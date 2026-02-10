<#
.SYNOPSIS
    Checks if a GitHub issue exists, is in the same repository, and is open.

.DESCRIPTION
    Test-IssueExists.ps1 validates that a given issue number exists in the current repository,
    verifies it belongs to the same repository, and checks if it's open (not closed).
    
    Results are cached in the session to avoid rate limiting when checking the same issue
    multiple times. Use -Refresh to bypass the cache and re-fetch issue data.

.PARAMETER IssueNumber
    The issue number to check. Must be a positive integer.

.PARAMETER Owner
    Repository owner (username or organization). If not provided, uses current repository.

.PARAMETER Repo
    Repository name. If not provided, uses current repository.

.PARAMETER Refresh
    Forces a re-fetch of the issue data, bypassing the session cache.

.OUTPUTS
    Returns a PSCustomObject with the following properties:
    - Exists: Boolean indicating if the issue exists
    - IsOpen: Boolean indicating if the issue is open (only meaningful if Exists is true)
    - IsSameRepository: Boolean indicating if the issue is in the same repository
    - IssueNumber: The issue number that was checked
    - State: Issue state (OPEN, CLOSED, or null if issue doesn't exist)
    - Title: Issue title (or null if issue doesn't exist)
    - Url: Issue URL (or null if issue doesn't exist)
    - RepositoryNameWithOwner: Full repository name with owner (or null if issue doesn't exist)
    - ErrorMessage: Error message if the check failed (or null if successful)

.EXAMPLE
    .\Test-IssueExists.ps1 -IssueNumber 123
    Checks if issue #123 exists, is open, and is in the current repository.

.EXAMPLE
    .\Test-IssueExists.ps1 -IssueNumber 123 -Owner "anokye-labs" -Repo "akwaaba"
    Checks if issue #123 exists in the anokye-labs/akwaaba repository.

.EXAMPLE
    .\Test-IssueExists.ps1 -IssueNumber 123 -Refresh
    Checks issue #123, forcing a fresh fetch from GitHub (bypassing cache).

.NOTES
    Requires:
    - PowerShell 7.x or higher
    - GitHub CLI (gh) installed and authenticated
    - Get-RepoContext.ps1 (for repository context)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [switch]$Refresh
)

$ErrorActionPreference = "Stop"

# Session cache for issue lookups
if (-not $script:IssueExistsCache) {
    $script:IssueExistsCache = @{}
}

# Helper function to get repository context
function Get-CurrentRepoContext {
    <#
    .SYNOPSIS
        Gets the current repository owner and name.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Getting current repository context..."
        
        # Use Get-RepoContext if available
        $repoContextScript = Join-Path $PSScriptRoot "Get-RepoContext.ps1"
        if (Test-Path $repoContextScript) {
            $context = & $repoContextScript
            if ($context -and $context.RepoId) {
                # Get current repo info to extract owner/repo
                $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
                if ($repoInfo -and $repoInfo.nameWithOwner) {
                    $parts = $repoInfo.nameWithOwner -split '/'
                    if ($parts.Length -eq 2) {
                        return @{
                            Owner = $parts[0]
                            Repo = $parts[1]
                            NameWithOwner = $repoInfo.nameWithOwner
                        }
                    }
                }
            }
        }
        
        # Fallback: use gh repo view directly
        $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
        if ($repoInfo -and $repoInfo.nameWithOwner) {
            $parts = $repoInfo.nameWithOwner -split '/'
            if ($parts.Length -eq 2) {
                return @{
                    Owner = $parts[0]
                    Repo = $parts[1]
                    NameWithOwner = $repoInfo.nameWithOwner
                }
            }
        }
        
        throw "Could not determine current repository context"
    }
    catch {
        Write-Error "Failed to get repository context: $_"
        return $null
    }
}

# Helper function to fetch issue data
function Get-IssueData {
    <#
    .SYNOPSIS
        Fetches issue data from GitHub.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$IssueNumber,
        
        [Parameter(Mandatory = $true)]
        [string]$Owner,
        
        [Parameter(Mandatory = $true)]
        [string]$Repo
    )
    
    try {
        Write-Verbose "Fetching issue ${IssueNumber} from $Owner/$Repo..."
        
        # Use gh issue view to get issue data
        $issueJson = gh issue view $IssueNumber `
            --repo "$Owner/$Repo" `
            --json number,state,title,url,repository 2>&1
        
        # Check if command failed (e.g., issue not found)
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Issue ${IssueNumber} not found or error occurred"
            return $null
        }
        
        $issue = $issueJson | ConvertFrom-Json
        
        if (-not $issue) {
            Write-Verbose "Issue ${IssueNumber} not found"
            return $null
        }
        
        Write-Verbose "Issue ${IssueNumber} found: State=$($issue.state)"
        return $issue
    }
    catch {
        Write-Verbose "Error fetching issue ${IssueNumber}: $_"
        return $null
    }
}

# Main execution
Write-Verbose "Test-IssueExists: Starting for issue ${IssueNumber}..."

# Determine target repository
$targetOwner = $Owner
$targetRepo = $Repo

if (-not $targetOwner -or -not $targetRepo) {
    Write-Verbose "Owner or Repo not specified, using current repository..."
    $currentRepo = Get-CurrentRepoContext
    
    if (-not $currentRepo) {
        Write-Error "Could not determine current repository context. Please specify -Owner and -Repo parameters."
        return [PSCustomObject]@{
            Exists = $false
            IsOpen = $false
            IsSameRepository = $false
            IssueNumber = $IssueNumber
            State = $null
            Title = $null
            Url = $null
            RepositoryNameWithOwner = $null
            ErrorMessage = "Could not determine repository context"
        }
    }
    
    if (-not $targetOwner) { $targetOwner = $currentRepo.Owner }
    if (-not $targetRepo) { $targetRepo = $currentRepo.Repo }
}

$targetRepoFullName = "$targetOwner/$targetRepo"
Write-Verbose "Target repository: $targetRepoFullName"

# Check cache
$cacheKey = "$targetRepoFullName#$IssueNumber"
if (-not $Refresh -and $script:IssueExistsCache.ContainsKey($cacheKey)) {
    Write-Verbose "Returning cached result for $cacheKey"
    return $script:IssueExistsCache[$cacheKey]
}

# Fetch issue data
$issue = Get-IssueData -IssueNumber $IssueNumber -Owner $targetOwner -Repo $targetRepo

if (-not $issue) {
    # Issue doesn't exist
    $result = [PSCustomObject]@{
        Exists = $false
        IsOpen = $false
        IsSameRepository = $false
        IssueNumber = $IssueNumber
        State = $null
        Title = $null
        Url = $null
        RepositoryNameWithOwner = $null
        ErrorMessage = "Issue ${IssueNumber} not found in $targetRepoFullName"
    }
    
    # Cache the result
    $script:IssueExistsCache[$cacheKey] = $result
    
    Write-Verbose "Issue ${IssueNumber} does not exist in $targetRepoFullName"
    return $result
}

# Issue exists - check repository and state
$issueRepoName = if ($issue.repository -and $issue.repository.nameWithOwner) {
    $issue.repository.nameWithOwner
} else {
    $targetRepoFullName  # Fallback to target repo if not provided in response
}

$isSameRepo = $issueRepoName -eq $targetRepoFullName
$isOpen = $issue.state -eq "OPEN"

$result = [PSCustomObject]@{
    Exists = $true
    IsOpen = $isOpen
    IsSameRepository = $isSameRepo
    IssueNumber = $IssueNumber
    State = $issue.state
    Title = $issue.title
    Url = $issue.url
    RepositoryNameWithOwner = $issueRepoName
    ErrorMessage = $null
}

# Cache the result
$script:IssueExistsCache[$cacheKey] = $result

Write-Verbose "Issue ${IssueNumber}: Exists=$($result.Exists), IsOpen=$($result.IsOpen), SameRepo=$($result.IsSameRepository)"

return $result
