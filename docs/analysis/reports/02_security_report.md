# Butlery Security and Compliance Analysis - Phase 1

```
BUTLERY SECURITY AND COMPLIANCE ANALYSIS - PHASE 1
====================================================
Analysis Date: 2026-02-26
Analyst: Claude (Opus 4.6)
Framework: OWASP Mobile Application Security Top 10 (2024)
Previous Audit: 2026-02-10 (Score: 76/100)
Delta: 13 commits since prior audit, all feature work (no security fixes)

OVERALL SECURITY SCORE: 67/100

+-- OWASP Mobile Top 10:                13/20 points
+-- Authentication & Session:           14/18 points
+-- Data Protection & Encryption:       13/18 points
+-- Network Security:                    8/12 points
+-- Firebase Security Rules:             9/12 points
+-- API Security & Secret Management:    4/10 points
+-- Code Protection & Platform:          6/10 points

SECURITY POSTURE: Needs Improvement

VULNERABILITY SUMMARY:
- CRITICAL (CVSS 9.0-10.0): 1 vulnerability
- HIGH (CVSS 7.0-8.9): 2 vulnerabilities
- MEDIUM (CVSS 4.0-6.9): 27 vulnerabilities
- LOW (CVSS 0.1-3.9): 16 vulnerabilities

TOP 5 SECURITY RISKS:
1. .env files bundled as Flutter assets -- all API keys extractable from APK (S-01, CVSS 9.1)
2. OCR/Vision API keys exposed client-side via direct HTTP calls (S-02, CVSS 7.5)
3. FieldEncryptionService registered but never called -- zero fields encrypted (D-02, CVSS 7.5)
4. Deep link handler processes links without auth check or input validation (C-12/C-13, CVSS 6.8)
5. friendCategories rules allow any authenticated user to add themselves (F-02, CVSS 6.5)
```

---

## Previous Audit Findings Status

| Prior Finding | Prior Severity | Status | Notes |
|---|---|---|---|
| H-01: sendNotification lacks sender-recipient auth | HIGH | **RESOLVED** | Conversation membership check added (A-15) |
| H-02: SSL pinning fails open on error | HIGH | **STILL OPEN** | `createPinnedClient()` returns unpinned client (N-05) |
| H-03: Release build signed with debug keys | HIGH | **STILL OPEN** | `build.gradle.kts:38` still uses debug signing (C-04) |
| M-01: SharedPreferences stores biometric flag | MEDIUM | **RESOLVED** | Biometric feature removed from project scope |
| M-02: No session inactivity timeout | MEDIUM | **RESOLVED** | `SessionTimeoutService` implemented (A-06) |

---

## Dimension 1: OWASP Mobile Top 10 Compliance (13/20)

| OWASP Category | Status | Findings | Max CVSS | Remediation Effort |
|---|---|---|---|---|
| M1: Improper Platform Usage | Pass | 1 info (orphaned Face ID perm) | 3.0 | 1 hour |
| M2: Insecure Data Storage | Partial | 4 issues | 7.5 | 16 hours |
| M3: Insecure Communication | Partial | 3 issues | 5.9 | 12 hours |
| M4: Insecure Authentication | Partial | 3 issues | 6.1 | 8 hours |
| M5: Insufficient Cryptography | Partial | 4 issues | 5.9 | 10 hours |
| M6: Insecure Authorization | Partial | 5 issues | 6.5 | 16 hours |
| M7: Client Code Quality | Partial | 2 issues | 5.5 | 4 hours |
| M8: Code Tampering | Partial | 3 issues | 6.5 | 8 hours |
| M9: Reverse Engineering | Fail | 1 critical | 9.1 | 20 hours |
| M10: Extraneous Functionality | Pass | 2 low | 3.5 | 2 hours |

### M1: Improper Platform Usage -- PASS

Android and iOS platform APIs used correctly. `android:allowBackup="false"`, network security config enforces HTTPS, permissions are appropriate (INTERNET, CAMERA, READ_MEDIA_IMAGES). One orphaned `NSFaceIDUsageDescription` in Info.plist (biometric feature removed from scope -- C-09).

### M2: Insecure Data Storage -- PARTIAL

- **D-02**: `FieldEncryptionService` is built (AES-256-CBC, proper key management) but never wired into any repository -- zero user data benefits from client-side encryption.
- **D-03**: All 3 `FlutterSecureStorage` instances missing `encryptedSharedPreferences: true` on Android.
- **D-09**: Recipes stored as JSON in SharedPreferences (medium sensitivity, app-sandboxed).
- **D-10**: Drift/SQLCipher properly encrypted (PASS).

### M3: Insecure Communication -- PARTIAL

- **N-05**: `SslPinningService.createPinnedClient()` returns a vanilla `http.Client()` -- no actual pinning. The `secureGet()`/`securePost()` methods that enforce pinning have zero callers.
- **N-06**: External APIs (OCR.space, Algolia, Tesseract) not covered by certificate pinning.
- **N-08**: 4 services create raw `http.Client()` bypassing the pinning layer entirely.
- Android network security config and iOS ATS both enforce HTTPS (PASS). No `badCertificateCallback` bypasses found (PASS).

### M4: Insecure Authentication -- PARTIAL

- **A-11**: FCM tokens not cleaned up on logout -- push notifications continue to the device.
- **A-03**: No email verification after registration.
- **A-02**: Password change accepts 6-char minimum despite `strongPassword()` validator existing.
- Session timeout implemented at 45 minutes with lifecycle awareness (PASS, previously M-02). MFA fully implemented via SMS (PASS).

### M5: Insufficient Cryptography -- PARTIAL

- **D-01**: AES-256-CBC (unauthenticated) instead of AES-256-GCM. CBC is vulnerable to padding oracle attacks.
- **D-05**: Key rotation destroys old data with no migration path.
- **D-04**: `dart:math Random()` (non-cryptographic PRNG) used in 5 locations including correlation IDs.
- **D-17**: Encryption key generation uses `FortunaRandom` seeded with `Random.secure()` (PASS).

### M6: Insecure Authorization -- PARTIAL

- **F-02**: `friendCategories` update rule lets any authenticated user add themselves to any group.
- **F-01**: `friendCategories` get rule allows any authenticated user to read any category by ID.
- **F-03**: Global `ingredients` collection has no security rule (reads fail silently).
- **F-12**: `menu_activity` create allows any authenticated user without membership check.
- PermissionValidationMixin adoption at 77% (corrected from previously claimed 20%).

### M7: Client Code Quality -- PARTIAL

- **C-06**: `_ErrorApp` exposes full stack traces and exception messages to end users in release builds.
- **C-07**: `DeepLinkHandler.debugInfo` getter exposes pending deep link URLs without `kDebugMode` guard.

### M8: Code Tampering -- PARTIAL

- **C-04**: Release build uses debug signing config (`signingConfigs.getByName("debug")`).
- **C-01**: No AAB build with obfuscation in CI (only APK has `--obfuscate`).
- **C-03**: Overly broad ProGuard `-keep` rules retain all of AndroidX, reducing R8 effectiveness.
- `isMinifyEnabled = true` and `isShrinkResources = true` in release builds (PASS).

### M9: Reverse Engineering -- FAIL

- **S-01**: `.env` files (containing Firebase keys, OCR.space key, Google Vision key, Algolia key, reCAPTCHA key) are bundled as Flutter assets in every release build. Extractable via `apktool` or even `unzip` on any APK.
- **S-02**: OCR/Vision API keys sent directly from the client in HTTP requests.

### M10: Extraneous Functionality -- PASS

- **C-16**: Python `site-packages` directory in `lib/` (development tooling for DIRIGERA lamp hook).
- **C-17**: TODO comments in build config for application ID and signing.
- No debug endpoints, dev credentials, or test backdoors found in release code paths.

### Butlery-Specific OWASP Checks

1. **FCM Token Security**: Tokens stored in `FlutterSecureStorage` (PASS). User-scoped in Firestore with proper rules (PASS). **Not cleaned on logout** (A-11, FAIL).
2. **Real-time Collaboration Security**: Presence system correctly enforces self-write-only (`request.auth.uid == userId`). Recipe presence readable by all authenticated users (F-10, accepted for collaborative awareness).
3. **Copy-on-Write Pattern**: Shared content uses subcollection-based membership model, not document references. Content isolation is properly maintained.

---

## Dimension 2: Authentication and Session Security (14/18)

### Findings

| ID | Severity | CVSS | Description | File |
|---|---|---|---|---|
| A-02 | MEDIUM | 4.3 | Weak password policy on password change (6-char min, no complexity) | `auth_viewmodel.dart:299`, `account_security_viewmodel.dart:32` |
| A-03 | MEDIUM | 5.3 | No email verification after registration | `auth_service.dart:55-66` |
| A-07 | LOW | 2.4 | No concurrent session management | N/A (missing feature) |
| A-09 | LOW | 2.0 | No MFA recovery codes or TOTP support | `auth_service.dart` MFA section |
| A-11 | HIGH | 6.1 | FCM tokens not cleaned on normal logout | `auth_service.dart:142-151` |
| A-14 | MEDIUM | 4.3 | Server-side rate limiter fails open for auth operations | `rate_limiter.ts:224-236` |
| A-16 | MEDIUM | 5.0 | Missing Firestore rules for `user_devices` and `deletion_audit_logs` | `firestore.rules` (missing) |
| A-17 | LOW | 2.0 | Email partially logged in debug output, full email on re-auth | `auth_service.dart:101`, `firebase_auth_repository.dart:224` |
| A-18 | LOW | 2.0 | Account deletion misses FCM token collections | `account_deletion_service.dart:89-106` |

### Positive Findings

- Session timeout fully implemented (45 min, 5 min warning, lifecycle-aware) -- **previous M-02 resolved**
- Notification sender-recipient auth check added -- **previous H-01 resolved**
- MFA implemented with SMS enrollment, sign-in challenge, unenrollment
- All auth tokens in `FlutterSecureStorage`, none in SharedPreferences
- Firebase Auth SDK handles token refresh automatically
- Rate limiting on auth operations (client + server, token bucket algorithm)

---

## Dimension 3: Data Protection and Encryption (13/18)

### Findings

| ID | Severity | CVSS | Description | File |
|---|---|---|---|---|
| D-01 | MEDIUM | 5.3 | AES-256-CBC instead of AES-256-GCM (no authenticated encryption) | `field_encryption_service.dart:72-83` |
| D-02 | HIGH | 7.5 | FieldEncryptionService registered in DI but never called -- zero fields encrypted | `core_module.dart:212-214` |
| D-03 | HIGH | 6.8 | All 3 `FlutterSecureStorage` instances missing `encryptedSharedPreferences: true` | `app_database.dart:120`, `field_encryption_service.dart:33`, `fcm_token_manager.dart:74` |
| D-04 | MEDIUM | 4.3 | `dart:math Random()` (non-crypto PRNG) used in 5 locations | `correlation_id.dart:21`, 4 others |
| D-05 | MEDIUM | 5.9 | Key rotation destroys old data with no migration path | `field_encryption_service.dart:196-204` |
| D-06 | HIGH | 6.5 | Account deletion missing 4 collections: notification_preferences, fcm_tokens, user_devices, consent | `account_deletion_service.dart:89-106` |
| D-07 | HIGH | 6.1 | `deletion_audit_logs` collection has no Firestore rule -- writes fail silently | `firestore.rules` (missing) |
| D-08 | MEDIUM | 4.7 | Consent model writes `grantedAt` but rule requires `timestamp` field | `user_consent.dart:44-53`, `firestore.rules:1288` |
| D-09 | LOW | 3.1 | Recipes stored as JSON in SharedPreferences (plaintext) | `persistence_service.dart:105-133` |
| D-12 | LOW | 2.4 | Cached network images not encrypted at rest | 9 widgets using `CachedNetworkImage` |
| D-15 | LOW | 2.1 | UserId logged extensively in AppLogger | Multiple files |
| D-19 | MEDIUM | 4.0 | Social deletion batch may exceed 500-doc Firestore limit | `social_deletion_operations.dart:11-78` |

### GDPR Compliance Report

| Article | Requirement | Implementation | Test Coverage | Score |
|---|---|---|---|---|
| Art. 7 | Consent Management | ConsentService: 6 granular purposes, version tracking, withdrawal, consent history, opt-in only | 38 tests | 8/10 |
| Art. 15 | Right of Access | DataExportService: 17 data categories, paginated, JSON format, self-service | 14 tests | 9/10 |
| Art. 17 | Right to Erasure | AccountDeletionService: 16 collections deleted, audit trail. Missing: notification_preferences, fcm_tokens, user_devices, consent | 15 tests | 7/10 |
| Art. 20 | Data Portability | DataExportService: JSON (machine-readable), comprehensive coverage, FCM tokens properly excluded | 14 tests | 9/10 |
| Art. 30 | Processing Records | FirebaseAuditRepository: immutable audit trail, user write-only, permission checks logged. Missing: deletion_audit_logs rule, no automated retention policy | Tests exist | 7/10 |

### Storage Security Matrix

| Storage | Encrypted | Actual Data | Required Protection | Status |
|---|---|---|---|---|
| SharedPreferences | No | Recipes (JSON), menus, view preferences, theme, locale | Medium (app-sandboxed) | ACCEPTABLE |
| FlutterSecureStorage | Yes (platform) | DB key, field encryption key, FCM tokens | Critical | PARTIAL (D-03) |
| Drift/SQLCipher | Yes (AES-256) | Offline recipes, sync queue, parse cache | Medium | PASS |
| Firestore | Yes (Google-managed) | All user content, PII, social data | Depends on rules | PASS |
| File system cache | No | Recipe images, avatars | Low | ACCEPTABLE |

---

## Dimension 4: Network Security (8/12)

### Findings

| ID | Severity | CVSS | Description | File |
|---|---|---|---|---|
| N-02 | MEDIUM | 3.7 | iOS ATS not explicitly configured (relies on default) | `Info.plist` |
| N-04 | LOW | 2.0 | URL import accepts HTTP input without auto-upgrade | `url_import_strategy.dart:64-65` |
| N-05 | HIGH | 5.9 | `createPinnedClient()` returns unpinned `http.Client()`; `secureGet`/`securePost` unused | `ssl_pinning_service.dart:95-101` |
| N-06 | MEDIUM | 4.8 | Non-Google external APIs not pinned (OCR.space, Algolia, Tesseract) | `ssl_pinning_service.dart:29-36` |
| N-08 | MEDIUM | 4.2 | 4 services create raw `http.Client()` bypassing SSL pinning layer | `http_content_fetcher.dart:24`, 3 others |
| N-13 | LOW | 1.8 | Hardcoded `butlery.app` URL (acceptable for own domain) | `deep_link_service.dart:67` |
| N-14 | LOW | 1.0 | Hardcoded Google Vision API endpoint | `ocr_extraction_service.dart:405` |

### Positive Findings

- Android `cleartextTrafficPermitted="false"` (PASS)
- No `badCertificateCallback` bypasses anywhere (PASS)
- No insecure WebSocket usage -- Firebase SDK handles all real-time (PASS)
- All external API calls use HTTPS endpoints (PASS)
- Appropriate request timeouts on all HTTP calls (PASS)
- No sensitive data logged from HTTP operations (PASS)

---

## Dimension 5: Firebase Security Rules (9/12)

### Collection Coverage Summary

74 match rules audited across 73 collections/subcollections. Full coverage table in appendix.

**Highlights:**
- Default deny on unmatched paths (PASS)
- Strong ownership model across virtually all collections (PASS)
- Allergen-critical data validated with `isValidTagResult()` and `_isValidUserIngredient()` (PASS)
- Immutable audit trail (update/delete denied on `audit_logs`) (PASS)
- Shared content subcollection pattern consistently applied (PASS)

### Findings

| ID | Severity | CVSS | Description | File |
|---|---|---|---|---|
| F-01 | HIGH | 5.3 | `friendCategories` get allows any authenticated user to read any category | `firestore.rules:186` |
| F-02 | HIGH | 6.5 | `friendCategories` update allows any user to add themselves to any group | `firestore.rules:192-195` |
| F-03 | HIGH | 5.3 | Top-level `ingredients` collection missing from rules (reads fail) | `firestore.rules` (missing) |
| F-04 | MEDIUM | 4.3 | `sharedRecipes` (camelCase) missing -- rules have `shared_recipes` (snake_case) | `firebase_search_repository.dart:34` |
| F-05 | MEDIUM | 4.3 | `users/{userId}/rateLimits` subcollection undocumented in rules | `rate_limiter.ts:128-133` |
| F-07 | MEDIUM | 5.3 | Rate limiter middleware fails open on Firestore errors | `rate_limiter.ts:224-236` |
| F-08 | MEDIUM | 5.3 | sendNotification/sendNotificationBatch lack rate limiting | `send-notification.ts:62` |
| F-11 | MEDIUM | 4.3 | `shoppingLists` delete rule uses fallback that allows orphaned doc deletion | `firestore.rules:1042-1043` |
| F-12 | MEDIUM | 4.3 | `menu_activity` create allows any auth user without membership check | `firestore.rules:1373-1374` |
| F-13 | MEDIUM | 4.3 | `globalRecipeCache` create has no field validation or size limits | `firestore.rules:1388-1389` |
| F-14 | MEDIUM | 3.7 | `isServerTimestamp()` helper defined but never used in any rule | `firestore.rules:45-47` |
| F-16 | MEDIUM | 4.3 | OCR Cloud Function accepts arbitrary `imageUrl` (potential SSRF) | `ocr-recipe-image.ts:68-76` |
| F-06 | LOW | 3.1 | `system_events` collection not explicitly documented in rules | `rate_limiter.ts:248` |
| F-09 | LOW | 3.1 | Notification error response leaks internal details | `send-notification.ts:265-268` |
| F-10 | LOW | 2.7 | `recipePresence` parent doc readable by all authenticated users | `firestore.rules:848-849` |
| F-15 | LOW | 2.0 | Shared recipe images publicly readable without auth | `storage.rules:35` |

### PermissionValidationMixin Adoption (Corrected)

| Metric | Value |
|---|---|
| Repositories extending BaseFirebaseRepository | 20 |
| Total Firestore-based repositories | 26 |
| Adoption rate | **76.9%** |
| Previous report claim | 20% (incorrect) |

The 6 non-adopting repositories are either read-only (`IngredientRepository`, `SearchRepository`), audit-only (`AuditRepository`), presence-only (`RecipePresenceRepository`), or use their own auth checks (`UserIngredientRepository`, `SocialRecipeRepository`).

---

## Dimension 6: API Security and Secret Management (4/10)

### Findings

| ID | Severity | CVSS | Description | File |
|---|---|---|---|---|
| S-01 | **CRITICAL** | **9.1** | .env files bundled as Flutter assets -- all API keys extractable from APK | `pubspec.yaml:138-141` |
| S-02 | HIGH | 7.5 | OCR/Vision API keys exposed via direct client HTTP calls | `ocr_extraction_service.dart:342,405-408` |
| S-04 | LOW | 1.0 | Commented-out `Bearer YOUR_BITLY_ACCESS_TOKEN` placeholder | `deep_link_service.dart:322-335` |
| S-07 | MEDIUM | 3.0 | 4 env vars consumed but missing from .env.example | `.env.example` |
| S-08 | MEDIUM | 3.5 | CI/CD builds lack .env creation/injection step | `build-validation.yml` |
| S-12 | MEDIUM | 4.0 | Rate limiter fails open (duplicate of F-07) | `rate_limiter.ts:224-236` |
| S-14 | LOW | 2.0 | Historical credential exposure (6 months, resolved but residual risk) | Git history |
| S-15 | LOW | 1.5 | No secret scanning in pre-commit hooks (lefthook has format+analyze only) | `lefthook.yml` |

### Positive Findings

- No hardcoded API key strings in Dart source (PASS)
- Cloud Functions use Firebase `defineSecret()` correctly (PASS)
- `.gitignore` comprehensive for .env and Firebase config files (PASS)
- No secret echo/exposure in CI workflows (PASS)
- Firebase config files not tracked in git (PASS)

---

## Dimension 7: Code Protection and Platform Security (6/10)

### Findings

| ID | Severity | CVSS | Description | File |
|---|---|---|---|---|
| C-01 | HIGH | 5.3 | No AAB build with obfuscation in CI (only APK) | `build-validation.yml:87` |
| C-02 | MEDIUM | 4.0 | No iOS build with obfuscation in CI | `.flutter_ci.yml.disabled` |
| C-03 | MEDIUM | 3.7 | Overly broad ProGuard `-keep` rules (all of AndroidX retained) | `proguard-rules.pro:6-24` |
| C-04 | HIGH | 6.5 | Release build uses debug signing config | `build.gradle.kts:38` |
| C-05 | LOW | 2.0 | iOS `COPY_PHASE_STRIP = NO` in Release | `project.pbxproj:513` |
| C-06 | HIGH | 5.5 | `_ErrorApp` exposes full stack traces in release builds | `main.dart:166-173` |
| C-07 | MEDIUM | 3.5 | `debugInfo` getter exposes deep link URLs without kDebugMode guard | `deep_link_handler.dart:218-222` |
| C-08 | LOW | 2.5 | Jailbreak detection fails open silently | `device_integrity_service.dart:39-43` |
| C-09 | MEDIUM | 3.0 | Orphaned Face ID permission (biometric feature removed) | `Info.plist:57-59` |
| C-12 | HIGH | 6.1 | Deep link parameters not validated (no format/length/sanitization) | `deep_link_handler.dart:94-119` |
| C-13 | HIGH | 6.8 | Deep link processed without authentication check | `deep_link_handler.dart:148-161` |
| C-14 | MEDIUM | 4.3 | Predictable short code generation (timestamp-based, not random) | `firebase_deeplink_repository.dart:249-261` |
| C-15 | MEDIUM | 4.0 | Custom `butlery://` scheme accepts any host | `AndroidManifest.xml:74-79` |
| C-16 | MEDIUM | 3.5 | Python site-packages in lib/ directory | `lib/site-packages/` |
| C-17 | LOW | 2.0 | TODO comments for application ID and signing in build config | `build.gradle.kts:23,36-37` |
| C-18 | LOW | 1.5 | Disabled workflow has build without obfuscation | `.flutter_ci.yml.disabled:243` |

### Positive Findings

- Firebase App Check enabled for production (Play Integrity, DeviceCheck, reCAPTCHA v3)
- `AppLogger.debug()` uses `assert()` -- compiled out in release builds
- `kDebugMode` guards used consistently across 35+ locations
- R8 minification enabled (`isMinifyEnabled = true`, `isShrinkResources = true`)
- `android:allowBackup="false"` correctly set
- Network security config enforces HTTPS

---

## Security Risk Matrix

```
                    IMPACT
              Low    Medium    High    Critical
         +--------+---------+--------+---------+
  High   |        |  A-03   | S-01   |         |
         |        |  A-14   | S-02   |         |
L        |        |  F-08   |        |         |
I   Med  | C-09   |  D-01   | D-02   |         |
K        | C-16   |  D-04   | D-03   |         |
E        | N-02   |  D-08   | D-06   |         |
L        |        |  F-14   | C-12   |         |
I        |        |  C-14   | C-13   |         |
H   Low  | A-07   |  D-05   | F-01   |         |
O        | A-09   |  N-05   | F-02   |         |
O        | C-05   |  N-06   | F-03   |         |
D        | C-08   |  C-04   | D-07   |         |
         | S-04   |  C-06   | A-11   |         |
         +--------+---------+--------+---------+
```

**Risk Concentration**: The highest-risk quadrant (High Likelihood x High Impact) contains the .env bundling issue (S-01) and client-side API key exposure (S-02). The Medium Likelihood x High Impact quadrant is densely populated with authorization, encryption, and deep link findings.

---

## Remediation Roadmap

### Phase 1: Critical Vulnerabilities (Week 1) -- P0

Must fix before any production deployment. Addresses CVSS 9.0+ findings.

| Fix | Finding | Effort | Risk Reduction |
|---|---|---|---|
| Move OCR/Vision API calls to Cloud Functions (follow Mistral pattern) | S-01, S-02 | 16 hours | Eliminates CRITICAL secret exposure |
| Switch to `--dart-define` for Firebase keys, remove .env from assets | S-01 | 8 hours | Eliminates .env bundling |
| Add `encryptedSharedPreferences: true` to all FlutterSecureStorage | D-03 | 1 hour | Strengthens Android key storage |
| Guard `_ErrorApp` with `kDebugMode` -- generic message in release | C-06 | 1 hour | Prevents stack trace leakage |

**Total effort: 26 hours. Expected risk reduction: 35%.**

### Phase 2: High Priority (Weeks 2-3) -- P1

Fix within sprint. Addresses CVSS 5.0-8.9 findings with high likelihood.

| Fix | Finding | Effort | Risk Reduction |
|---|---|---|---|
| Fix `friendCategories` rules (restrict get + update) | F-01, F-02 | 4 hours | Closes authorization bypass |
| Add deep link input validation + auth gating | C-12, C-13 | 8 hours | Prevents auth bypass + injection |
| Clean FCM tokens on logout (before signOut) | A-11, A-18 | 4 hours | Stops post-logout notifications |
| Wire `SslPinningService.secureGet/Post` into all HTTP callers | N-05, N-08 | 8 hours | Activates existing SSL pinning |
| Add missing Firestore rules (ingredients, deletion_audit_logs, rateLimits) | F-03, D-07, A-16 | 4 hours | Closes rule gaps |
| Fix consent model field name mismatch (grantedAt vs timestamp) | D-08 | 1 hour | Ensures consent writes succeed |
| Add 4 missing collections to account deletion | D-06 | 4 hours | Completes GDPR Art. 17 |
| Configure release signing with production keystore | C-04 | 4 hours | Required for store deployment |
| Add AAB build with obfuscation to CI | C-01 | 2 hours | Protects Play Store builds |
| Use `Random.secure()` for deep link short codes | C-14 | 1 hour | Prevents code enumeration |

**Total effort: 40 hours. Expected risk reduction: 30%.**

### Phase 3: Medium Priority (Month 2) -- P2

Scheduled hardening. Addresses CVSS 3.0-6.9 findings.

| Fix | Finding | Effort | Risk Reduction |
|---|---|---|---|
| Wire FieldEncryptionService into message/comment repositories | D-02 | 12 hours | Encrypts sensitive user content |
| Upgrade AES-CBC to AES-GCM (authenticated encryption) | D-01 | 8 hours | Prevents ciphertext tampering |
| Add rate limiting to notification Cloud Functions | F-08 | 4 hours | Prevents notification spam |
| Implement key versioning for encryption key rotation | D-05 | 8 hours | Enables safe key rotation |
| Add email verification after registration | A-03 | 6 hours | Proves email ownership |
| Apply `strongPassword()` to password change flow | A-02 | 2 hours | Consistent password policy |
| Add server timestamp enforcement on audit_logs, friend_requests | F-14 | 4 hours | Prevents timestamp manipulation |
| Fix menu_activity, globalRecipeCache, shoppingLists rule gaps | F-12, F-13, F-11 | 4 hours | Tightens rule validation |
| Add URL validation to OCR Cloud Function (prevent SSRF) | F-16 | 2 hours | Blocks internal network access |
| Pin external APIs (OCR.space, Algolia) | N-06 | 4 hours | Extends MITM protection |
| Remove orphaned Face ID permission | C-09 | 0.5 hours | Clean platform config |
| Move Python site-packages out of lib/ | C-16 | 0.5 hours | Clean project structure |
| Add secret scanning to pre-commit hooks | S-15 | 2 hours | Prevents accidental commits |
| Narrow ProGuard keep rules | C-03 | 4 hours | Improves R8 effectiveness |
| Fix social deletion batch overflow risk | D-19 | 4 hours | Prevents deletion failures |

**Total effort: 65 hours. Expected risk reduction: 20%.**

---

## Penetration Testing Readiness Checklist

- [x] OWASP Mobile Top 10 self-assessment complete
- [ ] All critical vulnerabilities remediated (S-01 blocking)
- [ ] Security rules reviewed and updated (F-01, F-02, F-03 blocking)
- [ ] Release signing configured (C-04 blocking)
- [ ] Test accounts and environment prepared
- [ ] Vulnerability disclosure policy documented
- [ ] Incident response plan in place
- [ ] Security testing tools identified (MobSF, OWASP ZAP, Burp Suite, Frida)
- [ ] Scope defined (in-scope vs out-of-scope endpoints)

---

## Appendix A: All Findings by Severity

### CRITICAL (CVSS 9.0-10.0)

| ID | CVSS | Description |
|---|---|---|
| S-01 | 9.1 | .env files bundled as Flutter assets -- all API keys (Firebase, OCR, Vision, Algolia, reCAPTCHA) extractable from release builds |

### HIGH (CVSS 7.0-8.9)

| ID | CVSS | Description |
|---|---|---|
| S-02 | 7.5 | OCR/Vision API keys sent in client-side HTTP requests |
| D-02 | 7.5 | FieldEncryptionService registered but never called |

### MEDIUM (CVSS 4.0-6.9)

| ID | CVSS | Description |
|---|---|---|
| D-03 | 6.8 | FlutterSecureStorage missing encryptedSharedPreferences on Android |
| C-13 | 6.8 | Deep link processed without authentication check |
| D-06 | 6.5 | Account deletion missing 4 collections (GDPR Art. 17) |
| C-04 | 6.5 | Release build uses debug signing config |
| F-02 | 6.5 | friendCategories update allows any user to add themselves |
| D-07 | 6.1 | deletion_audit_logs has no Firestore rule |
| A-11 | 6.1 | FCM tokens not cleaned on logout |
| C-12 | 6.1 | Deep link parameters not validated |
| D-05 | 5.9 | Key rotation destroys old data |
| N-05 | 5.9 | SSL pinning createPinnedClient returns unpinned client |
| C-06 | 5.5 | ErrorApp exposes stack traces in release |
| D-01 | 5.3 | AES-CBC instead of AES-GCM |
| F-01 | 5.3 | friendCategories get allows any auth user |
| F-03 | 5.3 | Global ingredients collection missing rules |
| F-07 | 5.3 | Rate limiter fails open |
| F-08 | 5.3 | Notification functions missing rate limiting |
| A-03 | 5.3 | No email verification after registration |
| C-01 | 5.3 | No AAB build with obfuscation |
| A-16 | 5.0 | Missing Firestore rules for user_devices, deletion_audit_logs |
| N-06 | 4.8 | External non-Google APIs not pinned |
| D-08 | 4.7 | Consent model/rule field name mismatch |
| D-04 | 4.3 | Insecure Random() in 5 locations |
| F-04 | 4.3 | sharedRecipes (camelCase) vs shared_recipes (snake_case) mismatch |
| F-05 | 4.3 | rateLimits subcollection undocumented |
| F-11 | 4.3 | shoppingLists delete rule fallback allows orphan deletion |
| F-12 | 4.3 | menu_activity create lacks membership check |
| F-13 | 4.3 | globalRecipeCache create has no validation |
| F-16 | 4.3 | OCR function accepts arbitrary imageUrl (SSRF risk) |
| A-14 | 4.3 | Server rate limiter fails open on auth operations |
| A-02 | 4.3 | Weak password policy on change path |
| N-08 | 4.2 | Raw http.Client instantiations bypass pinning |
| C-14 | 4.3 | Predictable short code generation |
| C-15 | 4.0 | Custom URL scheme without host validation |
| C-02 | 4.0 | No iOS build with obfuscation |
| D-19 | 4.0 | Social deletion batch overflow risk |
| S-08 | 3.5 | CI/CD builds lack .env injection |
| C-07 | 3.5 | debugInfo getter leaks deep link URLs |
| C-16 | 3.5 | Python site-packages in lib/ |
| N-02 | 3.7 | iOS ATS not explicitly configured |
| F-14 | 3.7 | isServerTimestamp() helper defined but never used |
| C-03 | 3.7 | Overly broad ProGuard keep rules |

### LOW (CVSS 0.1-3.9)

| ID | CVSS | Description |
|---|---|---|
| D-09 | 3.1 | Recipes in SharedPreferences (plaintext, app-sandboxed) |
| F-06 | 3.1 | system_events collection not in rules |
| F-09 | 3.1 | Notification error leaks internal details |
| S-07 | 3.0 | 4 env vars missing from .env.example |
| C-09 | 3.0 | Orphaned Face ID permission |
| F-10 | 2.7 | recipePresence readable by all auth users |
| C-08 | 2.5 | Jailbreak detection fails open |
| A-07 | 2.4 | No concurrent session management |
| D-12 | 2.4 | Cached images not encrypted |
| D-15 | 2.1 | UserId logged extensively |
| N-04 | 2.0 | URL import accepts HTTP |
| A-09 | 2.0 | No MFA recovery codes |
| A-17 | 2.0 | Email partially logged |
| A-18 | 2.0 | Account deletion misses FCM tokens |
| C-05 | 2.0 | iOS COPY_PHASE_STRIP disabled |
| C-17 | 2.0 | TODO in release build config |
| S-14 | 2.0 | Historical credential exposure |
| F-15 | 2.0 | Shared images publicly readable |
| N-13 | 1.8 | Hardcoded butlery.app URL |
| S-15 | 1.5 | No secret scanning in pre-commit |
| C-18 | 1.5 | Disabled workflow without obfuscation |
| S-04 | 1.0 | Commented-out placeholder token |
| N-14 | 1.0 | Hardcoded Vision API endpoint |

---

## Appendix B: Score Comparison

| Dimension | 2026-02-10 | 2026-02-26 | Delta | Notes |
|---|---|---|---|---|
| OWASP Mobile Top 10 | 15/20 | 13/20 | -2 | More thorough M9 analysis revealed S-01 |
| Authentication & Session | 13/18 | 14/18 | +1 | M-02 and H-01 resolved |
| Data Protection & Encryption | 15/18 | 13/18 | -2 | D-02 (encryption unused) and D-06 (deletion gaps) newly identified |
| Network Security | 10/12 | 8/12 | -2 | N-05 (pinning non-functional) analyzed deeper |
| Firebase Security Rules | 10/12 | 9/12 | -1 | F-01/F-02 friendCategories issues newly found |
| API Security & Secret Mgmt | 7/10 | 4/10 | -3 | S-01 CRITICAL .env bundling found |
| Code Protection & Platform | 6/10 | 6/10 | 0 | Deep link issues offset by confirmed positive findings |
| **Total** | **76/100** | **67/100** | **-9** | More thorough analysis, not regression |

The score decrease reflects deeper analysis, not security regression. The codebase has not changed in security-relevant ways since the prior audit. Key new findings (S-01, D-02, N-05) were present at the time of the prior audit but were not identified.

---

*Phase 1 complete. Zero code changes made. This report serves as input for Phase 2 remediation planning.*
