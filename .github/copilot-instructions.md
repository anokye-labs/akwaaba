# Akwaaba

Reference implementation of the Anokye-Krom System — a governance model for GitHub repositories where AI agents do all the coding.

## Tech Stack
- Documentation-first repository (Markdown)
- PowerShell helper scripts in `.github/skills/`
- GitHub Actions for automation
- GitHub GraphQL API for issue management

## Project Structure
- `docs/` — Governance documentation and guides
- `how-we-work/` — Process documentation
- `planning/` — Planning artifacts
- `scripts/` — Automation scripts
- `src/` — Reference implementation code
- `.github/skills/` — Okyerema skill (project management guidance for agents)

## Conventions
- AI agents use the **Okyerema** skill for project management operations
- Skills are documentation, not tools — read `SKILL.md`, follow its patterns, call helper scripts
- Issue-first workflow: every PR must trace back to a GitHub Issue
- All issues must have a GitHub Issue Type (Epic, Feature, Task, Bug)
- Use GitHub sub-issues for parent-child relationships
- Use GraphQL API (not REST) for issue types, sub-issues, and relationships

## Important Notes
- See `agents.md` for skill usage patterns and helper scripts
- See `GOVERNANCE.md` for the Anokye-Krom governance model
- See `how-we-work.md` for contribution workflow
