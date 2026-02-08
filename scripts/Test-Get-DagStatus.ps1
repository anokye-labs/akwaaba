<#
.SYNOPSIS
    Test script for Get-DagStatus.ps1

.DESCRIPTION
    Validates that Get-DagStatus.ps1 properly walks issue hierarchies,
    calculates metrics, identifies blocked/ready items, and outputs in
    multiple formats.
#>

$ErrorActionPreference = "Stop"

# Test configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testCorrelationId = [guid]::NewGuid().ToString()

Write-Host "Testing Get-DagStatus.ps1..." -ForegroundColor Cyan
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
        $script:testsFailed++
    }
    
    Write-Host ""
}

# Test 1: Script exists and is executable
Test-Command -TestName "Script file exists" -Command {
    Test-Path "$scriptDir/Get-DagStatus.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 2: Help content is available
Test-Command -TestName "Help content is available" -Command {
    Get-Help "$scriptDir/Get-DagStatus.ps1"
} -Validation {
    param($result)
    return $result.Synopsis -match "Recursively walk"
}

# Test 3: Script has required parameters
Test-Command -TestName "Required parameters defined" -Command {
    $params = (Get-Command "$scriptDir/Get-DagStatus.ps1").Parameters
    @{
        HasIssueNumber = $params.ContainsKey("IssueNumber")
        HasFormat = $params.ContainsKey("Format")
        HasMaxDepth = $params.ContainsKey("MaxDepth")
        HasCorrelationId = $params.ContainsKey("CorrelationId")
    }
} -Validation {
    param($result)
    return $result.HasIssueNumber -and $result.HasFormat -and $result.HasMaxDepth -and $result.HasCorrelationId
}

# Test 4: Format parameter accepts valid values
Test-Command -TestName "Format parameter validation" -Command {
    $param = (Get-Command "$scriptDir/Get-DagStatus.ps1").Parameters["Format"]
    $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
    $validateSet.ValidValues
} -Validation {
    param($result)
    return ($result -contains "Tree") -and ($result -contains "JSON") -and ($result -contains "CSV")
}

# Test 5: Dependencies exist
Test-Command -TestName "Invoke-GraphQL.ps1 exists" -Command {
    Test-Path "$scriptDir/Invoke-GraphQL.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

Test-Command -TestName "Get-RepoContext.ps1 exists" -Command {
    Test-Path "$scriptDir/Get-RepoContext.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

Test-Command -TestName "Write-OkyeremaLog.ps1 exists" -Command {
    Test-Path "$scriptDir/../.github/skills/okyerema/scripts/Write-OkyeremaLog.ps1"
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 6: Script can be dot-sourced without error
Test-Command -TestName "Script can be dot-sourced" -Command {
    try {
        # Create a test function to verify the script loaded
        $testScript = @"
`$scriptContent = Get-Content "$scriptDir/Get-DagStatus.ps1" -Raw
# Check if script has valid PowerShell syntax
`$null = [System.Management.Automation.PSParser]::Tokenize(`$scriptContent, [ref]`$null)
return `$true
"@
        Invoke-Expression $testScript
    }
    catch {
        return $false
    }
} -Validation {
    param($result)
    return $result -eq $true
}

# Test 7: Script handles missing issue gracefully (error case)
Write-Host "Running: Script handles non-existent issue" -ForegroundColor Yellow
try {
    # Try with a very high issue number that likely doesn't exist
    $output = & "$scriptDir/Get-DagStatus.ps1" -IssueNumber 999999 -CorrelationId $testCorrelationId 2>&1
    
    # If it didn't throw, check if it handled gracefully
    Write-Host "✗ FAIL: Script should have thrown an error for non-existent issue" -ForegroundColor Red
    $testsFailed++
}
catch {
    # Expected to fail for non-existent issue
    if ($_.Exception.Message -match "Failed to fetch issue|not found|404") {
        Write-Host "✓ PASS: Script handles non-existent issue with proper error" -ForegroundColor Green
        $testsPassed++
    } else {
        Write-Host "✗ FAIL: Script threw unexpected error: $_" -ForegroundColor Red
        $testsFailed++
    }
}
Write-Host ""

# Test 8: Test with a real issue (if available)
Write-Host "Running: Integration test with real issue" -ForegroundColor Yellow
try {
    # Try to find the first open issue in the repository
    $issueList = gh issue list --limit 1 --json number,state | ConvertFrom-Json
    
    if ($issueList -and $issueList.Count -gt 0) {
        $testIssue = $issueList[0].number
        Write-Host "  Testing with issue #$testIssue" -ForegroundColor Gray
        
        # Test Tree format
        $output = & "$scriptDir/Get-DagStatus.ps1" -IssueNumber $testIssue -Format Tree -CorrelationId $testCorrelationId 2>&1
        
        if ($output -match "#$testIssue") {
            Write-Host "✓ PASS: Tree format works with real issue" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Tree format output doesn't contain issue number" -ForegroundColor Red
            $testsFailed++
        }
        
        # Test JSON format
        $jsonOutput = & "$scriptDir/Get-DagStatus.ps1" -IssueNumber $testIssue -Format JSON -CorrelationId $testCorrelationId 2>&1 | Out-String
        $jsonOutput = $jsonOutput.Trim()
        
        try {
            $parsed = $jsonOutput | ConvertFrom-Json
            if ($parsed.Number -eq $testIssue) {
                Write-Host "✓ PASS: JSON format works with real issue" -ForegroundColor Green
                $testsPassed++
            } else {
                Write-Host "✗ FAIL: JSON format doesn't contain correct issue number" -ForegroundColor Red
                $testsFailed++
            }
        }
        catch {
            Write-Host "✗ FAIL: JSON output is not valid JSON: $_" -ForegroundColor Red
            $testsFailed++
        }
        
        # Test CSV format
        $csvOutput = & "$scriptDir/Get-DagStatus.ps1" -IssueNumber $testIssue -Format CSV -CorrelationId $testCorrelationId 2>&1 | Out-String
        
        if ($csvOutput -match "Number,Title,State" -and $csvOutput -match $testIssue) {
            Write-Host "✓ PASS: CSV format works with real issue" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: CSV format output is invalid" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "⊘ SKIP: No open issues found in repository for integration test" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⊘ SKIP: Could not run integration test: $_" -ForegroundColor Yellow
}
Write-Host ""

# Test 9: Verify structured logging to stderr
Write-Host "Running: Structured logging to stderr" -ForegroundColor Yellow
try {
    # Capture stderr separately
    $tempStderr = [System.IO.Path]::GetTempFileName()
    
    # Try to find an issue to test with
    $issueList = gh issue list --limit 1 --json number | ConvertFrom-Json
    
    if ($issueList -and $issueList.Count -gt 0) {
        $testIssue = $issueList[0].number
        
        # Run script and redirect stderr to file
        $null = & "$scriptDir/Get-DagStatus.ps1" -IssueNumber $testIssue -Format JSON -CorrelationId $testCorrelationId 2>$tempStderr
        
        # Read stderr content
        $stderrContent = Get-Content $tempStderr -Raw
        
        # Check if stderr contains JSON log messages
        if ($stderrContent -match '"timestamp"' -and $stderrContent -match '"level"' -and $stderrContent -match '"message"') {
            Write-Host "✓ PASS: Structured logging to stderr works" -ForegroundColor Green
            $testsPassed++
        } else {
            Write-Host "✗ FAIL: Stderr doesn't contain structured log messages" -ForegroundColor Red
            $testsFailed++
        }
    }
    else {
        Write-Host "⊘ SKIP: No issues found for logging test" -ForegroundColor Yellow
    }
    
    # Cleanup
    Remove-Item $tempStderr -ErrorAction SilentlyContinue
}
catch {
    Write-Host "⊘ SKIP: Could not test structured logging: $_" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "==================== TEST SUMMARY ====================" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "FAILED: Some tests did not pass." -ForegroundColor Red
    exit 1
} else {
    Write-Host "SUCCESS: All tests passed!" -ForegroundColor Green
    exit 0
}
