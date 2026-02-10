<#
.SYNOPSIS
    Validate the integrity of the issue DAG (Directed Acyclic Graph).

.DESCRIPTION
    Invoke-DagHealthCheck.ps1 performs comprehensive validation of the issue hierarchy,
    checking for:
    - Cycles (circular dependencies that should not exist)
    - Orphaned issues (not connected to any Epic/Feature hierarchy)
    - Issues with wrong types (e.g., Task tracking other Tasks)
    - Stale issues (open too long with no activity)
    - Epics without children
    
    Outputs a health report with warnings and errors categorized by severity.

.PARAMETER RootIssueNumber
    Optional root issue number to start validation from. If not provided, validates
    all open issues in the repository.

.PARAMETER DaysStale
    Number of days without activity to consider an issue stale. Default is 30.

.PARAMETER Format
    Output format. Valid values: Console (default), JSON, Markdown.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    .\Invoke-DagHealthCheck.ps1
    Performs full health check on all open issues.

.EXAMPLE
    .\Invoke-DagHealthCheck.ps1 -RootIssueNumber 14
    Validates the hierarchy starting from issue #14.

.EXAMPLE
    .\Invoke-DagHealthCheck.ps1 -DaysStale 14 -Format JSON
    Checks for issues stale for more than 14 days, outputs as JSON.

.OUTPUTS
    Health report with:
    - Errors: Critical issues (cycles, invalid hierarchies)
    - Warnings: Non-critical issues (orphans, stale issues, childless epics)
    - Summary: Overall health status

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Requires PowerShell 7.x or higher.
    
    Dependencies:
    - Get-DagStatus.ps1
    - Get-OrphanedIssues.ps1
    - Get-StalledWork.ps1
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$RootIssueNumber,

    [Parameter(Mandatory = $false)]
    [int]$DaysStale = 30,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "JSON", "Markdown")]
    [string]$Format = "Console",

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Import dependencies
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir/Invoke-GraphQL.ps1"
. "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

Write-OkyeremaLog -Message "Starting DAG health check" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Get repository context
try {
    $repoContext = & "$scriptDir/Get-RepoContext.ps1"
    Write-OkyeremaLog -Message "Repository context retrieved" -Level Debug -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to get repository context: $_" -Level Error -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
    throw
}

# Get current repository info
try {
    $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
    $owner = $repoInfo.owner.login
    $repoName = $repoInfo.name
    Write-OkyeremaLog -Message "Repository: $owner/$repoName" -Level Debug -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to get repository info: $_" -Level Error -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
    throw
}

# Initialize health report
$healthReport = [PSCustomObject]@{
    Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    Repository = "$owner/$repoName"
    Errors = @()
    Warnings = @()
    Summary = [PSCustomObject]@{
        TotalIssues = 0
        ErrorCount = 0
        WarningCount = 0
        HealthStatus = "Unknown"
    }
}

# Function to add error
function Add-Error {
    param(
        [string]$Category,
        [string]$Message,
        [int]$IssueNumber,
        [string]$IssueTitle = ""
    )
    
    $healthReport.Errors += [PSCustomObject]@{
        Category = $Category
        Message = $Message
        IssueNumber = $IssueNumber
        IssueTitle = $IssueTitle
    }
    $healthReport.Summary.ErrorCount++
}

# Function to add warning
function Add-Warning {
    param(
        [string]$Category,
        [string]$Message,
        [int]$IssueNumber,
        [string]$IssueTitle = ""
    )
    
    $healthReport.Warnings += [PSCustomObject]@{
        Category = $Category
        Message = $Message
        IssueNumber = $IssueNumber
        IssueTitle = $IssueTitle
    }
    $healthReport.Summary.WarningCount++
}

# Function to fetch all open issues with hierarchy information
function Get-AllOpenIssues {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$CorrelationId
    )

    Write-OkyeremaLog -Message "Fetching all open issues" -Level Debug -Operation "Get-AllOpenIssues" -CorrelationId $CorrelationId

    $query = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        id
        number
        title
        state
        issueType {
          id
          name
        }
        subIssues(first: 100) {
          totalCount
          nodes {
            number
            issueType {
              name
            }
          }
        }
        parents(first: 100) {
          totalCount
        }
      }
    }
  }
}
"@

    $variables = @{
        owner = $Owner
        repo = $Repo
    }

    $headers = @{
        "GraphQL-Features" = "sub_issues"
    }

    $result = Invoke-GraphQL -Query $query -Variables $variables -Headers $headers -CorrelationId $CorrelationId

    if (-not $result.Success) {
        Write-OkyeremaLog -Message "Failed to fetch issues" -Level Error -Operation "Get-AllOpenIssues" -CorrelationId $CorrelationId
        throw "Failed to query issues: $($result.Errors)"
    }

    return $result.Data.repository.issues.nodes
}

# Check 1: Find cycles using Get-DagStatus.ps1
Write-OkyeremaLog -Message "Check 1: Detecting cycles" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Fetch all open issues
$allIssues = Get-AllOpenIssues -Owner $owner -Repo $repoName -CorrelationId $CorrelationId
$healthReport.Summary.TotalIssues = $allIssues.Count
Write-OkyeremaLog -Message "Found $($allIssues.Count) open issues" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Track visited issues globally to detect cycles across the entire graph
$globalVisited = @{}
$cyclesDetected = @()

function Check-CyclesInHierarchy {
    param(
        [int]$IssueNumber,
        [hashtable]$Visited,
        [System.Collections.Generic.List[int]]$Path,
        [string]$Owner,
        [string]$Repo,
        [string]$CorrelationId
    )

    # Check if we're in the current path (cycle detected)
    if ($Path.Contains($IssueNumber)) {
        $cycleStart = $Path.IndexOf($IssueNumber)
        $cycleNodes = $Path[$cycleStart..($Path.Count - 1)] + @($IssueNumber)
        $cycleString = ($cycleNodes -join " → ")
        
        Write-OkyeremaLog -Message "Cycle detected: $cycleString" -Level Warn -Operation "Check-CyclesInHierarchy" -CorrelationId $CorrelationId
        
        # Only add if we haven't seen this cycle before
        $cycleKey = ($cycleNodes | Sort-Object) -join ","
        if (-not $script:cyclesDetected.Contains($cycleKey)) {
            $script:cyclesDetected += $cycleKey
            Add-Error -Category "Cycle" -Message "Circular dependency detected: $cycleString" -IssueNumber $IssueNumber
        }
        return
    }

    # Check if already visited globally
    if ($Visited.ContainsKey($IssueNumber)) {
        return
    }

    # Mark as visited
    $Visited[$IssueNumber] = $true
    $Path.Add($IssueNumber) | Out-Null

    # Get the issue's children
    $issue = $allIssues | Where-Object { $_.number -eq $IssueNumber }
    if ($issue -and $issue.subIssues.totalCount -gt 0) {
        foreach ($child in $issue.subIssues.nodes) {
            Check-CyclesInHierarchy -IssueNumber $child.number -Visited $Visited -Path $Path -Owner $Owner -Repo $Repo -CorrelationId $CorrelationId
        }
    }

    # Remove from path (backtrack)
    $Path.RemoveAt($Path.Count - 1) | Out-Null
}

# Check each issue as a potential root
foreach ($issue in $allIssues) {
    if (-not $globalVisited.ContainsKey($issue.number)) {
        $path = New-Object System.Collections.Generic.List[int]
        Check-CyclesInHierarchy -IssueNumber $issue.number -Visited $globalVisited -Path $path -Owner $owner -Repo $repoName -CorrelationId $CorrelationId
    }
}

Write-OkyeremaLog -Message "Cycle detection completed. Found $($healthReport.Errors.Count) cycles" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Check 2: Find orphaned issues
Write-OkyeremaLog -Message "Check 2: Finding orphaned issues" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

try {
    $orphanedIssues = & "$scriptDir/Get-OrphanedIssues.ps1"
    
    foreach ($orphan in $orphanedIssues) {
        $suggestedParent = if ($orphan.SuggestedParent) { " (suggested parent: #$($orphan.SuggestedParent.Number))" } else { "" }
        Add-Warning -Category "Orphaned" -Message "Issue is not connected to any Epic/Feature hierarchy$suggestedParent" -IssueNumber $orphan.Number -IssueTitle $orphan.Title
    }
    
    Write-OkyeremaLog -Message "Found $($orphanedIssues.Count) orphaned issues" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to check for orphaned issues: $_" -Level Warn -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
}

# Check 3: Validate issue type hierarchies
Write-OkyeremaLog -Message "Check 3: Validating issue type hierarchies" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Valid parent-child type relationships
# Epic → Feature, Epic → Task, Epic → Bug
# Feature → Task, Feature → Bug
# Task → Bug
# Bug → (none, bugs are leaf nodes)
$validRelationships = @{
    "Epic" = @("Feature", "Task", "Bug")
    "Feature" = @("Task", "Bug")
    "Task" = @("Bug")
    "Bug" = @()
}

foreach ($issue in $allIssues) {
    $parentType = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
    
    # Check if parent type is valid
    if ($parentType -eq "Unknown") {
        Add-Error -Category "InvalidType" -Message "Issue has no type assigned" -IssueNumber $issue.number -IssueTitle $issue.title
        continue
    }
    
    # Check each child
    if ($issue.subIssues.totalCount -gt 0) {
        foreach ($child in $issue.subIssues.nodes) {
            $childType = if ($child.issueType) { $child.issueType.name } else { "Unknown" }
            
            if ($childType -eq "Unknown") {
                Add-Error -Category "InvalidType" -Message "$parentType #$($issue.number) tracks issue #$($child.number) with no type" -IssueNumber $child.number
                continue
            }
            
            # Check if this parent-child relationship is valid
            if (-not $validRelationships.ContainsKey($parentType)) {
                Add-Error -Category "InvalidHierarchy" -Message "Unknown parent type '$parentType' for issue #$($issue.number)" -IssueNumber $issue.number -IssueTitle $issue.title
            }
            elseif ($childType -notin $validRelationships[$parentType]) {
                Add-Error -Category "InvalidHierarchy" -Message "$parentType #$($issue.number) incorrectly tracks $childType #$($child.number)" -IssueNumber $issue.number -IssueTitle $issue.title
            }
        }
    }
}

Write-OkyeremaLog -Message "Issue type validation completed" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Check 4: Find stale issues
Write-OkyeremaLog -Message "Check 4: Finding stale issues" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

try {
    $stalledIssues = & "$scriptDir/Get-StalledWork.ps1" -DaysStale $DaysStale
    
    foreach ($stalled in $stalledIssues) {
        Add-Warning -Category "Stale" -Message "Issue has been open with no activity for $($stalled.DaysSinceUpdate) days" -IssueNumber $stalled.Number -IssueTitle $stalled.Title
    }
    
    Write-OkyeremaLog -Message "Found $($stalledIssues.Count) stale issues" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to check for stale issues: $_" -Level Warn -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId
}

# Check 5: Verify all Epics have at least one child
Write-OkyeremaLog -Message "Check 5: Verifying Epics have children" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

$epics = $allIssues | Where-Object { $_.issueType.name -eq "Epic" }
foreach ($epic in $epics) {
    if ($epic.subIssues.totalCount -eq 0) {
        Add-Warning -Category "ChildlessEpic" -Message "Epic has no child issues" -IssueNumber $epic.number -IssueTitle $epic.title
    }
}

Write-OkyeremaLog -Message "Epic validation completed. Found $($epics.Count) epics" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Determine overall health status
if ($healthReport.Summary.ErrorCount -gt 0) {
    $healthReport.Summary.HealthStatus = "Critical"
}
elseif ($healthReport.Summary.WarningCount -gt 10) {
    $healthReport.Summary.HealthStatus = "Poor"
}
elseif ($healthReport.Summary.WarningCount -gt 0) {
    $healthReport.Summary.HealthStatus = "Fair"
}
else {
    $healthReport.Summary.HealthStatus = "Healthy"
}

Write-OkyeremaLog -Message "Health check completed. Status: $($healthReport.Summary.HealthStatus)" -Level Info -Operation "Invoke-DagHealthCheck" -CorrelationId $CorrelationId

# Output based on format
switch ($Format) {
    "JSON" {
        $healthReport | ConvertTo-Json -Depth 10
    }
    "Markdown" {
        Write-Output "# DAG Health Report"
        Write-Output ""
        Write-Output "**Repository:** $($healthReport.Repository)"
        Write-Output "**Timestamp:** $($healthReport.Timestamp)"
        Write-Output "**Status:** $($healthReport.Summary.HealthStatus)"
        Write-Output ""
        Write-Output "## Summary"
        Write-Output "- Total Issues: $($healthReport.Summary.TotalIssues)"
        Write-Output "- Errors: $($healthReport.Summary.ErrorCount)"
        Write-Output "- Warnings: $($healthReport.Summary.WarningCount)"
        Write-Output ""
        
        if ($healthReport.Errors.Count -gt 0) {
            Write-Output "## Errors (Critical)"
            Write-Output ""
            foreach ($error in $healthReport.Errors) {
                Write-Output "### [$($error.Category)] Issue #$($error.IssueNumber)"
                if ($error.IssueTitle) {
                    Write-Output "**Title:** $($error.IssueTitle)"
                }
                Write-Output "**Problem:** $($error.Message)"
                Write-Output ""
            }
        }
        
        if ($healthReport.Warnings.Count -gt 0) {
            Write-Output "## Warnings"
            Write-Output ""
            foreach ($warning in $healthReport.Warnings) {
                Write-Output "### [$($warning.Category)] Issue #$($warning.IssueNumber)"
                if ($warning.IssueTitle) {
                    Write-Output "**Title:** $($warning.IssueTitle)"
                }
                Write-Output "**Problem:** $($warning.Message)"
                Write-Output ""
            }
        }
        
        if ($healthReport.Errors.Count -eq 0 -and $healthReport.Warnings.Count -eq 0) {
            Write-Output "🎉 No issues found! The DAG is healthy."
        }
    }
    default { # Console
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  DAG Health Report" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Repository:  " -NoNewline -ForegroundColor Gray
        Write-Host $healthReport.Repository -ForegroundColor White
        Write-Host "Timestamp:   " -NoNewline -ForegroundColor Gray
        Write-Host $healthReport.Timestamp -ForegroundColor White
        Write-Host "Status:      " -NoNewline -ForegroundColor Gray
        
        $statusColor = switch ($healthReport.Summary.HealthStatus) {
            "Healthy" { "Green" }
            "Fair" { "Yellow" }
            "Poor" { "DarkYellow" }
            "Critical" { "Red" }
            default { "White" }
        }
        Write-Host $healthReport.Summary.HealthStatus -ForegroundColor $statusColor
        
        Write-Host ""
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "Summary" -ForegroundColor White
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "Total Issues: $($healthReport.Summary.TotalIssues)" -ForegroundColor Gray
        Write-Host "Errors:       " -NoNewline -ForegroundColor Gray
        if ($healthReport.Summary.ErrorCount -gt 0) {
            Write-Host $healthReport.Summary.ErrorCount -ForegroundColor Red
        } else {
            Write-Host "0" -ForegroundColor Green
        }
        Write-Host "Warnings:     " -NoNewline -ForegroundColor Gray
        if ($healthReport.Summary.WarningCount -gt 0) {
            Write-Host $healthReport.Summary.WarningCount -ForegroundColor Yellow
        } else {
            Write-Host "0" -ForegroundColor Green
        }
        
        if ($healthReport.Errors.Count -gt 0) {
            Write-Host ""
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "Errors (Critical)" -ForegroundColor Red
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
            
            foreach ($error in $healthReport.Errors) {
                Write-Host ""
                Write-Host "  [$($error.Category)] " -NoNewline -ForegroundColor Red
                Write-Host "Issue #$($error.IssueNumber)" -ForegroundColor White
                if ($error.IssueTitle) {
                    Write-Host "  Title: " -NoNewline -ForegroundColor Gray
                    Write-Host $error.IssueTitle -ForegroundColor White
                }
                Write-Host "  Problem: " -NoNewline -ForegroundColor Gray
                Write-Host $error.Message -ForegroundColor White
            }
        }
        
        if ($healthReport.Warnings.Count -gt 0) {
            Write-Host ""
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "Warnings" -ForegroundColor Yellow
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
            
            foreach ($warning in $healthReport.Warnings) {
                Write-Host ""
                Write-Host "  [$($warning.Category)] " -NoNewline -ForegroundColor Yellow
                Write-Host "Issue #$($warning.IssueNumber)" -ForegroundColor White
                if ($warning.IssueTitle) {
                    Write-Host "  Title: " -NoNewline -ForegroundColor Gray
                    Write-Host $warning.IssueTitle -ForegroundColor White
                }
                Write-Host "  Problem: " -NoNewline -ForegroundColor Gray
                Write-Host $warning.Message -ForegroundColor White
            }
        }
        
        if ($healthReport.Errors.Count -eq 0 -and $healthReport.Warnings.Count -eq 0) {
            Write-Host ""
            Write-Host "🎉 No issues found! The DAG is healthy." -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    }
}

# Return the health report object for pipeline use
return $healthReport
