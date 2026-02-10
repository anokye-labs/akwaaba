# Commit Validation Audit Log Example

This directory contains audit logs for all commit validation attempts.

## Log Format

Each log entry is a single line of JSON with the following structure:

```json
{
  "timestamp": "2026-02-10T00:39:47.372Z",
  "commitSha": "abc123def456",
  "commitAuthor": "developer@example.com",
  "commitMessage": "fix: update readme #123",
  "prNumber": 42,
  "validationResult": "Pass",
  "validationMessage": "Issue references: 123",
  "correlationId": "c49d795a-649f-4689-b000-87c65eb225e8"
}
```

## Fields

- **timestamp**: ISO 8601 UTC timestamp of the validation attempt
- **commitSha**: Full SHA of the commit being validated
- **commitAuthor**: Email address of the commit author
- **commitMessage**: The commit message headline
- **prNumber**: Pull request number (if applicable)
- **validationResult**: One of: `Pass`, `Fail`, `Skip`
- **validationMessage**: Additional details about the validation result
- **correlationId**: GUID for tracing related operations

## Log Files

Log files are named by date: `YYYY-MM-DD-validation.log`

Each log file contains one JSON object per line, making it easy to:
- Parse with `jq` or other JSON tools
- Import into log analysis systems
- Query with standard text tools

## Usage Examples

### Count validation attempts by date
```bash
ls -1 logs/commit-validation/*.log | wc -l
```

### View all failures for a specific PR
```bash
jq -r 'select(.prNumber == 42 and .validationResult == "Fail")' logs/commit-validation/*.log
```

### Analyze validation patterns
```bash
jq -r '.validationResult' logs/commit-validation/*.log | sort | uniq -c
```

### Find all commits by a specific author
```bash
jq -r 'select(.commitAuthor == "developer@example.com")' logs/commit-validation/*.log
```
