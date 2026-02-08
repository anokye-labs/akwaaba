# PowerShell Scripts

This directory contains PowerShell automation scripts for the Akwaaba repository.

## Available Scripts

### ConvertTo-EscapedGraphQL.ps1

A utility function that safely escapes text for use in GraphQL string literals. Addresses escaping bugs identified in PR #6 review comments.

**Features:**
- Handles newlines (converts to `\n`)
- Escapes double quotes (converts to `\"`)
- Escapes backslashes (converts to `\\`)
- Preserves emoji and unicode characters
- Pipe-friendly for easy integration
- Handles multiline heredocs
- Tab character escaping (converts to `\t`)

**Usage:**

```powershell
. ./scripts/ConvertTo-EscapedGraphQL.ps1
"Hello `"World`"" | ConvertTo-EscapedGraphQL
```

### Get-RepoContext.ps1

Fetches repository context (repo ID, issue types, project IDs, and label IDs) in one query.

**Features:**
- One-shot query to fetch all repository metadata
- Returns PSCustomObject with `.RepoId`, `.IssueTypes`, `.ProjectId`, `.Labels`
- Session-based caching for efficient reuse
- `-Refresh` switch to force re-fetch

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated

**Usage:**

```powershell
$context = ./scripts/Get-RepoContext.ps1
Write-Host "Repository ID: $($context.RepoId)"

# Force refresh the cache
$context = ./scripts/Get-RepoContext.ps1 -Refresh
```

### Get-DagCompletionReport.ps1

Generate a summary report of DAG progress suitable for status updates.

**Features:**
- Per-phase breakdown (by Epic)
- Per-feature breakdown (by Feature under Epic)
- Burndown data (closed over time)
- Multiple output formats: Console, Markdown table, or JSON
- Recursive hierarchy traversal
- Progress visualization with progress bars (Console format)

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Depends on: `Invoke-GraphQL.ps1`, `Get-RepoContext.ps1`, `Write-OkyeremaLog.ps1`

**Usage:**

```powershell
# Console format (default) - colorful output with progress bars
./scripts/Get-DagCompletionReport.ps1 -RootIssueNumber 1

# Markdown format for documentation and status updates
./scripts/Get-DagCompletionReport.ps1 -RootIssueNumber 1 -OutputFormat Markdown

# JSON format for automation and data processing
./scripts/Get-DagCompletionReport.ps1 -RootIssueNumber 1 -OutputFormat Json

# Include burndown data showing completion over time
./scripts/Get-DagCompletionReport.ps1 -RootIssueNumber 1 -IncludeBurndown

# Test mode to see queries without executing
./scripts/Get-DagCompletionReport.ps1 -RootIssueNumber 1 -DryRun
```

**Testing:**

```powershell
# Run mock test to verify output formatters
./scripts/Test-Get-DagCompletionReport-Mock.ps1

# Run full integration test (requires valid issue number)
./scripts/Test-Get-DagCompletionReport.ps1 -IssueNumber 1
```

### Invoke-GraphQL.ps1

Centralized GraphQL executor with retry logic, rate-limit handling, and structured error output.

**Features:**
- Retry with exponential backoff on 502/503/rate-limit errors
- Structured error objects (not raw stderr)
- DryRun mode that logs the query without executing
- Verbose logging with correlation IDs for tracing

**Usage:**

```powershell
$query = 'query { viewer { login } }'
$result = ./Invoke-GraphQL.ps1 -Query $query

$vars = @{ owner = "octocat"; name = "Hello-World" }
$result = ./Invoke-GraphQL.ps1 -Query $query -Variables $vars

# DryRun mode
$result = ./Invoke-GraphQL.ps1 -Query $query -DryRun
```

## Best Practices

1. **Always use Invoke-GraphQL.ps1** instead of calling `gh api graphql` directly
2. **Check the Success property** before using the Data
3. **Use -Verbose** for debugging and troubleshooting
4. **Use -DryRun** to test queries without executing them

## Examples

See `examples/GraphQL-Examples.ps1` for more usage examples.

## Contributing

When adding new scripts to this directory:

1. Follow PowerShell best practices
2. Include comprehensive comment-based help
3. Add test scripts when applicable
4. Update this README with documentation
5. Use the `ConvertTo-Verb` naming convention for functions
