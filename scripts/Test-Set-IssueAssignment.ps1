<#
.SYNOPSIS
    Test script for Set-IssueAssignment.ps1

.DESCRIPTION
    Tests the Set-IssueAssignment.ps1 script with various scenarios including
    parameter validation, DryRun mode, MaxAssign limiting, and error handling.
    
    Note: This test focuses on syntax and parameter validation.
    Integration tests would require a real GitHub repository with issues.
#>

Write-Host "Testing Set-IssueAssignment.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Get the script path
$scriptPath = Join-Path $PSScriptRoot "Set-IssueAssignment.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "✗ FAIL: Script not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Script found at: $scriptPath" -ForegroundColor Green
Write-Host ""

# Test 1: Verify script can be loaded without errors
Write-Host "Test 1: Script loads without syntax errors" -ForegroundColor Yellow
try {
    # Parse the script to check for syntax errors
    $null = [System.Management.Automation.PSParser]::Tokenize(
        (Get-Content $scriptPath -Raw), 
        [ref]$null
    )
    Write-Host "✓ PASS: Script has valid PowerShell syntax" -ForegroundColor Green
    $testsPassed++
}
catch {
    Write-Host "✗ FAIL: Script has syntax errors: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 2: Verify required parameters
Write-Host "Test 2: Required parameters defined correctly" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $requiredParams = $scriptInfo.Parameters.Keys | Where-Object {
        $scriptInfo.Parameters[$_].Attributes.Mandatory -eq $true
    }
    
    $expectedRequired = @("RootIssue", "Assignee")
    $missingRequired = @()
    
    foreach ($param in $expectedRequired) {
        if ($requiredParams -notcontains $param) {
            $missingRequired += $param
        }
    }
    
    if ($missingRequired.Count -eq 0) {
        Write-Host "✓ PASS: All required parameters are mandatory (RootIssue, Assignee)" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Missing required parameters: $($missingRequired -join ', ')" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not read script parameters: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 3: Verify optional parameters exist
Write-Host "Test 3: Optional parameters exist" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $paramNames = $scriptInfo.Parameters.Keys
    
    $expectedParams = @("MaxAssign", "DryRun", "Labels", "IssueType", "SortBy")
    $allExist = $true
    
    foreach ($param in $expectedParams) {
        if ($paramNames -notcontains $param) {
            Write-Host "  Missing parameter: $param" -ForegroundColor Yellow
            $allExist = $false
        }
    }
    
    if ($allExist) {
        Write-Host "✓ PASS: All expected optional parameters exist" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some optional parameters are missing" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify optional parameters: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 4: Verify SortBy validation set
Write-Host "Test 4: SortBy parameter has correct ValidateSet" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $sortByParam = $scriptInfo.Parameters["SortBy"]
    
    if ($sortByParam) {
        $validateSetAttr = $sortByParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        
        if ($validateSetAttr) {
            $expectedValues = @("priority", "number", "title")
            $actualValues = $validateSetAttr.ValidValues
            
            $matches = $true
            foreach ($expected in $expectedValues) {
                if ($actualValues -notcontains $expected) {
                    $matches = $false
                    break
                }
            }
            
            if ($matches -and $actualValues.Count -eq $expectedValues.Count) {
                Write-Host "✓ PASS: SortBy has correct ValidateSet values" -ForegroundColor Green
                $testsPassed++
            }
            else {
                Write-Host "✗ FAIL: SortBy ValidateSet values don't match expected" -ForegroundColor Red
                $testsFailed++
            }
        }
        else {
            Write-Host "✗ FAIL: SortBy parameter missing ValidateSet attribute" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "✗ FAIL: SortBy parameter not found" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify SortBy parameter: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 5: Verify DryRun parameter is a switch
Write-Host "Test 5: DryRun parameter is a switch" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $dryRunParam = $scriptInfo.Parameters["DryRun"]
    
    if ($dryRunParam) {
        $isSwitchParam = $dryRunParam.SwitchParameter
        
        if ($isSwitchParam) {
            Write-Host "✓ PASS: DryRun is a switch parameter" -ForegroundColor Green
            $testsPassed++
        }
        else {
            Write-Host "✗ FAIL: DryRun should be a switch parameter" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "✗ FAIL: DryRun parameter not found" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify DryRun parameter: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 6: Verify MaxAssign parameter type
Write-Host "Test 6: MaxAssign parameter is an integer" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $maxAssignParam = $scriptInfo.Parameters["MaxAssign"]
    
    if ($maxAssignParam) {
        $paramType = $maxAssignParam.ParameterType
        
        if ($paramType -eq [int]) {
            Write-Host "✓ PASS: MaxAssign is an integer parameter" -ForegroundColor Green
            $testsPassed++
        }
        else {
            Write-Host "✗ FAIL: MaxAssign should be an integer (is $paramType)" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "✗ FAIL: MaxAssign parameter not found" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify MaxAssign parameter: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 7: Verify Labels parameter is string array
Write-Host "Test 7: Labels parameter is a string array" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $labelsParam = $scriptInfo.Parameters["Labels"]
    
    if ($labelsParam) {
        $paramType = $labelsParam.ParameterType
        
        if ($paramType -eq [string[]]) {
            Write-Host "✓ PASS: Labels is a string array parameter" -ForegroundColor Green
            $testsPassed++
        }
        else {
            Write-Host "✗ FAIL: Labels should be a string array (is $paramType)" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "✗ FAIL: Labels parameter not found" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify Labels parameter: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 8: Verify script has proper help documentation
Write-Host "Test 8: Script has help documentation" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $hasSynopsis = $scriptContent -match '\.SYNOPSIS'
    $hasDescription = $scriptContent -match '\.DESCRIPTION'
    $hasExamples = $scriptContent -match '\.EXAMPLE'
    
    if ($hasSynopsis -and $hasDescription -and $hasExamples) {
        Write-Host "✓ PASS: Script has help documentation (SYNOPSIS, DESCRIPTION, EXAMPLE)" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script missing help documentation sections" -ForegroundColor Red
        if (-not $hasSynopsis) { Write-Host "  Missing: .SYNOPSIS" -ForegroundColor Yellow }
        if (-not $hasDescription) { Write-Host "  Missing: .DESCRIPTION" -ForegroundColor Yellow }
        if (-not $hasExamples) { Write-Host "  Missing: .EXAMPLE" -ForegroundColor Yellow }
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify help documentation: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 9: Verify script uses Write-OkyeremaLog
Write-Host "Test 9: Script uses Write-OkyeremaLog for logging" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match 'Write-OkyeremaLog' -or $scriptContent -match 'Write-Log') {
        Write-Host "✓ PASS: Script uses Write-OkyeremaLog for logging" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should use Write-OkyeremaLog for logging" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify logging usage: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 10: Verify script uses Get-ReadyIssues.ps1
Write-Host "Test 10: Script uses Get-ReadyIssues.ps1" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match 'Get-ReadyIssues') {
        Write-Host "✓ PASS: Script uses Get-ReadyIssues.ps1" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should use Get-ReadyIssues.ps1" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify Get-ReadyIssues usage: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 11: Verify script uses gh issue edit for assignment
Write-Host "Test 11: Script uses gh issue edit for assignment" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match 'gh issue edit.*--add-assignee') {
        Write-Host "✓ PASS: Script uses gh issue edit --add-assignee" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should use gh issue edit --add-assignee" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify gh issue edit usage: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 12: Verify script handles DryRun mode
Write-Host "Test 12: Script handles DryRun mode" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match 'if.*\$DryRun' -or $scriptContent -match 'DryRun mode') {
        Write-Host "✓ PASS: Script implements DryRun mode handling" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should implement DryRun mode handling" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify DryRun handling: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 13: Verify script handles MaxAssign limiting
Write-Host "Test 13: Script handles MaxAssign limiting" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match '\$MaxAssign' -and $scriptContent -match 'Select-Object -First') {
        Write-Host "✓ PASS: Script implements MaxAssign limiting" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should implement MaxAssign limiting" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify MaxAssign handling: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 14: Verify script has error handling
Write-Host "Test 14: Script has error handling" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $hasTryCatch = $scriptContent -match 'try\s*\{' -and $scriptContent -match 'catch\s*\{'
    $checksExitCode = $scriptContent -match '\$LASTEXITCODE'
    
    if ($hasTryCatch -and $checksExitCode) {
        Write-Host "✓ PASS: Script has try-catch blocks and checks exit codes" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should have try-catch blocks and check exit codes" -ForegroundColor Red
        if (-not $hasTryCatch) { Write-Host "  Missing: try-catch blocks" -ForegroundColor Yellow }
        if (-not $checksExitCode) { Write-Host "  Missing: \$LASTEXITCODE checks" -ForegroundColor Yellow }
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify error handling: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 15: Verify script returns results
Write-Host "Test 15: Script returns results" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match 'return \$results') {
        Write-Host "✓ PASS: Script returns results" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script should return results" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify return statement: $_" -ForegroundColor Red
    $testsFailed++
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some tests failed. Please review the output above." -ForegroundColor Red
    exit 1
}
