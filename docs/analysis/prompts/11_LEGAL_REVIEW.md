# Legal Review — Juridisk Granskning

**Analyst:** Claude (Opus 4.7)
**Mission:** Systematisk granskning av Butlerys juridiska dokument, licensefterlevnad och regulatorisk status. Identifiera diskrepanser mellan vad juridiska dokument påstår och vad koden faktiskt gör.
**Scope:** Legal document accuracy, license compliance, regulatory alignment (GDPR, EU AI Act, app store rules), discrepancy detection.

**Du är inte jurist och ger inte juridisk rådgivning** — du är en systematisk granskare som identifierar potentiella legala risker och flaggar dem för vidare utredning.

**Cross-Prompt Boundaries:**
- GDPR service implementation (ConsentService, DataExportService, AccountDeletionService): covered in `02_SECURITY_AND_COMPLIANCE.md` — skip implementation review here. This prompt checks whether **legal documents accurately describe** those implementations.
- Dependency CVEs and supply chain security: covered in `05_DEPENDENCIES_AND_SUPPLY_CHAIN.md` — skip here. This prompt checks **license compliance** only.
- UGC moderation, app store UGC policy, SDK consent sequencing, privacy manifests: covered in `09_TRUST_SAFETY_AND_PRIVACY.md` — skip here. This prompt checks **legal document accuracy** around these features.
- This prompt owns: legal document vs code discrepancies, third-party processor accuracy, license file bundling, font/asset licensing, iOS encryption declarations, regulatory text accuracy, and consent purpose vs implementation alignment.

---

## Two-Phase Approach

### Phase 1: Investigation & Documentation (THIS PHASE)

**CRITICAL**: Document everything, change nothing.
- Cross-reference every claim in legal documents against actual code
- Document findings with file:line references
- Classify issues by severity (Critical/High/Medium/Low)
- Provide effort estimates for each issue
- **ZERO code changes made**
- **ZERO files created or modified**
- Output: Complete findings report ready for Phase 2 remediation

### Phase 2: Remediation Plan (AFTER Phase 1 Complete)

- Review ALL Phase 1 findings together
- Prioritize: legal doc fixes (fast) vs code fixes (slower) vs external actions (DPAs, app store declarations)
- Group related issues for efficient batch fixing
- Create sequenced remediation plan
- Separate into: "can fix today" (doc edits) vs "needs decision" (regulatory choices) vs "needs external action" (DPAs, store submissions)

**DO NOT START PHASE 2 UNTIL PHASE 1 IS COMPLETE**

---

## Shared Project Context

```
Project:             Butlery (Swedish recipe and meal planning app)
Firebase project:    butlery-app-1
Framework:           Flutter / Dart (SDK >=3.24.0)
Architecture:        MVVM + Repository
                     Views -> ViewModels -> Services -> Repositories -> Firebase

Firebase services:   Firestore, Auth, Storage, Realtime Database, Cloud Functions (Node 20),
                     Analytics, Crashlytics, Performance, Remote Config, App Check, FCM
Cloud Functions:     europe-west1 (Belgium — NOT Stockholm despite code comments)
Platforms:           Android (minSdk 24), iOS (15.0+), Web (PWA), Windows
Primary market:      Sweden (Swedish UI, English secondary)
Monetization:        None implemented — pre-monetization phase

AI integration:
  - Google Gemini (server-side via Cloud Functions) — recipe structuring, OCR
  - On-device BERT NER (ONNX Runtime) — ingredient parsing
  - OCR.space — external OCR provider

Third-party processors (per privacy policy):
  - Firebase/Google (Analytics, Crashlytics, Performance, Auth, Firestore, Storage, FCM)
  - "Mistral AI" — INCORRECT, actually Google Gemini
  - Algolia — feature-flagged OFF, listed as active
  - OCR.space — NOT listed in privacy policy

Social features:     Friends, sharing, comments, ratings, messaging, groups, blocking

Legal documents (bundled as in-app Markdown assets):
  - assets/legal/privacy_policy_{en,sv}.md
  - assets/legal/terms_of_service_{en,sv}.md
  - assets/legal/community_guidelines_{en,sv}.md

GDPR infrastructure:
  - ConsentService (7 purposes, version 1.1.0)
  - AccountDeletionService (3-tier cascade)
  - DataExportService (facade with 5 export managers)
  - FirebaseAuditRepository (Article 30)

Generated file exclusions (skip during analysis):
  - *.g.dart
  - *.freezed.dart
  - app_localizations*.dart
```

---

## Investigation Framework: 8 Dimensions

### Dimension 1: Privacy Policy vs Code Reality (25 points)

**Investigation Scope:** Does the privacy policy accurately describe what the app actually does?

**Specific Investigation Tasks:**

1. **Third-Party Processor Accuracy**
   ```
   Cross-reference assets/legal/privacy_policy_en.md Section 6 against actual code:

   For each listed processor:
   - Is the company name correct?
   - Is the purpose description accurate?
   - Is the data transfer destination correct?
   - Is the legal basis appropriate?
   - Is the service actually in use (not feature-flagged off)?

   For each actual processor used in code:
   - Is it listed in the privacy policy?
   - Is the description complete?

   Known discrepancies to verify:
   - Line 125: "Mistral AI" — code uses Google Gemini (functions/src/llm/gemini-client.ts)
   - Line 131: "Algolia" listed as active — feature-flagged off (lib/services/feature_flags/)
   - OCR.space used in lib/services/ocr_extraction_service.dart — NOT listed

   Files:
   - assets/legal/privacy_policy_en.md (Section 6: "Third-party services")
   - functions/src/llm/gemini-client.ts
   - lib/services/feature_flags/feature_flag_service.dart
   - lib/services/ocr_extraction_service.dart
   ```

2. **Cookie Section in a Cookie-less App**
   ```
   Check assets/legal/privacy_policy_en.md Section 11:
   - Lines 252-265 describe cookie categories (necessary, optional)
   - Mentions "Authentication", "CSRF", "Analytics" cookies
   - Butlery is a mobile-first Flutter app — no browser cookies exist
   - Firebase Auth uses tokens, not cookies (even on web, uses IndexedDB)
   - Flag: entire section is misleading for mobile users

   Files:
   - assets/legal/privacy_policy_en.md:252-265
   ```

3. **Data Collection Claims vs Reality**
   ```
   Cross-reference privacy policy data categories against UserProfile model:

   Check:
   - Does the policy list ALL data categories collected?
   - device_info_plus collects device model/OS — is this disclosed?
   - FCM tokens stored in Firestore — disclosed as "device identifiers"?
   - IP address field exists in UserConsent model (nullable) — is collection disclosed?
   - Allergen preferences = potentially health-related data — is special category handling noted?
   - lastActiveAt tracking = behavioral data — disclosed?

   Files:
   - assets/legal/privacy_policy_en.md (Section 3: "Information we collect")
   - lib/models/user_profile.dart
   - lib/models/account/user_consent.dart
   ```

4. **Data Retention Claims vs Implementation**
   ```
   Cross-reference retention periods stated in privacy policy against code:

   Known discrepancy:
   - account_deletion_service.dart:41 hardcodes _auditLogRetentionDays = 180
   - cleanup-audit-logs.ts:36 defaults to 90 days
   - feature_flag_service.dart:47 also defaults 90 days
   - What does the privacy policy claim?

   Check all stated retention periods against actual cleanup functions in:
   - functions/src/cleanup/ (all cleanup-*.ts files)

   Files:
   - assets/legal/privacy_policy_en.md (Section 9: "Data retention")
   - lib/services/account/account_deletion_service.dart:41
   - functions/src/cleanup/cleanup-audit-logs.ts:36
   - lib/services/feature_flags/feature_flag_service.dart:47
   ```

5. **Bilingual Consistency**
   ```
   Compare EN and SV privacy policies for semantic equivalence:
   - Same sections, same claims, same processor list
   - No Swedish-only or English-only provisions
   - Same version/date

   Files:
   - assets/legal/privacy_policy_en.md
   - assets/legal/privacy_policy_sv.md
   ```

**Output Required:**
- Processor accuracy matrix (policy claim vs code reality)
- Data collection completeness assessment
- Retention period accuracy table
- Bilingual consistency status
- Misleading section inventory

---

### Dimension 2: Terms of Service & Community Guidelines (15 points)

**Investigation Scope:** Are ToS and community guidelines accurate, complete, and properly presented?

**Specific Investigation Tasks:**

1. **ToS Content Accuracy**
   ```
   Check assets/legal/terms_of_service_en.md:
   - Age requirement stated (13?) — is this correct for Swedish GDPR implementation?
     (Sweden: digital consent age = 13 per national implementation of GDPR Art. 8)
   - Jurisdiction clause — does it name Swedish law?
   - Data ownership — who owns recipe data the user creates?
   - AI processing — is Gemini-based processing disclosed? Or does it say "AI" generically?
   - Account termination — what happens to shared data when account is deleted?
   - Intellectual property — clear re: user-generated recipes?

   Files:
   - assets/legal/terms_of_service_en.md
   - assets/legal/terms_of_service_sv.md
   ```

2. **Acceptance Mechanism**
   ```
   How does the user accept ToS and privacy policy?
   - Is there a checkbox during registration?
   - Is acceptance timestamp recorded in Firestore?
   - Can acceptance be verified after the fact (audit trail)?
   - Is the consent version tracked and bumped when legal docs change?

   Files:
   - lib/views/auth/auth_view.dart (registration flow)
   - lib/views/onboarding/ (onboarding pages)
   - lib/services/account/consent_service.dart (consent version tracking)
   - lib/viewmodels/account/consent_viewmodel.dart
   ```

3. **In-App Accessibility**
   ```
   Check:
   - Are legal docs accessible from settings/profile without login?
   - Are they accessible from the auth/login screen (before account creation)?
   - Are they accessible from the app footer/about section?
   - Do the views render Markdown correctly (lib/views/legal/)?

   Files:
   - lib/views/legal/privacy_policy_view.dart
   - lib/views/legal/terms_of_service_view.dart
   - lib/views/legal/community_guidelines_view.dart
   - lib/views/account/ (settings links to legal docs)
   ```

4. **Community Guidelines Completeness**
   ```
   Check assets/legal/community_guidelines_{en,sv}.md:
   - Does it cover: harassment, spam, inappropriate content, copyright, impersonation?
   - Does it reference the reporting mechanism?
   - Does it describe consequences of violations?
   - Is it referenced from the ToS?
   - Is it accessible from social feature entry points?

   Files:
   - assets/legal/community_guidelines_en.md
   - assets/legal/community_guidelines_sv.md
   ```

5. **Bilingual Consistency**
   ```
   Same checks as Dimension 1 — EN/SV versions must match semantically.
   ```

**Output Required:**
- ToS completeness assessment per legal requirement
- Acceptance mechanism evaluation (click-wrap quality)
- Legal doc accessibility map (where in the app are they reachable?)
- Community guidelines coverage checklist

---

### Dimension 3: License Compliance (15 points)

**Investigation Scope:** Are all third-party libraries, fonts, and assets properly licensed?

**Specific Investigation Tasks:**

1. **Dart/Flutter Dependencies**
   ```
   Run: dart pub deps --style=compact

   For each dependency:
   - Identify the license (MIT, BSD, Apache-2.0, etc.)
   - Flag any GPL/AGPL/SSPL-licensed packages
   - Flag any packages without a clear license
   - Verify attribution requirements are met (Apache-2.0 requires NOTICE)

   Focus packages with non-standard licenses:
   - freerasp (^7.5.1) — Talsec freemium model, verify commercial use terms
   - flutter_onnxruntime (^1.6.4) — MIT claimed, verify ONNX Runtime license
   - sqlcipher_flutter_libs (^0.6.4) — SQLCipher has BSD + commercial variants
   - algoliasearch (^1.46.1) — MIT, but verify terms for inactive/unused SDKs

   Files:
   - pubspec.yaml
   - pubspec.lock
   ```

2. **Cloud Functions Dependencies**
   ```
   Check functions/package.json:
   - @google/generative-ai license
   - firebase-admin, firebase-functions licenses
   - All transitive dependencies

   Files:
   - functions/package.json
   - functions/package-lock.json (if exists)
   ```

3. **Font Licenses**
   ```
   Check assets/fonts/:
   - JosefinSans (3 weights: Regular, SemiBold, Bold) — OFL-1.1
   - SpaceGrotesk (4 weights: Regular, Medium, SemiBold, Bold) — OFL-1.1

   OFL-1.1 requires the license notice to be included with font redistribution.
   Verify: are OFL-1.1 license files (.txt) bundled alongside the TTF files?

   Known gap: currently NO license files exist in assets/fonts/

   Files:
   - assets/fonts/ (glob for *.txt, *.md, LICENSE*)
   - pubspec.yaml (fonts section)
   ```

4. **Illustration & Image Provenance**
   ```
   Audit assets/illustrations/:
   - broccoli.png, morot.png — origin/license?
   - champinjon.PNG, rodlok.PNG — origin/license?
   - arta/artskida0.PNG through artskida5.PNG — origin/license? ("arta" = artist?)

   Check:
   - Is there an attribution file?
   - Are these original works, stock photos, AI-generated, or third-party?
   - If AI-generated: which model? Terms of use?

   Files:
   - assets/illustrations/ (all files)
   - assets/illustrations/arta/ (all files)
   ```

5. **ONNX Model Licensing**
   ```
   Check:
   - Where are the BERT NER and line classifier models stored?
   - What model were they derived from? (HuggingFace model card?)
   - What license applies to the model weights?
   - Are model weights redistributed in the app bundle or downloaded from Firebase Storage?

   Files:
   - lib/services/parsing/ner/ner_model_manager.dart
   - lib/services/parsing/line_classifier/line_classifier_model_manager.dart
   - storage.rules (models/ path)
   ```

6. **Open-Source License Page**
   ```
   Check:
   - Does the app have a "Licenses" or "Open Source" screen?
   - Does Flutter's built-in LicensePage (showLicensePage) surface all dependency licenses?
   - Is it accessible from settings?

   Search:
   - "LicensePage", "showLicensePage", "OpenSourceLicenses" in lib/
   ```

**Output Required:**
- Dependency license inventory (package → license → risk level)
- Font license compliance status
- Asset provenance audit
- ONNX model license status
- Missing license file list

---

### Dimension 4: AI & Data Processing Compliance (15 points)

**Investigation Scope:** Does AI processing comply with EU AI Act, GDPR, and stated privacy commitments?

**Specific Investigation Tasks:**

1. **AI Provider Accuracy**
   ```
   Cross-reference all references to the AI provider:
   - Privacy policy: "Mistral AI" (WRONG — should be Google Gemini)
   - user_consent.dart:97 comment: "Mistral OCR" (WRONG)
   - LlmService docstring: check if it says Mistral
   - ToS AI section: what provider name is used?

   Collect ALL locations where the AI provider name appears.

   Files:
   - assets/legal/privacy_policy_{en,sv}.md
   - assets/legal/terms_of_service_{en,sv}.md
   - lib/models/account/user_consent.dart:97
   - lib/services/llm/llm_service.dart (docstring/comments)
   - functions/src/llm/gemini-client.ts
   ```

2. **PII Scrubber Coverage**
   ```
   Analyze functions/src/llm/pii-scrubber.ts:
   - What PII types are scrubbed? (email, phone, personnummer — confirmed)
   - What PII types are NOT scrubbed? (names, addresses, URLs with PII)
   - Is the scrubber called on ALL paths to Gemini? (structure-recipe.ts AND ocr-recipe-image.ts)
   - Are scrubbed placeholders reversible? (they shouldn't be)

   Risk: recipe text containing "Mormors recept från Anna Svensson, Storgatan 12"
   would send the name and address to Google Gemini without scrubbing.

   Files:
   - functions/src/llm/pii-scrubber.ts
   - functions/src/llm/structure-recipe.ts
   - functions/src/llm/ocr-recipe-image.ts
   ```

3. **AI Consent Gating**
   ```
   Verify the aiProcessing consent purpose actually gates AI processing:
   - Does LlmService check ConsentService before calling Gemini?
   - What happens if consent is revoked mid-session?
   - Is the on-device ONNX model also gated by AI consent? (It should NOT be —
     on-device processing doesn't share data with third parties)

   Files:
   - lib/services/llm/llm_service.dart
   - lib/services/account/consent_service.dart
   - lib/services/parsing/ner/onnx_ner_service.dart
   ```

4. **EU AI Act Classification**
   ```
   Assess Butlery's AI features against EU AI Act risk categories:
   - Recipe text structuring (Gemini) — likely minimal risk (no health/safety impact)
   - Ingredient NER parsing (on-device BERT) — minimal risk
   - OCR (OCR.space + Gemini Vision) — minimal risk

   Check:
   - Does any AI feature make decisions that affect user rights or safety?
   - Is AI-generated content clearly labeled in the UI?
   - Article 52 transparency: does the user know when content was AI-processed?

   Files:
   - lib/views/ (search for AI output display — is there a "generated by AI" indicator?)
   ```

5. **Google Gemini Data Terms**
   ```
   Check:
   - Does Gemini API retain prompt data for model training?
     (Google's API ToS for paid tiers: no training. Free tier: may use data.)
   - Which tier is Butlery using? (defineSecret suggests a paid API key)
   - Is a DPA in place with Google for Gemini API usage?
   - Is Gemini API data processed in EU? (Check endpoint URL in gemini-client.ts)

   Files:
   - functions/src/llm/gemini-client.ts (endpoint, model config)
   ```

**Output Required:**
- AI provider reference inventory (every location mentioning AI provider name)
- PII scrubber coverage gap analysis
- Consent gating verification
- EU AI Act risk classification
- Gemini API terms compliance status

---

### Dimension 5: App Store Legal Compliance (10 points)

**Investigation Scope:** Do platform-specific declarations match actual app behavior?

**Specific Investigation Tasks:**

1. **iOS Encryption Declaration**
   ```
   ios/Runner/Info.plist line 57-58:
     ITSAppUsesNonExemptEncryption = false

   BUT: the app uses SQLCipher (AES-256 encryption) via sqlcipher_flutter_libs.
   AES-256 IS non-exempt encryption per US export regulations (EAR).

   Check:
   - Does the app qualify for an encryption exemption (ERN)?
     (Exemption exists for apps using encryption solely for user data protection,
     not for communication encryption — this may qualify under TSU exception)
   - Apple requires an annual self-classification report if using non-exempt encryption
   - Flag as HIGH: the current declaration is technically incorrect

   Files:
   - ios/Runner/Info.plist:57-58
   - pubspec.yaml (sqlcipher_flutter_libs dependency)
   ```

2. **iOS Privacy Manifest Completeness**
   ```
   Check ios/Runner/PrivacyInfo.xcprivacy:
   - NSPrivacyTracking should be false (no IDFA tracking)
   - NSPrivacyCollectedDataTypes must list ALL collected data
   - Cross-reference against: device_info_plus data, FCM tokens, analytics events,
     social feature data (friend lists, messages), allergen preferences

   Current declared types: Email, Name, Photos, Product Interaction, Crash Data, Performance Data
   Potentially missing: Device ID (device_info_plus), Push Token (FCM), Health (allergens),
   Social (friend connections), Messages, User Content (recipes)

   Files:
   - ios/Runner/PrivacyInfo.xcprivacy
   - lib/services/notifications/fcm_service.dart (token collection)
   - lib/models/user_profile.dart (allergenPreferences)
   ```

3. **Google Play Data Safety**
   ```
   This cannot be verified from code — it's configured in Play Console.
   Document what SHOULD be declared based on code analysis:

   Data types collected:
   - Email, Name (UserProfile)
   - Photos (recipe images)
   - Device info (device_info_plus)
   - App interactions (Firebase Analytics, consent-gated)
   - Crash logs (Crashlytics)
   - Performance data (Firebase Performance)
   - Push notification tokens (FCM)
   - Messages (messaging feature)
   - Health info (allergen preferences — special category!)
   - Contacts (friend connections)

   Output a recommended Data Safety declaration for comparison against actual Play Console config.
   ```

4. **Age Rating Consistency**
   ```
   Check:
   - Privacy policy states minimum age (line 269)
   - ToS states minimum age
   - What are the App Store / Play Store age ratings?
   - UGC features (messaging, comments) typically require 12+ rating
   - Consistent across all three?

   Files:
   - assets/legal/privacy_policy_en.md:269
   - assets/legal/terms_of_service_en.md
   ```

**Output Required:**
- Encryption declaration accuracy assessment
- Privacy manifest completeness matrix
- Recommended Google Play Data Safety declaration
- Age rating consistency check

---

### Dimension 6: Consent Purpose vs Implementation Alignment (10 points)

**Investigation Scope:** Does each consent purpose in ConsentPurposes map to a real data processing activity, and vice versa?

**Specific Investigation Tasks:**

1. **Purpose-to-Implementation Mapping**
   ```
   For each consent purpose in lib/models/account/user_consent.dart:

   essentialServices (required):
   - What does it gate? (Should gate: Auth, Firestore, core recipe CRUD)
   - Verify it is always true (required = cannot be opted out)

   dataProcessing (required):
   - What does it gate? (Should gate: recipe storage, shopping lists, menus)
   - Verify it is always true

   analytics (optional):
   - What does it gate? (Should gate: Firebase Analytics events)
   - Verify: analytics_service.dart checks consent before logging
   - Verify: Crashlytics respects consent (or is it always-on?)

   marketing (optional):
   - What does it gate? (NOTHING — no marketing system exists)
   - Flag: orphaned consent purpose, potentially confusing to users

   socialFeatures (optional):
   - What does it gate? (Should gate: friends, sharing, comments, messaging)
   - Verify: does disabling this actually prevent social features?

   pushNotifications (optional):
   - What does it gate? (Should gate: FCM token registration, notification display)
   - Verify: fcm_service.dart checks this consent

   aiProcessing (optional):
   - What does it gate? (Should gate: Gemini API calls)
   - Comment says "Mistral OCR" — WRONG, should say "Gemini"
   - Verify: llm_service.dart checks this before API calls

   Files:
   - lib/models/account/user_consent.dart:90-107
   - lib/services/account/consent_service.dart
   - lib/services/analytics/analytics_service.dart
   - lib/services/notifications/fcm_service.dart
   - lib/services/llm/llm_service.dart
   ```

2. **Consent UI Accuracy**
   ```
   Check lib/views/account/consent_management_view.dart:
   - Does each toggle have an accurate description?
   - Does the "marketing" toggle have an honest description (given nothing exists)?
   - Are required purposes clearly marked as non-optional?
   - Is the consent version displayed?

   Files:
   - lib/views/account/consent_management_view.dart
   - lib/viewmodels/account/consent_viewmodel.dart
   ```

**Output Required:**
- Consent purpose mapping table (purpose → what it gates → verified?)
- Orphaned purpose identification
- Consent UI accuracy assessment
- Comment/docstring accuracy (Mistral → Gemini references)

---

### Dimension 7: Firebase & Hosting Security Compliance (5 points)

**Investigation Scope:** Do Firebase configurations meet legal/regulatory requirements?

Note: Detailed Firestore/Storage rules security audit is in `02_SECURITY_AND_COMPLIANCE.md`. This dimension covers **legally relevant** configuration gaps only.

**Specific Investigation Tasks:**

1. **Firebase Hosting Security Headers**
   ```
   Check firebase.json hosting section (lines 21-33):
   - No "headers" block exists
   - Missing for PWA web deployment:
     X-Content-Type-Options: nosniff
     X-Frame-Options: DENY
     Referrer-Policy: strict-origin-when-cross-origin
     Permissions-Policy: camera=(), microphone=(), geolocation=()
     Content-Security-Policy (at minimum frame-ancestors 'none')

   These are not strictly legal requirements but are industry-standard security
   headers that regulators and auditors expect to see.

   Files:
   - firebase.json:21-33
   ```

2. **Cloud Functions Region Accuracy**
   ```
   Multiple Cloud Function files claim "Region: europe-west1 (Stockholm)":
   - cleanup-audit-logs.ts:43
   - cleanup-cache.ts:19
   - cleanup-deleted-ingredients.ts:22
   - cleanup-rate-limits.ts:24

   europe-west1 is BELGIUM (St-Ghislain), not Stockholm.
   Stockholm is europe-north1.

   For GDPR purposes: both are within EU, so data residency is compliant.
   But the documentation is incorrect, which matters for audit accuracy.

   Check: is the Firestore database also in europe-west1?
   (This affects where personal data is physically stored.)

   Files:
   - functions/src/cleanup/*.ts (region comments)
   - firebase.json (if region is configured)
   ```

3. **Data Residency Summary**
   ```
   Document where all user data physically resides:
   - Firestore: [region]
   - Firebase Storage: [region]
   - Realtime Database: [region — may differ!]
   - Cloud Functions execution: europe-west1 (Belgium)
   - Firebase Analytics: Google global infrastructure
   - Crashlytics: Google global infrastructure
   - Gemini API: [check endpoint in gemini-client.ts]
   - OCR.space: [check API endpoint]
   - Algolia: [check region — if ever enabled]

   Flag any non-EU data processing.
   ```

**Output Required:**
- Hosting security header assessment
- Region accuracy corrections
- Data residency inventory with EU/non-EU classification

---

### Dimension 8: Future Monetization Legal Readiness (5 points)

**Investigation Scope:** When payment is eventually added, what legal gaps will need addressing?

Note: No payment processing exists today. This is a forward-looking assessment, not an audit of current state.

**Specific Investigation Tasks:**

1. **Pre-Monetization Checklist**
   ```
   Document what will be needed when monetization is added:
   - [ ] PCI DSS compliance (use Stripe/RevenueCat, never store card data)
   - [ ] Konsumentköplagen compliance (Swedish consumer protection)
   - [ ] Ångerrätt (14-day right of withdrawal for EU digital services)
   - [ ] Automatic renewal disclosure (explicit pre-purchase information)
   - [ ] VAT/moms handling per jurisdiction
   - [ ] App Store IAP requirements (Apple/Google take 15-30%)
   - [ ] Price display requirements (inclusive of moms for Swedish consumers)
   - [ ] Subscription cancellation UI (app store guidelines require easy cancellation)
   - [ ] Företagsuppgifter: company name, address, org.nr must be visible (e-commerce law)

   No files to audit — this is advisory output only.
   ```

2. **Existing Legal Doc Gaps for Monetization**
   ```
   Check current ToS and privacy policy:
   - Is there any payment/billing section? (Expected: no)
   - Is there a refund policy placeholder?
   - Will the current ToS need a major revision or just additions?
   ```

**Output Required:**
- Pre-monetization legal requirements checklist
- Current document gap analysis for future payments
- Effort estimate for legal monetization readiness

---

## Scoring Framework

| # | Dimension | Points | Scoring Guidance |
|---|-----------|--------|------------------|
| 1 | Privacy Policy vs Code Reality | /25 | 25: Policy matches code exactly. 12: Minor discrepancies. 0: Major false claims. |
| 2 | ToS & Community Guidelines | /15 | 15: Complete, accurate, accessible. 8: Minor gaps. 0: Missing or misleading. |
| 3 | License Compliance | /15 | 15: All licenses verified and compliant. 8: Minor gaps (missing attribution). 0: GPL/AGPL in proprietary code. |
| 4 | AI & Data Processing | /15 | 15: Correct provider named, full PII protection, consent enforced. 8: Gaps in scrubber. 0: Wrong provider in legal docs. |
| 5 | App Store Legal Compliance | /10 | 10: All declarations accurate. 5: Minor omissions. 0: Incorrect encryption declaration. |
| 6 | Consent Purpose Alignment | /10 | 10: Every purpose maps to real implementation. 5: Orphaned purposes. 0: Consent gates nothing. |
| 7 | Firebase & Hosting Compliance | /5 | 5: All headers, correct regions, documented residency. 3: Minor gaps. 0: Misleading region claims. |
| 8 | Future Monetization Readiness | /5 | 5: Clear roadmap documented. 3: Partial coverage. 0: No consideration. |
| **Total** | | **/100** | |

---

## Output Format

### Executive Summary

```
BUTLERY LEGAL REVIEW - PHASE 1 FINDINGS
=========================================
Analysis Date: [Date]
Analyst: Claude (Opus 4.7)
Scope: Legal document accuracy, license compliance, regulatory alignment

OVERALL SCORE: X/100
+-- Privacy Policy vs Code Reality:     X/25 points
+-- ToS & Community Guidelines:         X/15 points
+-- License Compliance:                 X/15 points
+-- AI & Data Processing:               X/15 points
+-- App Store Legal Compliance:          X/10 points
+-- Consent Purpose Alignment:           X/10 points
+-- Firebase & Hosting Compliance:       X/5 points
+-- Future Monetization Readiness:       X/5 points

STATUS: [Compliant | Gaps Found | Critical Discrepancies]

CRITICAL ISSUES: X found
HIGH PRIORITY: X found
MEDIUM PRIORITY: X found
LOW PRIORITY: X found

TOP 5 LEGAL RISKS:
1. [Description]
2. [Description]
3. [Description]
4. [Description]
5. [Description]
```

### Per-Dimension Report Format

For each dimension provide:
- Summary (2-3 sentences)
- Issues grouped by CRITICAL/HIGH/MEDIUM/LOW
- Each issue: description, file:line reference, legal risk, suggested fix, effort estimate
- Recommendations and quick wins

### Legal Document Accuracy Dashboard

| Claim in Legal Doc | File:Line | Code Reality | Match? | Severity |
|--------------------|-----------|-------------|--------|----------|
| AI provider: Mistral AI | privacy_policy_en.md:125 | Google Gemini (gemini-client.ts) | NO | CRITICAL |
| Algolia active | privacy_policy_en.md:131 | Feature-flagged off | NO | MEDIUM |
| Cookie usage | privacy_policy_en.md:252 | No cookies in mobile app | NO | MEDIUM |
| ... | ... | ... | ... | ... |

### Master Checklist

```
LEGAL REVIEW CHECKLIST
======================

PRIVACY POLICY
[ ] Third-party processor list matches actual code integrations
[ ] AI provider correctly named (currently says Mistral, should say Gemini)
[ ] Cookie section removed or rewritten for mobile
[ ] Algolia status accurately reflects feature-flag state
[ ] OCR.space listed as processor (currently missing)
[ ] Data retention periods match cleanup function implementations
[ ] All collected data categories listed (device info, FCM tokens, allergens)
[ ] EN and SV versions are semantically equivalent

TERMS OF SERVICE
[ ] Age requirement correct for Swedish GDPR implementation (13)
[ ] Jurisdiction correctly states Swedish law
[ ] AI processing disclosed with correct provider name
[ ] Data ownership clearly stated for user-generated recipes
[ ] Account deletion consequences described
[ ] EN and SV versions are semantically equivalent

COMMUNITY GUIDELINES
[ ] Covers required content categories (harassment, spam, copyright)
[ ] References reporting mechanism
[ ] Describes enforcement consequences
[ ] Accessible from social feature entry points
[ ] EN and SV versions are semantically equivalent

LICENSES
[ ] All pubspec.yaml dependencies have compatible licenses
[ ] All functions/package.json dependencies have compatible licenses
[ ] Font license files (OFL-1.1) bundled in assets/fonts/
[ ] Illustration provenance documented for all files in assets/illustrations/
[ ] ONNX model license verified
[ ] Open-source license page accessible in app

AI COMPLIANCE
[ ] AI processing consent (aiProcessing) actually gates Gemini calls
[ ] PII scrubber covers names and addresses (currently only email/phone/personnummer)
[ ] EU AI Act risk classification documented
[ ] AI-generated content transparency in UI
[ ] Gemini API data retention terms verified

APP STORE
[ ] iOS ITSAppUsesNonExemptEncryption accurately reflects SQLCipher usage
[ ] iOS Privacy Manifest lists all collected data types
[ ] Google Play Data Safety matches actual collection
[ ] Age rating consistent across stores, ToS, and privacy policy

CONSENT MODEL
[ ] Each ConsentPurpose maps to real functionality
[ ] marketing purpose removed or connected to actual marketing system
[ ] aiProcessing comment updated (Mistral → Gemini)
[ ] Consent UI descriptions accurate

FIREBASE / HOSTING
[ ] Firebase Hosting has security headers (CSP, X-Frame-Options, etc.)
[ ] Cloud Functions region comments corrected (europe-west1 = Belgium)
[ ] Data residency documented per service
```

---

## Investigation Execution Plan

### Stage 1: Legal Document Cross-Reference (2 hours)

```
Read in full:
- assets/legal/privacy_policy_en.md
- assets/legal/privacy_policy_sv.md
- assets/legal/terms_of_service_en.md
- assets/legal/terms_of_service_sv.md
- assets/legal/community_guidelines_en.md
- assets/legal/community_guidelines_sv.md

Cross-reference every factual claim against the codebase.
Document each discrepancy with file:line on both sides.
```

### Stage 2: License Audit (1.5 hours)

```
Run: dart pub deps --style=compact
Check: assets/fonts/ for license files
Check: assets/illustrations/ for attribution
Check: ONNX model provenance
Check: functions/package.json licenses
Compile license inventory.
```

### Stage 3: AI & Consent Verification (1.5 hours)

```
Read:
- functions/src/llm/ (all files — gemini-client.ts, pii-scrubber.ts, structure-recipe.ts, ocr-recipe-image.ts)
- lib/models/account/user_consent.dart
- lib/services/account/consent_service.dart
- lib/services/llm/llm_service.dart
- lib/services/analytics/analytics_service.dart

Trace consent checks in code. Map each purpose to implementation.
```

### Stage 4: App Store & Platform Declarations (1 hour)

```
Read:
- ios/Runner/Info.plist
- ios/Runner/PrivacyInfo.xcprivacy
- android/app/src/main/AndroidManifest.xml
- firebase.json

Verify declarations match actual app behavior.
```

### Stage 5: Report Compilation (1 hour)

Compile all findings into structured report with scoring.

**Total estimated: 7-8 hours**

---

## Critical Reminders

1. **DOCUMENT, DO NOT FIX** — this is investigation only
2. **LEGAL DOC vs CODE is the focus** — not whether the code is secure (that's prompt 02)
3. **ACCURACY OVER COMPLETENESS** — a privacy policy that exists but contains wrong information is worse than a missing one
4. **SWEDISH LEGAL CONTEXT** — reference Swedish implementations of EU directives where relevant
5. **BILINGUAL CONSISTENCY** — every finding must be checked in both EN and SV documents
6. **ZERO CODE CHANGES** — investigation and documentation only
7. **NO GDPR SERVICE DUPLICATION** — skip ConsentService implementation review (covered by Prompt 02); focus on whether legal docs accurately describe it
8. **REALISTIC SEVERITY** — pre-launch app, solo developer. Severity should reflect actual legal/regulatory risk, not theoretical perfection
