<#
.SYNOPSIS
    End-to-end plan materialization: creates a complete issue DAG from planning directories.

.DESCRIPTION
    This script orchestrates the complete materialization of a planning directory structure
    into GitHub issues with full hierarchy and dependency relationships:
    
    - Scans planning/phase-*/ directories
    - Creates Epics per phase (from README.md)
    - Creates Features per feature file (from NN-*.md files)
    - Creates Tasks per task block (within each feature)
    - Wires all parent-child relationships via tasklists
    - Applies cross-phase dependencies via body text
    - Adds everything to the project board
    
    Supports:
    - -DryRun for preview without creating issues
    - -Phase filter to materialize one phase at a time

.PARAMETER PlanDirectory
    Root planning directory containing phase-*/ subdirectories.
    Default: ./planning

.PARAMETER Owner
    GitHub repository owner (organization or user).

.PARAMETER Repo
    GitHub repository name.

.PARAMETER ProjectNumber
    Optional GitHub Projects V2 project number to add all created issues to.

.PARAMETER DryRun
    If specified, simulates the creation without actually creating issues.

.PARAMETER Phase
    Optional phase number to materialize only a specific phase (e.g., 1, 2, 3).
    If not provided, all phases are materialized.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    # Dry run to preview what would be created
    ./Invoke-PlanMaterialization.ps1 -Owner anokye-labs -Repo akwaaba -DryRun

.EXAMPLE
    # Materialize all phases and add to project #3
    ./Invoke-PlanMaterialization.ps1 -Owner anokye-labs -Repo akwaaba -ProjectNumber 3

.EXAMPLE
    # Materialize only phase 2
    ./Invoke-PlanMaterialization.ps1 -Owner anokye-labs -Repo akwaaba -Phase 2 -ProjectNumber 3

.EXAMPLE
    # Custom planning directory
    ./Invoke-PlanMaterialization.ps1 -PlanDirectory ./my-planning -Owner anokye-labs -Repo akwaaba

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - Phases: Array of phase results with Epic and Feature details
    - TotalEpics: Number of Epics created
    - TotalFeatures: Number of Features created
    - TotalTasks: Number of Tasks created
    - CorrelationId: The correlation ID for this request

.NOTES
    Dependencies:
    - Import-PlanToIssues.ps1 (for Feature and Task creation)
    - New-IssueHierarchy.ps1 (for Epic creation with hierarchy)
    - Set-IssueDependency.ps1 (for cross-phase dependencies)
    - Add-IssuesToProject.ps1 (for project board integration)
    - Invoke-GraphQL.ps1 (for GraphQL API calls)
    - ConvertTo-EscapedGraphQL.ps1 (for text escaping)
    - Write-OkyeremaLog.ps1 (for structured logging)
    
    Wave 2: Requires all dependencies to be merged.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$PlanDirectory = "./planning",

    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [int]$ProjectNumber,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [int]$Phase,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Define paths to dependency scripts
$scriptRoot = $PSScriptRoot
$invokeGraphQLPath = "$scriptRoot/Invoke-GraphQL.ps1"
$convertToEscapedPath = "$scriptRoot/ConvertTo-EscapedGraphQL.ps1"
$importPlanPath = "$scriptRoot/Import-PlanToIssues.ps1"
$newHierarchyPath = "$scriptRoot/New-IssueHierarchy.ps1"
$setDependencyPath = "$scriptRoot/Set-IssueDependency.ps1"
$addToProjectPath = "$scriptRoot/Add-IssuesToProject.ps1"
$writeLogPath = "$scriptRoot/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

# Import ConvertTo-EscapedGraphQL as it's a function
. $convertToEscapedPath

# Helper function to call Invoke-GraphQL
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
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
    
    & $invokeGraphQLPath @params
}

# Helper function to write logs
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "PlanMaterialization"
    )
    
    if (Test-Path $writeLogPath) {
        & $writeLogPath -Message $Message -Level $Level -Operation $Operation -CorrelationId $CorrelationId
    } else {
        Write-Verbose "[$Level] $Message"
    }
}

Write-Log -Message "Starting plan materialization" -Level Info

# Resolve absolute path for planning directory
$PlanDirectory = Resolve-Path $PlanDirectory -ErrorAction Stop
Write-Log -Message "Planning directory: $PlanDirectory" -Level Info

# Discover phase directories
$phasePattern = if ($Phase) {
    "phase-$Phase-*"
} else {
    "phase-*"
}

$phaseDirs = Get-ChildItem -Path $PlanDirectory -Directory -Filter $phasePattern | Sort-Object Name

if ($phaseDirs.Count -eq 0) {
    throw "No phase directories found matching pattern '$phasePattern' in $PlanDirectory"
}

Write-Log -Message "Found $($phaseDirs.Count) phase(s) to materialize" -Level Info

# Get repository context (for issue types)
Write-Log -Message "Fetching repository metadata" -Level Info

$metadataQuery = @"
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

$metadataResult = Invoke-GraphQLHelper -Query $metadataQuery -DryRun:$DryRun

if (-not $DryRun -and -not $metadataResult.Success) {
    throw "Failed to fetch repository metadata: $($metadataResult.Errors | ConvertTo-Json)"
}

$repositoryId = if ($DryRun -and -not $metadataResult.Success) {
    "R_MOCK_REPO"
} else {
    $metadataResult.Data.repository.id
}

$issueTypes = @{}
if ($metadataResult.Success) {
    foreach ($type in $metadataResult.Data.repository.owner.issueTypes.nodes) {
        $issueTypes[$type.name] = $type.id
    }
} else {
    # Mock for DryRun
    $issueTypes = @{
        "Epic" = "IT_EPIC_MOCK"
        "Feature" = "IT_FEATURE_MOCK"
        "Task" = "IT_TASK_MOCK"
        "Bug" = "IT_BUG_MOCK"
    }
}

Write-Log -Message "Repository ID: $repositoryId" -Level Debug

# Results collection
$allPhases = @()
$totalEpics = 0
$totalFeatures = 0
$totalTasks = 0
$allCreatedIssues = @()

# Process each phase
foreach ($phaseDir in $phaseDirs) {
    $phaseName = $phaseDir.Name
    Write-Log -Message "Processing phase: $phaseName" -Level Info
    
    # Parse phase README to get Epic details
    $phaseReadmePath = Join-Path $phaseDir.FullName "README.md"
    
    if (-not (Test-Path $phaseReadmePath)) {
        Write-Log -Message "Phase README not found: $phaseReadmePath (skipping)" -Level Warn
        continue
    }
    
    $phaseReadme = Get-Content -Path $phaseReadmePath -Raw
    
    # Extract Epic title (first # heading)
    $epicTitle = "Unknown Phase"
    if ($phaseReadme -match '(?m)^#\s+(.+)$') {
        $epicTitle = $Matches[1].Trim()
    }
    
    # Extract Epic body (everything except first heading and Dependencies section)
    $epicBody = $phaseReadme -replace '(?m)^#\s+.+$', '' # Remove title
    $epicBody = $epicBody -replace '(?ms)## Dependencies.*?(?=\n##|\z)', '' # Remove Dependencies section
    $epicBody = $epicBody.Trim()
    
    # Parse dependencies from README if present
    $phaseDependencies = @()
    if ($phaseReadme -match '(?ms)## Dependencies\s*\n(.*?)(?=\n##|\z)') {
        $depsSection = $Matches[1]
        # Look for issue references like anokye-labs/akwaaba#14 or just #14
        $depMatches = [regex]::Matches($depsSection, '(?:[\w-]+/[\w-]+)?#(\d+)')
        foreach ($match in $depMatches) {
            $phaseDependencies += $match.Value
        }
    }
    
    # Get feature files in this phase
    $featureFiles = Get-ChildItem -Path $phaseDir.FullName -Filter "*.md" | 
        Where-Object { $_.Name -ine "README.md" } | 
        Sort-Object Name
    
    Write-Log -Message "Found $($featureFiles.Count) feature file(s) in $phaseName" -Level Info
    
    if ($DryRun) {
        Write-Host ""
        Write-Host "=== DryRun: Phase $phaseName ===" -ForegroundColor Cyan
        Write-Host "Epic Title: $epicTitle" -ForegroundColor Yellow
        Write-Host "Epic Body (preview): $($epicBody.Substring(0, [Math]::Min(100, $epicBody.Length)))..." -ForegroundColor Gray
        Write-Host "Feature Files: $($featureFiles.Count)" -ForegroundColor Yellow
        if ($phaseDependencies.Count -gt 0) {
            Write-Host "Dependencies: $($phaseDependencies -join ', ')" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Step 1: Create Features and Tasks for each feature file using Import-PlanToIssues
    $featureResults = @()
    $featureIssueNumbers = @()
    
    foreach ($featureFile in $featureFiles) {
        Write-Log -Message "Importing feature from: $($featureFile.Name)" -Level Info
        
        $importParams = @{
            PlanFile = $featureFile.FullName
            Owner = $Owner
            Repo = $Repo
            CorrelationId = $CorrelationId
        }
        
        if ($DryRun) {
            $importParams.DryRun = $true
        }
        
        try {
            $importResult = & $importPlanPath @importParams
            
            if ($importResult -and $importResult[0].Result.ParentIssue) {
                $featureResults += $importResult[0]
                
                if (-not $DryRun) {
                    $featureNumber = $importResult[0].Result.ParentIssue.number
                    $featureIssueNumbers += $featureNumber
                    
                    # Track created issues
                    $allCreatedIssues += $importResult[0].Result.ParentIssue
                    $allCreatedIssues += $importResult[0].Result.TaskIssues
                    
                    $totalFeatures++
                    $totalTasks += $importResult[0].Result.TaskIssues.Count
                    
                    Write-Log -Message "Created Feature #$featureNumber with $($importResult[0].Result.TaskIssues.Count) Tasks" -Level Info
                } else {
                    $featureIssueNumbers += "#TBD"
                    Write-Host "  Would create Feature: $($importResult[0].Plan.Title)" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Log -Message "Failed to import feature from $($featureFile.Name): $_" -Level Error
            throw
        }
    }
    
    # Step 2: Create Epic and link Features via New-IssueHierarchy
    Write-Log -Message "Creating Epic for $phaseName" -Level Info
    
    # Build hierarchy definition
    $hierarchyDef = @{
        Type = "Epic"
        Title = $epicTitle
        Body = $epicBody
        Children = @()
    }
    
    # In DryRun or if features were created, build the hierarchy
    if ($DryRun) {
        # For DryRun, just show what would be created
        foreach ($featureResult in $featureResults) {
            $hierarchyDef.Children += @{
                Type = "Feature"
                Title = $featureResult.Plan.Title
                Body = "Feature details"
                Children = @()
            }
        }
        
        Write-Host "=== DryRun: Would create Epic hierarchy ===" -ForegroundColor Cyan
        Write-Host "Epic: $($hierarchyDef.Title)" -ForegroundColor Yellow
        Write-Host "  Features: $($hierarchyDef.Children.Count)" -ForegroundColor Gray
        Write-Host ""
    } else {
        # Create the Epic issue
        $epicTypeId = $issueTypes["Epic"]
        $escapedTitle = $epicTitle | ConvertTo-EscapedGraphQL
        $escapedBody = $epicBody | ConvertTo-EscapedGraphQL
        
        $createEpicMutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$repositoryId"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$epicTypeId"
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
        
        $epicResult = Invoke-GraphQLHelper -Query $createEpicMutation
        
        if (-not $epicResult.Success) {
            throw "Failed to create Epic for $phaseName`: $($epicResult.Errors | ConvertTo-Json)"
        }
        
        $epicIssue = $epicResult.Data.createIssue.issue
        $totalEpics++
        $allCreatedIssues += $epicIssue
        
        Write-Host "✓ Created Epic #$($epicIssue.number): $($epicIssue.title)" -ForegroundColor Green
        Write-Log -Message "Created Epic #$($epicIssue.number)" -Level Info
        
        # Step 3: Wire Epic -> Features relationship via tasklist
        if ($featureIssueNumbers.Count -gt 0) {
            Write-Log -Message "Wiring Epic to Features via tasklist" -Level Info
            
            $tasklist = "`n`n## 📋 Tracked Features`n"
            foreach ($featureNum in $featureIssueNumbers | Sort-Object) {
                $tasklist += "`n- [ ] #$featureNum"
            }
            
            $newEpicBody = $epicBody + $tasklist
            $escapedNewBody = $newEpicBody | ConvertTo-EscapedGraphQL
            
            $updateEpicMutation = @"
mutation {
  updateIssue(input: {
    id: "$($epicIssue.id)"
    body: "$escapedNewBody"
  }) {
    issue {
      number
    }
  }
}
"@
            
            $updateResult = Invoke-GraphQLHelper -Query $updateEpicMutation
            
            if (-not $updateResult.Success) {
                Write-Log -Message "Failed to update Epic tasklist: $($updateResult.Errors | ConvertTo-Json)" -Level Warn
            } else {
                Write-Log -Message "Updated Epic #$($epicIssue.number) with $($featureIssueNumbers.Count) Features" -Level Info
            }
        }
        
        # Step 4: Apply cross-phase dependencies if present
        if ($phaseDependencies.Count -gt 0) {
            Write-Log -Message "Applying $($phaseDependencies.Count) cross-phase dependencies to Epic #$($epicIssue.number)" -Level Info
            
            try {
                $depParams = @{
                    IssueNumber = $epicIssue.number
                    DependsOn = $phaseDependencies
                    CorrelationId = $CorrelationId
                }
                
                $depResult = & $setDependencyPath @depParams
                
                if ($depResult.Success) {
                    Write-Log -Message "Applied dependencies to Epic #$($epicIssue.number)" -Level Info
                } else {
                    Write-Log -Message "Failed to apply dependencies: $($depResult.Error)" -Level Warn
                }
            } catch {
                Write-Log -Message "Error applying dependencies: $_" -Level Warn
            }
        }
        
        # Step 5: Add Epic and all child issues to project board
        if ($ProjectNumber) {
            Write-Log -Message "Adding issues to project #$ProjectNumber" -Level Info
            
            $issueNumbersToAdd = @($epicIssue.number) + $featureIssueNumbers
            
            try {
                $projectParams = @{
                    IssueNumbers = $issueNumbersToAdd
                    ProjectNumber = $ProjectNumber
                    Owner = $Owner
                    Repo = $Repo
                    CorrelationId = $CorrelationId
                }
                
                $projectResult = & $addToProjectPath @projectParams
                
                if ($projectResult.Success) {
                    Write-Log -Message "Added $($projectResult.AddedCount) issues to project #$ProjectNumber" -Level Info
                } else {
                    Write-Log -Message "Failed to add some issues to project" -Level Warn
                }
            } catch {
                Write-Log -Message "Error adding issues to project: $_" -Level Warn
            }
        }
        
        # Store phase result
        $allPhases += @{
            PhaseName = $phaseName
            EpicIssue = $epicIssue
            FeatureIssues = $featureResults | ForEach-Object { $_.Result.ParentIssue }
            TaskIssues = $featureResults | ForEach-Object { $_.Result.TaskIssues } | ForEach-Object { $_ }
        }
    }
}

# Summary
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Materialization Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Phases processed: $($allPhases.Count)" -ForegroundColor Yellow
Write-Host "Epics created: $totalEpics" -ForegroundColor Yellow
Write-Host "Features created: $totalFeatures" -ForegroundColor Yellow
Write-Host "Tasks created: $totalTasks" -ForegroundColor Yellow
Write-Host "Total issues: $($allCreatedIssues.Count)" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host ""
    Write-Host "=== DryRun Mode - No issues were created ===" -ForegroundColor Cyan
}

Write-Host ""
Write-Log -Message "Plan materialization completed successfully" -Level Info

# Return results
return [PSCustomObject]@{
    Success = $true
    Phases = $allPhases
    TotalEpics = $totalEpics
    TotalFeatures = $totalFeatures
    TotalTasks = $totalTasks
    TotalIssues = $allCreatedIssues.Count
    CorrelationId = $CorrelationId
}
