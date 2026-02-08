<#
.SYNOPSIS
    Test script for ConvertTo-EscapedGraphQL.ps1

.DESCRIPTION
    Validates that ConvertTo-EscapedGraphQL properly escapes various types of input
    including newlines, quotes, backslashes, emoji, and unicode characters.
#>

# Import the script
. "$PSScriptRoot/ConvertTo-EscapedGraphQL.ps1"

Write-Host "Testing ConvertTo-EscapedGraphQL..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Escape {
    param(
        [string]$TestName,
        [string]$InputText,
        [string]$Expected
    )
    
    $result = $InputText | ConvertTo-EscapedGraphQL
    
    if ($result -eq $Expected) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:testsPassed++
    } else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Input:    '$InputText'" -ForegroundColor Yellow
        Write-Host "  Expected: '$Expected'" -ForegroundColor Yellow
        Write-Host "  Got:      '$result'" -ForegroundColor Yellow
        $script:testsFailed++
    }
}

# Test 1: Simple quote escaping
Test-Escape -TestName "Escape double quotes" `
    -InputText 'Hello "World"' `
    -Expected 'Hello \"World\"'

# Test 2: Backslash escaping
Test-Escape -TestName "Escape backslashes" `
    -InputText 'Path: C:\Users\Name' `
    -Expected 'Path: C:\\Users\\Name'

# Test 3: Combined backslash and quote
Test-Escape -TestName "Escape backslash and quote" `
    -InputText 'She said: "It\s nice"' `
    -Expected 'She said: \"It\\s nice\"'

# Test 4: Unix newline
Test-Escape -TestName "Escape Unix newline (LF)" `
    -InputText "Line 1`nLine 2" `
    -Expected 'Line 1\nLine 2'

# Test 5: Windows newline
Test-Escape -TestName "Escape Windows newline (CRLF)" `
    -InputText "Line 1`r`nLine 2" `
    -Expected 'Line 1\nLine 2'

# Test 6: Tab character
Test-Escape -TestName "Escape tab character" `
    -InputText "Column1`tColumn2" `
    -Expected 'Column1\tColumn2'

# Test 7: Empty string
Test-Escape -TestName "Empty string" `
    -InputText "" `
    -Expected ""

# Test 8: Emoji preservation
Test-Escape -TestName "Preserve emoji" `
    -InputText "Rocket: 🚀 Star: ⭐" `
    -Expected "Rocket: 🚀 Star: ⭐"

# Test 9: Unicode characters
Test-Escape -TestName "Preserve unicode" `
    -InputText "Café, naïve, Zürich" `
    -Expected "Café, naïve, Zürich"

# Test 10: Complex mixed content
Test-Escape -TestName "Complex mixed content" `
    -InputText "Line 1 with `"quotes`"`nLine 2 with \backslash`nEmoji: 🎉" `
    -Expected 'Line 1 with \"quotes\"\nLine 2 with \\backslash\nEmoji: 🎉'

# Test 11: Multiple consecutive special chars
Test-Escape -TestName "Multiple backslashes" `
    -InputText '\\\\server\\share' `
    -Expected '\\\\\\\\server\\\\share'

# Test 12: Using -Value parameter instead of pipeline
$result = ConvertTo-EscapedGraphQL -Value 'Test "Value" parameter'
if ($result -eq 'Test \"Value\" parameter') {
    Write-Host "✓ PASS: -Value parameter works" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "✗ FAIL: -Value parameter works" -ForegroundColor Red
    Write-Host "  Expected: 'Test \`"Value\`" parameter'" -ForegroundColor Yellow
    Write-Host "  Got:      '$result'" -ForegroundColor Yellow
    $testsFailed++
}

# Test 13: Heredoc (multiline string)
$heredoc = @"
First line with "quotes"
Second line with \backslash
Third line with emoji: 🚀
"@

$expectedHeredoc = 'First line with \"quotes\"\nSecond line with \\backslash\nThird line with emoji: 🚀'
$result = $heredoc | ConvertTo-EscapedGraphQL

if ($result -eq $expectedHeredoc) {
    Write-Host "✓ PASS: Heredoc escaping" -ForegroundColor Green
    $testsPassed++
} else {
    Write-Host "✗ FAIL: Heredoc escaping" -ForegroundColor Red
    Write-Host "  Expected: '$expectedHeredoc'" -ForegroundColor Yellow
    Write-Host "  Got:      '$result'" -ForegroundColor Yellow
    $testsFailed++
}

# Summary
Write-Host ""
Write-Host "==================== TEST SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "FAILED: Some tests did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "SUCCESS: All tests passed!" -ForegroundColor Green
    exit 0
}
