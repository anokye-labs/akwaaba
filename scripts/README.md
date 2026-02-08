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

### Get-ReadyIssues.ps1

Finds issues that are ready to work on - all dependencies met, not assigned.

**Features:**
- Walks the DAG (Directed Acyclic Graph) from a root Epic
- Filters to leaf tasks where parent is open and no blocking issues are open
- Optionally filters by label, type, or assignee
- Returns sorted list suitable for agent consumption
- Supports multiple sort orders (priority, number, title)

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Requires: `Invoke-GraphQL.ps1`, `Get-RepoContext.ps1`, `Write-OkyeremaLog.ps1`

**Usage:**

```powershell
# Find all ready issues under Epic #14
$readyIssues = ./scripts/Get-ReadyIssues.ps1 -RootIssue 14

# Find ready issues with specific labels
$readyIssues = ./scripts/Get-ReadyIssues.ps1 -RootIssue 14 -Labels @("priority:high", "backend")

# Find unassigned Task issues
$readyIssues = ./scripts/Get-ReadyIssues.ps1 -RootIssue 14 -IssueType "Task" -Assignee "none"

# Include assigned issues in results
$readyIssues = ./scripts/Get-ReadyIssues.ps1 -RootIssue 14 -IncludeAssigned

# Sort by number instead of priority
$readyIssues = ./scripts/Get-ReadyIssues.ps1 -RootIssue 14 -SortBy "number"
```

**Output:**

Returns an array of PSCustomObject with properties:
- `Number`: Issue number
- `Title`: Issue title
- `Type`: Issue type name
- `State`: Issue state (OPEN/CLOSED)
- `Url`: Issue URL
- `Labels`: Array of label names
- `Assignees`: Array of assignee logins
- `Depth`: Depth in the hierarchy (0 = root)

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
