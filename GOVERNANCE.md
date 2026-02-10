# Governance

**Akwaaba** operates under the **Anokye-Krom System** — a governance model where AI agents handle all commits in response to human-created issues.

## Philosophy

The Anokye-Krom System is built on three core principles:

1. **Issue-Driven Development** — All work begins with a GitHub issue created by a human
2. **Agent-Only Commits** — All code changes are implemented by approved AI agents
3. **Human Oversight** — Humans review, approve, and merge all changes

This model ensures:
- Every change is tracked and documented
- The "why" behind every commit is clear and searchable
- Work is coordinated through a single source of truth
- Consistent quality and adherence to conventions

## Branch Protection

The `main` branch is protected by a comprehensive GitHub ruleset that enforces our governance model.

### Active Rules

#### Pull Request Requirements
- **Require pull request before merging** — Direct pushes to `main` are blocked
- **Require at least 1 approval** — All PRs must be reviewed and approved
- **Dismiss stale reviews** — Reviews are invalidated when new commits are pushed
- **Require conversation resolution** — All review comments must be resolved before merging

#### Status Check Requirements
- **Require status checks to pass** — All required checks must succeed before merging
- **Required checks:**
  - `commit-validator` — Validates commit messages reference GitHub issues
  - `agent-auth` (planned) — Validates commits are from approved agents
- **Require branches to be up to date** — Branches must be current with `main` before merging

#### Commit Restrictions
- **Block force pushes** — History on `main` is immutable
- **Block branch deletion** — The `main` branch cannot be deleted
- **Restrict push access** — Only through approved pull requests

### Ruleset Configuration

The complete ruleset configuration is stored in `.github/rulesets/` (to be exported when implemented via GitHub UI).

## Commit Validation

All commits must reference a GitHub issue. This requirement is enforced by the `commit-validator` workflow.

### Valid Commit Formats

Commits must include an issue reference in one of these formats:

1. **Simple reference:** `#123`
2. **Keyword reference:** `Closes #123`, `Fixes #456`, `Resolves #789`
3. **Cross-repository:** `owner/repo#123`
4. **Full URL:** `https://github.com/owner/repo/issues/123`

### Examples

✅ **Valid commits:**
```
feat: Add governance documentation (#42)
fix: Correct validation logic, Closes #101
docs: Update README (anokye-labs/akwaaba#50)
```

❌ **Invalid commits:**
```
feat: Add new feature
fix: Bug fix
Update documentation
```

### Exempt Commits

The following commit types are automatically exempt from issue reference requirements:
- **Merge commits** — Automatically created by GitHub
- **Revert commits** — Starting with "Revert"
- **Bot commits** — From `github-actions[bot]`, `dependabot[bot]`, `renovate[bot]`

### Validation Logs

All commit validation attempts are logged to `logs/commit-validation/` with structured JSON for audit purposes:
- Timestamp of validation
- Commit SHA and author
- Pull request number
- Validation result (pass/fail/skip)
- Correlation ID for tracing

## Agent Authentication

Only approved AI agents are permitted to make commits to this repository.

### Approved Agents

The current list of approved agents includes:
- **copilot-swe-agent[bot]** — GitHub Copilot workspace agent
- **github-actions[bot]** — GitHub Actions automation
- **dependabot[bot]** — Automated dependency updates

The complete allowlist is maintained in `.github/approved-agents.json` (when implemented).

### Authentication Workflow

When a pull request is opened or updated, the `agent-auth` workflow (planned):

1. Fetches all commits in the pull request
2. Extracts commit author and committer information
3. Validates each commit against the approved agents list
4. Blocks merge if any commits are from non-approved sources

### Adding New Agents

To request approval for a new agent:

1. Create an issue using the `agent-approval-request` template (when available)
2. Provide:
   - Agent username/GitHub App ID
   - Purpose and use case
   - Security and authentication details
3. Wait for review and approval from repository maintainers
4. Agent will be added to the approved agents list

## Bypass Procedures

While the governance rules are strict, we recognize that emergencies happen. Bypass procedures exist for exceptional circumstances.

### When to Bypass

Bypass procedures should **only** be used for:
- **Security emergencies** — Critical vulnerabilities requiring immediate patches
- **System outages** — Production-down scenarios requiring rapid fixes
- **Infrastructure failures** — CI/CD or automation system failures preventing normal workflow

Bypass is **not appropriate** for:
- Convenience or speed
- Avoiding review process
- Working around disagreements
- Personal preferences

### How to Bypass

#### Emergency Merge Label

Apply the `emergency-merge` label to a pull request to bypass agent authentication validation.

**Requirements:**
- Only organization administrators can apply this label
- A comment explaining the emergency is required
- All bypasses are logged for audit

**Steps:**
1. Create pull request as normal
2. Add `emergency-merge` label
3. Comment with explanation: nature of emergency, why bypass is necessary
4. Proceed with merge after approval

#### Ruleset Bypass

Organization administrators can bypass the ruleset temporarily for direct pushes.

**Important:** This bypass should be used extremely rarely, as it circumvents all protections.

**When ruleset bypass is used:**
- Document the reason in a follow-up issue
- Create a pull request to formalize the emergency change
- Review the change post-facto
- Update incident response documentation if needed

### Who Can Bypass

Bypass permissions are restricted to:
- **Organization administrators** — Full bypass capability
- **Repository administrators** — Can apply emergency-merge label

### Audit Trail

All bypass events are logged:
- Emergency merge labels trigger logged validation results
- Ruleset bypasses are recorded in GitHub's audit log
- Comments on emergency merges provide context
- Logs are reviewed periodically to identify patterns

### Post-Bypass Process

After using bypass procedures:

1. **Document the incident** — Create a GitHub issue describing:
   - What happened
   - Why bypass was necessary
   - What was changed
   - Lessons learned

2. **Review the change** — Even if already merged:
   - Create a follow-up pull request if refinements needed
   - Ensure documentation is updated
   - Add tests if missing

3. **Update procedures** — If the incident revealed gaps:
   - Update governance documentation
   - Enhance automation to prevent recurrence
   - Revise incident response plans

## Issue-Driven Workflow

The Anokye-Krom System enforces an issue-first workflow.

### How It Works

1. **Human creates issue** — Describe what needs to be done and why
2. **Agent is assigned** — AI agent receives the issue
3. **Agent implements** — Agent reads issue, makes changes, creates PR
4. **Human reviews** — Review code, test functionality, provide feedback
5. **Agent refines** — Agent addresses feedback, updates PR
6. **Human merges** — Merge when satisfied

### Enforcement Mechanisms

The workflow is enforced through:
- **Branch protection** — No direct commits to `main`
- **Commit validation** — Every commit must reference an issue
- **Agent authentication** — Only approved agents can commit
- **Required reviews** — Human approval required before merge

## Troubleshooting

### My commit was rejected

**Check:** Does your commit message reference a GitHub issue?
- Add issue reference: `#123` or `Closes #456`
- See [Commit Validation](#commit-validation) for valid formats

### My PR is blocked by status checks

**Check:** Are all required status checks passing?
- View the "Checks" tab on your pull request
- Click on failed checks to see error details
- Address issues and push new commits

### I need to make an emergency change

**See:** [Bypass Procedures](#bypass-procedures)
- Determine if this truly qualifies as an emergency
- Follow the emergency merge process
- Document the incident thoroughly

### How do I request a new agent?

**Process:** (Planned - agent approval workflow)
- Create issue with `agent-approval-request` template
- Provide agent details and justification
- Wait for maintainer review
- Agent added to approved list if approved

## Related Documentation

- **[How We Work](./how-we-work.md)** — Overview of our coordination system
- **[Contributing Guide](./CONTRIBUTING.md)** — How to contribute to this repository
- **[Agent Conventions](./how-we-work/agent-conventions.md)** — Behavioral requirements for AI agents
- **[Okyerema Skill](./.github/skills/okyerema/SKILL.md)** — Project orchestration skill for agents

## Future Enhancements

Planned improvements to the governance system:

- **Ruleset export** — Export and version control ruleset configuration in `.github/rulesets/`
- **Agent auth workflow** — Automated validation of commit authors against approved agents list
- **Self-service agent registration** — Streamlined process for requesting new agent approvals
- **Enhanced audit reporting** — Dashboard and reports for governance metrics
- **Incident response playbooks** — Detailed procedures for common emergency scenarios

---

**Questions or Issues?**

If you have questions about governance policies or need assistance with bypass procedures, create an issue with the `question` label or contact repository administrators.
