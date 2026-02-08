# Get-IssueTypeIds.ps1
# Retrieve organization issue type IDs for use in GraphQL mutations
# Now delegates to Get-RepoContext.ps1 for retrieving issue types

param(
    [Parameter(Mandatory=$false)]
    [string]$Owner,
    
    [Parameter(Mandatory=$false)]
    [switch]$Refresh
)

# Import Get-RepoContext from scripts directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$getRepoContextPath = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir))) "scripts" "Get-RepoContext.ps1"

# Get repository context (includes issue types)
$context = & $getRepoContextPath -Refresh:$Refresh

# Extract issue types and format as hashtable
$types = @{}
foreach ($type in $context.IssueTypes) {
    $types[$type.Name] = $type.Id
}

# Output as hashtable
$types

# Also display
if ($context.IssueTypes.Count -gt 0) {
    $context.IssueTypes | ForEach-Object {
        [PSCustomObject]@{
            name = $_.Name
            id = $_.Id
        }
    } | Format-Table name, id
} else {
    Write-Warning "No issue types found. Note: Get-RepoContext may not support direct issue type querying for all organizations."
}
