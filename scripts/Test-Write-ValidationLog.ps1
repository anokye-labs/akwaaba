<#
.SYNOPSIS
    Test suite for Write-ValidationLog.ps1

.DESCRIPTION
    Comprehensive tests for the Write-ValidationLog.ps1 script, including:
    - Log file creation
    - JSON format validation
    - Required fields validation
    - Log directory creation
    - Multiple log entries

.EXAMPLE
    ./Test-Write-ValidationLog.ps1

.NOTES
    Author: Anokye Labs
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Test configuration
$script:TestLogDir = Join-Path $PWD "temp/test-validation-logs"
$script:PassedTests = 0
$script:FailedTests = 0
$script:TestResults = @()

# Helper function to run a test
function Test-CommitValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$TestBlock
    )
    
    Write-Host "`n--- Test: $TestName ---" -ForegroundColor Cyan
    
    try {
        & $TestBlock
        Write-Host "✓ PASSED" -ForegroundColor Green
        $script:PassedTests++
        $script:TestResults += [PSCustomObject]@{
            Test = $TestName
            Result = "PASSED"
            Error = $null
        }
    } catch {
        Write-Host "✗ FAILED: $_" -ForegroundColor Red
        $script:FailedTests++
        $script:TestResults += [PSCustomObject]@{
            Test = $TestName
            Result = "FAILED"
            Error = $_.Exception.Message
        }
    }
}

# Clean up test directory before tests
if (Test-Path $script:TestLogDir) {
    Remove-Item -Path $script:TestLogDir -Recurse -Force
}

Write-Host "=== Write-ValidationLog.ps1 Test Suite ===" -ForegroundColor Magenta
Write-Host "Test log directory: $script:TestLogDir"

#region Tests

Test-CommitValidation -TestName "Create log directory if not exists" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test1"
    
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "abc123" `
        -CommitAuthor "test@example.com" `
        -CommitMessage "test commit" `
        -PRNumber 1 `
        -ValidationResult "Pass" `
        -LogDirectory $testDir
    
    if (-not (Test-Path $testDir)) {
        throw "Log directory was not created"
    }
}

Test-CommitValidation -TestName "Create log file with correct name format" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test2"
    
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "def456" `
        -CommitAuthor "test@example.com" `
        -CommitMessage "test commit" `
        -PRNumber 2 `
        -ValidationResult "Fail" `
        -LogDirectory $testDir
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $expectedLogFile = Join-Path $testDir "$logDate-validation.log"
    
    if (-not (Test-Path $expectedLogFile)) {
        throw "Log file was not created with expected name: $expectedLogFile"
    }
}

Test-CommitValidation -TestName "Log entry is valid JSON" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test3"
    
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "ghi789" `
        -CommitAuthor "test@example.com" `
        -CommitMessage "test commit" `
        -PRNumber 3 `
        -ValidationResult "Pass" `
        -LogDirectory $testDir
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $logFile = Join-Path $testDir "$logDate-validation.log"
    $logContent = Get-Content $logFile -Raw
    
    # Try to parse as JSON
    $logObject = $logContent | ConvertFrom-Json
    
    if (-not $logObject) {
        throw "Log entry is not valid JSON"
    }
}

Test-CommitValidation -TestName "Log entry contains required fields" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test4"
    
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "jkl012" `
        -CommitAuthor "test@example.com" `
        -CommitMessage "test commit message" `
        -PRNumber 4 `
        -ValidationResult "Pass" `
        -ValidationMessage "Test message" `
        -CorrelationId "test-correlation-id" `
        -LogDirectory $testDir
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $logFile = Join-Path $testDir "$logDate-validation.log"
    $logContent = Get-Content $logFile -Raw
    $logObject = $logContent | ConvertFrom-Json
    
    $requiredFields = @('timestamp', 'commitSha', 'commitAuthor', 'commitMessage', 
                        'prNumber', 'validationResult', 'validationMessage', 'correlationId')
    
    foreach ($field in $requiredFields) {
        if (-not $logObject.PSObject.Properties.Name.Contains($field)) {
            throw "Log entry missing required field: $field"
        }
    }
    
    # Validate field values
    if ($logObject.commitSha -ne "jkl012") {
        throw "commitSha mismatch"
    }
    if ($logObject.commitAuthor -ne "test@example.com") {
        throw "commitAuthor mismatch"
    }
    if ($logObject.prNumber -ne 4) {
        throw "prNumber mismatch"
    }
    if ($logObject.validationResult -ne "Pass") {
        throw "validationResult mismatch"
    }
}

Test-CommitValidation -TestName "Multiple log entries append correctly" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test5"
    
    # Write first entry
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "mno345" `
        -CommitAuthor "test1@example.com" `
        -CommitMessage "first commit" `
        -PRNumber 5 `
        -ValidationResult "Pass" `
        -LogDirectory $testDir
    
    # Write second entry
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "pqr678" `
        -CommitAuthor "test2@example.com" `
        -CommitMessage "second commit" `
        -PRNumber 5 `
        -ValidationResult "Fail" `
        -LogDirectory $testDir
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $logFile = Join-Path $testDir "$logDate-validation.log"
    $logLines = Get-Content $logFile
    
    if ($logLines.Count -ne 2) {
        throw "Expected 2 log entries, found $($logLines.Count)"
    }
    
    # Validate both entries are valid JSON
    $entry1 = $logLines[0] | ConvertFrom-Json
    $entry2 = $logLines[1] | ConvertFrom-Json
    
    if ($entry1.commitSha -ne "mno345") {
        throw "First entry commitSha mismatch"
    }
    if ($entry2.commitSha -ne "pqr678") {
        throw "Second entry commitSha mismatch"
    }
}

Test-CommitValidation -TestName "Timestamp is in ISO 8601 format" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test6"
    
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "stu901" `
        -CommitAuthor "test@example.com" `
        -CommitMessage "test commit" `
        -PRNumber 6 `
        -ValidationResult "Pass" `
        -LogDirectory $testDir
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $logFile = Join-Path $testDir "$logDate-validation.log"
    $logContent = Get-Content $logFile -Raw
    
    # Check the raw JSON string for ISO 8601 format pattern
    # Pattern: "timestamp":"2026-02-10T00:39:47.372Z"
    if ($logContent -notmatch '"timestamp":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z"') {
        throw "Timestamp is not in ISO 8601 format in raw JSON: $logContent"
    }
    
    # Also verify it can be parsed as JSON
    $logObject = $logContent | ConvertFrom-Json
    if (-not $logObject.timestamp) {
        throw "Timestamp field missing after JSON parsing"
    }
}

Test-CommitValidation -TestName "ValidationResult accepts valid values" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test7"
    
    $validResults = @("Pass", "Fail", "Skip")
    
    foreach ($result in $validResults) {
        & "$PSScriptRoot/Write-ValidationLog.ps1" `
            -CommitSha "test$result" `
            -CommitAuthor "test@example.com" `
            -CommitMessage "test commit" `
            -PRNumber 7 `
            -ValidationResult $result `
            -LogDirectory $testDir
    }
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $logFile = Join-Path $testDir "$logDate-validation.log"
    $logLines = Get-Content $logFile
    
    if ($logLines.Count -ne 3) {
        throw "Expected 3 log entries, found $($logLines.Count)"
    }
}

Test-CommitValidation -TestName "Auto-generates correlation ID if not provided" -TestBlock {
    $testDir = Join-Path $script:TestLogDir "test8"
    
    & "$PSScriptRoot/Write-ValidationLog.ps1" `
        -CommitSha "vwx234" `
        -CommitAuthor "test@example.com" `
        -CommitMessage "test commit" `
        -PRNumber 8 `
        -ValidationResult "Pass" `
        -LogDirectory $testDir
    
    $logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $logFile = Join-Path $testDir "$logDate-validation.log"
    $logContent = Get-Content $logFile -Raw
    $logObject = $logContent | ConvertFrom-Json
    
    if ([string]::IsNullOrWhiteSpace($logObject.correlationId)) {
        throw "Correlation ID was not auto-generated"
    }
    
    # Validate it's a GUID format
    if ($logObject.correlationId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        throw "Correlation ID is not in GUID format: $($logObject.correlationId)"
    }
}

#endregion

# Print summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Magenta
Write-Host "Total tests: $($script:PassedTests + $script:FailedTests)"
Write-Host "Passed: $script:PassedTests" -ForegroundColor Green
Write-Host "Failed: $script:FailedTests" -ForegroundColor Red

if ($script:FailedTests -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $script:TestResults | Where-Object { $_.Result -eq "FAILED" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Error)"
    }
}

# Clean up test directory after tests
if (Test-Path $script:TestLogDir) {
    Remove-Item -Path $script:TestLogDir -Recurse -Force
}

# Exit with appropriate code
if ($script:FailedTests -gt 0) {
    exit 1
}

Write-Host "`n✓ All tests passed!" -ForegroundColor Green
exit 0
