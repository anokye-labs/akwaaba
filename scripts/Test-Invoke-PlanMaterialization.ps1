<#
.SYNOPSIS
    Test script for Invoke-PlanMaterialization.ps1

.DESCRIPTION
    Validates that Invoke-PlanMaterialization.ps1 properly orchestrates
    the complete plan materialization workflow in DryRun mode.
#>

Write-Host "Testing Invoke-PlanMaterialization.ps1..." -ForegroundColor Cyan
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
            Write-Host "  Output preview: $($output.Substring(0, [Math]::Min(300, $output.Length)))" -ForegroundColor Yellow
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

# Test 1: DryRun mode with default planning directory
Write-Host "Test 1: DryRun mode with all phases" -ForegroundColor Cyan
$planDir = "$PSScriptRoot/../planning"
if (Test-Path $planDir) {
    $cmd = "pwsh -File `"$PSScriptRoot/Invoke-PlanMaterialization.ps1`" -PlanDirectory `"$planDir`" -Owner anokye-labs -Repo akwaaba -DryRun"
    Test-DryRunOutput -TestName "DryRun all phases" -Command $cmd -ExpectedPattern "DryRun.*Phase"
} else {
    Write-Host "⊘ SKIP: DryRun all phases (planning directory not found)" -ForegroundColor Yellow
}

# Test 2: DryRun mode with single phase filter
Write-Host ""
Write-Host "Test 2: DryRun mode with Phase filter" -ForegroundColor Cyan
if (Test-Path $planDir) {
    $cmd = "pwsh -File `"$PSScriptRoot/Invoke-PlanMaterialization.ps1`" -PlanDirectory `"$planDir`" -Owner anokye-labs -Repo akwaaba -Phase 1 -DryRun"
    Test-DryRunOutput -TestName "DryRun phase 1 only" -Command $cmd -ExpectedPattern "phase-1"
} else {
    Write-Host "⊘ SKIP: DryRun phase filter (planning directory not found)" -ForegroundColor Yellow
}

# Test 3: Verify error handling for missing planning directory
Write-Host ""
Write-Host "Test 3: Error handling for missing directory" -ForegroundColor Cyan
try {
    $cmd = "pwsh -File `"$PSScriptRoot/Invoke-PlanMaterialization.ps1`" -PlanDirectory `"$PSScriptRoot/nonexistent`" -Owner anokye-labs -Repo akwaaba -DryRun 2>&1"
    $output = Invoke-Expression $cmd
    
    if ($output -match "not found|does not exist") {
        Write-Host "✓ PASS: Error handling for missing directory" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Error handling for missing directory" -ForegroundColor Red
        Write-Host "  Output: $output" -ForegroundColor Yellow
        $testsFailed++
    }
} catch {
    # Expected to throw
    if ($_.Exception.Message -match "not found|does not exist") {
        Write-Host "✓ PASS: Error handling for missing directory" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Error handling for missing directory" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $testsFailed++
    }
}

# Test 4: Verify error handling for non-existent phase
Write-Host ""
Write-Host "Test 4: Error handling for non-existent phase" -ForegroundColor Cyan
if (Test-Path $planDir) {
    try {
        $cmd = "pwsh -File `"$PSScriptRoot/Invoke-PlanMaterialization.ps1`" -PlanDirectory `"$planDir`" -Owner anokye-labs -Repo akwaaba -Phase 999 -DryRun 2>&1"
        $output = Invoke-Expression $cmd
        
        if ($output -match "No phase directories found") {
            Write-Host "✓ PASS: Error handling for non-existent phase" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Error handling for non-existent phase" -ForegroundColor Red
            Write-Host "  Output: $output" -ForegroundColor Yellow
            $testsFailed++
        }
    } catch {
        # Expected to throw
        if ($_.Exception.Message -match "No phase directories found") {
            Write-Host "✓ PASS: Error handling for non-existent phase" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Error handling for non-existent phase" -ForegroundColor Red
            Write-Host "  Error: $_" -ForegroundColor Yellow
            $testsFailed++
        }
    }
} else {
    Write-Host "⊘ SKIP: Non-existent phase test (planning directory not found)" -ForegroundColor Yellow
}

# Test 5: Verify correlation ID is generated
Write-Host ""
Write-Host "Test 5: Correlation ID generation" -ForegroundColor Cyan
if (Test-Path $planDir) {
    $cmd = "pwsh -File `"$PSScriptRoot/Invoke-PlanMaterialization.ps1`" -PlanDirectory `"$planDir`" -Owner anokye-labs -Repo akwaaba -Phase 1 -DryRun"
    Test-DryRunOutput -TestName "Correlation ID present" -Command $cmd -ExpectedPattern "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
} else {
    Write-Host "⊘ SKIP: Correlation ID test (planning directory not found)" -ForegroundColor Yellow
}

# Test 6: Verify summary output
Write-Host ""
Write-Host "Test 6: Summary output format" -ForegroundColor Cyan
if (Test-Path $planDir) {
    $cmd = "pwsh -File `"$PSScriptRoot/Invoke-PlanMaterialization.ps1`" -PlanDirectory `"$planDir`" -Owner anokye-labs -Repo akwaaba -Phase 1 -DryRun"
    Test-DryRunOutput -TestName "Summary contains statistics" -Command $cmd -ExpectedPattern "Materialization Summary"
} else {
    Write-Host "⊘ SKIP: Summary output test (planning directory not found)" -ForegroundColor Yellow
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
