<#
.SYNOPSIS
    Examples demonstrating usage of Get-PRReviewTimeline.ps1

.DESCRIPTION
    This file contains various examples showing how to use the Get-PRReviewTimeline.ps1
    script for analyzing PR review timelines.
#>

$scriptPath = Join-Path $PSScriptRoot ".." "Get-PRReviewTimeline.ps1"

Write-Host "=== Get-PRReviewTimeline.ps1 Usage Examples ===" -ForegroundColor Green
Write-Host ""

# Example 1: Basic console output
Write-Host "Example 1: Basic console output with colored timeline" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will display a colorful console timeline showing:" -ForegroundColor Gray
Write-Host "  - PR metadata (title, author, state)" -ForegroundColor Gray
Write-Host "  - Cycle time metrics" -ForegroundColor Gray
Write-Host "  - Bottleneck analysis" -ForegroundColor Gray
Write-Host "  - Chronological timeline of all events" -ForegroundColor Gray
Write-Host ""

# Uncomment to run:
# & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6

# Example 2: Markdown table output
Write-Host "Example 2: Markdown table output for documentation" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Markdown" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will output markdown tables suitable for:" -ForegroundColor Gray
Write-Host "  - Documentation in README files" -ForegroundColor Gray
Write-Host "  - PR comments or issue descriptions" -ForegroundColor Gray
Write-Host "  - Reports and dashboards" -ForegroundColor Gray
Write-Host ""

# Uncomment to run:
# & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -OutputFormat Markdown

# Example 3: JSON output for programmatic processing
Write-Host "Example 3: JSON output for scripts and automation" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will output structured JSON containing:" -ForegroundColor Gray
Write-Host "  - All timeline events with timestamps" -ForegroundColor Gray
Write-Host "  - Calculated metrics" -ForegroundColor Gray
Write-Host "  - Bottleneck analysis data" -ForegroundColor Gray
Write-Host "  - PR metadata" -ForegroundColor Gray
Write-Host ""

# Uncomment to run:
# $result = & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -OutputFormat Json | ConvertFrom-Json
# Write-Host "PR #$($result.PullRequest.Number): $($result.PullRequest.Title)"
# Write-Host "Total Cycle Time: $($result.Metrics.TotalCycleTime)"

# Example 4: Include detailed comments
Write-Host "Example 4: Include detailed review comments" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeComments" -ForegroundColor Yellow
Write-Host ""
Write-Host "This will include individual review comments in the timeline." -ForegroundColor Gray
Write-Host "Useful for detailed analysis but can be verbose for large PRs." -ForegroundColor Gray
Write-Host ""

# Uncomment to run:
# & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -IncludeComments

# Example 5: DryRun mode for testing
Write-Host "Example 5: DryRun mode to preview the GraphQL query" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun" -ForegroundColor Yellow
Write-Host ""
Write-Host "Running in DryRun mode..." -ForegroundColor Gray
& $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -DryRun
Write-Host ""

# Example 6: Using with custom correlation ID for tracing
Write-Host "Example 6: Custom correlation ID for tracing" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -CorrelationId 'TRACE-001'" -ForegroundColor Yellow
Write-Host ""
Write-Host "Use custom correlation IDs to:" -ForegroundColor Gray
Write-Host "  - Track related operations across multiple scripts" -ForegroundColor Gray
Write-Host "  - Correlate logs for debugging" -ForegroundColor Gray
Write-Host "  - Group related timeline analyses" -ForegroundColor Gray
Write-Host ""

# Uncomment to run:
# & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -CorrelationId "TRACE-001"

# Example 7: Analyzing multiple PRs in a loop
Write-Host "Example 7: Batch analysis of multiple PRs" -ForegroundColor Cyan
Write-Host "Script:" -ForegroundColor Yellow
Write-Host '  $prNumbers = @(1, 2, 3, 4, 5)' -ForegroundColor Gray
Write-Host '  foreach ($prNum in $prNumbers) {' -ForegroundColor Gray
Write-Host '    $result = & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber $prNum -OutputFormat Json | ConvertFrom-Json' -ForegroundColor Gray
Write-Host '    Write-Host "PR #$prNum: $($result.Metrics.TimeToMerge)"' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host ""
Write-Host "This can be used to:" -ForegroundColor Gray
Write-Host "  - Compare review times across multiple PRs" -ForegroundColor Gray
Write-Host "  - Identify patterns in review bottlenecks" -ForegroundColor Gray
Write-Host "  - Generate aggregate metrics" -ForegroundColor Gray
Write-Host ""

# Example 8: Combining with verbose logging
Write-Host "Example 8: Verbose logging for debugging" -ForegroundColor Cyan
Write-Host "Command: Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -Verbose" -ForegroundColor Yellow
Write-Host ""
Write-Host "Verbose mode will show:" -ForegroundColor Gray
Write-Host "  - GraphQL execution details" -ForegroundColor Gray
Write-Host "  - Retry attempts and delays" -ForegroundColor Gray
Write-Host "  - Correlation IDs for tracing" -ForegroundColor Gray
Write-Host "  - Structured log messages" -ForegroundColor Gray
Write-Host ""

# Uncomment to run:
# & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -Verbose

# Example 9: Piping output to file
Write-Host "Example 9: Save timeline to file" -ForegroundColor Cyan
Write-Host "Script:" -ForegroundColor Yellow
Write-Host '  # Markdown to file' -ForegroundColor Gray
Write-Host '  & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -OutputFormat Markdown > pr6-timeline.md' -ForegroundColor Gray
Write-Host '' -ForegroundColor Gray
Write-Host '  # JSON to file' -ForegroundColor Gray
Write-Host '  & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6 -OutputFormat Json > pr6-timeline.json' -ForegroundColor Gray
Write-Host ""

# Example 10: Using the returned object for further processing
Write-Host "Example 10: Processing the returned object" -ForegroundColor Cyan
Write-Host "Script:" -ForegroundColor Yellow
Write-Host '  $timeline = & $scriptPath -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 6' -ForegroundColor Gray
Write-Host '  ' -ForegroundColor Gray
Write-Host '  # Access the timeline events' -ForegroundColor Gray
Write-Host '  $reviewEvents = $timeline.Events | Where-Object { $_.Type -eq "REVIEW_SUBMITTED" }' -ForegroundColor Gray
Write-Host '  Write-Host "Total reviews: $($reviewEvents.Count)"' -ForegroundColor Gray
Write-Host '  ' -ForegroundColor Gray
Write-Host '  # Access metrics' -ForegroundColor Gray
Write-Host '  if ($timeline.Metrics.TimeToFirstReview) {' -ForegroundColor Gray
Write-Host '    Write-Host "Time to first review: $($timeline.Metrics.TimeToFirstReview)"' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host '  ' -ForegroundColor Gray
Write-Host '  # Access bottleneck info' -ForegroundColor Gray
Write-Host '  if ($timeline.Metrics.LongestWaitPeriod) {' -ForegroundColor Gray
Write-Host '    Write-Host "Longest wait: $($timeline.Metrics.LongestWaitPeriod.Duration)"' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host ""

Write-Host "=== End of Examples ===" -ForegroundColor Green
Write-Host ""
Write-Host "For more information, see:" -ForegroundColor Cyan
Write-Host "  Get-Help $scriptPath -Full" -ForegroundColor Yellow
Write-Host ""
