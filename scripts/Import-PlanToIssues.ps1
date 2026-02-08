<#
.SYNOPSIS
    Parse planning markdown files into GitHub issue hierarchies.

.DESCRIPTION
    This script reads feature markdown files from the planning/ directory and creates
    corresponding GitHub issues with proper hierarchy and relationships.
    
    - Reads a feature .md file, extracts title, tasks, dependencies, acceptance criteria
    - Creates an Epic (or Feature) for the file, Tasks for each task block
    - Builds tasklist relationships automatically using GitHub's tasklist syntax
    - -DryRun outputs what would be created without calling GitHub
    - -PlanDirectory mode processes an entire phase folder

.PARAMETER PlanFile
    Path to a single feature markdown file to import.

.PARAMETER PlanDirectory
    Path to a directory containing multiple feature markdown files to import.

.PARAMETER Owner
    GitHub repository owner (organization or user).

.PARAMETER Repo
    GitHub repository name.

.PARAMETER DryRun
    If specified, outputs what would be created without making API calls.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Import-PlanToIssues.ps1 -PlanFile planning/phase-2-governance/01-ruleset-protect-main.md -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    ./Import-PlanToIssues.ps1 -PlanDirectory planning/phase-2-governance -Owner anokye-labs -Repo akwaaba -DryRun

.OUTPUTS
    Returns an array of created issue objects with their numbers and relationships.

.NOTES
    Author: Anokye Labs
    Dependencies: Invoke-GraphQL.ps1, ConvertTo-EscapedGraphQL.ps1, Write-OkyeremaLog.ps1
#>

[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'File', Position = 0)]
    [string]$PlanFile,

    [Parameter(Mandatory = $true, ParameterSetName = 'Directory', Position = 0)]
    [string]$PlanDirectory,

    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

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

# Import dependencies (function/filter scripts only, not scripts with mandatory params)
. "$PSScriptRoot/ConvertTo-EscapedGraphQL.ps1"

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
    & "$PSScriptRoot/Invoke-GraphQL.ps1" @params
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

Write-OkyeremaLogHelper -Level Info -Message "Starting plan import" -Operation "Import-PlanToIssues" -CorrelationId $CorrelationId

#region Helper Functions

function Parse-PlanMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Write-OkyeremaLogHelper -Level Debug -Message "Parsing markdown file: $FilePath" -Operation "Parse-PlanMarkdown" -CorrelationId $CorrelationId

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    $content = Get-Content -Path $FilePath -Raw
    $lines = Get-Content -Path $FilePath

    # Initialize result object
    $plan = @{
        FilePath = $FilePath
        Title = ""
        ID = ""
        Phase = ""
        Status = ""
        Dependencies = @()
        Overview = ""
        Tasks = @()
        AcceptanceCriteria = @()
        Notes = ""
        RawContent = $content
    }

    # Parse title (first line starting with #)
    $titleMatch = $content -match '(?m)^#\s+(.+)$'
    if ($titleMatch) {
        $plan.Title = $Matches[1].Trim()
    }

    # Parse metadata (ID, Phase, Status, Dependencies)
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
        # Parse comma-separated or single dependency (case-insensitive filtering)
        $plan.Dependencies = $depLine -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^(None|N/A|n/a)$' }
    }

    # Parse Overview section (flexible whitespace after heading)
    if ($content -match '(?s)##\s+Overview\s*\n+(.+?)(?=\n##(?!#)|\z)') {
        $plan.Overview = $Matches[1].Trim()
    }

    # Parse Tasks section (flexible whitespace after heading)
    if ($content -match '(?s)##\s+(?:Key\s+)?Tasks\s*\n+(.+?)(?=\n##(?!#)|\z)') {
        $tasksSection = $Matches[1]
        
        # Split by task headers (### Task N:)
        $taskMatches = [regex]::Matches($tasksSection, '(?s)###\s+Task\s+\d+:\s*(.+?)(?=\n###|\z)')
        
        # Log warning if expected tasks section exists but no tasks were parsed
        if ($taskMatches.Count -eq 0 -and $tasksSection.Length -gt 0) {
            Write-OkyeremaLogHelper -Level Warn -Message "Tasks section found but no task headers matching '### Task N:' were parsed. Check markdown formatting." -Operation "Parse-PlanMarkdown" -CorrelationId $CorrelationId
        }
        
        foreach ($taskMatch in $taskMatches) {
            $taskContent = $taskMatch.Groups[1].Value.Trim()
            
            # Extract task title (first line)
            $taskLines = $taskContent -split '\n'
            $taskTitle = $taskLines[0].Trim()
            
            # Extract checklist items
            $checklistItems = @()
            foreach ($line in $taskLines) {
                if ($line -match '^\s*-\s+\[\s*\]\s*(.+)') {
                    $checklistItems += $Matches[1].Trim()
                }
            }
            
            $plan.Tasks += @{
                Title = $taskTitle
                Content = $taskContent
                ChecklistItems = $checklistItems
            }
        }
    }

    # Parse Acceptance Criteria section (flexible whitespace after heading)
    if ($content -match '(?s)##\s+Acceptance\s+Criteria\s*\n+(.+?)(?=\n##(?!#)|\z)') {
        $criteriaSection = $Matches[1].Trim()
        $criteriaLines = $criteriaSection -split '\n' | Where-Object { $_ -match '^\s*-\s+(.+)' }
        $plan.AcceptanceCriteria = $criteriaLines | ForEach-Object { $_ -replace '^\s*-\s+', '' }
    }

    # Parse Notes section (flexible whitespace after heading)
    if ($content -match '(?s)##\s+Notes\s*\n+(.+?)(?=\n##(?!#)|\z)') {
        $plan.Notes = $Matches[1].Trim()
    }

    Write-OkyeremaLogHelper -Level Info -Message "Parsed plan: $($plan.Title) with $($plan.Tasks.Count) tasks" -Operation "Parse-PlanMarkdown" -CorrelationId $CorrelationId

    return $plan
}

function Get-RepositoryContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,

        [Parameter(Mandatory = $true)]
        [string]$Repo
    )

    Write-OkyeremaLogHelper -Level Debug -Message "Fetching repository context for $Owner/$Repo" -Operation "Get-RepositoryContext" -CorrelationId $CorrelationId

    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    id
    owner {
      ... on Organization {
        issueTypes(first: 25) {
          nodes { id name }
        }
      }
    }
  }
}
"@

    $result = Invoke-GraphQLHelper -Query $query -CorrelationId $CorrelationId

    if (-not $result.Success) {
        throw "Failed to fetch repository context: $($result.Errors | ConvertTo-Json)"
    }

    $repoId = $result.Data.repository.id
    $issueTypes = $result.Data.repository.owner.issueTypes.nodes

    Write-OkyeremaLogHelper -Level Debug -Message "Repository ID: $repoId, Issue types: $($issueTypes.Count)" -Operation "Get-RepositoryContext" -CorrelationId $CorrelationId

    return @{
        RepositoryId = $repoId
        IssueTypes = $issueTypes
    }
}

function Get-IssueTypeId {
    param(
        [Parameter(Mandatory = $true)]
        [array]$IssueTypes,

        [Parameter(Mandatory = $true)]
        [string]$TypeName
    )

    $typeId = ($IssueTypes | Where-Object { $_.name -eq $TypeName }).id

    if (-not $typeId) {
        throw "Issue type '$TypeName' not found. Available: $($IssueTypes.name -join ', ')"
    }

    return $typeId
}

function New-IssueFromPlan {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Plan,

        [Parameter(Mandatory = $true)]
        [string]$RepositoryId,

        [Parameter(Mandatory = $true)]
        [array]$IssueTypes,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    Write-OkyeremaLogHelper -Level Info -Message "Creating issues for plan: $($Plan.Title)" -Operation "New-IssueFromPlan" -CorrelationId $CorrelationId

    $results = @{
        ParentIssue = $null
        TaskIssues = @()
    }

    # Determine parent issue type
    # All planning feature files create Feature issues
    # (Phase README files are excluded from directory processing and would require explicit -PlanFile)
    $parentType = "Feature"

    $parentTypeId = Get-IssueTypeId -IssueTypes $IssueTypes -TypeName $parentType

    # Build parent issue body
    $parentBody = ""
    if ($Plan.Overview) {
        $parentBody += "## Overview`n`n$($Plan.Overview)`n`n"
    }

    if ($Plan.AcceptanceCriteria.Count -gt 0) {
        $parentBody += "## Acceptance Criteria`n`n"
        foreach ($criteria in $Plan.AcceptanceCriteria) {
            $parentBody += "- $criteria`n"
        }
        $parentBody += "`n"
    }

    if ($Plan.Notes) {
        $parentBody += "## Notes`n`n$($Plan.Notes)`n`n"
    }

    # Create task issues first
    $taskNumbers = @()
    foreach ($task in $Plan.Tasks) {
        $taskTypeId = Get-IssueTypeId -IssueTypes $IssueTypes -TypeName "Task"
        
        $taskTitle = $task.Title
        $taskBody = $task.Content

        if ($DryRun) {
            Write-Host "=== DryRun: Would create Task ===" -ForegroundColor Cyan
            Write-Host "Title: $taskTitle" -ForegroundColor Yellow
            Write-Host "Type: Task" -ForegroundColor Yellow
            Write-Host "Body:" -ForegroundColor Yellow
            Write-Host $taskBody -ForegroundColor Gray
            Write-Host ""

            # Use placeholder for tasklist
            $taskNumbers += "#TBD"
            $results.TaskIssues += @{ Title = $taskTitle; Number = "TBD"; Body = $taskBody }
        } else {
            # Escape title and body for GraphQL
            $escapedTitle = $taskTitle | ConvertTo-EscapedGraphQL
            $escapedBody = $taskBody | ConvertTo-EscapedGraphQL

            $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$RepositoryId"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$taskTypeId"
  }) {
    issue {
      id
      number
      title
      url
    }
  }
}
"@

            $result = Invoke-GraphQLHelper -Query $mutation -CorrelationId $CorrelationId

            if (-not $result.Success) {
                throw "Failed to create task issue: $($result.Errors | ConvertTo-Json)"
            }

            $taskIssue = $result.Data.createIssue.issue
            Write-OkyeremaLogHelper -Level Info -Message "Created Task #$($taskIssue.number): $($taskIssue.title)" -Operation "New-IssueFromPlan" -CorrelationId $CorrelationId

            $taskNumbers += "#$($taskIssue.number)"
            $results.TaskIssues += $taskIssue
        }
    }

    # Add tasklist to parent body if there are tasks
    if ($taskNumbers.Count -gt 0) {
        $parentBody += "## Tasks`n`n"
        foreach ($taskNum in $taskNumbers) {
            $parentBody += "- [ ] $taskNum`n"
        }
    }

    # Create parent issue
    $parentTitle = $Plan.Title

    if ($DryRun) {
        Write-Host "=== DryRun: Would create $parentType ===" -ForegroundColor Cyan
        Write-Host "Title: $parentTitle" -ForegroundColor Yellow
        Write-Host "Type: $parentType" -ForegroundColor Yellow
        Write-Host "Body:" -ForegroundColor Yellow
        Write-Host $parentBody -ForegroundColor Gray
        Write-Host ""
        Write-Host "Summary: Would create 1 $parentType and $($Plan.Tasks.Count) Tasks" -ForegroundColor Green
        
        $results.ParentIssue = @{ Title = $parentTitle; Number = "TBD"; Body = $parentBody }
    } else {
        # Escape title and body for GraphQL
        $escapedTitle = $parentTitle | ConvertTo-EscapedGraphQL
        $escapedBody = $parentBody | ConvertTo-EscapedGraphQL

        $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$RepositoryId"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$parentTypeId"
  }) {
    issue {
      id
      number
      title
      url
    }
  }
}
"@

        $result = Invoke-GraphQLHelper -Query $mutation -CorrelationId $CorrelationId

        if (-not $result.Success) {
            throw "Failed to create parent issue: $($result.Errors | ConvertTo-Json)"
        }

        $parentIssue = $result.Data.createIssue.issue
        Write-OkyeremaLogHelper -Level Info -Message "Created $parentType #$($parentIssue.number): $($parentIssue.title)" -Operation "New-IssueFromPlan" -CorrelationId $CorrelationId
        Write-Host "✓ Created #$($parentIssue.number) [$parentType] $($parentIssue.title)" -ForegroundColor Green

        foreach ($taskIssue in $results.TaskIssues) {
            Write-Host "  ✓ Created #$($taskIssue.number) [Task] $($taskIssue.title)" -ForegroundColor Gray
        }

        $results.ParentIssue = $parentIssue
    }

    return $results
}

#endregion

#region Main Logic

try {
    # Determine files to process
    $filesToProcess = @()

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        if (-not (Test-Path $PlanFile)) {
            throw "Plan file not found: $PlanFile"
        }
        $filesToProcess += $PlanFile
    } else {
        if (-not (Test-Path $PlanDirectory)) {
            throw "Plan directory not found: $PlanDirectory"
        }
        # Exclude phase README files from directory processing
        # (They can be explicitly processed with -PlanFile if needed)
        $filesToProcess = Get-ChildItem -Path $PlanDirectory -Filter "*.md" | Where-Object { $_.Name -ne "README.md" } | ForEach-Object { $_.FullName }
        
        if ($filesToProcess.Count -eq 0) {
            throw "No markdown files found in directory: $PlanDirectory"
        }

        Write-OkyeremaLogHelper -Level Info -Message "Found $($filesToProcess.Count) files to process" -Operation "Import-PlanToIssues" -CorrelationId $CorrelationId
    }

    # Get repository context (only once, not in DryRun if we can avoid it)
    $repoContext = $null
    if (-not $DryRun) {
        $repoContext = Get-RepositoryContext -Owner $Owner -Repo $Repo
    } else {
        # For DryRun, we still need the context but can skip if offline
        Write-Host "=== DryRun Mode ===" -ForegroundColor Cyan
        Write-Host "Repository: $Owner/$Repo" -ForegroundColor Yellow
        Write-Host "Correlation ID: $CorrelationId" -ForegroundColor Yellow
        Write-Host ""
        
        try {
            $repoContext = Get-RepositoryContext -Owner $Owner -Repo $Repo
        } catch {
            Write-OkyeremaLogHelper -Level Warn -Message "Could not fetch repository context in DryRun mode: $_" -Operation "Import-PlanToIssues" -CorrelationId $CorrelationId
            # Create mock context for DryRun
            $repoContext = @{
                RepositoryId = "R_MOCK"
                IssueTypes = @(
                    @{ id = "IT_EPIC"; name = "Epic" }
                    @{ id = "IT_FEATURE"; name = "Feature" }
                    @{ id = "IT_TASK"; name = "Task" }
                )
            }
        }
    }

    # Process each file
    $allResults = @()
    foreach ($file in $filesToProcess) {
        Write-OkyeremaLogHelper -Level Info -Message "Processing file: $file" -Operation "Import-PlanToIssues" -CorrelationId $CorrelationId
        
        $plan = Parse-PlanMarkdown -FilePath $file
        $result = New-IssueFromPlan -Plan $plan -RepositoryId $repoContext.RepositoryId -IssueTypes $repoContext.IssueTypes -DryRun:$DryRun
        
        $allResults += @{
            FilePath = $file
            Plan = $plan
            Result = $result
        }
    }

    Write-OkyeremaLogHelper -Level Info -Message "Import completed successfully. Processed $($allResults.Count) files." -Operation "Import-PlanToIssues" -CorrelationId $CorrelationId

    # Return results
    return $allResults

} catch {
    Write-OkyeremaLogHelper -Level Error -Message "Import failed: $_" -Operation "Import-PlanToIssues" -CorrelationId $CorrelationId
    throw
}

#endregion
