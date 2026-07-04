#!/usr/bin/env python3
"""log_event.py — append one role-org metric event to events.jsonl.

The measurement loop the /org-retro and /stakeholder-review skills reference.
It was specified in README.md but never created, so events.jsonl accumulated
nothing (only its hand-written init line) — meaning /org-retro had no data to
score. This is that helper.

Deterministic, no LLM (per CLAUDE.md cost rules). Merges whatever JSON object
you pass with an auto `ts` (UTC ISO) if absent, and appends it as one line.
Fails soft: prints a warning to stderr and exits 0 so a logging failure never
blocks the caller (a review/retro must not be aborted by its own telemetry).

Usage:
  python3 docs/org/metrics/log_event.py '{"type":"review","tier":"full","stakeholders":7,"outcome":"approve-with-conditions"}'
  python3 docs/org/metrics/log_event.py '{"type":"retro","mode":"shakedown"}'

Event types (open schema; these fields are what the skills read):
  review — plan/tier/stakeholders/findings_material/outcome/escalated_to_human/adr/tokens_est/ran
  retro  — mode/period
"""
import datetime
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
EVENTS = os.path.join(HERE, "events.jsonl")


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("log_event: expected one JSON-object argument\n")
        return 0
    try:
        evt = json.loads(sys.argv[1])
        if not isinstance(evt, dict):
            raise ValueError("event must be a JSON object")
    except Exception as e:  # noqa: BLE001 — telemetry must never raise into the caller
        sys.stderr.write(f"log_event: could not parse event ({e}); skipping\n")
        return 0

    evt.setdefault("ts", datetime.datetime.now(datetime.timezone.utc).isoformat())
    try:
        with open(EVENTS, "a", encoding="utf-8") as f:
            f.write(json.dumps(evt, ensure_ascii=False) + "\n")
    except Exception as e:  # noqa: BLE001
        sys.stderr.write(f"log_event: could not append ({e}); skipping\n")
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
