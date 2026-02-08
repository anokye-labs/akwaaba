<#
.SYNOPSIS
    Example and test script for Write-OkyeremaLog.ps1

.DESCRIPTION
    Demonstrates various usage patterns of the Write-OkyeremaLog script and validates
    that it works correctly.
#>

# Get the path to the Write-OkyeremaLog script
$scriptPath = Join-Path $PSScriptRoot "Write-OkyeremaLog.ps1"

Write-Host "`n=== Testing Write-OkyeremaLog.ps1 ===" -ForegroundColor Cyan
Write-Host "Note: JSON logs appear below (on stderr)`n" -ForegroundColor Yellow

# Test 1: Info level log
Write-Host "Test 1: Info level log" -ForegroundColor Green
& $scriptPath -Level Info -Operation "Test" -Message "This is an info message"

# Test 2: Warning level log
Write-Host "`nTest 2: Warning level log" -ForegroundColor Green
& $scriptPath -Level Warn -Operation "Validate" -Message "This is a warning message"

# Test 3: Error level log
Write-Host "`nTest 3: Error level log" -ForegroundColor Green
& $scriptPath -Level Error -Operation "Process" -Message "This is an error message"

# Test 4: Debug level log
Write-Host "`nTest 4: Debug level log" -ForegroundColor Green
& $scriptPath -Level Debug -Operation "Trace" -Message "This is a debug message"

# Test 5: Log with correlation ID
Write-Host "`nTest 5: Log with correlation ID" -ForegroundColor Green
$correlationId = [guid]::NewGuid().ToString()
& $scriptPath -Level Info -Operation "Deploy" -Message "Deployment started" -CorrelationId $correlationId

# Test 6: Quiet mode (should not output to console)
Write-Host "`nTest 6: Quiet mode (should see no JSON output below)" -ForegroundColor Green
& $scriptPath -Level Info -Operation "Background" -Message "This log is suppressed" -Quiet
Write-Host "(If you see JSON above this line, the Quiet switch is not working)" -ForegroundColor Yellow

# Test 7: Multiple operations with same correlation ID
Write-Host "`nTest 7: Multiple operations with same correlation ID" -ForegroundColor Green
$operationId = [guid]::NewGuid().ToString()
& $scriptPath -Level Info -Operation "Step1" -Message "Starting operation" -CorrelationId $operationId
& $scriptPath -Level Info -Operation "Step2" -Message "Processing data" -CorrelationId $operationId
& $scriptPath -Level Info -Operation "Step3" -Message "Completing operation" -CorrelationId $operationId

Write-Host "`n=== All tests completed ===" -ForegroundColor Cyan
