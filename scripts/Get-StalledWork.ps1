<#
.SYNOPSIS
    Find stale issues that have been open too long with no activity.

.DESCRIPTION
    Get-StalledWork.ps1 queries open issues in a repository and identifies
    those that have been stale (no updates) beyond a configured threshold.
    Returns issues sorted by staleness (longest stale first).

.PARAMETER DaysStale
    Number of days without activity to consider an issue stale. Default is 30.

.PARAMETER DryRun
    If specified, logs the query without executing it against the API.

.OUTPUTS
    Returns an array of PSCustomObject with stalled issues:
    - Number: Issue number
    - Title: Issue title
    - IssueType: Type of the issue (e.g., Epic, Feature, Task, Bug)
    - State: Issue state (should be OPEN)
    - Url: Issue URL
    - UpdatedAt: Last update timestamp
    - DaysSinceUpdate: Days since last update
    - CreatedAt: Creation timestamp

.EXAMPLE
    PS> .\Get-StalledWork.ps1
    Finds all open issues stale for more than 30 days.

.EXAMPLE
    PS> .\Get-StalledWork.ps1 -DaysStale 14
    Finds issues stale for more than 14 days.

.EXAMPLE
    PS> .\Get-StalledWork.ps1 -DryRun
    Shows the query that would be executed without running it.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Dependencies:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$DaysStale = 30,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for tracking
$correlationId = [guid]::NewGuid().ToString()

# Get script directory for relative paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [switch]$DryRun,
        [string]$CorrelationId
    )
    
    $invokeGraphQLPath = Join-Path $scriptDir "Invoke-GraphQL.ps1"
    
    $params = @{
        Query = $Query
        Variables = $Variables
        CorrelationId = $CorrelationId
    }
    
    if ($DryRun) {
        $params.DryRun = $true
    }
    
    return & $invokeGraphQLPath @params
}

# Helper function to call Write-OkyeremaLog.ps1
function Write-OkyeremaLogHelper {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "",
        [string]$CorrelationId = ""
    )
    
    $writeLogPath = Join-Path (Split-Path $scriptDir -Parent) ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    
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
    
    & $writeLogPath @params
}

# Helper function to call Get-RepoContext.ps1
function Get-RepoContextHelper {
    $getRepoContextPath = Join-Path $scriptDir "Get-RepoContext.ps1"
    return & $getRepoContextPath
}

# Main execution
Write-OkyeremaLogHelper -Message "Starting stalled work search (threshold: $DaysStale days)" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId

# Get repository context
try {
    Write-OkyeremaLogHelper -Message "Fetching repository context" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId
    $repoContext = Get-RepoContextHelper
    
    if (-not $repoContext.RepoId) {
        Write-OkyeremaLogHelper -Message "Failed to get repository context" -Level "Error" -Operation "GetStalledWork" -CorrelationId $correlationId
        throw "Could not retrieve repository context"
    }
}
catch {
    Write-OkyeremaLogHelper -Message "Error getting repository context: $_" -Level "Error" -Operation "GetStalledWork" -CorrelationId $correlationId
    throw
}

# Extract owner and repo from gh cli
try {
    $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
    $parts = $repoInfo.nameWithOwner.Split('/')
    $owner = $parts[0]
    $repo = $parts[1]
    Write-OkyeremaLogHelper -Message "Repository: $owner/$repo" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId
}
catch {
    Write-OkyeremaLogHelper -Message "Error getting repository info: $_" -Level "Error" -Operation "GetStalledWork" -CorrelationId $correlationId
    throw
}

# Calculate cutoff date
$cutoffDate = (Get-Date).AddDays(-$DaysStale).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
Write-OkyeremaLogHelper -Message "Cutoff date: $cutoffDate" -Level "Debug" -Operation "GetStalledWork" -CorrelationId $correlationId

# Build GraphQL query to fetch open issues with update timestamps
# Note: GitHub GraphQL API doesn't support date filtering directly,
# so we fetch all open issues and filter client-side
$query = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, filterBy: { states: OPEN }, orderBy: { field: UPDATED_AT, direction: ASC }) {
      nodes {
        id
        number
        title
        url
        state
        updatedAt
        createdAt
        issueType {
          id
          name
        }
      }
    }
  }
}
"@

$variables = @{
    owner = $owner
    repo = $repo
}

Write-OkyeremaLogHelper -Message "Querying for open issues" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId

# Execute the query
$result = Invoke-GraphQLHelper -Query $query -Variables $variables -DryRun:$DryRun -CorrelationId $correlationId

if ($DryRun) {
    Write-OkyeremaLogHelper -Message "DryRun mode - query not executed" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId
    return $result
}

if (-not $result.Success) {
    Write-OkyeremaLogHelper -Message "GraphQL query failed" -Level "Error" -Operation "GetStalledWork" -CorrelationId $correlationId
    foreach ($error in $result.Errors) {
        Write-OkyeremaLogHelper -Message "Error: $($error.Message)" -Level "Error" -Operation "GetStalledWork" -CorrelationId $correlationId
    }
    throw "Failed to query issues"
}

$issues = $result.Data.repository.issues.nodes
Write-OkyeremaLogHelper -Message "Found $($issues.Count) open issues" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId

# Filter to stalled issues (updated before cutoff date)
$cutoffDateTime = [DateTime]::Parse($cutoffDate)
$stalledIssues = @($issues | Where-Object {
    $updatedAt = [DateTime]::Parse($_.updatedAt)
    $updatedAt -lt $cutoffDateTime
})

Write-OkyeremaLogHelper -Message "Found $($stalledIssues.Count) stalled issues (> $DaysStale days)" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId

# Build output with calculated days since update
$output = @()
$now = Get-Date
foreach ($issue in $stalledIssues) {
    $updatedAt = [DateTime]::Parse($issue.updatedAt)
    $daysSinceUpdate = [math]::Floor(($now - $updatedAt).TotalDays)
    
    $output += [PSCustomObject]@{
        Number = $issue.number
        Title = $issue.title
        IssueType = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
        State = $issue.state
        Url = $issue.url
        UpdatedAt = $issue.updatedAt
        DaysSinceUpdate = $daysSinceUpdate
        CreatedAt = $issue.createdAt
    }
}

# Sort by days since update (most stale first)
$output = $output | Sort-Object -Property DaysSinceUpdate -Descending

if ($output.Count -eq 0) {
    Write-Host "`nNo stalled issues found! 🎉" -ForegroundColor Green
}
else {
    Write-Host "`nFound $($output.Count) stalled issue(s):" -ForegroundColor Yellow
    foreach ($item in $output) {
        Write-Host "  #$($item.Number): $($item.Title) [$($item.IssueType)] - $($item.DaysSinceUpdate) days stale" -ForegroundColor Gray
    }
}

Write-OkyeremaLogHelper -Message "Stalled work search completed" -Level "Info" -Operation "GetStalledWork" -CorrelationId $correlationId

return $output
