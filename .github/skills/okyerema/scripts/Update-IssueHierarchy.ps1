# Update-IssueHierarchy.ps1
# Build parent-child relationships using sub-issues API

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$ParentNumber,
    [Parameter(Mandatory)][int[]]$ChildNumbers
)

$ErrorActionPreference = "Stop"

# Get parent issue node ID
$parentQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $ParentNumber) {
      id
      title
      issueType { name }
    }
  }
}
"@

$result = gh api graphql -f query="$parentQuery" | ConvertFrom-Json
$parentId = $result.data.repository.issue.id
$parentTitle = $result.data.repository.issue.title
$parentType = $result.data.repository.issue.issueType.name

Write-Host "Parent: #$ParentNumber [$parentType] $parentTitle" -ForegroundColor Cyan

# Get child issue node IDs
$childIssues = @()
foreach ($childNum in $ChildNumbers) {
    $childQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $childNum) {
      id
      number
      title
      issueType { name }
    }
  }
}
"@
    
    $childResult = gh api graphql -f query="$childQuery" | ConvertFrom-Json
    $child = $childResult.data.repository.issue
    $childIssues += $child
    Write-Host "  Child: #$($child.number) [$($child.issueType.name)] $($child.title)" -ForegroundColor Gray
}

# Add sub-issue relationships
$successCount = 0
foreach ($child in $childIssues) {
    $addSubIssueMutation = @"
mutation {
  addSubIssue(input: {
    issueId: `"$parentId`"
    subIssueId: `"$($child.id)`"
  }) {
    subIssue {
      number
      parent {
        number
      }
    }
  }
}
"@
    
    try {
        gh api graphql -H "GraphQL-Features: sub_issues" -f query="$addSubIssueMutation" | Out-Null
        $successCount++
    }
    catch {
        Write-Host "  ⚠ Failed to add #$($child.number): $_" -ForegroundColor Yellow
    }
}

Write-Host "`n✓ Added $successCount of $($childIssues.Count) sub-issues to #$ParentNumber" -ForegroundColor Green
Write-Host "  Relationships are immediate (no wait time)" -ForegroundColor Gray
