# Session Lessons

Learnings from corrections. Claude reviews at session start and adds entries after corrections.

---

### [Workflow] Late-phase side-effect agents must be wrapped — a Ship schema miss discarded a 1.13M-token run
- **Date**: 2026-05-29
- **Trigger**: `sprint-execute-parallel` ran iter-100 fully (8 tickets implemented + integrated + per-batch reviewed), then the Ship agent finished its git/Linear Bash steps WITHOUT calling StructuredOutput. `await agent({schema})` threw after 2 nudges and the unwrapped throw discarded the entire run. Nothing committed.
- **Rule**:
  1. In a workflow, any late-phase agent whose real output is *side effects* (commit/push/Linear), not its return value, must be wrapped in try/catch so a StructuredOutput miss can't nuke all upstream work.
  2. Follow it with a short focused **verify** agent that reads ground truth (`git log -1`, `git status --porcelain`, `git rev-list --count @{u}..HEAD`) and build the summary from that, not the agent's self-report. Return a recoverable status (`ship-incomplete`), never throw.
  3. Salvage a post-integration crash instead of re-running (each attempt = ~1.13M tokens): work is in the tree (Phase 0 guaranteed clean start), so verify analyze + tests → touch markers (honest, review ran) → `git add -A` + commit + push → reconcile Linear by querying current state (don't trust the crashed Ship's partial writes) → clean orphan worktrees + leftover patches.
- **Example**: Salvaged iter-100 → commit `43b3aadb3`, 7 tickets Done + BUT-1095 Canceled. Hardened the workflow (try/catch + verify-ship agent). See `memory/feedback_workflow_ship_resilience.md`.

## Active Lessons

<!-- Entries added automatically after user corrections -->
<!-- Format: ### [Category] Title -->
<!-- Date | Trigger | Rule | Example -->

### [Workflow] /sprint-execute Phase 1 plan-write is non-optional, even mid-streak
- **Date**: 2026-05-24
- **Trigger**: Iter 46 of an autonomous /loop session (~14 closes deep). User: "Men nu skippar du ju planning stagen eller?" After iter-2 correction in same session, I drifted again: iters 33–45 jumped straight to implementation without writing `tasks/todo.md` first. The Step 0 + plan write to `tasks/todo.md` was happening only in my head, not on disk.
- **Rule**:
  1. `/sprint-execute` Phase 1 ALWAYS writes the plan to `tasks/todo.md` before any code. This is not optional, even for "obviously trivial" tickets.
  2. Streak/momentum is not a license to skip discipline. A 14-iter streak is exactly when discipline matters most — drift compounds.
  3. The plan-file is also the durable audit trail. Mental plans evaporate; `tasks/todo.md` survives context compactions, parallel sessions, and future-Claude re-reads.
- **Example**: Iter 46 BUT-883 codemod — wrote retroactive plan to `tasks/todo.md` after pushback. For iter 47+: plan-file FIRST, then implementation, even for 1-file changes.
- **Files**: `tasks/todo.md` (always), `lessons.md` (this entry)

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

### [Workflow] Verify Edit succeeded before committing — never trust the commit-message claim
- **Date**: 2026-05-25
- **Trigger**: Iter 73 (BUT-1084). Called `Edit` on `.claude/agents/testing-specialist.knowledge.md` without a prior `Read`. The Edit tool returned `tool_use_error: File has not been read yet`, but I had batched it with `git add … && git commit …` in the same Bash chain. Git happily committed only the `tasks/todo.md` change. Pushed commit `96146b05f` had a body claiming the sanitizer entry was appended, but it wasn't. Caught it on post-commit diff inspection.
- **Rule**:
  1. After an `Edit` that errors, STOP. Don't proceed to commit-and-push assuming the file changed. The error message is canonical.
  2. Never batch `Edit` + `git add` + `git commit` in a single Bash chain — the Edit's success/failure is invisible until you read the tool response, by which point the commit has already happened.
  3. Always Read first if the harness hasn't tracked the file yet. The Read-before-Edit harness rule exists exactly to prevent this class of "tool said no, I didn't notice" failure.
  4. Honesty over completion (CLAUDE.md #10): if a commit claims X happened and X didn't, push a fix-up commit immediately rather than pretending it's done.
- **Example**: Recovery — push `8ebb36be5` "actually append BUT-1061 sanitizer entry (BUT-1084 fix-up)" referencing the bad commit. Don't `--amend` or rewrite history (CLAUDE.md never-amend rule).

### [Workflow] Stop hook — don't fix errors from other sessions
- **Date**: 2026-04-08
- **Trigger**: Stop hook fired with analyze errors on files not modified in this session. I correctly identified them as pre-existing (commit 0dc221f03) but started fixing them anyway.
- **Rule**: FIRST check: did this session modify the erroring files? If NO → these belong to a parallel session. Do NOT touch them. Tell the user they're pre-existing and move on. Only fix errors in files THIS session actually changed.
- **Example**: `recipe_service_adapter_test.dart` had errors calling non-existent methods. Git status was clean at session start, we only chatted. Correct response: "These are pre-existing from another session, not fixing them."

### [Workflow] Workflow `args` can arrive as a STRING — a stringified dryRun ran a full sprint to main
- **Date**: 2026-05-28
- **Trigger**: User asked for a `dryRun` of the `sprint-execute-parallel` workflow. I invoked `Workflow({args: {"dryRun": true}})` but the value reached the script as the JSON *string* `'{"dryRun": true}'`, not an object. `args.dryRun` was therefore `undefined`, `DRY_RUN` was `false`, the early-return gate was skipped, and the FULL pipeline ran: 7 tickets implemented, commit `631fceec4` pushed to main, 11 Linear tickets closed. A "preview" became a live ship.
- **Rule**:
  1. The Workflow tool warns "a stringified list reaches the script as one string" — defend against it. Parse `args` if `typeof args === 'string'` before reading any flag. Use strict equality for booleans (`x === true || x === 'true'`), never bare truthiness on a flag whose absence is dangerous.
  2. Any workflow that pushes/commits MUST have a clean-tree precondition (`git status --porcelain`) and abort if dirty — `git add -A` otherwise bundles unrelated in-flight work into the sprint commit (here it swept the pre-existing iter-98 changes into iter-99's commit, closing tickets BUT-1031/953/1004 that weren't in scope).
  3. A `dryRun` flag must gate ALL side effects (file writes, Linear transitions), not just the final implementation phase. "Preview" means read-only.
  4. For a destructive/outward-facing workflow, prefer fail-safe defaults: an unparseable or missing flag should bias toward NOT shipping, not toward shipping.
- **Example**: Hardened `.claude/workflows/sprint-execute-parallel.js` — defensive `args` parse, Phase 0 clean-tree abort (override via `allowDirty`), and read-only dry-run. See `memory/feedback_workflow_args_stringification.md`.

### [Workflow] Umbrella "apply the deferred review notes" tickets lose their content
- **Date**: 2026-05-29
- **Trigger**: iter-103 inherited BUT-1165 — an umbrella ticket whose body said "the 10 non-blocking iter-99 review findings are captured here so they outlive sprint-scratch `tasks/todo.md`." But the actual notes were never copied into the ticket; only a pointer + the list of area names was. The next sprint overwrote `tasks/todo.md`, so the specific findings evaporated. No durable `TODO(BUT-XXXX)` markers existed in `lib/` either. The ticket became permanently unmeetable — its acceptance ("each finding fixed or tracked") referenced data that no longer exists.
- **Rule**: A non-blocking reviewer finding must be filed as its **own discrete Linear ticket with the finding text in the body** at review time — never deferred into an umbrella that merely *points at* sprint-scratch. The sprint-execute follow-up rule already mandates this ("file a Linear ticket for every Tier-2 reviewer finding flagged follow-up"); the failure mode is creating ONE umbrella instead of N discrete tickets. If you ever inherit such an umbrella: spot-check the named areas for residual gaps, then close it honestly (areas verified / notes unrecoverable) rather than leaving an unmeetable ticket open or manufacturing fake findings to "complete" it.
- **Example**: BUT-1165 closed Done with a verification verdict — the 3 robustness-critical areas (presence dispose, shopping batch rollback, social-coordinator `_disposed` gate) were confirmed shipped defensively with tests in `631fceec4`; the lost notes were documented as unrecoverable rather than fabricated.

---

## Archived

<!-- Internalized patterns moved here -->
