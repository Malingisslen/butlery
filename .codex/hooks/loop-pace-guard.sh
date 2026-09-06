#!/usr/bin/env bash
# PreToolUse hook for ScheduleWakeup: stops the autonomous sprint loop from
# pacing ITSELF down (a long wake delay) unless the pace-down is justified.
#
# Why this exists (the single most-recurring loop failure):
#   lessons.md 2026-06-04 "scan the WHOLE backlog first" + the 2026-06-09
#   transcript mining both flagged the same thing — declaring "backlog drained /
#   needs you" from a partial view and pacing the loop down (long wake delay)
#   when actionable work remained. Prose rules kept getting violated mid-run, so
#   this promotes the rule to a mechanical gate (the self-verification principle:
#   a lesson that recurs gets a deterministic guard, not another paragraph).
#
# Scope — fires ONLY when the wake re-fires a sprint-execute loop (the wake
# `prompt` contains "sprint-execute"). Every other /loop task and one-off
# ScheduleWakeup is left completely untouched.
#
# Decision:
#   not a sprint-loop wake .................................. allow (exit 0)
#   short delay (<= THRESHOLD) — normal back-to-back pacing . allow
#   long delay, reason is a concrete external blocker ....... allow
#   long delay, fresh full-backlog scan proves 0 A-CLEAN .... allow
#   long delay, none of the above (a bare pace-down) ........ BLOCK
#
# There is ALWAYS a forward path: do real work (delay 60 → short-delay allow),
# prove the backlog is drained (write the scan artifact), or name a real blocker.
# So this can never trap the loop.
#
# CAVEAT: requires the harness to expose ScheduleWakeup to PreToolUse. If it
# doesn't, the hook is simply inert (never fires) — no harm, just no enforcement.
# Verify once on a live /loop run that loop-pace-guard.log gets entries.

set -uo pipefail

STATE_DIR="$HOME/.claude/state"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/loop-pace-guard.log"
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
SCAN_FILE="$PROJECT_ROOT/.claude/state/backlog-scan.json"
THRESHOLD=300       # delaySeconds at or below this = normal pacing, never gated
SCAN_TTL=1800       # backlog-scan.json must be < 30 min old to count as proof

INPUT=$(cat)

log_line() {
  printf '%s decision=%s delay=%ss reason=%s\n' \
    "$(date -Iseconds 2>/dev/null || date)" "$1" "${DELAY:-?}" "$2" \
    >> "$LOG" 2>/dev/null || true
}

# Parse delaySeconds (number) + prompt + reason. ScheduleWakeup args carry no
# filesystem paths, so json.loads is safe (the Windows backslash problem that
# motivates parse_hook_json.py doesn't apply here). prompt/reason are base64'd
# so spaces don't break the read. Any parse error → "0 _ _" → treated as allow.
PARSED=$(printf '%s' "$INPUT" | PYTHONIOENCODING=utf-8 python -c '
import json,sys,base64
try:
    d=json.loads(sys.stdin.read())
    ti=d.get("tool_input",{}) if isinstance(d,dict) else {}
except Exception:
    print("0 _ _"); sys.exit(0)
delay=ti.get("delaySeconds",0) or 0
try: delay=int(float(delay))
except Exception: delay=0
def enc(s):
    s=(s or "").replace("\n"," ").lower()
    return base64.b64encode(s.encode("utf-8")).decode("ascii") or "_"
print(delay, enc(ti.get("prompt","")), enc(ti.get("reason","")))
' 2>/dev/null || echo "0 _ _")

read -r DELAY PROMPT_B64 REASON_B64 <<< "$PARSED"
[ -z "${DELAY:-}" ] && DELAY=0
PROMPT=$(printf '%s' "${PROMPT_B64:-_}" | base64 -d 2>/dev/null || echo "")
REASON=$(printf '%s' "${REASON_B64:-_}" | base64 -d 2>/dev/null || echo "")

# Out of scope: not a sprint-execute loop wake → never interfere.
case "$PROMPT" in
  *sprint-execute*) : ;;
  *) log_line allow "not-sprint-loop"; exit 0 ;;
esac

# Normal back-to-back pacing → allow.
if [ "${DELAY:-0}" -le "$THRESHOLD" ]; then
  log_line allow "short-delay"
  exit 0
fi

# Bypass 1 — a concrete EXTERNAL blocker named in the reason (watching CI settle,
# a deploy/cooldown, an ops/Tier-D dependency). Vague "drained / needs you /
# nothing to do" deliberately does NOT match — that's exactly what we catch.
if printf '%s' "$REASON" | grep -qE '(ci[^a-z]|watching|awaiting|deploy|cooldown|rate.?limit|quota|emulator|tier.?d|launch.?gat|store submiss|play store|mfa|secret|console|prod[^a-z]|ops[^a-z])'; then
  log_line allow "blocker-reason"
  exit 0
fi

# Bypass 2 — a fresh full-backlog scan proving zero actionable-clean tickets.
if [ -f "$SCAN_FILE" ]; then
  NOW=$(date +%s)
  MTIME=$(stat -c '%Y' -- "$SCAN_FILE" 2>/dev/null || echo 0)
  AGE=$(( NOW - MTIME ))
  ACLEAN=$(python -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("aCleanCount",-1))
except Exception: print(-1)' "$SCAN_FILE" 2>/dev/null || echo -1)
  if [ "$AGE" -lt "$SCAN_TTL" ] && [ "${ACLEAN:-1}" = "0" ]; then
    log_line allow "fresh-scan-aClean0-age=${AGE}s"
    exit 0
  fi
fi

# BLOCK — a bare pace-down with no proof and no real blocker.
log_line block "unjustified-pace-down"

REASON_MSG="LOOP PACE GUARD: you're scheduling a long wake delay (${DELAY}s) inside a /sprint-execute loop. Per lessons.md (2026-06-04 \"scan the WHOLE backlog first\") and the 2026-06-09 transcript mining, pacing the loop down from a partial view is the single most-recurring loop failure. To proceed, do ONE of:

1. Run a FULL-backlog classification scan — every open Backlog+Todo ticket, classified A-CLEAN / B-UI / C-REFACTOR / D-BLOCKED — and write the result to .claude/state/backlog-scan.json as:
     {\"timestamp\": <unix>, \"totalClassified\": <N>, \"aCleanCount\": <M>, \"topCandidates\": [\"BUT-XXXX\", ...]}
   If aCleanCount is 0, re-issue the wake and this gate passes. If aCleanCount > 0, DON'T pace down — resume the loop on a real A-CLEAN ticket with delaySeconds:60.

2. If this long delay is a genuine EXTERNAL blocker (watching CI settle, a deploy cooldown, an ops/Tier-D dependency), state that plainly in the ScheduleWakeup \`reason\` (e.g. \"watching CI settle\", \"deploy cooldown\") and re-issue.

Do NOT just shorten the delay to slip past this gate without doing the work — the point is to prove there is no actionable work before idling, not to idle quietly. Remember your own filed follow-up tickets count as actionable work."

PYTHONIOENCODING=utf-8 python -c 'import json,sys; sys.stdout.write(json.dumps({"decision":"block","reason":sys.stdin.read()},ensure_ascii=False))' <<< "$REASON_MSG" 2>/dev/null
