# 🏛️ Akwaaba

**Welcome to Continuous AI**

_PRs welcome — read [How We Work](how-we-work.md) to get started_

> _Akwaaba_ (ah-KWAH-bah) — "Welcome" in Akan/Twi

Akwaaba is the reference implementation of the **Anokye-Krom System**, a governance model for GitHub repositories where AI agents do all the coding. Inspired by Steve Yegge's [Gas Town](https://medium.com/@steve.yegge/why-gas-town-will-beat-agent-systems-6e0f0b1a76f0), adapted for the Anokye Labs philosophy.

**Status:** 🚧 Active Development — Foundation phase complete, governance implementation in progress

---

## What is Akwaaba?

Akwaaba serves three purposes:

1. **Reference Implementation** — Demonstrates how to build agent-first repositories
2. **Governance Model** — Documents the Anokye-Krom System principles and patterns
3. **Onboarding Hub** — Welcomes both humans and AI agents to the Anokye Labs way of working

**Key Features:** Agent-only commits • Issue-driven development • Hierarchical planning (Epics → Features → Tasks) • Project orchestration via the Okyerema skill • Full observability and validation

---

## The Anokye-Krom System

The Anokye-Krom System is our governance model for agent-first development. Named after the legendary Akan priest Okomfo Anokye, who unified the Asante kingdom.

### Core Principles

**Humans Plan, Agents Code** — Humans create issues and review PRs; agents write all code
**Issue-First Workflow** — No commit without an issue; no PR without acceptance criteria  
**Strict Enforcement** — Branch protection blocks direct commits; all changes via agents  
**Structural Integrity** — Use GitHub's native features correctly (issue types, sub-issues, projects)  
**Continuous Verification** — Health checks validate that the system reflects reality

### How It Works

```
┌─────────────────────────────────────────────────┐
│                     Human                        │
│              (Creates Issue)                     │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│                  Okyerema                        │
│             (Talking Drummer)                    │
│    Orchestrates agents via GitHub Issues         │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│                    Agent                         │
│          (Reads, Codes, Commits, PRs)            │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│                     Human                        │
│               (Reviews PR)                       │
└─────────────────────────────────────────────────┘
```

The **Okyerema** (talking drummer) keeps the **asafo** (team) in rhythm as they do **adwoma** (work). See [Glossary](how-we-work/glossary.md) for all Akan terms.

---

## Quick Start

**Prerequisites:** [GitHub CLI](https://cli.github.com/) (v2.0+) • [PowerShell](https://github.com/PowerShell/PowerShell) (v7.0+) • [.NET SDK](https://dotnet.microsoft.com/download) (8.0+, optional)

```bash
# Clone the repository
git clone https://github.com/anokye-labs/akwaaba.git
cd akwaaba

# Explore the documentation
ls how-we-work/        # Human-readable guides
ls .github/skills/     # Agent skills and instructions
ls planning/           # Implementation roadmap
```

**For AI agents:** Start with the **[Okyerema Skill](.github/skills/okyerema/SKILL.md)**  
**For humans:** Start with **[Getting Started](how-we-work/getting-started.md)**

---

## Project Structure

```
akwaaba/
├── .github/
│   ├── skills/                 # Agent skills (Okyerema, etc.)
│   └── workflows/              # CI/CD automation
├── docs/
│   └── adr/                    # Architecture Decision Records
├── how-we-work/                # Human-readable documentation
│   ├── getting-started.md      # New contributor guide
│   ├── our-way.md              # How we structure work
│   ├── glossary.md             # Akan terms and concepts
│   └── agent-conventions.md    # Behavioral conventions for AI agents
├── planning/                   # Implementation roadmap
│   ├── phase-1-foundation/     # Repository setup
│   ├── phase-2-governance/     # Enforcement infrastructure
│   ├── phase-3-agents/         # Agent fleet
│   ├── phase-4-dotnet/         # Example .NET application
│   ├── phase-5-documentation/  # Comprehensive docs
│   └── phase-6-validation/     # Testing and polish
├── scripts/                    # PowerShell automation scripts
├── agents.md                   # Agent quick reference
└── how-we-work.md              # Entry point for humans
```

---

## Documentation

### For Humans

- **[How We Work](how-we-work.md)** — Overview of our philosophy and approach
- **[Getting Started](how-we-work/getting-started.md)** — New to GitHub Issues? Start here
- **[Our Way](how-we-work/our-way.md)** — How we structure and coordinate work
- **[Glossary](how-we-work/glossary.md)** — Akan terms and concepts
- **[ADR Process](how-we-work/adr-process.md)** — How we document architectural decisions

### For AI Agents

- **[Agents](agents.md)** — Quick reference for agent behavior
- **[Okyerema Skill](.github/skills/okyerema/SKILL.md)** — Project orchestration skill
- **[Agent Conventions](how-we-work/agent-conventions.md)** — Behavioral requirements

### Planning & Architecture

- **[Planning Roadmap](planning/README.md)** — Complete implementation plan across 6 phases
- **[Architecture Decisions](docs/adr/)** — Technical decisions with rationale

---

## Contributing

Akwaaba follows an **issue-first workflow**:

1. **Create an issue** — Describe what needs to be done with clear acceptance criteria
2. **Agent picks it up** — An AI agent responds to the issue and creates a PR
3. **Review the PR** — Humans review the code and provide feedback
4. **Merge when ready** — Agent addresses feedback; humans merge

**Direct commits to main are blocked.** All changes must go through the agent-driven PR workflow.

Looking for something to work on? Check out issues labeled [`good-first-issue`](https://github.com/anokye-labs/akwaaba/labels/good-first-issue).

Want to understand how to contribute as a human? Read **[How We Work](how-we-work.md)**.

Want to contribute as an agent? Read **[Agent Conventions](how-we-work/agent-conventions.md)**.

---

## The Anokye Labs Ecosystem

- **Akwaaba** (this repo) — Welcome and governance reference
- **Ananse** — Agentic runtime engine (coming soon)
- **Okyeame** — Voice-first client (coming soon)

See [Glossary](how-we-work/glossary.md) for meanings.

---

## Why "Anokye-Krom"?

**Okomfo Anokye** was the legendary Akan priest who helped unify the Asante kingdom by bringing down the Golden Stool from the sky. **Krom** means "town" or "settlement" in Akan languages.

**Anokye-Krom** is our "AI Town" — a place where humans and agents work together under a unified governance model. Like Okomfo Anokye unified the Asante people, our system unifies human creativity with agent execution.

---

## License

License details coming soon — see [issue tracker](https://github.com/anokye-labs/akwaaba/issues) for updates.

---

## Acknowledgments

- Inspired by [Gas Town](https://medium.com/@steve.yegge/why-gas-town-will-beat-agent-systems-6e0f0b1a76f0) by Steve Yegge
- Built with patterns from [copilot-media-plugins](https://github.com/anokye-labs/copilot-media-plugins)
- Architecture informed by experience with amplifier-dotnet

---

## Contact & Support

- **Issues:** [GitHub Issues](https://github.com/anokye-labs/akwaaba/issues)
- **Discussions:** [GitHub Discussions](https://github.com/anokye-labs/akwaaba/discussions)
- **Organization:** [Anokye Labs](https://github.com/anokye-labs)

**Akwaaba** — Welcome to the future of continuous AI development.
