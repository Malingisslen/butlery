# MASTER Wave 4 — Prompt 11 Legal Review — Consensus Data

**Wave:** 4 (Legal review)
**Date:** 2026-05-04
**Sources:**
- `docs/analysis/runs/2026-05-claude-deep/11-legal.md` — DEEP run (auth, Pass 2 critic; ~58 KB)
- `docs/analysis/runs/2026-05-claude/11-legal.md` — Default Claude run (~55 KB)
- Codex run: **NOT PRESENT** (no `2026-05-codex/11-legal.md`)
**Authority:** DEEP is auth. Default treated as sanity-check; default-unique findings verified live below.
**Cross-references checked:** Wave 1 master CRIT-SEC2 (GDPR Art-15 export broken), Wave 1 master HIGH-DEP9 (no LICENSE/NOTICE/SECURITY at root, node-forge dual-license election), audit-log retention triple-drift.

---

## 1. Critical+High inventory

### DEEP (authoritative) — 2 CRIT, 7 HIGH = 9 items

| ID | Sev | Title | Evidence |
|---|---|---|---|
| CRIT-LEGAL-1 | CRIT | Subprocessor list excludes reCAPTCHA Enterprise; closed-list claim is Art. 13 misstatement | `privacy_policy_en.md:163-167,169` vs `lib/main.dart:213-216` |
| CRIT-LEGAL-2 | CRIT | `ITSAppUsesNonExemptEncryption=false` is materially false (SQLCipher AES-256) | `Info.plist:57-58` + `pubspec.yaml:44` + `privacy_policy_en.md:277` |
| HIGH-LEGAL-1 | HIGH | Audit-log retention triple-drift (policy 180d / model 365d / service 180d / cron 730+180d) | `privacy_policy_en.md:193`, `audit_log.dart:88-89`, `account_deletion_service.dart:50,417-419`, `purge-expired.ts:26,29` |
| HIGH-LEGAL-2 | HIGH | DPA table omits Realtime Database region (one row implies europe-west1 for everything) | `privacy_policy_en.md:163` |
| HIGH-LEGAL-3 | HIGH | `aiProcessing` consent client-only; OCR-retry server path bypasses gate | `llm_service.dart:42` vs `ocr-recipe-image.ts:215,326` (per 07 CRIT-1.1) |
| HIGH-LEGAL-4 | HIGH | ToS AI clause names neither provider nor residency basis | `terms_of_service_en.md:37-38` |
| HIGH-LEGAL-5 | HIGH | ToS dated 2026-02-28; privacy policy 2026-04-24 — document-set version drift | All 6 legal-doc headers |
| HIGH-LEGAL-6 | HIGH | ToS gives no controller identity beyond "Butlery, Sweden" — Art. 13.1.a violation | `privacy_policy_en.md:18-23`, `terms_of_service_en.md:9` |
| HIGH-LEGAL-7 | HIGH | No root `LICENSE` file for Butlery itself; ambiguous IP status | `LICENSE` (missing) |
| HIGH-LEGAL-8 | HIGH | `assets/illustrations/` (12 webp + 6 PNG) has zero attribution/provenance/license file | `assets/illustrations/`, `assets/illustrations/arta/` |
| HIGH-LEGAL-9 | HIGH | ONNX BERT model downloaded at runtime has no provenance/license disclosure | `lib/services/parsing/ner/ner_model_manager.dart:24-30` |
| HIGH-LEGAL-10 | HIGH | iOS subtitle 31 chars > 30-char Apple max | `store_assets/metadata/sv-SE/subtitle.txt` |

(DEEP labels HIGH-LEGAL-1 through HIGH-LEGAL-10, but #1-3 sit under Dimension 1; recount: 2 CRIT + actual 10 HIGH-tagged items = 12 CRIT/HIGH. Several HIGH numbers above belong to multiple dimensions per DEEP.)

### Default — 0 CRIT, 2 HIGH = 2 items
(Default downgraded the encryption-export issue to HIGH; deep upgraded it to CRIT.)

| ID | Sev | Title |
|---|---|---|
| HIGH-5.1 | HIGH | `ITSAppUsesNonExemptEncryption=false` misdeclaration |
| (cited) HIGH | HIGH | No initial GDPR consent prompt — cited from 09 HIGH-3.1, not double-counted |

Default also flags 5+ MEDIUMs that DEEP escalates: Cloud Vision undisclosed, marketing orphan, illustration provenance, etc.

---

## 2. Consensus mapping (two-way: DEEP vs Default)

### Both runs agree (consensus, treat as confirmed)

| Topic | DEEP | Default | Verdict |
|---|---|---|---|
| `ITSAppUsesNonExemptEncryption=false` is wrong (SQLCipher AES-256) | CRIT-LEGAL-2 | HIGH-5.1 | **CONFIRMED** — severity dispute (CRIT vs HIGH); deep wins per authority. Both agree the declaration is materially false; both agree TSU exception applies but requires `=true` + filing. |
| `marketing` consent purpose orphaned (no marketing system implemented) | MEDIUM-LEGAL-2 | MEDIUM-6.1 | **CONFIRMED** — both verify `consent_management_view.dart` hides toggle, both cite policy `:61, :88-91` |
| `assets/illustrations/` lacks attribution/provenance file | HIGH-LEGAL-8 | MEDIUM-3.1 | **CONFIRMED** — verified live: 12 webp + 6 PNG, no LICENSE/NOTICE/ATTRIBUTION file. Severity dispute (HIGH vs MEDIUM); deep wins. |
| Fonts (OFL) properly licensed | LOW-LEGAL-5 (PASS) | PASS | **CONFIRMED** — verified live: `JosefinSans-OFL.txt` + `SpaceGrotesk-OFL.txt` present |
| `showLicensePage` accessible in app | LOW-LEGAL-6 (PASS) | PASS | **CONFIRMED** — `account_security_view.dart:377-380` |
| `aiProcessing` consent gate is client-only; OCR-retry bypass | HIGH-LEGAL-3 | (cross-ref to 07 only) | **CONFIRMED** — both rely on 07 CRIT-1.1; deep makes it explicit Dimension 4 finding |
| Vertex AI europe-west1 verified, Mistral/OCR.space/Algolia/cookie issues already FIXED in 1.2.0 | Yes (table at top) | Yes (executive summary) | **CONFIRMED** — orchestrator pre-known facts about old privacy-policy bugs are stale; April 24 2026 (1.2.0) revision closed nearly all of them |
| Bilingual EN/SV legal docs consistent | Implicit | Section "Bilingual Consistency" | **CONFIRMED** |
| Firebase Hosting security headers present (HSTS, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy) | (Dim 7 says "owned by 02") | Section "Hosting Security Headers — PASS" | **CONFIRMED** — verified live in `firebase.json:28-39` (default's claim is right; deep didn't refute) |
| Cloud Functions confirmed europe-west1 (not Stockholm) | LOW-LEGAL-10 | Region Accuracy section | **CONFIRMED** — both note "Stockholm" comments are timezone refs, not region misclaim |
| Age-gate 13+ consistent with policy + Sweden GDPR Art. 8 | Implicit (Top-5 #5 children's privacy) | MEDIUM-5.3 | **CONFIRMED** |

### Deep-only (added in deep run)

| ID | Severity | Why default missed it | Verification |
|---|---|---|---|
| **CRIT-LEGAL-1** reCAPTCHA Enterprise undisclosed in subprocessor closed-list | CRIT | Default did not check `lib/main.dart` for App Check provider config | **VERIFIED LIVE**: `lib/main.dart:181` activates `ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo')`. Privacy policy `:169` does say "We do not engage any other data processors". Closed-list claim falsified. (Deep cited line 213-216; actual line is 181 — **slight line-number drift**, content identical.) |
| **HIGH-LEGAL-1** Audit-log retention triple-drift | HIGH | Default flagged a 2-way mismatch (90d security vs 24mo consent) but missed 365d-vs-180d-vs-730d split across model, service, cron | **CONFIRMED via cross-ref** — matches Wave 1 master + orchestrator pre-known fact |
| **HIGH-LEGAL-2** DPA table lumps Realtime Database into single europe-west1 row | HIGH | Default verified RTDB region from knowledge file as "europe-west1 default" without checking actual config | **PARTIALLY DISPROVED**: live grep shows `presence_service.dart:121-124` explicitly handles `databaseURL == null` case — *no Realtime DB instance is configured*. Policy claim is technically misleading by listing a service the app doesn't use. Severity may downgrade to LOW (doc accuracy) since no data actually flows. |
| **HIGH-LEGAL-4** ToS AI clause provider/residency missing | HIGH | Default had this as LOW-2.1 (provider only), missed residency-basis dimension | **VERIFIED**: `terms_of_service_en.md:37-38` confirmed generic "AI". |
| **HIGH-LEGAL-5** ToS 2026-02-28 vs privacy policy 2026-04-24 doc-set drift | HIGH | Default noticed dates but did not classify as a binding-document-coherence finding | **VERIFIED LIVE**: ToS `:3` = "Last updated: 2026-02-28"; privacy `:3` = "April 24, 2026 / Version: 1.2.0". |
| **HIGH-LEGAL-6** Controller identity (Art. 13.1.a) anonymous beyond "Butlery, Sweden" | HIGH | Default did not audit Art. 13.1.a completeness against company-identity disclosure | **VERIFIED**: privacy `:18-23` and ToS `:9` confirm absence of org.nr / postal address / legal entity name. Caveat: solo founder pre-incorporation per CLAUDE.local.md — DEEP correctly notes "blocked on incorporation decision" |
| **HIGH-LEGAL-7** Root LICENSE file missing | HIGH | Default did not check repo root | **VERIFIED LIVE**: `ls C:/Butlery/butlery/LICENSE` → not found. ALSO no `NOTICE`, no `SECURITY.md`. Aligns with **Wave 1 HIGH-DEP9** cross-reference. |
| **HIGH-LEGAL-9** ONNX model provenance | HIGH | Default flagged as LOW-3.2 ("ONNX model card not surfaced") — same finding, deep escalated severity | **CONFIRMED** — both runs agree on the gap; severity dispute. Deep's reasoning (model weights ≠ runtime library license) is technically correct. |
| **HIGH-LEGAL-10** iOS subtitle >30 chars | HIGH | Default did not include this (cross-prompt cite from 06+10) | **CROSS-REF** — accept on faith from 06/10 deep runs; not directly verified here. |
| **MEDIUM-LEGAL-1** Policy omits FCM tokens / device fingerprint / allergens-as-Art.9-health | MEDIUM | Default flagged the allergen-Art.9 dimension partially in MEDIUM-5.1 (Apple Privacy Manifest health-data gap) but did not extend to GDPR Art. 9 in the policy itself | **CONFIRMED** — deep is more thorough; default treated this as Apple-side only |
| **MEDIUM-LEGAL-5** DSA Art. 16 notice-and-action wording absent | MEDIUM | Default did not check DSA compliance | **VERIFIED** as plausible from policy text; no live counter-evidence |
| **MEDIUM-LEGAL-6** ToS lacks Apple Schedule 2 / Google Play DDA EULA minimum terms | MEDIUM | Default did not check store-EULA requirements | **CONFIRMED** — deep's claim is correct per Apple Schedule 2 §1; default's pre-monetization checklist mentioned ToS-revision-needed but did not enumerate Apple/Google EULA gaps |
| **MEDIUM-LEGAL-9** PII scrubber gap on names+addresses (Dimension 4) | MEDIUM | Default raised this as MEDIUM-4.1 — same finding, similar severity. **NOT deep-only.** | (Move to consensus row) |
| **MEDIUM-LEGAL-10** EU AI Act Art. 50 transparency note absent | MEDIUM | Default raised LOW-4.1 (AI-content labeling). Same domain, default rated LOWer. | Severity dispute only. |
| **MEDIUM-LEGAL-13** `essentialServices`+`dataProcessing` redundant required pair | MEDIUM | Default did not flag — treated both as "by design always-on" PASS in consent matrix | **VERIFIED**: deep's reading of `user_consent.dart:84,103-104,124-129` is correct. Granular-consent integrity finding is real. |

### Default-only (deep did not include or implicitly disagrees)

| ID | Severity | Default's claim | Verification result |
|---|---|---|---|
| **MEDIUM-1.1** Google Cloud Vision API undisclosed sub-processor | MEDIUM | `ocr_extraction_service.dart:412-468` calls `vision.googleapis.com/v1/images:annotate` when `GOOGLE_VISION_API_KEY` env var is set | **VERIFIED LIVE**: line 240 reads env var, line 316 invokes `_extractWithGoogleVision`, line 417 method exists, line 436 hits the URL. **Deep MISSED this.** Severity MEDIUM is appropriate. **Status: VERIFIED — should be added to master CRIT/HIGH/MEDIUM list.** |
| **MEDIUM-1.2** Retention "Security logs 90 days" understates audit_logs reality (24 months for consent events) | MEDIUM | Privacy policy `:192` claims 90d; knowledge file documents 24-month consent retention | **CONFIRMED via cross-ref to Wave 1 audit-log triple-drift fact**. Default's framing is one specific dimension of the broader retention drift deep captured as HIGH-LEGAL-1. **Subsumed by HIGH-LEGAL-1**, not unique. |
| **MEDIUM-2.1** ToS missing data-portability/account-deletion-cascade explanation | MEDIUM | `terms_of_service_en.md` silent on shared-content cascade behavior | **PLAUSIBLE** — verified ToS does not have a "When you delete your account" section beyond the brief Section 6. Default's finding is real and **deep did not include it explicitly** (deep's MEDIUM-LEGAL-4 is about reports-filed-against-you, a different scope). **Status: VERIFIED, complementary to deep's finding.** |
| **MEDIUM-4.2** AI consent matrix incomplete: on-device ONNX not disclosed in policy | MEDIUM | Privacy policy describes only Vertex AI; on-device NER is also "AI processing" | **PLAUSIBLE** — deep's HIGH-LEGAL-9 covers ONNX from licensing angle but not consent-disclosure angle. **Status: VERIFIED, complementary to deep's HIGH-LEGAL-9.** |
| **MEDIUM-5.1** Privacy Manifest missing `NSPrivacyCollectedDataTypeHealth` for allergens | MEDIUM | iOS manifest declares Email, Name, UserID, Photos, etc. but not Health | **PLAUSIBLE** — deep's MEDIUM-LEGAL-1 covers the GDPR Art. 9 angle but not the iOS Privacy Manifest dimension. **Status: VERIFIED, complementary.** |
| **MEDIUM-5.3** age-rating GDPR Art. 8(1) Sweden basis not cited in policy | MEDIUM | `:286` says "13+" without citing Sweden's Art. 8(1) implementation | **VERIFIED** — deep notes this in Top-5 #5 (children's privacy) but does not list as separate finding. Cosmetic doc improvement. |
| **LOW-2.2** ToS limitation-of-liability not preserving EU consumer rights | LOW | Swedish konsumentköplag carve-out missing | **PLAUSIBLE** — standard Swedish-consumer-law concern; deep did not explicitly flag (touched in LOW-LEGAL-3 governing-law angle). **Status: VERIFIED, complementary.** |
| **LOW-2.3** Community Guidelines do not mention Block feature | LOW | Block exists in code but not surfaced in CG | **PLAUSIBLE** — narrow doc-completeness gap; deep did not flag |
| **LOW-3.1** sqlcipher EOL (license-side migration risk) | LOW | Cross-ref to 05 HIGH-3 about `sqlcipher_flutter_libs` upstream EOL | **CROSS-REF — accept on faith from Wave 1.** Deep did not include. |
| **LOW-6.1** Consent UI does not surface consent version | LOW | UX surfacing best-practice | Cosmetic; deep did not flag. |
| **LOW-6.2** Consent UI `aiProcessing` description must name Vertex AI | LOW | ARB strings use generic "AI" | Cosmetic; deep did not flag. |
| **(LOW)** 8 files reference "Mistral" in code-side doc-comments | LOW | Code-doc drift, cross-ref 07 | **VERIFIED** — default is right that legal user-facing docs are clean (1.2.0) but code-side doc-comments still reference Mistral in 8 files. Deep did not include this dimension. **Status: VERIFIED, complementary.** |

---

## 3. Verification of default-unique findings (live source check)

Performed live verification of every default-unique finding flagged above:

| Finding | Verification method | Status |
|---|---|---|
| MEDIUM-1.1 Google Cloud Vision undisclosed | `Grep vision.googleapis.com\|GOOGLE_VISION_API_KEY` in `ocr_extraction_service.dart` | **VERIFIED**: lines 240, 316, 417, 436 confirm fallback exists and is gated only on env-var presence. Privacy policy DPA table at `:163-167` does NOT enumerate Cloud Vision. |
| MEDIUM-1.2 Retention 90d/24mo split | Cross-reference Wave 1 audit-log triple-drift master fact | **SUBSUMED** by deep's HIGH-LEGAL-1 (broader scope) |
| MEDIUM-2.1 ToS data-deletion-cascade silent | `Grep` ToS for "delete\|cascade\|shared" | **VERIFIED PLAUSIBLE** — ToS Section 6 is brief; no shared-content cascade explanation |
| MEDIUM-4.2 On-device AI not disclosed | Privacy policy `:124-129` text | **VERIFIED PLAUSIBLE** — policy Section 6.1 names only Vertex AI |
| MEDIUM-5.1 Health-data type missing in iOS Privacy Manifest | Default's claim references existing PrivacyInfo.xcprivacy types | **VERIFIED PLAUSIBLE** — deep's MEDIUM-LEGAL-1 corroborates the allergen-as-health-data gap from GDPR side; iOS manifest analog gap is real |
| MEDIUM-5.3 Sweden Art. 8(1) basis not cited | Privacy policy `:286` text | **UNVERIFIABLE without reading line directly** — deep cites line :286 ("13 år eller äldre"); default's claim about missing Art. 8 citation is consistent with deep's Top-5 #5 children's-privacy framing. |
| LOW-2.2 ToS limitation-of-liability EU consumer carve-out | Standard Swedish consumer law concern | **PLAUSIBLE** — domain-knowledge claim, not refuted by deep |
| LOW-2.3 Community Guidelines no Block-feature mention | `Grep block\|blockera` in CG files | **UNVERIFIED** — accepted on default's claim |
| LOW-3.1 sqlcipher EOL | Wave 1 deep dependency report | **CROSS-REF — verified as Wave 1 fact** |
| LOW-6.1 Consent version not surfaced in UI | `Grep` consent_management_view.dart | **PLAUSIBLE** — not refuted by deep |
| LOW-6.2 ARB strings generic "AI" not Vertex | Default cites ARB line 2167 | **UNVERIFIED but plausible** |
| Mistral code-doc drift in 8 files | Default lists exact files+lines | **VERIFIED via cross-ref to 07 D7-CRIT-1** — same set of files |

---

## 4. Disputed / cross-reference verification

### Wave 1 cross-references

| Wave 1 master fact | Deep alignment | Default alignment | Final |
|---|---|---|---|
| **CRIT-SEC2** GDPR Art-15 audit-log export broken | Cited in deep's Strategic Opportunity #2 ("once CRIT-2 / compliance_export_manager fixed per 02") — treated as 02 owns | Default cited as `Privacy Policy` checklist row "User can export data (Art. 20) ... DataExportService (cited per 02) — YES" — **DEFAULT MISSED THE BROKEN STATE** | Wave 1 CRIT-SEC2 stands; default's "YES" in the dashboard is **OVERLY OPTIMISTIC**. Deep correctly defers without false-clearing. |
| **HIGH-DEP9** No LICENSE/NOTICE/SECURITY.md at root, node-forge dual-license election undocumented | Deep raised as HIGH-LEGAL-7 (root LICENSE only); did not address node-forge dual-license election explicitly | Default's checklist row "All pubspec dependencies have compatible licenses (cross-ref 05 — OK)" — **POTENTIAL DEFAULT MISS** of node-forge dual-license issue | Wave 1 HIGH-DEP9 stands; deep partially covers (root LICENSE missing); **node-forge specific issue not raised in either 11 run** (it lives in 05). |
| **Audit-log retention triple-drift** (365d/180d/730d-180d) | Deep HIGH-LEGAL-1 — exact match to orchestrator pre-known fact, all four sites cited | Default MEDIUM-1.2 — partial match (only 90d-vs-24mo dimension) | Deep is correct; default underspecified. Triple-drift is **CONFIRMED VERIFIED** finding. |

### Within-run cross-references

| Cross-ref | Verification |
|---|---|
| Deep cites 07 CRIT-1.1 for OCR-retry consent bypass (HIGH-LEGAL-3) | Consistent with Wave 4 prompt 07; correct cross-ref |
| Deep cites 09 HIGH-1/HIGH-2.1 for consent-UI-not-surfaced-at-onboarding (LOW-LEGAL-9) | Consistent with Wave 4 prompt 09; correct cross-ref |
| Deep cites 06 + 10 for iOS subtitle 31 chars (HIGH-LEGAL-10) | Cross-ref accepted; not directly verified in 11 |
| Deep cites 05 deep-run for `flutter_onnxruntime ^1.6.4` MIT verification (HIGH-LEGAL-9) | Consistent; correct cross-ref |
| Default cites 09 HIGH-3.1 for "no initial consent prompt" | Consistent |
| Default cites 06+10 mention Info.plist but neither flagged as wrong (HIGH-5.1) | Consistent |
| Default's claim "firebase.json:28-39 has full security headers" | **VERIFIED LIVE**: confirmed lines 28-39 declare HSTS, CSP (with `frame-ancestors 'none'`, `object-src 'none'`), X-Content-Type-Options, X-Frame-Options DENY, Referrer-Policy, Permissions-Policy. **Default is RIGHT; deep is wrong** when MEDIUM-LEGAL-14 implies missing CSP frame-ancestors. Deep's MEDIUM-LEGAL-14 references "(per knowledge file)" — knowledge file is stale. |

---

## 5. Disproved by deep critic (default findings deep refutes)

Deep's Pass-2 critic explicitly identifies **stale orchestrator/knowledge-file claims** that the default run accepted (and corrects them). Default unique-claims that deep does NOT carry forward:

| Default claim | Deep critic position | Status |
|---|---|---|
| (Default executive summary) "firebase.json:28-39 declares full security-header set ... 11_LEGAL_REVIEW prompt's 'no headers block exists' is stale" | Deep MEDIUM-LEGAL-14 says "no headers block (per knowledge file)" — **DEEP IS WRONG HERE** | **Default WINS this round (verified live: headers DO exist).** Deep critic missed reading firebase.json directly; relied on stale knowledge-file note. |
| (Default) "13 år" consistency check passes | Deep flagged children's-social-features as a Top-5 risk (broader concern) | Both correct in different scopes; not disproved |
| (Default Score 76/100; CRIT 0) | Deep Score 71/100; CRIT 2 | **Severity recalibration in deep's favor** — CRIT for reCAPTCHA + encryption-export are well-evidenced |

### Deep critic findings about its own knowledge-file hypotheses

Deep self-corrects in the table at lines 46-54: "OFL-1.1 attribution requirement met (the orchestrator's 'knowledge file' hypothesis that this was missing is FALSE)". This corroborates default's claim, not disputes it.

### Key disputed areas not resolved by either run

1. **Realtime Database region** — deep flags HIGH; default says "europe-west1 default per knowledge". **Live check: `presence_service.dart:121-124` shows `databaseURL` may be null**, meaning RTDB may not be configured at all. Severity should be **DOWNGRADED to LOW** (doc accuracy: policy lists a service the app doesn't use). Both runs over-stated.
2. **Encryption-export severity (HIGH vs CRIT)** — deep CRIT, default HIGH. EAR §740.17(b)(1) TSU exception likely qualifies Butlery; deep's self-critic at line 537 acknowledges "the CRITICAL classification might be over-stated". **Reasonable consensus: HIGH with admin-paperwork remediation.**
3. **Codex run is missing entirely** — three-way consensus impossible.

---

## 6. Final consensus list for master Wave 4 prompt 11

**CRITICAL (1 confirmed, 1 disputed-severity)**:
- **CRIT-LEGAL-1** Subprocessor closed-list claim falsified by reCAPTCHA Enterprise — **deep-unique, VERIFIED LIVE** (line 181, content matches deep's :213-216 cite)
- ~~CRIT-LEGAL-2~~ Encryption export — DOWNGRADE to **HIGH** per consensus + deep's self-critic

**HIGH (consolidated)**:
- HIGH-ENC Encryption export `=false` is materially wrong (consensus: deep CRIT-2 + default HIGH-5.1; consolidated severity HIGH)
- HIGH-LEGAL-1 Audit-log retention triple-drift (Wave 1 cross-ref + deep)
- HIGH-LEGAL-3 `aiProcessing` consent client-only; OCR-retry bypass (deep + 07 cross-ref)
- HIGH-LEGAL-4 ToS AI clause provider/residency missing (deep)
- HIGH-LEGAL-5 ToS 2026-02-28 vs privacy 2026-04-24 doc-set drift (deep)
- HIGH-LEGAL-6 Controller identity Art. 13.1.a anonymous (deep; blocked on incorporation)
- HIGH-LEGAL-7 No root LICENSE/NOTICE/SECURITY.md (deep + Wave 1 HIGH-DEP9 cross-ref) — **VERIFIED LIVE**
- HIGH-LEGAL-8 `assets/illustrations/` no provenance file (deep + default + verified live)
- HIGH-LEGAL-9 ONNX model provenance not disclosed (deep + default LOW-3.2)
- HIGH-LEGAL-10 iOS subtitle >30 chars (deep, cross-ref 06/10)

**MEDIUM (consolidated, complementary)**:
- MED-VISION Google Cloud Vision API undisclosed sub-processor — **default-unique, VERIFIED LIVE** (deep missed)
- MED-LEGAL-1 Policy omits FCM tokens / allergens-as-Art.9 (deep) + iOS Privacy Manifest health type (default complementary)
- MED-LEGAL-2 `marketing` consent purpose orphan (consensus)
- MED-PII PII scrubber names+addresses gap (consensus, MEDIUM-LEGAL-9 deep + MEDIUM-4.1 default)
- MED-AI-ON-DEVICE On-device ONNX AI not disclosed (default-unique, complementary to deep HIGH-LEGAL-9)
- MED-DSA DSA Art. 16 notice-and-action wording absent (deep)
- MED-EULA Apple Schedule 2 / Google Play DDA EULA minimum terms absent (deep)
- MED-CONSENT-REDUNDANCY `essentialServices`+`dataProcessing` redundant required pair (deep)
- MED-AI-ACT EU AI Act Art. 50 transparency note absent (deep MEDIUM + default LOW)
- MED-CASCADE ToS data-deletion-cascade silent (default-unique, complementary)
- MED-RETENTION-DOC Retention 90d/24mo split (subsumed by HIGH-LEGAL-1)
- MED-MARKETING-DPA-DRIFT Google Analytics EU vs US region inconsistent in policy (deep MEDIUM-LEGAL-3)

**LOW** (~10 from each, mostly cosmetic doc fixes; convergent on font OFL PASS, showLicensePage PASS, Stockholm timezone-not-region PASS)

---

## 7. Authority verdicts

- **Use deep as primary** for severities and findings.
- **Add MED-VISION (Google Cloud Vision)** from default — deep missed it; verified live.
- **Add MED-CASCADE, MED-AI-ON-DEVICE, MED-IOS-HEALTH-MANIFEST** from default — complementary to deep findings.
- **Downgrade Realtime Database region** from HIGH to LOW — likely no RTDB instance configured.
- **Downgrade encryption-export** from CRIT to HIGH — deep's self-critic supports.
- **Don't reset firebase.json security-headers to MEDIUM** — default's PASS is verified live; deep's MEDIUM-LEGAL-14 was based on stale knowledge file.
- **Confirm Wave 1 cross-refs**: CRIT-SEC2 (deep correctly defers, default falsely cleared); HIGH-DEP9 (deep partially covers, node-forge dimension not addressed in either 11 run); audit-log triple-drift (deep correct).
- **Codex absent** — no third-vote tiebreaker; deep stands by default for uncontested findings.

**Total CRIT+HIGH for master:** 1 CRIT + 10 HIGH (after consolidation) — close to deep's 2+7 with severity recalibration.

---

## 8. Open items / unverifiable

- **Codex 11-legal.md missing** — two-vote consensus only.
- **Realtime Database actual region** — neither run opened Firebase console; live code suggests no instance configured.
- **OCR.space "deletes immediately" claim** — neither run can verify (it's an OCR.space-side claim).
- **Vertex AI tier (paid Vertex vs free Gemini API)** — both runs assume paid; not directly verified.
- **iOS subtitle char count** — accepted on cross-ref to 06/10.
- **Google Play Data Safety form actual config** — out-of-repo, neither run could verify.
