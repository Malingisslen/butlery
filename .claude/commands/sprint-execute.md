---
description: Pick the next 3–10 tickets from Linear and implement them — self-sufficient, no triage step required
argument-hint: [N] [malin] [--pick] [--dry-run] [--focus <area>] [--no-review] — N = ticket count (default auto-size 6–10), malin = also surface + prep everything waiting on you (need-malin lane + Tier-D blockers + parked high-stakes) and ask you live at the end, --pick = interactive single/few-ticket selection (replaces the old /linear backlog), --dry-run previews without coding, --focus filters by area label, --no-review disables the always-on stakeholder panel (default: experts ON)
---

Self-sufficient sprint command. Selects the next batch of Linear tickets and implements them in one pass. No `/triage` prerequisite — that command was deleted because the scope-approval gate was rubber-stamp ceremony in a solo setup (see `memory/feedback_solo_no_scope_gate.md`).

## Prerequisites

1. Verify Linear MCP is connected (test `list_issues`). If not: "Linear MCP not connected. Run `/mcp` to reconnect." and stop.
2. If `$ARGUMENTS` contains `--dry-run`, run selection and print the plan without implementing.
3. If `$ARGUMENTS` contains `--pick`, selection is interactive (you choose the ticket(s)) instead of auto-batch — see "Interactive pick mode" in Phase 1.
4. If `$ARGUMENTS` contains `malin` (positional keyword; `--malin` also accepted), enable **Malin decision-queue mode** — see Phase 3.6. The normal sprint runs unchanged; this only ADDS a prepared decision pass at the very end. Because Malin typed it, she is present, so that pass asks her **live** (`AskUserQuestion`) instead of parking — the one thing the autonomous loop can't do.

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

### Autonomy-tier classification (do this for every candidate BEFORE selecting)

The backlog is no longer filtered down to "clean code-only" tickets. Classify each open
ticket into one of four tiers — this decides whether to attempt it, what verification it
needs, and whether it closes to **Done** or parks in **In Review** (see Phase 1.6 for the
full handling). The loop NEVER halts on tier — UI and large refactors ship to main and get
reviewed async via the In-Review state + a push notification.

- **Tier A — Full-auto.** Backend/service logic, data, parsing, tagging, test-gaps, tooling,
  lint/arch guards, refactors contained within one module, dependency bumps that don't need
  the SDK. No user-facing UI surface, no prod/ops dependency. → implement → main → close **Done**.
- **Tier B — UI-visual.** New or changed user-facing UI (new views, layout, color, affordances,
  empty states, discoverability). I CAN build these — I just can't be the one who signs off on
  how they look. → implement per design system + the UI/UX prefs in memory → HTML preview +
  Chrome screenshot → self-review vs mockups → main → **In Review** + push the screenshot.
- **Tier C — Large/risky refactor.** Cross-module reworks, base-class changes that propagate
  through inheritance, multi-file codemods with behavioral-divergence risk, files >500 lines
  being decomposed, cold-start/bootstrap changes. → Phase 1.5 expanded plan (no halt) →
  implement incrementally → full test suite + behavior diff → main → **In Review** + notify.
- **Tier D — Ops-blocked.** Genuinely needs prod/console access, a deploy, store/Play
  submission, MFA/auth-provider config, an external account, or secrets the loop can't reach.
  → do NOT attempt. Post a Linear comment enumerating the exact human/ops action required,
  then skip. Surface in the final report under "Needs you".

When unsure between A and C, treat it as C (richer plan, In Review). When unsure between B and
anything, treat it as B (it has a visual surface → needs eyes). Tier D is only for *true*
external blockers — "I'd rather not" is not Tier D.

### Stakeholder routing (experts always on — do this for every candidate at selection)

Butlery is complex enough that the right specialist is assigned to a ticket **from the start**,
not bolted on as an after-the-fact review. For every candidate ticket, resolve its likely-touched
paths (the Step-0 code read + the area labels) and run the role-org router:

```
python tools/stakeholder_router.py --json <likely paths...>
```

Record per ticket: its `tier` (`skip` / `single` / `full-panel`), its `panel` (the owning
role(s), plus the high-stakes core if full-panel), and any `high_stakes_hits`. This is one
deterministic Python call (no agents) — cheap, and it's what makes "always on" affordable:
the router bounds depth by blast radius so a doc-only ticket is skipped, a clean backend ticket
draws one owning specialist, and only genuinely high-stakes tickets convene the full panel.

Carry the panel into `tasks/todo.md` next to each task (`Stakeholders: <roles>`) and into the
Phase 1.4 review below. The router's tier is also the single risk signal Phase 1.5 uses — there
is no second hand-rolled formula (Seam unified with `/stakeholder-review`).

### Selection rules
- **NEVER select tickets labeled `onboarding-reserved`.** These are reserved as human onboarding capstones (e.g. BUT-677, BUT-722) and must stay untouched by the autonomous loop. Exclude them from selection entirely — don't score them, don't transition them, don't implement them.
- Default N = auto-size 6–10 based on backlog volume. `$ARGUMENTS` numeric arg overrides.
- **Mix tiers deliberately.** A healthy batch is mostly Tier A/B/C work — don't skip a ticket
  just because it's UI or a refactor; route it through its tier. Aim for a spread (e.g. 2–3
  Tier A + 1–2 Tier B + 0–1 Tier C) unless `--focus` narrows it. Genuinely-clean Tier A work
  may be scarce now (iter-103→105 drained it) — that's expected; lean into B and C.
- `--focus <area>` filters by area label (recipe, tagging, import, parsing, social, menu, shopping, account, analytics, settings, backend). Warn if <3 tickets.
- Cluster tickets by area/tier for coherent agent batching. Don't mix a 5-min lint fix with an architecture rework in one batch — but DO include both across the sprint.
- Skip tickets that appear completed in git but still open in Linear — flag them in the report so they can be closed.
- Tier D tickets don't count toward N — they're flagged, not worked. If the whole batch would be
  Tier D, say so plainly and pace down instead of forcing blocked work.

### Interactive pick mode (`--pick`) — replaces the old `/linear backlog`

`--pick` hands selection to you instead of auto-selecting a batch. Use it for "I'm here, let's
knock out one specific thing together." Everything downstream — routing, the Phase 1.4 panel,
verification, commit, push, close — is identical; only *selection* differs.

1. Run the same gather + score + tier-classify + route as above, but do NOT auto-select.
2. Present the candidates grouped, the way the old `/linear backlog` did:
   - **Type:** bug (3), security (1), tech-debt (5), …
   - **Area:** parsing (4), recipe (2), social (1), …
   - **Effort:** XS / S / M / L, judged now
   - **Stakeholders / tier:** each candidate's owning role(s) + router tier, so you can see what
     review it'll draw *before* you pick.
3. Ask which to take — a filter ("bugs", "parsing", "quick wins"), a specific BUT-XXX, or the
   top-scored match. Default to one ticket; you may pick a few.
4. On your confirmation, proceed through Phase 1.4 onward for the chosen ticket(s). Because you're
   present, Phase 1.4 escalates a high-stakes conflict to you **live** (`AskUserQuestion`) instead
   of parking it — the one thing the autonomous loop can't do.

`--pick` composes with `--dry-run` (`--pick --dry-run` lists the grouped candidates and stops) and
with `--no-review` (disables the panel for the picked ticket).

**Pacing the loop down is gated (mechanical).** Before you may signal "backlog drained / needs
you" or schedule a long wake delay in a `/loop /sprint-execute` run, you MUST first run a
FULL-backlog classification scan (every open Backlog+Todo ticket → A-CLEAN / B-UI / C-REFACTOR /
D-BLOCKED — never a 6-ticket spot-check, per lessons.md 2026-06-04) and write the result to
`.claude/state/backlog-scan.json`:
```json
{ "timestamp": <unix>, "totalClassified": <N>, "aCleanCount": <M>, "topCandidates": ["BUT-XXXX", ...] }
```
The `loop-pace-guard.sh` hook reads this file: if `aCleanCount` is 0 (fresh, <30 min) it lets the
long wake through; if it's >0, don't pace down — resume on a real A-CLEAN candidate (including your
own follow-up tickets filed earlier this session) with `delaySeconds: 60`. A genuine external
blocker (watching CI settle, deploy cooldown, ops/Tier-D wait) is the only other way past the gate
and must be named in the wake `reason`.

### Acceptance criteria per ticket (write these at selection — they are the rubric)

For every selected ticket, write **2–4 gradeable acceptance criteria** derived from the ticket
text + the Step-0 code read — BEFORE implementation. A criterion is *gradeable* when a fresh
agent could verify it from the diff and tests alone, with a yes/no answer. This rubric is what
Phase 2.7 grades against; it lets the loop self-verify *outcomes* instead of only checking that
lint/tests are green (see `memory/feedback_self_verification_loops.md`). Structural gates prove
the code compiles and is covered; they don't prove it did what the ticket asked.

- **Gradeable** (good): "Toggling the setting then restarting persists the value", "No new file
  exceeds 500 lines", "The allergen filter excludes any recipe containing the flagged allergen",
  "Every enum case has an explicit branch (no default fall-through)".
- **Not gradeable** (bad): "Works correctly", "Looks good", "Handles edge cases" — a verifier
  can't score these, so they catch nothing.
- Pin the *intent* the ticket exists to satisfy, **plus any explicit "don't do X" constraint** —
  those negative constraints are the first thing lost to goal drift across a long run.
- Tier B (UI): criteria are the visual/behavioral checkpoints the human grades from the preview
  (the screenshot review IS the grading) — still write them so the In-Review comment is concrete.

### Write the plan to `tasks/todo.md`

```markdown
## Sprint: [name] — [date]

### Agent A: [agent-name] — [theme]
- [ ] **A1. [verb] [description]** `[Tier A]` — `file/path.dart`: [change]. (BUT-XXX)
  - Acceptance: [criterion 1] · [criterion 2] · [criterion 3]
- [ ] **A2. ...** `[Tier B]` (BUT-YYY)
  - Acceptance: [criterion 1] · [criterion 2]

### Agent B: [agent-name] — [theme]
- [ ] **B1. ...** `[Tier C]` (BUT-ZZZ)
  - Acceptance: [criterion 1] · [criterion 2] · [criterion 3]

### Needs you (Tier D — flagged, not worked)
- BUT-NNN — [one-line: what human/ops action unblocks it]

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests
- [ ] Commit, push, PR
- [ ] Update Linear ticket states (Done for Tier A; In Review + notify for Tier B/C)
```

Tag every task with its tier (`[Tier A/B/C]`). The tier drives Phase 1.6 handling and the
Phase 3 close-out (Done vs In Review).

Archive any prior sprint below a `---` separator.

**Linear state transition:** for each BUT-XXX in the new plan, transition state to "Todo" (resolve state UUIDs once via `list_issue_statuses`, then `save_issue` per ticket). Skip silently if Linear MCP unavailable.

**Do not pause for user approval of scope.** Per `feedback_solo_no_scope_gate.md`, the rubber-stamp "approve my picks" gate was deleted. Proceed straight to Phase 1.4. (Note: this is different from the per-ticket plan-mode gate in Phase 1.5 — that one fires on risky tickets specifically, not on the sprint as a whole. It's also different from `--pick` mode, where you choosing the ticket IS the point of the mode, not a rubber-stamp.)

## Phase 1.4 — Stakeholder review (experts always ON, default; `--no-review` to disable)

Butlery is now complex enough that the default posture is **careful**: the specialists who own a
ticket review it *before* it's built, every time, weighing tradeoffs. This phase is **on by
default**. It turns off ONLY when the user explicitly passes `--no-review` (or says "skip the
panel" / "no stakeholder review"). The point is that being careful is the baseline, not an
opt-in. (Mostly $0: a `/loop /sprint-execute` running inside Malin's own session is flat-rate
Max; the tier router keeps even a metered headless run proportional.)

For each selected ticket, using the `tier` + `panel` computed in Phase 1's routing:

1. **`skip` tier** → no review (trivial/doc-only). Proceed to implement.
2. **`single` tier** → dispatch ONE blind critique from the owning role, following the
   `/stakeholder-review` pipeline (step 2 prompt): the agent grounds itself in its dossier section
   of `docs/architecture/ROLE_RESPONSIBILITY_MAP.md` and critiques the ticket only from its stake.
   Give it the ticket text + the ticket's blast-radius files only (not free repo exploration).
3. **`full-panel` tier** → dispatch the full blind panel (path owners ∪ high-stakes core)
   **concurrently in one message**, each agent blind to the others. Same per-role prompt.

Use cheap/low-effort subagents (these are scoped critiques). Then **synthesize** (stakeholder-review
steps 3–4).

**Log the review (non-optional — retro finding 2026-07-04):** after synthesis, for `single` and
`full-panel` tiers, append a review event so /org-retro can compute value + rubber-stamp rate
(unlogged panels made the org's measurement blind in all three repos):
```
python docs/org/metrics/log_event.py '{"type":"review","tier":"single|full-panel","panel":["<roles>"],"plan":"BUT-XXXX","outcome":"approve|approve-with-conditions|escalated|object","must_haves":N,"conflicts":N,"escalations":N,"adrs":[],"rubber_stamp":false,"approx_tokens":T,"via":"sprint-execute"}'
```
(Canonical field names, pinned 2026-07-04 across all three repos — `must_haves` is a count;
`via` lets /org-retro exclude sprint-routed reviews from trigger calibration.)
Then apply the outcome:

- **Fold every `must_have` / condition into THIS ticket's acceptance criteria** (Phase 1) and into
  the implementation brief. After review, the conditions are *binding*, not advisory — the Phase 2.7
  verifier grades them too.
- **approve / approve-with-conditions, no conflict** → implement with the conditions baked in.
- **Unresolved high-stakes conflict** (a `block` from a high-stakes-core role, or anything
  legal/privacy/interpretive) → the loop CANNOT `AskUserQuestion` (it halts). So do **NOT** implement
  the contested scope. Park the ticket in **In Review** with the conflict written out (each role's
  stake), write the ADR (`docs/org/adr/`, per `/stakeholder-review` step 5), and **PushNotification**
  Malin that a high-stakes decision is waiting. Implement only the uncontested remainder, if any, then
  continue the loop. This is how "escalate-human" survives in a non-halting loop — it becomes a parked
  ticket + a notification instead of a live question. **Exception — `--pick` mode:** you're present,
  so escalate the conflict to you LIVE via `AskUserQuestion` (with each role's stake) instead of
  parking it. This is the one capability the old `/linear backlog` had that the autonomous loop lacks.
- **Log the review event** for `/org-retro` (the `log_event.py` call in stakeholder-review's "Logging"
  section) so the panel's value/rubber-stamp-rate is measurable.

If `--no-review` was passed, skip this phase entirely and note "stakeholder review disabled by
--no-review" in the final report so the lowered-caution run is visible.

## Phase 1.5 — Risk-gated plan mode (hybrid)

**Why:** the file-plan in `tasks/todo.md` is durable but easy to drift from mid-iter (iter-46 lesson — wrote plan then jumped scope). For genuinely risky tickets — cross-cutting bugs, security surface, base classes that propagate through inheritance — `EnterPlanMode`'s forcing function (blocks Edit/Write/Bash until approval) prevents the batched-footgun class of error (iter-73 lesson). Mechanical cleanup doesn't benefit from the halt; routing P3/P4 tech-debt through plan mode wastes the autonomous loop. This phase splits the difference.

### Per-ticket risk score (router-driven — one source of truth)

The Phase 1 router already classified each ticket's blast radius. **Use its tier as the risk
signal** — do not maintain a second hand-rolled formula (the two drifting apart was the original
bug). The mapping:

```
requires_plan_mode = (
  tier == "full-panel"                              # high-stakes path or broad blast radius
  OR (tier == "single" AND priority <= 2)           # Urgent/High on a stakeholder-owned area
  OR (tier == "single" AND labels contains 'security')
)
# tier == "skip", or low-priority mechanical single-owner work → false
```

This keeps the plan-expansion gate, the always-on stakeholder panel (Phase 1.4), and
`/stakeholder-review` all reading the same `tools/stakeholder_router.py` + `docs/org/role-paths.json`.

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

## Phase 1.6 — Per-tier handling (the "keep going as autonomously as possible" engine)

This is what makes the loop able to take on UI and large refactors without stopping for
approval. The principle: **everything ships to main** (nothing is lost, CI runs, work
accumulates), but tickets whose correctness only a human can confirm park in **In Review**
with a notification instead of auto-closing to **Done**. The loop continues to the next
ticket regardless. Never call `EnterPlanMode` or `AskUserQuestion` mid-loop — both halt.

### Tier A — Full-auto (unchanged from the original loop)
Implement → verify → commit → push → close **Done**. This is the existing Phase 2/3 path.

### Tier B — UI-visual
1. **Design from what already exists.** Read the UI/UX preferences in memory (square design
   language, color tokens, bottom-nav behavior, etc.), the relevant mockup PNGs in
   `docs/design/mockups/`, and `_butlery-components.html`. Compose from existing components
   before inventing new ones. Follow `.claude/rules/html-previews.md` and `lib/widgets/CLAUDE.md`.
2. **Do NOT `AskUserQuestion` for design choices mid-loop** — it halts. Pick the option that
   best matches the mockups + memory prefs, build it, and let the user react to the preview
   async. Only when a choice is genuinely 50/50 AND consequential, note both options in the
   In-Review comment so they can redirect — still don't halt.
3. **Implement** the view/widget following MVVM + the design system.
4. **Preview + self-verify.** Generate an HTML preview in `docs/design/previews/` from
   `_butlery-template.html`; screenshot it via Chrome MCP at 375×812 (and a tablet width if the
   ticket is responsive). If Chrome MCP is unavailable in a headless loop, save the HTML and
   reference its path. Exhaustively self-review against the mockup per `.claude/rules/ui-conventions.md`
   (search accents, icon colors, spacing, radius, opacity, typography weight — list any deltas).
5. **Ship + park for review.** Commit + push to main (Phase 3), then set the ticket to
   **In Review** (state `9929b3b0-b74f-44b8-bf34-ad2e2e78af7c`), NOT Done. `save_comment` with:
   what changed, the preview/screenshot path (attach the image to Linear if possible), any
   design deltas vs mockup, and any 50/50 choice you made. Then **PushNotification** with a
   one-line "BUT-XXX UI ready for your eyes" + the screenshot path so the user can review on
   their phone. Continue to the next ticket.

### Tier C — Large/risky refactor
1. Run the Phase 1.5 expanded plan (Step 0 classification, files, blast radius, rollback) —
   it always fires for Tier C. Echo the risky-ticket plan block in chat.
2. Implement incrementally; prefer the smallest correct diff. For codemods with two divergent
   targets (e.g. BUT-581's two `orEmpty` forms), reconcile to one canonical form FIRST, in its
   own commit, before the sweep.
3. **Heavier verification:** run the full relevant test suite (not just changed-file analyze),
   and diff behavior vs main where feasible. For base-class changes, grep + spot-check every
   subclass/caller.
4. **Ship + park for review.** Commit + push to main, then set **In Review** + `save_comment`
   with the blast-radius summary and what to spot-check, + a PushNotification. Auto-close to
   **Done** ONLY when the change is fully mechanical and test-proven (e.g. a pure rename with
   green tests and zero behavioral surface) — when in doubt, In Review.

### Tier D — Ops-blocked
Do NOT attempt. `save_comment` on the ticket enumerating the exact human/ops steps that unblock
it (what to capture/configure/deploy, where). Leave its state untouched. List it under "Needs
you" in the final report. This documents the blocker instead of silently skipping — so the
backlog reads honestly and you know what's actually waiting on you.

### Tier B/C state UUIDs (resolve once, cache for session)
- **In Review** = `9929b3b0-b74f-44b8-bf34-ad2e2e78af7c`
- **Done** = resolve via `list_issue_statuses` (Tier A close-out, Phase 3 step 5).

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

### Deviation log (append-as-you-go — the thing scrollback loses)

During a long run, the moments where reality diverged from the plan are the highest-value
learning signal, and they're exactly what evaporates into scrollback across compactions. Keep a
running log in `tasks/todo.md` under a `## Deviation log` heading (below the task list, above the
`---` archive separator). Append one line the instant any of these happens — don't batch, don't
rely on memory:

- **deviation** — the plan said X, the code turned out to be Y. State the **conservative choice
  you made** and flag `[revisit]` if it's worth a second look. (Per Phase 2 Step-0: current code
  wins over ticket text — this logs *when* that rule fired and what you did about it.)
- **discovery** — something true and worth knowing surfaced (a dead capability, a hidden coupling)
  that didn't change your plan but the next run should know.
- **needs-malin** — a product/intent/legal judgment beyond the loop's authority (don't halt; log
  it, park the ticket per Phase 1.6, keep going).

Format: `- [deviation|discovery|needs-malin] BUT-XXX: <plan said> → <what I found> → <conservative choice / flag>`.
Keep the conservative option; never expand scope to "fix" a surprise mid-run — that's what the
`[revisit]` flag and a follow-up ticket are for. This log is read back in Phase 3's fold-back
step and feeds the lessons/knowledge loop; a recurring deviation is a rule waiting to be written.

## Phase 2.7 — Outcome verification (grade against the acceptance criteria)

**Why:** `dart analyze` + tests + reviewer markers verify *process* — that the code compiles, is
covered, and follows conventions. They do **not** verify the change actually did what the ticket
asked. A long autonomous run is exactly where this gap bites (agentic laziness: "20 of 50 items
done, declared complete"; goal drift losing a "don't do X" constraint after compaction). This
phase closes it with an independent grader. See `memory/feedback_self_verification_loops.md`.

For each implemented ticket (status `[x]`), dispatch a **fresh-context verifier subagent** — NOT
the agent that wrote the code (self-preferential bias makes self-grading near-worthless). Give it
ONLY: the ticket's **Acceptance** criteria, the diff scoped to that ticket's files
(`git diff -- <files>`), and the relevant tests. It returns, per criterion, **pass / fail /
unclear** + a one-line reason, and an overall verdict. Batch it: one verifier per `### Agent`
group is fine (it sees that batch's tickets + diff). This grader checks *intent satisfaction*,
not code quality — keep the bug-hunting reviewers in Phase 3 step 3 separate; a cheaper capable
model is fine here.

Handle the verdict:
- **All criteria pass** → proceed to Phase 3 normally (Tier A → Done, Tier B/C → In Review).
- **Any criterion fails** → fix inline if scoped, then re-grade. If it's genuine deferred scope,
  file a follow-up ticket AND **downgrade the close-out**: a Tier A ticket with a failing
  criterion does NOT close Done — move it to In Review with the failing criterion in the comment,
  so it gets human eyes instead of a false "done".
- **Unclear** → treat as a Tier B/C signal: park in In Review with the open question; don't
  auto-close Done on a criterion the grader couldn't confirm.

Carry the per-criterion grade into the Phase 3 close-out comment (the Tier A Done comment, or the
Tier B/C In-Review comment) — it's the concrete evidence the ticket did what it claimed.

## Phase 3 — Post-sprint (MANDATORY — sprint is not done until every step here completes)

**Failure mode being prevented:** prior sprints have ended with uncommitted changes and Linear tickets still in "In Progress." Phase 3 is non-optional. If you reach the end of Phase 2 and skip Phase 3, you have not finished the sprint.

After all tasks processed (or remaining tasks blocked):

1. **Full analyze** — `dart analyze --fatal-infos`. Fix anything fatal before continuing.

2. **File follow-ups as Linear tickets — MANDATORY before commit.** See "Follow-up rule" below. `tasks/todo.md` is overwritten by the next sprint, so any deferred work captured only there is silently lost. Linear is the durable backlog.

3. **Commit (inline, not delegated).** `/commit` is a slash command — invoking it from inside this command is a prose instruction, not an auto-execution. Run the commit workflow yourself, here, in this session:
   - `git status` and `git diff --staged` (stage with `git add` if needed).
   - Run `code-reviewer` agent on staged `.dart` files; fix Critical/High before proceeding.
   - Run `testing-specialist` agent on staged `lib/**/*.dart` files; fix failing tests before proceeding.
   - Write a conventional commit message (`feat:` / `fix:` / `refactor:` / etc.) with body explaining *why* + key changes + the "Known follow-ups (filed in Linear)" section listing the BUT-XXX tickets created in step 2. Footer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
   - `git commit`. If lefthook reformats and the commit fails, re-stage and commit again — never `--amend`, never `--no-verify`.
   - **Verification gate:** after commit, `git status` MUST show a clean working tree for tracked files. If it doesn't, the commit didn't capture everything — repeat step 3 until clean.

4. **Push** — `git push -u origin HEAD`.

5. **Transition Linear tickets by tier (inline, mandatory).** Do not assume `/commit` handled this. For each BUT-XXX in the just-pushed commit whose todo.md task is checked `[x]`, route by its tier tag:
   - **Tier A** → resolve "Done" UUID once via `list_issue_statuses`; `save_issue` stateId Done; `save_comment`: "Fixed in commit `<short hash>`. Changes: <subject>". Report "Closed BUT-XXX (Done)".
   - **Tier B / Tier C** → `save_issue` stateId **In Review** (`9929b3b0-b74f-44b8-bf34-ad2e2e78af7c`); `save_comment` per Phase 1.6 (preview/screenshot path or blast-radius + what to spot-check); **PushNotification** with the one-liner + artifact path. Report "BUT-XXX → In Review (awaiting your eyes)". (Exception: a fully-mechanical, test-proven Tier C may go straight to Done — Phase 1.6 Tier C step 4.)
   - Tickets marked `[~]` (obsolete via Step 0): close with comment "Obsolete — already resolved by `<commit-sha>`".
   - Tickets marked `[!]` (failed): leave open, transition back to "Todo", post a comment with the failure reason.
   - **Tier D** (flagged, never coded): leave state untouched; ensure the enumerated-blocker comment from Phase 1.6 was posted.
   - Skip silently only if Linear MCP is genuinely disconnected — and report that fact in the final summary so the user knows to transition manually.

6. **CI watcher** — Monitor: `bash .claude/hooks/monitors/ci-watcher.sh $(git rev-parse HEAD)` (persistent: false, timeout_ms: 900000). Continue without waiting; include CI status in final report when results arrive.

6.5. **Fold back the deviation log (MANDATORY when the log has entries).** Read the `## Deviation
   log` section written during Phase 2. For each entry decide its destination — this is how a
   one-off surprise becomes durable knowledge instead of being overwritten by the next sprint:
   - A `[revisit]` deviation with lasting product impact → **file a follow-up Linear ticket** (step 2 already ran, so add it).
   - A recurring or workflow-level deviation (a rule I'd want to hold next time) → **append a `tasks/lessons.md` entry + its `.claude/rules/lessons-digest.md` one-liner** (CLAUDE.md rule #9).
   - A domain pattern an agent should remember → note it for that agent's `.knowledge.md`.
   - A pure discovery with no action → let it archive with the sprint; no destination needed.
   Summarize the fold-back in the final report ("3 deviations: 1 ticketed, 1 → lessons, 1 archived").
   An empty deviation log is fine — say "no deviations logged" and move on.

7. **PR (only if a PR is wanted)** — solo direct-to-main is the default per `CLAUDE.local.md`; skip `gh pr create` unless the sprint touched something risky enough to warrant review.

8. **Final report — must include explicit confirmation of every gate:**
   ```
   Sprint complete.
   - Tasks: X/Y done, Z blocked, W obsoleted
   - Outcome grade: BUT-XXX 3/3 pass · BUT-YYY 2/3 (1 fail → In Review) · BUT-ZZZ 2/2 pass
   - Commit: <short-sha> "<subject>"
   - Pushed: yes/no
   - Closed Done (Tier A): BUT-XXX, BUT-YYY
   - In Review — your eyes (Tier B/C): BUT-PPP (UI, screenshot: <path>), BUT-QQQ (refactor, spot-check: <what>)
   - Needs you (Tier D — not worked): BUT-RRR — <human/ops action required>
   - Left open: BUT-ZZZ (failed — see comment)
   - Follow-ups filed: BUT-AAA, BUT-BBB
   - CI: pending / green / red
   ```
   If any line of that report is "skipped" or "n/a" without a real reason, you have not finished the sprint — go back and complete it. The "In Review" and "Needs you" lines are how the user stays in the loop without blocking it — never omit them when tickets land in those buckets.

   **Write for a non-coder who wasn't watching.** Malin reads every report, Linear comment, and
   push notification herself, and she doesn't read code. After the structured block above, add a
   short plain-language paragraph per shipped ticket: what changed *in the app* and *why* it was
   done — "recipes you cooked today now show a chip on the card, so you can see at a glance what's
   already been made" beats "added isCookedToday to RecipeCardViewModel". No arrow chains, no
   session shorthand, no invented labels; gloss any unavoidable technical term in product terms the
   first time. Same register as the mandatory "What this means in plain language" plan section.
   This applies to ALL human-facing text the sprint produces: the final report, every In-Review
   `save_comment` (the "what to spot-check" must be checkable by looking at the app, not the diff),
   and every PushNotification one-liner.

## Phase 3.6 — Malin decision queue (ONLY when `malin` passed)

`malin` is one mode, not an add-on: it runs the **full** autonomous sprint (Phases 1–3) first —
building, verifying, shipping, and closing everything it can on its own, exactly as a normal run —
and only **then**, here, collects everything still needing Malin into **one group** and walks her
through it. The building is done before this phase starts; this phase itself builds no blocked
scope — it **gathers, prepares, and asks** as a single batch. Skip this entire phase unless
`$ARGUMENTS` contains `malin` / `--malin`.

### 1. Assemble the queue (three sources, deduped)

- **`need-malin` lane** — `list_issues` with `team: "Butlery"` filtered to the label
  `need-malin` (the standing backlog of decisions/ops that are hers — see
  `memory/project_linear_lane_labels.md`). This is the primary source and exists independent
  of this sprint.
- **Tier-D blockers hit this run** — the ops-blocked tickets flagged under "Needs you" in
  Phase 1.6 / the Phase 3 report.
- **High-stakes parked items** — any ticket Phase 1.4 parked in **In Review** because a
  stakeholder raised an unresolved legal/privacy/interpretive conflict this run.

Dedup by BUT-XXX. Cap the live queue at the **top ~6 by stakes/priority** (Urgent/High,
legal/privacy, launch-blockers first); note any overflow in the final report so it isn't lost.

### 2. Prepare each into a decision brief (cheap prep only — this is read/research, NOT building)

For every queued item, do the inexpensive work that turns a vague "needs Malin" into a fast
yes/no or pick-one. **This is allowed even though the item is need-malin** — reading code,
reading the dossier, and researching an external unknown are not "building the blocked scope":

- **Read** the code/spec/ticket the decision touches so the options are grounded in reality.
- **Research the unknown** if it's external (a law, an App-Store rule, a vendor capability, a
  price) — use Context7 / web search rather than guessing; her training data and yours both age.
- **Frame it** as one of two shapes:
  - **A decision that's hers** (product/UX/legal call) → 2–3 concrete options, each with *what
    she'd notice in the app* and the tradeoff, **in plain language, zero jargon**; mark a
    recommendation (first option) and state what she risks either way.
  - **An ops action only she can do** (deploy, store/Apple enrollment, secrets, billing-enable)
    → it's not a decision, it's a to-do: state the exact single step and what it unblocks.

Build **nothing** that depends on her answer before she gives it. The mode prepares and asks; it
does not pre-decide.

### 3. Present it as ONE group, then ask her live (she's present)

Lay the whole prepared queue out as a **single grouped summary first** — split into **Godkänna**
(decisions/approvals that are hers) and **Göra** (ops to-dos only she can do) — so she sees the
full pile at once instead of drip-fed. Then walk her through it via `AskUserQuestion`, batched
(≤4 options-questions per call; decisions before to-dos, highest-stakes first). For each answer,
act **within this session**:

- **She picks an option / says go** → if that unblocks autonomous work, either build it now (if
  small and clearly in-scope) or file/keep the Linear ticket and **re-lane it to `autonomous`**
  (`save_issue.labels` REPLACES the set — pass `existing-labels − need-malin + autonomous`). Then
  it flows through a future `/sprint-execute` normally.
- **Legal / privacy / interpretive answer** → record it as an ADR (`docs/org/adr/`) and update
  the ticket body; build only what she explicitly authorized, no further.
- **Ops to-do** → leave the ticket for her, confirm the exact step in the ticket comment.
- **She defers** → leave it in `need-malin`, note her reason on the ticket.

### 4. If somehow NOT interactive (headless / inside `/loop`)

`AskUserQuestion` halts an unattended loop, so don't call it. Instead write the full prepared
queue into the final report and fire **one** `PushNotification` ("N decisions ready for you"),
then end. The live-ask is the interactive-only half; the prep half runs either way.

### 5. Report

Add to the Phase 3 final report a line:
`Decisions: cleared X (BUT-… re-laned autonomous), still open Y (BUT-…), ops to-dos Z (BUT-…)`.
Keep every brief in plain language — Malin reads these herself and does not read code.

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
- Does not auto-start the next sprint (Malin re-runs `/sprint-execute`, or the `/loop` re-fires it).
- Does not halt for approval — UI (Tier B) and large refactors (Tier C) ship to main and park in
  **In Review** with a push notification for async sign-off, rather than blocking the loop.
- Does not attempt Tier D (ops-blocked) work — it documents the blocker on the ticket and flags
  it under "Needs you" instead.

## Autonomy policy (why tiers exist)

Malin asked (2026-05-30) to keep the loop going as autonomously as possible across ALL work,
not just the clean code-only slice. The tier system is the mechanism: it lets the loop take on
UI and large refactors continuously while still giving Malin a real review checkpoint (the
In-Review state + notification) on the things only a human should sign off on — without ever
stopping the loop to wait. See `memory/feedback_autonomy_tiers.md`. The genuinely-clean Tier A
backlog was largely drained by iter-103→105; Tier B/C is where the volume is now.

## Relationship to /linear

- `/linear scan` — find NEW issues in code, create tickets (stamps the owning stakeholder on each).
- `/linear clean` / `/linear status` — backlog hygiene + dashboard.
- `/sprint-execute` — pick a batch AND implement in one pass (this command).
- `/sprint-execute --pick` — interactive single/few-ticket build. **This replaces `/linear backlog`**
  (removed 2026-06-27): same browse-and-pick, but with the full review/verify/close ceremony and
  live high-stakes escalation.
- `/sprint-execute malin` — normal autonomous sprint PLUS a prepared decision-queue at the end
  (Phase 3.6): everything waiting on Malin (need-malin lane + Tier-D blockers + parked high-stakes),
  researched into ready-to-decide briefs and asked live. Composes with `N` / `--focus` / `--no-review`.

`/triage` was removed (2026-05-03) and `/linear backlog` folded into `--pick` (2026-06-27). Their
prioritization/selection logic now lives in Phase 1 above.
