# Main Branch Protection Ruleset

## Overview

This directory contains the main branch protection ruleset for the Akwaaba repository, which enforces the Anokye-Krom System governance model.

## File: main-branch-protection.json

**Status:** Currently set to `"disabled"` enforcement mode  
**Target:** `refs/heads/main` branch

### Why Disabled?

The ruleset references a required status check (`commit-validator`) that has not yet been implemented. The enforcement mode will be changed to `"active"` once the workflow is ready.

### Rules Defined

1. **Pull Request Requirements** (`pull_request`)
   - Requires at least 1 approval before merging
   - Dismisses stale reviews when new commits are pushed
   - Requires all review conversations to be resolved
   - Code owner review: Not currently required (will be enabled when CODEOWNERS exists)

2. **Required Status Checks** (`required_status_checks`)
   - **commit-validator**: Validates that all commits reference open GitHub issues
     - `integration_id` is `null` for repository-based GitHub Actions workflows
     - Set to GitHub App ID if using a GitHub App for status checks
   - Strict mode enabled: Branches must be up to date before merging

3. **Commit Restrictions**
   - **non_fast_forward**: Blocks force pushes to main
   - **deletion**: Blocks branch deletion
   - **required_linear_history**: Requires linear history (no merge commits)

### Bypass Actors

Currently, no bypass actors are configured. Organization administrators have implicit bypass permissions.

## Applying the Ruleset

### Via GitHub UI

1. Navigate to Repository Settings → Rules → Rulesets
2. Click "New ruleset" → "New branch ruleset"
3. Upload or paste the contents of `main-branch-protection.json`
4. Verify all settings
5. **Keep enforcement as "disabled"** until the commit-validator workflow exists
6. Click "Create"

### Via GitHub API

```bash
gh api repos/anokye-labs/akwaaba/rulesets \
  --method POST \
  --input .github/rulesets/main-branch-protection.json
```

### After Implementation

Once the `commit-validator` workflow is implemented:

1. Update the ruleset's `enforcement` field from `"disabled"` to `"active"`
2. Re-apply the ruleset via UI or API
3. Test that the protection works as expected

## Dependencies

- **Required Workflow:** `.github/workflows/commit-validator.yml` (not yet implemented)
- **Planning Document:** `planning/phase-2-governance/02-workflow-commit-validator.md`

## Next Steps

1. Create an issue to track implementation of the `commit-validator` workflow (see `/tmp/required-workflows-issue.md`)
2. Implement the workflow as described in `planning/phase-2-governance/02-workflow-commit-validator.md`
3. Test the workflow
4. Update this ruleset to set `enforcement: "active"`
5. Apply the updated ruleset

## Related Documentation

- **Planning Feature:** `planning/phase-2-governance/01-ruleset-protect-main.md`
- **Governance Documentation:** `GOVERNANCE.md` (to be created in Phase 5)
- **ADR on GitHub Apps:** `docs/adr/ADR-0004-use-github-apps-for-agent-authentication.md`

## Maintenance

When updating this ruleset:
1. Validate JSON syntax: `cat main-branch-protection.json | python3 -m json.tool`
2. Review changes against GitHub's [ruleset documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
3. Test in a separate repository or branch if possible
4. Update this README to reflect any changes
