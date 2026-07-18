# Lessons Digest (auto-loaded)

One line per lesson in `tasks/lessons.md` — this digest loads every session so the
corrections are always in force; the full entries (Trigger/Rule/Example) are the deep
reference. **Sync contract (CLAUDE.md rule #9):** every new lesson gets its one-liner
appended here in the same edit. A Stop-hook tripwire (`knowledge-freshness`, workflow-guards plugin) warns
when the counts drift apart.

## Workflow

- A gate's block message may only name remedies that SHIP with the gate (same plugin / inlined procedure) — test the message from every repo the gate is installed in.
- An audit agent's claim about a tool's OUTPUT FORMAT is a guess until reproduced — run the real tool and test the regex against a real line before "fixing" a parser.
- Feedback right after a deliverable may target the TOOL/process, not the one artifact — disambiguate "fix this output" vs "improve the capability" before acting.
- A multi-part agreed initiative gets ONE written plan before any slice ships — chat scrollback is not a backlog.
- Every proposed improvement must name its mechanical trigger; upgrading an optional command is convenience, not infrastructure.
- Never prune a young system for inactivity — the observation window must exceed its natural cycle (tune now; keep/cut only after 2–3 cycles).
- Epic breakdown: query the epic's CHILDREN + statuses first; the epic body is a stale snapshot.
- Scan dedup runs against CURRENT code + recorded decided-nos — a closed same-name ticket may be a regression; refile it.
- Don't hand the user judgment/labor you can derive yourself; defer only product intent, irreversible actions, or external facts.
- Never conclude "backlog drained" from a sample — full-backlog classification first (gated via `.claude/state/backlog-scan.json`).
- Wrap side-effect ship agents in try/catch; verify from git ground truth; salvage crashed runs instead of re-running.
- Sprint Phase-1 plan-write to `tasks/todo.md` is non-optional — even mid-streak, even for trivial tickets.
- Bash `cd` persists across calls — use absolute paths.
- Verify a ticket's premise with a Step-0 code read before implementing; live code trumps ticket text.
- Verify Edits actually landed (`git diff`) before committing — never trust the commit-message claim.
- Stop-hook errors: fix only files THIS session touched; ignore parallel sessions' errors.
- Workflow `args` can arrive as a STRING — guard/parse booleans like dryRun before trusting them.
- Umbrella "apply the deferred notes" tickets must carry the content inline or link an immutable source.
- "Unreferenced" must be proven against the WHOLE repo, never a hand-picked subset.
- Eval input must match PRODUCTION input, not the cheapest-to-label input.
- Run arch gates locally before committing UI widgets.
- Touch review markers in a SEPARATE Bash call before `git commit` — never inline in the same call.
- Slow CI jobs (Build Validation, Run Tests): verify via `gh run list` — the 15-min watcher expires first.
- `docs/analysis/runs/` was deleted by explicit decision — don't recreate it; citations are inlined.
- An iOS-native pin's staleness needs the iOS Build Validation gate to prove — a changelog read is not enough.
- When the user asks for a new mode, deliver ONE mode — no "normal + extra", no spare variants.
- Staging doesn't survive parallel sessions — pathspec-commit in one call and re-verify the index after any gate block.
- Two-session single-checkout contention: `git commit -- <paths>` is immune to the other session's staged index; a lock with NO live git/lefthook process is stale (remove it — an until-loop otherwise spins to timeout); an analyze gate dying at exactly ~300s during their gate run is contention, not findings.
- "Map the workflows" means full coverage against a stated universe — never silently curate a sample.
- Data-writing Cloud Functions get the xhigh multi-agent review BEFORE commit — the single-specialist gate is necessary but not sufficient.
- When citing a deterministic tool's verdict (router tier, gate, test), RUN it and paste output — never assert what it would say.
- Port per-repo configs from the RETIRED implementation's real paths/semantics — structurally different machinery keeps its native hook + opts out of the shared one.
- Deny-rule-safe worktree cleanup uses non-destructive `git stash` (not `reset --hard`/`clean -f`, and don't script around the deny rule — the classifier catches the intent); and the Bash safety hook matches dangerous-command strings inside commit MESSAGES too, so `git commit -F <file>` for messages that quote them.
- Step-0 premise check greps CURRENT main (not `git log`) at SELECTION time — a scanner ticket whose fix already shipped under another ID gets closed as a duplicate, never carried as buildable.
- At ship time an `MM`/half-staged file is an explicit decision — `git diff` it and either review+test it into scope or `git checkout -- ` back to the reviewed staged version and file a follow-up with the reverted code; never let `git add -A` ship an unreviewed data-CF edit.
- Grade each SELECTED ticket against its OWN diff at ship — a batch "N landed, none failed" summary hides silent drops; a zero-diff ticket is dropped (carry forward) or obsolete (close citing the resolving commit), never Done.
- A fresh parallel worktree without `.dart_tool` makes analyze report PHANTOM undefined-member errors (`package:<self>` resolves to the MAIN checkout) — run `dart pub get --offline`/`flutter pub get` in the worktree before trusting analyze.
- lefthook `analyze` gate TIMEOUT (exit 124) while standalone `dart analyze` is clean = contention with VS Code's live analyzer — `taskkill //F //IM dart.exe` right before committing (not `LEFTHOOK_EXCLUDE` on a `.dart` diff); a saturated process table crashes the analysis server + blocks fork (restart, don't retry); background the commit so arch-guard's ~10-min compile outlives the shell ceiling.
- A clean-tree gate must judge dirt BY KIND: auto-generated role-org bookkeeping churn (`.stale` markers, metrics/janitor/world-watch/role-paths JSON) is not in-flight work — fix the gate (`delivery.cleanTreeIgnore` regex allowlist + Phase-0 filter), don't paper over it by committing the churn.
- The parallel-sprint ship phase can force a commit past the marker review-gate (fresh `.marker` mtime proves a touch, not a review) — on ANY sprint completion re-run the commit-gate specialists against the actual committed diff before trusting `review.gates:ok`; push≠deploy so unreviewed code on main is fixable forward.
- Shared-plugin (malin-plugins) installs are sha-pinned at LOCAL scope — after committing to C:/claude-plugins run `node tools/fanout-update.mjs` (one command, updates all repos + validates configs; since 2026-07-16), else the change never ships (new sessions only).
- Backslash/NUL content dies crossing tool layers (JSON→bash→printf/YAML→shell→regex) — write probes via quoted heredocs, keep regexes in script files not YAML inlines, and od-verify bytes before blaming the gate under test.
- A subagent naming a file as "the X path" proves existence, not routing — read the client orchestrator's tier/fallback structure yourself before asserting what runs first (cost/privacy claims always get direct verification).
- A backgrounded gated commit races the Stop-hook's own `dart analyze` (fired each turn-end) — under two-session load the process table saturates and the commit dies with fork failures + a stale `.git/index.lock`; run the gated commit FOREGROUND with a long Bash timeout (≤600000ms) so the turn stays active and no competing analyze fires, use `git commit -- <pathspec>` (immune to the other session's index sweep), and clear stale locks/zombies first. Content that passed all gates once (only the ref-lock racing) is proven clean — re-run is operational, not a findings fix.
- Clearing a corrupted .dartServer needs `taskkill //F //IM dart.exe` + immediate `rm -rf` (works with VS Code OPEN) — scripted close-VS-Code-then-delete always loses the respawn race; leftover temp files owned by the NEW analyzer PID mean success.
- A crashed sprint ship leaves the ONLY copy of the work in the dirty main tree — the engine prunes its worktrees after patching, so back up (`git diff HEAD` + a COPY of every untracked new file) before any triage; never `stash`/clean as "preservation" in a shared checkout.
- A blocked ship gate is a STOP, not a puzzle to route around — never forge a marker to satisfy a gate; a marker's mtime proves a touch, so read its CONTENTS against the current diff's ticket IDs before trusting `gates:ok`.

## Architecture

- `BaseViewModel.executeAsync` fails LOUD (throws `StateError`) on a disposed VM BY DESIGN — its non-nullable `Future<T>` can't return a fake `null`; the fail-silent siblings (`executeAsyncVoid`→false, setters→no-op) differ only because their return types allow it. Don't "harmonise" it; guard callers with `if (isDisposed) return;` instead (BUT-1462, sweep in BUT-1628).

## UI/UX

- Heuristic/LLM-derived visible content (headings, tags, parsed amounts) ships WITH its correction UI in the MVP — "display now, correct later" is never a valid phasing.

## Testing

- Red CI on an unrelated test = suspect a pre-existing flake; fix the flake at root (seed the RNG) — never rerun-until-green.
- Chronic-red CI disarms safety-gate tests silently — triage any always-red job to zero promptly, and after moving a definition, grep tests for hardcoded paths/regexes aimed at the old site.
- `architecture_test.dart` guards are NOT in `dart analyze` — analyze-clean ≠ CI-green for `lib/widgets/`.
- Adding a named param to a mocked service silently un-matches every old mocktail stub — update the stubs.
- cloud_firestore's FieldValue caches the platform factory statically — fake batches can throw subtype errors.
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- Lexicon-dependent tests: assert the premise, and watch NFC vs NFD normalization on å/ä/ö.
- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds `(?<![a-zåäö0-9])`/`(?![a-zåäö0-9])`, and pin å/ä/ö-boundary cases in tests.
- real-time-guard matches the literal `DateTime.now()` even inside comments.
- After changing a class's constructor, run its EXISTING test suites — not just the new test you wrote.
- A parallel-sprint's own "verified/done" is a claim, not a fact — on any salvage, verify from git, run the workflow /code-review (cross-file) on the staged diff BEFORE the specialist gates, then re-review the fixes; here it caught 8 bugs (incl. cross-file integration regressions) the per-ticket adversarial verify + file-scoped specialists both missed.
- Plan-threshold-guard evidence comes from the /review-plan skill → ExitPlanMode block→pass cycle (stamps `plan-approved-<session>.marker`), NOT a hand-rolled audit agent; if blocked despite an approved plan, re-enter plan mode + ExitPlanMode to stamp it — never SKIP_PLAN_GUARD for a feature, never clobber another session's tasks/todo.md.
- An audit report's "unfiled finding" is a repo-grep guess that can't see the tracker — before filing, re-check current code (may be fixed) AND search Linear (prior triage often consolidates many findings into one batch ticket whose title won't match).
- A sprint specialist-review gate scores `ok` on any result, even a STUB finding (`issue:"test"`) — for data-writing/deleting code, open the gate's actual payload and re-run the real specialist on the COMMITTED diff; adversarial verify passing too is not a substitute (refuters miss the same structural fail-open).

## Firebase

- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index (filter field first, aggregated field included); `count()` doesn't. In-memory fakes can't catch it — assert the declared index config in a test.
- Salvaging a crashed sprint pile: rebuild the ticket→file map from the run JOURNAL, re-verify each ticket on its own diff (never trust the sprint's gates:ok), and commit `.dart` in a QUIET WINDOW (no review agents running `flutter test`, `taskkill dart.exe` first) or the analyze gate deadlocks on two-analyzer contention.
