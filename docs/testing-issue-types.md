# Testing Issue Types

This document explains how to test the organization-level issue types used in the Anokye Labs repositories.

## Background

According to [ADR-0003: Use Organization-Level Issue Types](./adr/ADR-0003-use-org-level-issue-types.md), this repository uses **GitHub organization-level issue types** rather than issue templates with labels. The four issue types are:

- **Epic** — Large initiatives spanning multiple features
- **Feature** — Cohesive functionality grouping related tasks  
- **Task** — Specific work items to be completed
- **Bug** — Defects or broken functionality

## Why Test Issue Types?

Testing ensures that:
1. Organization-level issue types are properly configured
2. Issues can be created with the correct types
3. Hierarchical relationships work correctly (Epic → Feature → Task)
4. The sub-issues API properly links parent and child issues
5. GraphQL queries correctly retrieve type information

## Test Script

We provide a comprehensive test script at `/scripts/Test-IssueTypes.ps1` that:

1. **Creates test issues** with each type (Epic, Feature, Task, Bug)
2. **Establishes hierarchies** using the sub-issues API
3. **Verifies relationships** via GraphQL queries
4. **Cleans up** by closing test issues after verification

### Running the Test

```powershell
# Full test with creation, verification, and cleanup prompt
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba"

# Create and verify but skip cleanup (leave issues open for inspection)
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" -SkipCleanup

# Only verify existing test issues (no creation)
$issues = @{ Epic = 123; Feature = 124; Task = 125; Bug = 126 }
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" `
    -SkipCreation -TestIssueNumbers $issues

# Cleanup only (close specified test issues)
$issues = @{ Epic = 123; Feature = 124; Task = 125; Bug = 126 }
./scripts/Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" `
    -CleanupOnly -TestIssueNumbers $issues
```

### Test Output

The script provides detailed output for each step:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  STEP 1: Creating Test Issues
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▶ Creating test Epic
  ✓ Created Epic #123

▶ Creating test Feature linked to Epic
  ✓ Created Feature #124
  ✓ Linked Feature to Epic

▶ Creating test Task linked to Feature
  ✓ Created Task #125
  ✓ Linked Task to Feature

▶ Creating test Bug (standalone)
  ✓ Created Bug #126

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Created test issues:
  Epic : #123
  Feature : #124
  Task : #125
  Bug : #126
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

...verification output...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TEST SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Created Issues:
  Epic #123 - ✓ Verified
  Feature #124 - ✓ Verified
  Task #125 - ✓ Verified
  Bug #126 - ✓ Verified

Overall Status: SUCCESS ✓
All issue types created and verified correctly!
```

## What the Test Verifies

### 1. Issue Creation with Types

The test creates one issue of each type and verifies that the `issueType` field is correctly set:

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 123) {
      number
      title
      issueType { name }  # Should be "Epic", "Feature", "Task", or "Bug"
    }
  }
}
```

### 2. Hierarchy Relationships

The test verifies that the sub-issues API correctly establishes parent-child relationships:

```
Epic #123
└─ Feature #124
   └─ Task #125
```

Using GraphQL with the `sub_issues` feature:

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 123) {
      subIssues(first: 50) {
        nodes {
          number
          title
          issueType { name }
          subIssues(first: 50) {
            nodes {
              number
              title
              issueType { name }
            }
          }
        }
      }
    }
  }
}
```

### 3. Type Integrity

Each issue in the hierarchy maintains its correct type:
- Epic #123 remains type "Epic"
- Feature #124 remains type "Feature"  
- Task #125 remains type "Task"
- Bug #126 remains type "Bug" (standalone)

## Manual Testing

If you prefer to test manually:

### Step 1: Create Test Epic

```powershell
./.github/skills/okyerema/scripts/New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -Title "[TEST] Test Epic" `
    -TypeName "Epic" `
    -Body "Test Epic for verification"
```

### Step 2: Create Test Feature and Link to Epic

```powershell
# Create Feature
$feature = ./.github/skills/okyerema/scripts/New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -Title "[TEST] Test Feature" `
    -TypeName "Feature" `
    -Body "Test Feature for verification"

# Link to Epic (replace 123 with your Epic number)
./.github/skills/okyerema/scripts/Update-IssueHierarchy.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -ParentNumber 123 `
    -ChildNumber $feature.number
```

### Step 3: Create Test Task and Link to Feature

```powershell
# Create Task
$task = ./.github/skills/okyerema/scripts/New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -Title "[TEST] Test Task" `
    -TypeName "Task" `
    -Body "Test Task for verification"

# Link to Feature (replace 124 with your Feature number)
./.github/skills/okyerema/scripts/Update-IssueHierarchy.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -ParentNumber 124 `
    -ChildNumber $task.number
```

### Step 4: Create Test Bug

```powershell
./.github/skills/okyerema/scripts/New-IssueWithType.ps1 `
    -Owner "anokye-labs" -Repo "akwaaba" `
    -Title "[TEST] Test Bug" `
    -TypeName "Bug" `
    -Body "Test Bug for verification"
```

### Step 5: Verify Hierarchy

```powershell
# View hierarchy tree (replace 123 with your Epic number)
./scripts/Get-DagStatus.ps1 -IssueNumber 123 -Format Tree
```

### Step 6: Cleanup

```powershell
# Close each test issue via GitHub CLI or web UI
gh issue close 123 124 125 126
```

## Common Issues

### Issue Type Not Found

**Error:** `Issue type 'Epic' not found`

**Solution:** The organization doesn't have issue types configured. Contact the organization admin to set up Epic, Feature, Task, and Bug issue types at the organization level.

### Sub-Issues API Not Working

**Error:** `Field 'subIssues' doesn't exist on type 'Issue'`

**Solution:** Ensure you're using the `GraphQL-Features: sub_issues` header in your GraphQL requests:

```bash
gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."
```

### Wrong Issue Type After Creation

**Problem:** Issue shows wrong type after creation

**Solution:** You may have used `gh issue create` instead of the GraphQL API. Use `New-IssueWithType.ps1` or the GraphQL `createIssue` mutation with `issueTypeId` parameter.

## Important Notes

1. **Labels vs Types**: This repository does NOT use labels for type classification (no `epic`, `task`, `feature` labels). Issue types are organization-level metadata, not labels.

2. **No Issue Templates**: The repository uses organization-level issue types, not issue templates in `.github/ISSUE_TEMPLATE/`. The planning document mentioning issue templates was superseded by ADR-0003.

3. **Agent Request**: There is no "Agent Request" issue type. The original planning document (`planning/phase-2-governance/04-issue-templates.md`) proposed an "Agent Request" template, but this was not implemented when we switched to organization-level issue types. If you need to propose an agent, create a Feature or Task issue with appropriate labels (e.g., `agent-related`, `enhancement`).

4. **GraphQL Required**: Issue types can only be set via GraphQL API, not via `gh issue create` CLI commands.

## See Also

- [ADR-0003: Use Organization-Level Issue Types](./adr/ADR-0003-use-org-level-issue-types.md)
- [ADR-0001: Use Sub-Issues API for Hierarchy](./adr/ADR-0001-use-sub-issues-for-hierarchy.md)
- [Okyerema Skill Documentation](../.github/skills/okyerema/SKILL.md)
- [Issue Types Reference](../.github/skills/okyerema/references/issue-types.md)
- [Relationships Reference](../.github/skills/okyerema/references/relationships.md)
