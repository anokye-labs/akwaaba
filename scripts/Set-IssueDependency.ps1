<#
.SYNOPSIS
    Express blocking/dependency relationships between GitHub issues.

.DESCRIPTION
    This script manages issue dependencies by updating issue bodies with a Dependencies section.
    Since GitHub has no native dependency tracking, this uses body-text convention to document:
    - "Blocked by" relationships (issues that must be resolved first)
    - "Blocks" relationships (issues that depend on this one)
    
    The script automatically cross-references both directions:
    - If issue #20 depends on #14, then #20's body shows "Blocked by: #14"
      and #14's body shows "Blocks: #20"
    
    Wave indicators can be added to show when work can start.

.PARAMETER IssueNumber
    The issue number to update with dependencies.

.PARAMETER DependsOn
    Array of issue numbers that block this issue (issues that must be resolved first).
    Can include full references like "anokye-labs/akwaaba#14" or just numbers like "14".

.PARAMETER Blocks
    Array of issue numbers that this issue blocks (issues that depend on this one).
    Can include full references like "anokye-labs/akwaaba#20" or just numbers like "20".

.PARAMETER Wave
    Optional wave number indicating when work can start (e.g., "1" means "Cannot start until all dependencies are merged").

.PARAMETER DryRun
    If specified, logs the changes without executing them.

.PARAMETER CorrelationId
    Optional correlation ID for tracing. If not provided, one will be generated.

.EXAMPLE
    # Set issue #20 to depend on issues #14, #16, and #17
    ./Set-IssueDependency.ps1 -IssueNumber 20 -DependsOn @(14, 16, 17) -Wave 1

.EXAMPLE
    # Set issue #14 to block issue #20
    ./Set-IssueDependency.ps1 -IssueNumber 14 -Blocks @(20)

.EXAMPLE
    # Test changes without executing
    ./Set-IssueDependency.ps1 -IssueNumber 20 -DependsOn @(14, 16, 17) -DryRun

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if the operation succeeded
    - IssueNumber: The issue number that was updated
    - UpdatedDependencies: Array of dependencies that were set
    - UpdatedBlockers: Array of blockers that were set
    - CrossReferencesUpdated: Number of cross-references that were updated
    - CorrelationId: The correlation ID for this request

.NOTES
    Requires:
    - PowerShell 7.x or higher
    - GitHub CLI (gh) installed and authenticated
    - Invoke-GraphQL.ps1 in the same directory
    - ConvertTo-EscapedGraphQL.ps1 in the same directory
    - Write-OkyeremaLog.ps1 in ../.github/skills/okyerema/scripts/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [int]$IssueNumber,

    [Parameter(Mandatory = $false)]
    [string[]]$DependsOn = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$Blocks = @(),

    [Parameter(Mandatory = $false)]
    [int]$Wave = 0,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$CorrelationId
)

$ErrorActionPreference = "Stop"

# Generate correlation ID if not provided
if (-not $CorrelationId) {
    $CorrelationId = [guid]::NewGuid().ToString()
}

# Import required functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir/Invoke-GraphQL.ps1"
. "$scriptDir/ConvertTo-EscapedGraphQL.ps1"

$logScript = "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"
if (Test-Path $logScript) {
    . $logScript
} else {
    # Fallback if Write-OkyeremaLog is not available
    function Write-OkyeremaLog {
        param($Message, $Level = "Info", $Operation = "", $CorrelationId = "")
        Write-Verbose "[$Level] $Message"
    }
}

Write-OkyeremaLog -Message "Starting dependency update for issue ${IssueNumber}" `
    -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId

# Validate that at least one of DependsOn or Blocks is provided
if ($DependsOn.Count -eq 0 -and $Blocks.Count -eq 0) {
    throw "At least one of -DependsOn or -Blocks must be provided"
}

# Function to normalize issue reference to full format
function Get-NormalizedIssueRef {
    param([string]$ref)
    
    # If already in full format (owner/repo#number), return as-is
    if ($ref -match '^[^/]+/[^#]+#\d+$') {
        return $ref
    }
    
    # If just a number, get current repo context
    if ($ref -match '^\d+$') {
        $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
        return "$($repoInfo.nameWithOwner)#$ref"
    }
    
    # If #number format, get current repo context
    if ($ref -match '^#(\d+)$') {
        $repoInfo = gh repo view --json nameWithOwner | ConvertFrom-Json
        return "$($repoInfo.nameWithOwner)#$($Matches[1])"
    }
    
    throw "Invalid issue reference format: $ref"
}

# Function to extract repo and issue number from reference
function Get-IssueComponents {
    param([string]$ref)
    
    if ($ref -match '^([^/]+)/([^#]+)#(\d+)$') {
        return @{
            Owner = $Matches[1]
            Repo = $Matches[2]
            Number = [int]$Matches[3]
            FullRef = $ref
        }
    }
    
    throw "Invalid issue reference format: $ref"
}

# Function to get issue details (ID and body)
function Get-IssueDetails {
    param(
        [string]$Owner,
        [string]$Repo,
        [int]$Number,
        [string]$CorrelationId
    )
    
    $query = @"
query {
  repository(owner: "$Owner", name: "$Repo") {
    issue(number: $Number) {
      id
      number
      title
      body
    }
  }
}
"@
    
    $result = Invoke-GraphQL -Query $query -CorrelationId $CorrelationId
    
    if (-not $result.Success) {
        throw "Failed to fetch issue ${Number}: $($result.Errors[0].Message)"
    }
    
    return $result.Data.repository.issue
}

# Function to parse existing dependencies section
function Get-ExistingDependencies {
    param([string]$Body)
    
    $dependencies = @{
        BlockedBy = @()
        Blocks = @()
        Wave = 0
    }
    
    if ([string]::IsNullOrWhiteSpace($Body)) {
        return $dependencies
    }
    
    # Look for Dependencies section
    if ($Body -match '(?ms)^## Dependencies\s*\n(.*?)(?=\n##|\z)') {
        $depsSection = $Matches[1]
        
        # Parse Blocked by items
        if ($depsSection -match '(?ms)Blocked by:\s*\n(.*?)(?=\n+Blocks:|\z)') {
            $blockedByText = $Matches[1]
            $blockedByMatches = [regex]::Matches($blockedByText, '- \[ \] ([^\s]+)')
            foreach ($match in $blockedByMatches) {
                $dependencies.BlockedBy += $match.Groups[1].Value -replace '^([^#]+#\d+).*', '$1'
            }
        }
        
        # Parse Blocks items
        if ($depsSection -match '(?ms)Blocks:\s*\n(.*?)(?=\n+\*\*Wave:|\z)') {
            $blocksText = $Matches[1]
            $blocksMatches = [regex]::Matches($blocksText, '- \[ \] ([^\s]+)')
            foreach ($match in $blocksMatches) {
                $dependencies.Blocks += $match.Groups[1].Value -replace '^([^#]+#\d+).*', '$1'
            }
        }
        
        # Parse Wave
        if ($depsSection -match '\*\*Wave:\s*(\d+)\*\*') {
            $dependencies.Wave = [int]$Matches[1]
        }
    }
    
    return $dependencies
}

# Function to remove existing Dependencies section
function Remove-DependenciesSection {
    param([string]$Body)
    
    if ([string]::IsNullOrWhiteSpace($Body)) {
        return ""
    }
    
    # Remove everything from ## Dependencies to next ## or end of text
    $cleaned = $Body -replace '(?ms)^## Dependencies\s*\n.*?(?=\n##|\z)', ''
    
    # Clean up excessive newlines (consolidate multiple newlines into double newlines)
    $cleaned = $cleaned -replace '\n\s*\n\s*\n+', "`n`n"
    $cleaned = $cleaned.TrimEnd()
    
    return $cleaned
}

# Function to build Dependencies section
function Build-DependenciesSection {
    param(
        [string[]]$BlockedBy,
        [string[]]$Blocks,
        [int]$Wave,
        [string]$Owner,
        [string]$Repo
    )
    
    $section = @()
    $section += ""
    $section += "## Dependencies"
    $section += ""
    
    if ($BlockedBy.Count -gt 0) {
        $section += "Blocked by:"
        foreach ($dep in $BlockedBy | Sort-Object) {
            # Get issue details for the title
            $depComponents = Get-IssueComponents -ref $dep
            try {
                $depIssue = Get-IssueDetails -Owner $depComponents.Owner -Repo $depComponents.Repo -Number $depComponents.Number -CorrelationId $CorrelationId
                $section += "- [ ] $dep - $($depIssue.title)"
            } catch {
                Write-OkyeremaLog -Message "Could not fetch title for $dep, using reference only" `
                    -Level Warn -Operation "SetIssueDependency" -CorrelationId $CorrelationId
                $section += "- [ ] $dep"
            }
        }
        $section += ""
    }
    
    if ($Blocks.Count -gt 0) {
        $section += "Blocks:"
        foreach ($blocker in $Blocks | Sort-Object) {
            # Get issue details for the title
            $blockerComponents = Get-IssueComponents -ref $blocker
            try {
                $blockerIssue = Get-IssueDetails -Owner $blockerComponents.Owner -Repo $blockerComponents.Repo -Number $blockerComponents.Number -CorrelationId $CorrelationId
                $section += "- [ ] $blocker - $($blockerIssue.title)"
            } catch {
                Write-OkyeremaLog -Message "Could not fetch title for $blocker, using reference only" `
                    -Level Warn -Operation "SetIssueDependency" -CorrelationId $CorrelationId
                $section += "- [ ] $blocker"
            }
        }
        $section += ""
    }
    
    if ($Wave -gt 0) {
        $section += "**Wave: $Wave** — Cannot start until all dependencies are merged."
    }
    
    return ($section -join "`n")
}

# Function to update issue body
function Update-IssueBody {
    param(
        [string]$IssueId,
        [string]$NewBody,
        [string]$CorrelationId
    )
    
    $escapedBody = $NewBody | ConvertTo-EscapedGraphQL
    
    $mutation = @"
mutation {
  updateIssue(input: {
    id: "$IssueId"
    body: "$escapedBody"
  }) {
    issue {
      number
      body
    }
  }
}
"@
    
    return Invoke-GraphQL -Query $mutation -CorrelationId $CorrelationId
}

# Main execution
try {
    # Get current repo context
    $repoInfo = gh repo view --json nameWithOwner,owner,name | ConvertFrom-Json
    $currentOwner = $repoInfo.owner.login
    $currentRepo = $repoInfo.name
    
    Write-OkyeremaLog -Message "Working with repo: $currentOwner/$currentRepo" `
        -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId
    
    # Normalize all issue references
    $normalizedDependsOn = @()
    foreach ($dep in $DependsOn) {
        $normalizedDependsOn += Get-NormalizedIssueRef -ref $dep
    }
    
    $normalizedBlocks = @()
    foreach ($blocker in $Blocks) {
        $normalizedBlocks += Get-NormalizedIssueRef -ref $blocker
    }
    
    # Get current issue details
    Write-OkyeremaLog -Message "Fetching issue ${IssueNumber} details" `
        -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId
    
    $issue = Get-IssueDetails -Owner $currentOwner -Repo $currentRepo -Number $IssueNumber -CorrelationId $CorrelationId
    
    # Parse existing dependencies
    $existingDeps = Get-ExistingDependencies -Body $issue.body
    
    # Merge with new dependencies
    $allBlockedBy = @($normalizedDependsOn) + @($existingDeps.BlockedBy) | Select-Object -Unique | Sort-Object
    $allBlocks = @($normalizedBlocks) + @($existingDeps.Blocks) | Select-Object -Unique | Sort-Object
    
    # Use provided Wave or keep existing
    $finalWave = if ($Wave -gt 0) { $Wave } else { $existingDeps.Wave }
    
    # Remove old Dependencies section
    $cleanBody = Remove-DependenciesSection -Body $issue.body
    
    # Build new Dependencies section
    $depsSection = Build-DependenciesSection -BlockedBy $allBlockedBy -Blocks $allBlocks -Wave $finalWave `
        -Owner $currentOwner -Repo $currentRepo
    
    # Combine
    $newBody = $cleanBody + $depsSection
    
    if ($DryRun) {
        Write-Host "=== DryRun Mode ===" -ForegroundColor Cyan
        Write-Host "Correlation ID: $CorrelationId" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Would update issue ${IssueNumber} with:" -ForegroundColor Yellow
        Write-Host $newBody -ForegroundColor Gray
        Write-Host ""
        Write-Host "Cross-references to update:" -ForegroundColor Yellow
        
        foreach ($dep in $normalizedDependsOn) {
            $depComponents = Get-IssueComponents -ref $dep
            Write-Host "  - Issue #$($depComponents.Number): Add to Blocks section" -ForegroundColor Gray
        }
        
        foreach ($blocker in $normalizedBlocks) {
            $blockerComponents = Get-IssueComponents -ref $blocker
            Write-Host "  - Issue #$($blockerComponents.Number): Add to Blocked by section" -ForegroundColor Gray
        }
        
        Write-Host "==================" -ForegroundColor Cyan
        
        return [PSCustomObject]@{
            Success = $true
            IssueNumber = $IssueNumber
            UpdatedDependencies = $allBlockedBy
            UpdatedBlockers = $allBlocks
            CrossReferencesUpdated = 0
            CorrelationId = $CorrelationId
            DryRun = $true
        }
    }
    
    # Update the main issue
    Write-OkyeremaLog -Message "Updating issue ${IssueNumber} body" `
        -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId
    
    $updateResult = Update-IssueBody -IssueId $issue.id -NewBody $newBody -CorrelationId $CorrelationId
    
    if (-not $updateResult.Success) {
        throw "Failed to update issue ${IssueNumber}: $($updateResult.Errors[0].Message)"
    }
    
    # Cross-reference: update dependencies to show they block this issue
    $crossRefsUpdated = 0
    $currentRef = "$currentOwner/$currentRepo#$IssueNumber"
    
    foreach ($dep in $normalizedDependsOn) {
        try {
            $depComponents = Get-IssueComponents -ref $dep
            Write-OkyeremaLog -Message "Updating cross-reference in issue #$($depComponents.Number)" `
                -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId
            
            $depIssue = Get-IssueDetails -Owner $depComponents.Owner -Repo $depComponents.Repo -Number $depComponents.Number -CorrelationId $CorrelationId
            $depExistingDeps = Get-ExistingDependencies -Body $depIssue.body
            
            # Add current issue to the dependency's Blocks list
            $depBlocks = @($depExistingDeps.Blocks) + @($currentRef) | Select-Object -Unique | Sort-Object
            
            $depCleanBody = Remove-DependenciesSection -Body $depIssue.body
            $depDepsSection = Build-DependenciesSection -BlockedBy $depExistingDeps.BlockedBy -Blocks $depBlocks -Wave $depExistingDeps.Wave `
                -Owner $depComponents.Owner -Repo $depComponents.Repo
            $depNewBody = $depCleanBody + $depDepsSection
            
            $depUpdateResult = Update-IssueBody -IssueId $depIssue.id -NewBody $depNewBody -CorrelationId $CorrelationId
            
            if ($depUpdateResult.Success) {
                $crossRefsUpdated++
            }
        } catch {
            Write-OkyeremaLog -Message "Failed to update cross-reference in $dep`: $_" `
                -Level Warn -Operation "SetIssueDependency" -CorrelationId $CorrelationId
        }
    }
    
    # Cross-reference: update blockers to show they depend on this issue
    foreach ($blocker in $normalizedBlocks) {
        try {
            $blockerComponents = Get-IssueComponents -ref $blocker
            Write-OkyeremaLog -Message "Updating cross-reference in issue #$($blockerComponents.Number)" `
                -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId
            
            $blockerIssue = Get-IssueDetails -Owner $blockerComponents.Owner -Repo $blockerComponents.Repo -Number $blockerComponents.Number -CorrelationId $CorrelationId
            $blockerExistingDeps = Get-ExistingDependencies -Body $blockerIssue.body
            
            # Add current issue to the blocker's BlockedBy list
            $blockerBlockedBy = @($blockerExistingDeps.BlockedBy) + @($currentRef) | Select-Object -Unique | Sort-Object
            
            $blockerCleanBody = Remove-DependenciesSection -Body $blockerIssue.body
            $blockerDepsSection = Build-DependenciesSection -BlockedBy $blockerBlockedBy -Blocks $blockerExistingDeps.Blocks -Wave $blockerExistingDeps.Wave `
                -Owner $blockerComponents.Owner -Repo $blockerComponents.Repo
            $blockerNewBody = $blockerCleanBody + $blockerDepsSection
            
            $blockerUpdateResult = Update-IssueBody -IssueId $blockerIssue.id -NewBody $blockerNewBody -CorrelationId $CorrelationId
            
            if ($blockerUpdateResult.Success) {
                $crossRefsUpdated++
            }
        } catch {
            Write-OkyeremaLog -Message "Failed to update cross-reference in $blocker`: $_" `
                -Level Warn -Operation "SetIssueDependency" -CorrelationId $CorrelationId
        }
    }
    
    Write-OkyeremaLog -Message "Successfully updated issue ${IssueNumber} with $crossRefsUpdated cross-references" `
        -Level Info -Operation "SetIssueDependency" -CorrelationId $CorrelationId
    
    return [PSCustomObject]@{
        Success = $true
        IssueNumber = $IssueNumber
        UpdatedDependencies = $allBlockedBy
        UpdatedBlockers = $allBlocks
        CrossReferencesUpdated = $crossRefsUpdated
        CorrelationId = $CorrelationId
    }
    
} catch {
    Write-OkyeremaLog -Message "Error: $_" `
        -Level Error -Operation "SetIssueDependency" -CorrelationId $CorrelationId
    
    return [PSCustomObject]@{
        Success = $false
        IssueNumber = $IssueNumber
        Error = $_.Exception.Message
        CorrelationId = $CorrelationId
    }
}
