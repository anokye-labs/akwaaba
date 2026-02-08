<#
.SYNOPSIS
    Test script for New-IssueBatch.ps1

.DESCRIPTION
    Validates New-IssueBatch.ps1 functionality including:
    - JSON and CSV parsing
    - Validation logic
    - DryRun mode
    - Error handling
#>

$ErrorActionPreference = "Stop"

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Testing New-IssueBatch.ps1..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Case {
    param(
        [string]$TestName,
        [scriptblock]$TestBlock,
        [switch]$ExpectError
    )
    
    try {
        & $TestBlock
        
        if ($ExpectError) {
            Write-Host "✗ FAIL: $TestName (Expected error but none was thrown)" -ForegroundColor Red
            $script:testsFailed++
        }
        else {
            Write-Host "✓ PASS: $TestName" -ForegroundColor Green
            $script:testsPassed++
        }
    }
    catch {
        if ($ExpectError) {
            Write-Host "✓ PASS: $TestName (Error caught as expected: $_)" -ForegroundColor Green
            $script:testsPassed++
        }
        else {
            Write-Host "✗ FAIL: $TestName (Unexpected error: $_)" -ForegroundColor Red
            $script:testsFailed++
        }
    }
}

# Test 1: JSON parsing with valid input
Test-Case -TestName "Parse valid JSON file" -TestBlock {
    $result = & "$scriptDir/New-IssueBatch.ps1" `
        -InputFile "$scriptDir/examples/batch-issues.json" `
        -Owner "test-org" `
        -Repo "test-repo" `
        -DryRun `
        -Quiet
    
    if ($result.Count -ne 8) {
        throw "Expected 8 issues, got $($result.Count)"
    }
}

# Test 2: CSV parsing with valid input
Test-Case -TestName "Parse valid CSV file" -TestBlock {
    $result = & "$scriptDir/New-IssueBatch.ps1" `
        -InputFile "$scriptDir/examples/batch-issues.csv" `
        -Owner "test-org" `
        -Repo "test-repo" `
        -DryRun `
        -Quiet
    
    if ($result.Count -ne 8) {
        throw "Expected 8 issues, got $($result.Count)"
    }
}

# Test 3: Reject invalid file extension
Test-Case -TestName "Reject invalid file extension" -TestBlock {
    $tempFile = New-TemporaryFile
    $tempFile = Rename-Item $tempFile "$($tempFile.FullName).txt" -PassThru
    "test" | Out-File $tempFile
    
    try {
        & "$scriptDir/New-IssueBatch.ps1" `
            -InputFile $tempFile `
            -Owner "test-org" `
            -Repo "test-repo" `
            -DryRun `
            -Quiet
    }
    finally {
        Remove-Item $tempFile -Force
    }
} -ExpectError

# Test 4: Reject missing required fields
Test-Case -TestName "Reject missing title field" -TestBlock {
    $tempFile = New-TemporaryFile
    $tempFile = Rename-Item $tempFile "$($tempFile.FullName).json" -PassThru
    
    @'
[
  {
    "type": "Task",
    "body": "Description"
  }
]
'@ | Out-File $tempFile
    
    try {
        & "$scriptDir/New-IssueBatch.ps1" `
            -InputFile $tempFile `
            -Owner "test-org" `
            -Repo "test-repo" `
            -DryRun `
            -Quiet
    }
    finally {
        Remove-Item $tempFile -Force
    }
} -ExpectError

# Test 5: Reject invalid issue type
Test-Case -TestName "Reject invalid issue type" -TestBlock {
    $tempFile = New-TemporaryFile
    $tempFile = Rename-Item $tempFile "$($tempFile.FullName).json" -PassThru
    
    @'
[
  {
    "title": "Test Issue",
    "type": "InvalidType",
    "body": "Description"
  }
]
'@ | Out-File $tempFile
    
    try {
        & "$scriptDir/New-IssueBatch.ps1" `
            -InputFile $tempFile `
            -Owner "test-org" `
            -Repo "test-repo" `
            -DryRun `
            -Quiet
    }
    finally {
        Remove-Item $tempFile -Force
    }
} -ExpectError

# Test 6: Reject forward parent reference
Test-Case -TestName "Reject forward parent reference" -TestBlock {
    $tempFile = New-TemporaryFile
    $tempFile = Rename-Item $tempFile "$($tempFile.FullName).json" -PassThru
    
    @'
[
  {
    "title": "Child Issue",
    "type": "Task",
    "body": "Description",
    "parent": 2
  },
  {
    "title": "Parent Issue",
    "type": "Epic",
    "body": "Description"
  }
]
'@ | Out-File $tempFile
    
    try {
        & "$scriptDir/New-IssueBatch.ps1" `
            -InputFile $tempFile `
            -Owner "test-org" `
            -Repo "test-repo" `
            -DryRun `
            -Quiet
    }
    finally {
        Remove-Item $tempFile -Force
    }
} -ExpectError

# Test 7: DryRun mode returns expected structure
Test-Case -TestName "DryRun returns correct structure" -TestBlock {
    $result = & "$scriptDir/New-IssueBatch.ps1" `
        -InputFile "$scriptDir/examples/batch-issues.json" `
        -Owner "test-org" `
        -Repo "test-repo" `
        -DryRun `
        -Quiet
    
    $firstIssue = $result[0]
    
    if (-not $firstIssue.Index) { throw "Missing Index property" }
    if (-not $firstIssue.Title) { throw "Missing Title property" }
    if (-not $firstIssue.Type) { throw "Missing Type property" }
    if (-not $firstIssue.Url) { throw "Missing Url property" }
    
    if ($firstIssue.Title -ne "Epic: Phase 3 Development") {
        throw "Incorrect title: $($firstIssue.Title)"
    }
    if ($firstIssue.Type -ne "Epic") {
        throw "Incorrect type: $($firstIssue.Type)"
    }
}

# Test 8: Parent-child relationships are tracked
Test-Case -TestName "Parent-child relationships tracked" -TestBlock {
    $result = & "$scriptDir/New-IssueBatch.ps1" `
        -InputFile "$scriptDir/examples/batch-issues.json" `
        -Owner "test-org" `
        -Repo "test-repo" `
        -DryRun `
        -Quiet
    
    $childIssue = $result[1]  # Second issue (Feature: User Authentication System)
    
    if ($childIssue.Parent -ne 1) {
        throw "Expected parent reference 1, got $($childIssue.Parent)"
    }
}

# Test 9: Labels are preserved
Test-Case -TestName "Labels are preserved from JSON" -TestBlock {
    $result = & "$scriptDir/New-IssueBatch.ps1" `
        -InputFile "$scriptDir/examples/batch-issues.json" `
        -Owner "test-org" `
        -Repo "test-repo" `
        -DryRun `
        -Quiet
    
    $firstIssue = $result[0]
    
    if ($firstIssue.Labels.Count -ne 2) {
        throw "Expected 2 labels, got $($firstIssue.Labels.Count)"
    }
    if ("documentation" -notin $firstIssue.Labels) {
        throw "Missing expected label 'documentation'"
    }
    if ("enhancement" -notin $firstIssue.Labels) {
        throw "Missing expected label 'enhancement'"
    }
}

# Test 10: CSV semicolon-separated labels
Test-Case -TestName "CSV semicolon-separated labels parsed" -TestBlock {
    $result = & "$scriptDir/New-IssueBatch.ps1" `
        -InputFile "$scriptDir/examples/batch-issues.csv" `
        -Owner "test-org" `
        -Repo "test-repo" `
        -DryRun `
        -Quiet
    
    $issueWithMultipleLabels = $result[1]  # Feature with 'security' label
    
    if ($issueWithMultipleLabels.Labels.Count -lt 1) {
        throw "Expected at least 1 label, got $($issueWithMultipleLabels.Labels.Count)"
    }
}

# Summary
Write-Host ""
Write-Host "==================" -ForegroundColor Cyan
Write-Host "Tests Passed: $testsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "==================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
    exit 1
}
else {
    Write-Host ""
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
}
