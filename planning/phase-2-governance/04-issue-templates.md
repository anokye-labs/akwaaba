# Feature: Create Issue Templates

**ID:** issue-templates  
**Phase:** 2 - Governance  
**Status:** Pending  
**Dependencies:** repo-init

## Overview

Build comprehensive YAML issue templates that structure how work is proposed, categorized, and tracked.

## Tasks

### Task 1: Create Epic template
- [ ] Create `.github/ISSUE_TEMPLATE/epic.yml`
- [ ] Add name: "Epic"
- [ ] Add description explaining Epic purpose
- [ ] Add title field with prefix "[EPIC]"
- [ ] Add project phase dropdown
- [ ] Add description textarea (large, required)
- [ ] Add success criteria textarea
- [ ] Add labels: `epic`, phase label
- [ ] Add automatic project assignment

### Task 2: Create Feature template
- [ ] Create `.github/ISSUE_TEMPLATE/feature.yml`
- [ ] Add name: "Feature"
- [ ] Add parent Epic reference (input field with validation)
- [ ] Add feature title and description
- [ ] Add tasks checklist field
- [ ] Add dependencies field
- [ ] Add labels: `feature`, phase label
- [ ] Add project assignment

### Task 3: Create Task template
- [ ] Create `.github/ISSUE_TEMPLATE/task.yml`
- [ ] Add name: "Task"
- [ ] Add parent Feature reference
- [ ] Add task description
- [ ] Add acceptance criteria
- [ ] Add estimated effort dropdown (S/M/L)
- [ ] Add labels: `task`, phase label
- [ ] Add assignee field (optional)

### Task 4: Create Bug template
- [ ] Create `.github/ISSUE_TEMPLATE/bug.yml`
- [ ] Add severity dropdown (Critical/High/Medium/Low)
- [ ] Add "Steps to reproduce" section
- [ ] Add "Expected behavior" section
- [ ] Add "Actual behavior" section
- [ ] Add environment info (OS, .NET version, etc.)
- [ ] Add labels: `bug`, severity label
- [ ] Add priority field

### Task 5: Create Agent Request template
- [ ] Create `.github/ISSUE_TEMPLATE/agent-request.yml`
- [ ] Add agent name field
- [ ] Add purpose/problem statement
- [ ] Add proposed behavior description
- [ ] Add trigger conditions
- [ ] Add output/action descriptions
- [ ] Add labels: `agent-request`, `enhancement`
- [ ] Add template checklist for research

### Task 6: Configure template chooser
- [ ] Create `.github/ISSUE_TEMPLATE/config.yml`
- [ ] Set blank issues to disabled
- [ ] Add helpful description for template chooser
- [ ] Add external links (documentation, discussions)
- [ ] Customize contact links

### Task 7: Add template validation
- [ ] Research GitHub issue form schema validation
- [ ] Add regex patterns where appropriate
- [ ] Add placeholder text with examples
- [ ] Make required fields mandatory
- [ ] Add helpful validation messages

### Task 8: Create template documentation
- [ ] Document in GOVERNANCE.md: when to use each template
- [ ] Explain Epic → Feature → Task hierarchy
- [ ] Provide examples of good issues
- [ ] Add FAQ for common questions

### Task 9: Test templates
- [ ] Create test Epic issue
- [ ] Create test Feature linked to Epic
- [ ] Create test Task linked to Feature
- [ ] Create test Bug with all fields
- [ ] Create test Agent Request
- [ ] Verify labels auto-apply correctly
- [ ] Delete or close test issues

### Task 10: Finalize and commit
- [ ] Review all templates for consistency
- [ ] Ensure accessibility (screen readers)
- [ ] Check mobile rendering
- [ ] Commit: "feat(governance): Add comprehensive issue templates"

## Acceptance Criteria

- 5 templates exist (Epic, Feature, Task, Bug, Agent Request)
- All templates use YAML schema
- Required fields are enforced
- Labels auto-apply correctly
- Templates guide users to provide needed information
- Hierarchy (Epic → Feature → Task) is clear
- Documentation explains usage
- Templates render correctly on GitHub

## Notes

- YAML templates are more structured than Markdown
- Use validation to guide users, not frustrate them
- Provide examples in placeholders
- Keep templates concise - users won't fill out huge forms
- Consider adding issue templates for: documentation, question, etc.
