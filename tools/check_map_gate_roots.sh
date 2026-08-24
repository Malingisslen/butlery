#!/usr/bin/env bash
# Keep the workflow-map relevance gate in sync with the constant it duplicates.
#
# `.claude/hooks/post-edit-dispatch.sh` decides whether to spawn
# map-freshness-stamp.sh from a pure-bash prefix list. That list is only safe
# because `map_stamp.py` filters every map token through REPO_ROOTS, so no path
# outside those roots can ever stamp the map stale.
#
# The two live in different languages and neither reddens when they drift. If a
# root is added to REPO_ROOTS and not to the gate, edits under it silently stop
# stamping — the map goes stale without anyone being told, which is the exact
# failure class the gate exists to prevent. Same shape as BUT-1482 (a model field
# added without touching firestore.rules) and BUT-1903 (one number in three
# languages).
#
# Fails the commit when they diverge. Fix BOTH sides, never just one.

set -euo pipefail

MAP_STAMP=".claude/hooks/map_stamp.py"
DISPATCH=".claude/hooks/post-edit-dispatch.sh"

# Nothing to check if either side is absent (e.g. before the dispatcher landed).
[[ -f "$MAP_STAMP" && -f "$DISPATCH" ]] || exit 0

# REPO_ROOTS = ("lib/", "functions/", "test/", "tools/")  ->  functions lib test tools
PY_ROOTS=$(grep -E '^REPO_ROOTS\s*=' "$MAP_STAMP" \
  | grep -oE '"[^"]+"' | tr -d '"' | sed 's:/$::' | sort | tr '\n' ' ')

# The gate line:   lib/*|functions/*|test/*|tools/*) run map-freshness-stamp.sh ;;
SH_ROOTS=$(grep -oE '^[[:space:]]*(lib|functions|test|tools)/\*(\|[a-z]+/\*)*\)' "$DISPATCH" \
  | head -1 | tr -d ' )' | tr '|' '\n' | sed 's:/\*$::' | grep -v '^$' | sort | tr '\n' ' ')

if [[ -z "$PY_ROOTS" ]]; then
  echo "✗ check_map_gate_roots: could not read REPO_ROOTS from $MAP_STAMP" >&2
  exit 1
fi
if [[ -z "$SH_ROOTS" ]]; then
  echo "✗ check_map_gate_roots: could not read the map gate from $DISPATCH" >&2
  exit 1
fi

if [[ "$PY_ROOTS" != "$SH_ROOTS" ]]; then
  {
    echo "✗ check_map_gate_roots: the map-freshness gate and REPO_ROOTS disagree."
    echo "    $MAP_STAMP REPO_ROOTS : $PY_ROOTS"
    echo "    $DISPATCH  gate       : $SH_ROOTS"
    echo "  A root present in only one of them means edits under it silently stop"
    echo "  stamping the workflow map stale. Update BOTH."
  } >&2
  exit 1
fi

exit 0
