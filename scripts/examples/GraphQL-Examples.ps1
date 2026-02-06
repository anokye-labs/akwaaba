<#
.SYNOPSIS
    Examples demonstrating usage of Invoke-GraphQL.ps1

.DESCRIPTION
    This file contains various examples showing how to use the Invoke-GraphQL.ps1
    script for different GraphQL operations.
#>

# Import the script (adjust path as needed)
$scriptPath = Join-Path $PSScriptRoot ".." "Invoke-GraphQL.ps1"

Write-Host "=== Invoke-GraphQL.ps1 Usage Examples ===" -ForegroundColor Green
Write-Host ""

# Example 1: Simple query to get current user
Write-Host "Example 1: Get current viewer (user)" -ForegroundColor Cyan
$query1 = @"
query {
    viewer {
        login
        name
        email
        bio
    }
}
"@

Write-Host "Running query in DryRun mode first..." -ForegroundColor Yellow
& $scriptPath -Query $query1 -DryRun
Write-Host ""

# Uncomment to run actual query:
# $result1 = & $scriptPath -Query $query1
# if ($result1.Success) {
#     Write-Host "User: $($result1.Data.viewer.login)" -ForegroundColor Green
# }

# Example 2: Query with variables
Write-Host "Example 2: Get repository information with variables" -ForegroundColor Cyan
$query2 = @"
query(`$owner: String!, `$name: String!) {
    repository(owner: `$owner, name: `$name) {
        name
        description
        stargazerCount
        forkCount
        primaryLanguage {
            name
        }
    }
}
"@

$vars2 = @{
    owner = "github"
    name  = "docs"
}

Write-Host "Query: Repository info for github/docs" -ForegroundColor Yellow
& $scriptPath -Query $query2 -Variables $vars2 -DryRun
Write-Host ""

# Uncomment to run actual query:
# $result2 = & $scriptPath -Query $query2 -Variables $vars2
# if ($result2.Success) {
#     $repo = $result2.Data.repository
#     Write-Host "Repository: $($repo.name)" -ForegroundColor Green
#     Write-Host "Description: $($repo.description)" -ForegroundColor Green
#     Write-Host "Stars: $($repo.stargazerCount)" -ForegroundColor Green
# }

# Example 3: Query with error handling
Write-Host "Example 3: Handling errors properly" -ForegroundColor Cyan
$query3 = @"
query {
    repository(owner: "nonexistent", name: "repo") {
        name
    }
}
"@

Write-Host "This query would fail - showing how to handle errors:" -ForegroundColor Yellow
& $scriptPath -Query $query3 -DryRun
Write-Host ""

# Uncomment to demonstrate error handling:
# $result3 = & $scriptPath -Query $query3
# if (-not $result3.Success) {
#     Write-Host "Query failed!" -ForegroundColor Red
#     foreach ($error in $result3.Errors) {
#         Write-Host "  Error: $($error.Message)" -ForegroundColor Red
#         Write-Host "  Type: $($error.Type)" -ForegroundColor Red
#         Write-Host "  CorrelationId: $($error.CorrelationId)" -ForegroundColor Yellow
#     }
# }

# Example 4: Using custom correlation ID for tracing
Write-Host "Example 4: Using custom correlation ID" -ForegroundColor Cyan
$customCorrelationId = "TRACE-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
$query4 = @"
query {
    viewer {
        login
    }
}
"@

Write-Host "CorrelationId: $customCorrelationId" -ForegroundColor Yellow
& $scriptPath -Query $query4 -CorrelationId $customCorrelationId -DryRun
Write-Host ""

# Example 5: Verbose logging
Write-Host "Example 5: Verbose logging for debugging" -ForegroundColor Cyan
Write-Host "Running with -Verbose flag..." -ForegroundColor Yellow
& $scriptPath -Query $query4 -DryRun -Verbose
Write-Host ""

# Example 6: Custom retry settings
Write-Host "Example 6: Custom retry configuration" -ForegroundColor Cyan
Write-Host "Setting MaxRetries=5, InitialDelay=3s, MaxDelay=120s" -ForegroundColor Yellow
& $scriptPath -Query $query1 -MaxRetries 5 -InitialDelaySeconds 3 -MaxDelaySeconds 120 -DryRun
Write-Host ""

# Example 7: Listing issues in a repository
Write-Host "Example 7: List issues in a repository" -ForegroundColor Cyan
$query7 = @"
query(`$owner: String!, `$name: String!, `$count: Int!) {
    repository(owner: `$owner, name: `$name) {
        issues(first: `$count, states: OPEN) {
            nodes {
                number
                title
                state
                createdAt
            }
        }
    }
}
"@

$vars7 = @{
    owner = "github"
    name  = "docs"
    count = 5
}

Write-Host "Query: First 5 open issues from github/docs" -ForegroundColor Yellow
& $scriptPath -Query $query7 -Variables $vars7 -DryRun
Write-Host ""

# Uncomment to run actual query:
# $result7 = & $scriptPath -Query $query7 -Variables $vars7
# if ($result7.Success) {
#     Write-Host "Open Issues:" -ForegroundColor Green
#     foreach ($issue in $result7.Data.repository.issues.nodes) {
#         Write-Host "  #$($issue.number): $($issue.title)" -ForegroundColor White
#     }
# }

Write-Host "=== End of Examples ===" -ForegroundColor Green
Write-Host ""
Write-Host "To run actual queries, uncomment the execution blocks in this script." -ForegroundColor Yellow
Write-Host "Note: You need to be authenticated with 'gh auth login' first." -ForegroundColor Yellow
