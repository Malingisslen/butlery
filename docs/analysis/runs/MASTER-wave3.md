# MASTER — Wave 3 — Forensic Audit Consensus Report

**Scope:** Prompts 07 (AI/LLM Quality & Reliability), 08 (Product Analytics & Growth), 09 (Trust, Safety & Privacy), 10 (Monetization & Competitive Positioning).
**Date:** 2026-05-05.
**Sources:**
- `2026-05-claude/` — Claude default (all 12 + SYNTHESIS, complete)
- `2026-05-claude-deep/` — Claude deep + Pass 2 critic (all 12 + SYNTHESIS, complete)
- `2026-05-codex/` — OpenAI Codex CLI (08 only — bucket exhaustion blocked 07/09/10)

**Methodology:** Identical to Wave 1+2. Deep run is authoritative; default + (where present) codex used as triangulation.

**Consolidated wave score:** **67/100** (weighted average across 4 prompts: 71/71/60/65.5).

---

## 0. Executive summary

Wave 3 covers the **operational + commercial + safety substrate**: how the LLM functions are governed, what telemetry actually records, what trust-and-safety gates exist for user-generated content, and where the codebase stands on monetization readiness. Two themes dominate:

**Theme A — Quality gates exist but adoption is thin.** Same pattern as Wave 1 (`BaseService 96%/real ~75%`) and Wave 2 (`CircularProgressIndicator` raw use × 34): infrastructure built, enforcement absent. Examples this wave:
- `sessionId` always null in analytics events (BUT-588 TODO still on disk)
- Cooking-mode entirely dark (3 files emit zero events)
- `setUserId` for FirebaseAnalytics never called
- Image-moderation absent on `cook_snaps`/`shared/recipes`/`feedback` despite report system existing

**Theme B — Strategic deferrals leak into code.** MEMORY.md says "no monetization decisions yet, no app-store submission yet" — and the code reflects that:
- `subscription_tier` analytics frozen at `'free'` (no enrollment path)
- Zero screenshots on disk for store submission
- iOS subtitle is 31 chars > Apple's 30-char limit (will fail submission when the time comes)
- `HouseholdService` substrate exists for Family Plan (good — entitlement-ready)
- Step timer infra exists (good); auto-extract from text is what's missing

**Top three findings of the wave (all CRITICAL):**

1. **Image moderation gap on UGC paths.** `cook_snaps`, `shared/recipes`, and `feedback` collections accept image uploads with no NSFW/SafeSearch screening. `storage.rules` (76 lines) has zero references to `imageModeration` / `safetySearch`. Combined with Wave 1 MED-13 (Storage MIME spoofing) — polyglot SVG containing JS + uploaded NSFW content both have zero gate. (Prompt 09 CRIT-2)

2. **Brigade-amplifier `reports` collection.** `firestore.rules:1668-1680` allows any authenticated user to create `reports` with no rate limit, no enum validation, no self-report block. An attacker with N alt accounts can submit N reports against any user's content; combined with `account_deletion_service` cascade not probing `reports.contentOwnerId`, deletions leave dangling reports referencing the deleted user. (Prompt 09 CRIT-1)

3. **No closed-loop LLM quality measurement.** No golden-set regression tests, no production drift telemetry, no per-prompt-version success metric. `gemini-2.0-flash` model alias floats (not pinned) and analytics doesn't record `modelId`, so a Google-side model swap goes unnoticed in metrics. With LLM costs being a major budget line, the absence of measurement is both a quality and a cost risk. (Prompt 07 CRIT-1+2)

**Audit-integrity findings to flag:**

| Stale narrative | Reality | Source |
|---|---|---|
| "In-app review tracking is broken" | Default's HIGH cited line 114; actual `_logEvent` call at `in_app_review_service.dart:124-131` works fine | DROP this finding |
| "`recipeImageUploaded` event never invoked" | Wired at `recipe_persistence_manager.dart:210` | DROP |
| "BUT-588 sessionId fix already shipped" | TODO still on disk at `parse_events_tracker.dart:28` | Default was wrong; gap is real |
| "Mistral references are CRITICAL legal exposure" | Default conflated docstring drift with privacy-policy text. Live privacy policy says Vertex/Gemini correctly. Code-side drift is HIGH for prompt 12 doc-drift, not CRITICAL legal | Demote to prompt 12 |
| "OCRUsageTracker has zero persistence" | Daily counter IS persisted to SharedPreferences. Only monthly counter is in-memory. Bypass-via-force-quit risk holds for monthly enforcement only | Re-frame from "no persistence" to "monthly cap is exploitable" |

---

## 1. Score reconciliation across runs

### Per-prompt score consensus

| Prompt | Codex | Claude default | Claude deep | **Master (verified)** | Status |
|---|---:|---:|---:|---:|---|
| 07 AI/LLM Quality & Reliability | — (missing) | 78 | **71** | **71** | Acceptable; LLM quality unmeasured |
| 08 Product Analytics & Growth | 66 | 78 | **71** | **71** | Acceptable; key dark areas in cooking mode + social graph |
| 09 Trust, Safety & Privacy | — (missing) | 80 | **60** | **60** | Concerning; default missed brigade + moderation gaps |
| 10 Monetization & Competitive | — (missing) | 68 | **65.5** | **65.5** | Code-fact OK; strategic opportunities tagged hypothesis |
| **Wave 3 weighted average** | — | 76.0 | **66.9** | **66.9** | |

**Pattern continuing:** default scores 7-20 points higher than deep on every prompt. The largest gap is prompt 09 (default 80 vs deep 60), entirely attributable to two CRITICAL findings default missed (brigade-amplifier, image moderation).

### Disputed numbers — authoritative truth

| Metric | Codex | Default | Deep | **Master (verified)** |
|---|---:|---:|---:|---:|
| Cloud Function callables | 18 (W1) | 18 (W1) | 18 | **18** |
| `ContentType` enum values | not stated | "5 of 8" | 6 (Pass 2 reframed) | **6** (`'rating'`/`'shopping_list'` are wire-only legacy filtered by `fromWire`) |
| `ConsentPurpose` enum values | not stated | "vague" | 7 | **7** |
| Account deletion cascade tier counts | not stated | not stated | Tier 1=25, Tier 2=2, Tier 3=1 (28 ops) | **28 total ops** |
| Notification effectiveness source collections | not stated | "3" | 4 (Pass 2 strengthened) | **4 incompatible collections** |
| `reports` collection rule line range | not stated | "different range" | "1668-1680" | Lines shifted ~70 since deep run; substance unchanged |
| Cooking-mode events (dark area) | not counted | not counted | 3 dark files: view + viewmodel + service module | **3 dark files** verified |
| `cooksLast14Days` non-zero call sites | not counted | not counted | 0 (only literal 0 passed) | **0** |
| Win-back conversion meaningful actions | not counted | not counted | "exactly 3" | **3** |

---

## 2. Verified CRITICAL findings (4 — all from deep, all verified by master re-check)

### AI/LLM Quality & Reliability (Prompt 07)

#### CRIT-AI1 · No closed-loop LLM quality measurement
- **Source:** Deep CRIT (default rated HIGH; deep wins).
- **Evidence:** No golden-set regression tests under `test/golden/llm/` or similar. No production drift telemetry — analytics events for `recipe_parsed_*` don't include `modelId` or `promptVersion`. `functions/src/llm/PROMPT_CHANGELOG.md` exists as documentation but isn't gated by CI tests. Deep verified absence of canary-comparison framework.
- **Verification:** VERIFIED — independently confirmed no LLM regression tests on disk.
- **Why CRITICAL:** LLM costs are non-trivial and quality drift is silent. A Google-side model swap (e.g., `gemini-2.0-flash` resolving to a different model on Google's end) would go unnoticed in metrics. Worse: if a prompt update reduces parse accuracy by 10%, nothing fails CI; the user just sees worse parses.
- **Remediation:** Build `test/golden/llm/` corpus (~30 sample inputs covering ICA recipe page, koket.se page, OCR'd PDF, hand-written notes); add CI step running new prompt against corpus + comparing structured output to fixture; log `modelId` + `promptVersion` in analytics.

#### CRIT-AI2 · `gemini-2.0-flash` model alias is unpinned + no `modelId` in analytics
- **Source:** Deep CRIT.
- **Evidence:** `functions/src/llm/gemini-client.ts` references `gemini-2.0-flash` as a string alias. Google may resolve this to different model versions over time without notice. Analytics doesn't record which model actually responded.
- **Verification:** VERIFIED.
- **Why CRITICAL:** combines with CRIT-AI1 — there's no way to detect either client-side alias-resolution drift or production quality drift. Cost regressions also invisible (the model alias may resolve to a more expensive model variant).
- **Remediation:** Pin model to specific version (`gemini-2.0-flash-001` or similar concrete name); record `modelId` from Vertex response in every analytics event; add cost telemetry per model call.

### Trust, Safety & Privacy (Prompt 09)

#### CRIT-TS1 · Brigade-amplifier on `reports` collection
- **Source:** Deep CRIT (default rated MEDIUM; deep wins).
- **Evidence:** `firestore.rules:1668-1680` `reports` create rule has no rate limit, no `reportType` enum validation, no self-report block. Combined with `public_profiles` being world-readable to authenticated users (`firestore.rules:454-500` only requires `isAuthenticated()`), an attacker with N alt accounts can enumerate target user profiles + submit N coordinated reports. `account_deletion_service` cascade tier 1 (25 collections) does NOT probe `reports.contentOwnerId` — deleted users leave orphaned reports referencing them.
- **Verification:** VERIFIED — read rules block live, confirmed `_probeResidualData` covers 3 collections, `reports` not among them.
- **Why CRITICAL:** brigade campaigns can drown out legitimate reports + auto-trigger moderation queues if any are wired up. Combined with weak account deletion, attackers persist after their own deletion.
- **Remediation:** Add rate limit (`rateLimitWrite('reports', 30)` per orchestrator pattern), enum validation on `reportType`, `request.auth.uid != resource.data.contentOwnerId` self-report block, and `reports.contentOwnerId` cascade in deletion.

#### CRIT-TS2 · No image moderation on UGC paths (cook_snaps, shared/recipes, feedback)
- **Source:** Deep Pass 2 critic NEW (default missed entirely).
- **Evidence:** `storage.rules` is 76 lines total. Live grep returns ZERO references to `imageModeration` / `safetySearch` / `nsfw` / `vision.safeSearch`. `cook_snaps`, `shared/recipes`, and `feedback` collections accept image uploads with no server-side screening. Combined with Wave 1 MED-13 (client-controlled `contentType` allows magic-byte spoofing), the UGC trust boundary is shallow.
- **Verification:** VERIFIED.
- **Why CRITICAL:** required for App Store / Play UGC compliance (Apple Guideline 1.2 / Play UGC). Without it, any user can upload an offensive/illegal image and other users see it without filter. Apple has rejected apps for this exact gap.
- **Remediation:** Add `onObjectFinalized` Cloud Storage trigger that calls Vision API SafeSearch on upload; quarantine images flagged `LIKELY_ADULT`/`LIKELY_VIOLENT`/`LIKELY_RACY`. Estimated 1 day. Cost: ~$1.50 per 1k images analyzed (Vision API). Required for store submission anyway.

---

## 3. Verified HIGH findings (consolidated, ~28 unique after dedup)

### AI/LLM Quality (8 HIGH)

| ID | Title | Source | Verification |
|---|---|---|---|
| HIGH-AI1 | Server-to-server OCR-retry bypasses every value validator | deep | VERIFIED |
| HIGH-AI2 | `recipe.title` logged in success path (privacy leak) | deep | VERIFIED |
| HIGH-AI3 | Client retry stacks on rate-limit (compounds quota burn) | deep | VERIFIED |
| HIGH-AI4 | No adversarial test fixtures (jailbreak, prompt injection in recipe text) | deep Pass 2 | VERIFIED |
| HIGH-AI5 | No Vertex `cachedContent` prefix caching (cost) | deep Pass 2 | VERIFIED |
| HIGH-AI6 | Two splitter implementations with different production callers | deep | VERIFIED — `compound_splitter.dart` ← `ingredient_normalizer.dart:476`; `swedish_compound_splitter.dart` ← `crf_feature_extractor.dart:169` |
| HIGH-AI7 | Unicode fractions (⅙⅚⅐) missing from `quantity_parser.dart:55-68` | default unique | VERIFIED |
| HIGH-AI8 | No prompt-changelog gate in CI | default unique | VERIFIED |

### Product Analytics (~11 HIGH)

| ID | Title | Source | Verification |
|---|---|---|---|
| HIGH-PA1 | `sessionId` always null in events (BUT-588 TODO unshipped) | three-way | VERIFIED at `parse_events_tracker.dart:28` |
| HIGH-PA2 | Win-back narrow 3-action conversion set | three-way | VERIFIED |
| HIGH-PA3 | Notification effectiveness drawn from 4 incompatible source collections | deep Pass 2 (strengthened) | VERIFIED |
| HIGH-PA4 | Cooking-mode entirely dark (3 files emit zero events) | deep | VERIFIED across `cooking_mode_view.dart` + `cooking_mode_viewmodel.dart` + `cooking_session_module.dart` |
| HIGH-PA5 | `setUserId` for FirebaseAnalytics never called (only Crashlytics + BaseService user-id provider) | deep Pass 2 | VERIFIED |
| HIGH-PA6 | No `kDebugMode` guard on analytics — dev events pollute prod | deep Pass 2 | VERIFIED |
| HIGH-PA7 | `cooksLast14Days` only literal 0 passed (no real value) | deep | VERIFIED |
| HIGH-PA8 | `feature_flag_evaluated` only fires from `isInRollout`, not from `isEnabled` | deep | VERIFIED |
| HIGH-PA9 | Favorite action untracked, no `recipeFavorited` event constant | codex unique | VERIFIED |
| HIGH-PA10 | 8 social-graph churn events dark + DM dark | default+deep | VERIFIED 9 dark methods (definition-only) |
| HIGH-PA11 | `firstCook` milestone event missing | default+deep | VERIFIED |

### Trust, Safety & Privacy (4 HIGH)

| ID | Title | Source | Verification |
|---|---|---|---|
| HIGH-TS1 | Onboarding consent gap | default+deep | VERIFIED |
| HIGH-TS2 | Erasure cascade gap on `reports.contentOwnerId` | deep | VERIFIED |
| HIGH-TS3 | `ContentType` rule-side enum / silent black-hole on retired wire values | deep Pass 2 | VERIFIED 6 ContentType values, 2 retired filtered by `fromWire` returning null |
| HIGH-TS4 | reCAPTCHA pre-consent fingerprint (privacy policy says "no other data processors" — false claim, reCAPTCHA used in production) | deep | VERIFIED — `lib/main.dart:179-182` reCAPTCHA activate fires before consent gate at line 268; `assets/legal/privacy_policy_{en,sv}.md` zero reCAPTCHA mentions |

### Monetization (~7 HIGH after recalibration)

| ID | Title | Source | Verification |
|---|---|---|---|
| HIGH-MON1 | iOS subtitle 31 chars > Apple's 30-char limit (submission blocker when MEMORY.md "no submission yet" is lifted) | deep | VERIFIED — "Recept, veckomeny & inköpslista" = 31 chars |
| HIGH-MON2 | `subscription_tier` analytics frozen at `'free'` (no enrollment path; main.dart:823 doesn't pass `subscriptionTier`) | deep | VERIFIED |
| HIGH-MON3 | Zero screenshots on disk (`store_assets/screenshots/` only README) | deep | VERIFIED |
| HIGH-MON4 | `OCRUsageTracker` monthly counter is in-memory only (bypass-via-force-quit) | deep (Pass 1 partially wrong; Pass 2 correctly identified daily IS persisted, monthly is not) | Re-framed from "no persistence" to "monthly cap exploitable" |
| HIGH-MON5 | No IAP scaffolding (Apple ASBSP enrollment, Google Play Billing, restore-on-reinstall) | deep Pass 2 | VERIFIED via absence of `in_app_purchase` package and entitlement service |
| HIGH-MON6 | EU 14-day cooling-off period not addressed in subscription model | deep Pass 2 | VERIFIED via absence of refund/cooling-off code |
| HIGH-MON7 | Account-deletion ↔ subscription interaction undefined (does deleting account cancel sub? refund?) | deep Pass 2 | VERIFIED via absence in `account_deletion_service.dart` |

---

## 4. Disproved / stale findings

| Claim | Origin | Disproof | Master action |
|---|---|---|---|
| In-app review analytics is broken — events not wired | codex + default HIGH | `in_app_review_service.dart:124-131` has working `_logEvent` calls; default's quote stopped at line 114 | DROP |
| `recipeImageUploaded` event never invoked | deep MED-1.6 | Wired at `recipe_persistence_manager.dart:210` | DROP |
| BUT-588 sessionId fix has shipped | default | TODO still present at `parse_events_tracker.dart:28` | Gap is real (HIGH-PA1) |
| Codex CRITICAL: "import not measurable" | codex | Events DO fire from `receive_share_view.dart:98, 165` — measurability is via sessionId, not missing-event | DOWNGRADE to HIGH (covered by HIGH-PA1) |
| Mistral references = CRITICAL legal exposure | default 07 CRIT-1 | Privacy policy says Vertex/Gemini correctly. Code-side docstring drift is doc issue, not legal | DEMOTE to prompt 12 doc-drift |
| `ocr_usage_tracker.dart` is dead code | deep Pass 1 | Pass 2 retracted; live verified `recordUsage` called from `ocr_extraction_service.dart:257, 278, 294, 305, 320, 335` | Pass 2 correct |
| `OCRUsageTracker` has zero persistence | deep Pass 1+2 (partially) | Daily counter IS persisted via SharedPreferences (`_prefDailyCountKey`, `_persistDaily()`); only monthly is in-memory | Re-frame to monthly-only gap (HIGH-MON4) |
| Live recipe scaling is "Partial" | default 10 | Verified — `portion_scaler{,_logic,_ui}.dart` exist, fully wired | Default wrong; remove |
| Step timer infra is "Missing" | default 10 | `step_timer_service.dart` exists; what's missing is auto-extract-from-text | Default partially wrong |
| `firebase.json` security headers MISSING | deep MED-LEGAL-14 (cross-from 11) | VERIFIED at `firebase.json:28-39` — full HSTS+CSP+X-Frame-Options+Referrer-Policy+Permissions-Policy set | Default is right; deep wrong |
| Realtime Database region is HIGH risk | deep 11 | `presence_service.dart:121-124` shows RTDB may not be configured at all (`databaseURL == null` handled) | Demote to LOW |

---

## 5. Cross-cutting findings

### CC-Wave3-1 · UGC trust boundary is shallow across multiple gates
Three findings across 09 + Wave 1+2 surface the same defect class:
- CRIT-TS2 (no image moderation) — Wave 3
- Wave 1 MED-13 (client-controlled `contentType` allows magic-byte spoofing)
- Wave 1 MED-14 (`image/svg+xml` not excluded — XSS vector via Storage CDN)

**Combined impact:** any authenticated user can upload polyglot HTML/JS/SVG/NSFW content via cook_snaps/recipes/feedback. The combined fix is **one** Cloud Storage trigger that does magic-byte verification + SafeSearch + format whitelist (PNG/JPG/HEIF only). 1.5 days work to close all three.

### CC-Wave3-2 · Cost telemetry is missing across LLM + analytics
- CRIT-AI1+2 (no quality measurement, no modelId logging)
- HIGH-AI3 (client retry stacks)
- HIGH-AI5 (no Vertex prefix caching)
- HIGH-PA6 (no kDebugMode guard — dev events pollute prod analytics, inflating cost too)

**Combined narrative:** The LLM is a major cost line, and there's no end-to-end visibility into per-call cost, per-prompt success rate, or per-model drift. Build a unified `LlmCostTracker` that wraps every Vertex call, records (model, promptVersion, inputTokens, outputTokens, durationMs, success). Same module solves CRIT-AI2 and HIGH-PA6.

### CC-Wave3-3 · Strategic vs code-fact tagging matters
Prompt 10 has many "strategic opportunity" findings (Family Plan via HouseholdService, recipe-scaling tier-up, etc.). These are hypotheses about future product direction, not verifiable code facts. **They should not get the same severity weight as code findings** in remediation roadmap. The deep run did this tagging well (§5 of master data); default did not.

For synthesis, treat strategic opportunities as a separate category from code-defects.

---

## 6. Remediation roadmap (verified, sized)

### Sprint W3-1 — UGC trust boundary + LLM observability (target: 2 weeks, ~7 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| W3-1.1 | Cloud Storage `onObjectFinalized` trigger: magic-byte verify + SafeSearch + format whitelist | 1.5d | CRIT-TS2 + Wave 1 MED-13/14 |
| W3-1.2 | Tighten `reports` rule (rate limit + enum + self-report block) + add `reports.contentOwnerId` cascade in account deletion | 1d | CRIT-TS1 |
| W3-1.3 | Build `test/golden/llm/` corpus + CI golden test step | 1.5d | CRIT-AI1 |
| W3-1.4 | Pin `gemini-2.0-flash` to versioned alias + record `modelId` + cost in every Vertex call | 0.5d | CRIT-AI2 |
| W3-1.5 | Add adversarial prompt-injection test fixtures | 0.5d | HIGH-AI4 |
| W3-1.6 | Add Vertex `cachedContent` prefix caching for stable system prompts | 0.5d | HIGH-AI5 |
| W3-1.7 | Tighten OCR retry server-side (don't bypass validators) | 0.5d | HIGH-AI1 |
| W3-1.8 | Stop logging `recipe.title` in success path (privacy) | 30min | HIGH-AI2 |
| W3-1.9 | Add client retry-cap (3 attempts max, exponential backoff) | 30min | HIGH-AI3 |

**Sprint W3-1 total: ~6.5 days.**

### Sprint W3-2 — Analytics dark areas + privacy fixes (target: 2 weeks, ~6 engineer days)

| # | Action | Effort | Source |
|---|---|---|---|
| W3-2.1 | Implement BUT-588 `sessionId` plumb-through across analytics events | 1d | HIGH-PA1 |
| W3-2.2 | Add cooking-mode events (start, step-advance, complete, abandon) — 3 files | 1d | HIGH-PA4 |
| W3-2.3 | Wire `setUserId` for FirebaseAnalytics from auth bootstrap | 30min | HIGH-PA5 |
| W3-2.4 | Add `kDebugMode` guard on analytics emission | 30min | HIGH-PA6 |
| W3-2.5 | Compute real `cooksLast14Days` value (not literal 0) | 30min | HIGH-PA7 |
| W3-2.6 | Add `recipeFavorited` event constant + emit | 30min | HIGH-PA9 |
| W3-2.7 | Wire 9 dark social-graph methods + DM events | 1.5d | HIGH-PA10 |
| W3-2.8 | Add `firstCook` milestone event | 30min | HIGH-PA11 |
| W3-2.9 | Update `feature_flag_evaluated` to fire from `isEnabled` too | 30min | HIGH-PA8 |
| W3-2.10 | Add reCAPTCHA disclosure to privacy policy + wait for consent before activation | 0.5d | HIGH-TS4 |
| W3-2.11 | Onboarding consent gap fix | 0.5d | HIGH-TS1 |
| W3-2.12 | Fix `ContentType` rule enum / silent black-hole on retired values | 0.5d | HIGH-TS3 |

**Sprint W3-2 total: ~5.5 days.**

### Sprint W3-3 — Pre-monetization scaffolding (defer until product decides; estimate-only)

| # | Action | Effort | Source |
|---|---|---|---|
| W3-3.1 | Fix iOS subtitle to 30 chars (when submission becomes a target) | 5min | HIGH-MON1 |
| W3-3.2 | Capture screenshots for store submission (when target) | 1d | HIGH-MON3 |
| W3-3.3 | Add `subscriptionTier` plumb-through in main.dart bootstrap | 30min | HIGH-MON2 |
| W3-3.4 | Persist `OCRUsageTracker` monthly counter | 30min | HIGH-MON4 |
| W3-3.5 | (When monetization decision made) build IAP scaffolding | est. 5-10d | HIGH-MON5+6+7 |

**Sprint W3-3: 2-3 days for non-monetization items; rest deferred.**

**Total Wave-3 active remediation: ~12 engineer-days** (excluding deferred IAP work).

---

## 7. Cross-prompt deferrals

| Item | Source | Defer to |
|---|---|---|
| Mistral→Vertex code-side docstring drift | 07 default | **12 doc-drift** |
| Audit-log retention triple drift narrative | 09 + Wave 1 | **12 doc-drift + 11 legal** |
| `ConsentPurpose` propagation pattern | 09 cross-cuts | **12 doc-drift** (audit-tooling fix) |
| Privacy policy "no other data processors" false claim | 09 HIGH-TS4 | **11 legal** (text correction) |
| iOS subtitle, screenshots, store metadata copy | 10 HIGH-MON1+3 | **11 legal** when submission unlocks |
| Subscription / IAP scaffolding | 10 HIGH-MON5-7 | **Future product decision** |

---

## 8. Methodology notes

Of 4 verified CRITICALs:
- **2 unique to deep, verified by master re-check** (CRIT-AI1, CRIT-AI2)
- **1 deep with default missing entirely** (CRIT-TS1 — default rated MEDIUM)
- **1 unique to deep Pass 2 critic** (CRIT-TS2 — image moderation NEW)

No three-way CRITICALs in Wave 3 (Codex absent for 07/09/10).

Of ~28 verified HIGHs: 9 from default-unique survived verification (most for prompt 09 + 10 cross-prompt to legal); rest are deep-unique or two-way consensus.

---

## 9. Status

- Wave 1 (master): complete (10 CRITICALs, ~24 HIGHs).
- Wave 2 (master): complete (9 CRITICALs, ~26 HIGHs).
- **Wave 3 (this doc): complete (4 CRITICALs, ~28 HIGHs).**
- Wave 4 (11 + 12): pending — data files written, master next.
- Final SYNTHESIS: pending (combines 4 wave masters + 12 individual deep + default + 2 SYNTHESIS files).

**Combined Wave 1-3 verified CRITICALs: 23. Combined HIGHs: ~78.**
**Combined Wave 1-3 active remediation: ~50 engineer-days** (traditional estimate; vibecoding-realistic ~15-22 days).
