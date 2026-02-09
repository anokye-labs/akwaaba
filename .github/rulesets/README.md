# GitHub Rulesets

This directory contains GitHub repository ruleset configurations that enforce governance policies for the Akwaaba repository.

## Main Branch Protection

**File:** `main-branch-protection.json`

This ruleset enforces strict protection rules on the `main` branch to ensure all changes follow the Anokye-Krom System governance model.

### Rules Enforced

1. **Pull Request Required**
   - All changes must go through a pull request
   - At least 1 approval required before merging
   - Stale reviews are dismissed when new commits are pushed
   - All review threads must be resolved before merging

2. **Required Status Checks**
   - **Commit Validator** - Ensures all commits reference GitHub issues
   - **Agent Authentication** - Validates commits are from approved agents
   - **Strict status checks** - Branches must be up to date before merging

3. **Commit Restrictions**
   - Force pushes are blocked (non_fast_forward rule)
   - Branch deletion is blocked

4. **Bypass Permissions**
   - Only repository admins can bypass these rules in emergencies
   - All bypasses should be documented and reviewed

### Applying This Ruleset

This JSON file serves as documentation and a template for the ruleset configuration. To apply it:

1. Navigate to **Settings → Rules → Rulesets** in the GitHub repository
2. Create a new ruleset
3. Use this JSON as a reference to configure the rules
4. Ensure the status check names match the workflow job names:
   - `Commit Validator` (from `.github/workflows/commit-validator.yml`)
   - `Agent Authentication` (from `.github/workflows/agent-auth.yml`)

### Exporting Rulesets

To export the current ruleset configuration from GitHub:

```bash
gh api repos/anokye-labs/akwaaba/rulesets > main-branch-protection-export.json
```

### Status Check Dependencies

The required status checks reference workflows that must be implemented:

- **Commit Validator** - See `planning/phase-2-governance/02-workflow-commit-validator.md`
- **Agent Authentication** - See `planning/phase-2-governance/03-workflow-agent-auth.md`

These workflows are not yet implemented. The ruleset should be applied after these workflows are created and tested.

### Notes

- GitHub Rulesets are the modern replacement for legacy branch protection rules
- Rulesets provide more flexibility and can target multiple branches with patterns
- The `strict_required_status_checks_policy: true` setting ensures branches must be up to date with the base branch before merging
- Actor ID 5 represents the "Admin" repository role for bypass permissions
