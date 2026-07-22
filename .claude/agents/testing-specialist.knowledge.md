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
| `collectionGroup` queries | ~~Emulator~~ **FakeFirebaseFirestore works** (corrected 2026-06-30, see BUT-1396 entry — fake_cloud_firestore ^4.1 supports collectionGroup+equality) |
| Transactional writes | Emulator |
| Security rules behavior | Emulator (or hand off to `firestore-rules-tester`) |
| Service that wraps Firestore | Mock at the repository interface, not at Firestore level |

---

## Discovered patterns

_Compacted 2026-06-01 (BUT-1177): older entries condensed to their reusable lesson; verbose code examples trimmed. No distinct learning removed — only merged or summarized. The ~8 most recent entries are kept fuller._

*Append new dated entries below as the agent learns them. Trigger-tag each
entry: [Bug found] / [Pattern discovered] / [Helper added] / [User correction].*

## Distilled principles (2026-07-04 consolidation — raw entries verbatim in testing-specialist.knowledge.archive.md)

Each bullet keeps the literal idiom + origin ticket; the archive holds the full stories.

### Conscious-skip taxonomy (when NO test is owed — each discriminant is distinct)
- Static-method orchestrator: no test only when ALL four hold — (a) thin sequence of ≤3 calls, (b) no injection seam, (c) each call in its own try/catch, (d) no branching beyond the catches (BUT-431).
- Static disclosure whose sync contract is compiler-enforced: referencing `AnalyticsEvents.*` constants means a renamed constant fails `flutter analyze` before any test could run; l10n keys are covered by `flutter gen-l10n` (BUT-918).
- Pure-nav affordance: a button whose body is `pushNamed(<const route>)` is framework wiring; the route constant is compile-time checked (BUT-977). Cite ui-conventions.md:84 for heavy-scaffolding views.
- Nth surface adopting an already-proven predicate: prove mechanically via `git diff --staged --name-only` — if the pure-logic file is absent from the diff, there is no new test surface (BUT-1208).
- Mechanical `AppColors→theme` color-source swap: no test when finder-level assertions are unaffected — verify by reading the production diff (BUT-572/BUT-1362).
- `SemanticsService.announce` in an inline handler: skippable because announce is fire-and-forget with NO observable widget-tree effect; a channel test there pins call-site topology, not contract (BUT-905). BUT: once the view gains a DI seam or full-shell harness, the site becomes achievable — BUT-1212/1225/1231 later covered the "deferred" sites and unmasked a real `ProviderNotFoundException`. A conscious skip is dated, not permanent.
- A bypass/safety test is only worth writing when the code path it guards EXISTS: a static disclosure dialog with no account-creation code makes “gate not bypassed” a tautology, not a regression guard. If the view later gains a `test/views/` journey test, the disclosure is one beat there (“blocked screen → parent button shows guidance, `PopScope(canPop:false)` holds”), never a standalone widget test (BUT-946).

### A11y: announce channel + focus/hover behavioural tests
- Announce interception: `SemanticsService.announce(msg, dir)` Standard-codec-encodes `{type:'announce', data:{message, textDirection}}` onto `flutter/accessibility`; arm via `tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(BasicMessageChannel('flutter/accessibility', StandardMessageCodec()), handler)` — helper `AnnounceChannel.arm(tester)` (BUT-1210). Honesty gate: it intercepts the REAL channel; always assert the live `context.l10n.<key>`, never a hardcoded literal.
- Focus order: `expect(find.byType(FocusTraversalGroup), findsOneWidget)` is the DO-NOT-WRITE topology assert; the behavioural version focuses the first field, `await tester.sendKeyEvent(LogicalKeyboardKey.tab)`, then asserts `FocusScope.of(context).focusedChild` (BUT-701/BUT-1307).
- Hover: reading `widget.restDecoration`/`hoverDecoration` off the instance proves nothing — simulate `gesture.moveTo(center)` and assert the rendered `AnimatedContainer.decoration` flips and `MouseRegion.cursor` is `SystemMouseCursors.click` vs `MouseCursor.defer` (BUT-1308/1312-14). `MouseRegion` finder must be `.first` (BUT-1356-58).
- Tab-walk cycle detection dedupes on focus-node IDENTITY, not Y position (scrolling shifts every Y) (BUT-1309).

### Stubbed-both-ends blind spot (services wiring module→stream→widget)
- When a module test proves emission to an injected sink AND the widget test stubs the stream, NOTHING proves the service wires the two — subscribe to the real `service.conflictStream` in the service test and assert a `ConflictEvent` lands (BUT-1031, closed later same file).
- Grep for callers before trusting same-named tests: `RealtimeSyncService.resolveConflict<T>` was a DEAD DUPLICATE of `ConflictResolutionModule.resolveConflict` that omitted `_emitConflict`. `shouldResolveConflict` FALSE branches remain untested at service level (open).

### Import pipeline (SSRF / bombs / re-extract)
- `parseUrls` private/reserved-host filtering is an SSRF invariant, not formatting (BUT-947); the guard got duplicated and half-tested before the gap closed — treat SSRF coverage as a running thread across every import surface.
- Decompression bombs are caught pre-inflation on DECLARED totals: pin with `entry('b', 700, 1)` after `entry('a', 900, 900)` with `maxTotalBytes=1500` (BUT-1370); also verify the skip-not-import behavior of oversized entries end-to-end (BUT-1371 gap).
- A hermetic strategy can drive a hard-wired call site end-to-end: `TextImportStrategy.import` is fully hermetic, so a textPaste artefact exercises `_reextractFromSource` without a DI seam (BUT-1205).
- A CTA widget test proves the LABEL, not the action — wire-level assertion needed separately (2026-06-14).
- Injectable-factory seams leave the production DEFAULT untested: seam tests inject a fake factory, so add ONE test asserting the default mapping directly (`@visibleForTesting defaultReextractStrategyForTest(type)` → `isA<UrlImportStrategy>()` for url, `isA<TextImportStrategy>()` for every other enum value) (BUT-1300).

### Multi-select / bulk-action wiring
- VM tests + card tests each pass while the GLUE (`_deleteSelected` snapshot/order/callback) is untested at widget level (BUT-948) — test the glue.
- Selection-guard: pin `selectable = canRemoveMember` on the owner's OWN tile, not an all-strangers fixture (BUT-1038). Clear-on-cancel: re-enter selection and assert count is back to 1, not 2 — proves `_selectedIds.clear()` ran, not just `_selectionMode=false` (BUT-1038).
- Copy-paste id-field mismatch (`e.id` vs `e.notificationId` one method apart) is invisible unless fixtures make the two fields DIFFER (BUT-1080).
- Async error stubs on typed futures: `thenAnswer((_) => Future<int>.error(Exception(...)))` — never `thenThrow` (sync) nor `async => throw` (type-erased) (BUT-1080).

### Mock/Fake/locator idioms (narrow exceptions — check preconditions before reuse)
- `collectionGroup` on `FakeFirebaseFirestore` IS safe for index-free `.limit(N).get()` without `where()` — narrower than the decision tree's emulator default (2026-06-19).
- `FakeFirebaseFirestore` cannot fire `permission-denied`; omission is acceptable ONLY when the branch is a single `if (e.code == 'permission-denied') return null;` above a rethrow with no side effects — document + file the emulator-lane follow-up (2026-06-21).
- SUT resolves deps via `ServiceLocator.get`? Use `setupUnitWithProductionLocator()` — a mock in `GetIt.instance` is unreachable while `prod.ServiceLocator._container` is null, and a wrapping try-catch swallows the miss silently (BUT-1334).
- Callback-based async APIs: capture the named callback via `invocation.namedArguments[#codeSent]` and invoke it synchronously inside `thenAnswer` (BUT-1333). Distinct from `registerFallbackValue` (argument matching).
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT (BUT-1306).
- `serverTimestamp()` inside `batch.set(..., SetOptions(merge: true))` does NOT break fake_cloud_firestore — the 2026-05 landmine only trips certain write shapes; let a success test prove it lands, don't blanket-assume (FirebaseActivityEventRepository, 2026-06-14).
- Service-faked ≠ covered: a service test using `extends Fake implements XxxRepository` leaves the repo's own query/permission logic dark — the chunked 30-id `whereIn` fan-out (cross-batch sort + `take(limit)`) and the `deleteAllByUser`/`exportEventsByUser` ownership-deny branches each owe a repo-level test against FakeFirebaseFirestore (2026-06-14).

### Contract pinning: selectors, ordering, revert-vs-noop
- Every `field == expected` selector needs THREE pins: matched-key → reused; unmarked collision → untouched; marked-for-DIFFERENT-key → untouched + new created. Without the third, a regression to `field != null` hijacks last week's list and stays green (BUT-1234).
- "No local +1 compensation" contracts need `verifyInOrder` — ordering, not call-count, is load-bearing (BUT-838/694).
- A revert-to-start test must distinguish "reverted" from "never changed" — mutate first, then revert, then assert (BUT-1304).
- Server-owned-key omission guards (`toFirestoreEditable()` stripping `friendsCount`/`isHidden`/`hiddenAt`) need one test PER removed key (2026-06-14).
- `expect(() => asyncFn(), throwsA(...))` without await can pass spuriously — use `await expectLater(...)` + a state-survival assertion (BUT-734 review).
- Method removed+replaced (`incrementCookCount` → `addIncrementCookCountToBatch`): audit the deleted test group with a test-by-test successor map, not a “the new integration test covers it” gestalt — auth-state branches are the easiest to drop when every new test constructs `MockFirebaseAuth(signedIn: true)`. Pin per-method unauthenticated contracts too: `logCookEvent` returns false signed-out while `countSince`/`exportCookEventsByUser` THROW via `requireCurrentUserId()` (BUT-1235/1236).
- Revert experiment: when grading any “regression-catching” claim, flip the production flag/line back and confirm the gating tests FAIL while the controls stay green. Construct the REAL ViewModel so the exact constructor wiring the bug lived in is exercised — newing up `MenuGenerator(filterByAllergens: true)` directly would test the filter but not the VM default, which WAS the bug (BUT-1317).

### Bottom-sheet + unawaited-future pump patterns
- Gate-blocks-sheet path: `tester.runAsync(() async => checkForDuplicates(...))` is safe (no sheet ⇒ chain resolves). Sheet-appears path: `runAsync` DEADLOCKS — start the future unawaited (`// ignore: unawaited_futures`), drain the mock chain with one `pump()` per await, interact with the sheet, then `await resultFuture` (BUT-1247/1250).
- `pumpAndSettle()` HANGS on dialogs containing `CircularProgressIndicator` — bounded pumps (pre-06-04 archive, still load-bearing).

### Admin/metric + theme-token patterns
- Empty-mount sweep: `tester.takeException()` per sealed kind; `createLocalizedTestApp` only when the widget reads `context.l10n` on the empty path (MetricRenderer). Pure `(data, l10n) → value` functions instead use `AppLocalizations.delegate.load(Locale('sv'))` in `setUpAll` after `WidgetsFlutterBinding.ensureInitialized()` — no widget tree, no test app.
- Registry key-lock: compare each registry against `MetricKey.values.toSet()` INDEPENDENTLY — catches all three drift directions.
- Platform-dispatch widgets: `find.byType(CupertinoNavigationBar)` vs `find.byType(AppBar)` IS behavioural when dispatching between them is the widget's entire purpose (BUT-706) — a scoped exception to the topology rule.
- Forcing asset-load errors: the view reads `rootBundle.loadString`, so a `DefaultAssetBundle` override does nothing — break the `flutter/assets` platform channel itself (BUT-1340 REDO).

### Extraction seams
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static` (icon mapping BUT-1041; thresholds BUT-1245) instead of building a DI bridge.
- `AutoSaveManager<T>` contract: "encode-to-empty / encode-null ⇒ REMOVE the key, never write `\"\"`" — proven via an injected-throw on the `prefsProvider` seam (BUT-904).
- A "pure structural split" makes private behavior a public in→out contract — that's exactly when tests apply (BUT-1258).
- Mixin extraction preserving a public surface needs NO new test when the cross-collection isolation test already pins behavior (seeds BOTH collections, asserts one gone + one survives) — no "is the mixin mixed in" asserts (BUT-734).

### One-off gotchas that recur
- `.last` targets the actions-row button when dialog title and confirm share one l10n string — comment it inline (feed_tab).
- Idempotency via explicit toggle (`existingPending = true` after first call, assert counts stay 1) is as rigorous as a second-call proof and simpler (RecipeShareRequestModule).
- `MockMenuService` lives in `service_mocks.dart`, not `production_mocks.dart` — grep BOTH before concluding a mock doesn't exist (BUT-1346).
- Probabilistic coverage doesn't pin a HIERARCHY (cuisine +3 > category +2 > seasonal +1) — deterministic tier tests with `withClock(Clock.fixed(...))` do (BUT-1346).
- Real `.xlsx` stores text via shared-strings (`t="s"`), not `inlineStr` — fixture-fidelity gotcha for hand-rolled readers (BUT-503).
- Privacy gates pair `verify(write false)` with `verifyNever(write true)` — the `verifyNever` half kills dropped-gate regressions (BUT-912). Sibling-key isolation asserts `isNull`, not `isFalse` (BUT-1199).
- Age-boundary tests must pin the exact legal threshold (15 passes, 14 fails), not just far-side values (WS8).
- `export 'stub' if (dart.library.js_interop)` services: test the stub's no-op contract; the web state machine is unreachable from VM tests — flag, don't fake (BUT-1347).
- Re-check `git log -- <file>` before re-implementing a flagged gap — BUT-1312's hover assertions had already landed via BUT-1311.
- Selected-state must survive hover: drive the mouse over the selected card and assert the rendered `AnimatedContainer.decoration` still equals the selected REST decoration (production derives hover via `copyWith(boxShadow:)`) — the selection affordance is the user-visible invariant (BUT-1313).
- TestServiceLocator's default `MockNotificationService` returns null for `getPreferences()` → non-nullable setState throws → view renders its ERROR StateWidget and a tab-order harness fails with a misleading “form didn't render”; override with a fresh mock stubbing `NotificationPreferences.defaults()`. Cooldown-gated buttons: wrap the case in `withClock(Clock.fixed(...))` so focusability doesn't depend on wall-clock (BUT-1314).
- Windows flutter-test recipe: wrapper `.bat` with `set "PATH=C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Program Files\Git\cmd;C:\tools\flutter\bin"`, `cd /d` to the repo, run `%*` with `1> log 2>&1` INSIDE the bat, invoke via `cmd.exe //c` — the flutter/dart wrapper shells out to git AND PowerShell (2026-06-14/15). Don't leave the bat committed.

### Cross-doc field routing + model/helper contracts (distilled 2026-07-16)
- A private flag (`hasSeenActivityFeedHint`) belongs in `toPrivateSettings()`, and its test pins BOTH presence there AND absence from `toFirestore()` (public-doc privacy-leak guard). Writer-doc ≠ reader-doc is the BUT-748 class: `FirebaseUserRepository.fetchProfile`'s settings-merge `copyWith` needs an explicit line per merged field — the missing line made the once-only hint re-fire every session; caught by a round-trip test going red (BUT-1220).
- FakeFirebaseFirestore can't run `SetOptions(merge:true)` writes, but the read-merge IS testable: seed the public doc AND the settings sub-doc with plain `.set()`, call `fetchProfile`, assert the merge reads it back (BUT-1220).
- Defensive decode is what a naive round-trip skips: `_readActivityFeedEventTypes` drops non-bool entries (corrupt `{'shared':'yes'}` → absent-key ENABLED default) and non-Map → empty map — test both. The load-bearing VM test for a `mapEquals` change-detection branch: `updateActivityEventType` flips `hasUnsavedChanges` (BUT-1220).
- When an aggregator delegates a pure invariant to a helper, unit-test the helper's own contract — aggregator fixtures only cover the units their recipe data happens to use. `SmartUnitConverter.toCanonicalBase` returning `null` for non-measure units (`st`/`klyfta`/`förp`) is the ENTIRE guard against count/measure cross-merging; `hg`/`mg`/`cl`/full-word forms are only reachable there (BUT-1278). New model flag: pin omit-when-false in `toFirestore`, legacy-doc default-false read, and copyWith carry — pre-flag docs must read back non-staple (BUT-1279).
- When a `*_done.marker`/knowledge-file diff is the review scope, the lib/ changes to test are whatever that agent says it reviewed — trace the feature commit (`git log -S <keyword>`) and check each security-review claim has a behavioral test. A cross-casing fixture (`'Salt'` staple vs `salt` recipe line) proves the normalized-match path implicitly; mocktail's null-on-non-matching-arg transitively pins the scoped userId (BUT-1279/1281/1292).

### Firestore-rules .ts suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify([...])`/`hasRequiredFields([...])` list tests EACH field, not just one (activity_events left `type is string` + `recipeId`/`createdAt` immutability dark, 2026-06-14).
- A failure-only update suite can be silently over-restrictive — pair the denials with at least one `assertSucceeds` proving the actor CAN update a mutable field.
- The emulator persists docs across invocations: suffix create-test ids with a per-run `RUN = Date.now().toString(36)` or fixed-id creates silently become UPDATEs on the 2nd run and stop proving the create rule.
- These are hand-rolled `npx ts-node` runners against `127.0.0.1:8080` — they time out without `firebase emulators:start --only firestore`. Shared `rateLimitWrite` is emulator-stateful and exercised by other collections' suites — don't chase it per collection.
- Comment-only diffs owe no new test, but verify the comment's claim IS already pinned — BUT-1287's claim was gated by `_SpyAuditRepository` (a real `FirebaseAuditRepository` subclass recording `logPermissionCheck`, fail-loud via `singleWhere` orElse, with a denied-path negative control): the correct Fake-not-Mock for “prove a collaborator was invoked”.

### Weighted-random selectors
- Assert the weight MATH via a `@visibleForTesting static debugRecipeWeight(...)` hook (`greaterThan`/`lessThan` on computed weights) — NEVER the sampled outcome; outcome assertions on a `Random` draw are an automatic High flag (BUT-1318/1319).
- Intent-gating by construction: the rating test fails if `_ratingMultiplier` reverts to flat 1.0; the dedup test fails if the `* _recentUseDecay` line is removed. Unrated keeps non-zero weight AND equals 1★ (proves never-penalized, not just selectable). Decay-not-exclude is proven at TWO layers: weight-math unit test + end-to-end thin-pool fill (all-recent pool still fills count) (BUT-1318/1319).
- Known deferred gap noted then: `MenuGenerator._recentlyUsedRecipeIds()` plumbing (null-service → `const {}`, swallowed errors → `const {}`, 1-2 week window via `clock.now()`+`IsoWeekUtils`).

### Archived (pre-2026-06-04) — see testing-specialist.knowledge.archive.md
- 2026-04-25→05-08 (~30 entries) — seed + golden-set/Viterbi fixtures, GDPR-cascade tripwires, CF helper env stubs, HttpsCallable fakes, fail-soft resolvers, color-token migrations.
- 2026-05-19→05-26 (~45 entries) — sprint waves: recording-fakes, facade/dialog harnesses, `FieldValue.serverTimestamp` fake-breakage trio, platform-channel scaffolds, case-sensitivity URL bugs (TikTok/Instagram), RTDB mocktail stubs, CPI pump hangs, `final class` SDK walls.
- 2026-05-27→06-03 (~46 entries) — fakeAsync+SharedPreferences friction, timer races, trust/safety capture-asserts, BUT-1180 ULTRATHINK view-test rebuilds (6 files), announce-harness precursors, emulator-lane extraction recipe, iter-8x audit verdicts.

### Archived 2026-07-04 batch (2026-06-04 → 2026-06-26) — see testing-specialist.knowledge.archive.md
- 2026-06-04 (18 entries) — conscious-skip taxonomy origins, pure-helper extraction seams, bulk multi-select wiring (groups, notifications).
- 2026-06-05→06-10 (16 entries) — comment-visibility audience thread, AdaptiveIcons/settings codemods, ServiceLocator-bridge harnesses, announce-site closures (BUT-1210/1212/1225/1231), draft persistence.
- 2026-06-11→06-12 (12 entries) — selector-pinning (BUT-1234 three pins), ordering invariants (BUT-838/694), MenuShoppingListGenerator, iter reviews.
- 2026-06-13 (17 entries) — sprint/iter quality audits, pure-threshold extraction, resetForLogout index leak, bottom-sheet pump patterns (BUT-1247/1250), main.dart bootstrap extraction.
- 2026-06-14 (54 entries) — largest batch: RealtimeSync conflict family, import pipeline (SSRF/bombs/re-extract), social + cooking + menu VM coverage, model refactor guards, injectable-factory default gap (BUT-1300).
- 2026-06-15 (13 entries) — FocusTraversalGroup/hover behavioural thread (BUT-1307-14), AdaptiveAppBar dispatch, pantry bulk-bar.
- 2026-06-17→06-20 (17 entries) — admin metric/VM template family, GDPR Art 8 boundary, WS4/WS5/WS9 reviews.
- 2026-06-21 (23 entries) — GRP/SOC/IMP/ENG/COOK audits, MFA callback idiom, share-request idempotency, allergen-safety gates.
- 2026-06-22→06-23 (14 entries) — GetIt+DIContainer injectability triage (BUT-1339/1340/1353), hover+FAB audit, AdaptiveAppBar batches.
- 2026-06-24→06-26 (5 entries) — XlsxReader shared-strings gotcha, DecompressionGuard pair, AddPantryItemSheet error path.

### Archived 2026-07-16 batch (2026-06-04 → 2026-06-15 leftovers) — see testing-specialist.knowledge.archive.md
- 10 raw entries that had survived the 07-04 consolidation, relocated verbatim under “--- relocated 2026-07-16 ---”: BUT-946 conscious skip; BUT-1235/1236 deletion-audit successor map; BUT-1220 cross-doc hint-flag bug; BUT-1278/1279 unit reducer + isStaple; staple-exclusion security cross-check (BUT-1279/1281/1292); activity_events rules heuristics; FirebaseActivityEventRepository gaps; BUT-1312-14 hover/selected/tab-order; BUT-1317 revert experiment; BUT-1318/1319 weight-math hook. Every rule folded into the distilled sections above.

### 2026-06-28 — HouseholdRosterService test review: allergenPreferences gap + teen isMinor gap [Pattern — reviewed]

`test/unit/services/family/household_roster_service_test.dart` (5 tests, all passing).

**Core contract verdict: adequately covered.** Ordering (accounts first, in member order, then diner profiles), member-type discrimination, memberId sourcing (userId vs profile.id), display-name fallback to bare userId, and empty-on-unknown-household are all tested with the right intent — each test would fail if its named behavior broke.

**Gap 1 (staff-engineer insist): allergen preferences are never threaded through.** The service comment on line 38 promises "allergenPreferences resolved from the user profile for accounts and from the diner profile for non-account members" — this feeds present-aware menu personalization, the primary downstream consumer. The test's `MockFactory.createUserProfile` calls do NOT set a non-null `allergenPreferences`; `_diner(...)` also creates profiles with `allergenPreferences: null`. A refactor accidentally dropping the `allergenPreferences:` param from `HouseholdRosterMember.fromUser` or `fromDinerProfile` would pass every existing test. Two missing tests: "account member carries allergen preferences from the resolved user profile" and "diner profile member carries allergen preferences from the diner profile".

**Gap 2 (low cost, worth pinning): `teen` age band's `isMinor` is not exercised.** Test 3 uses `child` (minor) and `adult` (non-minor). `teen` is the band most likely to be misclassified in a future "teen is basically an adult" refactor; it has specific GDPR/guardian-consent implications. One missing test: "teen diner profile is reported as a minor in the roster".

**Weak assertion (not a blocker): test 2 asserts `roster.every((m) => m.isMinor == false)`.** Vacuously true if the roster is empty; passes even if a profile member slips in when diner repo returns unexpectedly. Scoping to `roster.where((m) => m.isUser)` is more precise, though the current split structure (test 1 and test 3 cover the profile side) makes this non-blocking.

**Pattern to remember: whenever a service maps two different model types (user profile → roster member, diner profile → roster member), write at least one test per type that asserts a non-trivial field beyond displayName and type — especially fields used downstream (allergenPreferences here). The ordering + typing tests prove the structure; the field-threading tests prove the data quality.**

### 2026-06-28 — BUT-1417 account-maturity CTA gate tests: review patterns [Pattern — reviewed]

**FriendsViewModel `error` getter chain must be stubbed correctly to avoid shadowing the maturity message.** The `get error` override chains `_friendsService.error ?? _groupCreationError ?? _searchManager.searchError ?? super.error`. The maturity gate writes via `setError()` → `_error` (the mixin field) → only visible as `super.error`. If `_friendsService.error` were NOT stubbed to `null`, the service error would shadow the maturity message and the `expect(vm.error, isNotNull)` assert would pass vacuously on the WRONG error. Lesson: when a test checks `vm.error isNotNull` on a VM with a multi-source `error` getter chain, audit that EVERY upstream source in the chain is stubbed to `null` in the "blocked" test — otherwise the assert can pass even if `setError()` was never called.

**`hasError` on FriendsViewModel does NOT include `super.error`** (lines 163-166 omit it) — so `vm.hasError` is `false` after a maturity gate block, even though `vm.error` is non-null. The test correctly asserts `vm.error isNotNull` rather than `vm.hasError isTrue`. This is a real production-side inconsistency worth noting, but the test is written at the right level and would NOT miss the bug.

**`_fixedHelper(bool result)` is a real `AccountMaturityHelper` instance with a controlled clock, not a mock. This is the correct pattern** — the helper's `isMatured()` logic runs for real, removing any tautology risk. Contrast: if a `MockAccountMaturityHelper` were used with `when(() => mock.isMatured(...)).thenReturn(false)`, the test would pass even if the ViewModel forgot to call `isMatured()` at all.

**`Future.delayed(Duration.zero)` for `_initializeData` pump** (lines 449, 492) is on the DO-NOT-WRITE list for time-dependent async but IS acceptable per 2026-05-01 lesson for fire-and-forget event-loop pumps where no real clock is involved and all stubs return synchronous values. The `_initializeData` stubs here are all synchronous (no real async), so `Duration.zero` is sound.

**ChatViewModel happy-path with `_authRepoWithNoUser()`:** the `_fixedHelper(true)` uses the time-based path (`isMatured` → 2h ≥ 60min), so `emailVerified` from `firebaseUser` is irrelevant (null user → falls to time check → true). The test is consistent.

### 2026-06-28 — FirebaseDinerProfileRepository: four contract gaps [Pattern — reviewed]

Reviewing `firebase_diner_profile_repository_test.dart` (10 tests, FakeFirebaseFirestore + real HouseholdRepository). Findings:

1. **`validateUpdatePermission` is never tested in the call path of `update()`**. The only update test exercises the consent guard throwing BEFORE `super.update()` is reached, meaning a regression that deleted `validateUpdatePermission` would produce zero failures. Needed: (a) a non-member calling `update()` receives `PermissionDeniedException`; (b) a valid update is read back to prove `super.update()` wiring.

2. **Cross-household write not tested.** The "non-member cannot create" test uses a total stranger (member of NO household). It does not cover a member of household A writing a profile with `householdId = household-B`. The `validateCreatePermission` check is on `entity.householdId`, so this is the actual attack surface. Add: seed two households; member of hh-1 attempts `create` with `householdId = 'hh-2'`; expect `PermissionDeniedException`.

3. **`hasAnyPreferences` boundary not characterised.** The consent guard fires on `allergenPreferences?.hasAnyPreferences ?? false`, not `!= null`. An empty `UserAllergenPreferences` with both sets empty would bypass the Art. 9 gate even without allergen consent. This may be intentional (no data = no risk), but there is no test pinning the boundary. A later tightening to `!= null` would change behavior silently.

4. **`getByHousehold` isolation: count-only assertion.** The test asserts `hasLength(1)` but does not assert which profile is returned, and does not test cross-household isolation (two households, each with a profile). The `where('householdId', ...)` filter contract is the real thing being guarded.

### 2026-06-28 — family-rating / diner-profile model review: three contract gaps [Pattern — reviewed]

Three recurring failure modes for model-layer tests, surfaced while reviewing `diner_profile_test.dart` + `family_rating_test.dart`:

1. **Circular determinism assertions.** `expect(buildId('r1','m1'), buildId('r1','m1'))` calls the same pure function twice and proves Dart referential transparency, not the actual domain invariant ("same (recipe, member) pair → same Firestore document address"). Pin the **output value**: `expect(FamilyRating.buildId('r1', 'm1'), 'r1_m1')`. If someone changes the separator or inserts a hash, the circular test passes; the pinned test fails.

2. **Missing negative/revocation paths for GDPR consent properties.** Testing `hasAllergenConsent: true` and `hasAllergenConsent: false` on freshly-constructed profiles does not exercise consent *revocation* — where a `copyWith` on `GuardianConsent` changes `includesAllergenConsent` from `true → false`. A buggy `copyWith` that silently preserves the original field would pass all three existing cases. The revocation path is the highest-consequence gap (GDPR Art. 9 compliance).

3. **Missing displayAverage on the zero/empty sentinel.** `FamilyRatingSummary.fromRatings('r1', [])` sets `familyAverage = 0`. `displayAverage` calls `.toStringAsFixed(1).replaceAll('.', ',')` — correct for `0` but would return `'NaN'` if the sentinel were ever changed to `double.nan`. Test: `expect(emptyRatingSummary.displayAverage, '0,0')`. User-visible, recipe-card pill text.

**Decision rule reaffirmed:** for model properties that encode compliance rules or user-visible rendering, test the *transition/revocation/edge* of the property, not just the happy state. The "intent" gate — "this test would fail if the production code broke the contract" — exposes gaps that the "does it assert something?" gate does not.

### 2026-06-28 — FamilyRatingService review: five behavioral gaps [Pattern — reviewed]

Reviewing `test/unit/services/family/family_rating_service_test.dart` (7 tests, FakeFirebaseFirestore + real `FirebaseFamilyRatingRepository` + seeded household, `_MockSocialRecipeOperations` for mirror assertion). All 7 tests pass.

**What the tests get right:** The `createdAt`-preservation test genuinely detects a create-instead-of-update regression — `_upsert` calling `_ratings.create(rating)` on re-rate would write a fresh doc with `t2` as `createdAt`, making `r.createdAt.isAtSameMomentAs(t1)` fail. The round-trip through `fromMap` means a serialization-level timestamp bug would also surface. Mirror-boundary tests assert both halves: `verifyNever` + repository read in the proxy test; `called(1)` (not just `called`) in the self-rating test catches a double-fire regression.

**Gap 1 (staff-engineer insist): stars-range validation is never exercised end-to-end.** `FamilyRatingSummary.fromRatings` filters by `hasValidStars`, so an out-of-range entry (0 or 6) stored via `rateAsFamily` silently produces `count: 0, average: 0.0`. No existing test catches this data hole. Add: rate with `stars: 0`; assert `getSummaryForRecipe` returns `count: 0`.

**Gap 2 (staff-engineer insist): adult self-re-rate mirror count is not verified.** `_rateAsFamily` always checks `_isSelfRating` — both the create and update branches call it. A bug making the mirror fire twice per re-rate (or zero times on update) is invisible. Add: `rate` twice (same adult self-rater); assert `socialOps.rateRecipe` `called(2)` total.

**Gap 3: `removeRating` on a non-existent id is untested.** The service promises "no-op tolerant." If the repository throws on missing delete, callers crash. Add: call `removeRating` without a prior `rate`; assert `returnsNormally`.

**Gap 4: `getSummaryForRecipe` with zero ratings is not round-tripped through the service.** `FamilyRatingSummary.fromRatings([])` early-returns an empty sentinel (tested at the model level), but the service's `_memberRatings` fallback (`result ?? const []`) is not exercised. Add: call `getSummaryForRecipe` for a recipe with no ratings; assert `count: 0, average: 0.0`.

**Gap 5 (minor): `getMemberRatings` is exercised only implicitly** (same `_memberRatings` body as `getSummaryForRecipe`). If it ever grows distinct logic (ordering, filtering), the coverage would silently disappear. One explicit test returning both seeded entries would close it.

**Decision rule: for a service where a write-path branch (create vs update) both call the same side-effecting check (`_isSelfRating`), write a test that calls the service TWICE on the same key and asserts total call count on the side effect.** This is the only way to prove the check fires once per call rather than once-ever or twice-per-update.

### 2026-06-30 — AuthView footer semantic labels (WCAG 4.1.2 fix) [Pattern + Bug found]

**Context:** `_buildFooter()` in `auth_view.dart` had `Semantics(link: true)` nodes with no `label:` — screen readers announced nothing for the Terms and Privacy footer links. The staged change added `label: context.l10n.a11yTermsOfServiceLink` / `label: context.l10n.a11yPrivacyPolicyLink` to both nodes.

**Test added:** `test/widget/views/auth/auth_view_legal_links_test.dart` — new test "footer links expose named semantic labels to screen readers in login mode". Pumps login mode (not register mode) and asserts `find.bySemanticsLabel(_kTermsA11yLabel)` + `find.bySemanticsLabel(_kPrivacyA11yLabel)` each find widgets. Without the `label:` the finders return nothing → `findsWidgets` fails. Would not break from a widget-structure refactor (asserts the semantic label string, not widget type or position).

**Side-effect caught and fixed:** Adding `label:` to the footer `Semantics` nodes made the same ARB strings appear in BOTH the inline register-mode links AND the footer, so `find.bySemanticsLabel(_kTermsA11yLabel)` now matches two nodes in register mode. Two pre-existing tests called `tester.ensureVisible(find.bySemanticsLabel(...))` without `.first` — `ensureVisible` calls `.single` internally and threw `Bad state: Too many elements`. Fixed both callers with `.first` (inline link precedes the footer in the widget tree since the Column adds `_buildFooter()` last). All 7 tests pass.

**Pattern:** When a semantic label string is shared between two widget subtrees (e.g. inline link and footer both use `a11yTermsOfServiceLink`), ALL `find.bySemanticsLabel(...)` callers in the test file must use `.first` / `.last` / `.at(n)` rather than expecting a singleton. The tree order is: body content (inline links) → footer (_buildFooter is the last Column child) → `.first` targets the body, `.last` targets the footer.

### 2026-07-11 — BUT-1576/1579 tagging: cost-guard + decimal-comma split review [Pattern — reviewed]

Reviewed the "tagging" sprint diff across four files: `IngredientParser.parseCompoundIngredient` "och"-split cap (BUT-1576, Dart), and the `csvToFirestore` alias-split regex `/;|,(?!\d)/` extended to `aliases_en`/`search_terms` (BUT-1579, TS). Both test suites green (Dart 37/37, TS 18/18). TS side is well-covered — the two new BUT-1579 cases mirror the existing BUT-1495/BUT-1571 aliasesSv pair and would fail on regression to a bare `";"`. Findings on the Dart cap tests:

1. **Cost-guard test derives its expected bound from the const it's guarding (circular-determinism variant, cf. 2026-06-28).** `expect(results, hasLength(IngredientParser.maxCompoundParts))` + `x${maxCompoundParts - 1}` means the SAFETY property (the bound is *small*, "a handful") is never pinned. Because the input is 20 parts, the test does catch inflation *above 20* (results would be 20, `hasLength(25)` fails) — but any drift within `[9, 20]` (e.g. someone bumps the cap 8→15, materially weakening the read-amplifier guard) passes green. Fix: add one literal pin — `expect(IngredientParser.maxCompoundParts, 8)` or assert `hasLength(8)` with the literal — so the guard's *value* is the contract, not just its mechanism.

2. **Cap boundary (off-by-one) untested.** The branch is `allParts.length > maxCompoundParts ? sublist(0, maxCompoundParts) : allParts`. Tests exercise 20 (well over) and 2 (well under) — never exactly 8 (keep all) vs exactly 9 (drop one), which is where an off-by-one (`>=` vs `>`, or `sublist(0, n-1)`) would hide. Add an exactly-`maxCompoundParts` case (all kept) and a `maxCompoundParts+1` case (one dropped).

3. **Silent tail-drop has an allergen-completeness dimension (production, Info — BUT-1576 is a decided guard).** `parseCompoundIngredient` feeds `IngredientLookupService.lookupFromRaw`, i.e. the allergen surface. A single line legitimately enumerating >8 "och"-joined items with an allergen in the tail (`…och jordnötter` as the 11th) drops that allergen from lookup with no telemetry. Real recipes list one ingredient per line so the practical risk is adversarial input, not real recipes — but the drop is unobservable. Consider a debug log / metric when the cap trips, so pathological inputs surface. Not blocking.

**Reusable rule: a cost/safety cap whose whole point is "bounded to a small N" must have ONE test that pins N as a literal.** A test that computes its expectation from the same const cannot distinguish "cap works at 8" from "cap silently relaxed to 15." Mechanism coverage (does it truncate?) and value coverage (to what?) are separate obligations.

### 2026-07-10 — BUT-1483 late-loaded config rebuild: marker-cuisine observable + version-guard gap [Pattern — reviewed]

`test/unit/services/tagging/tag_generator_test.dart` — new group "BUT-1483: late-loaded config rebuilds config-backed phases" (2 tests) + top-level helpers `_LateArrivingTagConfigService` and `_lateConfigWithMarkerCuisine()`. Production: `TagGenerator._ensureConfigCurrent()` rebuilds the config-backed Phase 1 (allergen/dietary) + Phase 5 (cuisine) at the start of each run when `ServiceLocator.tryGet<TagConfigService>()?.configOrNull` reports a newer `combinedVersion` than the one the phases were built with — fixes the boot race where the generator is constructed before the remote config finishes loading and would otherwise stay pinned to the static fallback all session.

**What the test gets right (keep this pattern):**
- **Marker-tag observable.** Injecting a config with a synthetic cuisine (`key: marker_cuisine`, `tags.sv: testkök`, `titleKeywords:[zzcuisine]`, `matchMode: title_only`) makes a tag that NEITHER the static fallback NOR the seeded cuisines emit. Its presence is a clean, behavioural proof that Phase 5 was rebuilt from live config — not a topology/instance-identity assert. The before-assert (`testkök isFalse` on the same generator pre-arrival) is a genuine negative control, and reusing the SAME generator instance across before/after is exactly the boot-race scenario (persistent generator, late config).
- **Injected-phase guard (test 2).** Constructing with `phase5: TagPhase5Cuisine(...)` flips `_canRebuildConfigPhases` false; the test asserts a late config does NOT introduce `testkök`. This guards the exact gate every other test in the file depends on — 143 phase-injecting/no-locator tests would break if rebuild ran over injected phases.
- **Isolation is order-independent and complete.** Group `setUp` registers the fake into `GetIt.instance` + `ServiceLocator.initialize(DIContainer())`; `tearDown` does `ServiceLocator.reset()` (nulls `_container` → `tryGet` returns null again) AND `GetIt.instance.unregister<TagConfigService>()`. `DIContainer()` construction registers nothing (just wraps `GetIt.instance`), so the only GetIt mutation is the one singleton, cleaned up explicitly. Confirmed all 145 tests green in one run (concurrency:1, no random ordering). The double is a clean Fake-style subclass (`extends TagConfigService`, overrides the `configOrNull` getter) — NOT a Mock-with-@override misuse — and `TagConfigService`'s constructor is inert (no listener/load on construction), so no Firebase-on-construction leak.

**Gap worth one more assertion (Medium): the same-version no-rebuild branch is untested.** `_ensureConfigCurrent` early-returns on `liveConfig.combinedVersion == _builtWithConfigVersion`. This is a cost guard — the method runs at the START of EVERY `generate`/`runPhaseN` call, so losing the equality check would rebuild Phase 1 + Phase 5 on every single tagging run (a real perf regression), and BOTH current tests would stay green (test 1 rebuilds→testkök appears; test 2 never rebuilds). Observable proof without touching internals: build the generator WITH a marker config (version N), then have the live service return a DIFFERENT config that shares `combinedVersion == N` but lacks the marker cuisine — if the guard holds, output still contains `testkök` (old phase retained); if the guard is dropped (always-rebuild), `testkök` disappears. Requires two configs colliding on `combinedVersion` (constructible via `combineVersions`). Non-blocking for the commit, but the version-equality contract currently has zero coverage.

**Rule reaffirmed:** to prove a config/version-gated rebuild, use a marker output that only the injected config emits and reuse ONE long-lived subject across the before/after transition — that pins "picked up the late value" without asserting instance identity. And when a rebuild path carries a `version ==` short-circuit, cover BOTH directions (newer→rebuild AND same→no-rebuild) or the cost-guard silently rots.

### 2026-07-09 — SocialRecipeSharingService (BUT-1503) review: 4 gaps [Pattern — reviewed]

Reviewed `social_recipe_sharing_service_test.dart` (38 tests, all pass) against the BUT-1503 diff (secondary `shared_recipes` write flipped from best-effort-true to bounded-retry-then-false). The self-heal contract is well pinned (transient-succeeds-on-retry lands exactly one doc + true; persistent-fail → false + sanitised setError + `attemptCount > 1`; primary-save-fail → no secondary write). Gaps found:

1. **Owner-admin invariant is guarded + tested for FIRST-share but NOT for re-share.** First-share re-asserts `memberPermissions[currentUserId] = admin` after the userIds loop (production line 108) and the test pins it (line 379). The re-share/else branch (lines 120-134) just does `updatedPermissions[userId] = permission` for each userId with NO owner re-assertion — so `shareRecipeWithUsers(id, [ownerUid], viewer)` on an already-collaborative recipe silently downgrades the owner from admin to viewer (loses unshare/manage rights). Latent only because current callers never pass the owner (`acceptRecipeShareRequest` passes `request.fromUserId`, group-share strips self). Lesson: **when a "seed the owner as admin" invariant is protected on one write branch, write the same test on the sibling branch — asymmetric guards are exactly what a future caller change breaks silently.** The catch-the-bug test would currently FAIL — that's the flag, don't weaken.

2. **Retry backoff (`Future.delayed(_secondaryWriteBackoff * attempt)`, line 186) has no injection seam → tests pay real wall-clock time.** The two persistent-failure tests each burn 150+300ms of real delay; the transient test 150ms. Can't use fakeAsync because the production const `Duration` isn't injectable. Recommend a `Future<void> Function(Duration) delay` ctor param defaulting to `Future.delayed` so tests inject a no-op / drive the loop synchronously. General pattern: **any production retry loop that tests must traverse needs an injectable delay, or the "no real waits in tests" rule is unenforceable at the service seam.**

3. **"minimal sender PII" test overpromises its GDPR intent.** The intent doc + test (lines 392-410) claim it pins "never the sender's email/phone," but the body only asserts the three positive fields; a refactor adding an email field to `SharedRecipe.create` would not fail it. Negative-scope claims need a negative assertion (e.g. `sharedRecipe.toMap().keys` contains no email/phone key) or the intent line should be softened. Recurring: a GDPR-minimisation test must assert the ABSENCE, not just the presence of the allowed fields.

4. **Hardcoded English `'Unknown'` fallback** at production line 148 (`_getCurrentUserDisplayName() ?? 'Unknown'`) for the recipient-visible `sharedByDisplayName`, while the sibling group-resolution path uses localised `AppLocale.current.displayUnknownUser` (line 391). Swedish is the UI language; inconsistent + untranslated, and no test exercises the null-displayName secondary write.

### 2026-07-09 — MenuService review: strong weight-math coverage, three untested public paths [Pattern — reviewed]

Reviewed `test/unit/services/menu_service_test.dart` against `lib/services/menu_service.dart` (menu area). The suite is genuinely strong on the deterministic weight math and the diversity balance pass — `debugRecipeWeight` is exercised directly (rating boost, family override, recent-use decay, ceiling caps), and the BUT-1457 decrement-before-scan fix has a dedicated "shared protein slot" test that would fail under the old code. The BUT-1464/1466 allergen-trust routing tests correctly pin all four verdict corners (stale-FREE excluded, manual-FREE rescued, manual-CONTAINS on untagged excluded). The unsatisfiable-pool tests correctly assert the product invariant "a cap is never met by dropping a recipe."

**Gaps worth remembering (none is a shipped bug — all are missing coverage on live public surface):**
1. **Day-pins path (`parsed.dayPins`, menu_service.dart:482-504) has ZERO coverage** — every `ParsedMenuRequest` in the suite uses `dayPins: const []`. The code comment stresses "Day pins land first (so tacofredag wins over generic selection)" — a first-class product feature with no test. A regression that dropped the pin loop, or double-counted a pinned mealType against a same-type slot, passes green. This is the single biggest gap.
2. **Personalisation scoring context (BUT-1320, `MenuScoringContext` / `context.multiplierFor`, menu_service.dart:138) is never constructed in a test** — every call uses the default `MenuScoringContext.empty`. The `@visibleForTesting debugMaxRatingBoost` getter (menu_service.dart:92) exists specifically so personalisation ceilings can be asserted below the rating ceiling, and NO test references it — a dead test-only accessor. Pantry/cuisine/skill nudges are unverified.
3. **`parsePrompt(input)` public API (used by the VM chip strip) is untested** — including its null-lexicon early return. Same for `generateMenuFromPrompt`'s null-lexicon `return {}`.
4. **`_passesGlobals` tag/ingredient exclusion branch (menu_service.dart:616-624, `globalExcludedTags` + `ingredientsNormalized`) is untested** — only the allergen/dietary trust branch is covered.

**Test-quality nits:** (a) the season-boost test (line 596-606) duplicates `SeasonUtils.currentSeasonTag`'s month boundaries inline with `DateTime.now().month` instead of calling `SeasonUtils.currentSeasonTag()` — if the boundaries ever move, the test tags recipes with the wrong season and silently loses its boost signal; call the real helper. (b) The Performance test asserts `sw.elapsedMilliseconds < 200` — a wall-clock threshold that is flake-prone on a loaded CI runner; a 1000-recipe generation is fine as a smoke test but the hard 200ms bound proves throughput, not a contract.

**Latent (not a bug, don't file):** `_enforceMenuDiversity` swaps a recipe out of the picks but the caller already added it to `usedIds` before enforcement, so a swapped-out recipe stays marked used and can't be reused. Benign — pools are filtered by mealType so it can't cross-contaminate a different slot, and preventing reuse within a generation is the desired direction anyway.

**Reusable rule:** when a service's public surface has an "X lands first / X wins" ordering comment (day pins here), that ordering IS the contract — write the two-recipe test where the pin and a same-type slot compete, or the ordering guarantee is unproven.

### 2026-07-09 — TagGenerator: tests drive the DEAD path (`generate`), production runs `assembleResult` [Pattern — dead-duplicate, review]

Reviewing `lib/services/tagging/tag_generator.dart`. Grep proves `TagGenerator.generate()` has **zero callers in `lib/`** — production tags through `TaggingPipelineRunner`, which calls the per-phase accessors (`runPhase1..runPhase5FromPhase1`) then `assembleResult(...)`. Only `generatePhase1Only` is still a live production entry (from `tagging_service.dart:283`). Yet all ~40 cases in `test/unit/services/tagging/tag_generator_test.dart` call `generator.generate(...)`.

**Why this matters (same shape as the RealtimeSyncService dead-duplicate, knowledge line 110-111):** the TagResult-assembly tail is DUPLICATED verbatim in two places — `generate` lines 356-396 and `assembleResult` lines 153-178 (allTags spread over phase1..5+partial, `_resolveTagConflicts`, `hasDraft = matched.any(status=='draft')`, `generatorVersion`, `decisions ?? null`). They are byte-identical *today*, but a future field/logic change made in `generate` (because that's what the suite exercises) leaves production's `assembleResult` stale and the 40 tests stay green. `hasDraftIngredients` was added once already — exactly the kind of field that must land in both. Clean fix: have `generate` delegate its tail to `assembleResult`, and add TagGenerator-level tests that hit `assembleResult` directly (or assert the two produce identical results for the same phase inputs). Do NOT just add coverage on `generate` — that deepens the wrong path.

**Second finding — the config-consistency comment is false for the production path.** `_ensureConfigCurrent()` (BUT-1483) rebuilds the two config-backed phases (`_phase1`, `_phase5`) when a newer `TagConfigService.configOrNull.combinedVersion` has loaded. Its doc claims "Runs first (before any phase call in a pipeline pass) so a single run always uses one consistent config." That only holds for the monolithic `generate()`, which calls it once up front. In the **runner** (production), `runPhase1` and `runPhase5` each call `_ensureConfigCurrent()` in *separate microtask Futures*. If the late Firebase config lands between the phase1 and phase5 microtasks, phase1's result is computed on config vA (or the static fallback) while phase5 rebuilds and runs on vB — one recipe tagged with mixed allergen-vs-cuisine config. Bounded (once per session, only the pass that straddles the config load) so Low severity, but the guarantee the comment advertises does not exist on the path users actually hit.

**Coverage gap:** `_ensureConfigCurrent`'s rebuild branch (the whole reason `_phase1`/`_phase5` are non-final) has ZERO direct test — no test references `TagConfigService`/`configOrNull`/`combinedVersion` rebuild. This is bug-fix code (BUT-1483) with no regression guard. A test: construct with a v1 config, register a `TagConfigService` whose `configOrNull` returns a v2 config, call `runPhase1`, and assert a cuisine/allergen verdict that only the v2 register would produce (proves the rebuild fired). Inject-neither so `_canRebuildConfigPhases` is true.

**Minor:** `_resolveTagConflicts(Set<String> tags, Recipe recipe)` never reads `recipe` (both call sites pass it). Unused param — `flutter analyze` won't flag it. Harmless but signals intended-but-absent recipe-aware conflict logic; the doc comment explicitly says season tags are intentionally NOT resolved, so drop the param or leave a reserved-for-future note.

### 2026-06-28 — BUT-1408 UTC-serialization: DateTime.isUtc vs system-timezone — CI-effectiveness verified [Pattern reviewed]

Reviewed `test/unit/models/feedback_entry_test.dart` — `serializes a local createdAt as a UTC Z string (BUT-1408)` (lines 41-59).

**Key finding: the `endsWith('Z')` assertion is effective on ALL CI machines, including UTC-offset-zero runners.** Dart's `DateTime(y,m,d,h,min)` constructor always produces `isUtc == false`, regardless of the machine's system timezone. `toIso8601String()` appends `Z` if and only if `isUtc == true`. Therefore a revert of `.toUtc()` in `FeedbackEntry.toMap()` always produces a string without `Z`, on any machine. The test catches the regression everywhere.

**The second assertion (line 58)** `expect(iso, local.toUtc().toIso8601String())` is NOT tautological: its expected value derives from the INPUT `local`, not from calling `toMap()` a second time. It adds value by pinning the exact UTC projection (including hour-shift on offset machines) and sub-second precision, which `endsWith('Z')` alone cannot catch.

**Misleading inline comment (line 57):** `// a no-op only when the machine is at UTC` — on a UTC+0 machine, `.toUtc()` is NOT a no-op (it changes `isUtc` from `false` to `true`, producing `Z`). What the comment means is that the numeric hour value is unchanged. This does not affect test correctness but may confuse a future reader into doubting CI coverage.

**Decision rule for DateTime UTC-serialization tests:** Use `DateTime(y,m,d,h)` (no `.utc(...)`) as the input fixture — this guarantees `isUtc==false` on every platform. `endsWith('Z')` catches missing `.toUtc()` universally. Pair with an exact-equality check against `input.toUtc().toIso8601String()` to also pin the UTC projection value and precision.
Group-creation draft migrated from inline `_load/_save/_clearDraft` JSON triad → `AutoSaveManager<Map<String,dynamic>>`. The NOVEL logic (the all-fields-empty → null/remove-key rule + the JSON shape) was extracted into a PURE codec `lib/widgets/social/groups/group_draft_codec.dart` (`buildGroupDraft`/`encodeGroupDraft`/`decodeGroupDraft`) and gated by 7 unit tests. Verdict: the codec test genuinely proves the migration's behaviour-preservation contract; gating via the pure codec instead of a full-widget pump is the CORRECT call, not a shortcut. Reusable judgements:
- **When a widget-draft migration introduces NEW persistence logic, extract the novel decision (emptiness rule + wire shape) into a pure function and gate THAT.** The dialog's residual glue (load→setState + friend-id resolution) is mechanical and shape-identical to 3 already-shipped string migrations — re-pumping the full dialog (provider + l10n + friends-service scaffolding) to re-prove it would be the BUT-368 structural-pump anti-pattern, high cost, near-zero marginal coverage. The codec seam is the right seam.
- **The load-bearing invariant `all-empty ⇒ null ⇒ remove-key` is what survives the refactor and is directly tested** (incl. the absent-fields `{}` defensive case). It flips iff the emptiness rule breaks. Plus a **byte-compat test decoding the EXACT legacy `_saveDraft` JSON blob** (`{"name":...,"emoji":"📚","friendIds":["x"]}`) — this is the migration's real risk (a key-name or shape drift would silently orphan every pre-migration persisted draft, since the SharedPreferences key is kept byte-identical). That test is the single most load-bearing one in the file; keep it.
- **The codec test does NOT prove the manager removes the key when encode→null, nor that the dialog wires encode/decode in.** Those are covered respectively by the AutoSaveManager unit suite (iter-116, `_write` drops the `encoded==null` branch) and are mechanical wiring. So the gap is honest and small. NON-BLOCKING follow-up (file as ticket, mirror BUT-1204): a `create_group_dialog` widget test — seed prefs key `group_creation_draft_v1` → name/emoji/friends restore on open; type → key written; commit → key cleared. This is the one beat the pure codec can't reach (load→field-restore + friend-id resolution from ids). Same shape as the missing URL/text import widget gates.
- **recipe-list-filter NON-fit is correctly documented, not skipped** — `_persistActiveFilters` writes 8 typed per-dimension `PersistenceService` entries (not one JSON key), so it doesn't fit the single-key primitive. The inline `// BUT-1203 exception` comment is the right move; no test owed for a doc-only non-migration.

### 2026-06-23 — BUT-1359/1360 sprint assessment: l10n-sourced widget tests auto-follow string fixes; Mock-with-body OK as a *counting fake*; fake_cloud_firestore ignores GetOptions.source [trigger: assess sprint test coverage]
Four-part sprint, all 16 tests across 5 files green, analyze clean. Verdicts + reusable patterns:
- **BUT-1359 FAQ diacritics (lib/l10n/app_sv.arb ASCII→å/ä/ö).** test/widget/views/faq_view_test.dart reads the 5 questions from `AppLocalizationsSv().faqQ1..Q5` and asserts `find.text(question)` — it sources the expected text from the *same localizations object* the corrected strings live in, so it auto-follows the fix. Grepped the test for old ASCII spellings (`vanner|anvander|Lagg till|Oppna|skarmavbild`…): **zero hardcoded ASCII assertions**, so nothing breaks on the å/ä/ö correction. Note faqQ2 (`vänner`) + faqQ3 (`använder`) gained diacritics in the *question* text the test renders, so this is a live check, not vacuous. **Pattern (good):** a widget test that pulls expected copy from `AppLocalizations*` rather than string literals is refactor-proof against any future copy/diacritic/locale edit — the right way to gate l10n-sourced views.
- **BUT-1360 import fast-fail (test/unit/viewmodels/import_base_offline_test.dart).** Non-vacuous: `_CountingTextImportStrategy` increments `importCalls` in its `import` body; offline test asserts `importCalls == 0` + offline message + `hasParsedRecipe isFalse` (proves the `if (!isOnline)` pre-check in `parseTextToRecipe` short-circuits *before* the 60s-timeout Cloud-Function round-trip), online test asserts `importCalls == 1` + parsed. Call-count is the load-bearing assertion. **Mocktail caveat (acceptable here):** `_CountingTextImportStrategy extends Mock implements TextImportStrategy` with a concrete `@override import` body — normally the banned "concrete @override on a Mock blocks when()" anti-pattern. Acceptable *because* it's used purely as a counting fake (no `when()` stub on `import` anywhere; only its side-effect count is read). Cleaner would be `extends Fake`, but `implements TextImportStrategy` needs the other interface members no-op'd, and `Mock` auto-stubs those to null — so `Mock` is the pragmatic choice. Not a bug; just don't `when(() => strategy.import(...))` it later.
- **BUT-1360 dedupe (Url/PhotoImportVM now inherit `isOnline` from ImportBaseViewModel).** The real regression check is that the pre-existing url_import_offline_test.dart + photo_import_offline_test.dart still pass with the inherited getter (rather than each VM's own copy). Both green (photo: camera/gallery/retryOcr all fail-fast offline; url: BUT-610 suite). Confirms the dedupe didn't change offline behaviour.
- **Menu cache-first (test/unit/repositories/firebase/firebase_weekly_menu_plan_repository_test.dart `fetchForWeek (cache-first)` group).** Prod swapped `collection.doc(id).get()` → `getDocCacheFirst(...)` which does `get(Source.cache)` then falls back to `get(Source.serverAndCache)`. Test asserts the **outcome contract**: seeded week → returns the plan w/ correct `weekIdFor` id; never-cached week → returns `null` without throwing (the `!exists` graceful path). **fake_cloud_firestore source-ignoring caveat (real):** `FakeFirebaseFirestore` ignores `GetOptions.source` entirely — returns the same in-memory doc for cache/server alike. So the test proves the *result* is right but **cannot** prove the cache-then-server routing, that the cache read fires first, or that the fallback branch executes. Verifying the routing itself would need the emulator lane (or a spy on the DocumentReference) — out of scope; the outcome contract is the right thing to gate at the fake level.
- **Coverage gap:** none worth adding. The only thing untested is the cache-vs-server routing of `getDocCacheFirst`, which is an infrastructure-level concern shared across repos (recipe archive read uses it too) and only meaningfully testable on the emulator — not a per-repo gap. Don't bootstrap that here.
- **Reusable distinction:** when a migration *consolidates* duplicated logic into a shared widget (here: each view's own ellipsis truncation → the widget's built-in), the test belongs on the widget (one test, all callers covered), NOT replicated per-view. Adding per-view "title truncates" tests would be the topology/duplication anti-pattern.

### [Pattern] 2026-06-23 — BUT-1360 offline-retain transform: test the pure transform once, assert wiring at the widget seam
Trigger: reviewing offline-resilience tests for RTDB-backed widgets (presence bar, cooking-session card, substitution sheet).
- The load-bearing logic lives in `lib/core/utils/retain_last_nonempty.dart` (`retainLastNonEmptyWhileOffline<T>`). Its five correctness properties are best pinned in a pure stream-transform unit test (`test/unit/core/utils/retain_last_nonempty_test.dart`): online-empty passes through, offline-empty replays last-non-empty, first-empty-offline passes (never invent data), non-empty shrink always passes, and connectivity-flip collapses to the live empty on reconnect. Driving a `StreamController` + a mutable `offline` flag through `.transform(...)` and asserting the exact output list is non-vacuous and refactor-proof.
- Widget-level tests (FamilyPresenceBar, CookingSessionStreamHolder) should NOT re-prove the transform's truth table — they assert the widget *routes its RTDB stream through* the transform via an injectable `isOffline: () => offline` seam (avatar/card retained on offline-empty, collapses on online-empty). Confirm the production widget actually calls `retainLastNonEmptyWhileOffline` (grep lib) so the widget test isn't bypassing it.
- A `class _FakeModule implements CookingSessionModule` with concrete `@override` bodies is a legitimate Fake (it `implements`, not `extends Mock`) — not the mocktail anti-pattern. The anti-pattern is concrete `@override` bodies on `extends Mock`.
- Web-timeout anti-hang contract (item 5): the `kIsWeb` branch can't run in the VM, so test the extracted bounded fetch (`loadWebRecipesBounded` + injectable `webRecipeFetchTimeout`) directly: a never-completing `Completer` future must `completes` within the shrunk timeout AND leave `isLoading == false`; a throwing fetch is absorbed (no rethrow); a fast fetch still replaces the list. Asserting `completes` is what proves "doesn't hang" — an unbounded await would time the test out.

### 2026-06-27 — BUT-941 re-review: auth-gate seam-injection closes a singleton-handler's untestable gap [Pattern + Confirmed-closed]
Trigger: re-reviewing IncomingShareHandler after the prior High gap (auth-gate untested) was addressed.
- `IncomingShareHandler` is a global singleton (factory returns `_instance`) that in production routes through `appNavigatorKey` + `ServiceLocator`. That shape is normally untestable without a device/widget tree. The fix is three `@visibleForTesting` seams that inject the *boundaries* only — `authResolver` (returns the auth repo), `navigate(paths)` (returns bool: false = no live navigator → stays pending), and an injectable `service` arg on `initialize`. The real decision logic (`_route`'s auth-null gate, `_onWarmShare`'s hold-on-unrouted, `initialize`'s try/finally that sets `isInitialized=true` even on a throwing service) runs unmocked. This is the correct seam granularity: mock the navigator/auth/service edges, exercise the real branching. Confirmed the prod handler's `_route` actually consults `authResolver()` and returns false on null user, so the auth-gate test is non-vacuous.
- **Refactor-proofness check:** the auth-gate test asserts behaviour (held when null → routes once a non-null user appears → drains, no double-route) not structure. The drain assertion (`routed.clear()` then a third `processPendingShare()` yields empty) is the load-bearing guard against a regression where `_pendingPaths` isn't nulled after a successful route (double-import). Good.
- **Service no-emit guard is non-vacuous:** `onMedia` only `_mediaController.add`s when the sanitized list `isNotEmpty` (drops non-strings + empty strings first). The `['', null]` payload sanitizes to `[]` so the `expect(emitted, isFalse)` proves the spurious-navigation guard, not just an absent listener.
- **VM offline test:** `verifyNever(() => mockClient.send(any()))` is the meaningful assertion — the `!isOnline` guard sits at the top of `loadImagesFromPaths` (line ~231) before any OCR, so proving the http client never fired proves the fail-fast actually short-circuits (not just that an error was set after wasted work). `_OfflineConnectivity extends Fake` with a concrete getter is a legit Fake, not the Mock-with-override anti-pattern.
- **Residual minor gaps (Low, not worth blocking):** (1) the warm-share last-share-wins supersede comment in `_onWarmShare` (a second unrouted share overwrites `_pendingPaths`) is asserted nowhere — but it's a documented degenerate case ("collisions not realistic for an interactive gesture") and low-value to pin. (2) No test drives a warm share that's held purely on the *auth-null* branch (the warm-start held test holds on navigator-not-ready with auth present); the cold-start test covers auth-null, so the `_route` auth gate is proven once — adequate. Verdict: adequate, all 16 green.

### 2026-06-27 — BUT-1384 age-floor 13→15: boundary tests + defensive-deserializer specific coverage [Pattern]
Trigger: verifying birthYear constructor invariant change and `_readBirthYear` defensive path.

**Three-layer coverage for a threshold change:**
1. **Constructor boundary (both sides):** `currentYear - 15` (accepts) + `currentYear - 14` (rejects, `throwsArgumentError`). The `-14` test is the load-bearing regression guard — it would have PASSED the old 13-floor and must NOW throw. `currentYear - 15` pins the floor exactly (a `>=`→`>` flip makes it throw).
2. **Generic defensive deserializer:** `birthYear: 9999` (future year) and `'abc'` (wrong type) both return null from `_readBirthYear` — correct but does NOT cover the migration-specific case.
3. **Migration-specific defensive deserializer (added):** `currentYear - 14` fed through `fromJson` AND `fromMap` must return null, not throw. Intent: an account stored under the old floor must continue to be readable; the constructor would reject `currentYear - 14` if `_readBirthYear` passed it through. This test would fail if someone changed `parsed > currentYear - 15` back to `parsed > currentYear - 13` in `_readBirthYear`.

**Pattern:** when a model constructor invariant tightens, add a test for the previously-valid-now-invalid value through BOTH the constructor path (expect throw) AND the defensive deserializer path (expect null). The generic "out-of-range" deserializer test with an obviously-wrong value (9999) does not prove the migration boundary — add the boundary value explicitly.

### 2026-06-27 — BUT-1386 (ADR-0002) server-side age verification: CF-gates-onboarding + birthYear-no-longer-client-written tests are sound [Assessment + pattern]
Trigger: reviewing the OnboardingViewModel age-verification tests + UserProfile birthYear-absence test for the move to a `verifySignupAge` Cloud Function as the sole age authority and sole writer of `birthYear`.

**Verdict: all sound, no edits. 99/99 green (onboarding_viewmodel_test + user_profile_test), analyze clean across all 3 touched files incl. onboarding_journey_test.**

The four new VM tests (`BUT-1386 server-side age verification` group) each pin a distinct branch of `completeOnboarding`'s pre-write gate (prod `onboarding_viewmodel.dart:234-249`) and are non-vacuous:
- **CF-called-before-completing (compliant path):** `verifyAge(year).called(1)` + onboarding write `.called(1)` + `ageRejected isFalse`. Ordering (CF gates the write) isn't pinned *here* but is pinned by implication in the rejection test below.
- **skips CF when no birthYear declared:** `verifyNever(() => verifyAge(any()))` — proves the `if (_selectedBirthYear != null)` gate. Load-bearing because age-agnostic suites (skip path, analytics tests) must never trip a CF round-trip.
- **under-15 rejection:** `result isFalse` + `ageRejected isTrue` + `verifyNever` onboarding write. The `verifyNever` write is the load-bearing ORDERING + seeding-block guard: rejection must bail BEFORE seeding/marking complete (the CF already deleted the Auth account). Would fail if a refactor moved the write above the gate.
- **infra-error path (the user's specific scrutiny target — IS it asserted that an infra error is NOT treated as under-15?):** YES, correctly. Test stubs `verifyAge` → `thenThrow`, asserts `result isFalse` + **`ageRejected isFalse`** + `verifyNever` onboarding write. This is the exact contract: prod's INNER try/catch (lines 240-243) returns false WITHOUT setting `_ageRejected`, vs the under-15 branch (244-248) which sets it. The test would fail if someone collapsed the two paths (e.g. moved `_ageRejected = true` into the catch, or dropped the inner try/catch so a thrown error escaped to the outer catch with the flag still false but the write also skipped for the wrong reason). The typed-rejection-vs-generic-retry distinction is what the view keys off to show butler-rejection vs retry-error — pinning `ageRejected` on both paths is the right seam.
- **Timeout sub-path note:** prod wraps `verifyAge(...).timeout(_completionTimeout)`; a hung CF throws TimeoutException through the SAME inner catch as the generic-exception test, so it's covered by implication (no separate test needed).

**UserProfile birthYear-absence test (replaced the old "round-trips through settings write"):** correctly inverts the contract. birthYear is now CF-authoritative, so the test asserts it is ABSENT from BOTH `toFirestoreEditable()` AND `toPrivateSettings()`. Non-vacuous + load-bearing because: (a) `toFirestore()` STILL includes birthYear (line 429) and `toFirestoreEditable()` strips it via an explicit `data.remove('birthYear')` (line 364) — so a dropped `remove` would ship the stale client value into the real write surface; (b) `firebase_user_repository.dart:164` writes profiles via `toFirestoreEditable()`, so this is the actual production write path, not a hypothetical one; (c) a stale in-memory birthYear colliding with the CF-set value would get the WHOLE profile write rejected by firestore.rules. `toPrivateSettings()` simply never lists it — the test guards a regression that re-adds it.

**Pattern (reusable for "field X moved from client-written to server-authoritative"):** invert the old round-trip test into an ABSENCE assertion on every client-write surface (`toFirestoreEditable` / `toPrivateSettings` / any merge-write map), and verify the assertion is non-vacuous by confirming the field still exists on the model and still appears in the base `toFirestore()` (so it COULD leak). Cross-check the repository to confirm which map is the real write path. Pair with a VM/service test proving the server call gates the downstream write (`verifyNever` the write on the server-rejection path = the ordering guard). The infra-error-vs-business-rejection distinction must be asserted on BOTH the typed-flag (`ageRejected`) AND the downstream-write-skipped (`verifyNever`) — asserting only the return value (`false` on both) would not distinguish them.

**All 67 tests passed** (66 pre-existing + 1 added for the specific 14yo boundary on both deserialization paths).

### 2026-06-27 — BUT-1386 age-CF moved gate-advance → resume regression guard (Pattern verified)

Re-reviewed the reworked `test/unit/viewmodels/onboarding_viewmodel_test.dart`
"BUT-1386 server-side age verification at the gate" group after the resume-fix
relocated the primary age-CF mint from completion to the gate advance
(`verifyAgeGate`). All 36 tests pass. Verdict: contract-proving, not green-chasing.

Production control flow confirmed against the test claims:
- `verifyAgeGate()` calls the CF, sets `_ageVerifiedThisSession = true` ONLY on a
  compliant result, sets `_ageRejected = true` ONLY on an explicit `false`
  (under-15), and on a THROW returns `error` WITHOUT touching `_ageRejected`.
- `completeOnboarding()` re-verifies only under the guard
  `_selectedBirthYear != null && !_ageVerifiedThisSession` (belt-and-suspenders).
- A resumed session has `_selectedBirthYear == null` (in-memory only;
  `setInitialPage` touches only `_currentPage`/`_viewedPages`), so the null short-
  circuits the guard → CF never called → completion still writes.

**Mutation-tested the two load-bearing assertions** (the whole point — confirm
they'd have failed through the original Critical regression, not just pass):
1. Removed the `_selectedBirthYear != null` null-guard → resume test went red
   (the `verifyAge(_selectedBirthYear!)` NPEs, completion returns false, caught
   by the test's `result == isTrue`).
2. Dropped the `_ageVerifiedThisSession = true` mint in the gate → "compliant gate
   pass NOT re-verified" test went red on its `verifyNever(verifyAge)`.
Both restored after; full suite green. The resume guard pins BOTH halves
correctly: `verifyNever(verifyAge)` AND `verify(completeOnboardingWithPreferences).called(1)`
— "no CF call" paired with "completion still succeeds/writes", so a regression
that re-verifies on resume can't sneak past on the default-true CF stub.

**Reusable pattern for "this guard must NOT fire on resume/restored state":** a
test that only asserts the happy return value is green-blind when the stubbed
dependency returns success anyway. Pin the NEGATIVE (`verifyNever` the dependency)
AND the POSITIVE downstream side effect (`verify(...).called(1)`) in the same
test. Then prove non-vacuity by mutating the production guard and watching THAT
test (not some other) go red. The infra-error-vs-under-15 distinction is
correctly asserted on the typed flag (`ageRejected` is/ isn't set) rather than
the shared return value — same lesson as the UserProfile entry above.

### 2026-06-27 — BUT-1386 (ADR-0002) server-side age gate review [Pattern discovered]
Reviewed the age-gate test trio (onboarding VM, UserProfile model, onboarding journey). All three prove intended behavior, not green. Key patterns worth reusing:
- **CF-as-sole-writer asserted negatively on EVERY client write surface.** The model test pins `birthYear` absent from BOTH `toFirestoreEditable()` and `toPrivateSettings()` with reasons tied to the firestore.rules deny + stale-collision risk. This is the right shape: assert absence on each surface a client actually writes through, not just one.
- **Three CF outcomes fully covered at the gate** (`verifyAgeGate`): compliant→`AgeGateAdvanceResult.compliant` + `verifyAge` called once + `ageRejected==false`; under-15→`rejected` + `ageRejected==true`; infra throw→`error` + `ageRejected==false` (retry, NOT the permanent rejection). The `ageRejected` flag is the load-bearing discriminator between "quiet butler rejection + route to start" and "generic retry" — both branches pinned.
- **Resume-bug invariant pinned** (the actual point of moving the mint to the gate): a resumed session (`setInitialPage(2)`, no birth year held) completes WITHOUT calling the CF; the belt-and-suspenders at completion fires ONLY when a year is held this session AND the gate handler didn't verify it. Both the "skip CF" and "belt fires once" paths tested.
- **Mocks mock the dependency, not the subject.** `AgeVerificationService` is a pure `Mock` (no override bodies, so `when()`/`verify()` work). The VM under test is real. Good.
- **Gap (Medium, not blocking): the journey test never exercises the gate CF.** `onboarding_journey_test.dart` advances page 0→1 via the `next` button → `nextPage()`, which does NOT call `verifyAgeGate()`. So the journey relies on the completion-time belt for its single `verifyAge` call, and never proves the under-15 / infra-error branches at the journey (widget) level — no "under-15 picks a young year → sees butler rejection → routed back to start" journey case exists. The VM unit tests cover the branches, but the user-visible rejection routing is untested end-to-end. A future journey case (tap a young year, attempt advance, assert rejection UI + back-to-start) would close this. The stub `_OnboardingBody` would need a real `verifyAgeGate()` call wired into its age-gate `next` handler to be faithful to production.

### 2026-06-27 — BUT-1393 profanity-gate VM tests (review)
**Trigger:** Review of two new tests (chat + comment) verifying the client-side profanity gate. Verdict: CLEAN, no Critical/High.

- **Real-filter injection pattern is correct here.** Both tests register the REAL `ContentFilterService()` via `TestServiceLocator.registerMock<ContentFilterService>(...)` BEFORE building a fresh VM, because the gate-holder (`ChatViewModel` ctor line 65; `SocialCommentsManager` ctor line 33) captures the filter via `ServiceLocator.get/tryGet` at construction. The default `setUp` VM is built before this registration, so a fresh VM is mandatory — using the shared `viewModel` would miss the filter. This is the right call: mocking the filter would mock away the behaviour under test.
- **Non-tautology confirmed both ways.** Chat: `_contentFilter.ensureClean` sets `_sendError` + returns false before `sendTextMessage` (chat_viewmodel.dart 280-288); if removed, send succeeds → `sendError` stays null → `expect(sendError, isNotNull)` fails. Comment: gate sets `_commentsError` + returns before `addComment` (social_comments_manager.dart 165-176); the default `FakeSocialRecipeOperations.addComment` returns a NON-null id (production_mocks.dart 2348), so removing the gate makes the post succeed → `newCommentText` cleared to `''` + `commentsError` null → BOTH assertions fail. Neither is a tautology.
- **`'fan'` and `'javla'` are genuinely on the list** (content_filter_words.dart 29, 33), and `_normalize` folds `jävla`→`javla`. So `'din jävla fan'` is genuinely flagged — not a silent clean-string pass.
- **Discriminator guards against passing for the wrong reason.** Chat gate is only reached when `canSendMessages` is true (early-return at line 269). If `canSendMessages` were false the test would still get `result==false` but `sendError` would stay null → `isNotNull` catches it. The shared setUp makes `user2` a friend + sets PermissionService uid, so the gate IS reached. The `sendError isNotNull` / `commentsError isNotNull` assertion is what makes "green for the wrong reason" impossible.
- **Pattern for future UGC-gate tests:** register real `ContentFilterService` → fresh VM/manager → feed a token from `swedishProfanity`/`englishProfanity` → assert (error surfaced) AND (no service write / text not cleared). The error-surfaced assertion is load-bearing; a bare `result==false` would pass on the empty-text guard too.

### 2026-06-28 — BUT-1440 Fake-default-same-as-expected makes a regression-guard vacuous [Pattern — guard ineffectiveness]
Trigger: reviewing `exportPantryItems forwards its computed limit to the repo (BUT-1440)` in `test/unit/services/account/export/content_export_manager_test.dart`.

The test captures `capturedMaxDocuments` via `_FakePantryRepository` and asserts `== 1000`. The problem: `_FakePantryRepository.exportAllByUser` defaults `int maxDocuments = 1000`, which is the same value `ExportPaginationHelper.getLimitForType('pantry_items')` returns (confirmed in `export_pagination_helper.dart` line 182). So if the production fix is reverted and the argument is omitted entirely, Dart fills the fake's own default (1000) into `capturedMaxDocuments` and the assertion still passes. **The guard is vacuous against the regression it exists to prevent.**

**Root cause of the ineffectiveness pattern:** when a Fake's parameter default equals the expected captured value, there is no way to distinguish "caller explicitly passed the value" from "caller omitted it and the Dart default filled in." This is structurally invisible to the test.

**Fix — use a sentinel default on the Fake:**
Change the Fake's default to a value that can never be a valid limit (e.g. `-1`). Then assert `capturedMaxDocuments == 1000` (or `isNot(-1)`) — equality is meaningful only if the caller actually passed 1000, because omitting the arg would capture -1.

```dart
// In _FakePantryRepository:
@override
Future<List<Map<String, dynamic>>> exportAllByUser(
  String userId, {
  int maxDocuments = -1,   // sentinel: -1 = arg was omitted by caller
}) async {
  capturedMaxDocuments = maxDocuments;
  return rows;
}

// Test assertion (now non-vacuous):
expect(pantryRepo.capturedMaxDocuments, 1000);
// Reverting the production fix → captures -1 → assertion fails. Correct.
```

**Decision rule:** whenever writing a "did the caller forward argument X?" test using a Fake that captures via an optional parameter, set the Fake's parameter default to a sentinel value that no valid caller would pass. The captured-value assertion is only load-bearing when the Fake's default differs from every plausible explicit value. This applies to any numeric limit, timeout, or enum capture where the zero/default is a valid production value.

**Affected file/line:** `test/unit/services/account/export/content_export_manager_test.dart`, `_FakePantryRepository.exportAllByUser` default at line 135, assertion at line 463.

### 2026-06-28 — CircuitBreaker half-open in-flight probe (BUT-1414) [trigger: review of concurrency-guard test]
- **getter→method conversion was load-bearing, not cosmetic.** `allowRequest` became a METHOD because it now MUTATES state (sets `_halfOpenProbeInFlight = true` when it hands out the single probe slot). A side-effecting getter would be the maintenance trap the production doc-comment (circuit_breaker.dart 49-51) warns against. All call sites + tests had `cb.allowRequest` → `cb.allowRequest()`; purely syntactic at the assertion level (same value asserted), so no existing assertion was weakened.
- **Sequential simulation IS the right way to test a Dart "concurrency" race.** Single isolate ⇒ the real race is "two callers enter the half-open window before the probe resolves." Test models it as two back-to-back `allowRequest()` calls inside one `withClock(start+31s)` block — first true (gets slot), second false (slot taken). No threads, no fakeAsync needed for the guard itself; `withClock` only pins the reset boundary (`elapsed 31s >= resetTime 30s`).
- **Non-tautology confirmed:** delete the `if (_halfOpenProbeInFlight) return false;` line (66) and the 2nd `allowRequest()` re-enters the elapsed branch (clock still start+31s) → returns true → `expect(..., isFalse)` (test line 130) fails. Genuinely exercises the guard.
- **Reopen-after-probe-failure leg is also deterministic:** `recordFailure()` stamps `_lastFailureTime = start+31s` (same injected clock), so the following `allowRequest()` sees `elapsed 0 < 30s` → false. Tests the latch-reopen without a second `withClock`.

### 2026-06-28 — BUT-1413 PII-scrubber cross-port parity review [Pattern discovered]

**Fixture parity is enforced by a BYTE-EQUALITY assertion, not a shared path.** The two fixture copies (`test/unit/services/llm/fixtures/pii-heuristic-vectors.json` and `functions/src/__tests__/fixtures/pii-heuristic-vectors.json`) are confirmed byte-identical. The Dart test `pii_scrubber_heuristic_vectors_test.dart` (line 39) asserts `file.readAsBytesSync() == source.readAsBytesSync()`, so any silent content drift (same vector count, edited input or expected) is a hard failure. This is the right pattern for cross-port fixture parity when the two fixture files must live in sibling directory trees — do NOT rely on documentation alone, and do NOT try to share a single path (the TS and Dart test runners resolve paths from different CWDs).

**The Dart main scrubber test (`pii_scrubber_test.dart`) does NOT load the shared fixture directly.** That is correct: `pii_scrubber_test.dart` exercises the scalar/list/map API of `scrubPayload` and `scrubUrlParams`; the fixture-driven contract (full-string equality on 28 heuristic vectors) lives in the sibling `pii_scrubber_heuristic_vectors_test.dart`. Both files must be run together for full coverage.

**All three BUT-1413 gap tests pass the non-tautology check:**
- **Gap 1 (list-URL params):** would fail if `_scrubValue`'s `List` branch called `scrubPii(v)` instead of `_scrubStringLeaf(key, v)` — `scrubPii` has no URL query-stripping logic. Confirmed by reading `_scrubValue` at line 317 of `pii_scrubber.dart`.
- **Gap 2 (slug PII):** `storgatan-14` and `mormor-Anna` are under the 20-char opaque-segment threshold so `_looksOpaquePathSegment` returns false for both. The only code path that fires is `_slugContainsPii`. Delete `|| _slugContainsPii(seg)` at line 165 and both scrubUrlParams slug tests fail. The negative case (`gulasch-med-svamp-russin`) independently catches an over-broad heuristic.
- **Gap 3 (base64 pass-through):** the `_opaqueKeys` fast path only covers the literal key `'imageBase64'`. The 160-char blob under `'unknownImageField'` reaches `_looksLikeBase64Blob` at line 307. Remove that branch and the blob is passed to `_scrubStringLeaf`, which runs `scrubPii` — the base64 alphabet is unlikely to accidentally contain personnummer patterns, but URL detection fires on any value starting `https://`; a blob starting with a schema prefix would be corrupted. The test uses a pure-alphabet blob so it proves the heuristic gate, not the corruption path.

**TS test harness is a bespoke runner (no Jest/Mocha), not a standard test framework.** `runTests()` prints PASS/FAIL and calls `process.exit(1)` on failure. This means (a) no IDE test discovery, (b) test output requires `npx ts-node` invocation per the file header, and (c) a thrown exception inside `PAYLOAD_CASES[n].run()` is silently caught and reported as FAIL (line 418–420) — the exception message is swallowed. If a bug causes a thrown RangeError rather than a wrong return value, the failure message says only `note: ...failNote`, not the error. This is intentional for defensive robustness but makes debugging harder. **If a TS PAYLOAD_CASE mysteriously fails, add a `console.log(e)` in the catch block temporarily.**

**The TS `scrubPayload` list branch casts the array as `unknown as string`** (lines 273, 296) to satisfy the TypeScript type signature `Record<string, string>`. This is a deliberate lie to the type system. If the production `scrubPayload` type ever narrows from `Record<string, unknown>` to `Record<string, string>`, the cast would be unnecessary — but right now it is the correct workaround for testing a `string | string[]` value under a `string`-typed interface. Flag this if the production TypeScript signature changes.
- **Probe slot is released by recordSuccess/recordFailure/reset** (lines 91, 110, 119) — a caller that takes the slot but never records an outcome latches the breaker in half-open forever. Acceptable because every production caller records via execute/executeWithFallback; worth a note if a future raw `allowRequest()` caller appears.

### 2026-06-28 — Household model review: five gaps found [Pattern discovered]

Reviewed `test/unit/models/household_test.dart` (11 tests) against `lib/models/household.dart`. The suite covers the core contracts well but has five meaningful gaps:

1. **`memberUserIds` uses `containsAll` instead of `unorderedEquals`.** A duplicated list (`['malin','malin','johan','farmor']`) passes the current assertion. Firestore `arrayContains` membership queries depend on no-duplication; the correct matcher is `unorderedEquals(<String>['malin','johan','farmor'])` paired with `expect(hh.memberUserIds.length, hh.members.length)`. P2.

2. **Projections are not re-checked after mutation.** `addMember` / `removeMember` tests verify `isMember`/`canEdit` on the structured list but never assert the resulting `memberUserIds`/`memberPermissions`. If `memberUserIds` were cached at construction rather than lazily computed, ALL existing mutation + round-trip tests stay green while the Firestore rules read stale projections. The fix: after `withJohan = base.addMember('johan')`, assert `withJohan.memberUserIds.contains('johan')` and `withJohan.memberPermissions['johan'] == 'edit'`. P2.

3. **`addMember` idempotency test does not check projection key count.** `again.members.where((m)=>m.userId=='johan').length == 1` catches struct duplicates but `again.memberPermissions.keys.where((k)=>k=='johan').length` is never checked. A bug that let `memberPermissions` enumerate all members (including invisible duplicates) stays green. P2.

4. **Unknown permission string falls back to `edit` — not tested.** `HouseholdMember.fromMap` uses `safeEnumByName(..., defaultValue: SharedListPermission.edit)`, so `"permission": "superadmin"` silently grants edit. A corrupt or forward-schema document becomes an editor without any guard firing. No test covers this; a single `fromMap({'userId':'x', 'permission':'superadmin', 'addedAt':...})` call with `expect(member.permission, SharedListPermission.edit)` would close it. P2 — Firestore rules rely on the `memberPermissions` map value being one of the known strings.

5. **`removeMember` no-op on absent user is untested.** `addMember` idempotency (second add returns `this`) is pinned; the symmetric contract (`removeMember('stranger') == this`) is not. Low regression risk but asymmetric coverage for two methods documented as complementary no-ops. P3.

---

### 2026-06-29 — [Trigger: review] Read-surface masking a no-write contract + proxy-mirror privacy contract needs verifyNever
Reviewed `test/unit/viewmodels/family/family_rating_entry_viewmodel_test.dart` (6 tests, FamilyRatingEntryViewModel, Phase 3 item 10). Suite is behaviorally honest (real repo+roster stack on FakeFirebaseFirestore, no topology/theme asserts). Two patterns worth carrying forward:

1. **A "no-write" contract asserted via the read surface can't tell a no-write from a filtered-on-read zero.** The "SKIPS empty rows" test asserted `getMemberRatings(...)` has no entry for the unrated member. But `getMemberRatings` filters `hasValidStars`, so a regression that wrote `stars:0` instead of skipping (`if (stars<1||stars>5) continue` → `rateAsFamily(stars:0)`) stays green — the 0-row is dropped on read. To firmly pin a no-write, assert at the WRITE surface: inject a `MockFamilyRatingService` and `verifyNever(() => mock.rateAsFamily(memberId: x, ...))` for the empty row, `verify(...).called(1)` for rated rows. End-to-end read-back is a fine companion but cannot pin the no-write alone. General rule: when the contract is "no side effect happened," verify the absence of the call, not the absence of its observable trace (the trace may be independently filtered).

2. **Mirror/proxy privacy contract needs verifyNever on the mirror target.** FamilyRatingService mirrors a genuine adult self-rating (`memberType==user && enteredByUid==memberId`) to `social.rateRecipe`, but a proxy entry (rating a child) must NOT. The VM owns the holder/proxy distinction (`isHolder`/`_currentUid`, per-row memberType from roster `fromUser`/`fromDinerProfile`). The test stubbed `socialOps.rateRecipe` but never verified call/no-call, so the highest-value contract (a child's verdict must not bump the parent's public score — a privacy leak) was unproven. Fix: after save, `verify(() => socialOps.rateRecipe(recipeId:_recipe, rating:<holder stars>)).called(1)` and `verifyNever(...)` for the profile member's stars. The `isHolder` getter test alone proves nothing about the save path.

Also flagged: out-of-range guard (`stars>5`) only tested on the low end; no error-path test (`save()` before `load()`, logged-out `load()`); no notification assertion on `setStars`; and a latent smell — the test builds a second local `FamilyRatingService()` distinct from the locator-registered one the VM resolves (works only because both share the same repo from the locator). Did not edit; report-only review.

**Decision rule reinforced:** for any denormalised projection field that security rules read via map-key access (`memberPermissions[userId]`), tests must verify the projection AFTER mutation, not only on a static fixture. A static fixture exercise of `memberPermissions` + a separate mutation test that never re-checks the projection is the exact "stubbed-both-ends" shape that leaves the wire untested.

### 2026-06-29 — Family-rating card-pill denormalization review (Phase 3 item 12)
**Trigger:** reviewed new tests for `FamilyRatingService._denormalizeFamilyAverage` (writes recomputed household avg onto `recipe.core.familyAverage`/`familyRatingCount` via `UnifiedRecipeService.updateRecipe`, best-effort + owned-only + `updatedAt` preserved). Tests at `test/unit/services/family/family_rating_service_test.dart` group "family-average denormalization (card pill source)" and `test/unit/models/recipe_unified_test.dart` group "RecipeCore family-rating denormalization". All passed; verdict was intent-driven, no weak assertions, no topology asserts. Report-only, no edits.

**Strong patterns confirmed:** `verify(() => svc.updateRecipe(captureAny())).captured.last as Recipe` then assert `.core.familyAverage`/`familyRatingCount` is the right way to prove a denormalized projection write — captures the converged value after N rate() calls, breaks on a mean swap or field mix-up. `verifyNever(updateRecipe)` + `saved isNotNull` cleanly proves owned-only-skip AND best-effort-survives-skip in one test. Mock classes body-less (correct).

**Gap pattern — equal-weight mean not isolated.** Spec said every diner weighted equally (a 6-yo == an adult). The denorm test mixed a `profile`(4)+`user`(2)→3.0, but `(4+2)/2` is ALSO what a type-weighted/count-weighted scheme produces for two raters — so an adult-double-weight bug would NOT fail any test. To pin equal-weight you need asymmetric stars across member types: `profile`=5 + `user`=1, assert avg==3.0 (equal) which becomes 2.33 under adult-2x. **Rule: to pin "weighting X", the test inputs must make X's wrong alternative produce a DIFFERENT number.** Same-value or symmetric inputs prove nothing about the weighting.

**Gap pattern — null-clamp branch (un-rate-the-last) untested.** Production writes `summary.hasRatings ? avg : null` for BOTH fields. "Skip when not in list" returns before that branch; "writes" only hits `hasRatings==true`. The owned-recipe + all-ratings-removed → `updateRecipe` carries `familyAverage:null, familyRatingCount:null` path was unguarded. If prod wrote `0.0`/`0` instead of null, a future card refactor could leak a "familj 0,0" pill (card guard is `familyRatingCount ?? 0 > 0`). Always test the field-clears-to-null arm of a denormalization, not just the writes-a-value arm.

**Gap pattern — best-effort isolation unproven.** Helper is try/catch-wrapped and awaited BEFORE the social mirror. `when(updateRecipe).thenAnswer(true)` always succeeds, so "a denorm failure keeps the rating + still mirrors" (the helper's own doc promise, BUT-369-style) had no test. Add `updateRecipe` `thenThrow` with recipe present, assert `saved != null` and mirror still fires for a self-rating.

**Widget-test call for branching pills = yes, worth it.** `recipe_card.dart` has real behavioral branching no test touched: `if (hasFamily) familyPill else if (hasPersonal) personalPill` (family SUPERSEDES personal) + `if (hasAlla)` shown alongside. Defend the supersession (else-if) and co-render, NOT padding/icon. Assert via `find.bySemanticsLabel(context.l10n.a11yFamilyRatingPill(...))` resolved from live localizations + capture `cs.primary` via Builder. Express guards behaviorally (count 0 + non-null avg → no pill) so it survives a guard-expression rewrite — don't assert the two guard sub-conditions as separate topology checks.

### 2026-06-29 — Family-rating menu-weight influence review (Phase 4 item 13)
**Trigger:** reviewed new group "Family-rating influence (Phase 4 item 13)" in `test/unit/services/menu_service_test.dart` (lines 642-714). Subject: `MenuService._ratingMultiplier` prefers `recipe.core.familyAverage`/`familyRatingCount` when `familyRatingCount > 0`, else falls back to public/personal `rating`/`ratingCount`; maps 1★→1.0, 5★→1.4, unrated→1.0. Tested via `MenuService.debugRecipeWeight(r, seasonTag: 'no_season')` (never-cooked → equal 90-day recency, so the rating multiplier is the only differentiator). 3 tests, all pass. Report-only, no edits.

**Strong pattern confirmed — pin precedence by CROSSING the two signals.** The key precedence test gives recipe A family 5 / personal 2 and recipe B family 2 / personal 5, then asserts `weight(A) > weight(B)`. Because the signals point in OPPOSITE directions, the strict inequality fails under both likely regressions: precedence flipped to personal (inequality reverses) AND signals averaged (both land equal, `greaterThan` fails). This is the right shape — same-direction or same-value inputs would prove nothing (cf. the equal-weight-mean gap from the Phase 3 item 12 entry: "to pin weighting X, inputs must make X's wrong alternative produce a DIFFERENT number"). copyWith persists these fields via the sentinel pattern (`recipe_unified.dart` ~544-549), so the test isn't riding a copyWith bug.

**Gap — the `familyRatingCount == 0` fallback arm is untested.** Production guard is `familyAvg != null && familyCount > 0`. The fallback test only exercises `familyAverage == null` (the null arm). A non-null `familyAverage` with count 0 (a realistic state: field pre-initialized, or count decremented to 0 after a withdrawal) is a SECOND fallback trigger. Build `familyAverage: 1.0, familyRatingCount: 0, rating: 5.0, ratingCount: 30` → must reach the 5★ personal boost, not the 1★ family penalty. If someone drops the `&& count > 0` from the guard, every current test still passes. Same lesson as the null-clamp-arm gap in Phase 3 item 12: test BOTH conditions of a compound guard.

**Gap — the 1.4x ceiling is not pinned on the family path.** The sibling personal-rating group asserts `weight(5★)/weight(unrated) <= 1.4` (line 634-638) but nothing asserts it for the family branch. Test 1 only checks an inequality, the fallback test only equality at 5★, the flop test only the floor — a family 5★ producing 1.8x would pass all three. Add `weight(familyFiveStar)/weight(unrated)` `closeTo(1.4)` (or `<= 1.4 + 1e-9`). Guards a future family branch written with its own multiplier math that forgets the `_maxRatingBoost` ceiling.

**Note — "soft not veto" test name slightly over-promises.** The flop test (`familyAverage:1.0` → `weight > 0` AND `== weight(unrated)`) proves "1★ family maps to multiplier 1.0", which the `== unrated` assertion already nails (catches a 0.1 veto-multiplier too); the `> 0` assertion is essentially subsumed. True "never excluded" is a SELECTION test (recipe still appears in `generateMenuFromParsedRequest` output when it's the only candidate), not a weight-math test. The group tests the multiplier, not pool exclusion — fine as-is, just don't read the name as proving exclusion can't happen. No weak assertions, no topology asserts, float tolerances (`closeTo(.,1e-9)`) correct.

### 2026-06-29 — Present-aware allergen filter: union + fall-through are the load-bearing cases
- **Trigger:** reviewed `menu_generator_present_aware_test.dart` (family Phase 4) — 2 tests pinned single-present-member filter on/off but not the union or the unresolvable-roster path.
- **Pattern:** for `MenuGenerator.presentMemberIds` filtering, the single-present-member test ("absent child's allergy doesn't filter") is necessary but NOT sufficient. The real regression surface is `_presentAllergenPrefs`'s union loop (`lib/viewmodels/menu/menu_generator.dart` ~L174-181): a "take first" or null-prefs regression passes the single-member tests and only fails a **both-present union** test (present=`[adult, kid]` must still exclude the kid's allergen). And the **unresolvable-roster fall-through** (roster returns null → single-user filtering) needs its own test or a regression there silently drops ALL filtering — an allergen-safety hole. When reviewing any "present/attendee-scoped" filter: demand union + fall-through, not just on/off.
- **FamilyRatingService.removeRating mirror:** the self-rate-vs-child guard is `_isSelfRating(existing)` read off the PERSISTED entry, so the un-rate side has its own proxy invariant independent of the rate side — un-rating a proxy entry must NOT `socialOps.removeRating` (would retract the proxied member's genuine public rating). `verifyNever` "child never mirrors" tests have a false-negative risk: they also pass if the seed verdict never persisted (then `existing==null` short-circuits before the guard). Assert the seed exists, or pair with a `verify(...).called(1)` on the delete, to prove the path was actually reached.

### 2026-06-30 — BUT-1426 inline-link a11y: existing full-graph auth test is the right host; isHidden + label-merge gotchas [Pattern + Helper-reuse]
- **Trigger:** coverage assessment of BUT-1426 a11y fix to `lib/views/auth_view.dart` — register consent checkboxes now `_buildConsentCheckbox` (>=48dp tap target), inline ToS/Privacy links migrated from `Text.rich`+`TapGestureRecognizer` spans to `Semantics(link:true,label:)`+`GestureDetector` (new l10n keys `a11yTermsOfServiceLink`/`a11yPrivacyPolicyLink`).
- **Path taken: A (lightweight, hosted in the EXISTING test).** `AuthView` does need the full auth graph, BUT the convention's "skip heavy scaffolding" cost is about *building* it — `test/widget/views/auth/auth_view_legal_links_test.dart` (BUT-563) ALREADY pumps the real `AuthView` with a real `AuthViewModel`+mocked `AuthService` via the prod-ServiceLocator/TestServiceLocator GetIt bridge (`prod.ServiceLocator.initialize(DIContainer())`). Adding a11y assertions there is free. Don't write a new skipped test or a from-scratch graph just to cover this.
- **The refactor BROKE that test's `_tapSpan` helper** (it walked `RichText`→`TapGestureRecognizer`, both deleted). Intent ("inline links navigate") still correct, so I rewrote to the new structure (`find.bySemanticsLabel` + `ensureVisible` + `tap`), NOT weakened it. Reconfirms: a deleted-recognizer refactor is exactly the case where the BUT-563 span helper must be replaced, not patched.
- **Two `find.bySemanticsLabel` gotchas on `Semantics(label:X, child: Text(visible))`:**
  1. **Label merges.** The node's rendered label is `"<a11y label>\n<visible text>"` (e.g. `"Användarvillkor\nVillkor"`). Exact-string `bySemanticsLabel` finds 0. Use a `RegExp` Pattern (`RegExp('Användarvillkor')`); anchor with `^` when the same word also appears as a standalone footer link (privacy: `^Integritetspolicy` + `.last` selects the inline node, footer renders first).
  2. **Off-screen = `isHidden` = unfindable.** The consent rows live in a `SingleChildScrollView` below the default test surface, so their semantics nodes carry `flags: isHidden` and `bySemanticsLabel`/`tap` find 0. `await tester.ensureVisible(finder)` before asserting/tapping. This is a TEST artifact (small surface), NOT a production a11y bug — verified by scrolling clearing isHidden.
- **48dp tap-target test = assert RENDERED size, not the literal.** `for (cb in find.byType(Checkbox)) tester.getSize(...).width/height >= 48.0`. Survives swapping `SizedBox(48,48)` for Padding/constraints; pins the WCAG 2.5.5 regression (old `SizedBox(24,24)` would fail). Two `Checkbox` widgets in register mode are distinguishable by `find.byWidget` (differ by `value`).
- **Audit script as structural guard: confirmed satisfied.** `tools/audit_unwrapped_tap_targets.dart` (now matches `TapGestureRecognizer` too, BUT-1426) does NOT flag `auth_view.dart` — the `Semantics(` anchor within its 10-line proximity window clears each `GestureDetector`, and `Checkbox(` is a self-labeling allow-list anchor. So the widget test (behaviour: navigation + named link role + 48dp) and the audit (structure: nothing unwrapped) are complementary, not redundant.

## 2026-06-30 — BUT-1447 theme-color migration (heroPaleGreen slot + family-screen token swap)

**Trigger:** New `ButleryColors` ThemeExtension slot added; 6 family screens + recipe_card swapped hardcoded `AppColors.*` for `cs.*` / `context.butleryColors.*` tokens, claimed light-pixel-identical.

- **New ThemeExtension slot → mirror the existing slot's test group, don't invent a new style.** `test/unit/theme/butlery_colors_extension_test.dart` already had a 6-test template for `iconMuted` (light hex / dark hex / copyWith preserve / copyWith override / lerp / Theme-accessor). For `heroPaleGreen` I copied that group verbatim with the new values. The load-bearing assertion is **light value == legacy literal** (`heroPaleGreen` light == `0xFFE8F0EA` == old `AppColors.greenPale`): THAT is what proves "light mode unchanged" at the source, independent of any widget render. If a refactor accidentally retuned the light value, this one-line test fails before any golden does. 6→12 tests, all pass.
- **For a pure token-swap migration, the right coverage is: source-value pin (unit) + light-render guard (golden + behaviour widget tests). Do NOT add ServiceLocator-graph view tests just to cover the swapped screens.** The token→legacy-literal mapping (`cs.primary`=forestGreen 0xFF4A7C59, `cs.secondary`=rust, `cs.outline`=textLight, `cs.surface`=cream, `cs.error`=error, `cs.outlineVariant`=divider, `heroPaleGreen`=greenPale) is verified end-to-end because `createLocalizedTestApp` pins the real `AppTheme.lightTheme`, so the existing `family_widgets_test.dart` (7 behaviour tests) and `recipe_card_golden_test.dart` (2 goldens) exercise the live resolution — a missing/null token would throw on build, a wrong light value would shift the golden. The family widget tests assert TEXT/behaviour not pixel colors, which is correct: golden owns pixel-identity, behaviour tests own "still builds under the theme."
- **Context-less helper fallback is a literal, by design — not a finding.** `parseAvatarColor` in `family_widgets.dart` has no `BuildContext`, so its fallback stays the raw `Color(0xFF4A7C59)` (the value behind `cs.primary`) rather than a token. Don't flag this as "should use the theme token"; there's no context to resolve one and the literal equals the light value.
- **Coverage verdict for this class of change:** adequate with the one unit test added. The screens with no dedicated widget test (`family_member_form_view`, `family_rating_breakdown`, `family_rating_entry_view`, `min_familj_view`, `who_is_eating_sheet`) carry no NEW rendering risk from a value-preserving token swap — the risk is "did the light value change," which the source-pin test covers globally. Heavy view tests skipped per ui-conventions.

## 2026-06-30 — BUT-1446 inline-link a11y in LinkifiedText + MarkdownBody (sibling of BUT-1426) [Pattern + Helper added]

**Trigger:** same recognizer→`WidgetSpan(Semantics(link:)+GestureDetector)` migration as BUT-1426, but in two OTHER widgets: `lib/widgets/common/linkified_text.dart` (URLs in user text → link, visible text = the URL, a11y label = `context.l10n.a11yLinkTo(url)`) and `lib/views/legal/markdown_body.dart` (`[label](url)` → link, visible text = label, a11y label = the label). Recognizer + `_recognizers`/dispose bookkeeping deleted. Broke 3 tests in `linkified_text_test.dart` + 1 in `markdown_body_test.dart`.

- **`linkified_text` failures were ROOT-CAUSED by the missing l10n delegate, not the structure.** The new WidgetSpan calls `context.l10n.a11yLinkTo(url)` at build time; the old tests used a bare `MaterialApp` with no `AppLocalizations.delegate`, so build threw before any assertion. Fix = pump through `createLocalizedTestApp(child: ...)`. Lesson: when a widget gains a `context.l10n` call inside a span, every test that pumps it must switch to the localized test app — a `findsNothing`/`Found 0` failure can be a build crash upstream, check the exception, don't just adjust the finder. `markdown_body` did NOT need this — its a11y label is the visible link text (`t.text`), no l10n call, so its plain `MaterialApp` pump stayed.
- **`find.textContaining('https://a.com')` → use `find.text('https://a.com')`.** Post-BUT-1446 the URL/label renders as its OWN `Text` inside the WidgetSpan, so the exact-match `find.text` works and is tighter. The old `textContaining` was matching the assembled `Text.rich` string; that single combined string no longer exists (URL chunk is split into a child Text), which is why those three assertions went red. Keep the intent (URL visible) but locate via the rendered child Text.
- **Text.rich MERGES all its spans (incl. the link WidgetSpan's Semantics) into ONE semantics node.** Dumped the tree: the paragraph node's label is the whole sentence concatenated (`"Read \nLänk till https://butlery.se/policy\nhttps://butlery.se/policy\n please."`) and that single node carries `isLink=true` (OR'd up from the link child). Consequences for the a11y assertion:
  1. **`bySemanticsLabel` must be a `RegExp` substring, not exact** — `RegExp(r'Länk till https://...')`, then assert `node.label` *contains* the accessible name. An anchored `^...$` exact match finds 0.
  2. **Assert `node.flagsCollection.isLink`, NOT `hasFlag(SemanticsFlag.isLink)`** — `hasFlag` is deprecated after Flutter 3.32 (analyzer `deprecated_member_use`). `flagsCollection.isLink` is the current API and avoids importing `dart:ui`/`flutter/semantics.dart`. (This supersedes any earlier note that used `hasFlag`.)
- **Helper added — url_launcher platform mock for "tapped link opens URL".** The recognizer is gone, so interactivity must be proven by `tester.tap(find.text(url-or-label))` + asserting `launchUrl` fired. There was NO existing url_launcher mock in `test/widget`. Pattern that works:
  ```dart
  class _RecordingUrlLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
    final launched = <String>[];
    @override LinkDelegate? get linkDelegate => null;        // the ONE other abstract member
    @override Future<bool> launchUrl(String url, LaunchOptions o) async { launched.add(url); return true; }
  }
  // setUp: save UrlLauncherPlatform.instance, set ours; tearDown: restore.
  ```
  `UrlLauncherPlatform` is `extends` (default impls), so you only override `launchUrl` + `linkDelegate`. `MockPlatformInterfaceMixin` bypasses the `PlatformInterface.verify` token check. `LinkDelegate` is NOT exported from the main library — import `package:url_launcher_platform_interface/link.dart`. **Added `url_launcher_platform_interface: ^2.3.2` to dev_dependencies** (next to `plugin_platform_interface`) to satisfy `depend_on_referenced_packages` — it's transitive otherwise. Do NOT mock url_launcher via MethodChannel for this; the platform-instance swap is cleaner and what these two files now use.
- **No production bug found** — all 4 failures were pure structural-assertion mismatch from the recognizer→WidgetSpan move. Final: linkified_text 7/7, markdown_body 4/4, both analyze-clean.

## 2026-06-30 — BUT-1442 `failed`-flag search path (UserService + FriendsSearchManager) [Pattern]

**Trigger:** a `failed` flag now propagates up parallel `*Result` methods so a search-backend OUTAGE surfaces as a degraded notice instead of "no users found". Old `List`-returning methods (`searchProfiles`/`searchUsers`) now DELEGATE to the new `*Result` ones. One existing UserService test broke + new behaviour needed coverage. No production bug found — clean delegation.

- **The break was a re-routed stub, not a logic change.** `user_service_test.dart` "should search users successfully" stubbed `mockUserRepository.searchProfiles('Doe')`, but `searchUsers` now calls `searchProfilesResult` under the hood. Fix = stub `searchProfilesResult` returning a `SearchResult<UserProfile>(hits:[...], totalHits:.., page:0, totalPages:1, processingTimeMs:0)` and `verify` the `*Result` method. **Lesson: when a `List`-returning method is refactored to delegate to a `Result`-returning one, every stub/verify on the OLD method silently mis-targets — grep the test for the old method name and re-point it.** The "handle search errors gracefully" test still validly hit the catch path (throw → `SearchResult.failure()` → `.hits==[]`) but I switched its stub to `searchProfilesResult` too (it was stubbing a method no longer on the call path, so it was a no-op stub passing by luck).
- **`SearchResult.failure()` is a const named ctor (`failed==true`, empty hits).** Use `const SearchResult<UserProfile>.failure()` for the outage case; the full ctor with `failed` defaulting false for the legitimate-zero-match case. The behavioural invariant worth pinning is the PAIR: `failed==true` outage (empty + degraded) vs `failed==false` zero-match (empty + neutral). Same empty `hits`, different `failed` — a test that only checks `hits.isEmpty` would pass for both and prove nothing. Always assert `failed` alongside emptiness.
- **`AppLocale.current` needs NO init in unit tests** — `lib/core/l10n/app_locale.dart` defaults `_current = AppLocalizationsSv()`. So a ViewModel/manager that reads `AppLocale.current.socialSearchUnavailable` off the BuildContext-free global resolves to the Swedish string with zero setup. Assert against `AppLocale.current.socialSearchUnavailable` (don't hardcode the Swedish text) so a copy tweak doesn't break the test.
- **Cache-poisoning is a real behavioural contract — test it as a PAIR.** `FriendsSearchManager._performSearch` must NOT cache a `failed` result (else a transient outage poisons that query until eviction). Proved it with two mirrored tests: (1) stub failure → search → re-stub success → search SAME query → assert it re-queried (`verify(...).called(2)`) and recovered; (2) stub success → search → re-search same query → assert it served cache (`verify(...).called(1)`). The success-caches test is what makes the failure-doesn't-cache test meaningful (without it, `called(2)` could just mean "never caches anything").
- **Re-searching the IDENTICAL query needs a `clearSearch()` first.** `updateSearch(q)` trims + stores `_searchQuery`; calling it twice with the same string still re-runs the debounced `_performSearch` (no same-query guard in this manager — unlike `SharedContentSearchViewModel` which has a no-op-on-unchanged guard). But to be robust against any future guard, I reset via `clearSearch()` between the two searches so the second `updateSearch('anna')` is unambiguously seen as a change.
- **Mock wiring:** `MockUnifiedFriendsService.setFriendsState(management: mockManagement)` makes `.management` return the configured `MockFriendsManagementOperations`. That mock `extends Mock` with concrete `@override` bodies for most methods BUT has **no `searchUsersResult` body** (the method is newer than the mock), so `when(() => mockManagement.searchUsersResult(q))` works (the anti-pattern only blocks `when()` on methods that HAVE a concrete body). Did NOT add a body — stubbing per-test is what the degraded/empty/success branches need.
- **Compile-timeout gotcha (not a real failure):** running `user_service_test.dart` + `friends_search_manager_test.dart` in ONE `flutter test` invocation hit the 12-min per-test LOAD timeout during the shared `lib/` compile (the friends test showed `loading ... [E] TimeoutException after 0:12:00`). Each file passes fine when run ALONE (compile fits the window). Lesson: a `TimeoutException ... during "loading"` with `+0` tests run = compile-bound, not a hung test — split the invocation per-file to confirm, don't go hunting for a deadlock. (Consistent with `reference_ci_unit_compile_floor.md`.)
- **Final:** user_service_test 32/32, friends_search_manager_test 5/5, both analyze-clean (`--fatal-infos`). Only test files touched; no pubspec change needed (`fake_async` already a dep).

## 2026-06-30 — BUT-1396/1400 GDPR export + ToS record [Pattern + decision-tree correction]

**Trigger:** added export-section + Terms-acceptance tests; one finding contradicts the FakeFirebaseFirestore-vs-emulator decision tree above.

- **CORRECTION to the decision tree: `collectionGroup` queries WORK in `fake_cloud_firestore ^4.1.0+1` — no emulator lane needed for plain collectionGroup reads.** The table at the top of this file says "collectionGroup → Emulator"; that's stale for the version we ship. Probed it directly: seed `pings/{groupId}/pings/{pingId}` then `firestore.collectionGroup('pings').where('fromUserId', isEqualTo: uid).get()` returns the nested doc (count==1). So `exportPingsSent` (a collectionGroup+equality query) is testable end-to-end with `FakeFirebaseFirestore` — the BUT-1396 task pre-authorised a degraded "presence-only" fallback, but it was unnecessary; I wrote the real `total==1` assertion. Emulator is still required for `FieldValue.increment`/`serverTimestamp`-sentinel/transactional/security-rules behaviour — only the *collectionGroup* row of the tree was wrong.
- **GDPR export sections: assert the THREE-part contract per new section, not just presence.** (1) seeded → `total`/`total_count == 1` AND the genuine PII field round-trips verbatim (e.g. `reports[].data.description`, the free-text — `reason` is just an enum); (2) ownership negative → a doc owned by a DIFFERENT uid is NOT in the bundle (proves the `where(reporterId==uid)` filter, would catch a "fetch all" regression); (3) empty-safe → a user with none of the data still gets the key present with `total==0` and **no `error` key**. The `containsKey('error') isFalse` check is the load-bearing one: each export manager wraps its body in `try/catch → return {'error': e}`, so an ownership-guard or repo regression silently degrades the section to an error payload that the "is the section present?" test would still pass. Mirrors the existing BUT-501/BUT-1235 patterns in `data_export_service_test.dart`.
- **`recordTermsAcceptance` (merge-write + serverTimestamp + validateSelfOperation) — test all three behaviours.** (a) writes `termsVersion` literal + non-null `termsAcceptedAt` (assert `isA<Timestamp>()` — the repo is built with `TestTimestampProvider` so the sentinel lands as a concrete `Timestamp`, not the fake-throwing `FieldValue.serverTimestamp()`); (b) **merge** preserves a pre-existing field on `users/{uid}` (a regression to non-merge `set()` would erase profile data — pin it); (c) calling it for a uid ≠ authenticated user throws `PermissionDeniedException` (from `validateSelfOperation` in `permission_validation_mixin.dart`) AND the foreign doc is NOT created. Assert the version against `UserService.currentTermsVersion` with a paired `expect(UserService.currentTermsVersion, '1.0')` so a deliberate version bump is a visible one-line edit, not a silent green.
- **Final:** data_export_service_test +5 BUT-1396 tests (reports round-trip, reports ownership-negative, realtime_recipes, pings collectionGroup, empty-safe-all-four) + 4 keys added to the "all required sections" list; firebase_user_repository_test +3 BUT-1400 tests. Both files analyze-clean (`--fatal-infos`), full run 68/68 passing (8 pre-existing emulator skips). No production bug found — clean wiring. Only test files touched.

## 2026-06-30 — BUT-1450 notification-analytics in GDPR export [Pattern: union/de-dup + counterparty-included]

**Trigger:** added 8 tests to `data_export_service_test.dart` for four new export sections (notification_history / _batches / _engagement / _delivery), built on the existing BUT-1396 three-part contract template. All 32/32 pass, analyze-clean. No production bug found — clean wiring.

- **`orderBy('sentAt', descending: true)` is testable end-to-end on `fake_cloud_firestore` — but the seeded doc MUST carry the orderBy field.** notification_history's repo query orders by `sentAt`; fake firestore (like real Firestore) silently DROPS docs missing the orderBy field from the result set. So a seed without `sentAt` would make a legit `total_count==1` test fail with 0 and look like a query bug. Always include the orderBy field in the fixture. (Confirms the decision-tree: plain orderBy on a present field needs no emulator lane.)
- **Two-query union + de-dup section needs FOUR distinct fixtures to fully pin it, each a different row of the truth table:** (1) sent-only (`senderId==uid`, target=other) → proves the sent leg; (2) received-only (`targetUserId==uid`, sender=other) → proves the received leg AND hosts the counterparty assertion; (3) self (`senderId==targetUserId==uid`) → both legs match the SAME doc, so `sent_count==1 && received_count==1 && total_count==1` proves the de-dup-by-id is real (a naive `[...sent, ...received]` concat without the `byId` map would give total_count==2 here — this is THE test that catches a dropped de-dup); (4) foreign (neither side==uid) → ownership-negative. `sent_count`/`received_count` are the pre-dedup leg sizes; `total_count` is the post-dedup merged length — asserting all three together is what distinguishes "deduped correctly" from "one leg returned nothing."
- **Counterparty-INCLUDED is a decided deviation — write the test that PROVES inclusion, never redaction.** On the received row (user is target), the test asserts `data['senderId'] == 'other-uid'` (the real foreign UID), explicitly NOT `'[anonymised]'`. This pins the Art. 15(4) include-the-counterparty decision in `.claude/rules/accepted-deviations.md`. A future reviewer's instinct ("a foreign UID leaking into an export looks like a privacy bug") is wrong here — the friendly record lives in notification_history joined via notificationId, and the delivery row's counterparty is the user's own data. The reason-string on the expect documents this so the test isn't mistaken for a redaction gap.
- **Reused the BUT-1396 three-part contract verbatim** (seeded→total+PII-roundtrip / ownership-negative / empty-safe-no-error). The `containsKey('error') isFalse` guard stays the load-bearing one — each manager method is try/catch→`{'error':e}`, so a repo/limit-helper regression degrades silently to an error payload a presence-only test would pass.

### 2026-07-01 — BUT-1419 client comment-maturity gate (SocialCommentsManager.postComment)
- **Trigger:** authoring a unit test for a new client-side fail-closed guard mirroring the server `isAccountMatured()` Firestore rule; the manager now blocks `postComment` for a fresh (<60 min) unverified account before hitting the backend.
- **`MockUnifiedRecipeService.social` is a Fake, NOT verifiable — do NOT use it for `verifyNever(addComment)` tests.** `production_mocks.dart` line ~1054 hard-wires `MockUnifiedRecipeService.social` to a `FakeSocialRecipeOperations` (a `Fake` with concrete bodies): `addComment` always returns a non-null id and cannot be stubbed or verified via mocktail. For any test whose load-bearing assertion is "backend NOT called" or "returned id was null", mock the interfaces directly: `class _MockRecipeService extends Mock implements UnifiedRecipeService` + `class _MockSocialOps extends Mock implements SocialRecipeOperations`, then `when(() => recipeService.social).thenReturn(social)`. This is the Mock-vs-Fake decision tree in practice — reach for the Fake only when you pass it around, never when you need `verify`.
- **The `account_maturity_cta_test.dart` harness is the canonical template for every maturity-gate test.** Reuse its `_fixedHelper(bool)` (constructs a real `AccountMaturityHelper` with a fixed `now` so a 2026-01-01T00:00 `joinedAt` is either 30 min old = not matured, or 2h old = matured) and its `_MockUser`/`_MockAuthRepository` pattern (`when(() => repo.currentUser).thenReturn(user_or_null)`). Do not mock `AccountMaturityHelper` itself — inject a real one with a controlled clock; that also exercises the age-vs-window arithmetic for free.
- **Domain invariant the LLM-autopilot happy path misses: maturity opens on AGE alone, not just email.** The obvious two tests (immature-blocked, email-verified-passes) both leave the age branch untested. Added a third: `emailVerified == null` (no firebase user) + `joinedAt` >60 min ago must still post. This is the branch the server rule's `||` covers and where a client/server drift would hide.
- **Assert the l10n message against `AppLocalizationsSv().newAccountSocialBlockedComment`, never the hardcoded Swedish literal.** `AppLocale.current` defaults to `AppLocalizationsSv()` with zero test setup, so the manager's error string is the real Swedish copy. Capturing it from the l10n source of truth (same principle as capturing theme colours from `ColorScheme`) keeps the test green through a copy tweak while still proving the RIGHT message was chosen.
- **Mutation-verified the guard.** Temporarily `if (false && !isAccountMatured)` in production → the blocked test failed on `verifyNever(addComment)` with "Unexpected calls: ...addComment" (NOT on the error-string expect), and the two matured tests stayed green. Confirms it fails closed on the backend-touch contract, not merely on state. Restored; no residue.

### 2026-07-01 — BUT-674: analytics minimization for minors (verifyNever as the load-bearing assertion)
**Trigger:** testing a privacy-minimization gate where a signal must be *suppressed* for a subclass of users (minors), not for everyone.
- The right assertion for "must NOT emit" is `verifyNever(() => mock.setUserProperty(name: X, value: any(named: 'value')))` — pin the *name*, wildcard the *value*, so it catches an emit at any stage value (`churned`, `active`, etc.). A value-specific verify would miss a leak of a different stage.
- Pair it with a positive control in the SAME test (language still emitted) so a blanket "analytics off" regression can't sneak past as a green minimization test, PLUS a sibling adult-path test proving the suppression is class-specific, not a removal.
- Gate lives inside `emitLifecycle` (covers both session-start and the cook-event re-emit path) → test `emitLifecycle` directly too, not only via `emitAtSessionStart`.
- Mutation-checked by deleting the `if (profile?.isMinor == true) return ...` line: both minor tests went red, adult test stayed green — the `verifyNever` genuinely guards. File: `test/unit/services/analytics/user_property_bootstrap_test.dart`; prod `lib/services/analytics/user_property_bootstrap.dart`.
- Harness note: `_MockAnalyticsService extends Mock implements AnalyticsService` (no method bodies) works cleanly with `when(...).thenAnswer`. Minimal `UserProfile` needs only uid/displayName/email/joinedAt/lastActiveAt + `isMinor`.

### 2026-07-01 — FirebaseUserRepository.fetchProfile settings-doc merge for isMinor (BUT-674)
Trigger: pinning that `fetchProfile` surfaces `isMinor` from the private settings sub-doc.
- `isMinor` is CF-written and server-authoritative; it lives on the private docs (root `users/{uid}` for rules + `users/{uid}/settings/preferences`), deliberately NOT the world-readable `public_profiles` doc. Same shape as the `hasSeenActivityFeedHint` (BUT-1220) merge: `fetchProfile` must merge it back or the client reads the default `false` forever and the analytics minimization for minors is inert.
- Test pattern is a copy of the BUT-1220 pair in `test/unit/repositories/firebase_user_repository_test.dart`: seed public doc via `_seedUserProfile(...)`, then `set({'isMinor': true})` directly onto the `settings/preferences` sub-doc (bypasses the merge:true write path the fake doesn't persist), call `fetchProfile`, assert `profile.isMinor == true`. Companion default test sets a settings doc WITHOUT isMinor → asserts `false`.
- **Subtlety worth noting:** `_createUserProfile(...).toFirestore()` writes `isMinor:false` into the public seed, and `UserProfile.fromMap` also reads `isMinor` from the public doc. So a `true` result can ONLY originate from the settings merge — this is what makes the hydration test a genuine guard on the merge line (not on `fromMap`).
- Mutation-checked: deleting `isMinor: s['isMinor'] as bool? ?? false` in `fetchProfile`'s settings copyWith turns the hydration test red (`Expected true, Actual false`) while the default test stays green. `dart analyze` clean on both files.
- Analytics re-confirm: `test/unit/services/analytics/user_property_bootstrap_test.dart` still 6/6 green (minor-suppression coverage intact).

### 2026-07-01 — BUT-1320/1321 weekly-menu personalisation scoring: strong pure-math coverage, wiring + one direction under-pinned
Trigger: reviewing `test/unit/services/menu/menu_personalization_test.dart` (14 tests) against the new `MenuScoringContext` (pantry/cuisine/skill multipliers) in `lib/services/menu/menu_scoring.dart`.
- **The pure-function design is a testing win worth copying.** Personalisation was extracted as `MenuScoringContext.multiplierFor(recipe)` — a pure `(recipe, context) → double`, `empty` = identity 1.0. This let every nudge be unit-tested in isolation *and* let the parity test pin `debugRecipeWeight(r, seasonTag:'no_season')` to an exact `90.0` baseline (never-cooked, unrated). Prefer this over burying the boost inside the weight loop where you can only assert it end-to-end.
- **Diversity-floor via seeded RNG is the right shape for "boosts don't collapse variety".** `MenuService(random: Random(20260701))` + 20 generated weeks + `maxShare ≤ 0.6` is deterministic (non-flaky) and actually exercises weighted-without-replacement selection through the REAL `generateMenuFromParsedRequest`, not the math in isolation. Caveat logged below.
- **GAP (weak assertion, real): "beginner biases toward simpler" is only half-proven.** The headline test asserts `simple > complex` for a beginner — but that ordering is satisfied by the complex *penalty* (0.85×) alone; it would still pass if `beginnerSimpleBoost` were silently 1.0. The symmetric `beginnerComplex < baseline` IS pinned, but `beginnerSimple > baseline` is not. A refactor dropping the simple up-weight escapes the suite. Fix: add `expect(_weight(simple, beginner), greaterThan(_weight(simple)))`.
- **GAP (dead scaffolding): `MockMenuService.lastScoringContext` getter added but never read.** The capture hook for asserting `MenuGenerator._buildScoringContext → generateMenuFromPrompt` threading exists in the mock, but no test reads it — the plumbing (pantry/cuisine/skill actually reach the service) is untested. Either write the wiring assertion or the getter is rot.
- **GAP (fail-open path untested): `MenuGenerator._buildScoringContext`.** New try/catch degrades to an empty context on missing `PantryService` (tryGet null), pantry read throw, or null profile — the exact "a failing/absent pantry never blocks generation" posture the BUT-1279 entry says to pin. No test registers a throwing PantryService and asserts generation still completes. This is the highest-value missing test.
- **GAP (minor, but it IS the binding condition): zero-match parity only covers the `null` branch.** Production guard is `overlap == null || overlap <= 0`. Test covers recipe-absent-from-map (null); a recipe *present* with `0.0` is not asserted equal to baseline. One line: `pantryMatchByRecipeId: {'r': 0.0}` → `equals(_weight(r))`.
- **Observation (not a defect): diversity `0.6` threshold validated against a single seed** (`20260701`), passing margin undocumented. Deterministic is good; but if it barely clears, a later gentle-boost tweak could flip red without the change being wrong. Consider a comment recording the observed `maxShare`, or loop 2–3 seeds.
- **Pre-existing, not this diff's sin:** `MockMenuService extends Mock` carries concrete `@override` bodies (hand-rolled fake). It works as a fake and the new field-capture is consistent with it; not worth churning here, but it's the `Mock`-with-bodies anti-pattern if it ever needs `when()`.
- Scale check done: `matchPercent = overlap / normalizedSet.length` is a [0,1] fraction, so the scoring's `clamp(0,1)` assumption is correct — no 0–100 vs 0–1 bug. Suite is 14/14 green; `debugMaxRatingBoost`/`maxSkillBoost` are `@visibleForTesting` so ceilings are asserted against the live constant, not a hardcoded 1.4.

### 2026-07-01 — BUT-1320/1321 follow-up: implemented the 4 gap-closing tests + 2 gotchas
Implemented the additions flagged in the review above. Files: `test/unit/services/menu/menu_personalization_test.dart` (now 15 tests) + NEW `test/unit/viewmodels/menu/menu_generator_personalization_test.dart` (4 tests). Both green, `flutter analyze` clean.
- **GOTCHA — CuisineConfig tag string ≠ enum identifier; a review claim was inverted.** A reviewer asked to swap the non-affinity test tag `'thailändsk'` → `'thailandsk'` (no ä), claiming the ä version was unknown. It's the opposite: the enum *member* is `thailandsk`, but `CuisineEntry.tag` (what `allTags`/`extractCuisineTag` actually compare) is the string `'thailändsk'` WITH ä. Swapping to `'thailandsk'` would make `extractCuisineTag` return null → exactly the coincidental-pass (unknown-tag → 1.0) the reviewer feared. Verified against source before acting (didn't blindly apply). Hardened instead: the affinity test now asserts `CuisineConfig.extractCuisineTag(other) == 'thailändsk'` so "not boosted" provably means non-favourite, not unrecognised. Lesson: when a relayed review claim contradicts the code, read the config source — `tag`/`key`/enum-name can diverge, and Swedish diacritics are a live footgun in tag strings.
- **PATTERN — testing an "absent ServiceLocator dependency" branch needs a real unregister; `TestServiceLocator` has none.** `MenuGenerator._buildScoringContext` resolves `PantryService` via `ServiceLocator.tryGet` (null → no pantry boost). To honestly test the null branch, remove any prior registration in `tearDown` with `GetIt.instance.unregister<PantryService>()` (guarded by `GetIt.instance.isRegistered<T>()`). `TestServiceLocator` exposes `registerSingleton` (unregisters-first) and `isRegistered`, but NO public `unregister` — and it shares `GetIt.instance` with the production `ServiceLocator`, so going through GetIt directly is correct and sufficient. Without this, a `registerSingleton` in an earlier test leaks a throwing/stub PantryService into the "no service registered" test and the null-branch coverage is a lie.
- **Direction-assertion lesson reused:** the beginner-skill test's `simple > complex` was satisfiable by the complex penalty alone; added `simple(beginner) > simple(baseline)` to pin the up-weight. Same shape as the analytics `verifyNever` + positive-control pairing — always assert the signal you claim to add, not just an ordering a sibling penalty could produce.
- **Diversity floor hardened to 3 fixed seeds** (was 1) + a comment recording the observed worst-case `maxShare ≈ 0.40` vs the `0.60` bar, so a later boost tweak that erodes variety fails instead of silently passing on a lucky seed.

### [2026-07-01] Trigger: reviewing seeded-RNG menu-balance tests (BUT-1324 protein diversity)
- **Verify a seeded probabilistic test ISN'T vacuous before trusting it.** MenuService's initial pick is weighted roulette (`_weightedSelect`), so a "double-violation gets rebalanced" test only proves anything if the *pre-balance* selection actually clustered. The public API hides that pre-balance state, so I replicated the exact roulette (same `Random(seed)`, weights = `daysSince` clamp 0..90, min 1; null lastCookedAt → 90; no season/rating/context multipliers when tags carry no season tag) in a throwaway `dart run` script. Confirmed `Random(20240701)` yields 3 traps in the combined-trap pick and 3 chicken in the four-same-protein pick — both genuinely exceed the cap, so the balance pass truly fires. Pattern: when a test's meaning depends on a hidden weighted draw, reproduce the draw offline rather than trusting the seed.
- **Weight math for MenuService replication:** weight = `min(daysSinceCooked, 90)` (null→90), floored at 1, ×1.5 if a tag equals the current season tag, ×ratingMultiplier (unrated→1.0), ×context (empty→1.0), ×recentUseDecay if recently used. For plain never-cooked-vs-N-days-ago pools with no season/rating tags, weights are just the day counts.
- **Observation (not a blocker) on the combined-pass order-independence test:** the fillers `a0..a4` are each a *distinct* cuisine AND *distinct* protein, so a naive sequential (cuisine-only-then-protein-only) pass would also satisfy both caps here — the test proves the OUTCOME contract but doesn't uniquely discriminate combined-vs-sequential. To make it discriminating, a future strengthening would add fillers that are diverse in one dimension but colliding in the other, so a greedy single-dimension pass leaves a residual cluster the combined pass resolves.
- **Drift-guard pattern for rule-map ↔ emitter coupling:** when a small hand-maintained map (`ProteinCategory._tagToCategory`) must cover every token another module emits (`Phase1NutritionCalculator.calculateProteinTags`), assert **set equality** between a test-maintained canonical list (copied from the emitter, with a comment pointing at file+intent) and the map's key set. Equality (not subset) also catches dead mappings. Enumerate the emitter's outputs by reading its source — driving it via real `IngredientLookupResult` fixtures is too brittle for a guard.
- **`ProteinCategory.categoryOf` first-tag-wins is Set-iteration-order dependent** — Dart set literals are LinkedHashSet (insertion order), so `{'nötkött','skaldjur'}`→beef and the reverse→shellfish. Pin both orderings so a loop refactor can't silently flip the tie-break.

### [2026-07-01] Trigger: reconciling BUT-1324 tests after /code-review fixed 2 production bugs
The two caveats I logged in the prior entry both became real fixes — the tests that encoded the old behaviour had to be inverted to match corrected production. Test-only diff, left uncommitted.
- **`ProteinCategory.categoryOf` is now PRECEDENCE-based, not first-tag-wins.** The `{'nötkött','skaldjur'}` reversed-order assertion I said "pins the tie-break" was pinning a BUG: because `TagResult` serialises tags alphabetically (M15, tag_result.dart:337), first-tag-wins bucketed a reloaded chicken+fish dish as fish. Fixed order: beef > pork > lamb > game > poultry > fish > shellfish > plant > egg. Updated both orderings of `{nötkött,skaldjur}` → **beef**; `{fläskkött,ägg}` → pork still holds (pork precedes egg). Added the regression test that would have caught the ship: `{'fisk','kyckling'}` (already alpha-sorted, 'fisk' first) must resolve **poultry**, not fish. Lesson reinforced: a tie-break test on a set that gets re-sorted on persistence is testing the wrong thing — assert the persistence-invariant outcome, not iteration order.
- **`_findBalancedReplacement` now decrements the OUTGOING recipe's categories before scanning (BUT-1457).** My earlier "double-violation test doesn't discriminate combined-vs-sequential" caveat → added a dedicated discriminating test: a 3-italiensk cluster resolvable only by a candidate that SHARES beef with the recipe being swapped out. Old code counted beef=2 (incl. the leaving recipe) and rejected the candidate → italiensk stuck at 3; fixed code frees the slot (beef→1) and swaps. The test asserts `cand` IN and `x_beef` OUT, so it fails against the old code specifically (not just an outcome check).
- **Making a sequential-vs-combined discriminator deterministic:** order filler weights via `cookedDaysAgo` so the *colliding* fillers are the heaviest non-trap recipes. A one-dimension (cuisine-then-protein) picker greedily grabs the three heaviest non-italiensk recipes — all beef — and self-inflicts a beef cluster; the combined `wouldCluster` check over all dims rejects the third beef and takes the lighter fish/egg fallback. Weight = clamped days-since-cooked, so heavier = smaller `cookedDaysAgo`.
- Final: 55 tests in `test/unit/services/menu_service_test.dart`, all green; `flutter analyze` clean.

### 2026-07-02 — BUT-1320 Settings "Meny och smak" + shared-control extraction review
Trigger: reviewed staged widget test `test/widget/views/settings/menu_taste_view_test.dart` (3 cases) for the new Settings menu-taste view + the extraction of `CookingPreferenceControls` out of `cooking_identity_section.dart`.
- **The original 3 were sound** (intro+controls render, skill-tap side-effect on the shared VM, hub-row route push) — side-effect verified against `vm.cookingSkillLevel`, not just a tap; route asserted via `onGenerateRoute` capture. No rot to delete.
- **Two real gaps found and filled (test-only, +2 → 5 cases):**
  1. **Save-button gating untested.** `MenuTasteView`'s Save uses `hasUnsavedChanges && !isLoading ? _save : null`. Added a widget test asserting the `ElevatedButton.onPressed` is `null` on fresh load and non-`null` after a skill tap. `ActionButtons.primaryButton` → `actionButton` renders an `ElevatedButton` with `onPressed: effectiveOnPressed`; find it via `find.widgetWithText(ElevatedButton, sv.commonSave)` and read `tester.widget<ElevatedButton>(...).onPressed` for enabled/disabled. This is the user-visible half; the VM `hasUnsavedChanges` invariant itself is already covered in `user_profile_viewmodel_test.dart`.
  2. **Refactor-regression on the profile-edit side.** Extraction pulled skill+cuisine OUT of `CookingIdentitySection` into shared `CookingPreferenceControls`; the shared widget is exercised by the Settings tests, but `CookingIdentitySection` (which still hosts the profile-only bio field) had ZERO widget coverage — a dropped bio field or unwired control would stay green. Added a test pumping `CookingIdentitySection` directly: asserts skill selector + a cuisine chip + `StyledInput` (bio) all render, and that a chip tap reaches `vm.cuisineAffinities` (control still wired to the same VM at the profile entry point). Fails specifically if the extraction dropped a control or the bio.
- **Pattern:** when a refactor extracts a shared widget consumed by TWO hosts, a test on the NEW host proves the widget works but does NOT prove the OLD host still embeds it + keeps its host-only siblings. Add a cheap render+one-side-effect test on the old host.
- 5/5 green; `flutter analyze` clean on the file.

### 2026-07-02 — BUT-684 handwritten-toggle client tests review
Trigger: reviewed staged client tests for the photo-import "handwritten recipe" toggle threading `isHandwritten` through model→service→VM→widget.
- **The 5 layered tests genuinely prove the wire, not topology.** Verified each: (1) `llm_service_ocr_handwritten_test.dart` uses a capturing fake `FirebaseFunctions`/`HttpsCallable` and asserts the flag lands in the actual callable **data map** (`payload['isHandwritten']` true/default-false) — not a getter check; (2) `llm_models_test.dart` pins `OcrRecipeImageRequest.toJson()['isHandwritten']` for fromBytes/fromUrl + default; (3) `llm_enhancement_service_test.dart` fake records `lastOcrIsHandwritten` proving `extractFromImage` forwards it; (4) VM test captures `autoImport('photo', options:)` and asserts `options['isHandwritten']==true` AND the recipe surfaces (parsedRecipe.title + ocrText contains title — exercises real `_extractHandwritten`/`_recipeToReviewText`, not vacuous); (5) widget test uses a real-field fake VM so a tap on `SwitchListTile` actually mutates `isHandwritten`, asserts default-OFF.
- **GAP found + filled (OFF-path at VM options layer).** Test #4 only checked the TRUE case; `extractHandwrittenForTesting` always calls `_extractHandwritten` regardless of the flag, so a hardcoded `'isHandwritten': true` in the options map would escape. Added a mirror test: flag left default-false → `options['isHandwritten']==false`. Test-only, +1 (VM file now 36 tests).
- **Accepted limitation (not filed):** the actual ON/OFF **dispatch** `if (_isHandwritten) _extractHandwritten else _ocrAndAppendPage` lives inside `_pickImageAndProcess`, which constructs `ImagePicker()` inline (platform channel) — unreachable in unit tests, which is exactly why `TestablePhotoImportViewModel` stubs the pickers and why a `@visibleForTesting extractHandwrittenForTesting` seam exists. The dispatch is a trivial one-liner; the OFF-path is instead pinned at the payload/wire layer (model+service+enhancement all assert default-false) plus the new VM options-false test. Don't demand a platform-channel mock for a one-line branch.
- **Fake-getter hygiene done right in the diff:** `MockPhotoImportViewModel` (production_mocks) + 2 sibling widget fakes add a concrete `bool get isHandwritten => false` override — correct here because it's a *non-nullable* getter a Mock would otherwise return null for via noSuchMethod and crash the view. This is the allowed exception to "no concrete bodies on Mock" (a non-nullable getter with no `when()` need), not the anti-pattern.
- Full suite (llm dir + VM + widget) 159 green after the add; `flutter analyze` clean on all touched test files.

### 2026-07-02 — BUT-1360 item 2: offline pending-sync hint across 3 write paths [Review + one strengthening]
**Trigger:** review the staged `test/widget/views/recipe_detail/offline_pending_sync_test.dart` (11 cases) for `SnackBarUtils.showPendingSyncIfOffline` and its wiring into mark-as-cooked, rating (success + swallowed-error catch), and comment-post success branches.
- **Verdict: keep. All three intent gates pass; assertions target the shown `find.text(l10n.xxx)`, never SnackBar topology.** Each path drives its REAL handler/widget over a mocked `OfflineService` only (comment: real `RecipeSocialHandler.postComment` + mocked `SocialRecipeViewModel.postComment`; rating: real `RecipeDetailMetadata` + `RecipeDetailViewModel`, mock `UnifiedRecipeService.updateRecipe`; cook: real `RecipeManagementHandler.markAsCooked` + real VM). The snackbar-decision logic under test is never stubbed.
- **Non-vacuity proven empirically, not just argued:** flipped the cook wiring `if (!showPendingSyncIfOffline(context))` → `if (true)` and the offline mark-as-cooked case went red while online stayed green (then `git checkout -- <file>` to restore the staged content). Template for proving a "replace-success-with-hint" test isn't vacuous: break the guard, offline must fail, online must not.
- **Online-path-unchanged assertion present for all 3 paths** (the gate the task flagged): comment-online asserts `socialCommentPosted` shows + `pendingSyncOffline` findsNothing; cook-online asserts `recipeMarkedAsCooked` + no hint; rating has BOTH online-success (silent: no hint, no error) and online-error (`ratingError` shows, no hint) — the online-error case also doubles as the proof that `updateRecipe→false` genuinely throws into the catch (so the offline-swallowed-error case is exercising the catch branch, not the success branch).
- **The rating success branch was previously SILENT** (no success snackbar) — the offline hint replaces nothing visible, so its non-vacuity rests on `pendingSyncOffline` findsOneWidget alone. Added the missing symmetric negative to the offline-success case: `expect(find.text(l10n.ratingError), findsNothing)` — matches the task's per-path contract ("offline → hint shows and normal success/ratingError does NOT") and was the only offline case lacking the negative. 11 cases stay 11 (strengthened, not added).
- **Helper unit trio is complete:** offline→hint+true, online→false+no-hint, and unregistered-`OfflineService`→false+no-hint (proves the `ServiceLocator.tryGet<OfflineService>() != null` guard — a plain `.get` would throw). The unregistered case relies on per-test `TestServiceLocator.reset()` so no prior `registerOffline` leaks.

### 2026-07-02 — BUT-520 FriendsViewModel→BaseViewModel: error-shadowing was the one uncovered migration risk [Pattern]
Reviewed the staged `ChangeNotifier + StateNotifierMixin/AsyncOperationMixin → BaseViewModel` migration (behaviour-preserving, public surface identical). The existing 48 tests genuinely cover loading-state surfacing (`should combine loading states` + default-state), service error surfacing (`should combine error states`: `_friendsService.error`→`error`), and dispose/post-dispose (`throwsFlutterError` on double-dispose + post-disposal no-op). Coalescing `notifyListeners` correctly has NO test (VM schedules via `addPostFrameCallback` → flaky; see 2026-06-21 entry). **The single real gap:** `createGroup`'s failure test asserted only the throw + `isCreatingGroup==false`, never that the **specific** group error surfaces. Post-migration `executeAsync` (now from BaseViewModel) writes `errorUnexpected` to `super._error` on catch; the `error` getter override `_friendsService.error ?? _groupCreationError ?? searchError ?? super.error` places `_groupCreationError` AHEAD of `super.error` so the specific message shadows the generic one. A dropped/reordered getter during migration would silently swap "Kunde inte skapa gruppen" for "Ett oväntat fel uppstod" — user-visible, untested. **Added one test** pinning `groupCreationError==errorCouldNotCreateGroup`, `error==errorCouldNotCreateGroup`, `error isNot errorUnexpected`, `hasError==true`. Locale/theme-proof: asserts against `AppLocale.current.*` getters, not raw strings. 48→49 green. When a VM overrides `error`/`hasError` to shadow the base, ALWAYS test the shadow explicitly on the path where base `executeAsync` writes its own error — the throw/return-value alone doesn't prove the getter precedence held.

### 2026-07-02 — BUT-520 RecipeDetailViewModel→BaseViewModel: error-suppression override was the migration risk [Review, no add]
Same migration family as the FriendsViewModel entry above, but the shadow is *unconditional*: this VM overrides `error`→`null` / `hasError`→`false` (not a service-error passthrough) because the detail screen deliberately has no error surface. Base `executeAsync` on catch calls `setError(errorUnexpected)` (writes `super._error`) then **rethrows** (base_viewmodel.dart 187-188), so a dropped override would leak the generic "Ett oväntat fel uppstod" onto the detail screen. The agent's added test (`error stays suppressed after a failed operation`) throws from `deleteRecipe`, catches the rethrow, asserts `error==null && hasError==false` — **non-vacuous**: removing the overrides flips it red (base `_error` is now non-null after the failed op). One path is enough since the override is a global getter, not per-op. Existing 33 already cover the other migration-touched surfaces: rethrow-on-failure (`should handle deletion failure` inits `result=true`, catches, asserts false), deletion loading (`should track deletion state` — VM keeps its own `_isDeleting`, untouched by migration), dispose guard (`returnsNormally` + double-dispose `throwsFlutterError`). Coverage sufficient, added nothing. 34 green, analyze clean.

### 2026-07-02 — BUT-520 UnifiedShoppingViewModel→BaseViewModel: new tests only covered the SAFE quadrant [Review, added 2]
Third VM in the migration family. Overrides `isLoading`/`error`/`hasError`/`clearError` as **unconditional passthroughs** to `_shoppingService` (never read `super`). The agent kept 61 tests + added a 2-test BUT-520 group. **The added tests were non-vacuous but covered the wrong quadrant.** Test 1 seeds a service error via `setShoppingState(error:)` while base `_error` is clean, asserts the specific message surfaces — catches override *removal* only in the "service-has-error / base-clean" quadrant. Test 2 ("no service error → no VM error") is **vacuous re: override removal** — base default `_error` is also null, so it passes with or without the override (harmless documentation, not load-bearing). **The migration risk the group's own comment describes — base `executeAsync` writing generic `errorUnexpected` to `super._error` then rethrowing — was NEVER exercised: no test drove a failed `executeAsync`, so `super._error` stayed null across all 63.** Also the task claimed the 61 covered "executeAsync rethrow at initialize/addItemsFromRecipe" — **false, zero `throwsA`/`thenThrow` in the file.** Added 2: (a) failed `initialize()` where the service ALSO reports its own specific error (mirrors production) → `expectLater(throwsA)` pins the rethrow + asserts `error==service message` AND `isNot(AppLocale.current.errorUnexpected)` — the FriendsViewModel gold pattern, kills the dropped-override leak in the base-populated quadrant; (b) `addItemsFromRecipe([{}])` (malformed data → cast throws inside `executeAsync`) → `throwsA(anything)` pins that method's rethrow contract so a future swap to `executeAsyncVoid` (silent `false`) is caught. 63→65 green, analyze clean. **Lesson (reinforces the Friends entry): for an unconditional error-shadow override, a test that only seeds the service error with base clean is NOT enough — you must drive the failed `executeAsync` so base writes its generic, else the exact leak the override guards is untested. `MockUnifiedShoppingService.error` reads `_error` (set by `setShoppingState`) independently of stubbed method throws, so you can make `initialize()` throw AND report a specific service error in the same test.**

### 2026-07-02 — Trigger: reviewing a ChangeNotifier→BaseViewModel migration (BUT-520)
BaseViewModel (`lib/viewmodels/base_viewmodel.dart`) overrides `notifyListeners` to be
disposal-guarded (`if (!_isDisposed) super.notifyListeners()`) and exposes `isDisposed`.
Migrating a VM off raw ChangeNotifier flips the teardown contract: raw ChangeNotifier
THROWS FlutterError on `notifyListeners()` after dispose; BaseViewModel safely no-ops.
So `throwsFlutterError` lifecycle tests MUST be rewritten, not deleted. The CORRECT
replacement still proves the teardown behaviour: register a listener, dispose, notify,
then assert (a) `returnsNormally`, (b) the listener was NOT invoked (`expect(notified,
isFalse)`), (c) `isDisposed == true`. The not-invoked assertion is load-bearing — without
it the test would still pass if listeners leaked, i.e. a weakening. Verified the BUT-520
recipe_form test did include it (sound, no strengthening needed).
Also: when a migrated VM delegates error state to a sub-state object (RecipeFormState),
it legitimately `@override`s BaseViewModel's `error`/`hasError` getters to surface the
domain-specific (Swedish) message instead of BaseViewModel's `_error`. Confirm the
error-surfacing tests still pass unchanged — that's the behaviour-preservation contract.

### 2026-07-02 — Seafood allergen safety-net + retag write-back review [Review + one gap]
Trigger: reviewing tests for the skaldjur 'seafood' trigger fix + cache retag write-back.
- **Seeded-artifact-as-fixture pattern (good, reusable):** `tag_phase1_seafood_safety_test.dart` builds `FirebaseTagConfig` from the actual `scripts/output/tagConfigs/*.json` production artifacts and runs the SAME behavioral assertions on both the static-fallback and firebase branches via a `for ((branch, config) in [...])` loop. This pins what's actually deployed, not just the Dart mirror — a config-drift class of bug (static fixed, JSON stale) fails the test. ⚠️ Prerequisite: the artifacts must be committed (they read via relative `File()`; missing files = loud load-time failure on CI).
- **Cross-port lockstep with pinned historical drift:** the TS `VALID_PROPERTIES` vs Dart `PropertyRegistry` test asserts `difference()` equals an exact known-drift set in BOTH directions, so old drift doesn't mask new drift. Same family as the 2026-06-28 PII-scrubber parity entry.
- **Directionality tests are the load-bearing ones here:** 'fisk stays FREE' (generic marker must not override specific-property win) and 'dairy stays vegetarisk FREE' (fix must not exclude animal-product wholesale) are the tests that distinguish the intended fix from a naive over-broad one.
- **Gap found (reported):** `ImportManager._checkCacheForUrl` write-back gating (`identical()` — write back ONLY on successful retag) had zero coverage. Seam exists without production changes: `ImportManager.withStrategies` + register MockGlobalRecipeCache/real UrlNormalizer/MockTaggingService in GetIt, drive via `autoImport(url)`. Vacuity trap: the cache path swallows exceptions and falls through to normal import, so any such test MUST pin `result.strategy == 'cache'` or a MissingStubError silently skips the code under test.

### 2026-07-02 — ChangeNotifier→BaseViewModel migration test posture (BUT-520, recipe_list_viewmodel)
Trigger: reviewing a behaviour-preserving migration where isLoading/error/hasError/clearError are `@override`s that delegate to a service.
- **Guarded-no-op regression test must be non-vacuous.** The BUT-1462 nuance is that post-dispose `notifyListeners()` on BaseViewModel is a silent no-op where raw ChangeNotifier would throw. A `expect(vm.notifyListeners, returnsNormally)` alone is vacuous — raw ChangeNotifier.dispose() already clears listeners, so "not invoked" would pass even without the guard; and `returnsNormally` doesn't prove the guard vs a lucky assert-off build. Correct test: addListener → dispose → `expect(vm.notifyListeners, returnsNormally)` AND `expect(notified, isFalse)`. Both halves needed.
- **`vm.notifyListeners` tearoff from a test does NOT trip `invalid_use_of_protected_member`.** BaseViewModel re-exposes notifyListeners as public (not @protected), so analyze stays clean. Fine to reference it directly in the test.
- **Delegation coverage is the real regression risk on this kind of migration**, not the dispose mechanics. Verify an existing test sets the service's state and asserts vm.isLoading/vm.error/vm.hasError reflect it, plus one that calls vm.clearError() and asserts the service cleared. If all overridden getters/methods are pinned this way, coverage is sufficient — don't add redundant delegation tests. (Here all four were covered in the 'State Accessors' + clearError tests; no additions needed.)

### 2026-07-02 — BUT-520 MenuViewModel→BaseViewModel: no-executeAsync VM → the simple delegation-only quadrant [Review, no add]
Fifth VM in the migration family. 13-line diff: dropped dead ErrorHandlingMixin, superclass ChangeNotifier→BaseViewModel, `@override` on `error`/`hasError`/`clearError` — all UNCONDITIONAL passthroughs to `_stateManager` (never read `super`). **Key distinction from the Friends/UnifiedShopping leak-quadrant entries: MenuViewModel uses NO base `executeAsync` anywhere.** Every one of its ~10 catch blocks routes manually through `_stateManager.setError(...)` / `_stateManager.handleOperationError(...)`; BaseViewModel's own `_error` is never written by any path. That collapses the risk surface to the recipe_list_viewmodel case (2026-07-02 entry): the ONLY migration break is a dropped override, and the empty-prompt validation path proves it non-vacuously because it populates `_stateManager.error` while leaving `super._error` null. Coverage confirmed sufficient, added nothing:
- error delegation → `should reject empty prompt` asserts `error == 'Ange vad du vill ha för meny'` (from `_stateManager.setError(errorEnterMenuDescription)`). Drop `@override error` → returns base null → RED. Non-vacuous.
- hasError delegation → `should clear error` asserts `hasError isTrue` on the same empty-prompt path (base `hasError` reads null super._error → false if override dropped) + `should handle generation error`.
- clearError delegation → `should clear error`: after `clearError()`, `error isNull && hasError isFalse`. Drop `@override clearError` → base clears already-null super._error, `_stateManager.error` still set → error non-null → RED. Non-vacuous.
- dispose/double-dispose → `should clean up resources on dispose` (returnsNormally) + `should throw on double dispose` (throwsFlutterError still holds: BaseViewModel guards post-dispose notify, NOT double-dispose, so ChangeNotifier's FlutterError survives).
23 pass / 7 pre-existing generateMenu-returns-empty failures (BUT-1463, verified via git stash on clean HEAD — NOT introduced by this migration, out of scope). **Rule reinforced: before reaching for the "drive a failed executeAsync to populate super._error" gold pattern, check whether the VM actually calls base executeAsync at all. If all error routing is manual into a sub-state object, super._error is dead and the empty-input/domain-validation path alone proves delegation — the leak quadrant doesn't exist.**

### 2026-07-02 — FIFO-multimap reuse tests: the vacuity checklist (ingredient sections chunk 1)
Trigger: reviewing `StructuredIngredientDeriver.deriveAll` FIFO Queue-multimap fix (duplicate raw lines under different headings must keep distinct reuse entries).
- **Three-part non-vacuity pattern for "distinct entries for duplicate keys" tests:** (1) assert with `same(...)` instance identity — value equality would pass a re-derived copy; (2) give the two reuse entries a distinguishing field beyond the one under test (a `note`) so const-canonicalization can't collapse them into one object; (3) mentally run the OLD code — a last-entry-wins map literal makes `entries[0]` the SECOND entry, so `same(first)` goes red under it. If any leg is missing the test can stay green through the regression.
- **A field added to `operator==`/`hashCode` makes every existing `fromJson(toJson()) == original` round-trip self-strengthening** — they now police the new field for free. Check equality membership FIRST when assessing round-trip coverage of a new field; if the field is excluded from `==`, the round-trips prove nothing about it and need explicit assertions.
- **Normalization call sites each need one blank-input pin.** `normalizeSection` had three entry points (fromJson, copyWithSection, fromParsed); only two were exercised with blank input — a refactor dropping the third (fromParsed) would let an LLM-emitted whitespace section create a phantom group with all tests green. One `expect(...section, isNull)` per boundary.

### 2026-07-02 — Ingredient-sections chunk 2 (RecipeOperations section preservation) [Review, clean; one untested crash-guard branch flagged]
Trigger: reviewing edit-operation tests for section survival (update keeps / append inherits / flat stays flat / reorder carries / updateAll survivors-keep+new-null).
- **Every test red-under-old-code:** pre-diff `updateIngredient`/`addIngredient` plain-derived (section null), so the 'Deg'/'Fyllning' assertions all flip red without the `copyWithSection` calls. The update test ALSO asserts `amount, 6` — guards the opposite failure mode (a naive "keep old entry untouched" implementation). Pair both directions when a fix is "re-derive BUT preserve one field".
- **Inheritance tests need the negative twin.** `addIngredient inherits last section` alone would pass an over-eager "inherit from any sectioned sibling" bug; the `flat recipe stays sectionless` twin kills it. Always pair inherit-positive with inherit-negative.
- **Pinning unchanged production code is legitimate when a sibling op changed:** `reorderIngredients` got no diff, but the carries-section test locks the contract against a future "re-derive on reorder" — cheap, behavioral, keep.
- **Guard-branch reachability check before dismissing an untested branch:** `addIngredient`'s `structured.isEmpty ? null : structured.last.section` guard is REACHABLE (facade `Recipe.structuredIngredients` returns `[]` when core list is non-null and `ingredients` is empty — e.g. a seeded-but-empty recipe getting its first line) and is the only thing preventing a `StateError` crash; it has zero coverage. When reviewing operations-layer edits, trace the facade getter to decide whether an empty/degenerate branch is a dead branch or an untested crash guard — don't assume either.
- Also confirmed the chunk-1 self-strengthening prediction: adding `section: 'Deg'` to the shared RecipeCore fixture made BOTH recipe-level round-trips (JSON + Firestore `fromMap`) police the field for free, because section is in `operator==`.

### 2026-07-03 — Ingredient-sections chunks 4-5 + copy-fixes [Review, clean; two kill-switch gaps flagged]
Trigger: reviewing section round-trip / section-aware dedup / sub-heading classifier / isolate round-trip / personal-copy-preserves-sections suites.
- **All seven target suites non-vacuous, 227 pass.** The CRITICAL safety test ('bare salt never dropped') is strict on BOTH legs: bare colon-less `salt` in an ingredient run must (a) survive classification into `ingredients` AND (b) not be eaten as a heading — the exact-list `expect(ingredients, ['2 dl grädde','salt','1 msk soja'])` goes RED if production swapped `_componentSubHeading`'s curated-vocab gate for `RecipeSectionDetector.isSectionHeader` (which treats any short word as a header). Confirmed the production comment names that exact anti-pattern it avoids.
- **`section` added to `RecipeIngredient` operator==/hashCode ⇒ every recipe-level round-trip self-polices it for free** (chunk-1 prediction holds again). The section-aware dedup 'merge keeps section' test is non-vacuous because the merge builder passes `section: existing.section`; drop that line and the `ExtractedIngredient` ctor defaults section→null → RED.
- **Default-true flag is IMPLICITLY guarded by the ON-path dedup tests:** `isSectionCaptureEnabled = tryGet<FeatureFlagService>() (null in unit tests) ?? true`, so 'stays two rows' etc. exercise the ON branch. If someone flipped the default to false, sections strip pre-dedup and smör-Deg+smör-Fyllning merge → 'stays two rows' RED. Nice, but this is NOT the same as testing the explicit OFF behavior.
- **GAP A (recommend closing now, cheap): llm_tier section-STRIP kill-switch (acceptance criterion 19) has zero coverage.** No test registers a FeatureFlagService returning false; `grep isSectionCaptureEnabled test/` → nothing. Criterion 19 is a documented contract (flag off ⇒ same-name rows merge exactly as pre-feature) and a kill switch that silently fails defeats its own purpose. One test: register a stub flag service (false), feed smör-in-Deg + smör-in-Fyllning, assert `parsed` merges to one summed row. Mirror of 'stays two rows'.
- **GAP B (larger, likely chunk 12): RuleBasedTier `_applySections` has NO coverage at all — ON or OFF.** There is no `rule_based_tier_test.dart`, and `test/golden/parsing_golden_dataset.json` has zero `section` fixtures, so the import-side stamping (positive stamp, the fail-open length-mismatch guard "a wrong section is worse than none", and the flag-OFF early return) is entirely unverified. The classifier's `ingredientSections` OUTPUT is tested; the wiring that stamps it onto `ParsedIngredient` is not. Golden fixtures (chunk 12) would cover the production-default ON path end-to-end but NOT the OFF path or the length-mismatch guard — those need explicit unit tests regardless, because goldens pin flag-ON output.
- **Registry note:** kill-switch flag-OFF paths are a recurring blind spot — the tryGet-fails-open pattern means unit tests never see the OFF branch unless a fake FeatureFlagService is explicitly registered. When reviewing any feature gated by `ServiceLocator.tryGet<FeatureFlagService>() ?? default`, assume the non-default branch is untested until proven otherwise.
### 2026-07-02 — BUT-1460 handwritten photo-import redesign: real-path verification (all 5 criteria non-vacuous)
Trigger: reviewed the redesign tests after 3 prior rounds shipped VACUOUS tests (most damaging: a rate-limit test that mocked `autoImport` to return the denial directly, so it passed while the real path still showed the English "No import strategy"/generic error).
Verdict: all 5 acceptance criteria genuinely proven; no gaps; no strengthening needed. 76 unit tests green, analyze clean.
- **The anti-vacuity design that works here:** the NEW `photo_import_handwritten_pipeline_test.dart` wires a REAL `ImportManager.withStrategies(mockPersonalOps, [PhotoImportStrategy()])` + REAL `ImportRateLimiter` (seeded to denial via `FakeFirebaseFirestore` at `users/{uid}/rate_limits/imports` with `importsThisMinute==importsPerMinute`) + a fake VISION LEAF (`_FakeLlmFailure extends Fake implements LlmEnhancementService`) registered in `GetIt.instance`. NOTHING in the `importSinglePhoto`/routing chain is mocked. Only the two true leaves (recipe-ops sink, LLM vision) are faked. This is the correct fake-the-leaf-not-the-subject shape the vacuous rounds violated.
- **GetIt/ServiceLocator bridge is load-bearing for the real limiter:** `ImportManager._rateLimiter` resolves `application_provider.ServiceLocator.get<ImportRateLimiter>()` → `DIContainer` wraps `GetIt.instance`. Test registers the seeded real limiter into `GetIt.instance` AFTER `ServiceLocator.initialize(DIContainer())`, overriding whatever DI registered. Same bridge lets `PhotoImportStrategy._llmService` pick up the fake vision leaf. Register-after-init order matters.
- **Clock discipline:** limiter uses `clock.now()`; test wraps the extract call in `withClock(Clock.fixed(t0), ...)` with `minuteWindowStart==t0` so `retryAfter` is a deterministic 60s → `RateLimitDenied(perMinute,60s).swedishMessage == l.rateLimitTooFast(60)`. Asserts equality to that AND `isNot(errorGeneric)` AND `isNot(contains('No import strategy'))`.
- **Empirical non-vacuity probe (the vacuous-round guard):** temporarily replaced `_extractHandwritten`'s `denied.swedishMessage` with `errorGeneric` → rate-limit pipeline test went RED (`Actual: 'Ett fel uppstod. Försök igen.'` vs expected `'Du importerar...'`); LLM-failure test stayed green (correctly — different branch). Reverted; production diff clean. Template: to prove a "surface the structured message" test isn't the old vacuous mock, break the VM's message-selection branch and confirm exactly the structured-message test flips.
- **Quality-gate skip criterion uses the REAL gate, mocks only downstream:** VM tests drive real `_assessAndRoute` → real `OCRExtractionService.instance.assessImageQuality` on 5-byte `testImageBytes` (< `UploadConstants.minOcrImageBytes` 50KB → `isRejected`). Handwritten pick → gate skipped → `importSinglePhoto` called once; sibling printed-OFF pick → same real gate rejects, `verifyNever` any importSinglePhoto. Mocking `mockImportManager` here is fine — the gate (the thing under test) is real, only the post-gate sink is stubbed.
- **importSinglePhoto unit (import_manager_test.dart) correctly separates concerns:** uses `_StubRateLimiter extends Fake` returning a fixed `RateLimitDenied` (interface-level fake, acceptable for the manager's branch unit) + `_FakeLlmFailure` leaf. Asserts `result.strategy=='rate_limited'`, `rateLimitDenied` non-null, message preserved `isNot(contains('No import strategy'))`, exactly one vision call. The REAL limiter-to-denial drive lives in the pipeline test, not duplicated here.

### 2026-07-02 — BUT-1464 household-allergen menu wiring review [Review + gaps found]
Trigger: coverage review of the uncommitted household-allergen diff (menu_generator/menu_service/menu_viewmodel/menu_content_widgets + MenuAllergenTrust).
- **Fixture `generatorVersion: kTagGeneratorVersion` additions are NOT assertion weakening — they are intent preservation.** Old TagResult fixtures omitted generatorVersion (null → `needsRetagging` true), so under the new stale-FREE→UNKNOWN downgrade every legacy FREE fixture would silently flip to UNKNOWN and the existing UNKNOWN-vs-FREE tests would test the wrong branch. Pinning fresh version keeps them on the trusted-tag branch; the stale branch is separately pinned (trust-matrix unit tests with version '1.0.0' + household tests driving stale FREE/CONTAINS through generateMenuFromPrompt). When a staleness guard lands, audit every TagResult fixture: version-less fixtures silently change meaning.
- **`lastGenerateRecipes` capture on the hand-rolled MockMenuService is the right public-seam assertion for pool filtering:** mock the selection service (dependency), run the REAL generator via `generateMenuFromPrompt`, assert the pool handed over contains no unsafe id. This fixed the 2026-07-01 audit complaint that tests exercised `getAvailableRecipesAsync` directly while production never called it.
- **Diagnosing "pre-existing failure" claims cheaply:** for the 7 menu_viewmodel failures (BUT-1463 class), the decisive checks were (a) failure signature `Expected true / Actual false` with NO MissingStubError naming any service the new code resolves (HouseholdService/AnalyticsService), and (b) the file's setUp stubs `allergenPreferences`, so the new pool path runs clean — plus the BUT-1317 allergen tests in the SAME file pass through the new path. Mechanism-level exoneration beats a second worktree compile.
- **Gaps reported (not fixed — review dispatch):** (1) `MenuService._recipeMatchesConstraints` trust-guard wiring for explicit "utan X" prompt constraints has zero coverage anywhere — no test uses non-empty `globalAllergenAvoid`/`globalDietaryRequire` through MenuService (grep confirmed; only the parser pins "utan gluten"→constraint). (2) UI half of the feature untested: no widget test renders the `menuHiddenByFamilyAllergies` hint (incl. the =1/other plural) or the `menuAllergenUnknownChip`; a11y tests only stub `isUnknownSoft→false`. (3) analytics positive-emit path unverified. (4) regenerate-section re-roll pool not pinned (shares getAvailableRecipesAsync with pinned paths — low).
- Observation: `unknownSoftRecipeIds` collected on the allergen pass can retain ids later removed by the dietary pass — harmless today (UI queries rendered recipes only), worth remembering if the set ever feeds counts.

### 2026-07-02 — BUT-1322 household-size portion-scaling review [Review + 4 gap areas filled, 12 tests added]
Trigger: coverage review of the uncommitted household-size diff (model + user_service sentinel + repo sub-doc persistence + cooking-mode/recipe-detail scaler defaulting + 2 analytics events).
- **Duplicated-logic trap: the SAME defaulting logic lived in TWO classes (CookingModeViewModel + RecipeDetailActions), each with its own `_resolveHouseholdDefault`.** The 5 cooking-mode tests covered only their copy; `RecipeDetailActions.initializeScaling` — the copy feeding the recipe-detail view AND add-to-shopping (`generateShoppingListFromRecipe(currentPortions:)`) — had ZERO tests (no test file existed for the class at all). When a diff wires the same behaviour into N surfaces, grep for every `_resolve*`/init copy and demand coverage per copy, not per behaviour. RecipeDetailActions is a plain non-widget class: unit-tested it directly with the cooking-mode harness shape (production `ServiceLocator.initialize(DIContainer())` + GetIt-registered `_MockUserService`/`_MockAnalyticsService`), no widget scaffolding needed. NEW `test/unit/views/recipe_detail/recipe_detail_actions_scaling_test.dart` (4 tests: pre-scale+event args, no-service identity, equal-size no-op + `verifyNever` no-bogus-event, manual-override once-per-open + unit-toggle-refire skip).
- **Settings-sub-doc field checklist (3rd instance of the BUT-1220/BUT-674 family — treat as a template):** any field persisted via `toPrivateSettings` needs (1) hydration test seeding `users/{uid}/settings/preferences` directly (public seed can't carry it since `toFirestore`/`toFirestoreEditable` exclude it — non-null proves the merge), (2) a corrupt-value test, (3) a `saveProfile` write-path test asserting settings-doc contains it + public doc does NOT (privacy leak guard) + fetch round-trip.
- **The corrupt-value test must assert a SIBLING merged field too.** `fetchProfile`'s settings merge is one `copyWith` inside one try/catch: a naive `as int?` parse of a corrupt `householdSize: 99` would throw in the range-checking constructor and the catch would silently drop the ENTIRE merge (allergen prefs, hint flag, isMinor). Asserting `householdSize == null` alone can't distinguish "parsed defensively" from "whole merge aborted" — pair it with `hasSeenActivityFeedHint == true` seeded in the same doc. That pairing is what pins `UserProfile.parseHouseholdSize` being used at the merge site.
- **Sentinel-parameter contract needs BOTH quadrants at the service layer:** `UserService.createOrUpdateProfile`'s `Object? householdSize = _unset` exists so omitting callers (social handler auto-creation) can't wipe the saved value while explicit null clears it. VM tests can never cover the omission quadrant (the VM always passes the field) — pinned in user_service_test via `captureAny()` on `saveProfile`: omit → preserved 4; pass 6 then explicit null → 6 then null.
- **Conditional analytics emit = changed-fires + unchanged-verifyNever pair, mutation-verified.** `logHouseholdSizeChanged` fires only when persisted value changed. Probe: flipped the guard to `if (true)` → exactly the unchanged-save `verifyNever` test went red (+2 -1); dropped repo merge-back to `null` → hydration + round-trip red, corrupt-test green (correct). Reverted by hand-editing (production diff was UNCOMMITTED — `git checkout` would nuke the feature; verified clean via `git diff | grep -c MUTATION` == 0).
- **`hasUnsavedChanges` equality-clause is load-bearing per field:** the `a.householdSize == b.householdSize` clause in `_profilesEqual` is the ONLY thing enabling Save after a household-only edit; widget tests asserted `vm.householdSize` mutation but never Save-enablement. One VM test pins it (out-of-range no-op + edit flips true).
- Pre-existing new tests verified non-vacuous by construction (model round-trip/sentinel/range; cooking-mode 5; menu-taste stepper 2 drive the REAL VM). Final: repo 48+8skip, user_service 34, profile-VM 54, actions 4 (new), model 71, cooking 36, menu-taste widget 7 — all green, 4 files analyze-clean --fatal-infos.

---

### [BUT-1322 review] Sentinel-vs-null wipe paths need argument-IDENTITY capture, not just "no side effect" — 2026-07-03
**Trigger:** Reviewing regression tests for the household-size wipe fix. The VM
suite already had a test proving an unedited save fires no `household_size_changed`
analytics — but that test would STAY GREEN if the VM regressed to passing
`edited.householdSize` (in-memory null) instead of `UserService.householdSizeUntouched`,
because `null == null` still suppresses the event while the wipe silently returns.
**Rule:** When a "leave-it-untouched" contract is carried by a *sentinel object*
(here `UserService.householdSizeUntouched = const Object()`), pin it by capturing the
forwarded argument and asserting `identical(captured, Sentinel)` — not by asserting a
downstream no-op. The three layers each need their own guard:
- Repo layer: `writeHouseholdSize:false` drops the key (`settings.remove('householdSize')`)
  so a merge-write with an explicit `null` value can't clear it. Non-vacuous because
  `toPrivateSettings()` always emits `householdSize` (even null), and FakeFirebaseFirestore
  stores merged nulls (does NOT treat null as delete) — so dropping `.remove` = fetch reads null = test fails.
- Service layer: omitted param → `_unset` sentinel → `writeHouseholdSize:false`. Test via `createOrUpdateProfile(displayName:...)` with the field omitted + captured saved profile.
- VM layer: `_householdSizeEdited ? edited.householdSize : householdSizeUntouched`. Test via `identical()` capture (added `user_profile_viewmodel_test.dart` → now 55 green).
**Also:** null-portions auto-scale guard (`recipe_detail_actions.dart` `declared != null && declared > 0`)
is pinned in `recipe_detail_actions_scaling_test.dart` — asserts currentPortions stays 1,
ingredients unchanged, `verifyNever` analytics. Non-vacuous: reverting the guard makes base=1,
household=6 → currentPortions 6 + amounts sextupled + a bogus `household_default` event.

---

## Discovered patterns

### 2026-07-03 — Ingredient-sections heuristic: fail-open tables + kill-switch (PR #211, chunk 6)
- **Trigger:** Reviewing `recipe_section_detector_test.dart` (NEW) + `schema_org_tier_test.dart` heading group for the `RecipeSectionDetector.componentSubHeadingLabel` safety hinge.
- **Pattern that works:** For a safety heuristic whose *false positive drops an allergen line from tagging*, the right test shape is (a) a small positive table proving it still fires on real headings (guards against over-failing), (b) a large fail-OPEN table of ambiguous/ingredient-like lines each asserting `null`, and (c) a dedicated allergen-safety invariant test iterating bare EU-14 allergen words → all `null`. Non-vacuity holds because the obvious wrong implementation (`isSectionHeader`, which greenlights any short single word) would flip `salt`/`socker` to non-null and fail the table.
- **Boundary to remember:** the fail-open guarantee is only for **colon-less / non-curated-vocab** lines. A lone allergen word *with a trailing colon* (`"Mjölk:"`, `"Salt:"`) IS returned as a heading by design (colon = strong signal). The allergen invariant table only covers colon-less words, so it does not — and cannot — assert null there. If a source ever emits `"Allergen:"` as its own `recipeIngredient` entry it would be pulled from tagging. Worth a documenting test pinning `"Mjölk:" → 'Mjölk'` so the tradeoff is visible, not silent.
- **Kill-switch test recipe (production `ServiceLocator`, not test locator):** `isSectionCaptureEnabled` reads `ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(FeatureFlags.ingredientSectionCapture) ?? true` — defaults ON when unregistered. To test flag-OFF: register a `Mock FeatureFlagService` in `GetIt.instance` returning `false`, then `ServiceLocator.initialize(DIContainer())`; tearDown unregisters + `ServiceLocator.reset()`. Default-on tests register nothing and rely on the `?? true` fallback. `_RecordingStrategy extends IngredientParsingStrategy` (real subclass overriding `parseLines` to capture `receivedLines`) is the clean way to assert "which lines did the tier hand to the parser" without CRF bundle loads.
- **Untested branches noted (low severity, not allergen-drops):** `_applySections` length-mismatch fail-open (strategy echoes 1:1, so the "parser merged/dropped lines ⇒ stamp nothing" guard never runs); trailing-heading-dropped branch. A mis-stamped section keeps the line present + tagged, so these are correctness-not-safety gaps.

### 2026-07-03 — Ingredient-sections display layer: IngredientDisplayRow.build + VM row caching (PR #211, chunks 7-8)
- **Trigger:** Reviewing `ingredient_display_row_test.dart` (NEW) + the `cooking_mode_viewmodel_test.dart` "ingredientRows (section grouping)" group for the sealed `IngredientDisplayRow` model and `CookingModeViewModel._rebuildIngredientRows` (ctor + `updatePortions`).
- **Verdict: both suites pass, non-vacuous, theme-free (pure model/VM — no widget/theme/padding asserts, no `@override` on the bodyless `Mock*` classes). No changes needed.**
- **Two load-bearing tests, non-vacuity confirmed by reasoning (not mutation):**
  - *length-mismatch-fails-open* (`build([a(Deg),b(Deg)], ['a'])` → exactly `[Line('a',0)]`): catches BOTH failure modes of a broken guard. Remove the `structured.length != displayLines.length` early-return and loop over `displayLines.length` → a spurious `Heading('Deg')` appears → assert fails. Loop over `structured.length` instead → `displayLines[1]` RangeError → test throws. And it proves the one display line survives (no drop). Solid.
  - *flat-list-indices* (`[a(Deg),b(Fyllning),c(Fyllning)]` → line indices `[0,1,2]`): pins substitution correctness. The plausible bug is indexing by position in the *output* rows list (headings would push indices to 1,3,4); test asserts 0,1,2. Catches it.
  - VM *rebuilds rescaled text on portion change (headings kept)*: `isNot('5 dl vetemjöl')` + `contains('vetemjöl')` + headings still `[Deg,Fyllning]`. Catches the stale-cache bug — if `updatePortions` skipped `_rebuildIngredientRows()`, `ingredientRows` would hold the original text and the `isNot` fails. The `isNot/contains` shape (not `equals('10 dl ...')`) is deliberately robust to scaler unit-normalization — good, not brittle.
- **Why the flat-recipe VM test hits the REAL null-section path, not the fail-open path:** `Recipe.structuredIngredients` getter (recipe_unified.dart ~1380) falls back to `core.ingredients.map(RecipeIngredient.rawOnly)` — LENGTH-ALIGNED null-section entries — whenever `core.structuredIngredients` is null or `!_structuredAligned`. So a factory recipe with no structured entries still feeds `build` a length-matched list of null sections ⇒ contiguous-null-collapse ⇒ no headings. The mismatch/fail-open branch is essentially **unreachable from the VM** (VM always scales via `scaleEntries(structuredIngredients,...)` which preserves length); it's a pure defensive guard, correctly tested only at the model level.
- **`build` trusts upstream section normalization — not self-defended.** `build` emits a heading for any `section != null`, so a `section: ''` (empty/whitespace) would render a BLANK heading. In production this is unreachable: `RecipeIngredient.normalizeSection` trims blank→null at every ingestion boundary (`fromJson`, the parser factory, `copyWithSection`). But the *default* `RecipeIngredient(section:'')` constructor does NOT normalize, and `build` doesn't either — so the "no blank heading" guarantee lives entirely upstream with no regression test tying the two together. Low severity (not reachable via persistence/parse), worth a one-line pin (`build([ing('x',section:'')],['x'])` → assert whatever the intended behavior is) if a future refactor moves normalization.
- **One concrete (optional) model gap:** fail-open is only exercised in the `structured.length > displayLines.length` direction. The opposite (`displayLines` longer — scaler expanded a line) hits the same `!=` guard + same comprehension, so it's structurally covered, but a second case would additionally prove no *display* line is dropped when display>structured (the comment claims "never drops or misplaces a line"). Cheap insurance, not a real hole.

### 2026-07-03 — Pooled-ratings key: recall/precision suites can share an "ignored-input" blind spot [Pattern + gap caught]
**Trigger:** reviewing `test/unit/services/rating/canonical_pool_key_test.dart` (v1 `CanonicalPoolKey`) + `content_fingerprint_golden_test.dart` on `claude/pooled-ratings-v1`.

- **Blind spot pattern (systemic, worth checking on any composite-key test):** the key was `hash(dishAnchor + ingredientNames)`. Every RECALL test held the ingredient set constant (reorder/OCR/hashtag variants) and the single PRECISION test varied the *anchor* (sockerkaka vs muffins on identical batter). Net effect: an implementation that ignored ingredients entirely and keyed on the anchor alone would have passed **all 20** tests green. Verified by probe: `key('Köttbullar',[blandfärs,lök])` ≠ `key('Köttbullar',[blandfärs,lök,ströbröd,ägg])` — ingredients *do* participate, but nothing pinned it. **Rule:** for a key/hash built from N inputs, you need at least one test per input where that input is the *sole* differentiator; otherwise the suite can't distinguish "input participates" from "input ignored." Added `ingredients drive identity — same anchor, different set → new pool` (also pins the deliberate v1 **exact-set-match** limitation: adding one ingredient SPLITS the pool — a real recall tradeoff a fuzzy-pooling refactor must revisit, not delete) + `empty title yields no key`.
- **Characterization-golden written AFTER a refactor pins the NEW behavior, not the old.** `content_fingerprint_golden_test.dart` pins `ContentFingerprint.generate()` byte-for-byte to protect the persisted GlobalRecipeCache. It correctly detects *future* drift, but it cannot by itself prove the just-done normalizer extraction was behavior-preserving — it pins whatever the current impl emits. Confirmed preservation the only reliable way: `git diff main` showed the constants + method bodies moved **verbatim** into `RecipeTextNormalizer`. Lesson: when a golden is added in the same change that refactors the thing it pins, verify faithfulness against the pre-refactor source (diff or capture-from-`main`), don't treat a green post-refactor golden as proof. The "fail-closed on drift → bump cache version, don't re-pin to green" docstring framing is the correct pattern for cache-persisted hashes; sha256-substring values can't be hand-invented so genuineness is established once the diff is verbatim + test green.
- **Minor (not fixed):** the `longest-token tie-break is first-wins` test only re-runs identical input, so it proves determinism, not first-vs-last-wins (anchor is hashed, not observable) — the name overclaims but the behavior it can reach is covered. And the longest-token anchor heuristic has an untested recall risk: a longer *descriptive* noun can hijack the anchor ("Tacopaj" vs "Tacopaj med köttfärs" → anchor flips to "kottfars"), splitting a pool. Left as a noted risk, not a required v1 test. Cross-language TS-twin parity (`functions/src/ratings/canonical-pool-key.ts`, condition C4) is deferred to the twin's golden fixture — correctly out of scope for these Dart tests.

### 2026-07-03 — Ingredient-sections reorder matrix: the "line-to-heading-boundary" branch is a distinct 5th case (PR #211, chunk 9) [Review + 1 gap filled]
- **Trigger:** Reviewing `ingredient_section_state_test.dart` (NEW, moveRow 4-way matrix) + `form_fields_manager_test.dart` (NEW, reorderAt/moveAt) for `IngredientSectionState.moveRow` — the highest-risk index-mapping in the feature.
- **Verdict: both suites pass (26→27 tests), non-vacuous, pure-model (no theme/widget/padding asserts). Traced the LINE-down-across-heading case by hand: `moveRow(1,5)` → rows `H:Deg,L,H:Fyllning,L,L`, returns `(from:0,to:2)`, and `sectionsForValues(['m2','f1','m1'])` → `['Deg','Fyllning','Fyllning']`. Confirmed exact — an off-by-one in `_lineIndexOfRow`/the `adjustedTo--` decrement would shift the tuple and fail. LINE-up (`moveRow(4,1)`→`(2,0)`) is the mirror; both pin exact tuples so both catch off-by-ones.**
- **Gap found + filled — the `fromLine == toLine → return null` branch (moveRow line 136) was never exercised.** The matrix had LINE up/down, HEADING up/down, no-op, out-of-range — but a line dragged to a heading boundary *without crossing another line row* keeps its flat index while changing section. This is the purest expression of the positional-section design (a line's section is reassigned with NO line-data move). Added `LINE dragged to a heading boundary reassigns section with NO line move`: `moveRow(2,4)` on seeded `H:Deg,L,L,H:Fyllning,L` → rows `H:Deg,L,H:Fyllning,L,L`, returns **null**, and `sectionsForValues(['m1','m2','f1'])` → `['Deg','Fyllning','Fyllning']` (m2 reclassified Deg→Fyllning, values order untouched). Non-vacuous: drop the line-136 guard → returns `(from:1,to:1)` → `expect(move,isNull)` fails. (The `moveAt(from==to)` no-op means the caller wouldn't corrupt data even without the guard, but the guard's *intent* — "don't signal a line move when none happened" — is now pinned, and the section-reassignment-without-move behavior is the real prize.)
- **`describe()` helper reads the label from the LIVE controller** (`s.headingController(id).text`) rather than a stored string — correct: it survives a getter rename and proves the controller-to-row binding, not a field. Good pattern for row-model assertions.
- **Remaining lower-value untested cases (noted, not filled):** (1) adjacent same-section line swap (`moveRow(1,3)`→`(0,1)`) — a simpler variant of the covered LINE-down, structurally identical mapping. (2) HEADING-down *section consequence* — `moveRow(0,5)` layout is asserted via `describe`, but the resulting `sectionsForValues` (the two ex-Deg lines become ungrouped `null`) isn't; describe covers the layout, the section walk is covered by other tests. (3) `form_fields_manager`'s `moveAt` controllers-realign test asserts `.text` matches new order — this passes whether or not `moveAt` clears the controller map (the `controllers` getter reconciles existing controllers' text to `_values[i]` regardless), so it proves user-visible text-order but NOT the instance rebuild; acceptable under test-behaviour-not-identity, worth knowing if a future bug is about stale controller *instances* under ReorderableListView keys.

### 2026-07-03 — Ingredient-sections chunks 10-11: form wiring + editor widget (PR #211) [Review, all pass — no changes]
- **Trigger:** Reviewing `recipe_form_state_test.dart` new `ingredient sections at save (PR #211)` group + `ingredient_section_state_test.dart` new `moveLineToSection` group + `sectioned_ingredient_list_builder_test.dart` (NEW form-surface a11y widget). 29 model+widget tests + 4 save tests all green; `flutter analyze` clean on all five touched files.
- **Both load-bearing tests verified NON-VACUOUS by real production mutation (not reasoning):**
  - *TEMPLATE `_seedStructured` gap test* — mutated `_seedStructured = recipe.core.structuredIngredients` → `= null` in `_loadRecipeData`. Result: BOTH the template AND the non-template "editing preserves sections" test flipped to `Actual: [null, null]`. Confirms the whole capture→seed-sidecar→`sectionsForValues`→`deriveAll(sections:)` chain is load-bearing. Subtlety worth remembering: the editing test also went red under this mutation even though its `reuse` (=`_originalRecipe.structuredIngredients`) still carried Deg/Fyllning — because `deriveAll`'s `sections:` param is **authoritative and clobbers reuse sections, including clearing them**. An empty sidecar → `[null,null]` → overwrites the good reuse sections. So the sidecar seed, not reuse, is what these two tests actually pin.
  - *manually-added-heading test* — mutated by dropping the `sections:` arg from `createRecipe`'s `deriveAll` call. Result: ONLY the manually-added-heading test flipped red (`+2 -1`); template + editing stayed GREEN because their `reuse` entries already carry persisted sections and nothing overwrote them. **Key insight: the manually-added-heading test is the SOLE guard of the `sectionsForValues`→`deriveAll(sections:)` derivation wiring** — it's the only test in the group with no `reuse` fallback, so it's the only one that can distinguish "sidecar stamped the section" from "reuse carried it." Also transitively exercises `moveIngredientRow` for a HEADING (heading→top via `moveRow(2,0)` returns null → no manager move; if that broke, sections would be `[null,null]`).
- **Real gap (medium value, NOT filled — flagged): the VM↔manager LINE-move seam is untested end-to-end.** The save-group tests set up state by calling `ingredientsManager.updateItems` + `ingredientSectionState.seedFromStructured` **directly**, bypassing the coordinated `addIngredientLine`/`removeIngredientLine`/`moveIngredientRow`(line)/`moveIngredientLineToSection` VM methods. Each half is tested (sidecar primitives in `ingredient_section_state_test.dart`; deriver stamping in the save group) but the seam `if (move != null) _ingredientsManager.moveAt(move.from, move.to)` is only proven for the HEADING branch (returns null → no moveAt). A regression where the VM computes the line-move tuple but forgets to apply it to the manager would leave values in old order while sidecar rows/sections are in new order → **silent section↔value misalignment at save**, uncaught. Worth one VM-level test: seed a 2-section recipe, `moveIngredientRow` a LINE across a heading (or `moveIngredientLineToSection`), `createRecipe`, assert BOTH the value order and the section order. (Reversed remove ordering — `removeAt` before `onLineRemoved` — is by contrast harmless: both index independent structures at the same flat position.)
- **Model gaps (low, noted):** `maxHeadingLength` (60) has no model-level guard/test — enforced only by the widget's `TextField maxLength`; a non-UI path (import/paste) could exceed it. `onLineRemoved` does NOT re-assert the "≥1 line slot" invariant that `seedFromStructured` guarantees — removing the last line leaves 0 rows/0 values (stays aligned, so no bug); the invariant is UI-guarded by the widget's `if (lineControllers.length > 1)` delete-button gate. Blank-section-string seed (`ing('a', section:'  ')`) not pinned at the seed path (covered indirectly by `normalizeSection`).
- **Widget gaps (low-medium, noted, form surface only — detail/cooking heading Semantics are the chunk-12 sweep, correctly out of scope here):** the "Flytta till rubrik" menu test asserts the affordance *appears* (`find.byTooltip`) but never opens it + taps an item, so `onMoveLineToSection(rowIndex, headingId)` arg dispatch (esp. `rowIndex` correctness) is unproven. Auto-add-line-on-typing (`_handleLineChange`: first char in last field → postFrame `onAddLine`) is untested — high-frequency user path. `canAddHeading:false` disabling the button, the single-line delete-button hiding (`lineControllers.length > 1`), and the `lineIndex >= lineControllers.length` defensive `SizedBox.shrink` desync-guard are all unexercised. The widget correctly asserts behaviour/Semantics only, NOT theme values (heading uses `cs.primaryContainer`/`cs.primary` border — deliberately not pinned; no golden), which is right per DO-NOT-WRITE (no hardcoded theme).
- **BUG CAUGHT + FIXED — order-dependent flaky widget test.** `heading delete announces the heading-specific label` used `find.bySemanticsLabel('Ta bort rubrik')` (exact String) but did NOT call `tester.ensureSemantics()`. It passed only when the *preceding* test (`heading row carries Semantics(header: true)`) happened to leave the semantics tree enabled — in isolation / on a different run order it failed `Found 0 widgets`. Two independent faults: (1) missing `ensureSemantics()` (semantics tree not guaranteed on); (2) exact-string match on a MERGED label — the delete control wraps `Semantics(label: a11yRemoveIngredientHeading, button:true)` AROUND an `IconButton(tooltip: same)`, so the resolved node label is the parent-label + tooltip merged (frame-timing dependent), never exactly `'Ta bort rubrik'`. Fix: added the `ensureSemantics()`/`handle.dispose()` bracket AND switched to `find.bySemanticsLabel(RegExp('Ta bort rubrik'))` + `findsWidgets` (the a11y rule doc's prescribed shape — tolerant of the merge). Verified stable across 3 isolated + combined runs. **General rule for this codebase: a `Semantics(label:)` wrapping a tooltip'd Material button produces a merged/duplicated node label — always assert it with a RegExp, never an exact String, and always bracket `bySemanticsLabel` lookups with `ensureSemantics()` in the same test rather than relying on a sibling test.**
- **Non-brittleness confirmed:** widget test finds by Swedish l10n copy (`'Lägg till rubrik'`, `bySemanticsLabel('Ta bort rubrik')`, `byTooltip('Flytta till rubrik')`) under `createLocalizedTestApp`'s pinned SV locale — consistent with the codebase pattern, tests user-visible copy not structure. `describe()` in the model test reads labels from the live controller (survives getter rename). No `find.byType(Provider<...>)` topology asserts, no padding/spacing asserts, no `@override` bodies on Mock classes. Clean.

### 2026-07-03 — Ingredient-sections chunk 12: cross-cutting safety sweep (PR #211) [Review, all pass — no changes; twin-proof VERIFIED valid]
- **Trigger:** Reviewing the 5 chunk-12 cross-cutting safety files that pin binding acceptance criteria: `ingredient_sections_safety_test.dart` (NEW, criteria 1-3 + JSON/Firestore round-trip), aggregator merge-across-sections case, export `sanitizeForJson` section survival (GDPR crit 15), `rule_based_tier_sections_test.dart` (NEW, Gap B branches), analytics `has_sections` (crit 18). Critical ask: is the **allergen-twin proof (criterion 1)** actually valid — does tagging read ONLY the flat `recipe.ingredients` and never `structuredIngredients[].section`?
- **VERDICT: twin proof is VALID.** Traced the tagging input path end-to-end and confirmed `.section` is never on it:
  - `TaggingService._generateTagsCore` (+`generatePhase1Preview`, `getUnknownIngredients`) reads `recipe.core.ingredientsNormalized ?? recipe.core.ingredients` — the FLAT `List<String>`. That list is what feeds `IngredientLookupService.lookupFromRaw`, and `Phase1AllergenCalculator.calculate` reads verdicts only off the resulting `IngredientLookupResult` (`lookup.getPropertyStatus` / `getCombinedPropertyStatus`). No recipe object reaches the allergen calc.
  - **Grep of the ENTIRE `lib/services/tagging/` tree for `structuredIngredients`/`.section`: zero hits.** The only related tokens anywhere in tagging are the 3 flat-list reads in `tagging_service.dart`. `tag_generator.dart` touches `recipe` only for `recipe.id` (logging). All 5 phases read exclusively flat fields: `recipe.core.ingredients` (flat, phases 2/3), `title`, `instructions`, `timeMinutes`, `portions`, `recipe.cuisine`. None reads structured data.
  - **The one real subtlety I chased down:** `ingredientsNormalized` is read *first* (fallback to `ingredients`), so if that getter derived from structured data the twins could diverge. It does NOT — it's a plain stored `List<String>?` field on `RecipeCore` (only ever copied or set from JSON; `git grep 'ingredientsNormalized:'` in `lib/services` = no matches, nothing folds section text in). Both twins leave it null → both fall back to byte-identical `.ingredients`. Safe.
- **Precision nit (not a defect, worth recording):** the test comment says "tagging is a pure function of the flat ingredient strings." Slightly overstated — tagging ALSO depends on title/instructions/time/portions/cuisine. But those are identical between the sectioned twin and its flat twin, so the conclusion (identical `TagResult`) still holds. The *precisely* valid claim is: **the only field differing between the twins is `.section`, and no tagging code reads `.section`.** The static read-set argument is sound; running both twins through the real pipeline and diffing `TagResult` would be belt-and-suspenders, not a correctness gap.
- **"Could a section reach verdict logic?" — no live vector.** The only theoretical path is a heading leaking into the flat `ingredients` (or `ingredientsNormalized`) list. That's exactly what criteria 2+3 guard (`entry.raw == ingredients[i]`, no heading is ever a flat line) and what production `RuleBasedTier._applySections` structurally prevents: it stamps `.section` onto the `ParsedIngredient` SIDECAR only, never inserts a heading as an ingredient line, and **fails open** (returns lines unstamped) on `sections.length != parsed.length`. Verified the two Gap-B tests are non-vacuous against real branches: `if (!isSectionCaptureEnabled) return` (kill-switch OFF test) and the length-mismatch early-return (`_ShrinkingStrategy` drops a line → all sections null).
- **Other 3 tests behaviourally sound, non-brittle:** aggregator keys on `name|unit` and merges smör across Deg+Fyllning into one 125g line (sections never split a shopping line); export dumps the whole doc through `sanitizeForJson` with no field allowlist so `structuredIngredients[].section` survives (asserts values `'Deg'`/`'Fyllning'`, not structure); analytics test captures the `recipe_created` params map and asserts `has_sections` true/false. Minor note: `has_sections` is passed as a Dart `bool` in the params map (same established pattern as the pre-existing `has_image` bool) — Firebase Analytics coerces/drops bool params downstream, but that's a pre-existing SDK-level concern, not introduced here and out of scope for section-safety.
- **No accepted-deviations conflict** — the 2026-07-01 draft-verdict-authority entry is orthogonal (about draft-status FREE verdicts, not sections).

---
### 2026-07-03 — Ingredient-sections kill-switch + draft-restore sidecar (section-fixes worktree)
Trigger: reviewed two bug-fix test additions for the `ingredient-sections` feature.

- **Finding A (draft restore re-seeds the section sidecar).** `RecipeFormState.loadFromDraft`
  calls `_ingredientsManager.updateItems(list)` — but `updateItems` does NOT run the
  sidecar sync choke-points (`onLineAppended`/`onLineRemoved`); only `addIngredientLine`/
  `removeIngredientLine` do. So bulk-replacing the line list (draft restore, and by the same
  logic any future `updateItems` caller) leaves `IngredientSectionState._rows` stale at its
  constructor seed (1 `LineRow` for a fresh form). The sectioned editor renders one row per
  sidecar `LineRow`, so 5 of 6 restored ingredients vanish visually. The test
  (`recipe_form_state_test.dart`, 'loadFromDraft re-seeds the section sidecar…') is
  non-vacuous: without the fix `rows.whereType<LineRow>().length == 1` while
  `ingredientsManager.values.length == 6`, so `expect(lineRows, 6)` goes red. Draft key/JSON
  shape are correct — `recipe_draft_<id>` + `jsonEncode(map)` matches
  `RecipeFormAutoSaveManager.saveDraftData`/`loadDraftData`, and `expect(ok, isTrue)` guards
  against a silently-failed load. **Pattern:** any bulk `updateItems` on a FormFieldsManager
  that has a positional sidecar must re-seed the sidecar; a test that asserts
  `sidecar.rowCount == manager.valueCount` after each such path is the guard.

- **Finding B (kill-switch OFF fully reverts the text path).** `captureSubHeadings:false`
  now gates `_componentSubHeading` in `SwedishLineClassifier.extractStructureFromSections`,
  so heading lines ('Deg:','Fyllning:') are RETAINED as ingredients instead of dropped —
  allergen tagging sees the pre-feature flat input. Two tests pin it:
  `swedish_line_classifier_test.dart` at the classifier level, and
  `rule_based_tier_sections_test.dart` end-to-end through the tier. The tier test is the
  stronger guard: `RuleBasedTier.parse` → `parseStructureCachedAsync(neuralClassifier:null)`
  → `compute(parseStructureInIsolate, {'text',‘captureSubHeadings’})`, so it exercises the
  **isolate arg-map flag threading** too (the flag can't be read from ServiceLocator inside
  the isolate). Both retain-checks (`contains('Deg:')`) go red if the gating is reverted.

- **Gaps noted (all low-severity, none block):**
  1. **Cache-key flag-collision is untested.** `parseStructureCachedAsync` now keys the cache
     on `'$captureSubHeadings|$text'`; reverting it to just `text` would return a stale
     opposite-flag result on the same `ParsingContext`, and NO test would catch it (every test
     uses a fresh context). If this matters, add: parse same text twice on one context with
     ON then OFF, assert the second result retains headings.
  2. **Neural path flag threading untested** (`NeuralLineClassifier.parseStructureAsync`'s new
     `captureSubHeadings` param) — no ONNX model in unit tests, so only the fallback/isolate
     legs run. Neural is dormant; acceptable.
  Both the ON path (sections stamped) and the length-mismatch fail-open remain covered.

### 2026-07-03 — Round-trip serialization tests: assert on the toFirestore map path, not copyWith
Trigger: reviewed `RecipeSerialization` section-header round-trip tests (structuredIngredients was written but never read back by the hand-rolled `deserializeRecipe`, so shared/collaborative recipes lost "Deg"/"Fyllning" headings on load).
Pattern that makes a serialization round-trip test genuinely end-to-end (not a tautology):
- Drive it through the real serializer the production load path uses. Here `serializeRecipe` == `recipe.toFirestore()` (a fresh `Map<String,dynamic>`), NOT `copyWith`/in-memory state. A test that round-trips through copyWith proves nothing about the Firestore encode/decode.
- Non-vacuity check for a "field now read back" fix: the buggy deserializer simply omitted the constructor arg, and `RecipeCore.structuredIngredients` defaults to null → `expect(restored..., isNotNull)` + section-equality would FAIL pre-fix. Confirmed genuine regression guard.
- Guard the "no phantom empty list" direction too: `RecipeIngredient.listFromJson` returns null for non-List AND for empty-parsed list; `toFirestore` omits the key when null. A flat recipe must round-trip to `structuredIngredients == isNull`, else a spurious `[]` leaks.
- Load-bearing function coverage: `RealtimeRecipe.fromMap` (the real collaborative-load wrapper) is a thin `data['recipe']`-unwrap that delegates to `deserializeRecipe` — testing `deserializeRecipe` directly covers it transitively; grep confirmed it's the single recipe-reconstruction point (no separate partial/live-edit deserializer for structuredIngredients). Full-document reload is the only decode path, so incremental live-edit sync is covered on next reload, not by a distinct code path.
Acceptable narrowness: the test asserts section labels + flat-ingredient invariant only (not amount/unit/note); that's the bug's scope. Don't pad round-trip tests with per-field identity asserts already covered by `RecipeIngredient` fromJson/toJson tests.

### 2026-07-03 — Deleting dead code: grep for the exact symbol, beware prefix false-positives (deep-review finding F)
- **Trigger:** verifying that deleting `RecipeBackwardCompatibilityMixin.reorderIngredient` (singular, zero callers) loses no test coverage.
- **Pattern:** `grep reorderIngredient test/` returns many hits, but ALL are `reorderIngredients` (plural, `RecipeOperations` static — the 24-case matrix), `reorderIngredientsRealtime`, and `reorderAt` (`FormFieldsManager`). None reference the deleted singular mixin method. When a deleted symbol is a prefix of a live one, read each hit — a raw match count lies. Deletion was clean: the real sectioned-editor reorder path is `moveIngredientRow`/`moveRow`, which IS tested.

### 2026-07-03 — A "sole guard" comment must have a test that hits the guard, not just the happy path (finding E)
- **Trigger:** comment in `ingredient_section_state.dart onLineRemoved` was reworded to claim `if (_rows.whereType<LineRow>().isEmpty) _rows.add(const LineRow())` is "the sole guard that keeps the sidecar non-empty for any non-UI caller."
- **Gap found:** the only `onLineRemoved` test removed a MIDDLE line from 3 lines — never drove line count to zero, so the guard branch was untested. The `seedFromStructured` empty-case test ("no lines still yields one line slot") covers a DIFFERENT code path, not `onLineRemoved`.
- **Rule:** when a comment/PR asserts a specific defensive branch is load-bearing, confirm a test actually enters that branch. Added two tests (flat + under-heading) that call `onLineRemoved` down to zero lines and assert the empty LineRow re-appears. They fail iff the guard is removed; survive refactors (assert via the `describe()` row-shape helper, not internal list ops).

### 2026-07-03 — TextImportStrategy ingredient sub-group sections (caption imports) [Pattern]
- **What:** `text_import_strategy.dart` captures "Deg:"/"Fyllning:" sub-headings, stamps each ingredient's structured `.section`, and MUST keep the heading out of the flat `ingredients` list (allergen-tagging safety invariant). 4 new tests review — all pass (41/41).
- **Alignment is text-keyed, not index-keyed:** `_sectionsFor` builds the sections list by iterating `cleanedIngredients` and looking up `sectionByKey[ing.toLowerCase()]`; `deriveAll` only applies sections when `sections.length == lines.length`. Robust to reordering; unmatched line degrades to null-section, never a wrong one. Don't write index-fragility tests against it.
- **Good coverage:** safety invariant (no heading leak, both `deg` and `deg:`) is the highest-value test and is present. Both capture paths asserted — STAGE-1 measurement-first ("2 dl socker") AND STAGE-3 scored ("1 nypa salt"). All-null no-regression case present. English "Dough:/Filling:" test doubles as the headerless-caption guard (no "Ingredienser:" marker → exercises the `!inInstructions` gate; a regression to `if (inIngredients)` fails it). None are vanity/impl-detail.
- **Genuine gap (suggested 1 test):** no test mixes GROUPED + UNGROUPED ingredients in one recipe — an ingredient BEFORE the first heading must stay `section == null` while later ones get stamped. Guards `currentSection` starting null + no retroactive assignment. Every existing test is all-grouped or all-null.
- **Known limitation (not a bug, cosmetic):** two identical parsed ingredient strings under different headings → `putIfAbsent` gives the second the FIRST section. Sections are cosmetic grouping, not safety; acceptable, don't demand a test.

### 2026-07-03 — Pooled-ratings Increment 5: GDPR export ⊇ erased symmetry [Pattern]
- **What:** review of the `pooled_rating_events` section added to `DataExportService` (reads `users/{uid}/canonical_rating_events`) + its erasure in `account-deletion-cascade.ts`. Dart 33/33, emulator 44/44.
- **Three-lane proof, and each lane owns a distinct claim — don't duplicate across lanes:**
  1. *Export unit* (`data_export_service_test.dart`): section always present (`isNotNull` in 'all required sections' — empty user) + a seeded real doc flows through (`error` isNull, `total_count` 1, id + ratingValue) proving the read path, not mere presence.
  2. *Deletion integration* (`request-account-deletion.integration.test.ts`): target's own event erased (I-CRE1), OTHER's retained (I-CRE2, uid-scope proof), residual probe counts zero (I-CRE3 leans on I21's empty `failedCollections`). The probe hits the SUBCOLLECTION via `.count()`, not a `where("userId","==")` — that wrong-field trap silently matches zero (realtime_recipes lesson, called out in the cascade comment).
  3. *Rules* (`canonical-stats-rules.test.ts`): owner-read read-scope — owner CAN, stranger/unauth CANNOT, collectionGroup DENIES, owner cannot create/update/delete (CF-only). This is where "ownership-denied read" lives — FakeFirebaseFirestore in the export unit bypasses rules, so DON'T try to assert read-denial there; it's structurally impossible (export only ever passes its own uid) and rules-covered.
- **Marginal non-gap (did NOT demand a test):** empty-user section isn't explicitly asserted `error`-isNull/`total_count` 0 — but an empty subcollection query can't error where the seeded query succeeds (same `_queryList`), so it's not an independent failure mode. Redundant per the one-meaningful-test rule.
- **Verdict:** adequate. All four intended behaviors (present-when-empty, real-data-flow, deletion-scope, read-ownership) each have a test that fails iff the behavior breaks and survives refactor.

### 2026-07-04 — Firestore stores whole-number aggregates as int (pooled-ratings 6a review)
**Trigger:** reviewing getPooledStats parsing tests. **Pattern:** when a server aggregate
holds a numeric mean that can land on a whole number (a small pool where every rater agreed
→ average exactly 5), Firestore stores it as `int`, not `double`. Production must read it as
`(data['field'] as num?)?.toDouble()` — `as double?` throws `int is not a subtype of double`
and silently drops the value. A parsing test that only feeds a `double` (4.3) never proves
this. **Rule:** for any read that parses a numeric average/mean/ratio from Firestore, add one
case with a whole-number value stored as int (`'average': 5`) and assert it → `5.0`. Cheap,
catches a real `as double?` regression. (Applies beyond ratings: any count-derived mean.)

### 2026-07-04 — Don't demand a module-level test for a one-line stamp into tested logic
**Trigger:** judged whether `_saveToCache`'s `ratingPoolKey = CanonicalPoolKey.compute(...)`
stamp needs a direct test. **Rule:** when a production line is a single assignment calling a
pure function that already has dedicated coverage (CanonicalPoolKey.compute had 19 tests incl.
fail-closed null cases), a heavy module-wiring test to prove "the assignment happened" is
low-value plumbing — indirect coverage is adequate. The only load-bearing bit worth a comment
is *ordering*: the compute must run before serialization so both cache (toJson) and Firebase
sync pick up the field. Flag ordering in review; don't mandate the test.

### 2026-07-04 — Dual serialization leg: a Firestore-only round-trip leaves the JSON leg unguarded (pooled-ratings 6 review)
**Trigger:** reviewing the `ratingPoolKey` round-trip test in `recipe_unified_test.dart`.
**Pattern:** `RecipeCore` (and models like it) serialize through TWO independent legs —
`toJson`/`fromJson` (local cache) and `toFirestore`/`fromMap` (Firestore). A new nullable
field's production change touches all four, but a round-trip test that only exercises
`fromMap(toFirestore())` proves nothing about the JSON leg. A future refactor could drop the
field from `fromJson` while `fromMap` keeps it and the test stays green. The existing generic
"round-trip JSON serialization" test uses the *default* instance (field = null), so a non-null
value never crosses the JSON leg. **Rule:** when a model has both legs, assert a NON-null value
survives BOTH `fromMap(toFirestore())` AND `fromJson(toJson())` — one extra line, closes the
asymmetry. Not a bug here (both legs added symmetrically), but the guard is what a round-trip
test is for. Also: `getPooledStats('')`'s empty-key early-return is a *real* contract, not a
tautology — `.doc('')` asserts in cloud_firestore, so the guard prevents a throw, not just a
redundant read.

### 2026-07-04 — Pooled-ratings 6/6a re-review: JSON-leg gap CLOSED, verified non-vacuous
**Trigger:** re-review after the earlier "Firestore-only round-trip leaves JSON leg unguarded"
finding was addressed. **Verified:** `recipe_unified_test.dart` now seeds a NON-null
`ratingPoolKey: 'v1:abcd1234ef567890'` via `copyWith` (default is null, so the value genuinely
differs) and asserts `RecipeCore.fromJson(core.toJson()).ratingPoolKey` == the seed alongside
the `fromMap(toFirestore())` leg + copyWith-sentinel (omit-keeps / null-clears) + legacy-doc
(field removed → null). Not a null-in/null-out tautology: dropping the field from `fromJson`
returns null ≠ seed → red. Both round-trip legs now proven with a live value. 52/52 pass.
**Pooled-stats file adequacy confirmed** — all six contracts each have a fail-iff-broken test:
n≥5 floor pinned at exactly 5 (count 4 false / 5 true, so changing `displayFloor` to 6 breaks
the at-floor test), null-average-never-displays (count 99 + null → false), whole-number average
stored as `int` survives `as num?` (`'average': 5` → 5.0), empty poolKey → null, missing doc →
null, one-decimal `displayAverage` (4.25 → "4.3", null → "0.0"). No real-regression gap found;
did NOT pad. One documented caveat carried forward: the empty-key guard's throw-prevention value
(real cloud_firestore asserts on `.doc('')`) is only partially reproduced by FakeFirebaseFirestore,
which returns null for a missing empty-id doc anyway — the test still pins the null contract, but
guard removal wouldn't necessarily go red under the fake. Acceptable; the contract is the null.

### 2026-07-04 — Trigger: reviewing pooled-ratings E2 (client display); the inject-vs-remap coverage blind spot
Pooled-ratings decision-9 display coverage came in three layers with a gap in the *middle*:
- **Repo unit** (`getBulkPooledStats`) returns a map keyed by **poolKey**.
- **Widget** (`RecipeCard`) is handed a `PooledStats?` **directly** and asserts pill-replaces-alla /
  fallback / null-unchanged.
- **The ViewModel seam that joins them** (`RecipeListViewModel._refreshPooledStats`) does the real
  work: flag-gate, collect poolKeys off the visible window, then **re-key poolKey → recipeId** onto
  the `pooledStats` getter the card reads. This seam had **zero** tests. If the remap regressed
  (kept poolKey keys / mapped the wrong recipe / dropped the flag gate), pooled pills would silently
  never appear in production and *neither* the repo test nor the widget test would go red — each
  side stubs past the join. **Pattern: when a repo returns data keyed by X and the widget consumes
  it keyed by Y, the VM that does X→Y is the highest-value test, not the endpoints.** Recommended a
  focused VM test (two recipes sharing one poolKey both receive the stat via `pooledStats[recipeId]`;
  a pool-less recipe gets none; flag-off → empty). Feasible on the existing `recipe_list_viewmodel_test`
  setUp — `mockRecipeService.setRecipeState(recipes:)` fires `_onRecipesChanged` → `_refreshPooledStats`;
  only extra wiring is registering a mock `RatingsRepository` + a `FeatureFlagService` returning enabled.
  Note the parallel `_refreshPantryMatches` is *also* untested but is lower-risk — its map is keyed by
  recipeId directly (no cross-key remap), so it lacks this seam's regression surface. "Mirrors an
  untested method" is not a reason to skip when the remap is the untested part.
- **Second gap: decision-9's demotion branch.** The widget tests never set a family/personal rating
  *together with* a floor-meeting pool, so `_buildFamilyPill(demoted:true)` / `_buildRatingPill(demoted:true)`
  — the "drop the household pill to neutral so only one brand-green number shows" invariant — have no
  coverage. A theme-resolved test (capture `cs` + `context.butleryColors.neutral` via Builder, assert the
  family pill's Container flips primary→neutral when a floored pool is present) catches removal of the
  `demoted: showPool` arg (which would render two green pills). Don't hardcode the color; resolve from theme.
- **Swedish assertions are robust here:** `betyg` (from `butleryBetygCount` → "N betyg") appears only in the
  pooled pill's *Text*; the family a11y label "Familjebetyg" is a `Semantics` label, which
  `find.text/textContaining` does **not** traverse. `alla` is an established pattern in this file; only
  faint risk is a factory recipe title/tag containing the substring — acceptable.

### 2026-07-04 — Pooled-ratings E2 re-review: T2 demotion gap CLOSED (non-vacuous); T1 seam still open [Pattern + verification]
Re-review of `test/widget/recipe/recipe_card_test.dart` diff on `claude/pooled-ratings-v1`.
- **T2 (demotion) — RESOLVED, verified non-vacuous.** New test `'a floored pool DEMOTES the
  co-existing family pill off brand-green'` renders `familyAverage:4.2 + familyRatingCount:3`
  together with `PooledStats(count:12)` (clears the n>=5 floor), asserts BOTH `familj` and
  `12 betyg` render, then pins the family `Text.style.color == cs.onSurfaceVariant` (resolved
  live via `tester.element(find.byType(RecipeCard))`). Non-vacuous by construction: in
  `_buildFamilyPill` the demoted fg is `onSurfaceVariant`, the un-demoted fg is `onPrimary`;
  these are distinct lightTheme roles, so removing `demoted: showPool` (default false) leaves
  `onPrimary` and the assertion fails. `find.textContaining('familj')` is unique — the family
  *Text* is lowercase "familj {rating}" while the a11y "Familjebetyg" is a `Semantics` label
  (not traversed by `find.text*`), and the pooled pill text carries no "familj". Green in the run.
- **T1 (RecipeListViewModel._refreshPooledStats poolKey→recipeId remap + flag gate) — STILL
  ZERO coverage; deferred.** The caller's stated deferral rationale ("display contract already
  covered by the widget tests + getBulkPooledStats unit tests") is **the exact seam blind spot
  I flagged** and does not hold: the widget test injects a `PooledStats?` directly and the repo
  test returns a poolKey-keyed map — *neither* exercises the VM's re-key. A remap regression
  (keeps poolKey keys / maps the wrong recipe / drops the flag gate) leaves BOTH endpoint tests
  green while pooled pills silently never render. So it is genuinely uncovered.
- **My verdict: deferral is ACCEPTABLE for this increment, but for a different reason than the
  one given.** The real mitigants are (1) `enable_pooled_ratings` defaults **false** in prod
  (`feature_flag_service.dart:66`) so the seam is dark — a regression is invisible to users
  until the flag is flipped; (2) the failure mode is display-only (pills don't show) — no data,
  permission, money, or GDPR exposure. **T1 must land before the flag is enabled**, not "someday".
- **Feasibility correction for the follow-up:** the "no test flag-setter / not in test DI" framing
  overstates the cost. The VM reads `ServiceLocator.tryGet<FeatureFlagService>()?.isEnabled(...)`
  and `ServiceLocator.get<RatingsRepository>().getBulkPooledStats(...)`. Standard path:
  `class MockFeatureFlagService extends Mock implements FeatureFlagService` +
  `when(() => m.isEnabled(FeatureFlags.enablePooledRatings)).thenReturn(true)`, register both it
  and a mock `RatingsRepository` in the test ServiceLocator, then drive `setRecipeState(recipes:)`
  (fires `_onRecipesChanged` → `_refreshPooledStats`) and assert `vm.pooledStats[recipeId]` for two
  recipes sharing one poolKey + none for a pool-less recipe + empty when the flag stub returns false.
  Moderate boilerplate, not a blocker-grade obstacle — it belongs on the existing
  `recipe_list_viewmodel_test` setUp.

### 2026-07-07 — BUT-1477/1478 review: pure-seam tests leave the transaction wiring AND the config table unpinned [Pattern — reviewed]

`rate-limiter-daily-cap.test.ts` (6/6 pass, real pure function + fixed Date, strong exact-value asserts — no weakened assertions, no mocked-away subject). But the seam-only pattern (same as `rate-limiter-refill.test.ts`) leaves two regression holes in `checkRateLimit`:
1. **Enforcement wiring**: nothing proves the transaction persists `dailyCount: prior + 1` + `dayKey` on the allowed path, nor that the daily-cap denial returns BEFORE consuming bucket tokens / writing the doc. Dropping the `+ 1` (or the whole `if (!dailyCap.allowed)` block) keeps all 6 seam tests green while the cap never fires. Same shape as BUT-1300 (injectable-factory default gap): a seam test proves the decision, never the caller.
2. **Config-table pinning**: `RATE_LIMIT_CONFIGS` is module-private and `getConfig` unexported, so removing `dailyLimit: 100` from `structureRecipe`/`importRecipe`/`ocrRecipeImage` (the entire point of BUT-1477 — bounding per-user LLM spend) regresses with zero test failures. Mirrors the lessons-digest "assert the declared index config in a test" idiom — cost-control config values need a pin, which needs a small export seam.

Also BUT-1478: `expireAt` (GDPR Art. 5(1)(e) TTL field on `parse_events`) is computed inline in the `onCall` handler — no seam, no test; a refactor dropping the field silently reopens unbounded retention. The Firestore TTL *policy* on `expireAt` is console config and untestable from unit tests — deploy-day checklist item, flag don't fake.

### 2026-07-07 — BUT-1495/1496 tagging-lookup review: locale-comma splitting edge [Pattern discovered]
Reviewing the comma-tolerant alias split (`csvToFirestore` now uses `/[;,]/` for `aliases_sv`)
plus the Dart lookup fixes (definite plurals, och-conjunction expansion, variation trims).
The new tests are well-aimed — each fails on pre-fix code, no weakened asserts, subject not
mocked. **Recurring pattern worth checking every time a list-split regex gains ','**: scan the
SAME file for decimal-comma handling of the same locale. `sync-ingredients-core.ts` already
normalizes Swedish decimal commas for `avg_price_sek` ("12,50"), proving the Sheet contains
decimal commas — so an alias like "lättmjölk 0,5%" would now split into two junk aliases that
feed `normalizedNames` (the allergen-lookup surface). No test pins that edge; fix candidate is
comma-not-between-digits (`/;|,(?![0-9])/`). Also noted: the `namesToNormalize.isEmpty → [raw]`
fallback branch in `lookupFromRaw` (quantity-only lines like "2 dl") is new and untested — the
och-split headline paths are tested but the defensive branch isn't.

### 2026-07-07 — BUT-1487 dead-code sweep review: default strategy registry is the untested seam [Pattern discovered]

Reviewing the import-tagging-dead-code sprint diff (FileImportStrategy removed from `ImportManager._initializeStrategies`; `ingredient_categorizer.dart` moved tagging/→shopping/ byte-identical, hash-verified; Instagram `extractWithResult`/`InstagramExtractionResult` family deleted with zero remaining references). Two reusable checks:

1. **Verify a "pure move" with `git hash-object <new> == git rev-parse HEAD:<old>`** — instant proof no logic edit hid inside the relocation, immune to CRLF noise that makes `diff` scream.
2. **The BUT-1300 injectable-factory-default gap applies to `ImportManager` specifically:** every active test uses `ImportManager.withStrategies(...)`; the ONLY default-constructor tests live in `test/integration/import/import_end_to_end_test.dart` which is bulk-`@Skip`ped (BUT-369) and `test/corpus/` (manual harness). So the production `_initializeStrategies` registry — which `importSinglePhoto` depends on via `whereType<PhotoImportStrategy>()` — has no active pin. Any diff editing that registry deserves one default-constructor test asserting `availableStrategies.whereType<PhotoImportStrategy>()` is non-empty (binding + `SharedPreferences.setMockInitialValues({})` already set up in import_manager_test.dart make it cheap). The "FileImportStrategy is unreachable in auto loops" premise itself IS pinned (three canHandle/validateInput-always-false tests in file_import_strategy_structure_test.dart), so its removal needed no new test.

### 2026-07-11 — social burndown review: BUT-1506 friend-cascade merge + BUT-1505 denorm txn [Pattern + Bug found — reviewed]

Reviewed `functions/src/cleanup/on-user-deleted.ts` (BUT-1506 merge of reverse-friendship delete + friend-count decrement into one idempotent batch) and `lib/services/family/family_rating_service.dart` (BUT-1505 transactional partial-update denormalization), plus both test files.

**Bug (correctness, GDPR-erasure-blocking): missing `public_profiles/{friendId}` makes the merged batch fail permanently.** `cleanupFriendshipsAndDecrementCounts` gates on the reverse-friendship doc's existence but then unconditionally `batch.update(public_profiles/{friendId}, increment(-1))`. Firestore `update()` on a non-existent doc throws NOT_FOUND and fails the WHOLE atomic batch. Real trigger: two users mutually friend each other, user A deletes (removes reverse doc in B's list + deletes `public_profiles/A`, but the cascade NEVER cleans A's own `users/A/friends/*`), then user B deletes → B's cascade reads `users/A/friends/B` (still present) as the idempotency token → proceeds to decrement the already-deleted `public_profiles/A` → NOT_FOUND → batch fails → cascade rethrows → onUserDeleted retries forever → all downstream GDPR purges (feedback/presence/notifications/cook-events) never run. Pre-existing in the old separate `updateFriendCounts`, but the merge (a) is the natural fix site and (b) now also blocks the reverse-friendship delete that previously committed independently. Fix: include the profile ref in the per-chunk `getAll`; if reverse exists but profile missing, delete reverse + audit only, skip the decrement. **Test gap:** the integration test never seeds a friend WITHOUT a public_profile — the exact new failure mode is uncovered.

**Dart test gap (the fix's own contract is unasserted): sibling-field preservation.** BUT-1505's whole point is "write ONLY the two family fields via dotted-path `txn.update` so a concurrent edit to any other recipe field isn't clobbered" (the old bug rewrote the whole doc). No test asserts an unrelated `core.*` field (e.g. `title`) SURVIVES the denorm. Confirmed feasible: fake_cloud_firestore applies dotted-path `update({'core.familyAverage':...})` as a nested merge (the green EQUAL-WEIGHT test reads `core['familyAverage']` back out of the seeded `core` map — proof siblings are preserved), so a `expect(core['title'], 'Fläskpannkaka')` after denorm would pass with the fix and fail on a regression to whole-doc rewrite. This is the achievable proxy for the concurrency contract (the fake can't detect real txn conflicts — a true concurrent-write test needs the emulator lane).

**Dart test gap (new branch): `!recipe.isPersonal`.** The denorm's new guard `if (recipe == null || !recipe.isPersonal) return;` has a test for the `null` half but none returning a non-personal (community) recipe. A regression dropping `!recipe.isPersonal` passes every current test.

**Integration test smell:** BUT-1354 summary asserts use `>=` (`friendsRemoved >= 1`, `socialRequestsCleaned >= 2`) despite per-run id isolation making exact counts knowable — `>=` would not catch a double-count regression. The added BUT-1506 retry assertions correctly use exact (`=== 0`, `=== 2`); the positive-effect ones should too.

### 2026-07-11 — BUT-639 lifecycle_stage_classifier review: activated-via-lastCook proxy + untested priority [Pattern — reviewed]

`test/unit/services/analytics/lifecycle_stage_classifier_test.dart` (16 tests, pure function, all pass). Clean pure-function tests, good boundary discipline (14/30/31d dormant/churned edges, the BUT-1550 30d12h sub-day test defeats the classic `.inDays`-truncation regression). No topology asserts. Genuine gaps found:

1. **[Correctness/doc-impl mismatch, Medium] `activated` uses `lastCookAt` as a proxy for FIRST cook.** Doc (lines 11, 88-89) says "first cook within 7 days of signup" but the code checks `lastCookAt.isAfter(signupAt+7d)` and the only available input (confirmed at `user_property_bootstrap.dart:81-85` and the `recipe_detail_viewmodel` caller) is `lastCookAt` — there is no `firstCookAt`. Consequence: a still-active multi-cook user whose FIRST cook was in-window but whose LAST cook is past day-7 and who has <3 cooks in 14d falls through to `new_`. Concrete: signup 12d ago, cooked day-3 and day-10, cooksLast14Days=2 → not churned/dormant, cooks<3, activation window = signup+7 (5d ago), lastCook 2d ago isAfter → NOT activated → `new_`. An engaged user gets tagged `new` and would receive new-user onboarding nudges. Not testable with the current signature (single-cook users have lastCook==firstCook, so every existing test is consistent and can't surface it). Fix = add a `firstCookAt` param, or soften the doc to "a cook within 7d of signup" and accept the proxy. **Lesson: when a classifier's doc names an input it doesn't actually receive (first vs last cook), the divergence only shows for multi-valued histories — single-value fixtures make impl and spec agree and hide it. Check the caller's available data against the doc's claimed semantics.**

2. **[Coverage gap, Medium] The emphasized "priority matters" invariant between habitual (stage 3) and activated (stage 4) is untested.** The activated test uses cooksLast14Days:1; the habitual test uses signup 60d ago (outside activation window). No test pins a user who is BOTH inside the 7d activation window AND has 3+ cooks asserting `habitual` wins. A regression swapping the stage-3/stage-4 check order goes green. Add: signup 5d, lastCook 1d, cooks 5 → expect habitual (not activated).

### 2026-07-11 — settings-ui sprint review (BUT-1526 detailBottomNav + legal views) [Bug found — reviewed]

Reviewed `layout_scaffolds.dart` (new `detailBottomNav`), `settings_hub_view.dart`, the three
legal views, `notifications_view.dart`, `faq_view.dart`.

1. **[Correctness, Medium — content-language mismatch] Legal views load markdown by DEVICE locale, ignoring the in-app language override.** `privacy_policy_view.dart:49`, `terms_of_service_view.dart:38`, `community_guidelines_view.dart:40` all resolve the asset with `PlatformDispatcher.instance.locale.languageCode` (the platform/device locale). But `MaterialApp.locale` is driven by `LocaleProvider` (`butlery_app.dart:620,722`), and the very `LanguageTile` in `settings_hub_view.dart` lets the user override it. So a user who forces the app to English on a Swedish device sees an English AppBar title (`context.l10n.privacyTitle`) over a Swedish policy body — a GDPR/legal document in the wrong language. Fix: read `Localizations.localeOf(context).languageCode` (capture in `didChangeDependencies`, not `initState`) or `LocaleProvider.locale`. **Test to write:** pump each legal view inside `createLocalizedTestApp` with locale forced to `en` while `PlatformDispatcher` reports `sv`; assert the `en` asset is requested (inject an asset-loader / assert the loaded string is the English one). No existing test pins the locale SOURCE — every current fixture has device==app locale so the bug is invisible.

2. **[Convention/cost, Low] `settings_hub_view.dart:24` calls `ServiceLocator.get<ReportService>()` inside `build()`** (widgets/views rule: never `ServiceLocator.get` in `build`). Compounded: `reportService.watchIsAdmin()` is invoked in the StreamBuilder builder on every rebuild, so each rebuild spins up a fresh Firestore listener (cost principle). StatelessWidget so rebuilds are rare, but move the service+stream into a StatefulWidget `initState`/cached field.

3. **[UX inconsistency, Low] `detailBottomNav` "+" (index 3) navigates, main-menu "+" opens a modal.** `layout_scaffolds.dart:51` does `Navigator.pushNamed(context, items[3].route)` → `/laggTill` (route IS registered, no crash), whereas `_MainMenuLayout.onNavigationChanged` intercepts `index == 3` to open the add-recipe modal bottom sheet. Same affordance, two behaviours depending on surface. Decide: intercept index 3 in `detailBottomNav` too, or accept intentionally.

4. **[Consistency, Info] `terms_of_service_view.dart:31` `_loadContent` lacks the leading `if (!mounted) return;`** its two sibling legal views have. Harmless today (only initState calls it) but diverges — would matter if wired to a retry/listener.

5. **[Info] Markdown rendering split:** `privacy_policy_view` renders via `MarkdownBody`; `terms_of_service` + `community_guidelines` use raw `SelectableText`. Current `.md` assets are near-plain-text (numbered sections, `-` bullets) so it reads fine, but any future `##`/`**bold**`/link in ToS/CG would show as raw syntax. Not a bug now.

3. **[Coverage gap, Low] Never-cooked churned/dormant boundaries (lines 77-79) are a SEPARATE code path** (`sinceSignup`) from the cook-path boundaries, tested only at 20d→dormant / 35d→churned. Exact 14d/30d/31d edges on this branch are unpinned, so a `>`→`>=` regression on line 78 escapes. The cook-path has all three edges; mirror at least the 30/31 edge for the never-cooked branch.

### 2026-07-11 — BUT-1551 AuthService.deleteCurrentAuthUser quiet-delete review [Pattern discovered]
Reviewed the 3-test trio for the new `deleteCurrentAuthUser()` (returns `AuthUserDeletionResult{deleted,needsReauth,failed}`, never throws) that moves the underage age-gate's `FirebaseAuth.instance.currentUser?.delete()` out of `onboarding_age_gate_blocked_view` and into the service. Tests at `test/unit/services/auth_service_test.dart` group "Delete Current Auth User (BUT-1551)". Verdict: sound, intent-driven, no weak assertions. Report-only.
- **The load-bearing "quiet contract" assertion is `expect(authService.errorMessage, isNull)` on the failure branches.** It's the discriminator vs `deleteAccount` (which sets a Swedish user-facing error). A regression copy-pasting deleteAccount's setError would fail these — correct guard. Works because a fresh AuthService has `errorMessage==null`, so it proves the method did NOT set it (not a tautology: the alternative implementation sets it).
- **Never-throws is the real acceptance link.** The view dropped its try/catch and now `await`s the service before `signOut()`; if the method rethrew, signOut is skipped. The `needsReauth`/`failed` tests (assert a returned enum, no throw) are exactly the regression guard for that wiring — so the "view routes through the service" criterion is adequately covered by proving-the-service + the diff, no widget test needed. Reinforces the line-184 entry: this StatefulWidget cleanup path belongs in a future age-gate JOURNEY test as one beat, not a standalone mechanical widget test (heavy ServiceLocator/nav scaffolding, BUT-387 Phase 6).
- **Gap (Low): the generic `catch (e)` branch is untested.** The `failed` test throws a `FirebaseAuthException(code:'network-request-failed')` — hits the `on FirebaseAuthException` block, not the trailing `catch (e)`. A non-Firebase throw (`throw Exception('boom')`) is a distinct branch also mapping to `failed`; add one line to cover it.
- **Gap (Low): `deleted` path's `_currentUser = null` side effect is unproven.** The success test never arranges a signed-in user, so asserting currentUser==null would be a tautology. Low value (caller signs out regardless); only worth pinning if the local-clear is ever load-bearing.

### 2026-07-11 — BUT-1540 deep-link expiry: boundary test one bucket away from the real flip [Pattern discovered — reviewed]
Reviewed the 5 new tests for `DeepLinkService.isTimestampExpired(int?)` (refactored out of `isLinkExpired`; the live `_handleRecipeLink` now early-returns on expiry). Rule is `clock.now().difference(linkTime).inDays > 7`. Verdict: catches loosening, MISSES tightening.
- **The decisive bucket is `inDays == 7`, and no test hits it.** `inDays` truncates, so the verdict flips between 7d23h (inDays 7 → NOT expired) and 8d0h (inDays 8 → expired). The suite tests inDays 6 (`6d23h`, labeled "the 7-day edge" but it's a full day short of the flip) and inDays 8. Mutation check: `>7`→`>6` (6-day expiry) and `>7`→`>=7` both differ ONLY at inDays 7 → every one of the 5 tests still passes → the two most plausible tightening regressions ESCAPE. Only `>7`→`>8` (loosening) is caught, by the 8d test. **Lesson: for a truncating-`.inDays` threshold `> N`, the boundary test must sit in the `inDays == N` bucket (assert not-expired) AND the `inDays == N+1` bucket (assert expired). A test one bucket below the flip proves nothing about the threshold. Same family as BUT-1550 30d12h and the BUT-639 never-cooked-branch note.** Fix: add `Duration(days: 7, hours: 12)` → isFalse alongside the existing 8d → isTrue.
- **Spec/impl off-by-one (pre-existing, not introduced): "expires after 7 days" but code keeps links valid through ~8 days** (`> 7` full days). Preserved from the original `isLinkExpired`, so not a BUT-1540 regression — but the test comment "at the 7-day edge (6d23h)" enshrines the mislabel. If product truly means death at 7×24h, code+tests are both wrong; that's a product question.
- **Handler navigation NOT worth a standalone test.** The 4-line guard is `int.tryParse(params['timestamp'] ?? '')` → `isTimestampExpired` → silent return. Decision is fully covered by the static tests; the early return is trivial. The only handler-specific untested bit is the tryParse→null fail-open (malformed/absent timestamp still opens the recipe — intended for legacy links). A NavigatorObserver+MaterialApp+mocked-RecipeRepository test for a 4-line guard is the heavy-scaffolding anti-pattern; fold "expired link doesn't open" + "malformed timestamp still opens" into a deep-link JOURNEY test if/when one exists (BUT-387 Phase 6 stance).
- **Style (no flake here): tests use `DateTime.now()` while prod reads `clock.now()`.** No clock override → same wall clock, and margins are hour/day-scale, so not flaky — but `withClock`/`fakeAsync` would be the pattern-correct form.

### 2026-07-11 — Boundary tests, not just far-side tests, catch off-by-one expiry bugs
Trigger: reviewing test/unit/core/bootstrap/deep_link_handler_test.dart (BUT-1587/BUT-1540 share-link 7-day expiry).
Pattern: an "8-days-stale is expired" assertion does NOT protect the fix BUT-1540 made
(`.inDays > 7`, which truncates to whole days and lets links live ~8 days, vs the correct
`> Duration(days: 7)`). Both the buggy and fixed impl return `true` at 8 days — the test
passes either way. To pin an off-by-one time boundary you must assert JUST INSIDE it: a
7d-12h timestamp is NOT-expired under the buggy `.inDays > 7` but expired under the fixed
`Duration` compare. Rule: when a ticket fixes a boundary/off-by-one, the regression test
must straddle the boundary (±1 unit), not sit comfortably on the far side. Pair with
`withClock`/`fakeAsync` so the reference `now` is fixed and the assertion is deterministic —
production here resolves time via `clock.now()`, so `withClock` controls it.

### 2026-07-11 — GDPR export tests: derive caps from getLimitForType, and don't skip the redaction path [Pattern discovered — reviewed]
Trigger: reviewed the two new export-manager tests (preferences_export_manager_test.dart BUT-1562, content_export_manager_test.dart BUT-1438/1440) + preferences_export_manager.dart.
Verdict: the truncated-flag tests are well-built (Fake not Mock, sentinel -1 default to catch a dropped `maxDocuments` forward, `expect(...==cap)` at exactly the cap so a `>`→`>=` regression is caught). Two durable lessons:
- **Hardcoding the cap value fights the "survive a harmless refactor" principle.** `ExportPaginationHelper.getLimitForType('user_notifications')` returns `defaultBatchSize` (500) *only because 'user_notifications' is absent from the `exportLimits` map* — an accident, not a decision (all the BUT-1450 sibling collections got explicit caps). The natural improvement (add an explicit `'user_notifications'` entry) would flip the real cap and break all three preferences tests, though behaviour got *more* correct. Rule for cap/limit tests: derive `final cap = ExportPaginationHelper.getLimitForType('<type>')` once and use it for BOTH `List.generate(cap, ...)` and the assertion — never a literal. Same applies to the pantry `1000` literals in the content test (that key IS in the map, so it's less fragile, but still config-coupled).
- **The security invariant in this manager is the FCM-token redaction, and it has zero coverage.** `exportFcmTokens` (preferences_export_manager.dart ~L143-163) truncates the push token to a 10-char prefix + `[redacted]`; a regression dropping the `containsKey('token')` guard or the substring would silently export a live credential in a GDPR bundle. The BUT-1562 test file only exercises `exportNotifications`. When reviewing a partial-coverage export manager, the redaction/anonymisation path outranks another happy-path list-reshape test (Phase 9 "invariant the LLM missed"). `exportNotificationDelivery`'s sent∪received de-dup-by-id + counts is the second-worthiest untested unit.

### 2026-07-11 — Salvage-gate re-review of the export/tagging test batch [Reviewed — CLEAN with one Low]
Trigger: re-reviewing staged tests from an incomplete sprint ship (preferences_export_manager, reserved_tags_consistency, tag_result migration, import_manager, detailBottomNav widget).
- **The FCM-redaction gap I flagged earlier today is now CLOSED.** `preferences_export_manager_test.dart` gained three `exportFcmTokens` tests: full-token → `prefix(10)+...[redacted]` exact-shape + raw-credential-absent-from-`result.toString()` invariant; short (<10) token → no RangeError (proves the `10.clamp(0,len)` guard); no-`token`-field row untouched. This is the correct security-invariant coverage — the redaction path outranks another happy-path list test (Phase 9).
- **Confirmed the two asked-about acceptance points.** (1) The truncated tests use a `Fake` (not Mock) with a `-1` sentinel `maxDocuments` default, capture the forwarded value, and assert `truncated`/`note` absent at 3 rows / present at exactly 500 — they exercise the manager's own `length >= limit` conditional, do NOT mock it away. (2) `reserved_tags_consistency_test.dart` injects its OWN probe (regex-scans the six phase source files at test time for `.add('x')` / `'key':[` / `return 'x'`), depends on no in-source debug probe, and has an "extraction actually fired" guard (`emittedTags.length > 80` + 5 representative tags) so a scraper broken by a phase refactor fails loudly instead of vacuously passing the FORWARD check.
- **One Low (unchanged from this morning's note, author kept the literal): the preferences test hardcodes `500`** in `List.generate(500,...)` / `contains('500')` / `capturedMaxDocuments == 500` instead of `final cap = ExportPaginationHelper.getLimitForType('user_notifications')`. The 500 is a *fallback default* (the key is absent from `exportLimits`), so adding an explicit entry — a behaviour-improving change — would red these three tests. Derive-the-cap remains the durable form. Not blocking.
- **tag_result migration group is exemplary domain-invariant coverage:** pins the read-time V0→V2 `_migrateSchema` (error-text lifted into `errorReason` only for `failed` results, not clobbering a normal recipe's `unknownIngredients`), migration idempotency (V2 blob not re-migrated), and the cross-user shared-cache round-trip proving safety verdicts survive while debug `decisions` are dropped from the stored blob. These are the invariants an LLM autopilot misses.

### 2026-07-12 — BUT-1594 signal-removal test review (cuisine/skill menu nudges deleted) [Reviewed — CLEAN]
Trigger: reviewed the uncommitted diffs for BUT-1594 removing the cuisine-affinity + cooking-skill menu weighting (scoring context is now pantry-only) across three files: menu_personalization_test.dart (service), menu_generator_personalization_test.dart (VM), household_size_view_test.dart (widget, renamed from menu_taste_view_test.dart).
Verdict: solid. Retained assertions still prove real behaviour, nothing weakened to pass. Durable lessons for "a signal was removed, trim its tests" reviews:
- **A `findsNothing` absence-assertion is only meaningful when the SAME test co-asserts a positive render.** The BUT-1594 regression test (`renders the intro line and the household stepper only`) asserts `find.text(intro)`+`find.text(stepper)` = `findsOneWidget` AND `SegmentedButton<CookingSkillLevel>`/`FilterChip('italiensk')` = `findsNothing` in one body. Without the positive half, `findsNothing` passes vacuously if the whole screen fails to build — so the removed-control guard would be a false green. Co-asserting the screen rendered makes the absence load-bearing. Verify this pairing whenever a test claims "control X is gone."
- **Deleting a signal's tests must be balanced by a KEPT guard that it survives WHERE it should.** BUT-1594 removed skill/cuisine from the *menu* screen but they stay on *profile-edit* (social bio). The `CookingIdentitySection keeps skill + cuisine (BUT-1594)` group both renders the shared controls AND taps a chip to prove `vm.cuisineAffinities` still updates — so an over-eager deletion that ripped the control out of profile-edit too fails here. A signal-removal PR without this "still-present-elsewhere" guard is under-tested.
- **`cuisineAffinities`/`CookingSkillLevel` legitimately remain referenced** in the VM/widget tests — those are `UserProfile`/`UserProfileViewModel` fields (still exist, profile-edit uses them). The now-removed symbols are the `MenuScoringContext` members (`cuisineAffinities`/`skill`/`maxSkillBoost`/`cuisineAffinityBoost`/`beginnerSimpleBoost`/`beginnerComplexPenalty`); grep confirmed the service test references none (only a one-line rationale comment). Don't conflate a shared field name across two subsystems — analyze-clean already proves no dangling ref.
- **Retained pantry coverage is complete:** boost direction (match>no-match), never-penalise on both the *absent-from-map* and *present-with-0.0* paths (distinct guards: `overlap==null` vs `overlap<=0`), partial<full, empty-context parity pinned to the literal recency baseline `90.0`, pantry ceiling ≤ rating ceiling + `maxCombinedBoost < debugMaxRatingBoost`, and the 3-seed diversity floor (maxShare ≤0.60, ≥6 distinct recipes) run through the REAL seeded generation entry. The parity test even keeps a `cuisineTag: 'italiensk'` recipe and asserts it scores exactly 90 — a bonus regression that cuisine no longer boosts. VM side keeps memoise-by-id + BUT-1279 fail-open (throwing pantry → empty map, generation completes) + unregistered + null-profile, all asserting generation is never blocked.

### 2026-07-12 — BUT-1594 follow-up: two new regression tests (null-original Save-arming + exit-dialog save-and-pop) [Reviewed — SOLID]
Trigger: focused re-review of two regression tests added after the BUT-1594 review found two real gaps (VM `hasUnsavedChanges` new-profile branch ignored `householdSize`; exit-dialog Save persisted but stranded the user on the screen). Both tests genuinely fail against the pre-fix code. Durable patterns:
- **To force the `_originalProfile == null && _editedProfile != null` branch of a dual-profile VM, build the VM with a null `currentUserProfile`.** `UserProfileViewModel._loadCurrentProfile` sees no profile → leaves `_originalProfile` null and builds a minimal editable *shell* (non-null `_editedProfile`). The default group VM (loaded profile) only ever exercises the `_profileFieldsEqual` branch, so a field omitted from the new-profile branch's `||`-chain (here `householdSize != null`) is invisible to every loaded-VM test. The new test asserts `hasUnsavedChanges==false` on the fresh shell (meaningful precondition: all fields unset) then `updateHouseholdSize(4)` flips it true — against pre-fix (no `householdSize` clause) the second expect returns false and the test fails. Note the VM reads profile via `ServiceLocator.get<UserService>().currentUserProfile`, NOT the injected `_userService`, so the null must be on the ServiceLocator-registered service (it is — test bridges the two).
- **Proving a "save-and-pop" (not just "save-and-close-dialog") needs a DUAL assertion after the pushed route pops: the subject view `findsNothing` AND the caller's home marker `findsOneWidget`.** The exit-dialog test pushes `HouseholdSizeView` onto a home scaffold carrying an `ElevatedButton('open')`, makes a change, fires system back via `tester.binding.handlePopRoute()`, then taps the dialog's Save. Because an opaque `MaterialPageRoute` drops the underlying route from the tree, `find.text('open')` is `findsNothing` *while the view is up* and returns only after a real pop — so co-asserting `HouseholdSizeView findsNothing` + `'open' findsOneWidget` distinguishes a true pop from a dialog that merely closed. Pre-fix (`Navigator.pop(dialogContext, false); await _save();` → handler returned `false`) saved but left the screen up, so `HouseholdSizeView` stays `findsOneWidget` → the test fails. Post-fix returns `!hasUnsavedChanges`.
- **Target the dialog's Save button, not the screen's, with `find.widgetWithText(ElevatedButton, commonSave).last`.** Both the screen's primary button and the dialog's are `ActionButtons.primaryButton` → `ElevatedButton`, so while the dialog is up two match; the later-pushed overlay route sorts last in traversal, so `.last` is the dialog button. Confirmed correct by the test passing post-fix (hitting the screen button would save-without-pop and fail).
- **A `Fake` service echoing the *unedited* profile back from `createOrUpdateProfile` is enough to make `saveProfile` report success and clear `hasUnsavedChanges`** — the VM syncs `_originalProfile = _editedProfile = updatedProfile` to the *same object*, so equality holds regardless of whether the echoed value reflects the edit. Save-success is legitimate without stubbing `isDisplayNameAvailable` because a household-only edit leaves `displayName` unchanged → `_hasDisplayNameChanged()` is false → the availability call is skipped (a Fake would otherwise throw `UnimplementedError` on it). Correct Fake usage: concrete in-memory body, no `when()` misuse.

### 2026-07-12 — BUT-1516 pooled "Butlery-betyget" menu weighting (review, no bug found)
Trigger: reviewing new tests for a Bayesian-shrinkage nudge whose whole point is that a few enthusiastic votes must NOT outrank a large slightly-lower pool.
- **A "reordering" assertion is only meaningful if you hand-verify the arithmetic makes it non-trivially true.** The key test asserts `multiplierFor(4.6★/n=200) > multiplierFor(5★/n=5)`. Confirmed against the constants (prior 3.5, shrinkage C=10): 5★/n=5 shrinks to `(10*3.5+5*5)/15 = 4.0` → 1.10×; 4.6★/n=200 shrinks to `(35+920)/210 = 4.548` → 1.21×. The inequality is real, not tautological — if shrinkage were dropped (raw average) the 5★ would win and the test would (correctly) fail. This is the anti-coverage-theater check: the test dies if `_pooledMultiplier` becomes a no-op OR loses the prior.
- **Bounds tests using `closeTo(constant, 0.01)` on a huge-n pool are the strongest no-op guards.** `10000 votes at 5.0 → closeTo(pooledMaxBoost=1.3, 0.01)`, `at 1.0 → closeTo(pooledMinFactor=0.85, 0.01)`, `at prior → closeTo(1.0, 0.001)`. A no-op multiplier (always 1.0) fails all three. Pairs with a `>0` selectability check on the worst dish (0.85×90=76.5).
- **The only two tests that survive a total no-op are legitimate:** the below-floor/null-average/absent-pool no-op cases (they catch "boost applied where it must NOT be" — a floor-guard regression) and the pure constant invariant `maxPooledBoost(1.3) <= debugMaxRatingBoost(1.4)`. Both are guard/config tests by design, not behaviour theater.
- **Plumbing zero-read guarantee is proven by `verifyNever(getBulkPooledStats)` under flag-OFF**, and keying-back is proven by an asymmetric fixture: return a stat for `v1:pool1` only → assert `r1` present, `r2` absent. The `r1.core.ratingPoolKey = 'v1:pool1'` stamping is what makes the fetch reach the repo without depending on `CanonicalPoolKey.compute` over factory ingredients. GetIt guard is sound: pooled group registers FeatureFlagService+RatingsRepository in its own setUp and unregisters both in its own tearDown (pooled group declared last), so no leak into the pantry group; outer tearDown only touches PantryService.

### 2026-07-12 — BUT-1470 import_manager parse-event logging (review; 1 real gap, no double-count)
Trigger: reviewed `_logParseEvent` at the `_parseWithStrategy` choke point + its 6-test spy suite.
- **The type-based URL exclusion (`if (strategy is UrlImportStrategy) return`) is complete, verified by grep, not by trust.** Only `url_import_strategy.dart` and `recipe_parser_service.dart` self-log `ParseEventLogger`; the photo/text/archive/social pipelines do NOT route through RecipeParserService (grep for `RecipeParserService` in `lib/services/import` hits only import_manager's comment + url_import_strategy). So there is no double-count for the non-URL paths — the exclusion needs to cover exactly one strategy type and it does. When reviewing a "single choke-point logger with an exclusion," prove the exclusion set == the self-logging set by grepping BOTH the strategies dir and the shared parser service, don't take the code comment's word.
- **Real gap: a strategy that THROWS is never logged.** `_logParseEvent` sits after `await strategy.import()` inside the try; a throw jumps to the catch (`Parse execution error`) with no event. That undercounts exactly the failures BUT-1470 set out to measure (OCR crash, social-pipeline network throw). RecipeParserService logs failures on its own exception paths, so the choke-point logger is asymmetric with the reference URL path. The spy suite has zero throwing-strategy coverage. Fix = log `success:false` in the catch (or a `finally`).
- **Test-gap pattern for "new logging at a shared method":** all 6 tests drive `importWithStrategy` (single strategy). The real entry points (`autoImport` fallback loop, `autoParseOnly`, `autoParseMulti`, `importSinglePhoto`) are untested for logging — and the fallback loop emits ONE event per attempted strategy (N-1 failures + 1 success for a multi-attempt import), so "#events != #user-imports" is an unpinned semantic a loop refactor could silently change. A logging test that only exercises the lowest-level wrapper, never the user-facing orchestration, leaves the interesting counting behaviour uncovered.
- **`_SpyParseEventLogger extends ParseEventLogger` (real superclass, one `@override`) is the CORRECT spy** — not the banned "@override body on a Mock." It's safe because ParseEventLogger is lazy-on-Firebase at construction, so `super()` runs with no Firebase app. But the spy captures `parseTimeMs` and NO test asserts it — a regression passing 0/wrong field goes unnoticed. Assert `greaterThanOrEqualTo(0)` when a spy records a field.

### 2026-07-12 — [trigger: review] Menu scoring-context cache (BUT-1455) — safety invariant separate from optimization
Reviewed `menu_generator.dart` `_reuseOrBuildScoringContext` + its 3 tests. Confirmed the reuse
cache is keyed by `pool.map(id).toSet()` and reused only when `pool.every(cachedIds.contains)`
(cache is a covering superset). Two things worth carrying forward:
- **Pattern (good):** to assert an I/O-reuse optimization, `verify(() => mock.read()).called(1)`
  then `verifyNever(() => mock.read())` after the second action — mocktail RESETS recorded calls
  on each `verify`, so `verifyNever` sees only post-verify invocations. The pantry read is the
  observable proxy; the pooled-stats read is gated behind `enable_pooled_ratings` (off in unit
  tests → zero reads regardless), so pooled-stats reuse is NOT observable in a plain unit test.
- **Missed domain invariant (recommend when touching this area):** the tests assert the
  optimization but none pins the SAFETY invariant that a stale cached scoring context can never
  reintroduce an allergen-unsafe recipe. It's structurally safe — `regenerateMenuSection`
  re-derives `pool` from `getAvailableRecipesAsync()` (fresh allergen filter) every call and the
  cache holds only scoring WEIGHTS keyed by recipeId — but a future refactor that also cached the
  POOL would silently break it. A regression-proof test: cache a context, tighten allergen prefs
  so a recipe becomes CONTAINS, re-roll, assert the recipe is absent from `lastGenerateRecipes`.

### 2026-07-12 — BUT-1593 title-source split in TextImportStrategy (review; test tightening is sound, one narrow edge uncovered)
Trigger: reviewed the uncommitted diff for `_parseTextToRecipe(text, titleSource)` — title now read from `normalized` (pre-preprocess) instead of `preprocessed`, plus a leading-fragment `titleKey` consumption loop in STAGE 3 — and the rewritten `should auto-detect text strategy and parse` test.
- **The test rewrite is the correct direction and genuinely fails on the pre-fix code.** It replaced loose `startsWith('Kottbullar') / length >= 3 / contains(...)` with exact `equals('Köttbullar med gräddsås')` + `equals([...3 ingredients])` + `equals([...3 instructions])`. Because the old code passed `preprocessed` for the title, it truncated to "Köttbullar med grädd", so the `equals` title assertion reds against pre-fix — the test straddles the fixed behaviour, not the far side. This is the good pattern (same family as the BUT-1540 boundary note): once a parse quirk is fixed, replace the quirk-tolerant loose assertion with the exact value so the quirk can't silently return. All 34 pass; analyze clean.
- **Uncovered narrow edge (Low): the `titleKey` consumption loop can eat a TOP-of-body ingredient line that is a prefix of the title.** The loop consumes leading lines while `titleKey.startsWith(buffer+lineKey)`. STAGE 1 (measurement-first) shields any *measured* ingredient, but a bare unmeasured line whose letter/digit key is a strict prefix of the title (title "Blåbärspaj", first body line "Blåbär") is consumed and lost. The code comment "can never eat a mid-recipe ingredient that merely echoes a title word" is true but understates it — it CAN eat a *top-of-body* line that prefixes the title. Genuinely narrow (needs bare line + prefix + before any non-prefix content), documented tradeoff, not blocking. No regression test exists for it, nor for the fallback path where preprocessing drops the title from the body entirely (then the loop tries to consume the first real content line). If this parser is touched again, add a "leading bare ingredient that prefixes the title survives" case.
- **`_titleKey` strips everything outside `[a-z0-9åäö]` after toLowerCase**, so accented non-Swedish letters (é in "purée") drop from the key → consumption under-fires (safe direction: leaves a fragment rather than eating content). Fine as-is.

### 2026-07-12 — Salvage review of force-committed 6f0942408 (TS + cleanup pieces the sprint gate didn't log)
Trigger: post-hoc salvage review of the parallel-sprint commit `6f0942408` (force-committed to main, no specialist re-read of the final diff). The Dart pieces (BUT-1470 / BUT-1455 / BUT-1593) are already reviewed above and hold up; this entry covers the TS + cleanup halves + the overall gap ranking.
- **`family-rating-recompute.test.ts` (BUT-1592) — genuinely proves its intent.** It tests the pure decision function `shouldRecomputeOnFamilyRatingUpdate(before, after)` directly: demotion `profile→user` stars-unchanged now asserts `true`, and the new `user→guest` case asserts `false`. Both red on the pre-fix `if(!isProfileRating(after)) return false` gate (demotion returned false). Pure-function-of-the-contract test — the right shape, would fail on a real regression. **Residual gap (thin, acceptable):** proves only the GATE, not the trigger wiring (`onFamilyRatingUpdated` actually invoking recompute when the gate says true). The `functions/src/index.ts:312` stale comment (BUT-1596) confirms the wiring side is only comment-audited, not test-covered.
- **`detect-lapsed-users.test.ts` (BUT-1567) — the 4 new integration cases are strong.** They drive the real `runDetectLapsedUsers` against a hand-rolled fake db and each straddles the fix: "irregular user caught after skipped run" reds if the window reverts to the ±12h point-in-time band; "already past thresholds NOT re-notified" pins the exclusive lower bound (`>`); "first run bounded lookback" pins `DEFAULT_CURSOR_LOOKBACK_MS`; "cursor persisted" pins the post-run `set(lastRunAt)`. Would catch a real regression. **Watch-item:** the fake db's `>`/`<=` window logic and the new cursor `get`/`set(merge)` were hand-authored IN this commit — the test partly grades its own fake. The window is a single-field range (`lastActiveAt >`,`<=`) so no composite index risk, but "the fake matches real Firestore range semantics" is asserted by construction, not proven. Acceptable for a pure-JS module test lane.
- **`cleanup-old-notifications.ts` drain loop (BUT-1563) — NO test, and BUT-1595 is NOT the whole gap.** Two untested surfaces, ranked:
  1. **(High) the `for(;;)` drain loop itself (BUT-1595 as filed).** The break is `snapshot.size < BATCH_LIMIT`. If `batchDeleteDocs` ever returns without actually removing rows (partial-batch failure, permission edge), the next query re-returns a full page and the loop spins forever — an unbounded-read/timeout risk that only a test with a fake that deletes < requested can expose. Also untested: the multi-page happy path (2+ full pages fully drained) and the empty-collection fast-exit.
  2. **(Medium, NOT filed) the new `(status, sentAt)` composite index for social-requests cleanup.** The cleanup query filters `status ==` + ranges `sentAt <` — that needs the composite that was added to `firestore.indexes.json` in the SAME commit. Per the standing Firebase lesson (fakes can't catch a missing composite), the guard is a test asserting the declared index config exists, not an in-memory run. No such assertion was added. If the index line is ever dropped, nothing reds until prod throws `FAILED_PRECONDITION`.
- **Salvage verdict / gap ranking (most to least important):**
  1. cleanup drain-loop behavioural test — infinite-loop-on-failed-delete + multi-page drain (BUT-1595, but scope it to include the failed-delete guard, not just "a test exists").
  2. `(status,sentAt)` composite-index config assertion test (unfiled — recommend a BUT ticket; it's the exact class the Firebase lesson exists for).
  3. import THROW path logs no parse event (BUT-1597, already filed) — asymmetric undercount vs the URL reference path.
  4. import `autoImport` fallback-loop logging count — N attempts emit N events; "#events != #user-imports" is unpinned (noted in the BUT-1470 entry above).
  5. family-rating + lapsed-users trigger/wiring (thin, gate logic itself is covered).
  So BUT-1595 is the top gap but explicitly NOT the only one — the composite-index assertion (#2) and the throw-path (#3) are real and the index one is currently unfiled.

### 2026-07-12 — Spoken-register golden review (menu parser, kb-whisper plan)
**Trigger:** reviewing `test/unit/services/menu/parser/spoken_prompt_golden_test.dart` (v1, 27 cases).
- **Correction tests must assert the LOSER is absent, not just the winner present.** For "X nej Y" last-wins cases, asserting `dietary contains Y` stays green if the correction pass silently dies: the unresolved marker is a clause-parser stop word, so BOTH X and Y get consumed as modifiers and the winner is still present. Assert the aggregate constraint set EQUALS the expected set.
- **Phrase-repetition correction is the big spoken shape the regex misses.** Speakers repeat the noun ("Tre middagar. Nej, fyra middagar.") and Whisper punctuates it into sentences → clause split → slots MERGE → 3+4=7 middagar, silently. The value-adjacent-to-marker regex (`tre nej fyra`) can't see it. Probe-verified 2026-07-12; golden sets for spoken text need a cross-clause repetition case even if skipped-with-ticket in v1.
- **Trace hygiene claims in production comments need a test.** `clause_parser` added nej/förlåt/vänta/ursäkta to `_stopWords` explicitly "so stray markers don't pollute the not-understood trace" — nothing asserted it; reverting the stop words keeps all 188 tests green.
- Probe pattern that worked: temp `_probe_review_test.dart` printing slot totals + `trace.notUnderstood` + the intermediate string after each spoken pass — cheap way to ground-truth "would this test catch X" claims before filing them.

### 2026-07-12 — dispose-cancel tests are confounded by an isDisposed early-return guard
Trigger: commit-gate review of BUT-1461 Gap 2 (live family-rating breakdown VM).
A "dispose cancels the subscription" test that only asserts a state value (e.g.
`vm.familyCount` frozen after a late write) does NOT prove the subscription was
cancelled if the VM's stream callback already opens with `if (isDisposed) return;`
(and `BaseViewModel.notifyListeners()` is itself disposed-guarded). Removing
`_subscription?.cancel()` from `dispose()` leaves the state frozen anyway — the
guard catches the late emission — so the test stays green while a real subscription
leak ships. The test is still SOUND for its user-visible contract (no stale update /
no crash after dispose), but its title over-claims. Verdict on that review: NON-blocking
(the leak is an implementation detail; per DO-NOT-WRITE we don't assert on the
subscription object). If you genuinely need to prove cancellation, you can't do it
cleanly through state — both defenses converge on the same observable, and asserting
on the private `StreamSubscription` is exactly the topology test we avoid. Flag the
title/intent mismatch, accept the test.
Companion sound-test pattern (same review): a live-vs-one-shot test IS decisive when
it (a) starts the listener on an EMPTY collection, asserts count 0, then (b) writes a
row AFTER `startListening()` returns and asserts count 1 — a one-shot `getForRecipe`
at start would read 0 and never see the later write, so it fails. And a membership-gate
repo test is decisive only when the member control asserts a NON-empty result on the
SAME query the stranger sees empty (isEmpty alone is satisfiable by mere data absence;
the member's `hasLength(2)` is what proves the gate discriminates on membership).
`pumpEventQueue()` (20 delayed-zero rounds) is ample to flush fake_cloud_firestore
snapshot propagation through repo→service→VM stream hops — no flakiness concern.

### 2026-07-12 — kb-whisper voice test review: 6 pinning tests verified by revert-probe; one was vacuous [Bug found in a test + pattern]
Trigger: reviewing the 6 regression tests added for the kb-whisper cross-file review fixes (voice_capture_service_test, whisper_model_manager_test, voice_prompt_button_test, text_normalizer_test, spoken_prompt_golden_test).
- **5 of 6 genuinely straddle their fix** (verified by reading the production diff, not trust): relocated-stop-path test asserts BOTH files deleted + `seenAudioPath == altPath` (fails if the `stoppedPath` finally-delete regresses); throttle test counts `storage.ref()` calls via a delegating `_CountingStorage extends Fake` — regressing `abortCheck()`→`endCheck()` makes attempt 2 short-circuit before any ref → `greaterThan` fails (endCheck stamps `_lastCheckTime`; abortCheck only clears `_checking`); stop-stays-tappable flips `enabled` via ValueNotifier mid-recording and asserts `IconButton.onPressed isNotNull` (fails on `widget.enabled ? _onTap : null`); mixed digit/word + plural→singular each have a normalizer unit test AND a golden case, with adjacent guard tests pinning the non-firing directions (trevliga≠tre, dagar≠veckor, råtta≠åtta).
- **The 6th (clause_parser stop-word trace hygiene) was VACUOUS — proved by probe + revert.** All 34 golden transcripts consumed their correction marker in `resolveSelfCorrections` BEFORE clause parsing, so the noiseWords⊆notUnderstood assertion never exercised `_stopWords`; reverting the nej/förlåt/ursäkta addition kept everything green. Fixed by adding `_Case('Tre middagar nej.', 'middag', 3)` — an UNRESOLVED marker (retraction with no replacement) inside a slot-bearing clause. Revert-run confirmed it is the only red (exact reason string), restore confirmed green. **Pattern: an aggregate hygiene assertion over N cases pins nothing unless ≥1 case actually routes the guarded token to the guarded code path — enumerate which case exercises which pass.**
- **Cheap revert-probe recipe on uncommitted work:** `cp` the production file to the scratchpad, `python` string-replace the fix out, run the ONE suite, `cp` back + `cmp` for byte-identical restore. Grounds "would fail if the fix regressed" in an observation instead of an argument.
- **Residual production gap (non-blocking, reported up):** clause_parser line ~99 `if (rest.isNotEmpty) notUnderstood.add(clause)` bypasses `_stopWords` for a LONE-marker clause — `'Tre middagar, nej.'` (comma) still yields `notUnderstood=[nej]` despite the fix's comment claiming stray markers can't pollute the trace. Slot/count unaffected; UX-copy blemish only. The comma-less golden case pins the covered path; the comma path needs a production filter if ever deemed worth it.
- **Trace-hygiene assertion IS load-bearing for fillers even without markers:** a no-op `stripSpokenFillers` leaks 'alltså'/'typ'/'liksom' (≥3 chars) into notUnderstood via the lone-clause path, and 2-char fillers ('eh','öh','mm') via the whole-clause add at line 99 — while count assertions alone would stay green (the correction pass still fires around unstripped fillers).
- **No test pins tools/ci/check_model_versions.py's PREPUBLISH_FAMILIES tolerance** (missing latest_version.txt → OK only pre-publish, loud failure for published families). tools/ci has no test harness at all; the guard's registry parser was smoke-run by hand against the real Dart file (whisper→1 parsed). Judged non-blocking dev tooling; recommend a ticket if the guard grows again.

### 2026-07-12 — FFI-boundary literal workarounds get a forensic comment, not a mirror test
Trigger: judging test proportionality for the `vadModelPath: ''` one-liner in `lib/services/voice/whisper_transcriber_ffi.dart` (fixes nlohmann type_error.302 native crash, verified on-device Pixel 9a).
- **Decision rule:** when a fix is a literal argument whose necessity lives on the far side of an FFI/native boundary, and the class IS the adapter behind the seam unit tests fake, no automated test is proportionate. The only assertable claim ("request built with X") mirrors the line, requires injecting the 3rd-party object purely for the test, breaks when the upstream plugin fixes the root cause (harmless refactor), and stays green if the plugin changes so the sentinel stops working (real regression). Wrong on both refactor-survival axes.
- **The honest coverage** = on-device verification (done, dated) + a comment carrying the reproduction recipe: exact native error type, user-visible symptom string, device, date. Judge these by whether the comment lets a future session safely evaluate removing the workaround.
- Contrast with the seam side: everything ABOVE `WhisperTranscriber` stays fake-tested as usual — this rule only covers the thin adapter whose entire body is the third-party call.

### 2026-07-12 — Live-listener ViewModel: prove re-emission + roster/count invariant (BUT-1461 Gap 2)
Trigger: review of a VM that moved from one-shot `load()` to a live Firestore listener
(`FamilyRatingBreakdownViewModel.startListening`).
Two assertions that actually gate the regression, both run through the REAL repo+service
stack over `FakeFirebaseFirestore` (FakeFirebaseFirestore DOES re-emit on snapshot writes,
so live behaviour is genuinely testable without the emulator):
1. **Re-emission proof:** startListening on an empty recipe (count 0) → write a rating AFTER
   listening starts → `pumpEventQueue()` → assert count/rows reflect it. Fails under a
   one-shot read (old `load()` would stay at 0). Don't mock the stream — a mock re-emit
   proves nothing about the production listener.
2. **Roster/count consistency invariant:** the summary count comes from the full rating set
   (denormalised, matches the card pill) but rows = roster ∩ raters. If the roster is cached
   once at open instead of re-read per rating-bearing emission, a member added mid-view yields
   count=2 / rows.length=1 (phantom "2 betyg" over one row). Assert `familyCount == rows.length`
   as the guard — it fails precisely under the cached-once bug. Stronger than asserting the two
   literal values because it encodes the invariant, not the scenario.
Accepted-by-inspection (agreed, not a blocking gap): the concurrent-emission `_generation`
stale-drop race and the transient-error-on-already-populated-section path (keeps last-known
rows) — both need nondeterministic interleaving to trigger. Live star-change/retraction reuse
the same emission handler as add, so no separate test earns its keep.

### 2026-07-13 — Voice-import final gate: 6 revert-probes in one batch; 3 gaps closed (cap-path WAV leak, unlimited-voice quota, widget auto-stop sync) [Pattern + gaps closed — reviewed]
Trigger: final gate review of the six voice-import suites (assembler / strategy / VM / capture service / view / prompt button) pinning the 10 /code-review fixes.
- **Batched revert-probe works and is cheap: apply ALL candidate regressions at once (5 here, across 4 production files), run every suite in ONE flutter test invocation, attribute each red by its failure line.** Attribution stays clean as long as each pinning test fails at an assertion unique to its probe (the dispose test reds at `verifyNever` before ever reaching the callback-probe code path). Probes that share a file/behavior (cap timer stops recorder vs stopAndTranscribe prefers capStoppedPath) must run in SEPARATE batches — under "timer doesn't stop", the relocated-cap test goes green because stopAndTranscribe's re-stop becomes the first recorder.stop() call and legitimately gets the relocated path. Verified all 6 probes bite: decimal-comma regex, per-capture callback (fails as a null-cast on `captured.single as void Function()` — a cast failure is a valid bite), ownership-guarded dispose (bites BOTH directions: always-cancel fails verifyNever, never-cancel fails called(1)), capStopped??stop, view listener removal, timer-only-fires-callback.
- **Gap pattern: a cap/auto-stop branch duplicates a privacy contract the manual branch already pins — re-pin it on the new branch.** The manual-stop suite had the relocated-recorder-path test (2026-07-12 entry), but the NEW cap path stores the recorder-returned path in `_capStoppedPath`; regressing `capStopped ?? await _recorder.stop()` to a plain re-stop() transcribes the wrong file AND leaks the relocated WAV — invisible to every existing test because the stub returned null. The observable stub: a COUNTER (`++stopCalls == 1 ? altPath : null`) modeling "second stop of an already-stopped recorder returns null"; then assert seenAudioPath == altPath + both files deleted. Probe-verified.
- **Gap pattern: check every behavioral review-fix has a pin, not just the ones the author listed.** Finding #6 ("unlimited voice imports" — success must recordUsage or checkLimit is inert) had zero coverage. Pin: `_RecordingRateLimiter extends Fake` (checkLimit → allowed, recordUsage captures ops) registered in GetIt + `app_provider.ServiceLocator.reset(); initialize(DIContainer())` (the import_manager_test BUT-1460 harness), assert success records exactly one `basic('voice')` op and a failed parse records none.
- **Widget-level auto-stop sync test earns its place even when the manual-stop test transitively covers the same listener.** In voice_import_view, `_onMicTap` deliberately does NOT write the controller — `_syncControllersFromVm` reconciles both stop kinds — so today the manual test exercises the listener. But the exact finding-#1 regression shape (reintroduce a manual controller write, drop the listener) keeps the manual test green while an auto-stopped dictation becomes invisible. The fake captures `onAutoStopped` from startRecording and the test fires it with NO tap, asserting the transcript text is findable + stop control gone + all three mics back (mic coexists with the done check — review finding #5). Probe (listener removal) reds it.
- **Mid-review external edit note:** production `voice_capture_service.dart` gained a race-hardening (re-check `_activeRecordingPath != path` AFTER the timer's await, local `capStopped` before committing to the field) between first read and probe time — take probe backups (cp to scratchpad) IMMEDIATELY before editing, and byte-verify restores with `cmp`, so a parallel session's edit is preserved instead of clobbered.

### 2026-07-13 — Köksbutlern final gate: 3 gaps closed (stale heard-chip, single-flight double-tap, disposed-mid-start orphan), verified by one 3-probe batch [Gaps closed — reviewed]
Trigger: final gate review of the four Köksbutlern suites (tts_service / cooking_command_interpreter / cooking_voice_controller / voice_assist_button) pinning the 10 /code-review fixes.
- **"Chip shows for X" + "chip absent before anything happens" together still don't pin "chip CLEARS on Y".** Both the controller test (`lastHeard == 'Blubb.'` after a miss) and the widget test (chip renders after an Unrecognized cycle, absent initially) were green with the `_lastHeard = null;` success-clear deleted — the exact finding-#9 regression (stale "Hörde:" chip forever). A set/clear pair is TWO behaviors; the clear needs its own test with a meaningful precondition (miss first, so lastHeard is provably non-null before the success). Probe-verified.
- **A dispose-mid-listen test does NOT cover dispose-mid-START — they cancel from different code.** Mid-listen: `dispose()` itself sees state==listening and cancels. Mid-start: state is still idle at dispose time (state flips only after `startRecording` resumes), so dispose cancels nothing — only the resuming `_beginListening`'s `if (_isDisposed)` re-check can abandon the orphan. The existing lifecycle test kept the finding-#3 fix invisible. Same holdStart-Completer fake gate serves both new tests: park `startRecording` before returning true, then dispose (or double-press) inside the gap, then complete.
- **Single-flight guard test shape:** `holdStart` gate → two un-awaited `onMicPressed()` → complete → `Future.wait` → assert `starts == 1` + state listening. Without the Completer it still bites (await on a completed future suspends), but the held start makes the race window explicit and robust to fake changes.
- **3-probe batch attribution stayed clean** (per the 2026-07-13 voice-import entry): heard-chip probe reds at `'Blubb.' != null`, guard probe at `starts 2 != 1`, disposed probe at `cancels 0 != 1`; all 15 other tests green under all three probes simultaneously. Backup + byte-identical restore via cmp.
- Also verified by read (no probe needed, non-vacuous by construction): the rewritten barge-in test asserts `stops == 0` immediately before a press that provably lands mid-held-speech (`state == speaking`) and `stops == 1` after — the old vacuous monotonic-counter shape is gone; and the 9 new duration golden pins (compound-half incl. halvannan, decimal-comma `1,5 timme`, summed `en timme och trettio minuter`) each assert the exact Duration, which reds on the shadow/five-hour/first-fragment-only regressions.

### 2026-07-14 — Voice-consolidation Phase 1 review (VersionedModelManager de-triplication) [Pattern + 2 gaps closed — reviewed]
Trigger: coverage review of the model-manager base-class refactor (NER/LC/whisper → `VersionedModelManager`) + clause-parser trace hygiene + failure-copy split.
- **"Refactor proven by unmodified suites" only proves the branches those suites reach.** The 4 fail-close suites passing byte-for-byte pins every REFUSAL branch, but the SUCCESS install path (verified bytes → disk, sidecar writes, version.txt-last) had ZERO executions anywhere — production registries hold real-model hashes, so no staged bytes can ever pass verification. The refactor itself created the seam that makes it testable: `hashRegistry` became an overridable hook, so a test subclass can register `sha256(stagedBytes)` and drive a full install. Added to `versioned_model_manager_hooks_test.dart`: registered-matching-hash install asserting byte-identical cached model (bytes written == bytes hashed — the integrity half of the TransferableTypedData change), sidecar content in the result, version.txt == staged version, no surviving .tmp, AND a fresh-manager cache-hit round trip. **Rule: when a rewrite is gated on "old suites unmodified", enumerate which branches those suites execute — the branch they structurally CANNOT reach (here: happy path) is where the rewrite ships untested.**
- **A copy-SPLIT needs a discriminating assertion on BOTH halves.** New `voiceUnavailable` and old `voicePromptFailed` share the suffix "Det går bra att skriva i stället"; the transcription-miss test asserted only the shared substring, so collapsing the miss path onto the new string stayed green. Tightened with `find.textContaining('kunde inte tolkas')` — when two strings share copy, pick the substring unique to each path.
- **TransferableTypedData round-trip risk is covered transitively by an unmodified suite**: `remote_weight_loader_integrity_test`'s "matching hash loads the parser" drives fromList → isolate materialize → verified-bytes return → `CrfWeights.fromJson(utf8.decode(verified))` — wrong/garbage bytes red it. Worth knowing before demanding a dedicated test.
- **Vocab-sidecar hook test is partially self-guarding via types**: if the base silently dropped NER's sidecar list, `sidecarContents['vocab.txt']!` throws inside `_tryLoadCached`'s catch → null → the missing-vocab test stays green by crash-to-null. The user-visible contract (never a vocab-less model) still holds, so the test is acceptable; the happy-path install test now covers the sidecar's positive direction.
- Accepted (non-blocking, reported up): cooking-mode's `voiceAssistUnavailable` arm (the bare string WITHOUT the typing pointer — there's no text field in cooking mode) is a one-line string swap in a view with no widget test; views are journey-test territory (BUT-387) and the two text-field surfaces pin the split. Also unpinned: `_hasReportableToken`'s digit-only clause filtering (no golden case routes a bare-digit clause to the trace).

### 2026-07-14 — Voice-consolidation Phase 2 gate (search mic REC-16 + comment mic SOC-19): GlobalKey-survival test added + copy-override gap closed [Gaps closed — reviewed]
Trigger: final gate review of the Phase 2 diff (VoicePromptButton moved to widgets/voice with startTooltip/rationaleTitle/rationaleBody/compact params; mics added to SearchFilterWidget + CommentFormWidget).
- **A GlobalKey keep-alive fix IS widget-testable, cheaply.** SearchInputWidget's suffix flips between `trailing` and `Row[clear, trailing]` on the empty↔non-empty text flip; without `key: _voiceButtonKey` the mic State is recreated mid-recording and its dispose() cancels the capture. Test shape: start recording → `tester.enterText` mid-recording → assert stop icon persists AND `fake.cancelCalls == 0` → complete the stop and assert the transcript still lands. Probe (key removed) reds it at the missing stop icon; both assertions discriminate. This is a BEHAVIOUR test (recording silently dying when you touch the field), not a topology test — the GlobalKey itself is never asserted.
- **Optional-override params with l10n defaults need a discriminating override test — the default-path test is structurally blind to the `??` plumbing.** The existing rationale test asserted 'skickas aldrig vidare', a substring shared by BOTH the menu-specific and new generic body, so deleting all three `widget.x ?? default` overrides stayed green. Same lesson family as Phase 1's copy-SPLIT: assert (a) arbitrary injected strings render (tooltip + dialog title + body), (b) `find.textContaining('veckomeny')` findsNothing so the default provably did NOT leak. Plus a one-line `find.byTooltip('Tala in din sökning'/'Tala in en kommentar')` per surface pins that each call site wired its OWN copy (the DPO wrong-purpose-dialog risk lives at the call site, not the widget).
- **Two-probe batch attribution stayed clean** (GlobalKey probe + override probe simultaneously, 4 reds each at a unique assertion, 39 others green). Backup→python string-replace→run→cp back→`cmp` byte-identical, per the 2026-07-12 recipe.
- Verified by read (no probe needed): the mid-post transcript-survival test's `find.text('och lite till')` cannot pass under the old unconditional `_controller.clear()` — the gated Completers land the transcript strictly before postComment resolves. Conscious skips: `compact` (VisualDensity — design tweak), view-level wiring (mina_recept `enableVoiceInput: true`, rationaleBody key swaps in cooking/voice-import views — journey territory per BUT-387), `MockVoiceCaptureService` TestServiceLocator registration (proven by the pre-existing comment-form suite passing with a mic now in the tree).

### 2026-07-14 — Voice-consolidation Phase 3 gate (Köksbutlern Q&A, COOK-14): 1 gap closed — the "SCALED line" claim was blind at scale 1.0 [Gap closed — reviewed]
Trigger: coverage review of the Q&A diff (SubstitutionQuery/QuantityQuery/GoToStep frames, controller arms, ratio speech, stemming).
- **A "portion-scaled answer" test run at the DEFAULT scale proves nothing about scaling — at factor 1.0, `scaledIngredients` is byte-identical to `recipe.ingredients`, so regressing the lookup to the raw list keeps every test green.** The test even claimed "SCALED line" in its title (same title-over-claims family as the 2026-07-12 dispose entry). Fix shape: `cookingVm.updatePortions(8)` (base 4 → factor 2.0), premise-assert the VM really rescaled the milk line (`isNot(contains('2 dl'))` — guards vacuousness if the string-fallback scaler ever stops scaling factory recipes), then assert the spoken answer contains the premise-derived scaled line AND `isNot(contains('2 dl mjölk'))`. Deriving the expected line from the VM keeps it robust to scaler formatting while still discriminating. Probe (`_cookingVm.scaledIngredients` → `_cookingVm.recipe.ingredients` in `_matchingIngredientLines`) reds exactly the new test at `Expected: contains '4 dl mjölk' / Actual: '2 dl mjölk'`; all 27 siblings green under the probe. **Rule: any "answers from the scaled/filtered/derived list" claim needs one test where that list provably DIFFERS from its source — equality at the default configuration is structural blindness.**
- Everything else judged adequate by read (no probe needed — each pin asserts an exact output string only the fixed code produces, and routing is proven by `as SubstitutionQuery` casts): stacked-tail strip, 'hur många ingredienser' readout precedence, compound per-part miss, decimal-comma ratio, raw-span pass-through (`substitutions.asked == ['grädde']`), 1:1 no-qualifier via `isNot(contains('youghurt, '))`-style discriminator, definite-form stemming (direct-miss→stem-hit is the only green path), out-of-range step, honest no-span. Swedish l10n additions are pinned behaviorally (controller tests assert the sv strings verbatim).
- **Accepted without tests (consciously):** the case-arm `if (_isDisposed) return;` after `suggestFor` is double-covered by `_speakThenWindow`'s own disposed guard — per the 2026-07-12 confounded-dispose entry, the two defenses converge on one observable, so no discriminating test exists; `lines.take(2)` verbosity cap + substring multi-match (design detail); quantity frame 2's greedy `(.+)$` catching never-owned utterances ('hur många steg är det' → honest miss, previously Unrecognized — not a regression); view wiring line (journey territory per BUT-387; `SubstitutionSuggestionService` DI registration pre-exists in content_module for the substitution sheet).

### 2026-07-14 — ImportManager parse-event exception path (BUT-1597): negative-assertion test could pass for the wrong reason [Pattern discovered, strengthened]
Trigger: review of `test/unit/services/import/import_manager_parse_event_exception_test.dart` + `lib/services/import/import_manager.dart` (import sprint).
- **A test whose whole point is a NEGATIVE assertion (`spyLogger.events, isEmpty`) is vacuous unless it also proves the guarded code path was actually reached.** The "URL strategy throws → manager must NOT log (it self-logs per-tier)" test asserted only `isSuccess isFalse` + empty events. But `importWithStrategy` returns `isSuccess=false` with an EMPTY log for BOTH the real path (found the strategy, `import()` threw, `strategy is! UrlImportStrategy` skip fired) AND a strategy-not-found miss (`'Strategy not found: URL Import'`, never invokes import). A `strategyName` drift from `'URL Import'` would silently convert the test into the second case and it stays green while proving nothing. Fix: assert `result.errorMessage, contains('Parse execution error')` — that string is produced ONLY by the catch block in `_parseWithStrategy` (line ~800), so it pins that `import()` was invoked and threw. **Rule: every "X does NOT happen" test needs a companion positive assertion that the code reached the point where X could have happened; distinguish the intended path from every other path that produces the same negative observable.** Same title-over-claims family as prior entries. Both tests pass after the edit.
- **Non-bug verified (defensive-guard, not reachable):** `_parseWithStrategy` logs a parse event on the return path (`_logParseEvent`, line ~730) AND again in its `catch` (line ~793). A successful parse whose downstream preview-tagging threw between them would double-log (success then success=false) AND discard the parsed recipe. But `TaggingService.generatePhase1Preview` catches everything internally and returns null (never throws), and the `_taggingService` getter is null-safe — so the window between the two logs cannot throw in practice. No live double-count. Left as-is; noted so a future change to `generatePhase1Preview`'s error contract (letting it throw) reopens the double-log + recipe-discard risk.
- **`_SpyParseEventLogger extends ParseEventLogger` with an `@override logEvent` body is a legitimate subclass spy, NOT the banned "Mock with @override body" anti-pattern** — it's a real class capturing calls in a list, never driven by `when()`. Fine as written. (The ban is specifically about `class X extends Mock` bodies silently blocking `when()`.)

### 2026-07-14 — [trigger: reviewing model equality tests] Equality-by-id tests must assert the NEGATIVE case
weekly_menu_plan_test.dart's `equality is by id` only asserted `a == a.copyWith(...)`.
That passes even if `operator ==` regressed to `=> true`. An equality test that omits an
unequal pair (different id) and a hashCode check proves nothing about discrimination.
Rule: any `operator ==`/hashCode test must include (a) equal pair → equal + same hashCode,
(b) a deliberately-unequal instance → `isFalse`. Same shape applies to WeeklyMenuPlanEntry
(id-keyed) and anywhere `==` is used for list membership/removal.

### 2026-07-14 — Import correction-snapshot cache collides on text/photo shared sourceUrl key
Trigger: reviewing lib/services/import/{text,photo,url}_import_strategy.dart.
`ParsedRecipeCache` is keyed by `recipe.sourceUrl` and one-time-read (removes on retrieve,
30-min TTL, LRU-50). URL imports key by the real unique URL — fine. But BUT-1469 extended
correction-snapshot caching to text + photo imports, and **both** carry the constant
placeholder sourceUrl `AppLocale.current.textImportSourceUrl` ("Importerat från text").
Photo inherits it too (photo re-homes only `sourceArtefact`, never `sourceUrl`). So every
text AND photo import writes/reads the SAME cache key. RecipeFormViewModel retrieves by
`initialRecipe.sourceUrl` (gated on isTemplate:true, which imports always pass — verified in
import_result_handler.dart:210). Two text/photo imports within 30 min before saving the first
→ the first-saved recipe's correction diff runs against the SECOND import's snapshot → wrong
baseline → corrupted parser-training data (the USP learning loop). Not a crash; silent data
corruption. A single-import flow works, so a naive test won't catch it.
Test to write (would fail today): import text recipe A, import text recipe B, then
`cache.retrieve(textImportSourceUrl)` and assert it is A's snapshot — currently returns B's.
Better: assert the two snapshots are cached under distinct keys. Fix belongs in production
(key text/photo snapshots by recipe.id, or give text imports a unique sourceUrl), not in the
test. Do NOT weaken to "last-write-wins is fine".

### 2026-07-14 — Seafood-safety lockstep test pins only 2 of the 3 vocab copies it claims [Gap found — reviewed]
Trigger: tagging-register sprint review of tag_phase1_seafood_safety_test.dart + property_registry.dart + Butlery_Ingredients_PROPERTIES.csv (BUT-1498 shellfish/wheat reconciliation).
- The `property-vocabulary lockstep` group's own comment (lines 166-176) claims "Three hand-maintained copies exist: PROPERTIES.csv, sync-ingredients-core.ts VALID_PROPERTIES, and Dart PropertyRegistry ... ANY new divergence fails here." But the test only asserts **TS ↔ Dart**. The CSV is never read. It was edited this sprint (68 line churn) and nothing guards it. Concretely CSV == TS exactly in this snapshot (both omit `raw-safe`, both carry `processed`), so the missing third leg would reuse the same `knownDartOnly={raw-safe}`/`knownTsOnly={processed}` split. A CSV edit (Sheet vocabulary snapshot) that renames/adds a property without touching the registry passes silently → an ingredient could carry a property the config gate never validates → a wrong FREE allergen verdict, the exact failure this suite exists to prevent. Fix: add a `csvProperties()` reader (parse col-0 ids, skip header) and assert `csv.difference(dart) == knownCsvOnly` / `dart.difference(csv) == knownDartOnly`.
- Secondary: the `every allergen/dietary trigger property passes both gates` test iterates allergen `triggerProperties` + dietary `excludedProperties` but **omits dietary `requiredProperties`** (pescetarian's `['fish','crustacean','mollusc']`). Production `PropertyRegistry.validateAllConfigs` DOES check required props. A Dart-only required prop (e.g. `raw-safe`) would pass the Dart gate but be unsuppliable by the Sheet/TS and this test wouldn't catch it. Add `...d.requiredProperties ?? const []` to the `used` set.
- Non-bug verified: firebase_ingredient_repository.dart's stale-while-revalidate + BUT-1331 offline-degrade + BUT-1498 collision logging are all correctly guarded (single-threaded coalescing via `_inFlightLoad`; `_cacheLoadedAt` set only after a successful `.get()`). No new correctness issue in the repo file.

### 2026-07-14 — DinerProfile.dislikedIngredients: JSON-cache + copyWith legs were untested [Gap closed — reviewed]
Trigger: BUT-1610 family sprint adding a soft `dislikedIngredients` Set<String> to DinerProfile + HouseholdRosterMember, wired through MinFamiljViewModel.saveFamilyMember(dislikedKeys:) and the family form. Reviewed diner_profile.dart / household_roster_member.dart / min_familj_viewmodel.dart / family_member_form_view.dart / the 5 l10n files / diner_profile_test.dart.
- No production correctness bug: field is symmetric (toFirestore omits when empty, fromMap/fromJson via `_parseStringSet`), copyWith uses `?? this.dislikedIngredients` (non-nullable, empty set is the cleared state so no sentinel needed), and withdrawAllergenConsent correctly does NOT touch dislikes. Dislikes are ordinary personal data → no Art. 9 consent gate, which is right.
- The new sprint tests only covered the **Firestore** path (omit-when-empty + adult round-trip). Two legs the VM edit path actually depends on were unguarded: (a) the **JSON cache** path — toJson ALWAYS emits `dislikedIngredients` (unlike toFirestore), and `fromJson`→`_parseStringSet` had zero coverage; a regression would silently drop dislikes from cached profiles. (b) **copyWith(dislikedIngredients:)** replace/clear + omit-preserve — the form's edit path is `existing.copyWith(dislikedIngredients: dislikes)`, so both "empty set clears" and "omitted arg preserves" are load-bearing. Added a `Disliked ingredients` copyWith group + a JSON-cache round-trip test to diner_profile_test.dart (17 pass, analyze clean).
- Remaining gaps flagged (not written — outside the in-scope test file): `HouseholdRosterMember.fromDinerProfile` carrying dislikes has NO test file at all; MinFamiljViewModel.saveFamilyMember has no test that dislikedKeys reach the persisted profile nor that they survive an allergen-consent withdrawal (the withdraw-must-not-drop-dislikes invariant). Pattern: when a sprint adds a field with THREE serialization surfaces (Firestore/JSON-cache/copyWith), a test that only hits one surface leaves the read-model + cache paths open.

### 2026-07-15 — Seafood-safety lockstep: CSV leg + requiredProperties gaps CLOSED [gap fixed — reviewed]
Trigger: BUT-1498 commit-gate review of tag_phase1_seafood_safety_test.dart (retire bare 'wheat', add 'shellfish'; valid_properties.dart as single source of truth). Two gaps flagged in the 2026-07-14 review of this same file were still unfixed and are the ticket's actual purpose, so closed them in-place:
- Added `csvProperties()` reader (parses col-0 ids of docs/tagging/data/Butlery_Ingredients_PROPERTIES.csv, skips header) + a `csv ↔ dart` divergence assertion. The suite now pins all THREE copies pairwise, not just TS↔Dart. Verified CSV==TS exactly in this snapshot (both carry `processed`, omit `raw-safe`; both omit `wheat`, carry `shellfish`), so `knownCsvOnly={processed}`, `dart.difference(csv)={raw-safe}`. A Sheet-side revival of bare `wheat` now fails here instead of only being caught downstream at the TS sync gate.
- Folded dietary `requiredProperties` into the `used` set of the "every trigger property passes both gates" test (pescetarian requires fish/crustacean/mollusc; production validateAllConfigs checks them). `FirebaseDietaryEntry.requiredProperties` is non-nullable List<String>, all three in both gates → passes.

### 2026-07-16 — BUT-1500 dead-Algolia-router removal: deleting a test is safe when the surviving passthrough was already the FALLBACK branch [Pattern — reviewed, safe-to-commit]
Trigger: commit-gate review of BUT-1500, which deletes `lib/services/search/recipe_search_router.dart` + its 454-line test, drops the router's DI registration in search_module.dart, and collapses `RecipeServiceAdapter.searchRecipes` from `ServiceLocator.tryGet<RecipeSearchRouter>() ?? _recipeRepository.searchRecipes` to just the direct repo call.
- **A deleted-test is provably safe when (a) grep confirms nothing else references the deleted subject and (b) the surviving code path was ALREADY the branch existing tests exercised.** Grepped `test/` and `lib/` for `RecipeSearchRouter`/`recipe_search_router` → zero hits after deletion. The adapter's collapsed path is not newly-untested: `recipe_service_adapter_test.dart` (lines ~240/256) already covered `adapter.searchRecipes` happy + failure paths, and because `TestServiceLocator` never registered a `RecipeSearchRouter`, `tryGet` returned null there — so those tests were ALWAYS driving the direct-repo fallback that is now the only path. No live coverage lost; the deleted 454-line suite only exercised the never-in-production router.
- **The algolia_search_repository_test.dart edit is description-only, verified by diff not by trust:** the `git diff` touched exactly the `test(...)` name string and the `reason:` narrative (removing the `RecipeSearchRouter` name); `expect(repo.usesExternalSearch, isTrue)` is byte-identical. Ran the suite → 37/37 pass. Same discipline as any "only reworded" claim: read the diff hunk, confirm the assertion expression is untouched, then run it.
- Coverage-gap verdict: none. The router was dead (no production caller — live search is SearchService-local, covered by search_service_test.dart; the adapter passthrough stays covered). Safe to commit. `usesExternalSearch` intentionally kept on `SearchRepository` — its doc comment was reworded from "RecipeSearchRouter uses this" to "Callers use this", the flag still gates the 200-cap bypass decision for any future caller.
- Core BUT-1498 intent VERIFIED not tautological: wheat re-added to Dart → dart.difference(ts/csv) grows → FAILS; shellfish dropped from Dart → ts/csv.difference(dart) grows → FAILS. Both drift directions caught in every pair. 19 tests pass, analyze clean. Safe to commit.

### 2026-07-16 — VM memoization of a fail-closed service bool makes transient failures permanent (BUT-1609 review) [Pattern discovered]
Trigger: reviewed the minor-account badge slice (ReportService.isMinorAccount + ModeratorReviewViewModel._resolveMinorOwners).
Two durable lessons:
1. **A `Future<bool>` that collapses "confirmed false" and "read failed" into `false` must not be memoized by the caller.** `getCachedOrExecute` deliberately caches only non-null (success) results, so the service retries failures — but the VM's `_minorOwners[id] = isMinor` memo (guarded by `containsKey`) freezes an error-`false` for the whole session, silently defeating the service's retry design. When reviewing fail-closed booleans, trace WHO caches: if any layer memoizes the collapsed value, a transient failure becomes sticky. Fix shapes: `Future<bool?>` (null = unknown, don't memoize) or only memoize the non-default value.
2. **A conditional `notifyListeners()` optimization (`if (anyMinor) notifyListeners()`) is invisible to state-only assertions.** Tests asserting `vm.isMinorOwner(...) == true` stay green if the notify line is deleted — but the badge never repaints after the fail-closed initial render. When async resolution changes render output, the test must also count listener notifications (the render trigger IS the contract), same family as the executeDebounced 3-notification rule.
Also: new service method `isMinorAccount` shipped with zero service-level tests while its sibling file report_service_test.dart covers every other method against FakeFirebaseFirestore — check the sibling service test file for the new method, not just the VM test, when a slice adds one method per layer.

### 2026-07-16 — BUT-1519 ButleryBetygPill dedupe gate review: extraction safe by unmodified suites; unpinned doc-comment contract closed [Gap closed — reviewed]
Trigger: commit-gate review of the pooled-pill dedupe (card + detail copies → shared `lib/widgets/recipe/butlery_betyg_pill.dart`).
- **A widget extraction is proven by the host surfaces' unmodified behavioral suites** when both suites assert rendered text of the extracted visual (recipe_card_test.dart AC7 group + recipe_detail_metadata_pooled_pill_test.dart — 44/44 pass byte-identical). Same BUT-1500 rule family: the surviving path is the branch the tests already exercised. One live delta verified by read: detail's old copy used `stats.average!` (crash-on-null), the merged widget uses `?? 0` — strictly safer, unreachable anyway (meetsDisplayFloor guarantees non-null).
- **A doc-comment contract with no pin doesn't survive extraction on trust.** The pill documents "always one decimal (4,0), deliberately NOT formatFractional" but every test fed 4.3 — swapping `_fmt` for `formatFractional` (renders "4") stayed green. Added the sv-SE whole-number pin to recipe_card_test.dart: `PooledStats(average: 4.0)` → `find.textContaining('4,0')` + `'4.0'` findsNothing. 41/41 pass. Rule: when reviewing an extraction, grep the new widget's doc comments for "deliberately"/"always"/"never" claims and check each has a discriminating test.
- Pre-existing bug found while reading the host (filed, not fixed — outside the diff): `RecipeCard._hasAnyMetadata` (recipe_card.dart ~694) gates the detailed-layout metadata row but only checks mealType/portions/time/personal rating — a recipe with ONLY familyAverage / averageRating / matchPercent / floor-clearing pooledStats renders NO pills (the decision-9 community pill silently missing). Compact/grid layouts don't have the gate. Test that would fail today: detailed card, no time/portions/personal rating, pooledStats(count:12) → expect `find.textContaining('12 betyg')` findsOneWidget.
- Also noted: `_buildRatingPill` renders the personal star with a DOT (`toStringAsFixed(1)` at ~624/635) while every sibling pill uses the Swedish comma via `_fmt` — sv-SE locale inconsistency, pre-existing.

### 2026-07-16 — BUT-1618 vocabulary unification: partition test pins a real DropdownButton crash class [Pattern + gaps — reviewed]
Trigger: sprint review of valid_properties.dart (flat set → categorized map), property_registry.dart (const→final), personal_tag_rule_dialog.dart (shared vocabulary + retired-value flagged entry), l10n, property_registry_test.dart.
- **Real latent crash the diff fixes:** the old dialog hand-listed 'fish'/'crustacean'/'mollusc' in BOTH the Allergens and Seafood dropdown categories → two DropdownMenuItems with the same value → Flutter's "exactly one item with value" assertion crashed when editing a rule that stored one of those. The new `kIngredientPropertyCategories` partition + the `every valid property appears in exactly one category` test pins this at the DATA level — the right level, since the dialog now renders the map verbatim. Pattern: when a widget renders a shared vocabulary into a value-keyed control (Dropdown, Radio group), pin uniqueness in the vocabulary's own unit test, not in a widget test.
- **Gap left open (flagged, not written — dropdown rendering overflows the default test surface per rule_builder_sheet_test.dart's own header):** the NEW user-visible behavior — a retired stored value ('wheat') rendering as a flagged `rulePropertyRetired` entry instead of a blanked dropdown — has zero widget coverage, and `_categoryLabel`'s default branch silently shows a raw category id if a new category is added.
- **const→final mutability note:** deriving `kValidIngredientProperties` via collection-for makes it a plain mutable LinkedHashSet (was deeply-immutable const). A test doing `.add()` on it now pollutes global state across the suite. Recommend `Set.unmodifiable(...)` whenever a const vocabulary becomes derived-final.
- The `expect(all.toSet(), kValidIngredientProperties)` assert is tautological TODAY (flat set is derived from the same map) but is a legitimate pin against future de-derivation — do not flag it for deletion.

### 2026-07-16 — [Pattern discovered] Pre-edit snapshot no-noise invariant is a SYMMETRY contract (BUT-1469 review)
The correction feedback loop's "unedited save produces no correction" guarantee holds only
because BOTH sides of the diff use identical idioms — verify each leg when reviewing/testing
this area:
- **Same parser + same string form:** `PreEditSnapshotRecorder._synthesizeIngredient` stores
  `IngredientParser.parseIngredient(line).quantity.toString()` and `RecipeDiffCalculator
  ._compareIngredient` compares against the same `correctedParsed.quantity.toString()`.
  `RegexParseResult.quantity` is a NON-nullable double defaulting to 1.0 (verified in
  `lib/utils/text/ingredient_parser.dart`), so quantity-less lines ("salt") yield "1.0" on
  both sides. A future one-sided change to `?.toString()` breaks the guarantee silently —
  a quantity-less line belongs in the no-noise test.
- **Same empty-line filter:** the recorder drops `trim().isEmpty` ingredient lines; the form
  save does the same (`recipe_form_state.dart:749`) — this symmetry is what prevents phantom
  "added" corrections.
- **UI neutrality is confidence-arithmetic:** all-medium (0.7) never trips
  `ParsedRecipe.needsReview` (low/failed only) nor `fieldsNeedingImprovement` (<0.5), so the
  quality banner in `skriv_sjalv_recept_view.dart:422` stays hidden for synthetic snapshots.
  Pin via `snapshot.needsReview == false` + `fieldsNeedingImprovement.isEmpty`, not via widget
  topology.
- **Coverage-map gotcha:** the recorder only fires inside `ImportManager._parseWithStrategy`.
  Paths that bypass it get NO snapshot: URL tiers 2/4/5 (self-store only happens in the
  enhanced-parser tier), GlobalRecipeCache hits (`_checkCacheForUrl`), FileImportViewModel
  (constructs its strategy directly), and recipe-detail re-extract. When testing "every import
  path captures corrections", enumerate against these call sites, not against strategy names.

### 2026-07-16 — BUT-1611/1612 weekly presence review: persisting a member-id selection reopens the "ids outlive the roster" hole [Bug found via probe — reviewed]
Trigger: sprint review of the per-day "who's home" feature (weekly_menu_plan model/service/VM, weekly_presence_selector, menu_generator dislikes).
- **Probe-confirmed High:** `MenuGenerator._presentAllergenPrefs` has no "zero present ids matched the roster" guard — it returns a non-null EMPTY `UserAllergenPreferences` (includeUnknown=true), so `prefSource` reports `present` while NOTHING is filtered. Previously unreachable (nothing set `presentMemberIds` in production); BUT-1611 both wires it live AND persists memberIds on the week doc, so a diner-profile deletion after presence was set leaves stale ids → allergen filtering silently disabled. Probe (temp test, deleted): presence `['ghost']` + roster with gluten kid → pool `[gluten, safe]`, hiddenByAllergenFilter 0, prefSource present. **Rule: when a feature PERSISTS a set of entity ids that a resolver later intersects with a live collection, always test the zero-intersection case — the union-of-nothing shape (empty prefs, empty roles, empty filters) usually fails OPEN.**
- Second gap (untested, high blast radius): `_filterByDislikes`'s blank-term guard — dropping `.where((d) => d.isNotEmpty)` makes `line.contains('')` true for EVERY line → entire pool hidden. One cheap pin: dislike `{' '}` hides nothing.
- Third: the new `weekly_presence_selector.dart` widget encodes the feature's core semantic (reset button → `null` = "everyone" vs confirm-with-none → `[]` = "nobody home") only in which button builds which `_DayPresenceResult`; no widget test exists, and a swap regression is invisible to the model/service tests that pin the two values separately.
- Verified-not-bugs worth remembering: repo `save()` is a full `set()` (no merge) so the model's omit-when-empty `presenceByDay` cannot leave a stale field behind; generated-menu distribution preserves presence because `applyGeneratedMenu` bases on `_plan.copyWith(entries: const [])` and `distributeFromGeneratedMenu` uses `existing ?? empty` (the model copyWith test pins the mechanism); and firebase_weekly_menu_plan_repository's prefix ranges LOOK broken (`isLessThan: '${userId}_'`) but the upper bound contains a LITERAL U+F8FF char (od-verified bytes `357 243 277`) — grep for the escaped `` misses it; byte-verify before filing a "same-bound empty range" finding.

---

### 2026-07-17 — BUT-1611 per-slot presence tests (review, trigger: review)
Reviewed the three staged presence test files against production. Net: model + viewmodel
tests are sound and rigorous; one copyWeek test is mislabeled and leaves its named invariant
uncovered.

- **STRONG — malformed-drop test** (`weekly_menu_plan_test.dart` ~L280): the `'notaslot': ['m9']`
  case specifically guards the `MealSlot.fromName`-falls-back-to-`middag` trap. Production
  parse (`_parsePresenceBySlot`) uses `where(name==).firstOrNull` (returns null), NOT
  `fromName`. If someone "simplified" it to `fromName`, `notaslot`→middag and the test would
  catch it (asserts mon/middag is null). Keep this pattern for any enum-keyed tolerant parse.
- **STRONG — empty-list-vs-null distinction** (round-trip test ~L231): explicitly-emptied slot
  (`fri/lunch: []`) survives serialization as `isEmpty` and is asserted distinct from an unset
  slot (`null`). This is the safety-critical distinction ("nobody home" ≠ "no filtering") and
  it is genuinely proven both directions.
- **STRONG — union fallback safety invariant** (`weekly_menu_plan_viewmodel_test.dart` L1404):
  "an incomplete per-slot selection falls back to household filtering" genuinely proves the
  invariant — every day's lunch set, middag unset → `presentUnionForGeneration` returns null,
  not a partial union. Would fail if production unioned only the set slots. The anchor-ignores-
  past-days test (L1430) correctly exercises the current-week Thursday anchor. Solid.
- **GAP — copyWeek "dest wins" test is mislabeled and does NOT cover the conflict branch**
  (`weekly_menu_plan_copyweek_presence_test.dart` L108-151). Title claims "dest wins", but
  source holds `mon/middag` while dest holds `mon/lunch` — NO overlapping (day,slot). The
  actual dest-wins line in `_mergePresenceForward` (`weekly_menu_plan_service.dart` ~L180:
  `if (target.containsKey(slot)) return;`) is therefore never exercised. Deleting that line
  (letting source overwrite dest) leaves this test GREEN. Fix: add a true-conflict case —
  source `mon/lunch=['m1']`, dest `mon/lunch=['m9']` → assert saved == `['m9']`. The existing
  test only proves additive/non-overlapping merge.
- **MINOR — undocumented boundary**: `copyWeek` gates presence copy on `source.entries`
  non-empty (`weekly_menu_plan_service.dart` L110 short-circuits to 0). A presence-only source
  week (presence set, no menu generated) carries NOTHING forward. Arguably fine (you copy a
  planned week), but no test documents it. Consider one asserting the boundary if the product
  intends presence-only weeks to be copyable.

### 2026-07-17 — BUT-1611 presence-seed + calendar-presence test review (coverage sound; one branch gap)
Trigger: intent-alignment review of the plan-approved rebuild's two new test artifacts (`who_is_eating_viewmodel_test.dart` BUT-1611 group + `calendar_presence_test.dart`).
- **Seed-overrides-cook-history is proven correctly by a DISJOINT-set discriminator.** The cook event is seeded `[malin, mormor]` while `load(seedMemberIds:[farfar])` — the seed set is disjoint from the cook-history set, so ANY leakage (cook-history taking effect, or a seed∪history union bug) shows up as an extra/missing selection. The test pins all three memberships (farfar true, malin/mormor false) + `selectedCount==1`, which kills both the "history wins" and "additive union" mutants. This is the right way to prove an override: make the two candidate sources produce visibly different results, never overlapping ones.
- **Empty-seed=nobody is meaningful** because it discriminates empty-list from null at the `if (seedMemberIds != null)` branch: the classic bug `!= null && isNotEmpty` would collapse `[]` to the everyone/cook-log fallback (count 2 here, no cook event → everyone), so `count==0` is a real mutant-killer, not a tautology.
- **Widget finders are robust for the two stated intents.** `findsNWidgets(2)` on `bySemanticsLabel(RegExp('hemma'))` keys off the a11y label "Välj vilka som är hemma på …" (one Semantics node per meal slot, övrigt excluded) and `FamilyAvatar findsNWidgets(4)` off the everyone-home default (`presentMemberIdsFor`→null→whole roster). Solo case (`roster.length<=1`) hides the row → both findsNothing genuinely proves invisibility.
  - Latent brittleness (not a current bug): `RegExp('hemma')` also matches the nobody-home Text "ingen hemma" (a Text produces an implicit semantics node). Current tests never render an empty-presence slot so the count stays 2, but a future family-test slot with `presentIds:[]` would silently inflate it. Tighten to `RegExp('är hemma')` to decouple the presence-label finder from the nobody-text.
- **GAP (only real one): the read-only no-create-household branch is untested.** `load(allowCreateHousehold:false)` when `getForUser` returns empty → `_roster=const []; return`. All three seed tests create a household in `setUp` via `ensureForUser`, and the widget test uses a mock VM, so nothing exercises it. The BUT-1611 invariant this branch exists to guarantee — *opening the weekly menu must NOT create a household* — has ZERO coverage. Add a VM test: fresh user, no household, `load(allowCreateHousehold:false)` → `roster` empty, `selectedCount 0`, `hasError false`, AND assert `householdRepo.getForUser(uid)` is still empty afterwards (proves no write-on-read). This is the strongest missing test because it pins a side-effect-absence, which the happy-path tests structurally cannot.
- Reusable rule already logged (2026-07-16, MenuGenerator) reinforced here: when a feature persists ids intersected later with a live collection, the zero-intersection case is the one to pin — here the seed tests DO cover it (ghost-id dropped), which is why the seed half is sound.

---

### 2026-07-17 — Coverage review of BUT-1618 (personal-tag rule dialog derives property dropdown from shared `kIngredientPropertyCategories`; retired-value flagged item)
Trigger: assessed whether the added `property_registry_test.dart` "category partition" + retired-wheat tests suffice, or whether the retired-value RENDERING needs its own test.

- **Partition test is HALF-rigorous.** `expect(all.length, all.toSet().length)` is the load-bearing assertion — it genuinely kills the DropdownButton duplicate-value crash mutant (re-listing a property in two categories). Keep it. BUT the companion `expect(all.toSet(), kValidIngredientProperties)` is **tautological today**: `kValidIngredientProperties` is derived by spreading the very same `kIngredientPropertyCategories.values` into a set, so the two sides are constructed identically and it can never fail. Its only latent value is guarding against someone later re-hardcoding the flat set independently. Note it; don't rely on it for drift detection (external drift vs Sheet/TS is pinned separately by `tag_phase1_seafood_safety_test.dart`).
- **The retired-value path carries a DISTINCT, uncovered crash — not the same one the partition test pins.** In `_buildPropertyDropdown` (`lib/widgets/tagging/personal_tag_rule_dialog.dart` ~L814), `initialValue: storedValue.isNotEmpty ? storedValue : null` now passes a RETIRED stored value straight to `DropdownButtonFormField`. The only thing that keeps that legal is the `storedValueIsRetired` block (~L771) adding exactly one matching item. If that block regresses, `initialValue` has zero matching items → DropdownButton's "exactly one item with value" assertion crash. The partition test cannot see this (it only checks category uniqueness, never the initialValue↔items invariant).
- **Recommendation pattern: pin the crash invariant at a light seam, NOT via a full dialog widget test.** The dialog is a StatefulWidget needing PersonalTagViewModel + provider + l10n, and there is NO existing test pumping it — full scaffolding is disproportionate for one branch, and a `find.text('wheat – inte längre giltig')` assertion is more brittle and proves LESS about the crash than the value-count invariant. Preferred: extract a `@visibleForTesting List<String> propertyDropdownValues(String storedValue)` pure helper and assert `values.where((v)=>v==storedValue).length == 1` for a retired value ('wheat'), a valid value ('dairy'), AND that empty stored value yields no phantom item. That directly pins the DropdownButton contract with ~5 lines of production extraction. Rule: when the untested behaviour is a crash-safety invariant behind heavy widget scaffolding, prefer a pure seam that asserts the exact framework precondition over a brittle full-pump render assertion.

### 2026-07-17 — [Gaps — reviewed] BUT-1609 minor-badge test coverage pass: 3 flagged gaps still open after tests staged
Second-pass review of the staged tests against the 2026-07-16 entry above. What landed vs. what's still missing:
- **watchIsAdmin permission-denied→false: COVERED WELL.** `report_service_test.dart:351-383` mocks the sealed CollectionReference/DocumentReference chain to emit `Stream.error(permission-denied)` and asserts `.first` yields `false` under a 2s `.timeout` — the timeout is the load-bearing guard (an empty/stranded stream would time out). This is the right way to force a rules error the fake can't produce; reuse this `_MockFirestoreRepository`+`_MockCollectionReference`+`_MockDocumentReference` triple (with `// ignore_for_file: subtype_of_sealed_class`) for any "stream must survive an error" test.
- **VM default AND true-after-resolve: COVERED.** `moderator_review_viewmodel_test.dart:111` (false pre-`startListening`) + `:116` (true after `pumpEventQueue`) prove both legs, not just one.
- **GAP 1 (blocking) — `isMinorAccount` has ZERO service-level tests.** The diff to `report_service_test.dart` added only the watchIsAdmin test; `grep isMinor` on that file is empty. This is the exact "one method per layer, check the sibling service file" miss the prior entry warned about — it recurred. Confirmed the fail-closed-on-error path is real AND distinct from missing-doc: `getCachedOrExecute` (base_service.dart:186) caches only non-null, so a thrown read → executeServiceOperation null → `?? false` is NOT cached (retries), while an absent doc returns false and IS cached. Five missing tests: (a) `isMinor:true`→true; (b) missing doc→false; (c) doc without the field→false (guards the `==true` predicate vs a `!=null` regression); (d) read-error→false then repoint mock to a valid true doc→true (proves error not cached); (e) seed true, mutate doc to false within 30-min window, second call still true (proves cache short-circuit).
- **GAP 2 — the repaint contract (`if (anyMinor) notifyListeners()`, viewmodel L79) is unguarded.** Exactly the "conditional notify invisible to state-only asserts" hazard from the prior entry — the staged VM test reads `isMinorOwner` state and never counts notifications, so deleting L79 stays green while the badge never repaints. A bare `greaterThanOrEqualTo(1)` won't catch it (the stream emission itself notifies). Robust mutation catch: equal-size all-adult batch vs one-minor batch, `addListener(()=>n++)` before `startListening()`, assert minor-batch n == adult-batch n + 1.
- **GAP 3 — "dedups in-flight lookups" claimed but unproven.** `verify(isMinorAccount(any())).called(2)` with owners {minor,adult,null} only proves ownerless-skip; distinct owners each call once regardless of dedup. Need a batch with two reports sharing one `contentOwnerId` → `.called(1)`, optionally a StreamController re-emitting the same batch → still `.called(1)` (guards the `_minorOwners.containsKey` cache path vs the `_minorLookupsInFlight` in-flight path).
- **Index guard (`report_service_indexes_test.dart`) — rigorous but one hole:** correctly pins `(status:ASCENDING, createdAt:DESCENDING)` via `contains(equals([...]))`, but never asserts `queryScope`. Declared index is `queryScope:COLLECTION` and the prod query is `.collection('reports')`; a refactor to `COLLECTION_GROUP` would keep the test green while `.collection()` still throws `failed-precondition`. Fold `i['queryScope']=='COLLECTION'` into the matched tuple. General rule for these structural index guards: assert scope alongside field order, because collection vs collectionGroup indexes are not interchangeable for the query that needs them.

### 2026-07-17 — [Gaps — reviewed] BUT-1519 shared ButleryBetygPill extraction: format contract under-pinned by loose textContaining
Reviewed the behaviour-preserving extraction of `lib/widgets/recipe/butlery_betyg_pill.dart` and its three suites. Extraction is sound and behaviour is pinned on BOTH consumer sides (not just structurally) — but the pill's OWN test is looser than the card's.
- **Both consumers are behaviourally (not structurally) pinned — confirmed.** The pill renders one Text `'$avg · ${butleryBetygCount(count)}'` = `"4,5 · 12 betyg"` (middot U+00B7, count label unique to this pill). The card test (`recipe_card_test.dart:950,1004`) and the UNCHANGED detail test (`recipe_detail_metadata_pooled_pill_test.dart:140`) both `find.textContaining('12 betyg')` — i.e. they match the SHARED widget's real rendered string, so the refactor keeps both green via genuine render, not a `find.byType(ButleryBetygPill)` topology assert. Behaviour-preservation is real on both sides.
- **GAP (weak, worth strengthening) — the pill's own format test does not pin the count-label or separator.** `butlery_betyg_pill_test.dart:32-33` uses `find.textContaining('4,5')` + `find.textContaining('12')`. The comma IS pinned (a `4.5`-dot regression drops the `,` match) and the one-decimal-for-whole-numbers IS pinned by the `4,0` case (:40). But `textContaining('12')` proves only that the digits `12` appear somewhere — a regression that dropped the `butleryBetygCount` label (rendering bare `"4,5 · 12"` instead of `"4,5 · 12 betyg"`) or changed the `·` separator stays GREEN. The card suite is stronger here (`'12 betyg'` + negative `find.textContaining('4.0'), findsNothing`). Fix: replace the two loose finds in the first test with one exact `expect(find.text('4,5 · 12 betyg'), findsOneWidget);` — the `_host` renders a single Text, so an exact match pins comma + separator + count-label + one-decimal in one assertion. Same tightening for the `4,0` test: `find.text('4,0 · 8 betyg')`.
- **GAP — the a11y label test drops the count.** `:47` asserts `find.bySemanticsLabel(RegExp('3,8'))` — proves the average interpolates but not the vote count or butler-voice shape. Tighten to `find.bySemanticsLabel(RegExp(r'Butlery-betyget 3,8, 7 röster'))` so a regression in the `a11yButleryBetygPill(avg, count)` order/count leg is caught (mirrors the pill's Semantics.label contract, l10n `Butlery-betyget {rating}, {count} röster`).
- **Demotion/slate is a CARD concern, already covered — not a pill gap.** The ticket's "demotion" (family pill text recedes from onPrimary → cs.onSurfaceVariant when a floored pool co-exists) lives in the card, not the pill, and IS theme-resolved-pinned at `recipe_card_test.dart:994-1015`. The pill itself has no demotion state. Don't add a pill demotion test.
- **`average==null` 0-fallback (widget L29 `stats.average ?? 0` → "0,0") — deliberately leave UNTESTED.** The widget comment + all callers gate on `meetsDisplayFloor` (average non-null), so the fallback is unreachable in production; a test would pin an accidental "0,0" render as if it were contract. This is the correct call — don't test a guard the callers prove can't fire.
- Rule reinforced: **`find.textContaining(<bare number>)` never pins a format contract — it pins a substring.** For a composed label (`avg · N unit`), assert the exact `find.text(...)` of the single rendered string; that catches separator, unit-word, and decimal-shape regressions in one line, where a digit-substring catches none of them.

### 2026-07-18 — [Review, clean] ShoppingSelectionManager (tech-debt-viewmodels) — selection-manager family base-class drift
Reviewed `lib/viewmodels/shopping/shopping_selection_manager.dart`. State machine is byte-identical to `pantry_selection_manager.dart` (enter/toggle/auto-exit/selectAll-guards-mode/clear), analyze clean, and `test/unit/viewmodels/shopping/shopping_selection_manager_test.dart` pins all five behaviours non-vacuously (asserts `isSelectionMode`+`selectedIds` state, not topology). No correctness bug, no test change needed.
- **Family base-class inconsistency (the only real finding).** The doc comment says it "Mirrors pantry_selection_manager / recipe_selection_manager", but this one `extends BaseViewModel` while BOTH named mirrors `extends ChangeNotifier`. A pure selection state-holder inherits BaseViewModel's whole loading/error/executeAsync/validation surface (~410 lines) it never uses. Not a bug (BaseViewModel guards post-dispose notify, so it's if anything safer), but it breaks the stated mirror contract. Pick one base for the family — either drop this to `ChangeNotifier` or migrate the two siblings up. Flag as Low.
- **Non-finding (don't re-flag):** `selectedIds => Set.unmodifiable(_selectedIds)` allocates per call, and `toggleSelection` can add an id while `isSelectionMode==false` if called cold (only `selectAll` guards the mode) — both are IDENTICAL to the accepted pantry/recipe siblings, so they're family design, not a regression introduced here.
- **Testing posture for these managers:** a plain `ChangeNotifier` selection state-holder needs NO ServiceLocator/BaseUnitTest setup — the existing test's `setUp(() => manager = ShoppingSelectionManager())` + `tearDown(dispose)` is the right minimal harness. Don't add executeAsync/loading-state tests for the inherited BaseViewModel surface: it's dead in this class (nothing writes `super._error`/`_isLoading`), so such tests would be vacuous.

### 2026-07-18 — [Review — gaps] tagging sprint: delta-refresh, override-log, tag scorecard eval
Reviewed `firebase_ingredient_repository.dart` (BUT-1475 delta refresh) + its test, `tag_overrides_log_repository.dart` / `tag_override_log_entry.dart` / `tag_editing_service.dart` (BUT-1473 correction capture), `tag_scorecard_eval_test.dart` (BUT-1489), and `tagging_module.dart`.
- **The delta-refresh test proves CONVERGENCE, not DELTA — the core BUT-1475 optimization is unguarded.** `firebase_ingredient_repository_delta_refresh_test.dart` asserts only `count()`/`findByName` after a TTL cross; every assertion still passes if someone reverts `_deltaRefreshOrFull` to a full `.get()` every hour (the thing the ticket exists to avoid). FakeFirebaseFirestore doesn't expose read counts, so wrap the collection in a counting spy (or count `.get()` calls via a query interceptor) and assert the delta path fetches 1 doc, not the whole set. Pattern for any "we fetch less now" optimization: the test MUST observe the read count, or it's testing the wrong contract.
- **`tag_overrides_log` has NO Firestore rule** (grep of `firestore.rules` = empty). The repo comment acknowledges "writes default-deny harmlessly until the rule ships" — but that means BUT-1473 captures NOTHING in production today, and `save()` swallows the permission-denied, so there is no signal it's dormant. There is no test/gate ensuring the rule ships before the feature is relied on. Flag Medium whenever a write path is shipped that is guaranteed to fail in prod with a silent catch.
- **Shared `_inFlightLoad` lets `forceRefresh()` silently degrade to a partial delta.** `loadCache(forceReload:true)` returns any in-flight future (L224-225); if a background delta refresh is running, a forced FULL reload returns that delta instead, then still fires `_notifyCacheInvalidated()`. A `forceReload` should not coalesce onto a non-force in-flight load. Low-Medium.
- **Delta refresh can't see deletions or newly-added legacy (no-`updatedAt`) docs.** Once any doc has `updatedAt`, `_maxUpdatedAt` is non-null so the full-reload fallback never runs again; admin-deleted ingredients linger until app restart/forceRefresh. Inherent to timestamp delta sync + acceptable for an admin collection, but note Low.
- **Eval test scores GENERATION on pre-matched golden ingredients — it does NOT exercise ingredient lookup/matching.** `generator.generate(ingredients: lookup, ...)` is fed hardcoded `matched`/`unmatched` from the JSON, so a regression in the repository's name/alias matching is invisible here (the binary golden test complements). Correct by design (mirrors corpus harness); note the scope so nobody assumes it guards matching.
- **Non-findings (don't re-flag):** `TagOverridesLogRepository` bypassing BaseFirebaseRepository/PermissionValidationMixin is the accepted BUT-886 own-data pattern (mirrors ParsingCorrectionRepository); `isGreaterThan` (not `>=`) on the baseline is the right re-fetch-avoidance tradeoff; `TagEditingService` sync methods not using `executeServiceOperation` is fine (that's for async ops); `TagTriState.fromString(null)` is null-safe.

### 2026-07-18 — BUT-1454 minor search-suppression: chokepoint-serialization test pattern
- **Trigger:** reviewed the `isMinor` threading (verifySignupAge CF response → AgeVerificationResult → OnboardingViewModel._isMinor → completeOnboardingWithPreferences → copyWith → UserProfile.toFirestore).
- **Good pattern to reuse:** the search-repo test (`firebase_search_repository_test.dart`) proves search-suppression by writing REAL profiles through `UserProfile.toFirestore()` into FakeFirebaseFirestore and asserting the minor is absent from `searchUsers()` — behavioral, survives a refactor of where the derivation lives. Do NOT replace with a `toFirestore()['isSearchable'] == false` getter assert; the end-to-end search test is strictly stronger.
- **Coverage gap noted:** the belt-and-suspenders completion branch (`OnboardingViewModel.completeOnboarding`, `_selectedBirthYear != null && !_ageVerifiedThisSession`) captures `_isMinor` from the CF but has NO minor-path test — only the gate path does. A rare-but-real branch.
- **Defense-in-depth note:** suppression is client-derived (`toFirestore`); a minor controlling their own client can still write `public_profiles.isSearchable:true` directly. Rules-level enforcement is tracked as a BUT-674 follow-up (accepted), not a regression — don't re-file as Critical.

### 2026-07-18 — BUT-1469 import-correction snapshot: zero-diff symmetry breaks on name-less ingredient lines
Trigger: reviewing the import-correction-snapshot widening (text/photo/voice/archive now feed
the parser feedback loop via `ImportCorrectionSnapshot` → `ParsedRecipeCache`, keyed by
recipe id).
Bug caught (real, Medium): the feature's core promise — "import + save with NO edits must
train nothing" — is violated for any recipe containing a quantity+unit-only ingredient line
(e.g. `"2 dl"`). `IngredientParser.parseIngredient("2 dl")` returns `name == ""` (unit-first
match consumes the whole tail). `RecipeDiffCalculator._namesMatch` returns false whenever
either name is empty, so the identical line can't self-match → phantom `removed` + `added`
= 2 fabricated corrections on an unedited save. Verified live: `totalCorrections == 2`.
Root cause spans `import_correction_snapshot.dart` (`_toParsedIngredient` stores empty name)
and `recipe_diff_calculator.dart` (`_diffIngredients` has no originalLine fallback). Fix
belongs in the diff calculator: when both parsed names are empty, match on `originalLine`
equality before declaring add/remove.
Test pattern that catches it: build a snapshot from a recipe whose ingredients include a
name-less line, diff against the SAME recipe, assert `correction == null`. Pinned as a
`skip:`-tagged test (honest known-bug marker, NOT a weakened green assertion).
Second (Low) find: URL imports that fall through to the text-fallback tiers
(`_tryWebScraperFallback` / `_tryHtmlTextParse` in `url_import_strategy.dart`) inherit the
inner `TextImportStrategy`'s snapshot tagged `ImportSource.text` — URL never re-tags it, so
those corrections are mis-attributed as `text` in training data (photo/voice DO re-tag).
Helper note: `ImportCorrectionSnapshot.capture(recipe, source:, cache:)` takes an explicit
`ParsedRecipeCache` seam — pass a real `ParsedRecipeCache()` to unit-test capture→retrieve
wiring without DI/ServiceLocator. Retrieve is one-time-use (removes on read).

### 2026-07-18 — BUT-1469 fix landed + over-correction guard (commit-gate review)
Trigger: reviewing the fix that un-skipped the name-less zero-diff test.
Fix (`recipe_diff_calculator.dart`): when `_bothNameless(a,b)`, pair the lines by
`_rawLinesEqual(originalLine, correctedLine)` before declaring add/remove, and treat two empty
names as NOT a name change in `_compareIngredient`. Confirmed the un-skipped test is
non-vacuous: old `_namesMatch` short-circuits `false` on any empty name (line ~352), so the
identical `"2 dl"` self-pair fabricated removed+added → the `isNull` assert fails on old code.
Review-added test (the missing coverage): the fix makes matching MORE lenient, so the real
regression vector is the opposite direction — a future refactor dropping the `_rawLinesEqual`
guard would let `"2 dl"` match `"3 dl"` and SILENTLY SWALLOW a genuine name-less edit on a
training-data feature. Pinned with a test that edits one of two distinct name-less lines
(`"3 dl"→"4 dl"`) and asserts the correction is still captured while the untouched `"2 dl"`
isn't dragged into a phantom merge. Rule: when a diff/matching fix widens what counts as a
match to kill phantoms, always add the paired test proving a REAL change on that same shape
still surfaces — the phantom-suppression test alone can't catch over-suppression.

---

## 2026-07-18 — Analytics chokepoint events need capture-tests; the GetIt→DIContainer bridge gotcha

Trigger: reviewed the "menu" sprint diff (`lib/services/analytics/analytics_events.dart` +
`lib/viewmodels/menu/menu_generator.dart`, BUT-1474 — swap-rate event `menu_recipe_swapped`
fired via `AnalyticsService.tryLog` in `MenuGenerator.swapSingleRecipe`).

The diff added a new analytics event at a "single chokepoint" but shipped with ZERO test
coverage. A dropped/renamed event or a renamed param silently kills the funnel with no
compile error — exactly the failure mode `AnalyticsEvents` (BUT-737) exists to prevent, but
constants don't protect the CALL SITE firing. Rule: any new `AnalyticsService.tryLog(...)`
at a behavioural chokepoint gets a capture-test — fires-once-with-params on the happy path,
fires-nothing on the negative path (here: exhausted swap). Pattern:
`MockAnalyticsService().capturedEvents.where((e) => e.name == '<event>')`.

GetIt-vs-DIContainer bridge gotcha (cost me one red run): `AnalyticsService.tryLog` resolves
via the PRODUCTION `ServiceLocator` (`lib/core/providers/application_provider.dart`), which is
a `DIContainer`, NOT the test `ServiceLocator`/GetIt that `TestServiceLocator.initialize()`
(the E2E locator) populates. A `MockAnalyticsService` registered only via
`TestServiceLocator.registerSingleton` is INVISIBLE to `tryLog` — capturedEvents stays empty
and the test false-fails. Fix: bridge them in setUpAll with
`production.ServiceLocator.initialize(DIContainer())` (import `application_provider` aliased +
`core/di/di_container.dart`); the real DIContainer reads off the same GetIt the test locator
fills, so registered mocks become visible. (Files that use `BaseUnitTest.setupUnitWithProductionLocator()`
already do this bridge — the plain `TestServiceLocator.initialize()` files do not.)
`TestServiceLocator.registerSingleton` unregisters-first, so per-test re-registration of a
fresh capture mock is safe (no cross-test bleed). Bridging was safe in the swap file only
because every test exercises the swap path, which never builds the scoring context / reads
FeatureFlagService (that read is OUTSIDE a try/catch in `_buildPooledStats` and an unstubbed
mock would throw) — check the code path before bridging a broad locator into an existing file.

Convention drift noted (pre-existing, already logged in ROLE_RESPONSIBILITY_MAP): the sibling
event `MenuGenerator._logHiddenByHouseholdEvent()` (line ~405) still uses a RAW string literal
`'menu_recipes_hidden_by_household'` instead of an `AnalyticsEvents` constant — the one untyped
event in the menu domain. Now more glaring since BUT-1474 added its neighbour the right way.

### 2026-07-18 — Base-class migration (ChangeNotifier → BaseViewModel) non-vacuous check [trigger: BUT-1607/BUT-520 commit-gate]
`ShoppingSelectionManager` migrated `extends ChangeNotifier` → `extends BaseViewModel`.
Existing suite (test/unit/viewmodels/shopping/shopping_selection_manager_test.dart, 6 tests)
passed unchanged and non-vacuously — asserts real state (isSelectionMode, selectedIds,
selectedCount, isSelected), no widget topology. The "base-class change un-matches mocktail
stubs" lesson did NOT bite here: the manager has no service dependencies, so the test uses a
bare `ShoppingSelectionManager()` and no `when()` stubs exist to silently break. Reusable check
for these BUT-520 base-class swaps: (1) BaseViewModel is an abstract ChangeNotifier, no required
ctor args, dispose() calls super.dispose() — so a no-arg test constructor + tearDown dispose()
stays valid; (2) only flag if the migrated VM takes mocked services (then re-verify stubs match).
COMMIT-READY.

### 2026-07-18 — Minor search-suppression proven at the serialization chokepoint [trigger: BUT-1454 commit-gate]
Reviewed BUT-1454 salvage batch (3 test files). The critical test in
firebase_search_repository_test.dart proves the CONTRACT the right way: it writes TWO real
profiles (minor + non-minor, both with `isSearchable:true` in memory) through
`UserProfile.toFirestore()` into FakeFirebaseFirestore, then asserts the minor is ABSENT from
`searchUsers('mina')`, the adult IS present, and an empty-query search returns only the adult.
This is non-vacuous: the suppression is one line — `toFirestore()` writes
`'isSearchable': isMinor ? false : isSearchable` (user_profile.dart:375) and the repo queries
`.where('isSearchable', isEqualTo: true)` — so removing either the derive-off in toFirestore OR
the query filter turns the minor visible and fails the test. This is the correct pattern for a
"serialized-derived field" contract: drive the REAL serializer, don't assert the getter.
Onboarding VM tests prove isMinor threads gate→completion (minor captures isMinor:true, adult
isMinor:false into completeOnboardingWithPreferences). Note: the "OR-monotonic, server-true
never downgraded" property is NOT in the client VM (it does a plain `_isMinor = result.isMinor`;
the belt path only runs when the gate didn't verify) — that monotonicity lives in
UserService/CF and is out of scope for these 3 files. The always-suppress-on-write monotonicity
that DOES matter (isMinor:true forces isSearchable:false regardless of the user's toggle) is
exactly what the repo test's "isSearchable:true minor still absent" assertion proves. 44/44 pass.
COMMIT-READY.

---

### 2026-07-18 — Delta-refresh discriminator tests + tag-scorecard CI gate (BUT-1475 / BUT-1489)
**Trigger:** commit-gate review of a salvage batch. A prior review had flagged the
BUT-1475 delta-refresh suite as WEAK: it proved convergence but stayed green even
if the refresh secretly reverted to a full-collection reload, so it did not guard
the read-cost win the feature exists for.

**Pattern — "discriminator" test for a cost/perf optimisation:** when a feature's
value is "does LESS work" (here: a `where('updatedAt', isGreaterThan: baseline)`
delta query instead of a full `.get()`), a convergence test is not enough — both the
optimised and the naive path converge. Add a test that only the OPTIMISED path can
pass: seed a doc that a full reload WOULD pull in but the filtered query MUST skip
(an `updatedAt` OLDER than the load baseline), then assert it is absent
(`count()==1`, `findByName(...) isNull`). This flips red the moment the filter is
dropped or the delta query is replaced by a full reload. Mirror it with the inverse
(`forceRefresh` must pick that same older-than-baseline doc up — proving forceRefresh
is genuinely full, not a delta). Verified both against `firebase_ingredient_repository.dart`:
delta path is `_deltaRefreshOrFull` (empty-delta restamps freshness, count unchanged);
forceRefresh routes through `loadCache(forceReload:true)`→`_doLoadCache` (full `.get()`).

**fake_cloud_firestore background-op draining:** the TTL refresh is fire-and-forget
(unawaited in `_ensureCacheLoaded`), so you cannot `await` it. `_drainMicrotasks()`
= two `await Future<void>.delayed(Duration.zero)` yields the event loop enough for the
fake `.get()` to resolve. This is NOT the banned `Future.delayed(Duration(seconds:N))`
real-wait — it is zero-duration event-loop yielding and is deterministic (5/5 green).
TTL staleness driven by an injected `now:` callback (a local mutable `_Clock`), so no
real time is involved.

**Vacuity check for eval/scorecard gates:** `scoreTriStateMap` iterates GOLD keys only,
so an empty answer key scores a vacuous 1.0 accuracy / 0 falseFree — a green gate that
proves nothing. Before trusting a scorecard floor test, confirm the committed golden set
actually populates the graded maps. Verified `test/golden/tagging_golden_dataset.json`:
20 recipes, 60 allergen + 33 dietary verdicts. The load-bearing assertion is the absolute
`falseFree <= 0` safety gate (never claim FREE where gold says CONTAINS/UNKNOWN), not the
accuracy floors (0.90/0.85, deliberately generous headroom below the current 100% so
legitimate golden edits don't flake while a broad regression still trips). Eval is pure
Dart + committed data, no network/clock → deterministic.

**Verdict:** COMMIT-READY. Both files analyze-clean; delta suite 5/5; eval 20 recipes,
60/60 allergens, 33/33 dietary, 0 false-FREE.

### 2026-07-18 — Fire-and-forget capture (BUT-1473 tag_overrides_log) needs a capture-test [trigger: commit-gate coverage of TagEditingService._logAllergenOverride]
BUT-1473 added an unawaited `ServiceLocator.tryGet<TagOverridesLogRepository>()?.save(entry)`
in `TagEditingService.applyAllergenOverride` — shipped with ZERO tests. Same failure mode as
the analytics-chokepoint entry above: a dropped field, wrong `direction` string, or a broken
`triggeringIngredients` lookup silently kills the learning-loop signal with no compile error.
Added 3 tests to `test/unit/services/tagging/tag_editing_service_test.dart`:
1. **Non-vacuous field assertions** — register a real `TagOverridesLogRepository(firestore:
   FakeFirebaseFirestore())`, apply a confirmed contains→free override, drain, then read the
   fake collection and assert EVERY field: userId==editedBy, recipeId, type=='allergen',
   tag, `direction=='contains->free'` (the load-bearing one), and triggeringIngredients pulled
   from the matching `TagDecision`. A bare "one doc landed" would be vacuous.
2. **tryGet-null no-op** — DIContainer initialized but repo NOT registered → edit still succeeds,
   nothing thrown.
3. **Non-blocking** — a `_NeverCompletingLogRepository extends TagOverridesLogRepository` whose
   `save` returns `Completer().future`; assert the edit result returns synchronously without
   draining. Proves capture can't block the edit. (Subclassing the CONCRETE repo with an
   `@override` body is fine — the DO-NOT rule is about `@override` bodies on mocktail `Mock`s.)

Bridge gotcha (same as the analytics entry): the service reads the PRODUCTION `ServiceLocator`
(`application_provider`, a DIContainer over `GetIt.instance`), not the test locator. Register the
real repo via `GetIt.instance.registerSingleton<TagOverridesLogRepository>(...)` AFTER
`prod.ServiceLocator.initialize(DIContainer())`; tearDown = `await GetIt.instance.reset()` +
`prod.ServiceLocator.reset()`. Fire-and-forget writes to FakeFirebaseFirestore land after two
`await Future.delayed(Duration.zero)`. Bridging was safe because applyAllergenOverride's ONLY
locator touch is this repo (checked the path first, per the bridge rule). Existing tests were
unaffected — they never initialize the prod locator, so tryGet returns null and the capture is a
silent no-op for them.

### 2026-07-18 — executeAsync's fail-loud fix exposes a dead retry loop in AsyncOperationMixin.executeWithRetry [trigger: review of base_viewmodel.dart doc-comment diff]
BUT-1462 corrected `executeAsync`'s doc from "returns null on failure" to "rethrows" (the code
always threw). Reviewing that diff surfaced a latent bug the correction implicates:
`AsyncOperationMixin.executeWithRetry` (base_viewmodel.dart:327-353) was written against the OLD
(false) null-return contract. It does `final result = await executeAsync(...); if (result != null
|| attempt == maxRetries) return result; await Future.delayed(delay);` — but executeAsync RETHROWS
on failure, so the first thrown exception propagates straight out of the `for` loop. The retry /
`Future.delayed` backoff path is only reachable when the operation RETURNS null without throwing —
impossible for a non-nullable `T`. Net: the mixin never retries a throwing op (the sole reason
retry exists), yet CLAUDE.md advertises it "with exponential backoff." Currently no production
caller (only the test + a same-named-but-different mixin in lib/core/mixins), so it's a latent
trap, not an active outage.
Test smell that hid it: test/unit/viewmodels/base_viewmodel_test.dart:443 "should retry on failure
and eventually succeed" was WEAKENED to `expect(attemptCount, greaterThanOrEqualTo(1))` (vacuous —
any op runs once) with a comment excusing that executeWithRetry "may not complete all retries." The
assertion was softened to go green instead of flagging the bug — exactly the anti-pattern. The
right move: either fix executeWithRetry to `try/catch` around executeAsync and restore
`expect(attemptCount, 3)`, or (if keeping current behavior) rename the test to state it does NOT
retry-on-throw. Also executeWithRetry's own doc (line ~316 "Returns operation result or null if all
attempts fail") is stale the same way executeAsync's was — the lesson's "correct the stale null doc
wherever it appears" wasn't applied here. The BUT-1462/BUT-1628 lesson should note executeWithRetry
is broken-by-the-same-fact so the sweep doesn't leave a silently-inert retry.

---

### 2026-07-18 — Review pattern: "armed-but-unsaveable" gate divergence (UserProfileViewModel / HouseholdSizeView, BUT-1594/BUT-1322)
Trigger: reviewing lib/viewmodels/user_profile_viewmodel.dart + lib/views/settings/household_size_view.dart (settings sprint).
Pattern to watch for whenever a save-only screen shares a multi-field ViewModel's `saveProfile()`:
the Save button's ENABLE predicate and the save's INTERNAL VALIDATION gate can disagree.
- HouseholdSizeView arms Save on `hasUnsavedChanges`, which has a special new-profile branch
  (VM lines 90-102) that returns true when `householdSize != null` even on a not-yet-loaded /
  first-run / offline profile (`_originalProfile == null`, `_editedProfile` = a shell with
  `displayName: ''`).
- But `saveProfile()` gates on `isFormValid` (`_displayNameError == null && displayName.isNotEmpty`,
  line 108). The shell's empty displayName makes it false → save returns false immediately,
  logging only via `_handleUserError` (which is a PRIVATE method that does NOT override the mixin's
  `handleUserError` and never sets `_operationError`). So `viewModel.error` stays null and the
  household screen shows the generic `profileCouldNotSave` — the setting is unsaveable, i.e. the
  exact "screen locks up" outcome BUT-1594 tried to prevent, just moved from a disabled button to a
  silent failing save.
- The VM test (test/unit/viewmodels/user_profile_viewmodel_test.dart:759) only asserts
  `hasUnsavedChanges` ARMS in this scenario; it never drives `saveProfile()` through it, so the gap
  is invisible in green. Whenever you see a hasUnsavedChanges/canSave special case, write the
  companion test that calls saveProfile() in that same state and asserts a MEANINGFUL result
  (success OR a non-null `error`), not just that the button armed.
Secondary note: `ErrorHandlingMixin.safeExecute` catches and returns `defaultValue` WITHOUT setting
any error field — a VM using it for a write must set its own user-facing error, or the view's
`vm.error ?? fallback` always shows the fallback. And this VM extends `ChangeNotifier` (not
`BaseViewModel`), so `notifyListeners()` in the new save `finally` is unguarded against disposal.

---

### 2026-07-18 — Drift guards: a one-directional "all → mapped" check is NOT a two-way drift guard (menu-tagging-quality sprint)
**Trigger:** reviewed the `ProteinTags` extraction refactor (`tag_phase1_nutrition.dart` +
`protein_category.dart` + `menu_service_test.dart`, BUT-1324 follow-up). The refactor moved the
protein vocabulary into a shared `ProteinTags.all` constant set and replaced the test's
**set-equality** drift guard (`ProteinCategory.allTags == handKeptEmittedSet`) with a loop
asserting each `ProteinTags.all` member maps to a non-null category.
**Pattern:** A drift guard that only walks `vocabulary → mapExists` catches *forward* drift
(a vocab entry with no mapping) but silently drops *reverse* drift (a mapping/vocab entry the
producer no longer emits — a dead mapping still compiles and still returns non-null). The new
doc comments claimed "reverse drift caught by the compiler" — **false**: the compiler only
catches deleting the *constant*; deleting the *emission branch* (`tags.add(ProteinTags.lax)`)
while keeping the constant/map/`all` entry compiles clean and passes the loop. The real
producer↔vocabulary coupling ("the tagger emits exactly `ProteinTags.all`") had ZERO test —
it was pure discipline. When you see a drift guard, ask both directions and ask whether the
*producer* is ever actually exercised. The durable fix is a **positive** test that drives the
real producer (build `IngredientLookupResult` fixtures per group → run `calculateProteinTags`
→ assert the emitted union == `ProteinTags.all` and each maps to a category), not a static
walk over a hand-maintained set.
**Second pattern (indexOf(-1) precedence trap):** `ProteinCategory.categoryOf` starts
`bestRank = _categoryPrecedence.length` and takes `rank = indexOf(category)`. A category present
in `_tagToCategory` but missing from `_categoryPrecedence` yields `-1`, and `-1 < length` is
always true → that category outranks EVERY real protein in a multi-protein dish. Latent today
(all 9 listed) but unguarded, and the non-null drift guard can't catch it. Guard with
`if (rank < 0) continue;` or assert `_tagToCategory.values ⊆ _categoryPrecedence` via a
`@visibleForTesting` accessor.
**Coverage gap noted:** the entire emission surface of `tag_phase1_nutrition.dart`
(group lookups, `räk` + `crustacean` gate, all of `calculateCarbTags` incl. the `grain/pasta-bread`
token) has NO direct test anywhere — protein tags are only tested by hand-setting `TagResult.tags`.

---

### 2026-07-18 — Review pattern: two independent owners of the same household-default scaling logic (BUT-1322/BUT-1515)
Trigger: reviewing lib/views/recipe_detail/recipe_detail_actions.dart + lib/viewmodels/cooking_mode_viewmodel.dart
(recipe-scaling sprint). Both files independently re-implement the SAME three-step behaviour —
resolve the household-size default, pre-scale ingredients from the recipe's own portions as base,
and log `logPortionScalingApplied(source: 'household_default'|'manual_override')` once per open —
plus the BUT-1515 boot-race re-apply with a manual-override latch. The test file's own header comment
admits it ("a separate copy of the logic in CookingModeViewModel"). The copies have ALREADY diverged:
`CookingModeViewModel._resolveHouseholdDefault` rejects out-of-range sizes (`< minPortions || > maxPortions`,
1–50), while `RecipeDetailActions._resolveHouseholdDefault` has NO range guard and trusts the
`UserProfile` 1–12 constructor invariant. Safe today, but a fix/relaxation in one won't reach the other.
Pattern to watch: when two surfaces (detail view + cooking mode) must agree on a derived value that
feeds a THIRD consumer (add-to-shopping reads `currentPortions`), a shared helper is the correctness
guarantee — duplicated resolve+scale+log is a latent split-brain. When reviewing such duplication,
check the guards line-by-line for drift, not just that both have tests.
Coverage gap found: both suites test the boot-race fallback→apply and the same-value idempotent no-op,
but NEITHER tests a household-size CHANGE to a *new* value while a default is ALREADY applied (the
`household == _currentPortions` guard's re-scale branch). A regression re-scaling from the wrong base,
or silently mutating amounts under a mid-cook user who never touched the scaler, would stay green.

### 2026-07-18 — BUT-1626 group-minor CF + analytics minimization review [Pattern — reviewed / correctness]

Reviewed `enforce-group-minor-membership.ts`, its pure-fn test, `firestore.rules` conversation gate,
and the analytics `setLifecycleStage` isMinor gate. Pure `computeMinorsToRemove` is well tested (6 cases,
adult/creator/unknown-creator fail-safe/mixed all pinned) and passes.

**Correctness — client-controlled `metadata.creatorId` defeats the CF's stated purpose.** The trigger keys
its whole "was this minor added by a friend" decision on `data.metadata.creatorId`, but the conversations
create rule (firestore.rules ~L1511) only requires `hasRequiredFields(['participantIds','createdAt'])` — it
NEVER validates `metadata.creatorId == request.auth.uid`. A tampered client (the exact threat the CF header
says it backstops) adds a minor to a group and sets `metadata.creatorId` to the *minor's own uid*: in the
handler `candidates = participantIds.filter(u => u !== creatorId)` drops the minor before any read, and
`computeMinorsToRemove` skips them via `if (uid === creatorId) continue`. Minor kept, gate bypassed. Lesson:
**a defense-in-depth CF that trusts a doc field is only as strong as the rule validating that field** — before
crediting a "backstop for tampered clients" gate, check the rules actually pin the field the gate reads. Fix
belongs in rules (require creatorId==auth.uid on create), not the CF (onDocumentCreated has no auth context).

**Testing gap — the safety-critical I/O branches are untested.** The pure fn is covered but the branch that
actually cuts access (strip from `participantIds`, `remaining.length < 2 ⇒ delete whole conversation`, the
per-uid `FieldValue.delete()` cleanup, membership-mirror cleanup) has ZERO coverage. For a child-safety trigger
this is the wrong half to leave dark. Owes a `test:integration:enforce-group-minor-membership` (emulator lane):
seed a >2 group with a non-friend-added minor, assert the minor leaves participantIds and read access is cut.
Delete-branch also orphans the KEPT participants' `conversation_memberships` mirrors (only removed uids are
cleaned) — ghost list entry.

**Analytics — two independent minor-minimization gates that can drift.** `AnalyticsRepository.setLifecycleStage`
gained `required bool isMinor` (early-returns when true) and is tested, BUT it has NO production call site: the
live path is `UserPropertyBootstrap.emitLifecycle`, which duplicates the suppression inline (`if (profile?.isMinor
== true) return`, L80) and calls `setUserProperty` directly. No safety gap today (both suppress), but the test
exercises a dead-in-prod setter while the live gate is a separate line — changing the minor policy in one place
silently leaves the other. When you see a "defense-in-depth mirror" setter, confirm which gate is actually on the
live path before trusting the test that covers the other.

### 2026-07-18 — BUT-1462 executeAsync rethrow: prove rethrow via retry attemptCount, not the swallowed direct test [Pattern discovered]

Reviewed the `base_viewmodel_test.dart` salvage for BUT-1462 (executeAsync now RETHROWS
on failure instead of returning null; executeWithRetry repaired to catch-and-retry).

- The *direct* failure test (`should handle async operation failure`) wraps the call in
  `try { ... } catch (_) {}` and only asserts `hasError, isTrue`. That is **vacuous with
  respect to the rethrow contract** — it passes whether executeAsync rethrows OR regresses
  to returning null. Don't rely on it to guard the rethrow.
- The rethrow contract is actually guarded — non-vacuously — by the retry tests:
  `attemptCount == 3` + `result == 'Success on attempt 3'` is only reachable if executeAsync
  rethrows (a return-null regression stops after attempt 1, giving attemptCount==1). So the
  retry group is the real guard for "executeAsync rethrows." Useful idiom: **prove a rethrow
  indirectly by counting side-effect iterations of a caller that only loops on throw.**
- Disposed→StateError is proven directly and correctly via `throwsStateError` (not swallowed).
- Gap noted (non-blocking): the documented invariant "a legitimate `null` operation result
  returns immediately without exhausting retries" (explicit in the production comment) has
  **no test** — no case where the operation returns null and asserts `attemptCount == 1`.
  A regression that treats null as a retry trigger would go uncaught. One cheap test owed.

---

## 2026-07-18 — BUT-1614 correction-capture tests (photo/text/url import strategies)

**Trigger:** commit-gate review of salvage tests proving each non-URL import path captures a pre-edit
`ImportCorrectionSnapshot` (the BUT-1469 widening of the parser feedback loop). Verdict: COMMIT-READY.

**Pattern — testing `ImportCorrectionSnapshot.capture` wiring.** The strategies capture via
`ServiceLocator.tryGet<ParsedRecipeCache>()` (no cache arg). To read the snapshot back through a real import,
wire a real cache into the production locator in `setUp`:
`ServiceLocator.reset(); ServiceLocator.initialize(DIContainer());` then
`GetIt.instance.registerSingleton<ParsedRecipeCache>(cache)` (unregister first if present); tearDown unregisters
+ `ServiceLocator.reset()`. Confirmed the chain: `ServiceLocator.tryGet` → `DIContainer.get` → `GetIt.instance`,
so the test's GetIt registration is what the strategy resolves. `ParsedRecipeCache.retrieve` is **one-time-use**
(removes on read) — retrieve once per test, no cross-test bleed.

**Non-vacuous asserts that mattered:** don't stop at `snapshot != null`. Assert `metadata.source` is the
strategy's own `ImportSource` (photo/text/url), `parserVersion == ImportCorrectionSnapshot.snapshotParserVersion`
(the sentinel proving it's a produced-recipe anchor, not a real parse), and for URL `metadata.domain == '8.8.8.8'`.
The load-bearing test is **last-write-wins**: photo/url delegate to the inner TextImportStrategy which stores a
`text`-tagged snapshot under the same recipe id first; the outer tier re-captures as photo/url and must overwrite —
seed a `text` snapshot, run the import, assert the final tag is photo/url. Best-effort path also pinned: with the
locator reset (no reachable cache) import still succeeds and nothing is stored.

**Bonus (good):** the text-strategy diff also converted ~9 pre-existing vacuous escape-hatch asserts
(`if (ingredients == ['Ingen ingrediensinformation']) { expect(...placeholder) } else {...}`) into hard behavioral
asserts, and deleted a green-no-op "should extract difficulty" test (no such field/extractor exists) with a
rationale comment. These characterize real parser behavior incl. current English-metadata gaps ("Serves 4" → null
portions, "Prep 15, Cook 30" → 15 not summed) — honest characterization, documented; mild note that a future
parser *improvement* will break them, which is acceptable for behavior-pinning tests on a Swedish-first parser.

---

### 2026-07-18 — BUT-1594 fix landed, tests still didn't close the gap the 2026-07-18 review flagged [Coverage review — gaps still open]
**Trigger:** coverage check on the uncommitted `UserService.createOrUpdateProfile` / `UserProfileViewModel` /
`household_size_view.dart` change described as "household-size-only settings screen can save without a display
name." The production fix is exactly what the earlier same-day "armed-but-unsaveable" entry above prescribed
(`isFormValid` now ORs `_householdSizeEdited`; `UserService` keeps `existingProfile.displayName` when the incoming
one is empty; `_handleUserError` now sets `_operationError` so `viewModel.error` is non-null) — but **no test was
added for any of the three legs**, so the fix shipped provably untested:
- No test calls `updateHouseholdSize(n)` (with displayName left empty / on an unloaded shell) then `saveProfile()`
  and asserts `true` — the one existing related test
  (`user_profile_viewmodel_test.dart:759`, "a household change on a not-yet-loaded profile arms Save") still only
  checks `hasUnsavedChanges`, never calls `saveProfile()`. This is the exact gap the prior entry named, still open.
- No test in `user_service_test.dart` passes `displayName: ''` to `createOrUpdateProfile` and asserts the saved
  profile keeps `existingProfile.displayName` — every existing call in that suite passes a non-empty name.
- No test asserts `viewModel.error` is non-null after the invalid-form save path
  (`user_profile_viewmodel_test.dart:623`, "should reject save with invalid form" checks only the boolean `result`).
- The new `isSaving` getter/re-entrancy guard (`if (_isSaving) return false;` in `saveProfile()`) has **zero**
  references anywhere in `user_profile_viewmodel_test.dart` — the double-tap guard the fix moved from the view's
  local `State` field onto the VM has no test proving a second concurrent `saveProfile()` call short-circuits
  (needs a `Completer`-backed mock answer to hold the first call in flight).
- `household_size_view_test.dart`'s `_FakeUserService.createOrUpdateProfile` resolves synchronously
  (`async => _profile`, no delay) — even a widget-level double-tap test can't observe `viewModel.isSaving` mid-save
  with today's fake; it needs a controllable delay (e.g. a `Completer`) to pin the button's `isLoading`/`canSave`
  wiring to `viewModel.isSaving` instead of the deleted local `_saving` flag.
**Pattern:** a same-day review can name the exact missing test and the fix can still land without it — grep the
suite for the new getter/state name (`isSaving`, the new UserService branch) before trusting "existing suites
pass" as evidence of coverage for a just-landed fix.

---

### 2026-07-19 — Trigger: emulator integration test wired to nothing CI runs
**Context:** BUT-1633 added `enforce-group-minor-membership.integration.test.ts` (child-safety
group-minor gate) + a `test:integration:enforce-group-minor-membership` npm script.
**Bug caught:** the new test executes in ZERO CI lanes. Two CI runners
(`functions/scripts/run-ci-unit-tests.js` for cloud-functions-unit.yml, and
`functions/scripts/run-all-tests.js` for `npm test`) both auto-discover `test:*` but EXCLUDE
the `test:integration:` and `test:rules` prefixes. The only lane that runs emulator-bound
integration tests is `firestore-rules.yml`, which runs `npm run test:rules:all` — a
HARDCODED chain. New integration tests are invisible to it unless explicitly appended.
**Rule:** when adding a `functions/` emulator integration test, appending the granular
`test:integration:*` script is NOT enough — you MUST also append
`&& ts-node src/__tests__/<name>.integration.test.ts` to the `test:rules:all` script in
functions/package.json (the 6 sibling integration tests are already chained there) AND add the
file to firestore-rules.yml's `paths:` trigger lists (both pull_request and push). Otherwise
the safety test ships green-forever and never guards. Same failure family as the digest lesson
"adding the granular script, forgot to extend the composite chain."
**Also noted:** in an integration test, `const after = (await ref.get()).data()!;` followed by
`after.participantIds` and only THEN `assert(after !== undefined, ...)` makes the friendly
assert dead — a missing doc throws a raw TypeError one line earlier. Order the existence assert
BEFORE the first dereference and drop the `!`.

---

### 2026-07-19 — Trigger: review of BUT-1631 protein-tag fallbacks (menu/tagging)
**Context:** BUT-1631 broadened `Phase1NutritionCalculator.calculateProteinTags` to add an
unconditional generic tag for the WHOLE group (`fågel` for any `protein/meat/poultry`,
`växtprotein` for any `protein/plant-based`), mirroring the pre-existing `fisk` fallback, so an
unrecognised protein still counts toward the weekly protein-balance cap (BUT-1324).
**Correctness concern caught (not a test bug — a design regression a test can't see):** the
"whole group is center-of-plate protein" assumption holds for `protein/seafood/fish` and
`protein/meat/poultry`, but is FALSE for `protein/plant-based`. In the live register
(`docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv`) that group also contains vegan
DAIRY-ALTERNATIVES + seasonings — kokosyoghurt, havre/soja-yoghurt, näringsjäst, and the whole
`vegansk ost/grädde/crème fraîche/gräddfil/kvarg/fetaost/vispgrädde` family. A recipe using any
of these as a splash/topping now emits `växtprotein` → `ProteinCategory` buckets the whole dish
as a plant-based-protein dinner, polluting the balance nudge. Before the change these emitted no
protein tag. Soft-nudge system so Medium, not safety-critical, but a genuine regression.
**Reusable rule:** when a tagger adds a GENERIC group-wide fallback tag, verify against the real
register that the Firestore `group` is homogeneous for the concept being tagged — grep
`awk -F, '$4=="<group>"{print $2}' docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv`. A
catch-all group (`protein/plant-based`) is NOT the same as a tight one (`protein/seafood/fish`).
A unit test with a synthetic ingredient can't catch this — the test author picks a genuine
protein (ärtprotein) as the "unrecognised" case and never a dairy-alt, so the false-positive
class stays invisible. When reviewing group-fallback changes, enumerate the group from the CSV.
**Also (Low):** the broadened duck branch uses `contains('ank')` checked BEFORE the `kalkon`
branch — order-fragile. Safe against today's register (only real duck items contain 'ank') but a
future poultry name with an 'ank' substring (a "…skank"/shank cut) mis-tags as duck. Check
species branches before a broad stem, or anchor the stem.
**Positive:** the drift-guard test (`menu_service_test.dart:1711`) reads the real
`Phase1NutritionCalculator.proteinTags` const and compares to `ProteinCategory.allTags` (derived
from the map, not hand-copied) — correct shape; a vocabulary drift fails the build. Verified both
sets = 24 identical tags by hand.

### 2026-07-20 — Substring-containment tag guards need an adversarial name probe, not a curated name list
**Trigger:** Reviewing the BUT-1631 salvage tests for `Phase1NutritionCalculator.calculateProteinTags`.
The new plant-dairy-alternative guard and its 8 test cases were both derived from the same
hand-picked list of register names ("vegansk vispgrädde", "kokosyoghurt", …), so the suite could
not fail — it enumerated exactly what the implementation was written to handle.
**Pattern:** for any `contains()`-based classifier, do not review by reading the curated cases.
Write a throwaway probe test that feeds every *sibling* name from `lib/constants/known_ingredients.dart`
through the real function and prints the emitted tags. That took ~2 minutes here and surfaced a
real bug the curated suite missed: `växtfärskost` (plant cream cheese) emits `växtfärs` because the
specifics loop matches `växtfärs` as a substring — the identical trap the author had already guarded
for bare `'ost'` inside `'rostad'`, one loop lower. Also surfaced: the guard requires the literal
word `vegansk`, so `växtcreme` / `växtfeta` / `sojaqvarg` / `sojagurt` / `havregurt` / `kokosgurt` /
`jästflingor` / `inaktiv jäst` / `veganskt smör` all still emit `växtprotein`.
**Rule:** a containment guard ships with (a) at least one test whose input was NOT in the list the
guard was written from, and (b) a pinned negative for the substring family (`X` vs `…X…`).

### 2026-07-20 — A "returns null on permission denial" test needs a positive control in the same test
**Trigger:** BUT-1558 removed `uploadImage`'s duplicate `_validateUploadPermission`, relying on the
inner `uploadImageData` check. The regression test asserted `uploadImage(foreignPath) == null` + no
bytes stored. But `uploadImage` also returns null when `compressImage` fails on the fake `MockFile` —
so with the permission gate deleted AND compression bailing, the test still passes, proving nothing.
**Rule:** any "denied ⇒ null / no side effect" test must first (or last) run the *identical fixture*
against an allowed path and assert it SUCCEEDS. Only then is the null attributable to the gate.
Applies to every repository permission test, not just storage.

---

### 2026-07-20 — BUT-1629 minor searchability opt-in: whole client path shipped with ZERO tests + silent-failure bug
**Trigger:** reviewed the `setProfileSearchability` slice (CF + `ProfileSearchabilityService` +
`UserProfileViewModel.setSearchableOptIn` + `privacy_section` toggle).

**Coverage fact worth the grep:** `grep -rn "setSearchableOptIn\|ProfileSearchabilityService" test/`
returns **zero hits**. The only new Dart test in the diff is the BUT-1459 `isSaving` re-entrancy
guard. The safety-critical method (the ONLY path a minor can become discoverable) and its
post-save re-assert are entirely unexercised. Same failure family as the 2026-07-18 BUT-1594
entry: a slice lands, the *adjacent* new test passes, and "existing suites green" is mistaken
for coverage. **Always grep the suite for the new method NAME, not the file.**

**Bug caught — `safeExecute` swallows the error unless `customErrorMessage` is passed.**
`error_handling_mixin.dart:133-137` only calls `handleUserError` when `customErrorMessage != null`.
`setSearchableOptIn` (`user_profile_viewmodel.dart:143-155`) passes none, and
`privacy_section.dart:46` discards the returned `false`. Result: a minor's opt-in that fails
(offline, `resource-exhausted` from the new 10-token bucket, App Check, `failed-precondition`)
snaps the switch back with **no message at all**. Reusable rule: any VM method wrapping a
user-initiated network action in `safeExecute` needs `customErrorMessage:` or the caller must
render the `false`; a test asserting only the returned bool will not catch the missing feedback —
assert `viewModel.error`/`hasError` too.

**Bug caught — swallowed failure followed by an unconditional optimistic copyWith.**
`user_profile_viewmodel.dart:410-414`: `_reassertMinorSearchability()` catches and logs
(`:170-175`), then lines 411-414 force `isSearchable: true` onto BOTH profiles regardless. On a
failed re-assert the server holds `false` while the UI renders ON and `hasUnsavedChanges` is
false, so nothing retries. **Pattern: a best-effort side effect must return its success and gate
the local state sync on it** — "best-effort" applies to the WRITE, never to the state mirror.

**Missing in-flight guard asymmetry.** The same commit added a re-entrancy guard to `saveProfile`
but not to `setSearchableOptIn`, which is the one calling a rate-limited CF, from an always-enabled
`SwitchListTile`. Rapid toggles race and last-response-wins. When reviewing a diff that introduces
an in-flight guard, check the OTHER new async entry points in the same file for the same need.

**Rate-limit budget sharing (cost/behaviour, invisible to unit tests):** every ordinary profile
save by an opted-in minor spends one `setProfileSearchability` token (`:409`) from the same
10-token/5-per-min bucket as the deliberate toggle. Exhaustion is swallowed ⇒ silent loss of
discoverability. When a new rate-limiter key is added, enumerate ALL call sites of the limited
callable, not just the user-facing one.

**Verified-good, do not re-flag:** (a) the CI lane IS wired — `test:set-profile-searchability`
carries neither the `test:rules` nor `test:integration:` prefix, so `run-ci-unit-tests.js`
auto-discovers it (checked against the 2026-07-19 trap entry). (b) The PP6 rules test in
`age-gate-rules.test.ts` is a strong pair: Admin-SDK write of `isSearchable:true` for a minor
survives, and the same minor's CLIENT write of the *identical already-stored* value is still
denied — proving the deny is diff-gated on the new value, not the old. Reuse that
privileged-write-then-client-write-same-value shape for any "server path is the audited
exception" rule.

**Gap in the CF suite:** `set-profile-searchability.test.ts` covers only
`setProfileSearchabilityWithDeps`. The `onCall` wrapper's `unauthenticated`, the
`typeof searchable !== "boolean"` → `invalid-argument` guard, and `enforceRateLimit` are
untested — the boolean guard matters because a string `"true"` would otherwise merge into
`public_profiles`. Also the "idempotent" case asserts convergence but never `writes.length`,
so it cannot distinguish idempotent from wrote-twice.

### 2026-07-20 — BUT-1628 clearError disposal-guard sweep: two quadrants, only one of which `returnsNormally` can test [trigger: review of the 11-VM clearError guard sweep]
Reviewed the `if (isDisposed) return;` sweep across 11 viewmodels' `clearError()`. The guards are
correct and analyze/tests are green, but the sweep shipped with **zero regression tests** — none of
the 11 test files was touched, and every existing `clearError` test only exercises the alive path.

**The load-bearing insight: the 11 VMs split into two quadrants that need DIFFERENT assertions.**
- **Quadrant A — delegate is disposed by `dispose()`** (menu→`_stateManager`, archive_import→
  `_importManager`, collaborative_shopping→`_itemOperationsManager`, realtime_menu→`_state`,
  add_members/universal_share→managers). The delegates' `clearError()` call `notifyListeners()`
  unconditionally (verified: `menu_state_manager.dart:68-71`, `archive_import_operations_manager.dart:92-95`),
  so an unguarded post-dispose call THROWS. Test = `dispose()` → `expect(vm.clearError, returnsNormally)`
  + `expect(notified, 0)`. Non-vacuous.
- **Quadrant B — delegate is a SERVICE that OUTLIVES the VM** (recipe_list, unified_recipe,
  unified_shopping, auth). Nothing throws here — the service is alive. **`returnsNormally` is VACUOUS
  in quadrant B.** The discriminating assertion is that the SHARED service error SURVIVES: seed
  `service.error`, dispose the VM, call `clearError()`, assert the error is still set. That pins the
  actual behaviour change (a dead VM must not wipe an error another live listener is still showing).
Mutation-verified: deleting the three guard lines turns exactly the three added tests red, 0 collateral.

**Harness note:** these test files' `tearDown` disposes the shared `viewModel`, so a disposal test
MUST construct its own local VM (a second `dispose()` in tearDown trips ChangeNotifier's
double-dispose FlutterError). Reuse the setUp mocks; the local VM's own subscriptions die with it.

**Production finding worth carrying:** `menu_viewmodel.dart` and `recipe_list_viewmodel.dart` each
keep a LOCAL `_isDisposed` set at the START of `dispose()` precisely because (per menu's own comment
at L38-44) `BaseViewModel.isDisposed` only flips inside `super.dispose()`, which those VMs call LAST —
after the delegates are already disposed. The new guards use the BASE `isDisposed`, so they do not
cover the intra-dispose window the local flag exists for. Same shape for the `isStreamDisposed` users
(archive_import, unified_recipe): `disposeStreamResources()` runs AFTER the managers are disposed.
Post-dispose calls (the real-world case) ARE covered; the window is narrow. `realtime_menu_viewmodel`
is the one that got it right — it guards on `_isDisposed`. **Rule: when a class carries both a local
and an inherited disposal flag, a new guard must use the one the class's own callbacks use, or it
silently guards a later moment than intended.**

---

### 2026-07-20 — trigger: sprint review of minor-searchability (BUT-1629/BUT-1637) user-service slice

Reviewing `lib/services/user_service.dart`, `lib/repositories/firebase/firebase_user_repository.dart`
and their tests. Production logic is coherent (verified: `UserProfile.toFirestore()` forces
`isSearchable:false` when `isMinor`, and `toFirestoreEditable()` inherits that — so the
BUT-1637 "full save clobbers a minor's opt-in, re-assert via callable" premise holds). No
production correctness bug found.

**Pattern caught — safety-critical service methods tested only at the ViewModel mock layer.**
Two children's-data paths had NO test at their own layer:
- `UserService.setMinorSearchable(bool)` — the deliberate minor opt-in path (the whole point of
  BUT-1629). It is *mocked* in `user_profile_viewmodel_test.dart` (`verify(() => mockUserService.setMinorSearchable(true))`),
  which proves the VM CALLS it but never exercises its contract: returns the SERVER's stored
  value (not the requested one), updates `_currentUserProfile`/cache to that server value,
  returns null + sets `error` when the callable fails, notifies.
- `FirebaseUserRepository.fetchPersistedSearchable(uid)` — the server-authoritative read the
  entire cross-device safety hinges on. Mocked in every service test, so a regression in the
  impl (dropping `Source.server`, or loosening `data()?['isSearchable'] == true` to a truthy
  check, or not throwing offline) is invisible.

Lesson: when a service method wraps a Cloud-Function callable for a safety gate, grep for a test
at the SERVICE/REPO layer, not just a `mockService.method` verify in the caller's test. A mock
`verify` proves wiring, never the wrapped contract.

### 2026-07-20 — optimized_image_loader_test review (perf-cache-test-backfill) [trigger: reviewing a legacy widget-test backfill around the BUT-1639 cache-recorder]
The `ImageLoadCacheRecorder` group (BUT-1639 hit-rate 50%-floor guard) is the one genuinely
good part — it pins a domain invariant (a download must never also score a hit) via singleton
delta assertions, and would go red if either guard were removed. Reuse that before/after-delta
shape for tests against the process-global `ImageMemoryCacheManager` singleton (it has no reset).
But the rest of the file is a catalogue of the BUT-368 anti-patterns:
- **Named-for-behaviour, asserts-only-topology.** "should show error widget on image load
  failure" / "should show default error widget" / "should show placeholder when provided" all
  assert `find.byType(Stack), findsWidgets` and never trigger the error/placeholder path
  (CachedNetworkImage never resolves in a unit test, so `_hasError`/placeholder opacity never
  change). They pass green while proving nothing the name claims — false confidence. To actually
  test the error path you must pump a fake `HttpClient` that 404s (or extract the error-widget
  selection to a pure function and test that).
- **Vestigial tests kept green after the code was gutted.** `getOptimizedUrl` is now a one-line
  pass-through, yet there are 6 near-duplicate tests (Cloudinary/imgix/query-param/"unsupported
  provider") all asserting the same identity, plus "should not add progressive parameter when
  disabled" which asserts `isNot(contains('progressive'))` on a URL that never contained it —
  vacuously true regardless of the `progressive` flag. One identity test is enough; delete the
  rest instead of renaming removed-feature tests to fit the stub.
- **Dead `MockBuildContext extends Mock implements BuildContext`** declared and never used;
  mocking BuildContext is itself discouraged.
Rule reaffirmed: after a production method is reduced to a stub/pass-through, DELETE its old
behaviour tests — don't keep them green by asserting the trivial new contract N times.

### 2026-07-20 — data-integrations retry review: two "retries" that never retry [trigger: review of retry_helper.dart + extraction_manager.dart]
Reviewed `lib/core/utils/retry_helper.dart`, `lib/services/extraction/extraction_manager.dart`,
and `test/unit/core/utils/retry_helper_test.dart`. Two silent no-op retry bugs, both hidden by
tests that only exercise the success path.

- **`ExtractionManager.extractFromUrl` (extraction_manager.dart:117-120) — retry is inert.** It wraps
  `withRetry(() => _webScraper.performExtraction(...), maxAttempts: 2)`. But `withRetry`
  (`lib/utils/retry_policy.dart`) only retries when `op()` THROWS a `defaultIsRetryable` exception.
  `WebScraper.performExtraction` (web_scraper.dart) NEVER throws on transient failure — every error
  path (timeout timer, `onReceivedError` network error, parse catch, outer catch) completes its
  Completer with `ExtractionResult(success:false, reason:'network')` and returns a RESOLVED future.
  So `withRetry` sees success and returns on attempt 1; a transient network blip is never retried.
  The lesson: **a retry wrapper keyed on thrown exceptions is dead over an API that signals failure by
  return value.** Fix = inspect `result.success`/`reason` and loop, OR make the scraper throw a
  transient exception. A test that mocks WebScraper to return two network-failure results then a
  success and asserts `performExtraction` was called twice would have caught it (currently no
  extraction_manager test exists).
- **`RetryableOperation` extension (retry_helper.dart:384-417) — can't retry.** It wraps `() => this`
  where `this` is an already-started `Future`. Re-awaiting a completed Future replays its cached
  error; the operation never re-runs. So `apiCall().retryWithBackoff()` (the exact usage the class
  doc advertises at line 41) burns the backoff delays but can never recover. Unused in prod today
  (all prod callers use the STATIC `RetryHelper.retryWithBackoff(() async {...})`), but it's public
  API. The existing tests (retry_helper_test.dart:296-316) only pass `Future.value(42)` — success
  passthrough — so they green-light a broken retry. **Rule: an extension-on-Future can never be a
  real retry primitive; retry needs a factory `() => op()`, not a live Future.**
- Minor, same file: `maxRetries` is really "max total attempts" (`while attempt < maxRetries`,
  attempt starts 0 → maxRetries=3 gives 3 executions = 2 retries), diverging from retry_policy.dart's
  correctly-named `maxAttempts`; the class docstring at line 97-98 still claims "Deterministic delays"
  though jitter was added at 151-159; and `retryNetworkOperation` matches error strings case-sensitively
  while `retryFirebaseOperation` lowercases first.

---

### 2026-07-20 — [trigger: reviewed a SharedPreferences key-rename migration] Fallback-read precedence needs its own test
`InAppReviewService` renamed `last_in_app_review_prompt_at` → `..._v1` with a read fallback
`prefs.getInt(newKey) ?? prefs.getInt(legacyKey)`. The added test only covers legacy-key-present-
within-cooldown (negative). It does NOT pin the **precedence when BOTH keys exist**: a swapped `??`
order (`legacy ?? new`) would let a stale legacy timestamp win over a recent new-key prompt and
re-spam the OS dialog — and no existing test catches it, because every test sets only one of the two
keys. **Rule: any `newKey ?? legacyKey` migration fallback needs a both-keys-present test asserting
the new key wins (recent new-key value must block even with an old legacy value present), plus the
positive direction (legacy-only, past-cooldown → DOES fire).** Cheap, and it's the exact refactor a
future cleanup is likely to break.

### 2026-07-21 — [trigger: salvage review of BUT-1637 + BUT-1640 disposed-guard tests] The "clearError-after-dispose is a no-op" test is triple-guarded and cannot fail
`BaseViewModel` already guards disposal in TWO independent places: `clearError()` itself opens with
`if (_isDisposed) return;` (base_viewmodel.dart:136) AND the overridden `notifyListeners()` is
`if (!_isDisposed) super.notifyListeners()` (base_viewmodel.dart:246). A subclass that adds its own
`clearError` override with a third `if (isDisposed) return` (recipe_detail_viewmodel L646,
add_members_to_group_viewmodel L339) is pure defense-in-depth. A test that disposes a local VM then
asserts `clearError` `returnsNormally` + `notified == 0` therefore **cannot go red by removing the
subclass guard** — the base clearError guard returns before `notifyListeners`, and even if that were
gone the base notify guard swallows it. To fail, all THREE guards must be deleted at once, at which
point dozens of other suites red first. These tests are **vacuous** (LOW severity — not harmful, just
zero-sensitivity coverage of a contract the base class already enforces process-wide). The
recipe_detail comment overclaims ("without the notifyListeners guard this would throw") — false, the
clearError guard short-circuits first; the add_members comment is honest ("locks the observable no-op
contract rather than catching a live crash today").
**Rule: a disposed-guard no-op test only earns its keep when the guarded call has an OBSERVABLE side
effect that a disposed VM must NOT perform and that is NOT already blocked by a base-class guard.** The
sound shape is the sibling test — `RecipeDetailViewModel` "late shared-service emission after dispose
never touches the dead VM": it disposes, then pushes a `stateStream` emission and asserts
`recipe.title` is UNCHANGED. That one WILL go red if `_recipeServiceSubscription?.cancel()` is dropped
from `dispose()`, because `_onRecipeServiceUpdate` mutates `_recipe = updatedRecipe` (L196) BEFORE the
guarded notify — the state mutation, not the notify, is the load-bearing assertion (notify is guarded
so `notified==0` proves nothing there). Prefer that pattern; delete or upgrade the bare clearError
no-op tests.

### 2026-07-22 — [trigger: review of BUT-1486 parse-tier vocabulary single-sourcing + parse_correction_uploader]
Two durable patterns from this sprint's "parsing" review:

1. **New telemetry-loss behaviour shipped with zero tests.** `ParseCorrectionUploader` (BUT-1486)
   added a `parseCorrectionUploadDropped` analytics event on FOUR drop paths (`unknown_tier`,
   `no_salt`, `payload_error`, `salt_error`) — the whole point being "silent losses are measurable."
   The 46 new test lines only covered the tier map; not one asserts a drop metric fires. It IS
   testable: `AnalyticsService.tryLog` resolves via `ServiceLocator.tryGet<AnalyticsService>()`
   (analytics_service.dart:82), so register a mock AnalyticsService and `verify(() => mock.logEvent(
   name: AnalyticsEvents.parseCorrectionUploadDropped, parameters: any(named:'parameters')))`. The
   `unknown_tier` path is the trivial one (pure sync, no salt/prefs): build a correction with a
   diffed field + a bogus `successfulTier`, call `upload`, assert the drop fires with
   `reason:'unknown_tier'` and the offending tier. **Rule: when a diff's stated purpose is "make X
   measurable," the emit-on-X path is the load-bearing behaviour — test it, not just the happy map.**

2. **Cross-language "single source of truth" that leaves one copy unguarded is not single-sourced.**
   `functions/src/shared/parse-tier-vocabulary.ts` was created to kill three hand-synced tier copies,
   and it exports `DART_TIER_NAMES` explicitly "for" copy #3 (`log-parse-event.ts`). But
   log-parse-event.ts STILL declares its own private CamelCase `VALID_TIERS` (L50-53), does not import
   the shared module, and — being unexported — cannot be pinned by the new
   `parse-tier-vocabulary.test.ts`. So copy #3 can still drift silently, which is the exact bug
   BUT-1486 set out to remove. **Rule: a consistency-test suite proving "single-sourcing" must import
   and pin EVERY copy it claims to unify; a copy the test can't reach isn't guarded. Verify by
   grepping for other declarations of the same vocabulary before trusting the suite's green.** Also:
   the Dart drift guard and the TS drift guard each pin their own side against a hand-written literal
   (`canonicalMapping` / `CANONICAL`) — cross-language drift is only caught while those two literals
   stay byte-identical by hand; there is no mechanical link between them (inherent to Dart-can't-
   import-TS, documented, accepted).

### 2026-07-22 — AnalyticsService.tryLog IS testable via the ServiceLocator seam (BUT-1486 review)
Trigger: reviewing salvaged BUT-1486 tests for `ParseCorrectionUploader`. Production added
four `_emitDropMetric` call sites (`unknown_tier` / `no_salt` / `payload_error` / `salt_error`)
via `AnalyticsService.tryLog(...)` — the whole point of the ticket being "make the loss
measurable instead of silent" — but ZERO tests asserted any emission fired. The tempting
excuse "static telemetry, no seam to intercept" is FALSE: `AnalyticsService.tryLog` resolves
its target with `ServiceLocator.tryGet<AnalyticsService>()` and calls `logEvent(name:, parameters:)`.
So a `MockAnalyticsService` registered via `TestServiceLocator.registerMock<AnalyticsService>(...)`
+ `verify(() => mock.logEvent(name: AnalyticsEvents.parseCorrectionUploadDropped, parameters: any(named:'parameters')))`
covers every drop path — including asserting the `reason` param value. Rule: when a ticket's
deliverable IS a fire-and-forget metric emitted through `AnalyticsService.tryLog`/`logEvent`,
that emission is a testable contract (event name + reason param), not "just telemetry" —
assert it fires, or the silent-loss it was built to prevent can regress unnoticed.
