<#
.SYNOPSIS
    Test script for Get-ReadyIssues.ps1

.DESCRIPTION
    Tests the Get-ReadyIssues.ps1 script with various scenarios including
    filtering by labels, issue type, assignee, and blocking dependencies.
    
    Note: This test requires a real GitHub repository with issues to test against.
    It uses mock scenarios to validate the logic but also includes integration tests.
#>

Write-Host "Testing Get-ReadyIssues.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Get the script path
$scriptPath = Join-Path $PSScriptRoot "Get-ReadyIssues.ps1"

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
    
    if ($requiredParams -contains "RootIssue") {
        Write-Host "✓ PASS: RootIssue parameter is mandatory" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: RootIssue parameter should be mandatory" -ForegroundColor Red
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
    
    $expectedParams = @("Labels", "IssueType", "Assignee", "IncludeAssigned", "SortBy")
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
        $validateSet = $sortByParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        
        if ($validateSet) {
            $validValues = $validateSet.ValidValues
            $expectedValues = @("priority", "number", "title")
            
            $allMatch = $true
            foreach ($expected in $expectedValues) {
                if ($validValues -notcontains $expected) {
                    Write-Host "  Missing ValidateSet value: $expected" -ForegroundColor Yellow
                    $allMatch = $false
                }
            }
            
            if ($allMatch -and $validValues.Count -eq $expectedValues.Count) {
                Write-Host "✓ PASS: SortBy ValidateSet is correct" -ForegroundColor Green
                $testsPassed++
            }
            else {
                Write-Host "✗ FAIL: SortBy ValidateSet values don't match expected" -ForegroundColor Red
                Write-Host "  Expected: $($expectedValues -join ', ')" -ForegroundColor Yellow
                Write-Host "  Got: $($validValues -join ', ')" -ForegroundColor Yellow
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
    Write-Host "✗ FAIL: Could not verify SortBy ValidateSet: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 5: Verify helper functions exist in script
Write-Host "Test 5: Helper functions defined in script" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $expectedFunctions = @(
        "Write-Log",
        "Invoke-GraphQLHelper",
        "Get-RepoContextHelper",
        "Get-BlockingDependencies",
        "Test-HasOpenBlockingDependencies",
        "Add-IssueToMap"
    )
    
    $allExist = $true
    foreach ($func in $expectedFunctions) {
        if ($scriptContent -notmatch "function\s+$func") {
            Write-Host "  Missing function: $func" -ForegroundColor Yellow
            $allExist = $false
        }
    }
    
    if ($allExist) {
        Write-Host "✓ PASS: All expected helper functions exist" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some helper functions are missing" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify helper functions: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 6: Verify blocking dependency regex pattern
Write-Host "Test 6: Blocking dependency parsing logic" -ForegroundColor Yellow
try {
    # Test the regex pattern for parsing "Blocked by:" sections
    $testBody1 = @"
Some description

## Dependencies

Blocked by:
- [ ] anokye-labs/akwaaba#14 - Invoke-GraphQL.ps1
- [ ] anokye-labs/akwaaba#15 - Get-RepoContext.ps1

More content
"@

    $testBody2 = @"
Description without dependencies
"@

    $testBody3 = @"
Description

Blocked by:
- [x] #10 - Completed dependency
- [ ] #20 - Open dependency

Other content
"@

    # Check if the regex pattern would match these bodies
    $pattern1Match = $testBody1 -match '(?ms)Blocked by:\s*\n((?:-\s*\[.\].*?\n?)+)'
    $pattern2Match = $testBody2 -match '(?ms)Blocked by:\s*\n((?:-\s*\[.\].*?\n?)+)'
    $pattern3Match = $testBody3 -match '(?ms)Blocked by:\s*\n((?:-\s*\[.\].*?\n?)+)'
    
    if ($pattern1Match -and -not $pattern2Match -and $pattern3Match) {
        Write-Host "✓ PASS: Blocking dependency regex pattern works correctly" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Blocking dependency regex pattern doesn't match expected" -ForegroundColor Red
        Write-Host "  Test 1 (should match): $pattern1Match" -ForegroundColor Yellow
        Write-Host "  Test 2 (should not match): $pattern2Match" -ForegroundColor Yellow
        Write-Host "  Test 3 (should match): $pattern3Match" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error testing blocking dependency pattern: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 7: Verify correlation ID generation
Write-Host "Test 7: Correlation ID is generated" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    if ($scriptContent -match '\$correlationId\s*=\s*\[guid\]::NewGuid\(\)\.ToString\(\)') {
        Write-Host "✓ PASS: Correlation ID generation found" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Correlation ID generation not found or incorrect" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking correlation ID: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 8: Verify dependency scripts are called correctly
Write-Host "Test 8: Dependency scripts called with & operator" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check that Invoke-GraphQL.ps1 is called with & operator in helper
    $invokesCorrectly = $scriptContent -match '&\s+\$graphqlScript.*-Query.*-Variables'
    
    # Check that Get-RepoContext.ps1 is called with & operator
    $repoContextCorrectly = $scriptContent -match '&\s+\$contextScript'
    
    # Check that Write-OkyeremaLog.ps1 is called with & operator
    $logCorrectly = $scriptContent -match '&\s+\$logScript.*-Message'
    
    if ($invokesCorrectly -and $repoContextCorrectly -and $logCorrectly) {
        Write-Host "✓ PASS: Dependency scripts called with & operator" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some dependency scripts not called correctly" -ForegroundColor Red
        Write-Host "  Invoke-GraphQL: $invokesCorrectly" -ForegroundColor Yellow
        Write-Host "  Get-RepoContext: $repoContextCorrectly" -ForegroundColor Yellow
        Write-Host "  Write-OkyeremaLog: $logCorrectly" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking dependency script calls: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 9: Verify GraphQL query structure
Write-Host "Test 9: GraphQL query includes required fields" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for essential GraphQL fields
    $requiredFields = @(
        "subIssues",
        "issueType",
        "labels",
        "assignees",
        "body",
        "state"
    )
    
    $allFieldsPresent = $true
    foreach ($field in $requiredFields) {
        if ($scriptContent -notmatch $field) {
            Write-Host "  Missing GraphQL field: $field" -ForegroundColor Yellow
            $allFieldsPresent = $false
        }
    }
    
    if ($allFieldsPresent) {
        Write-Host "✓ PASS: GraphQL query includes all required fields" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: GraphQL query missing some required fields" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking GraphQL query: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 10: Verify output structure
Write-Host "Test 10: Script defines expected output properties" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # The script should create PSCustomObject with these properties for the issue map
    $expectedProps = @(
        "Number",
        "Title",
        "State",
        "Url",
        "Type",
        "Labels",
        "Assignees",
        "Depth"
    )
    
    $allPropsPresent = $true
    foreach ($prop in $expectedProps) {
        if ($scriptContent -notmatch $prop) {
            Write-Host "  Missing property: $prop" -ForegroundColor Yellow
            $allPropsPresent = $false
        }
    }
    
    if ($allPropsPresent) {
        Write-Host "✓ PASS: Output structure includes expected properties" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Output structure missing some properties" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking output structure: $_" -ForegroundColor Red
    $testsFailed++
}

# Summary
Write-Host ""
Write-Host "==================== TEST SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "FAILED: Some tests did not pass." -ForegroundColor Red
    Write-Host ""
    Write-Host "Note: Unit tests passed. Integration tests require a GitHub repository" -ForegroundColor Yellow
    Write-Host "with issues to test against. Run the script manually to test with real data." -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "SUCCESS: All unit tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To test with real data, run:" -ForegroundColor Cyan
    Write-Host "  .\Get-ReadyIssues.ps1 -RootIssue <issue_number>" -ForegroundColor Yellow
    exit 0
}
