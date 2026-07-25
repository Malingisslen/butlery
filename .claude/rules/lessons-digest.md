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
- "Unreferenced" must be proven against the WHOLE repo, never a hand-picked subset.
- Run arch gates locally before committing UI widgets.
- When the user asks for a new mode, deliver ONE mode — no "normal + extra", no spare variants.
- "Map the workflows" means full coverage against a stated universe — never silently curate a sample.
- When citing a deterministic tool's verdict (router tier, gate, test), RUN it and paste output — never assert what it would say.
- A subagent naming a file as "the X path" proves existence, not routing — read the client orchestrator's tier/fallback structure yourself before asserting what runs first (cost/privacy claims always get direct verification).
- A blocked gate is a STOP, not a puzzle to route around — never forge a marker; a marker's mtime proves a touch, so read its CONTENTS against the current diff before trusting a gates:ok.
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- A subagent's transcript file is NOT a liveness signal (0 bytes + stale mtime is normal mid-run — it flushes on completion); only the completion notification proves an agent finished, so never write up "the agent stalled/failed" from file stats. Wait in few LONG background sleeps, not many short holds.

- Context-diet's four-mechanism retirement ranking (gate message > agent/skill body > `paths:` frontmatter > never description-alone) and its proof step now live in the `/context-diet` skill body itself — don't re-derive them here.

- "I read very little of what you reply" is a CONFIG bug first — grep the always-on setup (output styles, SessionStart plugins, stale model-tuning blocks) before apologising in prose; fix the mechanism (`~/.claude/output-styles/`) and delete the conflicting prose in the same edit.

- A decision record that ASSERTS SOMETHING ABOUT CODE (a gate's presence, a predicate, a field's absence) has an expiry it cannot see — grep the code before relying on one, and always before citing it to justify REMOVING a control. Code wins on facts; only the founder decides which document changes. Supersede the stale entry with a dated one quoting the verified code, never delete it silently.

## Architecture

- `BaseViewModel.executeAsync` fails LOUD (throws `StateError`) on a disposed VM BY DESIGN — its non-nullable `Future<T>` can't return a fake `null`; the fail-silent siblings differ only because their return types allow it. Don't "harmonise" it; guard callers with `if (isDisposed) return;` (BUT-1462, sweep in BUT-1628).

## UI/UX

- Heuristic/LLM-derived visible content (headings, tags, parsed amounts) ships WITH its correction UI in the MVP — "display now, correct later" is never a valid phasing.

## Language and Firebase gotchas

- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds `(?<![a-zåäö0-9])`/`(?![a-zåäö0-9])`, and pin å/ä/ö-boundary cases in tests.
- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index (filter field first, aggregated field included); `count()` doesn't. In-memory fakes can't catch it — assert the declared index config in a test.
