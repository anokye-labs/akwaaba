# GitHub Projects V2 Reference

**[← Back to SKILL.md](../SKILL.md)**

Use GraphQL for all Projects manipulation. The gh CLI is insufficient for field operations.

---

## Finding Projects

### List Organization Projects

```graphql
query {
  organization(login: "anokye-labs") {
    projectsV2(first: 20) {
      nodes {
        id
        title
        number
        url
        fields(first: 20) {
          nodes {
            ... on ProjectV2Field {
              id
              name
              dataType
            }
            ... on ProjectV2SingleSelectField {
              id
              name
              options { id name }
            }
          }
        }
      }
    }
  }
}
```

### Get Project by Number

```graphql
query {
  organization(login: "anokye-labs") {
    projectV2(number: 3) {
      id
      title
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue {
              number
              title
            }
          }
        }
      }
    }
  }
}
```

---

## Adding Issues to Projects

### Step 1: Get IDs

```graphql
query {
  organization(login: "anokye-labs") {
    projectV2(number: 3) {
      id  # PVT_xxx
    }
  }
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 106) {
      id  # I_xxx
    }
  }
}
```

### Step 2: Add Item

```graphql
mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_xxx"
    contentId: "I_xxx"
  }) {
    item {
      id  # PVTI_xxx — save this for field updates
    }
  }
}
```

### Bulk Add

```powershell
$projectId = "PVT_xxx"
$issueIds = @("I_aaa", "I_bbb", "I_ccc")

foreach ($id in $issueIds) {
    $mutation = @"
mutation {
  addProjectV2ItemById(input: {
    projectId: `"$projectId`"
    contentId: `"$id`"
  }) {
    item { id }
  }
}
"@
    gh api graphql -f query="$mutation" | Out-Null
    Start-Sleep -Milliseconds 500
}
```

---

## Setting Custom Fields

### Text Field

```graphql
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_xxx"
    itemId: "PVTI_xxx"
    fieldId: "PVTF_xxx"
    value: { text: "High Priority" }
  }) {
    projectV2Item { id }
  }
}
```

### Single-Select Field

```graphql
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_xxx"
    itemId: "PVTI_xxx"
    fieldId: "PVTF_xxx"
    value: { singleSelectOptionId: "PVTSSO_xxx" }
  }) {
    projectV2Item { id }
  }
}
```

### Number Field

```graphql
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_xxx"
    itemId: "PVTI_xxx"
    fieldId: "PVTF_xxx"
    value: { number: 1 }
  }) {
    projectV2Item { id }
  }
}
```

---

## Important Distinctions

### Project Fields ≠ Issue Relationships

Setting a "Parent" field in a Project does **NOT** create an issue relationship. These are completely separate systems:

| System | Purpose | Mechanism |
|--------|---------|-----------|
| Issue relationships | Actual parent-child links | Tasklists in issue body |
| Project fields | Tracking/visualization | Project custom fields |

### ID Types

| ID Type | Prefix | Used For |
|---------|--------|----------|
| Issue ID | `I_` | Issue mutations |
| Project ID | `PVT_` | Project operations |
| Project Item ID | `PVTI_` | Field updates |
| Field ID | `PVTF_` | Identifying fields |
| Option ID | `PVTSSO_` | Single-select values |

### gh CLI Limitations

| Operation | gh CLI | GraphQL |
|-----------|--------|---------|
| Add item to project | ✅ `gh project item-add` | ✅ |
| Set custom fields | ❌ | ✅ |
| Bulk operations | ❌ | ✅ |
| Query project data | Limited | ✅ Full |

**Use GraphQL for any write operations requiring precision.**

**[← Back to SKILL.md](../SKILL.md)**
