# Labels Reference

**[← Back to SKILL.md](../SKILL.md)**

Labels are for **categorization and filtering only**. Never use them for structure.

---

## ❌ DO NOT Use Labels For

### Issue Types
```powershell
# WRONG
gh issue create --label "epic"
gh issue create --label "task"
```
**Use instead:** Organization issue types via GraphQL `issueTypeId`

### Relationships
```powershell
# WRONG
gh issue create --label "parent:14"
gh issue create --label "blocked-by:7"
```
**Use instead:** Sub-issues API for parent-child, issue body text for blocking

### Status
```powershell
# WRONG
gh issue edit 14 --add-label "in-progress"
```
**Use instead:** Issue state (open/closed) or Projects status field

---

## ✅ DO Use Labels For

### Categorization
```
documentation, security, performance, testing
```

### Technology/Component Tags
```
typescript, powershell, api, frontend, infrastructure
```

### Special Designations
```
good-first-issue, help-wanted, breaking-change, needs-triage
```

### Phase/Milestone Tags (when milestones aren't enough)
```
phase-2-fal-ai, phase-3-workflow
```

---

## GraphQL Operations

### Get Repository Labels

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    labels(first: 100) {
      nodes { id name color description }
    }
  }
}
```

### Add Labels to Issue

```graphql
mutation {
  addLabelsToLabelable(input: {
    labelableId: "I_xxx"
    labelIds: ["LA_xxx", "LA_yyy"]
  }) {
    labelable {
      ... on Issue {
        number
        labels(first: 10) {
          nodes { name }
        }
      }
    }
  }
}
```

### Remove Labels

```graphql
mutation {
  removeLabelsFromLabelable(input: {
    labelableId: "I_xxx"
    labelIds: ["LA_xxx"]
  }) {
    labelable {
      ... on Issue { number }
    }
  }
}
```

### Create a Label

```graphql
mutation {
  createLabel(input: {
    repositoryId: "R_xxx"
    name: "documentation"
    color: "0075ca"
    description: "Improvements or additions to documentation"
  }) {
    label { id name }
  }
}
```

---

## Best Practices

1. **Use sparingly** — too many labels = noise
2. **Consistent naming** — `priority:high` not `high-priority`
3. **Document meanings** — in CONTRIBUTING.md or repo docs
4. **Meaningful colors** — similar categories get similar colors
5. **Clean up regularly** — remove unused labels

---

## Decision Tree

**Before creating a label, ask:**

- Is this structural info (type, parent, blocking)? → **Don't use a label.** Use issue types, sub-issues API, or body text.
- Is this status? → **Don't use a label.** Use issue state or Projects.
- Is this for filtering/searching? → ✅ **Label is appropriate.**
- Am I working around a missing feature? → **Stop. Find the proper GitHub feature.**

**[← Back to SKILL.md](../SKILL.md)**
