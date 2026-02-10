#!/usr/bin/env bash
# SessionStart hook (compact): Injects the session checkpoint as additionalContext
# so the post-compaction session has the full state from before compaction.

set -euo pipefail

MEMORY_DIR="/root/.claude/projects/-home-user-butlery/memory"
CHECKPOINT_FILE="$MEMORY_DIR/current-state.md"

# Only inject if checkpoint exists and is recent (within last 30 minutes)
if [ ! -f "$CHECKPOINT_FILE" ]; then
  exit 0
fi

# Check if file was modified in the last 30 minutes
FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$CHECKPOINT_FILE" 2>/dev/null || echo 0) ))
if [ "$FILE_AGE" -gt 1800 ]; then
  exit 0
fi

# Read checkpoint content
CHECKPOINT_CONTENT=$(cat "$CHECKPOINT_FILE")

# Read topic files for richer context
PATTERNS=""
if [ -f "$MEMORY_DIR/patterns.md" ]; then
  PATTERNS=$(cat "$MEMORY_DIR/patterns.md")
fi

INTERVIEW=""
if [ -f "$MEMORY_DIR/interview-decisions.md" ]; then
  INTERVIEW=$(cat "$MEMORY_DIR/interview-decisions.md")
fi

# Output as JSON with additionalContext
# Escape for JSON: replace newlines, backslashes, quotes, tabs
CONTEXT="SESSION RECOVERED AFTER COMPACTION - Read this carefully before continuing.

$CHECKPOINT_CONTENT

---
$PATTERNS

---
$INTERVIEW"

# Use python for reliable JSON escaping
python3 -c "
import json, sys
context = sys.stdin.read()
print(json.dumps({'additionalContext': context}))
" <<< "$CONTEXT"
