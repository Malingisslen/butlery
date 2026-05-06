# MASTER Wave 3 — Prompt 09 Trust, Safety & Advanced Privacy — Consensus Data

**Compiled:** 2026-05-04
**Inputs:**
- `docs/analysis/runs/2026-05-claude/09-trust-safety-privacy.md` (548 lines, Claude default) — score 80/100
- `docs/analysis/runs/2026-05-claude-deep/09-trust-safety-privacy.md` (856 lines, Claude deep + Pass 2 critic) — score 71/100 → revised **60/100** (Pass 2)
- Codex run: **MISSING** (no `2026-05-codex/09-trust-safety-privacy.md` on disk; only prompts 01/02/05 present in codex folder)

**Authority rule:** deep (with Pass 2 critic) is auctoritative; default used as sanity-check. Pass 2 already live-verified every Pass-1 CRITICAL/HIGH against source — its corrections supersede default wherever they conflict. Wave 1 cross-references (consent-purpose, audit-log retention, friend_requests, GDPR Art-15 export) are pulled in below; ConsentPurpose is already resolved on disk per Wave 1 prompt 02.

**Live re-verification done in this synthesis (mtime 2026-05-04):**
- `lib/models/account/user_consent.dart:91-99` — **`ConsentPurpose` enum has 7 values**: `essentialServices, dataProcessing, analytics, marketing, socialFeatures, pushNotifications, aiProcessing`. Live-confirmed.
- `lib/models/social/content_type.dart:10-17` — **`ContentType` enum has 6 values**: `recipe, comment, message, profile, cookSnap, group`. Docstring (lines 1-8) explicitly says retired wire names (`'rating'`, `'shopping_list'`) return null from `fromWire`.
- `firestore.rules:1668-1699` — `reports` collection. **Confirmed: no `rateLimitWrite`, no `description`/`reason` size cap, no `contentType in [...]` enum, no `contentOwnerId != reporterId` self-report block.** Required-fields list at line 1680 is `['reporterId','contentType','contentId','reason','status','createdAt']`. Both runs cited slightly different line ranges (`1595-1601` default, `1596-1599` deep) — the file has shifted; substance unchanged.
- `firestore.rules:454-500` — `public_profiles/{userId}` read rule is `allow read: if isAuthenticated();` (line 456). **No `isHidden` filter on read.** Admin update at line 496-499 sets `isHidden+hiddenAt` only. Owner update at 474-481 forbids writing `isHidden`/`hiddenAt`. Deep's NEW HIGH (read-side advisory only) live-verified.
- `lib/services/account/account_deletion_service.dart:164-208` — **Tier-1 has 25 entries, Tier-2 has 2 entries, Tier-3 has 1 entry** (total 28 cascade ops across 3 tiers). `'reports': () => _socialOps.deleteUserReports(userId)` at line 182 — purges reports the user FILED, not reports filed AGAINST them. `_probeResidualData` at lines 286-323 probes only 3 collections (`recipes`, `userNotifications`, `userFcmTokens`) — `reports` not in the probe set. Deep HIGH-1.1 live-verified.
- `lib/main.dart:179-182` — **`FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo'), ...)` runs in the early-init `Future.wait` block.** Site key in source binary. `_initializeModularSystem` is invoked at line 209; `_enableCollectionIfConsented` is at line 268-278. **App Check / reCAPTCHA fires before consent gate** — confirmed (deep cited `213-223` and `295`; substance correct, line numbers shifted).
- `lib/views/onboarding/` — directory listing confirms exactly 7 files (5 actual onboarding pages + age-gate-blocked + the wizard host): `onboarding_view.dart`, `onboarding_age_gate_page.dart`, `onboarding_age_gate_blocked_view.dart`, `onboarding_welcome_page.dart`, `onboarding_allergen_page.dart`, `onboarding_dietary_page.dart`, `onboarding_import_page.dart`. **Grep `consent|Consent` returns zero matches.** No consent UI in onboarding. Confirmed.
- `storage.rules` (full 76-line file) — **zero references** to `safeSearch`, `nsfw`, `imageModeration`, SafeSearch, adult-likelihood. `cook_snaps` covered by `users/{userId}/{allPaths=**}` (line 21-31), `shared/recipes/{recipeId}/**` at line 34-54, `feedback/{userId}/**` at line 62-69 — all 10 MB cap, image-content-type only, no moderation. Deep NEW CRITICAL (image moderation gap) live-verified.
- `assets/legal/privacy_policy_en.md` + `_sv.md` — **grep `reCAPTCHA|recaptcha|App Check|appcheck` returns zero matches in either file.** reCAPTCHA Enterprise is active in production but absent from the subprocessor list in both languages. Deep Pass-2 NEW MEDIUM verified. (Default did not catch this.)
- `lib/services/consent/` directory — **does NOT exist**; consent code lives at `lib/services/account/consent_service.dart` (10.8 KB). Orchestrator's path hint is stale; both runs correctly cited `lib/services/account/`.
- Wave 1 cross-references re-confirmed: ConsentPurpose drift resolved on disk (no longer a compile error); audit-log retention triple-drift documented in Wave 1 prompt 02 MEDIUM-1; GDPR Art-15 export is broken per Wave 1 CRIT-SEC2; `friend_requests` collection bug per Wave 1 HIGH-SEC2 — none of these are owned by 09 (cross-prompt boundaries respected by both runs).

---

## Score consensus

| Run | Score | Critical | High | Medium | Low | Informational |
|---|---:|---:|---:|---:|---:|---:|
| Codex | (missing) | — | — | — | — | — |
| Default (Claude) | 80/100 | 0 | 1 | 4 | 5 | 3 |
| Deep Pass 1 | 71/100 | 1 | 2 | 7 | 8 | 4 |
| Deep Pass 2 (final) | **60/100** | **2** | **4** | **10** | **8** | 5 |

**Consensus baseline: 60-65 / 100.** Default's 80 is an outlier — Pass 2 added one CRITICAL (image moderation) + two new HIGHs (rule-side `contentType` enum, `isHidden` read enforcement) that default missed entirely. Deep's Pass-1 elevation of the `reports`-rule gap from MEDIUM (default) → CRITICAL (deep) is well-evidenced (brigade-amplifier surface, weaponizable moderator queue) and is the single biggest score driver. The 20-point gap between default 80 and deep-Pass-2 60 reflects four legitimate findings default missed, not over-rating by deep.

---

## CRITICAL findings

| # | Title | Default | Deep P1 | Deep P2 | Verification | Notes |
|---|---|:-:|:-:|:-:|---|---|
| C-1 | `reports` create rule lacks rate limit / size caps / `contentType` enum / self-report block — moderator queue is brigade-weaponizable | MED-1.1 | **CRIT-1.1** | confirmed | **VERIFIED LIVE** — `firestore.rules:1668-1680`. No `rateLimitWrite`, no `description.size()`, no `reason.size()`, no `contentType in [...]`, no `contentOwnerId != reporterId`. Compare to `deep_links/{linkId}/clicks` (line 1770-1779) which does use `rateLimitWrite('deep_link_click', 10)` — the pattern exists, reports just doesn't use it | **Severity dispute resolved in favor of deep.** Default's MED treatment underestimates the active weaponization surface (10 sock-puppets × 100 reports ≈ 1000 fake reports interleaved with real ones in moderator queue). Brigade detector + auto-suppression interaction makes the victim the de-facto suspended account. CRITICAL |
| C-2 | Image upload moderation: ZERO content scanning on `cook_snaps` / `shared/recipes/**` / `feedback/**` — NSFW/CSAM/copyright surface | NOT FOUND | NOT FOUND | **NEW CRIT (Pass 2)** | **VERIFIED LIVE** — full read of `storage.rules` (76 lines): only image-content-type + 10 MB cap. Grep `safeSearch\|nsfw\|imageModeration\|adultLikelihood` across entire repo: zero hits. No `onObjectFinalized` CF for moderation. `functions/src/__tests__/moderation-rules.test.ts` has 0 image tests | **Unique to deep Pass 2.** Apple Guideline 1.2 + Google Play UGC + reputational/legal hit on first NSFW/CSAM upload to public feed. Cook-snaps are public-feed UGC visible to all authenticated users including 13-year-olds. Sweden BBS-lagen (host liability) hardens the case |

**Consensus CRITICAL count: 2 (C-1 brigade-amplifier `reports` rule + C-2 image-moderation gap).**

---

## HIGH findings

### Two-way consensus (default + deep)

| # | Title | Default | Deep | Verification |
|---|---|:-:|:-:|---|
| H-1 | Onboarding wizard ships ZERO consent UI / ToS checkbox / privacy gate / community-guidelines acceptance | HIGH-3.1 (no initial consent prompt) | **HIGH-2.1 + HIGH-3.1** (re-confirmed) | **VERIFIED LIVE** — `lib/views/onboarding/` directory listing confirms 5 wizard pages + age-gate-blocked + host (no consent step). Grep `consent\|Consent` in dir: zero. ToS checkbox lives ONLY in `auth_view.dart` signup flow — bypass-able via email-verification-resume / federated auth / deep-link entry. Default treats this as one HIGH; deep treats it as two faces of the same gap (legal-link absence at 2.1, consent-prompt absence at 3.1) — same root cause. GDPR Art. 7(2) "clearly distinguishable" + Art. 13 transparency + Apple Guideline 5.1.1 |

### Default-unique findings (re-verified)

None at HIGH severity. Default's full HIGH bucket is just H-1.

### Deep-unique findings (verified for this synthesis)

| # | Title | Deep severity | Verification | Status |
|---|---|:-:|---|---|
| H-2 | `account_deletion_service` does NOT cascade `reports.contentOwnerId == userId` — Art. 17 incomplete erasure | HIGH-1.1 (Pass 1) | **VERIFIED LIVE** — `account_deletion_service.dart:182` deletes only reports the user FILED (`deleteUserReports`); reports filed AGAINST them stay. `_probeResidualData` (lines 286-291) does not include `reports` in its 3-collection probe set. Deleted user's UID remains embedded in others' report records | VERIFIED |
| H-3 | `_resolveContentRef` switch covers 5/6 content types (admin moderation silently no-ops on unhandled types) — Pass 2 reframed to **rule-side `contentType` enum gap** (silent black-hole on report create) | HIGH-1.2 (Pass 1, partial misread); **REFRAMED Pass 2 to NEW HIGH** | **VERIFIED LIVE** — `content_type.dart` enum has exactly 6 values; switch in `report_service.dart:218-256` is exhaustive over the live enum. Pass 1's "5 of 8" framing is wrong (knowledge-file overstated coverage by listing retired `'rating'` + `'shopping_list'`). The REAL bug is at the rule layer: `firestore.rules:1668-1680` accepts ANY string for `contentType`, and `ContentReport.fromFirestore` (lines 67-86) silently filters out retired/unknown wire names → **abuse reports filed with stale or malicious `contentType` strings disappear from moderation entirely.** Pass 2 corrects narrative; severity unchanged | VERIFIED with Pass 2 reframing |
| H-4 | `isHidden=true` on suspended profiles is read-side advisory only — hidden profiles remain fully readable by any authenticated client | NEW HIGH (Pass 2) | **VERIFIED LIVE** — `firestore.rules:454-500`. Read rule at line 456: `allow read: if isAuthenticated();`. No `resource.data.get('isHidden', false) == false` clause. Admin can SET `isHidden` (lines 496-499); owner cannot un-hide; but stale clients see hidden profiles. Apple "ability to suspend abusive content" has functional gap | VERIFIED |
| H-5 | Firebase App Check via reCAPTCHA V3 fires BEFORE consent (web) — device fingerprint + behavioural signals collected pre-consent | HIGH-3.2 (Pass 1) | **VERIFIED LIVE** — `lib/main.dart:180-182` `providerWeb: ReCaptchaV3Provider('6Ldv4zcsAAAAAlSR-dDTTuDTcjgr7pYvPazzGPDo')` runs in early `Future.wait` block; `_enableCollectionIfConsented` doesn't run until line 268. Sets `_GRECAPTCHA` cookie on web; collects device fingerprint per Google reCAPTCHA TOS. Site key in source binary. Defensible under Art. 6(1)(f) legitimate interest but undocumented (see M-3 below) | VERIFIED |

**Consensus HIGH count: 4** (H-1 onboarding consent gap, H-2 erasure cascade gap on reports.contentOwnerId, H-3 rule-side contentType enum / silent black-hole, H-4 isHidden read enforcement, H-5 reCAPTCHA pre-consent fingerprint).

> Note: I'm listing 5 H-rows above because deep's Pass-2 totals also list 4 HIGHs but Pass-1 H-1.1/H-1.2 share a thread. Counting H-2 and H-3 as one "moderation correctness" HIGH gives 4. For the master doc I recommend listing H-1, H-2+H-3 (folded as "moderation pipeline correctness — erasure cascade + rule-side enum"), H-4, H-5.

---

## MEDIUM findings (consensus matrix)

| # | Title | Default | Deep | Verification | Notes |
|---|---|:-:|:-:|---|---|
| M-1 | Privacy Policy not linked from Settings hub About section | MED-2.1 | MED-2.1 | Confirmed (both cite `settings_hub_view.dart:65-95`) | 2-way agreement, 15-min fix |
| M-2 | Community Guidelines buried (Settings → Account Security → Community Guidelines, 2 levels deep) + not in auth view footer | MED-2.2 | MED-2.2 | Confirmed via `account_security_view.dart:371` | 2-way agreement |
| M-3 | reCAPTCHA Enterprise NOT in privacy policy subprocessor list (Art. 13 + Art. 30 disclosure gap) | NOT FOUND | **NEW MEDIUM (Pass 2)** | **VERIFIED LIVE** — grep `reCAPTCHA\|recaptcha\|App Check\|appcheck` in `privacy_policy_{en,sv}.md`: zero hits. Subprocessor list at `privacy_policy_en.md:106-169` covers Vertex AI / OCR.space / Algolia (with DPA links — Pass 2 noted Pass 1 missed this) but NOT reCAPTCHA. Privacy policy line 169 affirmatively states "We do not engage any other data processors" — **factually false while reCAPTCHA active.** | Unique to deep Pass 2; verified |
| M-4 | FCM payload sanitization: title/body length-checked but NOT scrubbed for PII (`scrubPii` exists, wired only for LLM input) | NOT FOUND | **NEW MEDIUM (Pass 2)** | Deep cites `functions/src/notifications/send-notification.ts:443-456` and `functions/src/llm/pii-scrubber.ts:89-97`. Lock-screen previews + APNs US-routing leak comment-body PII | Unique to deep Pass 2 |
| M-5 | Vertex AI prompts to europe-west1 scrub email/phone/personnummer but NOT displayNames / userIds / friend names — fragile invariant for future AI prompts | NOT FOUND | NEW MEDIUM (Pass 2) | Deep cites `pii-scrubber.ts:50-95` (no identity scrubbing) and privacy-policy line 165 declares only "Recipe images and extracted text" | Unique to deep Pass 2 |
| M-6 | Profanity filter has `'blansen'` (likely typo / non-Swedish word) on blocklist; missing real Swedish ethnic slurs (`blatte`, `svartskalle`, `apajävel`) | NOT FOUND | MED-1.2 (Pass 1) | Deep cites `lib/services/moderation/content_filter_service.dart:106` | Unique to deep |
| M-7 | Block enforcement is write-side only; reads are open (blocked users can still query `public_profiles`, `recipe_comments`, `recipe_ratings` of blocker) | LOW-1.1 | MED-1.1 | Deep elevated to MED on Apple "block abusive users" trust-promise grounds | Severity dispute; deep more conservative |
| M-8 | `app_opened` analytics event fires from `_AuthWrapperState.initState()` before consent listener may be wired (fail-closed gate works but undocumented) | LOW-3.1 | MED-3.1 | Deep elevated to MED (canary for future analytics-call pre-bootstrap) | Severity dispute; both note it's safe-by-design |
| M-9 | Crashlytics `setEnabled(false)` + Analytics `setEnabled(false)` initialization not in same `Future.wait` block — partial-init can leave Analytics enabled across launches if Crashlytics throws | NOT FOUND | MED-3.2 | Deep cites `lib/repositories/firebase/firebase_analytics_repository.dart:79-94` and `main.dart:210-224` | Unique to deep |
| M-10 | `consent_broadcast_web.dart` BroadcastChannel cross-tab race — tab B receives revoke but in-flight `app_opened` may have already passed gate | NOT FOUND | MED-3.3 | Deep cites `lib/services/account/consent_broadcast.dart:8-9`, `consent_service.dart:64-66, 228-241` | Unique to deep |
| M-11 | reCAPTCHA Enterprise V3 (web) sends device fingerprint to Google before consent + no documented region routing | NOT FOUND | MED-6.1 | Same evidence as H-5 + M-3 — Art. 44 transfer documentation gap | Unique to deep |
| M-12 | OCR.space data flow undocumented (data residency unverified; cross-ref 02 HIGH-1) | LOW-6.1 | MED-6.2 | Deep elevated due to UGC content (recipe images, possibly with handwriting/family-photo context) | Severity dispute; cross-prompt boundary with 02 |
| M-13 | Age-gate self-attestation only (no parental consent flow) | MED-7.1 | MED-7.1 | 2-way agreement; both note this is industry standard | Acceptable but worth flagging |
| M-14 | Social features unrestricted for 13-year-olds (App Store rating implication: 12+/17+ minimum given UGC + chat) | MED-7.2 | MED-7.2 | 2-way agreement; cross-ref to 06 UX for app-store rating questionnaire | |
| M-15 | Age-gate code-comment claims "15-year Swedish threshold enforced by `isAgeGatePassed`" but rule + dropdown enforce 13 | NOT FOUND | MED-7.3 | **VERIFIED LIVE** — deep cites `onboarding_age_gate_page.dart:19-21`. Comment-vs-code drift | Unique to deep |
| M-16 | No COPPA equivalent / Swedish IMY (LVU/dataskydd-för-barn) section in privacy policy | NOT FOUND | NEW MEDIUM (Pass 2) | Deep cites `privacy_policy_en.md:1-80` (no children's section) + grep `COPPA\|LVU\|barnskydd` zero hits | Unique to deep Pass 2 |
| M-17 | New-account rate-limit grace period absent (sock-puppet attack window) | MED-8.1 | MED-8.1 | 2-way agreement | |

**Consensus MEDIUM count: 14-17** (default 4, deep Pass 2 13+; deep is roughly 4× default's coverage at MEDIUM tier).

---

## LOW / Informational findings (one-line each)

- **Default LOW-2.1 / Deep LOW-2.1** — `appeals@butlery.app` is the only abuse contact (conflated with appeals). 2-way agreement.
- **Default LOW-2.2 / Deep LOW-2.2** — No structured appeal flow (mailto only). 2-way agreement; out of scope pre-launch.
- **Default LOW-3.2 / Deep LOW-3.1** — Algolia consent gate timing not verified at this layer; 2-way agreement.
- **Deep LOW-1.1** — Moderator dashboard query has no time filter / no `.limit()` (`report_service.dart:105-115`); unbounded snapshot stream. Unique to deep.
- **Deep LOW-1.2** — Same `feedback` rate-limit + size-cap gap as reports (already 02 MEDIUM-7); cross-ref.
- **Deep LOW-2.1 + LOW-2.2** — Same as default's LOW-2.1/2.2 (abuse-contact + appeal flow).
- **Deep LOW-4.1** — `PrivacyInfo.xcprivacy` does not declare collection by OCR.space or Google Vision (App Store Connect "Data Collected by Third Parties" form). Bundled into 02 HIGH-1.
- **Default LOW-7.1 / Deep LOW-7.1** — No "report a child" pathway / `under_minimum_age` reason category.
- **Deep LOW-7.2** — German under-16 users (Swedish 13 floor too low for some EU member states); post-launch geo-aware age gate.
- **Default LOW-8.1 / Deep LOW-8.1** — No duplicate-content detection. Acceptable as-is pre-launch.
- **Deep NEW LOW (Pass 2)** — UGC scanning of recipe titles for medical claims / brand abuse / trademark (Marabou, IKEA, Livsmedelsverket health claims). Unique to deep.
- **Deep NEW LOW (Pass 2)** — Feedback screenshots can be arbitrary 10 MB images including PII. Beta-feedback FAB should crop client-side.
- **Deep Informational** — `Tracking=false` declaration in `PrivacyInfo.xcprivacy:139` depends on consent gate; if Firebase→Google Ads link ever activated, manifest line becomes false. Document invariant in BUT-603 entry.
- **Deep Informational (Pass 2 correction)** — Subprocessor list IS maintained in `privacy_policy_{en,sv}.md` with DPA links per processor (Vertex AI, OCR.space, Algolia). Pass 1 implied this was a question mark; correction logged. (Default also did not catch this.)
- **Deep Informational** — APNs implicitly US-routed for iOS push (`functions/src/shared/notification-payload.ts`); knowledge BUT-641. Add to processor inventory.

---

## Disputed numbers (resolved against live source)

| Item | Default | Deep | Live | Resolution |
|---|---|---|---|---|
| `ConsentPurpose` enum value count | implicit "4-7 toggleable purposes" | "7 purposes" (Pass 1 invariant #8) | **7** (`essentialServices, dataProcessing, analytics, marketing, socialFeatures, pushNotifications, aiProcessing`) | Deep correct |
| `ContentType` enum value count | implicit (cited 6 in switch matrix) | Pass 1 said "5 of 8 contentType values" (off — knowledge file overstated coverage by listing 2 retired wire names); Pass 2 corrected to **6** | **6** (`recipe, comment, message, profile, cookSnap, group`); retired `rating`/`shopping_list` are NOT enum members, only legacy wire strings filtered out by `fromWire` | Deep Pass 2 correct; Pass 1 misread |
| `account_deletion_service` cascade tier counts | not enumerated | Pass 1 invariant #6 names ~16 UID-bearing collections; cascade map "tier1 line 163-195" | **Tier 1 has 25 entries, Tier 2 has 2 entries, Tier 3 has 1 entry** (`account_deletion_service.dart:164-208`); 28 cascade ops total. `_probeResidualData` covers 3 of these | Live count higher than either run cited; deep's "tier1 map (line 163-195)" is approximately the right region but the line-range now spans 164-196 |
| `reports` rule line range | `firestore.rules:1595-1601` (default), `1596-1599` (deep Pass 1), `1587-1599` (deep Pass 2 critic) | Live: **1668-1680** | Substance unchanged; both cited slightly outdated line numbers (file has shifted ~70 lines) |
| Firebase App Check / reCAPTCHA activation line | `main.dart:213-223` | `main.dart:213-223` (deep Pass 1+2) | Live: **`main.dart:179-182`** for the activate call; `_enableCollectionIfConsented` at **268-278** | Both citations stale; substance (App Check fires before consent) confirmed |
| Audit-log retention windows (cross-prompt 02 ownership) | not in 09 | "model 365d / service 180d / CF 730d-180d" (orchestrator ground truth from Wave 1 prompt 02 MED-1) | Confirmed; not owned by 09 | Cross-reference only |
| Default's "ContentReport `description` size cap" claim — does the field even exist? | implies it does | Pass 2 narrative implies it does | **NOT VERIFIED in this synthesis;** the rule's required-fields list at `firestore.rules:1680` is `['reporterId, contentType, contentId, reason, status, createdAt']` — `description` is NOT in the required-fields enum. Both runs treat `description` as an optional field that can be arbitrary-length. Plausible but unverified. | Both runs assume this; live re-verification of `ContentReport` model not done in this pass. Flag for future audit |

---

## Disproved by deep critic (default findings the deep run motbevisade)

1. **Default Executive-Summary point 1: "the user is asked to accept ToS+Privacy via checkbox but the granular consent purposes are never presented at all."**
   - Deep refuted: the ToS checkbox is in `auth_view.dart` (signup-only) — a user arriving via deep link, social-recovery, or the email-verification re-entry path can complete onboarding **without ever seeing the ToS signup checkbox either**. Default's framing softens the problem; deep correctly classifies it as TWO gaps (HIGH-2.1 + HIGH-3.1).

2. **Default's HIGH-3.1 "no initial consent prompt" framing** — accurate but **incomplete**. Deep adds the structural insight that App Check / reCAPTCHA fires BEFORE consent (HIGH-3.2 Pass 1), so the consent gate itself is moot for the device-fingerprint side-channel. Default missed the entire reCAPTCHA pre-consent fingerprint surface.

3. **Default's MEDIUM-1.1 "reports rule rate limit + size cap"** — deep elevated to CRITICAL after applying threat-modeling for moderator-queue weaponization (10 sock-puppets × 100 reports/account at SDK throughput → 1000 fake reports interleaved with real ones; brigade detector + auto-suppression interaction makes the victim suspended). Default underrated severity.

4. **Default's HIGH-1.2 framing of admin moderation coverage** — Pass 1 deep made the same misread (saying knowledge file lists 8 contentTypes, code only handles 5/6). Pass 2 deep corrected: enum has exactly 6 values; switch is exhaustive over the live enum; the **real** gap is at the rule layer (no `contentType in [...]` enum check → silent black-hole on report create when client submits stale/malicious wire names). Default did not catch the rule-layer gap at all.

5. **Default's "App Store Compliance Dashboard" row "Privacy nutrition labels: Aligned"** — deep adds OCR.space + Google Vision are NOT declared on the App Store Connect "Data Collected by Third Parties" form (LOW-4.1, bundled into 02 HIGH-1). Default rated this as "Aligned" without checking the third-party declaration.

6. **Default rated `Dimension 4: iOS Privacy Manifest` 12/12** — deep dropped to 11/12 on the OCR.space+Vision data-recipient declaration plus the `Tracking=false` informational caveat (manifest line is conditional on consent gate; if Firebase→Google Ads link is ever toggled, declaration becomes false). Default did not consider the conditional invariant.

7. **Default rated `Dimension 6: Data Transfer Compliance` 9/10** — deep dropped to 8/10 (Pass 1) → **6/10 (Pass 2)** after adding reCAPTCHA absent from subprocessor list (M-3) and FCM-PII-not-scrubbed (M-4). Default missed both.

8. **Default's LOW-3.1 "`app_opened` race"** — characterized as "benign by design but undocumented" with severity LOW. Deep elevated to MED-3.1 because it's a canary for any future analytics-call added to a `runApp`-time path; absent a pinning test, a future contributor breaks it silently.

---

## Cross-prompt boundaries (per orchestrator dedup rules)

- **GDPR consent SERVICE implementation drift / `ConsentPurpose` analyzer error** → **02 owns** (Wave 1 HIGH-2 in 02). Already resolved on disk. Not a 09 finding.
- **Audit-log retention triple-drift (model 365d / service 180d / CF 730d-180d)** → **02 owns** (Wave 1 prompt 02 MEDIUM-1). Cross-reference only.
- **GDPR Art-15 export broken** → **02 owns** (Wave 1 CRIT-SEC2). Cross-reference only — feeds into the privacy-policy claim that "self-service export" is functional, but ownership stays in 02.
- **`friend_requests` collection bug** → **02 owns** (Wave 1 HIGH-SEC2). Cross-reference only.
- **Audit-log retention vs legal claims (privacy-policy stated retention windows match implementation?)** → **11 Legal owns** per deep run cross-prompt section.
- **Pings broadcast read-side gap** → **02 owns** (Wave 1 prompt 02 MEDIUM-6). Default cited; deep cited; ownership stays in 02.
- **App store metadata + screenshots + nutrition-label submission form** → **06 UX owns**.
- **OCR.space API key extraction (in client binary)** → **02 HIGH-1 owns**. 09 references the data-flow / DPA-documentation angle (M-12) but the migration to a server-side proxy is in 02's remediation.
- **Image moderation CRITICAL (C-2)** likely overlaps with **02 (Cloud Function trust boundary)** and **03 (storage bucket lifecycle)**. Recommend orchestrator de-dup at synthesis. Primary ownership stays in 09.
- **Subprocessor / reCAPTCHA gap (M-3)** overlaps with **11 Legal** (privacy-policy completeness). Primary ownership in 09 (the SDK choice + activation timing) + 11 (the policy text).

---

## Counts summary

| Severity | Default | Deep P1 | Deep P2 (final) | Consensus |
|---|---:|---:|---:|---:|
| CRITICAL | 0 | 1 | **2** | **2** |
| HIGH | 1 | 2 (counted as 4 sub-findings) | **4** | **4** |
| MEDIUM | 4 | 7 | **10** | 14-17 (de-duped) |
| LOW | 5 | 8 | 8 | ~13 (de-duped) |
| Informational | 3 | 4 | 5 | 5 |
| **Score** | **80/100** | **71/100** | **60/100** | **60/100** |

---

## Ship-blockers (must fix before public launch)

Per Pass 2 verdict + live re-verification:

1. **C-2 image moderation CF** (CRITICAL — Apple Guideline 1.2 + CSAM hosting risk). 8 h.
2. **C-1 `reports` rule hardening** including `contentType in [...]` enum (bundles CRITICAL + HIGH H-3). Hand to `firestore-rules-tester`. 1-2 h rule + 6 h brigade detector.
3. **H-1 onboarding consent + ToS + privacy + community-guidelines page** (HIGH). 8 h.
4. **H-2 erasure cascade fix on `reports.contentOwnerId`** + extend `_probeResidualData`. 3 h.
5. **H-4 `isHidden` rule-side read enforcement** on `public_profiles/{userId}`. 1 h rule + 2 h regression.
6. **M-3 reCAPTCHA in privacy policy subprocessor list** (legal hygiene; "We do not engage any other data processors" line is affirmatively false until fixed). 30 min.

Estimated ship-blocker total: ~25-30 h.

---

End of MASTER Wave 3 — Prompt 09 data file.
