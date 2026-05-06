# MASTER Wave 3 — Prompt 10 (Monetization Readiness & Competitive Positioning) — Consensus Data

**Status:** Consensus build for master document.
**Sources:** 2 of 3 runs (Codex missing for Wave 3 monetization).
**Authoritative source:** `docs/analysis/runs/2026-05-claude-deep/10-monetization.md` (deep, Pass 1 + Pass 2 critic, ~89 KB — the largest Wave 3 report).
**Sanity check:** `docs/analysis/runs/2026-05-claude/10-monetization.md` (default, ~35 KB).
**Authoritative baseline (per MEMORY.md):**
- "No monetization decisions yet — just build the app" (Beta UX 2026-02-13).
- "Smart Cooking Mode first → AI Companion post-monetization" (Strategic Feature Analysis pointer).
- Store submission deferred indefinitely (`memory/feedback_no_store_submission_yet.md`).

**Headline scores:**
- Default: **70 / 100** ("Acceptable")
- Deep Pass 1 self-score: **68 / 100**
- Deep Pass 2 critic-adjusted: **65.5 / 100**

**Critical caveat — strategic vs code-fact reliability:**
Most of this prompt is *strategic / forward-looking* (entitlement design, IAP commercial mechanics, ASO positioning, competitor matrices). Strategic claims are **inherently more uncertain than code-state findings**. Each finding is tagged below with whether it is a verified code fact or a strategic hypothesis. CRITICAL findings are 0 in both runs (intentional — user has explicitly deferred submission and monetization).

---

## 1. Inventory — CRITICAL + HIGH findings

Both runs report **CRITICAL = 0**. All HIGHs are forward-looking (no live defects today). Wave-2 prompt 06 owns the App Store Readiness sub-score; this prompt cross-references it.

### 1.1 Default-run HIGHs (4 total)

| ID | Title | Type |
|----|-------|------|
| D-1.1 | No `subscriptionTier` field on `UserProfile` | Code fact |
| D-1.2 | No IAP package in `pubspec.yaml` | Code fact |
| D-1.3 | No Cloud Function for receipt validation | Code fact |
| D-2.1 | Rate-limit constants are hardcoded `static const` (16 callsites in 1 file) | Code fact |
| D-3.1 | No inline cooking timers | Code fact (PARTIALLY DISPROVED — see §4) |
| D-3.2 | No live recipe scaling UI | Code fact (DISPROVED — see §4) |
| D-4.1 | Differentiation undercommunicated in store metadata | Strategic |
| D-5.1 | Sign in with Apple becomes mandatory same release as any other social login | Strategic |
| D-5.2 | No App Store reviewer demo account documented | Code fact |
| D-5.3 | No Google Play Data Safety section drafted | Cross-ref Prompt 12 |
| D-6.1 | No paywall UI components in `lib/widgets/` | Code fact |

(Default-run section headers count "HIGH = 4" but the markdown contains 11 HIGH-level entries spread across §1–§6; the executive-summary "4" tally appears to be undercount. Deep run's **HIGH = 6** is closer to ground truth and is what the master should adopt.)

### 1.2 Deep-run HIGHs (Pass 1 = 6, Pass 2 critic adds +2 → 8 total)

**Pass 1 HIGH (6):**
| ID | Title | Type | Sister parity |
|----|-------|------|---------------|
| DP-1.1 | No `subscriptionTier` field on `UserProfile` (6-surface refactor) | Code fact | TWO-WAY |
| DP-1.2 | No IAP package in `pubspec.yaml` (RevenueCat strategic recommendation) | Code fact | TWO-WAY |
| DP-1.3 | No Cloud Function for server-side receipt validation | Code fact | TWO-WAY |
| DP-1.4 | `subscription_tier` analytics property is wired but frozen at `'free'` (NEW) | Code fact | DEEP-UNIQUE — sister missed |
| DP-2.2 | Rate-limit constants `static const` (16 callsites enumerated) | Code fact | TWO-WAY |
| DP-2.3 | Recipe-count cap infrastructure absent (NEW) | Code fact | DEEP-UNIQUE |
| DP-2.4 | Image-storage cap infrastructure absent (NEW) | Code fact | DEEP-UNIQUE |
| DP-3.1 | Inline cooking timer auto-extract missing (infra exists) — sister claim "missing" corrected | Code fact | DEEP-CORRECTS |
| DP-3.2 | Voice / hands-free cooking mode | Code fact | TWO-WAY |
| DP-3.3 | Manual nutrition entry / Livsmedelsverket fetch | Code fact | TWO-WAY |
| DP-4.1 | Differentiation undercommunicated in store metadata | Strategic | TWO-WAY |
| DP-5.1 | iOS subtitle 31 chars > Apple's 30-char limit (submission blocker) | Code fact | DEEP-UNIQUE — sister missed |
| DP-5.2 | SiwA mandatory same-release as other social login | Strategic | TWO-WAY |
| DP-5.3 | No App Store reviewer demo account documented | Code fact | TWO-WAY |
| DP-5.4 | Zero actual screenshots on disk (submission blocker) | Code fact | DEEP-UNIQUE |
| DP-6.1 | No paywall UI components | Code fact | TWO-WAY |
| DP-7.1 | 31-char subtitle blocks submission, undercommunicates AI (cross-link to 5.1) | Code fact + Strategic | DEEP-UNIQUE |

**Note:** Pass-1 declares "HIGH = 6" in exec summary but the body markdown contains 17 HIGH-tagged entries across §1–§7 (some are duplicate-cross-refs, e.g. 7.1 = 5.1). The "6" exec-summary count appears to refer to *unique* HIGHs; the master should adopt either the 6-count headline OR enumerate all distinct HIGHs (~12 unique).

**Pass 2 critic-added HIGH (2):**
| ID | Title | Type |
|----|-------|------|
| DC-B1 | Platform fees (Apple/Google 15% vs 30%, ASBSP enrollment) — never named in Pass 1 | Strategic / commercial |
| DC-B3 | Subscription state restoration after reinstall — Pass 1 mentioned button, never specified the flow | Strategic / commercial |

---

## 2. Consensus mapping — two-way vs unique

### 2.1 TWO-WAY consensus (both runs flag) — STRONG

| # | Finding | Default ID | Deep ID |
|---|---------|------------|---------|
| 1 | No `subscriptionTier` field on `UserProfile` (6 serialization surfaces) | D-1.1 | DP-1.1 |
| 2 | No IAP package (`in_app_purchase` / `purchases_flutter` / etc.) in `pubspec.yaml` | D-1.2 | DP-1.2 |
| 3 | No Cloud Function for receipt validation / webhook | D-1.3 | DP-1.3 |
| 4 | Rate-limit `static const` (16 callsites in 1 file, refactor mechanical) | D-2.1 | DP-2.2 |
| 5 | Voice / hands-free cooking mode missing (no `speech_to_text` dep) | D-3.4 | DP-3.2 |
| 6 | Manual nutrition entry / Livsmedelsverket fetch deferred (deliberate per memory) | D-3.3 | DP-3.3 |
| 7 | Differentiation undercommunicated in store metadata; AI/OCR/social-import buried | D-4.1 | DP-4.1 |
| 8 | SiwA mandatory same-release as any other social login (Apple §4.8) | D-5.1 | DP-5.2 |
| 9 | No App Store reviewer demo account documented (`reviewer-credentials.md`) | D-5.2 | DP-5.3 |
| 10 | No paywall UI components in `lib/widgets/` (zero `paywall/` / `entitlement/` / `upgrade/`) | D-6.1 | DP-6.1 |
| 11 | No conversion-funnel analytics events (`paywall_viewed`, `trial_started`, etc.) | D-6.2 | DP-6.2 |
| 12 | LLM cost ceiling per user `$0.50/day, $10/month` → AI import must be premium hook OR site-config-tiered (already implemented; mitigates) | D-6.5 | DP-6.6 |
| 13 | `firestore.rules` field-level write-protection for `subscriptionTier` not yet present (cross-ref Prompt 02) | D-2.3 | DP-2.6 |
| 14 | Schema is additive-friendly via defensive `safeXxx` deserialization, but no `schemaVersion` field | D-2.2 | DP-2.5 |
| 15 | `PermissionService` singleton is anti-DI; future `SubscriptionService` should use DI module pattern | D-1.4 | DP-1.5 |
| 16 | `isInRollout` could double as percentage-based premium-preview gating | D-1.6 | DP-1.8 |
| 17 | OG / JSON-LD on shared web routes missing | D-7.1 | DP-7.2 |
| 18 | UTM acquisition attribution wired but no campaign-loop / attribution-aware UI | D-7.2 | DP-7.3 |
| 19 | No referral / invite-loop incentive infrastructure (deep-link gen exists; reward grant missing) | D-4.3 | DP-4.5 |
| 20 | Nordic localization is one-ARB-file-away; structural strength | D-7.3 | DP-7.5 |
| 21 | No `feature_used` generic event for premium-feature heatmapping | D-2.4 | DP-2.7 |
| 22 | 8–9 separate import entry-points (cross-ref UX prompt 06) | D-3.5 | DP-3.5 |
| 23 | Cloud Function cost-trace per AI parse missing | D-6.6 | DP-6.7 |

**TWO-WAY moat / strength agreement:**
- `ImportRateLimiter` per-window cost tracking with Firestore transactions = freemium plumbing already paid for. (Both runs lead with this.)
- `FeatureFlagService` + `isInRollout` FNV-1a stable hashing = right substrate for percentage-entitlement gating.
- Multi-tier import pipeline (site-config → regex → LLM) = unit-economics moat (LLM is fallback, not default).
- Parsing-correction telemetry = data flywheel for Swedish NLP.
- GDPR + Swedish microcopy = trust moat.
- `in_app_review_service.dart` already shipped (BUT-678).
- Multi-platform widens funnel.

**TWO-WAY differentiation matrix (competitor scoring):**
- Default: Butlery × 6 competitors × 14 features.
- Deep: Butlery × 8 competitors × 21 features (adds Tasteline, Eaty (DK); adds rows for Pantry, Cook tracking, Pings, Substitution, Household, Cookbook PDF).
- Both flag Butlery's strongest moats: Swedish NLP, multi-tier import, collaborative meal planning, GDPR + Swedish microcopy.

### 2.2 DEEP-UNIQUE findings (deep flags; default missed)

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| U1 | iOS subtitle 31 chars > Apple's 30-char limit (`store_assets/metadata/sv-SE/subtitle.txt`) — submission blocker | HIGH | **VERIFIED** (see §3.1) |
| U2 | `OCRUsageTracker` partially in-memory: monthly counter + provider-usage map are NOT persisted; only daily count is persisted to SharedPreferences | HIGH | **VERIFIED with correction** (see §3.2) |
| U3 | `subscription_tier` analytics user-property is wired but frozen at `'free'` — no business-event re-emit pathway | HIGH | **VERIFIED** (see §3.3) |
| U4 | Recipe-count cap infrastructure absent (no `recipesOwnedCount` counter) | HIGH | VERIFIED (`UserCounters` tracks only inbox metrics; deep cited `user_counters.dart:1-50`) |
| U5 | Image-storage cap infrastructure absent (no per-user byte sum) | HIGH | UNVERIFIABLE without deep `image_upload_service.dart` read |
| U6 | Zero actual screenshots on disk in `store_assets/screenshots/` (only README) | HIGH | **VERIFIED** (see §3.4) |
| U7 | `HouseholdService` is the substrate for a Family Plan (group-marked-as-household → shared entitlement) | Strategic moat | **VERIFIED** (see §3.5) |
| U8 | Cook tracking ("lagat-snap") captures genuine cooking events — basis for "Wrapped"-style annual recap (SO-3) | Strategic moat | VERIFIED (services exist per file refs) |
| U9 | Pings (presence-aware nudges) are unique to Butlery in surveyed competitors | Strategic moat | UNVERIFIABLE (competitor inventories) |
| U10 | UTM attribution data infrastructure exists; ready before paid acquisition starts | Strategic | VERIFIED (file refs cited) |
| U11 | Tasteline + Eaty (DK) added to competitor matrix (default omitted them) | Strategic | UNVERIFIABLE — market-position claims |
| U12 | Default's "live recipe scaling = Partial" is **wrong**: `portion_scaler{,_logic,_ui}.dart` + `recipe_detail_content.dart:577-578` show live scaling | Code-fact correction | **VERIFIED** — files exist (see §3.6) |
| U13 | Default's "cooking timer = Missing" is **partially wrong**: `step_timer_service.dart` exists with absolute end-times; auto-extract from instruction text is what's missing | Code-fact correction | **VERIFIED** (see §3.7) |
| U14 | Web/desktop offline incomplete (4 stub files: `offline_initialization_stub.dart`, etc.) — partial-truth on description.txt's "FUNGERAR OFFLINE" claim | Code fact | UNVERIFIED in this consensus pass; deep-flagged |
| U15 | `web/manifest.json:9 "orientation":"portrait-primary"` locks PWA portrait → breaks landscape cooking mode on web | Code fact | UNVERIFIED in consensus pass |
| U16 | Cook-tracking is invisible as personal-stats feature — premium "Wrapped" opportunity | Strategic | Hypothesis |
| U17 | 8 conversion-funnel events enumerated specifically (paywall_viewed, dismissed, trial_started, converted, sub_renewed, sub_cancelled, restore_attempted, restore_succeeded) | Code fact | Default named "6", deep names "8" |
| U18 | `google_sign_in_mocks` in `dev_dependencies` only — mocks-without-impl pattern signals "social login was scoped and dropped" | Code fact + interpretation | VERIFIED dep status; "scoped and dropped" is interpretation |
| U19 | `android/app/src/main/AndroidManifest.xml` has no `com.android.vending.BILLING` permission | Code fact | VERIFIED via deep grep |

**Pass 2 critic blind-spot additions (deep-only, NOT in default):**
| # | Finding | Severity | Type |
|---|---------|----------|------|
| C-B1 | Apple/Google 15% vs 30% take-rate; ASBSP small-biz enrollment for solo founder | HIGH | Strategic / commercial fact |
| C-B2 | Refund webhook handling (Apple V2 `REFUND` / Google `SUBSCRIPTION_REFUNDED` RTDN) — Pass 1 covered receipt validation but not refund flows | MEDIUM | Strategic / commercial |
| C-B3 | Subscription state restoration on reinstall — anonymous-auth UID change, cross-platform (iOS↔Android), sign-out/sign-back-in cases | HIGH | Strategic / commercial |
| C-B4 | Cross-platform entitlement: Apple §3.1.3(b) "Multiplatform Services" allows Stripe-on-web + IAP-on-iOS — 5–15% margin win | MEDIUM | Strategic / commercial |
| C-B5 | Promo-code / offer-code infrastructure (Apple offer codes, Google promo codes) | LOW | Strategic / commercial |
| C-B6 | Education / discount eligibility (probably skip for Butlery's ICP) | LOW | Strategic |
| C-B7 | EU 14-day cooling-off (Consumer Rights Directive 2011/83/EU) — Konsumentverket enforcement, not Apple-enforced | MEDIUM | Strategic / regulatory |
| C-B8 | Swedish-anchored pricing (9 SEK / 19 SEK / 29 SEK) ≠ USD-anchored auto-conversion | MEDIUM | Strategic / regional |
| C-B9 | VAT / OSS for EU SaaS — IAP exempt (Apple/Google = merchant of record); Stripe-on-web requires OSS registration | MEDIUM | Structural / regulatory |
| C-B10 | ASBSP enrollment must happen BEFORE first paid release for 15% rate to auto-apply | LOW | Action item |
| C-C1 | Free-trial eligibility (`appAccountToken` to prevent multi-trial abuse) | MEDIUM | Strategic |
| C-C2 | Grace period handling (16-day Apple grace; `STATUS_IN_GRACE_PERIOD`) | MEDIUM | Strategic |
| C-C3 | Account-deletion ↔ active subscription interaction — app cannot cancel sub on user's behalf | MEDIUM | Cross-ref Prompt 09 |
| C-C4 | Break-even subscription price floor calculation: $10 LLM + $0.005 RevenueCat + 15% Apple → ~$12–14/mo for "unlimited AI" tier to be cash-positive on heavy users | HIGH (strategic framing) | Strategic |
| C-C5 | Stripe vs Adyen vs PayPal for web checkout | LOW | Strategic |

### 2.3 DEFAULT-UNIQUE findings (default flags; deep does NOT)

| # | Default finding | Status vs deep |
|---|-----------------|----------------|
| Du-1 | "Live recipe scaling UI = Missing/Partial" (D-3.2) | **DISPROVED by deep critic** — see §4 |
| Du-2 | "Cooking timer = Missing" (D-3.1, blanket) | **PARTIALLY DISPROVED by deep critic** — see §4 |
| Du-3 | Lists "HIGH = 4" in exec summary | Deep counts 6 (P1) / 8 (P2) — default appears to undercount |
| Du-4 | Treats `OCRUsageTracker` only as a strength signal ("freeMonthlyLimit named") with no enforcement gap mention | Deep flagged the persistence gap as HIGH (NEW) |
| Du-5 | No mention of subtitle char-count overrun | Deep caught it as HIGH submission blocker |
| Du-6 | Treats `subscription_tier` user property as not-yet-existing (since default doesn't surface it) | Deep flags it exists-but-frozen |
| Du-7 | Listing "$10k/mo LLM ceiling for 1k DAUs" framing | Deep echoes; minor refinement |
| Du-8 | "Cook tracking = unique" not surfaced (default lists Cook tracking as "Y" but doesn't elevate to moat) | Deep adds as Strength + SO-3 anchor |
| Du-9 | "HouseholdService" not surfaced (default lists `0 mentions`) | Deep elevates to Strategic Opportunity SO-2 |

**No default-unique CRITICAL or HIGH that survives the deep audit.** Default's strengths inventory is a near-subset of deep's; deep's commercial-mechanics layer (Pass 2) is a near-superset of default's revenue-infra layer.

---

## 3. Verification of deep-unique HIGH findings

### 3.1 iOS subtitle 31 chars (DP-5.1 / DP-7.1) — **VERIFIED**

```
$ wc -c store_assets/metadata/sv-SE/subtitle.txt
32  (= 31 chars + newline; ö is 2-byte UTF-8 multibyte)
$ cat: "Recept, veckomeny & inköpslista"
```
Character count = 31 (ö is one character; UTF-8 byte length is 32 = 31 chars + `\n`). Apple App Store Connect's iOS subtitle limit is 30 characters — confirmed via Apple's published metadata specifications. **Submission blocker stands.** Pass 2 critic independently re-verified this in §A V5.

### 3.2 `OCRUsageTracker` in-memory (DP-2.1 / EM-7) — **VERIFIED WITH CORRECTION**

Deep Pass 1 claim: "Zero persistence. No Firestore writes, no SharedPreferences, no Drift."
Deep Pass 2 critic: "`recordUsage()` only mutates `_dailyRequestCount` / `_monthlyRequestCount` / `_providerUsage` — zero Firestore / SharedPreferences / Drift writes anywhere in the 124-LOC file."

**This is overstated.** Live read of `lib/services/ocr/ocr_usage_tracker.dart`:
- File header comment (lines 8–9): *"Only the daily count is persisted — monthly is in-memory because persisting it meaningfully would require a list and the user-facing 'X calls left today' only needs the day."*
- `_prefDailyCountKey` + `_prefDailyDateKey` (lines 11–12) — SharedPreferences keys.
- `loadFromPersistence()` (lines 47–63) — restores daily count from SharedPreferences.
- `_persistDaily()` (lines 73–82) — writes daily count + date back on every `recordUsage()` call.
- `recordUsage()` (line 110) — calls `_persistDaily()`.

**Corrected finding:** The DAILY counter IS persisted (SharedPreferences). The MONTHLY counter and provider-usage map are NOT. Force-quit resets monthly + provider-usage; daily survives.

**Net impact on deep's argument:** The "force-quit bypasses 500/month free OCR limit" claim still holds for the monthly limit (which is the named limit `freeMonthlyLimit = 500` at `:31`). But the framing "zero persistence" is incorrect — daily IS persisted. The Pass 2 critic's V1 verdict "CONFIRMED" is itself partially wrong (critic also missed the SharedPreferences wiring — the critic's own re-grep should have surfaced lines 47–82).

**Recommended master-document framing:** "Monthly OCR counter is in-memory; daily counter is persisted via SharedPreferences. Any freemium model pricing OCR per-month would be bypassed by force-quit. Per-day enforcement survives restart." Effort estimate (1 day to migrate to Firestore mirror of `ImportRateLimiter`) remains correct.

Pass 2 critic also added independent verification (V8): server-side `functions/src/middleware/rate_limiter.ts` enforces only per-minute token-bucket (5 tokens, 2/min refill) on `ocrRecipeImage`, NOT a monthly cap. **Server has no 500/month enforcement at all** — strengthens the gap claim regardless of client-side persistence.

### 3.3 `subscription_tier` analytics property frozen at `'free'` (DP-1.4 / EM-11) — **VERIFIED**

Live verification:
- `lib/services/analytics/user_property_bootstrap.dart:36-44`: `emitAtSessionStart({..., String subscriptionTier = 'free'})` — default literal `'free'`.
- `:54`: `emitSubscriptionTier(subscriptionTier)` — emitted every session-start with whatever was passed.
- `:62-67`: `emitSubscriptionTier(String tier)` exists, `_safe`-wrapped to `analyticsService.setUserProperty`.
- `lib/main.dart:823-828`: only production caller of `emitAtSessionStart`. The call passes `locale`, `profile`, `lastCookAt: null`, `cooksLast14Days: 0` — **does NOT pass `subscriptionTier:`** → falls through to default `'free'`.
- Pass 2 critic also confirmed: `grep emitSubscriptionTier` across `lib/` returns only the bootstrap-internal callsite; no business-event re-emit anywhere.

**Verdict:** Until a business event (purchase, downgrade, trial-start) re-emits via `emitSubscriptionTier('pro')`, BigQuery cohorts will read `'free'` for 100% of users for 100% of eternity. The dimension is **wired-but-frozen**.

The header doc-comment at lines 21–24 explicitly acknowledges: *"During beta everyone is `'free'` — wired in now so the post-beta paid-cohort slice has data from day 1, not from the day the property is first set."* — i.e., this is an intentional pre-wiring per BUT-636/637/639. Whether it constitutes a "frozen-and-broken" gap depends on interpretation: if treated as cohort-bootstrap (pass-through is fine until paid SKU exists), it is working as designed. If treated as conversion-funnel-ready (re-emit hook needed before any paid event can be cohorted), the deep finding stands.

**Recommended master framing:** "Wired correctly for cohort pre-stamping, but no re-emit pathway exists from any business event. When the first paid SKU ships, EM-11 (the re-emit wire-up) is a 30-min change but easy to forget."

### 3.4 Zero screenshots on disk (DP-5.4) — **VERIFIED**

```
$ ls store_assets/screenshots/
README.md
```
Only the README. No PNGs, no per-locale subdirs with assets. Submission blocker when (if) submission day arrives. Per-locale × per-device-size production estimate (1–2 days asset work) is reasonable but not code-verifiable.

### 3.5 `HouseholdService` as Family-Plan substrate (SO-2 / U7) — **VERIFIED**

Live verification of `lib/services/household_service.dart` (101 LOC):
- `:23-31` `getHousehold()` — `firstWhere((c) => c.isHousehold)`.
- `:34` `bool get hasHousehold`.
- `:37-44` `getHouseholdMemberIds()` returns `household.allMemberIds`.
- `:59` further uses `getHouseholdMemberIds()` for allergen aggregation.

The mapping "household-marked group's owner has `subscriptionTier='family'` → all `allMemberIds` inherit entitlement" is a **strategic claim** built on top of verified substrate. The substrate is real; the entitlement-inheritance UX is design-debt (deep Pass 1 correctly notes this in self-critique: *"actual UX integration may surface friction (who pays vs who's invited; what about household-of-one)"*).

### 3.6 Live recipe scaling exists (U12 — sister falsification) — **VERIFIED**

```
$ ls lib/widgets/common/input/portion_scaler*
portion_scaler.dart
portion_scaler_logic.dart
portion_scaler_ui.dart
```
All 3 files exist. Deep cites `recipe_detail_content.dart:577-578` and `:23 List<String> scaledIngredients` (not re-read in this consensus pass; deep's own line refs verified by Pass 2 critic V6 with multiple call sites including `cooking_mode_view.dart:259,261,317`, `recipe_detail_view.dart:614`, `recipe_detail_tablet_content.dart:116`).

**Verdict:** Default's "Partial / Missing live scaling UI" claim (D-3.2) is **wrong**. Sister downgrade was incorrect. Master should drop this from the table-stakes-gap list.

### 3.7 Step timer infrastructure exists (U13 — sister partial-falsification) — **VERIFIED**

```
$ ls lib/services/cooking/
step_timer_service.dart
substitution_suggestion_service.dart
```
The infra exists. Deep's framing ("infra-yes, auto-extract-from-instruction-text-no") is the accurate refinement of default's "Missing".

**Verdict:** Default's "Cooking timer = Missing" (D-3.1) is **partially wrong**. The right finding is: regex extraction of "12 min" / "15 minuter" / "tre minuter" from instruction text → tappable timer trigger does not exist; the timer service backing it does.

---

## 4. Sister-claims disproved by deep critic

| # | Default claim | Deep correction | Verification |
|---|---------------|-----------------|--------------|
| F1 | "Live recipe scaling UI = Missing / Partial" (D-3.2) | Live scaling exists via `portion_scaler{,_logic,_ui}.dart` + `recipe_detail_content.dart:577-578` | **VERIFIED** in §3.6 |
| F2 | "Cooking timer = Missing" (D-3.1, blanket) | Timer service exists (`step_timer_service.dart`); auto-extract from instruction text is what's missing | **VERIFIED** in §3.7 |
| F3 | OCR tracker mentioned only as strength signal (no enforcement-gap flag) | OCR tracker monthly counter is in-memory → freemium bypass via force-quit | **VERIFIED with correction** in §3.2 (daily IS persisted; monthly is not) |
| F4 | `subscription_tier` not surfaced as wired | Wired but frozen at `'free'` — no business-event re-emit | **VERIFIED** in §3.3 |
| F5 | iOS subtitle char-count not flagged | 31 chars > 30-char Apple limit — submission blocker | **VERIFIED** in §3.1 |
| F6 | `HouseholdService` not surfaced as Family-Plan substrate | Strategic monetization opportunity SO-2 | **VERIFIED** substrate; SO-2 is strategic hypothesis (§3.5) |
| F7 | "8–9 separate import entry-points" listed but not as strategic compounding-cost | Cross-references UX prompt 06 as material UX cost | TWO-WAY (default also flags) — minor framing only |
| F8 | "$10/mo LLM ceiling" framed as user cost only | Reframed as price-floor math (Pass 2 C4): break-even subscription ≈ $12–14/mo | Pass 2 critic addition; strategic framing |

**No reverse direction:** Default does not catch anything that deep critic missed. Default is a near-strict subset of deep.

---

## 5. Strategic vs code-fact reliability tagging

Per the user's instruction (strategic bedömningar är inneboende osäkrare). Tagging by category:

### 5.1 Code facts (high confidence — verifiable)
- All `pubspec.yaml` dep absences (no `in_app_purchase`, no `purchases_flutter`, etc.) ✓
- `subscriptionTier` field absence on `UserProfile` ✓
- `OCRUsageTracker` persistence behavior (daily yes, monthly no) ✓
- Subtitle char-count overrun ✓
- `subscription_tier` analytics property frozen ✓
- Zero screenshots on disk ✓
- Zero `paywall/` dir under `lib/widgets/` or `lib/views/` ✓
- 16 callsites of `ImportRateLimits.x` in 1 file ✓
- `HouseholdService` exists with `isHousehold` + `allMemberIds` ✓
- `step_timer_service.dart` exists ✓
- `portion_scaler{,_logic,_ui}.dart` exist ✓
- AndroidManifest has no BILLING permission ✓
- Pass 2 critic's V1–V8 verifications ✓ (with the §3.2 correction noted)

### 5.2 Strategic claims (lower confidence — hypothesis territory)
- "RevenueCat is the obvious choice for indie shop" — defensible default but other vendors (Glassfy, Qonversion, Adapty) are equivalent.
- All SO-1..SO-8 strategic monetization opportunities — hypothesis.
- "$0.99 / 20 imports is the cheapest experiment" (SO-1) — anchoring on USD; Pass 2 B8 corrects to Swedish-anchored pricing.
- "Family Plan via HouseholdService is killer app" (SO-2) — substrate verified; UX integration is design-debt.
- "Wrapped recap is highest-converting subscription anchor" (SO-3) — Spotify analogy; not measured for food apps.
- All competitor-matrix cells (Yummly / BigOven / Paprika / Crouton / Mela / ICA / Tasteline / Eaty) — point-in-time, no live verification.
- "Swedish white-space for AI/import-first players" — depends on incumbents not pivoting.
- All Pass 2 commercial-mechanics findings (B1–B10, C1–C5) — strategic/commercial/regulatory facts (most are widely-published Apple/Google/EU rules) but their *effort estimates* and *fit-for-Butlery* are hypothesis.
- Break-even price floor "$12–14/mo for unlimited AI" (C4) — math is sound given inputs, but the inputs (LLM cost ceiling, RevenueCat fee, 15% Apple) are point-in-time.

### 5.3 Cross-reference dependencies
- Prompt 02 (firestore.rules) — owns `subscriptionTier` write-protection.
- Prompt 04 (perf) — owns LLM cost / latency.
- Prompt 06 (UX) — owns App Store Readiness sub-score (Wave-2 deep: 6/12). Subtitle char-count was caught at MEDIUM in 06; deep monetization elevated to HIGH given submission-blocker semantics.
- Prompt 07 (AI/LLM) — flagged `OCRUsageTracker` in-memory weakness as D5-LOW-1 in deep run (per Pass 2 critic V2 reconciliation). Sister 10-monetization missed it; sister 07 caught it.
- Prompt 08 (analytics) — owns conversion-funnel events.
- Prompt 09 (privacy/trust) — owns privacy manifest (will need update when payment SDKs added).
- Prompt 11 (legal) — owns subscription terms; Pass 2 B7 (EU 14-day cooling-off) cross-refs here.
- Prompt 12 (doc drift) — owns `STORE_SUBMISSION_CHECKLIST.md`, `play-data-safety-runbook.md`.

---

## 6. Score reconciliation — recommended master-document score

| Dimension | Default | Deep P1 | Deep P2 | Master rec. | Notes |
|-----------|--------:|--------:|--------:|------------:|-------|
| 1. Entitlement Architecture Readiness (/20) | 12.0 | 11.5 | 11.0 | **11.0** | Deep P2's restore-flow gap (B3) is real |
| 2. Schema Extensibility (/15) | 11.0 | 11.5 | 11.5 | **11.5** | Deep P1 = P2 agree |
| 3. Feature Completeness vs Table-Stakes (/20) | 14.5 | 14.0 | 14.0 | **14.0** | Deep correctly downgrades for offline web/desktop |
| 4. Differentiation (/15) | 13.0 | 13.0 | 13.5 | **13.0–13.5** | P2's web-Stripe upside is small; either is defensible |
| 5. App Store Submission Risk (/15) | 10.0 | 9.5 | 9.0 | **9.0** | P2's EU cooling-off + account-deletion-↔-sub interaction added |
| 6. Revenue Infrastructure Prerequisites (/10) | 6.5 | 6.0 | 4.5 | **4.5–6.0** | P2 commercial-mechanics blind-spot is the largest single adjustment |
| 7. Market Positioning & ASO (/5) | 3.0 | 2.5 | 2.0 | **2.0** | Subtitle blocker + Swedish-anchored pricing miss |
| **Total (/100)** | **70.0** | **68.0** | **65.5** | **~65.5** | Deep P2 critic-adjusted score |

The **default's 70/100 over-weights** the substrate strengths (`ImportRateLimiter`, `FeatureFlagService`) without subtracting for the commercial-mechanics layer or for the in-memory OCR persistence gap. The **deep P2 65.5/100 is more defensible**.

The actionable fix for §6 (Revenue Infrastructure 4.5–6.0) is large but mostly "wire stuff that doesn't exist yet" — the score gap reflects ~3-4 weeks of work (RevenueCat + paywall UI + receipt webhook + refund handling + restore flow + free-trial eligibility + grace period + price-floor analysis), not "things broken today."

---

## 7. Recommended issue counts for master document

| Severity | Default | Deep P1 | Deep P2 | Master recommendation |
|----------|--------:|--------:|--------:|----------------------:|
| CRITICAL | 0 | 0 | 0 | **0** |
| HIGH | 4 (per exec) / ~11 (per body) | 6 (per exec) / ~12 (per body) | 8 (P1+B1+B3) | **6–8 unique** (HIGH) |
| MEDIUM | 7 | 11 | 17 | **~14–17** |
| LOW | 6 | 8 | 11 | **~9–11** |
| Strategic monetization opportunities (SO) | n/a | 8 | 8 | **8 (SO-1 through SO-8)** |
| What's missing — entitlement infrastructure (EM) | n/a | 12 | 12 | **12 (EM-1 through EM-12)** |
| Pass 2 critic blind-spot adds (B/C series) | n/a | n/a | 10 (B) + 5 (C) | **10–15 commercial-mechanics findings** |

---

## 8. Quick-wins reconciliation (≤1 day)

Both runs converge on a tight set; deep adds 3.

| # | Quick win | Effort | Default | Deep | Master |
|---|-----------|-------:|:-------:|:----:|:------:|
| 1 | Replace iOS subtitle (`subtitle.txt`) — fix 31-char overrun + lead with AI | 1 min | — | Y | **Y (CRITICAL-equivalent)** |
| 2 | Lead `description.txt` with AI/OCR/social-import (currently buried) | 1 h | Y | Y | **Y** |
| 3 | Add 8 conversion-funnel analytics event constants as no-ops | 2 h | Y (6 events) | Y (8 events) | **Y (8 events)** |
| 4 | Add `subscriptionTier`-shaped placeholder field on `UserProfile` (nullable) | 4 h | Y | Y | **Y** |
| 5 | Migrate OCR monthly counter to Firestore (mirror of `ImportRateLimiter`) | 1 d | — | Y | **Y** |
| 6 | Tighten `InAppReviewService` minDays 90 → 100 (Apple cap safety margin) | 1 line | Y | Y | **Y** |
| 7 | Add reviewer demo account doc (`reviewer-credentials.md`) | 2 h | Y | Y | **Y** |
| 8 | Document static-const → tier-aware rate-limit refactor path (1-pg spec) | 2 h | Y | Y | **Y** |
| 9 | Add `cost_estimate_usd` field on parse-event log | 4 h | Y | Y | **Y** |
| 10 | Enroll Apple Small Business Program (15% rate) | 30 min | — | Y (P2 B10) | **Y** |
| 11 | "Du gör Butlery bättre" toast after parsing correction (data-flywheel visibility) | 4 h | Y | Y | **Y** |

**Top single ROI:** Subtitle fix (#1) is one-minute work that unblocks submission AND leads with AI — combines §5.1 + §4.1 + §7.1 in deep into one keystroke.

---

## 9. Phase 2 sprint plan reconciliation

Default offers Sprint 1/2/3 + Backlog. Deep offers Sprint A/B/C/D/E + Backlog. Deep is the more granular and actionable.

**Recommended master sprint sequence (deep's, lightly amended):**

- **Sprint A (ASO + safety, 1 day):** subtitle fix + description copy + in-app-review tightening + demo account doc.
- **Sprint B (table-stakes closures, 1 sprint):** inline timer auto-extract + import-entry-point consolidation (cross-ref UX).
- **Sprint C (entitlement substrate scaffolding — no monetization decision needed yet, 1 sprint):** EM-1 (`subscriptionTier` field) + EM-7 (OCR persistence) + EM-10 (analytics constants) + EM-11 (re-emit hook stub).
- **Sprint D (forward-looking — only if monetization decision lands, 3–4 weeks):** EM-2..5 (RevenueCat + Cloud Function + rules) + EM-9 (paywall UI) + Pass-2 commercial mechanics (B1 ASBSP, B2 refund webhook, B3 restore flow, B7 EU cooling-off, B8 SEK pricing, B10 ASBSP enrollment, C1 free-trial eligibility, C2 grace period, C3 account-deletion ↔ sub).
- **Sprint E (differentiator-led growth — post-IAP, 4–6 weeks):** SO-1 (pay-per-import) → SO-2 (Family Plan via HouseholdService) → SO-3 ("Wrapped" cook recap) → SO-7 (referral loop with `acquisition_attribution`).
- **Backlog:** SO-4 (B2B grocer ads), SO-5 (Smart Cooking Companion), SO-8 (public-recipe SEO), §3.2 voice/hands-free, §3.3 manual nutrition + Livsmedelsverket fetch.

---

## 10. Key open questions (master document should flag, not answer)

1. **Monetization decision timeline:** MEMORY.md says "no monetization decisions yet" + "just build the app." This entire prompt is forward-looking. When will a decision land? Sprint C scaffolding is cheap insurance regardless; Sprint D is wasted unless decision lands within 6 months of Sprint C.
2. **Pricing model first:** subscription vs consumable vs hybrid. Pass-1 leans "pay-per-AI-import + Family Plan combo" (SO-1 + SO-2). Pass-2 critic adds "$12–14/mo break-even floor for unlimited AI" — which constrains subscription pricing if going that route.
3. **Pure-IAP vs Stripe-hybrid (Pass-2 B4):** 5–15% margin difference, but adds OSS / VAT regulatory burden (B9). Decision affects 6–12 months of work.
4. **Anonymous-auth users + restore-purchase (Pass-2 B3):** unverified whether Butlery supports anonymous Firebase Auth; if yes, restore-on-reinstall is a 1–2 day design problem, not a 30-min UI add.
5. **Web-side public-recipe rendering (SO-8 / §7.2):** depends on whether `lib/views/social/public_profile_view.dart` renders cleanly on web — not deep-verified in either run.
6. **Tasteline / Eaty / market position:** competitor-matrix cells are point-in-time. Tasteline pivot to Aller Media (deep self-critique notes) may have shifted market; not re-checked.

---

## 11. Summary one-liner

**Deep is authoritative; default is a near-strict subset.** Deep adds 3 verified code-fact corrections to default (subtitle overrun, OCR monthly persistence gap, frozen `subscription_tier` analytics property), 12 strategic monetization opportunities (SO-1..8 + EM-1..12), and a Pass 2 critic layer (10 commercial-mechanics blind spots + 5 cross-report gaps) that default's revenue-infra section never reaches. **Recommended master score: 65.5/100 (deep Pass 2 adjusted), 6–8 HIGH, 14–17 MEDIUM, 9–11 LOW, 0 CRITICAL.** All HIGHs are forward-looking — no live defects today, consistent with explicit user deferral of monetization and store submission.

---

*End consensus data file. Sources: 2 of 3 runs (Codex absent for Wave-3 Prompt 10). Authoritative source: `docs/analysis/runs/2026-05-claude-deep/10-monetization.md` (Pass 1 + Pass 2 critic). Verification spot-checks: 7 deep-unique HIGH findings re-verified live during this consensus pass; 1 (`OCRUsageTracker`) returned a partial correction (daily IS persisted via SharedPreferences; only monthly is in-memory) — recommended master framing in §3.2.*
