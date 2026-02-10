# Agent Setup Guide

This guide explains how to set up and use AI agents in Anokye Labs repositories.

## Overview

Anokye Labs repositories follow an **agent-only commit policy**. This means:

- ✅ **Agents write all code** — AI agents make all commits and create all PRs
- ✅ **Humans guide and review** — Humans create issues, review PRs, and provide feedback
- ❌ **Humans don't commit directly** — No human commits are allowed on protected branches

## Why Agent-Only?

The **Anokye-Krom System** separates planning from execution:

1. **Clear Separation of Concerns** — Humans excel at planning and judgment; agents excel at execution
2. **Consistent Quality** — AI ensures consistent code style and patterns
3. **Full Audit Trail** — Every change is traceable to a specific issue and agent decision
4. **Issue-Driven Development** — Forces clear requirements before coding begins
5. **Scalability** — Agents can work in parallel on multiple issues simultaneously

Read more: [How We Work](./how-we-work.md)

## Quick Start: Using an Agent

### Step 1: Create an Issue

All work starts with a GitHub issue. Use one of our issue types:

- **Epic** — Large initiative spanning multiple features
- **Feature** — Cohesive piece of functionality
- **Task** — Specific, actionable work item
- **Bug** — Defect that needs fixing

Example task issue:
```markdown
## Description
Add authentication middleware to protect API endpoints

## Acceptance Criteria
- [ ] JWT validation middleware implemented
- [ ] Middleware added to protected routes
- [ ] Tests added for auth flows
- [ ] Documentation updated

## Dependencies
Blocked by: #123 (API routes must exist first)
```

### Step 2: Assign an Approved Agent

Assign an approved agent to the issue:

```bash
# Using GitHub CLI
gh issue edit 42 --add-assignee @copilot

# Or via the GitHub web UI
# Click "Assignees" → Select agent → Save
```

### Step 3: Agent Creates PR

The agent will:
1. Read the issue and understand requirements
2. Make necessary code changes
3. Create a PR referencing the issue
4. Respond to feedback and iterate

### Step 4: Review and Merge

As a human:
1. Review the PR code and changes
2. Test the functionality if needed
3. Provide feedback via PR comments
4. Approve and merge when satisfied

## Currently Approved Agents

### GitHub Copilot (@copilot)

- **Type:** GitHub App
- **Use Cases:** General-purpose coding, refactoring, bug fixes, documentation
- **Trigger:** Assign to issue with `@copilot`
- **Documentation:** [GitHub Copilot Docs](https://docs.github.com/en/copilot)

### Future Agents

We're exploring additional agents for specialized tasks:
- Code review automation
- Documentation generation
- Testing and validation
- Project orchestration

## Setting Up Your Own Agent

Want to use an AI agent in your workflow? Here's how:

### Option 1: Use GitHub Copilot (Recommended)

GitHub Copilot is already approved for this repository:

1. **Enable Copilot** in your GitHub account
2. **Assign it to an issue:** `@copilot` 
3. **Let it work** — Copilot will create a PR

### Option 2: Use a Custom Agent

To use a different AI agent:

1. **Choose your agent** — Claude, GPT-4, Gemini, etc.
2. **Set up authentication** — GitHub App, Personal Access Token, or OAuth
3. **Request approval** — Submit an agent request (see below)
4. **Wait for review** — Typically 1-2 business days

### Option 3: Build Your Own Agent

Building a custom agent? Here's what you need:

**Technical Requirements:**
- Authenticate via GitHub App (preferred) or PAT
- Read issues from the repository
- Create branches and commits
- Open pull requests
- Respond to PR comments

**Behavioral Requirements:**
- Follow [Agent Conventions](./agent-conventions.md)
- Reference issue numbers in commits
- Write clear, focused PRs
- Respond to review feedback

**Resources:**
- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [GitHub GraphQL API](https://docs.github.com/en/graphql)
- [Okyerema Skill](./.github/skills/okyerema/SKILL.md) — Project orchestration patterns

## Requesting Agent Approval

To add a new agent to the approved list:

### Step 1: Submit a Request

Create a new issue using the **Agent Request** template:

🔗 [Submit Agent Request](https://github.com/anokye-labs/akwaaba/issues/new?template=agent-request.yml)

Include:
- **Agent Name** — What should we call it?
- **Agent Type** — GitHub App, service account, etc.
- **Purpose** — What will it do?
- **Authentication** — How does it authenticate?
- **Justification** — Why is this agent needed?

### Step 2: Review Process

The Anokye Labs team will:
1. Review the request (typically within 1-2 business days)
2. Validate security and compliance
3. Test agent behavior if needed
4. Approve or request changes

### Step 3: Approval

Once approved:
1. Agent is added to `.github/approved-agents.json`
2. Agent can start making commits
3. You'll be notified via the issue

## Authentication Methods

### GitHub Apps (Recommended)

**Pros:**
- Best security model
- Granular permissions
- Clear audit trail
- Appears as `username[bot]`

**Setup:**
1. Create a GitHub App
2. Configure permissions (contents: write, pull_requests: write, issues: read)
3. Install on repository
4. Use app authentication in your agent

**Example:** GitHub Copilot uses this method

### Personal Access Token (PAT)

**Pros:**
- Simple to set up
- Works with any Git client

**Cons:**
- Harder to audit
- Requires human account
- Broader permissions

**Setup:**
1. Create a service account (e.g., `my-bot`)
2. Generate a fine-grained PAT
3. Limit scope to this repository only
4. Store token securely (GitHub Secrets, etc.)

### OAuth Apps

Similar to GitHub Apps but with fewer benefits. Generally not recommended for new agents.

## Troubleshooting

### "Human commits detected" Error

**Problem:** Your PR has commits from a human user instead of an approved agent.

**Solution:**
1. Close the PR
2. Create a GitHub issue describing the work
3. Assign an approved agent to the issue
4. Let the agent create a new PR

### Agent Not Responding

**Problem:** You assigned an agent to an issue, but nothing happened.

**Possible Causes:**
- Agent isn't configured correctly
- Issue doesn't meet agent's trigger conditions
- Agent is rate-limited or offline

**Solution:**
1. Check agent documentation for trigger requirements
2. Verify issue has clear acceptance criteria
3. Wait a few minutes and check again
4. Ask in [GitHub Discussions](https://github.com/anokye-labs/akwaaba/discussions)

### Agent Made Wrong Changes

**Problem:** The agent's PR doesn't match what you wanted.

**Solution:**
1. **Don't close the PR** — Provide feedback instead
2. Add review comments explaining what needs to change
3. Request changes via PR review
4. The agent will respond and update the PR

### Need Help?

- 📚 [Read the docs](https://github.com/anokye-labs/akwaaba)
- 💬 [Ask in Discussions](https://github.com/anokye-labs/akwaaba/discussions)
- 🐛 [Report a bug](https://github.com/anokye-labs/akwaaba/issues/new?template=bug.yml)
- 📧 Contact: Anokye Labs team

## Best Practices

### Writing Good Issues

Agents work best with clear, specific issues:

**✅ Good Issue:**
```markdown
## Description
Add rate limiting to API endpoints to prevent abuse

## Acceptance Criteria
- [ ] Rate limit middleware using express-rate-limit
- [ ] Limit: 100 requests per 15 minutes per IP
- [ ] Return 429 status when limit exceeded
- [ ] Add tests for rate limit behavior
- [ ] Update API documentation

## Context
Currently, the API has no rate limiting. This makes us vulnerable to 
DoS attacks and abuse.
```

**❌ Bad Issue:**
```markdown
Make the API better
```

### Providing Feedback

When reviewing agent PRs:

**✅ Good Feedback:**
```markdown
The authentication logic looks good, but please:
1. Add error handling for expired tokens (line 42)
2. Use bcrypt instead of SHA-256 for password hashing (security best practice)
3. Add a test case for invalid token format
```

**❌ Bad Feedback:**
```markdown
This doesn't work
```

### Emergency Override

In rare cases (production outages, security vulnerabilities), humans may need to commit directly:

1. Add the `emergency-merge` label to your PR
2. Document the reason in the PR description
3. Notify the team immediately
4. Create a follow-up issue to have an agent validate the emergency fix

**Note:** Emergency overrides are logged and reviewed. Use sparingly.

## See Also

- [How We Work](./how-we-work.md) — Philosophy and principles
- [Agent Conventions](./agent-conventions.md) — Behavioral requirements
- [Our Way](./our-way.md) — How we structure work
- [Getting Started](./getting-started.md) — First-time contributor guide
- [Okyerema Skill](./.github/skills/okyerema/SKILL.md) — Project orchestration

---

**Questions?** Open a [GitHub Discussion](https://github.com/anokye-labs/akwaaba/discussions) or create an issue.
