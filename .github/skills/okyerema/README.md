# Okyerema - Structured JSON Logging

> "Okyerema" (oh-CHEH-reh-mah) - Akan/Twi for "drummer" or "one who communicates through drums"

Okyerema provides structured JSON logging for operations within the Akwaaba system. Just as traditional drummers communicate important messages across distances, this logging system communicates operational status clearly and efficiently.

## Quick Start

```powershell
# Basic usage
. .\.github\skills\okyerema\Write-OkyeremaLog.ps1 -Level Info -Operation "Deploy" -Message "Deployment started"

# With correlation ID to track related operations
$correlationId = [guid]::NewGuid().ToString()
. .\.github\skills\okyerema\Write-OkyeremaLog.ps1 -Level Info -Operation "Step1" -Message "Starting" -CorrelationId $correlationId
. .\.github\skills\okyerema\Write-OkyeremaLog.ps1 -Level Info -Operation "Step2" -Message "Processing" -CorrelationId $correlationId

# Silent mode (no console output)
. .\.github\skills\okyerema\Write-OkyeremaLog.ps1 -Level Info -Operation "Background" -Message "Processing" -Quiet
```

## Features

### ✅ Structured JSON Output
Every log entry is valid JSON with a consistent schema:
```json
{
  "timestamp": "2026-02-06T22:24:35.7200853+00:00",
  "level": "Info",
  "operation": "Deploy",
  "message": "Deployment started",
  "correlationId": "abc-123-def"
}
```

### 📊 Multiple Log Levels
- **Info**: Normal operational messages
- **Warn**: Warning conditions that don't prevent operation
- **Error**: Error conditions that may affect operation
- **Debug**: Detailed information for troubleshooting

### 🔍 Correlation IDs
Track related operations across multiple log entries using correlation IDs. Perfect for:
- Multi-step workflows
- Distributed operations
- Request tracing
- Debugging complex scenarios

### 🎯 Clean Output Streams
- Logs go to **stderr** (visible in console but separate from data)
- **stdout** stays clean for pipeline data

### 🤫 Quiet Mode
Use `-Quiet` switch to suppress console output for silent operation.

## Files

- **SKILL.md** - Skill documentation with YAML front matter
- **Write-OkyeremaLog.ps1** - Main logging script
- **Test-OkyeremaLog.ps1** - Test suite demonstrating all features
- **Examples-OkyeremaLog.ps1** - Real-world usage examples

## Usage Examples

### Example 1: Simple Logging
```powershell
Write-OkyeremaLog -Level Info -Operation "Backup" -Message "Backup completed successfully"
```

### Example 2: Error Logging
```powershell
try {
    # Some operation that might fail
    Invoke-RiskyOperation
} catch {
    Write-OkyeremaLog -Level Error -Operation "RiskyOp" -Message $_.Exception.Message
}
```

### Example 3: Correlated Workflow
```powershell
$workflowId = [guid]::NewGuid().ToString()

Write-OkyeremaLog -Level Info -Operation "Workflow" -Message "Started" -CorrelationId $workflowId
Write-OkyeremaLog -Level Info -Operation "Step1" -Message "Validating input" -CorrelationId $workflowId
Write-OkyeremaLog -Level Info -Operation "Step2" -Message "Processing data" -CorrelationId $workflowId
Write-OkyeremaLog -Level Info -Operation "Workflow" -Message "Completed" -CorrelationId $workflowId
```

### Example 4: CI/CD Pipeline Integration
```powershell
# Log to stderr, pipe actual data to stdout
Write-OkyeremaLog -Level Info -Operation "Pipeline" -Message "Starting data processing"
$results = Get-ProcessingResults
Write-OkyeremaLog -Level Info -Operation "Pipeline" -Message "Processing completed"
$results | ConvertTo-Json | Write-Output
```

## Testing

Run the test suite to see all features in action:
```powershell
.\Test-OkyeremaLog.ps1
```

Run real-world examples:
```powershell
.\Examples-OkyeremaLog.ps1
```

## Log Format Specification

Each log entry contains:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `timestamp` | string | Yes | ISO 8601 timestamp (UTC) |
| `level` | string | Yes | One of: Info, Warn, Error, Debug |
| `operation` | string | Yes | Name of the operation being logged |
| `message` | string | Yes | Human-readable log message |
| `correlationId` | string | No | Optional ID to correlate related logs |

## Integration Tips

### With CI/CD Pipelines
```powershell
# Log to stderr, pipe data to stdout
$results = Get-ProcessingResults
Write-OkyeremaLog -Level Info -Operation "Pipeline" -Message "Processing completed"
$results | ConvertTo-Json | Write-Output
```

### With Error Handling
```powershell
try {
    Do-Something
    Write-OkyeremaLog -Level Info -Operation "Task" -Message "Success"
} catch {
    Write-OkyeremaLog -Level Error -Operation "Task" -Message $_.Exception.Message
    throw
}
```

### With Long-Running Operations
```powershell
$opId = [guid]::NewGuid().ToString()
Write-OkyeremaLog -Level Info -Operation "LongTask" -Message "Started" -CorrelationId $opId

1..100 | ForEach-Object {
    # Do work
    if ($_ % 10 -eq 0) {
        Write-OkyeremaLog -Level Debug -Operation "LongTask" -Message "Progress: $_%" -CorrelationId $opId
    }
}

Write-OkyeremaLog -Level Info -Operation "LongTask" -Message "Completed" -CorrelationId $opId
```

## Contributing

When contributing to Okyerema:
1. Maintain backward compatibility with the JSON schema
2. Ensure all parameters have validation
3. Include comment-based help for all functions
4. Add examples for new features
5. Update this README

## License

Part of the Akwaaba project. See repository license for details.
