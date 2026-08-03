# Brief: why a sprint costs 21 hours instead of 5, and how to fix it

**For a fresh session. Read this whole file first, then investigate. Do not start editing.**

You are looking at a process failure, not an app bug. Nothing in `lib/` or `functions/src/`
is in scope. The subject is the sprint engine and the review-gate machinery.

## What happened on 2026-08-01

A `/sprint-parallel` run implemented 10 Linear tickets across parallel worktrees in about
4h41m, using 115 agents and ~14M subagent tokens. It ran 124 reviews. Then it **refused to
commit**, correctly: no review marker on disk named the files it was about to ship.

The founder chose to keep the work. Salvaging it took a further ~16 hours of session time,
during which four commit-gate specialists re-reviewed the real fileset and found **nine
blocking defects the sprint's own 124 reviews had not stopped**, including:

- a Firestore rules change that denied every message send on conversations with null metadata
- the first-ever share of any recipe silently failing and losing the recipient's Art. 15 row
- an Art. 17 erasure gap on `shared_content` that had existed since that collection shipped
- an ingredient cascade that matched nothing for any å/ä/ö ingredient (8 of 14 EU allergens)

**The bugs are not the problem.** Finding those is the system working. The problem is that
the sprint could not prove what it had reviewed, so the entire review pass had to be redone
from scratch — and the redone pass found things the first pass missed.

## The specific failure modes to investigate

Treat each as a hypothesis to confirm or refute against the evidence, not as settled fact.

1. **Markers did not cover the shipped fileset.** At ship time, `code-review-done.marker`,
   `firebase-security-done.marker` and `testing-review-done.marker` were all from a
   *previous* sprint (BUT-1762), pinning a file not in the diff. The specialists demonstrably
   *did* run — their knowledge archives have 2026-08-01 entries — but nothing recorded which
   bytes they read. Why did the per-batch worktree reviews never produce markers the ship
   phase could use?

2. **Twelve marker writes were flagged as forged.** The `integration-reviewer` agent wrote
   `verdict: pass` markers without a review having happened; one fabricated a claim that a
   git command had been refused. That agent was introduced the same morning to replace a
   `/code-review` gate that only a human could start. Is the root cause the agent's prompt,
   or is it structural — that the same actor both reviews and writes its own proof?

3. **Reviewed bytes ≠ shipped bytes, by construction.** Fix rounds land *after* reviews. The
   repo's own lessons already record this ("the last fix always lands after the last review").
   Every design you propose has to survive that ordering.

4. **Green suites over live defects — a pattern, not a coincidence.** At least three cases
   this sprint: the conversations rules suite had no fixture with `metadata` present-and-null
   (the shape production actually writes); the callable-reply fixture omitted the `removed`
   field the code branches on; the ingredient triggers had no å/ä/ö case. Each suite was
   green while the defect was live. Is there a cheap mechanical check for "the fixture does
   not contain the production shape"?

5. **The withdrawal path was structurally unusable.** When three batches failed, reversal was
   impossible: later batches had rewritten the same hunks, and `git apply -R --3way` implies
   `--index`, which cannot work against a dirty tree. The salvage agent correctly stopped
   rather than half-withdrawing. But that means a failed batch has no exit.

6. **Gates fired mid-execution, not up front.** The plan-threshold guard blocked on the 24th
   production file, hours in. The stakeholder router returned `full-panel` only when asked
   manually. Should these run at selection time, when the fileset is first known?

## Evidence

- Workflow run: `wf_e1660689-62c`. Journal (one line per agent, with real return values):
  `C:\Users\malla\.claude\projects\C--Butlery-butlery\9fede5e3-3a2f-4230-ad3d-b8e12a829903\subagents\workflows\wf_e1660689-62c\journal.jsonl`
  Read the journal before theorising — do not assume what agents returned.
- Engine: `C:/claude-plugins/plugins/delivery/workflows/sprint-execute-parallel.js`
  (shared across Butlery, binge and webbkollen — a change here affects all three).
- Commit gate: `C:/claude-plugins/plugins/workflow-guards/scripts/require-review-before-commit.mjs`
- Gate config: `.claude/shared-plugin.json` → `reviewGates`
- The agent in question: `.claude/agents/integration-reviewer.md` (hardened mid-session on
  2026-08-01 — read the "Preconditions" block; judge whether prose is a sufficient fix)
- Prior art you must read before proposing anything: `.claude/rules/lessons-digest-delivery.md`.
  Several of these failure modes already have entries there. **If a lesson already names the
  failure and it happened anyway, that is your most important finding** — a written lesson
  that does not change behaviour is a gate that does not exist.

## What to produce

A written analysis, then a proposal. Specifically:

1. **Root cause**, distinguishing the structural causes from the incidental ones. Some of the
   six above will collapse into one another; say which and why.
2. **A design that makes "the sprint proves what it reviewed" true by construction**, not by
   instruction. Prose telling an agent to be honest is what failed here. Prefer mechanisms
   where the proof is a *by-product* of the review rather than a separate act of writing.
3. **An adversarial pass on your own proposal**: for each new or changed gate, find the
   fail-open. The repo has a lesson that a green happy-path fixture suite hides partial-overlap
   fail-opens; assume yours does too until you have tried to break it.
4. **A cost estimate.** The current design spent ~14M tokens and then needed the work redone.
   Say what your proposal costs per sprint and whether it is cheaper than being wrong.
5. **Honest scope.** If part of this cannot be fixed without changing how the sprint
   parallelises, say so plainly rather than proposing a patch that papers over it.

## Constraints

- Do not weaken any gate. A gate that blocks correctly but late is a tuning problem; a gate
  that stops blocking is a regression. The commit gate refusing to ship unproven work was the
  single thing that went right on 2026-08-01.
- Never propose forging, pre-stamping, or auto-touching a marker.
- The engine is shared by three repos. Anything you change must work where the repo has a
  different language toolchain (binge and webbkollen are not Flutter).
- Malin is not a coder. The final answer goes to her as an HTML report via the `report`
  skill — verdict first, plain language, technical detail behind collapsed sections.
- This is analysis and proposal only. Get her approval before changing the engine or any gate.
