---
name: janitor
description: Weekly maintenance sweep — refresh stale role dossiers, run due world-watch scans, fire org-retro when scheduled, compute the autonomy accept-rate metric, and clear scratch/disk cruft. Designed to run unattended as a scheduled cloud routine; also runnable by hand. Stamps docs/org/janitor/last-run.json so the due-check hook knows it ran.
---

# /janitor — the weekly maintenance routine

The audit's core law: *a loop is only as alive as its most mechanical trigger.* Several
maintenance loops kept stalling because their **detector** was a hook (alive) but their **pump**
was "a human remembers to run the skill" (dead). This routine IS the pump. It runs the due loops
end-to-end on a schedule so drift never accumulates. **It never touches app code or user data —
only maintenance artifacts.** Every step fails soft: log what couldn't run, continue, never abort
the whole routine on one failure.

**Model/cost:** the sweeps and dossier refreshes are mechanical → run subagents on `sonnet` at low
effort. The accept-rate metric is a deterministic Python script (NO agent). Only the final
"anything alarming?" summary uses the routine's own model. Keep it cheap.

## Steps (in order; each is independent — a failure skips to the next)

### 1. Refresh stale role dossiers
Read the markers under `docs/org/dossier-staleness/*.stale`. For each stale role, dispatch a
`sonnet`/low subagent that re-reads the role's owned paths and updates ONLY that role's section in
`docs/architecture/ROLE_RESPONSIBILITY_MAP.md` (Mandate / Evidence / Watch items) to match current
code, then clears the marker. Batch ~3 roles per agent (per the agent-timeout lesson). This is the
`/refresh-dossiers` skill's job — invoke its logic. Report: N dossiers refreshed.

### 2. Run due world-watch scans
Run `bash .claude/hooks/world-watch-due-check.sh`-equivalent logic: read
`docs/org/world-watch/state.json`, and for each role whose `lastScan` is older than its cadence,
run the `/world-watch` scan (poll sources, diff snapshot, impact-check, route material findings to
Linear per authority). Update `lastScan` even on a clean scan so it doesn't re-fire. Report: roles
scanned, material findings routed.

### 3. Fire org-retro if scheduled
Check `docs/org/metrics/retro-schedule.json`. If a retro is due, run `/org-retro` in the mode its
window supports (shakedown while the org is young — no pruning; full once ≥2–3 role cadences have
elapsed, ~mid-August 2026). Record its recommendations; DON'T auto-apply structural changes
(pruning roles is a Malin decision — surface it, don't do it).

### 4. Compute the autonomy accept-rate metric
```
python tools/cost_per_accepted_change.py --days 30 --json
```
Deterministic, no LLM. Append the result to `docs/org/metrics/accept-rate.jsonl` (one line,
stamped). If `accept_rate < 0.5`, flag it prominently in the report — per the loops literature,
below 50% the autonomous loop is costing more review than it saves and its gates need tightening.

### 5. Sweep scratch & disk cruft (conservative — never delete unsure)
- `.claude/state/`: delete one-off run artifacts older than 14 days that are NOT `*-done.marker`,
  `plan-approved-*`, `backlog-scan.json`, or an active emulator `.pid`/`.log`. When unsure, keep.
- `tasks/`: archive (don't delete) implemented plan files — move `*-plan.md` whose work is shipped
  to `tasks/archive/`. Leave `lessons.md`, `todo.md`, and any plan with unchecked items.
- Global (report only, don't auto-delete without confirmation): count of
  `~/.claude/security/security_warnings_state_*.json`, `~/.claude/shell-snapshots/`, and
  `~/.claude/file-history/` entries older than 60 days, so Malin can approve a bulk clean.

### 6. Stamp the run
Write `docs/org/janitor/last-run.json`:
```json
{ "lastRun": "<ISO date>", "dossiersRefreshed": N, "worldWatchRoles": N,
  "retroFired": true/false, "acceptRate": 0.NN, "scratchCleared": N }
```
This is what `janitor-due-check.sh` reads to know the routine is alive.

### 7. Report (Telegram + summary)
One short plain-language message (for a non-coder who wasn't watching): what was refreshed, any
material world-watch finding, the accept-rate trend, and anything needing Malin (a retro
recommendation, a bulk-delete confirmation, an accept-rate below 50%). Send via Telegram if
connected; otherwise print. Keep it to what changed and what needs her — not a step log.

## Scheduling
Runs weekly (Monday morning) as a cloud routine created via `/schedule`. If the schedule ever
stops, `janitor-due-check.sh` (SessionStart) nudges after 8 days. To (re)create it:
`/schedule` → weekly → command `/janitor`. Never let the routine act outward without Malin's
standing consent to the maintenance scope above — it is bounded to maintenance artifacts by design.
