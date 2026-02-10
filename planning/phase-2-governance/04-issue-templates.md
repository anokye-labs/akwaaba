# Feature: Create Issue Templates

**ID:** issue-templates  
**Phase:** 2 - Governance  
**Status:** ~~Pending~~ **Superseded by ADR-0003**  
**Dependencies:** repo-init

> **⚠️ IMPORTANT:** This planning document proposed using GitHub issue templates with auto-applying labels.
> However, **[ADR-0003: Use Organization-Level Issue Types](../../docs/adr/ADR-0003-use-org-level-issue-types.md)** decided to use organization-level issue types instead.
> 
> The testing requirements from **Task 9** have been implemented using organization-level issue types.
> See [docs/testing-issue-types.md](../../docs/testing-issue-types.md) and `scripts/Test-IssueTypes.ps1` for the current implementation.

## Overview

~~Build comprehensive YAML issue templates that structure how work is proposed, categorized, and tracked.~~

**Current Implementation:** We use GitHub organization-level issue types (Epic, Feature, Task, Bug) rather than issue templates. See ADR-0003 for rationale.

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

~~- 5 templates exist (Epic, Feature, Task, Bug, Agent Request)~~
~~- All templates use YAML schema~~
~~- Required fields are enforced~~
~~- Labels auto-apply correctly~~
~~- Templates guide users to provide needed information~~
- Hierarchy (Epic → Feature → Task) is clear
- Documentation explains usage
~~- Templates render correctly on GitHub~~

## What Was Actually Implemented

Instead of issue templates, we implemented organization-level issue types per ADR-0003:

### Implemented Features

✅ **Organization-Level Issue Types**:
- Epic, Feature, Task, and Bug types configured at organization level
- Types set via GraphQL API during issue creation
- Types are first-class metadata, not labels

✅ **Hierarchy Support**:
- Sub-issues API for parent-child relationships
- Epic → Feature → Task hierarchy pattern
- GraphQL queries for relationship traversal

✅ **Testing Infrastructure** (Task 9 equivalent):
- `scripts/Test-IssueTypes.ps1` — Comprehensive test script
- `docs/testing-issue-types.md` — Testing documentation
- `docs/issue-types-vs-templates.md` — Clarification document
- Creates test Epic, Feature, Task, and Bug issues
- Verifies types and hierarchical relationships
- Provides cleanup functionality

✅ **Documentation**:
- [ADR-0003: Use Organization-Level Issue Types](../../docs/adr/ADR-0003-use-org-level-issue-types.md)
- [Testing Issue Types](../../docs/testing-issue-types.md)
- [Issue Types vs Templates](../../docs/issue-types-vs-templates.md)
- [How We Work](../../how-we-work.md)
- [Okyerema Skill](../../.github/skills/okyerema/SKILL.md)

### Key Differences from Original Plan

| Original Plan | Actual Implementation |
|--------------|----------------------|
| Issue templates in `.github/ISSUE_TEMPLATE/` | Organization-level issue types |
| Auto-applying labels | No structural labels (types are native) |
| 5 templates (including Agent Request) | 4 org-level types (Epic, Feature, Task, Bug) |
| YAML schema validation | GraphQL API with required type IDs |
| Template rendering in UI | Native GitHub type selection |

### Why the Change?

See [ADR-0003](../../docs/adr/ADR-0003-use-org-level-issue-types.md) for full rationale:
- Issue types are first-class GitHub features
- Better UI/API integration
- No label pollution
- Consistent across all org repositories
- Works seamlessly with sub-issues API and Projects

## Notes

- YAML templates are more structured than Markdown
- Use validation to guide users, not frustrate them
- Provide examples in placeholders
- Keep templates concise - users won't fill out huge forms
- Consider adding issue templates for: documentation, question, etc.
