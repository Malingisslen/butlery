# Workflow Discipline

## When a plan is required

A change is "large" — and gets a written, approved plan before any Edit/Write — if it hits
any of: **2+ production files**, a new service/viewmodel/repository, an architectural or
base-class change, a "refactor"/"migrate" request, a multi-file codemod, **or any sensitive
domain** (Firestore data or rules, auth, Cloud Functions, GDPR/user data).

The sensitive-domain half applies **even at a single file**. Route that work through
planning before touching a matching path, not after the gate stops you.

Production means code under `lib/` or `functions/src/`. Tests, generated files
(`*.g.dart`, `*.freezed.dart`, `lib/l10n/`), docs and config do **not** count — a fix plus
its test ships without ceremony. Small, obvious, single-production-file fixes ship without
ceremony too; don't gold-plate.

Both halves are gate-enforced, and the gate prints the full remedy when it fires. Enter
plan mode automatically; the plan goes to `tasks/todo.md`; every plan ends with a
plain-language summary for Malin (rules in `.claude/plan-review-checklist.md`). If the work
starts going sideways, STOP and re-plan rather than pushing through.

## Cast stakeholders before planning

For any large change, or anything touching user/children's data, money, security, auth,
Firestore rules, release compliance or legal: run `python tools/stakeholder_router.py
--json <paths>` first and convene whatever tier it returns, then fold the conditions into
the plan as acceptance criteria. The `stakeholder-review` skill carries the procedure. An
unresolved high-stakes conflict goes to Malin *in* the plan, never buried.

## Before building new automation

A hook, scheduled routine, loop or agent earns its keep only if it passes the four-box
test (repeats ≥weekly, something auto-rejects bad output, runs end-to-end without a human
mid-run, "done" is objective) and has a named firing path. Full test in
`.claude/rules/automation-proposals.md` (loads when editing hooks/skills/workflows).

## Verification before done

- Relevant tests pass, and the diff behaves as intended versus main.
- Layout/UI changes get checked in a browser before "done".
- If the first fix fails: stop guessing. Find three similar working views, compare their
  pattern to the broken one, then fix from the working pattern.
- Ask: would a staff engineer approve this — including approving "I'm stuck" as an honest
  answer?

## Demand diagnosis

For non-trivial changes, ask "is there a more elegant way?" before presenting. If a fix
feels like a workaround, redo it cleanly knowing what you now know.

**Balance clause:** for simple or one-line fixes, ship it. This rule serves quality on
substantial work; on trivial work it would just fight "don't over-estimate complexity".
Applies when a change touches 3+ files, adds a service or viewmodel, or the first working
version felt like a workaround.

## Self-improvement loop

After any user correction, **and** after solving a hard problem (more than one failed
attempt, or a non-obvious judgment call), add an entry to `tasks/lessons.md` and its
one-liner to the matching digest in the same edit. Corrections capture what went wrong;
the second case captures reasoning worth keeping. Routine wins don't qualify. If a lesson
should become a CLAUDE.md rule, propose it.

## Memory

Auto-memory manages the memory directory. `current-state.md` is written by the PreCompact
hook — never overwrite it with auto-memory content.

## Autonomous problem solving

Bug report, failing CI, or an error pointed at: just fix it (spawn the debugger agent).
Don't ask for hand-holding on standard debugging. If stuck after several attempts, write a
diagnostic summary of what was tried and why it failed, then ask for direction.

## Parallel agent tasks

Chunk large item sets (50–100 at a time, never a whole file), verify agents aren't
overwriting each other, and batch (2–3) rather than fan out 10+ at once. Full guidance in
`.claude/rules/automation-proposals.md`.
