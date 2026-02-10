# How We Work

At Anokye Labs, the **Okyerema** (talking drummer) keeps our asafo (team) in rhythm. Whether you're a human contributor or an AI agent, understanding how we coordinate adwoma (work) is essential.

## The Rhythm

We use GitHub Issues and Projects as our primary coordination mechanism. Our approach is opinionated — we've learned from mistakes and encoded those lessons into a system that works for both humans and AI agents.

### The Instruments

| Tool | Purpose | Who Uses It |
|------|---------|-------------|
| **Issue Types** | Define what kind of work something is | Everyone |
| **Tasklists** | Connect work into hierarchies | Agents (via GraphQL) |
| **Projects** | Visualize and track progress | Humans + Agents |
| **Labels** | Categorize for filtering | Sparingly |

## Guides

### For Everyone
- **[Getting Started](./how-we-work/getting-started.md)** — New to GitHub Issues? Start here
- **[Our Way](./how-we-work/our-way.md)** — How we structure and coordinate work
- **[Glossary](./how-we-work/glossary.md)** — Akan terms and concepts we use
- **[ADR Process](./how-we-work/adr-process.md)** — How we document architectural decisions

### For Agents
- **[Agent Setup Guide](./how-we-work/agent-setup.md)** — How to register and configure AI agents
- **[Agent Behavior Conventions](./how-we-work/agent-conventions.md)** — Required behavioral conventions for agents
- **[Okyerema Skill](/.github/skills/okyerema/SKILL.md)** — The agent skill with GraphQL examples and helper scripts

## Quick Summary

### Issue Hierarchy

We structure work in up to 3 levels:

```
Epic → Feature → Task
```

**Epics** are big initiatives (like a full phase of work). **Features** group related tasks into cohesive deliverables. **Tasks** are the actual work items someone (or some agent) completes.

For simple work, we skip Features:

```
Epic → Task
```

### Issue Types

We use GitHub's **organization-level issue types** — not labels, not title prefixes. The types are:

- **Epic** — A large initiative
- **Feature** — A cohesive piece of functionality
- **Task** — A specific work item
- **Bug** — Something broken

### Labels

We use labels **sparingly** and only for categorization:
- ✅ `documentation`, `security`, `typescript`
- ❌ `epic`, `task`, `in-progress`, `blocked-by-7`

If you're tempted to create a structural label, you're using the wrong tool.

## The Okyerema

The Okyerema skill (`.github/skills/okyerema/`) contains everything an AI agent needs to manage our project structure. It includes:

- GraphQL queries and mutations for all operations
- PowerShell helper scripts for common tasks
- Reference guides for issue types, relationships, projects, and labels
- Error handling and troubleshooting

When the Okyerema beats the drum, the asafo moves in formation.

---

*Continue to [Getting Started](./how-we-work/getting-started.md) →*
