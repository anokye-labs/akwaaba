# Governance Model

This document describes the governance and enforcement model for the Akwaaba repository, based on the **Anokye-Krom System** philosophy.

## Table of Contents

- [Overview](#overview)
- [Anokye-Krom System](#anokye-krom-system)
- [Branch Protection](#branch-protection)
- [Agent Authentication](#agent-authentication)
- [Commit Validation](#commit-validation)
- [Emergency Procedures](#emergency-procedures)
- [Agent Registration Process](#agent-registration-process)

## Overview

The Akwaaba repository implements a strict governance model that:

1. **Protects the main branch** through comprehensive rulesets
2. **Requires agent authentication** for all commits
3. **Validates commit messages** reference tracked issues
4. **Enforces structured workflows** through issue templates
5. **Maintains audit trails** of all changes

## Anokye-Krom System

The Anokye-Krom System is our governance philosophy, inspired by the Akan concept of "Sankofa" (learning from the past to build the future) and named after the Asante founder Osei Tutu and the Asante capital Kumasi (originally Krom).

### Core Principles

1. **Foresight Over Reaction** - Prevent problems before they occur through proactive governance
2. **Collective Ownership** - All changes are tracked, reviewed, and attributed
3. **Agent-Driven Development** - Automated agents handle routine work, freeing humans for strategy
4. **Issue-Driven Work** - All work must be planned and tracked through GitHub issues
5. **Transparent Audit Trails** - Every change is traceable to its purpose and author
6. **Emergency Flexibility** - Procedures exist for urgent situations while maintaining accountability

## Branch Protection

The main branch is protected by a comprehensive GitHub ruleset that enforces:

### Pull Request Requirements

- **Required**: All changes must go through pull requests
- **Approvals**: At least 1 approval required before merge
- **Stale Reviews**: Dismissed automatically when new commits are pushed
- **Conversation Resolution**: All review conversations must be resolved

### Status Check Requirements

Two required status checks must pass before merging:

1. **Commit Validator** - Ensures all commits reference valid GitHub issues
2. **Agent Authentication** - Verifies all commits are from approved agents

Status checks enforce the "strict" policy, meaning branches must be up-to-date with main before merging.

### Commit Restrictions

- **Force Pushes**: Blocked to maintain commit history integrity
- **Branch Deletion**: Prevented to avoid accidental data loss
- **Direct Commits**: Not allowed - all changes via pull requests

### Ruleset Configuration

The complete ruleset is defined in `.github/rulesets/main-branch-protection.json` and can be applied to the repository using the GitHub API or web interface.

## Agent Authentication

### Authentication Policy

All commits to this repository must originate from **approved agents only**. Human users cannot commit directly to any branch that will be merged to main.

### Why Agent-Only Commits?

1. **Consistency** - Agents follow established patterns and conventions
2. **Auditability** - Agent actions are logged and traceable
3. **Quality** - Agents can run automated checks before committing
4. **Security** - Reduces risk of accidental credential exposure or insecure code
5. **Efficiency** - Agents can handle routine tasks 24/7

### Approved Agents

The list of approved agents is maintained in `.github/approved-agents.json`. Each approved agent entry includes:

- **username**: GitHub username (typically ends with `[bot]`)
- **githubAppId**: Unique GitHub App ID for verification
- **type**: Agent type (e.g., "github-copilot", "custom-bot")
- **description**: Purpose and capabilities of the agent
- **permissions**: Scopes and access levels
- **approvedBy**: Administrator who approved the agent
- **dateAdded**: ISO 8601 timestamp of approval
- **status**: Current status (active, suspended, revoked)

### Authentication Workflow

The **Agent Authentication** workflow (`.github/workflows/agent-auth.yml`) runs on every pull request to:

1. Fetch all commits in the PR
2. Extract commit author and committer information
3. Verify each commit author against the approved agents list
4. Check GitHub App IDs for bot accounts
5. Report violations with clear error messages
6. Block PR merge if non-agent commits are detected

### Emergency Override

In exceptional circumstances, a PR with human commits can be merged by:

1. Applying the `emergency-merge` label to the PR
2. Obtaining approval from a repository administrator
3. Documenting the reason in the PR description
4. Creating a follow-up issue to address the emergency process

All emergency overrides are logged and reviewed in monthly governance audits.

## Commit Validation

### Issue Reference Requirements

Every commit message must reference a valid GitHub issue using one of these formats:

- `feat: Add new feature (#123)`
- `fix: Resolve bug (#456)`
- `docs: Update documentation (#789)`

The **Commit Validator** workflow checks that:

1. Each commit message includes an issue reference (e.g., `#123`)
2. The referenced issue exists in the repository
3. The issue is not closed at the time of commit
4. The commit type matches conventional commit standards

### Conventional Commits

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

## Emergency Procedures

### When to Use Emergency Procedures

Emergency procedures should only be used for:

- **Critical security vulnerabilities** requiring immediate patching
- **Production outages** caused by recent commits
- **Data loss prevention** requiring urgent intervention
- **Legal/compliance issues** requiring immediate action

### Emergency Bypass Process

1. **Assess the situation** - Confirm it's a true emergency
2. **Notify stakeholders** - Alert repository administrators via designated channels
3. **Document the emergency** - Create an incident issue with severity label
4. **Apply bypass** - Administrator applies `emergency-merge` label
5. **Make minimal changes** - Only fix the immediate problem
6. **Create follow-up** - Schedule proper review and permanent fix
7. **Post-mortem** - Document lessons learned and update procedures

### Bypass Permissions

Only users with the **Admin** repository role can bypass branch protection rules. This includes:

- Organization administrators
- Repository administrators
- Emergency response team members (when designated)

All bypass actions are logged and must be justified in the associated PR.

## Agent Registration Process

### Overview

New agents must be formally approved before they can commit to the repository. This ensures security, quality, and accountability.

### Registration Steps

1. **Submit Request** - Create an agent registration issue using the "Agent Request" template
2. **Provide Details** - Include agent name, purpose, GitHub App ID, and planned permissions
3. **Security Review** - Repository administrators review the agent's security posture
4. **Approval Decision** - Administrators approve or request changes
5. **Update Allowlist** - Approved agent is added to `.github/approved-agents.json`
6. **Verification** - Test commits to verify authentication works
7. **Documentation** - Update relevant documentation with agent capabilities

### Request Template

Use the `.github/ISSUE_TEMPLATE/agent-request.yml` template to submit agent registration requests. The template ensures all required information is provided.

### Required Information

- **Agent Name**: Human-readable name
- **GitHub Username**: Bot account username (must end with `[bot]`)
- **GitHub App ID**: Unique identifier from GitHub App settings
- **Purpose**: What problem does this agent solve?
- **Planned Operations**: What will the agent do?
- **Permissions Required**: Minimum necessary scopes
- **Security Considerations**: How is the agent secured?
- **Maintenance Plan**: Who maintains the agent?

### Review Criteria

Agents are evaluated on:

1. **Necessity** - Is this agent truly needed?
2. **Security** - Does it follow security best practices?
3. **Scope** - Are permissions minimized appropriately?
4. **Maintainability** - Is there a clear maintenance plan?
5. **Documentation** - Are operations well-documented?

### Approval Timeline

- **Initial Review**: Within 2 business days
- **Security Assessment**: 3-5 business days
- **Final Decision**: Within 1 week of submission

Urgent agent requests can be expedited with appropriate justification.

### Agent Lifecycle

- **Active**: Agent is approved and can commit
- **Suspended**: Temporarily disabled pending investigation
- **Revoked**: Permanently removed from approved list

Status changes are documented in the approved-agents.json file and announced via repository notifications.

## Questions or Issues?

If you have questions about this governance model or need clarification:

1. Check the [CONTRIBUTING.md](CONTRIBUTING.md) guide
2. Review the [agents.md](agents.md) documentation
3. Search existing issues for similar questions
4. Create a new issue with the "question" label

For security concerns, please follow the security policy in [SECURITY.md](SECURITY.md) (if available) or contact repository administrators directly.

---

**Last Updated**: 2026-02-09  
**Version**: 1.0.0  
**Status**: Active
