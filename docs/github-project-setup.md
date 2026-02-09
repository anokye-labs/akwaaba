# GitHub Project Setup Guide

**Step-by-step instructions for creating the Akwaaba Development project**

This guide walks through the manual steps needed to create and configure the GitHub Project for the Akwaaba repository. GitHub Projects v2 cannot be fully configured through code, so these steps must be performed through the GitHub UI.

---

## Prerequisites

- Admin or Write access to the `anokye-labs/akwaaba` repository
- Familiarity with GitHub Projects v2 interface
- GitHub account with appropriate permissions

---

## Step 1: Create the Project

1. Navigate to https://github.com/anokye-labs/akwaaba
2. Click the **Projects** tab in the repository navigation
3. Click **Link a project** → **New project**
4. Choose **Table** as the starting layout
5. Name the project: **Akwaaba Development**
6. Add description: "Work tracking and visualization for the Akwaaba agent-first repository"
7. Click **Create project**

---

## Step 2: Configure Custom Fields

Navigate to Project Settings (⚙️ icon) → **Fields**

### Add Status Field

- Field name: `Status`
- Field type: **Single select**
- Options (in order):
  - `Backlog` (color: gray)
  - `Ready` (color: yellow)
  - `In Progress` (color: blue)
  - `In Review` (color: purple)
  - `Done` (color: green)
  - `Blocked` (color: red)

### Add Priority Field

- Field name: `Priority`
- Field type: **Single select**
- Options (in order):
  - `Critical` (color: red)
  - `High` (color: orange)
  - `Medium` (color: yellow)
  - `Low` (color: green)

### Add Effort Field

- Field name: `Effort`
- Field type: **Single select**
- Options (in order):
  - `XS` (Extra Small - < 1 hour)
  - `S` (Small - 1-4 hours)
  - `M` (Medium - 1-2 days)
  - `L` (Large - 3-5 days)
  - `XL` (Extra Large - > 1 week)

### Add Phase Field

- Field name: `Phase`
- Field type: **Single select**
- Options (in order):
  - `1-Foundation`
  - `2-Governance`
  - `3-Agents`
  - `4-DotNet`
  - `5-Documentation`
  - `6-Validation`

### Add Type Field

- Field name: `Type`
- Field type: **Single select**
- Options (in order):
  - `Epic`
  - `Feature`
  - `Task`
  - `Bug`

**Note:** This mirrors GitHub issue types for filtering purposes.

### Add Agent Owner Field

- Field name: `Agent Owner`
- Field type: **Text**
- Use to track which agent is assigned to the work

### Add Blocks Field

- Field name: `Blocks`
- Field type: **Text**
- Use to list issue numbers this item blocks (e.g., "#45, #67")

### Add Blocked By Field

- Field name: `Blocked By`
- Field type: **Text**
- Use to list issue numbers blocking this item (e.g., "#12, #34")

---

## Step 3: Create Project Views

### View 1: Backlog

1. Click **+ New view** → **Table**
2. Name: `Backlog`
3. Add filter: `status:Backlog,Ready`
4. Sort by: `Priority` (descending), then `created` (oldest first)
5. Show columns: Title, Status, Priority, Effort, Phase, Type
6. Save view

### View 2: Current Sprint

1. Click **+ New view** → **Table**
2. Name: `Current Sprint`
3. Add filter: `status:"In Progress","In Review"`
4. Sort by: `Priority` (descending)
5. Group by: `Agent Owner`
6. Show columns: Title, Status, Priority, Type, Assignees
7. Save view

### View 3: By Phase

1. Click **+ New view** → **Table**
2. Name: `By Phase`
3. Add filter: `status:!Done` (exclude completed items)
4. Group by: `Phase`
5. Sort by: `Priority` (descending)
6. Show columns: Title, Status, Priority, Type, Effort
7. Save view

### View 4: By Type

1. Click **+ New view** → **Table**
2. Name: `By Type`
3. Add filter: `status:!Done`
4. Group by: `Type`
5. Sort by: `created` (oldest first)
6. Show columns: Title, Status, Priority, Sub-issues
7. Save view

### View 5: Blocked

1. Click **+ New view** → **Table**
2. Name: `Blocked`
3. Add filter: `status:Blocked` OR add custom filter for "Blocked By" field containing text
4. Sort by: `Priority` (descending)
5. Show columns: Title, Status, Blocked By, Assignees, Labels
6. Save view

### View 6: Board (Optional)

1. Click **+ New view** → **Board**
2. Name: `Board`
3. Column field: `Status`
4. Show all status columns
5. Add filter: `status:!Done` (optional)
6. Save view

---

## Step 4: Configure Built-in Automation

Navigate to Project Settings → **Workflows**

### Workflow 1: Auto-add to project

- Trigger: **Item added to repository**
- Action: **Add to project**
- Configuration:
  - When: `issues`, `pull_requests`
  - Add to: `this project`
  - Set Status: `Backlog`

### Workflow 2: Auto-set In Progress

- Trigger: **Item assigned**
- Action: **Set field value**
- Configuration:
  - When: `issue` is assigned
  - Set: `Status` to `In Progress`

### Workflow 3: Auto-set In Review

- Trigger: **Pull request linked**
- Action: **Set field value**
- Configuration:
  - When: Pull request linked to issue
  - Set: `Status` to `In Review`

### Workflow 4: Auto-set Done

- Trigger: **Item closed**
- Action: **Set field value**
- Configuration:
  - When: `issue` or `pull_request` is closed
  - Set: `Status` to `Done`

### Workflow 5: Auto-set Blocked (Label-based)

- Trigger: **Item labeled**
- Action: **Set field value**
- Configuration:
  - When: label `blocked` is added
  - Set: `Status` to `Blocked`

---

## Step 5: Initial Data Population

### Add existing issues to the project

Option A: Manual bulk add
1. Go to the project
2. Click **+ Add item**
3. Search for and select issues to add
4. Issues will auto-populate with Status: Backlog

Option B: Use GraphQL (for bulk operations)
```powershell
# Get project ID
$query = @"
query {
  organization(login: "anokye-labs") {
    projectV2(number: 3) {
      id
    }
  }
}
"@

$projectId = (gh api graphql -f query="$query" | ConvertFrom-Json).data.organization.projectV2.id

# Add all open issues
$issues = gh issue list --repo anokye-labs/akwaaba --state open --json number,id --limit 1000 | ConvertFrom-Json

foreach ($issue in $issues) {
    $mutation = @"
mutation {
  addProjectV2ItemById(input: {
    projectId: "$projectId"
    contentId: "$($issue.id)"
  }) {
    item { id }
  }
}
"@
    gh api graphql -f query="$mutation" | Out-Null
    Start-Sleep -Milliseconds 500
}
```

---

## Step 6: Set Initial Field Values

For key issues, manually set:
- **Priority** — Based on importance
- **Effort** — Based on estimated size
- **Phase** — Based on planning phase
- **Type** — Based on actual issue type

Or use GraphQL to set fields programmatically (see `.github/skills/okyerema/references/projects.md`).

---

## Step 7: Configure Project README

1. In Project Settings, find the **README** section
2. Add project description and usage guide:

```markdown
# Akwaaba Development Project

Work tracking and visualization for the Akwaaba agent-first repository.

## Views

- **Backlog** — Prioritized work ready to start
- **Current Sprint** — Active work in progress
- **By Phase** — Work organized by project phases (1-6)
- **By Type** — Hierarchy view (Epics/Features/Tasks/Bugs)
- **Blocked** — Issues requiring attention

## Custom Fields

- **Status** — Current stage (Backlog → In Progress → Done)
- **Priority** — Importance (Critical/High/Medium/Low)
- **Effort** — Size estimate (XS/S/M/L/XL)
- **Phase** — Project phase (1-6)
- **Type** — Issue type (Epic/Feature/Task/Bug)
- **Agent Owner** — Assigned agent
- **Blocks/Blocked By** — Dependencies

## Documentation

See [GitHub Projects Guide](https://github.com/anokye-labs/akwaaba/blob/main/docs/github-projects.md) for complete usage instructions.
```

---

## Step 8: Link Project to Repository

1. In the repository, add project link to README (already done)
2. Pin the project to repository for easy access:
   - Go to Project Settings
   - Enable "Pin to repository"

---

## Step 9: Test Automation

Create a test issue to verify automation:

```bash
gh issue create \
  --repo anokye-labs/akwaaba \
  --title "Test: Project Automation" \
  --body "This is a test issue to verify project automation works correctly."
```

Verify:
- [ ] Issue auto-added to project
- [ ] Status set to "Backlog"
- [ ] Visible in Backlog view

Assign the issue:
```bash
gh issue edit <issue-number> --add-assignee @copilot
```

Verify:
- [ ] Status changed to "In Progress"
- [ ] Issue appears in Current Sprint view

Close the issue:
```bash
gh issue close <issue-number>
```

Verify:
- [ ] Status changed to "Done"
- [ ] Issue removed from active views (filtered out)

Clean up:
```bash
gh issue delete <issue-number>
```

---

## Step 10: Share with Team

1. Share project URL with team
2. Document project usage in team onboarding
3. Add project link to relevant documentation
4. Consider creating a quick reference card

---

## Maintenance

### Weekly

- Review "Blocked" view and resolve blockers
- Check "Current Sprint" for stale assignments
- Verify field values are up-to-date

### Monthly

- Review automation effectiveness
- Update views based on feedback
- Archive old completed work (optional)

### As Needed

- Add new custom fields for evolving needs
- Create new views for specific queries
- Update documentation with lessons learned

---

## Troubleshooting

### Issue not appearing in project

**Problem:** Created an issue but it's not in the project  
**Solution:** Check if auto-add workflow is enabled; manually add if needed

### Status not updating

**Problem:** Assigned an issue but status didn't change to "In Progress"  
**Solution:** Check workflow configuration; verify trigger conditions are met

### Can't update custom fields via CLI

**Problem:** `gh` commands fail to update project fields  
**Solution:** GitHub CLI has limited project support; use GraphQL instead

### Type field doesn't match issue type

**Problem:** Issue type changed but Project Type field is stale  
**Solution:** Type field must be updated manually or via GraphQL workflow

---

## Next Steps

After completing this setup:

1. Review the [GitHub Projects Guide](../docs/github-projects.md) for usage patterns
2. Check [ADR-0004](../docs/adr/ADR-0004-use-github-projects-for-visualization.md) for architectural decisions
3. Explore [Okyerema Projects Reference](../.github/skills/okyerema/references/projects.md) for GraphQL examples
4. Consider enhancing automation with custom GitHub Actions

---

*This guide is maintained as part of the Akwaaba repository documentation. For questions or improvements, please open an issue.*
