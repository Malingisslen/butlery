# Lessons Digest — core (auto-loaded)

One line per lesson in `tasks/lessons.md`; the full entries there are the deep reference.
**Sync contract (CLAUDE.md rule #9):** every new lesson gets its one-liner in the same edit.
A Stop-hook tripwire counts the lines across all digest files and warns when they drift.

Routing — put a new line in the file that matches when it is needed:
`lessons-digest.md` (here) for anything that binds any session; `lessons-digest-delivery.md`
for sprint, Linear, worktree and ship-pipeline lessons; `lessons-digest-testing.md` for
lessons that only matter while writing or running tests.

## Workflow

- An audit agent's claim about a tool's OUTPUT FORMAT is a guess until reproduced — run the real tool and test the regex against a real line before "fixing" a parser.
- Feedback right after a deliverable may target the TOOL/process, not the one artifact — disambiguate "fix this output" vs "improve the capability" before acting.
- A multi-part agreed initiative gets ONE written plan before any slice ships — chat scrollback is not a backlog.
- Every proposed improvement must name its mechanical trigger; upgrading an optional command is convenience, not infrastructure.
- Never prune a young system for inactivity — the observation window must exceed its natural cycle (tune now; keep/cut only after 2–3 cycles).
- Don't hand the user judgment/labor you can derive yourself; defer only product intent, irreversible actions, or external facts.
- Bash `cd` persists across calls — use absolute paths.
- Verify Edits actually landed (`git diff`) before committing — never trust the commit-message claim.
- Stop-hook errors: fix only files THIS session touched; ignore parallel sessions' errors.
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
- Deny-rule-safe worktree cleanup uses non-destructive `git stash`, never `reset --hard`/`clean -f`, and don't script around the deny rule — the classifier catches the intent; the Bash safety hook also matches dangerous-command strings inside commit MESSAGES, so use `git commit -F <file>` for those.
- At ship time an `MM`/half-staged file is an explicit decision — `git diff` it and either review+test it into scope or `git checkout -- ` back to the reviewed staged version and file a follow-up; never let `git add -A` ship an unreviewed data-CF edit.
- Shared-plugin (malin-plugins) installs are sha-pinned at LOCAL scope — after committing to C:/claude-plugins run `node tools/fanout-update.mjs`, else the change never ships (new sessions only).
- Backslash/NUL content dies crossing tool layers (JSON→bash→printf/YAML→shell→regex) — write probes with the file tools, keep regexes in script files not YAML inlines, and verify bytes before blaming the gate under test.
- A subagent naming a file as "the X path" proves existence, not routing — read the client orchestrator's tier/fallback structure yourself before asserting what runs first (cost/privacy claims always get direct verification).
- A blocked gate is a STOP, not a puzzle to route around — never forge a marker; a marker's mtime proves a touch, so read its CONTENTS against the current diff before trusting a gates:ok.
- Plan-threshold-guard evidence comes from the /review-plan skill → ExitPlanMode block→pass cycle (stamps `plan-approved-<session>.marker`), NOT a hand-rolled audit agent; never SKIP_PLAN_GUARD for a feature, never clobber another session's tasks/todo.md.
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- lefthook `analyze` TIMEOUT (exit 124) while standalone `dart analyze` is clean is contention with VS Code's live analyzer, not findings — recovery ladder in `docs/ops/analyzer-recovery.md`.
- A backgrounded gated commit races the Stop-hook's own analyze — run it FOREGROUND with a long Bash timeout (≤600000ms) and `git commit -- <pathspec>`; content that passed the gates once is proven clean, so a re-run is operational, not a findings fix.
- Clearing a corrupted `.dartServer` works with VS Code OPEN (`taskkill //F //IM dart.exe` then immediate `rm -rf`) — the close-VS-Code-first route loses the respawn race.
- A subagent's transcript file is NOT a liveness signal (0 bytes + stale mtime is normal mid-run — it flushes on completion); only the completion notification proves an agent finished, so never write up "the agent stalled/failed" from file stats. Wait in few LONG background sleeps, not many short holds.

- Always-on instruction context retires only into a NAMED mechanism, best-first: a gate's block message (fires when relevant, ships once for all repos) > an agent/skill body > `paths:` frontmatter (dropped on /compact, so safety rules keep a one-line always-on statement and move only detail) > never skill-description matching alone. A `retire` verdict needs the gate's text QUOTED and its config key wired in the same change; prove it by triggering the gate in a throwaway repo with none of the removed prose present (`/context-diet`).

## Architecture

- `BaseViewModel.executeAsync` fails LOUD (throws `StateError`) on a disposed VM BY DESIGN — its non-nullable `Future<T>` can't return a fake `null`; the fail-silent siblings differ only because their return types allow it. Don't "harmonise" it; guard callers with `if (isDisposed) return;` (BUT-1462, sweep in BUT-1628).

## UI/UX

- Heuristic/LLM-derived visible content (headings, tags, parsed amounts) ships WITH its correction UI in the MVP — "display now, correct later" is never a valid phasing.

## Language and Firebase gotchas

- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds `(?<![a-zåäö0-9])`/`(?![a-zåäö0-9])`, and pin å/ä/ö-boundary cases in tests.
- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index (filter field first, aggregated field included); `count()` doesn't. In-memory fakes can't catch it — assert the declared index config in a test.
