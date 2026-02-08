# New-IssueWithType.ps1
# Create a GitHub issue with proper organization issue type
# Now uses Invoke-GraphQL.ps1 for robust GraphQL operations

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$TypeName,  # Epic, Feature, Task, Bug
    [string]$Body = "",
    [string[]]$Labels = @()
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

# Get repo ID and type IDs
$query = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
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

$variables = @{
    owner = $Owner
    repo = $Repo
}

$result = Invoke-GraphQL -Query $query -Variables $variables

if (-not $result.Success) {
    $errorMsg = if ($result.Errors.Count -gt 0) { $result.Errors[0].Message } else { "Unknown error" }
    Write-Error "Failed to fetch repository info: $errorMsg"
    return
}

$repoId = $result.Data.repository.id
$typeId = ($result.Data.repository.owner.issueTypes.nodes | Where-Object { $_.name -eq $TypeName }).id

if (-not $typeId) {
    Write-Error "Issue type '$TypeName' not found. Available: $($result.Data.repository.owner.issueTypes.nodes.name -join ', ')"
    return
}

# Create issue (variables are already properly handled by Invoke-GraphQL)
$mutation = @"
mutation(`$repoId: ID!, `$title: String!, `$body: String!, `$typeId: ID!) {
  createIssue(input: {
    repositoryId: `$repoId
    title: `$title
    body: `$body
    issueTypeId: `$typeId
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

$mutationVars = @{
    repoId = $repoId
    title = $Title
    body = $Body
    typeId = $typeId
}

$createResult = Invoke-GraphQL -Query $mutation -Variables $mutationVars

if (-not $createResult.Success) {
    $errorMsg = if ($createResult.Errors.Count -gt 0) { $createResult.Errors[0].Message } else { "Unknown error" }
    Write-Error "Failed to create issue: $errorMsg"
    return
}

$issue = $createResult.Data.createIssue.issue

Write-Host "✓ Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor Green

# Add labels if provided (via GraphQL)
if ($Labels.Count -gt 0) {
    # Get label IDs
    $labelQuery = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    labels(first: 100) {
      nodes { id name }
    }
  }
}
"@
    
    $labelResult = Invoke-GraphQL -Query $labelQuery -Variables $variables
    
    if ($labelResult.Success) {
        $labelIds = $Labels | ForEach-Object {
            $name = $_
            ($labelResult.Data.repository.labels.nodes | Where-Object { $_.name -eq $name }).id
        } | Where-Object { $_ }

        if ($labelIds.Count -gt 0) {
            $labelIdList = ($labelIds | ForEach-Object { "`"$_`"" }) -join ', '
            $labelMutation = @"
mutation {
  addLabelsToLabelable(input: {
    labelableId: `"$($issue.id)`"
    labelIds: [$labelIdList]
  }) {
    labelable {
      ... on Issue { number }
    }
  }
}
"@
            $labelAddResult = Invoke-GraphQL -Query $labelMutation
            
            if ($labelAddResult.Success) {
                $allLabelNodes = $labelResult.Data.repository.labels.nodes
                $appliedLabels = $allLabelNodes | Where-Object { $_.id -in $labelIds } | ForEach-Object { $_.name }
                $missing = $Labels | Where-Object { $_ -notin ($allLabelNodes.name) }
                Write-Host "  + Labels: $($appliedLabels -join ', ')" -ForegroundColor Gray
                if ($missing) { Write-Warning "Labels not found (skipped): $($missing -join ', ')" }
            }
        }
    }
}

# Return issue object
$issue
