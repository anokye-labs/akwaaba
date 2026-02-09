# Update-AutoApproveConfig.ps1

Agentic interface for editing auto-approve rules configuration.

## Overview

`Update-AutoApproveConfig.ps1` provides a structured interface for managing the auto-approve rules configuration file at `.github/okyerema/auto-approve.json`. This script is designed for agent consumption with structured input/output and supports both JSON (for automation) and Console (for human interaction) output formats.

## Features

- **List**: View all auto-approve rules
- **Get**: Retrieve details for a specific rule
- **Add**: Create a new auto-approve rule
- **Update**: Modify an existing rule
- **Remove**: Delete a rule by ID
- **Schema Validation**: Validates configuration before writing
- **DryRun Mode**: Preview changes without saving
- **Dual Output Formats**: JSON (for agents) and Console (for humans)

## Configuration Schema

The auto-approve configuration file has the following structure:

```json
{
  "version": "1.0",
  "rules": [
    {
      "id": "unique-rule-id",
      "name": "Human-readable name",
      "enabled": true,
      "conditions": {
        "author": "copilot",
        "filesChanged": {
          "patterns": ["docs/**", "*.md"],
          "maxCount": 10
        },
        "excludePatterns": ["CHANGELOG.md"]
      },
      "checks": {
        "requireCI": true,
        "requireReviews": 0,
        "noConflicts": true
      },
      "description": "Optional description of the rule"
    }
  ]
}
```

### Rule Fields

- **id** (required): Unique identifier for the rule
- **name** (required): Display name for the rule
- **enabled** (required): Boolean indicating if the rule is active
- **conditions** (required): Conditions that must be met for auto-approval
  - **author**: GitHub username to match
  - **filesChanged**: File pattern matching criteria
    - **patterns**: Array of glob patterns to match
    - **maxCount**: Maximum number of files that can be changed
  - **excludePatterns**: Array of patterns to exclude
- **checks** (optional): Additional checks before auto-approval
  - **requireCI**: Whether CI must pass
  - **requireReviews**: Minimum number of reviews required
  - **noConflicts**: Whether the PR must have no merge conflicts
- **description** (optional): Human-readable description

## Usage Examples

### List All Rules

```powershell
# JSON output (for agents)
./Update-AutoApproveConfig.ps1 -Operation List -OutputFormat Json

# Console output (for humans)
./Update-AutoApproveConfig.ps1 -Operation List -OutputFormat Console
```

### Get a Specific Rule

```powershell
./Update-AutoApproveConfig.ps1 -Operation Get -RuleId "agent-docs-only" -OutputFormat Console
```

### Add a New Rule

```powershell
# Define conditions as JSON string
$conditions = '{"author":"copilot","filesChanged":{"patterns":["*.md"],"maxCount":5}}'
$checks = '{"requireCI":true,"requireReviews":0,"noConflicts":true}'

./Update-AutoApproveConfig.ps1 `
    -Operation Add `
    -RuleId "new-rule-id" `
    -RuleName "Documentation Only" `
    -RuleConditions $conditions `
    -RuleChecks $checks `
    -RuleDescription "Auto-approve doc changes" `
    -OutputFormat Json
```

### Update an Existing Rule

```powershell
# Disable a rule
./Update-AutoApproveConfig.ps1 `
    -Operation Update `
    -RuleId "agent-docs-only" `
    -RuleEnabled:$false `
    -OutputFormat Console

# Update rule conditions
$newConditions = '{"author":"bot","filesChanged":{"patterns":["tests/**"],"maxCount":10}}'
./Update-AutoApproveConfig.ps1 `
    -Operation Update `
    -RuleId "agent-tests-only" `
    -RuleConditions $newConditions `
    -OutputFormat Json
```

### Remove a Rule

```powershell
./Update-AutoApproveConfig.ps1 `
    -Operation Remove `
    -RuleId "obsolete-rule" `
    -OutputFormat Console
```

### DryRun Mode (Preview Changes)

```powershell
# Preview adding a rule without saving
./Update-AutoApproveConfig.ps1 `
    -Operation Add `
    -RuleId "test-rule" `
    -RuleName "Test" `
    -RuleConditions '{"author":"test"}' `
    -DryRun `
    -OutputFormat Console
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `Operation` | String | Yes | Operation to perform: `List`, `Get`, `Add`, `Update`, `Remove` |
| `RuleId` | String | Conditional | Rule ID (required for Get, Update, Remove, Add) |
| `RuleName` | String | Conditional | Rule name (required for Add, optional for Update) |
| `RuleEnabled` | Nullable[Boolean] | No | Enable/disable rule (Add/Update). For Add: defaults to `$true` if not provided. For Update: only changes if explicitly provided. |
| `RuleDescription` | String | No | Rule description (Add/Update) |
| `RuleConditions` | Object/JSON | Conditional | Rule conditions (required for Add, optional for Update) |
| `RuleChecks` | Object/JSON | No | Rule checks (Add/Update) |
| `DryRun` | Switch | No | Preview changes without saving |
| `OutputFormat` | String | No | Output format: `Json` (default), `Console` |
| `ConfigPath` | String | No | Custom config file path (defaults to `.github/okyerema/auto-approve.json`) |

## Output Format

### JSON Output

Returns a structured JSON object:

```json
{
  "Success": true,
  "Operation": "Add",
  "Message": "Rule added successfully",
  "Rules": { /* rule object */ },
  "Changes": "Added rule 'new-rule-id' with name 'New Rule'",
  "ConfigPath": "/path/to/auto-approve.json",
  "DryRun": false
}
```

### Console Output

Displays human-readable formatted output with colors:

```
═══════════════════════════════════════════════════════
  Auto-Approve Config: List
═══════════════════════════════════════════════════════

  Status: Success ✓
  Message: Retrieved 2 rules

  Rules (2):
    [✓] agent-docs-only
        Name: Auto-approve documentation-only changes
        Desc: Automatically approve PRs from agents...
    [✓] agent-tests-only
        Name: Auto-approve test-only changes
        Desc: Automatically approve PRs from agents...

  Config Path: /path/to/auto-approve.json

═══════════════════════════════════════════════════════
```

## Dependencies

- PowerShell 7.x or higher
- Access to the repository root directory
- Write permissions for the configuration file

## Error Handling

The script validates:
- Required parameters for each operation
- Configuration file existence and format
- JSON schema compliance
- Rule ID uniqueness (for Add operations)
- Rule existence (for Get, Update, Remove operations)

Errors are returned in the output with `Success: false` and a descriptive `Message`.

## Testing

Run the included test suite:

```powershell
./Test-Update-AutoApproveConfig.ps1
```

The test suite covers:
- All CRUD operations (Create, Read, Update, Delete)
- DryRun mode functionality
- Schema validation
- Error handling
- Both output formats

## Related Scripts

- **Test-PRAutoApprovable.ps1** (dependency) - Tests if a PR meets auto-approve criteria
- **Write-OkyeremaLog.ps1** - Logging utility used by the okyerema skill

## Notes

- The script is designed for agent consumption with structured JSON output
- DryRun mode is recommended when testing rule changes
- Schema validation ensures configuration integrity
- Configuration is stored at `.github/okyerema/auto-approve.json` by default
- Boolean parameters in PowerShell accept `$true`/`$false` or `1`/`0`
