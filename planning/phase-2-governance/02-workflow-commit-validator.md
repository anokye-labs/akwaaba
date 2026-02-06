# Feature: Create Commit Validator Workflow

**ID:** workflow-commit-validator  
**Phase:** 2 - Governance  
**Status:** Pending  
**Dependencies:** ruleset-protect-main

## Overview

Build a required GitHub Actions workflow that validates every commit in a PR references an open GitHub issue, enforcing issue-driven development.

## Tasks

### Task 1: Create workflow file structure
- [ ] Create `.github/workflows/commit-validator.yml`
- [ ] Set name: "Commit Validator"
- [ ] Configure triggers: pull_request (types: opened, synchronize)
- [ ] Set appropriate permissions (contents: read, pull-requests: read)

### Task 2: Define commit message validation logic
- [ ] Check for issue references: `#123`, `Closes #123`, `Fixes #123`, `Resolves #123`
- [ ] Use regex pattern to extract issue numbers
- [ ] Support multiple issue references in one commit
- [ ] Handle both short SHA and long SHA formats

### Task 3: Implement issue existence check
- [ ] Use GitHub CLI or API to verify issue exists
- [ ] Check issue is in the same repository
- [ ] Verify issue is open (not closed)
- [ ] Cache results to avoid rate limiting

### Task 4: Build validation script
- [ ] Create PowerShell script: `scripts/Validate-Commits.ps1`
- [ ] Accept PR number as input parameter
- [ ] Fetch all commits in the PR
- [ ] Validate each commit message
- [ ] Return structured results (pass/fail + details)

### Task 5: Configure workflow job
- [ ] Run on ubuntu-latest (or windows-latest for PowerShell)
- [ ] Check out repository
- [ ] Setup PowerShell environment
- [ ] Run validation script
- [ ] Set job status based on script output

### Task 6: Implement helpful error messages
- [ ] List commits that fail validation
- [ ] Show expected format examples
- [ ] Provide actionable fix instructions
- [ ] Link to contribution guidelines

### Task 7: Add status check reporting
- [ ] Use `actions/github-script` to post detailed comment on PR
- [ ] Update check status (success/failure)
- [ ] Include summary of validation results
- [ ] Mark as required check in ruleset

### Task 8: Handle edge cases
- [ ] Merge commits (skip validation or special handling)
- [ ] Revert commits (allow without issue reference)
- [ ] Bot commits (allow if from approved bots)
- [ ] WIP commits (warn but don't fail)

### Task 9: Test workflow
- [ ] Create test PR with valid commit references
- [ ] Create test PR with invalid commits (no issue)
- [ ] Create test PR with closed issue reference
- [ ] Verify all scenarios work correctly

### Task 10: Document and finalize
- [ ] Add workflow documentation to GOVERNANCE.md
- [ ] Document commit message format in CONTRIBUTING.md
- [ ] Add examples and FAQs
- [ ] Commit: "feat(governance): Add commit validator workflow"

## Acceptance Criteria

- Workflow runs on every PR
- Invalid commits block PR merge
- Error messages are clear and actionable
- Issue existence is verified
- Closed issues are rejected
- Performance is acceptable (< 30 seconds)
- Documentation is comprehensive

## Notes

- Consider caching issue lookups to reduce API calls
- Support both `#123` and full URLs
- Allow flexibility for special commit types (revert, merge)
- Make error messages educational, not punitive
