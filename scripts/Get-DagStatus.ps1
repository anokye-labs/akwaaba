<#
.SYNOPSIS
    Recursively walk an issue hierarchy and report status with metrics.

.DESCRIPTION
    Get-DagStatus.ps1 walks a GitHub issue hierarchy (DAG) recursively and reports
    status metrics at each level. It identifies:
    - Percentage complete at each level
    - Blocked items (open with all children done)
    - Ready items (open with no open dependencies)
    - Total counts and metrics
    
    Supports multiple output formats: Tree (default), JSON, and CSV.

.PARAMETER IssueNumber
    The issue number to start the hierarchy walk from (root of the DAG).

.PARAMETER Format
    Output format. Valid values: Tree, JSON, CSV. Default is Tree.

.PARAMETER MaxDepth
    Maximum depth to traverse. Default is 10. Use -1 for unlimited depth.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Get-DagStatus.ps1 -IssueNumber 14
    Displays tree view of issue #14 and its hierarchy.

.EXAMPLE
    ./Get-DagStatus.ps1 -IssueNumber 14 -Format JSON
    Outputs the hierarchy status as JSON.

.EXAMPLE
    ./Get-DagStatus.ps1 -IssueNumber 14 -Format CSV | Out-File status.csv
    Exports the hierarchy status to a CSV file.

.EXAMPLE
    ./Get-DagStatus.ps1 -IssueNumber 14 -MaxDepth 2
    Limits traversal to 2 levels deep.

.OUTPUTS
    Tree format: Formatted text tree to stdout
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
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Tree", "JSON", "CSV")]
    [string]$Format = "Tree",

    [Parameter(Mandatory = $false)]
    [int]$MaxDepth = 10,

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
# Write-OkyeremaLog is part of the Okyerema skill framework and located in .github/skills/
. "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

Write-OkyeremaLog -Message "Starting DAG status walk for issue #$IssueNumber" -Level Info -Operation "Get-DagStatus" -CorrelationId $CorrelationId

# Get repository context
try {
    $repoContext = & "$scriptDir/Get-RepoContext.ps1"
    Write-OkyeremaLog -Message "Repository context retrieved" -Level Debug -Operation "Get-DagStatus" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to get repository context: $_" -Level Error -Operation "Get-DagStatus" -CorrelationId $CorrelationId
    throw
}

# Get current repository info
try {
    $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
    $owner = $repoInfo.owner.login
    $repoName = $repoInfo.name
    Write-OkyeremaLog -Message "Repository: $owner/$repoName" -Level Debug -Operation "Get-DagStatus" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to get repository info: $_" -Level Error -Operation "Get-DagStatus" -CorrelationId $CorrelationId
    throw
}

# Function to fetch issue with its hierarchy
function Get-IssueWithHierarchy {
    param(
        [int]$Number,
        [string]$Owner,
        [string]$Repo,
        [int]$Depth,
        [string]$CorrelationId
    )

    Write-OkyeremaLog -Message "Fetching issue #$Number (depth: $Depth)" -Level Debug -Operation "Get-IssueWithHierarchy" -CorrelationId $CorrelationId

    $query = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      id
      number
      title
      state
      closed
      issueType {
        id
        name
      }
      trackedIssues(first: 100) {
        totalCount
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
        }
      }
      trackedInIssues(first: 100) {
        totalCount
        nodes {
          id
          number
          state
          closed
        }
      }
    }
  }
}
"@

    $variables = @{
        owner = $Owner
        repo = $Repo
        number = $Number
    }

    $result = Invoke-GraphQL -Query $query -Variables $variables -CorrelationId $CorrelationId

    if (-not $result.Success) {
        Write-OkyeremaLog -Message "Failed to fetch issue #$Number: $($result.Errors[0].Message)" -Level Error -Operation "Get-IssueWithHierarchy" -CorrelationId $CorrelationId
        throw "Failed to fetch issue #$Number"
    }

    return $result.Data.repository.issue
}

# Function to recursively build hierarchy tree
function Build-HierarchyTree {
    param(
        [int]$Number,
        [string]$Owner,
        [string]$Repo,
        [int]$CurrentDepth,
        [int]$MaxDepth,
        [hashtable]$Visited,
        [string]$CorrelationId
    )

    # Check if we've already visited this issue (cycle detection)
    if ($Visited.ContainsKey($Number)) {
        Write-OkyeremaLog -Message "Cycle detected: Issue #$Number already visited" -Level Warn -Operation "Build-HierarchyTree" -CorrelationId $CorrelationId
        return $null
    }

    # Check depth limit
    if ($MaxDepth -ne -1 -and $CurrentDepth -gt $MaxDepth) {
        Write-OkyeremaLog -Message "Max depth reached at issue #$Number" -Level Debug -Operation "Build-HierarchyTree" -CorrelationId $CorrelationId
        return $null
    }

    # Mark as visited
    $Visited[$Number] = $true

    # Fetch issue data
    $issue = Get-IssueWithHierarchy -Number $Number -Owner $Owner -Repo $Repo -Depth $CurrentDepth -CorrelationId $CorrelationId

    # Build node object
    $node = [PSCustomObject]@{
        Number = $issue.number
        Title = $issue.title
        State = $issue.state
        Closed = $issue.closed
        IssueType = if ($issue.issueType) { $issue.issueType.name } else { "Unknown" }
        Children = @()
        ParentCount = $issue.trackedInIssues.totalCount
        TotalChildren = 0
        ClosedChildren = 0
        PercentComplete = 0
        IsBlocked = $false
        IsReady = $false
        Depth = $CurrentDepth
    }

    # Recursively fetch children
    if ($issue.trackedIssues.totalCount -gt 0) {
        foreach ($child in $issue.trackedIssues.nodes) {
            $childNode = Build-HierarchyTree `
                -Number $child.number `
                -Owner $Owner `
                -Repo $Repo `
                -CurrentDepth ($CurrentDepth + 1) `
                -MaxDepth $MaxDepth `
                -Visited $Visited `
                -CorrelationId $CorrelationId

            if ($childNode) {
                $node.Children += $childNode
            }
        }
    }

    # Calculate metrics
    Calculate-NodeMetrics -Node $node

    return $node
}

# Function to calculate metrics for a node
function Calculate-NodeMetrics {
    param(
        [PSCustomObject]$Node
    )

    # Count direct children
    $Node.TotalChildren = $Node.Children.Count

    if ($Node.TotalChildren -gt 0) {
        # Count closed direct children
        # Wrap in @() to ensure .Count works even if Where-Object returns null or single item
        $Node.ClosedChildren = @($Node.Children | Where-Object { $_.State -eq "CLOSED" }).Count

        # Calculate percentage complete (based on direct children only)
        $Node.PercentComplete = [math]::Round(($Node.ClosedChildren / $Node.TotalChildren) * 100, 1)

        # Check if blocked: open with all children closed
        $Node.IsBlocked = ($Node.State -eq "OPEN" -and $Node.ClosedChildren -eq $Node.TotalChildren -and $Node.TotalChildren -gt 0)
    }
    else {
        # Leaf node
        $Node.PercentComplete = if ($Node.State -eq "CLOSED") { 100 } else { 0 }
        
        # Check if ready: open with no children and no open parents blocking it
        # Note: We mark it as ready if it has no children. The parent check is implicit
        # since if parent is closed, this is either closed or blocked by parent state.
        $Node.IsReady = ($Node.State -eq "OPEN")
    }
}

# Function to render tree format
function Format-TreeOutput {
    param(
        [PSCustomObject]$Node,
        [string]$Prefix = "",
        [bool]$IsLast = $true
    )

    # Build status indicator
    $stateIcon = if ($Node.State -eq "CLOSED") { "✓" } else { "○" }
    $blockedFlag = if ($Node.IsBlocked) { " [BLOCKED]" } else { "" }
    $readyFlag = if ($Node.IsReady -and $Node.State -eq "OPEN" -and $Node.TotalChildren -eq 0) { " [READY]" } else { "" }
    
    # Build metrics
    $metrics = if ($Node.TotalChildren -gt 0) {
        " ($($Node.ClosedChildren)/$($Node.TotalChildren), $($Node.PercentComplete)%)"
    } else {
        ""
    }

    # Build line
    $branch = if ($IsLast) { "└── " } else { "├── " }
    $line = "$Prefix$branch$stateIcon #$($Node.Number) - $($Node.Title)$metrics$blockedFlag$readyFlag"
    
    Write-Host $line

    # Process children
    if ($Node.Children.Count -gt 0) {
        $newPrefix = $Prefix + $(if ($IsLast) { "    " } else { "│   " })
        
        for ($i = 0; $i -lt $Node.Children.Count; $i++) {
            $isLastChild = ($i -eq ($Node.Children.Count - 1))
            Format-TreeOutput -Node $Node.Children[$i] -Prefix $newPrefix -IsLast $isLastChild
        }
    }
}

# Function to render JSON format
function Format-JsonOutput {
    param(
        [PSCustomObject]$Node
    )

    return $Node | ConvertTo-Json -Depth 100
}

# Function to flatten tree to CSV rows
function ConvertTo-CsvRows {
    param(
        [PSCustomObject]$Node,
        [string]$ParentPath = ""
    )

    $rows = @()

    # Build current path
    $currentPath = if ($ParentPath) { "$ParentPath > #$($Node.Number)" } else { "#$($Node.Number)" }

    # Create row for current node
    $row = [PSCustomObject]@{
        Number = $Node.Number
        Title = $Node.Title
        State = $Node.State
        IssueType = $Node.IssueType
        Depth = $Node.Depth
        TotalChildren = $Node.TotalChildren
        ClosedChildren = $Node.ClosedChildren
        PercentComplete = $Node.PercentComplete
        IsBlocked = $Node.IsBlocked
        IsReady = $Node.IsReady
        Path = $currentPath
    }

    $rows += $row

    # Recursively add children
    foreach ($child in $Node.Children) {
        $rows += ConvertTo-CsvRows -Node $child -ParentPath $currentPath
    }

    return $rows
}

# Function to render CSV format
function Format-CsvOutput {
    param(
        [PSCustomObject]$Node
    )

    $rows = ConvertTo-CsvRows -Node $Node
    return $rows | ConvertTo-Csv -NoTypeInformation
}

# Main execution
try {
    Write-OkyeremaLog -Message "Building hierarchy tree from issue #$IssueNumber" -Level Info -Operation "Get-DagStatus" -CorrelationId $CorrelationId
    
    $visited = @{}
    $tree = Build-HierarchyTree `
        -Number $IssueNumber `
        -Owner $owner `
        -Repo $repoName `
        -CurrentDepth 0 `
        -MaxDepth $MaxDepth `
        -Visited $visited `
        -CorrelationId $CorrelationId

    if (-not $tree) {
        Write-OkyeremaLog -Message "Failed to build hierarchy tree" -Level Error -Operation "Get-DagStatus" -CorrelationId $CorrelationId
        throw "Failed to build hierarchy tree"
    }

    Write-OkyeremaLog -Message "Hierarchy tree built successfully" -Level Info -Operation "Get-DagStatus" -CorrelationId $CorrelationId

    # Output in requested format
    switch ($Format) {
        "Tree" {
            Write-Host ""
            Write-Host "DAG Status for #$IssueNumber" -ForegroundColor Cyan
            Write-Host "Legend: ✓ = Closed, ○ = Open, [BLOCKED] = Open with all children done, [READY] = Open leaf with no dependencies" -ForegroundColor Gray
            Write-Host ""
            Format-TreeOutput -Node $tree
            Write-Host ""
        }
        "JSON" {
            $output = Format-JsonOutput -Node $tree
            Write-Output $output
        }
        "CSV" {
            $output = Format-CsvOutput -Node $tree
            Write-Output $output
        }
    }

    Write-OkyeremaLog -Message "DAG status walk completed successfully" -Level Info -Operation "Get-DagStatus" -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "DAG status walk failed: $_" -Level Error -Operation "Get-DagStatus" -CorrelationId $CorrelationId
    throw
}
