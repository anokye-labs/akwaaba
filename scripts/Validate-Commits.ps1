<#
.SYNOPSIS
    Validates commit messages in a PR reference GitHub issues.

.DESCRIPTION
    Validate-Commits.ps1 validates that every commit in a pull request contains a
    reference to a GitHub issue. It checks for patterns like #123, Closes #456,
    owner/repo#789, and full URLs. Each validation attempt is logged with audit
    information including commit author, PR number, and timestamp.

.PARAMETER PRNumber
    The pull request number to validate.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.PARAMETER LogDirectory
    Directory where audit logs should be stored. Default is logs/commit-validation.

.OUTPUTS
    Returns exit code 0 if all commits are valid, 1 if any commit fails validation.
    All validation attempts are logged to structured JSON files.

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba

.NOTES
    Author: Anokye Labs
    Dependencies: Write-ValidationLog.ps1, gh CLI
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
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [string]$LogDirectory = "logs/commit-validation"
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

#region Helper Functions

# Get repository context if not provided
function Get-RepoContextHelper {
    if (-not $Owner -or -not $Repo) {
        try {
            $remoteUrl = git config --get remote.origin.url
            if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/\.]+)') {
                $script:Owner = $Matches[1]
                $script:Repo = $Matches[2]
            }
        } catch {
            Write-Error "Failed to detect repository context. Please specify -Owner and -Repo."
            exit 1
        }
    }
}

# Check if commit message contains issue reference
function Test-CommitMessage {
    param(
        [string]$Message
    )
    
    # Patterns to match:
    # - #123 (simple issue reference)
    # - Closes #123, Fixes #456, Resolves #789 (keywords with issue)
    # - owner/repo#123 (cross-repo reference)
    # - Full GitHub URLs
    
    $patterns = @(
        '#\d+',                                          # #123
        '(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#\d+',  # Closes #123
        '[\w-]+/[\w-]+#\d+',                            # owner/repo#123
        'github\.com/[\w-]+/[\w-]+/issues/\d+'          # Full URL
    )
    
    foreach ($pattern in $patterns) {
        if ($Message -match $pattern) {
            return $true
        }
    }
    
    return $false
}

# Extract issue numbers from commit message
function Get-IssueReferences {
    param(
        [string]$Message
    )
    
    $issueNumbers = @()
    
    # Match simple #123 format
    if ($Message -match '#(\d+)') {
        $issueNumbers += $Matches[1]
    }
    
    # Match keyword formats (Closes #123, Fixes #456, etc.)
    $keywordMatches = [regex]::Matches($Message, '(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#(\d+)', 'IgnoreCase')
    foreach ($match in $keywordMatches) {
        $issueNumbers += $match.Groups[1].Value
    }
    
    # Match cross-repo format (owner/repo#123)
    $crossRepoMatches = [regex]::Matches($Message, '[\w-]+/[\w-]+#(\d+)')
    foreach ($match in $crossRepoMatches) {
        $issueNumbers += $match.Groups[1].Value
    }
    
    # Match full URL format
    $urlMatches = [regex]::Matches($Message, 'github\.com/[\w-]+/[\w-]+/issues/(\d+)')
    foreach ($match in $urlMatches) {
        $issueNumbers += $match.Groups[1].Value
    }
    
    return $issueNumbers | Select-Object -Unique
}

#endregion

#region Main Script

Write-Host "Validating commits for PR #$PRNumber..."

# Get repository context
Get-RepoContextHelper

Write-Host "Repository: $Owner/$Repo"

# Get commits from PR using gh CLI
try {
    $commitsJson = gh pr view $PRNumber --repo "$Owner/$Repo" --json commits | ConvertFrom-Json
    $commits = $commitsJson.commits
} catch {
    Write-Error "Failed to get commits for PR #$PRNumber : $_"
    exit 1
}

Write-Host "Found $($commits.Count) commit(s) to validate"

$failedCommits = @()
$passedCommits = @()
$skippedCommits = @()

# Validate each commit
foreach ($commit in $commits) {
    $sha = $commit.oid
    $shortSha = $sha.Substring(0, 7)
    $author = $commit.authors[0].email
    $message = $commit.messageHeadline
    
    Write-Host "`nValidating commit $shortSha by $author"
    Write-Host "  Message: $message"
    
    # Check for special commit types that can be skipped
    $skipPatterns = @(
        '^Merge ',           # Merge commits
        '^Revert ',          # Revert commits
        '^\[bot\]',          # Bot commits
        'dependabot'         # Dependabot commits
    )
    
    $shouldSkip = $false
    foreach ($pattern in $skipPatterns) {
        if ($message -match $pattern) {
            $shouldSkip = $true
            $skipReason = "Special commit type: $pattern"
            break
        }
    }
    
    if ($shouldSkip) {
        Write-Host "  ✓ Skipped: $skipReason" -ForegroundColor Yellow
        $skippedCommits += $commit
        
        # Log the skip
        & "$PSScriptRoot/Write-ValidationLog.ps1" `
            -CommitSha $sha `
            -CommitAuthor $author `
            -CommitMessage $message `
            -PRNumber $PRNumber `
            -ValidationResult "Skip" `
            -ValidationMessage $skipReason `
            -CorrelationId $CorrelationId `
            -LogDirectory $LogDirectory
        
        continue
    }
    
    # Check if commit message contains issue reference
    if (Test-CommitMessage -Message $message) {
        $issueRefs = Get-IssueReferences -Message $message
        Write-Host "  ✓ Pass: Found issue reference(s): $($issueRefs -join ', ')" -ForegroundColor Green
        $passedCommits += $commit
        
        # Log the pass
        & "$PSScriptRoot/Write-ValidationLog.ps1" `
            -CommitSha $sha `
            -CommitAuthor $author `
            -CommitMessage $message `
            -PRNumber $PRNumber `
            -ValidationResult "Pass" `
            -ValidationMessage "Issue references: $($issueRefs -join ', ')" `
            -CorrelationId $CorrelationId `
            -LogDirectory $LogDirectory
    } else {
        Write-Host "  ✗ Fail: No issue reference found" -ForegroundColor Red
        $failedCommits += $commit
        
        # Log the failure
        & "$PSScriptRoot/Write-ValidationLog.ps1" `
            -CommitSha $sha `
            -CommitAuthor $author `
            -CommitMessage $message `
            -PRNumber $PRNumber `
            -ValidationResult "Fail" `
            -ValidationMessage "No issue reference found in commit message" `
            -CorrelationId $CorrelationId `
            -LogDirectory $LogDirectory
    }
}

# Print summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "Total commits: $($commits.Count)"
Write-Host "Passed: $($passedCommits.Count)" -ForegroundColor Green
Write-Host "Failed: $($failedCommits.Count)" -ForegroundColor Red
Write-Host "Skipped: $($skippedCommits.Count)" -ForegroundColor Yellow

# If any commits failed, print details and exit with error
if ($failedCommits.Count -gt 0) {
    Write-Host "`n=== Failed Commits ===" -ForegroundColor Red
    foreach ($commit in $failedCommits) {
        $shortSha = $commit.oid.Substring(0, 7)
        Write-Host "  - $shortSha : $($commit.messageHeadline)"
    }
    
    Write-Host "`nCommit messages must reference a GitHub issue using one of these formats:" -ForegroundColor Yellow
    Write-Host "  - #123"
    Write-Host "  - Closes #123, Fixes #456, Resolves #789"
    Write-Host "  - owner/repo#123"
    Write-Host "  - https://github.com/owner/repo/issues/123"
    Write-Host "`nPlease amend your commits to include issue references."
    
    exit 1
}

Write-Host "`n✓ All commits passed validation!" -ForegroundColor Green
exit 0

#endregion
