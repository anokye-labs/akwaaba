# Relationships Reference

**[← Back to SKILL.md](../SKILL.md)**

## How Sub-Issues Create Relationships

GitHub's sub-issues API provides a formal parent-child relationship mechanism using GraphQL mutations. This replaces the deprecated tasklist-based approach.

### API Requirements

All sub-issues operations require the `GraphQL-Features: sub_issues` header:

```bash
gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."
```

### Limits

- **100 sub-issues** maximum per parent issue
- **8 levels** of nesting maximum
- Relationships are **immediate** (no parsing delay)

---

## Creating Relationships

### Step 1: Create Child Issue

```graphql
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Feature: Script Conversion"
    issueTypeId: "IT_feature"
  }) {
    issue { id number }
  }
}
```

### Step 2: Add Sub-Issue Relationship

```graphql
mutation {
  addSubIssue(input: {
    issueId: "I_parentNodeId"
    subIssueId: "I_childNodeId"
  }) {
    subIssue {
      number
      title
      parent {
        number
        title
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

### Step 3: Verify Immediately

Relationships are available immediately (no wait time):

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      subIssues(first: 50) {
        nodes {
          number
          issueType { name }
          title
        }
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

---

## Removing Relationships

```graphql
mutation {
  removeSubIssue(input: {
    issueId: "I_parentNodeId"
    subIssueId: "I_childNodeId"
  }) {
    subIssue {
      number
      parent {
        number
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

---

## Advanced Queries

### Full Issue Relationships (Parents + Children)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 106) {
      title
      issueType { name }
      subIssues(first: 50) {
        totalCount
        nodes { number title issueType { name } state }
      }
      parent {
        number
        title
        issueType { name }
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

### Nested Hierarchy (Epic → Features → Tasks)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      title
      issueType { name }
      subIssues(first: 50) {
        nodes {
          number
          title
          issueType { name }
          subIssues(first: 50) {
            nodes {
              number
              title
              issueType { name }
            }
          }
        }
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

### Find Orphaned Issues (No Parent)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        number
        title
        issueType { name }
        parent {
          number
        }
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

Filter in PowerShell: `Where-Object { -not $_.parent }`

### Completion Status

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      title
      subIssues(first: 100) {
        totalCount
        nodes { number state closed }
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

Calculate: `closedCount / totalCount * 100` for percentage.

---

## Conventions

| Parent Type | Children |
|-------------|----------|
| Epic (with Features) | Feature issues |
| Epic (direct Tasks) | Task issues |
| Feature | Task issues |
| Task | *(none — leaf node)* |

**Never mix Features and Tasks** in the same Epic's sub-issues. Choose one pattern.

---

## Migration from Tasklists

If you have existing tasklist-based relationships:

1. Query old relationships using `trackedIssues` / `trackedInIssues`
2. For each relationship, call `addSubIssue` mutation
3. Remove tasklist markdown from issue body (optional)

The old tasklist API (`trackedIssues` / `trackedInIssues`) was retired by GitHub on April 30, 2025.

**[← Back to SKILL.md](../SKILL.md)**
