# Feature: Create PR Reviewer Agent

**ID:** agent-pr-reviewer  
**Phase:** 3 - Agents  
**Status:** Pending  
**Dependencies:** agent-runner-common, agent-observability

## Overview
Build agent that reviews PRs for common issues: missing issue references, improper commit messages, code quality concerns.

## Key Tasks
- Create .github/agents/pr-reviewer.yml
- Check for issue reference in PR description
- Validate commit message format
- Check for test coverage changes
- Review for common mistakes (hardcoded secrets, etc.)
- Post structured review comments
- Support auto-approve for agent PRs (if criteria met)
- Add configurable review rules
- Test various PR scenarios
- Document in AGENTS.md
