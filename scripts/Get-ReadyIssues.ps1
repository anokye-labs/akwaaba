<#
.SYNOPSIS
    Finds issues that are ready to work on - all dependencies met, not assigned.

.DESCRIPTION
    Get-ReadyIssues.ps1 walks the DAG (Directed Acyclic Graph) from a root Epic
    and identifies leaf tasks that are ready to work on. An issue is considered
    ready if:
    - It's a leaf node (has no children in the hierarchy)
    - Its parent is open
    - It has no open blocking dependencies (from "Blocked by:" section)
    - It's not assigned (or matches assignee filter if specified)
    
    The script returns a sorted list suitable for agent consumption.

.PARAMETER RootIssue
    The issue number of the root Epic to start traversal from.

.PARAMETER Labels
    Optional array of label names to filter issues by. Only issues with ALL specified
    labels will be included.

.PARAMETER IssueType
    Optional issue type name to filter by (e.g., "Task", "Bug", "Feature").

.PARAMETER Assignee
    Optional GitHub username to filter by. Use "none" to find unassigned issues.

.PARAMETER IncludeAssigned
    If specified, includes assigned issues in the results. By default, only
    unassigned issues are returned.

.PARAMETER SortBy
    Sort order for results. Options: "priority" (default), "number", "title".

.OUTPUTS
    Array of PSCustomObject with properties:
    - Number: Issue number
    - Title: Issue title
    - Type: Issue type name
    - State: Issue state (OPEN/CLOSED)
    - Url: Issue URL
    - Labels: Array of label names
    - Assignees: Array of assignee logins
    - Depth: Depth in the hierarchy (0 = root)

.EXAMPLE
    .\Get-ReadyIssues.ps1 -RootIssue 14
    Finds all ready issues under Epic #14.

.EXAMPLE
    .\Get-ReadyIssues.ps1 -RootIssue 14 -Labels @("priority:high", "backend")
    Finds ready issues with both "priority:high" and "backend" labels.

.EXAMPLE
    .\Get-ReadyIssues.ps1 -RootIssue 14 -IssueType "Task" -Assignee "none"
    Finds unassigned Task issues that are ready.

.EXAMPLE
    .\Get-ReadyIssues.ps1 -RootIssue 14 -IncludeAssigned
    Finds all ready issues, including those already assigned.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Depends on: Invoke-GraphQL.ps1, Get-RepoContext.ps1, Write-OkyeremaLog.ps1
    
    Limitations:
    - Fetches up to 3 levels deep in the hierarchy
    - Limited to 100 tracked issues per level
    - Limited to 50 labels and 10 assignees per issue
    - These limits are sufficient for most hierarchies but may truncate very large structures
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$RootIssue,

    [Parameter(Mandatory = $false)]
    [string[]]$Labels = @(),

    [Parameter(Mandatory = $false)]
    [string]$IssueType,

    [Parameter(Mandatory = $false)]
    [string]$Assignee,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeAssigned,

    [Parameter(Mandatory = $false)]
    [ValidateSet("priority", "number", "title")]
    [string]$SortBy = "priority"
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for this operation
$correlationId = [guid]::NewGuid().ToString()

# Helper function to call Write-OkyeremaLog.ps1
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logScript = Join-Path $PSScriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation "Get-ReadyIssues" -CorrelationId $correlationId
    }
}

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{}
    )
    
    $graphqlScript = Join-Path $PSScriptRoot "Invoke-GraphQL.ps1"
    return & $graphqlScript -Query $Query -Variables $Variables -CorrelationId $correlationId
}

# Helper function to call Get-RepoContext.ps1
function Get-RepoContextHelper {
    $contextScript = Join-Path $PSScriptRoot "Get-RepoContext.ps1"
    return & $contextScript
}

Write-Log "Starting Get-ReadyIssues for root issue #$RootIssue"

# Get repository context
Write-Verbose "Fetching repository context..."
$repoContext = Get-RepoContextHelper

if (-not $repoContext -or -not $repoContext.RepoId) {
    Write-Log "Failed to fetch repository context" -Level "Error"
    throw "Failed to fetch repository context"
}

Write-Log "Repository context retrieved: $($repoContext.RepoId)"

# Parse owner and repo from environment or gh
$repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
$parts = $repoInfo.nameWithOwner -split '/'
$owner = $parts[0]
$repo = $parts[1]

Write-Verbose "Repository: $owner/$repo"

# Build GraphQL query to fetch the entire DAG from root issue
# This recursively fetches children up to 3 levels deep
# Note: Limited to 100 issues per level, 50 labels, 10 assignees per issue
# These limits are sufficient for most hierarchies but may truncate large structures
$dagQuery = @"
query(`$owner: String!, `$repo: String!, `$rootNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$rootNumber) {
      id
      number
      title
      state
      url
      body
      issueType {
        id
        name
      }
      labels(first: 50) {
        nodes {
          name
        }
      }
      assignees(first: 10) {
        nodes {
          login
        }
      }
      trackedIssues(first: 100) {
        nodes {
          id
          number
          title
          state
          url
          body
          issueType {
            id
            name
          }
          labels(first: 50) {
            nodes {
              name
            }
          }
          assignees(first: 10) {
            nodes {
              login
            }
          }
          trackedIssues(first: 100) {
            nodes {
              id
              number
              title
              state
              url
              body
              issueType {
                id
                name
              }
              labels(first: 50) {
                nodes {
                  name
                }
              }
              assignees(first: 10) {
                nodes {
                  login
                }
              }
              trackedIssues(first: 100) {
                nodes {
                  id
                  number
                  title
                  state
                  url
                  body
                  issueType {
                    id
                    name
                  }
                  labels(first: 50) {
                    nodes {
                      name
                    }
                  }
                  assignees(first: 10) {
                    nodes {
                      login
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
"@

Write-Log "Fetching DAG from root issue #$RootIssue"

$variables = @{
    owner = $owner
    repo = $repo
    rootNumber = $RootIssue
}

$result = Invoke-GraphQLHelper -Query $dagQuery -Variables $variables

if (-not $result.Success) {
    $errorMsg = $result.Errors | ForEach-Object { $_.Message } | Select-Object -First 1
    Write-Log "GraphQL query failed: $errorMsg" -Level "Error"
    throw "Failed to fetch issue DAG: $errorMsg"
}

$rootIssueData = $result.Data.repository.issue

if (-not $rootIssueData) {
    Write-Log "Root issue #$RootIssue not found" -Level "Error"
    throw "Root issue #$RootIssue not found"
}

Write-Log "Successfully fetched DAG with root issue #$RootIssue"

# Function to parse blocking dependencies from issue body
function Get-BlockingDependencies {
    param([string]$Body)
    
    if (-not $Body) {
        return @()
    }
    
    $blockingIssues = @()
    
    # Match "Blocked by:" section with issue references
    # Expected format in issue body:
    #   Blocked by:
    #   - [ ] owner/repo#123 - Description
    #   - [x] #456 - Another issue
    # Pattern explanation:
    #   (?ms) - multiline and singleline mode
    #   Blocked by:\s*\n - Match "Blocked by:" followed by newline
    #   ((?:-\s*\[.\].*?\n?)+) - Capture checklist items (- [ ] or - [x])
    if ($Body -match '(?ms)Blocked by:\s*\n((?:-\s*\[.\].*?\n?)+)') {
        $blockSection = $Matches[1]
        
        # Extract all issue numbers from the blocked by section
        $issueMatches = [regex]::Matches($blockSection, '#(\d+)')
        foreach ($match in $issueMatches) {
            $issueNum = [int]$match.Groups[1].Value
            $blockingIssues += $issueNum
        }
    }
    
    return $blockingIssues
}

# Function to check if an issue has open blocking dependencies
function Test-HasOpenBlockingDependencies {
    param(
        [object]$Issue,
        [hashtable]$IssueMap
    )
    
    $blockingIssues = Get-BlockingDependencies -Body $Issue.body
    
    foreach ($blockingNum in $blockingIssues) {
        if ($IssueMap.ContainsKey($blockingNum)) {
            $blockingIssue = $IssueMap[$blockingNum]
            if ($blockingIssue.state -eq "OPEN") {
                Write-Verbose "Issue #$($Issue.number) blocked by open issue #$blockingNum"
                return $true
            }
        }
        else {
            # Blocking issue not in our DAG - need to check it separately
            Write-Verbose "Checking external blocking issue #$blockingNum for issue #$($Issue.number)"
            
            $checkQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      number
      state
    }
  }
}
"@
            
            $checkVars = @{
                owner = $owner
                repo = $repo
                number = $blockingNum
            }
            
            $checkResult = Invoke-GraphQLHelper -Query $checkQuery -Variables $checkVars
            
            if ($checkResult.Success -and $checkResult.Data.repository.issue) {
                $blockingState = $checkResult.Data.repository.issue.state
                if ($blockingState -eq "OPEN") {
                    Write-Verbose "Issue #$($Issue.number) blocked by external open issue #$blockingNum"
                    return $true
                }
            }
        }
    }
    
    return $false
}

# Build a flat map of all issues in the DAG for easy lookup
Write-Verbose "Building issue map..."
$issueMap = @{}

function Add-IssueToMap {
    param(
        [object]$Issue,
        [int]$Depth,
        [object]$Parent
    )
    
    if (-not $Issue) { return }
    
    # Create normalized issue object
    $normalizedIssue = [PSCustomObject]@{
        Number = $Issue.number
        Title = $Issue.title
        State = $Issue.state
        Url = $Issue.url
        Body = $Issue.body
        Type = if ($Issue.issueType) { $Issue.issueType.name } else { $null }
        Labels = if ($Issue.labels -and $Issue.labels.nodes) { 
            @($Issue.labels.nodes | ForEach-Object { $_.name })
        } else { 
            @() 
        }
        Assignees = if ($Issue.assignees -and $Issue.assignees.nodes) { 
            @($Issue.assignees.nodes | ForEach-Object { $_.login })
        } else { 
            @() 
        }
        Children = @()
        Parent = $Parent
        Depth = $Depth
    }
    
    $issueMap[$Issue.number] = $normalizedIssue
    
    # Recursively process children
    if ($Issue.trackedIssues -and $Issue.trackedIssues.nodes) {
        foreach ($child in $Issue.trackedIssues.nodes) {
            $normalizedIssue.Children += $child.number
            Add-IssueToMap -Issue $child -Depth ($Depth + 1) -Parent $normalizedIssue
        }
    }
}

Add-IssueToMap -Issue $rootIssueData -Depth 0 -Parent $null

Write-Log "Built issue map with $($issueMap.Count) issues"

# Find ready issues - leaf nodes with no blocking dependencies
Write-Verbose "Finding ready issues..."
$readyIssues = @()

foreach ($issueNum in $issueMap.Keys) {
    $issue = $issueMap[$issueNum]
    
    # Skip if this is the root issue
    if ($issue.Number -eq $RootIssue) {
        continue
    }
    
    # Must be a leaf node (no children)
    if ($issue.Children.Count -gt 0) {
        Write-Verbose "Issue #$issueNum has children, skipping"
        continue
    }
    
    # Must be open
    if ($issue.State -ne "OPEN") {
        Write-Verbose "Issue #$issueNum is not open, skipping"
        continue
    }
    
    # Parent must be open (if there is a parent)
    if ($issue.Parent -and $issue.Parent.State -ne "OPEN") {
        Write-Verbose "Issue #$issueNum has closed parent, skipping"
        continue
    }
    
    # Must not have open blocking dependencies
    if (Test-HasOpenBlockingDependencies -Issue $issue -IssueMap $issueMap) {
        continue
    }
    
    # Apply filters
    
    # Filter by assignee
    if (-not $IncludeAssigned) {
        if ($issue.Assignees.Count -gt 0) {
            Write-Verbose "Issue #$issueNum is assigned, skipping"
            continue
        }
    }
    
    if ($Assignee) {
        if ($Assignee -eq "none") {
            if ($issue.Assignees.Count -gt 0) {
                Write-Verbose "Issue #$issueNum is assigned (filter: none), skipping"
                continue
            }
        }
        else {
            if ($issue.Assignees -notcontains $Assignee) {
                Write-Verbose "Issue #$issueNum not assigned to $Assignee, skipping"
                continue
            }
        }
    }
    
    # Filter by labels (must have ALL specified labels)
    if ($Labels.Count -gt 0) {
        $hasAllLabels = $true
        foreach ($requiredLabel in $Labels) {
            if ($issue.Labels -notcontains $requiredLabel) {
                $hasAllLabels = $false
                break
            }
        }
        
        if (-not $hasAllLabels) {
            Write-Verbose "Issue #$issueNum missing required labels, skipping"
            continue
        }
    }
    
    # Filter by issue type
    if ($IssueType -and $issue.Type -ne $IssueType) {
        Write-Verbose "Issue #$issueNum type '$($issue.Type)' doesn't match filter '$IssueType', skipping"
        continue
    }
    
    # This issue is ready!
    Write-Verbose "Issue #$issueNum is ready"
    $readyIssues += $issue
}

Write-Log "Found $($readyIssues.Count) ready issues"

# Sort the results
switch ($SortBy) {
    "number" {
        $readyIssues = $readyIssues | Sort-Object Number
    }
    "title" {
        $readyIssues = $readyIssues | Sort-Object Title
    }
    "priority" {
        # Priority sort: by depth (shallower first), then by number (lower first)
        $readyIssues = $readyIssues | Sort-Object Depth, Number
    }
}

# Return the results
return $readyIssues
