#!/usr/bin/env bash
# PostToolUse Write|Edit hook — regenerate Flutter l10n when an ARB file changes.
#
# ARB files (lib/l10n/app_*.arb) are the source of truth; the 11k-line
# app_localizations_*.dart files are generated. Editing an ARB without
# regenerating leaves the Swedish/English bindings stale and silently
# breaks UI strings until the next build. This hook bridges that gap.

set -euo pipefail

JSON=$(cat)

# Dispatcher fast path — see post-edit-dispatch.sh. Falls back to parsing stdin
# itself so this script stays runnable standalone.
if [[ "${BUTLERY_HOOK_DISPATCH:-}" == "1" ]]; then
  FILE="${BUTLERY_HOOK_FILE:-}"
else
FILE=$(printf '%s' "$JSON" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print(d.get('tool_input',{}).get('file_path','') or d.get('tool_response',{}).get('filePath',''))
" 2>/dev/null || true)
fi

[[ -z "${FILE:-}" ]] && exit 0

# Only act on ARB files in lib/l10n/
case "$FILE" in
  *lib/l10n/*.arb|lib/l10n/*.arb)
    : ;;
  *)
    exit 0 ;;
esac

if ! command -v flutter >/dev/null 2>&1; then
  echo "⚠ regenerate-l10n: flutter not on PATH — skipping codegen for $(basename "$FILE")" >&2
  exit 0
fi

# Run codegen. Swallow stdout (verbose), surface stderr only if it failed.
OUT=$(flutter gen-l10n 2>&1) || {
  {
    echo "✗ regenerate-l10n: flutter gen-l10n FAILED after edit to $(basename "$FILE")"
    echo "  Last lines:"
    printf '%s\n' "$OUT" | tail -n 10 | sed 's/^/    /'
    echo "  → Fix the ARB syntax / placeholder mismatch before next edit."
  } >&2
  exit 0  # non-blocking: write already succeeded; just nudge
}

echo "✓ regenerate-l10n: app_localizations_*.dart regenerated from $(basename "$FILE")" >&2
exit 0
