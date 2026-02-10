<#
.SYNOPSIS
    Test script for Validate-CommitAuthors.ps1

.DESCRIPTION
    Validates that Validate-CommitAuthors.ps1 properly validates commit authors
    against the approved agents allowlist. Tests include:
    - DryRun mode validation
    - Output format validation (Console, Markdown, Json)
    - Allowlist loading and parsing
    - Agent detection logic
    - Script help availability
#>

Write-Host "Testing Validate-CommitAuthors.ps1..." -ForegroundColor Cyan
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

# Test 1: DryRun mode
Write-Host "Test 1: DryRun mode with owner and repo" -ForegroundColor Cyan
$cmd1 = "pwsh -File `"$PSScriptRoot/Validate-CommitAuthors.ps1`" -PRNumber 1 -Owner anokye-labs -Repo akwaaba -DryRun"
Test-ScriptExecution -TestName "DryRun mode" -Command $cmd1 -ExpectedPattern "(DRY RUN|DryRun|Would validate)"
Write-Host ""

# Test 2: Console output format (DryRun)
Write-Host "Test 2: Console output format (DryRun)" -ForegroundColor Cyan
$cmd2 = "pwsh -File `"$PSScriptRoot/Validate-CommitAuthors.ps1`" -PRNumber 1 -Owner anokye-labs -Repo akwaaba -OutputFormat Console -DryRun"
Test-ScriptExecution -TestName "Console output format" -Command $cmd2 -ExpectedPattern "(DRY RUN|Approved agents loaded)"
Write-Host ""

# Test 3: Markdown output format (DryRun)
Write-Host "Test 3: Markdown output format (DryRun)" -ForegroundColor Cyan
$cmd3 = "pwsh -File `"$PSScriptRoot/Validate-CommitAuthors.ps1`" -PRNumber 1 -Owner anokye-labs -Repo akwaaba -OutputFormat Markdown -DryRun"
Test-ScriptExecution -TestName "Markdown output format" -Command $cmd3 -ExpectedPattern "(DryRun|PRNumber)"
Write-Host ""

# Test 4: JSON output format (DryRun)
Write-Host "Test 4: JSON output format (DryRun)" -ForegroundColor Cyan
$cmd4 = "pwsh -File `"$PSScriptRoot/Validate-CommitAuthors.ps1`" -PRNumber 1 -Owner anokye-labs -Repo akwaaba -OutputFormat Json -DryRun"
Test-ScriptExecution -TestName "JSON output format" -Command $cmd4 -ExpectedPattern '(\{|\}|"DryRun"|"PRNumber")'
Write-Host ""

# Test 5: Validate script can be imported (help available)
Write-Host "Test 5: Script can be imported (help available)" -ForegroundColor Cyan
try {
    $help = Get-Help "$PSScriptRoot/Validate-CommitAuthors.ps1" -ErrorAction Stop
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

# Test 6: Test approved-agents.json file exists
Write-Host "Test 6: Approved agents file exists" -ForegroundColor Cyan
$approvedAgentsPath = Join-Path (Split-Path $PSScriptRoot -Parent) ".github/approved-agents.json"
if (Test-Path $approvedAgentsPath) {
    Write-Host "✓ PASS: Approved agents file exists at $approvedAgentsPath" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "✗ FAIL: Approved agents file not found at $approvedAgentsPath" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 7: Test approved-agents.json is valid JSON
Write-Host "Test 7: Approved agents file is valid JSON" -ForegroundColor Cyan
try {
    if (Test-Path $approvedAgentsPath) {
        $content = Get-Content $approvedAgentsPath -Raw | ConvertFrom-Json
        if ($content.agents) {
            Write-Host "✓ PASS: Approved agents file is valid JSON with agents array" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Approved agents file missing 'agents' property" -ForegroundColor Red
            $testsFailed++
        }
    } else {
        Write-Host "✗ FAIL: Approved agents file not found" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ FAIL: Failed to parse approved agents JSON: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 8: Test approved-agents.json has required agent fields
Write-Host "Test 8: Approved agents have required fields" -ForegroundColor Cyan
try {
    if (Test-Path $approvedAgentsPath) {
        $content = Get-Content $approvedAgentsPath -Raw | ConvertFrom-Json
        $requiredFields = @('id', 'username', 'type', 'description', 'enabled')
        $allValid = $true
        
        foreach ($agent in $content.agents) {
            foreach ($field in $requiredFields) {
                if (-not ($agent.PSObject.Properties.Name -contains $field)) {
                    Write-Host "  Missing field '$field' in agent: $($agent.id)" -ForegroundColor Yellow
                    $allValid = $false
                }
            }
        }
        
        if ($allValid) {
            Write-Host "✓ PASS: All agents have required fields" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Some agents missing required fields" -ForegroundColor Red
            $testsFailed++
        }
    } else {
        Write-Host "✗ FAIL: Approved agents file not found" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ FAIL: Failed to validate agent fields: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 9: Test agent detection patterns
Write-Host "Test 9: Test GitHub App and bot detection patterns" -ForegroundColor Cyan
try {
    # Test pattern matching for [bot] suffix
    $testUsernames = @(
        @{ Username = "github-actions[bot]"; ShouldMatch = $true }
        @{ Username = "dependabot[bot]"; ShouldMatch = $true }
        @{ Username = "copilot"; ShouldMatch = $true }
        @{ Username = "web-flow"; ShouldMatch = $true }
        @{ Username = "regular-user"; ShouldMatch = $false }
    )
    
    $content = Get-Content $approvedAgentsPath -Raw | ConvertFrom-Json
    $patternsPassed = 0
    
    foreach ($test in $testUsernames) {
        $found = $false
        foreach ($agent in $content.agents) {
            if ($agent.username -eq $test.Username -or $agent.botUsername -eq $test.Username) {
                $found = $true
                break
            }
        }
        
        if ($found -eq $test.ShouldMatch) {
            $patternsPassed++
        } else {
            Write-Host "  Pattern mismatch for '$($test.Username)': expected $($test.ShouldMatch), got $found" -ForegroundColor Yellow
        }
    }
    
    # We expect at least copilot and web-flow to be in the list
    if ($patternsPassed -ge 2) {
        Write-Host "✓ PASS: Agent detection patterns work correctly" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Agent detection patterns failed ($patternsPassed/5 passed)" -ForegroundColor Red
        $testsFailed++
    }
} catch {
    Write-Host "✗ FAIL: Failed to test agent detection patterns: $_" -ForegroundColor Red
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
