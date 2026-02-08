<#
.SYNOPSIS
    Structured JSON logging for Okyerema operations.

.DESCRIPTION
    Write-OkyeremaLog.ps1 provides structured JSON logging to stderr for all Okyerema
    orchestration operations. Logs include timestamp, level, message, operation name,
    and correlation ID. Stdout remains clean for pipeline data.

.PARAMETER Message
    The log message to write.

.PARAMETER Level
    The log level. Valid values: Info, Warn, Error, Debug. Default is Info.

.PARAMETER Operation
    Optional operation name (e.g., "CreateIssue", "UpdateHierarchy").

.PARAMETER CorrelationId
    Optional correlation ID for tracing related operations.

.PARAMETER Quiet
    If specified, suppresses all log output. No JSON will be written to stderr.

.OUTPUTS
    Writes structured JSON to stderr (unless -Quiet is specified). Format:
    {"timestamp":"2026-02-08T22:15:23.505Z","level":"Info","message":"...","operation":"...","correlationId":"..."}

.EXAMPLE
    Write-OkyeremaLog -Message "Creating epic issue" -Level Info -Operation "CreateIssue"

.EXAMPLE
    Write-OkyeremaLog -Message "Issue created successfully" -Level Info -Operation "CreateIssue" -CorrelationId "abc123"

.EXAMPLE
    Write-OkyeremaLog -Message "Failed to create issue" -Level Error -Operation "CreateIssue" -Quiet

.NOTES
    Logs are written exclusively to stderr (unless -Quiet is specified). 
    Stdout remains clean for pipeline data.
    Use -Quiet to completely suppress log output for specific operations.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Info", "Warn", "Error", "Debug")]
    [string]$Level = "Info",

    [Parameter(Mandatory = $false)]
    [string]$Operation = "",

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId = "",

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Build log object
$logObject = [ordered]@{
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    level = $Level
    message = $Message
}

# Add optional fields only if provided
if ($Operation) {
    $logObject.operation = $Operation
}

if ($CorrelationId) {
    $logObject.correlationId = $CorrelationId
}

# Convert to JSON (compact, single line)
$json = $logObject | ConvertTo-Json -Compress

# Write to stderr
if (-not $Quiet) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json + [Environment]::NewLine)
    $Stream = [Console]::OpenStandardError()
    $Stream.Write($bytes, 0, $bytes.Length)
    $Stream.Flush()
}
