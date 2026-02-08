# ADR-0003: Use Organization-Level Issue Types

**Status:** Accepted  
**Date:** 2026-02-08  
**Deciders:** Anokye Labs Team  
**Tags:** issue-types, organization, github, structure

## Context

GitHub provides multiple ways to categorize and classify issues:

1. **Labels** - Flexible tags that can be added to issues (e.g., `bug`, `feature`, `epic`)
2. **Issue Templates** - Predefined forms for creating issues with specific fields
3. **Organization-Level Issue Types** - Formal issue classification at the org level (Epic, Feature, Task, Bug)
4. **Title Prefixes** - Convention like `[EPIC]`, `[TASK]` in issue titles
5. **Repository-Level Custom Types** - Custom issue types per repository

For our Epic → Feature → Task hierarchy, we needed a way to indicate what "kind" of issue each one is that:
- Is **visible** in the GitHub UI without custom tooling
- Is **queryable** via API for filtering and automation
- Is **consistent** across all repositories in the organization
- **Doesn't rely on labels** (which we reserve for categorization, not structure)
- **Works with sub-issues API** for hierarchy

## Decision

We will use **GitHub organization-level issue types** for all issue classification.

This means:
- **Epic** - Large initiatives spanning multiple features
- **Feature** - Cohesive functionality grouping related tasks
- **Task** - Specific work items to be completed
- **Bug** - Defects or broken functionality

### Implementation

1. Issue types are set during creation via `issueTypeId` field in GraphQL
2. All scripts must query org issue types and map names to IDs
3. Never use labels for structural classification (no `epic`, `task`, `feature` labels)
4. Never use title prefixes for type indication
5. Issue type IDs are org-wide and consistent across all repositories

### Usage Pattern

```graphql
# Query org issue types
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}

# Create issue with type
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Your Title"
    issueTypeId: "IT_xxx"  # Epic, Feature, Task, or Bug
  }) {
    issue { number issueType { name } }
  }
}
```

## Consequences

### Positive Consequences

- **First-class support** - Issue types are native GitHub concepts, not workarounds
- **UI integration** - Types appear prominently in issue lists and issue views
- **Consistent across repos** - Same types available in all org repositories
- **API queryable** - Can filter and group issues by type via GraphQL
- **No label pollution** - Frees labels for actual categorization
- **Clear semantics** - Everyone understands what "Epic" vs "Task" means
- **Project integration** - Issue types work seamlessly with GitHub Projects

### Negative Consequences

- **Org-level only** - Requires organization setup, not available for personal repos
- **Limited customization** - Can't create custom types beyond Epic/Feature/Task/Bug
- **GraphQL required** - Must use GraphQL to set types, not available in gh CLI commands
- **No default type** - Must explicitly set type on every issue creation
- **Migration burden** - Converting label-based or prefix-based systems requires work

### Risks

- GitHub might change org-level issue types feature (mitigated by ADR review)
- Organization admins could modify available types (requires governance)
- Different orgs might have different type sets (potential portability issue)

## Alternatives Considered

### Alternative 1: Use Labels for Issue Types

**Rationale:** Use labels like `epic`, `feature`, `task`, `bug` to classify issues.

**Why not chosen:**
- Labels are designed for categorization, not structural classification
- Creates label pollution (structural + actual categorization mixed together)
- Easy to forget or misapply labels
- Harder to enforce consistency
- Violates principle "labels only for categorization"
- UI doesn't treat labels as first-class types

### Alternative 2: Title Prefixes

**Rationale:** Use prefixes like `[EPIC]`, `[FEATURE]`, `[TASK]` in issue titles.

**Why not chosen:**
- Manual and error-prone
- Ugly in issue lists
- Not queryable via API without text parsing
- No enforcement mechanism
- Breaks if someone edits title
- No UI integration

### Alternative 3: Repository-Level Custom Types

**Rationale:** Define custom issue types per repository.

**Why not chosen:**
- Inconsistent across repositories in the organization
- More setup and maintenance overhead
- Agents would need to query types per repo
- Doesn't provide cross-repo consistency
- Epic/Feature/Task/Bug are sufficient for our needs

### Alternative 4: Issue Templates Only

**Rationale:** Use issue templates with YAML frontmatter to indicate type.

**Why not chosen:**
- Templates are for creation workflow, not classification
- Type isn't visible in issue metadata after creation
- Not queryable via API
- Users can skip templates or edit issues later
- Doesn't integrate with GitHub's native features

## References

- [GitHub Docs: Organization Issue Types](https://docs.github.com/en/issues/planning-and-tracking-with-projects/understanding-fields/about-issue-types)
- [Okyerema Skill: Issue Types Reference](/.github/skills/okyerema/references/issue-types.md)
- [how-we-work.md](../../how-we-work.md) - Documents our use of issue types
- Related ADR: [ADR-0001: Use Sub-Issues API for Hierarchy](./ADR-0001-use-sub-issues-for-hierarchy.md)

## Notes

- This is a **retroactive ADR** - the decision was made during initial repository setup
- The decision is documented in `how-we-work.md` but not as a formal ADR
- Organization-level issue types are a GitHub Enterprise and GitHub Team feature
- Our four types (Epic, Feature, Task, Bug) cover all current use cases
- If we need additional types, that would require a new ADR to extend this decision
