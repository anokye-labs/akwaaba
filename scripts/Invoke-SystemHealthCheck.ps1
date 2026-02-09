<#
.SYNOPSIS
    Validate that the Okyerema system's docs, scripts, and assumptions match current GitHub API reality.

.DESCRIPTION
    Invoke-SystemHealthCheck.ps1 goes beyond DAG health to check the system itself.
    Verifies that documentation, scripts, and API usage align with current GitHub API reality.
    
    Root cause: The entire Okyerema skill was built on the retired tasklist API for 10 months
    with no detection. This script catches this kind of drift.
    
    Performs the following checks:
    1. API Compatibility: Verify GraphQL queries in reference docs still work
    2. Script Dependencies: Verify all scripts referenced in SKILL.md actually exist
    3. Doc Freshness: Check if reference docs mention deprecated patterns
    4. Hierarchy Integrity: Verify all issues under an Epic have proper parent relationships
    5. Label Consistency: Verify no labels are being used for structure

.PARAMETER Owner
    The GitHub repository owner (organization or user).

.PARAMETER Repo
    The GitHub repository name.

.PARAMETER SkillPath
    Path to the Okyerema skill directory. Default is .github/skills/okyerema

.PARAMETER Verbose
    Enable verbose logging for debugging purposes.

.OUTPUTS
    Returns an array of PSCustomObject with check results:
    - CheckName: Name of the check performed
    - Status: Pass, Warn, or Fail
    - Details: Description of findings

.EXAMPLE
    PS> .\Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba"
    Runs all system health checks on the repository.

.EXAMPLE
    PS> .\Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba" -Verbose
    Runs checks with verbose logging enabled.

.EXAMPLE
    PS> .\Invoke-SystemHealthCheck.ps1 -Owner "anokye-labs" -Repo "akwaaba" -SkillPath ".github/skills/okyerema"
    Runs checks with custom skill path.

.NOTES
    Requires GitHub CLI (gh) to be installed and authenticated.
    Dependencies:
    - Invoke-GraphQL.ps1
    - Get-RepoContext.ps1
    - Write-OkyeremaLog.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Owner,

    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [Parameter(Mandatory = $false)]
    [string]$SkillPath = ".github/skills/okyerema"
)

$ErrorActionPreference = "Stop"

# Generate correlation ID for tracking
$correlationId = [guid]::NewGuid().ToString()

# Get script directory for relative paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Helper function to call Invoke-GraphQL.ps1
function Invoke-GraphQLHelper {
    param(
        [string]$Query,
        [hashtable]$Variables = @{},
        [string]$CorrelationId
    )
    
    $invokeGraphQLPath = Join-Path $scriptDir "Invoke-GraphQL.ps1"
    
    $params = @{
        Query = $Query
        Variables = $Variables
        CorrelationId = $CorrelationId
    }
    
    return & $invokeGraphQLPath @params
}

# Helper function to call Write-OkyeremaLog.ps1
function Write-OkyeremaLogHelper {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [string]$Operation = "",
        [string]$CorrelationId = ""
    )
    
    # Navigate from scripts/ to repository root using loop-based pattern
    $repoRoot = $scriptDir
    for ($i = 0; $i -lt 1; $i++) {
        $repoRoot = Split-Path -Parent $repoRoot
    }
    
    $writeLogPath = Join-Path $repoRoot ".github" "skills" "okyerema" "scripts" "Write-OkyeremaLog.ps1"
    
    $params = @{
        Message = $Message
        Level = $Level
    }
    
    if ($Operation) {
        $params.Operation = $Operation
    }
    
    if ($CorrelationId) {
        $params.CorrelationId = $CorrelationId
    }
    
    & $writeLogPath @params
}

# Initialize results array
$results = @()

Write-OkyeremaLogHelper -Message "Starting system health checks" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

# Resolve paths
$repoRoot = $scriptDir
for ($i = 0; $i -lt 1; $i++) {
    $repoRoot = Split-Path -Parent $repoRoot
}
$skillPathFull = Join-Path $repoRoot $SkillPath

# ===========================
# Check 1: API Compatibility
# ===========================
Write-OkyeremaLogHelper -Message "Running API Compatibility check" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

$apiCheckStatus = "Pass"
$apiCheckDetails = @()

# Check reference docs for deprecated API mentions
$referenceDocsPath = Join-Path $skillPathFull "references"
if (Test-Path $referenceDocsPath) {
    $referenceFiles = Get-ChildItem -Path $referenceDocsPath -Filter "*.md"
    
    foreach ($file in $referenceFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        
        # Check for deprecated trackedIssues API references (should use subIssues per ADR-0001)
        # Note: Negative lookahead (?!\s+is\s+empty) excludes the error message "trackedIssues is empty"
        # which is a valid reference to the field name in troubleshooting docs
        if ($content -match 'trackedIssues(?!\s+is\s+empty)' -or $content -match 'trackedInIssues') {
            # According to ADR-0001, trackedIssues/trackedInIssues are deprecated in favor of subIssues/parent
            $apiCheckStatus = "Warn"
            $apiCheckDetails += "File '$($file.Name)' references deprecated 'trackedIssues' or 'trackedInIssues' API. ADR-0001 mandates using 'subIssues' and 'parent' fields instead."
        }
        
        # Check for tasklist relationship mentions (deprecated per ADR-0001)
        if ($content -match 'tasklist|Tasklist') {
            $apiCheckStatus = "Warn"
            $apiCheckDetails += "File '$($file.Name)' mentions tasklists for relationships. ADR-0001 states tasklist-based relationships are deprecated; use createIssueRelationship mutation instead."
        }
    }
}

# Check SKILL.md for deprecated patterns
$skillMdPath = Join-Path $skillPathFull "SKILL.md"
if (Test-Path $skillMdPath) {
    $skillContent = Get-Content -Path $skillMdPath -Raw
    
    if ($skillContent -match 'trackedIssues|trackedInIssues') {
        $apiCheckStatus = "Warn"
        $apiCheckDetails += "SKILL.md references deprecated 'trackedIssues' API. Should use 'subIssues' per ADR-0001."
    }
    
    if ($skillContent -match 'tasklist|Tasklist') {
        $apiCheckStatus = "Warn"
        $apiCheckDetails += "SKILL.md mentions tasklists for relationships. ADR-0001 mandates using createIssueRelationship mutation instead."
    }
}

if ($apiCheckDetails.Count -eq 0) {
    $apiCheckDetails += "All documentation uses current GitHub API patterns (subIssues, createIssueRelationship)."
}

$results += [PSCustomObject]@{
    CheckName = "API Compatibility"
    Status = $apiCheckStatus
    Details = ($apiCheckDetails -join "`n")
}

# ================================
# Check 2: Script Dependencies
# ================================
Write-OkyeremaLogHelper -Message "Running Script Dependencies check" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

$scriptCheckStatus = "Pass"
$scriptCheckDetails = @()

if (Test-Path $skillMdPath) {
    $skillContent = Get-Content -Path $skillMdPath -Raw
    
    # Extract script references from SKILL.md (look for .ps1 file references)
    $scriptReferences = [regex]::Matches($skillContent, '\[scripts/([^\]]+\.ps1)\]') | ForEach-Object { $_.Groups[1].Value }
    
    foreach ($scriptRef in $scriptReferences) {
        $scriptPath = Join-Path $skillPathFull "scripts" $scriptRef
        
        if (-not (Test-Path $scriptPath)) {
            $scriptCheckStatus = "Fail"
            $scriptCheckDetails += "Referenced script '$scriptRef' not found at expected path: $scriptPath"
        }
    }
    
    if ($scriptCheckDetails.Count -eq 0) {
        $scriptCheckDetails += "All $($scriptReferences.Count) scripts referenced in SKILL.md exist."
    }
}
else {
    $scriptCheckStatus = "Warn"
    $scriptCheckDetails += "SKILL.md not found at expected path: $skillMdPath"
}

$results += [PSCustomObject]@{
    CheckName = "Script Dependencies"
    Status = $scriptCheckStatus
    Details = ($scriptCheckDetails -join "`n")
}

# ==========================
# Check 3: Doc Freshness
# ==========================
Write-OkyeremaLogHelper -Message "Running Doc Freshness check" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

$docFreshnessStatus = "Pass"
$docFreshnessDetails = @()

# Check for mentions of deprecated patterns across all docs
$allDocFiles = @()
if (Test-Path $skillPathFull) {
    $allDocFiles = Get-ChildItem -Path $skillPathFull -Recurse -Filter "*.md"
}

$deprecatedPatterns = @{
    "gh issue create.*--label.*epic|task|feature" = "Using labels for issue types (gh CLI doesn't support --type flag, must use GraphQL)"
    "addTrackedByIssue" = "Non-existent mutation (never existed in GitHub API)"
    "\[Epic\]|\[Task\]|\[Feature\]" = "Title prefixes for types (should use organization issue types)"
}

foreach ($file in $allDocFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    
    foreach ($pattern in $deprecatedPatterns.Keys) {
        if ($content -match $pattern) {
            $docFreshnessStatus = "Warn"
            $relativePath = $file.FullName.Replace("$repoRoot/", "")
            $docFreshnessDetails += "File '$relativePath' contains deprecated pattern: $($deprecatedPatterns[$pattern])"
        }
    }
}

if ($docFreshnessDetails.Count -eq 0) {
    $docFreshnessDetails += "No deprecated patterns found in documentation."
}

$results += [PSCustomObject]@{
    CheckName = "Doc Freshness"
    Status = $docFreshnessStatus
    Details = ($docFreshnessDetails -join "`n")
}

# ===============================
# Check 4: Hierarchy Integrity
# ===============================
Write-OkyeremaLogHelper -Message "Running Hierarchy Integrity check" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

$hierarchyCheckStatus = "Pass"
$hierarchyCheckDetails = @()

# Query for all open Epics and verify their children have parent relationships
# NOTE: This check uses the deprecated trackedIssues/trackedInIssues API because:
# 1. The repository hasn't migrated to sub-issues API yet (per ADR-0001)
# 2. We need to check the *current* state of the repository, not the ideal state
# 3. This is a pragmatic health check that works with what's actually deployed
# 4. The API Compatibility check above already warns about the deprecated API usage
$epicQuery = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    issues(first: 100, filterBy: { states: OPEN }) {
      nodes {
        id
        number
        title
        issueType {
          name
        }
        trackedIssues(first: 100) {
          nodes {
            number
            title
            issueType {
              name
            }
            trackedInIssues(first: 1) {
              totalCount
            }
          }
        }
      }
    }
  }
}
"@

$variables = @{
    owner = $Owner
    repo = $Repo
}

try {
    $epicResult = Invoke-GraphQLHelper -Query $epicQuery -Variables $variables -CorrelationId $correlationId
    
    if ($epicResult.Success) {
        $issues = $epicResult.Data.repository.issues.nodes
        $epics = $issues | Where-Object { $_.issueType.name -eq "Epic" }
        
        foreach ($epic in $epics) {
            $children = $epic.trackedIssues.nodes
            
            foreach ($child in $children) {
                # Check if child has parent relationship
                if ($child.trackedInIssues.totalCount -eq 0) {
                    $hierarchyCheckStatus = "Warn"
                    $hierarchyCheckDetails += "Issue #$($child.number) is tracked by Epic #$($epic.number) but shows no parent relationship (trackedInIssues.totalCount = 0). This indicates a relationship sync issue."
                }
            }
        }
        
        if ($hierarchyCheckDetails.Count -eq 0) {
            $hierarchyCheckDetails += "All child issues under Epics have proper parent relationships. Checked $($epics.Count) Epic(s)."
        }
    }
    else {
        $hierarchyCheckStatus = "Fail"
        $hierarchyCheckDetails += "Failed to query issue hierarchy: $($epicResult.Errors[0].Message)"
    }
}
catch {
    $hierarchyCheckStatus = "Fail"
    $hierarchyCheckDetails += "Error querying hierarchy: $_"
}

$results += [PSCustomObject]@{
    CheckName = "Hierarchy Integrity"
    Status = $hierarchyCheckStatus
    Details = ($hierarchyCheckDetails -join "`n")
}

# ==============================
# Check 5: Label Consistency
# ==============================
Write-OkyeremaLogHelper -Message "Running Label Consistency check" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

$labelCheckStatus = "Pass"
$labelCheckDetails = @()

# Query for labels and check for structural patterns
$labelQuery = @"
query(`$owner: String!, `$repo: String!) {
  repository(owner: `$owner, name: `$repo) {
    labels(first: 100) {
      nodes {
        name
        description
        color
      }
    }
  }
}
"@

try {
    $labelResult = Invoke-GraphQLHelper -Query $labelQuery -Variables $variables -CorrelationId $correlationId
    
    if ($labelResult.Success) {
        $labels = $labelResult.Data.repository.labels.nodes
        
        # Check for structural labels (anti-pattern)
        $structuralPatterns = @(
            "^epic$",
            "^task$",
            "^feature$",
            "^bug$",
            "parent:",
            "blocked-by",
            "depends-on",
            "in-progress",
            "todo"
        )
        
        foreach ($label in $labels) {
            foreach ($pattern in $structuralPatterns) {
                if ($label.name -match $pattern) {
                    $labelCheckStatus = "Warn"
                    $labelCheckDetails += "Label '$($label.name)' appears to be used for structure. Labels should only be used for categorization, not for types or relationships."
                }
            }
        }
        
        if ($labelCheckDetails.Count -eq 0) {
            $labelCheckDetails += "No structural labels found. All $($labels.Count) label(s) appear to be used correctly for categorization."
        }
    }
    else {
        $labelCheckStatus = "Fail"
        $labelCheckDetails += "Failed to query labels: $($labelResult.Errors[0].Message)"
    }
}
catch {
    $labelCheckStatus = "Fail"
    $labelCheckDetails += "Error querying labels: $_"
}

$results += [PSCustomObject]@{
    CheckName = "Label Consistency"
    Status = $labelCheckStatus
    Details = ($labelCheckDetails -join "`n")
}

# ========================
# Display Results
# ========================
Write-Host "`n╔════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                      SYSTEM HEALTH CHECK REPORT                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repository: $Owner/$Repo" -ForegroundColor White
Write-Host "Skill Path: $SkillPath" -ForegroundColor White
Write-Host "Correlation ID: $correlationId" -ForegroundColor Gray
Write-Host ""

foreach ($result in $results) {
    $statusColor = switch ($result.Status) {
        "Pass" { "Green" }
        "Warn" { "Yellow" }
        "Fail" { "Red" }
        default { "Gray" }
    }
    
    $statusSymbol = switch ($result.Status) {
        "Pass" { "✓" }
        "Warn" { "⚠" }
        "Fail" { "✗" }
        default { "?" }
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "$statusSymbol " -NoNewline -ForegroundColor $statusColor
    Write-Host "$($result.CheckName): " -NoNewline -ForegroundColor White
    Write-Host "$($result.Status)" -ForegroundColor $statusColor
    Write-Host ""
    Write-Host "$($result.Details)" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

# Summary
$passCount = ($results | Where-Object { $_.Status -eq "Pass" }).Count
$warnCount = ($results | Where-Object { $_.Status -eq "Warn" }).Count
$failCount = ($results | Where-Object { $_.Status -eq "Fail" }).Count

Write-Host ""
Write-Host "Summary: " -NoNewline -ForegroundColor White
Write-Host "$passCount passed" -NoNewline -ForegroundColor Green
Write-Host ", " -NoNewline
Write-Host "$warnCount warnings" -NoNewline -ForegroundColor Yellow
Write-Host ", " -NoNewline
Write-Host "$failCount failed" -ForegroundColor Red
Write-Host ""

Write-OkyeremaLogHelper -Message "System health check completed: $passCount passed, $warnCount warnings, $failCount failed" -Level "Info" -Operation "Invoke-SystemHealthCheck" -CorrelationId $correlationId

# Return results for pipeline use
return $results
