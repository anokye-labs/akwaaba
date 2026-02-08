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

# Get path to Get-DagStatus.ps1 in scripts directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$getDagStatusPath = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir))) "scripts" "Get-DagStatus.ps1"

# Delegate to Get-DagStatus.ps1 with Tree format
Write-Host "`nHierarchy for #${IssueNumber}:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Call Get-DagStatus with appropriate parameters
& $getDagStatusPath -IssueNumber $IssueNumber -Format Tree -MaxDepth $Depth
