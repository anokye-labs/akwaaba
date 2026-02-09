# 👋 Akwaaba

**Welcome to Continuous AI**

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-enabled-blue)](https://github.com/anokye-labs/akwaaba/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> **🚧 Project Status:** Active Development — This is a living reference implementation. The patterns are stable, but the codebase evolves continuously as agents respond to issues.

## What is Akwaaba?

**Akwaaba** (Akan/Twi: "Welcome") is a reference implementation of the **Anokye-Krom System** — a governance model for GitHub repositories where all commits originate from AI agents responding to human-created issues.

Inspired by Steve Yegge's "Gas Town" concept but distinctly Anokye Labs, this project demonstrates:

- **Agent-Only Commits:** Humans create issues, AI agents create all code
- **Issue-Driven Development:** Every change traces back to a GitHub issue
- **Structured Hierarchies:** Epics, Features, and Tasks managed via GitHub's sub-issues API
- **Full Observability:** Every agent action is logged, traced, and auditable
- **Safe Operations:** Automated validation, security scanning, and controlled execution

## The Anokye-Krom System

The **Anokye-Krom System** is named after the Akan town system (krom = town) and embodies six core principles:

### Core Principles

1. **Agent-Only Commits** — All code changes come from AI agents. Humans create and curate issues, agents execute them.

2. **Issue-Driven Development** — Every commit must be associated with a GitHub issue. No issue, no commit.

3. **Strict Enforcement** — Branch protection rules, commit validation, and automated checks prevent direct pushes.

4. **Hierarchical Decomposition** — Work is structured as Epics → Features → Tasks using GitHub's sub-issues API.

5. **Observability by Default** — Structured logging, distributed tracing, and comprehensive audit trails for all agent actions.

6. **Safe Operations** — Read-only by default. Write operations use safe-output processing with validation gates.

### The Okyerema

The **Okyerema** (talking drummer) is our coordination skill. Just as the traditional talking drum keeps the asafo (team) in rhythm, the Okyerema skill guides agents in:

- Creating and managing GitHub issues with proper types
- Building parent-child hierarchies via GraphQL
- Manipulating GitHub Projects for visibility
- Following consistent patterns across all operations

[Learn more about the Okyerema skill →](agents.md)

## Quick Start

### Prerequisites

- **GitHub CLI** (`gh`) with authentication configured
- **.NET 8 SDK** or later (for .NET examples)
- **PowerShell 7+** (for automation scripts)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/anokye-labs/akwaaba.git
cd akwaaba

# Review the planning documents
cat planning/README.md

# Explore the documentation
cat how-we-work.md
```

For detailed setup instructions, see [SETUP.md](SETUP.md) *(coming soon)*.

## Project Structure

```
akwaaba/
├── .github/
│   ├── skills/okyerema/      # Coordination skill for agents
│   └── workflows/            # GitHub Actions workflows
├── docs/
│   └── adr/                  # Architecture Decision Records
├── how-we-work/              # Human-readable process docs
├── planning/                 # Phase-by-phase implementation plan
├── scripts/                  # PowerShell automation scripts
└── agents.md                 # Agent operating documentation
```

## Documentation

### For Everyone

- **[How We Work](how-we-work.md)** — Understand our coordination approach
- **[Getting Started](how-we-work/getting-started.md)** — New to GitHub Issues? Start here
- **[Our Way](how-we-work/our-way.md)** — How we structure and coordinate work
- **[Glossary](how-we-work/glossary.md)** — Akan terms and concepts
- **[ADR Process](how-we-work/adr-process.md)** — How we document decisions

### For AI Agents

- **[Agents Documentation](agents.md)** — Agent operating model and conventions
- **[Okyerema Skill](.github/skills/okyerema/SKILL.md)** — Complete coordination skill with GraphQL examples
- **[Agent Conventions](how-we-work/agent-conventions.md)** — Behavioral requirements

### Technical Documentation

- **[Architecture Decision Records](docs/adr/)** — Key technical decisions
- **[Scripts Documentation](scripts/README.md)** — Automation script reference
- **[Planning Documents](planning/)** — Phase-by-phase implementation roadmap

## Contributing

We follow an **issue-first workflow**:

1. **Create an issue** describing the work (bug, feature, task)
2. **AI agent picks it up** and creates a PR with the solution
3. **Human reviews** the PR and merges if acceptable

**Note:** Direct commits to the main branch are blocked. All code changes must come through the agent workflow.

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md) *(coming soon)*.

### Good First Issues

Look for issues labeled [`good first issue`](https://github.com/anokye-labs/akwaaba/labels/good%20first%20issue) — these are great entry points for new contributors or agents.

## Research & Inspiration

This project builds on several key ideas and patterns:

### Foundational Concepts

- **Gas Town by Steve Yegge** — The original inspiration for agent-only commits ([Stevey's Blog, circa 2024](https://steve-yegge.medium.com/))
- **GitHub Sub-Issues API** — Hierarchical issue relationships ([GitHub Blog](https://github.blog/))
- **Anokye Labs Philosophy** — Agent-human collaboration patterns

### Pattern Influences

This implementation adapts patterns from two key sources:

1. **[copilot-media-plugins](https://github.com/microsoft/copilot-media-plugins)** — Microsoft's reference for GitHub Actions-first agent design
   - Actions-first architecture (agents as GitHub Actions workflows)
   - Error handling patterns (exponential backoff, circuit breakers)
   - Queue management and observability
   - Structured logging and distributed tracing

2. **[amplifier-dotnet](https://github.com/anokye-labs/amplifier-dotnet)** — Anokye Labs' .NET application patterns
   - Safe-output processing for agent-generated code
   - Validation gates and security scanning
   - Configuration management for multi-environment deployments
   - PowerShell automation scripts for complex workflows

### Additional Research

- **Distributed Systems Patterns** — Saga pattern, eventual consistency
- **Agent Coordination** — Multi-agent systems, task decomposition
- **GitHub GraphQL API** — Advanced queries, mutations, and pagination
- **Infrastructure as Code** — Declarative configuration, drift detection

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

Copyright (c) 2026 Anokye Labs

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Acknowledgments

Special thanks to:

- **Steve Yegge** for the Gas Town concept that inspired this work
- **Microsoft** for the copilot-media-plugins patterns that shaped our agent architecture
- **The GitHub team** for the sub-issues API and GraphQL capabilities
- **The Akan people** for the cultural concepts (Akwaaba, Okyerema, Anokye-Krom) that name our system

## Contact & Support

### Community

- **Issues:** [github.com/anokye-labs/akwaaba/issues](https://github.com/anokye-labs/akwaaba/issues)
- **Discussions:** [github.com/anokye-labs/akwaaba/discussions](https://github.com/anokye-labs/akwaaba/discussions)

### Anokye Labs

- **Website:** [anokyeLabs.com](https://anokyeLabs.com) *(coming soon)*
- **Email:** hello@anokyeLabs.com
- **GitHub:** [@anokye-labs](https://github.com/anokye-labs)

### Maintainers

This project is maintained by the Anokye Labs team with contributions from AI agents and human reviewers.

---

**Made with ❤️ by humans and agents working together**

*Akwaaba! Welcome to the future of continuous AI.*
