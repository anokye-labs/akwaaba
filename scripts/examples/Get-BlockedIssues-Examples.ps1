<#
.SYNOPSIS
    Example usage of Get-BlockedIssues.ps1

.DESCRIPTION
    This example demonstrates how to use Get-BlockedIssues.ps1 to analyze
    blocked issues in a GitHub repository.
#>

Write-Host "=== Get-BlockedIssues.ps1 Usage Examples ===" -ForegroundColor Green
Write-Host ""

# Example 1: Basic usage with explicit repository
Write-Host "Example 1: Analyze blocked issues in a repository" -ForegroundColor Cyan
Write-Host "Command: ./Get-BlockedIssues.ps1 -Owner 'anokye-labs' -Repo 'akwaaba'" -ForegroundColor Yellow
Write-Host ""

# Uncomment to run:
# $result = ./Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba"

# Example 2: Get results in JSON format
Write-Host "Example 2: Get results in JSON format" -ForegroundColor Cyan
Write-Host "Command: ./Get-BlockedIssues.ps1 -Owner 'anokye-labs' -Repo 'akwaaba' -OutputFormat Json" -ForegroundColor Yellow
Write-Host ""

# Uncomment to run:
# $result = ./Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputFormat Json

# Example 3: Get a summary only
Write-Host "Example 3: Get a summary only" -ForegroundColor Cyan
Write-Host "Command: ./Get-BlockedIssues.ps1 -Owner 'anokye-labs' -Repo 'akwaaba' -OutputFormat Summary" -ForegroundColor Yellow
Write-Host ""

# Uncomment to run:
# $result = ./Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputFormat Summary

# Example 4: Include closed issues in analysis
Write-Host "Example 4: Include closed issues" -ForegroundColor Cyan
Write-Host "Command: ./Get-BlockedIssues.ps1 -Owner 'anokye-labs' -Repo 'akwaaba' -IncludeClosed" -ForegroundColor Yellow
Write-Host ""

# Uncomment to run:
# $result = ./Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -IncludeClosed

# Example 5: Pipeline usage - get blocked issues and work with the data
Write-Host "Example 5: Pipeline usage" -ForegroundColor Cyan
Write-Host @"
Command:
`$result = ./Get-BlockedIssues.ps1 -Owner 'anokye-labs' -Repo 'akwaaba'
Write-Host "Found `$(`$result.TotalBlocked) blocked issues out of `$(`$result.TotalOpen) open issues"

# Work with the resolution order
foreach (`$issue in `$result.ResolutionOrder) {
    Write-Host "Next to work on: #`$(`$issue.Number) - `$(`$issue.Title)"
}
"@ -ForegroundColor Yellow
Write-Host ""

# Example 6: Check if specific issue is blocked
Write-Host "Example 6: Check if specific issue is blocked" -ForegroundColor Cyan
Write-Host @"
Command:
`$result = ./Get-BlockedIssues.ps1 -Owner 'anokye-labs' -Repo 'akwaaba'
`$issueNumber = 18
`$blocked = `$result.BlockedIssues | Where-Object { `$_.Number -eq `$issueNumber }

if (`$blocked) {
    Write-Host "Issue #`$issueNumber is blocked by:"
    foreach (`$blocker in `$blocked.BlockedBy) {
        Write-Host "  - #`$(`$blocker.Number): `$(`$blocker.Title)"
    }
} else {
    Write-Host "Issue #`$issueNumber is not blocked and can be worked on!"
}
"@ -ForegroundColor Yellow
Write-Host ""

Write-Host "=== Expected Issue Format ===" -ForegroundColor Green
Write-Host @"
Issues should include a '## Dependencies' section with 'Blocked by:' list:

## Dependencies

Blocked by:
- [ ] anokye-labs/akwaaba#14 - Invoke-GraphQL.ps1
- [ ] anokye-labs/akwaaba#15 - Get-RepoContext.ps1
- [ ] #42 - Some local issue

**Wave: 1** — Cannot start until all dependencies are merged.
"@ -ForegroundColor White
Write-Host ""

Write-Host "=== Prerequisites ===" -ForegroundColor Green
Write-Host "- PowerShell 7.x or higher" -ForegroundColor White
Write-Host "- GitHub CLI (gh) installed and authenticated" -ForegroundColor White
Write-Host "- GH_TOKEN environment variable set (for GitHub Actions)" -ForegroundColor White
Write-Host ""

Write-Host "=== End of Examples ===" -ForegroundColor Green
Write-Host ""
Write-Host "Uncomment the execution blocks in this script to run actual queries." -ForegroundColor Yellow
Write-Host "Ensure you have proper authentication set up first." -ForegroundColor Yellow
