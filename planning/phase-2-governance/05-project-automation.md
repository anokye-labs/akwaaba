# Feature: Setup GitHub Project Automation

**ID:** project-automation  
**Phase:** 2 - Governance  
**Status:** Pending  
**Dependencies:** issue-templates

## Overview

Configure a GitHub Project board with automation rules that provide visualization and workflow management for the entire repository lifecycle.

## Tasks

### Task 1: Create GitHub Project
- [ ] Navigate to organization projects or repo projects
- [ ] Create new project named "Akwaaba Development"
- [ ] Choose table layout initially
- [ ] Set project description and README

### Task 2: Configure project views
- [ ] Create "Backlog" view (all open issues, sorted by priority)
- [ ] Create "Current Sprint" view (issues in progress)
- [ ] Create "By Phase" view (grouped by phase labels)
- [ ] Create "By Type" view (grouped by issue type: Epic/Feature/Task)
- [ ] Create "Blocked" view (issues with blocked status)

### Task 3: Define custom fields
- [ ] Add "Status" field (Backlog, Ready, In Progress, In Review, Done, Blocked)
- [ ] Add "Priority" field (Critical, High, Medium, Low)
- [ ] Add "Effort" field (XS, S, M, L, XL)
- [ ] Add "Phase" field (1-6)
- [ ] Add "Agent Owner" field (dropdown of agent names)

### Task 4: Set up status automation
- [ ] Auto-add issues to project when created
- [ ] Set status to "Backlog" when added
- [ ] Set status to "In Progress" when issue assigned
- [ ] Set status to "In Review" when PR linked
- [ ] Set status to "Done" when issue closed

### Task 5: Configure PR linking automation
- [ ] Auto-link PRs to related issues
- [ ] Update issue status when PR opened
- [ ] Update issue status when PR merged
- [ ] Close issue automatically when PR merged (if "Closes #" in description)

### Task 6: Set up hierarchy visualization
- [ ] Configure Epic → Feature relationships
- [ ] Configure Feature → Task relationships
- [ ] Enable parent/child visualization
- [ ] Add progress tracking (% of children complete)

### Task 7: Create workflow automation rules
- [ ] When issue labeled "ready-to-implement" → move to "Ready"
- [ ] When issue labeled "blocked" → move to "Blocked" view
- [ ] When issue labeled "high-priority" → set Priority field
- [ ] When Epic closed → check all children are closed

### Task 8: Configure notifications
- [ ] Notify when Epic completed
- [ ] Alert when issue blocked
- [ ] Summary of completed work (weekly)
- [ ] Configure Slack integration (optional)

### Task 9: Create project documentation
- [ ] Document project views and their purpose
- [ ] Explain custom fields and how to use them
- [ ] Describe automation rules
- [ ] Add screenshots to docs

### Task 10: Export project configuration
- [ ] Document project setup steps
- [ ] Export automation rules as YAML (if possible)
- [ ] Save to `.github/project.yml` or document manually
- [ ] Create replication guide

### Task 11: Test project automation
- [ ] Create test issue and watch it auto-add
- [ ] Move through workflow stages
- [ ] Link test PR and verify status changes
- [ ] Test hierarchy views
- [ ] Close test items

### Task 12: Finalize
- [ ] Link project in README
- [ ] Update GOVERNANCE.md with project workflow
- [ ] Add project badges to README
- [ ] Commit any exportable configurations

## Acceptance Criteria

- GitHub Project exists and is linked to repository
- Multiple views provide different perspectives
- Custom fields enable rich metadata
- Automation rules reduce manual work
- Issue hierarchy is visualized
- Status updates are automated
- Documentation explains project usage
- Team can navigate project effectively

## Notes

- GitHub Projects (new) has better automation than Projects Classic
- Consider creating saved filters for common queries
- Project automation complements, not replaces, workflow automation
- Train team on project usage before rolling out
- Consider creating project templates for future repos
