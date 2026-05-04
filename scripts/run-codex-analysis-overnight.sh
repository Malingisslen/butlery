#!/usr/bin/env bash
# Quota-aware overnight wrapper around scripts/run-codex-analysis.sh.
#
# Why this exists:
#   - ChatGPT Team Codex enforces both a 5-hour rolling window AND a weekly cap.
#   - Bucket size for Team is small enough that a single deep prompt can drain
#     it (we saw 02 burn 582K tokens and still not finish before 429).
#   - The existing run-codex-analysis.sh is idempotent (skips reports that
#     already exist on disk) but doesn't wait when quota resets.
#
# What this does:
#   1. Calls the inner script.
#   2. If the pipeline isn't fully done, scans all _logs/*.log for the most
#      recent `resets_at` epoch returned by Codex's 429 response.
#   3. Sleeps until that epoch + a small buffer, then retries.
#   4. Bails if the reset is further than WEEKLY_CAP_HOURS away (likely the
#      weekly cap, which can be days — don't block a terminal that long).
#
# Usage:
#   nohup scripts/run-codex-analysis-overnight.sh > _overnight.log 2>&1 &
#   (use nohup or run in tmux/screen so closing the terminal doesn't kill it)
#
# Tunables (env vars):
#   MAX_ATTEMPTS          (default 12)  — safety cap on retry loops
#   RESET_BUFFER_SECONDS  (default 90)  — buffer added to reset epoch before retrying
#   WEEKLY_CAP_HOURS      (default 24)  — if reset is further than this, abort
#   SEQUENTIAL            (default 0)   — pass-through: 1 disables wave parallelism
#
# Idempotency:
#   The inner script skips reports that already exist on disk. So the first
#   attempt does what it can, the next attempt picks up the missing ones,
#   and so on until everything is done or we abort.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

INNER="scripts/run-codex-analysis.sh"
RUN_DIR="docs/analysis/runs/2026-05-codex"
LOG_DIR="$RUN_DIR/_logs"

MAX_ATTEMPTS="${MAX_ATTEMPTS:-12}"
RESET_BUFFER_SECONDS="${RESET_BUFFER_SECONDS:-90}"
WEEKLY_CAP_HOURS="${WEEKLY_CAP_HOURS:-24}"

REQUIRED_REPORTS=(
  01-code-quality.md  02-security.md         03-infrastructure.md
  04-performance.md   05-dependencies.md     06-user-experience.md
  07-ai-llm-quality.md 08-product-analytics.md 09-trust-safety-privacy.md
  10-monetization.md  11-legal.md            12-doc-drift.md
  SYNTHESIS.md
)

is_pipeline_done() {
  for r in "${REQUIRED_REPORTS[@]}"; do
    [[ ! -s "$RUN_DIR/$r" ]] && return 1
  done
  return 0
}

list_missing() {
  for r in "${REQUIRED_REPORTS[@]}"; do
    [[ ! -s "$RUN_DIR/$r" ]] && echo "  - $r"
  done
}

# Find the most recent `resets_at` epoch across all logs.
# Codex's 429 body contains: "resets_at":1777770645
find_latest_reset_epoch() {
  local latest=0
  shopt -s nullglob
  for log in "$LOG_DIR"/*.log; do
    local epoch
    epoch=$(grep -oE 'resets_at[^0-9]*([0-9]+)' "$log" 2>/dev/null | tail -1 | grep -oE '[0-9]+$')
    if [[ -n "$epoch" && "$epoch" =~ ^[0-9]+$ && "$epoch" -gt "$latest" ]]; then
      latest=$epoch
    fi
  done
  shopt -u nullglob
  echo "$latest"
}

format_eta() {
  local epoch="$1"
  local now=$(date +%s)
  local secs=$((epoch - now))
  local when
  when=$(date -d "@$epoch" '+%Y-%m-%d %H:%M %Z' 2>/dev/null || date -r "$epoch" '+%Y-%m-%d %H:%M %Z' 2>/dev/null || echo "epoch=$epoch")
  if [[ "$secs" -le 0 ]]; then
    echo "$when (in the past)"
  else
    printf '%s (in %dh %dm)\n' "$when" "$((secs / 3600))" "$(((secs % 3600) / 60))"
  fi
}

countdown_sleep() {
  local target_epoch="$1"
  local now wait_secs
  while true; do
    now=$(date +%s)
    wait_secs=$((target_epoch - now))
    [[ "$wait_secs" -le 0 ]] && break
    # print a heartbeat every ~10 minutes so anyone tailing the log knows we're alive
    local hb_interval=600
    [[ "$wait_secs" -lt "$hb_interval" ]] && hb_interval="$wait_secs"
    echo "[wait] $(date '+%H:%M:%S') — $((wait_secs / 60))m remaining until reset"
    sleep "$hb_interval"
  done
}

main() {
  echo "==========================================="
  echo "Codex overnight wrapper — starting $(date)"
  echo "Required reports: ${#REQUIRED_REPORTS[@]}"
  echo "==========================================="
  for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
    echo
    echo "------- attempt $attempt / $MAX_ATTEMPTS — $(date) -------"

    if is_pipeline_done; then
      echo "[done] Pipeline already complete on entry to attempt $attempt."
      return 0
    fi

    echo "[run] $INNER"
    "$INNER" || true   # don't let inner failures kill the wrapper

    if is_pipeline_done; then
      echo
      echo "[success] All ${#REQUIRED_REPORTS[@]} reports present after attempt $attempt."
      return 0
    fi

    echo "[partial] Missing after attempt $attempt:"
    list_missing

    local reset_epoch
    reset_epoch=$(find_latest_reset_epoch)
    if [[ "$reset_epoch" -eq 0 ]]; then
      echo "[abort] Pipeline incomplete but no 429 found in logs."
      echo "        Inspect $LOG_DIR/*.log — likely a different error class."
      return 1
    fi

    local now wait_secs
    now=$(date +%s)
    wait_secs=$((reset_epoch - now + RESET_BUFFER_SECONDS))

    if [[ "$wait_secs" -gt $((WEEKLY_CAP_HOURS * 3600)) ]]; then
      local hours=$((wait_secs / 3600))
      echo "[abort] Reset is ${hours}h+ away — likely weekly cap, not 5h window."
      echo "        Latest resets_at: $(format_eta "$reset_epoch")"
      echo "        Resume manually after weekly reset, or raise WEEKLY_CAP_HOURS."
      return 1
    fi

    echo "[quota] 429 detected. Reset: $(format_eta "$reset_epoch")"
    echo "[wait] Sleeping ${wait_secs}s (with ${RESET_BUFFER_SECONDS}s buffer)..."
    countdown_sleep "$((reset_epoch + RESET_BUFFER_SECONDS))"
    echo "[resume] $(date) — retrying."
  done

  echo
  echo "[abort] Exhausted $MAX_ATTEMPTS attempts. Still missing:"
  list_missing
  return 1
}

main "$@"
exit_code=$?
echo
echo "==========================================="
echo "Codex overnight wrapper — exit $exit_code at $(date)"
echo "==========================================="
exit $exit_code
