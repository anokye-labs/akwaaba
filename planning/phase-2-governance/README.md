# Phase 2: Governance Infrastructure

**Goal:** Build the enforcement layer that makes agent-only commits possible.

## Features

1. **ruleset-protect-main** - Branch protection ruleset
2. **workflow-commit-validator** - Validate commits reference issues
3. **workflow-agent-auth** - Validate commits are from agents
4. **issue-templates** - Structured issue templates
5. **project-automation** - GitHub Project with automation

## Dependencies

- Phase 1 must be complete
- Requires repository initialization

## Success Criteria

- Direct commits are blocked
- PRs require issue references
- Only agents can commit
- Issues follow structure
- Project board auto-updates

## Estimated Effort

Large - core governance layer, 3-5 sessions
