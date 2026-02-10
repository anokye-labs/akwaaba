# Manual Ruleset Enforcement Test Procedure

This document provides step-by-step instructions for manually testing GitHub ruleset enforcement on the main branch.

## Prerequisites

- Repository access with push permissions
- GitHub CLI (`gh`) installed (optional but recommended)
- Git configured with authentication

## Test Suite Overview

| Test | Description | Expected Result | Time Required |
|------|-------------|-----------------|---------------|
| 1 | Direct push to main | Push rejected | 2-3 minutes |
| 2 | PR creation without checks | PR created but merge blocked | 3-5 minutes |
| 3 | Verify merge blocking | UI shows protection status | 2-3 minutes |
| 4 | Verify ruleset configuration | Settings show all rules | 5 minutes |

**Total Time:** ~15-20 minutes

---

## Test 1: Direct Push to Main Branch

**Objective:** Verify that direct commits to main are blocked.

### Steps

1. **Save your current branch:**
   ```bash
   CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
   echo "Current branch: $CURRENT_BRANCH"
   ```

2. **Switch to main branch:**
   ```bash
   git checkout main
   git pull origin main
   ```

3. **Create a test file:**
   ```bash
   echo "Test at $(date)" > .test-direct-push.tmp
   ```

4. **Try to commit and push:**
   ```bash
   git add .test-direct-push.tmp
   git commit -m "test: Direct push attempt (should fail)"
   git push origin main
   ```

5. **Expected Result:**
   - Push should **FAIL** with an error message containing one of:
     - "protected branch"
     - "required status checks"
     - "pull request required"
     - "ruleset"
   
   **Example error message:**
   ```
   remote: error: GH006: Protected branch update failed for refs/heads/main.
   remote: error: Required status checks must pass before merging
   ```

6. **Cleanup:**
   ```bash
   # Reset the commit (it was never pushed)
   git reset --hard HEAD^
   rm -f .test-direct-push.tmp
   
   # Return to your original branch
   git checkout $CURRENT_BRANCH
   ```

7. **Record Result:**
   - ✅ PASS: Push was blocked with appropriate error
   - ❌ FAIL: Push succeeded (ruleset not configured!)

---

## Test 2: Create PR Without Required Status Checks

**Objective:** Verify that PRs can be created but merge is blocked until checks pass.

### Steps

1. **Create a test branch:**
   ```bash
   TEST_BRANCH="test-ruleset-$(date +%Y%m%d-%H%M%S)"
   git checkout -b $TEST_BRANCH
   ```

2. **Create a test change:**
   ```bash
   cat > test-ruleset-manual.md << 'EOF'
   # Manual Ruleset Test
   
   This file was created to test branch protection and merge blocking.
   
   Created: $(date -I)
   Branch: $(git rev-parse --abbrev-ref HEAD)
   
   This file can be safely deleted after testing.
   EOF
   ```

3. **Commit the change:**
   ```bash
   git add test-ruleset-manual.md
   git commit -m "test: Manual verification of ruleset enforcement
   
   This commit tests that:
   - PRs can be created
   - Merge is blocked without passing checks
   - Required status checks are enforced
   
   Related to ruleset enforcement testing."
   ```

4. **Push the branch:**
   ```bash
   git push -u origin $TEST_BRANCH
   ```

5. **Create a PR (using GitHub CLI):**
   ```bash
   gh pr create \
     --base main \
     --head $TEST_BRANCH \
     --title "Test: Manual Ruleset Enforcement Verification" \
     --body "**DO NOT MERGE - TEST PR**
   
   This PR is created to test ruleset enforcement:
   - Verify merge is blocked without required checks
   - Confirm status check requirements are displayed
   - Test branch protection rules
   
   Please close (do not merge) after verification is complete."
   ```
   
   **OR create PR via GitHub UI:**
   - Go to: https://github.com/anokye-labs/akwaaba/pulls
   - Click "New pull request"
   - Select `$TEST_BRANCH` → `main`
   - Fill in title and description
   - Click "Create pull request"

6. **Expected Result:**
   - PR should be **created successfully**
   - PR page should show merge is **blocked**

7. **Record Result:**
   - ✅ PASS: PR created, merge blocked
   - ❌ FAIL: PR couldn't be created or merge is not blocked

---

## Test 3: Verify Merge Blocking Without Checks

**Objective:** Confirm the PR shows correct blocking status and required checks.

### Steps

1. **Open the test PR in your browser:**
   ```bash
   # If using GitHub CLI
   gh pr view --web
   
   # Or manually navigate to:
   # https://github.com/anokye-labs/akwaaba/pull/NUMBER
   ```

2. **Scroll to the merge section (bottom of PR page)**

3. **Check for the following indicators:**

   **Merge Button Status:**
   - [ ] Merge button is **disabled** (grayed out)
   - [ ] Merge button shows reason: "Required checks pending" or similar

   **Protection Status Messages:**
   - [ ] Shows message: "Merging is blocked"
   - [ ] Shows message: "Required status checks must pass"
   
   **Required Status Checks Section:**
   - [ ] Lists specific required checks (e.g., "commit-validator", "agent-auth")
   - [ ] Shows check status (pending, in progress, or waiting)
   - [ ] Each check has a status icon (⚪ pending, 🔄 running, ✅ passed, ❌ failed)

   **Additional Protection Rules:**
   - [ ] Shows if reviews are required
   - [ ] Shows if conversations must be resolved
   - [ ] Shows if branch must be up to date

4. **Take Screenshots (optional but recommended):**
   - Screenshot of merge section showing blocking status
   - Screenshot of required checks list
   - Save to `docs/screenshots/` for documentation

5. **Record Result:**
   - ✅ PASS: All blocking indicators present and correct
   - ⚠️ PARTIAL: Some indicators present but incomplete
   - ❌ FAIL: No blocking indicators, merge would be allowed

6. **Cleanup (after verification):**
   ```bash
   # Close the PR (do not merge)
   gh pr close $PR_NUMBER --comment "Test completed - closing PR"
   
   # Delete the test branch
   git checkout main
   git branch -D $TEST_BRANCH
   git push origin --delete $TEST_BRANCH
   
   # Delete the test file if it exists
   rm -f test-ruleset-manual.md
   ```

---

## Test 4: Verify Ruleset Configuration

**Objective:** Review the actual ruleset configuration in GitHub settings.

### Steps

1. **Navigate to repository settings:**
   - Go to: https://github.com/anokye-labs/akwaaba/settings
   - Click on **"Rules"** in the left sidebar
   - Click on **"Rulesets"**

2. **Verify Main Branch Ruleset Exists:**
   - [ ] A ruleset targeting `main` branch exists
   - [ ] Ruleset is **Active** (not disabled)
   - [ ] Note the ruleset name: _________________

3. **Click on the ruleset to view details**

4. **Verify Core Protection Rules:**
   - [ ] **Require a pull request before merging** - ENABLED
   - [ ] **Require approvals** - ENABLED (number: ___)
   - [ ] **Dismiss stale pull request approvals** - ENABLED/DISABLED
   - [ ] **Require review from Code Owners** - ENABLED/DISABLED
   - [ ] **Require conversation resolution** - ENABLED/DISABLED

5. **Verify Status Check Rules:**
   - [ ] **Require status checks to pass** - ENABLED
   - [ ] **Required checks list:**
     - [ ] commit-validator
     - [ ] agent-auth
     - [ ] Other: _________________
   - [ ] **Require branches to be up to date** - ENABLED/DISABLED

6. **Verify Commit Restrictions:**
   - [ ] **Block force pushes** - ENABLED
   - [ ] **Require signed commits** - ENABLED/DISABLED
   - [ ] **Restrict deletions** - ENABLED

7. **Verify Bypass Permissions:**
   - [ ] **Who can bypass:** _________________
   - [ ] Bypass is restricted to: (org admins / specific users / etc.)

8. **Export Ruleset Configuration (optional):**
   ```bash
   # Get ruleset ID
   gh api /repos/anokye-labs/akwaaba/rulesets | jq '.[] | select(.target == "branch" and .name | contains("main"))'
   
   # Export full configuration
   gh api /repos/anokye-labs/akwaaba/rulesets/RULESET_ID > .github/rulesets/main-branch-protection.json
   ```

9. **Record Results:**
   - ✅ PASS: All expected rules configured correctly
   - ⚠️ PARTIAL: Most rules configured, some missing
   - ❌ FAIL: Ruleset missing or incorrectly configured

---

## Test Results Template

Use this template to record your test results:

```markdown
## Ruleset Enforcement Test Results

**Tester:** _______________
**Date:** _______________
**Repository:** anokye-labs/akwaaba
**Branch Tested:** main

### Test 1: Direct Push to Main
- **Status:** ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
- **Notes:** _______________
- **Error Message (if blocked):** _______________

### Test 2: PR Creation Without Checks
- **Status:** ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
- **PR Number:** #___
- **Notes:** _______________

### Test 3: Merge Blocking Verification
- **Status:** ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
- **Merge Button Disabled:** YES / NO
- **Required Checks Listed:** _______________
- **Notes:** _______________

### Test 4: Ruleset Configuration
- **Status:** ✅ PASS / ⚠️ PARTIAL / ❌ FAIL
- **Ruleset Name:** _______________
- **Rules Configured:** _______________
- **Notes:** _______________

### Overall Assessment
- **All Tests Passed:** YES / NO
- **Issues Found:** _______________
- **Recommendations:** _______________
```

---

## Troubleshooting

### Issue: Can't push to main even for testing
**Solution:** This is expected! The test confirms the ruleset is working. Make sure to reset your commit before switching branches.

### Issue: PR can be merged without checks
**Solution:** Ruleset may not be configured correctly. Check Settings → Rules → Rulesets and verify all required rules are enabled.

### Issue: Required checks not showing
**Solution:** 
1. Verify the workflow files exist in `.github/workflows/`
2. Check that workflows are triggered on `pull_request` events
3. Confirm workflow names match the required checks in the ruleset

### Issue: Can't create test PR
**Solution:** 
1. Make sure you're not trying to create PR from main to main
2. Verify you have push permissions to the repository
3. Check that the test branch has commits different from main

---

## After Testing

1. **Document your findings** in `docs/test-results-ruleset-enforcement.md`
2. **Update this procedure** if you found steps that were unclear or missing
3. **Create issues** for any problems found during testing
4. **Cleanup** any test branches or PRs that remain

---

**Last Updated:** 2026-02-10  
**Version:** 1.0  
**Maintained by:** Anokye Labs
