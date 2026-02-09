# GitHub App Detection Implementation

## Overview

This document describes the GitHub App detection implementation for commit author validation in the Akwaaba repository. The implementation enforces the agent-only commit pattern by validating that all commits in a pull request are from approved agents.

## Components

### 1. Approved Agents Allowlist (`.github/approved-agents.json`)

The allowlist defines which agents and GitHub Apps are authorized to commit to the repository.

**Structure:**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "version": "1.0.0",
  "description": "Allowlist of approved agents and GitHub Apps for commit authentication",
  "agents": [
    {
      "id": "github-copilot",
      "type": "github-app",
      "username": "copilot",
      "botUsername": "copilot[bot]",
      "githubAppId": 271694,
      "description": "GitHub Copilot - AI pair programmer",
      "approvedBy": "anokye-labs",
      "approvedDate": "2026-02-09",
      "permissions": ["read", "write"],
      "enabled": true
    }
  ],
  "validation": {
    "requireBotSuffix": true,
    "allowedBotPattern": "^[a-zA-Z0-9_-]+\\[bot\\]$",
    "requireAppIdVerification": true
  }
}
```

**Fields:**
- `id`: Unique identifier for the agent
- `type`: Agent type (e.g., "github-app")
- `username`: Base username without [bot] suffix
- `botUsername`: Full bot username with [bot] suffix
- `githubAppId`: GitHub App ID for verification
- `description`: Human-readable description
- `approvedBy`: Who approved this agent
- `approvedDate`: When the agent was approved
- `permissions`: Permissions granted to the agent
- `enabled`: Whether the agent is currently active

### 2. Validation Script (`scripts/Validate-CommitAuthors.ps1`)

PowerShell script that validates commit authors against the allowlist.

**Key Features:**
- Detects GitHub Apps by checking for `[bot]` suffix
- Verifies GitHub App IDs against allowlist
- Supports multiple authentication methods
- Provides detailed validation results
- Multiple output formats (Console, JSON, Markdown)

**Usage:**
```powershell
# Basic validation
./Validate-CommitAuthors.ps1 -PRNumber 42

# With custom output format
./Validate-CommitAuthors.ps1 -PRNumber 42 -OutputFormat Json

# With custom allowlist
./Validate-CommitAuthors.ps1 -PRNumber 42 -AllowlistPath ".github/custom-agents.json"
```

**Output:**
- `Valid`: Boolean indicating if all commits are from approved agents
- `Summary`: Statistics about commits (total, approved, unapproved, GitHub App, human)
- `Commits`: Array of all commits with validation details
- `UnapprovedCommits`: Array of commits from unapproved authors
- `ApprovedAgents`: List of approved agents found in the PR

### 3. Unit Tests (`scripts/Test-Validate-CommitAuthors.ps1`)

Comprehensive test suite for the validation logic.

**Test Coverage:**
1. **GitHub App Pattern Detection** (6 tests)
   - Standard GitHub App username (copilot[bot])
   - GitHub Actions bot
   - Dependabot
   - Username without [bot] suffix
   - Human username
   - Just 'bot' keyword

2. **GitHub App ID Extraction** (3 tests)
   - Extract copilot from bot username
   - Extract github-actions from bot username
   - Extract dependabot from bot username

3. **Allowlist Validation** (5 tests)
   - Approved GitHub App (copilot)
   - Approved GitHub App (github-actions)
   - Unapproved GitHub App
   - Disabled GitHub App
   - Human user

**Results:**
- All 14 tests passing (100% success rate)

## GitHub App Detection Logic

### Detection Flow

```
1. Fetch commit from PR
   ↓
2. Extract author information
   ↓
3. Check if author username contains [bot] suffix
   ↓
   ├─ Yes → GitHub App detected
   │         ↓
   │         Extract base name (remove [bot])
   │         ↓
   │         Search allowlist for matching botUsername or username
   │         ↓
   │         Check if enabled
   │         ↓
   │         ├─ Match found → APPROVED
   │         └─ No match → REJECTED (unapproved GitHub App)
   │
   └─ No → Regular username
             ↓
             Search allowlist for exact username match
             ↓
             Check if enabled
             ↓
             ├─ Match found → APPROVED (service account)
             └─ No match → REJECTED (human or unapproved agent)
```

### Key Functions

#### `Test-GitHubAppPattern`
```powershell
function Test-GitHubAppPattern {
    param([string]$Username)
    return $Username -match '\[bot\]$'
}
```
Detects if a username is a GitHub App by checking for `[bot]` suffix.

#### `Get-GitHubAppId`
```powershell
function Get-GitHubAppId {
    param([string]$BotUsername)
    return $BotUsername -replace '\[bot\]$', ''
}
```
Extracts the base name from a GitHub App username.

#### `Test-AgentInAllowlist`
```powershell
function Test-AgentInAllowlist {
    param(
        [string]$Username,
        [object]$Allowlist
    )
    # Returns: PSCustomObject with Approved, IsGitHubApp, Agent, Reason
}
```
Validates if an agent is approved in the allowlist.

## Authentication Methods Supported

### 1. GitHub App Installation
- Standard method for GitHub Apps
- Username format: `app-name[bot]`
- Requires GitHub App ID in allowlist
- Example: `copilot[bot]`, `github-actions[bot]`

### 2. Service Account
- For non-bot service accounts
- Username format: regular username (no [bot] suffix)
- Must be explicitly listed in allowlist
- Example: custom automation accounts

### 3. OAuth App
- Apps using OAuth authentication
- Treated as regular service accounts
- Must be explicitly listed in allowlist

## Integration with GitHub Actions

### Example Workflow

Create `.github/workflows/agent-auth.yml`:

```yaml
name: Agent Authentication

on:
  pull_request:
    types: [opened, synchronize]

permissions:
  contents: read
  pull-requests: read

jobs:
  validate-authors:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Validate Commit Authors
        shell: pwsh
        run: |
          $result = ./scripts/Validate-CommitAuthors.ps1 `
            -PRNumber ${{ github.event.pull_request.number }} `
            -Owner ${{ github.repository_owner }} `
            -Repo ${{ github.event.repository.name }} `
            -OutputFormat Json | ConvertFrom-Json
          
          if (-not $result.Valid) {
            Write-Error "❌ Validation failed: PR contains commits from unapproved authors"
            
            # Output details
            Write-Host "Unapproved commits:"
            foreach ($commit in $result.UnapprovedCommits) {
              Write-Host "  - $($commit.Oid): $($commit.Author.Login) - $($commit.Reason)"
            }
            
            exit 1
          }
          
          Write-Host "✅ All commits from approved agents"
          Write-Host "Approved agents: $($result.ApprovedAgents.id -join ', ')"
```

## Adding New Agents

To add a new agent to the allowlist:

1. **Identify the agent details:**
   - GitHub App ID (if applicable)
   - Bot username (with [bot] suffix if GitHub App)
   - Base username (without [bot] suffix)
   - Description

2. **Update `.github/approved-agents.json`:**
   ```json
   {
     "id": "new-agent",
     "type": "github-app",
     "username": "new-agent",
     "botUsername": "new-agent[bot]",
     "githubAppId": 12345,
     "description": "New Agent - Purpose",
     "approvedBy": "approver-username",
     "approvedDate": "2026-02-09",
     "permissions": ["read", "write"],
     "enabled": true
   }
   ```

3. **Test the configuration:**
   ```powershell
   ./scripts/Test-Validate-CommitAuthors.ps1
   ```

4. **Commit and push the change**

## Audit and Security

### Audit Features
- All validations can be traced with correlation IDs
- Detailed logging of validation results
- Clear rejection reasons for unapproved commits

### Security Best Practices
1. **Regularly review the allowlist** - Remove unused or compromised agents
2. **Enable only necessary agents** - Use the `enabled` field to control access
3. **Document approval process** - Track `approvedBy` and `approvedDate`
4. **Monitor validation failures** - Alert on unexpected rejection patterns
5. **Rotate GitHub App credentials** - Follow GitHub's security recommendations

## Troubleshooting

### Common Issues

#### 1. Validation fails for approved agent
**Symptom:** Agent is in allowlist but validation fails

**Solutions:**
- Verify the agent is `enabled: true`
- Check username format matches exactly (case-sensitive)
- For GitHub Apps, ensure `[bot]` suffix is present
- Verify GitHub App ID is correct

#### 2. Cannot extract commit author
**Symptom:** Error fetching commit information

**Solutions:**
- Ensure `GH_TOKEN` or `GITHUB_TOKEN` has correct permissions
- Verify repository access for the token
- Check if PR number exists and is accessible

#### 3. Allowlist file not found
**Symptom:** Script cannot load allowlist

**Solutions:**
- Verify file exists at `.github/approved-agents.json`
- Check file permissions
- Use `-AllowlistPath` parameter to specify custom location

## Future Enhancements

Potential improvements identified:

1. **Self-service agent registration** - Web UI for requesting agent approval
2. **Temporary agent access** - Time-limited approvals for testing
3. **Role-based permissions** - Different permission levels per agent
4. **Audit log export** - Export validation history for compliance
5. **Multi-repo allowlist** - Shared allowlist across organization
6. **Webhook notifications** - Alert on validation failures
7. **Metrics dashboard** - Visualize validation statistics

## References

- [Planning Document: Agent Authentication Workflow](../planning/phase-2-governance/03-workflow-agent-auth.md)
- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [GitHub GraphQL API](https://docs.github.com/en/graphql)
- [Anokye-Krom System Principles](../README.md#the-anokye-krom-system)

## Version History

- **1.0.0** (2026-02-09) - Initial implementation
  - GitHub App detection with [bot] suffix
  - Allowlist validation
  - Multiple output formats
  - Comprehensive test suite (14 tests, 100% pass rate)
