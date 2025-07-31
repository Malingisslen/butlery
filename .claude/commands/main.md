---
description: Commit current branch changes, merge to main, and cleanup
argument-hint: (no arguments required)
---

Complete git workflow to merge current branch work back to main and cleanup.

Follow these steps in order:

1. **Check Current Status**: Run `git status` to see what changes exist
2. **Get Current Branch**: Run `git branch --show-current` to identify the current branch name
3. **Commit All Changes**: Stage and commit all changes in the current branch with an appropriate commit message following repository conventions
4. **Switch to Main**: Checkout to the main branch with `git checkout main`
5. **Merge Branch**: Merge the feature branch into main with `git merge [branch-name]`
6. **Delete Branch**: Clean up by deleting the feature branch with `git branch -d [branch-name]`
7. **Confirm Status**: Run `git status` and `git log --oneline -3` to confirm the merge was successful

**Safety Checks**:
- Verify you're not already on main branch before starting
- Ensure there are changes to commit before proceeding
- Confirm merge was successful before deleting the branch
- Handle any merge conflicts if they occur

**Worktree Handling**:
- Check if working in a worktree directory (path contains `../project-`)
- If in worktree, after successful merge, offer to:
  - Remove the worktree: `git worktree remove ../project-[branch-name]`
  - Return user to main repository directory
  - Clean up any worktree references

**Error Handling**:
- If merge conflicts occur, inform user and provide guidance
- If branch deletion fails (e.g., unmerged commits), explain the issue
- If already on main, skip merge step but still commit changes
- If worktree removal fails, provide manual cleanup instructions

This command provides a complete feature branch workflow for finishing work and returning to main, with full worktree support.