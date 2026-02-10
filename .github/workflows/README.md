# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automating repository operations.

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

## Commit Validator

**File:** `commit-validator.yml`

### Purpose

Enforces issue-driven development by validating that every commit in a pull request references an open GitHub issue. This ensures all changes are tracked, documented, and linked to their motivating issues.

### Trigger

- **Event:** `pull_request`
- **Types:** `opened`, `synchronize`, `reopened`
- **When:** A pull request is created or updated

### Behavior

When a pull request is opened or updated, the workflow:

1. **Fetches all commits** in the PR using git log
2. **Validates each commit message** against issue reference patterns
3. **Verifies issue existence** using GitHub CLI
4. **Checks issue state** to ensure it's open (not closed)
5. **Posts results** as a PR comment with detailed feedback
6. **Updates commit status** to pass/fail the check

### Valid Commit Message Formats

Commits must include one of these issue reference formats:

- `#123` - Simple issue reference
- `Closes #123` - Closes the issue when merged
- `Fixes #123` - Fixes the issue when merged
- `Resolves #123` - Resolves the issue when merged
- `owner/repo#123` - Cross-repository reference
- `https://github.com/owner/repo/issues/123` - Full URL

### Special Cases

The validator **automatically skips** these commit types:

- **Merge commits** - Messages starting with `Merge branch` or `Merge pull request`
- **Revert commits** - Messages starting with `Revert`

These are considered administrative commits and don't require issue references.

### Status Check Reporting

The workflow uses `actions/github-script` to provide rich feedback:

#### On Success ✅

- Posts a success comment with summary
- Updates commit status to "success"
- Allows PR to be merged

Example comment:
```
## ✅ Commit Validation Passed

All 3 commits are valid

All commits reference valid open issues. Great job following our issue-driven development workflow! 🎉
```

#### On Failure ❌

- Posts detailed failure comment listing invalid commits
- Updates commit status to "failure"
- Blocks PR merge (when marked as required)
- Provides fix instructions

Example comment:
```
## ❌ Commit Validation Failed

2 of 5 commits failed validation

### Invalid Commits

- `a1b2c3d`: Update documentation
  - **Reason**: No issue reference
- `e4f5g6h`: Fix typo in README
  - **Reason**: Issue is closed

### How to Fix
[Instructions for fixing commits]
```

### Permissions

The workflow requires:
- `contents: read` - To checkout repository and read commits
- `pull-requests: write` - To post comments on PRs
- `statuses: write` - To update commit status checks

### Required Check Configuration

To enforce this validation, add it as a required status check in your branch protection rules:

1. Go to **Settings** → **Branches** → **Branch protection rules**
2. Select your protected branch (e.g., `main`)
3. Enable "Require status checks to pass before merging"
4. Add `commit-validator` to the list of required checks

### Performance

- Typical execution time: < 10 seconds for small PRs
- Handles PRs with dozens of commits efficiently
- Uses GitHub CLI for issue verification
- Caches issue lookups within the same run

### Troubleshooting

If the workflow produces unexpected results:

1. **Check commit message format** - Ensure issue references match the patterns
2. **Verify issue state** - Issue must be OPEN, not CLOSED
3. **Check issue number** - Issue must exist in the repository
4. **Review workflow logs** - Detailed validation output is logged
5. **Test locally** - Use `gh issue view <number>` to verify issue accessibility

### Related Documentation

- [CONTRIBUTING.md](../../CONTRIBUTING.md#commit-message-requirements) - Commit message guidelines
- [How We Work](../../how-we-work.md) - Issue-driven development philosophy

### Examples

**Valid commits:**
```
feat: Add commit validator workflow (#162)
fix: Handle edge case in parser (Closes #145)
docs: Update README with new examples
Fixes #200
```

**Invalid commits:**
```
Update README  # No issue reference
Fix bug  # No issue reference
Closes #999  # Issue doesn't exist
Fixes #50  # Issue is closed
```

