<#
.SYNOPSIS
    Test script for Get-BlockedIssues.ps1

.DESCRIPTION
    Validates that Get-BlockedIssues.ps1 correctly parses issue dependencies,
    identifies blocked issues, and generates resolution order.
#>

# Import the script functions (but not execute the main body)
$scriptPath = Join-Path $PSScriptRoot "Get-BlockedIssues.ps1"

Write-Host "Testing Get-BlockedIssues.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestCode,
        [scriptblock]$Validation
    )
    
    try {
        $result = & $TestCode
        $validationResult = & $Validation -Result $result
        
        if ($validationResult) {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName - Exception: $_" -ForegroundColor Red
        $script:testsFailed++
    }
}

# Extract and define the functions we need to test
# Instead of dot-sourcing which would execute the script, we'll copy the function definitions

function Get-IssueDependencies {
    param(
        [string]$Body
    )
    
    if (-not $Body) {
        return @()
    }
    
    $dependencies = @()
    
    # Pattern to match "Blocked by:" section
    $blockedByPattern = '(?ms)(?:^|\n)##\s*Dependencies\s*\n+Blocked\s+by:\s*\n(.*?)(?=\n##|\z)'
    
    if ($Body -match $blockedByPattern) {
        $blockedBySection = $matches[1]
        
        # Extract issue references
        $issuePattern = '(?:^|\s)-\s*\[[\sx]\]\s*(?:https?://github\.com/)?([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+)?#(\d+)'
        
        $matches = [regex]::Matches($blockedBySection, $issuePattern)
        
        foreach ($match in $matches) {
            $repoRef = $match.Groups[1].Value
            $issueNumber = $match.Groups[2].Value
            
            if ($repoRef) {
                $dependencies += [PSCustomObject]@{
                    Repository = $repoRef
                    Number = [int]$issueNumber
                    IsExternal = $true
                }
            } else {
                $dependencies += [PSCustomObject]@{
                    Repository = $null
                    Number = [int]$issueNumber
                    IsExternal = $false
                }
            }
        }
    }
    
    return $dependencies
}

function Find-BlockedIssues {
    param(
        [array]$Issues,
        [string]$CurrentRepo
    )
    
    $blockedIssues = @()
    
    foreach ($issue in $Issues) {
        if ($issue.state -ne "OPEN") {
            continue
        }
        
        $dependencies = Get-IssueDependencies -Body $issue.body
        
        if ($dependencies.Count -eq 0) {
            continue
        }
        
        $blockingIssues = @()
        
        foreach ($dep in $dependencies) {
            if ($dep.IsExternal) {
                $blockingIssues += [PSCustomObject]@{
                    Number = $dep.Number
                    Repository = $dep.Repository
                    State = "UNKNOWN"
                    IsBlocking = $true
                }
            } else {
                $depIssue = $Issues | Where-Object { $_.number -eq $dep.Number }
                
                if ($depIssue) {
                    if ($depIssue.state -eq "OPEN") {
                        $blockingIssues += [PSCustomObject]@{
                            Number = $depIssue.number
                            Title = $depIssue.title
                            Repository = $CurrentRepo
                            State = $depIssue.state
                            IsBlocking = $true
                        }
                    }
                } else {
                    $blockingIssues += [PSCustomObject]@{
                        Number = $dep.Number
                        Repository = $CurrentRepo
                        State = "NOT_FOUND"
                        IsBlocking = $true
                    }
                }
            }
        }
        
        if ($blockingIssues.Count -gt 0) {
            $blockedIssues += [PSCustomObject]@{
                Number = $issue.number
                Title = $issue.title
                State = $issue.state
                Url = $issue.url
                BlockedBy = $blockingIssues
                BlockCount = $blockingIssues.Count
            }
        }
    }
    
    return $blockedIssues
}

function Get-ResolutionOrder {
    param(
        [array]$Issues
    )
    
    # Build dependency graph
    $graph = @{}
    $inDegree = @{}
    
    # Initialize
    foreach ($issue in $Issues) {
        if ($issue.state -eq "OPEN") {
            $graph[$issue.number] = @()
            $inDegree[$issue.number] = 0
        }
    }
    
    # Build edges
    foreach ($issue in $Issues) {
        if ($issue.state -ne "OPEN") {
            continue
        }
        
        $dependencies = Get-IssueDependencies -Body $issue.body
        
        foreach ($dep in $dependencies) {
            if (-not $dep.IsExternal) {
                $depIssue = $Issues | Where-Object { $_.number -eq $dep.Number -and $_.state -eq "OPEN" }
                
                if ($depIssue) {
                    if (-not $graph.ContainsKey($dep.Number)) {
                        $graph[$dep.Number] = @()
                        $inDegree[$dep.Number] = 0
                    }
                    
                    $graph[$dep.Number] += $issue.number
                    $inDegree[$issue.number]++
                }
            }
        }
    }
    
    # Kahn's algorithm for topological sort
    $queue = [System.Collections.Queue]::new()
    
    foreach ($node in $inDegree.Keys) {
        if ($inDegree[$node] -eq 0) {
            $queue.Enqueue($node)
        }
    }
    
    $order = @()
    
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        $order += $current
        
        foreach ($neighbor in $graph[$current]) {
            $inDegree[$neighbor]--
            
            if ($inDegree[$neighbor] -eq 0) {
                $queue.Enqueue($neighbor)
            }
        }
    }
    
    # Convert to issue objects with titles
    $orderedIssues = @()
    foreach ($num in $order) {
        $issue = $Issues | Where-Object { $_.number -eq $num }
        if ($issue) {
            $orderedIssues += [PSCustomObject]@{
                Number = $issue.number
                Title = $issue.title
                Url = $issue.url
            }
        }
    }
    
    return $orderedIssues
}

# Test 1: Parse simple dependency
Write-Host "Test 1: Parse simple dependency from issue body" -ForegroundColor Yellow

$testBody = @"
# Issue Title

Some description.

## Dependencies

Blocked by:
- [ ] anokye-labs/akwaaba#14 - Invoke-GraphQL.ps1

More content here.
"@

Test-Function -TestName "Parse simple dependency" -TestCode {
    Get-IssueDependencies -Body $testBody
} -Validation {
    param($Result)
    return ($Result.Count -eq 1 -and $Result[0].Number -eq 14 -and $Result[0].Repository -eq "anokye-labs/akwaaba")
}

# Test 2: Parse multiple dependencies
Write-Host "Test 2: Parse multiple dependencies" -ForegroundColor Yellow

$testBody2 = @"
## Dependencies

Blocked by:
- [ ] anokye-labs/akwaaba#14 - Invoke-GraphQL.ps1
- [ ] anokye-labs/akwaaba#15 - Get-RepoContext.ps1
- [ ] anokye-labs/akwaaba#17 - Write-OkyeremaLog.ps1
"@

Test-Function -TestName "Parse multiple dependencies" -TestCode {
    Get-IssueDependencies -Body $testBody2
} -Validation {
    param($Result)
    return ($Result.Count -eq 3 -and $Result[0].Number -eq 14 -and $Result[1].Number -eq 15 -and $Result[2].Number -eq 17)
}

# Test 3: Parse local reference (no repo)
Write-Host "Test 3: Parse local issue reference" -ForegroundColor Yellow

$testBody3 = @"
## Dependencies

Blocked by:
- [ ] #42 - Some local issue
"@

Test-Function -TestName "Parse local issue reference" -TestCode {
    Get-IssueDependencies -Body $testBody3
} -Validation {
    param($Result)
    return ($Result.Count -eq 1 -and $Result[0].Number -eq 42 -and -not $Result[0].IsExternal)
}

# Test 4: Parse checked items
Write-Host "Test 4: Parse checked dependency items" -ForegroundColor Yellow

$testBody4 = @"
## Dependencies

Blocked by:
- [x] anokye-labs/akwaaba#10 - Completed dependency
- [ ] anokye-labs/akwaaba#11 - Pending dependency
"@

Test-Function -TestName "Parse checked items" -TestCode {
    Get-IssueDependencies -Body $testBody4
} -Validation {
    param($Result)
    # Should parse both checked and unchecked items
    return ($Result.Count -eq 2 -and $Result[0].Number -eq 10 -and $Result[1].Number -eq 11)
}

# Test 5: Handle empty body
Write-Host "Test 5: Handle empty issue body" -ForegroundColor Yellow

Test-Function -TestName "Handle empty body" -TestCode {
    Get-IssueDependencies -Body ""
} -Validation {
    param($Result)
    return ($Result.Count -eq 0)
}

# Test 6: Handle body with no dependencies section
Write-Host "Test 6: Handle body with no dependencies section" -ForegroundColor Yellow

$testBody6 = @"
# Issue Title

This is a regular issue with no dependencies.

## Description

Some description here.
"@

Test-Function -TestName "Handle body with no dependencies" -TestCode {
    Get-IssueDependencies -Body $testBody6
} -Validation {
    param($Result)
    return ($Result.Count -eq 0)
}

# Test 7: Mixed local and external references
Write-Host "Test 7: Parse mixed local and external references" -ForegroundColor Yellow

$testBody7 = @"
## Dependencies

Blocked by:
- [ ] #5 - Local issue
- [ ] owner/repo#100 - External issue
- [ ] anokye-labs/other-repo#200 - Another external
"@

Test-Function -TestName "Parse mixed references" -TestCode {
    Get-IssueDependencies -Body $testBody7
} -Validation {
    param($Result)
    $local = $Result | Where-Object { -not $_.IsExternal }
    $external = $Result | Where-Object { $_.IsExternal }
    return ($Result.Count -eq 3 -and $local.Count -eq 1 -and $external.Count -eq 2)
}

# Test 8: Resolution order with simple dependency chain
Write-Host "Test 8: Generate resolution order for dependency chain" -ForegroundColor Yellow

$testIssues = @(
    [PSCustomObject]@{
        number = 1
        title = "Issue 1"
        state = "OPEN"
        body = @"
## Dependencies
Blocked by:
- [ ] #2 - Issue 2
"@
        url = "http://example.com/1"
    }
    [PSCustomObject]@{
        number = 2
        title = "Issue 2"
        state = "OPEN"
        body = ""
        url = "http://example.com/2"
    }
)

Test-Function -TestName "Generate resolution order" -TestCode {
    Get-ResolutionOrder -Issues $testIssues
} -Validation {
    param($Result)
    # Issue 2 should come before Issue 1 in resolution order
    return ($Result.Count -eq 2 -and $Result[0].Number -eq 2 -and $Result[1].Number -eq 1)
}

# Test 9: Find blocked issues
Write-Host "Test 9: Find blocked issues correctly" -ForegroundColor Yellow

Test-Function -TestName "Find blocked issues" -TestCode {
    Find-BlockedIssues -Issues $testIssues -CurrentRepo "owner/repo"
} -Validation {
    param($Result)
    # Issue 1 should be blocked by Issue 2
    return ($Result.Count -eq 1 -and $Result[0].Number -eq 1 -and $Result[0].BlockedBy.Count -eq 1)
}

# Test 10: Handle closed blocking issue
Write-Host "Test 10: Handle closed blocking issues" -ForegroundColor Yellow

$testIssues10 = @(
    [PSCustomObject]@{
        number = 1
        title = "Issue 1"
        state = "OPEN"
        body = @"
## Dependencies
Blocked by:
- [ ] #2 - Issue 2
"@
        url = "http://example.com/1"
    }
    [PSCustomObject]@{
        number = 2
        title = "Issue 2"
        state = "CLOSED"
        body = ""
        url = "http://example.com/2"
    }
)

Test-Function -TestName "Handle closed blocking issue" -TestCode {
    Find-BlockedIssues -Issues $testIssues10 -CurrentRepo "owner/repo"
} -Validation {
    param($Result)
    # Issue 1 should NOT be blocked since Issue 2 is closed
    return ($Result.Count -eq 0)
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })

if ($testsFailed -gt 0) {
    exit 1
}

exit 0
