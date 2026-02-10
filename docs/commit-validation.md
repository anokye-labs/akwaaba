# Commit Validation

This document describes the commit validation system that enforces the issue-driven development workflow in the Akwaaba repository.

## Overview

The commit validator ensures that every commit in a pull request references at least one open GitHub issue. This enforcement maintains the integrity of the issue-first workflow where all work must be tracked through GitHub issues.

## How It Works

### Workflow

The validation is performed automatically by the `.github/workflows/commit-validator.yml` GitHub Actions workflow, which runs on every pull request when:
- A PR is opened
- New commits are pushed to an existing PR
- A PR is reopened

### Validation Script

The `scripts/Validate-Commits.ps1` PowerShell script performs the actual validation:

1. **Fetches PR commits** - Retrieves all commits in the pull request
2. **Extracts issue references** - Parses commit messages for issue numbers
3. **Validates references** - Checks that referenced issues exist and are open
4. **Handles special cases** - Skips validation for merge commits, revert commits, and bot commits
5. **Reports results** - Provides detailed feedback on failures

## Supported Commit Message Formats

The validator recognizes multiple ways to reference issues:

### Simple Reference
```
feat: Add user authentication #123
```

### Closing Keywords
```
fix: Resolve login bug Closes #456
fix: Address timeout issue Fixes #789
feat: Implement feature Resolves #101
```

### Multiple Issues
```
feat: Implement changes #123 #456
refactor: Update code Closes #123 Fixes #456
```

### Cross-Repository Reference
```
docs: Update guide owner/repo#123
```

### Full URL Reference
```
feat: New feature https://github.com/owner/repo/issues/123
```

## Error Messages

When validation fails, the system provides helpful error messages that include:

1. **List of failing commits** - Shows which commits don't have valid issue references
2. **Expected formats** - Examples of correct commit message formats
3. **Fix instructions** - Step-by-step guidance on how to resolve the issue
4. **Resource links** - Links to contribution guidelines and documentation

### Example Error Output

```
❌ Commit Validation Failed

The following commits do not reference an open GitHub issue:

  • a1b2c3d - feat: Add new feature
    Reason: No issue reference found in commit message

  • e4f5g6h - fix: Bug fix
    Reason: Issue(s) #123 are closed

📋 Expected Commit Message Format:

All commits must reference at least one open GitHub issue. Here are valid formats:

  ✓ Simple reference:
    feat: Add user authentication #123

  ✓ Closing keywords:
    fix: Resolve login bug Closes #456

  ✓ Multiple issues:
    feat: Implement changes #123 #456

🔧 How to Fix:

Option 1: Amend the most recent commit
  git commit --amend -m "your commit message #123"
  git push --force

Option 2: Interactive rebase (for multiple commits)
  git rebase -i HEAD~N  # where N is the number of commits
  # Mark commits with 'reword' to edit their messages
  git push --force

Option 3: Create a new issue for this work
  1. Create a GitHub issue describing this work
  2. Amend your commit(s) to reference the new issue
  3. Push the updated commits
```

## Special Cases

### Exempted Commits

The following commit types are automatically exempted from validation:

- **Merge commits** - Commits that merge branches or pull requests
- **Revert commits** - Commits that revert previous changes
- **Bot commits** - Commits from automated systems (author ends with `[bot]`)

### Issue State

Referenced issues must be **open** (not closed). If a commit references only closed issues, validation will fail with a clear explanation of which issues are closed.

### Issue Existence

Issues must exist in the repository. If a commit references a non-existent issue number, validation will fail.

## Running Manually

You can run the validation script manually for testing or debugging:

```powershell
# Validate commits in PR #123
./scripts/Validate-Commits.ps1 -PRNumber 123

# Validate against a specific base branch
./scripts/Validate-Commits.ps1 -PRNumber 456 -BaseRef develop
```

## Testing

A comprehensive test suite is available at `scripts/Test-Validate-Commits.ps1`:

```powershell
# Run all tests
./scripts/Test-Validate-Commits.ps1
```

The test suite includes 20 test cases covering:
- Valid commit message formats
- Invalid commit messages
- Edge cases (merge, revert, bot commits)
- Issue reference extraction
- Special commit detection

## Why We Do This

The issue-first workflow ensures:
- **Traceability** - All changes are tracked and documented
- **Coordination** - Work is coordinated through a single source of truth
- **Clarity** - The "why" behind every commit is clear and searchable
- **Collaboration** - Agents and humans can work together effectively

## Resources

- [Contribution Guidelines](../CONTRIBUTING.md) - Detailed contribution process
- [How We Work](../how-we-work.md) - Overview of the issue-first workflow
- [Commit Validator Workflow](../.github/workflows/commit-validator.yml) - GitHub Actions workflow
- [Validation Script](../scripts/Validate-Commits.ps1) - PowerShell validation script
- [Test Suite](../scripts/Test-Validate-Commits.ps1) - Comprehensive test coverage

## Troubleshooting

### Common Issues

**Issue: "No issue reference found"**
- Solution: Add an issue reference to your commit message (e.g., `#123`)

**Issue: "Issue #123 is closed"**
- Solution: Reference an open issue, or reopen the closed issue if work is still needed

**Issue: "Issue #123 does not exist"**
- Solution: Create the issue first, then reference it in your commit

**Issue: "Validation fails but I've referenced an issue"**
- Check that the issue number is correct
- Verify the issue is open (not closed)
- Ensure you're using a supported format (see examples above)

### Getting Help

If you encounter issues with the validation system:
1. Check the error message for specific guidance
2. Review the examples in this documentation
3. Consult the [Contribution Guidelines](../CONTRIBUTING.md)
4. Create an issue with the `question` label for assistance
