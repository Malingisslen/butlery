#!/usr/bin/env bash
# PostToolUse hook: detect firebase deploy and inject monitor instruction.
set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

# Fast path: skip Python entirely if command doesn't mention firebase/deploy
echo "$INPUT" | grep -qE 'firebase|deploy' || exit 0

PY_CMD="py -3"
command -v py &>/dev/null || PY_CMD="python3"

CMD=$(echo "$INPUT" | $PY_CMD .claude/hooks/parse_hook_json.py tool_input.command 2>/dev/null) || exit 0

if echo "$CMD" | grep -qE 'firebase\s+deploy|npm\s+run\s+deploy'; then
  echo '{"additionalContext":"Firebase deploy detected. Start the firebase error monitor now: use Monitor tool with command `bash .claude/hooks/monitors/firebase-errors.sh`, persistent: true, timeout_ms: 3600000, description: \"Firebase errors after deploy\". Continue working — errors will stream in as notifications."}'
fi
