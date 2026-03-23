# Git Workflow

## Git Safety
- NEVER run destructive git operations (checkout, reset, clean) with uncommitted changes
- Always run `git status` first; `git stash` if uncommitted work exists
- Ask user before any operation that could lose work

## Pre-Commit Checks
- After making code changes, always run `dart analyze --fatal-infos` before committing
- Fix any errors before staging

## Lefthook
- Git pre-commit hooks (lefthook) exist in this project and may reformat files
- After the first commit attempt, if it fails due to formatting, re-stage all changed files and commit again with the same message
- Do not panic or start over

## Parallel Sessions
- Another Claude Code session may be running in parallel in a worktree or on a different branch
- If `git status` shows unexpected changes or merge conflicts you didn't create, **stop and ask the user** — do not reset, clean, or force-push
- The other session's work is just as important
