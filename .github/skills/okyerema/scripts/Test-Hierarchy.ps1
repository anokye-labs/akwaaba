# Test-Hierarchy.ps1
# Verify issue relationships via GraphQL

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$IssueNumber,
    [int]$Depth = 2
)

$ErrorActionPreference = "Stop"

function Get-IssueTree {
    param([string]$Owner, [string]$Repo, [int]$Number, [int]$Level = 0)
    
    $indent = "  " * $Level
    
    $query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $Number) {
      number
      title
      state
      issueType { name }
      trackedIssues(first: 50) {
        totalCount
        nodes {
          number
          title
          state
          issueType { name }
        }
      }
      trackedInIssues(first: 5) {
        nodes {
          number
          issueType { name }
        }
      }
    }
  }
}
"@
    
    $result = gh api graphql -f query="$query" | ConvertFrom-Json
    $issue = $result.data.repository.issue
    
    $typeColor = switch ($issue.issueType.name) {
        "Epic" { "Cyan" }
        "Feature" { "Green" }
        "Task" { "White" }
        "Bug" { "Red" }
        default { "Gray" }
    }
    
    $stateIcon = if ($issue.state -eq "CLOSED") { "✓" } else { "○" }
    
    Write-Host "${indent}${stateIcon} #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor $typeColor
    
    if ($issue.trackedInIssues.nodes.Count -gt 0 -and $Level -eq 0) {
        $parent = $issue.trackedInIssues.nodes[0]
        Write-Host "${indent}  ↑ Parent: #$($parent.number) [$($parent.issueType.name)]" -ForegroundColor Gray
    }
    
    if ($issue.trackedIssues.totalCount -gt 0) {
        Write-Host "${indent}  ↓ Tracks $($issue.trackedIssues.totalCount) issues:" -ForegroundColor Gray
        
        foreach ($child in $issue.trackedIssues.nodes) {
            if ($Level -lt $Depth) {
                Get-IssueTree -Owner $Owner -Repo $Repo -Number $child.number -Level ($Level + 1)
            } else {
                $childStateIcon = if ($child.state -eq "CLOSED") { "✓" } else { "○" }
                $childIndent = "  " * ($Level + 1)
                Write-Host "${childIndent}${childStateIcon} #$($child.number) [$($child.issueType.name)] $($child.title)" -ForegroundColor Gray
            }
        }
    }
    
    return $issue
}

Write-Host "`nHierarchy for #${IssueNumber}:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Get-IssueTree -Owner $Owner -Repo $Repo -Number $IssueNumber | Out-Null
Write-Host ""
