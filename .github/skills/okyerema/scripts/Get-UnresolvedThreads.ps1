<#
.SYNOPSIS
    List unresolved (or all) review threads on a PR with comment details.

.PARAMETER Owner
    Repository owner.

.PARAMETER Repo
    Repository name.

.PARAMETER PullNumber
    Pull request number.

.PARAMETER IncludeResolved
    If set, shows all threads (not just unresolved).

.PARAMETER Brief
    If set, shows compact one-line-per-thread output.

.EXAMPLE
    .\Get-UnresolvedThreads.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6

.EXAMPLE
    .\Get-UnresolvedThreads.ps1 -Owner anokye-labs -Repo akwaaba -PullNumber 6 -IncludeResolved -Brief
#>
param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$PullNumber,
    [switch]$IncludeResolved,
    [switch]$Brief
)

$result = gh api graphql -f query="
{
  repository(owner: `"$Owner`", name: `"$Repo`") {
    pullRequest(number: $PullNumber) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          isCollapsed
          path
          line
          comments(first: 10) {
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
}" | ConvertFrom-Json

$threads = $result.data.repository.pullRequest.reviewThreads.nodes

if (-not $IncludeResolved) {
    $threads = $threads | Where-Object { -not $_.isResolved }
}

$total = $result.data.repository.pullRequest.reviewThreads.totalCount
$showing = $threads.Count

# Emit thread objects to pipeline for programmatic use
$threads | ForEach-Object { Write-Output $_ }

Write-Host "`n$Owner/$Repo PR #$PullNumber — $showing thread(s)" -ForegroundColor Cyan
if (-not $IncludeResolved) {
    $resolved = $total - $showing
    Write-Host "($resolved resolved, $showing unresolved)" -ForegroundColor Gray
}
Write-Host ""

for ($i = 0; $i -lt $threads.Count; $i++) {
    $t = $threads[$i]
    $firstComment = $t.comments.nodes[0]
    $status = if ($t.isResolved) { "[Resolved]" } else { "[Open]" }
    $statusColor = if ($t.isResolved) { "Green" } else { "Yellow" }
    $outdated = if ($t.isOutdated) { " (outdated)" } else { "" }

    if ($Brief) {
        $preview = ($firstComment.body -split "`n")[0]
        if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 97) + "..." }
        Write-Host "  [$i] " -ForegroundColor White -NoNewline
        Write-Host $status -ForegroundColor $statusColor -NoNewline
        Write-Host "$outdated $($t.path):$($t.line) — $preview" -ForegroundColor Gray
    }
    else {
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Write-Host "Thread [$i] " -ForegroundColor White -NoNewline
        Write-Host $status -ForegroundColor $statusColor -NoNewline
        Write-Host "$outdated" -ForegroundColor Gray
        Write-Host "  ID:   $($t.id)" -ForegroundColor DarkGray
        Write-Host "  File: $($t.path):$($t.line)" -ForegroundColor White
        Write-Host "  Comments: $($t.comments.totalCount)" -ForegroundColor Gray
        Write-Host ""

        foreach ($c in $t.comments.nodes) {
            Write-Host "  @$($c.author.login) ($($c.createdAt)):" -ForegroundColor Cyan
            $bodyLines = $c.body -split "`n" | Select-Object -First 5
            foreach ($line in $bodyLines) {
                Write-Host "    $line" -ForegroundColor White
            }
            if (($c.body -split "`n").Count -gt 5) {
                Write-Host "    ... (truncated)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }
}

if ($threads.Count -eq 0) {
    Write-Host "  No unresolved threads." -ForegroundColor Green
}
