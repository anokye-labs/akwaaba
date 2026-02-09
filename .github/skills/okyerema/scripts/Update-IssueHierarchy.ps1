# Update-IssueHierarchy.ps1
# Build parent-child relationships by adding tasklists to issue bodies
# Now uses Invoke-GraphQL.ps1 for robust GraphQL operations

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$ParentNumber,
    [Parameter(Mandatory)][int[]]$ChildNumbers,
    [ValidateSet("Features", "Tasks")]
    [string]$ChildType = "Tasks"
)

$ErrorActionPreference = "Stop"

# Find repository root and foundation layer scripts
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = $scriptDir
# Navigate up from .github/skills/okyerema/scripts to repository root
for ($i = 0; $i -lt 4; $i++) {
    $repoRoot = Split-Path -Parent $repoRoot
}
$scriptsPath = Join-Path $repoRoot "scripts"

# Import foundation layer scripts
. (Join-Path $scriptsPath "Invoke-GraphQL.ps1")

# Get parent issue
$parentQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      id
      title
      body
    }
  }
}
"@

$variables = @{
    owner = $Owner
    repo = $Repo
    number = $ParentNumber
}

$result = Invoke-GraphQL -Query $parentQuery -Variables $variables

if (-not $result.Success) {
    $errorMsg = if ($result.Errors.Count -gt 0) { $result.Errors[0].Message } else { "Unknown error" }
    Write-Error "Failed to fetch parent issue: $errorMsg"
    return
}

$parentId = $result.Data.repository.issue.id
$parentTitle = $result.Data.repository.issue.title
$parentBody = $result.Data.repository.issue.body

Write-Host "Parent: #$ParentNumber - $parentTitle" -ForegroundColor Cyan

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

# Build new tasklist
$tasklist = "`n`n## Tracked $ChildType`n`n"
foreach ($num in $ChildNumbers | Sort-Object) {
    $tasklist += "- [ ] #$num`n"
}

$newBody = $cleanBody + $tasklist

# Update parent (variables are already properly handled by Invoke-GraphQL)
$updateMutation = @"
mutation(`$id: ID!, `$body: String!) {
  updateIssue(input: {
    id: `$id
    body: `$body
  }) {
    issue { number }
  }
}
"@

$mutationVars = @{
    id = $parentId
    body = $newBody
}

$updateResult = Invoke-GraphQL -Query $updateMutation -Variables $mutationVars

if (-not $updateResult.Success) {
    $errorMsg = if ($updateResult.Errors.Count -gt 0) { $updateResult.Errors[0].Message } else { "Unknown error" }
    Write-Error "Failed to update issue: $errorMsg"
    return
}

Write-Host "✓ Updated #$ParentNumber with $($ChildNumbers.Count) tracked $ChildType" -ForegroundColor Green
Write-Host "  Children: #$($ChildNumbers -join ', #')" -ForegroundColor Gray
Write-Host "  ⏰ Wait 2-5 minutes for GitHub to parse relationships" -ForegroundColor Yellow
