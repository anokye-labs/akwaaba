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

### Import-DagFromJson.ps1

Create issue graph from a JSON DAG (Directed Acyclic Graph) definition.

**Features:**
- Parses and validates JSON DAG input
- Performs topological sort to determine creation order
- Creates issues in dependency order
- Builds tasklist relationships automatically
- DryRun mode for validation without execution
- Structured logging via Write-OkyeremaLog

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- ConvertTo-EscapedGraphQL.ps1
- Write-OkyeremaLog.ps1

**Input Format:**

```json
{
  "nodes": [
    {
      "id": "epic-1",
      "title": "Epic Issue Title",
      "type": "Epic",
      "body": "Issue description"
    }
  ],
  "edges": [
    {
      "from": "epic-1",
      "to": "feature-1",
      "relationship": "tracks"
    }
  ]
}
```

**Usage:**

```powershell
# Create issues from JSON file
./scripts/Import-DagFromJson.ps1 -JsonPath "dag.json"

# Validate without creating issues
./scripts/Import-DagFromJson.ps1 -JsonPath "dag.json" -DryRun

# Use JSON string directly
$json = '{"nodes":[{"id":"epic-1","title":"My Epic","type":"Epic","body":"Description"}],"edges":[]}'
./scripts/Import-DagFromJson.ps1 -JsonString $json
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

### New-IssueHierarchy.ps1

Create a complete Epic → Feature → Task tree in one call.

**Features:**
- Creates issues in correct order (leaves first, root last)
- Automatically wires up tasklist relationships between parent and child issues
- Optionally adds all issues to a project board
- Returns structured result with issue numbers and URLs
- DryRun mode for testing without creating issues
- Full support for correlation IDs and structured logging

**Usage:**

```powershell
# Simple Epic with direct Tasks
$hierarchy = @{
    Type = "Epic"
    Title = "Phase 0: Project Setup"
    Body = "Initial project setup"
    Children = @(
        @{ Type = "Task"; Title = "Initialize repository" }
        @{ Type = "Task"; Title = "Setup CI/CD" }
    )
}

$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $hierarchy

# Epic → Feature → Task hierarchy with project board
$hierarchy = @{
    Type = "Epic"
    Title = "Phase 2: Core Features"
    Children = @(
        @{
            Type = "Feature"
            Title = "User Authentication"
            Children = @(
                @{ Type = "Task"; Title = "Implement login" }
                @{ Type = "Task"; Title = "Add OAuth" }
            )
        }
    )
}

$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $hierarchy `
    -ProjectNumber 3

# Check result
if ($result.Success) {
    Write-Host "Created Epic #$($result.Root.Number)"
    Write-Host "Total issues: $($result.AllIssues.Count)"
}
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
```

**Note:** GitHub has no native dependency tracking, so this uses body-text convention.

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
