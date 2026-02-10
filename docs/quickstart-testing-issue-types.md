# Quick Start: Testing Issue Types

This guide helps you quickly test the organization-level issue type system.

## TL;DR

```powershell
# Run full test (create → verify → prompt for cleanup)
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba"
```

## What This Tests

✅ Creating issues with all 4 types (Epic, Feature, Task, Bug)  
✅ Linking issues in hierarchy (Epic → Feature → Task)  
✅ Verifying types via GraphQL queries  
✅ Validating sub-issues API relationships  
✅ Optional cleanup of test issues

## Prerequisites

1. **PowerShell 7.x or higher** installed
2. **GitHub CLI** (`gh`) installed and authenticated
3. **Permissions** to create issues in the target repository
4. **Organization** has issue types configured (Epic, Feature, Task, Bug)

## Step-by-Step

### 1. Full Test Run

Creates test issues, verifies them, and prompts for cleanup:

```powershell
cd /path/to/akwaaba
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba"
```

Expected output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  STEP 1: Creating Test Issues
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▶ Creating test Epic
  ✓ Created Epic #123

▶ Creating test Feature linked to Epic
  ✓ Created Feature #124
  ✓ Linked Feature to Epic

...
```

### 2. Leave Issues Open for Inspection

Skip cleanup to manually inspect created issues:

```powershell
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" -SkipCleanup
```

Visit the issues on GitHub to verify:
- Issue types are correctly shown
- Hierarchy appears in the UI
- Relationships are properly linked

### 3. Verify Existing Issues

If you already have test issues:

```powershell
$issues = @{ Epic = 123; Feature = 124; Task = 125; Bug = 126 }
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" `
    -SkipCreation -TestIssueNumbers $issues
```

### 4. Cleanup Only

Close previously created test issues:

```powershell
$issues = @{ Epic = 123; Feature = 124; Task = 125; Bug = 126 }
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" `
    -CleanupOnly -TestIssueNumbers $issues
```

## What Gets Created

The test script creates 4 issues:

1. **Epic** — "Test Epic for Issue Type Verification"
2. **Feature** — "Test Feature for Issue Type Verification" (linked to Epic)
3. **Task** — "Test Task for Issue Type Verification" (linked to Feature)
4. **Bug** — "Test Bug for Issue Type Verification" (standalone)

All issues are prefixed with `[TEST]` for easy identification.

## Verifying Results

The script automatically verifies:
- ✓ Each issue has the correct type
- ✓ Feature is a sub-issue of Epic
- ✓ Task is a sub-issue of Feature
- ✓ All relationships are queryable via GraphQL

You can also manually verify:

```powershell
# View hierarchy tree
./scripts/Get-DagStatus.ps1 -IssueNumber 123 -Format Tree

# Query via GraphQL
gh api graphql -H "GraphQL-Features: sub_issues" -f query='
  query {
    repository(owner: "anokye-labs", name: "akwaaba") {
      issue(number: 123) {
        issueType { name }
        subIssues(first: 10) {
          nodes { number title issueType { name } }
        }
      }
    }
  }
'
```

## Troubleshooting

### "Issue type 'Epic' not found"

**Problem:** Organization doesn't have issue types configured.

**Solution:** Contact organization admin to set up Epic, Feature, Task, and Bug issue types at the organization level.

### "Field 'subIssues' doesn't exist"

**Problem:** Missing required GraphQL header.

**Solution:** Ensure you're using `GraphQL-Features: sub_issues` header. The test script handles this automatically.

### "Permission denied"

**Problem:** Insufficient permissions to create issues.

**Solution:** Ensure you have write access to the repository and your `gh` authentication is valid:

```bash
gh auth status
gh auth refresh
```

## Manual Testing Alternative

If you prefer to test manually without the script:

```powershell
# 1. Create Epic
$epic = ./.github/skills/okyerema/scripts/New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -Title "[TEST] Manual Test Epic" -TypeName "Epic"

# 2. Create Feature and link to Epic
$feature = ./.github/skills/okyerema/scripts/New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -Title "[TEST] Manual Test Feature" -TypeName "Feature"

./.github/skills/okyerema/scripts/Update-IssueHierarchy.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -ParentNumber $epic.number -ChildNumber $feature.number

# 3. Verify
./scripts/Get-DagStatus.ps1 -IssueNumber $epic.number -Format Tree

# 4. Cleanup
gh issue close $epic.number $feature.number
```

## Learn More

- [Full Testing Documentation](testing-issue-types.md)
- [Issue Types vs Templates](issue-types-vs-templates.md)
- [ADR-0003: Use Organization-Level Issue Types](adr/ADR-0003-use-org-level-issue-types.md)
- [Okyerema Skill](../.github/skills/okyerema/SKILL.md)

## Quick Reference

| Command | Purpose |
|---------|---------|
| `Test-IssueTypes.ps1` | Full test run with cleanup prompt |
| `Test-IssueTypes.ps1 -SkipCleanup` | Create and verify, leave open |
| `Test-IssueTypes.ps1 -SkipCreation -TestIssueNumbers @{...}` | Verify existing |
| `Test-IssueTypes.ps1 -CleanupOnly -TestIssueNumbers @{...}` | Close test issues |
| `Get-DagStatus.ps1 -IssueNumber N` | View hierarchy tree |
| `New-IssueWithType.ps1` | Create single issue with type |
| `Update-IssueHierarchy.ps1` | Link parent-child issues |
