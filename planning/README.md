# Akwaaba Implementation Plan

## Overview

**Akwaaba** (Akan/Twi: "Welcome") is a reference implementation demonstrating the **Anokye-Krom System** - a governance model for GitHub repositories where all commits originate from AI agents responding to issues. Inspired by Steve Yegge's Gas Town, but distinctly Anokye Labs.

### The Anokye-Krom System

- **Agent-only commits**: Humans create issues, agents create code
- **Issue-driven development**: All work tracked through GitHub issues
- **Strict automation**: Branch protection, commit validation, authentication
- **Full observability**: Structured logging, tracing, and monitoring
- **Safe operations**: Read-only by default, write via safe-output processing

This planning directory contains the complete breakdown for building this system.

## Structure

- **phase-1-foundation/** - Repository setup and basic structure
- **phase-2-governance/** - Enforcement infrastructure and automation rules
- **phase-3-agents/** - Agent fleet implementation
- **phase-4-dotnet/** - Example .NET application and automation scripts
- **phase-5-documentation/** - Comprehensive documentation
- **phase-6-validation/** - Testing, validation, and polish

## How to Use

Each phase folder contains markdown files for individual features. Each feature file includes:
- Overview and purpose
- Detailed task breakdown
- Acceptance criteria
- Implementation notes

## Phase Summary

| Phase | Features | Dependencies |
|-------|----------|-------------|
| 1 | 3 | None - start here |
| 2 | 5 | Phase 1 |
| 3 | 5 | Phases 1-2 |
| 4 | 5 | Phases 1-3 |
| 5 | 5 | Phases 1-4 |
| 6 | 5 | All phases |

**Total:** 28 features across 6 phases

## Getting Started

1. Review `PLAN.md` in repository root for overall approach
2. Start with Phase 1 features (no dependencies)
3. Work through phases sequentially
4. Track progress using GitHub Project and issues
5. Update SQL todos as features complete

## Feature Naming Convention

Files are numbered by execution order within each phase:
- `01-feature-name.md` - First feature
- `02-feature-name.md` - Second feature
- etc.

## Cross-Phase Dependencies

Some features can be worked on in parallel:
- Phase 3 (agents) can start after Phase 2 (governance) begins
- Phase 5 (docs) can start as features complete
- Phase 6 (validation) runs alongside completion

See dependency trees in individual feature files.
