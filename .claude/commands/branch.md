---
description: Create and switch to a new git branch for current work
argument-hint: (no arguments required)
---

Create a new git branch for the work currently being done in this session.

Follow these steps:

1. **Analyze Current Work**: Look at recent changes and the nature of work being done to determine an appropriate branch name
2. **Check Git Status**: Run `git status` to see current changes
3. **Suggest Branch Name**: Based on the work being done, suggest a descriptive branch name using conventions like:
   - `feature/description` for new features
   - `fix/description` for bug fixes  
   - `refactor/description` for code improvements
   - `chore/description` for maintenance tasks
   - `docs/description` for documentation updates

4. **Create and Switch**: Create the new branch and switch to it using `git checkout -b branch-name`
5. **Confirm**: Verify the branch was created and you're now on the new branch

Ask the user to confirm the suggested branch name before creating it, or let them provide their own name.

Example branch names:
- `feature/code-intelligence-platform`
- `fix/flutter-analysis-issues`
- `refactor/analyzer-cleanup`
- `chore/command-structure-improvements`