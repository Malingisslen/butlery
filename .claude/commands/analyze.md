---
description: Run Flutter analyze, report issues, and optionally fix them
argument-hint: [--fix | --errors-only | --dry-run]
---

Run Flutter analyze and create a structured report of all issues found.

Options provided: $ARGUMENTS

## Workflow

1. **Run Analysis**: `flutter analyze`

2. **Report Issues** organized by priority:
   - CRITICAL: Errors preventing compilation
   - HIGH: Warnings affecting functionality
   - MEDIUM: Code quality warnings
   - LOW: Info/style suggestions
   Group issues by file for easier navigation.

3. **If `--fix` is provided** (or user confirms):
   For each issue in priority order:
   - Identify root cause (not just symptom)
   - Apply fix following project patterns
   - Verify fix didn't introduce new issues
   After all fixes, re-run `flutter analyze` and confirm zero issues.

4. **If no `--fix`**: Ask "Would you like me to fix these? Run `/analyze --fix`."

## Options
- `--fix`: Automatically fix all issues in priority order
- `--errors-only`: Only report/fix errors, skip warnings/infos
- `--dry-run`: Report what would be fixed without making changes
