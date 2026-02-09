<#
.SYNOPSIS
    Validates that all commits in a PR are from approved agents.

.DESCRIPTION
    Validate-CommitAuthors.ps1 validates that all commits in a pull request
    are from approved agents, enforcing the agent-only commit pattern.
    
    The script:
    - Fetches all commits in a PR
    - Detects GitHub Apps by checking for [bot] suffix
    - Verifies GitHub App IDs against the allowlist
    - Handles multiple authentication methods
    - Provides detailed validation results
    
    Supports multiple agent types:
    - GitHub Apps (e.g., copilot[bot], github-actions[bot])
    - Service accounts with GitHub App authentication
    - Multiple authentication methods (App installation, OAuth)

.PARAMETER PRNumber
    The pull request number to validate.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER AllowlistPath
    Path to the approved agents allowlist JSON file.
    Default: .github/approved-agents.json

.PARAMETER OutputFormat
    Output format for the result. Valid values: Console, Json, Markdown.
    Default is Console.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.PARAMETER DryRun
    If specified, shows what would be validated without making actual API calls.

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba -OutputFormat Json

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42 -AllowlistPath custom-allowlist.json

.OUTPUTS
    Returns a PSCustomObject with:
    - Valid: Boolean indicating if all commits are from approved agents
    - Commits: Array of commit validation results
    - UnapprovedCommits: Array of commits from unapproved authors
    - ApprovedAgents: List of approved agents found

.NOTES
    Author: Anokye Labs
    Dependencies: Invoke-GraphQL.ps1, Get-RepoContext.ps1
    Key script for agent authentication workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [int]$PRNumber,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$AllowlistPath = ".github/approved-agents.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Json", "Markdown")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

#region Helper Functions

# Helper function to call Get-RepoContext.ps1
function Get-RepoContextHelper {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )
    
    $params = @{}
    
    if ($Refresh) {
        $params.Refresh = $true
    }
    
    # Call Get-RepoContext.ps1 as a script
    & "$PSScriptRoot/Get-RepoContext.ps1" @params
}

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Variables = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $params = @{
        Query = $Query
    }
    
    if ($Variables.Count -gt 0) {
        $params.Variables = $Variables
    }
    
    if ($CorrelationId) {
        $params.CorrelationId = $CorrelationId
    }

    if ($DryRun) {
        $params.DryRun = $true
    }
    
    # Call Invoke-GraphQL.ps1 as a script
    & "$PSScriptRoot/Invoke-GraphQL.ps1" @params
}

function Test-GitHubAppPattern {
    <#
    .SYNOPSIS
        Tests if a username matches GitHub App pattern.
    
    .DESCRIPTION
        Checks if a username ends with [bot] suffix, indicating a GitHub App.
    
    .PARAMETER Username
        The username to test.
    
    .OUTPUTS
        Boolean indicating if username matches GitHub App pattern.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username
    )
    
    return $Username -match '\[bot\]$'
}

function Get-GitHubAppId {
    <#
    .SYNOPSIS
        Extracts the base name from a GitHub App username.
    
    .DESCRIPTION
        Removes the [bot] suffix from a GitHub App username to get the base name.
    
    .PARAMETER BotUsername
        The bot username (e.g., "copilot[bot]").
    
    .OUTPUTS
        Base name without [bot] suffix.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BotUsername
    )
    
    return $BotUsername -replace '\[bot\]$', ''
}

function Test-AgentInAllowlist {
    <#
    .SYNOPSIS
        Tests if an agent is in the approved allowlist.
    
    .DESCRIPTION
        Checks if an agent username or GitHub App is approved in the allowlist.
        Supports both exact username match and GitHub App ID verification.
    
    .PARAMETER Username
        The commit author username to check.
    
    .PARAMETER Allowlist
        The parsed allowlist configuration object.
    
    .OUTPUTS
        PSCustomObject with approval status and agent details.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [object]$Allowlist
    )
    
    # Check if username is a GitHub App
    $isGitHubApp = Test-GitHubAppPattern -Username $Username
    
    if ($isGitHubApp) {
        # Extract base name from bot username
        $baseName = Get-GitHubAppId -BotUsername $Username
        
        # Find matching agent in allowlist
        $matchedAgent = $Allowlist.agents | Where-Object {
            $_.enabled -and (
                $_.botUsername -eq $Username -or
                $_.username -eq $baseName
            )
        } | Select-Object -First 1
        
        if ($matchedAgent) {
            return [PSCustomObject]@{
                Approved = $true
                IsGitHubApp = $true
                Agent = $matchedAgent
                Reason = "Approved GitHub App: $($matchedAgent.description)"
            }
        }
        else {
            return [PSCustomObject]@{
                Approved = $false
                IsGitHubApp = $true
                Agent = $null
                Reason = "GitHub App not in allowlist: $Username"
            }
        }
    }
    else {
        # Non-bot username - check if it's an approved service account
        $matchedAgent = $Allowlist.agents | Where-Object {
            $_.enabled -and $_.username -eq $Username
        } | Select-Object -First 1
        
        if ($matchedAgent) {
            return [PSCustomObject]@{
                Approved = $true
                IsGitHubApp = $false
                Agent = $matchedAgent
                Reason = "Approved service account: $($matchedAgent.description)"
            }
        }
        else {
            return [PSCustomObject]@{
                Approved = $false
                IsGitHubApp = $false
                Agent = $null
                Reason = "User not in allowlist: $Username (human commit or unapproved agent)"
            }
        }
    }
}

#endregion

#region Load Allowlist

# Resolve allowlist path
$allowlistFullPath = if ([System.IO.Path]::IsPathRooted($AllowlistPath)) {
    $AllowlistPath
} else {
    # Get repo root
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = $PSScriptRoot | Split-Path -Parent
    }
    Join-Path $repoRoot $AllowlistPath
}

if (-not (Test-Path $allowlistFullPath)) {
    Write-Error "Allowlist file not found: $allowlistFullPath"
    exit 1
}

try {
    $allowlist = Get-Content $allowlistFullPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to load allowlist from $allowlistFullPath : $_"
    exit 1
}

#endregion

#region Get Repository Context

if (-not $Owner -or -not $Repo) {
    $repoContext = Get-RepoContextHelper
    if (-not $Owner) { $Owner = $repoContext.Owner }
    if (-not $Repo) { $Repo = $repoContext.Repo }
}

#endregion

#region Fetch PR Commits

if ($DryRun) {
    Write-Host "DRY RUN: Would validate commits in PR #$PRNumber" -ForegroundColor Yellow
    Write-Host "  Owner: $Owner" -ForegroundColor Gray
    Write-Host "  Repo: $Repo" -ForegroundColor Gray
    Write-Host "  Allowlist: $allowlistFullPath" -ForegroundColor Gray
    return
}

# GraphQL query to fetch commits with author information
$commitsQuery = @"
query(`$owner: String!, `$repo: String!, `$prNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$prNumber) {
      commits(first: 100) {
        nodes {
          commit {
            oid
            message
            author {
              name
              email
              user {
                login
              }
            }
            committer {
              name
              email
              user {
                login
              }
            }
          }
        }
      }
    }
  }
}
"@

$commitsResult = Invoke-GraphQLHelper -Query $commitsQuery -Variables @{
    owner = $Owner
    repo = $Repo
    prNumber = $PRNumber
} -CorrelationId $CorrelationId

$commits = $commitsResult.Data.repository.pullRequest.commits.nodes

#endregion

#region Validate Commits

$validatedCommits = @()
$unapprovedCommits = @()
$approvedAgentsFound = @()

foreach ($commitNode in $commits) {
    $commit = $commitNode.commit
    
    # Get author login (GitHub username)
    $authorLogin = if ($commit.author.user) {
        $commit.author.user.login
    }
    else {
        # Fallback: use email or name if user not linked
        $commit.author.email -replace '@.*$', ''
    }
    
    # Validate against allowlist
    $validation = Test-AgentInAllowlist -Username $authorLogin -Allowlist $allowlist
    
    # Build commit validation result
    $commitValidation = [PSCustomObject]@{
        Oid = $commit.oid.Substring(0, 7)
        Message = ($commit.message -split "`n")[0]
        Author = [PSCustomObject]@{
            Login = $authorLogin
            Name = $commit.author.name
            Email = $commit.author.email
        }
        IsGitHubApp = $validation.IsGitHubApp
        Approved = $validation.Approved
        Agent = $validation.Agent
        Reason = $validation.Reason
    }
    
    $validatedCommits += $commitValidation
    
    if (-not $validation.Approved) {
        $unapprovedCommits += $commitValidation
    }
    else {
        # Track approved agents found
        if ($validation.Agent -and $validation.Agent.id -notin $approvedAgentsFound.id) {
            $approvedAgentsFound += $validation.Agent
        }
    }
}

#endregion

#region Build Result

$valid = $unapprovedCommits.Count -eq 0

$result = [PSCustomObject]@{
    PRNumber = $PRNumber
    Owner = $Owner
    Repo = $Repo
    Valid = $valid
    Summary = [PSCustomObject]@{
        TotalCommits = $validatedCommits.Count
        ApprovedCommits = ($validatedCommits | Where-Object { $_.Approved }).Count
        UnapprovedCommits = $unapprovedCommits.Count
        GitHubAppCommits = ($validatedCommits | Where-Object { $_.IsGitHubApp }).Count
        HumanCommits = ($validatedCommits | Where-Object { -not $_.IsGitHubApp -and -not $_.Approved }).Count
    }
    Commits = $validatedCommits
    UnapprovedCommits = $unapprovedCommits
    ApprovedAgents = $approvedAgentsFound
    AllowlistPath = $allowlistFullPath
}

#endregion

#region Output Formatting

switch ($OutputFormat) {
    "Json" {
        return $result | ConvertTo-Json -Depth 10
    }
    
    "Markdown" {
        $markdown = @"
# Commit Author Validation for PR #$PRNumber

**Repository:** $Owner/$Repo  
**Result:** $(if ($valid) { "✅ **VALID** - All commits from approved agents" } else { "❌ **INVALID** - Unapproved commits detected" })

## Summary

- **Total Commits:** $($result.Summary.TotalCommits)
- **Approved:** $($result.Summary.ApprovedCommits)
- **Unapproved:** $($result.Summary.UnapprovedCommits)
- **GitHub App Commits:** $($result.Summary.GitHubAppCommits)
- **Human Commits:** $($result.Summary.HumanCommits)

"@

        if ($approvedAgentsFound.Count -gt 0) {
            $markdown += @"
## ✅ Approved Agents Detected

"@
            foreach ($agent in $approvedAgentsFound) {
                $markdown += "- **$($agent.id)** ($($agent.botUsername)): $($agent.description)`n"
            }
            $markdown += "`n"
        }

        if ($unapprovedCommits.Count -gt 0) {
            $markdown += @"
## ❌ Unapproved Commits

"@
            foreach ($commit in $unapprovedCommits) {
                $markdown += @"
### Commit $($commit.Oid)
- **Author:** $($commit.Author.Login) ($($commit.Author.Name))
- **Message:** $($commit.Message)
- **Reason:** $($commit.Reason)

"@
            }
        }

        return $markdown
    }
    
    "Console" {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Commit Author Validation for PR #$PRNumber" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Repository: " -NoNewline -ForegroundColor Gray
        Write-Host "$Owner/$Repo" -ForegroundColor White
        Write-Host ""
        
        if ($valid) {
            Write-Host "✅ RESULT: " -NoNewline -ForegroundColor Green
            Write-Host "VALID - All commits from approved agents" -ForegroundColor Green -BackgroundColor DarkGreen
        }
        else {
            Write-Host "❌ RESULT: " -NoNewline -ForegroundColor Red
            Write-Host "INVALID - Unapproved commits detected" -ForegroundColor Red -BackgroundColor DarkRed
        }
        Write-Host ""
        
        Write-Host "📊 SUMMARY" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Total Commits: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.TotalCommits -ForegroundColor White
        Write-Host "  Approved: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.ApprovedCommits -ForegroundColor Green
        Write-Host "  Unapproved: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.UnapprovedCommits -ForegroundColor $(if ($result.Summary.UnapprovedCommits -gt 0) { "Red" } else { "Gray" })
        Write-Host "  GitHub App Commits: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.GitHubAppCommits -ForegroundColor Cyan
        Write-Host "  Human Commits: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.HumanCommits -ForegroundColor $(if ($result.Summary.HumanCommits -gt 0) { "Red" } else { "Gray" })
        Write-Host ""
        
        if ($approvedAgentsFound.Count -gt 0) {
            Write-Host "✅ APPROVED AGENTS DETECTED" -ForegroundColor Green
            Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            foreach ($agent in $approvedAgentsFound) {
                Write-Host "  🤖 " -NoNewline -ForegroundColor Green
                Write-Host "$($agent.id)" -NoNewline -ForegroundColor Yellow
                Write-Host " ($($agent.botUsername))" -ForegroundColor Gray
                Write-Host "     $($agent.description)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
        
        if ($unapprovedCommits.Count -gt 0) {
            Write-Host "❌ UNAPPROVED COMMITS" -ForegroundColor Red
            Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            foreach ($commit in $unapprovedCommits) {
                Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                Write-Host "Commit $($commit.Oid)" -ForegroundColor Yellow
                Write-Host "    Author: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($commit.Author.Login)" -NoNewline -ForegroundColor White
                Write-Host " ($($commit.Author.Name))" -ForegroundColor Gray
                Write-Host "    Message: " -NoNewline -ForegroundColor DarkGray
                Write-Host $commit.Message -ForegroundColor White
                Write-Host "    Reason: " -NoNewline -ForegroundColor DarkGray
                Write-Host $commit.Reason -ForegroundColor Red
                Write-Host ""
            }
        }
        
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        return $result
    }
}

#endregion
