# Prompt 09 — Trust, Safety & Advanced Privacy — Phase 1

Analyst: Claude (Opus 4.7, 1M context). Run: 2026-05-claude. Read-only audit.
Knowledge file `firebase-backend-security.knowledge.md` (88 KB) referenced as Step 0; cross-referenced 02-security.md and 06-user-experience.md per orchestrator dedup rules.

---

## Executive Summary

**OVERALL SCORE: 80 / 100 — Good (one structural gap; otherwise mature posture)**

| # | Dimension | Score |
|---|-----------|-------|
| 1 | UGC Moderation System | 19 / 22 |
| 2 | Apple/Google UGC Policy Compliance | 14 / 18 |
| 3 | SDK Consent Sequencing | 9 / 15 |
| 4 | iOS Privacy Manifest | 12 / 12 |
| 5 | ATT Implementation | 10 / 10 |
| 6 | Data Transfer Compliance | 9 / 10 |
| 7 | Children's Data Protection | 4 / 8 |
| 8 | Community Guidelines & Spam | 3 / 5 |
| **Total** | | **80** |

Posture summary. Butlery has a real, mature trust-and-safety surface for a pre-launch app: a `ContentReport` model, a `ReportService` with admin moderation flow, a forward-only state machine in Firestore rules, a `BlockService` with composite-key idempotent blocks, a `ContentFilterService` profanity filter for Swedish + English, an admin-gated `ModeratorReviewView`, a community-guidelines screen, and a full PrivacyInfo.xcprivacy with `NSPrivacyTracking=false` (Apple ATT not required and correctly omitted). Vertex AI in europe-west1 (BUT-614 confirmed) — no third-country data transfer concerns for AI calls; Firebase region = europe-west1 (Belgium, NOT Stockholm despite 41 stale code comments documented in pre-analysis).

The points lost concentrate in three areas:

1. **Initial consent prompt is missing.** New users complete onboarding (Email, UID, name, allergens, photos) without ever being shown a consent screen. ConsentManagementView is reachable from the profile menu post-login, but the user was never solicited to grant or deny analytics / crashlytics / push consent. Default = denied, so no data is leaked, but Article 7(2) "request for consent ... clearly distinguishable" is technically not honoured — the user is asked to accept ToS+Privacy via checkbox but the granular consent purposes are never presented at all. **HIGH** — GDPR Art. 7(2) + Art. 13 transparency.
2. **`app_opened` analytics fires from `_AuthWrapperState.initState()` BEFORE consent gate is bound on the first navigation.** The event is internally gated by `AnalyticsService._hasAnalyticsConsent()` which fails closed if `_consentService` is null. But `setConsentService()` happens via DI module wire-up; if the ChangeNotifier listener attachment races the first `app_opened`, the event silently no-ops (correct). The race is benign by design but undocumented. **LOW** — defensive.
3. **Reports have no `description` length cap or rate limit on Firestore rules.** `ContentReport` accepts any string; the `reports` create rule (firestore.rules:1595) has no `description.size() <= N` guard and no `rateLimitWrite`. A malicious user could spam reports or stuff them with multi-KB text. **MEDIUM**.
4. **Children's-data protection is minimal.** Age gate exists (13 min, GDPR Art. 8 floor for Sweden). No COPPA pathway (US under-13 disallowed). Social features are not restricted for under-13 users beyond the gate refusing them entry. Acceptable for the Swedish-first market but App Store age rating must reflect it. **MEDIUM**.

### Top 5 Trust & Safety Risks

1. **No initial consent prompt** — `ConsentManagementView` is post-login profile-menu only. New user sign-up writes profile data without ever surfacing the granular consent UI. (HIGH)
2. **`reports` collection has no rate limit + no description size cap** — abusive reporting and report-collection storage spam. (MEDIUM)
3. **Pings broadcast read+ack open to any authenticated user (already in 02 MEDIUM-6)** — a stranger can read group-broadcast pings. Cross-references the safety surface; cite, don't re-rank.
4. **Block enforcement is write-side only** — blocked users can still READ public profiles, comments, recipe ratings of users who blocked them. Apple's "ability to block abusive users" requirement is met *functionally* (the blocker stops seeing the blocked user's content) but a determined blocked user retains read access. (LOW — acceptable but worth noting.)
5. **No appeal-process UI** — `appeals@butlery.app` mailto exists in Settings, but Google Play requires an appeal mechanism for content removal. The mailto is a documentation pattern, not a structured appeal flow. (LOW)

### Counts

- CRITICAL: 0
- HIGH: 1
- MEDIUM: 4
- LOW: 5
- Informational / drift: 3

---

## Dimension 1 — UGC Moderation System (19 / 22)

### Capability Matrix

| Capability | Status | Evidence |
|------------|--------|----------|
| Report mechanism (UI) | Implemented | `ReportContentDialog.show` invoked from chat (`chat_action_handler.dart:73`), recipe detail (`recipe_detail_view.dart:534, 672, 738`), friend profile (`friend_profile_view.dart:75, 91`), group detail (`group_detail_actions.dart:46`, `group_detail_app_bar.dart:69, 155`), group member card (`group_member_card.dart:152`). Six UGC contexts covered. |
| Report mechanism (backend) | Implemented | `lib/services/moderation/report_service.dart:30-64` `submitReport()` — typed `ContentType` (recipe / comment / message / cookSnap / group / profile). Forward-only state machine in `firestore.rules:1604-1615` (new → in_review → actioned → closed). |
| Report categorization | Partial | `ContentReport.reason` is a free-form string. There is no enum constraint at the rules level. |
| Block users | Implemented | `lib/repositories/firebase/firebase_block_repository.dart:53` `blockUser()` + composite-key docs `${blockerId}_${blockedId}`. Rules at `firestore.rules:1205-1224` enforce immutability + only-blocker-deletes. Blocked-users management UI at `lib/widgets/common/settings/blocked_users_section.dart`. |
| Block enforcement (writes) | Implemented | `isNotBlockedBy(targetUserId)` rules helper (firestore.rules:160) gates social_requests (482), recipe_comments (936), recipe_ratings (1248), notifications (1291). |
| Block enforcement (reads) | NOT enforced | Blocked users can still read public_profiles, recipes, comments, etc. — knowingly accepted as soft-block (UI hides). |
| Moderation queue (UI) | Implemented | `lib/views/admin/moderator_review_view.dart` admin-gated by `admins/{uid}` doc existence + rules. |
| Moderation actions | Implemented | `ReportService` exposes `advanceReportStatus()`, `closeReport()`, `deleteReportedContent()`, `suspendReportedProfile()` — covers warn-equivalent (advance to in_review), delete content (admin-override rules at firestore.rules:957, 1011, 1085, 1262), profile takedown (`isHidden: true` at public_profiles:462-466). |
| Automated screening | Implemented (client-side only) | `lib/services/moderation/content_filter_service.dart` — Swedish + English profanity word-boundary regex. Used as pre-publish gate via `ensureClean()`. Server-side filtering is deferred. |
| Rate limiting on UGC submits | Mostly implemented | `rateLimitWrite` applied to social_requests (10s), comments (5s), cook_snaps (5s), conversations (10s), messages (5s), recipe_ratings (5s), pings (60s). NOT applied to: `reports`, `feedback` (already in 02 MEDIUM-7). |

### Findings

#### MEDIUM-1.1 — `reports` create rule missing rate limit + no description size cap

- **Severity**: MEDIUM
- **Evidence**: `firestore.rules:1595-1601`. `allow create: if isAuthenticated() && request.resource.data.reporterId == request.auth.uid && hasRequiredFields(...)`. No `rateLimitWrite`. `ContentReport.description` (`lib/models/social/content_report.dart`) accepts arbitrary strings; rules do not validate `description.size() <= N` nor `reason.size() <= N`.
- **Impact**: an authenticated user can spam-create reports against any victim ID (or even random IDs) at SDK throughput. Each report doc costs 1 read for the moderator dashboard query, plus storage. Multi-KB descriptions amplify cost. Worse, a coordinated spam campaign against a target user puts that user's content into the moderator review queue, weaponizing the moderation flow itself.
- **Cite**: knowledge entry `2026-04-25 — store-submission rating defense triad` documents the rate-limit-everything-with-UGC pattern; `reports` slipped through.
- **Remediation**: add `&& rateLimitWrite('reports', 30)` and `&& request.resource.data.get('description', '').size() <= 1000 && request.resource.data.reason.size() <= 100`. Pair with `firestore-rules-tester` cases (forward to that agent — knowledge file says: do NOT write rules tests yourself).
- **Effort**: 1 h.

#### LOW-1.1 — Block is write-side enforcement only; reads are open

- **Severity**: LOW
- **Evidence**: `firestore.rules:160` `isNotBlockedBy` is referenced ONLY in create rules (482, 936, 1248, 1291). No read rule enforces it. A user who has been blocked can still query `public_profiles/{blockerId}`, read their `recipe_comments` (via collectionGroup), see their `recipe_ratings`, etc.
- **Impact**: the blocker gets functional protection (the blocked can't post, can't friend-request, can't ping). But "block" in many users' mental model = "they can't see me" — that promise isn't kept on the read side. Apple's UGC requirement is "the ability to block abusive users" which is met functionally; this is a UX-trust gap, not a policy violation.
- **Remediation (optional)**: scope `public_profiles/{userId}` read to `isAuthenticated() && !isBlockedBy(userId)`. Significant scope change — 1 extra `exists()` per public-profile read multiplies index cost. Could phase-in with a feature flag.
- **Effort**: 4 h (rules change + rules tests + cost analysis).

#### LOW-1.2 — Profanity filter is client-side only

- **Severity**: LOW
- **Evidence**: `content_filter_service.dart:31` doc-comment explicitly says: "Server-side filtering is deferred — this is baseline trust & safety." A determined user with a custom client bypasses `ensureClean()` and writes profanity directly to Firestore.
- **Impact**: surface only — the moderation reporting pipeline picks it up via user reports. For a Swedish-first audience with social-but-not-public-network design, low risk. Apple/Google do NOT require server-side filtering — they require the *ability to filter*, which the client filter satisfies for the 99% case.
- **Remediation (optional)**: re-implement the same word list in a Cloud Function `onCreate` trigger for comments/messages/cook_snaps/recipes. Or rely on the existing report flow as the safety net (current posture).
- **Effort**: 6 h (CF + tests + word-list propagation).

### Score: 19/22

Lost 3 points: -1 reports rate limit gap, -1 read-side block enforcement, -1 server-side profanity.

---

## Dimension 2 — Apple/Google UGC Policy Compliance (14 / 18)

### Apple App Store Review Guideline 1.2

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Method to filter objectionable material | Pass | `ContentFilterService.ensureClean()` pre-publish gate. |
| Mechanism to report offensive content | Pass | `ReportContentDialog.show` from 6 UGC contexts (see Dimension 1 matrix). |
| Ability to block abusive users | Pass (functional) | `BlockService` + UI; write-side enforcement only (LOW-1.1). |
| Published contact information | Partial | `appeals@butlery.app` mailto in Settings (`settings_hub_view.dart:117`). No dedicated abuse-report email distinct from appeals. |
| Prominently stated Terms of Service | Pass | ToS link in `auth_view.dart:524` (signup footer, accessible without login), `settings_hub_view.dart:73`, sign-up checkbox required (`auth_view.dart:351-374`). |

### Google Play Developer Policy (UGC)

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Content moderation system | Pass | `ReportService` + `ModeratorReviewView` + admin override rules. |
| User reporting mechanism | Pass | Same as Apple. |
| Content removal capability | Pass | `ReportService.deleteReportedContent()` + admin-override rules at firestore.rules:957, 1011, 1085, 1262. Profile suspension via `suspendReportedProfile()`. |
| Terms of use / community guidelines displayed in app | Partial | ToS in Settings + auth view. Community guidelines reachable ONLY from `account_security_view.dart:371` — buried 2 levels deep in Settings → Account Security. Not surfaced at signup. |
| Appeal process | Partial | `appeals@butlery.app` mailto in Settings (`settings_hub_view.dart:79`). No structured in-app appeal flow. |

### Findings

#### MEDIUM-2.1 — Privacy Policy not linked from Settings hub

- **Severity**: MEDIUM
- **Evidence**: `lib/views/settings/settings_hub_view.dart:65-95` — "About" section lists FAQ, Terms of Service, Appeal email, Moderator Review (admin-only). Privacy Policy is NOT listed. The route exists (`Routes.privacyPolicy`), the view exists (`lib/views/legal/privacy_policy_view.dart`), and it IS surfaced in the auth view footer (`auth_view.dart:543`) — but post-login, a user looking for "where do I read what data Butlery collects" will not find it in Settings.
- **Impact**: GDPR Art. 13 + 14 transparency requires the privacy notice to remain accessible *throughout* the data-processing relationship, not just at signup. Apple App Store requires privacy policy "easily accessible". The Auth view exposure satisfies the signup gate; the Settings absence is the post-login gap.
- **Cite**: this is a UX accessibility gap, not a security failure. Defers to 06 UX for app-store-metadata implications, but the gap itself is mine.
- **Remediation**: add a `_SettingsTile` for `legalPrivacyPolicy` in the About section of `settings_hub_view.dart` (between ToS and Appeal email). 5 min.
- **Effort**: 15 min.

#### MEDIUM-2.2 — Community Guidelines link buried, not surfaced at signup

- **Severity**: MEDIUM
- **Evidence**: `account_security_view.dart:371` is the ONLY entry point. Settings → Account Security → Community Guidelines = 2 levels deep. New users at signup see ToS + Privacy Policy in `auth_view.dart` but NOT community guidelines.
- **Impact**: Google Play UGC policy explicitly requires "Terms of use / community guidelines displayed in app". Compliant *barely* (the screen exists), but operationally hidden. App Store doesn't require community guidelines as a separate doc but does require ToS coverage of community standards — unclear whether the Butlery ToS embeds them.
- **Remediation**: add Community Guidelines tile to `settings_hub_view.dart` About section AND add a link in the auth view footer alongside ToS + Privacy.
- **Effort**: 30 min.

#### LOW-2.1 — Abuse-contact email is generic `appeals@butlery.app`

- **Severity**: LOW
- **Evidence**: `settings_hub_view.dart:117` — single mailto destination for both appeals AND abuse reports. Apple's "published contact information for reporting concerns" is met by mailto, but conflating two flows (user appealing their own moderated content vs. user reporting another user's offensive content) could degrade response triage.
- **Remediation**: split into `appeals@butlery.app` (existing) and `safety@butlery.app` (new), or rely on the in-app `ReportContentDialog` for abuse reports (which already exists) and document that mailto is appeals-only.
- **Effort**: 30 min (if added) or 0 (if documenting current intent is sufficient).

#### LOW-2.2 — No structured appeal flow

- **Severity**: LOW
- **Evidence**: `settings_hub_view.dart:114-127` — `_launchAppealEmail()` opens a mailto with subject + body template. Google Play requires "appeal process" — mailto is acceptable but not great UX. There is no in-app appeal-status tracking, no appeal-history view, no structured form.
- **Remediation**: post-launch, add an `appeals` Firestore collection mirroring `reports` with reverse direction (user → admin). Out of scope for pre-launch pre-monetization — note for backlog.
- **Effort**: 8 h (collection + rules + service + view).

### Score: 14/18

Lost 4 points: -1 privacy policy in settings, -1 community guidelines surfacing, -1 abuse-contact distinction, -1 structured appeal flow.

---

## Dimension 3 — SDK Consent Sequencing (9 / 15)

### Initialization Timeline (from `lib/main.dart`)

| Step | Action | Consent-gated? | File:line |
|------|--------|----------------|-----------|
| 1 | `WidgetsFlutterBinding.ensureInitialized()` | N/A | main.dart:132 |
| 2 | `Firebase.initializeApp(...)` | N/A (security primitive) | main.dart:165-167 |
| 3 | Firestore settings (persistence + cache) | N/A | main.dart:172-175 |
| 4 | `FirebaseCrashlytics.setCrashlyticsCollectionEnabled(false)` | DEFAULT-DENIED | main.dart:212 |
| 5 | `FirebaseAppCheck.activate(...)` | N/A (security, not analytics) | main.dart:213-223 |
| 6 | `_initializeModularSystem()` (DI + bootstrap stages) | mostly DI registration | main.dart:242 |
| 7 | `FirebasePerformance.setPerformanceCollectionEnabled(false)` | DEFAULT-DENIED | main.dart:288 |
| 8 | Bootstrap stages execute (Platform → Core → Content → Social → UI) | per-stage | main.dart:292 |
| 9 | `_enableCollectionIfConsented()` — checks `hasAnalyticsConsent` and re-enables Crashlytics + Performance + Analytics if granted | YES | main.dart:295, 305-358 |
| 10 | `runApp(ButleryApp())` | post-consent-check | main.dart:244 |
| 11 | `_AuthWrapperState.initState()` → `_trackAppOpened()` fires `app_opened` | YES (gated inside AnalyticsService) | main.dart:447, 703-721 |
| 12 | `MessagingModule` initializes `NotificationService` → `FCMService.initialize(consentService:...)` | YES (gates permission request + token registration on `_hasPushConsent()`) | messaging_module.dart:209, fcm_service.dart:134-143 |
| 13 | User opens consent screen via Profile menu (or never) | terminal — they may never grant | gdpr_consent_handler.dart:41-74 |

### Findings

#### HIGH-3.1 — No initial consent prompt; user is never solicited for granular consent

- **Severity**: HIGH (GDPR Art. 7(2) + Art. 13)
- **Evidence**:
  - `lib/views/onboarding/` — 6 onboarding pages (welcome, age gate, allergens, dietary, import, etc.). Zero consent UI. Confirmed via `Grep "consent"` against the directory: zero matches.
  - `lib/main.dart:1011` — `_AuthWrapperState.build()` flows: auth → email verification gate → onboarding gate → main app. No consent step.
  - `lib/widgets/common/profile/handlers/gdpr_consent_handler.dart:41` — `handleManageConsent()` is invoked from the profile menu (post-login).
  - Default consent is denied (`main.dart:288, 212`), so technically no data leaks. But Article 7(2) requires consent to be "an active demonstration of agreement", typically a prompt the user actually sees. The user agrees to ToS+Privacy via checkbox but is never presented with the granular per-purpose consent (analytics / crashlytics / performance / push / personalisation / marketing / cookSnaps).
- **Impact**: a user could use Butlery for months never having seen the consent screen. They will receive Apple's iOS push permission prompt (gated by FCM consent), but never the GDPR analytics consent. From a regulator's perspective: the legal basis for processing analytics is missing entirely (consent denied → no processing → fine, but the user was never *asked*). From an Article 13 perspective: the "purposes of the processing" must be communicated *at the time data is obtained* — by the time user signs up, profile data is being processed under contract (Art. 6(1)(b)), but the meta-question "what *additional* purposes can I opt into?" is never put to them.
- **Cite**: knowledge entry `2026-05-02 — FCM consent-revoke gap closed (BUT-754, M1 of BUT-573 follow-up)` documents the consent-change path but assumes consent was granted somewhere. The "somewhere" is Profile → Manage Consent — which the user must actively discover.
- **Remediation**: add a consent step to onboarding (between welcome and age gate, or after age gate before allergen step). Show the four to seven purposes as toggleable opt-ins, default OFF, with "deny all" + "accept all" + per-purpose. Persist via existing `ConsentService.grantConsent` API. Re-render the screen any time the user updates app version with new consent purposes (the `consent_version` mechanism already exists — knowledge BUT-356).
- **Effort**: 8 h (new onboarding page + ConsentViewModel reuse + analytics events + tests).

#### LOW-3.1 — `app_opened` fires before consent listener may be attached

- **Severity**: LOW (defensive)
- **Evidence**:
  - `lib/main.dart:447` — `initState()` calls `_trackAppOpened()` synchronously.
  - `lib/main.dart:711-720` — invokes `analyticsService.logEvent(name: 'app_opened', ...)`.
  - `lib/services/analytics_service.dart:138, 154, 162, 213` — every `logEvent` is gated by `_hasAnalyticsConsent()` which calls `ConsentService.checkSafely(_consentService, ...)` — fails closed if `_consentService == null`.
  - `analytics_service.dart:66-73` — `setConsentService()` is the wire-up point. Called by DI module after bootstrap. Race: bootstrap might wire ConsentService into AnalyticsService AFTER `_trackAppOpened` runs.
- **Impact**: NONE in practice — the fail-closed gate at `_hasAnalyticsConsent` returns false when `_consentService == null`. The event is silently dropped. No data leak. But the architectural implication is: any future analytics-call added to a `runApp`-time path must respect this race. Worth a doc comment.
- **Remediation**: add a doc comment to `AnalyticsService.logEvent` describing the fail-closed-on-null-consent contract; OR attach the consent service synchronously during bootstrap stage 1 instead of via a setter. Current behaviour is correct; this is hardening.
- **Effort**: 30 min (doc comment).

#### LOW-3.2 — Algolia consent gate timing not verified at this layer

- **Severity**: LOW
- **Evidence**: knowledge entry `2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)` says Algolia analytics events are gated; `lib/core/di/modules/search_module.dart:160-161` instantiates Algolia with key + ID at module-init time. The Algolia client itself (the `algoliasearch` package) initializes on first query, not on construction. No SDK data is sent until a search happens.
- **Impact**: Acceptable. Search is user-initiated; the user actively triggers the search after authentication. No race to flag.
- **Remediation**: none. Reading the knowledge file's BUT-752 entry confirms `ConsentService.addListener` is the correct pattern.

### Score: 9/15

Lost 6 points: -5 missing initial consent prompt (HIGH structural gap), -1 doc gap on race semantics.

---

## Dimension 4 — iOS Privacy Manifest (12 / 12)

`ios/Runner/PrivacyInfo.xcprivacy` exists and is exemplary. 236 lines, last audited 2026-04-24 (BUT-568), evidence trail tracked at `docs/ops/ios-privacy-manifest-audit.md`.

### Required-Reason API Coverage

| Category | Reason code | Justification | Status |
|----------|-------------|---------------|--------|
| `NSPrivacyAccessedAPICategoryUserDefaults` | CA92.1 | Defensive (shared_preferences ships its own; first-party Flutter plugins occasionally read defaults) | Declared |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | C617.1, 3B52.1 | image_picker EXIF + cached_network_image LRU | Declared |
| `NSPrivacyAccessedAPICategoryDiskSpace` | E174.1 | Firestore on-device cache GC + Crashlytics | Declared |
| `NSPrivacyAccessedAPICategorySystemBootTime` | 35F9.1 | Firebase Performance + Analytics session timing | Declared |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | — | Not used (no IME inspection) | Correctly absent |

### Tracking Declaration

- `NSPrivacyTracking` = `false` (line 14)
- `NSPrivacyTrackingDomains` = empty array (lines 15-16)
- Consistent with: no Facebook SDK, no advertising SDK, no IDFA usage anywhere in codebase, Firebase Analytics in default mode (no Google Ads linkage).

### Collected Data Types

Nine declared data types, each correctly tagged:
- Email Address (linked, app functionality)
- Name (linked, app functionality)
- User ID (linked, app functionality) — added in BUT-603
- Photos (linked, app functionality)
- Other User Content (linked, app functionality)
- Product Interaction (linked, analytics — consent-gated)
- Crash Data (NOT linked, app functionality)
- Performance Data (NOT linked, app functionality)
- Device ID (linked, app functionality) — Firebase Installations + FCM

All `NSPrivacyCollectedDataTypeTracking = false` — consistent with no cross-app tracking.

### Findings

No findings. Privacy manifest is complete, correct, well-commented, and audited. Knowledge entry `2026-04-24 (sprint BUT-568)` matches the file's documented last-audit date.

### Score: 12/12

---

## Dimension 5 — ATT Implementation (10 / 10)

ATT is **not required** for Butlery and is correctly absent.

### Determination

- App does NOT track users across other companies' apps/websites.
- No Facebook SDK, no advertising SDK, no IDFA access anywhere in codebase (verified by absence of `app_tracking_transparency` in pubspec, `NSUserTrackingUsageDescription` absent from Info.plist).
- Firebase Analytics in default mode (no Google Ads link in `firebase_options.dart` or anywhere else).
- `NSPrivacyTracking = false` declared.

### Score: 10/10

ATT-not-needed determination is correct. Implementation gap = 0.

---

## Dimension 6 — Data Transfer Compliance (9 / 10)

### Third-Party Data Processor Inventory

| Service | Data Sent | Processing Location | DPA / Mechanism |
|---------|-----------|---------------------|-----------------|
| Firebase / Google (Auth, Firestore, Storage, FCM, App Check, Analytics, Crashlytics, Performance) | All user data | europe-west1 (Belgium) — confirmed via `functions/src/index.ts` `setGlobalOptions({region: "europe-west1"})` (BUT-647) | Google's standard DPA + EU SCCs |
| Vertex AI Gemini (recipe extraction, ingredient parsing) | Recipe text + images during structure-recipe + ocr-recipe-image | europe-west1 (`functions/src/llm/gemini-client.ts:28` `VERTEX_LOCATION = "europe-west1"` — BUT-614 migration from US-egress Google AI Studio) | Same as Firebase (Google sub-processor) |
| Algolia (recipe search index) | Recipe titles + ingredients | EU cluster (knowledge BUT-580 verified at construction time in `search_module.dart`) | Algolia EU DPA |
| OCR.space (fallback OCR provider) | Recipe images | Per provider's TOS — appears to be US/EU mixed | Unknown — see 02 HIGH-1 (key extractable) |
| Google Vision (fallback OCR provider) | Recipe images | Google data centers; routing per Google's DPA | Google DPA |
| reCAPTCHA v3 (web App Check) | User device fingerprint | Google US/EU mixed | Google DPA |

Firebase Cloud Functions all pinned to europe-west1 per knowledge entry `2026-04-30 — server-side notification gate review patterns (BUT-647 / BUT-645 / BUT-638)` — region-pin verification: removing this line silently flips functions to `us-central1`. Currently correct.

### Findings

#### LOW-6.1 — OCR.space data flow undocumented

- **Severity**: LOW
- **Evidence**: `lib/services/ocr_extraction_service.dart:227` uses `OCR_SPACE_API_KEY` (compile-time). The provider's data-processing location is not pinned to EU in code or config. Per OCR.space's privacy policy (out of scope for this audit, but worth noting), recipes uploaded via this fallback may be processed in US.
- **Impact**: GDPR Chapter V — third-country transfer requires either an adequacy decision or SCCs. If OCR.space processes in US, the transfer mechanism is undocumented in the codebase and likely undocumented in privacy policy.
- **Cite**: 02 HIGH-1 already flagged this from the key-extraction angle. Adding the data-flow angle here.
- **Remediation**: in conjunction with 02's remediation (move keys to Cloud Function callable), pin the OCR provider chain to EU-only providers OR document the data flow in privacy policy + DPA inventory. The migration to a server-side proxy lets you log + control which provider receives each image.
- **Effort**: covered by 02 HIGH-1 effort estimate.

### Score: 9/10

Lost 1 point: OCR.space data residency unverified.

---

## Dimension 7 — Children's Data Protection (4 / 8)

### Age Verification

- Age gate at signup: `lib/views/onboarding/onboarding_age_gate_page.dart` — verified.
- Minimum age: 13 (Sweden's GDPR Article 8 floor — Sweden chose the lower 13 vs. EU default 16).
- Enforcement: `firestore.rules:371-384` enforces `birthYear <= request.time.year() - 13` on the preferences sub-document.
- Model validation: `lib/models/user_profile.dart:91` throws if `birthYear < 1900 || birthYear > currentYear - 13`.
- "Blocked" path: `lib/views/onboarding/onboarding_age_gate_blocked_view.dart` — exists.

### Findings

#### MEDIUM-7.1 — Age gate is self-attestation only

- **Severity**: MEDIUM
- **Evidence**: `lib/viewmodels/onboarding_viewmodel.dart:181` — onboarding writes whatever year the user picks. No verification, no parental consent flow, no fallback for users who claim under-13.
- **Impact**: standard for consumer apps and acceptable under Article 8 (the regulator does NOT require id verification for age — self-attestation is the norm). Apple/Google age-rating questionnaires accept self-attestation. The risk is COPPA: Butlery is targeting Swedish-first market but is global on the App Store. A US under-13 child who self-attests as 13+ enters a system with social features. COPPA requires "actual knowledge" of under-13 users; Butlery has no such knowledge by design.
- **Cite**: out-of-scope for the GDPR-only ConsentService that 02 audits; this is about the age-gate triangulation.
- **Remediation (optional)**: in onboarding age gate, add a "if you're under 13, please ask a parent..." disclaimer screen as an additional friction step. This is what most consumer apps do.
- **Effort**: 1 h.

#### MEDIUM-7.2 — Social features not restricted for younger users

- **Severity**: MEDIUM (App Store rating implication)
- **Evidence**: a 13-year-old user passes age gate and then has full access to friends, sharing, comments, ratings, groups, messaging. No age-tiered feature restriction.
- **Impact**: Apple App Store rating questionnaire asks about user-generated content + unrestricted web access + social features. With UGC + social + chat, the rating likely lands at 12+ minimum. If targeting 13+ (Swedish GDPR floor), the rating questionnaire MUST reflect "yes" for: user-generated content, mature themes (UGC can include profanity until filtered), unrestricted access (no parental controls). 4+ rating would be misleading.
- **Cite**: 06 UX has the app-store-metadata ownership; this is the *substantive* basis for whatever rating is declared.
- **Remediation**: confirm with 06 that the planned App Store age rating is 12+ minimum (likely 17+ given UGC + chat). Document the questionnaire answers in `docs/ops/app-store-rating-justification.md`.
- **Effort**: 30 min (documentation).

#### LOW-7.1 — No "report a child user" pathway

- **Severity**: LOW
- **Evidence**: `ContentReport.contentType` enum (recipe / comment / message / cookSnap / group / profile) — there's no specific "underage user" category. A user concerned that someone is under-13 (e.g. messaging in groups about being in 7th grade) has to use the generic "profile" report. Admins handling reports have no triage flag.
- **Remediation**: add a `ContentReport.reason` constant `under_minimum_age` with explicit handling in the moderator view (priority queue, suspend pending verification). 2 h.
- **Effort**: 2 h.

### Score: 4/8

Lost 4 points: -2 self-attestation only (acceptable but worth flagging), -2 social features unrestricted for 13-year-olds (rating questionnaire implication for 06).

---

## Dimension 8 — Community Guidelines & Spam (3 / 5)

### Community Guidelines

- Document exists: `assets/legal/community_guidelines_sv.md` + `_en.md` (loaded by `community_guidelines_view.dart:38, 45`).
- Translated: yes (Swedish + English).
- Reachable from app: yes, but buried (Settings → Account Security → Community Guidelines = 2 levels deep; not in main Settings hub; not in auth view).
- Referenced in ToS: not verified at this audit (defer to 11 Legal Review for ToS-doc accuracy).

### Spam Prevention

- Comments: 5s rate limit (firestore.rules:938) — adequate.
- Cook snaps: 5s (1000) — adequate.
- Messages: 5s (1073) — adequate.
- Pings: 60s (847) — generous, prevents notification spam.
- Friend requests: 10s (483) — adequate.
- Recipe ratings: 5s (1250) — adequate.
- Reports: NO rate limit (see MEDIUM-1.1).
- New-account restriction period: NONE — a fresh account can immediately rate-limit-write at the per-collection rate.
- Duplicate-content detection: NONE — same comment / message can be posted as fast as the rate limit allows.

### Findings

#### MEDIUM-8.1 — No new-account rate-limit grace period (sock-puppet risk)

- **Severity**: MEDIUM
- **Evidence**: a brand-new account can write to comments / messages / ratings within seconds of email-verification. No `request.time - userCreationTime > duration` gate.
- **Impact**: a malicious actor creates 5 sock-puppet accounts to mass-rate a recipe 1-star or to spam-comment. Each account is its own rate-limit bucket.
- **Remediation**: add `request.time > resource.data.userCreatedAt + duration.value(60, 's')` to UGC create rules (where `userCreatedAt` is mirrored from user profile via denormalisation). Or use a CF-level new-account gate. Cost: an extra `get(...)` per write into `users/{uid}/preferences` to read `creationTime` — borderline acceptable.
- **Effort**: 4 h (rules + denormalization or CF + tests).

#### LOW-8.1 — No duplicate-content detection

- **Severity**: LOW
- **Evidence**: same comment text can be posted 12 times per minute (rate-limited). No "last 5 comments by same user, all identical" check.
- **Remediation**: client-side check in `recipe_comments_viewmodel`; rules-level enforcement is hard (rules can't query historical writes). Acceptable as-is for pre-launch.
- **Effort**: 2 h (client-side).

### Score: 3/5

Lost 2 points: -1 community guidelines surfacing (already in 2.2 above; counted here too as a guideline-discoverability issue), -1 sock-puppet new-account window.

---

## App Store Compliance Dashboard

| Requirement | Apple | Google | Status | File:line |
|-------------|-------|--------|--------|-----------|
| Content filtering (UGC) | Required | Required | Implemented (client-side) | content_filter_service.dart |
| Report mechanism | Required | Required | Implemented | report_service.dart + 6 UI sites |
| Block users | Required | Required | Implemented (write-side enforcement) | firebase_block_repository.dart, firestore.rules:1205 |
| Contact info for abuse | Required | — | Partial (mailto only) | settings_hub_view.dart:117 |
| Terms of Service in-app | Required | Required | Implemented | terms_of_service_view.dart, auth_view.dart, settings_hub_view.dart:73 |
| Community guidelines in-app | — | Required | Implemented but buried | community_guidelines_view.dart, account_security_view.dart:371 |
| Content removal capability | Required | Required | Implemented (admin override) | report_service.dart, firestore.rules admin overrides |
| Appeal process | — | Required | Partial (mailto only) | settings_hub_view.dart:79, 117 |
| Privacy manifest (iOS) | Required | — | Complete | ios/Runner/PrivacyInfo.xcprivacy |
| Privacy nutrition labels | Required | — | Aligned (NSPrivacyCollectedDataTypes match Firebase scope) | PrivacyInfo.xcprivacy:99-234 |
| Data safety section (Play) | — | Required | Defer to 06 (app-store-metadata owns) | n/a |
| ATT prompt | Conditional | — | Not required, correctly absent | NSPrivacyTracking=false |
| Age rating accuracy | Required | Required | Defer to 06 (questionnaire ownership) — but 13+ minimum given UGC+chat | n/a |

---

## Risk Matrix

```
                     Likelihood
                     Low                Medium                High
Impact:
Critical                                                     —
High                                    HIGH-3.1             —
Medium               MEDIUM-7.1/7.2     MEDIUM-1.1/8.1       MEDIUM-2.1/2.2
Low                  LOW-1.1/1.2/3.1    LOW-2.1/2.2/3.2/6.1  LOW-7.1/8.1
```

Concentration is mid-band. Single HIGH (consent-prompt absence) is structural and one well-bounded sprint to fix.

---

## Knowledge-File Patterns Cited

- `2026-04-25 — initial seed` — repository contract; PermissionValidationMixin transitive adoption.
- `2026-04-25 — store-submission rating defense triad` — UGC moderation pattern; `reports` rate-limit gap below this baseline.
- `2026-04-26 — admin-delete rules tracking` — moderator override coverage matrix.
- `2026-04-26 — BUT-728 closes the moderation coverage matrix` — cook_snap rule shape reference.
- `2026-04-30 — server-side notification gate review patterns (BUT-647 / BUT-645 / BUT-638)` — region-pin verification.
- `2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)` — Algolia EU residency.
- `2026-05-02 — FCM consent-revoke gap closed (BUT-754)` — consent-revoke runtime path; cited HIGH-3.1.

---

## Phase 2 Preparation

### Issue counts

| Severity | Count | Estimated total effort |
|----------|-------|-------------------------|
| CRITICAL | 0 | — |
| HIGH | 1 | 8 h |
| MEDIUM | 4 | ~7.5 h (1+0.5+1+4+2) |
| LOW | 5 | ~10 h |
| **Total** | **10** | **~25 h** |

### Recommended sprint grouping

**Sprint 1 — Compliance + Quick wins (1 week):**
- HIGH-3.1: Add initial consent prompt to onboarding (8 h) — biggest GDPR + transparency win.
- MEDIUM-1.1: Add rate limit + size cap to `reports` rule (1 h) — pair with `firestore-rules-tester` agent per CLAUDE.md.
- MEDIUM-2.1: Add Privacy Policy tile to Settings hub (15 min).
- MEDIUM-2.2: Surface Community Guidelines in main Settings + auth footer (30 min).
- MEDIUM-7.2: Document App Store age-rating questionnaire answers (30 min).

**Sprint 2 — UGC + Spam hardening (1 week):**
- MEDIUM-8.1: New-account rate-limit grace period (4 h).
- MEDIUM-7.1: Under-13 disclaimer screen (1 h).
- LOW-2.1: Split appeals vs. safety mailto (30 min).
- LOW-7.1: Add `under_minimum_age` report reason category (2 h).

**Sprint 3 — Backlog (post-launch):**
- LOW-1.1: Read-side block enforcement (4 h, requires cost analysis).
- LOW-1.2: Server-side profanity CF (6 h).
- LOW-2.2: Structured appeal flow (8 h).
- LOW-3.1: Doc consent-listener race semantics (30 min).
- LOW-8.1: Client-side duplicate-content detection (2 h).

---

## Phase 1 Success Criteria

| Criterion | Met? |
|-----------|------|
| All 8 dimensions investigated and scored | Y |
| UGC moderation capability matrix | Y |
| Apple UGC compliance checklist | Y |
| Google Play UGC compliance checklist | Y |
| Content type moderation coverage | Y |
| Legal page accessibility assessment | Y |
| App store rejection risk rating | Y (LOW — UGC infrastructure mostly complete; legal-page surfacing gap is fixable in <1 h) |
| SDK initialization timeline vs consent | Y |
| Per-SDK consent gating assessment | Y |
| Privacy manifest existence + completeness | Y (perfect) |
| Required Reason API coverage matrix | Y |
| ATT requirement determination | Y (not required) |
| Data processor inventory with transfer mechanisms | Y |
| Children's data protection assessment | Y |
| Community guidelines existence + spam prevention | Y |
| Issue file:line references | Y |
| Effort estimates per finding | Y |
| Zero code changes | Y |

---

## Appendix — Files Cited (absolute paths)

- C:\Butlery\butlery\lib\main.dart
- C:\Butlery\butlery\lib\core\bootstrap\stages\platform_stage.dart
- C:\Butlery\butlery\lib\core\bootstrap\stages\core_stage.dart
- C:\Butlery\butlery\lib\services\analytics_service.dart
- C:\Butlery\butlery\lib\services\notifications\notification_service.dart
- C:\Butlery\butlery\lib\services\notifications\fcm_service.dart
- C:\Butlery\butlery\lib\services\moderation\report_service.dart
- C:\Butlery\butlery\lib\services\moderation\content_filter_service.dart
- C:\Butlery\butlery\lib\services\unified\operations\friends_management_operations.dart
- C:\Butlery\butlery\lib\repositories\firebase\firebase_block_repository.dart
- C:\Butlery\butlery\lib\widgets\common\profile\handlers\gdpr_consent_handler.dart
- C:\Butlery\butlery\lib\widgets\common\settings\blocked_users_section.dart
- C:\Butlery\butlery\lib\views\auth_view.dart
- C:\Butlery\butlery\lib\views\admin\moderator_review_view.dart
- C:\Butlery\butlery\lib\views\settings\settings_hub_view.dart
- C:\Butlery\butlery\lib\views\settings\account_security_view.dart
- C:\Butlery\butlery\lib\views\legal\community_guidelines_view.dart
- C:\Butlery\butlery\lib\views\legal\privacy_policy_view.dart
- C:\Butlery\butlery\lib\views\legal\terms_of_service_view.dart
- C:\Butlery\butlery\lib\views\onboarding\onboarding_age_gate_page.dart
- C:\Butlery\butlery\lib\views\onboarding\onboarding_age_gate_blocked_view.dart
- C:\Butlery\butlery\lib\models\user_profile.dart
- C:\Butlery\butlery\lib\models\social\content_report.dart
- C:\Butlery\butlery\lib\viewmodels\onboarding_viewmodel.dart
- C:\Butlery\butlery\firestore.rules
- C:\Butlery\butlery\functions\src\llm\gemini-client.ts
- C:\Butlery\butlery\functions\src\index.ts
- C:\Butlery\butlery\ios\Runner\Info.plist
- C:\Butlery\butlery\ios\Runner\PrivacyInfo.xcprivacy
- C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\02-security.md (cross-reference)
- C:\Butlery\butlery\docs\analysis\runs\2026-05-codex\_pre-analysis\SUMMARY.md
- C:\Butlery\butlery\.claude\agents\firebase-backend-security.knowledge.md

---

End of Phase 1.
