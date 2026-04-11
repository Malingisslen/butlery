#!/usr/bin/env bash
# PreToolUse hook for ExitPlanMode: forces a self-review of the plan
# before presenting it to the user.
#
# State:  $HOME/.claude/state/plan-reviewed-<session-hash>.marker
#         (contents = unix timestamp of creation)
# Log:    $HOME/.claude/state/plan-review-gate.log
#
# Flow:
#   1st call, no marker      → write marker, block with review prompt
#   2nd call, fresh marker   → delete marker, allow through (exit 0)
#   stale marker (> TTL)     → treat as 1st call
#
# Why $HOME/.claude/state/ instead of /tmp:
#   On Windows git-bash, /tmp can be ephemeral per shell invocation,
#   which caused the marker to vanish between calls and trap Claude
#   in an infinite review loop.
#
# Why per-session marker:
#   A global marker let Claude carry "already reviewed" state across
#   plans, silently bypassing the gate on the next plan.

set -uo pipefail

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"

LOG="$STATE_DIR/plan-review-gate.log"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$HOOK_DIR/parse_hook_json.py"
TTL_SECONDS=1800   # 30 minutes

INPUT=$(cat)

SESSION_ID=$(printf '%s' "$INPUT" | python "$PARSER" session_id 2>/dev/null || true)
[ -z "$SESSION_ID" ] && SESSION_ID="default"

MARKER_HASH=$(printf '%s' "$SESSION_ID" | sha1sum | cut -c1-12)
MARKER="$STATE_DIR/plan-reviewed-$MARKER_HASH.marker"

# Sweep stale markers from dead sessions (cheap GC)
find "$STATE_DIR" -maxdepth 1 -name 'plan-reviewed-*.marker' -type f \
  -mmin +$((TTL_SECONDS / 60)) -delete 2>/dev/null || true

log_line() {
  local decision="$1" reason="$2"
  printf '%s session=%s decision=%s reason=%s\n' \
    "$(date -Iseconds 2>/dev/null || date)" "${SESSION_ID:0:12}" \
    "$decision" "$reason" >> "$LOG" 2>/dev/null || true
}

NOW=$(date +%s)

# Fresh marker → second call → allow
if [ -f "$MARKER" ]; then
  STAMP=$(cat "$MARKER" 2>/dev/null || echo 0)
  AGE=$(( NOW - STAMP ))
  if [ "$AGE" -lt "$TTL_SECONDS" ]; then
    rm -f "$MARKER"
    log_line allow "fresh-marker-age=${AGE}s"
    exit 0
  fi
  rm -f "$MARKER"
  log_line block "stale-marker-age=${AGE}s"
else
  log_line block "no-marker"
fi

# First call — write fresh marker and block with review instructions
printf '%s' "$NOW" > "$MARKER"

# Best-effort hint: most recent plan file in the user's plan dir.
# (ExitPlanMode tool_input does not include the plan file path, so
# this is a heuristic — but the marker logic above does not depend on it.)
PLAN_FILE=""
if [ -d "$HOME/.claude/plans" ]; then
  PLAN_FILE=$(ls -t "$HOME/.claude/plans"/*.md 2>/dev/null | head -1 || true)
fi

REVIEW_PROMPT="PLAN REVIEW GATE: You must review your plan before presenting it.

1. Read the checklist: C:/Butlery/butlery/.claude/plan-review-checklist.md
2. Read your plan file${PLAN_FILE:+ ($PLAN_FILE)}
3. For each checklist section, verify your plan addresses it. If the section is not relevant to this plan (e.g., no UI work → skip Design System), note it and move on.
4. If you find issues, update the plan file and note what you changed.
5. If you need to verify specific theme tokens, read the actual theme files (lib/theme/).
6. Call ExitPlanMode when done."

# Emit block JSON via Python — robust against any characters in the prompt.
# PYTHONIOENCODING forces UTF-8 stdin so non-ASCII (e.g. →) round-trips
# correctly on Windows, where cp1252 is the default.
PYTHONIOENCODING=utf-8 python -c 'import json,sys; sys.stdout.write(json.dumps({"decision":"block","reason":sys.stdin.read()},ensure_ascii=False))' <<< "$REVIEW_PROMPT" 2>/dev/null
