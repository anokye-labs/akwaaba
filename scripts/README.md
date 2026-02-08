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

### Set-IssueDependency.ps1

Express blocking/dependency relationships between GitHub issues through body-text convention.

**Features:**
- Updates issue body with Dependencies section
- Cross-references both directions (blocks/blocked-by)
- Supports Wave indicators for work start timing
- DryRun mode for testing changes
- Automatic title fetching for referenced issues

**Usage:**

```powershell
# Set issue #20 to depend on issues #14, #16, and #17
./Set-IssueDependency.ps1 -IssueNumber 20 -DependsOn @(14, 16, 17) -Wave 1

# Set issue #14 to block issue #20
./Set-IssueDependency.ps1 -IssueNumber 14 -Blocks @(20)

# Test changes without executing
./Set-IssueDependency.ps1 -IssueNumber 20 -DependsOn @(14, 16, 17) -DryRun

# Using full issue references
./Set-IssueDependency.ps1 -IssueNumber 20 -DependsOn @("anokye-labs/akwaaba#14", "anokye-labs/akwaaba#16")
```

**Note:** GitHub has no native dependency tracking, so this uses body-text convention documented in `how-we-work/our-way.md`.

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
