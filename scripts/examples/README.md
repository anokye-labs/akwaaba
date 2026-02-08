# DAG Import Examples

This directory contains example files and scripts demonstrating the usage of various PowerShell automation scripts.

## Script Examples

### Get-PRReviewTimeline-Examples.ps1

Examples demonstrating how to use `Get-PRReviewTimeline.ps1` for analyzing PR review timelines.

**Includes examples for:**
- Basic console output with colored timeline
- Markdown table output for documentation
- JSON output for programmatic processing
- Including detailed review comments
- DryRun mode for testing
- Custom correlation IDs for tracing
- Batch analysis of multiple PRs
- Verbose logging for debugging
- Saving output to files
- Processing the returned object

**Usage:**
```powershell
# View all examples
./scripts/examples/Get-PRReviewTimeline-Examples.ps1

# Get detailed help
Get-Help ./scripts/Get-PRReviewTimeline.ps1 -Full
```

### GraphQL-Examples.ps1

Examples demonstrating how to use `Invoke-GraphQL.ps1` for making GraphQL queries.

### New-IssueHierarchy-Examples.ps1

Examples demonstrating how to use `New-IssueHierarchy.ps1` for creating issue hierarchies.

## DAG JSON Files

### sample-dag.json

A simple three-level hierarchy demonstrating Epic → Feature → Task relationships.

**Structure:**
- 1 Epic: "Build API Integration Layer"
- 2 Features: "Authentication Module", "Rate Limiting"
- 4 Tasks: Split between the two features

**Usage:**
```powershell
# Validate the DAG
./Import-DagFromJson.ps1 -JsonPath examples/sample-dag.json -DryRun

# Create issues (requires GitHub authentication)
./Import-DagFromJson.ps1 -JsonPath examples/sample-dag.json
```

### complex-dag.json

A more complex three-level hierarchy with multiple branches.

**Structure:**
- 1 Epic: "Database Migration to PostgreSQL"
- 3 Features: Schema, Data Pipeline, Validation
- 8 Tasks: Distributed across the three features

**Demonstrates:**
- Multiple features under one epic
- Balanced distribution of tasks
- Rich issue descriptions with markdown formatting

**Usage:**
```powershell
# Validate and see execution plan
./Import-DagFromJson.ps1 -JsonPath examples/complex-dag.json -DryRun
```

## JSON Format Specification

```json
{
  "nodes": [
    {
      "id": "unique-id",           // Required: Unique identifier within the DAG
      "title": "Issue Title",      // Required: GitHub issue title
      "type": "Epic|Feature|Task", // Required: Issue type (must exist in organization)
      "body": "Description"        // Optional: Issue description (supports markdown)
    }
  ],
  "edges": [
    {
      "from": "parent-id",         // Required: Parent node ID
      "to": "child-id",            // Required: Child node ID
      "relationship": "tracks"     // Optional: Relationship type (currently unused)
    }
  ]
}
```

## DAG Requirements

1. **Acyclic**: The graph must not contain any cycles
2. **Unique IDs**: All node IDs must be unique within the DAG
3. **Valid References**: All edges must reference existing nodes
4. **Valid Types**: Issue types must exist in the GitHub organization

## Tips

- Start with `DryRun` mode to validate your DAG before creating issues
- Use descriptive node IDs that indicate the hierarchy level (e.g., `epic-1`, `feature-1-1`, `task-1-1-1`)
- Include markdown formatting in the body field for better issue descriptions
- The script creates issues in topological order, so dependencies are always created before their parents
- Wait 2-5 minutes after creation for GitHub to parse tasklist relationships

## Creating Your Own DAG

1. Start with your Epic(s) at the top level
2. Add Feature nodes that the Epic tracks
3. Add Task nodes that each Feature tracks
4. Define edges from parent to child (Epic → Feature → Task)
5. Validate with `-DryRun` to see the execution plan
6. Run without `-DryRun` to create the issues

Example minimal DAG:
```json
{
  "nodes": [
    {"id": "e1", "title": "My Epic", "type": "Epic", "body": "Epic description"},
    {"id": "f1", "title": "My Feature", "type": "Feature", "body": "Feature description"}
  ],
  "edges": [
    {"from": "e1", "to": "f1", "relationship": "tracks"}
  ]
}
```
