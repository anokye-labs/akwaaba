<#
.SYNOPSIS
    Tests for Validate-Commits.ps1

.DESCRIPTION
    Unit and integration tests for the Validate-Commits.ps1 script.
    Tests include commit message validation patterns, issue reference detection,
    and special commit handling.

.NOTES
    Author: Anokye Labs
    This test file uses local function definitions to avoid executing the main script.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test-Validate-Commits.ps1" -ForegroundColor White
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

# Copy the validation function from Validate-Commits.ps1 for testing
function Test-CommitMessageForIssueReference {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommitMessage,
        
        [Parameter(Mandatory = $true)]
        [string]$CommitSha
    )
    
    # Special case: Revert commits are allowed without issue references
    if ($CommitMessage -match "^Revert\s+") {
        return @{
            Valid = $true
            Reason = "Revert commit"
            IssueReferences = @()
        }
    }
    
    # Pattern to match issue references:
    # - #123
    # - Closes #123, Fixes #123, Resolves #123
    # - Issue #123
    # - GH-123
    $issuePattern = '(?:#|GH-)(\d+)|(?:Closes?|Fixes?|Resolves?)\s+#(\d+)|Issue\s+#(\d+)'
    
    $matches = [regex]::Matches($CommitMessage, $issuePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    
    if ($matches.Count -gt 0) {
        $issueNumbers = @()
        foreach ($match in $matches) {
            # Extract the issue number from whichever capture group matched
            for ($i = 1; $i -lt $match.Groups.Count; $i++) {
                if ($match.Groups[$i].Success) {
                    $issueNumbers += $match.Groups[$i].Value
                }
            }
        }
        
        return @{
            Valid = $true
            Reason = "Issue reference found"
            IssueReferences = $issueNumbers | Select-Object -Unique
        }
    }
    
    return @{
        Valid = $false
        Reason = "No issue reference found"
        IssueReferences = @()
    }
}

#region Unit Tests

Write-Host "Unit Tests - Issue Reference Detection" -ForegroundColor Yellow
Write-Host ""

# Test basic issue reference (#123)
$result = Test-CommitMessageForIssueReference -CommitMessage "feat: Add new feature #123" -CommitSha "abc123"
Test-Assert -TestName "Detects basic issue reference (#123)" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "123")

# Test Closes pattern
$result = Test-CommitMessageForIssueReference -CommitMessage "fix: Fix bug Closes #456" -CommitSha "def456"
Test-Assert -TestName "Detects 'Closes #456' pattern" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "456")

# Test Fixes pattern
$result = Test-CommitMessageForIssueReference -CommitMessage "fix: Fixes #789 by updating logic" -CommitSha "ghi789"
Test-Assert -TestName "Detects 'Fixes #789' pattern" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "789")

# Test Resolves pattern
$result = Test-CommitMessageForIssueReference -CommitMessage "chore: Resolves #321" -CommitSha "jkl321"
Test-Assert -TestName "Detects 'Resolves #321' pattern" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "321")

# Test Issue pattern
$result = Test-CommitMessageForIssueReference -CommitMessage "docs: Update docs for Issue #654" -CommitSha "mno654"
Test-Assert -TestName "Detects 'Issue #654' pattern" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "654")

# Test GH- pattern
$result = Test-CommitMessageForIssueReference -CommitMessage "feat: Implement feature GH-987" -CommitSha "pqr987"
Test-Assert -TestName "Detects 'GH-987' pattern" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "987")

# Test multiple issue references
$result = Test-CommitMessageForIssueReference -CommitMessage "feat: Add feature #123 and #456" -CommitSha "stu111"
Test-Assert -TestName "Detects multiple issue references" -Condition ($result.Valid -eq $true -and $result.IssueReferences.Count -eq 2)

# Test no issue reference
$result = Test-CommitMessageForIssueReference -CommitMessage "feat: Add feature without issue" -CommitSha "vwx222"
Test-Assert -TestName "Detects missing issue reference" -Condition ($result.Valid -eq $false)

# Test revert commit (should pass without issue reference)
$result = Test-CommitMessageForIssueReference -CommitMessage "Revert 'feat: Add feature'" -CommitSha "yza333"
Test-Assert -TestName "Allows revert commits without issue reference" -Condition ($result.Valid -eq $true -and $result.Reason -eq "Revert commit")

# Test case insensitivity
$result = Test-CommitMessageForIssueReference -CommitMessage "fix: fixes #999 bug" -CommitSha "bcd444"
Test-Assert -TestName "Pattern matching is case-insensitive" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "999")

# Test issue reference in body (multiline message)
$multilineMessage = @"
feat: Add new authentication

This commit implements new authentication.
Closes #555
"@
$result = Test-CommitMessageForIssueReference -CommitMessage $multilineMessage -CommitSha "efg555"
Test-Assert -TestName "Detects issue reference in commit body" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "555")

# Test edge cases
$result = Test-CommitMessageForIssueReference -CommitMessage "feat: #" -CommitSha "hij666"
Test-Assert -TestName "Rejects incomplete issue reference (#)" -Condition ($result.Valid -eq $false)

$result = Test-CommitMessageForIssueReference -CommitMessage "feat: Closes # 777" -CommitSha "klm777"
Test-Assert -TestName "Rejects malformed issue reference (Closes # 777)" -Condition ($result.Valid -eq $false)

$result = Test-CommitMessageForIssueReference -CommitMessage "feat: Add feature #123abc" -CommitSha "nop888"
Test-Assert -TestName "Detects issue reference with trailing text (#123abc)" -Condition ($result.Valid -eq $true -and $result.IssueReferences -contains "123")

Write-Host ""

#endregion

#region Summary

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Test Summary" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests:  " -NoNewline
Write-Host $script:TestsTotal -ForegroundColor White
Write-Host "Passed:       " -NoNewline
Write-Host $script:TestsPassed -ForegroundColor Green
Write-Host "Failed:       " -NoNewline
Write-Host $script:TestsFailed -ForegroundColor $(if ($script:TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}

#endregion
