---
description: Identify documentation that no longer matches the code
argument-hint: [optional: docs folder to focus on]
---

Scan documentation for drift from actual implementation.

Focus area: $ARGUMENTS

## Analysis Categories

### 1. Implementation Plans
- Plans marked as "complete" but file still exists
- Step-by-step guides for finished migrations
- Debug/troubleshooting docs for resolved issues

### 2. Architecture Docs
- ADRs that describe superseded decisions
- Architecture guides with outdated patterns
- README files describing removed features

### 3. API Documentation
- Function signatures that changed
- Removed endpoints still documented
- Parameter changes not reflected

### 4. Feature Documentation
- Features that were removed
- Functionality that changed significantly
- Integration docs for removed dependencies

## Process

1. Scan all .md files in scope
2. For each doc, verify referenced code/features still exist
3. Check if described patterns match current implementation
4. Identify outdated sections

## Output Format

```markdown
## Documentation Drift Report

### Files to Delete (X files)
- path/to/file.md - Reason: [implementation complete/feature removed/etc.]

### Files to Update (Y files)
- path/to/file.md
  - Section "X": describes removed feature
  - Section "Y": outdated pattern reference

### Files OK (Z files)
- path/to/file.md
```

Ask: "Should I proceed with deletions and updates?"
