# 👋 Akwaaba

**Welcome to Continuous AI**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> **🚧 Status:** Active development | Reference implementation in progress

## What is Akwaaba?

**Akwaaba** (pronounced "ah-KWA-bah") means "Welcome" in Akan/Twi, the language of the Akan people of Ghana. In the same way that Akwaaba extends a warm welcome to guests, this project welcomes a new paradigm: **AI agents as full participants in software development**.

Akwaaba is a reference implementation demonstrating the **Anokye-Krom System** — a governance model for GitHub repositories where all commits originate from AI agents responding to issues. Inspired by principles of structured coordination and safe automation, Akwaaba shows what's possible when humans and AI work together within clear boundaries.

### Key Capabilities

- **Agent-Only Commits**: All code changes are made by AI agents responding to GitHub issues
- **Issue-Driven Development**: Every change is tracked, discussed, and approved through issues
- **Strict Enforcement**: Branch protection and automated validation ensure governance rules are followed
- **Full Observability**: Comprehensive logging and monitoring of all agent actions
- **Safe Operations**: Read-only by default with structured, validated write operations

## The Anokye-Krom System

The **Anokye-Krom System** (named after the legendary Akan symbol of unity) operates on six core principles:

1. **Agent-Only Commits** — Humans create issues and review PRs; AI agents write code
2. **Issue-Driven Development** — All work originates from and is tracked through GitHub issues
3. **Strict Enforcement** — Branch protection rules and automated workflows prevent policy violations
4. **Hierarchical Decomposition** — Complex work is broken into Epic → Feature → Task hierarchies
5. **Observability by Default** — All agent actions are logged, traced, and auditable
6. **Safe Operations** — Write operations use validated, structured outputs; reads are unrestricted

### The Okyerema

In Akan culture, the **Okyerema** (talking drummer) communicates through the drum, keeping the community coordinated. In Akwaaba, the Okyerema skill (`.github/skills/okyerema/`) teaches AI agents how to:

- Create and manage GitHub issues with proper types (Epic, Feature, Task, Bug)
- Build parent-child hierarchies using GitHub's sub-issues API
- Manipulate GitHub Projects via GraphQL
- Coordinate work across the repository

When the Okyerema beats the drum, the asafo (team) moves in formation.

## Project Structure

```
akwaaba/
├── .github/                  # GitHub-specific configurations
│   ├── okyerema/            # Auto-approval rules and configurations
│   ├── skills/              # Agent skills (coordination and orchestration)
│   │   └── okyerema/       # The talking drummer - project orchestration
│   └── workflows/           # GitHub Actions workflows
├── docs/                     # Documentation
│   └── adr/                 # Architecture Decision Records
├── how-we-work/             # Collaboration guides
│   ├── agent-conventions.md # AI agent behavior standards
│   ├── getting-started.md   # Introduction to GitHub Issues
│   ├── glossary.md          # Akan terms and concepts
│   ├── our-way.md           # Work structure and coordination
│   └── adr-process.md       # ADR documentation process
├── planning/                 # Implementation planning
│   ├── phase-1-foundation/  # Repository setup
│   ├── phase-2-governance/  # Enforcement infrastructure
│   ├── phase-3-agents/      # Agent fleet implementation
│   ├── phase-4-dotnet/      # Example .NET application
│   ├── phase-5-documentation/ # Comprehensive documentation
│   └── phase-6-validation/  # Testing and validation
├── scripts/                  # PowerShell automation scripts
│   ├── examples/            # Usage examples and sample data
│   ├── Get-*.ps1           # Query scripts (DAG status, issues, PRs)
│   ├── Invoke-*.ps1        # Action scripts (health checks, workflows)
│   ├── New-*.ps1           # Creation scripts (issues, hierarchies)
│   ├── Set-*.ps1           # Update scripts (assignments, dependencies)
│   └── Test-*.ps1          # Test scripts for validation
├── agents.md                 # Agent documentation and conventions
└── how-we-work.md           # Human-readable collaboration guide
```

### Directory Descriptions

- **`.github/`** — GitHub-specific configurations including agent coordination skills (Okyerema), auto-approval rules, and workflow automation
- **`docs/`** — Documentation including Architecture Decision Records (ADRs) that explain key technical decisions
- **`how-we-work/`** — Guides explaining how humans and agents collaborate, including conventions, processes, and glossary
- **`planning/`** — Detailed implementation plans organized by development phases, each containing feature specifications
- **`scripts/`** — PowerShell automation scripts for issue management, project coordination, health checks, and workflow automation
- **`agents.md`** — Primary documentation for AI agents, explaining skills and behavioral conventions
- **`how-we-work.md`** — Human-readable overview of collaboration patterns and coordination mechanisms

For architectural details and system design, see [ARCHITECTURE.md](ARCHITECTURE.md) *(coming soon)*.

## Quick Start

### Prerequisites

- **GitHub CLI** (`gh`) — [Install guide](https://cli.github.com/)
- **PowerShell** 7+ — [Install guide](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell)
- **.NET SDK** 8.0+ — [Install guide](https://dotnet.microsoft.com/download) *(for Phase 4+)*

### Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/anokye-labs/akwaaba.git
   cd akwaaba
   ```

2. **Review the planning:**
   ```bash
   cat planning/README.md
   ```

3. **Explore the Okyerema skill:**
   ```bash
   cat .github/skills/okyerema/SKILL.md
   ```

4. **Try a script:**
   ```powershell
   pwsh scripts/Get-DagStatus.ps1 -Owner anokye-labs -Repo akwaaba
   ```

For detailed setup instructions, see [SETUP.md](SETUP.md) *(coming soon)*.

## Documentation

- **[Planning](planning/README.md)** — Complete implementation plan across 6 phases
- **[How We Work](how-we-work.md)** — Coordination patterns for humans and agents
- **[Agents Guide](agents.md)** — Skills and conventions for AI agents
- **[ADRs](docs/adr/README.md)** — Architecture Decision Records
- **[Scripts](scripts/README.md)** — PowerShell automation documentation

### For Agents

AI agents should start with these resources:
1. **[Agents Guide](agents.md)** — Understand skills and conventions
2. **[Okyerema Skill](.github/skills/okyerema/SKILL.md)** — Learn project coordination
3. **[Agent Conventions](how-we-work/agent-conventions.md)** — Behavioral requirements

### For Humans

New contributors should read:
1. **[How We Work](how-we-work.md)** — Overview of our collaboration model
2. **[Getting Started](how-we-work/getting-started.md)** — Introduction to GitHub Issues
3. **[Our Way](how-we-work/our-way.md)** — Work structure and patterns

## Contributing

Akwaaba follows an **issue-first workflow**:

1. **Create an issue** describing the work to be done
2. **An AI agent** will pick up the issue and create a PR
3. **Review the PR** and provide feedback
4. **The agent** will address feedback and merge when approved

**Direct commits to `main` are blocked.** All changes must go through issues and pull requests.

For contribution guidelines and coding standards, see [CONTRIBUTING.md](CONTRIBUTING.md) *(coming soon)*.

### Good First Issues

Look for issues labeled `good-first-issue` to get started. These are well-scoped tasks suitable for new contributors or agents learning the system.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Attribution

Akwaaba builds on patterns from:
- **[copilot-media-plugins](https://github.com/anokye-labs/copilot-media-plugins)** — Media processing patterns
- **[amplifier-dotnet](https://github.com/anokye-labs/amplifier-dotnet)** — .NET architecture patterns

Inspired by concepts from:
- **Steve Yegge's "Gas Town"** — AI-driven development workflows
- **Akan culture** — Principles of community coordination and communication

## Contact & Support

- **Issues**: [GitHub Issues](https://github.com/anokye-labs/akwaaba/issues)
- **Discussions**: [GitHub Discussions](https://github.com/anokye-labs/akwaaba/discussions)
- **Organization**: [Anokye Labs](https://github.com/anokye-labs)

---

*Medaase* (Thank you) for your interest in Akwaaba! 🎊
