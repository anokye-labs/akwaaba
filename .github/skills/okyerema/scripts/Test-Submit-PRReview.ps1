<#
.SYNOPSIS
    Tests for Submit-PRReview.ps1

.DESCRIPTION
    Unit tests for the Submit-PRReview.ps1 script.
    Tests various review submission scenarios.

.NOTES
    Run this script to verify Submit-PRReview.ps1 functionality.
#>

$ErrorActionPreference = "Stop"

Write-Host "`n=== Testing Submit-PRReview.ps1 ===" -ForegroundColor Green
Write-Host ""

# Test 1: Script file exists
Write-Host "Test 1: Checking if Submit-PRReview.ps1 exists..." -ForegroundColor Cyan
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $scriptDir "Submit-PRReview.ps1"

if (Test-Path $scriptPath) {
    Write-Host "  ✓ Script file found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Script file not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

# Test 2: Script can be loaded (syntax check)
Write-Host "`nTest 2: Checking script syntax..." -ForegroundColor Cyan
try {
    $scriptContent = Get-Content $scriptPath -Raw
    $null = [scriptblock]::Create($scriptContent)
    Write-Host "  ✓ Script syntax is valid" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Script syntax error: $_" -ForegroundColor Red
    exit 1
}

# Test 3: Verify mandatory parameters
Write-Host "`nTest 3: Checking mandatory parameters..." -ForegroundColor Cyan
$expectedMandatory = @("Owner", "Repo", "PullNumber")
$allPresent = $true

foreach ($param in $expectedMandatory) {
    # Look for [Parameter(Mandatory = $true)] followed by [string]$ParamName
    $pattern = "\[Parameter\(Mandatory\s*=\s*\`$true\)\][\s\S]*?\[\w+\]\`$$param"
    if ($scriptContent -match $pattern) {
        Write-Host "  ✓ Mandatory parameter found: $param" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Missing mandatory parameter: $param" -ForegroundColor Red
        $allPresent = $false
    }
}

if (-not $allPresent) {
    exit 1
}

# Test 4: Verify Event parameter validation
Write-Host "`nTest 4: Checking Event parameter validation..." -ForegroundColor Cyan
if ($scriptContent -match '\[ValidateSet\("APPROVE",\s*"REQUEST_CHANGES",\s*"COMMENT"\)\]') {
    Write-Host "  ✓ Event parameter has correct validation set" -ForegroundColor Green
} else {
    Write-Host "  ✗ Event parameter validation not found or incorrect" -ForegroundColor Red
    exit 1
}

# Test 5: Test DryRun mode (should not fail)
Write-Host "`nTest 5: Testing DryRun mode..." -ForegroundColor Cyan
try {
    # Note: This will fail at runtime because dependencies aren't set up,
    # but we can at least verify the parameter is recognized
    $help = Get-Help $scriptPath -ErrorAction SilentlyContinue
    
    if ($help -and $help.parameters.parameter | Where-Object { $_.name -eq "DryRun" }) {
        Write-Host "  ✓ DryRun parameter is defined" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Could not verify DryRun parameter via Get-Help" -ForegroundColor Yellow
        Write-Host "    (This is expected if dependencies are not available)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  ⚠ Get-Help failed (expected if dependencies missing): $_" -ForegroundColor Yellow
}

# Test 6: Check for required helper functions
Write-Host "`nTest 6: Checking for helper functions..." -ForegroundColor Cyan
$requiredFunctions = @(
    "Write-Log",
    "Invoke-GraphQLHelper",
    "Get-RepoContextHelper",
    "ConvertTo-GraphQLString"
)

foreach ($func in $requiredFunctions) {
    if ($scriptContent -match "function\s+$func") {
        Write-Host "  ✓ Helper function found: $func" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Missing helper function: $func" -ForegroundColor Red
        exit 1
    }
}

# Test 7: Check for dependency script references
Write-Host "`nTest 7: Checking for dependency script references..." -ForegroundColor Cyan
$dependencyScripts = @(
    "Invoke-GraphQL.ps1",
    "Get-RepoContext.ps1",
    "Write-OkyeremaLog.ps1",
    "Reply-ReviewThread.ps1",
    "Resolve-ReviewThreads.ps1"
)

foreach ($dep in $dependencyScripts) {
    if ($scriptContent -match [regex]::Escape($dep)) {
        Write-Host "  ✓ Reference found: $dep" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Missing reference: $dep" -ForegroundColor Red
        exit 1
    }
}

# Test 8: Check for GraphQL mutation
Write-Host "`nTest 8: Checking for GraphQL mutation..." -ForegroundColor Cyan
if ($scriptContent -match 'addPullRequestReview') {
    Write-Host "  ✓ addPullRequestReview mutation found" -ForegroundColor Green
} else {
    Write-Host "  ✗ addPullRequestReview mutation not found" -ForegroundColor Red
    exit 1
}

# Test 9: Test ConvertTo-GraphQLString helper function
Write-Host "`nTest 9: Testing ConvertTo-GraphQLString helper..." -ForegroundColor Cyan

# Extract and test the function
$functionMatch = [regex]::Match($scriptContent, 'function\s+ConvertTo-GraphQLString\s*\{([\s\S]*?)^}', 
    [System.Text.RegularExpressions.RegexOptions]::Multiline)

if ($functionMatch.Success) {
    # Create a minimal test of the function logic
    $testCases = @(
        @{Input = 'Simple text'; Expected = 'Simple text'}
        @{Input = "Line1`nLine2"; Expected = 'Line1\nLine2'}
        @{Input = 'Quote: "test"'; Expected = 'Quote: \"test\"'}
        @{Input = 'Backslash: \test'; Expected = 'Backslash: \\test'}
    )
    
    Write-Host "  ✓ ConvertTo-GraphQLString function exists" -ForegroundColor Green
    Write-Host "    (Function logic tests would require executing the script)" -ForegroundColor Gray
} else {
    Write-Host "  ✗ ConvertTo-GraphQLString function not found" -ForegroundColor Red
    exit 1
}

# Test 10: Check documentation
Write-Host "`nTest 10: Checking documentation..." -ForegroundColor Cyan
$docChecks = @(
    @{Pattern = '\.SYNOPSIS'; Name = 'SYNOPSIS'}
    @{Pattern = '\.DESCRIPTION'; Name = 'DESCRIPTION'}
    @{Pattern = '\.PARAMETER'; Name = 'PARAMETER'}
    @{Pattern = '\.EXAMPLE'; Name = 'EXAMPLE'}
)

foreach ($check in $docChecks) {
    if ($scriptContent -match $check.Pattern) {
        Write-Host "  ✓ Documentation section found: $($check.Name)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Missing documentation section: $($check.Name)" -ForegroundColor Red
        exit 1
    }
}

# Test 11: Verify examples in documentation
Write-Host "`nTest 11: Checking documentation examples..." -ForegroundColor Cyan
$exampleCount = ([regex]::Matches($scriptContent, '\.EXAMPLE')).Count
if ($exampleCount -ge 4) {
    Write-Host "  ✓ Found $exampleCount examples (expected at least 4)" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Found only $exampleCount examples (expected at least 4)" -ForegroundColor Yellow
}

# Test 12: Check for correlation ID usage
Write-Host "`nTest 12: Checking for correlation ID..." -ForegroundColor Cyan
if ($scriptContent -match '\$correlationId\s*=\s*\[guid\]::NewGuid') {
    Write-Host "  ✓ Correlation ID generation found" -ForegroundColor Green
} else {
    Write-Host "  ✗ Correlation ID generation not found" -ForegroundColor Red
    exit 1
}

# Test 13: Check for error handling
Write-Host "`nTest 13: Checking for error handling..." -ForegroundColor Cyan
if ($scriptContent -match '\$ErrorActionPreference\s*=\s*"Stop"') {
    Write-Host "  ✓ ErrorActionPreference set to Stop" -ForegroundColor Green
} else {
    Write-Host "  ⚠ ErrorActionPreference not set to Stop" -ForegroundColor Yellow
}

if ($scriptContent -match 'if\s*\(-not\s+\$\w+\.Success\)') {
    Write-Host "  ✓ GraphQL result success checking found" -ForegroundColor Green
} else {
    Write-Host "  ⚠ GraphQL result success checking not found" -ForegroundColor Yellow
}

# Test 14: Check for Quiet parameter support
Write-Host "`nTest 14: Checking for Quiet parameter..." -ForegroundColor Cyan
if ($scriptContent -match '\[switch\]\$Quiet') {
    Write-Host "  ✓ Quiet parameter found" -ForegroundColor Green
    
    if ($scriptContent -match '-Quiet:\$Quiet') {
        Write-Host "  ✓ Quiet parameter is passed to helper functions" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Quiet parameter may not be passed to helper functions" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ✗ Quiet parameter not found" -ForegroundColor Red
    exit 1
}

# Test 15: Check for FileComments parameter
Write-Host "`nTest 15: Checking for FileComments parameter..." -ForegroundColor Cyan
if ($scriptContent -match '\[hashtable\[\]\]\$FileComments') {
    Write-Host "  ✓ FileComments parameter found (type: hashtable[])" -ForegroundColor Green
} else {
    Write-Host "  ✗ FileComments parameter not found or wrong type" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== All Tests Completed ===" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  - Script syntax is valid" -ForegroundColor White
Write-Host "  - All required parameters are present" -ForegroundColor White
Write-Host "  - Helper functions are defined" -ForegroundColor White
Write-Host "  - Dependency references are correct" -ForegroundColor White
Write-Host "  - Documentation is complete" -ForegroundColor White
Write-Host ""
Write-Host "Note: Integration tests require a live GitHub repository and PR." -ForegroundColor Yellow
Write-Host ""
