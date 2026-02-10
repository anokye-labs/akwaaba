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
- **GitHub branch protection rules** — Direct commits to main are blocked
- **Agent authentication workflow** — Only approved agents can commit (see [Approved Agents](./.github/APPROVED-AGENTS.md))
- **Commit validation workflows** — All commits must reference issues

Even repository maintainers follow this rule. It ensures consistency, auditability, and maintains the integrity of the Anokye-Krom System.

**For complete details on branch protection and bypass procedures, see [GOVERNANCE.md](GOVERNANCE.md).**

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
- **[Agent Setup Guide](./how-we-work/agent-setup.md)** — How to register and configure agents
- **[Agents Documentation](./agents.md)** — How agents should behave
- **[Okyerema Skill](/.github/skills/okyerema/SKILL.md)** — Project orchestration skill

## Commit Message Format

All commits must follow the **Conventional Commits** specification and reference an open GitHub issue.

### Format

```
<type>(<scope>): <description> (#issue)

[optional body]

[optional footer]
```

### Required Elements

1. **Type**: The kind of change (see types below)
2. **Description**: A clear, concise summary of the change
3. **Issue Reference**: At least one GitHub issue number (`#123`)

### Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(auth): Add OAuth2 support (#123)` |
| `fix` | Bug fix | `fix(api): Resolve timeout issue (#456)` |
| `docs` | Documentation only | `docs: Update API guide (#789)` |
| `style` | Formatting, no code change | `style: Fix indentation (#234)` |
| `refactor` | Code restructuring | `refactor(core): Simplify error handling (#567)` |
| `test` | Adding or updating tests | `test: Add unit tests for auth (#890)` |
| `chore` | Maintenance tasks | `chore: Update dependencies (#345)` |
| `perf` | Performance improvement | `perf(db): Optimize query execution (#678)` |
| `ci` | CI/CD changes | `ci: Add caching to workflow (#901)` |

### Scope (Optional but Recommended)

The scope indicates what area of the codebase is affected:
- `auth` - Authentication and authorization
- `api` - API endpoints and handlers
- `db` - Database and data access
- `ui` - User interface components
- `docs` - Documentation
- `test` - Testing infrastructure
- `core` - Core functionality
- `governance` - Repository governance

### Issue Reference Formats

You can reference issues in several ways:

```bash
# Basic reference (preferred for most commits)
feat(api): Add new endpoint (#123)

# Using action keywords (closes the issue when merged)
fix(auth): Resolve login bug - Fixes #456
fix(auth): Resolve login bug - Closes #456
fix(auth): Resolve login bug - Resolves #456

# Multiple issues
feat(ui): Update dashboard (Fixes #123, #456)
docs: Update guides (#789, #890)
```

### Complete Examples

**Basic feature:**
```
feat(api): Add user profile endpoint (#123)

Implements GET /api/users/:id endpoint to retrieve user profiles.
Includes validation and error handling.
```

**Bug fix with details:**
```
fix(auth): Prevent token expiration race condition (#456)

The token refresh logic had a race condition when multiple requests
occurred simultaneously. Added mutex to synchronize token updates.

Fixes #456
```

**Documentation update:**
```
docs: Add authentication guide (#789)

Created comprehensive guide covering OAuth2 flow, token management,
and common troubleshooting scenarios.
```

**Refactoring with breaking change:**
```
refactor(api): Restructure error responses (#234)

BREAKING CHANGE: Error response format changed from {error: string}
to {code: string, message: string, details: object}

Closes #234
```

### Validation

The **Commit Validator** workflow checks every commit to ensure:
- ✅ Contains a valid issue reference
- ✅ Referenced issue exists and is open
- ✅ Follows conventional commit format (recommended)
- ✅ Has a clear, descriptive message

Invalid commits will block the pull request from merging.

### Examples of Valid Commits

```bash
✅ feat(auth): Add OAuth2 support (#123)
✅ fix(api): Resolve timeout issue - Fixes #456
✅ docs: Update README with installation steps (#789)
✅ refactor(core): Simplify error handling (closes #234)
✅ test: Add integration tests (#567)
✅ chore(deps): Update packages (#890)
```

### Examples of Invalid Commits

```bash
❌ Add new feature
   → Missing issue reference

❌ Fix bug (#9999)
   → Issue doesn't exist

❌ Update docs (Closes #888)
   → Issue #888 is closed

❌ WIP
   → No issue reference or description

❌ feat: stuff (#123)
   → Description too vague
```

### Tips for Good Commit Messages

1. **Be specific**: "Fix login bug" → "Fix OAuth token refresh race condition"
2. **Use imperative mood**: "Add feature" not "Added feature" or "Adding feature"
3. **Reference the issue**: Always include the issue number
4. **Keep it concise**: First line should be ≤ 50 characters (72 max)
5. **Add details in body**: Use the body for detailed explanations if needed
6. **One logical change**: Each commit should be one cohesive change

### FAQs

**Q: Can I reference multiple issues in one commit?**  
A: Yes! Use commas: `feat(api): Add endpoints (#123, #456)`

**Q: What if I'm working on a task that's part of a feature?**  
A: Reference the specific task issue number, not the parent feature or epic.

**Q: Can I use URLs instead of `#123`?**  
A: Yes, but `#123` is preferred. Both work: `#123` or `https://github.com/anokye-labs/akwaaba/issues/123`

**Q: What about merge commits?**  
A: Merge commits are validated the same way. The PR must reference an issue.

**Q: Can I amend or rebase commits?**  
A: Yes, but remember: force pushing to `main` is blocked. Only amend/rebase on feature branches before merging.

**Q: What if I make a typo in the issue reference?**  
A: The commit validator will fail. You'll need to amend the commit with the correct reference.

**Q: Do I need to follow conventional commits exactly?**  
A: The issue reference is strictly required. Conventional commits format is strongly recommended for consistency.

**Q: Can I use WIP commits?**  
A: Yes, but they still need an issue reference: `WIP: #123 Implement feature X`

**Q: What about commits from bots or automation?**  
A: Approved bots (like Dependabot) are allowed. See [GOVERNANCE.md](GOVERNANCE.md) for details.

For more details on governance and enforcement, see [GOVERNANCE.md](GOVERNANCE.md).

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
