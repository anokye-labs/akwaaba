# Agent Authentication Guide

This guide explains how AI agents authenticate with GitHub in Anokye Labs repositories.

## Overview

Anokye Labs uses **GitHub Apps** for all agent authentication. Each AI agent has a dedicated GitHub App identity with granular permissions and short-lived tokens.

**Key principle:** Every automated action should be attributable to a specific agent with clear identity and audit trail.

## Authentication Architecture

### Components

1. **GitHub App** - First-class GitHub entity representing the agent
2. **Bot Identity** - Username with `[bot]` suffix (e.g., `okyerema[bot]`)
3. **Private Key** - RSA key pair for generating JWTs
4. **Installation Access Token** - Short-lived (1 hour) token for API operations
5. **Installation ID** - Unique identifier for app installation on org/repo

### Why GitHub Apps?

- **Security**: Short-lived tokens (1 hour), fine-grained permissions
- **Auditability**: Clear bot identity in commits, PRs, and issues
- **Scalability**: Higher rate limits (5,000+ req/hr for orgs)
- **Cost**: No paid seats consumed
- **Resilience**: Not tied to individual user accounts

See [ADR-0004](./adr/ADR-0004-use-github-apps-for-agent-authentication.md) for the full decision rationale.

## Authentication Flow

### Step 1: App Creation (One-time)

1. Navigate to GitHub Settings → Developer Settings → GitHub Apps
2. Click "New GitHub App"
3. Configure:
   - **Name**: Descriptive agent name (e.g., "Okyerema Issue Manager")
   - **Homepage URL**: Repository URL
   - **Webhook**: Disable if not needed
   - **Permissions**: Select minimal required permissions
     - Repository permissions: Issues (read/write), Pull Requests (read/write), etc.
     - Organization permissions: Members (read), etc.
   - **Where can this app be installed?**: "Only on this account" for Anokye Labs

4. Generate private key (downloaded as `.pem` file)
5. Note the App ID (shown on app settings page)

### Step 2: App Installation

1. On the app settings page, click "Install App"
2. Select organization or repositories
3. Choose:
   - **All repositories** - For org-wide agents
   - **Selected repositories** - For specialized agents
4. Complete installation
5. Note the Installation ID from URL: `https://github.com/organizations/{org}/settings/installations/{installation_id}`

### Step 3: Token Generation (Per Operation)

Agents generate tokens programmatically:

```python
import jwt
import time
import requests

# Load from secure storage
APP_ID = "123456"
INSTALLATION_ID = "12345678"
PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
...
-----END RSA PRIVATE KEY-----"""

# 1. Generate JWT (valid 10 minutes)
payload = {
    "iat": int(time.time()),
    "exp": int(time.time()) + 600,  # 10 minutes
    "iss": APP_ID
}
jwt_token = jwt.encode(payload, PRIVATE_KEY, algorithm="RS256")

# 2. Exchange JWT for installation access token
headers = {
    "Authorization": f"Bearer {jwt_token}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28"
}
response = requests.post(
    f"https://api.github.com/app/installations/{INSTALLATION_ID}/access_tokens",
    headers=headers
)
installation_token = response.json()["token"]

# 3. Use installation token for API operations
api_headers = {
    "Authorization": f"Bearer {installation_token}",
    "Accept": "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28"
}
# Make API calls with api_headers
```

### Step 4: API Operations

Use the installation access token for all GitHub API operations:

```python
# REST API
response = requests.get(
    "https://api.github.com/repos/anokye-labs/akwaaba/issues",
    headers=api_headers
)

# GraphQL API
response = requests.post(
    "https://api.github.com/graphql",
    headers=api_headers,
    json={"query": query, "variables": variables}
)

# Git operations (if Contents permission granted)
# Use token as password with https://x-access-token:{token}@github.com/...
```

### Step 5: Token Refresh

Tokens expire after 1 hour. Implement automatic refresh:

```python
class GitHubAppAuth:
    def __init__(self, app_id, installation_id, private_key):
        self.app_id = app_id
        self.installation_id = installation_id
        self.private_key = private_key
        self.token = None
        self.token_expires_at = 0
    
    def get_token(self):
        # Refresh if expired or expiring soon (5 min buffer)
        if time.time() > self.token_expires_at - 300:
            self.refresh_token()
        return self.token
    
    def refresh_token(self):
        jwt_token = self._generate_jwt()
        self.token = self._exchange_jwt_for_token(jwt_token)
        self.token_expires_at = time.time() + 3600  # 1 hour
```

## Agent Registration Process

### Phase 1: Manual Registration (Current)

**For Anokye Labs maintainers:**

1. **Request**: Team member identifies need for new agent
2. **Planning**: Define agent responsibilities and required permissions
3. **Creation**:
   - Create GitHub App (see Step 1 above)
   - Generate and store private key securely
   - Install app on required repositories
4. **Documentation**:
   - Record agent in `.github/approved-agents.json` (when implemented)
   - Document agent purpose and permissions
5. **Credential Storage**:
   - Store App ID, Installation ID, and private key as GitHub Secrets
   - Never commit credentials to repository

**Checklist:**
- [ ] GitHub App created with descriptive name
- [ ] Minimal necessary permissions configured
- [ ] Private key generated and stored securely
- [ ] App installed on target repositories
- [ ] App ID and Installation ID documented
- [ ] Credentials stored in GitHub Secrets
- [ ] Agent added to approved agents list
- [ ] Team notified of new agent

### Phase 2: Self-Service Registration (Future)

**Vision for automated agent registration:**

1. **Request**: Developer creates issue using "Agent Request" template
   - Agent name and description
   - Required permissions
   - Target repositories
   - Justification

2. **Approval**: Automated workflow routes to security team
   - Review permissions request
   - Validate justification
   - Approve or request changes

3. **Provisioning**: Automated workflow creates resources
   - Creates GitHub App via GitHub API
   - Applies permission template
   - Installs app on specified repositories
   - Generates and stores credentials
   - Updates approved agents list

4. **Notification**: Requestor receives credentials
   - Secure delivery via GitHub Secrets
   - Documentation link
   - Usage examples

**Benefits:**
- Faster agent onboarding
- Consistent permission templates
- Automatic audit trail
- Reduced manual configuration errors

## Security Best Practices

### Credential Management

1. **Never commit credentials**
   - Store in GitHub Secrets, not repository
   - Use environment variables in code
   - Rotate private keys quarterly

2. **Minimal permissions**
   - Grant only necessary repository permissions
   - Use read-only when possible
   - Limit repository access to required repos

3. **Token handling**
   - Never log tokens
   - Don't pass tokens in URLs
   - Use HTTPS for all API calls
   - Implement token refresh before expiration

4. **Monitoring**
   - Review app activity logs regularly
   - Alert on unexpected API usage
   - Audit permissions quarterly
   - Monitor for compromised credentials

### Permission Templates

Define standard permission sets for common agent types:

**Read-Only Agent:**
- Issues: read
- Pull Requests: read
- Contents: read

**Issue Manager Agent:**
- Issues: read, write
- Pull Requests: read
- Contents: read

**PR Automation Agent:**
- Issues: read, write
- Pull Requests: read, write
- Contents: read, write
- Workflows: read, write

**Full Automation Agent:**
- Issues: read, write
- Pull Requests: read, write
- Contents: read, write
- Workflows: read, write
- Projects: read, write

## Troubleshooting

### "Bad credentials" error

**Cause**: JWT or installation token expired or invalid

**Solution:**
1. Verify App ID is correct
2. Check private key format (PEM with proper headers)
3. Ensure JWT expiration is in the future
4. Regenerate installation token

### "Resource not accessible by integration"

**Cause**: App lacks required permissions

**Solution:**
1. Review app permissions in GitHub App settings
2. Add required permission
3. User must re-approve installation if permissions increased
4. Regenerate token after permission change

### "Not Found" when accessing resource

**Cause**: App not installed on target repository

**Solution:**
1. Verify installation includes target repository
2. Check Installation ID is correct
3. Ensure repository name is correct in API call

### Rate limit exceeded

**Cause**: Too many API requests

**Solution:**
1. Implement exponential backoff
2. Cache responses when possible
3. Use GraphQL to reduce request count
4. Check rate limit headers: `X-RateLimit-Remaining`

### Token refresh failures

**Cause**: JWT generation or exchange issues

**Solution:**
1. Check system time is synchronized (JWT uses timestamps)
2. Verify network connectivity to api.github.com
3. Implement retry logic with exponential backoff
4. Log errors for debugging

## Reference Implementation

For a complete reference implementation, see:
- `scripts/AgentRunner/AgentRunner.psm1` (when implemented)
- Agent examples in `.github/agents/` (when implemented)

## Further Reading

- [GitHub Docs: Authenticating with a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app)
- [GitHub Docs: GitHub App permissions](https://docs.github.com/en/rest/overview/permissions-required-for-github-apps)
- [ADR-0004: Use GitHub Apps for agent authentication](./adr/ADR-0004-use-github-apps-for-agent-authentication.md)
- [Best practices for creating GitHub Apps](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/best-practices-for-creating-a-github-app)

---

**Last Updated:** 2026-02-10  
**Maintainer:** Anokye Labs Team
