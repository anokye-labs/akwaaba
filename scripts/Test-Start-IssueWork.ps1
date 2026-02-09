<#
.SYNOPSIS
    Test script for Start-IssueWork.ps1

.DESCRIPTION
    Tests the Start-IssueWork.ps1 script with various scenarios including
    parameter validation, script syntax, and basic functionality checks.
    
    Note: Full integration testing requires GitHub authentication and
    a real repository with issues.
#>

Write-Host "Testing Start-IssueWork.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Get the script path
$scriptPath = Join-Path $PSScriptRoot "Start-IssueWork.ps1"

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
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match '\[Parameter\(Mandatory\s*=\s*\$true\)\][\s\S]*?\[int\]\$IssueNumber') {
        Write-Host "✓ PASS: IssueNumber parameter is mandatory" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: IssueNumber parameter should be mandatory" -ForegroundColor Red
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
    $scriptContent = Get-Content $scriptPath -Raw
    
    $expectedParams = @(
        "ProjectNumber",
        "StatusFieldName",
        "InProgressValue",
        "SkipBranch",
        "SkipAssignment",
        "SkipStatusUpdate",
        "CorrelationId"
    )
    $allExist = $true
    
    foreach ($param in $expectedParams) {
        if ($scriptContent -notmatch "\`$$param") {
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

# Test 4: Verify switch parameters are correctly defined
Write-Host "Test 4: Switch parameters are correctly defined" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    $switchParams = @("SkipBranch", "SkipAssignment", "SkipStatusUpdate")
    $allCorrect = $true
    
    foreach ($param in $switchParams) {
        if ($scriptContent -notmatch "\[switch\]\`$$param") {
            Write-Host "  Parameter $param is not defined as a switch" -ForegroundColor Yellow
            $allCorrect = $false
        }
    }
    
    if ($allCorrect) {
        Write-Host "✓ PASS: All switch parameters are correctly defined" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some switch parameters are incorrectly defined" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify switch parameters: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 5: Verify default parameter values
Write-Host "Test 5: Default parameter values are set correctly" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $checks = @{
        "StatusFieldName default" = ($scriptContent -match '\[string\]\$StatusFieldName\s*=\s*"Status"')
        "InProgressValue default" = ($scriptContent -match '\[string\]\$InProgressValue\s*=\s*"In Progress"')
    }
    
    $allCorrect = $true
    foreach ($check in $checks.GetEnumerator()) {
        if (-not $check.Value) {
            Write-Host "  Missing or incorrect: $($check.Key)" -ForegroundColor Yellow
            $allCorrect = $false
        }
    }
    
    if ($allCorrect) {
        Write-Host "✓ PASS: Default parameter values are set correctly" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some default parameter values are incorrect" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify default parameter values: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 6: Verify dependencies are loaded
Write-Host "Test 6: Script attempts to load required dependencies" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $dependencies = @(
        "Invoke-GraphQL.ps1",
        "Write-OkyeremaLog.ps1"
    )
    
    $allFound = $true
    foreach ($dep in $dependencies) {
        if ($scriptContent -notmatch [regex]::Escape($dep)) {
            Write-Host "  Missing dependency reference: $dep" -ForegroundColor Yellow
            $allFound = $false
        }
    }
    
    if ($allFound) {
        Write-Host "✓ PASS: All dependencies are referenced in the script" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some dependencies are not referenced" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify dependencies: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 7: Verify GraphQL queries are present
Write-Host "Test 7: GraphQL queries are defined" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $queries = @{
        "Issue query" = ($scriptContent -match 'repository\(owner:')
        "Assign mutation" = ($scriptContent -match 'addAssigneesToAssignable')
        "Project query" = ($scriptContent -match 'projectV2\(number:')
        "Update status mutation" = ($scriptContent -match 'updateProjectV2ItemFieldValue')
    }
    
    $allFound = $true
    foreach ($query in $queries.GetEnumerator()) {
        if (-not $query.Value) {
            Write-Host "  Missing or incorrect: $($query.Key)" -ForegroundColor Yellow
            $allFound = $false
        }
    }
    
    if ($allFound) {
        Write-Host "✓ PASS: All GraphQL queries are defined" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some GraphQL queries are missing" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify GraphQL queries: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 8: Verify branch naming pattern
Write-Host "Test 8: Branch naming pattern is implemented" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for branch naming pattern: issue-{number}-{slug}
    if ($scriptContent -match 'issue-\$IssueNumber') {
        Write-Host "✓ PASS: Branch naming pattern is implemented" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Branch naming pattern not found" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify branch naming pattern: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 9: Verify return object structure
Write-Host "Test 9: Return object structure is correct" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $requiredFields = @(
        "Success",
        "IssueNumber",
        "IssueTitle",
        "IssueUrl",
        "AssignedTo",
        "Branch",
        "Status",
        "CorrelationId",
        "StartTime"
    )
    
    $allFound = $true
    foreach ($field in $requiredFields) {
        if ($scriptContent -notmatch "$field\s*=") {
            Write-Host "  Missing return field: $field" -ForegroundColor Yellow
            $allFound = $false
        }
    }
    
    if ($allFound) {
        Write-Host "✓ PASS: Return object structure includes all required fields" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some return fields are missing" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify return object structure: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 10: Verify logging calls
Write-Host "Test 10: Logging is implemented" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Count Write-OkyeremaLog calls
    $logCallCount = ([regex]::Matches($scriptContent, 'Write-OkyeremaLog')).Count
    
    if ($logCallCount -ge 5) {
        Write-Host "✓ PASS: Script includes logging calls ($logCallCount found)" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Insufficient logging calls ($logCallCount found, expected at least 5)" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify logging calls: $_" -ForegroundColor Red
    $testsFailed++
}

# Summary
Write-Host ""
Write-Host "==================== Test Summary ====================" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "======================================================" -ForegroundColor Cyan

if ($testsFailed -eq 0) {
    Write-Host ""
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host ""
    Write-Host "Some tests failed. Please review the output above." -ForegroundColor Red
    exit 1
}
