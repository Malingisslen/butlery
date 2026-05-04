# Prompt 02 — Security & Compliance — Phase 1

Analyst: Claude (Opus 4.7, 1M context). Run: 2026-05-claude. Read-only audit.
Knowledge file consumed in full (88 KB) before any other work.

---

## Executive Summary

**OVERALL SCORE: 78 / 100 — Good (targeted hardening, not foundational rebuild)**

| Dimension                              | Score   |
|----------------------------------------|---------|
| 1. OWASP Mobile Top 10                 | 15 / 20 |
| 2. Authentication & Session            | 14 / 18 |
| 3. Data Protection & Encryption        | 14 / 18 |
| 4. Network Security                    | 11 / 12 |
| 5. Firebase Security Rules             | 10 / 12 |
| 6. API Security & Secret Management    |  6 / 10 |
| 7. Code Protection & Platform          |  8 / 10 |
| **Total**                              | **78**  |

Posture: Good. The repository contract (BaseFirebaseRepository → PermissionValidationMixin transitively, then Firestore rules as the authoritative gate) is solid and broadly applied. GDPR Articles 7/15/17/30 have real implementations with non-trivial test coverage and a documented rules-tester handoff. The 21-rule delta since the docs were last refreshed is consistently shaped (rate limits, immutability guards, recipient-self-scrub, admin-moderation overrides) — it is not a free-fire zone.

The points lost are concentrated in three areas:

1. **Third-party API keys baked into release binaries** (`OCR_SPACE_API_KEY`, `GOOGLE_VISION_API_KEY` via `String.fromEnvironment` — extractable from the AOT binary).
2. **GDPR consent enforcement gap surfaced by `flutter analyze`** — `lib/services/notifications/notification_service.dart:648-649` references `ConsentPurpose` and analyzer reports it as undefined despite the import being present. If the static error reflects a real compile failure, the entire push-consent-revoke → SecureStorage cleanup path (BUT-754) is dead code at runtime, leaving a stale FCM token in the keystore after the user revokes consent.
3. **Audit-log retention drift** — three different retention values for the same `audit_logs` collection (365d, 180d, 24mo/6mo) coexist across model, service, and Cloud Function.

### Top 5 Risks

1. **Third-party OCR/Vision API keys recoverable from release binary.** HIGH (CVSS 7.5).
2. **Push-consent revoke handler likely broken at runtime** (`ConsentPurpose` undefined — flutter-analyze.txt). HIGH (CVSS 7.4).
3. **Audit-log retention values drift across three call sites** — defence-in-depth confused, GDPR Art 5(1)(e) may be inconsistently honoured. MEDIUM (CVSS 5.5).
4. **Weekly menu plan participantUserIds drift not enforced in update rule** — admin can downgrade `participantUserIds` without updating `memberPermissions` (and vice versa) producing silent membership desync. MEDIUM (CVSS 5.0).
5. **Pings broadcast acknowledgement is open to any authenticated user** (`firestore.rules:863-864` deliberately accepts any auth user on broadcast pings) — knowingly accepted but the comment understates the impersonation surface. LOW (CVSS 3.5).

---

## Vulnerability Summary

- CRITICAL (CVSS ≥ 9.0): 0
- HIGH (7.0–8.9): 2
- MEDIUM (4.0–6.9): 8
- LOW (0.1–3.9): 6
- Informational / drift: 4

---

## Findings

### HIGH-1 — Third-party API keys baked into client binary

- **Severity**: HIGH (CVSS 7.5 — AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N)
- **OWASP**: M9 Reverse Engineering, M6 Insecure Authorization (key-misuse)
- **Evidence**:
  - `lib/services/ocr_extraction_service.dart:227` — `return const String.fromEnvironment('OCR_SPACE_API_KEY');`
  - `lib/services/ocr_extraction_service.dart:236` — `return const String.fromEnvironment('GOOGLE_VISION_API_KEY');`
- **Threat model**: `String.fromEnvironment` resolves at compile time. The literal value is embedded in the AOT-compiled snapshot and recoverable from a release APK/AAB/IPA via `strings`, `jadx`, or `r2`. An attacker extracts the keys and uses them against the third-party endpoints under their own quota until the founder notices the bill or the provider rate-limits the project. OCR.space and Google Vision both bill per-request — direct cost exposure.
- **Why this is HIGH not CRITICAL**: pinned HTTP client wraps the calls (BUT-427 — `pinned_http_client.dart`), so the local app can't be MITM'd into leaking the key over the wire, and the rest of the security model is intact. But the key still ships inside the binary regardless of pinning.
- **Remediation**: route OCR/Vision through a Cloud Functions callable that holds the key in Firebase Secrets (same pattern Gemini already uses — see `functions/src/llm/gemini-client.ts` which uses ADC, no key in source). Migrating preserves the pinning posture (server-side outbound calls) and shrinks the client attack surface to the Firebase callable, which is auth+AppCheck gated.
- **Effort**: 6–10 h (one CF per provider + client refactor, rate limiter already exists at `functions/src/middleware/rate_limiter.ts`).

### HIGH-2 — Consent-revoke push-token cleanup likely broken at runtime (BUT-754 regression)

- **Severity**: HIGH (CVSS 7.4 — privacy/GDPR Art. 17 + Art. 7(3))
- **OWASP**: M2 Insecure Data Storage (data persists past consent revocation), M7 Client Code Quality
- **Evidence**:
  - `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3` — `error - Undefined name 'ConsentPurpose' - lib\services\notifications\notification_service.dart:648:9`
  - `lib/services/notifications/notification_service.dart:16` (import is present): `import 'package:butlery/models/account/user_consent.dart';`
  - `lib/services/notifications/notification_service.dart:643-663` — `_handleConsentChange` calls `ConsentService.checkSafely(_subscribedConsentService, ConsentPurpose.pushNotifications, ...)` then `_tokenManager?.clearLocalToken()`
  - Knowledge entry `2026-05-02 — FCM consent-revoke gap closed (BUT-754, M1 of BUT-573 follow-up)` — describes this exact handler as the residual-store cleanup path.
- **Threat model**: User revokes push consent (Art 7(3) — withdrawal must be as easy as granting). The flutter-analyze error indicates the file does not compile. If true at runtime, the SecureStorage residual-token cleanup never runs after consent revocation. The token persists in encrypted Keychain/Keystore and could be reused by a future install of the same app on the same device, or surface in a backup if iOS Keychain backup is allowed. The BUT-754 entry explicitly documents this as the GDPR-relevant failure mode.
- **Caveat / verification gap**: The import IS present. The same enum reference at `lib/services/notifications/fcm_service.dart:163` is NOT flagged. This may be a stale analyzer cache rather than a real compile error — but the captured pre-analysis run is what the audit is contractually based on. If the flutter-analyze cache is stale, a re-run after `flutter clean` should produce 0 issues; that re-verification is part of remediation, not this audit.
- **Threat ranking rationale**: even if the static error is stale, the runtime path is critical to a compliance promise (BUT-754 closed within the last sprint). The fact that it produces a top-level analyzer error and the project's pre-commit hook (`flutter analyze --fatal-infos`) should have blocked the commit suggests the discipline was bypassed, which itself is a HIGH-severity process gap.
- **Remediation**:
  1. `flutter clean && flutter pub get && flutter analyze` — confirm whether the error reproduces.
  2. If it reproduces, fix the import (likely a missed `as` prefix conflict from `consent_service.dart` which imports `user_consent.dart` and re-exports nothing).
  3. Add a regression test: instantiate `NotificationService`, fire `_handleConsentChange` with consent revoked, assert `_tokenManager.clearLocalToken()` was called. Knowledge entry hints the existing test at `fcm_token_manager_test.dart` already has the SecureStorage fake — extend it.
- **Effort**: 1–2 h.

### MEDIUM-1 — Audit-log retention values drift across three call sites

- **Severity**: MEDIUM (CVSS 5.5)
- **OWASP**: M10 Extraneous Functionality (dead `expireAt` field), GDPR Art. 5(1)(e)
- **Evidence**:
  - `lib/models/audit_log.dart:88-89` — `'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365)))`
  - `lib/services/account/account_deletion_service.dart:50` — `static const int _auditLogRetentionDays = 180`
  - Knowledge entry `2026-04-30 — audit-log retention windows (BUT-665)`: 24 months for consent events, 6 months general. Authoritative cleanup is `functions/src/audit_logs/purge-expired.ts` querying `timestamp < cutoff`, NOT `expireAt`.
- **Threat model**: three different retention horizons claim to apply to the same collection. The CF is the only enforcer; the model's `expireAt` is dead weight. If a future contributor sees `expireAt` on the model and assumes Firestore TTL is auto-deleting, they will skip writing a TTL policy and the dead-field illusion deepens. From a regulator's perspective, the legal basis (Art 5(1)(c) data minimisation vs Art 7(1) consent demonstrability) requires *one* documented horizon per category — having three creates deniability ambiguity.
- **Remediation**: pick one of three:
  - (a) Activate Firestore TTL on `expireAt` and align values to the BUT-665 categories (consent: 730d, general: 180d). Drop `_auditLogRetentionDays`.
  - (b) Delete `expireAt` from the model+writes; rely entirely on the CF purger; document that as the single source of truth.
  - (c) Keep CF-only; align the 365d on the model write to 180d (general default) so even if CF stops, eventual TTL kicks in at the larger window.
- **Effort**: 2 h (pick + propagate + update `docs/security/audit-logs-retention.md`).

### MEDIUM-2 — `group_weekly_menu_plans` membership-desync vector

- **Severity**: MEDIUM (CVSS 5.0)
- **OWASP**: M6 Insecure Authorization
- **Evidence**: `firestore.rules:691-701`. Update rule allows admins to mutate `participants`, `participantUserIds`, AND `memberPermissions` — but does not require these three fields to stay synchronised. An admin can submit `participantUserIds: [a, b, c]` while leaving `memberPermissions` unchanged at `{a: 'admin', b: 'edit'}`. Subsequent reads gate on `memberPermissions` only (line 675 — `request.auth.uid in resource.data.memberPermissions`), so user `c` is in the participantUserIds list but cannot read.
- **Threat model**: griefing rather than data exfil. A malicious admin (or buggy client) can list a target user as "participant" in UI views that read `participantUserIds` while the user has no functional access. Could also confuse audit/export jobs that join on participantUserIds. Not a CVSS-9 because the admin role is required.
- **Remediation**: add a rules helper `_groupMembershipKeysAgree()` that checks `participantUserIds.toSet() == memberPermissions.keys().toSet()` and apply on update. Pair with a rules-tester case (hand off to `firestore-rules-tester` per CLAUDE.md).
- **Effort**: 2 h (rules + tests).

### MEDIUM-3 — `parsing_correction_repository.dart` and `site_config_repository.dart` bypass repository contract

- **Severity**: MEDIUM (CVSS 4.5)
- **OWASP**: M6 Insecure Authorization (audit-trail gap, not authz bypass)
- **Evidence**:
  - `lib/repositories/parsing_correction_repository.dart:27-31` — does NOT extend `BaseFirebaseRepository`, no `PermissionValidationMixin`, no audit-log writes. Holds `FirebaseFirestore.instance` directly.
  - `lib/repositories/site_config_repository.dart:14-28` — same pattern. Read-only against admin-curated `site_configs` (rules: `allow write: if false`), so authz risk is bounded — but the contract violation is the same.
  - `lib/repositories/firestore_repository.dart:49-64` — exposes the raw `firestore` getter as a public surface for callers; downstream services use it as a Firestore facade.
- **Threat model**: Firestore rules ARE the line of defense for these collections (parsing_corrections has `auth.uid == userId` create rule and ownership-only read). The mixin is the application-layer audit trail, not the security gate — but its absence means a client-side data poisoning attempt or a dropped permission check produces no audit-log entry, weakening BUT-424's tampering-detection story.
- **Remediation**: refactor both repos to extend `BaseFirebaseRepository` (or a read-only sibling for `site_configs`). For `FirestoreRepository`, document the deliberate facade pattern and ensure every call site has a typed repo to migrate to over time. Per knowledge entry `2026-04-30 — BUT-501 closed`, a dedicated gateway pattern exists for this exact case (`FirebaseDataExportRepository`).
- **Effort**: 4 h.

### MEDIUM-4 — `recipePresence` and `shoppingPresence` rules permit creation without TTL field

- **Severity**: MEDIUM (CVSS 4.7 — GDPR Art. 5(1)(c) data minimisation)
- **OWASP**: M2 Insecure Data Storage
- **Evidence**: `firestore.rules:778-786, 883-891`. Activeusers writes are `allow write: if isAuthenticated() && request.auth.uid == userId` — no validation that `expiresAt` is set, no validation that it's within a sensible window, no validation that `displayName`/`avatarUrl` are bounded length. The knowledge entry `2026-04-26 — Presence backends differ` documents the client-side TTL pattern but the rule does not enforce it server-side.
- **Threat model**: a misbehaving client (or a malicious user with a custom client) can write presence rows with no `expiresAt` or with `expiresAt` decades in the future. The TTL sweeper would only purge rows whose `expiresAt < now`, leaving the malicious row indefinitely. PII (displayName, avatarUrl) leaks across the GDPR cascade — and the BUT-477 cascade does pick these up by `userId`, so it's not a hard erasure failure, just a "data minimisation" bound that's rule-side absent.
- **Remediation**: extend the presence write rule to require `request.resource.data.expiresAt is timestamp && request.resource.data.expiresAt < request.time + duration.value(120, 's')` and `request.resource.data.get('displayName', '').size() <= 100`.
- **Effort**: 1 h (rules + rules-tester case).

### MEDIUM-5 — `unified_shared_shopping_lists` member with `view` permission can downgrade items

- **Severity**: MEDIUM (CVSS 4.5)
- **OWASP**: M6 Insecure Authorization
- **Evidence**: `firestore.rules:1125-1131`. Update rule for the LIST-level doc requires `view`/`edit`/`admin` member status, but the embedded `items[]` array is updateable as long as the affected keys exclude `ownerId`/`memberPermissions`/`createdAt`. A `view` member is rejected by the inner `in ['edit','admin']` clause — that's correct. **BUT**: this collection's `items` field is denormalised into the parent doc rather than living in the `match /items/{itemId}` subcollection at the `shared_content` path. Different collection, different rule, easy to confuse for a future contributor extending shared-list behaviour. Worth flagging in `docs/security/shopping-list-rules.md` so the embedded-vs-subcollection distinction stays explicit.
- **Threat model**: this is more drift-risk than active vuln — the rule shape *today* is correct. But the `unified_shared_shopping_lists` rule (line 1107) lives separately from the `shared_content/{contentId}/items/{itemId}` rule (line 570) and they evolve independently. The two collections are conceptually similar but the rules and item-shape diverged.
- **Remediation**: add a comment block to both rule sites cross-referencing the other; consider consolidation in a future sprint.
- **Effort**: 30 min.

### MEDIUM-6 — `pings` broadcast ack accepts any authenticated user (knowingly)

- **Severity**: MEDIUM (CVSS 4.0 — knowingly accepted but understated in code comment)
- **OWASP**: M6 Insecure Authorization
- **Evidence**: `firestore.rules:855-865`. Comment at lines 851-854 says "we can't cheaply verify group membership in rules for broadcasts, we allow ack on broadcasts by any authenticated user — the worst case is a peer acknowledging on behalf of the group, which is acceptable (ack is idempotent + UI-only)". The accepted gap is real: a non-member of the group can flip `acknowledged: true` on a broadcast ping with `toUserId == null`. They cannot read the ping content (read rule on line 830 requires being from/to or `toUserId == null` — but actually `toUserId == null` makes broadcasts world-readable to any authenticated user too). So a stranger can both read and ack a broadcast ping in any group across the database.
- **Threat model**: the ack itself is benign. The broader read access is more concerning — broadcast pings include `message` (capped at 100 chars) and `fromUserId`. An attacker iterates over `pings/*/pings` collectionGroup queries and harvests every broadcast ping ever sent (groupId leaks group existence + ownerId).
- **Verification**: collectionGroup `pings` rule at `firestore.rules:1577-1581` only grants read+delete to from/to user. Direct `match /pings/{groupId}/pings/{pingId}` rule at line 830 has the broadcast OR-branch (`resource.data.toUserId == null`). The two interact: collectionGroup queries run against the cg rule, but document-path reads run against the path rule. So an attacker who knows a `(groupId, pingId)` pair can read any broadcast.
- **Remediation**: tighten the broadcast-read OR-branch from `resource.data.toUserId == null` to `resource.data.toUserId == null && exists(.../friend_categories/$(groupId)) && (request.auth.uid in get(...).data.friendUserIds || request.auth.uid == get(...).data.ownerId)`. The get() cost is acceptable on a write-rare/read-rare collection. Pair with `firestore-rules-tester` cases.
- **Effort**: 3 h (rules + tests + verification).

### MEDIUM-7 — `feedback` collection has no length validation

- **Severity**: MEDIUM (CVSS 4.0 — DoS / cost amplification)
- **OWASP**: M7 Client Code Quality
- **Evidence**: `firestore.rules:1668-1674` — `allow create: if isAuthenticated() && isCreatingOwnDocument()`. No size cap, no field whitelist, no rate limit. Compare to `recipe_comments` (text capped at 2000) and `messages` (capped at 5000) which DO enforce size.
- **Threat model**: an authenticated user can write arbitrary-shape, arbitrary-size feedback docs as fast as their connection allows. Firestore doc size cap is 1 MB so abuse per-write is bounded, but write quota / cost amplification is real. Beta feedback FAB is on every screen.
- **Remediation**: add `request.resource.data.get('description', '').size() <= 5000`, whitelist allowed keys, and `rateLimitWrite('feedback', 60)`.
- **Effort**: 1 h.

### MEDIUM-8 — `notification_history` `data` map size limit is field-count, not byte-size

- **Severity**: MEDIUM (CVSS 4.0)
- **OWASP**: M7 Client Code Quality
- **Evidence**: `firestore.rules:1731` — `request.resource.data.get('data', {}).size() <= 20`. The `.size()` of a map returns key count, not byte size. An attacker writes 20 keys each holding a 50KB string → ~1MB per doc, just under the doc-size cap, multiplied by N writes per user limited only by SDK throughput.
- **Remediation**: add per-key length caps inside the `data` map (e.g., `request.resource.data.get('data', {}).values().toSet().size() <= 20` and supplemental string-length checks via `data.get('foo','').size() <= 200`). Or shift to a typed payload with explicit allowed keys.
- **Effort**: 2 h.

### LOW-1 — `connectivity_test` collection allows unrestricted read

- **Severity**: LOW (CVSS 2.5)
- **Evidence**: `firestore.rules:1095-1100`. Any authenticated user can read; no writes allowed. Used at app start by `FirestoreRepository.connectivityStream()`. Fine — but the collection name suggests it might leak app version / debug data over time. Today it is empty/admin-seeded.
- **Remediation**: document in a comment that this collection MUST stay admin-seeded with no PII; consider tag-checking at admin init.
- **Effort**: 15 min (doc comment).

### LOW-2 — `globalRecipeCache` allows any authenticated user to write rate-limited cache entries

- **Severity**: LOW (CVSS 3.5)
- **Evidence**: `firestore.rules:1450-1469`. `rateLimitWrite('globalRecipeCache', 30)` — 30s between cache writes per user. Cache is shared across users (any authenticated user can read), so a poisoned entry pollutes downstream parsing for everyone. Mitigated by per-user `createdBy` audit and the schema-validation that happens client-side in the parsing pipeline, but rule layer doesn't validate URL/title shape.
- **Threat model**: malicious user crafts a cache entry with attacker-controlled URL → other users' parse pipeline reads the cache and trusts shaped data. Worst case is misparsing, not RCE/data-leak.
- **Remediation**: extend create rule with `request.resource.data.url.matches('^https://.+') && request.resource.data.title.size() < 200`.
- **Effort**: 1 h.

### LOW-3 — `presence/{userId}` is readable by every authenticated user

- **Severity**: LOW (CVSS 3.5 — privacy)
- **Evidence**: `firestore.rules:1194-1198` — `allow read: if isAuthenticated()`. All online/offline status visible to every authenticated user.
- **Threat model**: information disclosure. Any user can poll and build a presence-graph of every Butlery user. Per knowledge BUT-624/590/416, "presence is currently online/offline only — pure presence; no geo" is the deliberate decision. Read-acceptable.
- **Remediation (optional)**: scope read to friends-only via `exists(/databases/.../users/$(userId)/friends/$(request.auth.uid))`. This breaks public-profile online dots, which may be intentional.
- **Effort**: 2 h (decision + change).

### LOW-4 — Android intent-filter for `text/*` MIME accepts arbitrary share text

- **Severity**: LOW (CVSS 3.0)
- **Evidence**: `android/app/src/main/AndroidManifest.xml:65-68` — `<data android:mimeType="text/*" />` on SEND intent. Wider than necessary — `text/plain` (line 53) and `text/html` (line 60) already covered.
- **Threat model**: malicious app shares content with arbitrary `text/foo` MIME, Butlery accepts it. The downstream processing path (smart-import) treats input as untrusted text anyway.
- **Remediation**: drop the `text/*` filter; rely on the two specific MIME types.
- **Effort**: 15 min.

### LOW-5 — Drift database failure-mode generates non-persistent encryption key

- **Severity**: LOW (CVSS 2.5 — availability, not confidentiality)
- **Evidence**: `lib/core/storage/drift/app_database.dart:175-181`. If SecureStorage read throws, generates a fresh random key with `_generateSecureKey()`. Subsequent launches will generate yet another fresh key → SQLCipher cannot decrypt previously-written data → user sees an empty offline cache.
- **Threat model**: not a confidentiality risk (the data is encrypted with a never-persisted key, so it's effectively destroyed). Availability risk: silent loss of offline cache without telemetry. The fallback comment says "data won't persist across app restarts if secure storage is unavailable" — fine.
- **Remediation**: add a structured Crashlytics event when the fallback fires so the founder can spot devices where SecureStorage is broken.
- **Effort**: 30 min.

### LOW-6 — `audit_logs` create rule rate limit is 2 seconds per write (too lax for log-spam abuse)

- **Severity**: LOW (CVSS 2.5)
- **Evidence**: `firestore.rules:1366` — `rateLimitWrite('audit_logs', 2)`. An authenticated user can write one audit log per 2s = 30 / minute per user = 43,200 / day. Per knowledge BUT-424 the user can only WRITE not read, so they can't enumerate their own trail — but they CAN spam-fill the collection, wasting storage and inflating retention costs.
- **Remediation**: increase to 30s or move to a CF-callable that pre-classifies the audit type and applies category-specific rate limits.
- **Effort**: 30 min.

### Informational — `stockholm` mentions in code comments (drift signal)

Per pre-analysis: 41 occurrences of "Stockholm" in `lib/` and `functions/`. The actual Cloud Functions region is `europe-west1` (Belgium). This is not a security defect — region IS Belgium per `functions/src/index.ts` `setGlobalOptions({region: "europe-west1"})` — but the doc/comment drift is misleading. Defer to Prompt 12.

### Informational — Firestore rules grew 22% / 28% since docs claim

Pre-analysis confirms 1788 lines / 95 match rules vs claimed 1465 / 74. The 21 new match rules I audited inline (recipePresence, shoppingPresence, pings, group_weekly_menu_plans, weekly_menu_plans, conversation_memberships, counters, settings, pantry, category_preferences, list_category_orders, blocks, deep_links/clicks, friend_categories, audit_logs, notification_delivery, notification_engagement, notification_metrics, recipe_social_stats, parse_corrections_v2, menu_lexicon, ingredient_suggestions, onboarding, acquisition, admins, reports). All are coherent with the security model — `default deny` at line 1810-1812 keeps the catch-all closed, and the new rules consistently use the established helper pattern (`isOwner`, `isAuthenticated`, `rateLimitWrite`, `cannotModify`). Drift is a doc problem (Prompt 12), not a security regression.

### Informational — `PermissionValidationMixin` adoption is structurally near-complete

The "20% adoption" claim in the orchestrator's known-context block is misleading. The mixin is applied transitively via `BaseFirebaseRepository` (lib/repositories/firebase/base_firebase_repository.dart:16-18). 30 Firebase repos extend `BaseFirebaseRepository`, so they ALL inherit the mixin. The two repos that don't (`parsing_correction_repository.dart`, `site_config_repository.dart`) are documented above (MEDIUM-3). Real adoption is ≥95%, not 20%. Recommend updating the orchestrator's `Known Security Gaps` section to reflect this.

### Informational — `cleartextTrafficPermitted` config is correct

`android/app/src/main/res/xml/network_security_config.xml` denies cleartext globally, allows only `localhost` and `10.0.2.2` (Android emulator). Good.

### Informational — Deep-link `https://butlery.app` has `autoVerify="true"`

Android App Links verification protects against deep-link hijacking by other apps. iOS universal links set in PrivacyInfo.xcprivacy domain. Both correct.

---

## OWASP Mobile Top 10 Scorecard

| Category | Status | Notes |
|----------|--------|-------|
| M1 Improper Platform Usage | Pass | Permissions justified, AndroidManifest allowBackup=false, network_security_config correct |
| M2 Insecure Data Storage | Partial | FCM token gap (HIGH-2), drift cache failure-mode (LOW-5), presence size cap missing (MEDIUM-4) |
| M3 Insecure Communication | Pass | HTTPS enforced; `http_certificate_pinning` wrapped (BUT-427/735/736); zero `badCertificateCallback` |
| M4 Insecure Authentication | Pass | Firebase Auth + MFA support (`auth_mfa_service.dart`); BUT-457 hardened FCM secure storage |
| M5 Insufficient Cryptography | Pass | SQLCipher 256-bit, `Random.secure`, base64Url-encoded; no custom crypto |
| M6 Insecure Authorization | Partial | MEDIUM-2/3/5/6 — rules drift edge cases, repo contract gaps |
| M7 Client Code Quality | Partial | HIGH-2 likely runtime broken; MEDIUM-7/8 size validation gaps |
| M8 Code Tampering | Pass | Release build minify+shrink+ProGuard, --obfuscate in CI |
| M9 Reverse Engineering | Partial | HIGH-1 third-party API keys recoverable from binary |
| M10 Extraneous Functionality | Partial | MEDIUM-1 dead `expireAt` field; LOW-1 connectivity_test |

---

## GDPR Compliance Report

| Article | Requirement | Implementation | Score |
|---------|-------------|----------------|-------|
| Art. 7 Consent | Granular per-purpose consent, version tracking, withdrawal | `ConsentService` + `ConsentPurposes` (7 enum values, exhaustive switch) + `_currentConsentVersion=1.1.0` | 8/10 — withdrawal cleanup may be broken (HIGH-2) |
| Art. 15 Right of Access | Self-service export of all user data | `DataExportService` + `FirebaseDataExportRepository` (BUT-501 closed) — single guarded gateway covering 28+ collections | 9/10 — `audit_logs` segment returns `permission-denied` per BUT-424; CF exporter still TBD |
| Art. 17 Right to Erasure | Cascading deletion across all user data | `AccountDeletionService` + 4 deletion ops (content/social/profile/storage) + `cleanupLegacySharedWith` admin cascade (BUT-753) + presence cascade (BUT-477) | 9/10 — known residual: `_scrubInboundSharedMenus` BUT-747 closed; remaining drift in audit-log retention (MEDIUM-1) |
| Art. 20 Data Portability | Machine-readable export | JSON via DataExportService | 9/10 |
| Art. 30 Records of Processing | Audit logs per operation | `FirebaseAuditRepository` + `purgeExpiredAuditLogs` CF (BUT-665) | 7/10 — three-way retention drift (MEDIUM-1); `audit_logs` create rate limit lax (LOW-6) |

GDPR posture overall: Good. The four-Article foundation is real, well-tested, and recently improved (BUT-424/498/501/665/671/747/753/754 all touch this surface). The scoring loss is concentrated on (a) the consent-revoke runtime regression risk and (b) the retention-policy drift that confuses the Article 5(1)(e) story.

---

## Firebase Security Rules Coverage (sampled)

| Collection | Auth | Ownership | Field validation | Notes |
|------------|------|-----------|------------------|-------|
| `users/{uid}` and 16 subcollections | Y | Y | Partial | settings birthYear gate (Art 8) at line 366-388; recipes tagResult validation 209-226 |
| `public_profiles/{uid}` | Y | Y | Y | friendsCount ±1 + rate limit 455-456; isHidden moderator-only 462-466 |
| `social_requests` | Y | Y | Y | rate-limited, server timestamp, blocking gate 482 |
| `shared_content/{cid}` and 6 subcollections | Y | Y (denorm) | Y | rate-limited; immutability on identity fields |
| `menus/{menuId}` | Y | Y (recipient + owner) | Y | BUT-747/749 recipient-self-scrub triple-guard; bulletproof against booting peers |
| `weekly_menu_plans/{planId}` | Y | Y (path-binding) | Y | doc-id binds owner via regex match |
| `group_weekly_menu_plans/{planId}` | Y | Y (member-perm map) | Partial | MEDIUM-2 membership-desync vector |
| `realtime_recipes`/`realtime_menus` | Y | Y | Y | participant-list check; presence subcollection nested correctly |
| `recipePresence`/`shoppingPresence` | Y | Y | Partial | MEDIUM-4 no expiresAt validation |
| `recipe_comments` | Y | Y (BUT-458 denorm) | Y | rate-limited; isNotBlockedBy gate; legacy-row degrade |
| `cook_snaps` | Y | Y | Y | BUT-728 full block created; admin moderation override |
| `messages` | Y | Y | Y | rate-limited; size 5000 cap; admin moderation override |
| `unified_shared_shopping_lists` | Y | Y (member-perm map) | Y | edit/admin gate; BUT-238 claim/unclaim covered |
| `blocks` | Y | Y (composite key) | Y | composite id `${blockerId}_${blockedId}`; immutable |
| `audit_logs` | Y (admin-only read) | Y (write self) | Y | BUT-424 admin-only read; LOW-6 lax rate limit |
| `pings` | Y | Y (from/to + broadcast) | Y | MEDIUM-6 broadcast read+ack open to any auth user |
| `reports` | Y | Y (reporter + admin) | Y | forward-only state machine 1604-1615 |
| `feedback` | Y | Y (create-self only) | NO | MEDIUM-7 no size cap or field whitelist |
| `notification_history` | Y | Y | Partial | MEDIUM-8 `data.size() <= 20` is field-count not bytes |
| `notification_delivery`/`engagement`/`metrics` | Y | Y | Y | well-shaped |
| `parsing_corrections` | Y | Y | Y | rule-side correct; mixin-side gap (MEDIUM-3) |
| `globalRecipeCache` | Y | Y | Partial | LOW-2 URL/title shape unvalidated |
| `presence/{uid}` | Y | Read-all | N/A | LOW-3 information disclosure (deliberate) |
| Default `match /{document=**}` | NO | N/A | N/A | `read,write: if false` — correct catch-all |

Storage rules (`storage.rules`):
- `users/{uid}/**` — owner-only, isValidImage, 10MB cap. ✅
- `shared/recipes/{rid}/**` — auth-read, metadata.uploadedBy create gate. ✅
- `models/**` — read-only auth. ✅
- `feedback/{uid}/**` — owner-only with image validation + 10MB. ✅
- Default `allow read,write: if false`. ✅
- No `cleartextTrafficPermitted` in storage scope (irrelevant — Firebase Storage is HTTPS-only).

Storage posture: clean. The 76-line file is well-structured.

---

## Cloud Functions Security (security-relevant subset)

- Region pin: `setGlobalOptions({region: "europe-west1"})` in `functions/src/index.ts` covers every export. Per knowledge BUT-647 region-pin verification: removing this line silently flips functions to `us-central1` (US egress = GDPR Chapter V regression). No regression detected in current state.
- ADC for Vertex AI (`functions/src/llm/gemini-client.ts:57-64`) — no API key in source. ✅
- Admin SDK use is in `functions/src/admin/admin-init.ts` only; standard pattern.
- `enforceAppCheck`: per knowledge entry only LLM + log-web-error functions enable it. The new `recordNotificationOpened` callable does not enforce App Check (knowledge entry C1 follow-up). Acceptable for shipping per the note, with rate limit + 30d TTL bounding abuse.

---

## Hardcoded Secrets Inventory

| File:line | Secret | Classification | Action |
|-----------|--------|----------------|--------|
| `lib/firebase_options.dart:35,45,53,62,71` | Firebase API keys (5x) | LOW (Firebase pattern — protected by app signing + rules) | None — leave as-is |
| `lib/services/ocr_extraction_service.dart:227` | `OCR_SPACE_API_KEY` (compile-time) | HIGH (extractable from binary) | HIGH-1 above |
| `lib/services/ocr_extraction_service.dart:236` | `GOOGLE_VISION_API_KEY` (compile-time) | HIGH (extractable from binary) | HIGH-1 above |
| `lib/services/ocr_extraction_service.dart:241` | `TESSERACT_API_URL` (compile-time) | LOW (URL not key) | None |
| `lib/core/di/modules/search_module.dart:160-161` | `ALGOLIA_APP_ID` / `ALGOLIA_API_KEY` (compile-time) | LOW (search-only key, EU-cluster verified at construction per knowledge BUT-580) | None — Algolia search-only API keys are restrictable in dashboard |
| `lib/services/device_integrity_service.dart:35,39` | Talsec team-ID + cert-hash (compile-time) | LOW (identifiers, not secrets) | None |

`.env.example` and `.env` posture: not directly inspected this run (deferred to local). Knowledge file confirms `.env` is gitignored.

---

## Risk Matrix

```
                Likelihood
                Low            Medium             High
Impact:
Critical                                          —
High           HIGH-1                             HIGH-2
Medium         MEDIUM-2/8     MEDIUM-1/4/6/7      MEDIUM-3
Low            LOW-1/4        LOW-2/5/6           LOW-3
```

Concentration is mid-band — no flame-on-the-roof items. The two HIGH findings are both well-bounded and individually fixable in <10 h.

---

## Phase 1 Success Criteria

| Criterion | Met? |
|-----------|------|
| All 7 dimensions investigated and scored | Y |
| OWASP M1-M10 per-category status | Y |
| Vulnerabilities documented with file:line + CVSS | Y |
| Risk matrix produced | Y |
| GDPR compliance per-article verified | Y |
| Firebase rules audited for sampled collections (24 sampled, full coverage table above) | Y |
| Hardcoded secrets inventory complete | Y |
| Storage security audited | Y |
| Network security assessed | Y |
| Code protection documented | Y |
| Remediation effort estimated per finding | Y |
| Zero code changes | Y |

---

## Knowledge-File Patterns Cited

- `2026-04-25 — initial seed` — repository contract baseline.
- `2026-04-25 — store-submission rating defense triad` — moderation/UGC posture.
- `2026-04-26 — Presence backends differ` — recipePresence/shoppingPresence TTL pattern (MEDIUM-4 evidence).
- `2026-04-26 — admin-delete rules tracking` — moderation coverage matrix (rules audit).
- `2026-04-26 — BUT-728 closes the moderation coverage matrix` — cook_snap rule shape pattern.
- `2026-04-27 — audit_logs read tightening (BUT-424)` — MEDIUM-1 + GDPR Art 15 follow-up.
- `2026-04-27 — third-party HTTPS pinning (BUT-427)` — pinning architecture (HIGH-1 mitigation).
- `2026-04-29 — DI singleton pattern for pinned HTTP clients (BUT-735)` — singleton lifecycle correctness.
- `2026-04-30 — server-side notification gate review patterns (BUT-647 / BUT-645 / BUT-638)` — region-pin verification + producer-consumer drift.
- `2026-04-30 — audit-log retention windows (BUT-665)` — MEDIUM-1 root cause.
- `2026-04-30 — BUT-501 closed: ExportRepo gateway pattern` — repo contract pattern (MEDIUM-3 fix template).
- `2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)` — third-party EU constraint.
- `2026-05-01 — Engagements collectionGroup wildcard` — self-scoped GDPR scrub pattern.
- `2026-05-02 — FCM consent-revoke gap closed (BUT-754, M1 of BUT-573 follow-up)` — HIGH-2 evidence.
- `2026-05-02 — BUT-753 legacy sharedWith admin cascade + BUT-577 JSON salvage` — admin-context cascade pattern.

---

## Appendix — Files Cited (absolute paths)

- C:\Butlery\butlery\firestore.rules
- C:\Butlery\butlery\storage.rules
- C:\Butlery\butlery\firebase.json (referenced for region setting; not directly opened)
- C:\Butlery\butlery\lib\firebase_options.dart
- C:\Butlery\butlery\lib\services\notifications\notification_service.dart
- C:\Butlery\butlery\lib\services\notifications\fcm_service.dart
- C:\Butlery\butlery\lib\services\notifications\modules\fcm_token_manager.dart
- C:\Butlery\butlery\lib\services\account\consent_service.dart
- C:\Butlery\butlery\lib\services\account\account_deletion_service.dart
- C:\Butlery\butlery\lib\services\auth\auth_mfa_service.dart
- C:\Butlery\butlery\lib\services\ocr_extraction_service.dart
- C:\Butlery\butlery\lib\services\llm\llm_service.dart
- C:\Butlery\butlery\lib\models\account\user_consent.dart
- C:\Butlery\butlery\lib\models\audit_log.dart
- C:\Butlery\butlery\lib\repositories\firebase\base_firebase_repository.dart
- C:\Butlery\butlery\lib\repositories\firebase\firebase_audit_repository.dart
- C:\Butlery\butlery\lib\repositories\parsing_correction_repository.dart
- C:\Butlery\butlery\lib\repositories\site_config_repository.dart
- C:\Butlery\butlery\lib\repositories\firestore_repository.dart
- C:\Butlery\butlery\lib\repositories\mixins\permission_validation_mixin.dart
- C:\Butlery\butlery\lib\core\storage\drift\app_database.dart
- C:\Butlery\butlery\lib\core\di\modules\search_module.dart
- C:\Butlery\butlery\lib\core\utils\log_sanitizer.dart
- C:\Butlery\butlery\functions\src\llm\gemini-client.ts
- C:\Butlery\butlery\android\app\src\main\AndroidManifest.xml
- C:\Butlery\butlery\android\app\src\main\res\xml\network_security_config.xml
- C:\Butlery\butlery\android\app\build.gradle.kts
- C:\Butlery\butlery\.github\workflows\build-validation.yml
- C:\Butlery\butlery\docs\analysis\runs\2026-05-codex\_pre-analysis\flutter-analyze.txt
- C:\Butlery\butlery\docs\analysis\runs\2026-05-codex\_pre-analysis\SUMMARY.md
- C:\Butlery\butlery\.claude\agents\firebase-backend-security.knowledge.md

---

End of Phase 1.
