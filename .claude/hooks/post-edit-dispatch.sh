#!/usr/bin/env bash
# PostToolUse Write|Edit — single entry point for the post-edit guardrail chain.
#
# Replaces 8 settings.json entries with 1. Reads stdin ONCE, resolves the repo
# root ONCE (the settings.json wrapper already cd'd here), extracts the payload
# fields with ONE parse_hook_json.py call, then runs only the scripts whose
# pure-bash relevance gate matches.
#
# Measured before this existed: an edit matching none of the eight still cost
# 5.21s of shell and ~23 process launches, because six of the eight spawned
# Python to parse the payload BEFORE the cheap test that rejects the file.
#
# CONTRACT WITH THE CHILD SCRIPTS
#   Every gate below is a superset of the child's own internal guard, so a gate
#   can only over-invoke, never under-invoke. Children KEEP their guards
#   (defence in depth) and stay runnable standalone by piping hook JSON in.
#
# NOT set -e: the 8 entries were independent and one failing never stopped the
# rest. run() swallows every non-zero to preserve that.
#
# NOTE: this chain is not the whole story. Three more PostToolUse Write|Edit
# hooks come from enabled plugins (role-org's dossier-stamp.mjs, workflow-guards'
# track-session-files.mjs and memory-index-guard.mjs) and are declared outside
# this repo. Nothing here speeds those up.

set -uo pipefail

# ---------------------------------------------------------------- payload ---
JSON=$(cat 2>/dev/null || true)
[[ -z "$JSON" ]] && exit 0

# Python probe: same order as the children use. With no Python at all, every
# child's own extraction fails and it exits 0 — reproduce that exactly.
if command -v py >/dev/null 2>&1; then        PY="py -3"
elif command -v python3 >/dev/null 2>&1; then PY="python3"
elif command -v python >/dev/null 2>&1; then  PY="python"
else exit 0
fi

HELPER=".claude/hooks/parse_hook_json.py"
[[ -f "$HELPER" ]] || exit 0

# ONE python spawn for the whole chain. parse_hook_json.py prints one line per
# requested dotted field and carries the Windows backslash-corruption regex
# fallback that the hand-rolled `python3 -c` snippets lacked.
FIELDS=$(printf '%s' "$JSON" | $PY "$HELPER" \
           tool_input.file_path tool_response.filePath session_id cwd 2>/dev/null) || exit 0

FILE_A=$(sed -n '1p' <<<"$FIELDS")
FILE_B=$(sed -n '2p' <<<"$FIELDS")
FILE="${FILE_A:-$FILE_B}"                      # same coalesce every child does

ROOT=$(pwd)                                    # wrapper already cd'd to toplevel

# --------------------------------------------------------- exported truth ---
# ONLY raw parsed scalars are exported. Nothing DERIVED (a relative path, a repo
# root treated as authority) crosses the boundary, so no child inherits a
# derivation that disagrees with its own — map_stamp.py in particular must keep
# computing repo_root()/rel_path() itself or the .stale marker could land
# somewhere else.
export BUTLERY_HOOK_DISPATCH=1
export BUTLERY_HOOK_FILE="$FILE"
export BUTLERY_HOOK_SESSION_ID="$(sed -n '3p' <<<"$FIELDS")"
export BUTLERY_HOOK_CWD="$(sed -n '4p' <<<"$FIELDS")"

# The payload is NEVER put in an environment variable: Windows caps the whole
# environment block at 32767 characters and a Write payload carries the entire
# file in tool_input.content, so a large write would break every child spawn.
# printf is a builtin, so re-feeding stdin costs a pipe and no process.
RC_BLOCK=0
run() {
  local s="$1"
  [[ -f "$ROOT/.claude/hooks/$s" ]] || return 0
  printf '%s' "$JSON" | bash "$ROOT/.claude/hooks/$s"
  local rc=$?
  [[ $rc -eq 2 ]] && RC_BLOCK=2                # 2 is the harness "block" code
  return 0
}

# Escape hatch: run everything unconditionally, bypassing the gates. Isolates
# "a gate is wrong" from "the dispatcher is wrong" without touching settings.
#
# `dart format` must run here too. An earlier version looped over the 7 child
# scripts only and returned before reaching the formatter below, so the hatch
# silently stopped formatting .dart files — caught by the harness's --gates-off
# control, which is precisely the failure that control exists to find.
if [[ "${BUTLERY_HOOK_GATES:-on}" == "off" ]]; then
  if [[ -n "$FILE" && "$FILE" == *.dart ]]; then
    { dart format "$FILE" 2>/dev/null || true; } 1>&2
  fi
  for s in safety-skill-trigger.sh file-size-guard.sh rules-change-detector.sh \
           regenerate-l10n.sh drift-version-guard.sh firestore-index-verifier.sh \
           map-freshness-stamp.sh; do run "$s"; done
  exit "$RC_BLOCK"
fi

# --------------------------------------------- gate-only derived rel path ---
# Mirrors map_stamp.drive_norm/rel_path, used ONLY to decide whether to spawn.
norm() {
  local p="${1//\\//}"
  case "$p" in /[a-zA-Z]/*) p="${p:1:1}:${p:2}" ;; esac
  case "$p" in [a-zA-Z]:/*) p="${p^}" ;; esac
  printf '%s' "$p"
}
NF=$(norm "$FILE"); NR=$(norm "$ROOT"); NR="${NR%/}"
if [[ -n "$NF" && "$NF" == "$NR"/* ]]; then REL="${NF#"$NR"/}"; else REL="${NF#/}"; fi

# ================================ gates ====================================
# Order is byte-identical to the pre-consolidation settings.json order.

# 1. dart format (was the inline bash -c entry).
#    stdout MUST be redirected: `dart format` prints "Formatted 1 file." and this
#    entry's stdout is now shared with safety-skill-trigger.sh's JSON payload.
#    At most ONE script in this chain may write to stdout.
if [[ -n "$FILE" && "$FILE" == *.dart ]]; then
  { dart format "$FILE" 2>/dev/null || true; } 1>&2
fi

if [[ -n "$FILE" ]]; then
  # 2-3. same predicate as each script's own `.dart` guard
  case "$FILE" in *.dart) run safety-skill-trigger.sh ;; esac
  case "$FILE" in *.dart) run file-size-guard.sh ;; esac
  # 4. superset of */firestore.rules|firestore.rules and */__tests__/*-rules.test.ts
  case "$FILE" in *firestore.rules|*rules.test.ts) run rules-change-detector.sh ;; esac
  # 5. superset of *lib/l10n/*.arb
  case "$FILE" in *.arb) run regenerate-l10n.sh ;; esac
  # 6. superset of *lib/core/storage/drift/tables/*.dart
  case "$FILE" in *drift/tables/*.dart) run drift-version-guard.sh ;; esac
  # 7. drops the lib/ qualifier from the script's own case
  case "$FILE" in *repositories/*.dart|*services/*.dart) run firestore-index-verifier.sh ;; esac
  # 8. map_stamp.py:84 filters every token through
  #    tok.startswith(("lib/","functions/","test/","tools/")) and all three
  #    branches of matches() preserve that prefix, so nothing outside those four
  #    roots can ever stamp. nocasematch because fnmatch normcases on Windows.
  #    If REPO_ROOTS there changes, this list must change with it.
  shopt -s nocasematch
  case "$REL" in
    lib/*|functions/*|test/*|tools/*) run map-freshness-stamp.sh ;;
    *) case "$NF" in   # belt-and-braces if the REL derivation disagreed
         */lib/*|*/functions/*|*/test/*|*/tools/*) run map-freshness-stamp.sh ;;
       esac ;;
  esac
  shopt -u nocasematch
fi

exit "$RC_BLOCK"
