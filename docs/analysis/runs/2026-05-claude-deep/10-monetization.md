# 10 — Monetization Readiness & Competitive Positioning — Pass 1 (deep run)

**Run:** `2026-05-claude-deep` (Wave 3)
**Pass:** 1 of 1 (this prompt is strategic — single deep pass; no Pass-2 critic scheduled per Wave-3 plan)
**Investigator:** Claude (Opus 4.7, 1M context) acting as `monetization-strategist` (no specialist agent assigned for this prompt → general-purpose investigator).
**Date:** 2026-05-03
**Knowledge files consulted:** none assigned. Cross-referenced Wave-2 deep `06-user-experience.md`, sister `2026-05-claude/10-monetization.md` (default-Claude pass), `MEMORY.md` (Beta UX 2026-02-13, Strategic Feature Analysis pointer), `feedback_no_store_submission_yet.md`.

---

## Executive Summary

```
BUTLERY MONETIZATION & COMPETITIVE POSITIONING - PHASE 1 FINDINGS (deep pass)
=============================================================================
Current monetization: None (deliberate pre-monetization, per CLAUDE.md + memory).
Store submission:     Deferred indefinitely (per memory/feedback_no_store_submission_yet.md).
Beta-UX scope:        No discovery dashboard; friends/sharing/comments/groups only.

OVERALL SCORE: 68 / 100  ("Acceptable, with hidden strengths and one underweighted blind spot")

  1. Entitlement Architecture Readiness:        11.5 / 20  (vs sister 12.0 — sister overcounts substrate)
  2. Schema Extensibility for Subscriptions:    11.5 / 15  (vs sister 11.0 — agreement)
  3. Feature Completeness vs Table-Stakes:      14.0 / 20  (vs sister 14.5 — minor downgrade for offline)
  4. Differentiation:                           13.0 / 15  (agreement with sister)
  5. App Store Submission Risk:                  9.5 / 15  (cross-ref 06; SiwA risk + demo-account gap)
  6. Revenue Infrastructure Prerequisites:       6.0 / 10  (vs sister 6.5 — small downgrade for OCR tracker in-memory)
  7. Market Positioning & ASO:                   2.5 / 5   (vs sister 3.0 — `description.txt` undersells AI; one-byte-overrun subtitle blocks submission)

CRITICAL: 0   HIGH: 6   MEDIUM: 11   LOW: 8
What's missing (entitlement infra): 12 (~30% of report by section weight)
Strategic monetization opportunities: 8

STATUS: Preparation Needed — no live defects, but entitlement infrastructure is
        absent enough that the first paid release is a 3-4 week project, not
        a one-sprint integration.

TOP 5 MONETIZATION & COMPETITIVE RISKS:
1. The `_subscriptionTier='free'` analytics user-property is wired but every
   downstream consumer assumes it never changes — when paid cohorts ship,
   the bootstrap path (`user_property_bootstrap.dart:37,54`) needs a
   re-emit hook that doesn't exist.
2. `OCRUsageTracker` is **in-memory only** (`lib/services/ocr/ocr_usage_tracker.dart:8-17`)
   — the 500/month "free limit" resets on app restart. Any freemium model
   pricing OCR would be trivially bypassed by force-quit. Sister report
   missed this.
3. iOS subtitle = 31 chars > 30-char Apple limit (`store_assets/metadata/sv-SE/subtitle.txt`)
   is a hard submission blocker. Sister missed it; 06-user-experience caught it
   but flagged MED — it's actually CRITICAL when submission day arrives.
4. Sign in with Apple ships zero-day with any other social login (Apple §4.8).
   No `sign_in_with_apple` package in `pubspec.yaml`.
5. Recipe-count cap, image-storage cap, friend-count cap, group-count cap
   — none of the obvious freemium dimensions has a counter today.
   `UserCounters` (`lib/models/user_counters.dart`) tracks only unread/inbox
   metrics, not creation-quota dimensions.
```

**Headline (deep-pass twist on sister):** Sister run scored 70/100 leaning on `ImportRateLimiter` as freemium plumbing. That holds, but **two findings sister missed knock the score down by 2 points**: (a) `OCRUsageTracker` is in-memory and resets on app restart — useless for tier enforcement; (b) the analytics monetization-cohort substrate (`subscription_tier` user property at `analytics_events.dart:182`) is wired-but-frozen — bootstrap default `'free'` at `user_property_bootstrap.dart:37` has no re-emit pathway from any business event. Both gaps are 1-2h fixes today, but they shape the "are we *actually* freemium-ready" answer.

**Critical-finding count is intentionally zero.** The user has explicitly deferred submission. This entire report is forward-looking risk.

---

## Pre-known facts cited (not re-discovered)

- `pubspec.yaml:22-99` — full deps audited live. **No** `in_app_purchase`, `purchases_flutter`, `revenuecat_flutter`, `purchasely`, `flutter_inapp_purchase`, `glassfy_flutter`, `qonversion_flutter`, `apphud_sdk`. Confirmed.
- `pubspec.yaml:98` — `in_app_review: ^2.0.10` shipped. Service is well-designed (see §5.6).
- `pubspec.yaml:120` — `google_sign_in_mocks` is in **dev_dependencies** only (mocks for tests). No production `google_sign_in` or `sign_in_with_apple`. The mocks-without-impl pattern is a tell that social login was scoped and dropped.
- `android/app/src/main/AndroidManifest.xml:1-127` — **no** `com.android.vending.BILLING` permission. Confirms zero IAP wire-up at platform layer.
- `ios/Runner/Info.plist:57-58` — `ITSAppUsesNonExemptEncryption=false` declared. Good — but if Stripe SDK lands later, must re-evaluate.
- `web/manifest.json:10` — `"prefer_related_applications": false` (PWA-first signal).
- `store_assets/screenshots/` — only `README.md` (5 lines reviewed). **Zero actual screenshots on disk** — submission blocker if/when the user reverses the deferral.
- `fastlane/` and `metadata/` directories: confirmed **do not exist** (`ls` failed). Metadata lives in `store_assets/metadata/{sv-SE,en-US}/`. No fastlane automation = manual ASO ops.
- 6 GitHub Actions workflows on disk vs 5 documented (per pre-analysis). None monetization-related.
- `flutter analyze` flagged `notification_service.dart:648` `ConsentPurpose undefined` — verified resolved on disk per Wave-1 report; not a submission blocker today.

---

## 1. Entitlement Architecture Readiness — 11.5/20

`PermissionService` (`lib/services/permission_service.dart:25-288`) is a singleton (`_instance ??=` at line 48) that delegates to three lazy modules: `RecipePermissionModule` (`:61-76`), `ShoppingPermissionModule` (`:79-88`), `GroupPermissionModule` (`:91-96`). The model is **resource-permission** ("can user X act on resource Y") via `ResourcePermission` (`lib/models/permissions/resource_permission.dart`) — this is correct for collaborative apps and **wrong for entitlement gating**. The questions don't compose: `permissionService.canEdit(recipe)` returns `true` even when a hypothetical "premium-only AI re-tag" should be blocked at the tier layer first.

`FeatureFlagService` (`lib/services/feature_flags/feature_flag_service.dart:23-273`) is the bright spot. Firebase Remote Config wired with:
- 28 typed flag constants at `:278-317` (kill switches, scalability, tagging thresholds).
- Per-session dedup of `feature_flag_evaluated` analytics events at `:198-222` with FNV-1a stable rollout hashing at `:175-192` — exactly what a per-user entitlement check needs.
- 1 hour minimum fetch interval (`:98`) and graceful default-fallback (`:115-122`) — production-ready substrate.

**However**, every flag in `_defaults` (`:46-82`) is operational — not a single `tier_*` or `entitlement_*` flag exists. The substrate is right; the schema is empty.

`subscription_tier` is **already wired as a Firebase Analytics user property** (`lib/services/analytics/analytics_events.dart:178-182` + `lib/services/analytics/user_property_bootstrap.dart:37,54,62-67`) — this is a BUT-623 concession to "set up the cohort dimension before we need it". But `emitSubscriptionTier()` is only called from `emitAtSessionStart` with the hardcoded literal `'free'` — there is no caller that re-emits on a business event. **No-op until the wiring is closed.** Sister report missed this.

### HIGH

**1.1 No `subscriptionTier` field on `UserProfile`** — `lib/models/user_profile.dart:26-97` has 25 fields. Adding `subscriptionTier`, `subscriptionStatus`, `currentPeriodEnd`, `originalTransactionId`, `paymentProvider` requires touching **6 surfaces in this one file**:
- `copyWith()` at `:101-165` (uses `_sentinel` pattern — addable cleanly)
- `toFirestore()` at `:239-258` (public/searchable subset)
- `toPrivateSettings()` at `:261-277` (sensitive settings subcollection)
- `toJson()` at `:280-314`
- `fromMap()` at `:317-364`
- `fromJson()` at `:366-413`

The model is well-defended (defensive deserialization at `:418-426` for `birthYear`) so additions are backwards-safe. But the `toFirestore()` vs `toPrivateSettings()` split forces a decision: subscription data is sensitive (lives in private settings subcollection) but also queryable (e.g. "all premium users → notify about new feature") which suggests the public profile mirror. Standard solution: store source-of-truth in private subcollection, mirror only `subscriptionTier` enum into `public_profiles` for query (with rules-protected write). Sister flagged the surface count; this report adds the **schema-split design decision** as the real friction. *Effort: 4-6 h to add fields + migrate readers + decide the split.*

**1.2 No IAP package in `pubspec.yaml`** — verified live. The dependency selection is itself a strategic decision worth scoping now (not later):
- `in_app_purchase` (Flutter team's official) — full Apple+Google support, but receipt validation is your problem.
- `purchases_flutter` (RevenueCat) — managed receipt validation, cross-platform entitlement caching, family sharing baked in. ~$0.35/MTR after 10k MTR, free under.
- Others (Glassfy, Qonversion, Adapty) — similar value props.

For an indie shop with ZERO existing payment infrastructure, **RevenueCat is the obvious choice** because it eliminates findings 1.3 (no receipt validation Cloud Function), 6.3 (family sharing), and 6.5 (webhook handler) in one decision. The sister report mentioned RevenueCat without naming it as the strategic recommendation. *Effort: 1 day for RevenueCat onboarding + 3-4 days for paywall UI + restore/manage flows.*

**1.3 No Cloud Function for server-side receipt validation** — `functions/src/index.ts:1-310` exports ~100 functions. Zero touch payments. The middleware substrate (`functions/src/middleware/` per pre-analysis) is mature (rate limiter, admin checker), so adding `validateReceiptAndGrantEntitlement(receiptData)` callable is mechanical IF rolling own validation. With RevenueCat the whole function is a 30-LOC webhook handler that updates Firestore based on RC's signed POST. *Effort: 1 week DIY, 2 days RevenueCat.*

**1.4 `subscription_tier` analytics property is wired but frozen** (NEW vs sister) — `user_property_bootstrap.dart:37,54` calls `emitSubscriptionTier('free')` at session start. No business event ever calls `emitSubscriptionTier('pro')`. The user property in BigQuery will say `'free'` for 100% of users for 100% of eternity until someone wires the re-emit hook. Sister report praised the property's existence; this pass notes the **callsite is open-ended**. *Effort: 30 min once an entitlement event source exists, but the gap matters because conversion-funnel cohorts (BUT-623's whole reason for being) are silently broken until then.*

### MEDIUM

**1.5 `PermissionService` singleton pattern is anti-DI** — `:48` `_instance ??= PermissionService._internal(...)`. The project's documented pattern (per `lib/services/CLAUDE.md`) is constructor injection in DI modules + `ServiceLocator.get<T>()` from views/VMs. `PermissionService` predates that rule. A `SubscriptionService` should be added via the DI module pattern (`lib/core/di/modules/core_module.dart` precedent) — **not** by extending `PermissionService`. *Effort: documentation, not refactor.*

**1.6 No "upgrade to unlock" UI primitive in `lib/widgets/`** — `ls lib/widgets/` returns 18 categories (`branding/`, `common/`, `cooking/`, `home/`, `image/`, `import/`, `legal/`, `menu/`, `messaging/`, `permissions/`, `recipe/`, `shopping/`, `social/`, `styled/`, `tagging/`, `user/`). Zero `paywall/`, `entitlement/`, `upgrade/`, `subscription/`. The square-aesthetic styled widgets at `lib/widgets/styled/styled_button.dart` provide the visual language; a `PaywallSheet` widget is greenfield. *Effort: 2-3 d for paywall + trial countdown + restore-purchase + manage-subscription deep links.*

**1.7 No "lock" iconography in `assets/illustrations/` for upsell screens** (NEW — `ls assets/illustrations/`: `arta/` only). The brand uses Arta-style illustrations (per `pubspec.yaml:148`). A "premium" illustration set is missing. *Effort: design, not engineering.*

### LOW

**1.8 `isInRollout(flag, userId)` could double as percentage-based premium-preview gating** (`feature_flag_service.dart:175-192`) — useful for "10% of users get the premium AI experience as a learning preview" before pricing. Defer until a hypothesis exists.

---

## 2. Schema Extensibility for Subscriptions — 11.5/15

The schema is **additive-friendly**: `UserProfile.fromMap()` at `:317-364` and `fromJson()` at `:366-413` use `SerializationUtils.safeXxx(...)` defaulted readers throughout. Legacy documents missing subscription fields would deserialize cleanly. There is no `schemaVersion` field, but the defensive readers compensate.

**`ImportRateLimiter` is the most important monetization artifact in the codebase** — `lib/services/import/import_rate_limiter.dart:1-468`. Per-window cost tracking with full Firestore transactions:
- `recordUsage()` at `:91-125` runs in `runTransaction` for atomic counter updates.
- Counters: `importsThisMinute / importsThisHour / importsToday / llmEnhancementsToday / llmExtractionsToday / llmVisionToday / llmCostToday / llmCostThisMonth / llmOperationsThisMonth` (`models/rate_limit_models.dart:189+`).
- Document path: `users/{uid}/rateLimits/imports`.
- Window-aware reset logic at `:382-467` — handles minute/hour/day/month rollovers.
- Fail-closed on Firestore errors (`:78-85`) — denies rather than allowing on infrastructure failure.

This is the freemium plumbing that **most pre-launch apps lack**. A premium tier today would be one map: `tierLimits = {free: {importsPerDay: 100, llmCostPerDay: 0.50}, premium: {importsPerDay: 1000, llmCostPerDay: 5.00}}` — all the persistence + cache + window-reset hooks already exist.

### CRITICAL-but-deferred (not flagged as CRITICAL because no monetization decision yet)

**2.1 `OCRUsageTracker` is in-memory only and resets on app restart** (NEW — sister missed) — `lib/services/ocr/ocr_usage_tracker.dart:1-124`:
- Counters at `:8-17` are plain Dart fields — `_dailyRequestCount`, `_monthlyRequestCount`, `_providerUsage` map.
- `freeMonthlyLimit = 500` declared at `:20` — name signals freemium intent.
- `_estimateMonthlyCost()` at `:81-86` uses hardcoded `_ocrSpaceCostPerCall = 0.01`, `_googleVisionCostPerCall = 0.05` (`:24-25`).
- **Zero persistence**. No Firestore writes, no SharedPreferences, no Drift. Force-quit the app → counters reset to 0.

**Implication:** if OCR is the freemium hook (e.g. "5 free scans/month, premium for unlimited") the gate is bypassed by killing the app. The model is the wrong model for monetization — it's a logging/dashboard model, not an enforcement model. Either rebuild on top of `ImportRateLimiter`'s Firestore pattern or move OCR into `ImportRateLimiter` as a fourth LLM operation type. *Effort: 1 day to migrate OCR counters into `ImportRateLimiter`.*

### HIGH

**2.2 Rate limit constants are hardcoded `static const`** (sister flagged this; this report adds the callsite scatter) — `lib/services/import/models/rate_limit_models.dart:289-300`:
```
importsPerMinute = 10
importsPerHour = 30
importsPerDay = 100
llmEnhancementsPerDay = 20
llmExtractionsPerDay = 10
llmVisionPerDay = 10
llmCostPerDay = 0.50
llmCostPerMonth = 10.00
```
Callsites that would need tier parameterization (verified live grep):
- `import_rate_limiter.dart:177, 186, 199, 208, 221, 230, 256, 262, 267, 277, 281, 300, 304, 363, 369, 375` (16 callsites).
- All in **one file**. Centralized — refactor is mechanical.

To make tier-aware: replace `ImportRateLimits.x` with `tierConfig.x` where `tierConfig` is loaded from Remote Config or `users/{uid}/subscription` doc and cached in the same `_cachedUsage` slot as the counters. *Effort: 1 day.*

**2.3 Recipe-count cap infrastructure absent** (NEW) — for a "free tier = 50 recipes" model: there is **no per-user recipe counter** that gates create. `UserProfile.publicRecipeCount` (`user_profile.dart:33`) tracks only public recipes for social profile display, not total. `UserCounters` (`lib/models/user_counters.dart`) tracks `unreadSharedRecipes`, `unreadMessages`, `pendingFriendRequests` — **inbox metrics, not creation quotas**. *Effort: 4-6 h to add `recipesOwnedCount` counter + cascade-update Cloud Function.*

**2.4 Image-storage cap infrastructure absent** (NEW) — `lib/services/upload/image_upload_service.dart` (per file presence; not deeply read) doesn't keep a running per-user byte sum. A "free tier = 100MB images" cap would require a new field + cascade. Firebase Storage usage queries are slow and rate-limited; client-side counter + cron reconcile is the standard. *Effort: 1 day.*

### MEDIUM

**2.5 No Firestore schema versioning on user document** (sister flagged) — adds risk for future migrations beyond simple additive fields. *Effort: ongoing.*

**2.6 `firestore.rules` write-protection for `subscriptionTier` is unverified** — pre-analysis says rules file is 1788 lines / 95 match rules. Rules must reject client self-promotion via `request.resource.data.subscriptionTier == resource.data.subscriptionTier` field-level check OR by routing all writes through `request.auth.token.admin == true` / Cloud Function with admin SDK. **Cross-ref Prompt 02.** *Effort: 2 h once field exists.*

**2.7 No `feature_used` generic event for premium-feature heatmapping** — `analytics_events.dart` (194 LOC) ships the per-feature events but no generic `feature_used` keyed on feature-id. Identifying which features warrant gating later requires this signal. **Cross-ref Prompt 08.** *Effort: 4 h.*

### LOW

**2.8 `UserCounters` is the natural place for creation-quota counters** (`user_counters.dart:1-50`) — could host `recipesOwnedCount`, `groupsOwnedCount`, `imageBytesUsed` without bloating `UserProfile`. The model is already wired for cascade updates per its docstring. *Effort: scoped into 2.3 + 2.4.*

**2.9 `HouseholdService` exists** (`lib/services/household_service.dart:14-46`) and aggregates allergen prefs across "household" group members. **This is the substrate for a Family Plan** — group-marked-as-household membership maps cleanly to "shared subscription". Sister missed this. *Effort: 0 today, big saver later.*

---

## 3. Feature Completeness vs Market Table-Stakes — 14.0/20

Sister table is largely correct; this pass corrects three claims:

| Category | Feature | Sister claim | Deep-pass verified |
|----------|---------|--------------|-------|
| Recipe display | Live recipe scaling | "Partial" | **Y** — `lib/widgets/common/input/portion_scaler.dart` + `portion_scaler_logic.dart` + `portion_scaler_ui.dart` + `recipe_detail_content.dart:577-578` (`InputComponents.portionScaler(originalPortions: viewModel.recipe.portions ?? 1)`) and `:23 List<String> scaledIngredients`. Live; sister downgrade was wrong. |
| Recipe display | Cooking timer (inline) | "Missing" | **Partial** — `lib/services/cooking/step_timer_service.dart:1-150+` is a per-step timer with `clock`-driven backgrounding-tolerant absolute end-times. BUT it's a single-active-timer service and there's no "tap '12 min' in instruction text → start timer" auto-extraction visible. Inline-from-instruction is missing; the timer infra is not. *Effort: 2-3 days for regex extraction + tap-to-start integration.* |
| Recipe display | Voice / hands-free | "Missing" | **Confirmed missing** — `pubspec.yaml` grep: no `speech_to_text`, no `google_speech`, no `voice` deps. Wakelock during cooking mode is the closest thing. |

### Table-stakes deep-pass matrix (deltas from sister)

| Feature | Status | File:line evidence |
|---|---|---|
| Create / edit / delete recipes | Y | `views/skriv_sjalv_recept_view.dart`, `views/edit_recipe_view.dart` |
| Import from URL | Y | `views/import_via_url_view.dart` + `services/import/url_import_strategy.dart` |
| Import from photo (OCR) | Y | `views/photo_import_view.dart` + `services/ocr_extraction_service.dart` + `services/ocr/ocr_usage_tracker.dart` |
| Import from social | Y | `services/social_media_extractor.dart` + `services/import/youtube/` |
| Import from archive (PDF/Excel) | Y | `services/import/archive_import_strategy.dart` + `services/import/file_import_strategy.dart` |
| Search (text) | Y | `services/search/recipe_search_router.dart` + `pubspec.yaml:91 algoliasearch` |
| Filter (tag/allergen) | Y | `services/tagging/phases/` (5-phase pipeline) |
| Favorite | Y | `models/recipe_unified.dart:244,337,398,487,568,612,698,889,1137,1381` (full lifecycle) + `views/mina_recept_view.dart:295,318` (filter) |
| Recipe scaling | **Y** (sister wrong) | `widgets/common/input/portion_scaler{,_logic,_ui}.dart` + `views/recipe_detail/recipe_detail_content.dart:577-578` |
| Inline cooking timer | **Partial** (sister wrong) | `services/cooking/step_timer_service.dart` infra exists; auto-extract from text missing |
| Cooking mode (screen-on) | Y | `views/cooking_mode_view.dart` + `pubspec.yaml:48 wakelock_plus` |
| Recipe photos (multi) | Y | `image_picker`, `image_cropper`, `cached_network_image` (`pubspec.yaml:55-57`) |
| Nutritional info (display) | Partial | `models/nutrition_info.dart` + `models/recipe_unified.dart:259` — populated only by `services/parsing/tiers/schema_org_tier.dart`. No manual entry, no Livsmedelsverket fetch live (admin function `functions/src/admin/fetch-livsmedelsverket.ts` is admin-only seed). |
| Weekly menu | Y | `views/veckomeny_view.dart` + `services/menu/weekly_menu_plan_service.dart` |
| Drag-and-drop scheduling | unknown | Not verified this pass; defer |
| Shopping list from menu | Y | `views/unified_shopping_view.dart` + `services/menu/parser/` (clause parsing for shopping items) |
| Shopping list mgmt (check-off, add) | Y | per beta-UX memory |
| Pantry tracking | Y | `services/pantry/pantry_service.dart` + `views/pantry/` |
| Substitution suggestions | Y | `services/cooking/substitution_suggestion_service.dart` |
| Share recipes (in-app) | Y | `services/share_service.dart` (556 LOC) + `pubspec.yaml:72 share_plus` |
| Share recipes (deep link) | Y | `services/deep_link_service.dart:1-80+` with full URL gen for invite/recipe/menu/shopping/profile (`:67-71`) |
| Comments + ratings | Y | `repositories/firebase/firebase_comments_repository.dart` + `functions/src/index.ts:226-309` (rating aggregation) |
| Groups / shared content | Y | `services/group_shared_content_service.dart` |
| **Household concept** (NEW) | Y | `services/household_service.dart:1-46` — group-marked-as-household; aggregates allergen prefs |
| Cook tracking | Y | `services/cook_snap_service.dart` + `repositories/firebase/firebase_cook_snap_repository.dart` + `firebase_cooking_session_repository.dart` |
| Real-time presence | Y | `services/presence_service.dart` + `pubspec.yaml:29 firebase_database` (RTDB onDisconnect) |
| Messaging | Y | `services/messaging/` (4 services) + `services/messaging_service.dart` |
| Notifications | Y | `services/notifications/` + `pubspec.yaml:33 flutter_local_notifications` |
| Pings (presence-aware nudge) | Y | `services/social/ping_service.dart` + `widgets/social/ping_compose_sheet.dart` |
| Step timer infra | Y | `services/cooking/step_timer_service.dart` |
| Offline access | **Downgrade vs sister** | `services/offline/offline_initialization{,_stub}.dart` + `offline_sync_manager{,_stub}.dart` + `offline_user_storage{,_stub}.dart` + `sync_result.dart` (8 files). Stub variants suggest platform-conditional. Drift (`pubspec.yaml:43`) + `sembast_web` (`:95`) wired. **Per Wave-2 perf report: online-first design.** Sister rated "partial"; deep pass agrees but flags that the stub-vs-impl split = web/desktop offline is incomplete. |
| Voice / hands-free | N | pubspec grep clean |
| Grocery delivery | N | per `memory/grocery-price-apis.md` (research-only) |
| Recipe collections | Y | personal tags = collections per beta-UX memory |
| Cookbook export (PDF) | Y | `lib/services/recipe_print_service{,_stub,_web}.dart` (3 platform variants) |
| Backup / restore | Y | `services/backup_service.dart:34` (`recipe_count` log on backup) |

### HIGH

**3.1 Inline cooking timer (auto-extract from instructions)** — sister rated "missing"; deep pass corrects to "infra-yes, auto-extract-no". The `StepTimerService` is well-built (`step_timer_service.dart:1-150+`: absolute end-time, `clock`-driven, backgrounding-safe). What's missing is the regex pass on instruction text to surface "12 min" / "15 minuter" / "tre minuter" as tappable timer triggers. *Effort: 2-3 d (regex + Swedish number-words + tap-to-start UI + a11y).*

**3.2 Voice / hands-free cooking mode** — confirmed absent. The cooking mode (`views/cooking_mode_view.dart`) is the natural insertion point. Swedish STT quality on `speech_to_text` package is unverified — Google's API is the strong-quality fallback at $0.024/min. *Effort: 1-2 weeks (STT verification + voice command grammar in Swedish + safety: no false-positive triggering).*

**3.3 Manual nutrition entry / on-demand Livsmedelsverket fetch** — `models/nutrition_info.dart` populates only from Schema.org JSON-LD. Per `MEMORY.md`: "Nutrition = plan models post-beta, use Livsmedelsverket API" — **deliberate deferral**. The admin Cloud Function (`functions/src/admin/fetch-livsmedelsverket.ts`) confirms the data source is provisioned. *Effort: 2 weeks for full nutrition feature.*

### MEDIUM

**3.4 Web/desktop offline incomplete** — 4 stub files (`offline_initialization_stub.dart`, `offline_sync_manager_stub.dart`, `offline_user_storage_stub.dart`, `pwa_install_service_stub.dart`) suggest mobile-only offline. App-store description (`store_assets/metadata/sv-SE/description.txt`) claims **"FUNGERAR OFFLINE"** unconditionally — partial truth on web. *Effort: variable; flag for honesty in description, not a code fix.*

**3.5 8-9 separate import entry-points** — flagged by `06-user-experience.md`. Cognitive overhead vs Yummly/BigOven's single "+" button. *Cross-ref UX.*

**3.6 Grocery delivery integration** — per `memory/grocery-price-apis.md` mapped landscape (ICA / Willys / Hemköp / Coop / Lidl / Matpriskollen). **Material strategic differentiator post-monetization** — see §6.

### LOW

**3.7 Unit conversion (metric ↔ imperial)** — Swedish-first; non-issue domestically. Note for UK/IE expansion.

**3.8 Cooking session tracking is implemented but not surfaced as a personal-stats feature** — `firebase_cooking_session_repository.dart` + `cook_snap_service.dart` capture data; no "you cooked 12 recipes this week" surface. **Premium feature opportunity.**

---

## 4. Differentiation — 13.0/15

Agreement with sister: this is Butlery's **strongest competitive asset**. Adding three rows sister missed:

| Feature | Butlery | Yummly | BigOven | Paprika | Crouton | Mela | ICA Recept | Tasteline | Eaty (DK) |
|---------|:-------:|:------:|:-------:|:-------:|:-------:|:----:|:----------:|:---------:|:---------:|
| Multi-tier AI import (site config → regex → LLM) | Y | partial | partial | partial | N | N | N | N | N |
| OCR-based image import | Y | N | partial | partial | N | N | N | N | N |
| Swedish NLP (compound split / Viterbi / line classifier) | Y | N | N | N | N | N | partial | partial | N |
| 5-phase auto-tagging | Y | partial | N | N | N | N | N | N | N |
| Real-time collaborative meal planning | Y | N | partial | N | N | N | N | N | N |
| Group recipe collections | Y | N | partial | N | N | N | N | N | N |
| Social features (friends/comments/ratings) | Y | Y | Y | N | N | N | partial | partial | partial |
| Multi-platform (iOS/Android/Web/macOS/Windows) | Y | partial | partial | Y | N | partial | partial | partial | partial |
| GDPR Phase 1 + Swedish microcopy on consent surfaces | Y | partial | partial | partial | partial | partial | Y | Y | Y |
| Swedish-first UX & content | Y | N | N | N | N | N | Y | Y | N |
| Inline cooking timers (auto-extract from text) | partial | Y | Y | Y | Y | Y | partial | N | N |
| Live recipe scaling (portion stepper) | **Y** (sister wrong) | Y | Y | Y | Y | Y | partial | partial | partial |
| Voice/hands-free cooking | N | Y | partial | N | N | N | N | N | N |
| Nutrition (manual + auto-fetch) | partial | Y | partial | Y | partial | N | partial | Y | partial |
| Pantry tracking | Y | partial | Y | N | N | N | N | N | partial |
| Cook tracking / "lagat-snap" | Y | partial | N | N | N | N | N | N | N |
| Pings (presence-aware nudges) | Y | N | N | N | N | N | N | N | N |
| Substitution suggestions | Y | partial | N | N | N | N | partial | N | N |
| Household-aware allergen aggregation | Y | N | N | N | N | N | N | N | N |
| Cookbook PDF export | Y | partial | Y | Y | partial | partial | N | N | N |
| Pricing model | none | freemium | freemium ($2.99/mo Pro) | $4.99 one-time | $4.99 one-time | $4.99 one-time | free | free | freemium |

**Strategic feature inventory unique to Butlery** (sister underweighted these):
1. **Pings as presence-aware nudges** (`services/social/ping_service.dart` + `widgets/social/activity_pings_feed.dart`) — no competitor surveyed has this primitive. It's a tiny but defensible UX wedge: "ping mom about tonight's recipe she shared".
2. **Cook tracking ("lagat-snap")** — `cook_snap_service.dart` + `firebase_cook_snap_repository.dart` + `firebase_cooking_session_repository.dart`. Most competitors track favorites; Butlery tracks actual cooking. The data alone is differentiating (it's the only true engagement metric in food apps).
3. **Household-aware allergen aggregation** (`household_service.dart:46+`) — **truly novel**. No competitor surveyed asks "what's safe for everyone in this household?" as a planning primitive. Real moat for family use cases.
4. **Pantry-aware planning** (`pantry/`) — combined with menu generation, this is the wedge against ICA/Coop's "buy this" model.
5. **UTM acquisition attribution wired** (`models/acquisition_attribution.dart:1-52`, `repositories/firebase/firebase_acquisition_repository.dart`) — most indie apps ship without source tracking. Sister flagged as 7.2 LOW; this pass elevates: **the data infrastructure for paid acquisition exists today**.

**Moat ratings (deep pass refinement):**

| Asset | Moat type | Defensibility |
|---|---|---|
| Swedish NLP pipeline | Hard / technical | 6-12 months for an incumbent to replicate; data flywheel via parsing-correction telemetry deepens it |
| Multi-tier import (site-config → regex → LLM) | Unit-economics | Cheaper to operate per import than LLM-everywhere competitors → can sustain a free tier they can't |
| Collaborative meal planning + presence | Network effect | Every friend on Butlery raises switching cost |
| Household-aware allergen aggregation | Niche category-defining | First-mover; nobody is even trying |
| GDPR + Swedish microcopy | Trust / regional | ICA/Coop match on trust; English-first competitors won't replicate |
| Cook tracking ("lagat-snap") | Data asset | Builds proprietary engagement signal others lack |
| Parsing-correction data flywheel | Compounding data | More users → better Swedish NLP → more imports succeed → more users |

### HIGH

**4.1 Differentiation undercommunicated in store metadata** (sister flagged) — `store_assets/metadata/sv-SE/description.txt:1-22` opens with "Planera veckans mat, spara dina favoritrecept och skapa smarta inköpslistor" — generic. Doesn't mention AI import, OCR, social-media import, household allergen aggregation, or pantry-aware planning. The keywords list (`store_assets/metadata/sv-SE/keywords.txt`) is "recept,matplanering,inköpslista,veckomeny,måltider,matlagning,dela recept,kokbok,måltidsplaneringButlery" — no "AI", no "foto", no "OCR", no "Instagram"/"TikTok", no "allergi". Lost ASO ranking on the highest-volume 2025-2026 search terms. *Effort: 1 h copy revision; biggest single ROI in this report.*

### MEDIUM

**4.2 Parsing-correction data flywheel is invisible to user** (sister flagged) — `lib/repositories/parsing_correction_repository.dart` collects telemetry; `functions/src/analytics/analyze-corrections.ts` mines it. **Literal data moat** but no user-facing message. Adding a "Du gör Butlery bättre — tack!" toast after a correction would (a) deepen the moat by encouraging more corrections, (b) surface the differentiator to support negative reviews ("the AI is bad" → "wait, my corrections train it"). *Effort: 4 h messaging + analytics check.*

**4.3 Cook tracking is invisible as a personal-stats feature** (NEW) — data is captured (`cook_snap_service.dart` + `firebase_cooking_session_repository.dart`) but I don't see a "Du har lagat 12 recept den här månaden" surface in `views/`. **Year-in-review premium feature opportunity** (Spotify Wrapped pattern → strong subscription anchor). *Effort: 1 week for stats screen + 1 week for "Wrapped"-style year recap.*

**4.4 Household-aware allergen aggregation is undocumented in store listing** — `household_service.dart` is a defensible novel feature. Nobody marketing it. *Effort: 30 min ASO copy.*

### LOW

**4.5 No referral / invite-loop incentive infrastructure** — `deep_link_service.dart:67-71` generates friend invitation URLs; `firebase_acquisition_repository.dart` captures attribution; **no "invite a friend, get a perk" loop wires the two together**. Network-effect moat is shallow without it. *Effort: 1 week (invite reward + tracking + abuse prevention) once monetization decided.*

---

## 5. App Store Submission Risk Assessment — 9.5/15

Cross-reference: `06-user-experience.md` Pass 2 owns App Store Readiness sub-score (6/12). This dimension scores **rejection risk** when (if) submission day arrives. Per `feedback_no_store_submission_yet.md` the user has explicitly deferred — this is forward-looking.

| Apple top-10 rejection reason | Risk for Butlery | Notes |
|-------------------------------|:----------------:|-------|
| 1. Bugs and crashes | LOW-MED | Wave-1 deep `ConsentPurpose undefined` resolved on disk per audit. No Crashlytics evidence reviewed. |
| 2. Broken links / placeholder content | **MEDIUM** | `macos/Runner/Base.lproj/MainMenu.xib` has `APP_NAME` placeholder × 6 (per `06-user-experience.md` HIGH-6) — would only ship as desktop, irrelevant for iOS. iOS clean. |
| 3. Incomplete information | LOW-MED | Privacy policy + ToS in `assets/legal/` (per `pubspec.yaml:148`). Listing copy present. |
| 4. Insufficient content / minimum functionality | LOW | App is feature-rich. Not a website wrapper. |
| 5. Privacy violations | MEDIUM | Cross-ref Prompt 09. Privacy manifest present (`ios/Runner/PrivacyInfo.xcprivacy` per pre-analysis). Accuracy is the question — payment SDKs (when added) require manifest update. |
| 6. UGC moderation | MEDIUM | Cross-ref Prompt 09. Reports + admin moderation rules exist (`functions/src/feedback/on-report-created.ts`, `lib/services/moderation/{report_service,content_filter_service}.dart`); end-to-end verification deferred. |
| 7. IAP issues | N/A | No IAP today. |
| 8. Performance | LOW | Cross-ref Prompt 04. |
| 9. Wrapper / minimum design | LOW | Native Flutter UI. |
| 10. Sign in with Apple | **HIGH** when other social login lands | Apple §4.8: SiwA mandatory if any other social login offered. Today: zero risk (no social login at all per `pubspec.yaml`). The day Google sign-in lands, SiwA must ship same release. |

### HIGH

**5.1 iOS subtitle is 31 chars — over Apple's 30-char hard limit** (sister missed; 06 caught at MED — this report elevates) — `store_assets/metadata/sv-SE/subtitle.txt` = `"Recept, veckomeny & inköpslista"` (verified char count = 31). Apple Connect rejects on upload. **Submission blocker.** Replace with `"Recept, veckomeny, inköpslista"` (29 chars, ampersand → comma). *Effort: 1 minute.*

**5.2 Sign in with Apple becomes mandatory same release any other social login lands** (sister flagged) — `pubspec.yaml` has no `sign_in_with_apple` and no `google_sign_in` (only `google_sign_in_mocks` in dev_dependencies for tests at `:120`). The mocks-without-impl pattern signals social login was scoped and dropped. The risk is the **sequencing trap**: when Google sign-in is added, forgetting SiwA is the canonical Apple §4.8 rejection. *Effort: 1 d for SiwA when needed.*

**5.3 No App Store reviewer demo account documented** (sister flagged 5.2) — `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` exists per pre-analysis. No `reviewer-credentials.md` found. Reviewers can't test social/group/sharing features without a pre-populated account with friends + shared recipes + groups. **Apple §2.1: reviewer access required for full-feature apps.** *Effort: 2 h to provision + document; recurring per-release.*

**5.4 Zero actual screenshots on disk** (NEW) — `store_assets/screenshots/` contains only `README.md` (5 device sizes + 5 recommended screens documented but no PNGs). **Hard submission blocker** — Apple requires 6.7" iPhone + iPad Pro 12.9" screenshots minimum. Not a code task; flagged because the README's screenshot recipe (clean food photos, dark + light, device frames) implies a half-day photoshoot per locale per device size = realistically 1-2 days of asset production. *Effort: 1-2 days asset production.*

### MEDIUM

**5.5 Account deletion in-app is required by Apple §5.1.1(v) and Play Store** — `lib/services/account/account_deletion_service.dart` exists with full operations module split (`account_deletion/{content,profile,social,storage}_deletion_operations.dart`). Verify it's reachable in 2 taps from settings. **Cross-ref `06-user-experience.md` HIGH-5: settings hub is missing data-export and consent-management tiles** — by extension, account-deletion linkage from `views/settings/settings_hub_view.dart:30-106` should be re-verified. *Effort: 30 min UX verification.*

**5.6 `InAppReviewService` trigger logic is excellent but Apple cap unverified** — `lib/services/in_app_review_service.dart:32-50`: triggers on 3rd 4-5★ rating, 7+ days post-install, 90-day floor between prompts. Apple's hard limit is 3 prompts/365 days — Butlery's 90-day floor allows max 4/year (could exceed in edge cases at days 0 + 90 + 180 + 270 + 360, technically 5). Tighten to 100 days for safety. The service is otherwise the best-of-breed implementation reviewed in this codebase. *Effort: 1 line change.*

**5.7 Reviewer notes don't yet explain AI import features** (sister flagged 5.4) — multi-tier import (URL → site config → regex → LLM) is non-obvious; reviewers may flag as broken if a niche site fails. App Store Connect review notes need a "what to test" section. *Effort: 1 h.*

**5.8 Google Play Data Safety section drafted unknown** — `docs/ops/play-data-safety-runbook.md` exists per pre-analysis. **Cross-ref Prompt 12.** *Effort: 4 h.*

### LOW

**5.9 No "what's new" per-version structure** — Single `release_notes.txt` overwritten per release. Cross-ref `06-user-experience.md` §6.5.

**5.10 macOS / Windows desktop builds are post-beta but already broken in user-visible ways** — per `06-user-experience.md` HIGH-6 (`macos/Runner/Base.lproj/MainMenu.xib` `APP_NAME` × 6, `windows/runner/main.cpp:30 L"butlery"` lowercase). **Cross-ref 06.**

---

## 6. Revenue Infrastructure Prerequisites — 6.0/10

`functions/src/index.ts` exports ~100 callable / triggered / scheduled functions in one file. Mature middleware (rate limiter, admin checker per pre-analysis). Cloud Functions substrate is best-in-class — only thing missing is the actual payment handlers.

`firebase_remote_config` (`pubspec.yaml:32`) is wired at app start (`feature_flag_service.dart:86-112`) — premium plan limits, paywall copy variants, and rollout percentages can all flow through without code deploys.

### HIGH (forward-looking)

**6.1 No paywall UI components in `lib/widgets/` or `lib/views/`** (sister flagged) — verified live: 18 widget categories, zero `paywall/`. Square brand aesthetic + cream/forestGreen tokens (`lib/theme/app_dimensions.dart:78-112` per 06 verification) provide the visual language; `PaywallSheet` widget is greenfield. *Effort: 3-4 d (paywall + trial countdown banner + restore-purchase + manage-subscription deep link).*

**6.2 No conversion-funnel analytics events** (sister flagged 6.2) — verified live grep on `analytics_events.dart` for `paywall|trial|purchase` returns only the user-property comment at `:178-182`. Missing event constants:
- `paywall_viewed`
- `paywall_dismissed`
- `trial_started`
- `trial_converted`
- `subscription_renewed`
- `subscription_cancelled`
- `restore_purchase_attempted`
- `restore_purchase_succeeded`

Without these, no LTV / cohort analysis post-launch. **Cross-ref Prompt 08.** *Effort: 2 h to add as no-op constants today; ready when needed.*

### MEDIUM

**6.3 Family-plan substrate exists but not wired to entitlements** (NEW vs sister) — `lib/services/household_service.dart:14-46` aggregates allergen prefs across "household" group members (`isHousehold` flag on category). RevenueCat's family entitlements (or Apple Family Sharing for autorenewing subs) maps cleanly: when household-marked group's owner has `subscriptionTier='family'`, all `allMemberIds` (`:36-44`) inherit the entitlement. **The substrate is more ready than the user model is.** *Effort: 1 week design + 3 d wire-up once chosen.*

**6.4 Consumable IAP (AI import credits) is supported by `ImportRateLimiter` architecture** (sister flagged 6.4) — `recordUsage` (`:91-125`) already tracks per-operation costs in Firestore-transactional updates. Adding a positive-offset "credits" bucket that decays per consumption is mechanical. **Pricing-model fit: pay-per-import** ($0.99 for 20 AI imports) maps very cleanly to existing infrastructure and avoids the subscription-resistance friction. *No effort estimate; pricing decision first.*

**6.5 No Cloud Function for receipt validation OR webhook handling** (sister flagged 1.3 + 6 conflated) — split here for clarity:
- **Receipt validation** (Apple/Google → server): zero today. `validateAppleReceipt`, `validatePlayReceipt` callable functions need creating. With RevenueCat, this is a 30-LOC webhook handler.
- **Webhook handling** (RevenueCat / Stripe → server): zero infrastructure today. Cloud Function with HMAC signature verification + Firestore update.
- **Scheduled subscription expiry check**: zero today. Pattern exists (`functions/src/scheduled/north-star-weekly.ts` proves scheduled functions work in this project).

*Effort: 1 week DIY full validation + webhook + scheduled, 2 days RevenueCat integration.*

**6.6 LLM cost ceiling per user is `$0.50/day, $10/month`** (`rate_limit_models.dart:299-300`) — at 1k DAUs at full quota = $10k/mo LLM. Not viable on 100% free. **Implication:** AI import path *must* eventually be either (a) the premium hook, or (b) heavily site-config-tiered to avoid LLM on known sites (already implemented at `lib/services/parsing/tiers/site_config_tier.dart` — mitigates risk significantly). The site-config tier is genuinely an economic moat. *No fix; framing for monetization decision.*

### LOW

**6.7 Cloud Functions cost-trace per AI parse missing** (sister flagged 6.6) — `functions/src/llm/structure-recipe.ts` and `ocr-recipe-image.ts` are the LLM endpoints. Recommend a `cost_estimate_usd` field on every parse-event log so per-import LTV becomes observable. *Effort: 4 h.*

---

## 7. Market Positioning & ASO — 2.5/5

Per `06-user-experience.md` Pass 2: Swedish + English store metadata exists. `applicationId = se.butlery.app` is professional. `butlery://` deep-link scheme registered (`ios/Runner/Info.plist:62-71`, `android/app/src/main/AndroidManifest.xml:71-83`). Universal Links / App Links domain is `butlery.app` (`AndroidManifest.xml:75 autoVerify="true"`). Web platform enabled (`pubspec.yaml:15 flutter_web_plugins`).

The Swedish recipe-app market in 2026 has known incumbents per the strategic-feature-analysis pointer (`memory/strategic-feature-analysis.md`): ICA Recept (free, brand-locked), Coop's recipe app, Tasteline (Aller Media — long-term relevance unclear), Köket.se (web-first), Eaty (DK, similar-position). **Niche AI/import-first players in Swedish are essentially absent — this is white space.**

### HIGH (downgrade vs sister)

**7.1 31-char subtitle blocks submission, undercommunicates AI** — see §5.1. The fix opportunity: replace with `"AI-recept & smart veckomeny"` (28 chars) — leads with the strongest differentiator + the table-stakes feature. *Effort: 1 minute, biggest ASO ROI in report.*

### MEDIUM

**7.2 No Open Graph / Schema.org JSON-LD on shared web routes** (sister flagged) — when Butlery shares a recipe link, social-media unfurls show generic preview, not a recipe card. Lost-but-recoverable acquisition channel. The codebase parses incoming JSON-LD (`lib/services/extraction/site_parsers/koket_recipe_parser.dart` + `services/parsing/tiers/schema_org_tier.dart`) but doesn't emit it on shared web pages. *Effort: 1 d if web frontend renders shared recipe pages; n/a if shares always deep-link to app.*

**7.3 UTM acquisition attribution wired but no campaign-loop** — `models/acquisition_attribution.dart:1-52` captures source/medium/campaign/firstSeenAt with first-write-wins (`:8` docstring). `repositories/firebase/firebase_acquisition_repository.dart` exists. **The data infrastructure for paid acquisition exists today** — but no attribution-aware UI (no "thanks for joining via @cookingblogger!" surface), no campaign-cohort dashboard. *Effort: 1 d to surface; bigger value once paid acquisition starts.*

### LOW

**7.4 PWA manifest could expose more shortcuts** — `web/manifest.json:22-44` ships 2 shortcuts (Lägg till, Inköpslista). Could add Veckomeny, Kokmodus. *Effort: 5 min.* (LOW because sister `06-user-experience` LOW-2 owns the PWA polish.)

**7.5 Localized Nordic expansion is one ARB-file away** — Norwegian Bokmål, Danish, Finnish unlock 20M+ adjacent speakers with no architecture work. Per Wave-2 deep `06`: 3,800 keys per locale (run-1 6,347 was wrong) — translator cost ~SEK 30k-50k per locale at standard rates. **Strength worth flagging.**

**7.6 No A/B testing of ASO assets** — Apple Product Page Optimization and Play Store experiments aren't wired. Operational, not code.

**7.7 `web/manifest.json:9 "orientation":"portrait-primary"`** — locks PWA to portrait. Fine for browsing, breaks `cooking_mode_view.dart` (landscape split per memory). *Effort: 1 line if landscape-when-cooking matters on web.*

---

## Strategic monetization opportunities (≥6 — headline section)

Bold takes informed by what the codebase already supports and what competitors don't.

### SO-1 — **Pay-per-AI-import credits** ($0.99 / 20 imports) — *cheapest experiment to validate willingness-to-pay*

The unit-economics concern (§6.6: $10/mo LLM ceiling per heavy free user) is a forcing function. `ImportRateLimiter.recordUsage` (`import_rate_limiter.dart:91-125`) already tracks per-operation cost atomically. A consumable "credits" bucket as a positive offset is a 2-day add. **Sells the AI import angle without locking it behind a recurring paywall.** Tests price elasticity ($0.99 ↔ $2.99) cheaply — RevenueCat's consumable IAP supports A/B price testing. **Recommended first experiment.**

### SO-2 — **Family Plan (`'family'` tier) leveraging `HouseholdService`**

Sister missed: `services/household_service.dart:14-46` already aggregates across household-marked group members. Apple Family Sharing for autorenewing subs OR RevenueCat family entitlements maps cleanly: owner pays `'family'` tier; all `allMemberIds` (`:36-44`) inherit. **The killer app for the household allergen aggregation feature** — "Butlery Family: 6 people, 4 allergies, 1 subscription". *Effort: 1 week design + 3 d wire after IAP lands. Strong moat against ICA's free-but-no-household model.*

### SO-3 — **"Butlery Wrapped" — paid annual recap leveraging `cook_snap_service`**

`firebase_cooking_session_repository.dart` + `cook_snap_service.dart` capture genuine cooking events. **Spotify Wrapped is the highest-converting subscription anchor in consumer apps.** A "Year in Recipes" recap (top 10 cooked, hours in kitchen, allergen-safe meals served, friends cooked together) is (a) shareable (organic acquisition), (b) emotionally resonant (purchase-driving moment), (c) only available because Butlery actually tracks cooking, not favoriting. *Effort: 1 week stats + 1 week recap UI; release Dec 1 for max effect.*

### SO-4 — **Sponsored "Smart Säsong" pantry-aware promotions** (B2B revenue, not subscription)

Pantry tracking + seasonal awareness (`services/seasonal/seasonal_hero_service.dart`) + grocery-API research (`memory/grocery-price-apis.md`) enables a non-spammy ad surface: "Du har bla bär i pantryt — ICA har x3 erbjudande på vaniljvisp den här veckan, klicka för recept som passar". Revenue model: CPC from grocers, **not user-paid**. Avoids the subscription-resistance friction entirely. *Effort: 4-6 weeks; requires grocer partnerships.*

### SO-5 — **Premium AI tier: "Smart Cooking Companion"**

Per `memory/strategic-feature-analysis.md`: "Winner: Smart Cooking Mode first → AI Companion post-monetization". This is the second-highest-value premium hook after pay-per-import. AI substitution suggestions exist (`services/cooking/substitution_suggestion_service.dart`) — premium tier could unlock voice-driven hands-free + per-step LLM assistance ("can I sub butter for olja?"). **Builds on existing infrastructure, doesn't compete with free tier's value.**

### SO-6 — **Differentiator-led ASO: kill the bland subtitle, lead with AI**

Replace `"Recept, veckomeny & inköpslista"` (31 chars; over limit; differentiation-zero) with `"AI-recept & smart veckomeny"` (28 chars; leads with AI). Replace description.txt opening (currently "Planera veckans mat...") with "Importera recept från foto, video eller URL — Butlery förstår svenska." **Closest thing to free money in this report.** *Effort: 1 hour copy revision. Cross-ref §4.1 + §5.1 + §7.1.*

### SO-7 — **Referral loop with `acquisition_attribution.dart` already wired**

`models/acquisition_attribution.dart:1-52` + `repositories/firebase/firebase_acquisition_repository.dart` + `deep_link_service.dart:67-71` (invite URL gen). **Three-quarters of the infrastructure for "invite a friend, get a free month" already exists.** Missing: the incentive grant logic and abuse prevention. Once subscriptions ship, the referral loop is a 1-week add with multiplicative effect on CAC. *Effort: 1 week post-IAP; high ROI.*

### SO-8 — **Public-recipe sharing as freemium acquisition channel**

`UserProfile.publicRecipeCount` (`user_profile.dart:33`), `isSearchable` (`:31`), `allowEmailSearch` (`:32`), `views/social/public_profile_view.dart` exist. Web-side rendering of public recipe URLs (with §7.2's OG tags) turns every shared recipe into a Google-indexable acquisition page. **Cheaper than paid ads, durable, compounds.** Free tier limited to N public recipes; premium tier unlimited. *Effort: 1-2 weeks for web-side rendering + sitemap.*

---

## What's missing — entitlement infrastructure (≥8)

### EM-1 — `subscriptionTier` field on `UserProfile`
Wired in analytics (`analytics_events.dart:182`) and bootstrap (`user_property_bootstrap.dart:37,54`) as a hardcoded `'free'`. **Not present on the model itself** (`user_profile.dart:26-97` enumerates all 25 fields). 6-surface refactor (see §1.1). *Effort: 4-6 h.*

### EM-2 — `SubscriptionService` in `lib/services/`
The DI module pattern (`lib/core/di/modules/core_module.dart`) is the right insertion point. Zero existence today. Service must wrap RevenueCat (or `in_app_purchase`) SDK + cache entitlement state + expose `bool canAccess(Feature.aiImport)` predicate API. *Effort: 1 week including paywall integration tests.*

### EM-3 — IAP package in `pubspec.yaml`
Verified live: zero. Strategic recommendation: RevenueCat (`purchases_flutter`) for managed receipt validation + family entitlements + cross-platform restore. *Effort: 1 d package onboarding.*

### EM-4 — Cloud Function for receipt validation / webhook handling
`functions/src/index.ts:1-310` — zero payment functions. Either DIY (`validateAppleReceipt`, `validatePlayReceipt`, scheduled expiry checker) OR thin RevenueCat webhook handler. *Effort: 1 week DIY, 2 d RevenueCat.*

### EM-5 — `firestore.rules` field-level write protection for subscription data
Pre-analysis: 1788 LOC / 95 match rules. Standard pattern: `request.resource.data.subscriptionTier == resource.data.subscriptionTier` field-level diff check on every user-doc write OR route via admin-SDK Cloud Function exclusively. **Cross-ref Prompt 02.** *Effort: 2 h.*

### EM-6 — Tier-parameterized rate limits
`rate_limit_models.dart:289-300` is `static const`. 16 callsites in `import_rate_limiter.dart` (`:177, 186, 199, 208, 221, 230, 256, 262, 267, 277, 281, 300, 304, 363, 369, 375`). All in one file — refactor is mechanical but real. *Effort: 1 d.*

### EM-7 — Persistent OCR usage tracking
`ocr_usage_tracker.dart:8-17` is in-memory. **Cannot enforce a free OCR cap — force-quit resets counters.** Either migrate to Firestore (mirror `ImportRateLimiter` pattern) or fold OCR into `ImportRateLimiter` as a fourth `LlmOperationType`. **Sister missed this.** *Effort: 1 d to migrate.*

### EM-8 — Per-user creation-quota counters
No `recipesOwnedCount` (`user_counters.dart:1-50` tracks only inbox metrics). No `groupsOwnedCount`. No `imageBytesUsed`. For a "free tier = 50 recipes / 100MB images" model, all three need adding + cascade Cloud Functions on create/delete. *Effort: 4-6 h per dimension + 4 h cascade function.*

### EM-9 — Paywall UI primitives
Zero `lib/widgets/paywall/` or `lib/views/paywall/`. Square brand aesthetic provides visual language but no `PaywallSheet`, `UpgradeBanner`, `TrialCountdown`, `RestorePurchaseButton`, `ManageSubscriptionLink`. *Effort: 3-4 d.*

### EM-10 — Conversion-funnel analytics events
8 missing constants enumerated in §6.2. None exist today in `analytics_events.dart` (194 LOC). *Effort: 2 h.*

### EM-11 — `subscription_tier` user-property re-emit hook
`user_property_bootstrap.dart:62-67` only called from session-start with hardcoded `'free'`. **No business-event call path.** Until wired, BigQuery cohorts for `subscription_tier` are useless. **Sister missed.** *Effort: 30 min once entitlement source exists.*

### EM-12 — Demo / reviewer account provisioning
Per §5.3: no `reviewer-credentials.md`. `docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` exists but no provisioned demo account with friends/groups/shared recipes. Apple §2.1 hard requirement. *Effort: 2 h.*

---

## Risk Heatmap (top 7 — expanded vs sister's 5)

| # | Risk | Severity | Time-to-fix when triggered |
|---|------|----------|----------------------------|
| 1 | iOS subtitle 31 chars → submission rejected on upload | HIGH (today, already-blocker) | 1 minute |
| 2 | `OCRUsageTracker` in-memory → free tier trivially bypassed | HIGH (forward) | 1 day |
| 3 | `subscription_tier` analytics property frozen at `'free'` → cohort analysis silently broken when paid ships | HIGH (forward) | 30 min wire + dependent on EM-1+EM-2 |
| 4 | IAP integration debt — 6-surface user-model refactor + new Cloud Functions + paywall UI | HIGH (forward) | 3-4 weeks total |
| 5 | Sign in with Apple becomes same-release requirement when any other social login lands | HIGH (forward) | 1 d if planned; rejection if forgotten |
| 6 | Inline cooking timer auto-extract is missing despite timer infra existing — table-stakes gap that surprises users | MEDIUM (today) | 2-3 d |
| 7 | Differentiation undercommunicated in store metadata (AI/OCR/social-import buried) → ASO ranking left on table | MEDIUM (today) | 1 h copy revision |

---

## Strengths to preserve (deep pass adds 3 to sister's list)

1. **`ImportRateLimiter` is freemium plumbing already paid for** — per-window cost-tracked Firestore-transactional. The most expensive subscription-stack piece, ready today (`import_rate_limiter.dart:91-125, 382-467`).
2. **`FeatureFlagService` + `isInRollout` stable hashing** — exact substrate for percentage-based entitlement gating (`feature_flag_service.dart:175-192`).
3. **Multi-tier import pipeline is a unit-economics moat** — site-config tier (`services/parsing/tiers/site_config_tier.dart`) means LLM is fallback, not default. Most AI-recipe apps LLM-everything.
4. **Parsing-correction telemetry** (`repositories/parsing_correction_repository.dart` + `functions/src/analytics/analyze-corrections.ts`) — literal data flywheel for Swedish NLP.
5. **GDPR + Swedish microcopy** — trust moat regional incumbents match but no English-first competitor will.
6. **`in_app_review` already shipped** (`pubspec.yaml:98`, `services/in_app_review_service.dart:1-150+`) — best-of-breed implementation: 4-5★ trigger + 7-day install floor + 90-day prompt floor + analytics emission.
7. **Multi-platform widens the funnel** — web is a free acquisition channel for share-link unfurls when §7.2 closed.
8. **NEW: `HouseholdService` is the family-plan substrate** (`services/household_service.dart:14-46`).
9. **NEW: UTM acquisition attribution wired** (`models/acquisition_attribution.dart:1-52`, `firebase_acquisition_repository.dart`) — paid-acquisition data infra ready before paid acquisition starts.
10. **NEW: Cook tracking captures the only true engagement signal in food apps** (`firebase_cook_snap_repository.dart`, `firebase_cooking_session_repository.dart`) — proprietary data asset for personalization, recommendations, "Wrapped" recap, and ML training.

---

## Quick wins (≤1 day, ROI-ordered)

1. **Replace iOS subtitle** (`store_assets/metadata/sv-SE/subtitle.txt`) — 1 min — unblocks submission AND leads with AI (SO-6).
2. **Lead `description.txt` with AI/OCR/social-import** (`store_assets/metadata/sv-SE/description.txt:1-22`) — 1 h — biggest ASO ROI.
3. **Add 8 conversion-funnel analytics event constants as no-ops** (`analytics_events.dart`) — 2 h — ready when needed (EM-10).
4. **Add `subscriptionTier`-shaped placeholder field on `UserProfile`** as nullable — 4 h — future-proofs schema (EM-1).
5. **Migrate `OCRUsageTracker` counters to Firestore** mirror of `ImportRateLimiter` pattern — 1 d — closes monetization-bypass hole (EM-7).
6. **Tighten `InAppReviewService` minDaysBetweenPrompts from 90 → 100** (`in_app_review_service.dart:46`) — 1 line — Apple-cap safety margin.
7. **Add reviewer demo account doc** (`docs/store-submission/reviewer-credentials.md`) — 2 h — recurring win every release (EM-12).
8. **Document `static const` → tier-aware rate-limit refactor path in 1-page spec** — 2 h — reduces future surprise (EM-6 prep).
9. **Add `cost_estimate_usd` field on parse-event log** — 4 h — observable per-import LTV (§6.7).

---

## Phase 2 preparation

- **Sprint A (ASO + safety, 1 day total):** §5.1 subtitle + §4.1 description copy + §5.6 in-app-review tightening + §5.3 demo account doc.
- **Sprint B (table-stakes closures, 1 sprint):** §3.1 inline timer auto-extract + §3.5 import-entry-point consolidation (cross-ref UX). 1 week.
- **Sprint C (entitlement substrate scaffolding — no monetization decision needed yet, 1 sprint):** EM-1 (`subscriptionTier` field) + EM-7 (OCR persistence) + EM-10 (analytics constants) + EM-11 (re-emit hook stub). 1 week.
- **Sprint D (forward-looking — only if monetization decision lands):** EM-2-5 (RevenueCat + Cloud Function + rules) + EM-9 (paywall UI). 3-4 weeks.
- **Sprint E (differentiator-led growth — post-IAP):** SO-1 (pay-per-import) → SO-2 (Family Plan) → SO-3 ("Wrapped") → SO-7 (referral loop). 4-6 weeks.
- **Backlog:** SO-4 (B2B grocer ads), SO-5 (Smart Cooking Companion), SO-8 (public-recipe SEO), §3.2 voice/hands-free, §3.3 manual nutrition + Livsmedelsverket fetch.

Phase 2 should also synthesize against `06-user-experience.md` (App Store Readiness 6/12; HIGH-5 settings sprawl; HIGH-6 desktop branding; MED-5 subtitle), Prompt 02 (rules to protect `subscriptionTier`), Prompt 04 (LLM cost framing), Prompt 08 (conversion funnel events), Prompt 09 (privacy manifest accuracy when payment SDKs added), Prompt 11 (legal text accuracy when subscription terms exist), Prompt 12 (doc drift on `STORE_SUBMISSION_CHECKLIST.md` and `play-data-safety-runbook.md`).

---

## Pass-1 self-critique

**Pass-1 over-claims:**
- HIGH-2.1 OCR enforcement gap is severe but pre-monetization makes it forward-only.
- SO-2 Family Plan via `HouseholdService` mapping is a strategic claim — actual UX integration may surface friction (who pays vs who's invited; what about household-of-one).
- SO-4 grocer-sponsored content is bold; requires real-world partnerships (memory pointer is research-only).

**Pass-1 likely under-counts:**
- Web-side public-recipe rendering (SO-8) value depends on whether `lib/views/social/public_profile_view.dart` actually renders on web cleanly — not deep-verified.
- Apple Family Sharing nuances (autorenewing subs only; consumables don't share) — not deeply audited.
- Tasteline's pivot to Aller Media may have shifted the competitive map since `MEMORY.md` was last updated.

**Pass-1 own gaps:**
- Did not deep-read the 100 Cloud Functions to confirm receipt-validation pattern absence beyond grep — possible a hidden helper exists.
- `StoreSubmissionChecklist` doc not opened — may already document SiwA + demo account.
- BUT-678 (in-app-review) trigger logic verified at 4-5★ + 90-day floor; whether the "happy moment" gating actually fires correctly at runtime not tested.
- 132 view files with 132 distinct rebuild patterns (per Wave-1) means there could be hidden monetization-relevant views I missed.
- Norwegian/Danish/Finnish localization cost estimate (§7.5) is a guess; haven't surveyed translator marketplace.

---

## What this means in plain language

Maximum 8 bullets, no jargon, written as if explaining to a friend who doesn't code:

- Butlery has no paid features today and no app-store submission planned soon — that's a deliberate choice, so nothing here is broken right now.
- The plumbing for a "free vs paid" model is *more* ready than it looks: there's already a system that counts how many AI imports each user does and what it cost, which is the hardest piece to build.
- BUT the equivalent counter for image-to-recipe scans only lives in the app's memory — close the app, the count goes back to zero. If that ever became a paid limit, people would just force-quit to bypass it. One-day fix when needed.
- The store description is bland — it sells "weekly menu and shopping list" instead of "AI reads recipes from any photo, link, or TikTok video in Swedish". That's the single biggest free win in this whole report — one hour of copy work.
- The Swedish app-store subtitle is one character too long ("Recept, veckomeny & inköpslista" = 31 letters; max is 30). Apple will reject the upload. One-minute fix.
- If/when login with Google or Facebook is added, Apple requires "Sign in with Apple" in the same release — easy to forget, embarrassing to be rejected for. Worth knowing now so it gets remembered later.
- Strongest hidden strength: Butlery already has a "household" concept (a group of people that share meal planning and allergies). That's a ready-made foundation for a "Family Plan" subscription that competitors don't have.
- Recommendation if a paid version ever ships: start with $0.99 for 20 AI imports (one-time, no subscription) — cheapest way to learn whether people will pay, no commitment, easy to refund, doesn't anger free users.

---

## Phase 1 deliverables checklist

- [x] Executive summary with overall score (out of 100) — 68/100
- [x] Detailed findings for all 7 dimensions with file:line references (≥50 unique refs — count below)
- [x] Issue classification (Critical/High/Medium/Low) with counts — 0 / 6 / 11 / 8
- [x] Entitlement architecture assessment — §1
- [x] Schema extensibility evaluation — §2
- [x] Table-stakes feature checklist (implemented / missing) — §3 with 30+ rows
- [x] Competitive positioning matrix — §4 (8 competitors × 21 features)
- [x] Differentiation and moat analysis — §4
- [x] App store rejection risk matrix — §5 (Apple top-10)
- [x] Demo account readiness assessment — §5.3
- [x] Revenue infrastructure prerequisites — §6
- [x] Market positioning evaluation — §7
- [x] Phase 2 preparation section with issue grouping — Sprints A-E
- [x] Strategic monetization opportunities ≥6 — SO-1..8 (8 delivered)
- [x] What's missing — entitlement infrastructure ≥8 — EM-1..12 (12 delivered)
- [x] Plain-language summary ≤8 bullets, no jargon
- [x] Zero code changes
- [x] Wrote to `docs/analysis/runs/2026-05-claude-deep/10-monetization.md` only

---

## Summary stats

- **Unique `file_path:line_number` references:** ~75 (target ≥50 — comfortably exceeded).
- **30%-on-what's-missing target:** met — §EM-1..12 (12 missing-infrastructure findings) + competitive feature gaps in §4 matrix + missing `paywall/upgrade/entitlement` widgets across multiple sections.
- **Critical: 0** (zero live defects; user has explicitly deferred submission).
- **High: 6** (subtitle char-overrun + OCR in-memory + analytics frozen at `'free'` + IAP package missing + SiwA forward + reviewer demo account missing).
- **Medium: 11**.
- **Low: 8**.
- **Strategic monetization opportunities: 8** (SO-1..8).
- **Missing-entitlement findings: 12** (EM-1..12).
- **Sister-run claims falsified:** 3 (live recipe scaling exists; cooking timer infra exists though auto-extract doesn't; OCR tracker is in-memory enforcement-bypass).
- **Sister-run claims confirmed:** ~12 (no IAP package; no `subscriptionTier` field; rate limits hardcoded; no paywall UI; no conversion events; no receipt-validation function; SiwA mandatory when other social login lands; description undersells AI; etc).
- **Knowledge files consulted:** none assigned to this prompt; cross-referenced 3 memory files + Wave-2 deep `06-user-experience.md` + sister `2026-05-claude/10-monetization.md`.

---

*End Pass 1 — investigator: Claude (Opus 4.7, 1M context). Final score 68/100. 6 HIGH (1 already a submission blocker today: subtitle char-count). 8 strategic opportunities including the "pay-per-AI-import + Family Plan via existing HouseholdService" combination as the recommended first-experiment + first-recurring-product. 12 entitlement-infrastructure gaps. Sister run scored 70/100; deep pass 68/100 — small downgrade for two sister-missed gaps (in-memory OCR tracker; frozen `subscription_tier` analytics property).*

---

## Pass 2 — Critic Findings

**Pass:** 2 of 2 (critic)
**Critic:** Claude (Opus 4.7, 1M context) — independent verification + blind-spot hunt
**Date:** 2026-05-04
**Mode:** Read-only verification of Pass 1's 84 file:line refs + 30%+ time on monetization blind spots Pass 1 missed.

### A. Verification of Pass 1's load-bearing claims

| # | Pass 1 claim | Pass 2 verdict | Evidence |
|---|---|---|---|
| V1 | `OCRUsageTracker` is in-memory only (`ocr_usage_tracker.dart:8-17`) | **CONFIRMED** | Lines 8-17 are plain Dart fields; `recordUsage()` (`:35-59`) only mutates `_dailyRequestCount` / `_monthlyRequestCount` / `_providerUsage` — zero Firestore / SharedPreferences / Drift writes anywhere in the 124-LOC file. Force-quit reset is real. |
| V2 | `OCRUsageTracker` 07-ai-llm-quality flagged as "dead code (zero callers)" — reconcile | **PROMPT FRAMING IS WRONG** | 07-ai-llm-quality.md line 263 lists it under "Client-side" features (not dead code); D5-LOW-1 (line 276) explicitly says "**in-memory only — no persistence across app restarts**" — same finding as Pass 1, NOT a "dead code" claim. Caller graph is live: `ocr_extraction_service.dart:13` imports it; `:157` instantiates; `:199` declares; `:253` exposes via `_recordUsage`; `:274,290,301,316,331` invoke for cache_hits / ocr_space / google_vision / tesseract paths. `OCRExtractionService` itself is wired into `lib/services/import/photo_import_strategy.dart:57,67,70` for the production photo-import flow. Pass 1's claim stands; the user prompt's "07 said dead code" is a misread of D5-LOW-1. **Reconciliation: both reports independently identified the in-memory weakness; neither called it dead.** |
| V3 | `subscription_tier` user property bootstrap defaults to `'free'` (`user_property_bootstrap.dart:37,54,62-67`) and has no business-event re-emit | **CONFIRMED** | Line 37: `String subscriptionTier = 'free'` default. Line 54: `emitSubscriptionTier(subscriptionTier)`. Lines 62-67: `emitSubscriptionTier()` exists, `_safe`-wrapped. `grep emitSubscriptionTier` across `lib/`: **only 1 production caller** = `user_property_bootstrap.dart:54` itself. `grep emitAtSessionStart`: only `lib/main.dart:802` calls it, and `main.dart:802-807` does NOT pass `subscriptionTier:` → falls through to default `'free'`. 100% of users emit `'free'` 100% of the time. Pass 1 verified. |
| V4 | `HouseholdService` substrate for Family Plan (`household_service.dart:14-46`) | **CONFIRMED** | Lines 14-46 read live. `getHousehold()` (`:23-31`) uses `firstWhere((c) => c.isHousehold)`. `getHouseholdMemberIds()` (`:37-44`) returns `household.allMemberIds` including owner. Maps cleanly to "owner pays family tier → all members inherit entitlement" as Pass 1 claims. Real substrate. |
| V5 | iOS subtitle 31 chars > Apple's 30-char limit | **CONFIRMED** | File is 32 bytes UTF-8 (`Recept, veckomeny & inköpslista`); `ö` is 2-byte multibyte. Decoded character count = **31** (Apple counts characters, not bytes). One char over. Submission blocker stands. |
| V6 | Live recipe scaling exists per Pass 1 falsification of sister | **CONFIRMED** | `widgets/common/input/portion_scaler{,_logic,_ui}.dart` all exist. `recipe_detail_content.dart:23` declares `final List<String> scaledIngredients`; `:577` uses `InputComponents.portionScaler`. Live in `cooking_mode_view.dart:259,261,317`, `recipe_detail_view.dart:614`, `recipe_detail_tablet_content.dart:116`. Sister's "Partial" was wrong. |
| V7 | `StepTimerService` exists at `lib/services/cooking/step_timer_service.dart` | **CONFIRMED** | File exists. `lib/services/cooking/` contains exactly 2 files: `step_timer_service.dart`, `substitution_suggestion_service.dart`. Pass 1's claim infra-exists-but-auto-extract-missing is internally consistent (no instruction-text regex visible). |
| V8 | Server-side OCR rate limit is per-minute, not per-month — so 500/month claim from `OCRUsageTracker` only enforced client-side | **CONFIRMED** (added context) | `functions/src/middleware/rate_limiter.ts:70-74`: `ocrRecipeImage` = `maxTokens: 5, refillRate: 2, refillIntervalMs: 60000` — **5 tokens with 2/minute refill**. Anti-burst, NOT monthly cap. The "free tier = 500 OCR/month" semantic Pass 1 worried about has zero server enforcement. Strengthens Pass 1's gap claim. |

**Verification verdict:** All 7 load-bearing Pass-1 claims hold. The user-prompt framing of "07 flagged as dead code" was incorrect — both reports independently flagged in-memory persistence weakness, not call-graph deadness. Pass 1 cited 75-84 file:line refs; spot-checked 12 across 6 distinct files (subtitle, OCR tracker, OCR extraction service, photo import strategy, user property bootstrap, main.dart, household service, server rate limiter, portion scaler set, cooking dir listing) — zero misreads.

### B. Blind spots — IAP commercial mechanics Pass 1 underweighted

Pass 1's 7 dimensions cover **technical readiness** thoroughly (entitlements, schema, paywall UI, receipt validation) but ship-zero-coverage on the **commercial / legal / margin** layer. For an indie planning EU/Nordic launch, these are launch-blocking when surfaced and trivially-skippable when not. Pass 1 score should drop ~3 points to reflect the missing dimension.

#### B1 — Platform fee margins (Apple/Google 15% vs 30%) — **HIGH-equivalent strategic gap**
Pass 1 cites RevenueCat MTR fees (~$0.35/MTR after 10k MTR) but **never names the 30% / 15% Apple+Google take-rate**, which is the single largest input to unit economics:
- **Apple App Store Small Business Program (ASBSP)**: 15% rate for developers earning <$1M/year *across all apps from same legal entity*. Auto-applied when org enrolls. Butlery as a solo-founder shop almost certainly qualifies day-one.
- **Apple standard rate**: 30% Year 1 of subscription per user; **drops to 15% after 12 consecutive months** of the same user being subscribed.
- **Google Play**: 15% for first $1M/year per developer account, 30% above. Subscriptions: 15% from day one (was 30% pre-2022).
- **Net implication:** at $0.99 pay-per-AI-import (SO-1), Butlery's gross is **$0.99 → $0.84** (15% small-biz) → minus VAT (see B6) → minus RevenueCat $0.005/MTR → minus LLM cost ~$0.03/import → net **~$0.70-0.80**. This is the actual unit economics, missing from §6 entirely.
- *Effort: 1 hour to add to monetization framing; 1 day to register ASBSP + family-plan tax exemption when subscriptions ship.*

#### B2 — Refund flow handling — **MEDIUM**
Apple permits user-initiated refunds via reportaproblem.apple.com; Apple Server Notifications V2 sends `REFUND` event. Google sends `SUBSCRIPTION_REFUNDED` via RTDN. **Pass 1's Cloud Function inventory (§6.5) doesn't mention refund webhooks at all** — only "receipt validation" and "scheduled expiry check". Without refund handling:
- User refunds an annual sub at month 11 → entitlement stays granted in Firestore until next "scheduled expiry check" (likely runs daily) → user gets 1 day of free premium access post-refund.
- Worse: if refund grants are not subtracted from `creditsRemaining` for consumables (SO-1 pay-per-import), refunded credits stay usable. **Gameable.**
- RevenueCat handles this in their dashboard automatically and re-emits webhooks — another point favoring the strategic recommendation but **only if the webhook handler subtracts consumable credits, which Pass 1 didn't spec.**
- *Effort: 4 hours to spec; built into RevenueCat onboarding (EM-4); separate handler for consumables.*

#### B3 — Subscription state restoration after reinstall — **HIGH**
Pass 1 mentions "restore-purchase" 4 times (§1.6, §6.1, §6.2, EM-9) as a UI button to add. **Never specifies the actual flow.** The hard cases:
- **iOS reinstall / new device**: `SKPaymentQueue.restoreCompletedTransactions` returns historical transactions. App must verify each, find the most recent active one, hydrate Firestore. With anonymous-auth users (does Butlery support? **unverified — check `firebase_auth` integration**) restore breaks because the new install has a different anonymous UID, no link to the original purchase.
- **Cross-platform restore**: User buys on iOS, signs in on Android — Apple receipt is invisible to Google Play SDK. RevenueCat solves by storing entitlements server-side keyed on RC App User ID; without RC the app must do this itself.
- **Sign-out / sign-back-in**: Apple receipts are device-Apple-ID-bound, not app-user-bound. Sign out of Butlery → sign in as different user → that user gets entitlements they didn't pay for unless `originalTransactionId` is checked against current Firebase UID.
- This is a 1-2 day design problem masquerading as a 30-min UI button. Pass 1's effort estimates undercount by ~3-5 days.

#### B4 — Cross-platform entitlement sharing (web → iOS) — **MEDIUM**
Butlery is multi-platform (`pubspec.yaml:15 flutter_web_plugins`; macOS/Windows builds confirmed). **Apple §3.1.3(b) "Multiplatform Services"** explicitly permits selling subscriptions outside the App Store and consuming on iOS — but only if (a) user creates account in-app, (b) account is portable. Stripe-on-web + Apple-IAP-on-iOS is legal under this clause; Pass 1 didn't flag it.
- **Strategic implication:** Butlery could sell premium via Stripe on butlery.app web (avoiding 15-30% take), grant entitlement server-side, and surface on iOS without a paywall. **This is a 5-15% margin win** on every user who converts via web.
- **Risk:** Apple §3.1.3(b) requires no in-app encouragement to buy outside (no link, no banner). One naïve "cheaper on the web!" upsell card → rejection.
- *Effort: same as RevenueCat onboarding (~1 week) plus Stripe integration (~3 days). Big upside if web traffic is non-trivial.*

#### B5 — Promo code infrastructure — **LOW**
Apple offers (a) **promo codes** (100/version for free downloads only, not subs), (b) **offer codes** (custom one-time-use codes for free trials / discounts on subs, configured in App Store Connect, redeemed via `presentCodeRedemptionSheet`). Google has **promo codes** (managed in Play Console) and **subscription offers** (intro pricing).
- **Pass 1 covers none of this.** A "TIDIGABETA50" code for beta-list converts is a standard ASO tool. Without it, can't run influencer / press / podcast partnerships at scale.
- *Effort: 1 day Apple offer-code redemption sheet + 1 day Google promo-code SDK + 1 day server-side validation. Defer until paid SKUs exist.*

#### B6 — Education / discount eligibility — **LOW**
Apple and Google support **subscription offers** (intro / promo / win-back pricing), Apple specifically supports **eligibility verification via SHA256-signed nonce** for "subscriber for X months" gating. Education-discount specifically requires Apple Education program enrollment OR third-party verification (Sheerid, Verifico — typically $0.50/verification). Probably not worth it for Butlery's ICP (Swedish home cooks ≠ student-heavy demographic), but worth a single-line acknowledgment.
- *Effort: skip for v1.*

#### B7 — EU 14-day cooling-off (Consumer Rights Directive) — **MEDIUM, EU-specific**
Digital subscriptions in the EU are subject to the **14-day right of withdrawal** under Directive 2011/83/EU **unless** the consumer expressly waives it AND acknowledges the waiver during purchase. Apple+Google paywalls handle the platform-level UX; the **Butlery ToS must include the waiver clause and the IAP flow must surface a "I waive my withdrawal right and agree the service starts immediately"** equivalent (Apple+Google don't auto-include this in the IAP sheet itself — it must be in your in-app purchase confirmation).
- Pass 1's §5 (App Store Submission Risk) covers Apple's top-10 rejection reasons — does NOT cover EU consumer-law compliance, which is **enforced by national consumer agencies (Konsumentverket in Sweden), not by app stores**, but a complaint-driven removal can still surface to App Review.
- *Effort: 4 hours legal copy review with Swedish consumer-rights wording + 2 hours wiring confirmation flow. Cross-ref Prompt 11.*

#### B8 — Price localization (SEK / EUR / USD / NOK / DKK) — **MEDIUM**
Apple+Google handle currency conversion via **price tiers** — developer picks a base price tier, platform sets local equivalents. **But the PSYCHOLOGY of pricing differs**: $0.99 is a magic price point in USD; the equivalent SEK (~10 SEK) is NOT a magic price point — Swedish consumers anchor at 9 SEK / 19 SEK / 29 SEK / 49 SEK / 99 SEK. App Store Connect lets you **manually override per-market prices**. Pass 1's recommendation "$0.99 for 20 AI imports" is anchored in USD; the Swedish equivalent should be **9 SEK or 19 SEK** explicitly chosen, not auto-converted ~10.50 SEK.
- For a Swedish-first product (`MEMORY.md`: "Swedish is the app's UI language"), **pricing should be Swedish-anchored, not USD-anchored**. SO-1 should read "9 SEK / 20 imports (SE) | $0.99 / 20 imports (US)".
- *Effort: 1 hour pricing matrix; revisit per locale launch.*

#### B9 — VAT / OSS for EU SaaS — **MEDIUM, structural**
Apple and Google **act as merchant of record** for IAP — they collect and remit VAT in EU jurisdictions, which is a massive simplification (developer doesn't need OSS / IOSS registration for in-app purchases). **However:**
- This **only applies to IAP**, not Stripe-on-web (B4). If Butlery sells via Stripe directly, **Butlery becomes the merchant of record** and must register for OSS (One Stop Shop) in Sweden (free; Skatteverket portal) to remit VAT to all 27 EU states quarterly.
- Stripe Tax handles calculation but not registration.
- For B2B revenue (SO-4 grocer ads), VAT is reverse-charged (B2B intra-EU) — different rules, simpler.
- **Net implication for Pass 1:** if recommending pure-IAP path, ignore. If recommending hybrid (Stripe-on-web + IAP-on-mobile per B4), **OSS registration is a 1-day setup-and-forget** but must be planned before first euro.
- *Effort: 1 day setup if going Stripe; zero if pure IAP.*

#### B10 — Apple App Store Small Business Program enrollment — **LOW (action item)**
Per B1, the 15% small-biz rate is auto-applied **only after explicit enrollment** at developer.apple.com/app-store/small-business-program. Solo founders forget this — the default is 30%. Butlery should enroll BEFORE the first paid release so the lower rate applies from day one. Re-enrollment annually is automated if revenue stays <$1M.
- *Effort: 30 minutes online form. ROI: 50% margin lift on every IAP dollar.*

### C. Other Pass-1 gaps not in the prompt's hunt list

| # | Gap | Severity | Note |
|---|---|---|---|
| C1 | Free-trial implementation: Apple's `INTRODUCTORY_PRICE` (free trial) flows are RTDN-event-driven and require server-side trial-eligibility check (`appAccountToken` to prevent multi-trial abuse). Pass 1 mentions `trial_started` analytics constant but no eligibility logic. | MEDIUM | Bundled into RevenueCat path; DIY = 2 days. |
| C2 | Subscription lifecycle CF needs to handle **grace period** (failed renewal payment, Apple gives 16 days) and **billing retry** state. User has functional access during grace; Firestore must reflect `STATUS_IN_GRACE_PERIOD` not `STATUS_EXPIRED`. | MEDIUM | RevenueCat exposes via `entitlement.willRenew`. |
| C3 | Account-deletion ↔ subscription interaction: Apple §5.1.1(v) requires in-app account deletion. **Active subscription must be cancelled by user separately via Apple/Google settings — app cannot cancel sub on user's behalf.** Account-deletion flow in Butlery (`account_deletion_service.dart` per Pass 1 §5.5) needs to surface a "you have an active subscription, cancel it here first" warning OR allow deletion while sub continues to bill (orphaned sub — Apple frowns on this). | MEDIUM | UX copy + deep link to subs management. |
| C4 | Pass 1 §6.6 notes `$0.50/day, $10/month` LLM cost ceiling but doesn't compute the **break-even subscription price**: at $10 worst-case LLM + $0.005 RevenueCat + 15% Apple = price floor of ~**$12-14/mo** for "unlimited AI" tier to be cash-positive on heavy users. **This sets the lower bound on subscription pricing**, not pulled-from-thin-air SO-3 et al. | HIGH (strategic framing) | Recommend explicit unit-economics table in next pass. |
| C5 | No mention of **Stripe vs Adyen vs PayPal** for the web checkout path (B4). Stripe is default for indie EU; Adyen has lower per-tx fees at scale; PayPal adds friction but increases conversion in DE/NL. | LOW | Defer until web-checkout decision. |
| C6 | Sister-claim reconciliation in Pass 1 says "Sister missed `OCRUsageTracker` in-memory" — but the user prompt notes 07-ai-llm-quality DID flag it (D5-LOW-1). Pass 1 conflated "sister 10-monetization" with "all sister reports". The accurate framing: 10-monetization sister missed it; 07-ai-llm-quality sister caught it. Pass 1's §EM-7 attribution "Sister missed this" is technically true for *this* sister (10-monetization) but incomplete cross-report. | LOW (attribution polish) | Worth a clarifying sentence in any Phase 2 synthesis. |

### D. Score reconciliation

| Dimension | Pass 1 score | Pass 2 verdict | Adjustment |
|---|---:|---|---:|
| 1. Entitlement Architecture Readiness | 11.5 / 20 | Held; B3 (restore flows) deepens the gap by 0.5 | -0.5 |
| 2. Schema Extensibility for Subscriptions | 11.5 / 15 | Held | 0 |
| 3. Feature Completeness vs Table-Stakes | 14.0 / 20 | Held | 0 |
| 4. Differentiation | 13.0 / 15 | Held; B4 (web-side Stripe) is +0.5 hidden upside on the moat | +0.5 |
| 5. App Store Submission Risk | 9.5 / 15 | B7 (EU cooling-off) and C3 (account-deletion ↔ sub) are real future blockers; -0.5 | -0.5 |
| 6. Revenue Infrastructure Prerequisites | 6.0 / 10 | B1+B2+B5+C1+C2+C4 are all Pass-1 misses on the COMMERCIAL layer; -1.5 | -1.5 |
| 7. Market Positioning & ASO | 2.5 / 5 | B8 (Swedish-anchored pricing) is a gap; -0.5 | -0.5 |
| **Total** | **68.0** | | **-2.5** |
| **Pass-2 adjusted score** | | | **65.5 / 100** |

**Issue counts adjustment:**
- HIGH: 6 (Pass 1) + 2 (B1 platform fees, B3 restore flow) = **8**
- MEDIUM: 11 (Pass 1) + 6 (B2, B4, B7, B8, B9, C1, C2, C3 — net +6 after merging B5 down) = **17**
- LOW: 8 (Pass 1) + 3 (B5, B6, B10) = **11**
- C4 reframes a strategic finding (cost ceiling → price floor) — already counted in §6.6, no new add.

### E. Strengths Pass 1 captured well (preserve)

- Cross-reference rigor with sister 10-monetization and Wave-2 06-user-experience is solid.
- `ImportRateLimiter` framing as the most expensive pre-built monetization piece is accurate and well-evidenced.
- Plain-language summary genuinely jargon-free (rule check passed).
- HouseholdService-as-Family-Plan-substrate is a real strategic insight nobody else surfaced.
- Cook-snap "Wrapped" recap idea is the strongest organic acquisition lever in this codebase.

### F. Recommended Pass-1 amendments (for synthesis-pass author)

1. **Add §6.X (commercial mechanics)** covering B1 (platform fees), B2 (refunds), B3 (restore flow), C1 (free trial eligibility), C2 (grace period), C4 (price floor math).
2. **Add §5.X (regional compliance)** covering B7 (EU 14-day cooling-off), C3 (account deletion ↔ sub).
3. **Add B8 (Swedish-anchored pricing) to §7** — replace USD anchors throughout SO-1..8.
4. **Add B10 (ASBSP enrollment) to Quick Wins** — 30 min, 50% margin lift.
5. **Footnote SO-1** ($0.99 → 9 SEK; net ~$0.70 after fees+VAT+LLM) so unit economics are first-class not buried.
6. **Clarify Sister-claim attribution** (C6) — say "sister 10-monetization missed this; sister 07-ai-llm-quality flagged it (D5-LOW-1)".

---

## Pass 2 verdict: **PASS-WITH-AMENDMENTS — score 65.5/100 (down 2.5 from Pass-1's 68/100)**

Pass 1's technical-readiness analysis is rigorous, accurate, and load-bearing claims hold under verification (7/7 spot-checked claims confirmed live). The user-prompt's framing of a 07-ai-llm-quality contradiction is incorrect: both sister reports independently flagged the OCR in-memory weakness — neither called it dead code.

The score reduction reflects a single underweighted dimension: **commercial mechanics of IAP** (platform fees, refund handling, restore flows, free-trial eligibility, grace periods, EU consumer rights, regional pricing psychology, ASBSP enrollment, VAT/OSS structure). Pass 1 covered the engineering layer (paywall UI, receipt-validation function, entitlement state machine) but treated payments as if they were just another async API. They are commercial+legal+regulatory artifacts with their own rejection paths and margin profiles. For a Swedish-first indie planning EU launch, B1 (15% vs 30%), B3 (restore on reinstall), B7 (EU cooling-off), and B8 (Swedish-anchored pricing) are launch-affecting and absent.

Issue-count delta: **+2 HIGH, +6 MEDIUM, +3 LOW**. Final adjusted: **8 HIGH / 17 MEDIUM / 11 LOW / 0 CRITICAL** (deferred submission keeps Critical at zero — correct).

Pass 1 stands as the technical-readiness reference; Pass 2 amendments F1-F6 should be folded by any Phase-2 synthesis author before this report drives a monetization sprint. **Do not commit / do not edit Pass 1 prose** — append-only delta above.

*End Pass 2 — critic: Claude (Opus 4.7, 1M context). Verdict: pass-with-amendments. Score: 65.5/100 (Pass 1 self-scored 68; Pass 2 adjusts -2.5 for commercial-mechanics blind spot). 7/7 verified Pass-1 claims confirmed live. 10 blind-spot findings (B1-B10) + 6 cross-report gaps (C1-C6). Recommended 6 amendments (F1-F6) for synthesis-pass folding.*
