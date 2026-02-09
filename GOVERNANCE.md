# Governance

This document defines how work is structured, coordinated, and tracked in Akwaaba repositories. It covers issue templates, hierarchies, workflows, and best practices that keep both humans and AI agents working in rhythm.

---

## Table of Contents

1. [Issue Templates](#issue-templates)
2. [When to Use Each Template](#when-to-use-each-template)
3. [Issue Hierarchy](#issue-hierarchy)
4. [Examples of Good Issues](#examples-of-good-issues)
5. [FAQ](#faq)

---

## Issue Templates

Akwaaba uses five standardized issue templates to structure work. Each template is purpose-built for a specific type of work and contains the fields necessary to properly track and coordinate that work.

### Available Templates

| Template | Purpose | Primary Fields |
|----------|---------|----------------|
| **Epic** | Large initiatives spanning multiple features | Phase, success criteria, description |
| **Feature** | Cohesive functionality grouping related tasks | Parent Epic, tasks checklist, dependencies |
| **Task** | Specific, completable work items | Parent Feature, acceptance criteria, effort estimate |
| **Bug** | Defects or broken functionality | Severity, steps to reproduce, environment |
| **Agent Request** | Proposals for new AI agents | Agent name, purpose, behavior, triggers |

**Important:** These templates use GitHub's **organization-level issue types**, not labels or title prefixes. Issue types are set via GraphQL API, not through labels.

---

## When to Use Each Template

### Epic

**Use Epic when:**
- You're planning a major phase of work (e.g., "Phase 2 - Governance")
- The work will take weeks or months to complete
- Multiple people or agents will work on different parts
- You need to coordinate multiple features into a cohesive whole

**Don't use Epic when:**
- The work is a single, isolated deliverable (use Feature or Task)
- You're fixing a single bug (use Bug)
- The scope is less than a week of work (use Feature or Task)

**Example Epic titles:**
- "Phase 2: Governance Implementation"
- "Complete Security Audit and Remediation"
- "Migration to New Authentication System"

---

### Feature

**Use Feature when:**
- You're building a cohesive piece of functionality that requires multiple tasks
- The work has natural groupings that belong together
- You want to track progress on a deliverable that's part of a larger Epic
- You have 3-10 related tasks that accomplish a single goal

**Don't use Feature when:**
- You have a single task (just create a Task)
- The work doesn't fit into an Epic (make it a standalone Task)
- Tasks aren't related to each other (create separate Tasks)

**Example Feature titles:**
- "Create Issue Templates"
- "Implement Branch Protection Rules"
- "Build Agent Authentication System"

---

### Task

**Use Task when:**
- You have a specific, completable work item
- Someone (human or agent) can complete it in a single session
- The acceptance criteria are clear and testable
- It's a concrete action, not a vague intention

**Don't use Task when:**
- The work is too vague ("Improve documentation" → needs breakdown)
- It's actually multiple tasks bundled together (split them)
- It's reporting a bug (use Bug template)

**Example Task titles:**
- "Create Epic template YAML file"
- "Add branch protection documentation to GOVERNANCE.md"
- "Implement GetIssueTypeIds PowerShell script"

---

### Bug

**Use Bug when:**
- Something is broken or not working as expected
- You can provide steps to reproduce the problem
- There's a clear difference between expected and actual behavior
- The issue is about fixing existing functionality, not adding new features

**Don't use Bug when:**
- You're requesting a new feature (use Feature or Task)
- Something is missing but was never implemented (use Task)
- You're reporting a design issue (use Task to redesign)

**Example Bug titles:**
- "Commit validation fails for valid GitHub App commits"
- "Sub-issues API returns 404 without proper header"
- "PowerShell script encoding breaks non-ASCII characters"

---

### Agent Request

**Use Agent Request when:**
- You're proposing a new AI agent for the repository
- You want to document the purpose and behavior of an agent
- You need approval to add an agent to the approved-agents.json list
- You're designing agent automation for a specific workflow

**Don't use Agent Request when:**
- You're reporting a bug in an existing agent (use Bug)
- You're improving agent behavior (use Task)
- You're updating agent documentation (use Task)

**Example Agent Request titles:**
- "Agent: Code Review Assistant for Pull Requests"
- "Agent: Automated Issue Triage and Labeling"
- "Agent: Security Vulnerability Scanner"

---

## Issue Hierarchy

Akwaaba uses a three-level hierarchy to organize work: **Epic → Feature → Task**. This hierarchy is implemented using GitHub's **sub-issues API**, not labels or markdown checklists.

### Three-Level Hierarchy (Epic → Feature → Task)

Use the full three-level hierarchy when you have a large initiative with natural groupings:

```
Epic: Phase 2 - Integration
├─ Feature: Core Skill Creation
│  ├─ Task: Analyze existing scripts
│  ├─ Task: Create SKILL.md
│  └─ Task: Add GraphQL examples
├─ Feature: Script Conversion (8 tasks)
│  ├─ Task: Convert Get-IssueTypeIds.ps1
│  ├─ Task: Convert Create-Issue.ps1
│  └─ ... (6 more tasks)
├─ Feature: Reference Documentation (7 tasks)
└─ Feature: Testing & Validation (2 tasks)
```

**When to use three levels:**
- Epic has 10+ tasks that fall into clear categories
- Features represent distinct deliverables
- Multiple people might work on different features in parallel
- You want to track progress at the feature level

### Two-Level Hierarchy (Epic → Task)

Use the two-level hierarchy when tasks are standalone and don't need intermediate grouping:

```
Epic: Phase 0 - Setup
├─ Task: Initialize repository
├─ Task: Create directory structure
├─ Task: Write .gitignore
└─ Task: Set up CI/CD workflows
```

**When to use two levels:**
- Tasks are independent of each other
- No natural groupings exist
- The phase is simple (setup, config, cleanup)
- You have fewer than 10 tasks total

### Creating Relationships

Relationships are created using GraphQL's `createIssueRelationship` mutation:

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

**Important:** Sub-issues API requires the `GraphQL-Features: sub_issues` header.

For detailed examples and helper scripts, see:
- [Okyerema Skill Reference](.github/skills/okyerema/SKILL.md)
- [Relationships Guide](.github/skills/okyerema/references/relationships.md)

---

## Examples of Good Issues

### Good Epic Example

**Title:** Phase 2: Governance Implementation

**Description:**
```
Implement comprehensive governance structure for the Akwaaba repository, including
issue templates, branch protection, commit validation, and agent authentication.

## Success Criteria
- [ ] Issue templates exist for all types (Epic, Feature, Task, Bug, Agent Request)
- [ ] Branch protection rules enforce pull request workflow
- [ ] Commit validation prevents unauthorized direct commits
- [ ] Agent authentication system verifies approved agents
- [ ] Documentation explains all governance processes

## Phase
Phase 2 - Governance

## Timeline
4-6 weeks

## Dependencies
- Completed Phase 1 (Repository Foundation)
```

**Why this is good:**
- Clear, specific success criteria
- Appropriate scope for an Epic
- Identifies dependencies
- Provides timeline context

---

### Good Feature Example

**Title:** Create Issue Templates

**Description:**
```
Build comprehensive YAML issue templates that structure how work is proposed,
categorized, and tracked.

## Parent Epic
#14 - Phase 2: Governance Implementation

## Tasks
- [ ] Create Epic template
- [ ] Create Feature template
- [ ] Create Task template
- [ ] Create Bug template
- [ ] Create Agent Request template
- [ ] Configure template chooser
- [ ] Add template validation
- [ ] Create template documentation
- [ ] Test all templates
- [ ] Finalize and commit

## Dependencies
None - this is foundational work

## Acceptance Criteria
- All 5 templates exist as YAML files
- Required fields are enforced
- Labels auto-apply correctly
- Templates render correctly on GitHub
- Documentation explains usage
```

**Why this is good:**
- Links to parent Epic
- Clear task breakdown
- Specific acceptance criteria
- Identifies dependencies (or lack thereof)

---

### Good Task Example

**Title:** Create template documentation in GOVERNANCE.md

**Description:**
```
Document in GOVERNANCE.md when to use each template, explain Epic > Feature > Task
hierarchy, provide examples of good issues, and add FAQ.

## Parent Feature
#85 - Create Issue Templates

## Acceptance Criteria
- GOVERNANCE.md contains section on issue templates
- Each template has "when to use" guidance
- Hierarchy is explained with examples
- At least 3 example issues are provided (Epic, Feature, Task)
- FAQ section answers common questions

## Effort Estimate
Medium (2-4 hours)
```

**Why this is good:**
- Links to parent Feature
- Specific, measurable acceptance criteria
- Realistic effort estimate
- Clear scope (won't drift)

---

### Good Bug Example

**Title:** Commit validation fails for valid GitHub App commits

**Description:**
```
## Severity
High - Blocks approved agents from committing

## Description
The commit validation workflow is rejecting commits from approved GitHub Apps,
even when they're correctly configured in approved-agents.json.

## Steps to Reproduce
1. Configure GitHub App in approved-agents.json with correct githubAppId
2. Have GitHub App create a commit
3. Observe commit validation workflow fail

## Expected Behavior
Commits from approved GitHub Apps should pass validation when they're in the
approved-agents.json allowlist.

## Actual Behavior
Validation fails with error: "Commit author not found in approved agents list"

## Environment
- Repository: anokye-labs/akwaaba
- Workflow: .github/workflows/validate-commits.yml
- PowerShell version: 7.4

## Additional Context
The issue appears to be in how we're detecting the [bot] suffix in usernames.
```

**Why this is good:**
- Clear severity assessment
- Reproducible steps
- Expected vs. actual behavior clearly stated
- Environment details provided
- Hypothesis included

---

### Good Agent Request Example

**Title:** Agent: Automated Issue Triage

**Description:**
```
## Agent Name
Issue Triage Agent

## Purpose / Problem
New issues often sit unassigned and uncategorized for hours. We need automated
triage to:
- Validate issue templates are used correctly
- Suggest labels based on content
- Assign to appropriate team members
- Link related issues

## Proposed Behavior
When a new issue is created:
1. Check that a template was used (not blank issue)
2. Analyze issue body for keywords → suggest labels
3. Check for parent Epic/Feature references → create relationships
4. Identify potential assignees based on content
5. Comment with suggestions for human to approve

## Trigger Conditions
- On issue opened
- On issue edited (if initially blank)

## Output / Actions
- Add comment with suggestions
- Optionally auto-add obvious labels (e.g., "documentation")
- Create relationship if parent is referenced

## Permissions Needed
- Read issues
- Write comments
- Add labels
- Create issue relationships

## Success Criteria
- 80% of new issues get triaged within 5 minutes
- False positive rate < 10%
- Human can easily approve/reject suggestions
```

**Why this is good:**
- Clear problem statement
- Specific behavior defined
- Triggers and outputs documented
- Permissions identified
- Success criteria measurable

---

## FAQ

### General Questions

**Q: Do I need to create an Epic for every piece of work?**

A: No. Epics are for large initiatives. For standalone work, create a Task directly. For a group of related tasks, create a Feature without an Epic.

---

**Q: How do I know if something should be a Feature or just multiple Tasks?**

A: Ask yourself: "Do these tasks accomplish a single, cohesive deliverable?" If yes, use a Feature. If they're independent work items, create separate Tasks.

---

**Q: Can I create a Task without a parent Feature or Epic?**

A: Yes! Standalone Tasks are perfectly fine for bug fixes, small improvements, or maintenance work that doesn't fit into a larger initiative.

---

**Q: What if I'm not sure which template to use?**

A: Start with the Task template. It's the most flexible. You can always convert it to a Feature or link it to an Epic later.

---

### Issue Types

**Q: Why can't I use labels like "epic" or "task"?**

A: We use GitHub's organization-level issue types, not labels. Labels are for categorization (e.g., "documentation", "security"), not structure. Issue types are the proper mechanism for defining what kind of work an issue represents.

---

**Q: How do I set an issue type?**

A: Issue types are set using GitHub's GraphQL API. See the [Issue Types Reference](.github/skills/okyerema/references/issue-types.md) for examples. The `gh` CLI doesn't support issue types yet.

---

**Q: Can I change an issue's type after creation?**

A: Yes, use the `updateIssue` GraphQL mutation with the new `issueTypeId`. See the [Issue Types Reference](.github/skills/okyerema/references/issue-types.md) for examples.

---

### Hierarchy and Relationships

**Q: How do I link a Task to its parent Feature?**

A: Use the `createIssueRelationship` GraphQL mutation with the parent and child issue IDs. Remember to include the `GraphQL-Features: sub_issues` header. See [Relationships Guide](.github/skills/okyerema/references/relationships.md).

---

**Q: Can a Task have multiple parents?**

A: No. GitHub's sub-issues API supports a single parent per issue. If work spans multiple features, it might actually be a Feature itself, or you should break it into separate Tasks.

---

**Q: What's the difference between sub-issues and tasklists?**

A: Sub-issues use GitHub's sub-issues API (preview feature) to create proper parent-child relationships. Tasklists are markdown checkboxes in issue bodies. We use sub-issues because they're immediate, reliable, and have proper API support. See [ADR-0001](docs/adr/ADR-0001-use-sub-issues-for-hierarchy.md) for details.

---

**Q: How do I represent blocking relationships?**

A: GitHub doesn't have native "blocks/blocked by" relationships. Document blocks in the issue body with "**Blocked by:** #7" and use Project custom fields if needed.

---

### Templates

**Q: Can I submit an issue without using a template?**

A: Blank issues are disabled in this repository. You must use one of the provided templates. This ensures consistency and helps both humans and agents understand the work.

---

**Q: What if none of the templates fit my needs?**

A: The templates cover 95% of cases. If you genuinely need something else, create a Task that describes what you need, and we'll evaluate whether a new template is warranted.

---

**Q: Can I modify a template after creating an issue?**

A: Yes, you can edit the issue body after creation. However, required fields should remain populated so the issue stays useful for tracking and coordination.

---

### Workflow

**Q: Who assigns issues?**

A: Issues can be self-assigned by humans or assigned to AI agents (like @copilot). Use `gh issue edit NUMBER --add-assignee "@copilot"` to assign to the Copilot agent (note the @ prefix is required).

---

**Q: How do I track progress on an Epic?**

A: Use GitHub Projects to visualize Epic progress. All sub-issues (Features and Tasks) will show up in the Epic's sub-issues section on GitHub. You can also query progress using GraphQL.

---

**Q: Can I close an Epic if it still has open Tasks?**

A: Technically yes, but you shouldn't. Epics should only close when all their Features and Tasks are complete. Check the sub-issues section before closing.

---

**Q: What happens if I create the wrong type of issue?**

A: Use the `updateIssue` GraphQL mutation to change the issue type. See [Issue Types Reference](.github/skills/okyerema/references/issue-types.md).

---

### Labels

**Q: When should I use labels?**

A: Use labels for categorization only:
- ✅ Technology: `powershell`, `typescript`, `graphql`
- ✅ Category: `documentation`, `security`, `performance`
- ✅ Special flags: `good-first-issue`, `breaking-change`
- ❌ Structure: `epic`, `task`, `in-progress`, `blocked`

---

**Q: Why are structural labels bad?**

A: They duplicate what issue types and relationships already do, leading to inconsistency. If a label represents structure, you're using the wrong tool. Use issue types and sub-issues instead.

---

### For AI Agents

**Q: How should agents create and manage issues?**

A: Agents should read the [Okyerema Skill](.github/skills/okyerema/SKILL.md) for comprehensive guidance. Key points:
- Always use GraphQL for issue types and relationships
- Set issue types at creation when possible
- Use sub-issues API for hierarchy
- Follow agent behavioral conventions
- Verify operations succeed

---

**Q: Can agents close issues automatically?**

A: Yes, when the work is complete and verified. Agents should comment on the issue explaining what was done before closing it.

---

**Q: Should agents create epics?**

A: Generally no. Epics represent strategic planning that humans should define. Agents execute Features and Tasks within Epics.

---

## Additional Resources

### Documentation
- [How We Work](./how-we-work.md) — Overview of coordination system
- [Our Way](./how-we-work/our-way.md) — Philosophy and practices
- [Getting Started](./how-we-work/getting-started.md) — New to GitHub Issues?
- [Glossary](./how-we-work/glossary.md) — Akan terms and concepts

### For AI Agents
- [Okyerema Skill](.github/skills/okyerema/SKILL.md) — Agent orchestration skill
- [Issue Types Reference](.github/skills/okyerema/references/issue-types.md)
- [Relationships Guide](.github/skills/okyerema/references/relationships.md)
- [Agent Conventions](./how-we-work/agent-conventions.md)

### Architecture Decisions
- [ADR-0001: Use Sub-Issues API for Hierarchy](docs/adr/ADR-0001-use-sub-issues-for-hierarchy.md)

---

**The Okyerema keeps us in rhythm. Medaase (Thank you) for following the beat.**
