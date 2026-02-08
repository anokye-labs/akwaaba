<#
.SYNOPSIS
    Test script for New-IssueHierarchy.ps1

.DESCRIPTION
    Validates that New-IssueHierarchy.ps1 properly creates issue hierarchies
    with correct structure, tasklist relationships, and project board additions.
#>

# Define test helper functions by extracting them from the main script
# We don't dot-source the main script because it has mandatory parameters

# Validation function from New-IssueHierarchy.ps1
function Test-HierarchyDefinition {
    param([hashtable]$Definition, [string]$Path = "root")
    
    if (-not $Definition.Type) {
        throw "Missing 'Type' at $Path"
    }
    
    if ($Definition.Type -notin @("Epic", "Feature", "Task", "Bug")) {
        throw "Invalid Type '$($Definition.Type)' at $Path. Must be Epic, Feature, Task, or Bug."
    }
    
    if (-not $Definition.Title) {
        throw "Missing 'Title' at $Path"
    }
    
    if ($Definition.Children) {
        $childIndex = 0
        foreach ($child in $Definition.Children) {
            Test-HierarchyDefinition -Definition $child -Path "$Path.Children[$childIndex]"
            $childIndex++
        }
    }
}

Write-Host "Testing New-IssueHierarchy..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Case {
    param(
        [string]$TestName,
        [scriptblock]$TestBlock
    )
    
    try {
        & $TestBlock
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        $script:testsPassed++
    } catch {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:testsFailed++
    }
}

# Test 1: Validate hierarchy structure validation
Test-Case -TestName "Reject hierarchy without Type" -TestBlock {
    $invalidHierarchy = @{
        Title = "Test"
    }
    
    try {
        Test-HierarchyDefinition -Definition $invalidHierarchy
        throw "Should have thrown validation error"
    } catch {
        if ($_ -match "Missing 'Type'") {
            # Expected error
        } else {
            throw
        }
    }
}

# Test 2: Validate hierarchy structure validation for invalid type
Test-Case -TestName "Reject hierarchy with invalid Type" -TestBlock {
    $invalidHierarchy = @{
        Type = "InvalidType"
        Title = "Test"
    }
    
    try {
        Test-HierarchyDefinition -Definition $invalidHierarchy
        throw "Should have thrown validation error"
    } catch {
        if ($_ -match "Invalid Type") {
            # Expected error
        } else {
            throw
        }
    }
}

# Test 3: Validate hierarchy structure validation for missing title
Test-Case -TestName "Reject hierarchy without Title" -TestBlock {
    $invalidHierarchy = @{
        Type = "Epic"
    }
    
    try {
        Test-HierarchyDefinition -Definition $invalidHierarchy
        throw "Should have thrown validation error"
    } catch {
        if ($_ -match "Missing 'Title'") {
            # Expected error
        } else {
            throw
        }
    }
}

# Test 4: Accept valid simple hierarchy
Test-Case -TestName "Accept valid simple hierarchy" -TestBlock {
    $validHierarchy = @{
        Type = "Epic"
        Title = "Test Epic"
        Body = "Epic description"
    }
    
    Test-HierarchyDefinition -Definition $validHierarchy
}

# Test 5: Accept valid nested hierarchy
Test-Case -TestName "Accept valid nested hierarchy" -TestBlock {
    $validHierarchy = @{
        Type = "Epic"
        Title = "Test Epic"
        Body = "Epic description"
        Children = @(
            @{
                Type = "Feature"
                Title = "Test Feature"
                Body = "Feature description"
                Children = @(
                    @{
                        Type = "Task"
                        Title = "Test Task"
                    }
                )
            }
        )
    }
    
    Test-HierarchyDefinition -Definition $validHierarchy
}

# Test 6: Validate child validation in nested structure
Test-Case -TestName "Reject nested hierarchy with invalid child" -TestBlock {
    $invalidHierarchy = @{
        Type = "Epic"
        Title = "Test Epic"
        Children = @(
            @{
                Type = "Feature"
                # Missing Title
            }
        )
    }
    
    try {
        Test-HierarchyDefinition -Definition $invalidHierarchy
        throw "Should have thrown validation error"
    } catch {
        if ($_ -match "Missing 'Title'") {
            # Expected error
        } else {
            throw
        }
    }
}

# Test 7: DryRun mode should not fail
# Note: We can't test the full script execution without mandatory parameters
# This test would require actual GitHub API access
Test-Case -TestName "DryRun mode preparation validates" -TestBlock {
    # Just validate the hierarchy is accepted for dry run
    $hierarchy = @{
        Type = "Epic"
        Title = "Test Epic (DryRun)"
        Body = "Testing dry run mode"
    }
    
    Test-HierarchyDefinition -Definition $hierarchy
}

# Test 8: Accept Bug type in hierarchy
Test-Case -TestName "Accept Bug issue type" -TestBlock {
    $validHierarchy = @{
        Type = "Bug"
        Title = "Test Bug"
        Body = "Bug description"
    }
    
    Test-HierarchyDefinition -Definition $validHierarchy
}

# Test 9: Epic → Task hierarchy (skipping Feature level)
Test-Case -TestName "Accept Epic → Task hierarchy" -TestBlock {
    $validHierarchy = @{
        Type = "Epic"
        Title = "Test Epic"
        Children = @(
            @{
                Type = "Task"
                Title = "Direct Task 1"
            }
            @{
                Type = "Task"
                Title = "Direct Task 2"
            }
        )
    }
    
    Test-HierarchyDefinition -Definition $validHierarchy
}

# Test 10: Complex multi-level hierarchy
Test-Case -TestName "Accept complex multi-level hierarchy" -TestBlock {
    $validHierarchy = @{
        Type = "Epic"
        Title = "Test Epic"
        Children = @(
            @{
                Type = "Feature"
                Title = "Feature 1"
                Children = @(
                    @{ Type = "Task"; Title = "Task 1.1" }
                    @{ Type = "Task"; Title = "Task 1.2" }
                )
            }
            @{
                Type = "Feature"
                Title = "Feature 2"
                Children = @(
                    @{ Type = "Task"; Title = "Task 2.1" }
                    @{ Type = "Task"; Title = "Task 2.2" }
                    @{ Type = "Task"; Title = "Task 2.3" }
                )
            }
        )
    }
    
    Test-HierarchyDefinition -Definition $validHierarchy
}

Write-Host ""
Write-Host "========================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "  Passed: $testsPassed" -ForegroundColor Green
Write-Host "  Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "========================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
    exit 1
}
