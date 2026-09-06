#!/usr/bin/env bash
# Stream Firebase Functions errors as Monitor notifications.
# Polls firebase functions:log every 30s, deduplicates, emits only new ERROR/WARNING.
set -euo pipefail

SEEN_FILE="${TMPDIR:-/tmp}/.firebase-error-monitor-seen"
> "$SEEN_FILE"
cleanup() { rm -f "$SEEN_FILE" "${SEEN_FILE}.tmp"; }
trap cleanup EXIT INT TERM

# Use sha256sum (available in Git Bash via coreutils)
if command -v sha256sum &>/dev/null; then
  hash_line() { printf '%s' "$1" | sha256sum | cut -d' ' -f1; }
else
  PY_CMD="py -3"
  command -v py &>/dev/null || PY_CMD="python3"
  hash_line() { printf '%s' "$1" | $PY_CMD -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())"; }
fi

while true; do
  LOGS=$(firebase functions:log --lines 50 2>/dev/null | grep -iE '\b(error|warn|ERROR|WARNING)\b' || true)

  if [ -n "$LOGS" ]; then
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      HASH=$(hash_line "$line")
      if ! grep -qxF "$HASH" "$SEEN_FILE" 2>/dev/null; then
        echo "$HASH" >> "$SEEN_FILE"
        echo "$line"
      fi
    done <<< "$LOGS"
  fi

  if [ -f "$SEEN_FILE" ] && [ "$(wc -l < "$SEEN_FILE")" -gt 200 ]; then
    tail -200 "$SEEN_FILE" > "${SEEN_FILE}.tmp" && mv "${SEEN_FILE}.tmp" "$SEEN_FILE"
  fi

  sleep 30
done
