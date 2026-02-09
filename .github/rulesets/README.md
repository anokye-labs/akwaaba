# Repository Rulesets

This directory contains GitHub repository ruleset configurations that enforce governance policies for the Akwaaba repository.

## What are Rulesets?

GitHub repository rulesets are a modern approach to branch protection that provides:
- Fine-grained control over branch policies
- JSON-based configuration for version control and replication
- Flexible bypass permissions
- Better integration with status checks and workflows

## Active Rulesets

### Main Branch Protection (`main-branch-protection.json`)

Protects the `main` branch with comprehensive rules to ensure code quality and maintain the integrity of the Anokye-Krom System.

**Rules Enforced:**

1. **Pull Request Required** - All changes must go through a pull request
   - No direct pushes to main
   - Ensures all changes are reviewed and tracked

2. **Required Approvals** - At least 1 approving review required
   - Ensures peer review of all changes
   - Maintains code quality standards

3. **Dismiss Stale Reviews** - Reviews are dismissed when new commits are pushed
   - Ensures reviewers see the latest code
   - Prevents approval of outdated changes

4. **Code Owner Review** - Requires review from code owners
   - Ensures domain experts review relevant changes
   - Requires CODEOWNERS file to be configured

5. **Conversation Resolution** - All review threads must be resolved
   - Ensures feedback is addressed
   - Prevents important comments from being ignored

6. **Delete Protection** - Prevents branch deletion
   - Protects the main branch from accidental removal

7. **Force Push Protection** - Blocks force pushes and non-fast-forward updates
   - Maintains commit history integrity
   - Prevents history rewriting

**Bypass Permissions:**

- Repository administrators can bypass these rules in emergency situations
- Bypass should be used sparingly and documented when necessary

## Applying Rulesets

These JSON files serve as the source of truth for repository governance. To apply or update a ruleset:

1. **Via GitHub UI:**
   - Navigate to Settings → Rules → Rulesets
   - Click "New ruleset" or edit existing
   - Import the JSON configuration
   - Review and activate

2. **Via GitHub API:**
   ```bash
   gh api repos/anokye-labs/akwaaba/rulesets \
     --method POST \
     --input .github/rulesets/main-branch-protection.json
   ```

3. **Via GitHub CLI:**
   ```bash
   gh ruleset create --repo anokye-labs/akwaaba \
     --file .github/rulesets/main-branch-protection.json
   ```

## Exporting Rulesets

To export current rulesets from GitHub:

```bash
# List all rulesets
gh api repos/anokye-labs/akwaaba/rulesets

# Export a specific ruleset by ID
gh api repos/anokye-labs/akwaaba/rulesets/{ruleset_id} > main-branch-protection.json
```

## Notes

- Rulesets complement branch protection rules but are more flexible
- Changes to these files should be reviewed carefully
- Test rulesets in a development environment when possible
- Document any emergency bypasses in issue comments or incident reports

## References

- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [Available Rules for Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)
- [Creating Rulesets via API](https://docs.github.com/en/rest/repos/rules)
