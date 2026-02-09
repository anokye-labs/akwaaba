# Common Errors & Fixes

**[← Back to SKILL.md](../SKILL.md)**

---

## Error: "Issue type not found"

**Cause:** Wrong type ID or type doesn't exist in organization.

**Fix:** Re-query organization types:
```graphql
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
```

---

## Error: Sub-issue limit exceeded

**Cause:** Tried to add more than 100 sub-issues to a parent, or exceeded 8 levels of nesting.

**Fix:** Split into multiple parent issues or flatten the hierarchy.

---

## Error: Missing GraphQL-Features header

**Cause:** Sub-issues API requires special header.

**Fix:** Always include `-H "GraphQL-Features: sub_issues"` in your gh api call:
```bash
gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."
```

---

## Error: Epic has mixed Features AND Tasks as sub-issues

**Cause:** Added both Features and Tasks as children of same Epic.

**Fix:** Choose one pattern:
- Epic → Features → Tasks (3-level)
- Epic → Tasks (2-level)

Never mix Features and Tasks under the same Epic.

---

## Error: addSubIssue mutation not found

**Cause:** Missing the `GraphQL-Features: sub_issues` header.

**Fix:** Use the sub-issues API with the required header:

```graphql
mutation {
  addSubIssue(input: {
    issueId: "I_parentNodeId"
    subIssueId: "I_childNodeId"
  }) {
    subIssue {
      number
      parent { number }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

---

## Error: gh CLI can't set issue type

**Cause:** The `gh issue create` command has no `--type` flag.

**Fix:** Use GraphQL `createIssue` mutation with `issueTypeId` parameter.

---

## Error: Project field doesn't create issue relationship

**Cause:** Project custom fields are for tracking/visualization only.

**Fix:** Use sub-issues API for actual parent-child relationships. Project fields are separate.

---

## Pre-Flight Checklist

Before starting any issue operations:

- [ ] I have the repository ID (`R_xxx`)
- [ ] I have organization issue type IDs (`IT_xxx`)
- [ ] I'm using GraphQL API with `GraphQL-Features: sub_issues` header
- [ ] I'm NOT using labels for types
- [ ] I've planned the hierarchy (3-level or 2-level?)
- [ ] I won't exceed 100 sub-issues per parent or 8 nesting levels

**[← Back to SKILL.md](../SKILL.md)**
