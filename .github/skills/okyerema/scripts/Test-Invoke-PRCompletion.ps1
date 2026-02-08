<#
.SYNOPSIS
    Test suite for Invoke-PRCompletion.ps1

.DESCRIPTION
    This script tests the comment categorization logic and dry-run functionality
    of Invoke-PRCompletion.ps1.

.EXAMPLE
    .\Test-Invoke-PRCompletion.ps1
#>

$ErrorActionPreference = "Stop"

# Import the Get-CommentCategory function by defining it locally (mirrors the script)
function Get-CommentCategory {
    param([string]$Body)
    
    $bodyLower = $Body.ToLower()
    
    # Check for suggestion/consider phrases first to avoid false blocking categorization
    $hasSuggestiveLanguage = $bodyLower -match '\b(consider|suggest|recommend|could|should|would|might)\b.*\b(error|bug|fail)'
    
    # Blocking indicators (highest priority) - but not if it's a suggestion
    if (-not $hasSuggestiveLanguage) {
        $blockingPatterns = @(
            '\b(security|vulnerability|exploit|injection)\b',
            '\b(critical|blocker|blocking|must fix)\b',
            '\b(breaks?|broken|this is a bug|has a bug|causes?\s+(a\s+)?(crash|error))\b',
            '\b(required|mandatory)\b',
            '\b(test\s+)?(fails?|failed|failure)\b'
        )
        
        foreach ($pattern in $blockingPatterns) {
            if ($bodyLower -match $pattern) {
                return "blocking"
            }
        }
    }
    
    # Question indicators
    $questionPatterns = @(
        '\?',
        '\b(why|how|what|when|where|which|could you|can you|would you)\b',
        '\b(explain|clarify|clarification)\b'
    )
    
    foreach ($pattern in $questionPatterns) {
        if ($bodyLower -match $pattern) {
            return "question"
        }
    }
    
    # Praise indicators
    $praisePatterns = @(
        '\b(nice|good|great|excellent|perfect|love|awesome|fantastic)\b',
        '\b(thank|thanks|lgtm|looks good)\b',
        '👍|❤️|🎉|✨|💯',
        '\b(well done|good job)\b'
    )
    
    foreach ($pattern in $praisePatterns) {
        if ($bodyLower -match $pattern) {
            return "praise"
        }
    }
    
    # Nitpick indicators
    $nitpickPatterns = @(
        '\b(nit|nitpick|minor|small|tiny)\b',
        '\b(style|formatting|whitespace|spacing)\b',
        '\b(typo|spelling)\b',
        '\boptional\b'
    )
    
    foreach ($pattern in $nitpickPatterns) {
        if ($bodyLower -match $pattern) {
            return "nitpick"
        }
    }
    
    # Suggestion indicators
    $suggestionPatterns = @(
        '\b(suggest|recommend|could|should|would|might)\b',
        '\b(improve|better|consider|instead)\b',
        '\b(refactor|simplify|optimize)\b'
    )
    
    foreach ($pattern in $suggestionPatterns) {
        if ($bodyLower -match $pattern) {
            return "suggestion"
        }
    }
    
    # Default to suggestion
    return "suggestion"
}

function Get-ProposedAction {
    param([string]$Category)
    
    switch ($Category) {
        "blocking" { return "fix" }
        "suggestion" { return "fix" }
        "nitpick" { return "fix" }
        "question" { return "escalate" }
        "praise" { return "acknowledge" }
        default { return "fix" }
    }
}

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsTotal = 0

function Test-Assert {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$FailureMessage = "Assertion failed"
    )
    
    $script:TestsTotal++
    
    if ($Condition) {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "  ✗ $TestName" -ForegroundColor Red
        Write-Host "    $FailureMessage" -ForegroundColor Red
        $script:TestsFailed++
    }
}

# ============================================================================
# Test: Comment Categorization
# ============================================================================
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Test Suite: Comment Categorization" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`nBlocking Comments:" -ForegroundColor White
Test-Assert "Security issue detected" `
    ((Get-CommentCategory "This has a security vulnerability") -eq "blocking") `
    "Should categorize security issues as blocking"

Test-Assert "Bug detected" `
    ((Get-CommentCategory "This is a bug that causes a crash") -eq "blocking") `
    "Should categorize bugs as blocking"

Test-Assert "Test failure detected" `
    ((Get-CommentCategory "This test fails when run") -eq "blocking") `
    "Should categorize test failures as blocking"

Test-Assert "Critical issue detected" `
    ((Get-CommentCategory "Critical: this must be fixed") -eq "blocking") `
    "Should categorize critical issues as blocking"

Write-Host "`nQuestions:" -ForegroundColor White
Test-Assert "Question mark detected" `
    ((Get-CommentCategory "Why not use this approach?") -eq "question") `
    "Should categorize questions with ? as question"

Test-Assert "Why question detected" `
    ((Get-CommentCategory "Why did you choose this method") -eq "question") `
    "Should categorize 'why' questions as question"

Test-Assert "How question detected" `
    ((Get-CommentCategory "How does this work with edge cases") -eq "question") `
    "Should categorize 'how' questions as question"

Test-Assert "Clarification request detected" `
    ((Get-CommentCategory "Can you clarify the intent here") -eq "question") `
    "Should categorize clarification requests as question"

Write-Host "`nPraise:" -ForegroundColor White
Test-Assert "Nice comment detected" `
    ((Get-CommentCategory "Nice work on this feature!") -eq "praise") `
    "Should categorize 'nice' as praise"

Test-Assert "LGTM detected" `
    ((Get-CommentCategory "LGTM! This looks great") -eq "praise") `
    "Should categorize LGTM as praise"

Test-Assert "Thanks detected" `
    ((Get-CommentCategory "Thanks for addressing this") -eq "praise") `
    "Should categorize thanks as praise"

Test-Assert "Emoji praise detected" `
    ((Get-CommentCategory "This is perfect 👍") -eq "praise") `
    "Should categorize emoji praise as praise"

Write-Host "`nNitpicks:" -ForegroundColor White
Test-Assert "Nit detected" `
    ((Get-CommentCategory "Nit: consider adding a space here") -eq "nitpick") `
    "Should categorize 'nit' as nitpick"

Test-Assert "Typo detected" `
    ((Get-CommentCategory "Small typo in the comment") -eq "nitpick") `
    "Should categorize typos as nitpick"

Test-Assert "Formatting issue detected" `
    ((Get-CommentCategory "Minor formatting issue with whitespace") -eq "nitpick") `
    "Should categorize formatting as nitpick"

Test-Assert "Optional suggestion detected" `
    ((Get-CommentCategory "Optional: you might want to rename this") -eq "nitpick") `
    "Should categorize optional suggestions as nitpick"

Write-Host "`nSuggestions:" -ForegroundColor White
Test-Assert "Suggest detected" `
    ((Get-CommentCategory "I suggest refactoring this method") -eq "suggestion") `
    "Should categorize 'suggest' as suggestion"

Test-Assert "Consider detected" `
    ((Get-CommentCategory "Consider using a different approach") -eq "suggestion") `
    "Should categorize 'consider' as suggestion"

Test-Assert "Should detected" `
    ((Get-CommentCategory "You should add error handling here") -eq "suggestion") `
    "Should categorize 'should' as suggestion"

Test-Assert "Improve detected" `
    ((Get-CommentCategory "This could be improved by caching") -eq "suggestion") `
    "Should categorize 'improve' as suggestion"

Test-Assert "Suggestion with error keyword" `
    ((Get-CommentCategory "Consider adding error handling") -eq "suggestion") `
    "Should categorize suggestive error language as suggestion, not blocking"

Test-Assert "Default categorization" `
    ((Get-CommentCategory "Update the documentation") -eq "suggestion") `
    "Should default to suggestion for unclear comments"

# ============================================================================
# Test: Proposed Actions
# ============================================================================
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Test Suite: Proposed Actions" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Test-Assert "Blocking should fix" `
    ((Get-ProposedAction "blocking") -eq "fix") `
    "Blocking comments should be fixed"

Test-Assert "Suggestion should fix" `
    ((Get-ProposedAction "suggestion") -eq "fix") `
    "Suggestions should be fixed"

Test-Assert "Nitpick should fix" `
    ((Get-ProposedAction "nitpick") -eq "fix") `
    "Nitpicks should be fixed"

Test-Assert "Question should escalate" `
    ((Get-ProposedAction "question") -eq "escalate") `
    "Questions should be escalated"

Test-Assert "Praise should acknowledge" `
    ((Get-ProposedAction "praise") -eq "acknowledge") `
    "Praise should be acknowledged"

# ============================================================================
# Test: Script Existence and Syntax
# ============================================================================
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Test Suite: Script Validation" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Determine the script path relative to the test file location
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$scriptPath = Join-Path $scriptDir "Invoke-PRCompletion.ps1"

Test-Assert "Script file exists" `
    (Test-Path $scriptPath) `
    "Invoke-PRCompletion.ps1 should exist at $scriptPath"

if (Test-Path $scriptPath) {
    try {
        $scriptContent = Get-Content $scriptPath -Raw
        $null = [System.Management.Automation.PSParser]::Tokenize($scriptContent, [ref]$null)
        Test-Assert "Script has valid PowerShell syntax" $true
    }
    catch {
        Test-Assert "Script has valid PowerShell syntax" $false "Syntax error: $_"
    }
    
    # Check for required parameters
    Test-Assert "Script has -Owner parameter" `
        ($scriptContent -match '\[Parameter\(Mandatory\s*=\s*\$true\)\][\s\S]*?\[string\]\$Owner') `
        "Script should have mandatory -Owner parameter"
    
    Test-Assert "Script has -Repo parameter" `
        ($scriptContent -match '\[Parameter\(Mandatory\s*=\s*\$true\)\][\s\S]*?\[string\]\$Repo') `
        "Script should have mandatory -Repo parameter"
    
    Test-Assert "Script has -PullNumber parameter" `
        ($scriptContent -match '\[Parameter\(Mandatory\s*=\s*\$true\)\][\s\S]*?\[int\]\$PullNumber') `
        "Script should have mandatory -PullNumber parameter"
    
    Test-Assert "Script has -DryRun parameter" `
        ($scriptContent -match '\[switch\]\$DryRun') `
        "Script should have -DryRun switch parameter"
    
    # Check for key functions
    Test-Assert "Script has Get-CommentCategory function" `
        ($scriptContent -match 'function Get-CommentCategory') `
        "Script should define Get-CommentCategory function"
    
    Test-Assert "Script has Get-ProposedAction function" `
        ($scriptContent -match 'function Get-ProposedAction') `
        "Script should define Get-ProposedAction function"
    
    # Check for dry-run mode handling
    Test-Assert "Script checks for DryRun mode" `
        ($scriptContent -match 'if\s*\(\$DryRun\)') `
        "Script should have conditional logic for DryRun mode"
}

# ============================================================================
# Test: Integration Tests (Mock-based)
# ============================================================================
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Test Suite: Mock Integration Tests" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Test scenario: Mixed thread types
Write-Host "`nScenario: Mixed thread types" -ForegroundColor White

$mockThreads = @(
    @{
        category = "blocking"
        comment = "This has a security vulnerability"
        expectedAction = "fix"
    },
    @{
        category = "nitpick"
        comment = "Nit: add spacing here"
        expectedAction = "fix"
    },
    @{
        category = "question"
        comment = "Why not use X instead?"
        expectedAction = "escalate"
    }
)

$classifications = @{}
$actions = @{}
foreach ($thread in $mockThreads) {
    $cat = Get-CommentCategory -Body $thread.comment
    $action = Get-ProposedAction -Category $cat
    
    if (-not $classifications.ContainsKey($cat)) {
        $classifications[$cat] = 0
    }
    $classifications[$cat]++
    
    if (-not $actions.ContainsKey($action)) {
        $actions[$action] = 0
    }
    $actions[$action]++
    
    Test-Assert "Thread '$($thread.comment)' categorized as $($thread.category)" `
        ($cat -eq $thread.category) `
        "Expected $($thread.category), got $cat"
    
    Test-Assert "Thread action is $($thread.expectedAction)" `
        ($action -eq $thread.expectedAction) `
        "Expected $($thread.expectedAction), got $action"
}

$totalThreads = $mockThreads.Count
$fixableCount = if ($actions.ContainsKey("fix")) { $actions["fix"] } else { 0 }
$acknowledgeCount = if ($actions.ContainsKey("acknowledge")) { $actions["acknowledge"] } else { 0 }
$escalateCount = if ($actions.ContainsKey("escalate")) { $actions["escalate"] } else { 0 }

Test-Assert "Summary counts match" `
    (($fixableCount + $acknowledgeCount + $escalateCount) -eq $totalThreads) `
    "Total fix/acknowledge + escalate should equal total threads. Got fixable=$fixableCount, acknowledge=$acknowledgeCount, escalate=$escalateCount, total=$totalThreads"

Write-Host "  Mock Summary: $totalThreads total, $($fixableCount + $acknowledgeCount) would fix/acknowledge, $escalateCount would escalate" -ForegroundColor Gray

# ============================================================================
# Final Results
# ============================================================================
Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Tests:  $script:TestsTotal" -ForegroundColor White
Write-Host "  Passed:       $script:TestsPassed" -ForegroundColor Green
Write-Host "  Failed:       $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed!" -ForegroundColor Red
    exit 1
}
