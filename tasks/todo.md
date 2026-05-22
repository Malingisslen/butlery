# Sprint Backlog

## Sprint: wave-11 — server-side account-deletion (BUT-788) — 2026-05-22 (Fr)

Theme: BUT-788 server-side account-deletion. Eliminates the auth-context race in the prior client-driven cascade by moving Firestore cleanup to a new `requestAccountDeletion` callable Cloud Function that calls `admin.auth().deleteUser(uid)` LAST.

### Agent A: cloud-functions-specialist + firebase-backend-security — BUT-788 server-side account-deletion
- [x] Step 0: read current code + classify (verdict: **fits** — destination matches ticket intent; existing `onUserDeleted` v1 trigger already owns cross-user cleanup, so the new CF only ports own-data cascade)
- [x] New CF `functions/src/account/request-account-deletion.ts` — callable, re-auth gate (`auth_time` < 5min), audit log, Storage cleanup, `admin.auth().deleteUser(uid)` LAST
- [x] New cascade module `functions/src/account/account-deletion-cascade.ts` — 24 own-data delete steps mirroring prior Flutter modules (3-tier orchestration: own-content → user-subcoll → user-root)
- [x] Registered in `functions/src/index.ts`; `tsc --noEmit` clean
- [x] Client `lib/services/account/account_deletion_service.dart` rewritten as ~190-line CF wrapper (was 430). Deleted: 4 `*DeletionOperations` modules (~1,050 lines)
- [x] DI in `core_module.dart` reduced from 17 deps to 4
- [x] Client unit test rewritten (6 tests pass): success path, `requires-recent-login` translation, search-index + offline-cache pre-cleanup ordering, no-auth short-circuit, failed-cascade still-signs-out
- [x] TS orchestrator test (4 tests pass): full-step shape, audit-log schema, auth-delete-failure handling, 180-day expireAt
- [x] `flutter analyze --fatal-infos` clean on lib/ + test/
- [x] Existing `profile_viewmodel_test.dart` (105 tests) + `account_deletion_journey_test.dart` (3 tests) still green

### Follow-ups filed in Linear
- BUT-1009 (Medium) — per-step Firestore integration test against emulator (current orchestrator test uses empty-snapshot fake)
- BUT-1010 (High, blocked on BUT-760) — enforce App Check on `requestAccountDeletion` once mobile attestation is registered
- BUT-1011 (Low) — async status-polling for very large account deletion (only if 9-min timeout is hit in prod telemetry)

### Post-sprint
- [ ] code-reviewer / firebase-backend-security / testing-specialist sign-offs (in progress)
- [ ] Commit + push
- [ ] Close BUT-788 in Linear
- [ ] CI watcher

---

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — focused single-item sprint for BUT-782 (URGENT FCMService static→instance + DI refactor) per its own ticket guidance. **Shipped:** BUT-782 (660-line rewrite, 23 tests up from 19, 218/218 in test/unit/services/notifications/). **Follow-ups filed:** BUT-1006 (High, re-bind consent listener on re-login — pre-existing latent bug), BUT-1007 (Medium, cover consent-change + token-refresh stream paths), BUT-1008 (Low, make MockFirebaseMessaging composable). **Deferred:** BUT-788 → wave-11.

### Original wave-10 plan (kept for context)

#### Agent A: cloud-functions-specialist + testing-specialist — BUT-782 (URGENT) FCMService → instance + DI
- [x] Convert `lib/services/notifications/fcm_service.dart` to instance + `BaseService`
- [x] Register in `MessagingModule` (not new `notifications_module.dart` — ticket permitted this; one less module)
- [x] Migrate 2 production callers in `notification_service.dart`
- [x] Rewrite 30+ test sites in `fcm_service_test.dart` (23 tests final count)
- [x] code-reviewer + testing-specialist + firebase-backend-security sign-offs

#### Post-sprint
- [x] `dart analyze --fatal-infos` clean
- [x] Full notifications/ test suite green (218/218)
- [x] Follow-up Linear tickets filed (BUT-1006, BUT-1007, BUT-1008)
- [x] Commit 826dceed1 (BUT-782) pushed
- [x] BUT-782 closed in Linear
- [ ] CI watcher (running in background)

---

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage continuation. **Shipped:** BUT-888 (categorize_ingredient + ner runners wired, 10/10 baseline locked in, ner skip-gated on env vars). Pre-sprint: BaseFirebaseRepository batch + FirebaseMessagingRepository facade test coverage (52 tests). **Filed follow-ups:** BUT-1003 (batch ops catch-swallow), BUT-1004 (categorizer enhancement), BUT-1005 (NER fixture model). **Deferred:** BUT-782 + BUT-788 → wave-10 (each merits a focused sprint).

### Original wave-9 plan (kept for context)

#### Pre-sprint (1)
- [x] **P0. Commit 3 orphan test files** — wave-8 coverage continuation:
  - `test/unit/repositories/firebase/base_firebase_repository_extra_test.dart` (CRUD + batch + cache contract)
  - `test/unit/repositories/firebase/firebase_messaging_repository_facade_test.dart` (delegation + validate quartet)
  - `test/unit/repositories/firebase/firebase_user_repository_gaps_test.dart` (formatter-only diff)
  - Standalone commit before wave-9 work so they don't entangle.

### Agent A: cloud-functions-specialist + testing-specialist — BUT-782 (URGENT) FCMService → instance + DI
- [ ] **A1. Convert `lib/services/notifications/fcm_service.dart` to instance.**
  - `class FCMService extends BaseService with ErrorHandlingMixin`
  - Constructor-inject: `FirebaseMessaging`, `ConsentService`, `FlutterLocalNotificationsPlugin`, optional `Future<UserService> Function()` for lazy access (avoid circular DI).
  - Convert all static fields → instance fields (`_messaging`, `_localNotifications`, `_onMessageReceived`, `_onMessageOpenedApp`, token-refresh subscription, consent-change subscription, dispose flag, etc.).
  - Subscriptions cancel in `onDispose()`. `serviceName => 'FCMService'`.
- [ ] **A2. DI registration.**
  - Create `lib/core/di/notifications_module.dart` (or extend existing notification-related module) — register `FCMService` as singleton with `BaseService` lifecycle.
  - Wire into the main DI container alongside `NotificationService`.
- [ ] **A3. Migrate production callers.**
  - `lib/services/notifications/notification_service.dart:168` + `:431` — `ServiceLocator.get<FCMService>()`.
  - Search `grep "FCMService\."` for any other touched site.
- [ ] **A4. Rewrite tests.**
  - `test/unit/services/notifications/fcm_service_test.dart` — 30+ sites use `FCMService.staticMethod`. Migrate to constructor-injected instance + `service.method`.
  - Drop `FCMService.setMessagingForTest` seam; replace with constructor injection of fake messaging.
  - Keep behavioural assertions identical — this is a refactor, not a feature change.

### Agent B: cloud-functions-specialist + firebase-backend-security — BUT-788 (Bug+security) server-side account-deletion
- [ ] **B1. Audit current flow.**
  - Find client-side `user.delete()` call (likely `lib/services/account/account_deletion_service.dart` or `lib/services/gdpr/*`).
  - Map current CF: `functions/src/account/request-account-deletion.ts` (or similar).
- [ ] **B2. Server-side single-callable.**
  - CF runs: all Firestore cascades → Storage cleanup → `auth.deleteUser(uid)` via Admin SDK (LAST step).
  - Re-auth check: client passes fresh ID token; CF verifies `auth_time` < 5 min.
  - Audit-log entries with deterministic `actor='system'`, `subject=uid` throughout.
- [ ] **B3. Client-side becomes one-call.**
  - Remove `firebaseAuth.user.delete()` from `account_deletion_service.dart`.
  - After CF responds, sign out locally; never call `user.delete()`.
  - Surface `requires-recent-login` from the CF response (not client SDK).
- [ ] **B4. Tests.**
  - CF integration test exercises full path on emulator (re-auth → cascade → admin auth delete → audit-log assertions).
  - Client unit test: deletion service no longer references `user.delete()`.

### Agent C: testing-specialist + flutter-developer — BUT-888 (test-gap) wire 2 on-device LLM golden runners — DONE
- [x] **C1.** `IngredientCategorizer` extracted to `lib/services/tagging/`; ShoppingListGenerator updated (35/35 tests pass).
- [x] **C2.** `test/golden/llm/categorize_ingredient_test.dart` ships — set-equality baseline (10/10 passing).
- [x] **C3.** `test/golden/llm/ner_test.dart` ships — gated on `NER_MODEL_PATH` env var; skips cleanly (see BUT-1005).
- [x] **C4.** Workflow wired with corpus_filter fall-through for unwired choices.

### Post-Sprint Status
- [x] `dart analyze --fatal-infos` clean
- [x] code-reviewer + testing-specialist agents reviewed BUT-888 + pre-sprint coverage
- [x] Follow-up Linear tickets filed: BUT-1003 (batch ops catch-swallow), BUT-1004 (categorizer enhancement), BUT-1005 (NER fixture model)
- [x] Commits 55d49d993 + 602420b91 (BUT-888) pushed
- [ ] BUT-888 closed in Linear
- [ ] CI watcher

---

## Archived wave-8 (commit 633595561 — bundled into "test(repositories): cover BaseFirebaseRepository CRUD + batch + cache (20 tests)") — 2026-05-22

wave-8 — LLM golden-set foundation + cascade-audit sweep + UI migration P1 + privacy drafts — 2026-05-21 (Th) — BUT-784/886/882/887 all shipped. BUT-782 + BUT-877 deferred (BUT-782 picked up in wave-9).

## Archived wave-7 (commit 5bd98f8e8 / 7ed82246c)

wave-7 — analytics wiring + repo-audit security + privacy docs + dedup pass — BUT-878/455/811/798 shipped. BUT-875/829/859 closed as obsolete/duplicate. BUT-877 still open (blocked on prod).

## Archived wave-6 (commit 273152149)

wave-6 — model-integrity test contract fix + cooking-mode analytics + ops runbooks — BUT-876/802/452 shipped. BUT-874 closed as premise-gone.

## Archived wave-5 (commit b66f5892f)

wave-5 — image-quality OCR gate + test-gap closures + adoption metric — BUT-660/872/865/866/873 shipped.

## Archived wave-4 (commit 90d88cfca / b115d7519)

wave-3 follow-ups + UI consolidation continuation — BUT-868/869/870/871/867/776/864.

## Archived wave-3 (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
