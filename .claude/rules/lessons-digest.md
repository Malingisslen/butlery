# Lessons Digest — core (auto-loaded)

One line per lesson in `tasks/lessons.md`; the full entries there are the deep reference.
**Sync contract (CLAUDE.md rule #9):** every new lesson gets its one-liner in the same edit.
A Stop-hook tripwire counts the lines across all digest files and warns when they drift.

Routing — put a new line in the file that matches when it is needed:
`lessons-digest.md` (here) for anything that binds any session; `lessons-digest-delivery.md`
for sprint, Linear, worktree and ship-pipeline lessons; `lessons-digest-testing.md` for
lessons that only matter while writing or running tests.

## Workflow

<!-- Four commit-retry lessons (formatter race reverting code but keeping comments;
     `git commit -- <pathspec>` dropping new files; never detaching past a slow gate;
     a gate that cannot be satisfied) are NOT here. They live in the commit gate's own
     block message, which fires at the moment they bite — no digest trigger detects
     "is committing". Shipped 2026-08-17 in workflow-guards/require-review-before-commit.mjs.
     Do not re-add them here; you would pay for them every session and still not be
     holding them at the retry. -->

- An audit agent's claim about a tool's OUTPUT FORMAT is a guess until reproduced — run the real tool and test the regex against a real line before "fixing" a parser.
- Feedback right after a deliverable may target the TOOL/process, not the one artifact — disambiguate "fix this output" vs "improve the capability" before acting.
- A multi-part agreed initiative gets ONE written plan before any slice ships — chat scrollback is not a backlog.
- Every proposed improvement must name its mechanical trigger; upgrading an optional command is convenience, not infrastructure.
- Never prune a young system for inactivity — the observation window must exceed its natural cycle (tune now; keep/cut only after 2–3 cycles).
- Don't hand the user judgment/labor you can derive yourself; defer only product intent, irreversible actions, or external facts.
- Bash `cd` persists across calls — use absolute paths.
- A 403 naming a permission can be a WRONG-IDENTIFIER bug, not a credentials bug — a project's display NAME and its real id can differ. Resolve the identifier against `.firebaserc`/`projects:list` BEFORE touching credentials, and before sending the user to fix their account.
- A hook on a RELATIVE path stops firing once Bash cwd drifts into a subdirectory, and a PreToolUse failure is NON-BLOCKING — so the safety firewall silently lets destructive commands through. Wrap every hook command with `cd "$(git rev-parse --show-toplevel)"`, and never weaken a firewall pattern that also matches commit-message prose.
- Verify Edits actually landed (`git diff`) before committing — never trust the commit-message claim.
- A multi-edit script that asserts before its single write loses EVERY edit when one search string is wrong — even the matched ones, and comment-only edits fail SILENTLY (no test, no analyzer). Grep the changed TOKEN and paste the count after any edit with no test.
- "Unreferenced" must be proven against the WHOLE repo, never a hand-picked subset.
- Run arch gates locally before committing UI widgets.
- When the user asks for a new mode, deliver ONE mode — no "normal + extra", no spare variants.
- "Map the workflows" means full coverage against a stated universe — never silently curate a sample.
- When citing a deterministic tool's verdict (router tier, gate, test), RUN it and paste output — never assert what it would say.
- A subagent naming a file as "the X path" proves existence, not routing — read the client orchestrator's tier/fallback structure yourself before asserting what runs first (cost/privacy claims always get direct verification).
- `curl` is a DIFFERENT CLIENT from the app — its 403/empty page is not your feature failing. Reproduce through the client the feature actually uses (headless browser, real UA, JS on) before calling a site blocked. A page-classifying probe needs TWO independent markers or it measures the crawler (BUT — 2026-08-01).
- A blocked gate is a STOP, not a puzzle to route around — never forge a marker; a marker's mtime proves a touch, so read its CONTENTS against the current diff before trusting a gates:ok.
- A new source file can land as a git binary blob — verify `file` says "text" before committing.
- A registry/structural lint that reddens on a given day is usually pointing at that day's DELETION commit, not at itself — date the first red run, `git log -S <symbol>`, and never allowlist a constant to clear a coverage lint.
- "It's the tooling, not the app" is a CLAIM, not a default — name the mechanism and show the measurement before writing it. Two symptoms appearing together is not evidence of one cause; a workaround that FAILS is data — `pointer-events:none` not fixing a click means the listener is on an ANCESTOR (BUT-1837).
- A blank white page under `flutter run -d web-server` is usually DWDS, not your code — debug mode holds `main()` until the Dart Debug Chrome extension connects, no console error. Call `window.$dartRunMain()` from the console to boot instantly instead of restarting the dev server (2026-08-13).
- Adding a CALLER changes the callee, even untouched — `tryClearRoster`'s logs were safe with UUIDv4-id callers, then leaked two raw uids once a deletion cascade passed `direct_<uidA>_<uidB>`. Check a callee's logs/bounds/errors against a NEW caller's inputs — a doc ID can be PII no `hasOnly` sees, and a mutant that fails to COMPILE is not a red test (BUT-1822).
- An ARB edit rewrites the WHOLE file (a hook re-serialises the JSON), so `git diff` can't show whose changes are in it. Compare KEY SETS against `git show HEAD:<file>` as JSON before staging any shared generated file (BUT-1783).
- A subagent's transcript file is NOT a liveness signal (0 bytes + stale mtime is normal mid-run — it flushes on completion); only the completion notification proves an agent finished. Wait in few LONG background sleeps, not many short holds.
- A comment about code has a HALF-LIFE — the change that falsifies it is usually YOURS, one commit later. A sentence naming a mechanism in another file is a DEPENDENCY: grep its name when you change that file. State the RULE and its consequence, not the current mechanism (BUT — layout seam, 2026-08-05).
- A comment is an UNTESTED ASSERTION — the compiler ignores it, tests don't exercise it, a future reader trusts it most. Before writing "X does not exist", grep for X; before "behaviour unchanged", diff against `git show HEAD:<file>`, not memory (BUT-1786).
- A deploy that DELETES many Cloud Run services can leave its replacement `"state":"FAILED"` while `firebase deploy` exits clean and `functions:list` still shows it BY NAME — verify per-function `state` from `--json` after any deploy that removes services (BUT — 2026-08-03).
- An invisible codepoint makes correct code read as broken — byte-check a suspicious bound (`cat -A`, `grep -P`) against real data before trusting a visual read. When a ticket claims a guard test is missing, MUTATION-TEST the existing suite first — the alarm often already exists (BUT-1690).
- Context-diet's four-mechanism retirement ranking (gate message > agent/skill body > `paths:` frontmatter > never description-alone) and its proof step now live in the `/context-diet` skill body itself — don't re-derive them here.
- "I read very little of what you reply" is a CONFIG bug first — grep the always-on setup (output styles, SessionStart plugins, stale model-tuning blocks) before apologising in prose; fix the mechanism (`~/.claude/output-styles/`) and delete the conflicting prose in the same edit.
- A decision record that ASSERTS SOMETHING ABOUT CODE has an expiry it cannot see — grep the code before relying on one, especially before citing it to justify REMOVING a control. Supersede a stale entry with a dated one, never delete it silently.
- A verifier's RED COUNT fingerprints the bytes it READ — when a claimed defect contradicts the code, revert the fix and check whether the claimed signature reproduces exactly; a match proves the reporter sampled stale content (and indicts every other claim from that run), which beats "the claim is false".
- Two samples cannot attribute a NONDETERMINISTIC failure: establish determinism first (does it fail in isolation? every time?), then run N>=5 per tree and compare RATES. A strict `isAfter` between two wall-clock stamps is a same-tick coin flip — recognisable before running anything.
- A sentence about code in ANOTHER file is a claim with a verification cost — pay it before writing. Which methods a class HAS is settled by its DECLARATION line, not the base class's source; "nothing does X" must grep dead code too. When a reviewer disproves one claim, re-read every other claim in the file (BUT-1819).
- A model field that reaches Firestore is a RULES change too — `hasOnly` fails CLOSED in silence. A field added without touching `firestore.rules` once denied EVERY recipe write for three weeks, unnoticed. Grep `firestore.rules` for the validator in the SAME edit you add a field, and give every `hasOnly` allowlist a rules test (BUT-1482).
- Editing an ARB after `flutter gen-l10n` has run ships the OLD string — the generated file keeps it and `dart analyze` compiles it happily. Re-run gen-l10n and grep the generated file for the changed substring after every ARB edit (BUT-1693).
- A rules block that ATTESTS on a parent document must first establish WHERE and WHEN that parent is written — `get()`-checking a parent that materialises later (e.g. on first message) denies creation permanently. Shape: `attested || unclaimed` (parent names you, OR parent absent), proven against the writer's REAL WriteBatch (2026-08-12).
- "Not a live bug" is a claim about CALLERS, not about a nullable fallback — an unreachable default at one call site doesn't mean no path produces the bad value. Trace UP from the WRITE (grep the writing method, then each caller), never down from the field's own default (BUT-1849).
- A source edit made THROUGH another language inherits ITS escape rules: `\b` in a Python heredoc writes a literal BACKSPACE into a Dart comment, compiler-invisible — 4x in one commit, in 4 files. Use `chr(92)+'b'`, then `grep -rlP '[\x00-\x08]' --include='*.dart' --include='*.ts'`; baseline is ONE file, `ocr_extraction_service_test.dart` (2026-08-19).
- Python and Git Bash resolve `/tmp` to DIFFERENT dirs on Windows, so a Python writer plus a bash reader compares against a STALE file, and CRLF from `gcloud` makes `comm` see no overlap. Compare sets in ONE language, strip CR, `mktemp -d`. Complements that do not add up mean the INPUTS are wrong (2026-08-17).

## Architecture

- `BaseViewModel.executeAsync` fails LOUD (throws `StateError`) on a disposed VM BY DESIGN — its non-nullable `Future<T>` can't return a fake `null`; the fail-silent siblings differ only because their return types allow it. Don't "harmonise" it; guard callers with `if (isDisposed) return;` (BUT-1462, sweep in BUT-1628).
- A global `Shortcuts` layer in `MaterialApp.builder` sits BELOW `DefaultTextEditingShortcuts`, so it beats the framework for a focused field — a bare Backspace→back binding stopped every text field from deleting, for months, behind a comment claiming the opposite. Bind only chords, or make the action DISABLE itself in an `EditableText` (BUT — login password field, 2026-08-07).

## UI/UX

- Heuristic/LLM-derived visible content (headings, tags, parsed amounts) ships WITH its correction UI in the MVP — "display now, correct later" is never a valid phasing.
- A `Semantics` node's RECT isn't guaranteed to match its widget's paint bounds — `FeedbackFAB`'s node measured the full viewport, so every tap opened the feedback dialog instead (BUT-1837). `main.dart` forces semantics on every web start, so a malformed node breaks browser automation and screen-reader users identically.

## Language and Firebase gotchas

- Dart RegExp `\b` is ASCII-only — bound Swedish tokens with explicit lookarounds `(?<![a-zåäö0-9])`/`(?![a-zåäö0-9])`, and pin å/ä/ö-boundary cases in tests.
- Firestore `sum()`/`average()` with a filter on a DIFFERENT field needs a COMPOSITE index (filter field first, aggregated field included); `count()` doesn't. In-memory fakes can't catch it — assert the declared index config in a test.
- A FAILED_PRECONDITION's `create_composite` token base64url-decodes to Firestore's OWN index spec — decode it before trusting a description of the cause. `orderBy(documentId(), 'desc')` needs a declared `__name__ DESCENDING` index; the retry then says "index is currently building" — poll, don't re-fix.
- A boundary/heuristic/attribution bug usually has a TWIN CLASS — grep sibling classes by NAME (not path) and trace which one the view actually calls; a legacy sibling is as likely to be live. Fix both in one commit or delete the dead one (BUT-1691, BUT-1697/1716).
- A harness picking between two on-disk shapes for the same fact must choose on the property that decides TRUTH (which is `verified`), never on which FILE EXISTS — existence is a side effect of production, and the loser drops silently (BUT — corpus split eval, 2026-08-05).
- A wrong-path Firestore read is a bug CLASS, not an instance — wrong collection, wrong field, or a filter on a non-existent field all look like "matches zero", invisible to the analyzer. Enumerate every reader AND writer of a collection (grep the CONSTANT) against `firestore.rules` — no `match` block means denied, not undocumented (BUT-1724).
- "Affected users" is a CLAIM WITH A TIMESTAMP — a bug's shape can suggest a population that dies to one timestamp check. Date the window at both ends and check live status before any sentence about who is affected (BUT-1846).
- A correction to a false comment can be false again in a new QUALIFIER — true per verb/caller/purpose/fixture but not universally. Before writing "every/no/nobody/nothing/only", name what it quantifies over and check each value; grep the phrase across the WHOLE tree, including `__tests__` (BUT-1838).
