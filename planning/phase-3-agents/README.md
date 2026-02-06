# Phase 3: Agent Fleet

**Goal:** Create reference agents demonstrating Continuous AI patterns.

## Features

1. **agent-runner-common** - Shared PowerShell module
2. **agent-observability** - Logging and monitoring infrastructure
3. **agent-doc-sync** - Documentation synchronization agent
4. **agent-issue-labeler** - Automatic issue labeling agent
5. **agent-pr-reviewer** - Pull request review agent

## Dependencies

- Phase 2 (governance) should be in place
- agent-runner-common is foundation for other agents

## Success Criteria

- 3 working agents (doc-sync, labeler, reviewer)
- Structured logs are generated
- Safe-output processing works
- Agents follow Actions-first design

## Estimated Effort

Large - core agent infrastructure, 4-6 sessions
