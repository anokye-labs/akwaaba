# Akwaaba

**Akwaaba** (ah-KWAH-bah) means *"Welcome"* in Akan/Twi. This is the reference implementation for the **Anokye System** — a governance model for GitHub repositories where AI agents and humans collaborate through structured, issue-driven development.

> *When the Okyerema beats the drum, the asafo moves in formation.*

## What Is This?

Akwaaba is where you come to learn how Anokye Labs works. It contains:

- **The Okyerema skill** — agent instructions for project orchestration via GitHub Issues, Projects, and sub-issues
- **30+ PowerShell scripts** — a complete toolkit for DAG tracking, PR workflows, plan materialization, and agent lifecycle management
- **Governance automation** — GitHub Actions that auto-assign unblocked work to agents
- **Conventions and guides** — how we structure work, name things, and make decisions

This isn't a library you install. It's a living reference that demonstrates a way of building software where issues are the single source of truth, agents are first-class contributors, and every change is traceable.

## The Anokye System

The Anokye System is built on a simple premise: **humans decide what to build, agents build it, and GitHub is the coordination layer.**

Every concept in the system draws from Akan culture:

| Role | Akan | What It Does |
|------|------|-------------|
| **Akwaaba** | Welcome | This repo — the reference implementation and onboarding ground |
| **Okyerema** | Talking Drummer | The orchestration skill — keeps agents in rhythm |
| **Asafo** | Warriors | The team — humans and AI agents working together |
| **Adwoma** | Work | GitHub Issues — the external memory and single source of truth |
| **Ananse** | Spider | The agentic runtime — GitHub Copilot, Actions, the web that connects everything |
| **Okyeame** | Linguist | Client applications — the voice between humans and machines |
| **Omanfo** | The People | The shared plugin — bundles skills for distribution |
| **Sankofa** | Return and get it | Automated health patrols — looking back to move forward |

```
                        ┌──────────────┐
                        │   Okyeame    │
                        │  (Client UI) │
                        └──────┬───────┘
                               │
                        ┌──────┴───────┐
                        │    Ananse    │
                        │  (Runtime)   │
                        └──────┬───────┘
                               │
                 ┌─────────────┼─────────────┐
                 │             │             │
           ┌─────┴─────┐ ┌────┴────┐ ┌──────┴──────┐
           │   Asafo   │ │  Asafo  │ │   Asafo     │
           │  (Agent)  │ │ (Agent) │ │  (Human)    │
           └─────┬─────┘ └────┬────┘ └──────┬──────┘
                 │             │             │
                 └─────────────┼─────────────┘
                               │
                        ┌──────┴───────┐
                        │  Okyerema   │
                        │  (Drummer)   │
                        │ Orchestrates │
                        │   adwoma     │
                        └──────┬───────┘
                               │
                        ┌──────┴───────┐
                        │   Adwoma     │
                        │ (GitHub      │
                        │  Issues)     │
                        └──────────────┘
```

## What's Inside

```
akwaaba/
├── .github/
│   ├── skills/okyerema/       # The Okyerema agent skill
│   │   ├── SKILL.md           #   Core instructions and GraphQL patterns
│   │   ├── references/        #   Detailed guides (issue types, relationships, projects, PRs)
│   │   └── scripts/           #   Agent helper scripts + tests
│   ├── workflows/             # GitHub Actions (auto-assign unblocked tasks)
│   └── okyerema/              # Agent configuration (auto-approve rules)
├── scripts/                   # PowerShell toolkit (30+ scripts)
├── planning/                  # Implementation plan (6 phases, 28 features)
├── how-we-work/               # Human-readable guides
│   ├── getting-started.md     #   New to GitHub Issues? Start here
│   ├── our-way.md             #   How we structure and coordinate work
│   ├── glossary.md            #   Akan terms and concepts
│   ├── agent-conventions.md   #   Behavioral rules for AI agents
│   └── adr-process.md         #   How we record architectural decisions
├── docs/adr/                  # Architectural Decision Records
├── agents.md                  # Agent entry point — read this first
└── how-we-work.md             # Human entry point — read this first
```

## The Scripts Toolkit

The `scripts/` directory contains a comprehensive PowerShell toolkit organized into five groups:

### Foundation
| Script | Purpose |
|--------|---------|
| `Invoke-GraphQL.ps1` | Centralized GraphQL executor with retry and rate limiting |
| `Get-RepoContext.ps1` | Cached repo/org/project context |
| `ConvertTo-EscapedGraphQL.ps1` | Safe string escaping for GraphQL |

### Issue Management & DAG
| Script | Purpose |
|--------|---------|
| `New-IssueBatch.ps1` | Create multiple typed issues in one operation |
| `New-IssueHierarchy.ps1` | Build Epic → Feature → Task trees |
| `Import-PlanToIssues.ps1` | Parse planning markdown into issues |
| `Get-DagStatus.ps1` | Recursive status walk of an issue hierarchy |
| `Get-ReadyIssues.ps1` | Find issues with all dependencies met |
| `Get-BlockedIssues.ps1` | Find issues blocked by open dependencies |
| `Get-OrphanedIssues.ps1` | Find issues not connected to any parent |
| `Get-DagCompletionReport.ps1` | Progress reporting per Epic/Feature |
| `Set-IssueDependency.ps1` | Express blocks/blocked-by relationships |
| `Add-IssuesToProject.ps1` | Bulk-add issues to a GitHub Project |
| `Set-IssueAssignment.ps1` | Assign issues to users or agents |

### Work Lifecycle
| Script | Purpose |
|--------|---------|
| `Start-IssueWork.ps1` | Assign self, create branch, update status |
| `Complete-IssueWork.ps1` | Push, create PR, link to issue, close |
| `Get-NextAgentWork.ps1` | Select next issue based on DAG readiness |
| `Get-StalledWork.ps1` | Find assigned issues with no progress |

### PR Workflows
| Script | Purpose |
|--------|---------|
| `Invoke-PRCompletion.ps1` | Automated review → fix → push → resolve loop |
| `Get-PRStatus.ps1` | Merge readiness, checks, reviews |
| `Get-PRCommentAnalysis.ps1` | Thread-level analysis with severity |
| `Get-ThreadSeverity.ps1` | Classify comments as bug/nit/suggestion/question |
| `Get-PRsByIssue.ps1` | Find PRs linked to specific issues |
| `Get-PRReviewTimeline.ps1` | Timeline of review activity |
| `Submit-PRReview.ps1` | Submit structured reviews |
| `Test-PRAutoApprovable.ps1` | Check if a PR meets auto-merge criteria |
| `Update-AutoApproveConfig.ps1` | Edit auto-approve rules |

### Orchestration & Health
| Script | Purpose |
|--------|---------|
| `Invoke-PlanMaterialization.ps1` | Convert a planning directory into an issue DAG |
| `Sync-PlanToIssues.ps1` | Detect drift between plan and issues |
| `Import-DagFromJson.ps1` | Bulk import from structured JSON |
| `Invoke-DagHealthCheck.ps1` | Detect orphans, cycles, type mismatches |
| `Invoke-SystemHealthCheck.ps1` | Full system integrity validation |

Every script includes a companion `Test-*.ps1` file, supports `-DryRun`, and follows PowerShell conventions with comment-based help.

## Key Design Decisions

These decisions are documented as [ADRs](docs/adr/) and enforced throughout the codebase:

1. **Sub-issues API for hierarchy** ([ADR-0001](docs/adr/ADR-0001-use-sub-issues-for-hierarchy.md)) — We use GitHub's `addSubIssue`/`removeSubIssue` mutations and `subIssues`/`parent` query fields. Not tasklists, not labels, not title prefixes.

2. **GraphQL for all writes** ([ADR-0002](docs/adr/ADR-0002-use-graphql-for-writes.md)) — Every mutation goes through `gh api graphql`. The CLI is insufficient for structured operations.

3. **Organization issue types** ([ADR-0003](docs/adr/ADR-0003-use-org-level-issue-types.md)) — We use Epic, Feature, Task, and Bug as GitHub organization-level issue types. Labels are for categorization only.

4. **Issues as external memory** — The issue DAG is the single source of truth. No separate project management tools, no manifests, no spreadsheets.

5. **Agent-first design** — Every script, convention, and workflow is designed for AI agents to use. Humans benefit from the same structure, but agents are the primary audience.

## Getting Started

### If You're a Human

Start with **[How We Work](how-we-work.md)** — it explains our issue hierarchy, naming conventions, and coordination model in plain language. Then browse the **[Glossary](how-we-work/glossary.md)** to understand the Akan terminology.

### If You're an Agent

Read **[agents.md](agents.md)** — it points you to the Okyerema skill and explains the behavioral conventions you must follow. The five core rules:

1. **Action-first** — Do it, don't discuss it
2. **Read-before-debug** — Check docs before trial-and-error
3. **Branch awareness** — Verify your branch before every git operation
4. **Skills are documentation** — Read SKILL.md, don't try to invoke it
5. **Minimal communication** — Fewest words necessary

### If You Want the Plugin

The Okyerema skill and shared capabilities are being packaged as the **[Omanfo Plugin](https://github.com/anokye-labs/plugins)** for installation into any repository. Until the plugin is ready, copy the `.github/skills/okyerema/` directory.

## Related Repositories

| Repository | Purpose |
|-----------|---------|
| [anokye-labs/plugins](https://github.com/anokye-labs/plugins) | The Omanfo plugin — packages Okyerema + shared skills for distribution |
| [anokye-labs/okyeame](https://github.com/anokye-labs/okyeame) | The Okyeame client — voice-first interface to the Ananse runtime |

## Why "Akwaaba"?

In Akan culture, *Akwaaba* is the first word you hear when you arrive. It means "welcome" — an invitation to enter, learn, and participate.

This repository serves the same purpose. Whether you're a new team member, a curious developer, or an AI agent encountering this system for the first time — akwaaba. Welcome. Everything you need to understand how we work is here.

---

*[How We Work](how-we-work.md) · [Agents](agents.md) · [Glossary](how-we-work/glossary.md) · [ADRs](docs/adr/) · [Planning](planning/)*
