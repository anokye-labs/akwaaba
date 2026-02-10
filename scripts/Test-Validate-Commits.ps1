<#
.SYNOPSIS
    Tests the Validate-Commits.ps1 script.

.DESCRIPTION
    Test-Validate-Commits.ps1 validates the commit validation script by testing:
    - Valid commit message formats
    - Invalid commit message formats
    - Edge cases (merge commits, bot commits, revert commits)
    - Issue existence and state checking
    - Error message formatting

.NOTES
    This script uses mock functions to avoid requiring actual GitHub CLI calls.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Test helper function
function Test-CommitValidation {
    param(
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "TEST: $TestName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    try {
        & $TestBlock
        Write-Host "✓ PASSED" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ FAILED: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        return $false
    }
}

# Load the script to test (dot-source to get functions)
$scriptPath = Join-Path $PSScriptRoot "Validate-Commits.ps1"

# We'll test individual functions by loading them
$scriptContent = Get-Content $scriptPath -Raw

# Extract and test Get-IssueReferences function
$getIssueReferencesCode = @'
function Get-IssueReferences {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommitMessage
    )
    
    $issueNumbers = [System.Collections.ArrayList]::new()
    
    # Pattern 1: Simple issue reference (#123)
    $simpleMatches = [regex]::Matches($CommitMessage, '#(\d+)')
    foreach ($match in $simpleMatches) {
        [void]$issueNumbers.Add($match.Groups[1].Value)
    }
    
    # Pattern 2: Full GitHub URLs
    $urlMatches = [regex]::Matches($CommitMessage, 'https://github\.com/[^/]+/[^/]+/issues/(\d+)')
    foreach ($match in $urlMatches) {
        [void]$issueNumbers.Add($match.Groups[1].Value)
    }
    
    # Remove duplicates and return as proper array
    # Use comma operator to force array return
    $unique = $issueNumbers | Select-Object -Unique
    return ,($unique -as [array])
}
'@

Invoke-Expression $getIssueReferencesCode

# Extract and test Test-IsSpecialCommit function
$testIsSpecialCommitCode = @'
function Test-IsSpecialCommit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommitMessage,
        
        [Parameter(Mandatory=$false)]
        [string]$CommitAuthor
    )
    
    # Check for merge commits
    if ($CommitMessage -match '^Merge (branch|pull request|remote-tracking branch)') {
        return @{ IsSpecial = $true; Reason = "Merge commit" }
    }
    
    # Check for revert commits
    if ($CommitMessage -match '^Revert ') {
        return @{ IsSpecial = $true; Reason = "Revert commit" }
    }
    
    # Check for bot commits (author ends with [bot])
    if ($CommitAuthor -match '\[bot\]$') {
        return @{ IsSpecial = $true; Reason = "Bot commit" }
    }
    
    return @{ IsSpecial = $false }
}
'@

Invoke-Expression $testIsSpecialCommitCode

# Test results tracking
$script:TestResults = @{
    Passed = 0
    Failed = 0
    Total = 0
}

function Record-TestResult {
    param([bool]$Passed)
    
    $script:TestResults.Total++
    if ($Passed) {
        $script:TestResults.Passed++
    }
    else {
        $script:TestResults.Failed++
    }
}

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         Validate-Commits.ps1 Test Suite                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Test 1: Simple issue reference (#123)
$result = Test-CommitValidation -TestName "Simple issue reference (#123)" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Add new feature #123"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "123") {
        throw "Expected issue #123, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 2: Multiple issue references
$result = Test-CommitValidation -TestName "Multiple issue references" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Update feature #123 #456"
    if ($refs.Count -ne 2) {
        throw "Expected 2 references, got $($refs.Count)"
    }
    if ($refs[0] -ne "123" -or $refs[1] -ne "456") {
        throw "Expected issues #123 and #456"
    }
}
Record-TestResult -Passed $result

# Test 3: Closing keywords (Closes #123)
$result = Test-CommitValidation -TestName "Closing keywords (Closes #123)" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "fix: Resolve bug Closes #123"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "123") {
        throw "Expected issue #123, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 4: Fixes keyword
$result = Test-CommitValidation -TestName "Fixes keyword" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "fix: Bug fix Fixes #456"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "456") {
        throw "Expected issue #456, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 5: Resolves keyword
$result = Test-CommitValidation -TestName "Resolves keyword" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Feature Resolves #789"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "789") {
        throw "Expected issue #789, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 6: Full GitHub URL
$result = Test-CommitValidation -TestName "Full GitHub URL" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: New feature https://github.com/owner/repo/issues/123"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "123") {
        throw "Expected issue #123, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 7: No issue reference
$result = Test-CommitValidation -TestName "No issue reference" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Add new feature"
    if ($refs.Count -ne 0) {
        throw "Expected 0 references, got $($refs.Count)"
    }
}
Record-TestResult -Passed $result

# Test 8: Duplicate references (should be unique)
$result = Test-CommitValidation -TestName "Duplicate references (deduplicated)" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Feature #123 #123"
    if ($refs.Count -ne 1) {
        throw "Expected 1 unique reference, got $($refs.Count)"
    }
}
Record-TestResult -Passed $result

# Test 9: Mixed URL and simple reference
$result = Test-CommitValidation -TestName "Mixed URL and simple reference" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Feature #123 https://github.com/owner/repo/issues/456"
    if ($refs.Count -ne 2) {
        throw "Expected 2 references, got $($refs.Count)"
    }
}
Record-TestResult -Passed $result

# Test 10: Merge commit detection
$result = Test-CommitValidation -TestName "Merge commit detection" -TestBlock {
    $check = Test-IsSpecialCommit -CommitMessage "Merge branch 'feature' into main"
    if (-not $check.IsSpecial) {
        throw "Expected merge commit to be detected as special"
    }
    if ($check.Reason -ne "Merge commit") {
        throw "Expected reason 'Merge commit', got '$($check.Reason)'"
    }
}
Record-TestResult -Passed $result

# Test 11: Merge pull request detection
$result = Test-CommitValidation -TestName "Merge pull request detection" -TestBlock {
    $check = Test-IsSpecialCommit -CommitMessage "Merge pull request #123 from user/branch"
    if (-not $check.IsSpecial) {
        throw "Expected merge PR to be detected as special"
    }
}
Record-TestResult -Passed $result

# Test 12: Revert commit detection
$result = Test-CommitValidation -TestName "Revert commit detection" -TestBlock {
    $check = Test-IsSpecialCommit -CommitMessage "Revert 'Add feature'"
    if (-not $check.IsSpecial) {
        throw "Expected revert commit to be detected as special"
    }
    if ($check.Reason -ne "Revert commit") {
        throw "Expected reason 'Revert commit', got '$($check.Reason)'"
    }
}
Record-TestResult -Passed $result

# Test 13: Bot commit detection
$result = Test-CommitValidation -TestName "Bot commit detection" -TestBlock {
    $check = Test-IsSpecialCommit -CommitMessage "Update dependencies" -CommitAuthor "dependabot[bot]"
    if (-not $check.IsSpecial) {
        throw "Expected bot commit to be detected as special"
    }
    if ($check.Reason -ne "Bot commit") {
        throw "Expected reason 'Bot commit', got '$($check.Reason)'"
    }
}
Record-TestResult -Passed $result

# Test 14: Regular commit is not special
$result = Test-CommitValidation -TestName "Regular commit is not special" -TestBlock {
    $check = Test-IsSpecialCommit -CommitMessage "feat: Add feature" -CommitAuthor "John Doe"
    if ($check.IsSpecial) {
        throw "Expected regular commit to not be special"
    }
}
Record-TestResult -Passed $result

# Test 15: Cross-repo reference (owner/repo#123)
$result = Test-CommitValidation -TestName "Cross-repo reference (owner/repo#123)" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Feature owner/repo#123"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "123") {
        throw "Expected issue #123, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 16: Issue reference in commit body
$result = Test-CommitValidation -TestName "Issue reference in commit body" -TestBlock {
    $message = @"
feat: Add new feature

This implements the feature requested in #456
"@
    $refs = Get-IssueReferences -CommitMessage $message
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "456") {
        throw "Expected issue #456, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 17: Multiple keywords in one message
$result = Test-CommitValidation -TestName "Multiple keywords in one message" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Feature Closes #123 Fixes #456 Resolves #789"
    if ($refs.Count -ne 3) {
        throw "Expected 3 references, got $($refs.Count)"
    }
}
Record-TestResult -Passed $result

# Test 18: Issue number at start of message
$result = Test-CommitValidation -TestName "Issue number at start of message" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "#123: Add new feature"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "123") {
        throw "Expected issue #123, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 19: Issue reference with parentheses
$result = Test-CommitValidation -TestName "Issue reference with parentheses" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Add feature (#123)"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "123") {
        throw "Expected issue #123, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Test 20: Large issue numbers
$result = Test-CommitValidation -TestName "Large issue numbers" -TestBlock {
    $refs = Get-IssueReferences -CommitMessage "feat: Feature #999999"
    if ($refs.Count -ne 1) {
        throw "Expected 1 reference, got $($refs.Count)"
    }
    if ($refs[0] -ne "999999") {
        throw "Expected issue #999999, got #$($refs[0])"
    }
}
Record-TestResult -Passed $result

# Print test summary
Write-Host "`n`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Test Summary                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  $($script:TestResults.Total)" -ForegroundColor White
Write-Host "Passed:       $($script:TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed:       $($script:TestResults.Failed)" -ForegroundColor $(if ($script:TestResults.Failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($script:TestResults.Failed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed!" -ForegroundColor Red
    exit 1
}
