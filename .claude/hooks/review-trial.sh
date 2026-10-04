#!/usr/bin/env bash
# SubagentStop hook: feeds the Opus-vs-Sonnet review trial (see review_trial.py).
# Fails open: any error exits 0 so it never disturbs a review.

set -uo pipefail

if command -v py &>/dev/null; then
  PY_CMD="py -3"
elif command -v python3 &>/dev/null; then
  PY_CMD="python3"
elif command -v python &>/dev/null; then
  PY_CMD="python"
else
  exit 0
fi

$PY_CMD .claude/hooks/review_trial.py "${1:-hook}" 2>/dev/null || true
exit 0
