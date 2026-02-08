<#
.SYNOPSIS
    Examples demonstrating usage of Invoke-PRCompletion.ps1

.DESCRIPTION
    This file contains various examples showing how to use the Invoke-PRCompletion.ps1
    script for automatically completing PR review threads.
#>

# Path to the script
$scriptPath = Join-Path $PSScriptRoot "Invoke-PRCompletion.ps1"

Write-Host "`n=== Invoke-PRCompletion.ps1 Usage Examples ===" -ForegroundColor Green
Write-Host ""

# Example 1: Dry run to preview what would be done
Write-Host "Example 1: Dry run to preview what would be done" -ForegroundColor Cyan
Write-Host "------------------------------------------------" -ForegroundColor DarkGray

$example1 = @"
# Run in dry-run mode to see what the script would do without making changes
& `$scriptPath ``
    -Owner 'anokye-labs' ``
    -Repo 'akwaaba' ``
    -PullNumber 6 ``
    -DryRun
"@

Write-Host $example1 -ForegroundColor Yellow
Write-Host ""
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  • Fetch all unresolved review threads" -ForegroundColor Gray
Write-Host "  • Classify each by severity (bug/suggestion/nit/question/praise)" -ForegroundColor Gray
Write-Host "  • Show a formatted report with proposed actions" -ForegroundColor Gray
Write-Host "  • NOT make any changes (no commits, pushes, replies, or resolves)" -ForegroundColor Gray
Write-Host ""

# Example 2: Dry run output example
Write-Host "Example 2: Expected dry run output format" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor DarkGray

$example2Output = @"
Dry Run - PR anokye-labs/akwaaba#6 (anokye-labs/akwaaba)
[Bug]        scripts/Foo.ps1:42                       - Undefined variable causes crash
[Nit]        references/doc.md:15                     - Consider rewording this sentence
[Question]   scripts/Baz.ps1:88                       - Why not use approach X instead?

Summary: 1 blocking, 1 nitpick, 1 question (3 total)
Action: Would fix 2, escalate 1
"@

Write-Host $example2Output -ForegroundColor DarkGray
Write-Host ""

# Example 3: Actually complete the PR review threads
Write-Host "Example 3: Actually complete the PR review threads" -ForegroundColor Cyan
Write-Host "-------------------------------------------------" -ForegroundColor DarkGray

$example3 = @"
# Run without -DryRun to actually process and complete threads
& `$scriptPath ``
    -Owner 'anokye-labs' ``
    -Repo 'akwaaba' ``
    -PullNumber 6
"@

Write-Host $example3 -ForegroundColor Yellow
Write-Host ""
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  • Fetch all unresolved review threads" -ForegroundColor Gray
Write-Host "  • Classify each thread by category" -ForegroundColor Gray
Write-Host "  • Reply to blocking/suggestion/nitpick threads with acknowledgment" -ForegroundColor Gray
Write-Host "  • Resolve those threads automatically" -ForegroundColor Gray
Write-Host "  • Escalate questions for human review (no auto-response)" -ForegroundColor Gray
Write-Host "  • Show a summary of actions taken" -ForegroundColor Gray
Write-Host ""

# Example 4: Using with quiet logging
Write-Host "Example 4: Using with quiet logging" -ForegroundColor Cyan
Write-Host "----------------------------------" -ForegroundColor DarkGray

$example4 = @"
# Suppress structured JSON logs to stderr
& `$scriptPath ``
    -Owner 'anokye-labs' ``
    -Repo 'akwaaba' ``
    -PullNumber 6 ``
    -DryRun ``
    -Quiet
"@

Write-Host $example4 -ForegroundColor Yellow
Write-Host ""

# Example 5: Integration with CI/CD
Write-Host "Example 5: Integration with CI/CD workflow" -ForegroundColor Cyan
Write-Host "-----------------------------------------" -ForegroundColor DarkGray

$example5 = @"
# In a GitHub Actions workflow or CI/CD pipeline:

# Step 1: Dry run first to review what would be done
& `$scriptPath -Owner 'anokye-labs' -Repo 'akwaaba' -PullNumber `$env:PR_NUMBER -DryRun

# Step 2: If approved, run for real
if (`$LASTEXITCODE -eq 0) {
    & `$scriptPath -Owner 'anokye-labs' -Repo 'akwaaba' -PullNumber `$env:PR_NUMBER
}
"@

Write-Host $example5 -ForegroundColor Yellow
Write-Host ""

# Example 6: Classification categories
Write-Host "Example 6: Understanding thread classifications" -ForegroundColor Cyan
Write-Host "-----------------------------------------------" -ForegroundColor DarkGray

Write-Host ""
Write-Host "The script classifies threads into these categories:" -ForegroundColor White
Write-Host ""
Write-Host "  [Bug/Blocking]  - Security issues, bugs, test failures → Auto-fix" -ForegroundColor Red
Write-Host "  [Suggestion]    - Recommended improvements → Auto-fix" -ForegroundColor Cyan
Write-Host "  [Nit]           - Minor style/formatting issues → Auto-fix" -ForegroundColor DarkGray
Write-Host "  [Question]      - Questions requiring clarification → Escalate to human" -ForegroundColor Magenta
Write-Host "  [Praise]        - Positive feedback → Acknowledge" -ForegroundColor Green
Write-Host ""

Write-Host "Classification is based on keywords in the comment:" -ForegroundColor Gray
Write-Host "  • 'security', 'vulnerability', 'bug', 'broken' → blocking" -ForegroundColor Gray
Write-Host "  • '?', 'why', 'how', 'explain' → question" -ForegroundColor Gray
Write-Host "  • 'nit', 'typo', 'formatting', 'optional' → nitpick" -ForegroundColor Gray
Write-Host "  • 'suggest', 'consider', 'could', 'should' → suggestion" -ForegroundColor Gray
Write-Host "  • 'nice', 'great', 'LGTM', 'thanks' → praise" -ForegroundColor Gray
Write-Host ""

Write-Host "=== End of Examples ===" -ForegroundColor Green
Write-Host ""
Write-Host "To run actual PR completions, use the commands above with real PR numbers." -ForegroundColor Yellow
Write-Host "Note: You need to be authenticated with 'gh auth login' first." -ForegroundColor Yellow
Write-Host "      Always run with -DryRun first to preview what will be done!" -ForegroundColor Yellow
Write-Host ""
