# Autonomous Sprint Loop

Drives `/sprint-execute` in a loop until the Linear backlog is empty (or you stop it).

**Billing:** built for **Claude Max subscription**, not API. The natural ceiling
is the 5-hour usage window — when you hit it, the loop sleeps until quota
resets and resumes automatically (configurable via `-RateLimitCooldownMin`).

## Why an external wrapper instead of an in-session loop?

Three constraints rule out the in-session approaches:

1. **`/clear` can't be called from inside a running session** — it would wipe the
   context of the call itself. The only way to get a truly fresh context per
   iteration is to spawn a new `claude` process per iteration. That is what this
   script does.
2. **Plan-mode approval is a TTY concept.** `/sprint-execute` already has its
   rubber-stamp plan gate removed (see `memory/feedback_solo_no_scope_gate.md`),
   so the only remaining friction is per-tool permission prompts. `claude -p`
   plus `--permission-mode bypassPermissions` resolves those without a human.
3. **Sprint Phase 3 commits, pushes, and closes Linear tickets inline.** So
   after iteration N the working tree is clean and Linear is up-to-date — the
   ideal starting condition for iteration N+1.

## Run it

```powershell
pwsh tools/autonomous-sprint-loop.ps1                       # defaults: 20 iters, batch 6
pwsh tools/autonomous-sprint-loop.ps1 -MaxIterations 40 -BatchSize 4
pwsh tools/autonomous-sprint-loop.ps1 -Focus tagging        # restrict to one area
pwsh tools/autonomous-sprint-loop.ps1 -RateLimitCooldownMin 0   # hard-stop on quota hit
```

Per-iteration logs land under `logs/autonomous-loop/iter-NNN-<timestamp>.log`,
plus a per-run summary at `logs/autonomous-loop/run-<timestamp>.log`.

## Stop it cleanly

From any terminal:

```powershell
New-Item -ItemType File -Path .claude/state/autonomous-loop-stop.marker
```

The loop checks for that marker before each iteration. It does **not**
interrupt an in-flight sprint — that would risk a half-committed state.

## How quota interacts with the loop

Claude Max enforces a rolling 5-hour usage window. When `claude -p` returns a
rate-limit / quota message:

- Loop scans the iter log for `rate limit`, `usage limit`, `quota exceeded`,
  `Too many requests`, `5-hour limit reached`, etc.
- If detected and `RateLimitCooldownMin > 0` (default 300 = 5h): loop sleeps,
  **re-runs the same iteration index**, and continues.
- If `RateLimitCooldownMin = 0`: loop stops; you restart manually.

You can also detect quota status before kicking the loop off with `/status` in
a regular interactive session.

## Safety knobs (already wired)

| Lever | Default | What it bounds |
|---|---|---|
| `-MaxIterations` | 20 | Hard cap on iterations regardless of backlog |
| `-BatchSize` | 6 | Tickets per sprint (smaller = more commits, less blast radius per failure) |
| `-SleepBetweenSec` | 20 | Cool-down to let lefthook/CI/git settle between iters |
| `-RateLimitCooldownMin` | 300 | Sleep when Claude Max quota hit; 0 = hard stop instead |
| `--no-session-persistence` | always | Each iter's session isn't resumable — keeps disk clean |
| `--permission-mode bypassPermissions` | always | No human-gated tool prompts |

There is **no `--max-budget-usd`** — that flag is API-only and would be
silently ignored on Max. Your actual budget is your Max quota window.

## When the loop terminates

- Stop marker present (graceful).
- `$MaxIterations` reached (hard cap).
- Sprint's output log matches one of: `No open tickets`, `Backlog is empty`,
  `0 tickets selected`, `Nothing to do` (means /sprint-execute Phase 1 found
  nothing to do).
- Rate-limit hit AND `-RateLimitCooldownMin 0` (you opted to stop instead of
  sleep).
- You Ctrl-C the loop (the in-flight `claude` process keeps running until it
  finishes its current iteration — best stopped via the marker for clean
  hand-off).

## What it does NOT do

- Doesn't auto-merge PRs (sprint pushes direct to main per
  `CLAUDE.local.md`; no PRs created).
- Doesn't run tests outside `/sprint-execute`'s own verification.
- Doesn't restart on transient failure — non-zero exit is logged and the
  loop continues to the next iteration anyway. If three iterations in a row
  fail with the same error, check the iter log and stop the loop.
- Doesn't notify on completion — tail the run log if you want to know when
  it's done:
  ```powershell
  Get-Content -Wait -Tail 20 logs/autonomous-loop/run-*.log | Select-Object -Last 1
  ```

## First run — sanity check before unleashing

Recommended sequence the first time:

```powershell
# 1) Single iteration, ensure it lands cleanly (sprint commits + pushes + closes tickets)
pwsh tools/autonomous-sprint-loop.ps1 -MaxIterations 1

# 2) Verify git tree is clean and Linear tickets you expected are closed
git status
# (check Linear board)

# 3) Now let it run
pwsh tools/autonomous-sprint-loop.ps1 -MaxIterations 20
```
