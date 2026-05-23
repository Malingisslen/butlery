# Sprint Backlog

## Sprint: wave-13 — bug/UX correctness across onboarding, error UX, import, recipe-list — 2026-05-22 (Fr)

Theme: nine Bug/UX tickets across four file-coherent batches. No new infra, no architectural changes — pure correctness wins.

### Agent A — Onboarding correctness (`lib/viewmodels/onboarding_viewmodel.dart`)
- [~] **A1. BUT-942** — Premise gone. Codebase already gates analytics at 4 layers (repo init / SDK enable / service logEvent / per-tracker). Ticket cancelled with verification comment.
- [x] **A2. BUT-926** — `_seedStarterRecipes()` now returns `Future<int>` and is awaited; new `onboardingRecipesSeedFailed` analytics event fires on partial failure.

### Agent B — Error UX polish (service-layer error surfacing)
- [x] **B1. BUT-971** — `StorageUploadException` typed exception. `FirebaseStorageRepository` rethrows on `FirebaseException(plugin: 'firebase_storage')`; `StorageService.uploadImageFile` bypasses `executeServiceOperation` so the typed exception reaches the classifier. New `ImageUploadErrorType.quotaExceeded` + `uploadFailureQuotaExceeded` localized copy.
- [x] **B2. BUT-968** — New `mapFirebaseErrorMessage` helper at `lib/core/utils/firebase_error_messages.dart`. Wired into `personal_recipe_operations.dart` catch blocks. Recognizes permission-denied, unauthorized, unauthenticated, unavailable, deadline-exceeded, network-request-failed.
- [x] **B3. BUT-966** — `auth_service.dart` onError handler now sets `_sessionExpired = true`, fires `sessionTimeoutLogout` analytics, then surfaces `errorSessionExpired` via setError after forceSignOut clears.

### Agent C — Import robustness (OCR/parser layer)
- [x] **C1. BUT-963** — Per-provider errors captured in `providerErrors` map; new `_classifyProviderErrors` returns `rate_limit | timeout | network | generic`. `photo_import_viewmodel.dart::_buildEnhancedErrorMessage` branches on this BEFORE the generic "no text extracted" fallback. New `errorOcrRateLimit` + `errorOcrTimeout` localized copy.
- [x] **C2. BUT-959** — `QuantityParser.parse` clamps negative values to 1.0 with warning. Matches existing invalid-input contract.

### Agent D — Recipe-list UX completion
- [~] **D1. BUT-933** — Re-scoped per Step 0. Wave-13 ships bulk-share only (the existing `UniversalShareDialog.bulkShare` factory takes a list). Tag / add-to-menu / export split into BUT-1012, BUT-1013, BUT-1014. New `selectedRecipes` getter on `RecipeListViewModel`.
- [x] **D2. BUT-921** — `PersistenceService.{get,set}Recipe{Time,MealType}Filters` added. `_loadDisplayPreferences` restores filters on init; toggle methods + `clearAllFilters` call new `_persistActiveFilters`. Rating/allergen/dietary/personalTag + scroll filed as BUT-1015.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean (full repo)
- [ ] Impacted tests pass
- [ ] Tier-2 agent reviews on changed `.dart` files
- [x] Follow-ups filed in Linear: BUT-1012, 1013, 1014 (BUT-933 split); BUT-1015 (BUT-921 rest); BUT-1016 (BUT-971 bytes path); BUT-1017 (BUT-968 broad sweep)
- [ ] Commit + push to main
- [ ] Close Linear tickets to Done
- [ ] CI watcher

### Known follow-ups (filed in Linear)
- BUT-1012 — Bulk tag on recipe-list selection
- BUT-1013 — Bulk add-to-menu on recipe-list selection
- BUT-1014 — Bulk export of selected recipes
- BUT-1015 — BUT-921 follow-up: persist remaining filters + scroll offset
- BUT-1016 — BUT-971 follow-up: typed-exception propagation in uploadImageBytes
- BUT-1017 — BUT-968 follow-up: apply `mapFirebaseErrorMessage` across remaining repos/services

---

## Archived wave-12 (commits 185ba807e + eb4562bc6) — 2026-05-22 (Fr)

wave-12 — 7 done + 2 deferred. Implementation bundled into 185ba807e (parallel session ate the message); tier-2 review findings in eb4562bc6. Linear tickets closed at 2026-05-22T20:13 (BUT-960/924/927/929/893/1003/1006 → Done; BUT-953/1009 → Backlog with re-scoped bodies).

## Archived wave-11 (commits 7551c14c2 + bca2f5bc7) — 2026-05-22 (Fr)

wave-11 — BUT-788 server-side account-deletion. Shipped: new `requestAccountDeletion` CF (re-auth gate, 24-step cascade, audit logs), client wrapper reduced 430→190 lines, 4 deletion modules deleted (~1,050 LOC), tests green. Follow-ups filed: BUT-1009 (integration test), BUT-1010 (App Check blocked on BUT-760), BUT-1011 (async polling for very-large accounts). BUT-788 closed in Linear.

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — BUT-782 FCMService static→instance + DI refactor. 660-line rewrite, 23 tests up from 19. Follow-ups: BUT-1006 (re-bind on re-login, completed in wave-12), BUT-1007 (consent/token stream tests), BUT-1008 (composable MockFirebaseMessaging).

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage. Shipped BUT-888. Follow-ups: BUT-1003 (batch ops catch-swallow, completed in wave-12), BUT-1004, BUT-1005.

## Archived wave-8 (commit 633595561) — 2026-05-22

wave-8 — BUT-784/886/882/887 shipped.

## Archived wave-7 (commit 5bd98f8e8 / 7ed82246c)

wave-7 — BUT-878/455/811/798 shipped.

## Archived wave-6 (commit 273152149)

wave-6 — BUT-876/802/452 shipped.

## Archived wave-5 (commit b66f5892f)

wave-5 — BUT-660/872/865/866/873 shipped.

## Archived wave-4 (commit 90d88cfca / b115d7519)

wave-3 follow-ups — BUT-868/869/870/871/867/776/864.

## Archived wave-3 (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
