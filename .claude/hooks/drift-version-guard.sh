#!/usr/bin/env bash
# PostToolUse Write|Edit hook — guard against schema-table edits without
# a corresponding schemaVersion bump.
#
# When a file in lib/core/storage/drift/tables/ is modified, check the
# session manifest for whether app_database.dart has also been touched.
# If not, emit a stderr warning. Non-blocking.
#
# Pairs with the /drift-migration skill (which the user invokes when they
# decide to migrate). This hook catches the silent-corruption path: editing
# a table schema without bumping schemaVersion.

set -euo pipefail

JSON=$(cat)

# Detect Python (same pattern as track-session-files.sh)
if command -v py &>/dev/null; then
  PY_CMD="py -3"
elif command -v python3 &>/dev/null; then
  PY_CMD="python3"
else
  exit 0
fi

HELPER=".claude/hooks/parse_hook_json.py"
[[ -f "$HELPER" ]] || exit 0

FIELDS=$(echo "$JSON" | $PY_CMD "$HELPER" session_id tool_input.file_path tool_response.filePath cwd 2>/dev/null) || exit 0
SESSION_ID=$(echo "$FIELDS" | sed -n '1p')
FILE_PATH_1=$(echo "$FIELDS" | sed -n '2p')
FILE_PATH_2=$(echo "$FIELDS" | sed -n '3p')
FILE="${FILE_PATH_1:-$FILE_PATH_2}"

[[ -z "${SESSION_ID:-}" || -z "${FILE:-}" ]] && exit 0

# Only act on files inside lib/core/storage/drift/tables/
case "$FILE" in
  *lib/core/storage/drift/tables/*.dart) : ;;
  *) exit 0 ;;
esac

# Look at the session manifest (built by track-session-files.sh).
# Missing manifest = first edit of the session = app_database NOT yet touched.
MANIFEST_DIR="${TMPDIR:-/tmp}/.claude-session-files"
MANIFEST="$MANIFEST_DIR/$SESSION_ID"

if [[ -f "$MANIFEST" ]] && grep -qE '(^|/)app_database\.dart$' "$MANIFEST" 2>/dev/null; then
  exit 0  # User is on it.
fi

TABLE=$(basename "$FILE")
{
  echo "⚠ drift-version-guard: ${TABLE} changed, but app_database.dart not yet touched this session."
  echo "  Drift schemas with new columns / tables / removed fields require a"
  echo "  schemaVersion bump and a migration step in app_database.dart."
  echo "  → Use the /drift-migration skill to scaffold the migration safely."
  echo "  → If this edit doesn't change the schema (rename, comment, formatting)"
  echo "    you can ignore this nudge."
} >&2

exit 0
