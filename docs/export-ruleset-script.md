# Export-Ruleset Script Documentation

## Overview

The `Export-Ruleset.ps1` script exports GitHub repository rulesets from the GitHub API to JSON files with comprehensive inline documentation. This is part of the repository governance tooling.

## Purpose

- **Export Configuration**: Capture the current state of repository rulesets
- **Documentation**: Add inline comments explaining each rule and parameter
- **Version Control**: Store ruleset configuration in the repository for tracking changes
- **Portability**: Export rulesets for reuse in other repositories

## Location

- **Script**: `scripts/Export-Ruleset.ps1`
- **Tests**: `scripts/Test-Export-Ruleset.ps1`
- **Output**: `.github/rulesets/` (default)
- **Documentation**: `.github/rulesets/README.md`

## Prerequisites

- PowerShell 7.x or higher
- GitHub CLI (`gh`) installed and authenticated, **OR**
- `GITHUB_TOKEN` environment variable set with a valid Personal Access Token
- Token requires `repo` scope for private repositories or `public_repo` for public repositories

## Usage

### Export All Rulesets

```powershell
./scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba"
```

This will:
1. Fetch all rulesets from the repository
2. Create JSON files in `.github/rulesets/`
3. Add inline comments explaining each rule
4. Include metadata (export command, API reference, timestamp)

### Export Specific Ruleset by ID

```powershell
./scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -RulesetId 12345
```

### Export to Custom Directory

```powershell
./scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -OutputPath "./my-rulesets"
```

### Use with Explicit Token

```powershell
./scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -Token "ghp_xxxxx"
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-Owner` | Yes | - | Repository owner (organization or user) |
| `-Repo` | Yes | - | Repository name |
| `-RulesetId` | No | - | Specific ruleset ID to export (exports all if omitted) |
| `-OutputPath` | No | `.github/rulesets` | Directory where JSON files will be saved |
| `-Token` | No | `$env:GITHUB_TOKEN` | GitHub Personal Access Token |

## Output Format

The script produces JSON files with:

### Naming Convention
- Based on ruleset name
- Spaces converted to hyphens
- Special characters removed
- Converted to lowercase
- Example: "Main Branch Protection" → `main-branch-protection.json`

### File Structure

```json
{
  "_comment": "GitHub Repository Ruleset Configuration",
  "_description": "This file defines comprehensive branch protection rules for the main branch",
  "_export_command": "pwsh -File scripts/Export-Ruleset.ps1 -Owner anokye-labs -Repo akwaaba",
  "_api_reference": "https://docs.github.com/en/rest/repos/rules",
  "_last_exported": "2026-02-09T23:47:00Z",
  
  "name": "Main Branch Protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { ... },
  "rules": [ ... ]
}
```

### Inline Comments

The script adds explanatory comments throughout the JSON:
- `_comment` fields explaining sections
- `_*_comment` fields for specific parameters
- API references and documentation links
- Usage examples and best practices

## Example Output

See `.github/rulesets/main-branch-protection.json` for a complete example of exported ruleset with inline documentation.

## Testing

Run the test suite to validate the script:

```powershell
# Run all tests
Invoke-Pester ./scripts/Test-Export-Ruleset.ps1

# Run specific test context
Invoke-Pester ./scripts/Test-Export-Ruleset.ps1 -Tag "Unit"

# Run integration tests (requires GITHUB_TOKEN)
Invoke-Pester ./scripts/Test-Export-Ruleset.ps1 -Tag "Integration"
```

## Error Handling

The script handles common errors:

- **No Token Found**: Throws clear error message if no authentication is available
- **API Failures**: Catches and reports API errors with details
- **Invalid Ruleset ID**: Reports when a specific ruleset doesn't exist
- **Network Issues**: Handles connection failures gracefully

## Authentication Methods

### Method 1: GitHub CLI (Recommended)

If you have `gh` CLI installed and authenticated:

```bash
gh auth login
```

The script will automatically use `gh` credentials.

### Method 2: Environment Variable

Set the `GITHUB_TOKEN` environment variable:

```powershell
# PowerShell
$env:GITHUB_TOKEN = "ghp_your_token_here"
./scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba"
```

```bash
# Bash
export GITHUB_TOKEN="ghp_your_token_here"
pwsh -File scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba"
```

### Method 3: Parameter

Pass token directly as parameter:

```powershell
./scripts/Export-Ruleset.ps1 -Owner "anokye-labs" -Repo "akwaaba" -Token "ghp_your_token_here"
```

## API Reference

The script uses the GitHub Repository Rulesets API:

- **List Rulesets**: `GET /repos/{owner}/{repo}/rulesets`
- **Get Ruleset**: `GET /repos/{owner}/{repo}/rulesets/{ruleset_id}`
- **Documentation**: https://docs.github.com/en/rest/repos/rules

## Related Documentation

- [.github/rulesets/README.md](.github/rulesets/README.md) - Comprehensive ruleset documentation
- [.github/rulesets/main-branch-protection.json](.github/rulesets/main-branch-protection.json) - Example exported ruleset
- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [Repository Rules API](https://docs.github.com/en/rest/repos/rules)

## Workflow Integration

This script is part of the repository governance workflow:

1. **Configure Rulesets**: Set up branch protection via GitHub UI
2. **Export Configuration**: Use this script to export rulesets
3. **Version Control**: Commit exported JSON to repository
4. **Documentation**: Inline comments provide context
5. **Reuse**: Apply same rules to other repositories

## Best Practices

1. **Regular Exports**: Export rulesets whenever they change
2. **Review Changes**: Use git diff to review ruleset changes
3. **Document Intent**: Ensure comments explain *why* rules exist
4. **Test First**: Use "evaluate" mode before "active" enforcement
5. **Backup**: Keep exports before making major changes

## Troubleshooting

### "No GitHub token found"

**Solution**: Set `GITHUB_TOKEN` environment variable or authenticate with `gh auth login`

### "Failed to call GitHub API"

**Possible causes**:
- Invalid token
- Token lacks required scopes
- Repository doesn't exist
- Network connectivity issues

**Solution**: Verify token has `repo` scope and repository exists

### "No rulesets found"

**Solution**: Verify the repository has rulesets configured via Settings → Rules → Rulesets

## Contributing

When modifying the export script:

1. Update documentation in this file
2. Add tests to `Test-Export-Ruleset.ps1`
3. Ensure inline comments are helpful
4. Follow existing code style
5. Test with both authentication methods

## See Also

- `scripts/README.md` - Complete script documentation
- Planning document: `planning/phase-2-governance/01-ruleset-protect-main.md`
- GitHub Actions workflows that enforce these rules
