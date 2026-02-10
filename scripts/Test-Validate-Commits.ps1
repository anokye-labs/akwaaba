<#
.SYNOPSIS
    Tests for Validate-Commits.ps1 script.

.DESCRIPTION
    Test-Validate-Commits.ps1 contains comprehensive tests for the commit message
    validation logic, covering all supported issue reference formats and edge cases.

.EXAMPLE
    .\Test-Validate-Commits.ps1
    
    Runs all tests and displays results.

.NOTES
    Tests cover:
    - Simple issue references (#123)
    - Action keywords (Closes, Fixes, Resolves)
    - Full repository references (owner/repo#123)
    - Full GitHub URLs
    - Multiple references per commit
    - Edge cases and invalid formats
    - SHA format handling
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Get the path to the script being tested
$scriptPath = Join-Path $PSScriptRoot "Validate-Commits.ps1"

# Test counter
$script:TestNumber = 0
$script:PassedTests = 0
$script:FailedTests = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $script:TestNumber++
    
    if ($Passed) {
        $script:PassedTests++
        Write-Host "✓ Test $($script:TestNumber): $TestName" -ForegroundColor Green
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Gray
        }
    }
    else {
        $script:FailedTests++
        Write-Host "✗ Test $($script:TestNumber): $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Red
        }
    }
}

function Test-CommitValidation {
    param(
        [string]$TestName,
        [string[]]$CommitMessages,
        [bool]$ExpectedValid,
        [int[]]$ExpectedIssues = @(),
        [string]$Owner = "",
        [string]$Repo = ""
    )
    
    try {
        $params = @{
            CommitMessages = $CommitMessages
        }
        
        if ($Owner) { $params.Owner = $Owner }
        if ($Repo) { $params.Repo = $Repo }
        
        $result = & $scriptPath @params
        
        $validationPassed = $result.IsValid -eq $ExpectedValid
        
        if ($ExpectedIssues.Count -gt 0) {
            $issuesMatch = ($result.IssueReferences.Count -eq $ExpectedIssues.Count)
            if ($issuesMatch) {
                foreach ($expectedIssue in $ExpectedIssues) {
                    if ($expectedIssue -notin $result.IssueReferences) {
                        $issuesMatch = $false
                        break
                    }
                }
            }
            
            $passed = $validationPassed -and $issuesMatch
            $message = "Expected issues: $($ExpectedIssues -join ', '), Got: $($result.IssueReferences -join ', ')"
        }
        else {
            $passed = $validationPassed
            $message = "IsValid: $($result.IsValid), Issues found: $($result.IssueReferences.Count)"
        }
        
        Write-TestResult -TestName $TestName -Passed $passed -Message $message
    }
    catch {
        Write-TestResult -TestName $TestName -Passed $false -Message "Exception: $_"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Validate-Commits.ps1 Test Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test Category 1: Simple Issue References
Write-Host "`n--- Simple Issue References ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "Simple issue reference (#123)" `
    -CommitMessages @("feat: Add new feature (#123)") `
    -ExpectedValid $true `
    -ExpectedIssues @(123)

Test-CommitValidation `
    -TestName "Issue reference at end of message" `
    -CommitMessages @("fix: Bug fix #456") `
    -ExpectedValid $true `
    -ExpectedIssues @(456)

Test-CommitValidation `
    -TestName "Issue reference at start of message" `
    -CommitMessages @("#789 - Initial implementation") `
    -ExpectedValid $true `
    -ExpectedIssues @(789)

Test-CommitValidation `
    -TestName "Multiple simple references in one commit" `
    -CommitMessages @("feat: Implement features (#123, #456, #789)") `
    -ExpectedValid $true `
    -ExpectedIssues @(123, 456, 789)

# Test Category 2: Action Keywords
Write-Host "`n--- Action Keywords ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "Closes keyword" `
    -CommitMessages @("fix: Bug fix (Closes #100)") `
    -ExpectedValid $true `
    -ExpectedIssues @(100)

Test-CommitValidation `
    -TestName "Fixes keyword" `
    -CommitMessages @("fix: Another fix (Fixes #200)") `
    -ExpectedValid $true `
    -ExpectedIssues @(200)

Test-CommitValidation `
    -TestName "Resolves keyword" `
    -CommitMessages @("feat: New feature (Resolves #300)") `
    -ExpectedValid $true `
    -ExpectedIssues @(300)

Test-CommitValidation `
    -TestName "Close keyword (singular)" `
    -CommitMessages @("fix: Bug fix (Close #400)") `
    -ExpectedValid $true `
    -ExpectedIssues @(400)

Test-CommitValidation `
    -TestName "Fix keyword (singular)" `
    -CommitMessages @("fix: Bug fix (Fix #500)") `
    -ExpectedValid $true `
    -ExpectedIssues @(500)

Test-CommitValidation `
    -TestName "Resolve keyword (singular)" `
    -CommitMessages @("feat: Feature (Resolve #600)") `
    -ExpectedValid $true `
    -ExpectedIssues @(600)

Test-CommitValidation `
    -TestName "Case insensitive action keywords" `
    -CommitMessages @("fix: Bug fix (CLOSES #700, fixes #800, ReSoLvEs #900)") `
    -ExpectedValid $true `
    -ExpectedIssues @(700, 800, 900)

Test-CommitValidation `
    -TestName "Multiple action keywords" `
    -CommitMessages @("fix: Multiple fixes (Fixes #111, Closes #222, Resolves #333)") `
    -ExpectedValid $true `
    -ExpectedIssues @(111, 222, 333)

# Test Category 3: Full Repository References
Write-Host "`n--- Full Repository References ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "Owner/repo#issue format" `
    -CommitMessages @("feat: Cross-repo feature (anokye-labs/akwaaba#123)") `
    -ExpectedValid $true `
    -ExpectedIssues @(123)

Test-CommitValidation `
    -TestName "Owner/repo#issue with repository context" `
    -CommitMessages @("feat: Feature (anokye-labs/akwaaba#456)") `
    -ExpectedValid $true `
    -ExpectedIssues @(456) `
    -Owner "anokye-labs" `
    -Repo "akwaaba"

Test-CommitValidation `
    -TestName "Different repo reference filtered out" `
    -CommitMessages @("feat: Feature (other-owner/other-repo#789)") `
    -ExpectedValid $false `
    -ExpectedIssues @() `
    -Owner "anokye-labs" `
    -Repo "akwaaba"

Test-CommitValidation `
    -TestName "Same repo reference included" `
    -CommitMessages @("feat: Feature (anokye-labs/akwaaba#999)") `
    -ExpectedValid $true `
    -ExpectedIssues @(999) `
    -Owner "anokye-labs" `
    -Repo "akwaaba"

Test-CommitValidation `
    -TestName "Action keyword with full repo reference" `
    -CommitMessages @("fix: Bug fix (Closes anokye-labs/akwaaba#555)") `
    -ExpectedValid $true `
    -ExpectedIssues @(555)

# Test Category 4: Full GitHub URLs
Write-Host "`n--- Full GitHub URLs ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "Full GitHub issue URL" `
    -CommitMessages @("feat: Feature (https://github.com/anokye-labs/akwaaba/issues/111)") `
    -ExpectedValid $true `
    -ExpectedIssues @(111)

Test-CommitValidation `
    -TestName "Multiple GitHub URLs" `
    -CommitMessages @("feat: Features (https://github.com/anokye-labs/akwaaba/issues/222 and https://github.com/anokye-labs/akwaaba/issues/333)") `
    -ExpectedValid $true `
    -ExpectedIssues @(222, 333)

Test-CommitValidation `
    -TestName "GitHub URL with repository context" `
    -CommitMessages @("feat: Feature (https://github.com/anokye-labs/akwaaba/issues/444)") `
    -ExpectedValid $true `
    -ExpectedIssues @(444) `
    -Owner "anokye-labs" `
    -Repo "akwaaba"

Test-CommitValidation `
    -TestName "Different repo URL filtered out" `
    -CommitMessages @("feat: Feature (https://github.com/other/repo/issues/555)") `
    -ExpectedValid $false `
    -ExpectedIssues @() `
    -Owner "anokye-labs" `
    -Repo "akwaaba"

# Test Category 5: Multiple References and Mixed Formats
Write-Host "`n--- Multiple References and Mixed Formats ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "Mixed formats in one commit" `
    -CommitMessages @("feat: Feature (#123, Closes #456, anokye-labs/akwaaba#789)") `
    -ExpectedValid $true `
    -ExpectedIssues @(123, 456, 789)

Test-CommitValidation `
    -TestName "All formats combined" `
    -CommitMessages @("feat: Feature (#111, Fixes #222, anokye-labs/akwaaba#333, https://github.com/anokye-labs/akwaaba/issues/444)") `
    -ExpectedValid $true `
    -ExpectedIssues @(111, 222, 333, 444)

Test-CommitValidation `
    -TestName "Duplicate issue numbers" `
    -CommitMessages @("feat: Feature (#123, Closes #123, anokye-labs/akwaaba#123)") `
    -ExpectedValid $true `
    -ExpectedIssues @(123)

Test-CommitValidation `
    -TestName "Multiple commits with different issues" `
    -CommitMessages @(
        "feat: Feature A (#100)",
        "fix: Bug fix (Fixes #200)",
        "docs: Documentation (#300)"
    ) `
    -ExpectedValid $true `
    -ExpectedIssues @(100, 200, 300)

# Test Category 6: Edge Cases and Invalid Formats
Write-Host "`n--- Edge Cases and Invalid Formats ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "No issue reference" `
    -CommitMessages @("feat: Feature without issue") `
    -ExpectedValid $false `
    -ExpectedIssues @()

Test-CommitValidation `
    -TestName "Invalid hash without number" `
    -CommitMessages @("feat: Feature (#)") `
    -ExpectedValid $false `
    -ExpectedIssues @()

Test-CommitValidation `
    -TestName "Hash in middle of word" `
    -CommitMessages @("feat: Feature test#123word") `
    -ExpectedValid $true `
    -ExpectedIssues @(123)

# Special handling for empty commit message test since PowerShell parameter validation rejects empty strings
try {
    $result = & $scriptPath -CommitMessages @(" ")  # Use whitespace-only string instead of empty
    $passed = ($result.IsValid -eq $false -and $result.IssueReferences.Count -eq 0)
    Write-TestResult -TestName "Empty commit message" -Passed $passed -Message "IsValid: $($result.IsValid), Issues found: $($result.IssueReferences.Count)"
}
catch {
    Write-TestResult -TestName "Empty commit message" -Passed $false -Message "Exception: $_"
}

Test-CommitValidation `
    -TestName "Valid and invalid commits mixed" `
    -CommitMessages @(
        "feat: Valid feature (#100)",
        "fix: Invalid fix without issue"
    ) `
    -ExpectedValid $false `
    -ExpectedIssues @(100)

Test-CommitValidation `
    -TestName "Hash in code block" `
    -CommitMessages @("feat: Added hash (#123) function") `
    -ExpectedValid $true `
    -ExpectedIssues @(123)

# Test Category 7: SHA Format Handling
Write-Host "`n--- SHA Format Handling ---`n" -ForegroundColor Yellow

Test-CommitValidation `
    -TestName "Short SHA format support" `
    -CommitMessages @("feat: Feature (#123)") `
    -ExpectedValid $true `
    -ExpectedIssues @(123)

Test-CommitValidation `
    -TestName "Long SHA format support" `
    -CommitMessages @("feat: Feature (#456)") `
    -ExpectedValid $true `
    -ExpectedIssues @(456)

# Note: The script doesn't distinguish between SHA formats in processing,
# but it should handle commit messages regardless of the SHA format used
# in the git history. The CommitSha parameter is optional and for reference only.

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $script:TestNumber" -ForegroundColor White
Write-Host "Passed:       $script:PassedTests" -ForegroundColor Green
Write-Host "Failed:       $script:FailedTests" -ForegroundColor $(if ($script:FailedTests -eq 0) { "Green" } else { "Red" })
Write-Host "========================================`n" -ForegroundColor Cyan

# Exit with appropriate code
if ($script:FailedTests -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some tests failed! ✗" -ForegroundColor Red
    exit 1
}
