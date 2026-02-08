<#
.SYNOPSIS
    Test script for Get-OrphanedIssues.ps1

.DESCRIPTION
    This script tests the Get-OrphanedIssues.ps1 script to ensure it has valid syntax,
    proper help documentation, and exports the expected functions.

.NOTES
    This is a basic syntax and structure test. Full functional testing requires
    GitHub CLI authentication and a repository with issues.
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Testing Get-OrphanedIssues.ps1 ===" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Join-Path $PSScriptRoot "Get-OrphanedIssues.ps1"

# Test 1: File exists
Write-Host "Test 1: Checking if script file exists..." -ForegroundColor Yellow
if (Test-Path $scriptPath) {
    Write-Host "  ✓ Script file exists" -ForegroundColor Green
} else {
    Write-Host "  ✗ Script file not found" -ForegroundColor Red
    exit 1
}

# Test 2: PowerShell syntax is valid
Write-Host "Test 2: Validating PowerShell syntax..." -ForegroundColor Yellow
try {
    $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
    Write-Host "  ✓ Syntax is valid" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Syntax error: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Help documentation is present
Write-Host "Test 3: Checking help documentation..." -ForegroundColor Yellow
try {
    $help = Get-Help $scriptPath
    if ($help.Synopsis) {
        Write-Host "  ✓ Synopsis found: $($help.Synopsis)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Synopsis not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ✗ Error getting help: $_" -ForegroundColor Red
    exit 1
}

# Test 4: Check parameters
Write-Host "Test 4: Checking script parameters..." -ForegroundColor Yellow
try {
    $params = (Get-Command $scriptPath).Parameters
    if ($params.ContainsKey('DryRun')) {
        Write-Host "  ✓ DryRun parameter found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ DryRun parameter not found" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ✗ Error checking parameters: $_" -ForegroundColor Red
    exit 1
}

# Test 5: Check for required dependencies references
Write-Host "Test 5: Checking for dependency references..." -ForegroundColor Yellow
$scriptContent = Get-Content $scriptPath -Raw
$dependencies = @("Invoke-GraphQL.ps1", "Get-RepoContext.ps1", "Write-OkyeremaLog.ps1")
$allFound = $true
foreach ($dep in $dependencies) {
    if ($scriptContent -match [regex]::Escape($dep)) {
        Write-Host "  ✓ Reference to $dep found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Reference to $dep not found" -ForegroundColor Red
        $allFound = $false
    }
}
if (-not $allFound) {
    exit 1
}

# Test 6: Verify constants are defined
Write-Host "Test 6: Checking for scoring constants..." -ForegroundColor Yellow
if ($scriptContent -match 'HIERARCHY_MATCH_BOOST') {
    Write-Host "  ✓ HIERARCHY_MATCH_BOOST constant found" -ForegroundColor Green
} else {
    Write-Host "  ✗ HIERARCHY_MATCH_BOOST constant not found" -ForegroundColor Red
    exit 1
}

if ($scriptContent -match 'HIERARCHY_WEAK_BOOST') {
    Write-Host "  ✓ HIERARCHY_WEAK_BOOST constant found" -ForegroundColor Green
} else {
    Write-Host "  ✗ HIERARCHY_WEAK_BOOST constant not found" -ForegroundColor Red
    exit 1
}

# Test 7: Verify helper functions are defined
Write-Host "Test 7: Checking for helper functions..." -ForegroundColor Yellow
$helperFunctions = @("Get-Words", "Get-StringSimilarity", "Invoke-GraphQLHelper", "Write-OkyeremaLogHelper", "Get-RepoContextHelper")
$allFound = $true
foreach ($func in $helperFunctions) {
    if ($scriptContent -match "function $func") {
        Write-Host "  ✓ Function $func found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Function $func not found" -ForegroundColor Red
        $allFound = $false
    }
}
if (-not $allFound) {
    exit 1
}

Write-Host ""
Write-Host "=== All tests passed! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Full functional testing requires:" -ForegroundColor Yellow
Write-Host "  - GitHub CLI (gh) installed and authenticated" -ForegroundColor Yellow
Write-Host "  - A repository with open issues to query" -ForegroundColor Yellow
Write-Host ""
