<#
.SYNOPSIS
    Bulk-add issues to a GitHub Project V2 and optionally set field values.

.DESCRIPTION
    This script adds multiple issues to a GitHub Project V2 board with optional
    custom field value configuration. It handles the complete workflow:
    - Resolves project ID from project number
    - Converts issue numbers to issue IDs
    - Adds issues to the project
    - Optionally sets custom field values (Status, Priority, etc.)
    - Implements rate limiting between mutations to avoid API throttling

.PARAMETER IssueNumbers
    Array of issue numbers to add to the project. Can be provided as an array
    or via pipeline input.

.PARAMETER ProjectNumber
    The project number (not ID) to add issues to. For example, if your project
    URL is https://github.com/orgs/anokye-labs/projects/3, use 3.

.PARAMETER FieldValues
    Optional hashtable of custom field values to set on added items.
    Keys are field names, values are the field values to set.
    
    Supported field types:
    - Text: String values
    - SingleSelect: Option name (e.g., "In Progress", "High Priority")
    - Number: Numeric values
    
    Example: @{ Status = "In Progress"; Priority = "High" }

.PARAMETER Owner
    Optional organization/owner name. If not provided, attempts to detect
    from current repository context.

.PARAMETER Repo
    Optional repository name. If not provided, attempts to detect from
    current repository context.

.PARAMETER DelayMs
    Delay in milliseconds between mutations. Default is 500ms to respect
    GitHub's rate limits.

.PARAMETER CorrelationId
    Optional correlation ID for tracing related operations. If not provided,
    one will be generated.

.PARAMETER Quiet
    Suppresses log output from Write-OkyeremaLog.

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if all operations succeeded
    - AddedCount: Number of issues successfully added
    - FailedCount: Number of issues that failed to add
    - Results: Array of individual operation results

.EXAMPLE
    .\Add-IssuesToProject.ps1 -IssueNumbers 101,102,103 -ProjectNumber 3
    
    Adds issues #101, #102, and #103 to project #3.

.EXAMPLE
    .\Add-IssuesToProject.ps1 -IssueNumbers 101,102 -ProjectNumber 3 -FieldValues @{ Status = "In Progress"; Priority = "High" }
    
    Adds issues with custom field values set.

.EXAMPLE
    101, 102, 103 | .\Add-IssuesToProject.ps1 -ProjectNumber 3
    
    Uses pipeline input to add issues to project.

.EXAMPLE
    .\Add-IssuesToProject.ps1 -IssueNumbers 101 -ProjectNumber 3 -Owner "anokye-labs" -Repo "akwaaba"
    
    Explicitly specifies owner and repository.

.NOTES
    Dependencies:
    - Invoke-GraphQL.ps1 (for GraphQL execution)
    - Get-RepoContext.ps1 (for repository context)
    - Write-OkyeremaLog.ps1 (for structured logging)
    
    Requires GitHub CLI (gh) to be installed and authenticated.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [int[]]$IssueNumbers,

    [Parameter(Mandatory = $true, Position = 1)]
    [int]$ProjectNumber,

    [Parameter(Mandatory = $false)]
    [hashtable]$FieldValues = @{},

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [int]$DelayMs = 500,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

begin {
    $ErrorActionPreference = "Stop"

    # Generate correlation ID if not provided
    if (-not $CorrelationId) {
        $CorrelationId = [guid]::NewGuid().ToString()
    }

    # Load dependencies
    $scriptRoot = $PSScriptRoot
    $invokeGraphQLPath = Join-Path $scriptRoot "Invoke-GraphQL.ps1"
    $getRepoContextPath = Join-Path $scriptRoot "Get-RepoContext.ps1"
    $writeLogPath = Join-Path $scriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"

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

    # Initialize results tracking
    $allIssueNumbers = @()
    $results = @()
    $addedCount = 0
    $failedCount = 0

    # Log start
    Write-OkyeremaLog -Message "Starting bulk-add issues to project" `
        -Level Info `
        -Operation "Add-IssuesToProject" `
        -CorrelationId $CorrelationId `
        -Quiet:$Quiet
}

process {
    # Collect all issue numbers from pipeline
    $allIssueNumbers += $IssueNumbers
}

end {
    try {
        # Get repository context
        Write-OkyeremaLog -Message "Fetching repository context" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

        # Detect owner/repo if not provided
        if (-not $Owner -or -not $Repo) {
            $repoInfo = & gh repo view --json owner,name | ConvertFrom-Json
            if (-not $Owner) {
                $Owner = $repoInfo.owner.login
            }
            if (-not $Repo) {
                $Repo = $repoInfo.name
            }
        }

        Write-OkyeremaLog -Message "Target: $Owner/$Repo, Project #$ProjectNumber, Issues: $($allIssueNumbers -join ', ')" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

        # Step 1: Get Project ID
        Write-OkyeremaLog -Message "Resolving project ID for project #$ProjectNumber" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

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
            $errorMsg = "Failed to fetch project: $($projectResult.Errors[0].Message)"
            Write-OkyeremaLog -Message $errorMsg `
                -Level Error `
                -Operation "Add-IssuesToProject" `
                -CorrelationId $CorrelationId `
                -Quiet:$Quiet
            throw $errorMsg
        }

        $project = $projectResult.Data.organization.projectV2
        if (-not $project) {
            $errorMsg = "Project #$ProjectNumber not found in organization $Owner"
            Write-OkyeremaLog -Message $errorMsg `
                -Level Error `
                -Operation "Add-IssuesToProject" `
                -CorrelationId $CorrelationId `
                -Quiet:$Quiet
            throw $errorMsg
        }

        $projectId = $project.id
        Write-OkyeremaLog -Message "Project resolved: $($project.title) ($projectId)" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

        # Step 2: Build field mapping if FieldValues provided
        $fieldMapping = @{}
        if ($FieldValues.Count -gt 0) {
            Write-OkyeremaLog -Message "Building field mapping for $($FieldValues.Count) field(s)" `
                -Level Info `
                -Operation "Add-IssuesToProject" `
                -CorrelationId $CorrelationId `
                -Quiet:$Quiet

            foreach ($fieldName in $FieldValues.Keys) {
                $field = $project.fields.nodes | Where-Object { $_.name -eq $fieldName }
                
                if (-not $field) {
                    Write-OkyeremaLog -Message "Field '$fieldName' not found in project, skipping" `
                        -Level Warn `
                        -Operation "Add-IssuesToProject" `
                        -CorrelationId $CorrelationId `
                        -Quiet:$Quiet
                    continue
                }

                $fieldInfo = @{
                    Id = $field.id
                    DataType = $field.dataType
                    Value = $FieldValues[$fieldName]
                }

                # For SingleSelect fields, resolve option ID
                if ($field.dataType -eq "SINGLE_SELECT") {
                    $optionName = $FieldValues[$fieldName]
                    $option = $field.options | Where-Object { $_.name -eq $optionName }
                    
                    if (-not $option) {
                        Write-OkyeremaLog -Message "Option '$optionName' not found for field '$fieldName', skipping" `
                            -Level Warn `
                            -Operation "Add-IssuesToProject" `
                            -CorrelationId $CorrelationId `
                            -Quiet:$Quiet
                        continue
                    }
                    
                    $fieldInfo.OptionId = $option.id
                    Write-OkyeremaLog -Message "Field '$fieldName': mapped option '$optionName' to $($option.id)" `
                        -Level Debug `
                        -Operation "Add-IssuesToProject" `
                        -CorrelationId $CorrelationId `
                        -Quiet:$Quiet
                }

                $fieldMapping[$fieldName] = $fieldInfo
                Write-OkyeremaLog -Message "Field '$fieldName' mapped: type=$($field.dataType), id=$($field.id)" `
                    -Level Debug `
                    -Operation "Add-IssuesToProject" `
                    -CorrelationId $CorrelationId `
                    -Quiet:$Quiet
            }
        }

        # Step 3: Get Issue IDs
        Write-OkyeremaLog -Message "Fetching issue IDs for $($allIssueNumbers.Count) issue(s)" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

        $issueMap = @{}
        foreach ($issueNum in $allIssueNumbers) {
            $issueQuery = @"
query(`$owner: String!, `$repo: String!, `$number: Int!) {
  repository(owner: `$owner, name: `$repo) {
    issue(number: `$number) {
      id
      number
      title
    }
  }
}
"@

            $issueVars = @{
                owner = $Owner
                repo = $Repo
                number = $issueNum
            }

            $issueResult = Invoke-GraphQL -Query $issueQuery -Variables $issueVars -CorrelationId $CorrelationId
            
            if ($issueResult.Success -and $issueResult.Data.repository.issue) {
                $issue = $issueResult.Data.repository.issue
                $issueMap[$issueNum] = @{
                    Id = $issue.id
                    Number = $issue.number
                    Title = $issue.title
                }
                Write-OkyeremaLog -Message "Issue #$issueNum resolved: $($issue.title) ($($issue.id))" `
                    -Level Debug `
                    -Operation "Add-IssuesToProject" `
                    -CorrelationId $CorrelationId `
                    -Quiet:$Quiet
            }
            else {
                Write-OkyeremaLog -Message "Issue #$issueNum not found or failed to fetch" `
                    -Level Warn `
                    -Operation "Add-IssuesToProject" `
                    -CorrelationId $CorrelationId `
                    -Quiet:$Quiet
            }
        }

        # Step 4: Add issues to project
        Write-OkyeremaLog -Message "Adding $($issueMap.Count) issue(s) to project" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

        foreach ($issueNum in $issueMap.Keys) {
            $issueInfo = $issueMap[$issueNum]
            
            # Add issue to project
            $addMutation = @"
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

            $addVars = @{
                projectId = $projectId
                contentId = $issueInfo.Id
            }

            $addResult = Invoke-GraphQL -Query $addMutation -Variables $addVars -CorrelationId $CorrelationId
            
            if ($addResult.Success) {
                $itemId = $addResult.Data.addProjectV2ItemById.item.id
                $addedCount++
                
                Write-OkyeremaLog -Message "Added issue #$issueNum to project (item ID: $itemId)" `
                    -Level Info `
                    -Operation "Add-IssuesToProject" `
                    -CorrelationId $CorrelationId `
                    -Quiet:$Quiet

                # Set field values if provided
                if ($fieldMapping.Count -gt 0) {
                    foreach ($fieldName in $fieldMapping.Keys) {
                        $fieldInfo = $fieldMapping[$fieldName]
                        
                        # Build value object based on field type
                        $valueObj = switch ($fieldInfo.DataType) {
                            "TEXT" { @{ text = $fieldInfo.Value } }
                            "SINGLE_SELECT" { @{ singleSelectOptionId = $fieldInfo.OptionId } }
                            "NUMBER" { @{ number = [int]$fieldInfo.Value } }
                            default {
                                Write-OkyeremaLog -Message "Unsupported field type '$($fieldInfo.DataType)' for field '$fieldName'" `
                                    -Level Warn `
                                    -Operation "Add-IssuesToProject" `
                                    -CorrelationId $CorrelationId `
                                    -Quiet:$Quiet
                                $null
                            }
                        }

                        if ($valueObj) {
                            # Convert value object to JSON for GraphQL variable
                            $valueJson = $valueObj | ConvertTo-Json -Compress
                            
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
                                projectId = $projectId
                                itemId = $itemId
                                fieldId = $fieldInfo.Id
                                value = $valueJson
                            }

                            $updateResult = Invoke-GraphQL -Query $updateMutation -Variables $updateVars -CorrelationId $CorrelationId
                            
                            if ($updateResult.Success) {
                                Write-OkyeremaLog -Message "Set field '$fieldName' = '$($fieldInfo.Value)' for issue #$issueNum" `
                                    -Level Info `
                                    -Operation "Add-IssuesToProject" `
                                    -CorrelationId $CorrelationId `
                                    -Quiet:$Quiet
                            }
                            else {
                                Write-OkyeremaLog -Message "Failed to set field '$fieldName' for issue #${issueNum}: $($updateResult.Errors[0].Message)" `
                                    -Level Warn `
                                    -Operation "Add-IssuesToProject" `
                                    -CorrelationId $CorrelationId `
                                    -Quiet:$Quiet
                            }

                            # Rate limiting between field updates
                            Start-Sleep -Milliseconds $DelayMs
                        }
                    }
                }

                $results += [PSCustomObject]@{
                    IssueNumber = $issueNum
                    Success = $true
                    ItemId = $itemId
                    Error = $null
                }
            }
            else {
                $failedCount++
                $errorMsg = $addResult.Errors[0].Message
                
                Write-OkyeremaLog -Message "Failed to add issue #${issueNum}: $errorMsg" `
                    -Level Error `
                    -Operation "Add-IssuesToProject" `
                    -CorrelationId $CorrelationId `
                    -Quiet:$Quiet

                $results += [PSCustomObject]@{
                    IssueNumber = $issueNum
                    Success = $false
                    ItemId = $null
                    Error = $errorMsg
                }
            }

            # Rate limiting between add operations
            Start-Sleep -Milliseconds $DelayMs
        }

        # Summary
        Write-OkyeremaLog -Message "Completed: $addedCount added, $failedCount failed" `
            -Level Info `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet

        # Return results
        return [PSCustomObject]@{
            Success = ($failedCount -eq 0)
            AddedCount = $addedCount
            FailedCount = $failedCount
            Results = $results
            CorrelationId = $CorrelationId
        }
    }
    catch {
        Write-OkyeremaLog -Message "Fatal error: $_" `
            -Level Error `
            -Operation "Add-IssuesToProject" `
            -CorrelationId $CorrelationId `
            -Quiet:$Quiet
        
        throw
    }
}
