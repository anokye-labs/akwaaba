# Contributing to Akwaaba

👋 **Akwaaba!** (Akan/Twi: "Welcome")

Thank you for your interest in contributing to Akwaaba. This repository is a reference implementation of the **Anokye-Krom System** — a governance model where AI agents handle all commits in response to human-created issues.

## The Issue-First Workflow

At Anokye Labs, **all work begins with a GitHub issue**. This is not just a best practice — it's how the system works:

1. **Humans create issues** — You identify what needs to be done and create an issue describing it
2. **Agents implement the work** — AI agents read the issue, make the changes, and create pull requests
3. **Humans review and merge** — You review the agent's work and merge when satisfied

This workflow ensures:
- All changes are tracked and documented
- Work is coordinated through a single source of truth
- The "why" behind every commit is clear and searchable

## Direct Commits Are Blocked

**Important:** Direct commits to protected branches (like `main`) are not permitted. All changes must go through the issue → agent → pull request workflow.

This restriction is enforced via:
- GitHub branch protection rules
- Commit validation workflows
- Agent authentication checks (only approved agents can commit)

Even repository maintainers follow this rule. It ensures consistency, auditability, and maintains the integrity of the Anokye-Krom System.

**Learn more:** [Agent Setup Guide](./how-we-work/agent-setup.md)

## How to Contribute

### 1. Create an Issue

Start by creating a GitHub issue that describes:
- **What** needs to be done
- **Why** it's needed
- **Acceptance criteria** — How will we know it's complete?

Use the appropriate issue type:
- **Epic** — A large initiative spanning multiple features
- **Feature** — A cohesive piece of functionality
- **Task** — A specific work item
- **Bug** — Something that's broken

### 2. Label Your Issue (Optional)

Labels are for categorization, not structure:
- ✅ Good: `documentation`, `security`, `powershell`
- ❌ Bad: `epic`, `in-progress`, `blocked`

For newcomers, consider adding the `good-first-issue` label (see below).

### 3. Wait for an Agent

Once your issue is created, an AI agent will:
1. Read and understand the issue
2. Implement the changes
3. Create a pull request
4. Link the PR back to the issue

### 4. Review and Provide Feedback

When the agent creates a pull request:
- Review the code changes
- Test the functionality
- Provide feedback via PR comments
- Request changes if needed

The agent will respond to your feedback and update the PR accordingly.

### 5. Merge

Once you're satisfied with the changes, merge the pull request. The issue will automatically close.

## Good First Issues

If you're new to the project or want to help others get started, look for issues labeled `good-first-issue`. These are:
- Well-defined and scoped
- Have clear acceptance criteria
- Require minimal context about the codebase
- Good learning opportunities

**Creating good first issues:**
When you identify work suitable for newcomers:
1. Create a detailed issue with clear instructions
2. Add the `good-first-issue` label
3. Include links to relevant documentation
4. Specify any prerequisites or setup needed

## Learning More

To understand how we structure and coordinate work:
- **[How We Work](./how-we-work.md)** — Overview of our coordination system
- **[Our Way](./how-we-work/our-way.md)** — Detailed philosophy and practices
- **[Getting Started](./how-we-work/getting-started.md)** — New to GitHub Issues? Start here
- **[Glossary](./how-we-work/glossary.md)** — Akan terms and concepts we use

For AI agents working in this repository:
- **[Agents Documentation](./agents.md)** — How agents should behave
- **[Okyerema Skill](/.github/skills/okyerema/SKILL.md)** — Project orchestration skill

## Contribution Guidelines

For detailed contribution guidelines, including:
- Code style and conventions
- Testing requirements
- Documentation standards
- Security policies

See **[CONTRIBUTION_GUIDELINES.md](./CONTRIBUTION_GUIDELINES.md)** *(placeholder - to be created)*

## Questions or Problems?

If you have questions about:
- **The issue-first workflow** — See [How We Work](./how-we-work.md)
- **Agent behavior** — See [Agent Conventions](./how-we-work/agent-conventions.md)
- **Technical setup** — Create an issue with the `question` label
- **Something else** — Open an issue and we'll help

---

**The Anokye-Krom System:** Where humans create the vision, agents execute the work, and everyone benefits from structured, auditable, collaborative development.
