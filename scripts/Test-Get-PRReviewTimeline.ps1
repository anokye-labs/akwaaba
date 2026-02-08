<#
.SYNOPSIS
    Test script for Get-PRReviewTimeline.ps1

.DESCRIPTION
    Validates that Get-PRReviewTimeline.ps1 properly constructs GraphQL queries
    and produces correct output in DryRun mode.
#>

Write-Host "Testing Get-PRReviewTimeline.ps1..." -ForegroundColor Cyan
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
        $output = Invoke-Expression $Command 2>&1 | Out-String
        
        if ($ShouldFail) {
            Write-Host "✗ FAIL: $TestName (expected failure but succeeded)" -ForegroundColor Red
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
            Write-Host "  Output: $($output.Substring(0, [Math]::Min(300, $output.Length)))" -ForegroundColor Yellow
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

# Test 1: DryRun mode with valid parameters
Write-Host "Test 1: DryRun mode with valid parameters" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -DryRun"
Test-ScriptExecution -TestName "DryRun mode" -Command $cmd -ExpectedPattern "DryRun Mode|query"

# Test 2: Verify GraphQL query structure in DryRun
Write-Host ""
Write-Host "Test 2: GraphQL query structure" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -DryRun"
Test-ScriptExecution -TestName "Query contains pullRequest" -Command $cmd -ExpectedPattern "pullRequest"

# Test 3: Verify query includes timeline items
Write-Host ""
Write-Host "Test 3: Query includes timeline items" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -DryRun"
Test-ScriptExecution -TestName "Query contains timelineItems" -Command $cmd -ExpectedPattern "timelineItems"

# Test 4: Test different output formats
Write-Host ""
Write-Host "Test 4: Output format - Console" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -OutputFormat Console -DryRun"
Test-ScriptExecution -TestName "Console format DryRun" -Command $cmd -ExpectedPattern "DryRun Mode"

Write-Host ""
Write-Host "Test 5: Output format - Markdown" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -OutputFormat Markdown -DryRun"
Test-ScriptExecution -TestName "Markdown format DryRun" -Command $cmd -ExpectedPattern "DryRun Mode"

Write-Host ""
Write-Host "Test 6: Output format - Json" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -OutputFormat Json -DryRun"
Test-ScriptExecution -TestName "Json format DryRun" -Command $cmd -ExpectedPattern "DryRun Mode"

# Test 7: Verify IncludeComments flag is accepted
Write-Host ""
Write-Host "Test 7: IncludeComments flag" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -IncludeComments -DryRun"
Test-ScriptExecution -TestName "IncludeComments flag accepted" -Command $cmd -ExpectedPattern "DryRun Mode"

# Test 8: Verify script accepts CorrelationId parameter
Write-Host ""
Write-Host "Test 8: CorrelationId parameter" -ForegroundColor Cyan
$cmd = "pwsh -File `"$PSScriptRoot/Get-PRReviewTimeline.ps1`" -Owner anokye-labs -Repo akwaaba -PullNumber 1 -CorrelationId 'test-123' -DryRun"
Test-ScriptExecution -TestName "CorrelationId parameter accepted" -Command $cmd -ExpectedPattern "DryRun Mode"

# Note: Tests for missing mandatory parameters are skipped because PowerShell will prompt for them
# interactively, which cannot be easily tested in this script. The parameter validation is enforced
# by PowerShell itself through the [Parameter(Mandatory = $true)] attribute.

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
