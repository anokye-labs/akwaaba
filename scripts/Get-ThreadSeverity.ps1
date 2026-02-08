<#
.SYNOPSIS
    Classify PR review thread comments by severity.

.DESCRIPTION
    Get-ThreadSeverity.ps1 classifies PR review thread comments into severity categories
    based on bot badge formats and keyword matching. This function is designed to help
    prioritize review feedback for automated PR completion workflows.
    
    Severity Categories:
    - Bug: Critical issues, errors, bugs, security concerns that must be addressed
    - Nit: Minor style, formatting, or cosmetic suggestions
    - Suggestion: Improvement recommendations that could enhance code quality
    - Question: Questions requiring clarification or design discussion
    
    Classification Logic:
    1. Parse known bot badge formats (Devin P0/P1/P2, Copilot red/yellow emojis)
    2. Keyword matching for Bug, Nit, Suggestion, Question
    3. Default to Bug (safer than ignoring unknown comments)

.PARAMETER Body
    The comment text to classify.

.PARAMETER AuthorLogin
    The GitHub login of the comment author (e.g., "copilot", "devin").

.OUTPUTS
    String: One of "Bug", "Nit", "Suggestion", or "Question"

.EXAMPLE
    .\Get-ThreadSeverity.ps1 -Body "🔴 This function has undefined behavior" -AuthorLogin "copilot"
    Returns: Bug

.EXAMPLE
    .\Get-ThreadSeverity.ps1 -Body "Consider renaming this variable for clarity" -AuthorLogin "user123"
    Returns: Nit

.EXAMPLE
    .\Get-ThreadSeverity.ps1 -Body "Why did you choose this approach?" -AuthorLogin "reviewer"
    Returns: Question

.NOTES
    Dependencies:
    - Write-OkyeremaLog.ps1 (optional, for logging)
    
    Parent Issue: anokye-labs/akwaaba#48
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Body,

    [Parameter(Mandatory = $true)]
    [string]$AuthorLogin
)

$ErrorActionPreference = "Stop"

# Helper function to wrap Write-OkyeremaLog calls (optional logging)
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Debug",
        [string]$Operation = "GetThreadSeverity"
    )
    
    $logScript = Join-Path $PSScriptRoot "Write-OkyeremaLog.ps1"
    if (Test-Path $logScript) {
        & $logScript -Message $Message -Level $Level -Operation $Operation
    }
}

# Main classification function
function Get-ThreadSeverityInternal {
    param(
        [string]$Body,
        [string]$AuthorLogin
    )
    
    $bodyLower = $Body.ToLower()
    $authorLower = $AuthorLogin.ToLower()
    
    # Step 1: Parse known bot badge formats
    
    # Devin bot badges: P0 (Bug), P1 (Bug), P2 (Nit)
    if ($authorLower -match "devin") {
        if ($Body -match '\bP0\b') {
            Write-Log -Message "Classified as Bug: Devin P0 badge detected" -Level Debug
            return "Bug"
        }
        elseif ($Body -match '\bP1\b') {
            Write-Log -Message "Classified as Bug: Devin P1 badge detected" -Level Debug
            return "Bug"
        }
        elseif ($Body -match '\bP2\b') {
            Write-Log -Message "Classified as Nit: Devin P2 badge detected" -Level Debug
            return "Nit"
        }
    }
    
    # Copilot bot badges: Red emoji (Bug), Yellow emoji (Suggestion)
    if ($authorLower -match "copilot") {
        # Red circle emoji (🔴) indicates critical/bug
        if ($Body -match '🔴|:red_circle:') {
            Write-Log -Message "Classified as Bug: Copilot red emoji detected" -Level Debug
            return "Bug"
        }
        # Yellow circle emoji (🟡) indicates suggestion/warning
        elseif ($Body -match '🟡|:yellow_circle:') {
            Write-Log -Message "Classified as Suggestion: Copilot yellow emoji detected" -Level Debug
            return "Suggestion"
        }
    }
    
    # Step 2: Keyword matching with priority order
    
    # Question indicators (check first to catch "?" early)
    # Only match standalone question words, not as part of statements
    $questionPatterns = @(
        '\?',
        '^\s*(why|how|what|where|which)\b',
        '\b(could you|can you|would you|should we)\b',
        '\b(explain|clarify|clarification)\b',
        '\bdesign\b.*\?'
    )
    
    foreach ($pattern in $questionPatterns) {
        if ($bodyLower -match $pattern) {
            Write-Log -Message "Classified as Question: matched pattern '$pattern'" -Level Debug
            return "Question"
        }
    }
    
    # Nit indicators (but exclude "consider adding/using/implementing" which are suggestions)
    $nitPatterns = @(
        '\b(nit|nitpick)\b',
        '\b(style|formatting|whitespace|spacing|indentation)\b',
        '\b(minor|wording|cosmetic|typo|spelling)\b',
        '\b(trailing|leading)\b.*\b(comma|space|newline)\b',
        '\bconsider\s+(renaming|moving|changing)\b'
    )
    
    foreach ($pattern in $nitPatterns) {
        if ($bodyLower -match $pattern) {
            Write-Log -Message "Classified as Nit: matched pattern '$pattern'" -Level Debug
            return "Nit"
        }
    }
    
    # Suggestion indicators (check before generic "consider")
    $suggestionPatterns = @(
        '\b(suggestion|suggest|recommend)\b',
        '\b(could|might|should|would)\b.*\b(improve|better|enhance)\b',
        '\boptional\b',
        '\b(refactor|simplify|optimize)\b',
        '\bconsider\s+(adding|using|implementing)\b',
        '\bconsider\b'
    )
    
    foreach ($pattern in $suggestionPatterns) {
        if ($bodyLower -match $pattern) {
            Write-Log -Message "Classified as Suggestion: matched pattern '$pattern'" -Level Debug
            return "Suggestion"
        }
    }
    
    # Bug indicators (high priority but checked after specific nit/suggestion patterns
    # to avoid false positives like "consider fixing this bug" → should be Nit/Suggestion)
    $bugPatterns = @(
        '\b(bug|bugs)\b',
        '\b(fail|fails|failed|failure)\b',
        '\b(error|errors|exception)\b',
        '\b(undefined|null\s+reference|segfault)\b',
        '\b(crash|crashes|crashing)\b',
        '\b(breaks?|broken|breaking)\b',
        '\b(malformed|invalid|incorrect)\b',
        '\b(security|vulnerability|exploit)\b',
        '\b(critical|blocker|blocking)\b',
        '\b(memory\s+leak|resource\s+leak)\b',
        '\b(deadlock|race\s+condition)\b'
    )
    
    foreach ($pattern in $bugPatterns) {
        if ($bodyLower -match $pattern) {
            Write-Log -Message "Classified as Bug: matched pattern '$pattern'" -Level Debug
            return "Bug"
        }
    }
    
    # Step 3: Default to Bug (safer than ignoring)
    Write-Log -Message "Classified as Bug: default fallback (no specific patterns matched)" -Level Debug
    return "Bug"
}

# Execute and output result
$severity = Get-ThreadSeverityInternal -Body $Body -AuthorLogin $AuthorLogin
Write-Output $severity
