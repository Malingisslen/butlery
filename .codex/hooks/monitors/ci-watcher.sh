#!/usr/bin/env bash
# Monitor GitHub Actions runs for a commit SHA.
# Usage: ci-watcher.sh [SHA] (defaults to HEAD)
# Each stdout line = a Monitor notification. Exits when all runs complete.
set -euo pipefail

SHA="${1:-$(git rev-parse HEAD)}"
SHORT_SHA="${SHA:0:7}"
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null) || REPO="malingisslen/butlery"
STATE_FILE="${TMPDIR:-/tmp}/.ci-watcher-${SHORT_SHA}"

> "$STATE_FILE"
cleanup() { rm -f "$STATE_FILE" "${STATE_FILE}.tmp"; }
trap cleanup EXIT INT TERM

EMPTY_POLLS=0
MAX_EMPTY_POLLS=20

while true; do
  RUNS=$(gh api "repos/$REPO/actions/runs?head_sha=$SHA&per_page=20" \
    --jq '.workflow_runs[] | "\(.id)|\(.name)|\(.status)|\(.conclusion // "pending")"' 2>/dev/null) || { sleep 30; continue; }

  if [ -z "$RUNS" ]; then
    EMPTY_POLLS=$((EMPTY_POLLS + 1))
    if [ "$EMPTY_POLLS" -ge "$MAX_EMPTY_POLLS" ]; then
      echo "No CI runs found for $SHORT_SHA after 5 min — exiting"
      exit 0
    fi
    sleep 15
    continue
  fi
  EMPTY_POLLS=0

  ALL_DONE=true
  FAIL_COUNT=0
  TOTAL=0
  while IFS='|' read -r id name status conclusion; do
    [ -z "$id" ] && continue
    TOTAL=$((TOTAL + 1))
    STATE="$status:$conclusion"
    PREV=$(grep "^$id|" "$STATE_FILE" 2>/dev/null | cut -d'|' -f2 || true)

    if [ "$PREV" != "$STATE" ]; then
      grep -v "^$id|" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || true
      echo "$id|$STATE" >> "${STATE_FILE}.tmp"
      mv "${STATE_FILE}.tmp" "$STATE_FILE"

      if [ "$status" = "completed" ]; then
        if [ "$conclusion" = "success" ]; then
          echo "[PASS] $name ($SHORT_SHA)"
        else
          echo "[FAIL] $name — $conclusion ($SHORT_SHA)"
        fi
      else
        echo "[RUNNING] $name ($SHORT_SHA)"
      fi
    fi

    [ "$status" != "completed" ] && ALL_DONE=false
    [ "$conclusion" != "success" ] && [ "$status" = "completed" ] && FAIL_COUNT=$((FAIL_COUNT + 1))
  done <<< "$RUNS"

  if [ "$ALL_DONE" = true ]; then
    if [ "$FAIL_COUNT" -gt 0 ]; then
      echo "CI DONE: $FAIL_COUNT/$TOTAL failed for $SHORT_SHA"
    else
      echo "CI DONE: All $TOTAL workflows passed for $SHORT_SHA"
    fi
    exit 0
  fi

  sleep 30
done
