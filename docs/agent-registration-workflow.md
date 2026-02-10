# Agent Registration Workflow Design

This document outlines the design for a future self-service agent registration system.

## Overview

**Goal:** Enable developers to request and provision new AI agents through an automated, secure workflow that maintains governance and audit trails while reducing manual overhead.

**Status:** Design proposal - not yet implemented

## Current Process (Manual)

1. Developer identifies need for agent
2. Maintainer creates GitHub App manually
3. Maintainer configures permissions
4. Maintainer installs app
5. Maintainer stores credentials
6. Maintainer documents agent
7. Notification sent to developer

**Pain points:**
- Manual steps prone to error
- Delays due to maintainer availability
- Inconsistent permission configurations
- Limited audit trail
- Poor documentation consistency

## Proposed Process (Automated)

### Phase 1: Request Submission

**Trigger:** Developer creates issue using "Agent Request" template

**Issue Template Fields:**
- Agent name (required)
- Agent description (required)
- Agent type (dropdown: read-only, issue-manager, pr-automation, full-automation)
- Repository access (multi-select or "all repositories")
- Custom permissions (optional, for non-standard agents)
- Justification (required)
- Estimated usage (requests per hour)

**Example:**
```yaml
name: Request New Agent
description: Request approval and provisioning of a new AI agent
title: "[Agent Request] "
labels: ["agent-request"]
body:
  - type: input
    id: agent-name
    attributes:
      label: Agent Name
      description: Short, descriptive name for the agent
      placeholder: "pr-reviewer-bot"
    validations:
      required: true
  
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What will this agent do?
    validations:
      required: true
  
  - type: dropdown
    id: agent-type
    attributes:
      label: Agent Type
      options:
        - Read-Only Agent
        - Issue Manager Agent
        - PR Automation Agent
        - Full Automation Agent
        - Custom (specify permissions below)
    validations:
      required: true
  
  - type: dropdown
    id: repository-access
    attributes:
      label: Repository Access
      options:
        - All repositories in organization
        - Selected repositories (list below)
    validations:
      required: true
  
  - type: textarea
    id: justification
    attributes:
      label: Justification
      description: Why is this agent needed?
    validations:
      required: true
```

### Phase 2: Security Review

**Trigger:** Issue labeled "agent-request"

**Automated Workflow:**
1. Validate all required fields present
2. Apply "pending-security-review" label
3. Assign to security team
4. Post comment with review checklist

**Security Team Review:**
- [ ] Agent purpose is clearly defined
- [ ] Requested permissions follow least-privilege principle
- [ ] Repository access is appropriately scoped
- [ ] Justification is reasonable
- [ ] No security concerns identified
- [ ] Similar agents don't already exist

**Outcomes:**
- **Approved:** Add "approved" label, proceed to provisioning
- **Changes Requested:** Comment with feedback, keep "pending-security-review"
- **Rejected:** Close issue with explanation

### Phase 3: Automated Provisioning

**Trigger:** Issue labeled "agent-request" + "approved"

**Provisioning Workflow:**

```yaml
name: Provision Agent
on:
  issues:
    types: [labeled]

jobs:
  provision:
    if: |
      contains(github.event.issue.labels.*.name, 'agent-request') &&
      contains(github.event.issue.labels.*.name, 'approved')
    runs-on: ubuntu-latest
    steps:
      - name: Parse Issue
        id: parse
        uses: ./.github/actions/parse-agent-request
        with:
          issue-body: ${{ github.event.issue.body }}
      
      - name: Create GitHub App
        id: create-app
        uses: ./.github/actions/create-github-app
        with:
          name: ${{ steps.parse.outputs.agent-name }}
          description: ${{ steps.parse.outputs.description }}
          permissions: ${{ steps.parse.outputs.permissions }}
        env:
          GH_TOKEN: ${{ secrets.APP_PROVISIONING_TOKEN }}
      
      - name: Install App
        id: install
        uses: ./.github/actions/install-github-app
        with:
          app-id: ${{ steps.create-app.outputs.app-id }}
          repositories: ${{ steps.parse.outputs.repositories }}
        env:
          GH_TOKEN: ${{ secrets.APP_PROVISIONING_TOKEN }}
      
      - name: Store Credentials
        id: store
        uses: ./.github/actions/store-app-credentials
        with:
          app-id: ${{ steps.create-app.outputs.app-id }}
          private-key: ${{ steps.create-app.outputs.private-key }}
          installation-id: ${{ steps.install.outputs.installation-id }}
        env:
          GH_TOKEN: ${{ secrets.REPO_TOKEN }}
      
      - name: Update Approved Agents List
        uses: ./.github/actions/update-approved-agents
        with:
          app-id: ${{ steps.create-app.outputs.app-id }}
          agent-name: ${{ steps.parse.outputs.agent-name }}
          description: ${{ steps.parse.outputs.description }}
          permissions: ${{ steps.parse.outputs.permissions }}
          approved-by: ${{ github.event.issue.assignees[0].login }}
          issue-number: ${{ github.event.issue.number }}
      
      - name: Notify Requestor
        uses: ./.github/actions/comment-issue
        with:
          issue-number: ${{ github.event.issue.number }}
          body: |
            ## ✅ Agent Provisioned Successfully
            
            Your agent has been created and configured.
            
            **Agent Details:**
            - **Name:** ${{ steps.parse.outputs.agent-name }}
            - **App ID:** ${{ steps.create-app.outputs.app-id }}
            - **Installation ID:** ${{ steps.install.outputs.installation-id }}
            - **Bot Username:** ${{ steps.create-app.outputs.bot-username }}
            
            **Next Steps:**
            1. Access credentials via GitHub Secrets:
               - `AGENT_${{ steps.parse.outputs.agent-name }}_APP_ID`
               - `AGENT_${{ steps.parse.outputs.agent-name }}_PRIVATE_KEY`
               - `AGENT_${{ steps.parse.outputs.agent-name }}_INSTALLATION_ID`
            
            2. Review [Agent Authentication Guide](../docs/agent-authentication.md)
            
            3. Test your agent in a sandbox environment first
            
            **Support:**
            - Documentation: [Agent Authentication](../docs/agent-authentication.md)
            - Troubleshooting: [Troubleshooting Guide](../docs/agent-authentication.md#troubleshooting)
      
      - name: Close Issue
        run: gh issue close ${{ github.event.issue.number }} --comment "Agent provisioned successfully."
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Phase 4: Audit and Monitoring

**Automated Audit Trail:**
- All provisioning actions logged to audit log
- Agent request issue preserved for reference
- Approved agents list maintained as source of truth
- Regular reports generated on agent usage

**Monitoring:**
- Track API usage per agent
- Alert on unusual patterns
- Monitor permission changes
- Quarterly permission audits

## Permission Templates

Standardized permission sets based on agent type:

### Read-Only Agent
```json
{
  "permissions": {
    "issues": "read",
    "pull_requests": "read",
    "contents": "read",
    "metadata": "read"
  }
}
```

### Issue Manager Agent
```json
{
  "permissions": {
    "issues": "write",
    "pull_requests": "read",
    "contents": "read",
    "metadata": "read"
  }
}
```

### PR Automation Agent
```json
{
  "permissions": {
    "issues": "write",
    "pull_requests": "write",
    "contents": "write",
    "metadata": "read"
  }
}
```

### Full Automation Agent
```json
{
  "permissions": {
    "issues": "write",
    "pull_requests": "write",
    "contents": "write",
    "workflows": "write",
    "projects": "write",
    "metadata": "read"
  }
}
```

## Approved Agents Data Structure

**File:** `.github/approved-agents.json`

```json
{
  "version": "1.0",
  "lastUpdated": "2026-02-10T00:00:00Z",
  "agents": [
    {
      "id": "001",
      "name": "okyerema",
      "type": "issue-manager",
      "description": "Issue hierarchy and project management agent",
      "githubAppId": "123456",
      "installationId": "12345678",
      "botUsername": "okyerema[bot]",
      "permissions": {
        "issues": "write",
        "pull_requests": "read",
        "contents": "read",
        "projects": "write"
      },
      "repositories": ["akwaaba"],
      "approvedBy": "maintainer-username",
      "approvedDate": "2026-02-10",
      "requestIssue": "#404",
      "enabled": true,
      "notes": "Primary project management agent"
    }
  ]
}
```

## Security Considerations

### Approval Process

**Who can approve agent requests?**
- Organization owners
- Security team members
- Designated approvers with "agent-approver" role

**Required reviews:**
- Minimum 1 approval for read-only agents
- Minimum 2 approvals for write-access agents
- Security team review for custom permissions

### Credential Security

**Storage:**
- Private keys stored in GitHub Secrets (encrypted)
- Secrets named: `AGENT_{NAME}_{CREDENTIAL_TYPE}`
- Access restricted to workflows and authorized personnel

**Rotation:**
- Quarterly rotation of private keys
- Automated rotation workflow
- Notification to agent owners before rotation
- Rollover period with dual-key support

### Access Control

**Repository-level controls:**
- Agents can only access explicitly approved repositories
- Installation can be scoped to specific repos
- Permissions can differ per repository

**Time-based controls:**
- Optional: Set expiration dates for temporary agents
- Quarterly review of all agents
- Automatic disable if unused for 90 days

## Implementation Phases

### Phase 1: Foundation (Prerequisite)
- [x] Define authentication strategy (ADR-0004)
- [x] Document authentication flow
- [x] Document registration process
- [ ] Create approved agents JSON schema
- [ ] Create issue template for agent requests

### Phase 2: Manual Process (Current)
- [ ] Establish manual approval process
- [ ] Create documentation for maintainers
- [ ] Train security team on review criteria
- [ ] Maintain approved agents list manually

### Phase 3: Partial Automation
- [ ] Implement automated validation of requests
- [ ] Create workflow for approval notifications
- [ ] Automate approved agents list updates
- [ ] Implement basic audit logging

### Phase 4: Full Automation
- [ ] Implement GitHub App creation via API
- [ ] Automate credential storage
- [ ] Implement self-service provisioning
- [ ] Add monitoring and alerting
- [ ] Implement quarterly audit reports

### Phase 5: Advanced Features
- [ ] Automated permission audits
- [ ] Agent usage analytics
- [ ] Cost tracking per agent
- [ ] Anomaly detection
- [ ] Self-service credential rotation

## Success Metrics

**Efficiency:**
- Time from request to provisioning < 1 hour (automated) vs. 1-2 days (manual)
- Approval process SLA: 24 hours

**Quality:**
- Zero credential leaks
- 100% of agents using standard permission templates
- Zero over-privileged agents

**Adoption:**
- 90% of new agents use self-service system
- 100% of agents documented in approved agents list

**Security:**
- All agents reviewed quarterly
- Credentials rotated on schedule
- No security incidents related to agent authentication

## Future Enhancements

**Advanced Features:**
- Machine learning for anomaly detection in agent behavior
- Automatic permission right-sizing based on usage patterns
- Integration with external identity providers
- Federated agent management across organizations
- Agent marketplace for pre-approved agent templates

**Integration Points:**
- SIEM integration for security monitoring
- Cost allocation and chargeback
- Compliance reporting
- Developer portal integration

## References

- [ADR-0004: Use GitHub Apps for agent authentication](../adr/ADR-0004-use-github-apps-for-agent-authentication.md)
- [Agent Authentication Guide](./agent-authentication.md)
- [GitHub API: Create GitHub App](https://docs.github.com/en/rest/apps/apps#create-a-github-app)
- Planning document: `planning/phase-2-governance/03-workflow-agent-auth.md`

---

**Last Updated:** 2026-02-10  
**Status:** Design Proposal  
**Next Steps:** Implement Phase 1 (Foundation)
