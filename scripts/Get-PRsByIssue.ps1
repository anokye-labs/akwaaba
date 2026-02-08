<#
.SYNOPSIS
    Find all PRs linked to specific issue(s).

.DESCRIPTION
    Get-PRsByIssue.ps1 searches for pull requests associated with one or more issues by:
    1. Searching for issue references in PR body text (e.g., "fixes #123", "closes #456")
    2. Checking branch naming convention (issue-{number}-*)
    3. Returning PR numbers, states, and review status for all matches

.PARAMETER IssueNumbers
    Array of issue numbers to search for. Can be a single number or multiple numbers.

.PARAMETER Owner
    Repository owner (username or organization). If not provided, uses current repository.

.PARAMETER Repo
    Repository name. If not provided, uses current repository.

.PARAMETER OutputFormat
    Output format: Console (colored output), Markdown (table), or Json (structured data).
    Default is Console.

.PARAMETER DryRun
    If specified, shows the queries that would be executed without running them.

.EXAMPLE
    .\Get-PRsByIssue.ps1 -IssueNumbers 14

    Finds all PRs linked to issue #14 in the current repository.

.EXAMPLE
    .\Get-PRsByIssue.ps1 -IssueNumbers 14,15,17 -OutputFormat Markdown

    Finds all PRs linked to issues #14, #15, and #17 and outputs as a Markdown table.

.EXAMPLE
    .\Get-PRsByIssue.ps1 -IssueNumbers 14 -Owner "anokye-labs" -Repo "akwaaba" -OutputFormat Json

    Finds all PRs linked to issue #14 in anokye-labs/akwaaba and outputs as JSON.

.OUTPUTS
    Returns information about PRs linked to the specified issues:
    - PR number
    - PR title
    - PR state (OPEN, CLOSED, MERGED)
    - Review decision (APPROVED, CHANGES_REQUESTED, REVIEW_REQUIRED, etc.)
    - Branch name
    - Associated issue numbers

.NOTES
    Requires:
    - PowerShell 7.x or higher
    - GitHub CLI (gh) installed and authenticated
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [int[]]$IssueNumbers,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for tracing
$correlationId = [guid]::NewGuid().ToString()

# Wrapper function for Invoke-GraphQL.ps1 to avoid parameter prompting
function Invoke-GraphQLQuery {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [switch]$DryRun,
        [string]$CorrelationId
    )
    
    $scriptPath = Join-Path $PSScriptRoot "Invoke-GraphQL.ps1"
    
    $params = @{
        Query = $Query
        Variables = $Variables
        CorrelationId = $CorrelationId
    }
    
    if ($DryRun) {
        $params.DryRun = $true
    }
    
    return & $scriptPath @params
}

# Wrapper function for Write-OkyeremaLog.ps1
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "GetPRsByIssue"
    )
    
    $scriptPath = Join-Path $PSScriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    
    & $scriptPath -Message $Message -Level $Level -Operation $Operation -CorrelationId $correlationId
}

# Get repository context if Owner/Repo not provided
if (-not $Owner -or -not $Repo) {
    Write-Log -Message "Fetching repository context..." -Level "Info"
    
    try {
        $repoInfo = & gh repo view --json owner,name | ConvertFrom-Json
        
        if (-not $Owner) {
            $Owner = $repoInfo.owner.login
        }
        if (-not $Repo) {
            $Repo = $repoInfo.name
        }
        
        Write-Log -Message "Using repository: $Owner/$Repo" -Level "Info"
    }
    catch {
        Write-Error "Failed to get repository context. Please specify -Owner and -Repo parameters or run from within a repository. Error: $_"
        exit 1
    }
}

Write-Log -Message "Searching for PRs linked to issues: $($IssueNumbers -join ', ')" -Level "Info"

# Build search queries for each issue
$allPRs = @{}  # Use hashtable to deduplicate by PR number

foreach ($issueNumber in $IssueNumbers) {
    Write-Log -Message "Processing issue #$issueNumber" -Level "Info"
    
    # Search 1: Find PRs that reference the issue in body or title
    # GitHub search syntax: "repo:owner/repo is:pr #issueNumber"
    $searchQuery = "repo:$Owner/$Repo is:pr #$issueNumber"
    
    Write-Log -Message "Searching for PRs with issue reference: $searchQuery" -Level "Debug"
    
    $query1 = @"
query(`$searchQuery: String!) {
  search(query: `$searchQuery, type: ISSUE, first: 100) {
    nodes {
      ... on PullRequest {
        number
        title
        state
        headRefName
        baseRefName
        url
        createdAt
        updatedAt
        closedAt
        mergedAt
        reviewDecision
        author {
          login
        }
        reviews(first: 10) {
          totalCount
          nodes {
            state
            author {
              login
            }
          }
        }
      }
    }
  }
}
"@
    
    $variables1 = @{
        searchQuery = $searchQuery
    }
    
    $result1 = Invoke-GraphQLQuery -Query $query1 -Variables $variables1 -DryRun:$DryRun -CorrelationId $correlationId
    
    if ($result1.Success -and $result1.Data.search.nodes) {
        foreach ($pr in $result1.Data.search.nodes) {
            if ($pr) {
                # Add to collection if not already present
                if (-not $allPRs.ContainsKey($pr.number)) {
                    $allPRs[$pr.number] = [PSCustomObject]@{
                        Number = $pr.number
                        Title = $pr.title
                        State = $pr.state
                        IsMerged = ($pr.mergedAt -ne $null)
                        ReviewDecision = $pr.reviewDecision
                        ReviewCount = $pr.reviews.totalCount
                        HeadBranch = $pr.headRefName
                        BaseBranch = $pr.baseRefName
                        Url = $pr.url
                        Author = $pr.author.login
                        CreatedAt = $pr.createdAt
                        UpdatedAt = $pr.updatedAt
                        ClosedAt = $pr.closedAt
                        MergedAt = $pr.mergedAt
                        LinkedIssues = @($issueNumber)
                        MatchReason = @("Body/Title Reference")
                    }
                }
                else {
                    # Add this issue to the linked issues list
                    if ($allPRs[$pr.number].LinkedIssues -notcontains $issueNumber) {
                        $allPRs[$pr.number].LinkedIssues += $issueNumber
                    }
                    if ($allPRs[$pr.number].MatchReason -notcontains "Body/Title Reference") {
                        $allPRs[$pr.number].MatchReason += "Body/Title Reference"
                    }
                }
            }
        }
    }
    
    # Search 2: Find PRs with branch name matching "issue-{number}-*"
    $branchPattern = "issue-$issueNumber-"
    Write-Log -Message "Searching for PRs with branch pattern: $branchPattern*" -Level "Debug"
    
    $query2 = @"
query(`$owner: String!, `$repo: String!, `$branchPattern: String!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequests(first: 100, headRefName: `$branchPattern) {
      nodes {
        number
        title
        state
        headRefName
        baseRefName
        url
        createdAt
        updatedAt
        closedAt
        mergedAt
        reviewDecision
        author {
          login
        }
        reviews(first: 10) {
          totalCount
          nodes {
            state
            author {
              login
            }
          }
        }
      }
    }
  }
}
"@
    
    $variables2 = @{
        owner = $Owner
        repo = $Repo
        branchPattern = $branchPattern
    }
    
    $result2 = Invoke-GraphQLQuery -Query $query2 -Variables $variables2 -DryRun:$DryRun -CorrelationId $correlationId
    
    if ($result2.Success -and $result2.Data.repository.pullRequests.nodes) {
        foreach ($pr in $result2.Data.repository.pullRequests.nodes) {
            if ($pr) {
                if (-not $allPRs.ContainsKey($pr.number)) {
                    $allPRs[$pr.number] = [PSCustomObject]@{
                        Number = $pr.number
                        Title = $pr.title
                        State = $pr.state
                        IsMerged = ($pr.mergedAt -ne $null)
                        ReviewDecision = $pr.reviewDecision
                        ReviewCount = $pr.reviews.totalCount
                        HeadBranch = $pr.headRefName
                        BaseBranch = $pr.baseRefName
                        Url = $pr.url
                        Author = $pr.author.login
                        CreatedAt = $pr.createdAt
                        UpdatedAt = $pr.updatedAt
                        ClosedAt = $pr.closedAt
                        MergedAt = $pr.mergedAt
                        LinkedIssues = @($issueNumber)
                        MatchReason = @("Branch Name")
                    }
                }
                else {
                    # Add this issue to the linked issues list
                    if ($allPRs[$pr.number].LinkedIssues -notcontains $issueNumber) {
                        $allPRs[$pr.number].LinkedIssues += $issueNumber
                    }
                    if ($allPRs[$pr.number].MatchReason -notcontains "Branch Name") {
                        $allPRs[$pr.number].MatchReason += "Branch Name"
                    }
                }
            }
        }
    }
}

# Convert to sorted array
$prList = $allPRs.Values | Sort-Object -Property Number -Descending

Write-Log -Message "Found $($prList.Count) PRs linked to the specified issues" -Level "Info"

# Output based on format
switch ($OutputFormat) {
    "Console" {
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Pull Requests Linked to Issues: $($IssueNumbers -join ', ')" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        if ($prList.Count -eq 0) {
            Write-Host "No pull requests found." -ForegroundColor Yellow
        }
        else {
            foreach ($pr in $prList) {
                # Determine state color
                $stateColor = switch ($pr.State) {
                    "OPEN" { "Green" }
                    "MERGED" { "Magenta" }
                    "CLOSED" { "Red" }
                    default { "White" }
                }
                
                # Determine review status
                $reviewStatus = if ($pr.IsMerged) {
                    "MERGED"
                }
                elseif ($pr.ReviewDecision) {
                    $pr.ReviewDecision
                }
                elseif ($pr.ReviewCount -gt 0) {
                    "PENDING"
                }
                else {
                    "NO REVIEWS"
                }
                
                $reviewColor = switch ($reviewStatus) {
                    "APPROVED" { "Green" }
                    "CHANGES_REQUESTED" { "Yellow" }
                    "MERGED" { "Magenta" }
                    "PENDING" { "Cyan" }
                    default { "Gray" }
                }
                
                Write-Host "PR #$($pr.Number)" -ForegroundColor White -NoNewline
                Write-Host " - " -NoNewline
                Write-Host "$($pr.State)" -ForegroundColor $stateColor -NoNewline
                Write-Host " - " -NoNewline
                Write-Host "$reviewStatus" -ForegroundColor $reviewColor
                
                Write-Host "  Title: $($pr.Title)" -ForegroundColor Gray
                Write-Host "  Branch: $($pr.HeadBranch) → $($pr.BaseBranch)" -ForegroundColor Gray
                Write-Host "  Linked Issues: #$($pr.LinkedIssues -join ', #')" -ForegroundColor Gray
                Write-Host "  Match: $($pr.MatchReason -join ', ')" -ForegroundColor DarkGray
                Write-Host "  URL: $($pr.Url)" -ForegroundColor DarkGray
                Write-Host ""
            }
            
            Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Cyan
            Write-Host "Total: $($prList.Count) pull request(s)" -ForegroundColor Cyan
            Write-Host ""
        }
    }
    
    "Markdown" {
        Write-Output "# Pull Requests Linked to Issues: $($IssueNumbers -join ', ')"
        Write-Output ""
        
        if ($prList.Count -eq 0) {
            Write-Output "No pull requests found."
        }
        else {
            Write-Output "| PR # | Title | State | Review Status | Branch | Linked Issues | Match Reason |"
            Write-Output "|------|-------|-------|---------------|--------|---------------|--------------|"
            
            foreach ($pr in $prList) {
                $reviewStatus = if ($pr.IsMerged) {
                    "MERGED"
                }
                elseif ($pr.ReviewDecision) {
                    $pr.ReviewDecision
                }
                elseif ($pr.ReviewCount -gt 0) {
                    "PENDING"
                }
                else {
                    "NO REVIEWS"
                }
                
                $issuesStr = "#$($pr.LinkedIssues -join ', #')"
                $matchStr = $pr.MatchReason -join ', '
                
                Write-Output "| [#$($pr.Number)]($($pr.Url)) | $($pr.Title) | $($pr.State) | $reviewStatus | $($pr.HeadBranch) | $issuesStr | $matchStr |"
            }
            
            Write-Output ""
            Write-Output "**Total:** $($prList.Count) pull request(s)"
        }
    }
    
    "Json" {
        $output = @{
            IssueNumbers = $IssueNumbers
            Repository = "$Owner/$Repo"
            TotalPRs = $prList.Count
            PullRequests = @($prList)
        }
        
        $output | ConvertTo-Json -Depth 10
    }
}

# Return the list for pipeline usage
return $prList
