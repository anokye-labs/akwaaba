<#
.SYNOPSIS
    Test script for Import-DagFromJson.ps1

.DESCRIPTION
    Validates Import-DagFromJson.ps1 functionality including:
    - JSON parsing and validation
    - DAG cycle detection
    - Topological sort
    - DryRun mode
#>

# Import the script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir/Import-DagFromJson.ps1"

Write-Host "Testing Import-DagFromJson..." -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-DagImport {
    param(
        [string]$TestName,
        [string]$JsonInput,
        [bool]$ShouldSucceed,
        [string]$ExpectedError = ""
    )
    
    Write-Host "Running: $TestName" -ForegroundColor Yellow
    
    try {
        $result = & "$scriptDir/Import-DagFromJson.ps1" -JsonString $JsonInput -DryRun -Quiet
        
        if ($ShouldSucceed) {
            if ($result.Success) {
                Write-Host "✓ PASS: $TestName" -ForegroundColor Green
                $script:testsPassed++
            } else {
                Write-Host "✗ FAIL: $TestName - Expected success but got failure" -ForegroundColor Red
                Write-Host "  Errors: $($result.Errors -join ', ')" -ForegroundColor Yellow
                $script:testsFailed++
            }
        } else {
            if (-not $result.Success) {
                if ($ExpectedError -and $result.Errors[0] -notmatch $ExpectedError) {
                    Write-Host "✗ FAIL: $TestName - Wrong error message" -ForegroundColor Red
                    Write-Host "  Expected: $ExpectedError" -ForegroundColor Yellow
                    Write-Host "  Got: $($result.Errors[0])" -ForegroundColor Yellow
                    $script:testsFailed++
                } else {
                    Write-Host "✓ PASS: $TestName (correctly failed)" -ForegroundColor Green
                    $script:testsPassed++
                }
            } else {
                Write-Host "✗ FAIL: $TestName - Expected failure but succeeded" -ForegroundColor Red
                $script:testsFailed++
            }
        }
    }
    catch {
        Write-Host "✗ FAIL: $TestName - Exception: $_" -ForegroundColor Red
        $script:testsFailed++
    }
    
    Write-Host ""
}

# Test 1: Valid simple DAG
$validSimpleDag = @"
{
  "nodes": [
    {
      "id": "epic-1",
      "title": "Epic Issue",
      "type": "Epic",
      "body": "Epic description"
    },
    {
      "id": "feature-1",
      "title": "Feature Issue",
      "type": "Feature",
      "body": "Feature description"
    }
  ],
  "edges": [
    {
      "from": "epic-1",
      "to": "feature-1",
      "relationship": "tracks"
    }
  ]
}
"@

Test-DagImport -TestName "Valid simple DAG" -JsonInput $validSimpleDag -ShouldSucceed $true

# Test 2: DAG with no edges
$dagNoEdges = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task Issue",
      "type": "Task",
      "body": "Task description"
    }
  ],
  "edges": []
}
"@

Test-DagImport -TestName "DAG with no edges" -JsonInput $dagNoEdges -ShouldSucceed $true

# Test 3: Complex DAG with multiple levels
$complexDag = @"
{
  "nodes": [
    {
      "id": "epic-1",
      "title": "Epic",
      "type": "Epic",
      "body": "Top level"
    },
    {
      "id": "feature-1",
      "title": "Feature 1",
      "type": "Feature",
      "body": "Feature 1"
    },
    {
      "id": "feature-2",
      "title": "Feature 2",
      "type": "Feature",
      "body": "Feature 2"
    },
    {
      "id": "task-1",
      "title": "Task 1",
      "type": "Task",
      "body": "Task under feature 1"
    },
    {
      "id": "task-2",
      "title": "Task 2",
      "type": "Task",
      "body": "Task under feature 2"
    }
  ],
  "edges": [
    {"from": "epic-1", "to": "feature-1", "relationship": "tracks"},
    {"from": "epic-1", "to": "feature-2", "relationship": "tracks"},
    {"from": "feature-1", "to": "task-1", "relationship": "tracks"},
    {"from": "feature-2", "to": "task-2", "relationship": "tracks"}
  ]
}
"@

Test-DagImport -TestName "Complex multi-level DAG" -JsonInput $complexDag -ShouldSucceed $true

# Test 4: Missing nodes array
$missingNodes = @"
{
  "edges": []
}
"@

Test-DagImport -TestName "Missing nodes array" -JsonInput $missingNodes -ShouldSucceed $false -ExpectedError "missing 'nodes'"

# Test 5: Node missing ID
$nodeMissingId = @"
{
  "nodes": [
    {
      "title": "No ID",
      "type": "Task",
      "body": "Description"
    }
  ],
  "edges": []
}
"@

Test-DagImport -TestName "Node missing ID" -JsonInput $nodeMissingId -ShouldSucceed $false -ExpectedError "missing 'id'"

# Test 6: Node missing title
$nodeMissingTitle = @"
{
  "nodes": [
    {
      "id": "task-1",
      "type": "Task",
      "body": "Description"
    }
  ],
  "edges": []
}
"@

Test-DagImport -TestName "Node missing title" -JsonInput $nodeMissingTitle -ShouldSucceed $false -ExpectedError "missing 'title'"

# Test 7: Node missing type
$nodeMissingType = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task",
      "body": "Description"
    }
  ],
  "edges": []
}
"@

Test-DagImport -TestName "Node missing type" -JsonInput $nodeMissingType -ShouldSucceed $false -ExpectedError "missing 'type'"

# Test 8: Duplicate node IDs
$duplicateIds = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task 1",
      "type": "Task",
      "body": "First"
    },
    {
      "id": "task-1",
      "title": "Task 2",
      "type": "Task",
      "body": "Duplicate"
    }
  ],
  "edges": []
}
"@

Test-DagImport -TestName "Duplicate node IDs" -JsonInput $duplicateIds -ShouldSucceed $false -ExpectedError "Duplicate node ID"

# Test 9: Edge referencing non-existent node
$invalidEdge = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task",
      "type": "Task",
      "body": "Description"
    }
  ],
  "edges": [
    {"from": "task-1", "to": "non-existent", "relationship": "tracks"}
  ]
}
"@

Test-DagImport -TestName "Edge with non-existent node" -JsonInput $invalidEdge -ShouldSucceed $false -ExpectedError "non-existent node"

# Test 10: DAG with cycle
$cyclicDag = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task 1",
      "type": "Task",
      "body": "First"
    },
    {
      "id": "task-2",
      "title": "Task 2",
      "type": "Task",
      "body": "Second"
    },
    {
      "id": "task-3",
      "title": "Task 3",
      "type": "Task",
      "body": "Third"
    }
  ],
  "edges": [
    {"from": "task-1", "to": "task-2", "relationship": "tracks"},
    {"from": "task-2", "to": "task-3", "relationship": "tracks"},
    {"from": "task-3", "to": "task-1", "relationship": "tracks"}
  ]
}
"@

Test-DagImport -TestName "Cyclic DAG detection" -JsonInput $cyclicDag -ShouldSucceed $false -ExpectedError "cycle"

# Test 11: Node with body as null/empty
$nodeEmptyBody = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task",
      "type": "Task"
    }
  ],
  "edges": []
}
"@

Test-DagImport -TestName "Node with missing body (should succeed)" -JsonInput $nodeEmptyBody -ShouldSucceed $true

# Test 12: Edge missing 'from' property
$edgeMissingFrom = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task",
      "type": "Task",
      "body": "Description"
    }
  ],
  "edges": [
    {"to": "task-1", "relationship": "tracks"}
  ]
}
"@

Test-DagImport -TestName "Edge missing 'from'" -JsonInput $edgeMissingFrom -ShouldSucceed $false -ExpectedError "missing 'from'"

# Test 13: Edge missing 'to' property
$edgeMissingTo = @"
{
  "nodes": [
    {
      "id": "task-1",
      "title": "Task",
      "type": "Task",
      "body": "Description"
    }
  ],
  "edges": [
    {"from": "task-1", "relationship": "tracks"}
  ]
}
"@

Test-DagImport -TestName "Edge missing 'to'" -JsonInput $edgeMissingTo -ShouldSucceed $false -ExpectedError "missing 'to'"

# Summary
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "✓ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some tests failed" -ForegroundColor Red
    exit 1
}
