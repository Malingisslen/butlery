#!/usr/bin/env bash
# PostToolUse Write|Edit hook — flag potentially-missing Firestore composite
# indexes when a repository file gains a multi-field query.
#
# Conservative: greps for two patterns that almost always need a composite
# index:
#   .where(...).orderBy(...)        # range + order
#   .where(...).where(...).orderBy  # multi-equality + order
# Then checks if the file mentions a collection name that has at least one
# index entry. If not, nudges. False positives are acceptable; missing this
# class of bug is not.

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

# Only act on repository / service files
case "$FILE" in
  *lib/repositories/*.dart|*lib/services/*.dart) : ;;
  *) exit 0 ;;
esac

[[ ! -f "$FILE" ]] && exit 0

INDEXES_FILE="firestore.indexes.json"
[[ ! -f "$INDEXES_FILE" ]] && exit 0

# Has the file added or kept a where().orderBy() or where().where() pattern?
# Multiline-aware grep — patterns may span lines.
HAS_COMPOUND=$(python3 - "$FILE" <<'PY' 2>/dev/null || echo 0
import re, sys
src = open(sys.argv[1], encoding='utf-8', errors='replace').read()
# Strip line breaks for matching across formatted call chains
flat = re.sub(r'\s+', ' ', src)
patterns = [
    r'\.where\([^)]*\)\s*\.orderBy\(',
    r'\.where\([^)]*\)\s*\.where\(',
    r'\.where\([^)]*\)\s*\.limit\([^)]*\)\s*\.orderBy\(',
]
print(1 if any(re.search(p, flat) for p in patterns) else 0)
PY
)

[[ "$HAS_COMPOUND" != "1" ]] && exit 0

# Extract collection-name candidates: arguments to .collection('foo') and
# any string that looks like a collectionGroup target.
COLLECTIONS=$(python3 - "$FILE" <<'PY' 2>/dev/null || true
import re, sys
src = open(sys.argv[1], encoding='utf-8', errors='replace').read()
hits = set()
for m in re.finditer(r'\.collection\(\s*[\x27"]([a-zA-Z_][a-zA-Z0-9_]*)[\x27"]\s*\)', src):
    hits.add(m.group(1))
for m in re.finditer(r'\.collectionGroup\(\s*[\x27"]([a-zA-Z_][a-zA-Z0-9_]*)[\x27"]\s*\)', src):
    hits.add(m.group(1))
print('\n'.join(sorted(hits)))
PY
)

[[ -z "${COLLECTIONS:-}" ]] && exit 0

# For each collection, check whether firestore.indexes.json mentions it.
MISSING=()
while IFS= read -r col; do
  [[ -z "$col" ]] && continue
  if ! grep -qF "\"collectionGroup\": \"$col\"" "$INDEXES_FILE"; then
    MISSING+=("$col")
  fi
done <<< "$COLLECTIONS"

if [[ ${#MISSING[@]} -gt 0 ]]; then
  {
    echo "⚠ firestore-index-verifier: $(basename "$FILE") has compound queries on:"
    for col in "${MISSING[@]}"; do
      echo "    • \"$col\" — no index entry in firestore.indexes.json"
    done
    echo "  Compound queries (where+orderBy / where+where) almost always need a"
    echo "  composite index. Verify, and if needed add to firestore.indexes.json"
    echo "  before deploying — missing indexes are silent until prod traffic hits."
    echo "  (Hint: \`firebase firestore:indexes\` shows the deployed shape.)"
  } >&2
fi

exit 0
