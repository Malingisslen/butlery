# Prompt 11 — Legal Review — Phase 1

Analyst: Claude (Opus 4.7, 1M context). Run: 2026-05-claude. Read-only audit.
Knowledge file `firebase-backend-security.knowledge.md` referenced as Step 0; cross-referenced reports 02, 05, 06, 07, 09 per orchestrator dedup rules. Phase 1 — investigation only, no code changes.

---

## Executive Summary

**OVERALL SCORE: 76 / 100 — Solid posture; concentrated gaps in encryption export declaration, AI-PII scrubbing scope, monetization-orphan consent purpose, and code-side documentation drift**

| # | Dimension | Score |
|---|-----------|-------|
| 1 | Privacy Policy vs Code Reality | 19 / 25 |
| 2 | ToS & Community Guidelines | 11 / 15 |
| 3 | License Compliance | 12 / 15 |
| 4 | AI & Data Processing | 10 / 15 |
| 5 | App Store Legal Compliance | 6 / 10 |
| 6 | Consent Purpose Alignment | 7 / 10 |
| 7 | Firebase & Hosting Compliance | 5 / 5 |
| 8 | Future Monetization Readiness | 5 / 5 |
| 9 | Adjustments / cross-prompt | 1 (bonus) |
| **Total** | | **76** |

Posture summary. The 11_LEGAL_REVIEW prompt brief was written against an older state of the codebase; **multiple "known discrepancies"** that the prompt instructs me to flag have already been remediated. In particular: (a) the privacy policy's AI provider is correctly named "Google Cloud Vertex AI (Gemini)" with europe-west1 residency at `assets/legal/privacy_policy_en.md:124-128` — there is **no remaining "Mistral AI" reference in any legal document**, only in code-side doc-comments; (b) `lib/models/account/user_consent.dart:97` no longer carries the "Mistral OCR" comment — the enum has been corrected; (c) `firebase.json:28-39` already declares a full security-header set (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy) — the prompt's "no headers block exists" instruction is stale; (d) `notification_service.dart:649` uses `ConsentPurpose.pushNotifications` (not undefined as the 09 cross-reference suggested). Cite: knowledge entry `2026-05-02 — FCM consent-revoke gap closed (BUT-754)` confirms BUT-754 closed that gap.

The remaining real gaps are:

1. **iOS `ITSAppUsesNonExemptEncryption=false` declaration is incorrect** — the app uses SQLCipher (AES-256) per privacy_policy_en.md:277 ("AES-256 encrypted storage (SQLCipher)") AND end-to-end TLS via Firebase. The exemption framework requires either ERN or self-certification of qualifying-use exemption (mass-market consumer encryption qualifies under EAR 740.17(b)(1) but must still be declared as `true` + claim exemption, not declared `false`). **HIGH** (App-Store-misdeclaration class).
2. **PII scrubber covers only email/phone/personnummer** — names and addresses pass through to Vertex AI. The privacy policy at `:129` ("Text is scrubbed for known PII patterns before processing; images cannot be scrubbed") is technically accurate ("known patterns"), but a regulator reading the user-facing description "we don't share your personal data with AI providers" against actual scrubber coverage will see a gap. **MEDIUM**.
3. **`marketing` consent purpose is orphan** — declared in `ConsentPurpose` enum, listed in privacy policy's legal-basis table at `:61`, but the consent-management UI at `lib/views/account/consent_management_view.dart:258` explicitly hides the toggle ("no marketing system implemented yet"). Privacy policy promises something the user cannot opt out of via the UI because they were never opted in via the UI. **MEDIUM**.
4. **No initial consent prompt** (cross-ref 09 HIGH-3.1) — onboarding never solicits granular GDPR consent. Privacy policy at `:280` says "manage in Profile > Account Management > Manage consents" — but the user must actively discover that screen. Confirmed in 09. **HIGH** (cited; not double-counted).
5. **Code-side documentation drift: 8 files still reference "Mistral AI"** — `functions/src/index.ts:10,24`, `functions/src/llm/PROMPT_CHANGELOG.md:58`, `functions/src/llm/ocr-recipe-image.ts:394` (correctly contrasting Gemini vs Mistral), `lib/services/llm/llm_service.dart` (header comment correctly says Gemini, but line 1 was previously "Mistral"), `lib/services/import/heic_converter.dart:3`, `lib/services/import/photo_import_strategy.dart:148`, `lib/services/ocr_extraction_service.dart:565`, plus `.claude/agents/cloud-functions-specialist.knowledge.md:20`. None of these are user-facing legal docs; they are pure documentation-rot. Cross-ref 07 D7-CRIT-1. **LOW** (cited).
6. **Google Cloud Vision API is a real OCR fallback path** but is NOT separately listed in the privacy policy as a sub-processor. `ocr_extraction_service.dart:412-468` calls `https://vision.googleapis.com/v1/images:annotate` whenever `GOOGLE_VISION_API_KEY` is set (`:236`). Privacy policy lumps it under "Google Firebase" but Cloud Vision is a separate Google product with separate DPA semantics. **MEDIUM**.
7. **Missing illustration provenance** — `assets/illustrations/arta/artskida0..5.PNG` and the WebP set (broccoli, morot, etc.) have no LICENSE/NOTICE/attribution file. Fonts ARE properly licensed (`JosefinSans-OFL.txt`, `SpaceGrotesk-OFL.txt` exist). **MEDIUM**.

### Top 5 Legal Risks

1. **iOS encryption export self-classification is misdeclared** — `ITSAppUsesNonExemptEncryption=false` is asserted in `ios/Runner/Info.plist:57-58` while the app demonstrably uses AES-256 via SQLCipher (privacy_policy_en.md:277 admits this). US Bureau of Industry and Security (BIS) penalties for false EAR declarations are real; Apple flags this in App Review and the annual self-classification report. (HIGH)
2. **No initial GDPR consent prompt** — Article 7(2) "request for consent ... clearly distinguishable" is not honoured; analytics, marketing, social, push, AI consents are never solicited. Cross-ref 09 HIGH-3.1. (HIGH; cited)
3. **PII scrubber gap on names + addresses** — Vertex AI receives un-scrubbed personal names/addresses embedded in recipe text. The privacy-policy-vs-code claim "scrubbed for known PII patterns" is technically true but the "patterns" cover only 3 categories (email/phone/personnummer). Article 5(1)(c) data minimisation. (MEDIUM)
4. **Orphan `marketing` consent purpose** — privacy policy makes a legal-basis claim about marketing under Art. 6(1)(a) for a feature that does not exist in the UI. The fix is small (remove privacy-policy line OR remove enum field) but the inconsistency itself is the legal risk. (MEDIUM)
5. **Google Cloud Vision sub-processor not separately disclosed** — Article 13.1.f and Article 28.2 require disclosure + consent to add sub-processors. Vision API ≠ Firebase ≠ Vertex AI even though they're all Google. (MEDIUM)

### Counts

- CRITICAL: 0
- HIGH: 2 (one cited from 09)
- MEDIUM: 5
- LOW: 4
- Informational / drift: 3

---

## Dimension 1 — Privacy Policy vs Code Reality (19 / 25)

### Processor Accuracy Matrix

| Privacy-policy claim | File:line | Code reality | Match? | Severity |
|---|---|---|---|---|
| AI provider: Google Cloud Vertex AI (Gemini), europe-west1 | `assets/legal/privacy_policy_en.md:124-128` | Confirmed: `functions/src/llm/gemini-client.ts:5,28,729` pins `VERTEX_LOCATION = "europe-west1"`; `structure-recipe.ts:218` calls Vertex AI Gemini in EU residency | YES | — |
| OCR.space as fallback OCR | `:131-135` | Confirmed: `lib/services/ocr_extraction_service.dart:225-231,360-409` (POST to `https://api.ocr.space/parse/image`) | YES | — |
| Algolia inactive (feature flag) | `:137-141` | Confirmed: knowledge `2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)`. Algolia gated by feature flag + analytics consent | YES | — |
| OCR.space "deleted immediately after processing" | `:166` | Cannot verify from code — this is OCR.space's contractual claim. Should be backed by their DPA, not code | — | LOW (audit gap) |
| **Google Cloud Vision** as a separate sub-processor | NOT LISTED | `ocr_extraction_service.dart:412-468` calls `https://vision.googleapis.com/v1/images:annotate` if `GOOGLE_VISION_API_KEY` env var is non-empty (`:236`). Circuit-breaker-guarded fallback after OCR.space failure (`:310-321`) | **NO** | MEDIUM |
| AI processing only via "Vertex AI Gemini" | `:124-129` | Vertex AI Gemini IS the primary path. But Cloud Vision API is a separate Google product (different SLA, different model, different data-flow), called whenever GOOGLE_VISION_API_KEY is set. Lumping it under "Google Firebase" undercounts the disclosure | NO | MEDIUM |
| Cookie usage section | NONE | No cookies in mobile app — confirmed: section 11 of policy at `:272-280` correctly retitled "Local storage and similar technologies" and explicitly states "does not use browser cookies" | YES | — (the prompt brief was stale) |
| Data retention: "Deletion audit logs 180 days" | `:193` | `lib/services/account/account_deletion_service.dart:41` `_auditLogRetentionDays = 180`. Matches. | YES | — |
| Data retention: "Security logs 90 days" | `:192` | Knowledge `2026-04-30 — audit_logs retention buckets` documents two buckets: 6 months general, 24 months consent events. **Privacy policy says 90 days for "Security logs" — code retains 180+ days for general bucket, 24 months for consent**. Mismatch. | NO | MEDIUM |
| Data retention: "Analytics data 14 months (Google Analytics standard)" | `:190` | Cannot verify from code — this is Firebase Analytics' default. Standard claim. | YES | — |

### Findings

#### MEDIUM-1.1 — Google Cloud Vision API is an undeclared sub-processor

- **Severity**: MEDIUM (GDPR Art. 13.1.f, Art. 28.2)
- **Evidence**: `lib/services/ocr_extraction_service.dart:215` comment "BUT-427: third-party OCR fallbacks (OCR.space, Google Vision, Tesseract)"; `:412-468` `_extractWithGoogleVision()` posts to `https://vision.googleapis.com/v1/images:annotate`; gated on env-var `GOOGLE_VISION_API_KEY` (`:236`). Privacy policy `:163` Data-Processor-Inventory lumps all Google products under one row ("Google Cloud / Firebase ... Crashlytics, Cloud Messaging, Remote Config, Performance Monitoring") but **does not enumerate Cloud Vision API**.
- **Impact**: Article 13.1.f requires the controller to identify the *recipients or categories of recipients* of personal data; recipe images posted to Cloud Vision contain whatever PII was visible in the photograph (handwritten names, addresses, friends' faces). Sub-processor disclosure is also a contract obligation under Art. 28.2 if any DPA references "Google Firebase" specifically.
- **Cross-reference**: not flagged in 02 or 07; this is the legal disclosure dimension that 11 owns.
- **Remediation**: either (a) remove the Cloud Vision fallback (current code allows it to be off when env var is unset) and document the policy decision; or (b) add a sixth row to the Data-Processor-Inventory table at `:163-167` for "Google Cloud Vision API". 1 hour.
- **Effort**: 1h.

#### MEDIUM-1.2 — Retention period for "Security logs 90 days" understates audit_logs reality

- **Severity**: MEDIUM (data-minimisation accuracy)
- **Evidence**: privacy_policy_en.md:192 "Security logs 90 days". Knowledge `2026-04-30 — audit_logs retention buckets` documents the actual implementation: 6 months for general operations, **24 months for consent events** (Art. 7(1) demonstrability). Code at `functions/src/audit_logs/purge-expired.ts` operates on these buckets. Privacy policy hides the 24-month consent-event retention behind a 90-day claim.
- **Impact**: regulator reading "we keep security logs 90 days" then discovering audit_logs entries from 18 months ago has a transparency gap. Acceptable to retain for accountability — Art. 7(1) literally requires it — but the policy must say so.
- **Remediation**: split the row into "Security logs 90 days" and "Consent audit logs 24 months (Art. 7(1) accountability)". Source-of-truth alignment with `docs/security/audit-logs-retention.md` per knowledge entry.
- **Effort**: 30 min.

#### LOW-1.1 — "OCR.space deletes immediately after processing" is unverified controller claim

- **Severity**: LOW (factual claim accuracy)
- **Evidence**: `:166` "deleted immediately after processing". OCR.space's published privacy policy says "your image is *not* stored on our servers" but the precise retention semantics (queue logs, error captures) cannot be derived from Butlery's code — this is an OCR.space-side claim Butlery is repeating.
- **Impact**: if regulator audits and OCR.space turns out to retain images for 24h for fraud-detection, Butlery is the one with a wrong policy claim.
- **Remediation**: confirm with OCR.space's DPA + cite the DPA URL alongside the claim, OR soften to "OCR.space processes images and does not store them per their published policy".
- **Effort**: 15 min (text edit).

### Bilingual Consistency

EN and SV versions are semantically equivalent. Spot-checked: same processor list (`:163-167` ↔ `:163-167`), same retention table, same legal-basis table, same age (13), same version (1.2.0, 24 April 2026). Sole stylistic difference: SV uses ❌ / ✅ / 🔔 / 📱 emoji decoration while EN uses bullet text. No semantic gap.

### Score: 19/25

Lost 6 points: −2 Cloud Vision undisclosed, −2 retention understatement, −1 OCR.space claim provenance, −1 Cloud Vision lump-sum description.

---

## Dimension 2 — Terms of Service & Community Guidelines (11 / 15)

### Findings

#### MEDIUM-2.1 — ToS missing data-portability + account-deletion consequences sections

- **Severity**: MEDIUM (GDPR Art. 17 + Art. 20 procedural disclosure)
- **Evidence**: `assets/legal/terms_of_service_en.md` covers acceptance, eligibility, content ownership, prohibited content, termination + appeal, liability, governing law. **No section on**: (a) what happens to shared data when account is deleted (recipes shared with friends — do they remain readable?), (b) data export rights mention. Privacy policy covers both but ToS does not cross-reference. Knowledge `2026-04-26 — ContentReport contentType` notes that comments/messages cascade-delete, but this is undocumented in ToS.
- **Impact**: a user who shared a recipe with friends, then deletes their account, then reads ToS expecting "what happens to my shared content" — the ToS is silent. This creates a "did the user know?" question on Art. 17 cascading.
- **Cross-reference**: 06 covers UX-side accessibility of ToS; this is the content-completeness dimension.
- **Remediation**: add Section 5.4 "When you delete your account" to ToS pointing to privacy policy §9.3 + clarifying that shared content is removed from your friends' views per cascade rules in `firestore.rules`. 30 min.
- **Effort**: 30 min.

#### LOW-2.1 — ToS AI section names "AI" but not the provider

- **Severity**: LOW
- **Evidence**: terms_of_service_en.md:37 "The Service may use AI (artificial intelligence) to extract and structure recipes". Privacy policy correctly names Google Vertex AI Gemini at `:124-129` but ToS keeps it generic. Acceptable for ToS scope (privacy policy is the disclosure venue), but a reader scanning only ToS sees "AI" without provider.
- **Remediation**: add "(Google Cloud Vertex AI Gemini, processed in EU)" to terms_of_service_en.md:37. 5 min.
- **Effort**: 5 min.

#### LOW-2.2 — ToS Section 7 limitation of liability does not preserve EU consumer rights

- **Severity**: LOW (Swedish konsumentköplag + EU Directive 93/13/EEC)
- **Evidence**: `:55-60` "Service provided as-is ... not liable for ... loss of data ...". Under Swedish konsumentköplag and EU Unfair Contract Terms Directive 93/13/EEC, "as-is" with full liability disclaimer against consumers is unenforceable for non-business users. Also missing: standard "this section does not exclude liability that cannot be excluded by law" carve-out which Swedish lawyers expect.
- **Impact**: clause likely unenforceable as drafted; regulator/court will read it down. Not a fine-class violation but legally ineffective.
- **Remediation**: append "Nothing in this section excludes liability that cannot be excluded under Swedish law (including konsumentköplagen and consumer-protection rules)." 5 min.
- **Effort**: 5 min.

#### LOW-2.3 — Community Guidelines do not reference Block feature

- **Severity**: LOW
- **Evidence**: community_guidelines_en.md mentions Reporting (`:55-58`) but not Blocking. The Block feature exists (`lib/repositories/firebase/firebase_block_repository.dart` per 09 Dimension 1 matrix) and is a UGC-policy-relevant trust-and-safety primitive. Apple Guideline 1.2 explicitly lists "ability to block abusive users".
- **Remediation**: add a §9 to community_guidelines_en.md "If someone bothers you, you can block them via Profile > Block User. Blocked users can no longer interact with you." 10 min.
- **Effort**: 10 min.

### Bilingual Consistency

ToS EN ↔ SV: equivalent. Both date 2026-02-28. Same 11 sections.
Community Guidelines EN ↔ SV: equivalent (verified by reading both).

### Score: 11/15

Lost 4 points: −2 ToS data-portability/cascade gap, −1 ToS AI provider name, −1 community guidelines block-feature gap.

---

## Dimension 3 — License Compliance (12 / 15)

### Font Licenses

`assets/fonts/`:
- `JosefinSans-Bold.ttf`, `JosefinSans-Regular.ttf`, `JosefinSans-SemiBold.ttf` + `JosefinSans-OFL.txt` (OFL-1.1 license bundled). PASS.
- `SpaceGrotesk-Bold.ttf`, `SpaceGrotesk-Medium.ttf`, `SpaceGrotesk-Regular.ttf`, `SpaceGrotesk-SemiBold.ttf` + `SpaceGrotesk-OFL.txt`. PASS.

The 11_LEGAL_REVIEW prompt's claim "currently NO license files exist in assets/fonts/" is **stale**.

### Open-Source License Page

`lib/views/settings/account_security_view.dart:373-380` wires `showLicensePage(context: context, applicationName: 'Butlery')`. Flutter's built-in surfacing covers all `pubspec.yaml` dependencies that ship a LICENSE file. Reachable from Settings > Account Security > Open Source Licenses. PASS.

### Findings

#### MEDIUM-3.1 — Illustration provenance not documented

- **Severity**: MEDIUM (copyright accuracy, store-rejection risk)
- **Evidence**: `assets/illustrations/arta/artskida0.PNG ... artskida5.PNG` and the WebP set (broccoli.webp, citrus.webp, morot.webp, kal.webp, sparris.webp, rabarber.webp, rodbeta.webp, rodlok.webp, pumpa.webp, champinjon.webp, bar.webp, artskida.webp). No `LICENSE`, `NOTICE`, `ATTRIBUTION.md`, or sidecar file with origin. The "arta/" subdirectory name suggests an artist abbreviation but is undocumented.
- **Impact**: if these are stock images or AI-generated, terms-of-use need to be retained alongside the bundle (e.g. Adobe Stock requires attribution-free use docs; AI images may have model-output usage restrictions). If they are original works of the developer, an explicit "© Butlery 2024-2026, all rights reserved" file is sufficient. The current state is "we don't know".
- **Cross-reference**: 05 Dimension 3 owns dependency licensing. Asset licensing is mine.
- **Remediation**: add `assets/illustrations/LICENSE.md` documenting origin per file (or per-folder if homogeneous). For example: "All illustrations in this directory are © Butlery 2026 and were created by [name]" or "Generated by [model] under [usage terms]". Solo-developer context — likely originals; just need to record it.
- **Effort**: 30 min.

#### LOW-3.1 — sqlcipher EOL signal — license-side implication

- **Severity**: LOW (legal-side)
- **Evidence**: cross-ref 05 HIGH-3 — `sqlcipher_flutter_libs 0.6.8` upstream marked `0.7.0+eol`. The wrapper is MIT; SQLCipher itself is BSD-3-Clause-style + commercial license available. If migration is forced by EOL to a different encryption substrate, the new substrate's license must be re-vetted (e.g. drift_native uses sqlite3 BSD; commercial SQLCipher would need a separate license file).
- **Impact**: not a current legal violation, but a foreseeable one if migration goes wrong.
- **Remediation**: when 05's HIGH-3 migration plan is executed, add a license-review step for the chosen replacement substrate.
- **Effort**: tracking only.

#### LOW-3.2 — ONNX model provenance not documented in `assets/`

- **Severity**: LOW
- **Evidence**: knowledge file does not mention ONNX model provenance. Models referenced via `lib/services/parsing/ner/ner_model_manager.dart` and `lib/services/parsing/line_classifier/line_classifier_model_manager.dart`. If models are downloaded from Firebase Storage at runtime, they are not in the app bundle — but the model card / training-data lineage still needs documentation for EU AI Act Art. 53 (foundation-model-derived).
- **Impact**: AI Act minimum-risk categorization (see Dim 4) means transparency obligations are limited. But model card should be referenced.
- **Remediation**: document model provenance in `docs/ai/model-card.md` (likely exists; verify and link from privacy policy).
- **Effort**: 30 min if doc exists; 2h if drafting from scratch.

### Score: 12/15

Lost 3 points: −2 illustration provenance, −1 ONNX model card not surfaced.

---

## Dimension 4 — AI & Data Processing Compliance (10 / 15)

### Provider Reference Inventory (every location naming "Mistral" or "Gemini")

| File:line | Says | Should say | Severity |
|---|---|---|---|
| `assets/legal/privacy_policy_en.md:124-128` | Vertex AI Gemini | Vertex AI Gemini | OK |
| `assets/legal/privacy_policy_sv.md:124-128` | Vertex AI Gemini | Vertex AI Gemini | OK |
| `assets/legal/terms_of_service_en.md:37-38` | "AI" generic | "Vertex AI Gemini" | LOW (D2) |
| `lib/services/llm/llm_service.dart:1-29` | Google Gemini via Cloud Functions, region europe-west1 | (correct) | OK |
| `lib/models/account/user_consent.dart:97` | (clean — no "Mistral OCR" comment) | (correct) | OK |
| `functions/src/index.ts:10,24` | "LLM Services (Mistral AI)" + "LLM Functions - Mistral AI integration" | "Vertex AI Gemini" | LOW (drift) |
| `functions/src/llm/PROMPT_CHANGELOG.md:58` | references "Mistral model" historical context | acceptable as historical changelog; flag for archiving | LOW |
| `functions/src/llm/ocr-recipe-image.ts:394` | "Gemini uses inlineData ... not image_url like Mistral" — **correctly contrasting**, not asserting | acceptable | OK |
| `lib/services/import/heic_converter.dart:3` | "Mistral's vision endpoint" | Vertex AI Gemini | LOW |
| `lib/services/import/photo_import_strategy.dart:148` | "Mistral may still parse them" | Vertex AI Gemini | LOW |
| `lib/services/ocr_extraction_service.dart:565` | "Mistral / OCR.space" | Vertex AI / OCR.space | LOW |
| `.claude/agents/cloud-functions-specialist.knowledge.md:20` | "llm/ (Mistral)" | Vertex AI Gemini (knowledge file is append-only — would need a 2026-05 dated supersede entry) | LOW |
| `.claude/hooks/secret-scan-precommit.sh:18,91` | "Mistral / Firebase key" — comment about secret-scan patterns | acceptable historical | OK |

**Net assessment**: zero remaining "Mistral" references in user-facing legal docs. Eight references in code-side documentation (most are doc-comments). 11_LEGAL_REVIEW prompt brief was written before BUT-580/BUT-754 cleaned this up.

### Findings

#### MEDIUM-4.1 — PII scrubber covers only email/phone/personnummer

- **Severity**: MEDIUM (GDPR Art. 5(1)(c) data minimisation)
- **Evidence**: `lib/services/llm/pii_scrubber.dart:13-37` and `functions/src/llm/pii-scrubber.ts:16-60` define replacement patterns ONLY for: `[EMAIL]`, `[PHONE]` (Swedish phone format), `[PERSONNUMMER]` (Swedish national ID). **Names** (e.g. "Mormors recept från Anna Svensson"), **street addresses** (e.g. "Storgatan 12, Stockholm"), and **URLs containing PII path segments** (partly covered by `scrubUrlParams` for opaque tokens but not for obvious PII paths) are NOT scrubbed.
- **Impact**: a user importing a recipe from a personal blog post that includes the author's name + address sends that data to Vertex AI in europe-west1. Vertex AI's published terms for paid Vertex API tiers (which Butlery uses — confirmed via Cloud Functions secret rotation pattern, not free tier) state inputs are not used for training, but they ARE retained for abuse monitoring. Privacy policy at `:129` says "Text is scrubbed for known PII patterns before processing" — technically true given the "known patterns" hedge, but a user reading the policy would assume "names, addresses, etc." are part of "PII patterns".
- **Cross-reference**: 02 covers consent-service implementation. 07 D7-CRIT-1 / D2 covers PII-scrubber correctness. This finding is the **legal-document-vs-implementation gap** that 11 owns: the disclosure language is more comforting than the actual coverage.
- **Remediation**: two paths — (a) tighten the policy language at `:129` to enumerate exactly which PII categories are scrubbed ("emails, Swedish phone numbers, Swedish personnummer; other personal information you place in recipe text may be processed by Vertex AI"); (b) extend the scrubber to redact common Swedish first-name/surname patterns and street-address patterns. Path (a) is 15 min and honest; path (b) is 6-8 hours and incomplete (NER on recipe text is itself an LLM problem). Recommend (a) for now.
- **Effort**: 15 min for honest disclosure; 6-8h for code-side scope expansion.

#### MEDIUM-4.2 — AI consent gating verified working but on-device parsing relies on it being denied

- **Severity**: MEDIUM (consent-modeling completeness)
- **Evidence**: `lib/services/llm/llm_service.dart:42` `_consentPurpose = ConsentPurpose.aiProcessing` + `:270` `if (!await _consentService.hasConsent(_consentPurpose)) { ... }`. Server-side calls correctly gated. **However**: `lib/services/parsing/ner/onnx_ner_service.dart` (on-device BERT NER) does **not** check consent — and it shouldn't, because on-device processing doesn't share data with third parties. Knowledge entry `2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)` correctly distinguishes "analytics" from "essential services" but I cannot find an analogous entry distinguishing on-device-AI from cloud-AI.
- **Impact**: privacy policy `:124-128` describes only Vertex AI as the AI processor. On-device ONNX is not disclosed as an AI processor (correct — it isn't a third party). A regulator question "your privacy policy says Vertex AI is the AI processor; is anything else processing my data with AI?" would surface the on-device path. No legal violation but disclosure-completeness gap.
- **Remediation**: add a sentence to privacy_policy_en.md §6.1 "Some AI processing happens entirely on your device (ingredient classification using a small language model). On-device processing does not share data with any third party."
- **Effort**: 10 min.

#### LOW-4.1 — EU AI Act Article 52 transparency: AI-processed content not labeled in UI

- **Severity**: LOW (AI Act Art. 50/52 — transparency)
- **Evidence**: per cross-ref 07 — recipe import via Vertex AI does not visibly label the resulting recipe as "AI-extracted". User sees a recipe form pre-filled with extracted values. AI Act Art. 50(2) requires "deepfake" labeling and Art. 52 requires generative-AI transparency for high-risk applications. Recipe extraction is **minimal-risk** under Art. 6 / Annex III — no high-risk classification triggered. Art. 50(1) applies to direct-interaction AI ("you are interacting with an AI") — recipe-extraction is back-end, not direct chat.
- **Impact**: technically below threshold for Art. 50/52 obligations. Disclosure is purely best-practice.
- **Remediation**: optional — show a small "AI-extracted, please review" hint on the recipe-form-after-import view. Soft polish; not legally required for minimal-risk classification.
- **Effort**: 30 min if added.

#### LOW-4.2 — Vertex AI tier and DPA confirmation not documented in repo

- **Severity**: LOW
- **Evidence**: `gemini-client.ts:5,28` confirms Vertex AI europe-west1 (paid tier — free Gemini API does not run in Vertex namespace). DPA: Google Cloud DPA at `https://cloud.google.com/terms/data-processing-addendum` (linked from privacy policy `:128`). Not stored or version-pinned in repo (not standard either — DPA is web-hosted by Google).
- **Remediation**: add `docs/ops/dpa-inventory.md` listing DPAs in force (Google Cloud, Algolia, OCR.space, Firebase) with last-checked dates. 30 min.
- **Effort**: 30 min.

### Score: 10/15

Lost 5 points: −3 PII scrubber scope vs disclosure, −1 on-device AI not disclosed, −1 AI Art. 52 best-practice optional label.

---

## Dimension 5 — App Store Legal Compliance (6 / 10)

### Findings

#### HIGH-5.1 — `ITSAppUsesNonExemptEncryption=false` is incorrect

- **Severity**: HIGH (US Export Administration Regulations + Apple App Review)
- **Evidence**: `ios/Runner/Info.plist:57-58` `<key>ITSAppUsesNonExemptEncryption</key><false/>`. **But**: privacy_policy_en.md:277 explicitly states "Your recipes and data are cached locally using AES-256 encrypted storage (SQLCipher)". AES-256 is non-exempt encryption under US EAR Cat 5 Part 2 by default. Two paths exist for legitimate apps:
  1. **TSU exception** (15 CFR 740.13(e)): for "publicly available" mass-market consumer encryption products. This exception still requires `ITSAppUsesNonExemptEncryption=true` PLUS providing the export-classification form OR claiming exemption.
  2. **App-uses-only-already-published-encryption** narrow exemption: when the app uses standard encryption built into the OS (CommonCrypto, etc.) without bringing its own. SQLCipher is a third-party library that ships AES-256 — it does NOT qualify under this narrow exemption.
- **Apple's own documentation** (https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations): if you use ANY encryption beyond what's exempt under §740.17(b)(1) consumer-mass-market, you must declare `true` and either (a) submit annual self-classification report (ERN), or (b) demonstrate exemption.
- **Impact**: misdeclaration is a federal compliance issue (BIS) — penalties exist on paper but in practice are rarely enforced for solo-developer mass-market apps. Apple App Review will increasingly flag this on routine submissions; misdeclaration discovered in audit = pulled-from-store risk. ALSO: the privacy policy's encryption claim at `:277` makes the misdeclaration **provable from the bundle alone** — anyone can read the policy + plist.
- **Cross-reference**: 06 user-experience.md:158 + 10 monetization.md:45 both observe the declaration but neither flags it as wrong (it was outside their dimension). 11 owns the legal-correctness call.
- **Remediation**: change `<false/>` to `<true/>` and add `ITSEncryptionExportComplianceCode` with the ERN value (free to obtain from BIS via SNAP-R) OR add `ITSAppUsesNonExemptEncryption=true` + claim TSU mass-market exception (most apps do this — App Store Connect prompts you through it on submission). The fact that the app uses only AES-256 for at-rest user-data protection (not for export-controlled communications encryption) means the §740.17(b)(1) "consumer-mass-market" path applies. ~1 hour to file ERN + update plist.
- **Effort**: 1h (BIS SNAP-R registration) + 5 min (plist).

#### MEDIUM-5.1 — Privacy Manifest data type list is missing FCM Push Token category

- **Severity**: MEDIUM (Apple required-disclosure)
- **Evidence**: `ios/Runner/PrivacyInfo.xcprivacy` declares: Email, Name, UserID, Photos, Other-User-Content, Product-Interaction, Crash-Data, Performance-Data, **DeviceID** (covers FCM tokens — line 222-233 says "device_info_plus and Firebase Installations generate a per-install device identifier used for FCM push routing"). Apple's data-type taxonomy does NOT have a separate "Push Token" type — DeviceID is the canonical category for FCM. So this IS covered. PASS on push token.
- **Real gap**: **Health & Fitness — allergen preferences**. Allergens (gluten, lactose, peanut, etc.) per `lib/models/user_profile.dart` `allergenPreferences` field. Apple's `NSPrivacyCollectedDataTypeHealth` (Health & Fitness section) covers "health data" — allergens may qualify as a special category. Currently NOT declared.
- **Impact**: allergens are GDPR Art. 9 special category if interpreted as "health data". Apple's privacy taxonomy is broader than GDPR — they include "Sensitive Info: Health and Fitness" in any case. Conservative declaration is to include `NSPrivacyCollectedDataTypeHealth` linked=true, tracking=false, purpose AppFunctionality.
- **Cross-reference**: 09 Dimension 4 (Privacy Manifest) gave 12/12 because Apple-required reasons are correct. This is a **disclosed-data-types completeness** gap, not a required-reason gap — different sub-dimension.
- **Remediation**: add `<dict>` block to PrivacyInfo.xcprivacy for `NSPrivacyCollectedDataTypeHealth`. Alternatively, document the legal call that allergen preferences are "dietary preferences not health data" and stay silent. The latter is legally defensible but optimistic.
- **Effort**: 15 min.

#### MEDIUM-5.2 — Google Play Data Safety: cannot verify, document expected declaration

- **Severity**: MEDIUM (cannot verify from code)
- **Evidence**: Google Play Data Safety form is configured in Play Console, not in repo. Based on code analysis, the declaration should include:
  - **Personal info**: Name, Email, User IDs (collected, linked, optional sharing, App Functionality + Account Management)
  - **Photos**: Photos (collected, linked, App Functionality)
  - **Messages**: In-app messages (collected, linked, App Functionality)
  - **App activity**: App interactions (collected, linked, optional, Analytics + Improvement) — consent-gated
  - **App info and performance**: Crash logs, Diagnostics (collected, optional, Analytics) — consent-gated
  - **Device or other IDs**: Device ID (collected, linked, App Functionality)
  - **Health and fitness**: Other health info — allergen preferences (collected, linked, App Functionality) — see MEDIUM-5.1
  - **Files and docs**: Files and docs — recipe images uploaded (collected, linked, App Functionality)
  - **Contacts**: friend list (collected, linked, optional, Account Management) — consent-gated to socialFeatures
  - **No Financial info** (pre-monetization)
  - **No Location** (presence is online/offline only — no geo)
- **Impact**: this is the gold-standard list 11 should produce per the prompt brief. Cannot verify against Play Console.
- **Remediation**: print this list, compare against Play Console's actual config, reconcile. Document as `docs/ops/play-data-safety-source-of-truth.md`. 1h.
- **Effort**: 1h.

#### MEDIUM-5.3 — Age rating consistency check

- **Severity**: MEDIUM
- **Evidence**: privacy_policy_en.md:286 "intended for users aged 13 or older". terms_of_service_en.md:13 "must be at least 13 years old". Knowledge `2026-04-25 — store-submission rating defense triad` documents Apple 12+ / Play Teen target with UGC + messaging + 24-h moderation triad. Legal docs say 13; Apple 12+ allows ≥12 but documents 13+ minimum on the developer side. Play Teen = 13+. Consistent.
- **Sub-finding**: privacy policy `:286` does not mention the **Article 8 GDPR digital consent age**. Sweden's national implementation lowers the digital-consent floor to 13 (Art. 8.1 default is 16, member states may lower to 13). The policy says "13 years or older" but does not cite the Art. 8 basis. This is required by Art. 13 transparency for clarity to the user.
- **Remediation**: add to privacy_policy_en.md:286 "(per Sweden's implementation of GDPR Article 8(1))". 5 min.
- **Effort**: 5 min.

### Score: 6/10

Lost 4 points: −2 ITSAppUsesNonExemptEncryption misdeclaration, −1 Privacy Manifest health gap, −1 Google Play Data Safety unverified.

---

## Dimension 6 — Consent Purpose Alignment (7 / 10)

### Purpose-to-Implementation Matrix

| ConsentPurpose | What the privacy policy says it gates | What code actually gates | Verified |
|---|---|---|---|
| `essentialServices` (required) | "Always active — account, auth, storage" (`:73-79`) | DI-injected; never checked at runtime — required = always-on | YES, by design |
| `dataProcessing` (required) | implicit (privacy policy doesn't surface this purpose by name) | Checked: `_consentService.hasConsent(ConsentPurpose.dataProcessing)` in some flows | YES (verified by grep) |
| `analytics` (optional) | "Understand how features are used" (`:84`) | Confirmed gated: `analytics_service.dart:81` `ConsentService.checkSafely(_consentService, ConsentPurpose.analytics, ...)` + `base_tracker.dart:23` | YES |
| `marketing` (optional) | "Send newsletters about new features ... Inform about updates" (`:88-91`) | **Code: NOTHING — no marketing system** (`consent_management_view.dart:258` "Marketing toggle hidden — no marketing system implemented yet") | **NO** |
| `socialFeatures` (optional) | "Share recipes with friends, see others' recipes ..." (`:93-98`) | Verified gated in social-feature paths per knowledge `2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)` and ConsentService listener pattern | YES |
| `pushNotifications` (optional) | "Notify you about comments, inform about shares ..." (`:99-103`) | Confirmed: `fcm_service.dart:135-184` gates token registration + permission request on `_hasPushConsent()` (knowledge `2026-05-02 — FCM consent-revoke gap closed (BUT-754)`) | YES |
| `aiProcessing` (optional) | "AI-based recipe extraction and structuring (OCR and text analysis) via Gemini models" (`:124-126`) | Confirmed: `llm_service.dart:42` + `:270` | YES |

### Findings

#### MEDIUM-6.1 — Orphan `marketing` consent purpose

- **Severity**: MEDIUM (transparency mismatch)
- **Evidence**: `lib/models/account/user_consent.dart:94` enum value `marketing`, `:106` `final bool marketing`, persisted to Firestore in `:153`. Privacy policy `:61` lists "Marketing and newsletters | Consent (Art. 6.1.a)" as a legal-basis category. **But**: `lib/views/account/consent_management_view.dart:258` explicitly hides the toggle: `// Marketing toggle hidden — no marketing system implemented yet.` `lib/viewmodels/account/consent_viewmodel.dart:138-143` has `setMarketing()` setter wired but no UI calls it (other than `:193` `_marketing = true` and `:203` `_marketing = false` "accept all" / "deny all" macros).
- **Impact**: the privacy policy promises a legal-basis pathway for marketing that the user cannot actively manage in the UI. If a user requests Article 15 access and asks "what marketing have you done with my data based on this consent?", the answer is "none, the feature doesn't exist". That's fine. But the user was never *asked* to consent or refuse — yet the consent record gets written with `marketing: false` by default. Article 7(2) "the request for consent shall be presented in a manner clearly distinguishable" is dodged: the consent isn't requested at all. Compounds with 09 HIGH-3.1.
- **Remediation**: two clean options:
  1. **Remove**: drop `marketing` from `ConsentPurpose`, drop the row from privacy policy `:61`, drop the marketing language at `:88-91`. The Firestore field stays in the schema for backwards compat (consent_management_view.dart:259 already notes this).
  2. **Wire up**: implement the email-newsletter feature, add the toggle, add the actual newsletter dispatch flow. ~1 week of work.
  Recommend (1) until monetization. Aligns with knowledge `Beta UX Decisions (2026-02-13) — No monetization decisions yet — just build the app`.
- **Effort**: 1h (option 1) or 1 week (option 2).

#### LOW-6.1 — Consent UI does not surface consent version

- **Severity**: LOW (minor transparency)
- **Evidence**: `consent_service.dart:36` `'1.1.0'; // 1.1.0: Added aiProcessing consent purpose`. ConsentManagementView does not display the version to the user. Article 7(1) accountability requires demonstrability — already covered by `users/{uid}/consent` doc that records `consentVersion`. UX surfacing is best-practice.
- **Remediation**: append a small "Last updated: v1.1.0 (24 April 2026)" line to ConsentManagementView. Surfaces audit-trail and helps users understand why they may be re-prompted on version bumps (per knowledge BUT-356).
- **Effort**: 15 min.

#### LOW-6.2 — Consent UI accuracy: `aiProcessing` description must accurately name Vertex AI

- **Severity**: LOW
- **Evidence**: `app_en.arb:2167` (consentAiProcessing) and `app_sv.arb:2167` use "AI"-generic language. Per Dim 4, the privacy policy correctly names Vertex AI Gemini. The consent UI should match for granular informed-consent purposes (Article 7(1) "informed").
- **Remediation**: update `consentAiProcessingDescription` in both ARB files to "Process recipe text and images using Google Cloud Vertex AI (Gemini), in EU/EES." Run `flutter gen-l10n`.
- **Effort**: 10 min.

### Score: 7/10

Lost 3 points: −2 marketing orphan, −1 consent version not surfaced + AI provider naming.

---

## Dimension 7 — Firebase & Hosting Compliance (5 / 5)

### Findings

#### Hosting Security Headers — PASS

`firebase.json:28-39` declares full security-header set:
- HSTS: `max-age=63072000; includeSubDomains; preload` ✓
- CSP: comprehensive policy with frame-ancestors 'none', object-src 'none' ✓
- X-Content-Type-Options: nosniff ✓
- X-Frame-Options: DENY ✓
- Referrer-Policy: strict-origin-when-cross-origin ✓
- Permissions-Policy: camera/microphone/geolocation = () ✓

The 11_LEGAL_REVIEW prompt brief at line 642 ("No 'headers' block exists") is **stale**.

### Region Accuracy

- All cleanup-*.ts files reviewed via grep `Stockholm.*europe-west1` — **no matches**. The "Stockholm" mentions in code are Europe/Stockholm timezone references (`send-activity-digest.ts:146`, `send-notification.ts:188` — quiet hours), `detect-lapsed-users.test.ts` (Stockholm timezone test fixtures). These are CORRECT (timezone-of-the-Swedish-user, not region-of-the-server).
- `gemini-client.ts:28` `VERTEX_LOCATION = "europe-west1"` — explicitly Belgium. Correct.
- `audit_logs/purge-expired.ts:120` `region: "europe-west1"` — correct.

The 41 stockholm-mentions documented in pre-analysis (`stockholm-mentions.txt`) are timezone references, not region misclaim. The orchestrator note about "Cloud Functions: europe-west1 (Belgium — NOT Stockholm despite code comments)" is from prior runs; current code does NOT make the wrong claim.

### Data Residency Inventory

| Service | Region | Within EU/EES? |
|---|---|---|
| Firestore | europe-west1 (Belgium) | YES |
| Firebase Storage | europe-west1 (Belgium) | YES |
| Realtime Database | (not configured for region — default) — knowledge `2026-04-30` notes europe-west1 default | YES (presumed) |
| Cloud Functions | europe-west1 (Belgium) | YES |
| Firebase Auth | global (Google) | mixed — EU-US Data Privacy Framework as documented in policy `:115,121` |
| Firebase Analytics | EU region per privacy policy `:164` | YES (with US aggregation per policy admission) |
| Crashlytics | global (Google) | mixed — DPF + SCCs per policy `:163` |
| Vertex AI Gemini | europe-west1 (Belgium) | YES — confirmed `:127` and `gemini-client.ts:28` |
| OCR.space | EU (Austria) | YES |
| Google Cloud Vision (fallback) | NOT documented — likely US default | **UNCLEAR** — adds to MEDIUM-1.1 finding |
| Algolia (inactive) | EU cluster (France) | YES — knowledge `2026-05-01 — Algolia EU cluster (BUT-580)` |

### Score: 5/5

All headers present, regions accurate, residency mapped. The Cloud Vision regional gap is captured in MEDIUM-1.1.

---

## Dimension 8 — Future Monetization Readiness (5 / 5)

No payments today. Pre-monetization checklist for documentation purposes only:

- [ ] PCI DSS — out of scope as long as Stripe/RevenueCat/Apple IAP is used (no PAN ever touched)
- [ ] Konsumentköplagen + ångerrätt (14-day) — needs clauses in ToS Section 5.x
- [ ] Automatic-renewal disclosure — needs pre-purchase information per EU Directive 2011/83/EU Art. 6
- [ ] VAT/moms handling — Apple/Google handle for IAP; needs separate handling for direct-to-consumer
- [ ] App Store IAP requirement — must use IAP for in-app digital goods
- [ ] Subscription cancellation UI — must be reachable in app per App Store Guideline 3.1.2(a)
- [ ] Företagsuppgifter (e-commerce law) — company name, org.nr, address must be visible
- [ ] Refund policy — placeholder section in ToS

ToS currently has no payment/billing section. When monetization arrives, this is a significant ToS revision (~5 new sections). Privacy policy may need a "Payment processing — Apple, Google, Stripe" sub-processor row.

### Score: 5/5

Forward-looking dimension; no current gap to penalize.

---

## Legal Document Accuracy Dashboard

| Claim in Legal Doc | File:Line | Code Reality | Match? | Severity |
|--------------------|-----------|--------------|--------|----------|
| AI provider: Vertex AI Gemini | privacy_policy_en.md:124-128 | `gemini-client.ts:28` europe-west1 Vertex | YES | OK (was the prompt's CRITICAL — already fixed) |
| OCR.space as third-party processor | privacy_policy_en.md:131-135, 166 | `ocr_extraction_service.dart:225-409` | YES | OK |
| Google Cloud Vision NOT named | not in policy | `ocr_extraction_service.dart:412-468` (fallback) | NO | MEDIUM-1.1 |
| Algolia inactive | privacy_policy_en.md:137 | feature-flagged off (knowledge BUT-580) | YES | OK |
| Cookie usage (mobile) | NOT in policy | No cookies in mobile app | YES | OK (was the prompt's MEDIUM — already fixed) |
| AES-256 SQLCipher | privacy_policy_en.md:277 | `pubspec.yaml: sqlcipher_flutter_libs` | YES | — but enables HIGH-5.1 |
| ITSAppUsesNonExemptEncryption=false | Info.plist:57-58 | App uses AES-256 | **NO** | HIGH-5.1 |
| Marketing legal-basis declared | privacy_policy_en.md:61 | No marketing system | NO | MEDIUM-6.1 |
| Security logs 90 days | privacy_policy_en.md:192 | audit_logs general bucket 6mo, consent 24mo | NO | MEDIUM-1.2 |
| Data residency europe-west1 | privacy_policy_en.md:163 | Confirmed | YES | OK |
| 13+ minimum age | privacy_policy_en.md:286, ToS:13 | Onboarding age gate | YES | OK |
| AI processing requires explicit consent | privacy_policy_en.md:126,133 | `llm_service.dart:42,270` | YES | OK |
| User can export data (Art. 20) | privacy_policy_en.md:216-219 | DataExportService (cited per 02) | YES | OK |
| User can delete account (Art. 17) | privacy_policy_en.md:211-214 | AccountDeletionService 3-tier cascade (cited per 02) | YES | OK |

---

## Master Checklist

```
LEGAL REVIEW CHECKLIST
======================

PRIVACY POLICY
[x] Third-party processor list matches actual code integrations (modulo Cloud Vision — MEDIUM-1.1)
[x] AI provider correctly named (Vertex AI Gemini, not Mistral)
[x] Cookie section removed and rewritten for mobile (already done)
[x] Algolia status accurately reflects feature-flag state
[x] OCR.space listed as processor
[ ] Google Cloud Vision listed as processor (MEDIUM-1.1)
[~] Data retention periods — partial mismatch (MEDIUM-1.2)
[x] Most collected data categories listed
[x] EN and SV versions are semantically equivalent

TERMS OF SERVICE
[x] Age requirement correct (13, Sweden GDPR Art. 8)
[x] Jurisdiction states Swedish law
[~] AI processing — generic "AI", not provider-named (LOW-2.1)
[x] User retains content ownership (5.1)
[ ] Account deletion consequences for shared data (MEDIUM-2.1)
[~] Liability disclaimer enforceable under Swedish consumer law (LOW-2.2)
[x] EN and SV versions are semantically equivalent

COMMUNITY GUIDELINES
[x] Covers harassment, spam, copyright, impersonation
[x] References reporting mechanism
[~] Block feature not mentioned (LOW-2.3)
[x] Accessible from social feature entry points
[x] EN and SV versions are semantically equivalent

LICENSES
[x] All pubspec.yaml dependencies have compatible licenses (cross-ref 05 — OK)
[x] All functions/package.json dependencies have compatible licenses (cross-ref 05 — OK)
[x] Font license files (OFL-1.1) bundled in assets/fonts/
[ ] Illustration provenance documented (MEDIUM-3.1)
[~] ONNX model license (LOW-3.2)
[x] Open-source license page accessible in app (account_security_view.dart:377)

AI COMPLIANCE
[x] AI processing consent (aiProcessing) actually gates Gemini calls
[ ] PII scrubber covers names and addresses (MEDIUM-4.1)
[~] EU AI Act risk classification documented (acceptable as minimal-risk)
[ ] AI-generated content transparency in UI (LOW-4.1)
[~] Vertex AI tier and DPA — DPA URL referenced; tier implicit (LOW-4.2)

APP STORE
[ ] iOS ITSAppUsesNonExemptEncryption accurately reflects SQLCipher usage (HIGH-5.1)
[~] iOS Privacy Manifest — Health (allergens) missing (MEDIUM-5.1)
[~] Google Play Data Safety — cannot verify, document recommendation (MEDIUM-5.2)
[x] Age rating consistent across stores, ToS, and privacy policy

CONSENT MODEL
[x] essentialServices, dataProcessing, analytics, socialFeatures, pushNotifications, aiProcessing each map to real functionality
[ ] marketing purpose orphan (MEDIUM-6.1)
[x] aiProcessing comment correct (Mistral comment removed)
[~] Consent UI accuracy — version not displayed (LOW-6.1), aiProcessing description generic (LOW-6.2)
[ ] No initial consent prompt (HIGH; cited from 09 HIGH-3.1)

FIREBASE / HOSTING
[x] Firebase Hosting has security headers (CSP, X-Frame-Options, etc.)
[x] Cloud Functions region — europe-west1 (no false Stockholm claim)
[x] Data residency documented per service
```

---

## Remediation Quick-Win Order (Phase 2 preview)

Doc-only edits (1 hour total, no code change):
1. Add Google Cloud Vision row to processor table (`privacy_policy_{en,sv}.md:163-167`) — 15 min — MEDIUM-1.1
2. Split retention table row "Security logs 90 days" → "Security logs 90 days" + "Consent audit logs 24 months" — 10 min — MEDIUM-1.2
3. Tighten PII-scrubber claim at `:129` to enumerate exact scrub categories — 10 min — MEDIUM-4.1 (path a)
4. Remove `marketing` consent row from privacy policy `:61` and `:88-91` — 10 min — MEDIUM-6.1 (path 1)
5. Add ToS section 5.4 "When you delete your account" — 15 min — MEDIUM-2.1
6. Add LICENSE.md to assets/illustrations/ — 30 min — MEDIUM-3.1
7. Add note to consent description that on-device AI is also processing — 10 min — MEDIUM-4.2

Code/config edits (1.5 hours):
8. Change `ITSAppUsesNonExemptEncryption` to `true` + claim TSU exemption — 1h (BIS SNAP-R) + 5 min (plist) — HIGH-5.1
9. Add NSPrivacyCollectedDataTypeHealth to PrivacyInfo.xcprivacy — 15 min — MEDIUM-5.1
10. Repo-wide Mistral→Vertex grep+replace in code-side doc-comments (8 files) — 30 min — LOW (cite 07)

Cross-prompt dependencies:
- 09 HIGH-3.1 (initial consent prompt) — 8h (own scope, not 11)
- 07 D7-CRIT-1 (Mistral docs in code) — overlapping with item 10 above
- 02 (consent service implementation) — 11 cites, doesn't fix

---

## File-Path References (absolute)

### Legal documents
- `C:\Butlery\butlery\assets\legal\privacy_policy_en.md`
- `C:\Butlery\butlery\assets\legal\privacy_policy_sv.md`
- `C:\Butlery\butlery\assets\legal\terms_of_service_en.md`
- `C:\Butlery\butlery\assets\legal\terms_of_service_sv.md`
- `C:\Butlery\butlery\assets\legal\community_guidelines_en.md`
- `C:\Butlery\butlery\assets\legal\community_guidelines_sv.md`

### Platform declarations
- `C:\Butlery\butlery\ios\Runner\Info.plist` (HIGH-5.1)
- `C:\Butlery\butlery\ios\Runner\PrivacyInfo.xcprivacy` (MEDIUM-5.1)
- `C:\Butlery\butlery\firebase.json` (Dim 7 — verified PASS)

### Consent + AI implementation
- `C:\Butlery\butlery\lib\models\account\user_consent.dart`
- `C:\Butlery\butlery\lib\services\account\consent_service.dart`
- `C:\Butlery\butlery\lib\views\account\consent_management_view.dart` (MEDIUM-6.1)
- `C:\Butlery\butlery\lib\viewmodels\account\consent_viewmodel.dart`
- `C:\Butlery\butlery\lib\services\llm\llm_service.dart`
- `C:\Butlery\butlery\lib\services\llm\pii_scrubber.dart` (MEDIUM-4.1)
- `C:\Butlery\butlery\functions\src\llm\pii-scrubber.ts` (MEDIUM-4.1)
- `C:\Butlery\butlery\functions\src\llm\gemini-client.ts`
- `C:\Butlery\butlery\functions\src\llm\structure-recipe.ts`
- `C:\Butlery\butlery\functions\src\llm\ocr-recipe-image.ts`
- `C:\Butlery\butlery\lib\services\ocr_extraction_service.dart` (MEDIUM-1.1 — Cloud Vision fallback)
- `C:\Butlery\butlery\lib\services\notifications\fcm_service.dart`
- `C:\Butlery\butlery\lib\services\notifications\notification_service.dart`

### Asset licensing
- `C:\Butlery\butlery\assets\fonts\JosefinSans-OFL.txt` (PASS)
- `C:\Butlery\butlery\assets\fonts\SpaceGrotesk-OFL.txt` (PASS)
- `C:\Butlery\butlery\assets\illustrations\` (no LICENSE — MEDIUM-3.1)
- `C:\Butlery\butlery\assets\illustrations\arta\` (no LICENSE — MEDIUM-3.1)

### Code-side documentation drift (LOW — cite 07)
- `C:\Butlery\butlery\functions\src\index.ts:10,24`
- `C:\Butlery\butlery\functions\src\llm\PROMPT_CHANGELOG.md:58`
- `C:\Butlery\butlery\functions\src\llm\ocr-recipe-image.ts:394` (acceptable contrast)
- `C:\Butlery\butlery\lib\services\import\heic_converter.dart:3`
- `C:\Butlery\butlery\lib\services\import\photo_import_strategy.dart:148`
- `C:\Butlery\butlery\lib\services\ocr_extraction_service.dart:565`
- `C:\Butlery\butlery\.claude\agents\cloud-functions-specialist.knowledge.md:20`

### App settings + license page
- `C:\Butlery\butlery\lib\views\settings\account_security_view.dart:377` (showLicensePage — PASS)

### Cross-referenced reports
- `C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\02-security.md` (consent service implementation — cited)
- `C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\05-dependencies.md` (sqlcipher EOL — LOW-3.1)
- `C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\06-user-experience.md:158` (Info.plist mention — does not flag HIGH-5.1)
- `C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\07-ai-llm-quality.md` D7-CRIT-1 (Mistral drift — overlapping with item 10)
- `C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\09-trust-safety-privacy.md` HIGH-3.1 (initial consent prompt — cited)
- `C:\Butlery\butlery\docs\analysis\runs\2026-05-claude\10-monetization.md:45` (Info.plist mention — does not flag HIGH-5.1)

---

## Self-improvement note for knowledge file

To be appended to `firebase-backend-security.knowledge.md` after Phase 1 sign-off:

```
### 2026-05-02 — iOS encryption export self-classification: ITSAppUsesNonExemptEncryption=false is wrong when SQLCipher is on the dependency tree

`ios/Runner/Info.plist` declaring `ITSAppUsesNonExemptEncryption=false` is incorrect any time the app links AES-256 cipher code (SQLCipher, libsodium, native CryptoKit beyond OS-built-in TLS, etc.). The mass-market consumer-encryption exemption (15 CFR 740.17(b)(1)) is the correct legitimate path; it requires `true` + TSU claim, not `false`. Fast remediation: file ERN via SNAP-R (1h), update plist to `true`, add `ITSEncryptionExportComplianceCode`. Apple App Store Connect prompts for this on submission.

Cross-reference: privacy_policy_en.md `:277` literally states "AES-256 encrypted storage (SQLCipher)" — bundle is self-contradictory.
```

---

**End of Phase 1 — Legal Review.**
