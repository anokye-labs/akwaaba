# Commit Validator Testing Guide

This document describes how to test the commit validator workflow and demonstrates the expected behavior for different scenarios.

## Test Scenarios

### Scenario 1: Valid Commit References

**Purpose**: Verify that commits with valid issue references pass validation.

**Setup**:
1. Create a test branch
2. Create commits that reference open issues

**Example commits**:
```bash
git commit -m "feat: Add new feature #415"
git commit -m "fix: Fix bug

Closes #415"
git commit -m "docs: Update documentation

Resolves #415
Fixes #416"
```

**Expected Result**:
- ✅ All commits pass validation
- Workflow completes successfully
- PR can be merged

### Scenario 2: Invalid Commits (No Issue Reference)

**Purpose**: Verify that commits without issue references fail validation.

**Setup**:
1. Create a test branch
2. Create commits without issue references

**Example commits**:
```bash
git commit -m "feat: Add new feature"
git commit -m "fix: Fix bug"
```

**Expected Result**:
- ❌ Validation fails
- Workflow provides clear error message listing invalid commits
- PR is blocked from merging
- Error message shows supported formats

**Error Message Example**:
```
=== Invalid Commits ===

Commit: a1b2c3d
Message: feat: Add new feature
Reason: No issue reference found

=== How to Fix ===
Every commit must reference an open GitHub issue. Supported formats:
  - #123
  - Closes #123
  - Fixes #456
  - Resolves #789
  - owner/repo#123
  - https://github.com/owner/repo/issues/123

To fix your commits, you can:
  1. Amend commit messages: git commit --amend
  2. Interactive rebase: git rebase -i HEAD~N
  3. Force push: git push --force-with-lease
```

### Scenario 3: Closed Issue Reference

**Purpose**: Verify that commits referencing closed issues fail validation.

**Setup**:
1. Create a test branch
2. Find a closed issue number
3. Create commits referencing the closed issue

**Example commits**:
```bash
# Assuming issue #100 is closed
git commit -m "feat: Add feature related to #100"
```

**Expected Result**:
- ❌ Validation fails
- Workflow reports that the referenced issue is closed
- PR is blocked from merging

**Error Message Example**:
```
=== Invalid Commits ===

Commit: x7y8z9a
Message: feat: Add feature related to #100
Reason: Issue #100 in anokye-labs/akwaaba is closed
```

### Scenario 4: Merge and Revert Commits

**Purpose**: Verify that merge and revert commits are skipped from validation.

**Setup**:
1. Create a test branch with regular commits
2. Merge another branch or create a revert commit

**Example commits**:
```bash
git merge feature-branch
# Creates: "Merge branch 'feature-branch' into main"

git revert abc123
# Creates: "Revert 'Add feature (#123)'"
```

**Expected Result**:
- ✅ Merge and revert commits are automatically skipped
- Only regular commits are validated
- Workflow completes successfully if all regular commits are valid

### Scenario 5: Multiple Issue References

**Purpose**: Verify that commits can reference multiple issues.

**Setup**:
1. Create a test branch
2. Create commits referencing multiple issues

**Example commits**:
```bash
git commit -m "feat: Major refactor #415 #416

This change addresses multiple issues:
- Fixes #417
- Resolves #418"
```

**Expected Result**:
- ✅ All referenced issues are validated
- At least one valid (open) issue reference is required
- Workflow completes successfully if at least one issue is valid

### Scenario 6: Cross-Repository References

**Purpose**: Verify that commits can reference issues in other repositories.

**Setup**:
1. Create a test branch
2. Create commits referencing issues in other repos

**Example commits**:
```bash
git commit -m "feat: Integrate with external-org/external-repo#123"
git commit -m "fix: Address https://github.com/external-org/external-repo/issues/456"
```

**Expected Result**:
- ✅ Cross-repository references are validated
- Referenced issues in external repos are checked
- Workflow completes successfully if issues exist and are open

## Running Tests Locally

### Prerequisites
- PowerShell 7.x or higher
- GitHub CLI (gh) installed and authenticated

### Unit Tests

Run the comprehensive unit tests:

```powershell
pwsh scripts/Test-Validate-Commits.ps1
```

Expected output:
```
Testing Validate-Commits.ps1...
Correlation ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Running: Script file exists
✓ PASS: Script file exists

Running: Help content is available
✓ PASS: Help content is available

...

============================================
Test Summary
============================================
Total Tests: 17
Passed: 17
Failed: 0

✅ All tests passed!
```

### Manual Testing

Test the validation script against a specific PR:

```powershell
# Test against PR #42
pwsh scripts/Validate-Commits.ps1 -PRNumber 42

# Test against PR in specific repo
pwsh scripts/Validate-Commits.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba
```

## Workflow Behavior

### Graceful Degradation

The workflow includes graceful degradation for incremental development:

```yaml
- name: Validate commits
  shell: pwsh
  run: |
    # Check if validation script exists
    $scriptPath = "./scripts/Validate-Commits.ps1"
    if (-not (Test-Path $scriptPath)) {
      Write-Host "⚠️  Warning: Validation script not found" -ForegroundColor Yellow
      Write-Host "Skipping validation (graceful degradation)" -ForegroundColor Yellow
      exit 0
    }
    
    # Run validation
    & $scriptPath -PRNumber ${{ github.event.pull_request.number }}
```

This ensures that:
- PRs are not blocked if the script doesn't exist yet
- Development can proceed incrementally
- The workflow provides clear warnings when skipping validation

### PR Comments

On validation failure, the workflow posts a comment to the PR with:
- Clear error message
- List of supported formats
- Link to contributing guidelines

## Testing Checklist

Use this checklist when testing the commit validator:

- [ ] Test with valid commit references (#123)
- [ ] Test with keyword references (Closes #123, Fixes #456)
- [ ] Test with no issue references
- [ ] Test with closed issue references
- [ ] Test with merge commits
- [ ] Test with revert commits
- [ ] Test with multiple issue references
- [ ] Test with cross-repository references (owner/repo#123)
- [ ] Test with full URL references
- [ ] Verify error messages are clear and actionable
- [ ] Verify PR comments are posted on failure
- [ ] Verify workflow completes successfully on valid commits
- [ ] Verify graceful degradation when script is missing

## Troubleshooting

### Issue: Validation script not found

**Error**: 
```
⚠️  Warning: Validation script not found at ./scripts/Validate-Commits.ps1
Skipping validation (graceful degradation during development)
```

**Solution**: 
- Ensure the script is committed to the repository
- Check the file path is correct
- Verify the workflow has checked out the repository

### Issue: GitHub CLI authentication fails

**Error**:
```
Error: Failed to fetch PR commits: gh: To use GitHub CLI, set the GH_TOKEN environment variable
```

**Solution**:
- Ensure `GH_TOKEN` is set in workflow environment variables
- Check `github.token` is available in the workflow context
- Verify repository permissions are correct

### Issue: Cannot verify issue exists

**Error**:
```
Failed to verify issue #123: gh issue view failed
```

**Solution**:
- Ensure the issue number is correct
- Verify the issue exists in the specified repository
- Check GitHub CLI has permissions to read issues
- Verify network connectivity

## Future Enhancements

Potential improvements for the commit validator:

1. **Caching**: Cache issue lookup results to reduce API calls
2. **Custom patterns**: Allow repository-specific commit message patterns
3. **Bot exemptions**: Automatically skip validation for approved bot commits
4. **Detailed metrics**: Track validation pass/fail rates over time
5. **Custom actions**: Support custom validation rules via configuration file

## References

- Planning Document: `planning/phase-2-governance/02-workflow-commit-validator.md`
- Validation Script: `scripts/Validate-Commits.ps1`
- Test Script: `scripts/Test-Validate-Commits.ps1`
- Workflow File: `.github/workflows/commit-validator.yml`
- Contributing Guidelines: `CONTRIBUTING.md`
