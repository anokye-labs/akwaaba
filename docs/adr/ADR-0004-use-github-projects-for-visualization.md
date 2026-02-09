# ADR-0004: Use GitHub Projects for Workflow Visualization

**Status:** Accepted  
**Date:** 2026-02-09  
**Deciders:** Anokye Labs Team  
**Related:** ADR-0001 (Sub-Issues), ADR-0002 (GraphQL), ADR-0003 (Issue Types)

---

## Context

The Akwaaba repository uses a structured approach to work management with Epics, Features, and Tasks. We need a way to:

1. Visualize work across the entire repository lifecycle
2. Track status of issues through different stages
3. Provide multiple perspectives on work (by phase, by type, by status)
4. Reduce manual overhead in tracking and status updates
5. Enable both humans and AI agents to understand work state

GitHub provides several mechanisms for work tracking: Labels, Milestones, Projects Classic, and Projects (v2). We needed to decide which to use as our primary visualization and workflow management tool.

## Decision

We will use **GitHub Projects (v2)** as our primary workflow visualization tool, with the following architecture:

### What Projects Does

- **Visualizes** work through multiple views (backlog, current sprint, by phase, by type, blocked)
- **Tracks** metadata through custom fields (Status, Priority, Effort, Phase)
- **Automates** status transitions based on issue lifecycle events
- **Aggregates** cross-repository work (when expanded to org-level projects)

### What Projects Does NOT Do

- **Define relationships** — Use sub-issues API for parent-child hierarchy
- **Set issue types** — Use organization-level issue types via GraphQL
- **Replace workflows** — GitHub Actions handle complex automation
- **Store truth** — Issues are the source of truth; Projects are a view

### Key Architectural Decisions

1. **Custom Fields Mirror Issue Data**
   - Type field in Projects mirrors issue types (but doesn't replace them)
   - Phase field mirrors phase labels
   - This duplication is necessary because Projects cannot query issue types directly

2. **Automation Rules for Common Transitions**
   - Auto-add issues when created → Status: Backlog
   - Issue assigned → Status: In Progress
   - PR linked → Status: In Review
   - Issue closed → Status: Done
   - Label "blocked" added → Status: Blocked

3. **GraphQL for Complex Operations**
   - Custom field updates require GraphQL (gh CLI insufficient)
   - Bulk operations use GraphQL mutations
   - Project data queries via GraphQL API

4. **Multiple Views for Different Contexts**
   - Backlog view: Prioritized work ready to start
   - Current Sprint view: Active work in progress
   - By Phase view: Work organized by project phases
   - By Type view: Hierarchy visualization (Epics/Features/Tasks)
   - Blocked view: Issues requiring attention

## Alternatives Considered

### Alternative 1: Labels Only

**Pros:**
- Simple, built into GitHub
- Easy to query via API
- No additional tool to learn

**Cons:**
- Flat structure, no visualization
- Manual tracking of status
- No workflow automation
- We specifically avoid structural labels (see ADR-0003)

**Decision:** Rejected. Labels are for categorization, not workflow management.

### Alternative 2: GitHub Projects Classic

**Pros:**
- Established tool
- Simple Kanban board

**Cons:**
- Limited automation
- No custom fields
- Being deprecated by GitHub
- Cannot handle complex queries

**Decision:** Rejected. Projects v2 is the future and offers superior automation.

### Alternative 3: External Tool (Jira, Linear, etc.)

**Pros:**
- Rich feature set
- Advanced reporting
- Established workflows

**Cons:**
- Additional tool to maintain
- Synchronization overhead
- Not integrated with GitHub
- Costs money at scale

**Decision:** Rejected. We prefer native GitHub tools for tighter integration.

### Alternative 4: Issues + Milestones Only

**Pros:**
- Simple, minimal overhead
- Native GitHub features
- No custom fields needed

**Cons:**
- No visual workflow
- Limited perspectives
- Manual status tracking
- Poor for cross-cutting views (e.g., blocked issues)

**Decision:** Rejected. Insufficient visualization for complex work hierarchies.

## Consequences

### Positive

- **Visual clarity** — Multiple views provide different perspectives on work
- **Reduced manual work** — Automation handles common status transitions
- **Better prioritization** — Priority and effort fields enable smart sorting
- **Hierarchy visibility** — By Type view shows Epic → Feature → Task structure
- **Native integration** — No external tools, all within GitHub ecosystem
- **Flexible queries** — Custom fields enable filtering and grouping

### Negative

- **Duplication** — Some data (Type, Phase) must be mirrored from issues to Projects
- **GraphQL required** — Cannot use gh CLI for field updates
- **Learning curve** — Team must learn Projects v2 interface
- **Manual sync** — Type field must be updated if issue type changes
- **Limited export** — Project configuration cannot be exported as code

### Neutral

- **Separate system** — Projects are a view layer, not the source of truth
- **Automation limits** — Built-in workflows are simple; complex logic needs Actions
- **Rate limits** — GraphQL API rate limits apply to project operations

## Implementation Notes

### Phase 1: Core Setup

1. Create "Akwaaba Development" project
2. Configure custom fields (Status, Priority, Effort, Phase, Type)
3. Set up 5 core views (Backlog, Current Sprint, By Phase, By Type, Blocked)
4. Enable auto-add workflow

### Phase 2: Automation

1. Configure built-in status transitions
2. Implement GitHub Actions for complex rules
3. Set up project field sync workflow

### Phase 3: Documentation

1. Create comprehensive usage guide (docs/github-projects.md)
2. Document custom fields and their purpose
3. Explain automation rules
4. Add troubleshooting guide

### Future Enhancements

- Org-level project for cross-repository work tracking
- Slack notifications for project events
- Custom GitHub Actions for advanced automation
- Weekly summary reports of completed work

## Monitoring

We will measure success by:

- **Adoption rate** — Are team members using project views?
- **Automation effectiveness** — How many status updates are automated vs. manual?
- **Issue visibility** — Can anyone quickly find what they need?
- **Hierarchy clarity** — Is the Epic → Feature → Task structure clear?

## Related Decisions

- **ADR-0001** — Sub-issues API defines relationships, Projects visualizes them
- **ADR-0002** — GraphQL required for all Project field updates
- **ADR-0003** — Issue types set via GraphQL, mirrored in Project Type field

## References

- [GitHub Projects Documentation](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [Okyerema Projects Reference](../.github/skills/okyerema/references/projects.md)
- [GitHub Projects Guide](../docs/github-projects.md)

---

**Supersedes:** None  
**Superseded by:** None (current)
