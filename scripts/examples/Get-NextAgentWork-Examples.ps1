<#
.SYNOPSIS
    Examples of using Get-NextAgentWork.ps1

.DESCRIPTION
    This file demonstrates various ways to use Get-NextAgentWork.ps1 to find
    the next best issue for an agent to work on based on DAG traversal,
    dependency analysis, and intelligent prioritization.
#>

# Ensure we're in the correct directory
$scriptRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Get-NextAgentWork.ps1 Examples" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic usage - get the next best issue
Write-Host "Example 1: Get the next best issue under Epic #14" -ForegroundColor Yellow
Write-Host "Command: .\Get-NextAgentWork.ps1 -RootIssue 14" -ForegroundColor Gray
Write-Host ""
Write-Host "This finds the single next best issue to work on using default prioritization:" -ForegroundColor White
Write-Host "  1. Prioritizes by depth (deepest/leaf issues first)" -ForegroundColor White
Write-Host "  2. Then by label priority (critical > high > medium > low)" -ForegroundColor White
Write-Host "  3. Then by creation date (oldest first)" -ForegroundColor White
Write-Host "  4. Finally by issue number as tiebreaker" -ForegroundColor White
Write-Host ""

# Example 2: Filter by agent capability tags
Write-Host "Example 2: Get next issue for an agent with specific capabilities" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -AgentCapabilityTags @("powershell", "api")' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds the next best issue that has at least one of the specified capability tags:" -ForegroundColor White
Write-Host '  - Issues with "powershell" label' -ForegroundColor White
Write-Host '  - OR issues with "api" label' -ForegroundColor White
Write-Host "Useful for matching work to agent capabilities." -ForegroundColor White
Write-Host ""

# Example 3: Sort by depth only
Write-Host "Example 3: Prioritize strictly by depth" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -SortBy "depth"' -ForegroundColor Gray
Write-Host ""
Write-Host "This prioritizes only by depth in the hierarchy:" -ForegroundColor White
Write-Host "  - Deepest issues (leaves) are selected first" -ForegroundColor White
Write-Host "  - Ignores label priority" -ForegroundColor White
Write-Host "  - Good for completing leaf tasks systematically" -ForegroundColor White
Write-Host ""

# Example 4: Sort by label priority only
Write-Host "Example 4: Prioritize strictly by label priority" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -SortBy "labels"' -ForegroundColor Gray
Write-Host ""
Write-Host "This prioritizes only by label priority:" -ForegroundColor White
Write-Host "  - priority:critical first" -ForegroundColor White
Write-Host "  - Then priority:high" -ForegroundColor White
Write-Host "  - Then priority:medium" -ForegroundColor White
Write-Host "  - Then priority:low" -ForegroundColor White
Write-Host "  - Then issues without priority labels" -ForegroundColor White
Write-Host "  - Ignores depth in hierarchy" -ForegroundColor White
Write-Host ""

# Example 5: Sort by age (oldest first)
Write-Host "Example 5: Prioritize oldest issues" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -SortBy "oldest"' -ForegroundColor Gray
Write-Host ""
Write-Host "This prioritizes by creation date:" -ForegroundColor White
Write-Host "  - Oldest issues first" -ForegroundColor White
Write-Host "  - Helps prevent issues from languishing" -ForegroundColor White
Write-Host "  - Good for clearing backlog systematically" -ForegroundColor White
Write-Host ""

# Example 6: Console output format
Write-Host "Example 6: Display formatted console output" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -OutputFormat "Console"' -ForegroundColor Gray
Write-Host ""
Write-Host "This displays a formatted console output with:" -ForegroundColor White
Write-Host "  - Issue number and title" -ForegroundColor White
Write-Host "  - Issue type and URL" -ForegroundColor White
Write-Host "  - Depth and priority information" -ForegroundColor White
Write-Host "  - Labels and creation date" -ForegroundColor White
Write-Host "  - Color-coded priority levels" -ForegroundColor White
Write-Host ""

# Example 7: JSON output format
Write-Host "Example 7: Get result as JSON for agent consumption" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -OutputFormat "Json"' -ForegroundColor Gray
Write-Host ""
Write-Host "This returns the result as JSON string:" -ForegroundColor White
Write-Host "  - Suitable for API responses" -ForegroundColor White
Write-Host "  - Easy to parse by automated agents" -ForegroundColor White
Write-Host "  - Can be piped to files or other tools" -ForegroundColor White
Write-Host ""

# Example 8: Combined filters and options
Write-Host "Example 8: Complex filtering with multiple criteria" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -AgentCapabilityTags @("backend", "api") -SortBy "labels" -OutputFormat "Console"' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds the next best issue that:" -ForegroundColor White
Write-Host '  - Has either "backend" or "api" label' -ForegroundColor White
Write-Host "  - Is prioritized by label priority" -ForegroundColor White
Write-Host "  - Is displayed with formatted console output" -ForegroundColor White
Write-Host ""

# Example 9: Using the output in a script
Write-Host "Example 9: Working with the output in a workflow" -ForegroundColor Yellow
Write-Host 'Command:' -ForegroundColor Gray
Write-Host '  $nextIssue = .\Get-NextAgentWork.ps1 -RootIssue 14' -ForegroundColor Gray
Write-Host '  if ($nextIssue) {' -ForegroundColor Gray
Write-Host '      Write-Host "Starting work on: #$($nextIssue.Number)"' -ForegroundColor Gray
Write-Host '      # Call Start-IssueWork.ps1 or other automation here' -ForegroundColor Gray
Write-Host '      # .\Start-IssueWork.ps1 -IssueNumber $nextIssue.Number' -ForegroundColor Gray
Write-Host '  } else {' -ForegroundColor Gray
Write-Host '      Write-Host "No ready issues found!"' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host ""
Write-Host "Output properties available:" -ForegroundColor White
Write-Host "  - Number: Issue number (int)" -ForegroundColor White
Write-Host "  - Title: Issue title (string)" -ForegroundColor White
Write-Host "  - Type: Issue type name (string)" -ForegroundColor White
Write-Host "  - State: Issue state (string: OPEN)" -ForegroundColor White
Write-Host "  - Url: Issue URL (string)" -ForegroundColor White
Write-Host "  - Body: Issue body text (string)" -ForegroundColor White
Write-Host "  - Labels: Array of label names (string[])" -ForegroundColor White
Write-Host "  - Assignees: Array of assignee logins (string[])" -ForegroundColor White
Write-Host "  - Depth: Depth in hierarchy (int, 0 = root)" -ForegroundColor White
Write-Host "  - Priority: Priority score (int, 0-4)" -ForegroundColor White
Write-Host "  - CreatedAt: ISO 8601 timestamp (string)" -ForegroundColor White
Write-Host ""

# Example 10: Verbose mode for debugging
Write-Host "Example 10: Use verbose mode for debugging" -ForegroundColor Yellow
Write-Host 'Command: .\Get-NextAgentWork.ps1 -RootIssue 14 -Verbose' -ForegroundColor Gray
Write-Host ""
Write-Host "Verbose mode shows:" -ForegroundColor White
Write-Host "  - Ready issues fetched from Get-ReadyIssues.ps1" -ForegroundColor White
Write-Host "  - Capability tag filtering decisions" -ForegroundColor White
Write-Host "  - Metadata enrichment progress" -ForegroundColor White
Write-Host "  - Prioritization strategy applied" -ForegroundColor White
Write-Host ""

# Real-world workflow example
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Real-World Agent Workflow" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "A typical agent workflow might look like this:" -ForegroundColor White
Write-Host ""
Write-Host '# 1. Define agent capabilities' -ForegroundColor Gray
Write-Host '$agentTags = @("powershell", "graphql", "api")' -ForegroundColor Gray
Write-Host ""
Write-Host '# 2. Find the next best issue for this agent' -ForegroundColor Gray
Write-Host '$nextIssue = .\Get-NextAgentWork.ps1 -RootIssue 14 -AgentCapabilityTags $agentTags' -ForegroundColor Gray
Write-Host ""
Write-Host '# 3. Check if an issue was found' -ForegroundColor Gray
Write-Host 'if ($nextIssue) {' -ForegroundColor Gray
Write-Host '    Write-Host "Starting work on issue #$($nextIssue.Number): $($nextIssue.Title)"' -ForegroundColor Gray
Write-Host '    Write-Host "Priority: $($nextIssue.Priority), Depth: $($nextIssue.Depth)"' -ForegroundColor Gray
Write-Host '    ' -ForegroundColor Gray
Write-Host '    # 4. Begin work (call Start-IssueWork.ps1 when available)' -ForegroundColor Gray
Write-Host '    # .\Start-IssueWork.ps1 -IssueNumber $nextIssue.Number' -ForegroundColor Gray
Write-Host '    ' -ForegroundColor Gray
Write-Host '    # 5. Process the issue' -ForegroundColor Gray
Write-Host '    # ... agent performs work ...' -ForegroundColor Gray
Write-Host '    ' -ForegroundColor Gray
Write-Host '} else {' -ForegroundColor Gray
Write-Host '    Write-Host "No matching issues found for this agent."' -ForegroundColor Gray
Write-Host '    Write-Host "Agent capabilities: $($agentTags -join ", ")"' -ForegroundColor Gray
Write-Host '}' -ForegroundColor Gray
Write-Host ""

# Priority label usage
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Priority Label Reference" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Priority labels affect issue selection:" -ForegroundColor White
Write-Host ""
Write-Host "  priority:critical (Score: 4)" -ForegroundColor Red
Write-Host "    - Blocking production issues" -ForegroundColor White
Write-Host "    - Critical security vulnerabilities" -ForegroundColor White
Write-Host "    - Must be addressed immediately" -ForegroundColor White
Write-Host ""
Write-Host "  priority:high (Score: 3)" -ForegroundColor Yellow
Write-Host "    - Important features or bugs" -ForegroundColor White
Write-Host "    - Significant impact on users" -ForegroundColor White
Write-Host "    - Should be addressed soon" -ForegroundColor White
Write-Host ""
Write-Host "  priority:medium (Score: 2)" -ForegroundColor Cyan
Write-Host "    - Normal priority work" -ForegroundColor White
Write-Host "    - Planned features" -ForegroundColor White
Write-Host "    - Non-critical improvements" -ForegroundColor White
Write-Host ""
Write-Host "  priority:low (Score: 1)" -ForegroundColor Gray
Write-Host "    - Nice-to-have features" -ForegroundColor White
Write-Host "    - Minor improvements" -ForegroundColor White
Write-Host "    - Can be deferred" -ForegroundColor White
Write-Host ""
Write-Host "  No priority label (Score: 0)" -ForegroundColor White
Write-Host "    - Default priority" -ForegroundColor White
Write-Host "    - Addressed based on other factors" -ForegroundColor White
Write-Host ""

# Capability tag matching
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Capability Tag Matching" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Agent capability tags allow matching issues to agent skills:" -ForegroundColor White
Write-Host ""
Write-Host "Example capability tags:" -ForegroundColor White
Write-Host '  - "powershell" - Agent can work on PowerShell scripts' -ForegroundColor Gray
Write-Host '  - "typescript" - Agent can work on TypeScript code' -ForegroundColor Gray
Write-Host '  - "api" - Agent can work on API development' -ForegroundColor Gray
Write-Host '  - "frontend" - Agent can work on frontend code' -ForegroundColor Gray
Write-Host '  - "backend" - Agent can work on backend code' -ForegroundColor Gray
Write-Host '  - "documentation" - Agent can work on documentation' -ForegroundColor Gray
Write-Host '  - "testing" - Agent can work on tests' -ForegroundColor Gray
Write-Host ""
Write-Host "An issue matches if it has ANY of the agent's capability tags." -ForegroundColor White
Write-Host ""

Write-Host "For more information, see the script's comment-based help:" -ForegroundColor Cyan
Write-Host "  Get-Help .\Get-NextAgentWork.ps1 -Full" -ForegroundColor Yellow
Write-Host ""
