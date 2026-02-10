# Issue Template Validation

This document describes the validation features added to the GitHub issue form templates.

## Overview

All issue templates (Epic, Feature, Task, Bug, Agent Request) now include comprehensive validation to ensure high-quality issue creation with structured, consistent data.

## Validation Features

### 1. Required Fields

All critical fields are marked with `validations: required: true`:

- **Epic**: Title, Phase, Description, Success Criteria
- **Feature**: Title, Parent Epic, Description, Tasks, Acceptance Criteria
- **Task**: Title, Parent Feature, Description, Acceptance Criteria
- **Bug**: Title, Severity, Description, Steps to Reproduce, Expected Behavior, Actual Behavior
- **Agent Request**: Agent Name, Username, Agent Type, Purpose, Operations, Triggers, Security Considerations, Maintainer, Maintenance Plan

### 2. Regex Pattern Validation

Input fields with specific format requirements use regex validation:

#### Parent Issue References (Feature & Task)
- **Pattern**: `^#?\d+$`
- **Validates**: Issue numbers with or without # prefix
- **Examples**: `#25`, `25`
- **Error Message**: "Please enter a valid issue number (e.g., #25 or 25)"

#### GitHub Usernames (Task & Agent Request)
- **Pattern**: `^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?$`
- **Validates**: Valid GitHub username format (1-39 characters, alphanumeric and hyphens)
- **Examples**: `copilot`, `my-bot-name`, `a`
- **Error Message**: "Please enter a valid GitHub username (1-39 characters, alphanumeric and hyphens)"

#### Bot Usernames (Agent Request)
- **Pattern**: `^[a-zA-Z0-9]([a-zA-Z0-9-]{0,37}[a-zA-Z0-9])?\[bot\]$`
- **Validates**: GitHub bot username format with [bot] suffix
- **Examples**: `copilot[bot]`, `my-app[bot]`
- **Error Message**: "Bot username must end with [bot] (e.g., my-app[bot])"

#### GitHub App ID (Agent Request)
- **Pattern**: `^\d+$`
- **Validates**: Numeric App ID
- **Examples**: `12345`, `67890`
- **Error Message**: "GitHub App ID must be a number"

### 3. Placeholder Text with Examples

Every field includes helpful placeholder text showing:
- The expected format
- Concrete examples
- Guidelines for what to include

**Examples**:

```yaml
# Epic Description
placeholder: |
  Provide a comprehensive overview including:
  - What problem does this epic solve?
  - What are the main goals and objectives?
  - What value does it deliver to the project?
  - What is the scope (what's included/excluded)?

# Bug Steps to Reproduce
placeholder: |
  Please provide step-by-step instructions:
  1. Go to '...'
  2. Click on '...'
  3. Enter '...'
  4. See error
```

### 4. Helpful Validation Messages

All regex patterns include custom error messages via `patternError` that:
- Clearly explain what went wrong
- Show the expected format
- Provide examples of valid input

### 5. Dropdown Menus

Pre-defined options for consistent categorization:

- **Epic**: Project phases (Phase 1-7)
- **Feature**: Priority levels (Critical, High, Medium, Low)
- **Task**: Effort estimation (Small, Medium, Large)
- **Bug**: Severity levels (Critical, High, Medium, Low)
- **Agent Request**: Agent types (GitHub App, AI Agent, Bot, Service Account)

### 6. Markdown Instructions

Each template includes:
- Header explaining the template purpose
- "Before creating" checklist
- Guidelines for proper usage
- Links to relevant documentation

### 7. Checkbox Groups

**Agent Request** includes a comprehensive permissions checklist for clear declaration of required access levels.

## Template Configuration

### config.yml

The `config.yml` file:
- Disables blank issues (`blank_issues_enabled: false`)
- Provides helpful contact links:
  - Documentation
  - Discussions
  - Project Board
  - How We Work guide

This ensures users always use structured templates and have access to help resources.

## Benefits

1. **Data Quality**: Required fields and validation ensure complete, properly formatted information
2. **User Guidance**: Placeholders and examples help users provide the right information
3. **Consistency**: Standardized formats across all issues
4. **Error Prevention**: Early validation prevents common mistakes
5. **Discoverability**: Clear instructions help new contributors understand expectations
6. **Automation-Friendly**: Structured data enables better automation and tooling

## Testing

To test the templates:

1. Navigate to the repository on GitHub
2. Click "Issues" → "New Issue"
3. Select a template
4. Try submitting with:
   - Missing required fields (should fail)
   - Invalid formats (should show error messages)
   - Valid data (should succeed)

## Future Enhancements

Potential improvements for consideration:

- Add more regex patterns for URLs, email addresses, or other common formats
- Include default assignees or labels based on template type
- Add issue type assignment automation (Epic, Feature, Task, Bug)
- Create template for Documentation or Enhancement requests
- Add conditional fields based on dropdown selections

## References

- [GitHub Docs: Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
- [GitHub Docs: Syntax for form schema](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-githubs-form-schema)
- [Planning Document: Issue Templates](../planning/phase-2-governance/04-issue-templates.md)
