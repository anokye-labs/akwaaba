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

## Branch Protection Rules

The following rules are enforced on this repository's default branch:

- **Pull request required** — All changes must go through a pull request. Direct pushes to the default branch are blocked.
- **Conversation resolution required** — All PR review comments and conversations must be resolved before merging.
- **Force pushes blocked** — Force pushes to the default branch are not allowed.
- **Branch deletion blocked** — The default branch cannot be deleted.

### Workflow

1. Create a feature branch (use git worktrees when possible)
2. Make changes and commit
3. Open a pull request targeting the default branch
4. Address all review comments and resolve conversations
5. Get at least 1 approval
6. Merge via the PR (squash or merge commit)

Never commit directly to the default branch. Never force push.

## Issue-First Workflow

**Every pull request must trace back to a GitHub Issue.** No PRs without issues. No direct commits to protected branches.

1. **Create an Issue** describing the work
2. **Create a branch** to implement
3. **Open a PR** that references the issue
4. **Review and merge** the PR, which closes the issue

## Issue Types (Required)

**Every issue MUST have an Issue Type applied.** Use the organization-level issue types defined for `anokye-labs` — these are the actual GitHub Issue Type field, NOT labels and NOT title prefixes.

| Issue Type | Use When |
|------------|----------|
| **Epic** | Large initiatives spanning multiple features |
| **Feature** | User-facing capabilities or system components |
| **Task** | Concrete, actionable work items |
| **Bug** | Defects and fixes |

Labels are for metadata and categorization only. Never use labels or title prefixes like `[TASK]` or `[BUG]` as a substitute for issue types.

## Issue Relationships

### Parent-Child Hierarchy

Use GitHub's sub-issues to create parent-child relationships:

- **3-level:** Epic → Feature → Task (when work groups into features)
- **2-level:** Feature → Task or Epic → Task (when tasks are standalone)

Maximum nesting depth is 8 levels, maximum 100 sub-issues per parent.

### Blocking Relationships

Create `blocked-by` / `blocking` relationships between issues to track dependencies. Before starting work on any issue, verify its blocking dependencies are resolved.

### GraphQL Required

Use the GraphQL API for issue types, sub-issues, and relationship management. The REST API does not support these features. Include the `GraphQL-Features: sub_issues` header for sub-issue operations.

## Delegating Work to Copilot

**Assigning issues to `@copilot` is the preferred way to get work done.** To delegate:

1. Create the issue with proper type, description, and relationships
2. Edit the issue and assign it to `@copilot`
3. Copilot will pick up the issue and open a PR

## Verification and Validation

**Agents must verify their own work thoroughly before handing back control.** Writing code and hoping it works is not acceptable. Verification goes beyond running unit tests — it means confirming the system actually behaves correctly end-to-end.

### Verification Expectations

1. **Build and test** — Run the build and all existing tests. Fix failures before declaring done.
2. **Runtime verification** — If the change affects runtime behavior, run the application and confirm it works. Don't just assume passing tests means the system is correct.
3. **Web UI verification** — If web pages or browser-based interfaces are involved, use the **Playwright CLI** skill to navigate, interact, screenshot, and validate the UI behaves correctly.
4. **Desktop/GUI verification** — If desktop GUI or graphical applications are involved and you're running in Copilot CLI, check for the availability of the **computer-use MCP server**. If available, use it to interact with and verify the GUI. If not available and you believe you need it, **ask the user to install it**.
5. **Integration verification** — If the change involves APIs, services, or external systems, make real calls and confirm responses. Don't mock what you can test live.

### When You Cannot Verify

If you cannot fully verify your work — due to missing tools, environment limitations, or access constraints:

1. **State it explicitly.** When you hand back control, clearly list what you were NOT able to validate.
2. **Explain why.** Say what tool, access, or capability you were missing.
3. **Ask for help.** If a tool or MCP server would enable verification, ask the user to install or configure it before you proceed.
4. **Never claim "done" without disclosure.** An honest "I could not verify X because Y" is always better than a silent gap.

### Available Verification Tools

| Scenario | Tool | How to Access |
|----------|------|---------------|
| Web pages / browser UI | Playwright CLI | Use the `playwright-cli` skill |
| Desktop GUI / graphical apps | Computer Use MCP | Check MCP server availability; ask user to install if needed |
| API endpoints | curl / Invoke-RestMethod | Direct HTTP calls |
| Build / test suites | Project build system | `dotnet test`, `npm test`, `pytest`, `cargo test`, etc. |
| File system / output | Direct inspection | Read and verify output files, logs, generated artifacts |

**Bottom line:** Do as much as possible to verify. Ask for help if you can't. Be transparent about what remains unverified.
