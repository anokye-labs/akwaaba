<#
.SYNOPSIS
    Tests for Get-PRStatus.ps1

.DESCRIPTION
    Unit and integration tests for the Get-PRStatus.ps1 script.
    Tests include parameter validation, GraphQL query building, and output formatting.

.NOTES
    Author: Anokye Labs
    This test file uses local function definitions to avoid executing the main script.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test-Get-PRStatus.ps1" -ForegroundColor White
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

# Copy helper function from Get-PRStatus.ps1 for testing
function Get-HumanReadableDuration {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime = (Get-Date)
    )
    
    $timeSpan = $EndTime - $StartTime
    
    if ($timeSpan.TotalDays -ge 1) {
        $days = [math]::Floor($timeSpan.TotalDays)
        $hours = $timeSpan.Hours
        if ($days -eq 1) {
            return "1 day, $hours hours"
        }
        return "$days days, $hours hours"
    }
    elseif ($timeSpan.TotalHours -ge 1) {
        $hours = [math]::Floor($timeSpan.TotalHours)
        $minutes = $timeSpan.Minutes
        if ($hours -eq 1) {
            return "1 hour, $minutes minutes"
        }
        return "$hours hours, $minutes minutes"
    }
    elseif ($timeSpan.TotalMinutes -ge 1) {
        $minutes = [math]::Floor($timeSpan.TotalMinutes)
        if ($minutes -eq 1) {
            return "1 minute"
        }
        return "$minutes minutes"
    }
    else {
        return "less than a minute"
    }
}

#region Unit Tests

Write-Host "Unit Tests" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Test: Get-HumanReadableDuration - Less than a minute
$now = Get-Date
$duration = Get-HumanReadableDuration -StartTime $now.AddSeconds(-30) -EndTime $now
Test-Assert -TestName "Duration: Less than a minute" -Condition ($duration -eq "less than a minute")

# Test: Get-HumanReadableDuration - Exactly 1 minute
$duration = Get-HumanReadableDuration -StartTime $now.AddMinutes(-1) -EndTime $now
Test-Assert -TestName "Duration: Exactly 1 minute" -Condition ($duration -eq "1 minute")

# Test: Get-HumanReadableDuration - Multiple minutes
$duration = Get-HumanReadableDuration -StartTime $now.AddMinutes(-5) -EndTime $now
Test-Assert -TestName "Duration: 5 minutes" -Condition ($duration -eq "5 minutes")

# Test: Get-HumanReadableDuration - Exactly 1 hour
$duration = Get-HumanReadableDuration -StartTime $now.AddHours(-1) -EndTime $now
Test-Assert -TestName "Duration: Exactly 1 hour" -Condition ($duration -match "1 hour")

# Test: Get-HumanReadableDuration - Multiple hours
$duration = Get-HumanReadableDuration -StartTime $now.AddHours(-3).AddMinutes(-15) -EndTime $now
Test-Assert -TestName "Duration: 3 hours 15 minutes" -Condition ($duration -match "3 hours, 15 minutes")

# Test: Get-HumanReadableDuration - Exactly 1 day
$duration = Get-HumanReadableDuration -StartTime $now.AddDays(-1) -EndTime $now
Test-Assert -TestName "Duration: Exactly 1 day" -Condition ($duration -match "1 day")

# Test: Get-HumanReadableDuration - Multiple days
$duration = Get-HumanReadableDuration -StartTime $now.AddDays(-5).AddHours(-3) -EndTime $now
Test-Assert -TestName "Duration: 5 days" -Condition ($duration -match "5 days")

Write-Host ""

#endregion

#region Integration Tests

Write-Host "Integration Tests" -ForegroundColor Yellow
Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Test: Script exists
$scriptPath = Join-Path $PSScriptRoot "Get-PRStatus.ps1"
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
Test-Assert -TestName "Script has PRNumber parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[int\]\$PRNumber')
Test-Assert -TestName "Script has Owner parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$Owner')
Test-Assert -TestName "Script has Repo parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$Repo')
Test-Assert -TestName "Script has OutputFormat parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[ValidateSet.*Console.*Markdown.*Json.*\]\s*\[string\]\$OutputFormat')
Test-Assert -TestName "Script has DryRun parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[switch\]\$DryRun')
Test-Assert -TestName "Script has CorrelationId parameter" -Condition ($scriptContent -match '\[Parameter.*\]\s*\[string\]\$CorrelationId')

# Test: Script contains GraphQL query
Test-Assert -TestName "Script contains GraphQL query" -Condition ($scriptContent -match 'query\(' -and $scriptContent -match 'pullRequest')

# Test: Script queries for merge status
Test-Assert -TestName "GraphQL query includes mergeable field" -Condition ($scriptContent -match 'mergeable')
Test-Assert -TestName "GraphQL query includes statusCheckRollup" -Condition ($scriptContent -match 'statusCheckRollup')

# Test: Script queries for review status
Test-Assert -TestName "GraphQL query includes reviewDecision field" -Condition ($scriptContent -match 'reviewDecision')
Test-Assert -TestName "GraphQL query includes reviews field" -Condition ($scriptContent -match 'reviews\(')

# Test: Script queries for linked issues
Test-Assert -TestName "GraphQL query includes closingIssuesReferences" -Condition ($scriptContent -match 'closingIssuesReferences')

# Test: Script queries for comment threads
Test-Assert -TestName "GraphQL query includes reviewThreads field" -Condition ($scriptContent -match 'reviewThreads')
Test-Assert -TestName "GraphQL query includes isResolved field" -Condition ($scriptContent -match 'isResolved')

# Test: Script queries for timeline events
Test-Assert -TestName "GraphQL query includes timelineItems field" -Condition ($scriptContent -match 'timelineItems')
Test-Assert -TestName "GraphQL query includes READY_FOR_REVIEW_EVENT" -Condition ($scriptContent -match 'READY_FOR_REVIEW_EVENT')
Test-Assert -TestName "GraphQL query includes CONVERT_TO_DRAFT_EVENT" -Condition ($scriptContent -match 'CONVERT_TO_DRAFT_EVENT')

# Test: Script has helper functions
Test-Assert -TestName "Script has Invoke-GraphQLHelper function" -Condition ($scriptContent -match 'function Invoke-GraphQLHelper')
Test-Assert -TestName "Script has Get-RepoContextHelper function" -Condition ($scriptContent -match 'function Get-RepoContextHelper')
Test-Assert -TestName "Script has Write-OkyeremaLogHelper function" -Condition ($scriptContent -match 'function Write-OkyeremaLogHelper')
Test-Assert -TestName "Script has Get-HumanReadableDuration function" -Condition ($scriptContent -match 'function Get-HumanReadableDuration')

# Test: Script supports all output formats
Test-Assert -TestName "Script supports Console output" -Condition ($scriptContent -match '"Console"')
Test-Assert -TestName "Script supports Markdown output" -Condition ($scriptContent -match '"Markdown"')
Test-Assert -TestName "Script supports Json output" -Condition ($scriptContent -match '"Json"')

# Test: Script has proper switch statement for output formatting
Test-Assert -TestName "Script uses switch for output formatting" -Condition ($scriptContent -match 'switch\s*\(\$OutputFormat\)')

# Test: Console output uses colored output
Test-Assert -TestName "Console output uses Write-Host with colors" -Condition ($scriptContent -match 'Write-Host.*-ForegroundColor')

# Test: Markdown output generates proper headers
Test-Assert -TestName "Markdown output has headers" -Condition ($scriptContent -match '# PR #')
Test-Assert -TestName "Markdown output has tables" -Condition ($scriptContent -match '\|\s*Property\s*\|\s*Value\s*\|')

# Test: Json output uses ConvertTo-Json
Test-Assert -TestName "Json output uses ConvertTo-Json" -Condition ($scriptContent -match 'ConvertTo-Json\s+-Depth\s+10')

# Test: Script uses dependencies correctly
Test-Assert -TestName "Script calls Invoke-GraphQL.ps1" -Condition ($scriptContent -match '\$PSScriptRoot/Invoke-GraphQL\.ps1')
Test-Assert -TestName "Script calls Get-RepoContext.ps1" -Condition ($scriptContent -match '\$PSScriptRoot/Get-RepoContext\.ps1')
Test-Assert -TestName "Script calls Write-OkyeremaLog.ps1" -Condition ($scriptContent -match 'Write-OkyeremaLog\.ps1')

# Test: Script has proper error handling
Test-Assert -TestName "Script sets ErrorActionPreference" -Condition ($scriptContent -match '\$ErrorActionPreference\s*=\s*"Stop"')
Test-Assert -TestName "Script checks for null PR" -Condition ($scriptContent -match 'if\s*\(\s*-not\s+\$pr\s*\)')

# Test: Script generates correlation ID
Test-Assert -TestName "Script generates correlation ID if not provided" -Condition ($scriptContent -match 'if\s*\(\s*-not\s+\$CorrelationId\s*\)' -and $scriptContent -match '\[guid\]::NewGuid')

# Test: Script logs operations
Test-Assert -TestName "Script logs start of operation" -Condition ($scriptContent -match 'Starting PR status check')
Test-Assert -TestName "Script logs success" -Condition ($scriptContent -match 'PR status retrieved successfully')

Write-Host ""

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
