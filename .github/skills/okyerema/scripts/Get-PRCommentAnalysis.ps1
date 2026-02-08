<#
.SYNOPSIS
    Analyze PR review comments for actionability with structured output.

.DESCRIPTION
    Get-PRCommentAnalysis.ps1 analyzes PR review comments and categorizes them by actionability.
    It builds on Get-UnresolvedThreads.ps1 to provide deeper analysis for agent consumption.
    
    Categories:
    - blocking: Must be addressed before merge (e.g., security issues, bugs)
    - suggestion: Recommended changes that improve quality
    - nitpick: Minor style or formatting suggestions
    - question: Questions requiring clarification
    - praise: Positive feedback

    Output includes:
    - Categorized comments grouped by file path
    - Unresolved thread identification
    - Summary statistics
    - Structured JSON output for agent consumption

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER OutputFormat
    Output format: Console (default), Markdown, or Json.

.PARAMETER IncludeResolved
    If set, includes resolved threads in the analysis.

.EXAMPLE
    .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

.EXAMPLE
    .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -OutputFormat Json

.EXAMPLE
    .\Get-PRCommentAnalysis.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeResolved -OutputFormat Markdown

.NOTES
    Dependencies:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
    - Get-UnresolvedThreads.ps1 (for comparison and validation)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $true)]
    [int]$PullNumber,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Markdown", "Json")]
    [string]$OutputFormat = "Console",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeResolved
)

$ErrorActionPreference = "Stop"

# Helper function to wrap Write-OkyeremaLog calls
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "PRCommentAnalysis"
    )
    
    $logScript = Join-Path $PSScriptRoot "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation $Operation
    }
}

# Helper function to wrap Invoke-GraphQL calls
function Invoke-GraphQLQuery {
    param(
        [string]$Query,
        [hashtable]$Variables = @{}
    )
    
    $graphQLScript = Join-Path (Split-Path $PSScriptRoot -Parent) "../../scripts/Invoke-GraphQL.ps1"
    if (Test-Path $graphQLScript) {
        return & $graphQLScript -Query $Query -Variables $Variables
    }
    else {
        throw "Invoke-GraphQL.ps1 not found at $graphQLScript"
    }
}

# Function to categorize a comment based on its content
function Get-CommentCategory {
    param([string]$Body)
    
    $bodyLower = $Body.ToLower()
    
    # Check for suggestion/consider phrases first to avoid false blocking categorization
    # e.g., "Consider adding error handling" should be suggestion, not blocking
    $suggestivePhrase = $bodyLower -match '\b(consider|suggest|recommend|could|should|would|might)\b.*\b(error|bug|fail)'
    
    # Blocking indicators (highest priority) - but not if it's a suggestion
    if (-not $suggestivePhrase) {
        $blockingPatterns = @(
            '\b(security|vulnerability|exploit|injection)\b',
            '\b(critical|blocker|blocking|must fix)\b',
            '\b(breaks?|broken|this is a bug|has a bug|causes?\s+(a\s+)?(crash|error))\b',
            '\b(required|mandatory)\b',
            '\b(test\s+)?(fails?|failed|failure)\b'
        )
        
        foreach ($pattern in $blockingPatterns) {
            if ($bodyLower -match $pattern) {
                return "blocking"
            }
        }
    }
    
    # Question indicators
    $questionPatterns = @(
        '\?',
        '\b(why|how|what|when|where|which|could you|can you|would you)\b',
        '\b(explain|clarify|clarification)\b'
    )
    
    foreach ($pattern in $questionPatterns) {
        if ($bodyLower -match $pattern) {
            return "question"
        }
    }
    
    # Praise indicators
    $praisePatterns = @(
        '\b(nice|good|great|excellent|perfect|love|awesome|fantastic)\b',
        '\b(thank|thanks|lgtm|looks good)\b',
        '👍|❤️|🎉|✨|💯',
        '\b(well done|good job)\b'
    )
    
    foreach ($pattern in $praisePatterns) {
        if ($bodyLower -match $pattern) {
            return "praise"
        }
    }
    
    # Nitpick indicators
    $nitpickPatterns = @(
        '\b(nit|nitpick|minor|small|tiny)\b',
        '\b(style|formatting|whitespace|spacing)\b',
        '\b(typo|spelling)\b',
        '\boptional\b'
    )
    
    foreach ($pattern in $nitpickPatterns) {
        if ($bodyLower -match $pattern) {
            return "nitpick"
        }
    }
    
    # Suggestion indicators (default for most comments)
    $suggestionPatterns = @(
        '\b(suggest|recommend|could|should|would|might)\b',
        '\b(improve|better|consider|instead)\b',
        '\b(refactor|simplify|optimize)\b'
    )
    
    foreach ($pattern in $suggestionPatterns) {
        if ($bodyLower -match $pattern) {
            return "suggestion"
        }
    }
    
    # Default to suggestion if no clear category
    return "suggestion"
}

# Function to analyze threads and comments
function Get-ThreadAnalysis {
    param($Threads)
    
    $analysis = @{
        TotalThreads = $Threads.Count
        UnresolvedThreads = 0
        ByCategory = @{
            blocking = @()
            suggestion = @()
            nitpick = @()
            question = @()
            praise = @()
        }
        ByFile = @{}
        Summary = @{
            blocking = 0
            suggestion = 0
            nitpick = 0
            question = 0
            praise = 0
        }
    }
    
    foreach ($thread in $Threads) {
        if (-not $thread.isResolved) {
            $analysis.UnresolvedThreads++
        }
        
        # Get the first comment (usually the main review comment)
        $firstComment = $thread.comments.nodes[0]
        $category = Get-CommentCategory -Body $firstComment.body
        
        # Create comment object
        $commentObj = [PSCustomObject]@{
            ThreadId = $thread.id
            FilePath = $thread.path
            Line = $thread.line
            Author = $firstComment.author.login
            Body = $firstComment.body
            CreatedAt = $firstComment.createdAt
            Url = $firstComment.url
            IsResolved = $thread.isResolved
            IsOutdated = $thread.isOutdated
            IsCollapsed = $thread.isCollapsed
            Category = $category
            CommentCount = $thread.comments.totalCount
            AllComments = $thread.comments.nodes
        }
        
        # Add to category
        $analysis.ByCategory[$category] += $commentObj
        $analysis.Summary[$category]++
        
        # Group by file
        if (-not $analysis.ByFile.ContainsKey($thread.path)) {
            $analysis.ByFile[$thread.path] = @()
        }
        $analysis.ByFile[$thread.path] += $commentObj
    }
    
    return $analysis
}

# Function to format output as Console
function Format-ConsoleOutput {
    param($Analysis, $Owner, $Repo, $PullNumber)
    
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " PR Comment Analysis: $Owner/$Repo #$PullNumber" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    # Summary statistics
    Write-Host "Summary:" -ForegroundColor White
    Write-Host "  Total Threads:     $($Analysis.TotalThreads)" -ForegroundColor Gray
    Write-Host "  Unresolved:        $($Analysis.UnresolvedThreads)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "By Category:" -ForegroundColor White
    Write-Host "  🚫 Blocking:       $($Analysis.Summary.blocking)" -ForegroundColor Red
    Write-Host "  💡 Suggestions:    $($Analysis.Summary.suggestion)" -ForegroundColor Cyan
    Write-Host "  🔍 Nitpicks:       $($Analysis.Summary.nitpick)" -ForegroundColor DarkGray
    Write-Host "  ❓ Questions:      $($Analysis.Summary.question)" -ForegroundColor Magenta
    Write-Host "  👍 Praise:         $($Analysis.Summary.praise)" -ForegroundColor Green
    Write-Host ""
    
    # Display by category
    $categoryOrder = @("blocking", "suggestion", "question", "nitpick", "praise")
    $categoryIcons = @{
        blocking = "🚫"
        suggestion = "💡"
        nitpick = "🔍"
        question = "❓"
        praise = "👍"
    }
    $categoryColors = @{
        blocking = "Red"
        suggestion = "Cyan"
        nitpick = "DarkGray"
        question = "Magenta"
        praise = "Green"
    }
    
    foreach ($category in $categoryOrder) {
        $comments = $Analysis.ByCategory[$category]
        if ($comments.Count -gt 0) {
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            $icon = $categoryIcons[$category]
            $color = $categoryColors[$category]
            Write-Host "$icon $($category.ToUpper()) ($($comments.Count))" -ForegroundColor $color
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host ""
            
            foreach ($comment in $comments) {
                $status = if ($comment.IsResolved) { "[✓]" } else { "[•]" }
                $statusColor = if ($comment.IsResolved) { "Green" } else { "Yellow" }
                
                Write-Host "  $status " -ForegroundColor $statusColor -NoNewline
                Write-Host "$($comment.FilePath):$($comment.Line)" -ForegroundColor White
                Write-Host "      @$($comment.Author)" -ForegroundColor Gray -NoNewline
                if ($comment.IsOutdated) {
                    Write-Host " (outdated)" -ForegroundColor DarkGray -NoNewline
                }
                Write-Host ""
                
                # Show preview (first 3 lines)
                $bodyLines = $comment.Body -split "`n" | Select-Object -First 3
                foreach ($line in $bodyLines) {
                    Write-Host "      $line" -ForegroundColor Gray
                }
                if (($comment.Body -split "`n").Count -gt 3) {
                    Write-Host "      ... (truncated)" -ForegroundColor DarkGray
                }
                Write-Host ""
            }
        }
    }
    
    # Files with most comments
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "FILES WITH COMMENTS" -ForegroundColor White
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    $filesSorted = $Analysis.ByFile.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending
    foreach ($fileEntry in $filesSorted) {
        $filePath = $fileEntry.Key
        $fileComments = $fileEntry.Value
        $unresolvedCount = ($fileComments | Where-Object { -not $_.IsResolved }).Count
        
        Write-Host "  $filePath" -ForegroundColor White
        Write-Host "    Total: $($fileComments.Count), Unresolved: $unresolvedCount" -ForegroundColor Gray
        
        # Show category breakdown for this file
        $fileCategories = $fileComments | Group-Object Category | Sort-Object Count -Descending
        $categorySummary = ($fileCategories | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ", "
        Write-Host "    Categories: $categorySummary" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Function to format output as Markdown
function Format-MarkdownOutput {
    param($Analysis, $Owner, $Repo, $PullNumber)
    
    $md = @()
    $md += "# PR Comment Analysis: $Owner/$Repo #$PullNumber"
    $md += ""
    $md += "## Summary"
    $md += ""
    $md += "| Metric | Count |"
    $md += "|--------|-------|"
    $md += "| Total Threads | $($Analysis.TotalThreads) |"
    $md += "| Unresolved | $($Analysis.UnresolvedThreads) |"
    $md += ""
    $md += "## By Category"
    $md += ""
    $md += "| Category | Count |"
    $md += "|----------|-------|"
    $md += "| 🚫 Blocking | $($Analysis.Summary.blocking) |"
    $md += "| 💡 Suggestion | $($Analysis.Summary.suggestion) |"
    $md += "| 🔍 Nitpick | $($Analysis.Summary.nitpick) |"
    $md += "| ❓ Question | $($Analysis.Summary.question) |"
    $md += "| 👍 Praise | $($Analysis.Summary.praise) |"
    $md += ""
    
    # By category details
    $categoryOrder = @("blocking", "suggestion", "question", "nitpick", "praise")
    $categoryIcons = @{
        blocking = "🚫"
        suggestion = "💡"
        nitpick = "🔍"
        question = "❓"
        praise = "👍"
    }
    
    foreach ($category in $categoryOrder) {
        $comments = $Analysis.ByCategory[$category]
        if ($comments.Count -gt 0) {
            $icon = $categoryIcons[$category]
            $md += "## $icon $($category.ToUpper()) ($($comments.Count))"
            $md += ""
            
            foreach ($comment in $comments) {
                $status = if ($comment.IsResolved) { "✓" } else { "•" }
                $outdated = if ($comment.IsOutdated) { " _(outdated)_" } else { "" }
                $md += "### $status $($comment.FilePath):$($comment.Line)$outdated"
                $md += ""
                $md += "**@$($comment.Author)**"
                $md += ""
                $md += "```"
                $md += $comment.Body
                $md += "```"
                $md += ""
            }
        }
    }
    
    # Files with comments
    $md += "## Files with Comments"
    $md += ""
    $md += "| File | Total | Unresolved | Categories |"
    $md += "|------|-------|------------|------------|"
    
    $filesSorted = $Analysis.ByFile.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending
    foreach ($fileEntry in $filesSorted) {
        $filePath = $fileEntry.Key
        $fileComments = $fileEntry.Value
        $unresolvedCount = ($fileComments | Where-Object { -not $_.IsResolved }).Count
        
        $fileCategories = $fileComments | Group-Object Category | Sort-Object Count -Descending
        $categorySummary = ($fileCategories | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ", "
        
        $md += "| $filePath | $($fileComments.Count) | $unresolvedCount | $categorySummary |"
    }
    
    return $md -join "`n"
}

# Function to format output as JSON
function Format-JsonOutput {
    param($Analysis, $Owner, $Repo, $PullNumber)
    
    $jsonObj = [ordered]@{
        repository = @{
            owner = $Owner
            name = $Repo
            pullRequest = $PullNumber
        }
        summary = @{
            totalThreads = $Analysis.TotalThreads
            unresolvedThreads = $Analysis.UnresolvedThreads
            byCategory = $Analysis.Summary
        }
        categories = @{
            blocking = @($Analysis.ByCategory.blocking)
            suggestion = @($Analysis.ByCategory.suggestion)
            nitpick = @($Analysis.ByCategory.nitpick)
            question = @($Analysis.ByCategory.question)
            praise = @($Analysis.ByCategory.praise)
        }
        byFile = @{}
    }
    
    # Convert hashtable to ordered for JSON
    foreach ($fileEntry in $Analysis.ByFile.GetEnumerator()) {
        $jsonObj.byFile[$fileEntry.Key] = @($fileEntry.Value)
    }
    
    return $jsonObj | ConvertTo-Json -Depth 10
}

# Main execution
Write-Log -Message "Starting PR comment analysis for $Owner/$Repo #$PullNumber" -Level Info

# Build GraphQL query to fetch review threads
$query = @"
query(`$owner: String!, `$repo: String!, `$pullNumber: Int!) {
  repository(owner: `$owner, name: `$repo) {
    pullRequest(number: `$pullNumber) {
      reviewThreads(first: 100) {
        totalCount
        nodes {
          id
          isResolved
          isOutdated
          isCollapsed
          path
          line
          comments(first: 10) {
            totalCount
            nodes {
              author { login }
              body
              createdAt
              url
            }
          }
        }
      }
    }
  }
}
"@

$variables = @{
    owner = $Owner
    repo = $Repo
    pullNumber = $PullNumber
}

Write-Log -Message "Fetching review threads from GitHub" -Level Info

try {
    $result = Invoke-GraphQLQuery -Query $query -Variables $variables
    
    if (-not $result.Success) {
        Write-Log -Message "GraphQL query failed: $($result.Errors | ConvertTo-Json)" -Level Error
        throw "Failed to fetch PR review threads: $($result.Errors[0].Message)"
    }
    
    $threads = $result.Data.repository.pullRequest.reviewThreads.nodes
    $totalCount = $result.Data.repository.pullRequest.reviewThreads.totalCount
    
    Write-Log -Message "Retrieved $($threads.Count) threads (total: $totalCount)" -Level Info
    
    # Filter threads if needed
    if (-not $IncludeResolved) {
        $threads = $threads | Where-Object { -not $_.isResolved }
        Write-Log -Message "Filtered to $($threads.Count) unresolved threads" -Level Info
    }
    
    # Analyze threads
    Write-Log -Message "Analyzing threads and categorizing comments" -Level Info
    $analysis = Get-ThreadAnalysis -Threads $threads
    
    Write-Log -Message "Analysis complete: $($analysis.Summary.blocking) blocking, $($analysis.Summary.suggestion) suggestions, $($analysis.Summary.question) questions" -Level Info
    
    # Output based on format
    switch ($OutputFormat) {
        "Console" {
            Format-ConsoleOutput -Analysis $analysis -Owner $Owner -Repo $Repo -PullNumber $PullNumber
        }
        "Markdown" {
            $markdown = Format-MarkdownOutput -Analysis $analysis -Owner $Owner -Repo $Repo -PullNumber $PullNumber
            Write-Output $markdown
        }
        "Json" {
            $json = Format-JsonOutput -Analysis $analysis -Owner $Owner -Repo $Repo -PullNumber $PullNumber
            Write-Output $json
        }
    }
    
    Write-Log -Message "PR comment analysis completed successfully" -Level Info
}
catch {
    Write-Log -Message "Error during PR comment analysis: $_" -Level Error
    throw
}
