<#
.SYNOPSIS
    Agent workflow: pick up an issue and begin work.

.DESCRIPTION
    Start-IssueWork.ps1 initializes a work session for a GitHub issue by:
    - Assigning the current user to the issue
    - Creating a feature branch from main (pattern: issue-{number}-{slug})
    - Setting issue status to "In Progress" in the project board
    - Logging the start event
    - Returning a context object for the work session

.PARAMETER IssueNumber
    The issue number to start work on.

.PARAMETER ProjectNumber
    Optional project number to update issue status in. If not provided,
    attempts to find the first accessible project.

.PARAMETER StatusFieldName
    Name of the status field in the project. Default is "Status".

.PARAMETER InProgressValue
    Value to set for the status field. Default is "In Progress".

.PARAMETER SkipBranch
    If specified, skips branch creation. Useful if already on correct branch.

.PARAMETER SkipAssignment
    If specified, skips assigning the issue to the current user.

.PARAMETER SkipStatusUpdate
    If specified, skips updating the issue status in the project.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.OUTPUTS
    PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - IssueNumber: The issue number
    - IssueTitle: The issue title
    - IssueUrl: The issue URL
    - AssignedTo: The user assigned to the issue
    - Branch: The created branch name (if created)
    - Status: The new status (if updated)
    - CorrelationId: The correlation ID for this session
    - StartTime: Timestamp when work started

.EXAMPLE
    .\Start-IssueWork.ps1 -IssueNumber 42
    Starts work on issue #42 with default settings.

.EXAMPLE
    .\Start-IssueWork.ps1 -IssueNumber 42 -ProjectNumber 3
    Starts work on issue #42 and updates status in project #3.

.EXAMPLE
    .\Start-IssueWork.ps1 -IssueNumber 42 -SkipBranch
    Starts work without creating a new branch.

.NOTES
    Dependencies:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
    
    Requires GitHub CLI (gh) to be installed and authenticated.
    Requires PowerShell 7.x or higher.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $false)]
    [int]$ProjectNumber,

    [Parameter(Mandatory = $false)]
    [string]$StatusFieldName = "Status",

    [Parameter(Mandatory = $false)]
    [string]$InProgressValue = "In Progress",

    [Parameter(Mandatory = $false)]
    [switch]$SkipBranch,

    [Parameter(Mandatory = $false)]
    [switch]$SkipAssignment,

    [Parameter(Mandatory = $false)]
    [switch]$SkipStatusUpdate,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Record start time
$startTime = Get-Date

# Import dependencies
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir/Invoke-GraphQL.ps1"
. "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"

Write-OkyeremaLog -Message "Starting work on issue #$IssueNumber" `
    -Level Info `
    -Operation "Start-IssueWork" `
    -CorrelationId $CorrelationId

# Get repository context
try {
    $repoInfo = & gh repo view --json owner,name | ConvertFrom-Json
    $owner = $repoInfo.owner.login
    $repo = $repoInfo.name
    
    Write-OkyeremaLog -Message "Repository: $owner/$repo" `
        -Level Info `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to get repository context: $_" `
        -Level Error `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
    throw
}

# Get current user
try {
    $currentUser = & gh api user --jq .login
    Write-OkyeremaLog -Message "Current user: $currentUser" `
        -Level Info `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
}
catch {
    Write-OkyeremaLog -Message "Failed to get current user: $_" `
        -Level Error `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
    throw
}

# Fetch issue details
Write-OkyeremaLog -Message "Fetching issue #$IssueNumber details" `
    -Level Info `
    -Operation "Start-IssueWork" `
    -CorrelationId $CorrelationId

$issueQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      id
      number
      title
      url
      state
      assignees(first: 10) {
        nodes {
          login
        }
      }
    }
  }
}
"@

$issueVars = @{
    owner = $owner
    repo = $repo
    number = $IssueNumber
}

$issueResult = Invoke-GraphQL -Query $issueQuery -Variables $issueVars -CorrelationId $CorrelationId

if (-not $issueResult.Success -or -not $issueResult.Data.repository.issue) {
    $errorMsg = "Failed to fetch issue #$IssueNumber"
    Write-OkyeremaLog -Message $errorMsg `
        -Level Error `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
    throw $errorMsg
}

$issue = $issueResult.Data.repository.issue
Write-OkyeremaLog -Message "Issue found: $($issue.title)" `
    -Level Info `
    -Operation "Start-IssueWork" `
    -CorrelationId $CorrelationId

# Check if issue is open
if ($issue.state -ne "OPEN") {
    Write-OkyeremaLog -Message "Warning: Issue #$IssueNumber is not in OPEN state (current: $($issue.state))" `
        -Level Warn `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
}

# Assign issue to current user (unless skipped)
$assignedTo = $null
if (-not $SkipAssignment) {
    Write-OkyeremaLog -Message "Assigning issue #$IssueNumber to $currentUser" `
        -Level Info `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
    
    # Check if already assigned
    $currentAssignees = $issue.assignees.nodes | ForEach-Object { $_.login }
    if ($currentAssignees -contains $currentUser) {
        Write-OkyeremaLog -Message "Issue #$IssueNumber is already assigned to $currentUser" `
            -Level Info `
            -Operation "Start-IssueWork" `
            -CorrelationId $CorrelationId
        $assignedTo = $currentUser
    }
    else {
        # Assign using GraphQL mutation
        $assignMutation = @"
mutation(`$issueId: ID!, `$assigneeIds: [ID!]!) {
  addAssigneesToAssignable(input: {
    assignableId: `$issueId
    assigneeIds: `$assigneeIds
  }) {
    assignable {
      ... on Issue {
        id
        assignees(first: 10) {
          nodes {
            login
          }
        }
      }
    }
  }
}
"@
        
        # Get user ID
        $userQuery = "query { user(login: `"$currentUser`") { id } }"
        $userResult = Invoke-GraphQL -Query $userQuery -CorrelationId $CorrelationId
        
        if (-not $userResult.Success -or -not $userResult.Data.user) {
            Write-OkyeremaLog -Message "Failed to get user ID for $currentUser" `
                -Level Error `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
            throw "Failed to get user ID"
        }
        
        $userId = $userResult.Data.user.id
        
        $assignVars = @{
            issueId = $issue.id
            assigneeIds = @($userId)
        }
        
        $assignResult = Invoke-GraphQL -Query $assignMutation -Variables $assignVars -CorrelationId $CorrelationId
        
        if ($assignResult.Success) {
            Write-OkyeremaLog -Message "Successfully assigned issue #$IssueNumber to $currentUser" `
                -Level Info `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
            $assignedTo = $currentUser
        }
        else {
            Write-OkyeremaLog -Message "Failed to assign issue #${IssueNumber}: $($assignResult.Errors[0].Message)" `
                -Level Warn `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
        }
    }
}

# Create feature branch (unless skipped)
$branchName = $null
if (-not $SkipBranch) {
    # Generate branch name: issue-{number}-{slug}
    $titleSlug = $issue.title -replace '[^a-zA-Z0-9\s-]', '' -replace '\s+', '-' -replace '-+', '-'
    $titleSlug = $titleSlug.Trim('-').ToLower()
    # Limit slug length to keep branch name reasonable
    if ($titleSlug.Length -gt 50) {
        $titleSlug = $titleSlug.Substring(0, 50).TrimEnd('-')
    }
    $branchName = "issue-$IssueNumber-$titleSlug"
    
    Write-OkyeremaLog -Message "Creating branch: $branchName" `
        -Level Info `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
    
    try {
        # Fetch latest from origin
        $fetchOutput = git fetch origin main 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-OkyeremaLog -Message "Failed to fetch from origin/main: $fetchOutput" `
                -Level Warn `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
            throw "Git fetch failed"
        }
        
        # Check if branch already exists
        $existingBranch = git branch --list $branchName 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-OkyeremaLog -Message "Failed to list branches: $existingBranch" `
                -Level Warn `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
            throw "Git branch list failed"
        }
        
        if ($existingBranch) {
            Write-OkyeremaLog -Message "Branch $branchName already exists, checking it out" `
                -Level Info `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
            $checkoutOutput = git checkout $branchName 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-OkyeremaLog -Message "Failed to checkout existing branch: $checkoutOutput" `
                    -Level Warn `
                    -Operation "Start-IssueWork" `
                    -CorrelationId $CorrelationId
                throw "Git checkout failed"
            }
        }
        else {
            # Create and checkout new branch from origin/main
            $checkoutOutput = git checkout -b $branchName origin/main 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-OkyeremaLog -Message "Failed to create branch: $checkoutOutput" `
                    -Level Warn `
                    -Operation "Start-IssueWork" `
                    -CorrelationId $CorrelationId
                throw "Git checkout -b failed"
            }
            Write-OkyeremaLog -Message "Created and checked out branch: $branchName" `
                -Level Info `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
        }
    }
    catch {
        Write-OkyeremaLog -Message "Failed to create/checkout branch: $_" `
            -Level Warn `
            -Operation "Start-IssueWork" `
            -CorrelationId $CorrelationId
    }
}

# Update issue status in project (unless skipped)
$statusSet = $null
if (-not $SkipStatusUpdate) {
    Write-OkyeremaLog -Message "Updating issue status to '$InProgressValue'" `
        -Level Info `
        -Operation "Start-IssueWork" `
        -CorrelationId $CorrelationId
    
    try {
        # If ProjectNumber not provided, try to find first accessible project
        if (-not $ProjectNumber) {
            Write-OkyeremaLog -Message "No project number specified, attempting to find default project" `
                -Level Info `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
            
            $projectsJson = & gh project list --owner $owner --format json 2>&1 | Where-Object { $_ -is [string] }
            if ($projectsJson) {
                $projects = $projectsJson | ConvertFrom-Json
                if ($projects -and $projects.Count -gt 0) {
                    $ProjectNumber = $projects[0].number
                    Write-OkyeremaLog -Message "Using project #$ProjectNumber: $($projects[0].title)" `
                        -Level Info `
                        -Operation "Start-IssueWork" `
                        -CorrelationId $CorrelationId
                }
            }
        }
        
        if ($ProjectNumber) {
            # Get project details and field information
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
      items(first: 100) {
        nodes {
          id
          content {
            ... on Issue {
              id
              number
            }
          }
        }
      }
    }
  }
}
"@
            
            $projectVars = @{
                owner = $owner
                projectNumber = $ProjectNumber
            }
            
            $projectResult = Invoke-GraphQL -Query $projectQuery -Variables $projectVars -CorrelationId $CorrelationId
            
            if ($projectResult.Success -and $projectResult.Data.organization.projectV2) {
                $project = $projectResult.Data.organization.projectV2
                
                # Find the status field
                $statusField = $project.fields.nodes | Where-Object { $_.name -eq $StatusFieldName }
                
                if ($statusField) {
                    # Find the "In Progress" option
                    $statusOption = $statusField.options | Where-Object { $_.name -eq $InProgressValue }
                    
                    if ($statusOption) {
                        # Find the project item for this issue
                        $projectItem = $project.items.nodes | Where-Object { 
                            $_.content.number -eq $IssueNumber 
                        }
                        
                        if ($projectItem) {
                            # Update the status field
                            $updateMutation = @"
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
                            
                            $updateVars = @{
                                projectId = $project.id
                                itemId = $projectItem.id
                                fieldId = $statusField.id
                                value = @{ singleSelectOptionId = $statusOption.id }
                            }
                            
                            $updateResult = Invoke-GraphQL -Query $updateMutation -Variables $updateVars -CorrelationId $CorrelationId
                            
                            if ($updateResult.Success) {
                                Write-OkyeremaLog -Message "Successfully updated issue status to '$InProgressValue'" `
                                    -Level Info `
                                    -Operation "Start-IssueWork" `
                                    -CorrelationId $CorrelationId
                                $statusSet = $InProgressValue
                            }
                            else {
                                Write-OkyeremaLog -Message "Failed to update status: $($updateResult.Errors[0].Message)" `
                                    -Level Warn `
                                    -Operation "Start-IssueWork" `
                                    -CorrelationId $CorrelationId
                            }
                        }
                        else {
                            Write-OkyeremaLog -Message "Issue #$IssueNumber not found in project #$ProjectNumber" `
                                -Level Warn `
                                -Operation "Start-IssueWork" `
                                -CorrelationId $CorrelationId
                        }
                    }
                    else {
                        Write-OkyeremaLog -Message "Status option '$InProgressValue' not found in field '$StatusFieldName'" `
                            -Level Warn `
                            -Operation "Start-IssueWork" `
                            -CorrelationId $CorrelationId
                    }
                }
                else {
                    Write-OkyeremaLog -Message "Status field '$StatusFieldName' not found in project #$ProjectNumber" `
                        -Level Warn `
                        -Operation "Start-IssueWork" `
                        -CorrelationId $CorrelationId
                }
            }
            else {
                Write-OkyeremaLog -Message "Failed to fetch project #$ProjectNumber" `
                    -Level Warn `
                    -Operation "Start-IssueWork" `
                    -CorrelationId $CorrelationId
            }
        }
        else {
            Write-OkyeremaLog -Message "No project available to update status" `
                -Level Warn `
                -Operation "Start-IssueWork" `
                -CorrelationId $CorrelationId
        }
    }
    catch {
        Write-OkyeremaLog -Message "Error updating project status: $_" `
            -Level Warn `
            -Operation "Start-IssueWork" `
            -CorrelationId $CorrelationId
    }
}

# Log completion
Write-OkyeremaLog -Message "Work started on issue #$IssueNumber" `
    -Level Info `
    -Operation "Start-IssueWork" `
    -CorrelationId $CorrelationId

# Return context object
$result = [PSCustomObject]@{
    Success = $true
    IssueNumber = $issue.number
    IssueTitle = $issue.title
    IssueUrl = $issue.url
    AssignedTo = $assignedTo
    Branch = $branchName
    Status = $statusSet
    CorrelationId = $CorrelationId
    StartTime = $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}

return $result
