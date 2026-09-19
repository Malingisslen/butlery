# testing-specialist — accumulated knowledge

Core card: read on every review, after the shared review core. The chapters are listed under
`knowledge.tiers` in `.claude/shared-plugin.json`; read each chapter whose `paths` match a
file in the diff. The archive, `testing-specialist.knowledge.archive.md`, is never read at
review. A new principle goes into the chapter it is about, and into this card only if it
applies to every review; `knowledge-caps-gate` refuses a core card over 15,000 chars and a
chapter over 20,000.

## How to update this file

- **PRINCIPLES only, 1-4 lines.** Earns its place only if a future run would act
  DIFFERENTLY because of it. Merge into the matching section; never append to the end.
- **The raw, dated record lives ONLY in `testing-specialist.knowledge.archive.md`** —
  append-only, one `### <date> — <title>` entry per incident, verbatim.

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
- **Fix loop consumes Critical/High only** — an all-Low/Medium re-review never changes. Apply
  zero-risk test-only fixes yourself; never edit production in a review pass.
**MUTATION PROBES: green and red are NOT symmetric. This bullet is load-bearing; do not
compress it.**
- **A GREEN probe is a hypothesis, never a measurement. Only a RED probe measures anything.**
- **The build cache is the reason.** A mutate→run→restore→mutate LOOP can be served the
  PREVIOUS mutant's kernel: mutate and restore inside one second and `flutter test` reuses a
  stale incremental build, so the run reports failures belonging to the mutant before it.
  **Never loop probes in one Bash call. Run each mutant in its OWN call, run it TWICE, and
  grade run B.** Re-run any surprising red alone before filing it.
- **Do not trust a `mktemp`+`trap` restore, even one whose own md5 reads clean** — measured on
  BUT-1971, the restoring call printed the pre-mutation md5 and the NEXT call found the mutant
  still live on disk. Restore with `git show :<path> > tmp && cp tmp <path>` (deterministic,
  and it is the copy the parent commits) and verify with `git diff --numstat <path>` EMPTY —
  never against a remembered hash.
- **Mutate the CALL SITE, not the member a fake overrides.** A widget suite injecting
  `MockFriendsViewModel` never executes production `FriendsViewModel.isBlocked`, so
  mutating it is all-green by construction and reads as "these tests are fine". Before
  probing, ask which of the mutated symbol's layers the harness actually reaches; for a
  repointed GUARD that is the `if` in the widget, not the method it calls (BUT-2022).
- **Only the `[E]`-marked line names a failing test.** `flutter test` prints the cumulative
  `+passed -failed` beside the test currently STARTING, so a report pasting the lines after a
  failure names the WRONG tests while the tally is right. Grep `\[E\]`, never the running names.
- **When the question is only "is this line REACHED at all", coverage answers it with no `lib/`
  write** — `flutter test --coverage --coverage-path=<scratchpad>/lcov.info <suites>`, then
  `awk '/^SF:.*<file>/,/^end_of_record/' | grep '^DA:<line>,'`; a `0` is the finding. ~10s, no
  restore, no parallel-session clobber, no auto-mode classifier. A reached line can still be
  unasserted, so reach for a mutant only for "does any test DISCRIMINATE this expression"
  (BUT-1831). The same report settles a widget test turning on a COLLABORATOR's state: read the
  DA hit on the RHS LINE of an `&&`, which evaluates only when the LHS was true (BUT-1908).
### Coverage decisions
Codecov: 60% project / 70% new patches / 2% drop tolerance — floors, decided 55% project
(2026-07-11); don't file generic "raise coverage" tickets.

**The opening moves of any coverage review, in order (each is seconds, each has caught a shipped
gap):**
1. **Grep each NEW TOKEN into a token→files table.** Zero files IS the finding; hits only in an
   extracted class's own suite means the composing line in the CALLER's suite is unproven
   (BUT-1838). **When the new token is a SHARED widget or helper its repo-wide hits are a
   decoy — grep the FLAG that SELECTS the changed branch instead** (`batchRunning`), which
   answers whether the edited line executes at all. A swap inside a busy/error/empty arm reads
   as covered because the suite pumps the surface, having only ever passed the flag's OTHER
   value (2026-09-07).
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
- **"Owes no test" turns on whether an ASSERTION LANE EXISTS, never on the change being small,
  structural or a mere wrapper — and the lane question is SETTLED BY RUNNING a scratch probe, not
  by predicting a deadlock.** When the suite already drives the real VM, already opens the
  surface and already stubs the seam, the lane exists and the wrapper owes the test. Reserve
  "owes none" for a sink with no harness at all. A modal route is the recurring shape, because
  every sibling test resolves during load and taps afterwards, so the whole group agrees
  vacuously (BUT-1971).
- **"X does NOT happen" needs proof the code reached where X could** — "no write" can mean skipped
  OR identical values; count writes, positive control same test. **A refusal test beside a new
  fail-closed guard is the standing carrier**: an earlier guard refuses first and both save
  assertions hold under every mutant. Drive the refused ACTION to the point where it would write —
  and read the inserted call's OWN early-returns against the state the failure left, because the
  same failed read that armed the guard usually nulls what the driving call needs (BUT-1939/1962).
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
  **The pair also recurs wherever a predicate is RE-COMPUTED in a second caller instead of called**
  — the model suite's discriminating fixture (the LEGACY `isGroup`-without-`groupId` case) does not
  reach the copy, so each copy owes its own; grep the copy's LINE, not the shared function (BUT-1854).
- **An assertion ENTAILED BY ITS NEIGHBOURS.** `expect` is fail-fast, so a line evaluates only when
  the lines above passed; when those pin BOTH operands, its kill set is EMPTY by construction. The
  commonest carrier is a LEAK test: an exact-string equality above an `isNot(contains(leak))` loop
  makes the loop unfailable. Keep the equality, delete the loop — the loop earns its place only where
  the assertion above it is a `contains` (BUT-1961/1962). **Where the neighbour IS a `contains`,
  entailment turns on whether the positive's match set swallows the regression wording, and
  TRANSLATING the pair silently re-decides that** — re-probe per DIRECTION after any re-wording, and
  read WHICH assertion the runner names (BUT-1957). **A guard that returns ABOVE the confirmation
  dialog is the same shape wearing a UI costume**: once "no dialog" is asserted, every downstream
  "nothing was written" line has an empty kill set, because the only write sits behind a tap the test
  never makes — so the test proves the DIALOG, and a name or comment promising the WRITE is the false
  sentence to strike (BUT-1951).
- **"No write was issued" is the commonest untestable claim** — count writes, positive control same
  test. `findsNothing` needs a co-asserted positive render. A widget whose only access control is an
  early-return is untested if every pump uses the same actor constant.
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
### One-off gotchas, Windows/runner notes, and the revert-probe technique
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
