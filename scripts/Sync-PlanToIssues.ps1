<#
.SYNOPSIS
    Diff current GitHub issues against the planning directory and identify drift.

.DESCRIPTION
    Sync-PlanToIssues.ps1 compares the current state of GitHub issues with the planning
    markdown files to identify drift between the two. It reports:
    - New tasks in plan not yet created as issues
    - Issues that are closed but plan still shows as pending
    - Issues that exist but don't match any plan file
    
    Can optionally create missing issues to bring GitHub in sync with the plan.
    
    This script relies on:
    - Get-DagStatus.ps1 for querying the issue DAG via GitHub relationships
    - Import-PlanToIssues.ps1 parsing patterns for understanding plan structure

.PARAMETER PlanDirectory
    Path to the planning directory containing phase-*/ subdirectories.
    Defaults to ./planning relative to repository root.

.PARAMETER Format
    Output format for drift report. Valid values: Console, JSON, CSV.
    Default is Console.

.PARAMETER CreateMissing
    If specified, automatically creates GitHub issues for tasks found in the plan
    but not yet created as issues.

.PARAMETER DryRun
    If specified, shows what would be done without making any changes.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Sync-PlanToIssues.ps1
    Analyzes drift between planning files and GitHub issues with console output.

.EXAMPLE
    ./Sync-PlanToIssues.ps1 -Format JSON
    Outputs drift analysis as JSON for automation consumption.

.EXAMPLE
    ./Sync-PlanToIssues.ps1 -CreateMissing
    Creates GitHub issues for any tasks found in plan files but not yet created.

.EXAMPLE
    ./Sync-PlanToIssues.ps1 -PlanDirectory ./planning -DryRun
    Shows what would be synced without making changes.

.OUTPUTS
    Console format: Formatted text report to stdout
    JSON format: JSON object to stdout
    CSV format: CSV data to stdout
    
    Structured logs are written to stderr via Write-OkyeremaLog.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Requires PowerShell 7.x or higher.
    
    Dependencies:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
    - Import-PlanToIssues.ps1 (for parsing patterns)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PlanDirectory = "./planning",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "JSON", "CSV")]
    [string]$Format = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$CreateMissing,

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

# Import dependencies
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper function to call Invoke-GraphQL.ps1
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
    & "$scriptDir/Invoke-GraphQL.ps1" @params
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
    & "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1" @params
}

Write-OkyeremaLogHelper -Message "Starting plan-to-issues sync" -Level Info -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId

# Get repository context
try {
    $repoContext = & "$scriptDir/Get-RepoContext.ps1"
    Write-OkyeremaLogHelper -Message "Repository context retrieved" -Level Debug -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLogHelper -Message "Failed to get repository context: $_" -Level Error -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
    throw
}

# Get current repository info
try {
    $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
    $owner = $repoInfo.owner.login
    $repoName = $repoInfo.name
    Write-OkyeremaLogHelper -Message "Repository: $owner/$repoName" -Level Debug -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLogHelper -Message "Failed to get repository info: $_" -Level Error -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
    throw
}

#region Helper Functions

function Parse-PlanMarkdown {
    <#
    .SYNOPSIS
        Parse a planning markdown file to extract metadata and tasks.
    .DESCRIPTION
        This is adapted from Import-PlanToIssues.ps1 parsing logic.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-OkyeremaLogHelper -Message "Parsing markdown file: $FilePath" -Level Debug -Operation "Parse-PlanMarkdown" -CorrelationId $CorrelationId

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    $content = Get-Content -Path $FilePath -Raw

    # Initialize result object
    $plan = @{
        FilePath = $FilePath
        FileName = Split-Path -Leaf $FilePath
        Title = ""
        ID = ""
        Phase = ""
        Status = ""
        Dependencies = @()
        Tasks = @()
    }

    # Parse title (first line starting with #)
    $titleMatch = $content -match '(?m)^#\s+(.+)$'
    if ($titleMatch) {
        $plan.Title = $Matches[1].Trim()
    }

    # Parse metadata
    if ($content -match '\*\*ID:\*\*\s*(.+)') {
        $plan.ID = $Matches[1].Trim()
    }

    if ($content -match '\*\*Phase:\*\*\s*(.+)') {
        $plan.Phase = $Matches[1].Trim()
    }

    if ($content -match '\*\*Status:\*\*\s*(.+)') {
        $plan.Status = $Matches[1].Trim()
    }

    if ($content -match '\*\*Dependencies:\*\*\s*(.+)') {
        $depLine = $Matches[1].Trim()
        $plan.Dependencies = $depLine -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '(?i)^(None|N/A)$' }
    }

    # Parse Tasks section
    $sectionEndPattern = '(?=\n##(?!#)|\z)'
    if ($content -match "(?s)##\s+(?:Key\s+)?Tasks\s*\n+(.+?)$sectionEndPattern") {
        $tasksSection = $Matches[1]
        
        # Split by task headers (### Task N:)
        $taskMatches = [regex]::Matches($tasksSection, '(?s)###\s+Task\s+\d+:\s*(.+?)(?=\n###|\z)')
        
        foreach ($taskMatch in $taskMatches) {
            $taskContent = $taskMatch.Groups[1].Value.Trim()
            
            # Extract task title (first line)
            $taskLines = $taskContent -split '\n'
            $taskTitle = $taskLines[0].Trim()
            
            $plan.Tasks += @{
                Title = $taskTitle
                Content = $taskContent
            }
        }
    }

    Write-OkyeremaLogHelper -Message "Parsed plan: $($plan.Title) with $($plan.Tasks.Count) tasks" -Level Debug -Operation "Parse-PlanMarkdown" -CorrelationId $CorrelationId

    return $plan
}

function Get-AllPlanFiles {
    <#
    .SYNOPSIS
        Get all planning markdown files from phase directories.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PlanDirectory
    )

    Write-OkyeremaLogHelper -Message "Scanning for planning files in: $PlanDirectory" -Level Info -Operation "Get-AllPlanFiles" -CorrelationId $CorrelationId

    if (-not (Test-Path $PlanDirectory)) {
        throw "Planning directory not found: $PlanDirectory"
    }

    $planFiles = @()
    
    # Find all phase-* directories
    $phaseDirs = Get-ChildItem -Path $PlanDirectory -Directory | Where-Object { $_.Name -match '^phase-' }
    
    foreach ($phaseDir in $phaseDirs) {
        # Get all .md files except README.md
        $mdFiles = Get-ChildItem -Path $phaseDir.FullName -Filter "*.md" | Where-Object { $_.Name -ine "README.md" }
        
        foreach ($mdFile in $mdFiles) {
            $planFiles += $mdFile.FullName
        }
    }

    Write-OkyeremaLogHelper -Message "Found $($planFiles.Count) planning files" -Level Info -Operation "Get-AllPlanFiles" -CorrelationId $CorrelationId

    return $planFiles
}

function Get-AllRepositoryIssues {
    <#
    .SYNOPSIS
        Fetch all issues from the repository.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo
    )

    Write-OkyeremaLogHelper -Message "Fetching all repository issues" -Level Info -Operation "Get-AllRepositoryIssues" -CorrelationId $CorrelationId

    $query = @"
query(`$owner: String!, `$repo: String!, `$cursor: String) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, after: `$cursor, orderBy: {field: CREATED_AT, direction: ASC}) {
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        id
        number
        title
        state
        closed
        issueType {
          id
          name
        }
        body
        createdAt
        closedAt
      }
    }
  }
}
"@

    $allIssues = @()
    $cursor = $null
    $hasNextPage = $true

    while ($hasNextPage) {
        $variables = @{
            owner = $Owner
            repo = $Repo
        }

        if ($cursor) {
            $variables.cursor = $cursor
        }

        $result = Invoke-GraphQLHelper -Query $query -Variables $variables -CorrelationId $CorrelationId

        if (-not $result.Success) {
            $errorMsg = $result.Errors[0].Message
            Write-OkyeremaLogHelper -Message "Failed to fetch issues: $errorMsg" -Level Error -Operation "Get-AllRepositoryIssues" -CorrelationId $CorrelationId
            throw "Failed to fetch issues: $errorMsg"
        }

        $issues = $result.Data.repository.issues
        $allIssues += $issues.nodes
        
        $hasNextPage = $issues.pageInfo.hasNextPage
        $cursor = $issues.pageInfo.endCursor

        Write-OkyeremaLogHelper -Message "Fetched $($issues.nodes.Count) issues (total: $($allIssues.Count))" -Level Debug -Operation "Get-AllRepositoryIssues" -CorrelationId $CorrelationId
    }

    Write-OkyeremaLogHelper -Message "Fetched $($allIssues.Count) total issues" -Level Info -Operation "Get-AllRepositoryIssues" -CorrelationId $CorrelationId

    return $allIssues
}

function Compare-PlanWithIssues {
    <#
    .SYNOPSIS
        Compare planning files with GitHub issues to identify drift.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$PlanFiles,

        [Parameter(Mandatory = $true)]
        [array]$Issues
    )

    Write-OkyeremaLogHelper -Message "Comparing $($PlanFiles.Count) plan files with $($Issues.Count) issues" -Level Info -Operation "Compare-PlanWithIssues" -CorrelationId $CorrelationId

    $drift = @{
        MissingFromGitHub = @()      # Tasks in plan but not in GitHub
        ClosedButPending = @()        # Issues closed in GitHub but plan shows pending
        ExtraInGitHub = @()           # Issues in GitHub but not in plan
        Matched = @()                 # Issues that match plan
    }

    # Parse all plan files
    $allPlans = @()
    foreach ($planFile in $PlanFiles) {
        try {
            $plan = Parse-PlanMarkdown -FilePath $planFile
            $allPlans += $plan
        }
        catch {
            Write-OkyeremaLogHelper -Message "Failed to parse plan file $planFile : $_" -Level Warn -Operation "Compare-PlanWithIssues" -CorrelationId $CorrelationId
        }
    }

    # Build a map of issue titles for quick lookup
    $issueTitleMap = @{}
    foreach ($issue in $Issues) {
        $normalizedTitle = $issue.title.Trim().ToLower()
        if (-not $issueTitleMap.ContainsKey($normalizedTitle)) {
            $issueTitleMap[$normalizedTitle] = @()
        }
        $issueTitleMap[$normalizedTitle] += $issue
    }

    # Check each plan for missing/closed issues
    foreach ($plan in $allPlans) {
        # Check parent feature
        if ($plan.Title) {
            $normalizedTitle = $plan.Title.Trim().ToLower()
            $matchingIssues = $issueTitleMap[$normalizedTitle]
            
            if (-not $matchingIssues) {
                # Missing from GitHub
                $drift.MissingFromGitHub += @{
                    Type = "Feature"
                    Title = $plan.Title
                    PlanFile = $plan.FileName
                    Phase = $plan.Phase
                }
            }
            elseif ($matchingIssues[0].state -eq "CLOSED" -and $plan.Status -notmatch '(?i)(done|completed|closed)') {
                # Closed in GitHub but plan shows pending
                $drift.ClosedButPending += @{
                    Type = "Feature"
                    IssueNumber = $matchingIssues[0].number
                    Title = $plan.Title
                    PlanFile = $plan.FileName
                    PlanStatus = $plan.Status
                    ClosedAt = $matchingIssues[0].closedAt
                }
            }
            else {
                # Matched
                $drift.Matched += @{
                    Type = "Feature"
                    IssueNumber = $matchingIssues[0].number
                    Title = $plan.Title
                    PlanFile = $plan.FileName
                }
            }
        }

        # Check tasks
        foreach ($task in $plan.Tasks) {
            $normalizedTitle = $task.Title.Trim().ToLower()
            $matchingIssues = $issueTitleMap[$normalizedTitle]
            
            if (-not $matchingIssues) {
                # Missing from GitHub
                $drift.MissingFromGitHub += @{
                    Type = "Task"
                    Title = $task.Title
                    PlanFile = $plan.FileName
                    ParentFeature = $plan.Title
                    Phase = $plan.Phase
                }
            }
            elseif ($matchingIssues[0].state -eq "CLOSED" -and $plan.Status -notmatch '(?i)(done|completed|closed)') {
                # Closed in GitHub but plan shows pending
                $drift.ClosedButPending += @{
                    Type = "Task"
                    IssueNumber = $matchingIssues[0].number
                    Title = $task.Title
                    PlanFile = $plan.FileName
                    ParentFeature = $plan.Title
                    PlanStatus = $plan.Status
                    ClosedAt = $matchingIssues[0].closedAt
                }
            }
            else {
                # Matched
                $drift.Matched += @{
                    Type = "Task"
                    IssueNumber = $matchingIssues[0].number
                    Title = $task.Title
                    PlanFile = $plan.FileName
                }
            }
        }
    }

    # Find issues that don't match any plan (only check Feature and Task types)
    $allPlanTitles = @()
    foreach ($plan in $allPlans) {
        if ($plan.Title) {
            $allPlanTitles += $plan.Title.Trim().ToLower()
        }
        foreach ($task in $plan.Tasks) {
            $allPlanTitles += $task.Title.Trim().ToLower()
        }
    }

    foreach ($issue in $Issues) {
        $issueType = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
        
        # Only check Feature and Task types
        if ($issueType -in @("Feature", "Task")) {
            $normalizedTitle = $issue.title.Trim().ToLower()
            
            if ($normalizedTitle -notin $allPlanTitles) {
                $drift.ExtraInGitHub += @{
                    Type = $issueType
                    IssueNumber = $issue.number
                    Title = $issue.title
                    State = $issue.state
                    CreatedAt = $issue.createdAt
                }
            }
        }
    }

    Write-OkyeremaLogHelper -Message "Drift analysis: Missing=$($drift.MissingFromGitHub.Count), Closed=$($drift.ClosedButPending.Count), Extra=$($drift.ExtraInGitHub.Count), Matched=$($drift.Matched.Count)" -Level Info -Operation "Compare-PlanWithIssues" -CorrelationId $CorrelationId

    return $drift
}

function Format-ConsoleOutput {
    <#
    .SYNOPSIS
        Format drift report for console output.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Drift
    )

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Plan-to-Issues Sync Report" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Summary
    Write-Host "Summary:" -ForegroundColor Yellow
    Write-Host "  Missing from GitHub: $($Drift.MissingFromGitHub.Count)" -ForegroundColor $(if ($Drift.MissingFromGitHub.Count -gt 0) { "Red" } else { "Green" })
    Write-Host "  Closed but Pending:  $($Drift.ClosedButPending.Count)" -ForegroundColor $(if ($Drift.ClosedButPending.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Extra in GitHub:     $($Drift.ExtraInGitHub.Count)" -ForegroundColor $(if ($Drift.ExtraInGitHub.Count -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Matched:             $($Drift.Matched.Count)" -ForegroundColor Green
    Write-Host ""

    # Details: Missing from GitHub
    if ($Drift.MissingFromGitHub.Count -gt 0) {
        Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "Missing from GitHub (in plan but not created):" -ForegroundColor Red
        Write-Host ""
        
        foreach ($item in $Drift.MissingFromGitHub) {
            Write-Host "  [$($item.Type)] $($item.Title)" -ForegroundColor White
            Write-Host "    Plan: $($item.PlanFile)" -ForegroundColor Gray
            if ($item.ParentFeature) {
                Write-Host "    Parent: $($item.ParentFeature)" -ForegroundColor Gray
            }
            if ($item.Phase) {
                Write-Host "    Phase: $($item.Phase)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }

    # Details: Closed but Pending
    if ($Drift.ClosedButPending.Count -gt 0) {
        Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "Closed but Pending (closed in GitHub, pending in plan):" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($item in $Drift.ClosedButPending) {
            Write-Host "  #$($item.IssueNumber) [$($item.Type)] $($item.Title)" -ForegroundColor White
            Write-Host "    Plan: $($item.PlanFile) (Status: $($item.PlanStatus))" -ForegroundColor Gray
            Write-Host "    Closed: $($item.ClosedAt)" -ForegroundColor Gray
            Write-Host ""
        }
    }

    # Details: Extra in GitHub
    if ($Drift.ExtraInGitHub.Count -gt 0) {
        Write-Host "─────────────────────────────────────────────────────" -ForegroundColor Gray
        Write-Host "Extra in GitHub (exists but not in plan):" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($item in $Drift.ExtraInGitHub) {
            Write-Host "  #$($item.IssueNumber) [$($item.Type)] $($item.Title)" -ForegroundColor White
            Write-Host "    State: $($item.State)" -ForegroundColor Gray
            Write-Host "    Created: $($item.CreatedAt)" -ForegroundColor Gray
            Write-Host ""
        }
    }

    # All clear message
    if ($Drift.MissingFromGitHub.Count -eq 0 -and 
        $Drift.ClosedButPending.Count -eq 0 -and 
        $Drift.ExtraInGitHub.Count -eq 0) {
        Write-Host "✓ No drift detected - Plan and GitHub are in sync!" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Format-JsonOutput {
    <#
    .SYNOPSIS
        Format drift report as JSON.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Drift
    )

    $output = @{
        summary = @{
            missingFromGitHub = $Drift.MissingFromGitHub.Count
            closedButPending = $Drift.ClosedButPending.Count
            extraInGitHub = $Drift.ExtraInGitHub.Count
            matched = $Drift.Matched.Count
        }
        missingFromGitHub = $Drift.MissingFromGitHub
        closedButPending = $Drift.ClosedButPending
        extraInGitHub = $Drift.ExtraInGitHub
        matched = $Drift.Matched
    }

    return $output | ConvertTo-Json -Depth 10
}

function Format-CsvOutput {
    <#
    .SYNOPSIS
        Format drift report as CSV.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Drift
    )

    $rows = @()

    # Missing from GitHub
    foreach ($item in $Drift.MissingFromGitHub) {
        $rows += [PSCustomObject]@{
            Category = "MissingFromGitHub"
            Type = $item.Type
            IssueNumber = ""
            Title = $item.Title
            PlanFile = $item.PlanFile
            ParentFeature = $item.ParentFeature
            Phase = $item.Phase
            State = ""
            PlanStatus = ""
            ClosedAt = ""
            CreatedAt = ""
        }
    }

    # Closed but Pending
    foreach ($item in $Drift.ClosedButPending) {
        $rows += [PSCustomObject]@{
            Category = "ClosedButPending"
            Type = $item.Type
            IssueNumber = $item.IssueNumber
            Title = $item.Title
            PlanFile = $item.PlanFile
            ParentFeature = $item.ParentFeature
            Phase = ""
            State = "CLOSED"
            PlanStatus = $item.PlanStatus
            ClosedAt = $item.ClosedAt
            CreatedAt = ""
        }
    }

    # Extra in GitHub
    foreach ($item in $Drift.ExtraInGitHub) {
        $rows += [PSCustomObject]@{
            Category = "ExtraInGitHub"
            Type = $item.Type
            IssueNumber = $item.IssueNumber
            Title = $item.Title
            PlanFile = ""
            ParentFeature = ""
            Phase = ""
            State = $item.State
            PlanStatus = ""
            ClosedAt = ""
            CreatedAt = $item.CreatedAt
        }
    }

    # Matched
    foreach ($item in $Drift.Matched) {
        $rows += [PSCustomObject]@{
            Category = "Matched"
            Type = $item.Type
            IssueNumber = $item.IssueNumber
            Title = $item.Title
            PlanFile = $item.PlanFile
            ParentFeature = ""
            Phase = ""
            State = ""
            PlanStatus = ""
            ClosedAt = ""
            CreatedAt = ""
        }
    }

    return $rows | ConvertTo-Csv -NoTypeInformation
}

function New-MissingIssues {
    <#
    .SYNOPSIS
        Create GitHub issues for items missing from GitHub.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$MissingItems,

        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    Write-OkyeremaLogHelper -Message "Creating $($MissingItems.Count) missing issues" -Level Info -Operation "New-MissingIssues" -CorrelationId $CorrelationId

    if ($DryRun) {
        Write-Host ""
        Write-Host "=== DryRun: Would create the following issues ===" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($item in $MissingItems) {
            Write-Host "[$($item.Type)] $($item.Title)" -ForegroundColor Yellow
            Write-Host "  From: $($item.PlanFile)" -ForegroundColor Gray
            Write-Host ""
        }
        
        return
    }

    # Group by plan file to create issues efficiently
    $itemsByPlanFile = @{}
    foreach ($item in $MissingItems) {
        $planFile = $item.PlanFile
        if (-not $itemsByPlanFile.ContainsKey($planFile)) {
            $itemsByPlanFile[$planFile] = @()
        }
        $itemsByPlanFile[$planFile] += $item
    }

    # Use Import-PlanToIssues.ps1 to create issues from each plan file
    foreach ($planFile in $itemsByPlanFile.Keys) {
        $items = $itemsByPlanFile[$planFile]
        $fullPath = Join-Path (Split-Path -Parent $PlanDirectory) $planFile
        
        if (-not (Test-Path $fullPath)) {
            # Try with planning directory prepended
            $fullPath = Join-Path $PlanDirectory $planFile
        }
        
        if (Test-Path $fullPath) {
            Write-Host "Creating issues from: $planFile" -ForegroundColor Cyan
            
            try {
                & "$scriptDir/Import-PlanToIssues.ps1" -PlanFile $fullPath -Owner $Owner -Repo $Repo -CorrelationId $CorrelationId
                Write-OkyeremaLogHelper -Message "Created issues from $planFile" -Level Info -Operation "New-MissingIssues" -CorrelationId $CorrelationId
            }
            catch {
                Write-OkyeremaLogHelper -Message "Failed to create issues from $planFile : $_" -Level Error -Operation "New-MissingIssues" -CorrelationId $CorrelationId
                Write-Host "  Error: $_" -ForegroundColor Red
            }
        }
        else {
            Write-OkyeremaLogHelper -Message "Plan file not found: $fullPath" -Level Warn -Operation "New-MissingIssues" -CorrelationId $CorrelationId
        }
    }
}

#endregion

#region Main Logic

try {
    # Resolve plan directory to absolute path
    $PlanDirectory = Resolve-Path $PlanDirectory -ErrorAction Stop
    
    Write-OkyeremaLogHelper -Message "Using plan directory: $PlanDirectory" -Level Info -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId

    # Get all plan files
    $planFiles = Get-AllPlanFiles -PlanDirectory $PlanDirectory

    if ($planFiles.Count -eq 0) {
        Write-OkyeremaLogHelper -Message "No planning files found in $PlanDirectory" -Level Warn -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
        Write-Host "No planning files found. Nothing to sync." -ForegroundColor Yellow
        exit 0
    }

    # Get all repository issues
    $issues = Get-AllRepositoryIssues -Owner $owner -Repo $repoName

    # Compare and identify drift
    $drift = Compare-PlanWithIssues -PlanFiles $planFiles -Issues $issues

    # Output results in requested format
    switch ($Format) {
        "Console" {
            Format-ConsoleOutput -Drift $drift
        }
        "JSON" {
            $output = Format-JsonOutput -Drift $drift
            Write-Output $output
        }
        "CSV" {
            $output = Format-CsvOutput -Drift $drift
            Write-Output $output
        }
    }

    # Create missing issues if requested
    if ($CreateMissing -and $drift.MissingFromGitHub.Count -gt 0) {
        Write-Host ""
        Write-Host "Creating missing issues..." -ForegroundColor Cyan
        
        New-MissingIssues -MissingItems $drift.MissingFromGitHub -Owner $owner -Repo $repoName -DryRun:$DryRun
        
        if (-not $DryRun) {
            Write-Host ""
            Write-Host "✓ Issues created. Run sync again to verify." -ForegroundColor Green
        }
    }
    elseif ($CreateMissing -and $drift.MissingFromGitHub.Count -eq 0) {
        Write-Host ""
        Write-Host "No missing issues to create." -ForegroundColor Green
    }

    Write-OkyeremaLogHelper -Message "Sync completed successfully" -Level Info -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLogHelper -Message "Sync failed: $_" -Level Error -Operation "Sync-PlanToIssues" -CorrelationId $CorrelationId
    throw
}

#endregion
