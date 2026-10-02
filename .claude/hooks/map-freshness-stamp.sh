#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): workflow-map freshness stamper.
# When an edited file is referenced by a node in docs/onboarding/workflow-map.html,
# stamp the map stale by writing docs/onboarding/workflow-map.stale. A later
# session re-traces only the affected flows, updates the map JSON, runs
# tools/check_workflow_map.py, and deletes the marker (see CLAUDE.md
# "Workflow map freshness").
#
# Sibling of dossier-freshness-stamp.sh — does no auditing itself. Soft + cheap
# + fails open: any error exits 0 so it never disrupts a Write/Edit.

set -euo pipefail

# Detect Python (same probe order as the other hooks).
if command -v py &>/dev/null; then
  PY_CMD="py -3"
elif command -v python3 &>/dev/null; then
  PY_CMD="python3"
elif command -v python &>/dev/null; then
  PY_CMD="python"
else
  exit 0
fi

# lefthook pre-commit: stamp from the staged files, which include those a script changed.
if [[ "${1:-}" == "--staged" ]]; then
  $PY_CMD .claude/hooks/map_stamp.py --staged || true
  exit 0
fi
# The stamper's own tests; unlike the stamping, these must fail loudly.
if [[ "${1:-}" == "--self-test" ]]; then
  exec $PY_CMD .claude/hooks/map_stamp.py --self-test
fi

INPUT=$(cat 2>/dev/null || echo "{}")

echo "$INPUT" | $PY_CMD .claude/hooks/map_stamp.py 2>/dev/null || true

exit 0
