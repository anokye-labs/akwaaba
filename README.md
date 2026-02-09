# 👋 Akwaaba

**Welcome to Continuous AI Development**

Akwaaba (Akan/Twi: "Welcome") is a reference implementation of the **Anokye-Krom System** - a governance model for GitHub repositories where all commits originate from AI agents responding to issues created by humans.

## What is the Anokye-Krom System?

The Anokye-Krom System is inspired by Steve Yegge's Gas Town but designed specifically for Anokye Labs. It enforces:

- **Agent-only commits**: Humans create issues, agents create code
- **Issue-driven development**: All work tracked through GitHub issues  
- **Strict automation**: Branch protection and commit validation
- **Full observability**: Structured logging and monitoring
- **Safe operations**: Read-only by default

## Documentation

### Planning & Architecture
- **[Implementation Plan](planning/README.md)** - Complete breakdown of all phases and features
- **[Agents Guide](agents.md)** - How AI agents work in this repository (includes Okyerema skill documentation)
- **GOVERNANCE.md** _(coming soon)_ - Governance rules and enforcement
- **[Architecture Documentation](docs/)** - Technical specifications and ADRs

### How We Work
- **[How We Work](how-we-work.md)** - Overview of our coordination approach
- **[Getting Started](how-we-work/getting-started.md)** - Introduction to GitHub Issues
- **[Our Way](how-we-work/our-way.md)** - How we structure and coordinate work
- **[Agent Conventions](how-we-work/agent-conventions.md)** - Behavioral requirements for AI agents
- **[Glossary](how-we-work/glossary.md)** - Akan terms and concepts

## Quick Start

This is a reference implementation project. To explore:

1. Review the [Implementation Plan](planning/README.md)
2. Read about [How We Work](how-we-work.md)
3. Examine the [Agents Guide](agents.md) to understand AI agent coordination
4. Browse issues to see the system in action

## Contributing

All work in this repository follows the Anokye-Krom System:

1. **Create an issue** describing the work needed
2. **An AI agent** will be assigned and create a PR
3. **Review and merge** through the normal GitHub workflow

Direct commits to protected branches are blocked. All code changes must originate from agents responding to issues.

## License

MIT License - See [LICENSE](LICENSE) file for details.

---

*Built with the Anokye-Krom System at [Anokye Labs](https://github.com/anokye-labs)*
