#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): Record files this session modifies
# into a per-session manifest for use by stop-analyze.sh.
# This enables the stop hook to distinguish "our" errors from errors
# introduced by another parallel session.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

# Detect Python
if command -v py &>/dev/null; then
  PY_CMD="py -3"
elif command -v python3 &>/dev/null; then
  PY_CMD="python3"
else
  # No Python — can't normalize paths, skip tracking
  exit 0
fi

# Extract fields using Windows-safe JSON helper
HELPER=".claude/hooks/parse_hook_json.py"
FIELDS=$(echo "$INPUT" | $PY_CMD "$HELPER" session_id tool_input.file_path tool_response.filePath cwd 2>/dev/null) || exit 0

SESSION_ID=$(echo "$FIELDS" | sed -n '1p')
FILE_PATH_1=$(echo "$FIELDS" | sed -n '2p')
FILE_PATH_2=$(echo "$FIELDS" | sed -n '3p')
CWD_RAW=$(echo "$FIELDS" | sed -n '4p')

FILE_PATH="${FILE_PATH_1:-$FILE_PATH_2}"
[ -z "$SESSION_ID" ] || [ -z "$FILE_PATH" ] && exit 0

# Normalize to repo-relative forward-slash path
REL_PATH=$($PY_CMD -c "
import sys, os, re
fp = sys.argv[1].replace('\\\\', '/')
cwd = (sys.argv[2] or os.getcwd()).replace('\\\\', '/')
cwd = cwd.rstrip('/')
def norm(p):
    m = re.match(r'^/([a-zA-Z])/(.*)', p)
    if m: return m.group(1).upper() + ':/' + m.group(2)
    m = re.match(r'^([a-zA-Z]):/(.*)', p)
    if m: return m.group(1).upper() + ':/' + m.group(2)
    return p
fp, cwd = norm(fp), norm(cwd)
if fp.startswith(cwd + '/'): fp = fp[len(cwd)+1:]
print(fp)
" "$FILE_PATH" "$CWD_RAW" 2>/dev/null) || exit 0

[ -z "$SESSION_ID" ] || [ -z "$REL_PATH" ] && exit 0

MANIFEST_DIR="${TMPDIR:-/tmp}/.claude-session-files"
mkdir -p "$MANIFEST_DIR"

# Prune manifests older than 24h (cleanup stale sessions)
find "$MANIFEST_DIR" -type f -mmin +1440 -delete 2>/dev/null || true

MANIFEST="$MANIFEST_DIR/$SESSION_ID"

# Append if not already present
if [ -f "$MANIFEST" ]; then
  grep -qxF "$REL_PATH" "$MANIFEST" 2>/dev/null || echo "$REL_PATH" >> "$MANIFEST"
else
  echo "$REL_PATH" > "$MANIFEST"
fi

exit 0
