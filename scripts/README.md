# Scripts Directory

This directory contains PowerShell utility scripts for the Akwaaba project.

## ConvertTo-EscapedGraphQL.ps1

A utility function that safely escapes text for use in GraphQL string literals. Addresses escaping bugs identified in PR #6 review comments.

### Features

- ✅ Handles newlines (converts to `\n`)
- ✅ Escapes double quotes (converts to `\"`)
- ✅ Escapes backslashes (converts to `\\`)
- ✅ Preserves emoji and unicode characters
- ✅ Pipe-friendly for easy integration
- ✅ Handles multiline heredocs
- ✅ Tab character escaping (converts to `\t`)

### Usage

#### Dot-source the script

```powershell
. ./scripts/ConvertTo-EscapedGraphQL.ps1
```

#### Basic usage with pipeline

```powershell
"Hello `"World`"" | ConvertTo-EscapedGraphQL
# Output: Hello \"World\"
```

#### Using the -Value parameter

```powershell
ConvertTo-EscapedGraphQL -Value "Line 1`nLine 2"
# Output: Line 1\nLine 2
```

#### Handling heredocs (multiline strings)

```powershell
@"
Multi-line
text with "quotes"
and \ backslashes
"@ | ConvertTo-EscapedGraphQL
# Output: Multi-line\ntext with \"quotes\"\nand \\ backslashes
```

#### Real-world example: GraphQL mutation

```powershell
$issueBody = @"
## Issue Description
This PR fixes:
- Escaping "quotes"
- Handling paths like C:\Windows
- Emoji support 🚀
"@

$escapedBody = $issueBody | ConvertTo-EscapedGraphQL
$mutation = "mutation { createIssue(body: \`"$escapedBody\`") }"
# Ready to send to GraphQL API
```

### Testing

Run the test suite to verify functionality:

```powershell
pwsh -File scripts/Test-ConvertTo-EscapedGraphQL.ps1
```

The test suite validates:
- Quote escaping
- Backslash escaping
- Newline handling (LF, CRLF, CR)
- Tab character escaping
- Emoji preservation
- Unicode character preservation
- Empty string handling
- Complex mixed content
- Multiple consecutive special characters

### GraphQL Escaping Rules

The utility follows GraphQL string literal escaping rules:

| Character | Escaped As | Description |
|-----------|------------|-------------|
| `\`       | `\\`       | Backslash |
| `"`       | `\"`       | Double quote |
| Newline   | `\n`       | Line feed (LF) |
| `\r\n`    | `\n`       | Carriage return + line feed (CRLF) |
| `\r`      | `\r`       | Carriage return (CR) |
| Tab       | `\t`       | Tab character |
| Emoji     | (preserved)| Unicode emoji preserved as-is |
| Unicode   | (preserved)| Unicode characters preserved as-is |

## Contributing

When adding new scripts to this directory:

1. Follow PowerShell best practices
2. Include comprehensive comment-based help
3. Add test scripts when applicable
4. Update this README with documentation
5. Use the `ConvertTo-Verb` naming convention for functions
