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

### Add-IssuesToProject.ps1

Bulk-add issues to a GitHub Project V2 and optionally set field values.

**Features:**
- Accepts issue numbers as array or pipeline input
- Automatically resolves project and issue IDs
- Sets custom field values (Status, Priority, etc.)
- Rate limiting between mutations to respect API limits
- Structured logging with correlation IDs

**Dependencies:**
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Basic usage
./scripts/Add-IssuesToProject.ps1 -IssueNumbers 101,102,103 -ProjectNumber 3

# With field values
./scripts/Add-IssuesToProject.ps1 -IssueNumbers 101,102 -ProjectNumber 3 `
    -FieldValues @{ Status = "In Progress"; Priority = "High" }

# Pipeline input
101, 102, 103 | ./scripts/Add-IssuesToProject.ps1 -ProjectNumber 3

# Explicit owner/repo
./scripts/Add-IssuesToProject.ps1 -IssueNumbers 101 -ProjectNumber 3 `
    -Owner "anokye-labs" -Repo "akwaaba"
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
