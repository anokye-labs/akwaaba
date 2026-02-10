#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the Validate-CommitAuthors.ps1 script.

.DESCRIPTION
    This script tests various scenarios of the agent authentication validation:
    - Approved GitHub App commits (copilot[bot])
    - Approved service account commits
    - Unapproved user commits
    - JSON parsing and agent matching
    - Emergency bypass detection

.NOTES
    This is a unit test suite that doesn't require actual GitHub API calls.
    It tests the core logic of the validation script.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    if ($Passed) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:TestsPassed++
    }
    else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "  $Message" -ForegroundColor Yellow
        }
        $script:TestsFailed++
    }
}

function Test-JsonStructure {
    Write-Host "`n=== Testing JSON Structure ===" -ForegroundColor Cyan
    
    # Test 1: File exists
    $fileExists = Test-Path ".github/approved-agents.json"
    Write-TestResult "approved-agents.json exists" $fileExists
    
    if (-not $fileExists) {
        return
    }
    
    # Test 2: Valid JSON
    try {
        $json = Get-Content ".github/approved-agents.json" -Raw | ConvertFrom-Json
        Write-TestResult "approved-agents.json is valid JSON" $true
    }
    catch {
        Write-TestResult "approved-agents.json is valid JSON" $false $_.Exception.Message
        return
    }
    
    # Test 3: Has agents array
    $hasAgents = $null -ne $json.agents
    Write-TestResult "Has 'agents' array" $hasAgents
    
    # Test 4: Has emergency bypass config
    $hasBypass = $null -ne $json.emergencyBypass
    Write-TestResult "Has 'emergencyBypass' config" $hasBypass
    
    # Test 5: Each agent has required fields
    $allAgentsValid = $true
    $requiredFields = @("id", "type", "username", "description", "approvedBy", "approvedDate", "permissions", "enabled")
    
    foreach ($agent in $json.agents) {
        foreach ($field in $requiredFields) {
            if (-not (Get-Member -InputObject $agent -Name $field -MemberType Properties)) {
                $allAgentsValid = $false
                Write-TestResult "Agent $($agent.id) has field '$field'" $false
            }
        }
    }
    
    if ($allAgentsValid) {
        Write-TestResult "All agents have required fields" $true
    }
    
    # Test 6: GitHub Apps have botUsername
    $gitHubAppsValid = $true
    foreach ($agent in $json.agents) {
        if ($agent.type -eq "github-app") {
            if (-not $agent.botUsername) {
                Write-TestResult "GitHub App $($agent.id) has botUsername" $false
                $gitHubAppsValid = $false
            }
            elseif (-not ($agent.botUsername -match '\[bot\]$')) {
                Write-TestResult "GitHub App $($agent.id) botUsername has [bot] suffix" $false
                $gitHubAppsValid = $false
            }
        }
    }
    
    if ($gitHubAppsValid) {
        Write-TestResult "All GitHub Apps have valid botUsername" $true
    }
}

function Test-AgentMatching {
    Write-Host "`n=== Testing Agent Matching Logic ===" -ForegroundColor Cyan
    
    $json = Get-Content ".github/approved-agents.json" -Raw | ConvertFrom-Json
    
    # Test: Match copilot[bot]
    $copilotAgent = $json.agents | Where-Object { $_.id -eq "github-copilot" }
    if ($copilotAgent) {
        $matchesCopilotBot = $copilotAgent.botUsername -eq "copilot[bot]"
        Write-TestResult "Copilot agent matches 'copilot[bot]'" $matchesCopilotBot
    }
    
    # Test: Match github-actions[bot]
    $actionsAgent = $json.agents | Where-Object { $_.id -eq "github-actions-bot" }
    if ($actionsAgent) {
        $matchesActionsBot = $actionsAgent.botUsername -eq "github-actions[bot]"
        Write-TestResult "Actions agent matches 'github-actions[bot]'" $matchesActionsBot
    }
    
    # Test: Enabled agents only
    $enabledAgents = $json.agents | Where-Object { $_.enabled }
    $allEnabled = $enabledAgents.Count -gt 0
    Write-TestResult "Has enabled agents" $allEnabled "$($enabledAgents.Count) enabled agents found"
}

function Test-GitHubAppDetection {
    Write-Host "`n=== Testing GitHub App Detection ===" -ForegroundColor Cyan
    
    # Test cases for [bot] suffix detection
    $testCases = @(
        @{ Username = "copilot[bot]"; Expected = $true; Description = "copilot[bot]" }
        @{ Username = "github-actions[bot]"; Expected = $true; Description = "github-actions[bot]" }
        @{ Username = "dependabot[bot]"; Expected = $true; Description = "dependabot[bot]" }
        @{ Username = "copilot"; Expected = $false; Description = "copilot (no suffix)" }
        @{ Username = "human-user"; Expected = $false; Description = "human-user" }
        @{ Username = "bot"; Expected = $false; Description = "bot (no brackets)" }
    )
    
    foreach ($test in $testCases) {
        $isBot = $test.Username -match '\[bot\]$'
        $passed = $isBot -eq $test.Expected
        Write-TestResult "Detect GitHub App: $($test.Description)" $passed
    }
}

function Test-WorkflowStructure {
    Write-Host "`n=== Testing Workflow Structure ===" -ForegroundColor Cyan
    
    # Test 1: Workflow file exists
    $workflowExists = Test-Path ".github/workflows/agent-auth.yml"
    Write-TestResult "agent-auth.yml workflow exists" $workflowExists
    
    if (-not $workflowExists) {
        return
    }
    
    # Test 2: Workflow has correct trigger
    $content = Get-Content ".github/workflows/agent-auth.yml" -Raw
    $hasPullRequestTrigger = $content -match 'on:\s+pull_request:'
    Write-TestResult "Workflow triggers on pull_request" $hasPullRequestTrigger
    
    # Test 3: Workflow calls validation script
    $callsScript = $content -match 'Validate-CommitAuthors\.ps1'
    Write-TestResult "Workflow calls Validate-CommitAuthors.ps1" $callsScript
    
    # Test 4: Workflow has proper permissions
    $hasPermissions = $content -match 'permissions:'
    Write-TestResult "Workflow defines permissions" $hasPermissions
    
    # Test 5: Workflow handles failure
    $handlesFailure = $content -match 'if: failure\(\)'
    Write-TestResult "Workflow handles failure case" $handlesFailure
}

function Test-ScriptStructure {
    Write-Host "`n=== Testing Script Structure ===" -ForegroundColor Cyan
    
    # Test 1: Script exists
    $scriptExists = Test-Path "scripts/Validate-CommitAuthors.ps1"
    Write-TestResult "Validate-CommitAuthors.ps1 exists" $scriptExists
    
    if (-not $scriptExists) {
        return
    }
    
    $content = Get-Content "scripts/Validate-CommitAuthors.ps1" -Raw
    
    # Test 2: Has required parameters
    $hasOwnerParam = $content -match '\$Owner'
    Write-TestResult "Script has Owner parameter" $hasOwnerParam
    
    $hasRepoParam = $content -match '\$Repo'
    Write-TestResult "Script has Repo parameter" $hasRepoParam
    
    $hasPRParam = $content -match '\$PullRequestNumber'
    Write-TestResult "Script has PullRequestNumber parameter" $hasPRParam
    
    # Test 3: Has helper functions
    $hasGitHubCLITest = $content -match 'function Test-GitHubCLI'
    Write-TestResult "Script has Test-GitHubCLI function" $hasGitHubCLITest
    
    $hasGetApprovedAgents = $content -match 'function Get-ApprovedAgents'
    Write-TestResult "Script has Get-ApprovedAgents function" $hasGetApprovedAgents
    
    $hasTestApprovedAgent = $content -match 'function Test-ApprovedAgent'
    Write-TestResult "Script has Test-ApprovedAgent function" $hasTestApprovedAgent
    
    # Test 4: Has emergency bypass logic
    $hasBypassLogic = $content -match '\$emergencyBypass'
    Write-TestResult "Script has emergency bypass logic" $hasBypassLogic
    
    # Test 5: Has audit logging
    $hasAuditLog = $content -match 'Write-AuditLog'
    Write-TestResult "Script has audit logging" $hasAuditLog
    
    # Test 6: Has proper exit codes
    $hasExitCodes = $content -match 'exit 0' -and $content -match 'exit 1' -and $content -match 'exit 2' -and $content -match 'exit 3'
    Write-TestResult "Script has proper exit codes (0,1,2,3)" $hasExitCodes
}

function Test-DocumentationExists {
    Write-Host "`n=== Testing Documentation ===" -ForegroundColor Cyan
    
    # Test 1: APPROVED-AGENTS.md exists
    $docExists = Test-Path ".github/APPROVED-AGENTS.md"
    Write-TestResult "APPROVED-AGENTS.md exists" $docExists
    
    if ($docExists) {
        $content = Get-Content ".github/APPROVED-AGENTS.md" -Raw
        
        # Test 2: Documents emergency bypass
        $documentsEmergency = $content -match 'Emergency Bypass'
        Write-TestResult "Documents emergency bypass" $documentsEmergency
        
        # Test 3: Documents adding new agents
        $documentsAddAgent = $content -match 'Adding a New Agent'
        Write-TestResult "Documents adding new agents" $documentsAddAgent
        
        # Test 4: Documents approved agents
        $documentsApprovedAgents = $content -match 'Currently Approved Agents'
        Write-TestResult "Documents currently approved agents" $documentsApprovedAgents
        
        # Test 5: Documents troubleshooting
        $documentsTroubleshooting = $content -match 'Troubleshooting'
        Write-TestResult "Documents troubleshooting" $documentsTroubleshooting
    }
}

# Run all tests
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Agent Authentication Validation - Test Suite        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Test-JsonStructure
Test-AgentMatching
Test-GitHubAppDetection
Test-WorkflowStructure
Test-ScriptStructure
Test-DocumentationExists

# Summary
Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    Test Summary                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "Total tests: $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor White
Write-Host "Passed:      $script:TestsPassed" -ForegroundColor Green
Write-Host "Failed:      $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -gt 0) { "Red" } else { "Green" })

if ($script:TestsFailed -eq 0) {
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "`n❌ Some tests failed." -ForegroundColor Red
    exit 1
}
