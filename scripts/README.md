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

### Get-DagStatus.ps1

Recursively walks an issue hierarchy and reports status with metrics at each level.

**Features:**
- Tree display with metrics (total, closed count, percentage complete)
- Identifies blocked items (open with all children done)
- Identifies ready items (open with no open dependencies)
- Multiple output formats: Tree (default), JSON, CSV
- Cycle detection for circular dependencies
- Configurable maximum depth
- Structured logging via Write-OkyeremaLog.ps1

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Display tree view (default)
./scripts/Get-DagStatus.ps1 -IssueNumber 14

# Output as JSON
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format JSON

# Export to CSV
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format CSV > status.csv

# Limit depth
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -MaxDepth 2
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

### Start-IssueWork.ps1

Agent workflow to pick up an issue and begin work.

**Features:**
- Assigns the current user to the issue
- Creates a feature branch from main (pattern: `issue-{number}-{slug}`)
- Sets issue status to "In Progress" in the project board
- Logs all actions with structured logging
- Returns a context object for the work session

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Git configured and repository initialized
- Requires: `Invoke-GraphQL.ps1`, `Write-OkyeremaLog.ps1`

**Usage:**

```powershell
# Start work on issue #42 with default settings
$workContext = ./scripts/Start-IssueWork.ps1 -IssueNumber 42

# Start work and update status in a specific project
$workContext = ./scripts/Start-IssueWork.ps1 -IssueNumber 42 -ProjectNumber 3

# Start work without creating a new branch
$workContext = ./scripts/Start-IssueWork.ps1 -IssueNumber 42 -SkipBranch

# Start work without assigning the issue
$workContext = ./scripts/Start-IssueWork.ps1 -IssueNumber 42 -SkipAssignment

# Start work without updating project status
$workContext = ./scripts/Start-IssueWork.ps1 -IssueNumber 42 -SkipStatusUpdate

# Custom status field and value
$workContext = ./scripts/Start-IssueWork.ps1 -IssueNumber 42 -StatusFieldName "Workflow" -InProgressValue "Active"
```

**Output:**

Returns a PSCustomObject with properties:
- `Success`: Boolean indicating if the operation succeeded
- `IssueNumber`: The issue number
- `IssueTitle`: The issue title
- `IssueUrl`: The issue URL
- `AssignedTo`: The user assigned to the issue
- `Branch`: The created branch name (if created)
- `Status`: The new status (if updated)
- `CorrelationId`: The correlation ID for this session
- `StartTime`: UTC timestamp when work started

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

### Get-OrphanedIssues.ps1

Find open issues not connected to any Epic/Feature hierarchy.

**Features:**
- Queries all open issues in the repository
- Filters to issues with no parent (trackedInIssues.totalCount == 0)
- Excludes Epics (they are roots, not orphans)
- Suggests potential parent Epic/Feature based on title similarity
- Provides formatted console output with visual hierarchy
- Returns structured data for pipeline use

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Depends on: Invoke-GraphQL.ps1, Get-RepoContext.ps1, Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Find all orphaned issues
./scripts/Get-OrphanedIssues.ps1

# Test mode - show query without executing
./scripts/Get-OrphanedIssues.ps1 -DryRun

# Use in pipeline
$orphans = ./scripts/Get-OrphanedIssues.ps1
$orphans | Where-Object { # PowerShell Scripts

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

### Get-DagStatus.ps1

Recursively walks an issue hierarchy and reports status with metrics at each level.

**Features:**
- Tree display with metrics (total, closed count, percentage complete)
- Identifies blocked items (open with all children done)
- Identifies ready items (open with no open dependencies)
- Multiple output formats: Tree (default), JSON, CSV
- Cycle detection for circular dependencies
- Configurable maximum depth
- Structured logging via Write-OkyeremaLog.ps1

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Display tree view (default)
./scripts/Get-DagStatus.ps1 -IssueNumber 14

# Output as JSON
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format JSON

# Export to CSV
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format CSV > status.csv

# Limit depth
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -MaxDepth 2
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

### Get-PRStatus.ps1

Comprehensive PR status check with merge, review, issues, threads, and time metrics.

**Features:**
- Merge status (mergeable, conflicts, CI checks passing)
- Review status (approved, changes requested, pending)
- Linked issues and their states
- Comment thread summary (resolved vs unresolved)
- Time-in-state metrics (time in draft, time since created, time since last update)
- Multiple output formats (Console, Markdown, Json)
- DryRun mode for query validation
- Automatic repository detection from current context

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Check status of PR #42 with console output
./scripts/Get-PRStatus.ps1 -PRNumber 42

# Generate markdown report
./scripts/Get-PRStatus.ps1 -PRNumber 42 -OutputFormat Markdown

# Get JSON output for scripting
./scripts/Get-PRStatus.ps1 -PRNumber 42 -OutputFormat Json | ConvertFrom-Json

# Specify repository explicitly
./scripts/Get-PRStatus.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba

# Test query without execution
./scripts/Get-PRStatus.ps1 -PRNumber 42 -DryRun
```

**Output Sections:**
- **Merge Status**: State, mergeable, CI checks with individual check details
- **Review Status**: Decision, approval counts, pending reviewers
- **Linked Issues**: Issues that will be closed by the PR
- **Comment Threads**: Total, resolved, unresolved, and outdated counts
- **Time Metrics**: Age, time since update, time in draft vs ready

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

Create a complete Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task tree in one call.

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

# Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task hierarchy with project board
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

### Get-PRsByIssue.ps1

Find all PRs linked to specific issue(s).

**Features:**
- Searches for PRs by issue reference in body/title (e.g., "fixes #123")
- Checks branch naming convention (issue-{number}-*)
- Returns PR numbers, states, and review status
- Supports multiple output formats: Console (colored), Markdown (table), JSON
- DryRun mode for testing queries

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Find PRs for a single issue
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14

# Find PRs for multiple issues with Markdown output
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14,15,17 -OutputFormat Markdown

# JSON output for automation
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14 -OutputFormat Json

# DryRun mode to see queries
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14 -DryRun
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

Create a complete Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task tree in one call.

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

# Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task hierarchy with project board
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

### Get-PRReviewTimeline.ps1

Timeline view of PR review activity showing when reviews were requested, submitted, and comments posted/resolved.

**Features:**
- Shows chronological timeline of all PR review events
- Tracks review requests, submissions, comments, and resolutions
- Calculates cycle times (time to first review, time to approval, time to merge)
- Identifies bottlenecks (longest wait periods between events)
- Multiple output formats: Console (colored), Markdown (tables), JSON (structured)
- Optional inclusion of detailed comment information
- DryRun mode for testing queries

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Console output with colors
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

# Markdown table format
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Markdown

# JSON for programmatic processing
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json

# Include detailed comments
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeComments

# Test the query without execution
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun
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

Create a complete Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task tree in one call.

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

# Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task hierarchy with project board
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
.IssueType -eq "Task" }
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

### Get-PRStatus.ps1

Comprehensive PR status check with merge, review, issues, threads, and time metrics.

**Features:**
- Merge status (mergeable, conflicts, CI checks passing)
- Review status (approved, changes requested, pending)
- Linked issues and their states
- Comment thread summary (resolved vs unresolved)
- Time-in-state metrics (time in draft, time since created, time since last update)
- Multiple output formats (Console, Markdown, Json)
- DryRun mode for query validation
- Automatic repository detection from current context

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Check status of PR #42 with console output
./scripts/Get-PRStatus.ps1 -PRNumber 42

# Generate markdown report
./scripts/Get-PRStatus.ps1 -PRNumber 42 -OutputFormat Markdown

# Get JSON output for scripting
./scripts/Get-PRStatus.ps1 -PRNumber 42 -OutputFormat Json | ConvertFrom-Json

# Specify repository explicitly
./scripts/Get-PRStatus.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba

# Test query without execution
./scripts/Get-PRStatus.ps1 -PRNumber 42 -DryRun
```

**Output Sections:**
- **Merge Status**: State, mergeable, CI checks with individual check details
- **Review Status**: Decision, approval counts, pending reviewers
- **Linked Issues**: Issues that will be closed by the PR
- **Comment Threads**: Total, resolved, unresolved, and outdated counts
- **Time Metrics**: Age, time since update, time in draft vs ready

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

Create a complete Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task tree in one call.

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

# Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task hierarchy with project board
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

### Get-PRsByIssue.ps1

Find all PRs linked to specific issue(s).

**Features:**
- Searches for PRs by issue reference in body/title (e.g., "fixes #123")
- Checks branch naming convention (issue-{number}-*)
- Returns PR numbers, states, and review status
- Supports multiple output formats: Console (colored), Markdown (table), JSON
- DryRun mode for testing queries

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Find PRs for a single issue
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14

# Find PRs for multiple issues with Markdown output
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14,15,17 -OutputFormat Markdown

# JSON output for automation
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14 -OutputFormat Json

# DryRun mode to see queries
./scripts/Get-PRsByIssue.ps1 -IssueNumbers 14 -DryRun
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

Create a complete Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task tree in one call.

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

# Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task hierarchy with project board
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

### Get-PRReviewTimeline.ps1

Timeline view of PR review activity showing when reviews were requested, submitted, and comments posted/resolved.

**Features:**
- Shows chronological timeline of all PR review events
- Tracks review requests, submissions, comments, and resolutions
- Calculates cycle times (time to first review, time to approval, time to merge)
- Identifies bottlenecks (longest wait periods between events)
- Multiple output formats: Console (colored), Markdown (tables), JSON (structured)
- Optional inclusion of detailed comment information
- DryRun mode for testing queries

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Usage:**

```powershell
# Console output with colors
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

# Markdown table format
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Markdown

# JSON for programmatic processing
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json

# Include detailed comments
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeComments

# Test the query without execution
./scripts/Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun
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

Create a complete Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task tree in one call.

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

# Epic ╬ô├Ñ├å Feature ╬ô├Ñ├å Task hierarchy with project board
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

## Invoke-SystemHealthCheck.ps1

Validate that the Okyerema system's docs, scripts, and assumptions match current GitHub API reality.

**Features:**
- Detects deprecated API references (trackedIssues vs subIssues)
- Verifies all scripts referenced in SKILL.md actually exist
- Checks for deprecated patterns in documentation (tasklists for relationships)
- Validates hierarchy integrity (parent relationships)
- Detects structural labels being used incorrectly
- Returns structured check results (Pass/Warn/Fail)

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated (for hierarchy and label checks)
- Invoke-GraphQL.ps1
- Get-RepoContext.ps1
- Write-OkyeremaLog.ps1

**Background:**
The entire Okyerema skill was built on the retired tasklist API for 10 months with no detection. This script catches this kind of drift by validating that documentation, scripts, and API usage align with current GitHub API reality. See ADR-0001 for context on the tasklist-to-subissues migration.

**Checks Performed:**
1. **API Compatibility**: Verify GraphQL queries in reference docs still work (trackedIssues vs subIssues)
2. **Script Dependencies**: Verify all scripts referenced in SKILL.md actually exist
3. **Doc Freshness**: Check if reference docs mention deprecated patterns
4. **Hierarchy Integrity**: Verify all issues under an Epic have proper parent relationships
5. **Label Consistency**: Verify no labels are being used for structure (epic, task, etc.)

**Usage:**

```powershell
# Run all system health checks
./scripts/Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba"

# Run with verbose logging
./scripts/Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba" -Verbose

# Run with custom skill path
./scripts/Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba" -SkillPath ".github/skills/okyerema"

# Capture results for programmatic use
$results = ./scripts/Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba"
$failedChecks = $results | Where-Object { $_.Status -eq "Fail" }
```

**Output:**

Returns an array of PSCustomObject with:
- `CheckName`: Name of the check performed
- `Status`: Pass, Warn, or Fail
- `Details`: Description of findings

**Example Output:**

```
╔════════════════════════════════════════════════════════════════════════════╗
║                      SYSTEM HEALTH CHECK REPORT                           ║
╚════════════════════════════════════════════════════════════════════════════╝

Repository: anokye-labs/akwaaba
Skill Path: .github/skills/okyerema

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠ API Compatibility: Warn

File 'relationships.md' references deprecated 'trackedIssues' API. ADR-0001 mandates using 'subIssues' and 'parent' fields instead.
SKILL.md mentions tasklists for relationships. ADR-0001 mandates using createIssueRelationship mutation instead.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Script Dependencies: Pass

All 4 scripts referenced in SKILL.md exist.
```

### Validate-CommitAuthors.ps1

Validates that all commits in a pull request are from approved agents listed in the allowlist.

**Features:**
- Fetches all commits in a specified PR
- Extracts author and committer information
- Detects GitHub Apps and bots by username patterns
- Validates against approved agents allowlist (`.github/approved-agents.json`)
- Handles special cases like GitHub web UI commits
- Supports multiple output formats: Console (default), Markdown, Json
- DryRun mode for testing without validation
- Structured logging with correlation IDs

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated
- `.github/approved-agents.json` allowlist file

**Usage:**

```powershell
# Validate commits in PR #42
./scripts/Validate-CommitAuthors.ps1 -PRNumber 42

# With explicit owner and repo
./scripts/Validate-CommitAuthors.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba

# Output as JSON
./scripts/Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Json

# Output as Markdown report
./scripts/Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Markdown

# DryRun mode (test without validation)
./scripts/Validate-CommitAuthors.ps1 -PRNumber 42 -DryRun

# Custom allowlist path
./scripts/Validate-CommitAuthors.ps1 -PRNumber 42 -AllowlistPath /path/to/agents.json
```

**Output:**

Returns a PSCustomObject with:
- `Valid`: Boolean indicating if all commits are from approved agents
- `TotalCommits`: Total number of commits checked
- `ValidCommits`: Number of valid commits
- `InvalidCommits`: Array of commits that failed validation
- `ApprovedAgents`: Array of enabled agents from the allowlist
- `ValidationDetails`: Detailed information about each commit

**Approved Agents Format:**

The `.github/approved-agents.json` file should contain:

```json
{
  "agents": [
    {
      "id": "github-copilot",
      "username": "copilot",
      "botUsername": "github-actions[bot]",
      "githubAppId": 15368,
      "type": "GitHubApp",
      "description": "GitHub Copilot coding agent",
      "approvedBy": "system",
      "approvedDate": "2026-02-09",
      "permissions": ["code_changes"],
      "enabled": true
    }
  ]
}
```

**Testing:**

```powershell
# Run test suite
./scripts/Test-Validate-CommitAuthors.ps1
```
