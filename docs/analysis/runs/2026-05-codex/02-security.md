### 1. Executive Summary

```text
BUTLERY SECURITY AND COMPLIANCE ANALYSIS - PHASE 1
====================================================
Analysis Date: 2026-05-03
Analyst: Codex (GPT-5)
Framework: OWASP Mobile Application Security Top 10 (2024)

OVERALL SECURITY SCORE: 61/100

+-- OWASP Mobile Top 10:                12/20 points
+-- Authentication & Session:           13/18 points
+-- Data Protection & Encryption:       13/18 points
+-- Network Security:                   7/12 points
+-- Firebase Security Rules:            5/12 points
+-- API Security & Secret Management:   6/10 points
+-- Code Protection & Platform:         5/10 points

SECURITY POSTURE: Needs Improvement

VULNERABILITY SUMMARY:
- CRITICAL (CVSS 9.0-10.0): 1 vulnerabilities
- HIGH (CVSS 7.0-8.9): 3 vulnerabilities
- MEDIUM (CVSS 4.0-6.9): 5 vulnerabilities
- LOW (CVSS 0.1-3.9): 2 vulnerabilities

TOP 5 SECURITY RISKS:
1. Forged friendships are possible by direct client writes to `/users/{userId}/friends/{friendId}`, enabling unauthorized social-graph manipulation and downstream notification abuse (`firestore.rules:282-285`, `functions/src/notifications/send-notification.ts:114-119`, `functions/src/notifications/send-notification.ts:530-533`).
2. Non-owner group members can rewrite full `friendUserIds` arrays in friend categories, not just self-add, which enables unauthorized membership edits (`firestore.rules:311-317`, `lib/repositories/firebase/friends/friend_category_repository.dart:109-116`, `lib/repositories/firebase/friends/friend_category_repository.dart:229-237`).
3. Certificate pinning is wired but effectively inactive because host pin lists are TODO/empty and requests fall back to trust store (`lib/services/security/cert_pin_config.dart:30-40`, `lib/services/security/cert_pin_config.dart:46-53`, `lib/services/security/pinned_http_client.dart:87-93`, `lib/repositories/algolia/algolia_pinning_interceptor.dart:79-82`).
4. Most callable Cloud Functions do not enforce App Check even though selective functions already do, leaving anti-abuse coverage inconsistent (`functions/src/index.ts:20`, `functions/src/notifications/send-notification.ts:74-76`, `functions/src/notifications/send-notification.ts:469-472`, `functions/src/events/log-parse-event.ts:144-146`, `functions/src/llm/structure-recipe.ts:64-71`, `functions/src/llm/ocr-recipe-image.ts:88-95`).
5. Rich user content is stored unencrypted in SharedPreferences (recipes/menu/drafts), increasing local data exposure risk (`lib/services/persistence_service.dart:64-69`, `lib/services/persistence_service.dart:110-129`, `lib/services/persistence_service.dart:202-207`, `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:274-281`, `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:340-347`).
```

Deferred by cross-prompt boundary:
- Dependency CVEs/supply-chain findings are owned by prompt 05 and are intentionally not scored here (`docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md:8-9`).
- Test infrastructure hang is recorded from pre-analysis and should be handled in prompt 03 (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529`).

### 2. OWASP Mobile Top 10 Scorecard

| OWASP Category | Status | Findings | Severity | Remediation Effort |
|----------------|--------|----------|----------|-------------------|
| M1: Improper Platform Usage | Partial | Broad external storage permissions remain on Android legacy paths (`android/app/src/main/AndroidManifest.xml:8-10`), while security hardening exists (`android/app/src/main/AndroidManifest.xml:22-24`). | M | 8 hours |
| M2: Insecure Data Storage | Partial | SharedPreferences stores recipe/menu/draft JSON (`lib/services/persistence_service.dart:125-129`, `lib/services/persistence_service.dart:205-207`, `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:279-281`) even though SQLCipher + secure key path exists (`lib/core/storage/drift/app_database.dart:121-127`, `lib/core/storage/drift/app_database.dart:141-153`). | M | 20 hours |
| M3: Insecure Communication | Fail | Pinning is no-op until fingerprints are populated (`lib/services/security/cert_pin_config.dart:39-40`, `lib/services/ocr_extraction_service.dart:217-219`) and HTTP import still accepts `http` scheme (`lib/services/import/fetchers/http_content_fetcher.dart:16`, `lib/services/import/fetchers/http_content_fetcher.dart:90-93`). | H | 24 hours |
| M4: Insecure Authentication | Partial | Auth stream handling and token refresh are present (`lib/services/auth_service.dart:52-65`, `lib/services/auth_service.dart:229-241`), but callable anti-abuse attestation is inconsistent (missing App Check on multiple callables) (`functions/src/notifications/send-notification.ts:74-76`, `functions/src/events/log-parse-event.ts:144-146`). | H | 16 hours |
| M5: Insufficient Cryptography | Partial | SQLCipher encryption with secure key storage is implemented (`lib/core/storage/drift/app_database.dart:129-159`, `lib/core/storage/drift/app_database.dart:166-172`), but sensitive-like data remains in plaintext preferences (`lib/services/persistence_service.dart:125-129`). | M | 12 hours |
| M6: Insecure Authorization | Fail | Overly permissive `friends` and `friend_categories` rules allow unauthorized relationship/membership state changes (`firestore.rules:282-285`, `firestore.rules:311-317`). | C | 32 hours |
| M7: Client Code Quality | Partial | Pre-analysis static analysis reports unresolved symbol in notification consent path (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`). | L | 2 hours |
| M8: Code Tampering | Partial | freeRASP integrity checks are wired (`lib/services/device_integrity_service.dart:89-99`, `lib/core/bootstrap/stages/core_stage.dart:48-57`) but app behavior is warn-only on compromise (`lib/core/bootstrap/stages/core_stage.dart:53-57`). | M | 12 hours |
| M9: Reverse Engineering | Partial | Android release minify/shrink is enabled (`android/app/build.gradle.kts:70-75`) but iOS release CI omits Dart obfuscation flags (`.github/workflows/build-validation.yml:225-229`) and project uses `COPY_PHASE_STRIP = NO` in release/profile configs (`ios/Runner.xcodeproj/project.pbxproj:341`, `ios/Runner.xcodeproj/project.pbxproj:519`). | M | 10 hours |
| M10: Extraneous Functionality | Partial | Notification callable still references `friend_requests` while rules and app constants use `social_requests`, indicating stale authorization path assumptions (`functions/src/notifications/send-notification.ts:125`, `firestore.rules:472`, `lib/core/constants/firestore_collections.dart:14`). | M | 6 hours |

### 3. Critical Vulnerability Report

#### C-1: Forged Friendship Graph via Firestore Rules
- CVSS: 9.1 (Critical)
- OWASP Category: M6 (Insecure Authorization)
- File:line location:
  - `firestore.rules:282-285`
  - `functions/src/notifications/send-notification.ts:114-119`
  - `functions/src/notifications/send-notification.ts:530-533`
  - `functions/src/notifications/send-notification.ts:125-133`
  - `firestore.rules:472-490`
- Attack vector/complexity:
  - Vector: Network
  - Complexity: Low
  - Privileges required: Low (authenticated user)
  - User interaction: None
- Description:
  - Any authenticated user can write friend docs under their own path and also under another user's friend path when `request.auth.uid == friendId`, enabling synthetic friendship state without accepted request enforcement in rules.
- Evidence:
```text
firestore.rules:282-285
match /friends/{friendId} {
  allow read: if isOwner(userId) || (isAuthenticated() && request.auth.uid == friendId);
  allow write: if isOwner(userId) || (isAuthenticated() && request.auth.uid == friendId);
}
```
```text
functions/src/notifications/send-notification.ts:114-119
if (callerUid !== targetUserId) {
  const friendDoc = await admin.firestore()
    .collection('users').doc(callerUid)
    .collection('friends').doc(targetUserId)
    .get();
```
- Proof of concept steps:
  1. Authenticate as attacker A.
  2. Write `/users/A/friends/V` (allowed by owner branch) (`firestore.rules:284`).
  3. Write `/users/V/friends/A` (allowed by `request.auth.uid == friendId` branch) (`firestore.rules:284`).
  4. Invoke `sendNotification` targeting victim V; friendship check resolves via attacker-owned friend doc (`functions/src/notifications/send-notification.ts:114-119`).
- Remediation (code example):
```text
// Phase-1 containment in firestore.rules:
match /friends/{friendId} {
  allow read: if isOwner(userId);
  allow write: if false; // move friend edge creation to trusted server callable
}
```
```text
// Server-side callable should validate accepted social request before write.
// Use social_requests (not friend_requests) as authority.
```
- Effort estimate: 16-24 hours (rules + callable migration + tests).

#### H-1: Friend Category Membership Rewrite by Non-Owners
- CVSS: 8.2 (High)
- OWASP Category: M6 (Insecure Authorization)
- File:line location:
  - `firestore.rules:311-317`
  - `lib/repositories/firebase/friends/friend_category_repository.dart:109-116`
  - `lib/repositories/firebase/friends/friend_category_repository.dart:229-237`
- Attack vector/complexity:
  - Vector: Network
  - Complexity: Low
  - Privileges required: Low (existing member)
  - User interaction: None
- Description:
  - Non-owner members can update `friendUserIds` as a full array diff, allowing unauthorized add/remove of other members.
  - Repository intent shows non-owner path is self-add only (`arrayUnion`), while owner path handles full membership updates.
- Evidence:
```text
firestore.rules:311-317
allow update: if isAuthenticated()
  && isInList('friendUserIds')
  && request.resource.data.diff(resource.data).affectedKeys()
    .hasOnly(['friendUserIds', 'updatedAt'])
```
```text
lib/.../friend_category_repository.dart:113-116
update({
  'friendUserIds': FieldValue.arrayUnion([currentUser]),
  'updatedAt': timestampProvider.serverTimestamp(),
});
```
- Proof of concept steps:
  1. Authenticate as existing member M of category C.
  2. Submit update with `friendUserIds` replacing array members (add arbitrary UID or remove others).
  3. Rule accepts as long as only `friendUserIds`/`updatedAt` changed.
- Remediation (code example):
```text
// Restrict member updates to self-add only:
allow update: if isAuthenticated()
  && request.auth.uid in resource.data.friendUserIds
  && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['friendUserIds', 'updatedAt'])
  && request.resource.data.friendUserIds.removeAll(resource.data.friendUserIds).hasOnly([request.auth.uid])
  && resource.data.friendUserIds.removeAll(request.resource.data.friendUserIds).size() == 0;
```
- Effort estimate: 8-12 hours (rules + emulator tests + app flow verification).

#### H-2: Certificate Pinning Wired but Inactive
- CVSS: 8.0 (High)
- OWASP Category: M3 (Insecure Communication)
- File:line location:
  - `lib/services/security/cert_pin_config.dart:30-40`
  - `lib/services/security/cert_pin_config.dart:46-53`
  - `lib/services/security/pinned_http_client.dart:87-93`
  - `lib/repositories/algolia/algolia_pinning_interceptor.dart:79-82`
  - `lib/services/ocr_extraction_service.dart:217-219`
- Attack vector/complexity:
  - Vector: Network
  - Complexity: Low to Medium (hostile Wi-Fi or compromised trust chain)
  - Privileges required: None
  - User interaction: User initiates network call
- Description:
  - Pinning wrappers are present, but configured host pin lists contain TODO placeholders only. Empty pin lists trigger trust-store fallback, so pin mismatch protection is not active for those hosts.
- Evidence:
```text
lib/services/security/cert_pin_config.dart:39-40
// TODO(BUT-427-ops): leaf cert SHA-256 fingerprint
// TODO(BUT-427-ops): backup cert SHA-256 fingerprint
```
```text
lib/services/security/pinned_http_client.dart:87-93
if (pins.isEmpty) {
  return _inner.send(request); // fall through
}
```
- Proof of concept steps:
  1. Route traffic through intercepting proxy with a locally trusted CA.
  2. Trigger OCR/import/Algolia requests to hosts whose pin list is empty.
  3. Requests succeed via trust store fallback rather than pin enforcement.
- Remediation (code example):
```text
static const Map<String, List<String>> hostPins = {
  'api.ocr.space': [
    'sha256/<primary-fingerprint>',
    'sha256/<backup-fingerprint>',
  ],
  'vision.googleapis.com': [
    'sha256/<primary-fingerprint>',
    'sha256/<backup-fingerprint>',
  ],
};
```
- Effort estimate: 12-16 hours (ops cert collection, rollout, monitoring).

#### H-3: Missing App Check Enforcement on High-Value Callables
- CVSS: 7.4 (High)
- OWASP Category: M4/M6 (Authentication and Authorization Hardening)
- File:line location:
  - `functions/src/index.ts:20`
  - `functions/src/notifications/send-notification.ts:74-76`
  - `functions/src/notifications/send-notification.ts:469-472`
  - `functions/src/events/log-parse-event.ts:144-146`
  - `functions/src/llm/structure-recipe.ts:64-71`
  - `functions/src/llm/ocr-recipe-image.ts:88-95`
- Attack vector/complexity:
  - Vector: Network
  - Complexity: Low
  - Privileges required: Low (authenticated account or abused session token)
  - User interaction: None
- Description:
  - App Check is selectively enabled (LLM callables), but multiple callables do not enforce it. This leaves inconsistent anti-automation/abuse controls across API surface.
- Evidence:
```text
functions/src/index.ts:20
setGlobalOptions({ region: "europe-west1" });
```
```text
functions/src/notifications/send-notification.ts:74
export const sendNotification = onCall(
```
```text
functions/src/llm/structure-recipe.ts:70
enforceAppCheck: true,
```
- Proof of concept steps:
  1. Authenticate with scripted client.
  2. Call non-App-Check callable endpoints directly (`sendNotification`, `sendNotificationBatch`, `logParseEvent`).
  3. Calls are accepted if auth/rate-limit checks pass, without attestation gate.
- Remediation (code example):
```text
export const sendNotification = onCall(
  {
    enforceAppCheck: true,
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => { ... }
);
```
- Effort estimate: 10-14 hours (callable updates + client rollout + monitoring).

### 4. Security Risk Matrix

| Vulnerability ID | Likelihood | Impact | Position |
|------------------|------------|--------|----------|
| C-1 Forged friendships | High | Critical | High x Critical |
| H-1 Friend category member rewrite | High | High | High x High |
| H-2 Pinning inactive | Medium | High | Medium x High |
| H-3 Missing App Check on callables | High | High | High x High |
| M-1 SharedPreferences stores rich content | Medium | Medium | Medium x Medium |
| M-2 iOS obfuscation/symbol hardening gap | Medium | Medium | Medium x Medium |
| M-3 Deep-links readable by all authenticated users | Medium | Medium | Medium x Medium |
| M-4 HTTP recipe import allowed | Medium | Medium | Medium x Medium |
| M-5 iOS bundle-id mismatch in Firebase options | Low | Medium | Low x Medium |
| L-1 Static analysis unresolved symbol (pre-analysis snapshot) | Low | Low | Low x Low |
| L-2 Test hang in infrastructure integration suite (deferred to Prompt 03) | Low | Low | Low x Low |

Evidence for medium/low matrix rows:
- SharedPreferences storage: `lib/services/persistence_service.dart:125-129`, `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:279-281`.
- iOS code protection gap: `.github/workflows/build-validation.yml:225-229`, `ios/Runner.xcodeproj/project.pbxproj:519`.
- Deep link broad reads: `firestore.rules:1680-1682`, `lib/repositories/firebase/firebase_deeplink_repository.dart:106-111`.
- HTTP import allowed: `lib/services/import/fetchers/http_content_fetcher.dart:16`, `lib/services/import/fetchers/http_content_fetcher.dart:90-93`.
- Bundle-id mismatch: `ios/Runner.xcodeproj/project.pbxproj:377`, `lib/firebase_options.dart:58`.
- Pre-analysis static error: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`.
- Pre-analysis hang: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31511-31518`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525-31529`.

### 5. GDPR Compliance Report

| Article | Requirement | Implementation | Test Coverage | Score |
|---------|------------|----------------|---------------|-------|
| Art. 7 | Consent Management | Granular consent purposes, versioning, renewal check, and revoke path are implemented (`lib/models/account/user_consent.dart:90-96`, `lib/models/account/user_consent.dart:102-108`, `lib/services/account/consent_service.dart:107-120`, `lib/services/account/consent_service.dart:150-156`, `firestore.rules:1376-1385`). | Prompt baseline says 38 tests (`docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md:248`); dedicated test suite present (`test/unit/services/account/consent_service_test.dart:1-3`). | 8/10 |
| Art. 15 | Right of Access | Export includes profile, recipes, menus, shopping lists, social, audit logs (`lib/services/account/data_export_service.dart:129-145`, `lib/services/account/data_export_service.dart:161-176`). | Prompt baseline says 14 tests (`docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md:258`); dedicated test suite present (`test/unit/services/account/data_export_service_test.dart:1-3`). | 8/10 |
| Art. 17 | Right to Erasure | Tiered cascade deletion, residual probe, and deletion audit log with retention are implemented (`lib/services/account/account_deletion_service.dart:161-220`, `lib/services/account/account_deletion_service.dart:398-423`). | Prompt baseline says 15 tests (`docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md:267`); account deletion test coverage exists (`test/unit/services/account/account_deletion_service_test.dart:1-4`). | 7/10 |
| Art. 20 | Data Portability | Export is machine-readable JSON and includes metadata/completeness flags (`lib/services/account/data_export_service.dart:162-173`, `lib/services/account/data_export_service.dart:197-206`). | Same DataExportService suite (`test/unit/services/account/data_export_service_test.dart:1-3`). | 8/10 |
| Art. 30 | Processing Records | Persistent audit logging with immutable client rule semantics and admin-only read in rules (`lib/repositories/firebase/firebase_audit_repository.dart:61-84`, `firestore.rules:1347-1369`). | Prompt does not specify count for Art. 30 (`docs/analysis/prompts/02_SECURITY_AND_COMPLIANCE.md:276-280`); dedicated repository suite present (`test/unit/repositories/firebase_audit_repository_test.dart:1-4`). | 8/10 |

### 6. Firebase Security Rules Coverage

| Collection | Auth Required | Ownership Check | Role-Based | Field Validation | Status |
|-----------|---------------|----------------|------------|-----------------|--------|
| `users/{uid}` | Y (`firestore.rules:201`) | Y (`firestore.rules:201`) | N | N | Pass |
| `users/{uid}/recipes` | Y (`firestore.rules:206`, `firestore.rules:209`) | Y (`firestore.rules:206`, `firestore.rules:209`) | Y (admin override) (`firestore.rules:233`) | Y (`isValidTagResult`) (`firestore.rules:210`, `firestore.rules:219`) | Pass |
| `users/{uid}/friends` | Y (`firestore.rules:283-284`) | Partial (owner or friendId branch) (`firestore.rules:283-285`) | N | N | Fail (over-permissive write model) |
| `users/{uid}/friend_categories` | Y (`firestore.rules:290`, `firestore.rules:312`) | Partial (member update too broad) (`firestore.rules:311-317`) | Y (admin moderation) (`firestore.rules:322`) | Partial (size limit only) (`firestore.rules:316`) | Fail |
| `social_requests/{requestId}` | Y (`firestore.rules:473`, `firestore.rules:478`) | Y (`firestore.rules:474-475`, `firestore.rules:487`) | Y (sender/recipient role) (`firestore.rules:492-495`) | Y (`hasRequiredFields`, status transitions) (`firestore.rules:481`, `firestore.rules:488-490`) | Pass |
| `shared_content/{contentId}` | Y (`firestore.rules:504-520`) | Y (`firestore.rules:505`, `firestore.rules:512`, `firestore.rules:519`) | Y (owner/member model) (`firestore.rules:508`, `firestore.rules:517-518`) | Y (`hasRequiredFields`, immutability) (`firestore.rules:513`, `firestore.rules:516`) | Pass |
| `menus/{menuId}` | Y (`firestore.rules:594`) | Y (`firestore.rules:595`, `firestore.rules:602`) | Y (recipient self-scrub branch) (`firestore.rules:616-620`) | Y (`hasRequiredFields`) (`firestore.rules:603`) | Pass |
| `user_fcm_tokens/{tokenDocId}` | Y (`firestore.rules:1313`, `firestore.rules:1317`) | Y (`firestore.rules:1314`, `firestore.rules:1318`, `firestore.rules:1326`) | N | Partial (`userId` enforced) (`firestore.rules:1317-1318`) | Pass |
| `audit_logs/{logId}` | Y (`firestore.rules:1363`) | Y (`firestore.rules:1364`) | Y (admin read only) (`firestore.rules:1358`) | Y (`hasRequiredFields`) (`firestore.rules:1365`) | Pass |
| `deep_links/{linkId}` | Y (`firestore.rules:1681-1682`) | Partial (`create`/`delete` by creator, broad read) (`firestore.rules:1681-1684`, `firestore.rules:1690-1691`) | N | Partial (`hasRequiredFields` only) (`firestore.rules:1684`) | Partial (authenticated-wide read) |

Storage rules assessment:
- Strong default posture: user-scoped reads/writes and type/size limits are present (`storage.rules:21-31`).
- Shared image path includes uploader metadata ownership checks (`storage.rules:40-53`).
- Explicit default deny catch-all exists (`storage.rules:72-74`).

Cloud Functions security posture:
- Positive: auth and rate-limit middleware exists (`functions/src/middleware/rate_limiter.ts:351-356`, `functions/src/middleware/rate_limiter.ts:374-390`).
- Gap: App Check enforcement is inconsistent across callables (`functions/src/notifications/send-notification.ts:74-76`, `functions/src/events/log-parse-event.ts:144-146`, `functions/src/llm/structure-recipe.ts:70`).

### 7. Remediation Roadmap

**Phase 1: Critical Vulnerabilities (Week 1)**
Priority P0, must fix before production hardening sign-off.
- Lock down `/users/{uid}/friends/{friendId}` to server-managed writes and migrate friend-edge creation to callable/admin path validated against accepted social requests (`firestore.rules:282-285`, `firestore.rules:472-490`) - 16 to 24 hours.
- Update notification authorization checks to use canonical request/friend model and remove stale `friend_requests` assumptions (`functions/src/notifications/send-notification.ts:125`, `lib/core/constants/firestore_collections.dart:14`) - 6 to 10 hours.
Total effort: 22 to 34 hours. Expected risk reduction: 40%.

**Phase 2: High Priority (Weeks 2-3)**
Priority P1, fix within sprint.
- Restrict friend-category member updates to self-add only semantics (`firestore.rules:311-317`) - 8 to 12 hours.
- Populate cert pins for configured hosts and validate fail-closed behavior in production paths (`lib/services/security/cert_pin_config.dart:39-40`, `lib/services/security/pinned_http_client.dart:87-93`) - 12 to 16 hours.
- Enforce App Check on non-LLM callable endpoints (`functions/src/notifications/send-notification.ts:74-76`, `functions/src/events/log-parse-event.ts:144-146`) - 10 to 14 hours.
Total effort: 30 to 42 hours. Expected risk reduction: 35%.

**Phase 3: Medium Priority (Month 2)**
Priority P2, scheduled hardening.
- Migrate recipe/menu/draft persistence from SharedPreferences to encrypted storage (Drift/SQLCipher or secure encrypted file) (`lib/services/persistence_service.dart:125-129`, `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:279-281`) - 20 to 32 hours.
- Enable iOS release obfuscation and revisit symbol-strip settings (`.github/workflows/build-validation.yml:225-229`, `ios/Runner.xcodeproj/project.pbxproj:519`) - 8 to 12 hours.
- Tighten deep-link data visibility and normalize ID/config drift (`firestore.rules:1681`, `lib/repositories/firebase/firebase_deeplink_repository.dart:106-111`, `lib/firebase_options.dart:58`, `ios/Runner.xcodeproj/project.pbxproj:377`) - 8 to 12 hours.
- Force HTTPS-only import fetching unless explicit approved exception list (`lib/services/import/fetchers/http_content_fetcher.dart:16`, `lib/services/import/fetchers/http_content_fetcher.dart:90-93`) - 6 to 10 hours.
Total effort: 42 to 66 hours. Expected risk reduction: 20%.

### 8. Penetration Testing Readiness Checklist

- [x] OWASP Mobile Top 10 self-assessment complete
- [ ] All critical vulnerabilities remediated
- [ ] Security rules reviewed and updated
- [ ] Test accounts and environment prepared
- [ ] Vulnerability disclosure policy documented
- [ ] Incident response plan in place
- [ ] Security testing tools identified (MobSF, OWASP ZAP, Burp Suite, Frida)
- [ ] Scope defined (in-scope vs out-of-scope endpoints)

