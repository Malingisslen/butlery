# e2e-test-specialist — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every journey-test task and **APPEND** to it on
discovery, real flake-fix, or user correction.

## How to update this file

- **Append-only** — supersede with a newer dated entry; never delete.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **Tag each entry** — [Pattern discovered] / [Flake fixed] / [Bug found] /
  [User correction].

---

## Journey-test catalog (test/views/)

| Journey | File | What it proves |
|---|---|---|
| Allergen preferences | `allergen_preferences_view_test.dart` | User sets allergens → state persists across navigation |
| Onboarding | `onboarding_journey_test.dart` | First-launch flow → first recipe imported |
| Import recipe | `import_recipe_journey_test.dart` | URL/text → parsed recipe in user's library |
| Cooking mode | `cooking_mode_journey_test.dart` | Recipe → cooking mode → step navigation |
| Menu → shopping | `menu_to_shopping_journey_test.dart` | Weekly menu → consolidated shopping list |
| Share recipe | `share_recipe_journey_test.dart` | Recipe → friend → recipient sees it |
| Account deletion | `account_deletion_journey_test.dart` | Delete account → all user data cascades, sign-out |
| Deep-link import | `deep_link_import_journey_test.dart` | `butlery://import?url=...` → pushes Routes.smartImport with decoded URL; unknown host pushes nothing |
| Social subdir | `test/views/social/` | Friend requests, comments, likes |
| Messaging subdir | `test/views/messaging/` | DM-style flows |

When a new journey is added, append a row above with a one-sentence
"what it proves."

## e2e bootstrap variants (test/e2e/)

| Entry point | Use for |
|---|---|
| `main_e2e_mock.dart` | Pure mock backends — fastest, runs in CI without emulator |
| `main_e2e_emulator.dart` | Local emulator backends — closest to prod, slower |
| `main_e2e_optimized.dart` | Reduced-fixture variant of emulator — faster CI |
| `main_e2e_staging.dart` | Staging-backed — full prod-shape, runs against `.env.staging` |

Choose by what behavior is under test:
- Pure UI state machines → mock
- Anything touching `FieldValue.increment`, transactions, security rules → emulator
- Smoke / release-readiness checks → staging

## Helpers (test/views/helpers/)

Read this dir before reinventing — there's already a journey-test app
builder, navigator helpers, and locale pinning utilities. The exact API
varies per session; grep for `Future<Widget>` builders and `pumpJourney*`
patterns when starting.

## Gesture & timing rules

- **Always** `await tester.pumpAndSettle()` after navigation, but cap with
  a timeout: `pumpAndSettle(Duration(seconds: 5))` — uncapped settles hide
  infinite-rebuild bugs.
- **Never** `Future.delayed`. If production code uses `DateTime.now()`,
  swap for `clock.now()` and drive with `fakeAsync`.
- **Tap by Semantics label**, not by widget index — order changes break
  index-based finds.
- **Verify navigation stack depth** with `Navigator.of(context).canPop()`
  assertions where it matters (e.g. account deletion should not be poppable
  back into a deleted account).

## Firestore lane in journey tests

Journey tests that need real Firestore semantics use:
```dart
setUp(() async { firestore = await firestoreForLane(); });
tearDown(() async { await clearLane(); });
```
With `skip: emulatorOnlySkip` if it's an emulator-only test. See
`test/test_support/emulator_lane.dart` for lane-management API.

## Flake catalog (append entries here when you fix one)

*Date / journey / root cause / fix.*

---

## Discovered patterns

*Append new dated, trigger-tagged entries below.*

### 2026-04-25 — initial seed
Knowledge file seeded from inventory of `test/views/` and `test/e2e/`.
Future entries should record real flake fixes, journey-boundary
clarifications, and new patterns this codebase has discovered — not
re-derivations of what's already here.

### 2026-06-28 — deep-link routing journey pattern [Pattern discovered]

**Journey:** `butlery://import?url=...` → SmartImport (BUT-1439).

**Key findings:**

1. `DeepLinkHandler` is a singleton (`DeepLinkHandler()` returns `_instance`).
   Call `handler.reset()` in `setUp` to clear `_pendingDeepLink` / `_isInitialized`
   state left from prior test runs or `initialize()` calls.

2. `processDeepLink` is an INSTANCE method (not static). Obtain via `DeepLinkHandler()`.

3. Auth gate (`authRepo.currentUser == null` → return early) is a genuine
   false-green risk: if AuthRepository is not in the ServiceLocator with a
   non-null `currentUser`, the method silently stores `_pendingDeepLink` and
   returns without pushing anything. Use:
   ```dart
   TestServiceLocator.registerMock<AuthRepository>(
     MockFactory.createAuthRepository(isAuthenticated: true, userId: 'test-user'),
   );
   ```
   after `TestServiceLocator.initialize()` + `prod_locator.ServiceLocator.initialize(DIContainer())`.

4. `processDeepLink` swallows ALL errors in a bare `catch (e) {}`. Guard against
   false-greens by asserting the NavigatorObserver spy actually recorded a push
   whose `settings.name == Routes.smartImport`. An empty `namedPushes` list with
   a clear `reason:` message exposes silent failures.

5. Use `tester.runAsync(() async { await handler.processDeepLink(...); })` to
   drive the real async work, then `await tester.pumpAndSettle(Duration(seconds:3))`
   to let the route settle.

6. Stub `onGenerateRoute` to return a trivial `Scaffold` for every route name.
   This lets `pushNamed(Routes.smartImport, ...)` succeed without pulling in
   SmartImportView's full ImportManager / connectivity / clipboard DI graph.

7. Route catalog addition: **Deep-link import** |
   `deep_link_import_journey_test.dart` | proves `butlery://import?url=...`
   lands on Routes.smartImport with the decoded URL as arguments; also proves
   an unknown host (`butlery://evil.example.com/x`) pushes nothing.

### 2026-07-01 — onboarding age-gate rejection journey (BUT-1437) [Pattern discovered]

**Journey:** under-15 age-gate rejection in `onboarding_journey_test.dart`.

**Stub-must-mirror-production rule (the real lesson):** the journey stub
`_OnboardingBody` had been advancing page 0 with a plain `viewModel.nextPage()`,
which NEVER called `verifyAgeGate()`. The stub was silently diverging from the
production handler `OnboardingView._handleNext`
(`lib/views/onboarding/onboarding_view.dart` ~L279-297). A journey stub that
skips the gate proves nothing about the gate. When a stub stands in for a
production navigation handler, its branch must mirror the production switch
arm-for-arm (here: `verifyAgeGate()` → switch on `AgeGateAdvanceResult` with
`rejected`→route-away, `error`→stay, `compliant`→advance). Added a code comment
in the stub pinning it to the prod line range so a future refactor of either
side is forced to reconcile.

**User-visible contract over method-spy:** the rejection assertion proves the
*routing* (a `Key('start_screen')` stand-in for prod's
`pushNamedAndRemoveUntil(Routes.auth)` replaces the whole wizard) AND that the
UGC pages (`page_allergens`/`page_dietary`/`page_import`) are unreachable — not
merely that `verifyAge` was called. The start-screen swap is done with a
`ValueNotifier<bool>` driving a `ValueListenableBuilder` at `home`, so the
onboarding tree is genuinely removed, mirroring the stack replacement.

**verify-at-gate, not at-completion:** asserted `verifyAge` is called EXACTLY
ONCE in BOTH the compliant and the rejected journeys. The VM sets
`_ageVerifiedThisSession` on a compliant gate result so `completeOnboarding`'s
belt doesn't re-verify — pinning that the check fires at the gate, not twice.
A second under-15 affordance (`Key('age_gate_set_minor')`,
`year - 10`) parallels the existing adult one.
