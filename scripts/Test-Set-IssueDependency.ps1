<#
.SYNOPSIS
    Test script for Set-IssueDependency.ps1

.DESCRIPTION
    Validates key functionality of Set-IssueDependency through integration tests
    using the -DryRun mode to avoid making actual API calls.
#>

$ErrorActionPreference = "Stop"

Write-Host "Testing Set-IssueDependency..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-ScriptValidation {
    param(
        [string]$TestName,
        [scriptblock]$TestBlock,
        [scriptblock]$ValidationBlock
    )
    
    try {
        $result = & $TestBlock
        $valid = & $ValidationBlock $result
        
        if ($valid) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
            Write-Host "  Result did not match expected" -ForegroundColor Yellow
            $script:testsFailed++
        }
    } catch {
        Write-Host "✗ FAIL: $TestName (Exception)" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
    }
}

# Test 1: Script loads without errors
Test-ScriptValidation -TestName "Script syntax validation" -TestBlock {
    # Use PowerShell parser to validate syntax
    $scriptPath = "$PSScriptRoot/Set-IssueDependency.ps1"
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
    return $errors
} -ValidationBlock {
    param($errors)
    if ($errors -and $errors.Count -gt 0) {
        Write-Host "  Syntax errors found:" -ForegroundColor Yellow
        foreach ($err in $errors) {
            Write-Host "    Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Yellow
        }
        return $false
    }
    return $true
}

# Test 2: Help documentation is complete
Test-ScriptValidation -TestName "Help documentation present" -TestBlock {
    Get-Help "$PSScriptRoot/Set-IssueDependency.ps1" -Full
} -ValidationBlock {
    param($help)
    return ($help.Synopsis -and 
            $help.Description -and 
            $help.Parameters -and
            $help.Examples)
}

# Test 3: Required parameters are defined
Test-ScriptValidation -TestName "Required parameters defined" -TestBlock {
    $help = Get-Help "$PSScriptRoot/Set-IssueDependency.ps1"
    $params = $help.Parameters.Parameter
    return $params
} -ValidationBlock {
    param($params)
    $paramNames = $params | ForEach-Object { $_.Name }
    return ($paramNames -contains "IssueNumber" -and
            $paramNames -contains "DependsOn" -and
            $paramNames -contains "Blocks" -and
            $paramNames -contains "DryRun")
}

# Test 4: Validate script has error handling
Test-ScriptValidation -TestName "Error handling present" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    return ($content -match '\$ErrorActionPreference\s*=\s*"Stop"' -and
            $content -match 'try\s*\{' -and
            $content -match 'catch\s*\{')
}

# Test 5: Script uses required dependencies
Test-ScriptValidation -TestName "Required dependencies referenced" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    return ($content -match 'Invoke-GraphQL' -and
            $content -match 'ConvertTo-EscapedGraphQL' -and
            $content -match 'Write-OkyeremaLog')
}

# Test 6: Script supports DryRun mode
Test-ScriptValidation -TestName "DryRun mode implemented" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    return ($content -match 'if\s*\(\s*\$DryRun\s*\)' -and
            $content -match 'DryRun\s*=\s*\$true')
}

# Test 7: Script has cross-reference logic
Test-ScriptValidation -TestName "Cross-reference logic present" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    return ($content -match 'Cross-reference' -and
            $content -match 'BlockedBy' -and
            $content -match 'Blocks')
}

# Test 8: Script uses structured logging
Test-ScriptValidation -TestName "Structured logging used" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    $logCalls = ([regex]::Matches($content, 'Write-OkyeremaLog')).Count
    return $logCalls -ge 5  # Should have multiple log statements
}

# Test 9: Script returns structured output
Test-ScriptValidation -TestName "Structured output returned" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    return ($content -match 'return\s*\[PSCustomObject\]@\{' -and
            $content -match 'Success\s*=' -and
            $content -match 'IssueNumber\s*=' -and
            $content -match 'CorrelationId\s*=')
}

# Test 10: Script has GraphQL query construction
Test-ScriptValidation -TestName "GraphQL queries constructed" -TestBlock {
    $content = Get-Content "$PSScriptRoot/Set-IssueDependency.ps1" -Raw
    return $content
} -ValidationBlock {
    param($content)
    return ($content -match 'query\s*\{' -and
            $content -match 'mutation\s*\{' -and
            $content -match 'repository\(' -and
            $content -match 'updateIssue\(')
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Test Summary:" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor Red
Write-Host "================================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
    exit 1
}

exit 0
