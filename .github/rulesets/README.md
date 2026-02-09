# GitHub Rulesets

This directory contains GitHub repository rulesets that define branch protection and other governance rules.

## Overview

GitHub Rulesets provide a modern, flexible way to enforce repository governance. They replace legacy branch protection with more powerful features:

- **Organization-wide enforcement**: Apply rules across all repositories
- **Layering**: Multiple rulesets can apply to the same branch
- **Granular bypass permissions**: Control who can bypass specific rules
- **Evaluate mode**: Test rules without enforcement
- **Better targeting**: Use patterns to target multiple branches

## Files in This Directory

### `main-branch-protection.json`

Comprehensive protection ruleset for the `main` branch. Enforces:

1. **Pull Request Requirements**
   - All changes must go through pull requests (no direct pushes)
   - Minimum 1 approving review required
   - Approval must come from someone other than the author
   - Stale reviews dismissed when new commits are pushed
   - All conversations must be resolved before merging

2. **Required Status Checks**
   - **Commit Validator**: Validates commit messages and metadata
   - **Agent Authentication**: Verifies automated agent authorization
   - Branches must be up-to-date before merging (strict checks)

3. **Commit Protection**
   - Branch deletion blocked
   - Force pushes blocked (maintains commit history integrity)

4. **Bypass Access**
   - Repository administrators can bypass in emergencies

## Exporting Rulesets from GitHub

Use the provided PowerShell script to export rulesets from GitHub API:

```powershell
# Export all rulesets from the repository
pwsh -File scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba"

# Export a specific ruleset by ID
pwsh -File scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId 12345

# Export to a custom directory
pwsh -File scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputPath "./my-rulesets"
```

### Prerequisites

- GitHub CLI (`gh`) installed and authenticated, OR
- `GITHUB_TOKEN` environment variable set with a valid Personal Access Token
- Token needs `repo` scope for private repositories or `public_repo` for public ones

### Manual Export via GitHub CLI

You can also export rulesets manually using GitHub CLI:

```bash
# List all rulesets
gh api repos/anokye-labs/akwaaba/rulesets

# Get a specific ruleset by ID
gh api repos/anokye-labs/akwaaba/rulesets/RULESET_ID

# Export to a file
gh api repos/anokye-labs/akwaaba/rulesets/RULESET_ID > main-branch-protection.json
```

### Manual Export via curl

```bash
# List all rulesets
curl -H "Authorization: token YOUR_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/anokye-labs/akwaaba/rulesets

# Get specific ruleset
curl -H "Authorization: token YOUR_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/anokye-labs/akwaaba/rulesets/RULESET_ID
```

## Applying Rulesets

Rulesets must be configured via the GitHub web interface or API. This repository stores the configuration for reference and documentation.

### Via GitHub Web Interface

1. Navigate to **Settings** → **Rules** → **Rulesets**
2. Click **New ruleset** → **New branch ruleset**
3. Configure the ruleset based on the JSON file in this directory
4. Set enforcement to **Active** (or **Evaluate** for testing)

### Via GitHub API

```bash
# Create a new ruleset
gh api repos/anokye-labs/akwaaba/rulesets \
  --method POST \
  --input main-branch-protection.json

# Update an existing ruleset
gh api repos/anokye-labs/akwaaba/rulesets/RULESET_ID \
  --method PUT \
  --input main-branch-protection.json
```

## Understanding the Ruleset Configuration

### Enforcement Levels

- **active**: Rules are enforced and block non-compliant actions
- **evaluate**: Rules are checked but only logged (test mode)
- **disabled**: Rules are not evaluated

### Rule Types

#### `pull_request`
Requires all changes to go through pull requests with specified review requirements.

**Parameters:**
- `required_approving_review_count`: Minimum approvals needed (1)
- `dismiss_stale_reviews_on_push`: Auto-dismiss approvals on new commits (true)
- `require_code_owner_review`: Require CODEOWNERS approval (false)
- `require_last_push_approval`: Block author self-approval (true)
- `required_review_thread_resolution`: All conversations resolved (true)

#### `required_status_checks`
Specifies automated checks that must pass before merging.

**Parameters:**
- `required_status_checks`: Array of check contexts (Commit Validator, Agent Authentication)
- `strict_required_status_checks_policy`: Require branch to be up-to-date (true)

#### `deletion`
Prevents branch deletion. No parameters.

#### `non_fast_forward`
Prevents force pushes and history rewrites. No parameters.

### Optional Rule Types

These can be added to the ruleset if needed:

#### `required_signatures`
Requires all commits to be signed with GPG or SSH keys.

```json
{
  "type": "required_signatures"
}
```

#### `required_linear_history`
Prevents merge commits, enforcing linear history via rebase or squash.

```json
{
  "type": "required_linear_history"
}
```

#### `required_deployments`
Requires successful deployment to specified environments.

```json
{
  "type": "required_deployments",
  "parameters": {
    "required_deployment_environments": ["production"]
  }
}
```

## Bypass Procedures

Repository administrators can bypass rules in emergencies. The bypass is logged in the audit log.

**When to bypass:**
- Critical security patch needed immediately
- System outage requiring emergency fix
- Automated system failure blocking legitimate work

**How to bypass:**
As a repository administrator, you can push directly or merge without meeting requirements. The action will be logged.

**After bypassing:**
1. Document the reason in the commit message or PR
2. Create a follow-up issue to address properly
3. Review audit logs to ensure bypass was appropriate

## Best Practices

1. **Start with Evaluate mode**: Test new rulesets in evaluate mode before enforcing
2. **Gradual rollout**: Apply strict rules progressively to minimize disruption
3. **Document exceptions**: Maintain clear policies on when bypass is appropriate
4. **Regular reviews**: Periodically review and update rulesets as needs change
5. **Monitor bypasses**: Review audit logs for bypass usage patterns

## Testing Rulesets

Before activating a ruleset:

1. Set enforcement to **evaluate**
2. Monitor for a period (e.g., 1-2 weeks)
3. Review violations that would have been blocked
4. Adjust rules based on findings
5. Switch to **active** enforcement

## API Reference

- [Repository Rulesets API](https://docs.github.com/en/rest/repos/rules)
- [Ruleset Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Managing Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/managing-rulesets-for-a-repository)

## Related Documentation

- [GOVERNANCE.md](../../GOVERNANCE.md) - Repository governance policies (if exists)
- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution guidelines
- [Planning Document](../../planning/phase-2-governance/01-ruleset-protect-main.md) - Ruleset planning

## Questions or Issues?

If you have questions about these rulesets or need to request a bypass for a specific situation, please:

1. Open an issue with the `governance` label
2. Contact the repository maintainers
3. Refer to the GOVERNANCE.md document (if exists)
