# 👋 Akwaaba

**Welcome to Continuous AI Development**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Build Status](https://img.shields.io/badge/build-passing-success.svg)](#)

> **Status:** Active development — This is a reference implementation demonstrating the Anokye-Krom System governance model.

## What is Akwaaba?

**Akwaaba** (Akan/Twi: "Welcome") is a reference implementation demonstrating the **Anokye-Krom System** — a governance model for GitHub repositories where all commits originate from AI agents responding to human-created issues.

Inspired by [Steve Yegge's Gas Town](https://medium.com/@steve.yegge/gas-town-8b8c5e58f5f7), but distinctly Anokye Labs.

### Key Capabilities

- **Agent-only commits** — Humans create issues, agents create code
- **Issue-driven development** — All work tracked through GitHub issues with hierarchical organization
- **Strict enforcement** — Branch protection, commit validation, and authentication
- **Full observability** — Structured logging, tracing, and monitoring via Okyerema (talking drummer)
- **Safe operations** — Read-only by default, write via safe-output processing

## The Anokye-Krom System

The Anokye-Krom System is our governance framework that ensures consistency and quality through automation. It operates on six core principles:

1. **Agent-Only Commits** — All code changes come from AI agents, never direct human commits
2. **Issue-Driven Development** — Every change starts with a GitHub issue; no ad-hoc modifications
3. **Strict Enforcement** — Branch protection rules prevent bypassing the system
4. **Hierarchical Decomposition** — Work is organized as Epics → Features → Tasks
5. **Observability by Default** — All operations are logged and traceable via Okyerema
6. **Safe Operations** — Agents operate in read-only mode except through validated outputs

The system uses GitHub's native features (Projects, Issues, Actions) combined with custom automation to create a self-governing repository where AI agents handle all implementation while humans focus on planning and review.

## Quick Start

### Prerequisites

Before working with Akwaaba, ensure you have:

- **[GitHub CLI](https://cli.github.com/)** (`gh`) version 2.0 or later — For interacting with GitHub from the command line
- **[.NET SDK](https://dotnet.microsoft.com/download)** (8.0 or later) — For building and running .NET projects
- **[PowerShell](https://github.com/PowerShell/PowerShell)** (7.0 or later) — For automation scripts

### Getting Started

1. **Clone the repository:**
   ```bash
   gh repo clone anokye-labs/akwaaba
   cd akwaaba
   ```

2. **Review the planning documentation:**
   ```bash
   # Read the implementation plan
   cat planning/README.md
   
   # Browse phase-specific plans
   ls planning/phase-*
   ```

3. **Set up your environment:**
   
   See [SETUP.md](./SETUP.md) for detailed setup instructions, including:
   - GitHub App configuration
   - Repository settings
   - Agent authentication
   - Testing your first workflow

4. **Explore the codebase:**
   ```bash
   # View repository structure
   tree -L 2
   
   # Read agent documentation
   cat agents.md
   
   # Understand how we work
   cat how-we-work.md
   ```

## Project Structure

```
akwaaba/
├── .github/
│   ├── agents/           # Agent instruction files
│   ├── skills/           # Reusable agent skills (like Okyerema)
│   └── workflows/        # GitHub Actions automation
├── docs/                 # Detailed documentation
│   └── adr/              # Architecture Decision Records
├── how-we-work/          # Process and coordination guides
├── planning/             # Phase-by-phase implementation plans
├── scripts/              # PowerShell automation scripts
└── src/                  # Source code (when implemented)
```

## Documentation

- **[Planning Docs](./planning/README.md)** — Phase-by-phase implementation breakdown
- **[Agents Guide](./agents.md)** — How AI agents work in this repository
- **[How We Work](./how-we-work.md)** — Process, coordination, and issue management
- **[Setup Guide](./SETUP.md)** — Replicate this pattern in your own repository
- **[Architecture](./docs/)** — Technical design and decisions

## Contributing

Akwaaba follows the **issue-first workflow**:

1. **Create an issue** describing what you want to accomplish
2. **Wait for an agent** to implement the changes and create a PR
3. **Review the PR** and provide feedback
4. **Merge** when ready

Direct commits to `main` are blocked by branch protection. All changes must go through the agent workflow.

### Good First Issues

New to the project? Look for issues tagged with `good-first-issue` in the [Issues tab](https://github.com/anokye-labs/akwaaba/issues).

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Attribution

Akwaaba builds on patterns from:
- [copilot-media-plugins](https://github.com/anokye-labs/copilot-media-plugins) — Media processing skills
- [amplifier-dotnet](https://github.com/anokye-labs/amplifier-dotnet) — .NET instrumentation patterns

## Contact

- **Organization:** [Anokye Labs](https://github.com/anokye-labs)
- **Issues:** [GitHub Issues](https://github.com/anokye-labs/akwaaba/issues)
- **Discussions:** [GitHub Discussions](https://github.com/anokye-labs/akwaaba/discussions)

---

**Akwaaba!** Welcome to the future of AI-assisted development. 🚀
