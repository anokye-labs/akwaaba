# Governance: The Anokye-Krom System

This document describes the governance model for Anokye Labs repositories, built on the **Anokye-Krom System** — where humans create the vision through issues, and AI agents execute the work.

## Table of Contents

- [Overview](#overview)
- [Issue Templates](#issue-templates)
- [Issue Hierarchy](#issue-hierarchy)
- [When to Use Each Template](#when-to-use-each-template)
- [Creating Issues](#creating-issues)
- [Working with Agents](#working-with-agents)
- [Examples](#examples)
- [FAQ](#faq)

## Overview

The Anokye-Krom System is built on three core principles:

1. **Issue-First Workflow** — All work begins with a GitHub issue
2. **Agent-Only Commits** — AI agents make all code changes
3. **Human Oversight** — Humans review, approve, and merge

This ensures:
- Complete traceability of all changes
- Clear documentation of "why" behind every commit
- Consistent, auditable development process
- Effective collaboration between humans and AI

## Issue Templates

We provide five issue templates to structure different types of work:

| Template | Purpose | Use When |
|----------|---------|----------|
| **Epic** | Large initiative spanning multiple features | Planning a major phase or multi-week project |
| **Feature** | Cohesive functionality grouping related tasks | Creating a specific capability or system component |
| **Task** | Specific, completable work item | Defining concrete work that can be done in hours/days |
| **Bug** | Defect or unexpected behavior | Something is broken and needs fixing |
| **Agent Request** | Propose new AI agent | Need to add a new agent to the repository |

All templates use **YAML schema** with:
- Required fields enforcement
- Automatic label application
- Guided data entry
- Validation and placeholder examples

## Issue Hierarchy

Issues are organized in a **three-level hierarchy**:

```
Epic (Phase-level initiative)
└── Feature (Cohesive capability)
    └── Task (Specific work item)
```

### Hierarchy Rules

1. **Epics** contain Features (and sometimes Tasks directly)
2. **Features** contain Tasks
3. **Tasks** are leaves — they don't contain other issues
4. **Bugs** can exist at any level or independently

### When to Use Three Levels

Use **Epic → Feature → Task** when:
- Epic has 5+ tasks that fall into natural groupings
- Features represent distinct deliverables
- Multiple people/agents work on different features in parallel

Example:
```
Epic: Phase 2 - Governance
├── Feature: Branch Protection
│   ├── Task: Research GitHub rulesets API
│   ├── Task: Create ruleset JSON
│   └── Task: Test and document
├── Feature: Commit Validator
│   ├── Task: Write validation script
│   └── Task: Create GitHub workflow
└── Feature: Agent Authentication
    ├── Task: Define approved agents list
    └── Task: Implement validation workflow
```

### When to Use Two Levels

Use **Epic → Task** when:
- Tasks are independent and standalone
- No natural groupings exist
- The phase is simple (setup, config, cleanup)

Example:
```
Epic: Phase 0 - Setup
├── Task: Initialize repository
├── Task: Create directory structure
├── Task: Write .gitignore
└── Task: Create README
```

## When to Use Each Template

### Epic Template

**Use when:**
- Planning a major initiative (e.g., "Phase 2 - Governance")
- Coordinating 3+ Features or 10+ Tasks
- Work spans multiple weeks or months
- Multiple contributors will be involved

**Contains:**
- Project phase
- Goals and objectives
- Success criteria
- List of Features (added after creation)
- Dependencies and blockers

**Examples:**
- Phase 2 - Governance
- Q1 Platform Modernization
- Authentication System Overhaul
- Security Hardening Initiative

### Feature Template

**Use when:**
- Creating a cohesive piece of functionality
- Grouping 3-8 related tasks
- Building a specific capability or component
- Work takes 1-4 weeks

**Contains:**
- Parent Epic reference
- Description of the feature
- Breakdown of tasks needed
- Acceptance criteria
- Technical notes

**Examples:**
- Branch Protection Ruleset
- Commit Validator Workflow
- Agent Authentication System
- Issue Template Suite

### Task Template

**Use when:**
- Defining specific, actionable work
- Can be completed in hours to days
- Has clear completion criteria
- Can be assigned to a person or agent

**Contains:**
- Parent Feature or Epic reference
- Detailed description of the work
- Acceptance criteria (checklist)
- Estimated effort
- Technical and testing notes

**Examples:**
- Create epic.yml template
- Write unit tests for auth service
- Update README with installation instructions
- Implement GraphQL mutation for sub-issues

### Bug Template

**Use when:**
- Something is broken or doesn't work
- Behavior differs from documentation
- System throws errors or crashes
- **Not** for feature requests or questions

**Contains:**
- Severity and priority
- Steps to reproduce
- Expected vs actual behavior
- Environment details
- Logs and error messages

**Examples:**
- Agent authentication workflow fails with 404 error
- Commit validator rejects valid commit messages
- Template chooser doesn't display custom templates
- GraphQL mutation returns null unexpectedly

### Agent Request Template

**Use when:**
- Proposing a new AI agent
- Need additional automation capabilities
- Want to grant repository access to an agent
- **Not** for modifying existing agents

**Contains:**
- Agent identification (name, username, type)
- Purpose and capabilities
- Required permissions
- Security considerations
- Maintenance plan
- Testing and validation approach

**Examples:**
- Add GitHub Copilot as approved agent
- Register custom build automation agent
- Enable documentation auto-update agent

## Creating Issues

### Step 1: Choose the Right Template

Navigate to **Issues → New Issue** and select the appropriate template from the issue chooser.

### Step 2: Fill in Required Fields

All templates have required fields marked with an asterisk (*). Provide:
- Clear, descriptive titles
- Detailed descriptions
- Specific acceptance criteria
- Relevant context and dependencies

### Step 3: Establish Relationships

For Features and Tasks, reference the parent issue:
- Use issue numbers: `#10`, `#25`
- Create parent-child relationships after both issues exist
- Agents will use GraphQL to establish sub-issue relationships

### Step 4: Submit and Monitor

After creating the issue:
- Agents will automatically be notified
- An agent will be assigned (or self-assign)
- Track progress through issue comments and linked PRs
- Review and provide feedback as work progresses

## Working with Agents

### Agent Assignment

Agents can be assigned in two ways:

1. **Manual Assignment** — Assign a specific agent when creating the issue
   - Use GitHub's assignee feature
   - Mention the agent in the issue body: `@copilot`

2. **Automatic Assignment** — Leave unassigned and agents will self-assign
   - Agents monitor new issues
   - They select issues matching their capabilities
   - Assignment happens when agent starts work

### Agent Workflow

When an agent works on an issue, it will:

1. **Acknowledge** — Comment on the issue to indicate it's starting work
2. **Research** — Read documentation, explore codebase, understand requirements
3. **Implement** — Make code changes following best practices
4. **Test** — Validate changes meet acceptance criteria
5. **Create PR** — Submit pull request linking back to the issue
6. **Respond** — Address feedback and make requested changes
7. **Complete** — Close issue when PR is merged

### Providing Feedback

When reviewing agent work:

- **Be specific** — Point to exact lines or files
- **Explain why** — Help the agent learn your preferences
- **Use examples** — Show what you want, not just what's wrong
- **Iterate** — Agents improve through feedback loops

Example good feedback:
> The implementation looks good, but please move the validation logic to a separate function for better testability. See how we handle this in `src/validators.js` lines 45-60.

### Emergency Overrides

In rare cases, direct commits may be needed:
- Critical security fixes
- Production emergencies
- System failures preventing agent operation

See emergency bypass procedures in `.github/APPROVED-AGENTS.md`.

## Examples

### Example 1: Three-Level Hierarchy

Creating a governance system:

```
1. Create Epic: "Phase 2 - Governance"
   - Phase: Phase 2
   - Description: Implement branch protection, validation, and agent auth
   - Success criteria: All governance features implemented and documented

2. Create Feature: "Branch Protection Ruleset"
   - Parent: #1 (Phase 2 Epic)
   - Description: Protect main branch with GitHub rulesets
   - Tasks: Research API, create config, test, document

3. Create Tasks under Feature:
   - Task: "Research GitHub rulesets API" (Parent: #2)
   - Task: "Create ruleset JSON configuration" (Parent: #2)
   - Task: "Test ruleset application" (Parent: #2)
   - Task: "Document ruleset in README" (Parent: #2)

4. Link relationships using GraphQL sub-issues API
```

### Example 2: Two-Level Hierarchy

Simple setup phase:

```
1. Create Epic: "Phase 0 - Setup"
   - Phase: Phase 0
   - Description: Initialize repository and basic structure
   
2. Create Tasks directly under Epic:
   - Task: "Initialize repository" (Parent: #1)
   - Task: "Create directory structure" (Parent: #1)
   - Task: "Write comprehensive .gitignore" (Parent: #1)
   - Task: "Create initial README" (Parent: #1)
```

### Example 3: Bug Report

Reporting a broken workflow:

```
1. Create Bug: "Agent authentication fails with 404"
   - Severity: High
   - Priority: P1
   - Steps to reproduce: (detailed steps)
   - Expected: Workflow passes
   - Actual: 404 error when fetching approved agents list
   - Environment: GitHub Actions, main branch, commit abc123
   - Logs: (paste error output)
```

### Example 4: Agent Request

Proposing a new agent:

```
1. Create Agent Request: "Add Copilot as approved agent"
   - Agent name: GitHub Copilot
   - Username: copilot
   - Type: GitHub App
   - Purpose: General code generation and issue resolution
   - Capabilities: Code generation, PR creation, testing
   - Permissions: Read/write code, issues, PRs
   - Security: OAuth authentication via GitHub App
   - Maintainer: @project-lead
```

## FAQ

### Do I need to use all three levels (Epic → Feature → Task)?

No. Use the hierarchy that makes sense:
- **Simple work:** Epic → Task (2 levels)
- **Complex work:** Epic → Feature → Task (3 levels)
- **Standalone bug:** Just create a Bug issue (no parent needed)

### Can I change issue types after creation?

Yes, but:
- Issue types are set via GitHub's organization settings
- Use GraphQL API to change types (not labels)
- Ensure the type matches the actual scope of work
- Update parent-child relationships if needed

### What if I'm not sure which template to use?

Ask yourself:
- **"How long will this take?"**
  - Hours/days → Task
  - Weeks → Feature
  - Months → Epic
  
- **"Does it contain other work items?"**
  - Contains Features → Epic
  - Contains Tasks → Feature or Epic
  - Standalone work → Task or Bug

When in doubt, start with a Task. You can always promote it to a Feature or Epic later.

### Can Tasks exist without a parent?

Technically yes, but it's not recommended. Every Task should be part of a Feature or Epic to maintain context and traceability.

Exception: Small, independent tasks like "Fix typo in README" can exist standalone.

### How do I link parent and child issues?

After creating both issues:
1. Use GitHub's sub-issues API via GraphQL
2. Or use the Okyerema skill which provides helper scripts
3. The relationship will show in GitHub's UI automatically

See the [Okyerema skill documentation](/.github/skills/okyerema/SKILL.md) for details.

### What about labels?

Use labels **sparingly** and only for categorization:
- ✅ Good: `documentation`, `security`, `powershell`
- ❌ Bad: `epic`, `in-progress`, `blocked`

Issue types and relationships are handled by GitHub's built-in features, not labels.

### Can I disable blank issues?

Yes, and we do. The `config.yml` file disables blank issues to ensure all issues use templates. This maintains consistency and ensures required information is captured.

### What if I need to report a security vulnerability?

**Do NOT use issue templates for security issues.** Follow the security policy:
- See [SECURITY.md](./SECURITY.md) or the Security tab
- Use GitHub's private security advisory feature
- Contact maintainers directly

### How do I know if an agent is available?

Check `.github/approved-agents.json` for the list of approved agents. All agents listed there with `"enabled": true` are available to work on issues.

### Can human contributors make commits?

In the Anokye-Krom System, agents handle all commits. Human contributions happen through:
1. Creating and managing issues
2. Reviewing pull requests
3. Providing feedback to agents
4. Making decisions about what to build

Direct commits are blocked by branch protection rules.

### What if I need to make an emergency change?

Emergency bypass procedures exist for critical situations:
- Add the `emergency-merge` label to PR
- Requires admin role
- All bypasses are logged for audit
- See `.github/APPROVED-AGENTS.md` for details

Use this sparingly and only for true emergencies.

### How do I track progress across multiple issues?

Use GitHub Projects:
1. Create a Project board
2. Add your Epic and all related issues
3. Use custom fields for status, priority, effort
4. Visualize progress with different views

Projects are for visualization — the issues themselves define the work and relationships.

### Can I create custom issue templates?

Yes, but:
- Stick to the five core templates when possible
- Custom templates should follow the same YAML schema
- Ensure they integrate with the hierarchy system
- Document any custom templates clearly

### Where can I learn more?

- **[How We Work](./how-we-work.md)** — Overview of coordination system
- **[Our Way](./how-we-work/our-way.md)** — Philosophy and practices
- **[Agent Conventions](./how-we-work/agent-conventions.md)** — Agent behavior requirements
- **[Okyerema Skill](/.github/skills/okyerema/SKILL.md)** — Technical tools for agents
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** — Contribution guidelines

---

**The Anokye-Krom System:** Structured governance where humans create the vision and agents execute the work, ensuring traceability, consistency, and effective collaboration.
