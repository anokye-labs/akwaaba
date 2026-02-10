<#
.SYNOPSIS
    Tests for Validate-Commits.ps1 script

.DESCRIPTION
    Comprehensive tests for commit validation including edge cases:
    - Merge commits
    - Revert commits
    - Bot commits
    - WIP commits
    - Regular commits with and without issue references
#>

$ErrorActionPreference = 'Stop'

# Load only the functions from the script, not the main execution logic
$scriptContent = Get-Content "$PSScriptRoot/Validate-Commits.ps1" -Raw
# Extract only the function definitions (everything before "# Main validation logic")
$functionsOnly = ($scriptContent -split '# Main validation logic')[0]
# Set required variables that functions depend on
$script:Owner = "test"
$script:Repo = "test"
# Execute the functions
Invoke-Expression $functionsOnly

<#
.SYNOPSIS
    Helper function to run a test
#>
function Test-CommitValidation {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    Write-Host "Running: $Name" -ForegroundColor Cyan
    
    try {
        & $Test
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
        return $false
    }
}

# Test: Merge commit detection
$passed = @()
$failed = @()

$result = Test-CommitValidation -Name "Test-IsMergeCommit: Detects merge pull request" -Test {
    $message = "Merge pull request #123 from user/branch"
    $result = Test-IsMergeCommit -Message $message
    if (-not $result) { throw "Failed to detect merge pull request" }
}
if ($result) { $passed += "Merge PR detection" } else { $failed += "Merge PR detection" }

$result = Test-CommitValidation -Name "Test-IsMergeCommit: Detects merge branch" -Test {
    $message = "Merge branch 'feature-branch' into main"
    $result = Test-IsMergeCommit -Message $message
    if (-not $result) { throw "Failed to detect merge branch" }
}
if ($result) { $passed += "Merge branch detection" } else { $failed += "Merge branch detection" }

$result = Test-CommitValidation -Name "Test-IsMergeCommit: Detects merge remote-tracking branch" -Test {
    $message = "Merge remote-tracking branch 'origin/main'"
    $result = Test-IsMergeCommit -Message $message
    if (-not $result) { throw "Failed to detect merge remote-tracking branch" }
}
if ($result) { $passed += "Merge remote detection" } else { $failed += "Merge remote detection" }

$result = Test-CommitValidation -Name "Test-IsMergeCommit: Does not detect regular commit" -Test {
    $message = "feat: Add new feature #123"
    $result = Test-IsMergeCommit -Message $message
    if ($result) { throw "Incorrectly detected merge commit" }
}
if ($result) { $passed += "Merge false positive" } else { $failed += "Merge false positive" }

# Test: Revert commit detection
$result = Test-CommitValidation -Name "Test-IsRevertCommit: Detects revert with quotes" -Test {
    $message = 'Revert "Add broken feature"'
    $result = Test-IsRevertCommit -Message $message
    if (-not $result) { throw "Failed to detect revert commit with quotes" }
}
if ($result) { $passed += "Revert with quotes" } else { $failed += "Revert with quotes" }

$result = Test-CommitValidation -Name "Test-IsRevertCommit: Detects revert without quotes" -Test {
    $message = 'Revert abc1234'
    $result = Test-IsRevertCommit -Message $message
    if (-not $result) { throw "Failed to detect revert commit without quotes" }
}
if ($result) { $passed += "Revert without quotes" } else { $failed += "Revert without quotes" }

$result = Test-CommitValidation -Name "Test-IsRevertCommit: Does not detect regular commit" -Test {
    $message = "fix: Revert variable to previous value #123"
    $result = Test-IsRevertCommit -Message $message
    if ($result) { throw "Incorrectly detected revert commit" }
}
if ($result) { $passed += "Revert false positive" } else { $failed += "Revert false positive" }

# Test: WIP commit detection
$result = Test-CommitValidation -Name "Test-IsWIPCommit: Detects WIP with brackets" -Test {
    $message = "[WIP] Working on feature"
    $result = Test-IsWIPCommit -Message $message
    if (-not $result) { throw "Failed to detect WIP with brackets" }
}
if ($result) { $passed += "WIP with brackets" } else { $failed += "WIP with brackets" }

$result = Test-CommitValidation -Name "Test-IsWIPCommit: Detects WIP without brackets" -Test {
    $message = "WIP: Working on feature"
    $result = Test-IsWIPCommit -Message $message
    if (-not $result) { throw "Failed to detect WIP without brackets" }
}
if ($result) { $passed += "WIP without brackets" } else { $failed += "WIP without brackets" }

$result = Test-CommitValidation -Name "Test-IsWIPCommit: Detects WIP lowercase" -Test {
    $message = "wip: still working"
    $result = Test-IsWIPCommit -Message $message
    if (-not $result) { throw "Failed to detect WIP lowercase" }
}
if ($result) { $passed += "WIP lowercase" } else { $failed += "WIP lowercase" }

$result = Test-CommitValidation -Name "Test-IsWIPCommit: Does not detect regular commit" -Test {
    $message = "feat: Add feature #123"
    $result = Test-IsWIPCommit -Message $message
    if ($result) { throw "Incorrectly detected WIP commit" }
}
if ($result) { $passed += "WIP false positive" } else { $failed += "WIP false positive" }

# Test: Bot detection
$result = Test-CommitValidation -Name "Test-IsApprovedBot: Detects github-actions bot" -Test {
    $result = Test-IsApprovedBot -Author "github-actions[bot]"
    if (-not $result) { throw "Failed to detect github-actions bot" }
}
if ($result) { $passed += "GitHub Actions bot" } else { $failed += "GitHub Actions bot" }

$result = Test-CommitValidation -Name "Test-IsApprovedBot: Detects dependabot" -Test {
    $result = Test-IsApprovedBot -Author "dependabot[bot]"
    if (-not $result) { throw "Failed to detect dependabot" }
}
if ($result) { $passed += "Dependabot" } else { $failed += "Dependabot" }

$result = Test-CommitValidation -Name "Test-IsApprovedBot: Detects renovate bot" -Test {
    $result = Test-IsApprovedBot -Author "renovate[bot]"
    if (-not $result) { throw "Failed to detect renovate bot" }
}
if ($result) { $passed += "Renovate bot" } else { $failed += "Renovate bot" }

$result = Test-CommitValidation -Name "Test-IsApprovedBot: Does not detect regular user" -Test {
    $result = Test-IsApprovedBot -Author "john.doe"
    if ($result) { throw "Incorrectly detected regular user as bot" }
}
if ($result) { $passed += "Bot false positive" } else { $failed += "Bot false positive" }

# Test: Issue reference extraction
$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts simple reference" -Test {
    $message = "feat: Add feature #123"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -ne 1) { throw "Expected 1 reference, got $($refs.Count)" }
    if ($refs[0].Number -ne 123) { throw "Expected issue #123, got #$($refs[0].Number)" }
}
if ($result) { $passed += "Simple reference" } else { $failed += "Simple reference" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts multiple simple references" -Test {
    $message = "feat: Add feature #123 and fix #456"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -ne 2) { throw "Expected 2 references, got $($refs.Count)" }
}
if ($result) { $passed += "Multiple references" } else { $failed += "Multiple references" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts keyword reference (Closes)" -Test {
    $message = "feat: Add feature Closes #123"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -eq 0) { throw "Expected at least 1 reference, got 0" }
    $hasClosesRef = $false
    foreach ($ref in $refs) {
        if ($ref.Number -eq 123) { $hasClosesRef = $true }
    }
    if (-not $hasClosesRef) { throw "Did not find Closes #123 reference" }
}
if ($result) { $passed += "Closes keyword" } else { $failed += "Closes keyword" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts keyword reference (Fixes)" -Test {
    $message = "fix: Bug Fixes #456"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -eq 0) { throw "Expected at least 1 reference, got 0" }
    $hasFixesRef = $false
    foreach ($ref in $refs) {
        if ($ref.Number -eq 456) { $hasFixesRef = $true }
    }
    if (-not $hasFixesRef) { throw "Did not find Fixes #456 reference" }
}
if ($result) { $passed += "Fixes keyword" } else { $failed += "Fixes keyword" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts keyword reference (Resolves)" -Test {
    $message = "feat: Feature Resolves #789"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -eq 0) { throw "Expected at least 1 reference, got 0" }
    $hasResolvesRef = $false
    foreach ($ref in $refs) {
        if ($ref.Number -eq 789) { $hasResolvesRef = $true }
    }
    if (-not $hasResolvesRef) { throw "Did not find Resolves #789 reference" }
}
if ($result) { $passed += "Resolves keyword" } else { $failed += "Resolves keyword" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts cross-repo reference" -Test {
    $message = "feat: Add feature from owner/repo#123"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -ne 1) { throw "Expected 1 reference, got $($refs.Count)" }
    if ($refs[0].Owner -ne "owner") { throw "Expected owner 'owner', got '$($refs[0].Owner)'" }
    if ($refs[0].Repo -ne "repo") { throw "Expected repo 'repo', got '$($refs[0].Repo)'" }
    if ($refs[0].Number -ne 123) { throw "Expected issue #123, got #$($refs[0].Number)" }
}
if ($result) { $passed += "Cross-repo reference" } else { $failed += "Cross-repo reference" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Extracts URL reference" -Test {
    $message = "feat: Add feature https://github.com/owner/repo/issues/123"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -eq 0) { throw "Expected at least 1 reference, got 0" }
    $hasUrlRef = $false
    foreach ($ref in $refs) {
        if ($ref.Number -eq 123 -and $ref.Owner -eq "owner" -and $ref.Repo -eq "repo") {
            $hasUrlRef = $true
        }
    }
    if (-not $hasUrlRef) { throw "Did not find URL reference" }
}
if ($result) { $passed += "URL reference" } else { $failed += "URL reference" }

$result = Test-CommitValidation -Name "Get-IssueReferences: Returns empty array for no references" -Test {
    $message = "feat: Add feature without reference"
    $refs = Get-IssueReferences -Message $message
    if ($refs.Count -ne 0) { throw "Expected 0 references, got $($refs.Count)" }
}
if ($result) { $passed += "No references" } else { $failed += "No references" }

# Test: Edge case combinations
$result = Test-CommitValidation -Name "Edge case: WIP commit with issue reference" -Test {
    $message = "WIP: Add feature #123"
    $refs = Get-IssueReferences -Message $message
    $isWIP = Test-IsWIPCommit -Message $message
    if (-not $isWIP) { throw "Should detect as WIP" }
    if ($refs.Count -eq 0) { throw "Should find issue reference" }
}
if ($result) { $passed += "WIP with reference" } else { $failed += "WIP with reference" }

$result = Test-CommitValidation -Name "Edge case: WIP commit without issue reference" -Test {
    $message = "[WIP] Working on something"
    $refs = Get-IssueReferences -Message $message
    $isWIP = Test-IsWIPCommit -Message $message
    if (-not $isWIP) { throw "Should detect as WIP" }
    if ($refs.Count -ne 0) { throw "Should not find issue reference" }
}
if ($result) { $passed += "WIP without reference" } else { $failed += "WIP without reference" }

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $($passed.Count)" -ForegroundColor Green
Write-Host "Failed: $($failed.Count)" -ForegroundColor Red
Write-Host ""

if ($failed.Count -gt 0) {
    Write-Host "Failed tests:" -ForegroundColor Red
    foreach ($test in $failed) {
        Write-Host "  - $test" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}
else {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
