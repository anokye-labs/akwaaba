# Get-IssueTypeIds.ps1
# Retrieve organization issue type IDs for use in GraphQL mutations

param(
    [Parameter(Mandatory)]
    [string]$Owner
)

$query = @"
query {
  organization(login: `"$Owner`") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
"@

$result = gh api graphql -f query="$query" | ConvertFrom-Json

$types = @{}
foreach ($type in $result.data.organization.issueTypes.nodes) {
    $types[$type.name] = $type.id
}

# Output as hashtable
$types

# Also display
$result.data.organization.issueTypes.nodes | Format-Table name, id
