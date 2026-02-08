# Examples for New-IssueHierarchy.ps1

# Example 1: Simple Epic with direct Tasks (no Features)
$simpleHierarchy = @{
    Type = "Epic"
    Title = "Phase 0: Project Setup"
    Body = "Initial project setup and configuration"
    Children = @(
        @{
            Type = "Task"
            Title = "Initialize repository"
            Body = "Create repo structure and initial files"
        }
        @{
            Type = "Task"
            Title = "Setup CI/CD pipeline"
            Body = "Configure GitHub Actions workflows"
        }
        @{
            Type = "Task"
            Title = "Write documentation"
            Body = "Create README and contributing guidelines"
        }
    )
}

# Create the hierarchy
$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $simpleHierarchy

Write-Host "Created Epic #$($result.Root.Number): $($result.Root.Url)"
Write-Host "Total issues created: $($result.AllIssues.Count)"

# Example 2: Epic with Features and Tasks (3-level hierarchy)
$complexHierarchy = @{
    Type = "Epic"
    Title = "Phase 2: Core Features"
    Body = "Implement core application features"
    Children = @(
        @{
            Type = "Feature"
            Title = "User Authentication"
            Body = "Complete user authentication system"
            Children = @(
                @{ Type = "Task"; Title = "Design authentication flow" }
                @{ Type = "Task"; Title = "Implement login/logout" }
                @{ Type = "Task"; Title = "Add OAuth providers" }
                @{ Type = "Task"; Title = "Write auth tests" }
            )
        }
        @{
            Type = "Feature"
            Title = "Data Management"
            Body = "Data storage and retrieval system"
            Children = @(
                @{ Type = "Task"; Title = "Design database schema" }
                @{ Type = "Task"; Title = "Implement CRUD operations" }
                @{ Type = "Task"; Title = "Add caching layer" }
            )
        }
    )
}

$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $complexHierarchy `
    -ProjectNumber 3

# Example 3: Creating from JSON file
$jsonContent = @"
{
    "Type": "Epic",
    "Title": "Phase 3: API Development",
    "Body": "Build RESTful API endpoints",
    "Children": [
        {
            "Type": "Feature",
            "Title": "Public API",
            "Body": "External facing API",
            "Children": [
                { "Type": "Task", "Title": "Define API spec (OpenAPI)" },
                { "Type": "Task", "Title": "Implement endpoints" },
                { "Type": "Task", "Title": "Add rate limiting" }
            ]
        },
        {
            "Type": "Feature",
            "Title": "API Documentation",
            "Body": "API docs and examples",
            "Children": [
                { "Type": "Task", "Title": "Generate API docs" },
                { "Type": "Task", "Title": "Write usage examples" }
            ]
        }
    ]
}
"@

# Save to file
$jsonContent | Out-File -FilePath "hierarchy.json" -Encoding UTF8

# Load and create from JSON
$hierarchy = Get-Content "hierarchy.json" | ConvertFrom-Json -AsHashtable

$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $hierarchy

# Clean up temporary file
Remove-Item "hierarchy.json"

# Example 4: DryRun mode (test without creating)
$testHierarchy = @{
    Type = "Epic"
    Title = "Test Epic"
    Body = "This is a test"
    Children = @(
        @{ Type = "Task"; Title = "Test Task 1" }
        @{ Type = "Task"; Title = "Test Task 2" }
    )
}

$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $testHierarchy `
    -DryRun `
    -Verbose

# Example 5: With correlation ID for tracing
$correlationId = [guid]::NewGuid().ToString()

$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $simpleHierarchy `
    -CorrelationId $correlationId

Write-Host "Operation completed with correlation ID: $($result.CorrelationId)"

# Example 6: Error handling
$result = ./New-IssueHierarchy.ps1 `
    -Owner "anokye-labs" `
    -Repo "akwaaba" `
    -HierarchyDefinition $complexHierarchy

if ($result.Success) {
    Write-Host "✓ Success! Created $($result.AllIssues.Count) issues" -ForegroundColor Green
    Write-Host "Root issue: #$($result.Root.Number) - $($result.Root.Url)"
    
    foreach ($issue in $result.AllIssues) {
        Write-Host "  #$($issue.Number) [$($issue.Type)] $($issue.Title)"
    }
} else {
    Write-Host "✗ Failed to create hierarchy" -ForegroundColor Red
    foreach ($error in $result.Errors) {
        Write-Host "  Error: $($error.Message)" -ForegroundColor Red
    }
}
