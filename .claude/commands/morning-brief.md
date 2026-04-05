---
description: Daily morning brief — project health, Linear status, sprint progress
argument-hint: [run|setup] — "run" executes now, "setup" creates weekday schedule
---

Daily morning brief: git activity, code health, Linear status, sprint progress. Sends summary to Telegram.

## No Arguments or `run`

Execute the morning brief immediately.

### Steps

Run these in parallel where possible:

1. **Git activity** (last 24h):
   Run `git log --since="24 hours ago" --oneline --no-merges` in C:/Butlery/butlery.
   Count commits, note which areas were touched.

2. **Code health**:
   Run `dart analyze --fatal-infos` in C:/Butlery/butlery.
   Report clean (0 issues) or list issues by severity.

3. **Linear status**:
   Use Linear MCP `list_issues` to fetch open issues for the Butlery project.
   Group by state: Triage, Backlog, Todo, In Progress.
   Flag any issues that are overdue or due today.
   Flag any Urgent or High priority issues.

4. **Sprint progress**:
   Read `tasks/todo.md`. Count checked `[x]` vs unchecked `[ ]` tasks.
   Identify the current sprint name.
   Note the first unchecked task as "next up".

### Compose Summary

Format as plain text (no markdown — Telegram renders it poorly):

```
Morning Brief - YYYY-MM-DD

Git: X commits since yesterday
[one line per commit, or "no commits"]

Health: dart analyze — clean / N issues
[list issues if any]

Linear:
Triage: X | Backlog: Y | Todo: Z | In Progress: W
Due/overdue: [list or "none"]
High/Urgent: [list or "none"]

Sprint: [sprint name]
Progress: X/Y tasks done
Next up: [first unchecked task]

Focus: [highest-priority actionable item]
```

### Send to Telegram

Use `mcp__plugin_telegram_telegram__reply` with:
- chat_id: "8690554844"
- text: the composed summary

If Telegram MCP is not available, print the summary to the console instead. Do not fail silently.

### Graceful degradation

- If Linear MCP is not connected: skip Linear section, note "Linear: not connected" in summary
- If `tasks/todo.md` does not exist: skip sprint section, note "Sprint: no active sprint"
- If `dart analyze` fails to run: skip health section, note "Health: analyze unavailable"
- Always send whatever was gathered — partial is better than nothing

---

## `setup`

Create a recurring schedule for weekday mornings.

### Steps

1. Check existing scheduled jobs (CronList) for any with "morning" in the name. Delete duplicates to avoid double-firing.

2. Create a durable CronCreate job:
   - schedule: weekdays at 08:53 local time (cron: `53 8 * * 1-5`)
   - durable: true
   - prompt: `/morning-brief run`

3. Confirm to the user:
   "Morning brief scheduled for weekdays at ~8:53am. Fires while Claude REPL is idle. Expires in 7 days — run `/morning-brief setup` again to renew."

### Notes

- The schedule only fires when the Claude Code REPL is idle (not mid-query)
- Durable jobs survive session restarts but auto-expire after 7 days
- Linear MCP and Telegram channel must be active in the session for full functionality
- To cancel: run CronList, then CronDelete with the job ID
