# PR Review Threads

GraphQL operations for managing pull request review conversations.

> Back to [SKILL.md](../SKILL.md)

## Find Unresolved Threads

```graphql
{
  repository(owner: "ORG", name: "REPO") {
    pullRequest(number: PR_NUM) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 5) {
            nodes {
              author { login }
              body
              createdAt
              url
            }
            totalCount
          }
        }
        totalCount
      }
    }
  }
}
```

Filter in code: `nodes | Where-Object { -not $_.isResolved }`

## Reply to a Thread

```graphql
mutation {
  addPullRequestReviewThreadReply(input: {
    pullRequestReviewThreadId: "PRRT_xxx"
    body: "Fixed in abc123 — added backslash escaping."
  }) {
    comment {
      url
    }
  }
}
```

**Important:** Escape the body properly before embedding:
```powershell
$escaped = $Body.Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n')
```

## Resolve a Thread

```graphql
mutation {
  resolveReviewThread(input: {
    threadId: "PRRT_xxx"
  }) {
    thread { isResolved }
  }
}
```

## Unresolve a Thread

```graphql
mutation {
  unresolveReviewThread(input: {
    threadId: "PRRT_xxx"
  }) {
    thread { isResolved }
  }
}
```

## Workflow: Address Review Feedback

1. **Analyze** PR comments for actionability → `Get-PRCommentAnalysis.ps1`
2. **Prioritize** blocking and high-priority comments
3. **Read** unresolved threads → `Get-UnresolvedThreads.ps1`
4. **Fix** the code
5. **Commit & push** to the PR branch
6. **Reply** to each thread explaining the fix → `Reply-ReviewThread.ps1 -Resolve`
7. **Verify** no unresolved threads remain → `Get-UnresolvedThreads.ps1`

## Automated PR Completion

The `Invoke-PRCompletion.ps1` script orchestrates the review-fix-push-resolve cycle, driving PRs to completion by automating the iterative workflow described above.

### Overview

This script is designed for agent-assisted execution: the script fetches and classifies review threads, the agent reads the output and makes code fixes, then the script commits, pushes, replies to threads, and resolves them. The loop continues until the PR is clean or a maximum iteration limit is reached.

### Parameters

```powershell
Invoke-PRCompletion.ps1 `
    -Owner <string> `           # Repository owner (mandatory)
    -Repo <string> `            # Repository name (mandatory)
    -PullNumber <int> `         # PR number (mandatory)
    [-MaxIterations <int>] `    # Safety limit (default: 5)
    [-ReviewWaitSeconds <int>] ` # Wait time after push (default: 90)
    [-DryRun] `                 # Report only, no changes
    [-AutoFixScope <string>] `  # 'All' or 'BugsOnly' (default: 'All')
    [-WorkingDirectory <string>] # Local clone path (defaults to current directory)
```

### How It Works

1. **Fetch** unresolved review threads using `Get-UnresolvedThreads.ps1`
2. **Classify** each thread by severity (bug, nit, suggestion, question)
3. **Report** findings to stdout for agent consumption
4. **Wait** for agent to make fixes (agent makes code changes between iterations)
5. **Detect** git changes and commit with iteration-numbered message
6. **Push** to PR branch
7. **Reply** to each addressed thread with commit SHA
8. **Resolve** addressed threads
9. **Wait** for reviewers to process the push
10. **Loop** until clean or max iterations reached

### Output

Returns a PSCustomObject with:
- `Status` - 'Clean', 'Partial', or 'Failed'
- `Iterations` - Number of iterations completed
- `TotalFixed` - Count of threads addressed
- `TotalSkipped` - Count of threads escalated
- `Remaining` - Count of unresolved threads left
- `CommitShas` - Array of fix commit SHAs

### Examples

#### Basic run
```powershell
# Run the completion workflow on PR #6
.\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

# Output:
# Iteration 1: Found 3 unresolved threads
#   Bugs: 2 | Nits: 1 | Suggestions: 0 | Questions: 0
# (Agent makes fixes...)
# Committed fixes for 3 threads in abc1234
# Waiting 90s for reviewers...
# PR is clean after 1 iteration(s)
```

#### Dry-run mode
```powershell
# See what would be done without making changes
.\Invoke-PRCompletion.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -DryRun

# Output:
# Dry Run - PR #6 (anokye-labs/akwaaba)
# [Bug]        scripts/Foo.ps1:42    - Undefined variable
# [Nit]        references/doc.md:15  - Consider rewording
# [Question]   scripts/Baz.ps1:88    - Why not use X?
#
# Summary: 2 bugs, 1 nit, 0 suggestions, 1 question (4 total)
# Action: Would fix 3, escalate 1
```

#### Bugs-only mode
```powershell
# Auto-fix only bugs, escalate everything else
.\Invoke-PRCompletion.ps1 `
    -Owner anokye-labs `
    -Repo akwaaba `
    -PullNumber 6 `
    -AutoFixScope BugsOnly

# Output:
# Iteration 1: Found 4 unresolved threads
#   Bugs: 2 | Nits: 1 | Suggestions: 0 | Questions: 1
# Fixing 2 bugs, escalating 2 threads
# (Agent makes fixes for bugs only...)
# Committed fixes for 2 threads in xyz5678
# Replied to 2 escalated threads (needs human decision)
```

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `Invoke-PRCompletion.ps1` | Orchestrate the review-fix-push-resolve cycle to drive PRs to completion |
| `Get-UnresolvedThreads.ps1` | List unresolved (or all) threads with comment details |
| `Get-PRCommentAnalysis.ps1` | Analyze PR comments for actionability with categorization (blocking, suggestion, nitpick, question, praise) |
| `Reply-ReviewThread.ps1` | Reply to a thread by ID or index, optionally resolve |
| `Resolve-ReviewThreads.ps1` | Bulk resolve/unresolve threads |

## Common Patterns

### Reply and resolve all unresolved threads with the same message
```powershell
$threads = .\Get-UnresolvedThreads.ps1 -Owner ORG -Repo REPO -PullNumber 6
foreach ($t in $threads) {
    .\Reply-ReviewThread.ps1 -Owner ORG -Repo REPO -PullNumber 6 -ThreadId $t.id -Body "Addressed in commit abc123" -Resolve
}
```

### Bulk resolve all (no reply)
```powershell
.\Resolve-ReviewThreads.ps1 -Owner ORG -Repo REPO -PullNumber 6 -All
```

### Analyze PR comments with JSON output for automation
```powershell
$json = .\Get-PRCommentAnalysis.ps1 -Owner ORG -Repo REPO -PullNumber 6 -OutputFormat Json
$analysis = $json | ConvertFrom-Json

# Get all blocking comments
$blocking = $analysis.categories.blocking
Write-Host "Found $($blocking.Count) blocking comments"

# Get files with most comments
$analysis.byFile.PSObject.Properties | ForEach-Object {
    [PSCustomObject]@{
        File = $_.Name
        Comments = $_.Value.Count
    }
} | Sort-Object Comments -Descending | Format-Table
```

### Get console output with categorization
```powershell
# Shows color-coded output by category (blocking, suggestion, nitpick, question, praise)
.\Get-PRCommentAnalysis.ps1 -Owner ORG -Repo REPO -PullNumber 6
```

### Generate Markdown report
```powershell
.\Get-PRCommentAnalysis.ps1 -Owner ORG -Repo REPO -PullNumber 6 -OutputFormat Markdown > pr-analysis.md
```
