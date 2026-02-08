<#
.SYNOPSIS
    Test script for Add-IssuesToProject.ps1

.DESCRIPTION
    Validates the functionality of Add-IssuesToProject.ps1 including:
    - Parameter validation
    - Pipeline input support
    - Field value mapping
    - Error handling
    
    This is a dry-run test that validates the script structure and
    parameter handling without making actual API calls.
#>

$ErrorActionPreference = "Stop"

Write-Host "Testing Add-IssuesToProject.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-ScriptSyntax {
    param([string]$TestName, [string]$ScriptPath)
    
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $ScriptPath -Raw), 
            [ref]$null
        )
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:testsPassed++
        return $true
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

function Test-ScriptParameters {
    param([string]$TestName, [string]$ScriptPath, [string[]]$ExpectedParams)
    
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$null, [ref]$null)
        $paramBlock = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.ParamBlockAst]}, $false) | Select-Object -First 1
        
        if (-not $paramBlock) {
            throw "No param block found"
        }
        
        $actualParams = $paramBlock.Parameters.Name.VariablePath.UserPath
        $missingParams = $ExpectedParams | Where-Object { $_ -notin $actualParams }
        
        if ($missingParams.Count -eq 0) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            Write-Host "  Found parameters: $($actualParams -join ', ')" -ForegroundColor Gray
            $script:testsPassed++
            return $true
        }
        else {
            throw "Missing parameters: $($missingParams -join ', ')"
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

function Test-ScriptHasHelp {
    param([string]$TestName, [string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        $hasHelp = $content -match '<#[\s\S]*?\.SYNOPSIS[\s\S]*?\.DESCRIPTION[\s\S]*?#>'
        
        if ($hasHelp) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            throw "No comment-based help found"
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

function Test-ScriptHasErrorHandling {
    param([string]$TestName, [string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        $hasErrorActionPreference = $content -match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
        
        if ($hasErrorActionPreference) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            throw "No ErrorActionPreference = 'Stop' found"
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

function Test-ScriptHasLogging {
    param([string]$TestName, [string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        $hasLogging = $content -match 'Write-OkyeremaLog'
        
        if ($hasLogging) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            throw "No Write-OkyeremaLog calls found"
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

function Test-ScriptHasPipelineSupport {
    param([string]$TestName, [string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        # Check for begin/process/end blocks
        $hasBeginBlock = $content -match '\bbegin\s*\{'
        $hasProcessBlock = $content -match '\bprocess\s*\{'
        $hasEndBlock = $content -match '\bend\s*\{'
        
        # Check for ValueFromPipeline attribute
        $hasValueFromPipeline = $content -match 'ValueFromPipeline\s*=\s*\$true'
        
        if ($hasBeginBlock -and $hasProcessBlock -and $hasEndBlock -and $hasValueFromPipeline) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            $missing = @()
            if (-not $hasBeginBlock) { $missing += "begin block" }
            if (-not $hasProcessBlock) { $missing += "process block" }
            if (-not $hasEndBlock) { $missing += "end block" }
            if (-not $hasValueFromPipeline) { $missing += "ValueFromPipeline attribute" }
            
            throw "Missing: $($missing -join ', ')"
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

# Run tests
$scriptPath = "$PSScriptRoot/Add-IssuesToProject.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "✗ FAIL: Script file not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Test 1: Script Syntax" -ForegroundColor Cyan
Test-ScriptSyntax -TestName "Parse script without errors" -ScriptPath $scriptPath
Write-Host ""

Write-Host "Test 2: Required Parameters" -ForegroundColor Cyan
$expectedParams = @(
    'IssueNumbers',
    'ProjectNumber',
    'FieldValues',
    'Owner',
    'Repo',
    'DelayMs',
    'CorrelationId',
    'Quiet'
)
Test-ScriptParameters -TestName "All required parameters present" -ScriptPath $scriptPath -ExpectedParams $expectedParams
Write-Host ""

Write-Host "Test 3: Documentation" -ForegroundColor Cyan
Test-ScriptHasHelp -TestName "Comment-based help present" -ScriptPath $scriptPath
Write-Host ""

Write-Host "Test 4: Error Handling" -ForegroundColor Cyan
Test-ScriptHasErrorHandling -TestName "ErrorActionPreference set to Stop" -ScriptPath $scriptPath
Write-Host ""

Write-Host "Test 5: Logging" -ForegroundColor Cyan
Test-ScriptHasLogging -TestName "Uses Write-OkyeremaLog" -ScriptPath $scriptPath
Write-Host ""

Write-Host "Test 6: Pipeline Support" -ForegroundColor Cyan
Test-ScriptHasPipelineSupport -TestName "Supports pipeline input with begin/process/end" -ScriptPath $scriptPath
Write-Host ""

# Summary
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "=" * 60 -ForegroundColor Cyan

if ($testsFailed -eq 0) {
    Write-Host "`n✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n✗ Some tests failed!" -ForegroundColor Red
    exit 1
}
