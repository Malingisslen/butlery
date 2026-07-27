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
- Touch review markers in a SEPARATE Bash call before `git commit` — never inline in the same call.
- Pin marker entries as `path@<staged blob sha>` (content identity is checked BEFORE mtime), generated from `git rev-parse :<path>` AFTER the final `git add` — pin-then-restage yields DRIFTED. Record honestly in the marker body anything that changed post-review.
- Stop-hook errors: fix only files THIS session touched; ignore parallel sessions' errors (same rule as CLAUDE.md's "Stop hook response").
- Staging doesn't survive parallel sessions — pathspec-commit in one call and re-verify the index after any gate block (same rule as git-workflow.md's "Parallel sessions").
- At ship time an `MM`/half-staged file is an explicit decision — `git diff` it and either review+test it into scope or `git checkout -- ` back to the reviewed staged version and file a follow-up; never let `git add -A` ship an unreviewed data-CF edit.
- Data-writing Cloud Functions get the xhigh multi-agent review BEFORE commit — the single-specialist gate is necessary but not sufficient.
- Plan-threshold-guard evidence comes from the /review-plan skill → ExitPlanMode block→pass cycle (stamps `plan-approved-<session>.marker`), NOT a hand-rolled audit agent; never SKIP_PLAN_GUARD for a feature, never clobber another session's tasks/todo.md.
- A crashed sprint ship leaves the ONLY copy of the work in the dirty main tree — the engine prunes its worktrees after patching, so back up (`git diff HEAD` + a COPY of every untracked new file) before any triage; never `stash`/clean as "preservation" in a shared checkout.
- Salvaging a crashed sprint pile: rebuild the ticket→file map from the run JOURNAL, re-verify each ticket on its own diff, and commit `.dart` in a QUIET WINDOW (no review agents running `flutter test`, `taskkill dart.exe` first) or the analyze gate deadlocks on two-analyzer contention.
- A clean-tree gate must judge dirt BY KIND: auto-generated role-org bookkeeping churn (`.stale` markers, metrics/janitor/world-watch/role-paths JSON) is not in-flight work — fix the gate (`delivery.cleanTreeIgnore` regex allowlist + Phase-0 filter), don't paper over it by committing the churn.
- Workflow `args` can arrive as a STRING — guard/parse booleans like dryRun before trusting them.
- The per-batch worktrees run NO commit gate, so specialist review is a scheduled post-sprint step that can silently not happen — diff each marker's CONTENTS against `git status` before writing any marker; if any changed file is uncovered, the sprint ends STAGED AND UNCOMMITTED (file the unblocking ticket, grade the plan, HOLD the Linear transitions — "Fixed in commit X" with no commit is a false record). Never forge a marker or exclude a review gate.
- An agent `.knowledge.md`, a chat message and a plan comment are NOT the backlog — the instant an implementer writes "needs a follow-up ticket", file it in that same edit with the code evidence; prose describing a deliverable is not the deliverable (BUT-1691's three sites sat unfiled in a knowledge file).
- A verifier's `fail` verdict is a HYPOTHESIS, same rank as an audit agent's claim about tool output — RUN the suite and paste the count before filing a ticket, transitioning one, or telling Malin "the defect is live". Highest-risk shapes: a claim about a comparison OPERATOR, and a file with two near-identical comparisons in different methods. A doc comment that names an anti-pattern gets misread AS the implementation (BUT-1686's "8 red tests / `>=` still live" was false — 106 passed, `fetchCapped` already used `>`; BUT-1704 filed then cancelled).

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

## CI and repo hygiene

- Slow CI jobs (Build Validation, Run Tests): verify via `gh run list` — the 15-min watcher expires first.
- `docs/analysis/runs/` was deleted by explicit decision — don't recreate it; citations are inlined.
- An iOS-native pin's staleness needs the iOS Build Validation gate to prove — a changelog read is not enough.
- Two-session single-checkout contention (stale `.git/index.lock`, `git commit -- <paths>` immune to the other session's staged index, an analyze gate dying at ~300s = contention not findings) — full ladder in `docs/ops/analyzer-recovery.md` §3/§5.
- lefthook `analyze` TIMEOUT (exit 124) with a clean standalone `dart analyze` = VS Code analyzer contention, not findings → `docs/ops/analyzer-recovery.md` §3.
- Backgrounded gated commit races the Stop hook's own analyzer under two-session load → run it FOREGROUND (`docs/ops/analyzer-recovery.md` §5); re-running already-clean content is operational, not a findings fix.
- Corrupted `.dartServer`: kill `dart.exe` then `rm -rf` immediately, VS Code stays OPEN → `docs/ops/analyzer-recovery.md` §4 (closing VS Code first loses the respawn race).

## Worktrees

- A fresh parallel worktree without `.dart_tool` makes analyze report PHANTOM undefined-member errors (`package:<self>` resolves to the MAIN checkout) — run `dart pub get --offline`/`flutter pub get` in the worktree before trusting analyze.
- The CF/TypeScript twin: a fresh worktree without `functions/node_modules` makes `tsc` report PHANTOM `TS2307 cannot find module 'firebase-functions'` on correct code — junction the main checkout's `functions/node_modules` to verify, then remove it before emitting the patch. Unlink with `cmd //c rmdir <path>` — `rm -rf` FOLLOWS the junction and deletes the main checkout's dependencies. A batch whose fileset is entirely outside the primary toolchain runs the OTHER language's gate (`npx tsc --noEmit` + its suites), never "gates inapplicable".
- The reverse also happens: a TS-only batch run from a fresh Dart worktree is missing `node_modules` too — same fix, junction from the main checkout and unlink with `cmd //c rmdir` (never `rm -rf`, which follows the junction).
- Deny-rule-safe worktree cleanup uses non-destructive `git stash`, never `reset --hard`/`clean -f`, and don't script around the deny rule — the classifier catches the intent; the Bash safety hook also matches dangerous-command strings inside commit MESSAGES, so use `git commit -F <file>` for those.

## Authoring gates and shared config

- A gate's block message may only name remedies that SHIP with the gate (same plugin / inlined procedure) — test the message from every repo the gate is installed in.
- Hardening a proof-of-review gate: the content check is `.every` protected file named + EXACT full-path identity (not `.some`/basename), fail-closed on empty; a green happy-path fixture suite hides the partial-overlap fail-open — run an adversarial "find the fail-open" review of gate machinery and add a partial-overlap fixture; producer and checker must agree on the identity form (BUT-1599/1619).
- Port per-repo configs from the RETIRED implementation's real paths/semantics — structurally different machinery keeps its native hook + opts out of the shared one.
- Shared-plugin (malin-plugins) installs are sha-pinned at LOCAL scope — after committing to C:/claude-plugins run `node tools/fanout-update.mjs`, else the change never ships (new sessions only).
- Backslash/NUL content dies crossing tool layers (JSON→bash→printf/YAML→shell→regex) — write probes with the file tools, keep regexes in script files not YAML inlines, and verify bytes before blaming the gate under test.
- Splitting a gate-blocked sprint: a BATCH verdict is not a per-FILE verdict (re-attribute each finding to the file it names, commit the files no finding lands on); expect a gate CHAIN after the review markers (simplify marker → plan-threshold → repo content guards), and when the next gate needs a WORKAROUND, drop those files from the commit instead — a content guard firing on your file is evidence the ticket isn't done, not noise.
- A divergent push with a deliberately dirty tree: `git merge` refuses on the dirty INDEX even when the incoming commit is disjoint — merge in a scratch `git worktree --detach origin/main`, push from there, then `git merge --ff-only` in the main checkout (it only touches genuinely differing files). Verify disjointness with `comm -12` first; never stash/reset the unshipped half.
- Verify an alert's DETECTION and its DELIVERY separately — a working detector with a mute channel looks identical to a broken one (`gh issue list`'s date column is UPDATED_AT, so a long-open tracking issue reads as brand new). A monitor's own run must `core.setFailed` even though it gates nothing (an always-green health badge is worse than none), and re-notification must COMMENT, not edit the body — GitHub sends no notification for body edits. Rate-limit (24h) + fingerprint the failing set so a per-gate trigger doesn't spam.
- A guard added in a fix round that reddens an INTENTIONAL existing test is changing a contract it did not declare — revert it and ticket, don't rewrite the test to fit (especially with no live caller, late in a large diff). A finding flagged N times may be repeatedly flagged BECAUSE it is latent; "fourth pass" argues for a ticket carrying the history, not a drive-by.
