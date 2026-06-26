#!/usr/bin/env bash
# PostToolUse hook (Write|Edit): dossier-freshness stamper.
# When an edited file matches a role's owned paths (docs/org/role-paths.json,
# generated from docs/architecture/ROLE_RESPONSIBILITY_MAP.md), stamp that
# role's dossier "stale" by writing a marker under docs/org/dossier-staleness/.
# The /refresh-dossiers skill re-audits only stale roles and clears the markers.
#
# Does no auditing itself. Soft + cheap + fails open: any error exits 0 so it
# never disrupts a Write/Edit. See docs/architecture/ROLE_ORG_DESIGN.md.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")

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

echo "$INPUT" | $PY_CMD .claude/hooks/dossier_stamp.py 2>/dev/null || true

exit 0
