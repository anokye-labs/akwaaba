<#
.SYNOPSIS
    Example usage for Get-PRCommentAnalysis.ps1

.DESCRIPTION
    This file demonstrates how to use Get-PRCommentAnalysis.ps1 to analyze PR comments.
    
    NOTE: These examples require GitHub CLI (gh) to be authenticated.
#>

# Example 1: Basic usage with console output
Write-Host "Example 1: Basic console output" -ForegroundColor Cyan
Write-Host "Command: .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6`n"

# Uncomment to run:
# .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

# Example 2: JSON output for agent consumption
Write-Host "`nExample 2: JSON output for agent consumption" -ForegroundColor Cyan
Write-Host "Command: .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json`n"

# Uncomment to run:
# $json = .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json
# $data = $json | ConvertFrom-Json
# Write-Host "Blocking comments: $($data.summary.byCategory.blocking)"
# Write-Host "Suggestions: $($data.summary.byCategory.suggestion)"

# Example 3: Markdown output
Write-Host "`nExample 3: Markdown output" -ForegroundColor Cyan
Write-Host "Command: .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Markdown > analysis.md`n"

# Uncomment to run:
# .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Markdown | Out-File analysis.md

# Example 4: Include resolved threads
Write-Host "`nExample 4: Include resolved threads in analysis" -ForegroundColor Cyan
Write-Host "Command: .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeResolved`n"

# Uncomment to run:
# .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeResolved

# Example 5: Programmatic usage - get blocking comments only
Write-Host "`nExample 5: Programmatic usage - filter for blocking comments" -ForegroundColor Cyan
Write-Host @"
Command:
`$json = .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json
`$analysis = `$json | ConvertFrom-Json
`$blocking = `$analysis.categories.blocking
foreach (`$comment in `$blocking) {
    Write-Host "BLOCKING: `$(`$comment.FilePath):`$(`$comment.Line) - `$(`$comment.Body.Substring(0, [Math]::Min(50, `$comment.Body.Length)))"
}
"@

Write-Host "`n"

# Example 6: Get files that need attention
Write-Host "`nExample 6: Identify files with most unresolved comments" -ForegroundColor Cyan
Write-Host @"
Command:
`$json = .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json
`$analysis = `$json | ConvertFrom-Json
`$analysis.byFile.PSObject.Properties | ForEach-Object {
    `$file = `$_.Name
    `$comments = `$_.Value
    `$unresolved = (`$comments | Where-Object { -not `$_.IsResolved }).Count
    [PSCustomObject]@{
        File = `$file
        TotalComments = `$comments.Count
        Unresolved = `$unresolved
    }
} | Sort-Object Unresolved -Descending | Format-Table
"@

Write-Host "`n"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "For real usage, uncomment the examples above and run them." -ForegroundColor Yellow
Write-Host "Ensure you have GitHub CLI (gh) authenticated first." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
