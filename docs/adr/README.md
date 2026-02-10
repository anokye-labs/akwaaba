# Architectural Decision Records (ADRs)

This directory contains Architectural Decision Records (ADRs) for the Akwaaba project.

## What is an ADR?

An Architectural Decision Record (ADR) is a document that captures an important architectural decision made along with its context and consequences.

## Why ADRs?

ADRs help us:
- **Remember why** - Document the reasoning behind key decisions
- **Communicate context** - Share knowledge with current and future team members
- **Validate changes** - Catch breaking changes when underlying assumptions shift
- **Learn from history** - Build institutional memory that survives personnel changes

## When to Write an ADR

Create an ADR when making decisions about:
- Architecture patterns and technology choices
- API designs and data models
- Build, deployment, or infrastructure approaches
- Security or compliance requirements
- Performance or scalability trade-offs

**Key principle:** If a future change might invalidate the decision, document it.

## ADR Format

We follow [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):

- **Status** - Proposed, Accepted, Deprecated, or Superseded
- **Context** - What forces are at play?
- **Decision** - What are we doing?
- **Consequences** - What are the impacts?

See [template.md](./template.md) for the full template.

## Naming Convention

ADRs are numbered sequentially:
- `ADR-0001-use-sub-issues-for-hierarchy.md`
- `ADR-0002-use-graphql-for-writes.md`
- `ADR-0003-use-org-level-issue-types.md`

## ADR Lifecycle

1. **Proposed** - Draft ADR created for discussion
2. **Accepted** - Team consensus reached, decision implemented
3. **Deprecated** - Decision no longer recommended, but may still exist in code
4. **Superseded** - Replaced by a newer ADR (reference the new ADR)

**Important:** ADRs are **immutable** once accepted. Never edit an accepted ADR - instead, create a new ADR that supersedes it.

## Current ADRs

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-0001](./ADR-0001-use-sub-issues-for-hierarchy.md) | Use sub-issues API for hierarchy | Accepted |
| [ADR-0002](./ADR-0002-use-graphql-for-writes.md) | Use GraphQL for all write operations | Accepted |
| [ADR-0003](./ADR-0003-use-org-level-issue-types.md) | Use organization-level issue types | Accepted |
| [ADR-0004](./ADR-0004-use-github-apps-for-agent-authentication.md) | Use GitHub Apps for agent authentication | Accepted |

## Process

See [how-we-work/adr-process.md](../../how-we-work/adr-process.md) for the complete ADR creation and review process.
