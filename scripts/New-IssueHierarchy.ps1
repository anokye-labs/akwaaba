<#
.SYNOPSIS
    Create a complete Epic → Feature → Task tree in one call.

.DESCRIPTION
    This script creates a complete issue hierarchy (Epic → Feature → Task) with a single call.
    It accepts a hashtable or JSON defining the tree structure, creates all issues in the correct
    order (leaves first, root last), wires up all tasklist relationships, adds all issues to a
    project board, and returns issue numbers and URLs.

.PARAMETER Owner
    Repository owner (username or organization).

.PARAMETER Repo
    Repository name.

.PARAMETER HierarchyDefinition
    A hashtable defining the issue hierarchy structure. Expected format:
    @{
        Type = "Epic"          # Epic, Feature, or Task
        Title = "Epic title"
        Body = "Description"
        Labels = @("label1")   # Optional
        Children = @(          # Optional array of child issues
            @{
                Type = "Feature"
                Title = "Feature title"
                Body = "Description"
                Children = @(...)
            }
        )
    }

.PARAMETER ProjectNumber
    Optional GitHub Projects V2 project number to add all created issues to.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.PARAMETER DryRun
    If specified, simulates the creation without actually creating issues.

.EXAMPLE
    $hierarchy = @{
        Type = "Epic"
        Title = "Phase 2 Development"
        Body = "Complete phase 2 of the project"
        Children = @(
            @{
                Type = "Feature"
                Title = "User Authentication"
                Body = "Implement user auth"
                Children = @(
                    @{ Type = "Task"; Title = "Create login page" }
                    @{ Type = "Task"; Title = "Setup OAuth" }
                )
            }
        )
    }
    
    $result = ./New-IssueHierarchy.ps1 -Owner "anokye-labs" -Repo "akwaaba" -HierarchyDefinition $hierarchy
    Write-Host "Created Epic: #$($result.Epic.Number)"

.EXAMPLE
    # Create from JSON file
    $json = Get-Content hierarchy.json | ConvertFrom-Json -AsHashtable
    ./New-IssueHierarchy.ps1 -Owner "anokye-labs" -Repo "akwaaba" -HierarchyDefinition $json -ProjectNumber 3

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - Epic/Feature/Task: Created issue details (number, url, id)
    - AllIssues: Flat array of all created issues
    - Errors: Array of any errors encountered
    - CorrelationId: The correlation ID for this request

.NOTES
    Dependencies:
    - Invoke-GraphQL.ps1 (for GraphQL API calls)
    - ConvertTo-EscapedGraphQL.ps1 (for escaping text)
    - Write-OkyeremaLog.ps1 (for structured logging)
    
    This script creates issues in leaf-first order (Tasks → Features → Epic) to ensure
    child issues exist before creating parent tasklists.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $true)]
    [hashtable]$HierarchyDefinition,

    [Parameter(Mandatory = $false)]
    [int]$ProjectNumber,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Import dependencies
$scriptRoot = $PSScriptRoot
. "$scriptRoot/Invoke-GraphQL.ps1"
. "$scriptRoot/ConvertTo-EscapedGraphQL.ps1"
. "$scriptRoot/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

Write-OkyeremaLog -Message "Starting issue hierarchy creation" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId

# Validate hierarchy structure
function Test-HierarchyDefinition {
    param([hashtable]$Definition, [string]$Path = "root")
    
    if (-not $Definition.Type) {
        throw "Missing 'Type' at $Path"
    }
    
    if ($Definition.Type -notin @("Epic", "Feature", "Task", "Bug")) {
        throw "Invalid Type '$($Definition.Type)' at $Path. Must be Epic, Feature, Task, or Bug."
    }
    
    if (-not $Definition.Title) {
        throw "Missing 'Title' at $Path"
    }
    
    if ($Definition.Children) {
        $childIndex = 0
        foreach ($child in $Definition.Children) {
            Test-HierarchyDefinition -Definition $child -Path "$Path.Children[$childIndex]"
            $childIndex++
        }
    }
}

Write-OkyeremaLog -Message "Validating hierarchy definition" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
Test-HierarchyDefinition -Definition $HierarchyDefinition

# Get repository ID and issue type IDs
Write-OkyeremaLog -Message "Fetching repository and issue type metadata" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId

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

$metadataResult = Invoke-GraphQL -Query $metadataQuery -CorrelationId $CorrelationId -DryRun:$DryRun

if (-not $metadataResult.Success) {
    Write-OkyeremaLog -Message "Failed to fetch repository metadata" -Level Error -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    return [PSCustomObject]@{
        Success       = $false
        AllIssues     = @()
        Errors        = $metadataResult.Errors
        CorrelationId = $CorrelationId
    }
}

$repositoryId = $metadataResult.Data.repository.id
$issueTypes = @{}
foreach ($type in $metadataResult.Data.repository.owner.issueTypes.nodes) {
    $issueTypes[$type.name] = $type.id
}

Write-OkyeremaLog -Message "Repository ID: $repositoryId" -Level Debug -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId

# Get project ID if project number provided
$projectId = $null
if ($ProjectNumber) {
    Write-OkyeremaLog -Message "Fetching project $ProjectNumber" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    $projectQuery = @"
query {
  organization(login: "$Owner") {
    projectV2(number: $ProjectNumber) {
      id
    }
  }
}
"@
    
    $projectResult = Invoke-GraphQL -Query $projectQuery -CorrelationId $CorrelationId -DryRun:$DryRun
    
    if ($projectResult.Success -and $projectResult.Data.organization.projectV2) {
        $projectId = $projectResult.Data.organization.projectV2.id
        Write-OkyeremaLog -Message "Project ID: $projectId" -Level Debug -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    } else {
        Write-OkyeremaLog -Message "Project $ProjectNumber not found" -Level Warn -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    }
}

# Create a single issue
function New-SingleIssue {
    param(
        [string]$Title,
        [string]$Body,
        [string]$TypeName,
        [string[]]$Labels = @()
    )
    
    $typeId = $issueTypes[$TypeName]
    if (-not $typeId) {
        throw "Issue type '$TypeName' not found. Available: $($issueTypes.Keys -join ', ')"
    }
    
    $escapedTitle = $Title | ConvertTo-EscapedGraphQL
    $escapedBody = if ($Body) { $Body | ConvertTo-EscapedGraphQL } else { "" }
    
    $mutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$repositoryId"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$typeId"
  }) {
    issue {
      id
      number
      title
      url
      issueType { name }
    }
  }
}
"@
    
    Write-OkyeremaLog -Message "Creating $TypeName issue: $Title" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    $result = Invoke-GraphQL -Query $mutation -CorrelationId $CorrelationId -DryRun:$DryRun
    
    if (-not $result.Success) {
        throw "Failed to create $TypeName issue '$Title': $($result.Errors[0].Message)"
    }
    
    $issue = $result.Data.createIssue.issue
    
    Write-OkyeremaLog -Message "Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    # Add labels if provided
    if ($Labels.Count -gt 0) {
        # TODO: Implement label addition via GraphQL if needed
        Write-OkyeremaLog -Message "Label addition not yet implemented" -Level Warn -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    }
    
    return $issue
}

# Add issue to project
function Add-IssueToProject {
    param([string]$IssueId)
    
    if (-not $projectId) {
        return
    }
    
    $mutation = @"
mutation {
  addProjectV2ItemById(input: {
    projectId: "$projectId"
    contentId: "$IssueId"
  }) {
    item {
      id
    }
  }
}
"@
    
    Write-OkyeremaLog -Message "Adding issue to project $ProjectNumber" -Level Debug -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    $result = Invoke-GraphQL -Query $mutation -CorrelationId $CorrelationId -DryRun:$DryRun
    
    if (-not $result.Success) {
        Write-OkyeremaLog -Message "Failed to add issue to project: $($result.Errors[0].Message)" -Level Warn -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    }
}

# Update parent issue with tasklist
function Update-ParentTasklist {
    param(
        [string]$ParentId,
        [string]$ParentBody,
        [array]$ChildNumbers,
        [string]$ChildTypePlural
    )
    
    # Build tasklist section
    $tasklist = "`n`n## 📋 Tracked $ChildTypePlural`n"
    foreach ($num in $ChildNumbers | Sort-Object) {
        $tasklist += "`n- [ ] #$num"
    }
    
    $newBody = $ParentBody + $tasklist
    $escapedBody = $newBody | ConvertTo-EscapedGraphQL
    
    $mutation = @"
mutation {
  updateIssue(input: {
    id: "$ParentId"
    body: "$escapedBody"
  }) {
    issue {
      number
    }
  }
}
"@
    
    Write-OkyeremaLog -Message "Updating parent tasklist with $($ChildNumbers.Count) children" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    $result = Invoke-GraphQL -Query $mutation -CorrelationId $CorrelationId -DryRun:$DryRun
    
    if (-not $result.Success) {
        throw "Failed to update parent tasklist: $($result.Errors[0].Message)"
    }
}

# Recursively create issues (depth-first, leaves first)
function New-IssueTreeRecursive {
    param([hashtable]$Definition)
    
    $createdIssues = @()
    
    # First, create all children recursively
    if ($Definition.Children) {
        foreach ($child in $Definition.Children) {
            $childResults = New-IssueTreeRecursive -Definition $child
            $createdIssues += $childResults
        }
    }
    
    # Then create this issue
    $issue = New-SingleIssue `
        -Title $Definition.Title `
        -Body ($Definition.Body ?? "") `
        -TypeName $Definition.Type `
        -Labels ($Definition.Labels ?? @())
    
    # Add to project
    Add-IssueToProject -IssueId $issue.id
    
    # If this issue has children, update its body with tasklist
    if ($Definition.Children -and $Definition.Children.Count -gt 0) {
        $childNumbers = $createdIssues | ForEach-Object { $_.number }
        
        # Determine child type plural
        $childType = $Definition.Children[0].Type
        $childTypePlural = if ($childType -eq "Feature") { "Features" } else { "Tasks" }
        
        Update-ParentTasklist `
            -ParentId $issue.id `
            -ParentBody ($Definition.Body ?? "") `
            -ChildNumbers $childNumbers `
            -ChildTypePlural $childTypePlural
    }
    
    # Add current issue to results
    $createdIssues += $issue
    
    return $createdIssues
}

# Create the entire hierarchy
try {
    Write-OkyeremaLog -Message "Creating issue hierarchy tree" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    $allIssues = New-IssueTreeRecursive -Definition $HierarchyDefinition
    
    Write-OkyeremaLog -Message "Successfully created $($allIssues.Count) issues" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    # Build result object
    $rootIssue = $allIssues[-1]  # Last created is the root
    
    $result = [PSCustomObject]@{
        Success       = $true
        Root          = [PSCustomObject]@{
            Number = $rootIssue.number
            Url    = $rootIssue.url
            Id     = $rootIssue.id
            Type   = $rootIssue.issueType.name
            Title  = $rootIssue.title
        }
        AllIssues     = $allIssues | ForEach-Object {
            [PSCustomObject]@{
                Number = $_.number
                Url    = $_.url
                Id     = $_.id
                Type   = $_.issueType.name
                Title  = $_.title
            }
        }
        Errors        = @()
        CorrelationId = $CorrelationId
    }
    
    Write-OkyeremaLog -Message "Issue hierarchy creation complete" -Level Info -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    return $result
}
catch {
    Write-OkyeremaLog -Message "Error creating hierarchy: $_" -Level Error -Operation "NewIssueHierarchy" -CorrelationId $CorrelationId
    
    return [PSCustomObject]@{
        Success       = $false
        AllIssues     = @()
        Errors        = @([PSCustomObject]@{
            Message = $_.Exception.Message
            Type    = "HierarchyCreationError"
        })
        CorrelationId = $CorrelationId
    }
}
