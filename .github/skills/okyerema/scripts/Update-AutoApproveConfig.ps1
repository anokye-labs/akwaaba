<#
.SYNOPSIS
    Agentic interface for editing auto-approve rules configuration.

.DESCRIPTION
    Update-AutoApproveConfig.ps1 provides a structured interface for managing the
    auto-approve rules configuration file at .github/okyerema/auto-approve.json.
    
    The script supports:
    - Reading current configuration
    - Adding new rules
    - Removing existing rules by ID
    - Updating existing rules
    - Listing all rules
    - Schema validation before writing
    - DryRun mode to preview changes without saving
    - Structured JSON output for agent consumption

.PARAMETER Operation
    The operation to perform. Valid values: List, Add, Remove, Update, Get

.PARAMETER RuleId
    The ID of the rule to operate on (required for Remove, Update, Get operations).

.PARAMETER RuleName
    The display name for the rule (required for Add, optional for Update).

.PARAMETER RuleEnabled
    Whether the rule is enabled (optional for Add/Update, defaults to $true).

.PARAMETER RuleDescription
    Description of what the rule does (optional for Add/Update).

.PARAMETER RuleConditions
    JSON string or hashtable containing rule conditions (required for Add, optional for Update).
    Example: '{"author":"copilot","filesChanged":{"patterns":["*.md"],"maxCount":5}}'

.PARAMETER RuleChecks
    JSON string or hashtable containing rule checks (optional for Add/Update).
    Example: '{"requireCI":true,"requireReviews":0,"noConflicts":true}'

.PARAMETER DryRun
    If specified, shows what would be changed without actually writing the file.

.PARAMETER OutputFormat
    Output format for results. Valid values: Console, Json. Default is Json for agent consumption.

.PARAMETER ConfigPath
    Path to the auto-approve configuration file. Defaults to .github/okyerema/auto-approve.json
    relative to repository root.

.EXAMPLE
    .\Update-AutoApproveConfig.ps1 -Operation List
    Lists all auto-approve rules in the configuration.

.EXAMPLE
    .\Update-AutoApproveConfig.ps1 -Operation Get -RuleId "agent-docs-only"
    Gets details for a specific rule.

.EXAMPLE
    .\Update-AutoApproveConfig.ps1 -Operation Add -RuleId "new-rule" -RuleName "New Rule" `
        -RuleConditions '{"author":"copilot"}' -DryRun
    Previews adding a new rule without saving.

.EXAMPLE
    .\Update-AutoApproveConfig.ps1 -Operation Remove -RuleId "agent-tests-only" -DryRun
    Previews removing a rule without saving.

.EXAMPLE
    .\Update-AutoApproveConfig.ps1 -Operation Update -RuleId "agent-docs-only" `
        -RuleEnabled $false -OutputFormat Console
    Disables a rule and displays results in console format.

.OUTPUTS
    Returns a PSCustomObject with:
    - Success: Boolean indicating if operation succeeded
    - Operation: The operation performed
    - Message: Human-readable status message
    - Rules: Array of rules (for List operation) or affected rule (for other operations)
    - Changes: Description of changes made (for Add/Update/Remove with DryRun)
    - ConfigPath: Path to configuration file
    - DryRun: Whether this was a dry run

.NOTES
    Author: Anokye Labs
    Dependencies: anokye-labs/akwaaba#31 (Test-PRAutoApprovable.ps1)
    
    The configuration file schema:
    {
      "version": "1.0",
      "rules": [
        {
          "id": "rule-id",
          "name": "Display Name",
          "enabled": true,
          "conditions": { ... },
          "checks": { ... },
          "description": "..."
        }
      ]
    }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet("List", "Add", "Remove", "Update", "Get")]
    [string]$Operation,

    [Parameter(Mandatory = $false)]
    [string]$RuleId,

    [Parameter(Mandatory = $false)]
    [string]$RuleName,

    [Parameter(Mandatory = $false)]
    [bool]$RuleEnabled,

    [Parameter(Mandatory = $false)]
    [string]$RuleDescription,

    [Parameter(Mandatory = $false)]
    [object]$RuleConditions,

    [Parameter(Mandatory = $false)]
    [object]$RuleChecks,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "Json")]
    [string]$OutputFormat = "Json",

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

$ErrorActionPreference = "Stop"

# Capture script root at script level for use in functions
$script:ScriptRoot = $PSScriptRoot

#region Helper Functions

function Get-ConfigFilePath {
    if ($ConfigPath) {
        return $ConfigPath
    }
    
    # Try to find repository root
    try {
        $repoRoot = git rev-parse --show-toplevel 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Not in a git repository"
        }
    }
    catch {
        # Fallback: assume script is in .github/skills/okyerema/scripts
        # Use script-level PSScriptRoot captured at script start
        $scriptDir = $script:ScriptRoot
        if (-not $scriptDir) {
            throw "Unable to determine script location or repository root. Please specify -ConfigPath parameter."
        }
        $repoRoot = Resolve-Path "$scriptDir/../../../.."
    }
    
    return Join-Path $repoRoot ".github/okyerema/auto-approve.json"
}

function Read-ConfigFile {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        throw "Configuration file not found: $Path"
    }
    
    try {
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        return $content
    }
    catch {
        throw "Failed to parse configuration file: $_"
    }
}

function Write-ConfigFile {
    param(
        [string]$Path,
        [object]$Config
    )
    
    try {
        $json = $Config | ConvertTo-Json -Depth 10
        Set-Content -Path $Path -Value $json -Encoding UTF8
    }
    catch {
        throw "Failed to write configuration file: $_"
    }
}

function Test-ConfigSchema {
    param([object]$Config)
    
    $errors = @()
    
    # Check required fields
    if (-not $Config.PSObject.Properties['version']) {
        $errors += "Missing required field: version"
    }
    
    if (-not $Config.PSObject.Properties['rules']) {
        $errors += "Missing required field: rules"
    }
    elseif (-not ($Config.rules -is [System.Array] -or $Config.rules -is [System.Collections.IList] -or $null -ne $Config.rules.Count)) {
        $errors += "Field 'rules' must be an array"
    }
    
    # Validate each rule
    foreach ($rule in $Config.rules) {
        if (-not $rule.PSObject.Properties['id']) {
            $errors += "Rule missing required field: id"
        }
        if (-not $rule.PSObject.Properties['name']) {
            $errors += "Rule '$($rule.id)' missing required field: name"
        }
        if (-not $rule.PSObject.Properties['enabled']) {
            $errors += "Rule '$($rule.id)' missing required field: enabled"
        }
        if (-not $rule.PSObject.Properties['conditions']) {
            $errors += "Rule '$($rule.id)' missing required field: conditions"
        }
    }
    
    return @{
        Valid = ($errors.Count -eq 0)
        Errors = $errors
    }
}

function Convert-ToHashtable {
    param([object]$InputObject)
    
    if ($InputObject -is [string]) {
        try {
            $InputObject = $InputObject | ConvertFrom-Json
        }
        catch {
            throw "Failed to parse JSON string: $_"
        }
    }
    
    if ($InputObject -is [hashtable]) {
        return $InputObject
    }
    
    if ($InputObject -is [PSCustomObject]) {
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = $property.Value
        }
        return $hash
    }
    
    return $InputObject
}

function New-Result {
    param(
        [bool]$Success,
        [string]$Operation,
        [string]$Message,
        [object]$Rules,
        [string]$Changes,
        [string]$ConfigPath,
        [bool]$DryRun
    )
    
    return [PSCustomObject]@{
        Success = $Success
        Operation = $Operation
        Message = $Message
        Rules = $Rules
        Changes = $Changes
        ConfigPath = $ConfigPath
        DryRun = $DryRun
    }
}

function Format-Output {
    param(
        [object]$Result,
        [string]$Format
    )
    
    if ($Format -eq "Json") {
        # For JSON format, just write the JSON to stdout
        Write-Output ($Result | ConvertTo-Json -Depth 10)
        return
    }
    
    # Console format
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Auto-Approve Config: $($Result.Operation)" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($Result.DryRun) {
        Write-Host "  [DRY RUN - No changes will be saved]" -ForegroundColor Yellow
        Write-Host ""
    }
    
    Write-Host "  Status: " -NoNewline
    if ($Result.Success) {
        Write-Host "Success ✓" -ForegroundColor Green
    }
    else {
        Write-Host "Failed ✗" -ForegroundColor Red
    }
    Write-Host "  Message: $($Result.Message)" -ForegroundColor Gray
    Write-Host ""
    
    if ($Result.Changes) {
        Write-Host "  Changes:" -ForegroundColor Yellow
        Write-Host "  $($Result.Changes)" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($Result.Rules) {
        if ($Result.Rules -is [Array]) {
            Write-Host "  Rules ($($Result.Rules.Count)):" -ForegroundColor Yellow
            foreach ($rule in $Result.Rules) {
                $status = if ($rule.enabled) { "✓" } else { "✗" }
                Write-Host "    [$status] $($rule.id)" -ForegroundColor $(if ($rule.enabled) { "Green" } else { "DarkGray" })
                Write-Host "        Name: $($rule.name)" -ForegroundColor Gray
                if ($rule.description) {
                    Write-Host "        Desc: $($rule.description)" -ForegroundColor DarkGray
                }
            }
        }
        else {
            Write-Host "  Rule:" -ForegroundColor Yellow
            Write-Host "    ID: $($Result.Rules.id)" -ForegroundColor Gray
            Write-Host "    Name: $($Result.Rules.name)" -ForegroundColor Gray
            Write-Host "    Enabled: $($Result.Rules.enabled)" -ForegroundColor Gray
            if ($Result.Rules.description) {
                Write-Host "    Description: $($Result.Rules.description)" -ForegroundColor Gray
            }
            Write-Host "    Conditions: $($Result.Rules.conditions | ConvertTo-Json -Depth 5 -Compress)" -ForegroundColor DarkGray
            if ($Result.Rules.checks) {
                Write-Host "    Checks: $($Result.Rules.checks | ConvertTo-Json -Depth 5 -Compress)" -ForegroundColor DarkGray
            }
        }
    }
    
    Write-Host ""
    Write-Host "  Config Path: $($Result.ConfigPath)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Main Operations

try {
    $configPath = Get-ConfigFilePath
    
    # Validate operation-specific parameters
    if ($Operation -in @("Remove", "Update", "Get") -and -not $RuleId) {
        throw "RuleId is required for $Operation operation"
    }
    
    if ($Operation -eq "Add" -and -not $RuleId) {
        throw "RuleId is required for Add operation"
    }
    
    if ($Operation -eq "Add" -and -not $RuleName) {
        throw "RuleName is required for Add operation"
    }
    
    if ($Operation -eq "Add" -and -not $RuleConditions) {
        throw "RuleConditions is required for Add operation"
    }
    
    # Read current configuration
    $config = Read-ConfigFile -Path $configPath
    
    # Perform operation
    switch ($Operation) {
        "List" {
            $validation = Test-ConfigSchema -Config $config
            if (-not $validation.Valid) {
                $result = New-Result -Success $false -Operation $Operation `
                    -Message "Configuration validation failed: $($validation.Errors -join '; ')" `
                    -Rules $null -Changes $null -ConfigPath $configPath -DryRun $false
            }
            else {
                $result = New-Result -Success $true -Operation $Operation `
                    -Message "Retrieved $($config.rules.Count) rules" `
                    -Rules $config.rules -Changes $null -ConfigPath $configPath -DryRun $false
            }
        }
        
        "Get" {
            $rule = $config.rules | Where-Object { $_.id -eq $RuleId }
            if (-not $rule) {
                $result = New-Result -Success $false -Operation $Operation `
                    -Message "Rule not found: $RuleId" `
                    -Rules $null -Changes $null -ConfigPath $configPath -DryRun $false
            }
            else {
                $result = New-Result -Success $true -Operation $Operation `
                    -Message "Retrieved rule: $RuleId" `
                    -Rules $rule -Changes $null -ConfigPath $configPath -DryRun $false
            }
        }
        
        "Add" {
            # Check if rule already exists
            $existing = $config.rules | Where-Object { $_.id -eq $RuleId }
            if ($existing) {
                $result = New-Result -Success $false -Operation $Operation `
                    -Message "Rule already exists: $RuleId. Use Update operation to modify it." `
                    -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
            }
            else {
                # Build new rule as PSCustomObject
                $newRule = [PSCustomObject]@{
                    id = $RuleId
                    name = $RuleName
                    enabled = if ($PSBoundParameters.ContainsKey('RuleEnabled')) { $RuleEnabled } else { $true }
                    conditions = Convert-ToHashtable -InputObject $RuleConditions
                }
                
                if ($RuleDescription) {
                    $newRule | Add-Member -NotePropertyName "description" -NotePropertyValue $RuleDescription
                }
                
                if ($RuleChecks) {
                    $newRule | Add-Member -NotePropertyName "checks" -NotePropertyValue (Convert-ToHashtable -InputObject $RuleChecks)
                }
                
                # Add to config (convert rules to ArrayList if needed for proper adding)
                if ($config.rules -is [Array]) {
                    $rulesList = [System.Collections.ArrayList]@($config.rules)
                    $rulesList.Add($newRule) | Out-Null
                    $config.rules = $rulesList.ToArray()
                }
                else {
                    $config.rules = @($config.rules) + @($newRule)
                }
                
                # Validate
                $validation = Test-ConfigSchema -Config $config
                if (-not $validation.Valid) {
                    $result = New-Result -Success $false -Operation $Operation `
                        -Message "Validation failed: $($validation.Errors -join '; ')" `
                        -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
                }
                else {
                    # Write if not dry run
                    if (-not $DryRun) {
                        Write-ConfigFile -Path $configPath -Config $config
                    }
                    
                    $changes = "Added rule '$RuleId' with name '$RuleName'"
                    $result = New-Result -Success $true -Operation $Operation `
                        -Message "Rule added successfully" `
                        -Rules $newRule -Changes $changes -ConfigPath $configPath -DryRun $DryRun
                }
            }
        }
        
        "Remove" {
            $rule = $config.rules | Where-Object { $_.id -eq $RuleId }
            if (-not $rule) {
                $result = New-Result -Success $false -Operation $Operation `
                    -Message "Rule not found: $RuleId" `
                    -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
            }
            else {
                # Remove from config
                $config.rules = @($config.rules | Where-Object { $_.id -ne $RuleId })
                
                # Write if not dry run
                if (-not $DryRun) {
                    Write-ConfigFile -Path $configPath -Config $config
                }
                
                $changes = "Removed rule '$RuleId' ($($rule.name))"
                $result = New-Result -Success $true -Operation $Operation `
                    -Message "Rule removed successfully" `
                    -Rules $rule -Changes $changes -ConfigPath $configPath -DryRun $DryRun
            }
        }
        
        "Update" {
            $ruleIndex = -1
            for ($i = 0; $i -lt $config.rules.Count; $i++) {
                if ($config.rules[$i].id -eq $RuleId) {
                    $ruleIndex = $i
                    break
                }
            }
            
            if ($ruleIndex -eq -1) {
                $result = New-Result -Success $false -Operation $Operation `
                    -Message "Rule not found: $RuleId" `
                    -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
            }
            else {
                $rule = $config.rules[$ruleIndex]
                $changes = @()
                
                # Update fields if provided
                if ($PSBoundParameters.ContainsKey('RuleName')) {
                    $rule.name = $RuleName
                    $changes += "name"
                }
                
                if ($PSBoundParameters.ContainsKey('RuleEnabled')) {
                    $rule.enabled = $RuleEnabled
                    $changes += "enabled"
                }
                
                if ($PSBoundParameters.ContainsKey('RuleDescription')) {
                    $rule.description = $RuleDescription
                    $changes += "description"
                }
                
                if ($RuleConditions) {
                    $rule.conditions = Convert-ToHashtable -InputObject $RuleConditions
                    $changes += "conditions"
                }
                
                if ($RuleChecks) {
                    $rule.checks = Convert-ToHashtable -InputObject $RuleChecks
                    $changes += "checks"
                }
                
                if ($changes.Count -eq 0) {
                    $result = New-Result -Success $false -Operation $Operation `
                        -Message "No changes specified. Provide at least one field to update." `
                        -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
                }
                else {
                    $config.rules[$ruleIndex] = $rule
                    
                    # Validate
                    $validation = Test-ConfigSchema -Config $config
                    if (-not $validation.Valid) {
                        $result = New-Result -Success $false -Operation $Operation `
                            -Message "Validation failed: $($validation.Errors -join '; ')" `
                            -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
                    }
                    else {
                        # Write if not dry run
                        if (-not $DryRun) {
                            Write-ConfigFile -Path $configPath -Config $config
                        }
                        
                        $changesList = $changes -join ', '
                        $changesDesc = "Updated rule '$RuleId': changed $changesList"
                        $result = New-Result -Success $true -Operation $Operation `
                            -Message "Rule updated successfully" `
                            -Rules $rule -Changes $changesDesc -ConfigPath $configPath -DryRun $DryRun
                    }
                }
            }
        }
    }
    
    # Output result
    Format-Output -Result $result -Format $OutputFormat
}
catch {
    $result = New-Result -Success $false -Operation $Operation `
        -Message "Error: $_" `
        -Rules $null -Changes $null -ConfigPath $configPath -DryRun $DryRun
    
    Format-Output -Result $result -Format $OutputFormat
    
    throw
}

#endregion
