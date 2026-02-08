# Issue Types Reference

**[← Back to SKILL.md](../SKILL.md)**

## Getting Type IDs

```graphql
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
```

```powershell
$query = @"
query {
  organization(login: `"anokye-labs`") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
"@

$result = gh api graphql -f query="$query" | ConvertFrom-Json
$result.data.organization.issueTypes.nodes | Format-Table name, id
```

## Creating Issues

### With Type at Creation

```graphql
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Epic: Phase 2 Integration"
    body: "Description here"
    issueTypeId: "IT_xxx"
  }) {
    issue {
      id
      number
      title
      issueType { name }
    }
  }
}
```

### Get Repository ID

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    id
  }
}
```

## Updating Types

**Important:** Use issue **ID** (starts with `I_`), not issue number.

### Get Issue ID from Number

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      id
      issueType { name }
    }
  }
}
```

### Update Type

```graphql
mutation {
  updateIssue(input: {
    id: "I_xxx"
    issueTypeId: "IT_xxx"
  }) {
    issue {
      number
      issueType { name }
    }
  }
}
```

## Bulk Updates

```powershell
$updates = @{ 14 = "Epic"; 106 = "Feature"; 15 = "Task" }
$types = Get-IssueTypeIds -Owner "anokye-labs"

foreach ($num in $updates.Keys) {
    $typeId = $types[$updates[$num]]
    
    $getId = @"
query {
  repository(owner: `"anokye-labs`", name: `"repo`") {
    issue(number: $num) { id }
  }
}
"@
    $issueId = (gh api graphql -f query="$getId" | ConvertFrom-Json).data.repository.issue.id
    
    $update = @"
mutation {
  updateIssue(input: {
    id: `"$issueId`"
    issueTypeId: `"$typeId`"
  }) {
    issue { number }
  }
}
"@
    gh api graphql -f query="$update" | Out-Null
    Write-Host "✓ #$num → $($updates[$num])"
    Start-Sleep -Milliseconds 500
}
```

## Verification

### Single Issue
```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      number
      title
      issueType { id name }
    }
  }
}
```

### All Open Issues by Type
```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        number
        title
        issueType { name }
      }
    }
  }
}
```

## Common Mistakes

| Mistake | Why Wrong | Fix |
|---------|-----------|-----|
| `gh issue create --label "epic"` | Labels ≠ types | Use GraphQL `issueTypeId` |
| `--title "[Epic] Phase 2"` | Prefix ≠ type | Set `issueTypeId` in mutation |
| `gh issue edit --add-label task` | Labels ≠ types | Use `updateIssue` mutation |

**[← Back to SKILL.md](../SKILL.md)**
