<#
.SYNOPSIS
    Submit a structured review on a PR (for agent use).

.DESCRIPTION
    Submit-PRReview.ps1 provides a comprehensive interface for submitting PR reviews
    via GitHub's GraphQL API. It supports:
    - Approve, request changes, or comment review states
    - General review body comments
    - File-specific comments with line references (inline comments)
    - Integration with Reply-ReviewThread.ps1 for replying to existing threads
    - Integration with Resolve-ReviewThreads.ps1 for resolving threads
    - Structured logging via Write-OkyeremaLog.ps1
    - Anokye Labs review conventions

.PARAMETER Owner
    Repository owner (organization or user).

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER Event
    Review event type. Valid values:
    - APPROVE: Approve the pull request
    - REQUEST_CHANGES: Request changes before merging
    - COMMENT: Leave general feedback without explicit approval (default)

.PARAMETER Body
    General review comment body (markdown supported). Optional.

.PARAMETER FileComments
    Array of hashtables for file-specific inline comments. Each hashtable should contain:
    - Path: File path relative to repository root
    - Line: Line number for the comment
    - Body: Comment text (markdown supported)
    - Side: Optional. "RIGHT" (default) for new code, "LEFT" for old code
    - StartLine: Optional. For multi-line comments, the starting line
    - StartSide: Optional. Side for the starting line
    
    Example: @{Path="src/file.ps1"; Line=42; Body="Consider refactoring this"}

.PARAMETER ResolveThreadIds
    Array of thread IDs to resolve after submitting the review.
    Uses Resolve-ReviewThreads.ps1 internally.

.PARAMETER ReplyToThreads
    Array of hashtables for replying to existing review threads. Each hashtable should contain:
    - ThreadId: The review thread ID (PRRT_xxx)
    - Body: Reply text (markdown supported)
    - Resolve: Optional boolean. If $true, resolves the thread after replying
    
    Uses Reply-ReviewThread.ps1 internally.

.PARAMETER DryRun
    If specified, logs the review without submitting it to GitHub.

.PARAMETER Quiet
    If specified, suppresses log output.

.EXAMPLE
    # Simple approval
    .\Submit-PRReview.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -Event APPROVE -Body "LGTM! 🚀"

.EXAMPLE
    # Request changes with inline comments
    $comments = @(
        @{Path="src/utils.ps1"; Line=42; Body="This should use the helper function instead"}
        @{Path="src/main.ps1"; Line=15; Body="Missing error handling here"}
    )
    .\Submit-PRReview.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 `
        -Event REQUEST_CHANGES -Body "Please address these issues" -FileComments $comments

.EXAMPLE
    # Comment with replies to existing threads
    $replies = @(
        @{ThreadId="PRRT_xxx"; Body="Fixed in latest commit"; Resolve=$true}
    )
    .\Submit-PRReview.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 `
        -Event COMMENT -Body "Updated based on feedback" -ReplyToThreads $replies

.EXAMPLE
    # Approve and resolve all threads
    $threadIds = @("PRRT_xxx", "PRRT_yyy")
    .\Submit-PRReview.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 `
        -Event APPROVE -Body "All issues addressed" -ResolveThreadIds $threadIds

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Uses Invoke-GraphQL.ps1, Get-RepoContext.ps1, Write-OkyeremaLog.ps1,
    Reply-ReviewThread.ps1, and Resolve-ReviewThreads.ps1.
    
    Follows Anokye Labs review conventions as documented in how-we-work/our-way.md.
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
    [ValidateSet("APPROVE", "REQUEST_CHANGES", "COMMENT")]
    [string]$Event = "COMMENT",

    [Parameter(Mandatory = $false)]
    [string]$Body = "",

    [Parameter(Mandatory = $false)]
    [hashtable[]]$FileComments = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$ResolveThreadIds = @(),

    [Parameter(Mandatory = $false)]
    [hashtable[]]$ReplyToThreads = @(),

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
# From .github/skills/okyerema/scripts, navigate to repo root
$repoRoot = Resolve-Path (Join-Path $scriptDir '..\..\..\..')
$rootScriptsDir = Join-Path $repoRoot "scripts"

# Helper function to invoke Write-OkyeremaLog.ps1
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $logScript = Join-Path $scriptDir "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation "SubmitPRReview" -CorrelationId $correlationId -Quiet:$Quiet
    }
}

# Helper function to invoke Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{}
    )
    
    $graphqlScript = Join-Path $rootScriptsDir "Invoke-GraphQL.ps1"
    if (-not (Test-Path $graphqlScript)) {
        throw "Invoke-GraphQL.ps1 not found at: $graphqlScript"
    }
    
    return & $graphqlScript -Query $Query -Variables $Variables -DryRun:$DryRun -CorrelationId $correlationId
}

# Helper function to invoke Get-RepoContext.ps1
function Get-RepoContextHelper {
    $contextScript = Join-Path $rootScriptsDir "Get-RepoContext.ps1"
    if (-not (Test-Path $contextScript)) {
        throw "Get-RepoContext.ps1 not found at: $contextScript"
    }
    
    return & $contextScript
}

# Helper function to escape strings for GraphQL
function ConvertTo-GraphQLString {
    param([string]$Text)
    
    if (-not $Text) { return "" }
    
    # Escape backslashes first
    $result = $Text.Replace('\', '\\')
    # Escape quotes
    $result = $result.Replace('"', '\"')
    # Escape newlines
    $result = $result.Replace("`r`n", '\n').Replace("`n", '\n').Replace("`r", '\n')
    # Escape tabs
    $result = $result.Replace("`t", '\t')
    
    return $result
}

Write-Log -Message "Starting PR review submission for $Owner/$Repo PR #$PullNumber" -Level "Info"

# Step 1: Get PR ID via GraphQL
Write-Log -Message "Fetching PR ID" -Level "Info"

$prIdQuery = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    pullRequest(number: $PullNumber) {
      id
      title
      headRefOid
    }
  }
}
"@

$prIdResult = Invoke-GraphQLHelper -Query $prIdQuery

if (-not $prIdResult.Success) {
    Write-Log -Message "Failed to fetch PR ID" -Level "Error"
    foreach ($error in $prIdResult.Errors) {
        Write-Log -Message "Error: $($error.Message)" -Level "Error"
    }
    throw "Failed to fetch PR ID"
}

$pullRequestId = $prIdResult.Data.repository.pullRequest.id
$prTitle = $prIdResult.Data.repository.pullRequest.title
$headCommitOid = $prIdResult.Data.repository.pullRequest.headRefOid

Write-Log -Message "PR ID: $pullRequestId, Title: $prTitle" -Level "Info"

# Step 2: Build the review mutation
Write-Log -Message "Building review mutation with event: $Event" -Level "Info"

$mutationInput = @{
    pullRequestId = $pullRequestId
}

# Add commit OID if available
if ($headCommitOid) {
    $mutationInput.commitOID = $headCommitOid
}

# Add body if provided
if ($Body) {
    $mutationInput.body = $Body
}

# Add event
$mutationInput.event = $Event

# Build the threads array for file comments
$threadsJson = ""
if ($FileComments.Count -gt 0) {
    Write-Log -Message "Adding $($FileComments.Count) file comment(s)" -Level "Info"
    
    $threadObjects = @()
    foreach ($comment in $FileComments) {
        if (-not $comment.Path -or -not $comment.Line -or -not $comment.Body) {
            Write-Log -Message "Invalid file comment - missing Path, Line, or Body" -Level "Warn"
            continue
        }
        
        $threadObj = [ordered]@{
            path = $comment.Path
            line = $comment.Line
            body = $comment.Body
        }
        
        # Add optional fields
        if ($comment.Side) {
            # Validate Side is a valid GraphQL enum value
            if ($comment.Side -notin @("LEFT", "RIGHT")) {
                Write-Log -Message "Invalid Side value: $($comment.Side). Must be LEFT or RIGHT. Using RIGHT as default." -Level "Warn"
                $threadObj.side = "RIGHT"
            } else {
                $threadObj.side = $comment.Side
            }
        } else {
            $threadObj.side = "RIGHT"
        }
        
        if ($comment.StartLine) {
            $threadObj.startLine = $comment.StartLine
        }
        
        if ($comment.StartSide) {
            $threadObj.startSide = $comment.StartSide
        }
        
        $threadObjects += $threadObj
    }
    
    if ($threadObjects.Count -gt 0) {
        $threadsJson = $threadObjects | ConvertTo-Json -Compress -Depth 10
    }
}

# Build the mutation
$escapedBody = ConvertTo-GraphQLString -Text $Body

# Build threads parameter
$threadsParam = if ($threadsJson) {
    # Parse and reformat as GraphQL input
    $threads = $threadsJson | ConvertFrom-Json
    $threadStrings = @()
    foreach ($thread in $threads) {
        $escapedPath = ConvertTo-GraphQLString -Text $thread.path
        $escapedThreadBody = ConvertTo-GraphQLString -Text $thread.body
        
        $threadStr = "{path: \`"$escapedPath\`", line: $($thread.line), side: $($thread.side), body: \`"$escapedThreadBody\`""
        
        if ($thread.startLine) {
            $threadStr += ", startLine: $($thread.startLine)"
        }
        if ($thread.startSide) {
            $threadStr += ", startSide: $($thread.startSide)"
        }
        
        $threadStr += "}"
        $threadStrings += $threadStr
    }
    
    "threads: [" + ($threadStrings -join ", ") + "]"
} else {
    ""
}

$mutation = @"
mutation {
  addPullRequestReview(input: {
    pullRequestId: "$pullRequestId"
$(if ($headCommitOid) { "    commitOID: `"$headCommitOid`"`n" })
$(if ($escapedBody) { "    body: `"$escapedBody`"`n" })
    event: $Event
$(if ($threadsParam) { "    $threadsParam`n" })
  }) {
    pullRequestReview {
      id
      state
      url
      body
      comments(first: 10) {
        totalCount
        nodes {
          path
          body
        }
      }
    }
  }
}
"@

Write-Log -Message "Submitting review mutation" -Level "Info"

if ($DryRun) {
    Write-Host "`n=== DryRun Mode: Review Mutation ===" -ForegroundColor Cyan
    Write-Host $mutation -ForegroundColor Yellow
    Write-Host "==================================`n" -ForegroundColor Cyan
}

$reviewResult = Invoke-GraphQLHelper -Query $mutation

if (-not $reviewResult.Success) {
    Write-Log -Message "Failed to submit review" -Level "Error"
    foreach ($error in $reviewResult.Errors) {
        Write-Log -Message "Error: $($error.Message)" -Level "Error"
    }
    throw "Failed to submit review"
}

$review = $reviewResult.Data.addPullRequestReview.pullRequestReview
Write-Log -Message "Review submitted successfully. ID: $($review.id), State: $($review.state)" -Level "Info"

if (-not $DryRun) {
    Write-Host "`n✓ Review submitted: $($review.url)" -ForegroundColor Green
    Write-Host "  State: $($review.state)" -ForegroundColor Cyan
    if ($review.body) {
        $bodyPreview = if ($review.body.Length -gt 100) {
            $review.body.Substring(0, 100) + "..."
        } else {
            $review.body
        }
        Write-Host "  Body: $bodyPreview" -ForegroundColor Gray
    }
    if ($review.comments.totalCount -gt 0) {
        Write-Host "  File comments: $($review.comments.totalCount)" -ForegroundColor Cyan
    }
}

# Step 3: Reply to threads if specified
if ($ReplyToThreads.Count -gt 0) {
    Write-Log -Message "Replying to $($ReplyToThreads.Count) thread(s)" -Level "Info"
    
    $replyScript = Join-Path $scriptDir "Reply-ReviewThread.ps1"
    if (-not (Test-Path $replyScript)) {
        Write-Log -Message "Reply-ReviewThread.ps1 not found at: $replyScript" -Level "Warn"
    } else {
        foreach ($reply in $ReplyToThreads) {
            if (-not $reply.ThreadId -or -not $reply.Body) {
                Write-Log -Message "Invalid reply - missing ThreadId or Body" -Level "Warn"
                continue
            }
            
            Write-Log -Message "Replying to thread: $($reply.ThreadId)" -Level "Info"
            
            $replyArgs = @{
                Owner = $Owner
                Repo = $Repo
                PullNumber = $PullNumber
                ThreadId = $reply.ThreadId
                Body = $reply.Body
            }
            
            if ($reply.Resolve -eq $true) {
                $replyArgs.Resolve = $true
            }
            
            if (-not $DryRun) {
                & $replyScript @replyArgs
            } else {
                Write-Host "`n=== DryRun: Would reply to thread $($reply.ThreadId) ===" -ForegroundColor Cyan
                Write-Host "Body: $($reply.Body)" -ForegroundColor Yellow
                Write-Host "Resolve: $($reply.Resolve -eq $true)" -ForegroundColor Yellow
            }
        }
    }
}

# Step 4: Resolve threads if specified
if ($ResolveThreadIds.Count -gt 0) {
    Write-Log -Message "Resolving $($ResolveThreadIds.Count) thread(s)" -Level "Info"
    
    $resolveScript = Join-Path $scriptDir "Resolve-ReviewThreads.ps1"
    if (-not (Test-Path $resolveScript)) {
        Write-Log -Message "Resolve-ReviewThreads.ps1 not found at: $resolveScript" -Level "Warn"
    } else {
        if (-not $DryRun) {
            & $resolveScript -Owner $Owner -Repo $Repo -PullNumber $PullNumber -ThreadIds $ResolveThreadIds
        } else {
            Write-Host "`n=== DryRun: Would resolve threads ===" -ForegroundColor Cyan
            Write-Host "Thread IDs: $($ResolveThreadIds -join ', ')" -ForegroundColor Yellow
        }
    }
}

Write-Log -Message "PR review submission completed" -Level "Info"

# Return the review object for pipeline use
return $review
