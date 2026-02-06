# Update-IssueHierarchy.ps1
# Build parent-child relationships by adding tasklists to issue bodies

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$ParentNumber,
    [Parameter(Mandatory)][int[]]$ChildNumbers,
    [ValidateSet("Features", "Tasks")]
    [string]$ChildType = "Tasks"
)

$ErrorActionPreference = "Stop"

# Get parent issue
$parentQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    issue(number: $ParentNumber) {
      id
      title
      body
    }
  }
}
"@

$result = gh api graphql -f query="$parentQuery" | ConvertFrom-Json
$parentId = $result.data.repository.issue.id
$parentTitle = $result.data.repository.issue.title
$parentBody = $result.data.repository.issue.body

Write-Host "Parent: #$ParentNumber - $parentTitle" -ForegroundColor Cyan

# Remove existing tasklist section
$lines = $parentBody -split "`n"
$cleanLines = @()
$inTasklist = $false

foreach ($line in $lines) {
    if ($line -match '^## .* Tracked') {
        $inTasklist = $true
        continue
    }
    if ($inTasklist -and $line -match '^- \[') { continue }
    if ($inTasklist -and $line -match '^\s*$') { continue }
    if ($inTasklist -and $line -match '^##') { $inTasklist = $false }
    if (-not $inTasklist) { $cleanLines += $line }
}

$cleanBody = ($cleanLines -join "`n").TrimEnd()

# Build new tasklist
$tasklist = "`n`n## Tracked $ChildType`n`n"
foreach ($num in $ChildNumbers | Sort-Object) {
    $tasklist += "- [ ] #$num`n"
}

$newBody = $cleanBody + $tasklist

# Update parent
$escapedBody = $newBody.Replace('"', '\"').Replace("`n", '\n')

$updateMutation = @"
mutation {
  updateIssue(input: {
    id: `"$parentId`"
    body: `"$escapedBody`"
  }) {
    issue { number }
  }
}
"@

gh api graphql -f query="$updateMutation" | Out-Null

Write-Host "✓ Updated #$ParentNumber with $($ChildNumbers.Count) tracked $ChildType" -ForegroundColor Green
Write-Host "  Children: #$($ChildNumbers -join ', #')" -ForegroundColor Gray
Write-Host "  ⏰ Wait 2-5 minutes for GitHub to parse relationships" -ForegroundColor Yellow
