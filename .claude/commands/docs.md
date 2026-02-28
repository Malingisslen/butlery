---
allowed-tools: Bash, Read, Edit, MultiEdit, Glob, Grep
description: Detect documentation drift and update docs based on code changes
argument-hint: [--drift-only | --update-only | optional: folder to focus on]
---

# Documentation Maintenance

Focus area: $ARGUMENTS

## Phase 1: Drift Detection (default first step)

Scan .md files for drift from actual implementation:
1. Implementation plans still lingering after completion
2. ADRs describing superseded decisions, outdated patterns
3. Changed function signatures, removed features still documented
4. CLAUDE.md references to paths/files that no longer exist

Output drift report: files to delete (with reason), files to update (with sections), files OK.

If `--drift-only`: stop here.

## Phase 2: Update Documentation

Use `git diff HEAD~1..HEAD` and `git status` to identify code changes, then update:
- CLAUDE.md project summary
- docs/ files for new patterns, features, architecture changes

Rules: preserve structure, only update for detected changes, respect 500-line limit, focus on architectural changes not minor fixes.

If `--update-only`: skip Phase 1.

Default (no flags): run both phases. Ask before making deletions.
