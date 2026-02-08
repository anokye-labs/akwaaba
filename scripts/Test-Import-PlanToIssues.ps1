<#
.SYNOPSIS
    Test script for Import-PlanToIssues.ps1

.DESCRIPTION
    Validates that Import-PlanToIssues.ps1 properly parses planning markdown files
    and produces correct output in DryRun mode.
#>

# Note: We don't dot-source the main script because it has mandatory parameters
# Instead, we'll test the helper function by extracting it or running the script in subprocess

Write-Host "Testing Import-PlanToIssues.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-DryRunOutput {
    param(
        [string]$TestName,
        [string]$Command,
        [string]$ExpectedPattern
    )
    
    try {
        $output = Invoke-Expression $Command 2>&1 | Out-String
        
        if ($output -match $ExpectedPattern) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        } else {
            Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
            Write-Host "  Expected pattern: $ExpectedPattern" -ForegroundColor Yellow
            Write-Host "  Output: $($output.Substring(0, [Math]::Min(200, $output.Length)))" -ForegroundColor Yellow
            $script:testsFailed++
            return $false
        }
    } catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

# Test 1: Test DryRun mode with a single file
$testFile = "$PSScriptRoot/../planning/phase-2-governance/01-ruleset-protect-main.md"
if (Test-Path $testFile) {
    Write-Host "Test 1: DryRun mode with single file" -ForegroundColor Cyan
    $cmd = "pwsh -File `"$PSScriptRoot/Import-PlanToIssues.ps1`" -PlanFile `"$testFile`" -Owner anokye-labs -Repo akwaaba -DryRun"
    Test-DryRunOutput -TestName "DryRun single file" -Command $cmd -ExpectedPattern "Would create"
} else {
    Write-Host "⊘ SKIP: DryRun single file (test file not found)" -ForegroundColor Yellow
}

# Test 2: Verify error handling for missing file
Write-Host ""
Write-Host "Test 2: Error handling for missing file" -ForegroundColor Cyan
try {
    $cmd = "pwsh -File `"$PSScriptRoot/Import-PlanToIssues.ps1`" -PlanFile `"$PSScriptRoot/nonexistent.md`" -Owner anokye-labs -Repo akwaaba -DryRun 2>&1"
    $output = Invoke-Expression $cmd
    
    if ($output -match "not found") {
        Write-Host "✓ PASS: Error handling for missing file" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Error handling for missing file" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    # Expected to throw
    Write-Host "✓ PASS: Error handling for missing file" -ForegroundColor Green
    $testsPassed++
}

# Summary
Write-Host ""
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
