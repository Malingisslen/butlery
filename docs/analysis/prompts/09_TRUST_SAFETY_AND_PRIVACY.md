# Trust, Safety & Advanced Privacy Compliance Analysis

## Analyst

Claude (Opus 4.6) -- comprehensive trust, safety, and privacy analysis agent.

## Mission

Perform a forensic-level investigation of Butlery's content moderation, UGC safety, and advanced privacy compliance. The goal is to verify that the app meets Apple and Google UGC policy requirements, handles SDK consent sequencing correctly, and complies with 2025-2026 privacy enforcement standards.

Butlery has full social features (friends, sharing, comments, ratings, groups, messaging). Both Apple and Google explicitly require UGC moderation infrastructure -- missing it is an app store rejection reason. Additionally, 2025-2026 privacy enforcement has moved beyond GDPR articles to targeting SDK consent race conditions, privacy manifests, and data transfer compliance. Prompt 02 covers GDPR service implementations but doesn't verify that actual data flows match consent state.

This is not a superficial review. This is a deep investigation across 8 weighted dimensions, totaling 100 points.

**Cross-Prompt Boundaries**:
- GDPR consent service implementation (ConsentService, DataExportService, AccountDeletionService): covered in `02_SECURITY_AND_COMPLIANCE.md` -- skip here.
- Dependency CVEs and supply chain: covered in `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md` -- skip here.
- App store metadata (icons, screenshots, descriptions): covered in `06_USER_EXPERIENCE_AND_PLATFORM.md` -- skip here.
- This prompt owns all UGC moderation, Apple/Google UGC policy compliance, SDK consent race conditions, iOS privacy manifest, ATT framework, data transfer compliance, children's data protection, and community guidelines enforcement.

---

## Two-Phase Approach

### Phase 1: Investigation & Documentation (THIS PHASE)

**CRITICAL**: Document everything, change nothing.
- Investigate all aspects systematically
- Document findings with file:line references
- Classify issues by severity (Critical/High/Medium/Low)
- Provide effort estimates for each issue
- **ZERO code changes made**
- **ZERO files created or modified**
- Output: Complete findings report ready for Phase 2 planning

### Phase 2: Smart Remediation Planning (AFTER Phase 1 Complete)

- Review ALL Phase 1 findings together
- Prioritize by impact, effort, and dependencies
- Group related issues for efficient batch fixing
- Create optimized fix sequence to minimize breaking changes
- Generate sprint-structured remediation plan

**DO NOT START PHASE 2 UNTIL PHASE 1 IS COMPLETE**

---

## Shared Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart
Codebase size:       ~850+ .dart files in lib/, ~150k+ lines of hand-written code
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase

Social features:
  - Friends (request, accept, block?)
  - Recipe sharing (copy-on-write pattern)
  - Comments and ratings
  - Groups (owner, admin, member roles)
  - Messaging

Privacy infrastructure:
  - ConsentService (GDPR Article 7, 38 tests)
  - DataExportService (Article 15/20, 14 tests)
  - AccountDeletionService (Article 17, 15 tests)
  - FirebaseAuditRepository (Article 30)

Platforms:           Android, iOS, Web, macOS, Windows
Third-party data processors: Mistral AI, Algolia, Firebase/Google

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
```

---

## Investigation Framework: 8 Dimensions (100 Points Total)

### Dimension 1: UGC Moderation System (22 points)

**Investigation Scope**: Does the app have infrastructure to handle abusive, harmful, or inappropriate user-generated content?

**Specific Investigation Tasks:**

1. **Report Mechanism**
   ```
   Check:
   - Do comments have a "report" action? (button, menu item)
   - Can users report recipes shared with them?
   - Can users report group messages?
   - Can users report user profiles?
   - Is the report reason categorizable? (spam, harassment, inappropriate, copyright)
   - Is there a Firestore collection for reports?

   Search:
   - "report" in all social view files
   - Report-related models, services, repositories
   - Firestore collection for moderation/reports
   ```

2. **Block/Mute Functionality**
   ```
   Check:
   - Can users block other users?
   - Does blocking hide the blocked user's content (comments, shared recipes)?
   - Does blocking prevent future friend requests?
   - Is there a "blocked users" management screen?
   - Is block state enforced server-side (Firestore rules)?

   Search:
   - "block" in user service, social views, Firestore rules
   - Block-related Firestore collections
   ```

3. **Content Moderation Queue**
   ```
   Check:
   - Is there an admin interface or dashboard for reviewing reports?
   - Are reported items flagged or hidden pending review?
   - Is there a moderation action system (warn, delete content, suspend user)?
   - Can moderators see the context of reported content?
   - Is there an escalation path for serious violations?

   Note: For a pre-launch app, a basic admin Firebase console workflow is acceptable.
   A full moderation dashboard is not required, but the data model must support it.
   ```

4. **Automated Moderation**
   ```
   Check:
   - Is there any automated content screening? (profanity filter, spam detection)
   - Are comments or messages screened before posting?
   - Is there rate limiting on comment/message submission?
   - Is there a word blocklist for Swedish profanity/harassment?
   ```

**Files to audit:**
- `lib/views/social/` (all social views -- report buttons?)
- `lib/services/` (any moderation or reporting service)
- `lib/repositories/firebase/` (report collections, block collections)
- `firestore.rules` (block enforcement, report storage)

**Output Required:**
- UGC moderation capability matrix (report, block, review, automate)
- Missing moderation features with app store rejection risk
- Data model assessment for moderation support
- Effort estimate to reach minimum viable moderation

---

### Dimension 2: Apple/Google UGC Policy Compliance (18 points)

**Investigation Scope**: Does the app meet the explicit UGC requirements from Apple App Store Review Guidelines and Google Play Developer Policy?

**Specific Investigation Tasks:**

1. **Apple App Store Review Guideline 1.2 (User-Generated Content)**
   ```
   Apple REQUIRES apps with UGC to have ALL of the following:
   - [ ] A method to filter objectionable material
   - [ ] A mechanism to report offensive content
   - [ ] The ability to block abusive users
   - [ ] Published contact information for reporting concerns
   - [ ] Prominently stated Terms of Service

   For each requirement:
   - Is it implemented?
   - Where in the UI is it accessible?
   - File:line reference for the implementation
   ```

2. **Google Play Developer Policy (User-Generated Content)**
   ```
   Google REQUIRES:
   - [ ] Content moderation system (automated or manual)
   - [ ] User reporting mechanism
   - [ ] Content removal capability
   - [ ] Terms of use / community guidelines displayed in app
   - [ ] Appeal process for content removal

   Check:
   - Are community guidelines accessible from the app?
   - Is there a Terms of Service screen or link?
   - Is the privacy policy accessible from the app?
   ```

3. **Content Types Assessment**
   ```
   Inventory all UGC content types:
   - Recipe text (title, ingredients, instructions, notes)
   - Recipe images (user-uploaded photos)
   - Comments
   - Ratings (numeric -- less moderation concern)
   - Group names and descriptions
   - User profile names and avatars
   - Messages between users

   For each type:
   - Can it contain offensive content?
   - Is it moderated?
   - Is it reportable?
   ```

4. **Legal Pages Accessibility**
   ```
   Check:
   - Privacy policy link in app (accessible without login)
   - Terms of Service link in app
   - Community guidelines (if separate from ToS)
   - Contact information for abuse reporting
   - Where in the app flow are these shown? (settings? onboarding? both?)
   ```

**Output Required:**
- Apple UGC compliance checklist (pass/fail per requirement)
- Google Play UGC compliance checklist (pass/fail per requirement)
- Content type moderation coverage matrix
- Legal page accessibility assessment
- App store rejection risk rating (Critical/High/Medium/Low)

---

### Dimension 3: SDK Consent Sequencing (15 points)

**Investigation Scope**: Do any SDKs initialize or collect data before the user has granted consent?

**Specific Investigation Tasks:**

1. **App Bootstrap Sequence Analysis**
   ```
   Read lib/core/bootstrap/stages/ and main.dart:
   - Map the exact order of SDK initialization
   - Identify where consent is checked
   - Identify which SDKs initialize BEFORE consent check

   Create a timeline:
   1. App starts
   2. [SDK X initializes] -- before or after consent?
   3. [SDK Y initializes] -- before or after consent?
   4. Consent screen shown
   5. User grants/denies consent
   6. [SDK Z starts collecting] -- respects consent?
   ```

2. **Firebase Analytics Consent Gating**
   ```
   Check:
   - Does Firebase Analytics initialize before consent?
   - Is setConsent() / setAnalyticsCollectionEnabled() called?
   - Is there a race condition where events fire before consent is set?
   - Is the first_open event suppressed until consent?

   Search:
   - FirebaseAnalytics initialization
   - setAnalyticsCollectionEnabled
   - Consent check before first analytics event
   ```

3. **Crashlytics Consent Gating**
   ```
   Check:
   - Does Crashlytics initialize before consent?
   - Is setCrashlyticsCollectionEnabled() called based on consent?
   - Are crash reports sent before consent is granted?
   - Is there a mechanism to defer Crashlytics until consent?
   ```

4. **Third-Party SDK Consent Gating**
   ```
   For each third-party SDK, verify consent gating:
   - Algolia: does search initialization respect consent?
   - Mistral AI: are AI calls gated behind consent?
   - Any other third-party SDKs

   Check:
   - Is consent state passed to SDKs that support it?
   - Are SDKs that don't support consent gating deferred until consent?
   ```

5. **Consent State Persistence**
   ```
   Check:
   - Is consent state persisted across app restarts?
   - Is consent state checked on every app launch?
   - What happens on first launch before any consent is given?
   - Is consent state synchronized across devices?
   ```

**Files to audit:**
- `lib/core/bootstrap/stages/` (all bootstrap stages)
- `lib/main.dart` or app initialization entry point
- `lib/services/consent_service.dart`
- `lib/services/analytics/analytics_service.dart` (consent check before events)
- Firebase initialization code

**Output Required:**
- SDK initialization timeline vs consent check position
- Consent race condition inventory (CRITICAL findings)
- Per-SDK consent gating assessment
- Consent state lifecycle diagram

---

### Dimension 4: iOS Privacy Manifest (12 points)

**Investigation Scope**: Is the iOS privacy manifest (PrivacyInfo.xcprivacy) present and complete? (Required since iOS 17, enforced since Spring 2024)

**Specific Investigation Tasks:**

1. **Privacy Manifest Existence**
   ```
   Check:
   - Does ios/Runner/PrivacyInfo.xcprivacy exist?
   - If not, this is a CRITICAL finding (app store rejection risk)

   Also check:
   - Do any third-party pods include their own privacy manifests?
   - Are all required API declarations present?
   ```

2. **Required Reason APIs**
   ```
   Apple requires declaration for these API categories if used:
   - NSPrivacyAccessedAPICategoryFileTimestamp
   - NSPrivacyAccessedAPICategorySystemBootTime
   - NSPrivacyAccessedAPICategoryDiskSpace
   - NSPrivacyAccessedAPICategoryUserDefaults
   - NSPrivacyAccessedAPICategoryActiveKeyboards

   Check:
   - Which of these APIs does Butlery (or its dependencies) use?
   - Is each usage declared in the privacy manifest with a valid reason?
   - UserDefaults (SharedPreferences) almost certainly requires declaration
   ```

3. **Privacy Nutrition Labels Accuracy**
   ```
   Cross-reference what the app actually collects against:
   - App Store Connect privacy labels (Data Types collected)
   - PrivacyInfo.xcprivacy declarations
   - Actual data collection in code

   Verify:
   - All collected data types are declared
   - Data linked to identity is correctly flagged
   - Data used for tracking is correctly flagged
   - Third-party data collection (Firebase, Algolia, Mistral) is included
   ```

4. **Tracking Transparency**
   ```
   Check:
   - Does the app track users across other companies' apps/websites?
   - If yes, NSUserTrackingUsageDescription must be in Info.plist
   - If no tracking, verify no SDK performs cross-app tracking
   ```

**Files to audit:**
- `ios/Runner/PrivacyInfo.xcprivacy` (does it exist?)
- `ios/Runner/Info.plist` (privacy descriptions, ATT)
- `ios/Podfile` and `ios/Podfile.lock` (third-party pod privacy manifests)

**Output Required:**
- Privacy manifest existence and completeness assessment
- Required Reason API coverage matrix
- Privacy nutrition label accuracy verification
- App store rejection risk from privacy manifest issues

---

### Dimension 5: Apple ATT Framework Implementation (10 points)

**Investigation Scope**: Is App Tracking Transparency correctly implemented?

**Specific Investigation Tasks:**

1. **ATT Requirement Assessment**
   ```
   Determine:
   - Does Butlery perform "tracking" as defined by Apple?
     (linking user/device data with third-party data for advertising/measurement)
   - If YES: ATT prompt is required before tracking
   - If NO: ATT prompt is not needed, but verify no SDK tracks without consent

   Common tracking triggers:
   - Firebase Analytics with Google Ads integration
   - Facebook SDK
   - Any advertising SDK
   - IDFA access
   ```

2. **ATT Prompt Implementation (if needed)**
   ```
   Check:
   - Is ATT prompt shown before any tracking occurs?
   - Is NSUserTrackingUsageDescription in Info.plist?
   - Is the description clear and app-specific (not generic)?
   - What happens when user declines? (tracking disabled, features work normally?)
   ```

3. **Post-ATT Consent Behavior**
   ```
   Check:
   - Is ATT status checked before enabling tracking SDKs?
   - Is ATT denial gracefully handled (no broken features)?
   - Is ATT status persisted and re-checked appropriately?
   - Does the app re-request ATT permission appropriately? (Apple limits re-prompting)
   ```

**Files to audit:**
- `ios/Runner/Info.plist` (NSUserTrackingUsageDescription)
- ATT-related Dart code (AppTrackingTransparency plugin if present)
- Analytics initialization code (consent gating)

**Output Required:**
- ATT requirement determination (needed / not needed)
- Implementation assessment if needed
- ATT denial handling evaluation

---

### Dimension 6: Data Transfer Compliance (10 points)

**Investigation Scope**: Are cross-border data transfers compliant with GDPR and related regulations?

**Specific Investigation Tasks:**

1. **Third-Party Data Processor Inventory**
   ```
   List every service that receives user data:

   | Service | Data Sent | Processing Location | DPA in Place? |
   |---------|-----------|--------------------|--------------
   | Firebase/Google | All user data | EU (europe-west1?) | Google DPA |
   | Mistral AI | Recipe text, images | EU? US? | ? |
   | Algolia | Recipe search index | EU? US? | ? |
   | [others] | | | |

   For each:
   - What data is sent?
   - Where is it processed (EU/US/other)?
   - Is there a Data Processing Agreement?
   - Is the transfer mechanism valid? (SCCs, adequacy decision, etc.)
   ```

2. **Firebase Data Residency**
   ```
   Check:
   - Firebase project region configuration
   - Firestore data location (europe-west1? us-central1?)
   - Cloud Functions deployment region
   - Firebase Storage bucket location
   - Is all data in EU for EU users?
   ```

3. **Mistral AI Data Flow**
   ```
   Check mistral-client.ts:
   - API endpoint URL (eu.mistral.ai vs api.mistral.ai)
   - Data retention by Mistral (training? caching?)
   - DPA with Mistral (or equivalent)
   - Can recipe content be used for Mistral model training?
   ```

4. **Algolia Data Flow**
   ```
   Check:
   - Algolia application region
   - What recipe data is indexed?
   - Is PII indexed? (user names in shared recipes?)
   - DPA with Algolia
   ```

**Files to audit:**
- `functions/src/llm/mistral-client.ts` (Mistral endpoint, data sent)
- Algolia configuration (index setup, data fields)
- Firebase project configuration (region settings)
- `firebase.json` (function regions)

**Output Required:**
- Data processor inventory with transfer mechanisms
- Data residency verification per service
- DPA coverage assessment
- Transfer compliance risk rating

---

### Dimension 7: Children's Data Protection (8 points)

**Investigation Scope**: Does the app comply with children's data protection requirements?

**Specific Investigation Tasks:**

1. **Age Verification**
   ```
   Check:
   - Is there an age gate or date of birth collection?
   - Is the minimum age set appropriately? (13 for COPPA, 16 for GDPR Article 8 in some EU states, 13 in Sweden)
   - Is age verified during registration?
   - What happens if a user indicates they're under the minimum age?
   ```

2. **Children's Content Assessment**
   ```
   Check:
   - Is Butlery directed at children? (likely not, but verify)
   - Could children reasonably use the app? (recipe app = possible)
   - Are there features that specifically appeal to children?
   - Is social interaction limited for younger users?
   ```

3. **COPPA/GDPR Article 8 Compliance**
   ```
   If children could use the app:
   - Is parental consent obtained for users under minimum age?
   - Is data collection minimized for younger users?
   - Can parents request deletion of their child's data?
   - Are social features restricted for children?
   ```

4. **App Store Age Rating**
   ```
   Check:
   - What age rating is set for the app? (4+, 9+, 12+, 17+)
   - Does the rating match the content? (UGC content = at least 12+)
   - Is social interaction correctly declared in age rating questionnaire?
   ```

**Output Required:**
- Age verification implementation status
- Children's data protection compliance assessment
- App Store age rating accuracy
- Risk assessment for children's access

---

### Dimension 8: Community Guidelines & Spam Prevention (5 points)

**Investigation Scope**: Are there community standards and technical measures to prevent abuse?

**Specific Investigation Tasks:**

1. **Community Guidelines Document**
   ```
   Check:
   - Do community guidelines exist? (in-app or web-hosted)
   - Do they cover: harassment, spam, inappropriate content, copyright, impersonation?
   - Are they accessible from the app?
   - Are they written in Swedish (primary audience)?
   - Are they referenced in Terms of Service?
   ```

2. **Spam Prevention**
   ```
   Check:
   - Rate limits on comment submission
   - Rate limits on friend requests
   - Rate limits on message sending
   - Rate limits on group creation
   - Duplicate content detection (same comment posted repeatedly)
   - New account restriction period (prevent spam accounts)

   Search:
   - Rate limiting logic in social services
   - Firestore rules with rate limiting (request.time checks)
   ```

3. **Content Guidelines Enforcement**
   ```
   Check:
   - Is there a mechanism to take action on guideline violations?
   - Can users be warned/suspended/banned?
   - Is there a user reputation system?
   - Are violations logged for audit?
   ```

**Output Required:**
- Community guidelines existence and completeness
- Spam prevention mechanism inventory
- Enforcement capability assessment

---

## Scoring Framework

| # | Dimension | Points | Scoring Guidance |
|---|-----------|--------|------------------|
| 1 | UGC Moderation System | /22 | 22: Report, block, review queue, automated screening. 11: Basic report/block. 0: No moderation. |
| 2 | Apple/Google UGC Policy | /18 | 18: All requirements met for both stores. 9: Partial compliance. 0: Missing critical requirements (rejection risk). |
| 3 | SDK Consent Sequencing | /15 | 15: All SDKs gated behind consent, no race conditions. 8: Most SDKs gated. 0: SDKs fire before consent. |
| 4 | iOS Privacy Manifest | /12 | 12: Complete PrivacyInfo.xcprivacy with all required declarations. 6: Exists but incomplete. 0: Missing entirely. |
| 5 | ATT Implementation | /10 | 10: Correctly determined if needed, properly implemented if so. 5: Exists but issues. 0: Missing when required. |
| 6 | Data Transfer Compliance | /10 | 10: All transfers documented, DPAs in place, EU residency verified. 5: Partially documented. 0: Unknown data flows. |
| 7 | Children's Data Protection | /8 | 8: Age gate, appropriate rating, COPPA/GDPR Art 8 addressed. 4: Age rating set correctly. 0: No consideration. |
| 8 | Community Guidelines & Spam | /5 | 5: Published guidelines, rate limiting, enforcement capability. 3: Basic guidelines. 0: None. |

---

## Output Format

### Executive Summary

```
BUTLERY TRUST, SAFETY & PRIVACY ANALYSIS - PHASE 1 FINDINGS
=============================================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.6)
Scope: UGC moderation, app store UGC policy, consent sequencing, privacy manifests, data transfers

OVERALL SCORE: X/100
+-- UGC Moderation System:             X/22 points
+-- Apple/Google UGC Policy:           X/18 points
+-- SDK Consent Sequencing:            X/15 points
+-- iOS Privacy Manifest:              X/12 points
+-- ATT Implementation:                X/10 points
+-- Data Transfer Compliance:          X/10 points
+-- Children's Data Protection:        X/8 points
+-- Community Guidelines & Spam:       X/5 points

STATUS: [App Store Ready | Rejection Risk | Critical Gaps]

APP STORE REJECTION RISKS: X found
CRITICAL ISSUES: X found
HIGH PRIORITY: X found
MEDIUM PRIORITY: X found
LOW PRIORITY: X found

TOP 5 TRUST & SAFETY RISKS:
1. [Description]
2. [Description]
3. [Description]
4. [Description]
5. [Description]
```

### Per-Dimension Report Format

For each dimension, provide: summary (2-3 sentences), issues grouped by CRITICAL/HIGH/MEDIUM/LOW with file:line references, impact description, required fix, and effort estimate. Include recommendations and quick wins.

### App Store Compliance Dashboard

| Requirement | Apple | Google | Status |
|-------------|-------|--------|--------|
| Content filtering | Required | Required | Implemented? |
| Report mechanism | Required | Required | Implemented? |
| Block users | Required | Required | Implemented? |
| Contact info | Required | - | Present? |
| Terms of Service | Required | Required | Accessible? |
| Community guidelines | - | Required | Published? |
| Content removal | Required | Required | Capable? |
| Appeal process | - | Required | Exists? |
| Privacy manifest | Required (iOS) | - | Complete? |
| Data safety section | - | Required | Accurate? |

### Phase 2 Preparation

Provide total issue counts by severity, estimated total remediation effort, and next steps for Phase 2 smart planning.

---

## Investigation Execution Plan

### Stage 1: UGC Moderation Audit (2 hours)

```
Read and analyze:
- lib/views/social/ (all social views -- report/block buttons?)
- lib/services/ (moderation, reporting, blocking services?)
- lib/repositories/firebase/ (report, block Firestore collections?)
- firestore.rules (block enforcement, report storage rules)

Focus: Report, block, moderation queue, automated screening
```

### Stage 2: App Store Policy Compliance (1 hour)

```
Check against Apple Guideline 1.2 and Google Play UGC Policy:
- Cross-reference each requirement against codebase
- Verify legal page accessibility (privacy policy, ToS, community guidelines)
- Check content type moderation coverage

Focus: Pass/fail per requirement, rejection risk assessment
```

### Stage 3: Consent Sequencing & Privacy Manifest (1.5 hours)

```
Read and analyze:
- lib/core/bootstrap/stages/ (initialization order)
- lib/services/consent_service.dart (consent gating)
- lib/services/analytics/analytics_service.dart (consent check)
- ios/Runner/PrivacyInfo.xcprivacy (existence and completeness)
- ios/Runner/Info.plist (privacy descriptions)

Focus: SDK init order vs consent, privacy manifest completeness, ATT
```

### Stage 4: Data Transfers & Children's Protection (1 hour)

```
Read and analyze:
- functions/src/llm/mistral-client.ts (Mistral data flow)
- Algolia configuration
- Firebase project region configuration
- Age verification or gate implementation

Focus: Data processor inventory, transfer mechanisms, age protection
```

### Stage 5: Report Compilation (1 hour)

Compile all findings into structured report.

**Total: 6.5-7.5 hours**

---

## Phase 1 Deliverables Checklist

- [ ] Executive summary with overall score (out of 100)
- [ ] Detailed findings for all 8 dimensions with file:line references
- [ ] Issue classification (Critical/High/Medium/Low) with counts and effort estimates
- [ ] UGC moderation capability matrix
- [ ] Apple UGC compliance checklist (pass/fail)
- [ ] Google Play UGC compliance checklist (pass/fail)
- [ ] SDK initialization timeline vs consent position
- [ ] Privacy manifest assessment
- [ ] ATT requirement determination
- [ ] Data processor inventory with transfer mechanisms
- [ ] Children's data protection assessment
- [ ] App Store Compliance Dashboard
- [ ] Phase 2 preparation section with issue grouping

---

## Critical Reminders

1. **DOCUMENT, DO NOT FIX** -- this is investigation only
2. **APP STORE REJECTION FOCUS** -- UGC moderation gaps are the #1 rejection risk for social apps
3. **NO GDPR SERVICE DUPLICATION** -- skip ConsentService implementation review (covered by Prompt 02)
4. **CONSENT SEQUENCING IS DIFFERENT** -- Prompt 02 checks that ConsentService works; this prompt checks that SDKs respect consent timing
5. **PRIVACY MANIFEST IS MANDATORY** -- missing PrivacyInfo.xcprivacy is a rejection since Spring 2024
6. **ZERO CODE CHANGES** -- investigation and documentation only
7. **REALISTIC** -- pre-launch apps commonly lack full moderation; severity should reflect actual rejection risk
8. **SWEDISH CONTEXT** -- community guidelines should address Swedish audience; legal references should include Swedish implementations of EU directives
