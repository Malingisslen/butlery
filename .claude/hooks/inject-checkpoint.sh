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

# Topic files: only include if they have real content (not just headers/templates).
# Truncate to keep total payload reasonable. MEMORY.md is already injected
# separately by Claude Code, so don't duplicate it here.
EXTRAS=""

for topic_file in "patterns.md" "interview-decisions.md"; do
  filepath="$MEMORY_DIR/$topic_file"
  [ -f "$filepath" ] || continue
  # Count non-empty, non-comment lines
  real_lines=$(grep -cvE '^\s*$|^\s*#|^\s*>|^\s*<!--' "$filepath" 2>/dev/null || true)
  if [ -n "$real_lines" ] && [ "$real_lines" -gt 0 ]; then
    EXTRAS="${EXTRAS}
---
$(head -50 "$filepath")"
  fi
done

CONTEXT="SESSION RECOVERED AFTER COMPACTION - Read this carefully before continuing.

${CHECKPOINT_CONTENT}${EXTRAS}"

# Output as JSON with additionalContext
python3 -c "
import json, sys
context = sys.stdin.read()
print(json.dumps({'additionalContext': context}))
" <<< "$CONTEXT"
