---
name: stakeholder-review
description: Phase-2 deliberation. Given a plan, a changed fileset, or a ticket, route it to the role-org stakeholders by blast radius, run PARALLEL BLIND critiques (each role from its own dossier stake + world-model, none seeing the others), synthesize one recommendation, break ties via the hybrid rule (escalate unresolved high-stakes to Malin; else CTO priority order), and record any disagreement as a dated ADR. Advisory only — never auto-merges or auto-acts. Interactive and $0 on Max.
---

# /stakeholder-review — multi-stakeholder review for the role-org

Turns the 28 static role dossiers into a working review panel. Built to the
constitution in `docs/architecture/ROLE_ORG_DESIGN.md` (read its "Phase 2" section
and the priority-order rubric before running). **Advisory only: it produces a
recommendation; Malin decides whether to proceed. It never edits app code, merges,
or acts.** $0/interactive — never headless.

## Input (`$ARGUMENTS`)

One of:
- **A plan** — a path to a plan file (e.g. `tasks/todo.md` or `~/.claude/plans/butlery-*.md`)
  or pasted plan text. Plans always route to `full-panel`.
- **A fileset** — explicit paths, or a git range (e.g. `HEAD~1..HEAD`, `main...`). Resolve to a
  file list with `git diff --name-only`.
- **A ticket** — a Linear ID (e.g. `BUT-1315`); fetch it, treat its description as the plan and its
  likely-touched paths as the fileset.

If unclear, ask which. If nothing is given, default to the working-tree diff (`git diff --name-only`).

## The pipeline

### 1. Route
Run the router to pick stakeholders + tier:
```
python tools/stakeholder_router.py --json <paths...>      # fileset
python tools/stakeholder_router.py --json --plan <paths>  # a plan
git diff --name-only main... | python tools/stakeholder_router.py --json --stdin
```
It returns `{tier, panel, high_stakes_hits, core_added, trivial_skipped, matched}`.

- `tier == "skip"` → say "trivial/doc-only — no stakeholder review needed" and stop.
- `tier == "single"` → run ONE critique (the owning role). If it returns `approve`, report and stop
  (no ADR). If it `block`s or attaches must-haves, treat it like a one-role panel: synthesize +
  (if it's a high-stakes block) escalate, and write an ADR.
- `tier == "full-panel"` → run the full panel below.

Tell the user the tier + who's seated (and that the high-stakes core was seated) before spending tokens.

### 2. Parallel blind critique  (the core — do NOT skip the blindness)
Dispatch the seated roles **concurrently, in one message** (multiple Agent calls), so no critique
sees another. Give each agent ONLY: its role name, the plan/diff, and an instruction to ground itself
in its own dossier. Use this prompt per role:

> You are the **{ROLE}** for Butlery (a Flutter/Firebase recipe & pantry app). Read your dossier:
> find your role's section in `docs/architecture/ROLE_RESPONSIBILITY_MAP.md` (heading `## N. {ROLE}`) —
> your **Mandate**, **Watch items**, **Evidence** paths, and your **🌍 World-watch** block (the
> external signals/sources you track). Critique the following plan/change **only from your stake and
> your world-model** — not as a generalist. Be specific to Butlery's code where you can. Do not try to
> represent other roles.
>
> PLAN/CHANGE:
> {plan text or `git diff` summary + file list}
>
> Return JSON only:
> `{"role","position":"approve|approve-with-conditions|block","top_risks":[...],"must_haves":[...],"world_model_flag":"<any law/policy/CVE/cost-trend angle, or empty>","cost_effort_note":"<short>","one_line_stance":"<one sentence>"}`

Use a cheap/low-effort subagent per role (these are scoped critiques). Collect all JSON results.
If a role returns nothing, note it and continue — don't block the panel on one dead agent.

### 3. Synthesize
You (the main loop) or one synthesizer agent reconciles ALL critiques into one recommendation:
- **Agreements** — what every seated role is fine with.
- **Conditions** — the union of `must_haves` (dedup) that should ride along if Butlery proceeds.
- **Conflicts** — genuine disagreements: `{roles, positions, high_stakes: bool, summary}`. A conflict
  is high-stakes if it involves a `block` from a high-stakes-core role (Security, Privacy/GDPR, Legal,
  Software Architect, Product Manager, FinOps) or touches user-safety / legal-privacy / data-integrity.
- **Overall:** `proceed | proceed-with-conditions | revise | block | escalate`.

### 4. Hybrid tiebreak  (per conflict)
- **Unresolved high-stakes conflict** → escalate to Malin with `AskUserQuestion`: state the tradeoff
  in one line, then give the options, and in the body lay out **each role's stake**. Do not decide it
  yourself. (Anything legal/privacy that's interpretive → always escalate.)
- **Any other conflict** → the **Chief-Architect (CTO)** decides by the priority order in DESIGN.md
  (user-safety > legal/privacy > data-integrity&security > correctness > cost > velocity > aesthetics).
  State which level decided it and why. You may act as the CTO agent for this step.

### 5. Record ADRs
For **every** conflict (resolved by CTO or escalated to Malin), append a new
`docs/org/adr/ADR-NNNN-<slug>.md` (next number; see `docs/org/adr/README.md` for the format) and add
its one-line entry to the ADR index. No conflict → no ADR (clean unanimous approval needs none).
Resolved-by-Malin ADRs record her choice once she answers.

### 6. Report (advisory)
Output: tier + panel, the one-line recommendation, the conditions to carry, each conflict + how it was
resolved, and links to any ADR(s) and escalation. End by reminding that this is advice — Malin decides
whether to proceed. **Never** edit code, commit the reviewed change, or mark anything done.

## Cost discipline
- Skip/single tiers cost ~0–1 agents. Full-panel is bounded (~6–11 agents, one round, no chat).
- One critique round only. Do not loop or re-debate. If the panel just agrees, say so plainly —
  cheap unanimous approval is a valid, useful outcome (and a signal the auto-trigger may not be worth it).
- The blindness + single-round design is the cost/quality lever; don't turn it into a conversation.
