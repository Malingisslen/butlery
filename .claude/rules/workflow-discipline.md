# Workflow Discipline

## Plan Mode (automatic for complex tasks)
- **Always plan before a large change — no exceptions.** A change is "large" if it hits ANY of: **2+ production files** (code under `lib/` or `functions/src/` — tests, generated files `*.g.dart`/`*.freezed.dart`/`lib/l10n/`, docs, and config do NOT count, so a fix + its test ships without ceremony), a new service / viewmodel / repository, an architectural or base-class change, a "refactor" / "migrate" request, a multi-file codemod, or a sensitive domain (Firestore data/rules, auth, Cloud Functions, GDPR / user data). Large changes ALWAYS get a written plan + approval before any Edit/Write — this holds in ad-hoc chat, not just `/sprint-execute` (it's the conversational equivalent of the sprint's Tier C). Small, obvious, single-production-file fixes ship without ceremony — don't gold-plate (CLAUDE.md rule #7). **Mechanically enforced (2026-07-03):** `plan-threshold-guard.sh` (PreToolUse Edit|Write) blocks the 2nd distinct production-file edit in a session unless plan evidence exists — the plan-review gate passed (it stamps `plan-approved-<session>.marker`) or `tasks/todo.md` was written in the last 6h. `SKIP_PLAN_GUARD=1` only for deliberate mechanical codemods, and say so in the summary. Do NOT dodge the gate by splitting into single-file edits.
- **Interview is part of every plan (MANDATORY, gate-enforced).** Before finalizing a plan, surface the open questions **ranked by blast radius** (an answer that changes the architecture outranks one that changes a detail) and ASK them via AskUserQuestion; fold the answers into the plan under an "## Open questions" section. If there are genuinely none, the section instead states "No architecture-changing unknowns" plus the assumptions being proceeded on. `plan-review-gate.sh` refuses to let ExitPlanMode through without this section — silent assumptions don't pass the gate.
- Enter plan mode automatically (no user action needed)
- Write plan to `/tasks/todo.md`, get approval, then implement
- Task state persists on disk - PreCompact hook reads both Claude Code tasks and `/tasks/todo.md`
- If going sideways → STOP and re-plan immediately
- Before presenting plans, review against `.claude/plan-review-checklist.md`
- **Plain-language summary (MANDATORY):** Every plan MUST end with a section called "## What this means in plain language" that:
  - Explains what the user will notice changing (new button, different behavior, etc.)
  - Uses zero technical jargon — no "viewmodel", "repository", "mixin", "provider", "widget tree"
  - Summarizes the risk: what could break, and how easy it is to undo
  - Is max 5-8 bullet points, written as if explaining to a friend who doesn't code

## Cast stakeholders BEFORE planning (ad-hoc work, not just sprints)
The role-org must be cast into planning the same way `/sprint-execute` Phase 1 + 1.4 does it — not only inside the sprint command. For any **large change** (above) OR any request touching a **sensitive domain** (user/children's data + GDPR, money/monetization, security/auth, Firestore rules, app-store/release compliance, legal), BEFORE writing the plan:
1. **Cast the panel.** Resolve the likely-touched paths and run the router: `python tools/stakeholder_router.py --json <paths>`. It returns the tier (`skip` / `single` / `full-panel`) and the owning role(s) + high-stakes core. Deterministic, cheap, no agents — this is what makes "experts always on" affordable (depth is bounded by blast radius).
2. **Convene the cast roles (Phase 1.4 style).** `single` → one blind critique from the owning role; `full-panel` → the full panel concurrently, each grounded in its dossier section of `docs/architecture/ROLE_RESPONSIBILITY_MAP.md`, blind to the others. Run these critiques on `sonnet` at low effort (scoped reads); keep the commit-gate reviewers on `opus`.
3. **Fold their conditions into the plan** as binding items (they become acceptance criteria, not advisory notes), then present the plan. An unresolved high-stakes conflict — a `block` from a high-stakes-core role, or anything legal/privacy/interpretive — gets surfaced to Malin *in* the plan, never buried.

`skip` tier (doc-only / trivial) → no panel, plan normally. This closes the only gap: the diff-review half of cast→plan→review already runs via the commit-gate specialists; this adds the cast + plan halves to direct requests.

## Before building a new automation — the four-box test
Loop/hook/agent machinery earns its keep only under specific conditions. Before proposing or
building ANY new automation (a hook, a scheduled routine, a self-running loop, an agent), check
all four boxes — miss one and it stays a **manual tool**, honestly labeled as such, not
infrastructure:
1. **Repeats ≥ weekly.** Below that, the setup + maintenance cost never amortizes; one good prompt wins.
2. **Something can auto-reject bad output.** A test, gate, type-check, or hard rule fails the work without a human. No gate → the loop just spins and bills (the "Ralph Wiggum" failure: it declares done on a half-finished job and keeps running).
3. **Doable end-to-end without handing a half-finished piece back.** If it stalls waiting for a human mid-run, it's a manual step wearing a loop costume.
4. **"Done" is objective, not taste.** If quality is a judgment call (visual polish, product intent), a human still signs off — automate the *detection*, not the *decision*.

This pairs with the mechanical-trigger rule (lessons-digest): an automation that passes the
four boxes still needs a named firing path (hook / schedule / gate), or it rots unread. Cost
note (CLAUDE.md Cost Principles): prefer deterministic code over an LLM call inside any loop —
a git-log diff beats an agent for "what changed," a regex beats a classifier for known shapes.

## Fit Check (when 2+ approaches exist)
- Requirements as rows, approaches as columns
- Cells are strictly pass (Y) or fail (N) — no "maybe"
- Include ALL requirements, even ones that seem obvious
- Pick the approach with fewest fails; ties broken by simplicity

## Verification Before Done
- `flutter analyze` passes
- Relevant tests pass
- Diff behavior vs main if relevant
- Ask: "Would a staff engineer approve this — including approving 'I'm stuck' as an honest answer?"
- For layout/UI bugs: test the fix in Chrome before declaring done
- If first fix fails: STOP guessing. Find 3 similar working views, compare their layout pattern to the broken view, then fix based on the working pattern.

## Demand Diagnosis (Balanced)
- For non-trivial changes, before presenting: ask "is there a more elegant way to do this?"
- If a fix feels hacky, redo it: "Knowing everything I know now, implement the clean solution from scratch."
- **Balance clause (do not skip):** for simple, obvious, or one-line fixes, ship it — don't gold-plate. This rule serves quality on substantial work; on trivial work it would just fight rule #7 (don't over-estimate complexity) and "minimal impact".
- Trigger: applies when a change touches 3+ files, adds a service/viewmodel, or the first working version felt like a workaround. Skip otherwise.

## Self-Improvement Loop (automatic)
- After ANY user correction → add entry to `/tasks/lessons.md`
- Format: `### [Category] Title` + Date, Trigger, Rule, Example
- Categories: Architecture, Code Quality, Testing, Workflow, Firebase, UI/UX
- If lesson should become CLAUDE.md rule → propose update

## Memory Management
- Auto-memory is enabled — Claude manages MEMORY.md and topic files automatically
- `current-state.md` is managed by the PreCompact hook — do not overwrite it with auto-memory
- **Hooks** (fully automatic, no manual trigger):
  - PreCompact → captures git state + tasks → `current-state.md`
  - SessionStart (compact) → injects checkpoint as context after compaction
  - `/interview` → persists answers to `interview-decisions.md`

## Autonomous Problem Solving
- Bug report → just fix it (spawn debugger agent)
- Failing CI → go fix without being told how
- Point at logs/errors → resolve them
- Don't ask for hand-holding on standard debugging
- If stuck after multiple attempts: write a diagnostic summary of what was tried and why it failed, then ask for direction

## Parallel Agent Tasks
- Process files in small chunks (50-100 items), never entire large files at once
- Define explicit chunk boundaries before launching agents
- Each agent must checkpoint progress and report completion status
- When using parallel task agents for large plans, verify that agents are not overwriting each other's changes
- If the plan has 10+ items, process them sequentially or in small batches of 2-3 to avoid conflicts
