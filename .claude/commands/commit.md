---
description: Commit all changes made during the session
argument-hint: (no arguments required)
---

Commit all changes made during this session to git with an appropriate commit message.

## Workflow

1. Run `git status` and `git diff --staged` (stage with `git add` if needed)
2. Run `dart analyze` on changed .dart files — fix any issues before proceeding
3. Create a conventional commit message:
   - Prefix: `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`
   - Clear description of what was accomplished
   - List key changes in the body if multi-file
   - `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` footer
4. Commit the changes
5. If pre-commit hook fails: fix the issue, re-stage, create a NEW commit (never amend)
6. Confirm success with `git status`
