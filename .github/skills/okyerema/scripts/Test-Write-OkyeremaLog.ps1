<#
.SYNOPSIS
    Test script for Write-OkyeremaLog.ps1

.DESCRIPTION
    Validates that Write-OkyeremaLog properly writes structured JSON logs to stderr
    with correct format, fields, and behavior for all log levels and options.
#>

$ErrorActionPreference = "Stop"

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Testing Write-OkyeremaLog..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-LogOutput {
    param(
        [string]$TestName,
        [hashtable]$Parameters,
        [scriptblock]$ValidationBlock
    )
    
    try {
        # Build command for bash execution to properly capture stderr
        $paramString = ""
        foreach ($key in $Parameters.Keys) {
            $value = $Parameters[$key]
            if ($value -is [bool] -and $value) {
                $paramString += " -$key"
            } else {
                $escapedValue = $value -replace "'", "'\''"
                $paramString += " -$key '$escapedValue'"
            }
        }
        
        # Execute via bash to capture actual stderr
        $bashCmd = "pwsh -File '$scriptDir/Write-OkyeremaLog.ps1'$paramString 2>&1"
        $output = bash -c $bashCmd
        
        # Run validation
        $result = & $ValidationBlock $output
        
        if ($result) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
            Write-Host "  Output: $output" -ForegroundColor Yellow
            $script:testsFailed++
        }
    } catch {
        Write-Host "✗ FAIL: $TestName (Exception)" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
    }
}

# Test 1: Basic Info log
Test-LogOutput -TestName "Basic Info log" -Parameters @{
    Message = "Test message"
    Level = "Info"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    # Validate timestamp format in raw JSON string
    $timestampFromRaw = if ($output -match '"timestamp":"([^"]+)"') { $matches[1] } else { $null }
    return ($json.level -eq "Info" -and 
            $json.message -eq "Test message" -and 
            $timestampFromRaw -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')
}

# Test 2: Warn level
Test-LogOutput -TestName "Warn level" -Parameters @{
    Message = "Warning message"
    Level = "Warn"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return $json.level -eq "Warn"
}

# Test 3: Error level
Test-LogOutput -TestName "Error level" -Parameters @{
    Message = "Error message"
    Level = "Error"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return $json.level -eq "Error"
}

# Test 4: Debug level
Test-LogOutput -TestName "Debug level" -Parameters @{
    Message = "Debug message"
    Level = "Debug"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return $json.level -eq "Debug"
}

# Test 5: With operation name
Test-LogOutput -TestName "With operation name" -Parameters @{
    Message = "Test message"
    Level = "Info"
    Operation = "CreateIssue"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return ($json.operation -eq "CreateIssue")
}

# Test 6: With correlation ID
Test-LogOutput -TestName "With correlation ID" -Parameters @{
    Message = "Test message"
    Level = "Info"
    CorrelationId = "abc-123-def"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return ($json.correlationId -eq "abc-123-def")
}

# Test 7: With operation and correlation ID
Test-LogOutput -TestName "With operation and correlation ID" -Parameters @{
    Message = "Test message"
    Level = "Info"
    Operation = "UpdateHierarchy"
    CorrelationId = "xyz-789"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return ($json.operation -eq "UpdateHierarchy" -and 
            $json.correlationId -eq "xyz-789")
}

# Test 8: Quiet switch (no output to stderr)
Test-LogOutput -TestName "Quiet switch suppresses output" -Parameters @{
    Message = "Test message"
    Level = "Info"
    Quiet = $true
} -ValidationBlock {
    param($output)
    # With -Quiet, stderr should be empty or whitespace-only
    return ([string]::IsNullOrWhiteSpace($output))
}

# Test 9: Default level is Info
Test-LogOutput -TestName "Default level is Info" -Parameters @{
    Message = "Test message"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return ($json.level -eq "Info")
}

# Test 10: JSON is valid and compact (single line)
Test-LogOutput -TestName "JSON is compact (single line)" -Parameters @{
    Message = "Test message"
    Level = "Info"
} -ValidationBlock {
    param($output)
    # Check that output doesn't contain multiple lines (no \n within the JSON)
    $lines = $output -split "`n" | Where-Object { $_.Trim() -ne "" }
    return ($lines.Count -eq 1)
}

# Test 11: Timestamp is ISO 8601 UTC format
Test-LogOutput -TestName "Timestamp is ISO 8601 UTC" -Parameters @{
    Message = "Test message"
    Level = "Info"
} -ValidationBlock {
    param($output)
    # Extract timestamp from raw JSON string
    $timestampFromRaw = if ($output -match '"timestamp":"([^"]+)"') { $matches[1] } else { $null }
    # Should end with Z and match the format
    return ($timestampFromRaw -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$' -and 
            $timestampFromRaw -like "*Z")
}

# Test 12: Message with special characters
Test-LogOutput -TestName "Message with special characters" -Parameters @{
    Message = "Test with `"quotes`" and \backslash and newline`n"
    Level = "Info"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    # ConvertFrom-Json should handle the escaping
    return ($json.message -eq "Test with `"quotes`" and \backslash and newline`n")
}

# Test 13: All fields present when all parameters provided
Test-LogOutput -TestName "All fields present" -Parameters @{
    Message = "Complete test"
    Level = "Debug"
    Operation = "TestOperation"
    CorrelationId = "test-123"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return ($json.PSObject.Properties.Name -contains "timestamp" -and
            $json.PSObject.Properties.Name -contains "level" -and
            $json.PSObject.Properties.Name -contains "message" -and
            $json.PSObject.Properties.Name -contains "operation" -and
            $json.PSObject.Properties.Name -contains "correlationId")
}

# Test 14: Only required fields when optional not provided
Test-LogOutput -TestName "Only required fields when optional not provided" -Parameters @{
    Message = "Minimal test"
    Level = "Info"
} -ValidationBlock {
    param($output)
    $json = $output | ConvertFrom-Json
    return ($json.PSObject.Properties.Name -contains "timestamp" -and
            $json.PSObject.Properties.Name -contains "level" -and
            $json.PSObject.Properties.Name -contains "message" -and
            $json.PSObject.Properties.Name -notcontains "operation" -and
            $json.PSObject.Properties.Name -notcontains "correlationId")
}

# Summary
Write-Host ""
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
