<#
.SYNOPSIS
    Resolve (or unresolve) PR review threads via GraphQL.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER ThreadIds
    Specific thread IDs to resolve. If omitted, resolves ALL unresolved threads.

.PARAMETER Unresolve
    If set, unresolves instead of resolving.

.PARAMETER All
    Resolve all unresolved threads (required if -ThreadIds not provided, as a safety check).

.EXAMPLE
    .\Resolve-ReviewThreads.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -All

.EXAMPLE
    .\Resolve-ReviewThreads.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -ThreadIds "PRRT_xxx","PRRT_yyy"

.EXAMPLE
    .\Resolve-ReviewThreads.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -All -Unresolve
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [string[]]$ThreadIds,
    [switch]$Unresolve,
    [switch]$All
)

$action = if ($Unresolve) { "unresolveReviewThread" } else { "resolveReviewThread" }
$label = if ($Unresolve) { "Unresolved" } else { "Resolved" }

# If no specific IDs, fetch all matching threads
if (-not $ThreadIds) {
    if (-not $All) {
        Write-Error "Provide -ThreadIds or use -All to affect all threads"
        exit 1
    }

    $result = gh api graphql -f query="
    {
      repository(owner: `"$Owner`", name: `"$Repo`") {
        pullRequest(number: $PullNumber) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
            }
          }
        }
      }
    }" | ConvertFrom-Json

    $threads = $result.data.repository.pullRequest.reviewThreads.nodes
    $targetResolved = if ($Unresolve) { $true } else { $false }
    $ThreadIds = ($threads | Where-Object { $_.isResolved -eq $targetResolved }).id

    if ($ThreadIds.Count -eq 0) {
        Write-Host "No threads to $($label.ToLower())." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "$($label): $($ThreadIds.Count) thread(s)" -ForegroundColor Cyan

foreach ($id in $ThreadIds) {
    gh api graphql -f query="
    mutation {
      $action(input: { threadId: `"$id`" }) {
        thread { isResolved }
      }
    }" | Out-Null
    Write-Host "  $label $id" -ForegroundColor Green
}

Write-Host "Done." -ForegroundColor Green
