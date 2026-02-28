# Phase 3: Critical Security (~7 days)

.env/API key exposure, rate limiters fail-open, Firebase rules gaps, deep link validation, error app stack traces.

---

## P3-01 — Fix main.dart release safety [HIGH]

**Source**: R01:H7.2, R02:C-06, R04 (implicit), R10:M5.1, R10 (implicit)
**Files**: `lib/main.dart:152-173`
**Fix**: (1) `runApp()` is called OUTSIDE the guarded zone — move `runApp(const ButleryApp())` inside `runZonedGuarded` so async errors reach Crashlytics. (2) `_ErrorApp` exposes stack traces in release — guard with `kDebugMode`, show generic error message.
**Effort**: 1.5h

---

## P3-02 — PII (user IDs, emails) in production logs [HIGH]

**Source**: R01:H7.1, R02:D-15, R02:A-17
**Files**: 80+ `AppLogger` calls across codebase, `lib/services/unified/operations/friends_invitations_operations.dart:145`, `lib/viewmodels/realtime/participant_tracker.dart:129`
**Fix**: Sanitize or hash PII before logging. `.info()`, `.warning()`, `.error()` forward to Crashlytics in release. GDPR Article 5(1)(c) data minimization risk.
**Effort**: 1d

---

## P3-03 — Rate limiters fail-open on errors [CRIT]

**Source**: R02:F-07, R02:A-14, R07:C6.1
**Files**: `lib/services/import/import_rate_limiter.dart:75-82`, `functions/src/middleware/rate_limiter.ts:224-236`
**Fix**: Both client and server rate limiters explicitly allow requests on Firestore errors. Change to fail-closed — deny on error, log alert.
**Effort**: 4h (2h client + 2h server)

---

## P3-04 — .env files bundled as Flutter assets [CRIT]

**Source**: R02:S-01, R02:S-02
**Files**: `pubspec.yaml:137-141`
**Fix**: Switch to `--dart-define` for Firebase keys, remove .env from assets. ~~OCR client-side API key~~ — obsolete, OCR service already moved to Cloud Functions.
**Effort**: 1-2d

---

## P3-05 — SSL pinning non-functional [HIGH]

**Source**: R02:N-05, R02:N-08
**Files**: `lib/core/network/ssl_pinning_service.dart:95-101`
**Fix**: `createPinnedClient()` returns unpinned `http.Client()`. Wire `secureGet()`/`securePost()` into all HTTP callers. Also: 4 services create raw `http.Client()` bypassing pinning.
**Effort**: 8h

---

## P3-06 — Firestore rules gaps (remaining) [HIGH]

**Source**: R02:D-07, R02:F-05
**Files**: `firestore.rules`
**Fix**: 6 of 9 original gaps already fixed (friendCategories, ingredients, sharedRecipes naming, shoppingLists delete, menu_activity create, globalRecipeCache validation). **Remaining**:
- `deletion_audit_logs` no rules (D-07)
- `rateLimits` subcollection rules missing (F-05)
**Effort**: 3h

---

## P3-07 — Deep link validation, auth, and debug exposure [HIGH]

**Source**: R02:C-07, R02:C-12, R02:C-13, R02:C-14, R02:C-15
**Files**: `lib/services/deep_link/deep_link_handler.dart:94-119,148-161,218-222`, `lib/repositories/firebase/firebase_deeplink_repository.dart:249-261`, `AndroidManifest.xml:74-79`
**Fix**: (1) Validate deep link parameters (format, length, sanitization). (2) Require auth before processing deep links. (3) Validate host for `butlery://` scheme. (4) Gate `debugInfo` getter behind `kDebugMode`. Note: `Random.secure()` for short codes is covered by P3-11.
**Effort**: 8h

---

## P3-08 — `FlutterSecureStorage` missing `encryptedSharedPreferences` [HIGH]

**Source**: R02:D-03
**Files**: `lib/core/database/app_database.dart:120`, `lib/services/encryption/field_encryption_service.dart:33`, `lib/services/notifications/fcm_token_manager.dart:74`
**Fix**: Add `encryptedSharedPreferences: true` to all 3 `FlutterSecureStorage` instances (Android platform).
**Effort**: 1h

---

## P3-09 — FCM tokens not cleaned on logout [HIGH]

**Source**: R02:A-11, R02:A-18
**Files**: `lib/services/auth/auth_service.dart:142-151`
**Fix**: Clean FCM tokens before `signOut()`. Account deletion FCM cleanup is covered by P2-14.
**Effort**: 4h

---

## P3-10 — `FieldEncryptionService` registered but never called [HIGH]

**Source**: R02:D-02
**Files**: `lib/core/di/modules/core_module.dart:212-214`
**Fix**: Wire FieldEncryptionService into message/comment repositories for sensitive user content. Or remove if not needed.
**Effort**: 12h (wire) or 1h (remove)

---

## P3-11 — Insecure `Random()` in correlation IDs [MED]

**Source**: R02:D-04
**Files**: `lib/core/utils/correlation_id.dart:21`
**Fix**: Replace `dart:math Random()` with `Random.secure()` for correlation IDs (low risk, debug only). Note: `firebase_deeplink_repository` uses `DateTime.now().millisecondsSinceEpoch`, not `Random()` — different weakness (predictable but not insecure random).
**Effort**: 30 min

---

## P3-12 — Overly broad ProGuard keep rules [MED]

**Source**: R02:C-03
**Files**: `android/app/proguard-rules.pro:6-24`
**Fix**: Narrow `-keep` rules — currently retains all of AndroidX, reducing R8 effectiveness.
**Effort**: 4h

---

## P3-13 — No server-side rate limiting on UGC [HIGH]

**Source**: R09:TS-037
**Files**: `firestore.rules`
**Fix**: Add `request.time`-based rate limiting rules for comments, messages, and social actions. Client-side rate limiter resets on app restart.
**Effort**: 1-2d

---

## P3-14 — Block not enforced server-side [HIGH]

**Source**: R09:TS-005
**Files**: `firestore.rules`
**Fix**: Add rules checking `blockedUsers` before allowing reads/writes on social collections. Currently client-side only.
**Effort**: 1d

---

## P3-15 — Block list not loaded on startup [HIGH]

**Source**: R09:TS-004
**Files**: `lib/services/unified/friends/friends_state_manager.dart`
**Fix**: Add `_loadBlockedUsers()` call in `initialize()`. Blocked users appear unblocked after restart.
**Effort**: 2h

---

## P3-16 — Add secret scanning to pre-commit hooks [LOW]

**Source**: R02:S-15
**Files**: `lefthook.yml`
**Fix**: Add secret pattern scanning (API keys, passwords) to pre-commit hooks.
**Effort**: 2h

---

## P3-17 — Notification functions missing rate limiting [MED]

**Source**: R02:F-08
**Files**: `functions/src/notifications/send-notification.ts:62`
**Fix**: `sendNotification` / `sendNotificationBatch` lack rate limiting. Abuse vector for notification spam.
**Effort**: 4h

---

## P3-18 — OCR Cloud Function SSRF risk [MED]

**Source**: R02:F-16
**Files**: `functions/src/llm/ocr-recipe-image.ts:68-76`
**Fix**: Add URL validation to prevent arbitrary `imageUrl` fetching internal network resources.
**Effort**: 2h

---

## P3-19 — Notification error response leaks internal details [LOW]

**Source**: R02:F-09
**Files**: `functions/src/notifications/send-notification.ts:265-268`
**Fix**: Sanitize error response — currently exposes internal error messages to caller.
**Effort**: 30 min
