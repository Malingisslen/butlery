#!/usr/bin/env bash
# PostToolUse Write|Edit — flag changes to firestore.rules or rules-test files.
# Emits a stderr nudge so the next turn auto-invokes firestore-rules-tester
# instead of requiring the user to ask.

set -euo pipefail

JSON=$(cat)

FILE=$(printf '%s' "$JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get('tool_input',{}).get('file_path','') or d.get('tool_response',{}).get('filePath',''))
" 2>/dev/null || true)

[[ -z "${FILE:-}" ]] && exit 0

case "$FILE" in
  */firestore.rules|firestore.rules)
    {
      echo "🔔 firestore.rules changed."
      echo "   → next turn: invoke the firestore-rules-tester agent to generate"
      echo "     allow/deny tests for the diff and run them against the emulator."
      echo "     The agent auto-starts the emulator; no manual setup needed."
    } >&2
    ;;
  */__tests__/*-rules.test.ts)
    {
      echo "🔔 rules-test file changed."
      echo "   → next turn: cd functions && npm run test:rules:all (emulator auto-starts)."
    } >&2
    ;;
esac

exit 0
