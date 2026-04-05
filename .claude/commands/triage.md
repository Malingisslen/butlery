---
description: Sprint triage — prioritize work, plan next sprint from Linear backlog
argument-hint: <subcommand> [args] — "status", "plan [N]", "focus <area>"
---

Sprint planning and priority sequencing. Reads Linear backlog, current sprint, and git activity to recommend what to work on next.

## No Arguments — Show Cheat Sheet

If run with no arguments, display this and stop:

```
/triage status          — Quick overview: what's done, what's next
/triage plan            — Generate next sprint plan (6-10 tasks)
/triage plan 3          — Generate sprint with exactly 3 tasks
/triage focus <area>    — Plan sprint for one area (recipe, social, backend, etc.)
```

Do NOT run any analysis. Just print the table above.

## Prerequisites

Verify Linear MCP is connected (test `list_issues`). If not: "Linear MCP not connected. Run `/mcp` to reconnect." and stop.

## Data Gathering (all subcommands)

Before any subcommand, gather these three inputs in parallel:

### Input 1: Linear Backlog
Fetch open issues via Linear MCP `list_issues` (states: Backlog, Todo, In Progress, Triage).
For each issue extract: ID, title, priority, state, labels (type + area), due date.

### Input 2: Current Sprint Status
Read `tasks/todo.md`. Parse:
- Sprint name/title
- Checked `[x]` vs unchecked `[ ]` tasks
- Linear ticket references (BUT-XXX patterns)

If `tasks/todo.md` does not exist or is empty, note "no active sprint".

### Input 3: Recent Git Activity
Run `git log --since="7 days ago" --oneline --no-merges` in C:/Butlery/butlery.
Map: which areas were touched, which BUT-XXX tickets were referenced in commit messages.

## Cross-Reference Logic

1. **Completed detection:** Linear tickets referenced in recent commits AND checked in todo.md = completed. Flag any Linear tickets still in Backlog/Todo that appear done in git.

2. **Stale detection:** Unchecked tasks in todo.md with no git activity in 7+ days = stale.

3. **Priority scoring** for each open Linear ticket:
   - Urgent = 100, High = 75, Medium = 50, Low = 25
   - Overdue due date: +50
   - Due this week: +25
   - Bug or security type label: +20
   - In Triage state (ungroomed): -10

4. **Grouping:** Cluster tickets by area label for coherent context sharing. Don't mix a 5-minute lint fix with an architecture rework in the same agent group.

---

## `status`

Read-only overview. Output:

```
Current Sprint: [name from todo.md, or "none"]
  Progress: X/Y tasks (Z%)
  Stale tasks: [unchecked with no recent git activity, or "none"]

Linear Pipeline:
  Triage: X | Backlog: Y | Todo: Z | In Progress: W
  Overdue: [list or "none"]
  Due this week: [list or "none"]
  High/Urgent: [list or "none"]

Recently Completed (7d):
  [commit-referenced BUT-XXX tickets, or "none"]

Recommendation: [one sentence]
```

The recommendation should be one of:
- "Current sprint has unchecked work — continue before planning new sprint"
- "Current sprint is complete — run `/triage plan` for next sprint"
- "No active sprint — run `/triage plan` to start one"
- "Blockers detected: [describe]"

---

## `plan` or `plan N`

Generate a new sprint plan. N = number of tasks (default: auto-size 6-10 based on backlog).

### Steps

1. Gather all three inputs + run cross-reference logic
2. If current sprint has unchecked tasks, ask: "Current sprint has X unchecked tasks. Archive and start fresh, or carry forward unchecked items?"
3. Select top-N tasks by priority score, grouped by area into agent assignments
4. For each task, include:
   - Linear ticket reference (BUT-XXX)
   - One-line description
   - Key files to touch (from the Linear ticket body, if available)
   - Suggested agent from `.claude/agents/` (debugger, flutter-developer, firebase-backend-security, etc.)
5. Present the sprint plan for user confirmation BEFORE writing

### Output format (matches existing todo.md conventions)

```markdown
## Sprint: [descriptive name] — [date]

### Agent A: [agent-name] — [theme/area]

- [ ] **A1. [verb] [description]** — `file/path.dart`: [specific change]. (BUT-XXX)
- [ ] **A2. [verb] [description]** — `file/path.dart`: [specific change]. (BUT-XXX)

### Agent B: [agent-name] — [theme/area]

- [ ] **B1. [verb] [description]** — `file/path.dart`: [specific change]. (BUT-XXX)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR, merge
- [ ] Update Linear ticket states

---

## What this means in plain language

- [what the user will notice changing]
- [what the user will notice changing]
- Risk: [what could break, how easy to undo]
```

On user confirmation: write to `tasks/todo.md`. If there was a previous sprint, archive it below a `---` separator.

**Linear state transition** (after writing todo.md):
- Call `list_issue_statuses` to resolve state name → UUID mapping
- For each BUT-XXX ticket in the new sprint plan:
  - Call `get_issue` with the ticket identifier to get its Linear UUID
  - Call `save_issue` with id: <uuid>, stateId: <Todo-state-uuid>
  - Report: "BUT-XXX → Todo"
- If Linear MCP is not connected, skip silently

---

## `focus <area>`

Same as `plan` but filtered to one area label.

Valid areas: recipe, tagging, import, parsing, social, menu, shopping, account, analytics, settings, backend.

If the area has fewer than 3 open tickets, warn: "Only X tickets in [area]. Consider `/triage plan` for a mixed sprint."

---

## Relationship to /linear

This command complements `/linear`, not replaces it:

- `/linear scan` = find NEW issues in the codebase and create tickets
- `/linear backlog` = pick ONE ticket and start implementing
- `/linear status` = dashboard of ticket counts
- `/triage status` = "where am I" with sprint context
- `/triage plan` = synthesize backlog into an ordered sprint with agent assignments

The triage command reads from Linear and transitions selected tickets to "Todo" state when a sprint plan is confirmed. It writes to `tasks/todo.md` and updates Linear ticket states, but never creates or deletes tickets.
