# GitHub Rulesets

This directory contains JSON configurations for GitHub repository rulesets that enforce branch protection and other governance policies.

## Overview

GitHub Rulesets provide a flexible way to enforce policies on branches, tags, and other repository resources. They are more powerful than legacy branch protection rules and allow for:

- Fine-grained control over branch protection
- Status check requirements
- Bypass permissions for specific users or teams
- Export/import via API for version control

## Files in this Directory

### `main-branch-protection.json`

Defines the branch protection rules for the `main` branch, including:

- **Pull Request Requirements**: Requires at least 1 approval before merging
- **Status Checks**: Requires "Commit Validator" and "Agent Authentication" workflows to pass
- **Commit Restrictions**: Blocks force pushes and branch deletion
- **Bypass Permissions**: Organization administrators can bypass rules in emergencies

## Creating a Ruleset via GitHub UI

To apply the ruleset defined in `main-branch-protection.json`:

### Step 1: Navigate to Rulesets Settings

1. Go to your repository on GitHub
2. Click **Settings** (top navigation)
3. In the left sidebar, under "Code and automation", click **Rules**
4. Click **Rulesets**

### Step 2: Create New Ruleset

1. Click the **New ruleset** button
2. Select **New branch ruleset**

### Step 3: Configure Basic Settings

1. **Name**: Enter `Main Branch Protection`
2. **Enforcement status**: Select **Active** (to enforce immediately) or **Disabled** (to create without enforcing)

### Step 4: Set Target Branches

1. In the **Target branches** section, click **Add target**
2. Select **Include by pattern**
3. Enter `main` as the branch pattern
4. This will apply the ruleset only to the main branch

### Step 5: Configure Branch Protection Rules

Enable the following rules by checking their boxes:

#### Restrict deletions
- ✅ **Prevent deletion of matching branches**

#### Require a pull request before merging
- ✅ Enable this rule
- **Required approvals**: Set to `1`
- ✅ **Dismiss stale pull request approvals when new commits are pushed**
- ✅ **Require approval of the most recent reviewable push**
- ✅ **Require conversation resolution before merging**

#### Require status checks to pass
- ✅ Enable this rule
- ✅ **Require branches to be up to date before merging**
- **Add status checks**:
  - Add `Commit Validator`
  - Add `Agent Authentication`
  
  Note: Status checks must exist in GitHub Actions workflows before they can be added here.

#### Block force pushes
- ✅ **Prevent users from force pushing to matching branches**

### Step 6: Configure Bypass Permissions

1. Scroll to the **Bypass list** section
2. Click **Add bypass**
3. Select **Organization admin**
4. Set bypass mode to **Always allow**

This allows organization administrators to bypass the rules in emergency situations. See [GOVERNANCE.md](../../GOVERNANCE.md) for bypass procedures.

### Step 7: Save the Ruleset

1. Review all settings to ensure they match the configuration
2. Click **Create** to save the ruleset
3. The ruleset will be immediately active (if enforcement is set to Active)

## Exporting a Ruleset

After creating a ruleset via the UI, you can export it to JSON for version control:

```bash
pwsh -File scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId <ruleset-id>
```

The ruleset ID can be found in the URL when viewing the ruleset in GitHub Settings.

## Importing/Updating a Ruleset

Currently, GitHub does not support importing rulesets via the UI. Rulesets must be created or updated via:

1. **GitHub UI** (manual configuration)
2. **GitHub API** (programmatic creation/updates)
3. **GitHub CLI** (if/when support is added)

## Optional Rules

The following rules are defined in the JSON file but marked as optional. Enable these if your organization requires them:

### Required Signatures
- Requires all commits to be signed with GPG, SSH, or S/MIME
- Enable this if your security policy requires commit signing

### Required Deployments
- Requires deployments to specific environments to succeed before merging
- Enable this if you have deployment gates (e.g., staging must deploy successfully)

## Testing the Ruleset

After creating the ruleset, verify it works correctly:

1. **Test direct push**: Try to push directly to main (should be blocked)
   ```bash
   git checkout main
   git commit --allow-empty -m "test"
   git push origin main  # Should fail
   ```

2. **Test PR without approval**: Create a PR and try to merge without approval (should be blocked)

3. **Test PR without status checks**: Create a PR before required workflows run (should be blocked from merging)

4. **Test force push**: Try to force push to main (should be blocked)
   ```bash
   git push --force origin main  # Should fail
   ```

5. **Test branch deletion**: Try to delete the main branch (should be blocked)
   ```bash
   git push origin --delete main  # Should fail
   ```

## Troubleshooting

### Status checks not appearing in the dropdown

If required status checks (Commit Validator, Agent Authentication) don't appear when configuring the ruleset:

1. Ensure the GitHub Actions workflows exist in `.github/workflows/`
2. Ensure the workflows have run at least once on a PR
3. The `name:` field in the workflow file determines the status check name
4. Wait a few minutes and refresh the ruleset configuration page

### Ruleset not enforcing

1. Check that **Enforcement status** is set to **Active**
2. Verify the branch pattern matches your target branch (`main`)
3. Check the ruleset is not in **Evaluate** mode (dry-run)

### Bypass not working

1. Verify bypass actors are correctly configured
2. Check that the user attempting to bypass has the correct role (e.g., Organization Admin)
3. Review bypass mode is set to "Always allow" or "Pull request only" as appropriate

## Additional Resources

- [GitHub Docs: Managing rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GitHub Docs: Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [GOVERNANCE.md](../../GOVERNANCE.md): Repository governance policies and bypass procedures
