<#
.SYNOPSIS
    Find open issues not connected to any Epic/Feature hierarchy.

.DESCRIPTION
    Get-OrphanedIssues.ps1 queries all open issues in a repository and identifies
    those that are not part of any hierarchy (trackedInIssues.totalCount == 0).
    Epics are excluded as they are roots, not orphans. The script suggests which
    Epic or Feature each orphaned issue might belong to based on similarity analysis.

.PARAMETER DryRun
    If specified, logs the query without executing it against the API.

.PARAMETER Verbose
    Enables verbose logging for debugging purposes.

.OUTPUTS
    Returns an array of PSCustomObject with orphaned issues and suggested parents:
    - Number: Issue number
    - Title: Issue title
    - IssueType: Type of the issue (e.g., Feature, Task, Bug)
    - State: Issue state (OPEN/CLOSED)
    - Url: Issue URL
    - SuggestedParent: Suggested parent issue with number, title, and type

.EXAMPLE
    PS> .\Get-OrphanedIssues.ps1
    Finds all orphaned issues in the current repository.

.EXAMPLE
    PS> .\Get-OrphanedIssues.ps1 -DryRun
    Shows the query that would be executed without running it.

.EXAMPLE
    PS> .\Get-OrphanedIssues.ps1 -Verbose
    Finds orphaned issues with verbose logging enabled.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Dependencies:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for tracking
$correlationId = [guid]::NewGuid().ToString()

# Get script directory for relative paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [switch]$DryRun,
        [string]$CorrelationId
    )
    
    $invokeGraphQLPath = Join-Path $scriptDir "Invoke-GraphQL.ps1"
    
    $params = @{
        Query = $Query
        Variables = $Variables
        CorrelationId = $CorrelationId
    }
    
    if ($DryRun) {
        $params.DryRun = $true
    }
    
    return & $invokeGraphQLPath @params
}

# Helper function to call Write-OkyeremaLog.ps1
function Write-OkyeremaLogHelper {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "",
        [string]$CorrelationId = ""
    )
    
    $writeLogPath = Join-Path (Split-Path $scriptDir -Parent) ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    
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
    
    & $writeLogPath @params
}

# Helper function to call Get-RepoContext.ps1
function Get-RepoContextHelper {
    $getRepoContextPath = Join-Path $scriptDir "Get-RepoContext.ps1"
    return & $getRepoContextPath
}

# Main execution
Write-OkyeremaLogHelper -Message "Starting orphaned issues search" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId

# Get repository context
try {
    Write-OkyeremaLogHelper -Message "Fetching repository context" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    $repoContext = Get-RepoContextHelper
    
    if (-not $repoContext.RepoId) {
        Write-OkyeremaLogHelper -Message "Failed to get repository context" -Level "Error" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
        throw "Could not retrieve repository context"
    }
}
catch {
    Write-OkyeremaLogHelper -Message "Error getting repository context: $_" -Level "Error" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    throw
}

# Extract owner and repo from gh cli
try {
    $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
    $parts = $repoInfo.nameWithOwner.Split('/')
    $owner = $parts[0]
    $repo = $parts[1]
    Write-OkyeremaLogHelper -Message "Repository: $owner/$repo" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
}
catch {
    Write-OkyeremaLogHelper -Message "Error getting repository info: $_" -Level "Error" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    throw
}

# Build GraphQL query to fetch all open issues with hierarchy information
$query = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        id
        number
        title
        url
        state
        issueType {
          id
          name
        }
        trackedInIssues(first: 1) {
          totalCount
        }
      }
    }
  }
}
"@

$variables = @{
    owner = $owner
    repo = $repo
}

Write-OkyeremaLogHelper -Message "Querying for open issues" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId

# Execute the query
$result = Invoke-GraphQLHelper -Query $query -Variables $variables -DryRun:$DryRun -CorrelationId $correlationId

if ($DryRun) {
    Write-OkyeremaLogHelper -Message "DryRun mode - query not executed" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    return $result
}

if (-not $result.Success) {
    Write-OkyeremaLogHelper -Message "GraphQL query failed" -Level "Error" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    foreach ($error in $result.Errors) {
        Write-OkyeremaLogHelper -Message "Error: $($error.Message)" -Level "Error" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    }
    throw "Failed to query issues"
}

$issues = $result.Data.repository.issues.nodes
Write-OkyeremaLogHelper -Message "Found $($issues.Count) open issues" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId

# Filter to orphaned issues (no parent) and exclude Epics
$orphanedIssues = @($issues | Where-Object { 
    $_.trackedInIssues.totalCount -eq 0 -and 
    $_.issueType.name -ne "Epic" 
})

Write-OkyeremaLogHelper -Message "Found $($orphanedIssues.Count) orphaned issues (excluding Epics)" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId

if ($orphanedIssues.Count -eq 0) {
    Write-Host "`nNo orphaned issues found! 🎉" -ForegroundColor Green
    return @()
}

# Query potential parent issues (Epics and Features)
Write-OkyeremaLogHelper -Message "Querying potential parent issues" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId

$parentQuery = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        id
        number
        title
        issueType {
          id
          name
        }
        trackedIssues(first: 1) {
          totalCount
        }
      }
    }
  }
}
"@

$parentResult = Invoke-GraphQLHelper -Query $parentQuery -Variables $variables -CorrelationId $correlationId

if (-not $parentResult.Success) {
    Write-OkyeremaLogHelper -Message "Failed to query potential parents, continuing without suggestions" -Level "Warn" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
    $potentialParents = @()
}
else {
    # Filter to Epics and Features only
    $potentialParents = @($parentResult.Data.repository.issues.nodes | Where-Object {
        $_.issueType.name -eq "Epic" -or $_.issueType.name -eq "Feature"
    })
    Write-OkyeremaLogHelper -Message "Found $($potentialParents.Count) potential parent issues" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId
}

# Constants for similarity scoring
$HIERARCHY_MATCH_BOOST = 10  # Boost when parent-child types match expected hierarchy
$HIERARCHY_WEAK_BOOST = 5    # Smaller boost for less ideal but acceptable hierarchy

# Helper function to tokenize strings into words
function Get-Words {
    param([string]$text)
    # Convert to lowercase, remove punctuation, split on whitespace, filter short words
    return ($text.ToLower() -replace '[^\w\s]', ' ' -split '\s+') | Where-Object { $_.Length -gt 2 }
}

# Helper function to calculate similarity between two strings (Jaccard similarity coefficient)
function Get-StringSimilarity {
    <#
    .SYNOPSIS
        Calculates Jaccard similarity coefficient between two strings.
    .OUTPUTS
        Returns a percentage (0-100) representing the similarity between the two strings.
    #>
    param(
        [string]$str1,
        [string]$str2
    )
    
    # Get word tokens
    $words1 = Get-Words -text $str1
    $words2 = Get-Words -text $str2
    
    if ($words1.Count -eq 0 -or $words2.Count -eq 0) {
        return 0
    }
    
    # Count common words
    $commonWords = @($words1 | Where-Object { $words2 -contains $_ })
    
    # Calculate Jaccard similarity coefficient as percentage
    $union = @($words1 + $words2 | Select-Object -Unique)
    if ($union.Count -eq 0) {
        return 0
    }
    
    return [math]::Round(($commonWords.Count / $union.Count) * 100, 2)
}

# Suggest potential parents for each orphaned issue
$results = @()

foreach ($orphan in $orphanedIssues) {
    $suggestedParent = $null
    $bestScore = 0
    
    # Find the best matching parent based on title similarity
    foreach ($parent in $potentialParents) {
        $score = Get-StringSimilarity -str1 $orphan.title -str2 $parent.title
        
        # Prefer Features for Tasks/Bugs, Epics for Features
        if ($orphan.issueType.name -eq "Feature" -and $parent.issueType.name -eq "Epic") {
            $score += $HIERARCHY_MATCH_BOOST  # Boost for correct hierarchy level
        }
        elseif (($orphan.issueType.name -eq "Task" -or $orphan.issueType.name -eq "Bug") -and $parent.issueType.name -eq "Feature") {
            $score += $HIERARCHY_MATCH_BOOST  # Boost for correct hierarchy level
        }
        elseif (($orphan.issueType.name -eq "Task" -or $orphan.issueType.name -eq "Bug") -and $parent.issueType.name -eq "Epic") {
            $score += $HIERARCHY_WEAK_BOOST  # Smaller boost for Epic as direct parent of Task/Bug
        }
        
        if ($score -gt $bestScore) {
            $bestScore = $score
            $suggestedParent = @{
                Number = $parent.number
                Title = $parent.title
                Type = $parent.issueType.name
                Score = $score
            }
        }
    }
    
    $results += [PSCustomObject]@{
        Number = $orphan.number
        Title = $orphan.title
        IssueType = $orphan.issueType.name
        State = $orphan.state
        Url = $orphan.url
        SuggestedParent = if ($suggestedParent) {
            [PSCustomObject]$suggestedParent
        } else {
            $null
        }
    }
}

# Display results
Write-Host "`n╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                          ORPHANED ISSUES REPORT                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Found $($results.Count) orphaned issue(s) (open issues with no parent)" -ForegroundColor Yellow
Write-Host ""

foreach ($result in $results) {
    $typeColor = switch ($result.IssueType) {
        "Feature" { "Green" }
        "Task" { "White" }
        "Bug" { "Red" }
        default { "Gray" }
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "Issue #$($result.Number): " -NoNewline -ForegroundColor Cyan
    Write-Host "$($result.Title)" -ForegroundColor White
    Write-Host "Type: " -NoNewline -ForegroundColor Gray
    Write-Host "$($result.IssueType)" -ForegroundColor $typeColor
    Write-Host "URL:  $($result.Url)" -ForegroundColor Gray
    
    if ($result.SuggestedParent) {
        Write-Host ""
        Write-Host "  💡 Suggested Parent:" -ForegroundColor Yellow
        Write-Host "     #$($result.SuggestedParent.Number): $($result.SuggestedParent.Title)" -ForegroundColor Green
        Write-Host "     Type: $($result.SuggestedParent.Type) (similarity: $($result.SuggestedParent.Score)%)" -ForegroundColor Gray
    }
    else {
        Write-Host ""
        Write-Host "  ⚠️  No suggested parent found" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-OkyeremaLogHelper -Message "Completed orphaned issues search: $($results.Count) orphaned issues found" -Level "Info" -Operation "GetOrphanedIssues" -CorrelationId $correlationId

# Return results for pipeline use
return $results
