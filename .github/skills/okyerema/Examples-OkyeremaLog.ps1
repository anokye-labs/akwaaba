<#
.SYNOPSIS
    Real-world usage examples for Write-OkyeremaLog.ps1

.DESCRIPTION
    Demonstrates practical scenarios where Write-OkyeremaLog would be used in
    actual operations, workflows, and automation scripts.
#>

# Get the path to the Write-OkyeremaLog script
$scriptPath = Join-Path $PSScriptRoot "Write-OkyeremaLog.ps1"

Write-Host "`n=== Real-World Usage Examples ===" -ForegroundColor Cyan
Write-Host "This demonstrates how Write-OkyeremaLog integrates into actual workflows`n" -ForegroundColor Yellow

# Example 1: Deployment workflow with correlation ID
Write-Host "Example 1: Deployment Workflow" -ForegroundColor Magenta
$deploymentId = [guid]::NewGuid().ToString()
Write-Host "Deploying application with correlation ID: $deploymentId`n" -ForegroundColor Gray

& $scriptPath -Level Info -Operation "PreDeploy" -Message "Validating deployment prerequisites" -CorrelationId $deploymentId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Info -Operation "PreDeploy" -Message "Prerequisites validated successfully" -CorrelationId $deploymentId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Info -Operation "Deploy" -Message "Starting application deployment" -CorrelationId $deploymentId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Warn -Operation "Deploy" -Message "Using default configuration for optional settings" -CorrelationId $deploymentId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Info -Operation "Deploy" -Message "Deployment completed successfully" -CorrelationId $deploymentId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Info -Operation "PostDeploy" -Message "Running smoke tests" -CorrelationId $deploymentId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Info -Operation "PostDeploy" -Message "All smoke tests passed" -CorrelationId $deploymentId

Write-Host "`n---`n" -ForegroundColor Gray

# Example 2: Error handling in a data processing pipeline
Write-Host "Example 2: Data Processing with Error Handling" -ForegroundColor Magenta
$batchId = [guid]::NewGuid().ToString()
Write-Host "Processing data batch with correlation ID: $batchId`n" -ForegroundColor Gray

& $scriptPath -Level Info -Operation "DataPipeline" -Message "Starting data processing batch" -CorrelationId $batchId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Debug -Operation "DataPipeline" -Message "Processing 1000 records" -CorrelationId $batchId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Warn -Operation "DataValidation" -Message "Found 3 records with missing optional fields" -CorrelationId $batchId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Error -Operation "DataValidation" -Message "Found 1 record with invalid format, skipping" -CorrelationId $batchId
Start-Sleep -Milliseconds 500

& $scriptPath -Level Info -Operation "DataPipeline" -Message "Successfully processed 999 of 1000 records" -CorrelationId $batchId

Write-Host "`n---`n" -ForegroundColor Gray

# Example 3: Silent background operation
Write-Host "Example 3: Silent Background Job (using -Quiet)" -ForegroundColor Magenta
Write-Host "Running background task silently...`n" -ForegroundColor Gray

$jobId = [guid]::NewGuid().ToString()
1..5 | ForEach-Object {
    & $scriptPath -Level Info -Operation "BackgroundSync" -Message "Processing chunk $_/5" -CorrelationId $jobId -Quiet
    Start-Sleep -Milliseconds 200
}

Write-Host "Background job completed (no console output from logs)`n" -ForegroundColor Green

Write-Host "---`n" -ForegroundColor Gray

# Example 4: Debugging a complex operation
Write-Host "Example 4: Debug-level Logging for Troubleshooting" -ForegroundColor Magenta
$operationId = [guid]::NewGuid().ToString()
Write-Host "Executing complex operation with debug logging: $operationId`n" -ForegroundColor Gray

& $scriptPath -Level Info -Operation "ComplexOp" -Message "Starting complex operation" -CorrelationId $operationId
Start-Sleep -Milliseconds 300

& $scriptPath -Level Debug -Operation "ComplexOp" -Message "Step 1: Initialized connection pool with 10 connections" -CorrelationId $operationId
Start-Sleep -Milliseconds 300

& $scriptPath -Level Debug -Operation "ComplexOp" -Message "Step 2: Retrieved configuration from cache" -CorrelationId $operationId
Start-Sleep -Milliseconds 300

& $scriptPath -Level Debug -Operation "ComplexOp" -Message "Step 3: Validated user permissions" -CorrelationId $operationId
Start-Sleep -Milliseconds 300

& $scriptPath -Level Info -Operation "ComplexOp" -Message "Operation completed in 1.2 seconds" -CorrelationId $operationId

Write-Host "`n---`n" -ForegroundColor Gray

# Example 5: Integration with existing scripts (capturing for processing)
Write-Host "Example 5: Pipeline Integration" -ForegroundColor Magenta
Write-Host "Demonstrating log object capture for programmatic processing`n" -ForegroundColor Gray

$logs = @()
$sessionId = [guid]::NewGuid().ToString()

$logs += & $scriptPath -Level Info -Operation "Session" -Message "Session started" -CorrelationId $sessionId -Quiet
Start-Sleep -Milliseconds 200

$logs += & $scriptPath -Level Info -Operation "Session" -Message "User authenticated" -CorrelationId $sessionId -Quiet
Start-Sleep -Milliseconds 200

$logs += & $scriptPath -Level Warn -Operation "Session" -Message "Password expires in 5 days" -CorrelationId $sessionId -Quiet
Start-Sleep -Milliseconds 200

$logs += & $scriptPath -Level Info -Operation "Session" -Message "Session ended" -CorrelationId $sessionId -Quiet

Write-Host "Captured $($logs.Count) log entries for programmatic analysis:" -ForegroundColor Cyan
$logs | ForEach-Object { Write-Host "  [$($_.level)] $($_.operation): $($_.message)" -ForegroundColor DarkGray }

Write-Host "`n=== Examples Complete ===" -ForegroundColor Cyan
Write-Host "Check stderr output above to see the JSON-formatted logs" -ForegroundColor Yellow
