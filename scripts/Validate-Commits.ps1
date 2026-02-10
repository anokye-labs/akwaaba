<#
.SYNOPSIS
    Validates commit messages in a pull request to ensure they reference open GitHub issues.

.DESCRIPTION
    This script validates that each commit in a PR references at least one open GitHub issue.
    It handles several edge cases:
    - Merge commits: Automatically skipped
    - Revert commits: Allowed without issue references
    - Bot commits: Allowed from approved bots (github-actions, dependabot)
    - WIP commits: Warning issued but validation passes
    
    Valid issue reference formats:
    - #123
    - Closes #123, Fixes #456, Resolves #789
    - owner/repo#123
    - https://github.com/owner/repo/issues/123

.PARAMETER Owner
    Repository owner (organization or user)

.PARAMETER Repo
    Repository name

.PARAMETER PullRequestNumber
    Pull request number to validate

.PARAMETER GitHubToken
    GitHub token for API authentication (optional, uses GITHUB_TOKEN env var if not provided)

.EXAMPLE
    .\Validate-Commits.ps1 -Owner "anokye-labs" -Repo "akwaaba" -PullRequestNumber 123

.OUTPUTS
    Returns a hashtable with validation results:
    @{
        Success = $true/$false
        Message = "Summary message"
        Commits = @(...)
        Warnings = @(...)
    }
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,
    
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    
    [Parameter(Mandatory = $true)]
    [int]$PullRequestNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'

# Approved bot accounts that can commit without issue references
$ApprovedBots = @(
    'github-actions[bot]',
    'dependabot[bot]',
    'renovate[bot]'
)

<#
.SYNOPSIS
    Detects if a commit is a merge commit.
#>
function Test-IsMergeCommit {
    param([string]$Message)
    
    return $Message -match '^Merge (pull request|branch|remote-tracking branch)'
}

<#
.SYNOPSIS
    Detects if a commit is a revert commit.
#>
function Test-IsRevertCommit {
    param([string]$Message)
    
    return $Message -match '^Revert\s+".*"' -or $Message -match '^Revert\s+\w+'
}

<#
.SYNOPSIS
    Detects if a commit is a WIP (Work In Progress) commit.
#>
function Test-IsWIPCommit {
    param([string]$Message)
    
    # Match common WIP patterns more strictly to avoid false positives
    return $Message -match '^\[WIP\]' -or $Message -match '^WIP:' -or $Message -match '^wip:' -or $Message -match '^\[wip\]'
}

<#
.SYNOPSIS
    Checks if a commit author is an approved bot.
#>
function Test-IsApprovedBot {
    param([string]$Author)
    
    foreach ($bot in $ApprovedBots) {
        if ($Author -eq $bot) {
            return $true
        }
    }
    
    return $false
}

<#
.SYNOPSIS
    Extracts issue references from a commit message.
#>
function Get-IssueReferences {
    param([string]$Message)
    
    $references = @()
    $processedPositions = @()  # Track positions of # that are part of cross-repo refs
    
    # Pattern 1: owner/repo#123 (check first to avoid conflicts with simple pattern)
    $matches = [regex]::Matches($Message, '([\w-]+)/([\w-]+)#(\d+)')
    foreach ($match in $matches) {
        $references += @{
            Type = 'cross-repo'
            Number = [int]$match.Groups[3].Value
            Owner = $match.Groups[1].Value
            Repo = $match.Groups[2].Value
        }
        # Record the position of the # in this match
        $hashPos = $match.Index + $match.Groups[1].Length + 1 + $match.Groups[2].Length
        $processedPositions += $hashPos
    }
    
    # Pattern 2: #123 (but not if already part of owner/repo#123)
    $matches = [regex]::Matches($Message, '#(\d+)')
    foreach ($match in $matches) {
        # Skip if this # position was already processed as part of a cross-repo reference
        if ($processedPositions -contains $match.Index) {
            continue
        }
        
        $number = [int]$match.Groups[1].Value
        # Only add if not already present
        if (-not ($references | Where-Object { $_.Number -eq $number -and $_.Owner -eq $Owner -and $_.Repo -eq $Repo })) {
            $references += @{
                Type = 'simple'
                Number = $number
                Owner = $Owner
                Repo = $Repo
            }
        }
    }
    
    # Pattern 3: Closes #123, Fixes #456, Resolves #789
    $matches = [regex]::Matches($Message, '(?:Closes|Fixes|Resolves)\s+#(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($match in $matches) {
        $number = [int]$match.Groups[1].Value
        # Only add if not already present
        if (-not ($references | Where-Object { $_.Number -eq $number -and $_.Owner -eq $Owner -and $_.Repo -eq $Repo })) {
            $references += @{
                Type = 'keyword'
                Number = $number
                Owner = $Owner
                Repo = $Repo
            }
        }
    }
    
    # Pattern 4: https://github.com/owner/repo/issues/123
    $matches = [regex]::Matches($Message, 'https://github\.com/([\w-]+)/([\w-]+)/issues/(\d+)')
    foreach ($match in $matches) {
        $number = [int]$match.Groups[3].Value
        $issueOwner = $match.Groups[1].Value
        $issueRepo = $match.Groups[2].Value
        # Only add if not already present
        if (-not ($references | Where-Object { $_.Number -eq $number -and $_.Owner -eq $issueOwner -and $_.Repo -eq $issueRepo })) {
            $references += @{
                Type = 'url'
                Number = $number
                Owner = $issueOwner
                Repo = $issueRepo
            }
        }
    }
    
    # Force return as array
    return ,($references)
}

<#
.SYNOPSIS
    Checks if an issue exists and is open.
#>
function Test-IssueIsOpen {
    param(
        [string]$IssueOwner,
        [string]$IssueRepo,
        [int]$IssueNumber
    )
    
    if (-not $GitHubToken) {
        Write-Warning "No GitHub token provided, skipping issue existence check"
        return $true
    }
    
    $headers = @{
        'Authorization' = "token $GitHubToken"
        'Accept' = 'application/vnd.github.v3+json'
    }
    
    $url = "https://api.github.com/repos/$IssueOwner/$IssueRepo/issues/$IssueNumber"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        return $response.state -eq 'open'
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            return $false
        }
        Write-Warning "Failed to check issue $IssueOwner/$IssueRepo#$IssueNumber : $_"
        return $false
    }
}

<#
.SYNOPSIS
    Fetches commits from a pull request.
#>
function Get-PRCommits {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$PullRequestNumber
    )
    
    if (-not $GitHubToken) {
        throw "GitHub token is required to fetch commits"
    }
    
    $headers = @{
        'Authorization' = "token $GitHubToken"
        'Accept' = 'application/vnd.github.v3+json'
    }
    
    $url = "https://api.github.com/repos/$Owner/$Repo/pulls/$PullRequestNumber/commits"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        return $response
    }
    catch {
        throw "Failed to fetch commits for PR #$PullRequestNumber : $_"
    }
}

<#
.SYNOPSIS
    Validates a single commit.
#>
function Test-Commit {
    param(
        [object]$Commit
    )
    
    $sha = $Commit.sha
    $shortSha = $sha.Substring(0, 7)
    $message = $Commit.commit.message
    $author = $Commit.commit.author.name
    $committer = $Commit.commit.committer.name
    
    # Check for edge cases
    
    # 1. Merge commits - skip
    if (Test-IsMergeCommit -Message $message) {
        return @{
            Success = $true
            Sha = $shortSha
            Message = $message.Split("`n")[0]
            Reason = "Merge commit (skipped)"
            IsEdgeCase = $true
        }
    }
    
    # 2. Revert commits - allow without issue reference
    if (Test-IsRevertCommit -Message $message) {
        return @{
            Success = $true
            Sha = $shortSha
            Message = $message.Split("`n")[0]
            Reason = "Revert commit (allowed)"
            IsEdgeCase = $true
        }
    }
    
    # 3. Bot commits - allow from approved bots
    if (Test-IsApprovedBot -Author $committer) {
        return @{
            Success = $true
            Sha = $shortSha
            Message = $message.Split("`n")[0]
            Reason = "Bot commit from $committer (allowed)"
            IsEdgeCase = $true
        }
    }
    
    # 4. WIP commits - warn but pass
    $isWIP = Test-IsWIPCommit -Message $message
    
    # Extract issue references
    $references = Get-IssueReferences -Message $message
    
    if ($references.Count -eq 0) {
        if ($isWIP) {
            return @{
                Success = $true
                Sha = $shortSha
                Message = $message.Split("`n")[0]
                Reason = "WIP commit (warning: no issue reference)"
                IsEdgeCase = $true
                IsWarning = $true
            }
        }
        
        return @{
            Success = $false
            Sha = $shortSha
            Message = $message.Split("`n")[0]
            Reason = "No issue reference found"
            IsEdgeCase = $false
        }
    }
    
    # Validate issue references
    $validReferences = @()
    $invalidReferences = @()
    
    foreach ($ref in $references) {
        $isOpen = Test-IssueIsOpen -IssueOwner $ref.Owner -IssueRepo $ref.Repo -IssueNumber $ref.Number
        if ($isOpen) {
            $validReferences += "$($ref.Owner)/$($ref.Repo)#$($ref.Number)"
        }
        else {
            $invalidReferences += "$($ref.Owner)/$($ref.Repo)#$($ref.Number)"
        }
    }
    
    if ($validReferences.Count -eq 0) {
        return @{
            Success = $false
            Sha = $shortSha
            Message = $message.Split("`n")[0]
            Reason = "No open issue found. References: $($invalidReferences -join ', ')"
            IsEdgeCase = $false
        }
    }
    
    $result = @{
        Success = $true
        Sha = $shortSha
        Message = $message.Split("`n")[0]
        Reason = "Valid references: $($validReferences -join ', ')"
        IsEdgeCase = $false
    }
    
    if ($isWIP) {
        $result.IsWarning = $true
        $result.Reason += " (WIP commit)"
    }
    
    return $result
}

# Main validation logic
try {
    Write-Host "Validating commits for PR #$PullRequestNumber in $Owner/$Repo" -ForegroundColor Cyan
    
    $commits = Get-PRCommits -Owner $Owner -Repo $Repo -PullRequestNumber $PullRequestNumber
    
    if ($commits.Count -eq 0) {
        Write-Host "No commits found in PR" -ForegroundColor Yellow
        return @{
            Success = $true
            Message = "No commits to validate"
            Commits = @()
            Warnings = @()
        }
    }
    
    Write-Host "Found $($commits.Count) commit(s) to validate" -ForegroundColor Cyan
    
    $results = @()
    $warnings = @()
    $failedCommits = @()
    
    foreach ($commit in $commits) {
        $result = Test-Commit -Commit $commit
        $results += $result
        
        if ($result.IsWarning) {
            $warnings += "$($result.Sha): $($result.Message) - $($result.Reason)"
        }
        
        if (-not $result.Success) {
            $failedCommits += $result
        }
        
        # Display result
        if ($result.Success) {
            if ($result.IsEdgeCase) {
                Write-Host "  ✓ $($result.Sha): $($result.Reason)" -ForegroundColor DarkGray
            }
            elseif ($result.IsWarning) {
                Write-Host "  ⚠ $($result.Sha): $($result.Reason)" -ForegroundColor Yellow
            }
            else {
                Write-Host "  ✓ $($result.Sha): $($result.Reason)" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  ✗ $($result.Sha): $($result.Reason)" -ForegroundColor Red
        }
    }
    
    # Summary
    Write-Host ""
    if ($failedCommits.Count -eq 0) {
        Write-Host "✓ All commits passed validation" -ForegroundColor Green
        
        if ($warnings.Count -gt 0) {
            Write-Host ""
            Write-Host "Warnings:" -ForegroundColor Yellow
            foreach ($warning in $warnings) {
                Write-Host "  $warning" -ForegroundColor Yellow
            }
        }
        
        return @{
            Success = $true
            Message = "All $($commits.Count) commit(s) passed validation"
            Commits = $results
            Warnings = $warnings
        }
    }
    else {
        Write-Host "✗ $($failedCommits.Count) commit(s) failed validation" -ForegroundColor Red
        Write-Host ""
        Write-Host "Failed commits:" -ForegroundColor Red
        foreach ($failed in $failedCommits) {
            Write-Host "  $($failed.Sha): $($failed.Message)" -ForegroundColor Red
            Write-Host "    Reason: $($failed.Reason)" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "Commit Message Format:" -ForegroundColor Yellow
        Write-Host "  Commits must reference an open issue using one of these formats:" -ForegroundColor Yellow
        Write-Host "    - #123" -ForegroundColor Yellow
        Write-Host "    - Closes #123, Fixes #456, Resolves #789" -ForegroundColor Yellow
        Write-Host "    - owner/repo#123" -ForegroundColor Yellow
        Write-Host "    - https://github.com/owner/repo/issues/123" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Edge cases (automatically handled):" -ForegroundColor Yellow
        Write-Host "    - Merge commits: Automatically skipped" -ForegroundColor Yellow
        Write-Host "    - Revert commits: Allowed without issue reference" -ForegroundColor Yellow
        Write-Host "    - Bot commits: Allowed from approved bots" -ForegroundColor Yellow
        Write-Host "    - WIP commits: Warning issued but allowed" -ForegroundColor Yellow
        
        return @{
            Success = $false
            Message = "$($failedCommits.Count) of $($commits.Count) commit(s) failed validation"
            Commits = $results
            Warnings = $warnings
        }
    }
}
catch {
    Write-Host "Error during validation: $_" -ForegroundColor Red
    return @{
        Success = $false
        Message = "Validation error: $_"
        Commits = @()
        Warnings = @()
    }
}
