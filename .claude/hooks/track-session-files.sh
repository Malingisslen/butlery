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

RESULT=$($PY_CMD -c "
import json, sys, os, re

data = json.loads(sys.stdin.read())
session_id = data.get('session_id', '')
file_path = (data.get('tool_input', {}).get('file_path', '')
             or data.get('tool_response', {}).get('filePath', ''))

if not session_id or not file_path:
    sys.exit(0)

# Normalize to repo-relative forward-slash path
fp = file_path.replace('\\\\', '/')

cwd = data.get('cwd', os.getcwd()).replace('\\\\', '/')
cwd = cwd.rstrip('/')

def normalize_drive(p):
    # /c/... -> C:/...
    m = re.match(r'^/([a-zA-Z])/(.*)', p)
    if m:
        return m.group(1).upper() + ':/' + m.group(2)
    # c:/... -> C:/...
    m = re.match(r'^([a-zA-Z]):/(.*)', p)
    if m:
        return m.group(1).upper() + ':/' + m.group(2)
    return p

fp = normalize_drive(fp)
cwd = normalize_drive(cwd)

if fp.startswith(cwd + '/'):
    fp = fp[len(cwd) + 1:]

print(f'{session_id}\n{fp}')
" <<< "$INPUT" 2>/dev/null) || exit 0

SESSION_ID=$(echo "$RESULT" | head -1)
REL_PATH=$(echo "$RESULT" | tail -1)

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
