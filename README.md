# 👋 Akwaaba

**Welcome to Continuous AI**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

> **⚠️ Status:** Active development — This repository demonstrates the Anokye-Krom System governance model. All commits are made by AI agents in response to human-created issues.

---

## What is Akwaaba?

**Akwaaba** (Akan/Twi: "Welcome") is a reference implementation demonstrating the **Anokye-Krom System** — a governance model for GitHub repositories where AI agents handle all code commits in response to human-created issues.

Inspired by Steve Yegge's "Gas Town" concept but distinctly Anokye Labs, Akwaaba proves that **Continuous AI** is not just possible, but practical. Humans define the work through issues, and AI agents execute it through code.

### The Anokye-Krom System

The **Anokye-Krom System** is a governance model that enforces agent-only commits while maintaining full human oversight:

- **Agent-only commits** — Humans create issues and review pull requests; AI agents write all code
- **Issue-driven development** — Every change originates from a GitHub issue with clear requirements
- **Strict automation** — Branch protection, commit validation, and authentication enforce the rules
- **Full observability** — Structured logging, tracing, and monitoring track all agent actions
- **Safe operations** — Read-only by default; writes happen through validated, safe-output processing

### Key Capabilities

Akwaaba demonstrates how to:

- **Orchestrate AI agents** using GitHub Issues, Projects, and the Okyerema coordination skill
- **Enforce governance** through branch protection rules and automated validation
- **Maintain quality** with AI-powered code reviews, security scanning, and automated testing
- **Scale collaboration** between human oversight and autonomous agent execution
- **Document patterns** that other teams can adopt for their own AI-assisted workflows

---

## The Okyerema: Coordination Through Rhythm

The **Okyerema** (talking drummer) keeps the asafo (team) in rhythm. This coordination skill teaches AI agents how to:

- Create and manage GitHub Issues with proper organization types (Epic, Feature, Task, Bug)
- Build parent-child hierarchies using GitHub's sub-issues API
- Manipulate GitHub Projects via GraphQL
- Use labels appropriately (sparingly, for categorization only)
- Verify relationships and troubleshoot issues

When the Okyerema beats the drum, the asafo moves in formation.

**Learn more:** [Agents Guide](agents.md) | [Okyerema Skill](.github/skills/okyerema/SKILL.md)

---

## Quick Start

### Prerequisites

- [GitHub CLI](https://cli.github.com/) (for GraphQL operations)
- [.NET SDK 9.0+](https://dotnet.microsoft.com/download) (for example applications)
- [PowerShell 7.4+](https://github.com/PowerShell/PowerShell) (for automation scripts)

### Get Started

```bash
# Clone the repository
git clone https://github.com/anokye-labs/akwaaba.git
cd akwaaba

# Review the implementation plan
cat planning/README.md

# Explore how we work
cat how-we-work.md
```

For comprehensive setup instructions, see [SETUP.md](SETUP.md) *(coming soon)*.

---

## Project Structure

```
akwaaba/
├── .github/
│   ├── agents/          # Agent configuration and prompts
│   ├── skills/          # Reusable agent skills (Okyerema)
│   └── workflows/       # GitHub Actions automation
├── docs/
│   └── adr/            # Architecture Decision Records
├── how-we-work/        # Detailed process documentation
├── planning/           # Phase-by-phase implementation plan
├── scripts/            # PowerShell automation scripts
└── src/                # Example .NET applications *(coming soon)*
```

Each directory contains its own README with details about its contents and purpose.

---

## Documentation

### Core Documents

- **[How We Work](how-we-work.md)** — Our approach to structuring and coordinating work
- **[Agents Guide](agents.md)** — How AI agents use the Okyerema skill
- **[Planning](planning/README.md)** — Complete phase-by-phase implementation breakdown
- **[Architecture Decisions](docs/adr/README.md)** — Rationale for key technical choices

### For AI Agents

- **[Okyerema Skill](.github/skills/okyerema/SKILL.md)** — Project orchestration with GraphQL examples
- **[Agent Conventions](how-we-work/agent-conventions.md)** — Required behavioral patterns

### For Humans

- **[Getting Started](how-we-work/getting-started.md)** — New to GitHub Issues? Start here
- **[Glossary](how-we-work/glossary.md)** — Akan terms and their meanings

---

## Contributing

Akwaaba uses **issue-first workflow**:

1. **Create an issue** describing the work you want done
2. **AI agents respond** by creating pull requests with code changes
3. **Human reviewers** approve or request changes
4. **Agents iterate** based on feedback until ready to merge

**Direct commits to main are blocked.** All changes must go through this workflow.

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md) *(coming soon)*.

---

## Why "Akwaaba"?

We draw from Akan cultural concepts because they map beautifully to AI-assisted software development:

- **Akwaaba** means "Welcome" — this is where newcomers learn our way
- **Okyerema** (talking drummer) coordinates but doesn't do the work itself
- **Asafo** (warrior company) is stronger as a unit than any individual
- **Adwoma** means "work" — the actual tasks being done

These aren't just names. They're design principles.

**Learn more:** [Glossary of Akan Terms](how-we-work/glossary.md)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

Akwaaba builds on patterns from:

- **Gas Town** by Steve Yegge — The inspiration for agent-only commits
- **[copilot-media-plugins](https://github.com/anokye-labs/copilot-media-plugins)** — Lessons in agent orchestration
- **[amplifier-dotnet](https://github.com/anokye-labs/amplifier-dotnet)** — Architecture patterns for .NET

---

## Support

- **Issues:** [GitHub Issues](https://github.com/anokye-labs/akwaaba/issues)
- **Discussions:** [GitHub Discussions](https://github.com/anokye-labs/akwaaba/discussions)
- **Organization:** [Anokye Labs](https://github.com/anokye-labs)

---

*Built with 🤖 by AI agents, guided by 👥 humans, inspired by 🥁 Akan wisdom.*
