<#
.SYNOPSIS
    Validates commit messages for issue references.

.DESCRIPTION
    Validate-Commits.ps1 checks commit messages for proper issue references,
    supporting various formats including simple references (#123), action keywords
    (Closes #123, Fixes #123, Resolves #123), and full repository URLs.
    
    The script supports multiple issue references per commit and handles both
    short and long SHA formats.

.PARAMETER CommitMessages
    Array of commit messages to validate.

.PARAMETER CommitSha
    Optional. The commit SHA (short or long format) for reference.

.PARAMETER Owner
    Optional. Repository owner for validating full URL references.

.PARAMETER Repo
    Optional. Repository name for validating full URL references.

.OUTPUTS
    Returns a PSCustomObject with:
    - IsValid: Boolean indicating if all commits have valid issue references
    - Results: Array of validation results for each commit
    - IssueReferences: Array of all extracted issue numbers

.EXAMPLE
    .\Validate-Commits.ps1 -CommitMessages @("feat: Add feature (#123)")
    
    Validates a single commit message with an issue reference.

.EXAMPLE
    .\Validate-Commits.ps1 -CommitMessages @("fix: Bug fix (Fixes #456, Closes #789)")
    
    Validates a commit with multiple issue references.

.EXAMPLE
    $commits = git log --format=%s main..HEAD
    .\Validate-Commits.ps1 -CommitMessages $commits -Owner "anokye-labs" -Repo "akwaaba"
    
    Validates commits in a PR against the main branch.

.NOTES
    Supported issue reference formats:
    - Simple reference: #123
    - Action keywords: Closes #123, Fixes #456, Resolves #789
    - Repository reference: anokye-labs/akwaaba#123
    - Full GitHub URL: https://github.com/anokye-labs/akwaaba/issues/123
    
    Multiple references can be combined in one commit message.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$CommitMessages,

    [Parameter(Mandatory = $false)]
    [string]$CommitSha,

    [Parameter(Mandatory = $false)]
    [string]$Owner,

    [Parameter(Mandatory = $false)]
    [string]$Repo
)

$ErrorActionPreference = "Stop"

# Define action keywords as a constant for consistency
# Note: Wrapped in non-capturing group for direct use in regex patterns
$script:ActionKeywords = '(?:Closes|Fixes|Resolves|Close|Fix|Resolve)'

function Get-IssueReferences {
    <#
    .SYNOPSIS
        Extracts issue references from a commit message.
    
    .DESCRIPTION
        Parses commit message text and extracts all issue references using regex patterns.
        Supports multiple formats including simple references, action keywords, and full URLs.
    
    .PARAMETER Message
        The commit message to parse.
    
    .PARAMETER Owner
        Optional repository owner for validating full URL references.
    
    .PARAMETER Repo
        Optional repository name for validating full URL references.
    
    .OUTPUTS
        Array of issue numbers (as integers) found in the commit message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Owner,

        [Parameter(Mandatory = $false)]
        [string]$Repo
    )

    $issueNumbers = @()
    $processedRanges = @()  # Track character ranges we've already processed

    # Helper function to check if a range overlaps with already processed ranges
    # This prevents duplicate issue extraction from overlapping patterns
    # (e.g., #123 in both owner/repo#123 and as a standalone reference)
    function Test-RangeProcessed {
        param([int]$Start, [int]$End, [array]$Ranges)
        foreach ($range in $Ranges) {
            if (($Start -ge $range.Start -and $Start -le $range.End) -or 
                ($End -ge $range.Start -and $End -le $range.End) -or
                ($Start -le $range.Start -and $End -ge $range.End)) {
                return $true
            }
        }
        return $false
    }

    # Helper function to mark a range as processed and add issue number
    # This ensures each matched pattern is only processed once and issue numbers
    # are not duplicated in the results
    function Add-IssueNumber {
        param(
            [int]$IssueNumber,
            [int]$MatchStart,
            [int]$MatchLength,
            [ref]$IssueNumbers,
            [ref]$ProcessedRanges
        )
        
        # Mark this range as processed
        $ProcessedRanges.Value += @{ Start = $MatchStart; End = $MatchStart + $MatchLength - 1 }
        
        # Add issue number if not already present
        if ($IssueNumber -notin $IssueNumbers.Value) {
            $IssueNumbers.Value += $IssueNumber
        }
    }

    # Helper function to check if repository matches the context
    # When Owner and Repo are provided, only references to that repository are included
    # When no context is provided, all references are accepted
    function Test-RepositoryMatch {
        param([string]$RefOwner, [string]$RefRepo, [string]$Owner, [string]$Repo)
        
        if ($Owner -and $Repo) {
            return ($RefOwner -eq $Owner -and $RefRepo -eq $Repo)
        }
        return $true  # No context provided, accept all
    }

    # Pattern 1: Action keywords with full repository reference
    # Matches: Closes anokye-labs/akwaaba#123, Fixes owner/repo#456
    # Process these first to handle repo-scoped references with keywords
    $actionFullRefPattern = "$script:ActionKeywords\s+([\w-]+)/([\w-]+)#(\d+)"
    $actionFullRefMatches = [regex]::Matches($Message, $actionFullRefPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($match in $actionFullRefMatches) {
        $refOwner = $match.Groups[1].Value
        $refRepo = $match.Groups[2].Value
        $issueNumber = [int]$match.Groups[3].Value
        
        if (Test-RepositoryMatch -RefOwner $refOwner -RefRepo $refRepo -Owner $Owner -Repo $Repo) {
            Add-IssueNumber -IssueNumber $issueNumber -MatchStart $match.Index -MatchLength $match.Length -IssueNumbers ([ref]$issueNumbers) -ProcessedRanges ([ref]$processedRanges)
        }
        else {
            # Still mark as processed even if filtered out
            $processedRanges += @{ Start = $match.Index; End = $match.Index + $match.Length - 1 }
        }
    }

    # Pattern 2: Full repository reference (owner/repo#123)
    # Matches: anokye-labs/akwaaba#123, etc.
    # Process these before simple patterns to handle repo-scoped references
    $fullRefPattern = '([\w-]+)/([\w-]+)#(\d+)'
    $fullRefMatches = [regex]::Matches($Message, $fullRefPattern)
    foreach ($match in $fullRefMatches) {
        # Skip if already processed
        if (Test-RangeProcessed -Start $match.Index -End ($match.Index + $match.Length - 1) -Ranges $processedRanges) {
            continue
        }
        
        $refOwner = $match.Groups[1].Value
        $refRepo = $match.Groups[2].Value
        $issueNumber = [int]$match.Groups[3].Value
        
        if (Test-RepositoryMatch -RefOwner $refOwner -RefRepo $refRepo -Owner $Owner -Repo $Repo) {
            Add-IssueNumber -IssueNumber $issueNumber -MatchStart $match.Index -MatchLength $match.Length -IssueNumbers ([ref]$issueNumbers) -ProcessedRanges ([ref]$processedRanges)
        }
        else {
            # Still mark as processed even if filtered out
            $processedRanges += @{ Start = $match.Index; End = $match.Index + $match.Length - 1 }
        }
    }

    # Pattern 3: Action keywords with simple issue reference
    # Matches: Closes #123, Fixes #456, Resolves #789, etc.
    # Process before simple patterns to avoid double-counting
    $actionPattern = "$script:ActionKeywords\s+#(\d+)"
    $actionMatches = [regex]::Matches($Message, $actionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    foreach ($match in $actionMatches) {
        # Skip if already processed
        if (Test-RangeProcessed -Start $match.Index -End ($match.Index + $match.Length - 1) -Ranges $processedRanges) {
            continue
        }
        
        $issueNumber = [int]$match.Groups[1].Value
        Add-IssueNumber -IssueNumber $issueNumber -MatchStart $match.Index -MatchLength $match.Length -IssueNumbers ([ref]$issueNumbers) -ProcessedRanges ([ref]$processedRanges)
    }

    # Pattern 4: Full GitHub URL
    # Matches: https://github.com/anokye-labs/akwaaba/issues/123
    $urlPattern = 'https?://github\.com/([\w-]+)/([\w-]+)/issues/(\d+)'
    $urlMatches = [regex]::Matches($Message, $urlPattern)
    foreach ($match in $urlMatches) {
        # Skip if already processed
        if (Test-RangeProcessed -Start $match.Index -End ($match.Index + $match.Length - 1) -Ranges $processedRanges) {
            continue
        }
        
        $refOwner = $match.Groups[1].Value
        $refRepo = $match.Groups[2].Value
        $issueNumber = [int]$match.Groups[3].Value
        
        if (Test-RepositoryMatch -RefOwner $refOwner -RefRepo $refRepo -Owner $Owner -Repo $Repo) {
            Add-IssueNumber -IssueNumber $issueNumber -MatchStart $match.Index -MatchLength $match.Length -IssueNumbers ([ref]$issueNumbers) -ProcessedRanges ([ref]$processedRanges)
        }
        else {
            # Still mark as processed even if filtered out
            $processedRanges += @{ Start = $match.Index; End = $match.Index + $match.Length - 1 }
        }
    }

    # Pattern 5: Simple issue reference (#123)
    # Matches: #123, #456, etc.
    # Process last to avoid matching parts of already-processed patterns
    $simplePattern = '#(\d+)'
    $simpleMatches = [regex]::Matches($Message, $simplePattern)
    foreach ($match in $simpleMatches) {
        # Skip if already processed (e.g., as part of owner/repo#123)
        if (Test-RangeProcessed -Start $match.Index -End ($match.Index + $match.Length - 1) -Ranges $processedRanges) {
            continue
        }
        
        $issueNumber = [int]$match.Groups[1].Value
        Add-IssueNumber -IssueNumber $issueNumber -MatchStart $match.Index -MatchLength $match.Length -IssueNumbers ([ref]$issueNumbers) -ProcessedRanges ([ref]$processedRanges)
    }

    return $issueNumbers
}

function Test-CommitMessage {
    <#
    .SYNOPSIS
        Validates a single commit message for issue references.
    
    .DESCRIPTION
        Checks if a commit message contains at least one valid issue reference.
    
    .PARAMETER Message
        The commit message to validate.
    
    .PARAMETER Sha
        Optional commit SHA for reference in the result.
    
    .PARAMETER Owner
        Optional repository owner.
    
    .PARAMETER Repo
        Optional repository name.
    
    .OUTPUTS
        PSCustomObject with validation result.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Sha,

        [Parameter(Mandatory = $false)]
        [string]$Owner,

        [Parameter(Mandatory = $false)]
        [string]$Repo
    )

    $issueRefs = Get-IssueReferences -Message $Message -Owner $Owner -Repo $Repo
    $hasIssueReference = $issueRefs.Count -gt 0

    $result = [PSCustomObject]@{
        Message = $Message
        Sha = $Sha
        IsValid = $hasIssueReference
        IssueReferences = $issueRefs
        ValidationMessage = if ($hasIssueReference) {
            "Valid: Found $($issueRefs.Count) issue reference(s): $($issueRefs -join ', ')"
        } else {
            "Invalid: No issue reference found. Commit messages must reference at least one issue using formats like #123, Closes #456, or Fixes owner/repo#789"
        }
    }

    return $result
}

# Main script logic
$allResults = @()
$allIssueReferences = @()

foreach ($message in $CommitMessages) {
    # Skip empty or whitespace-only messages
    if ([string]::IsNullOrWhiteSpace($message)) {
        $result = [PSCustomObject]@{
            Message = $message
            Sha = $CommitSha
            IsValid = $false
            IssueReferences = @()
            ValidationMessage = "Invalid: Empty commit message"
        }
        $allResults += $result
        continue
    }
    
    $result = Test-CommitMessage -Message $message -Sha $CommitSha -Owner $Owner -Repo $Repo
    $allResults += $result
    
    if ($result.IssueReferences) {
        foreach ($issueRef in $result.IssueReferences) {
            if ($issueRef -notin $allIssueReferences) {
                $allIssueReferences += $issueRef
            }
        }
    }
}

# Determine overall validation status
$isValid = ($allResults | Where-Object { -not $_.IsValid }).Count -eq 0

# Create summary output
$output = [PSCustomObject]@{
    IsValid = $isValid
    Results = $allResults
    IssueReferences = $allIssueReferences | Sort-Object
    Summary = @{
        TotalCommits = $CommitMessages.Count
        ValidCommits = ($allResults | Where-Object { $_.IsValid }).Count
        InvalidCommits = ($allResults | Where-Object { -not $_.IsValid }).Count
        TotalIssueReferences = $allIssueReferences.Count
    }
}

return $output
