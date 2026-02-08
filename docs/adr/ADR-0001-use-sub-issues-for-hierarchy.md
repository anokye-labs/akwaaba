# ADR-0001: Use Sub-Issues API for Hierarchy

**Status:** Accepted  
**Date:** 2026-02-08  
**Deciders:** Anokye Labs Team  
**Tags:** hierarchy, github-api, sub-issues, relationships

## Context

GitHub provides multiple mechanisms for representing issue hierarchies:

1. **Tasklist blocks** - Markdown checkboxes (`- [ ] #123`) in issue bodies that GitHub automatically parses into `trackedIssues` relationships
2. **Sub-issues API** - A formal parent-child relationship API with dedicated GraphQL mutations
3. **Labels** - Using labels like `parent:123` or `depends-on:456` (structural anti-pattern)
4. **Project fields** - Custom fields in Projects to indicate relationships

We needed a way to represent our Epic → Feature → Task hierarchy that is:
- **API-accessible** for agent automation
- **Visible** in the GitHub UI without custom tooling
- **Reliable** and officially supported by GitHub
- **Queryable** via GraphQL for traversing hierarchies

### The Tasklist Problem

In November 2024, GitHub announced the retirement of tasklist blocks as a relationship mechanism. While the markdown syntax still works for tracking completion, the automatic parsing into `trackedIssues` / `trackedInIssues` GraphQL relationships was scheduled for deprecation. This broke our entire hierarchy system since all agent tooling relied on these relationships.

**Key insight:** Because we never documented this decision as an ADR, we had no trigger to review it when GitHub announced the change. An ADR would have been flagged immediately during the retirement announcement.

## Decision

We will use GitHub's **sub-issues API** (the `createIssueRelationship` mutation) for all parent-child issue relationships going forward.

This means:
- Create relationships via `createIssueRelationship` mutation, not tasklist markdown
- Query relationships via the `parent` and `subIssues` fields, not `trackedInIssues` / `trackedIssues`
- Update all agent scripts and documentation to use the new API
- Migrate existing tasklist-based hierarchies to sub-issues API

### Migration Path

1. Update all PowerShell scripts in `scripts/` to use sub-issues mutations
2. Update Okyerema skill documentation with new API patterns
3. Migrate existing issue hierarchies by querying `trackedIssues` and recreating via `createIssueRelationship`
4. Remove or deprecate references to tasklist blocks for relationships

## Consequences

### Positive Consequences

- **Future-proof** - Uses GitHub's official, supported API for relationships
- **Better UX** - Sub-issues appear in a dedicated section of the issue UI
- **Stronger semantics** - Clear parent/child relationship vs. implicit tasklist parsing
- **No parsing delays** - Relationships are immediate, unlike tasklist's 2-5 minute async parsing
- **Queryable** - Standard GraphQL queries work reliably

### Negative Consequences

- **Migration work** - Must update all scripts, docs, and existing issues
- **Breaking change** - Old scripts using tasklists will break
- **Learning curve** - Team and agents must learn new API patterns
- **No markdown tracking** - Can't see hierarchy structure in raw issue body text anymore

### Risks

- GitHub might change sub-issues API in future (mitigated by ADR process - we'll catch it)
- Migration might break existing automation temporarily
- Some edge cases in hierarchy traversal might behave differently

## Alternatives Considered

### Alternative 1: Continue with Tasklists

**Rationale:** Wait and see if GitHub reverses the deprecation decision.

**Why not chosen:** 
- GitHub's announcement was clear - tasklists for relationships are being retired
- Building on deprecated APIs is technical debt
- We'd be in the same situation in 6-12 months, but with more code to migrate

### Alternative 2: Custom Label-Based System

**Rationale:** Use labels like `parent:14` to encode relationships, parse via scripts.

**Why not chosen:**
- Labels are not designed for structural relationships
- Violates our principle of "labels only for categorization"
- No UI visualization without custom tooling
- Error-prone and fragile
- Doesn't scale (GitHub has label count limits)

### Alternative 3: Project Custom Fields

**Rationale:** Use project custom fields like "Parent Issue" to link issues.

**Why not chosen:**
- Project fields are project-specific, not issue-level metadata
- Not accessible via GitHub's core issue API
- Wouldn't work for issues not in projects
- No automatic UI visualization
- Harder to query for hierarchy traversal

## References

- [GitHub GraphQL API: createIssueRelationship](https://docs.github.com/en/graphql/reference/mutations#createissuerelationship)
- [GitHub Docs: Sub-issues](https://docs.github.com/en/issues/tracking-your-work-with-issues/about-task-lists)
- [Okyerema Skill Documentation](/.github/skills/okyerema/SKILL.md)
- Issue motivating this ADR: Establish ADR process for architectural decisions

## Notes

- This is a **retroactive ADR** - the decision was already made implicitly when we adopted sub-issues after GitHub's announcement
- The tasklist approach was never formally documented, which is why we missed the deprecation
- This ADR **supersedes** the undocumented "use tasklists" decision
- All references to tasklists for relationships in documentation should be updated to reference this ADR
