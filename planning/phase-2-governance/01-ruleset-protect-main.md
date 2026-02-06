# Feature: Create Branch Protection Ruleset

**ID:** ruleset-protect-main  
**Phase:** 2 - Governance  
**Status:** Pending  
**Dependencies:** repo-init

## Overview

Create a comprehensive GitHub ruleset for the main branch that enforces strict governance and prevents unauthorized changes.

## Tasks

### Task 1: Research ruleset capabilities
- [ ] Review GitHub documentation on repository rulesets
- [ ] Understand difference between rulesets and legacy branch protection
- [ ] Identify which rules can be enforced via rulesets
- [ ] Document limitations and workarounds

### Task 2: Define core protection rules
- [ ] Require pull request before merging
- [ ] Require at least 1 approval
- [ ] Dismiss stale reviews when new commits pushed
- [ ] Require review from code owners (once CODEOWNERS exists)
- [ ] Require conversation resolution before merging

### Task 3: Define status check requirements
- [ ] Require status checks to pass before merging
- [ ] Identify required checks: commit-validator, agent-auth
- [ ] Require branches to be up to date before merging
- [ ] Configure strict status checks

### Task 4: Define commit restrictions
- [ ] Require signed commits (if desired)
- [ ] Restrict who can push to matching branches
- [ ] Block force pushes
- [ ] Block branch deletion

### Task 5: Create ruleset via GitHub UI
- [ ] Navigate to repository Settings → Rules → Rulesets
- [ ] Create new ruleset named "Main Branch Protection"
- [ ] Target: main branch
- [ ] Apply all defined rules
- [ ] Set bypass permissions (org admins only)

### Task 6: Export ruleset configuration
- [ ] Export ruleset as JSON via API
- [ ] Save to `.github/rulesets/main-branch-protection.json`
- [ ] Document the export command in README
- [ ] Add comments to JSON explaining each rule

### Task 7: Document ruleset in governance docs
- [ ] Create initial GOVERNANCE.md outline
- [ ] Document each rule and its purpose
- [ ] Explain bypass procedures for emergencies
- [ ] List who can bypass and under what conditions

### Task 8: Test ruleset
- [ ] Attempt direct push to main (should fail)
- [ ] Attempt push without PR (should fail)
- [ ] Create test PR without required checks (should block merge)
- [ ] Verify all protections work as expected

### Task 9: Commit and document
- [ ] Commit ruleset JSON: "feat(governance): Add main branch protection ruleset"
- [ ] Update README with link to ruleset documentation
- [ ] Create issue to implement required workflows

## Acceptance Criteria

- Ruleset is active on main branch
- Direct pushes are blocked
- PRs require approvals
- Status checks are enforced
- Ruleset JSON is exported and documented
- Testing confirms all rules work
- Bypass permissions are restricted appropriately

## Notes

- Rulesets are more flexible than legacy branch protection
- Consider creating additional rulesets for release branches later
- Document the "break glass" procedure for true emergencies
- Ensure org admins understand bypass implications
