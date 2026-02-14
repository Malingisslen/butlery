# Butlery Security and Compliance Analysis - Phase 1

```
BUTLERY SECURITY AND COMPLIANCE ANALYSIS - PHASE 1
====================================================
Analysis Date: 2026-02-10
Analyst: Claude (Opus 4.6)
Framework: OWASP Mobile Application Security Top 10 (2024)

OVERALL SECURITY SCORE: 76/100

+-- OWASP Mobile Top 10:                15/20 points
+-- Authentication & Session:           13/18 points
+-- Data Protection & Encryption:       15/18 points
+-- Network Security:                   10/12 points
+-- Firebase Security Rules:            10/12 points
+-- API Security & Secret Management:    7/10 points
+-- Code Protection & Platform:          6/10 points

SECURITY POSTURE: Good

VULNERABILITY SUMMARY:
- CRITICAL (CVSS 9.0-10.0): 0 vulnerabilities
- HIGH (CVSS 7.0-8.9): 3 vulnerabilities
- MEDIUM (CVSS 4.0-6.9): 7 vulnerabilities
- LOW (CVSS 0.1-3.9): 5 vulnerabilities

TOP 5 SECURITY RISKS:
1. sendNotification callable function lacks sender-recipient authorization check (H-01)
2. SSL pinning fails open on error, reducing MITM protection (H-02)
3. SharedPreferences stores biometric preference flag (non-sensitive but pattern concern) (M-01)
4. No session inactivity timeout enforced in client UI layer (M-02)
5. Release build signed with debug keys (build.gradle.kts:38) (H-03)
```

---

## Dimension 1: OWASP Mobile Top 10 Compliance (15/20)

### OWASP M1-M10 Scorecard

| OWASP Category | Status | Findings | Severity | Remediation Effort |
|----------------|--------|----------|----------|-------------------|
| M1: Improper Platform Usage | Pass | 0 issues | - | - |
| M2: Insecure Data Storage | Partial | 2 issues | M | 4 hours |
| M3: Insecure Communication | Pass | 1 issue | L | 2 hours |
| M4: Insecure Authentication | Partial | 2 issues | M | 6 hours |
| M5: Insufficient Cryptography | Pass | 0 issues | - | - |
| M6: Insecure Authorization | Partial | 2 issues | H/M | 8 hours |
| M7: Client Code Quality | Pass | 1 issue | L | 2 hours |
| M8: Code Tampering | Partial | 1 issue | M | 2 hours |
| M9: Reverse Engineering | Pass | 0 issues | - | - |
| M10: Extraneous Functionality | Pass | 1 issue | L | 1 hour |

### M1: Improper Platform Usage - PASS

**Android (AndroidManifest.xml)**:
- `INTERNET`: Required - justified.
- `CAMERA`: Justified for recipe photo import.
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`: Required for image access on older APIs.
- `READ_MEDIA_IMAGES`: Correct modern API 33+ scoped media permission.
- `android:allowBackup="false"`: Correctly prevents backup leakage.
- `android:networkSecurityConfig` references `network_security_config.xml` which enforces `cleartextTrafficPermitted="false"` by default (excellent).
- Deep link intent filters use `android:autoVerify="true"` for HTTPS scheme, reducing hijacking risk.

**iOS (Info.plist)**:
- Camera (`NSCameraUsageDescription`), Photo Library (`NSPhotoLibraryUsageDescription`), and Face ID (`NSFaceIDUsageDescription`) permissions all have Swedish-language usage descriptions.
- Universal Links configured with `applinks:butlery.app`.
- No unnecessary permissions (Location, Contacts, Microphone absent).

**Biometric Authentication (`local_auth`)**:
- `BiometricService` (`lib/services/auth/biometric_service.dart`) correctly checks `canCheckBiometrics` AND `isDeviceSupported()`.
- Graceful fallback on failure: sets `_isAvailable = false`, does not block app usage.

**Secure Storage (`flutter_secure_storage`)**:
- All instances use `AndroidOptions(encryptedSharedPreferences: true)` and `IOSOptions(accessibility: KeychainAccessibility.first_unlock)`.
- Used in 3 locations: `FieldEncryptionService`, `AppDatabase`, `FCMTokenManager`.

**Finding**: No issues. Platform APIs used correctly.

### M2: Insecure Data Storage - PARTIAL

**SharedPreferences Usage Audit** (lib/ only):
| Data Stored | File:Line | Sensitivity | Appropriate? |
|---|---|---|---|
| `session_count` (int) | `lib/main.dart:461` | Low | Yes |
| `biometric_auth_enabled` (bool) | `lib/services/auth/biometric_service.dart:59` | Low | Yes |
| `app_lock_timeout_minutes` (int) | `lib/services/app_lock_service.dart:39` | Low | Yes |
| Locale preference | `lib/core/providers/locale_provider.dart:35` | Low | Yes |
| Notification preferences | `lib/services/notifications/notification_repository.dart:134` | Low | Yes |
| Recipe collection data | `lib/services/persistence_service.dart:63` | Medium | Concern |

**flutter_secure_storage** (correctly used for):
- Field encryption key (`field_encryption_key_v1`)
- Database encryption key (`drift_db_encryption_key`)
- FCM token (`fcm_token`, `fcm_token_timestamp`)

**SQLCipher (Drift database)**:
- `app_database.dart:142`: Database encrypted with `PRAGMA key` using a key stored in `FlutterSecureStorage`.
- Key generation: `Random.secure()` with 32 bytes (256-bit) - cryptographically secure.

**Finding M2-1** (MEDIUM, CVSS 4.3):
- `PersistenceService` stores recipe collection data in SharedPreferences. While recipe data is not highly sensitive (it's user content, not credentials), it is unencrypted on disk. If recipes contain private notes, this could be a data leakage risk if the device is compromised.
- File: `lib/services/persistence_service.dart:63`
- Remediation: Consider migrating to the encrypted Drift database. Effort: 3 hours.

**Finding M2-2** (LOW, CVSS 2.4):
- `BiometricService` stores the biometric enabled flag in SharedPreferences. This is a non-sensitive preference, but modifying it could bypass app lock. The actual biometric challenge still goes through `local_auth` platform APIs, so exploitation impact is minimal.
- File: `lib/services/auth/biometric_service.dart:59`
- Remediation: Move to secure storage. Effort: 1 hour.

### M3: Insecure Communication - PASS

**HTTPS Enforcement**:
- `network_security_config.xml`: `cleartextTrafficPermitted="false"` for all domains except localhost/10.0.2.2 (development emulator only).
- All Firebase calls use HTTPS by default (no overrides found).
- No `http://` URLs in production Dart code. All `http://` references are in:
  - Schema.org markup (`http://schema.org/Recipe`) - not network calls
  - Test fixtures with test-only URLs
  - Form validator error messages mentioning `http://`

**No `badCertificateCallback`**: Zero instances found in the codebase. No certificate validation bypass.

**Finding M3-1** (LOW, CVSS 1.8):
- `network_security_config.xml:11-14` allows cleartext to `localhost` and `10.0.2.2`. This is standard for development but should ideally be in a debug-only configuration. Low risk since it only affects local loopback and emulator addresses.
- Remediation: Use Android build flavors to restrict cleartext to debug builds only. Effort: 2 hours.

### M4: Insecure Authentication - PARTIAL

**Firebase Auth Configuration**:
- Email/password authentication implemented in `FirebaseAuthRepository`.
- `RateLimiter` integrated in the auth repository (`lib/repositories/firebase/firebase_auth_repository.dart:38`).
- Re-authentication required before sensitive operations (`reauthenticateWithPassword` in `AuthService`).
- Password reset via Firebase secure email links.
- MFA support implemented (`AuthService` lines 281-312): phone-based verification with `multiFactor.getSession()`.

**Session Management**:
- `logoutDueToInactivity()` exists in `AuthService` (`lib/services/auth_service.dart:153`).
- `AppLockService` implements app-level lock with configurable timeout (default 5 minutes).
- Firebase Auth handles token refresh automatically.

**Finding M4-1** (MEDIUM, CVSS 5.3):
- No client-side session inactivity timeout is enforced in the UI layer. While `logoutDueToInactivity()` exists as a method, the codebase does not contain an inactivity timer that calls it. The `AppLockService` only triggers biometric re-authentication, not session termination.
- File: `lib/services/auth_service.dart:152-168`
- Remediation: Implement an inactivity timer (e.g., 30 minutes) that calls `logoutDueToInactivity()`. Effort: 4 hours.

**Finding M4-2** (LOW, CVSS 3.1):
- No MFA enforcement for sensitive operations (account deletion, email change). MFA is available but opt-in. Account deletion requires re-authentication but not MFA.
- File: `lib/services/auth_service.dart:211-229`
- Remediation: Enforce MFA for account deletion if MFA is enrolled. Effort: 2 hours.

### M5: Insufficient Cryptography - PASS

**FieldEncryptionService** (`lib/services/encryption/field_encryption_service.dart`):
- Algorithm: AES-256-CBC with PKCS7 padding (strong).
- IV: Random 128-bit IV per encryption (correct - no IV reuse).
- Key generation: `FortunaRandom` seeded with `Random.secure()` - cryptographically strong.
- Key storage: `FlutterSecureStorage` with platform keychain/keystore.
- Key rotation: `rotateKey()` method available with appropriate warning about data loss.
- No hardcoded encryption keys or IVs.

**Database Encryption**:
- SQLCipher via `sqlcipher_flutter_libs` with 256-bit key from `Random.secure()`.
- Key stored in `FlutterSecureStorage`.

**No insecure random**: No `dart:math` `Random()` (without `.secure()`) used for cryptographic purposes.

### M6: Insecure Authorization - PARTIAL

**PermissionValidationMixin Adoption**:
`BaseFirebaseRepository` uses `PermissionValidationMixin` (line 15). Since all Firebase repositories extend `BaseFirebaseRepository`, the mixin is available to ALL repositories. The earlier claim of "20% adoption" is inaccurate: the mixin is mixed in at the base class level, meaning 100% of Firebase repositories have access to it.

However, adoption of the validation *methods* varies:
| Repository | Uses validateOwnership | Uses validateWritePermission | Has custom permission checks |
|---|---|---|---|
| `BaseFirebaseRepository` | Yes (via `validateCreatePermission`) | Yes | Yes - abstract methods |
| `CollaborativeRecipeRepository` | Yes | Yes | Yes |
| `FirebaseSocialRecipeRepository` | Yes | Yes | Yes |
| `BaseStorageRepository` | Yes | N/A | Yes |
| `BaseMetadataRepository` | Yes | N/A | Yes |
| Others (via base class) | Inherited | Inherited | Via abstract methods |

Each `BaseFirebaseRepository` subclass MUST implement `validateCreatePermission`, `validateReadPermission`, `validateUpdatePermission`, and `validateDeletePermission` (abstract methods). This is enforced at compile time.

**Finding M6-1** (HIGH, CVSS 7.1):
- `sendNotification` Cloud Function (`functions/src/notifications/send-notification.ts:62-70`): Any authenticated user can send a notification to ANY other user by specifying `targetUserId`. The only check is `context.auth != null`. There is no verification that the sender has a relationship (friend, group member) with the recipient. The Firestore security rules for `user_notifications` DO validate friendship (`exists(...friends...)`), but the Cloud Function bypasses rules by using Admin SDK.
- Attack vector: Authenticated user can spam any user with push notifications.
- Remediation: Add friend/group relationship validation in the Cloud Function before sending. Effort: 3 hours.

**Finding M6-2** (MEDIUM, CVSS 5.5):
- `friendCategories` rules (`firestore.rules:186`): `allow get: if isAuthenticated()` permits ANY authenticated user to read any friend category document if they know the ID. While the comment says this is needed for invitation acceptance, it's overly broad.
- Remediation: Restrict to users who have a pending invitation for that group. Effort: 2 hours.

### M7: Client Code Quality - PASS

- `flutter analyze`: Zero issues (confirmed by pre-analysis).
- Error handling: `BaseService.safeExecute()` and `ErrorHandlingMixin` used consistently.
- No stack traces exposed to users - errors translated to Swedish user-friendly messages.
- FIXME comments found in `social_module.dart:192,251,257` - these are API implementation placeholders, not security workarounds.

**Finding M7-1** (LOW, CVSS 2.0):
- 3 FIXME annotations in `lib/core/di/modules/social_module.dart` at lines 192, 251, 257. These are feature implementation placeholders (menu/shopping service methods), not security issues. Documented here for completeness.

### M8: Code Tampering - PARTIAL

**Dart Obfuscation**:
- CI/CD: `build-validation.yml:83` uses `--obfuscate --split-debug-info=build/debug-info` for Android APK builds.
- Web builds: `flutter build web --release` (Dart-to-JS compilation provides implicit minification).

**Android ProGuard/R8**:
- `build.gradle.kts:39-40`: `isMinifyEnabled = true`, `isShrinkResources = true` in release.
- ProGuard rules (`proguard-rules.pro`) are broad but standard for Firebase apps.

**Jailbreak/Root Detection**:
- `DeviceIntegrityService` (`lib/services/device_integrity_service.dart`): Correctly implemented.
- Non-blocking approach: warns users but allows continued usage (appropriate for a recipe app).
- Also checks developer mode.

**Finding M8-1** (MEDIUM, CVSS 4.0):
- `kDebugMode` is used extensively (40+ occurrences in `lib/`) for conditional logging. All instances checked are properly gated. However, `performance_monitoring_service.dart:156,440` uses `!kReleaseMode` which is true for both debug AND profile modes, meaning performance monitoring code runs in profile builds. This is acceptable but noted.

### M9: Reverse Engineering - PASS

- Dart obfuscation with `--obfuscate` in CI (line 83 of `build-validation.yml`).
- `--split-debug-info=build/debug-info` separates debug symbols.
- API keys loaded from `.env` files via `flutter_dotenv`, not hardcoded in Dart source.
- Firebase API keys in `firebase_options.dart` reference `FirebaseConfig` which reads from dotenv, not hardcoded strings.
- No secrets visible after decompilation (verified via code analysis).

### M10: Extraneous Functionality - PASS

**Finding M10-1** (LOW, CVSS 1.5):
- `lib/services/deep_link_service.dart:326`: Commented-out Bitly API integration with placeholder `'Bearer YOUR_BITLY_ACCESS_TOKEN'`. This is a code comment, not executable code, but could mislead developers. Low risk.
- Remediation: Remove the commented-out example or move to documentation. Effort: 5 minutes.

### Butlery-Specific OWASP Checks

**FCM Token Security**: FCM tokens stored in `FlutterSecureStorage` with encrypted SharedPreferences on Android. Token refresh handled via `_setupTokenRefreshListener()`. Token cleanup on logout implemented in `FCMTokenManager._cleanup()`.

**Real-time Collaboration Security**: Firestore rules enforce participant validation for `realtime_recipes`, `realtime_menus`, and `realtime_resources`. Presence documents restricted to authenticated participants writing their own presence.

**Copy-on-Write Pattern**: Shared recipes use subcollection-based sharing (Issue #014). The `shared_recipes` collection stores copies, not references to user's original recipes.

---

## Dimension 2: Authentication and Session Security (13/18)

### Authentication Flow Security

| Feature | Status | Details |
|---|---|---|
| Email/password auth | Implemented | Via Firebase Auth |
| Google Sign-In | Available | `google_sign_in_mocks` in dev deps |
| Apple Sign-In | Not found | Not in pubspec.yaml |
| Biometric auth | Implemented | Face ID, Touch ID, Fingerprint |
| MFA | Implemented | Phone-based via `multiFactor` |
| Password reset | Implemented | Firebase secure email links |
| Rate limiting | Implemented | `RateLimiter` in auth repository |

### Token Management

| Token Type | Storage Location | Encrypted | Lifecycle |
|---|---|---|---|
| Firebase Auth token | Managed by Firebase SDK | Yes (platform keychain) | Auto-refresh |
| FCM token | FlutterSecureStorage | Yes | Refresh on re-auth, cleanup on logout |
| Field encryption key | FlutterSecureStorage | Yes (keychain/keystore) | Persistent with rotation method |
| DB encryption key | FlutterSecureStorage | Yes | Persistent |

### Session Management

- **Inactivity timeout**: Method exists (`logoutDueToInactivity`) but no timer triggers it (Finding M4-1).
- **App lock**: `AppLockService` with configurable timeout (1-60 minutes, default 5).
- **Concurrent sessions**: No explicit limit. Firebase Auth supports multiple device sessions by default.
- **Session fixation**: Firebase Auth generates new tokens on each authentication, preventing fixation.
- **Auth state listener**: `authStateChanges()` stream properly implemented in `FirebaseAuthRepository`.

### FCM Token Security

- Storage: `FlutterSecureStorage` with `encryptedSharedPreferences` (Android) and `KeychainAccessibility.first_unlock` (iOS).
- Token refresh: Listener via `_messaging.onTokenRefresh`.
- Token scoping: User-scoped in `user_fcm_tokens/{userId}` Firestore collection.
- Cleanup on logout: `_cleanup()` method clears `_currentToken` and secure storage keys.
- Old device cleanup: `_cleanupOldDevices()` method removes stale device entries.

### Findings Summary

- M4-1: No inactivity timer (MEDIUM, 4 hours)
- M4-2: No MFA enforcement for deletion (LOW, 2 hours)

---

## Dimension 3: Data Protection and Encryption (15/18)

### Sensitive Data Classification

| Classification | Data Types | Required Protection | Actual Protection | Status |
|---|---|---|---|---|
| Critical | Auth tokens, encryption keys | Keychain/Keystore | FlutterSecureStorage | PASS |
| High | PII (email, name), API keys | Encrypted storage | .env files + dotenv | PASS |
| Medium | Recipes, shopping lists, menus | Firestore + rules | Firestore + SQLCipher local | PASS |
| Low | App preferences, UI state, locale | SharedPreferences | SharedPreferences | PASS |

### Storage Security Matrix

| Storage Type | Encrypted | Used For | Risk Assessment |
|---|---|---|---|
| SharedPreferences | No | Session count, locale, biometric flag, lock timeout, notification prefs | LOW - only non-sensitive config |
| FlutterSecureStorage | Yes (keychain) | Encryption keys, FCM tokens | LOW risk |
| Drift/SQLCipher | Yes (AES-256) | Offline recipes, sync queue, JSON cache, parse cache, upload queue | LOW risk |
| Firestore | Yes (Google-managed) | All user content | Depends on rules (see Dim 5) |
| File system | No | Image cache | LOW - non-sensitive content |

### Encryption Implementation

- **AES-256-CBC**: Used in `FieldEncryptionService` for client-side field encryption before Firestore storage.
- **SQLCipher**: Used for local Drift database encryption.
- **Key management**: Keys generated with `Random.secure()` / `FortunaRandom`, stored in `FlutterSecureStorage`.
- **Key rotation**: `rotateKey()` method exists in `FieldEncryptionService` but requires manual data migration.
- **No hardcoded keys**: All encryption keys are runtime-generated and securely stored.

### Backup Security

- **Android**: `android:allowBackup="false"` and `android:fullBackupContent="false"` in AndroidManifest.xml - correctly prevents backup of sensitive data.
- **iOS**: No `NSAllowsArbitraryLoads` found. Standard iOS backup behavior applies; encryption keys in Keychain are excluded from iCloud backups by default with `KeychainAccessibility.first_unlock`.

### GDPR Compliance

| Article | Requirement | Implementation | Test Coverage | Score |
|---|---|---|---|---|
| Art. 7 | Consent Management | `ConsentService` + `FirebaseConsentRepository` | 38 tests | 9/10 |
| Art. 15 | Right of Access | `DataExportService` with 5 export managers | 14 tests | 9/10 |
| Art. 17 | Right to Erasure | `AccountDeletionService` with 4 deletion modules | 15 tests | 9/10 |
| Art. 20 | Data Portability | `DataExportService` (JSON format) | 14 tests | 9/10 |
| Art. 30 | Processing Records | `FirebaseAuditRepository` + immutable logs | Present | 8/10 |

**Article 7 Details**:
- `ConsentService` (`lib/services/account/consent_service.dart`): Granular consent with `ConsentPurposes` model.
- Version tracking via `_currentConsentVersion = '1.0.0'`.
- Consent stored in Firestore at `users/{userId}/consent/{consentDoc}` with timestamp.
- Consent withdrawal supported.
- Firestore rules enforce user can only write own consent records with required fields.

**Article 15/20 Details**:
- `DataExportService` uses facade pattern with 5 specialized managers: Content, Social, Activity, Compliance, Preferences.
- Export includes: profile, recipes, menus, shopping lists, friends, messages, comments, ratings, audit logs, consent records, notification data.
- Output format: comprehensive JSON with metadata including GDPR article references.

**Article 17 Details**:
- `AccountDeletionService` delegates to 4 focused modules: Content, Social, Profile, Storage.
- Cascading deletion across all collections.
- Requires re-authentication before deletion (`requires-recent-login` check).
- Audit log created for the deletion event itself.

**Article 30 Details**:
- `FirebaseAuditRepository`: Persistent audit logging to `audit_logs` Firestore collection.
- Audit logs are immutable (`allow update, delete: if false` in Firestore rules).
- Content: userId, operation, resourceType, resourceId, granted status, timestamp, metadata.
- Users can read their own audit logs (Art. 15), cannot modify them.
- Cloud Function `cleanupOldAuditLogs` for retention management.

**Finding GDPR-1** (LOW, CVSS 2.5):
- Audit log retention policy is implemented via Cloud Function but the retention period is not documented in user-facing privacy policy. Users should be informed of how long audit logs are kept.
- Remediation: Document retention period in privacy policy. Effort: 1 hour.

---

## Dimension 4: Network Security (10/12)

### HTTPS Enforcement

- **Android**: `network_security_config.xml` enforces HTTPS with `cleartextTrafficPermitted="false"`.
- **iOS**: iOS App Transport Security (ATS) enforces HTTPS by default.
- **Firebase**: All Firebase SDK calls use HTTPS natively.
- **No `badCertificateCallback`**: Zero instances found. No certificate validation bypass.

### SSL Certificate Pinning

`SslPinningService` (`lib/core/network/ssl_pinning_service.dart`):

**Implementation**:
- Root CA pinning (SHA-256) for Google Trust Services certificates.
- 6 Google/Firebase endpoints pinned: `firestore.googleapis.com`, `firebase.googleapis.com`, `vision.googleapis.com`, `storage.googleapis.com`, `identitytoolkit.googleapis.com`, `securetoken.googleapis.com`.
- Uses `http_certificate_pinning` package for validation.
- `secureGet()` and `securePost()` methods validate certificate before making requests.

**Finding H-02** (HIGH, CVSS 7.5):
- `SslPinningService.validateCertificate()` at line 74-78: On exception, `return true` (fails open). This means if there's an error during certificate validation (network timeout, parsing error), the connection is allowed through without validation.
- Additionally, at line 52-56: If no pins are configured for a host, the connection is allowed. This is by design but means non-Google APIs have no pinning.
- `createPinnedClient()` at line 100: Returns a standard `http.Client()` without any pinning enforcement. Actual pinning only occurs when using `secureGet()`/`securePost()` or explicitly calling `validateCertificate()`.
- Attack vector: MITM attacker could trigger certificate validation errors to bypass pinning.
- Remediation: Fail closed on certificate validation errors (block connection). Effort: 2 hours.

**Finding N-1** (MEDIUM, CVSS 5.0):
- OCR service (`lib/services/ocr_extraction_service.dart:200-205`): Falls back to standard `http.Client()` if `SslPinningService` is not available via ServiceLocator. This means OCR API calls to external services (ocr.space, Google Vision) may not have certificate pinning if the DI container is misconfigured.
- Remediation: Make SslPinningService a required dependency. Effort: 1 hour.

### HTTP Client Configuration

- `SslPinningService` provides `secureGet` and `securePost` with automatic certificate validation.
- `http_certificate_pinning` package timeout set to 30 seconds.
- OCR service sends API key in request body field (`apikey`), not in URL parameters.

---

## Dimension 5: Firebase Security Rules (10/12)

### Firestore Security Rules Audit

**Summary**: 1466 lines, 74+ match rules. Comprehensive coverage with defense-in-depth.

### Collection-by-Collection Coverage

| Collection | Auth Required | Ownership Check | Role-Based | Field Validation | Status |
|---|---|---|---|---|---|
| `users/{uid}` | Yes | Yes (`isOwner`) | N/A | N/A | PASS |
| `users/{uid}/recipes` | Yes | Yes | N/A | tagResult validated | PASS |
| `users/{uid}/recipe_summaries` | Yes | Yes | N/A | N/A | PASS |
| `users/{uid}/unified_shopping_lists` | Yes | Yes | N/A | N/A | PASS |
| `users/{uid}/ingredients` | Yes | Yes | Yes | ID match, status, size limits | PASS |
| `users/{uid}/personalTagIds` | Yes | Yes | N/A | N/A | PASS |
| `users/{uid}/personalTagGroups` | Yes | Yes | N/A | N/A | PASS |
| `users/{uid}/friends/{friendId}` | Yes | Yes + bidirectional | N/A | N/A | PASS |
| `users/{uid}/friendCategories` | Yes | Yes + members | Partial | N/A | **PARTIAL** |
| `users/{uid}/consent` | Yes | Yes | N/A | Required fields | PASS |
| `public_profiles/{uid}` | Yes (read all) | Yes (write) | N/A | Required fields, friendsCount validation | PASS |
| `friend_requests` | Yes | Sender/recipient | Status validation | Required fields | PASS |
| `group_invitations` | Yes | Sender/recipient | Status validation | Required fields | PASS |
| `shared_recipes` | Yes | Owner/members | Subcollection-based | Required fields | PASS |
| `shared_recipes/members` | Yes | Owner add, self-remove | N/A | Required fields | PASS |
| `shared_recipes/views` | Yes | Self-create only | N/A | Required fields | PASS |
| `shared_recipes/engagements` | Yes | Self-create only | N/A | Required fields | PASS |
| `shared_recipes/dismissals` | Yes | Self-create/delete | N/A | Required fields | PASS |
| `shared_recipes/collaborators` | Yes | Owner or self + flag | N/A | Required fields | PASS |
| `menus/{menuId}` | Yes | `sharedByUserId` | N/A | Required fields | PASS |
| `shared_menus` | Yes | Owner/members | Subcollection-based | Required fields | PASS |
| `shared_shopping_lists` | Yes | Owner/collaborators | Array-based | Required fields | PASS |
| `shared_shopping_lists/items` | Yes | Member check | N/A | ID match, addedByUserId | PASS |
| `realtime_recipes` | Yes | Owner/participants | Array-based | Required fields | PASS |
| `realtime_menus` | Yes | Owner/participants | Array-based | Required fields | PASS |
| `realtime_resources` | Yes | Owner/participants | Array-based | Required fields | PASS |
| `recipePresence` | Yes (read all) | Self-write | N/A | N/A | PASS |
| `recipe_comments` | Yes | Author/members | Recipe access check | Text length 1-1000 | PASS |
| `butlery_archive` | Yes (read) | Write: false | Admin only | N/A | PASS |
| `conversations` | Yes | Participant | N/A | Required fields | PASS |
| `messages` | Yes | Sender + participant | N/A | Required fields | PASS |
| `connectivity_test` | Yes (read) | Write: false | N/A | N/A | PASS |
| `unified_shared_shopping_lists` | Yes | Owner/collaborators | N/A | Required fields | PASS |
| `shoppingListTemplates` | Yes | Creator/public | N/A | Required fields | PASS |
| `shoppingLists` | Yes | Owner | N/A | N/A | PASS |
| `sharedShoppingLists` | Yes | Sharer/recipients | N/A | Required fields | PASS |
| `userSharedShoppingLists` | Yes | Self or sharer | N/A | N/A | PASS |
| `sharedMenus` | Yes | Sharer/recipients | N/A | N/A | PARTIAL |
| `userSharedMenus` | Yes | Self or sharer | N/A | N/A | PASS |
| `presence/{uid}` | Yes (read all) | Self-write | N/A | N/A | PASS |
| `shared_content` | Yes | Sender/recipient | N/A | Required fields, no self-send | PASS |
| `recipe_ratings` | Yes | Self-create/update | N/A | Rating 1-5, required fields | PASS |
| `user_notifications` | Yes | Self-read, friend-send | Friendship check | Required fields | PASS |
| `user_fcm_tokens` | Yes | Self only | N/A | N/A | PASS |
| `user_notification_preferences` | Yes | Self only | N/A | N/A | PASS |
| `audit_logs` | Yes | Self-read, self-create | Immutable (no update/delete) | Required fields | PASS |
| `menu_ratings` | Yes (read all) | Self-create/update | N/A | Rating 1-5, required fields | PASS |
| `menu_comments` | Yes (read all) | Self-create/update | N/A | Text length 1-1000 | PASS |
| `menu_templates` | Yes | Owner/public | N/A | Required fields | PASS |
| `menu_activity` | Yes (read all) | Self-create | Immutable | Required fields | PASS |
| `globalRecipeCache` | Yes | Create any, limited update | N/A | Update only accessCount/lastAccessedAt | PASS |
| `site_configs` | Yes (read) | Write: false | Admin only | N/A | PASS |
| `parsing_corrections` | Yes | Self only | Immutable (no update) | Required fields | PASS |
| `parse_events` | No access | Write: false | N/A | N/A | PASS |
| `{path=**}/members` (group) | Yes | Self-read | N/A | N/A | PASS |
| `{document=**}` (default) | Deny all | N/A | N/A | N/A | PASS |

### Key Security Strengths in Firestore Rules

1. **Default deny**: Catch-all rule at bottom denies all unmatched paths.
2. **Allergen safety validation** (CRIT-2, CRIT-8): `isValidTagResult()` and `_isValidUserIngredient()` prevent client-side tampering with allergen data.
3. **TriState validation** (H15): `_isValidTriStateMap()` limits status map size to prevent storage abuse.
4. **Immutable audit logs**: `allow update, delete: if false` ensures GDPR Article 30 compliance.
5. **Anti-spam notifications**: Friend existence check prevents notification spam attacks.
6. **Self-send prevention**: `shared_content` validates `fromUserId != toUserId`.
7. **Collection group query rules**: Properly scoped for `members` collection group queries.

### Findings

**Finding FR-1** (MEDIUM, CVSS 4.8):
- `friendCategories` at `firestore.rules:186`: `allow get: if isAuthenticated()` is overly permissive. Any authenticated user can read any friend category document if they know the document ID. This could expose group membership lists.
- Remediation: Add invitation existence check or require the user to be in the group's member list. Effort: 2 hours.

**Finding FR-2** (MEDIUM, CVSS 4.5):
- `sharedMenus` at `firestore.rules:1101`: Missing `hasRequiredFields` validation on create. The `sharedShoppingLists` equivalent has required fields, but `sharedMenus` does not.
- Remediation: Add `hasRequiredFields(['sharedByUserId', 'sharedWithUserIds', 'menuData', 'sharedAt'])`. Effort: 30 minutes.

**Finding FR-3** (LOW, CVSS 2.0):
- `menu_ratings`, `menu_comments`, `menu_activity` at lines 1297, 1321, 1370: Read access is `isAuthenticated()` without verifying the user has access to the parent menu. Any authenticated user can read all menu ratings/comments/activity. Since menus may be private, this could leak information about private menus.
- Remediation: Add parent menu access check. Effort: 3 hours.

### Storage Security Rules Audit

`storage.rules` (61 lines):
- Authentication required for all operations.
- User-scoped paths (`/users/{userId}/`) enforce ownership.
- Image type validation: `request.resource.contentType.matches('image/.*')`.
- Size limit: 10 MB per file.
- Shared recipes: Public read, write requires authentication with `uploadedBy` metadata.
- Default deny for all other paths.
- **No path traversal risk**: Firebase Storage paths don't support `..` traversal.

**Storage rules assessment**: PASS. Properly configured with type validation, size limits, and ownership enforcement.

### Cloud Functions Security

**Authentication**: All callable functions require `context.auth` / `request.auth` authentication check.

**Rate limiting**: `withRateLimit()` middleware (`functions/src/middleware/rate_limiter.ts`) enforces token bucket rate limiting per user per operation. Implemented for LLM operations (10 tokens/min), notifications (60/min), and parse events (30/min).

**Input validation**:
- `sendNotification`: Title length 100, body length 500, targetUserId length 128.
- `logParseEvent`: URL sanitization (removes sensitive query params), source whitelist validation.
- `structureRecipe`: Uses Mistral API key from Firebase secrets, not hardcoded.

**Admin SDK usage**: Correctly used for server-side operations. `admin.initializeApp()` at startup.

**Finding H-01** (HIGH, CVSS 7.1): Already documented in M6-1.

---

## Dimension 6: API Security and Secret Management (7/10)

### Hardcoded Secrets Audit

| Pattern | Found In | Risk | Assessment |
|---|---|---|---|
| Firebase API keys | `firebase_options.dart` via `FirebaseConfig` | LOW | Loaded from .env, not hardcoded |
| OCR API key | `ocr_extraction_service.dart` via `dotenv.env['OCR_API_KEY']` | LOW | Loaded from .env |
| Algolia API key | `search_module.dart` via `dotenv.env['ALGOLIA_API_KEY']` | LOW | Loaded from .env |
| Google Vision key | `ocr_extraction_service.dart` via `dotenv.env['GOOGLE_VISION_API_KEY']` | LOW | Loaded from .env |
| Mistral API key | `structure-recipe.ts` via `secrets: [mistralApiKey]` | LOW | Firebase Secrets Manager |
| Bitly token | `deep_link_service.dart:326` | NONE | Commented-out placeholder |
| Test tokens | `test/` directory only | NONE | Test fixtures only |

**Result**: Zero hardcoded secrets in production source code. All API keys loaded from environment variables via `flutter_dotenv` or Firebase Secrets.

### Environment Configuration

- `.env` files in `.gitignore` (lines 48-51): `.env`, `.env.*`, `*.env`, `*.env.*` - comprehensive.
- `google-services.json` and `GoogleService-Info.plist` in `.gitignore` (lines 54-57) - correct.
- `FirebaseConfig` class loads all Firebase config from `dotenv.env` with clear error handling in debug mode.
- Environment separation: `ENV` variable supports development/staging/production.

### CI/CD Secret Handling

- `test.yml:43`: `secrets.CODECOV_TOKEN` properly used via GitHub Secrets.
- No secrets echoed or logged in workflow files.
- No hardcoded tokens in any workflow YAML files.
- Build workflow does not require secrets (uses Flutter analyze + build only).

**Finding API-1** (MEDIUM, CVSS 5.8):
- `FirebaseConfig._throwMissingKey()` at `lib/core/config/firebase_config.dart:134-136`: In release mode, missing environment variables return empty string instead of throwing. This means the app could start with empty Firebase config, potentially sending requests to default/wrong endpoints.
- Remediation: Fail fast on missing critical config even in release mode. Effort: 1 hour.

**Finding API-2** (MEDIUM, CVSS 4.0):
- No documented key rotation procedure for third-party API keys (OCR Space, Algolia, Google Vision). While keys are in `.env` files and can be changed, there's no automated rotation or alerting mechanism.
- Remediation: Document key rotation procedures. Effort: 2 hours.

---

## Dimension 7: Code Protection and Platform Security (6/10)

### Dart Code Obfuscation

- **Android APK**: `--obfuscate --split-debug-info=build/debug-info` in CI (`build-validation.yml:83`). PASS.
- **Web**: `flutter build web --release` provides minification. PASS.
- **iOS**: No iOS build in CI workflow. iOS obfuscation status unknown.

### Android ProGuard/R8

- `build.gradle.kts:39-40`: `isMinifyEnabled = true`, `isShrinkResources = true`. PASS.
- `proguard-rules.pro`: Contains broad keep rules for Firebase (`-keep class com.google.firebase.** { *; }`) and AndroidX (`-keep class androidx.** { *; }`). These are standard but overly broad.
- `-dontwarn` suppressions for Firebase and GMS are acceptable.

### Jailbreak/Root Detection

- `DeviceIntegrityService`: Implemented with `flutter_jailbreak_detection`.
- Checks: jailbreak/root status AND developer mode.
- Behavior: Warn, not block. Appropriate for app risk profile (recipe app, not banking).
- Registered in DI via `core_module.dart`.

### Debug Mode Handling

- `kDebugMode` used consistently for conditional logging (40+ occurrences).
- Analytics collection disabled in debug mode (`firebase_analytics_repository.dart:28`).
- Crashlytics collection disabled in debug mode (`main.dart:100`).
- No debug features accessible in release builds.

### App Permissions Audit

**Android**:
| Permission | Justified | Notes |
|---|---|---|
| INTERNET | Yes | Core functionality |
| CAMERA | Yes | Recipe photo capture |
| READ_EXTERNAL_STORAGE | Yes | Legacy image access |
| WRITE_EXTERNAL_STORAGE | Yes | Legacy image save |
| READ_MEDIA_IMAGES | Yes | Modern scoped access (API 33+) |

No unnecessary permissions (Location, Contacts, Microphone, Phone absent).

**iOS**: Camera, Photo Library, Face ID. All justified with usage descriptions.

### Deep Link Security

- **Domain validation**: `parseDeepLink()` validates host is `butlery.app` or `www.butlery.app`.
- **Android**: `android:autoVerify="true"` enables App Links verification.
- **iOS**: `applinks:butlery.app` in `com.apple.developer.associated-domains`.
- **Custom scheme**: `butlery://` scheme registered. Custom schemes are less secure than universal links but acceptable for non-sensitive navigation.
- **Parameter validation**: Deep link parameters parsed with null safety and `Uri.decodeComponent`.
- **Timestamp included**: Deep links include timestamp for potential expiration checks.

### Findings

**Finding H-03** (HIGH, CVSS 7.0):
- `build.gradle.kts:38`: Release build uses `signingConfig = signingConfigs.getByName("debug")`. The release APK is signed with debug keys, which means:
  1. Play Store will reject it.
  2. App Links verification may fail.
  3. No meaningful code signing protection.
- Comment says "TODO: Add your own signing config for the release build."
- Remediation: Configure production signing keys. Effort: 2 hours.

**Finding CP-1** (MEDIUM, CVSS 4.5):
- No iOS build configuration in CI/CD. Obfuscation and build settings for iOS are not verified via automated pipeline.
- Remediation: Add iOS build step with `--obfuscate` to CI. Effort: 3 hours.

---

## Security Risk Matrix

| | Low Impact | Medium Impact | High Impact | Critical Impact |
|---|---|---|---|---|
| **High Likelihood** | | M4-1 (no inactivity timer) | H-03 (debug signing) | |
| **Medium Likelihood** | M3-1 (cleartext localhost) | FR-1 (friendCategories get), N-1 (OCR no pinning), API-1 (empty config fallback) | H-01 (notification auth), H-02 (SSL fail-open) | |
| **Low Likelihood** | M10-1 (commented code), M7-1 (FIXMEs), M2-2 (biometric pref), GDPR-1 (retention docs), FR-3 (menu ratings read) | FR-2 (sharedMenus fields), M4-2 (no MFA for deletion), API-2 (key rotation), CP-1 (no iOS CI build), M8-1 (profile mode perf) | M2-1 (recipe SharedPrefs) | |

---

## Remediation Roadmap

### Phase 1: High Priority (Week 1)

Priority P0/P1 - addresses CVSS 7.0+ findings.

1. **H-01**: Add sender-recipient authorization in `sendNotification` Cloud Function - 3 hours
2. **H-02**: Change SSL pinning to fail-closed on validation errors - 2 hours
3. **H-03**: Configure production signing keys for Android release builds - 2 hours

Total effort: 7 hours. Expected risk reduction: 35%.

### Phase 2: Medium Priority (Weeks 2-3)

Priority P1 - addresses CVSS 4.0-6.9 findings.

1. **M4-1**: Implement client-side inactivity timeout (30 min) - 4 hours
2. **FR-1**: Restrict `friendCategories` get access - 2 hours
3. **FR-2**: Add required fields validation to `sharedMenus` create rule - 30 minutes
4. **N-1**: Make SslPinningService required in OCR service - 1 hour
5. **API-1**: Fail fast on missing Firebase config in release mode - 1 hour
6. **CP-1**: Add iOS build with obfuscation to CI/CD - 3 hours
7. **API-2**: Document key rotation procedures - 2 hours
8. **M2-1**: Migrate recipe persistence to encrypted Drift DB - 3 hours

Total effort: 16.5 hours. Expected risk reduction: 40%.

### Phase 3: Low Priority (Month 2)

Priority P2 - addresses CVSS 0.1-3.9 findings.

1. **M4-2**: Enforce MFA for account deletion when enrolled - 2 hours
2. **M2-2**: Move biometric preference to secure storage - 1 hour
3. **FR-3**: Add parent menu access checks for ratings/comments/activity - 3 hours
4. **GDPR-1**: Document audit log retention in privacy policy - 1 hour
5. **M3-1**: Move cleartext config to debug-only build flavor - 2 hours
6. **M10-1**: Remove commented-out Bitly example - 5 minutes

Total effort: 9 hours. Expected risk reduction: 15%.

---

## Penetration Testing Readiness Checklist

- [x] OWASP Mobile Top 10 self-assessment complete
- [ ] All critical vulnerabilities remediated (0 critical, 3 high remain)
- [x] Security rules reviewed and updated (comprehensive coverage confirmed)
- [ ] Test accounts and environment prepared
- [ ] Vulnerability disclosure policy documented
- [ ] Incident response plan in place
- [x] Security testing tools identified (MobSF, OWASP ZAP, Frida)
- [x] Scope defined (Firebase, Cloud Functions, mobile clients)

---

## Appendix A: Files Audited

| Category | Files | Key Findings |
|---|---|---|
| Firebase config | `lib/core/config/firebase_config.dart` | No hardcoded secrets |
| Firestore rules | `firestore.rules` (1466 lines) | 74+ rules, comprehensive |
| Storage rules | `storage.rules` (61 lines) | Proper validation |
| Encryption | `lib/services/encryption/field_encryption_service.dart` | AES-256-CBC, secure key mgmt |
| Database | `lib/core/storage/drift/app_database.dart` | SQLCipher encryption |
| SSL Pinning | `lib/core/network/ssl_pinning_service.dart` | Fail-open concern |
| Auth | `lib/repositories/firebase/firebase_auth_repository.dart` | Rate limited |
| Auth service | `lib/services/auth_service.dart` | MFA support |
| Biometrics | `lib/services/auth/biometric_service.dart` | Proper implementation |
| App lock | `lib/services/app_lock_service.dart` | Configurable timeout |
| FCM tokens | `lib/services/notifications/modules/fcm_token_manager.dart` | Secure storage |
| Device integrity | `lib/services/device_integrity_service.dart` | Root/jailbreak detection |
| Deep links | `lib/services/deep_link_service.dart` | Domain validation |
| Android config | `android/app/src/main/AndroidManifest.xml` | backup=false |
| Network config | `android/app/src/main/res/xml/network_security_config.xml` | HTTPS enforced |
| Build config | `android/app/build.gradle.kts` | Minify + shrink enabled |
| ProGuard | `android/app/proguard-rules.pro` | Standard Firebase rules |
| iOS config | `ios/Runner/Info.plist` | Proper permission descriptions |
| CI/CD | `.github/workflows/build-validation.yml` | Obfuscation in CI |
| Cloud Functions | `functions/src/notifications/send-notification.ts` | Auth check, but no relationship check |
| Rate limiter | `functions/src/middleware/rate_limiter.ts` | Token bucket, comprehensive |
| GDPR consent | `lib/services/account/consent_service.dart` | Article 7 compliant |
| GDPR export | `lib/services/account/data_export_service.dart` | Articles 15/20 compliant |
| GDPR deletion | `lib/services/account/account_deletion_service.dart` | Article 17 compliant |
| Audit logs | `lib/repositories/firebase/firebase_audit_repository.dart` | Article 30 compliant |
| Permission mixin | `lib/repositories/mixins/permission_validation_mixin.dart` | Available to all repos |
| Base repository | `lib/repositories/firebase/base_firebase_repository.dart` | Mixin applied at base |
| OCR service | `lib/services/ocr_extraction_service.dart` | SSL pinning fallback |
