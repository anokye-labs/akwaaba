# GitHub Rulesets

This directory contains GitHub repository ruleset configurations for the Akwaaba repository. These rulesets enforce the governance model of the Anokye-Krom System.

## What are Rulesets?

GitHub rulesets are a modern, flexible way to protect branches and enforce repository policies. They replace legacy branch protection rules with a more powerful, layered approach.

## Available Rulesets

### Main Branch Protection (`main-branch-protection.json`)

Protects the `main` branch by enforcing strict governance policies that support the agent-only commit workflow.

#### Rules Enforced

1. **Pull Request Requirements**
   - **Required approvals**: At least 1 approval required before merging
   - **Dismiss stale reviews**: Reviews are dismissed when new commits are pushed
   - **Require conversation resolution**: All review comments must be resolved before merging
   - **Code owner review**: Currently disabled (will be enabled once CODEOWNERS file exists)

2. **Status Check Requirements**
   - **Strict status checks**: Branches must be up-to-date before merging
   - **Required checks**: Will be configured once workflows are added (e.g., commit-validator, agent-auth)

3. **Commit Restrictions**
   - **Block force pushes** (`non_fast_forward`): Prevents rewriting history on main branch
   - **Block branch deletion** (`deletion`): Prevents accidental deletion of main branch
   - **Block branch creation** (`creation`): Prevents direct branch creation at main ref

4. **Signed Commits**
   - **Status**: Not currently enforced
   - **Rationale**: Can be enabled later if desired for additional security
   - **To enable**: Add `{"type": "signed_commits"}` to the rules array

5. **Push Restrictions**
   - Enforced through pull request requirement
   - Direct pushes to main are blocked (must go through PR workflow)
   - Only bypass actors can push directly (see below)

#### Bypass Actors

- **Repository Admins** (`actor_id: 5, actor_type: RepositoryRole`): Can bypass all rules in emergencies
- **Bypass mode**: Always
- **Rationale**: Allows "break glass" emergency access for critical fixes

## Applying Rulesets

### Method 1: GitHub UI (Recommended for first-time setup)

1. Navigate to: **Settings → Rules → Rulesets**
2. Click **New ruleset → Import a ruleset**
3. Upload `main-branch-protection.json`
4. Review settings and click **Create**

### Method 2: GitHub API

```bash
# Get repository ID
REPO_ID=$(gh api repos/anokye-labs/akwaaba --jq '.id')

# Create ruleset
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/anokye-labs/akwaaba/rulesets \
  --input .github/rulesets/main-branch-protection.json
```

### Method 3: GitHub CLI

```bash
# Import the ruleset
gh ruleset import --repo anokye-labs/akwaaba \
  --file .github/rulesets/main-branch-protection.json
```

## Exporting Updated Rulesets

If you modify rulesets via the GitHub UI, export them to keep this repository up-to-date:

```bash
# List rulesets
gh api repos/anokye-labs/akwaaba/rulesets

# Export specific ruleset (replace RULESET_ID)
gh api repos/anokye-labs/akwaaba/rulesets/RULESET_ID \
  > .github/rulesets/main-branch-protection.json
```

## Testing the Ruleset

Once applied, test that protections work:

```bash
# Should fail: Direct push to main
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "test: Direct commit"
git push origin main  # ❌ Should be blocked

# Should fail: Force push to main
git push --force origin main  # ❌ Should be blocked

# Should succeed: PR workflow
git checkout -b test-branch
echo "test" >> test.txt
git add test.txt
git commit -m "test: Via PR"
git push origin test-branch  # ✅ Should succeed
# Then create PR and merge via GitHub UI
```

## Future Enhancements

- Add `signed_commits` rule when GPG signing is configured
- Add required status checks once workflows are implemented:
  - `commit-validator` - Validates commit messages and issue references
  - `agent-auth` - Validates commits are from authorized agents
  - CI/CD pipelines
- Enable `require_code_owner_review` once CODEOWNERS file exists
- Create additional rulesets for:
  - Release branches (`release/*`)
  - Development branches (`develop`)
  - Feature branches (`feature/*`)

## Documentation

- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Ruleset Recipes (GitHub)](https://github.com/github/ruleset-recipes)
- [Planning Document](../../planning/phase-2-governance/01-ruleset-protect-main.md)

## Related Files

- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Explains the agent-only commit workflow
- [agents.md](../../agents.md) - Agent behavior and conventions
- Planning: [phase-2-governance/01-ruleset-protect-main.md](../../planning/phase-2-governance/01-ruleset-protect-main.md)

---

**Note**: These rulesets are part of the Anokye-Krom System governance model, where all commits are made by AI agents in response to human-created issues. The restrictions ensure workflow integrity and auditability.
