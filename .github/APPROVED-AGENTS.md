# Approved Agents Allowlist

This document describes the approved agents allowlist system used in this repository to control which AI agents and bots can commit changes.

## Purpose

The approved agents allowlist (`approved-agents.json`) maintains a registry of authorized AI agents and bots that are permitted to:
- Create commits
- Open pull requests
- Make automated changes to the repository

This allowlist is used by the Agent Authentication workflow to validate that all commits come from approved sources, enforcing the agent-only commit pattern.

## File Location

**File:** `.github/approved-agents.json`

## Structure

The allowlist is a JSON file with the following structure:

```json
{
  "version": "1.0.0",
  "description": "Allowlist of approved AI agents",
  "lastUpdated": "YYYY-MM-DD",
  "agents": [
    {
      "username": "agent-name",
      "githubAppId": "app-id",
      "type": "github-app",
      "description": "What this agent does",
      "permissions": ["read", "write"],
      "approvedBy": "admin-username",
      "dateAdded": "YYYY-MM-DD",
      "status": "active"
    }
  ],
  "registrationProcess": { ... },
  "agentTypes": { ... },
  "permissionLevels": { ... },
  "statusValues": { ... }
}
```

## Required Fields for Each Agent

| Field | Type | Description |
|-------|------|-------------|
| `username` | string | The GitHub username of the agent (e.g., "copilot", "github-actions[bot]") |
| `githubAppId` | string | The GitHub App ID or identifier |
| `type` | enum | Agent type: "github-app", "bot-user", or "service-account" |
| `description` | string | Clear description of the agent's purpose and responsibilities |
| `permissions` | array | Permission levels: "read", "write", "admin" |
| `approvedBy` | string | Username of the person who approved this agent |
| `dateAdded` | string | Date the agent was added (YYYY-MM-DD format) |
| `status` | enum | Current status: "active", "suspended", or "revoked" |

## Agent Types

- **github-app**: Official GitHub application with an App ID (preferred)
- **bot-user**: Bot user account (legacy, prefer GitHub Apps when possible)
- **service-account**: Service account for automated operations

## Permission Levels

- **read**: Can read repository contents
- **write**: Can commit and create PRs
- **admin**: Administrative permissions (use with extreme caution)

## Status Values

- **active**: Agent is currently approved and operational
- **suspended**: Agent access is temporarily suspended
- **revoked**: Agent access has been permanently revoked

## Adding a New Agent

Follow this process to add a new agent to the allowlist:

### Step 1: Create a Request

Create a GitHub issue with the following information:
- **Title**: "Agent Registration Request: [Agent Name]"
- **Agent Username**: The exact GitHub username
- **GitHub App ID**: If applicable
- **Agent Type**: github-app, bot-user, or service-account
- **Purpose**: Detailed explanation of what the agent will do
- **Permissions Needed**: read, write, or admin
- **Justification**: Why this agent is needed

### Step 2: Review and Approval

- Repository administrators will review the request
- Security implications will be assessed
- The request may be approved, rejected, or require modifications

### Step 3: Add to Allowlist

Once approved:

1. Create a new branch from `main`
2. Edit `.github/approved-agents.json`
3. Add a new entry to the `agents` array with all required fields
4. Update the `lastUpdated` field with the current date
5. Validate the JSON format (use a JSON validator or linter)
6. Create a pull request with the changes

### Step 4: Validation

The PR must:
- Pass all CI checks
- Have valid JSON format
- Include all required fields for the new agent
- Be reviewed and approved by a repository administrator

### Step 5: Merge and Activation

- Once the PR is merged, the agent becomes active
- The Agent Authentication workflow will recognize the new agent
- Changes take effect immediately

## Modifying an Existing Agent

To modify an agent's permissions or status:

1. Create a GitHub issue explaining the change
2. Follow the same PR process as adding a new agent
3. Update the relevant fields in the agent's entry
4. Update the `lastUpdated` field

## Revoking an Agent

To revoke an agent's access:

1. Change the agent's `status` to "revoked"
2. Document the reason in the PR description
3. Update the `lastUpdated` field
4. The agent will be blocked from making new commits

## Suspending an Agent

To temporarily suspend an agent:

1. Change the agent's `status` to "suspended"
2. Document the reason and expected duration
3. Update the `lastUpdated` field
4. The agent can be reactivated by changing status back to "active"

## Validation Rules

The Agent Authentication workflow validates:
- Agent username matches an entry in the allowlist
- Agent status is "active"
- Commit author information matches the agent entry
- For GitHub Apps, the App ID matches the allowlist

## Security Considerations

- **Principle of Least Privilege**: Grant only the minimum necessary permissions
- **Regular Audits**: Review the allowlist quarterly
- **Monitoring**: Monitor agent activity for unusual patterns
- **Revocation**: Immediately revoke access if suspicious activity is detected
- **Documentation**: Keep agent purposes well-documented

## Emergency Procedures

If an agent is compromised or behaving unexpectedly:

1. Immediately change its status to "suspended" or "revoked"
2. Notify repository administrators
3. Investigate the agent's recent activity
4. Document the incident
5. Apply the emergency-merge label if urgent fixes are needed

## Troubleshooting

### Agent Commits Being Rejected

**Problem**: Commits from an approved agent are being rejected.

**Solutions**:
1. Verify the agent username exactly matches the allowlist entry
2. Check that the agent status is "active"
3. Ensure the Agent Authentication workflow is running correctly
4. Review the workflow logs for specific error messages

### Adding Agent Fails Validation

**Problem**: PR to add new agent fails CI checks.

**Solutions**:
1. Validate JSON format using a JSON validator
2. Ensure all required fields are present
3. Check for typos in field names
4. Verify the date format is YYYY-MM-DD

## Contact

For questions about the approved agents allowlist:
- Review the `CONTRIBUTING.md` file
- Create an issue with the "question" label
- Contact repository administrators

## References

- [Agent Authentication Workflow](.github/workflows/agent-auth.yml) (when implemented)
- [agents.md](../agents.md) - Overview of how agents work in this repository
- [GOVERNANCE.md](../GOVERNANCE.md) - Repository governance policies
- Planning: [phase-2-governance/03-workflow-agent-auth.md](../planning/phase-2-governance/03-workflow-agent-auth.md)
