---
description: Lightweight health check — runs silently every 30 min via CronCreate
argument-hint: (no arguments — called automatically)
---

CRITICAL: If ALL checks below pass with no findings, output NOTHING. No "all clear", no status, no timestamp, no acknowledgment. Just stop. Every token you emit adds to the context window and this runs every 30 minutes.

## Four Checks (run in parallel where possible)

### Check 1: Uncommitted changes staleness

Run `git diff --stat` and `git diff --cached --stat` in C:/Butlery/butlery.

- If no changes: pass (silent)
- If changes exist: check the age of the oldest modified file using `git diff --name-only | head -1` then `python3 -c "import os,time; print(int((time.time()-os.path.getmtime('FILE'))/60))"` to get minutes
- If oldest change is >60 minutes: finding — "Uncommitted changes in N files (oldest: Xm ago)"
- If <60 minutes: pass (silent — still actively working)

### Check 2: dart analyze delta

Run `dart analyze --fatal-infos 2>&1` in C:/Butlery/butlery.

Read previous issue count from `$TMPDIR/.heartbeat-analyze-count` (a single integer, or 0 if file missing).

- If analyze clean (0 issues) AND previous was 0: pass (silent)
- If analyze clean AND previous was >0: finding — "dart analyze now clean (was N issues)"
- If issues found AND count changed from previous: finding — "dart analyze: N issues (was M)"
- If issues found AND count unchanged: pass (silent — already known, avoid nagging)

Write new count to `$TMPDIR/.heartbeat-analyze-count`.

### Check 3: Linear stuck tickets

Call `mcp__linear__list_issues` with state filter for "In Progress".

For each In Progress ticket:
- Extract BUT-XXX identifier
- Run `git log --since="3 days ago" --grep="BUT-XXX" --oneline` to check for recent commits
- If no commits in 3 days: finding — "BUT-XXX stuck: In Progress N days, no commits"

If Linear MCP is not connected: skip entirely. Do NOT report the skip.

### Check 4: Stale sprint task

Read `tasks/todo.md`. Find the first unchecked `[ ]` task.

- Extract its BUT-XXX reference if present
- Run `git log --since="48 hours ago" --grep="BUT-XXX" --oneline`
- If no git activity in 48+ hours: finding — "Current task [description] open 48+ hours, no commits"
- If `tasks/todo.md` doesn't exist: skip silently

## After All Checks

Collect findings into a list.

**If findings list is empty: STOP. Output nothing. Do not acknowledge the heartbeat ran.**

**If findings list is non-empty:**

Print to console AND send to Telegram:

```
Heartbeat [HH:MM]
- [finding 1]
- [finding 2]
Action: [one-line suggested next step]
```

Send via `mcp__plugin_telegram_telegram__reply` with chat_id: "8690554844". If Telegram unavailable, console only.

## Activity comment (if applicable)

If Check 1 found uncommitted changes AND Check 3 found an In Progress ticket:
- Read `$TMPDIR/.heartbeat-last-comment.json` (JSON map of `{"BUT-XXX": "ISO-timestamp"}`)
- If the ticket's last comment was 2+ hours ago (or no entry exists):
  - Post `save_comment` on the ticket: "Progress checkpoint — uncommitted changes in N files, sprint task: [current task description]"
  - Update the timestamp in the JSON file
- If <2 hours since last comment: skip (avoid spam)

If the JSON file doesn't exist, create it. If Linear MCP is unavailable, skip.

## Graceful degradation

- Linear MCP not connected: skip Checks 3-4 Linear parts and activity comment. Do NOT report the skip.
- Telegram not available: print findings to console only
- `dart analyze` fails to run: skip Check 2
- `tasks/todo.md` missing: skip Check 4
- Any temp file missing: treat as first run (no previous state)
