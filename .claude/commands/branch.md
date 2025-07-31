---
description: Create and switch to a new git branch for current work
argument-hint: (no arguments required)
---

Create a new git branch for the work currently being done in this session.

Follow these steps:

1. **Analyze Current Work**: Look at recent changes and the nature of work being done as well as the current conversation to determine an appropriate branch name
2. **Check Git Status**: Run `git status` to see current changes
3. **Create Branch Name**: Based on the work being done, create a descriptive branch name using conventions like:
   - `feature/description` for new features
   - `fix/description` for bug fixes  
   - `refactor/description` for code improvements
   - `chore/description` for maintenance tasks
   - `docs/description` for documentation updates

4. **Choose Development Mode**: Ask user if they want:
   - **Standard Branch**: Create branch in current directory (default)
   - **Worktree Branch**: Create branch in separate worktree for parallel development

5. **Create and Switch**: 
   - **Standard**: `git checkout -b branch-name`
   - **Worktree**: `git worktree add ../project-[branch-name] [branch-name]` and provide instructions to launch Claude in new directory

6. **Confirm**: Verify the branch was created and you're now on the new branch

Ask the user to confirm the suggested branch name before creating it, or let them provide their own name.

Example branch names:
- `feature/code-intelligence-platform`
- `fix/flutter-analysis-issues`
- `refactor/analyzer-cleanup`
- `chore/command-structure-improvements`