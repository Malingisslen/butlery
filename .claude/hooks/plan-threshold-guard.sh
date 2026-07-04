#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): mechanical enforcement of the plan-mode
# threshold in .claude/rules/workflow-discipline.md.
#
# Rule: a change touching 2+ PRODUCTION files requires a written, approved
# plan. Production = lib/**.dart (excluding lib/l10n/ and generated
# *.g.dart / *.freezed.dart) or functions/src/** (excluding __tests__/).
# Tests, docs, config, and .claude/ never count toward the threshold, so
# the standard "fix + its test" atom ships without ceremony.
#
# Why a hook instead of the rule text alone: the threshold used to be
# self-judged by the model ("a change is large if..."), which is exactly
# the kind of judgment that silently degrades across model generations.
# This makes the threshold physics, not a promise. (See lessons.md
# 2026-07-03: every improvement must name its mechanical trigger.)
#
# Plan evidence (either satisfies the gate):
#   1. $HOME/.claude/state/plan-approved-<session-hash>.marker
#      — written by plan-review-gate.sh when ExitPlanMode passes the gate.
#   2. tasks/todo.md modified within the last 6 hours
#      — covers /sprint-execute flows that write plans directly.
#
# Escape hatch: SKIP_PLAN_GUARD=1 (deliberate mechanical codemods only).
# Fail-open on any parse error — this guard must never brick editing.

set -uo pipefail

[ "${SKIP_PLAN_GUARD:-0}" = "1" ] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$HOOK_DIR/parse_hook_json.py"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
STATE_DIR="$HOME/.claude/state"
EVIDENCE_TTL_SECONDS=$((6 * 3600))

INPUT=$(cat 2>/dev/null || echo "{}")

FIELDS=$(printf '%s' "$INPUT" | python "$PARSER" session_id tool_input.file_path cwd 2>/dev/null) || exit 0
SESSION_ID=$(echo "$FIELDS" | sed -n '1p')
FILE_PATH=$(echo "$FIELDS" | sed -n '2p')
CWD_RAW=$(echo "$FIELDS" | sed -n '3p')
[ -z "$SESSION_ID" ] || [ -z "$FILE_PATH" ] && exit 0

# Normalize to repo-relative forward-slash path (same logic as
# track-session-files.sh so manifest entries and this path compare equal).
REL_PATH=$(python -c "
import sys, os, re
fp = sys.argv[1].replace('\\\\', '/')
cwd = (sys.argv[2] or os.getcwd()).replace('\\\\', '/')
cwd = cwd.rstrip('/')
def norm(p):
    m = re.match(r'^/([a-zA-Z])/(.*)', p)
    if m: return m.group(1).upper() + ':/' + m.group(2)
    m = re.match(r'^([a-zA-Z]):/(.*)', p)
    if m: return m.group(1).upper() + ':/' + m.group(2)
    return p
fp, cwd = norm(fp), norm(cwd)
if fp.startswith(cwd + '/'): fp = fp[len(cwd)+1:]
print(fp)
" "$FILE_PATH" "$CWD_RAW" 2>/dev/null) || exit 0
[ -z "$REL_PATH" ] && exit 0

is_production() {
  case "$1" in
    lib/l10n/*) return 1 ;;
    *.g.dart|*.freezed.dart) return 1 ;;
    functions/src/__tests__/*) return 1 ;;
    lib/*.dart) return 0 ;;
    functions/src/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Not a production file → never counts, never blocks.
is_production "$REL_PATH" || exit 0

# Count distinct production files this session already touched (manifest is
# written by track-session-files.sh on PostToolUse) plus this one if new.
MANIFEST="${TMPDIR:-/tmp}/.claude-session-files/$SESSION_ID"
COUNT=1
if [ -f "$MANIFEST" ]; then
  ALREADY_LISTED=0
  PROD_IN_MANIFEST=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if is_production "$line"; then
      PROD_IN_MANIFEST=$((PROD_IN_MANIFEST + 1))
      [ "$line" = "$REL_PATH" ] && ALREADY_LISTED=1
    fi
  done < "$MANIFEST"
  if [ "$ALREADY_LISTED" = "1" ]; then
    COUNT=$PROD_IN_MANIFEST
  else
    COUNT=$((PROD_IN_MANIFEST + 1))
  fi
fi

# Below threshold → single-production-file fix, no ceremony.
[ "$COUNT" -lt 2 ] && exit 0

NOW=$(date +%s)

# Evidence 1: plan-review-gate passed for this session.
MARKER_HASH=$(printf '%s' "$SESSION_ID" | sha1sum | cut -c1-12)
APPROVED="$STATE_DIR/plan-approved-$MARKER_HASH.marker"
if [ -f "$APPROVED" ]; then
  STAMP=$(cat "$APPROVED" 2>/dev/null || echo 0)
  [ $((NOW - ${STAMP:-0})) -lt "$EVIDENCE_TTL_SECONDS" ] && exit 0
fi

# Evidence 2: a freshly written tasks/todo.md plan (sprint flows).
PLAN_TODO="$PROJECT_ROOT/tasks/todo.md"
if [ -f "$PLAN_TODO" ]; then
  M=$(stat -c '%Y' -- "$PLAN_TODO" 2>/dev/null || echo 0)
  [ $((NOW - ${M:-0})) -lt "$EVIDENCE_TTL_SECONDS" ] && exit 0
fi

REASON="PLAN THRESHOLD GUARD: this edit ($REL_PATH) brings the session to ${COUNT} distinct production files, and no plan evidence exists.

Changes touching 2+ production files (lib/ or functions/src/ code) require a written, approved plan (.claude/rules/workflow-discipline.md).

Do ONE of:
  1. Enter plan mode, write the plan (including the 'Open questions' section — blast-radius-ranked questions asked via AskUserQuestion, or an explicit 'No architecture-changing unknowns — assumptions: ...' declaration), and get it approved via ExitPlanMode. The gate stamps plan evidence for this session.
  2. If executing an existing approved plan, write/refresh it in tasks/todo.md first.
  3. For a deliberate mechanical codemod only: re-run with SKIP_PLAN_GUARD=1 and say so in the summary.

Do NOT split the change into single-file edits to dodge the gate."

PYTHONIOENCODING=utf-8 python -c 'import json,sys; sys.stdout.write(json.dumps({"decision":"block","reason":sys.stdin.read()},ensure_ascii=False))' <<< "$REASON" 2>/dev/null
