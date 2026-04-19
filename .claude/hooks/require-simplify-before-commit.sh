#!/usr/bin/env bash
# PreToolUse hook: gate `git commit` on a fresh /simplify run.
#
# /simplify is a plugin skill we can't instrument, so we rely on Claude
# writing a timestamp file (.claude/state/simplify-done.marker) after it
# runs. Stale marker = edits happened after the last simplify.

set -euo pipefail

HOOK_JSON="$(cat)"

# Cheap substring check first — most Bash calls won't mention commit at all,
# and this saves a Python spawn + `git rev-parse` per call.
if ! printf '%s' "$HOOK_JSON" | grep -q 'git commit'; then
  exit 0
fi

CMD="$(printf '%s' "$HOOK_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('tool_input',{}).get('command',''))" 2>/dev/null || true)"
[[ -z "$CMD" ]] && exit 0

# Require `git commit` at start-of-string or after a real shell separator
# (&&/||/;/|). Rejects `echo 'git commit'` and similar quoted occurrences
# — a quote or bare space isn't a separator, so they don't match.
if ! printf '%s' "$CMD" | grep -Eq '(^|[[:space:]]*(\&\&|\|\||;|\|)[[:space:]]*)git[[:space:]]+commit([[:space:]]|$|-)'; then
  exit 0
fi

# Pass help/version through — they don't actually commit.
if printf '%s' "$CMD" | grep -Eq '(--help|--version|-h[[:space:]]|-h$)'; then
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT"

# `git commit -a` commits modified-tracked without `git add`, so union
# staged + unstaged when deciding both scope and staleness.
CHANGED_FILES="$({ git diff --cached --name-only; git diff --name-only; } 2>/dev/null | sort -u)"

# Scope: only fire when a .dart file is part of the change set.
printf '%s\n' "$CHANGED_FILES" | grep -Eq '\.dart$' || exit 0

MARKER="$REPO_ROOT/.claude/state/simplify-done.marker"
mkdir -p "$(dirname "$MARKER")"

BLOCK() {
  cat >&2 <<EOF
[require-simplify-before-commit] $1

To unblock:
  1. Run the /simplify skill; fix any issues it finds.
  2. Run: touch .claude/state/simplify-done.marker
  3. Retry the commit.
EOF
  exit 2
}

[[ -f "$MARKER" ]] || BLOCK "No /simplify marker — /simplify has not run."

MARKER_MTIME="$(stat -c '%Y' -- "$MARKER" 2>/dev/null || echo 0)"
NEWEST_MTIME="$(
  printf '%s\n' "$CHANGED_FILES" | while read -r f; do
    # -f skips deleted files (git diff still lists them).
    [[ -f "$f" ]] && stat -c '%Y' -- "$f" 2>/dev/null || true
  done | sort -n | tail -1
)"

if [[ -n "$NEWEST_MTIME" ]] && (( NEWEST_MTIME > MARKER_MTIME )); then
  BLOCK "Marker is stale — files edited after the last /simplify."
fi

exit 0
