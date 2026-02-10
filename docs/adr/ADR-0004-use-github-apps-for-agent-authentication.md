# ADR-0004: Use GitHub Apps for Agent Authentication

**Status:** Accepted  
**Date:** 2026-02-10  
**Deciders:** Anokye Labs Team  
**Tags:** authentication, agents, security, automation

## Context

The Akwaaba project requires a secure, scalable authentication mechanism for AI agents that will automate repository operations such as creating issues, managing pull requests, updating documentation, and executing workflows. We need to decide between three primary authentication approaches:

1. **GitHub Apps** - First-class GitHub entities with granular permissions and bot identity
2. **Bot Users** - Dedicated user accounts acting as service accounts
3. **Service Accounts (Machine Users)** - Regular user accounts with Personal Access Tokens (PATs)

### Requirements

Our agent authentication solution must:
- Provide secure, auditable access to repository operations
- Support granular permissions to limit blast radius
- Scale across multiple repositories and organizations
- Not consume paid user seats unnecessarily
- Survive personnel changes (not tied to individual users)
- Use short-lived tokens to minimize security risks
- Clearly identify automated actions (vs human actions)
- Support future self-service agent registration

### Current Landscape (2024)

GitHub's authentication ecosystem has evolved significantly:
- **GitHub Apps** are now the recommended approach for automation
- **Installation access tokens** provide short-lived (1 hour), scoped authentication
- **Rate limits** for GitHub Apps scale with organization size (5,000+ requests/hour)
- **Bot identity** (`[bot]` suffix) clearly distinguishes automated actions
- **Service accounts** are considered legacy for organizational automation

## Decision

**We will use GitHub Apps as the primary authentication mechanism for all AI agents in Anokye Labs repositories.**

Each AI agent will be represented by a dedicated GitHub App with:
- A unique bot identity (e.g., `okyerema[bot]`, `adwoma-runner[bot]`)
- Granular, minimal permissions based on agent responsibilities
- Installation access tokens for short-lived authentication
- Clear audit trails through GitHub's app activity logs

### Authentication Flow

1. **App Setup** (One-time per agent)
   - Create GitHub App via Developer Settings
   - Configure permissions (read/write issues, PRs, contents, etc.)
   - Generate and securely store private key
   - Install app on target repositories/organization

2. **Token Generation** (Per operation)
   - Agent generates JWT using app private key (valid 10 minutes)
   - Exchange JWT for installation access token via GitHub API
   - Installation token valid for 1 hour with app's scoped permissions

3. **API Operations**
   - Use installation access token in Authorization header
   - Token identifies agent via bot username
   - All actions logged with agent identity

4. **Token Renewal**
   - Agents automatically refresh tokens before expiration
   - No manual intervention required

### Agent Registration Process

**Phase 1: Manual Registration** (Current)
1. Team creates GitHub App for new agent
2. Configure permissions based on agent requirements
3. Install app on repositories
4. Store app credentials securely (GitHub Secrets)
5. Document agent in repository records

**Phase 2: Self-Service Registration** (Future)
1. Developer requests new agent via issue template
2. Automated workflow provisions GitHub App
3. Permissions template applied based on agent type
4. App installed with approval workflow
5. Credentials generated and stored automatically

## Consequences

### Positive Consequences

- **Security**: Short-lived tokens (1 hour) minimize exposure window
- **Auditability**: Clear bot identity in all automated actions
- **Scalability**: Higher rate limits that scale with organization
- **Isolation**: Each agent has independent permissions and identity
- **Cost**: GitHub Apps don't consume paid user seats
- **Resilience**: Not tied to individual user accounts
- **Granularity**: Fine-grained permission control per repository and resource
- **Industry standard**: Aligned with GitHub's recommended practices

### Negative Consequences

- **Setup complexity**: More initial configuration than PATs
- **Token management**: Requires JWT generation and token refresh logic
- **Learning curve**: Team must understand GitHub App authentication flow
- **Private key security**: Must securely store and rotate private keys

### Risks

- **Private key compromise**: If leaked, attacker gains agent permissions
  - *Mitigation*: Store keys in encrypted secrets, rotate regularly, monitor access
- **Permission escalation**: Overly broad permissions could be exploited
  - *Mitigation*: Follow principle of least privilege, audit permissions quarterly
- **Token refresh failures**: Could interrupt agent operations
  - *Mitigation*: Implement retry logic, monitoring, and alerts

## Alternatives Considered

### Alternative 1: Service Account with Personal Access Token

A dedicated "bot" user account with a long-lived PAT for authentication.

**Why not chosen:**
- Consumes paid user seat in private repositories/organizations
- PATs are long-lived, increasing security risk if leaked
- Broader permissions, harder to scope precisely
- If maintainer leaves, automation can break
- Unclear identity (appears as regular user)
- Lower rate limits compared to GitHub Apps
- Considered legacy approach by GitHub

### Alternative 2: User Account Bot Users (Fake Users)

Creating dedicated user accounts to represent bots.

**Why not chosen:**
- Against GitHub Terms of Service for automated accounts
- Consumes paid seats
- No advantage over GitHub Apps
- Poor auditability (appears as human user)
- No special rate limit benefits
- Requires manual management

### Alternative 3: GITHUB_TOKEN (Actions-only)

Use GitHub Actions' built-in `GITHUB_TOKEN` for all automation.

**Why not chosen:**
- Limited to workflows running in the same repository
- Cannot operate across multiple repositories
- Limited permissions (cannot trigger other workflows)
- Not suitable for external agents or cross-repo automation
- Works well for simple CI/CD but insufficient for our use case

## References

- [GitHub Docs: Deciding when to build a GitHub App](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/deciding-when-to-build-a-github-app)
- [GitHub Docs: Authenticating as a GitHub App installation](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation)
- [GitHub Docs: Generating an installation access token](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [GitHub Docs: Differences between GitHub Apps and OAuth apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/differences-between-github-apps-and-oauth-apps)
- [Demystifying GitHub Apps: Using GitHub Apps to Replace Service Accounts](https://josh-ops.com/posts/github-apps/)
- Issue: `planning/phase-2-governance/03-workflow-agent-auth.md` - Task 1
- Related ADRs: ADR-0001, ADR-0002, ADR-0003

---

## Notes

- This decision establishes the foundation for agent authentication across Anokye Labs
- Implementation will be phased: manual registration first, then self-service
- Each agent should have minimal necessary permissions
- Regular security audits of agent permissions required
- Private keys must be rotated quarterly
- This ADR may be superseded if GitHub introduces new authentication mechanisms
