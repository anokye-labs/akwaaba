# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automating repository operations and enforcing governance policies.

## Agent Authentication

**File:** `agent-auth.yml`

### Purpose

Validates that all commits in pull requests are from approved AI agents, enforcing the agent-only commit pattern of the Anokye-Krom System.

### Trigger

- **Event:** `pull_request`
- **Types:** `opened`, `synchronize`, `reopened`, `labeled`, `unlabeled`

### Behavior

When a pull request is opened or updated, the workflow:

1. **Fetches all commits** in the pull request
2. **Extracts author information** (name and email)
3. **Validates against allowlist** in `.github/approved-agents.json`
4. **Detects GitHub Apps** by `[bot]` suffix in username
5. **Checks for emergency bypass** via `emergency-merge` label
6. **Creates audit log** of all validation attempts
7. **Reports results** with clear, actionable feedback

### Exit Codes

- **0** — All commits approved (success)
- **1** — Validation failed (blocks merge)
- **2** — Emergency bypass applied (allowed with warning)
- **3** — Error occurred (blocks merge)

### Approved Agents

Currently approved agents (see `.github/approved-agents.json`):
- **GitHub Copilot** (`copilot[bot]`) — AI-powered code generation
- **GitHub Actions** (`github-actions[bot]`) — Workflow automation

### Emergency Bypass

Administrators can apply the `emergency-merge` label to bypass validation in critical situations. All bypasses are logged for audit purposes.

### Permissions

The workflow requires:
- `contents: read` — To checkout repository and read configuration
- `pull-requests: read` — To fetch PR commits and labels

### Related Documentation

- [Approved Agents Guide](../APPROVED-AGENTS.md) — Complete documentation
- [Agent Conventions](../../how-we-work/agent-conventions.md) — Agent behavior
- [Contributing](../../CONTRIBUTING.md) — Contribution process

### Validation Script

The workflow calls `scripts/Validate-CommitAuthors.ps1` which:
- Uses GitHub CLI to fetch commit data
- Validates each commit author
- Provides detailed error messages
- Supports audit logging

### Testing

Run the test suite to verify the validation logic:

```bash
pwsh scripts/Test-Validate-CommitAuthors.ps1
```

---

## Agent Authentication

**File:** `agent-auth.yml`

### Purpose

Validates that all commits in pull requests are authored by approved agents, enforcing the repository's agent-only commit policy.

### Trigger

- **Event:** `pull_request` (types: opened, synchronize, reopened, labeled, unlabeled)
- **When:** A PR is created, updated, or labels change

### Behavior

When a pull request is created or updated, the workflow:

1. **Fetches all commits** in the pull request
2. **Validates each commit author** against `.github/approved-agents.json`
3. **Checks for emergency bypass** label (`emergency-merge`)
4. **Posts validation results** as a PR comment
5. **Passes or fails** the required check based on validation results

### Approved Agents

The list of approved agents is maintained in `.github/approved-agents.json`:

- `copilot-swe-agent[bot]` - GitHub Copilot Workspace
- `github-actions[bot]` - GitHub Actions automation
- `dependabot[bot]` - Automated dependency updates

### Emergency Bypass

In exceptional circumstances, validation can be bypassed by applying the `emergency-merge` label:

- Requires write permissions on the repository
- All bypasses are logged for audit purposes
- Should only be used for critical emergencies

### Validation Script

The workflow uses `scripts/Validate-CommitAuthors.ps1` which:

- Loads the approved agents allowlist
- Fetches commit data via GitHub GraphQL API
- Validates each commit author
- Provides detailed error messages for unauthorized commits
- Logs all validation attempts for audit

### Permissions

The workflow requires:
- `contents: read` - To checkout the repository
- `pull-requests: write` - To post validation comments

### Error Messages

When unauthorized commits are detected, the workflow provides:

- List of unauthorized commits and authors
- Explanation of the agent-only policy
- Instructions for fixing the issue
- Links to documentation
- Contact information for requesting agent approval

### Related Documentation

- [Agent Setup Guide](../../how-we-work/agent-setup.md)
- [Agent Approval Request Template](../ISSUE_TEMPLATE/agent-approval-request.yml)
- [Approved Agents List](../approved-agents.json)

### Related Scripts

- `scripts/Validate-CommitAuthors.ps1` - Validation logic
- `scripts/Test-Validate-CommitAuthors.ps1` - Test suite

## Auto-assign Unblocked Tasks

**File:** `auto-assign-unblocked.yml`

### Purpose

Automatically assigns newly-unblocked tasks to @copilot when all their blocking dependencies are resolved.

### Trigger

- **Event:** `issues.closed`
- **When:** An issue is closed in the repository

### Behavior

When an issue is closed, the workflow:

1. **Fetches all open issues** in the repository
2. **Parses dependencies** from each issue's body (looking for `## Dependencies` section with `Blocked by:` list)
3. **Identifies affected issues** that have the just-closed issue as a dependency
4. **Checks if fully unblocked** by verifying all dependencies in the checklist are now closed
5. **Assigns to @copilot** if:
   - All dependencies are closed
   - The issue is not already assigned

### Dependencies Format

Issues should include a `## Dependencies` section with a `Blocked by:` checklist:

```markdown
## Dependencies

Blocked by:
- [ ] #14 - First dependency
- [ ] anokye-labs/akwaaba#15 - Cross-repo dependency
- [x] #16 - Already closed dependency
```

The workflow supports both formats:
- Same repository: `#123`
- Cross-repository: `owner/repo#123`

### Permissions

The workflow requires:
- `issues: write` - To assign issues and add comments
- `contents: read` - To checkout the repository

### Example

When issue #14 is closed:
1. Issue #20 has dependencies: `- [ ] #14`, `- [x] #15`
2. Issue #14 is now closed, #15 was already closed
3. All dependencies for #20 are now closed
4. Workflow assigns issue #20 to @copilot
5. Adds comment: "🤖 This issue has been automatically assigned because all blocking dependencies are now closed."

### Limitations

- Processes up to 1000 open issues per run (configurable in the workflow)
- Only assigns unassigned issues
- Requires issues to use the standard Dependencies format
- Cross-repository dependencies must be accessible via `gh issue view`
- Dependencies that cannot be verified (UNKNOWN state) are treated as blocking to avoid premature assignment

### Related Scripts

This workflow complements the existing PowerShell scripts in `/scripts`:
- `Get-ReadyIssues.ps1` - Manually find ready issues in a DAG
- `Set-IssueDependency.ps1` - Set up issue dependencies
- `Get-BlockedIssues.ps1` - Find blocked issues

### Troubleshooting

If the workflow doesn't assign issues as expected:

1. **Check workflow runs** in Actions tab for errors
2. **Verify Dependencies format** matches the expected pattern
3. **Confirm issue state** - dependencies must be in CLOSED state
4. **Check permissions** - ensure the workflow has `issues: write` permission
5. **Review logs** - the workflow outputs detailed information about each step
