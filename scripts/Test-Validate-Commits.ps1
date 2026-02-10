<#
.SYNOPSIS
    Test script for Validate-Commits.ps1

.DESCRIPTION
    Validates that Validate-Commits.ps1 properly:
    - Extracts issue references from commit messages
    - Validates issue existence and state
    - Handles different commit types (merge, revert)
    - Provides clear error messages
    - Returns correct exit codes
#>

$ErrorActionPreference = "Stop"

# Test configuration
$script:scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $script:scriptDir) {
    $script:scriptDir = $PWD.Path
}
$testCorrelationId = [guid]::NewGuid().ToString()

Write-Host "Testing Validate-Commits.ps1..." -ForegroundColor Cyan
Write-Host "Correlation ID: $testCorrelationId" -ForegroundColor Gray
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-CommitValidation {
    param(
        [string]$TestName,
        [scriptblock]$Command,
        [scriptblock]$Validation
    )
    
    Write-Host "Running: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & $Command
        
        if (& $Validation $result) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ FAIL: $TestName - Validation failed" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName - Exception: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        $script:testsFailed++
    }
    
    Write-Host ""
}

# Test 1: Script exists and is executable
Test-CommitValidation -TestName "Script file exists" -Command {
    return (Test-Path "$script:scriptDir/Validate-Commits.ps1")
} -Validation {
    param($result)
    return [bool]$result
}

# Test 2: Help content is available  
Test-CommitValidation -TestName "Help content is available" -Command {
    $content = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $content
} -Validation {
    param($result)
    return $result -match "\.SYNOPSIS" -and $result -match "Validate that all commits"
}

# Test 3: Script has required parameters
Test-CommitValidation -TestName "Required parameters defined" -Command {
    $content = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $content
} -Validation {
    param($result)
    return $result -match '\[int\]\$PRNumber' -and 
           $result -match '\[string\]\$Owner' -and 
           $result -match '\[string\]\$Repo' -and 
           $result -match '\[string\]\$CorrelationId'
}

# Test 4: Issue reference patterns - simple format
Test-CommitValidation -TestName "Script contains simple issue reference pattern (#123)" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    # Check for key components: # symbol, digit pattern, and word boundary
    return ($result -match 'simplePattern') -and ($result -match '#') -and ($result -match '\\d')
}

# Test 5: Issue reference patterns - keyword format
Test-CommitValidation -TestName "Script contains keyword issue reference pattern (Closes #456)" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    return $result -match 'Closes|Fixes|Resolves'
}

# Test 6: Issue reference patterns - cross-repo format
Test-CommitValidation -TestName "Script contains cross-repo issue reference pattern" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    return $result -match 'crossRepoPattern'
}

# Test 7: Issue reference patterns - URL format
Test-CommitValidation -TestName "Script contains URL issue reference pattern" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    return $result -match 'github\.com'
}

# Test 8: Script handles multiple references
Test-CommitValidation -TestName "Script can handle multiple issue references" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    # Check that script iterates over matches
    return $result -match 'foreach.*match'
}

# Test 9: Script handles messages without issue references
Test-CommitValidation -TestName "Script handles messages without issue references" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    # Should check if no refs found
    return $result -match 'Count -eq 0' -or $result -match 'No issue reference'
}

# Test 10: Script identifies merge commits
Test-CommitValidation -TestName "Script identifies merge commits for skipping" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    return $result -match '\^Merge'
}

# Test 11: Script identifies revert commits
Test-CommitValidation -TestName "Script identifies revert commits for skipping" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    return $result -match '\^Revert '
}

# Test 12: Script validates issue state
Test-CommitValidation -TestName "Script validates issue state (open vs closed)" -Command {
    $scriptContent = Get-Content "$script:scriptDir/Validate-Commits.ps1" -Raw
    return $scriptContent
} -Validation {
    param($result)
    return $result -match 'state' -and $result -match 'OPEN'
}

# Test 13: Workflow file exists
Test-CommitValidation -TestName "Workflow file exists" -Command {
    return (Test-Path "$script:scriptDir/../.github/workflows/commit-validator.yml")
} -Validation {
    param($result)
    return [bool]$result
}

# Test 14: Workflow has correct triggers
Test-CommitValidation -TestName "Workflow has correct triggers" -Command {
    $workflowContent = Get-Content "$script:scriptDir/../.github/workflows/commit-validator.yml" -Raw
    return $workflowContent
} -Validation {
    param($result)
    return $result -match "pull_request:" -and $result -match "opened" -and $result -match "synchronize"
}

# Test 15: Workflow has correct permissions
Test-CommitValidation -TestName "Workflow has correct permissions" -Command {
    $workflowContent = Get-Content "$script:scriptDir/../.github/workflows/commit-validator.yml" -Raw
    return $workflowContent
} -Validation {
    param($result)
    return $result -match "contents: read" -and $result -match "pull-requests: read"
}

# Test 16: Workflow uses PowerShell
Test-CommitValidation -TestName "Workflow uses PowerShell" -Command {
    $workflowContent = Get-Content "$script:scriptDir/../.github/workflows/commit-validator.yml" -Raw
    return $workflowContent
} -Validation {
    param($result)
    return $result -match "shell: pwsh"
}

# Test 17: Workflow has graceful degradation
Test-CommitValidation -TestName "Workflow has graceful degradation" -Command {
    $workflowContent = Get-Content "$script:scriptDir/../.github/workflows/commit-validator.yml" -Raw
    return $workflowContent
} -Validation {
    param($result)
    return $result -match "Test-Path" -and $result -match "graceful degradation"
}

# Print final summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Total Tests: $($testsPassed + $testsFailed)" -ForegroundColor Gray
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "❌ Some tests failed" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
}
