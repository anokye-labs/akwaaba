<#
.SYNOPSIS
    Validates that all commits in a PR reference an open GitHub issue.

.DESCRIPTION
    Validate-Commits.ps1 checks each commit in a pull request to ensure it references
    at least one open GitHub issue. This enforces the issue-driven development workflow
    where all work must be tracked through GitHub issues.

    The script provides detailed, helpful error messages when validation fails, including:
    - List of commits that fail validation
    - Expected format examples
    - Actionable fix instructions
    - Links to contribution guidelines

.PARAMETER PRNumber
    The pull request number to validate.

.PARAMETER BaseRef
    The base reference (branch) for the PR. Defaults to 'main'.

.PARAMETER HeadRef
    The head reference (branch) for the PR. If not provided, will be fetched from PR info.

.OUTPUTS
    Returns an object with:
    - Success (bool): Whether all commits passed validation
    - FailedCommits (array): List of commits that failed validation
    - ErrorMessage (string): Detailed error message with actionable instructions

.EXAMPLE
    PS> .\Validate-Commits.ps1 -PRNumber 123
    Validates all commits in PR #123.

.EXAMPLE
    PS> .\Validate-Commits.ps1 -PRNumber 456 -BaseRef main
    Validates commits in PR #456 against the main branch.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Expected commit message formats:
    - #123
    - Closes #123
    - Fixes #123
    - Resolves #123
    - owner/repo#123
    - Full GitHub issue URLs
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [int]$PRNumber,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseRef = "main",
    
    [Parameter(Mandatory=$false)]
    [string]$HeadRef
)

# ANSI color codes for better readability
$script:Red = "`e[31m"
$script:Green = "`e[32m"
$script:Yellow = "`e[33m"
$script:Blue = "`e[34m"
$script:Cyan = "`e[36m"
$script:Bold = "`e[1m"
$script:Reset = "`e[0m"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = $script:Reset
    )
    Write-Host "${Color}${Message}${script:Reset}"
}

function Get-IssueReferences {
    <#
    .SYNOPSIS
        Extracts issue references from a commit message.
    .DESCRIPTION
        Supports multiple formats:
        - #123
        - Closes #123, Fixes #456, Resolves #789
        - owner/repo#123
        - https://github.com/owner/repo/issues/123
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommitMessage
    )
    
    $issueNumbers = [System.Collections.ArrayList]::new()
    
    # Pattern 1: Simple issue reference (#123)
    $simpleMatches = [regex]::Matches($CommitMessage, '#(\d+)')
    foreach ($match in $simpleMatches) {
        [void]$issueNumbers.Add($match.Groups[1].Value)
    }
    
    # Pattern 2: Full GitHub URLs
    $urlMatches = [regex]::Matches($CommitMessage, 'https://github\.com/[^/]+/[^/]+/issues/(\d+)')
    foreach ($match in $urlMatches) {
        [void]$issueNumbers.Add($match.Groups[1].Value)
    }
    
    # Remove duplicates and return as proper array
    # Use comma operator to force array return
    $unique = $issueNumbers | Select-Object -Unique
    return ,($unique -as [array])
}

function Test-IssueExists {
    <#
    .SYNOPSIS
        Checks if a GitHub issue exists and is open.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$IssueNumber
    )
    
    try {
        $issueInfo = gh issue view $IssueNumber --json state,number 2>&1 | ConvertFrom-Json
        
        if ($issueInfo.state -eq "OPEN") {
            return @{
                Exists = $true
                IsOpen = $true
                Number = $issueInfo.number
            }
        }
        else {
            return @{
                Exists = $true
                IsOpen = $false
                Number = $issueInfo.number
                State = $issueInfo.state
            }
        }
    }
    catch {
        return @{
            Exists = $false
            IsOpen = $false
        }
    }
}

function Test-IsSpecialCommit {
    <#
    .SYNOPSIS
        Checks if a commit is a special type that should be exempted from validation.
    .DESCRIPTION
        Exempts merge commits, revert commits, and bot commits from validation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommitMessage,
        
        [Parameter(Mandatory=$false)]
        [string]$CommitAuthor
    )
    
    # Check for merge commits
    if ($CommitMessage -match '^Merge (branch|pull request|remote-tracking branch)') {
        return @{ IsSpecial = $true; Reason = "Merge commit" }
    }
    
    # Check for revert commits
    if ($CommitMessage -match '^Revert ') {
        return @{ IsSpecial = $true; Reason = "Revert commit" }
    }
    
    # Check for bot commits (author ends with [bot])
    if ($CommitAuthor -match '\[bot\]$') {
        return @{ IsSpecial = $true; Reason = "Bot commit" }
    }
    
    return @{ IsSpecial = $false }
}

function Format-ErrorMessage {
    <#
    .SYNOPSIS
        Formats a detailed, helpful error message for failed validation.
    .DESCRIPTION
        Creates a comprehensive error message that includes:
        - List of failing commits
        - Expected format examples
        - Actionable fix instructions
        - Links to contribution guidelines
    #>
    param(
        [Parameter(Mandatory=$true)]
        [array]$FailedCommits,
        
        [Parameter(Mandatory=$true)]
        [int]$PRNumber
    )
    
    $message = @"
${script:Red}${script:Bold}❌ Commit Validation Failed${script:Reset}

${script:Bold}The following commits do not reference an open GitHub issue:${script:Reset}

"@
    
    foreach ($commit in $FailedCommits) {
        $shortSha = $commit.Sha.Substring(0, 7)
        $message += "${script:Red}  • ${shortSha}${script:Reset} - ${commit.Message}`n"
        
        if ($commit.Reason) {
            $message += "    ${script:Yellow}Reason: ${commit.Reason}${script:Reset}`n"
        }
    }
    
    $message += @"

${script:Bold}${script:Cyan}📋 Expected Commit Message Format:${script:Reset}

All commits must reference at least one open GitHub issue. Here are valid formats:

  ${script:Green}✓${script:Reset} ${script:Bold}Simple reference:${script:Reset}
    feat: Add user authentication ${script:Green}#123${script:Reset}

  ${script:Green}✓${script:Reset} ${script:Bold}Closing keywords:${script:Reset}
    fix: Resolve login bug ${script:Green}Closes #456${script:Reset}
    fix: Address timeout issue ${script:Green}Fixes #789${script:Reset}
    feat: Implement feature ${script:Green}Resolves #101${script:Reset}

  ${script:Green}✓${script:Reset} ${script:Bold}Cross-repository reference:${script:Reset}
    docs: Update guide ${script:Green}owner/repo#123${script:Reset}

  ${script:Green}✓${script:Reset} ${script:Bold}Full URL reference:${script:Reset}
    feat: New feature ${script:Green}https://github.com/owner/repo/issues/123${script:Reset}

  ${script:Green}✓${script:Reset} ${script:Bold}Multiple issues:${script:Reset}
    feat: Implement changes ${script:Green}#123 #456${script:Reset}

${script:Bold}${script:Cyan}🔧 How to Fix:${script:Reset}

${script:Bold}Option 1: Amend the most recent commit${script:Reset}
  git commit --amend -m "your commit message ${script:Green}#123${script:Reset}"
  git push --force

${script:Bold}Option 2: Interactive rebase (for multiple commits)${script:Reset}
  git rebase -i HEAD~N  ${script:Yellow}# where N is the number of commits${script:Reset}
  ${script:Yellow}# Mark commits with 'reword' to edit their messages${script:Reset}
  git push --force

${script:Bold}Option 3: Create a new issue for this work${script:Reset}
  1. Create a GitHub issue describing this work
  2. Amend your commit(s) to reference the new issue
  3. Push the updated commits

${script:Bold}${script:Cyan}📚 Learn More:${script:Reset}

• Contribution Guidelines: https://github.com/anokye-labs/akwaaba/blob/main/CONTRIBUTING.md
• How We Work: https://github.com/anokye-labs/akwaaba/blob/main/how-we-work.md
• Issue-First Workflow: All work must begin with a GitHub issue

${script:Bold}${script:Cyan}💡 Why We Do This:${script:Reset}

The issue-first workflow ensures:
  • All changes are tracked and documented
  • Work is coordinated through a single source of truth
  • The "why" behind every commit is clear and searchable
  • Agents and humans can collaborate effectively

${script:Yellow}Note: Merge commits, revert commits, and bot commits are automatically exempted.${script:Reset}

"@
    
    return $message
}

# Main validation logic
Write-ColorOutput "🔍 Validating commits in PR #${PRNumber}..." $script:Cyan

# Get PR information
try {
    $prInfo = gh pr view $PRNumber --json headRefName,baseRefName,commits | ConvertFrom-Json
    
    if (-not $HeadRef) {
        $HeadRef = $prInfo.headRefName
    }
    
    if (-not $BaseRef) {
        $BaseRef = $prInfo.baseRefName
    }
    
    $commits = $prInfo.commits
}
catch {
    Write-ColorOutput "❌ Failed to fetch PR information: $_" $script:Red
    exit 1
}

Write-ColorOutput "  Base: $BaseRef" $script:Blue
Write-ColorOutput "  Head: $HeadRef" $script:Blue
Write-ColorOutput "  Total commits: $($commits.Count)" $script:Blue
Write-Host ""

# Validate each commit
$failedCommits = @()
$validatedCount = 0
$skippedCount = 0

foreach ($commit in $commits) {
    $sha = $commit.oid
    $message = $commit.messageHeadline + "`n" + $commit.messageBody
    $author = $commit.authors[0].name
    
    $shortSha = $sha.Substring(0, 7)
    
    # Check if this is a special commit type
    $specialCheck = Test-IsSpecialCommit -CommitMessage $message -CommitAuthor $author
    
    if ($specialCheck.IsSpecial) {
        Write-ColorOutput "  ⊘ $shortSha - ${$specialCheck.Reason} (skipped)" $script:Yellow
        $skippedCount++
        continue
    }
    
    # Extract issue references
    $issueRefs = Get-IssueReferences -CommitMessage $message
    
    if ($issueRefs.Count -eq 0) {
        Write-ColorOutput "  ✗ $shortSha - No issue reference found" $script:Red
        $failedCommits += @{
            Sha = $sha
            Message = $commit.messageHeadline
            Reason = "No issue reference found in commit message"
        }
        continue
    }
    
    # Validate that at least one referenced issue exists and is open
    $hasValidIssue = $false
    $closedIssues = @()
    $missingIssues = @()
    
    foreach ($issueNum in $issueRefs) {
        $issueCheck = Test-IssueExists -IssueNumber $issueNum
        
        if ($issueCheck.Exists -and $issueCheck.IsOpen) {
            $hasValidIssue = $true
            break
        }
        elseif ($issueCheck.Exists -and -not $issueCheck.IsOpen) {
            $closedIssues += $issueNum
        }
        else {
            $missingIssues += $issueNum
        }
    }
    
    if ($hasValidIssue) {
        Write-ColorOutput "  ✓ $shortSha - Valid issue reference(s): $(($issueRefs | ForEach-Object { "#$_" }) -join ', ')" $script:Green
        $validatedCount++
    }
    else {
        $reasons = @()
        if ($closedIssues.Count -gt 0) {
            $reasons += "Issue(s) $(($closedIssues | ForEach-Object { "#$_" }) -join ', ') are closed"
        }
        if ($missingIssues.Count -gt 0) {
            $reasons += "Issue(s) $(($missingIssues | ForEach-Object { "#$_" }) -join ', ') do not exist"
        }
        
        $reason = $reasons -join "; "
        Write-ColorOutput "  ✗ $shortSha - $reason" $script:Red
        
        $failedCommits += @{
            Sha = $sha
            Message = $commit.messageHeadline
            Reason = $reason
        }
    }
}

Write-Host ""

# Summary
if ($failedCommits.Count -eq 0) {
    Write-ColorOutput "✅ ${script:Bold}All commits passed validation!${script:Reset}" $script:Green
    Write-ColorOutput "   Validated: $validatedCount" $script:Green
    Write-ColorOutput "   Skipped: $skippedCount" $script:Yellow
    
    # Return success result
    return @{
        Success = $true
        FailedCommits = @()
        ValidatedCount = $validatedCount
        SkippedCount = $skippedCount
    }
}
else {
    # Generate detailed error message
    $errorMessage = Format-ErrorMessage -FailedCommits $failedCommits -PRNumber $PRNumber
    
    Write-Host $errorMessage
    
    Write-ColorOutput "Summary:" $script:Bold
    Write-ColorOutput "  Failed: $($failedCommits.Count)" $script:Red
    Write-ColorOutput "  Validated: $validatedCount" $script:Green
    Write-ColorOutput "  Skipped: $skippedCount" $script:Yellow
    
    # Return failure result
    return @{
        Success = $false
        FailedCommits = $failedCommits
        ValidatedCount = $validatedCount
        SkippedCount = $skippedCount
        ErrorMessage = $errorMessage
    }
}
