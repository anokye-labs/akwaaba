<#
.SYNOPSIS
    Tests for Update-AutoApproveConfig.ps1

.DESCRIPTION
    Unit and integration tests for the Update-AutoApproveConfig.ps1 script.
    Tests include parameter validation, config file operations, schema validation,
    and all CRUD operations (List, Get, Add, Remove, Update).

.NOTES
    Author: Anokye Labs
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test-Update-AutoApproveConfig.ps1" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsTotal = 0

function Test-Assert {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        
        [Parameter(Mandatory = $false)]
        [string]$Message = ""
    )
    
    $script:TestsTotal++
    
    if ($Condition) {
        $script:TestsPassed++
        Write-Host "  ✓ " -NoNewline -ForegroundColor Green
        Write-Host $TestName -ForegroundColor White
    }
    else {
        $script:TestsFailed++
        Write-Host "  ✗ " -NoNewline -ForegroundColor Red
        Write-Host $TestName -ForegroundColor White
        if ($Message) {
            Write-Host "    $Message" -ForegroundColor DarkGray
        }
    }
}

#region Setup

# Create temporary test directory
$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "test-auto-approve-$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

# Create test config structure
$testConfigDir = Join-Path $testDir ".github/okyerema"
New-Item -ItemType Directory -Path $testConfigDir -Force | Out-Null

$testConfigPath = Join-Path $testConfigDir "auto-approve.json"

# Create initial test config
$initialConfig = @{
    version = "1.0"
    rules = @(
        @{
            id = "test-rule-1"
            name = "Test Rule 1"
            enabled = $true
            conditions = @{
                author = "copilot"
                filesChanged = @{
                    patterns = @("*.md")
                    maxCount = 5
                }
            }
            checks = @{
                requireCI = $true
                requireReviews = 0
                noConflicts = $true
            }
            description = "Test rule for documentation"
        }
        @{
            id = "test-rule-2"
            name = "Test Rule 2"
            enabled = $false
            conditions = @{
                author = "bot"
            }
            description = "Disabled test rule"
        }
    )
}

$initialConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $testConfigPath -Encoding UTF8

Write-Host "Test Setup:" -ForegroundColor Yellow
Write-Host "  Test Directory: $testDir" -ForegroundColor Gray
Write-Host "  Config Path: $testConfigPath" -ForegroundColor Gray
Write-Host ""

#endregion

#region Unit Tests

Write-Host "Unit Tests" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Test: Script exists
$scriptPath = Join-Path $PSScriptRoot "Update-AutoApproveConfig.ps1"
Test-Assert -TestName "Script file exists" -Condition (Test-Path $scriptPath)

# Test: Script can be parsed (syntax check)
try {
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
    Test-Assert -TestName "Script syntax is valid" -Condition $true
}
catch {
    Test-Assert -TestName "Script syntax is valid" -Condition $false -Message $_.Exception.Message
}

# Test: Script has required parameters
$scriptContent = Get-Content $scriptPath -Raw
Test-Assert -TestName "Script has Operation parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[ValidateSet.*List.*Add.*Remove.*Update.*Get.*\]\s*\[string\]\$Operation')
Test-Assert -TestName "Script has RuleId parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$RuleId')
Test-Assert -TestName "Script has RuleName parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$RuleName')
Test-Assert -TestName "Script has RuleEnabled parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[Nullable\[bool\]\]\$RuleEnabled')
Test-Assert -TestName "Script has RuleDescription parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$RuleDescription')
Test-Assert -TestName "Script has RuleConditions parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[object\]\$RuleConditions')
Test-Assert -TestName "Script has RuleChecks parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[object\]\$RuleChecks')
Test-Assert -TestName "Script has DryRun parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[switch\]\$DryRun')
Test-Assert -TestName "Script has OutputFormat parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[ValidateSet.*Console.*Json.*\]\s*\[string\]\$OutputFormat')
Test-Assert -TestName "Script has ConfigPath parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$ConfigPath')

# Test: Script has helper functions
Test-Assert -TestName "Script has Get-ConfigFilePath function" -Condition ($scriptContent -match 'function Get-ConfigFilePath')
Test-Assert -TestName "Script has Read-ConfigFile function" -Condition ($scriptContent -match 'function Read-ConfigFile')
Test-Assert -TestName "Script has Write-ConfigFile function" -Condition ($scriptContent -match 'function Write-ConfigFile')
Test-Assert -TestName "Script has Test-ConfigSchema function" -Condition ($scriptContent -match 'function Test-ConfigSchema')
Test-Assert -TestName "Script has Convert-ToHashtable function" -Condition ($scriptContent -match 'function Convert-ToHashtable')
Test-Assert -TestName "Script has New-Result function" -Condition ($scriptContent -match 'function New-Result')
Test-Assert -TestName "Script has Format-Output function" -Condition ($scriptContent -match 'function Format-Output')

# Test: Script supports all operations
Test-Assert -TestName "Script implements List operation" -Condition ($scriptContent -match '"List"')
Test-Assert -TestName "Script implements Get operation" -Condition ($scriptContent -match '"Get"')
Test-Assert -TestName "Script implements Add operation" -Condition ($scriptContent -match '"Add"')
Test-Assert -TestName "Script implements Remove operation" -Condition ($scriptContent -match '"Remove"')
Test-Assert -TestName "Script implements Update operation" -Condition ($scriptContent -match '"Update"')

# Test: Script has schema validation
Test-Assert -TestName "Script validates config schema" -Condition ($scriptContent -match 'Test-ConfigSchema')
Test-Assert -TestName "Script checks for version field" -Condition ($scriptContent -match 'version')
Test-Assert -TestName "Script checks for rules field" -Condition ($scriptContent -match 'rules')

# Test: Script has proper error handling
Test-Assert -TestName "Script sets ErrorActionPreference" -Condition ($scriptContent -match '\$ErrorActionPreference\s*=\s*"Stop"')
Test-Assert -TestName "Script has try-catch blocks" -Condition ($scriptContent -match 'try\s*\{' -and $scriptContent -match 'catch\s*\{')

# Test: Script supports both output formats
Test-Assert -TestName "Script supports Console output" -Condition ($scriptContent -match '"Console"' -and $scriptContent -match 'Write-Host')
Test-Assert -TestName "Script supports Json output" -Condition ($scriptContent -match '"Json"' -and $scriptContent -match 'ConvertTo-Json')

# Test: Script uses DryRun mode
Test-Assert -TestName "Script checks DryRun flag" -Condition ($scriptContent -match 'if.*-not.*\$DryRun')
Test-Assert -TestName "Script shows DryRun in output" -Condition ($scriptContent -match 'DRY RUN')

Write-Host ""

#endregion

#region Integration Tests

Write-Host "Integration Tests" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Test: List operation
try {
    $result = & $scriptPath -Operation List -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "List operation succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "List returns correct count" -Condition ($resultObj.Rules.Count -eq 2)
    Test-Assert -TestName "List includes test-rule-1" -Condition ($resultObj.Rules.id -contains "test-rule-1")
    Test-Assert -TestName "List includes test-rule-2" -Condition ($resultObj.Rules.id -contains "test-rule-2")
}
catch {
    Test-Assert -TestName "List operation succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "List returns correct count" -Condition $false
    Test-Assert -TestName "List includes test-rule-1" -Condition $false
    Test-Assert -TestName "List includes test-rule-2" -Condition $false
}

# Test: Get operation - existing rule
try {
    $result = & $scriptPath -Operation Get -RuleId "test-rule-1" -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Get operation succeeds for existing rule" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Get returns correct rule" -Condition ($resultObj.Rules.id -eq "test-rule-1")
    Test-Assert -TestName "Get returns rule name" -Condition ($resultObj.Rules.name -eq "Test Rule 1")
}
catch {
    Test-Assert -TestName "Get operation succeeds for existing rule" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Get returns correct rule" -Condition $false
    Test-Assert -TestName "Get returns rule name" -Condition $false
}

# Test: Get operation - non-existent rule
try {
    $result = & $scriptPath -Operation Get -RuleId "non-existent" -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Get operation fails for non-existent rule" -Condition ($resultObj.Success -eq $false)
}
catch {
    Test-Assert -TestName "Get operation fails for non-existent rule" -Condition $true
}

# Test: Add operation - DryRun
try {
    $conditions = '{"author":"copilot","filesChanged":{"patterns":["*.ps1"],"maxCount":3}}'
    $checks = '{"requireCI":true,"requireReviews":1}'
    $result = & $scriptPath -Operation Add -RuleId "test-rule-3" -RuleName "Test Rule 3" `
        -RuleConditions $conditions -RuleChecks $checks -RuleDescription "New test rule" `
        -ConfigPath $testConfigPath -OutputFormat Json -DryRun 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Add operation DryRun succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Add operation DryRun flag set" -Condition ($resultObj.DryRun -eq $true)
    
    # Verify file wasn't actually changed
    $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
    Test-Assert -TestName "Add DryRun doesn't modify file" -Condition ($config.rules.Count -eq 2)
}
catch {
    Test-Assert -TestName "Add operation DryRun succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Add operation DryRun flag set" -Condition $false
    Test-Assert -TestName "Add DryRun doesn't modify file" -Condition $false
}

# Test: Add operation - actual add
try {
    $conditions = '{"author":"copilot","filesChanged":{"patterns":["*.ps1"],"maxCount":3}}'
    $checks = '{"requireCI":true,"requireReviews":1}'
    $result = & $scriptPath -Operation Add -RuleId "test-rule-3" -RuleName "Test Rule 3" `
        -RuleConditions $conditions -RuleChecks $checks -RuleDescription "New test rule" `
        -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Add operation succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Add operation returns new rule" -Condition ($resultObj.Rules.id -eq "test-rule-3")
    
    # Verify file was actually changed
    $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
    Test-Assert -TestName "Add operation modifies file" -Condition ($config.rules.Count -eq 3)
    Test-Assert -TestName "Add operation adds correct rule" -Condition ($config.rules.id -contains "test-rule-3")
}
catch {
    Test-Assert -TestName "Add operation succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Add operation returns new rule" -Condition $false
    Test-Assert -TestName "Add operation modifies file" -Condition $false
    Test-Assert -TestName "Add operation adds correct rule" -Condition $false
}

# Test: Add operation - duplicate rule
try {
    $conditions = '{"author":"copilot"}'
    $result = & $scriptPath -Operation Add -RuleId "test-rule-1" -RuleName "Duplicate" `
        -RuleConditions $conditions -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Add operation fails for duplicate rule" -Condition ($resultObj.Success -eq $false)
}
catch {
    Test-Assert -TestName "Add operation fails for duplicate rule" -Condition $true
}

# Test: Update operation - DryRun
try {
    $result = & $scriptPath -Operation Update -RuleId "test-rule-1" -RuleEnabled $false `
        -ConfigPath $testConfigPath -OutputFormat Json -DryRun 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Update operation DryRun succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Update operation DryRun flag set" -Condition ($resultObj.DryRun -eq $true)
    
    # Verify file wasn't actually changed
    $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
    $rule = $config.rules | Where-Object { $_.id -eq "test-rule-1" }
    Test-Assert -TestName "Update DryRun doesn't modify file" -Condition ($rule.enabled -eq $true)
}
catch {
    Test-Assert -TestName "Update operation DryRun succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Update operation DryRun flag set" -Condition $false
    Test-Assert -TestName "Update DryRun doesn't modify file" -Condition $false
}

# Test: Update operation - actual update
try {
    $result = & $scriptPath -Operation Update -RuleId "test-rule-1" -RuleEnabled $false `
        -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Update operation succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Update operation returns updated rule" -Condition ($resultObj.Rules.enabled -eq $false)
    
    # Verify file was actually changed
    $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
    $rule = $config.rules | Where-Object { $_.id -eq "test-rule-1" }
    Test-Assert -TestName "Update operation modifies file" -Condition ($rule.enabled -eq $false)
}
catch {
    Test-Assert -TestName "Update operation succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Update operation returns updated rule" -Condition $false
    Test-Assert -TestName "Update operation modifies file" -Condition $false
}

# Test: Update operation - non-existent rule
try {
    $result = & $scriptPath -Operation Update -RuleId "non-existent" -RuleEnabled $true `
        -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Update operation fails for non-existent rule" -Condition ($resultObj.Success -eq $false)
}
catch {
    Test-Assert -TestName "Update operation fails for non-existent rule" -Condition $true
}

# Test: Remove operation - DryRun
try {
    $result = & $scriptPath -Operation Remove -RuleId "test-rule-2" `
        -ConfigPath $testConfigPath -OutputFormat Json -DryRun 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Remove operation DryRun succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Remove operation DryRun flag set" -Condition ($resultObj.DryRun -eq $true)
    
    # Verify file wasn't actually changed
    $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
    Test-Assert -TestName "Remove DryRun doesn't modify file" -Condition ($config.rules.Count -eq 3)
}
catch {
    Test-Assert -TestName "Remove operation DryRun succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Remove operation DryRun flag set" -Condition $false
    Test-Assert -TestName "Remove DryRun doesn't modify file" -Condition $false
}

# Test: Remove operation - actual remove
try {
    $result = & $scriptPath -Operation Remove -RuleId "test-rule-2" `
        -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Remove operation succeeds" -Condition ($resultObj.Success -eq $true)
    Test-Assert -TestName "Remove operation returns removed rule" -Condition ($resultObj.Rules.id -eq "test-rule-2")
    
    # Verify file was actually changed
    $config = Get-Content $testConfigPath -Raw | ConvertFrom-Json
    Test-Assert -TestName "Remove operation modifies file" -Condition ($config.rules.Count -eq 2)
    Test-Assert -TestName "Remove operation removes correct rule" -Condition ($config.rules.id -notcontains "test-rule-2")
}
catch {
    Test-Assert -TestName "Remove operation succeeds" -Condition $false -Message $_.Exception.Message
    Test-Assert -TestName "Remove operation returns removed rule" -Condition $false
    Test-Assert -TestName "Remove operation modifies file" -Condition $false
    Test-Assert -TestName "Remove operation removes correct rule" -Condition $false
}

# Test: Remove operation - non-existent rule
try {
    $result = & $scriptPath -Operation Remove -RuleId "non-existent" `
        -ConfigPath $testConfigPath -OutputFormat Json 2>&1
    $resultObj = $result | ConvertFrom-Json
    Test-Assert -TestName "Remove operation fails for non-existent rule" -Condition ($resultObj.Success -eq $false)
}
catch {
    Test-Assert -TestName "Remove operation fails for non-existent rule" -Condition $true
}

Write-Host ""

#endregion

#region Cleanup

# Clean up test directory
Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue

#endregion

#region Summary

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Tests: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsTotal -ForegroundColor White
Write-Host "  Passed: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsPassed -ForegroundColor Green
Write-Host "  Failed: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsFailed -ForegroundColor $(if ($script:TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "  All tests passed! ✓" -ForegroundColor Green
}
else {
    Write-Host "  Some tests failed. Please review." -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Exit with appropriate code
if ($script:TestsFailed -gt 0) {
    exit 1
}
else {
    exit 0
}

#endregion
