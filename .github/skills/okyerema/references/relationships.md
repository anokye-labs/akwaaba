# Relationships Reference

**[← Back to SKILL.md](../SKILL.md)**

## How Tasklists Create Relationships

GitHub automatically parses markdown tasklists in issue bodies into `trackedIssues` relationships.

### Format

```markdown
## 📋 Tracked Features

- [ ] #106 - Core Skill Creation
- [ ] #107 - Script Conversion
```

**Requirements:**
- Must use `- [ ]` checkbox syntax
- Must reference issue numbers with `#`
- Must be in issue body (not comments)
- Text after number is optional

### What GitHub Creates

- Parent gets `trackedIssues: [#106, #107]`
- Children get `trackedInIssues: [parent]`
- Checkboxes track completion

---

## Creating Relationships

### Step 1: Create Children First

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

### Step 2: Update Parent with Tasklist

```graphql
mutation {
  updateIssue(input: {
    id: "I_xxx"
    body: "Epic description\n\n## 📋 Tracked Features\n\n- [ ] #106 - Core Skill Creation\n- [ ] #107 - Script Conversion"
  }) {
    issue { number }
  }
}
```

### Step 3: Wait 2-5 Minutes

GitHub parses tasklists **asynchronously**. Do not verify immediately.

### Step 4: Verify

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      trackedIssues(first: 50) {
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

---

## Advanced Queries

### Full Issue Relationships (Parents + Children)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 106) {
      title
      issueType { name }
      trackedIssues(first: 50) {
        totalCount
        nodes { number title issueType { name } state }
      }
      trackedInIssues(first: 10) {
        nodes { number title issueType { name } }
      }
    }
  }
}
```

### Nested Hierarchy (Epic → Features → Tasks)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      title
      issueType { name }
      trackedIssues(first: 50) {
        nodes {
          number
          title
          issueType { name }
          trackedIssues(first: 50) {
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

### Find Orphaned Issues (No Parent)

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        number
        title
        issueType { name }
        trackedInIssues(first: 1) {
          totalCount
        }
      }
    }
  }
}
```

Filter in PowerShell: `Where-Object { $_.trackedInIssues.totalCount -eq 0 }`

### Completion Status

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      title
      trackedIssues(first: 100) {
        totalCount
        nodes { number state closed }
      }
    }
  }
}
```

Calculate: `closedCount / totalCount * 100` for percentage.

---

## Updating Existing Relationships

### Replacing a Tasklist

When changing relationships, **remove the old section completely** before adding a new one:

```powershell
# Get current body
$result = gh api graphql -f query="$getBodyQuery" | ConvertFrom-Json
$body = $result.data.repository.issue.body

# Remove old tasklist (everything from ## 📋 onward)
$lines = $body -split "`n"
$cleanLines = @()
$inTasklist = $false

foreach ($line in $lines) {
    if ($line -match '^## .* Tracked') {
        $inTasklist = $true
        continue
    }
    if ($inTasklist -and $line -match '^- \[') { continue }
    if ($inTasklist -and $line -match '^$') { continue }
    if ($inTasklist -and $line -match '^##') { $inTasklist = $false }
    if (-not $inTasklist) { $cleanLines += $line }
}

$cleanBody = ($cleanLines -join "`n").TrimEnd()

# Add new tasklist
$newBody = $cleanBody + "`n`n## 📋 Tracked Features`n`n- [ ] #106`n- [ ] #107"

# Update issue
$updateMutation = @"
mutation {
  updateIssue(input: {
    id: `"$issueId`"
    body: `"$($newBody.Replace('"', '\"').Replace("`n", '\n'))`"
  }) {
    issue { number }
  }
}
"@

gh api graphql -f query="$updateMutation" | Out-Null
```

---

## Conventions

| Parent Type | Section Header | Children |
|-------------|---------------|----------|
| Epic (with Features) | `## 📋 Tracked Features` | Feature issues |
| Epic (direct Tasks) | `## 📋 Tracked Tasks` | Task issues |
| Feature | `## 📋 Tracked Tasks` | Task issues |
| Task | *(none — leaf node)* | — |

**Never mix Features and Tasks** in the same Epic's tasklist. Choose one pattern.

**[← Back to SKILL.md](../SKILL.md)**
