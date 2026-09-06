#!/usr/bin/env bash
# SessionStart hook: suggest analyze monitor only when .dart files are modified.
set -euo pipefail

DART_CHANGES=$(git diff --name-only 2>/dev/null | grep '\.dart$' || true)
STAGED_DART=$(git diff --cached --name-only 2>/dev/null | grep '\.dart$' || true)

if [ -n "$DART_CHANGES" ] || [ -n "$STAGED_DART" ]; then
  echo '{"additionalContext":"Modified .dart files detected. Start the continuous dart analyze monitor: use Monitor tool with command `bash .claude/hooks/monitors/analyze-watcher.sh`, persistent: true, timeout_ms: 3600000, description: \"Continuous dart analyze\". This runs silently — notifications only fire when the issue count changes."}'
fi
