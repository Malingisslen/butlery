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
- **NEVER `git commit --no-verify` / `-n`, and never `git commit --amend`.** `--no-verify` skips the ENTIRE lefthook layer (format, analyze, arch-guard, secret-scan) — the commit-gate hooks now refuse it outright (BUT-1533). The only legitimate way to skip a *single* hung gate is the documented `LEFTHOOK_EXCLUDE=<gate>` env prefix (Commit-Deadlock Ladder rung 4), never `--no-verify`.
- **The commit is also gated by PreToolUse marker hooks** (`require-review-before-commit`, `require-simplify-before-commit` in the shared workflow-guards plugin): a `.dart`/`functions/src` change is blocked until the specialist-review markers under `.claude/state/` are fresh. These parse the commit's real argument list (BUT-1533) — a `--help`/`--no-verify`/`-h` sitting inside a `-m` message no longer disables the gate, and an env-prefixed `LEFTHOOK_EXCLUDE=… git commit` is still gated.

## Parallel Sessions
- Another Claude Code session may be running in parallel in a worktree or on a different branch
- If `git status` shows unexpected changes or merge conflicts you didn't create, **stop and ask the user** — do not reset, clean, or force-push
- The other session's work is just as important
- **Stage by explicit pathspec and commit in the SAME Bash call** — never `git add .`/`-A` when parallel work exists, and never leave files staged across turns (the other session's commit sweeps your index, and vice versa). After any gate block, re-verify the index before retrying.
- **`tasks/todo.md` belongs to whichever session is mid-plan in it.** If it holds another session's unchecked plan, write yours to a separate `tasks/<initiative>-plan.md` instead of overwriting.
- Committing onto the other session's feature branch is fine (solo repo, it merges to main soon) — sweeping its files into your commit is not.

## Commit-Deadlock Ladder (lefthook analyze hangs/crashes — iter-147 family)
Work the ladder in order; don't loop on one rung:
1. **Zombies**: `taskkill //F //IM flutter_tester.exe` (tiny idle processes are dead runners), retry once.
2. **Contending watcher**: check for a running "Continuous dart analyze" monitor (`/tmp/analyze*` mtimes fresh = active) — stop it, retry once.
3. **IDE-locked cache**: `dart.exe` respawning instantly = VS Code's language server; the `.dartServer` cache under `%LOCALAPPDATA%` can be bloated/corrupted but can only be cleared with VS Code closed. Flag it to Malin as a when-convenient chore.
4. **Documented exclusion** — `LEFTHOOK_EXCLUDE=analyze git commit ...` is legitimate ONLY when BOTH: a standalone `dart analyze` ran clean upstream, AND the staged diff contains no `.dart` files. State both facts in the commit body. All other gates still run. `LEFTHOOK=0` (all gates off) is never the answer.
