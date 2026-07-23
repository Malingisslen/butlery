#!/usr/bin/env bash
# BUT-1630: sprint scratch janitor.
#
# The parallel-sprint engine (delivery plugin's sprint-execute-parallel workflow)
# leaves two kinds of disposable scratch behind by design — it deliberately does
# NOT clean them in its own autonomous Ship phase:
#   1. Per-batch patch files under  .claude/state/sprint-patches/  (batch-<i>.patch).
#   2. Worktree-revert stashes tagged with the engine's STASH_MARKER, created so
#      an implementer agent can end its worktree clean WITHOUT the deny-listed
#      `git reset --hard` / `git clean -fd` (BUT-1569).
# This script clears both. Run it by hand or from a NON-autonomous entry point
# (e.g. /janitor) — NEVER from the engine's autonomous Ship prompt, or a running
# sprint could lose patches it still needs to apply.
#
# Usage:
#   bash tools/clean_sprint_scratch.sh              # remove scratch older than 24h
#   bash tools/clean_sprint_scratch.sh --all        # remove ALL sprint scratch now
#   bash tools/clean_sprint_scratch.sh --age-hours 6
#   bash tools/clean_sprint_scratch.sh --dry-run    # print what would be removed
#
# Safety:
#   * Only ever drops stashes whose message carries the exact engine marker below;
#     a human's own stashes are never touched.
#   * The default age window keeps an in-flight sprint's fresh scratch intact; use
#     --all only when you know no sprint is running.
set -euo pipefail

# Must stay identical to STASH_MARKER / PATCH_SUBDIR in the engine
# (C:/claude-plugins/.../workflows/sprint-execute-parallel.js). If either drifts
# there, update it here — this janitor targets exactly what that engine writes.
STASH_MARKER="sprint-parallel-cleanup"
PATCH_SUBDIR="sprint-patches"

age_hours=24
dry_run=0

usage() {
  sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)        age_hours=0; shift ;;
    --age-hours)  age_hours="${2:?--age-hours needs a value}"; shift 2 ;;
    --dry-run|-n) dry_run=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if ! [[ "$age_hours" =~ ^[0-9]+$ ]]; then
  echo "--age-hours must be a non-negative integer" >&2
  exit 2
fi

# Resolve the patch dir from the shared git-common-dir so this works from either
# the main checkout or a worktree — the engine anchors patches to the same place.
common_dir="$(git rev-parse --git-common-dir)"
patch_dir="$(cd "${common_dir}/.." && pwd)/.claude/state/${PATCH_SUBDIR}"

removed_patches=0
dropped_stashes=0

# ── 1. Patch files/dirs under sprint-patches ────────────────────────────────
if [[ -d "$patch_dir" ]]; then
  # Age filter in minutes. --all (age 0) drops the age predicate entirely so
  # EVERY entry matches; otherwise keep only entries older than age_hours
  # (find -mmin +N = modified more than N minutes ago).
  if [[ "$age_hours" -eq 0 ]]; then
    age_filter=()                       # no age predicate → matches everything
  else
    age_filter=(-mmin "+$((age_hours * 60))")
  fi
  while IFS= read -r -d '' entry; do
    if [[ "$dry_run" -eq 1 ]]; then
      echo "would remove patch scratch: $entry"
    else
      rm -rf "$entry"
    fi
    removed_patches=$((removed_patches + 1))
  done < <(find "$patch_dir" -mindepth 1 -maxdepth 1 "${age_filter[@]}" -print0)
else
  echo "no patch dir at $patch_dir (nothing to clean there)"
fi

# ── 2. Tagged cleanup stashes ───────────────────────────────────────────────
# Drop only stashes whose message contains the engine marker. Indexes shift on
# every drop, so re-resolve the first match each pass instead of caching refs.
if [[ "$dry_run" -eq 1 ]]; then
  while IFS= read -r line; do
    echo "would drop stash: $line"
    dropped_stashes=$((dropped_stashes + 1))
  done < <(git stash list --format='%gd %gs' 2>/dev/null | grep -F "$STASH_MARKER" || true)
else
  max_passes=1000
  while (( max_passes-- > 0 )); do
    # `|| true`: once the tagged stashes are drained (or there were none), the
    # grep matches nothing and exits 1; with `set -o pipefail` + `set -e` that
    # non-zero pipeline would otherwise kill the script mid-sweep (the dry-run
    # branch above guards its grep the same way).
    ref="$(git stash list --format='%gd %gs' 2>/dev/null \
          | grep -F "$STASH_MARKER" \
          | head -n1 \
          | awk '{print $1}' || true)"
    [[ -z "$ref" ]] && break
    git stash drop "$ref" >/dev/null
    dropped_stashes=$((dropped_stashes + 1))
  done
fi

# Plain `[[ cond ]] && assign` would exit non-zero when the test is false, and
# under `set -e` that kills the script right before the summary — so on a real
# (non-dry) run the janitor would see exit 1 and flag a clean sweep as a failure.
# Use explicit `if` so the status is always 0.
if [[ "$dry_run" -eq 1 ]]; then verb="would remove"; else verb="removed"; fi
if [[ "$removed_patches" -eq 1 ]]; then noun="entry"; else noun="entries"; fi
echo "sprint scratch janitor: ${verb} ${removed_patches} patch ${noun}, ${dropped_stashes} tagged stash(es)"
