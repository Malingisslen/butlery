---
description: Create and manage git worktrees for parallel development
argument-hint: [action] [branch-name] (optional)
---

Manage git worktrees to enable multiple independent Claude sessions working on different parts of the project simultaneously.

## Actions

### Create Worktree
**Usage**: `/worktree create feature-branch-name`

1. **Check Current Repository**: Verify we're in the main repository
2. **Create Branch** (if needed): Create the target branch if it doesn't exist
3. **Create Worktree**: Execute `git worktree add ../project-[branch-name] [branch-name]`
4. **Verify Setup**: Confirm worktree was created successfully
5. **Provide Instructions**: Show user how to launch Claude in the new worktree:
   ```bash
   cd ../project-[branch-name]
   claude
   ```

### List Worktrees
**Usage**: `/worktree list`

1. **List All Worktrees**: Run `git worktree list` to show all active worktrees
2. **Show Status**: Display which worktrees are in use and their branch status

### Remove Worktree
**Usage**: `/worktree remove branch-name`

1. **Verify Worktree Exists**: Check that the specified worktree exists
2. **Check for Changes**: Warn if there are uncommitted changes
3. **Remove Worktree**: Execute `git worktree remove ../project-[branch-name]`
4. **Cleanup Branch** (optional): Ask if the associated branch should be deleted

### Prune Worktrees
**Usage**: `/worktree prune`

1. **Prune Stale Worktrees**: Run `git worktree prune` to clean up deleted worktrees
2. **List Remaining**: Show remaining active worktrees

## Best Practices

- **Independent Tasks**: Use worktrees for completely independent features that won't conflict
- **Naming Convention**: Use descriptive names like `feature-auth-system`, `fix-shopping-cart`
- **Parallel Sessions**: Each worktree can run its own Claude session for focused development
- **Clean Up**: Remove worktrees when work is complete to avoid clutter

## Examples

**Creating a new feature worktree:**
```bash
git worktree add ../project-feature-auth feature-auth
cd ../project-feature-auth
claude  # Launch Claude in this worktree
```

**Typical workflow:**
1. Main Claude creates feature branch and worktree
2. New Claude session works in isolated worktree directory
3. When complete, merge branch and remove worktree
4. Continue with main development in original directory

This enables true parallel development where multiple Claude instances can work on different features without conflicts or waiting.