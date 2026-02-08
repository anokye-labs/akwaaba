<#
.SYNOPSIS
    Test script for Get-PRsByIssue.ps1

.DESCRIPTION
    Validates that Get-PRsByIssue.ps1 properly searches for PRs linked to issues
    and produces correct output in DryRun mode and various output formats.
#>

Write-Host "Testing Get-PRsByIssue.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-ScriptExecution {
    param(
        [string]$TestName,
        [string]$Command,
        [string]$ExpectedPattern,
        [switch]$ShouldFail
    )
    
    try {
        Write-Host "Running: $TestName" -ForegroundColor Cyan
        
        $output = Invoke-Expression $Command 2>&1 | Out-String
        
        if ($ShouldFail) {
            Write-Host "✗ FAIL: $TestName (expected to fail but succeeded)" -ForegroundColor Red
            $script:testsFailed++
            return $false
        }
        
        if ($output -match $ExpectedPattern) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
            Write-Host "  Expected pattern: $ExpectedPattern" -ForegroundColor Yellow
            Write-Host "  Output sample: $($output.Substring(0, [Math]::Min(300, $output.Length)))" -ForegroundColor Yellow
            $script:testsFailed++
            return $false
        }
    } catch {
        if ($ShouldFail) {
            Write-Host "✓ PASS: $TestName (failed as expected)" -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
            Write-Host "  Error: $_" -ForegroundColor Yellow
            $script:testsFailed++
            return $false
        }
    }
}

# Test 1: DryRun mode with single issue
Write-Host "Test 1: DryRun mode with single issue number" -ForegroundColor Cyan
$cmd1 = "pwsh -File `"$PSScriptRoot/Get-PRsByIssue.ps1`" -IssueNumbers 14 -Owner anokye-labs -Repo akwaaba -DryRun"
Test-ScriptExecution -TestName "DryRun single issue" -Command $cmd1 -ExpectedPattern "(DryRun|query)"
Write-Host ""

# Test 2: DryRun mode with multiple issues
Write-Host "Test 2: DryRun mode with multiple issue numbers" -ForegroundColor Cyan
$cmd2 = "pwsh -File `"$PSScriptRoot/Get-PRsByIssue.ps1`" -IssueNumbers 14,15,17 -Owner anokye-labs -Repo akwaaba -DryRun"
Test-ScriptExecution -TestName "DryRun multiple issues" -Command $cmd2 -ExpectedPattern "(DryRun|query)"
Write-Host ""

# Test 3: Console output format
Write-Host "Test 3: Console output format (DryRun)" -ForegroundColor Cyan
$cmd3 = "pwsh -File `"$PSScriptRoot/Get-PRsByIssue.ps1`" -IssueNumbers 1 -Owner anokye-labs -Repo akwaaba -OutputFormat Console -DryRun"
Test-ScriptExecution -TestName "Console output format" -Command $cmd3 -ExpectedPattern "(Pull Requests|DryRun)"
Write-Host ""

# Test 4: Markdown output format
Write-Host "Test 4: Markdown output format (DryRun)" -ForegroundColor Cyan
$cmd4 = "pwsh -File `"$PSScriptRoot/Get-PRsByIssue.ps1`" -IssueNumbers 1 -Owner anokye-labs -Repo akwaaba -OutputFormat Markdown -DryRun"
Test-ScriptExecution -TestName "Markdown output format" -Command $cmd4 -ExpectedPattern "(Pull Requests|#|DryRun)"
Write-Host ""

# Test 5: JSON output format
Write-Host "Test 5: JSON output format (DryRun)" -ForegroundColor Cyan
$cmd5 = "pwsh -File `"$PSScriptRoot/Get-PRsByIssue.ps1`" -IssueNumbers 1 -Owner anokye-labs -Repo akwaaba -OutputFormat Json -DryRun"
Test-ScriptExecution -TestName "JSON output format" -Command $cmd5 -ExpectedPattern '(\{|\}|"IssueNumbers"|DryRun)'
Write-Host ""

# Test 6: Validate script can be imported (help available)
Write-Host "Test 6: Script can be imported (help available)" -ForegroundColor Cyan
try {
    $help = Get-Help "$PSScriptRoot/Get-PRsByIssue.ps1" -ErrorAction Stop
    if ($help.Synopsis) {
        Write-Host "✓ PASS: Script help available" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Script help not available" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ FAIL: Cannot get script help: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Summary
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. Please review." -ForegroundColor Red
    exit 1
}
