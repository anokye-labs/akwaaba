# Scripts Directory

This directory contains PowerShell automation scripts for the Akwaaba repository.

## Available Scripts

### Get-RepoContext.ps1

Fetches repository context (repo ID, issue types, project IDs, and label IDs) in one query.

**Features:**
- One-shot query to fetch all repository metadata
- Returns PSCustomObject with `.RepoId`, `.IssueTypes`, `.ProjectId`, `.Labels`
- Session-based caching for efficient reuse
- `-Refresh` switch to force re-fetch

**Prerequisites:**
- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated

**Usage:**

```powershell
# Fetch repository context (cached after first call)
$context = ./scripts/Get-RepoContext.ps1

# Access the data
Write-Host "Repository ID: $($context.RepoId)"
Write-Host "Number of labels: $($context.Labels.Count)"
Write-Host "Number of projects: $($context.ProjectId.Count)"

# Force refresh the cache
$context = ./scripts/Get-RepoContext.ps1 -Refresh

# Use with verbose output
$context = ./scripts/Get-RepoContext.ps1 -Verbose
```

**Output Structure:**

```powershell
@{
    RepoId = "R_kgDO..." # Repository ID
    IssueTypes = @(      # Organization issue types (if available)
        @{
            Id = "..."
            Name = "Bug"
            FieldName = "Issue Type"
        }
    )
    ProjectId = @(       # Repository projects
        @{
            Id = "PVT_..."
            Number = 1
            Title = "Project Name"
            Url = "https://..."
        }
    )
    Labels = @(          # Repository labels
        @{
            Id = "LA_..."
            Name = "bug"
            Color = "d73a4a"
            Description = "Something isn't working"
        }
    )
}
```

**Notes:**
- The script caches results in the current PowerShell session
- Use `-Refresh` to bypass the cache and fetch fresh data
- Requires GitHub CLI authentication: `gh auth login`
