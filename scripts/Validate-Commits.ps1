<#
.SYNOPSIS
    Validate that all commits in a PR reference open GitHub issues.

.DESCRIPTION
    Validate-Commits.ps1 validates that every commit in a PR references at least one
    open GitHub issue. This enforces issue-driven development practices.
    
    The script:
    - Fetches all commits in the PR
    - Parses commit messages for issue references (#123, Closes #456, etc.)
    - Verifies referenced issues exist and are open
    - Reports validation results with actionable error messages

.PARAMETER PRNumber
    The pull request number to validate commits for.

.PARAMETER Owner
    The repository owner (organization or user). Defaults to current repo.

.PARAMETER Repo
    The repository name. Defaults to current repo.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42
    Validates all commits in PR #42.

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42 -Owner myorg -Repo myrepo
    Validates commits in PR #42 for a specific repository.

.OUTPUTS
    Returns 0 for success, 1 for validation failures.
    Writes validation results to stdout.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Requires PowerShell 7.x or higher.
    
    Supported issue reference formats:
    - #123
    - Closes #123, Fixes #456, Resolves #789
    - owner/repo#123
    - Full URLs: https://github.com/owner/repo/issues/123
    
    Special commit types (merge commits, reverts) are handled appropriately.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$PRNumber,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

Write-Host "=== Commit Validator ===" -ForegroundColor Cyan
Write-Host "PR Number: $PRNumber" -ForegroundColor Gray
Write-Host "Correlation ID: $CorrelationId" -ForegroundColor Gray
Write-Host ""

# Get repository context if not provided
if (-not $Owner -or -not $Repo) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    try {
        $repoContext = & "$scriptDir/Get-RepoContext.ps1"
        if (-not $Owner) { $Owner = $repoContext.Owner }
        if (-not $Repo) { $Repo = $repoContext.Repo }
        Write-Host "Repository: $Owner/$Repo" -ForegroundColor Gray
    }
    catch {
        Write-Host "Error: Failed to get repository context: $_" -ForegroundColor Red
        exit 1
    }
}

# Function to extract issue references from commit message
function Get-IssueReferences {
    param([string]$Message)
    
    $issueRefs = @()
    
    # Pattern 1: Simple #123 format
    $simplePattern = '#(\d+)'
    $simpleMatches = [regex]::Matches($Message, $simplePattern)
    foreach ($match in $simpleMatches) {
        $issueRefs += @{
            Number = [int]$match.Groups[1].Value
            Owner = $Owner
            Repo = $Repo
        }
    }
    
    # Pattern 2: Closes #123, Fixes #456, Resolves #789
    $keywordPattern = '(?:Closes|Fixes|Resolves|Refs?)\s+#(\d+)'
    $keywordMatches = [regex]::Matches($Message, $keywordPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($match in $keywordMatches) {
        $num = [int]$match.Groups[1].Value
        # Add only if not already present
        if (-not ($issueRefs | Where-Object { $_.Number -eq $num -and $_.Owner -eq $Owner -and $_.Repo -eq $Repo })) {
            $issueRefs += @{
                Number = $num
                Owner = $Owner
                Repo = $Repo
            }
        }
    }
    
    # Pattern 3: owner/repo#123
    $crossRepoPattern = '([a-zA-Z0-9-]+)/([a-zA-Z0-9_.-]+)#(\d+)'
    $crossRepoMatches = [regex]::Matches($Message, $crossRepoPattern)
    foreach ($match in $crossRepoMatches) {
        $refOwner = $match.Groups[1].Value
        $refRepo = $match.Groups[2].Value
        $num = [int]$match.Groups[3].Value
        # Add only if not already present
        if (-not ($issueRefs | Where-Object { $_.Number -eq $num -and $_.Owner -eq $refOwner -and $_.Repo -eq $refRepo })) {
            $issueRefs += @{
                Number = $num
                Owner = $refOwner
                Repo = $refRepo
            }
        }
    }
    
    # Pattern 4: Full GitHub URLs
    $urlPattern = 'https?://github\.com/([a-zA-Z0-9-]+)/([a-zA-Z0-9_.-]+)/issues/(\d+)'
    $urlMatches = [regex]::Matches($Message, $urlPattern)
    foreach ($match in $urlMatches) {
        $refOwner = $match.Groups[1].Value
        $refRepo = $match.Groups[2].Value
        $num = [int]$match.Groups[3].Value
        # Add only if not already present
        if (-not ($issueRefs | Where-Object { $_.Number -eq $num -and $_.Owner -eq $refOwner -and $_.Repo -eq $refRepo })) {
            $issueRefs += @{
                Number = $num
                Owner = $refOwner
                Repo = $refRepo
            }
        }
    }
    
    return $issueRefs
}

# Function to check if commit should be skipped
function Test-ShouldSkipCommit {
    param([string]$Message)
    
    # Skip merge commits
    if ($Message -match '^Merge (branch|pull request|remote-tracking branch)') {
        return $true
    }
    
    # Skip revert commits
    if ($Message -match '^Revert ') {
        return $true
    }
    
    return $false
}

# Function to verify issue exists and is open
function Test-IssueValid {
    param(
        [hashtable]$IssueRef
    )
    
    $issueNumber = $IssueRef.Number
    $issueOwner = $IssueRef.Owner
    $issueRepo = $IssueRef.Repo
    
    try {
        # Use gh CLI to check issue
        $issueJson = gh issue view $issueNumber --repo "$issueOwner/$issueRepo" --json state,title 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            return @{
                Valid = $false
                Reason = "Issue #$issueNumber does not exist in $issueOwner/$issueRepo"
            }
        }
        
        $issue = $issueJson | ConvertFrom-Json
        
        if ($issue.state -ne "OPEN") {
            return @{
                Valid = $false
                Reason = "Issue #$issueNumber in $issueOwner/$issueRepo is closed"
            }
        }
        
        return @{
            Valid = $true
            Title = $issue.title
        }
    }
    catch {
        return @{
            Valid = $false
            Reason = "Failed to verify issue #$issueNumber: $_"
        }
    }
}

# Fetch commits from the PR
Write-Host "Fetching commits from PR #$PRNumber..." -ForegroundColor Yellow
try {
    $commitsJson = gh pr view $PRNumber --repo "$Owner/$Repo" --json commits 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to fetch PR commits: $commitsJson" -ForegroundColor Red
        exit 1
    }
    
    $prData = $commitsJson | ConvertFrom-Json
    $commits = $prData.commits
    
    Write-Host "Found $($commits.Count) commit(s)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "Error: Failed to fetch PR commits: $_" -ForegroundColor Red
    exit 1
}

# Validate each commit
$invalidCommits = @()
$validCommits = @()
$skippedCommits = @()
# Git standard abbreviated commit SHA length (short enough to be readable, long enough to avoid collisions in most repos)
$shortShaLength = 7

foreach ($commit in $commits) {
    # Safely abbreviate commit SHA (standard is 7 characters, but handle shorter SHAs)
    $sha = if ($commit.oid.Length -ge $shortShaLength) { $commit.oid.Substring(0, $shortShaLength) } else { $commit.oid }
    $message = $commit.messageHeadline
    $fullMessage = if ($commit.messageBody) { "$message`n$($commit.messageBody)" } else { $message }
    
    Write-Host "Checking commit $sha : $message" -ForegroundColor Cyan
    
    # Check if commit should be skipped
    if (Test-ShouldSkipCommit -Message $fullMessage) {
        Write-Host "  → Skipped (merge/revert commit)" -ForegroundColor Gray
        $skippedCommits += @{
            SHA = $sha
            Message = $message
            Reason = "Merge or revert commit"
        }
        continue
    }
    
    # Extract issue references
    $issueRefs = Get-IssueReferences -Message $fullMessage
    
    if ($issueRefs.Count -eq 0) {
        Write-Host "  ✗ No issue reference found" -ForegroundColor Red
        $invalidCommits += @{
            SHA = $sha
            Message = $message
            Reason = "No issue reference found"
        }
        continue
    }
    
    # Verify at least one valid issue reference
    $hasValidRef = $false
    $refDetails = @()
    
    foreach ($ref in $issueRefs) {
        $validation = Test-IssueValid -IssueRef $ref
        $refDetails += $validation
        if ($validation.Valid) {
            $hasValidRef = $true
        }
    }
    
    if ($hasValidRef) {
        $validIssues = ($refDetails | Where-Object { $_.Valid }).Count
        Write-Host "  ✓ Valid ($validIssues issue reference(s) verified)" -ForegroundColor Green
        $validCommits += @{
            SHA = $sha
            Message = $message
            IssueRefs = $issueRefs
        }
    }
    else {
        $reasons = ($refDetails | ForEach-Object { $_.Reason }) -join "; "
        Write-Host "  ✗ Invalid: $reasons" -ForegroundColor Red
        $invalidCommits += @{
            SHA = $sha
            Message = $message
            Reason = $reasons
        }
    }
    
    Write-Host ""
}

# Print summary
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "Total commits: $($commits.Count)" -ForegroundColor Gray
Write-Host "Valid: $($validCommits.Count)" -ForegroundColor Green
Write-Host "Invalid: $($invalidCommits.Count)" -ForegroundColor $(if ($invalidCommits.Count -gt 0) { "Red" } else { "Gray" })
Write-Host "Skipped: $($skippedCommits.Count)" -ForegroundColor Gray
Write-Host ""

# If there are invalid commits, provide helpful guidance
if ($invalidCommits.Count -gt 0) {
    Write-Host "=== Invalid Commits ===" -ForegroundColor Red
    Write-Host ""
    foreach ($commit in $invalidCommits) {
        Write-Host "Commit: $($commit.SHA)" -ForegroundColor Yellow
        Write-Host "Message: $($commit.Message)" -ForegroundColor Gray
        Write-Host "Reason: $($commit.Reason)" -ForegroundColor Red
        Write-Host ""
    }
    
    Write-Host "=== How to Fix ===" -ForegroundColor Yellow
    Write-Host "Every commit must reference an open GitHub issue. Supported formats:" -ForegroundColor Gray
    Write-Host "  - #123" -ForegroundColor Gray
    Write-Host "  - Closes #123" -ForegroundColor Gray
    Write-Host "  - Fixes #456" -ForegroundColor Gray
    Write-Host "  - Resolves #789" -ForegroundColor Gray
    Write-Host "  - owner/repo#123" -ForegroundColor Gray
    Write-Host "  - https://github.com/owner/repo/issues/123" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To fix your commits, you can:" -ForegroundColor Gray
    Write-Host "  1. Amend commit messages: git commit --amend" -ForegroundColor Gray
    Write-Host "  2. Interactive rebase: git rebase -i HEAD~N" -ForegroundColor Gray
    Write-Host "  3. Force push: git push --force-with-lease" -ForegroundColor Gray
    Write-Host ""
    Write-Host "See CONTRIBUTING.md for more details on commit message format." -ForegroundColor Gray
    Write-Host ""
    
    exit 1
}

Write-Host "✓ All commits are valid!" -ForegroundColor Green
exit 0
