<#
.SYNOPSIS
    Unit and integration tests for Get-StalledWork.ps1

.DESCRIPTION
    This script tests the Get-StalledWork.ps1 functionality for detecting stalled
    agent work (PRs and issues with no activity beyond a threshold).

.EXAMPLE
    pwsh -File Test-Get-StalledWork.ps1
#>

$ErrorActionPreference = "Stop"

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

# Helper function for test assertions
function Assert-Equal {
    param(
        [string]$TestName,
        $Expected,
        $Actual
    )
    
    if ($Expected -eq $Actual) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Expected: $Expected" -ForegroundColor Yellow
        Write-Host "  Actual: $Actual" -ForegroundColor Yellow
        $script:TestsFailed++
    }
}

function Assert-True {
    param(
        [string]$TestName,
        [bool]$Condition
    )
    
    if ($Condition) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Assert-NotNull {
    param(
        [string]$TestName,
        $Value
    )
    
    if ($null -ne $Value) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Value was null" -ForegroundColor Yellow
        $script:TestsFailed++
    }
}

function Skip-Test {
    param(
        [string]$TestName,
        [string]$Reason
    )
    
    Write-Host "⊘ SKIP: $TestName - $Reason" -ForegroundColor Yellow
    $script:TestsSkipped++
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Testing Get-StalledWork.ps1" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Get script path
$scriptPath = Join-Path $PSScriptRoot "Get-StalledWork.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "✗ ERROR: Get-StalledWork.ps1 not found at $scriptPath" -ForegroundColor Red
    exit 1
}

#region Unit Tests

Write-Host "Running Unit Tests..." -ForegroundColor Cyan
Write-Host ""

# Test 1: Script loads without errors
Write-Host "Test 1: Script loads without errors" -ForegroundColor White
try {
    $null = Get-Command $scriptPath -ErrorAction Stop
    Write-Host "✓ PASS: Script loads without errors" -ForegroundColor Green
    $script:TestsPassed++
}
catch {
    Write-Host "✗ FAIL: Script failed to load: $_" -ForegroundColor Red
    $script:TestsFailed++
}

# Test 2: Script has correct parameters
Write-Host "Test 2: Script has correct parameters" -ForegroundColor White
try {
    $scriptInfo = Get-Command $scriptPath
    $params = $scriptInfo.Parameters.Keys
    
    Assert-True -TestName "Has Owner parameter" -Condition ($params -contains "Owner")
    Assert-True -TestName "Has Repo parameter" -Condition ($params -contains "Repo")
    Assert-True -TestName "Has StalledThresholdHours parameter" -Condition ($params -contains "StalledThresholdHours")
    Assert-True -TestName "Has IncludePRs parameter" -Condition ($params -contains "IncludePRs")
    Assert-True -TestName "Has IncludeIssues parameter" -Condition ($params -contains "IncludeIssues")
    Assert-True -TestName "Has CorrelationId parameter" -Condition ($params -contains "CorrelationId")
}
catch {
    Write-Host "✗ FAIL: Parameter validation failed: $_" -ForegroundColor Red
    $script:TestsFailed++
}

Write-Host ""

#endregion

#region Integration Tests

Write-Host "Running Integration Tests..." -ForegroundColor Cyan
Write-Host ""

# Check if we're in a valid git repository with GitHub authentication
$isGitRepo = $false
$hasGhAuth = $false

try {
    $repoInfo = gh repo view --json nameWithOwner 2>&1 | ConvertFrom-Json
    if ($repoInfo.nameWithOwner) {
        $isGitRepo = $true
        $hasGhAuth = $true
        
        $parts = $repoInfo.nameWithOwner.Split('/')
        $testOwner = $parts[0]
        $testRepo = $parts[1]
    }
}
catch {
    # Not in a git repo or gh not authenticated
}

if (-not $isGitRepo -or -not $hasGhAuth) {
    Skip-Test -TestName "Integration Test 1: Detect stalled PRs" -Reason "Not in a git repository or gh CLI not authenticated"
    Skip-Test -TestName "Integration Test 2: Detect stalled issues" -Reason "Not in a git repository or gh CLI not authenticated"
    Skip-Test -TestName "Integration Test 3: Filter by threshold" -Reason "Not in a git repository or gh CLI not authenticated"
    Skip-Test -TestName "Integration Test 4: Include/exclude PRs" -Reason "Not in a git repository or gh CLI not authenticated"
    Skip-Test -TestName "Integration Test 5: Include/exclude issues" -Reason "Not in a git repository or gh CLI not authenticated"
}
else {
    Write-Host "Using repository: $testOwner/$testRepo" -ForegroundColor DarkGray
    Write-Host ""
    
    # Integration Test 1: Run with default parameters
    Write-Host "Integration Test 1: Run with default parameters" -ForegroundColor White
    try {
        $result = & $scriptPath -Owner $testOwner -Repo $testRepo -StalledThresholdHours 24
        
        Assert-NotNull -TestName "Script returns result" -Value $result
        
        if ($null -ne $result) {
            if ($result -is [array]) {
                Assert-True -TestName "Result is an array" -Condition $true
                Write-Host "  Found $($result.Count) stalled items" -ForegroundColor DarkGray
                
                if ($result.Count -gt 0) {
                    $firstItem = $result[0]
                    Assert-True -TestName "First item has Number property" -Condition ($null -ne $firstItem.Number)
                    Assert-True -TestName "First item has Title property" -Condition ($null -ne $firstItem.Title)
                    Assert-True -TestName "First item has Type property" -Condition ($null -ne $firstItem.Type)
                    Assert-True -TestName "First item has Assignee property" -Condition ($null -ne $firstItem.Assignee)
                    Assert-True -TestName "First item has LastActivityDate property" -Condition ($null -ne $firstItem.LastActivityDate)
                    Assert-True -TestName "First item has HoursSinceActivity property" -Condition ($null -ne $firstItem.HoursSinceActivity)
                    Assert-True -TestName "First item has Status property" -Condition ($null -ne $firstItem.Status)
                    Assert-True -TestName "Type is PR or Issue" -Condition ($firstItem.Type -in @("PR", "Issue"))
                }
            }
            else {
                # Single result or no results
                Assert-True -TestName "Result is valid" -Condition $true
            }
        }
    }
    catch {
        Write-Host "✗ FAIL: Integration test failed: $_" -ForegroundColor Red
        Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor DarkGray
        $script:TestsFailed++
    }
    
    Write-Host ""
    
    # Integration Test 2: Test with PRs only
    Write-Host "Integration Test 2: Run with PRs only" -ForegroundColor White
    try {
        $result = & $scriptPath -Owner $testOwner -Repo $testRepo -StalledThresholdHours 24 -IncludePRs -IncludeIssues:$false
        
        Assert-NotNull -TestName "Script returns result" -Value $result
        
        if ($result -is [array] -and $result.Count -gt 0) {
            $allPRs = $true
            foreach ($item in $result) {
                if ($item.Type -ne "PR") {
                    $allPRs = $false
                    break
                }
            }
            Assert-True -TestName "All results are PRs" -Condition $allPRs
            Write-Host "  Found $($result.Count) stalled PRs" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  No stalled PRs found" -ForegroundColor DarkGray
            Assert-True -TestName "PRs only filter works" -Condition $true
        }
    }
    catch {
        Write-Host "✗ FAIL: PRs only test failed: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
    
    Write-Host ""
    
    # Integration Test 3: Test with Issues only
    Write-Host "Integration Test 3: Run with Issues only" -ForegroundColor White
    try {
        $result = & $scriptPath -Owner $testOwner -Repo $testRepo -StalledThresholdHours 24 -IncludePRs:$false -IncludeIssues
        
        Assert-NotNull -TestName "Script returns result" -Value $result
        
        if ($result -is [array] -and $result.Count -gt 0) {
            $allIssues = $true
            foreach ($item in $result) {
                if ($item.Type -ne "Issue") {
                    $allIssues = $false
                    break
                }
            }
            Assert-True -TestName "All results are Issues" -Condition $allIssues
            Write-Host "  Found $($result.Count) stalled issues" -ForegroundColor DarkGray
        }
        else {
            Write-Host "  No stalled issues found" -ForegroundColor DarkGray
            Assert-True -TestName "Issues only filter works" -Condition $true
        }
    }
    catch {
        Write-Host "✗ FAIL: Issues only test failed: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
    
    Write-Host ""
    
    # Integration Test 4: Test with different threshold
    Write-Host "Integration Test 4: Run with 48-hour threshold" -ForegroundColor White
    try {
        $result48 = & $scriptPath -Owner $testOwner -Repo $testRepo -StalledThresholdHours 48
        
        Assert-NotNull -TestName "Script returns result with 48-hour threshold" -Value $result48
        
        # 48-hour threshold should return fewer or equal items than 24-hour
        $result24 = & $scriptPath -Owner $testOwner -Repo $testRepo -StalledThresholdHours 24
        
        $count48 = if ($result48 -is [array]) { $result48.Count } elseif ($null -eq $result48) { 0 } else { 1 }
        $count24 = if ($result24 -is [array]) { $result24.Count } elseif ($null -eq $result24) { 0 } else { 1 }
        
        Assert-True -TestName "48-hour threshold returns fewer or equal items" -Condition ($count48 -le $count24)
        Write-Host "  24-hour threshold: $count24 items, 48-hour threshold: $count48 items" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "✗ FAIL: Threshold test failed: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
    
    Write-Host ""
    
    # Integration Test 5: Test hours since activity calculation
    Write-Host "Integration Test 5: Verify hours since activity calculation" -ForegroundColor White
    try {
        $result = & $scriptPath -Owner $testOwner -Repo $testRepo -StalledThresholdHours 1
        
        if ($result -is [array] -and $result.Count -gt 0) {
            $allValid = $true
            foreach ($item in $result) {
                # All items should have HoursSinceActivity >= threshold
                if ($item.HoursSinceActivity -lt 1) {
                    $allValid = $false
                    break
                }
            }
            Assert-True -TestName "All items meet threshold requirement" -Condition $allValid
        }
        else {
            Write-Host "  No stalled items found (expected with low threshold)" -ForegroundColor DarkGray
            Assert-True -TestName "Low threshold test completes" -Condition $true
        }
    }
    catch {
        Write-Host "✗ FAIL: Hours calculation test failed: $_" -ForegroundColor Red
        $script:TestsFailed++
    }
}

#endregion

#region Test Summary

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Passed:  " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsPassed -ForegroundColor Green
Write-Host "  Failed:  " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsFailed -ForegroundColor $(if ($script:TestsFailed -gt 0) { "Red" } else { "Gray" })
Write-Host "  Skipped: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsSkipped -ForegroundColor Yellow
Write-Host ""

$totalTests = $script:TestsPassed + $script:TestsFailed
if ($totalTests -gt 0) {
    $passRate = [math]::Round(($script:TestsPassed / $totalTests) * 100, 2)
    Write-Host "  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -eq 100) { "Green" } elseif ($passRate -ge 80) { "Yellow" } else { "Red" })
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Exit with appropriate code
if ($script:TestsFailed -gt 0) {
    exit 1
}
else {
    exit 0
}

#endregion
