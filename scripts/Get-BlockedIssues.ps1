<#
.SYNOPSIS
    Find issues that are stuck - open but blocked by other open issues.

.DESCRIPTION
    Get-BlockedIssues.ps1 analyzes dependency text in issue bodies, cross-references
    with issue states, and reports what is blocking each item. It suggests resolution
    order using topological sort.

    The script looks for "Blocked by:" sections in issue bodies following this format:
    - Blocked by: #123, #456
    - Blocked by: owner/repo#789

.PARAMETER Owner
    Repository owner (username or organization).

.PARAMETER Repo
    Repository name.

.PARAMETER IncludeClosed
    If specified, includes closed issues in the analysis.

.PARAMETER OutputFormat
    Output format: 'Text' (default), 'Json', or 'Summary'.

.PARAMETER CorrelationId
    Optional correlation ID for tracing operations.

.OUTPUTS
    Returns a PSCustomObject with:
    - BlockedIssues: Array of issues that are blocked by open issues
    - ResolutionOrder: Suggested order to resolve issues
    - TotalOpen: Count of total open issues analyzed
    - TotalBlocked: Count of blocked issues

.EXAMPLE
    .\Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba"
    
    Analyzes blocked issues in the anokye-labs/akwaaba repository.

.EXAMPLE
    .\Get-BlockedIssues.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputFormat Json
    
    Outputs results in JSON format.

.NOTES
    Requires:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeClosed,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Text", "Json", "Summary")]
    [string]$OutputFormat = "Text",

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Helper function to invoke Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [string]$CorrelationId
    )
    
    $scriptPath = Join-Path $PSScriptRoot "Invoke-GraphQL.ps1"
    & $scriptPath -Query $Query -Variables $Variables -CorrelationId $CorrelationId
}

# Helper function to invoke Write-OkyeremaLog.ps1
function Write-OkyeremaLogHelper {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "GetBlockedIssues",
        [string]$CorrelationId
    )
    
    $scriptPath = Join-Path $PSScriptRoot ".." ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    & $scriptPath -Message $Message -Level $Level -Operation $Operation -CorrelationId $CorrelationId
}

# Helper function to get repository context
function Get-RepoContextHelper {
    $scriptPath = Join-Path $PSScriptRoot "Get-RepoContext.ps1"
    & $scriptPath
}

# Function to extract dependencies from issue body
function Get-IssueDependencies {
    param(
        [string]$Body
    )
    
    if (-not $Body) {
        return @()
    }
    
    $dependencies = @()
    
    # Pattern to match "Blocked by:" section
    # Uses (?ms) for multiline and single-line modes
    # Matches: Blocked by: followed by issue references
    $blockedByPattern = '(?ms)(?:^|\n)##\s*Dependencies\s*\n+Blocked\s+by:\s*\n(.*?)(?=\n##|\z)'
    
    if ($Body -match $blockedByPattern) {
        $blockedBySection = $matches[1]
        
        # Extract issue references: #123, owner/repo#123, full URLs
        # Pattern matches:
        # - [ ] #123
        # - [ ] owner/repo#123
        # - [ ] https://github.com/owner/repo/issues/123
        $issuePattern = '(?:^|\s)-\s*\[[\sx]\]\s*(?:https?://github\.com/)?([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+)?#(\d+)'
        
        $matches = [regex]::Matches($blockedBySection, $issuePattern)
        
        foreach ($match in $matches) {
            $repoRef = $match.Groups[1].Value
            $issueNumber = $match.Groups[2].Value
            
            if ($repoRef) {
                # Full reference: owner/repo#123
                $dependencies += [PSCustomObject]@{
                    Repository = $repoRef
                    Number = [int]$issueNumber
                    IsExternal = $true
                }
            } else {
                # Local reference: #123
                $dependencies += [PSCustomObject]@{
                    Repository = $null
                    Number = [int]$issueNumber
                    IsExternal = $false
                }
            }
        }
    }
    
    return $dependencies
}

# Function to fetch all issues
function Get-AllIssues {
    param(
        [string]$Owner,
        [string]$Repo,
        [bool]$IncludeClosed,
        [string]$CorrelationId
    )
    
    Write-OkyeremaLogHelper -Message "Fetching issues from $Owner/$Repo" -CorrelationId $CorrelationId
    
    $states = if ($IncludeClosed) { "OPEN,CLOSED" } else { "OPEN" }
    
    $query = @"
query(`$owner: String!, `$repo: String!, `$cursor: String) {
    repository(owner: `$owner, name: `$repo) {
        issues(first: 100, after: `$cursor, orderBy: {field: CREATED_AT, direction: ASC}) {
            pageInfo {
                hasNextPage
                endCursor
            }
            nodes {
                number
                title
                state
                body
                url
                createdAt
                updatedAt
            }
        }
    }
}
"@
    
    $allIssues = @()
    $cursor = $null
    $hasNextPage = $true
    
    while ($hasNextPage) {
        $variables = @{
            owner = $Owner
            repo = $Repo
        }
        
        if ($cursor) {
            $variables.cursor = $cursor
        }
        
        $result = Invoke-GraphQLHelper -Query $query -Variables $variables -CorrelationId $CorrelationId
        
        if (-not $result.Success) {
            Write-OkyeremaLogHelper -Message "Failed to fetch issues: $($result.Errors[0].Message)" -Level "Error" -CorrelationId $CorrelationId
            throw "Failed to fetch issues from GitHub"
        }
        
        $issues = $result.Data.repository.issues.nodes
        $allIssues += $issues
        
        $pageInfo = $result.Data.repository.issues.pageInfo
        $hasNextPage = $pageInfo.hasNextPage
        $cursor = $pageInfo.endCursor
        
        Write-OkyeremaLogHelper -Message "Fetched $($issues.Count) issues (total: $($allIssues.Count))" -CorrelationId $CorrelationId
    }
    
    return $allIssues
}

# Function to analyze blocked issues
function Find-BlockedIssues {
    param(
        [array]$Issues,
        [string]$CurrentRepo
    )
    
    $blockedIssues = @()
    
    foreach ($issue in $Issues) {
        if ($issue.state -ne "OPEN") {
            continue
        }
        
        $dependencies = Get-IssueDependencies -Body $issue.body
        
        if ($dependencies.Count -eq 0) {
            continue
        }
        
        $blockingIssues = @()
        
        foreach ($dep in $dependencies) {
            if ($dep.IsExternal) {
                # External dependency - we can't check its state easily
                $blockingIssues += [PSCustomObject]@{
                    Number = $dep.Number
                    Repository = $dep.Repository
                    State = "UNKNOWN"
                    IsBlocking = $true
                }
            } else {
                # Local dependency - find it in our issues list
                $depIssue = $Issues | Where-Object { $_.number -eq $dep.Number }
                
                if ($depIssue) {
                    if ($depIssue.state -eq "OPEN") {
                        $blockingIssues += [PSCustomObject]@{
                            Number = $depIssue.number
                            Title = $depIssue.title
                            Repository = $CurrentRepo
                            State = $depIssue.state
                            IsBlocking = $true
                        }
                    }
                } else {
                    # Dependency not found - might be external or invalid
                    $blockingIssues += [PSCustomObject]@{
                        Number = $dep.Number
                        Repository = $CurrentRepo
                        State = "NOT_FOUND"
                        IsBlocking = $true
                    }
                }
            }
        }
        
        if ($blockingIssues.Count -gt 0) {
            $blockedIssues += [PSCustomObject]@{
                Number = $issue.number
                Title = $issue.title
                State = $issue.state
                Url = $issue.url
                BlockedBy = $blockingIssues
                BlockCount = $blockingIssues.Count
            }
        }
    }
    
    return $blockedIssues
}

# Function to suggest resolution order using topological sort
function Get-ResolutionOrder {
    param(
        [array]$Issues
    )
    
    # Build dependency graph
    $graph = @{}
    $inDegree = @{}
    
    # Initialize
    foreach ($issue in $Issues) {
        if ($issue.state -eq "OPEN") {
            $graph[$issue.number] = @()
            $inDegree[$issue.number] = 0
        }
    }
    
    # Build edges
    foreach ($issue in $Issues) {
        if ($issue.state -ne "OPEN") {
            continue
        }
        
        $dependencies = Get-IssueDependencies -Body $issue.body
        
        foreach ($dep in $dependencies) {
            if (-not $dep.IsExternal) {
                $depIssue = $Issues | Where-Object { $_.number -eq $dep.Number -and $_.state -eq "OPEN" }
                
                if ($depIssue) {
                    # dep.Number must be completed before issue.number
                    if (-not $graph.ContainsKey($dep.Number)) {
                        $graph[$dep.Number] = @()
                        $inDegree[$dep.Number] = 0
                    }
                    
                    $graph[$dep.Number] += $issue.number
                    $inDegree[$issue.number]++
                }
            }
        }
    }
    
    # Kahn's algorithm for topological sort
    $queue = [System.Collections.Queue]::new()
    
    # Start with nodes that have no dependencies
    foreach ($node in $inDegree.Keys) {
        if ($inDegree[$node] -eq 0) {
            $queue.Enqueue($node)
        }
    }
    
    $order = @()
    
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $order += $current
        
        foreach ($neighbor in $graph[$current]) {
            $inDegree[$neighbor]--
            
            if ($inDegree[$neighbor] -eq 0) {
                $queue.Enqueue($neighbor)
            }
        }
    }
    
    # Convert to issue objects with titles
    $orderedIssues = @()
    foreach ($num in $order) {
        $issue = $Issues | Where-Object { $_.number -eq $num }
        if ($issue) {
            $orderedIssues += [PSCustomObject]@{
                Number = $issue.number
                Title = $issue.title
                Url = $issue.url
            }
        }
    }
    
    return $orderedIssues
}

# Function to format output
function Format-Output {
    param(
        [array]$BlockedIssues,
        [array]$ResolutionOrder,
        [int]$TotalOpen,
        [string]$Format
    )
    
    $result = [PSCustomObject]@{
        BlockedIssues = $BlockedIssues
        ResolutionOrder = $ResolutionOrder
        TotalOpen = $TotalOpen
        TotalBlocked = $BlockedIssues.Count
    }
    
    if ($Format -eq "Json") {
        return $result | ConvertTo-Json -Depth 10
    }
    
    if ($Format -eq "Summary") {
        $summary = @"
## Blocked Issues Summary

Total Open Issues: $TotalOpen
Total Blocked Issues: $($BlockedIssues.Count)
Issues Ready to Work: $($ResolutionOrder.Count)

"@
        return $summary
    }
    
    # Text format (default)
    $output = @"
=== Blocked Issues Analysis ===

Total Open Issues: $TotalOpen
Total Blocked Issues: $($BlockedIssues.Count)

"@
    
    if ($BlockedIssues.Count -eq 0) {
        $output += "`nNo blocked issues found. All issues are ready to work on!`n"
    } else {
        $output += "`n--- Blocked Issues ---`n"
        
        foreach ($issue in $BlockedIssues) {
            $output += "`n#$($issue.Number): $($issue.Title)`n"
            $output += "  URL: $($issue.Url)`n"
            $output += "  Blocked by:`n"
            
            foreach ($blocker in $issue.BlockedBy) {
                if ($blocker.Repository) {
                    $output += "    - $($blocker.Repository)#$($blocker.Number)"
                } else {
                    $output += "    - #$($blocker.Number)"
                }
                
                if ($blocker.Title) {
                    $output += ": $($blocker.Title)"
                }
                
                $output += " [$($blocker.State)]`n"
            }
        }
    }
    
    if ($ResolutionOrder.Count -gt 0) {
        $output += "`n--- Suggested Resolution Order ---`n"
        $output += "(Issues with no dependencies listed first)`n`n"
        
        for ($i = 0; $i -lt $ResolutionOrder.Count; $i++) {
            $issue = $ResolutionOrder[$i]
            $output += "$($i + 1). #$($issue.Number): $($issue.Title)`n"
            $output += "   $($issue.Url)`n"
        }
    }
    
    return $output
}

# Main execution
try {
    Write-OkyeremaLogHelper -Message "Starting blocked issues analysis" -CorrelationId $CorrelationId
    
    # Get repository context if Owner/Repo not provided
    if (-not $Owner -or -not $Repo) {
        Write-OkyeremaLogHelper -Message "Fetching repository context" -CorrelationId $CorrelationId
        $context = Get-RepoContextHelper
        
        if ($context.RepoId) {
            # Parse owner/repo from context
            # This is a simplification - in reality we'd need to call gh repo view
            $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
            $parts = $repoInfo.nameWithOwner -split '/'
            $Owner = $parts[0]
            $Repo = $parts[1]
            
            Write-OkyeremaLogHelper -Message "Using repository: $Owner/$Repo" -CorrelationId $CorrelationId
        } else {
            throw "Could not determine repository context. Please specify -Owner and -Repo parameters."
        }
    }
    
    # Fetch all issues
    $issues = Get-AllIssues -Owner $Owner -Repo $Repo -IncludeClosed $IncludeClosed -CorrelationId $CorrelationId
    
    Write-OkyeremaLogHelper -Message "Analyzing $($issues.Count) issues for dependencies" -CorrelationId $CorrelationId
    
    # Find blocked issues
    $blockedIssues = Find-BlockedIssues -Issues $issues -CurrentRepo "$Owner/$Repo"
    
    Write-OkyeremaLogHelper -Message "Found $($blockedIssues.Count) blocked issues" -CorrelationId $CorrelationId
    
    # Get resolution order
    $resolutionOrder = Get-ResolutionOrder -Issues $issues
    
    Write-OkyeremaLogHelper -Message "Generated resolution order with $($resolutionOrder.Count) issues" -CorrelationId $CorrelationId
    
    # Count open issues
    $openIssues = @($issues | Where-Object { $_.state -eq "OPEN" })
    $totalOpen = $openIssues.Count
    
    # Format and output results
    $output = Format-Output -BlockedIssues $blockedIssues -ResolutionOrder $resolutionOrder -TotalOpen $totalOpen -Format $OutputFormat
    
    Write-Host $output
    
    Write-OkyeremaLogHelper -Message "Blocked issues analysis completed successfully" -CorrelationId $CorrelationId
    
    # Return structured data for pipeline use
    return [PSCustomObject]@{
        BlockedIssues = $blockedIssues
        ResolutionOrder = $resolutionOrder
        TotalOpen = $totalOpen
        TotalBlocked = $blockedIssues.Count
    }
}
catch {
    Write-OkyeremaLogHelper -Message "Error during blocked issues analysis: $_" -Level "Error" -CorrelationId $CorrelationId
    throw
}
