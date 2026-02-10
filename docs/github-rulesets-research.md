# GitHub Repository Rulesets Research

**Research Date:** February 2025  
**Status:** Complete

## Executive Summary

GitHub repository rulesets represent a modern, flexible approach to repository governance that supersedes legacy branch protection rules. Rulesets provide organization-wide policy enforcement, layered security models, granular bypass controls, and enhanced visibility for developers and auditors.

## What Are GitHub Rulesets?

GitHub rulesets allow repository and organization administrators to define, bundle, and enforce multiple policies across branches and tags. Unlike legacy branch protection rules that apply to individual branches, rulesets:

- Support both branches and tags
- Can be applied at repository, organization, or enterprise levels
- Allow multiple rulesets to layer on the same target (strictest rule wins)
- Provide transparent visibility to all users with read access
- Support "Evaluate" mode for testing rules before enforcement

## Key Capabilities

### 1. Scope and Governance

- **Multi-level enforcement**: Repository, organization, and enterprise levels
- **Scalability**: Up to 75 rulesets per repository and 75 organization-wide rulesets
- **Pattern matching**: Use fnmatch syntax to target branches/tags (e.g., `main`, `release/*`, `v*`)
- **Organization-wide availability**: Now available on GitHub Team plans (as of June 2025), not just Enterprise

### 2. Rule Types and Enforcement

#### Branch & Tag Protection Rules
- Require pull request reviews before merging
- Require status checks to pass
- Require signed commits
- Block force pushes
- Restrict branch/tag deletions
- Require linear commit history
- Restrict who can push/merge

#### Push Rulesets
- Block specific file types or extensions
- Enforce file path length restrictions
- Enforce file size limits
- Block files matching specific patterns
- Apply across fork networks

#### Commit Metadata Rules
- Require commit messages to match patterns (e.g., `ISSUE-\d+` for ticket references)
- Require author email to match patterns (e.g., `.*@company\.com`)
- Restrict committing users by name or email
- Require cryptographically signed commits

#### Branch/Tag Naming Rules
- Enforce naming conventions for branches/tags
- Restrict creation, deletion, or renaming based on patterns

### 3. Layering and Rule Resolution

- Multiple rulesets can apply to the same branch/tag simultaneously
- When conflicts occur, the **strictest rule always wins**
- More predictable than legacy branch protection priority/specificity model

### 4. Enforcement Modes

- **Active**: Rules are immediately enforced
- **Evaluate**: Dry-run mode for testing; violations are logged but not blocked
- **Disabled**: Rules remain defined but not enforced

### 5. Bypass Controls

Granular bypass permissions allow specific users, teams, or GitHub Apps to bypass rules:
- **Bypass**: Explicit action logged in audit trail (traditional "break glass")
- **Exempt**: Silent bypass for trusted automation (recently introduced)
- More fine-grained than legacy "admin bypass everything" model

### 6. Visibility and Auditability

- All users with read access can view active rulesets
- Ruleset history retained for 180 days
- Changes tracked in audit logs
- Import/export as JSON for version control and sharing

### 7. Advanced Features

- **Filter-based targeting**: Use custom repository properties and search syntax
- **Merge queue integration**: Merge queue bot can be added as bypass actor
- **API and automation**: Full REST and GraphQL API support
- **Custom properties**: Tag repositories with metadata (e.g., `is_production`) for automated management

## Rulesets vs Legacy Branch Protection

| Feature | Branch Protection Rules | Rulesets |
|---------|------------------------|----------|
| **Target** | Branches only | Branches and tags |
| **Scope** | Repository level | Repository, organization, enterprise |
| **Layering** | Single rule per branch | Multiple can apply (strictest wins) |
| **Visibility** | Admins only | All users with read access |
| **Bypass control** | Admin or global | Granular (users/teams/apps) |
| **Enforcement before creation** | No | Yes (naming patterns, metadata) |
| **Testing mode** | No | Yes (Evaluate mode) |
| **Organization-wide** | No | Yes |
| **Rule reuse** | No | Yes (named rulesets) |

### Why Rulesets Are Better

1. **Scalability**: Define once, apply to many repositories
2. **Transparency**: Developers can see what rules apply
3. **Flexibility**: Layer multiple policies, test before enforcing
4. **Consistency**: Reduce configuration drift across repositories
5. **Compliance**: Better auditability and fine-grained controls

## Complete List of Enforceable Rules

### Commit and Author Rules
- ✓ Commit message pattern matching (regex)
- ✓ Author email pattern matching (regex)
- ✓ Committer email pattern matching (regex)
- ✓ Require signed commits (GPG/SSH)
- ✓ Restrict commit authors by pattern

### File and Path Rules
- ✓ Block file paths matching patterns (fnmatch)
- ✓ Block file extensions
- ✓ Maximum file size limits
- ✓ Maximum file path length
- ✓ Require file paths to match patterns

### Branch and Tag Rules
- ✓ Branch/tag naming patterns
- ✓ Restrict branch/tag creation
- ✓ Restrict branch/tag deletion
- ✓ Restrict branch/tag renaming
- ✓ Block force pushes
- ✓ Require pull requests before merging
- ✓ Require specific number of approving reviews
- ✓ Dismiss stale pull request approvals
- ✓ Require review from code owners
- ✓ Require status checks to pass
- ✓ Require branches to be up to date before merging
- ✓ Require deployments to succeed before merging
- ✓ Require merge queue
- ✓ Require linear history
- ✓ Require workflows to pass before merging

### Access Control Rules
- ✓ Restrict pushes to specific users/teams
- ✓ Restrict deletions to specific users/teams
- ✓ Restrict who can bypass rules
- ✓ Define bypass permissions per rule

## Limitations and Workarounds

### Known Limitations (2025)

#### 1. Enterprise-Level Restrictions
**Limitation**: Some rules available at repository/organization level are not available at enterprise level:
- "Require deployments to succeed before merging"
- "Require merge queue"
- "Require status checks to pass"
- "Require workflows to pass before merging"

**Workaround**: Apply these rules at organization level instead of enterprise level.

#### 2. Role-Based Management
**Limitation**: Only organization owners can create and manage organization rulesets (not admins or custom roles).

**Workaround**: 
- Use clear RACI (Responsible, Accountable, Consulted, Informed) documentation
- Grant organization owner role to designated ruleset managers
- Monitor GitHub's roadmap for granular role improvements

#### 3. Bypass and Exemption Model
**Limitation**: Audit trails for exemptions (silent bypasses) may be less visible than traditional bypasses.

**Workaround**:
- Regularly review bypass/exemption usage in audit logs
- Use bypass (explicit) over exempt (silent) when transparency is critical
- Document all exemption grants with justification

#### 4. Custom Properties Namespace
**Limitation**: Custom properties share a namespace across the organization/enterprise, which can cause naming conflicts.

**Workaround**:
- Establish naming conventions (e.g., `team-name_property-name`)
- Centrally document all custom properties
- Use hierarchical naming (e.g., `security_level`, `team_name`)

#### 5. Insights and Reporting
**Limitation**: Some repository insights may display inaccurately or be temporarily unavailable.

**Workaround**:
- Use Rule Insights feature (introduced in 2025)
- Monitor GitHub changelog for reporting improvements
- Export audit logs for custom reporting

#### 6. Legacy Feature Gaps
**Limitation**: CODEOWNERS review requirements work differently than in branch protection rules.

**Workaround**:
- Enable "Require a pull request before merging" along with "Require review from code owners"
- Test in Evaluate mode before enforcing
- Review GitHub documentation for current CODEOWNERS integration status

### Best Practices to Avoid Issues

1. **Start with Evaluate Mode**
   - Test rules in dry-run mode first
   - Review Rule Insights to identify potential friction
   - Iterate before enabling Active enforcement

2. **Communicate Changes**
   - Notify developers before enforcing new rules
   - Document ruleset policies internally
   - Provide clear guidance on bypass procedures

3. **Use Custom Properties for Tiering**
   - Tag repositories by sensitivity (e.g., `production`, `internal`, `experimental`)
   - Apply appropriate rulesets to each tier
   - Adjust as repositories evolve

4. **Monitor and Adjust**
   - Regularly review audit logs
   - Track bypass rates to identify bottlenecks
   - Collect developer feedback
   - Update rulesets based on real-world usage

5. **Leverage Automation**
   - Manage rulesets via API/GraphQL
   - Use Infrastructure-as-Code (Terraform, etc.)
   - Version control ruleset definitions as JSON
   - Automate rollout across repository groups

6. **Use Exemptions Wisely**
   - Reserve exemptions for high-volume trusted automation
   - Use bypass (explicit) for human actions
   - Document all exemption grants
   - Audit exemption usage regularly

## Implementation Recommendations

### For Small Teams
- Start with repository-level rulesets
- Focus on core protections (signed commits, PR reviews, branch protection)
- Use Evaluate mode for at least one week before enforcing

### For Large Organizations
- Use organization-wide rulesets for consistent governance
- Implement tiered protection based on custom properties
- Establish a ruleset management working group
- Create ruleset templates for different repository types
- Automate ruleset deployment with IaC tools

### Migration from Branch Protection
1. Audit existing branch protection rules
2. Create equivalent rulesets in Evaluate mode
3. Monitor violations and adjust rules
4. Enable Active enforcement gradually (by team or repository group)
5. Deprecate legacy branch protection after validation

## Use Case Examples

### Protect CI/CD Configurations
```
Rule: Block modifications to .github/workflows/*
Target: All branches
Bypass: CI/CD team only
```

### Enforce Commit Standards
```
Rule: Commit message must match pattern "^(feat|fix|docs|chore):"
Target: main, develop
Bypass: None
```

### Require Company Email
```
Rule: Author email must match .*@company\.com
Target: All branches in production repositories
Bypass: GitHub Apps for automated releases
```

### Protect Release Tags
```
Rule: Block deletion of tags matching v*
Target: All tags
Bypass: Release managers only
```

## Resources

### Official Documentation
- [About Rulesets - GitHub Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [Enforcing Code Governance with Rulesets](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/enforcing-policies-for-code-governance)
- [Creating Rulesets for Repositories in Your Organization](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/creating-rulesets-for-repositories-in-your-organization)

### Community Resources
- [GitHub Well-Architected: Rulesets Best Practices](https://wellarchitected.github.com/library/governance/recommendations/managing-repositories-at-scale/rulesets-best-practices/)
- [7 Cool Things You Can Do with GitHub Rulesets](https://ghsioux.github.io/2025/01/09/7-cool-things-with-rulesets)
- [Upgrading Your GitHub Security: A Practical Guide to Rulesets](https://iifx.dev/en/articles/456363451/upgrading-your-github-security-a-practical-guide-to-rulesets)

### GitHub Changelog
- [Organization Rulesets for GitHub Team Plans](https://github.blog/changelog/2025-06-16-organization-rulesets-now-available-for-github-team-plans/)
- [GitHub Ruleset Exemptions and Repository Insights Updates](https://github.blog/changelog/2025-09-10-github-ruleset-exemptions-and-repository-insights-updates/)
- [Filter-based Ruleset Targeting](https://github.blog/changelog/2025-06-23-filter-based-ruleset-targeting/)

## Conclusion

GitHub rulesets represent a significant advancement in repository governance, offering the flexibility, scalability, and visibility needed for modern software development. While some limitations exist (particularly at the enterprise level and in role management), the benefits far outweigh the drawbacks for most use cases.

Organizations should prioritize migrating from legacy branch protection to rulesets, starting with Evaluate mode and gradually rolling out enforcement. The investment in learning and implementing rulesets will pay dividends in consistency, compliance, and developer productivity.

---

**Next Steps for Akwaaba:**
1. Decide on ruleset strategy (repository-level vs organization-level)
2. Define core protection requirements based on governance principles
3. Create initial rulesets in Evaluate mode
4. Test with a pilot repository
5. Roll out to all repositories with monitoring and adjustment
