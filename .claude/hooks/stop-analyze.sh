#!/usr/bin/env bash
# Stop hook: Run dart analyze to catch errors before Claude declares "done".
# Only runs when .dart files have been modified (staged or unstaged).
# Blocks Claude from stopping if analyze finds issues.
# On PERSISTENT failures (same error twice), instructs Claude to file a Linear ticket.

set -euo pipefail

# Check if any dart files were modified
MODIFIED_DART=$(git diff --name-only 2>/dev/null | grep '\.dart$' || true)
STAGED_DART=$(git diff --cached --name-only 2>/dev/null | grep '\.dart$' || true)

if [ -z "$MODIFIED_DART" ] && [ -z "$STAGED_DART" ]; then
  exit 0
fi

LAST_FAILURE_FILE="${TMPDIR:-/tmp}/.stop-analyze-last-failure"

# Run dart analyze
OUTPUT=$(dart analyze --fatal-infos 2>&1) || {
  # Analyze failed - check if this is a persistent failure
  TRIMMED=$(echo "$OUTPUT" | tail -20)

  # Hash the failure output for comparison
  HASH=$(echo "$TRIMMED" | sha256sum 2>/dev/null | cut -d' ' -f1 || \
         echo "$TRIMMED" | python3 -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())" 2>/dev/null || \
         echo "nohash")

  PREV_HASH=""
  if [ -f "$LAST_FAILURE_FILE" ]; then
    PREV_HASH=$(cat "$LAST_FAILURE_FILE" 2>/dev/null || echo "")
  fi

  echo "$HASH" > "$LAST_FAILURE_FILE"

  ESCAPED=$(echo "$TRIMMED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g' | tr '\n' ' ')

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
