<#
.SYNOPSIS
    Test script for Get-DagCompletionReport.ps1

.DESCRIPTION
    This script tests the Get-DagCompletionReport.ps1 script by running it
    with various parameters and validating the outputs.

.PARAMETER IssueNumber
    The issue number to use for testing. If not provided, the script will
    prompt for an issue number.

.EXAMPLE
    .\Test-Get-DagCompletionReport.ps1 -IssueNumber 1
    Tests the report generation for issue #1.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$IssueNumber
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptRoot "Get-DagCompletionReport.ps1"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Testing Get-DagCompletionReport.ps1" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ ERROR: Get-DagCompletionReport.ps1 not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Script found at $scriptPath" -ForegroundColor Green
Write-Host ""

# If no issue number provided, prompt user
if (-not $IssueNumber) {
    Write-Host "Please provide an issue number to test with:" -ForegroundColor Yellow
    $IssueNumber = Read-Host "Issue Number"
    
    if (-not $IssueNumber -or $IssueNumber -le 0) {
        Write-Host "❌ Invalid issue number" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Testing with issue #$IssueNumber" -ForegroundColor Yellow
Write-Host ""

# Test 1: Console format
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 1: Console Format" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

try {
    & $scriptPath -RootIssueNumber $IssueNumber -OutputFormat Console
    Write-Host "✓ Console format test passed" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ Console format test failed: $_" -ForegroundColor Red
    Write-Host ""
}

# Test 2: Markdown format
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 2: Markdown Format" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

try {
    $markdownOutput = & $scriptPath -RootIssueNumber $IssueNumber -OutputFormat Markdown
    Write-Host $markdownOutput
    
    # Validate markdown output contains expected sections
    $outputStr = $markdownOutput -join "`n"
    if ($outputStr -match "# DAG Completion Report" -and $outputStr -match "## Phase Summary") {
        Write-Host ""
        Write-Host "✓ Markdown format test passed" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "❌ Markdown format test failed: Missing expected sections" -ForegroundColor Red
        Write-Host ""
    }
} catch {
    Write-Host "❌ Markdown format test failed: $_" -ForegroundColor Red
    Write-Host ""
}

# Test 3: JSON format
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 3: JSON Format" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

try {
    $jsonOutput = & $scriptPath -RootIssueNumber $IssueNumber -OutputFormat Json
    Write-Host $jsonOutput
    
    # Validate JSON output
    $parsed = $jsonOutput | ConvertFrom-Json
    if ($parsed.Root -and $parsed.Phases) {
        Write-Host ""
        Write-Host "✓ JSON format test passed" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "❌ JSON format test failed: Missing expected properties" -ForegroundColor Red
        Write-Host ""
    }
} catch {
    Write-Host "❌ JSON format test failed: $_" -ForegroundColor Red
    Write-Host ""
}

# Test 4: Console format with burndown data
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 4: Console Format with Burndown" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

try {
    & $scriptPath -RootIssueNumber $IssueNumber -OutputFormat Console -IncludeBurndown
    Write-Host "✓ Console format with burndown test passed" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "❌ Console format with burndown test failed: $_" -ForegroundColor Red
    Write-Host ""
}

# Test 5: JSON format with burndown data
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host "Test 5: JSON Format with Burndown" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkCyan
Write-Host ""

try {
    $jsonBurndownOutput = & $scriptPath -RootIssueNumber $IssueNumber -OutputFormat Json -IncludeBurndown
    $parsed = $jsonBurndownOutput | ConvertFrom-Json
    
    Write-Host "Burndown entries: $($parsed.Burndown.Count)" -ForegroundColor Cyan
    
    if ($parsed.Burndown) {
        Write-Host "✓ JSON format with burndown test passed" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "⚠ JSON format with burndown test passed, but no burndown data found (may be expected if no issues closed)" -ForegroundColor Yellow
        Write-Host ""
    }
} catch {
    Write-Host "❌ JSON format with burndown test failed: $_" -ForegroundColor Red
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "All tests completed. Review the output above for details." -ForegroundColor Yellow
Write-Host ""
