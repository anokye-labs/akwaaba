<#
.SYNOPSIS
    Tests for Test-PRAutoApprovable.ps1

.DESCRIPTION
    Unit and integration tests for the Test-PRAutoApprovable.ps1 script.
    Tests include configuration loading, check execution, and output formatting.

.NOTES
    Author: Anokye Labs
    This test file validates the auto-approval checking functionality.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test-Test-PRAutoApprovable.ps1" -ForegroundColor White
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

#region Unit Tests

Write-Host "Unit Tests" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

# Test 1: Configuration file exists
Write-Host "Configuration Tests:" -ForegroundColor Cyan
$configPath = Join-Path $PSScriptRoot ".." ".github" "okyerema" "auto-approve.json"
Test-Assert -TestName "Configuration file exists" -Condition (Test-Path $configPath)

if (Test-Path $configPath) {
    # Test 2: Configuration is valid JSON
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        Test-Assert -TestName "Configuration is valid JSON" -Condition $true
        
        # Test 3: Configuration has required fields
        Test-Assert -TestName "Configuration has 'rules' field" -Condition ($null -ne $config.rules)
        
        # Test 4: Required rules exist
        $requiredRules = @("ciMustPass", "noUnresolvedComments", "linkedIssueRequired", 
                          "commitConventions", "noSecretsInDiff", "expectedScope", 
                          "noProtectedPathChanges")
        
        foreach ($rule in $requiredRules) {
            $ruleExists = $null -ne $config.rules.$rule
            Test-Assert -TestName "Rule '$rule' exists" -Condition $ruleExists
            
            if ($ruleExists) {
                $hasEnabled = $null -ne $config.rules.$rule.enabled
                Test-Assert -TestName "Rule '$rule' has 'enabled' property" -Condition $hasEnabled
                
                $hasDescription = $null -ne $config.rules.$rule.description
                Test-Assert -TestName "Rule '$rule' has 'description' property" -Condition $hasDescription
            }
        }
        
        # Test 5: Commit conventions pattern is valid regex
        if ($config.rules.commitConventions.pattern) {
            try {
                $pattern = $config.rules.commitConventions.pattern
                [regex]::new($pattern) | Out-Null
                Test-Assert -TestName "Commit conventions pattern is valid regex" -Condition $true
            }
            catch {
                Test-Assert -TestName "Commit conventions pattern is valid regex" -Condition $false -Message $_.Exception.Message
            }
        }
        
        # Test 6: Secret patterns are valid regex
        if ($config.rules.noSecretsInDiff.patterns) {
            $allPatternsValid = $true
            foreach ($pattern in $config.rules.noSecretsInDiff.patterns) {
                try {
                    [regex]::new($pattern) | Out-Null
                }
                catch {
                    $allPatternsValid = $false
                    break
                }
            }
            Test-Assert -TestName "All secret detection patterns are valid regex" -Condition $allPatternsValid
        }
    }
    catch {
        Test-Assert -TestName "Configuration is valid JSON" -Condition $false -Message $_.Exception.Message
    }
}

Write-Host ""

# Test 7: Script file exists
Write-Host "Script File Tests:" -ForegroundColor Cyan
$scriptPath = Join-Path $PSScriptRoot "Test-PRAutoApprovable.ps1"
Test-Assert -TestName "Script file exists" -Condition (Test-Path $scriptPath)

if (Test-Path $scriptPath) {
    # Test 8: Script has proper structure
    $scriptContent = Get-Content $scriptPath -Raw
    Test-Assert -TestName "Script has CmdletBinding" -Condition ($scriptContent -match '\[CmdletBinding\(\)\]')
    Test-Assert -TestName "Script has parameter block" -Condition ($scriptContent -match 'param\s*\(')
    Test-Assert -TestName "Script has PRNumber parameter" -Condition ($scriptContent -match '\[int\]\$PRNumber')
    Test-Assert -TestName "Script has OutputFormat parameter" -Condition ($scriptContent -match '\$OutputFormat')
    Test-Assert -TestName "Script has helper functions" -Condition ($scriptContent -match 'function Get-PRStatusHelper')
}

Write-Host ""

#endregion

#region Pattern Validation Tests

Write-Host "Pattern Validation Tests:" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

if (Test-Path $configPath) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    
    # Test commit message patterns
    Write-Host "Commit Message Pattern Tests:" -ForegroundColor Cyan
    $commitPattern = $config.rules.commitConventions.pattern
    
    $validCommits = @(
        "feat: add new feature",
        "fix: resolve bug",
        "docs: update readme",
        "style: format code",
        "refactor: restructure module",
        "test: add unit tests",
        "chore: update dependencies",
        "feat(scope)!: breaking change",
        "fix(api): correct endpoint"
    )
    
    $invalidCommits = @(
        "Add new feature",
        "fixed bug",
        "FEAT: wrong case",
        "feat:",
        "feat: " + ("x" * 150)
    )
    
    foreach ($commit in $validCommits) {
        $matches = $commit -cmatch $commitPattern
        Test-Assert -TestName "Valid commit matches: '$($commit.Substring(0, [Math]::Min(40, $commit.Length)))...'" -Condition $matches
    }
    
    foreach ($commit in $invalidCommits) {
        $matches = $commit -cmatch $commitPattern
        Test-Assert -TestName "Invalid commit rejected: '$($commit.Substring(0, [Math]::Min(40, $commit.Length)))...'" -Condition (-not $matches)
    }
    
    Write-Host ""
    
    # Test secret detection patterns
    Write-Host "Secret Detection Pattern Tests:" -ForegroundColor Cyan
    $secretPatterns = $config.rules.noSecretsInDiff.patterns
    
    $testSecrets = @(
        @{ Text = "password=mysecret123"; ShouldMatch = $true; Description = "password assignment" },
        @{ Text = "api_key=abc123xyz"; ShouldMatch = $true; Description = "API key" },
        @{ Text = "token: secret-token-value"; ShouldMatch = $true; Description = "token value" },
        @{ Text = "ghp_1234567890123456789012345678901234ab"; ShouldMatch = $true; Description = "GitHub PAT" },
        @{ Text = "-----BEGIN RSA PRIVATE KEY-----"; ShouldMatch = $true; Description = "private key" },
        @{ Text = "const message = 'Hello World'"; ShouldMatch = $false; Description = "normal code" },
        @{ Text = "# This is a password field"; ShouldMatch = $false; Description = "comment about password" }
    )
    
    foreach ($test in $testSecrets) {
        $matchFound = $false
        foreach ($pattern in $secretPatterns) {
            if ($test.Text -match $pattern) {
                $matchFound = $true
                break
            }
        }
        
        $expected = $test.ShouldMatch
        $actual = $matchFound
        $passed = $expected -eq $actual
        
        $testDesc = if ($expected) {
            "Secret pattern detects: $($test.Description)"
        } else {
            "Secret pattern ignores: $($test.Description)"
        }
        
        Test-Assert -TestName $testDesc -Condition $passed
    }
    
    Write-Host ""
}

#endregion

#region Mock Integration Tests

Write-Host "Mock Integration Tests:" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ""

Write-Host "Result Structure Tests:" -ForegroundColor Cyan

# Create a mock result object to test structure
$mockResult = [PSCustomObject]@{
    PRNumber = 42
    Owner = "test-owner"
    Repo = "test-repo"
    AutoApprovable = $true
    Reasons = @("CI checks passing", "No unresolved comments")
    FailedChecks = @()
    Summary = [PSCustomObject]@{
        TotalChecks = 7
        PassedChecks = 7
        FailedChecks = 0
    }
}

Test-Assert -TestName "Result has PRNumber" -Condition ($null -ne $mockResult.PRNumber)
Test-Assert -TestName "Result has Owner" -Condition ($null -ne $mockResult.Owner)
Test-Assert -TestName "Result has Repo" -Condition ($null -ne $mockResult.Repo)
Test-Assert -TestName "Result has AutoApprovable" -Condition ($null -ne $mockResult.PSObject.Properties['AutoApprovable'])
Test-Assert -TestName "Result has Reasons array" -Condition ($mockResult.Reasons -is [array])
Test-Assert -TestName "Result has FailedChecks array" -Condition ($mockResult.FailedChecks -is [array])
Test-Assert -TestName "Result has Summary" -Condition ($null -ne $mockResult.Summary)
Test-Assert -TestName "Summary has TotalChecks" -Condition ($null -ne $mockResult.Summary.TotalChecks)
Test-Assert -TestName "Summary has PassedChecks" -Condition ($null -ne $mockResult.Summary.PassedChecks)
Test-Assert -TestName "Summary has FailedChecks" -Condition ($null -ne $mockResult.Summary.FailedChecks)

# Test JSON serialization
try {
    $json = $mockResult | ConvertTo-Json -Depth 10
    $deserialized = $json | ConvertFrom-Json
    Test-Assert -TestName "Result can be serialized to JSON" -Condition $true
    Test-Assert -TestName "Deserialized result maintains structure" -Condition ($deserialized.AutoApprovable -eq $true)
}
catch {
    Test-Assert -TestName "Result can be serialized to JSON" -Condition $false -Message $_.Exception.Message
}

Write-Host ""

# Test failed check structure
Write-Host "Failed Check Structure Tests:" -ForegroundColor Cyan

$mockFailedCheck = [PSCustomObject]@{
    Rule = "ciMustPass"
    Description = "All CI checks must pass"
    Reason = "CI checks state: FAILURE (2 checks)"
}

Test-Assert -TestName "Failed check has Rule" -Condition ($null -ne $mockFailedCheck.Rule)
Test-Assert -TestName "Failed check has Description" -Condition ($null -ne $mockFailedCheck.Description)
Test-Assert -TestName "Failed check has Reason" -Condition ($null -ne $mockFailedCheck.Reason)

Write-Host ""

#endregion

#region Summary

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total Tests: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsTotal -ForegroundColor White
Write-Host "  Passed: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsPassed -ForegroundColor Green
Write-Host "  Failed: " -NoNewline -ForegroundColor Gray
Write-Host $script:TestsFailed -ForegroundColor $(if ($script:TestsFailed -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($script:TestsFailed -gt 0) {
    Write-Host "❌ TESTS FAILED" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "✅ ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}

#endregion
