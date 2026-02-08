<#
.SYNOPSIS
    Detect stalled agent work — PRs or issues that have been assigned but show no activity beyond a configurable threshold.

.DESCRIPTION
    Get-StalledWork.ps1 detects stalled agent work by identifying:
    - PRs with no commits or comments beyond the threshold
    - Assigned issues with no linked PR and no activity beyond the threshold
    
    This script helps identify work that may need intervention or reassignment.

.PARAMETER Owner
    Repository owner (username or organization). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    Repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER StalledThresholdHours
    Number of hours of inactivity to consider work as stalled. Default is 24 hours.

.PARAMETER IncludePRs
    If specified, includes pull requests in the stalled work detection. 
    Default behavior: both PRs and Issues are included if neither switch is specified.

.PARAMETER IncludeIssues
    If specified, includes issues in the stalled work detection.
    Default behavior: both PRs and Issues are included if neither switch is specified.

.PARAMETER CorrelationId
    Optional correlation ID for tracing operations.

.OUTPUTS
    Returns an array of PSCustomObject with:
    - Number: PR or Issue number
    - Title: PR or Issue title
    - Type: "PR" or "Issue"
    - Assignee: Current assignee login
    - LastActivityDate: Date of last activity (ISO 8601 format)
    - HoursSinceActivity: Hours since last activity
    - Status: Draft/Open/InProgress

.EXAMPLE
    .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba"
    
    Detects all stalled work (PRs and issues) with default 24-hour threshold.

.EXAMPLE
    .\Get-StalledWork.ps1 -StalledThresholdHours 48 -IncludePRs -IncludeIssues:$false
    
    Detects only stalled PRs with a 48-hour threshold.

.EXAMPLE
    .\Get-StalledWork.ps1 -Owner "anokye-labs" -Repo "akwaaba" -StalledThresholdHours 12
    
    Detects stalled work with a 12-hour threshold.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Depends on: Invoke-GraphQL.ps1, Get-RepoContext.ps1, Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 8760)] # Maximum 1 year (365 days)
    [int]$StalledThresholdHours = 24,

    [Parameter(Mandatory = $false)]
    [switch]$IncludePRs,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeIssues,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Default behavior: include both PRs and Issues if neither is explicitly specified
if (-not $PSBoundParameters.ContainsKey('IncludePRs') -and -not $PSBoundParameters.ContainsKey('IncludeIssues')) {
    $IncludePRs = $true
    $IncludeIssues = $true
}

#region Helper Functions

# Helper function to invoke Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Variables = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId
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
    
    # Call Invoke-GraphQL.ps1 as a script
    & "$PSScriptRoot/Invoke-GraphQL.ps1" @params
}

# Helper function to invoke Get-RepoContext.ps1
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

# Helper function to invoke Write-OkyeremaLog.ps1
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
        [string]$CorrelationId = ""
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
    
    # Call Write-OkyeremaLog.ps1 as a script
    $scriptPath = Join-Path $PSScriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    & $scriptPath @params
}

# Helper function to calculate hours since a datetime
function Get-HoursSince {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DateTimeString
    )
    
    $dateTime = [datetime]::MinValue
    if ([datetime]::TryParse($DateTimeString, [ref]$dateTime)) {
        $now = Get-Date
        $timeSpan = $now - $dateTime
        return [math]::Round($timeSpan.TotalHours, 2)
    }
    else {
        Write-OkyeremaLogHelper -Level Warn -Message "Failed to parse datetime: $DateTimeString, returning very high value to indicate error" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
        # Return a very high value (1 year) to indicate parsing failure
        # This prevents failed parsing from making items appear as "not stalled"
        return 8760
    }
}

# Helper function to safely compare two datetime strings
function Test-IsDateNewer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DateString1,
        
        [Parameter(Mandatory = $true)]
        [string]$DateString2
    )
    
    $date1 = [datetime]::MinValue
    $date2 = [datetime]::MinValue
    
    $parsed1 = [datetime]::TryParse($DateString1, [ref]$date1)
    $parsed2 = [datetime]::TryParse($DateString2, [ref]$date2)
    
    if ($parsed1 -and $parsed2) {
        return $date1 -gt $date2
    }
    
    return $false
}

#endregion

#region Main Logic

Write-OkyeremaLogHelper -Level Info -Message "Starting stalled work detection (threshold: $StalledThresholdHours hours)" -Operation "Get-StalledWork" -CorrelationId $CorrelationId

# Get repository context if Owner/Repo not provided
if (-not $Owner -or -not $Repo) {
    Write-OkyeremaLogHelper -Level Info -Message "Fetching repository context" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
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
        Write-OkyeremaLogHelper -Level Error -Message "Could not determine repository owner and name" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
        throw "Owner and Repo parameters are required, or must be run from a Git repository"
    }
}

Write-OkyeremaLogHelper -Level Debug -Message "Using repository: $Owner/$Repo" -Operation "Get-StalledWork" -CorrelationId $CorrelationId

$stalledItems = @()

#region Detect Stalled PRs

if ($IncludePRs) {
    Write-OkyeremaLogHelper -Level Info -Message "Detecting stalled pull requests" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
    
    # Build GraphQL query to fetch open/draft PRs with assignees
    $prQuery = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequests(first: 100, states: [OPEN], orderBy: {field: UPDATED_AT, direction: ASC}) {
      nodes {
        number
        title
        isDraft
        createdAt
        updatedAt
        assignees(first: 10) {
          nodes {
            login
          }
        }
        commits(last: 1) {
          nodes {
            commit {
              committedDate
            }
          }
        }
        comments(last: 1) {
          nodes {
            createdAt
          }
        }
        reviews(last: 1) {
          nodes {
            createdAt
          }
        }
        timelineItems(last: 1, itemTypes: [ISSUE_COMMENT, PULL_REQUEST_COMMIT, PULL_REQUEST_REVIEW]) {
          nodes {
            ... on IssueComment {
              createdAt
              __typename
            }
            ... on PullRequestCommit {
              commit {
                committedDate
              }
              __typename
            }
            ... on PullRequestReview {
              createdAt
              __typename
            }
          }
        }
      }
    }
  }
}
"@

    $prVariables = @{
        owner = $Owner
        repo = $Repo
    }
    
    $prResult = Invoke-GraphQLHelper -Query $prQuery -Variables $prVariables -CorrelationId $CorrelationId
    
    if (-not $prResult.Success) {
        Write-OkyeremaLogHelper -Level Error -Message "Failed to fetch PRs: $($prResult.Errors[0].Message)" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
        throw "Failed to fetch PRs: $($prResult.Errors[0].Message)"
    }
    
    $prs = $prResult.Data.repository.pullRequests.nodes
    Write-OkyeremaLogHelper -Level Info -Message "Found $($prs.Count) open PRs" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
    
    foreach ($pr in $prs) {
        # Skip PRs without assignees
        if ($pr.assignees.nodes.Count -eq 0) {
            continue
        }
        
        # Determine last activity date
        $lastActivityDate = $pr.updatedAt
        
        # Check last commit date
        # Note: GraphQL 'last: 1' returns the most recent commit, accessed as nodes[0]
        if ($pr.commits.nodes.Count -gt 0 -and $pr.commits.nodes[0].commit.committedDate) {
            $commitDate = $pr.commits.nodes[0].commit.committedDate
            if (Test-IsDateNewer -DateString1 $commitDate -DateString2 $lastActivityDate) {
                $lastActivityDate = $commitDate
            }
        }
        
        # Check last comment date
        if ($pr.comments.nodes.Count -gt 0 -and $pr.comments.nodes[0].createdAt) {
            $commentDate = $pr.comments.nodes[0].createdAt
            if (Test-IsDateNewer -DateString1 $commentDate -DateString2 $lastActivityDate) {
                $lastActivityDate = $commentDate
            }
        }
        
        # Check last review date
        if ($pr.reviews.nodes.Count -gt 0 -and $pr.reviews.nodes[0].createdAt) {
            $reviewDate = $pr.reviews.nodes[0].createdAt
            if (Test-IsDateNewer -DateString1 $reviewDate -DateString2 $lastActivityDate) {
                $lastActivityDate = $reviewDate
            }
        }
        
        # Check timeline items for most recent activity
        if ($pr.timelineItems.nodes.Count -gt 0) {
            foreach ($item in $pr.timelineItems.nodes) {
                $itemDate = $null
                if ($item.__typename -eq "PullRequestCommit" -and $item.commit.committedDate) {
                    $itemDate = $item.commit.committedDate
                }
                elseif ($item.createdAt) {
                    $itemDate = $item.createdAt
                }
                
                if ($itemDate -and (Test-IsDateNewer -DateString1 $itemDate -DateString2 $lastActivityDate)) {
                    $lastActivityDate = $itemDate
                }
            }
        }
        
        # Calculate hours since last activity
        $hoursSinceActivity = Get-HoursSince -DateTimeString $lastActivityDate
        
        # Check if stalled (no activity beyond threshold)
        if ($hoursSinceActivity -ge $StalledThresholdHours) {
            $status = if ($pr.isDraft) { "Draft" } else { "Open" }
            
            # Get assignee (just the first one for simplicity)
            $assignee = if ($pr.assignees.nodes.Count -gt 0) {
                $pr.assignees.nodes[0].login
            } else {
                "none"
            }
            
            $stalledItems += [PSCustomObject]@{
                Number = $pr.number
                Title = $pr.title
                Type = "PR"
                Assignee = $assignee
                LastActivityDate = $lastActivityDate
                HoursSinceActivity = $hoursSinceActivity
                Status = $status
            }
            
            Write-OkyeremaLogHelper -Level Debug -Message "Found stalled PR #$($pr.number): $hoursSinceActivity hours since activity" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
        }
    }
    
    Write-OkyeremaLogHelper -Level Info -Message "Found $($stalledItems.Count) stalled PRs" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
}

#endregion

#region Detect Stalled Issues

if ($IncludeIssues) {
    Write-OkyeremaLogHelper -Level Info -Message "Detecting stalled issues" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
    
    # Build GraphQL query to fetch assigned, open issues
    $issueQuery = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, states: OPEN, orderBy: {field: UPDATED_AT, direction: ASC}) {
      nodes {
        number
        title
        createdAt
        updatedAt
        assignees(first: 10) {
          nodes {
            login
          }
        }
        comments(last: 1) {
          nodes {
            createdAt
          }
        }
        timelineItems(first: 100, itemTypes: [CONNECTED_EVENT, DISCONNECTED_EVENT]) {
          nodes {
            ... on ConnectedEvent {
              createdAt
              subject {
                ... on PullRequest {
                  number
                  state
                  updatedAt
                }
              }
              __typename
            }
            ... on DisconnectedEvent {
              createdAt
              __typename
            }
          }
        }
        labels(first: 50) {
          nodes {
            name
          }
        }
      }
    }
  }
}
"@

    $issueVariables = @{
        owner = $Owner
        repo = $Repo
    }
    
    $issueResult = Invoke-GraphQLHelper -Query $issueQuery -Variables $issueVariables -CorrelationId $CorrelationId
    
    if (-not $issueResult.Success) {
        Write-OkyeremaLogHelper -Level Error -Message "Failed to fetch issues: $($issueResult.Errors[0].Message)" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
        throw "Failed to fetch issues: $($issueResult.Errors[0].Message)"
    }
    
    $issues = $issueResult.Data.repository.issues.nodes
    Write-OkyeremaLogHelper -Level Info -Message "Found $($issues.Count) open issues" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
    
    foreach ($issue in $issues) {
        # Skip issues without assignees
        if ($issue.assignees.nodes.Count -eq 0) {
            continue
        }
        
        # Check if issue has a linked, open PR
        $hasOpenLinkedPR = $false
        foreach ($timelineItem in $issue.timelineItems.nodes) {
            if ($timelineItem.__typename -eq "ConnectedEvent" -and 
                $timelineItem.subject -and 
                $timelineItem.subject.state -eq "OPEN") {
                $hasOpenLinkedPR = $true
                break
            }
        }
        
        # Skip issues with open linked PRs (they're tracked via PR detection)
        if ($hasOpenLinkedPR) {
            continue
        }
        
        # Determine last activity date
        $lastActivityDate = $issue.updatedAt
        
        # Check last comment date
        if ($issue.comments.nodes.Count -gt 0 -and $issue.comments.nodes[0].createdAt) {
            $commentDate = $issue.comments.nodes[0].createdAt
            if (Test-IsDateNewer -DateString1 $commentDate -DateString2 $lastActivityDate) {
                $lastActivityDate = $commentDate
            }
        }
        
        # Calculate hours since last activity
        $hoursSinceActivity = Get-HoursSince -DateTimeString $lastActivityDate
        
        # Check if stalled (no activity beyond threshold)
        if ($hoursSinceActivity -ge $StalledThresholdHours) {
            # Check for "In Progress" label or similar
            $status = "Open"
            foreach ($label in $issue.labels.nodes) {
                if ($label.name -match "(?i)in[- ]?progress|working|started") {
                    $status = "InProgress"
                    break
                }
            }
            
            # Get assignee (just the first one for simplicity)
            $assignee = if ($issue.assignees.nodes.Count -gt 0) {
                $issue.assignees.nodes[0].login
            } else {
                "none"
            }
            
            $stalledItems += [PSCustomObject]@{
                Number = $issue.number
                Title = $issue.title
                Type = "Issue"
                Assignee = $assignee
                LastActivityDate = $lastActivityDate
                HoursSinceActivity = $hoursSinceActivity
                Status = $status
            }
            
            Write-OkyeremaLogHelper -Level Debug -Message "Found stalled issue #$($issue.number): $hoursSinceActivity hours since activity" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
        }
    }
    
    Write-OkyeremaLogHelper -Level Info -Message "Found $($stalledItems.Count) total stalled items" -Operation "Get-StalledWork" -CorrelationId $CorrelationId
}

#endregion

# Sort by hours since activity (most stalled first)
$stalledItems = $stalledItems | Sort-Object -Property HoursSinceActivity -Descending

Write-OkyeremaLogHelper -Level Info -Message "Stalled work detection complete. Found $($stalledItems.Count) stalled items." -Operation "Get-StalledWork" -CorrelationId $CorrelationId

# Return structured output
return $stalledItems

#endregion
