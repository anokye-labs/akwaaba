<#
.SYNOPSIS
    Unit tests for Validate-CommitAuthors.ps1

.DESCRIPTION
    Tests the GitHub App detection and commit author validation functionality.
    
.NOTES
    Author: Anokye Labs
    Dependencies: Validate-CommitAuthors.ps1, Pester (optional)
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Suite: Validate-CommitAuthors.ps1" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Load the script functions for testing
$scriptPath = Join-Path $PSScriptRoot "Validate-CommitAuthors.ps1"

# Test cases
$testResults = @()

#region Test 1: GitHub App Pattern Detection

Write-Host "Test 1: GitHub App Pattern Detection" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray

# Load the function from the script
$scriptContent = Get-Content $scriptPath -Raw
$functionMatch = [regex]::Match($scriptContent, '(?s)function Test-GitHubAppPattern \{.*?\n\}(?=\n\nfunction|\n#region|\z)')
if ($functionMatch.Success) {
    Invoke-Expression $functionMatch.Value
}

$testCases = @(
    @{ Username = "copilot[bot]"; Expected = $true; Description = "Standard GitHub App username" },
    @{ Username = "github-actions[bot]"; Expected = $true; Description = "GitHub Actions bot" },
    @{ Username = "dependabot[bot]"; Expected = $true; Description = "Dependabot" },
    @{ Username = "copilot"; Expected = $false; Description = "Username without [bot] suffix" },
    @{ Username = "human-user"; Expected = $false; Description = "Human username" },
    @{ Username = "bot"; Expected = $false; Description = "Just 'bot' keyword" }
)

foreach ($testCase in $testCases) {
    try {
        $result = Test-GitHubAppPattern -Username $testCase.Username
        $passed = $result -eq $testCase.Expected
        
        if ($passed) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($testCase.Description): " -NoNewline
            Write-Host "PASS" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "$($testCase.Description): " -NoNewline
            Write-Host "FAIL" -ForegroundColor Red
            Write-Host "    Expected: $($testCase.Expected), Got: $result" -ForegroundColor DarkGray
        }
        
        $testResults += [PSCustomObject]@{
            Test = "Test-GitHubAppPattern"
            Case = $testCase.Description
            Passed = $passed
        }
    }
    catch {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($testCase.Description): " -NoNewline
        Write-Host "ERROR" -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor DarkGray
        
        $testResults += [PSCustomObject]@{
            Test = "Test-GitHubAppPattern"
            Case = $testCase.Description
            Passed = $false
        }
    }
}

Write-Host ""

#endregion

#region Test 2: GitHub App ID Extraction

Write-Host "Test 2: GitHub App ID Extraction" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray

# Load the function from the script
$functionMatch = [regex]::Match($scriptContent, '(?s)function Get-GitHubAppId \{.*?\n\}(?=\n\nfunction|\n#region|\z)')
if ($functionMatch.Success) {
    Invoke-Expression $functionMatch.Value
}

$testCases = @(
    @{ BotUsername = "copilot[bot]"; Expected = "copilot"; Description = "Extract copilot from bot username" },
    @{ BotUsername = "github-actions[bot]"; Expected = "github-actions"; Description = "Extract github-actions from bot username" },
    @{ BotUsername = "dependabot[bot]"; Expected = "dependabot"; Description = "Extract dependabot from bot username" }
)

foreach ($testCase in $testCases) {
    try {
        $result = Get-GitHubAppId -BotUsername $testCase.BotUsername
        $passed = $result -eq $testCase.Expected
        
        if ($passed) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($testCase.Description): " -NoNewline
            Write-Host "PASS" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "$($testCase.Description): " -NoNewline
            Write-Host "FAIL" -ForegroundColor Red
            Write-Host "    Expected: '$($testCase.Expected)', Got: '$result'" -ForegroundColor DarkGray
        }
        
        $testResults += [PSCustomObject]@{
            Test = "Get-GitHubAppId"
            Case = $testCase.Description
            Passed = $passed
        }
    }
    catch {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($testCase.Description): " -NoNewline
        Write-Host "ERROR" -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor DarkGray
        
        $testResults += [PSCustomObject]@{
            Test = "Get-GitHubAppId"
            Case = $testCase.Description
            Passed = $false
        }
    }
}

Write-Host ""

#endregion

#region Test 3: Allowlist Validation

Write-Host "Test 3: Allowlist Validation" -ForegroundColor Yellow
Write-Host "──────────────────────────────────────" -ForegroundColor DarkGray

# Define Test-AgentInAllowlist function inline for testing
function Test-AgentInAllowlist {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [object]$Allowlist
    )
    
    # Check if username is a GitHub App
    $isGitHubApp = Test-GitHubAppPattern -Username $Username
    
    if ($isGitHubApp) {
        # Extract base name from bot username
        $baseName = Get-GitHubAppId -BotUsername $Username
        
        # Find matching agent in allowlist
        $matchedAgent = $Allowlist.agents | Where-Object {
            $_.enabled -and (
                $_.botUsername -eq $Username -or
                $_.username -eq $baseName
            )
        } | Select-Object -First 1
        
        if ($matchedAgent) {
            return [PSCustomObject]@{
                Approved = $true
                IsGitHubApp = $true
                Agent = $matchedAgent
                Reason = "Approved GitHub App: $($matchedAgent.description)"
            }
        }
        else {
            return [PSCustomObject]@{
                Approved = $false
                IsGitHubApp = $true
                Agent = $null
                Reason = "GitHub App not in allowlist: $Username"
            }
        }
    }
    else {
        # Non-bot username - check if it's an approved service account
        $matchedAgent = $Allowlist.agents | Where-Object {
            $_.enabled -and $_.username -eq $Username
        } | Select-Object -First 1
        
        if ($matchedAgent) {
            return [PSCustomObject]@{
                Approved = $true
                IsGitHubApp = $false
                Agent = $matchedAgent
                Reason = "Approved service account: $($matchedAgent.description)"
            }
        }
        else {
            return [PSCustomObject]@{
                Approved = $false
                IsGitHubApp = $false
                Agent = $null
                Reason = "User not in allowlist: $Username (human commit or unapproved agent)"
            }
        }
    }
}

# Create a test allowlist
$testAllowlist = @{
    agents = @(
        @{
            id = "github-copilot"
            type = "github-app"
            username = "copilot"
            botUsername = "copilot[bot]"
            githubAppId = 271694
            description = "GitHub Copilot"
            enabled = $true
        },
        @{
            id = "github-actions"
            type = "github-app"
            username = "github-actions"
            botUsername = "github-actions[bot]"
            githubAppId = 15368
            description = "GitHub Actions"
            enabled = $true
        },
        @{
            id = "disabled-bot"
            type = "github-app"
            username = "disabled-bot"
            botUsername = "disabled-bot[bot]"
            githubAppId = 99999
            description = "Disabled Bot"
            enabled = $false
        }
    )
} | ConvertTo-Json -Depth 10 | ConvertFrom-Json

$testCases = @(
    @{ Username = "copilot[bot]"; ExpectedApproved = $true; ExpectedIsGitHubApp = $true; Description = "Approved GitHub App (copilot)" },
    @{ Username = "github-actions[bot]"; ExpectedApproved = $true; ExpectedIsGitHubApp = $true; Description = "Approved GitHub App (github-actions)" },
    @{ Username = "unknown-bot[bot]"; ExpectedApproved = $false; ExpectedIsGitHubApp = $true; Description = "Unapproved GitHub App" },
    @{ Username = "disabled-bot[bot]"; ExpectedApproved = $false; ExpectedIsGitHubApp = $true; Description = "Disabled GitHub App" },
    @{ Username = "human-user"; ExpectedApproved = $false; ExpectedIsGitHubApp = $false; Description = "Human user" }
)

foreach ($testCase in $testCases) {
    try {
        $result = Test-AgentInAllowlist -Username $testCase.Username -Allowlist $testAllowlist
        $passedApproval = $result.Approved -eq $testCase.ExpectedApproved
        $passedIsApp = $result.IsGitHubApp -eq $testCase.ExpectedIsGitHubApp
        $passed = $passedApproval -and $passedIsApp
        
        if ($passed) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($testCase.Description): " -NoNewline
            Write-Host "PASS" -ForegroundColor Green
        }
        else {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "$($testCase.Description): " -NoNewline
            Write-Host "FAIL" -ForegroundColor Red
            Write-Host "    Expected Approved: $($testCase.ExpectedApproved), Got: $($result.Approved)" -ForegroundColor DarkGray
            Write-Host "    Expected IsGitHubApp: $($testCase.ExpectedIsGitHubApp), Got: $($result.IsGitHubApp)" -ForegroundColor DarkGray
        }
        
        $testResults += [PSCustomObject]@{
            Test = "Test-AgentInAllowlist"
            Case = $testCase.Description
            Passed = $passed
        }
    }
    catch {
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host "$($testCase.Description): " -NoNewline
        Write-Host "ERROR" -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor DarkGray
        
        $testResults += [PSCustomObject]@{
            Test = "Test-AgentInAllowlist"
            Case = $testCase.Description
            Passed = $false
        }
    }
}

Write-Host ""

#endregion

#region Test Summary

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$totalTests = $testResults.Count
$passedTests = ($testResults | Where-Object { $_.Passed }).Count
$failedTests = $totalTests - $passedTests

Write-Host "  Total Tests: " -NoNewline -ForegroundColor Gray
Write-Host $totalTests -ForegroundColor White
Write-Host "  Passed: " -NoNewline -ForegroundColor Gray
Write-Host $passedTests -ForegroundColor Green
Write-Host "  Failed: " -NoNewline -ForegroundColor Gray
Write-Host $failedTests -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failedTests -eq 0) {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
}
else {
    Write-Host "❌ Some tests failed. See details above." -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Exit with appropriate code
exit $failedTests

#endregion
