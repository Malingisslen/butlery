#!/usr/bin/env bash
# Stop hook: Run dart analyze to catch errors before Claude declares "done".
# Only runs when .dart files have been modified (staged or unstaged).
# Blocks Claude from stopping if analyze finds issues (exit 2 + reason).

set -euo pipefail

# Check if any dart files were modified
MODIFIED_DART=$(git diff --name-only 2>/dev/null | grep '\.dart$' || true)
STAGED_DART=$(git diff --cached --name-only 2>/dev/null | grep '\.dart$' || true)

if [ -z "$MODIFIED_DART" ] && [ -z "$STAGED_DART" ]; then
  exit 0
fi

# Run dart analyze
OUTPUT=$(dart analyze --fatal-infos 2>&1) || {
  # Analyze failed - block Claude from stopping
  # Escape for JSON and truncate to last 20 lines
  TRIMMED=$(echo "$OUTPUT" | tail -20)
  ESCAPED=$(echo "$TRIMMED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/ /g' | tr '\n' ' ')
  echo "{\"decision\":\"block\",\"reason\":\"dart analyze found issues — fix before continuing: $ESCAPED\"}"
  exit 0
}

exit 0
