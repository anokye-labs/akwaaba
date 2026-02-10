<#
.SYNOPSIS
    Examples of using Test-IssueExists.ps1 to validate GitHub issues.

.DESCRIPTION
    This script provides practical examples of using Test-IssueExists.ps1 to check
    if issues exist, are open, and are in the correct repository. These examples
    demonstrate common use cases and integration patterns.
#>

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "Test-IssueExists.ps1 - Usage Examples" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Example 1: Basic usage - Check if an issue exists
Write-Host "Example 1: Basic issue existence check" -ForegroundColor Yellow
Write-Host "Command: ./Test-IssueExists.ps1 -IssueNumber 68" -ForegroundColor Gray
Write-Host ""
try {
    $result = & "$PSScriptRoot/../Test-IssueExists.ps1" -IssueNumber 68 -WarningAction SilentlyContinue
    Write-Host "Result:" -ForegroundColor Green
    Write-Host "  Exists: $($result.Exists)"
    Write-Host "  IsOpen: $($result.IsOpen)"
    Write-Host "  IsSameRepository: $($result.IsSameRepository)"
    Write-Host "  State: $($result.State)"
    Write-Host "  Title: $($result.Title)"
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Example 2: Check with explicit repository
Write-Host "Example 2: Check issue in specific repository" -ForegroundColor Yellow
Write-Host "Command: ./Test-IssueExists.ps1 -IssueNumber 1 -Owner 'anokye-labs' -Repo 'akwaaba'" -ForegroundColor Gray
Write-Host ""
try {
    $result = & "$PSScriptRoot/../Test-IssueExists.ps1" -IssueNumber 1 -Owner "anokye-labs" -Repo "akwaaba" -WarningAction SilentlyContinue
    Write-Host "Result:" -ForegroundColor Green
    Write-Host "  Exists: $($result.Exists)"
    Write-Host "  Repository: $($result.RepositoryNameWithOwner)"
    Write-Host "  ErrorMessage: $($result.ErrorMessage)"
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Example 3: Validate issue is open before proceeding
Write-Host "Example 3: Conditional logic - Only proceed if issue is open" -ForegroundColor Yellow
Write-Host "Code pattern:" -ForegroundColor Gray
Write-Host @'
    $issueCheck = ./Test-IssueExists.ps1 -IssueNumber 68
    if ($issueCheck.Exists -and $issueCheck.IsOpen -and $issueCheck.IsSameRepository) {
        # Proceed with work on the issue
        Write-Host "Issue is valid and open - proceeding..." -ForegroundColor Green
    } else {
        Write-Host "Issue validation failed:" -ForegroundColor Red
        if (-not $issueCheck.Exists) {
            Write-Host "  - Issue does not exist"
        }
        if (-not $issueCheck.IsOpen) {
            Write-Host "  - Issue is closed"
        }
        if (-not $issueCheck.IsSameRepository) {
            Write-Host "  - Issue is in a different repository"
        }
    }
'@ -ForegroundColor Gray
Write-Host ""

# Example 4: Batch validation of multiple issues
Write-Host "Example 4: Validate multiple issues" -ForegroundColor Yellow
Write-Host "Code pattern:" -ForegroundColor Gray
Write-Host @'
    $issueNumbers = @(68, 69, 70)
    $results = @()
    
    foreach ($issueNum in $issueNumbers) {
        $check = ./Test-IssueExists.ps1 -IssueNumber $issueNum
        $results += [PSCustomObject]@{
            IssueNumber = $issueNum
            Valid = ($check.Exists -and $check.IsOpen -and $check.IsSameRepository)
            State = $check.State
            Title = $check.Title
        }
    }
    
    # Display summary
    $results | Format-Table -AutoSize
'@ -ForegroundColor Gray
Write-Host ""

# Example 5: Using cache for performance
Write-Host "Example 5: Cache demonstration - Multiple calls use cached data" -ForegroundColor Yellow
Write-Host "First call fetches from GitHub, subsequent calls use cache:" -ForegroundColor Gray
Write-Host ""
try {
    Write-Host "First call (fetches from GitHub):" -ForegroundColor Cyan
    Measure-Command { 
        $result1 = & "$PSScriptRoot/../Test-IssueExists.ps1" -IssueNumber 68 -WarningAction SilentlyContinue
    } | Select-Object -ExpandProperty TotalMilliseconds | ForEach-Object {
        Write-Host "  Time: $_ ms"
    }
    
    Write-Host "Second call (uses cache):" -ForegroundColor Cyan
    Measure-Command { 
        $result2 = & "$PSScriptRoot/../Test-IssueExists.ps1" -IssueNumber 68 -WarningAction SilentlyContinue
    } | Select-Object -ExpandProperty TotalMilliseconds | ForEach-Object {
        Write-Host "  Time: $_ ms (should be much faster)"
    }
    
    Write-Host "Forcing refresh (bypasses cache):" -ForegroundColor Cyan
    Measure-Command { 
        $result3 = & "$PSScriptRoot/../Test-IssueExists.ps1" -IssueNumber 68 -Refresh -WarningAction SilentlyContinue
    } | Select-Object -ExpandProperty TotalMilliseconds | ForEach-Object {
        Write-Host "  Time: $_ ms"
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Example 6: Integration with commit validation
Write-Host "Example 6: Commit message validation pattern" -ForegroundColor Yellow
Write-Host "Code pattern:" -ForegroundColor Gray
Write-Host @'
    # Extract issue number from commit message
    $commitMessage = "feat(scripts): Add feature (#68)"
    if ($commitMessage -match '#(\d+)') {
        $issueNumber = [int]$matches[1]
        
        $validation = ./Test-IssueExists.ps1 -IssueNumber $issueNumber
        
        if (-not $validation.Exists) {
            Write-Error "Commit references non-existent issue #$issueNumber"
            exit 1
        }
        
        if (-not $validation.IsOpen) {
            Write-Warning "Commit references closed issue #$issueNumber (State: $($validation.State))"
        }
        
        if (-not $validation.IsSameRepository) {
            Write-Error "Issue #$issueNumber is not in this repository"
            exit 1
        }
        
        Write-Host "✓ Issue reference validated: $($validation.Title)" -ForegroundColor Green
    } else {
        Write-Error "No issue reference found in commit message"
        exit 1
    }
'@ -ForegroundColor Gray
Write-Host ""

# Example 7: Error handling
Write-Host "Example 7: Proper error handling" -ForegroundColor Yellow
Write-Host "Code pattern:" -ForegroundColor Gray
Write-Host @'
    try {
        $result = ./Test-IssueExists.ps1 -IssueNumber 123 -ErrorAction Stop
        
        if ($result.ErrorMessage) {
            Write-Warning "Issue check completed with message: $($result.ErrorMessage)"
        }
        
        # Check all conditions
        $isValid = $result.Exists -and $result.IsOpen -and $result.IsSameRepository
        
        if ($isValid) {
            Write-Host "Issue is valid - proceeding with work" -ForegroundColor Green
        } else {
            Write-Host "Issue validation failed - aborting" -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Error "Failed to validate issue: $_"
        exit 1
    }
'@ -ForegroundColor Gray
Write-Host ""

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "For more information, see:" -ForegroundColor Cyan
Write-Host "  Get-Help ./Test-IssueExists.ps1 -Full" -ForegroundColor Gray
Write-Host "====================================" -ForegroundColor Cyan
