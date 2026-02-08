<#
.SYNOPSIS
    Orchestrate PR completion with review-fix-push-resolve cycle.

.DESCRIPTION
    Main orchestration script that manages the PR completion lifecycle:
    1. Fetch unresolved review threads
    2. Classify each thread by severity
    3. Report findings
    4. Detect git changes (agent makes fixes)
    5. Commit with iteration-numbered message
    6. Push to PR branch
    7. Reply to addressed threads with commit SHA
    8. Resolve addressed threads
    9. Wait for reviewers
    10. Loop until clean or max iterations

.PARAMETER Owner
    Repository owner (org or user).

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER MaxIterations
    Maximum number of review-fix cycles. Default: 5.

.PARAMETER ReviewWaitSeconds
    Seconds to wait for reviewers after push. Default: 90.

.PARAMETER DryRun
    If set, report only without making changes.

.PARAMETER AutoFixScope
    What to auto-fix: All or BugsOnly. Default: All.

.PARAMETER WorkingDirectory
    Local clone path. Defaults to current directory.

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun -MaxIterations 3

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -AutoFixScope BugsOnly

.OUTPUTS
    PSCustomObject with:
    - Status: Clean/Partial/Failed
    - Iterations: Number of cycles completed
    - TotalFixed: Total threads resolved
    - TotalSkipped: Total threads skipped
    - Remaining: Unresolved thread count
    - CommitShas: Array of commit SHAs created

.NOTES
    Dependencies:
    - Get-UnresolvedThreads.ps1
    - Reply-ReviewThread.ps1
    - Resolve-ReviewThreads.ps1
    - Get-ThreadSeverity.ps1 (optional, falls back to simple classification)
    - Write-OkyeremaLog.ps1 (optional)
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
    [int]$MaxIterations = 5,

    [Parameter(Mandatory = $false)]
    [int]$ReviewWaitSeconds = 90,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "BugsOnly")]
    [string]$AutoFixScope = "All",

    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = ""
)

$ErrorActionPreference = "Stop"
$OperationName = "PRCompletion"

# Set working directory
if ($WorkingDirectory) {
    if (-not (Test-Path $WorkingDirectory)) {
        throw "WorkingDirectory does not exist: $WorkingDirectory"
    }
    Push-Location $WorkingDirectory
}

try {
    # Helper: Write log
    function Write-Log {
        param(
            [string]$Message,
            [string]$Level = "Info"
        )
        
        $logScript = Join-Path $PSScriptRoot "Write-OkyeremaLog.ps1"
        if (Test-Path $logScript) {
            & $logScript -Message $Message -Level $Level -Operation $OperationName
        }
        
        # Also write to console for visibility
        $color = switch ($Level) {
            "Error" { "Red" }
            "Warn" { "Yellow" }
            "Debug" { "Gray" }
            default { "White" }
        }
        Write-Host "[$Level] $Message" -ForegroundColor $color
    }

    # Helper: Classify thread severity (fallback if Get-ThreadSeverity.ps1 not available)
    function Get-ThreadClassification {
        param($Thread)
        
        $severityScript = Join-Path $PSScriptRoot "Get-ThreadSeverity.ps1"
        if (Test-Path $severityScript) {
            # Use the real script if available
            $result = & $severityScript -Thread $Thread
            return $result
        }
        
        # Fallback: Simple classification based on comment content
        $firstComment = $Thread.comments.nodes[0].body
        $lowerComment = $firstComment.ToLower()
        
        # Look for blocking keywords
        $blockingKeywords = @("security", "vulnerability", "bug", "error", "broken", "crash", "fail")
        $isBlocking = $false
        foreach ($keyword in $blockingKeywords) {
            if ($lowerComment -like "*$keyword*") {
                $isBlocking = $true
                break
            }
        }
        
        # Look for suggestion keywords
        $suggestionKeywords = @("suggest", "recommend", "consider", "could", "should", "might")
        $isSuggestion = $false
        foreach ($keyword in $suggestionKeywords) {
            if ($lowerComment -like "*$keyword*") {
                $isSuggestion = $true
                break
            }
        }
        
        # Look for question keywords
        $questionKeywords = @("?", "why", "how", "what", "clarify", "explain")
        $isQuestion = $false
        foreach ($keyword in $questionKeywords) {
            if ($lowerComment -like "*$keyword*") {
                $isQuestion = $true
                break
            }
        }
        
        # Classify
        $severity = if ($isBlocking) { "blocking" }
                   elseif ($isSuggestion) { "suggestion" }
                   elseif ($isQuestion) { "question" }
                   else { "nitpick" }
        
        $fixable = $severity -in @("blocking", "suggestion")
        if ($AutoFixScope -eq "BugsOnly") {
            $fixable = $severity -eq "blocking"
        }
        
        return [PSCustomObject]@{
            ThreadId = $Thread.id
            Severity = $severity
            Fixable = $fixable
            Path = $Thread.path
            Line = $Thread.line
            IsOutdated = $Thread.isOutdated
        }
    }

    # Helper: Get current git status
    function Get-GitChanges {
        $status = git --no-pager status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git status failed: $status" -Level "Error"
            return @()
        }
        return $status
    }

    # Helper: Get current commit SHA
    function Get-CurrentCommitSha {
        $sha = git --no-pager rev-parse HEAD 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git rev-parse failed: $sha" -Level "Error"
            return $null
        }
        return $sha.Trim()
    }

    # Helper: Get short commit SHA
    function Get-ShortCommitSha {
        param([string]$Sha)
        return $Sha.Substring(0, [Math]::Min(7, $Sha.Length))
    }

    # Helper: Commit and push changes
    function Invoke-CommitAndPush {
        param(
            [int]$Iteration,
            [array]$AddressedThreads
        )
        
        if ($DryRun) {
            Write-Log "DryRun: Would commit and push changes for iteration $Iteration" -Level "Info"
            return "dry-run-sha-$Iteration"
        }
        
        # Stage all changes
        git add . 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to stage changes"
        }
        
        # Commit with iteration-numbered message
        $threadCount = $AddressedThreads.Count
        $commitMsg = "PR review fixes - iteration $Iteration ($threadCount threads addressed)"
        git commit -m $commitMsg 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to commit changes"
        }
        
        $commitSha = Get-CurrentCommitSha
        Write-Log "Committed changes: $commitSha" -Level "Info"
        
        # Push to PR branch
        git push 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push changes"
        }
        
        Write-Log "Pushed commit $commitSha" -Level "Info"
        return $commitSha
    }

    # Helper: Reply to threads with commit info
    function Invoke-ReplyToThreads {
        param(
            [array]$Threads,
            [string]$CommitSha
        )
        
        if ($DryRun) {
            Write-Log "DryRun: Would reply to $($Threads.Count) threads with commit $CommitSha" -Level "Info"
            return
        }
        
        $replyScript = Join-Path $PSScriptRoot "Reply-ReviewThread.ps1"
        if (-not (Test-Path $replyScript)) {
            Write-Log "Reply-ReviewThread.ps1 not found, skipping replies" -Level "Warn"
            return
        }
        
        $shortSha = Get-ShortCommitSha -Sha $CommitSha
        foreach ($thread in $Threads) {
            $body = "Addressed in commit $shortSha"
            
            try {
                & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                    -ThreadId $thread.ThreadId -Body $body -ErrorAction Stop 2>&1 | Out-Null
                Write-Log "Replied to thread $($thread.ThreadId)" -Level "Info"
            }
            catch {
                Write-Log "Failed to reply to thread $($thread.ThreadId): $_" -Level "Warn"
            }
        }
    }

    # Helper: Resolve threads
    function Invoke-ResolveThreads {
        param([array]$ThreadIds)
        
        if ($DryRun) {
            Write-Log "DryRun: Would resolve $($ThreadIds.Count) threads" -Level "Info"
            return
        }
        
        if ($ThreadIds.Count -eq 0) {
            return
        }
        
        $resolveScript = Join-Path $PSScriptRoot "Resolve-ReviewThreads.ps1"
        if (-not (Test-Path $resolveScript)) {
            Write-Log "Resolve-ReviewThreads.ps1 not found, skipping resolution" -Level "Warn"
            return
        }
        
        try {
            & $resolveScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                -ThreadIds $ThreadIds -ErrorAction Stop 2>&1 | Out-Null
            Write-Log "Resolved $($ThreadIds.Count) threads" -Level "Info"
        }
        catch {
            Write-Log "Failed to resolve threads: $_" -Level "Warn"
        }
    }

    # Helper: Get unresolved threads with retry
    function Get-UnresolvedThreadsWithRetry {
        $getThreadsScript = Join-Path $PSScriptRoot "Get-UnresolvedThreads.ps1"
        if (-not (Test-Path $getThreadsScript)) {
            throw "Get-UnresolvedThreads.ps1 not found at $getThreadsScript"
        }
        
        $maxRetries = 1
        $attempt = 0
        
        while ($attempt -le $maxRetries) {
            try {
                # Capture only the thread objects, not console output
                $threads = & $getThreadsScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber 2>&1 |
                    Where-Object { $_ -is [PSCustomObject] -and $_.id }
                return $threads
            }
            catch {
                $attempt++
                if ($attempt -gt $maxRetries) {
                    Write-Log "Failed to fetch threads after $maxRetries retries: $_" -Level "Error"
                    throw
                }
                Write-Log "GraphQL failed, retrying... (attempt $attempt)" -Level "Warn"
                Start-Sleep -Seconds 2
            }
        }
    }

    # Main orchestration loop
    Write-Log "Starting PR completion for $Owner/$Repo PR #$PullNumber" -Level "Info"
    Write-Log "MaxIterations: $MaxIterations, ReviewWaitSeconds: $ReviewWaitSeconds, DryRun: $DryRun, AutoFixScope: $AutoFixScope" -Level "Info"
    
    $iterations = 0
    $totalFixed = 0
    $totalSkipped = 0
    $commitShas = @()
    $finalStatus = "Failed"
    
    while ($iterations -lt $MaxIterations) {
        $iterations++
        Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level "Info"
        Write-Host "" # Blank line for readability
        Write-Log "Iteration $iterations/$MaxIterations" -Level "Info"
        
        # Step 1: Fetch unresolved threads
        Write-Log "Fetching unresolved threads..." -Level "Info"
        $threads = Get-UnresolvedThreadsWithRetry
        
        if ($threads.Count -eq 0) {
            Write-Log "No unresolved threads found. PR is clean!" -Level "Info"
            $finalStatus = "Clean"
            break
        }
        
        Write-Log "Found $($threads.Count) unresolved thread(s)" -Level "Info"
        
        # Step 2 & 3: Classify and report
        $classified = @()
        $fixableThreads = @()
        $skippedThreads = @()
        
        foreach ($thread in $threads) {
            $classification = Get-ThreadClassification -Thread $thread
            $classified += $classification
            
            if ($classification.Fixable) {
                $fixableThreads += $classification
            } else {
                $skippedThreads += $classification
            }
        }
        
        Write-Host ""
        Write-Host "Thread Classification:" -ForegroundColor Cyan
        Write-Host "  Fixable (will auto-fix): $($fixableThreads.Count)" -ForegroundColor Green
        Write-Host "  Skipped (requires manual): $($skippedThreads.Count)" -ForegroundColor Yellow
        
        if ($fixableThreads.Count -eq 0) {
            Write-Log "No auto-fixable threads in this iteration. Manual intervention required." -Level "Warn"
            $finalStatus = "Partial"
            $totalSkipped += $skippedThreads.Count
            break
        }
        
        # Report details
        Write-Host ""
        Write-Host "Fixable Threads:" -ForegroundColor Green
        foreach ($t in $fixableThreads) {
            Write-Host "  - [$($t.Severity)] $($t.Path):$($t.Line)" -ForegroundColor White
        }
        
        if ($skippedThreads.Count -gt 0) {
            Write-Host ""
            Write-Host "Skipped Threads:" -ForegroundColor Yellow
            foreach ($t in $skippedThreads) {
                Write-Host "  - [$($t.Severity)] $($t.Path):$($t.Line)" -ForegroundColor Gray
            }
        }
        
        # Step 4: Detect git changes (agent makes fixes between iterations)
        Write-Host ""
        Write-Log "Waiting for agent to make fixes..." -Level "Info"
        Write-Host "  (In production, the agent would make code changes here)" -ForegroundColor Gray
        
        $gitChanges = Get-GitChanges
        
        if ($gitChanges.Count -eq 0) {
            Write-Log "No git changes detected. Replying to threads that no changes are needed." -Level "Warn"
            
            # Handle empty diff: reply and resolve
            foreach ($thread in $fixableThreads) {
                if (-not $DryRun) {
                    $replyScript = Join-Path $PSScriptRoot "Reply-ReviewThread.ps1"
                    if (Test-Path $replyScript) {
                        try {
                            & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                                -ThreadId $thread.ThreadId -Body "No code changes needed for this comment." `
                                -ErrorAction Stop 2>&1 | Out-Null
                        }
                        catch {
                            Write-Log "Failed to reply to thread: $_" -Level "Warn"
                        }
                    }
                }
            }
            
            $threadIds = $fixableThreads | ForEach-Object { $_.ThreadId }
            Invoke-ResolveThreads -ThreadIds $threadIds
            $totalFixed += $fixableThreads.Count
            
            # Continue to next iteration
            continue
        }
        
        Write-Log "Detected $($gitChanges.Count) file change(s)" -Level "Info"
        
        # Handle deleted files
        $deletedFiles = $gitChanges | Where-Object { $_ -match '^ D ' } | ForEach-Object { $_.Substring(3) }
        if ($deletedFiles.Count -gt 0) {
            Write-Log "Detected $($deletedFiles.Count) deleted file(s)" -Level "Info"
            
            foreach ($thread in $fixableThreads) {
                if ($thread.Path -in $deletedFiles) {
                    Write-Log "Thread relates to deleted file: $($thread.Path)" -Level "Info"
                    
                    if (-not $DryRun) {
                        $replyScript = Join-Path $PSScriptRoot "Reply-ReviewThread.ps1"
                        if (Test-Path $replyScript) {
                            try {
                                & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                                    -ThreadId $thread.ThreadId -Body "File has been removed." `
                                    -ErrorAction Stop 2>&1 | Out-Null
                            }
                            catch {
                                Write-Log "Failed to reply about deleted file: $_" -Level "Warn"
                            }
                        }
                    }
                }
            }
        }
        
        # Step 5 & 6: Commit and push
        Write-Host ""
        Write-Log "Committing and pushing changes..." -Level "Info"
        
        try {
            $commitSha = Invoke-CommitAndPush -Iteration $iterations -AddressedThreads $fixableThreads
            $commitShas += $commitSha
        }
        catch {
            Write-Log "Failed to commit/push: $_" -Level "Error"
            $finalStatus = "Failed"
            break
        }
        
        # Step 7 & 8: Reply and resolve
        Write-Host ""
        Write-Log "Replying to addressed threads..." -Level "Info"
        Invoke-ReplyToThreads -Threads $fixableThreads -CommitSha $commitSha
        
        Write-Log "Resolving addressed threads..." -Level "Info"
        $threadIds = $fixableThreads | ForEach-Object { $_.ThreadId }
        Invoke-ResolveThreads -ThreadIds $threadIds
        
        $totalFixed += $fixableThreads.Count
        $totalSkipped += $skippedThreads.Count
        
        # Step 9: Wait for reviewers
        if ($iterations -lt $MaxIterations) {
            Write-Host ""
            Write-Log "Waiting $ReviewWaitSeconds seconds for reviewers..." -Level "Info"
            if (-not $DryRun) {
                Start-Sleep -Seconds $ReviewWaitSeconds
            }
        }
    }
    
    # Final status
    Write-Host ""
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Level "Info"
    Write-Host ""
    Write-Host "PR Completion Summary" -ForegroundColor Cyan
    Write-Host "  Status: $finalStatus" -ForegroundColor $(if ($finalStatus -eq "Clean") { "Green" } elseif ($finalStatus -eq "Partial") { "Yellow" } else { "Red" })
    Write-Host "  Iterations: $iterations" -ForegroundColor White
    Write-Host "  Total Fixed: $totalFixed" -ForegroundColor Green
    Write-Host "  Total Skipped: $totalSkipped" -ForegroundColor Yellow
    
    # Get final remaining count
    $remainingThreads = Get-UnresolvedThreadsWithRetry
    $remaining = $remainingThreads.Count
    Write-Host "  Remaining: $remaining" -ForegroundColor $(if ($remaining -eq 0) { "Green" } else { "Yellow" })
    
    if ($commitShas.Count -gt 0) {
        Write-Host "  Commits:" -ForegroundColor White
        foreach ($sha in $commitShas) {
            Write-Host "    - $sha" -ForegroundColor Gray
        }
    }
    
    # Return structured result
    $result = [PSCustomObject]@{
        Status = $finalStatus
        Iterations = $iterations
        TotalFixed = $totalFixed
        TotalSkipped = $totalSkipped
        Remaining = $remaining
        CommitShas = $commitShas
    }
    
    Write-Output $result
}
finally {
    if ($WorkingDirectory) {
        Pop-Location
    }
}
