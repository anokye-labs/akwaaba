# Agent Behavior Conventions

This document encodes the behavioral conventions that AI agents must follow when working in Anokye Labs repositories. These conventions emerged from real session failures where agents over-explained, asked unnecessary questions, debugged without reading documentation, operated on wrong branches, and confused skill invocation patterns.

## 1. Action-First Principle

**Agents bias toward action with best judgment. Explain only if asked. Never narrate what you're about to do — just do it.**

### The Rule

Execute first, explain only when asked. Your code, output, and results are your communication. The user cares about what you accomplished, not what you're planning to accomplish.

### Do This ✅

```
[executes command]
Build completed. All 247 tests passed.
```

```
[makes the change]
Fixed authentication in auth.ts by adding token validation.
```

```
[runs diagnostic]
Error in line 42: undefined variable 'userId'. Fixed by initializing at line 38.
```

### Don't Do This ❌

```
"I'm going to run the build command now to check if there are any compilation errors. 
This will help us verify that the changes we made don't break existing functionality. 
Let me do that for you."
```

```
"I see the authentication issue. Before I fix it, let me explain what's happening: 
the token validation is missing, which means unauthorized requests could get through. 
I'll add the validation middleware..."
```

```
"Let me start by understanding what went wrong. I'll check the logs, then review 
the code, and then we can discuss potential solutions."
```

### When to Ask Questions

Only stop to ask when:
- The decision has significant **architectural or security impact**
- Multiple valid approaches exist with **no clear winner** based on codebase patterns
- You need information **not available** in the codebase, issue, or documentation
- The user has **explicitly asked** for your analysis or recommendation

Otherwise: **act immediately**.

### In Practice

- Codebase uses TypeScript? Write TypeScript. Don't ask.
- Tests exist? Run them. Don't announce it.
- Linting error? Fix it. Don't narrate.
- Pattern is clear from codebase? Follow it. Don't seek permission.
- Build fails? Fix the error. Don't explain the error back to the user.

**When in doubt: act.** You can explain your reasoning afterward if the user asks.

## 2. Read-Before-Debug Workflow

**When something doesn't work, consult reference documentation and upstream documentation BEFORE running diagnostic commands.**

### The Rule

Documentation first, diagnostics second. If reference docs exist, read them. If official upstream docs exist, check them. Only run diagnostic commands after exhausting documentation.

### Do This ✅

```
[reads .github/skills/okyerema/references/issue-creation.md]
[reads GitHub GraphQL API docs for createIssue mutation]
[implements the solution based on documented pattern]
Issue #142 created with correct type.
```

```
[checks scripts/README.md for usage examples]
[runs the script with documented parameters]
Script completed successfully.
```

```
[views existing test files to understand patterns]
[writes test following established pattern]
Test added to test/auth.test.ts.
```

### Don't Do This ❌

```
"Let me run some diagnostic commands to figure out why this isn't working..."
[runs gh issue list]
[runs gh api graphql]
[runs multiple exploratory commands]
"Now I think I understand the problem..."
```

```
"I'm not sure how to use this script. Let me try different parameter combinations 
to see what works..."
[trial and error with multiple invocations]
```

```
"Let me check what's happening by adding debug logging..."
[adds console.log statements]
[re-runs multiple times]
```

### The Diagnostic Hierarchy

When facing an issue, consult sources in this order:

1. **Local reference docs** — `.github/skills/*/references/`, `docs/`, `how-we-work/`
2. **Codebase examples** — Existing code that solves similar problems
3. **Inline documentation** — Comments, docstrings, script help text
4. **Upstream documentation** — Official API docs, library documentation
5. **Diagnostic commands** — ONLY after exhausting 1-4

### Exceptions

Run diagnostics immediately when:
- An **error message** explicitly tells you to check something specific
- You need to **verify** a fix you just implemented
- The user has asked you to **debug** or **investigate** something

## 3. Branch Awareness

**Agents verify they're on the expected branch before performing operations. Use `git branch --show-current` as a guard.**

### The Rule

Always verify the current branch before making changes, committing, or pushing. Wrong-branch operations waste time and create confusion.

### Do This ✅

```bash
# At the start of any session involving git operations
cd /home/runner/work/repo/repo
git branch --show-current
# Verify: copilot/my-feature-branch

# Then proceed with work
```

```bash
# Before committing changes
git branch --show-current
# Verify expected branch, then commit
```

```bash
# When the issue specifies a branch
# Issue: "Work on branch: phase-2-integration"
git branch --show-current
# Output: phase-2-integration ✓
# Proceed with confidence
```

### Don't Do This ❌

```bash
# Starting work without checking branch
cd /home/runner/work/repo/repo
# [makes changes immediately]
# [realizes later you were on main branch]
```

```bash
# Assuming you're on the right branch
# "I'll make the changes to the feature branch now..."
# [doesn't actually verify]
```

```bash
# Checking branch only after something goes wrong
git push origin feature-branch
# Error: branch feature-branch doesn't exist
git branch --show-current
# Oh, I was on main...
```

### Branch Verification Pattern

Use this pattern at the start of every session:

```bash
# 1. Navigate to repo
cd /home/runner/work/repo/repo

# 2. Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# 3. Verify or switch if needed
# If on wrong branch, fix it immediately
```

### When to Check Branch

Check the current branch:
- **At session start** — Before any git operations
- **Before committing** — Ensure changes go to the right branch
- **After checking out** — Verify the checkout succeeded
- **When confused** — If something doesn't make sense, check your branch

## 4. Skill Loading Patterns

**Clarify when skills are loaded as context (from .github/skills/) vs invoked as tools.**

### The Rule

**Skills are documentation, not tools.** Skills provide context and guidance that agents read and follow. They are NOT functions you invoke.

### What is a Skill?

A skill consists of:

1. **SKILL.md** — Core documentation with principles, patterns, and examples
2. **references/** — Detailed guides for specific operations
3. **scripts/** — Helper PowerShell scripts that agents can call

### Do This ✅

```
User: "Use the okyerema skill to create the issue hierarchy"

Agent:
[reads .github/skills/okyerema/SKILL.md]
[reads .github/skills/okyerema/references/hierarchy.md]
[follows the documented pattern]
[calls scripts/New-IssueWithType.ps1 if needed]
Created Epic #42, Features #43-45, and Tasks #46-52.
```

```
User: "Follow the testing skill"

Agent:
[reads .github/skills/testing/SKILL.md]
[applies principles from the documentation]
[writes tests following documented patterns]
Tests added following skill guidelines.
```

### Don't Do This ❌

```
User: "Use the okyerema skill"

Agent: 
"I'll invoke the okyerema skill now..."
[tries to find a tool or function named "okyerema"]
[fails to find it]
"I don't have access to that tool."
```

```
Agent:
"Let me call the skill function..."
[looks for skill() or okyerema() function]
"The skill doesn't seem to be responding."
```

```
Agent:
"I'll load the skill into my context..."
[never actually reads the SKILL.md file]
[makes up patterns instead of following documented ones]
```

### The Three-Part Pattern

When using a skill:

1. **Read** the SKILL.md file first
2. **Reference** guides in `references/` for detailed workflows  
3. **Call** scripts in `scripts/` when you need to perform operations

### Skill vs Tool

| Skills | Tools |
|--------|-------|
| Live in `.github/skills/` | Available in your tool list |
| Are documentation you read | Are functions you invoke |
| Provide context and patterns | Perform specific actions |
| You follow their guidance | You call them with parameters |

### Helper Scripts Within Skills

Scripts in `.github/skills/<skill>/scripts/` are **PowerShell helpers** that:
- Provide reusable implementations
- Can be called directly using `pwsh` command
- Are documented within the skill's SKILL.md

When a script exists for an operation, **use it** instead of reimplementing the logic.

**Example:**
```bash
# The okyerema skill documents this script
pwsh .github/skills/okyerema/scripts/New-IssueWithType.ps1 \
  -Title "My Task" \
  -Type Task \
  -Body "Description"
```

## 5. Minimal Communication

**Use the fewest words necessary. Never repeat back what the user said. Don't apologize theatrically.**

### The Rule

Communicate with precision and economy. Your words should add value, not fill space.

### Do This ✅

```
User: "Fix the build error in auth.ts"
Agent: [fixes the error]
Fixed. Build now passes.
```

```
User: "Add tests for the new authentication flow"
Agent: [writes tests]
Added 12 tests covering success, failure, and edge cases.
```

```
User: "The search feature is broken"  
Agent: [investigates and fixes]
Fixed null pointer in search.ts line 89. Search working.
```

### Don't Do This ❌

```
User: "Fix the build error in auth.ts"
Agent: "I understand you'd like me to fix the build error in the auth.ts file. 
I'll examine the error, determine the root cause, and implement a fix. Let me 
start by looking at the file..."
```

```
User: "Add tests for the new authentication flow"
Agent: "Sure! I'd be happy to help you add tests for the new authentication flow. 
Let me start by understanding what the authentication flow does, then I'll write 
comprehensive tests that cover all the scenarios..."
```

```
User: "The search feature is broken"
Agent: "I apologize for the inconvenience with the search feature. I sincerely 
apologize that this is causing issues. Let me investigate what went wrong. 
I'm really sorry about this problem..."
```

### Minimal Communication Rules

1. **No repetition** — Don't paraphrase what the user said
2. **No narration** — Don't announce what you're about to do
3. **No theatrical apologies** — A simple "Fixed" is better than "I deeply apologize..."
4. **No fluff** — Every word should add information
5. **Results over intentions** — Show what you did, not what you plan to do

### Acceptable Communication Patterns

**Acknowledgment + Action:**
```
[does the work immediately]
Done.
```

**Result + Key Detail:**
```
Fixed. The issue was a missing null check in line 42.
```

**Status + Next Step:**
```
Build passes. Ready for review.
```

**Finding + Resolution:**
```
Found 3 vulnerabilities. Fixed 2, marked 1 as false positive.
```

### When More Words Are Appropriate

Use more words when:
- **Reporting failure** — Explain what went wrong and why
- **Significant findings** — Security issues, data loss risks, breaking changes
- **Blocked work** — Dependencies not met, missing information
- **Explicitly asked** — User requests explanation or analysis

Even then: **be concise**. More words ≠ better communication.

### The Test

Before sending a message, ask:
- Would the user already know this?
- Am I adding new information?
- Could I say this in half the words?

If answers are yes, yes, yes — send it. Otherwise, cut it down or remove it.

---

## Summary

These five conventions form the core of how AI agents should behave in Anokye Labs repositories:

1. **Action-First** — Do it, don't discuss it
2. **Read-Before-Debug** — Documentation before diagnostics
3. **Branch Awareness** — Verify before operating
4. **Skill Loading** — Skills are docs, not tools
5. **Minimal Communication** — Precision over verbosity

These aren't suggestions — they're requirements. They exist because we've experienced the frustration of agents that violate them. Follow these conventions and you'll be an effective contributor to the Anokye system.

---

*[← Back to How We Work](../how-we-work.md) | [Agents →](../agents.md)*
