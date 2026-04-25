#!/usr/bin/env bash
# Stop hook — audit knowledge-file freshness.
# For each .knowledge.md, check git's last-modified date. If older than
# the freshness window AND its sibling agent file has been modified more
# recently (suggesting the agent changed but its memory didn't), nudge.
#
# This is a soft nudge, never blocking. The goal is to catch the
# "agent runs but never appends" failure mode early.

set -euo pipefail

# Only run inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

AGENTS_DIR=".claude/agents"
[[ -d "$AGENTS_DIR" ]] || exit 0

# Freshness window: 30 days.
WINDOW_SECONDS=$((30 * 24 * 3600))
NOW=$(date +%s)

STALE=()

for kf in "$AGENTS_DIR"/*.knowledge.md; do
  [[ -e "$kf" ]] || continue

  # Last commit touching the knowledge file
  KF_TS=$(git log -1 --format=%ct -- "$kf" 2>/dev/null || echo "")
  if [[ -z "$KF_TS" ]]; then
    # Untracked or never committed — fall back to filesystem mtime
    KF_TS=$(stat -c %Y "$kf" 2>/dev/null || echo "$NOW")
  fi

  AGE=$((NOW - KF_TS))
  [[ $AGE -lt $WINDOW_SECONDS ]] && continue

  AGENT_FILE="${kf%.knowledge.md}.md"
  if [[ -f "$AGENT_FILE" ]]; then
    AGENT_TS=$(git log -1 --format=%ct -- "$AGENT_FILE" 2>/dev/null || echo "$KF_TS")
    # Only flag if the agent file has been touched MORE recently than the
    # knowledge file — suggests the agent evolved but memory didn't.
    if [[ "$AGENT_TS" -gt "$KF_TS" ]]; then
      DAYS=$((AGE / 86400))
      STALE+=("$(basename "${AGENT_FILE%.md}") (knowledge file ${DAYS}d old; agent file newer)")
    fi
  fi
done

if [[ ${#STALE[@]} -gt 0 ]]; then
  {
    echo "📚 knowledge-freshness audit:"
    for entry in "${STALE[@]}"; do
      echo "   • $entry"
    done
    echo "   These agents may be running without honoring the append-on-discovery"
    echo "   contract. Check whether recent runs surfaced patterns that should"
    echo "   have been recorded but weren't."
  } >&2
fi

exit 0
