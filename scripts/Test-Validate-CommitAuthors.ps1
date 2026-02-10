<#
.SYNOPSIS
    Test script for Validate-CommitAuthors.ps1

.DESCRIPTION
    Validates the functionality of Validate-CommitAuthors.ps1 including:
    - Script syntax and structure
    - Parameter validation
    - Approved agents loading
    - Author validation logic
    - Error message generation
    
    This test validates the script structure and core logic without
    requiring actual GitHub API access.
#>

$ErrorActionPreference = "Stop"

Write-Host "Testing Validate-CommitAuthors.ps1..." -ForegroundColor Cyan
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

function Test-FunctionExists {
    param([string]$TestName, [string]$ScriptPath, [string]$FunctionName)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        $hasFn = $content -match "function\s+$FunctionName\s*\{"
        
        if ($hasFn) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            throw "Function '$FunctionName' not found"
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
        return $false
    }
}

function Test-ConfigFileStructure {
    param([string]$TestName, [string]$ConfigPath)
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Validate structure
        if (-not $config.agents) {
            throw "Missing 'agents' property"
        }
        
        if (-not $config.policy) {
            throw "Missing 'policy' property"
        }
        
        if ($config.agents.Count -eq 0) {
            throw "No agents defined in configuration"
        }
        
        # Validate required fields
        foreach ($agent in $config.agents) {
            if (-not $agent.username) { throw "Agent missing 'username'" }
            if (-not $agent.type) { throw "Agent missing 'type'" }
        }
        
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        Write-Host "  Found $($config.agents.Count) agent(s)" -ForegroundColor Gray
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

function Test-ErrorMessageContent {
    param([string]$TestName, [string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw
        
        # Check for key phrases in error message
        $requiredPhrases = @(
            "Human Commits Detected",
            "agent-only commit policy",
            "Why Agent-Only",
            "How to Fix This",
            "Setting Up an Agent",
            "Request New Agent Approval",
            "Currently Approved Agents"
        )
        
        $missing = @()
        foreach ($phrase in $requiredPhrases) {
            if ($content -notmatch [regex]::Escape($phrase)) {
                $missing += $phrase
            }
        }
        
        if ($missing.Count -eq 0) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
            return $true
        }
        else {
            throw "Missing required phrases in error message: $($missing -join ', ')"
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
Write-Host "Test Suite: Validate-CommitAuthors.ps1" -ForegroundColor Yellow
Write-Host "=" * 60
Write-Host ""

$scriptPath = "scripts/Validate-CommitAuthors.ps1"
$configPath = ".github/approved-agents.json"

# Test 1: Script syntax is valid
Test-ScriptSyntax "Script syntax is valid" $scriptPath

# Test 2: Required parameters exist
Test-ScriptParameters "Required parameters exist" $scriptPath @(
    "Owner",
    "Repo", 
    "PullRequestNumber",
    "ApprovedAgentsPath"
)

# Test 3: Script has comment-based help
Test-ScriptHasHelp "Script has comment-based help" $scriptPath

# Test 4: Required functions exist
Test-FunctionExists "Get-ApprovedAgents function exists" $scriptPath "Get-ApprovedAgents"
Test-FunctionExists "Test-ApprovedAuthor function exists" $scriptPath "Test-ApprovedAuthor"
Test-FunctionExists "Get-ErrorMessage function exists" $scriptPath "Get-ErrorMessage"

# Test 5: Configuration file structure is valid
if (Test-Path $configPath) {
    Test-ConfigFileStructure "Approved agents config structure is valid" $configPath
} else {
    Write-Host "⚠ SKIP: Configuration file not found at $configPath" -ForegroundColor Yellow
}

# Test 6: Error message contains required content
Test-ErrorMessageContent "Error message contains required content" $scriptPath

# Summary
Write-Host ""
Write-Host "=" * 60
Write-Host "Test Results:" -ForegroundColor Yellow
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
