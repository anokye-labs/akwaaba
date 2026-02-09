<#
.SYNOPSIS
    Examples for Validate-CommitAuthors.ps1

.DESCRIPTION
    Demonstrates various usage patterns for the commit author validation script.
    
.NOTES
    Author: Anokye Labs
#>

# Example 1: Basic validation of a PR with JSON output
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 1: Validate PR #42 (JSON output)" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Command:" -ForegroundColor Yellow
Write-Host '  ./Validate-CommitAuthors.ps1 -PRNumber 42 -Owner anokye-labs -Repo akwaaba -OutputFormat Json' -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Integrate with CI/CD pipelines for automated validation" -ForegroundColor DarkGray
Write-Host ""

# Example 2: Console output with correlation ID for tracing
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 2: Validate PR with Console output and tracing" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Command:" -ForegroundColor Yellow
Write-Host '  ./Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Console -CorrelationId "workflow-123"' -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Interactive validation with detailed console output and audit trail" -ForegroundColor DarkGray
Write-Host ""

# Example 3: Markdown output for GitHub comments
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 3: Validate PR with Markdown output" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Command:" -ForegroundColor Yellow
Write-Host '  ./Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Markdown > validation-report.md' -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Generate validation report for GitHub PR comments" -ForegroundColor DarkGray
Write-Host ""

# Example 4: DryRun mode to preview validation
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 4: Dry run validation" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Command:" -ForegroundColor Yellow
Write-Host '  ./Validate-CommitAuthors.ps1 -PRNumber 42 -DryRun' -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Preview validation without making API calls" -ForegroundColor DarkGray
Write-Host ""

# Example 5: Custom allowlist path
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 5: Validate with custom allowlist" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Command:" -ForegroundColor Yellow
Write-Host '  ./Validate-CommitAuthors.ps1 -PRNumber 42 -AllowlistPath ".github/custom-agents.json"' -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Test with a custom or staging allowlist configuration" -ForegroundColor DarkGray
Write-Host ""

# Example 6: GitHub Actions workflow integration
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 6: GitHub Actions Integration" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Workflow YAML:" -ForegroundColor Yellow
Write-Host @"
  - name: Validate Commit Authors
    run: |
      pwsh -File scripts/Validate-CommitAuthors.ps1 \
        -PRNumber `${{ github.event.pull_request.number }} \
        -Owner `${{ github.repository_owner }} \
        -Repo `${{ github.event.repository.name }} \
        -OutputFormat Json > validation-result.json
      
      # Check if valid
      `$result = Get-Content validation-result.json | ConvertFrom-Json
      if (-not `$result.Valid) {
        Write-Error "Validation failed: PR contains commits from unapproved authors"
        exit 1
      }
"@ -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Automated PR validation in GitHub Actions workflow" -ForegroundColor DarkGray
Write-Host ""

# Example 7: Parsing JSON output in scripts
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 7: Parse JSON output in PowerShell" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Script:" -ForegroundColor Yellow
Write-Host @'
  $jsonOutput = ./Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Json
  $result = $jsonOutput | ConvertFrom-Json
  
  if ($result.Valid) {
      Write-Host "✅ All commits from approved agents" -ForegroundColor Green
      Write-Host "Approved agents: $($result.ApprovedAgents.id -join ', ')" -ForegroundColor Gray
  }
  else {
      Write-Host "❌ Unapproved commits detected" -ForegroundColor Red
      foreach ($commit in $result.UnapprovedCommits) {
          Write-Host "  - $($commit.Oid): $($commit.Author.Login)" -ForegroundColor Red
      }
  }
'@ -ForegroundColor Gray
Write-Host ""
Write-Host "Use case: Programmatic validation result handling" -ForegroundColor DarkGray
Write-Host ""

# Example 8: Understanding validation results
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Example 8: Understanding the result structure" -ForegroundColor White
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Result JSON structure:" -ForegroundColor Yellow
Write-Host @'
{
  "PRNumber": 42,
  "Owner": "anokye-labs",
  "Repo": "akwaaba",
  "Valid": true,
  "Summary": {
    "TotalCommits": 5,
    "ApprovedCommits": 5,
    "UnapprovedCommits": 0,
    "GitHubAppCommits": 5,
    "HumanCommits": 0
  },
  "Commits": [
    {
      "Oid": "abc1234",
      "Message": "feat: Add new feature",
      "Author": {
        "Login": "copilot[bot]",
        "Name": "GitHub Copilot",
        "Email": "noreply@github.com"
      },
      "IsGitHubApp": true,
      "Approved": true,
      "Agent": {
        "id": "github-copilot",
        "type": "github-app",
        "username": "copilot",
        "botUsername": "copilot[bot]",
        "githubAppId": 271694,
        "description": "GitHub Copilot - AI pair programmer"
      },
      "Reason": "Approved GitHub App: GitHub Copilot - AI pair programmer"
    }
  ],
  "UnapprovedCommits": [],
  "ApprovedAgents": [
    {
      "id": "github-copilot",
      "botUsername": "copilot[bot]",
      "description": "GitHub Copilot - AI pair programmer"
    }
  ]
}
'@ -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "For more information, see:" -ForegroundColor White
Write-Host "  - Get-Help ./Validate-CommitAuthors.ps1 -Full" -ForegroundColor Gray
Write-Host "  - .github/approved-agents.json (allowlist configuration)" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
