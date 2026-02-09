# GitHub Projects Guide

**Complete guide to setting up and using GitHub Projects for Akwaaba**

This document describes how to configure GitHub Projects (v2) for the Akwaaba repository, including automation rules, custom fields, and workflow integration.

> **Need step-by-step setup instructions?** See the [GitHub Project Setup Guide](./github-project-setup.md) for detailed configuration steps.

---

## Overview

GitHub Projects provides visualization and workflow management for the entire repository lifecycle. Our project board integrates with issues, pull requests, and automation workflows to reduce manual work and provide multiple perspectives on work in progress.

## Project Setup

### Initial Configuration

1. **Create the Project**
   - Navigate to the repository or organization
   - Click **Projects** → **New project**
   - Choose **Table** layout as the primary view
   - Name it **"Akwaaba Development"**
   - Add description: "Work tracking and visualization for the Akwaaba agent-first repository"

2. **Link to Repository**
   - Go to Project Settings → Manage access
   - Ensure the project has access to the `anokye-labs/akwaaba` repository
   - Set permissions appropriately (Write access for automation)

### Custom Fields

Custom fields provide rich metadata for work items. Configure these fields in Project Settings → Fields:

| Field Name | Type | Options | Purpose |
|------------|------|---------|---------|
| **Status** | Single select | Backlog, Ready, In Progress, In Review, Done, Blocked | Track work stage |
| **Priority** | Single select | Critical, High, Medium, Low | Prioritize work |
| **Effort** | Single select | XS, S, M, L, XL | Estimate size |
| **Phase** | Single select | 1-Foundation, 2-Governance, 3-Agents, 4-DotNet, 5-Documentation, 6-Validation | Track project phases |
| **Type** | Single select | Epic, Feature, Task, Bug | Mirror issue types |
| **Agent Owner** | Text | - | Track which agent is working on it |
| **Blocks** | Text | - | List of issue numbers this blocks |
| **Blocked By** | Text | - | List of issue numbers blocking this |

**Important:** The "Type" field in Projects is separate from GitHub's issue types. Projects cannot read issue types directly, so we mirror them here for filtering and grouping.

## Project Views

Create multiple views to provide different perspectives on the work:

### 1. Backlog View

**Purpose:** See all open work, prioritized and ready to assign

**Configuration:**
- Filter: `status:Backlog,Ready`
- Sort: Priority (Critical → Low), then by creation date
- Group by: None
- Visible fields: Title, Status, Priority, Effort, Phase, Type

### 2. Current Sprint View

**Purpose:** Focus on active work in progress

**Configuration:**
- Filter: `status:"In Progress","In Review"`
- Sort: Priority, then by status
- Group by: Agent Owner
- Visible fields: Title, Status, Priority, Type, Assignees

### 3. By Phase View

**Purpose:** See work organized by project phases

**Configuration:**
- Filter: `status:!Done`
- Group by: Phase
- Sort: Priority within each phase
- Visible fields: Title, Status, Priority, Type, Effort

### 4. By Type View

**Purpose:** See hierarchy (Epics → Features → Tasks)

**Configuration:**
- Filter: `status:!Done`
- Group by: Type
- Sort: Creation date (oldest first)
- Visible fields: Title, Status, Priority, Sub-issues count

### 5. Blocked View

**Purpose:** Track blocked issues requiring attention

**Configuration:**
- Filter: `status:Blocked OR "Blocked By":*`
- Sort: Priority
- Group by: None
- Visible fields: Title, Status, Blocked By, Assignees, Labels

### 6. Board View (Optional)

**Purpose:** Kanban-style status board

**Configuration:**
- Layout: Board
- Columns: Backlog, Ready, In Progress, In Review, Done
- Group by: Status
- Show: All open issues

## Automation Rules

GitHub Projects supports built-in automation through workflows. Configure these in Project Settings → Workflows:

### Auto-add Issues

**Trigger:** Item added to repository
**Action:** Add to project
**Configuration:**
- When issues or pull requests are created
- Automatically add them to the project
- Set initial Status to "Backlog"

### Status: In Progress

**Trigger:** Item is assigned
**Action:** Set field value
**Configuration:**
- When an issue is assigned to someone
- Set Status to "In Progress"

### Status: In Review

**Trigger:** Pull request linked
**Action:** Set field value
**Configuration:**
- When a pull request is linked to an issue
- Set Status to "In Review"

### Status: Done

**Trigger:** Item closed
**Action:** Set field value
**Configuration:**
- When an issue or PR is closed
- Set Status to "Done"

### Status: Blocked

**Trigger:** Label added
**Action:** Set field value
**Configuration:**
- When label "blocked" is added to an issue
- Set Status to "Blocked"

## GitHub Actions Integration

In addition to built-in automation, use GitHub Actions for more complex workflows:

### Auto-assign Unblocked Tasks

The `.github/workflows/auto-assign-unblocked.yml` workflow:
- Triggers when issues are closed
- Finds issues blocked by the closed issue
- Checks if all dependencies are resolved
- Automatically assigns unblocked issues to `@copilot`

### Project Field Updates (Optional)

Create workflows to:
- Update custom fields based on issue labels
- Set Priority based on label patterns
- Update Phase based on milestone
- Sync Type field with actual issue type

Example workflow:
```yaml
name: Update Project Fields

on:
  issues:
    types: [opened, labeled, unlabeled, edited]

jobs:
  update-fields:
    runs-on: ubuntu-latest
    steps:
      - name: Update project fields via GraphQL
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          # Use GraphQL to update project fields
          # See .github/skills/okyerema/references/projects.md for examples
```

## Hierarchy Visualization

GitHub Projects can visualize issue hierarchies through sub-issues:

### Setting Up Hierarchy

1. **Use Sub-Issues API** — Create parent-child relationships via GraphQL
   ```graphql
   mutation {
     createIssueRelationship(input: {
       repositoryId: "R_xxx"
       parentId: "I_parent_xxx"
       childId: "I_child_xxx"
     }) {
       issueRelationship {
         parent { number }
         child { number }
       }
     }
   }
   ```

2. **Project Fields** — Use "Blocks" and "Blocked By" text fields for cross-dependencies

3. **Progress Tracking** — Projects automatically show progress for issues with sub-issues

### Viewing Hierarchy

- In the "By Type" view, group by Type to see Epics, Features, and Tasks separately
- Use the sub-issues count field to see how many children each item has
- Click into an issue to see its sub-issues panel on the right

## Best Practices

### Do's

✅ **Use Status field consistently** — Let automation handle most status changes  
✅ **Set Priority on all work** — Helps with sorting and filtering  
✅ **Update Blocked By field** — Makes dependencies visible  
✅ **Use views for focus** — Switch views based on what you need to see  
✅ **Keep Type field in sync** — Update when issue type changes  

### Don'ts

❌ **Don't use Projects for relationships** — Use sub-issues API instead  
❌ **Don't manually move items too often** — Trust the automation  
❌ **Don't create too many custom views** — Start with the core set  
❌ **Don't confuse Project fields with issue data** — They're separate systems  

## Maintenance

### Weekly Tasks

- Review "Blocked" view and resolve blockers
- Check "Current Sprint" for stale assignments
- Verify Type field matches issue types
- Archive completed work (optional)

### Monthly Tasks

- Review automation rules effectiveness
- Update views based on team feedback
- Check for orphaned project items
- Verify hierarchy relationships are correct

## Troubleshooting

### Issue not appearing in project

1. Check if auto-add workflow is enabled
2. Manually add with "Add item" button
3. Verify repository is linked to project

### Status not updating automatically

1. Check workflow triggers in Settings
2. Verify issue state transitions match triggers
3. Check GitHub Actions logs for errors

### Custom field not showing

1. Verify field is enabled in project settings
2. Check if field is hidden in current view
3. Adjust view field visibility settings

### Hierarchy not visible

1. Ensure sub-issue relationships are created via GraphQL
2. Check that issue types are set correctly
3. Use the "By Type" view to see hierarchy grouped

## Advanced Configuration

### GraphQL Integration

For programmatic project management, use GraphQL (see `.github/skills/okyerema/references/projects.md`):

- Query project data
- Update custom fields
- Bulk add items
- Set field values programmatically

### API Limitations

- GitHub CLI (`gh`) has limited project field support
- Always use GraphQL for custom field operations
- Rate limits apply to GraphQL queries (5000/hour)

### Export and Backup

Projects cannot be exported as code directly. To replicate:

1. Document all custom fields and options
2. Export automation rules as documented workflows
3. Save view configurations as text descriptions
4. Use GraphQL queries to extract data

## Resources

- [GitHub Projects Documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [Okyerema Skill Projects Reference](../.github/skills/okyerema/references/projects.md)
- [ADR: Use Sub-Issues API for Hierarchy](./adr/ADR-0001-use-sub-issues-for-hierarchy.md)
- [How We Work: Our Way](../how-we-work/our-way.md)

---

*Back to [Documentation Index](./README.md)*
