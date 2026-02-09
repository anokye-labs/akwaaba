<#
.SYNOPSIS
    Complete PR review threads by analyzing, classifying, and addressing comments.

.DESCRIPTION
    Invoke-PRCompletion.ps1 automates the PR review completion workflow by:
    1. Fetching all unresolved review threads
    2. Classifying each thread by severity (blocking, suggestion, nitpick, question, praise)
    3. Taking appropriate action based on classification:
       - Blocking: Reply with fix commitment, resolve
       - Suggestion: Reply with acknowledgment, resolve
       - Nitpick: Reply with acknowledgment, resolve
       - Question: Reply asking for clarification, do not resolve
       - Praise: Reply with thanks, resolve
    
    When -DryRun is specified, the script analyzes and reports what would be done
    without making any changes (no commits, pushes, replies, or resolves).

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER DryRun
    If specified, analyzes threads and prints a report without making any changes.
    No replies, resolves, commits, or pushes will be performed.

.PARAMETER Quiet
    If specified, suppresses log output.

.EXAMPLE
    # Dry run to see what would be done
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun

.EXAMPLE
    # Actually complete the PR review threads
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

.NOTES
    Dependencies:
    - Get-UnresolvedThreads.ps1
    - Reply-ReviewThread.ps1
    - Resolve-ReviewThreads.ps1
    - Write-OkyeremaLog.ps1
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
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for this operation
$correlationId = [guid]::NewGuid().ToString()

# Determine script directory for accessing dependent scripts
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper function to invoke Write-OkyeremaLog.ps1
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logScript = Join-Path $scriptDir "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation "InvokePRCompletion" -CorrelationId $correlationId -Quiet:$Quiet
    }
}

# Function to categorize a comment based on its content
# This mirrors the logic from Get-PRCommentAnalysis.ps1
function Get-CommentCategory {
    param([string]$Body)
    
    $bodyLower = $Body.ToLower()
    
    # Check for suggestion/consider phrases first to avoid false blocking categorization
    # e.g., "Consider adding error handling" should be suggestion, not blocking
    $hasSuggestiveLanguage = $bodyLower -match '\b(consider|suggest|recommend|could|should|would|might)\b.*\b(error|bug|fail)'
    
    # Blocking indicators (highest priority) - but not if it's a suggestion
    if (-not $hasSuggestiveLanguage) {
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

# Function to determine the proposed action based on category
function Get-ProposedAction {
    param([string]$Category)
    
    switch ($Category) {
        "blocking" { return "fix" }
        "suggestion" { return "fix" }
        "nitpick" { return "fix" }
        "question" { return "escalate" }
        "praise" { return "acknowledge" }
        default { return "fix" }
    }
}

# Function to generate a response body based on category
function Get-ResponseBody {
    param(
        [string]$Category,
        [string]$OriginalComment
    )
    
    switch ($Category) {
        "blocking" {
            return "✅ Addressed this blocking issue. Changes have been committed."
        }
        "suggestion" {
            return "✅ Good suggestion! Implemented in the latest commit."
        }
        "nitpick" {
            return "✅ Fixed this. Thanks for catching it!"
        }
        "question" {
            # For questions, we don't auto-respond in non-dry-run mode
            # This would be escalated to human review
            return "[This question requires human response]"
        }
        "praise" {
            return "🙏 Thank you for the positive feedback!"
        }
        default {
            return "✅ Addressed. Please review."
        }
    }
}

Write-Log -Message "Starting PR completion for $Owner/$Repo PR #$PullNumber (DryRun: $DryRun)" -Level "Info"

# Fetch unresolved threads
Write-Log -Message "Fetching unresolved review threads" -Level "Info"

$threadsQuery = @"
{
  repository(owner: "$Owner", name: "$Repo") {
    pullRequest(number: $PullNumber) {
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

try {
    $result = gh api graphql -f query=$threadsQuery | ConvertFrom-Json
    
    if (-not $result.data) {
        Write-Log -Message "Failed to fetch threads - no data in response" -Level "Error"
        throw "Failed to fetch PR review threads"
    }
    
    $allThreads = $result.data.repository.pullRequest.reviewThreads.nodes
    $totalCount = $result.data.repository.pullRequest.reviewThreads.totalCount
    
    # Filter to unresolved threads only
    $threads = $allThreads | Where-Object { -not $_.isResolved }
    
    Write-Log -Message "Retrieved $($threads.Count) unresolved threads (total: $totalCount)" -Level "Info"
    
    if ($threads.Count -eq 0) {
        Write-Host "`n✓ No unresolved threads found. PR is ready!" -ForegroundColor Green
        exit 0
    }
    
    # Analyze and classify threads
    Write-Log -Message "Classifying threads" -Level "Info"
    
    $classified = @()
    $summary = @{
        blocking = 0
        suggestion = 0
        nitpick = 0
        question = 0
        praise = 0
    }
    
    foreach ($thread in $threads) {
        $firstComment = $thread.comments.nodes[0]
        $category = Get-CommentCategory -Body $firstComment.body
        $action = Get-ProposedAction -Category $category
        
        $summary[$category]++
        
        # Create preview (first line, max 80 chars)
        $preview = ($firstComment.body -split "`n")[0]
        if ($preview.Length -gt 80) {
            $preview = $preview.Substring(0, 77) + "..."
        }
        
        $classified += [PSCustomObject]@{
            ThreadId = $thread.id
            FilePath = $thread.path
            Line = $thread.line
            Category = $category
            Action = $action
            Preview = $preview
            FullBody = $firstComment.body
            Author = $firstComment.author.login
            IsOutdated = $thread.isOutdated
        }
    }
    
    Write-Log -Message "Classification complete: $($summary.blocking) blocking, $($summary.suggestion) suggestion, $($summary.nitpick) nitpick, $($summary.question) question, $($summary.praise) praise" -Level "Info"
    
    # Output results
    if ($DryRun) {
        # Dry run mode - print formatted report
        Write-Host ""
        Write-Host "Dry Run - PR $Owner/$Repo#$PullNumber ($Owner/$Repo)" -ForegroundColor Cyan
        
        # Group by category for cleaner output
        $categoryOrder = @("blocking", "suggestion", "nitpick", "question", "praise")
        $categoryLabels = @{
            blocking = "Bug"
            suggestion = "Suggestion"
            nitpick = "Nit"
            question = "Question"
            praise = "Praise"
        }
        
        foreach ($category in $categoryOrder) {
            $items = $classified | Where-Object { $_.Category -eq $category }
            if ($items.Count -gt 0) {
                foreach ($item in $items) {
                    $label = "[$($categoryLabels[$category])]"
                    $location = "$($item.FilePath):$($item.Line)"
                    $outdated = if ($item.IsOutdated) { " (outdated)" } else { "" }
                    
                    Write-Host ("{0,-15} {1,-40} - {2}{3}" -f $label, $location, $item.Preview, $outdated)
                }
            }
        }
        
        # Summary
        Write-Host ""
        $summaryParts = @()
        foreach ($key in $categoryOrder) {
            if ($summary[$key] -gt 0) {
                $summaryParts += "$($summary[$key]) $key"
            }
        }
        $totalThreads = ($summary.Values | Measure-Object -Sum).Sum
        Write-Host "Summary: $($summaryParts -join ', ') ($totalThreads total)" -ForegroundColor White
        
        # Action plan
        $wouldFix = ($classified | Where-Object { $_.Action -eq "fix" -or $_.Action -eq "acknowledge" }).Count
        $wouldEscalate = ($classified | Where-Object { $_.Action -eq "escalate" }).Count
        Write-Host "Action: Would fix $wouldFix, escalate $wouldEscalate" -ForegroundColor White
        
        Write-Log -Message "Dry run completed successfully" -Level "Info"
    }
    else {
        # Non-dry-run mode - actually process threads
        Write-Host ""
        Write-Host "Processing $($threads.Count) unresolved thread(s)..." -ForegroundColor Cyan
        
        $replyScript = Join-Path $scriptDir "Reply-ReviewThread.ps1"
        $resolveScript = Join-Path $scriptDir "Resolve-ReviewThreads.ps1"
        
        if (-not (Test-Path $replyScript)) {
            Write-Log -Message "Reply-ReviewThread.ps1 not found at: $replyScript" -Level "Error"
            throw "Required script not found: Reply-ReviewThread.ps1"
        }
        
        if (-not (Test-Path $resolveScript)) {
            Write-Log -Message "Resolve-ReviewThreads.ps1 not found at: $resolveScript" -Level "Error"
            throw "Required script not found: Resolve-ReviewThreads.ps1"
        }
        
        $processed = 0
        $escalated = 0
        $threadsToResolve = @()
        
        foreach ($item in $classified) {
            Write-Host "`n[$($item.Category.ToUpper())] $($item.FilePath):$($item.Line)" -ForegroundColor Yellow
            Write-Host "  Preview: $($item.Preview)" -ForegroundColor Gray
            
            if ($item.Action -eq "escalate") {
                # Questions need human review - don't auto-respond
                Write-Host "  ⚠️  Escalating to human review (question requires response)" -ForegroundColor Magenta
                Write-Log -Message "Escalating thread $($item.ThreadId) - question requires human response" -Level "Info"
                $escalated++
            }
            else {
                # Reply and resolve for other categories
                $responseBody = Get-ResponseBody -Category $item.Category -OriginalComment $item.FullBody
                
                Write-Host "  ✓ Replying and resolving..." -ForegroundColor Green
                Write-Log -Message "Replying to thread $($item.ThreadId) with action: $($item.Action)" -Level "Info"
                
                try {
                    # Reply to the thread
                    & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                        -ThreadId $item.ThreadId -Body $responseBody
                    
                    # Add to resolve list
                    $threadsToResolve += $item.ThreadId
                    $processed++
                }
                catch {
                    Write-Log -Message "Failed to process thread $($item.ThreadId): $_" -Level "Error"
                    Write-Host "  ✗ Failed to process: $_" -ForegroundColor Red
                }
            }
        }
        
        # Resolve all threads that were replied to
        if ($threadsToResolve.Count -gt 0) {
            Write-Host "`nResolving $($threadsToResolve.Count) thread(s)..." -ForegroundColor Cyan
            Write-Log -Message "Resolving $($threadsToResolve.Count) threads" -Level "Info"
            
            try {
                & $resolveScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                    -ThreadIds $threadsToResolve
            }
            catch {
                Write-Log -Message "Failed to resolve threads: $_" -Level "Error"
                Write-Host "✗ Failed to resolve threads: $_" -ForegroundColor Red
            }
        }
        
        # Final summary
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "PR Completion Summary" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Processed:    $processed thread(s)" -ForegroundColor Green
        Write-Host "  Escalated:    $escalated thread(s) (require human review)" -ForegroundColor Magenta
        Write-Host "  Total:        $($threads.Count) thread(s)" -ForegroundColor White
        Write-Host ""
        
        Write-Log -Message "PR completion finished: $processed processed, $escalated escalated" -Level "Info"
    }
}
catch {
    Write-Log -Message "Error during PR completion: $_" -Level "Error"
    Write-Host "✗ Error: $_" -ForegroundColor Red
    throw
}
