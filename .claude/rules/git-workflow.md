# Git Workflow

## Safety

- Never run destructive git operations (`checkout`, `reset`, `clean`) with uncommitted changes.
- `git status` first; `git stash` if uncommitted work exists.
- Ask before any operation that could lose work.
- **Never `--no-verify`/`-n`, never `--amend`.** Both are refused by the commit gate. The
  only legitimate way to skip a single hung gate is `LEFTHOOK_EXCLUDE=<gate>`, and only
  when a standalone analyze ran clean AND the staged diff has no `.dart` files — state
  both facts in the commit body. `LEFTHOOK=0` is never the answer.

## Parallel sessions

Another session may be running in a worktree, on another branch, or in this very checkout.

- Unexpected changes or conflicts you didn't create: **stop and ask** — don't reset, clean,
  or force-push. The other session's work counts as much as yours.
- **Stage by explicit pathspec and commit in the SAME Bash call.** Never `git add .`/`-A`
  when parallel work exists, and never leave files staged across turns — the other session's
  commit sweeps your index, and yours sweeps theirs. Re-verify the index after any gate block.
- `tasks/todo.md` belongs to whichever session is mid-plan in it. If it holds another
  session's unchecked plan, write yours to `tasks/<initiative>-plan.md` instead.
- Committing onto the other session's feature branch is fine (solo repo, merges to main
  soon); sweeping its files into your commit is not.

## When the commit itself is stuck

Lefthook may reformat files as part of the commit — that is normal and it re-stages them
within the same run.

If the analyze gate hangs, times out, or reports findings that look wrong, the analyzer is
usually the problem rather than the code: `docs/ops/analyzer-recovery.md` has the ordered
recovery ladder (memory first, then zombies, contention, cache, and the one legitimate
bypass). The gate names that runbook when it fires.
