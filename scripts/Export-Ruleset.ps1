#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Exports a GitHub repository ruleset to JSON format.

.DESCRIPTION
    This script retrieves a repository ruleset configuration from GitHub via the REST API
    and exports it to a JSON file. This allows rulesets to be version controlled and
    documented alongside the repository code.

.PARAMETER Owner
    The GitHub organization or user name that owns the repository.

.PARAMETER Repo
    The name of the GitHub repository.

.PARAMETER RulesetId
    The ID of the ruleset to export. Can be found in the URL when viewing the ruleset
    in GitHub Settings (e.g., Settings > Rules > Rulesets > [ruleset-name]).
    Optional if RulesetName is provided.

.PARAMETER RulesetName
    The name of the ruleset to export (e.g., "Main Branch Protection").
    Optional if RulesetId is provided. If multiple rulesets have the same name,
    the first one found will be used.

.PARAMETER OutputPath
    The path where the exported JSON file should be saved.
    Defaults to ".github/rulesets/<ruleset-name>.json"

.PARAMETER Token
    GitHub Personal Access Token with 'repo' scope. If not provided, the script
    will attempt to use the GITHUB_TOKEN environment variable.

.EXAMPLE
    ./Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId 12345

    Exports ruleset with ID 12345 to the default output location.

.EXAMPLE
    ./Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetName "Main Branch Protection"

    Exports the ruleset named "Main Branch Protection" to the default output location.

.EXAMPLE
    $env:GITHUB_TOKEN = "ghp_xxxxxxxxxxxx"
    ./Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId 12345 -OutputPath "./my-ruleset.json"

    Exports ruleset using environment variable for authentication to a custom path.

.NOTES
    Requires GitHub token with appropriate permissions (repo scope).
    The exported JSON includes inline comments for documentation purposes.
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
    [string]$RulesetName,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$Token
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $color = switch ($Type) {
        "Info" { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }
    
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

# Validate parameters
if (-not $RulesetId -and -not $RulesetName) {
    Write-Status "Either RulesetId or RulesetName must be provided" -Type Error
    exit 1
}

# Get GitHub token
if (-not $Token) {
    $Token = $env:GITHUB_TOKEN
    if (-not $Token) {
        Write-Status "GitHub token not found. Please provide -Token parameter or set GITHUB_TOKEN environment variable" -Type Error
        exit 1
    }
}

Write-Status "Starting ruleset export for $Owner/$Repo"

# GitHub API base URL
$apiBase = "https://api.github.com"
$headers = @{
    "Accept" = "application/vnd.github+json"
    "Authorization" = "Bearer $Token"
    "X-GitHub-Api-Version" = "2022-11-28"
}

try {
    # If RulesetName is provided but not RulesetId, look up the ID
    if ($RulesetName -and -not $RulesetId) {
        Write-Status "Looking up ruleset by name: $RulesetName"
        
        $rulesetsUrl = "$apiBase/repos/$Owner/$Repo/rulesets"
        $response = Invoke-RestMethod -Uri $rulesetsUrl -Headers $headers -Method Get
        
        $ruleset = $response | Where-Object { $_.name -eq $RulesetName } | Select-Object -First 1
        
        if (-not $ruleset) {
            Write-Status "Ruleset '$RulesetName' not found in repository $Owner/$Repo" -Type Error
            Write-Status "Available rulesets:" -Type Info
            $response | ForEach-Object { Write-Host "  - $($_.name) (ID: $($_.id))" }
            exit 1
        }
        
        $RulesetId = $ruleset.id
        Write-Status "Found ruleset ID: $RulesetId"
    }

    # Fetch the ruleset
    Write-Status "Fetching ruleset with ID: $RulesetId"
    $rulesetUrl = "$apiBase/repos/$Owner/$Repo/rulesets/$RulesetId"
    $ruleset = Invoke-RestMethod -Uri $rulesetUrl -Headers $headers -Method Get

    # Determine output path
    if (-not $OutputPath) {
        $safeRulesetName = $ruleset.name -replace '[^a-zA-Z0-9-]', '-' -replace '--+', '-'
        $safeRulesetName = $safeRulesetName.Trim('-').ToLower()
        $OutputPath = ".github/rulesets/$safeRulesetName.json"
    }

    # Create output directory if it doesn't exist
    $outputDir = Split-Path -Path $OutputPath -Parent
    if ($outputDir -and -not (Test-Path -Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
        Write-Status "Created directory: $outputDir"
    }

    # Add documentation comments to the ruleset
    $documentedRuleset = [ordered]@{
        "_comment" = "Exported ruleset configuration for GitHub branch protection"
        "_repository" = "$Owner/$Repo"
        "_ruleset_id" = $ruleset.id
        "_export_command" = "pwsh -File scripts/Export-Ruleset.ps1 -Owner ""$Owner"" -Repo ""$Repo"" -RulesetId $($ruleset.id)"
        "_last_exported" = (Get-Date -Format "yyyy-MM-dd")
        "_github_url" = "https://github.com/$Owner/$Repo/settings/rules/$($ruleset.id)"
    }

    # Add ruleset properties
    $ruleset.PSObject.Properties | Where-Object { $_.Name -notin @('id', 'node_id', '_links', 'source_type', 'source', 'created_at', 'updated_at') } | ForEach-Object {
        $documentedRuleset[$_.Name] = $_.Value
    }

    # Add comments for specific sections
    if ($documentedRuleset.ContainsKey('conditions')) {
        $documentedRuleset['_conditions_comment'] = "Branch/tag patterns where this ruleset applies"
    }
    
    if ($documentedRuleset.ContainsKey('rules')) {
        $documentedRuleset['_rules_comment'] = "Protection rules enforced by this ruleset"
    }
    
    if ($documentedRuleset.ContainsKey('bypass_actors')) {
        $documentedRuleset['_bypass_actors_comment'] = "Users/teams that can bypass these rules"
    }

    # Convert to JSON with proper formatting
    $jsonOutput = $documentedRuleset | ConvertTo-Json -Depth 10

    # Save to file
    $jsonOutput | Set-Content -Path $OutputPath -Encoding UTF8
    Write-Status "Ruleset exported successfully to: $OutputPath" -Type Success

    # Display summary
    Write-Host ""
    Write-Status "Ruleset Summary:" -Type Info
    Write-Host "  Name: $($ruleset.name)"
    Write-Host "  ID: $($ruleset.id)"
    Write-Host "  Target: $($ruleset.target)"
    Write-Host "  Enforcement: $($ruleset.enforcement)"
    Write-Host "  Rules: $($ruleset.rules.Count)"
    Write-Host "  Bypass Actors: $($ruleset.bypass_actors.Count)"
    Write-Host ""
    Write-Status "Next steps:" -Type Info
    Write-Host "  1. Review the exported JSON file"
    Write-Host "  2. Commit the file to version control"
    Write-Host "  3. Document any customizations or notes"

} catch {
    Write-Status "Failed to export ruleset: $($_.Exception.Message)" -Type Error
    Write-Status "Response: $($_.ErrorDetails.Message)" -Type Error
    exit 1
}
