---
name: org-retro
description: Score how well the virtual role-org is working (world-watch, dossier-freshness, Phase-2 stakeholder-review) from its own committed evidence trail, and recommend concrete tuning. Two modes — shakedown (qualitative, ~days) and full (quantitative, ~weeks). Interactive and $0; reads artifacts, files nothing.
---

# /org-retro — measure & tune the role-org

Reads the evidence the system already emits and scores it against the levers that tune it. Files
nothing; outputs a retro + concrete recommendations. Mode arg: `shakedown` (default) or `full`.
See `docs/org/metrics/README.md` for the event schema.

## Read these
- `docs/org/metrics/events.jsonl` — the event trail (reviews, world-watch runs, triggers, freshness).
- `docs/org/adr/ADR-*.md` — every Phase-2 disagreement + what it caught.
- `docs/org/world-watch/state.json` — per-role lastScan, coverage, dead/blocked sources.
- `docs/org/dossier-staleness/` — current freshness markers.
- Linear, **if reachable** — world-watch tickets: how many were kept vs. closed as noise. If the
  Linear MCP is disconnected, say so and score that line as "manual".

## Scorecard — compute only what the data supports; say "insufficient data" honestly
1. **Phase-2 value** — reviews with ≥1 material finding a solo plan would miss / total. **Rubber-stamp
   rate** (`outcome: approve`, no conditions): high → the trigger is too eager.
2. **Trigger calibration** — `trigger.fired` vs. reviews actually `ran`. Over-fired-and-ignored →
   tighten the high-stakes signal list; a high-stakes change that fired nothing → loosen it.
3. **World-watch signal-to-noise** — findings filed vs. kept vs. deferred/dup. Source health from
   `state.json` (dead/blocked feeds, low coverage).
4. **Freshness accuracy** — did any review catch a **dossier** error the freshness loop should have?
   (The age-gate watch-item was one.) List them — each is a freshness miss.
5. **Cost** — est. tokens/review from events: is the full panel reserved for high-stakes plans, or
   firing on cheap ones?

## False-negative spot-check (do this manually — the logs can't show what was missed)
Pick ONE known recent external change per high-stakes role (a real CVE, an Apple/Play policy note, an
IMY/EDPB item from the last cycle) and verify it actually reached the system — a ticket/escalation, or
it's genuinely in scope for the next scheduled scan. A miss here is the scariest failure mode and is
invisible to the event trail.

## Output
A short retro:
- the scorecard (with "insufficient data" where true — in shakedown mode most lines will be),
- the spot-check result,
- **1-5 concrete tuning changes** (e.g. "add `<keyword>` to the high-stakes signal list in
  suggest-stakeholder-review.sh", "drop dead source X from state.json", "raise the single-vs-full
  panel threshold", "correct dossier role N").

Shakedown mode: focus on obvious misfires, not statistics. Then append one event:
`python3 docs/org/metrics/log_event.py '{"type":"retro","mode":"shakedown","period":"<from>..<to>"}'`.
