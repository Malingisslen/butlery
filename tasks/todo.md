# Sprint Backlog

## Sprint: wave-15 — wave-13/14 follow-up cleanup + quick refactors — 2026-05-23 (Sa)

Theme: 2 wave-14 stragglers (BUT-1022, BUT-1026) + 3-ticket wave-13 backend follow-up cluster + 3 quick wins / remaining test follow-up. All single-area-per-batch, no architectural changes, 90-min time-box on the one investigation item.

### Agent A — wave-14 stragglers (`testing-specialist` for A1, `debugger` for A2)
- [ ] **A1. BUT-1022 (High)** — `test/unit/services/ocr_extraction_service_test.dart` + `test/unit/viewmodels/photo_import_viewmodel_test.dart`: integration-style tests for `_classifyProviderErrors` → `_buildEnhancedErrorMessage` metadata-string contract. Cases: 429 → `errorOcrRateLimit`, `TimeoutException` → `errorOcrTimeout`, `SocketException` → `errorOcrTimeout`, generic → `errorNoTextExtracted`.
- [ ] **A2. BUT-1026 (Medium, investigation — TIME-BOX 90 min)** — pull failing E2E run log, locate the test, reproduce locally. Fix if root cause is identified inside the box; otherwise file follow-ups and abandon.

### Agent B — wave-13 backend follow-up cluster (`flutter-developer` for B1/B2, `firebase-backend-security` for B3)
- [ ] **B1. BUT-1020 (Medium)** — `lib/services/storage_service.dart`: restore network pre-flight UX on `uploadImageFile`. Check `NetworkService.isOnline` before typed-exception path; throw `StorageUploadException(code: 'no-network')`. Coverage in `storage_service_test.dart`.
- [ ] **B2. BUT-1015 (Medium)** — `lib/viewmodels/recipe_list_viewmodel.dart` + `PersistenceService` keys: extend wave-13's filter-persistence to rating/allergen/dietary/personalTag filters + scroll offset. Mirror the existing two-filter persistence pattern verbatim.
- [ ] **B3. BUT-1017 (Medium, scope-limited)** — apply `mapFirebaseErrorMessage` across remaining repos/services. Audit list first (>6 files → stop and file follow-up). Only files where raw Firebase exceptions reach UI.

### Agent C — quick wins + remaining wave-13 test follow-up (`flutter-developer` for C1/C2, `testing-specialist` for C3)
- [ ] **C1. BUT-1019 (Low)** — `lib/viewmodels/onboarding_viewmodel.dart`: migrate `extends ChangeNotifier` → `extends BaseViewModel`. Verify no method conflict.
- [ ] **C2. BUT-1018 (Low)** — `lib/viewmodels/recipe_list_viewmodel.dart`: wrap `_persistActiveFilters` in existing `Debouncer` (300ms).
- [ ] **C3. BUT-1027 (Medium)** — `test/unit/repositories/firebase/firebase_storage_repository_simple_test.dart` + `test/unit/services/storage_service_test.dart`: end-to-end propagation chain tests (`FirebaseException` quota-exceeded → `StorageUploadException` → `UploadRetryManager.classifyError` → `ImageUploadErrorType.quotaExceeded`).

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean across `lib/` + `test/`
- [ ] `dart format --set-exit-if-changed lib test` clean
- [ ] Tier-2 agent reviews on staged `.dart` files (per CLAUDE.md hook map)
- [ ] Commit + push to main
- [ ] Close Linear tickets to Done
- [ ] CI watcher

### Known follow-ups (filed in Linear)
_None yet — will append during sprint as Tier-2 review surfaces additional gaps._

---

## Archived wave-14 (parallel-session ships) — 2026-05-23 (Sa)

wave-14 — 7 tickets planned (3 CI + 4 test-debt). A parallel Claude session shipped 5/7 today **without checking off this file**: BUT-1024 (SHA-pin), BUT-1025 (account_deletion `FirebaseAuth.instance` → `AuthRepository`), BUT-1021 (AuthService stream-error tests), BUT-1023 (Storage upload exception tests), BUT-1016 (typed-exception in `uploadImageBytes`). All five moved to Linear Done at 2026-05-23T11:06. Carry-over to wave-15: **BUT-1022** (OCR error-chain tests) + **BUT-1026** (E2E `_FocusInheritedScope` investigation). Lesson reinforced: trust Linear state over local todo.md when they disagree.

## Archived wave-13 (commits 3fc2d1edc + 66a786479 + 3f7d40412) — 2026-05-22 (Fr)

wave-13 — 9 Bug/UX tickets across onboarding/error-UX/import/recipe-list. 7 shipped (BUT-926, 971, 968, 966, 963, 959, 921), 2 marked obsolete/rescoped ([~] BUT-942 premise gone, [~] BUT-933 split into 1012/1013/1014). Follow-ups filed: BUT-1012, 1013, 1014, 1015, 1016, 1017. Per backlog dump, all wave-13 BUT-IDs already absent from Backlog — confirming Linear-Done state was reached.

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
