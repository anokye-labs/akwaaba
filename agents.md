# Agents

AI agents working in Anokye Labs repositories should use the **Okyerema** skill for all project management operations.

## What is a Skill?

**A skill is documentation, not a tool.**

Skills in `.github/skills/` provide **context and guidance** that agents should read and follow. They are NOT tools that get invoked or called.

### Anatomy of a Skill

A skill consists of:

1. **SKILL.md** — The core documentation with principles, patterns, and examples
2. **references/** — Detailed guides for specific operations (loaded when needed)
3. **scripts/** — Helper PowerShell scripts that agents can call

### How to Use a Skill

When you need to use a skill (e.g., "use the okyerema skill"):

1. **Read** the SKILL.md file
2. **Follow** its principles and patterns
3. **Reference** the guides in `references/` for detailed workflows
4. **Call** the scripts in `scripts/` when you need to perform operations

**Do NOT** try to "invoke" a skill as if it were a function or tool. The skill IS the documentation — read it, understand it, apply it.

### Helper Scripts

Scripts in `.github/skills/<skill>/scripts/` are PowerShell helpers that:
- Provide reusable implementations of common operations
- Can be called directly by agents using the `pwsh` command
- Are documented within the skill's SKILL.md file

When a script exists for an operation, **use it** instead of reimplementing the logic.

## The Okyerema Skill

**Location:** [.github/skills/okyerema/SKILL.md](.github/skills/okyerema/SKILL.md)

The Okyerema (talking drummer) skill teaches agents how to:
- Create issues with proper organization types (Epic, Feature, Task, Bug)
- Build parent-child hierarchies using GitHub's sub-issues API
- Manipulate GitHub Projects via GraphQL
- Use labels appropriately (sparingly, for categorization only)
- Verify relationships and troubleshoot issues

## Quick Rules

1. **Use GraphQL for all structured operations** — gh CLI is insufficient
2. **Use organization issue types** — never labels or title prefixes
3. **Use sub-issues API for relationships** — createIssueRelationship mutation
4. **Include GraphQL-Features: sub_issues header** — required for sub-issues operations
5. **Use labels sparingly** — categorization only, never structure

## Session Context

Every agent session should operate in the context of a specific GitHub issue. Before starting work:

1. Identify the issue you're working on
2. Check its dependencies (are blocking issues resolved?)
3. Understand where it sits in the hierarchy
4. Do the work
5. Update and close the issue when done

## Agent Setup and Authentication

New agents must be registered before they can work in Anokye Labs repositories. See the **[Agent Setup Guide](how-we-work/agent-setup.md)** for:

- How to register a new agent
- Authentication requirements
- Approved agents list management
- Troubleshooting authentication issues

## Behavioral Conventions

AI agents working in Anokye Labs repositories must follow specific behavioral conventions. These conventions emerged from real session failures and are **requirements, not suggestions**.

For comprehensive documentation with detailed examples, see **[Agent Behavior Conventions](how-we-work/agent-conventions.md)**.

### The Five Core Conventions

1. **Action-First Principle** — Do it, don't discuss it. Execute immediately with best judgment. Explain only if asked.

2. **Read-Before-Debug Workflow** — Consult documentation before running diagnostics. Check reference docs, codebase examples, and upstream documentation before trial-and-error.

3. **Branch Awareness** — Verify current branch with `git branch --show-current` before any git operations. Wrong-branch work wastes time.

4. **Skill Loading Patterns** — Skills are documentation you read, not tools you invoke. Read SKILL.md, reference guides in `references/`, and call scripts in `scripts/`.

5. **Minimal Communication** — Use fewest words necessary. No repetition, no narration, no theatrical apologies.

### Quick Examples

**✅ Correct behavior:**
```
[checks branch: git branch --show-current]
[reads .github/skills/okyerema/SKILL.md]
[executes the operation]
Created Epic #42 with 5 child Features.
```

**❌ Wrong behavior:**
```
"I'm going to check what branch I'm on, then read the documentation to understand 
how to create the hierarchy. Let me start by examining the skill..."
```

**✅ Correct behavior:**
```
[reads reference docs for the error]
[implements documented solution]
Fixed. Build passes.
```

**❌ Wrong behavior:**
```
"Let me run some diagnostics to figure out what's wrong..."
[runs multiple exploratory commands]
"Now I'll try different approaches to see what works..."
```

### When to Act vs Ask

**Act immediately** when:
- Established patterns exist in the codebase
- Documentation provides clear guidance
- The operation is reversible or low-risk
- Best practices are well-known

**Ask first** when:
- Significant architectural or security impact
- Multiple valid approaches with no clear winner
- Information is not available in codebase/docs
- User explicitly requested your recommendation

**Default: act.** Explaining afterward if needed is better than asking permission.

## Human Documentation

For the human-readable version of how we work, see [how-we-work.md](./how-we-work.md).

## Future: Okyerema Plugin

Long-term, the Okyerema skill will move into a dedicated plugin in [anokye-labs/plugins](https://github.com/anokye-labs/plugins). Installing the plugin will set up the skill, helper scripts, and user-facing documentation automatically. Until then, the skill lives here in akwaaba.
