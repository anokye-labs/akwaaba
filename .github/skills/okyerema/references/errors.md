# Common Errors & Fixes

**[← Back to SKILL.md](../SKILL.md)**

---

## Error: "Issue type not found"

**Cause:** Wrong type ID or type doesn't exist in organization.

**Fix:** Re-query organization types:
```graphql
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
```

---

## Error: trackedIssues is empty after body update

**Cause:** GitHub hasn't parsed the tasklist yet.

**Fix:** Wait 2-5 minutes, then re-query. Check web UI first (updates faster than GraphQL).

---

## Error: Epic tracks both Features AND Tasks

**Cause:** Added new Feature tasklist without removing old Task tasklist.

**Fix:** Parse body, remove ALL existing tasklist sections, add only the correct one:

```powershell
$lines = $body -split "`n"
$cleanLines = @()
$inTasklist = $false

foreach ($line in $lines) {
    if ($line -match '^## .* Tracked') {
        $inTasklist = $true
        continue
    }
    if ($inTasklist -and $line -match '^- \[') { continue }
    if ($inTasklist -and $line -match '^$') { continue }
    if ($inTasklist -and $line -match '^##') { $inTasklist = $false }
    if (-not $inTasklist) { $cleanLines += $line }
}

$cleanBody = ($cleanLines -join "`n").TrimEnd()
$newBody = $cleanBody + "`n`n## 📋 Tracked Features`n`n- [ ] #106`n- [ ] #107"
```

---

## Error: GraphQL mutation `addTrackedByIssue` doesn't exist

**Cause:** There is no direct GraphQL mutation for parent-child relationships.

**Fix:** The ONLY mechanism is **Tasklists in issue body**. Update the parent issue body with markdown checkboxes.

---

## Error: gh CLI can't set issue type

**Cause:** The `gh issue create` command has no `--type` flag.

**Fix:** Use GraphQL `createIssue` mutation with `issueTypeId` parameter.

---

## Error: Project field doesn't create issue relationship

**Cause:** Project custom fields are for tracking/visualization only.

**Fix:** Use Tasklists in issue body for actual parent-child relationships. Projects fields are separate.

---

## Error: Garbled emoji in issue body

**Cause:** Encoding issues when passing emoji through PowerShell string escaping.

**Fix:** Use simple ASCII headers or ensure UTF-8 encoding:
```powershell
# Use simple header if emoji causes issues
$header = "## Tracked Features"
# Instead of
$header = "## 📋 Tracked Features"
```

---

## Pre-Flight Checklist

Before starting any issue operations:

- [ ] I have the repository ID (`R_xxx`)
- [ ] I have organization issue type IDs (`IT_xxx`)
- [ ] I'm using GraphQL API (not gh CLI for types/relationships)
- [ ] I'm NOT using labels for types
- [ ] I've planned the hierarchy (3-level or 2-level?)
- [ ] I'll wait 2-5 minutes before verifying tasklist relationships

**[← Back to SKILL.md](../SKILL.md)**
