# Feature: Add .gitignore Files

**ID:** gitignore-setup  
**Phase:** 1 - Foundation  
**Status:** Pending  
**Dependencies:** repo-init

## Overview

Create comprehensive .gitignore files to exclude build artifacts, IDE files, and temporary files from version control.

## Tasks

### Task 1: Create root .gitignore
- [ ] Add .NET patterns (bin/, obj/, *.user, *.suo)
- [ ] Add Visual Studio patterns (.vs/, *.vsidx)
- [ ] Add Rider patterns (.idea/)
- [ ] Add VS Code patterns (.vscode/ except settings shared)

### Task 2: Add PowerShell patterns
- [ ] Exclude PowerShell module artifacts (*.psd1 cache)
- [ ] Exclude test result files (TestResults/)
- [ ] Exclude log files (*.log, logs/)
- [ ] Exclude temporary scripts (temp*.ps1, scratch*.ps1)

### Task 3: Add .NET specific patterns
- [ ] Exclude NuGet packages (packages/, *.nupkg)
- [ ] Exclude build outputs (bin/, obj/, *.dll, *.exe)
- [ ] Exclude user-specific files (*.user, *.suo, *.userosscache)
- [ ] Exclude code coverage (coverage/, *.coverage)

### Task 4: Add OS-specific patterns
- [ ] Windows: Thumbs.db, Desktop.ini
- [ ] macOS: .DS_Store, .AppleDouble
- [ ] Linux: *~, .directory

### Task 5: Add IDE and editor patterns
- [ ] Exclude Rider: .idea/
- [ ] Exclude Visual Studio: .vs/, *.vsidx, *.sln.docstates
- [ ] Exclude VS Code: .vscode/ (keep settings.json template)
- [ ] Exclude general editors: *.swp, *.swo, *~

### Task 6: Add development tools patterns
- [ ] Git: *.orig, *.rej
- [ ] ReSharper: _ReSharper*/
- [ ] NCrunch: *.ncrunch*
- [ ] DotCover: *.dotCover

### Task 7: Add session and temporary files
- [ ] Copilot session artifacts (except intentional planning)
- [ ] Temporary test data (temp/, tmp/, scratch/)
- [ ] Local configuration overrides (*.local.*)

### Task 8: Document exceptions
- [ ] Add comments explaining why certain files ARE tracked
- [ ] Document any intentional exceptions
- [ ] Add section headers for clarity

### Task 9: Test .gitignore
- [ ] Create dummy files that should be ignored
- [ ] Verify `git status` doesn't show them
- [ ] Remove dummy files
- [ ] Commit with message: "chore: Add comprehensive .gitignore"

## Acceptance Criteria

- All common .NET artifacts are excluded
- PowerShell temporary files are excluded
- IDE-specific files are excluded appropriately
- OS-specific cruft is excluded
- File is well-organized with comments
- No accidentally excluded files that should be tracked
- `git status` is clean after building project

## Notes

- Use GitHub's .gitignore templates as reference
- Organize by category with comment headers
- Be comprehensive but not overly broad
- Test with actual build to verify patterns work
