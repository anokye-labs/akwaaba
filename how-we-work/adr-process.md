# ADR Process

An **Architectural Decision Record (ADR)** is a lightweight document that captures an important technical decision along with its context and consequences.

## Why We Use ADRs

The decision to use tasklist blocks for issue hierarchy was never formally documented. When GitHub retired tasklist blocks in late 2024, we had no ADR to flag for review. An ADR like "ADR-001: Use tasklist blocks for issue hierarchy" would have been immediately caught during the retirement announcement, allowing us to plan migration proactively instead of reactively.

**ADRs serve as trip wires** - they ensure that when underlying assumptions change (APIs deprecate, platforms evolve, requirements shift), we catch the impact early and can respond deliberately.

## When to Write an ADR

Create an ADR when making decisions about:

- **Architecture patterns** - How components interact, data flows, boundaries
- **Technology choices** - Languages, frameworks, libraries, platforms
- **API designs** - Public interfaces, data models, contracts
- **Infrastructure** - Build systems, deployment, CI/CD
- **Security** - Authentication, authorization, data protection
- **Performance** - Caching, scalability, optimization strategies

**Key principle:** If a future change (platform update, API deprecation, requirement shift) might invalidate the decision, write it down.

### What NOT to Document as ADR

- Temporary implementation details
- Obvious best practices (e.g., "use HTTPS")
- Decisions easily reversible without impact
- Personal preferences without architectural impact

## ADR Format

We follow [Michael Nygard's ADR format](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions):

```markdown
# ADR-NNNN: [Short Title]

**Status:** [Proposed | Accepted | Deprecated | Superseded]
**Date:** YYYY-MM-DD
**Deciders:** [Who made this decision]
**Tags:** [Optional categorization tags]

## Context
What forces are at play? What's the issue we're addressing?

## Decision
What are we doing? Be clear and specific.

## Consequences
What becomes easier or harder? What are the trade-offs?

### Positive Consequences
- Benefit 1
- Benefit 2

### Negative Consequences
- Drawback 1
- Drawback 2

### Risks
- Risk 1
- Risk 2

## Alternatives Considered
What else did we evaluate and why didn't we choose it?

## References
Links to issues, PRs, discussions, docs, articles
```

See [docs/adr/template.md](../docs/adr/template.md) for the full template.

## ADR Lifecycle

### 1. Proposed

Draft ADR created for discussion. May be in a PR or issue.

**Actions:**
- Share with stakeholders
- Gather feedback
- Iterate on context and consequences
- Consider alternatives

### 2. Accepted

Decision made, ADR merged, implementation proceeds.

**Actions:**
- Merge ADR to main branch
- Update [docs/adr/README.md](../docs/adr/README.md) index
- Reference ADR in related code/docs
- Implement the decision

### 3. Deprecated

Decision no longer recommended, but may still exist in code.

**Actions:**
- Update status to "Deprecated"
- Add deprecation context
- Document recommended alternative
- Create migration path if needed

### 4. Superseded

Replaced by a newer ADR.

**Actions:**
- Update status to "Superseded by ADR-NNNN"
- Leave original ADR intact (immutable)
- New ADR should reference superseded ADR
- Migration plan in new ADR

## Creating an ADR

### Step 1: Copy Template

```bash
cp docs/adr/template.md docs/adr/ADR-NNNN-your-title.md
```

Number sequentially (NNNN = 0001, 0002, etc.).

### Step 2: Fill in Context

Explain the forces at play:
- What problem are we solving?
- What constraints exist?
- What are the business/technical requirements?
- Why does this matter?

### Step 3: Document Decision

Be specific and actionable:
- What exactly are we doing?
- How will it be implemented?
- What changes as a result?

### Step 4: Analyze Consequences

Be honest about trade-offs:
- What improves? (positive)
- What gets harder? (negative)
- What could go wrong? (risks)

### Step 5: Consider Alternatives

Show you evaluated options:
- What else did you consider?
- Why didn't you choose those?
- What were the trade-offs?

### Step 6: Review and Discuss

- Open PR with the ADR
- Get feedback from team
- Iterate based on discussion
- Reach consensus

### Step 7: Accept and Merge

- Update status to "Accepted"
- Add actual date
- Merge to main
- Update docs/adr/README.md index

## Retroactive ADRs

Sometimes decisions are made informally or implicitly. When you discover an undocumented architectural decision, create a retroactive ADR:

1. Date it with today's date (when documented, not when decided)
2. Note in the "Notes" section that it's retroactive
3. Explain why it wasn't documented originally
4. Capture current state as accurately as possible

**Example:** ADR-0001, ADR-0002, and ADR-0003 are all retroactive, documenting decisions made during initial implementation.

## Modifying ADRs

### Golden Rule: ADRs are Immutable

Once accepted, **never edit an ADR's decision or context**. If the decision changes, create a new ADR that supersedes it.

### Allowed Changes

You may edit an accepted ADR only to:
- Fix typos or formatting
- Add clarifying notes
- Add "Superseded by" status
- Add references to newer ADRs

### Wrong Approach

❌ Edit ADR-0001 to say "now we use REST instead of GraphQL"

### Right Approach

✅ Create ADR-0005 titled "Use REST for Read Operations" with status "Supersedes ADR-0002"

## ADR Review Process

### During Planning

When proposing a significant change:
1. Check existing ADRs for conflicts
2. If it contradicts an ADR, either:
   - Adjust your approach, or
   - Create new ADR to supersede the old one

### During Implementation

Reference relevant ADRs in:
- PR descriptions
- Code comments (for non-obvious decisions)
- Documentation updates

### During External Changes

When platforms, libraries, or dependencies change:
1. Review ADR list for impacted decisions
2. Open issue to discuss if ADR is now invalid
3. Create superseding ADR if needed

**Example:** GitHub announces API deprecation → Check ADRs → Find ADR-0001 uses that API → Create ADR-NNNN to supersede with new approach

## ADR Index

All ADRs are listed in [docs/adr/README.md](../docs/adr/README.md) with:
- ADR number and title
- Current status
- Quick summary

Keep this index updated when adding new ADRs.

## Questions?

- **Should every decision be an ADR?** No. Focus on architectural decisions with long-term impact.
- **Can I update an ADR after it's accepted?** Only for typos/clarifications. For changes, create a new superseding ADR.
- **What if I disagree with an ADR?** Open an issue to discuss, potentially leading to a superseding ADR.
- **How detailed should ADRs be?** Enough to understand context and consequences, but stay concise (1-2 pages).

## Further Reading

- [Michael Nygard's Original ADR Article](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [ADR GitHub Organization](https://adr.github.io/)
- [docs/adr/](../docs/adr/) - Our ADR directory

---

*Continue reading: [Our Way](./our-way.md) | [Getting Started](./getting-started.md)*
