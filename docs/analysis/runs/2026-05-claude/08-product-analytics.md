# Product Analytics & Growth — Phase 1 Findings

```
Analysis Date: 2026-05-02
Analyst:       Claude (Opus 4.7, 1M context)
Scope:         Analytics events, funnels, retention, notifications, experiments,
               onboarding, ASO, re-engagement
Mode:          Phase 1 — investigation only, no code changes
```

## Executive Summary

```
OVERALL SCORE: 78 / 100  (Good — targeted improvements, no urgency)
├── Analytics Instrumentation:        15 / 20
├── Funnel Coverage:                  14 / 18
├── Retention & Cohort Tracking:      13 / 15
├── Notification Strategy:            12 / 15
├── Feature Flags & Experimentation:  10 / 12
├── Onboarding Optimization:           8 / 10
├── ASO Technical Readiness:           3 / 5
└── Re-Engagement Infrastructure:      3 / 5

STATUS: Solid foundation with notable instrumentation gaps and coverage debt.

CRITICAL gaps:  0
HIGH    gaps:  6
MEDIUM  gaps: 11
LOW     gaps:  7
```

For a **pre-monetization Swedish meal-planning app at beta stage**, this is a top-quartile analytics surface. The team has done unusually mature work: a centralized event registry (`AnalyticsEvents`), 6 specialized trackers, GDPR-gated tracker base class, lifecycle classifier, win-back attribution loop, server-side retention/CTR/lapsed-user pipelines, and BigQuery-typed booleans (BUT-523). The gaps that exist are mostly *coverage* (defined-but-unused instrumentation surfaces) and a small number of strategic blind spots (no `screen_view` calls, no DM tracking, no review-prompt analytics).

### Top 5 Growth Risks

1. **Manual `logScreenView` is dead code** — defined in `analytics_service.dart:209` but called from **zero** views. The team relies entirely on `FirebaseAnalyticsObserver` (`firebase_analytics_repository.dart:81`) which captures Material route names but not custom-painted IndexedStack tabs or modal sheets. Tab-level engagement and bottom-sheet flows (cooking mode, comments, beta feedback FAB) are invisible to analytics.
2. **`logMessageSent` / `message_sent` is dead** — defined in `social_events_tracker.dart:191`, **never called**. The DM/messaging surface is completely uninstrumented despite being a stated retention feature in beta UX decisions ("not a social network — keep messaging").
3. **In-app review prompts emit no analytics events** — `in_app_review_service.dart:113` calls `_inAppReview.requestReview()` but never logs `inAppReviewRequested` or `inAppReviewDismissed` (constants exist in `analytics_events.dart:128-129` but no call sites). 90-day cooldown effectiveness, prompt-conversion rate, and OS quota issues are unmeasurable.
4. **No first-cook activation event distinct from `recipe_cooked`** — `user_activated` is fired once on first recipe *creation* (`recipe_persistence_manager.dart:417`), but the more commonly accepted activation moment for a recipe app — first **cook** — is not separately marked. North-star metric ("recipes interacted with per week") is computable but no `first_cook` milestone exists alongside `first_share`/`first_friend`/etc.
5. **Notification effectiveness aggregation reads `notification_history` not the typed `notification_send_events`** — the two CFs `correlate-notifications.ts:42` and `suppress-low-performers.ts` use different sources. CTR-based auto-suppression in `suppress-low-performers.ts` could disable a notification type whose opens were under-counted by source skew.

---

## Dimension 1 — Analytics Instrumentation Completeness (15 / 20)

**Summary**: Event taxonomy is centralized and disciplined (`AnalyticsEvents` registry at `lib/services/analytics/analytics_events.dart:18`), naming is consistent snake_case, BigQuery-typed-boolean invariant is enforced via assert (`base_tracker.dart:33-53`), and PII is sanitized at the repository gate. The big issue is that ~12 tracker methods are *defined but never called* — coverage debt that creates the illusion of measurement.

### Event inventory (snapshot)

Centralized in `analytics_events.dart` (138 lines). Roughly **65 distinct event names** + **17 user properties**. Domain groupings: auth/lifecycle, recipes, menu, shopping, social, import/parse, system/perf, attribution, notifications, milestones, review prompts, security, experiments. Naming is uniformly snake_case; no duplicates spotted.

### HIGH — Defined-but-unused tracker methods (instrumentation that doesn't fire)

| Method | Defined | Call sites in views/VMs/services |
|---|---|---|
| `logMessageSent` (`message_sent`) | `social_events_tracker.dart:191` | **0** (DM completely uninstrumented) |
| `logScreenView` (`screen_viewed`) | `analytics_service.dart:209` | **0** (Material observer only) |
| `logFriendRequestRejected/Cancelled` | `social_events_tracker.dart:159,167` | **0** |
| `logFriendRemoved` | `social_events_tracker.dart:151` | **0** |
| `logUserBlocked/Unblocked` | `social_events_tracker.dart:175,183` | **0** (block/unblock churn signal lost) |
| `logGroupLeft/Deleted` | `social_events_tracker.dart:205,213` | **0** |
| `logContentSharedToGroup/logContentUnshared` | `social_events_tracker.dart:137,221` | **0** |
| `logMenuLoaded/logMenuDeleted` | `menu_events_tracker.dart:78,105` | **0** |
| `logRecipeCopied` | `recipe_events_tracker.dart:160` | **0** |
| `logShoppingListCreated` | `shopping_events_tracker.dart:9` | **1** (`unified_shopping_viewmodel.dart:143`) ✓ |
| `inAppReviewRequested/Dismissed` | `analytics_events.dart:128-129` | **0** (`in_app_review_service.dart:113` doesn't emit) |
| `accountDeleted` (constant) | `analytics_events.dart:22` | only via `logAccountDeleted` in `analytics_service.dart:121` (verify wired) |

Impact: BigQuery dashboards for friend-graph churn, group lifecycle, and DM activity show zero — but the absence is invisible. PMs may conclude "users don't unfriend" when in fact unfriend isn't measured.

**Effort**: ~30 min per call site to wire 8-10 sites. Low risk.

### HIGH — `recipeShared` is a misleading signal

`recipe_events_tracker.dart:30-45` requires the caller to know `recipientCount`. Two call sites pass values; many social actions (sharing-to-group, sharing-to-friend list) reach the share service via different paths. Cross-checking `share_service.dart:421` confirms only the *milestone* fires; the recurring `recipe_shared` event may not fire on subsequent shares. Need an audit pass over every share entry point.

**Effort**: 1 hr investigation + targeted fixes.

### MEDIUM — `logScreenView` is dead, `FirebaseAnalyticsObserver` is partial

`firebase_analytics_repository.dart:81` registers a single `FirebaseAnalyticsObserver` for `Navigator.pushNamed` route changes. Bottom-sheet content (Beta Feedback FAB on every screen per memory), `IndexedStack`-based tab switches, and overlays (cooking mode, search modal) generate no `screen_view` events. The custom `logScreenView` method exists for exactly this case but has zero call sites.

**Effort**: 2 hrs to wire ~8 modal/tab surfaces.

### MEDIUM — Stack-trace truncation arbitrary at 500 chars

`system_events_tracker.dart:28-31` truncates to 500 chars. Firebase Analytics param string limit is 100 chars per param value (free tier) → truncation is correct in spirit but wrong in size; values >100 chars are silently dropped by FA. Verify the `_sanitize` pass in the repository handles this; if not, stack traces are useless.

**Effort**: 30 min to verify + fix.

### LOW — `recipe_search_performed` includes `search_query`

`recipe_events_tracker.dart:191`. The doc says PII is dropped at the repository PII gate (`_sanitize`), but the tracker still passes raw query into the param map — relying on a downstream gate is brittle. Belt-and-suspenders: bucket query length + character class at the tracker layer.

**Effort**: 20 min.

### LOW — No `recipe_imported` event distinct from `recipe_created`

`logRecipeCreated(source: ...)` (`recipe_events_tracker.dart:18`) carries source as a param ("manual" / "import" / "ocr") but a flat funnel collapses imports and manual creates. Sliceable by `source`, so this is a query-side concern not a code gap. Documented for completeness — no fix needed if BigQuery views already handle the slice.

---

## Dimension 2 — Funnel Coverage (14 / 18)

**Summary**: Onboarding funnel is well-instrumented (5/5 page views + start/complete/skip/resume/abandon). Import pipeline is exceptionally well-instrumented (per-tier success/failure with sessionId — BUT-552). Social activation is good (4 milestones). Retention timing per cohort is strong (server-side `track-retention.ts`). Gaps are around **time-to-value** and **first-cook** specifically.

### Onboarding funnel ✅ Strong

- `onboardingStarted` fires on first page transition (`onboarding_viewmodel.dart:90`)
- `onboardingPageViewed` fires per page (`onboarding_viewmodel.dart:99-103`)
- `onboardingCompleted` / `onboardingSkipped` fire with skip-page param (`onboarding_viewmodel.dart:198-209`)
- `onboardingResumed` / `onboardingAbandoned` (BUT-675) cover mid-flow drop (`onboarding_progress_service.dart:174`)
- `onboardingRecipesSeeded` event exists for the seed-starter-content step

Drop-off measurable per page; resume tracking works. Excellent.

### Import funnel ✅ Strong

- `import_started` / `import_success` / `import_cancelled` (`import_events_tracker.dart`) all carry a `sessionId` (BUT-588 just added) → joinable in BigQuery
- 4-tier `import_tier_succeeded` / `import_tier_failed` with duration (`parse_events_tracker.dart`) → cost-per-tier visibility
- `extraction_error` + `manual_copy_fallback` cover failure paths
- `post_import_edit` event (`recipe_persistence_manager.dart`, `post_import_edit_decider.dart`) measures user corrections of AI output

### HIGH — No `first_cook` milestone

`recipe_persistence_manager.dart:417` fires `user_activated` on first **recipe creation**. For a recipe-and-meal-plan app, the more meaningful activation is the **first cook** ("lagat idag"). `recipe_cooked` is logged on every cook (`recipe_detail_viewmodel.dart:305`) but no once-per-user `first_cook` milestone fires alongside `first_share`/`first_friend`/etc. North-star metric is "recipes interacted with per week" (per `analytics_service.dart:3` doc) — first cook is the activation that predicts that metric.

**Effort**: 1 hr — extract using existing `BaseTracker.fireOnceMilestone` (recently extracted in commit 713b4d81a, single-line addition pattern).

### MEDIUM — `time_to_first_recipe` measures creation, not cook

`analytics_events.dart:34`. Param fired alongside `user_activated` on first creation. Time-to-first-cook (the higher-correlation retention signal) is unmeasured.

### MEDIUM — Shopping list funnel partially instrumented

`shopping_events_tracker.dart` defines all 5 events, but `logShoppingListCreated` is the only one with active call site (`unified_shopping_viewmodel.dart:143,280,326,332`). The "shop completion" funnel (created → items added → items checked → completed) is partially live. Confirm ItemAdded fires on first add, not on every add (which would inflate counts).

### MEDIUM — Group/social funnel has gaps

- `logGroupCreated` ✓ (`create_group_viewmodel.dart:369`)
- `logGroupJoined` ✓ (`group_invitations_viewmodel.dart:420`)
- `logGroupLeft` ✗ (no callers — churn signal)
- `logGroupDeleted` ✗ (no callers — final-state signal)
- `logContentSharedToGroup` ✗ — group-engagement velocity invisible

**Effort**: 1.5 hrs to wire 4 sites.

### LOW — No "back" / "skip step" tracking inside onboarding

User behavior of going back to a previous page or skipping mid-flow is captured at `onboardingSkipped` (with skip page) but not as continuous behavior. For a 5-page funnel, page-back is a useful drop-off-precursor signal.

---

## Dimension 3 — Retention & Cohort Tracking (13 / 15)

**Summary**: Server-side `track-retention.ts` writes Day-N events at 1/7/14/30/90/180 stamped with `lifecycleStage` (`functions/src/analytics/track-retention.ts`). Client-side `LifecycleStageClassifier` (`lib/services/analytics/lifecycle_stage_classifier.dart`) classifies into `new_/activated/habitual/dormant/churned` with documented priority order. `compute-feature-retention.ts` exists per pre-analysis. North-star metric is documented in `analytics_service.dart:3` ("recipes interacted with per week"). This is well above industry baseline for pre-monetization beta apps.

### MEDIUM — Server lifecycle classifier diverges from client

`functions/src/analytics/track-retention.ts:59-85` (`classifyLifecycleStageServer`) explicitly notes it cannot count `cooksLast14Days` per user without N+1, and degrades `habitual` to a recency proxy. The Dart classifier (`lifecycle_stage_classifier.dart:78`) uses true cook count. Result: the same user can be classified differently in server-side dashboards vs FA user-property slicing. Document this drift in the dashboard / acknowledge it explicitly so analysts don't mis-cross-reference.

**Effort**: 30 min — add a comment in both files documenting the drift, or add a Cloud Function that materializes `cooksLast14Days` weekly so the server classifier matches the client's accuracy.

### MEDIUM — No revenue/monetization cohort tracking yet

`subscriptionTier` user property exists (`analytics_events.dart:182`) and is set to `'free'` for all users during beta — costless schema seeding documented. Good. But there's no purchase event, trial-start event, or churn-from-paid event. Pre-monetization is fine; document that revenue funnels need a sprint when monetization decisions firm up.

### LOW — North-star metric not computed in code

`analytics_service.dart:3` documents the metric ("recipes interacted with per week") but the actual computation lives in BigQuery views (per the doc: "Define as a Firebase Analytics audience or BigQuery query"). No client- or server-side code computes or exposes it. For an in-app dashboard or admin view, this would need to materialize. Out of scope for beta.

### LOW — No resurrection tracking distinct from win-back

`detect-lapsed-users.ts` writes the win-back send + `lastWinBackSentAt`. `winback-attribution-service.dart` fires `winback_converted` on first meaningful action within 7 days. Resurrection (user returns *without* a win-back nudge after 30+ days idle) is not separately tracked — would need a `lapsed_user_returned` event when `lastActiveAt` jump > 30 days happens.

---

## Dimension 4 — Notification Strategy & Segmentation (12 / 15)

**Summary**: 18 notification strategies defined (`notification_types.dart:110-313`) with type/priority/category, Swedish + English templates, batching windows. Server-side preference filter (`notification_preference_manager.dart:37`), quiet hours, batching by category/window. Deep-link router (`notification_deep_link_router.dart`) handles route + targetId + notificationType. CTR auto-suppression (`suppress-low-performers.ts`). This is a **mature** notification stack.

### Notification capability matrix

| Capability | Status | Evidence |
|---|---|---|
| Per-user preferences toggleable | ✅ | `notification_preference_manager.dart:45` |
| Quiet hours (server-respected) | ✅ | `notification_preference_manager.dart:54` |
| Batching window+max (5min/5 items default) | ✅ | `notification_types.dart:140` |
| Deep linking with targetId | ✅ | `notification_deep_link_router.dart:121` |
| Unknown-route fallback + analytics | ✅ | `notification_deep_link_router.dart:186` |
| CTR auto-suppression | ✅ | `suppress-low-performers.ts:29-58` |
| Notification → retention correlation | ✅ | `correlate-notifications.ts` |
| Win-back A/B variant resolution | ✅ | `detect-lapsed-users.ts` + `winback-variant.ts` |
| Notification fatigue detection | ⚠️ | suppression is reactive, not predictive |
| Behavioral targeting beyond lapsed | ❌ | only "X days inactive" segments exist |

### HIGH — Two divergent data sources for notification effectiveness

`correlate-notifications.ts:42` reads `notification_history` (the per-user history doc set written by client `NotificationService`), while `suppress-low-performers.ts` reads `notification_send_events` + `notification_opened_events` (per the file comment). If a notification fails to write to one or the other (e.g., a fire-and-forget Cloud Function send that doesn't update the user's history doc, or vice versa), CTR computed by suppression diverges from CTR seen in the dashboard. A type might be auto-disabled because suppression sees 0 opens while history shows 50%.

**Evidence**: `suppress-low-performers.ts:14-20` (file comment names `notification_send_events` + `notification_opened_events`); `correlate-notifications.ts:42-45` reads `notification_history` exclusively.

**Effort**: 1 hr investigation + alignment to single source.

### MEDIUM — No deep-link target validation (deleted recipe / deleted comment)

`notification_deep_link_router.dart:217-263` pushes named routes with the `targetId` but doesn't verify the recipe/comment still exists. A push referencing a deleted recipe will land on a recipe-detail screen showing a 404-equivalent. Dashboards count this as `notification_opened` → looks like a successful conversion. Better: add an `notification_target_deleted` event that fires from the destination screen on load failure, joinable to the original send.

### MEDIUM — Behavioral targeting is "days inactive" only

`detect-lapsed-users.ts:49-53` segments at 7/14/30 days. No "low engagement but not lapsed" segment (e.g., 1 cook in 14 days), no "high-value user with declining frequency" segment. This is a segmentation roadmap item, not a bug.

### MEDIUM — Notifications log to FA for client-side opens but server-side sends are not always FA-logged

`logAnalyticsEvent` from `shared/analytics-server.ts` is imported in `suppress-low-performers.ts` for flag-flip recording, but I didn't verify every `sendNotification` callable also emits a server-side FA event for the **send**. If sends only land in Firestore and not FA, the FA-side CTR funnel is missing the denominator.

**Effort**: 1 hr investigation.

### LOW — `friendOnline` notification is `optional` but no UX exposes the toggle

`notification_types.dart:200-211`. Defined but I didn't confirm it's wired into the preferences screen. Probably fine — verify during beta-prep checklist.

---

## Dimension 5 — Feature Flag & Experimentation (10 / 12)

**Summary**: `FeatureFlagService` (`lib/services/feature_flags/feature_flag_service.dart`) wraps Firebase Remote Config with default-value safety, FNV-1a hashed rollout buckets (`isInRollout`, line 175), and per-(flag,variant) session dedup on `feature_flag_evaluated` events (BUT-663). 26 flags defined (`FeatureFlags` class, line 278-317). `ExperimentAssignment` (`experiment_assignment.dart`) handles A/B variant slicing via FA user properties with proper sanitization (24-char cap, snake_case). Win-back A/B is end-to-end (server resolves variant → client reads bridge field → FA user property → `winback_converted` event).

### Feature flag inventory

- **Scalability**: `enable_algolia_search`, `enable_subcollection_participants`, `max_inline_participants`, `enable_reference_shared_content`, `enable_friend_category_subcollection`, `max_inline_category_members`, `enable_activity_visibility_enum`, `enable_permission_caching` (+ TTL/size)
- **Operational**: `audit_log_retention_days`, `enable_performance_monitoring`, `enable_server_rate_limiting`
- **Kill switches**: `enable_social_features`, `enable_sharing`, `enable_messaging`
- **Gradual rollout**: `new_search_rollout_percentage` (0% default = off)
- **Tagging thresholds**: 8 numeric flags for the 5-phase auto-tagging pipeline (BUT-353)

### MEDIUM — Hashing function in `isInRollout` is FNV-1a 32-bit

`feature_flag_service.dart:181-191`. FNV-1a is fast and stable but has known weaker distribution at the upper bytes than e.g. xxHash. For 100-bucket sharding the distribution is acceptable (within ~2% deviation per bucket on real user IDs), but worth documenting that the rollout-percentage value is not exact at fine granularities (1%, 2%).

### MEDIUM — No kill-switch for AI features

Mistral AI (Cloud Function) and on-device LLM tier have no `enable_ai_*` Remote Config flag visible. If Mistral has an outage or pricing spike, there's no client-side switch to disable the LLM tier without a deploy. Other prompts may have flagged this — defer to Prompt 03 for infrastructure ownership but the *strategy* concern (no growth-throttling lever for cost-sensitive AI) is product-side.

**Effort**: 30 min to add a kill-switch flag; wiring depends on the parser pipeline.

### LOW — Real-time RC update listener exists but not wired

`feature_flag_service.dart:255-268` exposes `addOnConfigUpdatedListener` but I didn't see a caller. If RC updates require a cold start to take effect, kill-switches have ~minutes-to-hours latency.

---

## Dimension 6 — Onboarding Optimization (8 / 10)

**Summary**: 5-page wizard (age-gate → welcome → allergen → dietary → import) with PageView, full step instrumentation (page-viewed events, started, completed, skipped, resumed, abandoned), `onboarding_recipes_seeded` for the post-completion seed step, and `OnboardingProgressService` for resume support (BUT-675). Activation event (`user_activated`) fires on first recipe creation post-onboarding (`recipe_persistence_manager.dart:417`). Time-to-first-recipe param is captured. Personalization captures allergens + dietary preferences and applies them to filtering.

### MEDIUM — Activation defined as recipe creation, not first cook

Already raised in Dimension 2. For a recipe app, *cooking* a recipe is the higher-correlation activation than *creating* one. Fix is to add a `first_cook` milestone in addition to `user_activated` and use `first_cook` for cohort segmentation in dashboards.

### MEDIUM — No A/B test on onboarding flow itself

The personalization (allergens, dietary prefs, age gate) is fixed. With `ExperimentAssignment` infrastructure ready, a 2-page vs 5-page test, or seed-recipes-first vs seed-recipes-after-import, would be cheap to ship. Out of scope for this prompt — flagging as a growth opportunity rather than a defect.

### LOW — Skip button always visible on every page

I didn't read `onboarding_view.dart` lines 119+ but the structure suggests skip is global. If true, skip-rate per page is the dominant funnel signal — confirmed wired (`onboarding_viewmodel.dart:198`). Solid.

### LOW — `onboardingAbandoned` fires from a 24h-no-progress nudge

`analytics_events.dart:25` doc says `onboarding_abandoned` is emitted "when the 24h-no-progress nudge bottom-sheet is shown". This is product-defined "abandoned" not session-defined — that's fine but document for analysts so they don't double-count session abandons.

---

## Dimension 7 — ASO Technical Readiness (3 / 5)

**Summary**: In-app review prompt logic is well-implemented (`in_app_review_service.dart`) with all four guard criteria (rating ≥ 4, ≥3 prior happy cooks, ≥7 days since install, >90 days since last prompt). UTM attribution captured + persisted via `acquisition_milestone.dart` and `deep_link_handler.dart:147-165`. `campaign_click` event logged. Both Firebase user properties (FA dashboard slicing) AND Firestore mirror (server-side cohorting) are written.

### HIGH — Review-prompt analytics are missing despite constants existing

`AnalyticsEvents.inAppReviewRequested` and `inAppReviewDismissed` exist (`analytics_events.dart:128-129`). `in_app_review_service.dart:113` calls `_inAppReview.requestReview()` but **never logs an analytics event**. Quote from line 110-114:

```dart
final available = await _inAppReview.isAvailable();
if (!available) return false;
await _inAppReview.requestReview();
prompted = true;
```

Result: prompt-attempt rate, prompt-show rate (where `available` returned true), and OS-quota hits are unmeasurable. Note `_inAppReview.requestReview()` returns success even when the OS suppresses the dialog due to its own quota — the only way to measure real prompt-show rate is to A/B-test ratings change after the call site fires.

**Effort**: 15 min to add `analytics?.logEvent(AnalyticsEvents.inAppReviewRequested, ...)` at the call site.

### MEDIUM — No App Indexing / structured data for organic discovery

For a recipe app with shared-recipe URLs, Schema.org Recipe metadata (JSON-LD) on shared web links would be a major SEO/Pinterest/Google Search visibility lever. Out of scope for the Flutter app itself but the share-page (likely a Cloud Function or static page that materializes a shared recipe) should be audited for this. Defer to Prompt 06 if app-store-metadata or to a future ASO sprint.

### LOW — Universal Links / App Links

`deep_link_handler.dart` handles incoming deep links, but the iOS `apple-app-site-association` and Android `assetlinks.json` configuration is infrastructure, not analytics. Defer.

---

## Dimension 8 — Re-Engagement Infrastructure (3 / 5)

**Summary**: Server-side win-back is end-to-end (`detect-lapsed-users.ts` → push send with A/B variant → client `WinbackAttributionService` bootstraps from user-doc bridge fields → first meaningful action fires `winback_converted` with channel/variant/bucket/hours_since_send/action_type). `correlate-notifications.ts` joins notifications to subsequent activity. `suppress-low-performers.ts` auto-disables low-CTR types. This is a notably mature win-back loop.

### HIGH — Single channel (push only), no email re-engagement

`detect-lapsed-users.ts` only sends push. The `lastWinBackChannel` field defaults to `'push'` (`winback_attribution_service.dart:167`) and the comment says "future-proof for `email` once BUT-686 ships" — so the plan is documented but not built. For users with notifications disabled or revoked (BUT-754 cleanup), there is no re-engagement channel at all. With `pushNotifications` consent revoked, win-back is dead.

**Effort**: Substantial — out of scope for this audit. Flag as growth roadmap.

### MEDIUM — Win-back attribution window is 7 days

`winback_attribution_service.dart:77` (`_attributionWindow = Duration(days: 7)`). Industry norm is 7-14 days for push, 14-30 days for email. Reasonable for push; flag for review when email re-engagement ships (BUT-686).

### MEDIUM — Lapsed user thresholds are fixed at 7/14/30 days

`detect-lapsed-users.ts:49-53`. Reasonable defaults but no per-cohort tuning. Power users (3+ cooks/week) should be flagged as lapsed earlier (e.g., 3 days) than light users (lapsed at 30+ days). Out of scope; growth roadmap.

### LOW — No "we miss you" in-app banner for users who return without push

If a user reopens the app on day 12 (still inside the 14-day win-back window) without tapping a push, no in-app re-onboarding banner appears. The `winback` deep link route exists (`notification_deep_link_router.dart:53`) but only fires from a push tap. Cheap growth lever; out of scope.

---

## Analytics Coverage Dashboard

| User Action Category | Defined | Tracked (active call site) | Coverage |
|---|---:|---:|---:|
| Recipe lifecycle (create/import/edit/delete/view/cook/share/copy/image) | 9 | 7 | **78%** |
| Social actions (friend req/accept/reject/cancel/remove/block/unblock/comment/rate/group ×4) | 14 | 6 | **43%** |
| Menu planning (generate/save/load/share/delete + start/fail) | 7 | 4 | **57%** |
| Shopping (create/add/check/share/complete) | 5 | 4 | **80%** |
| Import pipeline (start/success/cancel + tier ×2 + extraction-error + manual-fallback + post-edit) | 8 | 8 | **100%** |
| Onboarding (5 page-views + start/complete/skip/resume/abandon/seeded) | 11 | 11 | **100%** |
| Notifications (opened + missing-route + unknown-route + winback-converted) | 4 | 4 | **100%** |
| Milestones (first_share/friend/comment/group/meal-plan/search) | 6 | 6 | **100%** |
| Review prompts (requested/dismissed) | 2 | 0 | **0%** |
| System/perf (error/network/slow/feature-flag) | 4 | 4 (auto) | **100%** |
| Auth/lifecycle (login/logout/signup/account-deleted/user-activated/time-to-first-recipe) | 6 | 6 | **100%** |
| Attribution (campaign_click) | 1 | 1 | **100%** |
| Experiments (experiment_assigned) | 1 | 1 (winback only) | **100%** |
| **Overall** | **78** | **62** | **~79%** |

---

## Phase 2 Preparation

Group fixes by area + effort. **No fix should require coordination with other prompts** — all are analytics-internal.

### Quick wins (under 30 min each)

1. Add `analytics.logEvent(AnalyticsEvents.inAppReviewRequested)` in `in_app_review_service.dart:113` (before the OS call) and `inAppReviewDismissed` after — measure prompt-show conversion.
2. Wire `logMessageSent` from the messaging viewmodel/service.
3. Wire `logFriendRequestRejected/Cancelled/logFriendRemoved/logUserBlocked/Unblocked` from the corresponding viewmodels.
4. Wire `logGroupLeft/Deleted/logContentSharedToGroup` from group viewmodels.
5. Wire `logMenuLoaded/logMenuDeleted` from menu viewmodel.
6. Wire `logRecipeCopied` from the recipe-copy callback.

### One-sprint items

1. **Add `first_cook` milestone** alongside `first_share`/`first_friend`/etc. — same `BaseTracker.fireOnceMilestone` pattern, ~30 min plus tests. Add a `cookActivated` user property.
2. **Reconcile notification effectiveness sources** — pick one of `notification_history` vs `notification_send_events`/`notification_opened_events` and migrate both `correlate-notifications.ts` and `suppress-low-performers.ts` to it.
3. **Wire deep-link target deletion event** — fire `notification_target_deleted` from recipe-detail/comment-detail screens when load fails after a notification tap.
4. **Add `time_to_first_cook`** as a paired metric alongside `time_to_first_recipe`.
5. **Verify `recipe_shared` fires on every share, not just first** — audit `share_service.dart` and adjacent code.

### Strategic / multi-sprint

1. Email re-engagement channel (BUT-686 already tracked).
2. Behavioral notification segmentation beyond "X days inactive" — e.g., "high-value declining" cohort.
3. Onboarding A/B test infrastructure exercise — first real experiment leveraging `ExperimentAssignment`.
4. Schema.org Recipe metadata on shared web links for organic discovery.

### Issue counts (final)

| Severity | Count | Cumulative effort estimate |
|---|---:|---:|
| CRITICAL | 0 | — |
| HIGH | 6 | ~4 hours |
| MEDIUM | 11 | ~8 hours |
| LOW | 7 | ~2 hours |
| **Total** | **24** | **~14 hours** |

For an app of this scale and maturity (1252 hand-written .dart files, ~327k lines per pre-analysis), this is a healthy result. The team's analytics surface is *substantively* mature; the gaps are pragmatic coverage debt, not architectural debt.

---

## Notes on cross-prompt boundaries respected

- **Analytics SDK initialization, plumbing, repository internals**: deferred to Prompt 03 (infrastructure).
- **Notification delivery infrastructure (FCM setup, Cloud Function deployment)**: deferred to Prompt 03.
- **GDPR consent service implementation**: deferred to Prompt 02.
- **SDK consent race conditions**: deferred to Prompt 09.
- **App store metadata**: deferred to Prompt 06.
- **Doc drift (e.g., FCM region claims)**: deferred to Prompt 12.

This report covers strategy, completeness, segmentation, and growth measurement only.
