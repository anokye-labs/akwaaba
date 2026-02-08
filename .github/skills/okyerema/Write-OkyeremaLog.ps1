<#
.SYNOPSIS
    Writes structured JSON log entries for Okyerema operations.

.DESCRIPTION
    Write-OkyeremaLog outputs structured JSON log entries to stderr, keeping stdout
    clean for pipeline data. Each log entry includes a timestamp, log level, operation
    name, message, and optional correlation ID.
    
    The name "Okyerema" comes from Akan/Twi meaning "drummer" or "one who communicates
    through drums" - fitting for a logging system that communicates operational status.

.PARAMETER Level
    The log level: Info, Warn, Error, or Debug.

.PARAMETER Operation
    The name of the operation being logged.

.PARAMETER Message
    The log message to record.

.PARAMETER CorrelationId
    Optional correlation ID to track related operations.

.PARAMETER Quiet
    Suppresses console output when specified.

.EXAMPLE
    Write-OkyeremaLog -Level Info -Operation "Deploy" -Message "Deployment started"
    
    Writes an Info level log entry for a deployment operation.

.EXAMPLE
    Write-OkyeremaLog -Level Warn -Operation "Validate" -Message "Missing optional field" -CorrelationId "abc-123"
    
    Writes a Warning level log entry with a correlation ID.

.EXAMPLE
    Write-OkyeremaLog -Level Error -Operation "Build" -Message "Build failed" -Quiet
    
    Writes an Error level log entry without console output.

.NOTES
    All logs are written to stderr to keep stdout clean for pipeline data.
    Logs are formatted as valid JSON for easy parsing and processing.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Info', 'Warn', 'Error', 'Debug')]
    [string]$Level,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId = '',

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Create the log entry object
$logEntry = [ordered]@{
    timestamp     = (Get-Date -Format "o")
    level         = $Level
    operation     = $Operation
    message       = $Message
}

# Add correlation ID if provided
if ($CorrelationId) {
    $logEntry.correlationId = $CorrelationId
}

# Convert to JSON (compact format, single line)
$jsonLog = $logEntry | ConvertTo-Json -Compress

# Write to stderr unless Quiet is specified
if (-not $Quiet) {
    [Console]::Error.WriteLine($jsonLog)
}
