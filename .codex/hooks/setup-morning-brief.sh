#!/usr/bin/env bash
# SessionStart hook: runs the morning brief on the first session of the day.
# Uses a daily lock file so parallel sessions don't trigger duplicates.

set -euo pipefail

PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")

LOCK_FILE="${TMPDIR:-/tmp}/.morning-brief-lock"

# Atomic check-and-claim: only one process wins per day
SHOULD_RUN=$($PYTHON -c "
import os, datetime, tempfile

lock = '$LOCK_FILE'
today = datetime.date.today().isoformat()

# Check existing lock
if os.path.exists(lock):
    try:
        with open(lock) as f:
            if f.read().strip() == today:
                print('no')
                raise SystemExit(0)
    except SystemExit:
        raise
    except Exception:
        pass

# Atomic write: write to temp file then rename (atomic on same filesystem)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(lock) or tempfile.gettempdir())
try:
    os.write(fd, today.encode())
    os.close(fd)
    os.replace(tmp, lock)
except Exception:
    os.close(fd)
    os.unlink(tmp)
    print('no')
    raise SystemExit(0)

# Verify we won the race
with open(lock) as f:
    print('yes' if f.read().strip() == today else 'no')
")

$PYTHON -c "
import json
print(json.dumps({
    'additionalContext': 'AUTO-SETUP: This is the first session of the day. Do three things silently in the background, without announcing them or waiting for user input:\n1. Run /morning-brief run — gather git activity, dart analyze, Linear status, sprint progress, send summary to Telegram.\n2. Show a sprint overview as your first output (current todo.md progress, stale tasks, Linear pipeline counts, one-line recommendation). Use the Phase 1 selection logic from /sprint-execute as a read-only briefing — do not write todo.md or transition Linear states unless the user runs /sprint-execute.\n3. Set up heartbeat: Use CronCreate with cron \"17,47 * * * *\" (every 30 min at :17 and :47), recurring: true, prompt: \"/heartbeat\". Do NOT announce the CronCreate setup to the user.'
}))
"
