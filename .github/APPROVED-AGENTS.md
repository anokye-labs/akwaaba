# Approved Agents

This document describes the approved agents list and agent authentication process for the Anokye-Krom System.

## Overview

The Anokye-Krom System enforces an **agent-only commit pattern** where all code changes must be made by approved AI agents. This ensures consistency, auditability, and maintains the integrity of the issue-driven workflow.

## How It Works

### 1. Agent Authentication Workflow

Every pull request is validated by the **Agent Authentication** workflow (`.github/workflows/agent-auth.yml`):

1. **Fetch Commits** — Retrieves all commits in the PR
2. **Extract Authors** — Identifies commit authors and their emails
3. **Check Allowlist** — Validates authors against the approved agents list
4. **Report Results** — Provides clear feedback on validation status
5. **Block or Allow** — Required status check prevents merge if validation fails

### 2. Approved Agents List

The list of approved agents is maintained in **`.github/approved-agents.json`**. Each agent entry includes:

- **id** — Unique identifier for the agent
- **type** — Agent type (`github-app`, `service-account`, `bot`)
- **username** — Primary username
- **botUsername** — Bot username for GitHub Apps (includes `[bot]` suffix)
- **githubAppId** — GitHub App ID (for GitHub Apps)
- **description** — What the agent does
- **approvedBy** — Who approved the agent
- **approvedDate** — When the agent was approved
- **permissions** — What the agent can do
- **enabled** — Whether the agent is currently active

### 3. Currently Approved Agents

#### GitHub Copilot
- **Type:** GitHub App
- **Username:** `copilot[bot]`
- **Purpose:** AI-powered code generation and automation
- **Permissions:** Read repository, write code, write pull requests, write issues

#### GitHub Actions
- **Type:** GitHub App
- **Username:** `github-actions[bot]`
- **Purpose:** Workflow automation for CI/CD and repository management
- **Permissions:** Read repository, write code, write pull requests, write workflow runs

## Emergency Bypass

In exceptional circumstances, the agent authentication requirement can be bypassed:

### When to Use

Emergency bypass should be used **only** when:
- Critical security vulnerability requires immediate patching
- Production system is down and needs urgent fix
- Agent system is unavailable due to platform issues
- Time-sensitive external dependencies force immediate action

### How to Use

1. **Apply Label** — Administrator applies `emergency-merge` label to the PR
2. **Document Reason** — Add clear explanation in PR description
3. **Validation Passes** — Workflow allows PR to proceed
4. **Audit Trail** — Bypass is logged for review

### Requirements

- Must be applied by repository administrator
- Reason must be documented in PR
- Post-incident review should be conducted
- Consider creating follow-up issue for proper agent-based implementation

## Adding a New Agent

### Process

1. **Create Agent Request Issue**
   - Use the Agent Request issue template
   - Provide all required information
   - Explain purpose and permissions needed

2. **Admin Review**
   - Repository administrators review the request
   - Evaluate security implications
   - Verify legitimate need

3. **Update Configuration**
   - Add agent entry to `.github/approved-agents.json`
   - Include all required fields
   - Set `enabled: true`

4. **Create PR**
   - Submit PR with the updated allowlist
   - Reference the agent request issue
   - Get approval from administrators

5. **Merge and Activate**
   - Merge the PR
   - Agent is immediately active
   - Verify by testing a commit

### Example Agent Entry

```json
{
  "id": "my-custom-agent",
  "type": "github-app",
  "username": "my-agent",
  "botUsername": "my-agent[bot]",
  "githubAppId": "my-agent-app-id",
  "description": "Custom agent for specific automation tasks",
  "approvedBy": "admin-username",
  "approvedDate": "2026-02-10",
  "permissions": [
    "read:repository",
    "write:code"
  ],
  "enabled": true
}
```

## Validation Script

The validation logic is implemented in **`scripts/Validate-CommitAuthors.ps1`**. This PowerShell script:

- Fetches commits from a pull request using GitHub CLI
- Extracts commit author information
- Checks authors against the approved agents list
- Detects GitHub Apps by the `[bot]` suffix
- Supports emergency bypass via PR labels
- Creates detailed audit logs
- Provides clear, actionable error messages

### Usage

```bash
# Validate a pull request
pwsh scripts/Validate-CommitAuthors.ps1 \
  -Owner "anokye-labs" \
  -Repo "akwaaba" \
  -PullRequestNumber 42

# With audit logging
pwsh scripts/Validate-CommitAuthors.ps1 \
  -Owner "anokye-labs" \
  -Repo "akwaaba" \
  -PullRequestNumber 42 \
  -AuditLog "validation-audit.log"
```

### Exit Codes

- **0** — All commits approved (success)
- **1** — Validation failed (unapproved commits)
- **2** — Emergency bypass applied (allowed with warning)
- **3** — Error occurred (script failure)

## Troubleshooting

### "Unapproved commit detected"

**Cause:** Commit was made by a user/account not in the approved agents list.

**Solution:**
1. Create an issue describing the needed changes
2. Assign the issue to an approved agent
3. Let the agent create a new PR

### "GitHub CLI not available"

**Cause:** The `gh` command is not installed or not in PATH.

**Solution:**
- Ensure GitHub CLI is installed
- Verify it's accessible in the workflow environment
- Check authentication is configured

### "Failed to fetch commits"

**Cause:** API error or network issue when fetching PR data.

**Solution:**
- Verify GitHub token has correct permissions
- Check if PR number is valid
- Retry the workflow

### Agent Not Being Recognized

**Cause:** Agent might not be properly configured in the allowlist.

**Solution:**
1. Check `.github/approved-agents.json` for the agent entry
2. Verify `botUsername` matches exactly (including `[bot]` suffix)
3. Ensure `enabled` is set to `true`
4. Check commit author name matches agent username

## Audit and Compliance

### Audit Trail

All validation attempts are logged, including:
- Timestamp of validation
- PR number and repository
- Commit SHAs and authors
- Validation results (approved/rejected)
- Emergency bypass usage

### Compliance Benefits

The agent authentication system provides:
- **Traceability** — Every commit linked to an agent and issue
- **Accountability** — Clear record of who approved each agent
- **Auditability** — Complete log of all validation attempts
- **Consistency** — Uniform enforcement across all branches
- **Security** — Prevents unauthorized code changes

## Related Documentation

- [How We Work](../how-we-work.md) — Overview of the Anokye-Krom System
- [Agent Conventions](../how-we-work/agent-conventions.md) — Agent behavior guidelines
- [Contributing](../CONTRIBUTING.md) — Contribution process
- [Issue Templates](./ISSUE_TEMPLATE/) — Creating issues for agents

## Questions?

For questions or issues related to agent authentication:
1. Check this documentation first
2. Review existing agent request issues
3. Create a new issue with the `question` label
4. Tag repository administrators if urgent

---

**The Anokye-Krom System:** Humans create the vision, agents execute the work, everyone benefits from structured, auditable development.
