# testing-specialist — chapter: guards

- A **method whose RETURN TYPE widens** (`Future<void>`→`Future<bool>`) — every existing call
  site discards it and the suite stays green under `return true`. Read whether ANY call ASSIGNS
  the result. Same grep answers for an UNCHANGED return value whose only assertions sit at a
  MOCK-service layer. Grade a widened return PER BRANCH of the caller's ternary, and resolve any
  "pinned in <other suite>" pointer with a grep before believing it (BUT-1962/1948/1982).
- A **guard added to close ANOTHER gate's finding** (security, GDPR, rules) arrives with NO pin
  at all — no finding asked for a test and the round's budget went to the findings that did. The
  tell is a method at `DA:0` whose class siblings are pinned; read the fix report for guards
  mentioned in passing as "also changed by the other gates" (BUT-1971).
- A **DATA-SOURCE swap on a `ServiceLocator.tryGet<T>()?.field` getter** (the CLAUDE.md footgun:
  `profileDisplayName` vs `currentDisplayName`) is deletable-green in EVERY suite, and settled
  analytically — both members are same-typed so the swap compiles, and the value is null either
  way whenever the locator is unregistered OR registered to an unstubbed mocktail `Mock`, which
  `TestServiceLocator` does by default. A pin on `T`'s own getter is the LAYER BELOW and cannot
  see which member the caller reads; an injected-lambda test pins CONSUMPTION, never the BINDING.
  Only two stubs with DIFFERENT strings, over the real service, discriminate (BUT-1764/1705).

**Grading a guard, a widening, or a rollback:**
- **A guard added to close a review finding gets its EXISTENCE pinned and its CONDITIONS not** —
  deleting the block reddens, stripping every conjunct but the one the finding named stays green.
  Grade each conjunct for HARM before filing: some are analytically inert, some degrade to a
  no-op, and usually ONE carries the real hazard (BUT-1971).
  **A ONE-predicate guard whose negative space holds SEVERAL values owes a fixture per value,
  and the naturally-occurring one hides the rest**: `!value.isFinite` covers {+Infinity,
  −Infinity, NaN}, and every overflow fixture anyone writes lands on +Infinity — so
  `if (value != double.infinity) return value;` survived all 171 tests of BUT-2067 (measured,
  twice). Enumerate what the predicate REJECTS, not what the bug produced; the production
  comment naming the extra value (`double.tryParse` accepts the literal `NaN`) is the tell.
  **On a two-conjunct GETTER the blind conjunct is the one whose false arm is built from the
  OTHER conjunct's CONSTRUCTOR DEFAULT** — a three-arm test reading "in both directions" then
  survives `=> otherConjunct`, because every arm agrees with it. Walk the conjuncts, not the
  arms: each needs a fixture false in IT and true in every sibling. Same walk settles a
  `?? <default>` fail-open — a direction stated in a comment is unwitnessed until one fixture
  OMITS the key and asserts the flag (BUT-2047).
  **The CONSEQUENCE you state for a surviving mutant is a separate claim, and it gets written
  into the repair's comment before anyone traces it** — "the notice would be shown to every
  user" was false because the caller reads `retained.first` inside the same `if`, so an empty
  list throws before any dialog is built. Trace the mutant through the CALLER to its first
  observable, or file the survival and stop: the finding does not need the consequence, and a
  wrong one ships as code (BUT-2047).
  **When ordering a strike, say WHICH clause — a CONDITIONAL survivor is true where the
  INDICATIVE one is false.** "must not assert X when nothing measured one" holds once the
  false head clause goes; "asserting X would tell them something nobody measured" does not,
  because it ranges over a branch where something did. I demanded both go and was wrong about
  the first; withdraw such an over-reach outright rather than re-file it narrowed (BUT-2047).
- **When a fix REPOINTS a read from source A to source B, every existing test whose SEEDER
  writes BOTH sources is green on the revert** — the fixture cannot tell the two readers
  apart, so the guard reads as pinned at every surface that has a test. Read the fake's
  seeder, not the test body: `setBlockedUsers` wrote `_preBlocked` AND `_statuses[id]`, so 3
  of 4 repointed guards survived reverting `isBlocked` to the ordered enum. The killer
  fixture DIVERGES the two sources (seed B, then overwrite A with the value that used to
  win), and ordering matters because the seeder writes A last. Same shape as the
  authed-uid-vs-passed-uid collapse (BUT-2022).
- **The test closing ONE conjunct discriminates only while the fixture leaves every OTHER
  conjunct SATISFIED — usually via an unremarked property of a stub nobody would defend.** Name
  the conjuncts the fixture is holding open in the test, or a later tidy vacuums it (BUT-1971).
  **Before demanding that naming, ask what VALUE the vacuuming edit would have to PRODUCE and
  where that value can come from** — a test asserting a second observable whose SOLE producer is
  the code under test is SELF-PROTECTING, and the extra pin is over-testing. Measured on BUT-2052:
  a "leave() resets the connection flag" tidy left the re-entry test still RED, because the
  assertion beside it reads a status STRING the mock only yields through the refresh being pinned.
  The residual is worth one sentence, not a test: such an assertion reads as decorative, so say
  what it READS — deleting it as redundant is what would arm the fragility.
- **Grade a guard PER FIELD it was extended to, and grade the DERIVED writes beside it** — a fix
  round closes one field and extends the same guard to a sibling in the same edit, and the report
  reads one fixture as covering both (BUT-1971).
- **A SET WIDENED OVER SEVERAL SOURCES is pinned only where a source contributes a uid no OTHER
  source holds.** Build the fixture-uid × source table; reading the spreads one by one makes all
  of them look covered. **Read the LOOKUP STUB first** — a `thenAnswer` ignoring its ARGUMENT
  makes every spread deletable-green; the stub must filter on
  `invocation.positionalArguments.first` (BUT-1971). **A CONSTANT set composed by spread
  (`B = {...A, x}`) is the same shape and reads as fully pinned**: every member of A is
  witnessed by B's consumer suite, so the only unwitnessed mutant is MOVING a member out of A
  into B's literal — behaviour-identical for B, silently narrowing A's own predicate. Grade
  membership PER SET, not per code: one fixture per A-member through A's OWN predicate. The
  MIRROR mutant, deleting the spread (`B = {x}`), is invisible to A's predicate and dies only
  in B's own per-code suite — so the pair is pinned only when BOTH suites carry a case per
  A-member (BUT-1922).
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
  enumerates). **One decision spelled in TWO grammars — a parsed-value EQUALITY and a raw-source
  regex PREFIX — is two decisions, and the doc comment calling them "the same decision spelled
  differently" is what stops the next reader checking**; run BOTH over one lattice, since the
  suite pinning the strict twin reads as covering the permissive one (BUT-2020). Grade the whole family in ONE cheap run: a scratchpad replica plus a MATRIX of
  full-regex × one-alternative-deleted over every fixture. Two things only the matrix shows: an
  alternative killed by TWO fixtures (fine) or by NONE (the finding). In a MASK-head/PRESERVE-frames
  splitter only the PRESERVE assertion pins the split. `hasRequiredFields` checks presence+non-null
  ONLY, never TYPE. **A stated red count must name its SCOPE** (BUT-1897).
- "Returns null on X / on permission denial" needs a positive control in the same fixture — where
  every layer swallows to null, null is the NORMAL shape of denied/offline/deleted; grep the suite
  for `async => null` on the loader.
- Last-wins/precedence tests need the LOSER asserted absent, with inputs where the wrong answer
  genuinely differs. A partition/drift-guard test from the SAME curated list the impl was written
  from cannot fail — probe with a real sibling name.
- Coalescing-across-calls: a fixture whose injected reader returns a CONSTANT can't see it — model
  the read, drive N calls on an advancing clock. A parameterised loop over failure codes proves one
  leg N times if the fixture starts EMPTY.
- A defensive DECODE helper's null branch needs the ABSENCE mutated, not the value, plus a wrong-TYPE
  row. **A `x !== undefined` → `x` (truthiness) swap is a FOUR-state behaviour change an "absent"
  fixture structurally cannot see** — the tell is an ENUMERATING doc comment with one member pinned.
  **Check the swap against HEAD before filing it as new behaviour — an EXTRACTION is the usual
  carrier and the extracted copy is often the REGRESSION** (`git show HEAD:<file>` on the
  ORIGINATING call site, not on the new function, which has no history) (BUT-1904).
- **A fix that DELETES dead code is mutation-dead by construction** — only the FORWARD direction is
  pinnable ("the field must not come back"); say that in the name, and never also assert the VALUE
  the deleted code could not produce (BUT-1873).
- A flag selecting between two values is pinned by both arms over one fixture with observably
  different values. A nullable override deriving its default from a nullable payload owes a third
  arm: the EMPTY (non-null) payload.
- "Declines/falls back" needs `equals([input])`, not `hasLength` — catches truncation. A test named
  after an input must assert that input's VALUE.
- **A hardcoded/derived fixture value that makes the guarded and unguarded expressions identical** —
  the analytic case; grade a guard PER FIELD, since the sibling field's fixture usually satisfies it.

- Circular determinism (calling the same pure function twice, or deriving expected from the const
  under test) — pin the literal OUTPUT.
- Sibling-branch short-circuit, BOTH polarities: for `if(A) return true; if(B) return true;`, check
  no fixture satisfies a branch other than the named one. MIRROR (AND-chain + `findsNothing`): a
  negative test naming ONE conjunct needs every OTHER conjunct SATISFIED — assert the premise in the
  test itself (BUT-1869).
- Fake-default-same-as-expected: use a sentinel no real caller would pass.
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
- Inherited-authorization-discarded: no test sees it while the permission fake defaults true. Tell:
  tests changing `currentUserId` on one double, not the permission double.
- A flag-lifting aggregator owes an EXACT-SET assertion + absence control, not `contains`. A two-layer
  fix (N emitters + chokepoint) is tested only at the chokepoint — a control, not coverage.
- **"The old code did X" is a claim about a GIT REVISION** — `git show HEAD:<file>` then a scratchpad
  replica over the NEW test's own fixture. When it is false the "regression guard" is a CONTROL that
  is GREEN on the bug. Grade a bug-fix suite by which cases fail at HEAD. Corollary: a plain `test()`
  calling a pure helper pins NO wiring by construction (BUT-1910).
- A guard classifying OLD vs NEW mutation is untested when every fixture base is EMPTY or the same
  LENGTH — need the MIXED case. Same for a re-found index after `await` and a field-exclusion
  decision.
- A `??` wiring needs a fixture where the arms DISAGREE. "Does less work now" needs a discriminator,
  not a convergence test. A chain gaining a MIDDLE arm (`parse(field) ?? existing ?? default`) is born
  unreachable whenever every fixture seeds a PARSEABLE field (BUT-1910).
- A PLACEMENT claim is un-pinnable when wrong-placement is benign — say so, don't force a test. A
  signature-only narrowing opens no gap by construction — the question is whether the DISPATCHER
  calls the narrowed overload.
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
- **Fixture-shape family**: the fixture's own shape answers for the code. An accumulator off `.first`
  hides its loop unless the first item is interior on every axis; enumerate every field production
  READS and override each independently.

- **LIVE-PATH CHECK, before writing any test for a bug fix**: grep the call chain from the view down to
  the write and confirm the fixed method is ON it — a fix on a parallel facade with no `lib/` callers
  ships nothing. A tested caller + a tested callee ≠ a tested seam.
  **The FAKE SANDWICH is the recurring form, and a whole ticket's worth of green suites hides it:**
  when a change adds a method at layer N, the suite at N+1 mocks layer N and the suite at N−1 mocks
  layer N−1's own collaborator, so nothing ever constructs N. Settle it with `grep -rn '<ClassName>(' test/`
  (zero non-Mock hits IS the finding) and confirm with a `--coverage` DA read — no `lib/` write, and an
  all-`DA:...,0` method body is unarguable. On BUT-1718 the ticket's ONE production decision
  (`intent: selfRemoval` at the module's single call site) sat in such a body while 2313 tests passed
  over it, and the layer's sibling hand-passes that same argument in its own suite — which is the exact
  incident that layer's comments already warn about.
