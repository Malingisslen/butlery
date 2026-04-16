# BUTLERY LEGAL REVIEW — PHASE 1 FINDINGS

```
Analysis Date: 2026-04-09
Analyst: Claude (Opus 4.7)
Scope: Legal document accuracy, license compliance, regulatory alignment
Prompt: docs/analysis/prompts/11_LEGAL_REVIEW.md
```

## Executive Summary

```
OVERALL SCORE: 48/100

+-- Privacy Policy vs Code Reality:     8/25 points
+-- ToS & Community Guidelines:        10/15 points
+-- License Compliance:                 8/15 points
+-- AI & Data Processing:               5/15 points
+-- App Store Legal Compliance:          5/10 points
+-- Consent Purpose Alignment:           5/10 points
+-- Firebase & Hosting Compliance:       3/5 points
+-- Future Monetization Readiness:       4/5 points

STATUS: Critical Discrepancies

CRITICAL ISSUES: 4 found
HIGH PRIORITY: 7 found
MEDIUM PRIORITY: 8 found
LOW PRIORITY: 5 found

TOP 5 LEGAL RISKS:
1. Privacy policy names wrong AI provider (Mistral AI vs actual Google Gemini)
2. Privacy policy describes features that don't exist (Google/Apple login, cookies)
3. 3 of 7 consent purposes are never enforced in code (marketing, socialFeatures, pushNotifications)
4. iOS encryption declaration incorrect (says no encryption, uses AES-256 SQLCipher)
5. Font/illustration assets distributed without required license files
```

---

## Dimension 1: Privacy Policy vs Code Reality (8/25)

The privacy policy contains multiple factual claims that do not match the codebase. Several describe features that don't exist, name wrong service providers, and state retention periods not implemented in code.

### CRITICAL

**C1 — AI Provider Misidentified: "Mistral AI" vs Google Gemini**
- **Policy claim:** `privacy_policy_en.md:125-129` — "Mistral AI (Mistral AI SAS, France)" for AI recipe extraction
- **Code reality:** `functions/src/llm/gemini-client.ts` uses `@google/generative-ai` SDK, model `gemini-2.0-flash`, API key via `defineSecret("GEMINI_API_KEY")`
- **Also wrong in:** `lib/services/llm/llm_service.dart:1-8,26` (docstring says "Mistral AI"), `lib/models/account/user_consent.dart:97` (comment says "Mistral OCR")
- **Legal risk:** GDPR Art. 13/14 requires accurate identification of data processors. Users consenting to "Mistral AI" processing have not consented to Google processing their data.
- **Fix:** Update all references to name Google (Gemini API) as the processor. Update privacy policy Section 6 with Google's Generative AI terms, USA transfer basis, and correct policy URL.
- **Effort:** 1-2 hours (doc edits + code comment fixes)

**C2 — Google/Apple Login Described But Not Implemented**
- **Policy claim:** `privacy_policy_en.md:48` — "If you log in via Google or Apple, we receive basic profile information"
- **Code reality:** Neither `google_sign_in` nor `sign_in_with_apple` exist in `pubspec.yaml`. `AuthRepository` has no OAuth methods. Only email/password auth is implemented.
- **Legal risk:** Privacy policy describes data collection from a non-existent feature. This is a false claim about data processing activities.
- **Fix:** Remove the Google/Apple login paragraph from both EN and SV privacy policies.
- **Effort:** 15 minutes

### HIGH

**H1 — Cookie Section in a Cookieless App**
- **Policy claim:** `privacy_policy_en.md:252-265` — Section 11 describes "Necessary cookies" (auth, CSRF, preferences) and "Optional cookies" (analytics, functionality)
- **Code reality:** Butlery is a Flutter mobile/PWA app. No cookie-setting code exists anywhere. Firebase Auth uses tokens (IndexedDB on web), not cookies. CSRF is not applicable.
- **Legal risk:** Misleading users about data processing techniques. May undermine trust if a regulator reviews the policy.
- **Fix:** Remove Section 11 entirely, or replace with a brief note that the app uses local storage tokens (not cookies) for authentication.
- **Effort:** 30 minutes

**H2 — Consent Log Retention (3 years) Not Implemented**
- **Policy claim:** `privacy_policy_en.md:171` — "Consent logs: 3 years after termination"
- **Code reality:** `UserConsent` model has no `expireAt` field. Consent records are deleted immediately during account deletion (`account_deletion_service.dart:163`). No 3-year retention mechanism exists.
- **Legal risk:** GDPR Art. 7(1) requires ability to demonstrate consent was given. Immediate deletion conflicts with this obligation. Either implement 3-year retention or change the policy to reflect actual behavior.
- **Fix:** Either implement consent log retention beyond account deletion (recommended for GDPR compliance) or update policy to state actual behavior.
- **Effort:** 4-8 hours if implementing retention; 15 minutes if updating policy

**H3 — Deleted Account 30-Day Backup Not Implemented**
- **Policy claim:** `privacy_policy_en.md:173` — "Deleted accounts: 30 days (backup retention)"
- **Code reality:** `AccountDeletionService` performs immediate, synchronous deletion. No soft-delete, staging period, or 30-day grace exists.
- **Legal risk:** Policy promise not honored. If a user regrets deletion within 30 days, the claimed backup doesn't exist.
- **Fix:** Either implement a 30-day soft-delete window or update the policy to state that deletion is immediate and irreversible.
- **Effort:** 2-4 days if implementing soft-delete; 15 minutes if updating policy

**H4 — BCrypt Claim Is False**
- **Policy claim:** `privacy_policy_en.md:229` — "Password encryption (bcrypt)"
- **Code reality:** No bcrypt library exists in `pubspec.yaml` or anywhere in the codebase. Firebase Auth handles password hashing server-side using scrypt, not bcrypt. The app never touches password hashing.
- **Legal risk:** Misrepresenting technical security measures in a GDPR privacy policy.
- **Fix:** Replace "bcrypt" with "Firebase Auth server-side password hashing" or simply "industry-standard password hashing."
- **Effort:** 15 minutes

### MEDIUM

**M1 — Algolia Listed as Active Processor**
- **Policy claim:** `privacy_policy_en.md:131-135` — Algolia presented as active search processor
- **Code reality:** `feature_flag_service.dart:32` — `'enable_algolia_search': false`. Algolia is disabled by default.
- **Fix:** Add qualifier "when enabled" or move to a "future processors" section.
- **Effort:** 15 minutes

**M2 — OCR.space Not Listed as Processor**
- **Code reality:** `lib/services/ocr_extraction_service.dart` sends user images to OCR.space API
- **Policy gap:** OCR.space is not mentioned anywhere in the privacy policy
- **Legal risk:** Undisclosed third-party processor receiving user data (recipe images)
- **Fix:** Add OCR.space to Section 6 processor list with purpose, transfer info, and policy URL
- **Effort:** 30 minutes

**M3 — Audit Log Retention Mismatch (3 conflicting values)**
- **Policy claim:** `privacy_policy_en.md:172` — "Security logs: 90 days"
- **Code values:**
  - Feature flag default (`feature_flag_service.dart:47`): 90 days ✓
  - Cleanup function (`cleanup-audit-logs.ts:36`): 90 days ✓
  - AuditLog model TTL (`audit_log.dart:89`): **365 days** ✗
  - Deletion audit log (`account_deletion_service.dart:41`): **180 days** ✗
- **Fix:** Align all values to a single retention period. Document deletion audit logs separately if they have a different retention.
- **Effort:** 1 hour

### LOW

**L1 — `marketing` Consent Purpose Described But No Marketing System Exists**
- **Policy claim:** `privacy_policy_en.md:62,89` — marketing communications as a consent category
- **Code reality:** No marketing email, no marketing push channel, no marketing service
- **Fix:** Remove from policy or mark as "future use — not currently active"
- **Effort:** 15 minutes

**L2 — Analytics Auth Events Fire Without Consent**
- **Code:** `analytics_service.dart:100-119` — login, signup, logout, account deletion events bypass consent check
- **Policy:** All analytics described as consent-based
- **Fix:** Either gate these events too, or disclose in policy that auth events are logged under legitimate interest (Art. 6(1)(f))
- **Effort:** 30 minutes

### BILINGUAL CONSISTENCY

EN and SV privacy policies are semantically equivalent. Minor differences:
- SV uses emoji markers (❌, ✅, 📧) in some sections; EN uses plain bullets — no legal impact
- SV uses local phone format `08-657 61 00` for IMY; EN uses `+46 8-657 61 00` — SV should add international prefix for completeness
- Both are version 1.0.0, dated October 21, 2025

---

## Dimension 2: ToS & Community Guidelines (10/15)

### HIGH

**H5 — No ToS/Privacy Policy Acceptance Checkbox at Registration**
- **Code:** `auth_view.dart:280-318` — Registration has an age confirmation checkbox (`_ageConfirmed`) but NO terms acceptance checkbox. No links to privacy policy or ToS on the auth screen.
- **ToS claim:** `terms_of_service_en.md:13` — "By creating an account, you confirm..." (browse-wrap, not click-wrap)
- **Legal risk:** Browse-wrap agreements (implied acceptance by use) are weaker than click-wrap (explicit checkbox) in EU courts. For GDPR consent and contractual acceptance, explicit click-wrap is strongly recommended.
- **Fix:** Add a "I accept the [Terms of Service] and [Privacy Policy]" checkbox with linked text, required for registration.
- **Effort:** 2-3 hours

### MEDIUM

**M4 — Privacy Policy Version Predates ToS by 4 Months**
- Privacy Policy: October 21, 2025 (v1.0.0)
- ToS: February 28, 2026 (no version number)
- Community Guidelines: February 28, 2026 (no version number)
- Risk: No cross-version referencing. ToS lacks version numbering for tracking acceptance.
- **Fix:** Add version numbers to ToS and community guidelines. Align update dates or add cross-references.
- **Effort:** 15 minutes

**M5 — Swedish ToS Typo**
- `terms_of_service_sv.md:24` — "Planera veckomenyerr" (double `r`)
- **Fix:** Correct to "Planera veckomenyer"
- **Effort:** 1 minute

### VERIFIED CORRECT

- Age requirement: 13 years — correct for Swedish GDPR implementation (national law sets digital consent age at 13)
- Jurisdiction: Swedish law, Swedish courts — correct
- User content ownership: user retains, service gets display license — reasonable
- AI processing: disclosed generically (provider name wrong, but concept is there)
- Community guidelines: cover all required categories (harassment, spam, copyright, impersonation, inappropriate content)
- Community guidelines accessible from settings
- Both EN/SV ToS are semantically equivalent

---

## Dimension 3: License Compliance (8/15)

### HIGH

**H6 — Font License Files Not Bundled (OFL-1.1 Violation)**
- `assets/fonts/` contains 7 TTF files (JosefinSans × 3, SpaceGrotesk × 4)
- Both are OFL-1.1 licensed. Section 2 of OFL requires the license text to accompany redistribution.
- **Zero license files** present in the directory.
- **Fix:** Add `JosefinSans-OFL.txt` and `SpaceGrotesk-OFL.txt` to `assets/fonts/`. Register them via `LicenseRegistry.addLicense()` in `main.dart` so they appear in Flutter's license page.
- **Effort:** 30 minutes

**H7 — Illustration Provenance Undocumented**
- `assets/illustrations/` contains 11 image files (broccoli, morot, champinjon, rodlok, artskida × 7)
- No attribution file, no README, no license metadata, no provenance trail
- Swedish vegetable names suggest custom-made, but `arta/` subdirectory hints at an artist or asset pack
- **Legal risk:** If these are stock images, Creative Commons, or commissioned work, the license terms may require attribution or restrict commercial use. Without documentation, this is a liability gap.
- **Fix:** Document the source/creator for every illustration in a `CREDITS.md` file. If commissioned, confirm work-for-hire or license grant exists.
- **Effort:** 30 minutes (if you know the source) to 2-4 hours (if you need to research)

### MEDIUM

**M6 — ONNX Model License Undocumented**
- `ner_model_manager.dart` and `line_classifier_model_manager.dart` download models from Firebase Storage (`models/ingredient_ner/v{N}/model.onnx`, `models/line_classifier/v{N}/model.onnx`)
- No license comments in the code. Comment says "BERT NER ONNX model" implying BERT lineage.
- If derived from a HuggingFace BERT checkpoint (Apache 2.0), attribution is required.
- **Fix:** Document model provenance (upstream model, training data source, license) in source comments.
- **Effort:** 30 minutes

**M7 — freeRASP License Requires EULA Review**
- `freerasp: ^7.5.1` — pub.dev says BSD-3-Clause but underlying Talsec SDK has a separate commercial EULA
- Free tier has usage limits. Production use terms should be reviewed.
- **Fix:** Review Talsec Terms of Service, confirm free tier covers your use case.
- **Effort:** 1 hour

### VERIFIED OK

- All `functions/package.json` dependencies: Apache 2.0 or MIT — no issues
- All standard Dart packages (provider, get_it, http, rxdart, etc.): MIT/BSD/Apache — no issues
- `sqlcipher_flutter_libs`: BSD-3-Clause (open-source community edition) — OK
- `flutter_onnxruntime`: MIT — OK
- Open-source license page exists: `account_security_view.dart:373-381` uses Flutter's `showLicensePage`

---

## Dimension 4: AI & Data Processing Compliance (5/15)

### CRITICAL

**C3 — AI Provider Wrong Everywhere (Systemic)**
Locations where "Mistral" appears but should say "Gemini":
1. `privacy_policy_en.md:125-129` — processor listing
2. `privacy_policy_sv.md:125-129` — same in Swedish
3. `lib/services/llm/llm_service.dart:1-8` — class docstring
4. `lib/services/llm/llm_service.dart:26` — inline comment
5. `lib/models/account/user_consent.dart:97` — consent purpose comment
6. `lib/services/ocr/ocr_usage_tracker.dart:14,24` — `mistral_text` key name

This is not a cosmetic issue. GDPR requires accurate processor identification. Users gave consent for "Mistral AI" data processing; the actual processor is Google.

### HIGH

**H8 — PII Scrubber Has Material Coverage Gaps**
- **Covered:** emails, Swedish phone numbers, personnummer, URL query parameters
- **NOT covered:** physical names, postal addresses, IP addresses, credit card/IBAN, non-Swedish phone formats, coordination numbers (samordningsnummer)
- **Critical scenario:** Recipe text "Mormors recept från Anna Svensson, Storgatan 12, 114 51 Stockholm" would send the name and full address to Google Gemini unscrubbed.
- `functions/src/llm/pii-scrubber.ts:14-20` — only 3 regex patterns
- **Fix:** Add patterns for Swedish names (harder), addresses, and at minimum document the limitation in the privacy policy.
- **Effort:** 4-8 hours for implementation; 30 minutes for policy disclosure

**H9 — Image Data Sent to Gemini Without Any PII Scrubbing**
- `functions/src/llm/ocr-recipe-image.ts:120-135` — image payload (base64) sent directly to Gemini Vision
- Only the optional `context` text parameter is scrubbed (line 123)
- If a user photographs a recipe page that shows their name, address, or phone number, it goes to Google unscrubbed
- **Architecturally unavoidable** for pixel data — but must be disclosed in privacy policy and consent screen
- **Fix:** Add explicit disclosure in privacy policy AI section: "Images sent for OCR processing may contain personal information visible in the photograph."
- **Effort:** 30 minutes (policy update)

### MEDIUM

**M8 — No EU AI Act Transparency in UI**
- No "generated by AI" indicator found in recipe views when content was AI-structured
- EU AI Act Art. 52 requires transparency when users interact with AI-generated content
- Recipe structuring (Gemini) transforms user text — the output should indicate AI involvement
- **Fix:** Add a subtle indicator (e.g., "AI-strukturerad" chip) on recipes processed by Gemini
- **Effort:** 2-3 hours

### VERIFIED OK

- `aiProcessing` consent is enforced: `llm_service.dart:252-265` checks `hasConsent('aiProcessing')` before every Gemini call
- On-device ONNX model is NOT gated by AI consent (correct — on-device processing doesn't share data with third parties)
- Gemini API key stored server-side via Firebase Secret Manager (never in client code)

---

## Dimension 5: App Store Legal Compliance (5/10)

### CRITICAL

**C4 — iOS Encryption Declaration Incorrect**
- `ios/Runner/Info.plist:57-58` — `ITSAppUsesNonExemptEncryption = false`
- App uses SQLCipher (AES-256) via `sqlcipher_flutter_libs`
- AES-256 IS non-exempt encryption under US Export Administration Regulations (EAR)
- The app may qualify for TSU (Technology and Software Unrestricted) exemption since encryption is only for local user data protection, not for communication. But the declaration must be `true` with an annual self-classification report, or the exemption must be explicitly claimed.
- **Fix:** Set `ITSAppUsesNonExemptEncryption` to `true` and file a self-classification report with the US BIS, or verify TSU exemption applies and document the basis.
- **Effort:** 2-4 hours (research + filing)

### MEDIUM

**M9 — iOS Privacy Manifest Potentially Incomplete**
- `PrivacyInfo.xcprivacy` declares 6 data types: Email, Name, Photos, Product Interaction, Crash Data, Performance Data
- Potentially missing:
  - Device ID (`device_info_plus` collects device model/OS)
  - Push Token (FCM registration)
  - Health/Medical (allergen preferences — Apple considers dietary restrictions health data)
  - User Content (recipes, messages)
  - Contacts (friend connections)
- **Fix:** Review Apple's privacy manifest categories against all data collection and update declarations.
- **Effort:** 1-2 hours

### LOW

**L3 — Age Rating Cross-Check Needed**
- ToS says 13+. Privacy policy says 13+. Consistent.
- App Store/Play Store actual age ratings cannot be verified from code — verify manually.
- UGC features (messaging, comments) typically require 12+ or higher.

---

## Dimension 6: Consent Purpose Alignment (5/10)

### HIGH

**H10 — `pushNotifications` Consent Never Enforced**
- `ConsentPurposes.pushNotifications` exists as an opt-in toggle in the consent UI
- `fcm_service.dart` — `initialize()` calls `requestPermission()` directly without checking `hasConsent('pushNotifications')`
- FCM tokens are registered in Firestore regardless of the consent flag
- Users who set `pushNotifications = false` in consent management may still receive push notifications (gated only by OS permission, not app consent)
- **Fix:** Check `hasConsent('pushNotifications')` before requesting OS permission and before registering FCM token.
- **Effort:** 1-2 hours

**H11 — `socialFeatures` Consent Never Enforced**
- `ConsentPurposes.socialFeatures` exists as an opt-in toggle
- No service in `lib/` calls `hasConsent('socialFeatures')` — confirmed by grep
- Social features (friends, sharing, comments, messaging) work regardless of this consent flag
- Users who disable social consent may still have their data shared with other users
- **Fix:** Either enforce the consent (gate social feature access) or remove the purpose from the consent model to avoid false promise.
- **Effort:** 4-8 hours if implementing gating; 1 hour if removing

### MEDIUM

**M10 — `marketing` Consent Purpose Is Orphaned**
- Exists in model, toggleable in UI, stored in Firestore — but nothing checks it
- No marketing system exists (no email, no marketing push channel)
- Users see a "Marketing communications" toggle that gates nothing
- **Fix:** Remove from consent purposes until a marketing system is built, or label clearly as "reserved for future use."
- **Effort:** 1 hour

**M11 — `aiProcessing` Consent Comment Incorrect**
- `user_consent.dart:97` — comment says "Mistral OCR"
- Should say "Google Gemini" (or just "AI recipe processing")
- **Fix:** Update comment
- **Effort:** 1 minute

---

## Dimension 7: Firebase & Hosting Compliance (3/5)

### MEDIUM

**M12 — Firebase Hosting Has No Security Headers**
- `firebase.json:21-33` — hosting section has no `headers` block
- Missing for PWA web deployment:
  - `Content-Security-Policy`
  - `X-Frame-Options: DENY`
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `Permissions-Policy`
- **Fix:** Add a `headers` block to the hosting section in `firebase.json`
- **Effort:** 30 minutes

### LOW

**L4 — Cloud Functions Region Comments Incorrect**
- 4+ files say "Region: europe-west1 (Stockholm)" — europe-west1 is Belgium, not Stockholm
- Stockholm is `europe-north1`
- No legal impact (both in EU), but inaccurate for audit documentation
- **Fix:** Correct comments to "europe-west1 (Belgium)"
- **Effort:** 15 minutes

**L5 — Firestore Database Region Unverifiable from Code**
- `firebase_options.dart` contains project ID but not Firestore region
- Region is set at project creation in Firebase Console
- Should be verified and documented for GDPR data residency claims
- **Fix:** Verify via `firebase firestore:databases:list` and document
- **Effort:** 5 minutes

### DATA RESIDENCY SUMMARY

| Service | Region | EU? | Notes |
|---------|--------|-----|-------|
| Cloud Functions | europe-west1 (Belgium) | ✅ | Verified in 17+ function files |
| Firestore | Unknown from code | ❓ | Verify in Firebase Console |
| Firebase Storage | Unknown from code | ❓ | Follows project default |
| Realtime Database | Unknown from code | ❓ | Follows project default |
| Firebase Analytics | Google global | ⚠️ | Google's infrastructure, EU-US DPF |
| Crashlytics | Google global | ⚠️ | Same as Analytics |
| Gemini API | Google global endpoint | ⚠️ | No EU-only processing guarantee |
| OCR.space | Unknown | ❓ | Not documented, not in privacy policy |

---

## Dimension 8: Future Monetization Readiness (4/5)

No payment processing exists. This is correctly reflected in the codebase — no Stripe, RevenueCat, IAP, or payment-related code.

### PRE-MONETIZATION CHECKLIST (for when payments are added)

- [ ] PCI DSS compliance via certified payment processor (Stripe/RevenueCat — never store card data)
- [ ] Konsumentköplagen (Swedish Consumer Protection Act) compliance
- [ ] Ångerrätt disclosure (14-day right of withdrawal, EU digital services)
- [ ] Automatic renewal disclosure (explicit pre-purchase information)
- [ ] VAT/moms handling per jurisdiction
- [ ] App Store IAP requirements (Apple requires IAP for digital goods/subscriptions)
- [ ] Price display inclusive of moms for Swedish consumers
- [ ] Easy cancellation UI (app store guidelines)
- [ ] Företagsuppgifter: company name, org.nr, address must be visible (Swedish e-commerce law)
- [ ] Refund policy section in ToS
- [ ] Payment/billing section in privacy policy

### CURRENT DOC GAPS

- ToS has no payment/billing section (expected — add when monetization is implemented)
- No företagsuppgifter (company info) visible in the app — this is already required for any commercial service in the EU, even free ones. Should be added to settings/about screen.

---

## Legal Document Accuracy Dashboard

| Claim in Legal Doc | File:Line | Code Reality | Match? | Severity |
|--------------------|-----------|-------------|--------|----------|
| AI provider: Mistral AI | privacy_policy_en.md:125 | Google Gemini (gemini-client.ts) | ❌ | CRITICAL |
| Google/Apple login described | privacy_policy_en.md:48 | Not implemented, only email/password | ❌ | CRITICAL |
| Cookie/CSRF usage | privacy_policy_en.md:252-265 | No cookies in app | ❌ | HIGH |
| Consent logs: 3 years | privacy_policy_en.md:171 | Deleted immediately on account deletion | ❌ | HIGH |
| Account backup: 30 days | privacy_policy_en.md:173 | Immediate irreversible deletion | ❌ | HIGH |
| Password hashing: bcrypt | privacy_policy_en.md:229 | Firebase Auth (scrypt, not bcrypt) | ❌ | HIGH |
| Algolia active processor | privacy_policy_en.md:131 | Feature-flagged off | ⚠️ | MEDIUM |
| OCR.space processor | Not listed | Active in ocr_extraction_service.dart | ❌ | MEDIUM |
| Security logs: 90 days | privacy_policy_en.md:172 | 90/180/365 days (3 conflicting values) | ⚠️ | MEDIUM |
| Analytics: 14 months | privacy_policy_en.md:170 | Google platform default, not configurable | ✅ | OK |
| Firebase processor | privacy_policy_en.md:113 | Confirmed in pubspec.yaml | ✅ | OK |
| Art. 15 data access | privacy_policy_en.md:183 | DataExportService implemented | ✅ | OK |
| Art. 17 account deletion | privacy_policy_en.md:191 | AccountDeletionService implemented | ✅ | OK |
| Art. 20 data portability | privacy_policy_en.md:196 | JSON export implemented | ✅ | OK |
| Art. 7.3 consent withdrawal | privacy_policy_en.md:205 | ConsentManagementView implemented | ✅ | OK |
| AI consent required | privacy_policy_en.md:127 | aiProcessing consent enforced in code | ✅ | OK |
| Data never sold | privacy_policy_en.md:147 | No sales mechanism exists | ✅ | OK |
| IMY as supervisory authority | privacy_policy_en.md:214 | Correctly identified | ✅ | OK |

---

## Master Checklist

```
PRIVACY POLICY
[✅] EN and SV versions semantically equivalent
[❌] Third-party processor list matches code (Mistral→Gemini wrong, OCR.space missing)
[❌] AI provider correctly named (says Mistral, should say Gemini)
[❌] Cookie section removed/rewritten for mobile (Section 11 is inapplicable)
[⚠️] Algolia status accurately reflects feature-flag state
[❌] OCR.space listed as processor (currently missing)
[❌] Data retention periods match implementations (3 values conflict)
[⚠️] All collected data categories listed (device info, FCM tokens need review)
[❌] Google/Apple login section removed (feature doesn't exist)
[❌] BCrypt claim corrected (Firebase Auth uses scrypt)
[❌] Consent log 3-year retention implemented or claim removed
[❌] 30-day account backup implemented or claim removed

TERMS OF SERVICE
[✅] Age requirement correct for Swedish GDPR (13)
[✅] Jurisdiction correctly states Swedish law
[⚠️] AI processing disclosed (but wrong provider name)
[✅] Data ownership clearly stated
[✅] Account deletion described
[✅] EN and SV versions semantically equivalent
[❌] Version number added to ToS
[❌] Typo fixed in SV version (veckomenyerr → veckomenyer)

COMMUNITY GUIDELINES
[✅] Covers required categories (harassment, spam, copyright, impersonation)
[✅] References reporting mechanism
[✅] Describes enforcement consequences
[✅] EN and SV versions semantically equivalent

LICENSES
[⚠️] pubspec.yaml dependencies — mostly OK, freeRASP EULA needs review
[✅] functions/package.json — all Apache 2.0 or MIT
[❌] Font OFL-1.1 license files bundled in assets/fonts/
[❌] Illustration provenance documented
[⚠️] ONNX model license verified
[✅] Open-source license page accessible in app

AI COMPLIANCE
[✅] AI consent (aiProcessing) gates Gemini calls
[⚠️] PII scrubber covers email/phone/personnummer (gaps: names, addresses)
[❌] All references to AI provider name are correct
[❌] Image OCR PII limitation disclosed in privacy policy
[❌] EU AI Act transparency indicator in UI

APP STORE
[❌] iOS ITSAppUsesNonExemptEncryption correct (false → should be true/exempt)
[⚠️] iOS Privacy Manifest — exists but potentially incomplete
[❓] Google Play Data Safety (verify in Play Console)
[✅] Age rating consistent (13+ in ToS and privacy policy)

CONSENT MODEL
[✅] aiProcessing enforced
[✅] analytics enforced
[❌] pushNotifications enforced (never checked in FCM code)
[❌] socialFeatures enforced (never checked anywhere)
[❌] marketing connected to real system (orphaned)
[❌] aiProcessing comment updated (Mistral → Gemini)

FIREBASE / HOSTING
[❌] Firebase Hosting security headers added
[⚠️] Cloud Functions region comments corrected (Belgium, not Stockholm)
[❓] Firestore data residency verified via Console

ACCEPTANCE MECHANISM
[❌] ToS/Privacy Policy checkbox at registration (currently only age checkbox)
[⚠️] Legal docs accessible from auth screen (currently no links)
```

---

## Phase 2 Preparation

### Issue Count Summary

| Severity | Count | Estimated Total Effort |
|----------|-------|----------------------|
| CRITICAL | 4 | 6-10 hours |
| HIGH | 7 | 14-28 hours |
| MEDIUM | 8 | 8-14 hours |
| LOW | 5 | 2-3 hours |
| **Total** | **24** | **30-55 hours** |

### Recommended Remediation Sequence

**Sprint 1: "Fix the Docs" (1-2 days)**
Quick wins — all privacy policy/ToS text corrections:
1. Replace "Mistral AI" with "Google Gemini" everywhere (C1, C3, M11)
2. Remove Google/Apple login paragraph (C2)
3. Remove cookie Section 11 (H1)
4. Fix bcrypt claim (H4)
5. Add OCR.space to processor list (M2)
6. Fix consent log/backup retention claims (H2, H3)
7. Fix Algolia qualifier (M1)
8. Add image OCR PII disclosure (H9)
9. Fix SV typo (M5)
10. Add version numbers to ToS/guidelines (M4)
11. Update all code comments (Mistral → Gemini)

**Sprint 2: "Consent + Compliance" (2-3 days)**
Code changes for consent integrity:
1. Add ToS/Privacy acceptance checkbox to registration (H5)
2. Enforce `pushNotifications` consent in FCM service (H10)
3. Either enforce or remove `socialFeatures` consent (H11)
4. Remove `marketing` consent purpose (M10)
5. Fix iOS encryption declaration (C4)
6. Add Firebase Hosting security headers (M12)

**Sprint 3: "Assets + AI" (1-2 days)**
License compliance and AI improvements:
1. Bundle OFL license files for fonts (H6)
2. Document illustration provenance (H7)
3. Document ONNX model license (M6)
4. Review freeRASP EULA (M7)
5. Expand PII scrubber (H8)
6. Review/update iOS Privacy Manifest (M9)

**Sprint 4: "Nice to Have" (1 day)**
Low-priority cleanup:
1. Add AI transparency indicator in UI (M8)
2. Fix region comments in Cloud Functions (L4)
3. Verify Firestore data residency (L5)
4. Verify app store age ratings (L3)
5. Add företagsuppgifter to app

**External Actions (Parallel):**
- Verify Firestore database region in Firebase Console
- Review Talsec/freeRASP commercial terms
- File iOS encryption self-classification if needed
- Verify Google Play Data Safety section accuracy
