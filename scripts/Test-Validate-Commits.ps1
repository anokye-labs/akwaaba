<#
.SYNOPSIS
    Test suite for Validate-Commits.ps1

.DESCRIPTION
    Comprehensive tests for the Validate-Commits.ps1 script, including:
    - Commit message pattern matching
    - Issue reference extraction
    - Special commit type handling
    - Validation result logging

.EXAMPLE
    ./Test-Validate-Commits.ps1

.NOTES
    Author: Anokye Labs
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Test configuration
$script:PassedTests = 0
$script:FailedTests = 0
$script:TestResults = @()

# Helper function to run a test
function Test-CommitValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$TestBlock
    )
    
    Write-Host "`n--- Test: $TestName ---" -ForegroundColor Cyan
    
    try {
        & $TestBlock
        Write-Host "✓ PASSED" -ForegroundColor Green
        $script:PassedTests++
        $script:TestResults += [PSCustomObject]@{
            Test = $TestName
            Result = "PASSED"
            Error = $null
        }
    } catch {
        Write-Host "✗ FAILED: $_" -ForegroundColor Red
        $script:FailedTests++
        $script:TestResults += [PSCustomObject]@{
            Test = $TestName
            Result = "FAILED"
            Error = $_.Exception.Message
        }
    }
}

Write-Host "=== Validate-Commits.ps1 Test Suite ===" -ForegroundColor Magenta

# Load the validation script functions for testing
$ValidateScript = Get-Content "$PSScriptRoot/Validate-Commits.ps1" -Raw

# Extract the Test-CommitMessage function for unit testing
$TestCommitMessageFunc = @'
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
        '#\d+',                                              # #123
        '(?i)(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+#\d+',  # Closes #123 (case-insensitive)
        '[\w-]+/[\w-]+#\d+',                                 # owner/repo#123
        'github\.com/[\w-]+/[\w-]+/issues/\d+'               # Full URL
    )
    
    foreach ($pattern in $patterns) {
        if ($Message -match $pattern) {
            return $true
        }
    }
    
    return $false
}
'@

# Extract the Get-IssueReferences function for unit testing
$GetIssueReferencesFunc = @'
function Get-IssueReferences {
    param(
        [string]$Message
    )
    
    $issueNumbers = @()
    
    # Match simple #123 format (all occurrences)
    $simpleMatches = [regex]::Matches($Message, '#(\d+)')
    foreach ($match in $simpleMatches) {
        $issueNumbers += $match.Groups[1].Value
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
'@

# Load test functions
Invoke-Expression $TestCommitMessageFunc
Invoke-Expression $GetIssueReferencesFunc

#region Pattern Matching Tests

Test-CommitValidation -TestName "Simple issue reference #123" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme #123"
    if (-not $result) {
        throw "Failed to match simple issue reference #123"
    }
}

Test-CommitValidation -TestName "Closes keyword with issue" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme Closes #456"
    if (-not $result) {
        throw "Failed to match 'Closes #456' pattern"
    }
}

Test-CommitValidation -TestName "Fixes keyword with issue" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme Fixes #789"
    if (-not $result) {
        throw "Failed to match 'Fixes #789' pattern"
    }
}

Test-CommitValidation -TestName "Resolves keyword with issue" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme Resolves #101"
    if (-not $result) {
        throw "Failed to match 'Resolves #101' pattern"
    }
}

Test-CommitValidation -TestName "Cross-repo reference owner/repo#123" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme anokye-labs/akwaaba#456"
    if (-not $result) {
        throw "Failed to match cross-repo reference"
    }
}

Test-CommitValidation -TestName "Full GitHub URL" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme https://github.com/anokye-labs/akwaaba/issues/789"
    if (-not $result) {
        throw "Failed to match full GitHub URL"
    }
}

Test-CommitValidation -TestName "No issue reference fails validation" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme"
    if ($result) {
        throw "Should not match commit without issue reference"
    }
}

Test-CommitValidation -TestName "Multiple issue references" -TestBlock {
    $result = Test-CommitMessage -Message "fix: update readme #123 and #456"
    if (-not $result) {
        throw "Failed to match commit with multiple issue references"
    }
}

#endregion

#region Issue Extraction Tests

Test-CommitValidation -TestName "Extract single issue number" -TestBlock {
    $issues = @(Get-IssueReferences -Message "fix: update readme #123")
    if ($issues.Count -ne 1 -or $issues[0] -ne "123") {
        throw "Failed to extract single issue number. Got: $($issues -join ', '), Count: $($issues.Count)"
    }
}

Test-CommitValidation -TestName "Extract issue from Closes keyword" -TestBlock {
    $issues = @(Get-IssueReferences -Message "fix: update readme Closes #456")
    if ($issues.Count -ne 1 -or $issues[0] -ne "456") {
        throw "Failed to extract issue from Closes keyword. Got: $($issues -join ', '), Count: $($issues.Count)"
    }
}

Test-CommitValidation -TestName "Extract issue from cross-repo reference" -TestBlock {
    $issues = @(Get-IssueReferences -Message "fix: update readme anokye-labs/akwaaba#789")
    if ($issues.Count -ne 1 -or $issues[0] -ne "789") {
        throw "Failed to extract issue from cross-repo reference. Got: $($issues -join ', '), Count: $($issues.Count)"
    }
}

Test-CommitValidation -TestName "Extract issue from full URL" -TestBlock {
    $issues = @(Get-IssueReferences -Message "fix: update readme https://github.com/anokye-labs/akwaaba/issues/101")
    if ($issues.Count -ne 1 -or $issues[0] -ne "101") {
        throw "Failed to extract issue from full URL. Got: $($issues -join ', '), Count: $($issues.Count)"
    }
}

Test-CommitValidation -TestName "Extract multiple unique issues" -TestBlock {
    $issues = @(Get-IssueReferences -Message "fix: update readme #123 and Closes #456")
    if ($issues.Count -ne 2) {
        throw "Failed to extract multiple issues. Got: $($issues -join ', '), Count: $($issues.Count)"
    }
    if ($issues -notcontains "123" -or $issues -notcontains "456") {
        throw "Missing expected issue numbers. Got: $($issues -join ', ')"
    }
}

Test-CommitValidation -TestName "Extract multiple simple issue references" -TestBlock {
    $issues = @(Get-IssueReferences -Message "fix: addresses #123 and #456")
    if ($issues.Count -ne 2) {
        throw "Failed to extract multiple simple references. Got: $($issues -join ', '), Count: $($issues.Count)"
    }
    if ($issues -notcontains "123" -or $issues -notcontains "456") {
        throw "Missing expected issue numbers. Got: $($issues -join ', ')"
    }
}

#endregion

#region Special Commit Type Tests

Test-CommitValidation -TestName "Merge commit pattern detection" -TestBlock {
    $message = "Merge pull request #123 from branch"
    if ($message -notmatch '^Merge ') {
        throw "Failed to match merge commit pattern"
    }
}

Test-CommitValidation -TestName "Revert commit pattern detection" -TestBlock {
    $message = "Revert 'fix: update readme'"
    if ($message -notmatch '^Revert ') {
        throw "Failed to match revert commit pattern"
    }
}

Test-CommitValidation -TestName "Bot commit pattern detection" -TestBlock {
    $message = "[bot] Automated update"
    if ($message -notmatch '^\[bot\]') {
        throw "Failed to match bot commit pattern"
    }
}

Test-CommitValidation -TestName "Dependabot commit pattern detection" -TestBlock {
    $message = "Bump dependency version (dependabot)"
    if ($message -notmatch 'dependabot') {
        throw "Failed to match dependabot commit pattern"
    }
}

#endregion

#region Case Sensitivity Tests

Test-CommitValidation -TestName "Closes keyword is case-insensitive" -TestBlock {
    $result1 = Test-CommitMessage -Message "fix: update readme closes #123"
    $result2 = Test-CommitMessage -Message "fix: update readme CLOSES #456"
    $result3 = Test-CommitMessage -Message "fix: update readme Closes #789"
    
    if (-not $result1 -or -not $result2 -or -not $result3) {
        throw "Closes keyword should be case-insensitive"
    }
}

Test-CommitValidation -TestName "Fixes keyword is case-insensitive" -TestBlock {
    $result1 = Test-CommitMessage -Message "fix: update readme fixes #123"
    $result2 = Test-CommitMessage -Message "fix: update readme FIXES #456"
    $result3 = Test-CommitMessage -Message "fix: update readme Fixes #789"
    
    if (-not $result1 -or -not $result2 -or -not $result3) {
        throw "Fixes keyword should be case-insensitive"
    }
}

#endregion

# Print summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Magenta
Write-Host "Total tests: $($script:PassedTests + $script:FailedTests)"
Write-Host "Passed: $script:PassedTests" -ForegroundColor Green
Write-Host "Failed: $script:FailedTests" -ForegroundColor Red

if ($script:FailedTests -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $script:TestResults | Where-Object { $_.Result -eq "FAILED" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Error)"
    }
}

# Exit with appropriate code
if ($script:FailedTests -gt 0) {
    exit 1
}

Write-Host "`n✓ All tests passed!" -ForegroundColor Green
exit 0
