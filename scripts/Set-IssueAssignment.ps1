<#
.SYNOPSIS
    Bulk-assign issues to a user (or @copilot) based on DAG readiness.

.DESCRIPTION
    Set-IssueAssignment.ps1 walks the issue DAG from a root Epic and identifies
    ready tasks (all dependencies met, not assigned), then assigns them to the
    specified user or @copilot. Useful for bootstrapping agent work and for
    ongoing DAG execution.
    
    The script:
    - Walks the DAG from a root Epic using Get-ReadyIssues.ps1
    - Identifies ready tasks (all dependencies met, not assigned)
    - Assigns them to the specified user or @copilot
    - Supports -DryRun to preview assignments without making changes
    - Supports -MaxAssign to limit how many issues to assign at once
    - Uses gh issue edit --add-assignee for assignment
    - Logs all operations via Write-OkyeremaLog

.PARAMETER RootIssue
    The issue number of the root Epic to start traversal from.

.PARAMETER Assignee
    The GitHub username or @copilot to assign issues to.
    Use "@copilot" to assign to the Copilot agent.

.PARAMETER MaxAssign
    Maximum number of issues to assign in this operation.
    Default is unlimited (all ready issues will be assigned).

.PARAMETER DryRun
    If specified, shows which issues would be assigned without making changes.

.PARAMETER Labels
    Optional array of label names to filter issues by. Only issues with ALL specified
    labels will be considered for assignment.

.PARAMETER IssueType
    Optional issue type name to filter by (e.g., "Task", "Bug", "Feature").

.PARAMETER SortBy
    Sort order for selecting issues to assign. Options: "priority" (default), "number", "title".

.OUTPUTS
    Array of PSCustomObject with properties:
    - Number: Issue number
    - Title: Issue title
    - Assigned: Boolean indicating if assignment was successful
    - Error: Error message if assignment failed (null if successful)

.EXAMPLE
    .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot"
    Assigns all ready issues under Epic #14 to @copilot.

.EXAMPLE
    .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "octocat" -MaxAssign 3
    Assigns up to 3 ready issues to user "octocat".

.EXAMPLE
    .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -DryRun
    Shows which issues would be assigned to @copilot without making changes.

.EXAMPLE
    .\Set-IssueAssignment.ps1 -RootIssue 14 -Assignee "@copilot" -Labels @("priority:high") -MaxAssign 5
    Assigns up to 5 high-priority ready issues to @copilot.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Depends on: Get-ReadyIssues.ps1, Invoke-GraphQL.ps1, Get-RepoContext.ps1, Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$RootIssue,

    [Parameter(Mandatory = $true)]
    [string]$Assignee,

    [Parameter(Mandatory = $false)]
    [int]$MaxAssign = 0,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string[]]$Labels = @(),

    [Parameter(Mandatory = $false)]
    [string]$IssueType,

    [Parameter(Mandatory = $false)]
    [ValidateSet("priority", "number", "title")]
    [string]$SortBy = "priority"
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for this operation
$correlationId = [guid]::NewGuid().ToString()

# Helper function to call Write-OkyeremaLog.ps1
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logScript = Join-Path $PSScriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation "Set-IssueAssignment" -CorrelationId $correlationId
    }
}

# Helper function to call Get-ReadyIssues.ps1
function Get-ReadyIssuesHelper {
    param(
        [int]$RootIssue,
        [string[]]$Labels = @(),
        [string]$IssueType,
        [string]$SortBy
    )
    
    $readyScript = Join-Path $PSScriptRoot "Get-ReadyIssues.ps1"
    
    $params = @{
        RootIssue = $RootIssue
        SortBy = $SortBy
    }
    
    if ($Labels.Count -gt 0) {
        $params.Labels = $Labels
    }
    
    if ($IssueType) {
        $params.IssueType = $IssueType
    }
    
    return & $readyScript @params
}

Write-Log "Starting Set-IssueAssignment for root issue #${RootIssue}, assignee: $Assignee"

if ($DryRun) {
    Write-Log "DryRun mode enabled - no assignments will be made" -Level "Info"
    Write-Host "=== DryRun Mode ===" -ForegroundColor Cyan
    Write-Host "No assignments will be made. This is a preview only." -ForegroundColor Cyan
    Write-Host ""
}

# Get ready issues from the DAG
Write-Verbose "Fetching ready issues from root #$RootIssue..."
Write-Log "Fetching ready issues from DAG"

try {
    $readyIssues = Get-ReadyIssuesHelper -RootIssue $RootIssue -Labels $Labels -IssueType $IssueType -SortBy $SortBy
}
catch {
    $errorMsg = "Failed to fetch ready issues: $_"
    Write-Log $errorMsg -Level "Error"
    throw $errorMsg
}

if (-not $readyIssues -or $readyIssues.Count -eq 0) {
    Write-Log "No ready issues found" -Level "Info"
    Write-Host "No ready issues found for assignment." -ForegroundColor Yellow
    return @()
}

Write-Log "Found $($readyIssues.Count) ready issues"
Write-Verbose "Found $($readyIssues.Count) ready issues"

# Apply MaxAssign limit if specified
if ($MaxAssign -gt 0 -and $readyIssues.Count -gt $MaxAssign) {
    Write-Log "Limiting to $MaxAssign issues (found $($readyIssues.Count))" -Level "Info"
    $readyIssues = $readyIssues | Select-Object -First $MaxAssign
}

Write-Host "Issues to assign: $($readyIssues.Count)" -ForegroundColor Green
Write-Host ""

# Assign issues
$results = @()

foreach ($issue in $readyIssues) {
    $issueNumber = $issue.Number
    $issueTitle = $issue.Title
    
    if ($DryRun) {
        Write-Host "[DryRun] Would assign issue #${issueNumber} to $Assignee" -ForegroundColor Cyan
        Write-Host "  Title: $issueTitle" -ForegroundColor Gray
        
        $results += [PSCustomObject]@{
            Number = $issueNumber
            Title = $issueTitle
            Assigned = $false
            Error = $null
            DryRun = $true
        }
        
        continue
    }
    
    Write-Verbose "Assigning issue #${issueNumber} to $Assignee..."
    Write-Log "Assigning issue #${issueNumber} to $Assignee"
    
    try {
        # Use gh issue edit to add assignee
        # The gh CLI supports @copilot as a special assignee value
        $ghOutput = gh issue edit $issueNumber --add-assignee $Assignee 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-Host "✓ Assigned issue #${issueNumber} to $Assignee" -ForegroundColor Green
            Write-Host "  Title: $issueTitle" -ForegroundColor Gray
            Write-Log "Successfully assigned issue #${issueNumber} to $Assignee"
            
            $results += [PSCustomObject]@{
                Number = $issueNumber
                Title = $issueTitle
                Assigned = $true
                Error = $null
                DryRun = $false
            }
        }
        else {
            $errorMsg = ($ghOutput | Out-String).Trim()
            Write-Warning "Failed to assign issue #${issueNumber}: $errorMsg"
            Write-Log "Failed to assign issue #${issueNumber}: $errorMsg" -Level "Error"
            
            $results += [PSCustomObject]@{
                Number = $issueNumber
                Title = $issueTitle
                Assigned = $false
                Error = $errorMsg
                DryRun = $false
            }
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Warning "Exception assigning issue #${issueNumber}: $errorMsg"
        Write-Log "Exception assigning issue #${issueNumber}: $errorMsg" -Level "Error"
        
        $results += [PSCustomObject]@{
            Number = $issueNumber
            Title = $issueTitle
            Assigned = $false
            Error = $errorMsg
            DryRun = $false
        }
    }
}

# Summary
Write-Host ""
Write-Host "=== Assignment Summary ===" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "DryRun completed. $($results.Count) issues would be assigned." -ForegroundColor Cyan
}
else {
    $successCount = ($results | Where-Object { $_.Assigned }).Count
    $failureCount = ($results | Where-Object { -not $_.Assigned }).Count
    
    Write-Host "Successfully assigned: $successCount" -ForegroundColor Green
    
    if ($failureCount -gt 0) {
        Write-Host "Failed assignments: $failureCount" -ForegroundColor Red
    }
    
    Write-Log "Assignment completed: $successCount succeeded, $failureCount failed"
}

Write-Host ""

# Return results
return $results
