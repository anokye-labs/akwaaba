<#
.SYNOPSIS
    Examples of using Get-ReadyIssues.ps1

.DESCRIPTION
    This file demonstrates various ways to use Get-ReadyIssues.ps1 to find
    issues that are ready to work on based on DAG traversal and dependency analysis.
#>

# Ensure we're in the correct directory
$scriptRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Get-ReadyIssues.ps1 Examples" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic usage - find all ready issues under an Epic
Write-Host "Example 1: Find all ready issues under Epic #14" -ForegroundColor Yellow
Write-Host "Command: .\Get-ReadyIssues.ps1 -RootIssue 14" -ForegroundColor Gray
Write-Host ""
Write-Host "This finds all leaf tasks under Epic #14 that:" -ForegroundColor White
Write-Host "  - Have no children (are leaf nodes)" -ForegroundColor White
Write-Host "  - Are open" -ForegroundColor White
Write-Host "  - Have open parents" -ForegroundColor White
Write-Host "  - Have no open blocking dependencies" -ForegroundColor White
Write-Host "  - Are not assigned" -ForegroundColor White
Write-Host ""

# Example 2: Filter by labels
Write-Host "Example 2: Find ready issues with specific labels" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -Labels @("priority:high", "backend")' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds ready issues that have BOTH labels:" -ForegroundColor White
Write-Host '  - "priority:high"' -ForegroundColor White
Write-Host '  - "backend"' -ForegroundColor White
Write-Host ""

# Example 3: Filter by issue type
Write-Host "Example 3: Find ready Task issues only" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -IssueType "Task"' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds only ready issues of type 'Task' (excludes Bugs, Features, etc.)" -ForegroundColor White
Write-Host ""

# Example 4: Filter by assignee - find unassigned
Write-Host "Example 4: Find unassigned ready issues" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -Assignee "none"' -ForegroundColor Gray
Write-Host ""
Write-Host "This explicitly finds only unassigned issues" -ForegroundColor White
Write-Host "Note: By default, only unassigned issues are returned anyway" -ForegroundColor White
Write-Host ""

# Example 5: Filter by assignee - find assigned to specific user
Write-Host "Example 5: Find ready issues assigned to a specific user" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -Assignee "octocat"' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds ready issues assigned to user 'octocat'" -ForegroundColor White
Write-Host ""

# Example 6: Include assigned issues
Write-Host "Example 6: Include both assigned and unassigned ready issues" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -IncludeAssigned' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds ALL ready issues, regardless of assignment status" -ForegroundColor White
Write-Host ""

# Example 7: Sort by number
Write-Host "Example 7: Sort results by issue number" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -SortBy "number"' -ForegroundColor Gray
Write-Host ""
Write-Host "Sort options:" -ForegroundColor White
Write-Host '  - "priority" (default): Sort by depth in hierarchy, then by number' -ForegroundColor White
Write-Host '  - "number": Sort by issue number' -ForegroundColor White
Write-Host '  - "title": Sort alphabetically by title' -ForegroundColor White
Write-Host ""

# Example 8: Combined filters
Write-Host "Example 8: Complex filtering with multiple criteria" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -IssueType "Task" -Labels @("backend") -SortBy "title"' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds ready issues that:" -ForegroundColor White
Write-Host '  - Are of type "Task"' -ForegroundColor White
Write-Host '  - Have the "backend" label' -ForegroundColor White
Write-Host "  - Are sorted alphabetically by title" -ForegroundColor White
Write-Host ""

# Example 9: Using the output
Write-Host "Example 9: Working with the output" -ForegroundColor Yellow
Write-Host 'Command:' -ForegroundColor Gray
Write-Host '  $readyIssues = .\Get-ReadyIssues.ps1 -RootIssue 14' -ForegroundColor Gray
Write-Host '  foreach ($issue in $readyIssues) {' -ForegroundColor Gray
Write-Host '      Write-Host "Ready: #$($issue.Number) - $($issue.Title)"' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host ""
Write-Host "Output properties available:" -ForegroundColor White
Write-Host "  - Number: Issue number (int)" -ForegroundColor White
Write-Host "  - Title: Issue title (string)" -ForegroundColor White
Write-Host "  - Type: Issue type name (string)" -ForegroundColor White
Write-Host "  - State: Issue state (string: OPEN/CLOSED)" -ForegroundColor White
Write-Host "  - Url: Issue URL (string)" -ForegroundColor White
Write-Host "  - Labels: Array of label names (string[])" -ForegroundColor White
Write-Host "  - Assignees: Array of assignee logins (string[])" -ForegroundColor White
Write-Host "  - Depth: Depth in hierarchy (int, 0 = root)" -ForegroundColor White
Write-Host ""

# Example 10: Verbose mode for debugging
Write-Host "Example 10: Use verbose mode for debugging" -ForegroundColor Yellow
Write-Host 'Command: .\Get-ReadyIssues.ps1 -RootIssue 14 -Verbose' -ForegroundColor Gray
Write-Host ""
Write-Host "Verbose mode shows:" -ForegroundColor White
Write-Host "  - GraphQL query execution details" -ForegroundColor White
Write-Host "  - Issue filtering decisions (why issues are included/excluded)" -ForegroundColor White
Write-Host "  - Blocking dependency checks" -ForegroundColor White
Write-Host ""

# Real-world workflow example
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Real-World Workflow Example" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "An agent workflow might look like this:" -ForegroundColor White
Write-Host ""
Write-Host '# 1. Find ready issues' -ForegroundColor Gray
Write-Host '$ready = .\Get-ReadyIssues.ps1 -RootIssue 14 -IssueType "Task"' -ForegroundColor Gray
Write-Host ""
Write-Host '# 2. Pick the highest priority one (first in list)' -ForegroundColor Gray
Write-Host '$nextIssue = $ready | Select-Object -First 1' -ForegroundColor Gray
Write-Host ""
Write-Host '# 3. Show what we found' -ForegroundColor Gray
Write-Host 'if ($nextIssue) {' -ForegroundColor Gray
Write-Host '    Write-Host "Next task to work on:"' -ForegroundColor Gray
Write-Host '    Write-Host "  #$($nextIssue.Number): $($nextIssue.Title)"' -ForegroundColor Gray
Write-Host '    Write-Host "  URL: $($nextIssue.Url)"' -ForegroundColor Gray
Write-Host '    Write-Host "  Type: $($nextIssue.Type)"' -ForegroundColor Gray
Write-Host '    Write-Host "  Labels: $($nextIssue.Labels -join ", ")"' -ForegroundColor Gray
Write-Host '} else {' -ForegroundColor Gray
Write-Host '    Write-Host "No ready issues found!"' -ForegroundColor Gray
Write-Host '}' -ForegroundColor Gray
Write-Host ""

Write-Host "For more information, see the script's comment-based help:" -ForegroundColor Cyan
Write-Host "  Get-Help .\Get-ReadyIssues.ps1 -Full" -ForegroundColor Yellow
Write-Host ""
