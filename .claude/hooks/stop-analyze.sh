#!/usr/bin/env bash
# Stop hook: Run dart analyze to catch errors before Claude declares "done".
#
# Session-aware: only blocks on errors in files THIS session modified.
# The session manifest is built incrementally by track-session-files.sh (a
# PostToolUse hook on Write|Edit) and lives at
#   $TMPDIR/.claude-session-files/$SESSION_ID
#
# Decision tree:
#   - No session_id in stdin           -> fall back to legacy behavior
#                                         (block on any dart analyze error).
#   - session_id present, no manifest  -> this session modified zero .dart
#                                         files; any error belongs to a
#                                         parallel session. Exit 0 (don't
#                                         block). Fixes the deadlock where
#                                         Session A's uncommitted lint
#                                         blocks a read-only Session B.
#   - session_id + manifest            -> partition dart analyze output by
#                                         file ownership (paths normalized
#                                         to forward-slashes so Windows
#                                         backslash output matches the
#                                         manifest format). Block only on
#                                         OUR errors; ignore FOREIGN errors.
#
# On PERSISTENT failures (same error twice in this session), instructs
# Claude to file a Linear ticket instead of re-trying the same fix.

set -euo pipefail

# Read stdin JSON (session_id, hook metadata)
INPUT=$(cat 2>/dev/null || echo "{}")

# Detect Python command once (avoids repeated failed lookups)
if command -v py &>/dev/null; then
  PY_CMD="py -3"
elif command -v python3 &>/dev/null; then
  PY_CMD="python3"
else
  PY_CMD=""
fi

# Extract session_id from stdin JSON (uses helper for Windows backslash safety)
SESSION_ID=""
if [ -n "$PY_CMD" ]; then
  SESSION_ID=$(echo "$INPUT" | $PY_CMD .claude/hooks/parse_hook_json.py session_id 2>/dev/null || echo "")
fi

# Load session manifest (built by track-session-files.sh)
MANIFEST_DIR="${TMPDIR:-/tmp}/.claude-session-files"
SESSION_FILES_LOADED=false
SESSION_HAS_NO_EDITS=false
MANIFEST=""

if [ -n "$SESSION_ID" ]; then
  if [ -f "$MANIFEST_DIR/$SESSION_ID" ]; then
    MANIFEST="$MANIFEST_DIR/$SESSION_ID"
    SESSION_FILES_LOADED=true
  else
    # We know the session_id but track-session-files.sh never recorded an
    # Edit/Write for it. This session is read-only: any dart analyze error
    # must belong to a parallel session or uncommitted work from outside.
    SESSION_HAS_NO_EDITS=true
  fi
fi

# JSON-escape stdin for embedding in a JSON string value.
json_escape() {
  if [ -n "$PY_CMD" ]; then
    $PY_CMD -c "import json,sys; print(json.dumps(sys.stdin.read().strip())[1:-1])" 2>/dev/null
  else
    tr '\n\r\t' '   '
  fi
}

# Check if any dart files were modified
MODIFIED_DART=$(git diff --name-only 2>/dev/null | grep '\.dart$' || true)
STAGED_DART=$(git diff --cached --name-only 2>/dev/null | grep '\.dart$' || true)
UNTRACKED_DART=$(git ls-files --others --exclude-standard '*.dart' 2>/dev/null | head -1)

if [ -z "$MODIFIED_DART" ] && [ -z "$STAGED_DART" ] && [ -z "$UNTRACKED_DART" ]; then
  exit 0
fi

# Session-aware short-circuit: if we know the session_id AND the session
# manifest doesn't exist, this session made zero Dart edits. Any lint in
# the working tree belongs to a parallel session — don't block. See BUT-398.
if [ "$SESSION_HAS_NO_EDITS" = true ]; then
  exit 0
fi

# Scope failure hash per session to prevent cross-session interference
LAST_FAILURE_FILE="${TMPDIR:-/tmp}/.stop-analyze-last-failure"
if [ -n "$SESSION_ID" ]; then
  LAST_FAILURE_FILE="${TMPDIR:-/tmp}/.stop-analyze-last-failure-$SESSION_ID"
fi

# Run dart analyze
OUTPUT="$(dart analyze --fatal-infos 2>&1)" || {

  # Partition errors by session ownership (if manifest available)
  if [ "$SESSION_FILES_LOADED" = true ] && [ -n "$PY_CMD" ]; then
    PARTITION_SCRIPT="$(mktemp)"
    cat > "$PARTITION_SCRIPT" << 'PYEOF'
import sys, re

def normalize(p):
    # Manifest stores forward-slash repo-relative paths; dart analyze on
    # Windows emits backslashes. Canonicalize both sides to forward-slash
    # lowercase for comparison so ownership matches cross-platform.
    return p.replace('\\', '/').lower()

manifest_path = sys.argv[1]
with open(manifest_path) as f:
    our_files = set(normalize(line.strip()) for line in f if line.strip())

output = sys.stdin.read()
our_lines = []
foreign_lines = []

pattern = re.compile(r'^\s*\S+\s+-\s+(\S+\.dart):\d+:\d+\s+-\s+')

for line in output.splitlines():
    m = pattern.match(line)
    if m:
        file_path = normalize(m.group(1))
        if file_path in our_files:
            our_lines.append(line)
        else:
            foreign_lines.append(line)

our_count = len(our_lines)
foreign_count = len(foreign_lines)

if our_count > 0:
    filtered = '\n'.join(our_lines)
    if foreign_count > 0:
        filtered += '\n\n(' + str(foreign_count) + ' issue(s) in files modified by another session — ignored.)'
    print('OUR_ERRORS\n' + filtered)
elif foreign_count > 0:
    print('FOREIGN_ONLY\n' + str(foreign_count) + ' issue(s) all in files NOT modified by this session — likely another parallel session.')
else:
    print('FALLBACK\n' + output)
PYEOF
    PARTITION="$($PY_CMD "$PARTITION_SCRIPT" "$MANIFEST" <<< "$OUTPUT" 2>/dev/null)" || PARTITION="FALLBACK
$OUTPUT"
    rm -f "$PARTITION_SCRIPT"

    CLASSIFICATION=$(echo "$PARTITION" | head -1)
    BODY=$(echo "$PARTITION" | tail -n +2)

    case "$CLASSIFICATION" in
      FOREIGN_ONLY)
        # All errors are in other sessions' files — don't block
        exit 0
        ;;
      OUR_ERRORS)
        # Errors in our files — block with filtered output
        OUTPUT="$BODY"
        ;;
      *)
        # FALLBACK — no manifest or unparsable, use original OUTPUT
        ;;
    esac
  fi

  # Persistent failure detection
  TRIMMED=$(echo "$OUTPUT" | tail -20 | tr -d '\r')

  # Hash the failure output for comparison
  if command -v sha256sum &>/dev/null; then
    HASH=$(echo "$TRIMMED" | sha256sum | cut -d' ' -f1)
  elif [ -n "$PY_CMD" ]; then
    HASH=$(echo "$TRIMMED" | $PY_CMD -c "import hashlib,sys; print(hashlib.sha256(sys.stdin.read().encode()).hexdigest())" 2>/dev/null || echo "nohash")
  else
    HASH="nohash"
  fi

  PREV_HASH=""
  if [ -f "$LAST_FAILURE_FILE" ]; then
    PREV_HASH=$(cat "$LAST_FAILURE_FILE" 2>/dev/null || echo "")
  fi

  echo "$HASH" > "$LAST_FAILURE_FILE"

  ESCAPED=$(echo "$TRIMMED" | json_escape)

  if [ "$HASH" = "$PREV_HASH" ] && [ "$HASH" != "nohash" ]; then
    echo "{\"decision\":\"block\",\"reason\":\"PERSISTENT dart analyze failure (identical to previous stop attempt). Do NOT retry fixing — instead create a Linear ticket with label 'bug' for this issue, then inform the user what was filed: $ESCAPED\"}"
  else
    echo "{\"decision\":\"block\",\"reason\":\"dart analyze found issues — fix before continuing: $ESCAPED\"}"
  fi
  exit 0
}

# Analyze passed — clean up any previous failure record
rm -f "$LAST_FAILURE_FILE"
exit 0
