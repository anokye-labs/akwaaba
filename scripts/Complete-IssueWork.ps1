<#
.SYNOPSIS
    Complete work on an issue by creating a PR and preparing it for review.

.DESCRIPTION
    Complete-IssueWork.ps1 finalizes work on an issue by:
    - Creating a PR from the current feature branch
    - Linking the PR to the issue using closing keywords
    - Adding the PR to the project board
    - Setting the project status to "In Review"
    - Running auto-approval checks (if Test-PRAutoApprovable.ps1 exists)
    - Adding approval labels if auto-approvable
    - Logging the completion event
    
    This script is designed to be used by both humans and agents as part of the
    issue → branch → PR workflow.

.PARAMETER IssueNumber
    The issue number being completed. Used to link the PR and validate the branch name.

.PARAMETER PRTitle
    Optional custom title for the PR. If not provided, uses the issue title.

.PARAMETER PRBody
    Optional custom body for the PR. If not provided, creates a standard format
    that references the issue.

.PARAMETER Owner
    GitHub repository owner (organization or user). If not specified, attempts to
    detect from current repository context.

.PARAMETER Repo
    GitHub repository name. If not specified, attempts to detect from current
    repository context.

.PARAMETER ProjectNumber
    Project number to add the PR to. If not provided, attempts to use the first
    project found in the repository context.

.PARAMETER DryRun
    If specified, shows what would be done without making actual changes.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.PARAMETER Quiet
    Suppresses log output from Write-OkyeremaLog.

.EXAMPLE
    .\Complete-IssueWork.ps1 -IssueNumber 42
    
    Creates a PR for issue #42 using default settings.

.EXAMPLE
    .\Complete-IssueWork.ps1 -IssueNumber 42 -PRTitle "Fix authentication bug" -ProjectNumber 3
    
    Creates a PR with a custom title and adds it to project #3.

.EXAMPLE
    .\Complete-IssueWork.ps1 -IssueNumber 42 -DryRun
    
    Shows what would be done without making changes.

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - PRNumber: The PR number created
    - PRURL: URL of the created PR
    - IsAutoApprovable: Whether the PR passed auto-approval checks
    - ProjectItemId: The project item ID if added to project
    - Message: Status message

.NOTES
    Author: Anokye Labs
    Dependencies: 
    - Invoke-GraphQL.ps1 (for GraphQL execution)
    - Get-RepoContext.ps1 (for repository context)
    - Write-OkyeremaLog.ps1 (for structured logging)
    - Get-PRStatus.ps1 (for PR status information)
    - Test-PRAutoApprovable.ps1 (optional, for auto-approval checks)
    
    Requires GitHub CLI (gh) to be installed and authenticated.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $false)]
    [string]$PRTitle,

    [Parameter(Mandatory = $false)]
    [string]$PRBody,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [int]$ProjectNumber,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

#region Load Dependencies

$scriptRoot = $PSScriptRoot
$invokeGraphQLPath = Join-Path $scriptRoot "Invoke-GraphQL.ps1"
$getRepoContextPath = Join-Path $scriptRoot "Get-RepoContext.ps1"
$writeLogPath = Join-Path $scriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
$getPRStatusPath = Join-Path $scriptRoot "Get-PRStatus.ps1"
$testAutoApprovablePath = Join-Path $scriptRoot "Test-PRAutoApprovable.ps1"

if (-not (Test-Path $invokeGraphQLPath)) {
    throw "Required dependency not found: $invokeGraphQLPath"
}
if (-not (Test-Path $getRepoContextPath)) {
    throw "Required dependency not found: $getRepoContextPath"
}
if (-not (Test-Path $writeLogPath)) {
    throw "Required dependency not found: $writeLogPath"
}

# Dot-source dependencies
. $invokeGraphQLPath
. $getRepoContextPath
. $writeLogPath

#endregion

#region Helper Functions

# Helper function for structured logging
function Write-OkyeremaLogHelper {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warn", "Error", "Debug")]
        [string]$Level = "Info",

        [Parameter(Mandatory = $false)]
        [string]$Operation = "",

        [Parameter(Mandatory = $false)]
        [string]$CorrelationId = "",

        [Parameter(Mandatory = $false)]
        [switch]$Quiet
    )
    
    $params = @{
        Message = $Message
        Level = $Level
    }
    
    if ($Operation) {
        $params.Operation = $Operation
    }
    
    if ($CorrelationId) {
        $params.CorrelationId = $CorrelationId
    }
    
    if ($Quiet) {
        $params.Quiet = $true
    }
    
    # Call Write-OkyeremaLog.ps1 as a script
    & $writeLogPath @params
}

# Helper function to get repository context
function Get-RepoContextHelper {
    param()
    
    $contextPath = Join-Path $PSScriptRoot "Get-RepoContext.ps1"
    if (Test-Path $contextPath) {
        return & $contextPath
    }
    return $null
}

# Helper function to safely get first error message
function Get-FirstErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        $Result
    )
    
    if ($Result.Errors -and $Result.Errors.Count -gt 0) {
        return $Result.Errors[0].Message
    }
    return "Unknown error"
}

#endregion

#region Main Logic

Write-OkyeremaLogHelper -Level Info -Message "Starting Complete-IssueWork for issue #$IssueNumber" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Step 1: Get current branch and verify it's an issue branch
Write-OkyeremaLogHelper -Level Info -Message "Checking current branch" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

$currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-OkyeremaLogHelper -Level Error -Message "Failed to get current branch: $currentBranch" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw "Failed to get current branch"
}

# Validate branch name follows issue-{number}-* pattern
$branchPattern = "^issue-(\d+)-"
if ($currentBranch -notmatch $branchPattern) {
    Write-OkyeremaLogHelper -Level Error -Message "Current branch '$currentBranch' does not follow issue-{number}-* pattern" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw "Current branch '$currentBranch' does not follow the expected pattern: issue-{number}-*"
}

$branchIssueNumber = [int]$matches[1]
if ($branchIssueNumber -ne $IssueNumber) {
    Write-OkyeremaLogHelper -Level Error -Message "Branch issue number ($branchIssueNumber) does not match provided issue number ($IssueNumber)" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw "Branch issue number ($branchIssueNumber) does not match provided issue number ($IssueNumber)"
}

Write-OkyeremaLogHelper -Level Info -Message "Branch validated: $currentBranch" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Step 2: Get repository context if Owner/Repo not provided
if (-not $Owner -or -not $Repo) {
    Write-OkyeremaLogHelper -Level Info -Message "Fetching repository context" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    $context = Get-RepoContextHelper
    
    if ($context) {
        # Parse owner and repo from GitHub CLI
        try {
            $repoViewResult = gh repo view --json nameWithOwner 2>&1
            if ($LASTEXITCODE -eq 0) {
                $repoViewJson = $repoViewResult | ConvertFrom-Json
                if ($repoViewJson -and $repoViewJson.nameWithOwner) {
                    $parts = $repoViewJson.nameWithOwner.Split('/')
                    if ($parts.Length -eq 2) {
                        if (-not $Owner) { $Owner = $parts[0] }
                        if (-not $Repo) { $Repo = $parts[1] }
                    }
                }
            }
        }
        catch {
            Write-OkyeremaLogHelper -Level Warn -Message "Could not get repository info from gh CLI: $_" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
        }
    }
    
    if (-not $Owner -or -not $Repo) {
        Write-OkyeremaLogHelper -Level Error -Message "Could not determine repository owner and name" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
        throw "Owner and Repo parameters are required, or must be run from a Git repository"
    }
}

Write-OkyeremaLogHelper -Level Debug -Message "Using repository: $Owner/$Repo" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Step 3: Get issue details
Write-OkyeremaLogHelper -Level Info -Message "Fetching issue #$IssueNumber details" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

$issueQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      id
      number
      title
      body
      state
    }
  }
}
"@

$issueVars = @{
    owner = $Owner
    repo = $Repo
    number = $IssueNumber
}

$issueResult = Invoke-GraphQL -Query $issueQuery -Variables $issueVars -CorrelationId $CorrelationId -DryRun:$DryRun

if (-not $issueResult.Success) {
    $errorMsg = "Failed to fetch issue #${IssueNumber}: $(Get-FirstErrorMessage -Result $issueResult)"
    Write-OkyeremaLogHelper -Level Error -Message $errorMsg -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw $errorMsg
}

$issue = $issueResult.Data.repository.issue
if (-not $issue) {
    Write-OkyeremaLogHelper -Level Error -Message "Issue #$IssueNumber not found" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw "Issue #$IssueNumber not found in $Owner/$Repo"
}

Write-OkyeremaLogHelper -Level Info -Message "Issue found: $($issue.title)" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Step 4: Prepare PR title and body
if (-not $PRTitle) {
    $PRTitle = $issue.title
}

if (-not $PRBody) {
    $PRBody = @"
Closes #$IssueNumber

## Changes
This PR addresses the requirements specified in issue #$IssueNumber.

## Testing
- Tested locally
- All checks passing

---
*This PR was created by Complete-IssueWork.ps1*
"@
}

Write-OkyeremaLogHelper -Level Debug -Message "PR Title: $PRTitle" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Step 5: Create PR
if ($DryRun) {
    Write-OkyeremaLogHelper -Level Info -Message "[DryRun] Would create PR: '$PRTitle' from '$currentBranch' to base branch" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    
    return [PSCustomObject]@{
        Success = $true
        PRNumber = 0
        PRURL = "https://github.com/$Owner/$Repo/pull/0"
        IsAutoApprovable = $false
        ProjectItemId = $null
        Message = "[DryRun] PR would be created"
        DryRun = $true
    }
}

Write-OkyeremaLogHelper -Level Info -Message "Creating PR" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Use gh CLI to create PR
$prCreateArgs = @(
    "pr", "create",
    "--title", $PRTitle,
    "--body", $PRBody,
    "--repo", "$Owner/$Repo"
)

$prResult = & gh @prCreateArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-OkyeremaLogHelper -Level Error -Message "Failed to create PR: $prResult" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw "Failed to create PR: $prResult"
}

# Extract PR URL from output
$prURL = $prResult | Select-Object -Last 1
Write-OkyeremaLogHelper -Level Info -Message "PR created: $prURL" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Extract PR number from URL
if ($prURL -match '/pull/(\d+)') {
    $prNumber = [int]$matches[1]
}
else {
    Write-OkyeremaLogHelper -Level Error -Message "Could not extract PR number from URL: $prURL" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    throw "Could not extract PR number from URL"
}

Write-OkyeremaLogHelper -Level Info -Message "PR #$prNumber created successfully" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Step 6: Get PR node ID for project operations
$prQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$number) {
      id
      number
      title
      url
    }
  }
}
"@

$prVars = @{
    owner = $Owner
    repo = $Repo
    number = $prNumber
}

$prQueryResult = Invoke-GraphQL -Query $prQuery -Variables $prVars -CorrelationId $CorrelationId

if (-not $prQueryResult.Success) {
    Write-OkyeremaLogHelper -Level Warn -Message "Could not fetch PR details, skipping project operations: $(Get-FirstErrorMessage -Result $prQueryResult)" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
}
else {
    $pr = $prQueryResult.Data.repository.pullRequest
    $prNodeId = $pr.id

    # Step 7: Add PR to project board if ProjectNumber provided
    if ($ProjectNumber) {
        Write-OkyeremaLogHelper -Level Info -Message "Adding PR to project #$ProjectNumber" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

        # Get project details
        $projectQuery = @"
query(`$owner: String!, `$projectNumber: Int!) {
  organization(login: `$owner) {
    projectV2(number: `$projectNumber) {
      id
      title
      fields(first: 50) {
        nodes {
          ... on ProjectV2Field {
            id
            name
            dataType
          }
          ... on ProjectV2SingleSelectField {
            id
            name
            dataType
            options {
              id
              name
            }
          }
        }
      }
    }
  }
}
"@

        $projectVars = @{
            owner = $Owner
            projectNumber = $ProjectNumber
        }

        $projectResult = Invoke-GraphQL -Query $projectQuery -Variables $projectVars -CorrelationId $CorrelationId

        if (-not $projectResult.Success) {
            Write-OkyeremaLogHelper -Level Warn -Message "Could not fetch project details: $(Get-FirstErrorMessage -Result $projectResult)" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
        }
        else {
            $project = $projectResult.Data.organization.projectV2
            if ($project) {
                $projectId = $project.id

                # Add PR to project
                $addToProjectMutation = @"
mutation(`$projectId: ID!, `$contentId: ID!) {
  addProjectV2ItemById(input: {
    projectId: `$projectId
    contentId: `$contentId
  }) {
    item {
      id
    }
  }
}
"@

                $addToProjectVars = @{
                    projectId = $projectId
                    contentId = $prNodeId
                }

                $addResult = Invoke-GraphQL -Query $addToProjectMutation -Variables $addToProjectVars -CorrelationId $CorrelationId

                if ($addResult.Success) {
                    $projectItemId = $addResult.Data.addProjectV2ItemById.item.id
                    Write-OkyeremaLogHelper -Level Info -Message "PR added to project, item ID: $projectItemId" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

                    # Step 8: Set project field "Status" to "In Review"
                    $statusField = $project.fields.nodes | Where-Object { $_.name -eq "Status" -and $_.dataType -eq "SINGLE_SELECT" }
                    
                    if ($statusField) {
                        $inReviewOption = $statusField.options | Where-Object { $_.name -eq "In Review" }
                        
                        if ($inReviewOption) {
                            Write-OkyeremaLogHelper -Level Info -Message "Setting Status to 'In Review'" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

                            $updateFieldMutation = @"
mutation(`$projectId: ID!, `$itemId: ID!, `$fieldId: ID!, `$value: ProjectV2FieldValue!) {
  updateProjectV2ItemFieldValue(input: {
    projectId: `$projectId
    itemId: `$itemId
    fieldId: `$fieldId
    value: `$value
  }) {
    projectV2Item {
      id
    }
  }
}
"@

                            $updateFieldVars = @{
                                projectId = $projectId
                                itemId = $projectItemId
                                fieldId = $statusField.id
                                value = @{
                                    singleSelectOptionId = $inReviewOption.id
                                }
                            }

                            $updateResult = Invoke-GraphQL -Query $updateFieldMutation -Variables $updateFieldVars -CorrelationId $CorrelationId

                            if ($updateResult.Success) {
                                Write-OkyeremaLogHelper -Level Info -Message "Status set to 'In Review'" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
                            }
                            else {
                                Write-OkyeremaLogHelper -Level Warn -Message "Could not set Status field: $(Get-FirstErrorMessage -Result $updateResult)" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
                            }
                        }
                        else {
                            Write-OkyeremaLogHelper -Level Warn -Message "'In Review' option not found in Status field" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
                        }
                    }
                    else {
                        Write-OkyeremaLogHelper -Level Warn -Message "Status field not found in project" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
                    }
                }
                else {
                    Write-OkyeremaLogHelper -Level Warn -Message "Could not add PR to project: $(Get-FirstErrorMessage -Result $addResult)" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
                }
            }
            else {
                Write-OkyeremaLogHelper -Level Warn -Message "Project #$ProjectNumber not found in organization $Owner" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            }
        }
    }
}

# Step 9: Run auto-approval check if Test-PRAutoApprovable.ps1 exists
$isAutoApprovable = $false
if (Test-Path $testAutoApprovablePath) {
    Write-OkyeremaLogHelper -Level Info -Message "Running auto-approval check" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    
    try {
        $autoApprovalResult = & $testAutoApprovablePath -PRNumber $prNumber -Owner $Owner -Repo $Repo -OutputFormat Json
        
        if ($autoApprovalResult -and $autoApprovalResult.autoApprovable) {
            $isAutoApprovable = $true
            Write-OkyeremaLogHelper -Level Info -Message "PR is auto-approvable" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            
            # Step 10: Add approval label
            Write-OkyeremaLogHelper -Level Info -Message "Adding auto-approval label" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            
            $labelResult = gh pr edit $prNumber --add-label "auto-approval" --repo "$Owner/$Repo" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-OkyeremaLogHelper -Level Info -Message "Auto-approval label added" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            }
            else {
                Write-OkyeremaLogHelper -Level Warn -Message "Could not add auto-approval label: $labelResult" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            }
        }
        else {
            Write-OkyeremaLogHelper -Level Info -Message "PR is not auto-approvable" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            if ($autoApprovalResult.failedChecks) {
                Write-OkyeremaLogHelper -Level Debug -Message "Failed checks: $($autoApprovalResult.failedChecks -join ', ')" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
            }
        }
    }
    catch {
        Write-OkyeremaLogHelper -Level Warn -Message "Error running auto-approval check: $_" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
    }
}
else {
    Write-OkyeremaLogHelper -Level Debug -Message "Test-PRAutoApprovable.ps1 not found, skipping auto-approval check" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet
}

# Step 11: Log completion event
Write-OkyeremaLogHelper -Level Info -Message "Issue #$IssueNumber work completed. PR #$prNumber created: $prURL" -Operation "Complete-IssueWork" -CorrelationId $CorrelationId -Quiet:$Quiet

# Return result
return [PSCustomObject]@{
    Success = $true
    PRNumber = $prNumber
    PRURL = $prURL
    IsAutoApprovable = $isAutoApprovable
    ProjectItemId = if ($projectItemId) { $projectItemId } else { $null }
    Message = "PR #$prNumber created successfully"
}

#endregion
