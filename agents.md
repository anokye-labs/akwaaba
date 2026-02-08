# Agents

AI agents working in Anokye Labs repositories should use the **Okyerema** skill for all project management operations.

## The Okyerema Skill

**Location:** [.github/skills/okyerema/SKILL.md](.github/skills/okyerema/SKILL.md)

The Okyerema (talking drummer) skill teaches agents how to:
- Create issues with proper organization types (Epic, Feature, Task, Bug)
- Build parent-child hierarchies using GitHub Tasklists
- Manipulate GitHub Projects via GraphQL
- Use labels appropriately (sparingly, for categorization only)
- Verify relationships and troubleshoot issues

## Quick Rules

1. **Use GraphQL for all structured operations** — gh CLI is insufficient
2. **Use organization issue types** — never labels or title prefixes
3. **Use Tasklists for relationships** — markdown checkboxes in issue body
4. **Wait 2-5 minutes** after tasklist updates for GitHub to parse
5. **Use labels sparingly** — categorization only, never structure

## Session Context

Every agent session should operate in the context of a specific GitHub issue. Before starting work:

1. Identify the issue you're working on
2. Check its dependencies (are blocking issues resolved?)
3. Understand where it sits in the hierarchy
4. Do the work
5. Update and close the issue when done

## Branch-Awareness Guard

Before performing any git operations, agents must verify they're on the expected branch:

### Pre-Flight Check

```bash
git branch --show-current
```

### Expected Branches

- **main** — Primary development branch
- **copilot/*** — Temporary branch created by GitHub Copilot for current task

### Guard Pattern

Before git operations (commit, push, merge, rebase), check current branch:

1. Run `git branch --show-current`
2. If on an unexpected branch (e.g., leftover `copilot/*` from a previous task):
   - Switch to the correct branch: `git checkout main` or `git checkout <expected-branch>`
   - Verify you're on the right branch before proceeding
3. If uncertain which branch to use, ask the user

### Why This Matters

Agent operations on the wrong branch lead to:
- Confusion about file state
- Unintended commits to wrong branches
- Merge conflicts
- Lost work

The branch-awareness guard prevents these issues by making branch verification an explicit pre-flight check.

## Human Documentation

For the human-readable version of how we work, see [how-we-work.md](./how-we-work.md).

## Future: Okyerema Plugin

Long-term, the Okyerema skill will move into a dedicated plugin in [anokye-labs/plugins](https://github.com/anokye-labs/plugins). Installing the plugin will set up the skill, helper scripts, and user-facing documentation automatically. Until then, the skill lives here in akwaaba.
