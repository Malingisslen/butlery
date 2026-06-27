# Role-org metrics

Append-only **evidence trail** for the virtual role-org (world-watch · dossier-freshness · Phase-2
stakeholder-review). It lets `/org-retro` score how well the system is working and tune it — without
a metrics pipeline. $0: one JSON line per real action, written by the skills/hooks that already run.

## How to log

Any skill/hook appends one event (it must never block on this):

```
python3 docs/org/metrics/log_event.py '{"type":"review", ...}'
```

The helper stamps `ts` (UTC ISO) and fails open. Keep it to **one event per real action**.

## Event types & recommended fields

- **`world-watch`** — `role`, `sources_reached`, `sources_total`, `findings`, `filed`, `deferred`,
  `escalated`, `notes`
- **`review`** (Phase-2) — `plan` (short label), `tier` (`full`|`single`|`skip`), `stakeholders` (n),
  `findings_material` (n), `outcome` (`approve`|`approve-with-conditions`|`escalated`),
  `escalated_to_human` (bool), `adr` (id or null), `tokens_est` (n)
- **`trigger`** — `fired` (bool), `signals` (matched keywords), `ran` (bool or null) — the
  ExitPlanMode nudge; `ran` is whether the human actually ran the review
- **`freshness`** — `event` (`flag`|`refresh`), `roles` (list), `drift_found` (bool)
- **`retro`** — written by `/org-retro` itself: `mode`, `period`

The schema is open — the helper merges whatever JSON you pass; these are the fields `/org-retro`
knows how to score.

## Retro cadence

- **~3-4 days after go-live → `/org-retro shakedown`** — qualitative. Catch misfires: trigger
  over-firing & being ignored, noisy world-watch tickets, rubber-stamp reviews, a dossier error a
  review caught. Plus one **false-negative spot-check** (logs can't show what the system *missed*).
- **~3-4 weeks → `/org-retro full`** — quantitative scorecard + concrete tuning changes, once there
  are enough reviews and scan cycles to be meaningful.

> A "few days" gives thin data on purpose: world-watch is weekly/monthly and Phase-2 only runs on
> risky plans. The shakedown is a sanity check, not statistics.
