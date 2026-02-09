# 👋 Akwaaba

**Welcome to Continuous AI — Where humans lead through issues, agents execute through code**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> **Status:** 🚧 Active Development — Reference implementation in progress

## What is Akwaaba?

**Akwaaba** (pronounced "ah-KWA-bah") means "Welcome" in Akan/Twi, the language of the Akan people of Ghana. It's the greeting that invites you into a space where collaboration happens differently.

This repository is a **reference implementation** of the **Anokye-Krom System** — a governance model for software development where:

- **Humans provide direction** through GitHub Issues
- **AI agents execute the work** through commits and pull requests
- **Automation enforces the rules** through branch protection and validation
- **Everyone benefits** from predictable, traceable, auditable development

Inspired by Steve Yegge's "Gas Town" concept, but distinctly Anokye Labs — we're building a system that works in practice, not just in theory.

## The Anokye-Krom System

The **Anokye-Krom System** (named after the legendary Okomfo Anokye, priest and co-founder of the Ashanti Empire) is a governance framework that transforms how humans and AI agents collaborate on code.

### Core Principles

The system operates on six foundational principles:

1. **Agent-Only Commits** — All code changes originate from AI agents responding to issues. Human commits are blocked by branch protection rules. This ensures every change is:
   - Tied to a tracked issue
   - Reviewed before merge
   - Attributable to a specific request

2. **Issue-Driven Development** — Every unit of work begins as a GitHub Issue. Issues define scope, capture context, and create an audit trail. The hierarchy (Epic → Feature → Task) structures complex work into manageable pieces.

3. **Strict Enforcement** — Branch protection rulesets, commit message validators, and authentication workflows prevent circumvention. The system doesn't rely on discipline — it relies on automation.

4. **Hierarchical Decomposition** — Large initiatives decompose into epics, features, and tasks using GitHub's sub-issues API. Agents work at the task level; humans coordinate at the epic and feature level.

5. **Observability by Default** — Every action generates structured logs. Every change links to an issue. Every decision is traceable. Debugging isn't detective work — it's log analysis.

6. **Safe Operations** — Agents operate in read-only mode by default. Write operations use safe-output processing with validation gates. Rollback is always possible.

### How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                     Anokye-Krom System                      │
│                                                             │
│  ┌──────────┐         ┌──────────┐         ┌──────────┐   │
│  │  Human   │ creates │  Issue   │ triggers│   Agent  │   │
│  │          │────────>│          │────────>│          │   │
│  │ Engineer │         │  (Task)  │         │ Executor │   │
│  └──────────┘         └──────────┘         └──────────┘   │
│       │                                           │        │
│       │                                           │        │
│       │ reviews                          creates  │        │
│       │                                           ▼        │
│       │                                    ┌──────────┐   │
│       └────────────────────────────────────│   Pull   │   │
│                                            │  Request │   │
│                                            └──────────┘   │
│                                                   │        │
│                                                   │        │
│                                           merges  │        │
│                                                   ▼        │
│                                            ┌──────────┐   │
│                                            │   Main   │   │
│                                            │  Branch  │   │
│                                            └──────────┘   │
│                                                            │
│  Protected by: Rulesets, Validators, Authentication       │
└─────────────────────────────────────────────────────────────┘
```

### What Makes It Different

**Traditional Development:**
- Humans commit directly to branches
- Issues are optional tracking mechanisms
- Discipline determines quality
- Audit trails are incomplete

**Anokye-Krom System:**
- Agents commit through validated workflows
- Issues are required entry points
- Automation determines quality
- Audit trails are comprehensive

## Quick Start

### Prerequisites

- **GitHub CLI** (`gh`) — [Install](https://cli.github.com/)
- **PowerShell 7+** — [Install](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **.NET SDK 9+** (optional, for running examples) — [Install](https://dotnet.microsoft.com/download)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/anokye-labs/akwaaba.git
cd akwaaba

# Review the planning documents
cat planning/README.md

# Explore the structure
ls -la
```

For detailed setup instructions, see [SETUP.md](SETUP.md) *(coming soon)*.

## Project Structure

```
akwaaba/
├── .github/
│   ├── skills/          # Agent skills (documentation + scripts)
│   │   └── okyerema/    # Project management skill
│   └── workflows/       # CI/CD and automation
├── docs/
│   ├── adr/             # Architecture Decision Records
│   └── guides/          # How-to guides (coming soon)
├── how-we-work/         # Process documentation
├── planning/            # Implementation roadmap
├── scripts/             # Automation and helper scripts
├── src/                 # Source code (coming soon)
├── agents.md            # Agent-specific guidance
└── how-we-work.md       # Human-readable process overview
```

## Documentation

- **[How We Work](how-we-work.md)** — Process overview for humans and agents
- **[Agents](agents.md)** — Agent-specific conventions and skills
- **[Planning](planning/README.md)** — Complete implementation roadmap
- **[ADRs](docs/adr/README.md)** — Architecture Decision Records
- **[GOVERNANCE.md](GOVERNANCE.md)** — Enforcement model *(coming soon)*

## Contributing

**All contributions happen through issues.**

Direct commits to `main` are blocked. To contribute:

1. **Create an issue** describing the work
2. **Wait for an agent** to pick up the issue
3. **Review the pull request** when the agent completes the work
4. **Merge** if the work meets acceptance criteria

For new contributors, look for issues labeled `good first issue`.

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md) *(coming soon)*.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.

## Acknowledgments

- **Inspired by:** Steve Yegge's "Gas Town" concept
- **Built with:** GitHub Copilot, GitHub Actions, PowerShell
- **Patterns from:** [copilot-media-plugins](https://github.com/anokye-labs/copilot-media-plugins) and [amplifier-dotnet](https://github.com/anokye-labs/amplifier-dotnet)
- **Research:** [GitHub Sub-Issues API](https://docs.github.com/en/issues/tracking-your-work-with-issues/about-sub-issues), [GitHub GraphQL API](https://docs.github.com/en/graphql)

## Contact & Support

- **Issues:** [GitHub Issues](https://github.com/anokye-labs/akwaaba/issues)
- **Discussions:** [GitHub Discussions](https://github.com/anokye-labs/akwaaba/discussions)
- **Organization:** [Anokye Labs](https://github.com/anokye-labs)

---

*"Akwaaba" — Welcome to the future of software development.*
