# testing-specialist — accumulated knowledge

Read as Step 0 of every testing task; update when you discover a pattern, find a helper, or
are corrected. `testing-specialist.md` holds the durable DO-WRITE/DO-NOT-WRITE rules, the
production→test path map, and Mock-vs-Fake. This file holds **principles only, edited in
place — never a log, and NOT append-only about itself.**

## How to update this file

- **PRINCIPLES only, 1-4 lines.** Earns its place only if a future run would act
  DIFFERENTLY because of it. Merge into the matching section; never append to the end.
- **The raw, dated record lives ONLY in `testing-specialist.knowledge.archive.md`** —
  append-only, one `### <date> — <title>` entry per incident, verbatim.
- **This file has drifted back four times (35K→432K 2026-07-24; 262K→112K 2026-08-09;
  162K→2026-08-17; 186K→here 2026-09-03) the same way: not dated entries (never used here)
  but individual principles absorbing worked-example detail — measured red counts, failure
  output, round-by-round narrative — instead of citing the ticket and archiving the detail.**
  When adding an example, ask if the sentence stands without it; if yes, archive the example
  and cite the ticket. A number you would have to MEASURE belongs in the archive, not here.
- **Budget ~25,000 chars** — a smell, not the control; the rule above is. Every principle the
  pre-2026-09-03 file carried survives here, merged, or verbatim in the archive's 2026-09-03
  snapshot entry (which supersedes nothing — it preserves).
- **The floor is set by the PRINCIPLE COUNT, not by prose.** At the 1-4 line rule above, the
  budget buys roughly one line per principle, which most of these rules do not fit in. So once
  the bullets are at that size, the only honest levers left are SPLITTING the file or RETIRING
  principles that no longer change what a run does — never one-lining a rule until it stops
  being actionable, and never deleting one to hit a number.
- **The real trigger is the Read tool, not char count** — past ~250,000 chars Step 0 silently
  degrades to grepping. Next time this approaches that, SPLIT THE LARGEST SECTION into its own
  file rather than compress again; measure which one it is at that moment, and do not carry a
  named guess forward (the guess in this paragraph was stale within one pass).

## When to consult the archive

Grep it when a principle here is too terse to act on and you need the worked example (test
code, failure output, measured counts); an unfamiliar mocktail/Firestore-fake discrepancy not
named below; an emulator-lane setup failure (full runbooks live there); a ticket's or area's
full review history (grep the BUT-#### or area name); a principle citing a measurement and you
want the probe that produced it; or this file itself reads too compressed — the 2026-09-03 and
2026-08-17 entries hold prior versions of this whole file, byte-for-byte.

---

## Principles

### Re-review economics (re-reviewing "after automated fixes")
- **Confirm bytes actually MOVED before re-reviewing** — hash + `wc -l` per file, both ends of
  the round; mtime lies. Isolate what changed since YOUR copy with `git cat-file -p <blob> >
  scratch/old && diff -u --strip-trailing-cr scratch/old <f>` — NOT `git diff <blob> $(git
  hash-object <f>)` (dies "bad object"), and never a plain `diff` (LF blob vs CRLF worktree
  calls every line changed). Diffing against HEAD buries the hunk in the round's other work.
- **A tree that moves DURING the round needs the same isolate-diff at VERDICT time** —
  re-verify every finding against the CURRENT bytes before filing and say which copy the
  verdict is against. `git diff <path>` empty ≠ unmoved (staged shows only in `git diff HEAD` /
  `git show :<path>`). Hash a suite's runtime INPUT files too (a source-text guard reading
  `firestore.rules`). **Write the hash TABLE into every round's archive entry, prose-only
  rounds included** — it is what makes the next round's attribution mechanical (BUT-1837/1904).
- **The brief is pinned to a hash and expires with it** — a `sed -n` printing different content
  at the same lines means re-Read and rebuild the mutant list; skip mutants already measured on
  an unchanged hash.
- **The motion check is the map: moved PRODUCTION ∩ unmoved SUITES = unasserted by
  construction** — `git show :<path>` on such a file is a free pre-fix mutant.
- **Fix loop consumes Critical/High only** — an all-Low/Medium re-review never changes. Apply
  zero-risk test-only fixes yourself; never edit production in a review pass.
- **Re-run the motion check against the FIX REPORT, not just your own copy** — a round's remedy
  routinely drags in production edits the report never mentions. Diff EVERY path, sort by
  production-vs-test, and grade the unreported production edits FIRST: nothing has asked whether
  a test can see them. The recurring shape is a fix for finding N landing an unpinned behaviour
  change beside it (BUT-1904).
- **"Duplicate test" is measurable**: mutate the guarded expression; a duplicate deletes only a
  strict subset of the kill set THROUGH THE SAME SEAM. Exceptions: reaches the sole fail-closed
  lookup via a different seam, or is another test's CONTROL. Grade two suites for one class by
  what only ONE holds. Never retire by path convention alone.
- **A live parallel session poisons a battery both ways**: their edits are FALSE KILLS in your
  run (attribute by test name vs mutant blast radius, re-hash before verdict); an identical md5
  + fresh mtime is THEIR mutate-and-restore, and your `finally` can clobber their in-flight
  write — prefer a production-free `test/`-side probe beside a live session.

**MUTATION PROBES: green and red are NOT symmetric. This bullet is load-bearing; do not
compress it.**
- **A GREEN probe is a hypothesis, never a measurement. Only a RED probe measures anything.**
- **The build cache is the reason.** A mutate→run→restore→mutate LOOP can be served the
  PREVIOUS mutant's kernel: mutate and restore inside one second and `flutter test` reuses a
  stale incremental build, so the run reports failures belonging to the mutant before it.
  **Never loop probes in one Bash call. Run each mutant in its OWN call, run it TWICE, and
  grade run B.** Re-run any surprising red alone before filing it.
- **The phantom arrives as a SUPERSET, on the mutant applied in the call right after a
  restore** — extra reds belong to the PREVIOUS mutant's kill set. A superset reads as "this
  mutant is broader than I predicted" rather than as an instrument fault, which is why it gets
  believed (BUT-1897, BUT-1971 M2).
- **Do not trust a `mktemp`+`trap` restore, even one whose own md5 reads clean** — measured on
  BUT-1971, the restoring call printed the pre-mutation md5 and the NEXT call found the mutant
  still live on disk. Restore with `git show :<path> > tmp && cp tmp <path>` (deterministic,
  and it is the copy the parent commits) and verify with `git diff --numstat <path>` EMPTY —
  never against a remembered hash.
- **A green probe over the SUITE YOU WROTE cannot support a "no other witness" claim** — that
  needs the suites found by `grep -rl '<mutated symbol>' test/`, a different set from the files
  you edited. "Raising this constant leaves every suite green" shipped false because the probe
  ran one file (BUT-1971).
- **Grouping several mutants into ONE run is legitimate and halves the runs, but only where they
  touch disjoint EXPRESSIONS *and* disjoint ASSERTIONS — otherwise one mutant MASKS another and the
  missing red reads as "that guard is unpinned".** Measured on BUT-1806: zeroing an increment made
  an opened `docsCreated == 2` guard unobservable in the same run, so a genuinely-killed mutant
  reported green. Predict the exact red SET before running and treat any shortfall as an
  instrument fault first. Two mutants hitting the same test through DIFFERENT assertions are also
  non-disjoint: `expect` stops at the first failure.
- **A green probe on a "nothing changes" test is usually GUARD-CHAIN SUBSUMPTION, not a live
  mutant** — an earlier early-return fires and the guard under test is never reached. The repair is
  a fixture that falls THROUGH the early return (the PARTIAL state, not the complete one), and it
  usually pins a real recovery invariant nobody had written down.
- **When a green result is the claim you want, prefer an ANALYTIC argument to a probe**:
  substitute the mutant value into the fixture's own arithmetic, or read that two expressions
  evaluate to the same fixture literal. Analysis outranks a green probe; a green probe outranks
  nothing.

- **When the question is only "is this line REACHED at all", coverage answers it with no `lib/`
  write** — `flutter test --coverage --coverage-path=<scratchpad>/lcov.info <suites>`, then
  `awk '/^SF:.*<file>/,/^end_of_record/' | grep '^DA:<line>,'`; a `0` is the finding. ~10s, no
  restore, no parallel-session clobber, no auto-mode classifier. A reached line can still be
  unasserted, so reach for a mutant only for "does any test DISCRIMINATE this expression"
  (BUT-1831). The same report settles a widget test turning on a COLLABORATOR's state: read the
  DA hit on the RHS LINE of an `&&`, which evaluates only when the LHS was true (BUT-1908).
- **Dart's lcov mis-attributes lines around an `await`** — an `await service.save(...)` line can
  carry no `DA:` record at all while a hit lands two lines past it, which reads as the opposite
  of the truth. The decisive probe is TEST-side and needs no `lib/` write: copy the suite to a
  scratch `_zz_probe_test.dart`, insert `verify(() => mock.<seam>(any())).called(greaterThan(0))`
  in every case, run with `--plain-name`, delete (BUT-1962).
- **"Only `dart format`" is provable, not assumed**: walk `git cat-file --batch-all-objects` and
  compare whitespace-stripped bytes blob-to-blob (not blob-to-disk — CRLF differs by one
  byte/line). The formatter can insert a trailing comma, so fall back to raw `diff`.
- **"Staging — resolved" isn't resolved until `git show :<path>` diff is empty.** `Read` returns
  the WORKTREE and the parent commits the INDEX, so a repair can be real and still absent from
  what ships. When the BRIEF says a finding is "already applied", run `git diff --numstat` on
  the reviewed paths BEFORE grading, not at verdict time; grade BOTH copies and say which the
  verdict is against — the index copy of a struck sentence is a SECOND claim, not a stale
  duplicate. **A round whose remedy was "strike a false sentence" is the highest-risk shape**:
  the verdict-time grep answers "gone" from the worktree while the index still carries every
  copy — grep `git show :<path>` (BUT-1909/1925/1971).
- **Two ways that check answers "clean" while proving nothing.** (1) A path-scoped git command
  run from the WRONG cwd prints nothing, byte-identical to "no differences" — every verification
  call gets an explicit `cd` and an echoed `pwd`. (2) `git status --porcelain` and `git diff`
  genuinely DISAGREE (stale stat cache: `MM` with an empty diff). Neither is the tiebreaker —
  compare `git ls-files -s <f>`'s blob to `git hash-object <f>`, then `update-index --refresh`
  (BUT-1910).
- **An analyze finding contradicting the source you just read, or a suite passing against code
  analyze says can't compile, means re-md5sum BOTH files** — a timestamp-preserving restore can
  leave stale bytes running.
- **"Would the RULES allow this?" — just run it**: a throwaway `_zz_probe_*.ts` under `npx
  firebase emulators:exec --only firestore --project demo-test` names the rule line in ~90s; add
  a control arm.
- When a parallel session lands a test for the same guard, delete yours with a pointer comment.

**Grading a reported STRIKE or REWORD** (the single most repeated failure class — see BUT-1837,
1897, 1904, 1909, 1910, 1912, 1961, 1962, 1971, 1982 in the archive):
- **Verify by grepping the OLD STRING in the worktree AND `git show :<path>` AT VERDICT TIME,
  never by the motion check** — a file that moved for the round's other edits passes every hash
  test with the sentence still present. **Your OWN prior round's reported strike gets that grep
  too**; rounds that re-read the DIFF cannot see a pre-existing block sitting outside every hunk.
- **A literal grep answers "gone" whenever the surviving copy is a PARAPHRASE.** Sweep the whole
  file by CONCEPT, and expect copies in different syntactic roles (inline comment, module doc
  comment, nested local-function doc, a suite's `group(` header, a presupposition in a sibling
  method). Sweep `test/` as well as `lib/` — a clean-at-HEAD suite is invisible to every
  diff-following sweep and rides into the NEXT ticket's commit.
- **STOP rule, or the sweep never terminates: a sentence saying only what the code REFUSES
  asserts no outcome and is not a carrier. Only a clause asserting what the write WOULD DO is.**
- **Grade the REPLACEMENT as a fresh claim — the paragraph written to BE the correction is where
  the next false sentence lands.** Recurring re-arming shapes: a measured count swapped for a
  quantifier; a supplied ANTECEDENT that is itself a quantifier over the group's contents (put
  the head noun INSIDE the surviving noun phrase); an INCREMENTED count; a positional distance
  ("twenty lines up", a derived value a human cannot type); a HISTORY sentence about the file's
  own prior wordings (only the review archive can settle it — and it is always strikeable,
  because the mechanism sentence beside it is the whole warning); a sentence NAMING its own
  verification command (it flips with the commit). **The repair is to STRIKE, never to
  re-measure or re-point.**
- **Test-file HEADERS carry several claims at once**: a COUNT, an EXCLUSIVITY claim ("N
  invariants nothing else in the repo holds"), a COVERAGE POINTER to another file, and the
  HELPERS the file uses. The round's own new group or new FILE is usually the falsifier, and the
  falsifier is often IN THE SAME FILE. Resolve a cross-file pointer with one grep of the guarded
  CLASS name in the cited file — zero hits IS the finding, and a false coverage pointer is worse
  than a false count because it is the sentence a later run cites to skip writing the test.
- **A test's NAME and its COMMENT are TWO copies of one claim** — grep the concept across names
  separately (`grep "^ *test('"`). Grade every test the round ADDS against the names already in
  the file, and re-grade unqualified `every|all|no ` names whenever the round NARROWS what a
  method returns.
- **The line that stops OVER-correcting: a quantifier over the CODE'S BEHAVIOUR is a CONTRACT; a
  quantifier over the TEST FILE'S CONTENTS is a COUNT.** Keep the contract (state the rule, not
  the evidence); strike the count. Settle a superlative by WALKING THE BRANCHES, never by
  counting fixtures.
- **Sweep the WHOLE file, not the diff-adjacent region** — a review sweep follows the hunks, so
  the accurate numeral near the finding gets fixed and the false one further down rides through.
  A present-tense sentence about a committed ARTEFACT (including a binary, where the claim is a
  DIMENSION no string grep sees) is measured against `git show :<path>`, never HEAD.
- **Grade the strike with cheap mechanical checks**: grep the struck string (0 hits); grep the
  ORDINAL or pointer it CARRIED (an orphaned "the second X" is a dangling reference); re-read
  the paragraphs left ADJACENT, whose "this"/"that" antecedents resolved through deleted text;
  then grade the surviving paragraph now carrying the fact ALONE as a fresh claim.
- **When the struck sentence is PINNED BY A SUITE, run the STRUCK TEXT ITSELF through that
  suite's matchers before grading the repair** — a `contains` on a prefix plus an `isNot` on a
  retired spelling both pass on the clause just removed, so the strike is revertible-green. The
  discriminator is an `isNot` on the struck clause's OWN literal. A prose pin cannot hold "does
  not overclaim" at all (BUT-1904).
- **A "two answers to one question" finding about a comment is settled by measuring each
  clause's REFERENT, never by reading the clauses against each other.** WITHDRAW a disproved
  finding outright rather than re-file a narrowed version — a declined non-blocking finding
  coming back reworded is the correction chain the strike rule exists to stop (BUT-1962).
- **Read a file's OWN HEADER before grading any prose below it** — a header saying "this is a
  ROUTING rule, not a census" makes every later census in that file a defect by the file's own
  terms. Cheapest strike argument there is, and it also settles strike-vs-expand.
- **A production edit in the round falsifies comments in files it never touched**, three shapes.
  (1) A param promoted DEFAULTED→REQUIRED kills every "delete this argument and it falls back to
  <default>" mutant sentence — the mutant is now a compile error and the sentence licenses
  re-adding the fail-open default; grep the removed default's NAME across `test/`. (2) A gate
  added at layer N falsifies every "only this layer can catch it" sentence — grade the quantifier
  against the SIBLING gates. (3) **A DESIGN REVERSAL mid-batch is the worst, because the
  assertions stay GREEN and a PRIOR ROUND has usually graded the rationale sentence TRUE.** A
  round's TRUE grading is valid only against the bytes it measured: when the production shape
  changes, re-grade every sentence the earlier round cleared and re-ask what the mutant is NOW.
  INDEX and WORKTREE can hold OPPOSITE designs of one method with the suite green on both —
  refuse to grade "the change" as one object, and read a comment flipping false→true→false with
  nobody editing it as proof the batch is oscillating. A reversal can RESTORE a retired mutant,
  so re-probe rather than inherit "reverting reddens exactly N" (that figure measures the probe
  PATCH's scope). A sentence a reversal falsified outlives its ticket and rides into the next
  one's commit (BUT-1908/1909/1962/1975).

### Project-specific test infrastructure (full detail in `testing-specialist.md`)
- Production ServiceLocator bridge: `production.ServiceLocator.initialize(DIContainer())` in
  `setUpAll`; both ServiceLocator classes share one `GetIt.instance`.
  `BaseUnitTest.setupUnitWithProductionLocator()` does both and works inside a GROUP-scoped
  `setUp` in a widget suite that otherwise never touches DI — pair it with
  `TestServiceLocator.reset()` + `prod.ServiceLocator.reset()` in that group's `tearDown`. It is
  what makes household/presence surfaces reachable from a widget test; note a VM can resolve a
  repository in its CONSTRUCTOR on a path that never calls it, and
  `test_service_locator.dart` may not register one (BUT-1982).
- **The FieldValue wall is CLOSED at the bootstrap, and a `skip:` naming it is now always
  stale. Do not compress this.** `FieldValue.serverTimestamp()` and every other sentinel resolve
  through `FieldValueFactoryPlatform.instance`, a PROCESS-WIDE SINGLETON that freezes on first
  use; if the real `MethodChannelFieldValueFactory` wins the race, a write through a fake database
  throws `MethodChannelFieldValue is not a subtype of MockFieldValuePlatform` deep inside the fake,
  where best-effort denormalization code catches broadly, swallows it, and lands ZERO documents —
  **the suite does not fail; it silently asserts nothing.** `BaseTest.setup()` now calls
  `installFakeFieldValuePlatform()` as its FIRST statement, so every suite reaching it through
  `setupUnit()`/`setupUnitWithProductionLocator()` wins by construction. A suite standing up
  cloud_firestore WITHOUT that bootstrap must call the helper itself, first. 26 skips died to
  this (BUT-1806); BUT-838 was the same wall.
- **An ordering contract that only a comment enforces WILL be got wrong — move it into the shared
  bootstrap instead of documenting it harder.** The `setUp`-ordering version of the rule above had
  two callers repo-wide and 26 tests switched off around it. When a rule reads "call X before Y",
  ask whether Y can just call X.
- **Un-skipping reveals a SECOND wall as often as none: an `update()`/`batch.update()` on a
  document the fixture never seeded.** `[FakeFirestore/not-found]` there is a real FIXTURE gap, not
  a fake limitation — real Firestore refuses `update` on a missing document too. The missing doc is
  reliably the DENORMALIZED COUNTER the write increments (`public_profiles.friendsCount`, the parent
  comment's `replyCount`), which is also the assertion the skip was hiding. Seed it, then assert it.
- **A test re-enabled from a `skip:` is the likeliest place in the repo to find a body with NO
  `expect` at all** — the skip string was doing the explaining, so nobody wrote the assertion.
  Grep every un-skipped body for `expect` before running anything (BUT-1806 found several, one
  ending literally at `// Assert - FieldValue.increment conflicts...`; the archive lists them).
- **A widget test driving a real screen can be blocked by an unrelated RENDER assertion in a
  sibling branch of that same screen** — satisfy the tested condition through a branch that does
  not reach it, then FILE the render defect. Weakening a fixture to dodge a crash is legitimate
  only when the dodged branch is provably not what the test claims to prove (BUT-1982).
- **`git stash` cannot attribute a failure when the worktree carries ANOTHER session's
  uncommitted work** — stashing yours reverts theirs too, so a suite going green reads as "I
  broke it". Remove your own additions IN PLACE (script it, assert each anchor unique, keep the
  removed text in the scratchpad). Same reason a probe RESTORE cannot use `git show :<path>` when
  the fix under test is worktree-only (BUT-1972/1982).
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — pass it.
- Debounced VM: `fakeAsync` + `async.elapse(300ms)`; `executeDebounced` fires 3 notifications.
  `test/views/` is journey-test territory (owned by `e2e-test-specialist`).
- **A repoint to `collectionGroup(...)` is HALF a fix** — needs a `fieldOverride` with
  `queryScope: COLLECTION_GROUP` or FAILED_PRECONDITIONs; `deploy --force` prunes anything absent
  from `firestore.indexes.json`. Suite needs three arms (override exists at group scope, exact
  set survives delete+add, source still spells the field). Register the npm `test:*` script in
  the same edit.
- **A `setUpAll(registerFallbackValue(...))` added with "the suite had none" is a MEASURED claim
  about the whole file** — grep `registerFallbackValue` and the mocked method across the WHOLE
  file, and delete-and-rerun as the cheapest check (BUT-1962).
- **Source-text assertion suites must strip comments first**, or a bare `includes` stays green
  after the setting is deleted; probe non-vacuity with a STRING mutant, never a file mutant. Two
  follow-ons (BUT-1946): a "the approved helper is still USED" assertion keyed on the bare
  identifier is satisfied by its own DECLARATION — key it on the CALL spelling and probe both
  directions; and BLANK comments to the same LENGTH rather than deleting them, so offsets in
  `stripped` match `raw`, else a marker looked up by `raw.indexOf(...)` returns the file's FIRST
  marker and one excused violation excuses every identically-spelled one.
- **A TAUTOLOGICAL assertion is not automatically a coverage hole — grade the whole test
  ARITHMETICALLY before repairing it.** `hasLength(<the constant>)` compares a bound to itself,
  but a sibling `first.entryId == 'e5'` may be `e(N − cap)` and already redden on every cap
  change. Substituting the mutant value into the fixture's own arithmetic settles this in seconds
  and OUTRANKS a mutation probe. A cross-language DRIFT guard pins EQUALITY between two copies,
  never the VALUE — and the moment one lands, every "nothing ties these two copies" comment on
  the other side goes false (BUT-1971).
- **A stub must reproduce the production return's IDENTITY, not just its VALUE, whenever the code
  under test branches on `identical(...)`** — a stub calling `copyWith` unconditionally hands
  back a fresh object, the short-circuit never fires, and a test written for that branch passes
  on the UNFIXED code. Read the production method's early-return line before writing any stub of
  it. A stub that correctly mirrors the identity return still silently drops the method's THROW
  arm: grade a hand-written stub against the callee's GUARD CLAUSES as well as its early returns,
  and check the gate with a scratch `_zz_probe_test.dart` rather than a `lib/` mutant (BUT-1971).
- **A test asserting that a value SURVIVES a rebuild cannot tell "carried through" from "never
  rebuilt"** — the fixture REACHING the branch is a separate fact from the assertion
  DISCRIMINATING it. Pin the rebuild itself beside the carry (BUT-1971).
- **A mocktail matcher goes vacuous only when a named arg's value stops equalling its DEFAULT** —
  `verifyNever` is the dangerous direction: a non-default named param can never match the
  omitted-param form, so the guard is UNFAILABLE. Spell every named param.
- A poll-until-condition loop discriminates only if the assertion sits AFTER it, polling the LAST
  observable step. `retry:true` owes a reachability read of `isCascadeEventExpired` as the
  handler's FIRST statement.

### Coverage decisions
Codecov: 60% project / 70% new patches / 2% drop tolerance — floors, decided 55% project
(2026-07-11); don't file generic "raise coverage" tickets.

**The opening moves of any coverage review, in order (each is seconds, each has caught a shipped
gap):**
1. **Grep each NEW TOKEN into a token→files table.** Zero files IS the finding; hits only in an
   extracted class's own suite means the composing line in the CALLER's suite is unproven
   (BUT-1838).
2. **Sort those hits by LAYER and by SEAM.** A healthy spread can still be zero coverage of
   PERSISTENCE (four suites naming a field while `toFirestore`/`fromMap` stay untouched, so the
   feature can fail to persist with everything green — and `if (x.isNotEmpty)` guards mean the
   lines never execute); mock-level hits do not reach a real-service gate; a callback seam with
   six hits all in the widget's own suite is absent from the app (BUT-1904/1971).
3. **`grep -rn '\.<method>(' test/` and ask whether ANY hit constructs the REAL service.**
   N-of-N mock-only IS the finding, and it ranges over every method on the class. **A brief's
   "no suite covers X" is that same claim and gets that same grep BEFORE any test is written** —
   the mirror of "resolve a `pinned in <other suite>` pointer with a grep". When the suite DOES
   exist, the live question is its KILL SET, so probe the existing test instead of writing a
   duplicate that deletes a strict subset through the same seam (BUT-1980).
4. **`grep -rn '\.<method>(' lib/` before filing** — a callerless seam owes nothing, and a
   "same-named method on a different class" hit is the usual decoy (BUT-1971).

**Tokens that reliably land with ZERO test hits** — check each by name, whatever the round's
other suites prove:
- A **bundle key** added to `_buildExportBundle`, and a **cascade step** registered in
  `runAccountDeletionWithDeps` (its own registry already records prior misses). Both are
  invisible to every suite that fakes the repository or `require()`s the deleter directly. Grep
  the key / the step NAME as the FIRST step of the review. A source-derived TS drift guard does
  not close it — it proves a path is SPELLED, not that any manager calls it (BUT-1732/1957/1992,
  BUT-1800/1956).
- A **telemetry constant** added in the same commit as the behaviour it measures (the sibling
  SUCCESS event is pinned, its FAILURE twin is not, emitted from the very `catch` the change made
  reachable) (BUT-1962).
- A call added to satisfy a **REPO RULE** rather than a feature (`logPermissionCheck`). Unpinned
  twice over: no repository suite injects an `auditRepository`, so the mixin's null branch never
  runs; and the `requireCurrentUserId()`-vs-caller-supplied-`userId` choice collapses to one
  observable whenever the fixture's authed uid IS the passed one. The killer fixture DIVERGES the
  two uids. Grade that choice PER CALL SITE, never per method. Template:
  `firebase_activity_event_repository_test.dart` (BUT-1962/1981/1971).
- A **method whose RETURN TYPE widens** (`Future<void>`→`Future<bool>`) — every existing call
  site discards it and the suite stays green under `return true`. Read whether ANY call ASSIGNS
  the result. Same grep answers for an UNCHANGED return value whose only assertions sit at a
  MOCK-service layer. Grade a widened return PER BRANCH of the caller's ternary, and resolve any
  "pinned in <other suite>" pointer with a grep before believing it (BUT-1962/1948/1982).
- A **guard added to close ANOTHER gate's finding** (security, GDPR, rules) arrives with NO pin
  at all — no finding asked for a test and the round's budget went to the findings that did. The
  tell is a method at `DA:0` whose class siblings are pinned; read the fix report for guards
  mentioned in passing as "also changed by the other gates" (BUT-1971).
- A **DETECTOR added beside a well-tested MUTATOR** reads as covered because the suite EXECUTES
  it and asserts nothing about it. A completeness signal is observable only through its FAILING
  state — grep the result flag's own name (`gdprCompliant`) rather than trusting the function ran
  (BUT-1971).

- A **DATA-SOURCE swap on a `ServiceLocator.tryGet<T>()?.field` getter** (the CLAUDE.md footgun:
  `profileDisplayName` vs `currentDisplayName`) is deletable-green in EVERY suite, and settled
  analytically — both members are same-typed so the swap compiles, and the value is null either
  way whenever the locator is unregistered OR registered to an unstubbed mocktail `Mock`, which
  `TestServiceLocator` does by default. A pin on `T`'s own getter is the LAYER BELOW and cannot
  see which member the caller reads; an injected-lambda test pins CONSUMPTION, never the BINDING.
  Only two stubs with DIFFERENT strings, over the real service, discriminate (BUT-1764/1705).

**Grading a guard, a widening, or a rollback:**
- **A disposal guard's RATIONALE COMMENT names a reaching path, and that is a measured claim about
  WHOSE continuation resumes — trace it, because one comment text pasted into sibling leaves is
  right in some and wrong in others.** "The owning ViewModel resumes after an `await` and touches
  this object" holds where the VM awaits a SERVICE and then touches the leaf; it is FALSE where the
  VM merely delegates (`return await _manager.foo(...)`, nothing after the await) — there the
  leaf's OWN async body is what resumes, typically in its `finally`. Same grep settles the method
  ENUMERATION such a comment carries: a method that reaches no `notifyListeners` on any path cannot
  reach the guard, so listing it is over-claiming. Strike both, never reword (BUT-1641).
- **A synchronous post-dispose call is an ADEQUATE pin for `if (_isDisposed) return` and pins
  nothing about REACHABILITY.** The guard has no await and `dispose()` sets the flag before
  `super.dispose()`, so no interleaving exists for an async test to expose — settle it
  analytically, not with a probe. What is still owed is one Completer test per leaf that OWNS the
  await, driving the real async method disposed mid-flight: it is the only thing that pins which
  method actually reaches the guard, and it is what catches an over-enumerated comment (BUT-1641).
- **A guard added to close a review finding gets its EXISTENCE pinned and its CONDITIONS not** —
  deleting the block reddens, stripping every conjunct but the one the finding named stays green.
  Grade each conjunct for HARM before filing: some are analytically inert, some degrade to a
  no-op, and usually ONE carries the real hazard (BUT-1971).
- **The test closing ONE conjunct discriminates only while the fixture leaves every OTHER
  conjunct SATISFIED — usually via an unremarked property of a stub nobody would defend.** Name
  the conjuncts the fixture is holding open in the test, or a later tidy vacuums it (BUT-1971).
- **Grade a guard PER FIELD it was extended to, and grade the DERIVED writes beside it** — a fix
  round closes one field and extends the same guard to a sibling in the same edit, and the report
  reads one fixture as covering both (BUT-1971).
- **A SET WIDENED OVER SEVERAL SOURCES is pinned only where a source contributes a uid no OTHER
  source holds.** Build the fixture-uid × source table; reading the spreads one by one makes all
  of them look covered. **Read the LOOKUP STUB first** — a `thenAnswer` ignoring its ARGUMENT
  makes every spread deletable-green; the stub must filter on
  `invocation.positionalArguments.first` (BUT-1971).
- **An optimistic-publish ROLLBACK is pinned only for the field the refusal test reads.** Every
  OTHER restored field is deletable-green whenever the fixture's collateral collection is EMPTY.
  Grade FIELD BY FIELD, seed each collateral collection NON-EMPTY and DIFFERENT from what the
  operation would leave, and check the RETRY-after-failure path — a lost re-armed snapshot is
  permanent data loss the failure test cannot see. A `finally` release is pinned only
  incidentally (BUT-1975/1965).
- **An OPTIMISTIC publish is pinned only where a test observes state while the write is still
  PENDING — count the `Completer`s, one per COPY of the publish, not one per method.**
  `grep -n "Completer\|unawaited"` on the suite is the whole check. Ask FIRST whether the publish
  is optimistic at all.
- **When ONE change edits TWIN repositories/methods, the test lands on the twin whose refusal
  branch is a TAUTOLOGY** and the untested twin is the one with a real actor gate. Grade a paired
  diff PER FILE and run the HEAD-bytes probe on the file the round wrote no test for (BUT-1981).
- **A cleanup that DELETES a pair of unsafe delegates and deliberately KEEPS one twin leaves the
  KEPT twin unpinned** — the survivor gets a rationale sentence instead of a test. Close it with
  a PAIR (failure fallback + persisted passthrough); the fallback assertion alone is satisfied by
  an "always empty" mutant (BUT-1948).
- **"Owes no test" turns on whether an ASSERTION LANE EXISTS, never on the change being small,
  structural or a mere wrapper — and the lane question is SETTLED BY RUNNING a scratch probe, not
  by predicting a deadlock.** When the suite already drives the real VM, already opens the
  surface and already stubs the seam, the lane exists and the wrapper owes the test. Reserve
  "owes none" for a sink with no harness at all. A modal route is the recurring shape, because
  every sibling test resolves during load and taps afterwards, so the whole group agrees
  vacuously (BUT-1971).

**Claims about call sites, constants and cross-language literals:**
- **A claim about "the call sites" is measured over the CALLERS of the CHANGED METHOD** —
  `grep -rn '\.<method>(' lib/` is the whole check. The claim comes back as a BARE QUANTIFIER
  ("the errorPrefix each ViewModel call site carries") and then as an EXISTENTIAL ("some carry
  none"); both are falsifiable the same way and both get the same grep. Two tells: the sentence
  carries its own EXCEPTION CLAUSE (the author enumerated and stopped), and the falsifier usually
  ships in the SAME COMMIT. Strike the quantifier, never repair it to "most" (BUT-1962).
- **A cross-language literal contract is usually pinned consumer-side only, and pinned on BOTH
  sides is still not pinned ACROSS** — a one-sided rename reddens only its own side and hands the
  author the new spelling, so the other language degrades silently. Check whether the emitting
  test IMPORTS the constant or RE-TYPES it (re-typing is the stronger pin) and state the residual
  as DIRECTIONAL. The enforcing pattern exists and is cheap: a Dart test that
  `File(...).readAsStringSync()` the `.ts` and regex-extracts the literal
  (`tag_phase1_seafood_safety_test.dart`). Until it is built, the mirroring test's NAME must state
  only what it asserts (`'the cap constant is 100'`), never the mirror (BUT-1929/1960).
- **A SHARED user-facing message CONSTANT is the same shape inside ONE language** — every
  consumer writes `find.text(kMessage)`, so the SYMBOL is pinned at N call sites and the STRING at
  none. Grep the literal across `test/`; zero hits IS the finding (BUT-1962). **The worst form has
  NO constant at all**: an action string typed twice (emitting `PopupMenuItem(value:)` and
  receiving `switch` arm) with a `default:` that only logs — a typo degrades to a dead menu entry,
  nothing red. The CLOSING shape is one widget test pumping the real app bar with `onMenuAction`
  wired to the real handler and tapping the visible label, so both copies die to one mutant. Scope
  that follow-up to the whole WIRING (the emitting side also carries a VISIBILITY filter, the
  receiving arm an ARGUMENT decision) (BUT-1971).
- **A GENERATED `app_localizations*.dart` carries no logic — its only reviewable question is which
  new ARB strings a suite types VERBATIM.** Read the answer as a table. The unpinned ones cluster:
  arms of an enum→l10n `switch` whose ENUM is asserted at VM level, tooltips, sheet titles, and
  snackbar bodies whose test taps a DIFFERENT literal in the same widget. **The killing mutant is
  ONE-DIRECTIONAL, never a swap** — swapping two arms reddens the pinned sibling, so write the
  finding as "repoint arm X" or the fix round proves the wrong mutant. Rewriting the generated file
  is never the repair. When no UI path can reach the state that renders the arm, drive the VM
  DIRECTLY under a real pump — that is the pin, not a shortcut (BUT-1971).
- **A figure measured OUTSIDE the repo (corpus gold, an eval sweep) has no test holding it, and
  manufacturing a fixture is worse than saying so** — grep the marker's own FIELD NAME across
  `test/`; zero hits IS the answer. What a test cannot do is ARITHMETIC ACROSS THE COPIES:
  recompute every stated delta, and every stated COUNTERFACTUAL, against the totals in each file
  quoting them. A `tools/` script with `main()` + private helpers is untestable by construction (an
  EXTRACTION ticket, not a missing test) — but a hardcoded count in its printed BANNER is neither:
  interpolate the runtime tally, and check the short-circuited arm that computes nothing. Grade an
  "unprintable" claim against EVERY printed artifact, not the counters the sentence names, and
  grade a private helper's return contract by RUNNING a scratchpad replica of it AND its caller's
  chain over the full input lattice — reading is how an ENUMERATING doc came out one state short
  (BUT-1847).
- **A new declaration inserted above a function silently RE-PARENTS the doc comment that sat
  there** — `git show HEAD:<f> | grep -B6` every symbol the change ADDS. A comment-only INSERT
  between two sentences inherits BOTH neighbours' references, so grade an insertion's SEAMS, not
  only its claims.
- **A comment's POSITIONAL safety argument ("the token must be the very first thing") is graded
  against every ITERATION of the loop that consumes it** — a head-parser that peels twice exempts
  slot 2 too. Scratchpad replica over the input lattice; the remedy is a qualifier, not code.
  Grade a QUANTIFIER by the population it ranges over AND by EXPOSURE (by name vs by throw site),
  and never let one `grep -c` be the verifier — require a `throw|return|=>` prefix and watch for
  switch-PATTERN arms and substring siblings. **Then check the repaired bound is PINNED**: a
  widened qualifier is a NEW claim with no test (BUT-1897).
- **A collection's DOCUMENT-ID SCHEME change (deterministic→auto-id) breaks every reader that
  addresses/dedupes by it, invisibly** — grade writers keyed on `doc(x)`, mergers doing
  `byId[doc.id]=doc` (silent double-render), and field-keyed cascades.
- When a fix SPLITS one write/event across destinations, or teaches a method a new side-field,
  grep every WRITER/reader's OWN SUITE (not `lib/`) — the list grows mid-round.

**Guard chains, refusals and structural blind spots:**
- **Guard-chain subsumption, three directions**: BACKWARD (an earlier guard pinned by nothing
  because a later one refuses everything it does), FORWARD (fixture must clear every downstream
  refusal WITH SLACK, never at an exact tie), SIDEWAYS (a new guard can unpin an older filter
  downstream). **The commonest SIDEWAYS carrier is a conjunct added to ONE copy of a duplicated
  predicate** — the other copy's ABSENCE of it becomes load-bearing, and the shared fixture
  builder hardcodes the field the conjunct reads. A production comment saying "do not harmonise
  these" is the DOC half and never the pin; parameterise the fixture builder on that field, one
  case per side (BUT-1904). Total subsumption = comment, never a test. Run "which mutants killed
  nothing" and its mirror once per file.
- **Two CONSTANTS in different classes can sit at a tie with nothing pinning the coupling** —
  mutate EACH side by one; two zero-red probes is the finding. **Before stating the writer's MAX,
  sweep EVERY branch that emits** — a probe covering one branch produced a false "exact tie" that
  was then copied verbatim into a test name (BUT-1912).
- **"X does NOT happen" needs proof the code reached where X could** — "no write" can mean skipped
  OR identical values; count writes, positive control same test. **A refusal test beside a new
  fail-closed guard is the standing carrier**: an earlier guard refuses first and both save
  assertions hold under every mutant. Drive the refused ACTION to the point where it would write —
  and read the inserted call's OWN early-returns against the state the failure left, because the
  same failed read that armed the guard usually nulls what the driving call needs (BUT-1939/1962).
- **The silent-return→throw rewrite seen from the other end**: putting `await expectLater(call,
  throwsA(...))` ABOVE a surviving "nothing was written" assertion makes that assertion
  UNREACHABLE when the throw is missing, so it no longer carries the missing-guard mutant. What it
  still kills is the ORDERING mutant (write, THEN throw) — the only sentence a comment may claim.
  Grade matcher discrimination from the TYPE LATTICE (`PermissionDeniedException implements
  Exception` vs `StateError` an `Error`), and attribute a denial to ONE conjunct (BUT-1962).
- **Grade a read-side guard against EVERY WRITER in the file — and the sentence "every save site
  guards on null" IS the finding.** The unguarded site is reliably the one that DERIVES its
  payload instead of mutating the loaded one, and a null fallback there can retarget the write to
  the WRONG week. **Refuse the aggregate probe the fix round offers back**: "neutralising every
  guard reddens exactly N" ranges over the SET and cannot see a per-site gap — mutate one site at a
  time (BUT-1939).
- **A refusal that REPLACES a whole body ships an ESCAPE HATCH nobody asserts** — "message shown"
  + "the thing it replaced is gone" are entailed by the same branch; the third observable
  (`StateWidget.error(onAction:)`) is untouched. Pin first-read-fails/second-answers plus a CALL
  COUNT, which also kills a no-op callback (BUT-1962).
- **"X was REPOINTED" — run X's PRE-EXISTING suite even if the ticket omits it.** It is written
  against the retired behaviour and usually passes VACUOUSLY (seam uncalled, fixture unseeded).
  Rewrite with a fixture where old/new DISAGREE, seed the new, assert the retired seam unreached
  (BUT-1838).
- A capped/OR'd flag over N sources needs its recall control rebuilt when a source is added or
  removed — grade any capped section by the below/at/over trio (BUT-1801/1832).
- A fan-out loop + accumulator is one untested input whenever every fixture is a singleton — close
  at the outer layer with 2-cut+1-retained via a capture recorder, never `verifyNever` beside a
  positive. Dead work (unread map, unused helper) reads as coverage — file a deletion ticket.
- Two branches sharing one guarded block need separate inputs; one variable at N call sites needs
  proof PER SITE (`any(named:)` survives mutants on the other sites). A comment naming two shapes
  one guard catches is two claims — reachability is a producer question.
- A guard inside a loop has a POSITION (before/after the accumulator update); one above a
  pre-existing early-return is blind to every fixture that falls through — usually the worst leak.
- A guard replicated across sibling FIELDS is tested on one field only; same for sibling CLASSES
  (mutate PER CLASS — a class whose output is already safe for another reason is
  deletable-green); same for a MULTI-ALTERNATIVE REGEX (one fixture per alternative its own doc
  enumerates). Grade the whole family in ONE cheap run: a scratchpad replica plus a MATRIX of
  full-regex × one-alternative-deleted over every fixture. Two things only the matrix shows: an
  alternative killed by TWO fixtures (fine) or by NONE (the finding). In a MASK-head/PRESERVE-frames
  splitter only the PRESERVE assertion pins the split. `hasRequiredFields` checks presence+non-null
  ONLY, never TYPE. **A stated red count must name its SCOPE** (BUT-1897).
- **A repository's ONE-SHOT reader and its LIVE-STREAM twin** carry byte-identical branches and the
  suite pins the one-shot half because it is the easier `await`; the stream is what the open screen
  renders from. `lcov DA=0` on the stream's branch is the whole probe (BUT-1908).
- **A source-scanning guard enforces its REGEX, not its TITLE — cite what it matches, never what it
  is called.** Grade it against the file's OWN PRE-CHANGE BYTES, a free corpus of the exact shape it
  refuses. A one-line anchor cannot see a wrapped call, and a long `reason:` string is what wraps it,
  so the evaded form is the NORM in any suite with explanatory failure messages. Before leaning on a
  guard as a contract, read its pattern and name the ALIASES of the guarded DATA it cannot see (a
  raw-uid lint matching `$userId` walks past `$conversationId`, which is literally two raw uids)
  (BUT-1897/1904).
- **A comment naming WHICH test guards an ORDERING dependency is graded by performing the reorder,
  never by reading the suite** — the decoy is a test pinning the same literal through the HELPER the
  mutated caller delegates to, invariant BY CONSTRUCTION. Route-check each candidate, then check the
  surviving test's fixtures one by one. Scope such a sentence to the FIXTURE it sits beside, and
  `grep -n '^  group('` the counterexample's line before writing "in this group" (BUT-1897).
- **A doc claiming two cases are mutually non-subsuming is a claim about a MATRIX** — run mutants ×
  tests in full; reading pairs it one-to-one by eye. A ~90-line scratchpad Dart replica settles it
  with no `lib/` write (BUT-1904).
- **A "pinned by the case named X" pointer is settled by a REACHABILITY probe on the branch the
  sentence is about** (`--plain-name '<X>' --coverage` + a `DA:` read), never by reading X's name.
  The recurring trap is a behaviour in TWO STACKED LAYERS that both fail the same way (a
  collaborator whose catch returns a NEUTRAL value and a caller catch behind it): every single-point
  mutant is absorbed by the other layer, so the case's kill set is empty. The repair is to STRIKE
  the pin clause, not to re-point it (BUT-1904/1909).
- The in-memory version DELETES data instead of failing to write it — `copyWith` is the durable fix;
  assert an UNTOUCHED member survives.
- Notification `when(...)` stubs are not coverage (the wrapper swallows everything incl.
  `MissingStubError`) — only `verify(...).called(n)` + `verifyNever` on the retained member.
- A test passing an OPTIONAL override bypasses the changed default branch — grep every call site.
  Worst case: a remote KILL SWITCH override present in every test by construction.
- A defensive bound on an injected collaborator is mutation-dead when every fake answers
  immediately — `grep 'fakeAsync\|Completer\|TimeoutException'` zero hits IS the finding. A new
  conjunct beside an existing gate is born mutation-dead without a fixture passing the OLD gate and
  failing ONLY the new one. **A cache invalidated from a stream's LIFECYCLE has one limb per
  callback and they need opposite fixtures**: `onError` an OPEN controller you `addError` to,
  `onDone` one you CLOSE and then read through; `const Stream.empty()` proves neither (BUT-1909).
- The CONDITIONAL-IMPORT SEAM: `flutter test` compiles the native branch into every unit test, the
  web stub into none — the shipping impl runs in zero tests if every test injects a fake through the
  `_testX` seam. Same for `Platform.isX`.
- A "no unit test can see this" comment is a claim — split the untestable PREMISE (rules denial)
  from the testable BEHAVIOUR (the catch is not).
- A COPY test stopping at the confirmation dialog pins the words, not the branch.
  `MaterialApp(routes:{...})` never reads `settings.arguments` — push through `onGenerateRoute`.
- Two l10n keys with the SAME string make `find.text` unfalsifiable — grep the ARB for EXACT value
  equality, since `find.text` is whole-`Text.data` equality, never substring (BUT-1831).
- "Returns null on X / on permission denial" needs a positive control in the same fixture — where
  every layer swallows to null, null is the NORMAL shape of denied/offline/deleted; grep the suite
  for `async => null` on the loader.
- Last-wins/precedence tests need the LOSER asserted absent, with inputs where the wrong answer
  genuinely differs. A partition/drift-guard test from the SAME curated list the impl was written
  from cannot fail — probe with a real sibling name.
- Coalescing-across-calls: a fixture whose injected reader returns a CONSTANT can't see it — model
  the read, drive N calls on an advancing clock. A parameterised loop over failure codes proves one
  leg N times if the fixture starts EMPTY.
- A predicate's SCOPE guard (suffix-not-substring) ships untested when the illustrating fixture sits
  outside its vocabulary — need the positive half PLUS the guarded shape.
- Round-trips must drive the REAL serializer, never `copyWith`; a DateTime sentinel needs zone
  normalisation checked via round trip.
- A two-sided guard (å/ä/ö boundaries) needs a discriminator PER SIDE and a recall control on
  tightening. Boundary shape is decided by the CONSUMER, not tidiness — never harmonise two
  deliberately different guards in this repo.
- A hand-built narrow write payload needs BOTH the carried and omitted keys pinned — for the
  omission, drive a mutator that moves the excluded key as its OWNER.
- Firestore whole-number aggregates store as `int` — `as double?` throws and silently drops the row.
  A guard spanning TWO user-facing shapes ships pinned on one; the diff's own "accepted consequence"
  sentence usually names the unpinned shape.
- A defensive DECODE helper's null branch needs the ABSENCE mutated, not the value, plus a wrong-TYPE
  row. **A `x !== undefined` → `x` (truthiness) swap is a FOUR-state behaviour change an "absent"
  fixture structurally cannot see** — the tell is an ENUMERATING doc comment with one member pinned.
  **Check the swap against HEAD before filing it as new behaviour — an EXTRACTION is the usual
  carrier and the extracted copy is often the REGRESSION** (`git show HEAD:<file>` on the
  ORIGINATING call site, not on the new function, which has no history) (BUT-1904).
- **A fail-loud parser deriving ownership from the STORED BODY is protective on read, an Art. 17
  defect on delete** — decide erasure from the composite-id PATH, not the body. A deterministic
  composite id + body-vs-path check makes "stored==payload" checks TAUTOLOGIES.
- A source-text guard pinning `keys().hasOnly([...])` has five vacuity seams: widest payload;
  complete writer set (forever); anchor sentinel checked against the NEXT match, not global
  uniqueness; blind to the `hasAll` mirror; can't see a SWAP (delete+add, count unchanged). Prove by
  neutralising the call and watching the WRONG-LIST message (BUT-1830).
- **A write the RULES refuse is 100% green under mocks, and its TWINS stay refused — grep the file,
  not the ticket.** Every field the write touches: grep `firestore.rules` for a deny; each surviving
  twin owes a comment naming the rule LINE. A comment quoting a deny-list beside a round-trip
  assertion names TWO populations that legitimately differ (the RULE's key list, the SERIALIZER's
  emitted set) (BUT-1831).
- The client-side twin: an injected `Future<bool> Function(T)` stubbed true can't show what
  PRODUCTION binds actually reject — resolve the argument to its terminal implementation, owed once
  per SPRINT.
- A CF split into pure core + DI'd orchestrator ships the orchestrator untested — a `noop` verdict
  can't see "writes no second message"; the missing fixture is the outsider-vs-member split.
- A guard skipping a per-parent subcollection probe is unfailable when the probed doc doesn't exist —
  repair with a TRAP row at a path production never writes, spelled with production CONSTANTS.
- A repository suite where every fixture lives in ONE scope can't see its scoping `where`, and
  habitually leaves inherited CRUD (`read`, `readAll`, `watchAll`) untested.
- **A dropdown widened to keep an off-vocabulary value needs FOUR fixtures**: off-list-untouched;
  pick-something-then-pick-back (only killer of keying the list off current vs stored selection);
  empty-stored; literal vocabulary pin (BUT-1858).
- **A fix that DELETES dead code is mutation-dead by construction** — only the FORWARD direction is
  pinnable ("the field must not come back"); say that in the name, and never also assert the VALUE
  the deleted code could not produce (BUT-1873).
- **A `StyledInput` with `keyboardType: TextInputType.number` silently gets
  `FilteringTextInputFormatter.digitsOnly`**, so any `replaceAll(',', '.')` decimal parse below it
  is DEAD and "1,5" reaches the model as 15. A suite that never types a DECIMAL cannot see it.
  **RUN the OLD formatter's regex before choosing the fixture that proves its replacement** —
  `allow(RegExp(r'^\d*\.?\d*'))` TRUNCATES at the comma while `digitsOnly` CONCATENATES, and the two
  failures need OPPOSITE fixtures (truncation lands INSIDE any range the true value satisfies).
  Assert the parsed VALUE, or bound BETWEEN the truncated prefix and the true value (BUT-1920).
- A flag selecting between two values is pinned by both arms over one fixture with observably
  different values. A nullable override deriving its default from a nullable payload owes a third
  arm: the EMPTY (non-null) payload.
- "Declines/falls back" needs `equals([input])`, not `hasLength` — catches truncation. A test named
  after an input must assert that input's VALUE.
- **`FakeFirebaseFirestore` honours `.orderBy(f, descending: true)` on a SUBCOLLECTION but RETURNS
  documents that lack `f`**, even as the only document; real Firestore drops them. So an ordered read
  is testable for ROUTING and ORDER on this lane, and its missing-field hazard belongs on the
  emulator lane or in a note beside the seed (measured 2026-09-02).

### Helpers that exist (grep before writing a new one)
| Helper | Path |
|---|---|
| `setupUnit()`, `teardownUnit()`, `setupUnitWithProductionLocator()` | `test/test_support/base_unit_test.dart` |
| `installFakeFieldValuePlatform()` | `test/test_support/fake_field_value_platform.dart` |
| `TestTimestampProvider`, matchers | `test/test_support/timestamp_test_helper.dart` |
| `useEmulatorLane`, `firestoreForLane()`, `clearLane()`, `emulatorOnlySkip` | `test/test_support/emulator_lane.dart` |
| `butleryGolden(...)` | `test/widget/golden/golden_helper.dart` |
| `createLocalizedTestApp(...)` | `test/infrastructure/helpers/widget_test_app.dart` |
| All production mocks | `test/infrastructure/mocks/production_mocks.dart` |
| Typed mock factory | `test/infrastructure/factories/mock_factory.dart` |
| `MockMenuService` (NOT in production_mocks.dart) | `test/infrastructure/mocks/service_mocks.dart` |

**`RecipeFactory.build` has NO `tagResult`/`tagOverrides` param; `RecipeBuilder` does.** Every
tagging-gated render (`recipe.tagResult != null` guards the card's allergen/dietary rows) is
UNREACHABLE from a factory-built fixture, so a test written on the factory passes vacuously rather
than failing to compile — that is how BUT-1780 shipped "fixed" with no badge ever on screen. Use
`RecipeBuilder().withTagResult(...)` for anything badge- or tag-related.

### FakeFirebaseFirestore vs emulator decision tree
| Behaviour under test | Use |
|---|---|
| Plain reads/writes/queries, `collectionGroup`+equality, `orderBy` on a present field | `FakeFirebaseFirestore()` in `setUp` |
| `FieldValue.increment`, `serverTimestamp` (usually), transactional writes, security rules | Emulator lane, or `firestore-rules-tester` |
| `GetOptions.source` | NOT testable — fake ignores `source`; real Firestore THROWS `unavailable` on a cache MISS instead of `exists:false`, so `if (!cached.exists) throw NotFound` is DEAD in production. Assert the outcome contract only. |
| `snapshot.metadata.isFromCache` | NOT reachable — fake answers every read `false`. `grep isFromCache <suite>` zero hits IS the finding. Stage via sealed-class mock on snapshot+metadata. |
| Read of a doc that may NOT EXIST, rules-guarded collection | NOT testable, and the fake's answer is the OPPOSITE of production's — a rule dereferencing `resource.data` denies a `get` on a missing doc. Test a "probe A, fall to B" helper with a ref whose `.get()` throws. |
| Service that wraps Firestore | Mock at the repository interface |
| Dotted-path `update({'core.x': v})`, `update()` on a MISSING doc | **Faithful.** Dotted keys write nested with siblings preserved; `FieldValue.delete()` on an absent key is a silent no-op, so seed the field first. `update()` on a missing doc throws and creates nothing — `expect(oldPathDoc.exists, isFalse)` is a PERMANENT PASS: documentation, not coverage. |
| A NULL-VALUED KEY via `set(..., merge: true)` (incl. `batch`) | **Faithful, `containsKey` is real coverage.** Key present, value null, siblings preserved; null OVERWRITES a stored map. |
| Query PREDICATE SHAPE, incl. `where('<map>.<uid>', isNull: false)` | **Exact.** Build the REAL repository over the fake; dotted keys, `isNull`, `arrayContains` all work. `isNotEqualTo: null` adds NO condition in the real SDK and makes the fake THROW — never accept a comment claiming map-path keys unsupported. |
| A negative "gets nothing" test | Mutation value only when the SUT doesn't swallow errors — behind a catch-all `return []` it's a recall control, and the positive test is the whole guard. |
| A per-ROW transactional write (doc id == uid) | Transaction wrapper is deletable-green by construction — the suite really pins the DOC-ID DERIVATION. Keep the two-actor test as CONTROL; put the permission half in the rules lane. |
| `FakeFirebaseFirestore.runTransaction` | NO-OP PASSTHROUGH, never proves atomicity — handler runs once, `SetOptions` dropped, `timeout`/`maxAttempts` ignored. Use a bare read-modify-write; a truly interleaved test fails on the fake, passes in production. |
| `test/integration` | Nothing in CI passes `--dart-define=USE_EMULATOR=true` over it — every lane test skips everywhere, never coverage. `flutter test` is plugin-less; the lane needs an `integration_test` project. Ticket it, don't "just add the flag." |
| `serverTimestamp()` in `batch.set(..., merge:true)` | Trips the fake on some shapes — never a valid `skip:`. Fix: `installFakeFieldValuePlatform()` as the FIRST line of `setUp` (see the ordering rule in test infrastructure). |
| `permission-denied` | Fake can't fire it — skip only when the branch is a bare `if (e.code=='permission-denied') return null;` above a rethrow, no side effects. |
| `orderBy` field | Seeded fixture must include every field the `orderBy` reads on a top-level collection; on a SUBCOLLECTION the fake keeps docs missing the field (real Firestore drops them). |
| `collectionGroup` | Safe on the fake for index-free `.limit(N).get()` with no `where()`, and (^4.1.0+1) for plain equality. |

### Conscious-skip taxonomy
- Static-method orchestrator: skip only when ALL hold — ≤3 calls, no injection seam, each in its own
  try/catch, no branching beyond the catches.
- Compiler-enforced sync contract (a renamed l10n/analytics constant fails gen-l10n/analyze first);
  pure-nav affordance (route constant is compile-checked).
- Nth surface adopting an already-proven predicate: prove via `git diff --staged --name-only` — no
  new surface if the pure-logic file is absent.
- `SemanticsService.announce` in a fire-and-forget handler is skippable UNTIL the view gains a DI
  seam — dated, not permanent. **A comment-only CORRECTION owes a grep of the CORRECTED SENTENCE
  across `test/`**: a covering suite's group header quotes production prose, so the false claim has a
  third copy there (BUT-1883).
- **A mask-at-the-throw fix owes NO test when nothing observes the message** — the string is handed to
  `AppLogger.error` as the ERROR OBJECT (only the MESSAGE arg is sanitized) and the user-visible text
  is a generic fallback, so `isNot(contains(id))` on it is type-description vacuity. The durable pin
  is a source lint in `test/architecture/`. **The skip INVERTS once the throwing class's own
  `toString()` interpolates the message** — `recordError` sends `exception.toString()`, so a fixture
  IS owed. Read that `toString()` before citing this bullet (BUT-1897/1915).
- **A "sole guard"/KNOWN-GAPS comment is a CLAIM until a test enters that exact branch** — verify
  against the model's SERIALIZER; never read a rules subcollection match or a cascade's defensive
  sweep as evidence the client writes it.
- **A SNACKBAR SEVERITY swap owes no test AT THE CALL SITE** — every discriminator belongs to
  `SnackBarUtils`, not the screen, and a call-site pin reddens on edits to a shared helper the screen
  does not own. If severity is a contract it earns ONE test in `snackbar_utils_test.dart`. **The
  narrower surviving rule (BUT-1971, same ticket): what is banned is pinning a THEME TOKEN a screen
  does not own; an ICON IDENTITY is stable and does kill the swap, so that assertion stands.**
- A pure removal of dead code owes no test when a repo-walking structural lint holds the invariant —
  verify the lint is byte-identical to HEAD and the pre-fix set had exactly ONE element.
- A behaviour-neutral respelling owes no test — earn that by MUTATION-COUNTING the existing suite,
  then fix the comment the respelling falsified. Before writing "the suite had nothing to say", grep
  `test/architecture/architecture_test.dart`: style bans ARE tests there. **Run
  `tools/check_staged_arch_guards.sh` FIRST when reviewing a recovered or never-reviewed patch** —
  ~1s, and it grades the axis vacuity analysis structurally cannot see. Gates grade CLAIMS; lints
  grade CONVENTIONS; neither covers the other (BUT-1912).

### Vacuity patterns — the recurring ways a "passing" test proves nothing
The single most repeated finding across months of review.
- **MASTER RULE: name every OTHER mechanism that could satisfy the assertion, then build the fixture
  where they DISAGREE. Every pattern below is an instance.**

**The tautology family — an assertion that CANNOT fail. Verify these analytically; no probe is owed,
and a probe would only return an untrustworthy green.**
- **An assertion on a state channel the subject NEVER WRITES.** `expect(viewModel.error, isNull)` is
  unfailable when the VM never calls `setError` and never routes through an `execute*` helper that
  would — grep the whole class for `setError|execute|handleError`; **zero hits IS the proof.** It
  reads as pinning "no error surfaced to the user", and the sentence beside it is usually TRUE as
  behaviour while nothing measures it. **Delete the line; never "strengthen" it onto another surface,
  because a subject with no error channel has none** (BUT-1962).
- **Two DIFFERENT expressions that evaluate to the SAME fixture literal** collapse into ONE
  observable and the swap mutant is analytically unkillable — just read the fixture. Recurring pairs:
  owner vs caller, creator vs current user, group id vs conversation id, `isGroup` vs `groupId !=
  null`. **The carrier that outlives the round is a fixture BUILDER that DERIVES one member of the
  pair from the other** — the collapse is then invisible at every call site and survives the very
  commit that fixes the production line. **Read the BUILDER, not the fixtures** (BUT-1856/1971).
- **An assertion ENTAILED BY ITS NEIGHBOURS.** `expect` is fail-fast, so a line evaluates only when
  the lines above passed; when those pin BOTH operands, its kill set is EMPTY by construction. The
  commonest carrier is a LEAK test: an exact-string equality above an `isNot(contains(leak))` loop
  makes the loop unfailable. Keep the equality, delete the loop — the loop earns its place only where
  the assertion above it is a `contains` (BUT-1961/1962). **Where the neighbour IS a `contains`,
  entailment turns on whether the positive's match set swallows the regression wording, and
  TRANSLATING the pair silently re-decides that** — re-probe per DIRECTION after any re-wording, and
  read WHICH assertion the runner names (BUT-1957).
- **A tautological PERMISSION gate**: `save(plan)` passing `plan.userId` into
  `validateUpdatePermission(userId, id, entity)` makes `entity.userId == userId` a tautology, so the
  doc-ID prefix is the sole determinant. Attribute a denial to ONE conjunct before writing about it
  (BUT-1962/1981).
- **A hardcoded/derived fixture value that makes the guarded and unguarded expressions identical** —
  the analytic case; grade a guard PER FIELD, since the sibling field's fixture usually satisfies it.

**Structural vacuity:**
- **An auth-gated `executeServiceOperation` wrapper hollows a raw-mock suite in BOTH directions.**
  `_isAuthenticated()` calls `ServiceLocator.get<AuthRepository>()`, which THROWS in a file with no
  DI harness, so the method returns `defaultValue` having never touched the repository, and
  `safeExecute` catches EVERYTHING so no `throwsA` test can pass while the wrapper is there.
  REMOVING it is a free analytic non-vacuity proof for any fail-loud fix. **The remedy is a HARNESS,
  not a redesign** — `setupUnitWithProductionLocator()` + a `FakeAuthRepository` auth state; the
  proof it worked is any arm asserting the SUCCESS value (BUT-1928).
- **The same swallow falsifies ORDERING-SAFETY comments two files away** — "do A before B, so if A
  fails B never runs" is FALSE whenever A wraps its write in `executeServiceOperation`. Grade every
  "if X fails, Y stays unwritten" sentence by opening X's method and asking whether anything can
  propagate out of it; usually only a guard that throws ABOVE the wrapper does (BUT-1928).
- **A blanket `FlutterError.onError = (_) {}` near `matchesGoldenFile` makes every golden a PERMANENT
  PASS** — the comparator reports by THROWING, `runAsync` catches it and returns `null`, and `null`
  is the matcher's word for "matched". The on-disk symptom is a golden whose DIMENSIONS disagree with
  the helper's pinned surface. Filter on `details.library == 'image resource service'` instead.
  Pinning the FILTER is not pinning the CALL SITE — the durable guard is a source lint in
  `test/architecture/`, which must strip comments first. **Re-check every claim written while a check
  was silenced** (BUT-1931).
- **An ORDERING fix (resolve A before B) is mutation-dead whenever the suite INJECTS A** — the
  testable constructor param resolves A synchronously, hiding a reverted fire-and-forget order
  (BUT-1838).
- **A control that DISABLES ITSELF after one tap makes every later negative-tap assertion in the same
  test unfailable** — order the negative tap FIRST and assert zero (BUT-1904).
- **ONE parameter feeding TWO axes is pinned on the easy axis only** (a grid's `spacing` used between
  rows AND columns) — enumerate the axes the parameter's own doc claims, one assertion each
  (BUT-1911).
- Circular determinism (calling the same pure function twice, or deriving expected from the const
  under test) — pin the literal OUTPUT.
- Sibling-branch short-circuit, BOTH polarities: for `if(A) return true; if(B) return true;`, check
  no fixture satisfies a branch other than the named one. MIRROR (AND-chain + `findsNothing`): a
  negative test naming ONE conjunct needs every OTHER conjunct SATISFIED — assert the premise in the
  test itself (BUT-1869).
- Fake-default-same-as-expected: use a sentinel no real caller would pass.
- **DESERIALIZER-DEFAULT vacuity**: a save-retrieve test asserting the parser's own `defaultValue` is
  unfailable — missing doc, dropped write and empty map all answer the same. Tell: a "returns
  defaults" sibling test with a byte-identical assertion list.
- **Production twin**: a "must not OVERWRITE" fixture holding the value the code would write anyway
  — only picked≠stored can see a dropped argument (BUT-1858).
- A NULLABILITY WIDENING (`T x=d`→`T? x=d`) trades a compile guarantee for a test — trace the `??`
  chain to what the mutant does downstream (a dropped initialiser can store a SILENTLY DERIVED value,
  not "no value").
- A collection-SHAPE assertion instead of the skipped element's VALUE (a Map can't hold a dup key, so
  "appears once" can't distinguish skip-vs-overwrite).
- **A change-detector conjunct in an incremental list updater** is pinned ONLY by two emissions whose
  other compared fields are byte-identical. Its comment is the second claim: grade "this always
  differs" against EVERY producer of the map, because a sibling that SHALLOW-copies hands back the
  SAME nested instance and `mapEquals` answers TRUE (BUT-1908).
- **A guard wrapping [spacer + a child that self-collapses to `SizedBox.shrink()`] is pinned ONLY by
  `find.byType(<ChildWidget>)`** — the child-CONTENT assertion is vacuous, because deleting the guard
  rebuilds the child, which draws nothing and leaves the dead spacer (BUT-1869).
- **A cap-decline test proves `continue`-not-`return` only if the DECLINING leg is not the LAST
  iteration** — with the over-cap direction last, both mutants leave identical state and the "the
  other direction is still swept" assertion passes on LOOP ORDER (BUT-1917).
- **A `contains('$n')` on a NUMBER is satisfied by any cap that has it as a substring** — pin the
  surrounding CLAUSE or the whole sentence. Sibling gap: deriving BOTH sides of a cap assertion from
  `getLimitForType(<type>)` cannot see the map ENTRY disappearing, and two types sharing one value
  make their type strings interchangeable — a suite that never asserts a cap ABSOLUTELY pins
  equality, never the number (BUT-2003).
- **A true/false PAIR over a new boolean pins the flag against HARDCODING and nothing else** — the
  surviving mutant derives the flag from a SIBLING field the two fixtures happen to correlate with.
  Enumerate the callee's zero-valued SUCCESS constants and add the third fixture where flag and
  sibling disagree; the diff's own new production comment usually states that case as the contract
  (BUT-1983).
- **A "resolves through the l10n key, not a literal" test whose BOTH sides resolve the SAME locale
  cannot kill a same-text revert** — pin routing by switching the accessor
  (`AppLocale.initialize(const Locale('en'))`, restored in `addTearDown`) and asserting the OTHER
  locale's text (BUT-1984).
- **A vacuity POST-MORTEM comment ("this case was vacuous because X") is an unmeasured claim, and the
  file's own other assertions usually disprove it** — re-derive the cause from the fix that killed
  it, not from the finder you changed at the same time (BUT-1904).
- **A "renders identically for a foreign/other-user row" case is vacuous when its fixture omits the
  callback the real call site passes UNCONDITIONALLY** — build the "should not occur" fixture with
  the PRODUCTION wiring, or the identity claim is about the harness (BUT-1904).
- A Fake with two branches answering the same success value, driven by one UI flag, eats a routing
  test whole — test the FAILURE arm. An enum-driven `defaults()` owes a KEY-SET-COMPLETENESS test.
- Negative-scope claims need a negative assertion against `toMap().keys`, not a render check.
- **"No write was issued" is the commonest untestable claim** — count writes, positive control same
  test. `findsNothing` needs a co-asserted positive render. A widget whose only access control is an
  early-return is untested if every pump uses the same actor constant.
- Inherited-authorization-discarded: no test sees it while the permission fake defaults true. Tell:
  tests changing `currentUserId` on one double, not the permission double.
- A flag-lifting aggregator owes an EXACT-SET assertion + absence control, not `contains`. A two-layer
  fix (N emitters + chokepoint) is tested only at the chokepoint — a control, not coverage.
- **Boundary tests must straddle the EXACT flip point** (`==N` vs `N+1`); a calendar-day guard flips
  at MIDNIGHT, not a duration. **An "these two spellings agree" assertion (`f(nfd) == f(nfc)`, two
  casings, two separators) is the same rule wearing a disguise** — vacuous unless the fixture
  straddles the threshold `f` actually tests. Measure both spellings against the BOUND before writing
  the fixture, never against plausibility (BUT-1904).
- **Any normalizer/sanitizer is the IDENTITY on an already-normal fixture, and realistic fixtures
  usually are** — enumerate what the helper changes, plant one instance each. MIRROR: a "the masker
  LEFT X alone" assertion is vacuous unless X sits inside the domain the masker would otherwise
  change. Compute the fixture against the guard's BOUNDS (BUT-1897).
- **Moving a mask INTO `toString()` silently subsumes every per-site mask assertion** — pin the
  exception FIELD instead, which cannot be satisfied by the class rule. **MIRROR at a class that does
  NOT mask**: asserting both `.message` and `.toString()` is ONE observable; the discriminator is the
  POSITIVE `contains('<first8>...')`, which also ROUTE-CHECKS. `isNot(contains(<whole value>))`
  passes on ANY elision, so pin the TAIL token absent — but FIRST read the masker's OWN suite, where
  an exact-EQUALITY pin already kills every tail-leaking mutant; demanding it symmetrically at every
  call site after that is symmetry theatre. **Grade "the exception object reaches Crashlytics"
  against the SERVICE's own error handler, not only the ViewModel a comment names** — two routes with
  opposite answers (the MESSAGE arg is masked, the OBJECT arg is not) (BUT-1897/1915).
- **A round-trip over a `double` is bound by its fixture LIST, and Dart's own notation switches inside
  the domain** — `toString()` goes EXPONENTIAL below 1e-6 and `round()` SATURATES at int64 rather than
  throwing, while `infinity` DOES throw `toInt`. Friendly fixtures prove none of it (BUT-1891).
  **A "round trip" over a UI value is TWO seams and the doc always blames the wrong one**:
  format→parse and format→FIELD→parse. Resolve which by grepping the CALLERS — if no production line
  pairs the two functions directly, the direct round trip is the path that does not exist. **The
  field seam's TRIGGER is a KEYSTROKE, not opening the dialog**: `inputFormatters` never run on a
  programmatically seeded controller, so a `typed()` helper models RETYPING, not seeding (BUT-1912).
- **An `inputFormatters:` line is mutation-dead until one fixture types a string the formatter CHANGES
  and the test reads the RENDERED text** — `initialValue` never runs formatters. On an
  `initialValue`-seeded `TextFormField`, `.controller` is NULL: read the descendant `EditableText`'s
  controller (BUT-1910).
- **"The old code did X" is a claim about a GIT REVISION** — `git show HEAD:<file>` then a scratchpad
  replica over the NEW test's own fixture. When it is false the "regression guard" is a CONTROL that
  is GREEN on the bug. Grade a bug-fix suite by which cases fail at HEAD. Corollary: a plain `test()`
  calling a pure helper pins NO wiring by construction (BUT-1910).
- **"Without this setUp line every case would be GREEN" is a claim about a REMOVAL — delete the line
  mentally down each test's own path before writing it.** A missing DI bridge, a `Fake` inside a
  fail-open catch, or an AUTH-PRE-FLIGHT harness all INVERT the observable: without them the
  FAILURE arms pass and the SUCCESS arm reddens. The disproof is almost always IN THE SAME FILE —
  that success arm is why the harness exists. STRIKE rather than reword (BUT-1909/1928).
- A guard classifying OLD vs NEW mutation is untested when every fixture base is EMPTY or the same
  LENGTH — need the MIXED case. Same for a re-found index after `await` and a field-exclusion
  decision.
- A `??` wiring needs a fixture where the arms DISAGREE. "Does less work now" needs a discriminator,
  not a convergence test. A chain gaining a MIDDLE arm (`parse(field) ?? existing ?? default`) is born
  unreachable whenever every fixture seeds a PARSEABLE field (BUT-1910).
- A `continue`-style skip-list disagrees with its absence only when a skipped token shares a LINE with
  a matched one — if that's also where the real answer is lost, it's a design finding.
- A PLACEMENT claim is un-pinnable when wrong-placement is benign — say so, don't force a test. A
  signature-only narrowing opens no gap by construction — the question is whether the DISPATCHER
  calls the narrowed overload.
- A measurement harness's failure mode is a confident number from a broken rig — demand a
  deliberately-broken POSITIVE CONTROL. Two rigs that read 0-diff for free: a `--output=none`/dry-run
  flag, and leaving the ORIGINALS inside the directory the tool rewrites.
- A hand-rolled double MODELLING a write's effect (not applying its payload) is blind to field NAMES,
  and a migration IS a field name — union under `Object.keys(op.data)[0]`.

**Semantics / a11y vacuity (all measured; `.claude/rules/ui-conventions.md` rule 5 was the origin of
the wrong belief and has been corrected in place):**
- **`Semantics(label:)` does NOT suppress a descendant `Text` — the two labels CONCATENATE into ONE
  node's label, parent first, `\n`-joined.** Three consequences: `find.bySemanticsLabel(exactString)`
  returns 0 for THAT reason (the RegExp form finds it); "this label is the ONLY thing a screen reader
  hears" is false, so a label restating the visible text ships a STUTTER; and the widget-property
  workaround the 0-hit provokes is strictly weaker (it cannot see `container`, `button`, the RECT or
  the merge). **Assert `tester.getSemantics(<scoped finder>)` instead.** The correct label for a
  tappable row naming its own content is the ACTION ALONE. **Assert the stutter by counting the CHILD
  SENTENCE inside `node.label`** (`'<row text>'.allMatches(node.label).length == 1`), never the
  label's own words — a word-count reads a restating label as "more words" and stays green
  (BUT-1904/1953/1971).
- **`Semantics(label:, button:)` at `container: false` gets NO node** — the config is absorbed by the
  nearest node-forming ancestor (usually `RenderView`), so the label lands on a screen-sized node that
  owns every other control and takes their taps. `find.bySemanticsLabel` and `matchesSemantics` PASS
  under that mutant; only the node's RECT and its non-adoption of a neighbouring labelled control
  discriminate, and only in a harness mirroring the REAL mount point. **An assertion green under the
  mutant BY CONSTRUCTION is ZERO evidence about the harness, both directions** — a probe spec must say
  which way each observation cuts. **`container` is NOT what a rect assertion discriminates once the
  child forms its own node** (a `GestureDetector` with `onTap` does); what it DOES kill is HOISTING
  the `Semantics` above a wider ancestor. Say which of the two a rect pin covers (BUT-1837).

### Fake/Mock idioms + the ServiceLocator/GetIt bridge
- `class X implements Y` with concrete bodies is a legitimate Fake; the mocktail ban is specifically a
  concrete `@override` on `extends Mock`. `extends <ConcreteClass>` with an override is a legitimate
  subclass SPY, not the banned pattern.
- **`verifyNever(() => mock.f(any()))` is UNFAILABLE against non-default NAMED args** —
  noSuchMethod fills omitted params with declared defaults. Spell every named param as
  `any(named:'x')` (positive `verify` unaffected). **The same default-filling makes a MULTI-`captureAny`
  verify non-vacuous for the "delete both new arguments" mutant** (the call is captured as
  `[<default>, null]`, so `captured.whereType<String>().single` throws). **`.captured` follows the
  SOURCE order of the `captureAny` calls inside the `verify` closure, NOT the mocked method's
  signature order** — so an index is stable (BUT-1858/1971).
- mocktail is LAST-REGISTERED-WINS — wildcard-then-specific `when` is a genuine repoint discriminator;
  reversing the lines silently duplicates the other test.
- When production adds a call to a NEW repository method, an existing `extends Fake` suite silently
  grades that leg's CATCH branch (noSuchMethod throws, swallowed) — grep the new method name across
  `test/`; zero overrides while production calls it IS the finding.
- A `-1` sentinel default on a Fake means two things and only one is self-proving — pick the arm.
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT.
- `verify(f(captureAny()))` marks calls VERIFIED, so a later `verifyInOrder` over the same method
  fails "not found" — capture THROUGH `verifyInOrder`. Fire-and-forget writes to
  `FakeFirebaseFirestore` need microtask draining, not a real-time wait. (A row written through the
  mixin's `unawaited(...)` IS visible to the very next `.get()` with zero intervening awaits, so a
  negative `expect(rows, isEmpty)` does discriminate — measured, BUT-1981.)
- **The GetIt→DIContainer bridge gotcha (recurring: analytics, tag-overrides, correction-snapshot,
  import chokepoints)**: many singletons resolve via PRODUCTION `ServiceLocator`, not
  `TestServiceLocator` — a mock there is invisible. Fix:
  `prod.ServiceLocator.initialize(DIContainer())`, register into `GetIt.instance` after; tearDown
  unregisters + resets.
- A hand-rolled CF query double must be IMMUTABLE once `.where()` is called twice — a mutable `q`
  aliases both legs. A double keyed on flat `"col/id"` paths CANNOT represent a subcollection.
- A new fire-and-forget telemetry call at a chokepoint ships with ZERO tests by default — add
  fires-once and fires-nothing; "no seam" is usually false. The test that matters passes NO injected
  seam. **The test written to close that gap is the one that goes green without reaching the failure
  it names**: the event sits in a `catch` wrapping a whole block, so ANY throw emits it — and the
  throw that fires is usually an unstubbed collaborator EARLIER in the block (mocktail's
  `MissingStubError`, caught by the same `catch`). Never grade such a test by reading it; a
  `verify(() => mock.<seam>())` in a scratch probe names the only call that happened. The repair is to
  stub the earlier seams and KEEP the `verify` in the committed test (BUT-1962).
- A funnel-attribution fix has two directions — an idempotent regenerate re-counts unchanged lines on
  rerun; assert the second run logs only the DELTA.
- A defaulted `String source='manual'` param is worse than silence — grep the CALLERS of the
  newly-tagged method, not the ticket's named path.
- A safety-critical method covered ONLY via a caller's `verify()` proves WIRING, never the CONTRACT.
  Mirror: an opt-in param's tests can prove the contract while zero production callers pass it.
- A REQUIRED param moves the job from "is it wired" to "is the DECLARED value right" — test the UI's
  CHOICE of value and its rebase after a self-triggered change.
- **A REFUSAL+CONTROL pair whose non-vacuity needs no probe**: when both cases pump ONE fixture
  builder and differ only in a stub, the control's green proves the path reaches the observable, and
  the refusal case's green then proves the stubbed seam WAS called. Grade such a pair by reading the
  two `when(...)` lines (BUT-1962).

### Disposal & lifecycle guard idioms (BaseViewModel family)
- `BaseViewModel` already guards disposal twice — only test a subclass's OWN guard when it protects an
  observable effect no base guard blocks.
- Two quadrants: delegate disposed BY this VM → `returnsNormally`+`notified==0`; delegate is a SHARED
  SERVICE outliving the VM → `returnsNormally` is VACUOUS, assert the service's error SURVIVES
  disposal.
- A class with both local `_isDisposed` and inherited `isDisposed` must use the SAME flag its own
  callbacks use. `executeAsync` RETHROWS on failure — prove via a caller retrying only on THROW.
- `dispose()` clearing DATA (not just controllers) opens a use-after-dispose window — dispose
  mid-operation, assert the write still carries user data.
- A "disposes its children" test asserting only `returnsNormally` is vacuous — materialize the child,
  assert it's dead after (`addListener`→`throwsFlutterError`).
- A suite whose every stubbed stream is already COMPLETING pins no cancellation — use a
  `StreamController`, assert `hasListener` true-before/false-after.
- A throw-on-disposed guard inside a shared builder is safe only at callers that catch —
  `notifyListeners()` post-dispose is DEBUG-ONLY, so never conclude "unreachable" from a debug-mode
  trace. **The MIRROR is the commoner comment defect: only the WRITE side asserts.**
  `TextEditingController.text` resolves to `ValueNotifier.value`, a bare field read with no
  `debugAssertNotDisposed`, so "reads the controller on a disposed State → an assertion in debug" is
  false — the read is silent and the real harm is the work that follows. Grade a disposal comment by
  which MEMBER it names (BUT-1831).
- A `manager.dispose()` fix's wiring half ships untested — delete the OWNER's `dispose()` line as a
  probe. The flip is the returned future THROWING instead of resolving null.
- A `Completer` whose `.future` is never awaited is dead plumbing — grep for `.future`. A polling loop
  returning a cached `_lastResult` drops the second caller's work.
- Any concurrency fix needs the second caller actually LAUNCHED (warm-up, gate on a `Completer`,
  launch B, settle) — assert `same(inFlight, queued)`, `queued==null` post-dispose, and exactly ONE
  persisted id from the overlapping pair. **The concurrency VACUITY carrier is LAST-WRITER-WINS**: two
  in-flight edits whose trailing arms both write one field resolve in CREATION order, so a test
  asserting the final value is answered by the ordering and not by the guard it names. The
  discriminating shape lets the NEWER edit finish first (BUT-1971).

### Contract pinning: selectors, ordering, equality, revert
- Every `field==expected` selector needs THREE pins: matched-key reused, unmarked-collision untouched,
  marked-for-different-key untouched + new created.
- `==`/`hashCode` need an equal pair AND a deliberately-unequal instance — watch `hashCode` hashing a
  collection by IDENTITY while `==` compares CONTENT.
- A numeric tuning constant is pinnable only in the direction that DELETES content — never manufacture
  a fixture just to satisfy a mutant.
- A colour pin is legitimate only when the row's semantics ARE the colour, and must name the theme
  TOKEN, not a raw hex — grep the hex across the theme's own fields too.
- `expect(x, isEmpty)` DOES discriminate `''` from `null` — the matcher's body is `(item as
  dynamic).isEmpty`, so null throws NoSuchMethodError and the test goes red (as an error, not a clean
  mismatch). Don't downgrade it to `equals('')` on suspicion (BUT-1874).
- `tester.widget<T>(find.byIcon(...))` throws StateError on "more than one," not a clean red — scope
  it. Ordering needs `verifyInOrder`, not call-count. Revert-to-start: mutate, THEN revert, then
  assert.
- A `void Function`→`Future<void> Function` fix is pinned PER CALL SITE — Dart drops the future behind
  a `void` param silently, so one dropped `await` is invisible unless the injected sink is made to
  FAIL.
- **Splitting one fixture instant into two (clock `t` vs caller's `date`) kills the VALUE-swap mutant
  and leaves the DERIVATION mutant alive** — inside `withClock` a same-week `date` makes
  `weekStartOf(clock.now())` byte-identical to `weekStartOf(date)`. What kills it is a SIBLING test
  running OUTSIDE the fixed clock. Grade a "do these mirror?" question per AXIS (BUT-1961).
- **The ROLE carrier is a fixture builder that hardcodes the PERMITTED role** — a widget-test builder
  pinned to `edit` cannot reach the viewer state, so every `if (vm.canEdit)` affordance guard has zero
  widget coverage while the suite reads complete. A VM-level refusal test does NOT substitute: it
  proves the DATA is safe and says nothing about offering a control that can only fail. Parameterise
  the widget fixture by role, and diff the two builders' SIGNATURES when a unit suite and a widget
  suite share a subject (BUT-1971).
- **Fixture-shape family**: the fixture's own shape answers for the code. An accumulator off `.first`
  hides its loop unless the first item is interior on every axis; enumerate every field production
  READS and override each independently.

### Import & correction-capture pipeline
- SSRF host-filtering and decompression-bomb caps are running invariants across every import surface.
  A CTA/UI test proves the LABEL, not the ACTION — assert wire-level dispatch separately.
- Correction-snapshot/parse-cache keys sharing a placeholder across unrelated imports silently
  collide — test two same-kind imports in sequence.
- A wizard rebuilding an editable buffer from a prior step loses edits on back-then-forward.
- **`\b` fixes are per-REGEX, not per-file** — the lefthook `swedish-boundary-guard` can't find
  `RegExp(r'\b'+unit+r'\b')` or an ASCII-token alternation wrapped in a literal `\b`; grep the raw
  escape yourself. Check for a diacritic FOLD first.
- A safety carve-out via `return null` grows a second, untested public entry point once one caller
  lacks the fallback. A "keep the row" carve-out needs the re-inserted string run through the
  CONSUMER's normalizer, asserting the resolved KEY, not list membership.
- A boundary repair inside a shared predicate changes behaviour at EVERY call site — some decide the
  OPPOSITE of the predicate's name; grep for compensating workarounds whose comments now assert the
  fixed bug as live.
- Rate-limit metering: enumerate ALL call sites of the limited op. A circuit-breaker over a parallel
  `Future.wait` must not discard already-materialized results mid-batch.
- A cross-copy "single source of truth" test must READ every copy — an unexported duplicate still
  drifts. Windows: `/c/tools/flutter/bin/flutter test <forward-slash-path>` via Bash works directly.

### GDPR / export section contract
- **Every section needs THREE proofs**: seeded (count present, PII round-trips verbatim);
  ownership-negative (another uid's doc absent); empty-safe (`total==0` AND `containsKey('error')
  isFalse`).
- **A FOURTH: JSON-ENCODABLE** — `expect(() => json.encode(section), returnsNormally)`. A raw
  `Timestamp` anywhere means NO FILE for the subject, uncatchable per-section. Drive via the REAL
  repository over `FakeFirebaseFirestore`. Pin the EXACT key set too.
- **A new export section spans FOUR-PLUS SEAMS and the round's suite lands only on the manager one**:
  the repository's Firestore PATH (the manager suite fakes the repository, so a wrong collection
  matching zero rows is invisible — BUT-1697 dropped every shopping list that way), the manager's
  shape, the bundle WIRING in `data_export_service.dart`, and the section's `data_minimisation`
  disclosure. ONE end-to-end test in `firebase_data_export_repository_*_test.dart` — seed the real
  subcollection plus a DECOY in the neighbour, assert the bundle key — kills the first two mutants at
  once. **A written warning comment does NOT work; the mechanical grep does** (BUT-1732/1957/1992).
- **A fifth seam: a SIBLING section that DERIVES flags from the same repository read.** Grep the
  repointed repository method for EVERY manager caller, not just the section named in the ticket, and
  make the fake answer each caller's other reads (BUT-1990).
- **A new section's failure envelope is pinned only by the file's parameterised `cases` table, never
  by a hand-written `completion(isA<Map>())`** — that matcher is satisfied by the raw-leak mutant
  `return {'error': e.toString()}`, the exact defect the table exists to prevent. Adding the row is
  the whole repair, and it also grades the section PHRASE, which reaches the bundle as "Could not
  export &lt;phrase&gt;." (BUT-1760/1957).
- **A section that gains PER-LEG isolation owes three checks the diff does not show**: (1) the removed
  outer `try` was the section's only envelope guarantee — grep every throwing expression left OUTSIDE
  the per-leg `try` (the `_exports` ServiceLocator getter is the usual one, and a throw there now
  aborts the WHOLE bundle); (2) a leak fixture repointed onto the surviving seam is fine only if the
  path it LEFT is pinned one layer down; (3) a partial-vs-outright condition is unkillable by
  construction when both `if`s write the same map key — do not file that as a coverage gap
  (BUT-2003/2004).
- **The `data_minimisation` sentence IS the Art. 12(1) mitigation for whatever the section decided to
  keep, so it dies with nothing red while the kept third-party data ships on.** Every sibling section
  carrying that key has a presence pin; a section disclosing rather than promising needs the same pin,
  asserted BESIDE the passthrough test so the disclosure and the disclosed field die together. Settle
  it by grep, not probe — the key is additive. **When the withheld set lives in ONE language and the
  sentence disclosing it in ANOTHER, nothing ties them and the drift arrives at birth** — grade a
  disclosure sentence against the EXEMPT SET, and read a test named "the bundle names BOTH exempted
  collections" as a count over that set rather than a behaviour (BUT-1957/1992).
- **That pin then COUPLES the wording, so grade the DISCLOSURE against the mechanism it describes in
  the same round.** It survives TRANSLATION only by luck; re-probe per DIRECTION after translating a
  pinned sentence, and prefer the phrase that pins the CLAUSE carrying the disclosure over a word the
  rest of the sentence also satisfies. Strike an overclaiming HEADLINE clause even when it errs in the
  privacy-conservative direction — it is the sentence a later round quotes to argue a wider keep
  (BUT-1957).
- A refactor collapsing N redaction blocks into ONE loop over a literal field list moves the whole
  contract into THE LIST — a dropped name fails OPEN while the doc still claims removal (BUT-1838).
- Before crediting a redaction, check that leg's QUERY against the WRITERS — a strip on a leg
  returning zero rows is dead code AND an Art. 15 gap.
- A GDPR rationale naming a Cloud Function is a claim about another language — grep `functions/src`
  before it ships or gets copied into `ACCEPTED_DEVIATIONS.md`.
- The bundle AGGREGATOR needs its own two tests: a flag nested in a list-of-maps needs a depth-bounded
  walk; the warnings lift must key on `error` as well as `error_code`. A derived message can't be
  worded from the failure case alone — `error_code` also marks PARTIAL success.
- A field added to an existing scrub/cascade ships untested because the suite LOOKS covering — audit
  the fixture's fields, add keys + a retained-field negative.
- A cascade deleting a PARENT does NOT delete subcollections, and its residual probe usually counts
  top-level docs only — grep rules for `match /<coll>/{id}/<sub>` and every client
  `.doc(x).collection(y)`.
- Redaction paths (FCM token→prefix+`[redacted]`) outrank another happy-path test. A two-query
  union+de-dup needs FOUR fixtures: sent-only, received-only, self (both legs match), foreign.
- Truncation flags need all THREE boundary points + a positive control per leg — the highest-value
  untested case in a multi-leg section is neither leg over cap but COMBINED over. `total_count` must
  equal the SHIPPED length, not the pre-trim fetch.
- The strongest forwarding assertion is one WHOLE-MAP equality on a per-method capture, derived from
  `getLimitForType` so a typo'd `type:` is caught too. A section's wiring line is deletable-green
  unless a bundle-level test asserts `data['<section>']`.
- A section-root flag ORed over M reads while aggregating N>M record types asserts completeness for
  data never probed — count reads, not the ticket's list.
- When extracting a shared capped-read primitive, test it directly (size/trim/both
  boundaries/unknown-type/error); per-section tests then only prove wiring — grep the whole swept file
  for the old pattern.
- **Fixture note**: a LOCAL `DateTime(...)` seed is zone-safe when the expectation is the SAME
  expression production evaluates — but a "newest wins" fixture whose newest row is also the LAST row
  leaves the last-wins mutant alive; put the max in the MIDDLE of an unordered query's rows.

### Settings-hydration & sentinel-parameter template (recurring: BUT-1220, 674, 1322, 1610)
Any field persisted via a private settings sub-doc needs: hydration seeding the sub-doc directly; a
corrupt-value test ALSO asserting a sibling merged field survives (one `copyWith` in one try/catch can
abort the whole merge); a save-path test asserting the settings doc has it and the public doc does
NOT, plus a round trip; one test per serialization surface. Sentinel params (`Object? field=_unset`)
need both quadrants: omit→preserved, explicit-null→cleared. Capture the forwarded ARGUMENT IDENTITY,
not a downstream no-op. An EMPTY-STRING sentinel (`''`=cleared, `null`=leave alone) is a contract
between TWO files: a widget test pinning what LEAVES the emitter is green forever if a consumer later
re-collapses `''` to "unchanged" — pin the consumer's own `x ?? current` line in ITS suite, same edit
(BUT-1874).

### Age/maturity/consent gates
- A field moved client→CF-authoritative: invert the old round-trip into an ABSENCE assertion on every
  client-write surface.
- "Infra error" vs "explicit rejection" needs a TYPED discriminator flag on BOTH branches.
- "Must NOT re-fire on resume" needs `verifyNever` AND the positive downstream effect in the SAME test.
- A "never-throws" method's contract is proven by the user-facing error field staying null on EVERY
  failure branch.

### Menu & tagging domain
- Weighted-random selectors: assert WEIGHT MATH via a `@visibleForTesting debug*` hook, never the
  sampled outcome; unrated == 1★ value; ceilings via `closeTo` at extremes.
- Any feature persisting entity ids later intersected with a live collection needs a ZERO-INTERSECTION
  test — stale ids usually fail OPEN, dangerous for allergen safety.
- A "conservative fallback" is only conservative if the shared `defaults` const is a SUPERSET of the
  happy path — open it and check.
- A widen-not-replace fallback needs its PASSTHROUGH half asserted too, not just the added floor.
- Anchor/cursor guards need a fixture landing the two code paths on DIFFERENT days.
- Feature-flag OFF paths are a systemic blind spot (`tryGet<T>() ?? true`) unless a fake flag service
  is explicitly registered false.
- Denormalized-projection tests: capture via `.captured.last`; cover NULL-CLAMP (last vote removed →
  null, not 0); prove EQUAL-WEIGHTING with ASYMMETRIC inputs.

### Firestore cost, index & cascade patterns
- A declared composite index needs its own assertion (fakes can't catch a missing one) — assert
  `queryScope` alongside field order.
- A merged/idempotent cascade `update()`ing a doc it assumes exists can throw NOT_FOUND and fail the
  whole batch — test the gating doc exists but the target does not.
- A dotted-path transactional `update` needs an UNRELATED sibling field asserted SURVIVING.
- A CF trusting a doc field for a security decision is only as strong as the Firestore RULE validating
  it on create.

### CF/TS-specific
- A new emulator-integration test needs wiring on THREE fronts: the granular `test:integration:*`
  script, the composite CI chain, and the workflow's `paths:` trigger — unit runners auto-discover
  `test:*` but EXCLUDE those prefixes.
- Order the existence assert BEFORE the first dereference of a possibly-missing doc.
- A fix swapping a hand-rolled throw for a shared enforcer ships deletable-green whenever the suite
  injects that enforcer as a seam, and the AUDIT ROW is unassertable if the logger bypasses the
  module's own test seam (`admin.firestore()` direct vs `__setFirestoreForTest`).
- A relational CONFIG pin stays green when both numbers move together — anchor one literal.
- A ts-node mutant removing the LAST use of an import doesn't compile (`TS6133`) and prints ZERO test
  lines, which reads as "the whole suite died" — keep the symbol used.
- A retired-collection RE-POINT is proven by seeding the RETIRED path as a trap in the SAME run.
- **Hand-rolled emulator runners share ONE world across cases, in order, so a mutant's RED COUNT is
  inflated by state cascade and cannot attribute anything** — a downstream case's PRECONDITION assert
  reddens on the upstream case's damage. Attribute per case with no repo write by replicating the
  handler's decision branches in a scratchpad JS file and replaying the cases in order; reproducing
  the reported red counts exactly is what proves the replica. **A guard that only skips WORK (a read,
  a redundant write) is invisible to a suite asserting only the final value** — it needs a fixture
  where the skipped work would land somewhere DIFFERENT, or it is untestable at that layer and owes a
  comment, not a test (BUT-1904).

### Multi-select / bulk-action wiring
- VM tests + card tests can pass while the GLUE (snapshot/order/callback) is untested at widget level.
  Selection-guard tests need the owner's OWN tile, not all-strangers.
- Clear-on-cancel: assert the count returns to the ORIGINAL, not zero. Copy-paste id-field mismatches
  are invisible unless a fixture makes the fields DIFFER.
- Async error stubs: `thenAnswer((_) => Future<int>.error(...))` — never `thenThrow`.

### Extraction seams & duplicated-logic-across-surfaces
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static`, not a DI bridge.
  When the SAME behaviour is re-implemented in 2+ classes, demand a test PER COPY.
- An OPT-IN parameter gating a SECURITY behaviour is OFF everywhere until a `lib/` caller passes it —
  grep the name in `lib/` and `test/` separately; "test-only hits" IS the finding.
- **LIVE-PATH CHECK, before writing any test for a bug fix**: grep the call chain from the view down to
  the write and confirm the fixed method is ON it — a fix on a parallel facade with no `lib/` callers
  ships nothing. A tested caller + a tested callee ≠ a tested seam.
- An optional nullable callback seam is invisible when every harness omits it — grep the seam's name
  across `test/`; zero hits IS the finding. **Hits are not the answer either: split them by LAYER** —
  all hits inside the widget's own suite means the view that WIRES it is unpinned, and deleting the
  production lines that pass it leaves every suite green with the feature absent from the app. A
  callback seam owes one test at the CALL SITE'S layer (BUT-1904).
- A new error/message seam is only as good as its READERS — a caller that awaits then shows success
  unconditionally means the message is never shown or cleared.
- Enumerate optimistic-rollback siblings by SHAPE (catch blocks restoring local state, `return
  false`), not the ticket's wording.
- When a data-loss ticket ships root cause + safety gate, the gate gets tests and the root cause gets
  none — grep the root-cause CLASS across `test/`. The third untested layer is usually the VIEW's
  outcome→message branch: assert the INVARIANT, be CHANNEL-AGNOSTIC.
- A "reads live state, not the cache" contract is only tested if the fixture makes the two DIFFER.
- An atomicity fix is tested at the layer OWNING atomicity, unreachable on the fake — a
  transaction-runner typedef seam is legitimate for platform codes but seams out the RUNNER, not the
  transaction; pair with an emulator-lane test.
- A permission guard on ONE method of a pair must be checked on its sibling — a callback-based API is
  the EASIER bypass. An attribution-field fix's sweep must include MODEL FACTORIES.
- Converting a per-item write to a per-item TRANSACTION makes existing `Future.wait` fan-outs over the
  SAME document pathological — grep callers first.
- A shared cache reused by a STRICTER new reader launders the weakest writer's output — enumerate
  every writer into the cache.
- A `didChangeDependencies` retry on a widget that renders `SizedBox.shrink()` on failure is DEAD —
  the early return happens before any `Theme.of`, so only a REMOUNT recovers.

### One-off gotchas, Windows/runner notes, and the revert-probe technique
- **An overflow probe MUST mount `AppTheme.lightTheme`** — the bare `MaterialApp`'s smaller default
  typography can hide a real overflow. Pin with SYNTHETIC tall content, never real ARB copy.
  `expect(takeException(), isNull)` is ALSO satisfied by a tile that rendered nothing, so co-assert the
  content under test is present — **and that co-assert must reach the DIMENSION the geometry depends
  on, not the container type** (`find.byType(<Row>)` is satisfied by a one-item row; assert the CHILD
  COUNT). A ladder that SKIPS cases per fixture is honest only if the skipped ones are MEASURED;
  register them as NAMED `skip:` (the runner prints the name every run), never a `continue`. Two
  residuals survive: the co-assert closes only "the ADDED content vanished", and a named skip goes
  stale GREEN the day the residual is fixed (BUT-1895/1911).
- **A SCROLLABLE ancestor makes the whole overflow class structurally unfailable** — inside a
  `SingleChildScrollView` the child gets unbounded height, so no content can overflow and
  `takeException(), isNull` is green at any size. It still kills a fixed-slice mutant, so keep the
  tests — but a group NAMED "the week fits" then asserts something nothing measures. Read
  `ScrollableState.position.maxScrollExtent` before writing "fits" (a `> 0` IS the finding), and
  strike the claim rather than re-scope it (BUT-1971).
- A page-size guard is only testable on a TALL surface (`tester.view.physicalSize = Size(800,14000)`,
  dpr 1.0) — a short surface auto-scrolls and hides item 0.
- A semantics assertion must be bracketed with `ensureSemantics()`/`handle.dispose()`; on a tooltip'd
  button match with `RegExp`, for the concatenation reason in the Vacuity section.
- Real `.xlsx` stores text via shared-strings (`t="s"`), not `inlineStr`. A `TimeoutException` with 0
  tests run is compile-bound (~12 min shared compile), not hung — split invocation per file.
- **THE PROBE LADDER, cheapest first**: (1) analytic — make the two sources DIFFERENT literals so a
  revert can't coincide with expected; (2) SCRATCHPAD replica via `dart.bat
  --packages=<repo>/.dart_tool/package_config.json` (no repo writes, immune to parallel sessions);
  (3) `test/`-side replica (`_zz_probe_test.dart`, deleted after); (4) mutate the INJECTION, not
  `lib/`; (5) only then a real `lib/` revert.
- **Writing a mutant into `lib/`/`functions/src` is REFUSED by the auto-mode classifier (content-, not
  command-sensitive)** — the Edit applies silently and the NEXT run is refused. On a dirty file: `cp
  -p` first, restore via reverse Edit, `cmp`/md5 verify. On a clean file: Edit-mutate, restore with
  `git checkout --`, verify via `git status`/`diff --stat` (not md5 — CRLF on checkout differs).
- **Revert-probe mechanics**: copy to scratch, string-replace the fix OUT, confirm EXACTLY the expected
  tests go red, restore + `cmp`. Assert the search text occurs EXACTLY ONCE before writing — doubles as
  a tree-motion detector. Do the cycle in ONE Bash call, script reading OLD/NEW text from FILES; on
  Windows read/replace/WRITE IN BINARY. (This is the one place a loop is allowed — see the
  green/red asymmetry bullet for why mutant BATTERIES must not be looped.)
- A WHOLE-CLASS replica scales this: copy class + suite to the SESSION SCRATCHPAD (not `test/`),
  rename, repoint the import — the only route when the `lib/` file is STAGED or edits are forbidden.
  Run the unmutated copy as control first.
- READ THE MUTATED LINE BACK before believing a red count — a shell heredoc can mangle backslashes
  silently. Write probes with the Write tool, raw Dart strings, never a bash heredoc. Never pipe a
  mutation driver into `head` (SIGPIPE kills its own cleanup).
- A probe file lives in scratch, not `test/` — a `// delete after` header is not a deletion. Close
  every round with `git status --porcelain`.
- When the test reads a FILE PATH (registry lints, declared-index asserts), the mutant is a GIT
  REVISION — `git show HEAD:<path> > scratch/`, run the walk against both. The only probe available
  when the "fix" is a deletion.
- A deletion mutant inside a fluent chain doesn't compile — substitute an always-true equivalent
  (`.where('name', isNull:false)`).
- A generated file in a diff is verified by re-running its generator, byte-compared, with the output's
  mtime moving while inputs don't (a byte match proves nothing if the generator silently skipped
  files).
- A one-character change inside a string literal can't be reviewed from `git diff` — `od -c` or `git
  show HEAD:` it. Byte-form grep false-negatives under UTF-8: use the codepoint form `grep -nP
  '\x{F8FF}'`, a Python sweep, or `cat -A`.
- **A new grep guard in `lefthook.yml` needs one path-handling probe** — it renders `{staged_files}`
  REPO-RELATIVE, so an anchor past a `path:line:` prefix false-fails on a Windows absolute path
  (`C:/…` splits at the drive colon); anchor the LAST `:<digits>:`. A guard wired only pre-commit is
  bypassed by `LEFTHOOK_EXCLUDE` or a merge. **The ONE-FILE case is its own probe**: grep OMITS the
  filename when handed exactly one FILE, so a `path:line:` parser takes its malformed-input branch and
  the baseline is never consulted. An EXIT-CODE-ONLY fixture suite structurally cannot see that. Probe
  any guard fix by running the guard's OWN fixture suite against `git show HEAD:<script>`; identical
  pass counts IS the finding, and the killer fixture INVERTS the expected code (BUT-1904).

### Firestore-rules `.ts` suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify`/`hasRequiredFields`
  list needs a test PER FIELD.
- A failure-only update suite can be silently over-restrictive — pair denials with an `assertSucceeds`
  on a mutable field.
- The emulator persists docs ACROSS invocations — suffix create-test ids with a per-run
  `Date.now().toString(36)`, or a fixed-id create silently becomes an update.
- Hand-rolled `npx ts-node` runners against `127.0.0.1:8080` time out without the emulator running
  first; `npx tsc --noEmit` DOES typecheck `src/__tests__` — a free non-emulator check on a rules suite
  you can't run.
- **A client-side filter test on the fake says NOTHING about whether the SERVER accepts that query** —
  rules refuse a whole QUERY when any candidate doc fails the read rule. A membership-filtered read
  owes THREE assertions: filtered-ALLOW (SDK's own spelling, with a non-empty premise check);
  unfiltered-DENY (delta is only the missing `where()`); and filtered-ALLOW-but-empty for a member of
  nothing.
