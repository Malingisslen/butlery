# BUTLERY PRODUCT ANALYTICS & GROWTH ANALYSIS — PHASE 1 FINDINGS

```
Analysis Date: 2026-02-26
Analyst: Claude (Opus 4.6) — 3 parallel exploration agents + report synthesis
Scope: Analytics instrumentation, funnels, retention, notifications, experimentation, onboarding, ASO, re-engagement

OVERALL SCORE: 46/100

+-- D1  Analytics Instrumentation:       11 /20
+-- D2  Funnel Coverage:                  6 /18
+-- D3  Retention & Cohort Tracking:      4 /15
+-- D4  Notification Strategy:           11 /15
+-- D5  Feature Flags & Experimentation:  8 /12
+-- D6  Onboarding Optimization:          3 /10
+-- D7  ASO Technical Readiness:          2 /5
+-- D8  Re-Engagement Infrastructure:     1 /5

STATUS: Needs Work

CRITICAL ISSUES: 4 found
HIGH PRIORITY:   8 found
MEDIUM PRIORITY: 10 found
LOW PRIORITY:    6 found

TOP 5 GROWTH RISKS:
1. Onboarding is a complete blind spot — zero analytics on a 4-page flow that determines first-session retention
2. Most analytics events are defined but never wired — 24 of 42 tracker methods have no call sites in ViewModels/Views
3. No retention or cohort tracking — impossible to measure day-1/7/30 retention or identify what drives long-term engagement
4. No re-engagement infrastructure — lapsed users disappear with no win-back mechanism
5. No in-app review prompt — missing the primary mechanism for organic App Store growth
```

---

## Dimension 1: Analytics Instrumentation Completeness — 11/20

**Summary**: Butlery has a well-architected analytics system with 7 tracker modules, GDPR consent checking, and a clean facade pattern. However, roughly 57% of defined tracker methods are never called from ViewModels or Views, creating extensive blind spots in core user flows.

### Architecture (Strong)

The analytics stack is cleanly layered:
- `AnalyticsService` facade (`lib/services/analytics_service.dart:15`) delegates to 6 specialized trackers
- `BaseTracker` (`lib/services/analytics/trackers/base_tracker.dart:6`) provides GDPR consent checking via `ConsentService`
- `FirebaseAnalyticsRepository` (`lib/repositories/firebase/firebase_analytics_repository.dart:11`) implements Firebase Analytics
- Analytics collection disabled in debug mode (`firebase_analytics_repository.dart:28`)

### Event Inventory

**42 event types defined across all trackers:**

| Tracker | Events Defined | Events Wired | Coverage |
|---------|---------------|-------------|----------|
| RecipeEventsTracker | 8 | 2 | 25% |
| ImportEventsTracker | 4 | 3 | 75% |
| MenuEventsTracker | 7 | 5 | 71% |
| ShoppingEventsTracker | 5 | 0 | 0% |
| SocialEventsTracker | 4 | 2 | 50% |
| SystemEventsTracker | 3 | 1 | 33% |
| AnalyticsService (direct) | 11 | 5 | 45% |
| **Total** | **42** | **18** | **43%** |

### Wired Events (actually called from ViewModels/Views)

| Event | Call Site | Tracker |
|-------|-----------|---------|
| `recipe_deleted` | `recipe_detail_viewmodel.dart:213` | Recipe |
| `recipe_cooked` | `recipe_detail_viewmodel.dart:269` | Recipe |
| `menu_generation_started` | `menu_viewmodel.dart:99` | Menu |
| `menu_generated` | `menu_viewmodel.dart:114` | Menu |
| `menu_generation_failed` | `menu_viewmodel.dart:133` | Menu |
| `menu_saved` | `menu_viewmodel.dart:269` | Menu |
| `menu_shared` | `menu_viewmodel.dart:289` | Menu |
| `friend_request_sent` | `friends_viewmodel.dart:166` | Social |
| `friend_request_accepted` | `friends_viewmodel.dart:199` | Social |
| `import_started` | `receive_share_view.dart:89` | Import |
| `import_success` | `receive_share_view.dart:155` | Import |
| `extraction_error` | `receive_share_view.dart:175,199` | Import |
| `app_opened` | `main.dart:502` | Direct |
| `app_backgrounded` | `main.dart:524` | Direct |
| `login` | via auth flow | Direct |
| `signup` | via auth flow | Direct |
| `logout` | via auth flow | Direct |
| `slow_operation` | `menu_viewmodel.dart:122` | System |

### Unwired Events (defined but never called)

| Event | Tracker | Severity |
|-------|---------|----------|
| `recipe_viewed` | Recipe | **CRITICAL** — most common user action, completely invisible |
| `recipe_created` | Recipe | **CRITICAL** — core conversion event, not tracked |
| `recipe_edited` | Recipe | HIGH — can't measure post-creation engagement |
| `recipe_shared` | Recipe | HIGH — social virality unmeasurable |
| `recipe_copied` | Recipe | MEDIUM |
| `recipe_image_uploaded` | Recipe | MEDIUM |
| `recipe_search_performed` | Recipe | HIGH — search is primary discovery mechanism |
| `screen_viewed` | Direct | HIGH — `logScreenView()` defined at `analytics_service.dart:147` but never called |
| `comment_created` | Social | HIGH — social engagement invisible |
| `recipe_rated` | Social | HIGH — quality signal unmeasurable |
| `shopping_list_created` | Shopping | HIGH — entire shopping feature invisible |
| `shopping_list_item_added` | Shopping | MEDIUM |
| `shopping_list_item_checked` | Shopping | MEDIUM |
| `shopping_list_shared` | Shopping | MEDIUM |
| `shopping_list_completed` | Shopping | MEDIUM |
| `manual_copy_fallback` | Import | LOW |
| `menu_loaded` | Menu | LOW |
| `menu_deleted` | Menu | LOW |
| `error_occurred` | System | MEDIUM |
| `network_error` | System | MEDIUM |

### Event Quality Assessment

**Naming**: Consistent `snake_case` convention across all events. No duplicates detected.

**Parameters**: Well-structured with typed parameters. Import events include `source`, `platform`, and error categorization (`firebase_analytics_repository.dart:337-355`).

**User properties** (`firebase_analytics_repository.dart:292-334`):
- `user_type`: new / casual / active / power_user (based on recipe count)
- `recipe_count_range`: 0, 1-5, 6-10, 11-20, 21-50, 50+
- `has_used_import`, `has_shared_recipe`, `has_marked_cooked`: boolean flags

### Issues

#### CRITICAL

**PA-01: recipe_viewed never tracked** — The most frequent user action has no analytics event
- Impact: Cannot measure content engagement, time spent reading recipes, or recipe discovery patterns
- Location: `recipe_events_tracker.dart:59-73` (defined), no call site in any ViewModel
- Fix: Wire `logRecipeViewed()` in `RecipeDetailViewModel.loadRecipe()`
- Effort: 30 min

**PA-02: recipe_created never tracked** — Core conversion event is invisible
- Impact: Cannot measure creation rate, source distribution (manual vs import), or time-to-first-recipe
- Location: `recipe_events_tracker.dart:8-14` (defined), no call site
- Fix: Wire in recipe creation flow (RecipeFormViewModel or equivalent)
- Effort: 30 min

#### HIGH

**PA-03: Entire shopping flow has zero analytics wiring** — 5 shopping events defined, 0 called
- Impact: Entire shopping feature usage invisible; cannot prioritize shopping improvements
- Location: `shopping_events_tracker.dart:1-83` (all methods unwired)
- Fix: Wire all 5 events in shopping-related ViewModels
- Effort: 2h

**PA-04: Social engagement events (comment, rating) unwired**
- Impact: Cannot measure social feature adoption or correlation with retention
- Location: `social_events_tracker.dart:32-58` (defined, not called)
- Fix: Wire in comment and rating ViewModels
- Effort: 1h

**PA-05: logScreenView defined but never called from any view**
- Impact: No screen-level navigation analytics; Firebase automatic screen tracking only
- Location: `analytics_service.dart:147-163`
- Fix: Add screen view tracking via NavigatorObserver or per-view calls
- Effort: 2h (NavigatorObserver approach) or 4h (per-view approach)

**PA-06: recipe_search_performed unwired — search is primary discovery**
- Impact: Cannot analyze search patterns, zero-result queries, or filter usage
- Location: `recipe_events_tracker.dart:115-130`
- Fix: Wire in RecipeQueryViewModel search execution
- Effort: 30 min

#### MEDIUM

**PA-07: PII in analytics events — `recipeTitle` logged in `recipe_cooked` and `recipe_deleted`**
- Impact: Recipe titles may contain personal information (e.g., "Mormors köttbullar")
- Location: `firebase_analytics_repository.dart:219,262`
- Fix: Remove `recipe_title` parameter or hash it; keep `recipe_id` for analysis
- Effort: 30 min

**PA-08: `setUserProperties` called but not wired to regular sync**
- Impact: User properties may become stale (e.g., recipe_count_range not updated after deletion)
- Location: `analytics_service.dart:119-131`
- Fix: Call `setUserProperties` after recipe CRUD operations
- Effort: 1h

---

## Dimension 2: Funnel Coverage — 6/18

**Summary**: Only the import funnel has partial coverage (via `receive_share_view.dart`). The onboarding funnel has zero instrumentation. Social activation funnel has minimal coverage. No retention funnels exist.

### Onboarding Funnel — ZERO COVERAGE

```
[App installed] → [Welcome page] → [Allergen page] → [Dietary page] → [Import page] → [Complete]
                      ❌              ❌                 ❌               ❌              ❌
                   No tracking     No tracking        No tracking      No tracking    No tracking
```

The entire 4-page onboarding flow (`lib/views/onboarding/`) contains zero analytics calls:
- `onboarding_view.dart`: No analytics import, no tracking on page change (`line 64: onPageChanged: viewModel.setPage`)
- `onboarding_viewmodel.dart`: No AnalyticsService dependency, no tracking on `completeOnboarding()` (line 67)
- Skip action (`_skipOnboarding`, `onboarding_view.dart:228`) untracked
- Cannot measure: drop-off per page, time per page, skip rate, completion rate, selections made

### Import Funnel — PARTIAL COVERAGE

```
[Import button] → [URL/Photo selected] → [Parsing] → [Review] → [Save]
      ✅               ❌                  ✅/❌        ❌         ✅
  import_started    No tracking      extraction_error  No tracking  import_success
                                     (on failure only)
```

- `import_started` logged at `receive_share_view.dart:89` with source parameter
- `import_success` logged at `receive_share_view.dart:155` with recipe_length
- `extraction_error` logged at `receive_share_view.dart:175,199` with categorization
- **Missing**: import tier used (site config / regex / LLM), parsing duration, review-screen edits, cancellation at review
- **Missing**: Correlation between `import_started` and `import_success` (no shared session ID)

### Social Activation Funnel — MINIMAL COVERAGE

```
[First friend added] → [First share] → [First comment] → [First group]
        ✅                  ❌              ❌                ❌
  friend_request_sent   recipe_shared   comment_created   No group events
  (wired)              (NOT wired)     (NOT wired)       at all
```

- Friend request send/accept tracked in `friends_viewmodel.dart:166,199`
- `recipe_shared`, `comment_created`, `recipe_rated` all defined but unwired
- No group-related events defined at all (group_created, group_joined, content_shared_to_group)
- Cannot segment users by social engagement level

### Retention-Critical Funnels — MINIMAL

- `app_opened` tracks `session_count` (`main.dart:502-507`) — basic session counting
- `app_backgrounded` tracks `session_duration_seconds` (`main.dart:524-528`)
- No day-1 / day-7 / day-30 return events
- No feature engagement depth tracking
- No churn risk signals

### Issues

#### CRITICAL

**PA-09: Onboarding funnel has zero analytics — complete blind spot**
- Impact: Cannot measure where new users drop off; 80% of mobile users churn within 3 days and this is unmeasurable
- Location: `lib/views/onboarding/` (4 pages), `lib/viewmodels/onboarding_viewmodel.dart`
- Fix: Add page_viewed, page_completed, onboarding_completed, onboarding_skipped events
- Effort: 2h

#### HIGH

**PA-10: Import funnel missing start-to-end correlation**
- Impact: Cannot calculate import conversion rate per source or identify where users abandon
- Fix: Add session_id to import_started/import_success, add import_cancelled and import_tier events
- Effort: 2h

**PA-11: No group analytics events defined**
- Impact: Group feature adoption completely invisible
- Fix: Add group_created, group_joined, content_shared_to_group to SocialEventsTracker
- Effort: 2h

#### MEDIUM

**PA-12: No time-to-first-value tracking**
- Impact: Cannot measure how quickly new users reach their "aha moment" (first recipe saved)
- Fix: Track time from signup to first recipe_created, surface as user property
- Effort: 1h

---

## Dimension 3: Retention & Cohort Tracking Infrastructure — 4/15

**Summary**: Basic user property segmentation exists but there is no cohort tracking, no day-N retention measurement, no North Star metric, and no user lifecycle stage system.

### Cohort Definition Capability

**Partial**: User properties allow some segmentation:
- `user_type` (new/casual/active/power_user) at `firebase_analytics_repository.dart:298-305`
- `recipe_count_range` at `firebase_analytics_repository.dart:308-311`
- `has_used_import`, `has_shared_recipe`, `has_marked_cooked` boolean flags

**Missing**:
- No signup date cohort grouping (daily/weekly)
- No acquisition source tracking
- No first-action cohort (manual recipe vs import)
- User properties are set but not regularly updated

### Retention Metrics — NONE

- `app_opened` logs `session_count` — allows session frequency analysis in Firebase console
- `app_backgrounded` logs `session_duration_seconds` — allows duration analysis
- **No day-N retention events** (no `day_1_return`, `day_7_return`, etc.)
- **No resurrection tracking** (returning after long absence)
- **No feature-level retention** (cannot answer "do users who import retain better?")

### North Star Metric — UNDEFINED

No North Star metric is defined or tracked. Candidate metrics:
- "Recipes cooked per week" (tracked via `recipe_cooked` but not aggregated)
- "Weekly active users" (derivable from `app_opened` but not explicitly measured)

### User Lifecycle Stages — NONE

No lifecycle stage system exists:
- No definition of: new, activated, engaged, power_user, at-risk, churned
- No automated triggers based on lifecycle stage
- No stage transitions tracked

### Issues

#### CRITICAL

**PA-13: No day-N retention tracking**
- Impact: Cannot measure the most fundamental growth metric; impossible to know if product changes improve retention
- Fix: Implement server-side retention calculation via Cloud Function cron job checking last-active dates
- Effort: 1d

#### HIGH

**PA-14: No North Star metric defined or tracked**
- Impact: Team cannot align on what "success" means; all optimization is directionless
- Fix: Define North Star (suggest "recipes interacted with per week"), add tracking event, create dashboard
- Effort: 4h

**PA-15: User properties not kept in sync**
- Impact: Segmentation data drifts from reality (user deletes recipes but user_type stays "power_user")
- Fix: Call `setUserProperties()` after every recipe CRUD operation and on app_opened
- Effort: 2h

#### MEDIUM

**PA-16: No user lifecycle stage system**
- Impact: Cannot target re-engagement or identify at-risk users
- Fix: Define stages based on recency × frequency, track transitions
- Effort: 1d

---

## Dimension 4: Notification Strategy & Segmentation — 11/15

**Summary**: The notification system is architecturally excellent — 6 specialized managers, 13 notification strategies with Swedish/English localization, batching, quiet hours, offline queuing, and delivery tracking. The main gap is that deep link routing from notifications is incomplete and there is no framework for measuring notification effectiveness against retention.

### Notification Types Inventory

13 `NotificationStrategy` constants defined in `notification_types.dart:102-250`:

| Strategy | Type | Priority | Category | Localized |
|----------|------|----------|----------|-----------|
| `friendRequest` | immediate | critical | friends | sv/en |
| `friendRequestAccepted` | immediate | high | friends | sv/en |
| `friendOnline` | optional | low | friends | sv/en |
| `recipeShared` | immediate | high | recipes | sv/en |
| `recipeComment` | batchable | medium | recipes | sv/en |
| `tagShared` | immediate | high | recipes | sv/en |
| `collaborationInvite` | immediate | high | collaboration | sv/en |
| `collaborationEnabled` | immediate | high | collaboration | sv/en |
| `collaborationJoined` | silent | low | collaboration | — |
| `collaborationLeft` | silent | low | collaboration | — |
| `realtimeEdit` | silent | low | collaboration | — |
| `shoppingListUpdate` | silent | low | shopping | — |
| `activityDigest` | digest | low | social | sv/en |

### Notification Architecture (Strong)

6 specialized managers in `lib/services/notifications/modules/`:

| Manager | Responsibility | Key File |
|---------|---------------|----------|
| `NotificationContentManager` | Template rendering, variable substitution | `notification_content_manager.dart` |
| `NotificationPreferenceManager` | Category toggles, quiet hours, user filtering | `notification_preference_manager.dart` |
| `NotificationOfflineManager` | Queue + retry when offline | `notification_offline_manager.dart` |
| `NotificationBatchManager` | 5-minute batching window for comments/likes | `notification_batch_manager.dart` |
| `FCMTokenManager` | Token lifecycle, multi-device, topic subscriptions | `fcm_token_manager.dart` |
| `NotificationAnalyticsManager` | Delivery tracking, engagement metrics, daily aggregation | `notification_analytics_manager.dart` |

### Delivery Tracking (Good)

`NotificationAnalyticsManager` (`notification_analytics_manager.dart:14-497`) tracks:
- `recordNotificationSent` (line 33) — with batched writes for performance
- `recordNotificationDelivered` (line 63) — FCM confirmation
- `recordNotificationFailed` (line 84) — with error codes
- `recordNotificationOpened` (line 108) — user tap
- `recordNotificationDismissed` (line 139) — user swipe
- `recordNotificationActionTaken` (line 161) — action button clicks
- `generateDailyMetrics` (line 186) — aggregate reporting
- `getUserEngagementSummary` (line 239) — per-user analytics
- `cleanupOldData` (line 441) — 90-day retention policy

### Segmentation (Good)

- Per-user preference checking: `shouldReceiveNotification()` at `notification_preference_manager.dart:36`
- Batch user filtering: `filterUsersForNotification()` at `notification_preference_manager.dart:75`
- Quiet hours with midnight-spanning support: `_checkQuietHours()` at `notification_preference_manager.dart:139`
- Category enable/disable per user: `isCategoryEnabled()` at `notification_preference_manager.dart:285`
- Local preference caching with 10-minute expiry and offline fallback

### Deep Linking (Incomplete)

`_handleMessageOpened` in `notification_service.dart:376-396`:
- Records analytics for notification opened (line 388)
- **BUT**: Navigation comment says "This would need a BuildContext or navigation service" (line 382)
- Deep link data is in notification payload but actual screen navigation is not implemented
- `DeepLinkHandler` (`deep_link_handler.dart`) handles incoming app links but is not integrated with notification tap routing

### Issues

#### HIGH

**PA-17: Notification deep link routing not implemented**
- Impact: Users tap notifications but land on home screen instead of relevant content
- Location: `notification_service.dart:376-396`
- Fix: Integrate with `DeepLinkHandler` or `GoRouter` to route based on notification payload type/category
- Effort: 4h

**PA-18: No notification effectiveness correlation with retention**
- Impact: Cannot answer "do notifications actually improve retention?" or "which types cause uninstalls?"
- Fix: Correlate notification_sent events with subsequent app_opened events; track unsubscribe rates per category
- Effort: 1d

#### MEDIUM

**PA-19: Activity digest notification defined but no trigger mechanism**
- Impact: Daily/weekly digest strategy exists but is never scheduled
- Location: `notification_types.dart:164-174` (activityDigest defined), no Cloud Function cron
- Fix: Create Cloud Function scheduled trigger for digest generation
- Effort: 4h

**PA-20: No notification A/B testing infrastructure**
- Impact: Cannot optimize notification content, timing, or frequency
- Fix: Integrate with Remote Config for notification variant assignment
- Effort: 1d

---

## Dimension 5: Feature Flags & Experimentation — 8/12

**Summary**: A capable feature flag system exists with Firebase Remote Config, 17 flags, kill switches, gradual rollout, and real-time config updates. Missing a formal A/B testing framework and experiment-to-analytics correlation.

### Feature Flag Inventory

17 flags defined in `feature_flag_service.dart:24-51`:

| Flag | Type | Default | Purpose |
|------|------|---------|---------|
| `enable_algolia_search` | bool | false | Search backend migration |
| `enable_subcollection_participants` | bool | true | Scalability migration |
| `max_inline_participants` | int | 10 | Participant limit |
| `enable_reference_shared_content` | bool | true | Content sharing model |
| `enable_server_rate_limiting` | bool | true | API protection |
| `enable_friend_category_subcollection` | bool | false | Data model migration |
| `max_inline_category_members` | int | 50 | Category scaling |
| `enable_activity_visibility_enum` | bool | true | Privacy control |
| `enable_permission_caching` | bool | false | Performance optimization |
| `permission_cache_ttl_seconds` | int | 300 | Cache configuration |
| `permission_cache_max_size` | int | 1000 | Cache configuration |
| `audit_log_retention_days` | int | 90 | Data retention |
| `enable_performance_monitoring` | bool | true | Observability |
| `enable_social_features` | bool | true | **Kill switch** |
| `enable_sharing` | bool | true | **Kill switch** |
| `enable_messaging` | bool | true | **Kill switch** |
| `new_search_rollout_percentage` | int | 0 | Gradual rollout |

### Remote Config Capabilities (Good)

- Initialization with sensible defaults (`feature_flag_service.dart:55-81`)
- 10-second fetch timeout, 1-hour minimum fetch interval
- Graceful degradation: defaults used if Remote Config fails (line 77)
- Type-safe accessors: `isEnabled()`, `getInt()`, `getString()`, `getDouble()`
- Type-safe constants: `FeatureFlags` class with static const strings (`feature_flag_service.dart:191-220`)

### Gradual Rollout (Good)

- `isInRollout(flag, userId)` at `feature_flag_service.dart:144-152`
- Stable hashing based on `flag + userId` — user always gets same assignment
- Percentage-based: 0% (off) to 100% (fully on)
- Currently used for `new_search_rollout_percentage`

### Real-Time Updates (Good)

- `addOnConfigUpdatedListener()` at `feature_flag_service.dart:174-186`
- Listens to `_remoteConfig.onConfigUpdated` stream
- Activates immediately on update
- Platform-aware (silently fails where unsupported)

### A/B Testing (Missing)

- **No experiment assignment logging**: `isInRollout` does not log the assignment to analytics
- **No experiment-to-conversion correlation**: Cannot segment analytics by experiment group
- **No formal experiment framework**: Rollout percentages exist but no hypothesis tracking or statistical significance

### Issues

#### HIGH

**PA-21: Feature flag assignments not logged to analytics**
- Impact: Cannot correlate feature flag variants with conversion or retention metrics
- Location: `feature_flag_service.dart:144-152` (isInRollout)
- Fix: Log experiment assignment as Firebase Analytics user property on each `isInRollout` call
- Effort: 2h

#### MEDIUM

**PA-22: No formal A/B testing framework**
- Impact: Feature rollouts are binary (on/off) without measuring impact
- Fix: Create ExperimentService that wraps FeatureFlagService with analytics logging and hypothesis tracking
- Effort: 1d

**PA-23: Kill switches have no automated trigger**
- Impact: Kill switches require manual Remote Config changes; no automated circuit breaker
- Fix: Consider error-rate-based automatic kill switch via Cloud Function monitoring
- Effort: 2d

---

## Dimension 6: Onboarding Optimization — 3/10

**Summary**: A clean 4-page onboarding flow exists that collects allergen and dietary preferences. However, it has zero analytics instrumentation, no activation metric, and no handling of abandoned onboarding.

### Onboarding Flow Structure

4 pages in `lib/views/onboarding/`:

| Page | File | Content | Analytics |
|------|------|---------|-----------|
| 1. Welcome | `onboarding_welcome_page.dart` | App icon, title, description | None |
| 2. Allergens | `onboarding_allergen_page.dart` | 8 allergen toggle cards (grid) | None |
| 3. Dietary | `onboarding_dietary_page.dart` | 3 dietary preference cards | None |
| 4. Import | `onboarding_import_page.dart` | URL import + photo import CTAs | None |

- PageView with dot indicators (`onboarding_view.dart:62-71`)
- Skip button available on all pages (`onboarding_view.dart:92-96`)
- Back/Next navigation with animated transitions
- Completion saves allergen/dietary preferences and marks onboarding complete (`onboarding_viewmodel.dart:67-95`)

### Activation Metrics — NONE

- No "activated user" definition
- No first-recipe tracking correlated with onboarding
- No time-to-first-value measurement
- Import page (page 4) provides a "quick win" path but success is not tracked

### Personalization (Partial)

- Allergen/dietary preferences collected and saved to `UserAllergenPreferences` (`onboarding_viewmodel.dart:76-81`)
- These preferences do affect subsequent experience (menu allergen filtering)
- No two-step quick picks implemented
- No pre-populated content after onboarding

### Incomplete Onboarding Handling — NONE

- If user abandons mid-flow, state is not persisted (ViewModel is local)
- No resumption from where user left off
- No notification to bring them back
- `markOnboardingComplete()` is all-or-nothing (`onboarding_viewmodel.dart:84`)

### Issues

#### CRITICAL

**PA-24: Zero onboarding analytics** (duplicate of PA-09, expanded here)
- Impact: The most critical conversion funnel is a complete blind spot
- Location: `lib/views/onboarding/` (all 4 pages), `lib/viewmodels/onboarding_viewmodel.dart`
- Fix: Instrument every step:
  - `onboarding_started` (first page viewed)
  - `onboarding_page_viewed` with page index and page name
  - `onboarding_allergen_selected` / `onboarding_dietary_selected` (selection events)
  - `onboarding_skipped` with page index where skip happened
  - `onboarding_completed` with allergen_count, dietary_count, time_to_complete
- Effort: 3h

#### HIGH

**PA-25: No activation metric defined**
- Impact: Cannot measure whether onboarding actually leads to meaningful engagement
- Fix: Define "activated" (e.g., "created or imported first recipe within 24h"), track as user property and event
- Effort: 2h

#### MEDIUM

**PA-26: Abandoned onboarding not handled**
- Impact: Users who close the app mid-onboarding restart from scratch
- Fix: Persist onboarding progress locally; resume from last page on next launch
- Effort: 4h

---

## Dimension 7: App Store Optimization Technical Readiness — 2/5

**Summary**: Deep link infrastructure exists for content sharing but no in-app review prompt, no app indexing, and no structured data for recipe content.

### Review Prompt Strategy — NONE

- No `in_app_review` package in the codebase (grep for `InAppReview`, `requestReview`, `launchReview` returns zero results)
- No trigger logic for review prompts
- This is the primary mechanism for organic App Store ratings growth

### Deep Linking for Marketing (Partial)

- `DeepLinkHandler` (`deep_link_handler.dart:22`) handles 4 deep link types:
  - `/invite` — friend invitations
  - `/recipe` — recipe sharing
  - `/menu` — menu sharing
  - `/shopping` — shopping list sharing
- Uses `receive_intent` package for Android intent handling
- Web platform excluded (`line 44: if (kIsWeb)`)
- **Missing**: No campaign attribution (no UTM parameters), no referral source tracking

### Technical ASO Elements — NONE

- No Firebase App Indexing configured
- No Schema.org Recipe structured data for shared recipes
- No Open Graph metadata for social sharing links

### Issues

#### HIGH

**PA-27: No in-app review prompt**
- Impact: Missing the most impactful organic growth mechanism; App Store ratings directly affect download conversion
- Fix: Add `in_app_review` package, trigger after meaningful success events (e.g., 5th recipe cooked, 3rd menu created)
- Effort: 4h

#### MEDIUM

**PA-28: No campaign attribution on deep links**
- Impact: Cannot measure marketing campaign effectiveness or referral sources
- Fix: Add UTM parameter parsing to deep link handler, log as analytics event
- Effort: 4h

#### LOW

**PA-29: No structured data for shared recipe content**
- Impact: Shared recipe links have no rich preview (Open Graph) for social media
- Fix: Generate Open Graph metadata for recipe share links via Cloud Function
- Effort: 1d

---

## Dimension 8: Re-Engagement & Win-Back Infrastructure — 1/5

**Summary**: No lapsed user detection, no win-back campaigns, no email re-engagement. The notification infrastructure is capable of supporting re-engagement but no trigger mechanism exists.

### Lapsed User Detection — NONE

- No definition of "lapsed user"
- No server-side lapse detection (no Cloud Function cron)
- No client-side last-active tracking beyond `session_count` in SharedPreferences

### Win-Back Notifications — NONE

- No automated win-back campaigns
- No personalized re-engagement content
- No escalation strategy (day 7 → day 14 → day 30)
- The `activityDigest` notification strategy exists (`notification_types.dart:164`) but has no trigger

### Email Re-Engagement — NONE

- No email infrastructure
- No transactional email system
- Firebase Auth provides email-only for password reset

### What Could Be Built On Existing Infrastructure

The notification system (`NotificationService`) already supports:
- User preference filtering and quiet hours
- Delivery tracking and engagement analytics
- Batching and offline queuing
- Cloud Function-based FCM sending

A re-engagement system would only need:
1. A Cloud Function cron job checking `lastActiveAt` timestamps
2. Notification strategy definitions for win-back messages
3. Progressive escalation logic

### Issues

#### HIGH

**PA-30: No lapsed user detection or win-back campaigns**
- Impact: Users who stop using the app are permanently lost with no recovery attempt
- Fix: Create Cloud Function cron that identifies users with no session in 7/14/30 days, send graduated win-back notifications
- Effort: 2d

#### LOW

**PA-31: No email re-engagement channel**
- Impact: Push notifications are the only re-engagement channel; if user disables notifications, no fallback
- Fix: Add transactional email via Firebase Extensions (SendGrid/Mailgun) for re-engagement
- Effort: 2d

**PA-32: Activity digest has no scheduling mechanism**
- Impact: "Daily activity" digest concept exists but never fires
- Fix: Cloud Function scheduled trigger (daily at 18:00) aggregating friend activity
- Effort: 1d

---

## Analytics Coverage Dashboard

| User Action Category | Actions Defined | Actions Wired | Coverage |
|---------------------|-----------------|---------------|----------|
| Recipe lifecycle | 8 | 2 | 25% |
| Social actions | 4 | 2 | 50% |
| Menu planning | 7 | 5 | 71% |
| Shopping list | 5 | 0 | 0% |
| Import pipeline | 4 | 3 | 75% |
| Navigation / screens | 1 | 0 | 0% |
| Onboarding | 0 | 0 | 0% |
| System / errors | 3 | 1 | 33% |
| Auth events | 4 | 4 | 100% |
| App lifecycle | 2 | 2 | 100% |
| **Total** | **38** | **19** | **50%** |

*Note: 4 additional unwired events (group events, recipe_favorited) are not yet defined.*

---

## Phase 2 Preparation

### Issue Summary by Severity

| Severity | Count | Est. Total Effort |
|----------|-------|-------------------|
| CRITICAL | 4 | 1.5 days |
| HIGH | 8 | 4.5 days |
| MEDIUM | 10 | 7 days |
| LOW | 6 | 7 days |
| **Total** | **28** | **~20 days** |

### Recommended Phase 2 Priority Order

**Sprint 1 — Analytics Foundation (3-4 days)**
Wire existing tracker methods to ViewModels (PA-01 through PA-06). This is the highest-ROI work because the infrastructure already exists — it's just calling methods that are already defined.

1. Wire `recipe_viewed`, `recipe_created`, `recipe_edited`, `recipe_shared` (PA-01, PA-02)
2. Wire all 5 shopping events (PA-03)
3. Wire `comment_created`, `recipe_rated` (PA-04)
4. Wire `recipe_search_performed` (PA-06)
5. Add screen view tracking via NavigatorObserver (PA-05)
6. Fix PII in `recipeTitle` parameters (PA-07)

**Sprint 2 — Onboarding & Funnels (2-3 days)**
Instrument the onboarding flow and close funnel gaps.

7. Add all onboarding analytics events (PA-09/PA-24)
8. Define and track activation metric (PA-25)
9. Add import funnel session correlation (PA-10)
10. Add group events to SocialEventsTracker (PA-11)
11. Add time-to-first-value tracking (PA-12)

**Sprint 3 — Retention & Growth (3-5 days)**
Build retention tracking and growth mechanisms.

12. Implement day-N retention tracking via Cloud Function (PA-13)
13. Define and track North Star metric (PA-14)
14. Keep user properties in sync (PA-15)
15. Add in-app review prompt (PA-27)
16. Log feature flag assignments to analytics (PA-21)

**Sprint 4 — Notification Optimization & Re-Engagement (4-5 days)**
Complete notification routing and build re-engagement.

17. Implement notification deep link routing (PA-17)
18. Build lapsed user detection + win-back (PA-30)
19. Schedule activity digest trigger (PA-19/PA-32)
20. Add notification effectiveness measurement (PA-18)

### What This Report Does NOT Cover

Per cross-prompt boundaries:
- Analytics SDK integration and Firebase setup → covered in `03_infrastructure_report.md`
- FCM delivery infrastructure and Cloud Function deployment → covered in `03_infrastructure_report.md`
- App store metadata (icons, screenshots, descriptions) → covered in `06_ux_platform_report.md`
