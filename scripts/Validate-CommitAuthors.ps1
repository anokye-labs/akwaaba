#!/usr/bin/env pwsh
<#
.SYNOPSIS
Validates that all commits in a PR are from approved agents.

.DESCRIPTION
This script validates that commits in a pull request are authored by
approved agents listed in .github/approved-agents.json. It enforces
the agent-only commit pattern for repository governance.

.PARAMETER Owner
Repository owner (username or organization)

.PARAMETER Repo
Repository name

.PARAMETER PullNumber
Pull request number to validate

.PARAMETER AllowlistPath
Path to the approved agents allowlist JSON file
Default: .github/approved-agents.json

.PARAMETER EmergencyBypassLabel
Label that allows bypassing validation in emergencies
Default: emergency-merge

.EXAMPLE
./Validate-CommitAuthors.ps1 -Owner "anokye-labs" -Repo "akwaaba" -PullNumber 123

.NOTES
Requires GitHub CLI (gh) to be installed and authenticated.
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
    [string]$AllowlistPath = ".github/approved-agents.json",

    [Parameter(Mandatory = $false)]
    [string]$EmergencyBypassLabel = "emergency-merge"
)

$ErrorActionPreference = "Stop"

# Function to load approved agents from allowlist
function Get-ApprovedAgents {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error "Allowlist file not found: $Path"
        return @()
    }

    $allowlist = Get-Content $Path -Raw | ConvertFrom-Json
    return $allowlist.agents
}

# Function to check if a username is an approved agent
function Test-ApprovedAgent {
    param(
        [string]$Username,
        [array]$ApprovedAgents
    )

    foreach ($agent in $ApprovedAgents) {
        if ($agent.username -eq $Username) {
            return $true
        }
    }
    return $false
}

# Function to get commits from a PR
function Get-PRCommits {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$PullNumber
    )

    $query = @"
query {
  repository(owner: \"$Owner\", name: \"$Repo\") {
    pullRequest(number: $PullNumber) {
      commits(first: 100) {
        nodes {
          commit {
            oid
            message
            author {
              name
              email
              user {
                login
              }
            }
            committer {
              name
              email
              user {
                login
              }
            }
          }
        }
      }
      labels(first: 10) {
        nodes {
          name
        }
      }
    }
  }
}
"@

    $result = gh api graphql -f query="$query" | ConvertFrom-Json
    return $result.data.repository.pullRequest
}

# Main validation logic
Write-Host "🔍 Validating commit authors for PR #$PullNumber in ${Owner}/${Repo}"
Write-Host ""

# Load approved agents
$approvedAgents = Get-ApprovedAgents -Path $AllowlistPath
Write-Host "✅ Loaded $($approvedAgents.Count) approved agents from allowlist"
Write-Host ""

# Get PR data
$prData = Get-PRCommits -Owner $Owner -Repo $Repo -PullNumber $PullNumber
$commits = $prData.commits.nodes
$labels = $prData.labels.nodes | ForEach-Object { $_.name }

Write-Host "📝 Found $($commits.Count) commits to validate"
Write-Host ""

# Check for emergency bypass label
$hasBypassLabel = $labels -contains $EmergencyBypassLabel
if ($hasBypassLabel) {
    Write-Host "⚠️  WARNING: Emergency bypass label '$EmergencyBypassLabel' detected!" -ForegroundColor Yellow
    Write-Host "⚠️  Validation is bypassed for this PR. This event will be logged." -ForegroundColor Yellow
    Write-Host ""
    # Log the bypass for audit trail
    $logEntry = @{
        timestamp = Get-Date -Format "o"
        pr = $PullNumber
        repo = "${Owner}/${Repo}"
        action = "emergency-bypass"
        label = $EmergencyBypassLabel
    }
    Write-Host "Audit log: $($logEntry | ConvertTo-Json -Compress)"
    exit 0
}

# Validate each commit
$invalidCommits = @()
$validCommits = @()

foreach ($commitNode in $commits) {
    $commit = $commitNode.commit
    $sha = $commit.oid.Substring(0, 7)
    
    # Get author username - try user login first, fall back to email
    $authorUsername = $null
    if ($commit.author.user -and $commit.author.user.login) {
        $authorUsername = $commit.author.user.login
    } else {
        # Extract username from email for bot commits
        if ($commit.author.email -match '^(\d+)\+(.+)@users\.noreply\.github\.com$') {
            $authorUsername = $Matches[2]
        } elseif ($commit.author.email -match '^(.+)@users\.noreply\.github\.com$') {
            $authorUsername = $Matches[1]
        }
    }

    # Check if author is approved
    if ($authorUsername -and (Test-ApprovedAgent -Username $authorUsername -ApprovedAgents $approvedAgents)) {
        Write-Host "✅ $sha - Approved agent: $authorUsername" -ForegroundColor Green
        $validCommits += $commit
    } else {
        $displayName = if ($authorUsername) { $authorUsername } else { $commit.author.email }
        Write-Host "❌ $sha - UNAUTHORIZED: $displayName" -ForegroundColor Red
        $invalidCommits += @{
            sha = $commit.oid
            author = $displayName
            message = $commit.message.Split("`n")[0]
        }
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════"

# Report results
if ($invalidCommits.Count -eq 0) {
    Write-Host "✅ SUCCESS: All $($validCommits.Count) commits are from approved agents" -ForegroundColor Green
    Write-Host ""
    exit 0
} else {
    Write-Host "❌ FAILURE: Found $($invalidCommits.Count) unauthorized commits" -ForegroundColor Red
    Write-Host ""
    Write-Host "Unauthorized commits:" -ForegroundColor Red
    foreach ($commit in $invalidCommits) {
        Write-Host "  • $($commit.sha.Substring(0, 7)): $($commit.author)" -ForegroundColor Red
        Write-Host "    $($commit.message)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════"
    Write-Host ""
    Write-Host "🚫 This pull request contains commits from unauthorized authors." -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 This repository follows an agent-only commit policy." -ForegroundColor Yellow
    Write-Host "   All commits must be created by approved agents or automation." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔧 To fix this issue:" -ForegroundColor Cyan
    Write-Host "   1. Set up an approved agent (GitHub Copilot, GitHub Actions, etc.)" -ForegroundColor Cyan
    Write-Host "   2. Have the agent recreate these commits" -ForegroundColor Cyan
    Write-Host "   3. Force-push to replace the unauthorized commits" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📖 For setup instructions, see: how-we-work/agent-setup.md" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🆘 Emergency bypass:" -ForegroundColor Yellow
    Write-Host "   Apply the '$EmergencyBypassLabel' label to bypass this check" -ForegroundColor Yellow
    Write-Host "   (Requires appropriate permissions and will be audited)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "❓ Questions? Request agent approval:" -ForegroundColor Cyan
    Write-Host "   https://github.com/${Owner}/${Repo}/issues/new?template=agent-approval-request.yml" -ForegroundColor Cyan
    Write-Host ""
    
    exit 1
}
