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
- **This file has drifted back three times (35K→432K 2026-07-24; 262K→112K 2026-08-09;
  162K→here 2026-08-17) the same way: not dated entries (never used here) but individual
  principles absorbing worked-example detail instead of citing the ticket and archiving the
  detail.** When adding an example, ask if the sentence stands without it; if yes, archive
  the example and cite the ticket.
- **Budget ~25,000 chars** — a smell, not the control; the rule above is. Every principle
  the pre-2026-08-17 file carried survives here, merged, or verbatim in the archive's
  2026-08-17 snapshot entry.
- **The real trigger is the Read tool, not char count** — past ~250,000 chars Step 0
  silently degrades to grepping. Next time this approaches that, SPLIT `Vacuity patterns`
  out rather than compress again; it's been the largest section twice running.

## When to consult the archive

Grep it when a principle here is too terse to act on and you need the worked example (test
code, failure output); an unfamiliar mocktail/Firestore-fake discrepancy not named below; an
emulator-lane setup failure (full runbooks live there); a ticket's or area's full review
history (grep the BUT-#### or area name); a principle citing "verified non-vacuous by X" and
you want the revert-probe that proved it; or this file itself reads too compressed — the
2026-08-17 entry holds the prior version of this whole file, byte-for-byte.

---

## Principles

### Re-review economics (re-reviewing "after automated fixes")
- **Confirm bytes actually MOVED before re-reviewing** — hash + `wc -l` per file, both ends
  of the round; mtime lies. `git diff <path>` empty ≠ unmoved (staged shows only in `git
  diff HEAD`/`git show :<path>`). Hash a suite's runtime INPUT files too (a source-text
  guard reading `firestore.rules`), not just changed ones.
- **The brief is pinned to a hash and expires with it** — a `sed -n` printing different
  content at the same lines means re-Read and rebuild the mutant list; skip re-running
  mutants already measured on an unchanged hash.
- **The motion check is the map: moved PRODUCTION ∩ unmoved SUITES = unasserted by
  construction** — `git show :<path>` on such a file is a free pre-fix mutant.
- **Fix loop consumes Critical/High only** — an all-Low/Medium re-review never changes.
  Apply zero-risk test-only fixes yourself; never edit production in a review pass.
- **"Duplicate test" is measurable**: mutate the guarded expression, delete only a strict
  subset kill set THROUGH THE SAME SEAM. Exceptions: reaches the sole fail-closed lookup via
  a different seam, or is another test's CONTROL. Grade two suites for one class by what
  only ONE holds — the tidy mirror suite is often the sweep; the "stale duplicate" can carry
  the security/a11y groups nobody rewrote. Never retire by path convention alone.
- **A live parallel session poisons a battery both ways**: their edits are FALSE KILLS in
  your run (attribute by test name vs mutant blast radius, re-hash before verdict); an
  identical md5 + fresh mtime is THEIR mutate-and-restore, and your `finally` can clobber
  their in-flight write — prefer a production-free `test/`-side probe beside a live session.
- **The tree moves DURING your round** — re-read before filing (a stale stack-trace line
  number is the cheapest tell); back up/restore your own probes in ONE Bash call.
- **A mutate→run→restore→mutate LOOP can be served the PREVIOUS mutant's kernel** — mutate
  and restore inside one second and `flutter test` reuses a stale incremental build, so the
  run reports failures belonging to the mutant before it. Tell: a red test the mutant cannot
  reach (a fixture that never enters the mutated branch). Never loop probes in one Bash call;
  run each in its own call and RE-RUN any surprising red alone before filing it (BUT-1897:
  two of four probe results were phantom, both reproduced clean on re-run).
- **When the question is only "is this line REACHED at all", coverage answers it with no
  `lib/` write** — `flutter test --coverage --coverage-path=<scratchpad>/lcov.info <suites>`,
  then `awk '/^SF:.*<file>/,/^end_of_record/' | grep '^DA:<line>,'`; a `0` is the finding.
  No backup, no restore, no parallel-session clobber, no auto-mode classifier, ~10s. Reach
  for a mutant only for the harder question ("does any test DISCRIMINATE this expression"),
  since a reached line can still be unasserted (BUT-1831: a private read seam's success arm
  read `DA:244,0` while its two failure arms were pinned).
- **"Only `dart format`" is provable, not assumed**: walk `git cat-file --batch-all-objects`,
  compare whitespace-stripped bytes blob-to-blob (not blob-to-disk — CRLF differs by one
  byte/line). The formatter can insert a trailing comma, so fall back to raw `diff` if a
  token-signature match misses a genuine format-only file.
- **"Staging — resolved" isn't resolved until `git show :<path>` diff is empty** — an index
  can sit behind graded bytes across rounds; close every round naming unstaged hunks. Close
  the POSITIVE direction mechanically at verdict time: `git diff --numstat` every reviewed
  path (0 lines = index matches worktree) in one call, so the verdict names the copy the
  parent will commit. **Two ways that check answers "clean" while proving nothing.** (1) A
  path-scoped git command run from the WRONG cwd prints nothing, byte-identical to "no
  differences" — every verification call gets an explicit `cd` and an echoed `pwd`, because
  this one fails SILENTLY into the reassuring answer. (2) `git status --porcelain` and `git
  diff` genuinely DISAGREE: status prints `MM` off a stale stat cache (mtime touched by a
  formatter/hook, content unchanged) while `git diff` is empty. Neither is the tiebreaker —
  compare `git ls-files -s <f>`'s blob to `git hash-object <f>`; `update-index --refresh`
  then makes status agree (BUT-1910).
- **An analyze finding contradicting the source you just read, or a suite passing against
  code analyze says can't compile, means re-md5sum BOTH files** — a timestamp-preserving
  restore can leave stale bytes running.
- **"Would the RULES allow this?" — just run it**: a throwaway `_zz_probe_*.ts` under `npx
  firebase emulators:exec --only firestore --project demo-test` names the rule line in ~90s;
  add a control arm.
- When a parallel session lands a test for the same guard, delete yours with a pointer
  comment. A measured claim in a comment is one command to verify — agreement across files
  often just means one was copied. **A reported REMOVAL or REWORD is verified by grepping the
  OLD STRING in the worktree AND `git show :<path>` AT VERDICT TIME, never by the motion
  check** — a file that moved for the round's OTHER edits passes every hash test with that one
  absent (twice measured: a false sentence outliving the production edit, and a two-repair
  round that landed the blocking fix and silently dropped the non-blocking reword, reported as
  done), and a parallel session can land the removal between two of your own greps: say which COPY the
  finding is against, since the parent commits the INDEX (BUT-1897). **Then grade the
  REPLACEMENT as a fresh claim** — a strike that swaps a measured count for a quantifier
  ("six call sites" → "from every list and detail surface") is unmeasured by construction, and
  the falsifier is usually an explicit exception in the same code (`assert(!readOnly, 'edit
  must be unreachable')`). The repair is to STRIKE the quantifier, never to re-measure it
  (BUT-1910).

### Project-specific test infrastructure (full detail in `testing-specialist.md`)
- Production ServiceLocator bridge: `production.ServiceLocator.initialize(DIContainer())`
  in `setUpAll`; both ServiceLocator classes share one `GetIt.instance`.
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — pass it.
- Debounced VM: `fakeAsync` + `async.elapse(300ms)`; `executeDebounced` fires 3
  notifications. `test/views/` is journey-test territory (owned by `e2e-test-specialist`).
- **A repoint to `collectionGroup(...)` is HALF a fix** — needs a `fieldOverride` with
  `queryScope: COLLECTION_GROUP` or FAILED_PRECONDITIONs; `deploy --force` prunes anything
  absent from `firestore.indexes.json`. Suite needs three arms (override exists at group
  scope, exact set survives delete+add, source still spells the field). Register the npm
  `test:*` script in the same edit.
- Source-text assertion suites must strip comments first, or a bare `includes` stays green
  after the setting is deleted; probe non-vacuity with a STRING mutant, never a file mutant.
- **A mocktail matcher goes vacuous only when a named arg's value stops equalling its
  DEFAULT** — `verifyNever` is the dangerous direction: a non-default named param can never
  match the omitted-param form, so the guard is UNFAILABLE. Spell every named param.
- A poll-until-condition loop discriminates only if the assertion sits AFTER it, polling the
  LAST observable step. `retry:true` owes a reachability read of `isCascadeEventExpired` as
  the handler's FIRST statement, or a deref above it escapes the bound.

### Coverage decisions
Codecov: 60% project / 70% new patches / 2% drop tolerance — floors, decided 55% project
(2026-07-11); don't file generic "raise coverage" tickets.
- **Open a review by grepping each NEW TOKEN into a token→files table** (~30s). Zero files
  IS the finding; hits only in an extracted class's own suite means the composing line in
  the CALLER's suite is still unproven (BUT-1838: a `copyWith` carry, a DTO write asymmetry,
  a query filter — three sibling suites untouched).
- When a fix SPLITS one write/event across destinations, or teaches a method a new
  side-field, grep every WRITER/reader's OWN SUITE (not `lib/`) — the list grows mid-round.
- **A figure measured OUTSIDE the repo (corpus gold, an eval sweep) has no test holding it,
  and manufacturing a fixture is worse than saying so plainly** — grep the marker's own FIELD
  NAME across `test/`; zero hits IS the answer, and the in-repo fixture corpus usually does
  not model the graded axis at all. The review a test cannot do is ARITHMETIC ACROSS THE
  COPIES: recompute every stated delta (before + added − relabelled) against the totals in
  each file quoting them; prose like "confirmed all 14, re-labelled one and added nine" can
  admit two readings whose splits differ while the total agrees. Grade a stated COUNTERFACTUAL
  the same way — "had the PAIR gone the other way it would read N" prices an UNMEASURED state
  when only ONE label was ever in play; the giveaway is the paragraph's own header saying
  "sensitive to ONE label". A `tools/` script with `main()` + private helpers is untestable
  by construction — an EXTRACTION ticket, not a missing test. But a hardcoded count in its own
  printed BANNER is neither: delete the literal and interpolate the runtime tally, which makes
  the drift class impossible instead of watched (a test would be a tautology afterwards). It
  misreports only on the arm that computes nothing — check for a short-circuited
  `if (flag && probe(x))` leaving the DEFAULT arm with no number to interpolate. **HOISTING
  that probe out of the short-circuit falsifies every doc sentence explaining why the default
  arm was safe ("never reads X") — grep the CONCEPT, not the field name; the clause that
  survives a sweep is the one spelling it in prose. A DATED `lessons.md` record is exempt only for FIGURES a later re-grade
  falsifies; a mechanism claim that was FALSE WHEN WRITTEN gets corrected there like
  anywhere else, or the batch ships two answers to one question.** A hoisted tally is
  population-independent, so
  `gateCounter == tally` holds ONLY on the gated arm — verify the OTHER arm's banner reads the
  tally, not the zero counter. **Then grep the file for the numbers the fix says it removed:
  "this file now contains NO count" survived a round as the stated justification for dropping
  the tool from a hand-carrier list, while a ticket-scoped historical count sat in its header.
  That count is legitimately exempt (anchored to a past grading, it cannot drift) — the defect
  is the unqualified absolute, so the fix is "no count of the CURRENT set", not a deletion.
  **That correction then becomes a STANDING INVARIANT THE SAME BATCH VIOLATES**: a later
  comment-only round re-typed the live tally (`fragment+tail`, the value the census class's
  own doc says to never type) into a NEW comment far from the promise. So re-grep the current-set VALUE, not the phrase, every round of a
  multi-round batch; the tell is a figure carrying no ticket and no date, since the carve-out
  saves an attributed-and-superseded figure and nothing else. Same round, same file: a
  comment advising "check X before quoting" while itself quoting an X derivable from nothing
  the tool prints — state the RULE and how you'd tell, never the current reading.
  **Deleting the stale figure is only HALF that repair: name what the run CANNOT print, or
  the next writer re-derives it and re-types it.** But grade an "unprintable" claim against
  EVERY printed artifact, not the two counters the sentence itself names: the ENTRY-scoped
  tally and the POPULATION-scoped page count genuinely fail to reconcile, yet a THIRD table
  (per-page movement deltas) settles half the claim — deltas sum to the tally, and an
  undercount cannot be masked because each page contributes at most once. Confirming the
  broad version on the named pair's merits alone is how one reviewer said "nothing printed
  can settle it" while another correctly found the table that does. An ENUMERATING doc ("four
  states, not three") is the same class of claim: a returning helper's list of named values
  + sentinel drops the PASS-THROUGH state (any other value returned VERBATIM), which is the
  state the sentinel exists to expose and the one a call site's `else { /* absent */ }`
  silently eats. Grade a private `tools/` helper's return contract by RUNNING a scratchpad
  replica of the function AND its caller's classification chain over the full input lattice
  (13 cases, ~30s) — reading is how the doc came out one state short.**
  **A new declaration inserted above a function silently RE-PARENTS the doc comment that sat
  there** — the const gets a doc describing the function, the function gets none, and the
  orphaned first line usually also states the return contract the new declaration just
  widened. `git show HEAD:<f> | grep -B6` every symbol the change ADDS. A guard for MALFORMED
  external input (unrecognised-enum counter + warning) is watched, not impossible, so the
  tautology argument above does NOT cover it; it owes no test because the helper is private
  AND reachable only through a `main()` resolving its data root from the ENVIRONMENT —
  subprocess-only, NOT "untestable by construction". Say that: the extraction is ~10 lines
  into `tools/corpus/`, where `test/corpus/corpus_multi_layout_test.dart` already builds a
  synthetic corpus in a temp dir and constructs `CorpusPaths(tmp)` directly. Probe BOTH
  disjuncts of a `v is! String || v.isEmpty` sentinel — a wrong-TYPE injection leaves the
  empty-string half deletable-green, and the guard's own comment names both shapes. A
  sentinel added to a returning helper changes NO count when it is chosen for values the old
  code already mapped to the same downstream branch — prove that by equality of the two
  return tables, not by a probe. Its discriminating evidence is then the new OBSERVABLE it
  unlocks (a WARNING naming the offending path), which HEAD cannot emit — never a count,
  because every count in sight moves at HEAD too. **A comment-only INSERT between two existing
  sentences inherits BOTH neighbours' references**: a bare "the nine" lands with no antecedent
  in that file, and the retraction it was pushed above ("wrong on both examples it named") now
  trails a pair the retraction never meant. Grade an insertion's SEAMS, not only its claims —
  and when two independently-derived figures collide numerically (9 band TAILS vs 9 gold
  TOKENS), the conflation lands in the carrier that never says what the first nine counts, even
  though the sibling file already carries the disambiguator. (BUT-1847)
- **A comment's POSITIONAL safety argument ("the token must be the very first thing in the
  string") is graded against every ITERATION of the loop that consumes it** — a head-parser
  that peels twice exempts slot 2 too, so the argument is falsified by the file's own
  neighbouring comment ("peeled TWICE, because V8 nests them"). Scratchpad replica over the
  input lattice, 30s; the remedy is a qualifier, not code. Grade a QUANTIFIER in the same
  file by the population it ranges over and by EXPOSURE — "most of this app's exception names
  sit in the 20-28 window" is 12/31 by name, ~62% weighted by throw site; the durable repair
  is the most-THROWN spelling with the measured pair (90 family sites of 168 constructions).
  One `grep -c` is NOT the verifier and saying so was itself the error repeated: the naive
  count reads 173, because it also catches switch-PATTERN arms (`PermissionDeniedException()
  =>` in `shopping_failure_message.dart`) and a substring sibling (`TagConfigValidationException`).
  Require a `throw|return|=>` prefix, and say "family" — 89 of the 90 are the base class and
  one is `StaleAccessControlBaseException`, whose own label is a different 31 characters.
  **Then check the repaired bound is PINNED, because a widened qualifier is a NEW claim with
  no test**: mutating the loop 2→4 left all 21 green while 2→1 reddened exactly one, so the
  suite pins "at least two slots" and nothing pins "at most two" — the exemption can silently
  grow to slot 3+. The killer fixture is a digit-free 20-28 LETTER token, capital-initial,
  in the slot just past the last legitimate label (BUT-1897).
- **A collection's DOCUMENT-ID SCHEME change (deterministic→auto-id) breaks every reader
  that addresses/dedupes by it, invisibly** — grade writers keyed on `doc(x)`, mergers doing
  `byId[doc.id]=doc` (silent double-render), and field-keyed cascades (can lose their
  address if spellings never matched).
- A cross-language literal contract (a CF-written marker Dart matches) is usually pinned
  consumer-side only — a doc comment claiming sync is not a test; grep for the enforcing one.
- **"X was REPOINTED" — run X's PRE-EXISTING suite even if the ticket omits it.** It's
  written against the retired behaviour and usually passes VACUOUSLY (seam uncalled, fixture
  unseeded) rather than failing. Rewrite with a fixture where old/new DISAGREE, seed the
  new, assert the retired seam unreached (BUT-1838: 6/6 red after, 0 before).
- A capped/OR'd flag over N sources needs its recall control rebuilt when a source is
  added/removed (BUT-1801 43/43 survived; BUT-1832 9/9) — grade any capped section by the
  below/at/over trio.
- A fan-out loop + accumulator is one untested input whenever every fixture is a singleton
  — close at the outer layer with 2-cut+1-retained via a capture recorder, never
  `verifyNever` beside a positive. Dead work (unread map, unused helper) reads as coverage —
  file a deletion ticket.
- Two branches sharing one guarded block need separate inputs; one variable at N call sites
  needs proof PER SITE (`any(named:)` survives mutants on the other sites). A comment naming
  two shapes one guard catches is two claims — the second is often unreachable-but-true;
  reachability is a producer question.
- **Fixture-shape family**: the fixture's own shape answers for the code. An accumulator off
  `.first` hides its loop unless the first item is interior on every axis; enumerate every
  field production READS, override each independently.
- A repository suite where every fixture lives in ONE scope can't see its scoping `where` —
  and habitually leaves inherited CRUD (`read`, `readAll`, `watchAll`) untested though it
  skips every filter the finders apply.
- A defensive DECODE helper's null branch needs the ABSENCE mutated, not the value, plus a
  wrong-TYPE row. A deterministic composite id + body-vs-path check makes "stored==payload"
  checks TAUTOLOGIES — isolate the one conjunct that can still decide.
- **A fail-loud parser deriving ownership from the STORED BODY is protective on read, an
  Art. 17 defect on delete** — the forged row becomes the one doc its owner can't erase;
  decide erasure from the composite-id PATH, not the body.
- **Guard-chain subsumption, three directions**: BACKWARD (an earlier guard pinned by
  nothing because a later one refuses everything it does), FORWARD (fixture must clear
  every downstream refusal WITH SLACK, never at an exact tie), SIDEWAYS (a new guard can
  unpin an older filter downstream). Total subsumption = comment, never a test. Run "which
  mutants killed nothing" and its mirror once per file.
- A guard inside a loop has a POSITION (before/after the accumulator update); one above a
  pre-existing early-return is blind to every fixture that falls through — usually the
  worst leak (raw content unfiltered).
- **A dropdown widened to keep an off-vocabulary value needs FOUR fixtures**: off-list-
  untouched; pick-something-then-pick-back (only killer of keying the list off current vs
  stored selection); empty-stored; literal vocabulary pin (BUT-1858).
- **A fix that DELETES dead code is mutation-dead by construction** — reverting it restores
  behaviour identical to the fix, so no test can redden. Only the FORWARD direction is
  pinnable ("the field must not come back"); say that in the name, and never also assert the
  VALUE the deleted code could not produce — that half is a tautology (BUT-1873).
- **A `StyledInput` with `keyboardType: TextInputType.number` silently gets
  `FilteringTextInputFormatter.digitsOnly`**, so any `replaceAll(',', '.')` decimal parse
  below it is DEAD and "1,5" reaches the model as 15. A suite over a numeric field that never
  types a DECIMAL cannot see it — measured, shopping add/edit dialogs, 2026-08-17.
- A flag selecting between two values is pinned by both arms over one fixture with
  observably different values — no production mutant needed. A nullable override deriving
  its default from a nullable payload owes a third arm: the EMPTY (non-null) payload.
- "Declines/falls back" needs `equals([input])`, not `hasLength` — catches truncation. A
  test named after an input must assert that input's VALUE.
- "X does NOT happen" needs proof the code reached where X could — "no write" can mean
  skipped OR identical values; count writes, positive control same test.
- A guard skipping a per-parent subcollection probe is unfailable when the probed doc
  doesn't exist — repair with a TRAP row at a path production never writes, spelled with
  production CONSTANTS (a literal drifts dead on a rename).
- **A write the RULES refuse is 100% green under mocks, and its TWINS stay refused — grep
  the file, not the ticket.** Every field the write touches: grep `firestore.rules` for a
  deny; each surviving twin owes a comment naming the rule LINE. A comment quoting a
  deny-list beside a round-trip assertion names TWO populations that legitimately differ —
  the RULE's key list and the SERIALIZER's emitted set — so "every one of those keys is
  re-sent" is a measured claim to check against the DTO, not a restatement. The keys a
  client never writes are pinned by an ABSENCE test at the serializer, and a module-level
  copy is a strict duplicate through the same function (BUT-1831: `groupId`/`memberSince`).
- A source-text guard pinning `keys().hasOnly([...])` has five vacuity seams: widest
  payload; complete writer set (forever); anchor sentinel checked against the NEXT match,
  not global uniqueness; blind to the `hasAll` mirror; can't see a SWAP (delete+add, count
  unchanged). Prove by neutralising the call and watching the WRONG-LIST message (BUT-1830).
- The client-side twin: an injected `Future<bool> Function(T)` stubbed true can't show what
  PRODUCTION binds actually rejects — resolve the argument to its terminal implementation,
  owed once per SPRINT (a feature can ship end-to-end while every write stays refused).
- A CF split into pure core + DI'd orchestrator ships the orchestrator untested — a `noop`
  verdict can't see "writes no second message"; the missing fixture is always the
  outsider-vs-member split the gate eats first.
- A guard replicated across sibling fields is tested on one field only — enumerate fields,
  one fixture per field per branch. **A multi-alternative REGEX is that same shape**: pin one
  fixture per alternative its own doc comment enumerates, or deleting a branch reddens
  nothing. BUT-1897's frame splitter named three stack spellings (`#0 `, V8 `at `,
  `fn@url:line:col`) and shipped with the V8 one — the majority browser — unpinned, because
  the two tests written were for the two spellings the ticket's prose talked about (closed
  2026-08-20). Grade the whole family in ONE cheap run: a scratchpad replica of the
  consuming function plus a MATRIX of full-regex × one-alternative-deleted variants over
  every fixture — no `lib/` write, so the auto-mode classifier never fires, and the
  alternative each fixture uniquely kills is read straight off the table. Two things only
  the matrix shows: an alternative can be killed by TWO fixtures (fine) or by NONE (the
  finding), and in a MASK-head/PRESERVE-frames splitter only the PRESERVE assertion pins the
  split — the privacy assertion beside it is satisfied under every split mutant (a
  no-match falls back to masking EVERYTHING), so it is a control against un-masking, not
  evidence the split works. `hasRequiredFields` checks presence+non-null ONLY, never
  TYPE — every shape check needs a companion `is! Map`/`is! List` row. **Same for a guard
  replicated across sibling CLASSES** (one masking call in six `toString()`s): mutate PER
  CLASS, because a class whose output is already safe for another reason is deletable-green
  — `ValidationException` prints `Value: <Type>` and its only masking-adjacent assertion is
  `isNot(contains('@'))`, which the type-description satisfies alone (BUT-1897). A stated
  red count must name its SCOPE: "removing the mask reddened 4" was true for ONE class and
  8 for the family, and the smaller number reads as "the other five are unpinned".
- **A source-scanning guard enforces its REGEX, not its TITLE — cite what it matches, never
  what it is called.** `architecture_test.dart`'s "no raw user ids in AppLogger calls"
  matches `$userId`/`$uid` only, so `$conversationId` walks past it in 9+ `lib/` files while
  literally being two raw uids (`direct_<a>_<b>`). Before leaning on a guard as a
  contract, read its pattern and name the aliases of the guarded DATA that the pattern
  cannot see; a guard whose own doc comment lists "known gaps" is naming variables, and the
  gap that matters is usually a different NAME for the same secret (BUT-1897, 2026-08-20).
- **A comment naming WHICH test guards an ORDERING dependency is graded by performing the
  reorder, never by reading the suite — and the decoy is systematic**: a test pinning the same
  literal through the HELPER the mutated caller delegates to is invariant BY CONSTRUCTION, so
  it reads like the closest guard and can never redden. Route-check each candidate (does the
  fixture enter the mutated seam?), then check the surviving test's fixtures one by one — only
  the REALISTIC-length one usually straddles the swap. Swapping `maskIdentifiers`' two rules:
  5 red across 4 suites, all through `sanitizeForCrashlyticsForTesting`; both `direct_#<hash>`
  literal pins stayed green (BUT-1897, 2026-08-20). **The comment REPAIRING that attribution
  then failed on SCOPE, the same day**: "every test in this group calls the helper directly,
  never the chokepoint" named as its own counterexample a test 70 lines below — inside that
  same `group(`. Scope the sentence to the FIXTURE it sits beside, and `grep -n '^  group('`
  the counterexample's line before writing "in this group"; the guard-bearing test is the
  file's ONLY caller of the mutated seam, so it is always one grep away (BUT-1897, 2026-08-21).
- The in-memory version DELETES data instead of failing to write it (a model field + N
  field-by-field rebuilds) — `copyWith` is the durable fix, it can't forget what it never
  enumerates; assert an UNTOUCHED member survives.
- Notification `when(...)` stubs are not coverage (the wrapper swallows everything incl.
  `MissingStubError`) — only `verify(...).called(n)` + `verifyNever` on the retained member.
- A test passing an OPTIONAL override bypasses the changed default branch — grep every call
  site. Worst case: a remote KILL SWITCH override present in every test by construction, so
  neither the real lookup nor the defaults entry runs anywhere.
- A defensive bound on an injected collaborator is mutation-dead when every fake answers
  immediately — `grep 'fakeAsync\|Completer\|TimeoutException'` zero hits IS the finding. A
  new conjunct beside an existing gate is born mutation-dead without a fixture passing the
  OLD gate and failing ONLY the new one.
- The CONDITIONAL-IMPORT SEAM: `flutter test` compiles the native branch into every unit
  test, web stub into none — the shipping impl runs in zero tests if every test injects a
  fake through the `_testX` seam. Same for `Platform.isX`: guard and no-guard agree on every
  observable that doesn't count calls.
- A "no unit test can see this" comment is a claim — split the untestable PREMISE (rules
  denial) from the testable BEHAVIOUR (the catch is not).
- A COPY test stopping at the confirmation dialog pins the words, not the branch — the
  decision usually lives on a surface it never renders (both snackbars, title, body).
- `MaterialApp(routes:{...})` never reads `settings.arguments` — nav tests on it pin the
  SHAPE vacuously; push through `onGenerateRoute` mirroring the real decode.
- Two l10n keys with the SAME string make `find.text` unfalsifiable — grep the ARB for EXACT
  value equality, since `find.text` is whole-`Text.data` equality, never substring. So a
  message CONTAINING an action label as a trailing sentence never made the tap ambiguous, and
  "shortening it disambiguates the tap" is a false premise to accept or file (BUT-1831).
- "Returns null on X" needs a positive control in the same fixture — where every layer
  swallows to null, null is the NORMAL shape of denied/offline/deleted, so grep the suite
  for `async => null` on the loader; zero hits IS the finding.
- Last-wins/precedence tests need the LOSER asserted absent, with inputs where the wrong
  answer genuinely differs. A partition/drift-guard test from the SAME curated list the impl
  was written from cannot fail — probe with a real sibling name.
- Coalescing-across-calls: a fixture whose injected reader returns a CONSTANT can't see it —
  model the read, drive N calls on an advancing clock. A parameterised loop over failure
  codes proves one leg N times if the fixture starts EMPTY — need a fixture failing the fast
  path's own predicate.
- A predicate's SCOPE guard (suffix-not-substring) ships untested when the illustrating
  fixture sits outside its vocabulary — need the positive half PLUS the guarded shape.
- Round-trips must drive the REAL serializer, never `copyWith`; a DateTime sentinel needs
  zone normalisation checked via round trip.
- A two-sided guard (å/ä/ö boundaries) needs a discriminator PER SIDE and a recall control on
  tightening — classify by which side the diacritic sits, and print each candidate pattern
  over all three fixture histories (old-matched, new-matched, never-matched) before writing
  rationale. Boundary shape is decided by the
  CONSUMER, not tidiness — never harmonise two deliberately different guards in this repo.
- A hand-built narrow write payload needs BOTH the carried and omitted keys pinned — for the
  omission, drive a mutator that moves the excluded key as its OWNER.
- Firestore whole-number aggregates store as `int` — `as double?` throws and silently drops
  the row. A guard spanning TWO user-facing shapes ships pinned on one — the diff's own
  "accepted consequence" sentence usually names the unpinned shape.

### Helpers that exist (grep before writing a new one)
| Helper | Path |
|---|---|
| `setupUnit()`, `teardownUnit()`, `setupUnitWithProductionLocator()` | `test/test_support/base_unit_test.dart` |
| `TestTimestampProvider`, matchers | `test/test_support/timestamp_test_helper.dart` |
| `useEmulatorLane`, `firestoreForLane()`, `clearLane()`, `emulatorOnlySkip` | `test/test_support/emulator_lane.dart` |
| `butleryGolden(...)` | `test/widget/golden/golden_helper.dart` |
| `createLocalizedTestApp(...)` | `test/infrastructure/helpers/widget_test_app.dart` |
| All production mocks | `test/infrastructure/mocks/production_mocks.dart` |
| Typed mock factory | `test/infrastructure/factories/mock_factory.dart` |
| `MockMenuService` (NOT in production_mocks.dart) | `test/infrastructure/mocks/service_mocks.dart` |

**`RecipeFactory.build` has NO `tagResult`/`tagOverrides` param; `RecipeBuilder` does.** Every
tagging-gated render (`recipe.tagResult != null` guards the card's allergen/dietary rows) is
UNREACHABLE from a factory-built fixture, so a test written on the factory passes vacuously
rather than failing to compile — that is exactly how BUT-1780 shipped "fixed" with no badge
ever on screen. Use `RecipeBuilder().withTagResult(...)` for anything badge- or tag-related.

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
| A NULL-VALUED KEY via `set(..., merge: true)` (incl. `batch`) | **Faithful, `containsKey` is real coverage.** Key present, value null, siblings preserved; null OVERWRITES a stored map. So "writer must emit key even when null" is testable at module level (verified 2026-08-13). |
| Query PREDICATE SHAPE, incl. `where('<map>.<uid>', isNull: false)` | **Exact.** Build the REAL repository over the fake; dotted keys, `isNull`, `arrayContains` all work. `isNotEqualTo: null` adds NO condition in the real SDK and makes the fake THROW — never accept a comment claiming map-path keys unsupported. |
| A negative "gets nothing" test | Mutation value only when the SUT doesn't swallow errors — behind a catch-all `return []` it's a recall control, and the positive test is the whole guard. |
| A per-ROW transactional write (doc id == uid) | Transaction wrapper is deletable-green by construction — the suite really pins the DOC-ID DERIVATION. Keep the two-actor test as CONTROL; put the permission half in the rules lane. |
| `FakeFirebaseFirestore.runTransaction` | NO-OP PASSTHROUGH, never proves atomicity — handler runs once, `SetOptions` dropped, `timeout`/`maxAttempts` ignored. Use a bare read-modify-write; a truly interleaved test fails on the fake, passes in production. |
| `test/integration` | Nothing in CI passes `--dart-define=USE_EMULATOR=true` over it — every lane test skips everywhere, never coverage. `flutter test` is plugin-less; the lane needs an `integration_test` project. Ticket it, don't "just add the flag." |
| `serverTimestamp()` in `batch.set(..., merge:true)` | Trips the fake on some shapes — never a valid `skip:`. Fix: `FieldValueFactoryPlatform.instance = MockFieldValueFactoryPlatform();` in `setUp`. |
| `permission-denied` | Fake can't fire it — skip only when the branch is a bare `if (e.code=='permission-denied') return null;` above a rethrow, no side effects. |
| `orderBy` field | Seeded fixture must include every field the `orderBy` reads — the fake silently drops docs missing it. |
| `collectionGroup` | Safe on the fake for index-free `.limit(N).get()` with no `where()`, and (^4.1.0+1) for plain equality. |

### Conscious-skip taxonomy
- Static-method orchestrator: skip only when ALL hold — ≤3 calls, no injection seam, each in
  its own try/catch, no branching beyond the catches.
- Compiler-enforced sync contract (renamed l10n/analytics constant fails gen-l10n/analyze
  first); pure-nav affordance (route constant is compile-checked).
- Nth surface adopting an already-proven predicate: prove via `git diff --staged
  --name-only` — no new surface if the pure-logic file is absent.
- `SemanticsService.announce` in a fire-and-forget handler is skippable UNTIL the view gains
  a DI seam — dated, not permanent. A comment-only diff owes no test IF the claim is already
  pinned by a fail-loud spy — verify, don't trust. But a comment-only CORRECTION owes a grep
  of the CORRECTED SENTENCE across `test/`: a covering suite's group header quotes production
  prose, so the false claim has a third copy there and the batch ships two answers to one
  question (BUT-1883 — "an unhydrated poll makes `closePoll` resolve to the first option" was
  still live in `message_query_module_test.dart` after both `lib/` copies were fixed;
  `_resolveWinner` returns null at zero votes).
- **A mask-at-the-throw fix owes NO test when nothing observes the message**: the string is
  caught in-method and handed to `AppLogger.error` as the ERROR OBJECT (only the MESSAGE
  arg is sanitized), the user-visible text is a generic fallback, and asserting
  `isNot(contains(id))` on that fallback is the classic type-description vacuity. Say so;
  the durable pin is a source lint in `test/architecture/`, not a fixture (BUT-1897,
  `ConversationsViewModel.leaveGroup` + `MessageDeletionModule`). Check "no production
  caller" yourself — it decides the verdict — and note that a residual-throw branch above
  `batchDeleteDocs` is unreachable on `FakeFirebaseFirestore`, whose deletes always succeed.
  **The skip INVERTS once the throwing class's own `toString()` interpolates the message** —
  `recordError` sends `exception.toString()` and the object crosses unsanitized, so a fixture
  IS owed, not a lint. Read that `toString()` before citing this bullet (BUT-1915).
- **A "sole guard"/KNOWN-GAPS comment is a CLAIM until a test enters that exact branch** —
  verify against the model's SERIALIZER, never read a rules subcollection match or a
  cascade's defensive sweep as evidence the client writes it. A rationale citing a backend
  propagator/cascade is two greps (collection constant, then the query field) and both
  usually fail.
- A pure removal of dead code owes no test when a repo-walking structural lint holds the
  invariant — verify the lint is byte-identical to HEAD and the pre-fix set had exactly ONE
  element.
- A behaviour-neutral respelling owes no test — earn that by MUTATION-COUNTING the existing
  suite, then fix the comment/header claim the respelling falsified. Before writing "the
  suite had nothing to say", grep `test/architecture/architecture_test.dart`: style bans
  (BUT-581 raw `?? ''`) ARE tests there, repo-walking source lints run in two CI workflows,
  with `tools/check_staged_arch_guards.sh` as the pre-commit twin. Behavioural suites cannot
  see a respelling by construction — that split is correct, not a gap.

### Vacuity patterns — the recurring ways a "passing" test proves nothing
The single most repeated finding across two months of review.
- **MASTER RULE: name every OTHER mechanism that could satisfy the assertion, then build the
  fixture where they DISAGREE. Every pattern below is an instance.**
- Circular determinism (calling the same pure function twice, or deriving expected from the
  const under test) — pin the literal OUTPUT.
- Sibling-branch short-circuit, BOTH polarities: for `if(A) return true; if(B) return
  true;`, check no fixture satisfies a branch other than the named one. MIRROR (AND-chain +
  `findsNothing`): a negative test naming ONE conjunct needs every OTHER conjunct
  SATISFIED, or the conjunct it names is deletable-green — assert the premise in the test
  itself (BUT-1869 "badges off" ran on a fixture WITH badges, so `.isEmpty` withheld the
  marker and the flag was never exercised).
- Fake-default-same-as-expected: use a sentinel no real caller would pass.
- **DESERIALIZER-DEFAULT vacuity**: a save-retrieve test asserting the parser's own
  `defaultValue` is unfailable — missing doc, dropped write, empty map all answer the same.
  Tell: a "returns defaults" sibling test with a byte-identical assertion list.
- **Production twin**: a "must not OVERWRITE" fixture holding the value the code would write
  anyway. Widest instance: an untouched-save test over `copyWith(f: _selection)` — only
  picked≠stored can see a dropped `f:` argument (BUT-1858 test 7).
- A NULLABILITY WIDENING (`T x=d`→`T? x=d`) trades a compile guarantee for a test — trace the
  `??` chain to what the mutant does downstream (a dropped initialiser can store a SILENTLY
  DERIVED value, not "no value").
- A collection-SHAPE assertion instead of the skipped element's VALUE (a Map can't hold a
  dup key, so "appears once" can't distinguish skip-vs-overwrite).
- **A guard wrapping [spacer + a child that self-collapses to `SizedBox.shrink()`] is pinned
  ONLY by `find.byType(<ChildWidget>)`** — the child-CONTENT assertion (badge, row item) is
  vacuous, because deleting the guard rebuilds the child, which then draws nothing and leaves
  the dead spacer the ticket was about (BUT-1869, `CompactAllergenRow` on an empty pref set).
- A Fake with two branches answering the same success value, driven by one UI flag, eats a
  routing test whole — test the FAILURE arm. An enum-driven `defaults()` owes a
  KEY-SET-COMPLETENESS test — a forgotten member is DEAD, not "off by default."
- Negative-scope claims need a negative assertion against `toMap().keys`, not a render check.
- **"No write was issued" is the commonest untestable claim** — before/after can't tell
  skipped from identical-value. Count writes, positive control same test.
- `findsNothing` needs a co-asserted positive render. A widget whose only access control is
  an early-return is untested if every pump uses the same actor constant.
- **An ORDERING fix (resolve A before B) is mutation-dead whenever the suite INJECTS A** —
  the testable constructor param resolves A synchronously, hiding a reverted fire-and-forget
  order (BUT-1838: 11/14 files, revert left all 45 green).
- Inherited-authorization-discarded: no test sees it while the permission fake defaults
  true. Tell: tests changing `currentUserId` on one double, not the permission double.
- A flag-lifting aggregator owes an EXACT-SET assertion + absence control, not `contains`. A
  two-layer fix (N emitters + chokepoint) is tested only at the chokepoint — a control, not
  coverage; each emitter owes its own suite's test.
- Boundary tests must straddle the EXACT flip point (`==N` vs `N+1`); a calendar-day guard
  flips at MIDNIGHT, not a duration. `DateTime.utc(...)` fixtures can't assert zone
  normalisation — feed `Timestamp.fromDate(x).toDate()`.
- Any normalizer/sanitizer is the IDENTITY on an already-normal fixture, and realistic
  fixtures usually are — enumerate what the helper changes, plant one instance each. MIRROR:
  a "the masker LEFT X alone" assertion is vacuous unless X sits inside the domain the
  masker would otherwise change — a 16-char class name under a {20,28} identifier rule
  survives for an unrelated reason, making the whole test byte-identical under the mutant its
  own `reason:` line names (BUT-1897, `_scrubStack`). Compute the fixture against the
  guard's BOUNDS, not against plausibility.
- **Moving a mask INTO `toString()` silently subsumes every per-site mask assertion** — after
  the class masks, `isNot(contains(uid))` on the RENDERED string is held up by the class rule,
  so the throw site's own `.masked*` call is deletable-green. Measured (BUT-1897): dropping
  `.maskedUserId` from both `MessageMutationModule` throw sites left the suite GREEN. The only
  surviving discriminator was a shape production never mints (`direct_abc` — hashed by
  `maskConversationId`, untouched by `maskIdentifiers`' two-segment rule), which ties the test
  to a divergence `log_sanitizer.dart` itself calls incidental. Pin the exception FIELD
  (`ResourceNotFoundException.resourceId`) instead: it discriminates on the REAL id and cannot
  be satisfied by the class rule. **MIRROR, at a class that does NOT mask**: when `toString()`
  is `'Label(op): $message'`, asserting both `.message` and `.toString()` is ONE observable —
  the second is entailed by the first and cannot fail alone. The discriminator is the POSITIVE
  `contains('<first8>...')`, which also ROUTE-CHECKS: it reddens if an earlier guard (recipe's
  owner-first check) caught the fixture instead. Fixture uid must exceed 8 chars or
  `maskUserId` is the identity (BUT-1915). That positive also separates every SIBLING helper in
  the utility class (each mints a different shape, and `maskIdentifiers` is the IDENTITY on a
  human NAME — so a display name needs `maskedName` at the throw and no sink rule can rescue
  it). What it cannot see is a PARTIAL mask: `isNot(contains(<whole value>))` passes on ANY
  elision, so pin the TAIL token absent too — but FIRST read the masker's OWN suite: an
  exact-EQUALITY pin there (`maskUserId('abcdefghijk') == 'abcdefgh...'`) already kills every
  tail-leaking masker mutant, leaving the call-site tail pin to catch only a HAND-ROLLED mask
  at the throw. Demanding it symmetrically at every call site after that is symmetry theatre;
  say so and end the round. **Grade "the exception object reaches Crashlytics" against the
  SERVICE's own error handler, not only the ViewModel a comment names** — `_handleError`
  reached `AppLogger.error(msg, e)` with no VM in the chain, so the sink survives even where
  the named caller is dead, AND it interpolates `'$e'` into the MESSAGE arg, which DOES run
  `maskIdentifiers` while the object arg does not. Two routes, opposite answers: scope any
  "the masker never runs here" sentence to the OBJECT route or it is false. A duplicate-branch
  fixture built by calling the seating method TWICE is non-vacuous by construction when the
  seat is the branch's only route — a failed seat throws nothing and `fail()` inside the `try`
  dies on the cast, so it reddens rather than passing.
- **A round-trip over a `double` is bound by its fixture LIST, and Dart's own notation
  switches inside the domain** — `toString()` goes EXPONENTIAL below 1e-6 (so a
  format→retype invariant breaks: `1,5e-7` re-formats to `1,57`) and `round()` SATURATES at
  int64 rather than throwing, while `infinity` DOES throw `toInt`. Friendly fixtures
  (1.5, 0.5, 2.25) prove none of it; enumerate the NOTATION boundaries, not more nice
  numbers (BUT-1891). A comment naming the strategy an assertion beats is itself untested —
  measured, the caret fixture made "counted" and "length-delta" AGREE and only separated
  "naive"; the two differ only when a character is dropped AFTER the caret.
  **A "round trip" over a UI value is TWO seams, and the doc always blames the wrong one**:
  format→parse and format→FIELD→parse. Measured, `parseSwedishDecimal` reads `1e-7` back
  EXACTLY (`double.tryParse` takes exponent notation); what loses it is the input
  FORMATTER's character filter dropping `e`/`-` → `17`. So "the parser cannot read it" would
  send the fix to the component that works. Resolve which seam by grepping the CALLERS: if no
  production line pairs the two functions directly, the direct round trip is the path that
  does not exist and the field one is the contract (BUT-1912). **The field seam has a
  TRIGGER, and it is not opening the dialog**: `inputFormatters` run on KEYSTROKES only, so a
  controller seeded programmatically keeps `5e-7` verbatim and saves the right value —
  measured with a `TextField` probe, seeded `"5e-7"` survives the pump, one keystroke makes it
  `"571"`. A `typed()` helper models RETYPING, not seeding, so any sentence about "what comes
  out of the field" owes the qualifier or it overstates the blast radius. Corollary for
  the suite: the test modelling the REAL seam is the one whose fixture list must straddle the
  flip (1e-6 holds / 5e-7 breaks), and a test name stating an unqualified universal the
  production doc now DENIES is the two-answers-to-one-question split — the name and the doc
  sentence are one claim in two files and land in one edit.
- A measurement harness's failure mode is a confident number from a broken rig — demand a
  deliberately-broken POSITIVE CONTROL, not just "the engine produced something". Two rigs
  that read 0-diff for free: a `--output=none`/dry-run flag (the tool never writes the file
  you then diff), and leaving the ORIGINALS inside the directory the tool rewrites.
- A hand-rolled double MODELLING a write's effect (not applying its payload) is blind to
  field NAMES, and a migration IS a field name — union under `Object.keys(op.data)[0]`.
- "Returns null on permission denial" needs a positive control same fixture — where every
  layer swallows to null, it's the NORMAL shape; grep for `async => null` on the loader.
- A `??` wiring needs a fixture where the arms DISAGREE. "Does less work now" needs a
  discriminator (something only the naive path pulls in), not a convergence test. A chain
  gaining a MIDDLE arm (`parse(field) ?? existing ?? default`) is born unreachable whenever
  every fixture seeds a PARSEABLE field — the arm needs the field CLEARED, which no
  seeded-fixture test does, so a changed fallback ships with nothing to redden (BUT-1910).
- **An `inputFormatters:` line is mutation-dead until one fixture types a string the formatter
  CHANGES and the test reads the RENDERED text** — a comma/period-tolerant parser answers "4,5"
  and "4.5" alike and `initialValue` never runs formatters, so both the parse case and the seed
  case survive deleting it; the killer is a second separator ("1,5,5" → "1,55"). On an
  `initialValue`-seeded `TextFormField`, `.controller` is NULL — read the descendant
  `EditableText`'s controller, which also survives a later switch to a controller (BUT-1910).
- **"The old code did X" is a claim about a GIT REVISION — run the old expression over the
  new test's own fixture before believing it, `git show HEAD:<file>` then a scratchpad
  replica.** When it is false the "regression guard" is usually a CONTROL that is GREEN on
  the bug: BUT-1910's `,5` case cited a 1.0 fallback that never happened
  (`double.tryParse('.5')` is 0.5, so old and new agree), leaving 1 of 3 new cases able to
  discriminate. Grade a bug-fix suite by which cases fail at HEAD, not by which read as the
  headline. Corollary at a widget suite: a plain `test()` calling the pure helper pins NO
  wiring by construction — it renders nothing, so a comment saying it proves the field uses
  this parser is false, and the real discriminator is an input the two candidate parsers
  ANSWER DIFFERENTLY through the FIELD (empty → null vs `parseSwedishNumber`'s 1.0).
  **Same class, opposite direction: "without this setUp line every case would be GREEN,
  measuring nothing" is a claim about a REMOVAL — delete the line mentally down each test's
  own path before writing it.** A missing DI bridge or a `Fake` fixture inside a fail-open
  catch makes the UNFILTERED-asserting tests pass and the one test that asserts the FILTERED
  result go RED — which is how the author found it — so the sentence inverts the observable it
  was written from. Scope it to the cases it is true of, or strike the clause; BUT-1909 shipped
  it in three copies (two test comments + `lessons-digest-testing.md`).
- A guard classifying OLD vs NEW mutation is untested when every fixture base is EMPTY or
  same LENGTH — need the MIXED case. Same for a re-found index after `await` (identical to
  stale when the collection has one element) and a field-exclusion decision (byte-identical
  round-trips hide it).
- A `continue`-style skip-list disagrees with its absence only when a skipped token shares a
  LINE with a matched one — if that's also where the real answer is lost, it's a design
  finding. (Scope guards, two-sided guards, narrow payloads: Coverage decisions holds them.)
- A PLACEMENT claim un-pinnable when wrong-placement is benign — say so, don't force a test.
  A signature-only narrowing opens no gap by construction — the question is whether the
  DISPATCHER calls the narrowed overload (2-arm replica, 10s).

### Fake/Mock idioms + the ServiceLocator/GetIt bridge
- `class X implements Y` with concrete bodies is a legitimate Fake; the mocktail ban is
  specifically a concrete `@override` on `extends Mock`. `extends <ConcreteClass>` with an
  override is a legitimate subclass SPY, not the banned pattern.
- **`verifyNever(() => mock.f(any()))` is UNFAILABLE against non-default NAMED args** —
  noSuchMethod fills omitted params with declared defaults, so `unit:null` never matches
  production's `unit:'st'`. Spell every named param as `any(named:'x')` (BUT-1858; positive
  `verify` unaffected).
- mocktail is LAST-REGISTERED-WINS — wildcard-then-specific `when` is a genuine repoint
  discriminator; reversing the lines silently duplicates the other test.
- When production adds a call to a NEW repository method, an existing `extends Fake` suite
  silently grades that leg's CATCH branch (noSuchMethod throws, swallowed) — grep the new
  method name across `test/`; zero overrides while production calls it IS the finding.
- A `-1` sentinel default on a Fake means two things and only one is self-proving — pick the
  arm, write the expectation, or it's just a recorder nobody reads.
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT.
- `verify(f(captureAny()))` marks calls VERIFIED, so a later `verifyInOrder` over the same
  method fails "not found" over an all-verified list — capture THROUGH `verifyInOrder`
  instead. Fire-and-forget writes to `FakeFirebaseFirestore` need microtask draining, not a
  real-time wait.
- **The GetIt→DIContainer bridge gotcha (recurring: analytics, tag-overrides, correction-
  snapshot, import chokepoints)**: many singletons resolve via PRODUCTION `ServiceLocator`,
  not `TestServiceLocator` — a mock there is invisible. Fix:
  `prod.ServiceLocator.initialize(DIContainer())`, register into `GetIt.instance` after;
  tearDown unregisters+resets.
- A hand-rolled CF query double must be IMMUTABLE once `.where()` is called twice — a
  mutable `q` aliases both legs. A double keyed on flat `"col/id"` paths CANNOT represent a
  subcollection; give it a real `ref.collection()`.
- A new fire-and-forget telemetry call at a chokepoint ships with ZERO tests by default —
  add fires-once (happy) and fires-nothing (negative); trace the resolution chain, "no seam"
  is usually false. The test that matters passes NO injected seam.
- A funnel-attribution fix has two directions — an idempotent regenerate re-counts unchanged
  lines on rerun; assert the second run logs only the DELTA.
- A defaulted `String source='manual'` param is worse than silence — grep the CALLERS of the
  newly-tagged method, not the ticket's named path.
- A safety-critical method covered ONLY via a caller's `verify()` proves WIRING, never the
  CONTRACT — grep the method name at its own layer. Mirror: an opt-in param's tests can
  prove the contract while zero production callers pass it — demand a named entry point.
- A REQUIRED param moves the job from "is it wired" to "is the DECLARED value right" — test
  the UI's CHOICE of value and its rebase after a self-triggered change.

### Disposal & lifecycle guard idioms (BaseViewModel family)
- `BaseViewModel` already guards disposal twice — only test a subclass's OWN guard when it
  protects an observable effect no base guard blocks.
- Two quadrants: delegate disposed BY this VM → `returnsNormally`+`notified==0`; delegate is
  a SHARED SERVICE outliving the VM → `returnsNormally` is VACUOUS, assert the service's
  error SURVIVES disposal.
- A class with both local `_isDisposed` and inherited `isDisposed` must use the SAME flag
  its own callbacks use. `executeAsync` RETHROWS on failure — prove via a caller retrying
  only on THROW.
- `dispose()` clearing DATA (not just controllers) opens a use-after-dispose window for a
  still-running op — dispose mid-operation, assert the write still carries user data.
- A "disposes its children" test asserting only `returnsNormally` is vacuous — materialize
  the child, assert it's dead after (`addListener`→`throwsFlutterError`).
- A suite whose every stubbed stream is already COMPLETING pins no cancellation — use a
  `StreamController`, assert `hasListener` true-before/false-after.
- A throw-on-disposed guard inside a shared builder is safe only at callers that catch —
  `notifyListeners()` post-dispose is DEBUG-ONLY, so never conclude "unreachable" from a
  debug-mode trace. The MIRROR is the commoner comment defect: only the WRITE side asserts.
  `TextEditingController.text` resolves to `ValueNotifier.value`, a bare field read with no
  `debugAssertNotDisposed` (measured, Flutter 3.38.5), so "reads the controller on a disposed
  State → an assertion in debug" is false — the read is silent and the real harm is the work
  that follows it. Grade a disposal comment by which MEMBER it names (BUT-1831).
- A `manager.dispose()` fix's wiring half ships untested — delete the OWNER's `dispose()`
  line as a probe; if the suite stays green, the fix is deletable. The flip is the returned
  future THROWING instead of resolving null.
- A `Completer` whose `.future` is never awaited is dead plumbing — grep for `.future`. A
  polling loop returning a cached `_lastResult` drops the second caller's work.
- Any concurrency fix needs the second caller actually LAUNCHED (warm-up, gate on a
  `Completer`, launch B, settle) — assert `same(inFlight, queued)`, `queued==null`
  post-dispose, and exactly ONE persisted id from the overlapping pair.

### Contract pinning: selectors, ordering, equality, revert
- Every `field==expected` selector needs THREE pins: matched-key reused, unmarked-collision
  untouched, marked-for-different-key untouched+new created.
- `==`/`hashCode` need an equal pair AND a deliberately-unequal instance — watch `hashCode`
  hashing a collection by IDENTITY while `==` compares CONTENT.
- A numeric tuning constant is pinnable only in the direction that DELETES content — never
  manufacture a fixture just to satisfy a mutant.
- A colour pin is legitimate only when the row's semantics ARE the colour, and must name the
  theme TOKEN, not a raw hex — grep the hex across the theme's own fields too.
- `expect(x, isEmpty)` DOES discriminate `''` from `null` — matcher's body is `(item as
  dynamic).isEmpty`, so null throws NoSuchMethodError and the test goes red (as an error,
  not a clean mismatch). So an `isEmpty` pin on a nullable "cleared vs unchanged" field is
  real coverage, not vacuous; don't downgrade it to `equals('')` on suspicion (BUT-1874).
- `tester.widget<T>(find.byIcon(...))` throws StateError on "more than one," not a clean red
  — scope it. Ordering needs `verifyInOrder`, not call-count. Revert-to-start: mutate, THEN
  revert, then assert.
- A `void Function`→`Future<void> Function` fix is pinned PER CALL SITE — Dart drops the
  future behind a `void` param silently, so one dropped `await` is invisible unless the
  injected sink is made to FAIL.

### Import & correction-capture pipeline
- SSRF host-filtering and decompression-bomb caps are running invariants across every
  import surface. A CTA/UI test proves the LABEL, not the ACTION — assert wire-level
  dispatch separately.
- Correction-snapshot/parse-cache keys sharing a placeholder across unrelated imports
  silently collide — test two same-kind imports in sequence.
- A wizard rebuilding an editable buffer from a prior step loses edits on back-then-forward.
- **`\b` fixes are per-REGEX, not per-file** — the lefthook `swedish-boundary-guard` can't
  find `RegExp(r'\b'+unit+r'\b')` or an ASCII-token alternation wrapped in a literal `\b`;
  grep the raw escape yourself. Check for a diacritic FOLD first — folded text has no å/ä/ö
  left to open a boundary.
- A safety carve-out via `return null` grows a second, untested public entry point once one
  caller lacks the fallback. A "keep the row" carve-out needs the re-inserted string run
  through the CONSUMER's normalizer, asserting the resolved KEY, not list membership.
- A boundary repair inside a shared predicate changes behaviour at EVERY call site — some
  decide the OPPOSITE of the predicate's name; grep for compensating workarounds whose
  comments now assert the fixed bug as live.
- Rate-limit metering: enumerate ALL call sites of the limited op. A circuit-breaker over a
  parallel `Future.wait` must not discard already-materialized results mid-batch.
- A cross-copy "single source of truth" test must READ every copy — an unexported duplicate
  still drifts. Windows: `/c/tools/flutter/bin/flutter test <forward-slash-path>` via Bash
  works directly.

### GDPR / export section contract
- **Every section needs THREE proofs**: seeded (count present, PII round-trips verbatim);
  ownership-negative (another uid's doc absent); empty-safe (`total==0` AND
  `containsKey('error') isFalse`).
- **A FOURTH: JSON-ENCODABLE** — `expect(() => json.encode(section), returnsNormally)`. A
  raw `Timestamp` anywhere means NO FILE for the subject, uncatchable per-section. Drive via
  the REAL repository over `FakeFirebaseFirestore`. Pin the EXACT key set too.
- A refactor collapsing N redaction blocks into ONE loop over a literal field list moves the
  whole contract into THE LIST — a dropped name fails OPEN while the doc still claims
  removal (BUT-1838: `memberSince` had zero coverage).
- Before crediting a redaction, check that leg's QUERY against the WRITERS — a strip on a
  leg returning zero rows is dead code AND an Art. 15 gap.
- A GDPR rationale naming a Cloud Function is a claim about another language — grep
  `functions/src` before it ships or gets copied into `ACCEPTED_DEVIATIONS.md`.
- The bundle AGGREGATOR needs its own two tests: a flag nested in a list-of-maps needs a
  depth-bounded walk; the warnings lift must key on `error` as well as `error_code`.
- A derived message can't be worded from the failure case alone — `error_code` also marks
  PARTIAL success.
- A field added to an existing scrub/cascade ships untested because the suite LOOKS
  covering — audit the fixture's fields, add keys + a retained-field negative.
- A cascade deleting a PARENT does NOT delete subcollections, and its residual probe usually
  counts top-level docs only — grep rules for `match /<coll>/{id}/<sub>` and every client
  `.doc(x).collection(y)`.
- Redaction paths (FCM token→prefix+`[redacted]`) outrank another happy-path test. A
  two-query union+de-dup needs FOUR fixtures: sent-only, received-only, self (both legs
  match), foreign.
- Truncation flags need all THREE boundary points + a positive control per leg — the
  highest-value untested case in a multi-leg section is neither leg over cap but COMBINED
  over. `total_count` must equal the SHIPPED length, not the pre-trim fetch.
- The strongest forwarding assertion is one WHOLE-MAP equality on a per-method capture,
  derived from `getLimitForType` so a typo'd `type:` is caught too. A section's wiring line
  is deletable green unless a bundle-level test asserts `data['<section>']`.
- A section-root flag ORed over M reads while aggregating N>M record types asserts
  completeness for data never probed — count reads, not the ticket's list.
- When extracting a shared capped-read primitive, test it directly (size/trim/both
  boundaries/unknown-type/error); per-section tests then only prove wiring — grep the whole
  swept file for the old pattern (silent clipping in un-swept siblings is worse than the bug).

### Settings-hydration & sentinel-parameter template (recurring: BUT-1220, 674, 1322, 1610)
Any field persisted via a private settings sub-doc needs: hydration seeding the sub-doc
directly; a corrupt-value test ALSO asserting a sibling merged field survives (one
`copyWith` in one try/catch can abort the whole merge); a save-path test asserting the
settings doc has it and the public doc does NOT, plus a round trip; one test per
serialization surface. Sentinel params (`Object? field=_unset`) need both quadrants:
omit→preserved, explicit-null→cleared. Capture the forwarded ARGUMENT IDENTITY, not a
downstream no-op. An EMPTY-STRING sentinel (`''`=cleared, `null`=leave alone) is a contract
between TWO files: a widget test pinning what LEAVES the emitter is green forever if a
consumer later re-collapses `''` to "unchanged" — pin the consumer's own `x ?? current` line
in ITS suite, same edit (BUT-1874: emitter pinned, `ShoppingItemManagementModule` untouched).

### Age/maturity/consent gates
- A field moved client→CF-authoritative: invert the old round-trip into an ABSENCE
  assertion on every client-write surface.
- "Infra error" vs "explicit rejection" needs a TYPED discriminator flag on BOTH branches.
- "Must NOT re-fire on resume" needs `verifyNever` AND the positive downstream effect in the
  SAME test.
- A "never-throws" method's contract is proven by the user-facing error field staying null
  on EVERY failure branch.

### Menu & tagging domain
- Weighted-random selectors: assert WEIGHT MATH via a `@visibleForTesting debug*` hook,
  never the sampled outcome; unrated == 1★ value; ceilings via `closeTo` at extremes.
- Any feature persisting entity ids later intersected with a live collection needs a
  ZERO-INTERSECTION test — stale ids usually fail OPEN, dangerous for allergen safety.
- A "conservative fallback" is only conservative if the shared `defaults` const is a
  SUPERSET of the happy path — open it and check.
- A widen-not-replace fallback needs its PASSTHROUGH half asserted too, not just the added
  floor — a preserved field can be silently swapped for empty.
- Anchor/cursor guards need a fixture landing the two code paths on DIFFERENT days, or a
  single-recipe fixture hides the off-by-one.
- Feature-flag OFF paths are a systemic blind spot (`tryGet<T>() ?? true`) unless a fake
  flag service is explicitly registered false.
- Denormalized-projection tests: capture via `.captured.last`; cover NULL-CLAMP (last vote
  removed → null, not 0); prove EQUAL-WEIGHTING with ASYMMETRIC inputs.

### Firestore cost, index & cascade patterns
- A declared composite index needs its own assertion (fakes can't catch a missing one) —
  assert `queryScope` alongside field order.
- A merged/idempotent cascade `update()`ing a doc it assumes exists can throw NOT_FOUND and
  fail the whole batch — test the gating doc exists but the target does not.
- A dotted-path transactional `update` needs an UNRELATED sibling field asserted SURVIVING.
- A CF trusting a doc field for a security decision is only as strong as the Firestore RULE
  validating it on create.

### CF/TS-specific
- A new emulator-integration test needs wiring on THREE fronts: the granular
  `test:integration:*` script, the composite CI chain, and the workflow's `paths:` trigger —
  unit runners auto-discover `test:*` but EXCLUDE those prefixes.
- Order the existence assert BEFORE the first dereference of a possibly-missing doc.
- A fix swapping a hand-rolled throw for a shared enforcer ships deletable-green whenever
  the suite injects that enforcer as a seam, and the AUDIT ROW is unassertable if the logger
  bypasses the module's own test seam (`admin.firestore()` direct vs `__setFirestoreForTest`).
- A relational CONFIG pin stays green when both numbers move together — anchor one literal.
- A ts-node mutant removing the LAST use of an import doesn't compile (`TS6133`) and prints
  ZERO test lines, which reads as "the whole suite died" — keep the symbol used.
- A retired-collection RE-POINT is proven by seeding the RETIRED path as a trap in the SAME
  run, never by asserting the live path alone.

### Multi-select / bulk-action wiring
- VM tests + card tests can pass while the GLUE (snapshot/order/callback) is untested at
  widget level. Selection-guard tests need the owner's OWN tile, not all-strangers.
- Clear-on-cancel: assert the count returns to the ORIGINAL, not zero. Copy-paste id-field
  mismatches are invisible unless a fixture makes the fields DIFFER.
- Async error stubs: `thenAnswer((_) => Future<int>.error(...))` — never `thenThrow`.

### Extraction seams & duplicated-logic-across-surfaces
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static`, not a DI
  bridge. When the SAME behaviour is re-implemented in 2+ classes, demand a test PER COPY —
  copies WILL diverge silently.
- An OPT-IN parameter gating a SECURITY behaviour is OFF everywhere until a `lib/` caller
  passes it — grep the name in `lib/` and `test/` separately; "test-only hits" IS the finding.
- **LIVE-PATH CHECK, before writing any test for a bug fix**: grep the call chain from the
  view down to the write, confirm the fixed method is ON it — a fix on a parallel facade
  with no `lib/` callers ships nothing. A tested caller + a tested callee ≠ a tested seam.
- An optional nullable callback seam ("stays constructible in tests") is invisible when every
  harness omits it — grep the seam's name across `test/`; zero hits IS the finding.
- A new error/message seam is only as good as its READERS — a caller that awaits then shows
  success unconditionally means the message is never shown or cleared.
- Enumerate optimistic-rollback siblings by SHAPE (catch blocks restoring local state,
  `return false`), not the ticket's wording — a fix on the two named leaves the rest live.
- When a data-loss ticket ships root cause + safety gate, the gate gets tests and the root
  cause gets none — grep the root-cause CLASS across `test/`. The third untested layer is
  usually the VIEW's outcome→message branch: assert the INVARIANT, be CHANNEL-AGNOSTIC.
- A "reads live state, not the cache" contract is only tested if the fixture makes the two
  DIFFER — cached vs stored needs a tick PLUS an item the cache never saw.
- An atomicity fix is tested at the layer OWNING atomicity, unreachable on the fake — a
  transaction-runner typedef seam is legitimate for platform codes but seams out the
  RUNNER, not the transaction; pair with an emulator-lane test.
- A permission guard on ONE method of a pair must be checked on its sibling — a
  callback-based API is the EASIER bypass. An attribution-field fix's sweep must include
  MODEL FACTORIES (a factory copying a display name means the FIRST stamp differs in source).
- Converting a per-item write to a per-item TRANSACTION makes existing `Future.wait` fan-outs
  over the SAME document pathological — grep callers first.
- A shared cache reused by a STRICTER new reader launders the weakest writer's output —
  enumerate every writer into the cache.
- A `didChangeDependencies` retry on a widget that renders `SizedBox.shrink()` on failure is
  DEAD — the early return happens before any `Theme.of`, so only a REMOUNT recovers.

### One-off gotchas, Windows/runner notes, and the revert-probe technique
- An overflow probe MUST mount `AppTheme.lightTheme` — the bare `MaterialApp`'s smaller
  default typography can hide a real overflow. Pin with SYNTHETIC tall content, never real
  ARB copy (dies with the flag). `expect(takeException(), isNull)` is ALSO satisfied by a
  tile that rendered nothing, so co-assert the content under test is present — otherwise a
  regression in the flag that ADDS the content turns the geometry case green. A ladder that
  SKIPS cases per fixture (`cleanUpTo`) is honest only if the skipped ones are MEASURED
  (320dp really does overflow from 1.3x, BUT-1895); the residual is then un-pinned in the
  reverse direction, so a source comment claiming "both ends are covered" goes stale in
  silence the day someone retunes the factor. Register those cases as NAMED `skip:`, never a
  `continue` — `testWidgets`' skip takes no reason, so the reason and ticket go in the NAME,
  which the runner prints every run. Two residuals survive that: the co-assert closes only
  "the ADDED content vanished" (a tile fitting because something ELSE shrank still passes),
  and a named skip goes stale GREEN the day the residual is actually fixed.
- A page-size guard is only testable on a TALL surface (`tester.view.physicalSize =
  Size(800,14000)`, dpr 1.0) — a short surface auto-scrolls and hides item 0.
- `Semantics(label:)` on a tooltip'd button MERGES into one node — match with `RegExp`,
  bracket with `ensureSemantics()`/`handle.dispose()`.
- Real `.xlsx` stores text via shared-strings (`t="s"`), not `inlineStr`. A
  `TimeoutException` with 0 tests run is compile-bound (~12 min shared compile), not hung —
  split invocation per file.
- **THE PROBE LADDER, cheapest first**: (1) analytic — make the two sources DIFFERENT
  literals so a revert can't coincide with expected; (2) SCRATCHPAD replica via `dart.bat
  --packages=<repo>/.dart_tool/package_config.json` (no repo writes, immune to parallel
  sessions); (3) `test/`-side replica; (4) mutate the INJECTION, not `lib/`; (5) only then a
  real `lib/` revert.
- **Writing a mutant into `lib/`/`functions/src` is REFUSED by the auto-mode classifier
  (content-, not command-sensitive)** — the Edit applies silently and the NEXT run is
  refused. On a dirty file: `cp -p` first, restore via reverse Edit, `cmp`/md5 verify. On a
  clean file: Edit-mutate, restore with `git checkout --`, verify via `git status`/`diff
  --stat` (not md5 — CRLF on checkout differs).
- **Revert-probe mechanics**: copy to scratch, string-replace the fix OUT, confirm EXACTLY
  the expected tests go red, restore + `cmp`. Assert the search text occurs EXACTLY ONCE
  before writing — doubles as a tree-motion detector. Do the cycle in ONE Bash call, script
  reading OLD/NEW text from FILES; on Windows read/replace/WRITE IN BINARY.
- A WHOLE-CLASS replica scales this: copy class + suite to the SESSION SCRATCHPAD (not
  `test/`), rename, repoint the import — the only route when the `lib/` file is STAGED or
  edits are forbidden. Run the unmutated copy as control first.
- READ THE MUTATED LINE BACK before believing a red count — a shell heredoc can mangle
  backslashes silently. Write probes with the Write tool, raw Dart strings, never a bash
  heredoc. Never pipe a mutation driver into `head` (SIGPIPE kills its own cleanup).
- A probe file lives in scratch, not `test/` — a `// delete after` header is not a deletion
  (two outlived their round in 2026-08-12). Close every round with `git status --porcelain`.
- When the test reads a FILE PATH (registry lints, declared-index asserts), the mutant is a
  GIT REVISION — `git show HEAD:<path> > scratch/`, run the walk against both. The only
  probe available when the "fix" is a deletion.
- A deletion mutant inside a fluent chain doesn't compile — substitute an always-true
  equivalent (`.where('name', isNull:false)`).
- A generated file in a diff is verified by re-running its generator, byte-compared, with
  the output's mtime moving while inputs don't (a byte match proves nothing if the generator
  silently skipped files).
- A one-character change inside a string literal can't be reviewed from `git diff` — `od -c`
  or `git show HEAD:` it. Byte-form grep false-negatives under UTF-8: use the codepoint form
  `grep -nP '\x{F8FF}'`, a Python sweep, or `cat -A`.
- A new grep guard in `lefthook.yml` needs one path-handling probe — it renders
  `{staged_files}` REPO-RELATIVE, so an anchor past a `path:line:` prefix false-fails on a
  Windows absolute path (`C:/…` splits at the drive colon); anchor the LAST `:<digits>:`. A
  guard wired only pre-commit is bypassed by `LEFTHOOK_EXCLUDE` or a merge.

### Firestore-rules `.ts` suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify`/
  `hasRequiredFields` list needs a test PER FIELD.
- A failure-only update suite can be silently over-restrictive — pair denials with an
  `assertSucceeds` on a mutable field.
- The emulator persists docs ACROSS invocations — suffix create-test ids with a per-run
  `Date.now().toString(36)`, or a fixed-id create silently becomes an update.
- Hand-rolled `npx ts-node` runners against `127.0.0.1:8080` time out without the emulator
  running first; `npx tsc --noEmit` DOES typecheck `src/__tests__` — a free non-emulator
  check on a rules suite you can't run.
- **A client-side filter test on the fake says NOTHING about whether the SERVER accepts that
  query** — rules refuse a whole QUERY when any candidate doc fails the read rule. A
  membership-filtered read owes THREE assertions: filtered-ALLOW (SDK's own spelling, with a
  non-empty premise check); unfiltered-DENY (delta is only the missing `where()`); and
  filtered-ALLOW-but-empty for a member of nothing.
