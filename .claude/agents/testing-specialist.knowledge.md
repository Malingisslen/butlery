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

_Compacted 2026-06-01 (BUT-1177): older entries condensed to their reusable lesson; verbose code examples trimmed. No distinct learning removed — only merged or summarized. The ~8 most recent entries are kept fuller._

*Append new dated entries below as the agent learns them. Trigger-tag each
entry: [Bug found] / [Pattern discovered] / [Helper added] / [User correction].*

### 2026-04-25 — initial seed
Seeded from `testing-specialist.md`, `MEMORY.md`, BUT-368/369 bug list.

### 2026-04-26 — A11y P2 + social safety [Pattern]
`lib/views/*` changes need NO new view tests (Phase 6 deleted that lane); theme files covered by golden + targeted contrast, not structural "uses AppColors.X" tests.

### 2026-04-30 — BUT-696 Viterbi golden-set fixtures [Pattern]
Golden-set rules: sibling `*_fixtures.dart` with typed records + explicit `expected: LineType?` (`null` = opt out, sparingly) + a fixture-sanity test (`>= N scorable lines`). **Print-then-assert accuracy** with baseline ~3pp below measured = free CI regression diff. Construct synthetic `ClassifiedLine` literals to isolate the algorithm (dial confidence). `identical(out[0], in[0])` pins short-circuit/no-copy. **Boundary-survival tests** (length-preservation + no-crash at the boundary), not exact post-boundary values, for edge mechanics.

### 2026-04-30 — BUT-611 Viterbi calibration [Pattern]
Hyperparameter sweeps: a non-default value "wins" only when the gap beats the noise floor (2pp) on BOTH golden + held-out at the SAME threshold (single-corpus wins = noise). Promote `static const` → ctor params with matching named defaults so tests sweep without mutating production. **Decision metric ≠ diagnostic metric** — optimize for the system's metric (end-to-end accuracy), not the easy one (F1 inflates on imbalanced classes). Commit a baseline `.md` for prose the loose asserts can't carry. Cross-corpus phrase-reuse is a generalization probe; only vocabulary overlap is leakage.

### 2026-04-30 — BUT-458 fail-soft resolver [Pattern]
For a resolver that NEVER throws (every failure → `null`): test the null contract **per failure mode** (each maps to a different degrade-mode). Pair with happy-path + fallback wiring tests through the real caller asserting doc-level effects (empty-list fallback present-not-missing — the rule's `in []` depends on it). Pin owner in `recipeOwnerId` NOT `sharedWithUserIds`. Don't apply where missing data should be a hard error.

### 2026-05-01 — BUT-746/747/748 GDPR cascade [Pattern + Bug]
**Documented-residual tripwire**: pin a known-wrong assertion with "flip when fixed"; on flip keep the same `field` arg, change only the matcher. `FieldValue.arrayRemove`/`arrayUnion` + fake_cloud_firestore + batched `update` = **silent no-op** → use explicit read-modify-write (`raw.where((id)=>id!=userId).toList()`); emulator lane if atomic semantics required. **Field-name canonicalisation is a GDPR risk** (BUT-748: writer `blockedId` vs reader `blockedUserId` → zero incoming blocks, Art 15) — when a field name spans TWO repos, write a cross-repo round-trip test.

### 2026-05-01 — BUT-688/691/... sprint [Pattern]
**Pluggable callable typedef beats plugin-channel mocks** (`typedef Fn` ctor param + default wiring the real plugin; tests pass an inline closure). Inline byte-fixtures for binary detectors. **GetIt swap for lazy singletons** resolved via `ServiceLocator.get<T>()` in fire-and-forget code. `Future.delayed(Duration.zero)` IS acceptable for fire-and-forget probes (event-loop pump, no clock — don't reach for fakeAsync). `@visibleForTesting` call-counter beats asserting deleted-field doc shape (avoids `FieldValue.delete()` fake drift).

### 2026-05-02 — BUT-751/752/692/732 multi-listener [Pattern]
`GetIt.asNewInstance()` for helper tests taking a `GetIt` param (no global state). **Multi-listener API: test the failure modes it was designed to fix** (co-subscribers, listener-throws-doesn't-block-others, idempotent-add pins `Set` not `List`). **Negative-space slug tests for opaque-token redaction** — pair every "strip" with a "keep" at adjacent thresholds, else `s/.*/redacted/` passes. Schema-correction inline comments document the prior fixture was WRONG (phantom field).

### 2026-05-02 — BUT-752 idempotent-add drop [Pattern]
Adopting `Listenable`/`ChangeNotifier`, test FLUTTER's contract not the bespoke one (ChangeNotifier fires twice for a double-added listener; pinning the old `Set` idempotency locks the impl). Drop is honest IF call sites don't rely on idempotent-add (verify first).

### 2026-05-02 — BUT-573/434 untestable-by-design [Pattern]
**"New lines of production code" ≠ "new test surface."** A private method, called from another private method, gated by static state, over a static-final external dep (`static final FirebaseMessaging _messaging`) is architecturally untestable in isolation — document the constraint, don't manufacture a smoke test. Min-viable seam: make the static dep `@visibleForTesting` mutable or constructor-inject.

### 2026-05-02 — BUT-754 fan-out listener wire-up [Pattern]
**A fan-out listener whose body is `read state → forward to one already-tested method` needs no own test** (risk = "is it subscribed?" + "does downstream handle it?", both proven elsewhere). Promote to a testable seam only when the body grows real logic (debounce, transform, conditional fan-out, analytics).

### 2026-05-02 — BUT-755..758 color-token migration [Bug found]
Tests pinning literal hex on PRODUCTION OUTPUT break when production swaps `AppColors.X → cs.X` (bare `MaterialApp` has no theme → `cs.primary` = Material default purple). **Before claiming a color migration is mechanically safe, grep `test/` for `== AppColors\.` and `== AppDimensions\.`.** Minimal fix: install `theme: AppTheme.lightTheme`. Long-term: capture `ColorScheme` via `Builder`.

### 2026-05-02 — BUT-600 parsing-golden tiers [Pattern]
**Service-level seam beats HTTP seam for LLM golden tests** (mock at `LlmService.structureRecipe`, hermetic <100ms, still exercises the tier contract). **Probe-then-pin** parser outputs (pin what it ACTUALLY emits, document quirks in `_note`). **Loose assertions** (`titleContains`/`ingredientCountMin`/`ingredientSubstrings`) survive parser tweaks. **Audit CI invocation when adding a test dir** — `test/golden/` was silently excluded from the `flutter test` command.

### 2026-05-04 — BUT-582 error-mapping switchboard [Pattern]
**Pin BOTH positive (code → message) AND negative (code != generic-fallback)** — the negative catches a refactor collapsing branches back to generic. Swedish↔English parity test catches "two codes → same template." **Decision rule: add tests for the changes where a regression silently changes user-visible behaviour AND the seam is cheap** (pure-function error-mapping passes both; fire-and-forget emitters + view-layer fan-out pass neither).

### 2026-05-04 — Sprint D (BUT-589/670/766) [Pattern]
**Counter on a `Fake HttpsCallable`** (increments-then-throws) proves "did the integration call its dep / did the CB short-circuit?" — assert `callCount` stayed at 3 across the 4th call, not just `breaker.isOpen`. Skip the `FirebaseFunctionsException` branch when its ctor is `@protected` (generic Exception hits both). `featureFlagServiceOverride` ctor param + `simulateConfigUpdate()` stub for the live-update contract. Pin "ServiceLocator not initialized" DISTINCT from "service missing".

### 2026-05-04 — Sprint F (BUT-682/630) [Pattern]
`same(<static-const-instance>)` for routing tests against const singletons (field-match passes for any future V2). "Without-init it's in-memory only" tests must also assert the external store stays UNTOUCHED. Concurrent-send tests are NOT a gap for single-isolate Dart services. `extends Mock` with a concrete `@override` body = anti-pattern; rename to `extends Fake`.

### 2026-05-05 — BUT-738 emitter extraction [Pattern]
When extracting analytics emitters, grep `test/` for the event/method name first; no hits ⇒ the emitter test is the new contract. `withClock(Clock.fixed(...))` for synchronous emitters reading `clock.now()`; `fakeAsync` only for time-elapsing async work.

### 2026-05-06 — CF helper unit tests + integration gap (BUT-778/780) [Pattern]
CF pure helpers: stub `process.env.FIREBASE_CONFIG` + `admin.initializeApp({projectId})` BEFORE `require()`-ing (triggers resolve eagerly); `require` not `import`. **Pure-helper tests don't prove the CF calls the helper** — the missing layer is an emulator-lane `*.integration.test.ts` (USE_EMULATOR, Linux CI). When a helper resolves identity from path conventions, audit patterns against the rules files. **Deletion-test pairing**: deleting a removed method's tests is correct (absent-grep is the proof); guard the remaining contract, don't add a "method doesn't exist" test.

### 2026-05-08 — BUT-815 timestampProvider seam [Pattern]
fake_cloud_firestore 4.x: `serverTimestamp()` in a batch makes `commit()` throw → catch returns null → doc never lands. Route through `BaseFirebaseRepository.timestampProvider` (prod unchanged via default `ServerTimestampProvider`; tests inject `TestTimestampProvider`). Prefer over working around the fake for "assert a batch wrote both docs."

### 2026-05-08 — HttpsCallable Fake for paginated CF [Pattern]
`HttpsCallableResult` has a private ctor (can't Mock): `_FakeHttpsCallableResult<T> implements HttpsCallableResult<T>` + `_ScriptedHttpsCallable extends Fake implements HttpsCallable` returning canned responses by `callCount`, throwing `StateError` on exhaustion (catches "asked for more pages than expected"); `receivedParameters` asserts cursor wiring. Sister: `_CountingHttpsCallable` for failure injection.

### 2026-05-19 — Sprint wave 3 (BUT-801/823/841/861) [Pattern]
**Distinguish "coverage gap" (no test for a path, P3) from "regression risk" (test exists but can go green incorrectly, P2).** DI-singleton-identity invariant = regression risk; SHA-mismatch error-envelope sub-paths = low-risk gaps. `safeString` wrong-type coercion = defence-in-depth only. `CircularProgressIndicator → StateWidget.loading()` was test-safe (no existing CPI finders against the migrated views).

### 2026-05-23 — Wave-14 BUT-1021 stream-error [Pattern]
**Recording-Fake for fire-and-forget analytics**: parallel `_captured*` slot + getter + `clear*` (don't switch to `verify()` — pulls it back to Mock-semantics). **`Future.delayed(10ms)` IS acceptable for draining an unawaited microtask chain in non-Flutter tests** (pumpEventQueue couples to flutter_test; fakeAsync has no timer). `contains('Sessionen')` over full-string equality for localized copy. Stream teardown: `controller.close()` BEFORE `dispose()`. **Mutual-exclusivity invariant tests for classifier getters** (each code matches EXACTLY one `is*` bucket + "unknown → all-false"). Arch-allow-list additions need an inline rationale comment.

### 2026-05-23 — Wave-17 BUT-932/1013 audit [Pattern]
**A behavior-contract change can make existing tests STALE assertions, not just incomplete** — rewrite/delete OLD-contract asserts in the SAME PR. Record returns: `expect(result, (added:0, overflowed:0))` (records are value-equal). `verify(() => repo.save(captureAny())).captured.single as Plan` (+ `registerFallbackValue`) beats a side-effecting `thenAnswer`. BUT-932 image-undo invariants: `removeImageAndCleanup` must `verifyNever` storage; `pendingDeleteCount==0` on empty queue; commit storage errors must NOT throw.

### 2026-05-24 — recipe_selection_dialogs facade [Pattern]
**For a thin facade whose inner dialogs hit `ServiceLocator.get` in `build()`, don't drive end-to-end** — (1) compile-time facade contract (touch static methods as Function refs); (2) construct inner widgets directly (ctors don't touch DI); (3) test leaf list items as pure StatelessWidgets. Anti-pattern abandoned: `showDialog` via NavigatorObserver + `takeException` (flaky, double-exception during dispose).

### 2026-05-24 — Scaffold contributes Positioned widgets [Pattern + Bug]
Migrating to `createLocalizedTestApp` (introduces a real Scaffold) can break `find.byType(Positioned), findsOneWidget` → matches 2. **When migrating to a Scaffold/Stack-introducing wrapper, audit all `find.byType(Positioned|Stack|ConstrainedBox|DefaultTextStyle)` and scope to the subject** via `find.descendant(of:..., matching:...)`, or use a behavioural assertion.

### 2026-05-24 — `FieldValue.serverTimestamp()` in toFirestore breaks fakes [Bug + Pattern]
A model's `toFirestore()` emitting a `FieldValue.*` sentinel breaks THREE test classes: pure-model round-trip (sentinel → null → `?? clock.now()` substitutes today), `FakeFirebaseFirestore` writes (`MethodChannelFieldValue` not `MockFieldValuePlatform`), seed helpers. Fix: hoist the sentinel into the repo layer, or inject `TestTimestampProvider`, or emulator lane. **Pre-commit: grep `test/` for every `<Model>.fromMap`/`.toFirestore` before approving a model adopting `FieldValue.*`.**

### 2026-05-24 — LlmEnhancementService [Pattern]
`_FakeLlmService extends Fake implements LlmService` with per-method `Response?`/`Throw?` + `int calls` + `last*Param` capture (assert invocations without mocktail, which fails silently against a Mock with concrete bodies). Gotcha: `ocrRecipeImage` has OPTIONAL `imageBytes`/`imageUrl` — fake override must match or `invalid_override`. Bug classes: canEnhance runs BEFORE rate-limit (else garbage burns budget); `isRateLimited → llmQuotaExceeded` not generic; tightening a catch to LlmException-only lets StateError propagate.

### 2026-05-24 — RecipeParserService + HtmlSanitizer trap [Pattern]
**`HtmlSanitizer.check()` does NOT flag raw `<script>` as critical** (silently stripped); only `data:text/html`, `\x00`, >5MB trigger `hasCriticalIssues` — a `<script>` security-gate test never trips; use `\x00`/`data:text/html,`. `_tiers` has no injection seam (a `tiers:` ctor param would unlock orchestration tests). LlmService stub via `implements` + `noSuchMethod` tracking call counts (cost guard).

### 2026-05-24 — import_rate_limiter [Pattern]
**`withClock(Clock.fixed(_t0 + Duration(...)), () => sut.method())` PER CALL** lets one test hit 59.999s AND 60.000s without fakeAsync (pin `_isInWindow` strict-`<`). **FakeFirebaseFirestore round-trips DateTime to local-zone** — anchor `_t0` with `DateTime(...)` not `DateTime.utc(...)` (else TZ offset → false greens). Fresh limiter (same repo+auth) = virgin cache. Fail-closed: `_ThrowingFirestoreRepository extends FirestoreRepository` overriding the `firestore` getter to throw. Cost cap uses `>` (0.50 allowed, 0.51 denied) — OPPOSITE of the count cap's `>=`; pin both.

### 2026-05-24 — SharedContentSearchViewModel [Pattern]
Debounced search via `fakeAsync` + 300ms `elapse` works for raw-`ChangeNotifier` VMs too. **Listener-capture for parent VMs subscribing to collaborators**: stub `addListener(any())` with `thenAnswer` capturing `positionalArguments.first as VoidCallback`, invoke manually. Strengthen "exactly one debounced call" by recording the actual query strings passed downstream. `withClock` OUTSIDE `fakeAsync` for date-filter tests.

### 2026-05-24 — UnifiedShoppingService (Batch 2) [User correction]
**A test file declaring a service "cannot be constructed in unit tests" + testing mock-on-mock was WRONG.** A unified service lazy-resolving via `ServiceLocator.get` inside `_initializeModules` CAN be wired with fakes + the bridge + the real service. Gotchas: `_startCollaborativeStream` only runs from `initialize()`; `addItemsBatch` dedup keys on trimmed-lowercased name AND unit; the fake repo exposes per-method `throwOnX` switches; `MockOfflineService` needs the `.database → .cacheDao` chain stubbed (lazy getter resolves).

### 2026-05-24 — UnifiedMenuService Firebase platform-channel scaffolding [Pattern + Bug]
For a SUT eagerly touching `FirebaseAuth.instance`, paste a Firebase-core mock into `setUpAll` (`TestFirebaseCoreHostApi.setUp(...)` + `Firebase.initializeApp()`). Three traps: Crashlytics is a MethodChannel (`setMockMethodCallHandler`); **`AppLogger.error → _logToCrashlytics` fires `.log()`/`.recordError()` WITHOUT awaiting — its sync try/catch can't catch the async-gap MissingPluginException; PRODUCTION BUG: `.catchError((_){})` the futures**; FirebaseAuth pigeon channels are BasicMessageChannel (`setMockMessageHandler` + `StandardMessageCodec.encodeMessage([result])`; listener registrations return a non-null String handle, not null). `+N ~3` = "passed with handled teardown noise", not skips.

### 2026-05-24 — RealtimeSyncService + parser-too-lenient [Pattern]
Wire a `FirestoreRepository`+`AuthRepository` service: LOCAL `FakeFirebaseFirestore` (not the singleton — in-flight streams attach to the old instance), real `FirestoreRepository(firestore: fake)`, local `_MockAuthRepository extends Mock` with `when()` stubs (the shared `MockAuthRepository` has a concrete `currentUserId` that bypasses `when()`). Flagged: `watchResource` swallows downstream errors to a side-channel `errorStream`; parser extremely lenient.

### 2026-05-24 — SharedRecipeViewModel dismiss-result-ignored [Bug found]
**BUT-1068: `dismissSharedRecipe` does `await coord.dismiss(...); return true;`** — discards the bool → on silent-false the VM hides the item then a refresh resurrects it. Fix: `return await coord.dismiss(...)`. Pinned with a `BUG:` test. Scaffolding: prod+test ServiceLocators share GetIt, so `registerMock` satisfies base-class lookups even with explicit-dep construction. `unintended_html_in_doc_comment` fires on `Foo<Bar>` in `///` — wrap in backticks.

### 2026-05-24 — UrlImportStrategy, batch 3 [Pattern + Bug]
**`InternetAddress.lookup` short-circuits on IP literals** — `http://8.8.8.8/recipe` URLs stay hermetic without a DNS stub. `TextImportStrategy.import` is intentionally lenient (never returns `assistance`) — Tier 5 "succeeds" on any non-empty HTML; pin the ACTUAL behaviour. Flagged: no `dnsLookup` seam; non-Recipe JSON-LD silently downgraded; tier-numbering inconsistency.

### 2026-05-25 — Batch 4: SharedMenuViewModel [Pattern]
**SharedMenuViewModel does NOT have the BUT-1068 bug** (same family, divergent impl). **Bool-propagation per-branch trio** is the only way to PROVE the distinction: true → returns true + side effect; false → false + NO side effect; throws → false + hasError + NO side effect (rules out four regressions). Also: `verifyInOrder` for clearCache-then-fetch; `markAsViewed` unauthenticated STILL returns true (write fires, cache-reload auth-gated); idempotent undismiss; per-item operating-state cleared on BOTH try/finally paths.

### 2026-05-25 — SocialRecipeService, batch 4 [Pattern + Bug]
**Fake a `UnifiedRecipeService` by overriding only the `personal` getter** (`Fake implements` overrides a `late final` field-as-getter without the real ctor). Pin silent-fail contracts with a `reason:` on BOTH the bool AND side-effect absence. Bugs: inconsistent `_error` population across the silent-fail family (dismiss sets it, undismiss/import/view don't); `_error` never cleared on success; `importSharedRecipe` returns true when sign-out races. Fakes dropping the named `limit` on `getMembersWithInfo` compile-fail `invalid_override`.

### 2026-05-25 — Batch 4: shared_shopping_viewmodel [Bug found]
**BUT-1069 (different root cause than BUT-1068): `loadContentWithPagination` re-implements pagination WITHOUT the dismissed/blocked/status-cache filters** in `loadContentFromRepository`, which the base flow goes through exclusively → filters are dead. Recipe sibling just `return loadContentFromRepository();`. Fix: same one-liner. Pinned 3 `PINS BUG` tests with inline flip instructions.

### 2026-05-25 — BUT-1072: `_activeListeners` dead code removed [Pattern resolved]
Confirms the 2026-04 RealtimeSyncService suspicion: dead, removed; the test pinning `isResourceWatched==false` mid-watch was protecting a bug-shaped contract, deleted with it. **When an entry says "either dead code or undocumented secondary path," prefer a deletion-PR over a pinning-test.**

### 2026-05-25 — YouTubeTranscriptService, batch 5 [Pattern + Bug]
**Characterization tests for permissive regexes** — pin ACTUAL behaviour in a `CHARACTERIZATION:`-prefixed test with the bug #; flipping is one line. Transcript-cleaner ordering bug: pin "no triple-spaces" not double to characterize without false positives. MockClient routing by `req.url.path`. **Dispose-ownership smoke test** for `client: http.Client?` + `_ownsClient` (injected client's `close()` NOT called; default-constructed `dispose()` `returnsNormally`). Bugs: host-boundary regex over-matches typosquats (no `^https?://(?:www\.|m\.)?youtube\.com/` anchor); `_cleanTranscript` ordering leaves double-spaces.

### 2026-05-25 — TikTokPipeline case-insensitive URL bug [Bug found]
**Host quick-check lowercases but `_tiktokPatterns` regexes are case-SENSITIVE** → `TikTok.com` passes the substring check, fails `hasMatch`, silently returns false. Fix: `caseSensitive: false`. (Recurs in Instagram + YouTube below.) For chained free→paid tiers, queue canned `ImportResultV2` on a `Fake LlmEnhancementService` (one per tier) + a `seenTranscripts` list to assert which text reached which tier.

### 2026-05-25 — SocialMenuCoordinator missing try-catch [Bug found]
**`joinSharedMenu` calls `read(...)` with NO try-catch** while siblings wrap + return null/empty → propagates uncaught into the UI (BUT-1086/1090). **Pattern: for coordinators hardwiring `FirebaseSharedMenuRepository()` in the ctor, use the dual-mock setup (Firebase Core host + two auth pigeon binary handlers) from `unified_menu_service_test`; test pure-logic methods directly, repo-touching methods only for early-exit branches; emulator lane for round-trip.**

### 2026-05-25 — SocialShoppingCoordinator: BUT-1094 confirmed [Pattern]
`joinSharedShoppingList` CORRECTLY wraps `read()` + sets error = the REFERENCE pattern. **BUT-1094: `getSharedShoppingListsForUser`/`loadStatusForShoppingList` + inherited base `markAsViewed`/`getUnreadCount` swallow errors WITHOUT `setError`** while siblings in the SAME file DO — pin broken-and-correct side by side. **Cleaner scaffolding: a coordinator going through `ServiceLocator.get<...Repo>()` (not direct instantiation) needs NO Firebase Core mock/pigeon handlers — just `GetIt.registerSingleton(mockRepo)` + the bridge.**

### 2026-05-25 — PresenceService RTDB mocking [Pattern]
**RTDB has no fake_cloud_firestore equivalent** — mocktail-stub `FirebaseDatabase`/`DatabaseReference`/`OnDisconnect`/`DataSnapshot` in a `_DbHarness` wiring per-path refs lazily. `FirebaseOptions` mockable via its const ctor (`databaseURL: null` for the bail-out guard). **mocktail gotcha: `verifyInOrder` + `verify(captureAny)` are mutually hostile across mocks** (verifyInOrder advances a global cursor → later captureAny finds zero) — SKIP verifyInOrder, verify each individually, document order as "structurally enforced" when syntactic. `WidgetsBindingObserver` needs `TestWidgetsFlutterBinding.ensureInitialized()`.

### 2026-05-25 — HtmlSanitizer surfaces non-JSON-LD `<script>` (BUT-1061) [Pattern]
`check()` now surfaces non-JSON-LD `<script>` as `warning` (not critical — real sites carry inline analytics). **Assert `hasCriticalIssues, isFalse` NOT `issues, isEmpty`** (intent = "gate didn't reject"). Or wrap in `<script type="application/ld+json">`. A `data-note="application/ld+json"` decoy still trips (lookahead anchors on `type=`).

### 2026-05-25 — Batch 7: shopping_item_management_module [Pattern]
Thin CRUD module with optimistic-update/rollback: constructor-inject a `Fake` repo with **per-method `Object?` error switches** (`throwOnAddItem`) — arming one exercises one rollback branch surgically. Counter-pattern: `UnifiedShoppingList.copyWith` has no `id` — use the full ctor.

### 2026-05-25 — Batch 7: shopping_social_share_module [Pattern + Bug]
**Bare `FakeFirebaseFirestore()` + `FakePermissionService` (skip `TestServiceLocator.initialize()`) when the module is constructor-injected** — `initialize()` installs `MockFieldValuePlatform` which fights real `serverTimestamp()` in batches; bare fake handles it cleanly. **Gotcha: `FakePermissionService.setPermissionState` forces `_isAuthenticated=true` if `currentUser` was set on a prior call** — build a fresh instance for unauth (`_unauthModule` helper). **FLIP-DETECTION for permission boundaries**: assert BOTH `out==null` AND `doc unchanged`. Bug: `importSharedShoppingList` `.update()` on missing pointer throws-and-swallows (use `.set(merge:true)`); missing-name fallback renders literal `?`.

### 2026-05-25 — Batch 7: BaseSocialCoordinator (abstract base) [Pattern + Bug]
**Test an abstract base via a private `_TestX extends BaseX`** supplying abstract bodies as programmable hooks + recording state (covers all 3 subclasses). **Bypass `MockUserService` for chained `when()`** (intermittent "No method stub" errors) — hand-roll `_FakeUserService extends Fake`. **Gotcha: `cloud_firestore` re-exports a `Type` class shadowing `dart:core.Type`** — avoid `Map<Type,_>` keys. **BUT-1094 root cause CONFIRMED in base** (`markAsViewed`/`getUnreadCount` catch+return-sentinel WITHOUT `_setError` — 2-line fix closes it across all 3 coordinators). Notification placeholders are TODO no-ops (pin "resolves quietly" as a canary).

### 2026-05-25 — InstagramPipeline + BUT-1092 sibling [Bug + Pattern]
Same case-sensitivity bug as TikTok (`Instagram.com` rejected — patterns need `caseSensitive: false`). `InstagramPipeline` constructs `WebScraper()` inline (no seam) — **document WHY coverage is shallow in the library doc** rather than leaving silent holes. **Drive `ImportNeedsScreenshot` naturally via `MissingPluginException`** (`HeadlessInAppWebView.run()` throws, WebScraper catches → no-caption path; needs `TestWidgetsFlutterBinding.ensureInitialized()`).

### 2026-05-25 — common_dialog_actions hardcoded-itemType [Bug found]
**`showRecipeDeleteConfirmation` etc. pass a HARDCODED Swedish `itemType` (`'recept'`)** → English locale renders "Delete recept?" (BUT-1088/1115 family). `_triggerButton<T>` helper. **Three pop-semantics distinct: `true`/`false`/`null`** (sentinel + `resolved` flag distinguishes "fired null" from "never fired"). Color-invariant via `Builder` + late `cs` capture. `FilledButton.icon` wraps the label in a private child (fall back to `find.text`). Split confirm/cancel into separate `testWidgets` (re-pumping leaks a route).

### 2026-05-25 — onnx_ner_service [Pattern]
ONNX services: `OnnxRuntime?` ctor param for init-failure; end-to-end inference needs the **platform interface** (`extends FlutterOnnxruntimePlatform with MockPlatformInterfaceMixin`, swap `.instance` via a `_withPlatform` try/finally — reusable for ANY `PlatformInterface` plugin); imports trip `implementation_imports` + `depend_on_referenced_packages`. **Highest-value ML test: label-index mapping through the SERVICE's own `_labels` const, NOT `BioLabel.values`** (orderings differ — catches "labels re-ordered without updating training script"). Inference-throws → list-of-nulls (CRF fallback, no rethrow).

### 2026-05-25 — SchemaOrgTier + dollar-sign gotcha [Pattern]
`htmlWithJsonLd(literal)` helper exercises real extraction without disk fixtures. `_RecordingStrategy extends IngredientParsingStrategy` overriding `parseLines` records the handoff. **Dollar-sign in `test(...)` descriptions (`'($0.18)'`) fails to parse (`$`=interpolation) — use a raw string `r'...'`.** **Tier failure-reason taxonomy is observable contract**: pin `noData` (no JSON-LD) vs `parseError` (present, no Recipe) — the orchestrator routes on these (BUT-1070).

### 2026-05-25 — Sprint-brief vs production-reality mismatch [User correction]
**Read the production file before trusting the brief.** A brief described "concurrency/retry/cancellation" but `UploadQueueManager` is a pure synchronous `Map` wrapper (zero Futures/Timers) — writing concurrency tests would violate Rule 3 + fail the intent gate. Steps: count Futures/Timers/Streams; if the brief talks about behaviour you don't see, write a SCOPE NOTE in the library-doc; cover what the file actually owns.

### 2026-05-25 — YouTubeImportStrategy, batch 9 [Pattern + Bug]
**Subclass a CONCRETE collaborator** (`_FakeTranscriptService extends YouTubeTranscriptService` overriding the 4 public methods) — avoids "extends Mock with @override bodies". Bugs: case-sensitive video-ID regex (`YouTube.com` rejected — BUT-1092 sibling, six patterns); `inputExample` not self-consistent (8-char `VIDEO_ID` vs 11-char regex). Verified present: BUT-980/1045 sourceUrl wiring (pinned with `withClock` proving `fetchedAt` from `package:clock`); "no transcript ⇒ no LLM" cost contract.

### 2026-05-25 — Batch 10: image_upload_coordinator [Pattern]
`AppLocale` defaults to Swedish at static init (no setup for `.current.*`). `registerFallbackValue(_FakeFile())` for `verifyNever(upload(any(),any()))`. `canBulkRetry`/`canBulkCancel` use strict `> 1`. **disposed/uploadsCanceled flags passed BY VALUE at method entry — a soft mid-flight flip is silently ignored** [fixed BUT-1129 below]. Clean seam: 3 callbacks constructor-injected.

### 2026-05-25 — Batch 10: site_config_tier [Pattern]
`_RecordingStrategy` stubs the CRF dep without mocktail. Seams: `preloadedConfig` (wins over `configLoader`); `configLoader` to assert the requested domain; `context.parsedDocument` mutable cache (pre-populate a DIFFERENT doc to prove cache-read); `withClock` for `metadata.timestamp`. Failure-mode tests that earn keep: `isSupported:false` skip, 0/9999 portions fallback, invalid CSS selector no-throw, non-http image URL rejected, strategy-failed → `noData`.

### 2026-05-25 — GlobalRecipeCache, batch 10 [Pattern]
A `BaseService` subclass needing ONLY `AuthRepository`: minimal 3-line bootstrap (no full `TestServiceLocator.initialize()`). **Constructor-inject pure-compute collaborators (`UrlNormalizer`, `ContentFingerprint`) with REAL impls** so a normalization regression breaks cache-collision tests. **Expiration: pin `clock` AND seed `cachedAt` as `Timestamp.fromDate(...)` directly** (don't round-trip `cache.save()` — `serverTimestamp()` masks reproducibility). `merge:false` overwrite test: write v1 with an extra field, save v2 without, assert `!containsKey`.

### 2026-05-26 — ResponsiveBuilder family [Pattern]
**Dual width-source widgets**: `LayoutBuilder` constraints vs `MediaQuery.size` — set `tester.view.physicalSize` (dpr=1.0) so both agree. Orientation derives from width:height ratio. **Pin breakpoint boundaries exactly: 599/600, 1023/1024** (a flipped `<=` shifts one device class). Passive accessor widgets: test by pumping a `Builder` calling the method inline. sed misses cross-line calls — re-run analyze after a rename.

### 2026-05-26 — DialogFactory + CPI pump pattern [Pattern]
**`pumpAndSettle()` HANGS on dialogs containing `CircularProgressIndicator`** (perpetual animation → 10s timeout). Use two-pump: `pump()` + `pump(Duration(milliseconds: 300))`. Bugs: `TextEditingController` per-call leak in `showFeedback`/`showTextInput`; `showDeleteConfirmation.itemType` raw-String English leak.

### 2026-05-26 — ApplicationBootstrap singleton [Pattern]
**Full-reset the singleton triple in BOTH setUp AND tearDown** (`ApplicationBootstrap().reset()` + `ServiceLocator.reset()` + `GetIt.instance.reset()`) else `_isInitialized=true` poisons later tests. **Zero-module + fake-stages walks the full bootstrap without Firebase** (`initialize(stages: [fakeStage])` skips Firebase validation because `hasUserScope==false` cold). Flagged: validate-failure re-wraps the inner exception (add `if (e is BootstrapException) rethrow`); `_validateStageRequirements` only logs in `kDebugMode`.

### 2026-05-26 — Ticket-then-flip integrity review (iter-78) [Review]
**When flipping a CHARACTERIZATION test, verify cause-and-effect with a SIBLING positive-control** (keep a lowercase-variant "proves cause" test next to the mixed-case flip; if only the flip is asserted, a regression breaking BOTH passes silently). **Docstring-only updates are valid when (a) the catch path can't be reached without a test-only seam, (b) the routing logic has its own unit test, (c) an existing test pins the boundary that would have to break** — cite all three.

### 2026-05-26 — AlgoliaSearchRepository `final class` wall [Pattern]
**When the SDK exposes a dep as `final class` (no `extends`, mocktail can't mock), you have NO seam** — privacy invariants stay untestable until production grows a `withClient(...)` ctor. Testable without it: getter, `getSuggestions('')`/`('a')` short-circuit, `batchIndexRecipes([])` early-return, custom index names, side-effect-free construction. **`.timeout(Duration(seconds:1))` on "should-not-touch-network" asserts** converts a DNS-storm hang into a clean `TimeoutException`. [Seam landed BUT-1130 below.]

### 2026-05-26 — FirebaseNotificationHistoryRepository [Pattern]
**`MockAuthRepository` + `FakeFirebaseFirestore` + `TestTimestampProvider` is the canonical trio for any `BaseFirebaseRepository` subclass.** Privacy-blast-radius asserts not happy-path dupes: `payload cannot forge userId (auth wins)`; `does not collaterally touch other users' docs`; `before cursor strict less-than`; **GDPR cascade completeness** (3 docs in 3 states all wiped); **"failed permission must not partially mutate"** double-assertion (throw AND doc unchanged). Note: `validateDeletePermission` returns true for any authed user (single-doc delete NOT user-scoped — only bulk is gated).

### 2026-05-26 — SocialRecipeSharingService privacy gates [Pattern]
Inject `UnifiedFriendsService` via raw GetIt. Deterministic-ID fixtures use `RecipeCore(id:...)` + `Recipe(core:...)` directly (factories generate UUIDs; `copyWith` has no `id`). `Fake` repos with named-record call logs. **Cap-test reads `Recipe.maxSharesPerRecipe` from the model** (survives a cap bump; pins the union-over-cap invariant). Flagged: secondary `shared_recipes` write failure returns true ("shared, recipient never sees it"); `'Unknown'` literal not localized.

### 2026-05-26 — iter-79 (BUT-1098/1100/1107/1108/1124) [Pattern]
**"Independence after partial failure"**: stub the FIRST call to throw, verify the SECOND ran once — `clearInteractions(mock)` AFTER setUp's initialize() so the count starts fresh. **Unhandled-async-swallow proof**: `await expectLater(Future<void>.delayed(Duration.zero), completes)` after a fire-and-forget void (the prod fix needs BOTH `Future.sync` AND `.catchError`). **Defense-in-depth gate**: seed Y valid + X invalid, assert null. Flipping a pinned-bug test asserts the FULL new contract (returns id AND pointer exists AND `isImported:true`), not "doesn't crash". Fake: `extends FirebaseSharedMenuRepository` with ONLY `@override read(...)` (all-optional ctor, no Firebase at construction). Mirrored tests for mirrored code ≠ duplication.

### 2026-05-26 — BUT-1087 error-clear-on-success [Pattern]
A ChangeNotifier service adding `_resetError()` per mutator + sanitized `_captureAndLog` needs THREE asserts: failure populates `_error`; **sanitized content where deterministic** (assert the localized substring `'behörighet'` when the raw exception has a sanitizer keyword, `isNotNull` for generic fallthrough); **successful retry clears `_error` using TWO DIFFERENT mutators** (same-method retry only proves intra-method reset). The `contains('behörighet')` assert proves it exercises the sanitizer, not just any non-null string.

### 2026-05-26 — Future.wait refactor: existing verify(...).called(N) suffices [Pattern]
Swapping sequential `await` for `Future.wait` over independent reads with no shared mutable state is observably unchanged — existing `verify().called(N)` + cache asserts already pin it. **First confirm existing tests assert SET semantics (`called(3)`) not SEQUENCE semantics (`verifyInOrder`)** — `Future.wait` may break sequence pins.

### 2026-05-27 — fakeAsync + SharedPreferences friction [Pattern]
**When the SUT both reads time via a `Timer` AND awaits a real `Future` from a plugin, don't use `fakeAsync`** (won't pump plugin microtasks; can't mix `await` into the sync body). Use a real `_settle(d) => Future.delayed(d + 100ms)` + `timeout: Timeout(seconds: 15)`. `fakeAsync` works when the SUT uses time but NOT plugins.

### 2026-05-27 — skipIfBusy timer cancellation [Pattern]
`scheduleAutoSave` calls `_autoSaveTimer?.cancel()` BEFORE the `skipIfBusy && _isAutoSaving` guard → a queued debounce from before the in-flight save is also cancelled. **Testing `skipIfBusy`-style guards: write two intents — (1) new schedule dropped; (2) previously-queued debounce isn't silently lost — OR document that it IS.** Cancel-then-guard ordering is common; always check it.

### 2026-05-27 — clearCurrentDraft sync-pointer + async-delete race [Pattern]
`clearCurrentDraft()` does unawaited `deleteDraft` then nulls the pointer — a following `saveNow` races. **Assert the synchronous contract; flag the race in the library doc; do NOT write a test requiring the race to manifest** (non-deterministic without a `Completer` seam).

### 2026-05-27 — ReportService trust/safety [Pattern]
**Capture-and-assert on the persisted `ContentReport` for identity-spoof guards** — `captured.single` to assert `reporterId == authUid` regardless of what the caller passed. Pin `createdAt` via `withClock`. **Assert side-effect ABSENCE on no-op paths by seeding a sentinel field** (pure `verifyNever` isn't enough when `executeServiceOperation` routes through fakeFirestore not the mock). ContentType routing = one named test per enum case. Use `setupUnitWithProductionLocator()` when the SUT runs through `executeServiceOperation(requiresAuth:true)`.

### 2026-05-27 — backup_service, batch 13 [Bug + Pattern]
Bugs: export writes `user_id` but import reads `user_email` (breadcrumb broken every round-trip); per-recipe error label reads top-level `recipeJson['title']` but `toJson()` nests under `core.title` (every failure shows "Okänt recept"). **file_picker platform substitution: `_FakeFilePickerPlatform extends FilePickerPlatform`** (NOT `implements`+`MockPlatformInterfaceMixin` — `extends` inherits the private `_token`), swap the static `instance`. **Round-trip integrity: capture every field via `captureAny(named:...)`, assert each equals the source** (one test catches every dropped field).

### 2026-05-27 — iter-81 FakeAuthRepository migration audit [Pattern]
For an `extends Mock → extends Fake` rename: **grep every file holding the Fake for `when\(\(\) => <var>\.`** — mocktail `when()` against a Fake is a runtime error (not silent), so a missed migration surfaces as a failure. The `local _MockAuthRepository extends Mock` + `_AuthStateHelper` extension keeps the ergonomic `mock.setAuthState(...)` call site while routing through `when()`.

### 2026-05-27 — Collaboration module owner-gate + atomicity [Pattern]
**Single-update atomicity pins**: `verify(...).captured` + `expect(captured.length, 1)` catches a refactor splitting "demote old owner" + "promote new owner" into two writes (window where both/neither holds owner). Fresh-read-before-write: stub `repo.read` to return a DIFFERENT membership than the local snapshot, assert the captured update merges from the fresh read. Privilege-escalation pin: `updateMemberPermissions` maps string `'admin' → ResourcePermission.owner` (freeze it).

### 2026-05-27 — SmartImportViewModel orchestration [Pattern + Bug]
**Pin in-flight phase via `Completer<T>`, not `Future.delayed(seconds)`** (latches deterministically, complete at teardown — no leaked timers). Disposed-VM tearDown guard `if (!vm.isDisposed) vm.dispose()`. `SharedPreferences.setMockInitialValues({})` in `setUp` (singleton cache module-scoped). `// ignore: unawaited_futures` (not `_ =`) paired with a `Completer`. **Parameterized via `for`+closure** with both sides of the mapping in the test name. Flagged: rate-limit synthesis lossy (hardcodes 1-hour/perDay); error-classification order misattributes "could not save: network unreachable".

### 2026-05-27 — friends_internal_operations, batch 14 [Pattern]
Prod reads `ServiceLocator.get` inside method bodies → `setupUnitWithProductionLocator()` + `registerMock` in the group's inner setUp. `MockUserService` doesn't stub `currentUserProfile` (local `_MockUserService` + `when()`). **`FakeAuthRepository.setAuthState(userId:...)` populates `currentUserId` but NOT `currentUser`** — code reading `currentUser?.uid` sees null; pass a real `User`. Privilege-escalation guard: pass a category with `ownerId ≠ current user`, `verify(addSelfToCategory).called(1)` + `verifyNever(saveCategory(...))`. Enum-to-string is `.toString().split('.').last` — pin for wire-format stability.

### 2026-05-27 — iter-82 epoch-ms draftId collision is fixture not race (BUT-1138) [Pattern]
**When a test inserts a small `Future.delayed` to disambiguate epoch-derived ids, check whether production has the same temporal granularity** — here `clearCurrentDraft()` awaits a real `SharedPreferences.remove` (>1ms in real Flutter), so the 2ms test wait is fixture-only. **When widening `void → Future<void>`, update stubs `thenAnswer((_){})` → `thenAnswer((_) async {})`** (old form fails at first `await`). Never write tests for "subcollections that might exist someday" — pin the schema as it stands.

### 2026-05-27 — iter-85 upload-subsystem flips [Pattern]
**State-seeding test for a multi-state summary**: trace the seed two steps (does it transition into stateA; does the summary derive stateA from a method filtering by EXACTLY that state, not a union?). **Bug-flip vs trivial post-fix pass — the boundary case**: a `> N → >= N` fix's bug-flip test must seed EXACTLY N (seeding N+1 passes both before/after = a regression guard not a bug-flip). **Localization-denominator**: assert `contains(new)` AND `isNot(contains(old))` (`'3 av 3'` alone is satisfied by `"3 av 35"`). Piecewise function = N tests, each input in ONE branch.

### 2026-05-27 — flutter test from Bash when PowerShell deny-listed [Helper]
`flutter.bat` needs PowerShell (deny-listed); `dart test` lacks `dart:ui`. Invoke the flutter_tools snapshot via bundled dart.exe: `/c/tools/flutter/bin/cache/dart-sdk/bin/dart.exe --disable-dart-dev /c/tools/flutter/bin/cache/flutter_tools.snapshot test <path>` (PATH = System32 + Git/cmd).

### 2026-05-27 — iter-86 (BUT-1109/1096) [Pattern]
**Localized fallback assertions for default-locale paths**: `AppLocale._current` defaults to `AppLocalizationsSv()` (plain singleton, no widget context) — assert `contains('Namnlös')` for a fallback; combine with `isNot(equals('?'))` (only-`isNot` passes on `''`; only-`contains` passes on `'?Namnlös?'`). **Tighten whitespace-collapse to the SMALLEST illegal run** (`isNot(contains('  '))` not `'   '`).

### 2026-05-27 — iter-88 (BUT-1129 closure rescope) [Pattern]
A refactor swapped captured-by-value bools for fresh-read closures (`isDisposedNow: bool Function()`) so per-file checks observe live state across `await`. **Race-window test recipe (no fakeAsync):** stub the inner await with a delayed Future; start the op (passing `() => flag`); flip `flag = true` SYNCHRONOUSLY between the sync return and the `await`; assert the post-await guard observes `true` (old by-value sees stale false → returns URL → FAILS; new → empty). The single-threaded event loop guarantees the flip lands before the guard re-runs. **Never accept a closure-rescope without one test in this exact shape; write it twice for two parallel flags.** A call-site asserting "flipped mid-flight and upload still completed" pinned the BUG — invert it.

### 2026-05-28 — BUT-1132 probe-query tests for infra-blocked branches [Pattern]
When the e2e skips (FakeFirestore-incompatible `FieldValue.increment`/`arrayUnion`), a query-only probe (exercise `where().where().limit(1).get()` against a pre-seeded doc) is necessary but NOT sufficient — it doesn't cover the `if (docs.isNotEmpty)` branch. **When you ship a probe: comment that it doesn't cover the post-query branch; file a follow-up to emulator-lane; or extract the branch into a pure helper.** Recorder-style fakes can't pin dedup (that contract lives at the repo layer).

### 2026-05-28 — iter-98 working-tree sprint (10 tickets) [Pattern + gaps]
Exemplary shapes: HeirloomBridge one-shot handoff with **draft-restore-on-failure** (the load-bearing retry assertion); ConflictResolutionModule per-branch via `onConflict: emitted.add`; tripwire-flip + file-header rewrite in the same diff; AssertionError-as-contract (existing key throws, missing key no-op); owner-scoped delete privacy (stranger-can't + doc survives + missing-doc-denies); idempotent re-add (counter-NOT-bumped). **Gaps: ConflictBanner widget ZERO test (only user-visible surface of BUT-1031 — a DO-WRITE widget test); resolver catch-branch non-emission untested (a "helpfully emit on error" regression shows a misleading banner); ~20 new IngredientCategorizer keywords untested incl. correctness-load-bearing rule-ORDER (oils before dry-goods, meat before fish).**

### 2026-05-28 — SocialShoppingCoordinator save-through flip (BUT-1105) [Pattern]
**"Fail-loud no-op replacement" (silent `return fakeId` → `throw UnsupportedError`) — assert BOTH levels: (1) direct call throws the right type; (2) every wrapper that delegates PROPAGATES not swallows** (wire a REAL throwing adapter through the wrapper, not a stub — the difference between pinning the contract and mocking away the subject). Delete the stale intent-doc + replace in the same diff.

### 2026-05-28 — shared_content pagination guard [Pattern]
The 3 subclass files pin `supportsPagination==false` + `loadMoreContent()` throws `UnsupportedError` (sound mutation behaviour). **Fragile-pattern note: `expect(() => vm.method(), throwsA(...))` in a SYNCHRONOUS test body on an `async` method passes only because the throw precedes any `await`** — robust form is `await expectLater(() => vm.method(), throwsA(...))` in an `async` test.

### 2026-05-28 — SocialRecipeService: pin SPECIFIC error string not isNotNull [Pattern]
**When a diff's intent is "surface a SPECIFIC user-facing message", pin that exact localized string** (`expect(service.error, AppLocale.current.errorImportPartialReSignIn)`), not `isNotNull` — a refactor regressing to a generic message still passes the weak assertion. Gap: `importSharedMenu` sign-out path has a bare `if (isAuthenticated)` with NO `else` (asymmetric with the recipe path) — documented in a test, not "fixed".

### 2026-05-28 — BUT-1161 extension-derivation + dup upload sites [Pattern + gap]
Gap: `ImageFormatUtils.extensionFor`/`extensionFromBytes` had ZERO direct tests. **`extensionFor(ImageFormat.unknown)` must return `'jpg'` NOT literal `'unknown'`** (the `.unknown` suffix is exactly the BUT-1161 mislabel — pin `isNot('unknown')`); `extensionFromBytes` uses `data.take(12)` (HEIC brand at offset 8-11 — narrower misclassifies iPhone scans). **Duplicated upload sites: BUT-1161 landed identically in `ImportBaseViewModel` AND `PhotoImportViewModel._uploadHeirloomScan`** — when you see `sha256...substring(0,16)` + `extensionFromBytes` duplicated, check both are covered or flag for extraction.

### 2026-05-29 — Adversarial LLM golden corpus (BUT-804) [Pattern + gap]
Three security contracts on the REAL `IngredientCategorizer`: `returnsNormally`, output ∈ schema, output ≠ input. **Gap: keyword-redirect vector** — `categorize()` is first-match-by-RULE-ORDER; an injection appending a competing category keyword DOES redirect the bucket (`"lök smör"` → dairy not veg). **When reviewing an adversarial corpus against a priority-ordered substring classifier, ensure it has a case where a high-priority keyword is injected alongside a lower-priority real token** ("injection is inert" is only provable for keyword-free payloads).

### 2026-05-29 — Menu clear-week + undo [Bug + gaps]
**Bug: undo drops overflow recipes** — `clearWeek()` wipes `_plan` AND `_overflow` but `undoClearWeek()` only restores `plan.entries` (snapshot never captured `_overflow`); the VM undo tests pass because none exercise an overflow-present scenario. Gaps: `restoreWeek` ZERO tests; `WeekNavHeader.onClearWeek` button + SnackBar undo wiring untested. `same(cleared)`/`same(restored)` identity asserts are acceptable (the contract IS "VM stores what service returned").

### 2026-05-29 — @visibleForTesting setError seam audit [Pattern]
Correct use of a test seam: `@visibleForTesting void setError(String?)` isolates the `_emitState` "data wins over stale error" branch without a real error-path that also clears `_lists`. **When a test seam lands, audit its sibling negative-branch test** — the seam made the previously-"can't reach" `ShoppingStateError` branch reachable; the inverse test written defensively-vague should be upgraded to use it. Facade delegators (one-line module forwards) don't need facade tests.

### 2026-05-29 — AlgoliaSearchRepository BUT-1130 seam landed [Coverage + Bug]
The `withClient(...)` seam (abstract `AlgoliaClient` + pass-through) was implemented. `_FakeAlgoliaClient implements AlgoliaClient` with concrete recording bodies = the correct Fake spy template for any thin-SDK-wrapper seam. Filled gaps: `indexUser`/`removeUser` (route to USERS index + rethrow), `searchUsers` field mapping, `getSuggestions` index fork, `healthCheck` (must NOT rethrow). **LATENT BUG: `batchIndexRecipes` does NOT chunk** (one `batch()` for all recipes; full-library reindex over the ceiling partial-fails). Did NOT pin the buggy single-batch (would lock the bug); reported for a chunk-at-≤1000 fix.

### 2026-05-29 — errorStream side-channel getters need both branches (BUT-1112) [Pattern]
Any new `Stream<X> get foo => svc?.foo ?? const Stream.empty()` is TWO behaviors — forward + fallback. Test both or the fallback rots. The empty-stream test asserts `forEach` completes without emitting (catches removal of `?? const Stream.empty()` → NPE). `MockRealtimeSyncService.setError(e)` pumps onto `errorStream` — use it, not `when(() => mock.errorStream)`.

### 2026-05-29 — Mock-as-Fake (MockRealtimeSyncService) [Pattern]
`MockRealtimeSyncService extends Mock` carries concrete `@override` bodies (the BUT-368/369 anti-pattern — concrete bodies block `when()`) — pre-existing + consistent = effectively a hand-rolled fake; acceptable because callers drive it via setters. Don't add `when(() => mock.errorStream)`; stub via `setError`. Flag for an `extends Fake` rename if it grows.

### 2026-05-29 — TierResult.success overrides quality [Pattern]
`TierResult.success({recipe})` computes `quality: recipe.overallQuality` — it doesn't take a quality arg; a helper mapping `q` only to a confidence BUCKET means requested 0.65 → actual 0.70. **A test claiming to pin a threshold boundary is NOT testing the edge — a `>=`→`>` regression survives.** When a stub's "quality" is recomputed downstream, assert the boundary against the COMPUTED value, or build a recipe whose `overallQuality` lands exactly on the edge.

### 2026-05-29 — `if (x != null) expect(...)` guards are weakened assertions [Pattern]
A conditional `expect` is a silent skip: if you can PROVE the guarded branch always runs (probe empirically), drop the guard and assert unconditionally — else a regression making the value null turns the test GREEN. Also flagged a tautology `expect(a==null || b==false || b, isTrue)` (always true; proves only "no throw").

### 2026-05-29 — BUT-504 mocked-away subject (High) [Bug found]
**Inline-fake-as-subject smell: the test defined a PARALLEL service in the test file and tested THAT — never imported/instantiated the production manager** (200+ green lines proving nothing — "mocks away the behavior it claims to verify"). Fix: drive the REAL manager through a `FakeRepository implements ...` backed by `FakeFirebaseFirestore` (reads return real `QueryDocumentSnapshot`s; the Fake strips `serverTimestamp()` before set). **Repository extraction done RIGHT = swap the constructor arg, keep the behavior assertions.**

### 2026-05-29 — Boolean-gate branch coverage (AND vs OR) [Pattern]
**For a compound gate (`A && B`), both-true and both-false do NOT distinguish `&&` from `||`** — a `&&`→`||` mutation survives unless a single-axis case (exactly one side true) is pinned. Concrete: an instructions-only Swedish page (`ingredients=0, instructions=6`) passes the `&&` gate; an ingredients-only page parses empty/empty — use the instructions-only shape (verified by mutation: only the new test goes red).

### 2026-05-29 — BUT-1135 doc-only notification contract [Pattern]
**When a service documents "intentionally NOT a ChangeNotifier / read-after-await", the ONLY in-flight observable is `isLoading`** — a test that `await`s then reads post-state is a no-op duplicate. Teeth-bearing test asserts `isLoading == true` SYNCHRONOUSLY after the call starts AND from inside the unresolved repo Future (via a `Completer` gate + an in-flight hook on the fake repo) — fails if a refactor moves `_isLoading = true` after the await.

### 2026-05-29 — BUT-1164 mapper + BUT-472 dispose leak [Pattern]
**"Constant X must never resurface" guard**: assert the NEGATIVE (`isNot(meatFish)`) across all group prefixes incl. `''` (survives a refactor accidentally re-adding an aggregate bucket). **Load-bearing precondition**: the dispose test's precondition reads the SAME private map the post-dispose assert reads. Weakness: a `conflict_timers_count==0` assert is vacuous (the map is only populated by a remote conflict the happy-path never triggers — zero before/after).

### 2026-05-29 — BUT-520 BaseViewModel disposed-guard test [Pattern]
After `ChangeNotifier → BaseViewModel`, existing error-path asserts still cover the migrated code (public surface unchanged) — no weakening. But the disposed-guard benefit is untested unless a test drives an async op across `dispose()`. **Recipe (no `Future.delayed`):** stub the service to return a `Completer.future` gate; call the method; `dispose()`; THEN `gate.complete()` + `await` (completion lands on a disposed VM → exercises the guard; removing the override throws "used after disposed"). **Don't dispose the SHARED tearDown instance in a disposal test — create a LOCAL `disposableVm`.**

### 2026-05-29 — DI-seam: DISTINCT value, BOTH super-params [Pattern]
**Distinct-value discrimination**: register the locator-backed fake with value A, inject a second with value B, assert B (same-value passes even when the seam is broken). **Test each super-param independently** (two added together are a copy-paste hazard; a slip passes if only one is exercised). When a base captures `_x = ServiceLocator.get<X>()` AT CONSTRUCTION (was lazy), verify the locator is populated before construction.

### 2026-05-30 — tagsMutated + zero-allowlist arch guard (BUT-1055/1066) [Review]
tagsMutated tests gate the contract (`clearCache` BEFORE `controller.add`); "clears cache before firing" is strongest (a non-clearing invalidate makes the 2nd `getAllTags` a cache hit → both asserts fail). **`await Future<void>.delayed(Duration.zero)` flush IS sound** — broadcast `add()` schedules a microtask; `Duration.zero` is a Timer (macrotask) draining all pending microtasks first → deterministic; reusable for broadcast-stream flush, no fakeAsync. The zero-allowlist arch guard is NON-vacuous (scans 134 view files, asserts `isEmpty` over a populated set).

### 2026-05-30 — FriendsEmptyState a11y (BUT-975) [Weak-assertion catch]
**`expect(getSemantics(...), isNotNull)` is a NO-OP** (with `ensureSemantics()`, `getSemantics` walks to the nearest merged node, never null) — deleting `Semantics(button:true, identifier:...)` leaves it green. **Always pair `getSemantics` with `matchesSemantics(isButton:true, label:..., identifier:...)`.** `Image.asset` + `errorBuilder` + `pump()` (not `pumpAndSettle`) = safe (failed asset → fallback Icon, never throws).

### 2026-05-30 — HeirloomBridge ServiceLocator.get throws in unregistered suites (BUT-1154) [Pattern]
`saveImportedRecipe()` → `_attachHeirloomIfPending()` calls `ServiceLocator.get<HeirloomBridge>()` (deliberately `get` not `tryGet`); `HeirloomBridge` is intentionally not in `TestServiceLocator.initialize()` so unregistered suites throw → `executeAsyncVoid` swallows → `saved==false`. **When a shared base method grows a hard `ServiceLocator.get<T>()` (not `tryGet`), audit EVERY subclass suite that calls it — register T or it throws-and-returns-false silently.** Fix: register an empty `HeirloomBridge()` (`hasPending==false`); do NOT weaken `expect(saved, isTrue)`.

### 2026-05-30 — BUT-1154 photo-import decomposition commit-gate [Pattern]
A pure mixin-extraction move preserving the public surface needs NO new tests to merge — `flutter analyze` is the gate. **Test-harness-artifact ID (NOT production bugs):** failing tests (a) call the mock DIRECTLY then assert on `viewModel` state the test never mutated ("mocks away the behavior it claims to verify"); (b) the prod paths are covered by passing sibling happy-paths (a real bug breaks those too); (c) a leaky test-double shadow field diverges from the field the pipeline reads. Rewrite to drive the real pipeline or delete; don't weaken/skip to go green.

### 2026-05-30 — BUT-1170 AutoPersonalTagDisplay re-bind [Static-state widget test]
COMMIT-SAFE: intent-gated (the "Vegansk" assertion fails if `_onInstanceReady` re-bind is removed), authentic login/logout paths, static-state isolation sufficient (final `pumpWidget(SizedBox)` unmounts → resets all 5 statics; the ONLY test mounting this widget). **Placeholder-shimmer flush: custom `flush()` (pump + pump(50ms)) instead of `pumpAndSettle`** — an infinite shimmer never converges; reusable for any always-animating loading state. CAVEAT: the static `_instanceReadyController` is process-global, never closed — flag if a 2nd mounting test appears.

### CPI→LoadingIndicator migration (BUT-885/1066/1168/1173, iter-113 + waves 2-4) [Pattern]
Canonical rule for mechanical indeterminate `CircularProgressIndicator → LoadingIndicator` swaps inside static builders (subsumes the 2026-05-30, 2026-06-01 iter-113, and 2026-06-01 wave-2 entries; covers `lib/widgets/` social/common/image files + the `lib/views/` BUT-861 `StateWidget.loading()` siblings):

- **A pure indeterminate swap is behavior-preserving and needs NO new widget test.** `LoadingIndicator → AdaptiveActivityIndicator` stays on the indeterminate `CircularProgressIndicator` path on non-iOS hosts (the `flutter test` default) IFF `value == null && backgroundColor == null`. `valueColor → color` is the equivalent indeterminate swap. The regression contract is the arch guard (`architecture_test.dart` "no raw CircularProgressIndicator in lib/widgets|views/", BUT-885/1066) — **de-allowlisting the migrated file + confirming the guard still passes IS the proof**, plus `loading_indicator_test.dart` (pins value!=null → determinate CPI carrying value/strokeWidth/backgroundColor; value==null/.small → AdaptiveActivityIndicator). A `find.byType(LoadingIndicator)` re-assert = a low-value getter-identity test.
- The swap adds a net-new `Semantics(liveRegion: true)` node (a11y improvement, not a behavior change).
- **`find.byType(CircularProgressIndicator)` SURVIVES the swap on the default non-iOS host** — it only changes under `Platform.isIOS` (→ `CupertinoActivityIndicator`); a CPI finder breaks ONLY if a test both renders a migrated widget AND forces iOS — verify neither. Remaining CPI finders are in `test/widget/common/indicators/` (wrappers — correct) + tests rendering their OWN spinners; view tests use the wrapper finder or an OR fallback (`LoadingIndicator || CircularProgressIndicator`, BUT-891).
- **The ONE swap that DOES need an extra test: any `value:` fed by a ternary/conditional/nullable-cast is a BEHAVIOR BRANCH, not a swap** — grep the diff for `value:` on every migrated call site. Straight pass-throughs (`value: progress`) are covered by the widget's own null/non-null tests. But `value: status.progress > 0 ? status.progress : null` is a real domain branch (progress==0 must render INDETERMINATE, not a stuck 0%-full arc) — assess as new logic needing a boundary test (the widget's hardcoded-literal tests never exercise the `>0 ? : null` boundary). **Spinner type alone never deserves a behavioral test; a determinate/boundary `value:` clamp does.**

### 2026-06-01 — BUT-1056 onShareError callback threading [Pattern]
**When a callback is threaded through N constructor hops, a direct-construction test of the LEAF proves the leaf FIRES it but never proves the WIRING.** The cap-rejection test constructs `RecipeSharingManager` directly with a local sink (intent-true: `newId==null` AND `surfacedError == errorShareCapReached(...)`). Real (low) gap: nothing proves `UnifiedRecipeService` passes `_setError` into `_socialContext`, nor that `SocialOperationsInitializer` (3 callsites) forwards `ctx.onShareError` through all branches — a refactor dropping it on one branch compiles clean + silently regresses with all 9 manager tests green. **Test the OUTERMOST wired unit you can cheaply build.** Design intent confirmed (NOT a gap): other return-null paths (recipe-not-found, empty createCollaborative) intentionally don't fire onShareError — only the cap path surfaces a dedicated message.

### 2026-06-01 — BUT-1171 PhotoImportViewModel @visibleForTesting setters [Pattern]
**Retiring a leaky test double: give production a single `@visibleForTesting` setter on the REAL field and delete the shadow field + getter overrides — do NOT add a parallel getter override.** `setOcrTextForTesting`/`setImageBytesForTesting` assign the real `_ocrText`/`_imageBytes` (+ `notifyListeners()`), so getters AND the pipeline observe the same state — this is the fix for the 2026-05-30 leaky-double finding (a shadow field diverging from the field the pipeline reads is the exact shape that produces "Expected true, Actual false" with zero production defect). The now-real save path is adequately covered (success / no-recipe-guard / save-failure, unblocked by the ServiceLocator bridge + empty `HeirloomBridge` in setUp). GENUINE GAP (file LOW): the heirloom-PENDING branch of `_attachHeirloomIfPending` is never exercised (bridge has no pending draft → early-returns); the whole BUT-953/1086/1161 upload sub-path (auth re-check → `errorAuthentication`, content-addressed path build, `uploadImageData`, draft-restore-on-failure) stays unpinned at the VM level — the new setters make a VM-level heirloom test cheap. Minor pre-existing smell: a `Future.delayed(10ms)` for processing-state (should be `fakeAsync`+`elapse`).
