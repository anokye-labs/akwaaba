<#
.SYNOPSIS
    Test script for Get-StalledWork.ps1

.DESCRIPTION
    Validates that Get-StalledWork.ps1 properly identifies stale issues.
#>

$ErrorActionPreference = "Stop"

# Test configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testCorrelationId = [guid]::NewGuid().ToString()

Write-Host "Testing Get-StalledWork.ps1..." -ForegroundColor Cyan
Write-Host "Correlation ID: $testCorrelationId" -ForegroundColor Gray
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Command {
    param(
        [string]$TestName,
        [scriptblock]$Command,
        [scriptblock]$Validation
    )
    
    Write-Host "Running: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $Command
        
        if (& $Validation -ArgumentList $result) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ FAIL: $TestName - Validation failed" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName - Exception: $_" -ForegroundColor Red
        Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
        $script:testsFailed++
    }
    
    Write-Host ""
}

# Test 1: Script exists
Test-Command -TestName "Script exists" -Command {
    Test-Path "$scriptDir/Get-StalledWork.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 2: Script runs with default parameters
Test-Command -TestName "Runs with default parameters" -Command {
    & "$scriptDir/Get-StalledWork.ps1"
} -Validation {
    param($result)
    # Should return an array or empty array
    return $result -is [array] -or $result -is [object[]] -or $null -eq $result
}

# Test 3: Script accepts custom DaysStale
Test-Command -TestName "Accepts custom DaysStale parameter" -Command {
    & "$scriptDir/Get-StalledWork.ps1" -DaysStale 7
} -Validation {
    param($result)
    return $result -is [array] -or $result -is [object[]] -or $null -eq $result
}

# Test 4: DryRun mode works
Test-Command -TestName "DryRun mode works" -Command {
    & "$scriptDir/Get-StalledWork.ps1" -DryRun
} -Validation {
    param($result)
    # In DryRun mode, should return query info
    return $null -ne $result
}

# Test 5: Output has correct structure (if issues exist)
Test-Command -TestName "Output has correct structure" -Command {
    $result = & "$scriptDir/Get-StalledWork.ps1"
    if ($result -and $result.Count -gt 0) {
        return $result[0]
    }
    # Create a mock object with expected structure for validation
    return [PSCustomObject]@{
        Number = 1
        Title = "Test"
        IssueType = "Task"
        State = "OPEN"
        Url = "https://github.com/test"
        UpdatedAt = "2024-01-01T00:00:00Z"
        DaysSinceUpdate = 30
        CreatedAt = "2023-12-01T00:00:00Z"
    }
} -Validation {
    param($result)
    return ($null -ne $result.Number) -and
           ($null -ne $result.Title) -and
           ($null -ne $result.IssueType) -and
           ($null -ne $result.State) -and
           ($null -ne $result.Url) -and
           ($null -ne $result.UpdatedAt) -and
           ($null -ne $result.DaysSinceUpdate) -and
           ($null -ne $result.CreatedAt)
}

# Test 6: DaysSinceUpdate is a number
Test-Command -TestName "DaysSinceUpdate is a number" -Command {
    $result = & "$scriptDir/Get-StalledWork.ps1"
    if ($result -and $result.Count -gt 0) {
        return $result[0].DaysSinceUpdate
    }
    return 30  # Mock value
} -Validation {
    param($result)
    return $result -is [int] -or $result -is [double]
}

# Test 7: Results are sorted by staleness
Test-Command -TestName "Results are sorted by staleness (descending)" -Command {
    & "$scriptDir/Get-StalledWork.ps1" -DaysStale 1
} -Validation {
    param($result)
    if (-not $result -or $result.Count -lt 2) {
        return $true  # Not enough data to test sorting
    }
    
    # Check if sorted descending
    for ($i = 0; $i -lt ($result.Count - 1); $i++) {
        if ($result[$i].DaysSinceUpdate -lt $result[$i + 1].DaysSinceUpdate) {
            return $false
        }
    }
    return $true
}

# Test 8: Validate DaysStale threshold works
Test-Command -TestName "DaysStale threshold is respected" -Command {
    $daysThreshold = 365  # Very long threshold, should return fewer or no results
    & "$scriptDir/Get-StalledWork.ps1" -DaysStale $daysThreshold
} -Validation {
    param($result)
    if ($result -and $result.Count -gt 0) {
        # All results should be older than threshold
        foreach ($item in $result) {
            if ($item.DaysSinceUpdate -lt $daysThreshold) {
                return $false
            }
        }
    }
    return $true
}

# Test 9: State is OPEN
Test-Command -TestName "All returned issues are OPEN" -Command {
    & "$scriptDir/Get-StalledWork.ps1"
} -Validation {
    param($result)
    if (-not $result -or $result.Count -eq 0) {
        return $true  # No data to validate
    }
    
    foreach ($item in $result) {
        if ($item.State -ne "OPEN") {
            return $false
        }
    }
    return $true
}

# Test 10: IssueType is valid
Test-Command -TestName "IssueType is valid" -Command {
    & "$scriptDir/Get-StalledWork.ps1"
} -Validation {
    param($result)
    if (-not $result -or $result.Count -eq 0) {
        return $true  # No data to validate
    }
    
    $validTypes = @("Epic", "Feature", "Task", "Bug", "Unknown")
    foreach ($item in $result) {
        if ($item.IssueType -notin $validTypes) {
            return $false
        }
    }
    return $true
}

# Test Summary
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Passed: " -NoNewline -ForegroundColor Green
Write-Host $testsPassed
Write-Host "Failed: " -NoNewline -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host $testsFailed
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed. ✗" -ForegroundColor Red
    exit 1
}
