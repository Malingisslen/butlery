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

## Before building new automation — the four-box test

A hook, scheduled routine, self-running loop or agent earns its keep only if all four hold.
Miss one and it stays a manual tool, honestly labelled:

1. **Repeats at least weekly** — below that the setup never amortizes.
2. **Something can auto-reject bad output** — a test, gate or hard rule fails the work
   without a human. No gate and the loop just spins and bills.
3. **Runs end-to-end** — if it stalls waiting for a human mid-run it's a manual step in a
   loop costume.
4. **"Done" is objective, not taste** — automate the detection, leave the decision.

It also needs a named firing path (hook, schedule, gate) or it rots unread. Prefer
deterministic code over an LLM call inside any loop.

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

Process files in small chunks (50–100 items), never a whole large file at once. Define
chunk boundaries before launching. Verify agents aren't overwriting each other. For a plan
with 10+ items, run sequentially or in batches of 2–3.
