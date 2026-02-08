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

### Manual Workflow

1. **Analyze** PR comments for actionability → `Get-PRCommentAnalysis.ps1`
2. **Prioritize** blocking and high-priority comments
3. **Read** unresolved threads → `Get-UnresolvedThreads.ps1`
4. **Fix** the code
5. **Commit & push** to the PR branch
6. **Reply** to each thread explaining the fix → `Reply-ReviewThread.ps1 -Resolve`
7. **Verify** no unresolved threads remain → `Get-UnresolvedThreads.ps1`

### Automated Workflow (Agent-Driven)

Use `Invoke-PRCompletion.ps1` for iterative review-fix-push-resolve cycles:

```powershell
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6
```

This orchestrates the complete cycle:
1. Fetches unresolved threads
2. Classifies by severity (blocking, suggestion, nitpick, question, praise)
3. Presents threads for the agent to fix
4. Waits for code changes
5. Commits and pushes fixes
6. Replies to and resolves threads
7. Waits for reviewers
8. Loops until PR is clean or max iterations reached

Options:
- `-DryRun` - Preview what would be done without making changes
- `-MaxIterations 5` - Limit iteration count (default: 5)
- `-ReviewWaitSeconds 90` - Time to wait for reviewers after each push (default: 90)
- `-AutoFixScope All|BugsOnly` - What to auto-fix (default: All)

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `Get-UnresolvedThreads.ps1` | List unresolved (or all) threads with comment details |
| `Get-PRCommentAnalysis.ps1` | Analyze PR comments for actionability with categorization (blocking, suggestion, nitpick, question, praise) |
| `Reply-ReviewThread.ps1` | Reply to a thread by ID or index, optionally resolve |
| `Resolve-ReviewThreads.ps1` | Bulk resolve/unresolve threads |
| `Invoke-PRCompletion.ps1` | Orchestrate iterative review-fix-push-resolve cycles to drive PR to completion |

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

### Automate PR completion (agent-driven)
```powershell
# Run iterative fix loop with dry-run to see what would happen
.\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6 -DryRun

# Run actual completion workflow
$result = .\Invoke-PRCompletion.ps1 -Owner ORG -Repo REPO -PullNumber 6 -MaxIterations 3
if ($result.Status -eq 'Clean') {
    Write-Host "PR is ready to merge!"
}
else {
    Write-Host "PR still has $($result.Remaining) unresolved threads"
}
```
