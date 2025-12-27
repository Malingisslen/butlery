---
description: Run analyze and automatically fix all issues in priority order
argument-hint: [--errors-only | --dry-run]
---

Run Flutter analyze and systematically fix all issues found.

Options provided: $ARGUMENTS

## Workflow

1. **Run Analysis**
   ```bash
   flutter analyze
   ```

2. **Prioritize Issues**
   - CRITICAL: Errors preventing compilation
   - HIGH: Warnings affecting functionality
   - MEDIUM: Code quality warnings
   - LOW: Info/style suggestions

3. **Fix Strategy**
   For each issue:
   - Identify root cause (not just symptom)
   - Apply fix following project patterns from CLAUDE.md
   - Verify fix didn't introduce new issues
   - Move to next issue

4. **Verification**
   After all fixes:
   - Run `flutter analyze` again
   - Confirm zero issues (or document remaining intentional ones)

## Options
- `--errors-only`: Only fix errors, skip warnings/infos
- `--dry-run`: Report what would be fixed without making changes

## Progress Tracking
Use todo list to track progress through all issues.

Continue fixing until all issues are resolved or ask for guidance on complex cases.
