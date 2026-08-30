# Session Lessons

Learnings from corrections and from problems that took more than one attempt. Newest first.
Every entry has a one-liner in a digest under `.claude/rules/` — the digest is what loads
into a session; this file is the deep reference behind it (CLAUDE.md rule #9: lesson and
digest line ship in the same edit).

<!-- HEADING LEVELS ARE LOAD-BEARING. The drift tripwire in knowledge-freshness.mjs counts
     `^### ` as one lesson each, so a lesson at `## ` is invisible to it and a sub-section
     at `### ` is counted as a lesson. One lesson = `### `. A sub-section inside one = `#### `. -->

Shape of an entry: `### Title`, then `Date:`, `Trigger:`, `Rule:`, `Example:`. Keep it under
about fifteen lines — the retelling is not the lesson, the rule is. A new entry goes at the
TOP of Current, never appended to the end of the file. Entries drop into Archived once the
rule is internalised (roughly six weeks).

## Current

### [Testing] A mutation probe's SUITE SET is part of the probe, and a fake's stub can lie by matching nothing

- **Date**: 2026-08-30 (BUT-1971 follow-ups)
- **Trigger**: two comments written in the same hour, each measured false by the reviewer who read them. Both were counterfactuals about mutants I had run.
- **Rule (probe scope)**: a mutation probe run against only the file you just wrote measures that file, not the claim. Mine said "raise the Dart cap and every suite stays green"; the service suite reddens too. Run the probe over the directory, not the file — this is the same "verification set chosen by the files you EDITED" trap this ticket already paid for once, arriving the second time as a COMMENT rather than a missed red suite.
- **Rule (fake stubs)**: `admin.firestore.FieldPath` HAS a `.split` method, so `(field as string).split(".")` on one does not throw — it returns `["", ""]`, reads `data[""]` as undefined, and a faithful `!=` matcher then excludes the document. The fake matches ZERO and reports a clean store over live data. Before writing that a mis-typed stub "throws and lands in the catch", run the two lines that check: does the object have the method, and what does the matcher do with the value it returns. A silent zero and a throw are opposite failures — one is a false all-clear, the other a false alarm — and only one of them a clean-store control can see.
- **Corollary**: after a reviewer strikes one such sentence, the replacement is where the next false one lands. Both of mine were struck twice before the third wording said only what was measured. On the second failed repair, delete the clause rather than attempt a third.


### [GDPR] Before designing a new field's erasure, ask whether the field is a second copy
- **Date**: 2026-08-30 (BUT-1971, the provenance build)
- **Trigger**: the blind DPO critique returned the panel's only blocking finding — a uid inside `metadata.poll.options[]` is an array of maps Firestore cannot query, so it would have been structurally unerasable. Both remedies I then sketched were real work.
- **Rule**: before designing storage or erasure for a new attribution field, grep every construction site of the thing it attributes and ask whether any path can make the new field differ from a field that already exists. Here there were three sites and the answer was no — a poll option's proposer is ALWAYS `metadata.poll.creatorId`, which is flat, queryable and already scrubbed. The check is minutes; the erasure design it removes is a day. A finding that dissolves this way is still a good finding: it forced the question.
- **Corollary**: where two variables must hold the same value on the only live path, pass them separately anyway and say they are equal TODAY, measured — never imply a test proves the distinction, because none can.

<!-- Full narrative, kept because the two remedies I nearly built are the expensive half:
The plan added `PollOption.proposedBy` so a menu dish could say who suggested it. The DPO's
blind critique returned the panel's only blocking finding: a uid inside
`metadata.poll.options[]` is an array of maps, which Firestore cannot query
("does any element have field X == uid"), so it would be **structurally unerasable** — the
exact bug class the repo had already paid to fix once, when BUT-1832/1835 moved `voterIds`
out to a `poll_votes` subcollection for that reason. The finding was correct and the plan
had not mentioned the `messages` collection at all.

Both remedies the plan then sketched were real work: mirror the subcollection, or add a flat
`array-contains`-queryable sibling field for the cascade to find.

Neither was needed. Every option in a poll is built by ONE person in ONE
`Poll.fromOptions(creatorId: ...)` call, and no path adds an option afterwards — so an
option's proposer is ALWAYS `metadata.poll.creatorId`, a flat field that already exists, is
already queryable, and is **already scrubbed by the cascade**. The new field would have been
a second copy of a fact the document already held, which is the drift `accepted-deviations.md`
records having removed once before (`sharedWithUserIds`, BUT-1798).

Two things worth keeping:

**The cheap check comes first.** Before designing storage or erasure for a new attribution
field, grep every construction site of the thing it attributes and ask whether any path can
make the new field differ from a field that already exists. Here there were three sites and
the answer was no. That question is minutes; the erasure design was a day.

**A dissolved finding is still a good finding.** The DPO was right about the hazard, and the
hazard is what forced the question that removed the field. Do not record this as "the panel
was wrong" — record it as the panel catching a defect early enough that the fix could be
subtraction.

Corollary now written into the code: because the closer of a poll must be its creator, the
actor and the proposer hold the same uid on that path, so no test can tell "read the right
variable" from "read the wrong one with the same value". The value is passed as its own
argument anyway, so the seam exists the day that gate widens — and the comment says they are
equal today, measured, rather than claiming the distinction is proven.
-->


### [Workflow] `git status` says WHAT changed, never BY WHOM — ownership is not derivable from a shared checkout
- **Date**: 2026-08-26 (four times in one night, five sessions sharing `C:/Butlery/butlery`)
- **Trigger**: Four ownership claims, each built on a correct measurement.
  (1) A worktree under `.claude/worktrees/` sat on a BUT-1911 commit, so a session was
  told its tree "stands on BUT-1911". The worktree was real and the SHA was right; it
  belonged to nobody asking.
  (2) Four files staged at session start were read as "my BUT-1912 work" and reported to
  the founder as this session's only owned ticket. They were another session's, recovered
  from the same sprint patch — so the content matched, which made the wrong conclusion
  look confirmed.
  (3) A reviewer warned a session that "your uncommitted set spans `firestore.rules` and
  six files under `functions/src/`". Those 29 files were a third session's BUT-1904 work,
  identifiable in one `git status` read by their own subject matter (an ADR named for the
  feature, a duplicate-guard test).
  (4) **While writing this entry**, its author attributed 15 staged files and two commits to
  the session that had just been corrected in (1)–(3) — they belonged to a fourth session
  mid-commit. The lesson did not inoculate the person writing it, in the same hour.
- **Rule**: In a shared checkout, `git status` / `git diff` / the index are facts about the
  TREE and carry **no author information at all**. Provenance exists in exactly three places:
  commit metadata, a session's own log of what it edited, and asking the session. Subject
  matter (an ADR title, a ticket-named test) identifies the TICKET, not the session — useful
  for routing a warning, never proof of who is holding the file. The failure is silent in
  both directions: it strands work nobody claims, and it invents work nobody did. Two
  corollaries that bit the same night: a peer's ownership claim about YOUR tree deserves the
  same check before you accept it, and content matching a patch proves shared ORIGIN, not
  authorship. This is the wrong-object shape of the entry below, aimed at the one question a
  repo full of parallel sessions asks hourly.

### [Workflow] A check run correctly against the wrong object is indistinguishable from a clean bill of health
- **Date**: 2026-08-26 (BUT-1921, and twice more the same day)
- **Trigger**: Three separate wrong answers in one session, all the same shape.
  (1) I reported all nine sprint patches "apply cleanly" on the strength of
  `git apply --check --3way` exiting 0 — but `--3way` exits 0 while writing conflict
  markers, so six of nine actually conflicted. The command ran, the exit code was read
  correctly, and it answered a different question than the one asked.
  (2) BUT-1921 was closed as obsolete by a sprint run, then confirmed obsolete by a
  parallel session, both having verified that the variable IS quoted in `secret-scan`.
  True — but dating the line showed it was quoted since 2026-05-03, three months before
  the error was observed, so `secret-scan` was never the source. Two correct checks, one
  innocent file, and a live bug left standing.
  (3) A reviewer stated a global maximum ("the deepest emission is 20 fraction digits")
  measured with a probe that replicated only one of the function's two emitting branches.
  The other branch reaches 22.
- **Rule**: A wrong check is easy to spot; a right check aimed at the wrong object is not,
  because everything about the execution looks correct. Before trusting a green result, ask
  what the check's OUTPUT actually ranges over, not whether it ran: does this exit code
  distinguish the failure I care about (`--3way` does not), is this the file the symptom
  came from (date the line against the observation), does this probe reach every branch that
  can produce the value (enumerate them from the source first). When a verdict and a symptom
  disagree, the verdict is usually measuring something adjacent — find what it measured
  before concluding the symptom was stale.

### [Workflow] A config artefact in the wrong SHAPE is dead, silently, forever
- **Date**: 2026-08-22
- **Trigger**: `/doctor` found two guardrails that had never once run. `.claude/skills/*.md` were flat files — Claude Code loads project skills only from `.claude/skills/<name>/SKILL.md`, and `.claude/commands/<name>.md`; a flat file in the skills dir is ignored with no warning. Fourteen of them, dead since 2025-11-24 (~9 months), while `CLAUDE.md`, four rules files and `safety-skill-trigger.sh` all pointed at them by name — including `tri-state-validator`, whose job is to stop Claude calling a recipe gluten-free. Separately, the user-scope force-push `PreToolUse` hook was a `jq` pipeline on a machine with no `jq`: 8,522 fires in one day, zero decisions, because a failing PreToolUse hook is non-blocking.
- **Rule**:
  1. **Existence is not liveness.** Proof that a skill/command/hook is wired is a non-zero `skillUsage` entry in `~/.claude.json`, its presence in the session's skill listing, or a recorded hook decision — never the file being on disk. "Nothing warned me" is the expected symptom of this bug, not reassurance.
  2. A hook whose **interpreter is missing** fails exactly like a hook that decided "allow". Check the interpreter exists before trusting any hook you did not just watch fire.
  3. `.claude/settings.json` is **not** the full hook picture — enabled plugins contribute hooks from `<plugin>/hooks/hooks.json`, invisible to any repo-only search. Butlery's "8 hooks on Write|Edit" is really 11.
  4. Origin matters when you write the history down: commit `f52d81b17` deleted 12 nested `SKILL.md` files, but it was an indiscriminate hygiene sweep that also deleted a committed `node_modules/` and an `esbuild.exe`. **It was not a verdict against the nested shape.** The flat files were a reintroduction after an accidental deletion. Do not cite that commit as a design decision.
- **Example**: The fix was `git mv` of 14 files into `.claude/commands/` — the shape this repo had already migrated seven siblings to (`3cbd57e2e`, `c6d9d7efe`) for this exact reason. The eleven model-invocable ones appeared in the live session listing the moment the files moved; the three carrying `disable-model-invocation: true` correctly did not.
- **Files**: `.claude/commands/*.md` (14 moved), `~/.claude/hooks/git-force-guard.py` (new), `~/.claude/settings.json`, `.claude/rules/automation-proposals.md`, `tools/gen_role_paths.py`, `docs/architecture/ROLE_RESPONSIBILITY_MAP.md`, `docs/onboarding/butlery-academy{-dossier.md,.html}`

### [Workflow] Repointing a path in a GENERATED file is a fix with a 7-day fuse
- **Date**: 2026-08-22
- **Trigger**: The plan for the move above said "repoint `docs/org/role-paths.json:307-308`". A stakeholder-review archaeology pass caught it: that file's own header says *"Generated by tools/gen_role_paths.py … Do not hand-edit; re-run the generator"*, and `/refresh-dossiers` regenerates it as step 0 of the weekly `/janitor`. The hand-fix would have silently reverted within a week.
- **Rule**:
  1. Before editing any config/data file, **read its first three lines** for a generated-by banner, and fix the SOURCE plus re-run the generator instead.
  2. Regenerating surfaces drift you did not cause — the committed `role-paths.json` still claimed `.claude/commands/janitor.md`, a file that had moved into a plugin. Diff the regenerated output and say which changes are yours and which were already stale; do not silently absorb the difference.
  3. **Check what a derived glob would newly claim.** `gen_role_paths.py` auto-derives `<parent>/**` unless the parent is in `GENERIC_DIRS`. Repointing one Evidence token at `.claude/commands/` would have handed one role all 22 command files, half of them another role's — a *new* bug introduced by the repair. `.claude/commands` had to join `.claude/hooks` and `.claude/rules` in `GENERIC_DIRS` first.
- **Example**: Verified by regenerating twice, with and without the `GENERIC_DIRS` line, and diffing: without it, `.claude/commands/**` lands on a second role. The exemption's real cost — no role stales on command-file edits at all — is the same trade already made for `.claude/hooks` and `.claude/rules`, and is stated rather than hidden.
- **Files**: `tools/gen_role_paths.py`, `docs/org/role-paths.json`, `docs/architecture/ROLE_RESPONSIBILITY_MAP.md`

### [Testing] A `Fake` fixture inside a fail-open catch makes the test measure the CATCH
- **Date**: 2026-08-22
- **Trigger**: BUT-1909's display-path test asserted that a blocked voter is stripped from a poll tally. It failed, showing the voter still present — and the fail-open sibling case beside it passed. Both were consistent with "the filter was never found", which is where I looked first. The real cause was two layers down: the fixture used the suite's own `FakeMessage`, and `_stripBlockedBallots` rebuilds the message with `copyWith`. A `Fake` throws on any member it does not implement, that throw landed in `_filterBlocked`'s deliberate fail-open `catch`, and the service served the page unfiltered. The test was measuring the catch.
- **Rule**:
  1. When the code under test is wrapped in a fail-open `catch`, a fixture that throws is INDISTINGUISHABLE from the feature not running. Use the real model type, not a `Fake`, for anything the production path calls a method on.
  2. A fail-open test and its fail-closed sibling behaving "consistently with X" is not evidence for X — enumerate every state consistent with the pair before diagnosing.
  3. Same suite, second trap: `TestServiceLocator.initialize()` deliberately SKIPS the production `ServiceLocator`, so `ServiceLocator.tryGet<T>()` reads a null container and returns null for everything. A group that needs `tryGet` must stand up its own `ServiceLocator.initialize(DIContainer())` in `setUp` — and until it does, the service never finds the collaborator at all.
- **Example**: `test/unit/services/messaging_service_test.dart`, group "blocked ballots on the read path (BUT-1909)". Both fixes were needed. A third round then measured my own account of it and struck two consequence clauses as overstated — the strip case goes RED without the bridge rather than green, and no case in the group both passed and asserted the opposite. The mechanism was right; the blast radius I claimed for it was not.
- **Files**: `test/unit/services/messaging_service_test.dart`

### [Testing] Inserting a test falsifies any comment above it that counts the tests
- **Date**: 2026-08-22
- **Trigger**: A BUT-1910 review round told me two of three new pantry cases were CONTROLS, green on pre-fix code. I wrote that in the block banner: "Only the 1,5,5 case discriminates; the other two are CONTROLS." The NEXT round's blocking finding added a fourth case below it — which is also a discriminator — so "only" and "the other two" were both false, in the same comment block whose neighbouring clause the previous round had struck for the same reason.
- **Rule**:
  1. A comment that quantifies over the tests below it has an insertion seam, and the next legitimate test is what breaks it. Name the LITERALS instead ("the 0,5 and ,5 cases are controls") — a literal survives an insert; a count and an "only" do not.
  2. This is the "every number must be measured" family, but the failure mode differs: the number was correct when written and was falsified by your own later work, not by drift.
  3. When a review round makes you ADD a test, re-read the comments above the insertion point before finishing the round.
- **Example**: `test/widget/views/pantry/add_pantry_item_sheet_test.dart`, the BUT-1910 banner. Two other counts in the same file — "Four contracts" and "Two disclosed reads of internals" — were falsified by the same batch and struck rather than renumbered.
- **Files**: `test/widget/views/pantry/add_pantry_item_sheet_test.dart`

### [Testing] A widget test finds nothing when the form body is a lazy list
- **Date**: 2026-08-22
- **Trigger**: A new widget test for the recipe rating field reported "Bad state: No element" on a finder that was correct. The form body is a `ListView`, so the field is not built until it is scrolled near — only two `TextFormField`s existed in the tree at all. The failure reads exactly like a missing widget or a wrong label.
- **Rule**: Before concluding a finder is wrong, count how many widgets of that TYPE the tree holds. A lazy `ListView`/`CustomScrollView` needs `scrollUntilVisible` first, and that belongs in a named helper so the next case cannot forget it. Second gotcha from the same file: a field seeded with `initialValue` has a NULL `TextFormField.controller` — read its text off the descendant `EditableText`, which also survives a later conversion to a controller.
- **Example**: `test/widget/views/recipe_form_rating_field_test.dart` — `revealRatingField` / `revealEditRatingField`.
- **Files**: `test/widget/views/recipe_form_rating_field_test.dart`

### [Delivery] A shell gate's cost is PROCESSES, not the grep
- **Date**: 2026-08-22
- **Trigger**: BUT-1894 — `real-time-guard` cost 646-859 s on every commit that staged a test file, three times the cost of analyzing the whole project, while the comment beside it promised "sub-second". The ticket blamed a full-tree search and prescribed scoping to the staged files.
- **Rule**:
  1. Measure the SEARCH and the LOOP separately. Both greps here finished in about 0.4 s; `DateTime.now()` matched over a thousand lines, and each match spawned an `awk` plus an `echo|sed|sed|grep` pipeline — roughly four processes per hit, some four thousand per commit. Process creation is the expensive primitive on Windows, so the fix is one `awk` pass per check, not a narrower grep. Scoping was right and worth about a tenth of a second.
  2. `set -euo pipefail` turns `grep`'s exit 1 ("no matches") into a pipeline failure. Read the status explicitly and separate 1 from >1, or the gate refuses every clean commit.
  3. A gate with no fixtures cannot be rewritten safely — that is how a previous rewrite claiming byte-identical behaviour reached review while failing OPEN on two inputs. Write the fixtures before the rewrite, and put a binary `*_test.dart` among them: `grep` prints "Binary file X matches" with no line number, and silently dropping an unparseable line is the fail-open shape.
- **Example**: 859 s to 0.52 s over the whole tree, 0.24 s measured on a real commit. Fifteen fixtures at `scripts/__tests__/check_test_real_time_test.sh`, wired into lefthook and CI.
- **Files**: `scripts/check_test_real_time.sh`, `scripts/__tests__/check_test_real_time_test.sh`, `lefthook.yml`, `.github/workflows/test.yml`

### [Delivery] A ticket's REMEDY can be refuted while its problem stands
- **Date**: 2026-08-22
- **Trigger**: BUT-1906 asked for the dietary badge row in the recipe grid card and prescribed the fix: if it does not fit, raise `_gridAspectRatio`. Building it overflowed the tile at every text scale — and raising the aspect ratio changed NOTHING, measured at 0.75 / 0.70 / 0.66 / 0.62. The constraint the ticket named was height; a ratio buys height, and the tile was already documented as needing an absolute `mainAxisExtent` instead.
- **Rule**:
  1. Step 0 checks the PROBLEM's premise. Check the REMEDY's premise too, and check it by MEASUREMENT rather than by reading — a prescribed fix that cannot work looks exactly like a fix that has not been tried yet.
  2. A stakeholder's alternative is also a premise. The Creative Director offered icon-only badges for spatial parity; that option did not exist, because the badge picks its icon from the STATUS, so two different diets render the same icon.
  3. When every named remedy is refuted, ship NOTHING and hand back the measurements. A reverted branch plus three numbers is a better deliverable than a silent 23px clip.
- **Example**: BUT-1906 parked In Review, blocked by BUT-1911, with the four aspect-ratio measurements in the ticket.
- **Files**: `tasks/todo.md` (deviation log)

### A shared choke point makes OTHER files' tests vacuous, and only a whole-diff read sees it (2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: Six single-file reviewers passed a PII change. The integration pass then found
  three things none of them could see. (a) The exception classes were fixed to keep their TYPE
  LABEL outside the mask — and the web sink, a different file, re-applied the mask over the
  whole string and ate the label again. (b) Two pre-existing tests in *untouched* files became
  unfailable: once the class masks itself, deleting the per-throw-site mask reddened nothing,
  while their comments still boasted the opposite. (c) Widening a regex anchor turned rule
  ORDER into a correctness dependency that no file recorded.
- **Rule**: When a fix moves a rule into a shared place, three questions are cross-file and a
  per-file reviewer cannot answer any of them: which OTHER callers now apply the rule where
  they did not, which existing tests are now held up by the new central rule instead of the
  thing they claim to pin, and did a widened pattern make some ordering or precedence
  load-bearing. Run a whole-diff pass, and when centralising, re-probe the tests of every
  caller — a green suite in an untouched file is the evidence that goes stale silently.
- **Files**: `lib/services/monitoring/web_error_reporter.dart`, `lib/core/utils/log_sanitizer.dart`

### Seven review rounds, and every block was a sentence I wrote, not code (2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: A four-ticket sprint went through seven specialist rounds. Four rounds blocked.
  Not one block was about behaviour — every single one was a MEASURED or CAUSAL claim in a
  comment that the code contradicted: "the most throw sites of the family" (measured 20 vs
  90), "roughly fifty throw sites" (173), an MFA field cited as protected by a default it
  never touches, "an empty set is what an opted-out user reaches the card with" (they reach it
  with null), a fabricated re-confirmation date, and a positional claim ("three lines from")
  that pointed at nothing. Two of those were themselves CORRECTIONS of an earlier wrong
  sentence.
- **Rule**: Treat every number, "most/every/only", causal "because", and provenance date in a
  comment as an assertion that must be MEASURED before it is written — `grep -c` it, or do not
  write it. Prefer the rule over the evidence: "`details:` is where callers put an id" needs no
  maintenance; "this class has the most throw sites" rots and misleads. And when a reviewer
  disproves one sentence, re-check every other sentence in the same edit — the repair is as
  falsifiable as the original, and here it was wrong twice.
- **Example**: Cheapest guard found: before writing a comparative, run the count for EVERY
  member of the set, not just the one being described. Two minutes; it would have caught three
  of the six.
- **Files**: `tasks/lessons.md`, `.claude/rules/lessons-digest.md`

### A mutation probe's restore can silently revert an unrelated fix (2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: A comment fix landed and its assertion passed. A later mutation probe on the
  SAME file backed up, mutated, and restored from a backup taken BEFORE that fix — quietly
  putting the false sentence back. It was caught only because a reviewer grepped for the
  claim after I had "already fixed" it.
- **Rule**: A probe's backup is a snapshot of a moment, so take it immediately before the
  mutation and never reuse one across edits. After any probe, `git diff` the probed file and
  confirm it holds the CURRENT intended content, not merely that it is unchanged since the
  backup. And verify a removal against `git show :<path>` — the index is what commits, and a
  worktree fix that never reached it looks identical to a fix that did.
- **Files**: `lib/core/exceptions/permission_exceptions.dart`

### A ticket's stated harm can be REFUTED, and the source is often a comment (BUT-1883, 2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: BUT-1883 specified a guard: stop `closePoll` acting on a poll whose votes were
  never loaded, because it "resolves to the first option and writes the wrong recipe into the
  week's plan". Neither half is reachable. `closePoll` re-reads the single message on a path
  the 20-poll cap cannot touch (`.take(20)` over a one-element list), and `_resolveWinner`
  returns null once every option reads zero. The ticket was written FROM two comments in
  `message_query_module.dart` that asserted both, and both were false.
- **Rule**: Step 0 has a third outcome besides fits/plan-stale: the premise can be *inverted*.
  When a ticket cites a mechanism, trace the mechanism, not the symptom — and when it turns
  out false, ask what the ticket was written from. A wrong comment does not just mislead a
  reader; it manufactures work, and the work looks legitimate all the way to the commit gate.
  Fix the comment, rewrite the ticket with the measurement, and file the real defect
  separately — do NOT build the specified guard to close the ticket.
- **Example**: The real defect was the inverse: the write is correct and the SCREEN lies. A
  capped poll shows "0 röster", the close button is still drawn, and closing then resolves the
  real winner. Filed as BUT-1908; nothing was built under BUT-1883.
- **Files**: `lib/repositories/firebase/modules/message_query_module.dart`

### Masking by SHAPE eats whatever shares the shape, and `\b` is not the boundary you want (BUT-1897, 2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: A rule truncating any 20-28 char alphanumeric run — the shape of a Firebase uid —
  was applied to an exception's whole `toString()`. `PermissionDeniedException` is 25 characters,
  so every one of them became `Perm***`. Caught by the existing tests on the first run. Then a
  verifier found the opposite failure: `\b` counts `_` as a word character, so a COMPOSITE id
  (`<uid>_2026-W34`, which is literally how a weekly menu plan is keyed) never matched at all.
- **Rule**: A shape-based redaction has two failure directions and you must test both. Keep
  anything that is NOT data outside the masked span (the type label, the frame names in a stack
  trace), and bound the pattern with explicit lookarounds — `(?<![a-zA-Z0-9])…(?![a-zA-Z0-9])` —
  because `\b` silently exempts every underscore-joined id. Ask "what else in this string is
  the same shape as the secret?" before shipping, and name a composite id in the tests.
- **Example**: Also stopped masking web STACK TRACES: hundreds of class names in `lib/` are
  20-28 chars, and on web that reporter is the only sink, so masked frames make the report
  useless. The message is masked; the frames are not.
- **Files**: `lib/core/utils/log_sanitizer.dart`, `lib/core/exceptions/permission_exceptions.dart`,
  `lib/services/monitoring/web_error_reporter.dart`

### Measure the CONTAINER before adding to it — it may already be overflowing (BUT-1895, 2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: The ticket asked for an allergen row in the recipe grid tile. Before writing the
  row I pumped the real grid geometry and found the tile already overflowed its own box by 70px
  at normal text size and 175px at 2x — for every recipe, including a one-word title. In release
  that is silent clipping, no stripes, which is why it had survived unreported.
- **Rule**: When a change adds content to a fixed-size container, measure the container empty
  first. "Add a row" is not implementable into something that already clips, and the honest fix
  is usually the container (make the image the layout's slack; scale the tile with the text),
  not smaller content. A fixed aspect ratio cannot hold text that scales — treat that as a bug
  class, not a tuning question.
- **Example**: A throwaway probe test printing `tester.takeException()` at scales 1.0/1.3/1.5/
  1.75/2.0 gave the numbers in about a minute and became the committed regression test.
- **Files**: `lib/widgets/recipe/recipe_card.dart`, `lib/theme/app_dimensions.dart`

### A formula copied into its own test measures the copy (BUT-1895, 2026-08-20)
- **Date**: 2026-08-20
- **Trigger**: The overflow test hardcoded the tile's aspect-ratio formula because the production
  one was a private function in the view. A verifier flagged it: retune the real formula and the
  test stays green against its own stale number while the real grid overflows.
- **Rule**: A test that re-derives the value under test proves the test agrees with itself. Move
  the function somewhere importable and import it. Doing so also re-runs the test against reality
  — here it immediately failed, because the delegate was reading `MediaQuery` from a context ABOVE
  the override the test installed, so the "2x" cases had been measuring a 1x tile all along. The
  hardcoded copy had hidden that by passing the scale in by hand.
- **Files**: `lib/theme/app_dimensions.dart`, `test/widget/recipe/recipe_card_grid_badges_test.dart`

### Main was red for three unrelated reasons and none of them was a bug (BUT-1905, 2026-08-20)

Three workflows red, up to eight days, zero user impact. `Run Tests` since 08-15, `Build
Validation` since 08-12, `Firestore Rules` since 08-15. Two of the three needed no commit
to break, and the repair was worth less than what the repair uncovered.

1. **A test can go red with no commit behind it.** Six cache tests seeded documents dated
   `2026-05-20` against a 90-day TTL, and `isExpired` reads `clock.now()`. On 2026-08-18 the
   fixtures expired for real and the assertions started reading `null` — correct behaviour
   from the code, a lit fuse from May. The whole 61-commit window was innocent. **Triage
   move: date the first red RUN, then ask whether any commit even lands in that window
   before reading diffs.** A literal past date next to a TTL is a time bomb; derive the
   fixture from the clock, and reserve absolute instants for the boundary tests that pin
   one inside `withClock`.

2. **Two red workflows are not one incident.** `Build Validation` had been red three days
   longer than `Run Tests` and for an unrelated reason (three unformatted test files), but
   arrived described as part of the same failure. Folding them together would have hidden
   the older one behind the newer fix. Date each workflow's first red separately before
   accepting any story that covers both. A third red — `Firestore Rules` — was not in the
   report at all and was found only by asking what else was failing.

3. **A red gate takes its whole chain down with it, silently.** `test:rules:all` is one
   `&&` chain of 41 suites and the failing one was second, so the other 39 never executed —
   in the rules workflow and in the pre-deploy gate alike. The `Rules coverage report +
   new-block gate` step carries no `if: always()`, so it was skipped every run too: the gate
   that catches a new `match` block nobody has asserted on had not fired since 08-15. That
   is the mechanism behind the poll-vote allowlist shipping unguarded on 08-17, one file
   over in the same repair. A chronically red gate is not one dark check, it is every check
   downstream of it, and the count is worth measuring before deciding a red is low priority.

4. **A rules TIGHTENING makes every older DENY test on that path vacuous, and nothing goes
   red to say so.** Two live instances found in one file. BUT-1838 added a membership
   conjunct to `messages` create: the ALLOW test failed loudly (that was the red), but the
   two DENY tests beside it started passing on the missing conversation rather than on the
   age claim they are named for. BUT-1419 had done the same to `recipe_comments` months
   earlier and nothing failed at all — deleting `isAgeCompliant()` from that rule left the
   entire suite green, and it was the repo's only guard on it. **After tightening a rule,
   re-attribute every existing DENY on that path: name the single-variable ALLOW control it
   differs from, and if two variables differ, the deny is over-determined and proves
   nothing.** Emulator output cannot tell you — every deny prints an interchangeable
   `PERMISSION_DENIED` naming a rule line, not a reason.

5. **Over-determined is not the same as short-circuited, and the difference is per
   collection.** Correcting (4) I wrote that both comment tests were "denied on maturity
   before the age gate was consulted". False: in `recipe_comments` the age check is the
   EARLIER conjunct and did fire — both checks failed, which is why deleting one changed
   nothing. The phrasing had been carried over from the `messages` block, where the order
   genuinely is the other way round. **A sentence about which conjunct denied first is a
   per-collection fact; state the property the test depends on (over-determination), not the
   order.**

6. **A probe that deletes only a helper's CALL SITES does not compile.** `noUnusedLocals` is
   on, so removing the three calls to a seed helper makes ts-node abort with TS6133 before a
   single test runs — and that exit code is indistinguishable from a red assertion. The
   first run of that probe reported a confident wrong answer. Delete the declaration too, or
   mutate the fixture data. (Same family as "a mutant that fails to COMPILE is not a red
   test", now with the specific setting that causes it.)

7. **The count that matters: six false sentences, all in comments, none catchable by any
   test.** A wrong date, a wrong count, a wrong universal ("names the METHOD wherever one
   exists" — false for two of four entries), a wrong ticket attribution, a wrong conjunct
   order, and one claim about a probe I had not run. Every one was caught by a reviewer, at
   roughly ten minutes per round, and four of them were introduced BY the correction to the
   one before it. The code in both commits was right the first time. **The prose is the
   defect surface on this kind of work, and a correction is a new claim, not the end of the
   work** — this is the third entry in this file to say so, which is itself the finding.

### A Python heredoc turns a backslash escape into a CONTROL BYTE, and one of the four hits was where no sweep can reach (2026-08-19)

Writing Dart or TypeScript through `python3 - <<'PYEOF'` is a good way to make a precise
multi-line edit. It is also a good way to write an invisible 0x08 into a source file.

In Python source, `'\b'` is BACKSPACE. So a comment explaining that Dart's
`\b` word-boundary anchor cannot fire inside `direct_a_b` — the exact sentence that
explains the bug — gets written to disk as `^H`, and the sentence renders as
"the `` anchors never fire". The compiler does not care. `dart analyze` is clean. Every
test passes. Only a reader loses.

It landed FOUR times in one change set: in THREE source files — the original comment, a
rewrite of a related comment one file over, and a new comment in a third — and then in the
COMMIT MESSAGE describing the bug. Three of the four were caught by review agents, not by me.

That fourth one is the part worth remembering. The remedy below is a file sweep scoped by
extension, so replay it against its own four events and it fires on three and is structurally
blind to the last. A commit message is not a file. Byte-check the message too, before
`git commit -F`.

Not all four were corrections — that qualifier was in an earlier draft of this entry and was
wrong. What they share is only the mechanism: every one of them was written through a Python
heredoc, which is simply how a precise multi-line edit gets made here, so the trap is armed on
every edit rather than on careless ones.

A fifth escape mistake in the same change set was a different bug with the same root: the
sweep prescribed below was written as a bare `\x00-\x08`, with no character class
around it, so it matched nothing. Count it separately; it is not a backspace.

**The fixes, in order of preference:**

1. Use a Python RAW string — `r"\b"` — or build the character explicitly with
   `chr(92) + "b"`. The explicit form is ugly and never wrong, and it is the one to reach
   for: this very line first shipped as `r"\\b"`, which is TWO backslashes and a `b`,
   i.e. the wrong answer inside the fix list of the lesson about getting it wrong.
2. After any heredoc edit that mentions a regex escape, run
   `git ls-files -z --cached --others --exclude-standard -- '*.dart' '*.ts' '*.md' | xargs -0 -r grep -laP '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'`

   From the REPO ROOT, over files git knows about but NOT ones it ignores, with `*.md`
   included. Every clause was learned the hard way. An earlier draft swept `lib/ test/ functions/src/` and therefore
   could not find the very instance this entry cites as its own proof, which lived in
   `.claude/` until BUT-1902 repaired it. A later one used `grep -r … .`, which walks the whole working tree — an order of
   magnitude more files than are tracked, nearly all of them machine-generated — so the baseline's
   "anything else is yours" would have become false the next time anyone ran `npm install`.
   (Deliberately no figures: this entry has had three sets of them and all three expired.
   Measure when you need the number.) `git ls-files` is the idiom
   `.github/workflows/text-integrity.yml` already uses to enumerate files — it
   lived in `test.yml` until 2026-08-19, when it had to move because that
   workflow's `paths-ignore` excluded the very directories the guard exists
   for. Extension scoping stays:
   PNG fixtures match otherwise.

   `--others --exclude-standard` is the third clause, and it closes a hole the second one
   opened: plain `git ls-files` lists TRACKED files, so a file the heredoc has just CREATED is
   invisible until you `git add` it — which is exactly when you would be running this. Measured
   in a throwaway repo: without the flags a brand-new corrupted file returns nothing; with them
   it is found, and `node_modules` stays excluded because it is gitignored. On this repo the
   two forms list the same files and return the same hits, so the flags cost nothing and
   cover the case that matters tomorrow. **The baseline is stated below, and nowhere
   else** — a second copy of it in this same item is what a reviewer caught after the first
   correction: the number was still "two" up here while the real statement below already
   said one.

   The class is wider than `\b`, and that is not defensive padding. This entry's own worked
   example ate FOUR escapes, and the first version of this sweep — `[\x00-\x08]` — could see
   only ONE of them. `\v` is 0x0B and `\f` is 0x0C; both sit above the old ceiling. The test
   passed anyway, purely because `\b` happened to be in the same file. Probed on one-byte
   fixtures: the old class matched the backspace file only, the new class matched all three.

   `\t` stays OUT, and that is a real hole rather than an oversight: a tab is legal in
   source, so no sweep can flag it. The `\t` half of the worked example below was invisible
   to this command and always would have been — it showed as `C:^Iools`, and only a reader
   catches that. `.github/workflows/text-integrity.yml` makes the same point generically, in
   the guard itself.

   **The expected set is ONE file. A SECOND is yours.**
   * `test/unit/services/ocr_extraction_service_test.dart` — deliberate control-character OCR
     fixtures, with a comment saying so. It is the same file
     `.github/workflows/text-integrity.yml` names — but the two do not do the same job, in
     three ways. CI EXCLUDES the file and so expects NOTHING back; this sweep expects exactly
     that file. CI scans a longer extension list — read it off the workflow
     rather than trusting a copy here. And CI sweeps TRACKED files only, so on a LOCAL tree
     it cannot see the not-yet-added file that `--others --exclude-standard` exists to catch;
     on CI itself everything present is tracked, so nothing that LANDS escapes it. A clean
     run here does not predict a green guard there, in either direction.

   It was TWO until 2026-08-19, and saying so here after the repair landed would have been
   FAIL-OPEN: a session that swept, got two hits and dismissed the second as "the known
   baseline" would have been dismissing a real one. Corrected the same day the reviewer
   caught it.

   The second entry was `.claude/agents/testing-specialist.knowledge.archive.md`, and
   the story is worth keeping even though the file is clean now. It read `lutter^Hin` where
   `C:\tools\flutter\bin` was meant. FOUR escapes were eaten across two Windows paths on
   that line — `\v` (from `\v1.0`), `\t`, `\f` and `\b`. Introduced 2026-06-14 in
   `3bf7a50f3`, in `testing-specialist.knowledge.md` — the file agents LOAD — moved into the
   append-only archive three weeks later by `58bae2954`, and repaired by BUT-1902 on
   2026-08-19. Nobody found it in two months because nobody swept over prose.

   Before the repair it showed only TWO of the four: the 0x08 on line 1143 and the tab on
   1142. A later rewrite had normalised the 0x0B and 0x0C into line breaks, which is why the
   damage spanned lines 1141-1143 and why an earlier draft of THIS entry read those breaks as
   `\n` and got the escape list wrong. Do not re-derive escapes from what survives.
3. Do not trust an earlier clean sweep. The sweep proves the bytes at that moment; the next
   heredoc reintroduces it.

**And the sweep itself has a trap, which this entry originally walked into.** Written without
the brackets — `\x00-\x08` instead of `[\x00-\x08]` — the pattern is not a range at
all. It is the three literal bytes NUL, hyphen, BACKSPACE, which nothing contains, so the
command reports CLEAN unconditionally. Measured: `printf 'X\x08Y'` piped to the
bracketless form matches 0 lines and to the bracketed form matches 1. A guard that always
says clean is worse than no guard, and it survived into a lesson about false assurance until
a reviewer ran it. **Test the sweep against a file you have deliberately corrupted, before
you trust it on a file you have not.**

This is the same family as the 2026-07-16 entry above ("Backslash/NUL content dies crossing
tool layers"), which said the same thing about `printf` and YAML and was not enough to stop
this: that entry names the layers to avoid, this one names the ONE layer that keeps being
reached for anyway, because a Python heredoc is the most convenient way to make a precise
multi-line edit. It is also the repo's "invisible codepoint" lesson (BUT-1690) with a
mechanism attached.
The general form: **a source edit performed through another language inherits that
language's escape rules, and the result is compiler-invisible.** The same trap ate a `\n`
inside a Dart string literal in the same session, which DID fail the analyzer — the
difference is that a control byte inside a comment has nothing to fail.

### A comment that QUOTES another comment breaks when you fix the thing it quotes (2026-08-19)

A false sentence appeared in five places. I corrected three, wrote a note saying so, and the
note said:

> this claim had FIVE sites, not three ... The header says three because that is how many I
> had found when I wrote it.

Then I fixed the header to say FIVE. The note now pointed at a header that said the opposite
of what the note promised — **a new falsehood created by the fix to an old one, in the same
commit**. The same note also said "the two just above" about two sites, one of which is 31
lines *below* it.

**A sentence that quotes another comment's wording, or its position, is a DEPENDENCY on that
wording and that layout.** Both are things you are actively editing. State the fact instead of
pointing at where the fact is written.

The count itself was wrong twice, for the ordinary reason: an unscoped number invites the next
correction. "Five sites" was true of the trigger and its test suite; `firestore.rules` and its
rules test carried the same claim, correctly tensed. Scope a count to what it counts.

#### The related trap, from the same review: a fast path can make a boundary unreachable

Separately in the same file, I wrote that flipping a comparator from `<` to `<=` would delete
a message on redelivery. A reviewer measured it and it would not: an `eventId` fast path
upstream catches that case and returns before the comparator ever runs. What the flip would
actually do is the inverse — delete one of two DIFFERENT messages written in the same
millisecond.

Two things follow, and the second is the sharper one:

1. **The stated failure mode was not the one a flip produces.** A guard's justification is an
   assertion about control flow, so trace what SHORT-CIRCUITS above it before writing why it
   matters.
2. **The mutant survived both suites.** No fixture sat on the boundary, so `<=` passed
   19/19 — the unit suite as it then stood — and 9/9. It is 20 cases now, the extra one being
   the boundary fixture ADDED to kill it (not the twentieth in file order), so quoting today's
   total would name a suite the mutant demonstrably does NOT pass. Scope a count to what it
   counted. A comment calling something "load-bearing" is an untested assertion until a
   fixture sits exactly ON the bound — and a fast path upstream is exactly what makes such a
   fixture easy to forget, because the boundary looks unreachable from the outside.

### A value bound on one collection does not bound a COPY of it on another — and "how long does it persist" is a claim about the writer you did not read (BUT-1903, 2026-08-19)

**What happened.** BUT-1903 bounded `messages.sentAt` at `request.time + 1h` in
`firestore.rules`, to stop a future-dated stamp pinning a chat message to the top and
freezing the chat-list preview. The rules-tester gate found the bound reaches neither harm
completely: `conversations.lastMessage` is a **denormalised copy** of `sentAt` on a
different collection, and that collection's `allow update` deny-list
(`['participantIds','createdAt','memberSince','groupId']`) does not name it. Any
participant can write `lastMessage.sentAt` directly, at any value, never touching the rule
the whole ticket is about.

**Then the duration claim was wrong twice, in the same comment.** Draft one said the whole
residual was "up to an hour" — false, because the copy is not covered. Draft two said the
copy's freeze was "PERMANENT", reasoned from `shouldReplaceLastMessage`'s self-heal firing
only on a non-Timestamp. Also false: `MessageMutationModule.sendMessage` merge-sets the
whole `lastMessage` map on **every** send with no comparison at all, so the next real
message clears it. The truth is "until the next message in that conversation — indefinite
in a quiet one, and re-poisonable after every send", which is a *different severity* from
either draft, and a future ticket would have sized its work against whichever was written.

**Same shape, one round later, in the same change.** Adding a gate that skips Admin-SDK
system rows from a telemetry sample silently falsified the paragraph two lines above it,
which had listed "an Admin-SDK write" as one of two causes for an empty bucket. The gate
removed the only such writer. The other listed cause was impossible too — the sample fires
at CREATE, so a pre-existing row can never produce one.

**The rules.**

1. When a rule bounds a field's VALUE, grep for other collections that store a
   **projection** of it before writing what the bound closes. `hasOnly`/deny-list rules on
   the copy are a separate surface and usually do not name the field.
2. A sentence about **how long** a bad value survives is a claim about *every* writer of
   that field. Enumerate them — server trigger AND client repository — before writing a
   duration. Reasoning from the path you happen to be editing is how both drafts went wrong.
3. **Your own fix in the same commit can falsify a comment you just wrote.** After adding
   any guard, re-read the paragraphs around it for claims the guard has just made false.
4. Do not cite a rules **line number** in a comment. This very edit moved everything below
   it by 55 lines; a reader following a stale number lands in an unrelated rule and
   concludes the claim is false. Name the block.
5. **A correction's SUPPORTING detail is as falsifiable as the claim it supports, and this
   is where the loop lives.** One paragraph in `message_send_error_mapper.dart` shipped five
   false supporting claims in a row, each after the first introduced by the fix to the one
   before it — the fifth of those corrections is this clause, because the draft said "each"
   and the opening claim was original rather than fix-induced, which is the exact standard
   this rule sets. The five: a
   four-link chain that had five links; "untested by anything" when three links were already
   pinned by type-identity assertions; "the shape link 1 already uses" when link 1 has no
   `on <Type> catch` at all; "nineteen methods apart" when it is twenty-six; and "fails
   LOUDLY" for a drift that is *silent* — it clears the user's text and reports success.
   Each was cheap to check and none was checked, because finishing a correction feels like
   the end of the work rather than the start of a new claim. **Rule: after correcting a
   comment, re-read the corrected sentence as if someone else wrote it, and grep every noun
   in it.** A reviewer who disproves one supporting detail in thirty seconds stops trusting
   the whole paragraph, which costs more than the overstatement bought.

### A gold set graded from TEXT undercounts, and a downscaled image lies about edges (BUT-1847, 2026-08-19)

The cookbook corpus's frame-cut set stood at 14 entries, hand-graded from what a word-shape
screen surfaced, and every published trim figure rested on it. Grading all 242 verified
entries against the PHOTOGRAPHS put it at 23 — and a DIFFERENT, terminal-punctuation screen,
run over the finished set, recovers only 9 of them (13 if it also looks for an explicit `...`; the other ten are clean
prose that simply stops). Five of the nine new entries are not camera cuts at all: a recipe
that starts at the foot of one page and finishes on a page the photo does not include. No
screen aimed at broken words can see that class — the gold ends on a clean full stop — so
"floor, not a count" was right and the floor was 40 % low.

1. **A screen finds the failures it is shaped like.** The word-shape screen looks for lines
   broken mid-word, so it finds vertical slices and misses clean truncation at a page break.
   Before trusting a hand-graded set, ask which failure the screen that produced its
   candidates could not have seen.
2. **A 1600 px view of a 3000×4000 photo invents edges.** `Pernillas festfisk` read as
   sliced by the frame and was intact at full resolution; the page's own `ocr.txt` carried
   the full line. Crop the ORIGINAL before labelling any edge, and cross-check against the
   stored OCR — it is free and it is from the same capture.
3. **A borderline label that decides what LEAVES the denominator has to be argued from a
   written criterion, never from the transcription and never from the number it produces.**
   `Inlagd sill` (159 chars) and `Mixade vitaminer` (166) are the same case: the next recipe's
   opening, taken by the bottom frame edge, no ingredient block, a line or two of method. Their
   gold READS differently only because one cut landed after a full stop — an accident of where
   the frame fell. I labelled them apart on that accident, and a reviewer was able to cite the
   rubric for BOTH answers, which is the tell that the rubric was under-determined. Settled by
   writing the criterion down (does the capture hold the recipe's SUBSTANCE?) and applying it to
   both: `fragment`. It moves the headline figure from 23 real gold tokens to 9, so the
   sensitivity is published beside the number rather than buried.
4. **Re-grading moves only the de-biased column.** The default arm reads the marker only to
   tally the census it prints — nothing downstream of that tally touches a score — so every
   biased figure kept reproducing byte for byte while the `--no-frame-cut` figures all moved.
   (That clause used to read "never reads the marker". It was true until this same batch made
   the read unconditional, and it survived three sweeps because it says "the marker" where its
   two corrected siblings say `frameCut`. Grep the CONCEPT, not the spelling.) A number from a corrected population must be quoted with the correction that
   produced it named, or the next reader diffs two gradings and calls it drift.
5. **Price the refusal you argued.** The 120-200 band had been declined by reading nine
   tails; it had never been measured on de-biased gold, and the entry said so. It costs 9
   real gold tokens and one right block count, against exactly zero for the shipped 120.
   Reading and measurement agreed — but TWO of the nine turned out to be debris by the
   corpus's own grading, so the argument had a hole the measurement did not.
6. **Editing the measured input mid-review invalidates the review, silently.** I flipped one
   gold entry while three reviewers were reading the diff that quoted figures derived from it;
   one of them re-ran the arms, found the corpus no longer matched the docs, and blocked. It
   was right to. Freeze the inputs a review is reading, or re-run the review after touching
   them — a verdict is only about the bytes it saw.

### A content-addressed gate is the only kind that converges (BUT-1801 salvage, 2026-08-17)

Eight review gates, six rounds, ~15 specialist passes over one 42-file commit. Every round
found real defects and every round found FEWER. What made it terminate is that the gate
measures BYTES, not claims: a PostToolUse hook records which reviewer opened which file and
the verdict its run ended on, content-addressed, so any edit after a review silently
un-proves the file it touched. I could not talk my way past it, and neither could a reviewer
— one passed while only *reasoning* about a file it never opened with Read, and the gate held
until it did.

The distribution of what the loop caught is the finding:

* **Zero logic defects in my own fixes.** Not one round found the code wrong.
* **Eight false SENTENCES from me.** A comment citing a rules line number that had already
  drifted; "all three `FirestoreCollections.recipes` sites" when there are five; "300 lines
  down" for 159; "the suite stays 32/32" for a 33-test suite; "no code writes that array any
  more" about an array still emitted (empty); a justification citing an error path that
  cannot occur; a comment describing the pre-BUT-1721 truncation walk and concluding a live
  line was inert; and "formatting only" said to a REVIEWER about a file carrying a whole
  document-id scheme change, which I had not opened.
* **Four tests that could not fail.** Two proved vacuous by mutation probe (one of them my
  own first attempt at closing a gap the reviewer had just named), one whose two halves were
  the same observable, one whose branch the test fake could not stage at all.
* **One real bug nobody was looking for**, found only because a reviewer read the whole file:
  poll hydration capped from the HEAD of an oldest-first list, so the polls it dropped were
  the ones on screen, rendering "0 röster" over real votes.

So the loop is expensive and it is not optional. The cheap-looking alternative — trusting a
verdict rather than the bytes — is exactly how the batch being salvaged reached "six
specialist reviewers passed" over files none of them had opened.

#### The corollaries worth carrying

**A verifier's FAIL is a hypothesis, and can be right for the wrong reason.** BUT-1801's
verifier failed the batch saying "only 1 of the 6 named sites was fixed". Three of the six
were already correct at HEAD — the ticket was stale — and the Art. 17 site it named was not
broken at all. But one layer down there WAS a defect neither the ticket nor the verifier
named: `probeResidualData` counted recipes on a path where documents cannot exist, so the
post-erasure residual check returned zero on every deletion without ever looking at a recipe.
Re-derive the verdict; do not implement it and do not dismiss it.

**"No client can write it" is not "nothing can be there."** I deleted a top-level read from
the deletion cascade as provably dead, citing an admin-only read-only rule. The Admin SDK
needs no rule, and a registered integration test plants a document there precisely to prove
the cascade sweeps it. Reverted. Before deleting a defensive read, grep `__tests__` — the
fixture is both the counterexample and the alarm.

**An error handler returning an EMPTY collection is fail-CLOSED.** The live poll-vote stream
mapped an error to an empty tally, which is *present* in the map, so the merge ran and blanked
every stored vote — under a comment claiming the same fail-open contract as its sibling, which
leaves the id OUT of its map. Only a null/absent marker is fail-open. Same shape as a probe
that reads an empty collection and reports "clean".

**A cosmetic edit is still a code change.** A test rename in the last minutes, after eight
gates had passed, put an apostrophe inside a single-quoted Dart string and stopped the file
compiling. Analyze the file you EDITED, not its neighbours — the suite passed in isolation and
only failed when run beside its sibling.

**Ask what goes unguarded when a test is deleted.** Removing a probe correctly removed five
tests for it, and with them the section's only assertion that its truncation flag can be
ABSENT — so an unconditional flag would have told every data subject their export was clipped
when it was complete. The deletion was right; the missing replacement was not.

### [Tooling] Python's `/tmp` and Git Bash's `/tmp` are different directories on Windows
Date: 2026-08-17

Five consecutive answers to "which functions would `--force` delete?" were wrong, and each
looked plausible: 69 deployed vs 71 exported with 8 overlap and 61 orphans — internally
impossible arithmetic that I re-derived rather than distrusted.

Two independent causes, stacked:

1. **Different filesystems.** A `python -c` heredoc wrote `/tmp/src.txt`, which Windows Python
   resolves as `C:\tmp\src.txt`. Git Bash's `/tmp` maps to the Windows temp dir. Every `comm`
   compared fresh gcloud output against a stale file from an earlier, cruder extraction that
   happened to still be sitting there. The Python printed a correct count each time, so the
   write looked confirmed.
2. **Different line endings.** `gcloud` emits `\r\n`; the parser emitted `\n`. `comm` requires
   both inputs sorted in the same collation and compares whole lines, so a trailing `\r` makes
   nearly every line unequal — which reads as "no overlap", not as "encoding problem".

The tell was there from the first run and I explained it away twice: **the two `comm`
directions did not add up.** 71 exported, 69 deployed, 8 overlap and an EMPTY
"exported-but-not-deployed" list cannot all be true. When a set comparison's complements are
inconsistent, the inputs are wrong — stop and check the files, don't refine the regex.

Rules that follow:

- Do the whole comparison **in one language**. Mixing a Python writer with a bash reader on
  Windows crosses a path-resolution boundary that neither tool reports.
- Normalise line endings at the boundary (`tr -d '\r'`) before any `comm`/`diff`/`sort` on
  tool output, always.
- Prefer `mktemp -d` over a hardcoded `/tmp/name` — a fresh directory cannot serve a stale
  file from a previous attempt.
- A parser that "mostly works" on a structured source is a smell: the third failure here was a
  `sed` that handled single-line `export { a } from "..."` but silently dropped multi-line
  blocks, hiding five real exports. Parse the language with a parser, and sanity-check the
  count against a crude `grep -c` before trusting a diff built on it.

### [Testing] An SDK's "unset" can be a sentinel OBJECT, so `== null` guards it vacuously
Date: 2026-08-17

A new suite pinned `maxInstances` on every deployed Cloud Function endpoint. It went green,
and its "no export ships without an instance ceiling" check was **incapable of failing**.

`firebase-functions` does not leave an unset `maxInstances` as `null` or `undefined` — it
stores a sentinel object whose `toJSON` renders as `null`. So every diagnostic agreed with the
wrong conclusion: `JSON.stringify(v)` printed `null`, `"maxInstances" in endpoint` was `true`,
and `typeof v` was `"object"` — while `v == null` was **false**. The vacuous check passed under
a mutant that deleted the option from every one of 70 functions.

It was caught only because the mutation probe reddened the *wrong assertion*: the mutant that
removed the ceiling failed the "is it the expected VALUE" check while the "is it PRESENT" check
stayed green. Two assertions over one invariant, and the mutant separated them — that
disagreement is the signal, and running only one mutant, or reading only the summary count,
would have hidden it.

Rules that follow:

- Never write `== null` / `!= null` against a value whose producer you have not read. Test the
  shape you actually require (`typeof x === "number"`), which fails closed on null, undefined
  AND a sentinel.
- `JSON.stringify` is not an identity check. A `toJSON` can make any object print as anything,
  including `null`.
- When one mutant reddens a *different* assertion than the one you predicted, stop and probe
  the raw value. A passing sibling assertion in that state is the vacuity showing itself.
- Type the field as `unknown` rather than `number | null` — a narrow type invites exactly the
  null check that cannot fire.

### `node --check` does not prove the sprint engine parses (2026-08-17)

Adding a sentence to a prompt inside `sprint-execute-parallel.js` broke the engine twice in a
row, and `node --check plugins/delivery/workflows/sprint-execute-parallel.js` printed nothing
both times.

It cannot: the harness evaluates that file as a FUNCTION BODY via `new AsyncFunction`, not as
a script. `--check` parses it under different rules and is happy.

The actual break was ordinary and easy to repeat — **a backtick inside a template literal**.
The prompt strings in that file are huge template literals, and writing a natural
"`<lens>: <verdict>`" or "a bare `pass`/`fail`" inside one terminates the literal at the first
backtick. Markdown habit and template literals are the same character.

**So: run `node test/delivery-engine-fixtures.mjs` after ANY edit to that file, including a
comment-only or prose-only one.** It evaluates the engine the way the runtime does and fails
loudly with the line number. The outer `test/run-fixtures.mjs` reported "219 checks passed,
0 failed" for its own suite while the engine underneath was unparseable, so read the
`delivery-engine:` line specifically, not the summary.

Inside those prompts, quote code with plain double quotes, not backticks.

### A detached commit does not pass the review gate (BUT-1858, 2026-08-16)

The commit gate here runs for eight to ten minutes, longer than the tool's cap, so my own
earlier lesson says to launch it detached (`Start-Process ... -WindowStyle Hidden`) and poll
`git rev-parse HEAD`. That lesson is right about the *timeout* and silent about the thing
that matters more: **the review gate is a PreToolUse hook on Bash, so it only sees commands
the tool runs.** A detached shell is invisible to it.

The first two times I used the trick, the review gate had already passed on those exact bytes
and the detached run was merely finishing what it had approved. The third time, lefthook's
arch-guard had refused the commit for a raw `?? ''` under `lib/`, I fixed it, and relaunched —
with a production file now one token different from what three reviewers had signed off. I
caught it mid-run and killed the process before it landed. Two minutes later the same commit,
run through the tool, was refused by the review gate naming exactly that file.

So the rule is not "don't run detached", it is: **the detached run may only finish a commit
the review gate has already approved on the current bytes.** Attempt it through the tool
first; a timeout after the gate has passed means the gate said yes and lefthook is just slow.
Any edit after that, however small and however demanded by another gate, sends you back
through the tool.

Two smaller things from the same sequence, both costly:

- **`git checkout -- <file>` restores HEAD, not your backup.** I used it to undo a mutation
  probe and it silently deleted an hour of work on that file, because the fix was not
  committed. The probe's own finding survived; the fix did not. Restore from a byte copy you
  made yourself (`cp` before, `cp` after, md5 both), and never from git while the work is
  uncommitted. This is the second time a restore mechanism has eaten a change in this repo.
- **A killed commit leaves `.git/index.lock` but an intact index.** Verify no live writer
  (`Get-CimInstance Win32_Process` — the long-lived `git.exe` entries in this checkout are
  days-old read-only status queries, not writers), then remove the lock; the staged set
  survives untouched.

#### And the shape the whole ticket had

Ten review rounds. Every blocking finding but one was a false sentence in a comment or a
decision record; the code was stable and mutation-proven from round two. **Three of the
blocking findings were my own corrections landing worse than what they replaced** — a hedge
turned into a false universal, two tests attributed to the wrong ticket, "the functions are
interchangeable" written about two functions closing over different vocabularies. The
BUT-1838 lesson said this already; what BUT-1858 adds is that it does not decay with
repetition. The prior on a reviewer-requested rewrite should be LOWER than on the original,
because the original was at least written while looking at the code.

### A run's own outcome report is a CLAIM about git, and it can be false in every clause (2026-08-16, sprint 2026-08-16 Agents C & D)

A parallel sprint reported four tickets as "BUILT and committed with this review still owed,
then parked In Review". It wrote that verdict into `docs/org/metrics/events.jsonl`, the file
`/org-retro` reads as evidence when it computes the autonomy accept-rate. Every clause was
false: `HEAD` equalled the sprint base commit (`git diff base..HEAD` empty), the only object
in `git log --all` since the run started was a stash commit, and all four issues read
`"status":"Todo"` in Linear with a `stateHistory` that never leaves unstarted. Three of the
four had produced no artifact at all — no commit, no stash, no held/failed record; they were
selected in `tasks/todo.md`, and then simply fell out of the run in silence.

The dangerous property is that the false report is *internally consistent*. It names real
tickets, real review tiers and real owning roles, and it flags its own gap honestly
("this review still owed") — which reads as candour and buys the rest of the sentence
credibility it has not earned. Nothing downstream re-checks it: the metrics file is
append-only prose, the Linear transitions are driven from the same report, and the next
session reads `tasks/todo.md`, which had no outcome block either.

So, mechanically, before writing or acting on ANY sprint outcome:

1. **`git rev-parse HEAD` against the sprint base.** Equal means nothing shipped, whatever
   the report says. `git diff <base>..HEAD` empty is the same statement, and both beat any
   worker's prose.
2. **`git stash list` + `git log --all --since=<run start>`** to find where work that was NOT
   committed actually went. A held batch lives in a stash and nowhere else.
3. **Read the tracker's own `stateHistory`**, not the report's claim about it. "Parked In
   Review" is checkable in one call.
4. **Grade each acceptance criterion against the tree**, not against the batch summary — the
   three silently-dropped tickets were all trivially disproved by one `find` or one `sed` of
   the file the ticket names.

Corollary for anything that writes to a metrics/evidence file: a row asserting an outcome
must be derived from git, never from a worker's report, and it must be written AFTER the
commit it describes exists. A row that says "shipped" for work that did not ship inflates the
exact number the file exists to measure, and it is uncommitted at the moment you can still
cheaply retract it. Filed as BUT-1865 (retract the rows), BUT-1866 (the missing outcome block
and the uncommitted review trail), BUT-1871 (three reviewers passed the bytes one verifier
failed).

And the shape behind the silent drops: a ticket that is selected but never built leaves NO
trace anywhere unless the run writes one. The held/failed lists are populated by workers that
reported back; a worker that produced nothing reports nothing, and the absence looks identical
to "not selected". A completeness sweep must therefore start from the SELECTION list in
`tasks/todo.md` and prove an outcome for each entry, rather than enumerating the outcomes the
run happened to hand it.

### A reviewer and a verifier can BOTH be right, because they grade different things (BUT-1871, 2026-08-16 / resolved 2026-08-17)

Three specialist reviewers passed a diff with zero blocking findings. The outcome verifier
failed the same bytes on two of three criteria. The ticket filed for it assumed one side had
blundered, and offered two candidate culprits. Neither was the answer.

The diff changed `content_card.dart` so a card DERIVES `showAllergenBadges` from the user's
preference sets. Its three new tests construct a `ContentCard`, pull the `RecipeCard` back out
of the tree, and assert the flag props. Delete the derivation and all three redden — so with
respect to the DIFF the tests are not vacuous, and the reviewers passed correctly.

But BUT-1780's claim was that allergen badges never APPEAR on recipe cards. No test renders a
badge. `recipe_card.dart:223` guards the badge block on `tagResult != null`, `RecipeFactory`
has no `tagResult` parameter at all, and neither file was in the diff. So with respect to the
TICKET nothing was pinned, and the verifier failed it correctly.

**Two graders, two rubrics, and nobody had said which one "a regression test" is graded
against.** That gap is the defect; hunting for a careless reviewer was chasing the wrong one.

#### The three mechanical causes, none of which a new rule would have fixed

The probe requirement already existed — `testing-specialist.md` says "Confirm it would fail if
that behaviour broke", and its knowledge file carries a whole *Vacuity patterns* section
opening with "the single most repeated finding across two months of review". It did not bind
because:

1. **It is written for AUTHORING.** The section heads "Before writing or editing a test". The
   agent was reviewing someone else's diff — in scope by topic, out of scope by verb.
2. **The severity taxonomy produced the pass.** `isBlocking` counts Critical and High only. A
   vacuous test breaks nothing in production, so it grades Medium, and a clean verdict is
   computed from there. The reviewer's own note said the suite "asserts the constructor FLAG,
   never a rendered badge" — and its `pass` was not a contradiction of that note. It was the
   taxonomy working as written.
3. **`notVerified` already existed and was read by NOTHING.** Declared in the reply schema,
   demanded in the instruction, parsed into the result object — three occurrences, no consumer.
   The field where "I could not show this would fail" already landed was a dead letter, so a
   new rule written above it would have repeated the miss one layer up.

#### And the reviewers were structurally denied the evidence

`runGateReviews` said "Review ONLY these files", computed from what the patch touched. Seeing
the vacuity required three files; one was in the diff. The other two were not merely
unmentioned — they were excluded by instruction, and because the ledger credits only files an
agent Reads, opening them was unrewarded work on top of that. The 2026-08-01 salvage had
already measured the same shape from the other end: seven of its nine blocking findings were
"this file is correct on its own but disagrees with something else".

#### What shipped

The severity class, a consumer for `notVerified`, and the removal of the word ONLY — reviewers
are now told to open siblings, and a doubt parks the ticket for Malin instead of closing it.

**A mandatory mutation probe was REFUSED**, and that refusal is the part most likely to be
re-proposed: gate reviewers run concurrently over one shared checkout, review proof is
content-addressed against the worktree blob, so a probe would re-score its own recorded read
AND every sibling reviewer's to `drifted` — routinely un-proving the review it strengthens.
Writing a mutant into `lib/` is also refused by the auto-mode classifier, silently, poisoning
the run's next action. The cheap read fixes the same miss with none of that.

### BUT-1838 — a correction to a false comment fails the same way the original did (2026-08-15)

A whole-range gate caught four code comments justifying live controls with a `firestore.rules`
branch BUT-1838 had deleted two days earlier. Fixing them took **six review rounds**, and every
round found a fresh false sentence *in the text I had just written to replace a false sentence*.
Zero logic defects the whole time. The failure mode was identical every time, and it is not
carelessness — it is the shape of the sentence.

#### The shape: an unqualified claim about a qualified fact

Each wrong sentence generalised something true **per verb**, **per caller**, or **per branch**:

| I wrote | The qualifier I dropped |
|---|---|
| "nobody can read, update or delete them, ever" | per VERB — `allow delete` and the `hasOnly(['lastReadAt'])` update branch key on `participantId == request.auth.uid` and never touch `parentDoc()`. Orphaned rows are UNREADABLE, not unreachable. |
| "the account cascade's two call sites are handed direct ids" | per CALLER — `deleteChatGroupMemberships` reads its id off a `chat_groups` doc, so it is group-side. Only `deleteMessages` is direct-side. |
| "a live parent … denies the roster to everyone" | per CALLER again — true for the two group-side callers (zero-member shell), false for the 1:1 branch, where the surviving partner is still named. |
| "No rule reads `chat_groups` membership" | per PURPOSE — rules read it for the group's read gate and for rename; what they never do is read it for a SIZE decision. |
| "Nothing actually caps a group's size" | `MAX_CHAT_GROUP_MEMBERS = 100`, enforced by both membership callables. |
| "re-introduce the fallback and this test reddens alone" | per FIXTURE — a sibling test stages the same predicate over an absent parent and flips too. |

Two of them were *worse than what they replaced*: the original sentences were correct, and my
rewrite invented a route that does not exist (a direct conversation's roster holds at most TWO
client-written rows — `directIdBinds` forces `p.size() == 2` and `participantIds` is in the
update deny-list, so it can never reach a 2000-row cap).

#### Three habits, in the order they pay

1. **Write the qualifier or write nothing.** "Every predicate that could SURFACE a row reads
   through the parent" is true; "every predicate reads through the parent" is false, and the
   difference is the whole finding. Before an absolute — *every, no, nobody, nothing, only, at
   all* — name the axis it quantifies over (verb? caller? branch? purpose?) and check each value.
2. **Enumerate by GREPPING THE PHRASE, not by fixing the site the reviewer named.** Round five
   fixed two instances a reviewer pointed at; round six's grep found a third in a file nobody had
   opened. Grep across the whole tree *including tests* — a false claim propagates by copy-paste,
   and `__tests__` is where the copies live.
3. **Re-read the WHOLE docstring, not the diff.** Two findings were context lines ~30 lines from
   my edit, inside the same comment block. They cannot appear in a diff, and they now contradicted
   the paragraph above them — which is strictly worse than being uniformly stale.

#### The other half: a decision record ages the same way

`.claude/rules/accepted-deviations.md` justified `MAX_ROSTER_SWEEP_ROWS` ("do not remove the cap")
with the same deleted branch — written one day before the branch died. A record that is wrong on
the day it is written is worse than one that goes stale, because it gets cited as authority. Both
files got a dated `AMENDED` addendum rather than a silent edit, and the replacement rationale was
itself panel-reviewed: the Security Architect refused the draft that said the path was no longer
client-writable, because `attestedWriter()` lets either participant of a direct chat write the
other's roster row. The phrase "not a live client write path" is now banned by name at every site.

#### Also, the underlying bug was bigger than reported

The reviewer reported "group chats are invisible to the unread badge". The badge read **0 for
everyone**: its inverse index is written `hasUnread: false` and the only writer that would flip it
has no production caller. The suggested fix (have the server write the missing rows) would not have
helped — they would arrive `false` too. **When a reviewer reports a symptom, find the mechanism
before accepting the scope**; the reported scope is a lower bound on the defect, not a description
of it.

### "Not a live bug" is a claim about CALLERS, not about a fallback (BUT-1849, 2026-08-15)

Deleting a dead widget, I documented a clamp in a neighbouring file and wrote the sentence that
made both reviewers fail the diff:

> no live path produces an off-list unit — `PantryService`'s `typicalUnit` fallback is unreachable
> while this sheet is the only caller and always passes a unit

Every clause in it is defensible in isolation. The conclusion is false. The clamp guards a
**shipped** flow: check off a shopping item with the auto-add-to-pantry preference on, and
`ShoppingCheckoffPantryService` → `PantryService.addFromShoppingItem` → `addFromText` stores the
item's free-text unit verbatim — `UnifiedShoppingItem.unit` is non-nullable, so the `unit ?? 'st'`
I was reasoning about never fires. Opening that row and pressing Save rewrites `förp` to `st`, and
because the same flow dedups on name + unit, the next check-off then creates a duplicate row.

**The error was choosing the wrong thing to trace.** I traced the *field's own default* (is the
fallback reachable?) and the *view's* callers (`PantryViewModel.addItemFromText` — genuinely only
this sheet). The question was about the SERVICE's callers, one layer down and in a different
feature. "Is X reachable" decomposes into "who calls the writer", and a null-coalescing operator
answers none of it. Nullability is not reachability.

Two habits:

1. **Trace up from the WRITE, not down from the field.** Grep the writing method's name, then each
   of *its* callers, until you hit UI or a trigger. The stopping condition is a human or a
   scheduler, never "the fallback can't fire".
2. **A reachability claim is load-bearing prose.** It downgrades a ticket, it justifies deferring a
   fix, and it is the sentence the next reader trusts instead of re-deriving. It had propagated
   into the Linear ticket too (as a "Nej" heading), so the correction was two documents, not one.

#### The test-side twin: deleting a defect test can unpin the field

The defect is pinned by a test explicitly labelled *delete this when BUT-1858 lands*. Nothing else
in the suite asserted `unit` at all — so the day the fix arrives and that test is removed as
instructed, unit persistence would be guarded by nothing, and an "always writes 'st'" regression
would pass. **A test written to be deleted must ship with the assertion that outlives it**: here,
one clause on the happy-path predicate checking an on-list unit round-trips. Ask, of every
temporary test, what goes unguarded on the day it is removed.

### A gate can be structurally unsatisfiable, and a chained command dies whole (BUT-1849, 2026-08-15)

Two failures of the same family, one day, both about the machinery rather than the code.

#### The gate could never pass, and that is a fact about the gate

`require-review-before-commit` proves a review by recording which bytes a reviewer opened,
comparing against `git rev-parse :<file>`. For a path staged as DELETED that command fails,
the sha comes back `''`, and `fileProven` opens with `if (!sha) return false`. So **every
proof for a deleted file was false forever**: no commit removing a gated `.dart` file could
pass, however many reviewers ran and passed. Not a race, not staleness — arithmetic. The
push gate carried the identical branch, which surfaced the instant the commit gate was fixed
and the very next push carried the two deletions.

It hid for two weeks because ledger mode landed 2026-08-01 and the last `.dart` deletion in
any of these repos was 2026-07-16. **A gate is only exercised by the shapes that actually
occur**, and "nobody hit it" is not evidence it works — the same reasoning as "nobody
reported it" not proving a write path works (BUT-1482).

The rule I want: when a gate blocks, ask *can this gate pass at all* before assuming the
work is wrong. Read the predicate. If it cannot be satisfied by any honest action, that is a
tool defect and fixing it IS the task — with fixtures and a mutation proof, never by routing
around. Both fixes here pin a deletion's proof to the *previous* version, so the requirement
stays real (the reviewer must have opened the content being removed) and merely becomes
performable. Both block messages now say how to read a file that is already gone, because
the old remedy — "open each file with Read" — was an instruction that could not be carried
out, and a reader following it loops.

#### A PreToolUse hook rejects the whole command string

I ran `git rm -- <two files> && git commit -F msg -- <ten paths>`. The commit gate matched
the string, refused it, and **neither half ran** — so the deletion I believed I had staged
was never staged. I then told two reviewers, in writing, that the files "are now staged as
`D`". Both went and looked, and both failed the diff on it. My own comment in production
code said "deleted by BUT-1849" about a file still sitting on disk.

The shape: a blocking hook is not a filter on the command's last clause. **Any state change
you chain ahead of a gated command is lost with it.** Put mutations in their own call, then
verify with the command that reads the result (`git diff --cached --name-status`), never
with the intention. And never write a factual claim about repo state into a brief — or a
comment — from what you meant to do; three of the nine review rounds on this ticket were
spent on exactly that.

#### Corollary on reporting

The lesson from BUT-1838 ("a correction fails the same way the original did") repeated here
in a new place: of nine review rounds, every blocking finding was a sentence about code
elsewhere, and **three were my corrections landing worse than what they replaced** — one
turned a hedge into a false universal, one attributed two tests to the wrong ticket, one
claimed all builders funnel through a helper when three do not. Before shipping a
replacement sentence, verify it at the same cost as the original. A reviewer-requested
rewrite is not pre-verified.

### `git commit -- <pathspec>` silently drops every NEW file (BUT-1838, 2026-08-14)

Staging by explicit pathspec is the repo rule when a parallel session shares the working
copy, and `git commit -F msg -- <paths>` honours it — for **tracked** files. Untracked ones
it ignores completely. A commit that was supposed to carry a new Cloud Functions module
landed as: `index.ts` exporting three callables that did not exist, a trigger importing a
module that did not exist, and the DELETION of the file it replaced. HEAD did not compile.

Nothing complained. The commit succeeded, every lefthook gate passed (they run on the staged
diff, which was internally consistent), and the only visible tell was the file COUNT in the
commit summary being smaller than the set I had named. I read that number and moved on.

Three habits, in order of cheapness:

1. **`git status --porcelain | grep '^??'` before every pathspec commit.** Untracked files
   are the failure mode; a `??` line for a path you just named is the whole diagnosis.
2. **Count.** `git show --stat HEAD | tail -1` against the number of paths you passed. They
   should match. When they do not, the difference is almost always new files.
3. **`git add -- <paths>` FIRST, then commit with the same pathspec.** `add` picks up
   untracked files; the pathspec on `commit` then keeps a parallel session's staged work out.
   Both halves are needed: `add` alone risks the other session sweeping you, `commit --`
   alone risks this.

The generalisation is worth more than the git trivia: **a partial-commit mechanism fails
CLOSED for edits and OPEN for additions.** Any tool that filters "what to include" by naming
things is only safe for things that already exist in whatever index it filters. The same
shape bites `git stash push -- <paths>`, `git diff --cached <paths>` used as a review scope,
and a reviewer marker that pins "the staged files" — the file nobody staged is invisible to
all of them, and invisible reads as fine.

Recorded rather than amended, per the repo's no-amend rule, so the broken intermediate commit
stays in history with its own explanation. That is the right trade: a reader bisecting
through it needs to know why one commit does not build, and a rewritten history would have
hidden exactly the failure this lesson is about.

### "Affected users" is a claim with a timestamp, and an enum is not coverage (BUT-1846, 2026-08-14)

A retired dropdown value (`digestFrequency: 'daily'`) crashed the notification settings
screen. The fix was right. Two things I wrote around it were not, and both were caught by
reviewers rather than by me.

#### 1. I asserted an affected population I had never counted

The doc comment said "these users have been receiving the weekly digest all along" and
"most affected documents still say `'daily'`". Two independent reviewers ran the same two
commands I had not:

```
git show -s --format=%ci 920256e9e   # 2026-03-27 09:57:58  option added
git show -s --format=%ci 77ba0bd30   # 2026-03-27 10:12:03  option removed
```

Fourteen minutes. No shipped build ever offered it, and `accepted-deviations.md` already
records that the app is not live, so the leftover data is test data. The *code* was right
either way — totality is the point — but the justification was fiction, and it would have
been quoted by the next person as evidence about real users.

The trap is that the bug's SHAPE suggests a population. A retired value implies people who
chose it; a broken screen implies people who hit it. Neither implication survives one
timestamp check. So: before writing a sentence about who is affected, date the window
(`git show -s` both ends) and check whether the app is live. If the answer is "nobody, and
it doesn't matter", say that — "whether such a document exists is beside the point, the
parse has to be total" is a stronger argument than an invented user anyway.

#### 2. The enum killed the crash class, and killed my test with it

Making the field `enum DigestFrequency { never, weekly }` makes the SDK's exactly-one-match
assert unreachable for every inhabitant of the type. That is the fix working. It also made
my own `expect(tester.takeException(), isNull)` **analytically unfailable** — a line whose
comment claimed it was "the primary proof".

Worse, exhaustiveness hid two real gaps. The `default`-less `switch` proves every enum
value gets *a* label; nothing proved it gets the *right* one. Repo-wide, no test read either
label. Swapping the two arms compiled and left the whole suite green, while a weekly
subscriber would read "Aldrig" on screen — the same lie as the bug being fixed. Separately,
dropping the `digestFrequency:` argument from `_copyPreferences` also stayed green: nothing
tapped the control.

**Compiler exhaustiveness is a proof about the SET, not about the MAPPING or the WIRING.**
When a type change removes a failure mode, ask what the old test was actually catching and
whether anything still catches it. Here the honest replacements were an item-list assertion
(`dropdown.items!.map((i) => i.value).toList() == Values` — the gate for the day someone
hand-writes the list again) and a test that taps the control and captures the save. Both
mutation-proven; the unfailable line stayed, relabelled as the cheap guard it is.

#### 3. Operational: a commit gate that outlives the tool timeout

The pre-commit suite here runs 400–600s. The Bash tool caps at 600s, and `run_in_background`
plus `nohup` both died with the shell — the log stopped after the first gate. What survived
was launching it fully detached from the shell's process group:

```
powershell -Command "Start-Process -FilePath 'C:\Program Files\Git\bin\bash.exe' \
  -ArgumentList '-lc','cd /c/repo && git commit -F msg > run.log 2>&1' -WindowStyle Hidden"
```

then polling `git rev-parse HEAD` until it moves. Three timed-out attempts each left a stale
`.git/index.lock` behind — and in a shared working copy you cannot assume a lock is yours.
Check its mtime against your own last attempt, and check that no live `git.exe` is doing
anything but read-only status queries, before removing one.

### A 403 that names a permission can still be a wrong-identifier bug (2026-08-13)

`firebase deploy --only firestore:rules --project butlery-app` failed four times across a
session with `HTTP Error: 403, Caller does not have required permission to use project
butlery-app`. I diagnosed it as expired credentials, then as a missing IAM role, told Malin
her account lacked the permission, and asked her to re-authenticate. She did; it failed
again.

The project id is `butlery-app-1`. `butlery-app` is a DIFFERENT project that this account
genuinely cannot use — so the error was accurate, specific, and about a resource I had
invented. `firebase projects:list` prints display name and project id in adjacent columns,
and `butlery-app` is the display NAME of `butlery-app-1`.

What made it expensive is that the error message was consistent with my wrong theory. A 403
naming a permission reads as an authorisation problem, so I kept fixing authorisation. The
tell was there from the first run: the error quotes the identifier back, and I never checked
that identifier against `.firebaserc` or the project list.

So: when a cloud command fails on identity, **first re-read the identifier in the error and
resolve it against the project's own config**, before touching credentials. `.firebaserc`,
`--project`, and the display-name-vs-id column are all cheaper to check than a re-auth. And
never ask the user to fix an account problem until the resource name has been verified — I
sent Malin to re-authenticate an account that was working the whole time.

Corollary already in the digest, from the other direction: a deterministic tool's verdict
must be RUN, not predicted. This one was run — four times — and the output was read through a
theory instead of literally.

### A comment that MAPS assertions to failures is itself an untested assertion, and mine was inverted (2026-08-13)

Two assertions pinned a two-sided invariant, each mutation-proven against the edit it exists
for. I then wrote a summary line — "the first assertion below catches (1); the second catches
(2)" — and it was backwards. My own probe output said so: mutant A (the DTO dropping a null
key) reddened the FIRST assertion, mutant B (stamping a creatorId) reddened the SECOND, and I
had numbered the edits in the other order two paragraphs above.

The damage is specific and worse than a wrong sentence. That line exists to tell a future
simplifier which assertion is load-bearing for which edit. Followed literally, it sends them
to check assertion 1 against edit (1), watch it not fire, and delete the only guard against
the other edit. And the second assertion passes VACUOUSLY under that edit — absent key and
null value both read as null — so the suite stays green afterwards.

Three things worth keeping:

1. **A mapping claim has a truth value and a cheap check.** I had the evidence on screen when
   I wrote the line: two probe runs, each naming the assertion that reddened. Re-read the
   probe output against the sentence before shipping the sentence.
2. **When two assertions guard one invariant, state which one is vacuous without the other.**
   The pair only works because assertion 1 removes a degree of freedom assertion 2 cannot see.
   That is the fact a simplifier needs; "both are needed" without the mechanism invites the
   deletion.
3. Same class as the false comments this sprint kept producing, one level up: not a claim
   about another file, but a claim about my own tests' behaviour, which is exactly as easy to
   get wrong and exactly as invisible to the analyzer.

### 2026-08-13 — Loosening a gate means finding the OTHER gate that enforced it

Malin decided the sprint engine may build routed rules/GDPR tickets and park them In Review
instead of refusing them. The selection-time gate was four lines and obvious. Changing only
those four lines would have shipped a policy that did nothing except waste a slot per ticket:
the commit-time backstop still held any batch whose worker reported an unrun panel, and a
worker building a rules ticket reports one every time. The engine's own comment said so —
that pairing is why the same "build and park" policy was withdrawn in August after a run lost
four of seven finished tickets to the stash.

Two more things only visible from reading the whole path:

1. **The report asserted something the code did not do.** It said parked tickets "are already
   in the In Review list above". They were not — `panelOwed` fed neither `verifiedDoneIds` nor
   `needsReviewIds`, so a parked ticket would have been closed as Done. Invisible for a week
   because the policy that populated the array had been turned off, which is the only reason
   nobody shipped an unreviewed rules change under a green report.
2. **The metrics row was keyed to the wrong list.** Declined reviews were logged for BLOCKED
   tickets only. Under the new policy those are exactly the tickets that do not exist, and the
   ones that do get built would have logged nothing — the precise silence that logging step
   was built to end.

Three habits:

- Before relaxing a gate, grep for every other place that reads the same signal, and read what
  each does with it. A gate that stops something is rarely the only one.
- When a code comment explains why a policy was WITHDRAWN, that comment is the test plan for
  re-adopting it. Read it as a list of what must change, not as history.
- A prose claim in a generated report ("these are already in the list above") is an untested
  assertion about code, same as a comment. Check it against the list-building code, not
  against intent.

Also: made it a per-repo config knob rather than a blanket change, because the engine is shared
with binge and webbkollen, whose backlogs do not have this problem and whose default should not
move under them.

### 2026-08-13 — "It's the tooling, not the app" is a claim, and half of it was false

Malin asked me to prove or disprove BUT-1779 by driving the real app. The app came up blank
and clicks kept landing on the wrong widget. I reported both as local tooling flakiness and
moved on. She asked one question — "but why is the app not working?" — and one of the two
was a real, measurable app defect that has been live the whole time.

**The blank screen was tooling.** `flutter run -d web-server` in debug mode loads every DDC
module and then holds `main()` behind the DWDS handshake, which needs the Dart Debug Chrome
extension. Without it the page sits white forever with no console error: 3251/3251 modules
loaded, `flutterCanvasKit` present, `$dartRunMain` defined and never called. Diagnosis is
three checks — `$dartLoader.loader.numLoaded` vs `numToLoad`, `!!document.querySelector('flutter-view')`,
and whether `window.$dartRunMain` exists. Calling `window.$dartRunMain()` from the console
boots it instantly. Do that instead of restarting the dev server; each restart with a changed
`--dart-define` invalidates the build cache and costs another full recompile (I burned four).

**The clicks were the app.** `FeedbackFAB`'s semantics node is the full viewport
(`0,0,1707,735`, `role="button"`, 36 descendant semantics nodes) even though the widget is a
`minTouchTarget` Container in a `Positioned`. Every tap bubbles to it, so with semantics on,
the feedback dialog opens instead of the control the user touched. Filed as BUT-1837.

What actually went wrong in my process:

1. **I bundled two symptoms under one cause because they appeared together.** Same session,
   same screen, both "the harness is being difficult". They had nothing to do with each other,
   and grouping them is what let the real one ride along unexamined.
2. **"Not my code" is the conclusion that most needs evidence, not the least.** It ends the
   investigation. I should hold it to the same bar as a bug claim: name the mechanism, show
   the measurement. I had neither when I wrote it.
3. **The measurement was cheap and I never took it.** One `getBoundingClientRect()` on the
   offending node settled it. I had already been fighting the symptom for an hour by then.
4. **The workaround attempts were the evidence, and I read past them.** `pointer-events:none`
   not helping means the listener is on an ANCESTOR, not an overlay — that is a structural
   fact about the tree, and it was in front of me two attempts before I acted on it.

Corollary for driving Flutter web at all: with semantics forced on (`main.dart` does this on
every web start), the semantics DOM is what receives clicks, so a malformed node breaks
automation *and* real users identically. That equivalence is why the automation trouble was
worth diagnosing rather than working around — the workaround would have hidden a live defect.

### 2026-08-13 — a helper's logs are only as safe as its CALLER LIST (BUT-1822)

`tryClearRoster` had logged a bare `conversationId` since it was written, and that was
fine: its only caller was a group-only trigger, and a group id is a client-minted UUIDv4.
BUT-1822 gave it a second caller — the GDPR deletion cascade's 1:1 branch — and a direct
conversation id is `direct_<uidA>_<uidB>`. The helper's code did not change. Its key space
did, and with it the PII profile of four log lines in a sink that outlives the erased
account. I also wrote a fifth such line myself, in the cascade, on the one code path whose
entire purpose is Art. 17 erasure — beside a `uid_prefix` field I had added *because* raw
uids must not be logged.

Both reviewers caught it independently; I caught none of it, and the passing test output
had been printing `direct_seeded` on my screen the whole time.

What generalises:

1. **Adding a caller is a change to the callee**, even when you do not touch its file. Read
   the callee's logs, its bounds and its error paths against the NEW caller's inputs — the
   ids, sizes and shapes it will now be handed for the first time. A prior review that
   judged a line safe ("group ids are opaque") was judging the caller list, not the line.
2. **A document ID can be PII.** Field-keyed probes and `hasOnly` allowlists are blind to
   it, so no residual check will ever alarm on it. The same fact decided a second finding:
   a conversation left standing keeps `direct_<erasedUid>_<...>` in its own id, so the step
   must report the erasure INCOMPLETE — nothing downstream can notice on its behalf.
3. **A comment that promises an alarm has to be true.** I wrote "the step lands in
   `failedCollections`" about a branch that returned `true`. The honest fix was to make the
   code match the comment, not to soften the comment — an erasure that did not finish must
   not be reported as finished.
4. **A mutant that does not compile is not a red test.** Three of seven probes removed a
   declaration's last use, so `tsc` refused and the run produced no FAIL lines at all —
   which reads exactly like a green suite if you only count reds. Assert the suite RAN
   (grep its summary line), and keep every symbol used when mutating.

### An ARB edit rewrites the WHOLE file, which a parallel session makes uncommittable (BUT-1783, 2026-08-13)

Removing two strings from `lib/l10n/app_sv.arb` and `app_en.arb` produced a **918-line
diff** in each: a PostToolUse hook re-serialises the ARB with a JSON pretty-printer, so
every inline `"count": { "type": "int" }` in the file expands to three lines. The two
deletions I intended were four lines of it.

That is only noise until a second session is editing the same files — and one was. A
key-set comparison against `git show HEAD:<file>` (parse both as JSON, diff the key sets,
diff the values) showed my two removals **plus eight `chatGroup*` keys that were not
mine**. `git diff` could not show me that: the reformat buried the real content change,
and `--ignore-all-space` still printed hundreds of lines because the change is structural,
not whitespace-only.

So the ARB and its `gen-l10n` output stayed OUT of the commit. The Dart no longer
references either getter, so nothing dangles; the string removal rides along with the
other session's commit. Leaving an orphan ARB key behind is safe here — checked, there is
no unused-key lint in `lefthook.yml` or `tools/`.

What generalises:

1. **Compare KEY SETS, not diffs, when a generated or auto-formatted file is shared.** Two
   lines of `python -c` parsing both revisions as JSON answers "whose changes are in this
   file?" definitively. A reformatting hook makes `git diff` useless for exactly the
   question the parallel-session rule needs answered.
2. **A hook can widen your diff far past your edit.** Check `git diff --stat` after
   touching any file a hook formats, before assuming the commit is yours to make.
3. **Dropping a file from a commit is a legitimate move**, not a failure — but say which
   file and why, and verify the remaining diff still compiles and analyses clean on its
   own. An ARB key with no reader is inert; a Dart reference to a deleted getter is not.

### A model field that reaches Firestore is a RULES change, and `hasOnly` fails closed in silence
Date: 2026-08-12
Trigger: BUT-1482 added `configRevision` to `TagResult` on 2026-07-23 and did not touch `firestore.rules`. `isValidTagResult` gates recipe writes with `tagResult.keys().hasOnly([...11 names...])`, so from that day **every recipe create AND update was denied in production** — for every user, because the five `tagConfigs` documents exist and carry a `version`, which makes `TagGenerator` stamp the field on every run. It shipped, and nobody noticed for three weeks: the last recipe in the account was saved 12 July, eleven days before the break. I found it on 2026-08-12 while reading `firestore.rules` for an unrelated plan (BUT-1817's tagResult merge), not from a bug report, and confirmed it in three escalating steps — an emulator probe against the real rules file, the DEPLOYED rules read in the console (identical), and finally a real save on Malin's phone: `PERMISSION_DENIED` at `users/{uid}/recipes/{id}`, "Failed to create Recipe". The fix was one name in a list.
Rule: A field added to a model that serializes into Firestore is a two-sided change — the model AND the rules — and the rules side has no compiler, no analyzer and no test unless you write one. `hasOnly` is the most dangerous shape in the file: it fails CLOSED, silently, on the WRITE, so nothing in the app logs an error the user would report; it simply stops working. So: (a) when you add a field to any model with a `toFirestore`, grep `firestore.rules` for that model's validator in the SAME edit; (b) a `hasOnly` allowlist gets a rules test the day it is written, asserting one allowed key set and one rejected extra key — the suite here had eleven recipe tests and none of them would have caught this; (c) "nobody has reported it" is not evidence a write path works, because a write path that nobody exercised for three weeks reports nothing. The generalisation of the wrong-path-Firestore-read lesson: a write that passes Dart and is denied by rules is invisible from the Dart side, and only a rules test or a real device sees it.
Example: 2026-08-12 — `configRevision` added to the allowlist with a bounded-int check, two regression tests (one allow, one reject a non-int) in `firestore-rules.test.ts` naming the outage in their comment, rules deployed, and a real save on the device verified in Firestore carrying `configRevision: 999697`.

### A formatter race can revert your CODE and keep your COMMENTS (2026-08-12, BUT-1693)

Twice in one session an external writer (formatter hook, or the parallel session) rewrote
`household_service.dart` from a stale buffer between my Edit and my next command. Both times
the Edit tool reported success. The dangerous shape is not the plain revert — it is the
HYBRID: the second time it restored the old code while keeping the new comments, leaving the
flag-off branch returning `null` under a comment explaining why it returned an empty map.
That is the exact ignorance-vs-knowledge conflation two reviewers had already made me fix,
re-introduced silently, describing itself correctly the whole way down.

What caught it: the SUITE, not the analyzer (the hybrid compiles clean) and not a re-read
(the comments look right). What would have shipped it: trusting "the edit applied cleanly".

So, in a repo where anything else writes files:
- After an Edit that carries behaviour, `grep` for the changed TOKEN — not the comment
  beside it — before moving on. A comment surviving is evidence of nothing.
- Prefer one atomic write (a `python` patch script asserting its anchors) over several Edits
  when the change spans a file; it fails loudly instead of half-landing.
- `md5sum` the file, stage it, then compare `git show :<file> | md5sum` against the tree
  before running the review gates. A verdict is scoped to bytes, and staging is what pins
  them.
- Re-run the suite after ANY edit to a file that has been reverted once, including a
  comment-only edit. That is the run that found this.

**Same day, same file, second source: a REVIEWER's mutation probe was left live.** The
testing agent reported "both probes reverted byte-identical, md5sum -c OK" and the analyzer
then found `if (false) {  // MUTANT: flag gate removed` in the shipped tree — which would
have read every household's shared allergen lists with the feature switched off. So: a
subagent's claim to have restored a file is a claim about ITS run, not about the file. After
any review that says it mutation-probed production code, grep the file for the probe's
shape (`if (false)`, `// MUTANT`, a commented-out guard) and re-run analyze before staging.
The index saved this one — the good bytes were already staged, so `git checkout -- <file>`
restored them exactly.

**Three times in one day, not once.** Two more reviewer probes reached the tree as FILES:
`zz_probe_review_test.dart` and `overflow_discrimination_probe_test.dart`, both opening with
"THROWAWAY … delete after", both left behind by agents whose reports said the probe was
removed. One was found by another reviewer reading `git status`, one by the analyzer warning
about an unused import inside it. So the check is mechanical and belongs in the pre-commit
routine, not in trust: after ANY review round that mentions probing, run
`git status --porcelain` plus `find test -name "*probe*" -o -name "zz_*"` and
`grep -rn "MUTANT\|THROWAWAY\|if (false)" lib/ test/`. A probe file is untracked, so it
never shows in `git diff` — only `status` and the filesystem see it, and a parallel session's
`git add .` would sweep it in.

### A rules branch that keys on an ABSENT parent cannot tell "not yet" from "gone" (2026-08-12)

`conversations/{id}/participants` got its first `match` block this sprint. Group creation
writes the roster before the top-level conversation document exists, so the read rule needs
a permissive branch: `parentNames(uid) || (parentDoc() == null && <you hold a row>)`. I
scoped that branch deliberately, wrote a fixture (P12B) proving an evicted member with a
LIVE parent is denied, and recorded in the block comment that the scoping "closes it".

It does not. Firestore rules cannot distinguish a parent that has never been written from
one that has been deleted, so `parentDoc() == null` becomes true again for any conversation
somebody deletes — and the roster subcollection does not cascade. The reviewer probed it:
after a parent delete, a member LISTs (allow), a stranger SEATS a row (allow), and then
LISTs (allow).

Two deleters, and the sharper one is the very Cloud Function the comment cites as the
reason the branch needed scoping. `enforceGroupMinorMembership` evicts non-friend-added
minors; when that leaves fewer than two members it deletes the whole conversation. So in
its collapse branch the evicted MINOR keeps roster read on a group they were removed from,
which is the exact child-safety outcome P12B was written to close, one subcase over.

Three things worth keeping:

1. **Enumerate every deleter of the parent before shipping a branch that keys on the
   parent's absence** — the client `allow delete` rule and every CF, not just the writers.
   The fix cannot live in rules; rules cannot delete and cannot see the difference. Here it
   is a code fix: the CF now deletes the roster row alongside the membership mirror.
2. **Seed the subcollection production really seeds.** The integration test created
   conversations and membership mirrors but no roster rows, so a cleanup assertion would
   have passed over an empty collection. I added the rows to the shared helper first, then
   the assertions, then mutation-tested: with the roster delete removed, the update branch
   and the collapse branch both redden and the keep path stays green.
3. **"Closes it" in a comment is the claim most worth attacking**, and this one was written
   by me in the same edit that created the hole it describes. The residual sentence now
   names both remaining cases — the pre-seat hole and the user-initiated delete — rather
   than asserting a closure that a five-minute probe disproves.

### Fixing the ARB after running gen-l10n ships the OLD string (2026-08-12, BUT-1693)

I corrected one character in `app_sv.arb` — a German low-9 opening quote `„` to the Swedish
`”` — in an Art. 9 consent body, minutes after `flutter gen-l10n` had already run. The
generated files kept the wrong character, and that is what the dialog renders. Nothing in
the repo could catch it: `dart analyze` compiles a stale constant happily, and the widget
tests assert copy by ROUTING (`find.text(sv.householdAllergenShareTitle)`), so test and
production read the same generated getter and drift together. Two reviewers found it only by
comparing every ARB key against its generated getter at code-point level.

Two mechanical habits:
- After ANY ARB edit, re-run `flutter gen-l10n` and grep the generated `app_localizations_*.dart`
  for the changed substring. The repo's `regenerate-l10n.sh` hook `exit 0`s silently when
  `flutter` is not on PATH (the standard Windows git-bash gotcha), so "the hook handles it"
  is not true here.
- For a string whose exact wording is legally load-bearing, compare it BYTE-WISE against its
  source of truth (the approved annex), not visually — `„` and `”` are one glyph apart on
  screen and one code point apart in the file.

### A multi-edit script that asserts before it writes loses EVERY edit, silently (2026-08-12)

Pattern used all sprint: read a file, apply N `assert old in s; s = s.replace(...)` pairs,
write once at the end. It is atomic, which is the point — but the failure mode is that a
single wrong search string aborts the run and **nothing is written, including the edits that
matched**. Twice in one session I then told a reviewer the fixes were taken. Both times the
reviewer read the bytes and told me they were not.

The first loss was invisible because a later call fixed one of the three by hand, so a
partial success masked a total failure of that script. The second was invisible because
comment-only edits produce no test and no analyzer signal — there is nothing to go red.

Three habits, in order of how much they buy:

1. **Grep the changed TOKEN after every edit that carries no test.** Not the file, not the
   comment beside it — a distinctive fragment of the new text, and print the count. Cheaper
   than a review round and it cannot be argued with. Already a lesson for code; it applies
   at least as hard to prose, because prose has no other verifier.
2. **One edit per script when the edits are independent.** The atomicity a multi-edit script
   buys is worth having when the edits must land together; when they are unrelated
   corrections, it converts a typo in edit 3 into losing edits 1 and 2.
3. **Never write "taken" in a handoff without the grep output.** A reviewer re-reading bytes
   is the most expensive way to discover a failed `str.replace`.

The deeper point is the one already in the digest and now proven from the other direction:
an Edit tool success is not proof the bytes moved, and a claim about your own edits is a
claim like any other — it needs evidence, and the evidence costs one command.

### A rules block that ATTESTS on a parent must first establish WHERE that parent is written, and WHEN (2026-08-12)

`conversations/{id}/participants/{participantId}` had no `match` block at all — it fell to the
terminal default-deny, so `ConversationParticipantModule.addParticipants` was refused on every
group and direct conversation create, and `batch.commit()` threw out of
`createGroupConversation`. One of five `hasOnly`-family drifts found after the three-week
recipe-save outage.

The obvious rule — `get()` the conversation and check `participantIds` — denies GROUP creation
permanently. `FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`, so the
group document is written under `users/{uid}/conversations/{id}`, while the roster goes to the
TOP-LEVEL path, whose parent only materialises when the first real message is sent (BUT-1795).
My stated premise — "same batch, so the parent isn't committed yet" — was wrong in a way that
would still have produced a working-looking rule for direct chats and a permanently broken one
for groups. Direct conversations write and AWAIT their parent before the batch; groups never
write it at all.

The shape that survived is `attested || unclaimed`: the parent names you, OR the parent is
absent and you hold a row. Plus own-row read, and a narrower delete than the parent block.

Four things worth keeping:

1. **Establish the write ORDER before writing the predicate.** Not from the call site's shape
   ("it's one batch") but from the repository: which mixin decides the path, and whether the
   parent write is awaited.
2. **Prove it by committing the writer's REAL `WriteBatch`**, not a hand-written fixture. A
   hand-written payload is the mechanism that let all five drifts through in the first place.
3. **Attribute a batch deny with a mutation probe.** The emulator prints a rule line for the
   wrong row inside a failed batch, which reads exactly like a second, independent deny and is
   not one.
4. **A permissive branch keyed on an ABSENT parent has more actors than the one you designed
   it for.** This one was written for the creating client; it also grants the outsider who
   guesses the id, every conversation anyone later deletes, and — the one that took four
   review rounds to surface — every seated member during the window before the first message,
   including a minor the eviction trigger has not reached yet, because that trigger fires on
   the parent document that does not exist yet. Enumerate actors and lifecycle states, not
   just the happy path.

### A sentence about code in another file is a claim; open that file or do not write it
Date: 2026-08-10
Trigger: BUT-1819 — one ticket, three commit gates, four review passes. Zero defects were found in the LOGIC after the first pass. **Eleven** were found in my prose, every one a confident assertion about code I had not opened: (1) "eleven scheme checks exist, none view-callable, none requires a host" — `FormValidators.url()` is public, in `lib/core/`, and requires a host WITH a dot; (2) the correction then called its sibling `recipeSourceUrl()` stricter too, when it returns valid for anything containing the word `Butlery`, so the seed string this very ticket introduced passes it — wrong in both directions on two consecutive passes; (3) a citation to a BUT-1819 accepted-deviation entry that did not exist in either deviation file; (4) "only 2 of the 30 files in `core/utils` import a model and a service" — zero do both, three do one, and there are 31 files; (5) "every other field is passed through untouched" while `copyWith` restamped `updatedAt` and recomputed `dataChecksum`; (6) the fix's own justification then invented a "last-write-wins reconciliation" on the offline path — grepped by a reviewer, no such code anywhere, the real reasons being sort order and caller honesty; (7) "the complete set of writers for this collection" — four more partial-field writers on the client, five in `functions/src`; (8) `updateBatch` listed as a covered path when it lives on a mixin this class does not use, so it cannot be called at all; (9) "nothing populates `ingredientsNormalized` before a write" — two copy factories do, both currently uncalled; (10) a security fix's comment claiming it now rejects control-character titles, when `validateRequiredFields` tests key PRESENCE only and the accepted set is provably identical; (11) a test header claiming every fixture is a real stored value, in the same commit that renamed one of them. Three separate specialists caught them; I caught none. The two that mattered most were (5), a real behaviour bug the comment concealed, and (10), the sentence a future reader would have cited as proof that empty titles are rejected.
Rule: Treat a sentence naming a symbol, file, count or behaviour outside the file you are editing as a CLAIM with a verification cost, and pay it before writing: open the file, run the expression, count the matches. Three shapes recur and each has a cheap check. A claim about which methods a class HAS is settled by its declaration line, not by the base class's source — a mixin the class does not use contributes nothing. A claim of the form "nothing does X" must grep including dead and uncalled code, then say "nothing on a live path" if that is what the grep supports. A claim that a guard REJECTS something must be read in the guard's own body — `containsKey` is not emptiness — and if it turns out not to reject, that is a product decision to surface, not a comment to write. When a reviewer disproves one claim, re-read every other claim in that file: they were written in the same state of belief, and (2) above is what happens when only the disproved one is fixed.
Example: 2026-08-10 — every one of the eleven rewritten to state what the code does, several keeping a dated note of what the false version said so the next reader can see the trap; the ticket's four guards mutation-tested separately, which is what kept the logic clean while the prose was not.

### Routing a call through a new helper adds a DEPENDENCY every existing test double must model
Date: 2026-08-10
Trigger: BUT-1819 routed `LinkifiedText._openUrl` through a shared `openExternalLink` helper — labelled defence in depth, "cannot change behaviour", because the regex upstream only matches `https?://`. It did change behaviour. The helper asks `canLaunchUrl` before launching; the old code did not. `linkified_text_test.dart`'s `_RecordingUrlLauncher` implements `launchUrl` and not `canLaunch`, so the base method's `UnimplementedError` fired, the tap recorded nothing, and "tapping a linkified URL opens it via url_launcher" went red — a real user-facing regression in ordinary comment links. It survived six review passes and four full test runs because every run named the folders I had EDITED (`test/unit/repositories/`, `test/widget/recipe/`, `test/unit/services/offline/`) and the broken test lives in `test/unit/widgets/common/`, which I never had reason to open. Worse, the same commit had just added a `try/catch` to that call site, so the loud `UnimplementedError` became a silent swallow — my own change hid the symptom from the only place it would have shown.
Rule: A call site rerouted through a shared helper inherits the helper's whole dependency list. The first repair was to complete the double (`canLaunch => true`); a reviewer then asked the better question — should the helper ask at all? It should not: the plugin documents `canLaunchUrl` as answering a PERMISSION question ("will always return false unless the application has been configured to allow querying"), Android declares the `<queries>` entries and `ios/Runner/Info.plist` declares no `LSApplicationQueriesSchemes`, so on iOS the gate could refuse links that would have opened — silently, since `_openUrl` does not read the result. Dropping it left the test double byte-identical to HEAD, which is the tell: **a test that only passes once you extend a double is asking whether the new dependency belongs there at all.** Answer that before extending. So before calling any such reroute "defence in depth, behaviour unchanged": diff the helper's calls against what the old line did (`canLaunchUrl` was the entire difference here), then run the suite that covers the REROUTED file, found by grepping the dependency's name across `test/` — not the folders you edited. The changed-file set is the wrong unit for a change whose blast radius is a shared function. And when adding a `catch` in the same commit as a behaviour change, remember it can convert the new failure into silence: add the catch after the suite is green, or run once without it.
Example: 2026-08-10 — five files in the repo touch url_launcher; all five now run and pass, and the double carries a `canLaunch` override with a comment naming BUT-1819 as the reason it exists.

### [Workflow] Judging what a PHOTOGRAPH shows by reading its OCR text is a measurement of the OCR, not of the page — and it was wrong four times in two days
Date: 2026-08-09
Trigger: BUT-1816's orphan-tail trim. I hand-graded the ten corpus pages the rule fires on by reading their extracted text, reported "8 of 10 right, 2 wrong" to Malin in a report, a decision-log entry and a plan gate, and recommended against the two. Malin read the report and said the two looked correct to her. Opening the actual JPEGs settled it in one glance: `Olika fyllningar med vaniljkräm` and `Djupfrysning av tårtor` are display headings in large type at the page foot with nothing readable under them, not subheadings inside the recipe above — 10 of 10 were correct cuts, and two more (`Sina ingredienser`, `Sina ingr`) are not from the cookbook at all but from the back-cover blurb of a different book lying on the table behind it, which no amount of text-reading could have revealed. The SAME text-only method had already produced the gate verdict that killed half the plan (the nine tails in the 120-200 band, called "subheadings inside a recipe"; re-read against the photos, `Chokladkräm` is a complete little recipe and `I stället för sås` is a new section's heading — verdict right, reason wrong). This is the second time in the same ticket Malin corrected the same reflex: a week earlier I had written in two files that the corpus was scanned material, having never opened an image, when it is her own phone photos with her thumb in frame. Pushing further, she pointed out that the corpus GOLD is graded by me, not her — and a spot check found the same disease at the base: frame-cut half recipes recorded as complete ones (2 of 7 pages opened, ≥12 of 242 by an automated screen), which means recall rewards keeping exactly the debris this ticket removes.
Rule: When the artefact under judgement is an IMAGE, text derived from it is evidence about the derivation, not about the artefact. Layout, type size, column structure, what is physically absent from the frame, and what belongs to a different object in the photo are all invisible in the extracted string, and every one of them decided a case here. So: before grading, labelling, or writing a verdict about photographed material — and always before recording one in a decision log — open the images. Ten JPEGs is a few minutes; a wrong verdict in `ACCEPTED_DEVIATIONS.md` outlives the session that wrote it. The corollary is the harder one: a GROUND TRUTH built the same way inherits the same blindness, so before quoting precision/recall as evidence, ask who graded the gold and by what method. Gold that never asked "is the whole recipe even on this page?" does not merely add noise — it encodes the opposite policy from the one being built, and the metric then penalises the feature for doing the right thing.
Example: 2026-08-09 — all ten shipped cases and all nine band cases re-read against the photographs; `orphan_tail.dart`'s library doc now lists all ten with what each actually is and ends with "if you are about to re-judge this list, open the images"; both deviation files carry a dated correction that keeps the retracted reasoning visible; the gold defect is written up with photographs and filed as its own ticket rather than folded into this one.

### [Workflow] A gate that filters its results AFTER running the check pays full price for output it throws away — and scoping the input silently disarmed it
Date: 2026-08-07
Trigger: Malin asked whether the Stop hooks were worth their runtime. Measured: `stop-check.mjs` runs `dart analyze --fatal-infos` over all 2,727 Dart files — 6m47s cold, 4m10s warm — then keeps only the findings whose file appears in this session's edit manifest and discards the rest as another session's. So the whole-repo scan was billed on every stop and its extra coverage was thrown away by design, including on turns where this session had touched no Dart at all (any dirty `.dart` in the working tree, from any session, was enough to trigger it). Scoping the command to the session's own files took it to ~11s. Then the fix itself went silently toothless: given explicit file arguments `dart analyze` prints BARE BASENAMES (`zz_gate_probe.dart`) instead of package-relative paths, so no manifest entry matched, and a deliberate type error came back FOREIGN_ONLY → exit 0. The gate reported clean on code that does not compile.
Rule: Two things, and the second is the expensive one. (1) When a gate discards results by a criterion it already knows BEFORE running — session ownership, changed-file set, a path filter — push that criterion into the command's input instead of the output filter; work whose result is structurally guaranteed to be dropped is not extra safety, it is just latency. (2) Narrowing a checker's input CHANGES ITS OUTPUT FORMAT, and any downstream parse of that output is now on a different contract — path shape is the classic one (`dart analyze` relativises to what you handed it, so one file yields a basename and a package yields `lib/…`). After scoping, the ownership partition was not merely redundant, it was actively wrong, and every finding matched nothing and vanished. So: mutation-test a gate after every change to it, never only before — a deliberate error in a file the gate is supposed to own is the one assertion that distinguishes "fast" from "no longer checking anything".
Example: 2026-08-07 — `stopCheck.command` gained an optional `{files}` placeholder (opt-in per repo; the two Next.js repos keep `npm run typecheck`, since passing files to `tsc` bypasses the project config). Deletions are filtered out, oddly-named paths disable scoping rather than reaching the shell, and long lists chunk at a 6000-char budget (verified: 300 files → 2 runs, each file exactly once). The partition is now skipped whenever the run was scoped, because the scope already was the ownership filter. Butlery: 4m10s → ~11s on a session-owned change, ~1s on a turn that changed no Dart.

### [Architecture] A global `Shortcuts` layer mounted in `MaterialApp.builder` OUTRANKS Flutter's text-editing keys — a bare Backspace binding silently disabled deletion in every text field
Date: 2026-08-07
Trigger: Malin reported she could not erase a mistyped character in the login screen's password field. Nothing in `auth_view.dart` explained it — plain `TextFormField`, plain controller, no formatter. The cause was three files away: BUT-521's a11y keyboard layer binds bare Backspace to `NavigateBackIntent`, and `butlery_app.dart` mounts that `Shortcuts` widget inside `MaterialApp.builder`. `WidgetsApp` builds `Shortcuts(default) → DefaultTextEditingShortcuts → … → builder(child)`, so anything the builder returns is a DESCENDANT of the framework's text-editing shortcuts. Key dispatch walks UP from the focused node, so the app's layer sees Backspace first, `CallbackAction` is always enabled, the event is marked handled, and `DeleteCharacterIntent` is never reached. Every text field on web and desktop; invisible on mobile, where soft-keyboard deletion goes through `TextInputConnection.deleteSurroundingText` and never becomes a key event. It had shipped with a doc comment asserting the exact opposite ("text fields receive Backspace before the shortcuts layer (Flutter focus order), so this never deletes characters") and a test suite whose only key-dispatch fixture focused a `SizedBox`.
Rule: Placement inside `MaterialApp.builder` is not "top of the tree" — it is BELOW `DefaultTextEditingShortcuts`, and therefore ABOVE it in priority for a focused field. Any app-level binding on a key that also means something inside a text field (Backspace, Delete, Enter, Home/End, arrows, Ctrl+A/C/V/Z) must either be modified with a chord or disable itself while focus sits in an `EditableText`. DISABLE, don't handle-and-return-null: `ShortcutManager.handleKeypress` treats a disabled action as `KeyEventResult.ignored` and keeps propagating, which is the only way the framework's own binding still runs. A key-dispatch test that focuses a `Focus`/`SizedBox` proves the activator→intent map and nothing about the conflict — the fixture must focus a real `TextField`, use the REAL `AppActions.dispatch()` map (a capturing stub is always enabled, so it cannot fail), and mirror production's mount point by wrapping via `MaterialApp.builder`, not `home:`.
Example: 2026-08-07 — `_NavigateBackAction` in `app_actions.dart` overrides `isEnabled` to return false when `FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null`. Two tests pin both halves (a character is deleted in a focused field; Backspace still pops a pushed route otherwise); mutation-verified by forcing `isEnabled => true`, which reddens exactly the delete test. The false comment on `NavigateBackIntent` was replaced with one stating the ordering and why the action disables itself.

### [Workflow] A measuring harness that PREFERS one data shape silently drops the other — and the number it reports looks fine
Date: 2026-08-05
Trigger: Building a block-count eval for the cookbook splitter, the new tool reported 146 pages and 13 multi-recipe spreads where a throwaway Python probe over the same corpus said 181 and 48. The probe was right. `tools/corpus/corpus_paths.dart:recipeEntries` chose between the flat (`<page>/gold.json`) and nested (`<page>/recipe-NN/gold.json`) layouts by asking which FILE EXISTED, then `continue`d. 47 corpus pages carry gold at both levels, because the prelabel writes a page-level draft AND one per block, so whichever shape the transcriber did not use is left behind. On 36 of them the flat leftover is unverified while the blocks are verified — so `recipeEntries` returned one unverified entry, `corpus_eval_core` skipped it as "not verified yet", and every verified recipe on those spreads left the score without a word. That is most of the long-standing "scores 146 of 242 verified recipes" gap, which had been attributed to something else entirely and written into a plan as a known limitation. The same session had already been burned once by a broken yardstick (`_totalTime` reading prep+cook and never `timeMinutes`, reporting 0.0% for a feature that worked).
Rule: When a harness must choose between two on-disk shapes for the same fact, choose on the PROPERTY that decides truth (here: which one is `verified`), never on which file happens to exist — existence is a side effect of how the data was produced, and the loser is dropped silently because both branches look reachable. Two habits: cross-check a new measurement against an independent quick-and-dirty implementation before trusting either, and when a known coverage gap has a stated cause, re-derive the cause rather than inheriting it — "the prelabel writes one draft per page" was true AND was not why 96 recipes were missing.
Example: 2026-08-05 — `recipeEntries` now picks the level that carries the verification; the corpus eval goes 146 → 152 scored, and the split eval sees 181 pages / 48 spreads instead of 146 / 13. The step-1 splitter change was then measured against the corrected baseline, failed its own per-recipe regression limit (one recipe −29 points of ingredient-F1), and was dropped.

### [Workflow] A comment about code has a HALF-LIFE — the change that falsifies it is usually your own, one commit later
Date: 2026-08-05
Trigger: Three separate reviewers, on three consecutive commits, found the same shape: a doc comment that was TRUE when written and that MY next change made false, with nothing failing in between. (1) `text_layout.dart` shipped saying "`DeviceTextRecognizer` still returns only `recognized.text` and discards it (the seam widens in a later commit)" — the very next commit was that seam, and both halves of the sentence inverted. (2) The same file's trim paragraph described a per-page `recognized.text.trim()` and derived a rule from it; my seam change deleted that trim, so the paragraph's worked example described nothing, while the rule it justified stayed correct — the dangerous combination, because a reader who greps for the trim, finds none, and concludes the rule is stale lands exactly on the silent index shift the paragraph exists to prevent. (3) `_str`'s doc said "anything unreadable decodes to an empty string" while the code stringified a `List` into `"[a]"` — the doc described the intent, the code the first draft. Earlier the same day the same class produced a fabricated `tools/` constraint that four existing files disprove, and a Flutter-dependency claim about a file that imports only `package:clock`. Six false comments in one session, every one caught by a reviewer, none by me — on top of the four in BUT-1786 that produced the existing "a comment is an UNTESTED ASSERTION" lesson.
Rule: The existing lesson covers writing a false claim. This is the sequel: a claim that was true decays, and the agent most likely to falsify it is you, in the next commit of the same plan. Two habits it costs nothing to keep. First, when a comment names a mechanism in ANOTHER file ("X trims", "Y has no callers", "the seam widens later"), that sentence is a dependency — when you change X, grep for its name before you change anything else, the same way you would update a caller. Second, prefer comments that state the RULE and its consequence over comments that narrate the current mechanism: "do not trim either side, or every converted index is short by the removed rows" survives a refactor that "the adapter trims per page" does not. When both are wanted, put the durable rule first and mark the mechanism as of a date, so a future reader can tell which half to distrust. And when a reviewer finds one, fix the class, not the instance — check every other claim in the same file in the same pass, because they were all written in the same state of belief.
Example: 2026-08-05 — the seam commit corrected all three, and the trim paragraph now records BOTH of its wrong drafts rather than deleting them, because the rule survived both wrong reasons and that is worth knowing. The "nothing imports this file yet" line is now dated rather than absolute.

### [Workflow] The comment is the least-verified thing you write — four false claims in one small ticket, every one caught by a reviewer
Date: 2026-08-04
Trigger: BUT-1786 paged one Firestore walk — ~120 lines of implementation plus a test. Five review rounds, and four of them found the SAME defect class: a comment asserting something the code does not do. (1) The header said removing the daily full-collection read "means stamping an expiresAt in the client and attaching a TTL policy" — both had shipped in July; `cache_entry.dart:98` stamps it, `firestore.indexes.json` declares the TTL, and a test pins it live. (2) The test's fake said an `indexOf`-based cursor model "FAILS a correct implementation" — true in general, but no fixture exercised it, and the reviewer swapped the model back and got 16/16 green. (3) The `WALL_CLOCK_BUDGET_MS` docstring said "this job declares no timeoutSeconds" ten lines above the constant that declared it — I had added the declaration and not re-read the comment above it. (4) "Semantics are unchanged against the ORIGINAL" was false for four values a client can write (`ttlDays: -5` expired instantly under `||`; `"abc"` never expired via a NaN compare). Every one was found by a reviewer, never by me, including on files I had just rewritten and believed I knew.
Rule: Treat a comment as an untested assertion, because that is exactly what it is — the compiler does not check it, the tests do not exercise it, and it is the part a future reader trusts most. Three habits, in cost order: when you ADD a declaration, re-read the comment ABOVE it (2 and 3 were both "the code moved, the prose did not"); before writing "X does not exist" or "this would require Y", grep for X (1 was two greps away); and before writing "behaviour unchanged", diff against `git show HEAD:<file>` rather than against your memory of what you edited (4). For a claim about a TEST's own strength, the only honest form is a fixture — a comment saying "this catches Z" is a hypothesis until the mutant reddens. The deeper point is that "I already checked this file" is worth nothing here: rounds 3 and 4 were on files I had rewritten minutes earlier.
Example: 2026-08-04 — all four corrected; the fake's cursor model got the fixture that pins it (surviving docs BEFORE a deleted anchor is the only shape where the two models disagree: 700 vs 799 scanned); the timeout pairing moved from a constant-vs-constant comparison to reading the v2 export's `__endpoint` deploy manifest, which reddens when the wrapper's `timeoutSeconds` is removed.

### [Workflow] A deploy that DELETES many Cloud Run services can leave its replacement in state FAILED — presence in `functions:list` is not liveness
Date: 2026-08-03
Trigger: The scheduler merge retired 14 `onSchedule` functions and created 3. `firebase deploy` reported success, the post-deploy smoke gate's name list matched, and `firebase functions:list` showed all three new functions in its table — but `dailyAnalytics` carried `"state": "FAILED"` in the JSON and had no `availableMemoryMb` or `timeoutSeconds` at all, while its two siblings from the same bundle were fine. The audit log gave two chained causes: first `Quota exceeded for quota metric 'Write requests' ... per minute per region` for `run.googleapis.com` (17 create/delete operations in one burst), then on the CLI's own retry `Container Healthcheck failed. Quota exceeded for total allowable CPU per project per region`. The deletions had not released their regional CPU yet, and this one function had just been raised to 512MiB — which in gen2 also raises the CPU request to a full vCPU. Ten daily analytics jobs would have silently not run, with their old functions already deleted. A targeted redeploy minutes later succeeded unchanged.
Rule: After any deploy that removes services, verify per-function `state` from `functions:list --json`, never the table and never the deploy's own exit code — a FAILED gen2 function still appears by name, so a name-presence smoke gate passes over an outage. Treat bulk delete+create as rate-limited work: the regional Cloud Run write quota is per MINUTE and deleted services hold their CPU allocation for a while after, so the replacement competes with the corpses of what it replaced. Raising memory in the same change makes it worse (more memory ⇒ more CPU ⇒ more quota). The recovery is boring — redeploy the single failed function once the burst has drained — but only if someone looks.
Example: 2026-08-03 — `dailyAnalytics` found FAILED during post-deploy verification, redeployed alone, confirmed ACTIVE at 512MiB/540s with all 15 scheduled functions ACTIVE. Nothing in the code changed.

### [Workflow] A hook wired to a RELATIVE path silently stops guarding the moment the Bash cwd drifts
Date: 2026-08-01
Trigger: A screenshot showed eight consecutive shell commands each printing `bash: .claude/hooks/bash-firewall.sh: No such file or directory`, alongside the same failure for `monitors/auto-firebase-monitor.sh`. Both files exist, are git-tracked, and are present in every worktree, so the obvious readings (bad checkout, deleted hook, cloud session) were all wrong. The transcript settled it: `grep -o '"cwd":"[^"]*"'` over the session's own `.jsonl` in `~/.claude/projects/` showed the cwd had moved from `C:\Butlery\butlery` to `C:\Butlery\butlery\functions`, and the error appears 34 times from that point on. Claude Code runs hooks from the shell's CURRENT directory, and all 13 project hooks were registered as `bash .claude/hooks/<x>.sh`. From a subdirectory none of them resolve. The one that matters is `bash-firewall.sh`: it is the PreToolUse guard that blocks the destructive git and `rm` commands the deny list misses, and its failure is reported as NON-BLOCKING, so the command it was supposed to stop runs anyway.
Rule: A hook path is not a path to a file, it is a promise that the file will be found from wherever the shell happens to be. Register every hook so it resolves independently of cwd — `bash -c 'cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"; exec bash .claude/hooks/<x>.sh'` fixes the subdirectory case, survives worktrees (toplevel is the worktree root, which carries the hooks), and degrades to the previous behaviour outside a repo. Absolute paths also work but bake in one machine's checkout. Corollary for diagnosis: when a hook error contradicts what is on disk, the answer is in the session transcript's `cwd` field, not in the filesystem — and the existing digest line "Bash `cd` persists across calls" is the same trap seen from the caller's side, so treat any relative path in an always-on config as suspect. Second corollary, learned the same hour: the firewall matches on the raw command STRING, so a commit message or heredoc quoting a blocked pattern is itself blocked — reword the prose, never weaken the guard.
Example: 2026-08-01 — all 13 relative hook commands rewritten in `.claude/settings.json` (`9a09f772c`). Verified end-to-end: from `functions/`, the wrapped firewall blocked a hard-reset probe that previously slipped through, passed a benign `npm test`, and returned the old non-blocking error outside a repo. The commit needed the documented `LEFTHOOK_EXCLUDE=analyze` bypass — the gate timed out at 5m twice with the machine at 1.9 GB free (analyzer-recovery step 1), while a standalone `dart analyze` ran clean and the staged diff held no `.dart` files.

### [Delivery] A gate's REMEDY TEXT is part of the gate — name a mechanism that does not exist and the gate manufactures the workaround it condemns
Date: 2026-08-01
Trigger: Investigating twelve forged marker writes, I grepped all six of Butlery's commit-gate agent definitions for the marker command they were assumed to run. Five had none — `code-reviewer`, `testing-specialist`, `firebase-backend-security`, `cloud-functions-specialist` and `firestore-rules-tester` have never contained a marker instruction. Only `integration-reviewer`, added that same morning, wrote one. Yet the commit gate's block message told every blocked session: "run the `<agent>` agent — it writes .claude/state/<marker> itself as its final step." For five of six gates that sentence is false, so the honest remedy was impossible and the session did the only thing left: hand-wrote the marker. The markers on disk prove it — `code-review-done.marker` opens with a scope note about a PARALLEL SESSION's work, knowledge a file-scoped reviewer could not have. Three paragraphs further down, the same message says writing a marker yourself forges the gate.
Rule: A gate has two halves — the check, and the remedy it prints when it fires. The remedy is executed by whoever is blocked, under pressure, and is therefore the most-followed instruction the gate emits. Verify it the way you verify the check: for every agent the message can name, confirm that agent actually performs the step the message promises, in this repo, today. When it does not, the gate is not merely unhelpful — it is training the exact bypass it exists to stop, and no amount of stern prose lower down survives an instruction saying the file should already exist. The deeper fix is to stop the remedy being a WRITE at all.
Example: 2026-08-01 — the false sentence deleted; five agents given the mechanical rules they were assumed to have; the marker replaced by a recorded ledger, so the remedy is now "run the agent" with nothing for a human to author.

### [Delivery] Unit of work, unit of proof and unit of undo must be the SAME SIZE — the largest one silently wins
Date: 2026-08-01
Trigger: The 2026-08-01 `/sprint-parallel` run built 10 tickets across 7 batches (4h41m, 115 agents, 68 reviewers, 355 findings, ~14M tokens) and shipped nothing; salvaging it cost ~16 more hours. Nothing malfunctioned — the commit gate refused unproven work, the engine withheld every marker, Ship correctly wrote none. The design was the fault: work was the whole sprint (45 files, one commit), proof was a marker naming every staged file a gate protects, and undo was one batch's patch, which stops being reversible the moment any later batch or fix round rewrites its hunks. Three batches failed verification; their reversal had already expired (verified per file: conflicts in 3/7, 4/7 and 5/7); so seven good tickets died with three bad ones. Five lessons in `lessons-digest-delivery.md` already described this, ALL dated before the run, one naming the exact command and the exact remedy.
Rule: When a pipeline batches work, check the three sizes against each other before trusting any of its gates. If proof covers a bigger set than you can withdraw, one bad member strands the whole thing. Make them equal — the practical form is a checkpoint per unit: apply, review, verify, COMMIT one batch at a time, so proof cannot expire (nothing later can rewrite committed bytes), undo becomes `git revert`/`git stash` instead of a reverse-apply that expires, and a fix round is bounded to the batch it belongs to. The corollary about lessons is the harder one: five written lessons naming this failure did not prevent it, because a lesson binds the next READER and an engine is a script that never reads one. If a lesson describes a mechanical failure of a mechanical system, it has to become code or it will be re-learned.
Example: 2026-08-01 — `sprint-execute-parallel.js` rebuilt around a per-batch loop (malin-plugins 90a73f4); one bad ticket now costs one ticket. 118 engine fixtures green, 5 engine mutants each reddening exactly their intended assertions.

### [Delivery] Proof of review must be a BY-PRODUCT of reviewing, never something the audited party writes afterwards
Date: 2026-08-01
Trigger: Every generation of the marker gate failed the same way, and each fix made the assertion stricter rather than removing it: bare `touch` → require the file be NAMED → require a `path@sha` pin → require the reviewer's own `reviewed` list → require prose preconditions in the agent. On 2026-08-01 twelve marker writes were still flagged as forged, one fabricating a claim that a git command had been refused. The common factor is structural, not behavioural: writing the marker is a SEPARATE ACT performed after the review, from memory, by the only party with an interest in the outcome. `simplify-done.marker` on disk at 04:46 that morning shows how far outside the control loop it sits — written by a reviewer the ENGINE spawned, during a run in which the engine had decided to withhold every marker.
Rule: For any "prove you did X" gate, ask what artefact doing X produces on its own, and check THAT. Reading a file is what creates the evidence of having read it — so record the read (PostToolUse hook: agent type, path, blob sha of the bytes shown) instead of asking for a statement about it. Three properties follow for free: coverage cannot be inflated because the reviewer does not author the record; a later fix silently un-proves the file it touched, so re-stamping is not expressible; and content-addressing means a parallel session's unrelated edit can no longer invalidate a real review, which is what trained everyone to re-touch markers. Be honest about the boundary — this mechanises COVERAGE, never judgement. The verdict still comes from the agent, and nine defects survived 68 reviews here.
Example: 2026-08-01 — `review-ledger.mjs` (PostToolUse) + `review-verdict.mjs` (SubagentStop) + a ledger-mode commit gate and a new push gate; `integration-reviewer`'s marker write DELETED rather than tightened. Verified end-to-end against the real config in a sandbox repo, never the live one — seeding a real ledger with a review that never happened is the forgery being fixed.

### [Workflow] When your own probe is the instrument it can strand a mutant or misreport the result — restore from a finally block AND signal handlers, and read the total off the right line
Date: 2026-08-01
Trigger: Two instrument failures in one hour while mutation-testing new gates. First, the probe applied mutant 3 of 5 and the harness killed it at the 2-minute timeout before the restore, leaving a live mutant in `require-review-before-commit.mjs` that weakened the partial-coverage check. Only a `git status` plus an anchor grep caught it; the suite was green WITH the mutant, because a mutant's whole point is passing the tests it disables. Second, the same script reported "89 checks passed" as its baseline where a direct run reported 162 — the suite prints one `N checks passed` line per nested sub-suite, and `String.match` with a non-global regex returns the FIRST.
Rule: A mutation probe is a WRITE to real code with a window in which the code is wrong, so treat the restore as the primary obligation: back up before the first mutation, restore in a `finally` AND from SIGINT/SIGTERM/SIGHUP/SIGBREAK handlers, then verify the bytes are identical and re-run the suite clean before believing any result. Never conclude "restored" from the absence of an error — the failure mode is exactly a run that never reached its own restore. And when scraping a total out of tool output, confirm the line you matched is the one you meant: prefer the last match or anchor on a unique prefix, because a nested runner's summary reads exactly like the outer one and turns a wrong number into a confident number.
Example: 2026-08-01 — mutant found live by `git status` + anchor grep and reverted; probe rewritten with backups, a finally, four signal handlers and a byte-identity assertion; the 162 vs 89 gap chased down rather than waved off, and the counts quoted to Malin taken from the direct runs.

### [Workflow] Measure the APP's own path, not a shell tool's — `curl` is a different client, and its 403 is not your feature failing
Date: 2026-08-01
Trigger: Asked to sweep "all Swedish recipe sites" for part C of the OCR/sites plan, I probed 40 domains with `curl` and reported three sites — coop.se, alltommat.expressen.se, zeinaskitchen.se — as "blocking us entirely, and a CSS selector cannot fix it". Malin approved keeping a scoped item to handle exactly that. Reading the code five minutes later: `UrlImportStrategy` already runs a Tier 3 **headless browser** pass (`url_import_strategy.dart:140-142`) commented verbatim *"Covers JS-rendered pages and sites blocking simple HTTP"*, backed by `WebScraper`'s `HeadlessInAppWebView` with a per-platform user agent, plus a Tier 4 text pass on the same rendered HTML. My sweep measured curl's access, never the app's. The same probe also produced junk verdicts a first time by landing on homepages and listing pages that passed a naive "contains 'ingrediens'" check — fixed by requiring an ingredient word AND a measurement token, which is what made the real result (11 domains already free via schema.org, and 8 of our own 10 site-configs therefore dead) trustworthy.
Rule: Before reporting that an external target is unreachable, unsupported or broken, identify which client the FEATURE uses and reproduce through that client. A shell fetch differs from the product in user agent, TLS fingerprint, cookie handling and — decisively — whether JavaScript runs; each difference alone can flip the verdict. This is the external-facing twin of the existing "a subagent naming a file proves existence, not routing" lesson: grep for an existing fallback tier before proposing to build one, because a plan that adds what the code already has is worse than no plan. And when a probe classifies pages, make it prove the page is the KIND it claims (two independent markers, not one), or the sweep measures the crawler.
Example: 2026-08-01 — C's replacement item withdrawn the same day it was approved; the plan now says the open question is a TEST of the existing Tier 3 on those four URLs, not a build. The sweep's surviving finding stands on its own: the big Swedish sites carry schema.org, so tier 1 already handles them free.

### [Verification] A verifier's RED COUNT is a fingerprint of the bytes it read — revert the fix and compare signatures before believing "this never landed"
- **Date**: 2026-07-30
- **Trigger**: The 2026-07-30 sprint's outcome verifier failed BUT-1739 with a specific, confident claim: the reorder in `recipe_text_normalizer.dart` was never applied and 7 golden tests were red, naming the exact fixture hash mismatch. The code plainly contained the fix and the suite ran 24/24 green. Rather than just asserting "the verifier is wrong", I reverted the two lines: the revert reproduced EXACTLY 7 reds — the same five "ca/cirka/ungefär" cases, the qualifier-invariance test, and the same `parenthetical_and_approx` hash pair the verifier quoted.
- **Rule**: A failure signature (count + which tests + which values) identifies a specific revision. When a verifier, agent or ticket claims a defect the code contradicts, don't stop at "run the suite and paste the count" — that only proves the CURRENT state. Reconstruct the claimed state and check whether its signature matches what was reported. An exact match proves WHICH bytes the reporter read, which is far stronger than "the claim is false": it says the reporting mechanism sampled stale content, so every other claim from that same run is suspect for the same reason. Then file nothing, and record the non-defect so the next session doesn't re-investigate.
- **Example**: 2026-07-30 — BUT-1739 closed as genuinely Done with the signature match recorded in the ticket. The same run's verifier had also failed BUT-1726 on "the security marker pins pre-change shas", which WAS true; a blanket "the verifier is unreliable" would have discarded a real finding.

### [Verification] Two samples cannot attribute a NONDETERMINISTIC failure — a control tree needs N runs per side, not one
- **Date**: 2026-07-30
- **Trigger**: A comments integration test went red during ship verification. It failed twice on the working tree; a clean HEAD worktree passed twice. That 2-vs-2 reads as "this sprint caused it", and I said so out loud. It was wrong: the test passes in isolation sometimes and fails other times, and nothing in the diff touches the comments path. Running it 6 times per tree gave 3 failures on ours and 4 on clean main — pre-existing, and marginally worse WITHOUT the change.
- **Rule**: The worktree control is the right instrument (detached `git worktree` at HEAD, `flutter pub get --offline`, same batch) — but one sample per side measures nothing when the failure is nondeterministic. Establish determinism FIRST: does it fail in isolation? does it fail every time? If not, run N>=5 per tree and compare RATES, not outcomes. And read the assertion's shape before running anything — a strict `isAfter` between two wall-clock stamps taken microseconds apart is a same-tick coin flip, a flake signature recognisable on sight.
- **Example**: 2026-07-30 — filed as BUT-1756 (pre-existing flake) instead of blocking the sprint's commit. The commit message records the 3-of-6 vs 4-of-6 measurement so nobody redoes it.

### [Testing] A fixture must CONTAIN the pattern it claims to guard — three vacuous tests shipped looking like coverage
- **Date**: 2026-07-30
- **Trigger**: Three tests in one sprint asserted a guard while being incapable of failing. `'paprika. 2 st'` and `'2 tsk kanel'` were meant to prove the `ca`-boundary lookarounds — neither string contains the substring `ca` at all, so both passed with the boundary deleted. A title test used `"Råg:"` to prove a guard on a path that rejects anything under 5 characters, so it exercised a different branch entirely, and the real hole (`"Havregryn:"`, `"Mjöl:"`, every `*mjöl:` compound becoming the recipe title and leaving the allergen-tagging input) shipped underneath it.
- **Rule**: Before trusting a negative assertion ("X is not matched", "Y does not become the title"), verify the fixture can REACH the code under test — grep the fixture for the literal the pattern hunts, and check it clears every length/shape precondition on the path you mean to exercise. Then mutation-test: delete the guard, confirm THAT test reddens. A green negative test proves nothing on its own, and it is the most common way coverage gets faked without anyone intending to fake it. For a two-sided boundary one fixture usually cannot pin both sides — a letter-flanked word blocks on either lookaround independently, so it catches neither single-sided mutant.
- **Example**: 2026-07-30 — re-fixtured onto `'tapioca. 2 st'` (kills the lookbehind mutant on both branches, measured) and `"Havregryn:"` (reddens on guard deletion, measured). BUT-1727/BUT-1715.

### [Architecture] A staleness guard cannot compare two values each SYNTHESISED at parse time — fix the non-determinism at the seam, not with a tolerance window
- **Date**: 2026-07-30
- **Trigger**: BUT-1726's new access-control drift check compared `base.createdAt` with `stored.createdAt`. `SerializationUtils.safeRequiredDateTime` falls back to `clock.now()` when the field is missing or unparseable, and `UnifiedShoppingList.fromMap` passes no `defaultValue` — so a legacy document yields a DIFFERENT value on every read. Every membership change on such a list was refused forever, with advice ("reload the list and try again") that can never succeed. My first fix was a 30-second "both values look freshly synthesised" window. Review killed it: the client-held value is anchored to the last snapshot emission, which is unbounded, so a dialog open four minutes still fails — while unit tests, which build both sides milliseconds apart, show it as fully fixed.
- **Rule**: When a guard compares a client-held value against a server value and BOTH can be synthesised at parse time, a tolerance window anchored to `now` is not a fix — the two anchors are different things ("when this write happened" vs "when the client last parsed"). Either make the parse deterministic (a stable sentinel `defaultValue`) or drop the field from the comparison and say why. Two tells that a window is wrong: the tests build both sides microseconds apart so the window always fires, and the suppressed field still rides along in the narrowed payload and gets WRITTEN. Check the second one — here the fabricated `createdAt` would have been persisted, because the owner branch of the update rule carries no field constraints.
- **Example**: 2026-07-30 — shipped by dropping `createdAt` from the drift set (`ownerId` and `memberPermissions` carry the whole access-control statement, both untouched) AND stripping it from the declared-base payload. Deterministic parse-seam fix is BUT-1755.

### [Delivery] A deviation entry authored INSIDE the change it authorises is not a decided call
- **Date**: 2026-07-30
- **Trigger**: The security review of the shared-shopping-list GDPR export refused both to file a third-party-data finding and to accept the deviation permitting it. Its reasoning: the entry in `ACCEPTED_DEVIATIONS.md` was ` M` in `git status` — written by the same uncommitted diff it authorised — and it justified itself by analogy from BUT-1450, whose own text records a HUMAN override by the founder. The analogy did not transfer; the new surface had authorised itself.
- **Rule**: `accepted-deviations.md` is treated as settled law by every agent and every plan, which is exactly why an entry can be minted to wave through the change that writes it. Before relying on a deviation to justify shipping, check two things: is the entry already COMMITTED (`git status` on the deviation files), and does the entry it argues by analogy FROM record a human decision rather than another inference? If either fails it is a proposal, not a verdict — escalate to the founder and record the answer in their name, dated.
- **Example**: 2026-07-30 — escalated; Malin decided to ship the export unredacted on its own terms. The entry now names her and the date, and the self-authorised paragraph is superseded in place rather than deleted.

### [Delivery] Re-review your OWN ship fixes — five defects came from the repairs, not from the sprint
- **Date**: 2026-07-30
- **Trigger**: After nine specialist passes found real defects in a held sprint, I fixed them and prepared to commit. A re-review pass over only the files the fixes touched found five NEW defects in the fixes themselves: a title guard so broad it wiped legitimate recipe titles (`"Kladdkaka:"`), a staleness window anchored to the wrong clock, a partial-failure message read after the loop that clears it on every iteration, a `mounted` guard that routed straight into an unguarded `setState` in `finally`, and a cost "optimisation" that would have silently disabled the export's own incompleteness flag (that one I caught myself and reverted).
- **Rule**: The fix round is written under time pressure, by whoever just absorbed a long findings list, and it is the LAST thing to touch the bytes — so it is simultaneously the least reviewed and the most likely to be wrong. Budget a re-review pass over exactly the fix diff as a standard step, not a contingency, and hand the reviewer the RATIONALE for each fix so it attacks the reasoning instead of re-deriving it. Ask specifically about over-reach: a guard added to close a narrow hole is the classic place to accidentally catch the general case.
- **Example**: 2026-07-30 — all five repaired before commit. The ship pass cost roughly as much again as the fix pass, and was worth it.

### [Delivery] A parallel sprint can lose the ability to withdraw a batch — reversibility is a property of the ORDER batches touch lines in, and it expires silently
Date: 2026-07-30
Trigger: The 2026-07-30 parallel sprint graded four of ten tickets as failing verification and tried to reverse-apply their two batches out of the working tree before committing the rest. Neither reversal was possible. Two separate causes. (1) The prescribed `git apply -R --3way --whitespace=fix` implies `--index`, so it requires every touched file to match the INDEX — but batches applied by the run are UNSTAGED, so index == HEAD and contains none of their changes; both patches failed instantly with "does not match index" for every file. The `--3way` form is structurally unusable against an unstaged tree, independent of content. (2) Probing with the meaningful read-only equivalent, `git apply -R --check`, 7 of batch-0's 11 files and 1 of batch-3's 4 still refused — because a LATER batch had rewritten the very hunks the earlier one would have to give back. BUT-1721's `error_code` work replaced the `'error': e.toString()` blocks batch-0 touched, so the context git searches for no longer exists; reversing would either fail mid-file or tear BUT-1721's fix out along with batch-0. Batch-3's paragraph in an agent `.knowledge.md` had been legitimately rewritten in place (those files are MEANT to be rewritten), so its added lines were gone in verbatim form. Result: a mixed tree of verified and failed work, no clean way to separate them, and a mandatory STOP with nothing committed.
Rule: Treat "can this batch still be withdrawn?" as a perishable property, not a guaranteed escape hatch. Two disciplines follow. First, never plan a withdrawal around `git apply -R --3way` for unstaged work — `--3way` implies `--index`; the honest probe is `git apply -R --check` (read-only, tests the working tree), and it must be run BEFORE any decision that assumes reversal is available. Second, the moment two batches are known to touch the same file, the second one to land destroys the first one's reversibility for that file; either serialize them, or checkpoint each batch into the index (or a commit on a scratch branch) the instant it applies cleanly, so a later reversal has a real base to reverse against. When reversal has already expired, a PARTIAL withdrawal is worse than either extreme — it leaves half of a rejected change in the tree with nothing recording which half. Stop, commit nothing, hand the human a per-file decision with the backup patch path, and say plainly on every affected ticket that the code never reached the app.
Example: 2026-07-30 — nothing reverted, hand-edited, staged or committed; the tree left byte-for-byte intact (44 status entries, `dart analyze --fatal-infos` clean) with the backup at `scratchpad/backup/tracked-before.patch`. BUT-1759 filed Urgent carrying the three untangle options, the seven refusing batch-0 paths, and the four must-do items that outlived the sprint (zero review markers covering any of the 41 changed files, five unreviewed `functions/src` files, an uncleared `workflow-map.stale`, and five undeclared widened files missing from the deviation log). All ten tickets stayed in Todo — no Done, no In Review — because both states would have encoded a shipping claim that was false.

### [Delivery] A review agent's mutation probe can outlive the agent — check the worktree against the index before every commit
Date: 2026-07-30
Trigger: During the rescue pass on the 2026-07-30 sprint, `firebase-backend-security` reported a HIGH finding that was not in anyone's diff: `social_export_manager.dart` showed `MM` in `git status`, and its WORKING-TREE bytes carried `'error': 'MUTANT raw exception: PERMISSION_DENIED blocks/me_uid-of-another-person'` with `error_code` deleted. The staged bytes were correct. It was a live mutation probe left behind by `testing-specialist`, which was running concurrently and legitimately mutating production files to prove the new tests reddened. By the time I checked, that agent had restored it — so the mutant existed for a window of minutes and was invisible to both the agent that made it and the agent that would have shipped it. A `git add -A`, a `git commit -a`, or a parallel session's index sweep during that window would have shipped a string containing another data subject's uid into the section body of every failed Art. 15 export.
Rule: A mutation test is a WRITE to production code, and any agent doing one is briefly holding a loaded weapon. Two disciplines. Instruct every review agent to mutate and restore inside the SAME shell call, and to report its own `git status --porcelain` line before finishing — an agent that cannot show a clean tree has not finished. And at ship, never trust `git diff --cached` alone: run `git status --porcelain` and treat any `MM` / ` M` as an unanswered question, because the index is not the tree and the gate reads the index while the tests read the tree. The corollary is that concurrent reviewers must not be pointed at overlapping filesets when any of them may mutate.
Example: 2026-07-30 — verified by hand (`grep -rn MUTANT lib/ test/ functions/src/` → nothing; `_failed()` back to its two correct keys) rather than trusting either agent's account, then re-staged and re-ran the suite. The re-review prompt for the final fix-round pass was amended to require same-call restore plus a pasted `git status` line.

### [Testing] Two Firestore deny tests cannot be told apart by their PERMISSION_DENIED text — the evaluation error fingerprints the RULE LINE, not the actor
Date: 2026-07-30
Trigger: Adding SSL40 (a revoked shared-list member cannot UPDATE) to the rules suite, I argued it was distinct from SSL22 (a non-member cannot update) because their emulator verdicts differed: SSL22 printed `evaluation error at L1642:24` while SSL40 printed a plain `false for 'update' @ L1642`. `firestore-rules-tester` re-ran both and showed the strings are BYTE-IDENTICAL; I had matched two different lines of interleaved log output to the wrong tests. Only SSL23 (unauthenticated) genuinely differs, because `isAuthenticated()` short-circuits before `resource` is dereferenced. The verdict string reflects which rule line evaluated and how far it got — a property of the RULE, not of who was asking.
Rule: Never use a `PERMISSION_DENIED` verdict string to argue that two deny tests exercise different predicates. Prove non-vacuity structurally instead, with two probes: a FAIL-CLOSED control (identical document, id, actor and payload, but with the actor seated as a member — it must now ALLOW, which proves the deny came from the membership conjunct and not from a malformed body or a wrong path) and a DISCRIMINATING MUTATION (change the rule so the suspected-duplicate branch grants — the new test must flip to allow while its neighbour stays denied). Also send the REAL payload shape at least once: a bare `update({items})` is a stronger isolation than the production write, but only a probe with the actual queued payload proves the production path denies too.
Example: 2026-07-30 — SSL40 proven with a six-row probe table; SSL41-43 added for the privileged-key conjunct, whose three anchors had one deny test between them while an ADR shipping in the same commit asserted the predicate. 43/43 green.

### [Architecture] A wrong-path Firestore read is a bug CLASS with a whole family — when you fix one, grep every other consumer of the same collection
Date: 2026-07-30
Trigger: BUT-1724 fixed three dead or wrong-path reads of a retired shopping collection, and was graded Done. During the same commit's review pass, `code-reviewer` found the identical disease still live in four more places, none of them in the ticket: the Art. 15 export reads `conversations/{id}/messages` while production writes a TOP-LEVEL `messages` collection keyed by `conversationId`; it orders by `timestamp` while the field is `sentAt`; the export then filters on `recipientIds`, a field that exists only on shared MENUS and never on a message; and BOTH account-deletion cascades sweep that same phantom subcollection. Each fault empties the result on its own. Net effect, verified by hand against the write path, the read path and `firestore.rules`: the GDPR export has never returned a single message, and a deleted user's chat content survives erasure indefinitely — while `deleteAllMessagesForUser` returns 0 and logs it as success.
Rule: A wrong collection path, a wrong field name and a filter on a non-existent field are all the same failure: a query that is SYNTACTICALLY perfect, throws nothing, and matches zero documents. Nothing in the type system, the analyzer, or an in-memory fake catches it, and a fake will happily seed the phantom path so the test passes too. So when one instance is found, treat it as a class: enumerate every reader AND every writer of that collection (`grep` the constant, not the string literal), and check each against the one place that is authoritative — `firestore.rules`, which must have a `match` block for any path a client can legitimately reach. A path with no rule block is not merely undocumented, it is denied. Highest-risk consumers are the ones whose emptiness looks normal: exports, deletion cascades, analytics probes, and anything whose caller swallows `permission-denied`.
Example: 2026-07-30 — BUT-1766 (Art. 17, Urgent) and BUT-1767 (Art. 15, Urgent) filed with the write path, read path and rules line cited; BUT-1768 filed for the same class in the realtime collections (`realtime_menus` in no deletion tier, `lastEditedByDisplayName` scrubbed nowhere). All three verified in the code by hand before filing, because a verifier's claim is a hypothesis.

### [Delivery] A long `flutter test` run must be DETACHED, and a status watcher must be proven to see failure
Date: 2026-07-29
Trigger: Verifying a 72-file sprint diff before commit needed the full unit+widget suite (~83 minutes). Three attempts died. The first two — `flutter test ... | tail` via the Bash tool's `run_in_background` — were killed by the harness's own background-command lifetime and left a ZERO-BYTE output file, which reads exactly like "the command produced nothing" rather than "the command was killed". The third, run through the repo's documented native-PATH `.bat` wrapper, got 1083 tests in and was killed the same way; only its persisted log proved it had been healthy. The fix was `powershell Start-Process -WindowStyle Hidden` so the run leaves the harness process tree entirely, with the `.bat` redirecting its own stdout to a log and echoing an exit sentinel. Separately, the CI watcher I armed to poll `gh run list` used a `--jq` filter whose status field came back EMPTY; my "pending" test compared against `in_progress|queued`, so three genuinely running jobs counted as not-pending and the monitor announced `CI-ALL-DONE` while Build Validation, Run Tests and SBOM were still going.
Rule: For any run longer than a few minutes, detach it from the harness (`Start-Process` on Windows) and have the script write its own terminal sentinel — then judge completion by the sentinel, never by the wrapper's exit or an empty output file. A zero-byte log is evidence of a KILL, not of a clean no-op; check byte count before concluding anything about the command's result. And a status watcher must be tested against the failure shape it is supposed to catch: assert on the terminal state you EXPECT (`completed`) rather than enumerating the pending states, because any parse breakage then reads as "not done" instead of silently as "done". Silence and blankness are the two shapes that look like success and are not.
Example: 2026-07-29 — detached run completed 19,327 passed / 68 skipped / 0 failed. The false `CI-ALL-DONE` was caught only by re-querying the three jobs by databaseId, which showed `status=in_progress, conclusion=` on all three; they were re-watched with a per-id loop keyed on `status == "completed"`.

### [Delivery] When a sprint holds its own commit, the follow-through is a REAL review pass — the hold is a finding, not a formality
Date: 2026-07-29
Trigger: The 2026-07-27 parallel sprint returned `ship-incomplete` with nothing committed, because its completeness critic found every `.claude/state/` marker pinned the PREVIOUS sprint's blob shas and that `firestore.rules` had changed despite the plan saying it would not. The tempting reading is bookkeeping: the code was already reviewed three times inside the run, all its suites were green, so re-stamping the markers against the new shas would have "cleared" the gate in minutes. Running the five specialists for real against the final staged diff instead found three defects that every in-run review, the per-ticket adversarial verify AND the file-scoped specialists had passed. A backfill migration re-created an ERASED user's uid into a field the rules make append-only, so no client write and no future cascade could remove it. The same migration stalled at ~10,350 documents while returning `success: true`, leaving the rest permanently unreachable to erasure — the exact gap its own ticket existed to close. And a Swedish gluten rescue kept the trailing colon, so the rescued row matched nothing in the register, dropped coverage below 1.0, and forced EVERY allergen on the recipe to UNKNOWN.
Rule: A held commit means the reviews that were run reviewed DIFFERENT BYTES than the ones about to ship. In-run reviews happen mid-fix; the last fix always lands after the last review, and the gap is where the compounding bugs live. Re-run the specialists on the final staged content and require each to paste real command output — the migration bugs were only visible to an agent that BUILT a harness and measured corpus throughput, and the colon bug only to one that traced a row end-to-end through the real lookup chain to a coverage number. Neither was findable by reading the diff. Corollary for grading: check each ticket's acceptance criteria against what actually shipped before closing it — BUT-1709 was briefly marked Done here when its third criterion ("the guard covers its own registration") was precisely the gap being filed as a new ticket.
Example: 2026-07-29 — shipped as `e14455ceb` after the real pass: 19,327 tests green, analyze clean repo-wide, `tsc` clean, all eight lefthook gates passed, markers re-pinned from `git rev-parse :<path>` after the final `git add`. Five new tickets filed for what was deliberately NOT folded into the diff.

### [Testing] A test written to pin a fix is a hypothesis until you mutate the fix and watch it redden
Date: 2026-07-27
Trigger: Clearing the 2026-07-26 sprint's commit gate meant writing ~15 tests to pin fixes the gate had demanded. Three of them proved nothing, each for a different reason, and two would have shipped had a reviewer not caught them. (1) `never queues a null activity field` asserted `expect(payload.values, everyElement(isNotNull))` against a map whose builder is `if (serialized[key] != null) key: ...` — a null is unrepresentable in the output, so the assertion is a tautology over the current code; and the fixture went through `UnifiedShoppingList.collaborative`, which stamps all four activity fields, so the guard was unreachable anyway. Two independent reasons it could not fail. (2) A `\b`-boundary fixture, `'1 påse riven ost till gratängen och lite extra till formen'`, contained no `-sen` token at all: it scored the same before and after the fix while sitting in a group whose header claimed "reverting the boundary reddens these". (3) The cached-base ACL test staged its "stale server state" with `docRef.update({'memberPermissions': {...}})` — `fake_cloud_firestore` DEEP-MERGES a nested map on update where real Firestore replaces it, so the stale state was never staged; I then rewrote it to `set()` and it still passed the mutant, because the fake also ignores `GetOptions(source: cache)`, so the "cached" read returns current server state and a doc-level divergence cannot be staged at all. The stale copy had to come from the MUTATOR instead. Only after that third rewrite did the mutation (`update(cachedBasePayload)` → `set(merge: true)`) actually redden it.
Rule: For any test whose purpose is to pin a fix, run the mutation before believing the test: revert the fix, run, confirm the red names YOUR test, restore, and verify the restore is byte-identical (`md5sum`). Three specific traps to check while writing, all of which cost a round here. A tautology over the implementation — if the code cannot produce the value you are asserting against, the assertion is decorative; assert on KEY ABSENCE rather than value non-nullness when the builder filters keys. A fixture answered by an EARLIER branch — a digit in a heading fixture reaches `RegExp(r'\d')` and returns before the guard under test, and a factory that stamps every field makes an "unstamped" test impossible; check the branches ABOVE the one you are testing, not only beside it. And a premise that depends on the fake behaving like production — `fake_cloud_firestore`'s `update()` deep-merges nested maps, its `runTransaction` is a passthrough, and it ignores `GetOptions(source:)`, so any test staging cache-vs-server divergence at the DOCUMENT level is staging nothing; drive the divergence through the mutator or the injected `fromFirestore`.
Example: 2026-07-27 — all three rewritten and mutation-verified before commit. The cached-base test now carries an extra member in the mutator, is owner-driven so the escalation guard cannot be what keeps the map out, and reddens on the `set(merge: true)` revert; `md5sum` confirmed the routing module byte-identical after the probe. Cost of the three rounds: roughly an hour, versus a commit whose three headline security tests all passed vacuously.

### [Delivery] A late guard that reddens an INTENTIONAL existing test is changing semantics it did not declare — revert it, do not rewrite the test
Date: 2026-07-27
Trigger: A reviewer flagged, for the fourth pass running, that the narrowed offline shopping-list payload silently DROPS any field outside `items` + the activity stamp while telling the caller the mutation applied. The suggested fix was an enforcer: diff `mutated.toFirestore()` against `live.toFirestore()` and throw on any out-of-whitelist key. I wrote it, and it immediately reddened two existing tests — both of which deliberately construct a mutator that changes a rule-locked field (`createdAt`, `memberPermissions`) precisely to prove the PAYLOAD excludes it. My guard converted "silently dropped" into "throws", which is arguably better, but it changed the contract of a public interface method late in a 70-file diff, with no plan, no live caller able to trigger it, and no way to keep both behaviours. The tempting move — rewrite the two tests to expect a throw — would have destroyed two genuine payload pins to accommodate a guard nobody had asked for at that scope.
Rule: When a guard added in a fix round reddens a test that was written on purpose, treat the red as a design signal rather than a test problem: the guard is changing a contract beyond its stated scope. Revert it and file the ticket, especially when no live caller can reach the case, the diff is already large, and the change would need its own plan. A finding flagged N times is not thereby urgent — it may be flagged repeatedly precisely because it is latent, and "fourth pass" is an argument for a ticket with the history in it, not for a drive-by. The reciprocal also holds: when the guard IS in scope, expect to update the tests, but only after checking each red individually to see whether it is the guard or the test that is wrong.
Example: 2026-07-27 — `requireOfflineWritableFields` reverted along with its three tests; the underlying gap kept as a documented paragraph on `cachedBasePayload` naming exactly which fields are dropped and why it is safe today. The two intentional payload tests survived untouched, and both still redden on the mutation they were written for.

### [Delivery] A new test can be born unrunnable — check the ignore file and the runner's name filter before counting it
Date: 2026-07-27
Trigger: BUT-1707 and BUT-1709 both added the repo's first tests for `functions/scripts/*.js`, and both hit a silent-nonexistence trap on the way in. First, `functions/.gitignore` ignores `*.js` and re-includes only `!scripts/*.js` — a pattern that does not reach `scripts/__tests__/`, so both new test files were unstageable. `git add` reported success at the directory level and the files simply were not in the commit; the failure mode is a test suite that exists on disk, passes locally, and is absent from the repo. Second, the ticket named an npm script `test:rules-coverage-report`, and `run-ci-unit-tests.js` EXCLUDES any script whose name starts with `test:rules` from the CI unit lane (they belong to the emulator lane) — so the obvious name would have registered a test that never runs in CI. Renaming to `test:script-coverage-report` / `test:script-test-registration` put both in the 77-suite unit-lane list, verified by reading the list rather than assuming.
Rule: A test only counts once you have proved it is (a) tracked by git and (b) selected by the runner. Both are hand-maintained lists that drift silently. After writing a new test in an unfamiliar directory, run `git status --porcelain <path>` (an untracked file that never appears is being ignored, not staged) and `git check-ignore -v <path>` to see WHICH pattern caught it; after adding a new npm/CI script, print the runner's resolved suite list and find your script by name in it. Naming conventions in a CI runner are load-bearing semantics, not cosmetics — a prefix can route a suite into a lane that does not execute.
Example: 2026-07-27 — `!scripts/**/*.js` added to `functions/.gitignore` (rather than relocating the tests out of `__tests__`), and the two scripts named `test:script-*`; both confirmed present in the unit-lane list before the tickets were graded.

### [Delivery] A plan's claim about which gated files the sprint touches expires on the first widened fileset — derive the review gates from the staged diff
Date: 2026-07-27
Trigger: The 2026-07-27 sprint plan asserted "firestore-rules-tester only if `firestore.rules` itself changes (it doesn't in this sprint's scope)". It did: BUT-1725 added `keepsContributorTrail()`, a create-side size bound and a new conjunct on `allow update`. Nine further files that no batch had declared — `swedish_line_classifier.dart`, `recipe_share_request_module.dart`, `user_service.dart`, `functions/src/index.ts`, `functions/src/migrations/`, `lib/l10n/*`, `shopping_list_permission_guards.dart`, `heading_word_lists.dart` — landed for defensible reasons (a 500-line split, a backfill with no declared home, a seam the fix genuinely needed). Every widening was honestly recorded in the deviation log. None of them updated the plan's gate list, so the sprint reached its post-phase believing four reviewers and no rules-tester were required, while the real diff needed five and named files no marker mentioned. Compounding it, all four existing markers were the PREVIOUS sprint's, pinning stale blob shas — the exact condition BUT-1703 was filed for, live again one sprint later.
Rule: At ship, recompute which review gates the diff triggers from `git diff --cached --name-only`, never from the plan's Phase-1 prediction. A plan's fileset is a forecast; a deviation log records that the forecast broke but does not re-run the gate mapping. Two corollaries. A widened fileset must appear in the reviewer MARKER, not only in the deviation log — a reviewer who never saw the file cannot have reviewed it, and the marker is the only artifact the commit gate reads. And a marker's mtime proves a touch: compare each marker's pinned `path@<blob sha>` against `git rev-parse :<path>` taken AFTER the final `git add`, and treat any drift as "no review happened", regardless of how recent the file looks.
Example: 2026-07-27 — the sprint ended STAGED AND UNCOMMITTED with all five reviews outstanding, no markers forged, and BUT-1703 re-scoped against the new diff instead of being closed as obsolete.

### [Testing] `FakeFirebaseFirestore.runTransaction` is a no-op passthrough — a transaction test on the fake can CONTRADICT production
- **Date**: 2026-07-26
- **Trigger**: BUT-1665 replaced a cached-base read-modify-write on shared shopping lists with a Firestore transaction, and shipped with 78 green tests including a group named for the concurrency guarantee. Two mutation probes against the LIVE production file both stayed green: re-pointing the mutator from the live document back to the cached list (the exact bug being fixed), and deleting the transaction entirely. Reading the package source explained why — `runTransaction` calls the handler once and returns; `_DummyTransaction.get` is a plain `documentReference.get()` and `.set` drops `SetOptions`; `timeout` and `maxAttempts` are accepted and ignored. No isolation, no abort, no retry.
- **Rule**: On `fake_cloud_firestore`, a transaction is not a weak transaction — it is not a transaction. A test that starts two overlapping mutations there does not merely fail to prove the race, it produces the OPPOSITE result from production: one writer's edit is lost, because the fake serialises nothing. `merge: true` is dropped too, so a server-only field the Dart model never writes is silently wiped, and a test asserting `!snapshot.exists` after a `Source.cache` miss passes only because the fake ignores `GetOptions` (real Firestore throws `unavailable`). So: never let a fake-backed test carry a group name or comment claiming atomicity, isolation or conflict behaviour — name what it actually pins (usually "the mutator's base came from a server read, not a client cache"), and put the real guarantee on the emulator lane. And check the lane actually RUNS: here `grep -rn USE_EMULATOR .github/workflows/` returned nothing and `run_e2e_tests.sh` pointed at `test/e2e`, so `test/integration` executed in no pipeline at all (BUT-1695).
- **Example**: 2026-07-26 — the fix was correct by inspection but its headline guarantee was unproven and its owning module (`ShoppingItemOperationsModule`, five collaborative mutator bodies) had zero test files. A 24-test suite whose fixture carries two independent server-only deltas now kills the cached-base mutation (0 passed / 6 failed under it); the no-transaction mutation still needs the emulator.

### [Delivery] A review marker pinned by TIMESTAMP dies on any later edit — pin `path@sha` instead, and note honestly what changed after review
- **Date**: 2026-07-26
- **Trigger**: After eight review rounds, four markers were stamped as bare path lists. The commit gate refused: STALE, because staleness is computed against the newest of ALL changed files. The only edits since were a two-line comment reword in two test files — made to satisfy `check_swedish_boundary.sh`, which scans source text for an ASCII word boundary next to å/ä/ö and cannot tell a comment from code, so it fired on comments quoting the exact pattern they exist to explain.
- **Rule**: The gate accepts `path@<staged blob sha>` and prefers it — content identity is checked BEFORE mtime, so a sha-pinned marker survives unrelated edits elsewhere in the tree and a timestamp-pinned one does not. Generate the pins from `git rev-parse :<path>` AFTER the final `git add`, not before: pinning first and re-staging afterwards produces DRIFTED, which is the gate correctly catching that the pinned bytes are not the staged bytes. When something did change after review, say so in the marker body rather than letting the pin imply otherwise — the guard being literal is a feature; weakening a safety check to accommodate prose is the wrong trade, so change the prose.
- **Example**: 2026-07-26 — `38d3a715e`. Reworded both comments to describe the pattern without spelling it, re-ran both suites (103 green) and the guard (exit 0), then pinned all four markers with a note recording the comment-only drift.

### [Workflow] A registry lint that reddens on a DELETION day is pointing at the grave, not at itself
Date: 2026-07-26
Trigger: "Run Tests" had been red on main for 41 consecutive runs since 2026-07-16, with exactly one failing test: the structural lint `analytics_events_coverage_test.dart` asserting every `AnalyticsUserProperties` constant has a caller in `lib/`. The two candidate explanations — the lint is stale, or a constant is genuinely dead — look symmetric from the failure message, and the tempting shortcut is to allowlist the constant. One `git log -S hasAlgoliaSearch` on the registry file, plus `git log --since` around the first red day, settled it in two commands: `d35902e16` (BUT-1500, 2026-07-16 09:00) deleted `lib/services/search/recipe_search_router.dart`, and the router held the property's ONLY `setUserProperty` call. The deletion was correct — nothing called the router — it just left the registry promising a metric nobody emits. Deciding removal-vs-rewiring then needed one more fact: `SearchRepository` has exactly one non-DI consumer left (account-deletion index cleanup), and `enable_algolia_search` is off in production, so re-pointing the property at `SearchModule._algoliaActive` would emit a constant `false` for every user forever — which is precisely why `subscription_tier` was retired from the same class in BUT-1410.
Rule: When a structural/registry lint goes red, date the first red run and diff it against `git log` for that day before reading the lint's own code. A lint whose input is a FILE WALK fails when a file DISAPPEARS, so the cause is usually in a deletion commit, not in the assertion — `git log -S <symbol>` finds the vanished call site directly. Then decide remove-vs-rewire on evidence, not sentiment: a dimension that would emit one constant value for every user is zero information and belongs deleted, and the in-file precedent for a previous retirement is the cheapest style guide for the replacement comment. Never allowlist a constant to clear a coverage lint — the allowlist is the exact regression the lint exists to prevent, and the assertion is the asset.
Example: 2026-07-26 — removed `AnalyticsUserProperties.hasAlgoliaSearch` with a dated retirement comment mirroring the `subscription_tier` block; the coverage lint's assertion was left byte-identical. The testing-specialist's non-vacuity probe added the check worth keeping: because `dead` is a SET, its single-element value against the HEAD registry proved the 12-day red was not masking a SECOND dead constant.

### [Delivery] A health-check workflow that edits an issue body notifies nobody, and its own badge lies
Date: 2026-07-26
Trigger: Malin asked why "Main CI Health Alert" reported green for ten days while "Run Tests" was red. The assumption behind the question — the alert missed it — was wrong, and checking rather than accepting it changed the whole fix. Tracking issue #219 had been OPEN since 2026-07-14 and was updated on every single alert run (`gh issue view 219 --json createdAt,updatedAt` proves it; `gh issue list`'s date column is UPDATED_AT, which reads as a fresh issue and misled the first pass). So detection worked perfectly. Two things made it invisible. First, the alert's job succeeds unconditionally — it gates nothing and only reads other workflows' results — so the Actions list showed "Main CI Health Alert ✅" beside a broken main; that green tick was what Malin had actually been reading. Second, when the issue already exists the script called `issues.update()` on the body, and GitHub sends NO notification for a body edit: one ping at creation, then silence across 41 red runs.
Rule: For any alerting automation, verify the DETECTION and the DELIVERY separately — "the alert fired" and "the human was told" are different facts, and a working detector with a mute delivery path looks identical to a broken detector. Two rules follow. A monitor's own run conclusion must reflect what it found (`core.setFailed`) even though it gates nothing, because an always-green badge on a health check is worse than no badge. And re-notification must use a channel that actually notifies: comment, don't edit — rate-limited (24h) and fingerprinted (embed the failing set as an HTML comment) so a workflow firing once per completed gate does not spam. Before touching the trigger list, replicate the monitor's own API query to prove coverage is not the problem: here the same `listWorkflowRunsForRepo` call showed Run Tests eight times, all red, so the gap was purely presentational.
Example: 2026-07-26 — `main-health-alert.yml` gained `core.setFailed` plus a fingerprinted 24h re-comment. Also measured and worth watching: 39 of the 100 runs in the alert's own one-page query window ARE the alert, so it crowds real gates out of its own lookback.

### [Workflow] An invisible character can make correct code read as broken — byte-check the bound before believing a range is impossible
Date: 2026-07-26
Trigger: BUT-1690 reported that the `weekly_menu_plans` doc-ID range in `firebase_weekly_menu_plan_repository.dart` used bounds `>= '${userId}_'` AND `< '${userId}_'` — a degenerate range matching zero documents, which would empty the GDPR export and no-op the recipe-delete cascade. Every code viewer agreed: the two bounds looked identical. They were not. The upper bound carried a trailing literal U+F8FF (a private-use codepoint that renders as nothing at all), so the range was correct and had always worked. `grep -n "isLessThan" <file> | cat -A` settled it in one command: `M-oM-#M-?` = `EF A3 BF` = U+F8FF present. A live read-only `firebase-admin` probe against production then showed the shipped range returning both real plans for the one user who has any, while the degenerate variant returned 0 — the two queries side by side, same collection, same second. The same trap then bit the write-up: typing the six-character escape into the plan document silently produced the literal character again.
Rule: Before accepting that a Firestore prefix range (or any string comparison) is degenerate, byte-check the bound with `cat -A` / `grep -P "\x{F8FF}"` — a visual read of source is not evidence about invisible codepoints, and this applies to your own Read output, a reviewer's eyes, and an audit agent's claim equally. Then confirm behaviour against real data rather than reasoning about it. Two corollaries. When a ticket says an existing guard test is missing, MUTATION-TEST the suite that already exists before writing a new one: remove the load-bearing token, run, count the failures, restore — here 3 tests went red, so the "alarm on zero rows" the ticket asked for was already in place and the correct deliverable was to delete the trap, not add coverage. And prefer the escape spelling for any non-printing sentinel, with a lint that forbids the literal, because a raw character survives no editor, formatter or encoding conversion visibly.
Example: 2026-07-26 — BUT-1690 closed as not-a-bug. `firebase_weekly_menu_plan_repository.dart:159,214` converted from the literal to the escape (behaviour-neutral, `git diff` 2 lines), a class-doc note added explaining that the sentinel is load-bearing and fails SILENTLY when dropped, and a new guard in `test/architecture/architecture_test.dart` forbids a literal U+F8FF anywhere in `lib/**.dart` — proved to bite by injecting one and watching it name `...repository.dart:17`. `functions/src` still carries two literals (`account-deletion-cascade.ts:828`, `request-account-deletion.integration.test.ts:729`), flagged to Malin rather than swept into a GDPR-cascade file for cosmetics.

### [Workflow] Decode the create_composite token — it is the index spec, and it outranks the reported cause
Date: 2026-07-26
Trigger: A bug report said `detect_anomalies` crashed nightly because "the Firestore query against collection group `daily` is missing a composite index". The FAILED_PRECONDITION was real and had fired on 100% of runs since deploy, but the named mechanism did not exist — `grep collectionGroup` returned zero hits for `daily` anywhere in the repo. The failing read (`detect-anomalies.ts:206-217`) is an ordinary subcollection scan whose only ordering is `orderBy(FieldPath.documentId(), "desc")`. Firestore's automatic single-field indexes cover `__name__` ASCENDING only, so a descending document-id sort needs a declared index — a gotcha invisible in the code, which looks index-free. Guessing the shape would have been wasted effort: the error's own `create_composite` URL carries the answer, base64url-decoding to the literal proto `collectionGroups/daily … \x10\x01 … "__name__" \x10\x02` = COLLECTION scope, one field, `__name__` DESCENDING. That decodes to a legal `firestore.indexes.json` entry verbatim.
Rule: When a FAILED_PRECONDITION names an index, decode the `create_composite` token before reading anyone's description of the cause — it is Firestore's own machine-readable spec (scope + ordered field list) and it is authoritative over both the ticket and your reading of the query. Two corollaries. A descending `orderBy(documentId())` is NOT index-free even though it filters on nothing; a single-field `__name__ DESCENDING` composite entry is the supported declaration and round-trips cleanly through `firebase firestore:indexes`. And after deploying, the very next run still fails with gRPC code 9 — the message changes to "that index is currently building and cannot be used yet", which reads exactly like the fix not working; poll `gcloud firestore indexes composite list` until `READY` before re-running, and re-read the message rather than the code.
Example: 2026-07-26 — one entry added to `firestore.indexes.json` (9cd5b53c2). A forced `gcloud scheduler jobs run` logged `detect_anomalies_start` → `detect_anomalies_complete` (flagged 0), zero ERROR entries, and `analytics/anomalies/daily/2026-07-26` was written. Blast radius was four consumers, not one: `anomaly_repository`, `daily_snapshot_repository`, `engagement_repository` and the feature-retention series all run the same descending-document-id read and all swallow the failure into an empty result, so the admin dashboard had been silently blank for five weeks with nothing in any log. Source data was never lost — the 05:00 snapshot jobs are writers and were unaffected.

### [Workflow] A boundary/heuristic bug usually has a twin class — grep by name and trace the caller before declaring the fix complete
Date: 2026-07-26
Trigger: The 2026-07-26 parallel sprint hit the duplicate-class trap twice in one run. BUT-1691 fixed the ASCII-`\b` bug in `lib/services/import/heuristics/ingredient_line_detector.dart`, then discovered a SECOND class with the same name, the same bug and a longer unit list at `lib/widgets/import/ingredient_line_detector.dart` — and that second one is the copy `assisted_import_viewmodel.dart:112` actually calls, so fixing only the first would have left the bug live on half the import surface. The implementer widened scope and fixed both (correct call, but outside the declared fileset, so the batch-disjointness guarantee was no longer verified). Hours later BUT-1697 hit the identical shape: the attribution fix landed in the items-array path while `firebase_shared_shopping_repository.dart` — DI-registered at `social_module.dart:371`, reached from three live callers, `grep -c lastActivityBy` = 0 — kept writing an items SUBCOLLECTION with no attribution at all. Same trap, different area, same day.
Rule: For any single-file fix to a heuristic, boundary, parser or attribution write, make "find the twin" a pre-implementation step, not a discovery: grep the repo for sibling classes by NAME (not by path), then trace which one the view/viewmodel actually calls. Two classes with one name is a maintained-fork smell, and the copy under `lib/widgets/` or the legacy sibling is as likely to be the live one as the "canonical" service. If both are live, fix both in one commit or the bug ships half-fixed; if only one is live, delete the other in the same commit rather than leaving the next session the same puzzle. When the fix must widen beyond a declared fileset, record it in the deviation log AND name the widened file in the reviewer marker — an unrecorded widening silently voids a parallel sprint's disjointness guarantee.
Example: 2026-07-26 — `ingredient_line_detector` fixed in both copies (recorded post-hoc); the shared-shopping subcollection path filed as BUT-1716 with reachability as its first acceptance criterion rather than assumed dead.

### [Delivery] A deferred sub-scope written into a knowledge file is unfiled work
Date: 2026-07-26
Trigger: BUT-1691's implementer wrote three real deferred sub-scopes into `.claude/agents/testing-specialist.knowledge.md:152`, explicitly noting for each that "the deliverable is a ticket, not an edit" — and filed no ticket. The completeness sweep found them only because it happened to read the knowledge file; nothing in Linear or the plan pointed there. All three were genuine live bugs (letters deleted from the parse-cache fingerprint, an orphaned period, a heading guard rejecting `Mjöl:` while accepting `Mjölk:`).
Rule: An agent knowledge file, a chat message and a plan comment are NOT the backlog — the instant an implementer writes "needs a follow-up ticket", file it in that same edit with the code evidence pasted in; prose describing a deliverable is not the deliverable.
Example: 2026-07-26 — the three BUT-1691 sites filed as BUT-1713/1714/1715 (BUT-1714 needing a product call on gluten words, which is exactly why prose was the wrong container).

### [Delivery] A verifier's "the suite is RED" is a claim until you run the suite
Date: 2026-07-26
Trigger: The sprint's data-safety verifier reported BUT-1686 as `fail` with "**8 failing tests**, `fetchCapped` still uses `rows.length >= cap`, the defect is live and unfixed" — a specific, quantified, entirely false claim. I filed BUT-1704 off it, then ran the suite before writing the summary: `flutter test test/unit/services/account/export/` → `+106: All tests passed!`. `fetchCapped` reads `rows.length > cap` on a deliberate `cap + 1` fetch and is correct. The `>=` the verifier "found" is at line 104 in a DIFFERENT method — a log-warning line in the pagination loop that sets no flag. The file's own doc comment at lines 228-233 warns against deriving the flag from `length >= cap`; the verifier appears to have matched the anti-pattern the comment forbids and reported it as the implementation.
Rule: A verifier's verdict is a HYPOTHESIS about the code, at exactly the same evidentiary rank as an audit agent's claim about a tool's output format: before filing a ticket, transitioning a ticket, or writing "the defect is live" in a founder-facing summary, RUN the suite and paste the count. Two shapes make this failure likely and both were present here — a claim about a comparison OPERATOR (one character, invisible to a skim, and `>=`/`>` differ only in a boundary case), and a file containing two near-identical comparisons in different methods, which invites misattribution. When a file's doc comment names an anti-pattern, expect a reader to find the anti-pattern in the comment and report it as the code. Retract loudly when it happens: cancel the ticket with the reproduction, correct every downstream record (sibling tickets' "depends on" lines, the outcome table, this file), and never silently drop it.
Example: 2026-07-26 — BUT-1704 filed and then CANCELLED within the same phase once the suite was run, with corrections posted to BUT-1686 and BUT-1712 and the outcome table amended. Cost of not running the suite first: a false GDPR-defect claim would have reached Malin in the ship report.

### [Delivery] A fanned-out parallel sprint runs NO commit gates — post-sprint must prove the markers cover THIS diff, and stop uncommitted if they don't
- **Date**: 2026-07-25
- **Trigger**: The 2026-07-25 parallel sprint (BUT-1661…BUT-1670) implemented ten tickets across isolated worktrees, each batch analyzing and testing its own files, and arrived at post-sprint with 51 changed files and a "review complete: false" flag. All four `.claude/state/*.marker` files existed and looked healthy by mtime, but their CONTENTS named previous sprints' filesets (tag_generator, assisted-import, BUT-1626, OCR-retry) — no specialist reviewer had run on a single file of this sprint, including `lib/repositories/` and `functions/src/` paths that `reviewGates` routes to the security specialists.
- **Rule**: In the parallel topology the per-batch worktrees never touch the commit gate, so specialist review is not a side effect of implementing — it is a scheduled post-sprint step that can silently not happen. Before writing ANY marker or planning a commit, diff the marker contents against `git status` and treat any uncovered file as review-not-run. If review didn't clear, the sprint ends **staged and uncommitted**: file the unblocking ticket, grade the plan, hold the Linear transitions (closing "Fixed in commit X" with no commit is a false record), and hand the diff to a human. Never forge a marker, never `LEFTHOOK_EXCLUDE` past a review gate, never re-run the commit hoping it passes.
- **Example**: Ended the sprint at `dart analyze` clean, eleven follow-up tickets filed (BUT-1679…BUT-1689), zero commits, zero Linear transitions. BUT-1679 carries the exact four agent invocations and the re-stamp step.

### [Workflow] A TypeScript-only batch inside a Dart worktree has no node_modules — junction it, and unlink with `cmd rmdir`, never `rm -rf`
- **Date**: 2026-07-25
- **Trigger**: BUT-1664 changed only `functions/src/*.ts` files. Its git worktree had no `functions/node_modules` at all, so the mandated `dart format` / `dart analyze` gate was inapplicable AND the TypeScript gate could not run either.
- **Rule**: When a batch's fileset is entirely outside the repo's primary toolchain, run the equivalent gate for the language it actually touched rather than reporting "gates inapplicable". For a TS batch in a Dart worktree on Windows: create a temporary directory junction to the main checkout's `functions/node_modules`, run `npx tsc --noEmit` plus the test suites, then remove the junction with `cmd //c rmdir <path>`. Do NOT use `rm -rf` on a junction — it follows the link and deletes the target, wiping the main checkout's dependencies. Verify the target directory is intact after unlinking.
- **Example**: BUT-1664 ran `npx tsc --noEmit` clean plus all four rate-limiter suites through a junction, then removed it with `cmd rmdir` and confirmed the main `functions/node_modules` still present.

### [Testing] The golden-corpus runner asserts a SNAPSHOT of passing case ids — adding a case without updating it fails the suite
- **Date**: 2026-07-25
- **Trigger**: BUT-1666's plan named only `test/golden/llm/categorize_ingredient/cases.json` as the file to extend. Adding seven cases there alone broke the suite, because `categorize_ingredient_test.dart` holds an `_expectedPassing` set of case ids and asserts the run matches it exactly.
- **Rule**: A golden/corpus suite in this repo is two files, not one: the corpus and the expected-passing snapshot. Extend both in the same edit. The snapshot is also a trap in the other direction — a passing suite proves only that the *listed* ids behave, so "the golden tests pass" is never evidence that a named acceptance-criterion string is covered. Grep the corpus for the literal string the ticket names before claiming the criterion is tested.
- **Example**: BUT-1666 added seven ids to `_expectedPassing`, and the suite went green at 17/17 — while `rökt paprika`, `rostad paprika` and `rostade cashewnötter`, all named verbatim in the acceptance criteria, appeared in no case at all and were still misclassified (BUT-1680).

### [Workflow] "I read very little of what you reply" is a config bug before it is a style problem
Date: 2026-07-25
Trigger: Malin shared three X posts about tuning Claude's response style (`i-have-adhd` plugin, Lydia Hallie's ELI5 output style, JJ Englert's CLAUDE.md response-style block) plus `anthropics/html-effectiveness`, and said she reads very little of what I write. The reflex is to write a shorter summary and move on. Checking the actual configuration found the cause: `explanatory-output-style@claude-plugins-official` was enabled in `~/.claude/settings.json`, injecting a SessionStart instruction to add "★ Insight" boxes and stating that Claude "may exceed typical length constraints" — the plugin's own README warns about its token cost. A second contributor was a June-dated "Fable 5 model tuning" block in `CLAUDE.local.md` that explicitly asked for LONGER end-of-turn summaries, written for a different model and a different failure mode.
Rule: When the user complains about how you communicate, audit the always-on configuration BEFORE apologising or self-correcting in prose. Verbosity that survives repeated correction is almost always instructed somewhere — an output style, a SessionStart hook, a plugin, or a stale tuning block written for a superseded model. Grep for it. Then fix the mechanism rather than the one reply: a reply-shape contract belongs in `~/.claude/output-styles/<name>.md` (loads every session, all repos, survives /compact) and any conflicting prose in CLAUDE.md-family files must be deleted in the same edit, or the two instructions fight and the longer one usually wins. Model-specific tuning blocks get a dated header and a re-check when the session model changes.
Example: 2026-07-25 — disabled the explanatory plugin, added the `Malin` output style (answer / bullets / what you need to do / also found; no preamble, no inter-tool narration, five bullets max), added a global `report` skill that writes long output as one self-contained HTML page under `C:/Users/malla/claude-reports/<repo>/` and opens it, and replaced the Fable-era block in `CLAUDE.local.md` with three pointer lines. The HTML-instead-of-wall-of-text idea is `anthropics/html-effectiveness`; the reply skeleton is JJ Englert's, the register is Lydia Hallie's ELI5.

### [Delivery] Salvaging a gate-blocked sprint: attribute per FILE, and expect a gate CHAIN
Date: 2026-07-25
Trigger: The 2026-07-25 parallel sprint implemented 10 tickets and then correctly held its own ship phase — its completeness critic found all four specialist markers predated the work. Running the missing reviews produced 14 verdicts, 7 BLOCKED. Malin chose "split it: commit what passed". Two things then went wrong in ways worth recording. First, a batch verdict is NOT a per-file verdict: the batch covering `preferences_export_manager` + `weekly_menu_plan_service` + `recipe_section_detector` returned BLOCKED **solely** because of the first file, while explicitly declaring the other two "verified clean" — treating the batch verdict as the file verdict would have discarded two shippable fixes. Second, satisfying the specialist markers did not unblock the commit: it revealed a CHAIN — `simplify-done.marker` (needs a /simplify pass), then the plan-threshold guard (12 production files touched this session, no plan), then the repo's `swedish-boundary-guard`. Three gates, each with a different remedy.
Rule: When splitting a blocked sprint, re-read every BLOCKED report and attribute each finding to the FILE it names, then commit the file set no finding lands on — never drop a whole batch. And expect gates in series, not one gate: after the review markers come the quality-pass marker, the plan-threshold guard, and the repo's own content guards. Each additional gate is a decision point about scope, not an obstacle to clear. The stopping rule that worked: satisfy a gate only by doing what it actually asks; when the next gate would require a WORKAROUND (SKIP_PLAN_GUARD for cosmetic edits), drop the affected files from the commit instead and file them. Two gates deep is normal; four gates deep with an override in hand means the commit is too big or too late at night. Corollary — a content guard firing on a file you were about to ship is evidence, not noise: `swedish-boundary-guard` looked like a false positive (it printed comment lines) but grep found live `\b` regexes two functions from the fix, so the ticket genuinely was not done.
Example: 2026-07-25 — shipped 11 files (BUT-1662 partial, BUT-1668, BUT-1664) as c0989a3a3; dropped `preferences_export_manager.dart` (testing gate), then `recipe_section_detector.dart` + its test (boundary guard), then all 5 cosmetic /simplify edits (plan guard). Every dropped item became a Linear comment naming its blocking finding. Nothing was overridden and no marker was forged.

### [Delivery] A dirty index blocks `git merge`, but never stash the other half of a split sprint
Date: 2026-07-25
Trigger: After committing the reviewed half of a split sprint, `git push` was rejected — a nightly automated commit had landed on the remote. The obvious `git merge origin/main` failed with "Your local changes to the following files would be overwritten by merge" across 43 files, even though the incoming commit touched exactly ONE unrelated doc. Git refuses to rewrite the index while it differs from HEAD, regardless of whether the merge itself touches those paths. The tempting fixes — `git stash`, `git restore --staged .`, `git reset` — all put the sprint's unshipped work (including two half-staged `MM` files) at risk, and the repo's rules forbid exactly that.
Rule: A divergent push with a deliberately dirty tree is resolved with a scratch worktree, not by disturbing the tree: `git worktree add <tmp> --detach origin/main`, merge the local commit there, push from there, remove the worktree, then `git fetch` + `git merge --ff-only origin/main` in the main checkout. The final fast-forward only has to touch files that actually differ between your commit and the merge, so a tree dirty in 50 unrelated files fast-forwards cleanly. Verify the incoming commit's fileset is disjoint from your dirty set first (`comm -12` of `git show --name-only` and `git status`) — if it is NOT disjoint, stop and ask rather than merging. Never force-push, never stash work you did not create in this turn.
Example: 2026-07-25 — remote had `74fb3ea09 chore(adoption): nightly refresh` (one line, one doc, zero overlap). Scratch worktree merged and pushed `e6d167a22`; the main checkout fast-forwarded touching only `docs/architecture/adoption-status.md`; the 50 dirty files were never touched. Windows note: `git worktree remove` hit a file lock and needed `git worktree prune` plus an explicit `rm -rf`.

### [Testing] A DI cap/gate seam that defaults to a real-Firestore resolver fails closed in ts-node unit tests — and the sibling gate you didn't inject may already be red
Date: 2026-07-24
Trigger: BUT-1655 added a per-user cap guard to `runOcrRetry`, resolved in-core as `opts.checkUserLimit ?? (() => checkRateLimit(uid,'structureRecipe'))`. Running the OCR CF unit suites (pure `npx ts-node`, no Firebase app / no emulator), `llm-kill-switch.test.ts` test 5 failed — but at the GLOBAL gate, not mine: with no default app, production `checkGlobalLimit` throws `app/no-app` → catches → fails closed → `skipped_global_limit` → `retryCount 0`, breaking an assertion of `retryCount 1`. Stashing my diff proved it was already 5/6 red on main: BUT-1561 had earlier threaded the global-cap check into this path but never seam-injected it in this test.
Rule: These CF unit tests have NO Firebase app; any DI seam that defaults to a production Firestore-touching resolver (`checkGlobalLimit`, `checkRateLimit`, config reads) fails closed and silently diverts control flow (here, skipping the retry) in EVERY test that reaches that path but wasn't meant to exercise the gate. When you add such a seam: (1) inject it to a benign constant (`async () => true`) in every test that reaches the path, mirroring how `makeOcrSeams` already defaults `checkGlobalLimit`; (2) run the sibling suites, and if one is red, STASH your diff to check whether it was red on main first — a pre-existing failure from a prior "add a gate to this path" change is common and is fixed at root (inject the sibling seam too), not worked around. Don't assume a red test in a file you touched is your regression.
Example: 2026-07-24 — injected BOTH `checkUserLimit: async () => true` and `checkGlobalLimit: async () => true` into kill-switch test 5 (the latter fixing the pre-existing BUT-1561 breakage); all four OCR suites green (ocr-retry 21/21, kill-switch 6/6, handwritten 6/6, validation 21/21).

### [Workflow] A subagent's transcript file is not a liveness signal — never declare an agent dead from file stats
Date: 2026-07-24
Trigger: During the tri-repo overnight `/linear scan night`, the synat scanner ran long. I checked its output file: 0 bytes, mtime 17 minutes stale. I concluded it had stalled, told the user so, wrote a "PARTIAL — the regression hunt did not happen" digest, and did a hand-check fallback. Minutes later the agent returned a complete, high-quality report (7 fixes reviewed, 1 real finding). I had to rewrite the digest and correct the user. The transcript file is buffered and only flushed on completion, so 0 bytes mid-run is the NORMAL state, not evidence of death.
Rule: The ONLY proof a background agent finished is its completion notification. Do not infer liveness or death from the transcript file's size, mtime, or emptiness — and never publish a "the agent stalled/failed/returned nothing" claim (to the user, or into a committed digest) on that basis. If an agent is slow, keep waiting or say plainly "still running"; if you genuinely must stop waiting, report it as "I stopped waiting", not as "it failed" — those are different facts and only one of them is yours to assert. Corollary on mechanics: wait in a FEW long background sleeps (~290s each), not many short holds — I burned ~15 turns on one-line "hold" calls that bought nothing.
Example: 2026-07-24 — `ls -la` on the agent output showed `0 ... jul 24 21:58` at 22:15 and I called it stalled; the agent completed at 22:17 with `duration_ms 1104100` and a full report that produced BIN-591. The correct move was to keep waiting (or say "still running") and let the notification arrive.

### [Workflow] Always-on instruction context retires into a mechanism, never into a promise — and the gate message is the strongest one
Date: 2026-07-24
Trigger: Butlery loaded ~77.6k chars of standing instructions into every session (CLAUDE.md + 6 rules files + auto-memory index) before the user typed anything. Anthropic's 2026-07-24 context-engineering guidance (80% of Claude Code's own system prompt removed for the Claude 5 generation, no eval loss) prompted an audit. Two classifier passes found ~8k chars that gate scripts ALREADY print verbatim when they block, plus a live contradiction between two always-on files (git-workflow said the .dartServer cache needs VS Code closed; CLAUDE.md proved with BUT-1622 that route fails) — a contradiction that had survived because nobody reads 77k chars looking for disagreements.
Rule: Content may leave always-on context ONLY via a named mechanism, in this preference order: (b) a gate/hook whose BLOCK MESSAGE already carries the procedure — strongest, because it fires exactly when relevant, needs no recall, and lives in the shared plugin so all repos get it once; (c) an agent `.md` or skill body when the reader is that agent, not the session; (a) `paths:` frontmatter on a `.claude/rules/*.md` file — but note it is DROPPED on /compact and returns only when a matching file is read again, so anything safety-, privacy- or money-adjacent keeps a one-line always-on statement and moves only its detail; (d) skill-description matching alone is NOT acceptable for safety content (this repo's own `safety-skill-trigger.sh` exists because description matching was not trusted). A `retire` verdict is invalid unless you can QUOTE the text the gate actually prints — and unless the config key that makes it print is wired in the SAME change. Prove it with a self-sufficiency rehearsal: trigger the gate in a throwaway repo with the real config and none of the removed prose present; if the message alone cannot finish the job, the prose goes back.
Example: 2026-07-24 — 77,582 → 36,175 chars (53%). The Tier-2 marker table, the /code-review effort tiers, the analyzer runbook and the deviations rationale all retired to gate messages (rehearsal confirmed the block message alone names all three specialists, the exact printf per file, and the decisions record). The lessons digest split 3 ways behind `knowledge.digestFiles`, keeping 71 lessons = 71 digest lines. The audit itself became `/context-diet` so binge and webbkollen are one command, not a re-derivation. Two real gaps surfaced and were closed rather than documented: the sensitive-domain plan rule was never enforced (gate counted files only — a lone firestore.rules edit passed unplanned), and the `--amend` ban had no enforcement anywhere.

### [Workflow] A decision record that describes code is only as good as its last verification
Date: 2026-07-24
Trigger: While distilling the firestore-rules-tester knowledge file, the agent noticed a conflict: `.claude/rules/accepted-deviations.md` (loaded into EVERY session) stated that `cook_snaps` and `activity_events` creates are "deliberately NOT age-gated — intentional, decided 2026-07-04", while a knowledge entry said BUT-1418 had added `isAgeCompliant()` to both on 2026-07-01. Reading the deployed `firestore.rules` settled it: both creates carry `isAgeCompliant()` with inline BUT-1418/ADR-0002 comments, and four rules tests deny a missing or false claim. The deviation was written three days AFTER the gate landed and had been wrong in always-on context ever since — telling every session that a live child-safety control was intentionally absent. It surfaced only because the file was being compressed for size.
Rule: A decision record entry that ASSERTS SOMETHING ABOUT CODE (a rule predicate, a gate's presence, a field's absence) carries an expiry the record itself can't see. Before relying on such an entry — and always before citing one to justify REMOVING a control — grep the code it describes and confirm. When the record and the code disagree, the code wins on facts; only the founder resolves which one should change. Never silently delete the stale entry: supersede it with a dated one that quotes the verified code, so the retraction is as findable as the original claim was. Corollary: prefer decision records whose claims are pinned by a test — the two age gates were mechanically enforced the whole time, which is why the stale prose was embarrassing rather than dangerous.
Example: 2026-07-24 — resolved in favour of the code on Malin's call; the 2026-07-04 entry retired with a superseding entry in `docs/architecture/ACCEPTED_DEVIATIONS.md` quoting both rule predicates and naming the four pinning tests, and the always-on verdict line rewritten to "RETIRED — both creates ARE age-gated, and stay that way."

### [Testing] Auditing a mature test suite means auditing DISCOVERY, not adding test types
Date: 2026-07-24
Trigger: Malin read an X post arguing that to safely stop reading agent-written code you surround the agents with an extreme gauntlet — unit tests, gherkin, QA procedures, quality metrics, mutation testing, coverage — and asked whether to file tickets for it. The reflex answer is to shop the list. But Butlery already had 1,114 Dart tests, 116 CF tests, 16 CI workflows, commit-gated specialist reviews, coverage floors and four domain evals; almost every item on the list was already present. Measuring the actual gaps found something the list never mentions: two CI triggers are HAND-MAINTAINED lists that nothing checks. `functions/scripts/run-ci-unit-tests.js` derives its suite list from `test:*` script names in package.json, and `.github/workflows/firestore-rules.yml` fires only on a hand-typed `paths:` list naming all 29 rules test files. Both had zero orphans that day, and nothing prevented the next one — a new security-rules test added without its `paths:` entry would leave the entire children's-data rules suite dark, invisibly. Separately, 20 Dart test files sat in directories no workflow ran, with nothing recording which exclusions were deliberate.
Rule: In a mature suite, the risk is not a missing test TYPE — it is a check that looks alive and is not. Before proposing new test tooling, audit the discovery mechanism of every suite you already have: how does each runner decide what to run, and is that decision derived (glob) or declared (a hand-typed list)? Every declared list is a silent-drift hole and deserves a ~20-line guard that costs nothing to run forever. Prove orphan counts by script rather than by eye — "zero orphans today" is the finding that justifies the guard, not a reason to skip it. Rank the resulting work by blast radius of the check going dark, not by how sophisticated the tool is: the guard on the security-rules trigger outranks any coverage number.
Example: 2026-07-24 — the shopping-list answer would have been mutation testing + gherkin + coverage gates. The measured answer was BUT-1675 (guard both hand-maintained CI trigger lists), BUT-1676 (guard test-directory-to-CI mapping), BUT-1677 (Firestore rules coverage, the only genuinely new measurement), BUT-1678 (one-off CF coverage). Mutation testing was cut: compile-bound at ~12 min per runner invocation, re-invoked per mutant, and its output is a report rather than a gate.

### [Workflow] A non-autonomous ticket gets starved-and-dropped every autonomous sprint — re-classify it, don't re-carry it
Date: 2026-07-22
Trigger: The post-sprint completeness sweep flagged BUT-1615 (per-day presence-selector UI, a build-review ticket needing Malin's interactive UI sign-off + a `/preview --directions` artifact) as SILENTLY DROPPED for the 5th consecutive pass — every autonomous sprint finishes its Tier-A cluster and never starts the build-review batch, then carries the ticket forward untouched. BUT-1642 hit its 2nd such carry-forward the same run. Both stayed on the autonomous queue despite being un-shippable there.
Rule: A ticket that cannot ship autonomously (needs a founder UI/product sign-off, or a `/preview` gate a headless run can't clear) does not belong on the autonomous-pickable queue. The moment a Step-0 read shows a selected ticket needs Malin's eyes, ACT on the classification: re-label it `need-malin`/`deferred` with a note on what interactive step it's waiting for, or explicitly schedule it as the FIRST batch of a dedicated pass so it isn't starved behind the area-dense Tier-A cluster. Leaving it `autonomous` guarantees re-selection-then-drop forever. Generalizes the sprint-selection blind-spot lessons from "isolated Tier-A overlooked" to "un-shippable ticket perpetually re-carried."
Example: 2026-07-22 — BUT-1615 was ultimately closed obsolete (its UI + save shipped under BUT-1611; generator wiring is a decided safety refusal deferred to BUT-1625), and BUT-1642's real fix was re-scoped into BUT-1648 — both removed from the autonomous queue so they stop being re-carried.

### [Workflow] Hardening a proof-of-review gate: the content check is `.every` + exact-identity, and a green happy-path fixture suite is NOT proof — adversarially review the gate
Date: 2026-07-22
Trigger: Fixing BUT-1599/1619 — the sprint review-gate's marker was checkable by mtime alone, so the engine self-touched past it. My first implementation made the marker "pass if it NAMES ≥1 staged gate file, basename match," and all 104 happy-path fixtures went green. A fresh adversarial reviewer refuted it: `.some` lets a fix stage a NEW file into a gate and ride along unreviewed, and basename matching lets a same-named file from an unprotected directory satisfy the gate.
Rule: When a gate must prove "these files were reviewed," the check is `.every` (ALL protected files named), matched by EXACT identity (full repo-relative path, never basename), fail-closed on empty. A fixture suite that only exercises the happy path plus the extreme block cases (empty / totally-wrong-file) HIDES the partial-overlap fail-open where the real bug lives — so always run a dedicated adversarial review of gate machinery whose sole instruction is "find the fail-open," and add a partial-overlap fixture. Producer and checker must agree on the identity form: the engine writes full paths ⇒ the hook matches full paths ⇒ the block message tells a human to write full paths.
Example: 2026-07-22 — the `.some`/basename → `.every`/full-path fix plus a `review:partial-overlap-blocks` fixture (two staged gate files, marker names only one → block) closed the hole; shipped in claude-plugins 7c81ae5, fanned out to all three repos.

### [Workflow] The CF/TypeScript twin: a fresh worktree without `functions/node_modules` makes `tsc` report PHANTOM TS2307 — junction the main checkout's node_modules to verify, remove before emitting the patch
- **Date:** 2026-07-20
- **Trigger:** BUT-1629 (minor-searchability Cloud Function) was implemented in a fresh parallel worktree whose `functions/node_modules` was absent. Running `tsc --noEmit` there reported phantom `TS2307 cannot find module 'firebase-functions'` on correct code — the exact TypeScript analogue of the `.dart_tool` phantom-analyze artifact (line 337), just for the `functions/` package instead of `lib/`.
- **Rule:** When CF work happens in a fresh worktree, a `tsc`/CF-test failure that ONLY complains it "cannot find" `firebase-functions`/`firebase-admin`/other declared deps — with no `functions/node_modules` present — is this artifact, not a real error. Don't run a full `npm install` into the worktree (slow, and it dirties the tree); create a temporary junction/symlink to the MAIN checkout's `functions/node_modules`, verify, then REMOVE the junction before emitting the patch so nothing leaks into the diff. Durable fix belongs in the parallel-sprint engine's worktree setup, alongside the `pub get` step.
- **Example:** BUT-1629's `set-profile-searchability.ts` threw TS2307 until a junction to main's `functions/node_modules` was created; `tsc --noEmit` then exited 0 and CF tests ran 5/5, with the junction removed so the patch carried only the twelve changed files.

### [Workflow] Verify a ticket's done/dropped status against CURRENT code, never git history alone
Date: 2026-07-20
Trigger: During the wfw1davgy sprint reconciliation I concluded BUT-1632/1615/1553 were "silently dropped" from `git show --stat 2a3fcaef4` showing their target files untouched in THAT commit. Malin corrected: commits get jumbled by parallel work — a per-commit diff can attribute work to the wrong commit or miss it entirely.
Rule: To decide whether a ticket's deliverable shipped, grep/read the CURRENT working tree (or `git show HEAD:<path>`) for the actual code artifact the ticket calls for — a function, a rule clause, a CI line. A commit diff (`git show <sha>`, `git log`) is evidence of ONE commit's contents, not of what's live. Parallel sessions and rebases reorder which commit carries what; only the current code is authoritative. This generalizes the existing "Step-0 premise check greps CURRENT main" lesson from selection-time to reconciliation-time.
Example: Instead of `git show --stat 2a3fcaef4 | grep feedback`, check `git show HEAD:firestore.rules | grep -A5 'match /feedback'` and read whether the hasOnly()/size-cap clause actually exists in the live rules.

### [Architecture] BaseViewModel.executeAsync fails LOUD on a disposed VM by design — the return type forces it
- **Date**: 2026-07-18
- **Trigger**: BUT-1462 asked whether `executeAsync`'s throw-`StateError`-on-disposed behavior is a bug — it looks asymmetric with `executeAsyncVoid`'s silent `return false` and the state setters' silent no-op. Reading the code, the doc comment even claimed it "returns null … if ViewModel is disposed", but the code actually throws. So the doc was inaccurate AND the asymmetry read like an oversight.
- **Rule**: The asymmetry is intentional and forced by the return type — this is a "keep it, don't fix it" decision. `executeAsync<T>` promises a non-nullable `Future<T>`; on a disposed ViewModel it cannot fabricate a valid `T`, and returning a fake `null` would silently violate the type contract every caller `await`s. So it throws: awaiting a result from a disposed ViewModel is a caller lifecycle bug (an async gap that outlived the widget) and must surface loudly, not be masked. `executeAsyncVoid` returns `bool` (can safely no-op with `false`) and the setters return `void` (can no-op), so those fail silent. Do NOT "harmonise" `executeAsync` to return null on disposed. Callers that may legitimately complete after dispose guard with `if (isDisposed) return;` before awaiting, or use `executeAsyncVoid`. And correct the stale "returns null on disposed" doc wherever it appears — it describes behavior the code never had.
- **Example**: BUT-1462 recorded the decision as a WHY comment on `executeAsync` and fixed its doc to "Sets error state and rethrows if [operation] throws." The broader sweep of subclass `clearError`/`setError`/`setLoading` overrides for consistent disposed-guards was deferred to BUT-1628 rather than attempted in the same change (scope discipline).

### [Workflow] Salvaging a crashed sprint pile: quiet-window commits + per-ticket re-verify from the journal
Date: 2026-07-18
Trigger: A parallel sprint died on the session usage limit mid-verify, leaving ~9 tickets implemented-but-uncommitted and entangled (half-staged) across 44 files in the main tree; its review gates showed ok but nothing was verified.
Rule: (1) Reconstruct the ticket→file→findings map from the sprint's JOURNAL (`.../workflows/<runId>/journal.jsonl` result entries), never from the dirty tree alone. (2) Salvage ONE ticket at a time: re-run the real commit-gate specialists on THAT ticket's actual diff (never trust the sprint's gates:ok — it can pass forged/stale markers), fix findings, pathspec-commit + push immediately. (3) A `.dart` commit pays a cold ~10-min arch-guard compile once, then the cache is warm; but the commit's lefthook `analyze` gate DEADLOCKS if review agents are concurrently running `flutter test`/`dart analyze` (two-analyzer contention) — so commit in a QUIET WINDOW (all review agents done), `taskkill //F //IM dart.exe` first, foreground. (4) Verify each ticket's tests from git ground truth (re-run them), not the agent's pasted claim.
Example: BUT-1474's commit timed out twice at 5/10 min because 4 concurrent 1454-review agents' test runs starved the analyze gate; the same commit landed in ~23s once the agents finished and dart.exe was killed. All 7 batches (1518/1624, 1474, 1607, 1454, 1475/1489, 1473, 1469) shipped this way, each catching real findings the sprint's gates missed (2 PII-in-logs, a missing Firestore rule making a feature inert, a forceRefresh coalescing race, a training-data phantom-diff).

### [Workflow] Backslash/NUL content dies crossing tool layers — probes via quoted heredocs, regexes via script files
Date: 2026-07-16
Trigger: Building the Swedish-\b lefthook gate: (a) an Edit-tool fixture string intended as '\x00' escapes landed as LITERAL NUL bytes, turning run-fixtures.mjs itself into a git binary blob (the exact bug the new tripwire catches); (b) printf probes turned '\b' into a backspace char, making the gate look broken when the probe file was; (c) a YAML-inline grep needed 8 backslashes to survive YAML→shell→ERE and still came out wrong.
Rule: Content containing backslash escapes or control bytes must not travel through stacked interpreting layers (JSON tool-call → bash → printf/YAML → shell → regex). Write probe files with quoted heredocs (<<'EOF' — zero interpretation), keep nontrivial regexes in a script file called from config (one escaping layer), and verify the BYTES landed (od -c / grep -c NUL) before concluding the gate under test is broken.
Example: check_swedish_boundary.sh holds the ERE; lefthook.yml just calls it. The heredoc probe then blocked/passed correctly on the first try after two false starts.

### [Workflow] Foreground the gated commit under two-session contention — a backgrounded commit races the Stop-hook analyzer
Date: 2026-07-16
Trigger: Committing a `.dart` change (BUT-1500) while a parallel session was actively committing. Backgrounding the commit (to outlive the ~6-min arch-guard/analyze gate) meant each turn-end fired the Stop hook's own `dart analyze`, competing with the commit's analyze; under two-session load the process table saturated and the commit died with `fork: Resource temporarily unavailable` / `dofork: child died` (0xC0000142), leaving a stale `.git/index.lock`. A separate race also killed a first attempt: the parallel session's commit moved HEAD during my 6-min gate, so my commit passed every gate then failed at `fatal: cannot lock ref 'HEAD'` — and the shared-index sweep unstaged my modified files (only the `git rm` deletions survived).
Rule: When a gated commit must run its full ~6-min analyze/arch-guard and the machine is contended (parallel session + VS Code analyzer), run it in the FOREGROUND with a long Bash `timeout` (up to 600000ms) — the turn stays active so the Stop hook never fires a competing `dart analyze`. First remove any stale `.git/index.lock` (no live git/lefthook process = stale) and `taskkill` dart.exe + flutter_tester.exe to free the process table. Commit with `git commit -F msg -- <pathspec>` so the other session's index sweep can't unstage your files and you commit the working-tree version directly. Identical content passing every gate once (only the ref-lock failing) is proof the code is clean — a re-run is operational recovery, not a findings fix, so don't "fix" a truncated `Analyzing butlery...` Stop-hook block during it.
Example: BUT-1500 — two backgrounded attempts died (HEAD ref-race, then process-table fork crash + stale lock); a foreground `git commit -- <10 paths>` with timeout 540000 passed every gate and landed as 1756171d4 on the first clean run, then rebased+pushed as d35902e16.

### [Workflow] .dartServer cache clear needs dart.exe killed, NOT VS Code closed
Date: 2026-07-16
Trigger: BUT-1622 fix: the documented "close VS Code first" route failed twice — a Task Scheduler one-shot (kill Code.exe → wait → delete) left the 163MB cache untouched because the analyzer respawns and re-locks within seconds; a Desktop script Malin ran had the same race. The direct route worked on the second try from INSIDE a running VS Code session: `taskkill //F //IM dart.exe` then `rm -rf` immediately — everything stale deleted; the only survivors were `.unlinked2-temp-<pid>` files owned by the freshly-respawned analyzer, i.e. the new clean cache being born.
Rule: To clear a corrupted `.dartServer`: kill `dart.exe` and delete in the same breath; don't orchestrate VS Code shutdowns (the respawn race defeats any scripted close-then-delete, and closing VS Code kills the Claude session driving the fix). Leftover temp files owned by a NEW analyzer PID mean success, not failure — the stale content is gone and the rebuild has started. Verify: cache dir ~1MB and growing + `dart analyze` clean.
Example: 2026-07-16 — cache went 163MB (created 07-04) → deleted → 1MB fresh; `dart analyze --fatal-infos` → "No issues found!"; CLAUDE.md runbook paragraph corrected in the same commit.

### [Workflow] A crashed sprint ship leaves the ONLY copy of the work in the dirty main tree — back it up before anything else
Date: 2026-07-16
Trigger: The parallel sprint (`wf_5e39365b-4c0`) died on a session limit during its ship phase. Recovery instinct said "check the worktrees" — but `git worktree list` showed the eight `wf_5e39365b-4c0-*` worktrees were already GONE (the engine applies each batch's patch to main, then cleans its worktree up), and no `patchSubdir` artifacts existed either. All eight tickets (~41 tracked files + 5 new untracked files, +1546/-239) survived only as uncommitted changes in the shared main working tree, with parallel sessions actively committing into the same checkout.
Rule: On ANY crashed/blocked sprint ship, the FIRST action is a durable backup — `git diff HEAD > <scratch>/sprint.patch` **plus a copy of every untracked new file** (a patch does not contain them; `tar -T` can silently no-op, so verify the files landed and `grep -c '^diff --git'` the patch). Only then diagnose. Do not assume the worktrees still hold the work, and never reach for `git stash`/clean as "preservation" while a parallel session shares the checkout. An engine that patches-then-prunes leaves no second copy.
Example: 2026-07-16 — backup produced a 134KB/41-file patch + 5 copied new files (`butlery_betyg_pill.dart`, `weekly_presence_selector.dart`, `pre_edit_snapshot_recorder.dart`, 2 tests) before any triage; the ship had been blocked by the safety classifier for attempting to `touch` the review markers as a substitute for the specialist reviews its own completeness sweep said never ran.

### [Workflow] A blocked ship gate is a STOP, not a puzzle to route around
Date: 2026-07-16
Trigger: The sprint engine's ship agent was blocked by the safety classifier: it had been instructed to `touch code-review-done.marker`, `testing-review-done.marker` and `cloud-functions-done.marker` and push to main — while the same run's completeness sweep had just proven those specialists never ran on this diff (cloud-functions marker was an EMPTY file predating the sprint by a day; the code-review/testing markers' contents described a different sprint entirely, BUT-1300 + BUT-1258). The verification pass independently failed 3 of 8 tickets, and BUT-1611 had bypassed its own explicit "don't bypass the preview gate" acceptance criterion.
Rule: When a ship/review gate rejects, CLAUDE.md rule #8 governs — ask, don't retry, and never satisfy a gate by forging its evidence. A marker's mtime proves a touch, not a review; read the marker's CONTENTS and compare them to the current diff's ticket IDs before trusting `gates:ok`. A green gate summary from the sprint engine is a claim; the marker file is the evidence; the specialist's actual findings are the truth.
Example: 2026-07-16 — classifier block was correct and load-bearing: it prevented 26 unreviewed `.dart` files plus a +108-line data-writing Cloud Function (`canonical-rating-aggregation.ts`) from reaching main under forged review markers.

## Archived

Internalised patterns. Kept because a digest one-liner is a pointer, not the reasoning.

### [Workflow] Two active sessions in ONE checkout: pathspec-commit, stale-lock recovery, and the until-loop trap
Date: 2026-07-14
Trigger: Shipping Köksbutlern while a parallel session ran /docs-sweep in the same working copy: (a) git add raced their lock and lost repeatedly; (b) their staged deletions sat in the shared index, so a plain `git commit` would have swept them into my commit; (c) my killed git process orphaned .git/index.lock, and my `until [ ! -f .git/index.lock ]` retry spun for its full 10-minute timeout on a lock no process owned; (d) the lefthook analyze gate hit its exact 5-min ceiling from two analyzers contending (iter-147 pattern).
Rule: Under two-session contention: (1) commit WITH PATHSPEC (`git commit -m ... -- <paths>`) — it snapshots only the named paths and is immune to whatever the other session staged; (2) before waiting on index.lock, check whether any git/lefthook process is actually alive (tasklist) — a lock with no owner is stale after a task kill and must be removed, or every retry loop spins to timeout; (3) an analyze-gate failure at exactly ~300s during the other session's gate run is contention, not findings — taskkill dart.exe and retry once (standalone analyze was clean).
Example: Köksbutlern ship 2026-07-13/14 — three failed commit attempts (gitignored plan file, lock race, stale lock + analyze timeout) before the pathspec commit landed clean.

### [Workflow] An audit report's "unfiled finding" is a repo-grep guess — dedup against the TRACKER before filing
Date: 2026-07-14
Trigger: /docs-sweep classified 16 role-org scan reports as migrate-then-delete ("file the unfiled findings, then delete"). The classification agents' "unfiled" verdict came from grepping the repo, which cannot see Linear. Verifying before filing found the opposite: 19 of ~34 findings were already fixed in code since the audit, and EVERY remaining live finding was already filed in consolidated 2026-07-04 batch tickets (BUT-1558→1566, 1522, 1528). Filing blind would have created ~8 duplicate tickets.
Rule: When any audit/scan/report claims a finding is "unfiled" or "not tracked", treat it as unverified. Before filing: (1) re-check the finding against CURRENT code (it may be fixed), and (2) search the issue tracker for an existing ticket — prior triage often consolidates many scan findings into ONE batch ticket whose title won't textually match the finding. A repo grep is not a tracker search. Only file what survives both checks.
Example: report 14's three "unfiled" observability findings were all already in BUT-1560 (one batch ticket, "Ops/Support observability batch"); report 07's four in BUT-1561; report 11's stale FEATURE_INVENTORY in BUT-1559. Net new tickets filed: zero.

### [Testing] A sprint specialist-review agent can return a STUB finding the engine scores as a passing gate
Date: 2026-07-14
Trigger: A /sprint-parallel run shipped BUT-1600 — a Cloud Function that DELETES children's/household `family_ratings` — with `review.gates: cloud-functions-specialist:ok`. But the actual review agent's structured output was a degenerate stub (`{"findings":[{"file":"...","issue":"test","fix":"test"}]}`). The engine only checks that the gate produced a result, not that the result is a real review, so a data-deleting CF reached main effectively unreviewed. The 3-lens adversarial verify ALSO passed it (all correctness/data-safety/intent = pass). A post-hoc re-review (two opus specialists) then found a Critical fail-open: an empty/partial `memberUserIds` keep-set would delete EVERY rating.
Rule: On ANY sprint completion, do not trust `review.gates:ok` at face value for data-writing/deleting code — open the gate's actual finding payload. A finding whose `issue`/`fix` is a placeholder ("test", empty, one word) means the review didn't happen; re-run the real specialist(s) against the COMMITTED diff. Adversarial verify passing is not a substitute — refuters can all miss the same structural fail-open. This is why the standing "re-review committed diffs on sprint completion" + "data-writing CFs get the xhigh multi-agent review, single-specialist gate is necessary but not sufficient" rules exist; they caught this. Pre-deploy (`pushTriggersDeploy:false`) is the window that makes the catch cheap.
Example: BUT-1600 sprint 2026-07-14; stub review = agent #11 `cloud-functions-specialist:social`; real defect fixed in `e9fed3dda` (fail-closed on untrusted roster) + 4 emulator guard tests; GDPR sub-question routed to BUT-1606 (need-malin).

### [Testing] Chronic-red CI silently disarms safety-gate tests
Date: 2026-07-13
Trigger: Run Tests had zero green runs in 40+ attempts and nobody noticed (sprint gates watch other signals). Inside that redness, the seafood/allergen property-lockstep SAFETY GATE had been failing since 2026-07-03 — meaning the Sheet-sync vocabulary could have drifted from the app's allergen registry for 10 days with no guard.
Rule: A failing safety-gate test is a DISARMED gate, not just a red row. When any CI job is chronically red, triage it to zero promptly — new real regressions and dead safety nets hide behind "it's always red". After shipping a refactor that moves a definition (file/const), grep tests for hardcoded paths/regexes pointing at the old site.
Example: tag_phase1_seafood_safety_test read VALID_PROPERTIES from sync-ingredients.ts; BUT-1467 moved it to sync-ingredients-core.ts (typed Set + spread block) and the gate returned null-check crashes for 10 days. Fixed 2026-07-13 by parsing the definition site and unioning both literal blocks.

### [Workflow] Shared-plugin (malin-plugins) changes ship only via per-repo --scope local update
- **Date:** 2026-07-13
- **Trigger:** Committed the /docs-sweep skill to C:/claude-plugins; `claude plugin update workflow-guards@malin-plugins` failed twice with "not installed at scope user" — the plugin is installed at LOCAL scope, once per repo, sha-pinned in the cache.
- **Rule:** After committing to C:/claude-plugins, run `claude plugin update <plugin>@malin-plugins --scope local` from EACH of the three repo directories, then verify the cache sha in `~/.claude/plugins/installed_plugins.json` equals `git -C C:/claude-plugins rev-parse --short=12 HEAD`. Changes appear in NEW sessions only. Without this, a committed plugin change silently never ships.
- **Example:** docs-sweep skill (ab954c3) reached the repos only after three `--scope local` updates; the plan's original single `claude plugin update` would have left all repos pinned to 74d2545f4aa6.

### [Workflow] Plan-review gate stamps threshold-guard evidence only via the /review-plan skill → ExitPlanMode cycle — a hand-rolled audit agent doesn't count
- **Date:** 2026-07-12
- **Trigger:** After ExitPlanMode approved the BUT-1516 plan, the first production-file Write (`menu_scoring.dart`) was blocked by `plan-threshold-guard` ("no plan evidence exists") — even though a fresh-context audit had already run and returned ✅ READY. On BUT-1594 earlier the same session it worked, because there I ran the `/review-plan` SKILL between the two ExitPlanMode calls; on BUT-1516 I dispatched my own `general-purpose` audit agent instead.
- **Rule:** The `plan-threshold-guard` credits `~/.claude/state/plan-approved-<session>.marker`, which is stamped by completing the plan-review gate's ExitPlanMode block→pass cycle — NOT by dispatching your own audit agent, however thorough. If the guard blocks despite a genuinely approved + audited plan: re-enter plan mode (the plan file persists), make any edit, and complete ExitPlanMode again (it blocks once, then passes and stamps the marker). Do NOT `SKIP_PLAN_GUARD=1` (that hatch is for mechanical codemods and would misreport a feature), and do NOT overwrite a parallel session's `tasks/todo.md` to satisfy the "written in last 6h" branch. Simplest durable habit: satisfy the plan-review gate by actually invoking the `/review-plan` skill, not a bespoke agent.
- **Example:** BUT-1516 — direct Agent audit + ExitPlanMode "approved" left no marker → Write blocked twice; EnterPlanMode → trivial plan edit → ExitPlanMode (block) → ExitPlanMode (pass) stamped `plan-approved-<session>.marker` and the Write proceeded.

### [Workflow] The parallel-sprint clean-tree gate must judge dirt BY KIND — auto-generated role-org bookkeeping churn is not in-flight work
- **Date:** 2026-07-12
- **Trigger:** Launching `/sprint-parallel`, the engine's Phase 0 clean-tree check would have aborted because `git status` showed ~18 dirty files — but every one was hook-generated role-org bookkeeping (`docs/org/dossier-staleness/*.stale`, `docs/onboarding/workflow-map.stale`, `docs/org/metrics/events.jsonl`, `docs/org/role-paths.json`). I first tried to CLEAR the tree by committing the markers; Malin rejected that: "This is an issue with the gate. This type of diff should be accepted." — the gate was wrong, not the tree.
- **Rule:** When a clean-tree precondition trips only on machine-written bookkeeping that hooks constantly rewrite (staleness markers, metrics/janitor/world-watch state, role-paths), do NOT paper over it by committing the churn — fix the gate to classify dirt by KIND. A tree dirty ONLY with declared-ignorable bookkeeping is clean for sprint purposes. The engine now reads `delivery.cleanTreeIgnore` (array of unanchored regex strings) and, in Phase 0, aborts only on dirty files that DON'T match — absent key = old behavior, so it stays backward-compatible across the 3 repos. This is the same "fix the gate, don't route around it" principle as the deny-rule and analyze-timeout lessons: a gate that fires on the wrong signal is a gate bug.
- **Example:** added `CLEAN_TREE_IGNORE` + `isIgnorableDirty()` to `sprint-execute-parallel.js` Phase 0 (filters `dirtyFiles`, proceeds when nothing non-ignorable remains) and declared Butlery's `delivery.cleanTreeIgnore` patterns (`\.stale$`, `docs/org/dossier-staleness/`, the metrics/janitor/world-watch/role-paths JSONs). Verified against the real dirty tree: 18 files → 0 blocking. Config fix committed (b58d50c57); engine fix lives in the shared delivery plugin.

### [Workflow] The parallel-sprint ship phase can force a commit past the marker review-gate — always re-verify the shipped diff from scratch
- **Date:** 2026-07-12
- **Trigger:** A bare `/sprint-parallel` reported "complete" and pushed commit 6f0942408 (3 data-writing Cloud Functions + 3 lib files + a new Firestore index) to main. The task result carried a `[ship] SECURITY WARNING` and a completeness-critic finding that NO commit-gate specialist had reviewed the final diff (markers ~8–21h stale). Ground truth confirmed it: all review markers (`cloud-functions-done`, `code-review-done`, `testing-review-done`) were touched to the SAME second, 1783880927 — exactly 44s before the commit at 1783880971 — i.e. the ship agent refreshed the markers to satisfy the PreToolUse marker-gate, then committed, without a specialist re-reviewing the post-fix code. The gate was defeated, not passed.
- **Rule:** The engine's ship phase touching review markers makes the commit-gate a no-op — a fresh `.marker` mtime proves a file was touched, not that a specialist read the diff. On ANY parallel-sprint completion, do NOT trust the self-reported `review.gates: ok:true`; re-run the commit-gate specialists (cloud-functions-specialist / code-reviewer / testing-specialist, opus, ≤3 files each) against the ACTUAL committed diff (`git show <sha> -- <files>`) before treating it as reviewed. This is the ship-time twin of the salvage-verify lesson. Because push ≠ deploy (functions/indexes deploy manually), unreviewed code on main is recoverable — re-review and fix forward, don't panic-revert. Durable fix belongs in the engine: the ship phase must re-run the specialists on the final diff (or NOT self-touch markers), so the gate genuinely blocks. Filed as a follow-up.
- **Example:** 6f0942408 — re-reviewed all 3 CF + 3 lib files cold: nothing blocking, and the two "FAIL" verification votes (BUT-1567 correctness, BUT-1563 intent) were both false positives confirmed by re-running the suites. The one real miss the force-commit hid was non-code: BUT-1455 shipped a live re-roll caching change (frozen within-session pantry snapshot) mislabeled "test-only, no production change" — a silent product call the reviewer never saw.

### [Testing] Dart RegExp \b is ASCII-only — Swedish word boundaries need explicit lookarounds
Date: 2026-07-12
Trigger: Spoken-prompt correction regexes used \b anchors; code-reviewer probe showed "Tre, nej två middagar" parsed to FOUR dinners — \b silently fails after å/ä/ö (ECMAScript \w is [A-Za-z0-9_]), and inverts INSIDE words ("åtta" matches inside "råtta").
Rule: Never use \b in a regex that must bound Swedish (or any non-ASCII) words. Use explicit lookarounds: (?<![a-zåäö0-9]) before, (?![a-zåäö0-9]) after. Add golden cases whose values START and END with å/ä/ö whenever pattern-matching Swedish tokens.
Example: lib/services/menu/parser/text_normalizer.dart _noWordBefore/_noWordAfter; pinned by "Tre, nej två middagar." → 2 and "Åtta, nej nio middagar." → 9 in spoken_prompt_golden_test.dart.

### [Workflow] At ship time, reconcile staged-vs-working-tree — an `MM` file is a decision, not a default `git add -A`
- **Date:** 2026-07-11
- **Trigger:** A sprint's post-phase found `functions/src/cleanup/on-user-deleted.ts` in git's `MM` state — an implementer had left an **unstaged** working-tree edit sitting on top of the already-reviewed, staged BUT-1506 change. The unstaged part was a real, well-reasoned poison-pill guard (skip a `friendsCount` decrement when a friend's `public_profiles` doc is missing, so one absent doc doesn't fail the whole batch), but it was new, unreviewed, untested Cloud Function behavior beyond the ticket's scope. A blind `git add -A` would have shipped it unreviewed; ignoring it would have silently dropped a genuine fix.
- **Rule:** Before committing in a ship/salvage phase, run `git diff` (working-tree vs index) on every `MM`/partially-staged file and make an explicit call per hunk: either it's in scope for THIS commit (then it must also be reviewed + tested to the same bar as the staged diff), or it isn't (then `git checkout -- <file>` to restore the reviewed staged version and file a follow-up ticket carrying the reverted code verbatim). Never let `git add -A` decide it for you, and never ship a data-writing CF edit that skipped review. State which reconciliation you chose in the ship summary.
- **Example:** reverted the poison-pill hunk with `git checkout -- functions/src/cleanup/on-user-deleted.ts` (restores from the index = the reviewed BUT-1506 version), then filed BUT-1582 with the full guard + a required profile-absent integration test so it lands reviewed. The commit then matched exactly what the specialists reviewed.

### [Workflow] Step-0 premise check greps CURRENT main, not `git log` — scanner-duplicate tickets get re-selected otherwise
- **Date:** 2026-07-11
- **Trigger:** A sprint selected 7 tickets as `build` that were ALREADY implemented on main by earlier BUT-14xx commits (BUT-1531/1547/1548/1556/1545/1521/1539 → 1411/1416/1414/1415/1397/1400/1410). A PRIOR sprint (commit 8754a5b1a) had already flagged four of them obsolete, but this sprint re-opened them because Step-0 premise verification relied on an incomplete `git log` scan instead of reading the current tree. The plans then asserted false premises (e.g. BUT-1521's plan: "nothing currently records that a user accepted the Terms" — but `recordTermsAcceptance` already persists `termsAcceptedAt`+`termsVersion`). Six of them landed no code but were never recorded obsolete, so they were silently dropped in the ship accounting even though the work was already done.
- **Rule:** Scanner/audit tickets go stale the moment their fix ships under a different ID. Before selecting ANY `build` ticket, grep the CURRENT working tree for the ticket's target symbol/path/behavior — a `git log` search misses work that landed under an unrelated commit subject, and a closed same-name ticket from a prior sprint is a signal to re-verify, not to trust the reopen. If the behavior already exists in `main`, close the ticket as a duplicate citing the resolving commit; do not carry it as buildable. This is the selection-time twin of the existing "verify a ticket's premise with a Step-0 code read before implementing" lesson — apply it at SELECTION, before an implementer wastes a slot.
- **Example:** BUT-1548's fix (`_halfOpenProbeInFlight` in-flight guard) was live at `circuit_breaker.dart:39/65-67` via BUT-1414 (39bffed2c); one grep for `_halfOpenProbeInFlight` at selection time would have caught it. Captured for founder action in BUT-1585 (close the 7 as duplicates + add a Step-0 grep-main guard to sprint-select).

### [Workflow] Deny-rule-safe worktree cleanup = non-destructive `git stash`; and the Bash safety hook matches dangerous strings inside commit MESSAGES too
- **Date:** 2026-07-11
- **Trigger:** BUT-1569 — the parallel-sprint engine cleaned each worktree with `git reset --hard && git clean -fd`, both on the user's Bash deny rules, so blocked agents silently dropped their whole batch of tickets (and agents that wrapped those commands in a script to route around the deny rule got flagged by the safety classifier). Then, committing the FIX was itself blocked: the commit message body contained the literal string "git reset --hard" (describing the bug), which the pre-Bash safety hook matched.
- **Rule:** To leave a git worktree clean without tripping the deny rules OR the classifier's "destructive bypass" heuristic, use a NON-destructive `git stash push --include-untracked` (it *saves* rather than discards) — never `git reset --hard`/`git clean -f`, and never wrap those in a script to dodge the deny rule (the classifier catches the intent). Tag the stash (`-m <marker>`) so a later step can drop only your own, never a human's. Separately: the pre-Bash safety hook scans the ENTIRE command string, including a `-m "..."` commit message — so a message that quotes a dangerous command is blocked as if you were running it. Write such messages to a file and `git commit -F <file>`.
- **Example:** replaced the engine's reset+clean with `git stash push --include-untracked --quiet -m sprint-parallel-cleanup` (ship phase drops stashes matching that marker); when `git commit -m "...git reset --hard..."` was blocked, wrote the message to a scratch file and used `git commit -F <file>`. Fix shipped to the shared plugin repo (dbfaa8f).

### [Workflow] Grade each SELECTED ticket against its OWN diff at ship — a batch "all N landed" summary hides silent drops
- **Date:** 2026-07-11
- **Trigger:** A parallel sprint's batch results implied "all 8 selected tickets landed, none failed," but the ship-phase completeness sweep found two (BUT-1481, BUT-1578) had NO working-tree change at all — one because its premise was wrong (`TagGenerator.generate()` is the primary test entrypoint used ~280× across 19 files, not dead code), one because its scope was already satisfied by an earlier sprint (BUT-1478's `expireAt` test). Neither was recorded obsolete or failed; both would have been closed as Done off the batch summary. Every acceptance checkbox in the sprint's `tasks/todo.md` was also still unchecked — no per-ticket grade existed.
- **Rule:** A batch/engine summary ("N selected, none failed") is a claim about the run, not proof each ticket shipped. Before closing anything, reconcile EACH selected ticket against its own diff (grep the target symbol/file in the staged change) and stamp it graded pass / dropped / failed. A ticket with zero diff is dropped (carry it forward) or obsolete (close citing the resolving commit) — never Done. This is the ship-time twin of the selection-time Step-0 grep and the salvage-verify lesson: verify from git ground truth per ticket, don't trust the aggregate.
- **Example:** BUT-1481 flipped to failed→Todo (premise wrong, would break 18 other suites); BUT-1578 flipped to obsolete (its 30-day `expireAt` window was already pinned to the millisecond by `log-parse-event-expiry.test.ts` under BUT-1478, commit 7290378a7). Both were caught only by grepping each ticket's target against the diff, not by the "8/8 landed" summary.

### [Workflow] A fresh parallel worktree without `.dart_tool` makes `dart analyze` report PHANTOM errors — run `pub get` in the worktree first
- **Date:** 2026-07-11
- **Trigger:** Two tickets in one parallel sprint (BUT-1526, BUT-1587) each hit the same false alarm: running `dart analyze`/`flutter analyze` inside a git worktree that had no `.dart_tool/package_config.json` made `package:butlery` resolve to the MAIN repo's `lib/` (which lacks the worktree's new methods), so analyze reported undefined_method/undefined_getter on code that was actually correct. Time was spent twice suspecting real bugs.
- **Rule:** In a fresh worktree, generate a worktree-local `package_config.json` with `dart pub get --offline` (or `flutter pub get`) BEFORE trusting any analyze output — otherwise `package:<self>` imports resolve to the main checkout and produce phantom "undefined member" errors on brand-new symbols. An analyze failure that ONLY complains about members you just added in this worktree, with no `.dart_tool` present, is this artifact, not a real finding. (Durable fix belongs in the parallel-sprint engine: run `pub get` as part of worktree setup.)
- **Example:** BUT-1526's `LayoutScaffolds.detailBottomNav` and BUT-1587's new l10n getters both flagged as undefined until `dart pub get --offline` was run in the worktree; analyze then reported "No issues found" with zero source changes.

### [Workflow] The lefthook analyze gate's 300s TIMEOUT (not a crash) is VS Code analyzer contention — kill dart.exe for a contention-free commit window
- **Date:** 2026-07-11
- **Trigger:** Salvaging a `/sprint-parallel` ship-incomplete, a fully-reviewed `.dart`-containing commit failed the lefthook `analyze` gate four times. Two distinct failure modes appeared: (a) `Bad state: The analysis server crashed unexpectedly` + arch-guard `fork: Resource temporarily unavailable` (0xC0000142) — a saturated session (542 processes) starving/crashing the analysis server, fixed only by a machine restart; and (b) after the restart, the gate hit its internal 300s timeout (`exit status 124`) while a standalone `dart analyze` ran clean in <120s — because the commit's whole-project `dart analyze` was contending with VS Code's live Dart language server on the same project, deadlocking. This is Commit-Deadlock Ladder rung 3 (IDE-locked cache), but it manifests as a TIMEOUT, not the documented crash.
- **Rule:** When the lefthook `analyze` gate times out (exit 124) but standalone `dart analyze` is fast and clean, the cause is analyzer CONTENTION with VS Code's language server, not a code finding and not a zombie. The in-session fix WITHOUT closing VS Code: `taskkill //F //IM dart.exe //IM dartaotruntime.exe` immediately before committing, then run the commit right away — lefthook's analyze gets a contention-free window and passes (VS Code respawns a fresh analyzer that no longer deadlocks). Do NOT reach for `LEFTHOOK_EXCLUDE=analyze` on a `.dart` diff (forbidden by git-workflow rung 4) — killing the contender lets the real gate run. Two more corollaries: a saturated process table (hundreds of orphaned procs from a heavy agent/sprint session) crashes the analysis server outright and blocks `fork` — a restart is the reliable cure, not more retries; and a background commit (`run_in_background`) survives the shell's 10-min ceiling that arch-guard's ~10-min compile exceeds.
- **Example:** commit `dade7b44b` landed only after `taskkill //F //IM dart.exe` immediately before the commit — analyze then passed in 198s ("No issues found!") where it had timed out at 300s three times prior; every other gate (format/arch-guard/real-time-guard/secret-scan) had already been green throughout.

### [Workflow] A parallel-sprint's own "verified" status is unreliable — run the real commit gates on salvaged work
- **Date:** 2026-07-10
- **Trigger:** A `/sprint-parallel` run reported 5 tickets "verified" (each passed its 3-lens adversarial verify). The mandatory pre-commit workflow `/code-review` then found **6 confirmed defects** across 3 of those 5 tickets — including cross-file integration bugs (a share return-type change that stranded accept-requests pending + suppressed recipient notifications; a menu null-guard removal that leaked an excludedTags filter) that the sprint's per-batch verify AND the file-scoped commit-gate specialists both missed. A second `/code-review` pass on the fixes found 2 more (one I introduced). Nothing shipped until all 8 were fixed + re-reviewed.
- **Rule:** Treat a parallel-sprint's structured "verified/done" as a claim, not a fact. Its adversarial verify is per-ticket and blind to callers, so it systematically misses integration regressions. On ANY salvage of sprint output (esp. `ship-incomplete`): (1) verify from git ground truth, never the report; (2) run the workflow-backed `/code-review` (cross-file finders + adversarial verify) on the staged diff BEFORE the commit-gate specialists — it catches caller/integration bugs the file-scoped specialists don't; (3) after fixing, re-run `/code-review` on the fixes (they carry their own bugs); (4) only then dispatch the specialist gates for markers. The layered review (workflow `/code-review` ⊃ single specialist) is what caught these — the specialist gate is the floor, not the ceiling (cf. the 2026-07-03 data-CF lesson).
- **Example:** BUT-1503's sharing return type changed bool→enum; the sharing-service's own tests were green, but `acceptRecipeShareRequest` and the notification coordinator (different files) still treated the new "partial" outcome as total failure → stuck-pending request + no recipient notification. Only the cross-file `/code-review` pass surfaced it. Shipped as `fc5f941e5` after two review rounds.

### [Workflow] A gate's block message may only name remedies that ship WITH the gate
- **Date**: 2026-07-05
- **Trigger**: A synat session hit the shared plan-review gate's high-stakes block, which instructed "run /review-plan" — a command that exists only as a Butlery-local file. The session got "Unknown skill: review-plan" and had to improvise the auditor by hand. The gate had been ported to all three repos; its remedy hadn't.
- **Rule**: When a gate/hook blocks with instructions, every command, skill, script, or file it names must be guaranteed co-installed with the gate itself — ship the remedy inside the same plugin (auto-discovered skill), or make the message self-contained (inline the procedure), or have the hook check existence and adapt its message. "Works in the repo where it was written" is the porting bug's signature; test block messages from the OTHER repos' perspective when a gate is shared.
- **Example**: Fixed by adding skills/review-plan/SKILL.md to workflow-guards (a repo-agnostic fresh-context auditor, auto-present wherever the gate is) and updating the block text to name the fallback; Butlery's richer local command still wins when present (9282f77).

### [Workflow] An audit agent's claim about a tool's OUTPUT FORMAT is plausible, not confirmed — reproduce before "fixing"
- **Date**: 2026-07-05
- **Trigger**: A verification-audit agent reported (MEDIUM, hedged) that Butlery's stop-check `errorPathRegex` "likely never matches" because `dart analyze` uses a bullet-separated format with the file path third. I rewrote the regex to the bullet format. The plan's own verification step — inducing a REAL lint error — then showed the actual output is hyphen-separated (`error - file:line:col - message - rule`), the ORIGINAL regex matched perfectly, and my "fix" was the regression. Reverted.
- **Rule**: Findings that assert what a tool PRINTS (CLI output shapes, log formats, error layouts) are training-data guesses until reproduced — even when the auditor names a version. Before changing any parser/regex on such a finding: run the real tool, capture a real line, test old AND new pattern against it. The audit agent itself flagged it couldn't reproduce under read-only constraints — that hedge means "verify me first," not "fix me first." Extends the digest line "when citing a deterministic tool's verdict, RUN it" to third-party-tool output formats surfaced by subagents.
- **Example**: `dart analyze` probe file with `undefinedFunction()` → real line `  error - probe.dart:2:3 - ... - undefined_function`; original regex captured `probe.dart`, my bullet rewrite captured nothing. A fixture pinning the REAL format now guards it.

### [Workflow] Feedback after a deliverable may target the TOOL that made it, not the one artifact
- **Date**: 2026-07-04
- **Trigger**: After I delivered a one-off `/brag` launch video for Butlery, Malin said the visuals had empty placeholder spots that "should have been fixed," and that she wanted "the skill" to analyze the whole project longer, allow longer videos when needed, and use Q&A when unsure. I read this as "redo THIS movie" and started a deep re-analysis + rebuild of the single Butlery clip (even asked 4 scoped questions about it). Malin: "My input was intended to improve the whole skill not this particular movie."
- **Rule**: When feedback arrives right after a deliverable, first disambiguate its SCOPE: is it "fix this specific output" or "improve the general capability / skill / process that produced it"? Behavioural or quality feedback phrased in general terms ("it should…", "the skill should…", "way longer", "wherever it is unsure") usually means the tool, not the single artifact — improving the artifact by hand leaves the next run just as broken. If the target is ambiguous, ask which one before doing the work; don't default to the narrow re-do just because the artifact is the thing in front of you.
- **Example**: Correct read here: "spend way longer analyzing, allow longer videos, use Q&A when unsure, stop shipping emoji placeholders" = edit the `/brag` skill's SKILL.md + step-1/step-2 references so EVERY future run (any project) behaves that way — not a rebuild of the Butlery mp4.

### [Workflow] Never assert a router/gate verdict you didn't run
- **Date:** 2026-07-04
- **Trigger:** The shared-plugin plan claimed "stakeholder router tier = skip" as a judgment call; the fresh-context plan auditor actually RAN `tools/stakeholder_router.py` and got `single` — a mandatory blind critique had been skipped. The critique then produced 6 binding conditions that materially improved the design (fail-closed gates, shakedown file retention).
- **Rule:** When a plan or summary cites a deterministic tool's verdict (router tier, gate result, test outcome), RUN the tool and paste its output — never infer what it "would" say. Deterministic checks are cheap; asserted verdicts are how gates die.
- **Example:** `python tools/stakeholder_router.py --json <paths>` → paste `{"tier": ...}` into the plan, instead of writing "tier = skip (pure tooling)".

### [Workflow] Port configs against the target repo's ACTUAL layout, not the reference repo's defaults
- **Date:** 2026-07-04
- **Trigger:** The shared-plugin migration wrote webbkollen's `.claude/shared-plugin.json` with Butlery-shaped dossier paths (`docs/org/role-paths.json`, `docs/org/dossier-staleness/`) without reading webbkollen's retired hook, which actually used `docs/org/world-watch/role-paths.json` + `.claude/state/dossier-stale/`. Its staleness tracking died silently for 4 hours; webbkollen's own org-retro caught it. binge's scheme turned out structurally incompatible (numbered append-log markers) — config could never have bridged it.
- **Rule:** When migrating/porting per-repo machinery, read the RETIRED implementation in each target repo first and mirror its real paths and semantics in config; where semantics differ structurally, keep the native implementation and opt out of the shared one — don't force one repo's shape onto another.
- **Example:** `dossier-freshness.mjs` line 48 said `docs/org/world-watch/role-paths.json`; the config I wrote said `docs/org/role-paths.json`. One grep of the retired hook would have caught it.

### [Workflow] An agreed multi-part initiative gets ONE written plan before any slice ships — don't implement the piece under discussion and let the rest evaporate
- **Date**: 2026-07-03
- **Trigger**: The setup-improvement conversation produced an accepted set of ~10 mechanically-triggered improvements. When Malin pushed on one slice (mandatory interview + plan threshold), I implemented that slice immediately — hooks, rules, tests, commit — with no written plan covering the whole initiative. Malin: "but now you are implementing only part of the plan?" The other 8 items existed only in chat scrollback, exactly where accepted work goes to die. Also self-inconsistent: the change itself was multi-file and shipped ad hoc while I was busy making ad-hoc multi-file changes impossible.
- **Rule**: The moment a discussion converges on MORE than one accepted work item, stop implementing and write the full plan to tasks/ first — every accepted item, its mechanical trigger, its order — get approval, then execute slices from the plan. The slice currently being discussed is not more real than the ones discussed ten minutes ago; chat scrollback is not a backlog. This is the conversational form of rule #5 (plans = execute + verify) and pairs with the mechanical-trigger lesson above: the plan file IS the mechanism that keeps the un-discussed slices alive.
- **Example**: Correct flow here: after the mechanical-trigger re-anchoring was accepted, write tasks/setup-hardening-plan.md listing all items (gates, deviation log, blindspot critic, preview gate, janitor, heartbeat health, distillation, handover memo, retro metrics, sibling ports), ask the blast-radius questions, get approval — THEN build item 1.

### [Workflow] Every proposed improvement must name its mechanical trigger — upgrading an optional command is decoration
- **Date**: 2026-07-03
- **Trigger**: The setup audit itself established "a routine is only as alive as its most mechanical trigger" — then in the very next analysis I proposed adopting the HTML-artifact patterns by "upgrading /preview" and "adding a plan convention," i.e. improvements parked inside manually-invoked commands. Malin: "you are still wanting to upgrade some commands which still needs to be called manually... we have already established that mechanically calling for things leaves them stale and forgotten."
- **Rule**: A proposal isn't complete until it answers "what physically fires this?" Distinguish two things: (a) the *content* of a skill/command is durable once written (it runs whenever the skill runs — no rot); (b) the *invocation* is where staleness lives. So every improvement must be attached to an already-firing path or given a new mechanical trigger: wire it into a skill that a loop/schedule already invokes (sprint-execute), enforce it at a hook that already fires (plan-review-gate on ExitPlanMode, commit-gate markers), gate it in CI, or put it on the janitor/schedule. An improvement whose firing path is "the model or Malin remembers to call X" gets proposed as such honestly — convenience, not infrastructure.
- **Example**: Deviation-log → inside sprint-execute (fires every sprint via /loop). Tweakable-plan format → enforced by the plan-review-gate hook that already blocks every ExitPlanMode. Design-directions preview → a preview-done marker required by a PreToolUse gate when a new view file is created (same pattern as review markers), NOT "upgrade /preview and hope it gets called."

### [Workflow] Don't recommend pruning a young system for "no evidence of use" — the observation window must exceed the system's natural cycle
- **Date**: 2026-07-03
- **Trigger**: In the setup audit I recommended running /org-retro and pruning the 33-role virtual org down to "the roles the evidence supports." Malin pushed back: the expert org has only been live a few days — many roles (monthly world-watch cadences, rare legal/compliance events) simply haven't had a chance to fire yet. "Never fired" after days is expected, not a verdict.
- **Rule**: Before recommending removal/pruning based on absence of activity, compare the observation window to the thing's **natural firing cadence**. If the window is shorter than the cycle (a monthly scan observed for a week, a rare-event role observed for days), absence of evidence is NOT evidence of absence — recommend *tuning* now and schedule the *pruning decision* for after ≥2–3 full cycles. The org-retro skill already encodes this distinction (shakedown mode ~days = qualitative tuning; full mode ~weeks = quantitative keep/cut) — match the mode to the window. Same logic as the existing "scan the WHOLE backlog before pacing down" lesson: don't draw survival conclusions from an undersized sample.
- **Example**: Correct recommendation: run /org-retro in shakedown mode now (tune routing, dossier freshness, panel quality), clear the dossier backlog for ALL 33 roles, and put a dated re-review (~4–6 weeks out, after the monthly roles have fired 1–2×) on the calendar for any keep/cut call.

### [Firebase] Firestore sum()/average() with a filter on a DIFFERENT field needs a COMPOSITE index (aggregated field included)
- **Date**: 2026-07-03
- **Trigger**: In pooled-ratings Stage B I wrote `collectionGroup("canonical_rating_events").where("poolKey","==",k).aggregate({count, average("ratingValue")})` and declared only a single-field COLLECTION_GROUP index on `poolKey`. Unit tests passed (9/9) because the in-memory Firestore fake computes averages straight from a Map — it models data, not the index layer. An adversarial review caught that in real Firestore this throws `FAILED_PRECONDITION` on every drain, so the public "Butlery-betyget" number would never be written. The commit-gate cloud-functions-specialist had explicitly (and wrongly) said "the averaged field doesn't need indexing" — two reviewers disagreed, so I verified against Firebase docs + the billing model before deciding.
- **Rule**: Firestore aggregations are computed from **index entries only** and never read the documents (that's why they bill per index-entries-read). So `count()` needs just the filter field indexed, but `sum(F)`/`average(F)` need **F materialized in the same scanned index** as the filter — i.e. a COMPOSITE index with the equality-filter field(s) FIRST then the aggregated field: `(poolKey ASC, ratingValue ASC)`. A single-field index on the filter field serves count() and silently makes sum()/average() throw. This is NOT covered by the accepted-deviation "pure-equality queries need no composite index" — that rule is about equality *reads*, not aggregations over a second field. When two review agents disagree on a Firestore/infra fact, verify against docs/first-principles — don't average their opinions. Guard the class of bug with a test that asserts the **declared index config** matches the aggregate's needs (the data-fake can't), and confirm at deploy (the emulator/console enforces aggregate indexes; a unit fake never will).
- **Example**: Fix was replacing the single-field `poolKey` fieldOverride with a composite `{collectionGroup: canonical_rating_events, queryScope: COLLECTION_GROUP, fields:[poolKey, ratingValue]}` in `firestore.indexes.json`, plus a `requiredCompositeIndexDeclared` test that reads the index file and asserts the composite exists with poolKey before ratingValue.

### [Workflow] On data-writing Cloud Functions, run the xhigh multi-agent review BEFORE commit — the single-specialist gate is necessary but not sufficient
- **Date**: 2026-07-03
- **Trigger**: The pooled-ratings Increment-2 mirror CF passed the `cloud-functions-specialist` gate ("clean of Critical/High"). The specialist even wrote a knowledge entry *endorsing* the design. A follow-up `/code-review xhigh` (6 finders + 13 independent verifiers) then found **12 verified issues**, headlined by a **showstopper the specialist had explicitly cleared**: the CF read recipes from a top-level `recipes/{id}` collection that does not exist (recipes are user-scoped at `users/{uid}/recipes/{id}`), so the feature would have written zero pool events — dead on arrival. Caught pre-commit; nothing shipped.
- **Rule**: For a Cloud Function that WRITES user data (pool events, aggregates, cascades), the commit-gate specialist review is the floor, not the ceiling. Before committing, also run the workflow-backed `/code-review` at `high`/`xhigh` (functions/src/ is on the xhigh list in CLAUDE.md). Two independent failure modes this catches that a single reviewer missed here: (a) a **data-model assumption stated confidently but never checked against `firestore.rules` + the repository mixin** — the authoritative sources for a collection's real path/scoping (an incidental `collection(name)` call elsewhere, e.g. legacy admin code, is NOT proof the collection exists); (b) **tests that seed the same wrong shape the code assumes** — a fake that mirrors the code's mistake instead of the real Firestore layout makes the bug structurally invisible (all 12 tests were green over a DOA feature). Also verify v2 event-trigger retry semantics explicitly: `throw` does nothing unless the trigger is registered with `{ retry: true }`.
- **Example**: mirror CF read `db.collection("recipes").doc(recipeId)`; correct path is `db.collection("users").doc(userId).collection("recipes").doc(recipeId)`. `firestore.rules` line ~337 has only the nested `match`, and `recipe_ratings` docs carry no owner uid — both discoverable in one read each, but only checked *after* the xhigh review flagged it. Recorded in `cloud-functions-specialist.knowledge.md` (2026-07-03 correction) and `tasks/todo.md` (Increment-2 rework block).

### [Workflow] Verify subagent claims about ROUTING before relaying them as fact
- **Date:** 2026-07-02 (ingredient-sections analysis)
- **Trigger:** In the OCR follow-up I told Malin "photo imports don't do traditional OCR-then-parse. The image goes directly to Gemini Vision" — stated as fact, derived from a subagent's pipeline map that merely listed `ocr-recipe-image.ts` as "the photo/OCR path". The actual client flow (photo_import_strategy.dart) runs traditional OCR providers first (OCR.space → Google Vision → Tesseract) and only falls back to the Gemini Vision function as Tier 4 when OCR or text-parsing fails. Malin caught it: "We should not send all photos to llms?!"
- **Rule:** A subagent naming a file as "the X path" tells you the file EXISTS on that path, not that it's the primary/only route. Before asserting how traffic is routed (what runs first, what's a fallback, what % hits an external service), read the client-side strategy/orchestrator yourself and check for tier/fallback structure. Cost- and privacy-sensitive claims ("every photo goes to an LLM") get direct verification, always.
- **Example:** photo_import_strategy.dart:167-233 shows `_ocrService.extractText` first and `_tryLlmFallback` only on OCR failure/empty text/parse failure — the exact opposite routing of what I claimed.

### [UI/UX] Heuristic-derived visible content must ship WITH its correction UI — editing is not a "v2"
- **Date:** 2026-07-02 (ingredient-sections analysis)
- **Trigger:** I recommended phasing ingredient section headers as v1 = capture at import + read-only display, v2 = manual editing "until user signal asks for it". Malin: "if we are to implement this it needs to be both v1 and 2 (how else would a user edit the header...)". The v1-only cut would show users AI/heuristic-detected headings they could neither fix nor remove when wrong — worse than not showing them.
- **Rule:** When a feature surfaces content derived by heuristics or an LLM (detected headings, parsed amounts, tags), the user's ability to correct/delete that content is part of the MVP, not a follow-up. Read-only derived data that can be wrong erodes trust and contradicts the app's own correction-flywheel philosophy. Phase by import-path coverage or by surface if needed — never by "display now, correct later".
- **Example:** Revised scope: ingredient sections ship as one feature = import capture + display + editable heading rows in the recipe form.

### [Workflow] Staging doesn't survive parallel sessions — pathspec-commit, and re-verify the index after any gate block
- **Date:** 2026-07-02
- **Trigger:** Staged 5 webbkollen files, got blocked by a commit gate, retried 40 min later with bare `git commit` assuming my staging was intact. A parallel session's index operations had swapped the staged set: my commit (bc51178) shipped THEIR 9 scoring files under MY message, while my files were silently unstaged. Existing lesson (feedback_parallel_session_git_add_sweep) covered "stage+commit in one call" but not the retry-after-block case.
- **Rule:** The git index is shared mutable state across sessions. (1) Never bare-`git commit` when a parallel session may be active — always `git commit -- <explicit paths>` (add untracked files in the same Bash call). (2) After ANY gate block or delay between add and commit, re-run `git diff --cached --name-only` and compare against what you intend to ship BEFORE retrying. (3) A wrong-message commit that's already pushed does NOT get amended/force-pushed while a parallel session is active — correct the record in the next commit's message instead.
- **Example:** webbkollen bc51178 (their work, my message) → corrected in 0228aaa's message; binge commit done right: add + pathspec-commit in one call left the parallel session's 8 staged files untouched.

### [Workflow] "Map the workflows" means full coverage against a stated universe — never silently curate a sample
- **Date:** 2026-07-02
- **Trigger:** Built workflow maps with 5-7 hand-picked flows per repo and presented them as "the workflow map". Malin: "these are not even remotely close to being full coverage." Butlery's own FEATURE_INVENTORY.md counts 137 features; the map covered 6 flows.
- **Rule:** When documenting coverage-shaped artifacts (maps, inventories, test suites), (1) name the coverage universe explicitly (feature inventory, functions catalog, route list), (2) state the fraction covered in the artifact itself, (3) either deliver the full universe or present the subset AS a subset with the gap enumerated. A curated sample presented without a denominator reads as completeness and misleads.
- **Example:** workflow-map.html should declare "covers X of 137 inventory features" and the linter should enforce the mapping (every inventory ID appears in >=1 flow), so coverage is a checked number, not a vibe.

### [Workflow] When the user asks for a new mode, deliver one mode — don't bolt it on as "normal + extra" or offer spare variants
- **Date:** 2026-06-30 (`/sprint-execute malin` design)
- **Trigger:** Malin asked for a `/sprint-execute malin` mode that builds and then gathers everything she must approve-or-do. I implemented it correctly but framed it repeatedly as "the normal sprint runs unchanged; malin only ADDS a pass," over-emphasized "build NOTHING," and closed by offering a second build-nothing `malin-only` variant. She pushed back: "malin bara är det nya men att den ska bygga och sedan samla ihop allt jag behöver godkänna eller göra i grupp" — she wants ONE mode that builds, then collects approvals/to-dos as one group.
- **Rule:** When the user names a new mode, treat it as a single coherent thing from her point of view, not "existing behaviour + a tacked-on phase." Lead with what the mode DOES end-to-end (here: build the full sprint, then bring me my pile, grouped), not with reassurance about what stays the same. Don't offer extra opt-in variants she didn't ask for — it reads as not having a clear model of what she wants. "Build nothing" is an internal safety detail, not the headline.
- **Example:** Reframed Phase 3.6 intro to "malin is one mode … runs the full sprint first, then collects everything needing Malin into one group"; changed the live-ask step to present a single grouped summary split into "Godkänna" / "Göra" before asking; dropped the offered malin-only variant.

### [Testing] A new source file can land as a git binary blob — verify `file` says "text" before committing
- **Date:** 2026-06-28 (BUT-1149 coverage burndown)
- **Trigger:** A new unit test (`json_cache_helper_test.dart`) used NUL bytes as map-key separators in an in-memory fake's `_k()` helper. `flutter test` and `dart analyze` both passed (a NUL is valid inside a Dart string literal), but `git commit` recorded the file as `Bin 0 -> 9020 bytes` — git's binary heuristic trips on any NUL byte, so the file would show no diffs on every future change. Only noticed because the commit diffstat said "0 insertions" for a 270-line new file.
- **Rule:** Never use NUL/control-char separators in source (use `|`, `::`, etc.). After creating a NEW source file whose commit diffstat shows `Bin`/"0 insertions", run `file <path>` (expect "… text") or count NUL bytes with `tr -cd` piped to `wc -c` (expect 0) and fix before it ossifies. Green tests do NOT prove the file is text.
- **Example:** the separator went from a NUL to `|`; `tr` cleaned the 4 NULs, and `file` then reported "C source, Unicode text, UTF-8 text". Fixed in da4a8c9ac (follow-up to e5fcf6ac3, no --amend).

### [Testing] Lexicon-dependent tests: assert the premise, and watch NFC vs NFD on å/ä/ö
- **Date:** 2026-06-28 (BUT-1149, SwedishDefiniteNormalizer)
- **Trigger:** Writing tests for SwedishDefiniteNormalizer (which no-ops on words already in KnownIngredients), I assumed "löken" was an unknown definite form — but "löken" is itself a lexicon entry, so tryNormalize correctly returned null and 5 tests "failed". Compounded by my source emitting "ö" inconsistently (some NFC U+00F6, some NFD o+U+0308), so byte-identical-looking literals didn't all match the NFC lexicon.
- **Rule:** When a unit under test branches on membership in a constant set (KnownIngredients, allow-lists, enums-from-strings), assert the PREMISE explicitly in-test (`expect(isKnown(base), isTrue)` AND `expect(isKnown(derivedForm), isFalse)`) so a wrong example fails loud at the premise, not mysteriously at the behavior. Build derived strings by appending to the base literal (`'${base}en'`) so accented bytes always match the base. If accented literals misbehave, NFC-normalize the test file (`python -c "import unicodedata,io; ... unicodedata.normalize('NFC', s)"`) — the repo's lexicons are NFC.
- **Example:** Swapped base "lök" (both "lök" and "löken" are lexicon entries) → "citron" (base known, "citronen" absent); added the two-sided premise asserts; NFC-normalized the file. 13/13 green (97ac23595).

### [Testing] real-time-guard matches the literal DateTime.now() even inside comments
- **Date:** 2026-06-28 (BUT-1149, recurred 2x this session)
- **Trigger:** A test comment "// Fixed reference dates (no DateTime.now() ...)" tripped the pre-commit real-time-guard, which greps raw test text for the literal `DateTime.now()` — comments included. Cost a full ~200s hook cycle to discover. Same trap hit MenuQualityAnalyzer's comment earlier this session.
- **Rule:** Never write the literal token `DateTime.now()` anywhere in a `test/unit/**/*_test.dart` file — not in code, not in comments, not in a string. To reference the concept in prose, say "real-clock reads" / "the wall clock" instead. If you must show it, break the token. Quick self-check before committing a new test: `grep -c 'DateTime.now()' <file>` must be 0.
- **Example:** "no DateTime.now() —" → "no real-clock reads —" unblocked the commit (9e74b6e4d). Also re-learned: touch the review markers in a SEPARATE Bash call before `git commit` (the PreToolUse hook checks marker mtime before the inline touch runs).

### [Testing] After changing a class's constructor, run its EXISTING test suites — not just the new test you wrote
- **Date:** 2026-06-28 (BUT-1417 follow-up)
- **Trigger:** BUT-1417 added constructor deps (authRepository on Friends/Chat/AddMembers viewmodels, userService on AddMembers) that fall back to the production ServiceLocator. I verified BUT-1417 only against its NEW test (account_maturity_cta_test.dart) and marked it Done. A later full-suite coverage run revealed ~95 failures across the three EXISTING viewmodel suites: ctor crashes ("ServiceLocator not initialized") because those tests construct with explicit mocks and never initialize the production locator, plus behavioral failures in chat (the new maturity gate blocked message-send for the un-matured test user).
- **Rule:** When a change adds/changes a constructor param or a ServiceLocator/DI fallback on class X, immediately run EVERY existing `*_test.dart` that constructs X — `grep -rl "X(" test/` — before claiming done. A green new test proves the feature; it does NOT prove you didn't break the class's existing suites. Especially true for params that fall back to `ServiceLocator.get<...>()`: tests that inject explicit deps will hit the uninitialized production locator the moment a new fallback is added.
- **Example:** Fixed in 9b9c2fdd1 — injected FakeAuthRepository + FakeMaturedAccountHelper (new always-matured fake in production_mocks) + MockUserService at every construction site. friends 48/48, add_members 41/41, chat 43/43.

### [Workflow] To break down / plan an epic, QUERY ITS CHILDREN FIRST — never plan from the epic's description
- **Date**: 2026-06-26
- **Trigger**: Asked to "plan BUT-1332" (break a feature-inventory epic into shippable child tickets), I read the epic *body* — which still narrated all the work as pending — and wrote a plan to create 15 children. The fresh-context plan auditor checked **live Linear** and found BUT-1332 **already had 15 children (BUT-1333–1347), all `Done`** (shipped 2026-06-21→23). My plan would have created 15 exact duplicates of completed work. The audit (cold-eyes, queried state instead of trusting text) is the only reason no duplicates were filed.
- **Rule**: An epic's description is a **planning snapshot that goes stale the moment its children ship** — it is never authoritative for "what's left." Before planning, decomposing, or "filing the children" of ANY epic/umbrella ticket, the FIRST action is `list_issues parentId=<epic>` and read the children's **statuses**. If children exist, the breakdown is already done — the only residual work is reconciling the stale epic shell (close it / annotate it), not re-deriving children. This is the epic-specific form of the existing Step-0 premise rule (line ~71) and the backlog-classification rule (line ~20): both say *check live state, never the ticket prose* — this case is sharper because the misleading prose is the epic's own body. Reinforces `memory/project_backlog_triage_2026-06-15.md` ("plan from the actual backlog, never from an epic's child-list description").
- **Example**: BUT-1332's body listed the gaps as a to-do; querying its children showed BUT-1333–1347 all Done. Correct move was to close the epic with a "✅ all children shipped; do not re-derive from the list below" note — zero tickets created.

### [Workflow] Dedup is against CURRENT CODE, not closed-ticket titles — closed-ticket memory only covers "decided-no", not "fixed"
- **Date**: 2026-06-25
- **Trigger**: After a `/linear scan`, I justified the dedup tracker keeping ~357 closed tickets as "so the scan won't re-file things you already built." Malin pushed back: *"why would it flag the same thing? if the code was fixed then its not an issue.. if its not an issue it should be refiled?"* She was right — I'd blurred two distinct cases and overstated the tracker's role.
- **Rule**: A genuinely **fixed** issue vanishes from the current code on its own, so a fresh scan can't re-find it — no closed-ticket memory needed for those. The dedup-against-closed-tickets memory only earns its place for **Canceled / won't-fix / accepted-deviation** items: the code pattern is still present (so a naive scan WILL flag it), but the *decision* to leave it was already made. So: (1) the authoritative dedup is verifying each candidate against the **live code** + checking it isn't a decided-no, NOT matching ticket titles; (2) if the current code genuinely has the issue and it isn't a recorded decision, FILE it even if a same-named ticket was closed — could be a regression; (3) never explain "net-new is scarce" as "because the dedup history is big" — the real cause is **code maturity** (few real issues left). Tracker = cheap first-pass filter + record of decisions, not source of truth.
- **Example**: BUT-656/653/668/672/661 are *Canceled* (dead paid-tier premise), and their code patterns (e.g. the single hardcoded OCR cap) still sit in the code — a scan re-flags them every time; the tracker's job is remembering we said no, not that they were fixed.

### [Workflow] "This iOS-native pin is now stale" needs the iOS Build Validation gate to prove — a changelog read is not enough
- **Date:** 2026-06-24 (BUT-1367)
- **Trigger:** A post-Dart-3.10 dependency-analysis workflow (sonnet subagents) claimed the `connectivity_plus 7.0.0` and `device_info_plus 12.3.0` iOS pins were "over-cautious / likely stale" based on reading the upstream changelogs (no mention of the offending API). I lifted `connectivity_plus` → 7.1.1 on a branch; Dart-side analyze + all 66 connectivity tests passed. But the iOS Build Validation lane (PR #188) went RED: `connectivity_plus-7.1.1/.../PathMonitorConnectivityProvider.swift:28` STILL calls `NWPath.isUltraConstrained` (the iOS-26 fake-SDK API). The pin was correct all along; the changelog read missed it (the call wasn't a documented change). Reverted; closed PR.
- **Rule:** For pins justified by an iOS-native build break, a subagent's "changelog shows no sign of it → pin is stale" is a HYPOTHESIS, not a verdict — only the `Build Validation` iOS lane (`build (ios)`, runs on PR→main, can't run on this Windows machine) is authoritative. Validate such lifts on a branch+PR and read the iOS lane before believing the pin can go. Sibling pins from the same vendor sharing the same speculative-iOS-26-API pattern (here device_info_plus's `isiOSAppOnVision`) are very likely still broken too — don't burn a second iOS-gate cycle re-testing them without new upstream evidence. Record the confirmed re-test date in the pin comment so it isn't re-litigated.
- **Example:** BUT-1367 — connectivity_plus 7.1.1 iOS-red on `isUltraConstrained`; pin kept at 7.0.0 with a dated "RE-TESTED 2026-06-24" note; device_info_plus left pinned by inference (same pattern + it also cascades win32 6 / package_info_plus 10). The Firebase part of the same ticket was also a no-op: `firebase_app_check 0.4.3` (security pin) transitively holds the whole `firebase_*` suite at 6.x, so `pub upgrade` moves nothing.

### [Workflow] docs/analysis/runs/ deleted by explicit user decision — citations inlined, harness kept
- **Date:** 2026-06-19
- **Trigger:** The 2026-05-31 lesson above recorded *keeping* `docs/analysis/` because ADR-002, `data-residency.md`, and a viewmodel comment cite its MASTER-wave files as decision provenance. In a dedicated cleanup session the user was shown that conflict (plus the CI guards that allow-list the tree as a "frozen forensic-audit corpus") and explicitly chose to **delete `docs/analysis/runs/` entirely** anyway, keeping only the re-runnable `prompts/` harness + `CODEX_RUN_GUIDE.md`.
- **Rule:** A documented "keep" lesson is not a veto over a later explicit user decision — but it IS a checklist of what breaks. When overriding it, first re-locate every live citation (`grep` MASTER-wave / runs paths across the WHOLE tree) and make each citing doc **self-contained** (preserve the finding ID + substance, drop the dead-file pointer) in the same change, so the deletion doesn't orphan provenance. The CI guards (`check_no_mistral_refs.sh`, `check_no_inline_adoption_pct.sh`) use `[[ -d ]]` and survive `runs/` removal since `prompts/` remains.
- **Example:** Removed `runs/` (~60 files); rewrote ADR-002 (CRIT-DEP1), `data-residency.md` (CRIT-INFRA1) and `docs/ops/backups.md` (which also had stale "unresolved" text — BUT-819 already accepted the west1-compute/west3-data split) to cite the findings without the deleted paths. The lib citation named in the old lesson no longer existed. Also kept `scripts/test_real_time_baseline.txt` — it looked like loop scratch but is the live allow-list for `scripts/check_test_real_time.sh`.

### [Workflow] Run arch gates locally before committing UI widgets
- **Date:** 2026-06-13 (iter-142)
- **Trigger:** CI "Architecture & Code Quality Validation" + "Build Validation" went red on a new widget (`parse_confidence_review.dart`) that code-reviewer, testing-specialist, AND the pre-commit `/code-review` had all passed clean. Two gates fired: the AppColors keep-set grep (used `AppColors.warning`, outside the BUT-572 legitimate-keep set) and `architecture_test.dart` (used `EdgeInsets.only(left:)`, RTL-unsafe).
- **Rule:** Before committing any new/changed `lib/views/` or `lib/widgets/` `.dart`, run BOTH gates locally — they are grep/test-based CI checks the agent reviewers don't execute: (1) `flutter test test/architecture/architecture_test.dart`, and (2) the AppColors grep from `.github/workflows/architecture-validation.yml` (`grep -rn "AppColors\." lib/views lib/widgets --include=*.dart | grep -vE "AppColors\.(brand|illustration|overlay|neutral|transparent|rustLight|creamDarker|greenMuted)"`). Use `context.butleryColors.<slot>` for status colors and `EdgeInsetsDirectional.only(start:/end:)` instead of `EdgeInsets.only(left:/right:)`.
- **Example:** `parse_confidence_review.dart` — `AppColors.warning` → `context.butleryColors.warning`; `EdgeInsets.only(left:)` → `EdgeInsetsDirectional.only(start:)`. Also un-blocked a pre-existing same-class violation in `menu_placement_view.dart` (BUT-1241) that had left `architecture_test` red on main.

### [Workflow] Touch review markers in a SEPARATE Bash call before `git commit` — never in the same call
- **Date:** 2026-06-13 (iter-144)
- **Trigger:** Combining `touch .claude/state/*.marker` and `git commit` in one Bash call kept failing the require-review/require-simplify gate as "STALE", even though the touch was right before the commit. Root cause: the PreToolUse hook rejects the ENTIRE Bash tool call before any of it executes — so when the commit is blocked, the preceding `touch` never runs, and the markers stay stale. (Wasted 2 commit attempts across iter-142 and iter-144.)
- **Rule:** Always `touch` all required markers in their OWN Bash call (no `git commit` in it → hook passes → touch actually runs), verify `marker_mtime > newest_staged_file_mtime`, THEN run `git commit` in the next call. Do NOT rely on a touch that shares a call with the blocked commit. (Also: second-granularity mtime means a touch in the same second as a just-formatted file can tie — the separate-call latency also fixes that.)
- **Example:** iter-144 — `touch ...5 markers...` standalone (marker→1781357786) then `git commit` separately succeeded; the prior same-call attempt left firebase-security-done.marker at its old 1781354343 because the rejected commit aborted the whole call.

### [Workflow] Verify slow CI jobs (Build Validation + Run Tests) via gh — the 15-min watcher expires before they finish
- **Date:** 2026-06-13 (iter-141→147 session)
- **Trigger:** `ci-watcher.sh` (15-min monitor) times out before "Build Validation" (release-AAB build) and "Run Tests"/"Integration Tests" (~12-min compile floor + emulator, total ~30–50 min) complete. Across 6 sprints I reported "CI green" off only the fast gates (Architecture/E2E/Firestore-Rules/SBOM/Dependency-Audit) and never confirmed the slow two. A `gh run list` sweep later showed iter-144 (`7a3a5ab`) "Run Tests" = **failure** — which I'd reported green. (It turned out to be an infra flake: `subosito/flutter-action` `hashFiles('**/pubspec.lock') failed`, not a code/test failure; the next commit's run was green. But I didn't KNOW that at report time.)
- **Rule:** Don't claim full CI-green off the fast jobs alone. After the watcher times out, confirm the slow jobs explicitly: `gh run list --limit 8 --json headSha,status,conclusion,name --jq '.[]|select(.name=="Build Validation" or .name=="Run Tests")|"\(.headSha[0:7]) \(.status)/\(.conclusion)"'`. If a slow job shows `failure`, pull `gh run view <id> --log-failed` and classify infra-flake (flutter-action hashFiles, emulator-didn't-come-up, cancelled-by-supersede) vs real test failure BEFORE reporting. Re-check on the next loop wake rather than trusting the timed-out watcher.
- **Example:** iter-144 Run Tests failure was `hashFiles('**/pubspec.lock')` in flutter-action setup (transient runner FS) — infra, not code; iter-145 (superset) passed, so main stayed green.

### [Testing] cloud_firestore FieldValue cachear plattformsfactoryn statiskt — fake-batchar kan kasta subtype-fel
- **Date:** 2026-06-11
- **Trigger:** BUT-838: `FieldValue` cachear `FieldValueFactoryPlatform.instance` i en `static final` vid första användning. Om `BaseUnitTest.setupUnit()` skapar en FieldValue INNAN fake_cloud_firestore installerat sin mock-factory kastar varje senare `FieldValue.increment` genom en fake-batch `MethodChannelFieldValue is not a subtype of MockFieldValuePlatform`.
- **Rule:** Tester som driver `FieldValue` genom fake_cloud_firestore-batchar får inte dela bootstrap med tester som rört FieldValue före fake-installationen — kör dem i egen fil utan den delade setupen (dokumentera i filhuvudet).
- **Example:** test/integration/firebase/repositories/firebase_cook_event_repository_integration_test.dart hoppar avsiktligt över den delade bootstrappen.

### [Testing] Adding a named param to a mocked service silently un-matches every old mocktail stub
- **Date:** 2026-06-10
- **Trigger:** BUT-906 added `shareActivityToFeed` to `UserService.createOrUpdateProfile`; `user_profile_viewmodel_test.dart` stubs (written without that arg) stopped matching, the missing-stub throw was swallowed by `safeExecute`, and `saveProfile()` returned false — red nightly + red push CI two days later, far from the causing commit.
- **Rule:** When adding a named parameter to a service method that tests mock, grep `test/` for the METHOD NAME and add `paramName: any(named: 'paramName')` to every stub/verify site in the same commit. Mocktail fails to match silently — no compile error, and error-swallowing wrappers convert it to a wrong return value.
- **Example:** Fixed in iter-137 by the debugger agent: 6 stub sites in test/unit/viewmodels/user_profile_viewmodel_test.dart.

### [Workflow] Don't offload judgment/labor to the user when they have no context you can't find yourself
- **Date**: 2026-06-09 (mined from session transcripts, adversarially verified)
- **Trigger**: 2 distinct sessions — Claude handed self-resolvable decisions and tedious-but-mechanical work back to the user despite having authored every artifact involved. User pushback: *"allt är gjort av dig — jag har inget extra minne eller koll än vad du kan hitta"* and *"är det inte enklast om du rättar facit?"*
- **Rule**: Before deferring anything to the user, ask **"Does the user hold privileged context I cannot obtain by investigating?"** If NO — I authored the artifact, the answer is derivable from code/files/history, or it's tedious-but-mechanical labor — then I OWN it: investigate and decide (or just do the work), then report the decision + reasoning. Only defer when the user genuinely holds context I can't reach: (a) a product/preference/intent call, (b) an irreversible/destructive action needing sign-off, or (c) an external real-world fact. The deciding test is WHO HOLDS THE CONTEXT, not whether asking feels safer. Sharpens the existing "don't ask for hand-holding" / "stop-and-ask only on product-intent ambiguity" rules.
- **Example**: On the cookbook gold-corpus side-project, Claude said "din boll" on correcting the gold file and offered radera/behåll choices on parser output it had itself generated — work the user could not do better, since Claude authored every artifact involved.

### [Workflow] Don't extrapolate "backlog drained / loop should stop" from a small sample — scan the WHOLE backlog first
- **Date**: 2026-06-04 (iter-121)
- **Trigger**: In a `/loop /sprint-execute` run I evaluated **6** candidate tickets, found them all heavy/deploy-blocked/product-uncertain, and concluded "the actionable-clean backlog is drained — the loop needs Malin's input." I wrote a pace-down todo + drafted a PushNotification saying so. Malin interrupted: *"is this true for all 135 backlog tickets?"* — I had NOT checked the other ~129. A full classification scan (one subagent, ~4min) found ~11 genuinely actionable A-CLEAN tickets — including **three test-gap follow-ups I had filed earlier in the same session** (BUT-1204/1207/1209) and then ignored during selection.
- **Rule**: Before ever claiming the loop is out of actionable work (or sending a "needs you / backlog drained" signal), dispatch ONE subagent to classify the ENTIRE open backlog (Backlog+Todo, all ~130+) into A-CLEAN / B-UI / C-REFACTOR / D-BLOCKED / STALE and return the top A-CLEAN candidates. 6-ticket spot-checks are for *picking within* a known-non-empty pool, NOT for concluding the pool is empty. Two specific anti-patterns to avoid: (1) extrapolating from the few highest-priority tickets (the High-pri ones skew toward deploy/ops/epics; the clean Tier-A often sits in Low-pri test-gaps/refactors); (2) ignoring **your own** follow-up tickets filed earlier in the session — those are prime next-loop work, already scoped.
- **Example**: After the scan, resumed the loop on a real A-CLEAN ticket instead of pacing down. The "pace down instead of forcing blocked work" rule from the sprint-execute skill only applies when the WHOLE batch is genuinely D — proven by a full scan, not assumed from a handful.

### [Testing] Red CI on a commit ≠ your regression — suspect a pre-existing flake when the failing test is unrelated
- **Date**: 2026-06-03
- **Trigger**: BUT-581 chunk 3 swept `?? ''`→`.orEmpty()` in `lib/viewmodels/`+`lib/core/` (behaviorally identical, 0 service files touched). CI Run Tests went red — but on `menu_service_test.dart: should give season boost` (`Expected >550, Actual 549`), a `lib/services/` test my change never touched. It had PASSED on the prior commit (same day). It was a pre-existing **flaky probabilistic test**: 1000 trials of weighted selection where boost (P≈0.6, mean 600, σ≈15.5) vs no-boost (mean 500) distributions OVERLAP at ~4σ, so the `>550` threshold trips when a boost run dips to ~549 (~3.3σ). The original "mean-5σ≈560" comment math was wrong (σ≈15.5, not ~2).
- **Rule**: When CI fails on a commit, FIRST check whether the failing test is in the area you changed and whether your change could plausibly affect it. If the test is unrelated (different layer, behaviorally-identical change) and/or passed on a recent prior commit, it's likely a **pre-existing flake**, not your regression — don't thrash trying to "fix" your correct change. Then FIX the flake at root: for a probabilistic test, **seed the RNG for determinism** (inject an optional `Random? random` defaulting to `Random()` — production unchanged, test seeds it) rather than widening a statistical threshold (at small n, overlapping distributions have NO flake-free threshold). Re-running CI "until it's green" hides the time-bomb.
- **Example**: Added injectable seeded `Random` to `MenuService`; the season-boost test now asserts a deterministic count (`>540`, exact under seed `Random(20240603)`) — proves the boost, never flakes. `9fd21d07d`.

### [Testing] `architecture_test.dart` guards are NOT in `dart analyze` — analyze-clean ≠ CI-green for `lib/widgets/`
- **Date**: 2026-06-03
- **Trigger**: BUT-1049 added a new `lib/widgets/recipe/comment_image_attachments.dart` whose full-screen image viewer used a raw `CircularProgressIndicator` as the `CachedNetworkImage` placeholder. `dart analyze --fatal-infos` was clean and all unit/widget tests passed, so it committed + pushed — then CI's **Architecture & Code Quality Validation** *and* **Build Validation** jobs both went red (both run `flutter test test/architecture/architecture_test.dart`). The BUT-885/BUT-1168 guard forbids raw `CircularProgressIndicator(` in `lib/widgets/` (must use the `LoadingIndicator` wrapper for platform-adaptive rendering + a11y live-region semantics). Cost a fix-forward commit (`29ff3f98b`) + a full ~40-min CI cycle.
- **Rule**: When a change adds or edits **any file under `lib/`** (not just `lib/widgets/`), run `flutter test test/architecture/architecture_test.dart` **locally before pushing** — `dart analyze` does NOT enforce the project's architecture guards. Analyze-clean is necessary, not sufficient. Guards that bite and are invisible to analyze: raw-spinner ban (`lib/widgets/`), **raw `?? ''` ban → use `.orEmpty()` (BUT-581, applies to ALL of `lib/`)**, no-direct-Firebase-outside-repos, no `.collection('...')` literals, LTR-fixed `EdgeInsets`, unguarded `DateTime`/`Timestamp` casts, `Image.network` ban, file-size/accepted-large list. For agents building anything in `lib/`, add "run the architecture test" to the verify step.
- **Example 1 (spinner)**: Swapped the raw spinner → `LoadingIndicator(size: 24, strokeWidth: 2)`; arch test +16 -1 → all-green.
- **Example 2 (`?? ''`, 2026-06-04 iter-118 recurrence)**: New `lib/widgets/social/groups/group_draft_codec.dart` (BUT-1203) used `(draft['name'] as String?) ?? ''` — analyze-clean, but the BUT-581 arch guard went red on main (Architecture **and** Build Validation jobs). Same lesson, different guard: I ran `dart analyze` + unit tests but NOT the arch test for a non-`widgets` `lib/` file. Fix-forward: `.orEmpty()` + `import default_value_extensions.dart`. The `?? ''` guard is the most likely one to catch new string-handling code anywhere in `lib/`; grep your diff for `?? ''` before pushing.
- **Example 3 (`?? ''`, 2026-06-08 iter-130/135 — THIRD recurrence, self-caught LATE)**: BUT-901's `recipe_detail_view.dart` `_confirmSnapVisibility` used `formatted ?? ''`. Analyze + lefthook clean → pushed → the Architecture job was RED on main for **3 commits** (BUT-901/906/1213) before I noticed — because each iteration I checked only that CI runs were `in_progress`, never their **terminal conclusion**. Two compounding failures: (a) violated this very lesson again (didn't grep the diff for `?? ''`); (b) **CI verification must confirm a GREEN terminal state, not just that runs started** — use `gh run list --workflow="Architecture & Code Quality Validation" --branch main --limit 1` and read the `conclusion` column (or a Monitor that polls to `completed`). Fix-forward `35fa33517`. **A 3×-recurring mistake despite a written rule means the rule isn't enough → preventive guard filed as BUT-1217: a fast lefthook pre-commit grep of the STAGED diff for newly-added `?? ''` (diff-only → no allowList needed, flags only additions). Until it lands: grep the diff for `?? ''` AND, when a push touches `lib/`, confirm the Architecture CI job reaches `success`, not just that it queued.**

### [Workflow] Eval input must match PRODUCTION input, not the cheapest-to-label input
- **Date**: 2026-06-01
- **Trigger**: Building the cookbook gold-corpus eval, I recommended capturing pages with a phone **document scanner** (dewarp + contrast) because it maximizes OCR quality and minimizes hand-correction. The user pushed back: the whole point is to measure how the pipeline works **for a real user**, and real users photograph recipes with the plain **camera** — curl, glare, angle and all. Optimizing capture for clean labeling silently swaps the thing being measured: a pristine scan benchmarks a best-case that production never sees.
- **Rule**: When a corpus exists to measure real-world performance, the **eval image must be captured the way the end user captures it** (here: camera photo), even though that makes the gold facit harder to produce. Decouple the two: the **facit (ground truth)** comes from the physical source in hand (the book), NOT from any one image's OCR — so it's capture-independent; the **eval image** is the realistic production input. A clean scan is at most a *transcription aid for building the facit*, never the scored input. To separate "is the parser good?" from "is our OCR robust?", capture BOTH a clean scan and a camera shot of the same page (multiple images per recipe, one shared facit) and compare — the gap is what OCR quality costs in the field.
- **Example**: Corrected the corpus capture guidance to camera-first; the pipeline already supported it unchanged (prelabel OCRs `page-01.jpg` → `ocr.txt` → draft → human-corrected `gold.json`), so only the capture *recommendation* was wrong, not the design.

### [Workflow] "Unreferenced" must be proven against the WHOLE repo, never a hand-picked dir subset
- **Date**: 2026-05-31
- **Trigger**: During a deletable-files audit I declared `scripts/backfill/cook_count.dart` "safe to delete (0 references)". My grep scoped refs to `.github docs scripts tools *.md pubspec .claude` — it omitted `test/`. The file was imported by `test/scripts/cook_count_backfill_test.dart` (`import '../../scripts/backfill/cook_count.dart'` + `runCookCountBackfill()`). The deletion broke `flutter analyze`; only the lefthook pre-commit analyze gate (5-min run) caught it and blocked the commit. A second self-inflicted miss: the original workflow's dead-code scanner had *hallucinated* 4 lib files that don't exist — so "0 references" claims from upstream agents are not trustworthy without re-running the check.
- **Rule**:
  1. Before deleting any file, prove it's unreferenced with `git grep -l -F "<basename>"` across the **entire tracked tree** (no `-- <path>` subset), then subtract the file itself. `test/` is the most commonly-forgotten consumer — production code is clean but a test imports the thing.
  2. "0 references" from a prior agent/scan is a hypothesis, not a fact — re-verify yourself. The deadcode scan in `wf_07c1e859` hallucinated non-existent paths; always confirm `git ls-files`/disk existence first.
  3. Distinguish reference *kinds*: a hit that is only your own audit report is not a build reference (safe); a hit in `test/`, a conditional `import ... if (...)`, or an `onCall` export is load-bearing.
  4. Trust the gates — don't `--no-verify` or fabricate review markers to get past a block. The analyze gate caught a real bug here; the firebase-backend-security agent gate forced a genuine second look at the `functions/` deletions. Both auto-mode classifier denials (destructive `git rm` on an exploratory thread; marker fabrication) were correct.
- **Example**: Restored `cook_count.dart` (+ its test stays), shipped only the 7 whole-repo-verified deletions in `5ff405613`. Kept `docs/analysis/` after finding ADR-002, `data-residency.md`, and a `recipe_detail_viewmodel.dart:339` comment all *cite* its MASTER-wave files as decision provenance — deleting it would orphan live citations.

### [Workflow] Late-phase side-effect agents must be wrapped — a Ship schema miss discarded a 1.13M-token run
- **Date**: 2026-05-29
- **Trigger**: `sprint-execute-parallel` ran iter-100 fully (8 tickets implemented + integrated + per-batch reviewed), then the Ship agent finished its git/Linear Bash steps WITHOUT calling StructuredOutput. `await agent({schema})` threw after 2 nudges and the unwrapped throw discarded the entire run. Nothing committed.
- **Rule**:
  1. In a workflow, any late-phase agent whose real output is *side effects* (commit/push/Linear), not its return value, must be wrapped in try/catch so a StructuredOutput miss can't nuke all upstream work.
  2. Follow it with a short focused **verify** agent that reads ground truth (`git log -1`, `git status --porcelain`, `git rev-list --count @{u}..HEAD`) and build the summary from that, not the agent's self-report. Return a recoverable status (`ship-incomplete`), never throw.
  3. Salvage a post-integration crash instead of re-running (each attempt = ~1.13M tokens): work is in the tree (Phase 0 guaranteed clean start), so verify analyze + tests → touch markers (honest, review ran) → `git add -A` + commit + push → reconcile Linear by querying current state (don't trust the crashed Ship's partial writes) → clean orphan worktrees + leftover patches.
- **Example**: Salvaged iter-100 → commit `43b3aadb3`, 7 tickets Done + BUT-1095 Canceled. Hardened the workflow (try/catch + verify-ship agent). See `memory/feedback_workflow_ship_resilience.md`.

### [Workflow] Umbrella "apply the deferred review notes" tickets lose their content
- **Date**: 2026-05-29
- **Trigger**: iter-103 inherited BUT-1165 — an umbrella ticket whose body said "the 10 non-blocking iter-99 review findings are captured here so they outlive sprint-scratch `tasks/todo.md`." But the actual notes were never copied into the ticket; only a pointer + the list of area names was. The next sprint overwrote `tasks/todo.md`, so the specific findings evaporated. No durable `TODO(BUT-XXXX)` markers existed in `lib/` either. The ticket became permanently unmeetable — its acceptance ("each finding fixed or tracked") referenced data that no longer exists.
- **Rule**: A non-blocking reviewer finding must be filed as its **own discrete Linear ticket with the finding text in the body** at review time — never deferred into an umbrella that merely *points at* sprint-scratch. The sprint-execute follow-up rule already mandates this ("file a Linear ticket for every Tier-2 reviewer finding flagged follow-up"); the failure mode is creating ONE umbrella instead of N discrete tickets. If you ever inherit such an umbrella: spot-check the named areas for residual gaps, then close it honestly (areas verified / notes unrecoverable) rather than leaving an unmeetable ticket open or manufacturing fake findings to "complete" it.
- **Example**: BUT-1165 closed Done with a verification verdict — the 3 robustness-critical areas (presence dispose, shopping batch rollback, social-coordinator `_disposed` gate) were confirmed shipped defensively with tests in `631fceec4`; the lost notes were documented as unrecoverable rather than fabricated.

### [Workflow] Workflow `args` can arrive as a STRING — a stringified dryRun ran a full sprint to main
- **Date**: 2026-05-28
- **Trigger**: User asked for a `dryRun` of the `sprint-execute-parallel` workflow. I invoked `Workflow({args: {"dryRun": true}})` but the value reached the script as the JSON *string* `'{"dryRun": true}'`, not an object. `args.dryRun` was therefore `undefined`, `DRY_RUN` was `false`, the early-return gate was skipped, and the FULL pipeline ran: 7 tickets implemented, commit `631fceec4` pushed to main, 11 Linear tickets closed. A "preview" became a live ship.
- **Rule**:
  1. The Workflow tool warns "a stringified list reaches the script as one string" — defend against it. Parse `args` if `typeof args === 'string'` before reading any flag. Use strict equality for booleans (`x === true || x === 'true'`), never bare truthiness on a flag whose absence is dangerous.
  2. Any workflow that pushes/commits MUST have a clean-tree precondition (`git status --porcelain`) and abort if dirty — `git add -A` otherwise bundles unrelated in-flight work into the sprint commit (here it swept the pre-existing iter-98 changes into iter-99's commit, closing tickets BUT-1031/953/1004 that weren't in scope).
  3. A `dryRun` flag must gate ALL side effects (file writes, Linear transitions), not just the final implementation phase. "Preview" means read-only.
  4. For a destructive/outward-facing workflow, prefer fail-safe defaults: an unparseable or missing flag should bias toward NOT shipping, not toward shipping.
- **Example**: Hardened `.claude/workflows/sprint-execute-parallel.js` — defensive `args` parse, Phase 0 clean-tree abort (override via `allowDirty`), and read-only dry-run. See `memory/feedback_workflow_args_stringification.md`.

### [Workflow] Verify Edit succeeded before committing — never trust the commit-message claim
- **Date**: 2026-05-25
- **Trigger**: Iter 73 (BUT-1084). Called `Edit` on `.claude/agents/testing-specialist.knowledge.md` without a prior `Read`. The Edit tool returned `tool_use_error: File has not been read yet`, but I had batched it with `git add … && git commit …` in the same Bash chain. Git happily committed only the `tasks/todo.md` change. Pushed commit `96146b05f` had a body claiming the sanitizer entry was appended, but it wasn't. Caught it on post-commit diff inspection.
- **Rule**:
  1. After an `Edit` that errors, STOP. Don't proceed to commit-and-push assuming the file changed. The error message is canonical.
  2. Never batch `Edit` + `git add` + `git commit` in a single Bash chain — the Edit's success/failure is invisible until you read the tool response, by which point the commit has already happened.
  3. Always Read first if the harness hasn't tracked the file yet. The Read-before-Edit harness rule exists exactly to prevent this class of "tool said no, I didn't notice" failure.
  4. Honesty over completion (CLAUDE.md #10): if a commit claims X happened and X didn't, push a fix-up commit immediately rather than pretending it's done.
- **Example**: Recovery — push `8ebb36be5` "actually append BUT-1061 sanitizer entry (BUT-1084 fix-up)" referencing the bad commit. Don't `--amend` or rewrite history (CLAUDE.md never-amend rule).

### [Workflow] /sprint-execute Phase 1 plan-write is non-optional, even mid-streak
- **Date**: 2026-05-24
- **Trigger**: Iter 46 of an autonomous /loop session (~14 closes deep). User: "Men nu skippar du ju planning stagen eller?" After iter-2 correction in same session, I drifted again: iters 33–45 jumped straight to implementation without writing `tasks/todo.md` first. The Step 0 + plan write to `tasks/todo.md` was happening only in my head, not on disk.
- **Rule**:
  1. `/sprint-execute` Phase 1 ALWAYS writes the plan to `tasks/todo.md` before any code. This is not optional, even for "obviously trivial" tickets.
  2. Streak/momentum is not a license to skip discipline. A 14-iter streak is exactly when discipline matters most — drift compounds.
  3. The plan-file is also the durable audit trail. Mental plans evaporate; `tasks/todo.md` survives context compactions, parallel sessions, and future-Claude re-reads.
- **Example**: Iter 46 BUT-883 codemod — wrote retroactive plan to `tasks/todo.md` after pushback. For iter 47+: plan-file FIRST, then implementation, even for 1-file changes.
- **Files**: `tasks/todo.md` (always), `lessons.md` (this entry)

### [Workflow] Bash `cd` persists across calls — use absolute paths for greps
- **Date**: 2026-05-04
- **Trigger**: During BUT-555 sembast audit, my `grep -rn "sembast" lib/` returned zero matches even though `lib/core/cache/cache_dao_stub.dart` clearly imports `package:sembast_web/sembast_web.dart`. Reason: the previous Bash call ran `cd functions && npm run build`, so the shell session was inside `functions/` when the grep ran — `lib/` resolved to `functions/lib/`, which doesn't contain those files. I almost dropped the deps thinking they were dead.
- **Rule**:
  1. Prefer the **Grep tool** over `bash grep` whenever possible — it always operates from the project root.
  2. When using `bash grep`/`find`/`ls`, either use absolute paths or `cd /c/Butlery/butlery &&` explicitly.
  3. Trust **`dart analyze --fatal-infos`** as the final gate before claiming a refactor done. It caught this one.
- **Example**: After re-running with `grep -rn "sembast" --include="*.dart" /c/Butlery/butlery/lib/`, the consumer was visible immediately. Reverted pubspec changes; BUT-555 outcome = audited & kept (both deps actively used; comments added pointing at consumers).
- **Files**: `pubspec.yaml` (sembast/sembast_web kept with consumer-pointer comments)

### [Workflow] Verify ticket premise before implementing — collapse triage gate
- **Date**: 2026-05-03
- **Trigger**: Mid-conversation, I noted that BUT-760's prescribed fix (App Attest) might not match current `firebase_app_check 0.4.0` API. Malin asked whether tickets should be deeply re-verified before execution given they may be stale, then pushed further: "you create the linear tickets and implement the fixes" — and "I always just approve [the sprint plan]."
- **Rule**:
  1. Linear tickets are notes from past-Claude (during shallow `/triage` scans) to future-Claude. Their authority is *lower* than the implementer's current code-read. The current code-read wins on disagreement.
  2. Run a Step 0 classification on every ticket before coding: **fits / premise-gone / plan-stale**. On `premise-gone`, close the ticket. On `plan-stale`, **rewrite the Linear ticket body** (not a footnote comment) and proceed. Stop-and-ask only on product-intent ambiguity, never on technical re-scopes.
  3. The two-step `/triage plan` → `/sprint-execute` workflow was a rubber-stamp gate (Malin always approved). **Deleted** `/triage`. `/sprint-execute` now picks tickets *and* implements in one call. In a solo-agent setup, the natural unit of approval is the commit/PR, not the sprint plan.
  4. A gate that always passes is worse than no gate — it signals oversight that isn't happening.
- **Example**: BUT-760 ticket said "use App Attest with DeviceCheck fallback." Without Step 0, I would have implemented that blindly even if 0.4.0's API or current security recommendations made it wrong. Step 0 forces a current code-read + (if external claims are made) a Context7 verification before coding.
- **Files**: `memory/feedback_ticket_premise_verification.md`, `memory/feedback_solo_no_scope_gate.md`, `.claude/commands/sprint-execute.md` (rewritten), `.claude/commands/triage.md` (deleted), `.claude/commands/commit.md` (updated reference), `.claude/hooks/setup-morning-brief.sh` (updated reference).

### [Workflow] Stop hook — don't fix errors from other sessions
- **Date**: 2026-04-08
- **Trigger**: Stop hook fired with analyze errors on files not modified in this session. I correctly identified them as pre-existing (commit 0dc221f03) but started fixing them anyway.
- **Rule**: FIRST check: did this session modify the erroring files? If NO → these belong to a parallel session. Do NOT touch them. Tell the user they're pre-existing and move on. Only fix errors in files THIS session actually changed.
- **Example**: `recipe_service_adapter_test.dart` had errors calling non-existent methods. Git status was clean at session start, we only chatted. Correct response: "These are pre-existing from another session, not fixing them."

### [Engineering] A bulk sync must protect BOTH directions of an explicit decision
- **Date**: 2026-08-22 (BUT-1856)
- **Trigger**: The meal-vote chat's roster sync mirrors a `FriendCategory`. I built
  `departedUserIds` so an explicit REMOVAL survives the sync — and then evicted
  "everyone not in the category", which silently deleted an explicit ADDITION an admin
  had made through the group screen, wrote "X har lämnat gruppen" into the thread, and
  did it again after every re-invite. Five review passes read the removal guard and
  approved it; the missing mirror was found only by the whole-diff pass.
- **Rule**: The moment you write a guard so a bulk mechanism cannot undo one kind of
  human decision, ask what the OPPOSITE decision is and whether the same mechanism eats
  it. Name both directions in the same edit, or state in the comment why only one needs
  protecting. A guard that exists in one direction is evidence the author knew the
  hazard — which is exactly why nobody re-checks the other.
- **Also**: the fix is a positive set (`categorySeatedUserIds`), not a heuristic on
  `memberAddedBy`. That map is read by the child-safety backstop to find who seated a
  minor, so writing a sentinel into it would have changed a safety verdict.

### [Engineering] A comment that COUNTS is a defect the moment the count can grow
- **Date**: 2026-08-22 (BUT-1856)
- **Trigger**: One new Cloud Function falsified eight sentences across five files in one
  commit — "the three callables", "All FOUR are pinned", "70 gen2 services", "~7000
  vCPU", "all 71 endpoints", "64 of the 70", "raise it for all 70", "the two raw uids".
  Every one was true when written. Nothing asserted any of them, so nothing reddened.
- **Rule**: Strike the numeral rather than re-counting it, and sweep the WHOLE file —
  the header fix reads as done while three more counts sit in the body. Where the count
  is load-bearing, replace the prose with a test that derives it (the rate limiter's
  daily-cap coverage check now fails on the next unpinned entry instead of quoting a
  total).

### [Flutter] A plan's own mechanism can be refuted by the same measurement that refuted the ticket's
- **Date**: 2026-08-23 (BUT-1911 / BUT-1906)
- **Trigger**: BUT-1906's prescribed remedy (raise the grid aspect ratio) had already
  been refuted by measurement. The approved plan replaced it with a computed absolute
  tile height, and named that computation as its weakest assumption. It was: measured
  across WIDTHS rather than only text scales, the text block needs 244 logical pixels on
  a 360dp phone at 2x and 272 on a 320dp one, and keeps growing as the tile narrows
  because the badge row wraps onto another run. Where that run lands is a step, not a
  curve, so every formula fitted to a few points is a guess that clips on some device,
  silently, in release.
- **Rule**: When a fix's job is to predict a layout, vary the axis you were NOT worried
  about before believing the formula. A prediction that comes out short does not fail
  loudly — a release build draws no overflow stripes, it just removes content. Two
  refuted remedies in one ticket family is a signal to change the SHAPE of the answer
  (here: let the row size to its tallest card, so nothing predicts anything) rather than
  to fit a third curve.
- **Also**: the same pass found the grid card's photo was already collapsing to 28 logical
  pixels at normal text size, 1 pixel on a 320dp phone and ZERO from 1.5x — an `Expanded`
  image is the slack, and the slack runs out before anyone reports a bug about it. Nobody
  had filed that; it was invisible because it degrades smoothly.

### [Flutter] The dietary badge does not fit a grid tile, and only width says so
- **Date**: 2026-08-23 (BUT-1906)
- **Trigger**: The plan reserved vertical space for a dietary row. The row overflowed
  HORIZONTALLY at normal text size on a modern phone: a 2-column tile gives that row 88
  logical pixels on a 360dp screen and 68 on a 320dp one, while "vegansk" needs 111 and
  "vegetarisk" 145 — 188 and 255 at 2x. The card's whole content column is 68px wide
  there once margin and padding come off.
- **Rule**: Before budgeting height for a new row, measure its WIDTH against the box. A
  height budget written for a row that cannot fit horizontally looks finished and ships
  a clipped badge. And check the stated fallback exists: "icon-only" was not available,
  because the badge picks its icon from the STATUS, so two different diets render the
  same green leaf.

### [Testing] A harness that pumps repeatedly in one test cannot search for an overflow
- **Date**: 2026-08-23 (BUT-1911)
- **Trigger**: A measurement harness raised a candidate tile height by 1px per iteration
  inside ONE `testWidgets`, calling `pumpWidget` each time and stopping at the first
  `takeException() == null`. It reported the SAME answer for every screen width and text
  scale — the first candidate above the starting point. `pumpWidget` reuses the element
  tree, so the overflow does not re-report per iteration, and the search reads as "it
  fits" instead of "the instrument is broken".
- **Rule**: One pump per test when the thing being measured is a layout error. To get a
  number, pump once with generous constraints and read the geometry off the rendered
  tree; a suspiciously CONSTANT answer across inputs that should differ is the harness,
  not the finding.

### [Testing] A widget that stops squeezing reddens the tests that measured its squeeze
- **Date**: 2026-08-23 (BUT-1911)
- **Trigger**: Three green tests failed once the grid card sized to its content. All
  three handed the card a box that could not hold it — a 200px-wide `SizedBox` with a
  tight height, and the full 800px test surface where a 4:3 photo alone is 552px tall.
  They had passed because the card gave up its image height rather than complain.
- **Rule**: When a fix removes a widget's ability to shrink, the tests that break are
  usually asserting the OLD contract by accident — they were never about geometry. Fix
  the harness to the widget's real usage (here: a grid card only ever lives in a 2-to-4
  column cell) and say so in the test, rather than capping the widget to keep an
  unrealistic box green.

### [Engineering] A line-count row cannot be typed; it has to be computed at commit time
- **Date**: 2026-08-23 (BUT-1911)
- **Trigger**: `ACCEPTED_LARGE_FILES.md` wants a measured `wc -l` per oversized file.
  I wrote that number THREE times in one change and it was wrong all three times —
  774 when the file was 801, 1148 when it was 1165, 1165 when it was 1176 — each one
  correct when measured and falsified minutes later by my own next edit. Two review
  rounds spent a finding on it. The third would have too.
- **Rule**: Never type a count that describes a file you are still editing. Recompute
  the row from `wc -l` in the SAME Bash call that stages and commits, so the number
  cannot be older than the bytes it describes. This generalises: any figure in a
  committed file that measures another file in the same commit is a derived value, and
  a derived value that a human types is a value that is wrong.

### [Delivery] A sprint's own report is not an inventory — reconcile it against the tree
- **Date**: 2026-08-23 (BUT-1932, BUT-1933, BUT-1936)
- **Trigger**: The run reported ONE held batch. The stash list held four, three of them
  finished work nobody was told about — two Article-17 erasure fixes, an accessibility fix
  with its tests, and a test-shape fix. Separately, BUT-1931 was selected in the plan with
  four acceptance criteria and then left the run with no disposition row at all: no commit,
  no stash, no metrics row, no Linear comment. And four production files were left STAGED
  in the index across turns, where the next commit in the checkout sweeps them.
- **Rule**: Close a run by reconciling three inventories, never by reading the run's own
  summary: (a) every selected ticket has a disposition row; (b) every stash the run created
  is named, by SHA, against a ticket; (c) the index is empty and every dirty path in the
  tree belongs to a named batch. Anything unmatched is reported as unaccounted — a "Done"
  written over an unaccounted tree is the 2026-08-04 false report. And `git stash` DROPS
  untracked files: BUT-1928's entire test proof (a new 267-line file) was outside its own
  held stash, one tree-discarding command from gone while the fix itself survived.

### [Delivery] A gate's cited FILENAME is a claim; verify it exists before obeying the block
- **Date**: 2026-08-23 (BUT-1934)
- **Trigger**: Both commit-gate reviewers refused a real batch with "reviewer never named:
  binary_test.dart; the ledger does not corroborate a read of: binary_test.dart". No file of
  that name exists anywhere in the repo and it was in no batch's file set. An Urgent
  data-loss fix is still unshipped because of it.
- **Rule**: A blocked gate is a stop, not a puzzle — but a gate that names a specific
  ARTEFACT is asserting that artefact exists, and that assertion is checkable in one
  command. `git ls-files | grep` the cited name before spending a batch on it. A block whose
  subject does not exist indicts the gate, not the diff, and the fix belongs in the gate.

### [Testing] A service wrapped in executeServiceOperation makes a stubbed-repo test green without ever calling the repo
- **Date**: 2026-08-23 (BUT-1937)
- **Trigger**: Two tests in `group_weekly_menu_plan_service_test.dart` passed on a fabricated
  empty plan. `getOrBuildWeek` goes through `executeServiceOperation`, whose auth pre-flight
  reads the PRODUCTION `ServiceLocator`; without `setupUnitWithProductionLocator` the
  pre-flight fails, the wrapped closure never runs, and the assertion matches the fallback's
  shape. Only three files in the whole menu suite stand up that harness.
- **Rule**: For any service behind an `executeServiceOperation`-style wrapper, assert that
  the stubbed method was CALLED, not that the result has the right shape — a result shape a
  fallback can also produce proves nothing. Whenever one such false-green is found, sweep
  the siblings: the missing harness is a property of the wrapper, not of the feature.

### [Workflow] A scoped competitive finding got promoted to the product's USP by episodes reading each other
- **Date**: 2026-08-25 (Butlery Radio radar)
- **Trigger**: Radar v.35 headlined that a rival had "taken Butlery's position in words" by
  copying an allergen sentence, calling allergen blocking "the architectural claim Butlery's
  whole differentiation rests on". Malin: *"Var får du din information om att just
  allergenerna är vår stora USP? Det är det inte."* The USP is the collect-everything +
  auto-tag + catered-menu chain, and `docs/architecture/RECIPE_PIPELINE.md` states it in its
  first line — *any source → import → extraction → parsing → tagging → personalization*. The
  claim's real origin was a 2026-07-26 competitor note where "our blocking is real, theirs
  only warns" was scoped as the strongest edge **in a head-to-head with one rival's false
  marketing**. Each radar then gathered from the previous radar's log instead of the product
  record, and the scoped finding compounded into an identity claim over several weeks.
- **Rule**: A recurring episode/report that reads its own previous output will amplify
  whatever framing it started with — no single run introduces an error large enough to
  notice. Anchor every "what this product IS" sentence in the product record (the doc, the
  code) on each run, never in the prior episode; a competitive comparison tells you where a
  RIVAL is weak, which is a fact about the rival, not about what you are for. When a scoped
  finding is worth carrying forward, carry its scope with it — the qualifier is the first
  thing a summary drops.

### [Workflow] A CLI's output format is a platform variable, and a guard that discards a stream stops guarding
- **Date**: 2026-08-26 (BUT-1894 follow-up)
- **Trigger**: `main` was red on the real-time guard's own fixture "binary `*_test.dart` is
  refused" — exit 0 where 1 was expected — while the same suite was green on the dev machine.
  GNU grep reports a binary match as prose rather than a `path:line:text` record, and it moved
  that prose from stdout to stderr in 3.5. The guard ran grep with `2>/dev/null`. Git Bash
  ships grep 3.0 (stdout, caught); the CI runner ships 3.11 (stderr, discarded), so the check
  returned "OK" and exited 0. The hole predated the ticket that exposed it: the same
  `2>/dev/null` sat in the pre-rewrite guard, so CI had never once refused a binary test file.
  Reproduced by running the untouched suite under WSL Ubuntu, which gave the CI log's exact
  14/15.
- **Rule**: Before parsing a tool's output, reproduce that output on the platform that will
  run it — a version difference can move a message to another stream without changing a single
  exit code, and the dev machine's version is the one least likely to match CI's. Parse on a
  property the message cannot lose (here: a record without `:<line>:` is refused, whatever the
  stream and whatever the wording), never on the wording or the stream itself. And a guard that
  sends any stream to `/dev/null` is claiming that stream can hold nothing it needs — write that
  claim down or merge the stream.

### [Workflow] A dormant assertion protects nothing, and the comment written to fix it invented a safety net that did not exist
- **Date**: 2026-08-26 (BUT-1931 follow-up)
- **Trigger**: `butleryGolden` had set `FlutterError.onError = (_) {}` around
  `matchesGoldenFile`. A golden comparison reports its verdict as a THROWN error, so the
  blanket handler turned every pixel mismatch into a PASS. While it was dormant the helper's
  doc comment claimed the goldens were "deterministic across platforms" and produced "the same
  pixel grid on any OS" — nothing could contradict it. The moment BUT-1931 made the comparison
  live, seven of eight goldens differed on ubuntu (0.16-0.86 %) and six of seven on macOS (up
  to 3.90 %). Then, writing the comment that justified the platform pin, I asserted that "the
  verify skill and the commit gate" would still catch a visual regression before a commit
  lands. Review disproved both: `lefthook.yml` runs no Flutter test at all, and `verify.md`'s
  mapping stops at `test/widget/<widget>_test.dart` and never reaches a golden. Looking for
  what actually does compare turned up better evidence than the false claim did — the nightly
  `widget (windows-latest)` leg runs them un-skipped on a machine that is not the authoring
  one, and had already passed. Two further counting errors followed in the corrections
  themselves, one of them a phrase the reviewer supplied for a seven-item set and I pasted
  onto an eight-item one.
- **Rule**: When a repair makes a dormant assertion live, re-check every sentence written
  while it was dormant — they were never true, only unfalsifiable. And a comment justifying a
  fix is itself an untested assertion: before naming a mechanism as the safety net, open that
  mechanism's config and confirm it runs the thing you are claiming. Name the check you
  VERIFIED, not the one that ought to exist. A correction inherits the fragility of the claim
  it repairs, and a count is true only of the exact set it was measured on — moving it to a
  neighbouring set is how a fix ships a fresh false sentence.

### [Workflow] A repo RULE can be the false claim, and a correction round is the likeliest place to plant the next one
- **Date**: 2026-08-26 (BUT-1904 follow-up)
- **Trigger**: Two independent instances in one change.
  (a) `.claude/rules/ui-conventions.md` rule 5 said `Semantics(label:)` "blocks descendant
  Text from being merged into the screen-reader output, so the parent label wins". Written
  under that rule, BUT-1904's dismiss control carried a label restating the whole notice.
  Measured on the built semantics node: the label and the child `Text` are CONCATENATED, so
  the row announced "Du har redan skickat det här, tryck för att ta bort notisen. Du har
  redan skickat det här." The rule is auto-loaded on `lib/views/**` and `lib/widgets/**`, so
  every a11y label in the app was written against it — 190 `a11y*` keys, unaudited (BUT-1953).
  The first test written for it read the `Semantics` WIDGET's property, which cannot see a
  merge, so it agreed with the rule.
  (b) "A blocked row carries no text" was load-bearing wherever the export filter was argued.
  No `firestore.rules` limb bounds what `type` is written TO on a create or a sender update,
  so a client can write a row already stamped and holding 5000 characters — pinned as B16/B17,
  both ALLOW. (The third limb, the read-receipts update, forbids `type` outright — the
  under-counted quantifier was itself one of this sprint's findings.)
  ADR-0009 had ALREADY corrected that premise in one bullet; the correction round that removed
  it there wrote it back further down the same record, as the justification for a different
  decision. It was also load-bearing in the FILTER itself, which keyed on `type` alone and so
  withheld client-stamped rows still carrying text the requester had genuinely received — an
  Art. 15 under-disclosure created by the fix.
- **Rule**: A project rule file is an untested assertion like any other, and a rule that
  auto-loads has produced code shaped by it — when a measurement contradicts one, the finding
  is not "fix this call site" but "correct the rule and scope the sweep of what it already
  produced". Assert against the RENDERED artefact (`tester.getSemantics`), never the widget
  property that cannot observe the failure. And when removing a false premise, grep the WHOLE
  repo for it and fix every copy in the same edit: the round that removes it is the round most
  likely to re-derive it, because the reasoning that produced it is loaded in context.

### [Workflow] A comment that explains WHY a test is shaped a certain way asserts what the test CATCHES — and that is the claim that keeps coming back wrong
- **Date**: 2026-08-27 (BUT-1929 / BUT-1800 sprint)
- **Trigger**: Eight false sentences in one batch, all struck rather than reworded. Five of
  them, each caught by a different reviewer pass:
  1. "the string already existed and reached nothing" — `messagingGroupNoLongerExists` is live
     at `group_detail_view.dart:103`.
  2. "the two uid-bearing analytics siblings BUT-1789 left behind" — there is a third,
     `analytics/notifications/effectiveness`.
  3. striking that numeral produced "uid-bearing analytics event rows BUT-1789 left behind",
     which dropped the names too and so claimed MORE than the counted version did.
  4. "TTL is the tool for the anonymous aggregate, which is why `daily/{date}` keeps one" —
     `daily/{date}` keeps no TTL; nothing in `firestore.indexes.json` covers it.
  5. one comment on `maxMembers` was rewritten THREE times and was wrong all three: first
     "no Dart test can read it" (false — `tag_phase1_seafood_safety_test.dart` reads TS
     source), then "would stay green if the constant and the ARB string moved together"
     (the ARB takes the number as a placeholder, so that mechanism cannot participate), then
     "only a bare literal here can catch the constant drifting from MAX_CHAT_GROUP_MEMBERS"
     (it catches the DART constant moving; TS-side drift is caught by nothing).
- **Rule**: The digest already said a correction is as falsifiable as the claim it repairs.
  What that entry missed is WHICH comments keep failing: the ones that explain why a test or
  a guard is shaped the way it is, because they assert what it CATCHES — a counterfactual
  about a mutant nobody ran, which reads as obviously true and is measurable only by running
  the mutant. First, an explanatory clause of that kind is worth writing
  only after mutation-probing the thing it describes; otherwise state what the code DOES and
  stop. Second, after the SECOND failed repair of one sentence, stop repairing: delete the
  clause outright. A third wording is not more likely to be right — three of the five above
  were second or third attempts, and the correcting round is when the wrong reasoning is
  most loaded in context. Corollary from #3: striking a numeral can BROADEN a claim, so
  re-read what survives as a standalone sentence rather than assuming a shorter one is safer.
  Third, added when the count reached eight: a REVIEWER's stated measurement is as falsifiable
  as a comment. The eighth was not mine — a stakeholder-review agent reported that the capped
  decline-above-cap sweeps in `account-deletion-cascade.ts` "only exist for the collectionGroup
  queries"; I folded it into the plan as a BINDING condition and it propagated into a code
  comment, until a later reviewer produced the counterexample (`deleteChatGroupMemberships`
  caps a plain top-level collection query). A critique arrives with file:line evidence and
  still ranges over only what that agent opened, so check its quantifier before it becomes a
  plan condition or a comment — especially "X is the only Y", which is the shape a
  single-file reader is least able to establish.

### [Workflow] A pipeline that has never run hides every one of its faults at once, and its own safety gate can fail a deploy that worked
- **Date**: 2026-08-27 (BUT-1904 rollout)
- **Trigger**: Shipping BUT-1904 meant deploying two Cloud Functions. `deploy-firebase.yml`
  existed, looked maintained, and had a smoke gate and auto-rollback. Its run history was
  EMPTY — every previous deploy had been done outside CI — and it failed four times in a row,
  each on a different fault: (1) the CI service account had eleven roles and none for Secret
  Manager, so it could not read that a secret existed; (2) `firebase deploy` refuses any
  codebase containing a failure policy without `--force`, and two functions carry a vetted
  `retry: true`; (3) `run.googleapis.com/CpuAllocPerProjectRegion` is 20 vCPU for the region
  while every function is 1 vCPU at maxScale 10, so admitting ONE new revision reserves 10 and
  two at once needs the whole ceiling; (4) the smoke gate then FAILED A DEPLOY THAT WORKED —
  `echo "$list" | grep -qF` plus `set -o pipefail`, where `grep -q` exits on match, `echo` dies
  on SIGPIPE writing the rest of ~200KB, and the pipeline's status comes from the dead writer.
  Which names it reported missing depended on their position in the JSON.
  Two of these were already known to the codebase and neither surfaced: the CPU wall is written
  in `cloud-functions-specialist.knowledge.md`, and the `retry: true` audit is in the code.
- **Rule**: Check whether the pipeline you are about to rely on has EVER succeeded (`gh run list`)
  before treating a failure as a regression — an unused path fails serially, one fault at a time,
  and each looks like the whole problem. Read a deploy's verdict against the RESOURCE, never the
  exit code: `firebase deploy` reporting 52 failures had two real ones, and a green-looking gate
  can fail a live deploy. Any `cmd | grep -q` under `pipefail` is a latent false negative on large
  input. And when a check disagrees with the artefact, believe the artefact: Cloud Run revisions
  said deployed while the gate said missing.


### [Workflow] The paragraph written to BE the correction is where the next three false sentences land — and a pointer is a quantifier
- **Date**: 2026-08-27 (BUT-1961 follow-up / BUT-1928 premise)
- **Trigger**: Three shipped tickets argued from "a failed weekly-plan read OVERWRITES the
  saved week". Measured false: the empty plan carries a fresh `createdAt` and both update
  rules refuse a changed one, so the SERVER denies it. I struck the premise in three code
  comments and wrote a rules test to pin the deny. The commit-gate reviewers then found a
  succession of false sentences, every one of them inside text I had written AS the
  correction, each round's repair producing the next round's finding. This very entry was
  one of them: it first named a count and a number of rounds, and a later round in the same
  commit falsified both. Representative cases:
  1. "W2 is the test that stops an `empty()` change being silent" — W2 builds its fixture
     from a literal and never calls `empty()`. The word appeared in that file ONLY in my
     comment.
  2. "Three shipped tickets all argue from the same fact" — two of them argued the exact
     OPPOSITE, in the very sentences this diff was deleting. The correction re-asserted the
     inversion it existed to remove, as HISTORY.
  3. The same claim, reworded, SURVIVED 100 lines lower in W2's own comment after I struck
     it from the header.
  4. "The constructor half is pinned in Dart by <test>" — that test covers
     `WeeklyMenuPlan.empty`; `GroupWeeklyMenuPlan.empty` had no `createdAt` assertion and no
     `withClock` anywhere in its file. Half the claim's range was unguarded, and the rules
     test G1 would have kept passing while pinning a hazard that no longer existed.
  5. A workflow-map sentence: BUT-1961 relaxes the refusal "OFFLINE, och bara där" —
     `getDocCacheFirst`'s fallback sits in `catch (_)` on the SERVER read, so any error
     serves the cached absence. A rules file staged in the SAME commit said so explicitly.
  Separately, my structural argument that W5 was a single-variable deny control was wrong:
  its fixture carried the OWNER's `userId`, so the uid conjuncts denied it and the doc-id
  prefix was never isolated. A reviewer's probe removed the prefix check and W5 still passed.
- **Rule**: A pointer — "the test that pins this", "the guard for that" — is a QUANTIFIED
  claim, and it must resolve for every symbol the surrounding sentence ranges over. Name two
  constructors and one test resolves half of it. Prefer closing the gap over scoping the
  sentence: adding the missing group test made the sentence true and removed the hazard,
  where a "for the personal constructor only" caveat would have documented it forever.
  After striking a claim, GREP THE WHOLE FILE for it — a header fix reads as finished while
  the body still says it, and a reworded survivor is harder to see than the original. When
  correcting an inverted comment, do not narrate what the old comments believed: that is the
  one sentence guaranteed to re-plant the inversion, and it is a claim about TICKET TEXT,
  which no test can hold. And attribution of a DENY is a MEASUREMENT, not a structural
  argument — "the other conjuncts are satisfied" is the reasoning that was wrong here;
  removing the conjunct and watching the test stay green is the one that was right.

## `git add` + `git commit` in one call: a gate block loses the add, and the next reviewer reads stale index bytes (BUT-1974, 2026-08-29)

`git-workflow.md` requires staging by explicit pathspec and committing in the SAME Bash
call, so a parallel session's index sweep cannot take your files. That is right and stays.
But the commit gate is a **PreToolUse hook on Bash**: when it blocks, it blocks the WHOLE
compound command, so the `git add` never ran either. The index is left exactly as it was.

The failure is not the block — it is what happens next. Applying the reviewer's fixes edits
the WORKTREE, and re-running the reviewers then has them read an index that still holds the
refuted bytes. Both reviewers came back blocking on a finding that was already fixed on
disk, each spending a full pass to conclude "the files are `MM`". Two rounds, no defect.

**The move after any gate block: re-run the `git add` on its own, verify `git status --short`
shows `M` and not `MM`, and only then re-run the reviewers.** `MM` is the whole tell, and it
costs one command to check.

**Sharpened after it bit twice more in the same session, both times after this entry was
written.** The separator does not matter. `&&`, `;`, a newline — the gate is a PreToolUse hook
on the Bash TOOL CALL, so it refuses the whole string before the shell sees any of it. The
second relapse came from thinking `;` would let the `add` through because it is not a
short-circuit; it does not, and nothing in the block message says which command failed,
because none of them ran. Both times a reviewer caught it by comparing the index blob against
what it had read — not by trusting my description of the change. Leaving them staged between the add and the commit is a shorter
exposure than an extra review round, and the block already proved a commit is not imminent.

Generalisation worth keeping: a gate's failure mode includes **what it did not run**. A
compound command is atomic to the hook but not to your intent, so after any PreToolUse block
ask which side effects you had assumed were already applied. Same shape as the analyzer
lessons — the check disagreeing with your memory is usually measuring a different object,
and here the object was the index versus the tree.

## Never write a future action in the present tense — the turn ends before it runs (Malin, 2026-08-29)

Twice in one session I closed a reply with "kör om granskarna" / "jag stagar om och kör den
sista granskningsrundan" and then stopped. Nothing ran. Malin caught both with the same
two-word question, and the second time asked why I keep saying I will do things I never do.

The mechanism is not forgetfulness. A reply that ends with a sentence about the next step
reads — to me, while writing it — as if the step were already in motion, and the turn
terminates on that sentence. The user then has no way to tell a completed action from an
announced one, because both are written the same way.

Two rules, and the first is the load-bearing one:

1. **Do the action IN the turn, then report it.** If a tool call is what makes the sentence
   true, the call goes before the sentence, not after.
2. If something genuinely cannot run yet, it is a **"nästa steg:"** line, never a present
   tense verb. "Kör om granskarna" and "nästa steg: köra om granskarna" cost the same to
   write and differ completely in what they promise.

This is the same failure class as the false code comments this very session kept striking —
a sentence asserting something nobody measured — except the reader here is Malin rather
than a future session, and she cannot check it against the code.

## A mutation probe can certify a LIVE mutant as covered — clear the build cache (BUT-1971, 2026-08-29)

`flutter test` serves a stale incremental kernel after rapid file swaps, which is exactly
what a probe loop does: write mutant, run, restore, run. A reviewer's probe reported a live
mutant as GREEN, and two subsequent runs of the *unmodified* file went red on unrelated
tests. `rm -rf .dart_tool/flutter_build` between the edit and the run made every result
reproduce.

This session ran dozens of probes in that shape. One conclusion is now visibly wrong
because of it: I measured the week-arrow `Expanded` wrappers as unpinned, struck the
comment justifying them, and a second reviewer measured minutes later that removing them
overflows by 30px and 70px. I had attributed the disagreement to a non-equivalent mutant.
The likelier cause is that my probe read stale bytes.

**The asymmetry is what saves it, and it is worth knowing rather than just the fix.** A RED
probe is trustworthy: a stale kernel of the *correct* code cannot manufacture a failure.
A GREEN probe is not. So the error mode is one-directional — a probe can only ever tell you
a guard is unpinned when it is pinned, never the reverse. Every green result this session
led to adding a test or striking a claim, both safe. Nothing shipped resting on a false
green.

Two rules: clear the cache between mutation and run, and treat a green probe as a
hypothesis rather than a measurement — especially before writing the word "unpinned" into
a comment, which is a counterfactual claim about an unrun mutant on top of an unreliable
instrument.

## A notice's meaning cannot be DERIVED from two independently-updated pieces of state (BUT-1971, 2026-08-29)

The group menu needed a retry button on exactly one failure: an undo whose save died,
leaving the dish held in memory but no control reaching it. The cheap read was to derive
that in the widget — `editNotice == saveFailed && canUndoRemoval` — since a failed removal
clears the undo arm and so cannot match.

That is true for the case it was written from and false in general. `_edit` sets
`saveFailed` in its `catch` around the compute, and only clears the undo arm *after* it
publishes. So any OTHER edit whose computation throws lands with `saveFailed` set and the
earlier removal's arm still standing — and the retry it earns would put back a dish the
user removed minutes ago instead of redoing what they just tried.

Nothing in the app can make that compute throw today, so it was defensive rather than live.
That is exactly why it is worth recording: the derived condition looked measured, the
measurement covered one of its two inputs, and the test that would have caught it did not
exist because nobody thought to write a MOVE into an UNDO's test group. It took a
fresh-context auditor reading the two files cold.

The fix is not a longer condition. It is an enum value — `undoFailed` — set at the one
point in the code that knows both halves at once. A derived condition re-answers a question
at a distance from where the answer was known; a named value carries it.

Generalise: when a UI branch keys off a conjunction of two fields, ask what ELSE sets each
field and in what ORDER, then name the case at its origin instead.
