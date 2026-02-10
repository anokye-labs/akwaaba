# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automating repository operations.

## Commit Validator

**File:** `commit-validator.yml`

### Purpose

Validates that every commit in a pull request references a GitHub issue, enforcing issue-driven development.

### Trigger

- **Event:** `pull_request`
- **Types:** `opened`, `synchronize`
- **When:** A pull request is opened or updated with new commits

### Behavior

When a pull request is created or updated, the workflow:

1. **Checks out the repository** with full git history
2. **Sets up PowerShell environment** on ubuntu-latest
3. **Runs validation script** (`scripts/Validate-Commits.ps1`) to check all commits
4. **Validates each commit** contains an issue reference (e.g., `#123`, `Closes #123`, `Fixes #123`)
5. **Sets job status** based on validation results:
   - ✅ Success: All commits reference valid issues
   - ❌ Failure: One or more commits missing issue references

### Commit Message Format

Commits should reference GitHub issues using one of these patterns:
- `#123` - References issue
- `Closes #123` - Closes issue when merged
- `Fixes #123` - Fixes issue when merged
- `Resolves #123` - Resolves issue when merged

Example: `feat(governance): Add commit validation workflow (#42)`

### Permissions

The workflow requires:
- `contents: read` - To checkout the repository
- `pull-requests: read` - To read pull request information

### Status

**Current Status:** Workflow configured, validation script pending implementation

The workflow file is in place and will:
- Run successfully if the validation script exists
- Show a warning and pass if the script doesn't exist yet (to avoid blocking PRs during initial setup)

Once `scripts/Validate-Commits.ps1` is implemented, the workflow will enforce commit validation.

### Related Documentation

- Planning: `planning/phase-2-governance/02-workflow-commit-validator.md`
- This implements Task 5 of the Commit Validator feature

### Troubleshooting

If the workflow fails:

1. **Check commit messages** - Ensure all commits reference an issue with `#123` format
2. **View workflow logs** - Check Actions tab for detailed error messages
3. **Verify issue exists** - Make sure referenced issues exist and are open
4. **Review validation script** - Check `scripts/Validate-Commits.ps1` for logic errors

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
