#!/usr/bin/env bash
# PreToolUse(ExitPlanMode): GATED, non-blocking nudge to run the Phase-2 panel.
#
# This is the money-pit guard (adopted from Binge's reference implementation): it
# SCANS THE FINISHED PLAN TEXT for high-stakes signals and only THEN suggests
# /stakeholder-review. Routine plans (a CSS tweak, a copy fix) get SILENCE. The
# panel is expensive (~0.6M tokens for a full high-stakes review); reserve it for
# plans where it pays for itself. Never auto-runs, never blocks (that's
# plan-review-gate.sh's job). Fails open.
#
# See docs/architecture/ROLE_ORG_DESIGN.md (Phase 2) and .claude/skills/stakeholder-review.md.

set -euo pipefail

INPUT=$(cat 2>/dev/null || echo "{}")
PARSER=".claude/hooks/parse_hook_json.py"
PYTHON=$(command -v py >/dev/null 2>&1 && echo "py -3" || (command -v python3 >/dev/null 2>&1 && echo python3 || echo python))

# The plan text: prefer the ExitPlanMode tool input, fall back to tasks/todo.md.
PLAN=$(printf '%s' "$INPUT" | $PYTHON "$PARSER" tool_input.plan 2>/dev/null || true)
if [ -z "$PLAN" ] && [ -f tasks/todo.md ]; then PLAN=$(cat tasks/todo.md 2>/dev/null || true); fi
[ -z "$PLAN" ] && exit 0

# High-stakes signals -ONLY these warrant the expensive panel. Anything else: silence.
# (security rules, GDPR/personal data, auth, Cloud Functions, moderation, destructive
# data ops, payments, allergen-safety, LLM -Butlery's veto-level surfaces.)
SIGNALS='firestore\.rules|storage\.rules|security rule|\bgdpr\b|personal data|\bpii\b|privacy polic|consent|\bauth\b|authentication|\bpassword\b|sign-?up|login|age.?gate|minimum age|coppa|cloud function|functions/src|moderation|report(ing)? abuse|trust.?(and|&|.) ?safety|\bdelet(e|ion)|erasure|retention|purge|destructive|payment|billing|subscription|monetiz|allergen|\bllm\b|vertex|\bocr\b'

HITS=$(printf '%s' "$PLAN" | grep -ioE "$SIGNALS" 2>/dev/null | tr 'A-Z' 'a-z' | sort -u | tr '\n' ',' | sed 's/,$//' || true)
[ -z "$HITS" ] && exit 0   # routine plan -> stay silent

MSG="This plan touches high-stakes areas ($HITS). Consider running /stakeholder-review on it before finalizing. The role-org panel routes to the right stakeholders, runs parallel blind critiques (scoped to the plan's blast-radius files), and records disagreements as ADRs. The router picks the tier: a full panel only for high-stakes/broad plans, a SINGLE stakeholder for mid-risk. Non-blocking and advisory; skip it if you judge this routine."

printf '%s' "$MSG" | $PYTHON -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":sys.stdin.read()}}))' 2>/dev/null || true

exit 0
