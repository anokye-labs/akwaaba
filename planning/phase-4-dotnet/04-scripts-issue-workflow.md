# Feature: Create Issue Workflow Scripts

**ID:** scripts-issue-workflow  
**Phase:** 4 - Automation Scripts  
**Status:** Pending  
**Dependencies:** issue-templates

## Overview
Build PowerShell scripts that automate the issue → branch → PR workflow for both humans and agents.

## Key Tasks
- Create New-IssueFromBranch.ps1 (create issue, branch, link)
- Create Start-IssueWork.ps1 (label ready, create branch, setup)
- Create Complete-IssueWork.ps1 (create PR, link, request review)
- Add parameter validation and error handling
- Include comment-based help
- Test scripts end-to-end
- Document usage in SETUP.md
- Commit: "feat(scripts): Add issue workflow automation"
