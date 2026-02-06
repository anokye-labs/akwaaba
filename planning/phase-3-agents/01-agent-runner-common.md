# Feature: Create Shared Agent Runner Module

**ID:** agent-runner-common  
**Phase:** 3 - Agents  
**Status:** Pending  
**Dependencies:** None (foundation for all agents)

## Overview

Build a PowerShell module that provides common functions all agents will use: structured logging, issue context loading, PR creation, error handling, and safe-output processing.

## Tasks

### Task 1: Create module structure
- [ ] Create `scripts/AgentRunner/` directory
- [ ] Create `AgentRunner.psd1` module manifest
- [ ] Create `AgentRunner.psm1` module file
- [ ] Set version 0.1.0
- [ ] Define exported functions

### Task 2: Implement logging functions
- [ ] `Write-AgentLog`: Write structured JSON log entry
- [ ] `Start-AgentTrace`: Begin trace with correlation ID
- [ ] `Write-AgentStep`: Log individual agent step
- [ ] `Stop-AgentTrace`: Complete trace and write summary
- [ ] All functions accept common parameters (trace_id, agent_id, step_name)

### Task 3: Build issue context functions
- [ ] `Get-IssueContext`: Fetch issue from GitHub (by number)
- [ ] `Get-IssueHierarchy`: Get parent/child issues
- [ ] `Get-IssueLabels`: Parse and categorize labels
- [ ] `Test-IssueReady`: Check if issue is ready for agent work
- [ ] Cache issue data to reduce API calls

### Task 4: Create PR management functions
- [ ] `New-AgentPullRequest`: Create PR with standard agent format
- [ ] `Add-PRComment`: Add comment to PR with structured format
- [ ] `Set-PRLabel`: Apply labels to PR
- [ ] `Link-PRToIssue`: Ensure PR properly references issue
- [ ] `Wait-ForPRReview`: Monitor PR status (optional)

### Task 5: Implement error handling
- [ ] `Invoke-WithRetry`: Retry logic with exponential backoff
- [ ] `Invoke-WithCircuitBreaker`: Circuit breaker pattern
- [ ] `Write-AgentError`: Log errors in structured format
- [ ] `Test-TransientError`: Classify error types
- [ ] `ConvertTo-AgentResult`: Standardize return values

### Task 6: Build safe-output processing
- [ ] `Initialize-SafeOutput`: Setup safe output buffer
- [ ] `Add-SafeOutput`: Add item to safe output
- [ ] `Submit-SafeOutput`: Process buffered outputs (create PR, comment, etc.)
- [ ] Validate outputs before submission
- [ ] Log all safe-output operations

### Task 7: Add utility functions
- [ ] `Get-AgentConfig`: Load agent configuration
- [ ] `Test-AgentAuth`: Verify agent authentication
- [ ] `Get-RepositoryContext`: Get repo metadata
- [ ] `Format-AgentMessage`: Format messages consistently
- [ ] `ConvertTo-JsonLog`: Convert objects to log-friendly JSON

### Task 8: Implement correlation tracking
- [ ] Generate unique correlation IDs (GUIDs)
- [ ] Thread correlation ID through all functions
- [ ] Add correlation ID to all logs
- [ ] Enable distributed tracing across agent calls

### Task 9: Add module documentation
- [ ] Write comment-based help for all functions
- [ ] Include examples for each function
- [ ] Create `README.md` in module directory
- [ ] Document logging schema
- [ ] Add troubleshooting guide

### Task 10: Write module tests
- [ ] Create `AgentRunner.Tests.ps1` with Pester
- [ ] Test logging functions
- [ ] Mock GitHub API calls
- [ ] Test error handling and retries
- [ ] Test safe-output processing
- [ ] Achieve >80% code coverage

### Task 11: Create module manifest
- [ ] Set proper version and GUID
- [ ] List all exported functions
- [ ] Add author and description
- [ ] Define PowerShell version requirement (7.x)
- [ ] List required modules (if any)

### Task 12: Finalize and commit
- [ ] Run module tests
- [ ] Validate module loads correctly
- [ ] Test import in clean PowerShell session
- [ ] Commit: "feat(agents): Add AgentRunner common module"

## Acceptance Criteria

- PowerShell module loads without errors
- All functions have comment-based help
- Logging produces valid JSON
- Error handling includes retry logic
- Safe-output prevents unauthorized actions
- Module is well-tested (>80% coverage)
- Documentation is comprehensive
- Module follows PowerShell best practices

## Notes

- This is foundational - quality matters more than speed
- Follow PowerShell approved verbs (Get-, New-, Set-, etc.)
- Use proper parameter validation
- Include pipeline support where appropriate
- Consider performance - agents will call these functions frequently
- Make module discoverable via PowerShell Gallery later
