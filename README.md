# Akwaaba

**Akwaaba** (ah-KWAH-bah) means *"Welcome"* in Akan/Twi — and that is exactly what this is. Welcome to the Anokye System.

This repository is the reference implementation for a governance model where humans and AI agents collaborate through structured, issue-driven development. Everything you need to understand how Anokye Labs works lives here.

> *When the Okyerema beats the drum, the asafo moves in formation.*

## The Anokye System

The Anokye System is built on a simple premise: **humans decide what to build, agents build it, and GitHub is the coordination layer.**

Today, two forces drive the system forward:

- **The Okyeame** (Linguist) — the client interface. [WatchTower](https://github.com/anokye-labs/watchtower) is the current Okyeame: a cross-platform desktop application with an "Ancestral Futurism" design language, providing the voice between humans and the system.
- **The Okyerema** (Talking Drummer) — the OODA orchestration skill. The Okyerema implements an **Observe → Orient → Decide → Act** loop for coordinating work. It is optimized for GitHub Issues — because issues are the most natural protocol for coordinating agents — but the pattern is not limited to GitHub.

Together, the Okyeame and the Okyerema form the working heart of the system. The Okyeame speaks; the Okyerema orchestrates.

### Why GitHub Issues?

Issues are not just task tracking. In the Anokye System, they are **external memory** — the single source of truth that both humans and AI agents can read, write, and act on. An issue is a contract. A sub-issue is a decomposition. A dependency is a sequencing constraint. This makes the issue DAG (directed acyclic graph) the coordination protocol for the entire asafo.

The strategic advantage: any agent that can read and write GitHub Issues can participate in the system without custom integration.

### Roles and Concepts

Every concept in the system draws from Akan culture:

| Role | Akan | What It Does | Status |
|------|------|-------------|--------|
| **Akwaaba** | Welcome | This repo — the reference implementation and onboarding ground | ✅ Active |
| **Okyeame** | Linguist | Client applications — [WatchTower](https://github.com/anokye-labs/watchtower) is the current Okyeame | ✅ Active |
| **Okyerema** | Talking Drummer | OODA orchestration of work — keeps agents in rhythm | ✅ Active |
| **Asafo** | Warriors | The team — humans and AI agents working together | ✅ Active |
| **Adwoma** | Work | GitHub Issues — external memory and single source of truth | ✅ Active |
| **Omanfo** | The People | Shared plugin — bundles skills for distribution | 🔧 In Progress |
| **Sankofa** | Return and get it | Automated health patrols — looking back to move forward | 🔧 In Progress |
| **Ananse** | Spider | The agentic runtime — not yet part of the system | 🔮 Future |

```
                        ┌──────────────┐
                        │   Okyeame    │
                        │ (WatchTower) │
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
                        │ (OODA Loop)  │
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

## The Okyerema: OODA Orchestration

The Okyerema is more than a project management tool. It implements the OODA loop:

- **Observe** — Read the issue DAG. What's done? What's blocked? What's ready?
- **Orient** — Understand dependencies, priorities, and the current state of the asafo.
- **Decide** — Select the next piece of work. Assign it.
- **Act** — Create branches, open PRs, resolve issues, advance the plan.

This loop runs continuously. When an agent completes a task, the Okyerema observes the change, re-orients, and decides what comes next. The drummer never stops.

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

## The Anokye Labs Ecosystem

| Repository | Role | Description |
|-----------|------|-------------|
| **[akwaaba](https://github.com/anokye-labs/akwaaba)** | Akwaaba | This repo — reference implementation and welcome mat |
| **[watchtower](https://github.com/anokye-labs/watchtower)** | Okyeame | Cross-platform desktop client with Ancestral Futurism design language |
| **[plugins](https://github.com/anokye-labs/plugins)** | Omanfo | Packages Okyerema + shared skills for distribution |
| **[copilot-media-plugins](https://github.com/anokye-labs/copilot-media-plugins)** | — | Agentic media plugins for GitHub Copilot |

## Why "Akwaaba"?

In Akan culture, *Akwaaba* is the first word you hear when you arrive. It means "welcome" — an invitation to enter, learn, and participate.

This repository serves the same purpose. Whether you're a new team member, a curious developer, or an AI agent encountering this system for the first time — akwaaba. Welcome. Everything you need to understand how we work is here.

---

*[How We Work](how-we-work.md) · [Agents](agents.md) · [Glossary](how-we-work/glossary.md) · [ADRs](docs/adr/) · [Planning](planning/)*
