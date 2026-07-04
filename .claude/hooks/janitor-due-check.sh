#!/usr/bin/env bash
# SessionStart hook: the watchdog's watchdog. The weekly janitor runs as a
# scheduled cloud routine, but a schedule can silently stop (the 30-min
# heartbeat did exactly this — CronCreate jobs are session-scoped and died
# with their session). This deterministic check nudges if the janitor hasn't
# stamped a run in >JANITOR_MAX_DAYS, so a dead schedule surfaces same-day
# instead of drifting for weeks. Does NO maintenance itself. Fails open.

set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STAMP="$PROJECT_DIR/docs/org/janitor/last-run.json"
LOCK_FILE="${TMPDIR:-/tmp}/.janitor-due-lock"
JANITOR_MAX_DAYS=8

# At most one nudge per day across parallel sessions / restarts.
TODAY=$($PYTHON -c "import datetime;print(datetime.date.today().isoformat())" 2>/dev/null || echo "")
if [ -n "$TODAY" ] && [ -f "$LOCK_FILE" ] && [ "$(cat "$LOCK_FILE" 2>/dev/null)" = "$TODAY" ]; then
  exit 0
fi

DAYS_SINCE=$($PYTHON - "$STAMP" "$JANITOR_MAX_DAYS" <<'PY' 2>/dev/null || true
import json, sys, datetime, os
stamp, maxdays = sys.argv[1], int(sys.argv[2])
if not os.path.exists(stamp):
    print("never")   # never run — nudge
    sys.exit(0)
try:
    st = json.load(open(stamp))
    d = datetime.date.fromisoformat(st.get("lastRun", "")[:10])
    n = (datetime.date.today() - d).days
    print(str(n) if n >= maxdays else "")
except Exception:
    print("unparseable")
PY
)

[ -z "$DAYS_SINCE" ] && exit 0

[ -n "$TODAY" ] && printf '%s' "$TODAY" > "$LOCK_FILE" 2>/dev/null || true

$PYTHON - "$DAYS_SINCE" "$JANITOR_MAX_DAYS" <<'PY'
import json, sys
since, maxd = sys.argv[1], sys.argv[2]
when = "has NEVER run" if since == "never" else (
       "last-run stamp is unreadable" if since == "unparseable" else f"last ran {since} days ago (> {maxd}d)")
msg = (
    f"JANITOR OVERDUE — the weekly maintenance routine {when}. The scheduled cloud "
    "routine may have stopped (schedules die silently). When convenient, run /janitor "
    "(or re-create the schedule via /schedule). It refreshes stale dossiers, runs due "
    "world-watch roles, fires org-retro when scheduled, computes the accept-rate metric, "
    "and sweeps scratch/disk cruft — then stamps docs/org/janitor/last-run.json. "
    "This is a nudge only; don't halt what you're doing to run it."
)
print(json.dumps({"additionalContext": msg}))
PY
