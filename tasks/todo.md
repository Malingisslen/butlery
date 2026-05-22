# Sprint Backlog

## Sprint: wave-10 — FCM static-singleton refactor + server-side account-deletion (carried from wave-9) — TBD

Theme: focused single-item sprint for BUT-782 per its own ticket guidance (660-line refactor + 30+ test rewrites — won't fit alongside other work). Then BUT-788 (server-side account-deletion) once FCM lands.

### Agent A: cloud-functions-specialist + testing-specialist — BUT-782 (URGENT) FCMService → instance + DI
- [ ] Convert `lib/services/notifications/fcm_service.dart` to instance + `BaseService`
- [ ] Create `lib/core/di/notifications_module.dart`
- [ ] Migrate 2 production callers in `notification_service.dart`
- [ ] Rewrite 30+ test sites in `fcm_service_test.dart`
- [ ] testing-specialist + firebase-backend-security sign-offs

### Agent B (next sprint or same sprint if A finishes early): cloud-functions-specialist + firebase-backend-security — BUT-788 server-side account-deletion
- [ ] Audit current flow + map current CF
- [ ] Server-side single-callable (cascades → Storage → `auth.deleteUser`)
- [ ] Client becomes one-call (remove `firebaseAuth.user.delete()`)
- [ ] Re-auth `< 5min` enforcement on the CF
- [ ] CF integration test + client unit test

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
