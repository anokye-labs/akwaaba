<#
.SYNOPSIS
    Examples of using Set-IssueAssignment.ps1

.DESCRIPTION
    This file demonstrates various ways to use Set-IssueAssignment.ps1 to
    bulk-assign issues to users or @copilot based on DAG readiness.
#>

# Ensure we're in the correct directory
$scriptRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Set-IssueAssignment.ps1 Examples" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic usage - assign all ready issues to @copilot
Write-Host "Example 1: Assign all ready issues under Epic #14 to @copilot" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot"' -ForegroundColor Gray
Write-Host ""
Write-Host "This assigns ALL ready issues under Epic #14 to @copilot" -ForegroundColor White
Write-Host "Ready issues are:" -ForegroundColor White
Write-Host "  - Leaf nodes (no children)" -ForegroundColor White
Write-Host "  - Open with open parents" -ForegroundColor White
Write-Host "  - No open blocking dependencies" -ForegroundColor White
Write-Host "  - Currently unassigned" -ForegroundColor White
Write-Host ""

# Example 2: DryRun mode - preview assignments
Write-Host "Example 2: Preview what would be assigned (DryRun mode)" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -DryRun' -ForegroundColor Gray
Write-Host ""
Write-Host "DryRun mode shows which issues would be assigned WITHOUT making changes" -ForegroundColor White
Write-Host "Use this to:" -ForegroundColor White
Write-Host "  - Preview assignments before committing" -ForegroundColor White
Write-Host "  - Verify filters are working as expected" -ForegroundColor White
Write-Host "  - Check how many issues would be affected" -ForegroundColor White
Write-Host ""

# Example 3: Limit assignments with MaxAssign
Write-Host "Example 3: Assign only 3 issues at a time" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -MaxAssign 3' -ForegroundColor Gray
Write-Host ""
Write-Host "MaxAssign limits how many issues to assign in one operation" -ForegroundColor White
Write-Host "Useful for:" -ForegroundColor White
Write-Host "  - Gradual rollout of work" -ForegroundColor White
Write-Host "  - Testing with a small batch first" -ForegroundColor White
Write-Host "  - Controlling agent workload" -ForegroundColor White
Write-Host ""

# Example 4: Assign to a specific user
Write-Host "Example 4: Assign ready issues to a specific GitHub user" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "octocat"' -ForegroundColor Gray
Write-Host ""
Write-Host "You can assign to any GitHub username, not just @copilot" -ForegroundColor White
Write-Host ""

# Example 5: Filter by labels
Write-Host "Example 5: Assign only high-priority issues" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -Labels @("priority:high")' -ForegroundColor Gray
Write-Host ""
Write-Host "Use Labels to filter which ready issues to assign" -ForegroundColor White
Write-Host "Only issues with ALL specified labels will be assigned" -ForegroundColor White
Write-Host ""

# Example 6: Filter by issue type
Write-Host "Example 6: Assign only Task issues" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -IssueType "Task"' -ForegroundColor Gray
Write-Host ""
Write-Host "Filter by issue type to assign only specific types" -ForegroundColor White
Write-Host 'Examples: "Task", "Bug", "Feature"' -ForegroundColor White
Write-Host ""

# Example 7: Combined filters with DryRun
Write-Host "Example 7: Complex filtering with preview" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -Labels @("backend") -IssueType "Task" -MaxAssign 5 -DryRun' -ForegroundColor Gray
Write-Host ""
Write-Host "Combine multiple filters for precise control:" -ForegroundColor White
Write-Host "  - Only backend Task issues" -ForegroundColor White
Write-Host "  - Limit to 5 assignments" -ForegroundColor White
Write-Host "  - Preview before executing" -ForegroundColor White
Write-Host ""

# Example 8: Sort order matters
Write-Host "Example 8: Control which issues get assigned first" -ForegroundColor Yellow
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -MaxAssign 3 -SortBy "priority"' -ForegroundColor Gray
Write-Host ""
Write-Host "SortBy controls the order when MaxAssign is used:" -ForegroundColor White
Write-Host '  - "priority" (default): Shallowest in hierarchy first, then lowest number' -ForegroundColor White
Write-Host '  - "number": Lowest issue number first' -ForegroundColor White
Write-Host '  - "title": Alphabetical by title' -ForegroundColor White
Write-Host ""

# Example 9: Workflow - Iterative assignment
Write-Host "Example 9: Iterative workflow for gradual rollout" -ForegroundColor Yellow
Write-Host ""
Write-Host "Step 1: Preview high-priority work" -ForegroundColor Cyan
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -Labels @("priority:high") -DryRun' -ForegroundColor Gray
Write-Host ""
Write-Host "Step 2: Assign first batch" -ForegroundColor Cyan
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -Labels @("priority:high") -MaxAssign 3' -ForegroundColor Gray
Write-Host ""
Write-Host "Step 3: Wait for completion, then assign more" -ForegroundColor Cyan
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -Labels @("priority:high") -MaxAssign 3' -ForegroundColor Gray
Write-Host ""
Write-Host "This workflow allows you to:" -ForegroundColor White
Write-Host "  - Start with high-priority work" -ForegroundColor White
Write-Host "  - Assign in small batches" -ForegroundColor White
Write-Host "  - Monitor progress between batches" -ForegroundColor White
Write-Host ""

# Example 10: Integration with Get-ReadyIssues.ps1
Write-Host "Example 10: Use with Get-ReadyIssues.ps1 for analysis" -ForegroundColor Yellow
Write-Host ""
Write-Host "First, analyze what's ready:" -ForegroundColor Cyan
Write-Host 'Command: $ready = .\Get-ReadyIssues.ps1 -RootIssue 14' -ForegroundColor Gray
Write-Host 'Command: $ready | Format-Table Number, Title, Type, Labels' -ForegroundColor Gray
Write-Host ""
Write-Host "Then assign based on analysis:" -ForegroundColor Cyan
Write-Host 'Command: .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -MaxAssign $ready.Count' -ForegroundColor Gray
Write-Host ""

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "For more information:" -ForegroundColor White
Write-Host '  Get-Help .\Set-IssueAssignment.ps1 -Full' -ForegroundColor Gray
Write-Host ""
