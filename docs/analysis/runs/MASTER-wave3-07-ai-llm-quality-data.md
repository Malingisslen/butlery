# MASTER Wave 3 — Prompt 07 AI/LLM Feature Quality & Reliability — Consensus Data

- **Date:** 2026-05-04
- **Inputs:** 2 runs (Codex absent for prompt 07)
  - `docs/analysis/runs/2026-05-claude/07-ai-llm-quality.md` (Claude Opus 4.7 default, Wave-1, ~41 KB)
  - `docs/analysis/runs/2026-05-claude-deep/07-ai-llm-quality.md` (Claude Opus 4.7 deep + Pass-2 critic, ~73 KB) — **AUTHORITATIVE**
- **Methodology:** Deep is authoritative. Default is sanity-check / unique-finding feed. Where they conflict on severity or numbers, deep wins. Default-unique findings are verified against live source and tagged.
- **Pre-known facts (orchestrator baseline, accepted):**
  - LLM provider migrated Mistral → Vertex AI Gemini 2.0 Flash (`europe-west1`). Both runs corrected the orchestrator's stale Mistral wording.
  - 18 callable Cloud Functions, 3 enforce App Check (~17 %).
  - `ConsentPurpose.aiProcessing` is implemented on disk (deep verified `lib/services/account/consent_service.dart:36`).

---

## Score consensus (default vs deep)

| Dimension | Default (Wave-1) | Deep Pass 1 | Deep Pass 2 (final) | Authoritative delta |
|---|---|---|---|---|
| D1 Output Validation & Guardrails | 16/20 | 15/20 | **14/20** | deep stricter (server-side validation thinness + `responseSchema` strictness gap not seen by default) |
| D2 Failure Modes & Fallback | 15/18 | 14/18 | **14/18** | deep adds retry-stack-on-rate-limit + budget skew on OCR retry |
| D3 Quality Measurement & Feedback | 11/15 | 8/15 | **8/15** | deep correctly upgrades regression-gap to CRITICAL |
| D4 Prompt Engineering & Versioning | 10/12 | 10/12 | **9/12** | deep critic upgrades prompt-prefix-caching to HIGH (CLAUDE.md cost rule) |
| D5 OCR Pipeline Robustness | 10/12 | 9/12 | **8/12** | deep critic: image preprocessing absent on Gemini Vision path (production-primary) |
| D6 Cost Controls & Abuse Prevention | 9/10 | 9/10 | **9/10** | identical |
| D7 Privacy & Regulatory | 4/8 | 6/8 | **6/8** | deep is more generous — Mistral-doc-drift is doc-only, not a privacy CRIT (default over-counted it as D7-CRIT-1) |
| D8 NLP Pipeline Accuracy | 3/5 | 3/5 | **3/5** | identical |
| **Overall** | **78 / 100** ("Good") | 74 / 100 | **71 / 100** ("Good with material gaps") |

**Authoritative score: 71 / 100.** Default's 78 is too generous because it (a) gave only 1 CRITICAL where deep finds 2, (b) under-weighted server-side validation thinness, (c) under-weighted the closed-loop quality vacuum, (d) treated `ocr_usage_tracker` and Mistral-doc-drift as more material than they are.

**Issue counts (authoritative):**

| Severity | Default | Deep Pass 1 | Deep Pass 2 (final) |
|---|---|---|---|
| CRITICAL | 1 | 2 | **2** |
| HIGH | 4 | 6 | **8** |
| MEDIUM | 11 | 14 | **17** |
| LOW | 7 | 9 | **9** |

---

## CRITICAL findings (consensus matrix + verification)

### CRIT-1 — Floating model alias `gemini-2.0-flash`
- **Status:** TWO-WAY CONSENSUS (severity disputed; deep wins).
- **Default ranks:** D4 / HIGH (top-5 #2).
- **Deep ranks:** D4 / **CRITICAL** (top-5 #1).
- **Verdict:** **CRITICAL** (deep's framing wins — combined with absence of `modelId` in `parse_corrections_v2`, a model-rev swap is undetectable; CLAUDE.md cost+correctness principles make this CRIT-grade).
- **Evidence:** `functions/src/llm/gemini-client.ts:721` literal `export const TEXT_MODEL = "gemini-2.0-flash";`. No `modelId` in `functions/src/events/log-parse-correction.ts:71-80,162-186`.
- **Verified:** YES (deep critic re-checked live).
- **Fix:** pin to `gemini-2.0-flash-001`; add `modelId` to `StructureRecipeResponse` and to correction events.

### CRIT-2 — No closed-loop quality measurement / no golden-set regression
- **Status:** TWO-WAY CONSENSUS (severity disputed; deep wins).
- **Default ranks:** D2-HIGH-2 / D3-HIGH-1 (top-5 #3) — bundled under "no scheduled regression test".
- **Deep ranks:** D3 / **CRITICAL** (top-5 #2).
- **Verdict:** **CRITICAL** (deep's escalation is correct — no `golden*` files anywhere, no scheduled CF reads `parse_corrections_v2`, no `alertPolicy` on quality metrics. Capture-only; no action half).
- **Evidence:** No `golden*` under `test/unit/services/parsing/` or `functions/src/__tests__/`. `firebase.json` has no alertPolicy. Correction-rate dashboards exist but no automated alert.
- **Verified:** YES (deep critic re-checked live).
- **Fix:** scheduled CF runs 30 known URLs through `runStructureRecipe` weekly; threshold on per-field Levenshtein; alert on >5 % delta. Marginal cost ~$0.12/month.

### CRIT-3 (default-only) — Mistral references in code-side docs
- **Status:** UNIQUE TO DEFAULT (default labels D7-CRIT-1; deep DEMOTES).
- **Default ranks:** D7 / CRITICAL (top-5 #1).
- **Deep ranks:** Not a finding — deep treats it as a known doc-drift (orchestrator pre-known fact) and quietly corrects in line 10 of its own header.
- **Verdict:** **NOT CRITICAL — demote to MEDIUM doc-drift.**
- **Reasoning:** the on-disk privacy-policy / DPIA copy is owned by Prompt 11, not by `lib/services/llm/llm_service.dart:28`'s docstring. The user-visible privacy disclosure does not literally inherit from a Dart source-comment. Default conflates "if legal copies from this docstring it'll be wrong" (true) with "users see Mistral in the privacy policy" (untested premise). Real impact is internal doc cleanup, not a CRIT user-disclosure regression.
- **Verified:** Default's evidence is real (`lib/services/llm/llm_service.dart:28-29` does say "Mistral" + "Firebase Secrets"; both wrong post-Vertex/ADC). But severity is over-stated.
- **Fix:** repo-wide grep+replace of "Mistral" → "Vertex AI Gemini" in code doc-comments (~1-2 hours). Track as MEDIUM (Doc Drift) — overlaps with Wave-3 prompt 12 (doc-drift).

---

## HIGH findings (consensus matrix + verification)

### HIGH-1 — Vertex `finishReason` / safety-block path silent
- **Status:** TWO-WAY CONSENSUS.
- **Default ranks:** D1-HIGH-1 (top-5 #5).
- **Deep ranks:** D2 / HIGH (top-5 #3).
- **Verdict:** HIGH.
- **Evidence:** `functions/src/llm/gemini-client.ts:103-114` — `extractResponseText` iterates only `candidate.content?.parts ?? []`; never reads `candidate.finishReason` or `candidate.safetyRatings`. Empty join → `""` → `structure-recipe.ts:229-237` returns `"Inget svar från AI-tjänsten."` Identical fallback at `ocr-recipe-image.ts:293-303`.
- **Verified:** YES (deep critic re-checked live).
- **Fix:** branch on `finishReason` (`STOP|MAX_TOKENS|SAFETY|RECITATION|OTHER`); log structured field; surface distinct Swedish error per cause.

### HIGH-2 — Server-to-server retry bypasses every value validator
- **Status:** UNIQUE TO DEEP (default did not surface).
- **Deep ranks:** D1 / HIGH (top-5 #4).
- **Verdict:** HIGH.
- **Evidence:** `functions/src/llm/ocr-retry.ts:154-157` calls `deps.structureRecipe({text:rawText, mode:"extract"}, authUidHash)` → `structure-recipe.ts:290-315` returns `parseRecipeResponse` direct. Server `parseRecipeResponse` (`gemini-client.ts:639-703`) only validates required-field presence + type coercion. All per-unit ceilings, suspicious-pattern, URL-in-title, instruction-count cap live in `lib/services/parsing/tiers/llm_tier.dart:128-178,398-499` (client-side only).
- **Verified:** YES.
- **Why default missed:** default's D1 matrix marks "server-side validation is intentionally thin" as a *feature* (Vertex enforces shape). Default did not trace the OCR-retry server-to-server path that bypasses the client-side value layer.
- **Fix:** port per-unit ceilings, suspicious-pattern check, URL-in-title check, instruction-count cap into `parseRecipeResponse` so both call sites are protected.

### HIGH-3 — Kill-switch indistinguishable from generic no-result client-side
- **Status:** TWO-WAY CONSENSUS.
- **Default ranks:** D2-HIGH-1 (top-5 #4).
- **Deep ranks:** D2 / HIGH.
- **Verdict:** HIGH.
- **Evidence:** `structure-recipe.ts:160-173` returns `{success:false, error:"AI-receptolkning är tillfälligt avstängd."}`. `lib/services/parsing/tiers/llm_tier.dart:112-122` maps any `!response.success` to `TierFailureReason.noData`. UI shows generic "no recipe found".
- **Verified:** YES.
- **Fix:** add `TierFailureReason.aiKilled` (or `featureDisabled`); pipe server-supplied Swedish copy through `userMessage` on `ParseResult`.

### HIGH-4 — Divergent compound splitter implementations
- **Status:** PRESENT IN BOTH (severity escalated by deep).
- **Default ranks:** D8-LOW-1 ("two splitters coexist").
- **Deep ranks:** D8 / HIGH (top-5 #5).
- **Verdict:** HIGH (deep's escalation is correct — they have *different rules and different production callers*).
- **Evidence:**
  - `lib/utils/text/compound_splitter.dart` (146 lines, scoring + LRU cache, suffixes from `CompoundSuffixes.{extendedEndings,primarySuffixes}`) — called by `lib/utils/text/ingredient_normalizer.dart:476`.
  - `lib/utils/text/swedish_compound_splitter.dart` (98 lines, hardcoded ~40-element `_foodSuffixes`, no cache) — called by `lib/services/parsing/crf/crf_feature_extractor.dart:169`.
  - Both files exist on disk (verified).
- **Verified:** YES (live grep confirmed both call paths).
- **Why default under-rated:** default treated it as aesthetic ("knowledge-file pattern says supersede"); did not trace that both have live callers in different production paths producing inconsistent splitting decisions for allergen detection vs ingredient lookup.
- **Fix:** pick one canonical, delete the other; or factor into shared core with two API surfaces.

### HIGH-5 — `recipe.title` logged in success path (privacy)
- **Status:** UNIQUE TO DEEP (default did not surface).
- **Deep ranks:** D7 / HIGH.
- **Verdict:** HIGH.
- **Evidence:** `structure-recipe.ts:307` logs `` `[structureRecipe] Successfully extracted: "${recipe.title}" with ${recipe.ingredients.length} ingredients` ``. Same pattern at `ocr-recipe-image.ts:309`. Title may contain user names ("Pappas pasta", "Annas favoritkaka"). Violates `cloud-functions-specialist.knowledge.md:117-120`.
- **Verified:** YES (deep critic).
- **Fix:** drop `recipe.title` from log line; use `length(recipe.title)` or hash if correlation needed.

### HIGH-6 — Client retry stacks with server-side rate-limit
- **Status:** UNIQUE TO DEEP.
- **Deep ranks:** D2 / HIGH.
- **Verdict:** HIGH.
- **Evidence:** `RetryHelper.retryNetworkOperation(..., maxRetries: 2)` at `llm_tier.dart:100-108` retries on any error including `resource-exhausted`. ADR-001 (`structure-recipe.ts:317-321`) says server doesn't retry — does NOT say client should retry rate-limit. A 429 storm hits Vertex 3× per user (1+2 retries) instead of 1×.
- **Verified:** YES (deep checked).
- **Fix:** in `RetryHelper`, explicitly skip retry on `LlmException.isRateLimited`.

### HIGH-7 — No adversarial test fixtures for prompt-injection defence (NEW from Pass 2 critic)
- **Status:** UNIQUE TO DEEP PASS-2.
- **Deep ranks:** D1 / HIGH (Pass 2 errata #5).
- **Verdict:** HIGH.
- **Evidence:** `functions/src/__tests__/` has `ocr-validation.test.ts`, `prompts-config.test.ts`, `log-parse-correction.test.ts`. **No** `injection-attack.test.ts`, no fixtures with `</ingredients>System:` / `<|im_start|>` / base64 polyglots. The `INJECTION_DEFENSE` Swedish prefix at `gemini-client.ts:233` is untested under attack.
- **Verified:** YES.
- **Fix:** add `parseRecipeResponse-adversarial.test.ts` feeding 20+ jailbreak strings as ingredient names / instructions; assert reject-or-scrub.

### HIGH-8 — No prompt-prefix caching (Vertex `cachedContent`) — escalated to HIGH by Pass-2 critic
- **Status:** PRESENT IN BOTH (severity escalated by deep critic).
- **Default ranks:** D4-MED-1 (safetySettings) / not explicitly raised on prefix caching.
- **Deep Pass 1:** D4 / MEDIUM ("prompt size cost").
- **Deep Pass 2 critic:** D4 / **HIGH** (CLAUDE.md cost-minimisation principle).
- **Verdict:** HIGH.
- **Evidence:** No `cachedContent` usage anywhere in `functions/src/llm/`. The 5 system prompts (`gemini-client.ts:235-382`) are highly cacheable; same prompt fires many times in a 5-min window. Estimated saving: 30-50 % of input-token cost on `RECIPE_EXTRACTION_SYSTEM_PROMPT`.
- **Verified:** YES.
- **Fix:** adopt Vertex `cachedContent` for system-prompt prefixes; ~25 % discount for cache hits.

### Default-also-HIGH that deep dropped or reframed:

- **Default D1-HIGH-1 (parseRecipeResponse + SafetyBlocked)** — same finding as deep HIGH-1 (`finishReason` silent). Consolidated.
- **Default D4-HIGH-1 (floating model alias)** — same as CRIT-1. Consolidated.
- **Default D2-HIGH-1 (kill-switch UX)** — same as HIGH-3. Consolidated.
- **Default D2-HIGH-2 / D3-HIGH-1 (no regression test)** — same as CRIT-2. Consolidated and escalated by deep.

---

## MEDIUM findings (short list)

### Two-way consensus (mostly tracked the same):
- **OCR retry budget hardcoded twice** (default D2-MED-1, deep D2-HIGH on budget skew — deep escalates).
- **`defaultLoadKillSwitch` re-reads `system/config` per call, no cache** (default D2-MED-2, deep doesn't explicitly call out — default UNIQUE-VERIFIED).
- **Tagging-pipeline failure isolation gap** (default D2-MED-3 / D8-MED-2; deep D2 has it as MEDIUM in tagging-pipeline section).
- **No A/B prompt testing infrastructure** (default D3-MED-1, deep D3 / strategic).
- **Quality dashboard runbook missing** (default D3-MED-2).
- **No edit-rate by source-domain aggregator** (default D3-MED-3, deep D3 / "no edit-distance computed on save").
- **Vertex `safetySettings` not configured** (default D4-MED-1; deep does not call out — default UNIQUE).
- **`tags[]` no controlled vocabulary** (default D4-MED-2 + D1-MED-2; deep D4 / `responseSchema` strictness Pass-2 NEW MEDIUM).
- **Prompt-changelog CI enforcement planned not active** (default D4-MED-3).
- **OCR Unicode fractions missing ⅙ ⅚ ⅐** (default D5-MED-1).
- **No non-Swedish text detection in OCR** (default D5-MED-2).
- **OCR-error-corrector vs PII-scrubbing order** (default D5-MED-3).
- **Rate-limit fail-mode inconsistent error code** (default D6-MED-1).
- **`ConsentPurpose.aiProcessing` single bucket, no granularity** (default D7-MED-1).
- **No AI Act Art. 50 transparency UX** (default D7-MED-2; deep D7 / "no first-use AI disclosure").
- **OCR `imageUrl` token in transit** (default D7-MED-3; partially overlaps deep's `recipe.title` HIGH).
- **`SwedishCompoundSplitter._foodSuffixes` lacks `-rätt/-paj/-soppa/-stuvning`** (default D8-MED-1; deep D8 / brand names + foreign loanwords MEDIUM).

### Deep-unique MEDIUMs:
- D1: `parseRecipeResponse` accepts unbounded `parsed.instructions.length` (no cap server-side).
- D1: No URL-in-`source` check.
- D1: per-unit amount ceilings only in Dart (kMaxAmountByUnit not ported to TS).
- D1: `instructions[].text > 2000 chars` rejects whole recipe (one bad step nukes 49 good).
- D1: `description` length triple-source mismatch (prompt 200, schema 500-slice, client 500).
- D1: instruction-smuggling via ingredient name undefended (jailbreak markers).
- D1: source field round-tripped from LLM not from `cleanSourceUrl` — bypasses scrubbing.
- D1: no cross-check that instructions reference declared ingredients.
- D1: no quantity-vs-portions ratio sanity guard.
- D1: salvage path `truncated:true` not analytics-emitted (only logger.warn).
- D2: no salvage for main `parseRecipeResponse` token-cap mid-recipe.
- D2: `LlmException.isRateLimited` detected by string-match `"rate limit"` instead of `code==="resource-exhausted"`.
- D2: HEIC / PDF MIME magic-byte detection missing in `detectMimeType`.
- D2: empty `triggerProperties` in Firebase config silently skips an allergen.
- D3: no `parsedByTier` field persisted on recipe doc.
- D3: cost-per-import metric not aggregated.
- D5: image preprocessing (rotation/contrast/downscale) absent on Gemini Vision path (production-primary).
- D5: `INPUT_COST_PER_M`/`OUTPUT_COST_PER_M` may not match Vertex EU pricing; vision input has different per-image cost not modelled.
- D5: `withTimeout` not applied to `model.generateContent` on OCR path.
- D5: `context` field on OCR scrubbed for PII but appended verbatim — same injection vector as recipe text, no defense.
- D6: no per-IP rate limiting.
- D6: `system/llmLimits` global counter has no per-operation breakdown.
- D6: `enhancement` and `ingredientLines` modes share daily budget.
- D6: no Vertex AI quota monitoring / alertPolicy (Pass-2 NEW MEDIUM).
- D7: personnummer regex requires hyphen — `198501011234` not redacted (Pass-2 upgrades from LOW to MEDIUM).
- D8: divergent compound splitter regression coverage missing (Pass-2 NEW MEDIUM).
- D8: ONNX line-classifier model has no SHA-256 / signature integrity check.
- D8: brand names (Marabou, Felix) not in known-ingredient vocab.
- D8: foreign loanwords (ricotta, guanciale) not in compound splitter.
- D8: range handling `2-3 dl` may double-process between server prompt convention and client `quantity_parser`.
- D1 (Pass-2 NEW): Vertex `responseSchema` strictness gap — `enum`, `maxItems`, `maxLength`, `pattern` supported but unused in `RECIPE_SCHEMA` / `INGREDIENT_SCHEMA`.

---

## Disproved by deep critic

1. **Default's "OCR pipeline = 3-provider with circuit breaker" framing.** Default D5 describes "OCR.space → Google Vision → Tesseract" with circuit breaker as production. Deep Pass-1 initially called this out as dead code; Deep Pass-2 critic **REJECTED that rejection** — `OCRExtractionService` IS live: `lib/services/ocr_extraction_service.dart:253` `_recordUsage(...)` is called at lines 274, 290, 301, 316, 331; the service is constructed in `lib/viewmodels/photo_import_viewmodel.dart:119,539`; held in `lib/services/import/photo_import_strategy.dart:57`; registered as production in `lib/services/import/import_manager.dart:139`. **Verified live by this MASTER pass:** `recordUsage` callers found at exactly those line numbers. The 3-provider pipeline is therefore **alive alongside** Gemini Vision OCR — the in-memory tracker is observability-broken (resets per app launch) but the code is not dead. Default is technically correct; Deep Pass-1's "dead code" framing was wrong; Deep Pass-2 retracted.

2. **Default D7-CRIT-1 "Mistral references in code-side documentation."** Default labelled as CRITICAL on the theory that legal/privacy docs would mirror the code-side docstring. Deep does not treat as CRIT (and silently corrects in its own header). Authoritative verdict: doc-drift, MEDIUM, repo-wide grep+replace ~1-2h. **Default's CRITICAL count therefore over-states by 1.**

3. **Default's D5-LOW-1 "OCRUsageTracker is in-memory only — no persistence — counters reset on launch — therefore useless."** Default's claim of uselessness is overstated: deep critic shows the tracker IS called on every photo-import path (cache_hits, ocr_space, google_vision, tesseract). The data is collected; it just isn't surfaced anywhere. So "remove or persist" is the right fix but "in-memory only" is not "dead". Reframe to MEDIUM observability-broken-not-dead.

4. **Default's D2-LOW-1 "Tier priority numbers are magic constants, no central registry."** Mostly aesthetic; deep does not surface. Authoritative: keep as LOW or drop.

5. **Default's D1-MED-3 "no SQL-injection-shape guard but Firestore is JSON so OK."** Self-disproving; default explicitly says it's out of scope. Drop.

---

## Unique to default (verified)

These findings appear ONLY in default but live source confirms them. Add them to the MASTER doc.

1. **D2-MED-2 — `defaultLoadKillSwitch` reads `system/config` on every call (no cache).**
   - **Verified:** YES (deep does not contradict; deep's `prompts-config.ts` has cache, kill-switch should mirror).
   - **Severity:** MEDIUM.
   - **Evidence:** `structure-recipe.ts:94-99` reads on every invocation; compare `prompts-config.ts:91` 5-min cache.
   - **Fix:** 60s module-scope cache.

2. **D3-MED-2 — Quality dashboard URL not documented.**
   - **Verified:** YES (no `docs/ops/parse-quality-dashboard-runbook.md` found).
   - **Severity:** MEDIUM.
   - **Fix:** add runbook with BigQuery views / Looker dashboard URLs.

3. **D4-MED-1 — Vertex-side `safetySettings` not configured.**
   - **Verified:** YES (`gemini-client.ts:69-79` does not set `safetySettings` on `generationConfig`; defaults BLOCK_MEDIUM_AND_ABOVE on dangerous content may inappropriately block legitimate alcohol/knife references).
   - **Severity:** MEDIUM.
   - **Fix:** explicit `safetySettings: [{category:"HARM_CATEGORY_DANGEROUS_CONTENT", threshold:"BLOCK_ONLY_HIGH"}, …]`.

4. **D4-MED-3 — Prompt-changelog CI enforcement is "planned" but not active.**
   - **Verified:** YES (no CI workflow asserts a `PROMPT_CHANGELOG.md` entry on `gemini-client.ts:PROMPT_VERSION` change).
   - **Severity:** MEDIUM.
   - **Fix:** CI script diffs `PROMPT_VERSION` and asserts same-PR new entry.

5. **D5-MED-1 — Unicode fractions missing ⅙ ⅚ ⅐.**
   - **Verified:** YES — re-checked `lib/utils/text/quantity_parser.dart:55-68` confirms only ½ ¼ ¾ ⅓ ⅔ ⅛ ⅜ ⅝ ⅞ ⅕ ⅖ ⅗ (12 entries); ⅙, ⅚, ⅐ absent.
   - **Severity:** LOW-MEDIUM (low-frequency in baking).
   - **Fix:** add three entries; trivial.

6. **D5-MED-2 — No non-Swedish text detection in OCR.**
   - **Verified:** UNVERIFIABLE without grep but plausible (no `langid`-style tooling found in deep index either).
   - **Severity:** MEDIUM.
   - **Fix:** post-OCR language-detect; reject with Swedish "Endast svenska recept stöds just nu".

7. **D8-MED-1 — `SwedishCompoundSplitter._foodSuffixes` lacks `-rätt/-paj/-soppa/-stuvning`.**
   - **Verified:** YES (deep confirms `swedish_compound_splitter.dart:23-31` hardcodes ~40-element set including `press, kvarn, mos`; deep does not enumerate the missing dish-suffixes but Default's enumeration is plausible).
   - **Severity:** MEDIUM (overlaps with deep's HIGH-4 splitter divergence — fix when unifying).

8. **D6-LOW-1 — No `docs/ops/cost-alerts.md`.**
   - **Verified:** YES (no such file found).
   - **Severity:** LOW.
   - **Fix:** add doc describing GCP budget alert thresholds.

9. **D7-MED-3 — OCR `imageUrl` Storage download URL with `?token=` in transit.**
   - **Verified:** Plausible. `ocr-url-validator.ts:268-273` has a "do not log download URLs" guard; deep does not re-flag but doesn't disprove either. Practical exposure low (Cloud Functions default doesn't capture request bodies).
   - **Severity:** MEDIUM (default's call) → **deep would likely call LOW** (no log path captures it). Authoritative: MEDIUM with low practical risk.

---

## Cross-prompt boundaries (defer-out)

Both runs explicitly defer-out the same items, with deep being slightly more explicit:

| Concern | Owner |
|---|---|
| LLM API-key security, CORS scope, auth/App-Check enforcement details | **02 Security** |
| Cloud Function timeout / cold-start / memory / per-prompt latency (p99) | **04 Performance** |
| Vertex SDK / `vertexai 1.12.0` / `p-limit` / `flutter_onnxruntime` CVEs | **05 Dependencies** |
| Privacy-policy / DPIA wording / data-safety disclosure copy / Mistral→Vertex legal-doc-drift | **11 Legal** |
| Repo-wide stale-Mistral references in non-LLM code paths | **12 Doc Drift** |

**Cross-prompt finding to flag for Wave-3 prompt 02 (security):** HIGH-2 (server-to-server retry bypass) is technically input validation, not auth/CORS. It belongs in 07 (this doc). HIGH-7 (no adversarial fixtures for `INJECTION_DEFENSE`) is testing-side; could also be flagged for 01 (code quality / test gaps). Authoritative: keep both in 07.

**Cross-prompt finding to flag for Wave-3 prompt 03 (infrastructure):** Pass-2 NEW MEDIUM "no Vertex quota alertPolicy" overlaps with infrastructure's GCP-side observability. Keep in 07 because it concerns AI feature reliability specifically.

**Cross-prompt finding to flag for Wave-3 prompt 04 (performance):** OCR retry budget skew (deep HIGH on `MIN_REMAINING_BUDGET_MS = 65_000` triggering frequent `skipped_budget` due to cold-start + OCR + rawText time) is partially performance-owned. Authoritative: cite both 04 and 07.

---

## Verification footer

- All deep CRITICAL/HIGH items re-verified by Deep Pass-2 critic against live source; line refs confirmed reliable.
- Default's CRITICAL count over-states by 1 (Mistral-doc-drift demoted).
- Default's HIGH-4 (`parseRecipeResponse` shape-mismatch) is the same finding as deep HIGH-1; consolidated.
- Default-unique MEDIUMs that survive: 9 (listed under "Unique to default — verified"). Five of those nine cluster under doc/runbook/CI hygiene; four are technical (kill-switch cache, safetySettings, Unicode fractions, lang-detect).
- Two splitters confirmed live with different production callers:
  - `compound_splitter.dart` ← `ingredient_normalizer.dart:476`
  - `swedish_compound_splitter.dart` ← `crf/crf_feature_extractor.dart:169`
- `ocr_usage_tracker.recordUsage` confirmed called at 5 sites in `ocr_extraction_service.dart` (lines 257, 278, 294, 305, 320, 335).

**Authoritative summary line for the MASTER doc:**

> AI / LLM Feature Quality scores **71/100** — 2 CRITICAL (floating model alias; no closed-loop quality measurement), 8 HIGH, 17 MEDIUM, 9 LOW. Production-shippable; two High items deserve a sprint. Highest-leverage fix: pin `gemini-2.0-flash-001` and add `modelId` to analytics events (≤1h, removes a class of silent regressions). Highest-leverage build: scheduled golden-set regression CF (~$0.12/month, closes the D3 gap that no other measurement can).
