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

# Size tripwire: a knowledge file past this many lines drowns its own signal
# and is re-read in full on every agent invocation (recurring token cost).
# Threshold per setup-hardening-plan item 4.
SIZE_LIMIT=800
OVERSIZED=()

for kf in "$AGENTS_DIR"/*.knowledge.md; do
  [[ -e "$kf" ]] || continue

  LINES=$(wc -l < "$kf" 2>/dev/null | tr -d ' ' || echo 0)
  if [[ "${LINES:-0}" -gt "$SIZE_LIMIT" ]]; then
    OVERSIZED+=("$(basename "$kf") (${LINES} lines > ${SIZE_LIMIT})")
  fi

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

if [[ ${#OVERSIZED[@]} -gt 0 ]]; then
  {
    echo "📏 knowledge-size tripwire:"
    for entry in "${OVERSIZED[@]}"; do
      echo "   • $entry"
    done
    echo "   Oversized knowledge files bury their own principles and cost tokens on"
    echo "   every agent invocation. Distill: compress entries >30d old into a"
    echo "   principles section, move raw entries to <name>.knowledge.archive.md"
    echo "   (append-only contract preserved). See tasks/setup-hardening-plan.md item 2."
  } >&2
fi

# Digest-sync tripwire: every lesson in tasks/lessons.md must have its one-liner
# in .claude/rules/lessons-digest.md (the auto-loaded surface). Counts drifting
# apart means a correction was captured but is NOT in force at session start.
LESSONS_FILE="tasks/lessons.md"
DIGEST_FILE=".claude/rules/lessons-digest.md"
if [[ -f "$LESSONS_FILE" && -f "$DIGEST_FILE" ]]; then
  LESSON_COUNT=$(grep -c '^### ' "$LESSONS_FILE" 2>/dev/null || echo 0)
  DIGEST_COUNT=$(grep -c '^- ' "$DIGEST_FILE" 2>/dev/null || echo 0)
  if [[ "${LESSON_COUNT:-0}" -ne "${DIGEST_COUNT:-0}" ]]; then
    {
      echo "🔁 lessons-digest drift: $LESSON_COUNT lessons in $LESSONS_FILE but"
      echo "   $DIGEST_COUNT one-liners in $DIGEST_FILE. Add the missing digest"
      echo "   line(s) now (CLAUDE.md rule #9: lesson + digest line in the same edit)."
    } >&2
  fi
fi

exit 0
