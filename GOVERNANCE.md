# Repository Governance

This document outlines the governance policies and enforcement mechanisms for the Akwaaba repository, a reference implementation of the **Anokye-Krom System**.

## Table of Contents

- [Overview](#overview)
- [Branch Protection](#branch-protection)
- [Commit Validator Workflow](#commit-validator-workflow)
- [Agent Authentication](#agent-authentication)
- [Bypass Procedures](#bypass-procedures)

## Overview

The Akwaaba repository implements strict governance controls to ensure:
- **Issue-driven development**: All changes must be linked to GitHub issues
- **Agent-only commits**: Only approved AI agents can commit code
- **Quality assurance**: All changes go through pull request review
- **Auditability**: Every commit is traceable to an issue and its rationale

These controls are enforced through a combination of:
- GitHub branch protection rulesets
- GitHub Actions workflows
- Commit validation checks
- Agent authentication mechanisms

## Branch Protection

The `main` branch is protected by GitHub rulesets that enforce:

### Required Pull Requests
- Direct commits to `main` are blocked
- All changes must go through pull requests
- Pull requests require review before merging

### Required Status Checks
Two status checks must pass before merging:
1. **Commit Validator** - Validates commit messages reference open issues
2. **Agent Authentication** - Verifies commits are from approved agents

### Non-Fast-Forward Protection
- Force pushes to `main` are blocked
- History rewriting is prevented
- Branch cannot be deleted

### Strict Status Checks
- Status checks must pass on the latest commit
- Cannot merge stale pull requests

For detailed ruleset configuration, see [`.github/rulesets/`](.github/rulesets/).

## Commit Validator Workflow

The **Commit Validator** workflow enforces issue-driven development by validating that every commit in a pull request references an open GitHub issue.

### Purpose

The commit validator ensures:
- Every code change is traceable to a specific issue
- The rationale for changes is documented
- Work is properly planned and coordinated
- The repository history remains meaningful and searchable

### How It Works

1. **Trigger**: Runs on every pull request (opened, synchronized, reopened)
2. **Validation**: Examines each commit message in the pull request
3. **Issue Check**: Verifies referenced issues exist and are open
4. **Status Update**: Sets the required "Commit Validator" status check

### Commit Message Requirements

Every commit message must reference at least one GitHub issue using one of these formats:

```
#123                    Basic issue reference
Closes #123            Closes the issue when merged
Fixes #123             Fixes the issue when merged
Resolves #123          Resolves the issue when merged
```

Multiple issue references are allowed:
```
Fixes #123, #456
Closes #123 and resolves #456
```

### Validation Rules

The workflow validates that:
- ✅ Commit message contains at least one issue reference
- ✅ Referenced issue exists in this repository
- ✅ Referenced issue is currently open
- ✅ Issue reference format is correct

The workflow allows:
- ✅ Merge commits (validated differently)
- ✅ Commits from approved bots
- ✅ Multiple issue references

The workflow rejects:
- ❌ Commits with no issue reference
- ❌ References to closed issues
- ❌ References to non-existent issues
- ❌ Malformed issue references

### Error Messages

When validation fails, the workflow provides:
- List of commits that failed validation
- Specific reason for each failure
- Examples of correct commit message format
- Link to contribution guidelines

### Special Cases

**Merge Commits**: Validated using the same rules, but the PR itself is considered the primary source of truth for issue references.

**Bot Commits**: Commits from approved bots (GitHub Apps) are allowed if the bot is registered in the approved agents list.

**WIP Commits**: Work-in-progress commits should still reference the issue being worked on. Use the issue reference with a WIP prefix:
```
WIP: #123 Implement feature X
```

### Performance

- Average validation time: < 10 seconds
- Issue lookups are cached to avoid rate limiting
- Runs in parallel with other status checks

### Examples

**Valid commit messages:**
```
feat(auth): Add OAuth2 support (#123)
fix(api): Resolve timeout issue - Fixes #456
docs: Update README with installation steps (#789)
refactor(core): Simplify error handling (closes #234)
```

**Invalid commit messages:**
```
Add new feature               ❌ No issue reference
Fix bug (#999)                ❌ Issue doesn't exist
Update docs (Closes #888)     ❌ Issue is closed
WIP                           ❌ No issue reference
```

For detailed commit message formatting guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md#commit-message-format).

## Agent Authentication

The **Agent Authentication** workflow verifies that commits are from approved AI agents.

### Purpose

This ensures:
- Only vetted agents can commit code
- Agent behavior can be audited
- Security vulnerabilities are prevented
- Accountability is maintained

### How It Works

1. **Trigger**: Runs on every pull request
2. **Author Check**: Examines the author of each commit
3. **Allowlist Validation**: Verifies author is in approved agents list
4. **Status Update**: Sets the required "Agent Authentication" status check

### Approved Agents

Agents must be registered in [`.github/approved-agents.json`](.github/approved-agents.json) with:
- GitHub App ID or bot username
- Description of agent's purpose
- Permissions granted
- Approval date and approver
- Status (enabled/disabled)

For the agent registration process, see [`.github/APPROVED-AGENTS.md`](.github/APPROVED-AGENTS.md).

## Bypass Procedures

In rare emergency situations, repository administrators may need to bypass protection rules.

### When to Bypass

Bypass should only be used for:
- Critical security patches requiring immediate deployment
- Infrastructure failures blocking normal workflow
- Correcting critical errors in protection rules themselves

### How to Bypass

1. **Administrator Review**: Two administrators must approve the bypass
2. **Document Reason**: Create an incident issue explaining the bypass
3. **Use Bypass Permission**: Administrators with bypass permission can override checks
4. **Post-Bypass Review**: Create a follow-up issue to restore normal process

### Bypass Accountability

All bypasses are:
- Logged in repository audit trail
- Documented in incident issues
- Reviewed in monthly governance reviews
- Subject to post-incident analysis

### Requesting Bypass Permission

If you believe protection rules need to be modified:
1. Create an issue explaining the limitation
2. Propose the change with rationale
3. Discuss with maintainers
4. Update rules through normal PR process

**Note**: Most requests for bypass stem from misunderstanding the workflow. Before requesting bypass, consult [CONTRIBUTING.md](CONTRIBUTING.md) and [how-we-work.md](how-we-work.md).

---

## Questions?

If you have questions about these governance policies:
- See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
- See [how-we-work.md](how-we-work.md) for workflow details
- Create an issue with the `question` label
- Contact repository maintainers

**Remember**: These policies exist to make collaboration better, not harder. If something isn't working, we want to hear about it!
