#!/usr/bin/env bash
# SessionStart hook (compact): Injects the session checkpoint as additionalContext
# so the post-compaction session can pick up where it left off.
#
# Token budget: keep total injection under ~200 lines to avoid wasting
# the space that compaction just freed.

set -euo pipefail

# Cross-platform Python detection
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")

# Use CLAUDE_PROJECT_DIR or detect via git
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

# Derive memory dir (same logic as pre-compact.sh)
MEMORY_DIR=$($PYTHON -c "
import os, re, sys
p = sys.argv[1].replace(os.sep, '/')
if len(p) > 2 and p[0] == '/' and p[2] == '/':
    p = p[1].upper() + ':' + p[2:]
encoded = re.sub(r'[:/]', '-', p)
home = os.path.expanduser('~').replace(os.sep, '/')
print(home + '/.claude/projects/' + encoded + '/memory')
" "$PROJECT_DIR")

CHECKPOINT_FILE="$MEMORY_DIR/current-state.md"

# Only inject if checkpoint exists and is recent (within last 30 minutes)
if [ ! -f "$CHECKPOINT_FILE" ]; then
  exit 0
fi

# Portable file age check (no GNU stat dependency)
FILE_AGE=$($PYTHON -c "
import os, time
try:
    mtime = os.path.getmtime('$CHECKPOINT_FILE')
    print(int(time.time() - mtime))
except Exception:
    print(9999)
")

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
$PYTHON -c "
import json, sys
context = sys.stdin.read()
print(json.dumps({'additionalContext': context}))
" <<< "$CONTEXT"
