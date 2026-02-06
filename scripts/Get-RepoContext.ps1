<#
.SYNOPSIS
    Fetches repository context (repo ID, issue types, project IDs, and label IDs) in one query.

.DESCRIPTION
    Get-RepoContext.ps1 performs a one-shot query to fetch comprehensive repository metadata
    from GitHub, including repository ID, organization issue type IDs, project IDs, and label IDs.
    Results are cached in the session for reuse, and can be refreshed with the -Refresh switch.

.PARAMETER Refresh
    Forces a re-fetch of the repository context, bypassing the session cache.

.OUTPUTS
    PSCustomObject with the following properties:
    - RepoId: The ID of the repository (string identifier)
    - IssueTypes: Array of organization issue types with their IDs and names
    - ProjectId: Array of project IDs and names associated with the repository
    - Labels: Array of label names, IDs, and colors in the repository

.EXAMPLE
    PS> .\Get-RepoContext.ps1
    Fetches repository context and caches it in the session.

.EXAMPLE
    PS> .\Get-RepoContext.ps1 -Refresh
    Forces a fresh fetch of repository context, ignoring cached data.

.EXAMPLE
    PS> $context = .\Get-RepoContext.ps1
    PS> $context.RepoId
    Fetches context and accesses the repository ID.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Uses session-scoped caching via $script: scope variables.
#>

[CmdletBinding()]
param(
    [switch]$Refresh
)

# Session cache variable
if (-not $script:RepoContextCache) {
    $script:RepoContextCache = $null
}

function Get-RepositoryId {
    <#
    .SYNOPSIS
        Fetches the repository ID using GitHub CLI.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Fetching repository ID..."
        
        # Get current repository information
        $repoInfo = gh repo view --json id,nameWithOwner | ConvertFrom-Json
        
        if ($repoInfo -and $repoInfo.id) {
            Write-Verbose "Repository ID: $($repoInfo.id)"
            return @{
                Id = $repoInfo.id
                NameWithOwner = $repoInfo.nameWithOwner
            }
        }
        else {
            Write-Warning "Could not retrieve repository ID"
            return $null
        }
    }
    catch {
        Write-Error "Failed to fetch repository ID: $_"
        return $null
    }
}

function Get-OrganizationIssueTypes {
    <#
    .SYNOPSIS
        Fetches organization issue types using GitHub CLI.
    #>
    [CmdletBinding()]
    param(
        [string]$Owner
    )
    
    try {
        Write-Verbose "Fetching organization issue types for $Owner..."
        
        # Attempt to get issue types from the organization's projects
        # Note: This requires GitHub GraphQL API access
        $query = @"
query {
  organization(login: "$Owner") {
    projectsV2(first: 5) {
      nodes {
        id
        title
        fields(first: 20) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id
              name
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
}
"@
        
        # Try to fetch issue types - this may not be available in all orgs
        $errorOutput = $null
        $result = gh api graphql -f query="$query" 2>&1 | Tee-Object -Variable errorOutput | 
            Where-Object { $_ -is [string] } | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        # Log any errors for debugging
        if ($errorOutput) {
            $errorMessages = $errorOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            if ($errorMessages) {
                Write-Verbose "GraphQL query info: $($errorMessages -join '; ')"
            }
        }
        
        if ($result -and $result.data.organization.projectsV2.nodes) {
            $issueTypes = @()
            
            foreach ($project in $result.data.organization.projectsV2.nodes) {
                $issueTypeFields = $project.fields.nodes | 
                    Where-Object { $_.name -like "*Type*" -or $_.name -like "*Issue*" }
                
                foreach ($field in $issueTypeFields) {
                    if ($field.options) {
                        foreach ($option in $field.options) {
                            $issueTypes += @{
                                Id = $option.id
                                Name = $option.name
                                FieldName = $field.name
                                ProjectTitle = $project.title
                            }
                        }
                    }
                }
            }
            
            Write-Verbose "Found $($issueTypes.Count) issue types"
            return $issueTypes
        }
        else {
            Write-Verbose "No issue types found or not available for this organization"
            return @()
        }
    }
    catch {
        Write-Warning "Could not fetch organization issue types: $_"
        return @()
    }
}

function Get-RepositoryProjects {
    <#
    .SYNOPSIS
        Fetches project IDs accessible to the authenticated user.
    .DESCRIPTION
        Returns projects owned by the authenticated user. In practice, this includes
        organization and repository projects that the user has access to.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Fetching accessible projects..."
        
        # Get projects accessible to the authenticated user
        # This includes organization and repository projects
        $errorOutput = $null
        $projects = gh project list --owner "@me" --format json 2>&1 | Tee-Object -Variable errorOutput |
            Where-Object { $_ -is [string] } | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        # Log any errors for debugging
        if ($errorOutput) {
            $errorMessages = $errorOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
            if ($errorMessages) {
                Write-Verbose "Project list query info: $($errorMessages -join '; ')"
            }
        }
        
        if ($projects) {
            $projectList = @()
            foreach ($project in $projects) {
                $projectList += @{
                    Id = $project.id
                    Number = $project.number
                    Title = $project.title
                    Url = $project.url
                }
            }
            
            Write-Verbose "Found $($projectList.Count) projects"
            return $projectList
        }
        else {
            Write-Verbose "No projects found"
            return @()
        }
    }
    catch {
        Write-Warning "Could not fetch repository projects: $_"
        return @()
    }
}

function Get-RepositoryLabels {
    <#
    .SYNOPSIS
        Fetches label IDs and names from the repository.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Fetching repository labels..."
        
        # Get all labels from the repository
        $labels = gh label list --json id,name,color,description --limit 1000 | ConvertFrom-Json
        
        if ($labels) {
            $labelList = @()
            foreach ($label in $labels) {
                $labelList += @{
                    Id = $label.id
                    Name = $label.name
                    Color = $label.color
                    Description = $label.description
                }
            }
            
            Write-Verbose "Found $($labelList.Count) labels"
            return $labelList
        }
        else {
            Write-Verbose "No labels found"
            return @()
        }
    }
    catch {
        Write-Error "Failed to fetch repository labels: $_"
        return @()
    }
}

# Main execution
Write-Verbose "Get-RepoContext: Starting..."

# Check if cache exists and -Refresh not specified
if ($script:RepoContextCache -and -not $Refresh) {
    Write-Verbose "Returning cached repository context"
    return $script:RepoContextCache
}

# Fetch all context data
Write-Verbose "Fetching fresh repository context..."

$repoInfo = Get-RepositoryId
$owner = if ($repoInfo -and $repoInfo.NameWithOwner) { 
    $repoInfo.NameWithOwner.Split('/')[0] 
} else { 
    $null 
}

$issueTypes = if ($owner) { Get-OrganizationIssueTypes -Owner $owner } else { @() }
$projects = Get-RepositoryProjects
$labels = Get-RepositoryLabels

# Create result object
$result = [PSCustomObject]@{
    RepoId = $repoInfo.Id
    IssueTypes = $issueTypes
    ProjectId = $projects
    Labels = $labels
}

# Cache the result
$script:RepoContextCache = $result

Write-Verbose "Repository context cached for session reuse"

# Return the result
return $result
