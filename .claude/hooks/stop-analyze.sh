#!/usr/bin/env bash
# Stop hook: Run dart analyze to catch errors before Claude declares "done".
# Only runs when .dart files have been modified (staged, unstaged, or untracked).
# Blocks Claude from stopping if analyze finds issues.
# On PERSISTENT failures (same error twice), instructs Claude to file a Linear ticket.

set -euo pipefail

# Detect Python command once (avoids repeated failed lookups)
if command -v py &>/dev/null; then
  PY_CMD="py -3"
elif command -v python3 &>/dev/null; then
  PY_CMD="python3"
else
  PY_CMD=""
fi

# JSON-escape stdin for embedding in a JSON string value.
json_escape() {
  if [ -n "$PY_CMD" ]; then
    $PY_CMD -c "import json,sys; print(json.dumps(sys.stdin.read().strip())[1:-1])" 2>/dev/null
  else
    tr '\n\r\t' '   '
  fi
}

# Check if any dart files were modified
MODIFIED_DART=$(git diff --name-only 2>/dev/null | grep '\.dart$' || true)
STAGED_DART=$(git diff --cached --name-only 2>/dev/null | grep '\.dart$' || true)
UNTRACKED_DART=$(git ls-files --others --exclude-standard '*.dart' 2>/dev/null | head -1)

if [ -z "$MODIFIED_DART" ] && [ -z "$STAGED_DART" ] && [ -z "$UNTRACKED_DART" ]; then
  exit 0
fi

LAST_FAILURE_FILE="${TMPDIR:-/tmp}/.stop-analyze-last-failure"

# Run dart analyze
OUTPUT=$(dart analyze --fatal-infos 2>&1) || {
  # Analyze failed - check if this is a persistent failure
  TRIMMED=$(echo "$OUTPUT" | tail -20 | tr -d '\r')

  # Hash the failure output for comparison
  if command -v sha256sum &>/dev/null; then
    HASH=$(echo "$TRIMMED" | sha256sum | cut -d' ' -f1)
  elif [ -n "$PY_CMD" ]; then
    HASH=$(echo "$TRIMMED" | $PY_CMD -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())" 2>/dev/null || echo "nohash")
  else
    HASH="nohash"
  fi

  PREV_HASH=""
  if [ -f "$LAST_FAILURE_FILE" ]; then
    PREV_HASH=$(cat "$LAST_FAILURE_FILE" 2>/dev/null || echo "")
  fi

  echo "$HASH" > "$LAST_FAILURE_FILE"

  ESCAPED=$(echo "$TRIMMED" | json_escape)

  if [ "$HASH" = "$PREV_HASH" ] && [ "$HASH" != "nohash" ]; then
    echo "{\"decision\":\"block\",\"reason\":\"PERSISTENT dart analyze failure (identical to previous stop attempt). Do NOT retry fixing — instead create a Linear ticket with label 'bug' for this issue, then inform the user what was filed: $ESCAPED\"}"
  else
    echo "{\"decision\":\"block\",\"reason\":\"dart analyze found issues — fix before continuing: $ESCAPED\"}"
  fi
  exit 0
}

# Analyze passed — clean up any previous failure record
rm -f "$LAST_FAILURE_FILE"
exit 0
