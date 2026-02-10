#!/usr/bin/env pwsh
<#
.SYNOPSIS
Test suite for Validate-CommitAuthors.ps1

.DESCRIPTION
Comprehensive tests for the agent authentication validation script.
Tests include approved agents, unauthorized commits, and emergency bypass.
#>

$ErrorActionPreference = "Stop"

# Test setup
$scriptPath = Join-Path $PSScriptRoot "Validate-CommitAuthors.ps1"
$allowlistPath = Join-Path $PSScriptRoot ".." ".github" "approved-agents.json"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Suite: Validate-CommitAuthors.ps1" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$testResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
}

function Test-Case {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [bool]$Skip = $false
    )

    Write-Host "Test: $Name" -ForegroundColor Yellow
    
    if ($Skip) {
        Write-Host "  ⊘ SKIPPED" -ForegroundColor Gray
        $script:testResults.Skipped++
        Write-Host ""
        return
    }

    try {
        & $Test
        Write-Host "  ✅ PASSED" -ForegroundColor Green
        $script:testResults.Passed++
    } catch {
        Write-Host "  ❌ FAILED: $_" -ForegroundColor Red
        $script:testResults.Failed++
    }
    Write-Host ""
}

# Test 1: Allowlist loads correctly
Test-Case "Allowlist file loads correctly" {
    if (-not (Test-Path $allowlistPath)) {
        throw "Allowlist file not found"
    }

    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    if (-not $allowlist.agents) {
        throw "Allowlist missing 'agents' array"
    }

    if ($allowlist.agents.Count -lt 1) {
        throw "Allowlist should have at least one agent"
    }

    $agent = $allowlist.agents[0]
    if (-not $agent.username) {
        throw "Agent missing 'username' field"
    }
}

# Test 2: Allowlist includes Copilot agent
Test-Case "Allowlist includes copilot-swe-agent[bot]" {
    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    $copilotAgent = $allowlist.agents | Where-Object { $_.username -eq "copilot-swe-agent[bot]" }
    
    if (-not $copilotAgent) {
        throw "Copilot agent not found in allowlist"
    }

    if ($copilotAgent.type -ne "github-app") {
        throw "Copilot agent should be type 'github-app'"
    }
}

# Test 3: Allowlist includes GitHub Actions bot
Test-Case "Allowlist includes github-actions[bot]" {
    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    $actionsAgent = $allowlist.agents | Where-Object { $_.username -eq "github-actions[bot]" }
    
    if (-not $actionsAgent) {
        throw "GitHub Actions agent not found in allowlist"
    }
}

# Test 4: Allowlist includes Dependabot
Test-Case "Allowlist includes dependabot[bot]" {
    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    $dependabot = $allowlist.agents | Where-Object { $_.username -eq "dependabot[bot]" }
    
    if (-not $dependabot) {
        throw "Dependabot not found in allowlist"
    }
}

# Test 5: Script file exists and is executable
Test-Case "Validation script exists" {
    if (-not (Test-Path $scriptPath)) {
        throw "Script file not found: $scriptPath"
    }

    $content = Get-Content $scriptPath -Raw
    
    if (-not ($content -match "param\s*\(")) {
        throw "Script missing parameter block"
    }

    if (-not ($content -match "\-Owner")) {
        throw "Script missing -Owner parameter"
    }

    if (-not ($content -match "\-Repo")) {
        throw "Script missing -Repo parameter"
    }

    if (-not ($content -match "\-PullNumber")) {
        throw "Script missing -PullNumber parameter"
    }
}

# Test 6: Script has required functions
Test-Case "Script contains required functions" {
    $content = Get-Content $scriptPath -Raw
    
    $requiredFunctions = @(
        "Get-ApprovedAgents",
        "Test-ApprovedAgent",
        "Get-PRCommits"
    )

    foreach ($func in $requiredFunctions) {
        if (-not ($content -match "function\s+$func")) {
            throw "Missing required function: $func"
        }
    }
}

# Test 7: Script has emergency bypass logic
Test-Case "Script includes emergency bypass handling" {
    $content = Get-Content $scriptPath -Raw
    
    if (-not ($content -match "emergency")) {
        throw "Script missing emergency bypass logic"
    }

    if (-not ($content -match "EmergencyBypassLabel")) {
        throw "Script missing EmergencyBypassLabel parameter"
    }
}

# Test 8: Script has proper error messaging
Test-Case "Script has user-friendly error messages" {
    $content = Get-Content $scriptPath -Raw
    
    $requiredMessages = @(
        "agent-only",
        "unauthorized",
        "approved agents"
    )

    foreach ($msg in $requiredMessages) {
        if (-not ($content -match $msg)) {
            throw "Missing error message keyword: $msg"
        }
    }
}

# Test 9: Allowlist has valid JSON schema
Test-Case "Allowlist uses valid JSON schema" {
    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    if ($allowlist.'$schema' -notmatch "json-schema.org") {
        throw "Allowlist missing or invalid JSON schema"
    }
}

# Test 10: All agents have required fields
Test-Case "All agents have required fields" {
    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    $requiredFields = @("username", "type", "description", "approvedBy", "approvedDate")
    
    foreach ($agent in $allowlist.agents) {
        foreach ($field in $requiredFields) {
            if (-not $agent.$field) {
                throw "Agent $($agent.username) missing field: $field"
            }
        }
    }
}

# Test 11: Agent usernames follow bot naming convention
Test-Case "Agent usernames follow naming convention" {
    $allowlist = Get-Content $allowlistPath -Raw | ConvertFrom-Json
    
    foreach ($agent in $allowlist.agents) {
        if ($agent.type -eq "github-app") {
            if ($agent.username -notmatch "\[bot\]$") {
                throw "GitHub App agent should end with [bot]: $($agent.username)"
            }
        }
    }
}

# Test 12: Script has audit logging
Test-Case "Script includes audit logging" {
    $content = Get-Content $scriptPath -Raw
    
    if (-not ($content -match "audit|log")) {
        throw "Script missing audit/logging references"
    }
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✅ Passed:  $($testResults.Passed)" -ForegroundColor Green
Write-Host "  ❌ Failed:  $($testResults.Failed)" -ForegroundColor Red
Write-Host "  ⊘  Skipped: $($testResults.Skipped)" -ForegroundColor Gray
Write-Host ""

$total = $testResults.Passed + $testResults.Failed + $testResults.Skipped
$passRate = if ($total -gt 0) { [math]::Round(($testResults.Passed / $total) * 100, 1) } else { 0 }

Write-Host "  Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })
Write-Host ""

if ($testResults.Failed -gt 0) {
    Write-Host "❌ Some tests failed!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
}
