# Issue Types vs Issue Templates

This document clarifies the difference between **organization-level issue types** (what we use) and **issue templates** (what we don't use).

## Current Implementation: Organization-Level Issue Types

According to [ADR-0003: Use Organization-Level Issue Types](./adr/ADR-0003-use-org-level-issue-types.md), this repository uses **GitHub organization-level issue types**, not issue templates.

### What We Use

✅ **Organization-Level Issue Types** via GraphQL API:
- **Epic** — Large initiatives spanning multiple features
- **Feature** — Cohesive functionality grouping related tasks
- **Task** — Specific work items to be completed
- **Bug** — Defects or broken functionality

These are set during issue creation using GraphQL:

```graphql
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Issue Title"
    issueTypeId: "IT_xxx"  # Organization-level type ID
  }) {
    issue { number issueType { name } }
  }
}
```

### What We Don't Use

❌ **Issue Templates** in `.github/ISSUE_TEMPLATE/`:
- These are YAML or Markdown forms for issue creation UI
- Can auto-apply labels during creation
- Do NOT set organization-level issue types
- Not used in this repository (directory is empty except .gitkeep)

## Why This Matters

The original planning document (`planning/phase-2-governance/04-issue-templates.md`) proposed creating issue templates with auto-applying labels:

```yaml
# This was proposed but NOT implemented
# .github/ISSUE_TEMPLATE/epic.yml
name: "Epic"
labels: ["epic"]  # Auto-apply 'epic' label
```

However, **ADR-0003 superseded this approach** because:
1. Labels are not issue types — they're for categorization only
2. Organization-level types are first-class GitHub features
3. Types integrate with Projects, API queries, and UI
4. No label pollution (structural + categorization labels mixed)

## What About "Agent Request"?

The issue description mentions creating an "Agent Request" test issue. However:

- **There is no "Agent Request" organization-level issue type**
- The planning document mentioned it as a proposed issue template (not implemented)
- To request an agent, create a **Feature** or **Task** issue with appropriate categorization labels like `agent-related`, `enhancement`

## Testing Issue Types

Since we use organization-level issue types (not templates), testing involves:

1. ✅ **Creating issues with each type** via GraphQL
2. ✅ **Verifying types are correctly set** via GraphQL queries
3. ✅ **Testing hierarchical relationships** via sub-issues API
4. ❌ **NOT testing label auto-application** (we don't use structural labels)
5. ❌ **NOT testing issue templates** (we don't have any)

See [testing-issue-types.md](./testing-issue-types.md) for the complete testing guide.

## Labels: Use Sparingly

We use labels **only for categorization**, never for structure:

✅ **Good uses:**
- `documentation` — Issue involves documentation
- `security` — Security-related issue
- `typescript` — TypeScript-specific issue
- `good-first-issue` — Good for new contributors
- `breaking-change` — Introduces breaking changes

❌ **Bad uses:**
- `epic`, `feature`, `task`, `bug` — Use issue types instead
- `in-progress`, `blocked` — Use project status fields instead
- `parent:14`, `depends-on:7` — Use sub-issues API instead

## Migration Note

If you encounter references to issue templates or auto-applying labels in old documentation:

1. These refer to the **original plan** from Phase 2 planning
2. The plan was **superseded by ADR-0003**
3. We decided to use **organization-level issue types** instead
4. Update any documentation you find to reflect the current implementation

## Quick Reference

| Feature | Issue Templates | Org-Level Issue Types (We Use) |
|---------|----------------|--------------------------------|
| **Location** | `.github/ISSUE_TEMPLATE/*.yml` | Organization settings |
| **Set via** | GitHub UI form | GraphQL API |
| **Visible in** | Issue creation flow | Issue metadata, lists, API |
| **Queryable** | No (labels only) | Yes (native GraphQL field) |
| **Labels** | Can auto-apply | Manual only |
| **Consistency** | Per-repository | Across all org repos |
| **Hierarchy Support** | No | Yes (via sub-issues API) |

## See Also

- [ADR-0003: Use Organization-Level Issue Types](./adr/ADR-0003-use-org-level-issue-types.md)
- [ADR-0001: Use Sub-Issues API for Hierarchy](./adr/ADR-0001-use-sub-issues-for-hierarchy.md)
- [Testing Issue Types](./testing-issue-types.md)
- [How We Work](../how-we-work.md)
- [Okyerema Skill](../.github/skills/okyerema/SKILL.md)
