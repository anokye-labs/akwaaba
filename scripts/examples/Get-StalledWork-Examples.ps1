<#
.SYNOPSIS
    Examples of using Get-StalledWork.ps1

.DESCRIPTION
    This file demonstrates various ways to use Get-StalledWork.ps1 to detect
    stalled agent work - PRs or issues that have been assigned but show no activity
    beyond a configurable threshold.
#>

# Ensure we're in the correct directory
$scriptRoot = Split-Path -Parent $PSScriptRoot

Write-Host "Get-StalledWork.ps1 Examples" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic usage - detect all stalled work with default 24-hour threshold
Write-Host "Example 1: Find all stalled work with default threshold (24 hours)" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba"' -ForegroundColor Gray
Write-Host ""
Write-Host "This finds all stalled PRs and issues with:" -ForegroundColor White
Write-Host "  - No commits or comments in the last 24 hours" -ForegroundColor White
Write-Host "  - Assigned to someone" -ForegroundColor White
Write-Host "  - Still open/draft" -ForegroundColor White
Write-Host ""
Write-Host "Output includes:" -ForegroundColor White
Write-Host "  - Number: PR or Issue number" -ForegroundColor White
Write-Host "  - Title: PR or Issue title" -ForegroundColor White
Write-Host "  - Type: 'PR' or 'Issue'" -ForegroundColor White
Write-Host "  - Assignee: Current assignee login" -ForegroundColor White
Write-Host "  - LastActivityDate: Date of last activity (ISO 8601)" -ForegroundColor White
Write-Host "  - HoursSinceActivity: Hours since last activity" -ForegroundColor White
Write-Host "  - Status: Draft/Open/InProgress" -ForegroundColor White
Write-Host ""

# Example 2: Detect stalled work with custom threshold
Write-Host "Example 2: Find stalled work with 48-hour threshold" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -StalledThresholdHours 48' -ForegroundColor Gray
Write-Host ""
Write-Host "Use this to detect work that has been stalled for longer periods" -ForegroundColor White
Write-Host "Useful for identifying seriously stuck work that may need escalation" -ForegroundColor White
Write-Host ""

# Example 3: Detect only stalled PRs
Write-Host "Example 3: Find only stalled PRs" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -IncludePRs -IncludeIssues:$false' -ForegroundColor Gray
Write-Host ""
Write-Host "This focuses only on pull requests:" -ForegroundColor White
Write-Host "  - Draft PRs with no commits or updates" -ForegroundColor White
Write-Host "  - Open PRs awaiting review with no activity" -ForegroundColor White
Write-Host ""
Write-Host "Typical use case: Detect Copilot SWE agent PRs that sat in draft for 2+ days" -ForegroundColor White
Write-Host ""

# Example 4: Detect only stalled issues
Write-Host "Example 4: Find only stalled issues" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -IncludePRs:$false -IncludeIssues' -ForegroundColor Gray
Write-Host ""
Write-Host "This focuses only on issues:" -ForegroundColor White
Write-Host "  - Assigned issues with no linked PR" -ForegroundColor White
Write-Host "  - No comments or updates beyond threshold" -ForegroundColor White
Write-Host ""
Write-Host "Note: Issues with open linked PRs are tracked via PR detection" -ForegroundColor White
Write-Host ""

# Example 5: Short threshold for quick checks
Write-Host "Example 5: Find work stalled for 12 hours (short threshold)" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -StalledThresholdHours 12' -ForegroundColor Gray
Write-Host ""
Write-Host "Use this for more aggressive monitoring:" -ForegroundColor White
Write-Host "  - Detect work that may need a quick check-in" -ForegroundColor White
Write-Host "  - Good for fast-paced sprints" -ForegroundColor White
Write-Host ""

# Example 6: Long threshold for major blockers
Write-Host "Example 6: Find work stalled for 72+ hours (major blockers)" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -StalledThresholdHours 72' -ForegroundColor Gray
Write-Host ""
Write-Host "Use this to identify critical blockers:" -ForegroundColor White
Write-Host "  - Work that has been completely stuck for 3+ days" -ForegroundColor White
Write-Host "  - May need reassignment or intervention" -ForegroundColor White
Write-Host ""

# Example 7: Processing output in a pipeline
Write-Host "Example 7: Process stalled work in a pipeline" -ForegroundColor Yellow
Write-Host 'Command: $stalledWork = .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba"' -ForegroundColor Gray
Write-Host 'Then: $stalledWork | Where-Object { $_.HoursSinceActivity -gt 48 } | Format-Table' -ForegroundColor Gray
Write-Host ""
Write-Host "Output is structured for pipeline consumption:" -ForegroundColor White
Write-Host '  $stalledWork | Where-Object { $_.Type -eq "PR" }' -ForegroundColor DarkGray
Write-Host '  $stalledWork | Sort-Object HoursSinceActivity -Descending' -ForegroundColor DarkGray
Write-Host '  $stalledWork | Export-Csv "stalled-work.csv"' -ForegroundColor DarkGray
Write-Host ""

# Example 8: Filtering and reporting
Write-Host "Example 8: Generate a report of critical stalled PRs" -ForegroundColor Yellow
Write-Host 'Command:' -ForegroundColor Gray
Write-Host '  $work = .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -IncludePRs -IncludeIssues:$false' -ForegroundColor DarkGray
Write-Host '  $critical = $work | Where-Object { $_.Status -eq "Draft" -and $_.HoursSinceActivity -gt 48 }' -ForegroundColor DarkGray
Write-Host '  $critical | Format-Table Number, Title, Assignee, HoursSinceActivity' -ForegroundColor DarkGray
Write-Host ""
Write-Host "This generates a focused report on draft PRs that have been stalled for 2+ days" -ForegroundColor White
Write-Host ""

# Example 9: Running without specifying Owner/Repo (auto-detect from current repo)
Write-Host "Example 9: Auto-detect repository from current context" -ForegroundColor Yellow
Write-Host 'Command: .\Get-StalledWork.ps1 -StalledThresholdHours 24' -ForegroundColor Gray
Write-Host ""
Write-Host "If run from within a git repository with gh CLI authenticated:" -ForegroundColor White
Write-Host "  - Owner and Repo are auto-detected" -ForegroundColor White
Write-Host "  - No need to specify repository details" -ForegroundColor White
Write-Host ""

# Example 10: Integration with monitoring/alerting
Write-Host "Example 10: Daily monitoring script" -ForegroundColor Yellow
Write-Host 'Example monitoring script:' -ForegroundColor Gray
Write-Host '  # Run daily to detect stalled work' -ForegroundColor DarkGray
Write-Host '  $stalled = .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -StalledThresholdHours 48' -ForegroundColor DarkGray
Write-Host '  if ($stalled.Count -gt 0) {' -ForegroundColor DarkGray
Write-Host '    Write-Host "Warning: $($stalled.Count) items have been stalled for 48+ hours" -ForegroundColor Red' -ForegroundColor DarkGray
Write-Host '    $stalled | Format-Table' -ForegroundColor DarkGray
Write-Host '    # Send notification or create an issue' -ForegroundColor DarkGray
Write-Host '  }' -ForegroundColor DarkGray
Write-Host ""
Write-Host "This can be integrated into CI/CD pipelines or cron jobs for automated monitoring" -ForegroundColor White
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "For more information, see: Get-StalledWork.ps1 -?" -ForegroundColor Gray
Write-Host ""
