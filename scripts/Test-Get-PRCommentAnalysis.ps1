<#
.SYNOPSIS
    Test suite for Get-PRCommentAnalysis.ps1

.DESCRIPTION
    This script tests the comment categorization logic and analysis functions
    in Get-PRCommentAnalysis.ps1.

.EXAMPLE
    .\Test-Get-PRCommentAnalysis.ps1
#>

$ErrorActionPreference = "Stop"

# Import the Get-CommentCategory function by defining it locally
function Get-CommentCategory {
    param([string]$Body)
    
    $bodyLower = $Body.ToLower()
    
    # Check for suggestion/consider phrases first to avoid false blocking categorization
    # e.g., "Consider adding error handling" should be suggestion, not blocking
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
    
    # Suggestion indicators (default for most comments)
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
    
    # Default to suggestion if no clear category
    return "suggestion"
}

# Test data
$testCases = @(
    @{
        Body = "This code has a security vulnerability that needs to be fixed"
        Expected = "blocking"
        Description = "Security vulnerability"
    },
    @{
        Body = "This is a critical bug that will crash the application"
        Expected = "blocking"
        Description = "Critical bug"
    },
    @{
        Body = "This test fails when running on Windows"
        Expected = "blocking"
        Description = "Test failure"
    },
    @{
        Body = "Why did you choose this approach?"
        Expected = "question"
        Description = "Question with 'why'"
    },
    @{
        Body = "Could you explain how this function works?"
        Expected = "question"
        Description = "Question with 'could you explain'"
    },
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
        Body = "Nit: Missing trailing comma"
        Expected = "nitpick"
        Description = "Nitpick with 'nit'"
    },
    @{
        Body = "Minor style issue: use single quotes instead of double"
        Expected = "nitpick"
        Description = "Nitpick with 'minor' and 'style'"
    },
    @{
        Body = "Typo in the comment"
        Expected = "nitpick"
        Description = "Nitpick with 'typo'"
    },
    @{
        Body = "I suggest refactoring this method to be more readable"
        Expected = "suggestion"
        Description = "Suggestion with 'suggest' and 'refactor'"
    },
    @{
        Body = "This could be improved by using a map instead of a loop"
        Expected = "suggestion"
        Description = "Suggestion with 'could' and 'improved'"
    },
    @{
        Body = "Consider adding error handling here"
        Expected = "suggestion"
        Description = "Suggestion with 'consider'"
    },
    @{
        Body = "We should add unit tests for this function"
        Expected = "suggestion"
        Description = "Suggestion with 'should'"
    },
    @{
        Body = "This is a general comment about the code"
        Expected = "suggestion"
        Description = "Default to suggestion"
    }
)

# Run tests
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Test Suite: Get-PRCommentAnalysis.ps1                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$passed = 0
$failed = 0
$testResults = @()

foreach ($test in $testCases) {
    $result = Get-CommentCategory -Body $test.Body
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
    }
    
    $testResults += [PSCustomObject]@{
        Description = $test.Description
        Expected = $test.Expected
        Actual = $result
        Passed = $success
        Body = $test.Body
    }
}

Write-Host ""
Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "Results: " -ForegroundColor White -NoNewline
Write-Host "$passed passed" -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host "$failed failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
Write-Host "─────────────────────────────────────────────────────────`n" -ForegroundColor DarkGray

# Test category priority (blocking should take precedence over other indicators)
Write-Host "Testing category priority..." -ForegroundColor Cyan

$priorityTests = @(
    @{
        Body = "This is a critical security issue but you did a nice job finding it"
        Expected = "blocking"
        Description = "Blocking should take precedence over praise"
    },
    @{
        Body = "Why is this code broken? It seems like a bug."
        Expected = "blocking"
        Description = "Blocking should take precedence over question"
    }
)

foreach ($test in $priorityTests) {
    $result = Get-CommentCategory -Body $test.Body
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
    }
}

Write-Host ""

# Summary
if ($failed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
