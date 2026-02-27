#!/usr/bin/env bash
# SessionStart hook (compact): Injects the session checkpoint as additionalContext
# so the post-compaction session can pick up where it left off.
#
# Token budget: keep total injection under ~200 lines to avoid wasting
# the space that compaction just freed.

set -euo pipefail

MEMORY_DIR="/root/.claude/projects/-home-user-butlery/memory"
CHECKPOINT_FILE="$MEMORY_DIR/current-state.md"

# Only inject if checkpoint exists and is recent (within last 30 minutes)
if [ ! -f "$CHECKPOINT_FILE" ]; then
  exit 0
fi

FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$CHECKPOINT_FILE" 2>/dev/null || echo 0) ))
if [ "$FILE_AGE" -gt 1800 ]; then
  exit 0
fi

# Read checkpoint (core session state - always include)
CHECKPOINT_CONTENT=$(cat "$CHECKPOINT_FILE")

# Topic files (patterns.md, interview-decisions.md) are no longer injected here.
# Auto-memory loads MEMORY.md at session start and reads topic files on demand.

CONTEXT="SESSION RECOVERED AFTER COMPACTION - Read this carefully before continuing.

${CHECKPOINT_CONTENT}"

# Output as JSON with additionalContext
python3 -c "
import json, sys
context = sys.stdin.read()
print(json.dumps({'additionalContext': context}))
" <<< "$CONTEXT"
