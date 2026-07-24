# testing-specialist — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every testing task and **APPEND** to it when it
discovers a new pattern, encounters a new helper, or is corrected by the
user.

The main agent file (`testing-specialist.md`) holds the durable rules
(DO-WRITE / DO-NOT-WRITE patterns, the production→test path map, Mock-vs-Fake
guidance). This file holds **what the agent has learned since then** — as a
**principles document**, not a day-by-day log: every entry is a durable,
reusable rule, not incident narrative.

## How to update this file

- **This file holds PRINCIPLES only.** Fold new learning into the matching
  section below as a 1-4 line rule (merge with an existing bullet if it's a
  restatement; add a bullet/section if genuinely new). A principle earns its
  place only if a future run would do something DIFFERENT because of it —
  not "we once saw X."
- **Raw incident narrative goes to the archive, not here.** If the story is
  worth preserving (a gnarly bug, a full repro), append it verbatim to
  `testing-specialist.knowledge.archive.md` under a new `## <date> — <title>`
  heading, then fold the one-line lesson in here. Never let a dated
  "### YYYY-MM-DD — what happened today" entry accumulate in THIS file again
  — that's what caused the 2026-07-24 rewrite (432K chars of daily log
  restating the same ~15 patterns hundreds of times).
- **Append into the RIGHT SECTION**, not just onto the end.
- **Keep it tight.** If this file crosses ~35,000 chars again, you're logging
  incidents instead of distilling — stop and fold before adding more.

## When to consult the archive

The archive holds the full dated history this file distills — every entry
ever written, verbatim, chronological. Grep it when:
- A principle below is too terse to act on and you need the worked example
  (exact test code, production line numbers, exact failure output).
- You hit an unfamiliar mocktail stub mismatch, `MissingStubError`, or a
  fake-vs-real-Firestore discrepancy not named below — this exact confusion
  has likely been solved before with the specific fix documented.
- An emulator-lane setup is failing — the archive has full Windows/emulator
  runbook entries.
- You're reviewing a specific ticket/area (menu, tagging, import, family
  rating, voice) and want the full review history, not just the rule — grep
  the BUT-#### ticket or area name.
- A principle cites "verified non-vacuous by X" and you want the actual
  revert-probe/mutation-test that proved it, to reuse the technique.

---

## Principles

### Project-specific test infrastructure (full detail in `testing-specialist.md`)
- Production ServiceLocator bridge: `production.ServiceLocator.initialize(DIContainer())` in `setUpAll`. Two ServiceLocator classes (production wraps DIContainer, test uses GetIt directly) share the same `GetIt.instance`.
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — always pass it explicitly.
- Debounced VM methods need `fakeAsync` + `async.elapse(Duration(milliseconds:300))`. `executeDebounced` triggers 3 notifications: setLoading(true) + operation + setSuccess().
- Per-view "mechanical" tests were deleted (BUT-387 Phase 6) — `test/views/` is journey-test territory only (owned by `e2e-test-specialist`); heavy-scaffolding views get ONE beat in a journey test, not a standalone widget test.

### Coverage decisions
Codecov: 60% project / 70% new patches / 2% drop tolerance — floors, not targets; one behaviorally meaningful test beats ten getter checks. Project floor DECIDED at 55% (2026-07-11) — don't file generic "raise coverage" tickets.

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

### FakeFirebaseFirestore vs emulator decision tree
| Behaviour under test | Use |
|---|---|
| Plain reads/writes/queries, `collectionGroup`+equality, `orderBy` on a present field | `FakeFirebaseFirestore()` in `setUp` |
| `FieldValue.increment`, `serverTimestamp` (usually), transactional writes, security rules | Emulator lane, or `firestore-rules-tester` |
| `GetOptions.source` (cache-first vs server) | NOT testable on the fake — ignores `source`, returns the same doc either way. Assert the outcome contract only. |
| Service that wraps Firestore | Mock at the repository interface |
- `serverTimestamp()` inside `batch.set(..., SetOptions(merge:true))` does not reliably break the fake — only certain write shapes trip it; let a success test prove it lands.
- Fake CANNOT fire `permission-denied` — acceptable to skip only when the branch is a single `if (e.code=='permission-denied') return null;` above a rethrow with no side effects.
- A seeded fixture must include every field an `orderBy` reads — the fake (like real Firestore) silently drops docs missing it, which can masquerade as a query bug.

### Bugs found via tests (a few representative ones — the archive has the rest)
BUT-369: `Recipe.copyWith` empty-list crash, `FirebaseShoppingRepository` delete-permission bypass, `ParseEventLogger` Firebase-on-construction — all caught because the test checked the real invariant, not internal structure.

### Conscious-skip taxonomy (each discriminant is distinct)
- Static-method orchestrator: skip only when ALL hold — ≤3 calls, no injection seam, each in its own try/catch, no branching beyond the catches.
- Static disclosure whose sync contract is compiler-enforced (renamed `AnalyticsEvents.*`/l10n constant fails analyze/gen-l10n before any test runs).
- Pure-nav affordance (`pushNamed(<const route>)`) — route constant is compile-checked.
- Nth surface adopting an already-proven predicate: prove via `git diff --staged --name-only` — no new surface if the pure-logic file is absent from the diff.
- Mechanical `AppColors→theme` swap: skip only if finder-level assertions are unaffected.
- `SemanticsService.announce` in a fire-and-forget handler is skippable UNTIL the view gains a DI seam or full-shell harness — a conscious skip is dated, not permanent.
- A "sole guard"/"bypass not possible" comment is a claim until a test actually enters that exact branch.
- A comment-only diff owes no new test IF the claim is already pinned by a spy/Fake that would fail-loud if false — verify, don't trust.

### Vacuity patterns — the recurring ways a "passing" test proves nothing
The single most repeated finding across two months of review. Check every new test against this list.
- **Circular determinism.** Calling the same pure function twice, or deriving the expected value from the SAME const the test guards, proves referential transparency, not the invariant. Pin the literal OUTPUT VALUE (`expect(buildId('r1','m1'), 'r1_m1')`, not `expect(buildId(...), buildId(...))`). Same trap for a cost/safety cap: if the expected length is computed FROM the const under test, add one literal pin (`expect(maxCompoundParts, 8)`).
- **Fake-default-same-as-expected.** If a Fake's optional-param default equals the "forwarded" value the test asserts, omitting the arg still passes. Use a sentinel default no real caller would pass (`maxDocuments = -1`).
- **Negative-scope claims need a negative assertion.** "Never includes email/phone" must assert ABSENCE (`toMap().keys` excludes it), not just presence of allowed fields.
- **Boundary tests must straddle the EXACT flip point.** For truncating `.inDays > N`, the flip is between `inDays==N` and `N+1` — a test at `N-1`/`N+2` misses tightening regressions entirely. Assert both `Duration(days:N,hours:12)` (not-yet) and `Duration(days:N+1)` (now).
- **"X does NOT happen" needs proof the code reached the point X could have.** Two different failure paths can share one negative observable (e.g. "strategy threw" vs "strategy not found" both yield empty events) — assert a signature UNIQUE to the intended path.
- **`findsNothing` needs a co-asserted positive render** in the same test, else a build crash upstream explains the absence too.
- **"Returns null on permission denial" needs a positive control in the SAME fixture** — the null could come from an unrelated failure further down the same path.
- **Last-wins/correction tests must assert the LOSER is absent**, not just the winner present.
- **Precedence/weighting tests need inputs where the WRONG alternative gives a DIFFERENT number**, ideally opposite-direction (A: sig1=5,sig2=2; B: sig1=2,sig2=5 → assert weight(A)>weight(B)). Same-value inputs can't distinguish precedence from averaging.
- **A drift guard walking only `vocab → mapping exists` catches forward drift, not reverse** (a mapping the producer no longer emits still compiles). Fix: a POSITIVE test driving the real producer, asserting emitted set == vocabulary.
- **A partition/uniqueness test derived from the SAME curated list the impl was written from cannot fail.** For any `contains()`-based classifier, run a throwaway probe over every sibling name in the real vocabulary — surfaces substring-collision bugs in minutes.
- **A "does less work now" claim needs a discriminator test, not a convergence test** — seed something ONLY the naive path would wrongly pull in, assert it's absent.
- **Round-trips must drive the REAL serializer** (`toFirestore()`/`fromMap`), never `copyWith`. A model with two legs (`toJson`/`fromJson` cache AND `toFirestore`/`fromMap`) needs a non-null value asserted through BOTH independently.
- **A test title claiming something the fixture can't distinguish** ("SCALED line", "dest wins", "reverse drift caught by the compiler") — trace whether the fixture is at the default/identity config or the branch is unreachable. Audit names against bodies.
- **A test named as a round-trip that never calls the read-side function** is misleading and a coverage hole — grep test names against what bodies actually call.
- **Firestore numeric aggregates landing on a whole number are stored as `int`, not `double`** — a parser using `as double?` throws and silently drops the row; add one whole-number case (`'average':5` → `5.0`).

### Fake/Mock idioms + the ServiceLocator/GetIt bridge
- `class X implements Y` with concrete bodies is a legitimate Fake. The mocktail ban is specifically a concrete `@override` on `extends Mock` (blocks `when()`) — narrow exception: a pure call-count "counting fake" never `when()`-stubbed on that method, or a non-nullable getter a bare Mock would noSuchMethod-crash on.
- `extends <ConcreteClass>` with an `@override` body is a legitimate SUBCLASS SPY, not the banned pattern (the ban is about mocktail `Mock`).
- Lazy `tryGet` fields cache on construction — register fakes BEFORE constructing the SUT.
- Callback-based async APIs: capture the named callback via `invocation.namedArguments[#name]`, invoke synchronously inside `thenAnswer`.
- **The GetIt→DIContainer bridge gotcha (recurring — analytics/tag-overrides/correction-snapshot/import chokepoints):** many singletons (`AnalyticsService.tryLog`, `ImportManager`'s rate limiter/cache/normalizer, `TagEditingService`'s override log) resolve via the PRODUCTION `ServiceLocator` (`application_provider.dart`, a `DIContainer` over `GetIt.instance`) — NOT the plain `TestServiceLocator.initialize()` path. A mock registered only via `TestServiceLocator.registerMock/registerSingleton` is INVISIBLE there; captured events stay empty, test silently proves nothing. Fix: `prod.ServiceLocator.initialize(DIContainer())`, then register into `GetIt.instance` AFTER; tearDown = unregister + `ServiceLocator.reset()`. Check what else on that path touches the locator before bridging into an existing file — an unstubbed dependent read outside try/catch can throw.
- Fire-and-forget writes to `FakeFirebaseFirestore` need microtask draining — two `await Future.delayed(Duration.zero)` (or `pumpEventQueue()`); not the banned real-time wait.
- **A new fire-and-forget telemetry call at a chokepoint reliably ships with ZERO tests.** Add a capture-test: fires-once-with-params on the happy path, fires-nothing on the negative path. "Just telemetry, no seam" is usually false — trace the resolution chain.
- **A safety-critical method covered ONLY via `mockService.method` `verify()` in a caller's test proves WIRING, never the wrapped CONTRACT.** Grep for the new method NAME at its own service/repo layer.
- `collectionGroup` on the fake is safe for index-free `.limit(N).get()` without `where()`, AND (^4.1.0+1) for plain `collectionGroup`+equality — narrower than "always needs emulator."

### Disposal & lifecycle guard idioms (BaseViewModel family)
- `BaseViewModel` already guards disposal TWICE: `clearError()`'s `if (_isDisposed) return;` AND `notifyListeners()`'s `if (!_isDisposed) super.notifyListeners()`. A subclass's OWN third guard is often untestable-to-fail — a bare `dispose()→clearError()→returnsNormally+notified==0` test can't go red from removing just the subclass guard. Only test a disposal guard when it protects an OBSERVABLE effect not already blocked by a base guard (e.g. a late stream emission mutating a private field BEFORE the guarded notify — assert the STATE stays unchanged).
- Two quadrants when sweeping a guard across many VMs: (A) delegate disposed BY this VM's own `dispose()` — test `returnsNormally`+`notified==0`. (B) delegate is a SHARED SERVICE outliving the VM — `returnsNormally` is VACUOUS; assert the service's error SURVIVES the VM's disposal instead.
- A class with BOTH a local `_isDisposed` (set at the START of its own dispose, before delegates') and inherited `BaseViewModel.isDisposed` (flips only inside `super.dispose()`, often called LAST) must have any new guard use the SAME flag its own callbacks use.
- Migrating `ChangeNotifier`→`BaseViewModel`: the old `throwsFlutterError` post-dispose-notify test becomes `returnsNormally` (silent no-op now) — but ALSO assert the listener was NOT invoked, or the test can't tell "no-op" from "leaked".
- A VM shadowing `error`/`hasError` must be proven by driving a FAILED base `executeAsync` (populates `super._error`) — seeding only a service-level error while base stays clean can't catch a dropped override. First check the VM calls base `executeAsync` at all; if error routing is fully manual, `super._error` is dead and this pattern doesn't apply.
- `executeAsync` RETHROWS on failure (not null). Prove it indirectly via a caller that only retries on THROW (assert attempt count) — a bare try/catch around the call is vacuous re: rethrow-vs-null.

### Contract pinning: selectors, ordering, equality, revert
- Every `field == expected` selector needs THREE pins: matched-key reused, unmarked-collision untouched, marked-for-different-key untouched+new-created.
- `==`/`hashCode` tests need an equal pair (equal + same hashCode) AND a deliberately-unequal instance — equal-pair-only passes even if `==` regressed to `=>true`. Watch `hashCode` hashing a collection field by IDENTITY while `==` compares by CONTENT — share instances so the tested field is the only variable.
- Ordering contracts need `verifyInOrder`, not call-count.
- A revert-to-start test must mutate first, THEN revert, then assert.
- Method removed+replaced: audit the deleted group with a test-by-test successor map — auth/permission branches are easiest to silently drop.
- **Revert experiment (strongest non-vacuity proof):** flip the production line back, confirm the gating test FAILS while controls stay green. Construct the REAL object under the exact constructor wiring the bug lived in.
- `expect(() => asyncFn(), throwsA(...))` without `await` can pass spuriously — use `await expectLater(...)`.

### Import & correction-capture pipeline
- SSRF host-filtering and decompression-bomb caps are running invariants across every import surface.
- A CTA/UI test proves the LABEL, not the ACTION — assert wire-level dispatch separately (extract a `@visibleForTesting` pure helper) when a shared widget/VM hardcodes an attribution tag for "the common case."
- **Correction-snapshot/parse-cache keys sharing a placeholder across unrelated imports silently collide** (e.g. text+photo both keyed on the same constant placeholder `sourceUrl`) — second write overwrites the first's training snapshot with no error. Test two same-kind imports in sequence, assert retrieval returns the FIRST's data.
- **A wizard rebuilding an editable buffer from a prior step unconditionally on forward-nav loses edits on back-then-forward.** Forward-only suites are structurally blind — add one back→edit→forward preservation test; guard with a "did selection actually change" check.
- **Rate-limit metering: enumerate ALL call sites of the limited operation** — assisted-import, cache-hit, social-platform paths have each silently bypassed or double-charged the same bucket.
- **A circuit-breaker over a parallel `Future.wait` batch must not discard already-materialized results** from the same batch when it trips mid-batch — a success after the trip point can be dropped though its side effects already happened.
- **A "retry" wrapper keyed on THROWN exceptions is dead over an API signaling failure by return value** — check what the wrapped op does on failure first. Wrapping an ALREADY-STARTED `Future` in a retry extension can never re-run it.
- **A cross-copy "single source of truth" test must actually READ every copy it claims to unify** — an unexported duplicate elsewhere can still drift silently.
- Windows `flutter test`: `/c/tools/flutter/bin/flutter test <forward-slash-path>` via the Bash tool works directly, no wrapper needed.

### GDPR / export section contract
- Every export section needs THREE proofs: (1) seeded → count present AND the genuine PII field round-trips verbatim; (2) ownership-negative → a doc owned by ANOTHER uid is absent; (3) empty-safe → `total==0` AND `containsKey('error') isFalse` (every manager wraps its body in try/catch→`{'error':e}`, so this catches a silent degrade a bare "section exists" test would miss).
- Redaction paths (e.g. FCM token → 10-char prefix + `[redacted]`) are the SECURITY invariant and outrank another happy-path test — check these first when reviewing a partial export manager.
- Where counterparty data is a DECIDED inclusion (not redaction), write the test that PROVES inclusion, with a comment citing the decision.
- A two-query union+de-dup section needs FOUR fixtures: sent-only, received-only, self (both legs match the SAME doc — the only row catching a de-dup regression), foreign (ownership-negative).
- Derive caps: `final cap = ExportPaginationHelper.getLimitForType('<type>')`, use for both fixture size and assertion — never hardcode, since fixing an accidental fallback-default is a behavior IMPROVEMENT a hardcoded test would wrongly fail.

### Settings-hydration & sentinel-parameter template (recurring: BUT-1220, 674, 1322, 1610)
Any field persisted via a private settings sub-doc needs: (1) a hydration test seeding the sub-doc DIRECTLY; (2) a corrupt-value test that ALSO asserts a SIBLING merged field survives (the merge is one `copyWith` in one try/catch — a naive parse of the corrupt field can abort the WHOLE merge, invisible if you only check the corrupt field's own null-safety); (3) a save-path test asserting the settings doc has it AND the public doc does NOT (privacy-leak guard) + round trip; (4) if the field has 3 serialization surfaces (Firestore/JSON-cache/copyWith), each needs its OWN test.
Sentinel-parameter contracts (`Object? field = _unset`) need both quadrants at the layer where omission is possible: omit→preserved, explicit-null→cleared. Prefer capturing the forwarded ARGUMENT IDENTITY against the sentinel (`identical(captured, Sentinel)`) over a downstream no-op — a regressed VM forwarding an in-memory null instead of the sentinel can coincidentally suppress the same effect.

### Age/maturity/consent gates
- A field moved client→CF-authoritative: invert the old round-trip into an ABSENCE assertion on EVERY client-write surface (`toFirestoreEditable`, `toPrivateSettings`, any merge map) — verify non-vacuous by confirming the field still appears in base `toFirestore()` (so it COULD leak).
- "Infra error" vs "explicit rejection" needs a TYPED discriminator flag asserted on BOTH branches — a bare boolean can't tell them apart.
- "Must NOT re-fire on resume/already-verified" needs BOTH `verifyNever(gate call)` AND the positive downstream effect in the SAME test — asserting only the return value is green-blind when the stub defaults to success anyway.
- A "quiet/never-throws" method's contract is proven by asserting the user-facing error field stays null on EVERY failure branch.

### Menu & tagging domain
- Weighted-random selectors: assert WEIGHT MATH via a `@visibleForTesting debug*` hook, never the sampled outcome (an assertion on which item got picked from a `Random` draw is an automatic vacuity flag). Pair with: unrated equals the 1★ value (never-penalized, not just selectable); ceilings pinned via `closeTo` at extreme inputs so a no-op multiplier fails.
- **Any feature persisting entity ids later intersected with a live collection (present-diner ids, dislike lists) needs a ZERO-INTERSECTION test** — stale ids usually fail OPEN (empty filter = no filtering), the dangerous direction for allergen safety.
- Feature-flag OFF paths are a systemic blind spot: `tryGet<FeatureFlagService>() ?? true` means the OFF branch is untested unless a fake flag service is explicitly registered false.
- A config-version-gated rebuild guard needs both directions: newer→rebuild, same→no-rebuild. If a version is captured once but RE-DERIVED later instead of threaded through, a concurrent run can stamp the wrong version.
- Dead-duplicate code paths: when tests drive one method but production calls a DIFFERENT one (verify via grep for real callers), the tested path can drift silently — fix by making the live path DELEGATE to the tested tail.
- An "X lands first" ordering comment is unproven without a two-candidate COMPETING test.
- Denormalized-projection tests: capture via `captureAny()`+`.captured.last`; cover the NULL-CLAMP arm (removing the last vote → null, not 0); prove EQUAL-WEIGHTING with ASYMMETRIC inputs (symmetric inputs can't distinguish equal-weight from count-weighted).
- A repo→VM re-key seam (poolKey→recipeId) is the highest-value untested point when the repo test asserts one key-shape and the widget test injects the other directly.
- Adding a versioning field to old fixtures is usually INTENT-PRESERVING under a new staleness guard, not weakening — audit ALL fixtures of that type when such a guard lands.

### Firestore cost, index & cascade patterns
- A declared composite index needs its own assertion (the index array, in a test) — fakes can't catch a missing composite. Also assert `queryScope` (COLLECTION vs COLLECTION_GROUP) alongside field order.
- A merged/idempotent cascade batch that unconditionally `update()`s a doc it assumes exists can throw NOT_FOUND and fail the WHOLE batch if that doc is already gone — test the gating doc exists but the TARGET doesn't.
- A denormalization write via dotted-path transactional `update` needs a test asserting an UNRELATED sibling field SURVIVES — proves scoped merge, not whole-doc rewrite.
- A CF trusting a doc field for a security decision is only as strong as the Firestore RULE validating that field on create — confirm the rule pins it before crediting a "backstop for tampered clients."

### CF/TS-specific
- A new emulator-integration test must be wired into the CI chain on THREE fronts: the granular `test:integration:*` script, the composite chain CI actually runs (e.g. append to `test:rules:all`), and the workflow's `paths:` trigger list — unit-test runners auto-discover `test:*` but EXCLUDE `test:integration:`/`test:rules` prefixes.
- In integration tests, order the existence assert BEFORE the first dereference of a possibly-missing doc — a `data()!` throws a raw TypeError one line before the friendly assert runs.

### Multi-select / bulk-action wiring
- VM tests + card tests can pass while the GLUE (snapshot/order/callback) is untested at widget level.
- Selection-guard tests need the owner's OWN tile, not all-strangers. Clear-on-cancel: assert count returns to the ORIGINAL, not zero.
- Copy-paste id-field mismatches are invisible unless a fixture makes the two fields DIFFER.
- Async error stubs: `thenAnswer((_) => Future<int>.error(...))` — never `thenThrow` (sync) nor `async => throw` (type-erased).

### Extraction seams & duplicated-logic-across-surfaces
- Pure decisions locked in a DI-heavy widget → extract `@visibleForTesting static` instead of a DI bridge.
- A "pure structural split" makes private behavior a public in→out contract — that's when tests newly apply.
- **Duplicated-logic trap: when the SAME behavior is independently re-implemented in 2+ classes, grep every `_resolve*`/init copy and demand a test PER COPY.** Copies WILL diverge silently (observed: one gains a range guard the other lacks).
- When consolidating duplicated per-caller logic into ONE shared widget/helper, a test on the NEW host doesn't prove the OLD host still embeds it — add a cheap render+side-effect test on the OLD host too.
- A crash-safety invariant behind heavy widget scaffolding (e.g. Dropdown's "exactly one item with this value") is better pinned via a small extracted `@visibleForTesting` pure helper than a brittle full-pump assertion.
- When a migration consolidates duplicated logic into a shared widget, the test belongs on the widget ONCE (proves all callers) — don't replicate a per-caller test.

### One-off gotchas, Windows/runner notes, and the revert-probe technique
- `Semantics(label:)` wrapping a tooltip'd button MERGES into one node with a concatenated label — match with `RegExp` (never exact String), bracket `bySemanticsLabel` with `tester.ensureSemantics()`/`handle.dispose()` in the SAME test.
- Optional-override params with an l10n `??` default: assert an injected override renders AND `find.textContaining(<default's unique substring>)` findsNothing — a shared substring makes the default-path test blind to whether the override threads through.
- A `GlobalKey` preventing State recreation is tested behaviorally: drive the state-changing event that WOULD recreate it, assert continuity survives — never assert on the key itself.
- **"Derives from a scaled/filtered list" claims need the list to provably DIFFER from its source** (factor ≠ 1.0) — testing at the default/identity config is structural blindness.
- A copy-SPLIT (two strings sharing a suffix) needs an assertion on the substring UNIQUE to each.
- Real `.xlsx` stores text via shared-strings (`t="s"`), not `inlineStr`.
- Age-boundary tests must pin the exact legal threshold on BOTH sides, not just far-side values.
- `export 'stub' if (dart.library.js_interop)` services: test only the stub's no-op contract; the web state machine is unreachable from VM tests.
- **Revert-probe (the reliable non-vacuity proof):** copy the production file to scratch, string-replace the fix OUT, run the affected suite, confirm EXACTLY the expected test(s) go red at a unique assertion, restore and byte-verify with `cmp`. Batch probes in one run only when each fails uniquely; separate when they share a code path. Back up IMMEDIATELY before editing — a parallel session may be editing the same file.
- A `TimeoutException ... during "loading"` with 0 tests run is compile-bound (~12min shared `lib/` compile), not a hung test — split the invocation per-file to confirm.

### Firestore-rules `.ts` suites (emulator-gated)
- Every `&&` clause in an `allow` rule gets a failing test; every `cannotModify`/`hasRequiredFields` list needs a test PER FIELD.
- A failure-only update suite can be silently over-restrictive — pair denials with an `assertSucceeds` on a mutable field.
- The emulator persists docs ACROSS invocations — suffix create-test ids with a per-run `RUN = Date.now().toString(36)`, or a fixed-id create silently becomes an update on the 2nd run.
- These are hand-rolled `npx ts-node` runners against `127.0.0.1:8080` — time out without `firebase emulators:start --only firestore` running first.
