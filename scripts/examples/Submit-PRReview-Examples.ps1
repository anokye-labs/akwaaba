<#
.SYNOPSIS
    Examples demonstrating usage of Submit-PRReview.ps1

.DESCRIPTION
    This file contains various examples showing how to use the Submit-PRReview.ps1
    script for different PR review scenarios.
#>

# Path to the script
$scriptPath = Join-Path $PSScriptRoot ".." "Submit-PRReview.ps1"

Write-Host "`n=== Submit-PRReview.ps1 Usage Examples ===" -ForegroundColor Green
Write-Host ""

# Example 1: Simple approval with a comment
Write-Host "Example 1: Simple approval with a comment" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor DarkGray

$example1 = @"
& `$scriptPath ``
    -Owner 'anokye-labs' ``
    -Repo 'akwaaba' ``
    -PullNumber 10 ``
    -Event APPROVE ``
    -Body 'LGTM! Great work on this feature. 🚀'
"@

Write-Host $example1 -ForegroundColor Yellow
Write-Host ""

# Uncomment to run:
# & $scriptPath -Owner 'anokye-labs' -Repo 'akwaaba' -PullNumber 10 -Event APPROVE -Body 'LGTM! Great work on this feature. 🚀'

# Example 2: Request changes with inline file comments
Write-Host "Example 2: Request changes with inline file comments" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor DarkGray

$example2 = @"
`$comments = @(
    @{
        Path = 'src/Submit-PRReview.ps1'
        Line = 42
        Body = 'This should use the helper function instead of direct GraphQL call'
    }
    @{
        Path = 'src/utils.ps1'
        Line = 15
        Body = 'Missing error handling for null values here'
    }
)

& `$scriptPath ``
    -Owner 'anokye-labs' ``
    -Repo 'akwaaba' ``
    -PullNumber 10 ``
    -Event REQUEST_CHANGES ``
    -Body 'Please address the inline comments before merging.' ``
    -FileComments `$comments
"@

Write-Host $example2 -ForegroundColor Yellow
Write-Host ""

# Example 3: DryRun mode for testing
Write-Host "Example 3: DryRun mode for testing" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor DarkGray

$example3 = @"
& `$scriptPath ``
    -Owner 'anokye-labs' ``
    -Repo 'akwaaba' ``
    -PullNumber 10 ``
    -Event COMMENT ``
    -Body 'Testing the review system' ``
    -DryRun
"@

Write-Host $example3 -ForegroundColor Yellow
Write-Host ""

Write-Host "Running Example 3 (DryRun mode)..." -ForegroundColor Magenta
# Filter out JSON log entries (structured logs from Write-OkyeremaLog.ps1)
& $scriptPath -Owner 'anokye-labs' -Repo 'akwaaba' -PullNumber 10 -Event COMMENT -Body 'Testing the review system' -DryRun 2>&1 | Where-Object { $_ -notmatch '^{' }
Write-Host ""

Write-Host "=== End of Examples ===" -ForegroundColor Green
Write-Host ""
Write-Host "To run actual reviews, uncomment the execution blocks in this script." -ForegroundColor Yellow
Write-Host "Note: You need to be authenticated with 'gh auth login' first." -ForegroundColor Yellow
Write-Host "      Replace owner, repo, and PR numbers with actual values." -ForegroundColor Yellow
Write-Host ""
