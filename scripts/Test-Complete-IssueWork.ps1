<#
.SYNOPSIS
    Test script for Complete-IssueWork.ps1

.DESCRIPTION
    Tests the Complete-IssueWork.ps1 script with various scenarios including:
    - DryRun mode validation
    - Branch name validation
    - Parameter validation
    - Error handling

.EXAMPLE
    .\Test-Complete-IssueWork.ps1

.NOTES
    This is a mock test that validates the script structure and DryRun mode.
    Full integration testing requires a real Git repository with branches and issues.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Get script paths
$scriptRoot = $PSScriptRoot
$scriptPath = Join-Path $scriptRoot "Complete-IssueWork.ps1"

if (-not (Test-Path $scriptPath)) {
    throw "Complete-IssueWork.ps1 not found at: $scriptPath"
}

# Test counters
$testsPassed = 0
$testsFailed = 0
$testsTotal = 0

function Test-Assertion {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$ErrorMessage = "Test failed"
    )
    
    $script:testsTotal++
    
    if ($Condition) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:testsPassed++
    }
    else {
        Write-Host "✗ FAIL: $TestName - $ErrorMessage" -ForegroundColor Red
        $script:testsFailed++
    }
}

Write-Host "`n=== Testing Complete-IssueWork.ps1 ===" -ForegroundColor Cyan
Write-Host ""

#region Test 1: Script file exists and is readable
Write-Host "Test 1: Script file validation" -ForegroundColor Yellow

try {
    $scriptContent = Get-Content -Path $scriptPath -Raw
    Test-Assertion -TestName "Script file exists and is readable" -Condition ($null -ne $scriptContent)
}
catch {
    Test-Assertion -TestName "Script file exists and is readable" -Condition $false -ErrorMessage $_.Exception.Message
}

#endregion

#region Test 2: Script has proper structure
Write-Host "`nTest 2: Script structure validation" -ForegroundColor Yellow

$hasParamBlock = $scriptContent -match '\[CmdletBinding\(\)\]'
Test-Assertion -TestName "Script has CmdletBinding attribute" -Condition $hasParamBlock

$hasIssueNumberParam = $scriptContent -match '\[Parameter\(Mandatory = \$true.*\]\s+\[int\]\$IssueNumber'
Test-Assertion -TestName "Script has mandatory IssueNumber parameter" -Condition $hasIssueNumberParam

$hasDryRunParam = $scriptContent -match '\[switch\]\$DryRun'
Test-Assertion -TestName "Script has DryRun parameter" -Condition $hasDryRunParam

$hasCorrelationId = $scriptContent -match '\$CorrelationId'
Test-Assertion -TestName "Script uses correlation ID for tracing" -Condition $hasCorrelationId

$hasErrorActionPreference = $scriptContent -match '\$ErrorActionPreference = "Stop"'
Test-Assertion -TestName "Script sets ErrorActionPreference to Stop" -Condition $hasErrorActionPreference

#endregion

#region Test 3: Script has required dependencies
Write-Host "`nTest 3: Dependency validation" -ForegroundColor Yellow

$checksInvokeGraphQL = $scriptContent -match 'Invoke-GraphQL'
Test-Assertion -TestName "Script uses Invoke-GraphQL.ps1" -Condition $checksInvokeGraphQL

$checksRepoContext = $scriptContent -match 'Get-RepoContext'
Test-Assertion -TestName "Script uses Get-RepoContext.ps1" -Condition $checksRepoContext

$checksLogging = $scriptContent -match 'Write-OkyeremaLog'
Test-Assertion -TestName "Script uses Write-OkyeremaLog.ps1" -Condition $checksLogging

#endregion

#region Test 4: Script implements required functionality
Write-Host "`nTest 4: Functionality validation" -ForegroundColor Yellow

$checksBranch = $scriptContent -match 'git rev-parse --abbrev-ref HEAD'
Test-Assertion -TestName "Script checks current branch" -Condition $checksBranch

$validatesBranchPattern = $scriptContent -match 'issue-.*-.*pattern'
Test-Assertion -TestName "Script validates branch naming pattern" -Condition $validatesBranchPattern

$createsPR = $scriptContent -match 'gh.*pr create'
Test-Assertion -TestName "Script creates PR using GitHub CLI" -Condition $createsPR

$linksToIssue = $scriptContent -match 'Closes #'
Test-Assertion -TestName "Script links PR to issue with closing keywords" -Condition $linksToIssue

$addsToProject = $scriptContent -match 'addProjectV2ItemById'
Test-Assertion -TestName "Script adds PR to project board" -Condition $addsToProject

$setsStatus = $scriptContent -match 'In Review'
Test-Assertion -TestName "Script sets status to 'In Review'" -Condition $setsStatus

$checksAutoApproval = $scriptContent -match 'Test-PRAutoApprovable'
Test-Assertion -TestName "Script checks for auto-approval" -Condition $checksAutoApproval

$addsLabel = $scriptContent -match 'auto-approval'
Test-Assertion -TestName "Script adds auto-approval label if applicable" -Condition $addsLabel

#endregion

#region Test 5: Error handling
Write-Host "`nTest 5: Error handling validation" -ForegroundColor Yellow

$checksLastExitCode = $scriptContent -match '\$LASTEXITCODE'
Test-Assertion -TestName "Script checks LASTEXITCODE after git/gh commands" -Condition $checksLastExitCode

$logsErrors = $scriptContent -match 'Level Error'
Test-Assertion -TestName "Script logs errors appropriately" -Condition $logsErrors

$throwsOnFailure = $scriptContent -match 'throw'
Test-Assertion -TestName "Script throws exceptions on critical failures" -Condition $throwsOnFailure

#endregion

#region Test 6: DryRun mode validation (mock test)
Write-Host "`nTest 6: DryRun mode behavior" -ForegroundColor Yellow

# This test validates that DryRun mode is implemented
# We cannot actually run it without a proper Git environment

$handlesDryRun = $scriptContent -match 'if \(\$DryRun\)'
Test-Assertion -TestName "Script has DryRun mode implementation" -Condition $handlesDryRun

$returnsDryRunResult = $scriptContent -match 'DryRun = \$true'
Test-Assertion -TestName "Script returns DryRun flag in result" -Condition $returnsDryRunResult

#endregion

#region Test 7: Output structure validation
Write-Host "`nTest 7: Output structure validation" -ForegroundColor Yellow

$returnsSuccess = $scriptContent -match 'Success ='
Test-Assertion -TestName "Script returns Success field" -Condition $returnsSuccess

$returnsPRNumber = $scriptContent -match 'PRNumber ='
Test-Assertion -TestName "Script returns PRNumber field" -Condition $returnsPRNumber

$returnsPRURL = $scriptContent -match 'PRURL ='
Test-Assertion -TestName "Script returns PRURL field" -Condition $returnsPRURL

$returnsAutoApprovable = $scriptContent -match 'IsAutoApprovable ='
Test-Assertion -TestName "Script returns IsAutoApprovable field" -Condition $returnsAutoApprovable

$returnsMessage = $scriptContent -match 'Message ='
Test-Assertion -TestName "Script returns Message field" -Condition $returnsMessage

#endregion

#region Test 8: Comment-based help
Write-Host "`nTest 8: Documentation validation" -ForegroundColor Yellow

$hasSynopsis = $scriptContent -match '\.SYNOPSIS'
Test-Assertion -TestName "Script has .SYNOPSIS section" -Condition $hasSynopsis

$hasDescription = $scriptContent -match '\.DESCRIPTION'
Test-Assertion -TestName "Script has .DESCRIPTION section" -Condition $hasDescription

$hasExamples = $scriptContent -match '\.EXAMPLE'
Test-Assertion -TestName "Script has .EXAMPLE section(s)" -Condition $hasExamples

$hasOutputs = $scriptContent -match '\.OUTPUTS'
Test-Assertion -TestName "Script has .OUTPUTS section" -Condition $hasOutputs

$hasNotes = $scriptContent -match '\.NOTES'
Test-Assertion -TestName "Script has .NOTES section" -Condition $hasNotes

#endregion

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $testsTotal" -ForegroundColor White
Write-Host "Passed:      $testsPassed" -ForegroundColor Green
Write-Host "Failed:      $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some tests failed. Please review the output above." -ForegroundColor Red
    exit 1
}
