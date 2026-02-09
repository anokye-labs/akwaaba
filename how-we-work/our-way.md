# Our Way: Coordinating Adwoma through the Asafo

This is how Anokye Labs structures and coordinates work. It's opinionated — built from real experience, including mistakes we've made and corrected.

## The Philosophy

We believe in:

1. **Structure over tags** — Use issue types and relationships, not labels
2. **Hierarchy over flatness** — Epic → Feature → Task gives clarity at every level
3. **Automation over ceremony** — Scripts and agents handle the bookkeeping
4. **Verification over assumption** — Always check that the system reflects reality

## Issue Types Are Sacred

At Anokye Labs, every issue must have the correct **type**:

| Type | When to Use |
|------|-------------|
| **Epic** | A phase of work or major initiative |
| **Feature** | A cohesive piece that groups related tasks |
| **Task** | A specific, completable work item |
| **Bug** | Something broken |

**These are set via GitHub's organization settings, not labels.** This is the single most important rule. If you see issues with labels like "epic" or "task" instead of actual types, something has gone wrong.

## The Three-Level Hierarchy

### When to Use Three Levels

Use **Epic → Feature → Task** when your Epic has natural groupings:

```
Epic: Phase 2 - Integration
├─ Feature: Core Skill Creation
│  ├─ Task: Analyze existing scripts
│  └─ Task: Create SKILL.md
├─ Feature: Script Conversion (8 tasks)
├─ Feature: Reference Documentation (7 tasks)
└─ Feature: Testing & Validation (2 tasks)
```

This is the right choice when:
- You have 5+ tasks that fall into clear categories
- Features represent distinct deliverables
- Multiple people might work on different features in parallel

### When to Use Two Levels

Use **Epic → Task** when tasks are standalone:

```
Epic: Phase 0 - Setup
├─ Task: Initialize repository
├─ Task: Create directory structure
└─ Task: Write .gitignore
```

This is the right choice when:
- Tasks are independent
- No natural groupings exist
- The phase is simple (setup, config, cleanup)

## Labels: Less Is More

We follow a strict policy on labels:

### ✅ Use Labels For
- **Categorization** — `documentation`, `security`, `performance`
- **Technology** — `powershell`, `typescript`, `graphql`
- **Milestones** — `phase-2-fal-ai` (when GitHub milestones aren't granular enough)
- **Special flags** — `good-first-issue`, `help-wanted`, `breaking-change`

### ❌ Never Use Labels For
- **Issue types** — That's what types are for
- **Relationships** — That's what sub-issues are for
- **Status** — That's what issue state and Projects are for
- **Working around missing features** — Find the proper tool

**Rule of thumb:** If you're creating a label to communicate structure, you're using the wrong mechanism.

## Projects as Dashboards

GitHub Projects are for **visualization and tracking**, not for defining relationships:

- Use Projects to see the big picture across issues
- Use custom fields for priority, status, and effort
- Don't confuse Project fields with issue relationships — they're separate systems

## The Agent Workflow

AI agents in our repositories follow a disciplined workflow:

1. **Check the issue** — Every session starts in the context of a GitHub issue
2. **Check dependencies** — Are blocking issues resolved?
3. **Do the work** — Implement what the issue describes
4. **Verify** — Run tests, check behavior
5. **Update the issue** — Report progress, close when done

The [Okyerema skill](../.github/skills/okyerema/SKILL.md) gives agents the technical tools to do all of this correctly.

## Agent Behavioral Conventions

AI agents must follow specific behavioral conventions when working in Anokye Labs repositories. These conventions emerged from real session failures and encode requirements for effective agent behavior.

**See [Agent Behavior Conventions](./agent-conventions.md) for comprehensive documentation.**

### The Five Core Conventions

1. **Action-First Principle** — Do the work immediately with best judgment. Explain only if asked. Never narrate.

2. **Read-Before-Debug Workflow** — Consult reference docs and upstream documentation BEFORE running diagnostic commands.

3. **Branch Awareness** — Verify current branch with `git branch --show-current` before any git operations.

4. **Skill Loading Patterns** — Skills are documentation you read (from `.github/skills/`), not tools you invoke.

5. **Minimal Communication** — Use fewest words necessary. No repetition, no theatrical apologies.

These aren't suggestions — they're requirements that make agents effective contributors to the Anokye system.

## Blocking Relationships

GitHub doesn't have native "blocks/blocked by" relationships. We handle this by:

1. **Issue body text** — "**Blocked by:** #7 (Phase 1 must complete first)"
2. **Project fields** — Custom "Blocks" and "Blocked By" text fields
3. **Phase ordering** — Issues within a phase generally depend on prior phases

## Sub-Issues API for Hierarchy

We use GitHub's **sub-issues API** to create parent-child relationships in our Epic → Feature → Task hierarchy.

### Creating Relationships

Use the `createIssueRelationship` mutation to establish parent-child relationships:

```graphql
mutation {
  createIssueRelationship(input: {
    repositoryId: "R_xxx"
    parentId: "I_parent_xxx"
    childId: "I_child_xxx"
  }) {
    issueRelationship {
      parent { number }
      child { number }
    }
  }
}
```

**Important:** When using sub-issues API via GraphQL, you must include the header:
```
GraphQL-Features: sub_issues
```

### Querying Relationships

Query relationships using the `parent` and `subIssues` fields:

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
        }
      }
    }
  }
}
```

### Why Sub-Issues?

- **Immediate** — No parsing delays like the old tasklist approach
- **Official API** — Supported by GitHub, future-proof
- **Better UI** — Sub-issues appear in a dedicated section
- **Reliable** — Direct relationships, no markdown parsing required

See [ADR-0001: Use Sub-Issues API for Hierarchy](../docs/adr/ADR-0001-use-sub-issues-for-hierarchy.md) for the full rationale.

## Lessons Learned

These rules exist because we made every mistake in the book:

| Mistake | What Happened | What We Do Now |
|---------|---------------|----------------|
| Used labels for types | Confusion about actual issue types | Use organization types via GraphQL |
| Used title prefixes | `[Epic]` in title doesn't set type | Set type via GraphQL mutation |
| Created flat hierarchies | Epic → 95 Tasks was unmanageable | Use Features to group tasks |
| Used gh CLI | Couldn't set types or relationships | Use GraphQL for all structured ops |
| Used tasklists | Relied on deprecated API, parsing delays | Use sub-issues API with createIssueRelationship |

---

*[← Back to How We Work](../how-we-work.md) | [Glossary →](./glossary.md)*
