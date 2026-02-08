<#
.SYNOPSIS
    Create issue graph from a JSON DAG definition.

.DESCRIPTION
    Import-DagFromJson.ps1 creates GitHub issues from a JSON DAG (Directed Acyclic Graph)
    definition. It performs topological sorting to create issues in dependency order,
    then builds tasklist relationships in GitHub to establish parent-child hierarchies.
    
    The script:
    - Parses and validates JSON DAG input
    - Performs topological sort to determine creation order
    - Creates issues using GitHub GraphQL API
    - Builds tasklist relationships using issue body updates
    - Supports DryRun mode for validation without execution

.PARAMETER JsonPath
    Path to JSON file containing the DAG definition.

.PARAMETER JsonString
    JSON string containing the DAG definition (alternative to JsonPath).

.PARAMETER DryRun
    If specified, validates the DAG and shows the execution plan without creating issues.

.PARAMETER CorrelationId
    Optional correlation ID for tracing operations across logs.

.PARAMETER Quiet
    If specified, suppresses log output from Write-OkyeremaLog.

.INPUTS
    JSON format:
    {
      "nodes": [
        {
          "id": "epic-1",
          "title": "Epic Issue Title",
          "type": "Epic",
          "body": "Issue description"
        }
      ],
      "edges": [
        {
          "from": "epic-1",
          "to": "feature-1",
          "relationship": "tracks"
        }
      ]
    }

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - CreatedIssues: Hashtable mapping node IDs to created issue numbers
    - Errors: Array of error messages (if any)
    - CorrelationId: The correlation ID for this operation

.EXAMPLE
    .\Import-DagFromJson.ps1 -JsonPath "dag.json"
    Creates issues from the DAG definition in dag.json.

.EXAMPLE
    .\Import-DagFromJson.ps1 -JsonPath "dag.json" -DryRun
    Validates the DAG and shows execution plan without creating issues.

.EXAMPLE
    $json = '{"nodes":[{"id":"epic-1","title":"My Epic","type":"Epic","body":"Description"}],"edges":[]}'
    .\Import-DagFromJson.ps1 -JsonString $json

.NOTES
    Requires:
    - PowerShell 7.x or higher
    - GitHub CLI (gh) installed and authenticated
    - Invoke-GraphQL.ps1
    - ConvertTo-EscapedGraphQL.ps1
    - Write-OkyeremaLog.ps1
    
    Dependencies: anokye-labs/akwaaba#14, #16, #17
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, ParameterSetName = "FromFile")]
    [string]$JsonPath,

    [Parameter(Mandatory = $false, ParameterSetName = "FromString")]
    [string]$JsonString,

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
. "$scriptDir/ConvertTo-EscapedGraphQL.ps1"
$invokeGraphQLPath = "$scriptDir/Invoke-GraphQL.ps1"

# Locate Write-OkyeremaLog.ps1 relative to repository root
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    $writeLogPath = Join-Path $repoRoot ".github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"
} else {
    # Fallback to relative path
    $writeLogPath = "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"
}

if (-not (Test-Path $writeLogPath)) {
    throw "Write-OkyeremaLog.ps1 not found at: $writeLogPath"
}

# Helper function to write logs
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    & $writeLogPath -Message $Message -Level $Level -Operation "Import-DagFromJson" -CorrelationId $CorrelationId -Quiet:$Quiet
}

Write-Log -Message "Starting DAG import (DryRun: $DryRun)" -Level "Info"

# Parse JSON input
try {
    if ($JsonPath) {
        Write-Log -Message "Reading JSON from file: $JsonPath" -Level "Info"
        if (-not (Test-Path $JsonPath)) {
            throw "JSON file not found: $JsonPath"
        }
        $dagJson = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    }
    elseif ($JsonString) {
        Write-Log -Message "Parsing JSON from string" -Level "Info"
        $dagJson = $JsonString | ConvertFrom-Json
    }
    else {
        throw "Must provide either -JsonPath or -JsonString parameter"
    }
}
catch {
    Write-Log -Message "Failed to parse JSON: $_" -Level "Error"
    return [PSCustomObject]@{
        Success       = $false
        CreatedIssues = @{}
        Errors        = @("Failed to parse JSON: $_")
        CorrelationId = $CorrelationId
    }
}

Write-Log -Message "JSON parsed successfully" -Level "Info"

# Validate JSON structure
if (-not $dagJson.nodes) {
    Write-Log -Message "JSON missing 'nodes' array" -Level "Error"
    return [PSCustomObject]@{
        Success       = $false
        CreatedIssues = @{}
        Errors        = @("JSON missing 'nodes' array")
        CorrelationId = $CorrelationId
    }
}

if (-not $dagJson.edges) {
    Write-Log -Message "JSON missing 'edges' array, assuming no relationships" -Level "Warn"
    $dagJson | Add-Member -MemberType NoteProperty -Name edges -Value @() -Force
}

Write-Log -Message "Validating DAG structure (nodes: $($dagJson.nodes.Count), edges: $($dagJson.edges.Count))" -Level "Info"

# Validate nodes
$nodeIds = @{}
foreach ($node in $dagJson.nodes) {
    if (-not $node.id) {
        Write-Log -Message "Node missing 'id' property" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Node missing 'id' property")
            CorrelationId = $CorrelationId
        }
    }
    
    if ($nodeIds.ContainsKey($node.id)) {
        Write-Log -Message "Duplicate node ID: $($node.id)" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Duplicate node ID: $($node.id)")
            CorrelationId = $CorrelationId
        }
    }
    
    $nodeIds[$node.id] = $true
    
    if (-not $node.title) {
        Write-Log -Message "Node '$($node.id)' missing 'title' property" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Node '$($node.id)' missing 'title' property")
            CorrelationId = $CorrelationId
        }
    }
    
    if (-not $node.type) {
        Write-Log -Message "Node '$($node.id)' missing 'type' property" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Node '$($node.id)' missing 'type' property")
            CorrelationId = $CorrelationId
        }
    }
}

Write-Log -Message "All nodes validated successfully" -Level "Info"

# Validate edges and build adjacency lists
$adjacencyList = @{}
$reverseAdjacencyList = @{}
$inDegree = @{}

foreach ($nodeId in $nodeIds.Keys) {
    $adjacencyList[$nodeId] = @()
    $reverseAdjacencyList[$nodeId] = @()
    $inDegree[$nodeId] = 0
}

foreach ($edge in $dagJson.edges) {
    if (-not $edge.from) {
        Write-Log -Message "Edge missing 'from' property" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Edge missing 'from' property")
            CorrelationId = $CorrelationId
        }
    }
    
    if (-not $edge.to) {
        Write-Log -Message "Edge missing 'to' property" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Edge missing 'to' property")
            CorrelationId = $CorrelationId
        }
    }
    
    if (-not $nodeIds.ContainsKey($edge.from)) {
        Write-Log -Message "Edge references non-existent node: $($edge.from)" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Edge references non-existent node: $($edge.from)")
            CorrelationId = $CorrelationId
        }
    }
    
    if (-not $nodeIds.ContainsKey($edge.to)) {
        Write-Log -Message "Edge references non-existent node: $($edge.to)" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = @{}
            Errors        = @("Edge references non-existent node: $($edge.to)")
            CorrelationId = $CorrelationId
        }
    }
    
    # Build adjacency list (from -> to means 'from' tracks 'to')
    $adjacencyList[$edge.from] += $edge.to
    $reverseAdjacencyList[$edge.to] += $edge.from
    $inDegree[$edge.to]++
}

Write-Log -Message "Edges validated and adjacency lists built" -Level "Info"

# Perform topological sort using Kahn's algorithm
Write-Log -Message "Performing topological sort" -Level "Info"

$sortedNodes = @()
$queue = [System.Collections.Queue]::new()

# Start with nodes that have no dependencies (in-degree = 0)
foreach ($nodeId in $nodeIds.Keys) {
    if ($inDegree[$nodeId] -eq 0) {
        $queue.Enqueue($nodeId)
        Write-Log -Message "Adding root node to queue: $nodeId" -Level "Debug"
    }
}

$tempInDegree = $inDegree.Clone()

while ($queue.Count -gt 0) {
    $currentNode = $queue.Dequeue()
    $sortedNodes += $currentNode
    
    # For each child of current node
    foreach ($childNode in $adjacencyList[$currentNode]) {
        $tempInDegree[$childNode]--
        
        if ($tempInDegree[$childNode] -eq 0) {
            $queue.Enqueue($childNode)
            Write-Log -Message "Node ready for processing: $childNode" -Level "Debug"
        }
    }
}

# Check for cycles
if ($sortedNodes.Count -ne $nodeIds.Count) {
    Write-Log -Message "DAG contains a cycle - topological sort failed" -Level "Error"
    return [PSCustomObject]@{
        Success       = $false
        CreatedIssues = @{}
        Errors        = @("DAG contains a cycle - cannot determine creation order")
        CorrelationId = $CorrelationId
    }
}

Write-Log -Message "Topological sort completed successfully" -Level "Info"
Write-Log -Message "Creation order: $($sortedNodes -join ', ')" -Level "Info"

# DryRun mode - show plan and exit
if ($DryRun) {
    Write-Host ""
    Write-Host "=== DryRun Mode ===" -ForegroundColor Cyan
    Write-Host "Correlation ID: $CorrelationId" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "DAG validated successfully" -ForegroundColor Green
    Write-Host "  Nodes: $($dagJson.nodes.Count)" -ForegroundColor Gray
    Write-Host "  Edges: $($dagJson.edges.Count)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Execution Plan (creation order):" -ForegroundColor Yellow
    
    $stepNum = 1
    foreach ($nodeId in $sortedNodes) {
        $node = $dagJson.nodes | Where-Object { $_.id -eq $nodeId }
        Write-Host "  $stepNum. Create [$($node.type)] $($node.title) (id: $nodeId)" -ForegroundColor White
        
        $children = $adjacencyList[$nodeId]
        if ($children.Count -gt 0) {
            Write-Host "     → Will track: $($children -join ', ')" -ForegroundColor Gray
        }
        
        $stepNum++
    }
    
    Write-Host ""
    Write-Host "==================" -ForegroundColor Cyan
    
    return [PSCustomObject]@{
        Success       = $true
        CreatedIssues = @{}
        Errors        = @()
        CorrelationId = $CorrelationId
        DryRun        = $true
    }
}

# Get repository context
Write-Log -Message "Fetching repository context" -Level "Info"

try {
    $repoContext = & "$scriptDir/Get-RepoContext.ps1"
    
    if (-not $repoContext -or -not $repoContext.RepoId) {
        throw "Failed to get repository context"
    }
    
    Write-Log -Message "Repository ID: $($repoContext.RepoId)" -Level "Info"
}
catch {
    Write-Log -Message "Failed to get repository context: $_" -Level "Error"
    return [PSCustomObject]@{
        Success       = $false
        CreatedIssues = @{}
        Errors        = @("Failed to get repository context: $_")
        CorrelationId = $CorrelationId
    }
}

# Get organization issue types
Write-Log -Message "Fetching issue types" -Level "Info"

$getIssueTypesQuery = @"
query {
  repository(owner: "OWNER_PLACEHOLDER", name: "REPO_PLACEHOLDER") {
    owner {
      ... on Organization {
        issueTypes(first: 50) {
          nodes {
            id
            name
          }
        }
      }
    }
  }
}
"@

try {
    # Get current repository info
    $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
    $owner = $repoInfo.owner.login
    $repoName = $repoInfo.name
    
    $getIssueTypesQuery = $getIssueTypesQuery.Replace("OWNER_PLACEHOLDER", $owner).Replace("REPO_PLACEHOLDER", $repoName)
    
    $issueTypesResult = & $invokeGraphQLPath -Query $getIssueTypesQuery -CorrelationId $CorrelationId
    
    if (-not $issueTypesResult.Success) {
        throw "Failed to fetch issue types: $($issueTypesResult.Errors[0].Message)"
    }
    
    $issueTypes = @{}
    foreach ($issueType in $issueTypesResult.Data.repository.owner.issueTypes.nodes) {
        if ($issueTypes.ContainsKey($issueType.name)) {
            Write-Log -Message "Warning: Duplicate issue type name '$($issueType.name)' - using last occurrence" -Level "Warn"
        }
        $issueTypes[$issueType.name] = $issueType.id
    }
    
    Write-Log -Message "Found $($issueTypes.Count) issue types" -Level "Info"
}
catch {
    Write-Log -Message "Failed to fetch issue types: $_" -Level "Error"
    return [PSCustomObject]@{
        Success       = $false
        CreatedIssues = @{}
        Errors        = @("Failed to fetch issue types: $_")
        CorrelationId = $CorrelationId
    }
}

# Create issues in topological order
Write-Log -Message "Creating issues in dependency order" -Level "Info"

$createdIssues = @{}
$createdIssueData = @{}

foreach ($nodeId in $sortedNodes) {
    $node = $dagJson.nodes | Where-Object { $_.id -eq $nodeId }
    
    Write-Log -Message "Creating issue for node: $nodeId" -Level "Info"
    
    # Get issue type ID
    if (-not $issueTypes.ContainsKey($node.type)) {
        Write-Log -Message "Issue type '$($node.type)' not found for node '$nodeId'" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = $createdIssues
            Errors        = @("Issue type '$($node.type)' not found. Available: $($issueTypes.Keys -join ', ')")
            CorrelationId = $CorrelationId
        }
    }
    
    $issueTypeId = $issueTypes[$node.type]
    
    # Escape title and body
    $escapedTitle = $node.title | ConvertTo-EscapedGraphQL
    $escapedBody = if ($node.body) { $node.body | ConvertTo-EscapedGraphQL } else { "" }
    
    # Create issue mutation
    $createIssueMutation = @"
mutation {
  createIssue(input: {
    repositoryId: "$($repoContext.RepoId)"
    title: "$escapedTitle"
    body: "$escapedBody"
    issueTypeId: "$issueTypeId"
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
    
    try {
        $createResult = & $invokeGraphQLPath -Query $createIssueMutation -CorrelationId $CorrelationId
        
        if (-not $createResult.Success) {
            throw "GraphQL error: $($createResult.Errors[0].Message)"
        }
        
        $issue = $createResult.Data.createIssue.issue
        $createdIssues[$nodeId] = $issue.number
        $createdIssueData[$nodeId] = $issue
        
        Write-Log -Message "Created issue #$($issue.number) for node '$nodeId'" -Level "Info"
        Write-Host "✓ Created #$($issue.number) [$($node.type)] $($node.title)" -ForegroundColor Green
    }
    catch {
        Write-Log -Message "Failed to create issue for node '$nodeId': $_" -Level "Error"
        return [PSCustomObject]@{
            Success       = $false
            CreatedIssues = $createdIssues
            Errors        = @("Failed to create issue for node '$nodeId': $_")
            CorrelationId = $CorrelationId
        }
    }
}

Write-Log -Message "All issues created successfully" -Level "Info"

# Build relationships by updating parent issues with tasklists
Write-Log -Message "Building tasklist relationships" -Level "Info"

foreach ($nodeId in $sortedNodes) {
    $children = $adjacencyList[$nodeId]
    
    if ($children.Count -eq 0) {
        continue
    }
    
    Write-Log -Message "Adding tasklist to issue for node: $nodeId" -Level "Info"
    
    $parentIssue = $createdIssueData[$nodeId]
    $node = $dagJson.nodes | Where-Object { $_.id -eq $nodeId }
    
    # Build tasklist section
    $tasklistSection = "`n`n## 📋 Tracked Items`n`n"
    foreach ($childId in $children) {
        $childNumber = $createdIssues[$childId]
        $tasklistSection += "- [ ] #$childNumber`n"
    }
    
    # Get current body and append tasklist
    $currentBody = if ($node.body) { $node.body } else { "" }
    $newBody = $currentBody + $tasklistSection
    $escapedNewBody = $newBody | ConvertTo-EscapedGraphQL
    
    # Update issue mutation
    $updateIssueMutation = @"
mutation {
  updateIssue(input: {
    id: "$($parentIssue.id)"
    body: "$escapedNewBody"
  }) {
    issue {
      number
    }
  }
}
"@
    
    try {
        $updateResult = & $invokeGraphQLPath -Query $updateIssueMutation -CorrelationId $CorrelationId
        
        if (-not $updateResult.Success) {
            throw "GraphQL error: $($updateResult.Errors[0].Message)"
        }
        
        Write-Log -Message "Updated issue #$($parentIssue.number) with tasklist" -Level "Info"
        Write-Host "✓ Updated #$($parentIssue.number) with $($children.Count) tracked items" -ForegroundColor Green
    }
    catch {
        Write-Log -Message "Failed to update issue #$($parentIssue.number): $_" -Level "Warn"
        Write-Host "⚠ Warning: Failed to update #$($parentIssue.number) with tasklist: $_" -ForegroundColor Yellow
    }
}

Write-Log -Message "DAG import completed successfully" -Level "Info"

Write-Host ""
Write-Host "✓ DAG import completed successfully" -ForegroundColor Green
Write-Host "  Created $($createdIssues.Count) issues" -ForegroundColor Gray
Write-Host ""
Write-Host "  ⏰ Note: GitHub parses tasklist relationships asynchronously" -ForegroundColor Yellow
Write-Host "     Wait 2-5 minutes before verifying parent-child relationships" -ForegroundColor Yellow

return [PSCustomObject]@{
    Success       = $true
    CreatedIssues = $createdIssues
    Errors        = @()
    CorrelationId = $CorrelationId
}
