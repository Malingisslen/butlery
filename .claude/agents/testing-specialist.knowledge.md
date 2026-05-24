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

### 2026-05-01 — BUT-688/691/623/599/662 sprint review [Pattern discovered]
Sprint added five new test files (47 tests, all green): win-back
attribution service (10), user-property bootstrap (5), analytics-service
typed-probe group (3), image-format detector (13), HEIC converter (7).
Reviewed for "tests verify behavior, not structure" — passed. Patterns
worth not losing:

1. **Pluggable callable typedef beats plugin-channel mocks.**
   `HeicConverter` exposes a `typedef HeicCompressFn = Future<Uint8List?>
   Function(Uint8List bytes, {required int quality})` with a default that
   wires `FlutterImageCompress.compressWithList`. Tests pass an inline
   closure that captures `quality` and returns canned bytes. Zero plugin
   channel mocks, zero `setMockMessageHandler`, runs in <1s. Apply this
   pattern any time a service wraps a Flutter plugin where you only need
   to assert the input/output contract, not the plugin's behavior.

2. **Inline byte-fixture pattern for binary-format detectors.** Magic-byte
   tests construct `Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...])`
   inline rather than loading real image files from disk. Same idea as
   the Viterbi `*_fixtures.dart` pattern but inverted: when fixtures are
   tiny and self-documenting (4-12 bytes per case), inline them; when
   fixtures are large and hand-curated (full Swedish recipes), sibling
   `_fixtures.dart` file. Don't load real `.heic`/`.jpg` files for
   detector tests — the detector reads exactly the first ~16 bytes
   anyway, and disk I/O is dead weight in unit tests.

3. **`ServiceLocator.get<T>()` swap-with-GetIt for mocking lazy
   singletons.** When production code does
   `ServiceLocator.get<WinbackAttributionService>().attemptAttribution(...)`
   inside a fire-and-forget call, you can't constructor-inject a mock.
   Test infrastructure pattern:
   ```dart
   setUpAll(() => prod.ServiceLocator.initialize(DIContainer()));
   setUp(() {
     final getIt = GetIt.instance;
     if (getIt.isRegistered<WinbackAttributionService>()) {
       getIt.unregister<WinbackAttributionService>();
     }
     getIt.registerSingleton<WinbackAttributionService>(mockWinback);
   });
   tearDown(() {
     if (getIt.isRegistered<WinbackAttributionService>()) {
       getIt.unregister<WinbackAttributionService>();
     }
   });
   ```
   The two ServiceLocators (production wraps DIContainer, test uses GetIt
   direct) share the same `GetIt.instance`, so registering against GetIt
   makes the production `ServiceLocator.get<T>()` resolve to the mock.
   Confirmed working in `analytics_service_test.dart` "Win-back probe on
   typed delegate paths" group. Same pattern documented in MEMORY.md
   2026-02-09.

4. **`Future.delayed(Duration.zero)` IS acceptable in tests for
   fire-and-forget probes.** General rule still stands ("no
   `Future.delayed(Duration(seconds: N))` in tests") but `Duration.zero`
   is just an event-loop pump — needed when production code uses
   `// ignore: discarded_futures` to fire-and-forget a probe. The test
   awaits zero-delay, then `verify()` against the mocked dependency.
   Don't reach for `fakeAsync` here — there's no actual clock dependency
   on the production path; it's just async-microtask scheduling.

5. **`debugClearFieldsCalls` counter beats asserting deleted-field
   doc shape.** The `WinbackAttributionService` exposes
   `int get debugClearFieldsCalls` so tests can assert "we attempted to
   clear the bridge fields" without depending on `fake_cloud_firestore`'s
   `FieldValue.delete()` semantics (which drift across versions —
   confirmed in BUT-746/747 sprint notes). When you need to test "the
   side effect was attempted" but the post-effect state is fragile under
   a fake, count invocations on a `// visible for testing` getter on the
   subject. Cleaner than capturing `verify(() => mockRepo.update(any()))`
   when the production code doesn't go through a mockable boundary.

Coverage gaps documented for follow-up sprint:
- `PhotoImportStrategy` HEIC integration: detector + converter tested
  in isolation but the `import()` method's wiring (does it call the
  converter when format is HEIC, does it populate `image_format` /
  `image_format_sent` in metadata?) is untested. Existing
  `photo_import_strategy_test.dart` was not updated this sprint.
- 7-day boundary in `WinbackAttributionService` uses strict `>` — no
  test pins the exact `now - 7d ± 1s` boundary. A future refactor to
  `>=` would silently change behavior with no test failure. Would
  require a clock seam (`package:clock`) for deterministic boundary
  testing, which the production code doesn't currently support.
- 5 of 8 HEIC fourcc brands untested (`hevc`, `hevx`, `msf1`, `heis`,
  `hevs`). `mif1` covers ~95% of iPhone photo libraries so impact is
  low; a parameterized test iterating all 8 would close this for ~10
  LoC.

No production bugs caught this run — all sprint changes are additive
(new attribution service, new format detector, new typed probe sites).
Tests verify the new contracts cleanly. Sprint approved.

### 2026-05-02 — BUT-751/752/692/732 multi-listener + path-token sprint review [Pattern discovered]
Sprint reviewed 88/88 green across three test files. Patterns worth not
losing:

1. **`GetIt.asNewInstance()` for helper-function tests over container.** The
   new top-level `hasAnalyticsConsent(GetIt)` helper takes a `GetIt`
   directly so tests don't need the production ServiceLocator bridge.
   Each test creates `container = GetIt.asNewInstance()` in `setUp` —
   no shared global state, no `unregister` ceremony, no setUpAll
   coordination. Use this pattern any time a helper accepts a GetIt
   container as a parameter rather than calling `GetIt.instance` itself.
   The deny-on-unregistered case becomes a one-line test instead of a
   teardown puzzle.

2. **Multi-listener API: test the failure modes the API was designed
   to fix.** The BUT-752 group covers exactly the bugs the prior
   single-callback API enabled: (a) two co-subscribers (FCM +
   SearchModule) — the test name even calls out the real-world wiring
   that broke; (b) listener-throws-doesn't-block-others — defence in
   depth against bad subscribers; (c) idempotent-add — pins the contract
   that `Set<VoidCallback>` (not `List`) is the right backing structure.
   These aren't structural tests; each one would have caught a real
   regression if the implementation chose the wrong data structure.
   Reusable for any "we just migrated single→multi callback" review:
   the listener-throws and idempotent-add cases are the two most-skipped
   tests, and they're both load-bearing.

3. **Negative-space slug tests for opaque-token redaction.** The
   `scrubUrlParams` group pairs each redaction case (Algolia / UUID /
   JWT / hex hash) with a **slug-keep** counter-case at the *same
   length range*: 21-char Swedish slug (kept), 19-char opaque (kept,
   below threshold), 32-char hex (redacted). Without the keep-cases
   the tests would pass with `s/.*/:redacted/` and prove nothing about
   the heuristic. The "longest unsplit run is 9 chars" comment on the
   long-slug test pins the *reason* the heuristic decides keep vs.
   strip, so a future tweak that flips the rule (e.g. "strip on total
   length" instead of "longest unsplit run") immediately surfaces.
   Reusable shape: any redaction-by-heuristic test must pair every
   "should strip" with a "should keep" at adjacent thresholds.

4. **Schema-correction comments document why the fixture changed.**
   `social_deletion_operations_test.dart` carries inline `BUT-732:`
   comments naming the correction (`views`/`dismissals` were phantom,
   `ownerId` → `sharedByUserId`). This is the right way to mark
   fixture corrections that aren't behaviour changes — the diff alone
   would read as "moved fields around" but the comment proves the
   prior fixture was *wrong*, not that the contract changed. Production
   code is the source of truth; when test fixtures use field names not
   in the production schema, the test was passing for the wrong reason.
   Spot-check pattern for any "delete-cascade" test: grep production
   for the field/collection name used in the fixture; if it's missing
   or rare, the fixture is a phantom.

Mock discipline check: `MockFirebaseConsentRepository` mocks the
**dependency** (the repo) — subject under test is `ConsentService`
itself. Correct. `_MockMessagingRepository` same shape. No subject-mocking
anywhere. No Mock-with-`@override`-bodies — clean.

No new bugs caught this run — all three changes are additive (new
helper, new listener API, fixture corrections). Sprint approved.

### 2026-05-02 — BUT-752 simplify pass: idempotent-add drop [Pattern discovered]
Re-review of the simplify pass on `consent_service_test.dart`:
`addConsentChangeListener` / `removeConsentChangeListener` renamed to
`addListener` / `removeListener` to match `Listenable`, and the
"duplicate add registers once" test was DROPPED.

Drop is honest, not a weakening. Rule for future "we just adopted
Flutter's `Listenable`/`ChangeNotifier`" reviews: the contract you
must test is *Flutter's*, not the prior bespoke API's. `ChangeNotifier`
documents "identical listener added twice fires twice" — the inverse
of the prior `Set`-backed idempotent behaviour. A test pinning the old
behaviour would lock the implementation to a `Set`, defeating the
point of conforming to `Listenable`. Confirm the call sites don't
rely on idempotent-add (here: FCMService uses `executeOnce`,
SearchModule does pre-emptive `removeListener` in `configureUserScope`)
before dropping. If a consumer DID rely on idempotent-add, the right
fix is to wrap that consumer's registration, not to pin the service's
data structure.

The retained 6 listener tests cover the contract that survives the
next refactor: single fire, no fire on failed save, no-listener safety,
multi-listener fan-out (the BUT-752 reason the API was migrated),
removal by identity, and listener-throws-doesn't-block-others. No
"duplicate-add doesn't crash" test is needed — that's a `ChangeNotifier`
invariant, not a Butlery one.

Anti-pattern caught & avoided: in BUT-368/369 we deleted ~11.5k LoC
of structural tests because they pinned the old implementation. The
idempotent-add test was an early form of that anti-pattern (pin the
data structure choice rather than the user-visible contract). Drop
was correct.

### 2026-05-02 — BUT-573 / BUT-434 sprint review: untestable-by-design assessment [Pattern discovered]
Sprint touched two `lib/` files with new behaviour and a clean answer for
both was "the existing test pattern IS the project norm — not a coverage
gap to chase."

1. **`fcm_service.dart` `_revokePushAccess()` + revoke branch in
   `_onConsentChanged()`.** Untestable without a refactor:
   - `_messaging` is `static final FirebaseMessaging _messaging =
     FirebaseMessaging.instance` — initialised at class-load, no seam.
   - `_onConsentChanged()` and `_revokePushAccess()` are private static
     methods.
   - Static state (`_pushPermissionsRequested`, `_consentChangeInProgress`)
     gates whether the new branch even runs.
   - The call to `ServiceLocator.get<UserService>().clearFCMToken()` could
     in principle be verified via the GetIt swap pattern (BUT-688/691 entry
     above), but the test still couldn't trigger `_onConsentChanged` itself
     — and verifying the second of three side effects while the first
     (`_messaging.deleteToken()`) is unobservable proves nothing useful.

   The existing 23-test file documents the constraint in its header
   ("FCMService uses static methods with a static FirebaseMessaging
   instance. In test environments, the real FirebaseMessaging.instance
   is used. Methods that interact with Firebase infrastructure will fail
   gracefully via safeExecute/try-catch."). The new code follows the
   same pattern (each `await _messaging.deleteToken()` /
   `await userService.clearFCMToken()` is in its own try/catch with
   AppLogger.warning on failure). No coverage gap to file.

   If a future refactor needs to make this testable, the minimum-viable
   seam is to change `_messaging` from a `static final` to a
   `@visibleForTesting` mutable static (or constructor-inject the
   service). Don't add `@visibleForTesting` accessors for the private
   methods alone — that just exposes implementation without providing a
   way to fake `FirebaseMessaging`.

2. **`deep_link_handler.dart` `receive_intent` → `app_links` migration.**
   Same shape: `AppLinks()` is constructed inline inside `initialize()`,
   no seam. The one-line plugin call `await AppLinks().getInitialLink()`
   is mechanically equivalent to the old `receive_intent.ReceiveIntent.getInitialIntent()`.
   The interesting behaviour (URL parsing, route resolution, pending-link
   handling) lives in `DeepLinkService` (85 tests, all green post-migration).

   No `DeepLinkHandler` test file exists — and shouldn't be created for
   this commit. Adding a test that just asserts "the initialize method
   doesn't throw on web" would be exactly the structural smoke test
   BUT-368 deleted 11.5k LoC of. The migration's behavioural risk is
   "does the initial link still get parsed correctly?" — covered by the
   DeepLinkService tests, which run the parser on the same input format.

3. **B2 mechanical RTL changes (11 widget/view files).** `EdgeInsets.only(left/right)`
   → `EdgeInsetsDirectional.only(start/end)`, `Alignment.centerLeft` →
   `AlignmentDirectional.centerStart`, `TextAlign.left` → `TextAlign.start`.
   Mechanical directional-aware swap — produces identical visuals in LTR
   (Swedish app locale), correct visuals in RTL (currently no RTL locale
   shipped). Per BUT-387 Phase 6, per-view tests aren't a target. Golden
   tests on these widgets would catch a *visual* regression (none here),
   not a directional-correctness bug (proven by the swap being mechanical
   and Flutter's own widget contract).

4. **`app_dimensions.dart` `paddingOnlyLeft8` → `paddingOnlyStart8` +
   3 dead constants deleted.** Pure constant rename + dead-code removal.
   Single call site updated. No test target — these are spacing tokens,
   not behaviour.

Decision rule emerging from this review: **"new lines of production code"
≠ "new test surface."** When the new code is a private method on a
class with no DI seam, called from another private method, gated by
static state, operating on a static-final external dependency — the
honest answer is "this is architecturally untestable in isolation;
the integration path catches it." Document the constraint in the
review (commit body or marker note), don't manufacture a smoke test
that proves nothing.

Sprint approved: 23/23 green for FCM, 85/85 for DeepLinkService, 9/9
for account-deletion integration. No new test files needed. Marker
written.

### 2026-05-02 — BUT-754 parallel consent listener wire-up [Pattern discovered]
Sprint added `NotificationService._handleConsentChange` — a sibling
consent listener to FCMService's existing one. FCMService handles SDK +
Firestore + memory teardown on revoke; the new NotificationService
listener handles the FCMTokenManager SecureStorage cleanup that
FCMService can't reach (different lifecycle — FCMTokenManager is
per-user, FCMService is process-wide).

The new `clearLocalToken()` got two direct unit tests in
`fcm_token_manager_test.dart` (deletes both keys + nulls memory;
idempotent on empty store). The NotificationService listener wire-up
got NO new test. Reviewed and confirmed defensible:

1. **Listener wire-up has no behaviour the components don't already
   cover.** The whole listener body is: read consent state via
   `ConsentService.checkSafely` (already tested in consent_service tests
   with the multi-listener BUT-752 group), if revoked call
   `_tokenManager?.clearLocalToken()` (now tested in
   fcm_token_manager_test.dart), guarded by `_consentHandlerInProgress`
   reentrancy bool. There is no transformation, no decision logic, no
   contract beyond "fan out to the right downstream." A test would have
   to construct a real `NotificationService` (which constructs ~10
   modules + hits `production.ServiceLocator`), inject a fake
   `ConsentService`, fire its listeners, and assert
   `verify(() => mockTokenManager.clearLocalToken())` — testing the
   *plumbing*, not the user-visible behaviour. That's the structural
   anti-pattern BUT-368 deleted ~11.5k LoC of.

2. **Same shape as the FCMService consent listener (which we
   documented as untestable-by-design in the BUT-573/434 entry above).**
   Both listeners are private methods triggered by an external
   listenable. The difference is that FCMService's listener has
   *unobservable* side effects (`FirebaseMessaging.instance.deleteToken`
   on a static-final SDK), while NotificationService's listener has
   *already-tested* side effects. Either way, the "does the listener
   actually fan out correctly?" question is answered by the
   ChangeNotifier contract (BUT-752 multi-listener tests) plus the
   downstream tests, not by a per-listener wire-up test.

3. **The reentrancy guard (`_consentHandlerInProgress`) is the one
   thing that *would* be worth pinning if the listener got more
   complex.** Currently the body is `await
   ConsentService.checkSafely(...)` + optional `await
   _tokenManager.clearLocalToken()`. Neither call goes back into
   ConsentService, so re-entrance can't happen via the production
   call graph — the guard is belt-and-braces against a future
   refactor that adds a notify cycle. If a future change makes the
   listener call something that *can* trigger consent change (e.g.
   updating a setting that's wired to a consent gate), add a single
   unit test that fires the listener twice quickly and asserts
   `clearLocalToken` is called exactly once. Today that test would
   prove only that "false stays false on a flag we just toggled."

Decision rule: **a fan-out listener whose body is `read state →
forward to one already-tested method` does not need its own test.**
The risk surface is "is the listener actually subscribed?" (proven by
BUT-752 multi-listener tests on ConsentService — `addListener` /
`notifyListeners` behaviour is correct) and "does the downstream
handle the call?" (proven by `fcm_token_manager_test.dart` BUT-754
group). The wire-up itself is structural plumbing.

If the listener body grows to include real logic (debouncing, state
transformation, conditional fan-out to multiple downstreams,
metric/analytics emission), promote it to a testable seam — extract
the body into a public method that takes the consent state as a
parameter, and unit-test that method directly. Today's body doesn't
warrant that overhead.

Sprint approved: 22/22 green for FCMTokenManager (incl. 2 new
BUT-754 tests), 23/23 green for FCMService. Pre-existing flakes
(notification_content_manager, notification_preference_manager,
calendar_weekly_menu_widget week-nav button) confirmed pre-existing
via the user's `git stash` check — not regressions.

### 2026-05-02 — BUT-755..758 color-token migration: hardcoded-AppColors finder caught a real regression [Bug found]
26-file BUT-572 wave migration (115 sites swapping `AppColors.X` → `cs.X`
or `context.butleryColors.X`). Sample-run of `test/widget/social/`
exposed `family_presence_bar_test.dart` failing 1/4 dependent tests:
`findOnlineDot()` predicate compared `decoration.color ==
AppColors.forestGreen` (the literal `0xFF4A7C59`), but production now
reads `cs.primary`. The test's `wrap()` built a bare `MaterialApp` with
no `theme:` — so `cs.primary` resolved to Material's default purple, not
forestGreen, and the finder returned zero matches.

This is exactly the DO-NOT-WRITE pattern in `testing-specialist.md`:
"No hardcoded theme values" + "Capture `ColorScheme` via a `Builder`."
The original test pre-dated the migration and pinned a literal — when
production stopped using the literal, the finder broke.

Fix: install `theme: AppTheme.lightTheme` on the test's `MaterialApp`.
That keeps the literal-color predicate valid (because production's
`lightColorScheme.primary` *is* `forestGreen` — same hex), and as a
bonus makes the test theme-faithful. Surgical 2-line edit to `wrap()`
+ comment update on `findOnlineDot()`. All 5 family-presence tests
green post-fix. Surveyed the rest of `test/` for similar patterns —
only this one file used `AppColors` for production-color matching
(the other `AppColors` references are contrast/asset tests, not
migration risk).

Pattern reminder for any future "swap hardcoded colors for theme
tokens" sprint: **grep `test/` for `== AppColors\.` and `==
AppDimensions\.` before claiming the diff is mechanically safe.**
Tests that pin literals on the *production output* break the moment
the production source-of-truth changes, even when the rendered hex is
identical. The right long-term fix is to capture `ColorScheme` via
`Builder` in test setup and assert against `cs.X` directly, but
"install the matching production theme on the test MaterialApp" is
the minimal-diff fix that doesn't lock the test to a specific hex.

Sprint coverage assessment:
- iconMuted unit tests (6/6) cover the right contract — light/dark
  literal hex (regression gate against accidental brand-color change),
  `copyWith` preserve+override, lerp interpolation, end-to-end Theme
  wiring via `context.butleryColors.iconMuted`. Test #6 has a minor
  smell — uses `runApp` + `endOfFrame.then` instead of
  `tester.pumpWidget` + sync `expect`, so the `expect` runs in a
  dangling future after the test completes; if it ever fires it'd be
  outside the test's reporting window. Not blocking (the resolved
  value is also pinned by tests 1-2 via the static accessor), but
  worth converting to a `testWidgets` block on the next touch.
- 20+ migrated widgets without dedicated golden tests: confirmed
  byte-identical migration (every replaced color resolves to the same
  hex via `lightColorScheme`), and BUT-572 pilot's
  `calendar_weekly_menu_populated.png` golden already proved this.
  Adding goldens for previously-untested widgets is correctly out of
  sprint scope — that's a separate "expand golden coverage" ticket.
- `getSocialColorScheme` API change (optional → required `BuildContext`):
  zero stray no-arg callers anywhere in `lib/` or `test/`, fallback was
  dead code. No isolated test needed; the function's behaviour (map of
  semantic-role → ColorScheme color) is contract-trivial and any caller
  that ships a regression would break that consuming widget's tests
  directly.

Tests run this review: 83/83 green across iconMuted unit + 9 sampled
widget test files (styled_input, step_timer, cooking_session_card,
substitution_bottom_sheet, family_presence_bar, activity_pings_feed,
ping_compose_sheet, duplicate_merge_sheet, heirloom_stamp,
seasonal_hero_header, cooking_mode_touch_target). Pre-existing flakes
(notification_content_manager, notification_preference_manager,
calendar_weekly_menu_widget week-nav) NOT re-run — already
characterised in prior sprint, not regressions.

### 2026-05-02 — BUT-600 parsing-golden tier coverage [Pattern discovered]
Extended `test/golden/parsing_golden_test.dart` (was 4 SchemaOrg-only
entries) to cover all three substantive parsing tiers: 4 SchemaOrg + 5
RuleBased + 4 LLM = 13 dataset entries, all green. The dataset JSON
gained a `tier` discriminator (`schemaOrg` | `ruleBased` | `llm`) plus
per-tier input keys (HTML `fixture` reference / inline `text` /
`mockResponse` ExtractedRecipe JSON).

Key patterns / decisions worth not losing:

1. **Service-level seam beats HTTP seam for LLM golden tests.** The
   `LlmService.structureRecipe` boundary is the cleanest mock point —
   `LlmTier` calls into `LlmService`, which itself wraps
   `FirebaseFunctions.httpsCallable`. Mocking at service level keeps the
   golden suite hermetic (no Firebase init, no `MethodChannel` plumbing,
   <100ms per test) while still exercising the **tier contract**:
   validation, normalisation, partial-recipe fallback, suspicious-pattern
   gating. The `_GoldenMockLlmService implements LlmService` shape (with
   `noSuchMethod` fall-through and `nextResponse` field) is identical to
   `MockLlmService` in `test/unit/services/parsing/tiers/llm_tier_test.dart`
   — copied inline rather than extracted to a shared helper because the
   golden suite has only one consumer and the unit suite has only one
   consumer; extracting would have added a 6th file that the BUT-600
   constraint cap forbade. If a third consumer appears, extract.

2. **Probe-then-pin for RuleBasedTier expected outputs.** Wrote a
   throwaway `_scratch_rule_based_probe.dart` that ran each candidate
   plaintext through the real tier and printed actual ingredient/instruction
   lines, then deleted it before commit. Lets fixtures pin **what the
   tier actually emits**, not what it "should" emit. Caught one real
   quirk: the `kottgryta` fixture's `"Det här behövs:"` header line
   passes through as an ingredient. Fixture documents this in `_note`
   instead of "fixing" it with an aspirational assertion. Same shape as
   the BUT-696 sibling-fixtures pattern (probe to discover, then pin).

3. **Loose assertions survive parser tweaks.** Each `expected` block uses
   `titleContains` / `ingredientCountMin` (not `ingredientCount`) /
   `ingredientSubstrings` / `instructionCountMin`. A future RuleBased
   refactor that splits one ingredient into two, or merges two instructions
   into one, won't break the suite as long as the user-visible recipe is
   still correct. Tight equality assertions on the exact list lengths
   would have made this dataset a chore to maintain after every tier
   tweak — exactly the BUT-368 anti-pattern.

4. **CI invocation needed updating — `test/golden/` was not picked up.**
   `.github/workflows/test.yml` ran `flutter test test/unit test/widget
   test/views`. The golden parsing + tagging suites lived in
   `test/golden/` and were quietly excluded from CI. Extended the
   command to `flutter test test/unit test/widget test/views test/golden`.
   Worth checking on every "add a new test directory" sprint — `test/`
   has accumulated `unit/`, `widget/`, `views/`, `integration/`, `golden/`,
   `infrastructure/`, `test_support/` over time and each one needs to
   be either explicitly listed or covered by a wildcard.

5. **Mock-Gemini fixture format = `ExtractedRecipe.toJson()` shape.**
   `mockResponse` JSON in dataset entries maps directly to
   `ExtractedRecipe.fromJson` — `title`, `portions`, `prepTimeMinutes`,
   `cookTimeMinutes`, `ingredients[]` with `amount`/`unit`/`name`/`preparation`,
   `instructions[]`. Recording from real Gemini = grab the `recipe` field
   off `StructureRecipeResponse` and paste it into the dataset. README
   documents the record-vs-replay flow.

Files added/changed (4 of 6 budget):
- `test/golden/parsing_golden_test.dart` (rewritten — tier dispatch,
  shared assertion block, `_GoldenMockLlmService`)
- `test/golden/parsing_golden_dataset.json` (added 9 entries — 5
  RuleBased + 4 LLM; existing 4 SchemaOrg entries unchanged except
  for added `tier: "schemaOrg"` field)
- `test/golden/README.md` (new — entry shape, tier seams,
  record-from-Gemini flow)
- `.github/workflows/test.yml` (one-line: added `test/golden` to the
  `flutter test` command)

No production bugs caught — RuleBasedTier and LlmTier were both already
behaviourally correct on the candidate fixtures. The value here is
forward-looking: a future Gemini model bump, prompt edit, or
SwedishLineClassifier tweak will surface in this suite before it
silently regresses parse quality on real user imports.

### 2026-05-04 — BUT-582 LlmException.fromFirebase coverage gap closed [Pattern discovered]
7-ticket sprint review (BUT-538 / BUT-534 / BUT-540 / BUT-616 / BUT-655 /
BUT-582 / BUT-531). Four of seven `lib/` files lacked direct test coverage.
Triaged each:

1. **`LlmException.fromFirebase` (BUT-582) — REAL gap, closed.** Added
   `test/unit/services/llm/llm_exception_from_firebase_test.dart` (7 tests,
   green). The function is a pure error-string → user-facing-copy mapping —
   the cheapest possible test seam (no Firebase init, no mocks, no DI), and
   the failure mode is high-impact (silent error-copy regression — user sees
   "Ett fel uppstod" instead of "Förfrågan tog för lång tid"). The new
   `deadline-exceeded` and `unavailable` branches each get a dedicated
   "must NOT equal `llmGenericError`" assertion — that's the regression
   shape: a refactor that accidentally drops the new `if` blocks would
   silently fall back to the generic bucket with no test failure unless
   you specifically assert the *negative* (not-generic). The Swedish↔English
   parity test (6 distinct messages) is the second guard rail: catches the
   accidental "two codes map to the same template" regression.

   Reusable pattern: **for any error-mapping switchboard, pin both the
   positive (this code → this message) AND the negative (this code !=
   generic-fallback message). The positive pins the happy path; the
   negative pins that future "simplification" doesn't collapse the
   branches back together.**

2. **`parse_event_logger.dart` `_emitFailureMetric` (BUT-616) — defensible
   skip.** Fire-and-forget metric emitter inside a `catchError` on an
   already-fire-and-forget callable. Two layers of try/catch by design
   ("never let metric emission cascade into a second failure path"). Any
   test would need to fake `FirebaseFunctions.instance.httpsCallable` to
   throw, then verify against an injected `AnalyticsService` mock — but
   the host class has no DI seam (`FirebaseFunctions.instance` accessed
   directly through `_functionsCache`), and the analytics emit path is
   already exercised by every other test that registers `AnalyticsService`.
   Same shape as the FCM/DeepLinkHandler "untestable-by-design" pattern in
   the 2026-05-02 BUT-573/434 entry.

3. **`notification_preferences_view.dart` `_logPreferenceChange` (BUT-655)
   — defensible skip.** Per BUT-387 Phase 6 + the `views/` CLAUDE.md, view
   tests aren't a target. The analytics call is `ServiceLocator.tryGet` +
   `analytics.logEvent(name: ..., parameters: {category, enabled, source})`
   — pure forwarding with a null-guard. A test would assert "the toggle
   handler called the mock analytics" — structural plumbing. The
   user-visible contract (toggle persists + announces) is covered by the
   existing notification-preferences manager tests. If the funnel ever
   shows "preference toggles dropped to zero," that's a dashboard-side
   alert, not a missing test.

4. **`report_content_dialog.dart` (BUT-531) — defensible skip for now.**
   New `TextField` + outcome record on a dialog with no existing test
   file. Same Phase 6 view-layer logic; the dialog's user-visible
   contract (text → outcome record) is contract-trivial and would be
   covered by a journey test if and when reporting flow gets one.

Decision rule confirmed: **of N untested production-changes in a sprint,
the right number to add tests for is "the ones where a regression would
silently change user-visible behaviour AND the test seam is cheap."**
Pure-function error-mapping passes both (cheap seam, high blast radius);
fire-and-forget metric emitters and view-layer fan-out callbacks pass
neither (no seam, low blast radius — already covered by downstream).
Don't manufacture structural smoke tests to fill in the matrix.

Sprint approved. Marker written.

### 2026-05-04 — Sprint D (BUT-589 / BUT-670 / BUT-766) review [Pattern discovered]
3 new test files, 11 tests, all green; `flutter analyze` clean. Reviewed
for behavioural focus, mock-vs-subject discipline, and seam quality.
All three files pass. Patterns worth not losing:

1. **Counter on a `Fake HttpsCallable` is the right shape for "did the
   integration call its dependency?" tests.** `_CountingHttpsCallable
   extends Fake implements HttpsCallable` with an `int callCount` field
   and a `call()` body that increments-then-throws. The CB regression
   gate's load-bearing claim — "4th call does NOT invoke the callable"
   — is encoded as `expect(callable.callCount, 3)` *after* the 4th
   `service.structureRecipe(...)` resolves. That's the correct shape:
   asserting the count *stayed at 3* across the 4th call proves the
   short-circuit, not just that the breaker reports open. A test that
   only asserted `breaker.isOpen` would let a refactor that opens the
   CB but still calls the callable slip through.

2. **Skip the `FirebaseFunctionsException` branch when the constructor
   is `@protected`.** The test file's comment names this explicitly:
   "Use a generic Exception (not FirebaseFunctionsException — its
   constructor is @protected so test code can't instantiate it
   directly). The CB increments on either branch of the LlmService
   catch handler; the test only cares that failures count, not which
   branch." Correct call — production code calls `recordFailure()`
   from both `on FirebaseFunctionsException catch` and the trailing
   `catch (e)`, so either branch exercises the breaker. Don't
   sub-class `FirebaseFunctionsException` to "cover both branches" —
   that's testing the catch-clause topology, not the breaker
   contract.

3. **`@visibleForTesting` getter on a private field is a reasonable
   seam when the field's only test exposure is read-only.**
   `LlmService.backendBreakerForTest` returns the injected
   `CircuitBreaker` so the test can assert `isOpen` without poking at
   `_backendBreaker`. The constructor already accepts an optional
   `CircuitBreaker? backendBreaker` param, so the test could
   instantiate its own and hold the reference (which it does) — the
   getter is belt-and-braces. Acceptable; not strictly needed for
   this test (the test holds the breaker reference directly via
   `breaker = CircuitBreaker(...)`), but harmless and cheap. If the
   test only inspected the locally-held reference, the getter could
   be removed; keep it as documentation of the test seam.

4. **`featureFlagServiceOverride` constructor parameter is the right
   widget-test seam.** Same pattern as
   `viewmodel_test_helpers.dart`-style constructor-injection — the
   widget exposes an optional override, production wiring leaves it
   null and falls back to `ServiceLocator.tryGet<FeatureFlagService>()`.
   Avoids the "register a fake in GetIt before pumping" dance that
   forces every test to coordinate global state. Confirmed: the
   `_StubFlagService` is a plain `implements FeatureFlagService` Fake
   (no Mock-with-`@override`-bodies — clean).

5. **`simulateConfigUpdate()` test helper on the stub is a reasonable
   seam for "does the gate react to mid-session flag flips?"** The
   gate registers a `addOnConfigUpdatedListener(_onConfigUpdated)` in
   `initState`; the stub stores the listener in `_listener` and
   exposes a public `simulateConfigUpdate()` that fires it. Test
   flips the flag value + calls `simulateConfigUpdate()` + pumps —
   asserts the blocker now appears. That's testing the live-update
   contract (gate must re-evaluate when Remote Config updates),
   which is the actual user-visible behaviour the BUT-670 listener
   wiring exists for. Correct shape.

6. **`Future<void>.delayed(Duration.zero)` micro-pump pattern reused
   for fire-and-forget verification.** The `tryLog` test uses 5
   zero-delay yields to let the `tryGet → consent check → logEvent`
   chain complete before `verify(() => repo.logEvent(...)).called(1)`.
   This mirrors the BUT-688/691 entry's "`Future.delayed(Duration.zero)`
   IS acceptable in tests for fire-and-forget probes" rule — there's
   no real clock to advance, just async-microtask scheduling.
   `fakeAsync` would add ceremony without value. Confirmed working in
   <100ms.

7. **Pin "no-ops when ServiceLocator has not been initialized" as a
   distinct test from "no-ops when service is missing."** These look
   identical at the call-site (`AnalyticsService.tryLog('demo')`) but
   exercise different code paths inside `tryGet` —
   "uninitialized container" vs "container present, type missing."
   Both must be silently safe because `tryLog` is called during
   bootstrap (where the container isn't yet wired) and during normal
   degraded mode (web with missing Firebase, etc.). Pinning them
   separately means a refactor that handles only one path surfaces
   immediately. Same shape as the 2026-04-30 BUT-458 "test the null
   contract per failure mode, not just one" pattern.

Coverage gaps explicitly considered, all defensible-skip:

- **CB resetTime expiry / half-open transition.** The CB unit at
  `lib/core/circuit_breaker.dart` has its own dedicated tests
  (`circuit_breaker_test.dart` covers the resetTime → half-open →
  recovery path with `withClock(...)`). The new BUT-589 file
  intentionally tests *the LlmService integration* (does opening
  the breaker actually short-circuit the callable?), not the breaker
  algorithm itself. Adding a half-open test here would duplicate
  the unit suite and couple the LlmService test to `package:clock`
  setup. Skip is correct.

- **`MaintenanceModeBlocker` widget at extreme text scale.** The
  blocker clamps `textScaler` to `[1.0, 1.5]` (production code, line
  39-46) — worth pinning eventually, but the assertion is on the
  MediaQuery clamp, which is a Flutter contract. Adding a widget
  test that shoves `MediaQuery(textScaler: 3.0)` and asserts the
  button is still on-screen would be a behavioural test (a11y
  guarantee that the retry button doesn't get pushed off-screen).
  Defensible skip for this sprint; flag for a follow-up a11y sprint
  if reduced-motion + text-scale testing gets a sweep.

- **`tryLog` with consent denied.** Production code: `tryLog →
  ServiceLocator.tryGet → analytics.logEvent` — and `logEvent` itself
  internally checks `_hasAnalyticsConsent()` before forwarding to the
  repo. The "consent denied" path is *already tested* in
  `analytics_service_test.dart` (the BUT-688/691 typed-probe group's
  "no-op when consent is missing" tests). Re-asserting it through
  `tryLog` would just exercise the same downstream branch via a
  thin wrapper. Skip is correct — consent gating is a property of
  `logEvent`, and `tryLog` is just a null-guarded forwarder.

Mock-vs-subject discipline check (per CLAUDE.md testing
philosophy point 3 — "Mock dependencies, not the subject"):
- BUT-589: SUT = `LlmService`. Mocked: `FirebaseFunctions`,
  `HttpsCallable`, `ImportRateLimiter`, `ConsentService`. Real:
  `LlmService`, injected real `CircuitBreaker`. Correct.
- BUT-670: SUT = `MaintenanceModeGate`. Mocked: `FeatureFlagService`.
  Real: `MaintenanceModeGate`, real `MaintenanceModeBlocker` rendered
  in the gate's build. Correct.
- BUT-766: SUT = `AnalyticsService.tryLog` (static helper). Mocked:
  `AnalyticsRepository`, `ConsentService`. Real: `AnalyticsService`
  instance + real `ServiceLocator` + real `GetIt`. Correct — the
  test exercises the actual `tryGet → null-guard → logEvent` chain
  with the SUT in the loop.

No production bugs caught this run — all three changes are
additive (new circuit breaker integration, new gate widget, new
helper method). Tests verify the new contracts cleanly. Sprint
approved.

### 2026-05-04 — Sprint F (BUT-682 / BUT-630) review [Pattern discovered]
Two test changes — new `ocr_usage_tracker_test.dart` (7 tests) + extended
`ping_service_test.dart` (7 new tests across 2 groups). Both green; analyze
clean. Patterns confirmed and gaps flagged:

1. **`same(<static-const-instance>)` is the correct identity assertion for
   routing tests against const strategy/config singletons.** The BUT-630
   strategies (`NotificationStrategy.pingNudge` etc.) are `static const`
   instances. `same()` pins "the router returns this exact canonical
   constant" — a `category`/`priority` field-match would pass for any
   future `pingNudgeV2` with the same attributes, defeating the regression
   gate. Reusable for any "router returns one of N canonical const
   instances" test.

2. **`Future<void>.delayed(Duration.zero)` is the established repo
   convention for fire-and-forget verification in async services** —
   already documented in BUT-688/691 entry; reaffirmed here for the
   PingService unawaited push path. Don't reach for `fakeAsync` when
   there's no clock dependency, just microtask scheduling.

3. **Gap caught — additionalData payload completeness in BUT-630 routing
   tests.** The new file asserts `additionalData['type'] == ping` but
   doesn't verify `pingId`/`groupId` round-trip into the FCM payload.
   The whole point of the additionalData map is the deep-link
   round-trip (recipient taps notification → app routes to the specific
   ping doc). A regression that drops `pingId` or `groupId` from the
   payload would not fail the suite. Worth a small follow-up assertion;
   not blocking sprint approval.

4. **Gap caught — symmetric negative for "no prefs interaction" test.**
   `ocr_usage_tracker_test.dart`'s "without loadFromPersistence, tracker
   is in-memory only" test asserts only that the counter increments. It
   doesn't pin that prefs are *not* touched. A regression where
   `_persistDaily()` falls back to `SharedPreferences.getInstance()`
   when `_prefs == null` would silently start writing to global prefs
   and the test would stay green. Same shape as BUT-582 "pin both
   positive AND negative for switchboard" rule — for any
   "without-init it's in-memory only" test, also assert prefs (or the
   external store) remains untouched. Recommend creating a separate
   prefs instance + asserting `getInt(...)` returns null after the
   in-memory `recordUsage` call.

5. **Concurrent-send tests are NOT a gap for single-isolate Dart
   services.** Question came up during this review; rule: PingService
   sends are sequential awaits at the call site (single-isolate event
   loop). A `Future.wait([...sends])` test would assert Dart's
   event-loop semantics, not the service contract. Rate-limit ordering
   is already covered by the burst test. Skip.

Mock-vs-subject discipline check:
- BUT-682: SUT = `OCRUsageTracker`. Real: `SharedPreferences` mock from
  the official plugin (`setMockInitialValues`) — not a hand-rolled fake.
  Correct shape; no over-mocking.
- BUT-630: SUT = `PingService`. Mocked (Fake): `FirestoreRepository`
  (wraps `FakeFirebaseFirestore`), `PermissionService`, `UnifiedFriendsService`.
  Notification service is `_RecordingNotificationService extends Mock`
  — but with concrete `@override sendImmediateNotification` body, which
  is the Mock-with-`@override`-bodies anti-pattern flagged in
  `testing-specialist.md`. Defensible here because the test never calls
  `when(() => mock...)` on it — it's purely a recorder. Renaming to
  `extends Fake` would be more honest (no `noSuchMethod` fall-through
  needed; the class only ever gets `sendImmediateNotification` called
  on it). Flag for next touch, not blocking.

Sprint approved with two follow-up items recommended (additionalData
payload assertion + in-memory prefs-untouched negative).

### 2026-05-05 — BUT-738 emitter extraction review [Pattern discovered]
Reviewed Sprint K extraction of `RecipeEditAnalyticsEmitter` from
`RecipePersistenceManager` (5 emitter tests, all green). No upstream test
file referenced the manager's analytics behaviour, so nothing needed to
move — `recipe_edited` / `post_import_edit` had no manager-level coverage
before the extraction (decider tests existed but not for the orchestration
layer). Pattern worth keeping: when extracting analytics emitters,
`grep test/ recipe_edited|post_import_edit|<methodName>` first; if no
hits, the emitter test is the new contract. `withClock(Clock.fixed(...))`
is the right tool for synchronous emitters that read `clock.now()` —
`fakeAsync` is only needed for time-elapsing async work (debounce, retry).
The 5 cases here capture: (1) recipe_edited with non-empty diff, (2)
no-sourceUrl gate, (3) within-window emit + tier_used forwarded, (4)
outside-window gate, (5) tier_used omitted when null — that's the full
behavioural contract; no implementation-detail asserts.

### 2026-05-06 — CF helper unit tests + integration gap (BUT-778, BUT-780)
**Trigger**: Pattern discovered + Coverage gap flagged

When Cloud Functions extract pure decision helpers (e.g. `detectFormat`,
`resolveUploaderUid`, `shouldReplaceLastMessage`), the unit-test pattern
in `functions/src/__tests__/` is to stub `process.env.FIREBASE_CONFIG`
+ `admin.initializeApp({ projectId: ... })` before `require()`-ing the
module — `firebase-functions` resolves trigger declarations eagerly at
module load and demands a bucket name. `require` (not `import`) the
helpers so the module-load hack runs first. Pattern is in
`moderate-upload.test.ts` and `sync-conversation-last-message.test.ts`.

**Coverage gap to remember**: pure-helper unit tests prove the helper is
correct in isolation but DON'T prove the CF actually calls it. A wiring
bug ("CF doesn't invoke `detectFormat` and just deletes nothing", "CF
calls helper but ignores null result") passes unit tests green. For any
CF where the security/cost decision lives in a helper, an emulator-lane
integration test (`*.integration.test.ts` gated on `USE_EMULATOR=true`,
Linux CI only) is the missing layer. Skip on Java-less dev boxes,
required on CI. Mirrors the Flutter `emulatorOnlySkip` pattern.

**Also remember**: when a helper resolves identity from path conventions
(e.g. `users/{uid}/...`, `feedback/{uid}/...`), audit the path patterns
against `storage.rules` / `firestore.rules` — if rules permit a path
the helper doesn't recognize, identity resolution silently returns null
in production. Test set must enumerate every permitted prefix.

**Deletion-test pairing rule**: when production code deletes a method,
deleting its tests is correct, not a coverage loss. The replacement test
should guard the *remaining* contract (e.g. "dispose without throwing"
after auto-healer removal in BUT-778 messaging repo). Don't add a
"verify the method doesn't exist" test — the absent-grep is the proof.

### 2026-05-08 — BUT-815 testability tweak: timestampProvider on submitReport [Pattern discovered]
Adding the batch+throttle test for `FirebaseReportRepository.submitReport`
hit the documented `fake_cloud_firestore` 4.x limitation with
`FieldValue.serverTimestamp()` — `batch.commit()` throws and the production
catch returns `null`, so the report doc never lands. The fix: route the
throttle write through the existing `BaseFirebaseRepository.timestampProvider`
(which already exists for exactly this reason — see
`lib/core/utils/timestamp_provider.dart`'s class doc). One-line production
change:

  `batch.set(throttleRef, {'lastReportAt': FieldValue.serverTimestamp()});`
  →
  `batch.set(throttleRef, {'lastReportAt': timestampProvider.serverTimestamp()});`

Plus `super.timestampProvider,` on the repo's constructor. Production
behaviour unchanged (default is `ServerTimestampProvider`). Tests inject
`TestTimestampProvider` and assert both docs land in the same batch.

Rule for future "I want to assert a batch wrote both docs" tests against a
repo that uses `serverTimestamp()`: prefer routing through `timestampProvider`
over working around fake_cloud_firestore. Several other repos in
`lib/repositories/firebase/` still use raw `FieldValue.serverTimestamp()`
in batches (e.g. `firebase_deeplink_repository.dart`, audit) — same testability
pattern would unblock those if a similar test is needed.

### 2026-05-08 — HttpsCallable Fake pattern for paginated CF tests [Pattern discovered]
Testing `ComplianceExportManager.exportAuditLogs` (which pages via the
`exportAuditLogs` Cloud Function's `nextCursor`) needs a way to return
canned `HttpsCallableResult` objects across multiple calls. `HttpsCallableResult`
has a private constructor → cannot be `Mock`'d directly. Pattern that worked:

```dart
class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this.data);
  @override final T data;
}

class _ScriptedHttpsCallable extends Fake implements HttpsCallable {
  _ScriptedHttpsCallable(this._responses);
  final List<Map<String, dynamic>> _responses;
  int callCount = 0;
  final List<Object?> receivedParameters = [];

  @override
  Future<HttpsCallableResult<T>> call<T>([Object? parameters]) async {
    if (callCount >= _responses.length) {
      throw StateError('Scripted callable exhausted at page ${callCount + 1}');
    }
    receivedParameters.add(parameters);
    return _FakeHttpsCallableResult<T>(_responses[callCount++] as T);
  }
}
```

Loud-fail on exhaustion (StateError, not return-empty) catches "production
asked for more pages than expected" — important for cap/overflow tests.
`receivedParameters` lets you assert the cursor wiring (page 1 = no cursor,
pages 2+ = `{'before': cursor}`).

Sister pattern: `test/unit/services/llm/llm_service_circuit_breaker_test.dart`
has `_CountingHttpsCallable` for failure-injection. The two patterns
together — failure-counting Fake and scripted-response Fake — cover most
CF test needs without pulling in mocktail wrappers around private types.

### 2026-05-19 — Sprint wave 3 coverage review (BUT-801 / 823 / 841 / 861) [Pattern discovered]
Reviewed 7-ticket sprint. Test gaps catalogued (none blocking):

1. **BUT-801 DI dedup** (`lib/main.dart` `_localeProvider` now from
   `ApplicationBootstrap().container.get<LocaleProvider>()`): the failure
   mode "DI not initialised before initState" is implicitly covered by any
   widget test that pumps `ButleryApp` — `test/e2e/bootstrap_diagnostic_test.dart`
   does pump the real app. No targeted assertion that
   `ServiceLocator.get<LocaleProvider>() == ApplicationBootstrap().container.get<LocaleProvider>()`
   (the actual BUT-801 contract: same instance). Cheap follow-up:
   `test('LocaleProvider is a singleton across DI and ServiceLocator')`
   in `test/unit/core/di/`. Identity test, not behaviour — but it directly
   guards the regression class that caused the bug.

2. **BUT-801 `_LanguageTile`** (new `StatefulWidget` in `settings_hub_view.dart`):
   no widget test. The user-visible contract is "tap tile → AlertDialog with
   `LocaleProvider.supportedLocales` rows → tap row → `setLocale(code)` → subtitle
   refreshes". Worth a single widget test using `createLocalizedTestApp` +
   a fake `LocaleProvider` registered via `ServiceLocator`. Filed as gap, not
   blocker — the locale-switch journey is exercisable from settings hub.

3. **BUT-823 integrity short-circuit** (the new test file). Coverage of the
   primary security claim ("mismatched bytes never touch disk") is solid:
   asserts both `result == null` AND empty cache dir (no `.tmp`, no committed).
   **Non-blocking gaps to file**:
   - **Empty registry path** — `verifyOnnxBytes` with no expected hash returns
     `ok=true, unverified=true`. The integration test doesn't cover the
     "unverified bytes still get written" path; covered in
     `expected_model_hashes_test.dart` at unit level but not wired through
     `_downloadModel`. Asymmetry: if a future refactor flipped the
     unverified-bytes branch to "abort", silent regression.
   - **Transient FirebaseException mid-download** — `_downloadModel`'s
     try/catch returns null on FirebaseException, but no test asserts the
     cache stays clean if Storage throws between model and vocab fetch.
     Likely benign (both fetched in parallel `Future.wait`) but unproven.
   - **Pre-existing `.tmp` from a prior interrupted run** — `_tryLoadCached`
     deletes leftover tmp files; no test for the "downloaded once, version
     file missing, tmp left over" recovery path.

   These are coverage gaps in `_downloadModel`'s error envelope, not in the
   BUT-823 security guarantee itself. The current test correctly isolates
   "mismatched SHA-256 → no disk write" which is the only thing BUT-823
   needs to prove.

4. **BUT-841 `SerializationUtils.safeString` migration** (4 sites in 3
   models): behaviour delta vs old `as String? ?? default` is non-zero —
   wrong-type input now coerces via `.toString()` instead of throwing
   `TypeError`. Old tests in `tag_decision_test.dart` and
   `realtime_resource_test.dart` cover the null→default path (still passing).
   No test in the repo asserts the new wrong-type coercion (e.g. int in a
   String field → string-rendered int). For pure Firestore-roundtrip code
   the wrong-type case never happens; this is defence-in-depth only.
   No new test needed; existing coverage is sufficient for the documented
   contract.

   `NotificationHistoryEntry.displayTitle/displayBody` have **zero test
   coverage** — pre-existing gap, not caused by this sprint. Worth filing
   separately (5-line test file).

5. **BUT-861 CircularProgressIndicator → StateWidget.loading()** (10
   sites across 11 view files). Verified by grep: no existing test asserts
   `find.byType(CircularProgressIndicator)` against any of the 11 migrated
   views (allergen_preferences / mfa_settings / notification_preferences /
   consent_management / moderator_review / recipe_detail / community_guidelines /
   terms_of_service / shopping_list_content / recipe_personal_tag_handler /
   settings_hub). The 40+ existing CircularProgressIndicator assertions are
   in unrelated widget tests (loading_widgets, styled_button, friend_category_manager,
   etc.). Migration is test-safe.

**Lesson**: when filing follow-up coverage tickets, distinguish
"coverage gap" (no test exists for a path) from "regression risk"
(test exists but is wrong / could go green incorrectly). BUT-823's
extra paths are coverage gaps with low regression risk — file them
P3, not P1. BUT-801's identity invariant is a regression risk — file P2.

### 2026-05-23 — Wave-14 BUT-1021 stream-error test pattern [Pattern discovered]
Reviewed three wave-14 test additions: storage-upload exception getters
(19 pure-Dart tests), `MockAnalyticsService.capturedEvents` slot, and the
AuthService stream-error group (`BUT-966 / BUT-1021`). All cleared review;
no production bugs found. Patterns worth reusing:

1. **Recording-Fake pattern for fire-and-forget analytics.** When a method
   on a `Mock` class is documented "semantically a Fake, don't stub with
   `when()`," but tests still need to assert *whether* it was called and
   with what payload, add a parallel `_captured*` slot + immutable getter +
   `clear*` reset. Don't switch to `verify()` — that pulls the class back
   into Mock-semantics and the comment lies. The pattern is already in
   `MockAnalyticsService` for `_capturedUserId` (BUT-833) and now
   `_capturedEvents` (BUT-1021). Both keep the concrete body fire-and-forget
   for callers that don't care, while letting BUT-833/1021-style tests
   assert the analytics chokepoint.

2. **Real-time `Future.delayed(10ms)` IS acceptable for draining an unawaited
   microtask chain in non-Flutter tests.** `pumpEventQueue()` would couple
   the test to `flutter_test`; `fakeAsync` doesn't help because there's no
   `DateTime.now()`/timer to advance — the chain is just awaits on mocked
   `thenAnswer` Futures. 10ms of wall-clock drains them all. The DO-NOT-WRITE
   rule against `Future.delayed` targets *production-timing waits* (debounce,
   throttle, retry windows), not microtask-chain drains. Document the
   chain in a helper comment (`forceSignOut → setError → notify → logEvent`)
   so future readers don't shorten it.

3. **`contains('Sessionen')` over full-string equality for localized copy.**
   The test claims "the session-expired Swedish surface fired," not "the
   exact 2026-05 copy fired." Equality couples the test to copywriting.
   `contains` on a stable noun pins the contract. Same reasoning applies
   to any future test of localized error messages — assert the *anchor*
   word, not the sentence.

4. **Stream teardown order: `streamController.close()` *before*
   `streamAuthService.dispose()`.** Close emits `onDone` cleanly through
   the still-live subscription; dispose then cancels. Reverse order risks
   a `Bad state: Cannot add new events after calling close` if any
   post-dispose code re-touches the controller, and loses the chance
   for the subscription to observe done.

5. **Mutual-exclusivity invariant tests for classifier getters.** When a
   set of `is*` getters partition an error/state space (e.g.
   `isQuotaExceeded` / `isUnauthorized` / `isCanceled` / `isNetworkError`
   on `StorageUploadException`), add a final group that asserts each
   canonical code matches *exactly one* bucket — plus an "unknown code →
   all-false" test pinning the caller's fallback path. Catches a future
   refactor that overlaps the buckets (e.g. moves `unauthenticated` into
   *both* `isUnauthorized` and a new `isAuthGap`) before the
   misclassification reaches the UI as the wrong Swedish copy.

6. **Architecture-allow-list additions need an inline rationale comment.**
   `test/architecture/architecture_test.dart` is the chokepoint preventing
   ad-hoc `Firebase{X}.instance` usage outside DI. New entries should
   document *which* singleton and *why it can't be mocked at the call
   site* — see the BUT-1025 `core_module.dart` comment for the template
   (CF-callable construction, must stay mockable via the wrapping service).

### 2026-05-23 — Wave-17 BUT-932/BUT-1013 audit (Pattern discovered)

**Trigger:** Wave-17 ship audit of `recipe_image_manager.removeImageAndCleanup`
and `WeeklyMenuPlanService.bulkAssignRecipes`.

**Pattern: when behavior contract changes, existing tests in the same file
may become stale assertions, not just incomplete coverage.** The pre-existing
`test/unit/viewmodels/recipe_image_manager_test.dart` "Image Cleanup and
Storage Management" group (lines ~607-680) verifies
`verify(() => mockStorageService.deleteRecipeImage(...)).called(1)`
synchronously after `removeImageAndCleanup`. Under BUT-932 this now happens
only after `commitPendingStorageDeletes()` — these tests will pass in green
build only because the captured call count from prior setUp interactions is
non-zero, or will outright fail. They were left in place during this audit
because rewriting them is out of scope for the new-coverage pass; flagged
as follow-up. **Lesson:** when an audit finds pre-existing tests asserting
the OLD contract, rewrite or delete them in the same PR as the new tests —
otherwise next-touch sees a confusing mix of "delete must happen now" and
"delete must NOT happen now" assertions in the same file.

**Pattern: record-typed return values + mocktail.** For
`Future<({int added, int overflowed})>` you assert via
`expect(result.added, 3); expect(result.overflowed, 7);` or as a whole
`expect(result, (added: 0, overflowed: 0));` — direct record comparison
works because Dart records are value-equal.

**Pattern: `verify(() => repo.save(captureAny())).captured.single as Plan`**
is the clean way to inspect the persisted plan in bulk-write tests instead
of stubbing `save` with a side-effecting `thenAnswer` that stores into a
local var. Requires `registerFallbackValue(_FakeWeeklyMenuPlan())` in a
`setUpAll`.

**Pattern: BUT-932 undo invariants worth re-asserting on any image-manager
refactor:** (1) `removeImageAndCleanup` must `verifyNever` the storage
mock — the whole point is deferral. (2) After `commitPendingStorageDeletes`,
`pendingDeleteCount` must be 0 even when the queue was empty (local-file
removals snapshot for undo but never enqueue). (3) Storage errors during
commit must NOT throw — the recipe save already succeeded, orphan blobs
are tolerated.

### 2026-05-24 — recipe_selection_dialogs facade testing strategy [Pattern discovered]
Widget-test round 6 produced `test/widget/common/dialogs/recipe_selection_dialogs_test.dart`
(23 tests, all green). The facade itself is a 46-line dispatcher with two
`showDialog` calls into `FriendRecipeSharingDialog` and
`MenuRecipeSelectionDialog`. Both inner dialogs synchronously hit
`ServiceLocator.get<UnifiedRecipeService>()` / `ServiceLocator.get<RecipeListViewModel>()`
inside their `build()`, so driving the dialogs end-to-end from a widget
test would require the full DIContainer + two ChangeNotifier mocks +
async loads. **Not worth it** for a facade — the value-to-overhead ratio
is terrible and the inner ViewModels are already tested elsewhere.

**Strategy applied:**
1. Compile-time facade contract — touch `RecipeSelectionDialogs.showRecipeSelector`
   and `showMenuRecipeSelector` as Function references in plain `test(...)`
   blocks. A signature change breaks the build; that's the assertion.
2. Construct the inner dialog widgets directly (no `pumpWidget`) — the
   constructors don't touch DI, only `build()` does. Stores `friend` /
   `categoryName` correctly without pumping.
3. Test the leaf list items (`FriendRecipeListItem`, `MenuRecipeListItem`)
   as pure `StatelessWidget`s — that's where the actual user-visible
   behaviour lives: title/mealType/time/portions rendering, Swedish
   "Delad" badge for `isAlreadyShared`, checkbox + row-tap callback wiring,
   conditional rendering of description / time / portions / image placeholder.

**Anti-pattern abandoned:** First draft tried to drive `showDialog` via a
trigger button + `NavigatorObserver` route spy, then `tester.takeException()`
to swallow the DI crash. Two problems: (a) `pushCount` counts the home
route too — `_RouteSpy` registered before `pumpWidget` sees 2 pushes, not
1, requiring a `pushCount = 0` reset after initial pump. (b) The DI-crashed
`ChangeNotifierProvider` triggers a second exception during `dispose()`
("type 'Null' is not a subtype of type 'RecipeSelectionViewModel'") that's
caught at teardown by the framework, not by `takeException`. Net: messy,
flaky, and not actually proving anything the constructor test doesn't.

**Production observations (not bugs, worth noting):** both
`FriendRecipeListItem` and `MenuRecipeListItem` define an unused, no-op
`void dispose()` method at the end of the class — they're `StatelessWidget`s
so `dispose` is never invoked. Looks like leftover boilerplate from a
StatefulWidget extraction. Safe to delete; doesn't affect behaviour.

