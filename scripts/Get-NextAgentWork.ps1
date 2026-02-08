<#
.SYNOPSIS
    Finds the next best issue for an agent to work on.

.DESCRIPTION
    Get-NextAgentWork.ps1 queries the DAG and returns the single next best issue 
    for an agent to pick up. It leverages Get-ReadyIssues.ps1 to find ready issues
    (dependencies met) and then applies additional prioritization and filtering:
    
    - Prioritizes by: depth in tree (leaves first), label priority, creation order
    - Filters by agent capability tags (if configured)
    - Returns a single issue context object ready for Start-IssueWork
    
    The prioritization logic ensures that:
    1. Deeper issues (leaves) are worked on before shallower issues
    2. Issues with higher priority labels (priority:critical > priority:high > 
       priority:medium > priority:low) are preferred
    3. Among issues with equal depth and priority, older issues come first

.PARAMETER RootIssue
    The issue number of the root Epic to start traversal from.

.PARAMETER AgentCapabilityTags
    Optional array of label names representing agent capabilities. Only issues
    with at least one matching capability tag will be returned. If not specified,
    all ready issues are considered regardless of labels.
    
    Example: @("powershell", "api", "backend")

.PARAMETER SortBy
    Prioritization strategy for selecting the next issue. Options:
    - "priority" (default): Depth-first (leaves first), then label priority, then creation order
    - "depth": Strictly by depth in hierarchy (deepest first)
    - "labels": Strictly by label priority (priority:critical first)
    - "oldest": Strictly by creation date (oldest first)

.PARAMETER OutputFormat
    Output format for the result. Options:
    - "Object" (default): Returns PSCustomObject with issue details
    - "Json": Returns JSON string representation
    - "Console": Displays formatted console output and returns object

.OUTPUTS
    PSCustomObject with properties:
    - Number: Issue number
    - Title: Issue title
    - Type: Issue type name
    - State: Issue state (OPEN)
    - Url: Issue URL
    - Body: Issue body text
    - Labels: Array of label names
    - Assignees: Array of assignee logins (should be empty for ready issues)
    - Depth: Depth in the hierarchy (0 = root)
    - Priority: Calculated priority score (higher = more urgent)
    - CreatedAt: Issue creation timestamp
    
    Returns $null if no ready issues match the criteria.

.EXAMPLE
    .\Get-NextAgentWork.ps1 -RootIssue 14
    Finds the next best issue under Epic #14 using default prioritization.

.EXAMPLE
    .\Get-NextAgentWork.ps1 -RootIssue 14 -AgentCapabilityTags @("powershell", "api")
    Finds the next best issue that has either "powershell" or "api" label.

.EXAMPLE
    .\Get-NextAgentWork.ps1 -RootIssue 14 -SortBy "depth" -OutputFormat "Console"
    Finds the deepest issue and displays formatted console output.

.EXAMPLE
    $nextIssue = .\Get-NextAgentWork.ps1 -RootIssue 14 -OutputFormat "Json"
    Gets the next issue as JSON for agent consumption.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Depends on: 
    - Get-ReadyIssues.ps1
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
    
    This script is designed to be called by automated agents as part of their
    work selection process. It should be followed by Start-IssueWork.ps1 to
    begin work on the returned issue.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$RootIssue,

    [Parameter(Mandatory = $false)]
    [string[]]$AgentCapabilityTags = @(),

    [Parameter(Mandatory = $false)]
    [ValidateSet("priority", "depth", "labels", "oldest")]
    [string]$SortBy = "priority",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Object", "Json", "Console")]
    [string]$OutputFormat = "Object"
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for this operation
$correlationId = [guid]::NewGuid().ToString()

# Helper function to call Write-OkyeremaLog.ps1
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logScript = Join-Path $PSScriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation "Get-NextAgentWork" -CorrelationId $correlationId
    }
}

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{}
    )
    
    $graphqlScript = Join-Path $PSScriptRoot "Invoke-GraphQL.ps1"
    return & $graphqlScript -Query $Query -Variables $Variables -CorrelationId $correlationId
}

# Helper function to get priority score from labels
function Get-PriorityScore {
    param([string[]]$Labels)
    
    # Priority label scoring:
    # priority:critical = 4
    # priority:high = 3
    # priority:medium = 2
    # priority:low = 1
    # no priority label = 0
    
    foreach ($label in $Labels) {
        switch ($label) {
            "priority:critical" { return 4 }
            "priority:high" { return 3 }
            "priority:medium" { return 2 }
            "priority:low" { return 1 }
        }
    }
    
    return 0
}

Write-Log "Starting Get-NextAgentWork for root issue #$RootIssue"

# Get ready issues from Get-ReadyIssues.ps1
Write-Verbose "Fetching ready issues using Get-ReadyIssues.ps1..."
$readyIssuesScript = Join-Path $PSScriptRoot "Get-ReadyIssues.ps1"

if (-not (Test-Path $readyIssuesScript)) {
    Write-Log "Get-ReadyIssues.ps1 not found at $readyIssuesScript" -Level "Error"
    throw "Required dependency Get-ReadyIssues.ps1 not found. This script depends on Get-ReadyIssues.ps1 (issue #25)."
}

try {
    # Get all ready issues (unassigned by default)
    $readyIssues = & $readyIssuesScript -RootIssue $RootIssue -SortBy "number"
    Write-Log "Found $($readyIssues.Count) ready issues from Get-ReadyIssues.ps1"
}
catch {
    Write-Log "Failed to fetch ready issues: $_" -Level "Error"
    throw "Failed to fetch ready issues: $_"
}

if (-not $readyIssues -or $readyIssues.Count -eq 0) {
    Write-Log "No ready issues found under root issue #$RootIssue"
    
    if ($OutputFormat -eq "Console") {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Next Agent Work - No Issues Available" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Root Issue: #$RootIssue" -ForegroundColor Yellow
        Write-Host "Status: No ready issues found" -ForegroundColor Yellow
        Write-Host ""
    }
    
    return $null
}

Write-Verbose "Retrieved $($readyIssues.Count) ready issues"

# Filter by agent capability tags if provided
if ($AgentCapabilityTags.Count -gt 0) {
    Write-Verbose "Filtering by agent capability tags: $($AgentCapabilityTags -join ', ')"
    
    $filteredIssues = @()
    foreach ($issue in $readyIssues) {
        # Check if issue has at least one matching capability tag
        $hasMatchingTag = $false
        foreach ($tag in $AgentCapabilityTags) {
            if ($issue.Labels -contains $tag) {
                $hasMatchingTag = $true
                break
            }
        }
        
        if ($hasMatchingTag) {
            $filteredIssues += $issue
            Write-Verbose "Issue #$($issue.Number) matches capability tags"
        }
        else {
            Write-Verbose "Issue #$($issue.Number) does not match capability tags, skipping"
        }
    }
    
    $readyIssues = $filteredIssues
    Write-Log "Filtered to $($readyIssues.Count) issues matching capability tags"
    
    if ($readyIssues.Count -eq 0) {
        Write-Log "No ready issues match the specified capability tags"
        
        if ($OutputFormat -eq "Console") {
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host "  Next Agent Work - No Matching Issues" -ForegroundColor Cyan
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Root Issue: #$RootIssue" -ForegroundColor Yellow
            Write-Host "Agent Capability Tags: $($AgentCapabilityTags -join ', ')" -ForegroundColor Yellow
            Write-Host "Status: No issues match the specified capability tags" -ForegroundColor Yellow
            Write-Host ""
        }
        
        return $null
    }
}

# Parse owner and repo from environment
$repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
$parts = $repoInfo.nameWithOwner -split '/'
$owner = $parts[0]
$repo = $parts[1]

Write-Verbose "Repository: $owner/$repo"

# Fetch additional metadata (createdAt) for prioritization
# We need createdAt for "oldest" sorting and for tiebreaking in "priority" mode
Write-Verbose "Fetching additional metadata for prioritization..."

$issueNumbers = $readyIssues | ForEach-Object { $_.Number }
$enrichedIssues = @()

foreach ($issue in $readyIssues) {
    # Query for createdAt timestamp
    $metadataQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      number
      createdAt
      body
    }
  }
}
"@
    
    $variables = @{
        owner = $owner
        repo = $repo
        number = $issue.Number
    }
    
    $result = Invoke-GraphQLHelper -Query $metadataQuery -Variables $variables
    
    if ($result.Success -and $result.Data.repository.issue) {
        $metadata = $result.Data.repository.issue
        
        # Create enriched issue object with all properties
        $enrichedIssue = [PSCustomObject]@{
            Number = $issue.Number
            Title = $issue.Title
            Type = $issue.Type
            State = $issue.State
            Url = $issue.Url
            Body = $metadata.body
            Labels = $issue.Labels
            Assignees = $issue.Assignees
            Depth = $issue.Depth
            Priority = Get-PriorityScore -Labels $issue.Labels
            CreatedAt = $metadata.createdAt
        }
        
        $enrichedIssues += $enrichedIssue
        Write-Verbose "Enriched issue #$($issue.Number) with metadata"
    }
    else {
        Write-Log "Failed to fetch metadata for issue #$($issue.Number), using default values" -Level "Warning"
        
        # Use issue without full metadata
        $enrichedIssue = [PSCustomObject]@{
            Number = $issue.Number
            Title = $issue.Title
            Type = $issue.Type
            State = $issue.State
            Url = $issue.Url
            Body = $null
            Labels = $issue.Labels
            Assignees = $issue.Assignees
            Depth = $issue.Depth
            Priority = Get-PriorityScore -Labels $issue.Labels
            CreatedAt = $null
        }
        
        $enrichedIssues += $enrichedIssue
    }
}

Write-Log "Enriched $($enrichedIssues.Count) issues with metadata"

# Sort issues based on the specified strategy
Write-Verbose "Applying prioritization strategy: $SortBy"

switch ($SortBy) {
    "depth" {
        # Sort by depth (deepest first), then by number (older first)
        $enrichedIssues = $enrichedIssues | Sort-Object @{Expression={$_.Depth}; Descending=$true}, Number
    }
    "labels" {
        # Sort by priority score (highest first), then by number (older first)
        $enrichedIssues = $enrichedIssues | Sort-Object @{Expression={$_.Priority}; Descending=$true}, Number
    }
    "oldest" {
        # Sort by creation date (oldest first), then by number
        $enrichedIssues = $enrichedIssues | Sort-Object CreatedAt, Number
    }
    "priority" {
        # Default: Depth (deepest first), then priority (highest first), then creation date (oldest first)
        $enrichedIssues = $enrichedIssues | Sort-Object @{Expression={$_.Depth}; Descending=$true}, @{Expression={$_.Priority}; Descending=$true}, CreatedAt, Number
    }
}

# Select the top issue
$nextIssue = $enrichedIssues | Select-Object -First 1

if (-not $nextIssue) {
    Write-Log "No issue selected after prioritization (this shouldn't happen)"
    return $null
}

Write-Log "Selected issue #$($nextIssue.Number): $($nextIssue.Title)"

# Format output based on OutputFormat parameter
if ($OutputFormat -eq "Console") {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Next Agent Work - Issue Selected" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Issue Number: " -NoNewline -ForegroundColor Gray
    Write-Host "#$($nextIssue.Number)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Title: " -NoNewline -ForegroundColor Gray
    Write-Host "$($nextIssue.Title)" -ForegroundColor White
    Write-Host ""
    Write-Host "Type: " -NoNewline -ForegroundColor Gray
    Write-Host "$($nextIssue.Type)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "URL: " -NoNewline -ForegroundColor Gray
    Write-Host "$($nextIssue.Url)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Depth: " -NoNewline -ForegroundColor Gray
    Write-Host "$($nextIssue.Depth)" -ForegroundColor White
    Write-Host ""
    
    if ($nextIssue.Priority -gt 0) {
        Write-Host "Priority: " -NoNewline -ForegroundColor Gray
        $priorityLabel = switch ($nextIssue.Priority) {
            4 { "Critical"; break }
            3 { "High"; break }
            2 { "Medium"; break }
            1 { "Low"; break }
            default { "None" }
        }
        $priorityColor = switch ($nextIssue.Priority) {
            4 { "Red"; break }
            3 { "Yellow"; break }
            2 { "Cyan"; break }
            1 { "White"; break }
            default { "Gray" }
        }
        Write-Host "$priorityLabel" -ForegroundColor $priorityColor
        Write-Host ""
    }
    
    if ($nextIssue.Labels.Count -gt 0) {
        Write-Host "Labels: " -NoNewline -ForegroundColor Gray
        Write-Host "$($nextIssue.Labels -join ', ')" -ForegroundColor Magenta
        Write-Host ""
    }
    
    if ($nextIssue.CreatedAt) {
        Write-Host "Created: " -NoNewline -ForegroundColor Gray
        Write-Host "$($nextIssue.CreatedAt)" -ForegroundColor White
        Write-Host ""
    }
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    return $nextIssue
}
elseif ($OutputFormat -eq "Json") {
    return $nextIssue | ConvertTo-Json -Depth 10
}
else {
    # Default: return object
    return $nextIssue
}
