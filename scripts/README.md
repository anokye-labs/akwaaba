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

### New-IssueBatch.ps1

Create multiple GitHub issues from a JSON or CSV input file with type support and relationship wiring.

**Features:**
- Batch create issues from JSON or CSV input
- Support for all organization issue types (Epic, Feature, Task, Bug)
- Automatic parent-child relationship wiring via tasklists
- Progress bar for large batches
- DryRun mode to preview operations
- Structured logging via Write-OkyeremaLog
- Label assignment support

**Input Format:**

JSON example:
```json
[
  {
    "title": "Epic: Phase 3 Development",
    "type": "Epic",
    "body": "Description",
    "labels": ["documentation", "enhancement"],
    "parent": null
  },
  {
    "title": "Child Task",
    "type": "Task",
    "body": "Task description",
    "labels": ["bug"],
    "parent": 1
  }
]
```

CSV example:
```csv
title,type,body,labels,parent
"Epic: Phase 3 Development",Epic,"Description","documentation;enhancement",
"Child Task",Task,"Task description","bug",1
```

**Usage:**

```powershell
# Create issues from JSON file
./New-IssueBatch.ps1 -InputFile issues.json -Owner anokye-labs -Repo akwaaba

# Preview operations without creating issues
./New-IssueBatch.ps1 -InputFile issues.csv -Owner anokye-labs -Repo akwaaba -DryRun

# Create with quiet logging
./New-IssueBatch.ps1 -InputFile issues.json -Owner anokye-labs -Repo akwaaba -Quiet
```

**Notes:**
- Parent references use 1-based indexing
- Parents must be defined before children in the input file
- Relationships are wired after all issues are created
- GitHub needs 2-5 minutes to parse tasklist relationships

## Best Practices

1. **Always use Invoke-GraphQL.ps1** instead of calling `gh api graphql` directly
2. **Use New-IssueBatch.ps1** for creating multiple related issues at once
3. **Check the Success property** before using the Data
4. **Use -Verbose** for debugging and troubleshooting
5. **Use -DryRun** to test queries and operations without executing them

## Examples

See `examples/GraphQL-Examples.ps1` for more usage examples.

## Contributing

When adding new scripts to this directory:

1. Follow PowerShell best practices
2. Include comprehensive comment-based help
3. Add test scripts when applicable
4. Update this README with documentation
5. Use the `ConvertTo-Verb` naming convention for functions
