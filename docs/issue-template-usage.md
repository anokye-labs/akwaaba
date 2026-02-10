# Issue Template Usage Guide

This guide provides examples of using the GitHub issue form templates with their validation features.

## Quick Reference

| Template | Purpose | Parent Reference | Key Validations |
|----------|---------|------------------|-----------------|
| **Epic** | Large initiative | None | Title, Phase, Description, Success Criteria |
| **Feature** | Cohesive functionality | Epic issue # | Title, Parent Epic (#N), Description, Tasks, Acceptance Criteria |
| **Task** | Specific work item | Feature issue # | Title, Parent Feature (#N), Description, Acceptance Criteria |
| **Bug** | Defect report | None | Title, Severity, Description, Steps, Expected/Actual Behavior |
| **Agent Request** | New agent approval | None | Name, Username, Type, Purpose, Operations, Security |

## Creating Issues

### 1. Epic

**When to use:**
- Starting a new phase or major initiative
- Work spans weeks or months
- Multiple features needed

**Example:**
```yaml
Title: Implement Comprehensive Testing Framework
Phase: Phase 6 - Validation & Polish
Description: Create a comprehensive testing framework for all repository scripts...
Success Criteria:
  - [ ] All scripts have test coverage
  - [ ] Automated tests run on PRs
  - [ ] Documentation updated
```

### 2. Feature

**When to use:**
- Implementing a cohesive feature within an epic
- Work can be completed in 1-2 weeks
- Multiple tasks required

**Example:**
```yaml
Title: Create Issue Templates
Parent Epic: #5 (or just "5")
Description: Build YAML issue templates for Epic, Feature, Task, Bug, and Agent Request...
Tasks:
  - [ ] Create epic.yml template
  - [ ] Create feature.yml template
  - [ ] Add validation rules
Acceptance Criteria:
  - [ ] All 5 templates created
  - [ ] Validation working
  - [ ] Tests passing
```

**Validation Examples:**

✅ **Valid Parent Epic entries:**
- `5`
- `#5`
- `123`
- `#123`

❌ **Invalid Parent Epic entries:**
- `Epic #5` (includes text)
- `#` (no number)
- `abc` (not a number)
- `#5 and #6` (multiple references)

### 3. Task

**When to use:**
- Specific, actionable work item
- Completable in hours to a few days
- Part of a feature

**Example:**
```yaml
Title: Add regex validation to epic template
Parent Feature: #25
Description: Add regex patterns to validate issue number references in the epic template...
Acceptance Criteria:
  - [ ] Regex patterns added
  - [ ] Validation messages clear
  - [ ] Tests pass
Effort: Small - Few hours
Assignee: copilot
```

**Validation Examples:**

✅ **Valid Assignee entries:**
- `copilot`
- `user123`
- `my-bot-name`
- `a` (single character)

❌ **Invalid Assignee entries:**
- `@copilot` (includes @ symbol)
- `-invalid` (starts with hyphen)
- `user name` (contains space)
- `user_name` (contains underscore)

### 4. Bug Report

**When to use:**
- Something is broken or not working as expected
- Reproducible defect
- Unexpected behavior

**Example:**
```yaml
Title: Template validation fails for valid issue numbers
Severity: High - Major functionality is broken
Description: When entering "#123" in the parent feature field, validation fails...
Steps to Reproduce:
  1. Go to New Issue
  2. Select Task template
  3. Enter "#123" in Parent Feature field
  4. See validation error
Expected Behavior: Should accept "#123" as valid issue reference
Actual Behavior: Shows error "Please enter a valid issue number"
```

**Severity Options:**
- **Critical** - System is unusable or data loss
- **High** - Major functionality is broken
- **Medium** - Feature doesn't work as expected
- **Low** - Minor issue or cosmetic problem

### 5. Agent Request

**When to use:**
- Need to add a new GitHub App
- Request AI agent access
- Set up automated bot

**Example:**
```yaml
Agent Name: Code Review Agent
Username: copilot
Bot Username: copilot[bot]
GitHub App ID: 12345
Agent Type: GitHub App - Automated application
Purpose: Provide automated code reviews on pull requests...
Operations:
  - Add review comments
  - Request changes
  - Approve PRs
Triggers:
  - PR opened
  - PR updated
  - Manual review request
Security Considerations:
  - Read-only access to code
  - No merge permissions
  - Rate limited to 10 reviews/hour
Maintainer: @team-leads
```

**Validation Examples:**

✅ **Valid Username:**
- `copilot`
- `github-actions`
- `my-bot-2024`

❌ **Invalid Username:**
- `@copilot` (@ not allowed)
- `copilot[bot]` (use Bot Username field instead)
- `-invalid` (can't start with hyphen)

✅ **Valid Bot Username:**
- `copilot[bot]`
- `github-actions[bot]`
- `my-app[bot]`

❌ **Invalid Bot Username:**
- `copilot` (missing [bot] suffix)
- `copilot-bot` (wrong format)
- `copilot[BOT]` (case sensitive)

✅ **Valid GitHub App ID:**
- `12345`
- `999999`
- `1`

❌ **Invalid GitHub App ID:**
- `abc` (not a number)
- `#12345` (no # symbol)
- `12.34` (no decimals)

## Common Validation Errors

### Issue Number Validation

**Error:** "Please enter a valid issue number (e.g., #25 or 25)"

**Causes:**
- Including text before/after the number
- Using letters instead of numbers
- Leaving the field empty (if required)

**Fix:**
- Use just the number: `25`
- Or with hash: `#25`
- No spaces or other characters

### Username Validation

**Error:** "Please enter a valid GitHub username (3-39 characters, alphanumeric and hyphens)"

**Causes:**
- Including @ symbol
- Using underscores or dots
- Starting/ending with hyphen
- Too long (>39 characters)

**Fix:**
- Use only letters, numbers, and hyphens
- Don't include @ symbol
- Keep under 40 characters
- Can't start or end with hyphen

### Bot Username Validation

**Error:** "Bot username must end with [bot] (e.g., my-app[bot])"

**Causes:**
- Missing [bot] suffix
- Wrong format like `-bot` or `_bot`
- Case mismatch (must be lowercase [bot])

**Fix:**
- Always end with `[bot]`
- Example: `copilot[bot]`
- Case sensitive: must be `[bot]` not `[BOT]`

### App ID Validation

**Error:** "GitHub App ID must be a number"

**Causes:**
- Including letters or symbols
- Using # prefix
- Including spaces or special characters

**Fix:**
- Use only numeric digits
- Example: `12345`
- No prefixes or suffixes

## Tips for Success

1. **Read the Template Instructions**
   - Each template has a markdown header with guidance
   - Follow the "Before creating" checklist

2. **Use Placeholder Examples**
   - Placeholders show the expected format
   - Follow the examples provided

3. **Fill Required Fields First**
   - Required fields are marked with asterisks (*)
   - You can't submit until all required fields are complete

4. **Check Validation Messages**
   - If you see a red error, read the message carefully
   - The message tells you exactly what's wrong

5. **Copy Issue Numbers Correctly**
   - You can copy issue numbers from the URL
   - Both `#25` and `25` work for parent references

6. **Use Dropdowns When Available**
   - Dropdowns ensure consistent values
   - Phases, priorities, severities, and effort are predefined

## Need Help?

If you're having trouble with templates:

1. **Check the Documentation**
   - [Template Validation Guide](./issue-template-validation.md)
   - [How We Work](../how-we-work.md)
   - [Contributing Guide](../CONTRIBUTING.md)

2. **Ask in Discussions**
   - Go to GitHub Discussions
   - Search for similar questions
   - Ask for clarification

3. **Report Template Bugs**
   - If validation is broken, file a Bug issue
   - Include the exact error message
   - Describe what you entered

## Testing Your Changes

After templates are merged, you can test them:

1. Go to repository Issues tab
2. Click "New Issue"
3. Select a template
4. Try:
   - Leaving required fields empty (should block submission)
   - Entering invalid formats (should show error)
   - Entering valid data (should work)

The templates will render with:
- Clear field labels
- Helpful descriptions
- Placeholder text
- Validation messages
- Required field indicators

## Future Improvements

Potential enhancements being considered:

- Email validation for contact fields
- URL validation for links
- Date format validation
- Custom validation for specific fields
- Conditional fields based on selections
- Auto-assignment based on template type

## Feedback Welcome

We're always improving our templates. If you have suggestions:

- Open a discussion to propose changes
- File an issue to report problems
- Submit a PR with improvements
- Share your experience in team meetings

Remember: Templates are designed to help you provide complete information efficiently. The validation ensures consistency and quality across all issues!
