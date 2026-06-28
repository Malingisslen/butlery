#!/usr/bin/env bash
# PreToolUse hook: gate `git commit` on fresh specialist-review markers.
#
# Mirrors require-simplify-before-commit.sh — same marker-staleness
# discipline, but per-pattern: different staged file paths require
# different specialist reviewers.
#
# Trigger map (keep in sync with each agent's MUST BE USED clause):
#   *.dart                                          → code-reviewer
#   lib/**/*.dart                                   → testing-specialist
#   lib/repositories/, lib/services/{firebase|...}  → firebase-backend-security
#   functions/src/ (incl. __tests__/)               → cloud-functions-specialist
#   firestore.rules, functions/src/__tests__/*-rules → firestore-rules-tester
#
# Markers live at .claude/state/<name>-done.marker.
# Stale = newest changed-file mtime > marker mtime.

set -uo pipefail

HOOK_JSON="$(cat)"

# Cheap substring check first — most Bash calls won't mention commit at all.
if ! printf '%s' "$HOOK_JSON" | grep -q 'git commit'; then
  exit 0
fi

CMD="$(printf '%s' "$HOOK_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool_input',{}).get('command',''))" 2>/dev/null || true)"
[[ -z "$CMD" ]] && exit 0

# Require `git commit` at start-of-string or after a real shell separator
# (rejects `echo 'git commit'` and similar quoted occurrences).
if ! printf '%s' "$CMD" | grep -Eq '(^|[[:space:]]*(\&\&|\|\||;|\|)[[:space:]]*)git[[:space:]]+commit([[:space:]]|$|-)'; then
  exit 0
fi

# Pass help/version through — they don't actually commit.
if printf '%s' "$CMD" | grep -Eq '(--help|--version|-h[[:space:]]|-h$)'; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT"

# Determine actual commit scope:
#   `git commit`           → only staged files (--cached)
#   `git commit -a`/--all  → staged ∪ modified-tracked (git stages-then-commits)
# Including unstaged files unconditionally over-blocks during parallel-session
# work (another session's uncommitted .dart edits would force review markers
# even when committing unrelated config files in this session).
INCLUDE_UNSTAGED="$(printf '%s' "$CMD" | python3 -c '
import sys, shlex
try:
    args = shlex.split(sys.stdin.read())
    i = args.index("commit")
except Exception:
    print(0); sys.exit()
flags = args[i+1:]
takes_arg = {"-m","--message","-F","--file","-C","--reuse-message","-c","--reedit-message","-t","--template","--author","--date","-S","--gpg-sign"}
skip_next = False
for a in flags:
    if skip_next:
        skip_next = False; continue
    if a in takes_arg:
        skip_next = True; continue
    if a == "-a" or a == "--all":
        print(1); sys.exit()
    if a.startswith("-") and not a.startswith("--") and "a" in a[1:]:
        print(1); sys.exit()
print(0)
' 2>/dev/null || echo 0)"

if [[ "$INCLUDE_UNSTAGED" == "1" ]]; then
  CHANGED_FILES="$({ git diff --cached --name-only; git diff --name-only; } 2>/dev/null | sort -u)"
else
  CHANGED_FILES="$(git diff --cached --name-only 2>/dev/null | sort -u)"
fi
[[ -z "$CHANGED_FILES" ]] && exit 0

STATE_DIR="$REPO_ROOT/.claude/state"
mkdir -p "$STATE_DIR"

# ---- Trigger detection ----------------------------------------------------

# Parallel arrays — kept in lockstep so index i refers to the same review.
required_markers=()
required_agents=()

has_match() {
  printf '%s\n' "$CHANGED_FILES" | grep -Eq "$1"
}

# code-reviewer — any .dart
if has_match '\.dart$'; then
  required_markers+=("code-review-done.marker")
  required_agents+=("code-reviewer")
fi

# testing-specialist — any lib/*.dart
if has_match '^lib/.*\.dart$'; then
  required_markers+=("testing-review-done.marker")
  required_agents+=("testing-specialist")
fi

# firebase-backend-security — repositories/ + services with firebase/firestore/
# auth/user/gdpr in path (the Flutter/Dart Firebase surface only). Cloud
# Functions (functions/src/) now route to cloud-functions-specialist below
# (BUT-1402).
fire_security=0
has_match '^lib/repositories/' && fire_security=1
has_match '^lib/services/.*(firebase|firestore|auth|user|gdpr)' && fire_security=1
if [[ $fire_security -eq 1 ]]; then
  required_markers+=("firebase-security-done.marker")
  required_agents+=("firebase-backend-security")
fi

# cloud-functions-specialist — any functions/src/ change, INCLUDING __tests__/
# (the ~52 non-rules CF unit tests were previously ungated). Rules tests also
# trigger firestore-rules-tester below — both reviews apply to them. (BUT-1402)
if has_match '^functions/src/'; then
  required_markers+=("cloud-functions-done.marker")
  required_agents+=("cloud-functions-specialist")
fi

# firestore-rules-tester — firestore.rules OR functions/src/__tests__/*-rules.test.ts
fire_rules=0
printf '%s\n' "$CHANGED_FILES" | grep -Fxq 'firestore.rules' && fire_rules=1
has_match '^functions/src/__tests__/.*-rules\.test\.ts$' && fire_rules=1
if [[ $fire_rules -eq 1 ]]; then
  required_markers+=("rules-tester-done.marker")
  required_agents+=("firestore-rules-tester")
fi

# Nothing to gate? Pass through.
if [[ ${#required_markers[@]} -eq 0 ]]; then
  exit 0
fi

# ---- Marker staleness check ----------------------------------------------

NEWEST_MTIME="$(
  printf '%s\n' "$CHANGED_FILES" | while read -r f; do
    # -f skips deleted files (git diff still lists them).
    [[ -f "$f" ]] && stat -c '%Y' -- "$f" 2>/dev/null || true
  done | sort -n | tail -1
)"

block_reasons=()

for i in "${!required_markers[@]}"; do
  marker="${required_markers[$i]}"
  agent="${required_agents[$i]}"
  marker_path="$STATE_DIR/$marker"

  if [[ ! -f "$marker_path" ]]; then
    block_reasons+=("MISSING: $agent — run agent against staged diff, then: touch .claude/state/$marker")
    continue
  fi

  marker_mtime="$(stat -c '%Y' -- "$marker_path" 2>/dev/null || echo 0)"
  if [[ -n "$NEWEST_MTIME" ]] && (( NEWEST_MTIME > marker_mtime )); then
    block_reasons+=("STALE: $agent — files edited after review. Re-run, then: touch .claude/state/$marker")
  fi
done

if [[ ${#block_reasons[@]} -eq 0 ]]; then
  exit 0
fi

# ---- Agent-timeout advisory (per memory/feedback_agent_timeout.md) -------

count_lines() {
  printf '%s\n' "$CHANGED_FILES" | { grep -E "$1" || true; } | wc -l | tr -d ' '
}
total_dart="$(count_lines '\.dart$')"
total_lib_dart="$(count_lines '^lib/.*\.dart$')"

# ---- Emit consolidated BLOCK ---------------------------------------------

{
  echo "[require-review-before-commit] Specialist reviews are missing/stale."
  echo ""
  for reason in "${block_reasons[@]}"; do
    echo "  - $reason"
  done
  echo ""
  if (( total_dart > 3 || total_lib_dart > 3 )); then
    echo "Heads-up: ${total_dart} .dart files staged (${total_lib_dart} in lib/)."
    echo "Per memory/feedback_agent_timeout.md, agents stall on >3 files."
    echo "Either split this commit, or run agents in batches and touch the marker after the final batch."
    echo ""
  fi
  echo "After reviews complete, retry the commit."
} >&2

exit 2
