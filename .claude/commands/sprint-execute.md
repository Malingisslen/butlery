---
description: Execute the current sprint from todo.md — implement all tasks, then commit + push + PR
argument-hint: [--dry-run] — preview execution plan without implementing
---

Execute all unchecked tasks in `tasks/todo.md` from top to bottom.

## Prerequisites

1. Read `tasks/todo.md` — if no unchecked tasks exist, say "No tasks to execute. Run `/triage plan` first." and stop.
2. If `$ARGUMENTS` contains `--dry-run`, print the execution plan (task list with order, agent assignments, files) and stop without implementing.

## Execution Loop

### Agent Batching

Tasks under the same `### Agent` heading should be batched into a single agent invocation. Don't spawn a separate agent per task — process the whole group together.

### Per-Task Steps

1. **Parse the task** — extract: task ID (A1, B1, etc.), description, target file(s), suggested agent, BUT-XXX reference
1.5. **Linear state update** — if the task references BUT-XXX:
   - Call `list_issue_statuses` to resolve "In Progress" state UUID (cache for session)
   - Call `get_issue` with BUT-XXX to get the Linear UUID
   - Call `save_issue` with id: <uuid>, stateId: <In-Progress-uuid>
   - Call `save_comment` with: "Started implementation — [task description]"
   - If Linear MCP unavailable, skip silently
2. **Implement** — if the task specifies an agent, invoke that agent with the full task group. Otherwise, implement directly.
3. **Verify** — run `dart analyze --fatal-infos` on changed files. Fix any issues.
4. **Check off** — mark the task as `[x]` in todo.md
5. **Report progress** — "Task A1 complete. Sprint: X/Y done."

### Error Handling

- If a task fails after 2 attempts: mark it with `[!]` in todo.md, note the error, and continue to the next task
- If `dart analyze` fails and the fix is not obvious: stop the sprint and report which task caused the issue
- Never silently skip a task — always report what happened

## Post-Sprint Steps

After all tasks are processed (or all remaining tasks are blocked):

1. Run full `dart analyze --fatal-infos`
2. Run `/commit` (this triggers code review, testing, and Linear ticket closure)
3. Push to remote: `git push -u origin HEAD`
4. Create PR via `gh pr create` with sprint summary derived from todo.md
5. Report: "Sprint complete. PR: [url]. X/Y tasks done, Z blocked."

## What This Does NOT Do

- Does not create worktrees (use worktrees manually for parallel sprints)
- Does not merge PRs (user reviews and merges)
- Does not auto-start the next sprint (user runs `/triage plan`)

These are intentionally manual to keep the human in the loop for irreversible operations.
