<#
.SYNOPSIS
    Structured JSON audit logging for commit validation operations.

.DESCRIPTION
    Write-ValidationLog.ps1 provides structured JSON audit logging for commit validation
    attempts. Logs include timestamp, commit author, PR number, validation result,
    and correlation ID. Logs are stored in logs/commit-validation/ directory for
    future analysis of patterns.

.PARAMETER CommitSha
    The SHA of the commit being validated.

.PARAMETER CommitAuthor
    The author of the commit (name or email).

.PARAMETER CommitMessage
    The commit message being validated.

.PARAMETER PRNumber
    The pull request number (if applicable).

.PARAMETER ValidationResult
    The result of validation. Valid values: Pass, Fail, Skip.

.PARAMETER ValidationMessage
    Optional message describing the validation result or error.

.PARAMETER CorrelationId
    Optional correlation ID for tracing related operations.

.PARAMETER LogDirectory
    Directory where logs should be stored. Default is logs/commit-validation.

.OUTPUTS
    Writes structured JSON to log file in the specified directory.
    Format: YYYY-MM-DD-validation.log (one log entry per line)

.EXAMPLE
    Write-ValidationLog -CommitSha "abc123" -CommitAuthor "user@example.com" -CommitMessage "fix: update readme" -PRNumber 42 -ValidationResult Pass

.EXAMPLE
    Write-ValidationLog -CommitSha "def456" -CommitAuthor "user@example.com" -CommitMessage "update code" -PRNumber 42 -ValidationResult Fail -ValidationMessage "No issue reference found"

.NOTES
    Logs are appended to daily log files in JSON format for easy parsing and analysis.
    Each log entry is a single line of JSON.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CommitSha,

    [Parameter(Mandatory = $true)]
    [string]$CommitAuthor,

    [Parameter(Mandatory = $true)]
    [string]$CommitMessage,

    [Parameter(Mandatory = $false)]
    [int]$PRNumber = 0,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Pass", "Fail", "Skip")]
    [string]$ValidationResult,

    [Parameter(Mandatory = $false)]
    [string]$ValidationMessage = "",

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId = "",

    [Parameter(Mandatory = $false)]
    [string]$LogDirectory = "logs/commit-validation"
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Build log object
$timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ", [System.Globalization.CultureInfo]::InvariantCulture)
$logObject = [ordered]@{
    timestamp = $timestamp
    commitSha = $CommitSha
    commitAuthor = $CommitAuthor
    commitMessage = $CommitMessage
    prNumber = $PRNumber
    validationResult = $ValidationResult
    validationMessage = $ValidationMessage
    correlationId = $CorrelationId
}

# Convert to JSON (compact, single line)
$json = $logObject | ConvertTo-Json -Compress

# Ensure log directory exists
if ([System.IO.Path]::IsPathRooted($LogDirectory)) {
    $logPath = $LogDirectory
} else {
    $logPath = Join-Path $PWD $LogDirectory
}

if (-not (Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

# Create log filename based on current date (UTC)
$logDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$logFile = Join-Path $logPath "$logDate-validation.log"

# Append log entry to file
Add-Content -Path $logFile -Value $json -Encoding UTF8

# Also write to stderr for immediate visibility
Write-Host "::notice::Validation logged: $ValidationResult for commit $CommitSha" -ForegroundColor Gray
