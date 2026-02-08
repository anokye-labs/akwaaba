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

- Processes up to 1000 open issues per run
- Only assigns unassigned issues
- Requires issues to use the standard Dependencies format
- Dependencies must be in the same repository or accessible via `gh issue view`

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
