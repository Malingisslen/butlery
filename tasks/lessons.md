# Session Lessons

Learnings from corrections. Claude reviews at session start and adds entries after corrections.

---

## Active Lessons

<!-- Entries added automatically after user corrections -->
<!-- Format: ### [Category] Title -->
<!-- Date | Trigger | Rule | Example -->

### [Workflow] Bash `cd` persists across calls — use absolute paths for greps
- **Date**: 2026-05-04
- **Trigger**: During BUT-555 sembast audit, my `grep -rn "sembast" lib/` returned zero matches even though `lib/core/cache/cache_dao_stub.dart` clearly imports `package:sembast_web/sembast_web.dart`. Reason: the previous Bash call ran `cd functions && npm run build`, so the shell session was inside `functions/` when the grep ran — `lib/` resolved to `functions/lib/`, which doesn't contain those files. I almost dropped the deps thinking they were dead.
- **Rule**:
  1. Prefer the **Grep tool** over `bash grep` whenever possible — it always operates from the project root.
  2. When using `bash grep`/`find`/`ls`, either use absolute paths or `cd /c/Butlery/butlery &&` explicitly.
  3. Trust **`dart analyze --fatal-infos`** as the final gate before claiming a refactor done. It caught this one.
- **Example**: After re-running with `grep -rn "sembast" --include="*.dart" /c/Butlery/butlery/lib/`, the consumer was visible immediately. Reverted pubspec changes; BUT-555 outcome = audited & kept (both deps actively used; comments added pointing at consumers).
- **Files**: `pubspec.yaml` (sembast/sembast_web kept with consumer-pointer comments)

### [Workflow] Verify ticket premise before implementing — collapse triage gate
- **Date**: 2026-05-03
- **Trigger**: Mid-conversation, I noted that BUT-760's prescribed fix (App Attest) might not match current `firebase_app_check 0.4.0` API. Malin asked whether tickets should be deeply re-verified before execution given they may be stale, then pushed further: "you create the linear tickets and implement the fixes" — and "I always just approve [the sprint plan]."
- **Rule**:
  1. Linear tickets are notes from past-Claude (during shallow `/triage` scans) to future-Claude. Their authority is *lower* than the implementer's current code-read. The current code-read wins on disagreement.
  2. Run a Step 0 classification on every ticket before coding: **fits / premise-gone / plan-stale**. On `premise-gone`, close the ticket. On `plan-stale`, **rewrite the Linear ticket body** (not a footnote comment) and proceed. Stop-and-ask only on product-intent ambiguity, never on technical re-scopes.
  3. The two-step `/triage plan` → `/sprint-execute` workflow was a rubber-stamp gate (Malin always approved). **Deleted** `/triage`. `/sprint-execute` now picks tickets *and* implements in one call. In a solo-agent setup, the natural unit of approval is the commit/PR, not the sprint plan.
  4. A gate that always passes is worse than no gate — it signals oversight that isn't happening.
- **Example**: BUT-760 ticket said "use App Attest with DeviceCheck fallback." Without Step 0, I would have implemented that blindly even if 0.4.0's API or current security recommendations made it wrong. Step 0 forces a current code-read + (if external claims are made) a Context7 verification before coding.
- **Files**: `memory/feedback_ticket_premise_verification.md`, `memory/feedback_solo_no_scope_gate.md`, `.claude/commands/sprint-execute.md` (rewritten), `.claude/commands/triage.md` (deleted), `.claude/commands/commit.md` (updated reference), `.claude/hooks/setup-morning-brief.sh` (updated reference).

### [Workflow] Stop hook — don't fix errors from other sessions
- **Date**: 2026-04-08
- **Trigger**: Stop hook fired with analyze errors on files not modified in this session. I correctly identified them as pre-existing (commit 0dc221f03) but started fixing them anyway.
- **Rule**: FIRST check: did this session modify the erroring files? If NO → these belong to a parallel session. Do NOT touch them. Tell the user they're pre-existing and move on. Only fix errors in files THIS session actually changed.
- **Example**: `recipe_service_adapter_test.dart` had errors calling non-existent methods. Git status was clean at session start, we only chatted. Correct response: "These are pre-existing from another session, not fixing them."

---

## Archived

<!-- Internalized patterns moved here -->
