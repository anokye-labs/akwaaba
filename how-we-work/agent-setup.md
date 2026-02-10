# Agent Setup Guide

This guide explains how to register and configure AI agents to work in Anokye Labs repositories.

## Overview

Anokye Labs follows an **agent-only commit pattern** where all code changes are made by approved AI agents in response to human-created issues. This ensures:

- All work is tracked through GitHub issues
- Changes are documented and auditable
- The "why" behind every commit is clear
- Consistency in how work gets done

## Who Needs This Guide?

You need this guide if you want to:
- Register a new AI agent to work in Anokye Labs repositories
- Understand how agent authentication works
- Troubleshoot agent authentication issues
- Set up an agent for the first time

## Agent Authentication Requirements

### Approved Agents List

All agents must be registered in the **approved agents list** before they can commit to the repository. This list is stored in `.github/approved-agents.json` and contains:

- Agent username (e.g., `copilot-swe-agent[bot]`)
- GitHub App ID (if applicable)
- Description of the agent's purpose
- Date added

### Authentication Methods

Agents can authenticate using one of these methods:

1. **GitHub Apps** (Recommended)
   - Better audit trail
   - Fine-grained permissions
   - Official GitHub integration
   - Example: GitHub Copilot, custom GitHub Apps

2. **Bot Users**
   - Standard user accounts marked as bots
   - Username typically ends in `[bot]`
   - Managed through GitHub Apps or service accounts

3. **Service Accounts**
   - Regular GitHub accounts used for automation
   - Less preferred due to weaker audit trail
   - May be phased out in favor of GitHub Apps

## How to Register a New Agent

### Step 1: Prepare Agent Information

Gather the following information about your agent:

- **Agent Name**: The GitHub username or app name
- **Authentication Type**: GitHub App, Bot User, or Service Account
- **GitHub App ID**: Required if using a GitHub App
- **Purpose**: What will this agent do?
- **Maintainer**: Who is responsible for this agent?

### Step 2: Create a Registration Request

Create a GitHub issue in the repository using the following template:

```markdown
Title: Register Agent: [Agent Name]

## Agent Information

- **Agent Name**: copilot-swe-agent[bot]
- **Authentication Type**: GitHub App
- **GitHub App ID**: 1143301
- **Purpose**: Automated code changes in response to issues
- **Maintainer**: @your-username

## Justification

[Explain why this agent is needed and what it will do]

## Security Considerations

[Address any security concerns, permissions needed, etc.]
```

### Step 3: Wait for Approval

A repository maintainer will:
1. Review your registration request
2. Verify the agent's credentials
3. Add the agent to `.github/approved-agents.json`
4. Close the issue once approved

### Step 4: Test the Agent

Once approved, test the agent by:
1. Creating a test issue
2. Having the agent create a pull request
3. Verifying the agent authentication workflow passes
4. Confirming the PR can be merged

## Agent Behavior Requirements

Agents working in Anokye Labs repositories must follow the **Agent Behavior Conventions** documented in [agent-conventions.md](./agent-conventions.md).

Key requirements:

1. **Action-First Principle** — Execute immediately with best judgment, explain only if asked
2. **Read-Before-Debug** — Consult documentation before running diagnostics
3. **Branch Awareness** — Verify current branch before any git operations
4. **Skill Loading** — Read skills as documentation, don't try to invoke them as tools
5. **Minimal Communication** — Use fewest words necessary, no narration

### Session Context

Every agent session should operate in the context of a specific GitHub issue:

1. Identify the issue you're working on
2. Check its dependencies (are blocking issues resolved?)
3. Understand where it sits in the hierarchy
4. Do the work
5. Update and close the issue when done

### Using the Okyerema Skill

Agents must use the **Okyerema skill** for all project management operations. See [agents.md](../agents.md) and [.github/skills/okyerema/SKILL.md](../.github/skills/okyerema/SKILL.md) for details.

## Agent Authentication Workflow

When you create a pull request, the **Agent Authentication** workflow validates that all commits are from approved agents.

### How It Works

1. The workflow triggers on PR open/synchronize events
2. It fetches all commits in the PR
3. For each commit, it checks the author against `.github/approved-agents.json`
4. If all commits are from approved agents → ✅ Workflow passes
5. If any commits are from non-approved sources → ❌ Workflow fails

### Workflow File

The workflow is defined in `.github/workflows/agent-auth.yml` (if implemented).

### Validation Script

The validation logic is in `scripts/Validate-CommitAuthors.ps1` (if implemented).

## Troubleshooting

### "Authentication failed: commit author not approved"

**Problem**: Your agent's commits are being rejected by the authentication workflow.

**Solutions**:
1. Verify the agent is in `.github/approved-agents.json`
2. Check the username matches exactly (case-sensitive)
3. For GitHub Apps, verify the App ID is correct
4. Ensure the agent is committing as itself, not as a human user

### "No approved agents found in repository"

**Problem**: The `.github/approved-agents.json` file is missing or empty.

**Solutions**:
1. Create a registration request issue (see above)
2. Contact a repository maintainer
3. Check if you're on the correct branch

### Agent commits succeed but workflow still fails

**Problem**: The authentication workflow has a bug or configuration issue.

**Solutions**:
1. Check the workflow run logs in GitHub Actions
2. Verify the workflow file exists and is properly configured
3. Look for error messages in the validation script output
4. Contact the repository maintainer

### Emergency: Need to bypass agent authentication

**Problem**: You need to merge a PR urgently but agent authentication is blocking it.

**Solutions**:
1. Add the `emergency-merge` label to the PR (requires specific permissions)
2. The authentication workflow will log the bypass but allow the merge
3. All bypasses are audited and should be rare
4. After the emergency, create an issue to fix the underlying problem

### Agent is approved but still can't push to protected branches

**Problem**: Branch protection rules are preventing the agent from pushing.

**Solutions**:
1. Verify the agent is included in the branch protection ruleset
2. Check that the agent has the necessary repository permissions
3. For GitHub Apps, verify the app installation has the right access level
4. Contact a repository admin to review branch protection settings

### Rate limiting issues

**Problem**: Agent is hitting GitHub API rate limits.

**Solutions**:
1. Use GraphQL instead of REST API where possible (higher limits)
2. Implement caching for repeated queries
3. Use batch operations to reduce API calls
4. For GitHub Apps, ensure you're using app authentication (higher limits than user tokens)

## Approved Agents File Format

The `.github/approved-agents.json` file follows this structure:

```json
{
  "agents": [
    {
      "username": "copilot-swe-agent[bot]",
      "type": "github-app",
      "appId": 1143301,
      "description": "GitHub Copilot automated code changes",
      "addedDate": "2026-01-15",
      "addedBy": "hoopsomuah"
    },
    {
      "username": "dependabot[bot]",
      "type": "github-app",
      "appId": 29110,
      "description": "Automated dependency updates",
      "addedDate": "2026-01-15",
      "addedBy": "hoopsomuah"
    }
  ],
  "emergencyBypass": {
    "label": "emergency-merge",
    "requiredRole": "admin",
    "auditLog": "logs/agent-auth/bypasses.log"
  }
}
```

## Audit Logging

All agent authentication attempts are logged for audit purposes:

- **Location**: `logs/agent-auth/` directory
- **Format**: Structured JSON, one entry per line
- **Contents**: Timestamp, commit SHA, author, PR number, validation result
- **Retention**: Logs are kept indefinitely for compliance

### Example Log Entry

```json
{
  "timestamp": "2026-02-10T02:52:16Z",
  "sha": "abc123def456",
  "author": "copilot-swe-agent[bot]",
  "prNumber": 123,
  "result": "approved",
  "correlationId": "pr-123-run-456"
}
```

## Security Considerations

### Principle of Least Privilege

Agents should have the **minimum permissions** necessary to do their job:

- Read access to repository contents
- Write access to create branches and PRs
- No admin access unless absolutely required
- Scoped permissions via GitHub App installations

### Secrets Management

Agents should **never**:
- Commit secrets, API keys, or credentials to the repository
- Log sensitive information
- Share credentials between different agents
- Use personal access tokens (use GitHub App tokens instead)

### Monitoring and Alerting

Repository maintainers should:
- Review agent authentication logs regularly
- Monitor for unusual patterns (failed auth attempts, emergency bypasses)
- Set up alerts for authentication failures
- Audit the approved agents list quarterly

## Advanced Topics

### Self-Service Agent Registration (Future)

The current process requires manual approval. Future enhancements may include:
- Automated registration for well-known GitHub Apps
- Self-service registration with approval workflow
- Integration with organization-level agent management
- Centralized agent directory across all Anokye Labs repos

### Agent Permissions Model

Different agent types may require different permissions:

| Agent Type | Typical Permissions |
|------------|---------------------|
| **Code Generator** | Read repo, write branches, write PRs |
| **Dependency Updater** | Read repo, write branches, write PRs, read packages |
| **Documentation Bot** | Read repo, write branches, write PRs, read wiki |
| **Security Scanner** | Read repo, write issues, write PR comments |

### Multi-Repository Agents

If your agent works across multiple Anokye Labs repositories:
1. Register the agent in each repository separately
2. Use consistent naming and configuration
3. Document which repos the agent has access to
4. Coordinate permissions across repositories

## Getting Help

If you're stuck or have questions:

1. **Check the documentation**:
   - [Agent Behavior Conventions](./agent-conventions.md)
   - [Agents Overview](../agents.md)
   - [Contributing Guide](../CONTRIBUTING.md)

2. **Search existing issues**:
   - Look for similar agent registration requests
   - Check closed issues for solutions

3. **Create an issue**:
   - Use a clear, descriptive title
   - Include relevant error messages
   - Tag with `documentation` or `agent-setup` label

4. **Contact a maintainer**:
   - For urgent issues or security concerns
   - When you need approval for a new agent
   - If you suspect a bug in the authentication workflow

## Related Documentation

- **[Agent Behavior Conventions](./agent-conventions.md)** — How agents should behave
- **[Agents Overview](../agents.md)** — Understanding the agent system
- **[Okyerema Skill](../.github/skills/okyerema/SKILL.md)** — Project management for agents
- **[Contributing Guide](../CONTRIBUTING.md)** — The issue-first workflow
- **[How We Work](../how-we-work.md)** — Overall coordination system

---

*[← Back to How We Work](../how-we-work.md)*
