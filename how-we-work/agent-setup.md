# Agent Setup Guide

This repository follows an **agent-only commit policy**. All commits must be created by approved automation agents, not by humans directly.

## Why Agent-Only Commits?

The agent-only policy provides several benefits:

- **Consistency**: Agents follow established patterns and conventions
- **Quality**: Automated validation and testing before commits
- **Traceability**: Clear audit trail of all changes
- **Scalability**: Reduces manual review burden
- **Security**: Reduces risk of human error or malicious commits

## Approved Agents

The list of approved agents is maintained in [`.github/approved-agents.json`](../.github/approved-agents.json).

Currently approved agents include:

- **GitHub Copilot Workspace** - AI-powered code generation and editing
- **GitHub Actions** - Automated workflows and CI/CD
- **Dependabot** - Automated dependency updates

## Setting Up an Agent

### Option 1: GitHub Copilot Workspace

GitHub Copilot Workspace is recommended for most development work.

1. **Enable Copilot Workspace**
   - Ensure you have GitHub Copilot subscription
   - Access Copilot Workspace from the GitHub UI
   - Or use the Copilot CLI tools

2. **Create Changes**
   - Describe the changes you want to make
   - Copilot Workspace will generate the code
   - Review and approve the generated changes

3. **Submit Pull Request**
   - Copilot creates commits as `copilot-swe-agent[bot]`
   - These commits are automatically approved
   - The PR can proceed through normal review

### Option 2: GitHub Actions

Use GitHub Actions for automated workflows.

1. **Create Workflow File**
   ```yaml
   name: My Automation
   
   on:
     schedule:
       - cron: '0 0 * * *'
   
   jobs:
     update:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         
         - name: Make changes
           run: |
             # Your automation logic here
             
         - name: Create Pull Request
           uses: peter-evans/create-pull-request@v5
           with:
             token: ${{ secrets.GITHUB_TOKEN }}
             commit-message: 'chore: automated update'
             title: 'Automated Update'
   ```

2. **Commits from Actions**
   - Commits will be created as `github-actions[bot]`
   - Automatically approved by the agent auth workflow

### Option 3: Custom Agent

For specialized automation needs:

1. **Request Approval**
   - Open an issue using the agent approval request template
   - Provide details about your agent and use case
   - Wait for repository admin approval

2. **Add to Allowlist**
   - After approval, admin will add your agent to `.github/approved-agents.json`
   - Include: username, type, app ID, description

3. **Configure Agent**
   - Set up your agent with appropriate credentials
   - Ensure it commits with the approved username
   - Test with a draft PR before going live

## Emergency Bypass

In exceptional circumstances (critical hotfix, infrastructure emergency), the agent requirement can be bypassed:

1. **Apply Emergency Label**
   - Add the `emergency-merge` label to your PR
   - Requires write permissions on the repository

2. **Provide Justification**
   - Comment on the PR explaining why bypass is needed
   - Tag repository administrators

3. **Post-Emergency Review**
   - Emergency bypasses are logged and audited
   - Follow up to ensure proper process is restored

## Troubleshooting

### "Unauthorized commits detected"

**Problem**: Your commits are not recognized as coming from an approved agent.

**Solution**:
1. Verify you're using an approved agent
2. Check that the agent username matches the allowlist exactly
3. Ensure the agent is properly authenticated

### "Agent not in allowlist"

**Problem**: You want to use an agent that isn't approved yet.

**Solution**:
1. File an agent approval request issue
2. Provide use case and justification
3. Wait for admin approval
4. Use an already-approved agent in the meantime

### "Emergency bypass not working"

**Problem**: The `emergency-merge` label isn't bypassing validation.

**Solution**:
1. Verify the label name is exactly `emergency-merge`
2. Ensure you have permissions to apply labels
3. Check that the workflow is running after the label is applied
4. Re-run the workflow if needed

## Best Practices

1. **Use Copilot Workspace for most changes**
   - Fastest and easiest for development work
   - Great for bug fixes and feature development

2. **Use GitHub Actions for scheduled tasks**
   - Dependency updates
   - Regular maintenance
   - Automated reports

3. **Document automation workflows**
   - Keep workflow files well-commented
   - Document any complex automation logic
   - Include runbooks for maintenance

4. **Test before production**
   - Use draft PRs to test new automation
   - Verify commit authorship is correct
   - Ensure validation passes

5. **Monitor and maintain**
   - Review agent activity regularly
   - Keep approved agents list up to date
   - Remove unused agents

## Getting Help

- **Questions**: Open a discussion in the repository
- **Agent Requests**: Use the agent approval request template
- **Issues**: Report bugs with the validation workflow
- **Documentation**: Suggest improvements via PR

## Related Documentation

- [Governance Model](../GOVERNANCE.md)
- [Contributing Guide](../CONTRIBUTING.md)
- [Workflow Automation](../.github/workflows/README.md)
- [Repository Conventions](agent-conventions.md)
