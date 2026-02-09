# Getting Started with GitHub Issues

If you're new to GitHub Issues and Projects, this guide will get you oriented.

## What Are GitHub Issues?

Issues are how we track work. Think of them as structured to-do items that live inside a repository. Each issue has:

- **Title** — What needs to be done
- **Body** — Details, context, acceptance criteria
- **State** — Open or Closed
- **Type** — Epic, Feature, Task, or Bug
- **Assignees** — Who's working on it
- **Labels** — Optional tags for filtering

## Issue Types

GitHub has **organization-level issue types** that describe what kind of work an issue represents:

### Epic
A large initiative that spans multiple features and tasks. Think of it as a project phase or a major goal.

**Example:** "Phase 2: fal.ai Integration" — encompasses 19 tasks across 4 feature areas.

### Feature
A cohesive piece of functionality that delivers value. Features group related tasks.

**Example:** "PowerShell Script Conversion" — encompasses 8 individual script conversion tasks.

### Task
A specific, actionable piece of work that someone can pick up and complete.

**Example:** "Convert generate.sh to Invoke-FalGenerate.ps1"

### Bug
Something that's broken and needs fixing.

**Example:** "API timeout when processing large images"

## Issue Hierarchy

Issues can be connected in parent-child relationships:

```
Epic: Phase 2 - Integration
├─ Feature: Script Conversion
│  ├─ Task: Convert generate.sh
│  ├─ Task: Convert search.sh
│  └─ Task: Convert upload.sh
└─ Feature: Documentation
   ├─ Task: Write API reference
   └─ Task: Write examples
```

These relationships are created using GitHub's **sub-issues API** — a formal parent-child relationship system that uses GraphQL mutations.

## GitHub Projects

Projects are visual boards for tracking work across issues. They can have:

- **Views** — Board, table, or timeline layouts
- **Custom Fields** — Priority, status, effort estimates
- **Filters** — Show only what matters right now
- **Automation** — Auto-move cards based on status

## What Are Labels?

Labels are colored tags you can attach to issues for filtering. We use them **sparingly**:

- ✅ Good: `documentation`, `security`, `phase-2-fal-ai`
- ❌ Bad: `epic`, `task`, `in-progress`

Labels are for **categorization**, not for defining what type of work something is or how issues relate to each other.

## Next Steps

- **[Our Way](./our-way.md)** — How Anokye Labs structures work
- **[Glossary](./glossary.md)** — Akan terms and concepts

---

*[← Back to How We Work](../how-we-work.md)*
