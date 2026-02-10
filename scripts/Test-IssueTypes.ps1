<#
.SYNOPSIS
    Test script for GitHub organization issue types and hierarchies.

.DESCRIPTION
    This script creates test issues with different organization-level issue types
    (Epic, Feature, Task, Bug), establishes hierarchical relationships using the
    sub-issues API, verifies the relationships work correctly, and provides
    cleanup functionality to close or delete the test issues.
    
    This implements Task 9 from planning/phase-2-governance/04-issue-templates.md:
    - Create test Epic issue
    - Create test Feature linked to Epic
    - Create test Task linked to Feature
    - Create test Bug with all fields
    - Verify hierarchies work correctly
    - Cleanup test issues

.PARAMETER Owner
    Repository owner (username or organization).

.PARAMETER Repo
    Repository name.

.PARAMETER SkipCreation
    Skip creation and only run verification (assumes test issues already exist).

.PARAMETER SkipCleanup
    Skip cleanup step, leaving test issues open for manual inspection.

.PARAMETER TestIssueNumbers
    Optional hashtable with existing test issue numbers to verify/cleanup:
    @{ Epic = 123; Feature = 124; Task = 125; Bug = 126 }

.PARAMETER CleanupOnly
    Only perform cleanup on issues specified in -TestIssueNumbers.

.EXAMPLE
    .\Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba"
    
    Creates test issues, verifies hierarchies, and prompts for cleanup.

.EXAMPLE
    .\Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" -SkipCleanup
    
    Creates and verifies test issues but leaves them open for inspection.

.EXAMPLE
    $issues = @{ Epic = 123; Feature = 124; Task = 125; Bug = 126 }
    .\Test-IssueTypes.ps1 -Owner "anokye-labs" -Repo "akwaaba" -CleanupOnly -TestIssueNumbers $issues
    
    Only cleans up specified test issues.

.NOTES
    Dependencies:
    - Invoke-GraphQL.ps1 (for GraphQL execution)
    - Get-DagStatus.ps1 (for hierarchy verification)
    - GitHub CLI (gh) installed and authenticated
    
    This script uses organization-level issue types, not issue templates with labels.
    See ADR-0003-use-org-level-issue-types.md for rationale.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [switch]$SkipCreation,

    [switch]$SkipCleanup,

    [hashtable]$TestIssueNumbers = @{},

    [switch]$CleanupOnly
)

$ErrorActionPreference = "Stop"

# Find repository root and load dependencies
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = $scriptDir  # Already in scripts directory

# Import required scripts
. (Join-Path $scriptDir "Invoke-GraphQL.ps1")

$newIssueScript = Join-Path $repoRoot ".github" "skills" "okyerema" "scripts" "New-IssueWithType.ps1"
$updateHierarchyScript = Join-Path $repoRoot ".github" "skills" "okyerema" "scripts" "Update-IssueHierarchy.ps1"
$getDagStatusScript = Join-Path $scriptDir "Get-DagStatus.ps1"

# Test results tracker
$testResults = @{
    Success = $true
    Created = @{}
    Verified = @{}
    Cleaned = @{}
    Errors = @()
}

function Write-TestHeader {
    param([string]$Message)
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-TestStep {
    param([string]$Message)
    Write-Host "`n▶ $Message" -ForegroundColor Blue
}

function Write-TestSuccess {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-TestFailure {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
    $testResults.Success = $false
    $testResults.Errors += $Message
}

# Step 1: Create Test Issues (if not skipping)
if (-not $CleanupOnly -and -not $SkipCreation) {
    Write-TestHeader "STEP 1: Creating Test Issues"
    
    Write-TestStep "Creating test Epic"
    try {
        $epic = & $newIssueScript -Owner $Owner -Repo $Repo `
            -Title "[TEST] Test Epic for Issue Type Verification" `
            -TypeName "Epic" `
            -Body @"
# Test Epic

This is a test Epic created to verify organization-level issue types work correctly.

## Purpose
- Verify Epic issue type is properly set
- Test hierarchy relationships (Epic → Feature → Task)
- Validate sub-issues API functionality

## Test Coverage
- [x] Epic creation
- [ ] Feature linked to Epic
- [ ] Task linked to Feature
- [ ] Bug issue (standalone)

**This is a test issue and should be closed after verification.**
"@
        
        $testResults.Created['Epic'] = $epic.number
        Write-TestSuccess "Created Epic #$($epic.number)"
    }
    catch {
        Write-TestFailure "Failed to create Epic: $_"
    }

    Write-TestStep "Creating test Feature linked to Epic"
    try {
        $feature = & $newIssueScript -Owner $Owner -Repo $Repo `
            -Title "[TEST] Test Feature for Issue Type Verification" `
            -TypeName "Feature" `
            -Body @"
# Test Feature

This is a test Feature created to verify Feature → Epic linking.

## Parent
Linked to Epic #$($testResults.Created['Epic'])

## Test Tasks
- [ ] Task 1: Verify Task → Feature linking
- [ ] Task 2: Verify hierarchy traversal

**This is a test issue and should be closed after verification.**
"@
        
        $testResults.Created['Feature'] = $feature.number
        Write-TestSuccess "Created Feature #$($feature.number)"
        
        # Link Feature to Epic using sub-issues API
        Write-TestStep "Linking Feature #$($feature.number) to Epic #$($testResults.Created['Epic'])"
        & $updateHierarchyScript -Owner $Owner -Repo $Repo `
            -ParentNumber $testResults.Created['Epic'] `
            -ChildNumber $feature.number
        Write-TestSuccess "Linked Feature to Epic"
    }
    catch {
        Write-TestFailure "Failed to create/link Feature: $_"
    }

    Write-TestStep "Creating test Task linked to Feature"
    try {
        $task = & $newIssueScript -Owner $Owner -Repo $Repo `
            -Title "[TEST] Test Task for Issue Type Verification" `
            -TypeName "Task" `
            -Body @"
# Test Task

This is a test Task created to verify Task → Feature linking.

## Parent
Linked to Feature #$($testResults.Created['Feature'])

## Acceptance Criteria
- [x] Task issue created with correct type
- [ ] Task properly linked to parent Feature
- [ ] Task visible in Feature's sub-issues

**This is a test issue and should be closed after verification.**
"@
        
        $testResults.Created['Task'] = $task.number
        Write-TestSuccess "Created Task #$($task.number)"
        
        # Link Task to Feature using sub-issues API
        Write-TestStep "Linking Task #$($task.number) to Feature #$($testResults.Created['Feature'])"
        & $updateHierarchyScript -Owner $Owner -Repo $Repo `
            -ParentNumber $testResults.Created['Feature'] `
            -ChildNumber $task.number
        Write-TestSuccess "Linked Task to Feature"
    }
    catch {
        Write-TestFailure "Failed to create/link Task: $_"
    }

    Write-TestStep "Creating test Bug (standalone)"
    try {
        $bug = & $newIssueScript -Owner $Owner -Repo $Repo `
            -Title "[TEST] Test Bug for Issue Type Verification" `
            -TypeName "Bug" `
            -Body @"
# Test Bug

This is a test Bug created to verify Bug issue type.

## Description
Test bug to verify organization-level Bug issue type works correctly.

## Steps to Reproduce
1. N/A - This is a test issue

## Expected Behavior
Bug issue type should be properly set

## Actual Behavior
Creating test bug to verify type system

## Environment
- Test environment
- Issue type: Bug

**This is a test issue and should be closed after verification.**
"@ `
            -Labels @("test")
        
        $testResults.Created['Bug'] = $bug.number
        Write-TestSuccess "Created Bug #$($bug.number)"
    }
    catch {
        Write-TestFailure "Failed to create Bug: $_"
    }

    Write-Host "`n" -NoNewline
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "Created test issues:" -ForegroundColor Yellow
    foreach ($type in @('Epic', 'Feature', 'Task', 'Bug')) {
        if ($testResults.Created[$type]) {
            Write-Host "  $type : #$($testResults.Created[$type])" -ForegroundColor White
        }
    }
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}
elseif ($TestIssueNumbers.Count -gt 0) {
    # Use provided issue numbers
    $testResults.Created = $TestIssueNumbers.Clone()
    Write-TestHeader "Using provided test issues"
    foreach ($type in $TestIssueNumbers.Keys) {
        Write-Host "  $type : #$($TestIssueNumbers[$type])" -ForegroundColor White
    }
}

# Step 2: Verify Hierarchies (if not cleanup-only)
if (-not $CleanupOnly) {
    Write-TestHeader "STEP 2: Verifying Issue Types and Hierarchies"
    
    # Verify Epic and its children
    if ($testResults.Created['Epic']) {
        Write-TestStep "Verifying Epic #$($testResults.Created['Epic']) hierarchy"
        try {
            & $getDagStatusScript -IssueNumber $testResults.Created['Epic'] -Format Tree -MaxDepth 3
            
            # Verify via GraphQL that types are correct
            $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $($testResults.Created['Epic'])) {
      number
      title
      issueType { name }
      subIssues(first: 50) {
        nodes {
          number
          title
          issueType { name }
          subIssues(first: 50) {
            nodes {
              number
              title
              issueType { name }
            }
          }
        }
      }
    }
  }
}
"@
            
            $result = gh api graphql -H "GraphQL-Features: sub_issues" -f query="$query" | ConvertFrom-Json
            $epicIssue = $result.data.repository.issue
            
            # Verify Epic type
            if ($epicIssue.issueType.name -eq "Epic") {
                Write-TestSuccess "Epic #$($epicIssue.number) has correct type: Epic"
                $testResults.Verified['Epic'] = $true
            }
            else {
                Write-TestFailure "Epic #$($epicIssue.number) has wrong type: $($epicIssue.issueType.name)"
            }
            
            # Verify Feature child
            if ($testResults.Created['Feature']) {
                $feature = $epicIssue.subIssues.nodes | Where-Object { $_.number -eq $testResults.Created['Feature'] }
                if ($feature) {
                    if ($feature.issueType.name -eq "Feature") {
                        Write-TestSuccess "Feature #$($feature.number) is linked to Epic and has correct type: Feature"
                        $testResults.Verified['Feature'] = $true
                    }
                    else {
                        Write-TestFailure "Feature #$($feature.number) has wrong type: $($feature.issueType.name)"
                    }
                    
                    # Verify Task grandchild
                    if ($testResults.Created['Task']) {
                        $taskNode = $feature.subIssues.nodes | Where-Object { $_.number -eq $testResults.Created['Task'] }
                        if ($taskNode) {
                            if ($taskNode.issueType.name -eq "Task") {
                                Write-TestSuccess "Task #$($taskNode.number) is linked to Feature and has correct type: Task"
                                $testResults.Verified['Task'] = $true
                            }
                            else {
                                Write-TestFailure "Task #$($taskNode.number) has wrong type: $($taskNode.issueType.name)"
                            }
                        }
                        else {
                            Write-TestFailure "Task #$($testResults.Created['Task']) is not linked to Feature #$($feature.number)"
                        }
                    }
                }
                else {
                    Write-TestFailure "Feature #$($testResults.Created['Feature']) is not linked to Epic #$($epicIssue.number)"
                }
            }
        }
        catch {
            Write-TestFailure "Failed to verify Epic hierarchy: $_"
        }
    }
    
    # Verify Bug (standalone)
    if ($testResults.Created['Bug']) {
        Write-TestStep "Verifying Bug #$($testResults.Created['Bug'])"
        try {
            $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $($testResults.Created['Bug'])) {
      number
      title
      issueType { name }
    }
  }
}
"@
            
            $result = gh api graphql -f query="$query" | ConvertFrom-Json
            $bugIssue = $result.data.repository.issue
            
            if ($bugIssue.issueType.name -eq "Bug") {
                Write-TestSuccess "Bug #$($bugIssue.number) has correct type: Bug"
                $testResults.Verified['Bug'] = $true
            }
            else {
                Write-TestFailure "Bug #$($bugIssue.number) has wrong type: $($bugIssue.issueType.name)"
            }
        }
        catch {
            Write-TestFailure "Failed to verify Bug: $_"
        }
    }
}

# Step 3: Cleanup (if not skipping)
if (-not $SkipCleanup) {
    Write-TestHeader "STEP 3: Cleanup Test Issues"
    
    Write-Host "`nDo you want to close the test issues? (Y/N): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    
    if ($response -eq 'Y' -or $response -eq 'y') {
        foreach ($type in @('Task', 'Feature', 'Epic', 'Bug')) {
            if ($testResults.Created[$type]) {
                $issueNum = $testResults.Created[$type]
                Write-TestStep "Closing $type #$issueNum"
                try {
                    # Get issue ID
                    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $issueNum) {
      id
    }
  }
}
"@
                    $result = gh api graphql -f query="$query" | ConvertFrom-Json
                    $issueId = $result.data.repository.issue.id
                    
                    # Close issue
                    $mutation = @"
mutation {
  closeIssue(input: {
    issueId: "$issueId"
  }) {
    issue {
      number
      state
    }
  }
}
"@
                    gh api graphql -f query="$mutation" | Out-Null
                    Write-TestSuccess "Closed $type #$issueNum"
                    $testResults.Cleaned[$type] = $true
                }
                catch {
                    Write-TestFailure "Failed to close $type #$issueNum : $_"
                }
            }
        }
    }
    else {
        Write-Host "`n  Test issues left open for manual inspection" -ForegroundColor Yellow
    }
}

# Final Summary
Write-TestHeader "TEST SUMMARY"

Write-Host "`nCreated Issues:" -ForegroundColor Yellow
foreach ($type in @('Epic', 'Feature', 'Task', 'Bug')) {
    if ($testResults.Created[$type]) {
        $status = if ($testResults.Verified[$type]) { "✓ Verified" } else { "⚠ Not Verified" }
        $color = if ($testResults.Verified[$type]) { "Green" } else { "Yellow" }
        Write-Host "  $type #$($testResults.Created[$type]) - $status" -ForegroundColor $color
    }
}

if ($testResults.Errors.Count -gt 0) {
    Write-Host "`nErrors:" -ForegroundColor Red
    foreach ($error in $testResults.Errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
}

Write-Host "`nOverall Status: " -NoNewline
if ($testResults.Success -and $testResults.Verified.Count -eq 4) {
    Write-Host "SUCCESS ✓" -ForegroundColor Green
    Write-Host "All issue types created and verified correctly!" -ForegroundColor Green
}
elseif ($testResults.Success) {
    Write-Host "PARTIAL SUCCESS" -ForegroundColor Yellow
    Write-Host "Some verifications were skipped or incomplete" -ForegroundColor Yellow
}
else {
    Write-Host "FAILURE ✗" -ForegroundColor Red
    Write-Host "Some tests failed. Please review errors above." -ForegroundColor Red
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

# Return test results for programmatic use
return $testResults
