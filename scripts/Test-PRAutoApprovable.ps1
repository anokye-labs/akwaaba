<#
.SYNOPSIS
    Test if a PR meets auto-approval criteria for agent PRs.

.DESCRIPTION
    Test-PRAutoApprovable.ps1 determines if a PR meets auto-approval criteria
    for agent-created PRs. It checks multiple conditions based on rules stored
    in .github/okyerema/auto-approve.json.
    
    Default checks include:
    - CI passing: All CI checks must pass
    - No unresolved comments: No unresolved review threads
    - Linked issue: PR must link to at least one issue
    - Commit conventions: Commits follow conventional commit format
    - No secrets in diff: No secrets detected in the diff
    - Expected scope: Changes are within expected file patterns
    - No protected path changes: No changes to protected files
    
    Returns a structured result object with:
    - autoApprovable: boolean indicating if PR can be auto-approved
    - reasons: array of reasons why PR is auto-approvable (passed checks)
    - failedChecks: array of failed checks preventing auto-approval

.PARAMETER PRNumber
    The pull request number to check.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER ConfigPath
    Path to the auto-approve configuration JSON file.
    Default: .github/okyerema/auto-approve.json

.PARAMETER OutputFormat
    Output format for the result. Valid values: Console, Markdown, Json.
    Default is Console.

.PARAMETER DryRun
    If specified, shows what would be checked without making actual API calls.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    ./Test-PRAutoApprovable.ps1 -PRNumber 42

.EXAMPLE
    ./Test-PRAutoApprovable.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba -OutputFormat Json

.EXAMPLE
    ./Test-PRAutoApprovable.ps1 -PRNumber 42 -ConfigPath custom-rules.json

.OUTPUTS
    Returns a PSCustomObject with:
    - autoApprovable: bool
    - reasons: array of passed checks
    - failedChecks: array of failed checks with details

.NOTES
    Author: Anokye Labs
    Dependencies: Get-PRStatus.ps1, Get-PRCommentAnalysis.ps1, Invoke-GraphQL.ps1, Get-RepoContext.ps1
    Key script for agent PR workflow.
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
    [string]$ConfigPath = ".github/okyerema/auto-approve.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
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

# Helper function to call Get-RepoContext.ps1
function Get-RepoContextHelper {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Refresh
    )
    
    $params = @{}
    
    if ($Refresh) {
        $params.Refresh = $true
    }
    
    # Call Get-RepoContext.ps1 as a script
    & "$PSScriptRoot/Get-RepoContext.ps1" @params
}

# Helper function to call Get-PRStatus.ps1
function Get-PRStatusHelper {
    param(
        [Parameter(Mandatory = $true)]
        [int]$PRNumber,
        
        [Parameter(Mandatory = $false)]
        [string]$Owner,
        
        [Parameter(Mandatory = $false)]
        [string]$Repo,
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $params = @{
        PRNumber = $PRNumber
        OutputFormat = "Json"
    }
    
    if ($Owner) { $params.Owner = $Owner }
    if ($Repo) { $params.Repo = $Repo }
    if ($CorrelationId) { $params.CorrelationId = $CorrelationId }
    if ($DryRun) { $params.DryRun = $true }
    
    $jsonResult = & "$PSScriptRoot/Get-PRStatus.ps1" @params
    
    if ($DryRun) {
        return $null
    }
    
    return $jsonResult | ConvertFrom-Json
}

# Helper function to call Get-PRCommentAnalysis.ps1
function Get-PRCommentAnalysisHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        
        [Parameter(Mandatory = $true)]
        [string]$Repo,
        
        [Parameter(Mandatory = $true)]
        [int]$PullNumber
    )
    
    $params = @{
        Owner = $Owner
        Repo = $Repo
        PullNumber = $PullNumber
        OutputFormat = "Json"
    }
    
    $jsonResult = & "$PSScriptRoot/Get-PRCommentAnalysis.ps1" @params
    return $jsonResult | ConvertFrom-Json
}

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Variables = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )
    
    $params = @{
        Query = $Query
    }
    
    if ($Variables.Count -gt 0) {
        $params.Variables = $Variables
    }
    
    if ($CorrelationId) {
        $params.CorrelationId = $CorrelationId
    }

    if ($DryRun) {
        $params.DryRun = $true
    }
    
    # Call Invoke-GraphQL.ps1 as a script
    & "$PSScriptRoot/Invoke-GraphQL.ps1" @params
}

#endregion

#region Load Configuration

# Resolve config path
$configFullPath = if ([System.IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath
} else {
    # Get repo root
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        $repoRoot = $PSScriptRoot | Split-Path -Parent
    }
    Join-Path $repoRoot $ConfigPath
}

if (-not (Test-Path $configFullPath)) {
    Write-Error "Configuration file not found: $configFullPath"
    exit 1
}

try {
    $config = Get-Content $configFullPath -Raw | ConvertFrom-Json
    $rules = $config.rules
}
catch {
    Write-Error "Failed to load configuration from $configFullPath : $_"
    exit 1
}

#endregion

#region Get Repository Context

if (-not $Owner -or -not $Repo) {
    $repoContext = Get-RepoContextHelper
    if (-not $Owner) { $Owner = $repoContext.Owner }
    if (-not $Repo) { $Repo = $repoContext.Repo }
}

#endregion

#region Collect PR Data

# Get PR status (includes merge status, reviews, checks, linked issues, threads)
$prStatus = Get-PRStatusHelper -PRNumber $PRNumber -Owner $Owner -Repo $Repo -CorrelationId $CorrelationId -DryRun:$DryRun

if ($DryRun) {
    Write-Host "DRY RUN: Would check PR #$PRNumber for auto-approval criteria" -ForegroundColor Yellow
    Write-Host "  Owner: $Owner" -ForegroundColor Gray
    Write-Host "  Repo: $Repo" -ForegroundColor Gray
    Write-Host "  Config: $configFullPath" -ForegroundColor Gray
    return
}

# Get comment analysis (includes categorized comments and unresolved threads)
$commentAnalysis = Get-PRCommentAnalysisHelper -Owner $Owner -Repo $Repo -PullNumber $PRNumber

# Get PR commits for commit message validation
$commitsQuery = @"
query(`$owner: String!, `$repo: String!, `$prNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$prNumber) {
      commits(first: 100) {
        nodes {
          commit {
            message
            oid
          }
        }
      }
    }
  }
}
"@

$commitsResult = Invoke-GraphQLHelper -Query $commitsQuery -Variables @{
    owner = $Owner
    repo = $Repo
    prNumber = $PRNumber
} -CorrelationId $CorrelationId

$commits = $commitsResult.Data.repository.pullRequest.commits.nodes

# Get PR file changes for scope and protected path validation
$filesQuery = @"
query(`$owner: String!, `$repo: String!, `$prNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$prNumber) {
      files(first: 100) {
        nodes {
          path
          additions
          deletions
        }
      }
    }
  }
}
"@

$filesResult = Invoke-GraphQLHelper -Query $filesQuery -Variables @{
    owner = $Owner
    repo = $Repo
    prNumber = $PRNumber
} -CorrelationId $CorrelationId

$files = $filesResult.Data.repository.pullRequest.files.nodes

# Get PR diff for secret detection
$diffQuery = @"
query(`$owner: String!, `$repo: String!, `$prNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$prNumber) {
      headRefOid
      baseRefOid
    }
  }
}
"@

$diffResult = Invoke-GraphQLHelper -Query $diffQuery -Variables @{
    owner = $Owner
    repo = $Repo
    prNumber = $PRNumber
} -CorrelationId $CorrelationId

# Use git diff to get the actual diff content
# Note: This requires the repository to be cloned locally
$headOid = $diffResult.Data.repository.pullRequest.headRefOid
$baseOid = $diffResult.Data.repository.pullRequest.baseRefOid

# Try to get diff if we're in a git repository
$diff = ""
$repoRoot = git rev-parse --show-toplevel 2>$null
if ($repoRoot) {
    try {
        # Fetch the refs if needed
        git fetch origin $headOid 2>$null
        git fetch origin $baseOid 2>$null
        
        # Get the diff
        $diff = git diff "$baseOid..$headOid" 2>$null
    }
    catch {
        Write-Warning "Could not fetch diff locally: $_"
    }
}

#endregion

#region Run Checks

$reasons = @()
$failedChecks = @()

# Check 1: CI Must Pass
if ($rules.ciMustPass.enabled) {
    $checksState = $prStatus.MergeStatus.ChecksState
    $checksCount = $prStatus.MergeStatus.ChecksCount
    
    if ($checksState -eq "SUCCESS") {
        $reasons += "CI checks passing ($checksCount checks)"
    }
    elseif ($checksCount -eq 0) {
        $reasons += "No CI checks configured (treated as pass)"
    }
    else {
        $failedChecks += [PSCustomObject]@{
            Rule = "ciMustPass"
            Description = $rules.ciMustPass.description
            Reason = "CI checks state: $checksState ($checksCount checks)"
        }
    }
}

# Check 2: No Unresolved Comments
if ($rules.noUnresolvedComments.enabled) {
    $unresolvedCount = $prStatus.ThreadStatus.Unresolved
    
    if ($unresolvedCount -eq 0) {
        $reasons += "No unresolved review comments"
    }
    else {
        # Check if there are blocking comments
        $blockingCount = $commentAnalysis.Summary.blocking
        
        if ($blockingCount -gt 0) {
            $failedChecks += [PSCustomObject]@{
                Rule = "noUnresolvedComments"
                Description = $rules.noUnresolvedComments.description
                Reason = "$unresolvedCount unresolved thread(s) including $blockingCount blocking comment(s)"
            }
        }
        else {
            $failedChecks += [PSCustomObject]@{
                Rule = "noUnresolvedComments"
                Description = $rules.noUnresolvedComments.description
                Reason = "$unresolvedCount unresolved thread(s)"
            }
        }
    }
}

# Check 3: Linked Issue Required
if ($rules.linkedIssueRequired.enabled) {
    $linkedIssuesCount = $prStatus.LinkedIssues.Count
    
    if ($linkedIssuesCount -gt 0) {
        $issueNumbers = ($prStatus.LinkedIssues | ForEach-Object { "#$($_.Number)" }) -join ", "
        $reasons += "Linked to issue(s): $issueNumbers"
    }
    else {
        $failedChecks += [PSCustomObject]@{
            Rule = "linkedIssueRequired"
            Description = $rules.linkedIssueRequired.description
            Reason = "No linked issues found"
        }
    }
}

# Check 4: Commit Conventions
if ($rules.commitConventions.enabled) {
    $pattern = $rules.commitConventions.pattern
    $invalidCommits = @()
    
    foreach ($commitNode in $commits) {
        $commitMessage = $commitNode.commit.message
        $firstLine = ($commitMessage -split "`n")[0]
        
        if ($firstLine -cnotmatch $pattern) {
            $invalidCommits += [PSCustomObject]@{
                Oid = $commitNode.commit.oid.Substring(0, 7)
                Message = $firstLine
            }
        }
    }
    
    if ($invalidCommits.Count -eq 0) {
        $reasons += "All $($commits.Count) commit(s) follow conventional commit format"
    }
    else {
        $exampleMessages = ($invalidCommits | Select-Object -First 3 | ForEach-Object { "$($_.Oid): $($_.Message)" }) -join "; "
        $failedChecks += [PSCustomObject]@{
            Rule = "commitConventions"
            Description = $rules.commitConventions.description
            Reason = "$($invalidCommits.Count) commit(s) don't follow conventions. Examples: $exampleMessages"
        }
    }
}

# Check 5: No Secrets in Diff
if ($rules.noSecretsInDiff.enabled -and $diff) {
    $secretPatterns = $rules.noSecretsInDiff.patterns
    $foundSecrets = @()
    
    foreach ($pattern in $secretPatterns) {
        $matches = [regex]::Matches($diff, $pattern)
        if ($matches.Count -gt 0) {
            foreach ($match in $matches) {
                # Get the line containing the match
                $lines = $diff -split "`n"
                $matchingLine = $lines | Where-Object { $_ -match [regex]::Escape($match.Value) } | Select-Object -First 1
                
                $foundSecrets += [PSCustomObject]@{
                    Pattern = $pattern
                    Match = $match.Value.Substring(0, [Math]::Min(50, $match.Value.Length)) + "..."
                    Line = $matchingLine.Substring(0, [Math]::Min(100, $matchingLine.Length))
                }
            }
        }
    }
    
    if ($foundSecrets.Count -eq 0) {
        $reasons += "No secrets detected in diff"
    }
    else {
        $secretExamples = ($foundSecrets | Select-Object -First 2 | ForEach-Object { $_.Match }) -join "; "
        $failedChecks += [PSCustomObject]@{
            Rule = "noSecretsInDiff"
            Description = $rules.noSecretsInDiff.description
            Reason = "$($foundSecrets.Count) potential secret(s) detected. Examples: $secretExamples"
        }
    }
}
elseif ($rules.noSecretsInDiff.enabled -and -not $diff) {
    # If we couldn't get the diff, treat it as a warning but don't fail
    $reasons += "No secrets detected (diff not available for validation)"
}

# Check 6: Expected Scope
if ($rules.expectedScope.enabled) {
    $allowedPatterns = $rules.expectedScope.allowedPatterns
    $outOfScopeFiles = @()
    
    foreach ($file in $files) {
        $matchesPattern = $false
        foreach ($pattern in $allowedPatterns) {
            if ($file.path -match $pattern) {
                $matchesPattern = $true
                break
            }
        }
        
        if (-not $matchesPattern) {
            $outOfScopeFiles += $file.path
        }
    }
    
    if ($outOfScopeFiles.Count -eq 0) {
        $reasons += "All $($files.Count) file(s) within expected scope"
    }
    else {
        $examples = ($outOfScopeFiles | Select-Object -First 3) -join ", "
        $failedChecks += [PSCustomObject]@{
            Rule = "expectedScope"
            Description = $rules.expectedScope.description
            Reason = "$($outOfScopeFiles.Count) file(s) outside expected scope. Examples: $examples"
        }
    }
}

# Check 7: No Protected Path Changes
if ($rules.noProtectedPathChanges.enabled) {
    $protectedPaths = $rules.noProtectedPathChanges.protectedPaths
    $protectedFilesChanged = @()
    
    foreach ($file in $files) {
        foreach ($protectedPath in $protectedPaths) {
            if ($file.path -eq $protectedPath -or $file.path -match [regex]::Escape($protectedPath)) {
                $protectedFilesChanged += $file.path
            }
        }
    }
    
    if ($protectedFilesChanged.Count -eq 0) {
        $reasons += "No protected paths modified"
    }
    else {
        $examples = $protectedFilesChanged -join ", "
        $failedChecks += [PSCustomObject]@{
            Rule = "noProtectedPathChanges"
            Description = $rules.noProtectedPathChanges.description
            Reason = "$($protectedFilesChanged.Count) protected file(s) modified: $examples"
        }
    }
}

#endregion

#region Build Result

$autoApprovable = $failedChecks.Count -eq 0

$result = [PSCustomObject]@{
    PRNumber = $PRNumber
    Owner = $Owner
    Repo = $Repo
    AutoApprovable = $autoApprovable
    Reasons = $reasons
    FailedChecks = $failedChecks
    Summary = [PSCustomObject]@{
        TotalChecks = $reasons.Count + $failedChecks.Count
        PassedChecks = $reasons.Count
        FailedChecks = $failedChecks.Count
    }
}

#endregion

#region Output Formatting

switch ($OutputFormat) {
    "Json" {
        return $result | ConvertTo-Json -Depth 10
    }
    
    "Markdown" {
        $markdown = @"
# Auto-Approval Check for PR #$PRNumber

**Repository:** $Owner/$Repo  
**Result:** $(if ($autoApprovable) { "✅ **AUTO-APPROVABLE**" } else { "❌ **NOT AUTO-APPROVABLE**" })

## Summary

- **Total Checks:** $($result.Summary.TotalChecks)
- **Passed:** $($result.Summary.PassedChecks)
- **Failed:** $($result.Summary.FailedChecks)

"@

        if ($reasons.Count -gt 0) {
            $markdown += @"
## ✅ Passed Checks

"@
            foreach ($reason in $reasons) {
                $markdown += "- $reason`n"
            }
            $markdown += "`n"
        }

        if ($failedChecks.Count -gt 0) {
            $markdown += @"
## ❌ Failed Checks

"@
            foreach ($check in $failedChecks) {
                $markdown += @"
### $($check.Rule)
- **Description:** $($check.Description)
- **Reason:** $($check.Reason)

"@
            }
        }

        return $markdown
    }
    
    "Console" {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Auto-Approval Check for PR #$PRNumber" -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Repository: " -NoNewline -ForegroundColor Gray
        Write-Host "$Owner/$Repo" -ForegroundColor White
        Write-Host ""
        
        if ($autoApprovable) {
            Write-Host "✅ RESULT: " -NoNewline -ForegroundColor Green
            Write-Host "AUTO-APPROVABLE" -ForegroundColor Green -BackgroundColor DarkGreen
        }
        else {
            Write-Host "❌ RESULT: " -NoNewline -ForegroundColor Red
            Write-Host "NOT AUTO-APPROVABLE" -ForegroundColor Red -BackgroundColor DarkRed
        }
        Write-Host ""
        
        Write-Host "📊 SUMMARY" -ForegroundColor Cyan
        Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Total Checks: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.TotalChecks -ForegroundColor White
        Write-Host "  Passed: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.PassedChecks -ForegroundColor Green
        Write-Host "  Failed: " -NoNewline -ForegroundColor Gray
        Write-Host $result.Summary.FailedChecks -ForegroundColor $(if ($result.Summary.FailedChecks -gt 0) { "Red" } else { "Gray" })
        Write-Host ""
        
        if ($reasons.Count -gt 0) {
            Write-Host "✅ PASSED CHECKS" -ForegroundColor Green
            Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            foreach ($reason in $reasons) {
                Write-Host "  ✓ " -NoNewline -ForegroundColor Green
                Write-Host $reason -ForegroundColor White
            }
            Write-Host ""
        }
        
        if ($failedChecks.Count -gt 0) {
            Write-Host "❌ FAILED CHECKS" -ForegroundColor Red
            Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            foreach ($check in $failedChecks) {
                Write-Host "  ✗ " -NoNewline -ForegroundColor Red
                Write-Host $check.Rule -ForegroundColor Yellow
                Write-Host "    Description: " -NoNewline -ForegroundColor DarkGray
                Write-Host $check.Description -ForegroundColor White
                Write-Host "    Reason: " -NoNewline -ForegroundColor DarkGray
                Write-Host $check.Reason -ForegroundColor Red
                Write-Host ""
            }
        }
        
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        return $result
    }
}

#endregion
