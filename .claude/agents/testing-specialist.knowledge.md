# testing-specialist — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every testing task and **APPEND** to it when it
discovers a new pattern, encounters a new helper, or is corrected by the
user.

The main agent file (`testing-specialist.md`) holds the durable rules
(DO-WRITE / DO-NOT-WRITE patterns, the production→test path map, Mock-vs-Fake
guidance). This file holds **what the agent has learned since then**.

## How to update this file

- **Append-only** — never delete entries; supersede with a newer dated entry.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **Tag with the trigger** — Bug found / Pattern discovered / Helper added /
  User correction.

---

## Project-specific test infrastructure (already in agent file)

These live in `testing-specialist.md` — read it for full detail, summarized
here so the agent sees them in context:

- **Production ServiceLocator bridge**: `production.ServiceLocator.initialize(DIContainer())` in `setUpAll`. Two ServiceLocator classes (production wraps DIContainer, test uses GetIt directly) sharing the same `GetIt.instance`.
- **`MockUnifiedRecipeService.setRecipeState()`** defaults `isInitialized: false` — always pass it explicitly.
- **Debounced ViewModel methods** need `fakeAsync` + `async.elapse(Duration(milliseconds: 300))`.
- **`executeDebounced`** triggers 3 notifications: setLoading(true) + operation + setSuccess().
- **Per-view "mechanical" tests were deleted in BUT-387 Phase 6** — `test/views/` is now journey-test territory only. Don't recreate them.

## Bugs found via tests (don't lose this — these prove the philosophy)

- **BUT-369**: `Recipe.copyWith` empty-list crash — caught because the test
  was checking the right invariant (copyWith with empty children must not
  crash), not "copyWith calls some internal method."
- **BUT-369**: `FirebaseShoppingRepository` delete permission bypass —
  test asserted "stranger cannot delete owner's item," not "delete returns
  bool."
- **BUT-369**: `ParseEventLogger` Firebase-on-construction — test caught
  initialization order issue because it constructed in isolation.

If a future test catches a real bug, **append an entry below** — the
philosophy ("test the contract, not the structure") is proven by a growing
list of bugs caught, and that list is itself the most persuasive
counter-argument to "let's just delete this test."

## Coverage decisions

- Codecov gate: **60% project, 70% new patches, 2% drop tolerance**.
- These are floors, not targets. Don't chase coverage by adding
  getter-identity tests.
- Behaviorally meaningful test at 50% line coverage > ten getter checks at
  90%.

## Helpers that exist (don't reinvent)

| Helper | Path |
|---|---|
| `setupUnit()`, `teardownUnit()` | `test/test_support/base_unit_test.dart` |
| `TestTimestampProvider`, matchers | `test/test_support/timestamp_test_helper.dart` |
| `useEmulatorLane`, `firestoreForLane()`, `clearLane()`, `emulatorOnlySkip` | `test/test_support/emulator_lane.dart` |
| `butleryGolden(...)` | `test/widget/golden/golden_helper.dart` |
| `createLocalizedTestApp(...)` | `test/infrastructure/helpers/widget_test_app.dart` |
| All production mocks | `test/infrastructure/mocks/production_mocks.dart` |
| Typed mock factory | `test/infrastructure/factories/mock_factory.dart` |

Always grep these before writing a new helper.

## FakeFirebaseFirestore vs emulator decision tree

| Behaviour under test | Use |
|---|---|
| Plain reads/writes/queries | `FakeFirebaseFirestore()` in `setUp` |
| `FieldValue.increment` | Emulator lane (`firestoreForLane()` + `skip: emulatorOnlySkip`) |
| `serverTimestamp` | Emulator |
| `collectionGroup` queries | Emulator |
| Transactional writes | Emulator |
| Security rules behavior | Emulator (or hand off to `firestore-rules-tester`) |
| Service that wraps Firestore | Mock at the repository interface, not at Firestore level |

---

## Discovered patterns

*Append new dated entries below as the agent learns them. Trigger-tag each
entry: [Bug found] / [Pattern discovered] / [Helper added] / [User correction].*

### 2026-04-25 — initial seed
Knowledge file seeded from `testing-specialist.md`, `MEMORY.md` (test
infrastructure patterns 2026-02-09), and the BUT-368/369 bug list. Future
entries should record genuinely new test patterns, helpers, or bugs caught.

### 2026-04-26 — A11y P2 + social safety sprint coverage [Pattern discovered]
Sprint added 6 new test files (37 tests, all green): A1 `app_colors_contrast_test`
(WCAG AA contrast ratios for `textLight` against cream/white/creamDark), A2
`styled_input_semantics_test` (labelText / search-variant hint / explicit
semanticLabel surface as screen-reader labels), A4 `reduced_motion_test`
(MediaQuery.disableAnimations + `Duration.respectingMotion` extension —
clean pattern for animation a11y), A5 `app_shortcuts_test` (keyboard
Intent dispatch + `mainTabSwitchRequest` ValueNotifier bridge), B1
`group_detail_report_tiles_test` (overflow menu Report tile owner-vs-non-owner
visibility), B2 `content_filter_service_test` (Swedish + English profanity,
word-boundary, case-insensitive, fieldName-doesn't-leak).

Coverage gaps worth tracking for a follow-up sprint:
- `lib/services/cook_snap_service.dart` switched `containsProfanity` →
  `ensureClean` with no direct service test. Behaviour is covered indirectly
  by `content_filter_service_test`, but the wiring (does CookSnap surface
  `result.reason` to the user?) isn't asserted. Next time a CookSnap test
  is touched, add the ensureClean-rejects-upload assertion.
- `lib/services/moderation/report_service.dart` added a `'group'` case in
  `_resolveContentRef` for `users/{ownerId}/friend_categories/{categoryId}`.
  The UI flow (dialog opens) is tested by `group_detail_report_tiles_test`,
  but the doc-ref resolution itself is untested. Worth a small unit test
  asserting the resolved path matches `users/{ownerId}/friend_categories/{groupId}`.

Pattern reminder enforced this run: `lib/views/*` modifications do NOT
require new view tests (BUT-387 Phase 6 deleted that lane). Theme files
are covered by golden tests + targeted contrast assertions, not by structural
"uses AppColors.X" tests.

### 2026-04-30 — BUT-696 Viterbi golden-set fixture pattern [Pattern discovered]
Added `viterbi_context_processor_test.dart` (20 tests) + sibling
`viterbi_context_processor_fixtures.dart` for the line-classifier post-processor.
Patterns worth reusing:

1. **Sibling fixtures file for golden sets.** `*_fixtures.dart` next to the
   test holds typed records (`GoldenLine` / `GoldenRecipe`) with an explicit
   `expected: LineType?` per line. `null` opts a line out of scoring — use it
   only for genuinely ambiguous lines, not as a green-test escape hatch.
   Fixture sanity test (`every fixture has >= N scorable lines`) prevents
   the fixture from rotting into uselessness.

2. **Print-then-assert accuracy as the regression gate.** The accuracy test
   prints the per-recipe number AND the aggregate, then asserts against a
   baseline tuned ~3pp below the actual measured number. First run measured
   98.2% (108/110), baseline pinned at 95%. The print line gives future
   refactorers a free regression diff in test logs without needing a
   separate snapshot file.

3. **Test the contract directly with synthetic `ClassifiedLine` inputs.**
   Most existing Viterbi coverage went through `SwedishLineClassifier`,
   which makes "high-confidence anchoring" hard to assert (you can't dial
   confidence). Constructing `ClassifiedLine` literals lets you write
   "low-confidence (0.4) line in the middle of high-confidence (0.9) run
   gets pulled" as a single-axis test — clean isolation of the algorithm
   from the per-line classifier's lexicon.

4. **`identical()` for short-circuit assertions.** When code returns the
   same instance for unchanged-type lines, `identical(output[0], input[0])`
   pins that contract. Future refactors that "helpfully" wrap in copyWith
   surface immediately. (Not paranoid — this matters because `secondaryType`
   semantics depend on this short-circuit: only overridden lines get
   `secondaryType` populated.)

5. **Boundary-survival tests, not value tests, for edge mechanics.** The
   "boost decays after ~15 lines" test only asserts length-preservation +
   no-crash at the boundary, not the resulting type at line 16. Asserting
   the exact post-boundary classification would couple the test to the
   transition-matrix tuning; asserting "didn't crash at the boundary"
   pins the algorithmic invariant without locking the numbers.

Contract surprises found while reading the source:
- `classifyWithContext` returns the `lines` argument *unchanged* (same
  reference) when `length <= 1`. Tests assert this with `identical()`.
- The override path only writes `secondaryType` when the type changes —
  unchanged lines pass through verbatim. No `copyWith` allocation churn.
- The `_negInf = -1e9` sentinel is used both for unreachable transitions
  AND uninitialized cells. Not a bug, but worth knowing if any future
  test needs to construct adversarial probabilities.

No production bugs caught this run — the algorithm was already battle-tested
through `SwedishLineClassifier` integration tests. The dedicated unit tests
are insurance against a transition-matrix or emission-weight refactor
silently regressing edge cases.

### 2026-04-30 — BUT-611 Viterbi calibration close-out [Pattern discovered]
Cluster D added `viterbi_calibration_test.dart` (6 tests), companion
`viterbi_calibration_fixtures.dart` (4 held-out Swedish recipes, 59 hand-labeled
lines, all scorable), and `viterbi_calibration_baseline.md` committed reference
numbers. Production change: three `static const` thresholds in
`ViterbiContextProcessor` (`_highConfidenceThreshold = 0.75`,
`_highEmissionWeight = 2.5`, `_lowEmissionWeight = 1.0`) promoted to
constructor parameters with `_default*` fallbacks so calibration tests can
sweep without mutating production state. `const ViterbiContextProcessor()`
call-sites compile unchanged.

Patterns worth reusing for any "is this hardcoded threshold actually right?"
investigation:

1. **Held-out corpus as overfitting check.** Golden set (110 lines) tunes the
   algorithm; held-out set (59 lines) authored *after* and intentionally
   chosen to be lexically distinct catches drift. Decision rule: a non-default
   value "wins" only when the gap exceeds the noise floor (2pp) on *both*
   corpora and at the *same* threshold value. Single-corpus wins are dismissed
   as small-corpus noise. This is the right shape for any hyperparameter
   sweep — it's strictly stronger than "best on golden" and also catches
   "this fixture was tuned to make the test pass."

2. **Promote `static const` → constructor parameters with named defaults
   matching the constants** when calibration tests need to sweep. `const
   ViterbiContextProcessor()` keeps working at every call site. The doc
   comment ("production code should not pass these arguments") tells
   readers the new API exists for tests, not for runtime configuration.
   Don't go further (e.g. environment-driven threshold) unless production
   actually needs it — keep the surface minimal.

3. **Print-then-assert calibration tables.** Each test emits a
   formatted table to stdout (band/n/correct/accuracy or
   threshold/above/accuracy/P/R/F1) before asserting loose invariants
   (monotonicity allowing 1 inversion, top-vs-bottom band ≤5pp, held-out vs
   golden aggregate ≤5pp). Tables give a "free regression diff" in test
   logs when a refactor drifts the numbers — same pattern as BUT-696,
   reapplied to a multi-axis sweep.

4. **Decision metric ≠ diagnostic metric.** The threshold gates emission
   anchoring, so the right success metric is end-to-end post-Viterbi
   *accuracy*, not P/R/F1. F1 with "above-threshold" as the positive class
   would have flagged 0.60 as the winner, but the gain is mechanical
   (recall inflates because almost every line is correctly classified, so
   widening the positive set inflates recall regardless of whether
   anchoring helped). Test still prints F1 as a diagnostic so future
   readers can see why it's not the decision driver. The same anti-pattern
   surfaces in any "threshold + structurally-imbalanced classes" scenario:
   pick the metric the *system* optimizes for, not whichever metric is
   easiest to compute.

5. **Calibration baseline as a committed `.md` next to the test.** The
   baseline file documents the actual numbers, the decision, the honest
   residuals (sparse confidence range, small-corpus artifact in the
   `[0.80, 0.90)` band on golden), and explicitly why F1 is not used. This
   is documentation that the test itself can't carry — assertions must
   be loose to avoid brittleness, but the prose can be specific. When a
   future engineer asks "why is the threshold 0.75?", the baseline file
   answers in one read.

6. **Header-phrasing reuse is intentional, not leakage.** Held-out set
   shares one header phrase ("Det här behövs:") with the golden set, but
   pairs it with completely different food vocabulary (yeast dough vs
   creamed spinach). This is a *generalization probe*: does the
   classifier+Viterbi handle the structural pattern when the surrounding
   words are unfamiliar? Vocabulary, recipe names, and dish types are
   fully distinct between corpora. When reviewing held-out corpora, look
   for vocabulary overlap (would be leakage), not phrase overlap (often
   intentional generalization probes).

Determinism note: tests run in <1s with no random sampling, no clock
calls, no I/O — pure functions over fixture corpora. Re-running yields
byte-identical numbers. Verified: 6/6 green, `flutter analyze` clean.

No production bugs caught this run. The calibration measurement
*confirmed* the hardcoded 0.75 was already correct (end-to-end accuracy
flat across `[0.70, 0.90]` on both corpora; only 0.60 materially
degrades). The value of the test is now twofold: (a) it's the
empirical evidence for the constant the next reviewer will ask about,
and (b) it's a regression gate if a future transition-matrix tweak
shifts the calibration curve.

### 2026-04-30 — BUT-458 fail-soft resolver test pattern [Pattern discovered]
`firebase_recipe_ownership_resolver_test.dart` (8 tests, all green) covers
a resolver that **never throws** — every failure mode (missing recipe,
orphaned recipe, callback exception, empty member map) returns `null`.
This is intentional: the caller (`FirebaseCommentsRepository.addComment`)
treats null as "skip denorm fields, let security rules degrade to
author-only read." The comment write must succeed even if ownership
resolution fails.

Test-shape implications, distinct from typical "throw on bad input"
repos:

1. **Test the null contract per failure mode, not just one.** Four
   separate tests pin null returns for four different upstream
   failures (recipe absent, recipe present but no owner data, callback
   throws, empty memberPermissions). A single "returns null on bad
   input" test would let a refactor that handles only one failure
   slip through. Each null path corresponds to a different production
   degrade-mode (recipe deleted vs. legacy schema vs. Firestore error
   vs. fresh collab-recipe with no members) — they look identical to
   the test but have different debug paths in production.

2. **Pair the unit tests with one happy-path + one fallback wiring
   test through the real caller.** The two `addComment with resolver
   wired` tests instantiate the real `FirebaseCommentsRepository`
   against `FakeFirebaseFirestore` and assert the doc-level effect:
   when resolver returns a snapshot, `recipeOwnerId` +
   `sharedWithUserIds` land on the doc; when resolver returns null,
   `data.containsKey('recipeOwnerId') == false` AND
   `sharedWithUserIds == []`. This is the right shape because the
   *security rule's `in []` operator* depends on the empty-list
   fallback being present rather than missing — a "didn't crash" test
   would miss that.

3. **Owner is in `recipeOwnerId`, not in `sharedWithUserIds`.** The
   collaborative-recipe test explicitly asserts `isNot(contains('owner-uid'))`
   on the shared list. This pins the contract that drives the rule
   structure (owner-branch vs. shared-branch are mutually exclusive
   in the rule's `allow read` predicate). Future refactors that
   "helpfully" duplicate the owner into the shared list to simplify
   the rule would surface here.

Pattern is reusable for any resolver/coordinator that's intentionally
fail-soft (returns null/empty rather than throwing) because the
*caller* needs the operation to keep going. Don't apply this to
resolvers where missing data should be a hard error — those want
`throwsA(...)` tests instead.

### 2026-05-01 — BUT-746/747/748 GDPR cascade close-out [Pattern discovered + Bug found]
Sprint 2026-05-01 closed three documented residuals from the BUT-671 GDPR
cascade work. Test side: `account_deletion_residual_test.dart` flipped
two `_expectMatchingExists` tripwires to `_expectNoMatching` (BUT-746
top-level `menus` orphans, BUT-747 `sharedToUserIds` array scrub) and
re-pointed the incoming-blocks query to canonical `blockedId` (BUT-748).
Sibling `data_export_service_test.dart` got a new
`exportIncomingBlocks queries canonical blockedId field` test that would
have failed under the prior `blockedUserId` query — proper regression
gate, not a smoke test.

Patterns / gotchas worth not losing:

1. **Documented-residual tripwire pattern works.** BUT-671's original
   author pinned three `_expectMatchingExists` assertions with
   "TRIPWIRE: when this fails, the bug is fixed — flip to
   `_expectNoMatching`" comments. That's exactly what happened in this
   sprint: production code closed the gap, the assertion went red, the
   author flipped the matcher and updated the file header. Comment
   prose carries the *next action* the test alone can't express.
   Reusable for any "we know this is wrong, but the fix is out of
   scope for this commit" situation.

2. **`FieldValue.arrayRemove` + `fake_cloud_firestore` + batched
   `update` = silent no-op.** Agent A's BUT-747 fix uses an explicit
   read-modify-write (`raw.where((id) => id != userId).toList()`)
   inside the batch update rather than `arrayRemove`. Production code
   carries a comment naming the fake-firestore behaviour: "some
   fake-Firestore versions don't honour the array transform inside a
   batched update; the explicit list rewrite is unambiguous and the
   per-doc cost is identical on real Firestore." When writing array-scrub
   code that must be testable under `FakeFirebaseFirestore`, prefer
   read-modify-write. If `arrayRemove` is non-negotiable (e.g. you need
   the atomic semantics under contention), test on the emulator lane
   instead. Symmetric `arrayUnion` has the same caveat — verify before
   relying on it inside a batch.

3. **Field-name canonicalisation is a real GDPR risk surface.** BUT-748
   was a pure naming bug: `FirebaseBlockRepository` writes/queries
   `blockedId`, but `FirebaseDataExportRepository.exportIncomingBlocks`
   queried `blockedUserId`. The export path silently returned zero
   incoming blocks for every user — a GDPR Art 15 (right of access)
   violation that no behavioural test caught for months. Lesson: when a
   field name appears in *two* repos, write at least one cross-repo
   integration test that round-trips the field (writer-repo writes,
   reader-repo reads, asserts non-empty). Don't trust string-equality
   review alone — it's the test category that catches typos and rename
   drift. Add this to repo-pair test checklists going forward.

4. **Test-only `_expectNoMatching` after a tripwire flip should keep
   the same `field` argument and just change the matcher.** Agent A
   could have moved or rewritten the assertion block; instead they
   surgical-edited the matcher + the `why` string. Clean diff, easy
   review, and the test's intent is unchanged ("after deletion, no
   menus should exist with sharedByUserId == deletedUid"). Don't take
   the opportunity to refactor unrelated structure when flipping a
   tripwire — the diff is the proof of "this was a known bug, now
   fixed" and a noisy diff dilutes that signal.

Sprint coverage on the staged files:
- `lib/repositories/firebase/firebase_data_export_repository.dart`:
  16/16 in `data_export_service_test.dart` (incl. new BUT-748 test).
- `lib/services/account/account_deletion/content_deletion_operations.dart`:
  1/1 in `account_deletion_residual_test.dart` (single integration-style
  test iterating all collections — tripwires now flipped green).
- `lib/viewmodels/onboarding_viewmodel.dart`: 8/8 in
  `onboarding_viewmodel_test.dart`.
- `lib/views/onboarding/onboarding_view.dart`: 15/15 across four widget
  tests (`onboarding_age_gate_page_test.dart`,
  `onboarding_allergen_page_test.dart`,
  `onboarding_dietary_page_test.dart`,
  `onboarding_landscape_overflow_test.dart`) + 2/2 in
  `onboarding_journey_test.dart`.
- `lib/core/di/modules/{core,ui}_module.dart` and `lib/main.dart`:
  no direct tests (DI/bootstrap — covered transitively by every
  ViewModel test that goes through `production.ServiceLocator.initialize`).
  No coverage gap to file.

Total: 42/42 green for the sprint. Two production bugs caught by the
cascade re-test (BUT-746 + BUT-747) — both surfaced by the tripwire
pattern when the production cascade was extended. BUT-748 caught by
the new direct-query test, which is the kind of cross-repo
field-name regression that's worth seeding as a checklist item.
