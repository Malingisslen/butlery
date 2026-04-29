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

# Resolve the active plan file. ExitPlanMode tool_input does not include
# the plan path, so we pick the most-recently-modified candidate across
# the two known plan locations:
#   - ~/.claude/plans/*.md   (Claude Code plan-mode default — system reminder
#                             writes a path here at plan-mode entry)
#   - $PROJECT_ROOT/tasks/todo.md  (workflow-discipline.md sprint plan)
# Newest mtime wins. This avoids the previous bug where the hook scanned
# stale tasks/todo.md content while the user was actually exiting a fresh
# plan in ~/.claude/plans/, producing wrong trigger decisions.
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
PLAN_TODO="$PROJECT_ROOT/tasks/todo.md"

PLAN_FILE=""
PLAN_MTIME=0

if [ -d "$HOME/.claude/plans" ]; then
  for f in "$HOME/.claude/plans"/*.md; do
    [ -f "$f" ] || continue
    m=$(stat -c '%Y' -- "$f" 2>/dev/null || echo 0)
    if [ "${m:-0}" -gt "$PLAN_MTIME" ]; then
      PLAN_FILE="$f"
      PLAN_MTIME=$m
    fi
  done
fi

if [ -f "$PLAN_TODO" ]; then
  m=$(stat -c '%Y' -- "$PLAN_TODO" 2>/dev/null || echo 0)
  if [ "${m:-0}" -gt "$PLAN_MTIME" ]; then
    PLAN_FILE="$PLAN_TODO"
    PLAN_MTIME=$m
  fi
fi

# High-stakes trigger detection — escalates from in-context self-review
# to a fresh-agent dispatch via /review-plan. Triggers picked from actual
# correction history (memory/feedback_*.md):
#   - Repositories / Firestore rules / auth → security & data-integrity risk
#   - Theme files → design-system rules are easy to skip in self-review
#   - Large plans (>100 lines) → too much surface for in-context review
HIGH_STAKES=""
if [ -n "$PLAN_FILE" ] && [ -f "$PLAN_FILE" ]; then
  plan_lines=$(wc -l < "$PLAN_FILE" 2>/dev/null | tr -d ' ' || echo 0)
  if [ "${plan_lines:-0}" -gt 100 ]; then
    HIGH_STAKES="${HIGH_STAKES}plan>${plan_lines}-lines "
  fi
  if grep -qE '(lib/repositories/|firestore\.rules|firebase_auth|FirestoreRepository|GDPR|PermissionValidation)' "$PLAN_FILE" 2>/dev/null; then
    HIGH_STAKES="${HIGH_STAKES}security-or-data "
  fi
  if grep -qE '(lib/theme/|app_colors|app_dimensions|app_typography|BorderRadius\.circular|widgets/CLAUDE\.md)' "$PLAN_FILE" 2>/dev/null; then
    HIGH_STAKES="${HIGH_STAKES}design-system "
  fi
fi

if [ -n "$HIGH_STAKES" ]; then
  REVIEW_PROMPT="PLAN REVIEW GATE [HIGH-STAKES: ${HIGH_STAKES}]

Active plan file: ${PLAN_FILE:-<none detected>}

This plan touches load-bearing surface (security / data / design system) or is large enough that in-context self-review is unreliable.

Required: run \`/review-plan${PLAN_FILE:+ $PLAN_FILE}\` to dispatch a fresh-context auditor that reads CLAUDE.md, .claude/rules/, widgets/CLAUDE.md, tasks/lessons.md, and the relevant memory cold — then audits the plan against .claude/plan-review-checklist.md.

Steps:
  1. Run /review-plan${PLAN_FILE:+ $PLAN_FILE}
  2. Address any RED or YELLOW findings (update the plan file if needed)
  3. Call ExitPlanMode again — this gate will let it through

Do NOT do an in-context self-review for this plan. The whole point is that the auditor reads the rules cold without the context that wrote the plan."
  log_line block "high-stakes:${HIGH_STAKES} plan=${PLAN_FILE##*/}"
else
  REVIEW_PROMPT="PLAN REVIEW GATE: You must review your plan before presenting it.

1. Read the checklist: C:/Butlery/butlery/.claude/plan-review-checklist.md
2. Read your plan file${PLAN_FILE:+ ($PLAN_FILE)}
3. For each checklist section, verify your plan addresses it. If the section is not relevant to this plan (e.g., no UI work → skip Design System), note it and move on.
4. If you find issues, update the plan file and note what you changed.
5. If you need to verify specific theme tokens, read the actual theme files (lib/theme/).
6. Call ExitPlanMode when done.

(Self-review path: this plan didn't trip any high-stakes triggers — security/data, design-system, or >100 lines. If you think it should have, run /review-plan anyway.)"
fi

# Emit block JSON via Python — robust against any characters in the prompt.
# PYTHONIOENCODING forces UTF-8 stdin so non-ASCII (e.g. →) round-trips
# correctly on Windows, where cp1252 is the default.
PYTHONIOENCODING=utf-8 python -c 'import json,sys; sys.stdout.write(json.dumps({"decision":"block","reason":sys.stdin.read()},ensure_ascii=False))' <<< "$REVIEW_PROMPT" 2>/dev/null
