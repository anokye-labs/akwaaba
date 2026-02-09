# Governance

This document defines the governance model and policies for the Akwaaba repository.

## Overview

Akwaaba implements the **Anokye-Krom System** — a governance model where AI agents handle all commits in response to human-created issues. This ensures consistency, auditability, and maintains a clear record of why every change was made.

## Core Principles

The Anokye-Krom System operates on six core principles:

1. **Agent-Only Commits** - All code changes are made by AI agents, never directly by humans
2. **Issue-Driven Development** - Every change must be linked to a GitHub issue
3. **Strict Enforcement** - Technical controls enforce policies; exceptions require approval
4. **Hierarchical Decomposition** - Work is organized in Epic → Feature → Task structure
5. **Observability by Default** - All decisions, changes, and actions are tracked and visible
6. **Safe Operations** - Prefer reversible changes; document risky operations

## Branch Protection

The `main` branch is protected by comprehensive rulesets that enforce our governance model.

### Protection Rules

#### 1. Pull Request Required

**Rule:** All changes to `main` must go through a pull request.

**Purpose:** 
- Ensures all changes are reviewed before merging
- Maintains a clear audit trail
- Prevents accidental or unauthorized changes

**Impact:**
- Direct pushes to `main` are blocked
- All contributors must create branches and PRs
- Emergency fixes must also follow this process

#### 2. Required Approvals

**Rule:** At least 1 approving review is required before merging.

**Purpose:**
- Ensures peer review of all changes
- Maintains code quality standards
- Provides accountability for changes

**Impact:**
- PRs cannot be merged until approved
- Reviewers must explicitly approve changes
- Authors cannot approve their own PRs

#### 3. Dismiss Stale Reviews

**Rule:** Approvals are automatically dismissed when new commits are pushed.

**Purpose:**
- Ensures reviewers see the latest code
- Prevents merging of code that differs from what was approved
- Maintains review integrity

**Impact:**
- New commits require re-approval
- Reviewers must review changes after each push
- Encourages smaller, focused PRs

#### 4. Code Owner Review

**Rule:** Changes must be approved by code owners when applicable.

**Purpose:**
- Ensures domain experts review relevant changes
- Maintains component ownership
- Distributes review responsibility

**Impact:**
- Requires CODEOWNERS file configuration
- Certain paths require specific reviewers
- Subject matter experts are automatically involved

**Note:** This rule is configured but requires a CODEOWNERS file to be fully effective.

#### 5. Conversation Resolution

**Rule:** All review conversations must be resolved before merging.

**Purpose:**
- Ensures all feedback is addressed
- Prevents important comments from being ignored
- Maintains communication between reviewers and authors

**Impact:**
- Unresolved threads block merging
- Authors must respond to all feedback
- Encourages thorough code review discussions

#### 6. Delete Protection

**Rule:** The `main` branch cannot be deleted.

**Purpose:**
- Protects primary branch from accidental removal
- Maintains repository integrity
- Prevents catastrophic mistakes

**Impact:**
- Branch deletion is blocked
- Even administrators cannot delete main
- Provides safety against human error

#### 7. Force Push Protection

**Rule:** Force pushes and non-fast-forward updates are blocked.

**Purpose:**
- Maintains commit history integrity
- Prevents history rewriting
- Ensures reproducibility

**Impact:**
- Cannot use `git push --force`
- Cannot rewrite main branch history
- Linear history is preserved

## Bypass Permissions

### Who Can Bypass

Repository administrators have the ability to bypass protection rules in emergency situations.

### When to Bypass

Bypass should only be used in exceptional circumstances:

- **Security Vulnerabilities** - Critical security fixes requiring immediate deployment
- **Service Outages** - Issues causing production downtime
- **Build System Failures** - CI/CD infrastructure problems blocking all PRs
- **Data Loss Prevention** - Urgent fixes to prevent data corruption or loss

### Bypass Procedure

1. **Document the Emergency** - Create an incident issue explaining the situation
2. **Notify the Team** - Alert relevant stakeholders
3. **Make the Change** - Use bypass permissions to push the fix
4. **Document the Bypass** - Comment on the incident issue with:
   - What was changed and why
   - Why normal process couldn't be followed
   - What validation was performed
5. **Follow-up PR** - If possible, create a retroactive PR showing the changes
6. **Post-Incident Review** - Discuss how to prevent similar situations

### Bypass Accountability

- All bypasses are logged by GitHub
- Bypasses must be documented in issues
- Frequent bypasses indicate process problems
- Pattern of bypasses will be reviewed

## Enforcement

These policies are enforced through:

1. **GitHub Rulesets** - Technical controls defined in `.github/rulesets/`
2. **GitHub Actions** - Automated workflows validate compliance
3. **Code Review** - Human reviewers verify policy adherence
4. **Security Scanning** - Automated tools check for vulnerabilities

## Configuration Files

- **Rulesets:** `.github/rulesets/main-branch-protection.json`
- **Documentation:** `.github/rulesets/README.md`
- **Workflows:** `.github/workflows/` (various validation workflows)

## Changes to Governance

Changes to this governance model should:

1. Start with a GitHub issue discussing the proposed change
2. Be reviewed by repository maintainers
3. Be documented in this file
4. Update relevant ruleset configurations
5. Be announced to all contributors

## References

- [CONTRIBUTING.md](./CONTRIBUTING.md) - How to contribute
- [README.md](./README.md) - Project overview and Anokye-Krom System explanation
- [agents.md](./agents.md) - Agent-specific documentation
- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)

## Questions?

If you have questions about these policies:

1. Check existing issues for discussions
2. Create a new issue with the `governance` label
3. Reach out via [anokyelabs.com](https://anokyelabs.com)
