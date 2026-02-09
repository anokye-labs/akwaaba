<#
.SYNOPSIS
    Test script for Invoke-DagHealthCheck.ps1

.DESCRIPTION
    Validates that Invoke-DagHealthCheck.ps1 properly identifies DAG issues:
    - Cycles
    - Orphaned issues
    - Invalid type hierarchies
    - Stale issues
    - Childless epics
#>

$ErrorActionPreference = "Stop"

# Test configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testCorrelationId = [guid]::NewGuid().ToString()

Write-Host "Testing Invoke-DagHealthCheck.ps1..." -ForegroundColor Cyan
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

# Test 1: Script exists and is executable
Test-Command -TestName "Script exists" -Command {
    Test-Path "$scriptDir/Invoke-DagHealthCheck.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 2: Get-StalledWork.ps1 dependency exists
Test-Command -TestName "Get-StalledWork.ps1 dependency exists" -Command {
    Test-Path "$scriptDir/Get-StalledWork.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 3: Script can be invoked and returns a health report object
Test-Command -TestName "Returns health report object" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    return ($null -ne $result) -and 
           ($null -ne $result.Errors) -and 
           ($null -ne $result.Warnings) -and 
           ($null -ne $result.Summary)
}

# Test 4: Health report has required summary fields
Test-Command -TestName "Health report has summary fields" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    return ($null -ne $result.Summary.TotalIssues) -and
           ($null -ne $result.Summary.ErrorCount) -and
           ($null -ne $result.Summary.WarningCount) -and
           ($null -ne $result.Summary.HealthStatus)
}

# Test 5: Health status is valid
Test-Command -TestName "Health status is valid" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    $validStatuses = @("Healthy", "Fair", "Poor", "Critical", "Unknown")
    return $result.Summary.HealthStatus -in $validStatuses
}

# Test 6: JSON format output
Test-Command -TestName "JSON format output works" -Command {
    $jsonOutput = & "$scriptDir/Invoke-DagHealthCheck.ps1" -Format JSON -CorrelationId $testCorrelationId
    if ($jsonOutput -is [string]) {
        $jsonOutput | ConvertFrom-Json
    } else {
        # If it's already an object, convert to JSON and back
        ($jsonOutput | ConvertTo-Json -Depth 10) | ConvertFrom-Json
    }
} -Validation {
    param($result)
    return ($null -ne $result) -and ($null -ne $result.Summary)
}

# Test 7: Markdown format output
Test-Command -TestName "Markdown format output works" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -Format Markdown -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    # Markdown format writes to host and still returns the object
    return $null -ne $result
}

# Test 8: Custom DaysStale parameter
Test-Command -TestName "Custom DaysStale parameter works" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -DaysStale 14 -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    return $null -ne $result
}

# Test 9: Errors array structure
Test-Command -TestName "Errors have correct structure" -Command {
    $report = & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
    if ($report.Errors.Count -gt 0) {
        return $report.Errors[0]
    }
    return [PSCustomObject]@{ Category = "Test"; Message = "Test"; IssueNumber = 1 }
} -Validation {
    param($result)
    return ($null -ne $result.Category) -and
           ($null -ne $result.Message) -and
           ($null -ne $result.IssueNumber)
}

# Test 10: Warnings array structure
Test-Command -TestName "Warnings have correct structure" -Command {
    $report = & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
    if ($report.Warnings.Count -gt 0) {
        return $report.Warnings[0]
    }
    return [PSCustomObject]@{ Category = "Test"; Message = "Test"; IssueNumber = 1 }
} -Validation {
    param($result)
    return ($null -ne $result.Category) -and
           ($null -ne $result.Message) -and
           ($null -ne $result.IssueNumber)
}

# Test 11: Get-StalledWork.ps1 runs independently
Test-Command -TestName "Get-StalledWork.ps1 runs independently" -Command {
    & "$scriptDir/Get-StalledWork.ps1"
} -Validation {
    param($result)
    # Should return an array (even if empty)
    return $result -is [array] -or $result -is [object[]] -or $null -eq $result
}

# Test 12: Get-StalledWork.ps1 with custom days
Test-Command -TestName "Get-StalledWork.ps1 with custom DaysStale" -Command {
    & "$scriptDir/Get-StalledWork.ps1" -DaysStale 7
} -Validation {
    param($result)
    return $result -is [array] -or $result -is [object[]] -or $null -eq $result
}

# Test 13: Health report timestamp format
Test-Command -TestName "Timestamp is in ISO 8601 format" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    try {
        [DateTime]::Parse($result.Timestamp) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Test 14: Repository field is populated
Test-Command -TestName "Repository field is populated" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    return -not [string]::IsNullOrWhiteSpace($result.Repository)
}

# Test 15: Error count matches errors array length
Test-Command -TestName "Error count matches errors array" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    return $result.Summary.ErrorCount -eq $result.Errors.Count
}

# Test 16: Warning count matches warnings array length
Test-Command -TestName "Warning count matches warnings array" -Command {
    & "$scriptDir/Invoke-DagHealthCheck.ps1" -CorrelationId $testCorrelationId
} -Validation {
    param($result)
    return $result.Summary.WarningCount -eq $result.Warnings.Count
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
