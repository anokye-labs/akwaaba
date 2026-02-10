#!/usr/bin/env pwsh
<#
.SYNOPSIS
Validates that all commits in a PR are from approved agents.

.DESCRIPTION
Enforces the agent-only commit policy by checking each commit author
against the approved agents list. Provides clear error messages when
human commits are detected.

.PARAMETER Owner
Repository owner (organization or user)

.PARAMETER Repo
Repository name

.PARAMETER PullRequestNumber
Pull request number to validate

.PARAMETER ApprovedAgentsPath
Path to approved-agents.json file (default: .github/approved-agents.json)

.EXAMPLE
./Validate-CommitAuthors.ps1 -Owner anokye-labs -Repo akwaaba -PullRequestNumber 42
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,
    
    [Parameter(Mandatory = $true)]
    [string]$Repo,
    
    [Parameter(Mandatory = $true)]
    [int]$PullRequestNumber,
    
    [Parameter(Mandatory = $false)]
    [string]$ApprovedAgentsPath = ".github/approved-agents.json"
)

$ErrorActionPreference = "Stop"

# Function to load approved agents
function Get-ApprovedAgents {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error "Approved agents configuration not found at: $Path"
        return $null
    }
    
    $config = Get-Content $Path -Raw | ConvertFrom-Json
    return $config
}

# Function to check if an author is approved
function Test-ApprovedAuthor {
    param(
        [string]$Author,
        [object]$Config
    )
    
    # Check if author matches any approved agent username
    foreach ($agent in $Config.agents) {
        if ($Author -eq $agent.username) {
            return $true
        }
        # Also check for [bot] suffix (GitHub Apps appear as username[bot])
        if ($Author -eq "$($agent.username)[bot]") {
            return $true
        }
    }
    
    return $false
}

# Function to generate helpful error message
function Get-ErrorMessage {
    param(
        [array]$HumanCommits,
        [object]$Config
    )
    
    $message = @"
❌ **Human Commits Detected**

This repository follows an **agent-only commit policy**. All code changes must be made by approved AI agents, not humans.

**Policy Violation:**
The following commits were made by human users instead of approved agents:

"@

    foreach ($commit in $HumanCommits) {
        $message += "`n- ``$($commit.sha)`` by **$($commit.author)**: $($commit.message)"
    }
    
    $message += @"


**Why Agent-Only?**

The Anokye-Krom system follows a "Humans Plan, Agents Code" philosophy:
- **Humans:** Create issues, review PRs, provide feedback
- **Agents:** Write all code, make all commits, create PRs

This separation ensures:
- Clear separation of concerns
- Consistent code quality through AI
- Full audit trail of all changes
- Issue-driven development

**How to Fix This:**

1. **Close this PR** - Human commits cannot be merged
2. **Create a GitHub issue** describing what needs to be done
3. **Assign an approved agent** (e.g., @copilot) to the issue
4. **Let the agent create the PR** with the necessary changes

**Setting Up an Agent:**

If you need to use an AI agent for this work:
- Read the agent setup guide: $($Config.policy.documentation_url)
- Review agent conventions: https://github.com/anokye-labs/akwaaba/blob/main/how-we-work/agent-conventions.md
- See how we work: https://github.com/anokye-labs/akwaaba/blob/main/how-we-work.md

**Request New Agent Approval:**

If you need a new agent approved for this repository:
- Submit a request: $($Config.policy.request_approval_url)
- Provide: agent name, purpose, authentication method
- Allow 1-2 business days for review

**Currently Approved Agents:**

"@

    foreach ($agent in $Config.agents) {
        $message += "`n- **$($agent.username)** ($($agent.type)): $($agent.description)"
    }
    
    $message += @"


**Questions?**

- Read our documentation: https://github.com/anokye-labs/akwaaba
- Open a discussion: https://github.com/anokye-labs/akwaaba/discussions
- Contact: Anokye Labs team

---
*This check is enforced by the Agent Authentication workflow*
"@

    return $message
}

# Main execution
Write-Host "🔍 Validating commit authors for PR #$PullRequestNumber..."

# Load approved agents configuration
$config = Get-ApprovedAgents -Path $ApprovedAgentsPath
if ($null -eq $config) {
    Write-Error "Failed to load approved agents configuration"
    exit 1
}

Write-Host "✓ Loaded approved agents configuration"
Write-Host "  Policy enforcement: $($config.policy.enforcement)"
Write-Host "  Approved agents: $($config.agents.Count)"

# Fetch commits from the PR using GitHub CLI
Write-Host "Fetching commits from PR #$PullRequestNumber..."

$commitsJson = gh pr view $PullRequestNumber `
    --repo "$Owner/$Repo" `
    --json commits `
    --jq '.commits'

if (-not $commitsJson) {
    Write-Error "Failed to fetch commits from PR"
    exit 1
}

$commits = $commitsJson | ConvertFrom-Json

if ($commits.Count -eq 0) {
    Write-Host "⚠️  No commits found in PR"
    exit 0
}

Write-Host "✓ Found $($commits.Count) commit(s) to validate"

# Validate each commit
$humanCommits = @()

foreach ($commit in $commits) {
    $sha = $commit.oid.Substring(0, 7)
    $author = $commit.authors[0].login
    $message = ($commit.messageHeadline -split "`n")[0]
    
    Write-Host "  Checking commit $sha by $author..."
    
    if (-not (Test-ApprovedAuthor -Author $author -Config $config)) {
        Write-Host "    ❌ NOT APPROVED: $author" -ForegroundColor Red
        $humanCommits += @{
            sha = $sha
            author = $author
            message = $message
        }
    } else {
        Write-Host "    ✓ Approved agent: $author" -ForegroundColor Green
    }
}

# Report results
if ($humanCommits.Count -eq 0) {
    Write-Host "`n✅ All commits are from approved agents!" -ForegroundColor Green
    Write-Host "   Agent authentication check: PASSED"
    exit 0
} else {
    Write-Host "`n❌ Found $($humanCommits.Count) commit(s) from unauthorized users" -ForegroundColor Red
    Write-Host ""
    
    # Generate and output error message
    $errorMessage = Get-ErrorMessage -HumanCommits $humanCommits -Config $config
    Write-Host $errorMessage
    
    # Also output to a file that can be used by the workflow
    $errorMessage | Out-File -FilePath "agent-auth-error.txt" -Encoding utf8
    
    Write-Host "`n---"
    Write-Host "Agent authentication check: FAILED" -ForegroundColor Red
    exit 1
}
