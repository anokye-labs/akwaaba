<#
.SYNOPSIS
    Orchestrate iterative PR review-fix-push-resolve cycle to drive PR completion.

.DESCRIPTION
    Invoke-PRCompletion.ps1 automates the review feedback loop:
    1. Fetch unresolved review threads
    2. Classify by severity (blocking, suggestion, nitpick, question, praise)
    3. Report threads to stdout for agent to fix
    4. Detect code changes
    5. Commit and push fixes
    6. Reply to threads with commit SHA
    7. Resolve addressed threads
    8. Wait for reviewers to process
    9. Loop until clean or max iterations reached
    
    This is an orchestration script designed to be called by an agent that will
    make the actual code changes. The script handles all git operations and thread
    management.

.PARAMETER Owner
    Repository owner (org or user).

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER MaxIterations
    Maximum number of fix-push-review cycles (default: 5).

.PARAMETER ReviewWaitSeconds
    Time to wait for reviewers after each push (default: 90).

.PARAMETER DryRun
    If set, shows plan without making any changes.

.PARAMETER AutoFixScope
    What to auto-fix: 'All' (default) or 'BugsOnly' (escalate everything else).

.PARAMETER WorkingDirectory
    Local clone path (defaults to current directory).

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun

.EXAMPLE
    .\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -MaxIterations 3 -AutoFixScope BugsOnly

.OUTPUTS
    PSCustomObject with:
    - Status: 'Clean' | 'Partial' | 'Failed'
    - Iterations: int
    - TotalFixed: int
    - TotalSkipped: int
    - Remaining: int (unresolved threads left)
    - CommitShas: array of fix commit SHAs

.NOTES
    Dependencies:
    - Get-UnresolvedThreads.ps1
    - Reply-ReviewThread.ps1
    - Write-OkyeremaLog.ps1
    - git CLI
    - gh CLI
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
    [ValidateSet('All', 'BugsOnly')]
    [string]$AutoFixScope = 'All',

    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = $PWD
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper: Write log message
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logScript = Join-Path $ScriptDir "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation "PRCompletion"
    }
    else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

# Helper: Classify thread by severity/category
function Get-ThreadClassification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Body,
        
        [Parameter(Mandatory = $false)]
        [string]$AuthorLogin = ""
    )
    
    $bodyLower = $Body.ToLower()
    
    # Check for known bot severity indicators
    # P0 = critical/blocking, P1 = high priority, P2 = medium
    if ($Body -match 'P0|P\[0\]') {
        return 'blocking'
    }
    if ($Body -match 'P1|P\[1\]') {
        return 'blocking'
    }
    if ($Body -match 'P2|P\[2\]') {
        return 'suggestion'
    }
    
    # Check for suggestion/consider phrases to avoid false blocking classification
    $hasSuggestiveLanguage = $bodyLower -match '\b(consider|suggest|recommend|could|should|would|might)\b.*\b(error|bug|fail)'
    
    # Blocking indicators (highest priority) - but not if it's a suggestion
    if (-not $hasSuggestiveLanguage) {
        $blockingPatterns = @(
            '\b(security|vulnerability|exploit|injection|xss|csrf|sql injection)\b',
            '\b(critical|blocker|blocking|must fix|required|mandatory)\b',
            '\b(breaks?|broken|this is a bug|has a bug|causes?\s+(a\s+)?(crash|error))\b',
            '\b(undefined behavior|null pointer|memory leak|race condition)\b',
            '\b(test\s+)?(fails?|failed|failure|failing)\b',
            '\b(malformed|invalid|corrupts?|data loss)\b'
        )
        
        foreach ($pattern in $blockingPatterns) {
            if ($bodyLower -match $pattern) {
                return 'blocking'
            }
        }
    }
    
    # Question indicators
    $questionPatterns = @(
        '\?$',
        '^\s*(why|how|what|when|where|which)\b',
        '\b(could you|can you|would you)\s+(explain|clarify)\b',
        '\b(not sure|unclear|confused)\b'
    )
    
    foreach ($pattern in $questionPatterns) {
        if ($bodyLower -match $pattern) {
            return 'question'
        }
    }
    
    # Praise indicators
    $praisePatterns = @(
        '\b(nice|good|great|excellent|perfect|love|awesome|fantastic)\b',
        '\b(thank|thanks|lgtm|looks good|well done|good job)\b',
        '👍|❤️|🎉|✨|💯|🔥'
    )
    
    foreach ($pattern in $praisePatterns) {
        if ($bodyLower -match $pattern) {
            return 'praise'
        }
    }
    
    # Nitpick indicators
    $nitpickPatterns = @(
        '\b(nit|nitpick|minor|small|tiny|trivial)\b',
        '\b(style|formatting|whitespace|spacing|indentation)\b',
        '\b(typo|spelling|grammar|wording|cosmetic)\b',
        '\boptional\b'
    )
    
    foreach ($pattern in $nitpickPatterns) {
        if ($bodyLower -match $pattern) {
            return 'nitpick'
        }
    }
    
    # Suggestion indicators (default for actionable comments)
    $suggestionPatterns = @(
        '\b(suggest|recommend|could|should|would|might|perhaps)\b',
        '\b(improve|better|consider|instead|prefer)\b',
        '\b(refactor|simplify|optimize|clean up)\b'
    )
    
    foreach ($pattern in $suggestionPatterns) {
        if ($bodyLower -match $pattern) {
            return 'suggestion'
        }
    }
    
    # Default to 'suggestion' for safety (assume actionable)
    return 'suggestion'
}

# Helper: Get unresolved threads with classification
function Get-ClassifiedThreads {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$PullNumber
    )
    
    Write-Log "Fetching unresolved threads..." "Info"
    
    $getThreadsScript = Join-Path $ScriptDir "Get-UnresolvedThreads.ps1"
    if (-not (Test-Path $getThreadsScript)) {
        throw "Get-UnresolvedThreads.ps1 not found at $getThreadsScript"
    }
    
    # Capture thread objects from pipeline
    $threads = @(& $getThreadsScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber 2>&1 | 
        Where-Object { $_ -is [PSCustomObject] -and $null -ne $_.id })
    
    Write-Log "Found $($threads.Count) unresolved threads" "Info"
    
    # Classify each thread
    $classified = @()
    foreach ($thread in $threads) {
        $firstComment = $thread.comments.nodes[0]
        $classification = Get-ThreadClassification -Body $firstComment.body -AuthorLogin $firstComment.author.login
        
        $classified += [PSCustomObject]@{
            ThreadId = $thread.id
            FilePath = $thread.path
            Line = $thread.line
            Author = $firstComment.author.login
            Body = $firstComment.body
            Classification = $classification
            IsOutdated = $thread.isOutdated
            CommentCount = $thread.comments.totalCount
        }
    }
    
    return $classified
}

# Helper: Report threads to stdout for agent to read
function Show-ThreadsForReview {
    param(
        [array]$Threads,
        [int]$Iteration
    )
    
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " Iteration $Iteration - Review Threads to Address" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    # Group by classification
    $grouped = $Threads | Group-Object -Property Classification
    
    foreach ($group in $grouped) {
        $count = $group.Count
        $category = $group.Name
        
        $icon = switch ($category) {
            'blocking' { '🚫' }
            'suggestion' { '💡' }
            'nitpick' { '🔍' }
            'question' { '❓' }
            'praise' { '👍' }
            default { '📝' }
        }
        
        $color = switch ($category) {
            'blocking' { 'Red' }
            'suggestion' { 'Cyan' }
            'nitpick' { 'DarkGray' }
            'question' { 'Magenta' }
            'praise' { 'Green' }
            default { 'White' }
        }
        
        Write-Host "$icon $($category.ToUpper()): $count thread(s)" -ForegroundColor $color
    }
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host ""
    
    # Show each thread
    for ($i = 0; $i -lt $Threads.Count; $i++) {
        $thread = $Threads[$i]
        
        $icon = switch ($thread.Classification) {
            'blocking' { '🚫' }
            'suggestion' { '💡' }
            'nitpick' { '🔍' }
            'question' { '❓' }
            'praise' { '👍' }
            default { '📝' }
        }
        
        Write-Host "[$i] $icon " -ForegroundColor White -NoNewline
        Write-Host "$($thread.Classification.ToUpper())" -ForegroundColor Yellow -NoNewline
        Write-Host " - $($thread.FilePath):$($thread.Line)" -ForegroundColor White
        Write-Host "    Thread ID: $($thread.ThreadId)" -ForegroundColor DarkGray
        Write-Host "    Author: @$($thread.Author)" -ForegroundColor Gray
        
        if ($thread.IsOutdated) {
            Write-Host "    [OUTDATED - code has changed]" -ForegroundColor DarkYellow
        }
        
        Write-Host ""
        Write-Host "    Comment:" -ForegroundColor Cyan
        $bodyLines = $thread.Body -split "`n"
        foreach ($line in $bodyLines) {
            Write-Host "    $line" -ForegroundColor Gray
        }
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Helper: Check for changed files
function Get-ChangedFiles {
    param([string]$WorkingDirectory)
    
    Push-Location $WorkingDirectory
    try {
        $status = git status --porcelain 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git status failed: $status" "Error"
            return @()
        }
        
        $changed = @()
        foreach ($line in $status) {
            if ($line -match '^\s*[MADR?]') {
                $changed += $line.Trim()
            }
        }
        
        return $changed
    }
    finally {
        Pop-Location
    }
}

# Helper: Commit and push changes
function Invoke-CommitAndPush {
    param(
        [string]$WorkingDirectory,
        [string]$CommitMessage,
        [int]$Iteration
    )
    
    Push-Location $WorkingDirectory
    try {
        Write-Log "Adding changed files..." "Info"
        $addResult = git add -A 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git add failed: $addResult" "Error"
            throw "Failed to stage changes"
        }
        
        Write-Log "Committing changes..." "Info"
        $commitResult = git commit -m $CommitMessage 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git commit failed: $commitResult" "Error"
            throw "Failed to commit changes"
        }
        
        Write-Log "Pushing to remote..." "Info"
        $pushResult = git push 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Git push failed: $pushResult" "Error"
            throw "Failed to push changes"
        }
        
        # Get commit SHA
        $sha = git rev-parse --short HEAD 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to get commit SHA: $sha" "Warning"
            $sha = "unknown"
        }
        
        Write-Log "Committed and pushed as $sha" "Info"
        return $sha.Trim()
    }
    finally {
        Pop-Location
    }
}

# Helper: Reply and resolve threads
function Invoke-ReplyAndResolve {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$PullNumber,
        [array]$Threads,
        [string]$CommitSha
    )
    
    $replyScript = Join-Path $ScriptDir "Reply-ReviewThread.ps1"
    if (-not (Test-Path $replyScript)) {
        throw "Reply-ReviewThread.ps1 not found at $replyScript"
    }
    
    $repliedCount = 0
    
    foreach ($thread in $Threads) {
        try {
            $body = "Fixed in $CommitSha"
            
            # Don't resolve questions - those need human decision
            $shouldResolve = $thread.Classification -ne 'question'
            
            if ($shouldResolve) {
                Write-Log "Replying and resolving thread: $($thread.FilePath):$($thread.Line)" "Info"
                & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                    -ThreadId $thread.ThreadId -Body $body -Resolve 2>&1 | Out-Null
            }
            else {
                Write-Log "Replying to question thread (not resolving): $($thread.FilePath):$($thread.Line)" "Info"
                & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                    -ThreadId $thread.ThreadId -Body $body 2>&1 | Out-Null
            }
            
            $repliedCount++
        }
        catch {
            Write-Log "Failed to reply to thread $($thread.ThreadId): $_" "Warning"
        }
    }
    
    return $repliedCount
}

# Main execution
function Main {
    Write-Log "Starting PR completion workflow for $Owner/$Repo #$PullNumber" "Info"
    Write-Log "Max iterations: $MaxIterations, Review wait: ${ReviewWaitSeconds}s, Auto-fix scope: $AutoFixScope" "Info"
    
    if ($DryRun) {
        Write-Host "`n🔍 DRY RUN MODE - No changes will be made`n" -ForegroundColor Yellow
    }
    
    $iteration = 0
    $totalFixed = 0
    $totalSkipped = 0
    $commitShas = @()
    
    while ($iteration -lt $MaxIterations) {
        $iteration++
        
        Write-Host "`n" -NoNewline
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
        Write-Host " ITERATION $iteration of $MaxIterations" -ForegroundColor Magenta
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Magenta
        Write-Host ""
        
        # Step 1: FETCH - get all unresolved review threads
        $threads = Get-ClassifiedThreads -Owner $Owner -Repo $Repo -PullNumber $PullNumber
        
        if ($threads.Count -eq 0) {
            Write-Host "`n✅ PR is clean after $iteration iteration(s)!" -ForegroundColor Green
            Write-Host "   No unresolved review threads remaining.`n" -ForegroundColor Green
            
            return [PSCustomObject]@{
                Status = 'Clean'
                Iterations = $iteration
                TotalFixed = $totalFixed
                TotalSkipped = $totalSkipped
                Remaining = 0
                CommitShas = $commitShas
            }
        }
        
        # Step 2: CLASSIFY - group by severity
        $byClassification = $threads | Group-Object -Property Classification
        $blockingCount = ($threads | Where-Object { $_.Classification -eq 'blocking' }).Count
        $suggestionCount = ($threads | Where-Object { $_.Classification -eq 'suggestion' }).Count
        $nitpickCount = ($threads | Where-Object { $_.Classification -eq 'nitpick' }).Count
        $questionCount = ($threads | Where-Object { $_.Classification -eq 'question' }).Count
        $praiseCount = ($threads | Where-Object { $_.Classification -eq 'praise' }).Count
        
        # Step 3: REPORT - show what was found
        Write-Host "Found $($threads.Count) unresolved threads:" -ForegroundColor White
        Write-Host "  🚫 Blocking:    $blockingCount" -ForegroundColor Red
        Write-Host "  💡 Suggestions: $suggestionCount" -ForegroundColor Cyan
        Write-Host "  🔍 Nitpicks:    $nitpickCount" -ForegroundColor DarkGray
        Write-Host "  ❓ Questions:   $questionCount" -ForegroundColor Magenta
        Write-Host "  👍 Praise:      $praiseCount" -ForegroundColor Green
        Write-Host ""
        
        # Determine which threads to address based on AutoFixScope
        $threadsToFix = if ($AutoFixScope -eq 'BugsOnly') {
            $threads | Where-Object { $_.Classification -eq 'blocking' }
        }
        else {
            # Address all except praise (praise threads don't need fixing)
            $threads | Where-Object { $_.Classification -ne 'praise' }
        }
        
        $threadsToSkip = $threads | Where-Object { $_ -notin $threadsToFix }
        
        if ($threadsToSkip.Count -gt 0) {
            Write-Host "⏭️  Skipping $($threadsToSkip.Count) threads (AutoFixScope=$AutoFixScope):" -ForegroundColor Yellow
            foreach ($t in $threadsToSkip) {
                Write-Host "   - $($t.Classification): $($t.FilePath):$($t.Line)" -ForegroundColor DarkGray
            }
            Write-Host ""
            $totalSkipped += $threadsToSkip.Count
        }
        
        if ($threadsToFix.Count -eq 0) {
            Write-Host "`n⚠️  No threads to fix based on current scope. Stopping." -ForegroundColor Yellow
            
            return [PSCustomObject]@{
                Status = 'Partial'
                Iterations = $iteration
                TotalFixed = $totalFixed
                TotalSkipped = $totalSkipped
                Remaining = $threads.Count
                CommitShas = $commitShas
            }
        }
        
        # Show threads that need fixing
        Show-ThreadsForReview -Threads $threadsToFix -Iteration $iteration
        
        if ($DryRun) {
            Write-Host "`n🔍 DRY RUN: Would process $($threadsToFix.Count) threads" -ForegroundColor Yellow
            Write-Host "   In normal mode, the agent would:" -ForegroundColor Gray
            Write-Host "   1. Make code fixes for each thread" -ForegroundColor Gray
            Write-Host "   2. Commit changes" -ForegroundColor Gray
            Write-Host "   3. Push to remote" -ForegroundColor Gray
            Write-Host "   4. Reply to and resolve threads" -ForegroundColor Gray
            Write-Host "   5. Wait ${ReviewWaitSeconds}s for reviewers" -ForegroundColor Gray
            Write-Host ""
            
            return [PSCustomObject]@{
                Status = 'DryRun'
                Iterations = $iteration
                TotalFixed = 0
                TotalSkipped = $totalSkipped
                Remaining = $threads.Count
                CommitShas = @()
            }
        }
        
        # Step 4: FIX - Wait for agent to make code changes
        Write-Host "`n⏸️  WAITING FOR CODE FIXES..." -ForegroundColor Yellow
        Write-Host "   The agent should now review the threads above and make code fixes." -ForegroundColor Gray
        Write-Host "   Press ENTER when fixes are complete to continue..." -ForegroundColor Gray
        Read-Host
        
        # Step 5: CHECK for changes
        $changedFiles = Get-ChangedFiles -WorkingDirectory $WorkingDirectory
        
        if ($changedFiles.Count -eq 0) {
            Write-Host "`n⚠️  No code changes detected." -ForegroundColor Yellow
            Write-Host "   Options:" -ForegroundColor Gray
            Write-Host "   1. Make fixes and press ENTER" -ForegroundColor Gray
            Write-Host "   2. Skip this iteration (threads will be marked as reviewed)" -ForegroundColor Gray
            Write-Host ""
            
            $response = Read-Host "Skip and mark as reviewed? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                # Reply to threads without resolving
                Write-Host "`nMarking threads as reviewed (no changes needed)..." -ForegroundColor Cyan
                $replyScript = Join-Path $ScriptDir "Reply-ReviewThread.ps1"
                foreach ($thread in $threadsToFix) {
                    try {
                        & $replyScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
                            -ThreadId $thread.ThreadId -Body "Reviewed - no changes needed" -Resolve 2>&1 | Out-Null
                    }
                    catch {
                        Write-Log "Failed to reply to thread: $_" "Warning"
                    }
                }
                continue
            }
            else {
                Write-Host "Waiting for fixes..." -ForegroundColor Gray
                Read-Host "Press ENTER when ready"
                continue
            }
        }
        
        Write-Host "`n✅ Detected $($changedFiles.Count) changed file(s):" -ForegroundColor Green
        foreach ($file in $changedFiles) {
            Write-Host "   $file" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Step 6: COMMIT & PUSH
        $commitMessage = "fix: address $($threadsToFix.Count) review comment(s) (iteration $iteration)"
        Write-Host "Committing and pushing..." -ForegroundColor Cyan
        
        try {
            $commitSha = Invoke-CommitAndPush -WorkingDirectory $WorkingDirectory -CommitMessage $commitMessage -Iteration $iteration
            $commitShas += $commitSha
            $totalFixed += $threadsToFix.Count
            
            Write-Host "✅ Pushed commit $commitSha" -ForegroundColor Green
        }
        catch {
            Write-Log "Failed to commit/push: $_" "Error"
            Write-Host "`n❌ Failed to commit and push changes: $_" -ForegroundColor Red
            
            return [PSCustomObject]@{
                Status = 'Failed'
                Iterations = $iteration
                TotalFixed = $totalFixed
                TotalSkipped = $totalSkipped
                Remaining = $threads.Count
                CommitShas = $commitShas
            }
        }
        
        # Step 7: REPLY & RESOLVE
        Write-Host "`nReplying to and resolving threads..." -ForegroundColor Cyan
        $repliedCount = Invoke-ReplyAndResolve -Owner $Owner -Repo $Repo -PullNumber $PullNumber `
            -Threads $threadsToFix -CommitSha $commitSha
        
        Write-Host "✅ Replied to $repliedCount thread(s)" -ForegroundColor Green
        
        # Step 8: WAIT - let reviewers process the new push
        if ($iteration -lt $MaxIterations) {
            Write-Host "`n⏳ Waiting ${ReviewWaitSeconds}s for reviewers to process the new push..." -ForegroundColor Cyan
            Write-Host "   (Ctrl+C to abort)" -ForegroundColor DarkGray
            Start-Sleep -Seconds $ReviewWaitSeconds
        }
    }
    
    # Reached max iterations
    Write-Host "`n⚠️  Reached maximum iterations ($MaxIterations)" -ForegroundColor Yellow
    
    # Check final state
    $finalThreads = Get-ClassifiedThreads -Owner $Owner -Repo $Repo -PullNumber $PullNumber
    
    if ($finalThreads.Count -eq 0) {
        Write-Host "✅ PR is now clean!" -ForegroundColor Green
        
        return [PSCustomObject]@{
            Status = 'Clean'
            Iterations = $iteration
            TotalFixed = $totalFixed
            TotalSkipped = $totalSkipped
            Remaining = 0
            CommitShas = $commitShas
        }
    }
    else {
        Write-Host "⚠️  $($finalThreads.Count) unresolved thread(s) remain." -ForegroundColor Yellow
        Write-Host "   Consider increasing -MaxIterations or addressing threads manually." -ForegroundColor Gray
        
        return [PSCustomObject]@{
            Status = 'Partial'
            Iterations = $iteration
            TotalFixed = $totalFixed
            TotalSkipped = $totalSkipped
            Remaining = $finalThreads.Count
            CommitShas = $commitShas
        }
    }
}

# Execute main function and return result
try {
    $result = Main
    
    # Display final summary
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " PR COMPLETION SUMMARY" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
    Write-Host "Status:           " -NoNewline
    $statusColor = switch ($result.Status) {
        'Clean' { 'Green' }
        'Partial' { 'Yellow' }
        'Failed' { 'Red' }
        'DryRun' { 'Cyan' }
        default { 'White' }
    }
    Write-Host $result.Status -ForegroundColor $statusColor
    
    Write-Host "Iterations:       $($result.Iterations)"
    Write-Host "Threads Fixed:    $($result.TotalFixed)"
    Write-Host "Threads Skipped:  $($result.TotalSkipped)"
    Write-Host "Remaining:        $($result.Remaining)"
    Write-Host "Commits:          $($result.CommitShas.Count)"
    
    if ($result.CommitShas.Count -gt 0) {
        Write-Host "`nCommit SHAs:" -ForegroundColor Gray
        foreach ($sha in $result.CommitShas) {
            Write-Host "  - $sha" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    
    # Return the result object
    return $result
}
catch {
    Write-Log "Fatal error in PR completion workflow: $_" "Error"
    Write-Host "`n❌ Fatal error: $_" -ForegroundColor Red
    
    return [PSCustomObject]@{
        Status = 'Failed'
        Iterations = 0
        TotalFixed = 0
        TotalSkipped = 0
        Remaining = -1
        CommitShas = @()
    }
}
