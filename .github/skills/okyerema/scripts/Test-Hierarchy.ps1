# Test-Hierarchy.ps1
# Verify issue relationships via GraphQL
# Now a thin wrapper around Get-DagStatus.ps1

param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][int]$IssueNumber,
    [int]$Depth = 2
)

$ErrorActionPreference = "Stop"

# Find repository root and Get-DagStatus.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = $scriptDir
# Navigate up from .github/skills/okyerema/scripts to repository root
for ($i = 0; $i -lt 4; $i++) {
    $repoRoot = Split-Path -Parent $repoRoot
}
$getDagStatusPath = Join-Path $repoRoot "scripts" "Get-DagStatus.ps1"

# Delegate to Get-DagStatus.ps1 with Tree format
Write-Host "`nHierarchy for #${IssueNumber}:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Call Get-DagStatus with appropriate parameters
& $getDagStatusPath -IssueNumber $IssueNumber -Format Tree -MaxDepth $Depth
