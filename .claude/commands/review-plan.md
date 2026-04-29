---
description: Fresh-context plan audit — dispatches an agent that reads project rules cold, then audits tasks/todo.md against plan-review-checklist.md
argument-hint: [optional: path to plan file, defaults to tasks/todo.md]
model: opus
---

Dispatch a fresh-context auditor against the current plan. The point is that the auditor reads the rule surface area COLD — without the context that wrote the plan — so it catches drift the in-context self-review misses (especially design-system and rule-already-documented violations from `tasks/lessons.md` and `memory/feedback_*.md`).

## Usage

- `/review-plan` → audits `tasks/todo.md`
- `/review-plan path/to/plan.md` → audits a specific plan file

## What you do

Spawn a `general-purpose` Agent (NOT a specialist — you want one that reads everything fresh, not one biased toward its niche). Pass it the prompt below verbatim, with `$1` resolved to the plan path (default `tasks/todo.md`).

Wait for the agent to return. Show its scorecard to the user. If anything is RED, address it before the user calls `ExitPlanMode` again. If only YELLOW, surface the findings and let the user decide.

## Agent prompt (pass this to the dispatched agent)

> You are a fresh-context plan auditor for the Butlery project. You have NOT seen the conversation that produced this plan. That is the point — your job is to read the project's rules cold and check whether the plan obeys them.
>
> **Step 1 — Read the rule surface area, in this order, before looking at the plan:**
> 1. `CLAUDE.md` (project root) — critical rules + conventions
> 2. `CLAUDE.local.md` — solo-dev workflow rules (no PR ceremony, push to main, etc.)
> 3. `.claude/rules/code-style.md`
> 4. `.claude/rules/git-workflow.md`
> 5. `.claude/rules/workflow-discipline.md`
> 6. `.claude/rules/ui-conventions.md` (if it exists)
> 7. `.claude/plan-review-checklist.md` — the rubric you'll audit against
> 8. `tasks/lessons.md` — recent corrections, especially the most recent
> 9. `lib/widgets/CLAUDE.md` if the plan touches UI (square-corner rule lives here)
> 10. `C:/Users/malla/.claude/projects/C--Butlery-butlery/memory/MEMORY.md` — index of feedback memories. Open any `feedback_*.md` whose topic matches the plan domain.
>
> **Step 2 — Read the plan: `$1`**
>
> **Step 3 — Memory cross-check (preflight, BEFORE the checklist audit).**
>
> The in-context agent that wrote this plan may not have re-read MEMORY.md / interview-decisions.md / feedback memories. Your job is to catch contradictions with already-decided constraints. Specifically check the plan against:
>
> - `C:/Users/malla/.claude/projects/C--Butlery-butlery/memory/MEMORY.md` — pull anything in "Beta UX Decisions" or "UI/UX Design Preferences" that touches the plan's domain
> - `C:/Users/malla/.claude/projects/C--Butlery-butlery/memory/interview-decisions.md` — prior decisions that should not be re-litigated
> - Any `feedback_*.md` whose name matches the plan's domain
>
> Common contradictions worth catching (examples — not exhaustive):
> - Plan proposes a "discovery" or social-network surface → memory says "Not a social network" (delete discovery dashboard)
> - Plan proposes monetization mechanics → memory says "No monetization decisions yet"
> - Plan proposes personal-tag-based favorites → memory says "Favorites = boolean isFavorite, NOT personal tags"
> - Plan proposes step-by-step cooking cards → memory says "Cooking mode = landscape split-view, NOT step-by-step cards"
> - Plan proposes biometric/app lock implementation → memory says "Biometric/App lock = delete backend code entirely"
> - Plan proposes new collection concept → memory says "Collections = enhance personal tags to be shareable, NOT new concept"
> - Plan proposes social-login implementation → memory says "Social login = post-beta"
> - Plan proposes rounded corners on badges/buttons/cards → memory says "SQUARE everywhere — no rounded edges"
> - Plan proposes branch+PR ceremony → memory says "Solo workflow: push direct to main, never ask"
>
> Output this BEFORE the scorecard:
>
> ```
> ## Memory cross-check
> - ✅ No conflicts with prior decisions, OR
> - ⚠️ Conflicts found: [list each conflict with: what plan says vs what memory says, with file:section citation]
> ```
>
> If conflicts are found, they are 🔴 RED automatically — prior decisions take precedence over a fresh plan unless the plan explicitly justifies overriding them.
>
> **Step 4 — Audit the plan section by section against `plan-review-checklist.md`.**
> For each of its 11 sections, output one of:
> - 🟢 GREEN — section is satisfied, or genuinely N/A (say which)
> - 🟡 YELLOW — partial / uncertain / needs verification before proceeding
> - 🔴 RED — clear violation of a documented rule. Cite the rule (file + line/section).
>
> **Critical:** RED findings must cite WHICH rule is violated, by file path. "This feels off" is not RED. "Plan creates a new repository without `PermissionValidationMixin` — violates `CLAUDE.md` Critical Rule #3" is RED.
>
> Pay extra attention to these recurring drift patterns from the corrections history:
> - Skipping a fix as "needs design discussion" when the rule is already documented (see `memory/feedback_design_system_violations.md`)
> - Offering branch-vs-main ceremony (see `memory/feedback_solo_direct_to_main.md` — solo dev, push direct)
> - Plans that propose new files instead of editing existing ones (CLAUDE.md "Prefer editing existing files")
> - Plans missing the mandatory "What this means in plain language" section (see `.claude/rules/workflow-discipline.md`)
> - Plans that quietly exceed the 500-line file limit without proposing a facade (see `.claude/rules/code-style.md`)
> - Plans that add features/abstractions beyond the task ("future-proofing" — CLAUDE.md "Don't add features...beyond what the task requires")
> - Hardcoded colors/sizes/border radii that should come from theme tokens
>
> **Step 5 — Output format:**
>
> ```
> ## Plan Audit: [plan filename]
>
> ## Memory cross-check
> [✅ No conflicts, OR ⚠️ list conflicts with citations]
>
> ### Scorecard
> 1. Design System          — 🟢/🟡/🔴 [one-line verdict]
> 2. Architecture & Layers  — 🟢/🟡/🔴 [one-line verdict]
> 3. Security & Data        — 🟢/🟡/🔴 [one-line verdict]
> 4. UI States & i18n       — 🟢/🟡/🔴 [one-line verdict]
> 5. DI & Registration      — 🟢/🟡/🔴 [one-line verdict]
> 6. Testing                — 🟢/🟡/🔴 [one-line verdict]
> 7. Edge Cases             — 🟢/🟡/🔴 [one-line verdict]
> 8. Code Reuse             — 🟢/🟡/🔴 [one-line verdict]
> 9. Visual Previews        — 🟢/🟡/🔴 [one-line verdict]
> 10. Scope & Simplicity    — 🟢/🟡/🔴 [one-line verdict]
> 11. Plain-Language Summary — 🟢/🟡/🔴 [one-line verdict]
>
> ### Findings (RED / YELLOW only)
> [For each, include: section, what's wrong, rule citation, suggested fix]
>
> ### Verdict
> - ✅ READY — all GREEN + no memory conflicts, plan can proceed
> - ⚠️ FIX YELLOW — proceed only if YELLOW items are intentional/explained
> - ❌ BLOCKED — RED findings or memory conflicts must be resolved before ExitPlanMode
> ```
>
> Be specific and brief. No filler. If you're certain a section is N/A (e.g., no UI work → Design System N/A), say so once and move on. Don't pad.

## After the agent returns

- Surface the scorecard verbatim to the user
- If RED: highlight which rules were violated and propose specific edits to `tasks/todo.md`
- If YELLOW only: ask the user whether to proceed or fix
- If GREEN: call `ExitPlanMode` (the gate hook will see the marker is fresh and let it through)
