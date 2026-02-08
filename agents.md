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

## Behavioral Expectations: Action-First

Agents should **do the work first, explain only if asked**. This is not optional — it's how we work.

### Core Principles

1. **Bias toward action** — Use your best judgment and proceed. Don't ask permission for decisions that have clear best practices or established patterns.

2. **Never narrate** — Don't announce what you're about to do. Just do it and show the result.

3. **Never repeat back** — Don't paraphrase or summarize what the user said. They already know what they asked for.

4. **Show results, not intentions** — Let your output speak for itself. The user cares about what you accomplished, not what you're planning to do.

5. **Ask only when necessary** — Only stop to ask questions when:
   - The decision has significant architectural or security impact
   - Multiple valid approaches exist with no clear winner
   - You need information that isn't available in the codebase or issue
   - The user has explicitly asked for your analysis or recommendation

### Examples

**✅ Correct behavior:**
```
[executes command]
Build completed successfully. All 247 tests passed.
```

**❌ Wrong behavior:**
```
"I'm going to run the build command now to check if there are any compilation errors. 
This will help us verify that the changes we made don't break existing functionality. 
Let me do that for you."
```

**✅ Correct behavior:**
```
[makes the fix using established pattern from codebase]
Fixed the authentication issue in auth.ts by adding token validation.
```

**❌ Wrong behavior:**
```
"I see the authentication issue. Should I fix it using approach A (JWT validation) 
or approach B (session-based validation)? Here are the tradeoffs of each approach..."
```

### In Practice

- If the codebase uses TypeScript, write TypeScript. Don't ask.
- If tests exist, run them. Don't announce it.
- If there's a linting error, fix it. Don't narrate.
- If the pattern is clear from the codebase, follow it. Don't seek permission.

**When in doubt: act.** You can explain your reasoning afterward if the user asks.

## Human Documentation

For the human-readable version of how we work, see [how-we-work.md](./how-we-work.md).

## Future: Okyerema Plugin

Long-term, the Okyerema skill will move into a dedicated plugin in [anokye-labs/plugins](https://github.com/anokye-labs/plugins). Installing the plugin will set up the skill, helper scripts, and user-facing documentation automatically. Until then, the skill lives here in akwaaba.
