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

1. **Read** unresolved threads → `Get-UnresolvedThreads.ps1`
2. **Fix** the code
3. **Commit & push** to the PR branch
4. **Reply** to each thread explaining the fix → `Reply-ReviewThread.ps1 -Resolve`
5. **Verify** no unresolved threads remain → `Get-UnresolvedThreads.ps1`

## Helper Scripts

| Script | Purpose |
|--------|---------|
| `Get-UnresolvedThreads.ps1` | List unresolved (or all) threads with comment details |
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
