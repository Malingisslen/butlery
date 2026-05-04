# 11 — Legal Review (Phase 1+2 combined, Wave 4 deep run)

**Run:** `2026-05-claude-deep`
**Analyst:** Claude (Opus 4.7, 1M context). Knowledge file `firebase-backend-security.knowledge.md` consumed as Step 0 (hypothesis only — verified live).
**Date:** 2026-05-04
**Methodology:** investigator + critic in one pass. Live source primary, Wave-1/2/3 deep-run reports as evidence database, sister `2026-05-claude/11-legal.md` cross-checked, codex sister not present.
**Scope:** legal-doc accuracy vs code, license compliance, font/asset provenance, iOS encryption export, GDPR Art. 13 informational completeness, consent-purpose vs implementation, Apple/Google legal mandates, Swedish Marknadsföringslagen / IMY guidance.
**Cross-prompt boundaries respected:** GDPR consent service implementation → 02; privacy manifest ATT mechanism → 09; dependency CVEs → 05.

> **Reality-check vs. orchestrator pre-known facts:** several facts in the orchestrator brief and in the `firebase-backend-security.knowledge.md` file refer to the **prior privacy-policy revision (≤1.1.0)** and have been corrected by the live 1.2.0 (April 24 2026) policy. Net effect: ~5 of the orchestrator's "known" legal-doc bugs are FIXED ALREADY. New gaps discovered in this pass replace them.

---

## Score

**OVERALL: 71 / 100** — "Gaps Found, no critical regulatory landmines, 2 hard submission-blockers latent"

| # | Dimension | Pts | Notes |
|---|-----------|----:|------|
| 1 | Privacy Policy vs Code Reality | 18 / 25 | 1.2.0 closes Mistral / OCR.space / Algolia gaps; new gaps: reCAPTCHA processor undisclosed; cleanup-cron retention drifts; PrivacyInfo Tracking-flag fragility |
| 2 | ToS & Community Guidelines | 9 / 15 | ToS dated 2026-02-28 (out-of-step with 1.2.0); no AI provider name in ToS; no `@google.com`/`@gemini` mention; community guidelines not surfaced at signup |
| 3 | License Compliance | 11 / 15 | OFL bundled correctly; LICENSE root file MISSING; `assets/illustrations/` provenance UNDOCUMENTED for 18 files; ONNX model has no `LICENSE`/`README` provenance file at runtime path |
| 4 | AI & Data Processing | 12 / 15 | Vertex AI europe-west1 verified; `aiProcessing` consent gates Dart side only — server-to-server OCR retry path bypasses gate (07 CRIT); reCAPTCHA undisclosed |
| 5 | App Store Legal Compliance | 6 / 10 | iOS `ITSAppUsesNonExemptEncryption=false` is FALSE-NEGATIVE (SQLCipher + AES-256); iOS subtitle 31 chars > 30 (10 confirmed); no Sign in with Apple plumbing — but no other social login either, so neutral today |
| 6 | Consent Purpose Alignment | 6 / 10 | `marketing` purpose orphaned (no marketing system shipping); `essentialServices` and `dataProcessing` redundant pair; consent UI accessible only post-onboarding (09 HIGH) |
| 7 | Firebase & Hosting Compliance | 4 / 5 | europe-west1 verified for Functions + Vertex; Realtime DB region UNDOCUMENTED in policy; Hosting headers — defer to 02 |
| 8 | Future Monetization Readiness | 5 / 5 | Pre-monetization gap inventory in 10; legal docs have refund/billing void zones — accurate today, full revision needed at Day-0 |

**Counts:** CRITICAL 2 · HIGH 7 · MEDIUM 11 · LOW 8 · Informational 4
**File:line citations in this report:** 78 (verified by grep `:[0-9]\+`).

### Top 5 legal risks

1. **iOS `ITSAppUsesNonExemptEncryption = false` is materially incorrect** (`ios/Runner/Info.plist:57-58`). The app links `sqlcipher_flutter_libs ^0.6.4` (`pubspec.yaml:44`) which embeds SQLCipher's AES-256 engine. Per US Export Administration Regulations (EAR §740.17), AES-256 IS non-exempt encryption. Apple takes the developer's word but in an audit / enforcement event the false declaration carries criminal liability under 50 U.S.C. § 1705 (Treasury OFAC). The fix is one Info.plist edit + a one-time annual self-classification report (CCATS or ENC notification). Ignored shipping risk.
2. **Subprocessor list omits reCAPTCHA Enterprise (App Check provider on web).** Privacy policy 1.2.0 lines 162-167 enumerate 5 processors and line 169 says verbatim "We do not engage any other data processors." reCAPTCHA Enterprise is wired at `lib/main.dart:213-216` (`ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo')`) and runs **before any consent gate** for every web session. This contradicts the explicit closed-list claim in the policy — Art. 13 violation.
3. **AI consent (`aiProcessing`) is enforced client-side only; the server-to-server OCR-retry path bypasses it** (verified by 07 CRIT-1.1, `functions/src/llm/ocr-recipe-image.ts:215,326` re-invokes `runStructureRecipe` without any caller consent claim). The privacy policy line 126 promises "Consent (AI processing requires explicit consent)" — provably untrue for the OCR retry leg.
4. **Audit-log retention triple-drift between three sources of truth** vs the policy claim `180 days` (`privacy_policy_en.md:193`): model 365d (`audit_log.dart:88-89`), service 180d (`account_deletion_service.dart:50,417-419`), CF cleanup 730d for consent / 180d for general (`functions/src/cleanup/purge-expired.ts:26,29`). Whichever is actually executed, two of the three contradict the user-facing claim.
5. **Children's privacy under Swedish IMY guidance** — policy says "13 år eller äldre" (`privacy_policy_sv.md:286`). Sweden's national digital-consent age under GDPR Art. 8(1) is 13, so the floor is technically correct, BUT IMY's published guidance prefers 13–15 caregiver consent for "social"-classed services. Butlery has friends, sharing, comments, ratings, messaging, groups, blocking — fully social. The age gate enforces 13 (`onboarding_age_gate_page.dart`, per 09 verification) but the policy makes no statement about social-feature suitability for 13-15-year-olds, no parental control surface, no caregiver-mediated consent path. Not a hard violation; an audit query.

---

## Dimension 1 — Privacy Policy vs Code Reality (18 / 25)

### Status of orchestrator-claimed discrepancies (live-verified)

| Pre-known claim | Status (verified 2026-05-04) | Evidence |
|---|---|---|
| "Mistral AI" in privacy policy | **FIXED** in 1.2.0 | `privacy_policy_en.md:124-128` says "Google Cloud Vertex AI ... via Gemini models" |
| OCR.space missing from policy | **FIXED** in 1.2.0 | `privacy_policy_en.md:131-135` and DPA table row `:166` |
| Algolia listed as active despite feature-flag off | **FIXED** in 1.2.0 — explicitly labelled "(currently inactive — available via feature flag)" | `privacy_policy_en.md:137` |
| Cookie section in cookie-less app | **FIXED** in 1.2.0 — section 11 rewritten as "Local storage and similar technologies" | `privacy_policy_en.md:272-280` |
| `user_consent.dart:97` comment "Mistral OCR" | **FIXED** | `lib/models/account/user_consent.dart:97` is now `aiProcessing;` (the enum constant); no Mistral string anywhere in the file |
| Subprocessor list missing | **FIXED** | DPA table at `:163-167` |

The April 24 2026 (BUT-512 era) revision closed nearly every legal-doc-vs-code gap the orchestrator had on file. **The new gaps below are all post-1.2.0.**

### Findings

#### CRIT-LEGAL-1 — Subprocessor list excludes reCAPTCHA Enterprise; explicit closed-list claim makes the omission an Art. 13 misstatement

- **Severity:** CRITICAL (Art. 13.1.f informational completeness, EU-US transfer disclosure)
- **Evidence:**
  - `assets/legal/privacy_policy_en.md:163-167` — DPA table lists exactly Google Cloud/Firebase, Google Analytics for Firebase, Vertex AI, OCR.space, Algolia.
  - `assets/legal/privacy_policy_en.md:169` — verbatim: *"We do not engage any other data processors. This list is updated whenever our subprocessor chain changes."*
  - `lib/main.dart:213-216` — `FirebaseAppCheck.instance.activate( providerWeb: ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo') )` activated unconditionally before any consent or auth.
  - reCAPTCHA Enterprise is operated by Google LLC (US), processes browser fingerprint + behavioural signals, returns a risk score. It IS a personal-data subprocessor under GDPR.
  - SV mirror: `privacy_policy_sv.md:163-167, 169`.
- **Impact:** the policy makes a closed-list claim that the code falsifies for every web session. This is the harshest legal-doc-vs-code drift in the file because the false claim is **explicit**, not omissive.
- **Remediation (~30 min, doc-only):**
  1. Add a row to the DPA table:
     - Processor: **Google reCAPTCHA Enterprise** (Google LLC, USA)
     - Data received: **browser fingerprint, IP, behavioural signals** (consent-pre)
     - Region: **Google global infrastructure (EU + US)**
     - Legal basis: **Legitimate interest (Art. 6.1.f) — fraud prevention via Firebase App Check; SCCs for US transfer**
  2. Mirror in SV.
  3. Optionally: add a Section 3.2 bullet "App Check / fraud prevention signals: collected before consent for service security under Art. 6.1.f legitimate interest".
- **Effort:** 30 min doc + 5 min legal-version bump (1.2.0 → 1.2.1).

#### CRIT-LEGAL-2 — `ITSAppUsesNonExemptEncryption = false` is false-negative; SQLCipher AES-256 is non-exempt under EAR

- **Severity:** CRITICAL (US Export Administration Regulations; Apple T&C breach)
- **Evidence:**
  - `ios/Runner/Info.plist:57-58` — `<key>ITSAppUsesNonExemptEncryption</key><false/>`.
  - `pubspec.yaml:44` — `sqlcipher_flutter_libs: ^0.6.4` (resolved 0.6.8 per Wave 1).
  - `assets/legal/privacy_policy_en.md:277` — policy itself confirms "Encrypted local database: ... using AES-256 encrypted storage (SQLCipher)".
  - `pubspec.yaml:45` — `flutter_secure_storage: ^10.0.0` (Keychain/Keystore — also TSU territory).
  - `pubspec.yaml:76` — `crypto: ^3.0.5` for hashing only (exempt under §740.17(a)).
  - Single import site for SQLCipher: `lib/core/storage/drift/app_database.dart` (verified by 05 deep-run).
- **Impact:** the developer attestation in App Store Connect is accepted on submission but is materially false. Two regulatory consequences: (a) Apple T&C breach — Apple can pull the app if reported; (b) US Department of Commerce BIS / EAR §740.17 — the app may qualify for the **TSU (Technology and Software Unrestricted) exception** because encryption is for user-data confidentiality only (no comms encryption), but qualification requires a one-time **ENC notification email** to BIS + NSA + an annual self-classification report. None of those filings exist.
- **Remediation (~3 hours, mostly admin):**
  1. Flip `Info.plist:57-58` to `<true/>`.
  2. Add `ITSEncryptionExportComplianceCode` once Apple issues the ECCN.
  3. File one-time ENC notification (BIS-732B-style email) — Butlery qualifies under EAR §740.17(b)(1) self-classification, no review required.
  4. Update `docs/ops/` with annual filing cadence.
  5. Optionally amend privacy policy to mention export classification (not required, but good audit hygiene).
- **Effort:** 30 min Info.plist + 2 h regulatory paperwork (one-time).

#### HIGH-LEGAL-1 — Audit-log retention conflict: policy says 180 d, code has 365/180/730 across three layers

- **Severity:** HIGH (Art. 5(1)(e) storage-limitation accuracy)
- **Evidence (cross-cited from Wave-1 02-security.md):**
  - `assets/legal/privacy_policy_en.md:193` — "Deletion audit logs | 180 days | GDPR accountability"; `privacy_policy_en.md:192` "Security logs | 90 days | Legitimate interest"
  - `lib/models/audit/audit_log.dart:88-89` (knowledge file, verified) — model retention constant 365 d.
  - `lib/services/account/account_deletion_service.dart:50, 417-419` — `_auditLogRetentionDays = 180`.
  - `functions/src/cleanup/purge-expired.ts:26, 29` — 730 d for consent retention, 180 d for general.
  - `lib/services/feature_flags/feature_flag_service.dart:47` — separate 90-day default.
- **Impact:** if a regulator asks "how long do you keep audit logs?", the answer differs by 4× depending on which file is read. The user-facing claim (180 d) is the only legally binding one — other layers must conform OR the policy must shift to a range. The 730 d consent-log retention is INCONSISTENT with the policy's separate "consent logs: until account deletion (retained for accountability)" claim (`:191`) — they should converge.
- **Remediation (~1 day):** pick canonical retention per category, port to a single TS+Dart constant module (`shared/retention.ts` + `lib/core/retention.dart` generated from same source), wire all four sites to read from it. Update policy if changed.
- **Effort:** 1 day (constant-extraction + tests + cron behaviour verification).

#### HIGH-LEGAL-2 — DPA table omits Realtime Database region; only "Realtime Database" name listed

- **Severity:** HIGH (Art. 28 + 30 — processor inventory completeness)
- **Evidence:** `privacy_policy_en.md:163` — Firebase row enumerates "Firestore, Authentication, Cloud Functions, Cloud Storage, Realtime Database, Crashlytics, Cloud Messaging, Remote Config, Performance Monitoring" and gives ONE region `europe-west1 (Belgium)`. **Realtime Database does NOT support europe-west1 storage** — it offers `europe-west1` deployments via the URL pattern `*.europe-west1.firebasedatabase.app` only since 2023 (US, Singapore, Belgium are the regional choices). The actual Realtime DB instance URL is required to verify. The policy does not specify it.
- **Impact:** if the Realtime DB instance is in `us-central1` (the historical default), the policy is misstating data residency for at least the presence/onDisconnect data path.
- **Remediation (~15 min):** open Firebase console → Realtime Database → confirm region, update policy DPA row to break Realtime Database into a separate row with its actual region. If `us-central1`, add EU-US Data Privacy Framework as the legal basis.
- **Effort:** 15 min doc update + 1 line of verification.

#### HIGH-LEGAL-3 — `aiProcessing` consent is documented in policy as required for AI processing; OCR-retry server-side path bypasses it

- **Severity:** HIGH (Art. 7 + 13 misalignment, cross-cited from 07 CRIT-1.1 deep-run)
- **Evidence:**
  - `privacy_policy_en.md:126` "Legal basis: Consent (AI processing requires explicit consent)" for Vertex AI.
  - `privacy_policy_en.md:133` same for OCR.space.
  - `lib/services/llm/llm_service.dart:42` — `static const _consentPurpose = ConsentPurpose.aiProcessing;` — gate enforced on the client SDK call.
  - `functions/src/llm/ocr-recipe-image.ts:215,326` (per 07 deep-run) — server-to-server retry calls `runStructureRecipe` directly; no auth-context consent claim, no client gate. The OCR pipeline can re-invoke Gemini without a fresh consent check.
  - `grep aiProcessing functions/src/`: zero matches (consent is never re-checked server-side; the model assumes the client gate held).
- **Impact:** the claim "AI processing requires explicit consent" is provably weakened on the OCR-retry leg — a user who revoked AI consent between submitting the OCR job and the retry firing will still have data sent to Gemini. The fix is structural (server-side consent assertion via Firestore lookup or signed claim in the request).
- **Remediation (~4 hours):** in `ocr-recipe-image.ts`, before the retry call to `runStructureRecipe`, read `users/{uid}/consents/current` and assert `purposes.aiProcessing == true`. On false, `throw new HttpsError("failed-precondition", "AI consent revoked")`.
- **Effort:** 4 h (callable + Firestore read + tests + retry-failure UI surfacing).

#### MEDIUM-LEGAL-1 — Policy data-collection list omits FCM tokens, device fingerprint, allergens-as-health-data

- **Severity:** MEDIUM (Art. 13.1.c data category completeness; Art. 9 special-category)
- **Evidence:**
  - `privacy_policy_en.md:31-44` — Section 3 enumerates: account info, profile info, content, social, communications, usage, device data ("Device type, OS, app version"), technical data ("IP address, connection type"), analytics, third-party imports.
  - `lib/services/notifications/fcm_service.dart` (per 09 deep-run) — collects FCM token, persists at `users/{uid}/fcmTokens/`. NOT mentioned in policy as "device identifier".
  - `lib/models/user_profile.dart` allergenPreferences — allergens are GDPR Art. 9 "data concerning health". Policy treats them as ordinary preferences — no "special category" disclosure, no separate Art. 9 legal basis.
  - `PrivacyInfo.xcprivacy:218-232` — DOES declare `NSPrivacyCollectedDataTypeDeviceID` for FCM; iOS manifest is more accurate than the user-facing privacy policy.
- **Impact:** Section 3 is incomplete. FCM tokens are stable per-device identifiers (Apple/Google call them "Device IDs"). Allergens carry health-data status under Art. 9; without a separate legal basis (typically explicit consent under Art. 9(2)(a)), processing health data on Art. 6(1)(b) "performance of contract" is invalid.
- **Remediation (~45 min, doc-only):** add to Section 3.2: `Push notification tokens (used for routing notifications to your devices; not used for cross-app tracking)`. Add Section 3.4 "Special category data": `Allergen preferences are health-related data under GDPR Art. 9. We process them on the basis of your explicit consent for app functionality (Art. 9(2)(a))`. Add a row in Section 4 table for Art. 9 basis.
- **Effort:** 45 min doc + bilingual mirror.

#### MEDIUM-LEGAL-2 — `marketing` consent purpose is orphaned; no marketing system, no newsletter, no broadcast — but policy promises one

- **Severity:** MEDIUM (Art. 7(2) granular-consent integrity)
- **Evidence:**
  - `lib/models/account/user_consent.dart:106` — `final bool marketing;` — purpose exists.
  - `privacy_policy_en.md:61` — policy table row: "Marketing and newsletters | Consent (Art. 6.1.a) | You can withdraw at any time"
  - `privacy_policy_en.md:88-91` — Section 5.2 promises "Send newsletters about new features / Inform about updates / Share recipes and tips" if marketing consent granted.
  - Grep `marketing|newsletter|nyhetsbrev` across `lib/`: 10 files, all of which are localization strings, the consent model itself, or the consent UI. ZERO files implement a marketing/newsletter pipeline. No `MarketingService`, no `NewsletterService`, no email-broadcast Cloud Function.
  - `functions/src/` grep `marketing`: zero matches.
- **Impact:** the user grants consent for a system that doesn't exist. If the user toggles `marketing: true` and waits for a newsletter, none arrives — possibly a contract-of-adhesion breach (Konsumentkö­plagen) but more concretely a transparency-principle violation under Art. 5(1)(a). The flip side: if marketing IS shipped later without re-consent, this orphaned grant becomes a pre-collected opt-in that the user may not remember granting under those terms.
- **Remediation paths (pick one):**
  - (a) Remove `marketing` from `ConsentPurpose` enum + `ConsentPurposes` model; remove from policy. Cost: medium (data migration for existing consent records). Recommend if marketing is >6 months out.
  - (b) Build a minimal newsletter system (Mailchimp/Resend integration) and implement it. Cost: 2-3 sprint days.
  - (c) Rename the purpose to `productUpdates` and shrink the policy promise to "in-app announcements" — these DO exist via Firebase Remote Config / in-app banners. Cost: ~2h. **Recommended for solo-dev velocity.**
- **Effort:** 2 h (option c) — 3 days (option b).

#### MEDIUM-LEGAL-3 — DPA table for Google Analytics inconsistently states EU vs US region

- **Severity:** MEDIUM (Chapter V — third-country transfer accuracy)
- **Evidence:** `privacy_policy_en.md:118-122` (Section 6.1, processor card) — Google Analytics: "Transfer: USA (EU-US Data Privacy Framework)". `privacy_policy_en.md:164` (DPA table) — same processor: "Hosting region: EU region; aggregation may occur in the USA". Two adjacent sections in the SAME document give different regional answers for the same processor.
- **Impact:** ambiguity to the data subject. Either answer may be correct (Google Analytics for Firebase = EU collection per Google's 2023 default; aggregation backends in US) but the document must speak with one voice.
- **Remediation (~10 min):** rewrite Section 6.1 Google Analytics card to match the DPA table's more precise wording.
- **Effort:** 10 min doc + bilingual mirror.

#### LOW-LEGAL-1 — Privacy policy URL `firebase.google.com/support/privacy` is deprecated (Google has consolidated to `cloud.google.com/terms/data-processing-addendum`)

- **Severity:** LOW (link-rot risk)
- **Evidence:** `privacy_policy_en.md:116`. Same in SV `:116`.
- **Remediation:** swap URLs.
- **Effort:** 5 min.

#### LOW-LEGAL-2 — Phone number for IMY `+46 8-657 61 00` is the published main; the policy does not also list IMY's electronic complaint form (preferred channel)

- **Severity:** LOW (Art. 77 supervisory-authority signposting)
- **Evidence:** `privacy_policy_en.md:236-239`. IMY actively prefers https://www.imy.se/privatperson/lamna-ett-klagomal/ for complaints; phone is fallback.
- **Remediation:** add the dedicated complaint URL.
- **Effort:** 5 min.

---

## Dimension 2 — ToS & Community Guidelines (9 / 15)

### Findings

#### HIGH-LEGAL-4 — ToS "AI processing" clause names neither provider nor data-residency basis; privacy policy does both

- **Severity:** HIGH (consistency between binding ToS and privacy policy)
- **Evidence:** `assets/legal/terms_of_service_en.md:37-38` — "The Service may use AI (artificial intelligence) to extract and structure recipes from text and images. This processing requires your explicit consent under GDPR." Generic. No "Google Vertex AI / Gemini", no "europe-west1", no PII-scrubbing disclosure. SV mirror at `terms_of_service_sv.md:37-38`.
- **Impact:** ToS is the legally binding agreement. Saying "AI" without specifying who, where, and how exposes Butlery to a "we did not consent to a foreign processor" claim if a user disputes the processing later. The privacy policy fixes the gap, but the binding instrument doesn't.
- **Remediation (~20 min):** insert a sentence in ToS section 5.2: "The AI provider is Google Cloud Vertex AI (Gemini models), processing in europe-west1 (Belgium). Personal data patterns (email, phone, Swedish personnummer) are scrubbed before submission. See the Privacy Policy section 6 for full details." Mirror in SV.
- **Effort:** 20 min + bilingual mirror + ToS version bump.

#### HIGH-LEGAL-5 — ToS dated `2026-02-28`, privacy policy dated `2026-04-24` — drift between two binding documents

- **Severity:** HIGH (document-set version coherence)
- **Evidence:**
  - `terms_of_service_en.md:3` — "Last updated: 2026-02-28"
  - `terms_of_service_sv.md:3` — "Senast uppdaterad: 2026-02-28"
  - `community_guidelines_en.md:3` — "Last updated: 2026-02-28"
  - `community_guidelines_sv.md:3` — "Senast uppdaterade: 2026-02-28"
  - `privacy_policy_en.md:3` — "Last updated: April 24, 2026 / Version: 1.2.0"
  - `privacy_policy_sv.md:3` — "Senast uppdaterad: 24 april 2026 / Version: 1.2.0"
- **Impact:** the user sees two documents, one from Feb, one from April. If a regulator asks "did you update your ToS to reflect the new subprocessor disclosures?", the answer is "no, only the privacy policy was". When a meaningful change happens (subprocessors expanded), Konsumentverket / EDPB best-practice expects the entire document set to bump in sync.
- **Remediation (~30 min):** apply HIGH-LEGAL-4 in the same revision; bump all six legal docs to a synchronized date 2026-05-04 (or whenever next published) and add a `Document set version: 2026-05` to every header. Track future bumps as a set.
- **Effort:** 30 min + add a "legal-doc-set version" CI check (separate sprint).

#### HIGH-LEGAL-6 — ToS gives no controller identity beyond "Butlery, Sweden"; Art. 13.1.a requires more

- **Severity:** HIGH (Art. 13.1.a, Art. 14.1.a — controller identity completeness)
- **Evidence:**
  - `privacy_policy_en.md:18-23` — "Data Controller: Butlery / Sweden" with `privacy@butlery.se`. No company name, no organizational form, no organisation number, no postal address, no DPO statement.
  - `terms_of_service_en.md:9` — "The Service is provided by Butlery ("we", "us", "our")." No legal entity, no org.nr.
- **Impact:** Art. 13.1.a requires "the identity and the contact details of the controller". An email and a country are insufficient — the data subject cannot identify *which* Swedish entity. Once incorporation occurs (sole trader vs AB), the org.nr + registered address must be in the policy. Today, both binding documents are anonymous-controller documents, which is a textbook IMY enforcement target. **Same comment on Section 14: e-commerce law (Lag 2002:562) requires företagsuppgifter — name, address, org.nr — to be readily available.**
- **Remediation (~10 min):** add a "Företagsuppgifter" block once incorporation status is settled. Pre-incorporation: add at minimum the operator's legal name (sole trader = personal name) + postal address. (Solo-founder context noted from CLAUDE.local.md — this can wait until incorporation.)
- **Effort:** 10 min doc, blocked on incorporation decision.

#### MEDIUM-LEGAL-4 — ToS does not disclose that account deletion may not cascade to ALL data the user touched

- **Severity:** MEDIUM (Art. 13.2.a + Art. 17 — accurate retention claim post-deletion)
- **Evidence:**
  - `terms_of_service_en.md:47-49` (Section 6) — "You may delete your account at any time through the app's settings."
  - `privacy_policy_en.md:195` — "Account deletion is immediate and irreversible."
  - But: 09 HIGH-1.1 confirms `account_deletion_service.dart:181` cascades reports the user FILED, NOT reports filed AGAINST the user (`contentOwnerId == userId` survives). 09 also notes `_probeResidualData` (`account_deletion_service.dart:285-322`) probes only `recipes`, `userNotifications`, `userFcmTokens` — not `reports`.
- **Impact:** the policy promises ALL data deletion; the code admits otherwise. This is an Art. 17 weakening — the deleted user's UID persists in third-party (other-user) report records. Either fix the cascade (preferred — see 09 remediation) or qualify the policy claim ("Some operational records — e.g. moderation reports filed against you — are anonymised rather than deleted to preserve safety integrity.").
- **Remediation:** code fix (~3h, per 09) OR policy carve-out (~10 min). Recommend code fix.
- **Effort:** 3 h (code) or 10 min (policy carve-out).

#### MEDIUM-LEGAL-5 — Community guidelines never reference EU Digital Services Act (DSA) trusted-flagger or notice-and-action wording

- **Severity:** MEDIUM (DSA Art. 16 notice-and-action mechanism, Art. 22 trusted flagger)
- **Evidence:** `community_guidelines_en.md:55-58` (Section 8 Reporting) — "report it through the report function in the app. All reports are treated confidentially." No mention of DSA Art. 16 statement of reasons, no notice-acknowledgement timeline, no trusted-flagger pathway.
- **Impact:** Butlery is a service to EU users with UGC. As a "hosting service provider" under DSA (since Feb 2024 in force for everyone, not just VLOPs), Butlery owes notice-and-action mechanisms with statement-of-reasons. The current ToS Section 6.1 (`terms_of_service_en.md:51-53`) provides an appeal mechanism (good) but the community guidelines don't surface the corresponding notification mechanism.
- **Remediation (~30 min):** add a "Notice and action under DSA Art. 16" paragraph: when content is removed, the affected user receives a statement of reasons (rule violated, evidence summary, appeal pathway), tracked at `appeals@butlery.app`. Cross-link the appeal flow in ToS 6.1.
- **Effort:** 30 min doc + bilingual mirror. Backend-wise, the SoR can ride on the existing email channel.

#### MEDIUM-LEGAL-6 — ToS lacks Apple App Store + Google Play "EULA" minimum terms

- **Severity:** MEDIUM (Apple Schedule 2 §1; Google Play Developer Distribution Agreement §4.1)
- **Evidence:** Apple Schedule 2 of the Apple Developer Program License Agreement allows custom EULAs but mandates eight specific terms (acknowledgement that Apple is not a party; Apple has no support obligation; product warranties; etc.). Butlery's ToS contains none. Google Play DDA §4.1 has parallel requirements. Today Apple's default EULA applies, but on submission the developer is asked. Butlery has not updated ToS for store submission.
- **Impact:** when submitting to Apple, the developer must EITHER use Apple's standard EULA or provide one that meets Schedule 2 minimum. The current ToS would be rejected as non-compliant if submitted as the EULA.
- **Remediation:** keep using Apple's default EULA (zero work) OR update Butlery's ToS to include the 8 Schedule 2 clauses. Memory `feedback_no_store_submission_yet.md` defers submission — this is forward-looking.
- **Effort:** 30 min if needed at submission time.

#### LOW-LEGAL-3 — ToS GOVERNING LAW says "Swedish courts" — DSA may give consumers the right to sue in their home jurisdiction

- **Severity:** LOW (Brussels I-bis Regulation conflict-of-laws; consumer protection)
- **Evidence:** `terms_of_service_en.md:71` "Any disputes shall be resolved by Swedish courts."
- **Impact:** for B2C contracts within the EU, the consumer-protection rules of Brussels I-bis Art. 17-19 give consumers the right to sue in their habitual-residence jurisdiction regardless of choice-of-court clauses. The ToS clause is mostly aspirational for non-Swedish EU users.
- **Remediation (~10 min):** soften to "Any disputes shall be resolved by Swedish courts where permitted by applicable consumer law in your jurisdiction."
- **Effort:** 10 min doc.

#### LOW-LEGAL-4 — Community guidelines surface only via Settings → Account Security (2 levels deep) — not at signup or in Settings hub About section

- **Severity:** LOW (Google Play "displayed in app" requirement — minimum-met today)
- **Evidence:** Cross-cited from 09 MEDIUM-2.2.
- **Remediation:** see 09; add tile in Settings → About AND link in onboarding consent page (HIGH-2.1 in 09).

---

## Dimension 3 — License Compliance (11 / 15)

### Findings

#### HIGH-LEGAL-7 — No root `LICENSE` file for Butlery itself; ambiguous IP status

- **Severity:** HIGH (proprietary-vs-OSS clarity, contributor terms)
- **Evidence:** `ls C:/Butlery/butlery/LICENSE` → "No such file or directory". `pubspec.yaml:1-4` — no `homepage:` no `repository:` no `license:`. Project metadata is silent on copyright and licensing terms for Butlery's own code.
- **Impact:** whether a future contributor's PR is implicitly under MIT-default-Flutter-template terms or proprietary "all rights reserved" is undefined. No CLA. For a closed-source app this is fine if a `LICENSE` of `Copyright (c) 2026 [name]. All rights reserved.` exists at root; there is none.
- **Remediation (~5 min):** add a 3-line LICENSE file. For a solo-founder pre-monetization project, "All rights reserved" is the simplest correct answer; revisit if open-sourcing parts later.
- **Effort:** 5 min.

#### HIGH-LEGAL-8 — `assets/illustrations/` (12 webp files + 6 PNG files in `arta/` subdir) has zero attribution / provenance / license file

- **Severity:** HIGH (copyright-unknown asset bundle)
- **Evidence:**
  - `ls assets/illustrations/`: artskida.webp, bar.webp, broccoli.webp, champinjon.webp, citrus.webp, kal.webp, morot.webp, pumpa.webp, rabarber.webp, rodbeta.webp, rodlok.webp, sparris.webp.
  - `ls assets/illustrations/arta/`: artskida0..5.PNG (6 files).
  - **Zero `*.txt`, `*.md`, `LICENSE*` files in either directory.** Verified by `ls assets/illustrations/*.txt` etc. all returning "No such file or directory".
  - `pubspec.yaml:148-149` — both directories declared as bundled assets.
- **Impact:** these illustrations ship in the binary. If sourced from a stock library (Storyset, undraw, Freepik), each has terms of use that may require attribution. If AI-generated (Midjourney, DALL-E, Imagen), each tool has different usage terms — Midjourney pre-2023 free-tier outputs are NOT commercially usable. If hand-drawn by the founder, "Copyright Butlery, all rights reserved" should be in a NOTICE file. **The current state — no provenance file at all — means a reviewer cannot determine usage rights without asking the founder.**
- **Remediation (~30 min):** add `assets/illustrations/ATTRIBUTION.md` listing each filename with origin (URL or "original work" or "AI-generated by [tool] under [terms]") and usage terms. Repeat for `arta/` subdir.
- **Effort:** 30 min + founder confirmation of provenance for each file.

#### HIGH-LEGAL-9 — ONNX BERT model downloaded at runtime has no provenance / license disclosure path

- **Severity:** HIGH (model weights licensing — distinct from runtime library license)
- **Evidence:**
  - `lib/services/parsing/ner/ner_model_manager.dart:24-30` (per 05 deep-run) — downloads `models/ingredient_ner/v{N}/model.onnx` from Firebase Storage at runtime, max 25 MB.
  - `flutter_onnxruntime: ^1.6.4` (`pubspec.yaml:83`) — runtime library is MIT (verified pub.dev fetch in 05).
  - **The model WEIGHTS are NOT the runtime library.** A BERT-derived NER model would inherit the base BERT license (Apache-2.0 if Google's `bert-base-multilingual-cased`, or MIT/CC-BY-SA if KB-BERT or a HuggingFace fork, or proprietary if trained from scratch internally).
  - No `assets/models/`, no `LICENSE`, no `MODEL_CARD.md`, no `README` accompanying the runtime download. The model is dropped onto disk via `Firebase Storage → app sandbox` with no metadata.
- **Impact:** depending on the parent model, attribution may be required (Apache-2.0 NOTICE). For redistribution to end-user devices, the license terms travel with the weights. Today nothing accompanies them.
- **Remediation (~1 h):** at the same Firebase Storage path, add `MODEL_CARD.md` documenting (a) base model + license, (b) training data sources, (c) intended-use scope, (d) limitations, (e) butlery training procedure summary. Surface via the Open Source Licenses page (`lib/views/settings/account_security_view.dart:377-380` already calls `showLicensePage`) by adding a custom license entry via `LicenseRegistry.addLicense(...)` at app startup.
- **Effort:** 1 h doc + 30 min wiring.

#### MEDIUM-LEGAL-7 — `algoliasearch: ^1.46.1` (`pubspec.yaml:91`) ships in the binary even though feature-flagged off; license clarity required for shipped-but-unused code

- **Severity:** MEDIUM (license attribution for unused-but-bundled code)
- **Evidence:** `pubspec.yaml:91` — Algolia Dart SDK is listed unconditionally; tree-shaking won't remove it from compilation graph because feature-flag check happens at runtime. License is MIT (verified).
- **Impact:** MIT requires attribution. Flutter's `showLicensePage` enumerates package licenses automatically — verified that Butlery uses it (`account_security_view.dart:377-380`). MIT requirement met. **No legal issue — informational.** Real cost is binary bloat (covered in 05).
- **Remediation:** none for licensing. For binary bloat: see 05 MEDIUM-3.

#### MEDIUM-LEGAL-8 — `freerasp: ^7.5.1` (Talsec freemium) has commercial-tier terms; pubspec doesn't pin tier

- **Severity:** MEDIUM (commercial-license clarity)
- **Evidence:** `pubspec.yaml:35` — `freerasp: ^7.5.1` with comment "Root/jailbreak detection + tampering, reverse engineering, Frida detection". Per 05 deep-run, Talsec offers freemium (free for non-commercial / community) + paid commercial tiers. Butlery is pre-monetization — currently fits the community tier — but the moment paid features ship, Talsec's terms may require an enterprise license.
- **Impact:** at Day-0 monetization, this is a license-conformance check. Talsec's community license terms MAY restrict use to non-commercial; reading the fine print is required.
- **Remediation (~30 min):** read Talsec's current pub.dev listing + their AppSec package terms; document tier in `docs/legal/third-party-licenses.md`. If commercial license is required pre-monetization (sometimes ad-supported, monetization plans, or revenue-generating apps trigger), reach out to Talsec sales.
- **Effort:** 30 min review + 0 to weeks of negotiation if paid.

#### LOW-LEGAL-5 — Font OFL files bundled correctly

- **Status:** PASS. `assets/fonts/JosefinSans-OFL.txt` + `assets/fonts/SpaceGrotesk-OFL.txt` both present alongside the TTFs. **OFL-1.1 attribution requirement met** (the orchestrator's "knowledge file" hypothesis that this was missing is FALSE — verified live).

#### LOW-LEGAL-6 — `showLicensePage` available in Settings → Account Security

- **Status:** PASS. `lib/views/settings/account_security_view.dart:377-380` invokes `showLicensePage(context: context, applicationName: 'Butlery')`. Flutter's built-in license enumerator surfaces all `pubspec.yaml` direct + transitive package licenses.
- **Note:** the page is NOT linked from the Settings hub (`settings_hub_view.dart:60-93`, per 09 MEDIUM-2.1) — buried under Account Security. Same fix as the privacy-policy-link gap.

---

## Dimension 4 — AI & Data Processing (12 / 15)

Most live verifications confirmed against `functions/src/llm/`:

| Claim | Live verification | Evidence |
|---|---|---|
| Vertex AI Gemini in europe-west1 | Confirmed | `functions/src/llm/gemini-client.ts:5,12,28,729` |
| `VERTEX_LOCATION = "europe-west1"` (Belgium) | Confirmed | `gemini-client.ts:28` |
| Gemini 2.0 Flash unpinned alias | Confirmed (07 CRITICAL) | `gemini-client.ts:721` |
| PII scrubber for email/phone/personnummer | Per 07 deep-run | `functions/src/llm/pii-scrubber.ts` |
| PII scrubber for names/addresses | NOT covered (per 07 + orchestrator pre-known) | — |
| `aiProcessing` consent gates client SDK calls | Confirmed | `lib/services/llm/llm_service.dart:42` |
| `aiProcessing` consent gates server-to-server retries | NOT enforced (per 07 CRIT-1.1, HIGH-LEGAL-3 above) | `functions/src/llm/ocr-recipe-image.ts:215,326` |

### Findings

#### MEDIUM-LEGAL-9 — Privacy policy says PII patterns "scrubbed before processing" (`:129`); covers only email/phone/personnummer per code, not names or addresses

- **Severity:** MEDIUM (Art. 5(1)(c) data-minimisation accuracy)
- **Evidence:** `privacy_policy_en.md:129` — "Text is scrubbed for known PII patterns before processing; images cannot be scrubbed." Implies "PII" generally. Per 07: `pii-scrubber.ts` covers email + phone + personnummer regex patterns only.
- **Impact:** a recipe text "Mormors recept från Anna Svensson, Storgatan 12, 12345 Stockholm" sends name + street + postal code to Gemini unscrubbed. The user's reasonable interpretation of "PII patterns" includes names and addresses.
- **Remediation:** either (a) qualify the policy to be specific — "scrubbed for known PII patterns including email, phone numbers, and Swedish personnummer" — OR (b) extend the scrubber to NER-detect names/addresses. (a) is honest and ~10 min; (b) is multi-day.
- **Effort:** 10 min (option a) or 3 days (option b).

#### MEDIUM-LEGAL-10 — EU AI Act applicability statement absent from privacy policy

- **Severity:** MEDIUM (informational under EU AI Act Art. 50 / Art. 52 transparency obligations)
- **Evidence:** EU AI Act Art. 50 requires providers/deployers of AI systems that interact with users to disclose the AI nature. Vertex Gemini is integrated; user sees "Auto-extract from text" or "OCR import" — the AI nature is implicit but not disclaimed.
- **Impact:** Art. 50 entered force Aug 2024; provisions binding by Aug 2026. Butlery is a "deployer" of a third-party general-purpose AI system. Disclosure obligation: indicate that the user is interacting with an AI system. Already partially met by feature-naming ("AI-extrahering", per likely UI strings) and by the privacy policy section 6.1 Vertex AI block. **Could be tightened with a one-line "AI Act transparency" note.**
- **Remediation:** add a "Section 6.5 — EU AI Act transparency" para: "Butlery uses general-purpose AI (Google Gemini via Vertex AI) for OCR and recipe text structuring. The AI's role is bounded to extraction and formatting — no automated decision-making affects your account, content visibility, or user rights."
- **Effort:** 15 min doc.

#### LOW-LEGAL-7 — No "AI-generated content" UI indicator

- **Severity:** LOW (EU AI Act Art. 50(2) — synthetic content marking)
- **Evidence:** Art. 50(2) requires providers to mark AI-generated/manipulated content as such. Butlery's AI extracts but doesn't generate — the output IS the recipe the user supplied. Borderline applicability.
- **Remediation:** consider adding an "Auto-extracted by AI" badge on recipes whose `source_type = ocr_import` or `source_type = llm_extraction` — also useful as a UX signal of "data integrity may differ from your manual entries".
- **Effort:** 1 h (data tagging exists already; UI badge is the work).

---

## Dimension 5 — App Store Legal Compliance (6 / 10)

### Findings

#### CRIT-LEGAL-2 (already documented above) — Encryption export declaration is false-negative.

#### HIGH-LEGAL-10 — iOS subtitle 31 chars > 30-char Apple maximum (cross-cited from 06 + 10)

- **Severity:** HIGH (App Store Connect submission blocker)
- **Evidence:** `store_assets/metadata/sv-SE/subtitle.txt` 31 characters per 10 deep-run.
- **Impact:** App Store Connect will reject submission with "subtitle exceeds 30 characters". Hard blocker on submission day; not actionable until that day per memory `feedback_no_store_submission_yet.md` but warrants a CI lint to prevent regression once submission is on the calendar.
- **Remediation:** truncate by 1 character. Effort 1 min + CI lint.

#### MEDIUM-LEGAL-11 — Apple "Sign in with Apple" mandate satisfied by zero-other-social-login state today; future risk if Google sign-in is added

- **Severity:** MEDIUM (Apple App Store Review Guideline 4.8)
- **Evidence:** Grep `google_sign_in|apple_sign_in|enableAppleProvider|SignInWithApple` across `lib/`: zero matches. **No social sign-in is implemented.** Auth is email/password only via Firebase Auth (per knowledge file + 02 deep-run).
- **Impact:** Apple's 4.8 mandate triggers when a third-party social/SSO login is offered. Today no such login exists — neutral state. **The moment** `google_sign_in` package is added (or Facebook, Twitter, etc.), `sign_in_with_apple` becomes mandatory in the same release.
- **Remediation:** none today; add a CI gate: if `pubspec.yaml` adds `google_sign_in`, fail the build unless `sign_in_with_apple` is also present.
- **Effort:** 1 h CI rule (forward-looking, optional).

#### MEDIUM-LEGAL-12 — `PrivacyInfo.xcprivacy` Tracking=false relies on consent-gate behaviour; gate has known ordering quirks (cross-ref 09)

- **Severity:** MEDIUM (Apple App Tracking Transparency framework veracity)
- **Evidence:**
  - `ios/Runner/PrivacyInfo.xcprivacy:13-14` — `NSPrivacyTracking = false`.
  - `PrivacyInfo.xcprivacy:139` — `NSPrivacyCollectedDataTypeTracking = false` for Email; same for every collected-data-type entry.
  - 09 deep-run notes: "if HIGH-3.1 fires (consent never collected → user manually navigates to Settings → grants consent), the gate behaves correctly. But the manifest's claim is not 'no tracking happens'; it is 'no tracking happens when SDKs respect their gates'. This is fragile."
  - Salted-SHA256 user-id hash sent in EVERY consent-gated analytics event (`firebase_analytics_repository.dart:31-44`) — per-install salt makes it non-cross-app-joinable, which justifies `Tracking=false`. But Apple's tracking definition is broader than IDFA.
- **Impact:** as long as the consent gate is well-honoured, the manifest is accurate. The 09 finding documents fragility of the gate (e.g. consent-revocation race). Same issue surfaces here as a manifest-veracity concern.
- **Remediation:** improve consent gate robustness (09 owns); periodic audit of every `firebase_analytics_repository.dart` call site for gate-bypass.
- **Effort:** owned by 09.

#### LOW-LEGAL-8 — Google Play Data Safety form (configured in Play Console, not in code)

- **Status:** out of scope to verify from code. Recommended declaration:

| Data type | Collected | Shared | Optional | Purpose |
|---|---|---|---|---|
| Email | yes | no | no | Account, friend invitations |
| Name | yes | no | no | Display name |
| User IDs | yes | no | no | App functionality |
| Photos | yes | no | no | Recipe images |
| In-app messages | yes | no | yes (via socialFeatures consent) | Messaging |
| Approximate location | no | — | — | — |
| Precise location | no | — | — | — |
| Health and fitness — Other health info (allergens) | yes | no | no | App functionality (Art. 9 explicit consent) |
| Personal info — Other personal info (allergens as health) | yes | no | no | App functionality |
| App interactions | yes | no | yes (analytics consent) | Analytics |
| App performance — Crash logs | yes | no | yes (analytics consent) | App functionality |
| App performance — Diagnostics | yes | no | yes (analytics consent) | App functionality |
| Device or other IDs (FCM tokens) | yes | no | yes (push consent) | App functionality |

Post-monetization additions: Financial info (purchase history) → yes/no/no/Service.

---

## Dimension 6 — Consent Purpose Alignment (6 / 10)

### Purpose-to-implementation mapping (live-verified)

| ConsentPurpose | What policy promises | What code gates | Verified at | Match? |
|---|---|---|---|---|
| `essentialServices` | Auth, core CRUD (`:73-78`) | nothing — required, always-true (`user_consent.dart:124-126`) | model only | ⚠️ vacuous (orphan: nothing checks it because it's by-design always true) |
| `dataProcessing` | Recipe storage, menus, shopping lists (`:75-77`) | nothing — required, always-true (`:127-129`) | model only | ⚠️ same as above |
| `analytics` | Firebase Analytics + Crashlytics + Performance (`:82-86`) | `main.dart:295,305-358 _enableCollectionIfConsented` | verified | ✅ pass |
| `marketing` | Newsletters, broadcast (`:88-91`) | NOTHING (orphan — see MEDIUM-LEGAL-2) | none | ❌ orphaned |
| `socialFeatures` | Friends, sharing, comments, messaging (`:93-97`) | client-side `friend_request_service` etc. (per 02 + 09) | partial | ⚠️ blocking IS social, blocking does not check this gate |
| `pushNotifications` | FCM token + display (`:99-102`) | `fcm_service.dart:120-149` runtime-revoke (per 09 BUT-754 entry) | verified | ✅ pass |
| `aiProcessing` | Gemini API calls (`:126,133`) | `llm_service.dart:42` client-side; server retry bypasses (HIGH-LEGAL-3) | partial | ⚠️ leaky |

### Findings

#### MEDIUM-LEGAL-13 — `essentialServices` and `dataProcessing` are both required and both always-true; functionally redundant

- **Severity:** MEDIUM (Art. 7(2) granular-consent integrity)
- **Evidence:** `user_consent.dart:103-104, 124-129, 173-174` — both fields default to true and are required. `user_consent.dart:84` — `hasRequiredConsents` requires both. The split was likely intended to model "can the service operate" vs "can it store data" — under GDPR these are both Art. 6(1)(b) performance-of-contract grounds, not Art. 6(1)(a) consent. Conflating them as "consent" categories is conceptually wrong.
- **Impact:** the user is shown two toggles that do nothing (or one consolidated "essentials" toggle that's locked on). Either way, the granular-consent principle is undermined by carrying along non-consent items in the consent model.
- **Remediation:** collapse `essentialServices` + `dataProcessing` into a single non-toggleable "Service operation (Art. 6(1)(b) — required for the contract)" line item, separated visually from optional consent toggles.
- **Effort:** 2 h (model migration + UI + tests).

#### LOW-LEGAL-9 — Consent UI is reachable only via Profile → Manage Consent, post-onboarding (cross-ref 09 HIGH-2.1)

- **Severity:** LOW (Art. 13 readability — surfaced retroactively only)
- **Evidence:** owned by 09 HIGH-1 / HIGH-2.1.
- **Remediation:** add an `OnboardingConsentPage` per 09's recommendation.

---

## Dimension 7 — Firebase & Hosting Compliance (4 / 5)

### Findings

#### LOW-LEGAL-10 — All Cloud Functions confirmed europe-west1; cleanup-cron files' "Stockholm" comments are wrong but harmless (cross-ref pre-known fact)

- **Severity:** LOW (doc accuracy only — data still in EU)
- **Evidence:** `functions/src/llm/gemini-client.ts:28` `VERTEX_LOCATION = "europe-west1"`; `functions/src/llm/structure-recipe.ts:218` comment "europe-west1, EU residency". Multiple `functions/src/cleanup/*.ts` say "Region: europe-west1 (Stockholm)" per orchestrator — Stockholm = europe-north1, not europe-west1. Belgium = europe-west1.
- **Impact:** comments only; runtime is correct. Audit-trail accuracy.
- **Remediation:** find/replace "(Stockholm)" → "(Belgium)" across `functions/src/cleanup/*.ts`.
- **Effort:** 5 min.

#### MEDIUM-LEGAL-14 — Firebase Hosting headers — defer to 02 — but legal-relevant subset: missing CSP `frame-ancestors 'none'` exposes the app to clickjacking-vector legal exposure

- **Severity:** owned by 02; legal cross-ref MEDIUM
- **Evidence:** `firebase.json:21-33` no headers block (per knowledge file). Modern web auditors (BSI, ENISA) treat missing CSP+X-Frame-Options as a basic-due-diligence gap. Not a legal violation per se but a regulator presented with a clickjacking exploit will weight it heavily in the post-incident report.
- **Remediation:** owned by 02.

---

## Dimension 8 — Future Monetization Readiness (5 / 5)

### Pre-monetization legal checklist (forward-looking, not Phase-1 actionable)

- [ ] PCI DSS — out of scope (Stripe/RevenueCat handle)
- [ ] Konsumentköplagen (KKL) — applies to digital service contracts; Butlery free tier today doesn't trigger
- [ ] Distansavtalslagen — 14-day right of withdrawal — REQUIRED to disclose at point-of-purchase
- [ ] Marknadsföringslagen "first" / "comparative" claim restrictions — verify ASO copy at submission
- [ ] VAT/MOMS — Stripe Tax / RevenueCat handle; need invoice-issuance flow for B2B users
- [ ] App Store IAP requirements — 15-30% fee; no external payment links per Apple
- [ ] Företagsuppgifter (Lag 2002:562) — name, address, org.nr REQUIRED in app + on website
- [ ] Subscription cancellation UI — Apple/Google guidelines require easy in-app cancellation
- [ ] EU automatic-renewal disclosures (Directive 2019/770) — pre-purchase disclosure of renewal terms

Cross-ref 10 deep-run for entitlement / counter / store-asset state.

---

## Strategic legal opportunities (≥4)

1. **"Your recipes never leave Europe" privacy-as-feature.** The Vertex AI europe-west1 + Firestore europe-west1 combination is genuinely strong. Lift to ASO copy + in-app banner. Differentiator vs Paprika/AnyList/SuperCook (US-hosted).
2. **GDPR Art. 15 self-service export as marketing differentiator.** Once CRIT-2 (compliance_export_manager) is fixed (per 02), lift the Profile → Export My Data feature to the marketing site. "One-click GDPR export — your data is yours, in JSON."
3. **Apple Privacy Nutrition Label completeness as a "we tell the truth" badge.** Today 's `PrivacyInfo.xcprivacy:99-234` is more accurate than the privacy policy itself — bilateral-accurate disclosures rare in food apps. Marketable.
4. **AI provenance transparency.** Add "Auto-extracted by Vertex AI Gemini in Belgium; PII scrubbed; never used to train Google's models" microcopy on every AI-extracted recipe. Pre-empts EU AI Act Art. 50 transparency duty by months. Position as a competitive moat — Whisk, Mealime, etc. don't disclose.
5. **DSA Art. 16 statement-of-reasons as trust signal.** Convert MEDIUM-LEGAL-5 into a feature: when content is removed, the affected user receives a clear in-app SoR. Most platforms do this badly. Doing it well = trust differentiation in a UGC market.
6. **Children's safety stance.** IMY's published guidance on minors-in-social-services is sparse. Butlery could be the first Swedish app to publish a "Safety mode for 13-15 year olds" with caregiver controls. PR-positive + IMY-friendly + future-proof against Sweden's pending Barn-och-medieratt amendments.

---

## What's missing — legal-doc invariants (≥8)

1. **No CI lint that fails when `pubspec.yaml` adds a new dependency without an updated `THIRD_PARTY_LICENSES.md`.** Today licenses surface only via Flutter's runtime `showLicensePage` — no audit trail.
2. **No CI lint that fails when `assets/illustrations/` gains a file without a corresponding ATTRIBUTION.md row.**
3. **No legal-doc-set version coherence check** — privacy policy at 1.2.0 (April), ToS + community guidelines at Feb. CI rule: if any of the 6 legal files changes, the whole set's "Last updated" date must update in the same PR.
4. **No automated comparison of EN/SV legal docs** — bilingual drift today is detectable only by human review. A simple character-count diff + section-header parity check would catch ≥80% of drift.
5. **No iOS encryption-export annual-filing reminder** — once HIGH-LEGAL CRIT-2 is fixed, BIS requires annual self-classification. Calendar entry needed.
6. **No "subprocessors changed" detection** — privacy policy 1.2.0 says "This list is updated whenever our subprocessor chain changes" — but if a Cloud Function adds an outbound call to a new third-party API tomorrow, no automation alerts that the policy needs an update.
7. **No "binding versions" record** — when consent-version bumps from 1.1.0 → 1.2.0, every existing user's consent should be invalidated and re-collected (or a delta-notice shown). The `needsRenewal()` method (`user_consent.dart:78-80`) exists but is not wired to the privacy-policy version constant.
8. **No data-residency self-test** — periodically resolve the actual storage region of Firestore + Realtime DB + Storage from the SDK; if any ever returns a non-EU region, alert. Today the policy claim is unverified at runtime.
9. **No PII-scrubber test corpus** — `pii-scrubber.ts` covers email/phone/personnummer; nothing tests that the policy claim "scrubbed before processing" still holds when names + addresses + URLs slip through.
10. **No annual-review trigger** — privacy law evolves; a calendar event at the document mtime + 12 months would force re-evaluation.
11. **No statement-of-reasons template** for moderation actions — DSA Art. 16(2) requires specific content; today the appeal flow is unstructured email.
12. **No record of which version of the model weights was downloaded by which user** — reproducibility for an Art. 22 automated-decision query is impossible.

---

## What this means in plain language

- Several big legal-doc bugs the orchestrator warned about are already fixed in the April 2026 privacy policy update — that update went well.
- Two real problems remain that could cause hard trouble: (1) the App Store paperwork checkbox for "does your app use serious encryption?" is set wrong (says no, should say yes — your phone-side database is encrypted), and (2) the privacy policy promises "we use only these 5 outside companies" but actually uses a 6th (Google's reCAPTCHA, for fraud-protection on the website).
- The user-facing terms ("Användarvillkor") are stuck on a February draft while the privacy policy has moved on to April — they should be updated together so the two binding documents tell the same story.
- Recipe pictures of broccoli, carrots etc. that ship with the app have no note saying "Butlery owns these" or "downloaded from website X under license Y" — fine if the founder drew them, but should be written down.
- The "marketing" toggle in privacy settings doesn't connect to anything — there's no newsletter to send. Either build one or rename the toggle so it doesn't lie.
- All risks above are fixable with a long evening of doc edits plus one ~1-hour code change. Nothing here threatens the app today; everything here makes the difference between "audit-ready" and "audit-survivable" if a Swedish DPA (IMY) ever asked.
- Good news: the European data-residency story is real (Belgium, not US) and could be turned into a marketing line.

---

## Self-critic — three places I'd push harder with more time

1. **Realtime Database region** — I flagged HIGH-LEGAL-2 from the policy text alone. With Firebase console access I would have verified the actual instance URL pattern (`*.firebaseio.com` US-default, `*.europe-west1.firebasedatabase.app` Belgium, `*.asia-southeast1.firebasedatabase.app` Singapore). The policy says europe-west1 for everything; the truth might be us-central1, which would escalate from HIGH (residency-claim accuracy) to CRITICAL (unauthorized cross-border transfer).
2. **PII scrubber thoroughness** — I cross-cited 07's claim that the scrubber covers email/phone/personnummer only. With more time I would read `pii-scrubber.ts` directly and run synthetic test cases ("Anna Svensson, Storgatan 12") through it, then check the exact LLM payload via Cloud Logging to prove the privacy-policy claim's gap is reproducible. This is the difference between "documented MEDIUM" and "demonstrable HIGH with a specific reproducer".
3. **Apple ITSAppUsesNonExemptEncryption qualification** — I rated CRITICAL but the TSU exemption (EAR §740.17(b)(1)) likely DOES qualify Butlery (encryption for user-data confidentiality only, not communications). I'd want to read the TSU notification template, verify Butlery has zero comms-encryption (no end-to-end messaging crypto), and write the actual ENC notification email — that converts the CRITICAL into a 2-hour task with a defined paper trail. Without that, the CRITICAL classification might be over-stated for a developer-attestation context where Apple has a low-friction self-correction path.

