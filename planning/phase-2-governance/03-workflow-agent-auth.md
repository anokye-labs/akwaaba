# Feature: Create Agent Authentication Workflow

**ID:** workflow-agent-auth  
**Phase:** 2 - Governance  
**Status:** Pending  
**Dependencies:** ruleset-protect-main

## Overview

Build a required GitHub Actions workflow that validates commits are from approved agents, enforcing the agent-only commit pattern.

## Tasks

### Task 1: Define agent authentication strategy
- [x] Research GitHub App authentication patterns
- [x] Decide: GitHub App vs Bot user vs Service account
- [x] Document authentication flow
- [x] Plan for future agent registration system

### Task 2: Create allowlist of approved agents
- [ ] Define allowlist format (JSON or YAML)
- [ ] Store in `.github/approved-agents.json`
- [ ] Include: bot username, GitHub App ID, description
- [ ] Add process for adding new agents

### Task 3: Create workflow file
- [ ] Create `.github/workflows/agent-auth.yml`
- [ ] Set name: "Agent Authentication"
- [ ] Configure triggers: pull_request (types: opened, synchronize)
- [ ] Set permissions (contents: read, pull-requests: read)

### Task 4: Build commit author validation
- [ ] Create PowerShell script: `scripts/Validate-CommitAuthors.ps1`
- [ ] Fetch all commits in PR
- [ ] Extract commit author and committer info
- [ ] Check against approved agents list
- [ ] Handle GitHub web UI commits (needs special case)

### Task 5: Implement GitHub App detection
- [ ] Detect commits from GitHub Apps (author includes [bot])
- [ ] Verify GitHub App ID against allowlist
- [ ] Handle App installation context
- [ ] Support multiple App authentication methods

### Task 6: Add human override mechanism
- [ ] Define emergency bypass label (e.g., "emergency-merge")
- [ ] Require specific team/role to apply label
- [ ] Log all bypasses for audit
- [ ] Notify on bypass usage

### Task 7: Configure error messaging
- [ ] Clear error when human commits detected
- [ ] Explain agent-only policy
- [ ] Link to documentation on setting up agents
- [ ] Provide contact for requesting new agent approval

### Task 8: Implement audit logging
- [ ] Log every validation attempt
- [ ] Record commit author, PR number, timestamp
- [ ] Store logs in structured format
- [ ] Enable future analysis of patterns

### Task 9: Test authentication workflow
- [ ] Create test PR with agent commits (should pass)
- [ ] Create test PR with human commits (should fail)
- [ ] Test emergency bypass label (should pass with warning)
- [ ] Verify audit logs are created

### Task 10: Document agent onboarding
- [ ] Create AGENT-SETUP.md guide
- [ ] Document how to register new agent
- [ ] Explain authentication requirements
- [ ] Add troubleshooting section

### Task 11: Finalize and integrate
- [ ] Add workflow to required checks in ruleset
- [ ] Update GOVERNANCE.md with authentication policy
- [ ] Create template for agent registration requests
- [ ] Commit: "feat(governance): Add agent authentication workflow"

## Acceptance Criteria

- Workflow validates commit authors
- Non-agent commits block PR merge
- Approved agents can commit freely
- Emergency bypass works correctly
- Audit trail is maintained
- Documentation is clear
- Allowlist is easy to update

## Notes

- GitHub Apps are preferred over bot users (better audit trail)
- Consider rate limiting implications
- Plan for future: self-service agent registration
- Balance security with usability
- Emergency bypass should be rare and visible
