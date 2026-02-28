# Track 1: AI/LLM Pipeline + Dependencies — Decisions

**Branch**: `track-1/ai-deps`
**Date**: 2026-02-28

## Phase 5 — AI/LLM Safety & Quality

All 20 items implemented except one:

### P5-17 — Golden regression dataset: DEFERRED

The plan marked this "if time" with a 3-day estimate. Creating 20-30 diverse golden recipes with expected outputs is a manual curation task that doesn't block any other work. It should be done as a dedicated follow-up when we have real production data to base the test cases on.

---

## Phase 9 — Dependencies & Tech Debt

8 of 14 items implemented. Remaining 6 explained below.

### P9-07 — csv 6.0.0 → 7.1.0: BLOCKED (SDK version)

csv 7.x requires Dart SDK ≥3.10.1. The project is on Dart 3.9.0 (Flutter 3.32.4). Upgrading the SDK is a separate, broader decision that affects all dependencies and CI. Revisit after the next Flutter stable release.

The pubspec now has a comment noting the constraint: `csv: ^6.0.0  # (7.x needs Dart 3.10+)`.

### P9-17 — Remove friends_service_stubs.dart: SKIPPED (not dead code)

The plan identified this as dead stubs, but investigation found that `UnifiedFriendsService` actively imports and uses `FriendsServiceCoordinator`, `FriendsSyncService`, `FriendsPresenceService`, and `FriendsCacheService` from this file. Removing it would break compilation. The plan item was incorrect.

### P9-21 — Move lib/site-packages/ → scripts/site-packages/: SKIPPED (doesn't exist)

The directory `lib/site-packages/` does not exist in the codebase. Nothing to move.

### P9-05 — Remove recipe_backward_compatibility_mixin.dart: SKIPPED (doesn't exist)

The file `lib/models/recipe_backward_compatibility_mixin.dart` does not exist. The deprecated annotations mentioned in the plan item were not found either. Likely already cleaned up in a prior session.

### P9-08 — Upgrade drift + drift_dev (2.29.0 → 2.31.0): BLOCKED (Flutter SDK)

drift_dev 2.31.0 requires `sqlparser ^0.43.1`, which requires `analyzer >=8.1.0`. The `test` package must also upgrade to 1.27.0+ for analyzer 8.x compatibility, but `test 1.27.0` requires `test_api: 0.7.8` — and Flutter 3.35.1 pins `test_api: 0.7.6` in its SDK. These constraints are mutually exclusive. Drift 2.29.0 is the highest resolvable version on Flutter 3.35.1.

Revisit after the next Flutter stable release (which will ship a newer `test_api`).

### P9-01 — Migrate sqlcipher_flutter_libs: DEFERRED (needs EOL verification)

The plan says to verify EOL on pub.dev first. As of 2026-02-28, `sqlcipher_flutter_libs 0.6.4` is still maintained. No migration needed until an actual EOL announcement. This is a risk-aware deferral, not a skip — should be checked quarterly.

### P9-20 — Duration constants: DONE

Created `lib/core/constants/durations.dart` with the most commonly repeated values (debounce, timeouts, caching, retention). Animation durations already live in `theme_constants.dart` and were not duplicated. Existing code can be migrated to use these constants incrementally — no bulk refactor was done to avoid a large diff in this track.

---

## Dependency Upgrades Applied

| Package | Before | After | Notes |
|---------|--------|-------|-------|
| algoliasearch | ^1.36.1 | ^1.46.1 | Patch upgrade |
| get_it | ^9.0.5 | ^9.2.1 | Patch upgrade |
| uuid | ^4.5.1 | ^4.5.3 | Patch upgrade |
| flutter_local_notifications | ^20.0.0 | ^20.1.0 | Patch upgrade |
| device_info_plus | ^11.1.0 | ^12.3.0 | Major upgrade |
| image_cropper | ^8.0.0 | ^11.0.0 | Major upgrade |
| flutter_jailbreak_detection | ^1.10.0 | — | Removed |
| freerasp | — | ^7.4.0 | Replacement (root/jailbreak + tampering + Frida detection) |
| flutter_cache_manager | ^3.4.1 | — | Removed (transitive dep, zero imports) |

## Verification

- `npx tsc --noEmit` (functions/) — clean
- `flutter analyze` — clean (only pre-existing .env asset warnings)
