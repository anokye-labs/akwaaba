<#
.SYNOPSIS
    Comprehensive PR status check with merge, review, issues, threads, and time metrics.

.DESCRIPTION
    Get-PRStatus.ps1 provides a comprehensive status report for a GitHub Pull Request.
    It retrieves and analyzes:
    - Merge status (mergeable, conflicts, CI checks passing)
    - Review status (approved, changes requested, pending)
    - Linked issues and their states
    - Comment thread summary (resolved vs unresolved)
    - Time-in-state metrics (time in draft, time since created, time since last update)
    
    The script queries GitHub GraphQL API for comprehensive PR data and formats the
    output according to the specified format (Console, Markdown, or Json).

.PARAMETER PRNumber
    The pull request number to check status for.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER OutputFormat
    Output format for the status report. Valid values: Console, Markdown, Json.
    Default is Console.

.PARAMETER DryRun
    If specified, shows what would be queried without making actual API calls.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Get-PRStatus.ps1 -PRNumber 42

.EXAMPLE
    ./Get-PRStatus.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba -OutputFormat Markdown

.EXAMPLE
    ./Get-PRStatus.ps1 -PRNumber 42 -OutputFormat Json

.EXAMPLE
    ./Get-PRStatus.ps1 -PRNumber 42 -DryRun

.OUTPUTS
    Returns a PSCustomObject with comprehensive PR status information, formatted
    according to the OutputFormat parameter.

.NOTES
    Author: Anokye Labs
    Dependencies: Invoke-GraphQL.ps1, Get-RepoContext.ps1, Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [int]$PRNumber,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$OutputFormat = "Console",

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

#region Helper Functions

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Variables = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $params = @{
        Query = $Query
    }
    
    if ($Variables.Count -gt 0) {
        $params.Variables = $Variables
    }
    
    if ($CorrelationId) {
        $params.CorrelationId = $CorrelationId
    }

    if ($DryRun) {
        $params.DryRun = $true
    }
    
    # Call Invoke-GraphQL.ps1 as a script
    & "$PSScriptRoot/Invoke-GraphQL.ps1" @params
}

# Helper function to call Get-RepoContext.ps1
function Get-RepoContextHelper {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )
    
    $params = @{}
    
    if ($Refresh) {
        $params.Refresh = $true
    }
    
    # Call Get-RepoContext.ps1 as a script
    & "$PSScriptRoot/Get-RepoContext.ps1" @params
}

# Helper function to call Write-OkyeremaLog.ps1
function Write-OkyeremaLogHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warn", "Error", "Debug")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [string]$Operation = "",

        [Parameter(Mandatory = $false)]
        [string]$CorrelationId = "",

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )
    
    $params = @{
        Message = $Message
        Level = $Level
    }
    
    if ($Operation) {
        $params.Operation = $Operation
    }
    
    if ($CorrelationId) {
        $params.CorrelationId = $CorrelationId
    }
    
    if ($Quiet) {
        $params.Quiet = $true
    }
    
    # Call Write-OkyeremaLog.ps1 as a script
    & "$PSScriptRoot/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1" @params
}

# Helper function to calculate time duration in human-readable format
function Get-HumanReadableDuration {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime = (Get-Date)
    )
    
    $timeSpan = $EndTime - $StartTime
    
    if ($timeSpan.TotalDays -ge 1) {
        $days = [math]::Floor($timeSpan.TotalDays)
        $hours = $timeSpan.Hours
        if ($days -eq 1) {
            return "1 day, $hours hours"
        }
        return "$days days, $hours hours"
    }
    elseif ($timeSpan.TotalHours -ge 1) {
        $hours = [math]::Floor($timeSpan.TotalHours)
        $minutes = $timeSpan.Minutes
        if ($hours -eq 1) {
            return "1 hour, $minutes minutes"
        }
        return "$hours hours, $minutes minutes"
    }
    elseif ($timeSpan.TotalMinutes -ge 1) {
        $minutes = [math]::Floor($timeSpan.TotalMinutes)
        if ($minutes -eq 1) {
            return "1 minute"
        }
        return "$minutes minutes"
    }
    else {
        return "less than a minute"
    }
}

#endregion

#region Main Logic

Write-OkyeremaLogHelper -Level Info -Message "Starting PR status check for PR #$PRNumber" -Operation "Get-PRStatus" -CorrelationId $CorrelationId

# Get repository context if Owner/Repo not provided
if (-not $Owner -or -not $Repo) {
    Write-OkyeremaLogHelper -Level Info -Message "Fetching repository context" -Operation "Get-PRStatus" -CorrelationId $CorrelationId
    $context = Get-RepoContextHelper
    
    if ($context -and $context.RepoId) {
        # Parse owner and repo from context
        $repoViewResult = & gh repo view --json nameWithOwner | ConvertFrom-Json
        if ($repoViewResult -and $repoViewResult.nameWithOwner) {
            $parts = $repoViewResult.nameWithOwner.Split('/')
            if ($parts.Length -eq 2) {
                if (-not $Owner) { $Owner = $parts[0] }
                if (-not $Repo) { $Repo = $parts[1] }
            }
        }
    }
    
    if (-not $Owner -or -not $Repo) {
        Write-OkyeremaLogHelper -Level Error -Message "Could not determine repository owner and name" -Operation "Get-PRStatus" -CorrelationId $CorrelationId
        throw "Owner and Repo parameters are required, or must be run from a Git repository"
    }
}

Write-OkyeremaLogHelper -Level Debug -Message "Using repository: $Owner/$Repo" -Operation "Get-PRStatus" -CorrelationId $CorrelationId

# Build GraphQL query for comprehensive PR status
$query = @"
query(`$owner: String!, `$repo: String!, `$prNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$prNumber) {
      number
      title
      url
      state
      isDraft
      createdAt
      updatedAt
      closedAt
      mergedAt
      mergeable
      merged
      author {
        login
      }
      baseRefName
      headRefName
      additions
      deletions
      changedFiles
      
      # Merge status and checks
      commits(last: 1) {
        nodes {
          commit {
            statusCheckRollup {
              state
              contexts(first: 100) {
                nodes {
                  ... on CheckRun {
                    name
                    conclusion
                    status
                    detailsUrl
                  }
                  ... on StatusContext {
                    context
                    state
                    targetUrl
                  }
                }
              }
            }
          }
        }
      }
      
      # Review status
      reviewDecision
      reviews(first: 100) {
        totalCount
        nodes {
          author {
            login
          }
          state
          submittedAt
          body
        }
      }
      
      # Review requests
      reviewRequests(first: 10) {
        totalCount
        nodes {
          requestedReviewer {
            ... on User {
              login
            }
            ... on Team {
              name
            }
          }
        }
      }
      
      # Linked issues via closing keywords
      closingIssuesReferences(first: 50) {
        totalCount
        nodes {
          number
          title
          state
          url
        }
      }
      
      # Comment threads
      reviewThreads(first: 100) {
        totalCount
        nodes {
          isResolved
          isOutdated
          comments(first: 1) {
            totalCount
            nodes {
              author {
                login
              }
              body
              createdAt
            }
          }
        }
      }
      
      # General comments
      comments(first: 100) {
        totalCount
      }
      
      # Timeline events for state changes
      timelineItems(first: 100, itemTypes: [READY_FOR_REVIEW_EVENT, CONVERT_TO_DRAFT_EVENT]) {
        nodes {
          ... on ReadyForReviewEvent {
            createdAt
            __typename
          }
          ... on ConvertToDraftEvent {
            createdAt
            __typename
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
    prNumber = $PRNumber
}

Write-OkyeremaLogHelper -Level Info -Message "Querying GitHub API for PR #$PRNumber" -Operation "Get-PRStatus" -CorrelationId $CorrelationId

# Execute GraphQL query
$result = Invoke-GraphQLHelper -Query $query -Variables $variables -CorrelationId $CorrelationId -DryRun:$DryRun

if (-not $result.Success) {
    Write-OkyeremaLogHelper -Level Error -Message "Failed to fetch PR status: $($result.Errors[0].Message)" -Operation "Get-PRStatus" -CorrelationId $CorrelationId
    throw "Failed to fetch PR status: $($result.Errors[0].Message)"
}

if ($DryRun) {
    Write-OkyeremaLogHelper -Level Info -Message "DryRun mode - query displayed but not executed" -Operation "Get-PRStatus" -CorrelationId $CorrelationId
    return $result
}

$pr = $result.Data.repository.pullRequest

if (-not $pr) {
    Write-OkyeremaLogHelper -Level Error -Message "PR #$PRNumber not found in $Owner/$Repo" -Operation "Get-PRStatus" -CorrelationId $CorrelationId
    throw "PR #$PRNumber not found in $Owner/$Repo"
}

Write-OkyeremaLogHelper -Level Info -Message "Processing PR status data" -Operation "Get-PRStatus" -CorrelationId $CorrelationId

#region Process PR Data

# Parse merge status
$mergeStatus = [PSCustomObject]@{
    Mergeable = $pr.mergeable
    Merged = $pr.merged
    State = $pr.state
    IsDraft = $pr.isDraft
}

# Parse CI checks
$ciChecks = @()
$checksState = "UNKNOWN"
if ($pr.commits.nodes.Count -gt 0 -and $pr.commits.nodes[0].commit.statusCheckRollup) {
    $rollup = $pr.commits.nodes[0].commit.statusCheckRollup
    $checksState = $rollup.state
    
    foreach ($context in $rollup.contexts.nodes) {
        if ($context.name) {
            # CheckRun
            $ciChecks += [PSCustomObject]@{
                Name = $context.name
                Status = $context.conclusion ?? $context.status
                Url = $context.detailsUrl
                Type = "CheckRun"
            }
        }
        elseif ($context.context) {
            # StatusContext
            $ciChecks += [PSCustomObject]@{
                Name = $context.context
                Status = $context.state
                Url = $context.targetUrl
                Type = "StatusContext"
            }
        }
    }
}

$mergeStatus | Add-Member -MemberType NoteProperty -Name "ChecksState" -Value $checksState
$mergeStatus | Add-Member -MemberType NoteProperty -Name "ChecksCount" -Value $ciChecks.Count
$mergeStatus | Add-Member -MemberType NoteProperty -Name "Checks" -Value $ciChecks

# Parse review status
$reviewStatus = [PSCustomObject]@{
    Decision = $pr.reviewDecision ?? "NONE"
    TotalReviews = $pr.reviews.totalCount
    PendingReviewers = $pr.reviewRequests.totalCount
}

# Count reviews by state
$approvedCount = ($pr.reviews.nodes | Where-Object { $_.state -eq "APPROVED" }).Count
$changesRequestedCount = ($pr.reviews.nodes | Where-Object { $_.state -eq "CHANGES_REQUESTED" }).Count
$commentedCount = ($pr.reviews.nodes | Where-Object { $_.state -eq "COMMENTED" }).Count

$reviewStatus | Add-Member -MemberType NoteProperty -Name "Approved" -Value $approvedCount
$reviewStatus | Add-Member -MemberType NoteProperty -Name "ChangesRequested" -Value $changesRequestedCount
$reviewStatus | Add-Member -MemberType NoteProperty -Name "Commented" -Value $commentedCount

# Get pending reviewers
$pendingReviewers = @()
foreach ($request in $pr.reviewRequests.nodes) {
    if ($request.requestedReviewer.login) {
        $pendingReviewers += $request.requestedReviewer.login
    }
    elseif ($request.requestedReviewer.name) {
        $pendingReviewers += $request.requestedReviewer.name
    }
}
$reviewStatus | Add-Member -MemberType NoteProperty -Name "PendingReviewersList" -Value $pendingReviewers

# Parse linked issues
$linkedIssues = @()
foreach ($issue in $pr.closingIssuesReferences.nodes) {
    $linkedIssues += [PSCustomObject]@{
        Number = $issue.number
        Title = $issue.title
        State = $issue.state
        Url = $issue.url
    }
}

# Parse comment threads
$threadStatus = [PSCustomObject]@{
    Total = $pr.reviewThreads.totalCount
    Resolved = ($pr.reviewThreads.nodes | Where-Object { $_.isResolved }).Count
    Unresolved = ($pr.reviewThreads.nodes | Where-Object { -not $_.isResolved }).Count
    Outdated = ($pr.reviewThreads.nodes | Where-Object { $_.isOutdated }).Count
    GeneralComments = $pr.comments.totalCount
}

# Calculate time-in-state metrics
$createdAt = [datetime]::Parse($pr.createdAt)
$updatedAt = [datetime]::Parse($pr.updatedAt)
$now = Get-Date

$timeMetrics = [PSCustomObject]@{
    CreatedAt = $pr.createdAt
    UpdatedAt = $pr.updatedAt
    AgeSinceCreated = Get-HumanReadableDuration -StartTime $createdAt
    TimeSinceLastUpdate = Get-HumanReadableDuration -StartTime $updatedAt
}

# Calculate time in draft vs ready
$draftTime = $null
$readyTime = $null

if ($pr.isDraft) {
    # Currently in draft
    $lastReadyEvent = $pr.timelineItems.nodes | Where-Object { $_.__typename -eq "ReadyForReviewEvent" } | Select-Object -Last 1
    if ($lastReadyEvent) {
        $lastReadyAt = [datetime]::Parse($lastReadyEvent.createdAt)
        $draftTime = Get-HumanReadableDuration -StartTime $lastReadyAt
    }
    else {
        # Never been ready
        $draftTime = Get-HumanReadableDuration -StartTime $createdAt
    }
}
else {
    # Currently ready
    $lastDraftEvent = $pr.timelineItems.nodes | Where-Object { $_.__typename -eq "ConvertToDraftEvent" } | Select-Object -Last 1
    $lastReadyEvent = $pr.timelineItems.nodes | Where-Object { $_.__typename -eq "ReadyForReviewEvent" } | Select-Object -Last 1
    
    if ($lastReadyEvent) {
        $lastReadyAt = [datetime]::Parse($lastReadyEvent.createdAt)
        $readyTime = Get-HumanReadableDuration -StartTime $lastReadyAt
    }
    elseif (-not $lastDraftEvent) {
        # Was never draft
        $readyTime = Get-HumanReadableDuration -StartTime $createdAt
    }
}

$timeMetrics | Add-Member -MemberType NoteProperty -Name "TimeInDraft" -Value $draftTime
$timeMetrics | Add-Member -MemberType NoteProperty -Name "TimeReady" -Value $readyTime

if ($pr.closedAt) {
    $timeMetrics | Add-Member -MemberType NoteProperty -Name "ClosedAt" -Value $pr.closedAt
}
if ($pr.mergedAt) {
    $timeMetrics | Add-Member -MemberType NoteProperty -Name "MergedAt" -Value $pr.mergedAt
}

#endregion

# Build comprehensive status object
$statusObject = [PSCustomObject]@{
    PRNumber = $pr.number
    Title = $pr.title
    Author = $pr.author.login
    Url = $pr.url
    BaseRef = $pr.baseRefName
    HeadRef = $pr.headRefName
    Additions = $pr.additions
    Deletions = $pr.deletions
    ChangedFiles = $pr.changedFiles
    MergeStatus = $mergeStatus
    ReviewStatus = $reviewStatus
    LinkedIssues = $linkedIssues
    ThreadStatus = $threadStatus
    TimeMetrics = $timeMetrics
}

Write-OkyeremaLogHelper -Level Info -Message "PR status retrieved successfully" -Operation "Get-PRStatus" -CorrelationId $CorrelationId

#endregion

#region Output Formatting

switch ($OutputFormat) {
    "Json" {
        return $statusObject | ConvertTo-Json -Depth 10
    }
    
    "Markdown" {
        $markdown = @"
# PR #$($pr.number): $($pr.title)

**Author:** $($pr.author.login)  
**URL:** $($pr.url)  
**Branch:** ``$($pr.headRefName)`` → ``$($pr.baseRefName)``  
**Changes:** +$($pr.additions) -$($pr.deletions) ($($pr.changedFiles) files)

## 🔀 Merge Status

| Property | Value |
|----------|-------|
| State | $($mergeStatus.State) |
| Mergeable | $($mergeStatus.Mergeable) |
| Merged | $($mergeStatus.Merged) |
| Is Draft | $($mergeStatus.IsDraft) |
| Checks State | $($mergeStatus.ChecksState) |
| Checks Count | $($mergeStatus.ChecksCount) |

"@

        if ($ciChecks.Count -gt 0) {
            $markdown += @"
### CI Checks

| Name | Status | Type |
|------|--------|------|

"@
            foreach ($check in $ciChecks) {
                $markdown += "| $($check.Name) | $($check.Status) | $($check.Type) |`n"
            }
            $markdown += "`n"
        }

        $markdown += @"
## 👥 Review Status

| Property | Value |
|----------|-------|
| Decision | $($reviewStatus.Decision) |
| Approved | $($reviewStatus.Approved) |
| Changes Requested | $($reviewStatus.ChangesRequested) |
| Commented | $($reviewStatus.Commented) |
| Pending Reviewers | $($reviewStatus.PendingReviewers) |

"@

        if ($pendingReviewers.Count -gt 0) {
            $markdown += "**Pending Reviewers:** " + ($pendingReviewers -join ", ") + "`n`n"
        }

        if ($linkedIssues.Count -gt 0) {
            $markdown += @"
## 🔗 Linked Issues

| Number | Title | State |
|--------|-------|-------|

"@
            foreach ($issue in $linkedIssues) {
                $markdown += "| [#$($issue.Number)]($($issue.Url)) | $($issue.Title) | $($issue.State) |`n"
            }
            $markdown += "`n"
        }
        else {
            $markdown += "## 🔗 Linked Issues`n`nNo linked issues found.`n`n"
        }

        $markdown += @"
## 💬 Comment Threads

| Property | Value |
|----------|-------|
| Total Threads | $($threadStatus.Total) |
| Resolved | $($threadStatus.Resolved) |
| Unresolved | $($threadStatus.Unresolved) |
| Outdated | $($threadStatus.Outdated) |
| General Comments | $($threadStatus.GeneralComments) |

## ⏱️ Time Metrics

| Property | Value |
|----------|-------|
| Created | $($timeMetrics.CreatedAt) |
| Last Updated | $($timeMetrics.UpdatedAt) |
| Age | $($timeMetrics.AgeSinceCreated) |
| Time Since Update | $($timeMetrics.TimeSinceLastUpdate) |

"@

        if ($timeMetrics.TimeInDraft) {
            $markdown += "| Time in Draft | $($timeMetrics.TimeInDraft) |`n"
        }
        if ($timeMetrics.TimeReady) {
            $markdown += "| Time Ready | $($timeMetrics.TimeReady) |`n"
        }
        if ($timeMetrics.MergedAt) {
            $markdown += "| Merged At | $($timeMetrics.MergedAt) |`n"
        }
        if ($timeMetrics.ClosedAt) {
            $markdown += "| Closed At | $($timeMetrics.ClosedAt) |`n"
        }

        return $markdown
    }
    
    "Console" {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  PR #$($pr.number): $($pr.title)" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Author: " -NoNewline -ForegroundColor Gray
        Write-Host $pr.author.login -ForegroundColor White
        Write-Host "URL: " -NoNewline -ForegroundColor Gray
        Write-Host $pr.url -ForegroundColor Cyan
        Write-Host "Branch: " -NoNewline -ForegroundColor Gray
        Write-Host "$($pr.headRefName) → $($pr.baseRefName)" -ForegroundColor Yellow
        Write-Host "Changes: " -NoNewline -ForegroundColor Gray
        Write-Host "+$($pr.additions) -$($pr.deletions) " -NoNewline -ForegroundColor White
        Write-Host "($($pr.changedFiles) files)" -ForegroundColor DarkGray
        Write-Host ""
        
        # Merge Status
        Write-Host "🔀 MERGE STATUS" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        $stateColor = switch ($mergeStatus.State) {
            "OPEN" { "Green" }
            "CLOSED" { "Red" }
            "MERGED" { "Magenta" }
            default { "Gray" }
        }
        Write-Host "  State: " -NoNewline -ForegroundColor Gray
        Write-Host $mergeStatus.State -ForegroundColor $stateColor
        
        $mergeableColor = switch ($mergeStatus.Mergeable) {
            "MERGEABLE" { "Green" }
            "CONFLICTING" { "Red" }
            default { "Yellow" }
        }
        Write-Host "  Mergeable: " -NoNewline -ForegroundColor Gray
        Write-Host $mergeStatus.Mergeable -ForegroundColor $mergeableColor
        
        Write-Host "  Merged: " -NoNewline -ForegroundColor Gray
        Write-Host $mergeStatus.Merged -ForegroundColor $(if ($mergeStatus.Merged) { "Green" } else { "Gray" })
        
        Write-Host "  Is Draft: " -NoNewline -ForegroundColor Gray
        Write-Host $mergeStatus.IsDraft -ForegroundColor $(if ($mergeStatus.IsDraft) { "Yellow" } else { "Gray" })
        
        $checksColor = switch ($mergeStatus.ChecksState) {
            "SUCCESS" { "Green" }
            "FAILURE" { "Red" }
            "PENDING" { "Yellow" }
            default { "Gray" }
        }
        Write-Host "  Checks State: " -NoNewline -ForegroundColor Gray
        Write-Host $mergeStatus.ChecksState -ForegroundColor $checksColor
        Write-Host "  Checks Count: " -NoNewline -ForegroundColor Gray
        Write-Host $mergeStatus.ChecksCount -ForegroundColor White
        
        if ($ciChecks.Count -gt 0) {
            Write-Host ""
            Write-Host "  CI Checks:" -ForegroundColor DarkCyan
            foreach ($check in $ciChecks) {
                $checkColor = switch ($check.Status) {
                    "SUCCESS" { "Green" }
                    "FAILURE" { "Red" }
                    "PENDING" { "Yellow" }
                    "IN_PROGRESS" { "Yellow" }
                    "QUEUED" { "DarkYellow" }
                    default { "Gray" }
                }
                Write-Host "    • " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($check.Name): " -NoNewline -ForegroundColor Gray
                Write-Host $check.Status -ForegroundColor $checkColor
            }
        }
        Write-Host ""
        
        # Review Status
        Write-Host "👥 REVIEW STATUS" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        $decisionColor = switch ($reviewStatus.Decision) {
            "APPROVED" { "Green" }
            "CHANGES_REQUESTED" { "Red" }
            "REVIEW_REQUIRED" { "Yellow" }
            default { "Gray" }
        }
        Write-Host "  Decision: " -NoNewline -ForegroundColor Gray
        Write-Host $reviewStatus.Decision -ForegroundColor $decisionColor
        
        Write-Host "  Approved: " -NoNewline -ForegroundColor Gray
        Write-Host $reviewStatus.Approved -ForegroundColor $(if ($reviewStatus.Approved -gt 0) { "Green" } else { "Gray" })
        
        Write-Host "  Changes Requested: " -NoNewline -ForegroundColor Gray
        Write-Host $reviewStatus.ChangesRequested -ForegroundColor $(if ($reviewStatus.ChangesRequested -gt 0) { "Red" } else { "Gray" })
        
        Write-Host "  Commented: " -NoNewline -ForegroundColor Gray
        Write-Host $reviewStatus.Commented -ForegroundColor White
        
        Write-Host "  Pending Reviewers: " -NoNewline -ForegroundColor Gray
        Write-Host $reviewStatus.PendingReviewers -ForegroundColor $(if ($reviewStatus.PendingReviewers -gt 0) { "Yellow" } else { "Gray" })
        
        if ($pendingReviewers.Count -gt 0) {
            Write-Host "    • " -NoNewline -ForegroundColor DarkGray
            Write-Host ($pendingReviewers -join ", ") -ForegroundColor Yellow
        }
        Write-Host ""
        
        # Linked Issues
        Write-Host "🔗 LINKED ISSUES" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        if ($linkedIssues.Count -gt 0) {
            foreach ($issue in $linkedIssues) {
                $issueStateColor = if ($issue.State -eq "OPEN") { "Green" } else { "Gray" }
                Write-Host "  • " -NoNewline -ForegroundColor DarkGray
                Write-Host "#$($issue.Number) " -NoNewline -ForegroundColor Cyan
                Write-Host "[$($issue.State)] " -NoNewline -ForegroundColor $issueStateColor
                Write-Host $issue.Title -ForegroundColor White
            }
        }
        else {
            Write-Host "  No linked issues found" -ForegroundColor DarkGray
        }
        Write-Host ""
        
        # Comment Threads
        Write-Host "💬 COMMENT THREADS" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Total Threads: " -NoNewline -ForegroundColor Gray
        Write-Host $threadStatus.Total -ForegroundColor White
        Write-Host "  Resolved: " -NoNewline -ForegroundColor Gray
        Write-Host $threadStatus.Resolved -ForegroundColor Green
        Write-Host "  Unresolved: " -NoNewline -ForegroundColor Gray
        Write-Host $threadStatus.Unresolved -ForegroundColor $(if ($threadStatus.Unresolved -gt 0) { "Yellow" } else { "Gray" })
        Write-Host "  Outdated: " -NoNewline -ForegroundColor Gray
        Write-Host $threadStatus.Outdated -ForegroundColor DarkGray
        Write-Host "  General Comments: " -NoNewline -ForegroundColor Gray
        Write-Host $threadStatus.GeneralComments -ForegroundColor White
        Write-Host ""
        
        # Time Metrics
        Write-Host "⏱️  TIME METRICS" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Created: " -NoNewline -ForegroundColor Gray
        Write-Host $timeMetrics.CreatedAt -ForegroundColor White
        Write-Host "  Last Updated: " -NoNewline -ForegroundColor Gray
        Write-Host $timeMetrics.UpdatedAt -ForegroundColor White
        Write-Host "  Age: " -NoNewline -ForegroundColor Gray
        Write-Host $timeMetrics.AgeSinceCreated -ForegroundColor Yellow
        Write-Host "  Time Since Update: " -NoNewline -ForegroundColor Gray
        Write-Host $timeMetrics.TimeSinceLastUpdate -ForegroundColor Yellow
        
        if ($timeMetrics.TimeInDraft) {
            Write-Host "  Time in Draft: " -NoNewline -ForegroundColor Gray
            Write-Host $timeMetrics.TimeInDraft -ForegroundColor Magenta
        }
        if ($timeMetrics.TimeReady) {
            Write-Host "  Time Ready: " -NoNewline -ForegroundColor Gray
            Write-Host $timeMetrics.TimeReady -ForegroundColor Green
        }
        if ($timeMetrics.MergedAt) {
            Write-Host "  Merged At: " -NoNewline -ForegroundColor Gray
            Write-Host $timeMetrics.MergedAt -ForegroundColor Magenta
        }
        if ($timeMetrics.ClosedAt) {
            Write-Host "  Closed At: " -NoNewline -ForegroundColor Gray
            Write-Host $timeMetrics.ClosedAt -ForegroundColor Red
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        return $statusObject
    }
}

#endregion
