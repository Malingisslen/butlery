#!/usr/bin/env bash
# PreToolUse hook (Write): a NEW screen under lib/views/ may not be created
# until a design-directions preview has been shown to Malin for it.
#
# Rationale: Malin can't read code but reads every visual. Recognizing a
# preference is far easier than specifying one, so a new view should start
# from "react to these variants" (per docs' design-directions pattern +
# .claude/rules/html-previews.md), not from code she can't see. This makes
# that step physics, mirroring the review-marker gates.
#
# Fires ONLY when: tool is Write, target is a NEW file (does not yet exist),
# under lib/views/, ends in .dart, and is not a *_test.dart. Editing an
# existing view, or any non-view file, never trips it.
#
# Satisfy the gate with a marker:
#   .claude/state/preview-done-<slug>.marker   (<slug> = view basename sans .dart)
# The /preview skill (design-directions mode) stamps this after showing
# variants + collecting Malin's steal/skip choices. Escape hatch for a
# genuinely non-visual view (rare) or a mechanical move: SKIP_PREVIEW_GATE=1.
# Fail-open on any parse error — never brick file creation.

set -uo pipefail

[ "${SKIP_PREVIEW_GATE:-0}" = "1" ] && exit 0

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$HOOK_DIR/parse_hook_json.py"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"
STATE_DIR="$HOME/.claude/state"

INPUT=$(cat 2>/dev/null || echo "{}")

FIELDS=$(printf '%s' "$INPUT" | python "$PARSER" tool_input.file_path cwd 2>/dev/null) || exit 0
FILE_PATH=$(echo "$FIELDS" | sed -n '1p')
CWD_RAW=$(echo "$FIELDS" | sed -n '2p')
[ -z "$FILE_PATH" ] && exit 0

REL_PATH=$(python -c "
import sys, os, re
fp = sys.argv[1].replace('\\\\', '/')
cwd = (sys.argv[2] or os.getcwd()).replace('\\\\', '/')
cwd = cwd.rstrip('/')
def norm(p):
    m = re.match(r'^/([a-zA-Z])/(.*)', p)
    if m: return m.group(1).upper() + ':/' + m.group(2)
    m = re.match(r'^([a-zA-Z]):/(.*)', p)
    if m: return m.group(1).upper() + ':/' + m.group(2)
    return p
fp, cwd = norm(fp), norm(cwd)
if fp.startswith(cwd + '/'): fp = fp[len(cwd)+1:]
print(fp)
" "$FILE_PATH" "$CWD_RAW" 2>/dev/null) || exit 0

# Scope: new lib/views/ dart file, not a test.
case "$REL_PATH" in
  lib/views/*_test.dart) exit 0 ;;
  lib/views/*.dart) : ;;
  *) exit 0 ;;
esac

# Only a NEW file trips the gate — editing an existing view is fine.
ABS="$PROJECT_ROOT/$REL_PATH"
[ -f "$ABS" ] && exit 0

SLUG=$(basename "$REL_PATH" .dart)
MARKER="$STATE_DIR/preview-done-$SLUG.marker"
[ -f "$MARKER" ] && exit 0

REASON="PREVIEW GATE: creating a new screen ($REL_PATH) with no design-directions preview.

Malin reads visuals, not code — a new view starts from variants she can react to, not
code she can't see (.claude/rules/html-previews.md + the design-directions pattern).

Do ONE of:
  1. Run /preview --directions for this screen (the workflow-guards plugin's preview
     skill — ships with this repo's plugins): 3-4 deliberately INCOMPATIBLE variants with steal/skip
     chips at tasks/previews/$SLUG-directions.html, rendered to Malin; after her picks are
     folded into the design decision, stamp: touch \"$MARKER\" — then retry this Write.
  2. Genuinely non-visual view or a mechanical file move → SKIP_PREVIEW_GATE=1 and say so.

Do NOT hand-build the view first and preview after — the point is she shapes it before it exists."

PYTHONIOENCODING=utf-8 python -c 'import json,sys; sys.stdout.write(json.dumps({"decision":"block","reason":sys.stdin.read()},ensure_ascii=False))' <<< "$REASON" 2>/dev/null
