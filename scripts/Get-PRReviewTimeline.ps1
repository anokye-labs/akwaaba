<#
.SYNOPSIS
    Timeline view of PR review activity showing when reviews were requested, submitted, and comments posted/resolved.

.DESCRIPTION
    Get-PRReviewTimeline.ps1 fetches comprehensive timeline data for a pull request, including:
    - When review requests were sent to reviewers
    - When reviews were submitted (approved, changes requested, commented)
    - When review comments were posted and resolved
    - When the PR was created, merged, or closed
    - Total cycle time from creation to merge/close
    - Identification of bottlenecks (longest wait periods)
    
    This tool helps understand the review flow and identify delays in the review process.

.PARAMETER Owner
    Repository owner (username or organization).

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER OutputFormat
    Output format: Console (default, colored output), Markdown (table format), or Json (structured data).
    
.PARAMETER IncludeComments
    Include individual review comments in the timeline (may be verbose for large PRs).

.PARAMETER DryRun
    If specified, logs the query without executing it against the API.

.PARAMETER CorrelationId
    Optional correlation ID for tracing related operations.

.EXAMPLE
    .\Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6
    
    Shows a console timeline of PR #6 with colored output.

.EXAMPLE
    .\Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Markdown
    
    Outputs timeline in markdown table format.

.EXAMPLE
    .\Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json
    
    Outputs timeline as JSON for programmatic processing.

.EXAMPLE
    .\Get-PRReviewTimeline.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeComments
    
    Includes all individual review comments in the timeline.

.OUTPUTS
    PSCustomObject with timeline events, cycle times, and bottleneck analysis.
    Format depends on -OutputFormat parameter.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Uses Invoke-GraphQL.ps1 for API calls with retry logic.
    Uses Write-OkyeremaLog.ps1 for structured logging.
    Uses Get-RepoContext.ps1 for repository metadata.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,
    
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    
    [Parameter(Mandatory = $true)]
    [int]$PullNumber,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$OutputFormat = "Console",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludeComments,
    
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Get script directory for relative paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper function to invoke Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [switch]$DryRun,
        [string]$CorrelationId
    )
    
    $invokeParams = @{
        Query = $Query
        Variables = $Variables
        CorrelationId = $CorrelationId
    }
    
    if ($DryRun) {
        $invokeParams.DryRun = $true
    }
    
    $invokeGraphQLPath = Join-Path $ScriptDir "Invoke-GraphQL.ps1"
    & $invokeGraphQLPath @invokeParams
}

# Helper function to invoke Write-OkyeremaLog.ps1
function Write-LogHelper {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "GetPRReviewTimeline",
        [string]$CorrelationId
    )
    
    $logParams = @{
        Message = $Message
        Level = $Level
        Operation = $Operation
        CorrelationId = $CorrelationId
    }
    
    $writeLogPath = Join-Path $ScriptDir ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    & $writeLogPath @logParams
}

Write-LogHelper -Message "Starting PR review timeline fetch for $Owner/$Repo#$PullNumber" -CorrelationId $CorrelationId

# GraphQL query to fetch PR timeline data
$query = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$number) {
      id
      number
      title
      state
      isDraft
      createdAt
      updatedAt
      mergedAt
      closedAt
      author {
        login
      }
      timelineItems(first: 100, itemTypes: [
        REVIEW_REQUESTED_EVENT,
        REVIEW_REQUEST_REMOVED_EVENT,
        PULL_REQUEST_REVIEW,
        PULL_REQUEST_REVIEW_THREAD,
        MERGED_EVENT,
        CLOSED_EVENT,
        REOPENED_EVENT,
        READY_FOR_REVIEW_EVENT,
        CONVERT_TO_DRAFT_EVENT
      ]) {
        totalCount
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          __typename
          ... on ReviewRequestedEvent {
            createdAt
            requestedReviewer {
              ... on User {
                login
              }
              ... on Team {
                name
              }
            }
            actor {
              login
            }
          }
          ... on ReviewRequestRemovedEvent {
            createdAt
            requestedReviewer {
              ... on User {
                login
              }
              ... on Team {
                name
              }
            }
            actor {
              login
            }
          }
          ... on PullRequestReview {
            id
            createdAt
            submittedAt
            state
            author {
              login
            }
            comments(first: 10) {
              totalCount
              nodes {
                id
                createdAt
                body
                path
                position
              }
            }
          }
          ... on PullRequestReviewThread {
            id
            isResolved
            resolvedAt
            comments(first: 10) {
              totalCount
              nodes {
                id
                createdAt
                author {
                  login
                }
                body
                path
              }
            }
          }
          ... on MergedEvent {
            createdAt
            actor {
              login
            }
            commit {
              oid
            }
          }
          ... on ClosedEvent {
            createdAt
            actor {
              login
            }
          }
          ... on ReopenedEvent {
            createdAt
            actor {
              login
            }
          }
          ... on ReadyForReviewEvent {
            createdAt
            actor {
              login
            }
          }
          ... on ConvertToDraftEvent {
            createdAt
            actor {
              login
            }
          }
        }
      }
      reviewThreads(first: 50) {
        totalCount
        nodes {
          id
          isResolved
          resolvedAt
          comments(first: 10) {
            totalCount
            nodes {
              id
              createdAt
              author {
                login
              }
              body
              path
            }
          }
        }
      }
      reviews(first: 50) {
        totalCount
        nodes {
          id
          createdAt
          submittedAt
          state
          author {
            login
          }
        }
      }
    }
  }
}
"@

$variables = @{
    owner = $Owner
    repo = $Repo
    number = $PullNumber
}

Write-LogHelper -Message "Executing GraphQL query for PR timeline" -CorrelationId $CorrelationId

$result = Invoke-GraphQLHelper -Query $query -Variables $variables -DryRun:$DryRun -CorrelationId $CorrelationId

if ($DryRun) {
    Write-LogHelper -Message "DryRun mode - query not executed" -CorrelationId $CorrelationId
    return $result
}

if (-not $result.Success) {
    Write-LogHelper -Message "GraphQL query failed" -Level "Error" -CorrelationId $CorrelationId
    foreach ($error in $result.Errors) {
        Write-LogHelper -Message "Error: $($error.Message)" -Level "Error" -CorrelationId $CorrelationId
    }
    throw "Failed to fetch PR timeline: $($result.Errors[0].Message)"
}

$pr = $result.Data.repository.pullRequest

if (-not $pr) {
    Write-LogHelper -Message "Pull request #$PullNumber not found" -Level "Error" -CorrelationId $CorrelationId
    throw "Pull request #$PullNumber not found in $Owner/$Repo"
}

Write-LogHelper -Message "Successfully fetched PR timeline data" -CorrelationId $CorrelationId

# Process timeline events
$events = @()

# Add PR creation event
$events += [PSCustomObject]@{
    Timestamp = [DateTime]::Parse($pr.createdAt)
    Type = "PR_CREATED"
    Actor = $pr.author.login
    Description = "Pull request created"
    Details = @{
        Title = $pr.title
        State = $pr.state
        IsDraft = $pr.isDraft
    }
}

# Process timeline items
foreach ($item in $pr.timelineItems.nodes) {
    $timestamp = $null
    $type = $null
    $actor = $null
    $description = $null
    $details = @{}
    
    switch ($item.__typename) {
        "ReviewRequestedEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "REVIEW_REQUESTED"
            $actor = $item.actor.login
            $reviewer = if ($item.requestedReviewer.login) { $item.requestedReviewer.login } else { $item.requestedReviewer.name }
            $description = "Review requested from @$reviewer"
            $details.Reviewer = $reviewer
        }
        "ReviewRequestRemovedEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "REVIEW_REQUEST_REMOVED"
            $actor = $item.actor.login
            $reviewer = if ($item.requestedReviewer.login) { $item.requestedReviewer.login } else { $item.requestedReviewer.name }
            $description = "Review request removed from @$reviewer"
            $details.Reviewer = $reviewer
        }
        "PullRequestReview" {
            $timestamp = if ($item.submittedAt) { [DateTime]::Parse($item.submittedAt) } else { [DateTime]::Parse($item.createdAt) }
            $type = "REVIEW_SUBMITTED"
            $actor = $item.author.login
            $stateText = switch ($item.state) {
                "APPROVED" { "approved" }
                "CHANGES_REQUESTED" { "requested changes" }
                "COMMENTED" { "commented" }
                "DISMISSED" { "was dismissed" }
                default { $item.state.ToLower() }
            }
            $description = "Review $stateText by @$actor"
            $details.ReviewState = $item.state
            $details.CommentCount = $item.comments.totalCount
            $details.ReviewId = $item.id
            
            # Optionally include individual comments
            if ($IncludeComments -and $item.comments.totalCount -gt 0) {
                $details.Comments = $item.comments.nodes | ForEach-Object {
                    @{
                        CreatedAt = $_.createdAt
                        Body = $_.body
                        Path = $_.path
                        Position = $_.position
                    }
                }
            }
        }
        "PullRequestReviewThread" {
            if ($IncludeComments -and $item.comments.totalCount -gt 0) {
                $firstComment = $item.comments.nodes[0]
                $timestamp = [DateTime]::Parse($firstComment.createdAt)
                $type = "REVIEW_THREAD"
                $actor = $firstComment.author.login
                $resolvedText = if ($item.isResolved) { " (resolved)" } else { "" }
                $description = "Review thread started$resolvedText"
                $details.ThreadId = $item.id
                $details.IsResolved = $item.isResolved
                $details.ResolvedAt = $item.resolvedAt
                $details.CommentCount = $item.comments.totalCount
                $details.Path = $firstComment.path
            }
        }
        "MergedEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "PR_MERGED"
            $actor = $item.actor.login
            $description = "Pull request merged"
            $details.CommitOid = $item.commit.oid
        }
        "ClosedEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "PR_CLOSED"
            $actor = $item.actor.login
            $description = "Pull request closed"
        }
        "ReopenedEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "PR_REOPENED"
            $actor = $item.actor.login
            $description = "Pull request reopened"
        }
        "ReadyForReviewEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "READY_FOR_REVIEW"
            $actor = $item.actor.login
            $description = "Marked ready for review"
        }
        "ConvertToDraftEvent" {
            $timestamp = [DateTime]::Parse($item.createdAt)
            $type = "CONVERTED_TO_DRAFT"
            $actor = $item.actor.login
            $description = "Converted to draft"
        }
    }
    
    if ($timestamp) {
        $events += [PSCustomObject]@{
            Timestamp = $timestamp
            Type = $type
            Actor = $actor
            Description = $description
            Details = $details
        }
    }
}

# Add merge/close event if present
if ($pr.mergedAt) {
    # Check if we already have a merged event from timeline
    $hasMergedEvent = $events | Where-Object { $_.Type -eq "PR_MERGED" }
    if (-not $hasMergedEvent) {
        $events += [PSCustomObject]@{
            Timestamp = [DateTime]::Parse($pr.mergedAt)
            Type = "PR_MERGED"
            Actor = $null
            Description = "Pull request merged"
            Details = @{}
        }
    }
}
elseif ($pr.closedAt) {
    # Check if we already have a closed event from timeline
    $hasClosedEvent = $events | Where-Object { $_.Type -eq "PR_CLOSED" }
    if (-not $hasClosedEvent) {
        $events += [PSCustomObject]@{
            Timestamp = [DateTime]::Parse($pr.closedAt)
            Type = "PR_CLOSED"
            Actor = $null
            Description = "Pull request closed"
            Details = @{}
        }
    }
}

# Sort events by timestamp
$events = $events | Sort-Object -Property Timestamp

# Calculate cycle times and identify bottlenecks
$cycleMetrics = [PSCustomObject]@{
    TotalCycleTime = $null
    TimeToFirstReview = $null
    TimeToApproval = $null
    TimeToMerge = $null
    LongestWaitPeriod = $null
    ReviewCount = ($events | Where-Object { $_.Type -eq "REVIEW_SUBMITTED" }).Count
    ReviewRequestCount = ($events | Where-Object { $_.Type -eq "REVIEW_REQUESTED" }).Count
}

$creationEvent = $events | Where-Object { $_.Type -eq "PR_CREATED" } | Select-Object -First 1
$firstReview = $events | Where-Object { $_.Type -eq "REVIEW_SUBMITTED" } | Select-Object -First 1
$firstApproval = $events | Where-Object { $_.Type -eq "REVIEW_SUBMITTED" -and $_.Details.ReviewState -eq "APPROVED" } | Select-Object -First 1
$mergeEvent = $events | Where-Object { $_.Type -eq "PR_MERGED" } | Select-Object -First 1
$closeEvent = $events | Where-Object { $_.Type -eq "PR_CLOSED" } | Select-Object -First 1

if ($firstReview) {
    $cycleMetrics.TimeToFirstReview = ($firstReview.Timestamp - $creationEvent.Timestamp)
}

if ($firstApproval) {
    $cycleMetrics.TimeToApproval = ($firstApproval.Timestamp - $creationEvent.Timestamp)
}

if ($mergeEvent) {
    $cycleMetrics.TimeToMerge = ($mergeEvent.Timestamp - $creationEvent.Timestamp)
    $cycleMetrics.TotalCycleTime = $cycleMetrics.TimeToMerge
}
elseif ($closeEvent) {
    $cycleMetrics.TotalCycleTime = ($closeEvent.Timestamp - $creationEvent.Timestamp)
}
elseif ($pr.updatedAt) {
    $cycleMetrics.TotalCycleTime = ([DateTime]::Parse($pr.updatedAt) - $creationEvent.Timestamp)
}

# Find longest wait period (time between consecutive events)
$maxWait = $null
$maxWaitStart = $null
$maxWaitEnd = $null

for ($i = 0; $i -lt ($events.Count - 1); $i++) {
    $wait = $events[$i + 1].Timestamp - $events[$i].Timestamp
    if (-not $maxWait -or $wait -gt $maxWait) {
        $maxWait = $wait
        $maxWaitStart = $events[$i]
        $maxWaitEnd = $events[$i + 1]
    }
}

if ($maxWait) {
    $cycleMetrics.LongestWaitPeriod = [PSCustomObject]@{
        Duration = $maxWait
        FromEvent = $maxWaitStart.Description
        FromTime = $maxWaitStart.Timestamp
        ToEvent = $maxWaitEnd.Description
        ToTime = $maxWaitEnd.Timestamp
    }
}

# Build result object
$timelineResult = [PSCustomObject]@{
    PullRequest = [PSCustomObject]@{
        Number = $pr.number
        Title = $pr.title
        State = $pr.state
        Author = $pr.author.login
        CreatedAt = $pr.createdAt
        UpdatedAt = $pr.updatedAt
        MergedAt = $pr.mergedAt
        ClosedAt = $pr.closedAt
        IsDraft = $pr.isDraft
    }
    Events = $events
    Metrics = $cycleMetrics
    CorrelationId = $CorrelationId
}

# Output based on format
switch ($OutputFormat) {
    "Json" {
        Write-LogHelper -Message "Outputting timeline as JSON" -CorrelationId $CorrelationId
        return $timelineResult | ConvertTo-Json -Depth 10
    }
    "Markdown" {
        Write-LogHelper -Message "Outputting timeline as Markdown" -CorrelationId $CorrelationId
        
        # PR Summary
        Write-Output "# PR Review Timeline: #$($pr.number) - $($pr.title)"
        Write-Output ""
        Write-Output "**Repository:** $Owner/$Repo"
        Write-Output "**Author:** @$($pr.author.login)"
        Write-Output "**State:** $($pr.state)"
        Write-Output "**Created:** $($pr.createdAt)"
        if ($pr.mergedAt) {
            Write-Output "**Merged:** $($pr.mergedAt)"
        }
        elseif ($pr.closedAt) {
            Write-Output "**Closed:** $($pr.closedAt)"
        }
        Write-Output ""
        
        # Metrics
        Write-Output "## Metrics"
        Write-Output ""
        Write-Output "| Metric | Value |"
        Write-Output "|--------|-------|"
        if ($cycleMetrics.TotalCycleTime) {
            Write-Output "| Total Cycle Time | $($cycleMetrics.TotalCycleTime.ToString()) |"
        }
        if ($cycleMetrics.TimeToFirstReview) {
            Write-Output "| Time to First Review | $($cycleMetrics.TimeToFirstReview.ToString()) |"
        }
        if ($cycleMetrics.TimeToApproval) {
            Write-Output "| Time to Approval | $($cycleMetrics.TimeToApproval.ToString()) |"
        }
        if ($cycleMetrics.TimeToMerge) {
            Write-Output "| Time to Merge | $($cycleMetrics.TimeToMerge.ToString()) |"
        }
        Write-Output "| Review Count | $($cycleMetrics.ReviewCount) |"
        Write-Output "| Review Request Count | $($cycleMetrics.ReviewRequestCount) |"
        Write-Output ""
        
        # Bottleneck
        if ($cycleMetrics.LongestWaitPeriod) {
            Write-Output "## Bottleneck Analysis"
            Write-Output ""
            Write-Output "**Longest Wait Period:** $($cycleMetrics.LongestWaitPeriod.Duration.ToString())"
            Write-Output ""
            Write-Output "- **From:** $($cycleMetrics.LongestWaitPeriod.FromEvent) at $($cycleMetrics.LongestWaitPeriod.FromTime)"
            Write-Output "- **To:** $($cycleMetrics.LongestWaitPeriod.ToEvent) at $($cycleMetrics.LongestWaitPeriod.ToTime)"
            Write-Output ""
        }
        
        # Timeline
        Write-Output "## Timeline"
        Write-Output ""
        Write-Output "| Timestamp | Event | Actor | Description |"
        Write-Output "|-----------|-------|-------|-------------|"
        foreach ($event in $events) {
            $actorDisplay = if ($event.Actor) { "@$($event.Actor)" } else { "" }
            Write-Output "| $($event.Timestamp.ToString('yyyy-MM-dd HH:mm:ss')) | $($event.Type) | $actorDisplay | $($event.Description) |"
        }
        Write-Output ""
    }
    "Console" {
        Write-LogHelper -Message "Outputting timeline to console" -CorrelationId $CorrelationId
        
        # PR Summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " PR Review Timeline" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Repository: " -ForegroundColor Gray -NoNewline
        Write-Host "$Owner/$Repo" -ForegroundColor White
        Write-Host "  PR Number:  " -ForegroundColor Gray -NoNewline
        Write-Host "#$($pr.number)" -ForegroundColor White
        Write-Host "  Title:      " -ForegroundColor Gray -NoNewline
        Write-Host "$($pr.title)" -ForegroundColor White
        Write-Host "  Author:     " -ForegroundColor Gray -NoNewline
        Write-Host "@$($pr.author.login)" -ForegroundColor Cyan
        Write-Host "  State:      " -ForegroundColor Gray -NoNewline
        
        $stateColor = switch ($pr.state) {
            "MERGED" { "Green" }
            "OPEN" { "Yellow" }
            "CLOSED" { "Red" }
            default { "White" }
        }
        Write-Host "$($pr.state)" -ForegroundColor $stateColor
        
        Write-Host "  Created:    " -ForegroundColor Gray -NoNewline
        Write-Host "$($pr.createdAt)" -ForegroundColor White
        
        if ($pr.mergedAt) {
            Write-Host "  Merged:     " -ForegroundColor Gray -NoNewline
            Write-Host "$($pr.mergedAt)" -ForegroundColor Green
        }
        elseif ($pr.closedAt) {
            Write-Host "  Closed:     " -ForegroundColor Gray -NoNewline
            Write-Host "$($pr.closedAt)" -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host " Metrics" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        
        if ($cycleMetrics.TotalCycleTime) {
            Write-Host "  Total Cycle Time:        " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.TotalCycleTime.ToString())" -ForegroundColor White
        }
        if ($cycleMetrics.TimeToFirstReview) {
            Write-Host "  Time to First Review:    " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.TimeToFirstReview.ToString())" -ForegroundColor White
        }
        if ($cycleMetrics.TimeToApproval) {
            Write-Host "  Time to Approval:        " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.TimeToApproval.ToString())" -ForegroundColor White
        }
        if ($cycleMetrics.TimeToMerge) {
            Write-Host "  Time to Merge:           " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.TimeToMerge.ToString())" -ForegroundColor White
        }
        Write-Host "  Review Count:            " -ForegroundColor Gray -NoNewline
        Write-Host "$($cycleMetrics.ReviewCount)" -ForegroundColor White
        Write-Host "  Review Request Count:    " -ForegroundColor Gray -NoNewline
        Write-Host "$($cycleMetrics.ReviewRequestCount)" -ForegroundColor White
        
        if ($cycleMetrics.LongestWaitPeriod) {
            Write-Host ""
            Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host " Bottleneck Analysis" -ForegroundColor Cyan
            Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "  Longest Wait Period: " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.LongestWaitPeriod.Duration.ToString())" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "    From: " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.LongestWaitPeriod.FromEvent)" -ForegroundColor White -NoNewline
            Write-Host " at " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.LongestWaitPeriod.FromTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
            Write-Host "    To:   " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.LongestWaitPeriod.ToEvent)" -ForegroundColor White -NoNewline
            Write-Host " at " -ForegroundColor Gray -NoNewline
            Write-Host "$($cycleMetrics.LongestWaitPeriod.ToTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host " Timeline ($($events.Count) events)" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        
        foreach ($event in $events) {
            $eventColor = switch ($event.Type) {
                "PR_CREATED" { "Cyan" }
                "REVIEW_REQUESTED" { "Yellow" }
                "REVIEW_SUBMITTED" { "Green" }
                "PR_MERGED" { "Green" }
                "PR_CLOSED" { "Red" }
                "READY_FOR_REVIEW" { "Cyan" }
                default { "White" }
            }
            
            Write-Host "  $($event.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor DarkGray -NoNewline
            Write-Host "  │  " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($event.Type.PadRight(25))" -ForegroundColor $eventColor -NoNewline
            
            if ($event.Actor) {
                Write-Host "  @$($event.Actor)" -ForegroundColor Cyan -NoNewline
            }
            
            Write-Host "  " -NoNewline
            Write-Host "$($event.Description)" -ForegroundColor White
            
            # Show additional details for some event types
            if ($event.Type -eq "REVIEW_SUBMITTED" -and $event.Details.CommentCount -gt 0) {
                Write-Host "     " -NoNewline
                Write-Host "└─ " -ForegroundColor DarkGray -NoNewline
                Write-Host "$($event.Details.CommentCount) comment(s)" -ForegroundColor Gray
            }
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        # Return the object for pipeline use
        return $timelineResult
    }
}

Write-LogHelper -Message "PR review timeline completed successfully" -CorrelationId $CorrelationId
