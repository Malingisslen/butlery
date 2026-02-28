BUTLERY TRUST, SAFETY & PRIVACY ANALYSIS - PHASE 1 FINDINGS
=============================================================
Analysis Date: 2026-02-28
Analyst: Claude (Opus 4.6)
Scope: UGC moderation, app store UGC policy, consent sequencing,
       privacy manifests, data transfers, children's protection

OVERALL SCORE: 18/100

+-- UGC Moderation System:             3/22 points
+-- Apple/Google UGC Policy:           2/18 points
+-- SDK Consent Sequencing:            2/15 points
+-- iOS Privacy Manifest:              0/12 points
+-- ATT Implementation:                5/10 points
+-- Data Transfer Compliance:          4/10 points
+-- Children's Data Protection:        2/8 points
+-- Community Guidelines & Spam:       0/5 points

STATUS: CRITICAL GAPS — App Store Rejection Risk

APP STORE REJECTION RISKS: 5 found
CRITICAL ISSUES: 8 found
HIGH PRIORITY: 6 found
MEDIUM PRIORITY: 5 found
LOW PRIORITY: 3 found

TOP 5 TRUST & SAFETY RISKS:
1. No UGC report backend — reports are silently discarded (fake success message)
2. ConsentService never wired to AnalyticsService — all analytics bypass consent
3. PrivacyInfo.xcprivacy missing entirely — iOS App Store rejection since Spring 2024
4. No Terms of Service exist — Apple/Google both require this for UGC apps
5. Crashlytics enabled unconditionally before any consent check

---

## Dimension 1: UGC Moderation System — 3/22

**Summary:** Block functionality is fully implemented. A report UI exists but only for group shopping lists, and it silently discards reports (logs locally, shows fake "sent" success). No content moderation queue, no automated screening, no server-side enforcement.

### CRITICAL

**TS-001: Report mechanism is a facade — reports silently discarded**
- File: `lib/widgets/social/group_shopping_list_actions.dart:239`
- `reportShoppingList()` logs to AppLogger and shows "Rapport skickad" success snackbar, but writes nothing to Firestore. User believes their report was submitted.
- Impact: Users have no functional way to report abusive content. Apple/Google both require working report mechanisms.
- Fix: Create `reports` Firestore collection, write report documents, add Cloud Function for notification.
- Effort: 1-2 days

**TS-002: No report mechanism for comments, recipes, messages, or profiles**
- The only report UI is on shopping lists in group context. Comments, shared recipes, messages, and user profiles have no report action.
- Impact: Most UGC content types are unreportable. Direct app store rejection risk.
- Fix: Add report actions to comment views, recipe detail view, messaging view, and profile view.
- Effort: 2-3 days

**TS-003: No Firestore collection for reports**
- `firestore.rules` (1,465 lines) contains zero references to a reports collection.
- Impact: Even if the UI wrote reports, there's nowhere to store them.
- Fix: Add `reports` collection to Firestore rules with proper security rules.
- Effort: 0.5 days

### HIGH

**TS-004: Block list not loaded on startup**
- File: `lib/services/unified/friends/friends_state_manager.dart`
- `initialize()` loads friends, friend requests, categories, and group invitations but never loads `blockedUsers` from Firebase. The blocked list starts empty every session.
- Impact: Blocked users appear unblocked after app restart until the user takes a block action.
- Fix: Add `_loadBlockedUsers()` call in `initialize()`.
- Effort: 0.5 days

**TS-005: Block not enforced server-side**
- `firestore.rules` has no rules checking `blockedUsers` before allowing reads or writes. A blocked user can still read the blocker's content via direct Firestore queries.
- Impact: Block is client-side only — a determined user can bypass it.
- Fix: Add Firestore rule checks for blocked status on social collections.
- Effort: 1 day

**TS-006: No "Block" button on friend profile view**
- File: `lib/views/social/friend_profile_view.dart`
- Shows "Remove Friend" but no "Block" option. Block is only accessible from the friend request flow.
- Impact: Users can't easily block someone they're already friends with.
- Fix: Add block action to friend profile view.
- Effort: 0.5 days

### MEDIUM

**TS-007: Comment model lacks moderation fields**
- File: `lib/models/social/social_comment.dart`
- Model has no `isHidden`, `isReported`, `moderationStatus`, or `reportCount` fields.
- Impact: Cannot hide reported content pending review.
- Fix: Add moderation fields to SocialComment model.
- Effort: 0.5 days

**TS-008: No automated content screening**
- No profanity filter, no spam detection, no duplicate content detection exists anywhere.
- Impact: No defense against abusive content until manual moderation is added.
- Fix: Add basic Swedish profanity word list filter for comments/messages. Consider Cloud Function trigger.
- Effort: 2-3 days

### Recommendations & Quick Wins
- Quick win: Wire up the existing report UI to actually write to Firestore (TS-001, ~4 hours)
- Quick win: Load blocked users on startup (TS-004, ~2 hours)
- Priority: Create `reports` collection and extend report UI to all content types

---

## Dimension 2: Apple/Google UGC Policy Compliance — 2/18

**Summary:** Butlery fails nearly every Apple and Google UGC requirement. No content filtering, no working report mechanism, no Terms of Service, no community guidelines, no appeal process. The only passing item is partial block functionality.

### App Store Compliance Dashboard

| Requirement | Apple | Google | Status |
|-------------|-------|--------|--------|
| Content filtering | Required | Required | **MISSING** — no filtering |
| Report mechanism | Required | Required | **FACADE** — UI exists but discards reports |
| Block users | Required | Required | **PARTIAL** — works but not loaded on restart |
| Contact info | Required | — | **PARTIAL** — `privacy@butlery.se` in privacy policy |
| Terms of Service | Required | Required | **MISSING** — no ToS exists |
| Community guidelines | — | Required | **MISSING** — no guidelines exist |
| Content removal | Required | Required | **MISSING** — no admin tools |
| Appeal process | — | Required | **MISSING** — no appeal mechanism |
| Privacy manifest | Required (iOS) | — | **MISSING** — no PrivacyInfo.xcprivacy |
| Data safety section | — | Required | **UNKNOWN** — cannot verify from code |

### CRITICAL

**TS-009: No Terms of Service**
- l10n has `authTermsOfService` ("Villkor") rendered as dead text on auth screen — no document, no view, no navigation target.
- File: `lib/views/auth_view.dart:400` (dead label)
- Impact: Both Apple and Google require ToS for apps with UGC. Rejection risk.
- Fix: Create ToS document (Swedish + English), create ToS view, wire navigation, add acceptance checkbox to registration.
- Effort: 2-3 days (content + implementation)

**TS-010: No community guidelines**
- Zero references to community guidelines, "riktlinjer", or conduct policies anywhere in codebase.
- Impact: Google Play explicitly requires community guidelines for apps with UGC. Rejection risk.
- Fix: Create community guidelines document covering harassment, spam, inappropriate content, copyright, impersonation. Add to app settings and onboarding.
- Effort: 1-2 days

**TS-011: Privacy policy inaccessible before registration**
- File: `lib/views/auth_view.dart:399-413`
- Auth footer shows "Villkor · Integritetspolicy" as plain `Text` — no tap handlers, no navigation. Users cannot read the privacy policy before creating an account.
- Impact: GDPR requires informed consent before data collection. Apple requires privacy policy accessible without login.
- Fix: Make footer labels tappable, navigate to PrivacyPolicyView (and future ToS view).
- Effort: 0.5 days

**TS-012: No ToS/privacy acceptance during registration**
- File: `lib/viewmodels/auth_viewmodel.dart:209`
- `register()` accepts email, password, displayName — no consent boolean, no ToS acceptance recorded.
- Impact: No record that user agreed to terms. Legal liability.
- Fix: Add checkbox to registration, record acceptance timestamp in user profile.
- Effort: 1 day

### HIGH

**TS-013: English privacy policy never loaded**
- File: `lib/views/legal/privacy_policy_view.dart:45`
- `_loadPrivacyPolicy()` hardcodes `privacy_policy_sv.md`. The English asset `privacy_policy_en.md` exists but is never used.
- Impact: Non-Swedish users cannot read the privacy policy in their language.
- Fix: Load based on locale.
- Effort: 0.5 days

### Content Type Moderation Coverage

| Content Type | Can contain offensive? | Moderated? | Reportable? |
|-------------|----------------------|------------|-------------|
| Recipe text | Yes | No | No |
| Recipe images | Yes | No | No |
| Comments | Yes | No | No |
| Ratings | Low risk (numeric) | N/A | No |
| Group names/descriptions | Yes | No | No |
| User profile names/avatars | Yes | No | No |
| Messages | Yes | No | No |
| Shopping list items | Low risk | No | Facade only |

**App store rejection risk: CRITICAL** — Butlery would be rejected by both Apple and Google in its current state for UGC apps.

---

## Dimension 3: SDK Consent Sequencing — 2/15

**Summary:** ConsentService exists with tests but is never wired to AnalyticsService. All analytics events bypass consent checks. Crashlytics and Firebase Performance are enabled unconditionally before any consent. The consent architecture is fundamentally broken at the wiring level.

### CRITICAL

**TS-014: ConsentService never connected to AnalyticsService**
- `AnalyticsService.setConsentService()` method exists (`analytics_service.dart:55`) but is never called from any DI module or startup code. Zero call sites found in entire codebase.
- Result: `AnalyticsService._consentService` is always `null`.
- File: `lib/services/analytics/analytics_service.dart:68-78`
  ```dart
  Future<bool> _hasAnalyticsConsent() async {
    if (_consentService == null) return true; // Always null → always true
  }
  ```
- Impact: ALL analytics events are logged regardless of user consent. GDPR Article 7 violation.
- Fix: Wire `ConsentService` into `AnalyticsService` in `CoreModule.configure()`.
- Effort: 0.5 days

**TS-015: BaseTracker consent check always returns true**
- File: `lib/services/analytics/base_tracker.dart:19-32`
- Same pattern: `_consentService == null → return true`. All trackers bypass consent.
- Impact: Every tracker (recipe, social, performance, etc.) logs events without consent.
- Fix: Same wiring fix as TS-014.
- Effort: Included in TS-014

**TS-016: Crashlytics enabled before consent, before auth**
- File: `lib/main.dart:113-114`
  ```dart
  FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode)
  ```
- Called in `main()` before `ApplicationBootstrap.initialize()`, before any user is authenticated, before any consent could be read.
- Impact: Crash reports (including device info, stack traces) sent to Google without consent.
- Fix: Defer Crashlytics enablement until consent is checked. Default to disabled.
- Effort: 1 day

**TS-017: Firebase Performance trace started before consent**
- File: `lib/main.dart:200`
- `FirebasePerformance.instance.newTrace('app_startup')` runs before bootstrap and consent.
- Impact: Performance data collected without consent.
- Fix: Defer performance traces until after consent check.
- Effort: 0.5 days

### HIGH

**TS-018: FirebaseAnalyticsRepository.initialize() never called**
- File: `lib/core/di/modules/core_module.dart:253-254`
- `CoreModule.initialize()` calls `analyticsService.toString()` (a no-op) instead of `analyticsService.initialize()`. So `setAnalyticsCollectionEnabled` is never invoked.
- Impact: Firebase Analytics collection runs on Firebase SDK defaults (enabled).
- Fix: Call `analyticsService.initialize()` in CoreModule.
- Effort: 0.5 days

**TS-019: Algolia client instantiated before consent**
- File: `lib/core/di/modules/search_module.dart:55-59`
- `SearchClient` is created at DI configure time. Health check query runs at `SearchModule.initialize()` (line 93-94), before consent.
- Impact: Algolia receives data before user consents. (Mitigated: feature flag is off by default.)
- Fix: Gate Algolia initialization behind consent when feature flag is on.
- Effort: 0.5 days

### SDK Initialization Timeline vs Consent

| Order | What | Consent checked? |
|-------|------|-----------------|
| 1 | `Firebase.initializeApp()` | No |
| 2 | `Crashlytics.setCrashlyticsCollectionEnabled(true)` | **No** |
| 3 | `FirebaseAppCheck.activate()` | No |
| 4 | `FirebasePerformance.newTrace()` | **No** |
| 5 | DI: `SharedPreferences.getInstance()` | No |
| 6 | DI: `FirebaseAnalyticsRepository()` created | No |
| 7 | DI: `AnalyticsService()` created (consent never wired) | **No** |
| 8 | DI: `ConsentService` registered (lazy) | N/A |
| 9 | DI: `SearchClient` created (if Algolia flag on) | **No** |
| 10 | Bootstrap stages execute | No consent gate |
| 11 | User authenticates | — |
| 12 | ConsentService lazily accessed | First consent check |

**Conclusion:** Every SDK initializes and starts collecting before consent is ever checked.

---

## Dimension 4: iOS Privacy Manifest — 0/12

**Summary:** `PrivacyInfo.xcprivacy` does not exist. This is a mandatory file since Spring 2024 for iOS 17+ apps. App Store submission will be rejected.

### CRITICAL

**TS-020: PrivacyInfo.xcprivacy missing entirely**
- `ios/Runner/` contains no privacy manifest file.
- Impact: **Automatic App Store rejection** for iOS 17+ submissions since Spring 2024.
- Fix: Create `PrivacyInfo.xcprivacy` with all required declarations.
- Effort: 0.5 days

**TS-021: NSPrivacyAccessedAPICategoryUserDefaults not declared**
- SharedPreferences is used in 12+ files, which maps to `NSUserDefaults` on iOS.
- Apple requires this to be declared in the privacy manifest with a valid reason code.
- Impact: App Store rejection.
- Fix: Add `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (app functionality) to privacy manifest.
- Effort: Included in TS-020

### HIGH

**TS-022: Third-party pod privacy manifests not verified**
- Firebase, Algolia, and other pods may require their own privacy manifest declarations.
- Impact: Combined privacy manifest must cover all Required Reason API usage across all dependencies.
- Fix: Run `flutter build ios` and check Xcode warnings for missing privacy manifests. Verify pod privacy manifests are bundled.
- Effort: 0.5 days

**TS-023: Privacy nutrition labels cannot be verified**
- Without a privacy manifest, App Store Connect privacy labels (data types, tracking, linking) cannot be cross-referenced against actual data collection.
- Impact: If privacy labels in App Store Connect don't match actual collection, Apple can reject or remove the app.
- Fix: Audit actual data collection and ensure App Store Connect labels match.
- Effort: 1 day

### Required Privacy Manifest Content

```xml
<!-- Minimum required PrivacyInfo.xcprivacy content -->
NSPrivacyAccessedAPITypes:
  - NSPrivacyAccessedAPICategoryUserDefaults (SharedPreferences → NSUserDefaults)
    Reason: CA92.1 (access info written by the app itself)

NSPrivacyCollectedDataTypes:
  - Email address (registration)
  - Name (registration, profile)
  - Photos (recipe images)
  - Coarse location (not collected currently? verify)
  - Usage data (Firebase Analytics)
  - Crash data (Crashlytics)
  - Performance data (Firebase Performance)
  - Search queries (Algolia, if enabled)

NSPrivacyTracking: false (no cross-app tracking)
```

---

## Dimension 5: ATT Implementation — 5/10

**Summary:** No ATT prompt implementation exists, but Butlery likely does not require one. Firebase Analytics in Flutter does not access IDFA by default, and there is no advertising SDK. However, this assessment should be verified.

### MEDIUM

**TS-024: No ATT framework, but likely not required**
- No `app_tracking_transparency` package in pubspec.yaml
- No IDFA access, no advertising SDK, no cross-app tracking
- Firebase Analytics in Flutter does not use IDFA unless explicitly configured
- Impact: Low risk — ATT is not required if no tracking occurs. But should be formally verified.
- Fix: Verify no SDK accesses IDFA. Document the determination. If any future SDK needs tracking, implement ATT before enabling it.
- Effort: 0.5 days (verification only)

**TS-025: Stale NSFaceIDUsageDescription in Info.plist**
- File: `ios/Runner/Info.plist:58-59`
- FaceID description exists but biometric auth was decided to be deleted entirely (per project memory).
- Impact: Low — won't cause rejection but is misleading.
- Fix: Remove `NSFaceIDUsageDescription` from Info.plist.
- Effort: 5 minutes

**Score rationale:** 5/10 because ATT is likely not required and correctly not implemented, but the formal determination hasn't been documented, and the stale FaceID key is a minor issue.

---

## Dimension 6: Data Transfer Compliance — 4/10

**Summary:** Firebase/Google data transfer is partially documented (EU-USA DPF). Mistral AI uses the default non-EU endpoint. Algolia region is unknown. Neither Mistral nor Algolia are listed in the privacy policy as data processors.

### CRITICAL

**TS-026: Mistral AI uses non-EU API endpoint**
- File: `functions/src/llm/mistral-client.ts:25`
- `new Mistral({ apiKey })` — no `serverUrl` override. SDK defaults to `https://api.mistral.ai` (global/US).
- Impact: Recipe text and images are sent to a non-EU endpoint. GDPR Article 44 requires valid transfer mechanism for EU-to-US data transfers.
- Fix: Set `serverUrl: 'https://eu.mistral.ai'` for EU data processing.
- Effort: 5 minutes (code change) + DPA negotiation time

**TS-027: Mistral and Algolia absent from privacy policy**
- File: `assets/legal/privacy_policy_sv.md:113-123`
- Section 6.1 lists only "Google Firebase" and "Google Analytics" as third-party processors. Mistral AI and Algolia are not mentioned.
- Impact: GDPR Article 13 requires disclosure of all data recipients. Privacy policy is materially incomplete.
- Fix: Add Mistral AI and Algolia to privacy policy Section 6.1.
- Effort: 0.5 days

### HIGH

**TS-028: No DPA with Mistral AI**
- Recipe text (up to 50,000 chars), source URLs, and base64-encoded recipe images are sent to Mistral.
- No Data Processing Agreement is referenced in code or documentation.
- Impact: GDPR Article 28 requires a DPA with all data processors.
- Fix: Execute DPA with Mistral AI. Mistral offers a standard DPA.
- Effort: Business/legal process (1-2 weeks)

**TS-029: No DPA with Algolia**
- While feature-flagged off, the infrastructure indexes recipe titles, descriptions, ingredients, owner IDs, and user display names.
- No DPA referenced.
- Impact: Must have DPA in place before enabling the feature flag.
- Fix: Execute DPA with Algolia before enabling search.
- Effort: Business/legal process (1-2 weeks)

**TS-030: Algolia region unknown**
- No EU region specified in code. Algolia region is determined by the Application ID at account creation.
- Impact: If Algolia cluster is in US, recipe data crosses borders without valid transfer mechanism.
- Fix: Verify Algolia application region. If not EU, migrate or configure EU cluster.
- Effort: 0.5 days (verification) + potential migration

### MEDIUM

**TS-031: Source URLs sent unredacted to Mistral**
- File: `functions/src/llm/structure-recipe.ts:68`
- `sourceUrl` may contain session tokens or user-identifying parameters.
- Impact: Potential PII leakage to third-party processor.
- Fix: Strip query parameters from source URLs before sending to Mistral.
- Effort: 0.5 days

**TS-032: Firestore region not confirmable from code**
- Cloud Functions are pinned to `europe-west1`. ADR-003 states Firestore should be `europe-west1`. But Firestore region is set at project creation in Firebase Console, not in code.
- Impact: Cannot verify from code alone. Low risk if ADR-003 was followed.
- Fix: Verify in Firebase Console that Firestore location is `europe-west1`.
- Effort: 5 minutes (verification)

### Data Processor Inventory

| Service | Data Sent | Processing Location | DPA | In Privacy Policy? |
|---------|-----------|--------------------|----|-------------------|
| Firebase/Google | All user data, analytics, crashes | europe-west1 (claimed) | Yes (EU-USA DPF) | Yes |
| Mistral AI | Recipe text, images, source URLs | **US (default endpoint)** | **No** | **No** |
| Algolia | Recipe metadata, ingredients, user names | **Unknown** | **No** | **No** |

---

## Dimension 7: Children's Data Protection — 2/8

**Summary:** Privacy policy states the app is for 13+ users, but there is no technical age gate. No date of birth collection, no age checkbox during registration, no parental consent mechanism.

### HIGH

**TS-033: No age gate during registration**
- File: `lib/views/auth_view.dart` — registration collects name, email, password only.
- File: `lib/viewmodels/auth_viewmodel.dart:209` — `register()` has no age parameter.
- File: `lib/views/onboarding/onboarding_view.dart` — 4 pages, no age verification.
- Privacy policy states "13+" (Section 12) but enforcement is text-only.
- Impact: Children can register without any barrier. GDPR Article 8 requires consent from parent/guardian for users under 16 (Sweden: 13 minimum, but parental consent required 13-15).
- Fix: Add age confirmation checkbox or date of birth field to registration. Block users who indicate they're under 13. For 13-15, consider parental consent flow.
- Effort: 1-2 days

**TS-034: No mechanism to detect or handle underage users**
- If an underage user is discovered post-registration, there is no admin tool to flag, restrict, or delete their account beyond the standard account deletion flow.
- Impact: No reactive protection for children.
- Fix: Add admin capability to flag underage accounts and trigger deletion.
- Effort: 1 day

### MEDIUM

**TS-035: Social features unrestricted for any user**
- Comments, messaging, friend requests, group participation — all available to any registered user regardless of age.
- Impact: If a child registers, they have full access to social features.
- Fix: If age gate is implemented, restrict social features for users 13-15 or require parental consent for social features.
- Effort: 2-3 days (depends on approach)

### App Store Age Rating

- Age rating is configured in App Store Connect / Google Play Console, not in code.
- With UGC social features (comments, messaging), the minimum appropriate rating is **12+** (Apple) / **Teen** (Google).
- Cannot verify current setting from code.

---

## Dimension 8: Community Guidelines & Spam Prevention — 0/5

**Summary:** No community guidelines exist. Client-side rate limiting exists but is in-memory only (resets on app restart). No server-side rate limiting. No enforcement capability for guideline violations.

### CRITICAL

**TS-036: No community guidelines document**
- Zero references to community guidelines, "riktlinjer", or conduct policies anywhere in codebase.
- Impact: Google Play requires community guidelines for apps with UGC.
- Fix: Create community guidelines in Swedish and English. Cover: harassment, spam, inappropriate content, copyright, impersonation. Add to settings and make accessible from social features.
- Effort: 1-2 days

### HIGH

**TS-037: No server-side rate limiting on UGC**
- Firestore rules have no `request.time`-based rate limiting for comments, messages, or social actions.
- Client-side rate limiter (`lib/core/rate_limiting/rate_limiter.dart`) is in-memory only — resets on app restart, trivially bypassable.
- Impact: A determined spammer can post unlimited comments/messages.
- Fix: Add Firestore security rules with rate limiting (e.g., max 1 comment per 5 seconds per user). Consider Cloud Function rate limiting.
- Effort: 1-2 days

### MEDIUM

**TS-038: No enforcement capability for violations**
- No mechanism to warn, suspend, or ban users. No user reputation system. No admin moderation tools.
- Impact: Even if guidelines exist, there's no way to enforce them.
- Fix: Add `isSuspended` field to user profile, check on login and social actions.
- Effort: 2-3 days

### LOW

**TS-039: Notification spam partially mitigated**
- `firestore.rules` (line ~1208) requires notification sender is either self or a friend of recipient.
- This prevents arbitrary notification spam but doesn't limit volume from friends.

---

## Issue Summary

| Severity | Count | Issues |
|----------|-------|--------|
| **CRITICAL** | 8 | TS-001, TS-002, TS-003, TS-009, TS-010, TS-014/015, TS-016, TS-020/021, TS-026, TS-027, TS-036 |
| **HIGH** | 6 | TS-004, TS-005, TS-006, TS-028, TS-029, TS-033, TS-037 |
| **MEDIUM** | 5 | TS-007, TS-008, TS-024, TS-031, TS-035, TS-038 |
| **LOW** | 3 | TS-025, TS-032, TS-039 |

**Estimated total remediation effort:** 25-35 days (includes legal/business processes for DPAs)
**Code-only remediation:** 15-20 days

---

## Phase 2 Preparation

### Recommended Fix Prioritization (by app store rejection risk)

**Sprint 1 — App Store Blockers (must fix before submission):**
1. Create `PrivacyInfo.xcprivacy` (TS-020, TS-021, TS-022) — 1 day
2. Create Terms of Service document + view (TS-009, TS-012) — 2 days
3. Make auth footer links tappable (TS-011) — 0.5 days
4. Wire report mechanism to Firestore (TS-001, TS-003) — 1 day
5. Extend report to all content types (TS-002) — 2 days
6. Fix block loading on startup (TS-004) — 0.5 days
7. Wire ConsentService to AnalyticsService (TS-014, TS-015, TS-018) — 1 day
8. Defer Crashlytics until consent (TS-016, TS-017) — 1 day
9. Create community guidelines (TS-010, TS-036) — 1 day
10. Add age confirmation to registration (TS-033) — 1 day

**Sprint 2 — Compliance Hardening:**
1. Switch Mistral to EU endpoint (TS-026) — 5 minutes
2. Update privacy policy with all processors (TS-027) — 0.5 days
3. Add server-side Firestore rate limiting (TS-037) — 1 day
4. Block enforcement in Firestore rules (TS-005) — 1 day
5. Add moderation fields to models (TS-007) — 0.5 days
6. Load English privacy policy by locale (TS-013) — 0.5 days
7. Strip PII from Mistral requests (TS-031) — 0.5 days

**Sprint 3 — Business/Legal (parallel):**
1. Execute DPA with Mistral AI (TS-028)
2. Execute DPA with Algolia (TS-029)
3. Verify Algolia region, migrate if needed (TS-030)
4. Verify Firestore region in Console (TS-032)
5. Set correct App Store age rating (12+/Teen)
