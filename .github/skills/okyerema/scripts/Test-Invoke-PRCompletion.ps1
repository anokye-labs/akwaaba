<#
.SYNOPSIS
    Test suite for Invoke-PRCompletion.ps1

.DESCRIPTION
    This script tests the thread classification logic and workflow orchestration
    in Invoke-PRCompletion.ps1. Integration tests require a real PR with threads.

.EXAMPLE
    .\Test-Invoke-PRCompletion.ps1

.EXAMPLE
    # Run integration test (requires real PR)
    .\Test-Invoke-PRCompletion.ps1 -IntegrationTest -Owner anokye-labs -Repo akwaaba -PullNumber 6
#>

[CmdletBinding()]
param(
    [switch]$IntegrationTest,
    [string]$Owner = "anokye-labs",
    [string]$Repo = "akwaaba",
    [int]$PullNumber = 0
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import the classification function for unit testing
# This duplicates the function from Invoke-PRCompletion.ps1 for isolated testing
function Get-ThreadClassification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Body,
        
        [Parameter(Mandatory = $false)]
        [string]$AuthorLogin = ""
    )
    
    $bodyLower = $Body.ToLower()
    
    # Check for known bot severity indicators
    # P0 = critical/blocking, P1 = high priority, P2 = medium
    if ($Body -match 'P0|P\[0\]') {
        return 'blocking'
    }
    if ($Body -match 'P1|P\[1\]') {
        return 'blocking'
    }
    if ($Body -match 'P2|P\[2\]') {
        return 'suggestion'
    }
    
    # Check for suggestion/consider phrases to avoid false blocking classification
    $hasSuggestiveLanguage = $bodyLower -match '\b(consider|suggest|recommend|could|should|would|might)\b.*\b(error|bug|fail)'
    
    # Blocking indicators (highest priority) - but not if it's a suggestion
    if (-not $hasSuggestiveLanguage) {
        $blockingPatterns = @(
            '\b(security|vulnerability|exploit|injection|xss|csrf|sql injection)\b',
            '\b(critical|blocker|blocking|must fix|required|mandatory)\b',
            '\b(breaks?|broken|this is a bug|has a bug|causes?\s+(a\s+)?(crash|error))\b',
            '\b(undefined behavior|null pointer|memory leak|race condition)\b',
            '\b(test\s+)?(fails?|failed|failure|failing)\b',
            '\b(malformed|invalid|corrupts?|data loss)\b'
        )
        
        foreach ($pattern in $blockingPatterns) {
            if ($bodyLower -match $pattern) {
                return 'blocking'
            }
        }
    }
    
    # Question indicators
    $questionPatterns = @(
        '\?$',
        '^\s*(why|how|what|when|where|which)\b',
        '\b(could you|can you|would you)\s+(explain|clarify)\b',
        '\b(not sure|unclear|confused)\b'
    )
    
    foreach ($pattern in $questionPatterns) {
        if ($bodyLower -match $pattern) {
            return 'question'
        }
    }
    
    # Praise indicators
    $praisePatterns = @(
        '\b(nice|good|great|excellent|perfect|love|awesome|fantastic)\b',
        '\b(thank|thanks|lgtm|looks good|well done|good job)\b',
        '👍|❤️|🎉|✨|💯|🔥'
    )
    
    foreach ($pattern in $praisePatterns) {
        if ($bodyLower -match $pattern) {
            return 'praise'
        }
    }
    
    # Nitpick indicators
    $nitpickPatterns = @(
        '\b(nit|nitpick|minor|small|tiny|trivial)\b',
        '\b(style|formatting|whitespace|spacing|indentation)\b',
        '\b(typo|spelling|grammar|wording|cosmetic)\b',
        '\boptional\b'
    )
    
    foreach ($pattern in $nitpickPatterns) {
        if ($bodyLower -match $pattern) {
            return 'nitpick'
        }
    }
    
    # Suggestion indicators (default for actionable comments)
    $suggestionPatterns = @(
        '\b(suggest|recommend|could|should|would|might|perhaps)\b',
        '\b(improve|better|consider|instead|prefer)\b',
        '\b(refactor|simplify|optimize|clean up)\b'
    )
    
    foreach ($pattern in $suggestionPatterns) {
        if ($bodyLower -match $pattern) {
            return 'suggestion'
        }
    }
    
    # Default to 'suggestion' for safety (assume actionable)
    return 'suggestion'
}

# Unit Test: Classification Logic
function Test-ThreadClassification {
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Unit Tests: Thread Classification                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    $testCases = @(
        # Bot severity badges
        @{
            Body = "P0: Critical security vulnerability in authentication"
            Expected = "blocking"
            Description = "Bot P0 badge"
        },
        @{
            Body = "P[1] High priority bug"
            Expected = "blocking"
            Description = "Bot P1 badge"
        },
        @{
            Body = "P2 This could be improved"
            Expected = "suggestion"
            Description = "Bot P2 badge"
        },
        
        # Blocking patterns
        @{
            Body = "This has a SQL injection vulnerability"
            Expected = "blocking"
            Description = "Security vulnerability"
        },
        @{
            Body = "Critical bug: causes crash on startup"
            Expected = "blocking"
            Description = "Critical bug with crash"
        },
        @{
            Body = "This test fails consistently"
            Expected = "blocking"
            Description = "Test failure"
        },
        @{
            Body = "This is broken and causes data loss"
            Expected = "blocking"
            Description = "Broken with data loss"
        },
        @{
            Body = "Undefined behavior when input is null"
            Expected = "blocking"
            Description = "Undefined behavior"
        },
        @{
            Body = "Race condition in concurrent access"
            Expected = "blocking"
            Description = "Race condition"
        },
        
        # Questions
        @{
            Body = "Why did you choose this approach?"
            Expected = "question"
            Description = "Question with 'why'"
        },
        @{
            Body = "How does this handle edge cases?"
            Expected = "question"
            Description = "Question with 'how'"
        },
        @{
            Body = "Could you explain the logic here?"
            Expected = "question"
            Description = "Question with 'could you explain'"
        },
        @{
            Body = "I'm not sure I understand this section"
            Expected = "question"
            Description = "Question with 'not sure'"
        },
        
        # Praise
        @{
            Body = "Nice work! This looks great."
            Expected = "praise"
            Description = "Praise with 'nice' and 'great'"
        },
        @{
            Body = "LGTM 👍"
            Expected = "praise"
            Description = "Praise with LGTM and emoji"
        },
        @{
            Body = "Excellent refactoring 🎉"
            Expected = "praise"
            Description = "Praise with emoji"
        },
        @{
            Body = "Well done on the implementation"
            Expected = "praise"
            Description = "Praise with 'well done'"
        },
        
        # Nitpicks
        @{
            Body = "Nit: Missing trailing comma"
            Expected = "nitpick"
            Description = "Nitpick with 'nit'"
        },
        @{
            Body = "Minor style issue: inconsistent spacing"
            Expected = "nitpick"
            Description = "Nitpick with 'minor' and 'style'"
        },
        @{
            Body = "Typo in the comment"
            Expected = "nitpick"
            Description = "Nitpick with 'typo'"
        },
        @{
            Body = "Optional: could use better variable name"
            Expected = "nitpick"
            Description = "Nitpick with 'optional'"
        },
        @{
            Body = "Trivial: extra whitespace"
            Expected = "nitpick"
            Description = "Nitpick with 'trivial'"
        },
        
        # Suggestions
        @{
            Body = "I suggest refactoring this method"
            Expected = "suggestion"
            Description = "Suggestion with 'suggest' and 'refactor'"
        },
        @{
            Body = "This could be improved by caching"
            Expected = "suggestion"
            Description = "Suggestion with 'could' and 'improved'"
        },
        @{
            Body = "Consider adding error handling here"
            Expected = "suggestion"
            Description = "Suggestion with 'consider' (not blocking even with 'error')"
        },
        @{
            Body = "We should add unit tests"
            Expected = "suggestion"
            Description = "Suggestion with 'should'"
        },
        @{
            Body = "Perhaps we can simplify this logic"
            Expected = "suggestion"
            Description = "Suggestion with 'perhaps' and 'simplify'"
        },
        @{
            Body = "This general comment about the approach"
            Expected = "suggestion"
            Description = "Default to suggestion"
        }
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($test in $testCases) {
        $result = Get-ThreadClassification -Body $test.Body
        $success = $result -eq $test.Expected
        
        if ($success) {
            $passed++
            Write-Host "✓ " -ForegroundColor Green -NoNewline
        }
        else {
            $failed++
            Write-Host "✗ " -ForegroundColor Red -NoNewline
        }
        
        Write-Host "$($test.Description)" -ForegroundColor White
        
        if (-not $success) {
            Write-Host "  Expected: $($test.Expected)" -ForegroundColor Yellow
            Write-Host "  Got:      $result" -ForegroundColor Red
            Write-Host "  Body:     $($test.Body)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "Results: " -ForegroundColor White -NoNewline
    Write-Host "$passed passed" -ForegroundColor Green -NoNewline
    Write-Host ", " -NoNewline
    Write-Host "$failed failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
    Write-Host "─────────────────────────────────────────────────────────`n" -ForegroundColor DarkGray
    
    return @{ Passed = $passed; Failed = $failed }
}

# Integration Test: Dry-Run Mode
function Test-DryRunMode {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$PullNumber
    )
    
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Integration Test: Dry-Run Mode                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    if ($PullNumber -eq 0) {
        Write-Host "⚠️  Skipping: No PR number provided (-PullNumber)" -ForegroundColor Yellow
        return @{ Passed = 0; Failed = 0; Skipped = 1 }
    }
    
    $scriptPath = Join-Path $ScriptDir "Invoke-PRCompletion.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "✗ Script not found: $scriptPath" -ForegroundColor Red
        return @{ Passed = 0; Failed = 1; Skipped = 0 }
    }
    
    Write-Host "Running Invoke-PRCompletion.ps1 with -DryRun..." -ForegroundColor Cyan
    Write-Host "  Owner: $Owner, Repo: $Repo, PR: $PullNumber`n" -ForegroundColor Gray
    
    try {
        $result = & $scriptPath -Owner $Owner -Repo $Repo -PullNumber $PullNumber -DryRun
        
        Write-Host "`n✓ Dry-run completed successfully" -ForegroundColor Green
        Write-Host "  Status: $($result.Status)" -ForegroundColor Gray
        Write-Host "  Iterations: $($result.Iterations)" -ForegroundColor Gray
        Write-Host "  Remaining threads: $($result.Remaining)" -ForegroundColor Gray
        
        # Validate result structure
        $structureValid = $true
        $requiredFields = @('Status', 'Iterations', 'TotalFixed', 'TotalSkipped', 'Remaining', 'CommitShas')
        
        foreach ($field in $requiredFields) {
            if (-not $result.PSObject.Properties.Name.Contains($field)) {
                Write-Host "✗ Missing required field: $field" -ForegroundColor Red
                $structureValid = $false
            }
        }
        
        if ($structureValid) {
            Write-Host "✓ Result structure is valid" -ForegroundColor Green
        }
        
        # Validate no side effects in dry-run
        if ($result.Status -eq 'DryRun' -and $result.TotalFixed -eq 0 -and $result.CommitShas.Count -eq 0) {
            Write-Host "✓ Dry-run had no side effects (no commits)" -ForegroundColor Green
            return @{ Passed = 2; Failed = 0; Skipped = 0 }
        }
        else {
            Write-Host "✗ Dry-run appears to have had side effects" -ForegroundColor Red
            return @{ Passed = 1; Failed = 1; Skipped = 0 }
        }
    }
    catch {
        Write-Host "✗ Dry-run failed: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        return @{ Passed = 0; Failed = 1; Skipped = 0 }
    }
}

# Main execution
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host " Test Suite: Invoke-PRCompletion.ps1" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta

$totalPassed = 0
$totalFailed = 0
$totalSkipped = 0

# Run unit tests
$unitResults = Test-ThreadClassification
$totalPassed += $unitResults.Passed
$totalFailed += $unitResults.Failed

# Run integration tests if requested
if ($IntegrationTest) {
    $integrationResults = Test-DryRunMode -Owner $Owner -Repo $Repo -PullNumber $PullNumber
    $totalPassed += $integrationResults.Passed
    $totalFailed += $integrationResults.Failed
    $totalSkipped += $integrationResults.Skipped
}
else {
    Write-Host "`nℹ️  Integration tests skipped. Run with -IntegrationTest to enable." -ForegroundColor Cyan
}

# Final summary
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host " Test Summary" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Passed:  " -NoNewline; Write-Host "$totalPassed" -ForegroundColor Green
Write-Host "  Failed:  " -NoNewline; Write-Host "$totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Gray" })
Write-Host "  Skipped: " -NoNewline; Write-Host "$totalSkipped" -ForegroundColor Yellow
Write-Host ""

if ($totalFailed -gt 0) {
    Write-Host "❌ Some tests failed" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
}
