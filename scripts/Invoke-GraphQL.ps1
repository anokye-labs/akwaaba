<#
.SYNOPSIS
    Centralized GraphQL executor with retry logic, rate-limit handling, and structured error output.

.DESCRIPTION
    This script provides a robust wrapper around the GitHub GraphQL API (gh api graphql).
    It includes:
    - Retry with exponential backoff on 502/503/rate-limit errors
    - Structured error objects (not raw stderr)
    - DryRun mode that logs the query without executing
    - Verbose logging with correlation IDs for tracing

.PARAMETER Query
    The GraphQL query string to execute.

.PARAMETER Variables
    Optional hashtable of GraphQL variables to pass with the query.

.PARAMETER DryRun
    If specified, logs the query without executing it against the API.

.PARAMETER MaxRetries
    Maximum number of retry attempts for transient failures. Default is 3.

.PARAMETER InitialDelaySeconds
    Initial delay in seconds before first retry. Default is 2 seconds.

.PARAMETER MaxDelaySeconds
    Maximum delay in seconds between retries. Default is 60 seconds.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    $query = 'query { viewer { login } }'
    Invoke-GraphQL -Query $query

.EXAMPLE
    $query = 'query($owner: String!, $name: String!) { repository(owner: $owner, name: $name) { name } }'
    $vars = @{ owner = "octocat"; name = "Hello-World" }
    Invoke-GraphQL -Query $query -Variables $vars

.EXAMPLE
    Invoke-GraphQL -Query $query -DryRun -Verbose

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - Data: The response data (if successful)
    - Errors: Array of structured error objects (if failed)
    - CorrelationId: The correlation ID for this request
    - Attempts: Number of attempts made
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,

    [Parameter(Mandatory = $false)]
    [hashtable]$Variables = @{},

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [int]$MaxRetries = 3,

    [Parameter(Mandatory = $false)]
    [int]$InitialDelaySeconds = 2,

    [Parameter(Mandatory = $false)]
    [int]$MaxDelaySeconds = 60,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

Write-Verbose "[$CorrelationId] Starting GraphQL request"

# DryRun mode - log and exit
if ($DryRun) {
    Write-Verbose "[$CorrelationId] DryRun mode enabled - query will not be executed"
    Write-Host "=== DryRun Mode ===" -ForegroundColor Cyan
    Write-Host "Correlation ID: $CorrelationId" -ForegroundColor Cyan
    Write-Host "Query:" -ForegroundColor Cyan
    Write-Host $Query -ForegroundColor Yellow
    
    if ($Variables.Count -gt 0) {
        Write-Host "Variables:" -ForegroundColor Cyan
        $Variables.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "==================" -ForegroundColor Cyan
    
    return [PSCustomObject]@{
        Success       = $true
        Data          = $null
        Errors        = @()
        CorrelationId = $CorrelationId
        Attempts      = 0
        DryRun        = $true
    }
}

# Function to check if error is retryable
function Test-RetryableError {
    param([string]$ErrorMessage, [int]$ExitCode)
    
    # Check for HTTP error codes
    if ($ErrorMessage -match '502|503') {
        return $true
    }
    
    # Check for rate limit errors
    if ($ErrorMessage -match 'rate limit|rate-limit|retry after|too many requests|429') {
        return $true
    }
    
    # Check for timeout errors
    if ($ErrorMessage -match 'timeout|timed out') {
        return $true
    }
    
    return $false
}

# Function to calculate delay with exponential backoff
function Get-RetryDelay {
    param([int]$Attempt, [int]$InitialDelay, [int]$MaxDelay)
    
    $delay = $InitialDelay * [Math]::Pow(2, $Attempt - 1)
    
    # Add jitter (random variation between 0-25% of delay)
    $jitter = Get-Random -Minimum 0 -Maximum ([int]($delay * 0.25))
    $delay = $delay + $jitter
    
    # Cap at max delay
    return [Math]::Min($delay, $MaxDelay)
}

# Function to parse structured errors from stderr
function ConvertTo-StructuredError {
    param([string]$ErrorMessage, [int]$ExitCode, [string]$CorrelationId)
    
    # Try to parse JSON error if present
    if ($ErrorMessage -match '\{.*"errors".*\}') {
        try {
            $jsonMatch = [regex]::Match($ErrorMessage, '\{.*\}').Value
            $errorObj = $jsonMatch | ConvertFrom-Json
            
            if ($errorObj.errors) {
                return $errorObj.errors | ForEach-Object {
                    [PSCustomObject]@{
                        Message       = $_.message
                        Type          = $_.type
                        Path          = $_.path
                        CorrelationId = $CorrelationId
                        ExitCode      = $ExitCode
                        RawError      = $ErrorMessage
                    }
                }
            }
        }
        catch {
            # Fall through to generic error parsing
        }
    }
    
    # Generic structured error
    return @([PSCustomObject]@{
        Message       = $ErrorMessage
        Type          = "GraphQLExecutionError"
        Path          = $null
        CorrelationId = $CorrelationId
        ExitCode      = $ExitCode
        RawError      = $ErrorMessage
    })
}

# Main execution loop with retry logic
$attempt = 0
$lastError = $null

while ($attempt -lt ($MaxRetries + 1)) {
    $attempt++
    
    Write-Verbose "[$CorrelationId] Attempt $attempt of $($MaxRetries + 1)"
    
    try {
        # Build the gh command
        $ghArgs = @('api', 'graphql')
        
        # Add query
        $ghArgs += @('-f', "query=$Query")
        
        # Add variables
        foreach ($var in $Variables.GetEnumerator()) {
            $varValue = $var.Value
            
            # Handle different value types
            if ($varValue -is [int] -or $varValue -is [bool]) {
                $ghArgs += @('-F', "$($var.Key)=$varValue")
            }
            else {
                $ghArgs += @('-f', "$($var.Key)=$varValue")
            }
        }
        
        Write-Verbose "[$CorrelationId] Executing: gh $($ghArgs -join ' ')"
        
        # Execute the command and capture both stdout and stderr
        $output = & gh @ghArgs 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Verbose "[$CorrelationId] Request succeeded on attempt $attempt"
            
            # Parse the response
            try {
                $response = $output | ConvertFrom-Json
                
                # Check for GraphQL errors in response
                if ($response.errors) {
                    Write-Warning "[$CorrelationId] GraphQL returned errors"
                    
                    $structuredErrors = $response.errors | ForEach-Object {
                        [PSCustomObject]@{
                            Message       = $_.message
                            Type          = $_.type
                            Path          = $_.path
                            CorrelationId = $CorrelationId
                            ExitCode      = 0
                            RawError      = $_ | ConvertTo-Json -Compress
                        }
                    }
                    
                    return [PSCustomObject]@{
                        Success       = $false
                        Data          = $response.data
                        Errors        = $structuredErrors
                        CorrelationId = $CorrelationId
                        Attempts      = $attempt
                    }
                }
                
                # Success with data
                return [PSCustomObject]@{
                    Success       = $true
                    Data          = $response.data
                    Errors        = @()
                    CorrelationId = $CorrelationId
                    Attempts      = $attempt
                }
            }
            catch {
                Write-Warning "[$CorrelationId] Failed to parse response as JSON"
                $lastError = "Failed to parse response: $_"
                $structuredErrors = ConvertTo-StructuredError -ErrorMessage $lastError -ExitCode $exitCode -CorrelationId $CorrelationId
                
                return [PSCustomObject]@{
                    Success       = $false
                    Data          = $null
                    Errors        = $structuredErrors
                    CorrelationId = $CorrelationId
                    Attempts      = $attempt
                }
            }
        }
        else {
            # Command failed
            $errorMessage = ($output | Out-String).Trim()
            $lastError = $errorMessage
            
            Write-Verbose "[$CorrelationId] Request failed with exit code $exitCode"
            Write-Verbose "[$CorrelationId] Error: $errorMessage"
            
            # Check if error is retryable
            $isRetryable = Test-RetryableError -ErrorMessage $errorMessage -ExitCode $exitCode
            
            if ($isRetryable -and $attempt -lt ($MaxRetries + 1)) {
                $delay = Get-RetryDelay -Attempt $attempt -InitialDelay $InitialDelaySeconds -MaxDelay $MaxDelaySeconds
                Write-Warning "[$CorrelationId] Retryable error detected. Waiting $delay seconds before retry..."
                Start-Sleep -Seconds $delay
                continue
            }
            else {
                # Not retryable or out of retries
                if (-not $isRetryable) {
                    Write-Verbose "[$CorrelationId] Error is not retryable"
                }
                else {
                    Write-Verbose "[$CorrelationId] Max retries exceeded"
                }
                
                $structuredErrors = ConvertTo-StructuredError -ErrorMessage $errorMessage -ExitCode $exitCode -CorrelationId $CorrelationId
                
                return [PSCustomObject]@{
                    Success       = $false
                    Data          = $null
                    Errors        = $structuredErrors
                    CorrelationId = $CorrelationId
                    Attempts      = $attempt
                }
            }
        }
    }
    catch {
        $lastError = $_.Exception.Message
        Write-Verbose "[$CorrelationId] Exception occurred: $lastError"
        
        # Check if we should retry
        $isRetryable = Test-RetryableError -ErrorMessage $lastError -ExitCode 1
        
        if ($isRetryable -and $attempt -lt ($MaxRetries + 1)) {
            $delay = Get-RetryDelay -Attempt $attempt -InitialDelay $InitialDelaySeconds -MaxDelay $MaxDelaySeconds
            Write-Warning "[$CorrelationId] Retryable exception. Waiting $delay seconds before retry..."
            Start-Sleep -Seconds $delay
            continue
        }
        else {
            $structuredErrors = ConvertTo-StructuredError -ErrorMessage $lastError -ExitCode 1 -CorrelationId $CorrelationId
            
            return [PSCustomObject]@{
                Success       = $false
                Data          = $null
                Errors        = $structuredErrors
                CorrelationId = $CorrelationId
                Attempts      = $attempt
            }
        }
    }
}

# Should not reach here, but just in case
$structuredErrors = ConvertTo-StructuredError -ErrorMessage $lastError -ExitCode 1 -CorrelationId $CorrelationId

return [PSCustomObject]@{
    Success       = $false
    Data          = $null
    Errors        = $structuredErrors
    CorrelationId = $CorrelationId
    Attempts      = $attempt
}
