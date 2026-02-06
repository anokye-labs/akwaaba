# New-IssueWithType.ps1
# Create a GitHub issue with proper organization issue type

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$TypeName,  # Epic, Feature, Task, Bug
    [string]$Body = "",
    [string[]]$Labels = @()
)

$ErrorActionPreference = "Stop"

# Get repo ID and type IDs
$query = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
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

$result = gh api graphql -f query="$query" | ConvertFrom-Json
$repoId = $result.data.repository.id
$typeId = ($result.data.repository.owner.issueTypes.nodes | Where-Object { $_.name -eq $TypeName }).id

if (-not $typeId) {
    Write-Error "Issue type '$TypeName' not found. Available: $($result.data.repository.owner.issueTypes.nodes.name -join ', ')"
    return
}

# Create issue
$escapedTitle = $Title.Replace('\', '\\').Replace('"', '\"')
$escapedBody = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')

$mutation = @"
mutation {
  createIssue(input: {
    repositoryId: `"$repoId`"
    title: `"$escapedTitle`"
    body: `"$escapedBody`"
    issueTypeId: `"$typeId`"
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

$result = gh api graphql -f query="$mutation" | ConvertFrom-Json
$issue = $result.data.createIssue.issue

Write-Host "✓ Created #$($issue.number) [$($issue.issueType.name)] $($issue.title)" -ForegroundColor Green

# Add labels if provided (via GraphQL, not gh CLI)
if ($Labels.Count -gt 0) {
    # Get label IDs
    $labelQuery = @"
query {
  repository(owner: `"$Owner`", name: `"$Repo`") {
    labels(first: 100) {
      nodes { id name }
    }
  }
}
"@
    $labelResult = gh api graphql -f query="$labelQuery" | ConvertFrom-Json
    $labelIds = $Labels | ForEach-Object {
        $name = $_
        ($labelResult.data.repository.labels.nodes | Where-Object { $_.name -eq $name }).id
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
        gh api graphql -f query="$labelMutation" | Out-Null
        Write-Host "  + Labels: $($Labels -join ', ')" -ForegroundColor Gray
    }
}

# Return issue object
$issue
