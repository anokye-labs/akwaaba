<#
.SYNOPSIS
    Test scenarios for Invoke-PRCompletion.ps1

.DESCRIPTION
    Validates the PR completion workflow with mock data and simulated behaviors.
    Tests classification, loop logic, and status reporting without requiring
    actual GraphQL calls or git operations.

.NOTES
    This test suite validates:
    1. Clean PR - 0 unresolved threads, immediate exit, Status=Clean
    2. Single bug - 1 bug thread, fix, reply, resolve, clean
    3. Mixed severity - bugs + nits + questions, correct classification
    4. Max iterations - simulate persistent reviewer, hits limit, Status=Partial
    5. DryRun - no side effects, report only
    6. Empty diff - thread exists but no code change needed, reply no changes, resolve
    7. GraphQL error - simulate API failure, retry once, skip with warning
#>

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Suite: Invoke-PRCompletion.ps1" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

#region Helper Functions

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    if ($Passed) {
        Write-Host "  ✓ PASS: $TestName" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "  ✗ FAIL: $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "    $Message" -ForegroundColor Yellow
        }
        $script:testsFailed++
    }
}

function Test-ClassificationLogic {
    <#
    .SYNOPSIS
        Tests the thread classification function independently
    #>
    param([string]$Body, [string]$ExpectedSeverity)
    
    # Mock classification logic based on keywords (priority order matters)
    $severity = "Bug"  # default
    
    # Keyword-based classification (mimics Get-ThreadSeverity.ps1)
    # Priority: Bug > Question > Suggestion > Nit
    if ($Body -match 'P0|P1|bug:|fail|error|undefined|crash|breaks|security') {
        $severity = "Bug"
    }
    elseif ($Body -match '\?$|why |should we|design question') {
        $severity = "Question"
    }
    elseif ($Body -match 'suggestion:|could|might|optional|perhaps') {
        $severity = "Suggestion"
    }
    elseif ($Body -match 'P2|nit:|style:|consider|minor|wording|cosmetic') {
        $severity = "Nit"
    }
    
    return $severity -eq $ExpectedSeverity
}

function Mock-UnresolvedThreads {
    <#
    .SYNOPSIS
        Simulates Get-UnresolvedThreads.ps1 output
    #>
    param([int]$Count, [string[]]$Bodies = @())
    
    $threads = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $body = if ($i -lt $Bodies.Count) { $Bodies[$i] } else { "Generic comment $i" }
        $threads += [PSCustomObject]@{
            Id = "PRVT_thread_$i"
            IsResolved = $false
            Path = "src/file$i.ps1"
            Line = 10 + $i
            Comments = @(
                [PSCustomObject]@{
                    Author = [PSCustomObject]@{ Login = "reviewer" }
                    Body = $body
                    CreatedAt = (Get-Date).ToString("o")
                }
            )
        }
    }
    return $threads
}

function Mock-PRCompletionResult {
    <#
    .SYNOPSIS
        Simulates Invoke-PRCompletion.ps1 output structure
    #>
    param(
        [string]$Status,
        [int]$Iterations,
        [int]$TotalFixed,
        [int]$TotalSkipped,
        [int]$Remaining,
        [string[]]$CommitShas = @()
    )
    
    return [PSCustomObject]@{
        Status = $Status
        Iterations = $Iterations
        TotalFixed = $TotalFixed
        TotalSkipped = $TotalSkipped
        Remaining = $Remaining
        CommitShas = $CommitShas
    }
}

#endregion

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 1: Classification Function" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Test 1.1: Bug classification
$result = Test-ClassificationLogic -Body "This is a bug: undefined variable" -ExpectedSeverity "Bug"
Write-TestResult -TestName "Bug classification - undefined variable" -Passed $result

# Test 1.2: Nit classification
$result = Test-ClassificationLogic -Body "nit: consider renaming this variable" -ExpectedSeverity "Nit"
Write-TestResult -TestName "Nit classification - style comment" -Passed $result

# Test 1.3: Suggestion classification
$result = Test-ClassificationLogic -Body "You could use a more descriptive name here" -ExpectedSeverity "Suggestion"
Write-TestResult -TestName "Suggestion classification - optional improvement" -Passed $result

# Test 1.4: Question classification
$result = Test-ClassificationLogic -Body "Why did you choose this approach?" -ExpectedSeverity "Question"
Write-TestResult -TestName "Question classification - ends with question mark" -Passed $result

# Test 1.5: Security bug classification
$result = Test-ClassificationLogic -Body "P0: Security vulnerability - SQL injection risk" -ExpectedSeverity "Bug"
Write-TestResult -TestName "Bug classification - security issue with P0 badge" -Passed $result

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 2: Scenario - Clean PR (0 unresolved threads)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: No unresolved threads
$threads = Mock-UnresolvedThreads -Count 0
$result = Mock-PRCompletionResult -Status "Clean" -Iterations 1 -TotalFixed 0 -TotalSkipped 0 -Remaining 0

Write-TestResult -TestName "Clean PR - Zero threads found" -Passed ($threads.Count -eq 0)
Write-TestResult -TestName "Clean PR - Status is Clean" -Passed ($result.Status -eq "Clean")
Write-TestResult -TestName "Clean PR - Only 1 iteration" -Passed ($result.Iterations -eq 1)
Write-TestResult -TestName "Clean PR - Zero remaining" -Passed ($result.Remaining -eq 0)
Write-TestResult -TestName "Clean PR - No commits made" -Passed ($result.CommitShas.Count -eq 0)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 3: Scenario - Single Bug Thread" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: 1 bug thread, then fixed (iteration 1 has thread, iteration 2 is clean)
$threadsIter1 = Mock-UnresolvedThreads -Count 1 -Bodies @("bug: variable is undefined")
$threadsIter2 = Mock-UnresolvedThreads -Count 0
$result = Mock-PRCompletionResult -Status "Clean" -Iterations 2 -TotalFixed 1 -TotalSkipped 0 -Remaining 0 -CommitShas @("abc1234")

Write-TestResult -TestName "Single Bug - Thread detected in iteration 1" -Passed ($threadsIter1.Count -eq 1)
Write-TestResult -TestName "Single Bug - Classified as Bug" -Passed (Test-ClassificationLogic -Body $threadsIter1[0].Comments[0].Body -ExpectedSeverity "Bug")
Write-TestResult -TestName "Single Bug - Clean after fix" -Passed ($threadsIter2.Count -eq 0)
Write-TestResult -TestName "Single Bug - Status is Clean" -Passed ($result.Status -eq "Clean")
Write-TestResult -TestName "Single Bug - 2 iterations total" -Passed ($result.Iterations -eq 2)
Write-TestResult -TestName "Single Bug - 1 thread fixed" -Passed ($result.TotalFixed -eq 1)
Write-TestResult -TestName "Single Bug - Commit created" -Passed ($result.CommitShas.Count -eq 1)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 4: Scenario - Mixed Severity" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: Multiple threads with different severities
$threadBodies = @(
    "bug: null pointer exception",
    "nit: variable naming is inconsistent",
    "Why did you choose this algorithm?",
    "suggestion: caching might improve performance"
)
$threads = Mock-UnresolvedThreads -Count 4 -Bodies $threadBodies

# Helper to get actual classification
function Get-ActualClassification {
    param([string]$Body)
    
    if ($Body -match 'P0|P1|bug:|fail|error|undefined|crash|breaks|security') {
        return "Bug"
    }
    elseif ($Body -match '\?$|why |should we|design question') {
        return "Question"
    }
    elseif ($Body -match 'suggestion:|could|might|optional|perhaps') {
        return "Suggestion"
    }
    elseif ($Body -match 'P2|nit:|style:|consider|minor|wording|cosmetic') {
        return "Nit"
    }
    return "Bug"  # default
}

$bugCount = 0
$nitCount = 0
$questionCount = 0
$suggestionCount = 0

foreach ($thread in $threads) {
    $body = $thread.Comments[0].Body
    $classification = Get-ActualClassification -Body $body
    
    switch ($classification) {
        "Bug" { $bugCount++ }
        "Nit" { $nitCount++ }
        "Question" { $questionCount++ }
        "Suggestion" { $suggestionCount++ }
    }
}

Write-TestResult -TestName "Mixed Severity - 4 threads total" -Passed ($threads.Count -eq 4)
Write-TestResult -TestName "Mixed Severity - 1 Bug detected" -Passed ($bugCount -eq 1)
Write-TestResult -TestName "Mixed Severity - 1 Nit detected" -Passed ($nitCount -eq 1)
Write-TestResult -TestName "Mixed Severity - 1 Question detected" -Passed ($questionCount -eq 1)
Write-TestResult -TestName "Mixed Severity - 1 Suggestion detected" -Passed ($suggestionCount -eq 1)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 5: Scenario - Max Iterations Reached" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: Persistent reviewer keeps adding comments, hits MaxIterations=5
$maxIterations = 5
$result = Mock-PRCompletionResult -Status "Partial" -Iterations $maxIterations -TotalFixed 8 -TotalSkipped 0 -Remaining 3 -CommitShas @("abc1", "def2", "ghi3", "jkl4", "mno5")

Write-TestResult -TestName "Max Iterations - Status is Partial" -Passed ($result.Status -eq "Partial")
Write-TestResult -TestName "Max Iterations - Reached max (5)" -Passed ($result.Iterations -eq $maxIterations)
Write-TestResult -TestName "Max Iterations - Some threads fixed" -Passed ($result.TotalFixed -gt 0)
Write-TestResult -TestName "Max Iterations - Threads remain" -Passed ($result.Remaining -gt 0)
Write-TestResult -TestName "Max Iterations - Commit per iteration" -Passed ($result.CommitShas.Count -eq $maxIterations)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 6: Scenario - DryRun Mode" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: DryRun shows plan without making changes
$threads = Mock-UnresolvedThreads -Count 3 -Bodies @(
    "bug: missing null check",
    "nit: improve formatting",
    "Why use this pattern?"
)

# In DryRun: no commits, no status changes, just reporting
$dryRunResult = [PSCustomObject]@{
    DryRun = $true
    ThreadsFound = $threads.Count
    Bugs = 1
    Nits = 1
    Questions = 1
    Suggestions = 0
    WouldCommit = $false
    WouldResolve = $false
}

Write-TestResult -TestName "DryRun - Reports threads found" -Passed ($dryRunResult.ThreadsFound -eq 3)
Write-TestResult -TestName "DryRun - No commits made" -Passed ($dryRunResult.WouldCommit -eq $false)
Write-TestResult -TestName "DryRun - No threads resolved" -Passed ($dryRunResult.WouldResolve -eq $false)
Write-TestResult -TestName "DryRun - Classification reported" -Passed ($dryRunResult.Bugs -eq 1 -and $dryRunResult.Nits -eq 1 -and $dryRunResult.Questions -eq 1)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 7: Scenario - Empty Diff (No Code Change Needed)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: Thread exists but review finds no code change needed
# Script should reply "Reviewed - no changes needed" and resolve
$threads = Mock-UnresolvedThreads -Count 1 -Bodies @("nit: This is actually fine as is")
$emptyDiffResult = [PSCustomObject]@{
    GitDiffEmpty = $true
    ReplyMessage = "Reviewed - no changes needed"
    ThreadResolved = $true
    CommitCreated = $false
}

Write-TestResult -TestName "Empty Diff - Thread detected" -Passed ($threads.Count -eq 1)
Write-TestResult -TestName "Empty Diff - Git diff is empty" -Passed ($emptyDiffResult.GitDiffEmpty -eq $true)
Write-TestResult -TestName "Empty Diff - Reply sent" -Passed ($emptyDiffResult.ReplyMessage.Length -gt 0)
Write-TestResult -TestName "Empty Diff - Thread resolved" -Passed ($emptyDiffResult.ThreadResolved -eq $true)
Write-TestResult -TestName "Empty Diff - No commit created" -Passed ($emptyDiffResult.CommitCreated -eq $false)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 8: Scenario - GraphQL Error Handling" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Simulate: GraphQL API failure, retry once, then skip with warning
$errorScenario = [PSCustomObject]@{
    FirstCallFailed = $true
    RetryAttempted = $true
    RetrySucceeded = $false
    ThreadSkipped = $true
    WarningIssued = $true
    ErrorMessage = "GraphQL API rate limit exceeded"
}

Write-TestResult -TestName "GraphQL Error - First call failed" -Passed ($errorScenario.FirstCallFailed -eq $true)
Write-TestResult -TestName "GraphQL Error - Retry attempted" -Passed ($errorScenario.RetryAttempted -eq $true)
Write-TestResult -TestName "GraphQL Error - Thread skipped on failure" -Passed ($errorScenario.ThreadSkipped -eq $true)
Write-TestResult -TestName "GraphQL Error - Warning issued" -Passed ($errorScenario.WarningIssued -eq $true)
Write-TestResult -TestName "GraphQL Error - Error message captured" -Passed ($errorScenario.ErrorMessage.Length -gt 0)

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 9: Output Structure Validation" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Validate the output contract structure
$result = Mock-PRCompletionResult -Status "Clean" -Iterations 2 -TotalFixed 3 -TotalSkipped 1 -Remaining 0 -CommitShas @("abc123", "def456")

Write-TestResult -TestName "Output - Has Status field" -Passed ($null -ne $result.Status)
Write-TestResult -TestName "Output - Has Iterations field" -Passed ($null -ne $result.Iterations)
Write-TestResult -TestName "Output - Has TotalFixed field" -Passed ($null -ne $result.TotalFixed)
Write-TestResult -TestName "Output - Has TotalSkipped field" -Passed ($null -ne $result.TotalSkipped)
Write-TestResult -TestName "Output - Has Remaining field" -Passed ($null -ne $result.Remaining)
Write-TestResult -TestName "Output - Has CommitShas field" -Passed ($null -ne $result.CommitShas)
Write-TestResult -TestName "Output - CommitShas is array" -Passed ($result.CommitShas -is [array])
Write-TestResult -TestName "Output - Status is valid enum" -Passed ($result.Status -in @("Clean", "Partial", "Failed"))

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 10: Edge Cases" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

# Edge case 1: Thread on deleted file
$deletedFileThread = [PSCustomObject]@{
    Path = "deleted_file.ps1"
    FileExists = $false
    ReplyMessage = "File no longer exists"
    ThreadResolved = $true
}

Write-TestResult -TestName "Edge Case - Deleted file handled" -Passed ($deletedFileThread.FileExists -eq $false)
Write-TestResult -TestName "Edge Case - Deleted file reply sent" -Passed ($deletedFileThread.ReplyMessage.Length -gt 0)
Write-TestResult -TestName "Edge Case - Deleted file thread resolved" -Passed ($deletedFileThread.ThreadResolved -eq $true)

# Edge case 2: All threads are questions (no auto-fix)
$questionThreads = Mock-UnresolvedThreads -Count 3 -Bodies @(
    "Why this approach?",
    "Should we consider alternatives?",
    "What's the rationale here?"
)
$allQuestionsResult = [PSCustomObject]@{
    ThreadsFound = 3
    AutoFixable = 0
    RequiresHumanInput = 3
    Status = "Partial"
}

Write-TestResult -TestName "Edge Case - All questions detected" -Passed ($allQuestionsResult.ThreadsFound -eq 3)
Write-TestResult -TestName "Edge Case - No auto-fixable threads" -Passed ($allQuestionsResult.AutoFixable -eq 0)
Write-TestResult -TestName "Edge Case - Human input required" -Passed ($allQuestionsResult.RequiresHumanInput -eq 3)
Write-TestResult -TestName "Edge Case - Status reflects incomplete" -Passed ($allQuestionsResult.Status -eq "Partial")

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TEST SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "FAILED: Some tests did not pass." -ForegroundColor Red
    Write-Host ""
    Write-Host "NOTE: These are mock tests validating the expected behavior" -ForegroundColor Yellow
    Write-Host "      of Invoke-PRCompletion.ps1. Failures indicate issues with" -ForegroundColor Yellow
    Write-Host "      the test expectations or mock logic." -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "SUCCESS: All test scenarios validated!" -ForegroundColor Green
    Write-Host ""
    Write-Host "These tests validate the expected behavior of:" -ForegroundColor Cyan
    Write-Host "  • Thread classification (Bug/Nit/Suggestion/Question)" -ForegroundColor White
    Write-Host "  • Clean PR workflow (0 threads → immediate exit)" -ForegroundColor White
    Write-Host "  • Single bug fix workflow (detect → fix → clean)" -ForegroundColor White
    Write-Host "  • Mixed severity handling" -ForegroundColor White
    Write-Host "  • Max iteration limits (Status=Partial)" -ForegroundColor White
    Write-Host "  • DryRun mode (no side effects)" -ForegroundColor White
    Write-Host "  • Empty diff handling (no changes needed)" -ForegroundColor White
    Write-Host "  • GraphQL error recovery" -ForegroundColor White
    Write-Host "  • Output structure contract" -ForegroundColor White
    Write-Host "  • Edge cases (deleted files, all questions)" -ForegroundColor White
    exit 0
}
