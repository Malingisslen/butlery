#!/usr/bin/env bash
# Continuous dart analyze on modified files. Emits only when issue count changes.
set -euo pipefail

PREV_COUNT=""

while true; do
  DART_FILES=$(git diff --name-only 2>/dev/null | grep '\.dart$' || true)
  STAGED=$(git diff --cached --name-only 2>/dev/null | grep '\.dart$' || true)
  ALL_DART=$(echo -e "$DART_FILES\n$STAGED" | sort -u | grep -v '^$' || true)

  if [ -z "$ALL_DART" ]; then
    sleep 60
    continue
  fi

  # shellcheck disable=SC2086
  OUTPUT=$(dart analyze --fatal-infos $ALL_DART 2>&1 || true)
  COUNT=$(echo "$OUTPUT" | grep -cE '^\s*(error|warning|info)\s+[-•]' || echo "0")

  if [ "$COUNT" != "$PREV_COUNT" ]; then
    if [ "$COUNT" = "0" ]; then
      echo "dart analyze: CLEAN (was ${PREV_COUNT:-?} issues)"
    else
      FIRST=$(echo "$OUTPUT" | grep -E '^\s*(error|warning)\s+[-•]' | head -1 | sed 's/^\s*//')
      echo "dart analyze: $COUNT issues (was ${PREV_COUNT:-none}) | $FIRST"
    fi
    PREV_COUNT="$COUNT"
  fi

  sleep 60
done
