# Phase 8: Analytics & Growth (~5 days)

Event wiring, onboarding instrumentation, retention tracking, notification routing.

---

## P8-01 — Wire `recipe_viewed` analytics event [CRIT]

**Source**: R08:PA-01
**Files**: `recipe_events_tracker.dart:59-73` (defined), no call site
**Fix**: Wire `logRecipeViewed()` in `RecipeDetailViewModel.loadRecipe()`. Most common user action is invisible.
**Effort**: 30 min

---

## P8-02 — Wire `recipe_created` analytics event [CRIT]

**Source**: R08:PA-02
**Fix**: Wire in recipe creation flow. Core conversion event is not tracked.
**Effort**: 30 min

---

## P8-03 — Wire all 5 shopping analytics events [HIGH]

**Source**: R08:PA-03
**Files**: `shopping_events_tracker.dart:1-83`
**Fix**: Entire shopping feature (5 events defined, 0 called) is invisible.
**Effort**: 2h

---

## P8-04 — Wire social engagement events [HIGH]

**Source**: R08:PA-04
**Files**: `social_events_tracker.dart:32-58`
**Fix**: Wire `comment_created`, `recipe_rated` in respective ViewModels.
**Effort**: 1h

---

## P8-05 — Wire `logScreenView` [HIGH]

**Source**: R08:PA-05
**Files**: `analytics_service.dart:147-163`
**Fix**: Add screen view tracking via NavigatorObserver.
**Effort**: 2h

---

## P8-06 — Wire `recipe_search_performed` [HIGH]

**Source**: R08:PA-06
**Files**: `recipe_events_tracker.dart:115-130`
**Fix**: Wire in RecipeQueryViewModel.
**Effort**: 30 min

---

## P8-07 — Wire remaining recipe events [HIGH]

**Source**: R08:PA-01, R08:PA-02 (extended)
**Fix**: Wire `recipe_edited`, `recipe_shared`, `recipe_image_uploaded`.
**Effort**: 1h

---

## P8-08 — Remove PII from analytics events [MED]

**Source**: R08:PA-07
**Files**: `firebase_analytics_repository.dart:219,262`
**Fix**: Remove `recipe_title` parameter from `recipe_cooked` and `recipe_deleted`. Keep `recipe_id`.
**Effort**: 30 min

---

## P8-09 — Instrument onboarding funnel [CRIT]

**Source**: R08:PA-09, R08:PA-24
**Files**: `lib/views/onboarding/` (4 pages), `lib/viewmodels/onboarding_viewmodel.dart`
**Fix**: Add `onboarding_started`, `onboarding_page_viewed`, `onboarding_allergen_selected`, `onboarding_dietary_selected`, `onboarding_skipped`, `onboarding_completed`.
**Effort**: 3h

---

## P8-10 — Define and track activation metric [HIGH]

**Source**: R08:PA-25
**Fix**: Define "activated" (e.g., "created or imported first recipe within 24h"), track as user property and event.
**Effort**: 2h

---

## P8-11 — Import funnel session correlation [HIGH]

**Source**: R08:PA-10
**Fix**: Add session_id to `import_started` / `import_success`, add `import_cancelled` and `import_tier` events.
**Effort**: 2h

---

## P8-12 — Add group analytics events [HIGH]

**Source**: R08:PA-11
**Fix**: Define and wire `group_created`, `group_joined`, `content_shared_to_group` in SocialEventsTracker.
**Effort**: 2h

---

## P8-13 — Implement day-N retention tracking [CRIT]

**Source**: R08:PA-13
**Fix**: Cloud Function cron checking last-active dates. Track day-1/7/30 retention.
**Effort**: 1d

---

## P8-14 — Define North Star metric [HIGH]

**Source**: R08:PA-14
**Fix**: Define (suggest "recipes interacted with per week"), add tracking event, create dashboard.
**Effort**: 4h

---

## P8-15 — Keep user properties in sync [MED]

**Source**: R08:PA-08, R08:PA-15
**Fix**: Call `setUserProperties()` after recipe CRUD operations and on `app_opened`.
**Effort**: 2h

---

## P8-16 — Implement notification deep link routing [HIGH]

**Source**: R08:PA-17
**Files**: `notification_service.dart:376-396`
**Fix**: Users tap notifications but land on home screen. Integrate with DeepLinkHandler for proper routing.
**Effort**: 4h

---

## P8-17 — Schedule activity digest trigger [MED]

**Source**: R08:PA-19, R08:PA-32
**Fix**: `activityDigest` strategy exists but no Cloud Function cron trigger.
**Effort**: 4h

---

## P8-18 — Build lapsed user detection + win-back [HIGH]

**Source**: R08:PA-30
**Fix**: Cloud Function cron identifying users with no session in 7/14/30 days, send graduated win-back notifications.
**Effort**: 2d

---

## P8-19 — Log feature flag assignments to analytics [HIGH]

**Source**: R08:PA-21
**Files**: `feature_flag_service.dart:144-152`
**Fix**: Log experiment assignment as Firebase Analytics user property on `isInRollout` calls.
**Effort**: 2h

---

## P8-20 — Time-to-first-value tracking [MED]

**Source**: R08:PA-12
**Fix**: Track time from signup to first `recipe_created`.
**Effort**: 1h

---

## P8-21 — Campaign attribution on deep links [MED]

**Source**: R08:PA-28
**Fix**: Add UTM parameter parsing to deep link handler, log as analytics event.
**Effort**: 4h

---

## P8-22 — Notification effectiveness correlation [MED]

**Source**: R08:PA-18
**Fix**: Correlate notification_sent events with subsequent app_opened events; track unsubscribe rates per category.
**Effort**: 1d
