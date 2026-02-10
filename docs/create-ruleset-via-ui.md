# Creating Main Branch Protection Ruleset via GitHub UI

This guide provides step-by-step instructions for creating the Main Branch Protection ruleset through the GitHub web interface.

## Prerequisites

- Administrative access to the `anokye-labs/akwaaba` repository
- Understanding of branch protection concepts
- GitHub Actions workflows (`Commit Validator` and `Agent Authentication`) must exist and have run at least once

## Step-by-Step Instructions

### 1. Navigate to Repository Settings

1. Go to [https://github.com/anokye-labs/akwaaba](https://github.com/anokye-labs/akwaaba)
2. Click the **Settings** tab in the top navigation bar
3. In the left sidebar, scroll down to the **Code and automation** section
4. Click on **Rules**
5. Click on **Rulesets**

### 2. Create New Ruleset

1. On the Rulesets page, click the green **New ruleset** dropdown button
2. Select **New branch ruleset** from the dropdown menu

### 3. Configure Ruleset Name and Enforcement

In the **Ruleset Name** field:
- Enter: `Main Branch Protection`

Under **Enforcement status**:
- Select: **Active** (to enforce rules immediately)
- Alternative: Select **Disabled** if you want to create but not enforce yet
- Don't select **Evaluate** unless you're testing (dry-run mode)

### 4. Configure Target Branches

In the **Target branches** section:

1. Click the **Add target** button
2. Select **Include by pattern** from the dropdown
3. In the pattern field, enter: `main`
4. The ruleset will now apply only to the `main` branch

Alternatively, you can:
- Select **Include default branch** to target whatever branch is set as default
- Use wildcard patterns like `release/*` for multiple branches

### 5. Enable Restrict Deletions

In the **Rules** section, locate **Restrict deletions**:

- ✅ Check the box next to **Restrict deletions**
- This prevents the main branch from being deleted

### 6. Configure Pull Request Requirements

Locate **Require a pull request before merging**:

1. ✅ Check the box to enable this rule
2. Under **Required approvals**:
   - Set the number to: `1`
   - This requires at least 1 approval before merging
3. ✅ Check **Dismiss stale pull request approvals when new commits are pushed**
   - This ensures reviews are valid for the latest code
4. ✅ Check **Require approval of the most recent reviewable push**
   - This prevents self-approvals from working around the review requirement
5. ✅ Check **Require conversation resolution before merging**
   - All review comments must be resolved before merging

Leave unchecked (unless you add CODEOWNERS file later):
- ❌ Require review from Code Owners (enable later if CODEOWNERS file is added)

### 7. Configure Status Check Requirements

Locate **Require status checks to pass before merging**:

1. ✅ Check the box to enable this rule
2. ✅ Check **Require branches to be up to date before merging**
   - This ensures PRs include the latest changes from main before merging

3. In the **Add checks** section:
   - Click **Add checks**
   - Search for and add: `Commit Validator`
   - Click **Add checks** again
   - Search for and add: `Agent Authentication`

**Important Notes:**
- These status checks must exist as GitHub Actions workflows in `.github/workflows/`
- The workflow `name:` field in the YAML file must match exactly
- If checks don't appear, ensure the workflows have run at least once on a PR
- You may need to wait a few minutes and refresh the page

### 8. Enable Force Push Protection

Locate **Block force pushes**:

- ✅ Check the box next to **Block force pushes**
- This prevents force pushes to the main branch, protecting history

### 9. Configure Bypass Permissions

Scroll down to the **Bypass list** section:

1. Click **Add bypass**
2. In the modal that appears:
   - Select **Role** from the dropdown
   - Choose **Organization admin**
   - For **Bypass mode**, select **Always allow**
3. Click **Add** to add the bypass actor

This configuration allows organization administrators to bypass the rules in emergency situations. See the repository's GOVERNANCE.md (once created) for bypass procedures and policies.

### 10. Review and Create

1. Scroll through all settings and verify they match the configuration above
2. Review the **Target branches** to ensure `main` is correctly targeted
3. Review all enabled **Rules** to ensure nothing is missed
4. Review **Bypass list** to ensure only appropriate actors can bypass

When everything looks correct:
- Click the green **Create** button at the bottom of the page

### 11. Verify Ruleset is Active

After creation, you should see:
- The ruleset appears in the list on the Rulesets page
- Status shows as **Active** (green badge)
- Applies to `main` branch

Click on the ruleset name to view its configuration and get its ID from the URL.

### 12. Export the Ruleset (Optional but Recommended)

To save the ruleset configuration to version control:

1. Note the ruleset ID from the URL (e.g., `https://github.com/anokye-labs/akwaaba/settings/rules/12345` → ID is `12345`)
2. Run the export script:
   ```bash
   export GITHUB_TOKEN="your_token_here"
   pwsh -File scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId 12345
   ```
3. Commit the exported JSON to the repository

### 13. Test the Ruleset

Verify the ruleset works by testing each protection:

#### Test 1: Direct Push to Main (Should Fail)
```bash
git checkout main
git commit --allow-empty -m "test direct push"
git push origin main
```
Expected: Push is rejected with a message about branch protection

#### Test 2: Force Push (Should Fail)
```bash
git push --force origin main
```
Expected: Push is rejected

#### Test 3: Branch Deletion (Should Fail)
```bash
git push origin --delete main
```
Expected: Deletion is rejected

#### Test 4: PR Without Approval (Should Block)
1. Create a new branch and PR
2. Try to merge without getting an approval
Expected: Merge button is disabled or blocked

#### Test 5: PR Without Status Checks (Should Block)
1. Create a PR before status checks complete
2. Try to merge
Expected: Merge button is disabled until checks pass

## Troubleshooting

### Issue: Status checks don't appear in the dropdown

**Solution:**
1. Verify the workflows exist in `.github/workflows/commit-validator.yml` and `.github/workflows/agent-authentication.yml`
2. Check that the `name:` field in each workflow matches exactly (`Commit Validator` and `Agent Authentication`)
3. Create a test PR to trigger the workflows at least once
4. Wait 5-10 minutes and refresh the ruleset configuration page
5. If still not appearing, try typing the exact name in the search box

### Issue: Ruleset not enforcing

**Solution:**
1. Verify **Enforcement status** is set to **Active** (not Disabled or Evaluate)
2. Check the **Target branches** configuration matches your branch name exactly
3. Verify you're working on the correct branch (main)

### Issue: Can't merge even with approvals

**Solution:**
1. Ensure status checks have completed successfully (green checkmarks)
2. Verify the branch is up to date with main (rebase or merge latest changes)
3. Check that all conversation threads are resolved
4. Verify you have the required number of approvals (at least 1)

### Issue: Organization admin bypass not working

**Solution:**
1. Verify the user is actually an organization admin (not just repo admin)
2. Check that bypass mode is set to "Always allow"
3. Ensure you're not in a branch that doesn't match the ruleset target

## Optional Rules (Not Enabled by Default)

The following rules can be enabled if your organization requires them:

### Required Signatures
- Requires all commits to be GPG, SSH, or S/MIME signed
- Enable at: **Require signed commits** rule
- Only enable if your team has commit signing infrastructure set up

### Required Deployments
- Requires deployments to specific environments before merging
- Enable at: **Require deployments to succeed before merging** rule
- Useful for requiring staging deploys before production merges

### Restrict Creations
- Restricts who can create branches matching the pattern
- Enable at: **Restrict creations** rule
- Rarely needed for main branch (usually can't be created anyway)

## Additional Configuration Options

### Multiple Branch Patterns
To protect multiple branches with the same rules:
- In **Target branches**, click **Add target** multiple times
- Add patterns like: `main`, `release/*`, `production`

### Team-Based Bypass
Instead of role-based bypass, you can add specific teams:
- In **Bypass list**, select **Team** instead of **Role**
- Choose the specific team that should have bypass access
- More granular than organization-wide admin access

### Status Check Timeout
GitHub will wait indefinitely for required status checks. To prevent this:
- Use branch protection rules in addition to rulesets (if needed)
- Or implement timeout logic in the workflows themselves

## Next Steps

After creating the ruleset:

1. ✅ Test all protections to ensure they work as expected
2. ✅ Export the ruleset configuration to JSON (see step 12)
3. ✅ Document the ruleset in GOVERNANCE.md
4. ✅ Communicate the new protections to the team
5. ✅ Set up the required status check workflows (Commit Validator, Agent Authentication)
6. ✅ Create emergency bypass procedures documentation

## Related Documentation

- [Main Ruleset README](../.github/rulesets/README.md) - Detailed ruleset documentation
- [GitHub Docs: Managing Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GitHub Docs: Available Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)

## Support

If you encounter issues not covered in troubleshooting:
1. Check GitHub's status page for API issues
2. Review GitHub's documentation for updates to ruleset features
3. Contact repository administrators for assistance
4. Create an issue in the repository if you suspect a bug
