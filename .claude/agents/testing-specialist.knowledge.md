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
