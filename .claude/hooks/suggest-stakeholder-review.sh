#!/usr/bin/env bash
# PreToolUse(ExitPlanMode) hook: NON-BLOCKING nudge to consider running the
# Phase-2 stakeholder review on a plan. Validated 2026-06-27: a full-panel review
# caught a false premise + a genuine legal split + ~8 conditions a solo plan missed
# (~0.6M tokens for a high-stakes plan — worth it there, overkill for trivial ones).
# So this only SUGGESTS; the human decides whether to spend the tokens. Runs
# alongside plan-review-gate.sh (which does the blocking). Fails open.
#
# See docs/architecture/ROLE_ORG_DESIGN.md (Phase 2) and .claude/skills/stakeholder-review.md.

set -euo pipefail

MSG="Before finalizing this plan, consider running /stakeholder-review on it — the role-org \
deliberation panel. It's most worth the tokens when the plan touches HIGH-STAKES paths \
(firestore.rules, lib/services/{auth,security,llm,account}, functions/src/{account,audit_logs,cleanup,llm}, \
payments) or 3+ areas; it routes to the right stakeholders, runs parallel blind critiques, and records \
any disagreement as an ADR. Skip it for trivial/doc-only plans (the router will say 'skip' anyway). \
This is advisory — not required to proceed."

PYTHON=$(command -v py >/dev/null 2>&1 && echo "py -3" || (command -v python3 >/dev/null 2>&1 && echo python3 || echo python))

# Emit additive context for the model; never block (that's plan-review-gate's job).
printf '%s' "$MSG" | $PYTHON -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":sys.stdin.read()}}))' 2>/dev/null || true

exit 0
