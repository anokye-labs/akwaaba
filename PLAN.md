# Akwaaba: Continuous AI Reference Implementation

## Problem Statement

Create a reference implementation repository (Akwaaba) that demonstrates the "GasTown" governance model - a GitHub repository where:
- All commits originate from AI agents responding to issues
- Strict automation enforces workflow discipline
- Complete observability and traceability of all changes
- Issue-driven development is not optional, it's enforced
- Agents operate within safe, auditable boundaries

This builds on patterns from:
- **copilot-media-plugins**: Continuous AI, agent archetypes, Actions-first design, structured issue hierarchies
- **amplifier-dotnet**: Issue-driven development enforcement, specification-driven development, tool-first approach

## Proposed Approach

Build Akwaaba as a **full reference implementation** with three layers:

1. **Governance Infrastructure** (.github/)
   - Branch protection rulesets
   - Required workflows for commit validation
   - Project automation rules
   - Issue templates with strict schemas

2. **Agent Fleet** (.github/agents/)
   - 3-5 reference agents demonstrating common patterns
   - Actions-first design with safe-output processing
   - Structured logging and observability

3. **Example .NET Application**
   - Simple .NET project showing how agents maintain code
   - Demonstrates agent → issue → commit flow
   - Infrastructure scripts in PowerShell

## Success Criteria

- [ ] Any direct commit attempt is blocked (unless from approved agent)
- [ ] All commits reference an issue number
- [ ] Issues automatically create tracking branches
- [ ] Agents operate in read-only mode by default
- [ ] Full audit trail of all agent actions
- [ ] Documentation enables others to replicate pattern

## Repository Structure

```
anokye-labs/akwaaba/
├── .github/
│   ├── workflows/          # Enforcement & agent workflows
│   ├── agents/             # Agent definitions (Actions-first)
│   ├── rulesets/           # Branch protection rules
│   ├── ISSUE_TEMPLATE/     # Structured issue templates
│   └── project.yml         # Project automation config
├── src/                    # Example .NET application
├── scripts/                # PowerShell automation scripts
├── docs/                   # Documentation
│   ├── AGENTS.md          # Agent operating model
│   ├── GOVERNANCE.md      # Rules and enforcement
│   └── SETUP.md           # How to replicate
└── README.md
```

## Implementation Plan

### Phase 1: Repository Foundation
- **repo-init**: Initialize Akwaaba repository structure
- **readme-welcome**: Create welcoming README explaining the concept
- **gitignore-setup**: Add .NET and PowerShell .gitignore

### Phase 2: Governance Infrastructure
- **ruleset-protect-main**: Create branch protection ruleset for main
- **workflow-commit-validator**: Workflow that validates all commits reference issues
- **workflow-agent-auth**: Workflow that validates commits are from approved agents
- **issue-templates**: Create issue templates (Epic, Feature, Task, Bug, Agent Request)
- **project-automation**: Set up GitHub Project with automation rules

### Phase 3: Agent Fleet (Reference Implementations)
- **agent-doc-sync**: Agent that keeps docs in sync with code
- **agent-issue-labeler**: Agent that auto-labels issues based on content
- **agent-pr-reviewer**: Agent that reviews PRs for common issues
- **agent-runner-common**: Shared PowerShell module for agent execution
- **agent-observability**: Structured logging infrastructure for all agents

### Phase 4: Example .NET Application
- **dotnet-project-init**: Create simple .NET console application
- **dotnet-specs**: Add spec-kit specifications
- **dotnet-tests**: Basic test structure
- **scripts-issue-workflow**: PowerShell scripts for issue → branch → PR workflow
- **scripts-agent-utils**: Helper scripts for agent development

### Phase 5: Documentation & Knowledge Transfer
- **doc-agents-md**: Comprehensive AGENTS.md (based on copilot-media-plugins)
- **doc-governance-md**: GOVERNANCE.md explaining enforcement model
- **doc-setup-md**: Step-by-step SETUP.md for replication
- **doc-architecture-md**: Technical architecture documentation
- **readme-finalize**: Polish main README with quick-start

### Phase 6: Validation & Polish
- **test-agent-execution**: Validate agents run correctly
- **test-commit-blocking**: Test that direct commits are blocked
- **test-issue-workflow**: End-to-end test of issue → agent → commit flow
- **polish-templates**: Refine issue templates based on testing
- **create-demo-video**: Optional: Record demo of the system in action

## Dependencies

```
repo-init
  → readme-welcome
  → gitignore-setup

ruleset-protect-main
  → workflow-commit-validator
  → workflow-agent-auth

workflow-agent-auth
  → agent-runner-common

agent-runner-common
  → agent-doc-sync
  → agent-issue-labeler
  → agent-pr-reviewer

dotnet-project-init
  → dotnet-specs
  → dotnet-tests

scripts-issue-workflow, scripts-agent-utils
  → doc-setup-md

All agents
  → agent-observability

All docs depend on implementation being done
```

## Key Technical Decisions

### 1. Agent Authentication
Use GitHub App with restricted permissions:
- Read: repository contents, issues, discussions
- Write: pull requests, workflow runs
- No direct commit access

### 2. Commit Enforcement Strategy
Required workflow on main branch that:
- Checks commit author is from approved GitHub App
- Validates commit message contains issue reference (`#123` or `Closes #123`)
- Validates referenced issue exists and is open
- Blocks PR merge if validations fail

### 3. Issue → Branch → PR Flow
Automation that:
- Creates branch when issue is labeled with `ready-to-implement`
- Branch name: `issue-{number}-{sanitized-title}`
- Triggers agent workflow with issue context
- Agent creates commits on that branch
- Agent opens PR when complete

### 4. Agent Architecture (Actions-First)
Each agent is a `.github/agents/{name}.yml`:
```yaml
---
on: [trigger]
permissions: read
safe-outputs:
  create-pr:
    title-prefix: "[agent-name]"
---
Natural language instructions for the agent.
Agent has access to repo context and can create PRs.
```

Compiled to standard GitHub Actions YAML via `gh aw compile`.

### 5. Observability
All agent actions emit structured JSON logs:
```json
{
  "timestamp": "...",
  "trace_id": "...",
  "agent_id": "...",
  "step_name": "...",
  "tool_call": {...},
  "status": "success|failure"
}
```

### 6. .NET Example Project
Simple console app demonstrating:
- Spec-kit driven development
- Test coverage
- Documentation that agents maintain
- Multiple agents collaborating on same codebase

### 7. PowerShell Scripts Location
Infrastructure scripts (issue creation, branch management, agent helpers):
- Location: `/scripts/`
- Naming: `Verb-Noun.ps1` (PowerShell conventions)
- Documentation: Inline help with examples

## Plugins Repository Integration

Track required plugins/capabilities as issues in anokye-labs/plugins:

### Needed Capabilities
1. **GitHub App Configuration Tool**
   - Issue in plugins repo: Setup tool for GitHub App with specific permissions
   
2. **Actions-First Compiler Extension**
   - Issue in plugins repo: `gh aw compile` equivalent or integration
   
3. **Agent Observability Dashboard**
   - Issue in plugins repo: Web UI for viewing structured agent logs

4. **Issue → Branch Automator**
   - Issue in plugins repo: Reusable workflow for issue → branch creation

5. **Commit Validator Action**
   - Issue in plugins repo: Reusable action for commit validation

## Notes

- Start with repo-init and basic structure
- Build governance layer before agents (enforces discipline from day 1)
- Keep agents simple initially - complexity can come later
- Document everything as we build - this is a reference implementation
- Test enforcement early and often
- Consider recording demo videos for documentation

## Research References

All patterns based on:
- copilot-media-plugins AGENTS.md (~8,000 words)
- amplifier-dotnet agents.md pattern
- GitHub's Continuous AI research (GitHub Next blog)
- Actions-first design pattern
- Safe-output processing model
