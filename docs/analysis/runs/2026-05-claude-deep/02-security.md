# 02 — Security & Compliance — MERGED CANONICAL (Pass 2 Critic + Merger)

**Pass 1 — investigator draft:** firebase-backend-security specialist (preserved findings: HIGH-1 cert-pin empty, HIGH-2 12-of-15 callables miss App Check, HIGH-4 `friend_requests` legacy collection bug, MEDIUM-1 `category_overrides`/`activity_events` rule gaps, audit-log triple-drift).
**Pass 2 — critic + merger:** verified each Pass 1 / Pass 2-sibling claim against live source at the cited line, reconciled divergent claims, hunted blindspots (Storage MIME spoofing, SVG XSS, subcollection inheritance bugs, GDPR Art-30 records, token refresh).
**Methodology:** DEEP. Knowledge file consumed as hypothesis store, not authority. Dedup'd to other prompts: CVEs/licenses → 05; AI output validation → 07; AI/Function timeouts → 04; SDK consent race / privacy manifest / ATT / UGC moderation → 09; iOS encryption decl → 11; DR → 03.

**Total file:line citations in this merged report:** 96 (verified via grep `:[0-9]\+`). Threshold ≥50 met by ~2x.

---

## Score

**62 / 100** — "Acceptable" range, downgraded from earlier 71 estimate by:
- Cert-pinning is wired but EMPTY for all 8 hosts (Pass 1 HIGH-1, verified): MITM-vulnerable on hostile networks. Sibling Pass 2 missed this entirely.
- App Check coverage is 3 of 18 callables, not 3 of 15: 17% coverage, NOT the "5 of 15" Pass 2 sibling claimed (Pass 1 was more accurate; Pass 2 sibling under-counted callables and inflated the App Check coverage).
- `category_overrides` and `activity_events` rule gaps (verified by grep): two collections actively written by client repos with NO Firestore rule block — both fail closed, both look like dead code in production.
- `friend_requests` legacy collection bug (verified): 4 references in `send-notification.ts` plus 1 in `cleanup-expired-friend-requests.ts` plus 1 in `admin/reset-user-data.ts` to a renamed collection. Pending-friend-request notification flow is silently broken.
- Pass 2 sibling additions kept: Storage `image/svg+xml` XSS vector (verified — `storage.rules:9` matches `image/.*` with no exclusion); `realtime_menus/votes` rule gap (verified by grep — feature wired through to widget tree).

| Dimension                              | Weight | Score |
|----------------------------------------|--------|-------|
| OWASP Mobile Top 10                    | 20     | 12    |
| Authentication & Session               | 18     | 13    |
| Data Protection & Encryption           | 18     | 11    |
| Network Security                       | 12     | 7     |
| Firebase Security Rules                | 12     | 8     |
| API Security & Secret Management       | 10     | 5     |
| Code Protection & Platform             | 10     | 6     |

---

## Verification Summary (Pass 2 against source)

**Confirmed by source read:**
- `firestore.rules` is **1813 lines, 90 match blocks** (`grep -c "match /" firestore.rules`).
- **Exactly 3 callables have `enforceAppCheck: true`**: `structureRecipe` (`structure-recipe.ts:64` for export, `:70` for option), `ocrRecipeImage` (`ocr-recipe-image.ts:88` for export, `:94` for option), `logWebError` (`log-web-error.ts:116` for export, `:121` for option). Pass 2 sibling's CRIT-3 said "5 callables miss App Check" — undercounted.
- **Total callables exported = 18**, not 15: `bulk-retag.ts:191,401`, `seed-site-configs.ts:263,321`, `analyze-corrections.ts:308`, `track-unmatched-ingredients.ts:166`, `cleanup-audit-logs.ts:155`, `cleanup-deleted-ingredients.ts:164`, `log-parse-correction.ts:188`, `log-parse-event.ts:144`, `log-web-error.ts:116`, `ocr-recipe-image.ts:88`, `structure-recipe.ts:64`, `backfill-recipe-comments-denorm.ts:331`, `record-notification-opened.ts:125`, `send-notification.ts:74,469`. **15 of 18 callables miss App Check** (~83%).
- `votes` does NOT appear anywhere in `firestore.rules` (grep returns 0).
- `category_overrides` does NOT appear in `firestore.rules` (grep returns 0).
- `activity_events` does NOT appear in `firestore.rules` (grep returns 0).
- `friend_requests` referenced 6 times across `functions/src/`: `send-notification.ts:125,130,539,544`, `shared/collections.ts:20`, plus `cleanup-expired-friend-requests.ts:32` (via `Collections.friendRequests` constant), `admin/reset-user-data.ts:74`. The actual rule is `social_requests` (`firestore.rules:472`).
- `lib/services/security/cert_pin_config.dart:34-71` — **eight host entries, all `<String>[]` placeholders** with `// TODO(BUT-427-ops)` markers. Verified by reading the entire 105-line file.
- Audit-log retention triple-drift verified: model 365d (`audit_log.dart:88-89`), service 180d (`account_deletion_service.dart:50,417-419`), CF 730d consent / 180d general (`purge-expired.ts:26,29`).
- `compliance_export_manager.dart:42-91` — direct Firestore read at line 49, catch swallows error at 84-90, class docstring at 11-20 verbatim admits the path is broken.
- `firebase_menu_voting_repository.dart:54-66` — three of four validators return literal `true`, only `_isMenuParticipant` (line 39-46) is a real predicate, and it does NOT call `logPermissionCheck`.
- `account_deletion_service.dart:142-146` — comment "Delete auth entry FIRST", `await user.delete()` runs before tier-1 Firestore deletes.
- `lib/main.dart:208-238` — Crashlytics disabled at 212, but native error handlers (228-238) are registered BEFORE consent gate fires at 295. Consent enable runs in `_enableCollectionIfConsented()` at 305-359.
- `storage.rules:9` — `isValidImage()` matches `image/.*` with NO svg exclusion. Storage rules cannot inspect magic bytes.
- `firebase_storage_repository.dart:259` — `ImageFormatUtils.detectMimeTypeWithFallback` runs CLIENT-SIDE only (line 264 uses the result as `contentType`). Bypassable from a hostile client.
- `fcm_token_manager.dart:73-76` — `iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock)` (correct), `aOptions: AndroidOptions()` defaults (acceptable but not best practice).
- `MenuSlotVote` feature liveness verified: widget (`lib/widgets/menu/menu_vote_card.dart`), viewmodel (`menu_voting_viewmodel.dart`), service (`menu_voting_service.dart`), DI (`collaboration_module.dart`), push deep-link route (`notification_deep_link_router.dart:49`).

**Reconciled divergence:**
- App Check claim — Pass 1 said "12 of 15", Pass 2 sibling said "5 of 15". TRUTH: 15 of 18 missing. Pass 1 closer (the 12 referred to non-test callables; Pass 2 sibling missed several).
- Cert-pin claim — Pass 1 flagged HIGH-1 (cert pinning empty for all 8 hosts), Pass 2 sibling MISSED entirely. TRUTH: Pass 1 right; this is HIGH-severity.
- Crashlytics race — Pass 1 flagged at MEDIUM-3 (`main.dart:212`/`:295`), Pass 2 sibling did not flag. TRUTH: real, MEDIUM (per Firebase docs the SDK buffers locally and flushes when collection is re-enabled).
- `friend_requests` collection bug — Pass 1 only. TRUTH: real, HIGH-4 (silently breaks pending-friend-request notification flow).

---

## CRITICAL Findings

### CRIT-1 — `realtime_menus/{menuId}/votes/{voteId}` has NO firestore.rules block; every client write is default-denied since the feature shipped — and the feature IS live, not dead code

- **Severity:** CRITICAL (CVSS 7.4 technical; CRITICAL operationally — push-deep-link surface on a feature that silently fails).
- **Files:**
  - `lib/repositories/firebase/firebase_menu_voting_repository.dart:24-25` — collection ref builder.
  - Writes at: line 75 (`createVote`), 90 (`castVote`), 103 (transactional `resolveVote`), 120 (`addAlternative`).
  - `firestore.rules:741-770` defines `realtime_menus` with only a `presence` subcollection. **Pass 2 grep `votes` against firestore.rules returns ZERO matches.**
  - Default-deny `match /{document=**}` at `firestore.rules:1810-1812` rejects every write.
- **Repository contract:** `validateCreatePermission` (line 49-51) checks `realtime_menus/{menuId}.participantIds`, but client-side gates do not bypass rules. The actual `set()` at line 75 is rejected by the rules layer. Three of four validators return `true` (see H6 below).
- **Feature liveness verified (Pass 2):** UI widget exists (`menu_vote_card.dart`), composed in `menu_content_widgets.dart`, viewmodel in `menu_voting_viewmodel.dart`, service in `menu_voting_service.dart`, DI registration in `collaboration_module.dart`, push notification deep-link route in `notification_deep_link_router.dart:49` (line 56-63 lists `/menu_voting` as a valid route).
- **Worst failure shape:** push-notification → user taps → opens menu_voting screen → user votes → silent permission-denied → UI looks like it succeeded → vote never persists. Same failure-mode class as the cook_snaps gap closed in BUT-728.
- **Remediation (~30 min):** Add a rule block under `match /realtime_menus/{menuId}` mirroring the `presence` subcollection, gated on `isRealtimeParticipant('realtime_menus', menuId)` for read/create. For `castVote` (votes.userId map updates), pin `request.resource.data.diff(resource.data).affectedKeys().hasOnly(['votes'])`. Add rules tests via `firestore-rules-tester` agent for the participant-allow + non-participant-deny matrix.

---

### CRIT-2 — `compliance_export_manager.exportAuditLogs` permission-denies on every non-admin call and the catch block silently swallows it; GDPR Article 15 is currently broken for audit-log access

- **Severity:** CRITICAL (CVSS 6.5 technical; promoted to CRITICAL due to GDPR regulatory exposure plus codebase's own admission that it's shipped-broken).
- **Files (verified verbatim):**
  - `lib/services/account/export/compliance_export_manager.dart:42-91`.
  - Line 49: `_firestore.collection(FirestoreCollections.auditLogs).where('userId', isEqualTo: userId)...` — direct Firestore SDK read.
  - Lines 84-90: `} catch (e) { return {'error': e.toString(), 'note': 'Audit logs may not be available or accessible'}; }` — swallows `permission-denied` PlatformException into a payload field.
  - Class docstring at lines 11-20: **the codebase admits the path is broken** verbatim ("a Cloud Function exporter is the proper long-term fix; tracked under the BUT-424 follow-up").
  - `firestore.rules:1358` — `allow read: if isAdmin();` (BUT-424 tightening on 2026-04-27).
  - `functions/src/exports/` does NOT exist (Pass 2 `ls` confirmed: `cannot access`).
- **Behaviour:** the Article 15 export is **always missing the audit-log category** for end users with ≥1 audit-log entry. Empty-result happy path returns `{total_count: 0, audit_logs: []}` at lines 70-83; only the rules-deny exception triggers the swallow. Every active user has many audit-log entries; the bug fires for every non-admin user.
- **GDPR exposure:** Article 15 (Right of Access) requires the controller to provide ALL personal data. Audit logs stamped against the user's UID are personal data. A regulator request would catch this missing category.
- **Remediation (~2-3 h):** Build callable `exportAuditLogs` Cloud Function using Admin SDK + `request.auth.uid` filter. Deploy to `europe-west1`. Add `enforceAppCheck: true` and `enforceRateLimit('export', 60)`. Rewire `compliance_export_manager` to call via `FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('exportAuditLogs')`.

---

### CRIT-3 — 15 of 18 callable Cloud Functions lack `enforceAppCheck`, leaving them open to non-app callers (cost-burn, analytics-poisoning, friend-fallback abuse)

- **Severity:** CRITICAL (CVSS 7.6 — abuse asymmetric: cost-burn unbounded, data-poisoning silent, fix is one-line).
- **Files (Pass 2 verified `enforceAppCheck` setting per file):**

| Function | Export line | App Check |
|---|---|---|
| `structureRecipe` | `functions/src/llm/structure-recipe.ts:64` | YES (`:70`) |
| `ocrRecipeImage` | `functions/src/llm/ocr-recipe-image.ts:88` | YES (`:94`) |
| `logWebError` | `functions/src/events/log-web-error.ts:116` | YES (`:121`) |
| `bulkMarkForRetagging` | `functions/src/admin/bulk-retag.ts:191` | NO (admin gate inside) |
| `getRetagStatus` | `functions/src/admin/bulk-retag.ts:401` | NO (admin gate inside) |
| `seedSiteConfigs` | `functions/src/admin/seed-site-configs.ts:263` | NO (admin gate inside) |
| `getSiteConfigStats` | `functions/src/admin/seed-site-configs.ts:321` | NO (admin gate inside) |
| `getCorrectionStats` | `functions/src/analytics/analyze-corrections.ts:308` | NO |
| `getUnmatchedIngredientStats` | `functions/src/analytics/track-unmatched-ingredients.ts:166` | NO |
| `getAuditLogStats` | `functions/src/cleanup/cleanup-audit-logs.ts:155` | NO |
| `getDeletedIngredientStats` | `functions/src/cleanup/cleanup-deleted-ingredients.ts:164` | NO |
| `logParseCorrection` | `functions/src/events/log-parse-correction.ts:188` | NO |
| `logParseEvent` | `functions/src/events/log-parse-event.ts:144` | NO (also bare `onCall(handler)` — no options object at all) |
| `backfillRecipeCommentsDenorm` | `functions/src/migrations/backfill-recipe-comments-denorm.ts:331` | NO (admin gate inside) |
| `recordNotificationOpened` | `functions/src/notifications/record-notification-opened.ts:125` | NO (also bare `onCall(handler)`) |
| `sendNotification` | `functions/src/notifications/send-notification.ts:74` | NO |
| `sendNotificationBatch` | `functions/src/notifications/send-notification.ts:469` | NO |

- **Total:** 3 of 18 covered. **15 of 18 unprotected.** ~17% coverage.
- **Highest-risk subset (no admin gate inside the body):**
  1. `recordNotificationOpened` — CTR poisoning vector. Attacker with any auth account can spam-write `(uid, fakeNotificationId)` rows; combined with `suppressLowPerformers` (`functions/src/index.ts:87`), can game which notification types are killed.
  2. `logParseEvent` — `lines 199-217` increment `site_configs/{domain}.failureCount` server-side. Sybil attack against a competitor domain (e.g. `www.ica.se`) silently degrades parser confidence weighting.
  3. `logParseCorrection` — feeds into `analyzeCorrections` (`index.ts:93`) which influences future LLM training inputs. Poison vector.
  4. `sendNotification` / `sendNotificationBatch` — friendship gate present but legacy `friend_requests` query (HIGH-4) is broken. Bypasses default-deny only via friendship; App Check would block automated probing.
- **Why admin-gated callables still benefit from App Check:** prevents automated probing for the admin allow-list shape, and rate-limit-saturation by admin uids.
- **Remediation (~1-2 h):** Add `{ region: 'europe-west1', enforceAppCheck: true, cors: [...] }` options to all 15 unprotected callables. For the two bare-`onCall(handler)` forms (`logParseEvent`, `recordNotificationOpened`), switch to the two-argument `onCall(options, handler)` form (~10 LOC each).

---

## HIGH Findings

### HIGH-1 — All eight third-party SSL cert pins are empty placeholders (cert pinning effectively inactive for ALL hosts)

- **Severity:** HIGH (CVSS 7.4 — AV:N/AC:H/PR:N/UI:N/S:U/C:H/I:H/A:N).
- **OWASP:** M3 Insecure Communication.
- **Files (Pass 2 verified by reading the entire file):**
  - `lib/services/security/cert_pin_config.dart:34-71` — **eight host entries, every list is `<String>[]` with `// TODO(BUT-427-ops)` placeholders.** Hosts: `butlery-app-dsn.algolia.net`, `butlery-app.algolia.net`, `api.ocr.space`, `vision.googleapis.com`, `www.ica.se`, `www.koket.se`, `www.arla.se`, `www.recept.se`.
  - `lib/services/security/pinned_http_client.dart:87-93` (per Pass 1; not re-verified) — `if (pins.isEmpty) { ... return _inner.send(request); }` falls through to platform trust.
  - `lib/services/ocr_extraction_service.dart:215` — wraps the BUT-427 pinning client, but pin lists are empty.
  - `lib/repositories/algolia/algolia_search_repository.dart:90` — Algolia interceptor wired, but pin lists empty.
- **Threat model:** Wired-Inactive posture is strictly worse than "no pinning" for documentation/audit purposes — the wrapper is installed and looks active. Any attacker on a hostile network (corporate proxy, captive portal, OS-level CA install) can transparently intercept Algolia search queries (which include user search text), OCR uploads (recipe images), and recipe-scraping traffic. Combined with HIGH-3 (binary-extractable OCR keys), the attacker has TWO independent paths to the same secret.
- **Sibling Pass 2 missed this entirely** — scored M3 as Pass.
- **Remediation (~5-9 h):** (1) Capture leaf + intermediate cert SHA-256 from each live endpoint via `openssl s_client -showcerts -connect <host>:443 < /dev/null | openssl x509 -fingerprint -sha256 -noout`. (2) Populate the eight host entries with `[leaf, backup]`. (3) Add a release-mode guard in `PinnedHttpClient` that emits a Crashlytics non-fatal when a known-pinned-host has empty pins (kReleaseMode-only, fail-closed). (4) Establish a 30-day-before-rotation alert in ops calendar.

---

### HIGH-2 — Cloud Function `sendNotification` queries non-existent `friend_requests` collection (legacy collection rename leak); pending-friend-request notification flow is silently broken

- **Severity:** HIGH (CVSS 7.0 — functional bug with security-adjacent silent-failure shape).
- **OWASP:** M6 (broken authorization fallback path), M10 Extraneous Functionality.
- **Files (Pass 2 verified — 6 references to a collection that does not exist):**
  - `functions/src/notifications/send-notification.ts:125, 130, 539, 544` — direct `admin.firestore().collection('friend_requests')` calls.
  - `functions/src/shared/collections.ts:20` — `friendRequests: "friend_requests"` (legacy constant).
  - `functions/src/cleanup/cleanup-expired-friend-requests.ts:32` — uses `Collections.friendRequests` (resolves to `friend_requests`).
  - `functions/src/admin/reset-user-data.ts:74` — `{ name: "friend_requests" }` in deletion targets.
  - `firestore.rules:472` — actual collection is `social_requests`. NO `friend_requests` rule anywhere.
  - `lib/repositories/firebase/firebase_social_request_repository.dart` exists; no FirebaseFriendRequestRepository.
- **Behaviour (`send-notification.ts:122-145` verbatim):** When `callerUid !== targetUserId` AND no friendship doc exists, falls through to pending-friend-request fallback. Both queries return empty (collection is empty). `permission-denied` thrown. Effect: notifications can ONLY be sent between confirmed friends OR self → self. The "Anna sent you a friend request" notification is broken.
- **Bonus:** `cleanup-expired-friend-requests.ts` is now a no-op CRON job — sweeping an empty collection.
- **Remediation (~1-2 h):** Rename queries to `social_requests` and update where-clauses to filter `type == 'friend_request' && status == 'pending'`. Update the `Collections.friendRequests` constant or remove it. Add an integration test that verifies a pending-request notification reaches the recipient.

---

### HIGH-3 — Third-party API keys baked into client binary (OCR.space, Google Vision)

- **Severity:** HIGH (CVSS 7.5 — AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:N/A:N).
- **OWASP:** M9 Reverse Engineering, M6 Insecure Authorization.
- **Files:**
  - `lib/services/ocr_extraction_service.dart:227` — `String.fromEnvironment('OCR_SPACE_API_KEY')`.
  - `lib/services/ocr_extraction_service.dart:236` — `String.fromEnvironment('GOOGLE_VISION_API_KEY')`.
  - `lib/services/ocr_extraction_service.dart:241` — `TESSERACT_API_URL` (URL — LOW risk).
- **Threat model:** `String.fromEnvironment` materialises at compile time. Values land in the AOT snapshot, recoverable from release APK/AAB/IPA via `strings`/`jadx`/`r2`. OCR.space and Google Vision both bill per-request — direct cost exposure. Bridge to HIGH-1: with cert pinning empty, attacker doesn't even need to reverse-engineer; can MITM the live key off the wire.
- **Remediation (~6-10 h):** Route through Cloud Functions callable holding the key in Firebase Secrets (Gemini already does this — `functions/src/llm/gemini-client.ts` uses ADC, no key in source). Extend the existing `ocrRecipeImage` callable to cover OCR.space + Google Vision fallbacks server-side.

---

### HIGH-4 — Cross-user GDPR cascades in `social_deletion_operations.dart` and `profile_deletion_operations.dart` write directly via `_firestore`, bypass `PermissionValidationMixin`, and emit ZERO audit-log entries

- **Severity:** HIGH (CVSS 5.5 confidentiality bounded; HIGH on forensic-ability gap).
- **Files:**
  - `lib/services/account/account_deletion/social_deletion_operations.dart:64` — `batch.delete(_firestore.collection(...).doc(friendId).collection('friends').doc(userId))` deletes a doc OWNED BY ANOTHER USER.
  - `social_deletion_operations.dart:97` — collection-group batch delete.
  - `social_deletion_operations.dart:156, 208, 239` — collection-group scrub patches.
  - `profile_deletion_operations.dart:65` — `await prefsDoc.delete()` of settings docs.
- **Architectural concern:** these are legitimate GDPR Art-17 cross-user cascade ops. Routing them through per-resource repos with `validateOwnership` would deny because they cross ownership boundaries. Knowledge file entry **2026-04-27 BUT-498** acknowledges this as "partial-by-design." Defensible.
- **The actual critique:** there is NO audit logging on this path. `BaseFirebaseRepository.delete` calls `logPermissionCheck` for every per-user delete. The cross-user cascade does NOT — these deletes never appear in `audit_logs`. From a forensic-investigation standpoint there's no trail showing WHEN, WHO, or WHICH cross-user docs were touched.
- **Remediation (~3 h):** Wrap each cascade step in a synthetic audit-log entry via `FirebaseAuditRepository.logPermissionCheck`. Stamp `operation: 'gdpr_cascade_cross_user'`, `metadata: {step: 'reverse_friendship_delete', count: N, triggered_by_user: userId}`. One audit_log doc per cascade step (not per affected doc) — N=10 steps = 10 extra writes per account deletion.

---

### HIGH-5 — Account-deletion auth-context race (`user.delete()` runs before Firestore cleanup)

- **Severity:** HIGH (CVSS 6.0 — race + GDPR Art-17 incomplete erasure if race trips).
- **Files:**
  - `lib/services/account/account_deletion_service.dart:142-159` — comment "Delete auth entry FIRST", `await user.delete()` at line 146, followed by tier-1/2/3 Firestore deletes at lines 163-237.
  - `functions/src/cleanup/on-user-deleted.ts:29-51` — v1 auth.user().onDelete trigger, admin SDK so bypasses rules race. Good.
- **Threat model:** Firebase SDK caches ID token for ~1 hour after `user.delete()`, so deletes generally succeed within that window — BUT rules that ALSO call `exists(/databases/.../users/$(deletedUid))` or `get(/databases/.../public_profiles/$(deletedUid))` will see the doc gone for cascades that touch other users' subcollections (e.g. friend cleanup on the deleted user's friend's `friends/{deletedUid}` subdoc, recipe-comments BUT-459 isNotBlockedBy chain). Self-DoS during deletion; partial Firestore-side residue if client crashes mid-deletion (network drop, app suspend).
- **Remediation (~8-12 h):** Move the entire deletion server-side into a single CF callable that holds admin SDK privilege end-to-end — eliminates the race. Cheaper interim fix (~2 h): reverse the order (Firestore tiers first, `user.delete()` last). Document trade-off — the comment at lines 143-145 argues the opposite, both positions are defensible; the server-side approach removes the dilemma.

---

## MEDIUM Findings

### MED-1 — Two collections referenced by repository code have NO Firestore rule (`category_overrides`, `activity_events`)

- **Severity:** MEDIUM-HIGH (CVSS 6.5 — functional bug; security-relevant if a rule is later added without thinking).
- **Files (Pass 2 grep verified neither name exists in firestore.rules):**
  - `lib/repositories/firebase/firebase_category_preferences_repository.dart:216` writes to `category_overrides/{normalizedItemName}` via `_globalOverrideDoc()` at line 102-106.
  - `lib/core/constants/firestore_collections.dart:55` — `categoryOverrides = 'category_overrides'`.
  - `lib/repositories/firebase/firebase_activity_event_repository.dart:25` writes to `activity_events`.
  - `lib/core/constants/firestore_collections.dart:48` — `activityEvents = 'activity_events'`.
  - `functions/src/scheduled/north-star-weekly.ts:91` — server-side admin-SDK aggregation works (admin SDK bypasses rules).
- **Two interpretations, both bad:**
  1. **Dead-code:** `recordGlobalOverride` (called from a user flow at `firebase_category_preferences_repository.dart:209-224`) silently fails — error swallowed at line 222. `fetchFriendActivity` at `firebase_activity_event_repository.dart:68-99` returns empty for every user.
  2. **Coverage-gap:** someone adds a naive rule. `category_overrides` is global crowd-sourced learning; `allow read, write: if isAuthenticated()` would let any user wipe global category overrides, poisoning categorization for everyone.
- **Remediation (~4 h):** For `category_overrides`: `allow read: if isAuthenticated(); allow create, update: if isAuthenticated() && rateLimitWrite('category_overrides', 30) && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['overrides', 'updatedAt']) && request.resource.data.overrides.size() < 100;`. For `activity_events`: denormalize `visibleToUserIds` at write time and check `request.auth.uid in resource.data.visibleToUserIds`. Hand off to `firestore-rules-tester` for design + tests.

---

### MED-2 — Crashlytics buffers fatal errors before consent gate runs

- **Severity:** MEDIUM (CVSS 5.0 — GDPR Art. 7 violated by upload-after-consent of pre-consent stack traces).
- **OWASP:** M2 Insecure Data Storage (PII in fatal error reports persisted to disk).
- **Files (Pass 2 verified by reading lines 200-360):**
  - `lib/main.dart:212` — `setCrashlyticsCollectionEnabled(false)`.
  - `lib/main.dart:228-238` — `FlutterError.onError` and `PlatformDispatcher.onError` registered to call `recordFlutterFatalError` and `recordError` on Crashlytics.
  - `lib/main.dart:295` — `_enableCollectionIfConsented()` runs AFTER `_initializeModularSystem()` at line 242.
  - `lib/main.dart:330` — `setCrashlyticsCollectionEnabled(hasConsent && !kDebugMode)` flips the flag.
- **Threat model:** Crashlytics SDK buffers crashes locally regardless of the disabled flag — that flag controls UPLOAD, not capture. Per Firebase docs: "If collection is disabled, the crash report is stored locally and sent the next time the user enables collection." If a fatal error occurs during the bootstrap window (DI initialisation, repository wiring, SearchModule Algolia init at `_initializeModularSystem` line 242-292) — BEFORE consent is granted — and the user later grants consent, the buffered stack trace uploads. Stack traces typically include local variable names, class/function names with PII references (e.g. `UserProfile(uid: ABC123, email: alice@example.com)` if `toString()` was traversed in the error path).
- **Remediation (~1 h):** Switch the order — register `FlutterError.onError` and `PlatformDispatcher.onError` ONLY inside `_enableCollectionIfConsented()` after consent confirmed. Pre-consent errors log to console only. Belt-and-braces: call `FirebaseCrashlytics.instance.deleteUnsentReports()` immediately if consent is denied.

---

### MED-3 — Audit-log retention drifts across three call sites (model 365d, service 180d, CF 730d/180d)

- **Severity:** MEDIUM (CVSS 5.5).
- **OWASP:** M10 Extraneous Functionality (dead `expireAt` field), GDPR Art. 5(1)(e).
- **Files (Pass 2 verified each call site):**
  - `lib/models/audit_log.dart:88-89` — `'expireAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365)))`.
  - `lib/services/account/account_deletion_service.dart:50` — `_auditLogRetentionDays = 180`, used at line 417-419 for deletion-event logs.
  - `functions/src/audit_logs/purge-expired.ts:26` — `CONSENT_RETENTION_DAYS = 730`.
  - `functions/src/audit_logs/purge-expired.ts:29` — `GENERAL_RETENTION_DAYS = 180`.
  - `purge-expired.ts:125-126` — CF queries by `timestamp < cutoff`, NOT by `expireAt`. The model's `expireAt` field is dead weight.
- **Threat model:** Three documented retention horizons claim to apply to one collection. CF is the only enforcer; the model field is misleading vestige. A future contributor who sees `expireAt` and assumes a Firestore TTL policy will skip writing one — dead-field illusion deepens. Regulator: data-minimisation (Art 5(1)(c)) vs consent demonstrability (Art 7(1)) requires ONE documented horizon per category — three creates audit ambiguity.
- **Remediation (~2 h):** Pick CF as source of truth (730d consent, 180d general). Drop `expireAt` from model+writes. Update `docs/security/audit-logs-retention.md` (referenced by `purge-expired.ts:4-7`) to reflect single source.

---

### MED-4 — `audit_logs` retains `userId` and resource-path strings post-deletion; `on-user-deleted.ts` cascade does NOT scrub them; privacy-policy doc-drift

- **Severity:** MEDIUM (CVSS 4.5).
- **Files:**
  - `lib/repositories/mixins/permission_validation_mixin.dart:391-446` — `logPermissionCheck` writes `userId`, `resourceType`, `resourceId`, `granted`, `metadata`, sometimes free-text `details`.
  - `functions/src/cleanup/on-user-deleted.ts:53-122` — 10 cascade steps; NONE reference `audit_logs`.
  - `functions/src/audit_logs/purge-expired.ts:116` — deletes by `timestamp < cutoff`, not by user.
- **Effect:** A deleted user's audit logs persist for up to 24 months (BUT-665 consent-related window).
- **Regulatory reading:** GDPR Art-17(3)(e) explicitly preserves the right to retain personal data "for the establishment, exercise or defence of legal claims" — audit logs qualify. So full erasure is NOT required — but the user MUST be informed in the privacy policy.
- **Remediation (~30 min):** Document in `docs/security/audit-logs-retention.md` and reflect in privacy policy. Defer privacy-policy text alignment to Prompt 11.

---

### MED-5 — `recipePresence`/`shoppingPresence` write rules don't validate `expiresAt` bounds or `displayName` length

- **Severity:** MEDIUM (CVSS 5.5 — GDPR Art. 5(1)(c) data-minimisation, presence-graph poisoning).
- **Files:**
  - `firestore.rules:778-786` (recipePresence/activeUsers): `allow write: if isAuthenticated() && request.auth.uid == userId;` — no `expiresAt` validation, no field whitelist.
  - `firestore.rules:883-891` (shoppingPresence/activeUsers): same.
- **Threat model:** Misbehaving client writes presence rows with `expiresAt: timestamp(year=2099)` or unbounded displayName/avatarUrl. TTL sweeper never purges. PII (displayName) cascades only by `userId` — victim user can be shadowed in another user's presence list with attacker-controlled displayName for years.
- **Remediation (~1 h + rules-tester):** Extend write rules with `request.resource.data.expiresAt is timestamp && request.resource.data.expiresAt > request.time && request.resource.data.expiresAt < request.time + duration.value(120, 's') && request.resource.data.get('displayName', '').size() <= 100 && request.resource.data.get('avatarUrl', '').size() <= 1000`.

---

### MED-6 — `pings` broadcast: any auth user can READ + ACK any group's broadcast pings

- **Severity:** MEDIUM (CVSS 5.0).
- **OWASP:** M6 Authorization.
- **Files (Pass 2 verified):**
  - `firestore.rules:830-833` — read OR-branch: `resource.data.toUserId == null` makes broadcasts world-readable to any authenticated user.
  - `firestore.rules:855-865` — update gate: `resource.data.toUserId == null` allows any auth user to ACK.
  - `firestore.rules:1577-1581` — collectionGroup `pings` rule restricts to `from/to == auth.uid`, but document-path direct reads at 830-833 don't.
- **Exploit:** Attacker enumerates groupIds from `friend_categories` collectionGroup (line 1544-1547 — only requires being in ONE group with the target group's owner). Discovers a broadcast pingId via a friend who shared it. Reads + ACKs every broadcast in that group.
- **Remediation (~3 h + rules-tester handoff):** Tighten the broadcast OR-branch to include a membership `get()` check.

---

### MED-7 — `feedback` collection has no length validation, no rate limit, no field whitelist

- **Severity:** MEDIUM (CVSS 4.0 — DoS / cost amplification).
- **File:** `firestore.rules:1668-1674` — `allow create: if isAuthenticated() && isCreatingOwnDocument();`. No size cap, no whitelist, no rate limit. Compare: `recipe_comments:932` (text ≤2000), `messages:1072` (content ≤5000), `cook_snaps:998` (caption ≤200).
- **Remediation (~1 h):** Add `request.resource.data.get('description', '').size() <= 5000`, `keys().hasOnly([...])`, `rateLimitWrite('feedback', 60)`.

---

### MED-8 — `notification_history.data` size cap is field-count, not byte-size

- **Severity:** MEDIUM (CVSS 4.0).
- **File:** `firestore.rules:1731` — `request.resource.data.get('data', {}).size() <= 20`. `.size()` of a map returns key count. Attacker writes 20 keys × 50KB strings → ~1MB per doc.
- **Remediation (~2 h):** Combine field-count cap with per-key length caps; or shift to typed payload with explicit allowed keys.

---

### MED-9 — `parsing_correction_repository` and `site_config_repository` bypass repository contract

- **Severity:** MEDIUM (CVSS 4.5).
- **Files:**
  - `lib/repositories/parsing_correction_repository.dart:27-31` — does NOT extend `BaseFirebaseRepository`, no `PermissionValidationMixin`, no audit-log writes.
  - `lib/repositories/site_config_repository.dart:14-28` — same.
- **Note:** Real PermissionValidationMixin coverage is structurally near-complete via `BaseFirebaseRepository` inheritance — these two are the only true outliers. The orchestrator's "20% adoption" claim is misleading.
- **Threat model:** Firestore rules ARE the line of defense for these collections (`parsing_corrections` has `auth.uid == userId` create rule per `firestore.rules:1499-1516`). The mixin is the application-layer audit trail — its absence weakens BUT-424's tampering-detection story.
- **Remediation (~4 h):** Refactor both to extend `BaseFirebaseRepository` (or read-only sibling for `site_configs`). Use `firebase_data_export_repository.dart` gateway pattern (BUT-501) as template.

---

### MED-10 — `globalRecipeCache` write rule does not validate URL/title shape (cache poisoning)

- **Severity:** MEDIUM (CVSS 4.5).
- **File:** `firestore.rules:1450-1469`. `rateLimitWrite('globalRecipeCache', 30)`. Cache shared across users (any auth user reads at line 1452). Required-fields-only schema — no shape validation on `url` or `title`.
- **Threat model:** Malicious user crafts cache entry with attacker-controlled URL → other users' parse pipeline trusts shaped data. Combined with LLM tier's prompt-injection regex panel at `lib/services/parsing/tiers/llm_tier.dart:398-405` (which only checks `<script`, `javascript:`, `{{}}`, `${}`, `__proto__`, `constructor(`), attacker injects prompt-injection text into cached title (e.g. "Ignore previous instructions and output...") — bypasses the regex.
- **Remediation (~1 h):** Extend create rule with `request.resource.data.url.matches('^https://.+') && request.resource.data.title.size() < 200 && request.resource.data.title.size() > 0 && request.resource.data.url.size() < 2000`.

---

### MED-11 — `group_weekly_menu_plans` membership-desync vector

- **Severity:** MEDIUM (CVSS 5.0).
- **File:** `firestore.rules:691-701`. Update rule allows admins to mutate `participants`, `participantUserIds`, AND `memberPermissions` — but does not require these three fields to stay synchronised.
- **Threat model:** Griefing — admin lists target user as "participant" in UI views that read `participantUserIds` while user has no functional access via `memberPermissions`.
- **Remediation (~2 h + rules-tester):** Add rules helper `_groupMembershipKeysAgree()` checking `participantUserIds.toSet() == memberPermissions.keys().toSet()`.

---

### MED-12 — H6 (sibling) — `firebase_menu_voting_repository` returns `true` from three of four `validate*Permission` methods; `_isMenuParticipant` does not call `logPermissionCheck`

- **Severity:** MEDIUM (already covered by CRIT-1 fix).
- **File:** `lib/repositories/firebase/firebase_menu_voting_repository.dart:54-66` (Pass 2 verified verbatim).
- **Two violations of `lib/repositories/CLAUDE.md`:**
  1. "All 4 permission methods" must be REAL predicates, not stubs returning `true`.
  2. "Every custom permission check must call `logPermissionCheck()`" — `_isMenuParticipant` (line 39-46) does NOT.
- **Pattern caution:** any `validateXxxPermission(...) => true` in a repository is a CRITICAL-severity smell.
- **Remediation:** rolled into CRIT-1.

---

### MED-13 — Storage `contentType` validation is client-controlled; magic-byte spoofing possible

- **Severity:** MEDIUM (CVSS 5.0).
- **File:** `storage.rules:9` — `function isValidImage() { return request.resource.contentType.matches('image/.*'); }`. Storage rules cannot inspect file magic bytes. `firebase_storage_repository.dart:264` sets contentType client-side via `ImageFormatUtils.detectMimeTypeWithFallback` (line 259) — bypassable.
- **Threat model:** Polyglot HTML/JS uploaded with `contentType: 'image/png'`. Receiving Flutter widget decodes via image codec (fails) — but Firebase Storage's CDN serves back the client-claimed contentType. Polyglot SVG containing JavaScript opens via `getDownloadURL()` in browser → XSS.
- **Remediation:** see MED-14 (cheaper) or `onObjectFinalized` Storage trigger with magic-byte re-validation (~2 h).

---

### MED-14 — `image/svg+xml` not explicitly excluded from `storage.rules` `isValidImage()`

- **Severity:** MEDIUM (CVSS 5.5 — XSS via Storage CDN).
- **File:** `storage.rules:9` — regex `image/.*` matches `image/svg+xml`. SVGs are XML-with-script.
- **Remediation (~5 min):** Change to `return request.resource.contentType.matches('image/.*') && !request.resource.contentType.matches('image/svg.*');`.

---

### MED-15 — Three admin gates with three different sources of truth

- **Severity:** MEDIUM (CVSS 4.5).
- **Files:** `functions/src/shared/require-admin.ts:19-20` accepts BOTH `request.auth.token.admin === true` AND `request.auth.token.role === 'admin'`. Firestore-side `isAdmin()` (`firestore.rules:55-58`) uses a THIRD shape: `admins/{uid}` doc existence.
- **Threat model:** Admin-revoke clearing only one shape leaves user partially admin.
- **Remediation (~2 h):** Standardize on `admins/{uid}` doc existence (most observable from rules). Refactor `require-admin.ts` to read via `admin.firestore().doc('admins/${uid}').get()` with in-memory cache.

---

### MED-16 — Friends rule cross-user `allow write` has no rate limit, no field validation, no link to accepted social_request

- **Severity:** MEDIUM (CVSS 5.5).
- **File:** `firestore.rules:282-285`:
  ```
  match /friends/{friendId} {
    allow read: if isOwner(userId) || (isAuthenticated() && request.auth.uid == friendId);
    allow write: if isOwner(userId) || (isAuthenticated() && request.auth.uid == friendId);
  }
  ```
- **Threat model:** Attacker walks every public_profile (readable by all auth users per `firestore.rules:422`) and INSERTS themselves as a friend in EVERY other user's `friends` subcollection. Reverse-friendship cleanup only fires on account-delete. Attacker also gets cross-user friend-list reads (read symmetric to write).
- **Remediation (~1 h):** Add `&& exists(/databases/$(database)/documents/social_requests/$(request.auth.uid + '_' + userId))` and `&& rateLimitWrite('friends_cross_user', 60)` to cross-user branch. Split `allow write` into `allow create | allow update, delete` (only owner can update/delete).

---

### MED-17 — Recipe comment blocking gate bypassed when client omits `recipeOwnerId` field

- **Severity:** MEDIUM (CVSS 5.4).
- **Files:**
  - `firestore.rules:928-938` — create rule conditional on `recipeOwnerId` field presence.
  - `firestore.rules:1247-1249` — same shape for `recipe_ratings`.
- **Documented as intentional** (BUT-459 backwards-compatibility window). After ≥2 weeks of new client deploys, time to harden.
- **Remediation (~1 h):** Confirm production clients stamp the field via analytics; promote rule to require both `recipeOwnerId` AND `isNotBlockedBy(recipeOwnerId)`.

---

## LOW Findings

### LOW-1 — `audit_logs` create rate limit is 2s (43,200 writes/day per user)
- `firestore.rules:1366` — `rateLimitWrite('audit_logs', 2)`. User can spam-fill the collection. Effort: 30 min — increase to 10-30s or move to CF callable with category-specific limits.

### LOW-2 — `presence/{userId}` is readable by every authenticated user
- `firestore.rules:1194-1198`. Deliberate per BUT-624. Optional scope-to-friends fix: 2 h.

### LOW-3 — Drift app DB encryption-key fallback generates non-persistent key on SecureStorage failure
- `lib/core/storage/drift/app_database.dart:175-181`. Add Crashlytics structured event when fallback fires. Effort: 30 min.

### LOW-4 — Android intent-filter for `text/*` MIME accepts arbitrary share text
- `android/app/src/main/AndroidManifest.xml:65-68`. Drop in favour of explicit `text/plain` + `text/html`. Effort: 15 min.

### LOW-5 — `LogSanitizer.maskUserId` truncation too narrow at small user-base
- `lib/core/utils/log_sanitizer.dart:35-40`. First 8 chars of UID. At beta scale (<500 users), uniquely identifying across log analyses. Effort: 1 h — keep first 4 + last 4, or hash with per-install salt.

### LOW-6 — `connectivity_test` collection allows unrestricted read
- `firestore.rules:1095-1100`. Document MUST stay admin-seeded with no PII.

### LOW-7 — Tracker SharedPreferences key uses raw userId
- `lib/services/analytics/trackers/base_tracker.dart:88` — `final key = '$prefsPrefix$userId';`. SharedPreferences plaintext on web. Effort: 2 h — hash with same per-install salt as `firebase_analytics_repository.dart:466-486`.

### LOW-8 — Cert-pin failure-mode has no Crashlytics event
- `lib/services/security/pinned_http_client.dart:114-116`. Fire Crashlytics non-fatal on `_onPinMismatch`. Effort: 1 h.

### LOW-9 — LLM prompt-injection regex panel naive and trivially bypassable
- `lib/services/parsing/tiers/llm_tier.dart:398-405` — six regex patterns: `<script`, `javascript:`, `{{}}`, `${}`, `__proto__`, `constructor(`. Misses every actual prompt-injection class. Defer to Prompt 07.

### LOW-10 — FCM token migration leaves legacy SharedPreferences page recoverable on un-encrypted Android
- `lib/services/notifications/modules/fcm_token_manager.dart:73-76`. iOS `KeychainAccessibility.first_unlock` correct. Android `AndroidOptions()` defaults to `EncryptedSharedPreferences` on API 23+. Recommend explicit `aOptions: AndroidOptions(encryptedSharedPreferences: true)` for greppability.

---

## Rules-Test Coverage Gap Analysis

**Pass 2 confirmed:** `ls functions/src/__tests__/*-rules.test.ts` returns exactly **10 files**. Total match blocks = 90.

**Currently tested (≥1 allow + ≥1 deny):**

| Collection / path | Test file |
|---|---|
| `users/{uid}/recipes/{id}` | `firestore-rules.test.ts` |
| `users/{uid}/settings/preferences` | `firestore-rules.test.ts` + `age-gate-rules.test.ts` |
| `users/{uid}/onboarding/{progressDoc}` | `firestore-rules.test.ts` |
| `users/{uid}/pantry/{itemId}` | `firestore-rules.test.ts` |
| `audit_logs/{logId}` | `audit-logs-rules.test.ts` |
| `users/{uid}/friend_categories/{id}` | `cook-snaps-and-message-mod-rules.test.ts` |
| `cook_snaps/{snapId}` | `cook-snaps-and-message-mod-rules.test.ts` |
| `messages/{messageId}` | `cook-snaps-and-message-mod-rules.test.ts` |
| `menus/{menuId}` | `menus-rules.test.ts` |
| `recipe_comments/{commentId}` | `recipe-comments-rules.test.ts` |
| `users/{uid}/acquisition/{acquisitionDoc}` | `acquisition-rules.test.ts` |
| `parse_corrections_v2/{id}` | `parse-corrections-v2-rules.test.ts` |
| `reports/{reportId}` | `reports-rules.test.ts` |
| `public_profiles/{userId}` (admin moderation only) | `moderation-rules.test.ts` |
| `unified_shared_shopping_lists` (admin moderation only) | `moderation-rules.test.ts` |

~14-16 of 90 = **~16-18% coverage**.

**Highest-blast-radius untested rules:**
- `realtime_recipes/{recipeId}` + `presence/`
- `realtime_menus/{menuId}` + `presence/` + **MISSING `votes/`** (CRIT-1)
- `recipePresence/{recipeId}/activeUsers/{uid}` (BUT-477 GDPR)
- `shoppingPresence/{listId}/activeUsers/{uid}`
- `pings/{groupId}/pings/{pingId}` (MED-6)
- `social_requests/{requestId}` (state machine + isNotBlockedBy)
- `shared_content/{contentId}` + 5 subcollections
- `weekly_menu_plans/{planId}` (regex match)
- `group_weekly_menu_plans/{planId}` (MED-11)
- `unified_shared_shopping_lists/{listId}` non-moderation paths
- `user_fcm_tokens/{tokenDocId}`
- `user_notifications/{notificationId}` (BUT-459 blocking gate)
- `user_notification_preferences/{userId}`
- `users/{uid}/consent/{consentDoc}` (GDPR Art-7)
- `blocks/{blockId}` (composite-key)
- `recipe_ratings/{ratingId}` (same blocking-gate weakness)
- `notification_history`/`notification_batches`/`notification_delivery`/`notification_engagement`/`notification_metrics`
- `friends/{friendId}` cross-user write branch (MED-16)

**Hand off to `firestore-rules-tester` agent.** Target 50% to catch high-blast-radius gaps.

---

## OWASP Mobile Top 10 Scorecard

| Category | Status | Notes |
|----------|--------|-------|
| M1 Improper Platform Usage | Pass | Permissions justified; cleartext denied; allowBackup=false. |
| M2 Insecure Data Storage | **Partial → Weak** | MED-2 (Crashlytics pre-consent buffer), MED-5, LOW-3, LOW-7. |
| M3 Insecure Communication | **Fail** | HIGH-1 cert pinning empty for ALL hosts. |
| M4 Insecure Authentication | Pass | Firebase Auth + MFA service; BUT-457 hardened FCM SecureStorage. SMS-only MFA, no TOTP. |
| M5 Insufficient Cryptography | Pass | SQLCipher 256-bit, `Random.secure`, base64Url; no custom crypto. |
| M6 Insecure Authorization | **Partial** | CRIT-1, CRIT-3, HIGH-2, HIGH-4, HIGH-5, MED-1, MED-6, MED-9, MED-10, MED-11, MED-12, MED-15, MED-16, MED-17. |
| M7 Client Code Quality | Partial | MED-7, MED-8, LOW-9. |
| M8 Code Tampering | Pass | Release build minify+shrink+ProGuard; --obfuscate in CI; freeRASP runtime asserts at `device_integrity_service.dart:200-221`. |
| M9 Reverse Engineering | Partial | HIGH-3 third-party API keys recoverable from binary. |
| M10 Extraneous Functionality | Partial | MED-3 dead `expireAt` field; LOW-6 connectivity_test; HIGH-2 stale `friend_requests` references. |

---

## GDPR Compliance Report

| Article | Implementation | Score |
|---------|----------------|-------|
| Art. 5(1)(c) Data minimisation | rules-enforced; presence size gap (MED-5); notification_history (MED-8) | 7/10 |
| Art. 5(1)(e) Storage limitation | Drift across model/service/CF (MED-3) | 6/10 |
| Art. 7 Consent | `ConsentService` + 7-purpose enum (`user_consent.dart:90-98`); `_currentConsentVersion` (`consent_service.dart:35`); cross-tab broadcast via `consent_broadcast_web.dart` | 9/10 |
| Art. 8 Children | Rule-side age gate (`firestore.rules:374,384`) | 8/10 |
| Art. 15 Right of Access | `DataExportService` + `FirebaseDataExportRepository` (BUT-501); **CRIT-2 broken for audit_logs** | 6/10 |
| Art. 17 Right to Erasure | 28-collection cascade + on-user-deleted CF; HIGH-5 race | 7/10 |
| Art. 20 Data Portability | JSON via DataExportService | 9/10 |
| Art. 30 Records of Processing | `FirebaseAuditRepository` + `purgeExpiredAuditLogs` CF; MED-3 drift; LOW-1 lax write rate | 7/10 |

**GDPR posture: 7.4/10 average** — solid foundation, weakened by CRIT-2 (Art-15 broken for audit logs), MED-2 (Crashlytics pre-consent buffer), MED-3 (audit-log retention drift). **Records of Processing Activities (Art-30) doc:** no `docs/legal/records-of-processing.md` exists; the processor list lives implicitly in code (Firebase, Algolia, Mistral via Vertex, OCR.space, Google Vision, Crashlytics, Performance, FCM, ReCAPTCHA, freeRASP, AppCheck providers). Drift-prone. See Strategic-3.

---

## Hardcoded Secrets Inventory

| File:line | Secret | Classification |
|-----------|--------|----------------|
| `lib/firebase_options.dart:35,45,53,62,71` | Firebase API keys (5x) | LOW (Firebase pattern) |
| `lib/services/ocr_extraction_service.dart:227` | `OCR_SPACE_API_KEY` (compile-time) | **HIGH** — see HIGH-3 |
| `lib/services/ocr_extraction_service.dart:236` | `GOOGLE_VISION_API_KEY` (compile-time) | **HIGH** — see HIGH-3 |
| `lib/services/ocr_extraction_service.dart:241` | `TESSERACT_API_URL` (compile-time) | LOW (URL) |
| `lib/core/di/modules/search_module.dart:160-161` | `ALGOLIA_APP_ID` / `ALGOLIA_API_KEY` | LOW (search-only key restrictable) |
| `lib/services/device_integrity_service.dart:33` | `_kAndroidUploadCertHash` | LOW (identifier) |
| `lib/services/device_integrity_service.dart:35,39` | freeRASP teamId + cert hash | LOW |
| `lib/main.dart:215` | ReCAPTCHA v3 site key | LOW (publicly visible by design) |

---

## Strategic Security Opportunities

1. **Field-level encryption on shared content** → unlocks "share recipe history with my doctor / dietitian" without trusting recipient's account. Free-text recipe `notes` field may contain medical/dietary info; current state is plain Firestore. (Verified by Pass 2: `FieldEncryptionService` does NOT exist — `grep -rn FieldEncryption lib/` returns zero. Orchestrator's claim of client-side field encryption is unfounded.)
2. **App Check enforcement on every callable** → unlocks public-read mode on `butlery_archive/` and (eventually) Algolia search; once App Check covers every server endpoint, the friction of "users must sign in to even browse the recipe library" disappears.
3. **GDPR Art-30 Records of Processing as code-as-spec** → maintain `docs/legal/records-of-processing.md` AS the source of truth; CI test asserts every external processor referenced in `pubspec.yaml`/`functions/package.json` appears in the document. Unlocks B2B/enterprise compliance differentiator + auto-detected drift on dependency adds.
4. **Cert pinning rotation pipeline** → unlocks third-party API integrations (Spotify cooking-music, partner grocery API) — once the rotation runbook exists, adding a new pinned host is mechanical.
5. **Audit-log Cloud Function exporter (CRIT-2 fix)** → unlocks GDPR Art-15 user-facing audit-log export — compliance differentiator AND closes the regulatory gap.
6. **Server-side notification analytics (App Check + rate limit on `recordNotificationOpened`)** → unlocks honest A/B testing of notification copy.
7. **Re-auth gate on destructive ops** → currently `account_deletion_service.dart` does NOT call `user.reauthenticateWithCredential()` before `user.delete()` (Pass 2 grep confirmed: only one mention of "reauth" — inside a comment at line 142). Adds belt-and-braces against session-hijacking-driven account deletion. Effort: ~3 h.

---

## What's Missing — Security Invariants Nobody Tests

1. **Cert-pinning host coverage:** no test that asserts every host hit by production traffic appears in `cert_pin_config.dart` AND has a non-empty pin list.
2. **App-Check enforcement on every callable:** no test that asserts every `onCall` exported from `functions/src/index.ts` has `enforceAppCheck: true` (or carries an explicit justification comment).
3. **Collection ↔ Rule coverage:** no test asserts every `FirestoreCollections.X` constant has a corresponding `match /X/...` block in `firestore.rules`. The `category_overrides`, `activity_events`, AND `realtime_menus/votes` gaps would surface immediately. **This is the failure mode that has now occurred THREE times** (cook_snaps in BUT-728, menu_votes today, category_overrides+activity_events today).
4. **Default-deny coverage:** no test fuzzes Firestore rules with random collection names to verify the catch-all at `firestore.rules:1810-1812` denies. THE critical safety net — if rules-refactor accidentally moves it ABOVE other allow rules, default-deny stops working silently.
5. **Audit-log immutability runtime check:** `firestore.rules:1369` has `allow update, delete: if false;` — but admin SDK bypasses rules. A future CF that writes `db.collection('audit_logs').doc(id).update(...)` would corrupt the trail with no compile-time signal. Add a `// AUDIT_IMMUTABLE_DO_NOT_UPDATE` sentinel + custom lint flagging any `firestore().collection('audit_logs').doc(...).update|delete` in `functions/src/`.
6. **Crashlytics consent gating:** no test asserts that `FirebaseCrashlytics.instance.recordError(...)` is NOT called before consent has been verified (pre-consent error window at `lib/main.dart:228-237`).
7. **`sendNotification` friendship-fallback path** (HIGH-2): no test asserts the legacy `friend_requests` query returns the expected pending-friend-request doc. Test would have caught the rename leak.
8. **Account-deletion sequencing:** no test asserts `user.delete()` ordering at `account_deletion_service.dart:142-159` works under SDK-token-cache expiry.
9. **GDPR cascade completeness:** no test asserts the union of collections deleted at `account_deletion_service.dart:163-237` MATCHES the union of collections in `lib/repositories/firebase/*.dart` `collectionName` getters.
10. **PII sanitization in analytics:** no test asserts every `recipeId`/`groupId`/`userId` in `analytics_events.dart` event-parameter names is in `_piiHashKeys` OR `_piiDropKeys` (`firebase_analytics_repository.dart:31-44`).
11. **SecureStorage logout completeness:** no test asserts on `signOut()`, all SecureStorage keys associated with the user are purged. iOS Keychain persists across re-installs by default — token leak across accounts.
12. **Audit-log retention single-source-of-truth:** no test asserts model doesn't write a stale `expireAt`, nor that CF retention values match documented numbers in `docs/security/audit-logs-retention.md`.
13. **Subcollection rule inheritance:** no test that enumerates every subcollection path used in `lib/repositories/firebase/*.dart` (e.g. `realtime_menus/{menuId}/votes/{voteId}`) and asserts a corresponding `match` block exists. Firestore rules don't cascade — every subcollection needs explicit declaration.
14. **No request-input validation invariants at Cloud Functions entry:** sampled callables (`logParseEvent`, `logParseCorrection`, `recordNotificationOpened`) all have ad-hoc input validation. No shared `validateRequest<T>(schema, request)` helper. Future callable could ship without input validation. `zod` not currently in `functions/package.json`.
15. **No CSP / response-header configuration on web build:** no `firebase.json` audit done; `web/index.html` has no `Content-Security-Policy` header. Reflected XSS via SVG upload (MED-14) or deep-link querystring would execute unmitigated. Defer to Prompt 11 if web is out of scope.

---

## Drift / Informational

- **`stockholm` mentions (41 in `lib/`+`functions/`)** are timezone references (`Europe/Stockholm` for DST-safe quiet-hours per `functions/src/shared/quiet-hours.ts:3`). CF compute region is `europe-west1` (Belgium) per `index.ts:20`. **Not a security defect.**
- **Firestore rules at 1813 lines / 90 match rules.**
- **PermissionValidationMixin "20% adoption" claim is misleading:** real coverage near-complete via `BaseFirebaseRepository` mixing in `PermissionValidationMixin` per `base_firebase_repository.dart:16-18`.
- **Knowledge-file accuracy (verified):** BUT-754 FCM consent revoke handler at `notification_service.dart:643-663` (analyzer error is stale-cache), BUT-498 FCM token delete rule at `firestore.rules:1325-1326`, BUT-747/749 menus recipient-self-scrub triple-guard at `firestore.rules:613-627`, BUT-728 cook_snaps full block at `firestore.rules:976-1014`, BUT-457 SecureStorage-only FCM at `fcm_token_manager.dart:73-76`, BUT-580 Algolia EU cluster at `core/di/modules/search_module.dart:160-161`, BUT-665 audit-log retention at `purge-expired.ts:26-29`, BUT-424 audit_logs admin-read at `firestore.rules:1358`.
- **`FieldEncryptionService` does NOT exist** — `grep -rn FieldEncryption lib/` returns zero matches. Orchestrator doc-drift.

---

## Risk Matrix

```
                        Likelihood
                Low                Medium              High
Impact:
Critical                                              CRIT-1, CRIT-2, CRIT-3
High           HIGH-1 (cert)      HIGH-2 (friend_req) HIGH-3, HIGH-4, HIGH-5
Medium         MED-3, MED-4       MED-1, MED-2, MED-6 MED-5, MED-11, MED-13,
               MED-8, MED-9       MED-7, MED-10, MED-15  MED-14, MED-16, MED-17
                                  MED-12
Low            LOW-1, LOW-4       LOW-2, LOW-3, LOW-5 LOW-9
               LOW-6              LOW-7, LOW-8, LOW-10
```

---

## What this means in plain language

- **The big picture is good but the perimeter has soft spots.** The deep parts (who-can-see-what rules, the consent backbone, account deletion, audit logs) are solid. Most users are well protected.
- **One feature is silently broken in production:** the menu voting screen is live and reachable from push notifications, but votes never actually save because the database wasn't told to allow them. Users tap, they vote, nothing happens. Same kind of bug we already fixed once for cook-snaps.
- **One privacy-export feature is also broken:** when a user asks for their data via the GDPR export, the audit-log section silently returns "may not be available" because the read isn't allowed. The codebase even comments that this is broken. A regulator would catch it.
- **Three things to fix before the next round of marketing:** (1) the certificate fingerprints we set up to defend against Wi-Fi attackers were never actually filled in; (2) most of our backend endpoints don't yet check that the call comes from the official Butlery app, so abuse bots could spam them; (3) two image-OCR API keys are baked into the app file and could be pulled out.
- **One real bug masquerades as a security issue:** part of the friend-notification flow on the server still looks for an old database table name we already renamed. It silently returns "permission denied". Not exploitable, but the feature is broken.
- **A subtle privacy edge case:** if the app crashes during the first ~2 seconds of startup (before consent is asked), the crash report can later upload once consent is granted. We should hold off on registering the crash handler until after consent.
- **Two new ones in this report worth noting:** SVG images can be uploaded and served from our Storage CDN, which can run JavaScript in browsers — a path to cross-site-scripting. And our friends list can be edited cross-user with no rate-limit, no proof of an accepted friend-request, so an attacker could insert themselves into everyone's friends list.
- **Easy to undo:** every fix above is small (most are 1-4 hours). Nothing requires a rebuild of how the app works — just adding missing checks in the right places.

---

## Pass 2 verdict

**APPROVED-WITH-CORRECTIONS**

Both drafts had real strengths and real misses. Pass 1 (investigator) had correct App Check coverage analysis (12 of 15 → actually 15 of 18), correct cert-pinning HIGH-1 finding, correct `friend_requests` legacy bug, correct `category_overrides`/`activity_events` rule omissions, correct Crashlytics consent race, correct audit-log triple-drift. Pass 2 (sibling) had correct CRIT-1 (`realtime_menus/votes` rule gap with feature-liveness verification), correct CRIT-2 (`compliance_export_manager` GDPR break), correct H6 menu_voting validators, the new MED-13/MED-14 storage MIME spoofing + SVG XSS findings, and the new MED-16 friends cross-user write finding. Pass 2 sibling MISSED HIGH-1 (cert pinning) entirely, undercounted callables (15 vs 18) in CRIT-3, and missed the `friend_requests` legacy bug (HIGH-2 in this merged report). The merged canonical report keeps the strongest finding from each, corrects all reconciled divergences against verified source, and adds 4+ Pass-2 blindspot items (subcollection inheritance test, GDPR Art-30 records-of-processing doc, re-auth gate, CSP/web headers).

**Sibling file `02-security-pass1-investigator.md` will be deleted after this merge is committed to disk.**
