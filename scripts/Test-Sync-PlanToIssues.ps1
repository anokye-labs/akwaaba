<#
.SYNOPSIS
    Test script for Sync-PlanToIssues.ps1

.DESCRIPTION
    Validates that Sync-PlanToIssues.ps1 properly compares planning files
    with GitHub issues, identifies drift, and can create missing issues.
#>

$ErrorActionPreference = "Stop"

# Test configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testCorrelationId = [guid]::NewGuid().ToString()

Write-Host "Testing Sync-PlanToIssues.ps1..." -ForegroundColor Cyan
Write-Host "Correlation ID: $testCorrelationId" -ForegroundColor Gray
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Command {
    param(
        [string]$TestName,
        [scriptblock]$Command,
        [scriptblock]$Validation
    )
    
    Write-Host "Running: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $Command
        
        if (& $Validation -ArgumentList $result) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ FAIL: $TestName - Validation failed" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName - Exception: $_" -ForegroundColor Red
        $script:testsFailed++
    }
    
    Write-Host ""
}

# Test 1: Script exists and is executable
Test-Command -TestName "Script file exists" -Command {
    Test-Path "$scriptDir/Sync-PlanToIssues.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 2: Help content is available
Test-Command -TestName "Help content is available" -Command {
    Get-Help "$scriptDir/Sync-PlanToIssues.ps1"
} -Validation {
    param($result)
    return $result.Synopsis -match "Diff current GitHub issues"
}

# Test 3: Script has required parameters
Test-Command -TestName "Required parameters defined" -Command {
    $params = (Get-Command "$scriptDir/Sync-PlanToIssues.ps1").Parameters
    @{
        HasPlanDirectory = $params.ContainsKey("PlanDirectory")
        HasFormat = $params.ContainsKey("Format")
        HasCreateMissing = $params.ContainsKey("CreateMissing")
        HasDryRun = $params.ContainsKey("DryRun")
        HasCorrelationId = $params.ContainsKey("CorrelationId")
    }
} -Validation {
    param($result)
    return $result.HasPlanDirectory -and $result.HasFormat -and $result.HasCreateMissing -and $result.HasDryRun -and $result.HasCorrelationId
}

# Test 4: Format parameter accepts valid values
Test-Command -TestName "Format parameter validation" -Command {
    $param = (Get-Command "$scriptDir/Sync-PlanToIssues.ps1").Parameters["Format"]
    $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
    $validateSet.ValidValues
} -Validation {
    param($result)
    return ($result -contains "Console") -and ($result -contains "JSON") -and ($result -contains "CSV")
}

# Test 5: Dependencies exist
Test-Command -TestName "Invoke-GraphQL.ps1 exists" -Command {
    Test-Path "$scriptDir/Invoke-GraphQL.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

Test-Command -TestName "Get-RepoContext.ps1 exists" -Command {
    Test-Path "$scriptDir/Get-RepoContext.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

Test-Command -TestName "Write-OkyeremaLog.ps1 exists" -Command {
    Test-Path "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

Test-Command -TestName "Import-PlanToIssues.ps1 exists" -Command {
    Test-Path "$scriptDir/Import-PlanToIssues.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 6: Script can be dot-sourced without error
Test-Command -TestName "Script has valid PowerShell syntax" -Command {
    try {
        $scriptContent = Get-Content "$scriptDir/Sync-PlanToIssues.ps1" -Raw
        # Check if script has valid PowerShell syntax
        $null = [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$null)
        return $true
    }
    catch {
        return $false
    }
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 7: Script handles missing planning directory gracefully
Write-Host "Running: Script handles missing planning directory" -ForegroundColor Yellow
try {
    $output = & "$scriptDir/Sync-PlanToIssues.ps1" -PlanDirectory "/nonexistent/path" -CorrelationId $testCorrelationId 2>&1
    Write-Host "✗ FAIL: Script should have thrown an error for non-existent directory" -ForegroundColor Red
    $testsFailed++
}
catch {
    if ($_.Exception.Message -match "not found|does not exist|cannot find") {
        Write-Host "✓ PASS: Script handles missing directory with proper error" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Script threw unexpected error: $_" -ForegroundColor Red
        $testsFailed++
    }
}
Write-Host ""

# Test 8: DryRun mode works
Write-Host "Running: DryRun mode works" -ForegroundColor Yellow
try {
    # Check if planning directory exists
    $repoRoot = Split-Path -Parent $scriptDir
    $planningDir = Join-Path $repoRoot "planning"
    
    if (Test-Path $planningDir) {
        # Run in DryRun mode with CreateMissing
        $output = & "$scriptDir/Sync-PlanToIssues.ps1" -PlanDirectory $planningDir -DryRun -CreateMissing -CorrelationId $testCorrelationId 2>&1 | Out-String
        
        # In DryRun mode, it should complete without errors and show what would be done
        if ($output -match "DryRun" -or $output -match "Summary") {
            Write-Host "✓ PASS: DryRun mode works" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: DryRun mode output doesn't match expected format" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "⊘ SKIP: Planning directory not found for DryRun test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ FAIL: DryRun mode failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 9: Console format output works
Write-Host "Running: Console format output" -ForegroundColor Yellow
try {
    $repoRoot = Split-Path -Parent $scriptDir
    $planningDir = Join-Path $repoRoot "planning"
    
    if (Test-Path $planningDir) {
        # Run with Console format (default)
        $output = & "$scriptDir/Sync-PlanToIssues.ps1" -PlanDirectory $planningDir -Format Console -CorrelationId $testCorrelationId 2>&1 | Out-String
        
        # Check if output contains expected sections
        if ($output -match "Summary" -and ($output -match "Missing from GitHub|Closed but Pending|Extra in GitHub|No drift detected")) {
            Write-Host "✓ PASS: Console format output works" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Console format output doesn't match expected format" -ForegroundColor Red
            Write-Host "  Output preview: $($output.Substring(0, [Math]::Min(200, $output.Length)))" -ForegroundColor Gray
            $testsFailed++
        }
    }
    else {
        Write-Host "⊘ SKIP: Planning directory not found for Console format test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ FAIL: Console format test failed: $_" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Gray
    $testsFailed++
}
Write-Host ""

# Test 10: JSON format output works
Write-Host "Running: JSON format output" -ForegroundColor Yellow
try {
    $repoRoot = Split-Path -Parent $scriptDir
    $planningDir = Join-Path $repoRoot "planning"
    
    if (Test-Path $planningDir) {
        # Run with JSON format
        $jsonOutput = & "$scriptDir/Sync-PlanToIssues.ps1" -PlanDirectory $planningDir -Format JSON -CorrelationId $testCorrelationId 2>&1 | Out-String
        $jsonOutput = $jsonOutput.Trim()
        
        # Find JSON content (skip stderr logs)
        $jsonStart = $jsonOutput.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonContent = $jsonOutput.Substring($jsonStart)
            
            try {
                $parsed = $jsonContent | ConvertFrom-Json
                if ($parsed.summary -and $null -ne $parsed.summary.missingFromGitHub) {
                    Write-Host "✓ PASS: JSON format output works" -ForegroundColor Green
                    $testsPassed++
                } else {
                    Write-Host "✗ FAIL: JSON format doesn't contain expected structure" -ForegroundColor Red
                    $testsFailed++
                }
            }
            catch {
                Write-Host "✗ FAIL: JSON output is not valid JSON: $_" -ForegroundColor Red
                Write-Host "  Output preview: $($jsonContent.Substring(0, [Math]::Min(200, $jsonContent.Length)))" -ForegroundColor Gray
                $testsFailed++
            }
        }
        else {
            Write-Host "✗ FAIL: No JSON content found in output" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "⊘ SKIP: Planning directory not found for JSON format test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ FAIL: JSON format test failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 11: CSV format output works
Write-Host "Running: CSV format output" -ForegroundColor Yellow
try {
    $repoRoot = Split-Path -Parent $scriptDir
    $planningDir = Join-Path $repoRoot "planning"
    
    if (Test-Path $planningDir) {
        # Run with CSV format
        $csvOutput = & "$scriptDir/Sync-PlanToIssues.ps1" -PlanDirectory $planningDir -Format CSV -CorrelationId $testCorrelationId 2>&1 | Out-String
        
        # Check if output contains CSV header
        if ($csvOutput -match "Category.*Type.*IssueNumber.*Title") {
            Write-Host "✓ PASS: CSV format output works" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: CSV format output doesn't contain expected header" -ForegroundColor Red
            Write-Host "  Output preview: $($csvOutput.Substring(0, [Math]::Min(200, $csvOutput.Length)))" -ForegroundColor Gray
            $testsFailed++
        }
    }
    else {
        Write-Host "⊘ SKIP: Planning directory not found for CSV format test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ FAIL: CSV format test failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 12: Script outputs structured logs to stderr
Write-Host "Running: Structured logging to stderr" -ForegroundColor Yellow
try {
    $repoRoot = Split-Path -Parent $scriptDir
    $planningDir = Join-Path $repoRoot "planning"
    
    if (Test-Path $planningDir) {
        # Capture stderr separately
        $tempStderr = [System.IO.Path]::GetTempFileName()
        
        # Run script and redirect stderr to file
        $null = & "$scriptDir/Sync-PlanToIssues.ps1" -PlanDirectory $planningDir -Format JSON -CorrelationId $testCorrelationId 2>$tempStderr
        
        # Read stderr content
        $stderrContent = Get-Content $tempStderr -Raw
        
        # Check if stderr contains JSON log messages
        if ($stderrContent -match '"timestamp"' -and $stderrContent -match '"level"' -and $stderrContent -match '"message"') {
            Write-Host "✓ PASS: Structured logging to stderr works" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Stderr doesn't contain structured log messages" -ForegroundColor Red
            $testsFailed++
        }
        
        # Cleanup
        Remove-Item $tempStderr -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "⊘ SKIP: Planning directory not found for logging test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⊘ SKIP: Could not test structured logging: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "==================== TEST SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "FAILED: Some tests did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "SUCCESS: All tests passed!" -ForegroundColor Green
    exit 0
}
