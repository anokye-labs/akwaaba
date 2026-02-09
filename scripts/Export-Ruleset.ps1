<#
.SYNOPSIS
    Export GitHub repository rulesets to JSON files.

.DESCRIPTION
    Fetches repository rulesets from the GitHub API and saves them to 
    .github/rulesets/ directory with detailed comments and documentation.

.PARAMETER Owner
    The repository owner (organization or user).

.PARAMETER Repo
    The repository name.

.PARAMETER RulesetId
    Optional. The ID of a specific ruleset to export. If not provided, exports all rulesets.

.PARAMETER OutputPath
    The directory where ruleset JSON files should be saved. 
    Defaults to .github/rulesets/

.PARAMETER Token
    GitHub Personal Access Token. If not provided, will use GITHUB_TOKEN environment variable.

.EXAMPLE
    # Export all rulesets from a repository
    ./Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba"

.EXAMPLE
    # Export a specific ruleset by ID
    ./Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId 12345

.EXAMPLE
    # Export with custom output path
    ./Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputPath "./rulesets/"

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated, or a valid GITHUB_TOKEN.
    API Reference: https://docs.github.com/en/rest/repos/rules
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [int]$RulesetId,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".github/rulesets",

    [Parameter(Mandatory = $false)]
    [string]$Token
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to get GitHub token
function Get-GitHubToken {
    if ($Token) {
        return $Token
    }
    
    if ($env:GITHUB_TOKEN) {
        return $env:GITHUB_TOKEN
    }
    
    if ($env:GH_TOKEN) {
        return $env:GH_TOKEN
    }
    
    throw "No GitHub token found. Please provide -Token parameter or set GITHUB_TOKEN environment variable."
}

# Function to call GitHub API
function Invoke-GitHubAPI {
    param(
        [string]$Endpoint,
        [string]$Token
    )
    
    $headers = @{
        "Authorization" = "token $Token"
        "Accept"        = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com$Endpoint" -Headers $headers -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to call GitHub API: $_"
        throw
    }
}

# Function to add explanatory comments to ruleset JSON
function Add-RulesetComments {
    param(
        [string]$Name,
        [object]$Ruleset
    )
    
    $comments = @{
        "id"                     = "Unique identifier for this ruleset"
        "name"                   = "Display name of the ruleset"
        "target"                 = "What this ruleset applies to (branch, tag, etc.)"
        "source_type"            = "Where this ruleset is defined (Repository, Organization)"
        "source"                 = "The source repository or organization"
        "enforcement"            = "Enforcement level: active, evaluate, or disabled"
        "conditions"             = "Conditions that determine when this ruleset applies"
        "rules"                  = "Array of protection rules enforced by this ruleset"
        "bypass_actors"          = "Users/teams/apps that can bypass these rules"
        "node_id"                = "GraphQL node ID for this ruleset"
        "pull_request"           = "Requires pull requests before merging"
        "required_approving_review_count" = "Minimum number of approving reviews required"
        "dismiss_stale_reviews_on_push" = "Automatically dismiss approvals when new commits are pushed"
        "require_code_owner_review" = "Require review from code owners"
        "require_last_push_approval" = "Require approval from someone other than the last pusher"
        "required_review_thread_resolution" = "All review conversations must be resolved"
        "required_status_checks" = "Status checks that must pass before merging"
        "strict_required_status_checks_policy" = "Require branches to be up to date before merging"
        "required_deployment_environments" = "Deployment environments that must succeed"
        "deletion"               = "Prevents branch deletion"
        "non_fast_forward"       = "Prevents force pushes and branch rewrites"
        "required_linear_history" = "Requires linear commit history (no merge commits)"
        "required_signatures"    = "Requires commits to be signed"
        "ref_name"               = "Git ref pattern that this ruleset applies to"
    }
    
    $output = @"
{
  "_comment": "GitHub Repository Ruleset Configuration",
  "_description": "This file defines branch protection rules for the $Name",
  "_export_command": "pwsh -File scripts/Export-Ruleset.ps1 -Owner anokye-labs -Repo akwaaba",
  "_api_reference": "https://docs.github.com/en/rest/repos/rules",
  "_last_exported": "$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')"

"@

    # Add each field with its comment
    $json = $Ruleset | ConvertTo-Json -Depth 10
    $output += "," + $json.TrimStart("{").TrimEnd("}")
    $output += "`n}"
    
    return $output
}

# Main execution
try {
    Write-Host "Exporting GitHub rulesets..." -ForegroundColor Cyan
    
    # Get authentication token
    $authToken = Get-GitHubToken
    Write-Host "✓ Authentication token found" -ForegroundColor Green
    
    # Create output directory if it doesn't exist
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
        Write-Host "✓ Created output directory: $OutputPath" -ForegroundColor Green
    }
    
    # Fetch rulesets
    if ($RulesetId) {
        Write-Host "Fetching ruleset ID $RulesetId..." -ForegroundColor Yellow
        $ruleset = Invoke-GitHubAPI -Endpoint "/repos/$Owner/$Repo/rulesets/$RulesetId" -Token $authToken
        $rulesets = @($ruleset)
    }
    else {
        Write-Host "Fetching all rulesets..." -ForegroundColor Yellow
        $rulesets = Invoke-GitHubAPI -Endpoint "/repos/$Owner/$Repo/rulesets" -Token $authToken
    }
    
    if ($rulesets.Count -eq 0) {
        Write-Warning "No rulesets found for $Owner/$Repo"
        return
    }
    
    Write-Host "✓ Found $($rulesets.Count) ruleset(s)" -ForegroundColor Green
    
    # Export each ruleset
    foreach ($ruleset in $rulesets) {
        $rulesetName = $ruleset.name -replace '\s', '-' -replace '[^a-zA-Z0-9-]', ''
        $fileName = "$rulesetName.json".ToLower()
        $filePath = Join-Path $OutputPath $fileName
        
        Write-Host "Exporting '$($ruleset.name)' to $fileName..." -ForegroundColor Yellow
        
        # Add comments and save
        $commentedJson = Add-RulesetComments -Name $ruleset.name -Ruleset $ruleset
        $commentedJson | Out-File -FilePath $filePath -Encoding UTF8
        
        Write-Host "✓ Saved to: $filePath" -ForegroundColor Green
    }
    
    Write-Host "`n✓ Export completed successfully!" -ForegroundColor Green
    Write-Host "Exported files are in: $OutputPath" -ForegroundColor Cyan
}
catch {
    Write-Error "Export failed: $_"
    exit 1
}
