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

### Get-BlockedIssues.ps1

Find issues that are stuck - open but blocked by other open issues.

**Features:**
- Analyzes dependency text in issue bodies (looks for "## Dependencies" sections)
- Cross-references with issue states to identify blocking issues
- Reports what is blocking each item
- Suggests resolution order using topological sort (Kahn's algorithm)
- Multiple output formats: Text (default), Json, or Summary
- Handles both local (#123) and external (owner/repo#123) issue references

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Requires Invoke-GraphQL.ps1, Get-RepoContext.ps1, and Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Analyze blocked issues in current repository
./scripts/Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba"

# Output in JSON format
./scripts/Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputFormat Json

# Get just a summary
./scripts/Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputFormat Summary

# Include closed issues in analysis
./scripts/Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -IncludeClosed
```

**Expected Issue Format:**

Issues should include a "## Dependencies" section with "Blocked by:" list:

```markdown
## Dependencies

Blocked by:
- [ ] anokye-labs/akwaaba#14 - Invoke-GraphQL.ps1
- [ ] anokye-labs/akwaaba#15 - Get-RepoContext.ps1
- [ ] #42 - Some local issue
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
