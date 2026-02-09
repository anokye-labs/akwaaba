<#
.SYNOPSIS
    Test script for Invoke-SystemHealthCheck.ps1

.DESCRIPTION
    This script tests the Invoke-SystemHealthCheck.ps1 script to ensure it has valid syntax,
    proper help documentation, and the expected parameters.

.NOTES
    This is a basic syntax and structure test. Full functional testing requires
    GitHub CLI authentication and a repository with issues.
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Testing Invoke-SystemHealthCheck.ps1 ===" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Join-Path $PSScriptRoot "Invoke-SystemHealthCheck.ps1"

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

# Test 4: Check required parameters
Write-Host "Test 4: Checking script parameters..." -ForegroundColor Yellow
try {
    $params = (Get-Command $scriptPath).Parameters
    
    $requiredParams = @('Owner', 'Repo')
    foreach ($param in $requiredParams) {
        if ($params.ContainsKey($param)) {
            Write-Host "  ✓ Required parameter '$param' found" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Required parameter '$param' not found" -ForegroundColor Red
            exit 1
        }
    }
    
    $optionalParams = @('SkillPath')
    foreach ($param in $optionalParams) {
        if ($params.ContainsKey($param)) {
            Write-Host "  ✓ Optional parameter '$param' found" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Optional parameter '$param' not found" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ✗ Error checking parameters: $_" -ForegroundColor Red
    exit 1
}

# Test 5: Check for required dependencies references
Write-Host "Test 5: Checking for dependency references..." -ForegroundColor Yellow
$scriptContent = Get-Content $scriptPath -Raw
$dependencies = @("Invoke-GraphQL.ps1", "Write-OkyeremaLog.ps1")
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

# Test 6: Verify check names are defined
Write-Host "Test 6: Checking for expected health checks..." -ForegroundColor Yellow
$expectedChecks = @(
    "API Compatibility",
    "Script Dependencies", 
    "Doc Freshness",
    "Hierarchy Integrity",
    "Label Consistency"
)
foreach ($check in $expectedChecks) {
    if ($scriptContent -match [regex]::Escape($check)) {
        Write-Host "  ✓ Check '$check' found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Check '$check' not found" -ForegroundColor Red
        exit 1
    }
}

# Test 7: Verify output structure
Write-Host "Test 7: Checking for output structure..." -ForegroundColor Yellow
if ($scriptContent -match 'CheckName') {
    Write-Host "  ✓ CheckName field found" -ForegroundColor Green
} else {
    Write-Host "  ✗ CheckName field not found" -ForegroundColor Red
    exit 1
}

if ($scriptContent -match 'Status') {
    Write-Host "  ✓ Status field found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Status field not found" -ForegroundColor Red
    exit 1
}

if ($scriptContent -match 'Details') {
    Write-Host "  ✓ Details field found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Details field not found" -ForegroundColor Red
    exit 1
}

# Test 8: Verify status values
Write-Host "Test 8: Checking for status values..." -ForegroundColor Yellow
$statusValues = @("Pass", "Warn", "Fail")
foreach ($status in $statusValues) {
    if ($scriptContent -match "`"$status`"") {
        Write-Host "  ✓ Status '$status' found" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Status '$status' not found" -ForegroundColor Red
        exit 1
    }
}

# Test 9: Verify deprecated pattern checks
Write-Host "Test 9: Checking for deprecated pattern detection..." -ForegroundColor Yellow
$deprecatedPatterns = @("trackedIssues", "trackedInIssues", "tasklist", "subIssues")
foreach ($pattern in $deprecatedPatterns) {
    if ($scriptContent -match [regex]::Escape($pattern)) {
        Write-Host "  ✓ Check for pattern '$pattern' found" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Check for pattern '$pattern' not explicitly mentioned" -ForegroundColor Yellow
    }
}

# Test 10: Verify ADR-0001 reference
Write-Host "Test 10: Checking for ADR-0001 reference..." -ForegroundColor Yellow
if ($scriptContent -match "ADR-0001") {
    Write-Host "  ✓ ADR-0001 reference found" -ForegroundColor Green
} else {
    Write-Host "  ⚠ ADR-0001 reference not found (recommended for context)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All Tests Passed ===" -ForegroundColor Green
Write-Host ""
exit 0
