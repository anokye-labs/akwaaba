# PowerShell Scripts

This directory contains PowerShell automation scripts for the Akwaaba repository.

## Available Scripts

### Invoke-GraphQL.ps1

Centralized GraphQL executor with retry logic, rate-limit handling, and structured error output.

**Features:**
- Retry with exponential backoff on 502/503/rate-limit errors
- Structured error objects (not raw stderr)
- DryRun mode that logs the query without executing
- Verbose logging with correlation IDs for tracing

**Usage:**

```powershell
# Simple query
$query = 'query { viewer { login } }'
$result = ./Invoke-GraphQL.ps1 -Query $query

# Query with variables
$query = 'query($owner: String!, $name: String!) { 
    repository(owner: $owner, name: $name) { 
        name 
        description 
    } 
}'
$vars = @{ owner = "octocat"; name = "Hello-World" }
$result = ./Invoke-GraphQL.ps1 -Query $query -Variables $vars

# DryRun mode (logs without executing)
$result = ./Invoke-GraphQL.ps1 -Query $query -DryRun

# With verbose logging
$result = ./Invoke-GraphQL.ps1 -Query $query -Verbose

# Custom retry settings
$result = ./Invoke-GraphQL.ps1 -Query $query -MaxRetries 5 -InitialDelaySeconds 3
```

**Response Object:**

The script returns a structured PSCustomObject:

```powershell
@{
    Success       = $true/$false     # Boolean indicating success
    Data          = <response data>  # GraphQL response data (if successful)
    Errors        = @(<errors>)      # Array of structured error objects (if failed)
    CorrelationId = "guid"           # Correlation ID for tracing
    Attempts      = 1                # Number of attempts made
}
```

**Error Object Structure:**

```powershell
@{
    Message       = "Error message"
    Type          = "ErrorType"
    Path          = @("field", "path")
    CorrelationId = "guid"
    ExitCode      = 1
    RawError      = "Full error text"
}
```

## Best Practices

1. **Always use Invoke-GraphQL.ps1** instead of calling `gh api graphql` directly
2. **Check the Success property** before using the Data
3. **Use -Verbose** for debugging and troubleshooting
4. **Use -DryRun** to test queries without executing them
5. **Include correlation IDs** in logs for easier tracing across multiple calls

## Examples

See `examples/GraphQL-Examples.ps1` for more usage examples.
