#!/usr/bin/env bash
# PreToolUse hook for ExitPlanMode: Forces a self-review of the plan
# before presenting it to the user. Uses a marker file to allow the
# second attempt through (preventing infinite loops).

set -euo pipefail

MARKER_FILE="/tmp/.butlery-plan-reviewed"

# If marker exists, this is the second call — allow through
if [ -f "$MARKER_FILE" ]; then
  rm -f "$MARKER_FILE"
  exit 0
fi

# First call — create marker and block with review instructions
touch "$MARKER_FILE"

# Find the most recent plan file
PLAN_DIR="$HOME/.claude/plans"
PLAN_FILE=""
if [ -d "$PLAN_DIR" ]; then
  PLAN_FILE=$(ls -t "$PLAN_DIR"/*.md 2>/dev/null | head -1)
fi

REVIEW_PROMPT="PLAN REVIEW GATE: You must review your plan before presenting it.

1. Read the checklist: C:/Butlery/butlery/.claude/plan-review-checklist.md
2. Read your plan file${PLAN_FILE:+ ($PLAN_FILE)}
3. For each checklist section, verify your plan addresses it. If the section is not relevant to this plan (e.g., no UI work → skip Design System), note it and move on.
4. If you find issues, update the plan file and note what you changed.
5. If you need to verify specific theme tokens, read the actual theme files (lib/theme/).
6. Call ExitPlanMode when done."

# Output JSON to block the tool call (pure bash — avoids python3 platform warning on Windows)
ESCAPED=$(echo "$REVIEW_PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//')
echo "{\"decision\":\"block\",\"reason\":\"$ESCAPED\"}"
