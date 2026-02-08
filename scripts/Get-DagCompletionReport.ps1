<#
.SYNOPSIS
    Generate a summary report of DAG progress suitable for status updates.

.DESCRIPTION
    Get-DagCompletionReport.ps1 queries GitHub issues to generate a comprehensive
    progress report for a Directed Acyclic Graph (DAG) of work items. The report
    includes:
    - Per-phase breakdown (by Epic)
    - Per-feature breakdown (by Feature under Epic)
    - Burndown data (closed over time)
    - Multiple output formats: Console, Markdown table, or JSON

.PARAMETER RootIssueNumber
    The issue number of the root Epic to analyze. The script will traverse the
    entire hierarchy from this root issue.

.PARAMETER OutputFormat
    The output format for the report. Valid values: Console, Markdown, Json.
    Default is Console.

.PARAMETER IncludeBurndown
    If specified, includes burndown data showing when issues were closed over time.

.PARAMETER DryRun
    If specified, logs the GraphQL queries without executing them.

.EXAMPLE
    .\Get-DagCompletionReport.ps1 -RootIssueNumber 1
    Generates a console report for the DAG rooted at issue #1.

.EXAMPLE
    .\Get-DagCompletionReport.ps1 -RootIssueNumber 1 -OutputFormat Markdown
    Generates a Markdown table report for the DAG rooted at issue #1.

.EXAMPLE
    .\Get-DagCompletionReport.ps1 -RootIssueNumber 1 -OutputFormat Json -IncludeBurndown
    Generates a JSON report with burndown data for the DAG rooted at issue #1.

.OUTPUTS
    Outputs the report to stdout in the specified format:
    - Console: Formatted text with colors and progress bars
    - Markdown: GitHub-flavored markdown tables
    - Json: Structured JSON object

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Depends on:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1 (in .github/skills/okyerema/scripts/)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$RootIssueNumber,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeBurndown,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for this operation
$correlationId = [guid]::NewGuid().ToString()

# Determine script paths
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$invokeGraphQLPath = Join-Path $scriptRoot "Invoke-GraphQL.ps1"
$getRepoContextPath = Join-Path $scriptRoot "Get-RepoContext.ps1"
$writeLogPath = Join-Path (Split-Path -Parent $scriptRoot) ".github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [switch]$DryRun
    )
    
    $params = @{
        Query = $Query
        Variables = $Variables
        CorrelationId = $correlationId
    }
    
    if ($DryRun) {
        $params.DryRun = $true
    }
    
    & $invokeGraphQLPath @params
}

# Helper function to call Write-OkyeremaLog.ps1
function Write-OkyeremaLogHelper {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "GetDagCompletionReport"
    )
    
    & $writeLogPath -Message $Message -Level $Level -Operation $Operation -CorrelationId $correlationId
}

# Function to get repository context
function Get-RepoContextHelper {
    & $getRepoContextPath
}

# Function to fetch issue hierarchy recursively
function Get-IssueHierarchy {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number,
        [int]$Level = 0,
        [hashtable]$Visited = @{}
    )
    
    # Prevent infinite loops
    if ($Visited.ContainsKey($Number)) {
        return $null
    }
    $Visited[$Number] = $true
    
    Write-OkyeremaLogHelper -Message "Fetching issue #$Number at level $Level" -Level "Debug"
    
    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $Number) {
      id
      number
      title
      state
      createdAt
      closedAt
      issueType { name }
      trackedIssues(first: 100) {
        totalCount
        nodes {
          id
          number
          title
          state
          createdAt
          closedAt
          issueType { name }
        }
      }
    }
  }
}
"@
    
    $result = Invoke-GraphQLHelper -Query $query -DryRun:$DryRun
    
    if (-not $result.Success) {
        Write-OkyeremaLogHelper -Message "Failed to fetch issue #$Number : $($result.Errors[0].Message)" -Level "Error"
        return $null
    }
    
    $issue = $result.Data.repository.issue
    
    # Create issue object
    $issueObj = [PSCustomObject]@{
        Number = $issue.number
        Title = $issue.title
        State = $issue.state
        Type = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
        CreatedAt = $issue.createdAt
        ClosedAt = $issue.closedAt
        Level = $Level
        Children = [System.Collections.Generic.List[object]]::new()
        TotalCount = $issue.trackedIssues.totalCount
        ClosedCount = 0
        OpenCount = 0
    }
    
    # Recursively fetch children
    if ($issue.trackedIssues.nodes) {
        foreach ($child in $issue.trackedIssues.nodes) {
            $childObj = Get-IssueHierarchy -Owner $Owner -Repo $Repo -Number $child.number -Level ($Level + 1) -Visited $Visited
            if ($childObj) {
                $issueObj.Children.Add($childObj) | Out-Null
                
                # Update counts
                if ($child.state -eq "CLOSED") {
                    $issueObj.ClosedCount++
                } else {
                    $issueObj.OpenCount++
                }
            }
        }
    }
    
    return $issueObj
}

# Function to calculate statistics for each Epic
function Get-EpicStatistics {
    param([object]$Epic)
    
    $stats = @{
        Epic = $Epic.Title
        EpicNumber = $Epic.Number
        EpicState = $Epic.State
        Features = [System.Collections.Generic.List[object]]::new()
        TotalTasks = 0
        CompletedTasks = 0
        TotalFeatures = 0
        CompletedFeatures = 0
    }
    
    foreach ($feature in $Epic.Children) {
        $featureStats = @{
            Feature = $feature.Title
            FeatureNumber = $feature.Number
            FeatureState = $feature.State
            TotalTasks = $feature.TotalCount
            CompletedTasks = $feature.ClosedCount
            Progress = 0
        }
        
        if ($feature.TotalCount -gt 0) {
            $featureStats.Progress = [math]::Round(($feature.ClosedCount / $feature.TotalCount) * 100, 2)
        }
        
        $stats.Features.Add($featureStats) | Out-Null
        $stats.TotalTasks += $feature.TotalCount
        $stats.CompletedTasks += $feature.ClosedCount
        $stats.TotalFeatures++
        
        if ($feature.State -eq "CLOSED") {
            $stats.CompletedFeatures++
        }
    }
    
    $stats.Progress = 0
    if ($stats.TotalTasks -gt 0) {
        $stats.Progress = [math]::Round(($stats.CompletedTasks / $stats.TotalTasks) * 100, 2)
    }
    
    return $stats
}

# Function to collect burndown data
function Get-BurndownData {
    param([object]$Root)
    
    # Use ArrayList for better performance with large hierarchies
    $allIssues = [System.Collections.Generic.List[object]]::new()
    
    function Collect-Issues {
        param([object]$Issue)
        
        $allIssues.Add($Issue)
        
        foreach ($child in $Issue.Children) {
            Collect-Issues -Issue $child
        }
    }
    
    Collect-Issues -Issue $Root
    
    # Filter closed issues and group by date
    $closedIssues = $allIssues | Where-Object { $_.State -eq "CLOSED" -and $_.ClosedAt }
    
    $burndownData = $closedIssues | 
        Group-Object { ([DateTime]$_.ClosedAt).ToString("yyyy-MM-dd") } |
        Sort-Object Name |
        ForEach-Object {
            [PSCustomObject]@{
                Date = $_.Name
                Count = $_.Count
                Issues = $_.Group | ForEach-Object { "#$($_.Number)" }
            }
        }
    
    # Calculate cumulative closed count
    $cumulative = 0
    $burndownData | ForEach-Object {
        $cumulative += $_.Count
        $_ | Add-Member -MemberType NoteProperty -Name "Cumulative" -Value $cumulative
    }
    
    return $burndownData
}

# Function to output Console format
function Write-ConsoleReport {
    param(
        [object]$Root,
        [array]$EpicStats,
        [array]$BurndownData
    )
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  DAG COMPLETION REPORT" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Root: #$($Root.Number) - $($Root.Title)" -ForegroundColor Yellow
    Write-Host "Type: $($Root.Type)" -ForegroundColor Gray
    Write-Host ""
    
    foreach ($stat in $EpicStats) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
        
        $epicStateIcon = if ($stat.EpicState -eq "CLOSED") { "✓" } else { "○" }
        Write-Host "${epicStateIcon} Epic #$($stat.EpicNumber): $($stat.Epic)" -ForegroundColor Cyan
        Write-Host "   Progress: $($stat.CompletedTasks)/$($stat.TotalTasks) tasks ($($stat.Progress)%)" -ForegroundColor White
        Write-Host "   Features: $($stat.CompletedFeatures)/$($stat.TotalFeatures) completed" -ForegroundColor White
        
        # Progress bar
        $barWidth = 40
        $filled = [math]::Floor(($stat.Progress / 100) * $barWidth)
        $empty = $barWidth - $filled
        $bar = "[" + ("█" * $filled) + ("░" * $empty) + "]"
        Write-Host "   $bar" -ForegroundColor Green
        Write-Host ""
        
        if ($stat.Features.Count -gt 0) {
            Write-Host "   Features:" -ForegroundColor Gray
            foreach ($feature in $stat.Features) {
                $featureStateIcon = if ($feature.FeatureState -eq "CLOSED") { "✓" } else { "○" }
                $progressBar = ""
                if ($feature.TotalTasks -gt 0) {
                    $miniBarWidth = 20
                    $miniFilled = [math]::Floor(($feature.Progress / 100) * $miniBarWidth)
                    $miniEmpty = $miniBarWidth - $miniFilled
                    $progressBar = "[" + ("█" * $miniFilled) + ("░" * $miniEmpty) + "]"
                }
                
                Write-Host "     ${featureStateIcon} #$($feature.FeatureNumber): $($feature.Feature)" -ForegroundColor White
                Write-Host "        $($feature.CompletedTasks)/$($feature.TotalTasks) tasks ($($feature.Progress)%) $progressBar" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
    
    if ($BurndownData -and $BurndownData.Count -gt 0) {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
        Write-Host "BURNDOWN DATA" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($day in $BurndownData) {
            Write-Host "  $($day.Date): $($day.Count) closed (Total: $($day.Cumulative))" -ForegroundColor White
            Write-Host "    $($day.Issues -join ', ')" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# Function to output Markdown format
function Write-MarkdownReport {
    param(
        [object]$Root,
        [array]$EpicStats,
        [array]$BurndownData
    )
    
    Write-Output "# DAG Completion Report"
    Write-Output ""
    Write-Output "**Root:** #$($Root.Number) - $($Root.Title)"
    Write-Output ""
    Write-Output "## Phase Summary"
    Write-Output ""
    Write-Output "| Epic | Progress | Features | Tasks |"
    Write-Output "|------|----------|----------|-------|"
    
    foreach ($stat in $EpicStats) {
        $stateIcon = if ($stat.EpicState -eq "CLOSED") { "✅" } else { "⏳" }
        Write-Output "| $stateIcon #$($stat.EpicNumber) $($stat.Epic) | $($stat.Progress)% | $($stat.CompletedFeatures)/$($stat.TotalFeatures) | $($stat.CompletedTasks)/$($stat.TotalTasks) |"
    }
    
    Write-Output ""
    Write-Output "## Feature Breakdown"
    Write-Output ""
    
    foreach ($stat in $EpicStats) {
        Write-Output "### Epic: $($stat.Epic)"
        Write-Output ""
        Write-Output "| Feature | Progress | Tasks |"
        Write-Output "|---------|----------|-------|"
        
        foreach ($feature in $stat.Features) {
            $stateIcon = if ($feature.FeatureState -eq "CLOSED") { "✅" } else { "⏳" }
            Write-Output "| $stateIcon #$($feature.FeatureNumber) $($feature.Feature) | $($feature.Progress)% | $($feature.CompletedTasks)/$($feature.TotalTasks) |"
        }
        
        Write-Output ""
    }
    
    if ($BurndownData -and $BurndownData.Count -gt 0) {
        Write-Output "## Burndown Data"
        Write-Output ""
        Write-Output "| Date | Issues Closed | Cumulative | Issues |"
        Write-Output "|------|---------------|------------|--------|"
        
        foreach ($day in $BurndownData) {
            Write-Output "| $($day.Date) | $($day.Count) | $($day.Cumulative) | $($day.Issues -join ', ') |"
        }
        
        Write-Output ""
    }
}

# Function to output JSON format
function Write-JsonReport {
    param(
        [object]$Root,
        [array]$EpicStats,
        [array]$BurndownData
    )
    
    $report = [PSCustomObject]@{
        Root = [PSCustomObject]@{
            Number = $Root.Number
            Title = $Root.Title
            Type = $Root.Type
            State = $Root.State
        }
        Phases = $EpicStats
        Burndown = if ($BurndownData) { $BurndownData } else { @() }
        GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    }
    
    $report | ConvertTo-Json -Depth 10
}

# Main execution
Write-OkyeremaLogHelper -Message "Starting DAG completion report for issue #$RootIssueNumber" -Level "Info"

# Get repository context
Write-OkyeremaLogHelper -Message "Fetching repository context" -Level "Debug"
$repoContext = Get-RepoContextHelper

if (-not $repoContext) {
    Write-OkyeremaLogHelper -Message "Failed to get repository context" -Level "Error"
    throw "Failed to get repository context"
}

# Extract owner and repo from current repository
try {
    $repoInfo = gh repo view --json nameWithOwner 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-OkyeremaLogHelper -Message "Failed to get repository info: $repoInfo" -Level "Error"
        throw "GitHub CLI command failed. Ensure 'gh' is installed, authenticated, and run from a repository directory."
    }
    $repoInfoObj = $repoInfo | ConvertFrom-Json
    $parts = $repoInfoObj.nameWithOwner.Split('/')
    $owner = $parts[0]
    $repo = $parts[1]
    
    Write-OkyeremaLogHelper -Message "Repository: $owner/$repo" -Level "Debug"
}
catch {
    Write-OkyeremaLogHelper -Message "Failed to get repository context: $_" -Level "Error"
    throw "Failed to determine repository owner and name. Ensure you are running this from a repository directory and GitHub CLI is properly configured."
}

# Fetch the issue hierarchy
Write-OkyeremaLogHelper -Message "Fetching issue hierarchy starting from #$RootIssueNumber" -Level "Info"
$rootIssue = Get-IssueHierarchy -Owner $owner -Repo $repo -Number $RootIssueNumber

if (-not $rootIssue) {
    Write-OkyeremaLogHelper -Message "Failed to fetch root issue #$RootIssueNumber" -Level "Error"
    throw "Failed to fetch root issue #$RootIssueNumber"
}

Write-OkyeremaLogHelper -Message "Issue hierarchy fetched successfully" -Level "Info"

# Calculate statistics for each Epic (child of root)
Write-OkyeremaLogHelper -Message "Calculating statistics" -Level "Debug"
$epicStats = [System.Collections.Generic.List[object]]::new()

if ($rootIssue.Type -eq "Epic") {
    # If root is an Epic, treat it as a single phase
    $epicStats.Add((Get-EpicStatistics -Epic $rootIssue)) | Out-Null
} else {
    # If root has Epic children, process each Epic
    foreach ($epic in $rootIssue.Children) {
        if ($epic.Type -eq "Epic" -or $epic.Children.Count -gt 0) {
            $epicStats.Add((Get-EpicStatistics -Epic $epic)) | Out-Null
        }
    }
}

# Collect burndown data if requested
$burndownData = @()
if ($IncludeBurndown) {
    Write-OkyeremaLogHelper -Message "Collecting burndown data" -Level "Debug"
    $burndownData = Get-BurndownData -Root $rootIssue
}

Write-OkyeremaLogHelper -Message "Generating report in $OutputFormat format" -Level "Info"

# Output the report in the requested format
switch ($OutputFormat) {
    "Console" {
        Write-ConsoleReport -Root $rootIssue -EpicStats $epicStats -BurndownData $burndownData
    }
    "Markdown" {
        Write-MarkdownReport -Root $rootIssue -EpicStats $epicStats -BurndownData $burndownData
    }
    "Json" {
        Write-JsonReport -Root $rootIssue -EpicStats $epicStats -BurndownData $burndownData
    }
}

Write-OkyeremaLogHelper -Message "Report generation completed" -Level "Info"
