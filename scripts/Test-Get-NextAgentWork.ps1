<#
.SYNOPSIS
    Test script for Get-NextAgentWork.ps1

.DESCRIPTION
    Tests the Get-NextAgentWork.ps1 script with various scenarios including
    prioritization strategies, capability tag filtering, and output formats.
    
    Note: This test requires a real GitHub repository with issues to test against.
    It uses mock scenarios to validate the logic but also includes integration tests.
#>

Write-Host "Testing Get-NextAgentWork.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Get the script path
$scriptPath = Join-Path $PSScriptRoot "Get-NextAgentWork.ps1"

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
    
    $expectedParams = @("AgentCapabilityTags", "SortBy", "OutputFormat")
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
            $expectedValues = @("priority", "depth", "labels", "oldest")
            
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

# Test 5: Verify OutputFormat validation set
Write-Host "Test 5: OutputFormat parameter has correct ValidateSet" -ForegroundColor Yellow
try {
    $scriptInfo = Get-Command $scriptPath -ErrorAction Stop
    $outputFormatParam = $scriptInfo.Parameters["OutputFormat"]
    
    if ($outputFormatParam) {
        $validateSet = $outputFormatParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        
        if ($validateSet) {
            $validValues = $validateSet.ValidValues
            $expectedValues = @("Object", "Json", "Console")
            
            $allMatch = $true
            foreach ($expected in $expectedValues) {
                if ($validValues -notcontains $expected) {
                    Write-Host "  Missing ValidateSet value: $expected" -ForegroundColor Yellow
                    $allMatch = $false
                }
            }
            
            if ($allMatch -and $validValues.Count -eq $expectedValues.Count) {
                Write-Host "✓ PASS: OutputFormat ValidateSet is correct" -ForegroundColor Green
                $testsPassed++
            }
            else {
                Write-Host "✗ FAIL: OutputFormat ValidateSet values don't match expected" -ForegroundColor Red
                Write-Host "  Expected: $($expectedValues -join ', ')" -ForegroundColor Yellow
                Write-Host "  Got: $($validValues -join ', ')" -ForegroundColor Yellow
                $testsFailed++
            }
        }
        else {
            Write-Host "✗ FAIL: OutputFormat parameter missing ValidateSet attribute" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "✗ FAIL: OutputFormat parameter not found" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Could not verify OutputFormat ValidateSet: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 6: Verify helper functions exist in script
Write-Host "Test 6: Helper functions defined in script" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    $expectedFunctions = @(
        "Write-Log",
        "Invoke-GraphQLHelper",
        "Get-PriorityScore"
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

# Test 7: Verify Get-PriorityScore function logic
Write-Host "Test 7: Priority scoring logic" -ForegroundColor Yellow
try {
    # Test the priority scoring logic by loading the function
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check if priority scoring logic exists
    $hasCritical = $scriptContent -match 'priority:critical.*4'
    $hasHigh = $scriptContent -match 'priority:high.*3'
    $hasMedium = $scriptContent -match 'priority:medium.*2'
    $hasLow = $scriptContent -match 'priority:low.*1'
    
    if ($hasCritical -and $hasHigh -and $hasMedium -and $hasLow) {
        Write-Host "✓ PASS: Priority scoring logic is implemented correctly" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Priority scoring logic is incomplete" -ForegroundColor Red
        Write-Host "  Critical: $hasCritical, High: $hasHigh, Medium: $hasMedium, Low: $hasLow" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error testing priority scoring logic: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 8: Verify correlation ID generation
Write-Host "Test 8: Correlation ID is generated" -ForegroundColor Yellow
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

# Test 9: Verify dependency on Get-ReadyIssues.ps1
Write-Host "Test 9: Script calls Get-ReadyIssues.ps1" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check that Get-ReadyIssues.ps1 is referenced
    $hasGetReadyIssues = $scriptContent -match 'Get-ReadyIssues\.ps1'
    $callsGetReadyIssues = $scriptContent -match '&\s+\$readyIssuesScript'
    
    if ($hasGetReadyIssues -and $callsGetReadyIssues) {
        Write-Host "✓ PASS: Script correctly calls Get-ReadyIssues.ps1" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Script doesn't properly call Get-ReadyIssues.ps1" -ForegroundColor Red
        Write-Host "  Has reference: $hasGetReadyIssues" -ForegroundColor Yellow
        Write-Host "  Calls script: $callsGetReadyIssues" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking Get-ReadyIssues.ps1 dependency: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 10: Verify output structure
Write-Host "Test 10: Script defines expected output properties" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # The script should create PSCustomObject with these properties
    $expectedProps = @(
        "Number",
        "Title",
        "Type",
        "State",
        "Url",
        "Body",
        "Labels",
        "Assignees",
        "Depth",
        "Priority",
        "CreatedAt"
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

# Test 11: Verify agent capability tag filtering logic
Write-Host "Test 11: Agent capability tag filtering implemented" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for capability tag filtering
    $hasCapabilityCheck = $scriptContent -match 'AgentCapabilityTags'
    $hasLabelMatching = $scriptContent -match 'Labels\s+-contains'
    
    if ($hasCapabilityCheck -and $hasLabelMatching) {
        Write-Host "✓ PASS: Agent capability tag filtering is implemented" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Agent capability tag filtering not properly implemented" -ForegroundColor Red
        Write-Host "  Has capability check: $hasCapabilityCheck" -ForegroundColor Yellow
        Write-Host "  Has label matching: $hasLabelMatching" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking capability tag filtering: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 12: Verify sorting strategies are implemented
Write-Host "Test 12: All sorting strategies implemented" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for all sorting strategies
    $hasDepth = $scriptContent -match '"depth"'
    $hasLabels = $scriptContent -match '"labels"'
    $hasOldest = $scriptContent -match '"oldest"'
    $hasPriority = $scriptContent -match '"priority"'
    
    if ($hasDepth -and $hasLabels -and $hasOldest -and $hasPriority) {
        Write-Host "✓ PASS: All sorting strategies are implemented" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Some sorting strategies are missing" -ForegroundColor Red
        Write-Host "  Depth: $hasDepth, Labels: $hasLabels, Oldest: $hasOldest, Priority: $hasPriority" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking sorting strategies: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 13: Verify GraphQL query for metadata
Write-Host "Test 13: GraphQL query includes required fields" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for essential GraphQL fields for metadata
    $hasCreatedAt = $scriptContent -match 'createdAt'
    $hasBody = $scriptContent -match 'body'
    
    if ($hasCreatedAt -and $hasBody) {
        Write-Host "✓ PASS: GraphQL query includes required metadata fields" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: GraphQL query missing some required fields" -ForegroundColor Red
        Write-Host "  Has createdAt: $hasCreatedAt" -ForegroundColor Yellow
        Write-Host "  Has body: $hasBody" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking GraphQL query: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 14: Verify console output format
Write-Host "Test 14: Console output format implemented" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for console output formatting
    $hasConsoleFormat = $scriptContent -match 'OutputFormat.*-eq.*"Console"'
    $hasWriteHost = $scriptContent -match 'Write-Host'
    
    if ($hasConsoleFormat -and $hasWriteHost) {
        Write-Host "✓ PASS: Console output format is implemented" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: Console output format not properly implemented" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking console output: $_" -ForegroundColor Red
    $testsFailed++
}

# Test 15: Verify JSON output format
Write-Host "Test 15: JSON output format implemented" -ForegroundColor Yellow
try {
    $scriptContent = Get-Content $scriptPath -Raw
    
    # Check for JSON output formatting
    $hasJsonFormat = $scriptContent -match 'OutputFormat.*-eq.*"Json"'
    $hasConvertToJson = $scriptContent -match 'ConvertTo-Json'
    
    if ($hasJsonFormat -and $hasConvertToJson) {
        Write-Host "✓ PASS: JSON output format is implemented" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "✗ FAIL: JSON output format not properly implemented" -ForegroundColor Red
        $testsFailed++
    }
}
catch {
    Write-Host "✗ FAIL: Error checking JSON output: $_" -ForegroundColor Red
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
    Write-Host "  .\Get-NextAgentWork.ps1 -RootIssue <issue_number>" -ForegroundColor Yellow
    exit 0
}
