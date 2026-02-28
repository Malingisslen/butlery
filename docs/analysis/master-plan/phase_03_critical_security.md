# Phase 3: Critical Security (~4 days)

.env/API key exposure, rate limiters fail-open, Firebase rules gaps, deep link validation, debug signing, error app stack traces.

---

## P3-01 — Fix `runZonedGuarded` no-op [HIGH]

**Source**: R01:H7.2, R04 (implicit), R10:M5.1
**Files**: `lib/main.dart:152-165`
**Fix**: `runApp()` is called OUTSIDE the guarded zone. Move `runApp(const ButleryApp())` inside the `runZonedGuarded` body so async errors reach Crashlytics.
**Effort**: 1h

---

## P3-02 — `_ErrorApp` exposes stack traces in release [HIGH]

**Source**: R02:C-06, R10 (implicit)
**Files**: `lib/main.dart:166-173`
**Fix**: Guard `_ErrorApp` with `kDebugMode` — show generic error message in release builds.
**Effort**: 1h

---

## P3-03 — PII (user IDs, emails) in production logs [HIGH]

**Source**: R01:H7.1, R02:D-15, R02:A-17
**Files**: 80+ `AppLogger` calls across codebase, `lib/services/unified/operations/friends_invitations_operations.dart:145`, `lib/viewmodels/realtime/participant_tracker.dart:129`
**Fix**: Sanitize or hash PII before logging. `.info()`, `.warning()`, `.error()` forward to Crashlytics in release. GDPR Article 5(1)(c) data minimization risk.
**Effort**: 1d

---

## P3-04 — Rate limiters fail-open on errors [CRIT]

**Source**: R02:F-07, R02:A-14, R07:C6.1
**Files**: `lib/services/import/import_rate_limiter.dart:75-82`, `functions/src/middleware/rate_limiter.ts:224-236`
**Fix**: Both client and server rate limiters explicitly allow requests on Firestore errors. Change to fail-closed — deny on error, log alert.
**Effort**: 4h (2h client + 2h server)

---

## P3-05 — .env files bundled as Flutter assets [CRIT]

**Source**: R02:S-01, R02:S-02
**Files**: `pubspec.yaml:138-141`, `lib/services/extraction/ocr_extraction_service.dart:342,405-408`
**Fix**: (1) Switch to `--dart-define` for Firebase keys, remove .env from assets. (2) Move OCR/Vision API calls to Cloud Functions (follow Mistral pattern).
**Effort**: 2-3d

---

## P3-06 — SSL pinning non-functional [HIGH]

**Source**: R02:N-05, R02:N-08
**Files**: `lib/services/network/ssl_pinning_service.dart:95-101`
**Fix**: `createPinnedClient()` returns unpinned `http.Client()`. Wire `secureGet()`/`securePost()` into all HTTP callers. Also: 4 services create raw `http.Client()` bypassing pinning.
**Effort**: 8h

---

## P3-07 — Firestore rules gaps [HIGH]

**Source**: R02:F-01, R02:F-02, R02:F-03, R02:D-07, R02:A-16, R02:F-04, R02:F-05, R02:F-11, R02:F-12, R02:F-13
**Files**: `firestore.rules`
**Fix** (combined):
- `friendCategories` get/update allows any auth user (F-01, F-02) → restrict to owner
- Global `ingredients` collection missing (F-03) → add rules
- `deletion_audit_logs` no rule (D-07) → add write rule
- `user_devices` / `deletion_audit_logs` missing (A-16) → add rules
- `sharedRecipes` camelCase vs `shared_recipes` snake_case mismatch (F-04)
- `rateLimits` subcollection undocumented (F-05)
- `shoppingLists` delete rule fallback (F-11)
- `menu_activity` create lacks membership check (F-12)
- `globalRecipeCache` create no validation (F-13)
**Effort**: 8h total

---

## P3-08 — Deep link validation and auth [HIGH]

**Source**: R02:C-12, R02:C-13, R02:C-14, R02:C-15
**Files**: `lib/services/deep_link/deep_link_handler.dart:94-119,148-161`, `lib/repositories/firebase/firebase_deeplink_repository.dart:249-261`, `AndroidManifest.xml:74-79`
**Fix**: (1) Validate deep link parameters (format, length, sanitization). (2) Require auth before processing deep links. (3) Use `Random.secure()` for short code generation. (4) Validate host for `butlery://` scheme.
**Effort**: 8h

---

## P3-09 — `FlutterSecureStorage` missing `encryptedSharedPreferences` [HIGH]

**Source**: R02:D-03
**Files**: `lib/core/database/app_database.dart:120`, `lib/services/encryption/field_encryption_service.dart:33`, `lib/services/notifications/fcm_token_manager.dart:74`
**Fix**: Add `encryptedSharedPreferences: true` to all 3 `FlutterSecureStorage` instances (Android platform).
**Effort**: 1h

---

## P3-10 — FCM tokens not cleaned on logout [HIGH]

**Source**: R02:A-11, R02:A-18
**Files**: `lib/services/auth/auth_service.dart:142-151`, `lib/services/account/account_deletion_service.dart:89-106`
**Fix**: Clean FCM tokens before `signOut()`. Also add FCM token cleanup to account deletion.
**Effort**: 4h

---

## P3-11 — `FieldEncryptionService` registered but never called [HIGH]

**Source**: R02:D-02
**Files**: `lib/core/di/modules/core_module.dart:212-214`
**Fix**: Wire FieldEncryptionService into message/comment repositories for sensitive user content. Or remove if not needed.
**Effort**: 12h (wire) or 1h (remove)

---

## P3-12 — `debugInfo` getter exposes deep link URLs [MED]

**Source**: R02:C-07
**Files**: `lib/services/deep_link/deep_link_handler.dart:218-222`
**Fix**: Gate behind `kDebugMode`.
**Effort**: 15 min

---

## P3-13 — Insecure `Random()` in 5 locations [MED]

**Source**: R02:D-04
**Files**: `lib/core/correlation_id.dart:21`, 4 others
**Fix**: Replace `dart:math Random()` with `Random.secure()` in security-relevant contexts (correlation IDs, short codes).
**Effort**: 1h

---

## P3-14 — Overly broad ProGuard keep rules [MED]

**Source**: R02:C-03
**Files**: `android/app/proguard-rules.pro:6-24`
**Fix**: Narrow `-keep` rules — currently retains all of AndroidX, reducing R8 effectiveness.
**Effort**: 4h

---

## P3-15 — No server-side rate limiting on UGC [HIGH]

**Source**: R09:TS-037
**Files**: `firestore.rules`
**Fix**: Add `request.time`-based rate limiting rules for comments, messages, and social actions. Client-side rate limiter resets on app restart.
**Effort**: 1-2d

---

## P3-16 — Block not enforced server-side [HIGH]

**Source**: R09:TS-005
**Files**: `firestore.rules`
**Fix**: Add rules checking `blockedUsers` before allowing reads/writes on social collections. Currently client-side only.
**Effort**: 1d

---

## P3-17 — Block list not loaded on startup [HIGH]

**Source**: R09:TS-004
**Files**: `lib/services/unified/friends/friends_state_manager.dart`
**Fix**: Add `_loadBlockedUsers()` call in `initialize()`. Blocked users appear unblocked after restart.
**Effort**: 2h

---

## P3-18 — Add secret scanning to pre-commit hooks [LOW]

**Source**: R02:S-15
**Files**: `lefthook.yml`
**Fix**: Add secret pattern scanning (API keys, passwords) to pre-commit hooks.
**Effort**: 2h
