<#
.SYNOPSIS
    Test suite for Get-ThreadSeverity.ps1

.DESCRIPTION
    This script tests the severity classification logic in Get-ThreadSeverity.ps1.
    Tests cover bot badge parsing, keyword matching, and edge cases.

.EXAMPLE
    .\Test-Get-ThreadSeverity.ps1
#>

$ErrorActionPreference = "Stop"

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptDir "Get-ThreadSeverity.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "✗ ERROR: Get-ThreadSeverity.ps1 not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Test Suite: Get-ThreadSeverity.ps1                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$passed = 0
$failed = 0

function Test-Severity {
    param(
        [string]$TestName,
        [string]$Body,
        [string]$AuthorLogin,
        [string]$Expected
    )
    
    try {
        $result = & $scriptPath -Body $Body -AuthorLogin $AuthorLogin
        $success = $result -eq $Expected
        
        if ($success) {
            $script:passed++
            Write-Host "✓ " -ForegroundColor Green -NoNewline
            Write-Host "$TestName" -ForegroundColor White
        }
        else {
            $script:failed++
            Write-Host "✗ " -ForegroundColor Red -NoNewline
            Write-Host "$TestName" -ForegroundColor White
            Write-Host "  Expected: $Expected" -ForegroundColor Yellow
            Write-Host "  Got:      $result" -ForegroundColor Red
            Write-Host "  Body:     $Body" -ForegroundColor Gray
            Write-Host "  Author:   $AuthorLogin" -ForegroundColor Gray
        }
    }
    catch {
        $script:failed++
        Write-Host "✗ " -ForegroundColor Red -NoNewline
        Write-Host "$TestName (Exception)" -ForegroundColor White
        Write-Host "  Error: $_" -ForegroundColor Yellow
    }
}

# ============================================================================
# Required Tests from Issue
# ============================================================================

Write-Host "Required Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Devin comment with P2 badge → Nit" `
    -Body "P2: This variable name could be more descriptive" `
    -AuthorLogin "devin" `
    -Expected "Nit"

Test-Severity `
    -TestName "Copilot comment with red emoji → Bug" `
    -Body "🔴 This function has undefined behavior" `
    -AuthorLogin "copilot" `
    -Expected "Bug"

Test-Severity `
    -TestName "Comment with 'consider renaming' → Nit" `
    -Body "Consider renaming this variable for clarity" `
    -AuthorLogin "reviewer123" `
    -Expected "Nit"

Test-Severity `
    -TestName "Comment ending with ? → Question" `
    -Body "Why did you choose this approach?" `
    -AuthorLogin "user456" `
    -Expected "Question"

Test-Severity `
    -TestName "Plain 'undefined variable' → Bug" `
    -Body "undefined variable reference" `
    -AuthorLogin "coder789" `
    -Expected "Bug"

Write-Host ""

# ============================================================================
# Bot Badge Tests
# ============================================================================

Write-Host "Bot Badge Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Devin badges
Test-Severity `
    -TestName "Devin P0 badge → Bug" `
    -Body "P0: Critical security vulnerability in authentication" `
    -AuthorLogin "devin" `
    -Expected "Bug"

Test-Severity `
    -TestName "Devin P1 badge → Bug" `
    -Body "P1: Memory leak in main loop" `
    -AuthorLogin "devin" `
    -Expected "Bug"

Test-Severity `
    -TestName "Devin P2 badge → Nit" `
    -Body "P2: Variable naming convention" `
    -AuthorLogin "devin" `
    -Expected "Nit"

Test-Severity `
    -TestName "Devin-like name with P2 → Nit" `
    -Body "P2: Code style issue" `
    -AuthorLogin "devin-agent" `
    -Expected "Nit"

# Copilot badges
Test-Severity `
    -TestName "Copilot red emoji → Bug" `
    -Body "🔴 Error handling is missing here" `
    -AuthorLogin "copilot" `
    -Expected "Bug"

Test-Severity `
    -TestName "Copilot yellow emoji → Suggestion" `
    -Body "🟡 This could be refactored for better readability" `
    -AuthorLogin "copilot" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Copilot with :red_circle: markdown → Bug" `
    -Body ":red_circle: This breaks the build" `
    -AuthorLogin "copilot" `
    -Expected "Bug"

Test-Severity `
    -TestName "Copilot with :yellow_circle: markdown → Suggestion" `
    -Body ":yellow_circle: Consider using a different pattern" `
    -AuthorLogin "copilot" `
    -Expected "Suggestion"

Write-Host ""

# ============================================================================
# Question Tests
# ============================================================================

Write-Host "Question Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Question with ? → Question" `
    -Body "Is this the right approach?" `
    -AuthorLogin "user1" `
    -Expected "Question"

Test-Severity `
    -TestName "Question with 'why' → Question" `
    -Body "Why is this needed?" `
    -AuthorLogin "user2" `
    -Expected "Question"

Test-Severity `
    -TestName "Question with 'how' → Question" `
    -Body "How does this work?" `
    -AuthorLogin "user3" `
    -Expected "Question"

Test-Severity `
    -TestName "Question with 'could you' → Question" `
    -Body "Could you explain this logic?" `
    -AuthorLogin "user4" `
    -Expected "Question"

Test-Severity `
    -TestName "Question with 'should we' → Question" `
    -Body "Should we use a different pattern here?" `
    -AuthorLogin "user5" `
    -Expected "Question"

Test-Severity `
    -TestName "Design question → Question" `
    -Body "Is this design correct?" `
    -AuthorLogin "architect" `
    -Expected "Question"

Write-Host ""

# ============================================================================
# Nit Tests
# ============================================================================

Write-Host "Nit Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Nit with 'nit:' prefix → Nit" `
    -Body "nit: missing trailing comma" `
    -AuthorLogin "reviewer" `
    -Expected "Nit"

Test-Severity `
    -TestName "Style issue → Nit" `
    -Body "Style: use single quotes instead of double" `
    -AuthorLogin "linter" `
    -Expected "Nit"

Test-Severity `
    -TestName "Minor wording → Nit" `
    -Body "Minor: this wording could be clearer" `
    -AuthorLogin "editor" `
    -Expected "Nit"

Test-Severity `
    -TestName "Typo → Nit" `
    -Body "Typo in the comment above" `
    -AuthorLogin "proofreader" `
    -Expected "Nit"

Test-Severity `
    -TestName "Cosmetic change → Nit" `
    -Body "This is just a cosmetic change" `
    -AuthorLogin "designer" `
    -Expected "Nit"

Test-Severity `
    -TestName "Consider renaming → Nit" `
    -Body "Consider renaming userId to userID" `
    -AuthorLogin "coder" `
    -Expected "Nit"

Test-Severity `
    -TestName "Consider moving → Nit" `
    -Body "Consider moving this function to a helper file" `
    -AuthorLogin "architect" `
    -Expected "Nit"

Test-Severity `
    -TestName "Whitespace issue → Nit" `
    -Body "Extra whitespace at end of line" `
    -AuthorLogin "formatter" `
    -Expected "Nit"

Test-Severity `
    -TestName "Trailing comma → Nit" `
    -Body "Missing trailing comma in array" `
    -AuthorLogin "linter" `
    -Expected "Nit"

Write-Host ""

# ============================================================================
# Suggestion Tests
# ============================================================================

Write-Host "Suggestion Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Suggestion keyword → Suggestion" `
    -Body "I suggest using a map instead of an array here" `
    -AuthorLogin "advisor" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Recommend keyword → Suggestion" `
    -Body "I recommend adding error handling" `
    -AuthorLogin "expert" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Could improve → Suggestion" `
    -Body "This could improve performance" `
    -AuthorLogin "optimizer" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Might be better → Suggestion" `
    -Body "It might be better to use async/await" `
    -AuthorLogin "modernizer" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Optional improvement → Suggestion" `
    -Body "Optional: add caching for this function" `
    -AuthorLogin "performance" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Refactor suggestion → Suggestion" `
    -Body "We should refactor this to be more modular" `
    -AuthorLogin "architect" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Consider adding → Suggestion" `
    -Body "Consider adding unit tests for this" `
    -AuthorLogin "qa" `
    -Expected "Suggestion"

Test-Severity `
    -TestName "Consider using → Suggestion" `
    -Body "Consider using a constant instead of magic number" `
    -AuthorLogin "maintainer" `
    -Expected "Suggestion"

Write-Host ""

# ============================================================================
# Bug Tests
# ============================================================================

Write-Host "Bug Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Bug keyword → Bug" `
    -Body "This is a bug in the validation logic" `
    -AuthorLogin "tester" `
    -Expected "Bug"

Test-Severity `
    -TestName "Fail keyword → Bug" `
    -Body "This will fail when input is null" `
    -AuthorLogin "validator" `
    -Expected "Bug"

Test-Severity `
    -TestName "Error keyword → Bug" `
    -Body "Error: division by zero possible" `
    -AuthorLogin "analyzer" `
    -Expected "Bug"

Test-Severity `
    -TestName "Undefined behavior → Bug" `
    -Body "This causes undefined behavior" `
    -AuthorLogin "checker" `
    -Expected "Bug"

Test-Severity `
    -TestName "Crash keyword → Bug" `
    -Body "This will crash if the array is empty" `
    -AuthorLogin "debugger" `
    -Expected "Bug"

Test-Severity `
    -TestName "Breaks keyword → Bug" `
    -Body "This breaks the API contract" `
    -AuthorLogin "api-designer" `
    -Expected "Bug"

Test-Severity `
    -TestName "Malformed data → Bug" `
    -Body "Malformed JSON in response" `
    -AuthorLogin "integrator" `
    -Expected "Bug"

Test-Severity `
    -TestName "Security issue → Bug" `
    -Body "Security: SQL injection vulnerability" `
    -AuthorLogin "security-team" `
    -Expected "Bug"

Test-Severity `
    -TestName "Critical issue → Bug" `
    -Body "Critical: this blocks deployment" `
    -AuthorLogin "release-manager" `
    -Expected "Bug"

Test-Severity `
    -TestName "Memory leak → Bug" `
    -Body "Memory leak detected in this function" `
    -AuthorLogin "profiler" `
    -Expected "Bug"

Test-Severity `
    -TestName "Race condition → Bug" `
    -Body "Race condition in concurrent access" `
    -AuthorLogin "concurrency-expert" `
    -Expected "Bug"

Write-Host ""

# ============================================================================
# Edge Cases and Default Tests
# ============================================================================

Write-Host "Edge Cases and Default Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Empty body → Bug (default)" `
    -Body "" `
    -AuthorLogin "someone" `
    -Expected "Bug"

Test-Severity `
    -TestName "Generic comment → Bug (default)" `
    -Body "This looks interesting" `
    -AuthorLogin "casual-reviewer" `
    -Expected "Bug"

Test-Severity `
    -TestName "Plain text → Bug (default)" `
    -Body "Some random text without keywords" `
    -AuthorLogin "commenter" `
    -Expected "Bug"

Test-Severity `
    -TestName "Multiple indicators: question wins over bug keyword" `
    -Body "Why does this cause a bug?" `
    -AuthorLogin "curious" `
    -Expected "Question"

Test-Severity `
    -TestName "Case insensitive: BUG → Bug" `
    -Body "BUG: uppercase keyword" `
    -AuthorLogin "shouter" `
    -Expected "Bug"

Test-Severity `
    -TestName "Case insensitive: NIT → Nit" `
    -Body "NIT: uppercase nit" `
    -AuthorLogin "capslock" `
    -Expected "Nit"

Test-Severity `
    -TestName "Multiline comment with bug → Bug" `
    -Body @"
This is a longer comment
that spans multiple lines
and mentions a bug somewhere
"@ `
    -AuthorLogin "detailed-reviewer" `
    -Expected "Bug"

Test-Severity `
    -TestName "Comment with emoji but not bot → Bug (default)" `
    -Body "👍 Nice work!" `
    -AuthorLogin "regular-user" `
    -Expected "Bug"

Test-Severity `
    -TestName "Bot name in body not author → Bug (default)" `
    -Body "The devin bot found this" `
    -AuthorLogin "human-reviewer" `
    -Expected "Bug"

Write-Host ""

# ============================================================================
# Priority Tests (keyword order matters)
# ============================================================================

Write-Host "Priority Tests:" -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Test-Severity `
    -TestName "Question mark takes priority → Question" `
    -Body "Is this a bug?" `
    -AuthorLogin "asker" `
    -Expected "Question"

Test-Severity `
    -TestName "Nit takes priority over suggestion keywords → Nit" `
    -Body "Nit: consider this optional improvement" `
    -AuthorLogin "nitpicker" `
    -Expected "Nit"

Test-Severity `
    -TestName "Bot badge takes priority over keywords → Nit" `
    -Body "P2: This is a critical security bug (just kidding)" `
    -AuthorLogin "devin" `
    -Expected "Nit"

Write-Host ""

# ============================================================================
# Summary
# ============================================================================

Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "Results: " -ForegroundColor White -NoNewline
Write-Host "$passed passed" -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host "$failed failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
Write-Host "─────────────────────────────────────────────────────────`n" -ForegroundColor DarkGray

if ($failed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
