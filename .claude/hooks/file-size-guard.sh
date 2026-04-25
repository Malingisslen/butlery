#!/usr/bin/env bash
# 500-line guard — soft warning, non-blocking.
# Warns when a .dart file Claude just wrote/edited exceeds 500 lines,
# unless it is on the allowlist or carries the local-override sentinel.
#
# Tiers:
#   1. Allowlist:  `docs/architecture/ACCEPTED_LARGE_FILES.md` (basename match in backticks)
#   2. Sentinel:   `// claude:large-file-ok — <reason>` in the file's first 10 lines
#   3. Warn:       stderr message; exit 0 so the write still succeeds

set -euo pipefail

JSON=$(cat)

FILE=$(printf '%s' "$JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get('tool_input',{}).get('file_path','') or d.get('tool_response',{}).get('filePath',''))
" 2>/dev/null || true)

[[ -z "${FILE:-}" ]] && exit 0
[[ "$FILE" != *.dart ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# Skip generated files unconditionally
case "$FILE" in
  *.g.dart|*.freezed.dart|*app_localizations*) exit 0 ;;
esac

LINES=$(wc -l < "$FILE" 2>/dev/null | tr -d ' \r' || echo 0)
[[ -z "$LINES" || "$LINES" -le 500 ]] && exit 0

# Tier 2: local sentinel
if head -n 10 "$FILE" 2>/dev/null | grep -qE '^//\s*claude:large-file-ok'; then
  exit 0
fi

# Tier 1: allowlist
BASENAME=$(basename "$FILE")
ALLOWLIST="docs/architecture/ACCEPTED_LARGE_FILES.md"
if [[ -f "$ALLOWLIST" ]] && grep -qF "\`${BASENAME}\`" "$ALLOWLIST"; then
  exit 0
fi

# Tier 3: soft warning (visible to the model on next turn)
{
  echo "⚠ file-size-guard: ${BASENAME} is now ${LINES} lines (limit: 500)."
  echo "  Options:"
  echo "    • Refactor with the facade pattern (preferred — see CLAUDE.md rule #2)"
  echo "    • Add to ${ALLOWLIST} with a one-line reason, or"
  echo "    • Add '// claude:large-file-ok — <reason>' as the first comment in the file."
} >&2

exit 0
