---
name: okyerema
description: >
  Project orchestration skill for Anokye Labs. Use when creating, managing, or
  querying GitHub issues, projects, hierarchies, and relationships. The Okyerema
  (talking drummer) keeps agents in rhythm — coordinating adwoma (work) through
  the asafo (the team). Read this skill for any issue creation, hierarchy
  setup, project board manipulation, or when you need to understand how we
  structure work.
---

# Okyerema: The Talking Drummer

The Okyerema coordinates adwoma (work) across the asafo (team). This skill teaches agents how to orchestrate GitHub-based project management the Anokye Labs way.

## Core Principles

1. **Use GitHub organization issue types** (Epic, Feature, Task, Bug) — never labels or title prefixes
2. **Use GraphQL API for all write operations** — gh CLI is insufficient
3. **Use Sub-Issues API for parent-child relationships** — `addSubIssue` mutation with `GraphQL-Features: sub_issues` header
4. **Use labels only for categorization** — never for structure
5. **Relationships are immediate** — no parsing delays with sub-issues API
6. **Hierarchy: Epic → Feature → Task** — 3 levels when grouping exists, 2 levels when tasks are standalone

## When to Use This Skill

- Creating Epics, Features, or Tasks
- Setting up issue hierarchies
- Querying or manipulating GitHub Projects
- Checking issue relationships
- Responding to and resolving PR review threads
- Understanding how work is structured

## Quick Operations

### Get Organization Issue Type IDs

```graphql
query {
  organization(login: "anokye-labs") {
    issueTypes(first: 25) {
      nodes { id name }
    }
  }
}
```

### Create Issue with Correct Type

```graphql
mutation {
  createIssue(input: {
    repositoryId: "R_xxx"
    title: "Your Title"
    body: "Description"
    issueTypeId: "IT_xxx"
  }) {
    issue { id number title issueType { name } }
  }
}
```

### Create Parent-Child Relationship

Use the `addSubIssue` mutation (requires `GraphQL-Features: sub_issues` header):

```graphql
mutation {
  addSubIssue(input: {
    issueId: "I_parentNodeId"
    subIssueId: "I_childNodeId"
  }) {
    subIssue {
      number
      title
      parent {
        number
        title
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

**Limits:** Up to 100 sub-issues per parent, 8 levels of nesting.

### Verify Relationships

```graphql
query {
  repository(owner: "anokye-labs", name: "repo") {
    issue(number: 14) {
      issueType { name }
      subIssues(first: 50) {
        nodes { 
          number 
          title 
          issueType { name }
        }
      }
      parent {
        number
        title
        issueType { name }
      }
    }
  }
}
```

Run with: `gh api graphql -H "GraphQL-Features: sub_issues" -f query="..."`

## Hierarchy Patterns

### Pattern A: Epic → Feature → Task

Use when tasks group naturally into features:

```
Epic #14: Phase 2
├─ Feature #106: Core Skill Creation
│  ├─ Task #15: Analyze scripts
│  └─ Task #16: Create SKILL.md
└─ Feature #107: Script Conversion
   ├─ Task #17: Convert generate.sh
   └─ Task #18: Convert search.sh
```

### Pattern B: Epic → Task

Use when tasks are standalone:

```
Epic #1: Phase 0 Setup
├─ Task #2: Init repo
├─ Task #3: Create structure
└─ Task #4: Write .gitignore
```

## What NOT To Do

❌ `gh issue create --label "epic"` — Labels are not types
❌ `gh issue create --title "[Epic] Phase 2"` — Prefixes are not types
❌ Forget the `GraphQL-Features: sub_issues` header — Required for sub-issues API
❌ Use gh CLI for project field manipulation — Use GraphQL
❌ Use labels for structure — Labels are for categorization only

## References (Load When Needed)

For detailed GraphQL examples and workflows, reference these guides:

- **[Issue Types](references/issue-types.md)** — Creating, updating, verifying types
- **[Relationships](references/relationships.md)** — Parent-child, hierarchy queries, orphan detection
- **[Projects](references/projects.md)** — GitHub Projects V2 GraphQL API
- **[PR Reviews](references/pr-reviews.md)** — Reply to, resolve, and find unresolved review threads
- **[Labels](references/labels.md)** — When and how to use labels properly
- **[Errors & Fixes](references/errors.md)** — Common mistakes and solutions

## Helper Scripts

Invoke these scripts for common operations:

- **[scripts/Get-IssueTypeIds.ps1](scripts/Get-IssueTypeIds.ps1)** — Retrieve type IDs for an organization
- **[scripts/New-IssueWithType.ps1](scripts/New-IssueWithType.ps1)** — Create issue with proper type
- **[scripts/Update-IssueHierarchy.ps1](scripts/Update-IssueHierarchy.ps1)** — Build parent-child relationships via sub-issues API
- **[scripts/Test-Hierarchy.ps1](scripts/Test-Hierarchy.ps1)** — Verify relationships via GraphQL

## Labels: Use Sparingly

Labels are for **filtering and categorization only**:

✅ **Good uses:** `documentation`, `security`, `typescript`, `good-first-issue`, `breaking-change`
❌ **Bad uses:** `epic`, `task`, `blocked-by-7`, `in-progress`, `parent:14`

If you're tempted to create a label for structure, you're using the wrong tool. Use issue types, tasklists, or project fields instead.

## Glossary

| Akan Term | Meaning | In Our System |
|-----------|---------|---------------|
| **Okyerema** | Talking drummer | This skill — the orchestrator |
| **Asafo** | Warrior company | The team of agents and humans |
| **Adwoma** | Work | Issues, tasks, deliverables |
| **Akwaaba** | Welcome | This reference repo |
| **Okyeame** | Spokesperson | Client applications |
| **Ananse** | Spider (folklore) | The agentic runtime |
