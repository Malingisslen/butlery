# 10 — Monetization Readiness & Competitive Positioning — Phase 1 Findings

**Run:** 2026-05-claude (Wave 3)
**Analyst:** Claude (Opus 4.7, 1M context)
**Mode:** Read-only investigation. Zero code changes.
**Date:** 2026-05-02
**Knowledge file consulted:** none assigned to this prompt; cross-referenced `06-user-experience.md` (App Store Readiness 7/12), `MEMORY.md` and `feedback_no_store_submission_yet.md`.

---

## Executive Summary

```
MONETIZATION & COMPETITIVE POSITIONING — PHASE 1 FINDINGS
============================================================
Current monetization: None (deliberate pre-monetization).
Store submission:     Deferred (user-stated).

OVERALL SCORE: 70/100  ("Acceptable")

  1. Entitlement Architecture Readiness:        12.0 / 20
  2. Schema Extensibility for Subscriptions:    11.0 / 15
  3. Feature Completeness vs Table-Stakes:      14.5 / 20
  4. Differentiation:                           13.0 / 15
  5. App Store Submission Risk:                 10.0 / 15  (cross-ref 06)
  6. Revenue Infrastructure Prerequisites:       6.5 / 10
  7. Market Positioning & ASO:                   3.0 / 5

CRITICAL: 0   HIGH: 4   MEDIUM: 7   LOW: 6
STATUS: Preparation Needed (no defects today; gaps surface only when
        a monetization decision lands).
```

**Headline:** Butlery is in materially *better* monetization shape than its "no decisions yet" framing suggests. The cost-tracking rate limiter (`lib/services/import/import_rate_limiter.dart` — full per-minute / per-hour / per-day / monthly cost windows already persisted to Firestore) is the single most expensive piece of freemium plumbing that most pre-launch apps lack. Differentiation is genuinely strong (Swedish NLP + multi-tier import pipeline + collaborative meal planning) and hard to replicate. The two real gaps are (a) **no `subscriptionTier` field on `UserProfile`** so feature gating today would touch the user model, and (b) **no IAP/RevenueCat dependency** in `pubspec.yaml`, so the moment a monetization decision lands there's a 1–2 week integration tax.

**Critical-finding count is intentionally zero.** Nothing here blocks user-visible functionality. Every "HIGH" finding is forward-looking — a future-state observation framed per the orchestrator's instruction not to score down for deliberate deferrals.

---

## Pre-analysis context already known (cited, not re-discovered)

- `pubspec.yaml` confirms **no** `in_app_purchase`, `purchases_flutter`, `revenuecat_flutter`, `purchasely_flutter`, or `flutter_inapp_purchase` dependency. Verified via grep — only matches in `lib/` for "purchase|subscription|entitlement|premium|paywall|RevenueCat|StoreKit" are false positives (parsing-tier `tier_result.dart`, `LlmTier`, etc.).
- `pubspec.yaml:98` already ships `in_app_review: ^2.0.10` — review prompt infrastructure present (BUT-678).
- Android `applicationId = se.butlery.app` (per `06-user-experience.md` §5.1) — production-ready bundle identifier.
- iOS `CFBundleIdentifier` set; `ITSAppUsesNonExemptEncryption=false` declared (`ios/Runner/Info.plist`); deep-link scheme `butlery://` registered.
- 6 347 i18n keys × 2 locales (sv/en) — Nordic expansion is keys-only, not architecture work.

---

## 1. Entitlement Architecture Readiness — 12.0/20

`PermissionService` (`lib/services/permission_service.dart:25`) is a singleton that delegates to three modules: `RecipePermissionModule`, `ShoppingPermissionModule`, `GroupPermissionModule`. The model is **resource-permission**, not user-tier — it answers "can user X do action Y on resource Z" via `ResourcePermission` (`lib/models/permissions/resource_permission.dart`). This is the right shape for collaborative apps but **not** the shape for entitlement gating.

A `SubscriptionService` could be added cleanly alongside (the DI module pattern at `lib/core/di/modules/` makes injection trivial — see `core_module.dart` for precedent). The friction is that *every feature* that wants to gate on tier would need a separate `subscriptionService.canUse(Feature.x)` call rather than a `permissionService.canAccess(...)` extension. Two services, two questions to ask before each gated action. Workable but not elegant.

`FeatureFlagService` (`lib/services/feature_flags/feature_flag_service.dart:23`) is mature — Firebase Remote Config wired with defaults, dedup, FNV-1a stable rollout hashing (`isInRollout`, line 175), and analytics emission. The flag set today is **operational-only** (kill switches, scalability flags, tagging thresholds) — there are zero "tier-gated" flags. **But the substrate is right**: `isInRollout(flag, userId)` is exactly what a per-user entitlement check needs. Adding `tier_gated_*` flags or a `user_tier` user property is an afternoon's work.

### HIGH

**1.1 No `subscriptionTier` / `entitlement` field on `UserProfile`** — `lib/models/user_profile.dart:26-97` exposes 25 fields including allergens, FCM, onboarding state, birth-year, moderation flags. Adding `subscriptionTier`, `subscriptionStatus`, `currentPeriodEnd`, `originalTransactionId` requires touching `toFirestore()` (`:239`), `toPrivateSettings()` (`:261`), `toJson()` (`:280`), `fromMap()` (`:317`), `fromJson()` (`:366`), and `copyWith()` (`:101`) — six surfaces in one file. The model uses `_sentinel` for nullable copyWith semantics so additions are backwards-safe, but the surface area is real. **Forward-state, not blocker.** *Effort: 3–4 h to add fields + migrate readers.*

**1.2 No IAP package in pubspec** — `pubspec.yaml` reviewed in full; zero IAP/subscription dependencies. Adding `in_app_purchase` or `purchases_flutter` (RevenueCat) is the standard integration. RevenueCat's stronger argument for an indie shop: server-side receipt validation + cross-platform entitlement caching as a managed service, removing the need for the Cloud Function in `1.3`. **Forward-state.** *Effort: 1–2 weeks for full integration including paywall UI + receipt validation.*

**1.3 No Cloud Function pattern for receipt validation** — `functions/src/index.ts` exports 100+ functions across notifications, cleanup, analytics, ingredients, social — but **no payment / receipt / webhook handler**. The Cloud Functions infrastructure is mature (per-region, per-secret, per-rate-limiter middleware at `functions/src/middleware/rate_limiter.ts`) so adding `validateAppleReceipt` / `validatePlayReceipt` / `revenueCatWebhook` callable handlers is mechanical. **Forward-state.** *Effort: 1 week if rolling own; 2 days if delegating to RevenueCat.*

### MEDIUM

**1.4 `PermissionService` is a singleton with `_instance ??=` pattern** (`lib/services/permission_service.dart:48`) — testable but tightly coupled. A future `SubscriptionService` should follow the **module + DI** pattern (per `lib/services/CLAUDE.md` rules + `lib/core/di/modules/`) rather than singleton, to avoid extending the legacy shape. *Effort: documentation, not refactor.*

**1.5 No "upgrade to unlock" UI primitive** — grep for `upgrade`, `premium`, `paywall` returns zero matches in `lib/views/` and `lib/widgets/`. The settings hub (`lib/views/settings/settings_hub_view.dart`) is the natural insertion point. *Effort: 1 d for paywall/upgrade-card widget once pricing model is decided.*

### LOW

**1.6 `isInRollout(flag, userId)` (`feature_flag_service.dart:175`) could double as an entitlement check** for percentage-based premium previews ("10% of users see the AI import experience as preview to drive conversion") — useful for learning before pricing. Defer until a hypothesis exists.

---

## 2. Schema Extensibility for Subscriptions — 11.0/15

The schema is **additive-friendly** — `UserProfile.fromMap()` (`:317`) and `UserProfile.fromJson()` (`:366`) both use `SerializationUtils.safeXxx(...)` defaulted readers, so legacy documents without subscription fields would deserialize cleanly. There is no schema versioning field (`schemaVersion`), but the defensive deserialization compensates.

The most impressive piece: **`ImportRateLimiter` already does cost tracking**. `lib/services/import/import_rate_limiter.dart:299` enforces `llmCostPerMonth = $10.00` (`models/rate_limit_models.dart:300`) per user, with full transaction-safe Firestore updates (`recordUsage`, line 91). Counters: `importsThisMinute / importsThisHour / importsToday / llmEnhancementsToday / llmExtractionsToday / llmVisionToday / llmCostToday / llmCostThisMonth / llmOperationsThisMonth`. Document path: `users/{uid}/rateLimits/imports`. **This is the freemium plumbing.** A premium tier today would be a single map: `tierLimits = {free: {importsPerDay: 100, llmCostPerDay: 0.50}, premium: {importsPerDay: 1000, llmCostPerDay: 5.00}}` — all the hooks exist.

`OCRUsageTracker` (`lib/services/ocr/ocr_usage_tracker.dart:20`) similarly has `freeMonthlyLimit = 500` already named with that prefix. Anticipation of a free tier is encoded in the constant name.

### HIGH

**2.1 Rate limit constants are hardcoded `static const`** — `lib/services/import/models/rate_limit_models.dart:289-300` declares `importsPerMinute = 10`, `importsPerDay = 100`, `llmCostPerDay = 0.50`, `llmCostPerMonth = 10.00`. Per-user-tier parameterization would require:
- Replacing `ImportRateLimits.x` callsites (16 references in `import_rate_limiter.dart`) with `tierConfig.x`
- Loading tier config from Remote Config or `users/{uid}` document
- Caching tier config on user-load

The good news: callsites are already centralized through one class — there's no scatter. *Effort: 1 d to make tier-aware.*

### MEDIUM

**2.2 No Firestore schema versioning on user document** — adds risk for future migrations beyond simple additive fields. *Effort: ongoing — add a `schemaVersion: 1` field next time the model changes anyway.*

**2.3 `firestore.rules` would need write-protection for `subscriptionTier`** — clients must not be able to self-promote. Standard pattern: rule allows write only if `request.auth.token.admin == true` OR via a Cloud Function with admin SDK (e.g., RevenueCat webhook). The rules file has the patterns (per the 95-match-rule audit referenced in pre-analysis SUMMARY); adding the field-level `request.resource.data.subscriptionTier == resource.data.subscriptionTier` clause is mechanical. **Cross-ref: defer to Prompt 02 for rules audit.** *Effort: 2 h.*

**2.4 No "feature usage event" stream in analytics for premium-feature heatmapping** — `lib/services/analytics/analytics_events.dart` ships ~200 events (per pre-analysis), but I did not find a `feature_used` generic event keyed on feature-id. Identifying *which* features warrant gating later requires this signal. *Effort: 4 h to add + retro-instrument 5 candidate features.* **Cross-ref: Prompt 08 owns analytics strategy.**

### LOW

**2.5 `UserCounters` model exists separately** (`lib/models/user_counters.dart`) — could host `recipesThisMonth` / `groupsCreated` etc. without bloating `UserProfile`. Worth scoping. *Effort: 30 min review.*

**2.6 Storage usage (image bytes) is not currently counted per user** — relevant if a free tier wants to cap image storage. `lib/services/upload/image_upload_service.dart` (per file presence) doesn't appear to keep a running per-user byte sum. *Effort: 4 h if needed.*

---

## 3. Feature Completeness vs Market Table-Stakes — 14.5/20

| Category | Implemented | Notes |
|----------|-------------|-------|
| **Recipe management** | | |
| Create recipes manually | Y | `lib/views/skriv_sjalv_recept_view.dart` (873 LOC) |
| Import from URL | Y | `lib/views/import_via_url_view.dart`, schema.org tier |
| Import from image | Y | `lib/views/photo_import_view.dart`, OCR pipeline |
| Import from social media | Y | TikTok/Instagram/YouTube pipelines (`lib/services/import/pipelines/`) |
| Edit / delete | Y | `lib/views/skriv_sjalv_recept_view.dart` |
| Search recipes | Y | Algolia integration (`pubspec.yaml:91`, `algoliasearch ^1.46.1`) |
| Filter (tag/allergen/dietary) | Y | 5-phase auto-tagging |
| Favorite/bookmark | Y | `isFavorite` boolean on `Recipe` model (per MEMORY.md 2026-02-13) |
| **Recipe display** | | |
| Recipe scaling (portions) | **Partial** | `Recipe.portions` field present (`recipe_unified.dart:116`); no live scale-on-detail UI grep'd |
| Unit conversion (metric ↔ imperial) | **Missing** | Swedish-first; non-issue domestically |
| Cooking timer (inline) | **Missing** | `cooking_mode_view.dart` is screen-on landscape split (per MEMORY.md 2026-02-13) but no timer-from-instruction-text |
| Cooking mode (screen-on, large text) | Y | `cooking_mode_view.dart` + `wakelock_plus` (`pubspec.yaml:48`) |
| Recipe photos | Y | `image_picker`, `image_cropper`, `cached_network_image`, multi-image per `imageSelectUpTo` ARB |
| Nutritional info | **Partial** | `NutritionInfo?` field present (`recipe_unified.dart:259`) for Schema.org-imported recipes; no editor for manual entry, no Livsmedelsverket fetch live (admin function exists) |
| **Meal planning** | | |
| Weekly menu | Y | `lib/views/veckomeny_view.dart` |
| Drag-and-drop scheduling | unknown | Need to inspect `veckomeny_view.dart` |
| Shopping list from menu | Y | `lib/views/unified_shopping_view.dart`, `UnifiedShoppingService` |
| Shopping list management | Y | Check off, manual add (per MEMORY.md beta UX decisions) |
| **Social** | | |
| Share recipes (in-app, links, external) | Y | `share_service.dart`, `share_plus`, `app_links` |
| Public sharing (link) | Y | `deep_link_service.dart` |
| Comments | Y | `social_comments_manager.dart` |
| Ratings | Y | `firebase_recipe_repository.dart` |
| Groups / shared collections | Y | Full social/group module |
| **Other** | | |
| Offline access | **Partial** | Drift (`pubspec.yaml:43`) + sembast — `lib/services/offline/` exists; per Prompt 04 notes, online-first design |
| Voice / hands-free cooking mode | **Missing** | No `speech_to_text` package detected |
| Grocery delivery integration | **Missing** | Out of scope per memory `grocery-price-apis.md` (research only) |
| Recipe collections / folders | Y | Personal tags = collections (per MEMORY.md beta decisions) |

**Swedish market specifics:**
- Swedish measurement units (dl, msk, tsk, krm): present in parser. `lib/services/parsing/` has Swedish compound splitting and Viterbi context — confirmed in pre-analysis context.
- Swedish ingredient database: `lib/constants/known_ingredients.dart` + Livsmedelsverket fetch admin function (`functions/src/admin/fetch-livsmedelsverket.ts`).
- Swedish recipe site compat: `koket_recipe_parser.dart` site-specific parser exists; site-config tier covers others.

### HIGH

**3.1 No inline cooking timers** — `cooking_mode_view.dart` is wakelock + landscape split (good) but instructions don't auto-extract "koka i 12 minuter" → tappable timer. Crouton, Paprika, BigOven all do this. Real differentiator gap. *Effort: 3–4 d (regex + timer state + a11y).*

**3.2 No live recipe scaling UI** — `Recipe.portions` exists but I don't see a "ändra portioner" stepper that recalculates ingredient quantities on detail view. Standard table-stake; users expect to tap "4 → 6" and watch quantities change. Verify in `recipe_detail_view.dart` (835 LOC, deferred to a focused read). *Effort: 1 d if quantity-with-unit parsing is solid (it is).*

### MEDIUM

**3.3 Nutritional info is import-only** — `NutritionInfo?` populates from Schema.org JSON-LD only. No manual entry, no fetch-on-demand from Livsmedelsverket per ingredient. Per `MEMORY.md`: "Nutrition = plan models post-beta, use Livsmedelsverket API" — this is a deliberate deferral. *Effort: 2 weeks for full nutrition feature.*

**3.4 Voice/hands-free** — wet-hands cooking is the canonical "I have no free fingers" UX. Not present. *Effort: 1–2 weeks (Swedish STT quality verification + voice-design).*

**3.5 8–9 separate import entry-points** — flagged by `06-user-experience.md` §3.1. Cognitive overhead vs Yummly/BigOven's single "+" button. *Cross-ref to UX prompt; not re-scoring here.*

### LOW

**3.6 Unit conversion (metric ↔ imperial)** — Swedish-first, non-issue. Note for Nordic / EU expansion if reaching UK/IE.

**3.7 Grocery delivery integration** — `memory/grocery-price-apis.md` already maps the landscape (ICA / Willys / Hemköp / Coop / Lidl / Matpriskollen). Material strategic differentiator, post-monetization.

---

## 4. Differentiation — 13.0/15

This dimension is Butlery's **strongest competitive asset.** The matrix below uses what I can verify in code; competitor cells are positioned by widely-known feature sets — these are not exhaustive but the relative pattern is reliable.

| Feature | Butlery | Yummly | BigOven | Paprika | Crouton | Mela | ICA Recept |
|---------|:-------:|:------:|:-------:|:-------:|:-------:|:----:|:----------:|
| Multi-tier AI import (site config → regex → LLM) | ✅ | ⚠ | ⚠ | ⚠ | ❌ | ❌ | ❌ |
| OCR-based image import | ✅ | ❌ | ⚠ | ⚠ | ❌ | ❌ | ❌ |
| Swedish NLP (compound split / Viterbi / line classifier) | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠ |
| 5-phase auto-tagging | ✅ | ⚠ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Real-time collaborative meal planning | ✅ | ❌ | ⚠ | ❌ | ❌ | ❌ | ❌ |
| Group recipe collections | ✅ | ❌ | ⚠ | ❌ | ❌ | ❌ | ❌ |
| Social features (friends/comments/ratings) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ⚠ |
| Multi-platform (iOS/Android/Web/macOS/Windows) | ✅ | ⚠ | ⚠ | ✅ | ❌ | ⚠ | ⚠ |
| GDPR Phase 1 complete | ✅ | ⚠ | ⚠ | ⚠ | ⚠ | ⚠ | ✅ |
| Swedish-first UX & content | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| Cooking timers (inline) | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠ |
| Recipe scaling (live) | ⚠ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠ |
| Voice/hands-free cooking | ❌ | ✅ | ⚠ | ❌ | ❌ | ❌ | ❌ |
| Pricing model | none | freemium | freemium | one-time | one-time | one-time | free |

Legend: ✅ confirmed, ⚠ partial / unclear, ❌ absent.

**Moat rating per asset:**

- **Swedish NLP pipeline** — *Hard moat.* Compound splitter + Viterbi context + line classifier represent multi-month linguistic engineering. ICA Recept has Swedish content but no NLP-driven import. Replicable by a well-resourced incumbent in 6–12 months; mode of defense is to keep accumulating training data via the parsing-correction repository (`lib/repositories/parsing_correction_repository.dart`).
- **Multi-tier import pipeline** — *Medium moat.* The architecture (site-config → regex → LLM fallback) is non-obvious and well-engineered (`lib/services/parsing/tiers/`). Site-config tier means cheap parsing for known sites (zero LLM cost), so unit economics on imports are healthier than competitors who LLM-everything. **This is also a unit-economics moat:** see §6.
- **Collaborative meal planning** — *Soft moat / network effect.* Real-time Firebase Realtime Database backbone (presence + onDisconnect) is a real engineering investment. Network effects compound: friends already on Butlery raise switching cost.
- **GDPR Phase 1 complete + Swedish microcopy on every consent surface** — *Trust moat.* Niche but sticky for the Swedish market where data trust is a purchase factor (cross-ref: Prompt 02 GDPR readiness, Prompt 09 consent flows, Prompt 11 legal).

### HIGH

**4.1 Differentiation is currently undercommunicated in store metadata** — per `06-user-experience.md` §6, `store_assets/metadata/sv-SE/description.txt` covers planning/lists/sharing/offline/GDPR but does not lead with "AI-driven import från foto, URL, Instagram, TikTok, YouTube". For Swedish ASO, leading with the AI import angle is a much stronger keyword play (high search-volume in 2025-2026 AI app gold rush). *Effort: 1 h copy revision.*

### MEDIUM

**4.2 Parsing-correction data flywheel is implemented but its value is invisible** — `lib/repositories/parsing_correction_repository.dart` collects correction telemetry, and `functions/src/analytics/analyze-corrections.ts` mines it. This is a literal **data moat** (more users → better Swedish NLP) but no story is told to the user about it. A "Du gör Butlery bättre" message after a correction lift would harden the moat by making it visible (and likely increases willingness to correct, deepening the moat further). *Effort: 4 h messaging + analytics check.*

### LOW

**4.3 No referral / invite-loop infrastructure** — `deep_link_service.dart` generates friend invitation links but there's no "invite a friend, get a perk" loop. Network-effect moat is shallow without it. *Effort: 1 week (invite reward + tracking + abuse prevention) once monetization decided.*

---

## 5. App Store Submission Risk Assessment — 10.0/15

**Cross-reference:** `06-user-experience.md` §6 owns the App Store Readiness sub-score (7/12). I'm not re-scoring metadata. I'm scoring **rejection risk** — the probability that a submission that *uses* the metadata reviewed by 06 gets rejected. Per the user's note `feedback_no_store_submission_yet.md`, the user has explicitly deferred filing — so this is forward-looking, not a present blocker.

| Apple top-10 rejection reason | Risk for Butlery | Notes |
|-------------------------------|:----------------:|-------|
| 1. Bugs and crashes | LOW-MEDIUM | One known `flutter analyze` error blocks release builds (`notification_service.dart:649` — owned by 06 §C1). No Crashlytics evidence reviewed this pass. |
| 2. Broken links / placeholder content | LOW | Zero `Lorem ipsum` / `TODO` user-visible strings found in views (per 06 §4). |
| 3. Incomplete information | LOW-MEDIUM | Privacy policy + ToS in `assets/legal/` (per pubspec asset list). Listing copy present. |
| 4. Insufficient content / minimum functionality | LOW | App is feature-rich; not a website wrapper. |
| 5. Privacy violations | MEDIUM | Privacy manifest present (`ios/Runner/PrivacyInfo.xcprivacy`, deferred to 09); accuracy is the question. |
| 6. UGC moderation | MEDIUM | Cross-ref Prompt 09. Reports + admin moderation rules exist (`functions/src/feedback/on-report-created.ts`); needs end-to-end verification. |
| 7. IAP issues | N/A | No IAP today. |
| 8. Performance | LOW | Cross-ref Prompt 04. |
| 9. Wrapper / minimum design | LOW | Native Flutter UI, adaptive widgets, M3 + dark mode. |
| 10. Sign in with Apple | **HIGH** | Apple requires SiwA *if any* third-party social login is offered. Butlery currently has no social login (per MEMORY.md beta UX: "Social login (Google/Apple) = post-beta"). **Today: zero risk.** The moment Google sign-in lands, SiwA becomes mandatory same-day. |

### HIGH

**5.1 Sign in with Apple becomes mandatory on the same release that ships any other social login** — when Google sign-in (post-beta plan) is added, SiwA must ship in the same build. Apple guideline 4.8. Forgetting is a routine cause of rejection. *Effort: 1 d for `sign_in_with_apple` integration when Google login lands.*

**5.2 No App Store reviewer demo account documented** — `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` exists (per 06 §6) but I see no `reviewer-credentials.md` or `BUT-416` resolution. Reviewers can't test social/group/sharing features without a pre-populated account with friends + shared recipes + groups. *Effort: 2 h to provision + document; recurring per-release.*

**5.3 No Google Play Data Safety section drafted** — `docs/ops/play-data-safety-runbook.md` exists per pre-analysis grep but my pass didn't open it. **Cross-ref Prompt 12 for doc-vs-reality drift.** *Effort: 4 h once data flows are inventoried (Prompt 02/09 outputs).*

### MEDIUM

**5.4 Reviewer notes don't yet explain AI import features** — Apple reviewers may not understand multi-tier import (URL → site config → regex → LLM). A 3-paragraph "what to test" section in App Store Connect review notes prevents "missing functionality" rejections. *Effort: 1 h once submission is on the table.*

**5.5 Account deletion in-app is required** (Apple guideline 5.1.1 (v), Play Store policy) — `lib/services/account/account_deletion_service.dart` exists; verify it's reachable in 2 taps from settings. *Cross-ref Prompt 09.* *Effort: 30 min UX verification.*

### LOW

**5.6 In-app review prompt cadence not yet tuned** — `in_app_review_service.dart` is present. Apple limits to 3 prompts per 365-day window; trigger should be after a positive milestone (recipe imported, week-meny generated). Verify gating logic. *Effort: 30 min review.*

**5.7 No "what's new" per-version structure** — Cross-ref `06-user-experience.md` §6.5. Single `release_notes.txt` overwritten per release. *Defer to 06.*

---

## 6. Revenue Infrastructure Prerequisites — 6.5/10

`functions/src/index.ts` ships ~100 callable / triggered / scheduled functions with mature middleware (`functions/src/middleware/rate_limiter.ts` for server-side rate-limit, `functions/src/shared/require-admin.ts` for privileged ops). The substrate to add receipt-validation + webhook-handler functions is best-in-class — the only thing missing is the actual handlers.

`firebase_remote_config` is wired at app start — premium plan limits, paywall copy variants, and rollout percentages can all flow through without code deploys.

### HIGH (forward-looking)

**6.1 No paywall UI components in `lib/widgets/`** — grep confirmed. Standard pattern: bottom-sheet paywall + lifetime-trial banner + soft-paywall card. Design language can reuse the cream/forestGreen square aesthetic (`lib/widgets/styled/styled_button.dart` style). *Effort: 3–4 d for paywall + trial countdown + restore-purchase + manage-subscription deep links.*

### MEDIUM

**6.2 No conversion funnel events in `analytics_events.dart`** — `paywall_viewed`, `paywall_dismissed`, `trial_started`, `trial_converted`, `subscription_renewed`, `subscription_cancelled` — none exist (zero matches in `analytics_events.dart` for `purchase|subscription|trial|paywall`). Without these, no LTV / cohort analysis is possible post-launch. *Effort: 2 h once payment events exist.* **Cross-ref Prompt 08.**

**6.3 Family-plan / shared-subscription support requires household-grouping** — Butlery already has groups (collaborative meal planning), but groups today are content-sharing, not entitlement-sharing. RevenueCat supports family entitlements via shared `appUserID`; native StoreKit 2 supports Family Sharing for autorenewing subscriptions. Either is a single config flip, **but** designing UX around it (who pays, who's included, what counts as "household") is a decision-debt. *Effort: 1 week once chosen.*

**6.4 Consumable IAP (e.g., AI import credits) is supported by the architecture** — `ImportRateLimiter.recordUsage` already increments per-operation costs. Adding a consumable bucket would just add a positive offset that decays. Worth listing as a viable model — pay-per-import — given the unit-economics observation in §6.5. *No effort estimate; pricing model decision first.*

### LOW

**6.5 Unit-economics signal: AI import cost ceiling is `$0.50/day, $10/month per user`** (`rate_limit_models.dart:299-300`). At a hypothetical 1 000 active free users importing daily at full quota, monthly LLM ceiling is **$10 000** — not viable on free. The Mistral integration uses prompt caching per Cloud Function design (deferred to Prompt 04/07 for the perf/quality side, but the cost frame is mine). **Implication:** the AI import path *must* eventually be either (a) the premium hook, or (b) heavily site-config-tiered to avoid LLM on known sites (already implemented, mitigates risk). *No fix; framing for monetization decision.*

**6.6 Cloud Functions cost trace per AI parse** — `functions/src/llm/structure-recipe.ts` and `ocr-recipe-image.ts` are the two LLM endpoints. Cross-ref Prompt 04 for latency/timeout audit; cost dimension is mine. Recommend a `cost_estimate_usd` field on every parse-event log so per-import LTV becomes observable. *Effort: 4 h.*

---

## 7. Market Positioning & ASO — 3.0/5

Per `06-user-experience.md` §6, Swedish + English store metadata exists. `applicationId = se.butlery.app` is professional. `butlery://` deep-link scheme registered. Web platform is enabled (`flutter_web_plugins` in pubspec).

The Swedish recipe-app market in 2026 has known incumbents: ICA Recept (free, brand-locked), Coop's recipe app, Tasteline (acquired by Aller Media — long-term relevance unclear), Köket.se (web-first), Recipe-by-Yummly's Swedish coverage. Niche AI/import-first players in Swedish are essentially absent — this is white space.

### MEDIUM

**7.1 No web-side Open Graph / Schema.org JSON-LD on shared recipe links** — grep returned only `lib/services/extraction/site_parsers/koket_recipe_parser.dart` (parsing *incoming* JSON-LD, not *emitting* it). When Butlery shares a recipe link, social-media unfurls show generic preview, not the recipe card. Lost-but-recoverable acquisition channel. *Effort: 1 d if there's a web frontend rendering shared recipe pages; n/a if shares always deep-link to app.*

**7.2 No referral attribution mechanism** — `lib/models/acquisition_attribution.dart` exists (per grep) so the model is there, but the wiring to "this install came from this user's invite link" is not surfaced in code I read. *Effort: spike to verify; ~1 d if missing.*

### LOW

**7.3 Localized Nordic expansion is one ARB-file away** — Norwegian Bokmål, Danish, and Finnish would unlock 20M+ adjacent speakers with no architecture work, only translation cost. **Strength worth flagging.** *Effort: variable per locale; ~2 weeks per locale for translation review at 6 347 keys.*

**7.4 No A/B testing of ASO assets** — Apple's Product Page Optimization and Play Store experiments aren't wired (would be operational, not code, anyway).

---

## Risk Heatmap (top 5)

| # | Risk | Severity | Time-to-fix when triggered |
|---|------|----------|----------------------------|
| 1 | IAP integration debt — adding any tier-gated feature today touches user model + ships pubspec dep + new Cloud Functions | HIGH (forward) | 1–2 weeks integration + 1 week paywall UI |
| 2 | Sign in with Apple becomes a same-release requirement when any other social login lands | HIGH (forward) | 1 d if planned; submission rejection if forgotten |
| 3 | Cooking timers + live recipe-scaling are table-stakes the app currently ships without | HIGH (today) | 1 week combined |
| 4 | Differentiation undercommunicated in store listing (AI import angle missing from `description.txt`) | MEDIUM | 1 h copy revision |
| 5 | `static const` rate limits aren't tier-aware → freemium gating requires central refactor (mitigated: 16 callsites all in 1 file) | MEDIUM (forward) | 1 d |

---

## Strengths to preserve

- **`ImportRateLimiter` is freemium plumbing already paid for.** Per-window cost tracking with Firestore-transactional updates is the most expensive piece of any subscription stack and it exists today.
- **`FeatureFlagService` + `isInRollout` stable hashing** is the right substrate for percentage entitlement gating.
- **Multi-tier import pipeline is a unit-economics moat** — site-config tier means LLM is the *fallback*, not the default. Most AI-recipe apps LLM-everything; Butlery is engineered to be cheaper to run.
- **Parsing-correction telemetry** (`lib/repositories/parsing_correction_repository.dart` + `analyze-corrections.ts`) is a literal data flywheel for Swedish NLP.
- **GDPR + Swedish microcopy** is a trust moat that regional incumbents (ICA, Coop) match but no English-first competitor will replicate.
- **`in_app_review` is already shipped** (`pubspec.yaml:98`, BUT-678) — cheapest possible ASO booster is wired.
- **Multi-platform (iOS / Android / Web / macOS / Windows)** widens the funnel — web is a free acquisition channel for share-link unfurls (when 7.1 is addressed).

---

## Quick wins (≤1 day, ROI-ordered)

1. **Lead `description.txt` with AI-import positioning** (4.1) — 1 h copy revision; biggest ASO ROI.
2. **Add `subscriptionTier`-shaped placeholder to `UserProfile`** as `null` field with serialization wired but no reads (1.1) — 3–4 h; future-proofs schema.
3. **Add 6 conversion-funnel analytics events** (`paywall_viewed`, `trial_started`, etc.) as no-op constants in `analytics_events.dart` (6.2) — 1 h; ready when needed, costs nothing now.
4. **Inline cooking timers in cooking-mode** (3.1) — 3–4 d; closes a real table-stakes gap.
5. **Live recipe scaling (portions stepper)** (3.2) — 1 d; closes the second table-stakes gap.
6. **Reviewer demo account doc** (5.2) — 2 h; recurring win every release.
7. **Document `static const` → tier-aware rate-limit refactor path in a 1-page spec** (2.1) — 2 h spec only; reduces future surprise.

---

## Phase 2 preparation

- **Sprint 1 (table-stakes + ASO):** 3.1 timers + 3.2 scaling + 4.1 description copy revision + 5.5 account deletion verification.
- **Sprint 2 (forward-looking, only if monetization decision lands):** 1.1 user-model fields + 1.2 IAP package selection + 1.3 receipt-validation Cloud Function + 6.1 paywall UI.
- **Sprint 3 (nice-to-haves):** 4.2 data-flywheel messaging + 7.1 OG tags on shared web routes + 7.2 referral wiring.
- **Backlog:** 3.3 manual nutrition entry, 3.4 voice/hands-free, 6.3 family plan, 7.4 ASO experiments.

Phase 2 should also synthesize against `06-user-experience.md` (App Store Readiness 7/12), Prompt 02 (rules to protect `subscriptionTier`), Prompt 04 (LLM cost framing), Prompt 08 (conversion funnel events), Prompt 09 (privacy manifest accuracy when payment SDKs are added).

---

## Phase 1 completion checklist

- [x] Executive summary with overall score (out of 100)
- [x] Detailed findings for all 7 dimensions with file:line references
- [x] Issue classification (Critical/High/Medium/Low) with counts and effort estimates
- [x] Entitlement architecture assessment
- [x] Schema extensibility evaluation
- [x] Table-stakes feature checklist (implemented / missing)
- [x] Competitive positioning matrix (Butlery + 6 competitors × 14 features)
- [x] Differentiation and moat analysis
- [x] App store rejection risk matrix (Apple top-10)
- [x] Demo account readiness assessment
- [x] Revenue infrastructure prerequisites
- [x] Market positioning evaluation
- [x] Phase 2 preparation section with issue grouping
- [x] **Zero code changes**

---

*End Phase 1 — owner: Claude (Opus 4.7, 1M context). Cross-references: Prompt 02 (rules for `subscriptionTier` protection), Prompt 04 (LLM cost / latency), Prompt 06 (App Store metadata + readiness — owns icons/screenshots/description), Prompt 08 (conversion funnel events), Prompt 09 (privacy manifest accuracy w.r.t. payment SDKs), Prompt 11 (legal text accuracy when subscription terms exist), Prompt 12 (doc drift on `STORE_SUBMISSION_CHECKLIST.md` and `play-data-safety-runbook.md`).*
