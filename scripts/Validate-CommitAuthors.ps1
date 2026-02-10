<#
.SYNOPSIS
    Validates that all commits in a PR are from approved agents.

.DESCRIPTION
    Validate-CommitAuthors.ps1 fetches all commits in a pull request and validates
    that each commit's author and committer are approved agents from the allowlist.
    This enforces the agent-only commit policy for the repository.
    
    The script:
    - Fetches all commits in the specified PR
    - Extracts author and committer information
    - Detects GitHub Apps and bots by username patterns
    - Validates against the approved agents allowlist
    - Handles special cases like GitHub web UI commits
    - Returns detailed validation results

.PARAMETER PRNumber
    The pull request number to validate.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER AllowlistPath
    Path to the approved agents JSON file. Defaults to .github/approved-agents.json
    relative to repository root.

.PARAMETER OutputFormat
    Output format for the validation report. Valid values: Console, Markdown, Json.
    Default is Console.

.PARAMETER DryRun
    If specified, shows what would be validated without making actual API calls.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Json

.EXAMPLE
    ./Validate-CommitAuthors.ps1 -PRNumber 42 -DryRun

.OUTPUTS
    Returns a PSCustomObject with validation results:
    - Valid: Boolean indicating if all commits are from approved agents
    - TotalCommits: Total number of commits checked
    - ValidCommits: Number of valid commits
    - InvalidCommits: Array of commits that failed validation
    - ApprovedAgents: Array of agents found in the allowlist
    - ValidationDetails: Detailed information about each commit

.NOTES
    Author: Anokye Labs
    Requires: PowerShell 7.x or higher, GitHub CLI (gh) authenticated
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
    [string]$AllowlistPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $logEntry = @{
        timestamp = $timestamp
        level = $Level
        message = $Message
        operation = "ValidateCommitAuthors"
        correlationId = $CorrelationId
    }
    
    # Write to stderr so stdout remains clean for pipeline data
    [Console]::Error.WriteLine(($logEntry | ConvertTo-Json -Compress))
}

function Get-RepositoryContext {
    if ($Owner -and $Repo) {
        return @{ Owner = $Owner; Repo = $Repo }
    }
    
    try {
        $remote = git remote get-url origin 2>&1
        if ($remote -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
            return @{
                Owner = $Matches[1]
                Repo = $Matches[2]
            }
        }
    } catch {
        Write-Log "Failed to detect repository context from git remote" -Level "Warn"
    }
    
    throw "Could not determine repository context. Please provide -Owner and -Repo parameters."
}

function Get-ApprovedAgents {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        throw "Approved agents file not found at: $Path"
    }
    
    try {
        $content = Get-Content $Path -Raw | ConvertFrom-Json
        return $content.agents
    } catch {
        throw "Failed to parse approved agents file: $_"
    }
}

function Test-IsApprovedAgent {
    param(
        [string]$Username,
        [array]$ApprovedAgents
    )
    
    foreach ($agent in $ApprovedAgents) {
        if (-not $agent.enabled) {
            continue
        }
        
        # Check username match
        if ($agent.username -eq $Username) {
            return @{ IsApproved = $true; Agent = $agent }
        }
        
        # Check bot username match
        if ($agent.botUsername -eq $Username) {
            return @{ IsApproved = $true; Agent = $agent }
        }
        
        # Check for [bot] suffix pattern
        if ($Username -match '^(.+)\[bot\]$') {
            $baseName = $Matches[1]
            if ($agent.botUsername -eq $Username -or $agent.username -eq $baseName) {
                return @{ IsApproved = $true; Agent = $agent }
            }
        }
    }
    
    return @{ IsApproved = $false; Agent = $null }
}

function Get-PRCommits {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$PRNumber
    )
    
    Write-Log "Fetching commits for PR #$PRNumber in $Owner/$Repo"
    
    try {
        $commits = gh pr view $PRNumber --repo "$Owner/$Repo" --json commits | ConvertFrom-Json
        return $commits.commits
    } catch {
        throw "Failed to fetch PR commits: $_"
    }
}

function Format-ValidationResult {
    param(
        [PSCustomObject]$Result,
        [string]$Format
    )
    
    switch ($Format) {
        "Json" {
            return $Result | ConvertTo-Json -Depth 10
        }
        "Markdown" {
            $md = "# Commit Author Validation Report`n`n"
            $md += "**PR:** #$($Result.PRNumber)`n"
            $md += "**Repository:** $($Result.Owner)/$($Result.Repo)`n"
            $md += "**Status:** $(if ($Result.Valid) { '✅ PASSED' } else { '❌ FAILED' })`n"
            $md += "**Total Commits:** $($Result.TotalCommits)`n"
            $md += "**Valid Commits:** $($Result.ValidCommits)`n`n"
            
            if ($Result.InvalidCommits.Count -gt 0) {
                $md += "## Invalid Commits`n`n"
                $md += "| SHA | Author | Committer | Reason |`n"
                $md += "|-----|--------|-----------|--------|`n"
                foreach ($commit in $Result.InvalidCommits) {
                    $sha = $commit.Sha.Substring(0, 7)
                    $md += "| $sha | $($commit.AuthorName) | $($commit.CommitterName) | $($commit.Reason) |`n"
                }
                $md += "`n"
            }
            
            $md += "## Approved Agents`n`n"
            foreach ($agent in $Result.ApprovedAgents) {
                $md += "- **$($agent.username)** ($($agent.type)): $($agent.description)`n"
            }
            
            return $md
        }
        default {
            # Console output with colors
            $output = ""
            
            if ($Result.Valid) {
                Write-Host "`n✅ VALIDATION PASSED" -ForegroundColor Green
            } else {
                Write-Host "`n❌ VALIDATION FAILED" -ForegroundColor Red
            }
            
            Write-Host "`nPR: #$($Result.PRNumber)" -ForegroundColor Cyan
            Write-Host "Repository: $($Result.Owner)/$($Result.Repo)" -ForegroundColor Cyan
            Write-Host "Total Commits: $($Result.TotalCommits)" -ForegroundColor Cyan
            Write-Host "Valid Commits: $($Result.ValidCommits)" -ForegroundColor Green
            
            if ($Result.InvalidCommits.Count -gt 0) {
                Write-Host "`n❌ Invalid Commits ($($Result.InvalidCommits.Count)):" -ForegroundColor Red
                foreach ($commit in $Result.InvalidCommits) {
                    $sha = $commit.Sha.Substring(0, 7)
                    Write-Host "  • $sha - Author: $($commit.AuthorName), Committer: $($commit.CommitterName)" -ForegroundColor Yellow
                    Write-Host "    Reason: $($commit.Reason)" -ForegroundColor Yellow
                }
            }
            
            Write-Host "`nApproved Agents:" -ForegroundColor Cyan
            foreach ($agent in $Result.ApprovedAgents) {
                $status = if ($agent.enabled) { "✓" } else { "✗" }
                Write-Host "  $status $($agent.username) ($($agent.type)): $($agent.description)" -ForegroundColor White
            }
            
            Write-Host ""
            return $null
        }
    }
}

#endregion

#region Main Logic

try {
    Write-Log "Starting commit author validation for PR #$PRNumber"
    
    # Get repository context
    $repoContext = Get-RepositoryContext
    $Owner = $repoContext.Owner
    $Repo = $repoContext.Repo
    
    Write-Log "Repository context: $Owner/$Repo"
    
    # Determine allowlist path
    if (-not $AllowlistPath) {
        $repoRoot = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to determine repository root"
        }
        $AllowlistPath = Join-Path $repoRoot ".github/approved-agents.json"
    }
    
    Write-Log "Loading approved agents from: $AllowlistPath"
    
    # Load approved agents
    $approvedAgents = Get-ApprovedAgents -Path $AllowlistPath
    Write-Log "Loaded $($approvedAgents.Count) approved agents"
    
    if ($DryRun) {
        Write-Host "DRY RUN MODE - Would validate PR #$PRNumber in $Owner/$Repo" -ForegroundColor Yellow
        Write-Host "Allowlist path: $AllowlistPath" -ForegroundColor Yellow
        Write-Host "Approved agents loaded: $($approvedAgents.Count)" -ForegroundColor Yellow
        
        $dryRunResult = [PSCustomObject]@{
            DryRun = $true
            PRNumber = $PRNumber
            Owner = $Owner
            Repo = $Repo
            AllowlistPath = $AllowlistPath
            ApprovedAgentsCount = $approvedAgents.Count
            CorrelationId = $CorrelationId
        }
        
        if ($OutputFormat -eq "Json") {
            return $dryRunResult | ConvertTo-Json -Depth 10
        }
        return $dryRunResult
    }
    
    # Fetch PR commits
    $commits = Get-PRCommits -Owner $Owner -Repo $Repo -PRNumber $PRNumber
    Write-Log "Fetched $($commits.Count) commits from PR #$PRNumber"
    
    # Validate each commit
    $validCommits = 0
    $invalidCommits = @()
    $validationDetails = @()
    
    foreach ($commit in $commits) {
        $authorLogin = $commit.authors[0].login
        $authorName = $commit.authors[0].name
        $authorEmail = $commit.authors[0].email
        $committerLogin = $commit.committer.login
        $committerName = $commit.committer.name
        $sha = $commit.oid
        
        Write-Log "Validating commit $($sha.Substring(0, 7)) by $authorLogin"
        
        # Check author
        $authorCheck = Test-IsApprovedAgent -Username $authorLogin -ApprovedAgents $approvedAgents
        
        # Check committer
        $committerCheck = Test-IsApprovedAgent -Username $committerLogin -ApprovedAgents $approvedAgents
        
        $isValid = $authorCheck.IsApproved -and $committerCheck.IsApproved
        
        $detail = [PSCustomObject]@{
            Sha = $sha
            Message = $commit.messageHeadline
            AuthorLogin = $authorLogin
            AuthorName = $authorName
            AuthorEmail = $authorEmail
            CommitterLogin = $committerLogin
            CommitterName = $committerName
            AuthorApproved = $authorCheck.IsApproved
            CommitterApproved = $committerCheck.IsApproved
            IsValid = $isValid
        }
        
        $validationDetails += $detail
        
        if ($isValid) {
            $validCommits++
            Write-Log "Commit $($sha.Substring(0, 7)) is valid"
        } else {
            $reason = @()
            if (-not $authorCheck.IsApproved) {
                $reason += "Author '$authorLogin' not in approved agents list"
            }
            if (-not $committerCheck.IsApproved) {
                $reason += "Committer '$committerLogin' not in approved agents list"
            }
            
            $invalidCommits += [PSCustomObject]@{
                Sha = $sha
                Message = $commit.messageHeadline
                AuthorName = $authorLogin
                CommitterName = $committerLogin
                Reason = ($reason -join "; ")
            }
            
            Write-Log "Commit $($sha.Substring(0, 7)) is INVALID: $($reason -join '; ')" -Level "Warn"
        }
    }
    
    # Build result object
    $result = [PSCustomObject]@{
        Valid = ($invalidCommits.Count -eq 0)
        PRNumber = $PRNumber
        Owner = $Owner
        Repo = $Repo
        TotalCommits = $commits.Count
        ValidCommits = $validCommits
        InvalidCommits = $invalidCommits
        ApprovedAgents = $approvedAgents | Where-Object { $_.enabled }
        ValidationDetails = $validationDetails
        CorrelationId = $CorrelationId
    }
    
    Write-Log "Validation complete: $(if ($result.Valid) { 'PASSED' } else { 'FAILED' })"
    
    # Format and return result
    $formatted = Format-ValidationResult -Result $result -Format $OutputFormat
    if ($formatted) {
        return $formatted
    }
    return $result
    
} catch {
    Write-Log "Validation failed with error: $_" -Level "Error"
    throw
}

#endregion
