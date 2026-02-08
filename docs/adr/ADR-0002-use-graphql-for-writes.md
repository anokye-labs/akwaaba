# ADR-0002: Use GraphQL for All Write Operations

**Status:** Accepted  
**Date:** 2026-02-08  
**Deciders:** Anokye Labs Team  
**Tags:** api, graphql, automation, github-cli

## Context

GitHub provides two primary APIs for programmatic access:

1. **REST API** - Traditional REST endpoints, accessible via `gh api /repos/...` commands
2. **GraphQL API** - Modern query language, accessible via `gh api graphql` commands

Our agent automation requires several operations that are only possible or better supported through specific APIs:

- **Setting issue types** - Only available via GraphQL (`issueTypeId` field)
- **Creating relationships** - Sub-issues API uses GraphQL mutations
- **Querying hierarchies** - Traversing parent/child relationships requires GraphQL
- **Bulk operations** - GraphQL allows fetching related data in single query
- **Type safety** - GraphQL schema provides validation

We needed to decide: Should we use REST, GraphQL, or a mix of both?

## Decision

We will use **GraphQL exclusively for all write operations** (mutations) in agent scripts.

This means:
- Issue creation → `createIssue` mutation with `issueTypeId`
- Issue updates → `updateIssue` mutation
- Relationship creation → `createIssueRelationship` mutation
- Any other modifications → GraphQL mutations

**Read operations** may use REST if simpler, but GraphQL is preferred for consistency.

### Implementation Standards

All scripts must:
1. Use `scripts/Invoke-GraphQL.ps1` wrapper, never raw `gh api graphql`
2. Use parameterized queries with `-F` flag for security (prevents injection)
3. Handle GraphQL error responses properly (check `errors` array)
4. Use proper variable types (integers with `-F`, strings with `-f`)

## Consequences

### Positive Consequences

- **Feature completeness** - Access to all GitHub capabilities (issue types, sub-issues, etc.)
- **Consistency** - Single API paradigm across all write operations
- **Type safety** - GraphQL schema validates requests before execution
- **Efficiency** - Single query can fetch/update related data (fewer round trips)
- **Future-proof** - GitHub's newest features often launch in GraphQL first
- **Better errors** - GraphQL error messages are structured and detailed

### Negative Consequences

- **Learning curve** - Team must learn GraphQL syntax and schema
- **Verbosity** - GraphQL queries are longer than REST endpoints
- **Debugging complexity** - Query structure errors can be harder to debug
- **Tooling dependency** - Requires `gh` CLI with GraphQL support
- **No REST fallback** - Can't easily switch to REST if GraphQL has issues

### Risks

- GitHub might deprecate or change GraphQL schema (mitigated by ADR review process)
- Complex nested queries might hit rate limits faster
- Schema changes could break existing queries (requires version monitoring)

## Alternatives Considered

### Alternative 1: Use REST API

**Rationale:** REST is simpler and more familiar to most developers.

**Why not chosen:**
- REST doesn't support issue types (`issueTypeId` field)
- REST doesn't support sub-issues API
- Can't traverse hierarchies without multiple REST calls
- Less efficient for bulk operations
- GitHub's newest features often aren't in REST

### Alternative 2: Mixed Approach (REST for Simple, GraphQL for Complex)

**Rationale:** Use REST for basic CRUD, GraphQL only when necessary.

**Why not chosen:**
- Inconsistent - team must learn and maintain both
- Harder to standardize error handling
- Need to decide "when to use which" for every operation
- More complex codebase with two API paradigms
- Creates confusion in documentation

### Alternative 3: GitHub CLI Convenience Commands

**Rationale:** Use `gh issue create`, `gh issue edit`, etc. instead of API calls.

**Why not chosen:**
- CLI commands don't expose all API features (e.g., issue types)
- Output format is human-readable, not machine-parseable
- Less control over exact request/response
- Wrapper around REST, inherits its limitations

## References

- [GitHub GraphQL API Documentation](https://docs.github.com/en/graphql)
- [scripts/Invoke-GraphQL.ps1](../../scripts/Invoke-GraphQL.ps1) - Our GraphQL wrapper
- [Okyerema Skill Documentation](/.github/skills/okyerema/SKILL.md)
- Repository memory: "Always use scripts/Invoke-GraphQL.ps1 instead of raw gh api graphql commands"
- Related ADR: [ADR-0001: Use Sub-Issues API for Hierarchy](./ADR-0001-use-sub-issues-for-hierarchy.md)

## Notes

- This is a **retroactive ADR** - the decision was made during Phase 1 implementation
- The decision is visible throughout the codebase but was never formally documented
- All scripts in `scripts/` and `.github/skills/okyerema/scripts/` follow this pattern
- GraphQL is used for writes; reads may use REST for convenience when GraphQL isn't needed
