# Get-DagStatus.ps1 Examples

This document provides examples of using Get-DagStatus.ps1 to track issue hierarchies.

## Basic Usage

### Tree Output (Default)

```powershell
./scripts/Get-DagStatus.ps1 -IssueNumber 14
```

Example output:
```
DAG Status for #14
Legend: ✓ = Closed, ○ = Open, [BLOCKED] = Open with all children done, [READY] = Open leaf with no dependencies

└── ○ #14 - Create Okyerema Skill Framework (3/5, 60.0%)
    ├── ✓ #15 - Get-RepoContext.ps1
    ├── ✓ #16 - Invoke-GraphQL.ps1
    ├── ✓ #17 - Write-OkyeremaLog.ps1
    ├── ○ #18 - Get-DagStatus.ps1 [BLOCKED]
    └── ○ #19 - Create-IssueHierarchy.ps1 [READY]
```

### JSON Output

```powershell
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format JSON
```

Example output:
```json
{
  "Number": 14,
  "Title": "Create Okyerema Skill Framework",
  "State": "OPEN",
  "Closed": false,
  "IssueType": "Epic",
  "Children": [
    {
      "Number": 15,
      "Title": "Get-RepoContext.ps1",
      "State": "CLOSED",
      "Closed": true,
      "IssueType": "Task",
      "Children": [],
      "ParentCount": 1,
      "TotalChildren": 0,
      "ClosedChildren": 0,
      "PercentComplete": 100,
      "IsBlocked": false,
      "IsReady": false,
      "Depth": 1
    }
  ],
  "ParentCount": 0,
  "TotalChildren": 5,
  "ClosedChildren": 3,
  "PercentComplete": 60.0,
  "IsBlocked": false,
  "IsReady": false,
  "Depth": 0
}
```

### CSV Output

```powershell
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format CSV > status.csv
```

Example output:
```csv
Number,Title,State,IssueType,Depth,TotalChildren,ClosedChildren,PercentComplete,IsBlocked,IsReady,Path
14,Create Okyerema Skill Framework,OPEN,Epic,0,5,3,60.0,False,False,#14
15,Get-RepoContext.ps1,CLOSED,Task,1,0,0,100,False,False,#14 > #15
16,Invoke-GraphQL.ps1,CLOSED,Task,1,0,0,100,False,False,#14 > #16
17,Write-OkyeremaLog.ps1,CLOSED,Task,1,0,0,100,False,False,#14 > #17
18,Get-DagStatus.ps1,OPEN,Task,1,0,0,0,True,False,#14 > #18
19,Create-IssueHierarchy.ps1,OPEN,Task,1,0,0,0,False,True,#14 > #19
```

## Advanced Usage

### Limiting Depth

Limit the hierarchy traversal to a specific depth:

```powershell
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -MaxDepth 2
```

This will only traverse 2 levels deep from the root issue.

### Using Correlation IDs

For tracing and debugging, provide a correlation ID:

```powershell
$correlationId = [guid]::NewGuid().ToString()
./scripts/Get-DagStatus.ps1 -IssueNumber 14 -CorrelationId $correlationId -Verbose
```

The correlation ID will appear in all structured log messages written to stderr, making it easy to trace the execution.

## Understanding the Output

### Metrics

- **Total/Closed Count**: Shows how many direct children exist and how many are closed
  - Example: `(3/5)` means 3 out of 5 children are closed
- **Percentage Complete**: Calculated as (ClosedChildren / TotalChildren) × 100
  - Example: `60.0%` means 60% of direct children are closed

### Status Indicators

- **✓ (Checkmark)**: Issue is closed
- **○ (Circle)**: Issue is open
- **[BLOCKED]**: Issue is open but all its children are done (ready to close)
- **[READY]**: Issue is open with no children and no blocking dependencies (ready to work on)

### Blocked Items

An issue is marked as "blocked" when:
1. The issue state is OPEN
2. All of its children are CLOSED
3. It has at least one child

This typically means the issue is waiting for someone to review the completed work and close it.

### Ready Items

An issue is marked as "ready" when:
1. The issue state is OPEN
2. It has no children (leaf node)
3. No other issues are blocking it

This typically means the issue is ready to be worked on.

## Use Cases

### Sprint Planning

Use the CSV output to create reports in Excel or Google Sheets:

```powershell
./scripts/Get-DagStatus.ps1 -IssueNumber 100 -Format CSV | Out-File sprint-status.csv
```

### Finding Work

Find ready-to-work items by filtering the CSV output:

```powershell
$data = ./scripts/Get-DagStatus.ps1 -IssueNumber 100 -Format CSV | ConvertFrom-Csv
$ready = $data | Where-Object { $_.IsReady -eq "True" }
$ready | Format-Table Number, Title
```

### Tracking Epic Progress

Get a visual overview of epic progress:

```powershell
./scripts/Get-DagStatus.ps1 -IssueNumber 14
```

### CI/CD Integration

Use JSON output in automated pipelines:

```powershell
$status = ./scripts/Get-DagStatus.ps1 -IssueNumber 100 -Format JSON | ConvertFrom-Json

# Check completion threshold
$completionThreshold = 80
if ($status.PercentComplete -lt $completionThreshold) {
    Write-Warning "Epic is less than $completionThreshold% complete"
}

# Find blocked items using functional approach
function Find-Blocked($node) {
    # Return this node if blocked
    if ($node.IsBlocked) { $node }
    # Recursively check all children
    $node.Children | ForEach-Object { Find-Blocked $_ }
}

$blocked = @(Find-Blocked $status)

if ($blocked.Count -gt 0) {
    Write-Warning "Found $($blocked.Count) blocked items that need attention"
}
```

## Troubleshooting

### Script Fails to Find Issues

Ensure:
1. GitHub CLI (`gh`) is installed and authenticated
2. You have access to the repository
3. The issue number exists

### Slow Performance

For large hierarchies:
1. Use `-MaxDepth` to limit traversal
2. Use `-Format JSON` or `-Format CSV` for better performance (no formatting overhead)

### Circular Dependencies

The script automatically detects circular dependencies and logs warnings to stderr. These warnings won't affect the output but will be visible in the structured logs.

## Integration with Other Tools

### Okyerema Skill

This script is a key component of the Okyerema orchestration skill. It provides the foundation for understanding issue hierarchies and making intelligent decisions about project status.

### PowerShell Pipeline

All outputs can be piped to other PowerShell commands:

```powershell
# Count open issues using functional approach
$json = ./scripts/Get-DagStatus.ps1 -IssueNumber 14 -Format JSON | ConvertFrom-Json

function Count-Open($node) {
    # Count this node if open
    $count = if ($node.State -eq "OPEN") { 1 } else { 0 }
    # Add counts from all children
    $childCounts = $node.Children | ForEach-Object { Count-Open $_ }
    $count + ($childCounts | Measure-Object -Sum).Sum
}

$openCount = Count-Open $json
Write-Host "Total open issues: $openCount"
```
