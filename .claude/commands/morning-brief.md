---
description: Daily morning brief — health, Linear status, sprint progress across ALL THREE projects (Butlery, binge, synat), delivered to Telegram
argument-hint: (no arguments — run by the daily scheduled task, or by hand)
---

Compose ONE combined morning brief covering all three projects and deliver it. Lean and
mechanical: parallel `sonnet`/low subagents for the reads, no deep analysis.

## Gather (parallel; each repo independently, failures degrade per-section)

For EACH of C:/Butlery/butlery, C:/binge, C:/webbkollen:

1. **Git activity** (24h): `git log --since="24 hours ago" --oneline --no-merges` — count +
   areas touched. Also `git status --porcelain | wc -l` (uncommitted work left behind?).
2. **Health**: the repo's `stopCheck.command` from `.claude/shared-plugin.json`
   (dart analyze / npm run typecheck) — clean or N issues.
3. **CI**: `gh run list --limit 3` in the repo — latest run green/red (skip if no gh).

Once, via Linear MCP (scoped per repo's `delivery.linear` config — Butlery by team, binge/
synat by PROJECT, never team):
4. **Linear**: open counts by state; overdue/due-today; Urgent+High; **In Review items
   waiting on Malin** (these are the headline).
5. **Sprint state**: each repo's `tasks/todo.md` — checked/unchecked + sprint name.

## Compose (plain text, no markdown — Telegram renders it poorly)

```
Morgonbrief YYYY-MM-DD

VÄNTAR PÅ DIG (X st):
- [repo] BUT-XXX/BIN-XXX — one plain-language line each (In Review sign-offs, decisions)
  (or "inget just nu")

Butlery: N commits | analyze clean/N | CI grön/röd | Linear: T/B/Todo/InProg | sprint X/Y
binge:   ... | synat: ...

Fokus idag: [the single highest-value item, one line]
```

Keep the whole message under ~25 lines. Plain language throughout — no class names, no
shorthand. Swedish is fine (Malin reads it natively).

## Deliver

Send via the Telegram plugin's `reply` tool, chat_id "8690554844" (load via ToolSearch if
deferred). If the send fails or the tool is unavailable in this environment, send a
PushNotification with the "VÄNTAR PÅ DIG" count + focus line instead, and print the full
brief as the final message. Never fail silently.

## Scheduling (the part that actually works)

This command has NO self-scheduling. CronCreate is SESSION-ONLY (jobs die with the session
— the reason the old `setup` mode never worked). The standing trigger is a **claude.ai
scheduled task** (same proven mechanism as the weekly janitor): Malin creates it once —
daily ~06:45, prompt `/morning-brief` in the Butlery project. If the schedule stops firing,
recreate it there; do not reach for CronCreate.
