#!/usr/bin/env bash
# SessionStart hook: reminds to run /org-retro once a scheduled retro window has passed
# and that retro hasn't been logged yet. Deterministic (date math + a scan of events.jsonl);
# does NO analysis itself — that's the /org-retro skill. Daily lock; fails open.
# See docs/org/metrics/.

set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo python3)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
SCHED="$PROJECT_DIR/docs/org/metrics/retro-schedule.json"
EVENTS="$PROJECT_DIR/docs/org/metrics/events.jsonl"
LOCK="${TMPDIR:-/tmp}/.org-retro-due-lock"

[ -f "$SCHED" ] || exit 0

TODAY=$($PYTHON -c "import datetime;print(datetime.date.today().isoformat())" 2>/dev/null || echo "")
if [ -n "$TODAY" ] && [ -f "$LOCK" ] && [ "$(cat "$LOCK" 2>/dev/null)" = "$TODAY" ]; then exit 0; fi

DUE=$($PYTHON - "$SCHED" "$EVENTS" <<'PY' 2>/dev/null || true
import json, sys, datetime
try:
    sched = json.load(open(sys.argv[1]))
    go = datetime.date.fromisoformat(sched["goLive"][:10])
except Exception:
    sys.exit(0)
done = set()
try:
    for line in open(sys.argv[2], encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("type") == "retro" and o.get("mode"):
            done.add(o["mode"])
except Exception:
    pass
today = datetime.date.today()
out = []
for r in sched.get("retros", []):
    m, d = r.get("mode"), r.get("afterDays", 0)
    if not m or m in done:
        continue
    if (today - go).days >= d:
        out.append(f"{m} (due {d}d after go-live {go.isoformat()})")
print("\n".join(out))
PY
)

[ -z "$DUE" ] && exit 0
[ -n "$TODAY" ] && printf '%s' "$TODAY" > "$LOCK" 2>/dev/null || true

$PYTHON - "$DUE" <<'PY'
import json, sys
due = sys.argv[1]
msg = (
    "ROLE-ORG RETRO DUE. A scheduled retrospective window has passed:\n" + due + "\n\n"
    "Run /org-retro <mode> (shakedown or full) when convenient — it reads the event log + ADRs + "
    "world-watch state + freshness markers, scores how the role-org is performing, does a manual "
    "false-negative spot-check, and recommends concrete tuning. Interactive/$0; files nothing. "
    "Running it logs a retro event, which clears this reminder. See docs/org/metrics/README.md."
)
print(json.dumps({"additionalContext": msg}))
PY
