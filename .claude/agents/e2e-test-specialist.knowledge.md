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
