#!/usr/bin/env bash
# SessionStart hook: deterministically checks whether any role's world-watch scan
# is due (now - lastScan >= cadence) and, if so, injects a reminder to run
# /world-watch. Does NO scanning itself — that's the skill's job (interactive, $0
# on Max). Fails open: any error exits 0 so it never blocks a session.
#
# See docs/architecture/ROLE_ORG_DESIGN.md.

set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
STATE_FILE="$PROJECT_DIR/docs/org/world-watch/state.json"
LOCK_FILE="${TMPDIR:-/tmp}/.world-watch-due-lock"

[ -f "$STATE_FILE" ] || exit 0

# At most one reminder per day (parallel sessions / multiple starts won't nag).
TODAY=$($PYTHON -c "import datetime;print(datetime.date.today().isoformat())" 2>/dev/null || echo "")
if [ -n "$TODAY" ] && [ -f "$LOCK_FILE" ]; then
  if [ "$(cat "$LOCK_FILE" 2>/dev/null)" = "$TODAY" ]; then exit 0; fi
fi

DUE=$($PYTHON - "$STATE_FILE" <<'PY' 2>/dev/null || true
import json, sys, datetime
try:
    st = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
days = st.get("cadenceDays", {"weekly":7,"monthly":30,"quarterly":90})
today = datetime.date.today()
due = []
for r in st.get("roles", []):
    last = r.get("lastScan")
    window = days.get(r.get("cadence","weekly"), 7)
    if not last:
        due.append(f"{r['role']} ({r.get('cadence')}, last: never)")
        continue
    try:
        d = datetime.date.fromisoformat(last[:10])
        if (today - d).days >= window:
            due.append(f"{r['role']} ({r.get('cadence')}, last: {last[:10]})")
    except Exception:
        due.append(f"{r['role']} ({r.get('cadence')}, last: unparseable)")
print("\n".join(due))
PY
)

[ -z "$DUE" ] && exit 0

# Claim the daily lock so we remind at most once/day.
[ -n "$TODAY" ] && printf '%s' "$TODAY" > "$LOCK_FILE" 2>/dev/null || true

$PYTHON - "$DUE" <<'PY'
import json, sys
due = sys.argv[1]
msg = (
    "WORLD-WATCH DUE (role-org MVP). These role scans are due:\n" + due + "\n\n"
    "Run /world-watch in the background, without announcing it or waiting for input. "
    "It polls each due role's sources, diffs against the stored snapshot, impact-checks "
    "deltas against the role's dossier, and routes material findings per authority "
    "(auto-ticket -> Linear; escalate-human -> Linear ticket labelled for Malin). "
    "Stay silent unless something material is found. If a scan finds nothing, still "
    "update lastScan in docs/org/world-watch/state.json so it doesn't re-fire. "
    "See docs/architecture/ROLE_ORG_DESIGN.md."
)
print(json.dumps({"additionalContext": msg}))
PY
