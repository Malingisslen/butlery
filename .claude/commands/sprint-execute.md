---
description: Pick the next 3–10 tickets from Linear and implement them — self-sufficient, no triage step required
argument-hint: [N] [--dry-run] [--focus <area>] — N = ticket count (default auto-size 6–10), --dry-run previews without coding, --focus filters by area label
---

Self-sufficient sprint command. Selects the next batch of Linear tickets and implements them in one pass. No `/triage` prerequisite — that command was deleted because the scope-approval gate was rubber-stamp ceremony in a solo setup (see `memory/feedback_solo_no_scope_gate.md`).

## Prerequisites

1. Verify Linear MCP is connected (test `list_issues`). If not: "Linear MCP not connected. Run `/mcp` to reconnect." and stop.
2. If `$ARGUMENTS` contains `--dry-run`, run selection and print the plan without implementing.

## Phase 1 — Selection (replaces old `/triage plan`)

Gather these inputs in parallel:

- **Linear backlog** — `list_issues` with `team: "Butlery"` for states Backlog, Todo, In Progress, Triage. Extract: ID, title, priority, state, labels, due date.
- **Current sprint** — read `tasks/todo.md`. If unchecked tasks exist, ask: "Carry forward unchecked items, or archive and start fresh?" Otherwise no prompt.
- **Recent git activity** — `git log --since="7 days ago" --oneline --no-merges`. Map BUT-XXX references to detect already-completed tickets still in Backlog/Todo.

### Priority scoring per open ticket
- Urgent = 100, High = 75, Medium = 50, Low = 25
- Overdue: +50 ; Due this week: +25
- Bug or security label: +20
- In Triage state (ungroomed): −10

### Selection rules
- Default N = auto-size 6–10 based on backlog volume. `$ARGUMENTS` numeric arg overrides.
- `--focus <area>` filters by area label (recipe, tagging, import, parsing, social, menu, shopping, account, analytics, settings, backend). Warn if <3 tickets.
- Cluster tickets by area for coherent agent batching. Don't mix a 5-min lint fix with an architecture rework in one batch.
- Skip tickets that appear completed in git but still open in Linear — flag them in the report so they can be closed.

### Write the plan to `tasks/todo.md`

```markdown
## Sprint: [name] — [date]

### Agent A: [agent-name] — [theme]
- [ ] **A1. [verb] [description]** — `file/path.dart`: [change]. (BUT-XXX)
- [ ] **A2. ...** (BUT-YYY)

### Agent B: [agent-name] — [theme]
- [ ] **B1. ...** (BUT-ZZZ)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR
- [ ] Update Linear ticket states
```

Archive any prior sprint below a `---` separator.

**Linear state transition:** for each BUT-XXX in the new plan, transition state to "Todo" (resolve state UUIDs once via `list_issue_statuses`, then `save_issue` per ticket). Skip silently if Linear MCP unavailable.

**Do not pause for user approval of scope.** Per `feedback_solo_no_scope_gate.md`, the rubber-stamp "approve my picks" gate was deleted. Proceed straight to Phase 1.5. (Note: this is different from the per-ticket plan-mode gate in Phase 1.5 — that one fires on risky tickets specifically, not on the sprint as a whole.)

## Phase 1.5 — Risk-gated plan mode (hybrid)

**Why:** the file-plan in `tasks/todo.md` is durable but easy to drift from mid-iter (iter-46 lesson — wrote plan then jumped scope). For genuinely risky tickets — cross-cutting bugs, security surface, base classes that propagate through inheritance — `EnterPlanMode`'s forcing function (blocks Edit/Write/Bash until approval) prevents the batched-footgun class of error (iter-73 lesson). Mechanical cleanup doesn't benefit from the halt; routing P3/P4 tech-debt through plan mode wastes the autonomous loop. This phase splits the difference.

### Per-ticket risk score

For each ticket in the sprint, compute a binary `requires_plan_mode` flag:

```
requires_plan_mode = (
  priority <= 2  # Urgent or High
  OR (labels contains 'Bug' AND labels contains any of: backend, security, social, recipe, menu, shopping, account)
  OR (labels contains 'security')
  OR (estimated file-touch >= 3 AND ticket spans multiple modules — not a sweep within one dir)
)
```

**Skip the gate explicitly when:**
- Priority is Low (4) AND labels are pure `tech-debt` / `Improvement` / `test-gap` / `dependency`.
- Mechanical-rename, dead-code-deletion, single-line-fix patterns (e.g. BUT-1060 stale-dispose, BUT-1076 tier-rename, BUT-1097 deprecated-method-delete).
- Doc-only commits.

### If the gate fires

**Do NOT call `EnterPlanMode`.** The autonomous loop must not halt. Instead, write a richer plan for THIS ticket — both to disk and to chat — then proceed.

1. **Expand the file-plan** for this ticket in `tasks/todo.md` beyond the standard structure. Add explicit sub-sections (under the ticket's bullet):
   - **Step 0 classification** (fits / premise-gone / plan-stale + the reasoning)
   - **Files touched** (path + line range per site)
   - **Blast radius** (callers grepped, sibling sites checked, test impact)
   - **Product-intent flags** (anything uncertain about user-facing intent — flag but do NOT halt)
   - **Rollback shape** (one sentence on how to undo if it goes wrong)
2. **Echo a summary block in chat** before the first Edit:
   ```
   ★ Risky-ticket plan ─ BUT-XXXX ──────────────────
   Classification: <fits/plan-stale/premise-gone>
   Files: <list>
   Blast radius: <one-line>
   Proceeding automatically (no approval gate).
   ─────────────────────────────────────────────────
   ```
   This forces a moment of visible commitment that's hard to drift from, without halting the loop.
3. **Proceed to Phase 2** for this ticket immediately. No `EnterPlanMode`, no approval wait.

### If the gate doesn't fire

Skip the expansion. The standard file-plan section in `tasks/todo.md` is sufficient audit trail for mechanical work. Proceed directly to Phase 2.

### Discipline (no halt, but no excuses)

The point of Phase 1.5 is to write a BETTER plan for risky tickets, not to ask for approval. If the expanded-plan echo reveals scope confusion or product-intent uncertainty AFTER it's written, the right move is to file a follow-up Linear ticket capturing the uncertainty and proceed with the narrower-but-correct scope — not to halt the loop.

## Phase 2 — Execution

### Per-ticket Step 0 (mandatory, before any code)

Per `memory/feedback_ticket_premise_verification.md` — every ticket gets this gate before implementation:

1. **Read the code the ticket points at** (current state, not what the ticket assumes).
2. **Classify:**
   - **Fits** → implement as written.
   - **Premise gone** (problem already fixed / refactored away) → close the Linear ticket, link the resolving commit, mark the task `[~]` in todo.md with note "obsolete: <commit-sha>", skip to next ticket.
   - **Plan stale** (problem real, prescribed location/approach no longer fits) → re-scope inline. **Edit the Linear ticket body itself** to match the new plan (use `save_issue` with updated description). Then implement.
3. **If the ticket cites external specifics** (API names, library versions, security mechanisms) → verify against current docs (Context7 / web) before coding.
4. **Stop-and-ask only on product-intent uncertainty** — "does this user-facing goal still matter?" or "I can't tell what past-me was trying to achieve." Never stop for technical re-scopes; just do them.

The current code-read **always wins** over the ticket text when they disagree. Past-Claude wrote tickets during shallow scans across many issues; present-Claude has deeper context on the one ticket.

### Agent batching

Tasks under the same `### Agent` heading batch into one agent invocation. Don't spawn a separate agent per task.

### Per-task steps (after Step 0 says "fits" or "plan-stale + rescoped")

1. **Parse the task** — extract task ID, description, target files, suggested agent, BUT-XXX.
2. **Linear state update** — if BUT-XXX referenced:
   - Resolve "In Progress" state UUID (cache for session).
   - `get_issue` with BUT-XXX → Linear UUID.
   - `save_issue` with stateId: <In-Progress-uuid>.
   - `save_comment`: "Started implementation — [task description]".
   - Skip silently if Linear MCP unavailable.
3. **Implement** — invoke the suggested agent with the full task group, or implement directly.
4. **Verify** — `dart analyze --fatal-infos` on changed files. Fix any issues.
5. **Background test validation** — for batches that touched multiple `lib/` files:
   - Identify corresponding test paths (`test/unit/<area>/`).
   - Monitor: `bash .claude/hooks/monitors/test-streamer.sh <test-paths>` (persistent: false, timeout_ms: 600000).
   - Continue without waiting; address failures when notifications arrive.
6. **Check off** — mark `[x]` in todo.md.
7. **Report progress** — "Task A1 complete. Sprint: X/Y done."

### Error handling
- Task fails after 2 attempts: mark `[!]` in todo.md, note the error, continue to next.
- `dart analyze` fails with non-obvious fix: stop the sprint, report which task caused it.
- Never silently skip — always report.

## Phase 3 — Post-sprint (MANDATORY — sprint is not done until every step here completes)

**Failure mode being prevented:** prior sprints have ended with uncommitted changes and Linear tickets still in "In Progress." Phase 3 is non-optional. If you reach the end of Phase 2 and skip Phase 3, you have not finished the sprint.

After all tasks processed (or remaining tasks blocked):

1. **Full analyze** — `dart analyze --fatal-infos`. Fix anything fatal before continuing.

2. **File follow-ups as Linear tickets — MANDATORY before commit.** See "Follow-up rule" below. `tasks/todo.md` is overwritten by the next sprint, so any deferred work captured only there is silently lost. Linear is the durable backlog.

3. **Commit (inline, not delegated).** `/commit` is a slash command — invoking it from inside this command is a prose instruction, not an auto-execution. Run the commit workflow yourself, here, in this session:
   - `git status` and `git diff --staged` (stage with `git add` if needed).
   - Run `code-reviewer` agent on staged `.dart` files; fix Critical/High before proceeding.
   - Run `testing-specialist` agent on staged `lib/**/*.dart` files; fix failing tests before proceeding.
   - Write a conventional commit message (`feat:` / `fix:` / `refactor:` / etc.) with body explaining *why* + key changes + the "Known follow-ups (filed in Linear)" section listing the BUT-XXX tickets created in step 2. Footer: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>`.
   - `git commit`. If lefthook reformats and the commit fails, re-stage and commit again — never `--amend`, never `--no-verify`.
   - **Verification gate:** after commit, `git status` MUST show a clean working tree for tracked files. If it doesn't, the commit didn't capture everything — repeat step 3 until clean.

4. **Push** — `git push -u origin HEAD`.

5. **Close Linear tickets (inline, mandatory).** Do not assume `/commit` handled this — close them here too. For each BUT-XXX in the just-pushed commit whose corresponding todo.md task is checked `[x]`:
   - Resolve "Done" state UUID once via `list_issue_statuses` (cache for the session).
   - `get_issue` with BUT-XXX → Linear UUID.
   - `save_issue` with `stateId: <Done-uuid>`.
   - `save_comment`: "Fixed in commit `<7-char short hash>`. Changes: <commit subject>".
   - Report inline: "Closed BUT-XXX in Linear".
   - Tickets marked `[~]` (obsolete via Step 0): close with comment "Obsolete — already resolved by `<commit-sha>`".
   - Tickets marked `[!]` (failed): leave open, transition back to "Todo", post a comment with the failure reason.
   - Skip silently only if Linear MCP is genuinely disconnected — and report that fact in the final summary so the user knows to close manually.

6. **CI watcher** — Monitor: `bash .claude/hooks/monitors/ci-watcher.sh $(git rev-parse HEAD)` (persistent: false, timeout_ms: 900000). Continue without waiting; include CI status in final report when results arrive.

7. **PR (only if a PR is wanted)** — solo direct-to-main is the default per `CLAUDE.local.md`; skip `gh pr create` unless the sprint touched something risky enough to warrant review.

8. **Final report — must include explicit confirmation of every gate:**
   ```
   Sprint complete.
   - Tasks: X/Y done, Z blocked, W obsoleted
   - Commit: <short-sha> "<subject>"
   - Pushed: yes/no
   - Linear closed: BUT-XXX, BUT-YYY (N tickets)
   - Linear left open: BUT-ZZZ (failed — see comment)
   - Follow-ups filed: BUT-AAA, BUT-BBB
   - CI: pending / green / red
   ```
   If any line of that report is "skipped" or "n/a" without a real reason, you have not finished the sprint — go back and complete it.

## Follow-up rule (mandatory, applies in every phase)

**`tasks/todo.md` is sprint-scratch, not a backlog.** The next `/sprint-execute` overwrites it. Anything that needs to outlive the current sprint must land in Linear before the commit.

**File a Linear ticket for every:**

- **Deferred sub-scope** that an in-flight ticket explicitly drops (e.g. SafeSearch deferred from BUT-780; cert-pin fingerprints deferred from BUT-769).
- **Tier-2 reviewer finding** flagged "follow-up" or "out of scope" — code-reviewer / testing-specialist / firebase-backend-security / firestore-rules-tester gaps that aren't fixed inline.
- **ADR / decision-only ticket** whose execution is a future sprint (e.g. BUT-789 → ADR-002 → execution ticket).
- **Ops task** that requires production access this session can't reach (cert capture, console verification, Cloud Monitoring alert wiring, restore drill).
- **Test gap** the testing-specialist names but the sprint can't fill (CF integration tests requiring emulator, etc.).
- **"Refactor on the third repetition"** patterns identified during simplify pass.

**Don't file tickets for:**
- Work that fits in the current sprint — just do it.
- Speculative future ideas without a concrete trigger.
- Doc-only nits inside the just-shipped code (fix inline).

**Format:** create via `mcp__linear__save_issue` with `team: "Butlery"`, a meaningful priority (High for blockers / fail-loud security gates, Medium for active improvement, Low for "when convenient"), and labels matching the area + type (`backend`, `security`, `tech-debt`, `Bug`, `test-gap`, `Improvement`, `performance`, `dependency`, etc.). Body must include: source ("BUT-XXX follow-up" + commit SHA), what's needed, acceptance bullets, why deferred.

**Reference filed tickets in the commit message** under a "Known follow-ups (filed in Linear)" section — list `BUT-XXX — title` for each. The `Known follow-ups` section in `tasks/todo.md` is fine for the in-sprint working notes, but the Linear tickets are the source of truth.

## What this does NOT do

- Does not create worktrees (manual for parallel sprints).
- Does not merge PRs (Malin reviews and merges, or auto-merges per solo direct-to-main rule).
- Does not auto-start the next sprint (Malin re-runs `/sprint-execute` when ready).

## Relationship to /linear

- `/linear scan` — find NEW issues in code, create tickets.
- `/linear backlog` — pick ONE ticket interactively.
- `/linear status` — dashboard.
- `/sprint-execute` — pick a batch AND implement in one pass (this command).

`/triage` was removed (2026-05-03). Its prioritization logic now lives in Phase 1 above.
