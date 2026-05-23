# Sprint Backlog

## Sprint: wave-14 — CI hygiene + wave-13 test-debt tail — 2026-05-23 (Sa)

Theme: 3 CI-blocking issues + 4 test-gap follow-ups from wave-13's shipped error-UX work. All low-risk, two coherent agent batches.

### Agent A — CI hygiene (`firebase-backend-security` for BUT-1025, `code-reviewer` for the rest)
- [ ] **A1. BUT-1024** — `.github/workflows/`: SHA-pin `subosito/flutter-action@v2` to a specific commit SHA. Apply same pattern to any other third-party actions not yet pinned.
- [ ] **A2. BUT-1025** — `lib/services/account/account_deletion_service.dart`: replace `FirebaseAuth.instance` direct access with injected `AuthService` / `AuthRepository`. Constructor injection, update DI registration.
- [ ] **A3. BUT-1026** — Investigate E2E `StateError in _FocusInheritedScope` from CI. Likely a widget-test teardown ordering issue. Find offending test, add proper `tearDown` / wrap with `runAsync`.

### Agent B — Wave-13 test-debt tail (`testing-specialist`)
- [ ] **B1. BUT-1021** — `test/unit/services/auth_service_test.dart`: cover the new `authStateChanges` onError handler from BUT-966. Cases: stream emits error → `_sessionExpired=true` set, analytics event fires, `errorSessionExpired` surfaced after forceSignOut.
- [ ] **B2. BUT-1022** — `test/unit/viewmodels/photo_import_viewmodel_test.dart`: cover the `_classifyProviderErrors` branches from BUT-963 (rate_limit / timeout / network / generic) → enhanced error message routing.
- [ ] **B3. BUT-1023** — `test/unit/services/storage_service_test.dart`: cover `StorageUploadException` propagation from BUT-971. Cases: FirebaseException(plugin: firebase_storage) → typed exception → quotaExceeded classification.
- [ ] **B4. BUT-1016** — `lib/repositories/firebase/firebase_storage_repository.dart`: extend BUT-971 typed-exception propagation to `uploadImageBytes` (currently only `uploadImageFile` rethrows correctly). Add coverage in storage_service_test.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean
- [ ] Tier-2 agent reviews on staged `.dart` files
- [ ] Commit + push to main
- [ ] Close Linear tickets to Done
- [ ] CI watcher

### Known follow-ups (filed in Linear)
_None yet — will append during sprint as Tier-2 review surfaces additional gaps._

---

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
