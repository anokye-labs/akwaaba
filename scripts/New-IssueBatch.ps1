<#
.SYNOPSIS
    Create multiple GitHub issues from a JSON/CSV input file with type support and relationship wiring.

.DESCRIPTION
    New-IssueBatch.ps1 creates multiple GitHub issues in batch from a JSON or CSV input file.
    Each entry specifies title, type, body, labels, and optional parent issue reference.
    
    The script performs two phases:
    1. Create all issues with proper organization issue types
    2. Wire parent-child relationships after all issues are created
    
    Features:
    - Progress bar for large batches
    - DryRun mode to preview operations
    - Structured logging via Write-OkyeremaLog
    - Correlation ID for tracing
    - Support for CSV and JSON input formats

.PARAMETER InputFile
    Path to the JSON or CSV file containing issue definitions.
    
    JSON format example:
    [
      {
        "title": "Epic Issue",
        "type": "Epic",
        "body": "Description",
        "labels": ["documentation", "enhancement"],
        "parent": null
      },
      {
        "title": "Child Task",
        "type": "Task",
        "body": "Task description",
        "labels": ["bug"],
        "parent": 1
      }
    ]
    
    CSV format example:
    title,type,body,labels,parent
    "Epic Issue",Epic,"Description","documentation;enhancement",
    "Child Task",Task,"Task description","bug",1

.PARAMETER Owner
    Repository owner (username or organization).

.PARAMETER Repo
    Repository name.

.PARAMETER DryRun
    If specified, previews operations without creating issues.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.PARAMETER Quiet
    Suppress structured logging output.

.OUTPUTS
    Returns an array of created issue objects with properties:
    - Index: Original index from input file
    - Number: GitHub issue number (null in DryRun mode)
    - Title: Issue title
    - Type: Issue type
    - Url: Issue URL
    - Parent: Parent index reference (if specified)

.EXAMPLE
    .\New-IssueBatch.ps1 -InputFile issues.json -Owner anokye-labs -Repo akwaaba
    Creates issues from JSON file.

.EXAMPLE
    .\New-IssueBatch.ps1 -InputFile issues.csv -Owner anokye-labs -Repo akwaaba -DryRun
    Previews operations without creating issues.

.EXAMPLE
    .\New-IssueBatch.ps1 -InputFile issues.json -Owner anokye-labs -Repo akwaaba -Quiet
    Creates issues with suppressed logging.

.NOTES
    Dependencies:
    - Invoke-GraphQL.ps1 (for GraphQL execution)
    - ConvertTo-EscapedGraphQL.ps1 (for string escaping)
    - Write-OkyeremaLog.ps1 (for structured logging)
    - GitHub CLI (gh) installed and authenticated
    
    Input file requirements:
    - title: Required, issue title
    - type: Required, one of: Epic, Feature, Task, Bug
    - body: Optional, issue description
    - labels: Optional, array (JSON) or semicolon-separated (CSV)
    - parent: Optional, 1-based index referencing another issue in the batch
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_})]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Import dependencies
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$invokeGraphQLPath = Join-Path $scriptDir "Invoke-GraphQL.ps1"
$convertEscapePath = Join-Path $scriptDir "ConvertTo-EscapedGraphQL.ps1"
$writeLogPath = Join-Path (Split-Path $scriptDir) ".github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

if (-not (Test-Path $invokeGraphQLPath)) {
    throw "Dependency not found: Invoke-GraphQL.ps1. Expected at: $invokeGraphQLPath"
}
if (-not (Test-Path $convertEscapePath)) {
    throw "Dependency not found: ConvertTo-EscapedGraphQL.ps1. Expected at: $convertEscapePath"
}
if (-not (Test-Path $writeLogPath)) {
    throw "Dependency not found: Write-OkyeremaLog.ps1. Expected at: $writeLogPath"
}

# Dot-source function scripts only (ConvertTo-EscapedGraphQL is a function)
. $convertEscapePath

# Helper function to invoke GraphQL (wraps Invoke-GraphQL.ps1 script)
function Invoke-GraphQL {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        [hashtable]$Variables = @{},
        [switch]$DryRun,
        [string]$CorrelationId
    )
    
    $args = @{
        Query = $Query
        Variables = $Variables
    }
    
    if ($DryRun) {
        $args.DryRun = $true
    }
    
    if ($CorrelationId) {
        $args.CorrelationId = $CorrelationId
    }
    
    return & $invokeGraphQLPath @args
}

# Helper function to write logs (wraps Write-OkyeremaLog.ps1 script)
function Write-OkyeremaLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "",
        [string]$CorrelationId = "",
        [switch]$Quiet
    )
    
    $args = @{
        Message = $Message
        Level = $Level
    }
    
    if ($Operation) {
        $args.Operation = $Operation
    }
    
    if ($CorrelationId) {
        $args.CorrelationId = $CorrelationId
    }
    
    if ($Quiet) {
        $args.Quiet = $true
    }
    
    & $writeLogPath @args
}

# Helper function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    Write-OkyeremaLog -Message $Message -Level $Level -Operation "New-IssueBatch" -CorrelationId $CorrelationId -Quiet:$Quiet
}

Write-Log "Starting batch issue creation" -Level "Info"
Write-Log "Input file: $InputFile" -Level "Info"
Write-Log "Target: $Owner/$Repo" -Level "Info"

# Parse input file
$extension = [System.IO.Path]::GetExtension($InputFile).ToLower()
$entries = @()

try {
    if ($extension -eq ".json") {
        Write-Log "Parsing JSON input file" -Level "Info"
        $entries = Get-Content $InputFile -Raw | ConvertFrom-Json
    }
    elseif ($extension -eq ".csv") {
        Write-Log "Parsing CSV input file" -Level "Info"
        $csvData = Import-Csv $InputFile
        $entries = $csvData | ForEach-Object {
            [PSCustomObject]@{
                title = $_.title
                type = $_.type
                body = if ($_.body) { $_.body } else { "" }
                labels = if ($_.labels) { $_.labels -split ";" } else { @() }
                parent = if ($_.parent) { [int]$_.parent } else { $null }
            }
        }
    }
    else {
        throw "Unsupported file format: $extension. Only .json and .csv are supported."
    }
}
catch {
    Write-Log "Failed to parse input file: $_" -Level "Error"
    throw
}

if (-not $entries -or $entries.Count -eq 0) {
    Write-Log "No entries found in input file" -Level "Error"
    throw "Input file contains no entries"
}

Write-Log "Parsed $($entries.Count) entries from input file" -Level "Info"

# Validate entries
for ($i = 0; $i -lt $entries.Count; $i++) {
    $entry = $entries[$i]
    $index = $i + 1
    
    if (-not $entry.title) {
        throw "Entry $index is missing required field: title"
    }
    if (-not $entry.type) {
        throw "Entry $index is missing required field: type"
    }
    if ($entry.type -notin @("Epic", "Feature", "Task", "Bug")) {
        throw "Entry $index has invalid type: $($entry.type). Must be one of: Epic, Feature, Task, Bug"
    }
    if ($entry.parent) {
        if ($entry.parent -lt 1 -or $entry.parent -gt $entries.Count) {
            throw "Entry $index has invalid parent reference: $($entry.parent). Must be between 1 and $($entries.Count)"
        }
        if ($entry.parent -ge $index) {
            throw "Entry $index has forward parent reference: $($entry.parent). Parent must be defined before child"
        }
    }
}

Write-Log "All entries validated successfully" -Level "Info"

# Fetch repository context
Write-Log "Fetching repository context" -Level "Info"

$contextQuery = @"
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

$contextResult = Invoke-GraphQL -Query $contextQuery -DryRun:$DryRun -CorrelationId $CorrelationId

if (-not $contextResult.Success) {
    Write-Log "Failed to fetch repository context" -Level "Error"
    $contextResult.Errors | ForEach-Object {
        Write-Log "Error: $($_.Message)" -Level "Error"
    }
    throw "Failed to fetch repository context"
}

if ($DryRun) {
    Write-Log "DryRun mode: Repository context would be fetched" -Level "Info"
    $repoId = "DRY_RUN_REPO_ID"
    $issueTypes = @(
        @{ name = "Epic"; id = "DRY_RUN_EPIC_ID" }
        @{ name = "Feature"; id = "DRY_RUN_FEATURE_ID" }
        @{ name = "Task"; id = "DRY_RUN_TASK_ID" }
        @{ name = "Bug"; id = "DRY_RUN_BUG_ID" }
    )
}
else {
    $repoId = $contextResult.Data.repository.id
    $issueTypes = $contextResult.Data.repository.owner.issueTypes.nodes
    
    if (-not $issueTypes -or $issueTypes.Count -eq 0) {
        throw "No issue types found for organization. Ensure the repository is owned by an organization with issue types configured."
    }
    
    Write-Log "Repository ID: $repoId" -Level "Info"
    Write-Log "Available issue types: $($issueTypes.name -join ', ')" -Level "Info"
}

# Phase 1: Create all issues
Write-Log "Phase 1: Creating $($entries.Count) issues" -Level "Info"
$createdIssues = @()

for ($i = 0; $i -lt $entries.Count; $i++) {
    $entry = $entries[$i]
    $index = $i + 1
    $percentComplete = [int](($i / $entries.Count) * 100)
    
    Write-Progress -Activity "Creating issues" -Status "Creating issue $index of $($entries.Count): $($entry.title)" -PercentComplete $percentComplete
    
    # Find type ID
    $typeId = ($issueTypes | Where-Object { $_.name -eq $entry.type }).id
    if (-not $typeId) {
        Write-Log "Issue type '$($entry.type)' not found for entry $index" -Level "Error"
        throw "Issue type '$($entry.type)' not found. Available types: $($issueTypes.name -join ', ')"
    }
    
    # Escape title and body
    $escapedTitle = $entry.title | ConvertTo-EscapedGraphQL
    $escapedBody = if ($entry.body) { $entry.body | ConvertTo-EscapedGraphQL } else { "" }
    
    # Build mutation
    $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$repoId"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$typeId"
  }) {
    issue {
      id
      number
      title
      issueType { name }
      url
    }
  }
}
"@
    
    Write-Log "Creating issue $index/$($entries.Count): [$($entry.type)] $($entry.title)" -Level "Info"
    
    $issueResult = Invoke-GraphQL -Query $mutation -DryRun:$DryRun -CorrelationId $CorrelationId
    
    if (-not $issueResult.Success) {
        Write-Log "Failed to create issue $index" -Level "Error"
        $issueResult.Errors | ForEach-Object {
            Write-Log "Error: $($_.Message)" -Level "Error"
        }
        throw "Failed to create issue $index"
    }
    
    if ($DryRun) {
        $createdIssue = [PSCustomObject]@{
            Index = $index
            Id = "DRY_RUN_ISSUE_ID_$index"
            Number = $null
            Title = $entry.title
            Type = $entry.type
            Url = "https://github.com/$Owner/$Repo/issues/DRY_RUN"
            Parent = $entry.parent
            Labels = $entry.labels
        }
        Write-Log "DryRun: Would create issue #$index [$($entry.type)] $($entry.title)" -Level "Info"
    }
    else {
        $issue = $issueResult.Data.createIssue.issue
        $createdIssue = [PSCustomObject]@{
            Index = $index
            Id = $issue.id
            Number = $issue.number
            Title = $issue.title
            Type = $issue.issueType.name
            Url = $issue.url
            Parent = $entry.parent
            Labels = $entry.labels
        }
        Write-Log "Created issue #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -Level "Info"
    }
    
    $createdIssues += $createdIssue
    
    # Add labels if specified
    if ($entry.labels -and $entry.labels.Count -gt 0 -and -not $DryRun) {
        Write-Log "Adding labels to issue #$($createdIssue.Number): $($entry.labels -join ', ')" -Level "Info"
        
        # Fetch label IDs
        $labelQuery = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    labels(first: 100) {
      nodes { id name }
    }
  }
}
"@
        
        $labelResult = Invoke-GraphQL -Query $labelQuery -CorrelationId $CorrelationId
        
        if ($labelResult.Success) {
            $allLabels = $labelResult.Data.repository.labels.nodes
            $labelIds = $entry.labels | ForEach-Object {
                $labelName = $_
                ($allLabels | Where-Object { $_.name -eq $labelName }).id
            } | Where-Object { $_ }
            
            if ($labelIds.Count -gt 0) {
                $labelIdList = ($labelIds | ForEach-Object { "`"$_`"" }) -join ', '
                $labelMutation = @"
mutation {
  addLabelsToLabelable(input: {
    labelableId: "$($createdIssue.Id)"
    labelIds: [$labelIdList]
  }) {
    labelable {
      ... on Issue { number }
    }
  }
}
"@
                
                $labelAddResult = Invoke-GraphQL -Query $labelMutation -CorrelationId $CorrelationId
                
                if ($labelAddResult.Success) {
                    Write-Log "Added labels to issue #$($createdIssue.Number)" -Level "Info"
                }
                else {
                    Write-Log "Warning: Failed to add labels to issue #$($createdIssue.Number)" -Level "Warn"
                }
            }
            
            # Warn about missing labels
            $missingLabels = $entry.labels | Where-Object { $_ -notin ($allLabels.name) }
            if ($missingLabels) {
                Write-Log "Warning: Labels not found in repository: $($missingLabels -join ', ')" -Level "Warn"
            }
        }
    }
    elseif ($entry.labels -and $entry.labels.Count -gt 0 -and $DryRun) {
        Write-Log "DryRun: Would add labels: $($entry.labels -join ', ')" -Level "Info"
    }
}

Write-Progress -Activity "Creating issues" -Completed

Write-Log "Phase 1 complete: Created $($createdIssues.Count) issues" -Level "Info"

# Phase 2: Wire parent-child relationships
Write-Log "Phase 2: Wiring parent-child relationships" -Level "Info"

$parentsToUpdate = @{}

foreach ($issue in $createdIssues) {
    if ($issue.Parent) {
        $parentIndex = $issue.Parent
        
        if (-not $parentsToUpdate.ContainsKey($parentIndex)) {
            $parentsToUpdate[$parentIndex] = @()
        }
        
        $parentsToUpdate[$parentIndex] += $issue.Index
    }
}

if ($parentsToUpdate.Count -eq 0) {
    Write-Log "No parent-child relationships to wire" -Level "Info"
}
else {
    Write-Log "Found $($parentsToUpdate.Count) parent(s) with children to wire" -Level "Info"
    
    $relationshipIndex = 0
    $totalRelationships = $parentsToUpdate.Count
    
    foreach ($parentIndex in $parentsToUpdate.Keys) {
        $relationshipIndex++
        $percentComplete = [int](($relationshipIndex / $totalRelationships) * 100)
        
        $parent = $createdIssues | Where-Object { $_.Index -eq $parentIndex }
        $childIndices = $parentsToUpdate[$parentIndex]
        $children = $createdIssues | Where-Object { $_.Index -in $childIndices }
        
        Write-Progress -Activity "Wiring relationships" -Status "Updating parent $relationshipIndex of $totalRelationships" -PercentComplete $percentComplete
        
        if ($DryRun) {
            Write-Log "DryRun: Would update parent #$($parent.Index) with $($children.Count) children" -Level "Info"
            foreach ($child in $children) {
                Write-Log "DryRun: Would link child #$($child.Index) to parent #$($parent.Index)" -Level "Info"
            }
        }
        else {
            Write-Log "Updating parent #$($parent.Number) with $($children.Count) children" -Level "Info"
            
            # Fetch parent's current body
            $parentQuery = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $($parent.Number)) {
      id
      body
    }
  }
}
"@
            
            $parentResult = Invoke-GraphQL -Query $parentQuery -CorrelationId $CorrelationId
            
            if (-not $parentResult.Success) {
                Write-Log "Warning: Failed to fetch parent #$($parent.Number)" -Level "Warn"
                continue
            }
            
            $parentId = $parentResult.Data.repository.issue.id
            $parentBody = $parentResult.Data.repository.issue.body
            if (-not $parentBody) { $parentBody = "" }
            
            # Remove existing tasklist section
            $lines = $parentBody -split "`n"
            $cleanLines = @()
            $inTasklist = $false
            
            foreach ($line in $lines) {
                if ($line -match '^## [\p{So}\s]*Tracked (Tasks|Features|Items)') {
                    $inTasklist = $true
                    continue
                }
                if ($inTasklist -and $line -match '^- \[') { continue }
                if ($inTasklist -and $line -match '^\s*$') { continue }
                if ($inTasklist -and $line -match '^##') { $inTasklist = $false }
                if (-not $inTasklist) { $cleanLines += $line }
            }
            
            $cleanBody = ($cleanLines -join "`n").TrimEnd()
            
            # Determine child type for section header
            $childTypes = $children | Select-Object -ExpandProperty Type -Unique
            $sectionName = if ($childTypes.Count -eq 1) {
                if ($childTypes[0] -eq "Task") { "Tasks" }
                elseif ($childTypes[0] -eq "Feature") { "Features" }
                else { "Items" }
            } else { "Items" }
            
            # Build new tasklist
            $tasklist = "`n`n## Tracked $sectionName`n`n"
            foreach ($child in ($children | Sort-Object { $_.Number })) {
                $tasklist += "- [ ] #$($child.Number)`n"
            }
            
            $newBody = $cleanBody + $tasklist
            $escapedBody = $newBody | ConvertTo-EscapedGraphQL
            
            # Update parent issue
            $updateMutation = @"
mutation {
  updateIssue(input: {
    id: "$parentId"
    body: "$escapedBody"
  }) {
    issue { number }
  }
}
"@
            
            $updateResult = Invoke-GraphQL -Query $updateMutation -CorrelationId $CorrelationId
            
            if ($updateResult.Success) {
                Write-Log "Updated parent #$($parent.Number) with $($children.Count) tracked $sectionName" -Level "Info"
                $childNumbers = $children | ForEach-Object { "#$($_.Number)" }
                Write-Log "Linked children: $($childNumbers -join ', ')" -Level "Info"
            }
            else {
                Write-Log "Warning: Failed to update parent #$($parent.Number)" -Level "Warn"
                $updateResult.Errors | ForEach-Object {
                    Write-Log "Error: $($_.Message)" -Level "Error"
                }
            }
        }
    }
    
    Write-Progress -Activity "Wiring relationships" -Completed
    
    if (-not $DryRun) {
        Write-Log "Phase 2 complete: Wired relationships for $($parentsToUpdate.Count) parent(s)" -Level "Info"
        Write-Host ""
        Write-Host "⏰ Note: GitHub needs 2-5 minutes to parse tasklist relationships" -ForegroundColor Yellow
        Write-Host "   Use Test-Hierarchy.ps1 to verify relationships after waiting" -ForegroundColor Yellow
    }
}

Write-Log "Batch issue creation complete" -Level "Info"

# Output summary
if ($DryRun) {
    Write-Host ""
    Write-Host "=== DryRun Summary ===" -ForegroundColor Cyan
    Write-Host "Would create $($createdIssues.Count) issues:" -ForegroundColor Cyan
    foreach ($issue in $createdIssues) {
        $parentInfo = if ($issue.Parent) { " (child of #$($issue.Parent))" } else { "" }
        Write-Host "  [$($issue.Type)] $($issue.Title)$parentInfo" -ForegroundColor Yellow
    }
    if ($parentsToUpdate.Count -gt 0) {
        Write-Host "Would wire $($parentsToUpdate.Count) parent-child relationship(s)" -ForegroundColor Cyan
    }
    Write-Host "==================" -ForegroundColor Cyan
}
else {
    Write-Host ""
    Write-Host "=== Created Issues ===" -ForegroundColor Green
    foreach ($issue in $createdIssues) {
        $parentInfo = if ($issue.Parent) { " (child of #$($createdIssues[$issue.Parent - 1].Number))" } else { "" }
        Write-Host "  #$($issue.Number) [$($issue.Type)] $($issue.Title)$parentInfo" -ForegroundColor White
        Write-Host "  $($issue.Url)" -ForegroundColor Gray
    }
    Write-Host "==================" -ForegroundColor Green
}

# Return created issues
return $createdIssues
