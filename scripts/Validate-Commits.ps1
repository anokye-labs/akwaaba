<#
.SYNOPSIS
    Validates commit messages in a pull request reference GitHub issues.

.DESCRIPTION
    Validate-Commits.ps1 fetches all commits in a GitHub Pull Request and validates
    that each commit message contains a reference to a GitHub issue. This ensures
    all work is tracked through the issue-driven development workflow.
    
    The script checks for issue references in the following formats:
    - #123
    - Closes #123
    - Fixes #123
    - Resolves #123
    - Issue #123
    - GH-123
    
    Special commit types are handled appropriately:
    - Merge commits are validated
    - Revert commits are allowed without issue references
    - Co-authored commits are validated

.PARAMETER PRNumber
    The pull request number to validate commits for.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER OutputFormat
    Output format for the validation results. Valid values: Console, Json.
    Default is Console.

.PARAMETER DryRun
    If specified, shows what would be validated without making actual API calls.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42 -OutputFormat Json

.EXAMPLE
    ./Validate-Commits.ps1 -PRNumber 42 -DryRun

.OUTPUTS
    Returns a PSCustomObject with validation results:
    - Success: Boolean indicating if all commits passed validation
    - PRNumber: The PR number that was validated
    - TotalCommits: Total number of commits in the PR
    - ValidCommits: Number of commits that passed validation
    - InvalidCommits: Number of commits that failed validation
    - Results: Array of validation results for each commit
    - CorrelationId: Correlation ID for tracing

.NOTES
    Author: Anokye Labs
    Dependencies: GitHub CLI (gh)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [int]$PRNumber,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Json")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

#region Helper Functions

function Get-RepositoryContext {
    <#
    .SYNOPSIS
        Gets repository owner and name from current git context if not provided.
    #>
    param(
        [string]$Owner,
        [string]$Repo
    )
    
    if (-not $Owner -or -not $Repo) {
        try {
            $repoInfo = gh repo view --json owner,name | ConvertFrom-Json
            if (-not $Owner) {
                $Owner = $repoInfo.owner.login
            }
            if (-not $Repo) {
                $Repo = $repoInfo.name
            }
        }
        catch {
            throw "Failed to detect repository context. Please provide -Owner and -Repo parameters."
        }
    }
    
    return @{
        Owner = $Owner
        Repo = $Repo
    }
}

function Test-CommitMessageForIssueReference {
    <#
    .SYNOPSIS
        Tests if a commit message contains a valid issue reference.
    #>
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

function Get-PRCommits {
    <#
    .SYNOPSIS
        Fetches all commits in a pull request.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [int]$PRNumber,
        
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        
        [Parameter(Mandatory = $true)]
        [string]$Repo
    )
    
    try {
        $repoArg = "$Owner/$Repo"
        $commits = gh pr view $PRNumber --repo $repoArg --json commits | ConvertFrom-Json
        
        return $commits.commits
    }
    catch {
        throw "Failed to fetch commits for PR #${PRNumber}: $($_.Exception.Message)"
    }
}

function Format-ValidationResults {
    <#
    .SYNOPSIS
        Formats validation results based on output format.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Results,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputFormat
    )
    
    if ($OutputFormat -eq "Json") {
        return $Results | ConvertTo-Json -Depth 10
    }
    
    # Console format
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Commit Validation Results - PR #$($Results.PRNumber)" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Total Commits:   " -NoNewline
    Write-Host $Results.TotalCommits -ForegroundColor White
    Write-Host "Valid Commits:   " -NoNewline
    Write-Host $Results.ValidCommits -ForegroundColor Green
    Write-Host "Invalid Commits: " -NoNewline
    Write-Host $Results.InvalidCommits -ForegroundColor $(if ($Results.InvalidCommits -gt 0) { "Red" } else { "Green" })
    Write-Host ""
    
    if ($Results.InvalidCommits -gt 0) {
        Write-Host "Invalid Commits:" -ForegroundColor Red
        Write-Host ""
        foreach ($result in $Results.Results | Where-Object { -not $_.Valid }) {
            Write-Host "  ✗ " -NoNewline -ForegroundColor Red
            Write-Host "$($result.Sha.Substring(0, 7))" -NoNewline -ForegroundColor Yellow
            Write-Host " - $($result.Message)" -ForegroundColor White
            Write-Host "    Reason: $($result.Reason)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    if ($Results.ValidCommits -gt 0) {
        Write-Host "Valid Commits:" -ForegroundColor Green
        Write-Host ""
        foreach ($result in $Results.Results | Where-Object { $_.Valid }) {
            Write-Host "  ✓ " -NoNewline -ForegroundColor Green
            Write-Host "$($result.Sha.Substring(0, 7))" -NoNewline -ForegroundColor Yellow
            Write-Host " - $($result.Message)" -ForegroundColor White
            if ($result.IssueReferences.Count -gt 0) {
                Write-Host "    Issues: $($result.IssueReferences -join ', ')" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }
    
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Results.Success) {
        Write-Host "✓ All commits passed validation" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Validation failed" -ForegroundColor Red
        Write-Host ""
        Write-Host "Commits must reference a GitHub issue using one of these formats:" -ForegroundColor Yellow
        Write-Host "  - #123" -ForegroundColor White
        Write-Host "  - Closes #123" -ForegroundColor White
        Write-Host "  - Fixes #123" -ForegroundColor White
        Write-Host "  - Resolves #123" -ForegroundColor White
        Write-Host "  - Issue #123" -ForegroundColor White
        Write-Host "  - GH-123" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Correlation ID: $($Results.CorrelationId)" -ForegroundColor DarkGray
    Write-Host ""
    
    return $null
}

#endregion

#region Main Logic

# Get repository context
$repoContext = Get-RepositoryContext -Owner $Owner -Repo $Repo
$Owner = $repoContext.Owner
$Repo = $repoContext.Repo

if ($DryRun) {
    Write-Host "DRY RUN: Would validate commits in PR #$PRNumber for $Owner/$Repo" -ForegroundColor Yellow
    Write-Host "Correlation ID: $CorrelationId" -ForegroundColor DarkGray
    exit 0
}

# Fetch commits
Write-Verbose "Fetching commits for PR #$PRNumber..."
$commits = Get-PRCommits -PRNumber $PRNumber -Owner $Owner -Repo $Repo

if (-not $commits -or $commits.Count -eq 0) {
    throw "No commits found in PR #$PRNumber"
}

Write-Verbose "Found $($commits.Count) commit(s) to validate"

# Validate each commit
$validationResults = @()
foreach ($commit in $commits) {
    $commitSha = $commit.oid
    $commitMessage = $commit.messageHeadline
    
    # Get full commit message if available
    if ($commit.messageBody) {
        $fullMessage = "$commitMessage`n$($commit.messageBody)"
    }
    else {
        $fullMessage = $commitMessage
    }
    
    Write-Verbose "Validating commit $($commitSha.Substring(0, 7))..."
    $validation = Test-CommitMessageForIssueReference -CommitMessage $fullMessage -CommitSha $commitSha
    
    $validationResults += [PSCustomObject]@{
        Sha = $commitSha
        Message = $commitMessage
        Valid = $validation.Valid
        Reason = $validation.Reason
        IssueReferences = $validation.IssueReferences
    }
}

# Calculate summary
$totalCommits = $validationResults.Count
$validCommits = ($validationResults | Where-Object { $_.Valid }).Count
$invalidCommits = $totalCommits - $validCommits
$success = $invalidCommits -eq 0

# Build result object
$result = [PSCustomObject]@{
    Success = $success
    PRNumber = $PRNumber
    Owner = $Owner
    Repo = $Repo
    TotalCommits = $totalCommits
    ValidCommits = $validCommits
    InvalidCommits = $invalidCommits
    Results = $validationResults
    CorrelationId = $CorrelationId
}

# Format and output results
Format-ValidationResults -Results $result -OutputFormat $OutputFormat

# Set exit code based on validation success
if (-not $success) {
    exit 1
}

#endregion
