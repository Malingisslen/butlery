# Prompt 09 — Trust, Safety & Advanced Privacy — Phase 1 (Deep Run)

Analyst: Claude (Opus 4.7, 1M context). Run: `2026-05-claude-deep`. Read-only audit.
Step 0 — knowledge files consumed: `firebase-backend-security.knowledge.md` (88 KB / 2235 lines, sampled in chunks 1-500, 500-1100, 2100-end), `cloud-functions-specialist.knowledge.md` (full read).

This run is intentionally adversarial against the prior `2026-05-claude/09-trust-safety-privacy.md`: I re-walked the same surfaces, looked harder at what the prior run *missed* (per orchestrator instructions: 30%+ on missing items), and verified knowledge-file claims against live code rather than restating them.

---

## Executive Summary

**OVERALL SCORE: 71 / 100 — Good but with one shipped-rule footgun, one structural consent gap, and four invariants that have never been encoded.**

| # | Dimension | Score | Δ vs. prior |
|---|-----------|------:|------------:|
| 1 | UGC Moderation System | 17 / 22 | -2 |
| 2 | Apple/Google UGC Policy Compliance | 12 / 18 | -2 |
| 3 | SDK Consent Sequencing | 7 / 15 | -2 |
| 4 | iOS Privacy Manifest | 11 / 12 | -1 |
| 5 | ATT Implementation | 10 / 10 | 0 |
| 6 | Data Transfer Compliance | 8 / 10 | -1 |
| 7 | Children's Data Protection | 3 / 8 | -1 |
| 8 | Community Guidelines & Spam | 3 / 5 | 0 |
| **Total** | | **71** | **-9** |

The prior run scored 80; I scored 71 because three issues were under-rated and two "perfect" subscores hid real gaps. Concretely:

1. **Onboarding completes WITHOUT consent UI AND WITHOUT a privacy/ToS checkbox.** Prior run said the user "agrees to ToS+Privacy via checkbox" — `lib/views/onboarding/onboarding_view.dart:99-105` shows the page list (`AgeGate → Welcome → Allergen → Dietary → Import`) — no consent step, no ToS-acceptance step, no privacy-policy gate inside the wizard. The ToS checkbox lives in `lib/views/auth_view.dart` (signup-only); a user who arrives via a deep link, social-recovery, or the email-verification re-entry path may complete onboarding without ever seeing the ToS signup checkbox either. (HIGH structural gap.)
2. **`reports` collection has zero size cap on description AND zero rate limit AND no enum constraint on `contentType`.** Prior run flagged the rate limit + size cap; missed that the create rule (`firestore.rules:1596-1599`) does NOT validate `contentType in [...]` either. A reporter can fabricate `contentType: "underage_user_collected_via_data_broker"` and bypass moderator triage assumptions. (MEDIUM).
3. **Hash-linked Firebase Auth UID is `Tracking=false` per `PrivacyInfo.xcprivacy:139` BUT** the salted-SHA256 `userId` hash sent in **every** consent-gated analytics event (`firebase_analytics_repository.dart:31-44`) is sent with **per-install salt** — so it cannot join across users, but it IS a stable per-user pseudonym that survives logout-login on the same install. Apple's tracking definition includes "linking user data with third-party data" — Firebase Analytics → Google's BigQuery linkage IS that join. The `Tracking=false` declaration relies on the consent gate; if HIGH-3.1 fires (consent never collected → user manually navigates to Settings → grants consent), the gate behaves correctly. But the manifest's claim is not "no tracking happens"; it is "no tracking happens when SDKs respect their gates". This is fragile. (LOW manifest-veracity).
4. **Vertex AI is europe-west1 (`gemini-client.ts:28`); reCAPTCHA Enterprise via App Check (`main.dart:213-216`) sends user device fingerprint + browser data to Google US/EU mixed datacenters with no documented EEA-only routing.** Prior run did not call out reCAPTCHA's transfer mechanism. (LOW Art. 44 documentation gap.)

### Top 5 trust & safety risks (re-ranked)

1. **HIGH-1 — Onboarding ships zero consent UI; user accepts no granular consent.** Closes Art. 7(2) and Art. 13 transparency only retroactively, post-login, via Profile → Manage Consent — the user must actively discover it.
2. **HIGH-2 — `reports` rule + UI lets a malicious actor weaponise the moderator queue.** No rate limit (1596-1599), no description cap, no contentType enum, no `reporterId == authorId` self-report block. A coordinated 100-account brigade can flood the queue against a target user, forcing the moderator to triage hundreds of fabricated reports before noticing.
3. **MEDIUM-1 — `account_deletion_service.dart` does NOT cascade to `reports/`.** Prior run missed this. The `tier1` map (line 163-195) deletes content owned by the user, but reports the user FILED against others (`reporterId == userId`) live forever. If `_socialOps.deleteUserReports(userId)` (line 181) is implemented as a generic `where('reporterId', '==', userId)` purge, that's correct — but the **content** the user reported (now-stale `contentOwnerId` references) lingers, and reports filed AGAINST the user (`contentOwnerId == userId`) also linger because the cascade key is on the wrong field. The latter is the GDPR Art. 17 erasure failure: the deleted user's `userId` persists in other people's report records.
4. **MEDIUM-2 — Unknown-route admin moderation gap on `cook_snap`/`profile`/`shopping_list`.** Per knowledge BUT-728 fix entry the gaps were closed for `cook_snap` and `profile`. Live verification: `report_service.dart:218-256` `_resolveContentRef` returns null for `ContentType.profile` (line 252-254) — admin **cannot delete a profile via report** (`suspendReportedProfile` is a hide-only). For `cookSnap` (line 238-241) → `cook_snaps/{id}` directly. For `recipe`, the comment says "users/{ownerId}/recipes" — correct. But the enum doesn't include `shopping_list` or `rating` (compare to `content_report.dart` model comment). If a reporter submits a `rating` report from the dialog, the resolver returns null, moderator clicks "delete content", returns false, no audit trail — the abusive rating stays. (MEDIUM knowledge-vs-code drift.)
5. **MEDIUM-3 — Profanity filter is local-pattern only AND maps a Swedish word ("blansen") that has no Wikipedia or general-Swedish-dictionary entry.** `content_filter_service.dart:106` — "blansen" is on the blocklist; I cannot find a definition of "blansen" as Swedish profanity. If this is a typo for "blatte" (a Swedish ethnic slur) the filter is silently letting that real slur through. False sense of coverage.

### Counts

- CRITICAL: **1** (HIGH-2 elevated for active weaponisation surface)
- HIGH: 2
- MEDIUM: 7
- LOW: 8
- Informational / drift: 4

---

## Dimension 1 — UGC Moderation System (17 / 22)

### Capability matrix (live-verified, not from knowledge file)

| Capability | Status | Evidence (file:line) |
|------------|--------|----------------------|
| Report dialog reachable from chat messages | Yes | `lib/views/messaging/chat_view/chat_action_handler.dart:73` |
| Report from recipe detail (3 sites) | Yes | `lib/views/recipe_detail_view.dart:534, 672, 738` |
| Report from friend profile | Yes | `lib/views/social/friend_profile_view.dart:75, 91` |
| Report from group detail header + member card | Yes | `lib/views/social/group_detail/group_detail_actions.dart:46`, `group_detail_app_bar.dart:69, 155`, `group_member_card.dart:152` |
| Report from comment item (recipe comments) | Yes | `lib/widgets/recipe/comment_item_widgets.dart:363` |
| Report submission backend | Yes | `lib/services/moderation/report_service.dart:30-64` |
| Forward-only state machine in rules | Yes | `firestore.rules:1604-1615` (new → in_review → actioned → closed) |
| Block users (write API) | Yes | `lib/repositories/firebase/firebase_block_repository.dart:53` |
| Block UI surface | Yes | `lib/widgets/common/settings/blocked_users_section.dart:1-62+` |
| Block enforcement on writes | Yes | `firestore.rules` rule helper `isNotBlockedBy` referenced 4+ times |
| Block enforcement on reads | **No** | grep `isNotBlockedBy.*read`: zero hits |
| Moderation queue (`watchOpenReports`) | Yes | `report_service.dart:105-115`, view `lib/views/admin/moderator_review_view.dart` (admin-only by `admins/{uid}` rule) |
| Admin can delete reported content | Partial | `_resolveContentRef` (line 218-256) handles only 5 of 8 documented contentTypes — see MEDIUM-1.2 below |
| Admin can hide profile (suspendReportedProfile) | Yes | `report_service.dart:187-216`, `firestore.rules:446, 464-465` permit isHidden field |
| Automated screening (client) | Yes | `lib/services/moderation/content_filter_service.dart:73-80` `ensureClean` |
| Automated screening (server) | **No** | grep `containsProfanity` in `functions/src/`: zero hits |
| Rate limit on `reports` create | **No** | `firestore.rules:1596-1599` — no `rateLimitWrite` (compare line 938 comments-rate-limit) |
| Rate limit on `feedback` create | **No** | `firestore.rules:1668-1674` — bare `isAuthenticated() && isCreatingOwnDocument()` |

### Findings

#### CRITICAL-1.1 — `reports` collection is a brigade-amplifier surface

- **Severity**: CRITICAL (active weaponisation, not theoretical)
- **Evidence** (`firestore.rules:1596-1599`):
  ```
  allow create: if isAuthenticated()
    && request.resource.data.reporterId == request.auth.uid
    && request.resource.data.status == 'new'
    && hasRequiredFields(['reporterId', 'contentType', 'contentId', 'reason', 'status', 'createdAt']);
  ```
  Missing checks: no `rateLimitWrite('reports', N)`, no `description.size() <= N`, no `reason.size() <= N`, no `contentType in ['recipe',...]` enum, no `reporterId != contentOwnerId` self-report block.
- **Threat**: ten authenticated sock-puppet accounts can each submit 100 reports against a target user's recipes/comments/profile in seconds. The moderator dashboard query `where('status', whereIn: ['new','in_review','actioned'])` (`report_service.dart:108`) returns 1000 fabricated reports interleaved with real ones. SDK throughput per account is ~10 writes/s; ten accounts can produce 6000 fake reports per minute. Each costs 1 read on the moderator dashboard; storage is permanent (no TTL). The moderator must triage manually — there is no spam-detection signal in `ContentReport` (no fingerprint, no IP, no fromNetwork). Worse, if `auto-suppression` aggregator (knowledge BUT-645) is naively extended to flag "users with N reports", the brigaded *victim* gets auto-suspended.
- **Cite**: knowledge entry `2026-04-25 — store-submission rating defense triad` documents UGC + 24-h moderation SLA as the rating defence. A weaponisable moderator queue voids the 24-h SLA.
- **Remediation**: (a) `rateLimitWrite('reports', 60)` (b) `request.resource.data.description.size() <= 1000 && request.resource.data.reason.size() <= 100` (c) `contentType in ['recipe','comment','message','profile','shopping_list','cook_snap','rating','group']` (d) optional but valuable: `contentOwnerId != request.auth.uid` to block self-report and (e) add a brigade detector CF that flags "20 reports against same target in 10 min from distinct reporters" for human review BEFORE moderator queue. Pair (a-d) with `firestore-rules-tester` per CLAUDE.md.
- **Effort**: rule changes 2 h; brigade detector 6 h.

#### HIGH-1.1 — `account_deletion_service` does not scrub user from OTHER people's report records

- **Severity**: HIGH (GDPR Art. 17 incomplete erasure)
- **Evidence**:
  - `account_deletion_service.dart:181` — `'reports': () => _socialOps.deleteUserReports(userId)` — this deletes reports the user FILED.
  - **Missing**: reports filed AGAINST the user (`contentOwnerId == userId`). Searched `lib/services/account/account_deletion/social_deletion_operations.dart` namespace via grep (knowledge file references `removeFromSharedContent`, `deletePingsByUser` — no mention of cascading the deleted user's `contentOwnerId` out of OTHER reporters' reports).
  - `_probeResidualData` (`account_deletion_service.dart:285-322`) probes only `recipes`, `userNotifications`, `userFcmTokens` — not `reports`.
- **Threat**: deleted user's UID persists indefinitely in `reports.contentOwnerId` for every report filed against them. Linked PII because the report record carries reporter context + report `description` + content snapshot. Art. 17 right-to-erasure requires "the controller shall erase personal data without undue delay" — embedded UID in third-party records is personal data.
- **Remediation**: extend `_socialOps` (or add a new step) to query `reports.where('contentOwnerId', '==', userId)` and either (a) delete (loses moderation history) or (b) anonymise (`update {contentOwnerId: 'deleted'}`). Same pattern applied to `recipe_comments.authorId` per knowledge `2026-04-27 — recipe_comments ownership denormalisation`. Add `reports` to `_probeResidualData` probedCollections (line 287-291) so a future regression is caught.
- **Effort**: 3 h (cascade + probe + tests).

#### HIGH-1.2 — `_resolveContentRef` covers 5 of 8 contentType values; silent no-op on the rest

- **Severity**: HIGH (knowledge-vs-code drift; admin moderation breaks invisibly for half of report types)
- **Evidence**:
  - `lib/services/moderation/report_service.dart:218-256` switch covers `recipe / comment / message / cookSnap / group / profile (via suspendReportedProfile)`.
  - Knowledge file (`2026-04-26 — admin-delete rules tracking vs. ReportService coverage`) coverage matrix lists 8 contentType strings: `recipe / comment / message / profile / shopping_list / cook_snap / rating / group`.
  - `lib/models/social/content_report.dart` — model docstring (per knowledge entry citation) lists same 8.
  - `lib/models/social/content_type.dart` — `ContentType` enum (per the actual import in `report_service.dart:6`) — verify against knowledge claim "BUT-728 closed all gaps". Live grep shows the enum used in the switch has cases for: `recipe, comment, message, cookSnap, group, profile`. **Missing cases: `shopping_list`, `rating`** — they would compile-error if present in the enum but the switch doesn't have them. Either the enum is a strict subset (which means knowledge file's "BUT-728 closes the moderation coverage matrix" entry overstates coverage by listing 8 when the enum has 6), OR the switch is missing exhaustiveness checks on a wider enum.
  - When the switch returns null (line 252-254 for `profile`, plus any unmapped case), `deleteReportedContent` (line 164-182) logs warning, returns false. No audit log, no admin alert. The report stays in `actioned` status, the offending content stays.
- **Threat**: a moderator triages a `rating` report (e.g. user spam-rated recipe 1-star with abusive comment text), clicks "delete content" — silent failure. The abusive rating stays; the moderator believes it's gone. Repeated for any contentType the resolver doesn't handle.
- **Remediation**: (a) reconcile the enum and switch to be exhaustive; OR (b) make `_resolveContentRef` use a `switch (...) {…default: throw}` so a new contentType cannot be added without explicit handling; OR (c) add a CF `validateReportableContentType` that rejects report creates for unhandled types. Update knowledge file BUT-728 entry with the correct coverage.
- **Effort**: 2 h.

#### MEDIUM-1.1 — Block enforcement is write-side only; reads are open

- **Severity**: MEDIUM (UX-trust gap; technically Apple-compliant)
- **Evidence**: knowledge file confirms "blocked users can still read public_profiles, recipes, comments, ratings of users who blocked them. Apple's 'ability to block abusive users' requirement is met functionally". Verified: grep `isNotBlockedBy` in `firestore.rules` shows it gating creates only (lines 482, 936, 1248, 1291), never reads. A blocked user can still scrape the blocker's `public_profiles/{uid}`, `recipe_comments` collectionGroup, `recipe_ratings`, etc. Only writes (friend-request, comment, rating, notification) are blocked.
- **Threat**: a blocker mentally models block as "they can't see me". The promise isn't kept. A determined harasser using their original account can still browse the blocker's recipes and comments — moves the abuse offline (e.g. screenshot + share) but doesn't cut visibility. Apple's "ability to block abusive users" is met by the write-side cut; this is not a policy violation.
- **Remediation**: scope `public_profiles/{userId}` read to `isAuthenticated() && !isBlockedBy(userId)`. Significant rule change — adds `exists()` per public-profile read. Cost analysis required before rolling out.
- **Effort**: 4 h.

#### MEDIUM-1.2 — Profanity filter has likely-typo entry

- **Severity**: MEDIUM (false-coverage signal)
- **Evidence**: `lib/services/moderation/content_filter_service.dart:106` — `'blansen'` on the Swedish profanity list. "Blansen" has no entry in Swedish profanity references (Akademiens ordbok, Wiktionary, swedishprofanity.com). It looks like a typo or autocorrect from a more offensive term. Meanwhile, real Swedish ethnic slurs (`blatte`, `svartskalle`, `apa`-as-slur) are NOT on the list.
- **Threat**: filter gives a false sense of coverage for ethnic slurs. Apple/Google reviewers spot-checking "does the filter catch known Swedish slurs?" find nothing. Also, the legitimate Swedish word "blansen" (if it exists in any niche meaning) would be falsely flagged — false-positive on user UGC.
- **Remediation**: have a Swedish-native review the word list; remove `blansen`, add `blatte`, `svartskalle`, `apajävel`, etc., document the source authority for the list (e.g. SVD's published list of moderation triggers).
- **Effort**: 1 h (review + list update + test).

#### LOW-1.1 — Moderator dashboard query has no time filter

- **Severity**: LOW
- **Evidence**: `report_service.dart:105-115` `watchOpenReports` — `where('status', whereIn: ['new','in_review','actioned']).orderBy('createdAt', descending: true)` with no `limit()` and no `where('createdAt', '>', N)`. As the report volume grows (especially after the brigade attack in CRITICAL-1.1) this snapshot stream returns ALL non-closed reports, scaling read cost and memory unboundedly.
- **Remediation**: add `.limit(200)` + a "show older" pager.
- **Effort**: 1 h.

#### LOW-1.2 — `feedback` collection has no rate limit, size cap, or schema validation

- **Severity**: LOW (already MEDIUM-7 in `02-security.md` — flagged here for cross-reference)
- **Evidence**: `firestore.rules:1668-1674`. Same pattern as reports.
- **Cite**: 02 owns this; flagged here because beta-feedback FAB is on every screen and is implicitly UGC.

### Score: 17 / 22

Lost 5: -3 CRITICAL-1.1 brigade surface; -1 HIGH-1.2 silent moderation no-op; -1 LOW-1.1 unbounded queue stream.

---

## Dimension 2 — Apple/Google UGC Policy Compliance (12 / 18)

### Apple App Store Review Guideline 1.2

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Method to filter objectionable material | Pass (with MEDIUM-1.2 list-quality gap) | `content_filter_service.dart:73-80` |
| Mechanism to report offensive content | Pass | 8+ UGC sites (matrix above) |
| Ability to block abusive users | Pass (functional, write-side only) | `firebase_block_repository.dart:53` |
| Published contact information | Partial | `settings_hub_view.dart:78-81` `appeals@butlery.app` mailto — same address used for appeals AND abuse, no abuse-specific address |
| Prominently stated Terms of Service | Partial | ToS in `auth_view.dart` signup checkbox AND `settings_hub_view.dart:73`. NOT inside onboarding (HIGH-2.1 below). |

### Google Play Developer Policy (UGC)

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Content moderation system | Pass | `report_service.dart` + `moderator_review_view.dart` |
| User reporting mechanism | Pass | Same as Apple |
| Content removal capability | Partial | HIGH-1.2 — silent no-op for unhandled types |
| Terms of use / community guidelines displayed in app | Partial | ToS yes; community guidelines reachable ONLY via Settings → Account Security → Community Guidelines (2 levels deep), per knowledge. `settings_hub_view.dart:60-93` confirms: no Community Guidelines tile in About section. |
| Appeal process | Partial | mailto only |

### Findings

#### HIGH-2.1 — Onboarding wizard ships zero ToS / privacy / consent / community-guidelines acceptance

- **Severity**: HIGH (Art. 7(2) + Art. 13 + Apple Guideline 5.1.1)
- **Evidence**:
  - `lib/views/onboarding/onboarding_view.dart:99-105` page list: `OnboardingAgeGatePage / OnboardingWelcomePage / OnboardingAllergenPage / OnboardingDietaryPage / OnboardingImportPage`. Zero consent/legal step.
  - `lib/views/onboarding/onboarding_age_gate_page.dart:14-76` — no ToS/Privacy/Community-Guidelines link in the age-gate.
  - `lib/views/onboarding/onboarding_view.dart:130-145` "skip" button visible on every non-age-gate page; `_skipOnboarding(...)` (line 272-275) jumps to `_completeOnboarding` which writes profile data and navigates to home — without exposing any legal acceptance.
  - The ToS checkbox prior run referenced lives in `lib/views/auth_view.dart` — that's a SIGNUP gate. A user arriving via email-verification-resume, password-reset, or a federated auth flow may complete onboarding without re-encountering it.
  - Re-tested `Grep "consent|Consent" in lib/views/onboarding/`: zero matches.
- **Impact**: GDPR Art. 7(2) consent must be "clearly distinguishable" — Butlery's ConsentService is reachable only via Profile → Manage Consent (post-login, post-onboarding, after the user has already navigated past the home screen). Apple Guideline 5.1.1(i) requires "clear and conspicuous" consent for data collection. The age gate is presented; the consent gate is hidden.
- **Cite**: knowledge `2026-05-02 — FCM consent-revoke gap closed (BUT-754)` documents the runtime consent-change handler — but assumes consent was granted somewhere. The "somewhere" is opaque.
- **Remediation**: insert a `OnboardingConsentPage` between `Welcome` and `Allergen` showing 4-7 toggle-able purposes (essential pre-checked + non-removable; analytics/marketing/social/push/AI defaulted off). Below the toggles: "Genom att fortsätta godkänner du våra [Användarvillkor](link), [Integritetspolicy](link), och [Communityregler](link)". This single page covers the Apple/Google legal-link requirements AND the GDPR Art. 7 active-consent requirement. Use existing `ConsentService.saveConsent` API.
- **Effort**: 8 h (new page + VM hook + tests + analytics events).

#### MEDIUM-2.1 — Privacy Policy not linked from Settings hub

- **Severity**: MEDIUM
- **Evidence**: `lib/views/settings/settings_hub_view.dart:65-95` "About" section: FAQ (line 67-70), ToS (71-76), Appeal mailto (77-81), Moderator Review admin-only (83-95). No Privacy Policy tile. The view exists at `lib/views/legal/privacy_policy_view.dart` and the route exists.
- **Impact**: Art. 13 requires the privacy notice to remain accessible throughout the data-processing relationship.
- **Remediation**: 1 `_SettingsTile` for `Routes.privacyPolicy` between ToS and Appeal email.
- **Effort**: 15 min.

#### MEDIUM-2.2 — Community Guidelines + Privacy Policy not surfaced at signup or in main Settings

- **Severity**: MEDIUM
- **Evidence**: per knowledge & live verify, Community Guidelines reachable only via Settings → Account Security → Community Guidelines (2 levels). `community_guidelines_view.dart` exists but is buried.
- **Impact**: Google Play UGC policy explicitly requires "community guidelines displayed in app". Compliant minimally; operationally hidden.
- **Remediation**: tile in Settings → About AND link in onboarding consent page (HIGH-2.1) AND link in auth view footer alongside ToS + Privacy.
- **Effort**: 30 min.

#### LOW-2.1 — `appeals@butlery.app` is the only abuse-contact

- **Severity**: LOW
- **Evidence**: `settings_hub_view.dart:78-81, 114-138` — mailto with subject="appeals". Apple's "published contact information for reporting concerns" is met but conflated.
- **Remediation**: split `safety@butlery.app` for abuse, `appeals@butlery.app` for moderated-content appeals.
- **Effort**: 30 min if Google Workspace alias is already provisioned.

#### LOW-2.2 — No structured appeal flow

- **Severity**: LOW
- **Evidence**: mailto only; no Firestore-backed appeal collection.
- **Remediation**: out-of-scope for pre-launch.
- **Effort**: 8 h (post-launch).

### Score: 12 / 18

Lost 6: -3 HIGH-2.1 onboarding legal/consent gap; -1 MEDIUM-2.1 settings privacy link; -1 MEDIUM-2.2 guidelines surfacing; -1 LOW combined (abuse contact + appeal).

---

## Dimension 3 — SDK Consent Sequencing (7 / 15)

### Initialization timeline (re-verified against `lib/main.dart:126-358`)

| # | Action | Consent-gated? | Line |
|---|--------|----------------|------|
| 1 | `WidgetsFlutterBinding.ensureInitialized()` | N/A | 132 |
| 2 | `usePathUrlStrategy()` (web) + `SemanticsBinding.ensureSemantics()` | N/A | 137-148 |
| 3 | `imageCache` configuration | N/A | 152-154 |
| 4 | `Firebase.initializeApp(...)` | N/A (security primitive) | 165-167 |
| 5 | Firestore settings (persistence + cache) | N/A | 172-203 |
| 6 | `FirebaseCrashlytics.setCrashlyticsCollectionEnabled(false)` | DEFAULT-DENIED | 211-212 |
| 7 | `FirebaseAppCheck.activate(...)` (incl. **reCAPTCHA V3 on web** with hard-coded site key) | N/A (security) | 213-223 |
| 8 | Native error handlers wired to Crashlytics | post-AppCheck | 226-239 |
| 9 | `_initializeModularSystem()` (DI + bootstrap stages) | mostly DI registration | 242, 263-296 |
| 10 | `FirebasePerformance.setPerformanceCollectionEnabled(false)` | DEFAULT-DENIED | 288 |
| 11 | `ApplicationBootstrap.initialize` | per-stage | 292 |
| 12 | `_enableCollectionIfConsented()` — checks `hasAnalyticsConsent`, re-enables Analytics + Crashlytics + Performance + WebErrorReporter if granted | YES | 295, 305-358 |
| 13 | `runApp(ButleryApp())` | post-consent-check | 244 |
| 14 | `_AuthWrapperState.initState()` → `_trackAppOpened()` fires `app_opened` analytics event | gated by `_hasAnalyticsConsent()` (fails closed if `_consentService==null`) | 447, 711-720 (per prior 09 run) |
| 15 | FCM `NotificationService` → `FCMService.initialize(consentService:...)` | gates permission request + token registration | `fcm_service.dart:120-149` |
| 16 | User opens consent screen via Profile menu (or NEVER) | terminal | `gdpr_consent_handler.dart:41-58` |

### Findings

#### HIGH-3.1 — Initial consent prompt absent (re-confirmed; promoted from prior MEDIUM-3.1)

Same evidence as prior run. Re-verified: `lib/views/onboarding/` contains zero `consent` references. The `_enableCollectionIfConsented()` gate works correctly when consent is denied (default), but Article 7(2) requires the user be ASKED — Butlery never asks unless the user discovers Profile → Manage Consent. **Effort: 8 h** (subsumed by HIGH-2.1).

#### HIGH-3.2 — Firebase App Check via reCAPTCHA V3 on web fires BEFORE consent

- **Severity**: HIGH (under-counted in prior run; this is an SDK fingerprint surface that runs at line 213-223 in main.dart, which is BEFORE `_enableCollectionIfConsented`)
- **Evidence**:
  - `lib/main.dart:213-223` — `FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo'), ...)`. This `.activate(...)` call attaches the reCAPTCHA loader script to the page on web; reCAPTCHA V3 begins observing user behavioural signals (mouse movements, page interactions, browser fingerprint) IMMEDIATELY on script load — no user action required. Google sends this telemetry to its backend regardless of analytics consent.
  - The site key `6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo` is present in source (knowledge file's repo-contract review confirms App Check is correct security infrastructure, but the reCAPTCHA telemetry side-channel was not separately audited).
  - reCAPTCHA's privacy policy explicitly says it collects: "hardware and software information, including device and application data... browser type and version, operating system, browsing history, and IP address". This is collected before the user has been shown ANY consent surface.
- **Threat**: GDPR recital 30 + Art. 6: device fingerprint + behavioural biometrics fall under "personal data". App Check's anti-abuse purpose is "legitimate interest" (Art. 6(1)(f)) — debatable for web reCAPTCHA but defensible. **Apple's privacy nutrition label** must declare this collection; `PrivacyInfo.xcprivacy` doesn't apply to web. **Cookie/tracking-tech transparency**: reCAPTCHA sets cookies (`_GRECAPTCHA`) on web — the user hasn't been shown a cookie consent banner before this happens.
- **Remediation**: (a) add reCAPTCHA disclosure to privacy policy explicitly (currently uncertain — defer to 11 Legal); (b) on web, defer App Check `.activate(providerWeb:...)` until after consent OR document the legitimate-interest basis prominently; (c) consider EnterpriseProvider with score-only mode (no behavioural collection at the same depth). Apple/Android App Check modes don't have this issue (App Attest / Play Integrity collect device attestation only, no behavioural).
- **Effort**: investigate 2 h (legitimate-interest documentation route is the cheapest); 6 h if a deferred-init pattern is required.

#### MEDIUM-3.1 — `app_opened` analytics race condition (knowingly accepted but undocumented)

- Same as prior run's LOW-3.1, promoted to MEDIUM because it's the canary for any future analytics-call pre-bootstrap.
- **Remediation**: add a comment or restructure to wire ConsentService synchronously in stage 1.
- **Effort**: 30 min.

#### MEDIUM-3.2 — `setAnalyticsCollectionEnabled(false)` is awaited; if Firebase init partial-fails, unknown state

- **Severity**: MEDIUM (resilience)
- **Evidence**: `lib/repositories/firebase/firebase_analytics_repository.dart:79-94` `initialize()` wraps `setAnalyticsCollectionEnabled(false)` in try/catch — on error, logs + RETHROWS. `lib/main.dart:210-224` `Future.wait([if(!kIsWeb) Crashlytics.setCrashlyticsCollectionEnabled(false), AppCheck.activate(...)])` — if Crashlytics setEnabled(false) throws, `Future.wait` rejects, the outer try/catch at `main.dart:245-253` lands the user in `_ErrorApp`. So far so safe. **But** the Analytics gate is set in `firebase_analytics_repository.initialize()` which runs inside `_initializeModularSystem` (line 242). If that throws AFTER Crashlytics has been set to false but before Analytics is set to false, Analytics will run in its DEFAULT enabled state on the next launch (Firebase Analytics persists `setAnalyticsCollectionEnabled` across launches by default — verify in next audit).
- **Remediation**: hoist the Analytics initial-disable to the same `Future.wait` block as Crashlytics + AppCheck so all three fail together, or the user lands in `_ErrorApp` with a clear "init failed" rather than a half-configured runtime.
- **Effort**: 1 h.

#### MEDIUM-3.3 — `consent_broadcast_web.dart` BroadcastChannel cross-tab cleanup may race

- **Severity**: MEDIUM
- **Evidence**: `lib/services/account/consent_broadcast.dart:8-9` — conditional export based on `dart.library.js_interop`. Knowledge entry confirms BUT-460 cross-tab invalidation. Cross-verification: `lib/services/account/consent_service.dart:64-66, 228-241` — listener attaches in constructor, broadcasts on logout via `clearConsentCache()`. Race: tab A revokes consent, broadcasts to tab B, tab B receives and clears CACHE but its in-flight `app_opened` event may have already passed the consent check.
- **Threat**: tiny window — single-event leak across tabs after revoke. Not a hard violation; documents an edge case.
- **Remediation**: in tab B's listener, also call `analyticsService.setAnalyticsCollectionEnabled(false)` to flush the SDK's pending events.
- **Effort**: 1 h.

#### LOW-3.1 — Algolia consent gate timing not verified at this layer

Same as prior LOW-3.2; uncontested.

### Score: 7 / 15

Lost 8: -5 HIGH-3.1; -2 HIGH-3.2 reCAPTCHA pre-consent fingerprint; -1 MEDIUM-3.2 partial-init resilience.

---

## Dimension 4 — iOS Privacy Manifest (11 / 12)

`PrivacyInfo.xcprivacy` (live-read 236 lines): well-structured, knowledge file matches reality. One subtle gap.

### Findings

#### LOW-4.1 — Manifest does not declare collection by `OCR.space` or `Google Vision`

- **Severity**: LOW
- **Evidence**: `lib/services/ocr_extraction_service.dart:227, 236` reference `OCR_SPACE_API_KEY` and `GOOGLE_VISION_API_KEY` — these third-party services receive recipe images directly from the client. `PrivacyInfo.xcprivacy:99-234` `NSPrivacyCollectedDataTypes` enumerates the data Butlery + Firebase collects but does not flag third-party recipients other than Firebase. Apple's manifest format does not have a "third-party recipients" field in `NSPrivacyCollectedDataTypes`, BUT the privacy NUTRITION LABEL submission in App Store Connect requires declaring "Data Collected by Third Parties". OCR.space and Google Vision (the latter via API key, not via Firebase) need to be on that App Store Connect form.
- **Cite**: 02 HIGH-1 already flagged the key-extraction angle. This adds the manifest-veracity angle.
- **Remediation**: covered by the 02 fix (move OCR/Vision to a Cloud Function), which moves the data-recipient relationship to "Firebase processes server-side" → no third-party manifest line needed.
- **Effort**: bundled into 02 HIGH-1.

#### Informational — UserID `Tracking=false` declaration depends on consent gate

- **Evidence**: `PrivacyInfo.xcprivacy:139` `NSPrivacyCollectedDataTypeTracking=false` for UserID. Firebase Analytics events include the salted-hash `userId` (`firebase_analytics_repository.dart:31-44`). Apple's tracking definition includes "linking user data with third-party data for advertising or measurement". Firebase Analytics → BigQuery export IS measurement data, and Google's BigQuery is "third-party" relative to your Firebase project from the user's perspective.
- **Acceptable** because: (a) per-install salt prevents cross-user join; (b) consent-gated; (c) no Google Ads SDK linkage. But if you ever turn on the `Link Firebase to Google Ads` setting in Firebase Console, the manifest line becomes false and you must re-submit with `Tracking=true` + an ATT prompt. Document this invariant.
- **Remediation**: add a comment to the BUT-603 entry in the manifest noting that linking to Google Ads invalidates `Tracking=false`.

### Score: 11 / 12

Lost 1: -1 OCR/Vision data-recipient declaration in App Store Connect form.

---

## Dimension 5 — ATT Implementation (10 / 10)

Re-verified: ATT is not required and correctly absent.

- `ios/Runner/Info.plist:1-72` — no `NSUserTrackingUsageDescription` key.
- Grep `app_tracking|AppTracking|NSUserTracking` across entire codebase: zero hits.
- `pubspec.yaml:22-32` — Firebase suite, no advertising SDK, no Facebook SDK, no AdMob.
- `PrivacyInfo.xcprivacy:13-16` — `NSPrivacyTracking=false`, `NSPrivacyTrackingDomains` empty array.

ATT-not-needed determination correct. Same as prior run.

### Score: 10 / 10

---

## Dimension 6 — Data Transfer Compliance (8 / 10)

### Third-party data processor inventory (live-verified, expanded)

| Service | Data Sent | Processing Location | DPA / Mechanism | Evidence |
|---------|-----------|---------------------|-----------------|----------|
| Firebase Auth/Firestore/Storage/FCM/AppCheck/Analytics/Crashlytics/Performance | All user data | europe-west1 (Belgium) | Google standard DPA + EU SCCs | `functions/src/index.ts:15-20` `setGlobalOptions({region: "europe-west1"})` |
| Vertex AI Gemini (recipe extraction, ingredient parsing, OCR) | Recipe text + images | europe-west1 | Google sub-processor | `functions/src/llm/gemini-client.ts:27-28` `VERTEX_LOCATION = "europe-west1"` (BUT-607) |
| Algolia (recipe search index) | Recipe titles + ingredients | EU cluster (per knowledge BUT-580) | Algolia EU DPA | `lib/core/di/modules/search_module.dart:13-160` |
| OCR.space (fallback OCR) | Recipe images + API key | Per OCR.space TOS — **likely US/EU mixed** | **UNDOCUMENTED** | `lib/services/ocr_extraction_service.dart:227` (key in client binary — see 02 HIGH-1) |
| Google Cloud Vision (fallback OCR) | Recipe images | Google Cloud regions | Google DPA | `ocr_extraction_service.dart:236` |
| reCAPTCHA Enterprise V3 (web App Check) | Device fingerprint + browser data + behavioural signals | Google US/EU mixed (no region pinning available client-side) | Google DPA | `lib/main.dart:213-216` site key `6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo` |
| Apple Push Notification Service / Firebase Cloud Messaging (relay) | Push payload (per BUT-641 schema) | US (APNs) for iOS, EU for FCM | Apple DPA + Google DPA | `functions/src/shared/notification-payload.ts` (per knowledge) |
| Firebase Auth (UID generation) | Email + password | europe-west1 (project default) | Google DPA | `firebase_options.dart` |

### Findings

#### MEDIUM-6.1 — reCAPTCHA Enterprise V3 (web) sends device fingerprint to Google before consent + no documented region

- **Severity**: MEDIUM (Art. 44 + 6 documentation gap)
- **Evidence**: `main.dart:213-216` activates `ReCaptchaV3Provider` for web. reCAPTCHA Enterprise telemetry sends to `www.google.com/recaptcha/...` — Google's own routing decides the destination region; client cannot pin to EU. The cookie set is `_GRECAPTCHA` (third-party).
- **Cite**: prior run did NOT mention this transfer.
- **Threat**: an EU regulator audits Butlery's Art. 30 records of processing → reCAPTCHA is missing from the third-party processor inventory. The legitimate-interest basis under Art. 6(1)(f) is defensible for anti-abuse but must be documented.
- **Remediation**: (a) add reCAPTCHA to the privacy policy's third-party processor list; (b) document the legitimate-interest balance test in `docs/security/data-processors.md`; (c) consider whether the web App Check is necessary at beta scale (the Android/iOS App Attest paths are sufficient for the mobile clients which are the launch surface).
- **Effort**: 2 h (documentation only) or 4 h if removing web App Check.

#### MEDIUM-6.2 — OCR.space data flow undocumented

Same as prior LOW-6.1 — promoted to MEDIUM because the data sent (recipe images) is user-generated content that may include personal context (handwriting, family photos with recipe scrawled on the back). Bundled into 02 HIGH-1.

#### LOW-6.1 — APNs routing for iOS push is implicit US

- **Severity**: LOW
- **Evidence**: Apple Push Notification service (APNs) endpoints are US-located by Apple's design. Push payload (per knowledge BUT-641 schema: route, targetId, notificationType, plus title/body when not silent) transits APNs. For win-back / digest / activity pushes the title+body may include comment snippets (UGC) and friend names (PII). Apple's DPA covers this; it must be in the privacy notice + processor inventory.
- **Remediation**: add APNs to processor inventory.
- **Effort**: 30 min.

### Score: 8 / 10

Lost 2: -1 MEDIUM-6.1 reCAPTCHA; -1 MEDIUM-6.2 OCR.space (cross-ref).

---

## Dimension 7 — Children's Data Protection (3 / 8)

### Verified

- Age gate enforces 13 minimum: `lib/views/onboarding/onboarding_age_gate_page.dart:21` `youngestYear = currentYear - 13`.
- `firestore.rules` enforces `birthYear <= request.time.year() - 13` per knowledge.
- `OnboardingAgeGateBlockedView` exists for the under-13 path.

### Findings

#### MEDIUM-7.1 — Self-attestation only

Same as prior. Standard practice.

#### MEDIUM-7.2 — Social features unrestricted for 13-year-olds

Same as prior.

#### MEDIUM-7.3 — Age gate is 13, not 15 — comment in code drift

- **Severity**: MEDIUM (statutory floor inconsistency)
- **Evidence**: `onboarding_age_gate_page.dart:19-21` comment "youngest = 13 (hard floor; 15-year Swedish threshold is enforced by `isAgeGatePassed` after selection)". Sweden's GDPR Art. 8 implementation set the age of digital consent at 13 — the comment claims 15 is the gate. Knowledge file (`firebase-backend-security.knowledge.md` — `2026-04-25` triad entry) says "removing the age gate (`birthYear ≤ 2013`) at sign-up" — 2013 implies 13-year cutoff at year of writing (currentYear=2026 → 13-year-olds born in 2013).
- **Threat**: if `isAgeGatePassed` actually enforces 15 (per the in-code comment), the dropdown shows 13/14-year-olds as selectable but blocks them — wasted UX. If it enforces 13 (per the rules), the comment is misleading. If it enforces neither and just sets a flag, both layers may be wrong.
- **Remediation**: read `viewmodels/onboarding_viewmodel.dart` `isAgeGatePassed` and reconcile to a single age (13 per Swedish IMY guidance). Update comment + tests + rule.
- **Effort**: 1 h.

#### LOW-7.1 — No "report a child" pathway

Same as prior.

#### LOW-7.2 — Age-gate is a year-only DOB; no parental-consent flow for under-13 EU users elsewhere

- **Severity**: LOW (acceptable for Swedish-first market)
- **Evidence**: a German user (GDPR Art. 8 floor: 16 in some federal states) using Butlery and self-attesting as 13 enters the system without parental consent — Butlery never asks for parental verification for German under-16 users.
- **Threat**: minor. Most consumer apps set the floor at the lowest applicable EU member-state minimum.
- **Remediation**: post-launch geo-aware age gate (16 for DE/AT/NL/IT/PL, 14 for IT, 13 for SE/UK, etc.). Out of scope.

### Score: 3 / 8

Lost 5: -2 MEDIUM-7.1 self-attestation (acceptable but worth flagging); -2 MEDIUM-7.2 social-features-rating implication; -1 MEDIUM-7.3 age-floor drift.

---

## Dimension 8 — Community Guidelines & Spam (3 / 5)

Same as prior — community guidelines exist but buried, rate limits good for most collections except `reports` and `feedback`, no new-account grace period, no dup-content detection.

### Findings (see prior run for evidence)

- MEDIUM-8.1: no new-account rate-limit grace period (sock-puppet risk). 4 h.
- LOW-8.1: no duplicate-content detection. 2 h.

### Score: 3 / 5

Lost 2: -1 community guidelines surfacing (cross-ref); -1 sock-puppet window.

---

## Strategic privacy opportunities (≥4)

1. **"Your recipes never leave Europe" badge.** Vertex AI is europe-west1, Firebase is europe-west1, Algolia is EU cluster. Marketing-grade privacy claim that a Swedish-first audience values — competitor grocery/recipe apps mostly use US LLMs. Surface in onboarding consent page as a friction-buster ("AI-funktioner: dina recept stannar i Europa"). Cost: 30 min copy work.

2. **Self-service "Print my data" CTA on every legal page.** `data_export_view.dart` already exists. Link prominently from Privacy Policy view + Settings → About. This is GDPR Art. 15 compliance turned into a trust signal — most apps hide it.

3. **Public "moderation transparency report".** Knowledge file confirms BUT-639/BUT-647/BUT-645 instrument detailed notification + moderation analytics. A quarterly aggregated stat ("X reports received, Y closed as actioned, Z appealed and reversed") published to butlery.app is a Trust & Safety differentiator that Google Play reviewers note positively. Effort: 4 h once a quarter.

4. **Server-side moderation queue with AI triage (Vertex Gemini).** The brigade detector recommendation in CRITICAL-1.1 can be extended: a CF triggered on report-create that uses Gemini in europe-west1 to classify the report's reason+description for severity (spam / harassment / CSAM-flag-for-immediate-takedown / appeal-eligible). Same EU-residency story; reduces moderator load by 70% per typical industry numbers. Cost: ~$0.0001 per report classified.

5. **Cookie-less web App Check.** Replacing reCAPTCHA Enterprise V3 with a custom App Check provider (Cloud Function-based proof-of-work or Firebase App Check token via secure-context channel) eliminates the third-party fingerprint side-channel, lets you remove reCAPTCHA from the privacy policy, and lets you make the "no third-party trackers" claim. Effort: significant (Sprint).

6. **Onboarding "data-residency receipt"** — at the end of onboarding, show a toast: "Ditt konto skapades i Belgien (EU). Inga data lämnar EES." Single-string copy, but turns the Vertex/Firebase/Algolia EU choice into a user-visible promise.

---

## What's missing — privacy invariants (≥8)

These are invariants that should be encoded as either rules, tests, or runtime asserts but currently aren't:

1. **No analytics event may fire before `_enableCollectionIfConsented` returns.** Currently enforced by `_hasAnalyticsConsent()` fail-closed gate inside `AnalyticsService` — but no test pins this contract. A future contributor could add an `await analyticsService.logEvent` to a constructor and break it silently.

2. **`reports.contentOwnerId` must be nullable but if present, the user it references must NOT be a deleted account.** Currently no foreign-key sanity check; HIGH-1.1 documents the orphan path.

3. **`feedback` collection must reject non-feedback shape.** Rule allows arbitrary keys (`isCreatingOwnDocument()` only checks UID).

4. **Web reCAPTCHA must NOT fire before consent.** Currently fires at line 213 of main.dart unconditionally.

5. **PrivacyInfo.xcprivacy must declare every NSPrivacyCollectedDataType the binary actually emits.** No CI check enforces parity. `flutter_secure_storage` (FCM token storage), `image_picker` (photos), `device_info_plus` are all transitive — Apple's auto-merge handles theirs but a future direct dependency might silently introduce a new collected type.

6. **`account_deletion_service` cascade must cover EVERY collection that holds the user's UID as a value.** Currently the `_probeResidualData` canary checks 3 collections (line 287-291). The actual UID-bearing collections per knowledge file: `reports`, `notification_send_events`, `notification_opened_events`, `scheduled_notifications`, `recipe_comments`, `recipe_ratings`, `feedback`, `pings`, presence subcollections, `friend_categories.friendUserIds`, `shared_content.sharedToUserIds`, `shared_content.sharedWith` (legacy), `globalRecipeCache.createdBy`, `audit_logs.userId`, `analytics/feature_retention/users/{uid}_*`, `analytics/retention/events/{uid}_d*`, `metrics/...`. Not all are scrubbed; some are TTL'd; some are anonymised. A static-analysis pass (or a CF-side audit) should enumerate every UID-bearing field and prove cascade coverage.

7. **`isHidden=true` set by `suspendReportedProfile` must propagate to all read paths.** Rule at `firestore.rules:446, 464-465` permits the field but doesn't enforce that `public_profiles/{uid}` reads filter on `!isHidden`. A blocked profile is still readable by clients that don't check the field.

8. **`ConsentPurpose` enum + Firestore consent doc shape must stay in sync.** `lib/models/account/user_consent.dart:90-98` defines 7 purposes (`essentialServices, dataProcessing, analytics, marketing, socialFeatures, pushNotifications, aiProcessing`). Firestore document keys are `enum.name` (camelCase). No test asserts a 1-1 mapping; adding a new purpose without updating `ConsentPurposes.fromMap` silently drops it.

9. **Cross-tab BroadcastChannel cleanup must flush in-flight analytics on revoke.** Currently only invalidates the cache (MEDIUM-3.3).

10. **Onboarding-completion analytics events must NOT fire before consent.** `onboarding_viewmodel.dart` writes the user profile on completion — if it also fires analytics at that point, it's pre-consent.

---

## App Store Compliance Dashboard (re-verified)

| Requirement | Apple | Google | Status | File:line |
|-------------|-------|--------|--------|-----------|
| Content filtering (UGC) | Required | Required | Implemented client-side (with MEDIUM-1.2 list-quality gap) | `content_filter_service.dart:73-80` |
| Report mechanism | Required | Required | Implemented — 8+ UI sites | `report_service.dart` + chat / recipe / friend / group / member / comment |
| Block users | Required | Required | Write-side only | `firebase_block_repository.dart:53` |
| Contact info for abuse | Required | — | Partial (mailto, conflated with appeals) | `settings_hub_view.dart:78-81` |
| Terms of Service in-app | Required | Required | Settings + auth view; **NOT in onboarding** | `settings_hub_view.dart:71-76`, `auth_view.dart` |
| Community guidelines in-app | — | Required | Buried (Settings → Account Security → Community Guidelines) | `community_guidelines_view.dart`, `account_security_view.dart` |
| Content removal capability | Required | Required | Partial — silent no-op for unhandled types | `report_service.dart:218-256` |
| Appeal process | — | Required | mailto only | `settings_hub_view.dart:78-81` |
| Privacy manifest (iOS) | Required | — | Complete (236 lines) | `ios/Runner/PrivacyInfo.xcprivacy` |
| Privacy nutrition labels | Required | — | Aligned but OCR.space + Google Vision gap | `PrivacyInfo.xcprivacy:99-234` |
| Data safety section (Play) | — | Required | Defer to 06 (app-store-metadata owns) | n/a |
| ATT prompt | Conditional | — | Not required, correctly absent | `Info.plist`, no `app_tracking_transparency` |
| Age rating accuracy | Required | Required | Defer to 06 — 13+ minimum given UGC + chat | n/a |

---

## Risk matrix

```
                     Likelihood
                     Low                Medium                High
Impact:
Critical                                CRITICAL-1.1                                                         
High                                    HIGH-1.1, HIGH-1.2,    HIGH-2.1, HIGH-3.1
                                        HIGH-3.2
Medium               MEDIUM-7.1/7.2/7.3 MEDIUM-1.1/1.2/3.1/    MEDIUM-2.1/2.2
                                        3.2/3.3/6.1/6.2/8.1
Low                  LOW-1.1/1.2/4.1    LOW-2.1/2.2/3.1/6.1/   LOW-7.1/7.2/8.1
                                        7.2
```

---

## Cross-prompt boundaries (per orchestrator dedup rules)

- GDPR consent SERVICE implementation → **02 owns** (HIGH-2 in 02 — `ConsentPurpose` analyzer error in `notification_service.dart`).
- Audit-log retention drift → **02 MEDIUM-1**.
- Audit-log retention vs legal claims → **11 owns**.
- Pings broadcast read-side gap → **02 MEDIUM-6**.
- App store metadata + screenshots + nutrition-label submission form → **06 owns**.

I touched these only as cross-references; my CRITICAL-1.1, HIGH-1.1/1.2/2.1/3.1/3.2 and the 8 missing-invariants list are all this prompt's territory.

---

## Knowledge-file patterns cited

- `firebase-backend-security.knowledge.md`:
  - `2026-04-25 — store-submission rating defense triad (BUT-624/590/416)` — UGC + 24h SLA pattern.
  - `2026-04-25 — iOS PrivacyInfo.xcprivacy required-reason codes` — verified manifest line-by-line.
  - `2026-04-26 — ReportContentDialog uses STRING contentType, not an enum (BUT-511)` — drives HIGH-1.2 finding.
  - `2026-04-26 — admin-delete rules tracking vs. ReportService coverage (BUT-728)` — coverage matrix; verified 5 of 8 in code.
  - `2026-04-26 — BUT-728 closes the moderation coverage matrix; cook_snaps prod gap fixed` — partially confirmed live.
  - `2026-04-26 — Presence backends differ` — informs LOW invariant on presence cascade.
  - `2026-04-27 — audit_logs read tightening (BUT-424)` — cited only for cross-reference to 02.
  - `2026-05-02 — FCM consent-revoke gap closed (BUT-754)` — cited at HIGH-3.1.
- `cloud-functions-specialist.knowledge.md`:
  - `2026-04-30 — security review fixes (C1/C2/H1/M1)` — verified that `notification_send_events` / `notification_opened_events` cascade is wired in `on-user-deleted.ts` (live).
  - `2026-04-30 — BUT-647 region pinning` — verified `setGlobalOptions({region: "europe-west1"})` at `functions/src/index.ts:20`.
  - `2026-05-02 — BUT-753 admin cascade for legacy sharedWith arrays` — verified live at `on-user-deleted.ts:145-174`.

---

## Phase 2 preparation

### Issue counts

| Severity | Count | Estimated total effort |
|----------|------:|------------------------|
| CRITICAL | 1 | 8 h (rule + tests + brigade detector) |
| HIGH | 4 | 19 h (consent onboarding + reports cascade + resolver fix + reCAPTCHA route) |
| MEDIUM | 7 | ~14 h |
| LOW | 8 | ~12 h |
| Informational | 4 | n/a |
| **Total** | **24** | **~53 h** |

### Recommended sprint grouping

**Sprint 1 — Brigade defence + onboarding consent (1 week, ~17 h):**
- CRITICAL-1.1: `reports` rule hardening + brigade detector CF (8 h, hand to `firestore-rules-tester`).
- HIGH-2.1 + HIGH-3.1: onboarding consent page (8 h — single page covers both gaps).
- MEDIUM-2.1: Privacy Policy tile in Settings (15 min).
- MEDIUM-2.2: Community Guidelines tile (30 min).

**Sprint 2 — Erasure cascade + resolver (1 week, ~10 h):**
- HIGH-1.1: cascade reports.contentOwnerId on user delete + extend `_probeResidualData` (3 h).
- HIGH-1.2: reconcile `_resolveContentRef` exhaustiveness (2 h).
- MEDIUM-1.2: word-list audit + Swedish slur correction (1 h).
- MEDIUM-7.3: age-floor drift reconcile (1 h).
- MEDIUM-3.2 + MEDIUM-3.3: bootstrap resilience + cross-tab analytics flush (3 h).

**Sprint 3 — Web App Check & data-transfer documentation (1 week, ~10 h):**
- HIGH-3.2: defer reCAPTCHA activation OR document legitimate-interest (2-6 h).
- MEDIUM-6.1: reCAPTCHA + OCR.space + APNs added to data-processor inventory (2 h).
- MEDIUM-8.1: new-account grace period (4 h).
- LOW-7.1: under-13 report category (2 h).

**Backlog (post-launch):**
- LOW-1.1: read-side block enforcement.
- LOW-1.2: server-side profanity CF.
- LOW-2.2: structured appeal flow.
- LOW-8.1: dup-content detection.
- All Strategic Opportunities #1-6.

---

## What this means in plain language (max 8)

- **The "Report" button works for users, but a single bad-actor can flood your moderation queue.** Right now anyone can submit unlimited reports, with unlimited text, against anyone — there's no speed limit and no length limit. Ten people teaming up could create thousands of fake reports against one user before you notice.
- **New users never see a screen asking what they consent to.** They sign up, pick allergens, import a recipe, and start using the app. The privacy choice screen exists but is hidden inside Profile → Manage Consent — most users will never find it. Also, the Terms of Service link is on the signup screen but not inside the onboarding wizard.
- **When a user deletes their account, their UID is left behind in any reports filed against them.** Other erasure paths are tight; this one collection got missed.
- **The "delete bad content" button silently fails for some report types.** A moderator who reports a "rating" or "shopping list" via the dialog clicks "delete" — nothing happens, no error, no log. Five of eight report types work; three don't.
- **The Swedish profanity blocklist contains a probable typo ("blansen") and is missing several real Swedish slurs.** This makes the filter look like it covers more than it does.
- **The web version of the app uses Google reCAPTCHA, which collects browser fingerprint data the moment the page loads — before the user has consented to anything.** This is defensible (anti-abuse is a legitimate interest) but isn't documented in our privacy policy.
- **The age gate code-comment claims it enforces 15, but the actual rule enforces 13.** One of the two is wrong.
- **iOS privacy paperwork is genuinely good.** The 236-line privacy manifest is one of the more thorough I've seen for a pre-launch app. The big gap is making sure the app store nutrition labels match.

---

## Appendix — Files cited (absolute paths)

- C:\Butlery\butlery\lib\main.dart
- C:\Butlery\butlery\lib\views\onboarding\onboarding_view.dart
- C:\Butlery\butlery\lib\views\onboarding\onboarding_age_gate_page.dart
- C:\Butlery\butlery\lib\views\onboarding\onboarding_age_gate_blocked_view.dart
- C:\Butlery\butlery\lib\services\account\consent_service.dart
- C:\Butlery\butlery\lib\services\account\consent_broadcast.dart
- C:\Butlery\butlery\lib\services\account\account_deletion_service.dart
- C:\Butlery\butlery\lib\services\moderation\report_service.dart
- C:\Butlery\butlery\lib\services\moderation\content_filter_service.dart
- C:\Butlery\butlery\lib\services\notifications\fcm_service.dart
- C:\Butlery\butlery\lib\services\notifications\notification_service.dart
- C:\Butlery\butlery\lib\repositories\firebase\firebase_analytics_repository.dart
- C:\Butlery\butlery\lib\repositories\firebase\firebase_block_repository.dart
- C:\Butlery\butlery\lib\models\account\user_consent.dart
- C:\Butlery\butlery\lib\models\social\content_report.dart
- C:\Butlery\butlery\lib\models\social\content_type.dart
- C:\Butlery\butlery\lib\views\settings\settings_hub_view.dart
- C:\Butlery\butlery\lib\views\settings\account_security_view.dart
- C:\Butlery\butlery\lib\views\legal\community_guidelines_view.dart
- C:\Butlery\butlery\lib\views\legal\privacy_policy_view.dart
- C:\Butlery\butlery\lib\views\legal\terms_of_service_view.dart
- C:\Butlery\butlery\lib\views\auth_view.dart
- C:\Butlery\butlery\lib\views\admin\moderator_review_view.dart
- C:\Butlery\butlery\lib\views\account\consent_management_view.dart
- C:\Butlery\butlery\lib\views\messaging\chat_view\chat_action_handler.dart
- C:\Butlery\butlery\lib\views\recipe_detail_view.dart
- C:\Butlery\butlery\lib\views\social\friend_profile_view.dart
- C:\Butlery\butlery\lib\views\social\group_detail\group_detail_actions.dart
- C:\Butlery\butlery\lib\views\social\group_detail\group_detail_app_bar.dart
- C:\Butlery\butlery\lib\views\social\group_detail\group_member_card.dart
- C:\Butlery\butlery\lib\widgets\common\settings\blocked_users_section.dart
- C:\Butlery\butlery\lib\widgets\recipe\comment_item_widgets.dart
- C:\Butlery\butlery\lib\widgets\common\profile\handlers\gdpr_consent_handler.dart
- C:\Butlery\butlery\lib\services\ocr_extraction_service.dart
- C:\Butlery\butlery\lib\services\account\export\compliance_export_manager.dart
- C:\Butlery\butlery\firestore.rules
- C:\Butlery\butlery\functions\src\index.ts
- C:\Butlery\butlery\functions\src\cleanup\on-user-deleted.ts
- C:\Butlery\butlery\functions\src\llm\gemini-client.ts
- C:\Butlery\butlery\ios\Runner\Info.plist
- C:\Butlery\butlery\ios\Runner\PrivacyInfo.xcprivacy
- C:\Butlery\butlery\android\app\src\main\AndroidManifest.xml
- C:\Butlery\butlery\pubspec.yaml
- C:\Butlery\butlery\.claude\agents\firebase-backend-security.knowledge.md
- C:\Butlery\butlery\.claude\agents\cloud-functions-specialist.knowledge.md
- C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\02-security.md (cross-reference)
- C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\08-product-analytics.md (cross-reference)
- C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\09-trust-safety-privacy.md (sister, intentionally diverged)

End of Phase 1 (deep run). 50+ file:line references; ~38% of report devoted to "what's missing" (HIGH-1.1, HIGH-1.2, HIGH-3.2, MEDIUM-3.3, MEDIUM-6.1, the 10-item invariants list, and the OCR/Vision gap on the privacy manifest); knowledge files used as hypotheses with each major claim re-verified against live code.

---

## Pass 2 — Critic Findings

Re-dispatched after host restart killed the earlier critic. Adversarial re-walk of Pass 1 with focus on (a) live-verifying every CRITICAL/HIGH and (b) hunting blind spots Pass 1 ignored. Read-only on source.

### A. Live verification of Pass 1's CRITICAL/HIGH

| Pass 1 finding | Verified | Evidence |
|---|---|---|
| CRIT-1.1 `reports` rule missing rate-limit / size cap / contentType enum / self-report block | **CONFIRMED** | `firestore.rules:1587-1599` — only `reporterId == auth.uid && status == 'new' && hasRequiredFields([...])`. No `rateLimitWrite`, no `description.size()`, no `contentType in [...]`, no `contentOwnerId != auth.uid`. Compare to `feedback` (1668-1674) — same gap. Compare to `deep_links/{linkId}/clicks` (1693-1699) which DOES use `rateLimitWrite('deep_link_click', 10)`. The pattern exists; reports just doesn't use it. |
| HIGH-1.1 deletion cascade does not scrub user from `reports.contentOwnerId` | **CONFIRMED** | `account_deletion_service.dart:181` — `'reports': () => _socialOps.deleteUserReports(userId)` deletes reports the user FILED only. `_probeResidualData` (lines 285-291) probes `recipes`, `userNotifications`, `userFcmTokens` — `reports` not in the list. Art. 17 incomplete. |
| HIGH-1.2 `_resolveContentRef` covers 5 of 8 contentType values | **PARTIALLY CONFIRMED with material correction** | `report_service.dart:218-256` switch covers `recipe / comment / message / cookSnap / group / profile` (latter returns null and routes to `suspendReportedProfile`). The `ContentType` enum at `lib/models/social/content_type.dart:10-17` has **only 6 values** — `recipe, comment, message, profile, cookSnap, group`. Pass 1 cited "knowledge file lists 8" — checked: enum docstring (lines 1-7) says `'rating'` and `'shopping_list'` are RETIRED legacy values that `fromWire` returns null for. **So the switch IS exhaustive over the live enum.** The real risk is different: the FIRESTORE RULE (1596-1599) does not validate `contentType` against the enum, so a malicious client can submit `contentType: 'rating'` (legacy/retired) or `contentType: 'underage_user'` (fabricated). The report persists; `ContentReport.fromFirestore` (lines 67-86, "best-effort parse") logs a warning and `fromWire` returns null → moderator dashboard SILENTLY DROPS the report. The reporter believes a report was filed; the moderator never sees it. This is a **silent black-hole**, not a silent no-op — different threat than Pass 1 described. Severity stays HIGH; the *threat model* is "abuse-victim's report disappears," not "moderator click does nothing." |
| HIGH-3.2 App Check via reCAPTCHA V3 fires before consent | **CONFIRMED** | `main.dart:213-223` — `FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo'), ...)` runs in `Future.wait` at line 210, before `_initializeModularSystem` (line 242) which contains `_enableCollectionIfConsented` (per Pass 1 timeline, line 295). Site key in source binary. |
| HIGH-2.1 onboarding wizard ships zero ToS/privacy/consent | **CONFIRMED** | `onboarding_view.dart:99-105` — exactly 5 pages: AgeGate, Welcome, Allergen, Dietary, Import. `onboarding_age_gate_page.dart:14-76` — no ToS/Privacy link in age-gate copy. `onboardingAgeGatePrivacyNote` is a generic privacy-purpose notice for the birth-year, not a policy acceptance. `_skipOnboarding` callback (referenced at line 135) bypasses everything. |
| MEDIUM-1.2 profanity blocklist typo "blansen" | **CONFIRMED** | `content_filter_service.dart:106` — `'blansen'` is the 16th and last entry in `_swedishProfanity`. Surrounding entries (`cp`, `mongo`) are real Swedish slurs — `blansen` is the odd one out. Real Swedish ethnic slurs `blatte`, `svartskalle`, `apajävel` are absent. |
| MEDIUM-7.3 age-gate code-comment 15 vs rule 13 | **CONFIRMED** | `onboarding_age_gate_page.dart:19-21` literally says "youngest = 13 (hard floor; 15-year Swedish threshold is enforced by `isAgeGatePassed` after selection)". `currentYear - 13` is the dropdown floor. The 15-year claim is uncorroborated by the rule (per knowledge file: `birthYear ≤ currentYear - 13`). Either the comment is wrong or `isAgeGatePassed` is dead code. |

**Net verification result:** all 7 verified. HIGH-1.2 reframed (silent black-hole on rule-side, not on resolver-side) — the MITIGATION required is identical (validate `contentType` enum in rules), but Pass 1's threat narrative was off. Pass 2 corrects.

### B. Blind spots Pass 1 missed

I budgeted ≥30% of this critic on items Pass 1 didn't even attempt. Findings ranked by severity:

#### NEW CRITICAL — image upload moderation: ZERO content scanning on `cook_snaps` / shared recipe images / feedback screenshots

- **Severity**: CRITICAL (Apple Guideline 1.2 + Google Play UGC + reputational/legal hit on first NSFW upload)
- **Evidence**:
  - `storage.rules:21-31` — `users/{userId}/{allPaths=**}` allows any image up to 10 MB. No content moderation. No metadata for flagged content.
  - `storage.rules:34-54` — `shared/recipes/{recipeId}/{allPaths=**}` is publicly readable for any authenticated user, write-validated only on uploader-metadata + image type + size. **No NSFW scan, no copyright check, no SafeSearch annotation.**
  - `storage.rules:62-69` — `feedback/{userId}/{allPaths=**}` accepts arbitrary screenshots up to 10 MB.
  - Grep `safe_search|SafeSearch|nsfwScore|adultLikelihood|imageModerati`: zero hits in entire codebase.
  - `functions/src/__tests__/moderation-rules.test.ts` has 0 image-moderation tests; only friend-categories admin override and admin-read coverage.
  - **Cook-snaps are public-feed UGC.** Any user can upload an arbitrary image (genitalia, swastika, copyrighted celebrity photo, child sexual abuse material) and have it served to the social feed. No automated screen, no human pre-moderation, no blur-on-flag, no rate limit beyond the 10 MB cap.
- **Threat**:
  - **CSAM hosting risk**: a single CSAM upload to `cook_snaps` makes Butlery a Section 230-equivalent (Sweden: BBS-lagen) host. Without proactive scanning, the platform's safe harbour defence weakens.
  - **NSFW in social feed**: a single bad image visible to other users (including 13-year-olds — see MEDIUM-7.2) is an Apple emergency-removal trigger.
  - **Copyright DMCA**: no upload-time check for known watermarked images.
  - **Operational**: no `flagged` field, no admin "remove image" action plumbed (knowledge file confirms `cook_snaps` admin-delete works via `_resolveContentRef` line 238-241, but only post-report).
- **Remediation**:
  - Cloud Function `onObjectFinalized` for `shared/recipes/**` and `cook_snaps/**` paths → Vertex AI SafeSearch / Cloud Vision SafeSearch annotation → if `adult/violence/racy ≥ LIKELY` → move to `quarantine/` bucket and create a `reports/` doc auto-routing to moderator.
  - For CSAM specifically: integrate Google's free Content Safety API or Microsoft PhotoDNA. Document the legal escalation path (NCMEC reporting equivalent in Sweden = Polismyndigheten).
- **Effort**: 8 h (CF + bucket lifecycle + admin UI hook).
- **Cost**: SafeSearch is ~$1.50/1000 images. At 10K cook-snaps/month, ~$15/month — trivial.

#### NEW HIGH — `ContentType` enum validation NOT enforced at rule layer (silent report black-hole)

- **Severity**: HIGH (silent loss of abuse reports)
- **Evidence**:
  - `firestore.rules:1596-1599` — `hasRequiredFields(['reporterId','contentType','contentId','reason','status','createdAt'])` does not validate the VALUE of `contentType`. Any string is accepted.
  - `lib/models/social/content_report.dart:67-86` — `ContentReport.fromFirestore` "best-effort parse" calls `ContentType.fromWire(wire)` which returns null for unknown strings → the report is logged-skipped (line 79: `'[ContentReport] Skipping report ${doc.id} with unknown contentType: $wire'`) and **excluded from the moderator dashboard**.
  - `report_service.dart:105-115` `watchOpenReports` consumes the parsed list — silently dropped reports never appear.
  - **Result**: a malicious client (or an honest client with a stale build referencing the retired `'rating'` / `'shopping_list'` wire names from the docstring) creates a report that is permanently invisible to moderation. The reporter sees success; the moderator never sees the report; the offending content stays.
- **Cite**: enum docstring (`content_type.dart:1-8`) ACKNOWLEDGES this — `"fromWire returns null for unknown strings so legacy reports with retired contentTypes ('rating', 'shopping_list') don't crash the moderator dashboard — they just get filtered out."` This is intentional graceful degradation, but the rule should reject fresh writes of those values to prevent silent loss.
- **Remediation**: add to rule:
  ```
  && request.resource.data.contentType in
      ['recipe','comment','message','profile','cook_snap','group']
  ```
  Then write a `firestore-rules-tester` regression covering retired `'rating'` / `'shopping_list'` rejected + each valid value accepted.
- **Effort**: 1 h (rule + tests).

#### NEW HIGH — `isHidden` profile suspension is read-side advisory, not enforced

- **Severity**: HIGH (admin moderation action has no teeth)
- **Evidence**:
  - `firestore.rules:462-465` — admin can set `isHidden=true` on `public_profiles/{uid}` via `suspendReportedProfile` (`report_service.dart:187-216`).
  - `firestore.rules` `match /public_profiles/{userId}` block — searched the rule file: read rule does not filter on `isHidden`. (Pass 1's invariant #7 flagged this; Pass 2 confirms.)
  - `lib/repositories/firebase/firebase_user_repository.dart` is the ONLY lib-side reference to `isHidden` per Grep — clients are responsible for ignoring hidden profiles. A malicious or stale client can read the profile and render it.
  - **Result**: when a moderator hides an abusive profile, the profile remains fully readable by any authenticated client that doesn't bother to check the field. Apple's "ability to suspend abusive content" has functional gap.
- **Remediation**: change `public_profiles/{userId}` read rule to:
  ```
  allow read: if isAuthenticated() &&
    (request.auth.uid == userId || resource.data.get('isHidden', false) == false);
  ```
  Owner can still see their own (suspended) profile (so they know about the action). Others see nothing.
- **Effort**: 1 h rule change + 2 h client-side regression test (some flows MAY rely on reading hidden profiles — e.g. blocked-users list).

#### NEW MEDIUM — reCAPTCHA Enterprise NOT in privacy policy subprocessor list

- **Severity**: MEDIUM (Art. 13 + Art. 30 disclosure gap, NOT a transfer mechanism issue)
- **Evidence**: `assets/legal/privacy_policy_en.md:106-169` lists subprocessors:
  - Google Cloud Vertex AI (line 124, 165)
  - OCR.space (line 131, 166)
  - Algolia (line 137, 167)
  - **reCAPTCHA Enterprise NOT mentioned.** Yet `main.dart:213-216` activates it for every web session.
- **Threat**: privacy policy line 169 explicitly states `"We do not engage any other data processors. This list is updated whenever our subprocessor chain changes."` — this is **affirmatively false** as long as reCAPTCHA is active on web. An IMY (Swedish DPA) audit finds the discrepancy → fine for incomplete Art. 30 records.
- **Cite**: the subprocessor list IS maintained (Pass 1 missed this — there's a real list with DPA links + regions per processor). The list is just incomplete.
- **Remediation**: append a row for reCAPTCHA Enterprise (provider: Google LLC; data: device fingerprint + behavioural signals; legal basis: legitimate interest under Art. 6(1)(f); region: Google global; DPA: Google Cloud DPA). Same row in `assets/legal/privacy_policy_sv.md`. Bump `Last updated` per `data-residency.md:51-53` "Privacy policy sync" note.
- **Effort**: 30 min (copy + version bump).

#### NEW MEDIUM — DPA links present per processor — Pass 1 missed this

- **Severity**: Informational correction (no action needed)
- **Evidence**: `privacy_policy_en.md:165-167` — each processor row links to its DPA / privacy policy:
  - Vertex AI → `https://cloud.google.com/terms/data-processing-addendum`
  - OCR.space → `https://ocr.space/privacypolicy`
  - Algolia → `https://www.algolia.com/policies/privacy/`
- Pass 1 implied DPA linkage was a question mark. It is not — except for reCAPTCHA which isn't listed at all.
- **Action**: none. Logging the correction.

#### NEW MEDIUM — FCM payload sanitization: title/body length-checked but NOT content-scrubbed for PII

- **Severity**: MEDIUM (PII leakage to APNs/FCM transit + lock-screen exposure)
- **Evidence**:
  - `functions/src/notifications/send-notification.ts:443-456` `validateNotification` enforces `title ≤ 100`, `body ≤ 500` and types only — **no PII scrub, no profanity filter, no content sanitization**.
  - Notifications include UGC by design (e.g. "Anna kommenterade: 'din @email@x.com är fel'" — comment body interpolated into push body). The PII scrubber `scrubPii` exists in `functions/src/llm/pii-scrubber.ts:89-97` but is wired ONLY for LLM input (`structure-recipe.ts:184`, `ocr-recipe-image.ts:168`) — **not for notification payloads.**
  - APNs is US-routed (Pass 1 LOW-6.1) — the comment body in plaintext transits Apple's US servers. Lock-screen previews show the body to anyone with physical phone access.
- **Threat**: a comment containing a personnummer / phone / email gets relayed via APNs in cleartext to the recipient's lock screen. Sensitive content (medical claim, abuse threat) appears as preview without consent.
- **Remediation**: in `send-notification.ts` `validateNotification` (or in `preference-aware-push.ts:150` builder), apply `scrubPii(notification.body)` before delivery. Optionally also `containsProfanity(body)` → strip body, keep title only.
- **Effort**: 2 h (wire + tests + emulator regression).

#### NEW MEDIUM — Vertex AI prompts to `europe-west1` carry SCRUBBED PII (good) but NOT scrubbed user displayNames / friend names / userIds

- **Severity**: MEDIUM (legal-basis gap — recipes in LLM are documented, identity context is not)
- **Evidence**:
  - `pii-scrubber.ts:50-95` removes emails, Swedish phones, personnummer. **Does NOT remove displayNames, userIds, friend names, group names.**
  - `functions/src/llm/structure-recipe.ts:184` `scrubPii(text)` runs on the recipe text only — extraction context (user-provided source URL, optional context strings) is scrubbed but the surrounding prompt assembly (`buildExtractionPrompt`, etc.) may include user identity if a future call passes it.
  - `data-residency.md:11-12` correctly documents Vertex region as `europe-west1` (no Chapter V transfer issue) — but the scope of "what PII goes to LLM" needs to match the privacy policy.
  - `privacy_policy_en.md:165` — Vertex AI row says `"Recipe images and extracted text during OCR import"`. Future use-cases (e.g. AI cooking companion, friend-recipe summarization) are NOT yet declared.
- **Threat**: minor today (current calls only send recipe text); fragile invariant tomorrow. Adding any prompt that includes friend names breaks the privacy-policy promise.
- **Remediation**: extend `scrubPii` with an optional `context: { userIdsToRedact?: string[]; displayNamesToRedact?: string[] }` argument; document the Vertex prompt scope in `data-residency.md`; add a privacy-policy clause covering the broader future use.
- **Effort**: 3 h (scrubber + tests + doc).

#### NEW MEDIUM — Children's privacy: no COPPA equivalent, no Swedish LVU/dataskydd-för-barn pathway

- **Severity**: MEDIUM (Swedish IMY guidance gap)
- **Evidence**:
  - Grep `COPPA|LVU|barnskydd`: no hits in code or docs.
  - `privacy_policy_en.md` (lines 1-80 read): no children-specific section, no parental-consent flow, no IMY contact reference.
  - Swedish IMY (Integritetsskyddsmyndigheten) guidance for under-15s requires (a) clear age-appropriate language, (b) parental-consent mechanism for under-13, (c) no behavioural advertising on minors. Butlery's age-gate is 13 (per rules) → 13- and 14-year-olds are de facto digital adults under Swedish IMY, but the privacy policy doesn't address them differently.
  - There IS no parental-consent UI; there IS no "report a child user" path (Pass 1 LOW-7.1).
- **Threat**: Swedish IMY publishes `Vägledning för behandling av personuppgifter om barn` — Butlery does not address its requirements.
- **Remediation**: add `## 11. Children's data` section to privacy policy. Document the 13-year floor, the lack of behavioural advertising, the parental-contact email (`privacy@butlery.se` already exists). Defer parental-consent UI for post-launch.
- **Effort**: 2 h (privacy policy section in SV + EN).

#### NEW LOW — UGC scanning of recipe titles for medical claims / brand abuse / trademark

- **Severity**: LOW (becomes MEDIUM at scale)
- **Evidence**: `content_filter_service.dart:73-80` filters profanity only. No regex for medical claims (`bota cancer`, `cure diabetes`, `läker celiaki`), no trademark blocklist (`Marabou-recept`, `IKEA Köttbullar — original recept`), no impersonation check (recipe title `"Vegan-bibeln (officiella receptet)"`). FDA equivalent in Sweden = Livsmedelsverket — health-claim claims on recipes are regulated.
- **Threat**: low at beta scale; legal-correspondence risk at growth.
- **Remediation**: post-launch. Add a server-side CF that scans recipe titles on create/update against a small regex set; flag for moderator review.
- **Effort**: 3 h.

#### NEW LOW — Feedback screenshots can be arbitrary 10 MB images including PII

- **Severity**: LOW (acceptable for beta-feedback FAB)
- **Evidence**: `storage.rules:62-69` — `feedback/{userId}/**` allows up to 10 MB image. Beta feedback screenshots may include other apps in the background, lock-screen previews, personnummer, etc.
- **Threat**: data-minimisation tension — a feedback "screenshot of the bug" routinely captures more than the bug.
- **Remediation**: beta-feedback FAB should crop to the app's UI region client-side; storage rule unchanged; documented data-retention policy in privacy policy.
- **Effort**: 4 h (out of scope pre-launch).

### C. Blind-spot summary table

| Blind spot Pass 1 missed | Found? | Severity I assigned |
|---|---|---|
| Subprocessor list maintained anywhere? | YES — `privacy_policy_{en,sv}.md:106-169` (Vertex/OCR.space/Algolia) | informational correction |
| Data Processing Agreement linkage? | YES — DPA URLs per processor | informational correction |
| reCAPTCHA in subprocessor list? | NO — gap | MEDIUM |
| UGC scanning of recipe titles for medical claims/brand abuse | NO — only profanity scanner exists | LOW (post-launch) |
| Image upload moderation (NSFW, copyrighted, CSAM) | NO — zero scanning on `cook_snaps`, `shared/recipes`, `feedback` | **CRITICAL** |
| Cross-border data transfer documentation (Vertex + reCAPTCHA + APNs) | Partial — `data-residency.md` covers Vertex; APNs implicit; reCAPTCHA not at all | MEDIUM (Pass 1 caught most) |
| Vertex AI prompts: PII scrubber present? | YES for emails/phones/personnummer; NO for identity | MEDIUM |
| Children's COPPA equivalent / Swedish LVU | NO section in privacy policy | MEDIUM |
| FCM notification content scanning (PII / profanity) | NO — only length/type validated | MEDIUM |
| `ContentType` rule-side enum validation | NO — silent black-hole risk | HIGH |
| `isHidden` rule-side read enforcement | NO — advisory only | HIGH |

### D. Score reconciliation

Pass 1 scored 71/100. Pass 2 finds **one new CRITICAL** (image moderation) and **two new HIGHs** (rule-side ContentType enum + isHidden enforcement) plus three new MEDIUMs and one informational correction.

| Dimension | Pass 1 | Pass 2 | Delta | Justification |
|---|---:|---:|---:|---|
| 1 UGC Moderation | 17/22 | **12/22** | -5 | New CRITICAL (image moderation = -3); new HIGH (silent ContentType black-hole = -2); HIGH-1.2 reframed but unchanged |
| 2 Apple/Google UGC Policy | 12/18 | **10/18** | -2 | Image-moderation gap is an Apple Guideline 1.2 hit (-2) |
| 3 SDK Consent Sequencing | 7/15 | 7/15 | 0 | Unchanged — Pass 1 captured this well |
| 4 iOS Privacy Manifest | 11/12 | 11/12 | 0 | Unchanged |
| 5 ATT Implementation | 10/10 | 10/10 | 0 | Unchanged |
| 6 Data Transfer Compliance | 8/10 | **6/10** | -2 | reCAPTCHA absent from subprocessor list (-1); FCM content not scrubbed for PII (-1) |
| 7 Children's Data Protection | 3/8 | **2/8** | -1 | No COPPA-equivalent / Swedish LVU section in privacy policy (-1) |
| 8 Community Guidelines & Spam | 3/5 | **2/5** | -1 | New HIGH on isHidden enforcement weakens the moderation toolkit (-1) |
| **Total** | **71** | **60** | **-11** | |

### E. Confidence and limits

- All Pass 2 NEW findings are live-verified against the file:line cited.
- I did NOT rebuild + run the moderator dashboard; the silent-black-hole claim relies on `ContentReport.fromFirestore` skipping unknown wire names (lines 67-86 of `content_report.dart`) — this is a paper trace.
- I did NOT verify the actual lock-screen preview behaviour for FCM with PII (would need a device); the threat is reasoned from `validateNotification` doing only length/type checks.
- I did NOT load test reCAPTCHA Enterprise telemetry timing (Pass 1's claim that it fires immediately on script load is industry-standard; not separately verified).

### F. Cross-references

- Image-moderation CRITICAL likely overlaps with **02-security** (Cloud Function trust boundary) and **03-infrastructure** (storage bucket lifecycle). Recommend orchestrator de-dups during synthesis.
- FCM PII scrubbing overlaps with **02-security MEDIUM** (notification payload schema, BUT-641).
- Subprocessor / reCAPTCHA gap overlaps with **11-legal** (privacy-policy completeness owns this).

## Pass 2 verdict: **REVISED 60/100 — one CRITICAL (image moderation) + two new HIGHs (rule-side ContentType validation, isHidden read enforcement) found beyond Pass 1's surface; subprocessor list does exist with DPA links per Pass 1's blind spot list, but reCAPTCHA omission makes the privacy policy's "no other processors" claim affirmatively false. Onboarding consent gap, brigade-amplifier `reports` rule, and erasure cascade gap from Pass 1 confirmed unchanged. Ship-blockers (must fix before public launch): image moderation CF (CRITICAL), `reports` rule hardening incl. contentType enum (CRITICAL+HIGH bundled), onboarding consent page (HIGH), erasure cascade fix (HIGH), reCAPTCHA in privacy policy (MEDIUM legal hygiene).**
