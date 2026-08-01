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
- A hook registered with a RELATIVE path stops firing the moment the Bash cwd drifts into a subdirectory, and a PreToolUse failure is NON-BLOCKING — so the safety firewall silently lets destructive commands through. Wrap every hook command with `cd "$(git rev-parse --show-toplevel)"`, and diagnose contradictory hook errors from the transcript's `cwd` field, not the filesystem. The firewall also matches commit-message prose quoting a blocked pattern — reword, never weaken it.
- Verify Edits actually landed (`git diff`) before committing — never trust the commit-message claim.
- "Unreferenced" must be proven against the WHOLE repo, never a hand-picked subset.
- Run arch gates locally before committing UI widgets.
- When the user asks for a new mode, deliver ONE mode — no "normal + extra", no spare variants.
- "Map the workflows" means full coverage against a stated universe — never silently curate a sample.
- When citing a deterministic tool's verdict (router tier, gate, test), RUN it and paste output — never assert what it would say.
- A subagent naming a file as "the X path" proves existence, not routing — read the client orchestrator's tier/fallback structure yourself before asserting what runs first (cost/privacy claims always get direct verification).
- A blocked gate is a STOP, not a puzzle to route around — never forge a marker; a marker's mtime proves a touch, so read its CONTENTS against the current diff before trusting a gates:ok.
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- A registry/structural lint that reddens on a given day is usually pointing at that day's DELETION commit, not at itself — date the first red run, `git log -S <symbol>`, and never allowlist a constant to clear a coverage lint.
- A subagent's transcript file is NOT a liveness signal (0 bytes + stale mtime is normal mid-run — it flushes on completion); only the completion notification proves an agent finished, so never write up "the agent stalled/failed" from file stats. Wait in few LONG background sleeps, not many short holds.

- A mutation probe is a WRITE to real code and your own script is the instrument: back up first, restore from a `finally` AND from SIGINT/SIGTERM/SIGHUP/SIGBREAK, then assert the bytes are byte-identical — a harness timeout killed one between "apply mutant 3" and "restore", and the suite was GREEN with the mutant live. Scraping a total from tool output: anchor on a unique prefix or take the LAST match; a nested sub-suite's "N checks passed" line reads exactly like the outer one (89 vs 162).

- An invisible codepoint makes correct code read as broken — before believing a Firestore prefix range is degenerate (`>= x AND < x`), byte-check the bound (`cat -A`, `grep -P "\x{F8FF}"`) and confirm against real data; a visual read of source, yours or an agent's, is not evidence about non-printing characters. When a ticket claims a guard test is missing, MUTATION-TEST the existing suite first (remove the load-bearing token, count the reds, restore) — the alarm often already exists and the real fix is deleting the trap. Spell non-printing sentinels as escapes and lint the literal (BUT-1690).

- Context-diet's four-mechanism retirement ranking (gate message > agent/skill body > `paths:` frontmatter > never description-alone) and its proof step now live in the `/context-diet` skill body itself — don't re-derive them here.

- "I read very little of what you reply" is a CONFIG bug first — grep the always-on setup (output styles, SessionStart plugins, stale model-tuning blocks) before apologising in prose; fix the mechanism (`~/.claude/output-styles/`) and delete the conflicting prose in the same edit.

- A decision record that ASSERTS SOMETHING ABOUT CODE (a gate's presence, a predicate, a field's absence) has an expiry it cannot see — grep the code before relying on one, and always before citing it to justify REMOVING a control. Code wins on facts; only the founder decides which document changes. Supersede the stale entry with a dated one quoting the verified code, never delete it silently.

- A verifier's RED COUNT fingerprints the bytes it READ — when a claimed defect contradicts the code, revert the fix and check whether the claimed signature reproduces exactly; a match proves the reporter sampled stale content (and indicts every other claim from that run), which beats "the claim is false".
- Two samples cannot attribute a NONDETERMINISTIC failure: establish determinism first (does it fail in isolation? every time?), then run N>=5 per tree and compare RATES. A strict `isAfter` between two wall-clock stamps is a same-tick coin flip — recognisable before running anything.
- A test fixture must CONTAIN the pattern it claims to guard, and must clear every length/shape precondition on the path it means to exercise — three vacuous tests shipped as coverage in one sprint ('paprika.' and 'kanel' have no "ca" in them; "Råg:" is too short to reach the guarded branch). Always mutation-test a negative assertion.

## Architecture

- `BaseViewModel.executeAsync` fails LOUD (throws `StateError`) on a disposed VM BY DESIGN — its non-nullable `Future<T>` can't return a fake `null`; the fail-silent siblings differ only because their return types allow it. Don't "harmonise" it; guard callers with `if (isDisposed) return;` (BUT-1462, sweep in BUT-1628).

## UI/UX

- Heuristic/LLM-derived visible content (headings, tags, parsed amounts) ships WITH its correction UI in the MVP — "display now, correct later" is never a valid phasing.

## Language and Firebase gotchas

- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds `(?<![a-zåäö0-9])`/`(?![a-zåäö0-9])`, and pin å/ä/ö-boundary cases in tests.
- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index (filter field first, aggregated field included); `count()` doesn't. In-memory fakes can't catch it — assert the declared index config in a test.
- A FAILED_PRECONDITION's `create_composite` token base64url-decodes to Firestore's OWN index spec — decode it before trusting any description of the cause. `orderBy(documentId(), 'desc')` is NOT index-free (auto single-field covers `__name__` ASC only); declare a one-field `__name__ DESCENDING` entry. The next run then fails with the SAME code 9 but "index is currently building" — poll until READY, don't re-fix.

- A boundary/heuristic/attribution bug usually has a TWIN CLASS — before implementing a single-file fix, grep sibling classes by NAME (not path) and trace which one the view actually calls; the copy under `lib/widgets/` or the legacy sibling is as likely to be the live one. Fix both in one commit or delete the dead one; if the fix must widen past a declared fileset, record it in the deviation log AND name the widened file in the reviewer marker (BUT-1691, BUT-1697/1716).

- A wrong-path Firestore read is a bug CLASS, not an instance — a wrong collection, a wrong field name and a filter on a non-existent field are all "syntactically perfect query, throws nothing, matches zero", invisible to the analyzer and happily seeded by a fake. When one is found, enumerate every reader AND writer of that collection (grep the CONSTANT, not the literal) and check each against `firestore.rules`: a path with no `match` block is denied, not merely undocumented. Highest risk where emptiness looks normal — exports, deletion cascades, analytics probes, any caller that swallows `permission-denied` (BUT-1724 was graded Done while four more instances of its own disease were live, incl. an Art. 15 export that has never returned a message and an Art. 17 cascade that has never deleted one).
