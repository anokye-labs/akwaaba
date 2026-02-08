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
- **Relationships** — That's what tasklists are for
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

## Read Docs Before Debug

When something doesn't work as expected, agents must follow this workflow:

### The Workflow

1. **Read reference docs FIRST** — Check documentation, changelogs, and migration guides
2. **Check for API/feature changes** — Look for deprecations, retirements, or breaking changes
3. **THEN run diagnostics** — Only if docs don't explain the issue

### Why This Matters

Running diagnostic commands without understanding the system wastes time and context. Thirty seconds of reading often reveals what dozens of trial-and-error commands cannot.

### Real Example: The trackedIssues Mystery

**What happened:** During Okyerema development, an agent spent multiple turns running GraphQL queries trying to debug why `trackedIssues` returned 0 results:

```graphql
# Tried queries like this repeatedly:
query {
  repository(owner: "anokye-labs", name: "akwaaba") {
    issue(number: 1) {
      trackedIssues(first: 10) {
        totalCount
        nodes { ... }
      }
    }
  }
}
```

**What should have happened:**

1. **Read GitHub's changelog** → Discover that [tasklist blocks were retired](https://github.blog/changelog/2024-08-15-sunset-notice-tasklists-in-issues-markdown/)
2. **Check GraphQL schema docs** → See that `trackedIssues` depends on deprecated tasklist syntax
3. **Understand the change** → GitHub migrated from tasklists to sub-issues
4. **Apply the solution** → Use `closingIssuesReferences` or sub-issue relationships instead

**Time difference:**
- ❌ **Trial-and-error approach:** Multiple turns, wasted context tokens, no progress
- ✅ **Read-docs-first approach:** 30 seconds to find the answer, immediate solution

### How to Apply This

**Before running diagnostic commands, ask:**
- Have I checked the official documentation?
- Have I looked at recent changelogs or migration guides?
- Have I searched for deprecation notices?
- Do I understand what the API/feature is supposed to do?

**After reading docs, if still unclear:**
- Now run targeted diagnostic commands
- Use the knowledge from docs to interpret results
- Focus diagnostics on gaps in the documentation

### Anti-Patterns to Avoid

❌ **Don't do this:**
- Run `gh api` commands blindly hoping for clues
- Try variations without understanding why
- Debug for multiple turns without consulting docs
- Assume the API works the same as it did before

✅ **Do this instead:**
- Start with the source of truth (official docs)
- Understand the intended behavior first
- Use diagnostics to verify your understanding
- Check changelogs when behavior seems wrong

## Blocking Relationships

GitHub doesn't have native "blocks/blocked by" relationships. We handle this by:

1. **Issue body text** — "**Blocked by:** #7 (Phase 1 must complete first)"
2. **Project fields** — Custom "Blocks" and "Blocked By" text fields
3. **Phase ordering** — Issues within a phase generally depend on prior phases

## Lessons Learned

These rules exist because we made every mistake in the book:

| Mistake | What Happened | What We Do Now |
|---------|---------------|----------------|
| Used labels for types | Confusion about actual issue types | Use organization types via GraphQL |
| Used title prefixes | `[Epic]` in title doesn't set type | Set type via GraphQL mutation |
| Created flat hierarchies | Epic → 95 Tasks was unmanageable | Use Features to group tasks |
| Used gh CLI | Couldn't set types or relationships | Use GraphQL for all structured ops |
| Expected instant updates | Relationships didn't appear immediately | Wait 2-5 minutes after tasklist changes |
| Debugged before reading docs | Wasted turns on trackedIssues that was deprecated | Check changelogs and docs first, then debug |

---

*[← Back to How We Work](../how-we-work.md) | [Glossary →](./glossary.md)*
