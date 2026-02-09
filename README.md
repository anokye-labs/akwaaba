# 👋 Akwaaba

**Welcome to Agent-Driven Development**

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)
![Status](https://img.shields.io/badge/status-in%20development-yellow)

> **Project Status**: Akwaaba is currently in active development. The system is functional but evolving as we refine the Anokye-Krom governance model.

## What is Akwaaba?

**Akwaaba** (Akan/Twi: "Welcome") is a reference implementation of the **Anokye-Krom System** — a governance model for GitHub repositories where AI agents handle all code commits in response to human-created issues.

Inspired by Steve Yegge's Gas Town concept but distinctly Anokye Labs, Akwaaba demonstrates a new way of building software where:

- **Humans define the work** through GitHub issues
- **AI agents execute the work** by creating commits and pull requests
- **Automated systems enforce governance** to ensure quality and traceability
- **Full observability** provides transparency into every decision

### Key Capabilities

- **Agent-Only Commits**: Direct commits are blocked; only AI agents can push code
- **Issue-Driven Development**: Every commit traces back to a GitHub issue
- **Hierarchical Work Breakdown**: Epics → Features → Tasks using GitHub's sub-issues API
- **Project Orchestration**: PowerShell scripts coordinate work across the agent fleet
- **Safe Operations**: Read-only by default with write operations via validated outputs

## The Anokye-Krom System

The Anokye-Krom System is the governance framework that powers Akwaaba. Named after the legendary Ashanti golden stool (the "Krom"), it establishes rules and structures that create harmony between human oversight and AI execution.

### Core Principles

1. **Agent-Only Commits**
   - Branch protection rules prevent direct human commits
   - All code changes come from authenticated AI agents
   - Commit messages follow conventional commit format

2. **Issue-Driven Development**
   - Every change originates from a GitHub issue
   - Issues use organization-level types (Epic, Feature, Task, Bug)
   - Dependencies tracked through GitHub's native sub-issues API

3. **Strict Enforcement**
   - Automated validation of commit authorship
   - CI/CD pipelines verify issue linkage
   - Status checks ensure agent authentication

4. **Hierarchical Decomposition**
   - Complex work broken into Epic → Feature → Task structure
   - Simple work uses Epic → Task pattern
   - All relationships managed via GraphQL API

5. **Observability by Default**
   - Structured logging captures all operations
   - Tracing connects issues to commits to deployments
   - Dashboard provides real-time visibility

6. **Safe Operations**
   - Read operations unrestricted
   - Write operations through validated safe-output processing
   - Rollback capabilities for every change

## Okyerema: The Coordination Layer

The **Okyerema** (Akan: "talking drummer") is the coordination skill that teaches AI agents how to manage project structure and orchestrate work.

Located in `.github/skills/okyerema/`, the Okyerema skill provides:

- **GraphQL Operations**: Queries and mutations for issues, projects, and relationships
- **Helper Scripts**: PowerShell automation for common tasks
- **Reference Guides**: Detailed documentation for every operation
- **Error Handling**: Troubleshooting and recovery patterns

When agents need to create issues, build hierarchies, or update project boards, they read the Okyerema skill and call its helper scripts. The Okyerema beats the drum, and the asafo (team) moves in formation.

Learn more: [agents.md](./agents.md) | [Okyerema Skill](./.github/skills/okyerema/SKILL.md)

## Project Structure

```text
akwaaba/
├── .github/
│   ├── skills/
│   │   └── okyerema/          # Project orchestration skill for agents
│   └── workflows/             # GitHub Actions automation
├── docs/
│   └── adr/                   # Architecture Decision Records
├── how-we-work/               # Human-readable process documentation
├── planning/                  # Phase-based implementation plan
├── scripts/                   # PowerShell automation scripts
└── agents.md                  # Agent instructions and conventions
```

### Directory Descriptions

- **.github/skills/okyerema/** — The Okyerema skill teaches agents project management via GraphQL
- **.github/workflows/** — CI/CD automation and governance enforcement
- **docs/adr/** — Architecture Decision Records documenting key technical choices
- **how-we-work/** — Human-readable guides for working with the Anokye-Krom System
- **planning/** — Phase-based breakdown of Akwaaba implementation features
- **scripts/** — PowerShell scripts for issue management, project coordination, and PR workflows

For architectural details, see [docs/adr/README.md](./docs/adr/README.md).

## Quick Start

### Prerequisites

- Git
- PowerShell 7+ (cross-platform)
- GitHub CLI (`gh`)
- GitHub personal access token with `repo`, `project`, and `read:org` scopes

### Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/anokye-labs/akwaaba.git
   cd akwaaba
   ```

2. **Review the planning documents**

   ```bash
   # See the overall implementation plan
   cat planning/README.md
   
   # Explore phase-based breakdown
   ls planning/phase-*/
   ```

3. **Try the helper scripts**

   ```bash
   # View available scripts
   ls scripts/*.ps1
   
   # Get help on any script
   Get-Help ./scripts/Get-NextAgentWork.ps1 -Detailed
   ```

4. **Read the agent conventions**

   ```bash
   cat agents.md
   ```

For detailed setup instructions, see [how-we-work/getting-started.md](./how-we-work/getting-started.md).

## Documentation

- **[How We Work](./how-we-work.md)** — Human-readable overview of our processes
- **[Agents Guide](./agents.md)** — Instructions for AI agents working in this repository
- **[Okyerema Skill](./.github/skills/okyerema/SKILL.md)** — Project orchestration skill with GraphQL examples
- **[ADR Index](./docs/adr/README.md)** — Architecture Decision Records
- **[Planning](./planning/README.md)** — Phase-based implementation breakdown

Additional documentation:

- [Getting Started](./how-we-work/getting-started.md) — Setup and first steps
- [Our Way](./how-we-work/our-way.md) — How we structure and coordinate work
- [Glossary](./how-we-work/glossary.md) — Akan terms and concepts
- [Agent Conventions](./how-we-work/agent-conventions.md) — Behavioral guidelines for AI agents

## Contributing

Akwaaba follows the **Anokye-Krom System**, which means all code contributions must come from AI agents responding to GitHub issues.

### How to Contribute

1. **Create a GitHub Issue**
   - Describe the problem, feature, or improvement
   - Use the appropriate issue type (Epic, Feature, Task, Bug)
   - Link to parent issues if part of a larger effort

2. **Wait for Agent Assignment**
   - The Okyerema coordination system will assign the issue to an AI agent
   - The agent will create a pull request with the implementation

3. **Review the Pull Request**
   - Human reviewers provide feedback through PR comments
   - Agents address feedback by updating the PR
   - PRs merge automatically when all checks pass and reviews approve

### Direct Commits Are Blocked

Branch protection rules prevent direct commits to main branches. This is intentional — it ensures:

- Every change has traceability to an issue
- All code goes through the agent workflow
- Quality standards are consistently enforced

Looking for a good first issue? Search for issues labeled [`good first issue`](https://github.com/anokye-labs/akwaaba/labels/good%20first%20issue).

## Research & Inspiration

Akwaaba draws inspiration from multiple sources in the agent-driven development space.

### Pattern Influences

- **copilot-media-plugins** — Patterns for organizing agent instructions (reference)
- **amplifier-dotnet** — Early experimentation with agent-first development (reference)

These projects helped shape our thinking on skill-based architecture and agent coordination patterns.

## License

Akwaaba is released under the **MIT License**.

```text
MIT License

Copyright (c) 2025 Anokye Labs

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Acknowledgments

Special thanks to:

- Steve Yegge for the Gas Town concept that inspired this exploration
- The GitHub team for building powerful APIs (especially sub-issues and Projects v2)
- The Anokye Labs community for feedback and experimentation

## Contact & Support

- **GitHub Issues**: [github.com/anokye-labs/akwaaba/issues](https://github.com/anokye-labs/akwaaba/issues)
- **Website**: [anokyelabs.com](https://anokyelabs.com) *(coming soon)*
- **Email**: <hello@anokyelabs.com>

---

**Akwaaba** — Welcome to the future of software development. 🚀
