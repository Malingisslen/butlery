---
paths:
  - ".claude/workflows/**"
  - ".claude/shared-plugin.json"
  - ".claude/state/**"
  - "tasks/todo.md"
---

# Lessons Digest — delivery pipeline

Lessons that only bind while running `/sprint-execute`, `/sprint-parallel`, `/linear`, the
Workflow engine, or while authoring gates. Counted by the same drift tripwire as the core
digest (`knowledge.digestFiles`), so a lesson here is as "in force" as one there — it just
does not load in sessions that are not doing this work.

Read this before starting a sprint, a backlog scan, or a ship pass.

## Sprint and ship

- Sprint Phase-1 plan-write to `tasks/todo.md` is non-optional — even mid-streak, even for trivial tickets.
- Wrap side-effect ship agents in try/catch; verify from git ground truth; salvage crashed runs instead of re-running.
- Grade each SELECTED ticket against its OWN diff at ship — a batch "N landed, none failed" summary hides silent drops; a zero-diff ticket is dropped (carry forward) or obsolete (close citing the resolving commit), never Done.
- The parallel-sprint ship phase can force a commit past the marker review-gate (fresh `.marker` mtime proves a touch, not a review) — on ANY sprint completion re-run the commit-gate specialists against the actual committed diff before trusting `review.gates:ok`; push≠deploy so unreviewed code on main is fixable forward.
- A sprint specialist-review gate scores `ok` on any result, even a STUB finding (`issue:"test"`) — for data-writing/deleting code, open the gate's actual payload and re-run the real specialist on the COMMITTED diff; adversarial verify passing too is not a substitute (refuters miss the same structural fail-open).
- A parallel-sprint's own "verified/done" is a claim, not a fact — on any salvage, verify from git, run the workflow /code-review (cross-file) on the staged diff BEFORE the specialist gates, then re-review the fixes; here it caught 8 bugs the per-ticket adversarial verify and file-scoped specialists both missed.
- A crashed sprint ship leaves the ONLY copy of the work in the dirty main tree — the engine prunes its worktrees after patching, so back up (`git diff HEAD` + a COPY of every untracked new file) before any triage; never `stash`/clean as "preservation" in a shared checkout.
- Salvaging a crashed sprint pile: rebuild the ticket→file map from the run JOURNAL, re-verify each ticket on its own diff, and commit `.dart` in a QUIET WINDOW (no review agents running `flutter test`, `taskkill dart.exe` first) or the analyze gate deadlocks on two-analyzer contention.
- A clean-tree gate must judge dirt BY KIND: auto-generated role-org bookkeeping churn (`.stale` markers, metrics/janitor/world-watch/role-paths JSON) is not in-flight work — fix the gate (`delivery.cleanTreeIgnore` regex allowlist + Phase-0 filter), don't paper over it by committing the churn.
- Workflow `args` can arrive as a STRING — guard/parse booleans like dryRun before trusting them.

## Ticket selection and the backlog

- Verify a ticket's premise with a Step-0 code read before implementing; live code trumps ticket text.
- Step-0 premise check greps CURRENT main (not `git log`) at SELECTION time — a scanner ticket whose fix already shipped under another ID gets closed as a duplicate, never carried as buildable.
- Verify a ticket's done/dropped status against CURRENT code (grep the working tree / `git show HEAD:<path>`), never a per-commit `git show`/`git log` — parallel work jumbles which commit carries what.
- Never conclude "backlog drained" from a sample — full-backlog classification first (gated via `.claude/state/backlog-scan.json`).
- Epic breakdown: query the epic's CHILDREN + statuses first; the epic body is a stale snapshot.
- Scan dedup runs against CURRENT code + recorded decided-nos — a closed same-name ticket may be a regression; refile it.
- An audit report's "unfiled finding" is a repo-grep guess that can't see the tracker — before filing, re-check current code (may be fixed) AND search Linear (prior triage often consolidates many findings into one batch ticket whose title won't match).
- Umbrella "apply the deferred notes" tickets must carry the content inline or link an immutable source.
- A ticket that CANNOT ship autonomously (build-review / need-malin UI sign-off) gets starved-and-dropped every autonomous sprint — the moment a Step-0 read shows a ticket needs the founder's eyes, re-label it need-malin/deferred; don't let it ride the autonomous queue as a perpetual carry-forward (BUT-1615 hit its 5th consecutive drop).

## Worktrees

- A fresh parallel worktree without `.dart_tool` makes analyze report PHANTOM undefined-member errors (`package:<self>` resolves to the MAIN checkout) — run `dart pub get --offline`/`flutter pub get` in the worktree before trusting analyze.
- The CF/TypeScript twin: a fresh worktree without `functions/node_modules` makes `tsc` report PHANTOM `TS2307 cannot find module 'firebase-functions'` on correct code — junction the main checkout's `functions/node_modules` to verify, then remove it before emitting the patch.

## Authoring gates and shared config

- A gate's block message may only name remedies that SHIP with the gate (same plugin / inlined procedure) — test the message from every repo the gate is installed in.
- Hardening a proof-of-review gate: the content check is `.every` protected file named + EXACT full-path identity (not `.some`/basename), fail-closed on empty; a green happy-path fixture suite hides the partial-overlap fail-open — run an adversarial "find the fail-open" review of gate machinery and add a partial-overlap fixture; producer and checker must agree on the identity form (BUT-1599/1619).
- Port per-repo configs from the RETIRED implementation's real paths/semantics — structurally different machinery keeps its native hook + opts out of the shared one.
