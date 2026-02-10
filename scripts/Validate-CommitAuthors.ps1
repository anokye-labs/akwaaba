#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates that all commits in a pull request are from approved agents.

.DESCRIPTION
    This script enforces the agent-only commit pattern by:
    1. Fetching all commits in a pull request
    2. Extracting commit author information
    3. Checking authors against the approved agents allowlist
    4. Detecting GitHub Apps by [bot] suffix in username
    5. Supporting emergency bypass via PR labels
    6. Creating an audit trail of all validations

.PARAMETER Owner
    The repository owner (organization or user).

.PARAMETER Repo
    The repository name.

.PARAMETER PullRequestNumber
    The pull request number to validate.

.PARAMETER AllowlistPath
    Path to the approved-agents.json file. Defaults to .github/approved-agents.json

.PARAMETER BypassLabel
    Label that allows emergency bypass. Defaults to 'emergency-merge'

.PARAMETER AuditLog
    Path to write audit log. If not provided, logs to stdout only.

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -Owner "anokye-labs" -Repo "akwaaba" -PullRequestNumber 42

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -Owner "anokye-labs" -Repo "akwaaba" -PullRequestNumber 42 -AuditLog "audit.log"

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Exit codes:
    0 = All commits are from approved agents
    1 = Validation failed (unapproved commits found)
    2 = Emergency bypass applied
    3 = Error (missing dependencies, invalid input, etc.)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $true)]
    [int]$PullRequestNumber,

    [Parameter(Mandatory = $false)]
    [string]$AllowlistPath = ".github/approved-agents.json",

    [Parameter(Mandatory = $false)]
    [string]$BypassLabel = "emergency-merge",

    [Parameter(Mandatory = $false)]
    [string]$AuditLog
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ANSI color codes for output
$script:ColorReset = "`e[0m"
$script:ColorRed = "`e[31m"
$script:ColorGreen = "`e[32m"
$script:ColorYellow = "`e[33m"
$script:ColorBlue = "`e[34m"
$script:ColorCyan = "`e[36m"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = $script:ColorReset
    )
    Write-Host "${Color}${Message}${script:ColorReset}"
}

function Write-AuditLog {
    param(
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    
    Write-Verbose $logEntry
    
    if ($AuditLog) {
        Add-Content -Path $AuditLog -Value $logEntry
    }
}

function Test-GitHubCLI {
    try {
        $null = gh --version
        return $true
    }
    catch {
        Write-ColorOutput "Error: GitHub CLI (gh) is not installed or not in PATH." $script:ColorRed
        Write-ColorOutput "Install from: https://cli.github.com/" $script:ColorYellow
        return $false
    }
}

function Get-ApprovedAgents {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        throw "Approved agents file not found: $Path"
    }
    
    $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return $content
}

function Get-PullRequestLabels {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number
    )
    
    try {
        $labelsJson = gh pr view $Number --repo "$Owner/$Repo" --json labels | ConvertFrom-Json
        return $labelsJson.labels | ForEach-Object { $_.name }
    }
    catch {
        Write-Warning "Failed to fetch PR labels: $_"
        return @()
    }
}

function Get-PullRequestCommits {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number
    )
    
    try {
        $commitsJson = gh pr view $Number --repo "$Owner/$Repo" --json commits | ConvertFrom-Json
        return $commitsJson.commits
    }
    catch {
        throw "Failed to fetch commits for PR #${Number}: $_"
    }
}

function Test-GitHubApp {
    param([string]$Username)
    
    # GitHub Apps have [bot] suffix in their username
    return $Username -match '\[bot\]$'
}

function Test-ApprovedAgent {
    param(
        [string]$AuthorName,
        [string]$AuthorEmail,
        [object]$ApprovedAgents
    )
    
    foreach ($agent in $ApprovedAgents.agents) {
        if (-not $agent.enabled) {
            continue
        }
        
        # Check for GitHub App match (bot username)
        if ($agent.type -eq "github-app" -and $agent.botUsername) {
            if ($AuthorName -eq $agent.botUsername) {
                return @{
                    Approved = $true
                    Agent = $agent
                    MatchType = "github-app"
                }
            }
        }
        
        # Check for regular username match
        if ($agent.username) {
            if ($AuthorName -eq $agent.username -or $AuthorEmail -like "*$($agent.username)*") {
                return @{
                    Approved = $true
                    Agent = $agent
                    MatchType = "username"
                }
            }
        }
    }
    
    return @{
        Approved = $false
        Agent = $null
        MatchType = $null
    }
}

function Format-ValidationResults {
    param(
        [array]$Results,
        [bool]$AllApproved,
        [bool]$EmergencyBypass
    )
    
    Write-ColorOutput "`n========================================" $script:ColorCyan
    Write-ColorOutput "Agent Authentication Validation Results" $script:ColorCyan
    Write-ColorOutput "========================================`n" $script:ColorCyan
    
    if ($EmergencyBypass) {
        Write-ColorOutput "⚠️  EMERGENCY BYPASS ACTIVE" $script:ColorYellow
        Write-ColorOutput "This PR has the emergency bypass label applied.`n" $script:ColorYellow
    }
    
    Write-ColorOutput "Total commits: $($Results.Count)" $script:ColorBlue
    
    $approvedCount = ($Results | Where-Object { $_.Approved }).Count
    $unapprovedCount = $Results.Count - $approvedCount
    
    Write-ColorOutput "Approved: $approvedCount" $script:ColorGreen
    Write-ColorOutput "Unapproved: $unapprovedCount" $script:ColorRed
    
    Write-ColorOutput "`nCommit Details:" $script:ColorBlue
    Write-ColorOutput "---------------`n" $script:ColorBlue
    
    foreach ($result in $Results) {
        $sha = $result.Sha.Substring(0, 7)
        $status = if ($result.Approved) { "✓" } else { "✗" }
        $color = if ($result.Approved) { $script:ColorGreen } else { $script:ColorRed }
        
        Write-ColorOutput "$status [$sha] $($result.AuthorName)" $color
        Write-ColorOutput "   Email: $($result.AuthorEmail)" $script:ColorBlue
        
        if ($result.Approved) {
            Write-ColorOutput "   Agent: $($result.Agent.id) ($($result.MatchType))" $script:ColorGreen
        }
        else {
            Write-ColorOutput "   ❌ NOT AN APPROVED AGENT" $script:ColorRed
        }
        
        Write-Host ""
    }
    
    if (-not $AllApproved -and -not $EmergencyBypass) {
        Write-ColorOutput "========================================" $script:ColorRed
        Write-ColorOutput "❌ VALIDATION FAILED" $script:ColorRed
        Write-ColorOutput "========================================`n" $script:ColorRed
        Write-ColorOutput "The following commits are from unapproved authors:" $script:ColorRed
        
        $unapproved = $Results | Where-Object { -not $_.Approved }
        foreach ($commit in $unapproved) {
            Write-ColorOutput "  • $($commit.Sha.Substring(0, 7)) by $($commit.AuthorName)" $script:ColorRed
        }
        
        Write-ColorOutput "`nAgent-Only Commit Policy:" $script:ColorYellow
        Write-ColorOutput "This repository follows the Anokye-Krom System where only approved" $script:ColorYellow
        Write-ColorOutput "AI agents are allowed to commit code. This ensures:" $script:ColorYellow
        Write-ColorOutput "  • All changes are tracked and auditable" $script:ColorYellow
        Write-ColorOutput "  • Consistent code quality through automated processes" $script:ColorYellow
        Write-ColorOutput "  • Clear separation between planning (human) and execution (agent)`n" $script:ColorYellow
        
        Write-ColorOutput "To fix this issue:" $script:ColorYellow
        Write-ColorOutput "1. Create a GitHub issue describing the needed changes" $script:ColorYellow
        Write-ColorOutput "2. Assign the issue to an approved agent (e.g., @copilot)" $script:ColorYellow
        Write-ColorOutput "3. Let the agent create a new PR with the changes" $script:ColorYellow
        Write-ColorOutput "`nFor emergency situations:" $script:ColorYellow
        Write-ColorOutput "Administrators can apply the 'emergency-merge' label to bypass validation.`n" $script:ColorYellow
    }
    elseif ($EmergencyBypass) {
        Write-ColorOutput "========================================" $script:ColorYellow
        Write-ColorOutput "⚠️  EMERGENCY BYPASS" $script:ColorYellow
        Write-ColorOutput "========================================`n" $script:ColorYellow
        Write-ColorOutput "This PR will be allowed to merge despite validation failures." $script:ColorYellow
        Write-ColorOutput "Emergency bypasses are logged for audit purposes.`n" $script:ColorYellow
    }
    else {
        Write-ColorOutput "========================================" $script:ColorGreen
        Write-ColorOutput "✅ VALIDATION PASSED" $script:ColorGreen
        Write-ColorOutput "========================================`n" $script:ColorGreen
        Write-ColorOutput "All commits are from approved agents." $script:ColorGreen
    }
}

# Main execution
try {
    Write-AuditLog "Starting validation for PR #$PullRequestNumber in $Owner/$Repo"
    
    # Check dependencies
    if (-not (Test-GitHubCLI)) {
        Write-AuditLog "ERROR: GitHub CLI not available"
        exit 3
    }
    
    # Load approved agents
    Write-ColorOutput "Loading approved agents from: $AllowlistPath" $script:ColorBlue
    $approvedAgentsConfig = Get-ApprovedAgents -Path $AllowlistPath
    Write-AuditLog "Loaded $($approvedAgentsConfig.agents.Count) approved agents"
    
    # Check for emergency bypass
    Write-ColorOutput "Checking for emergency bypass label..." $script:ColorBlue
    $labels = Get-PullRequestLabels -Owner $Owner -Repo $Repo -Number $PullRequestNumber
    $emergencyBypass = $labels -contains $BypassLabel
    
    if ($emergencyBypass) {
        Write-AuditLog "WARNING: Emergency bypass active for PR #$PullRequestNumber"
    }
    
    # Fetch commits
    Write-ColorOutput "Fetching commits for PR #$PullRequestNumber..." $script:ColorBlue
    $commits = Get-PullRequestCommits -Owner $Owner -Repo $Repo -Number $PullRequestNumber
    Write-AuditLog "Found $($commits.Count) commits in PR #$PullRequestNumber"
    
    if ($commits.Count -eq 0) {
        Write-ColorOutput "No commits found in PR. Nothing to validate." $script:ColorYellow
        Write-AuditLog "No commits found in PR #$PullRequestNumber"
        exit 0
    }
    
    # Validate each commit
    $results = @()
    foreach ($commit in $commits) {
        $authorName = $commit.authors[0].name
        $authorEmail = $commit.authors[0].email
        $sha = $commit.oid
        
        Write-Verbose "Validating commit $sha by $authorName <$authorEmail>"
        
        $validation = Test-ApprovedAgent -AuthorName $authorName -AuthorEmail $authorEmail -ApprovedAgents $approvedAgentsConfig
        
        $result = @{
            Sha = $sha
            AuthorName = $authorName
            AuthorEmail = $authorEmail
            Approved = $validation.Approved
            Agent = $validation.Agent
            MatchType = $validation.MatchType
        }
        
        $results += $result
        
        $status = if ($validation.Approved) { "APPROVED" } else { "REJECTED" }
        Write-AuditLog "Commit $sha by ${authorName}: $status"
    }
    
    # Determine overall result
    $allApproved = @($results | Where-Object { -not $_.Approved }).Count -eq 0
    
    # Display results
    Format-ValidationResults -Results $results -AllApproved $allApproved -EmergencyBypass $emergencyBypass
    
    # Set exit code
    if ($emergencyBypass) {
        Write-AuditLog "PR #${PullRequestNumber}: Emergency bypass - ALLOWED"
        exit 2
    }
    elseif ($allApproved) {
        Write-AuditLog "PR #${PullRequestNumber}: All commits approved - PASSED"
        exit 0
    }
    else {
        Write-AuditLog "PR #${PullRequestNumber}: Unapproved commits found - FAILED"
        exit 1
    }
}
catch {
    Write-ColorOutput "`nError: $_" $script:ColorRed
    Write-ColorOutput $_.ScriptStackTrace $script:ColorRed
    Write-AuditLog "ERROR: $_"
    exit 3
}
