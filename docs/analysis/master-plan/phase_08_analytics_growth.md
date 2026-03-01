# Phase 8: Analytics & Growth (~5 days) [DONE]

Event wiring, onboarding instrumentation, retention tracking, notification routing.

---

## ~~P8-01~~ — Wire `recipe_viewed` analytics event [DONE]

**Source**: R08:PA-01
**Fix**: Wired `logRecipeViewed()` in `RecipeDetailViewModel` constructor.

---

## ~~P8-02~~ — Wire `recipe_created` analytics event [DONE]

**Source**: R08:PA-02
**Fix**: Wired `logRecipeCreated()` in `RecipePersistenceManager._logRecipeCreated()` after create path success.

---

## ~~P8-03~~ — Wire all 5 shopping analytics events [DONE]

**Source**: R08:PA-03
**Fix**: Wired all 5 events in `UnifiedShoppingViewModel` (createPersonalList, createCollaborativeList, addItem, toggleItemBought, listCompleted) and `ShoppingShareViewModel` (shareShoppingListCommand).

---

## ~~P8-04~~ — Wire social engagement events [DONE — pre-existing]

**Source**: R08:PA-04
**Status**: Already wired at service layer (comment_created, recipe_rated).

---

## ~~P8-05~~ — ~~Wire `logScreenView`~~ [FIXED — pre-existing]

**Status**: Verified fixed — `FirebaseAnalyticsObserver` already wired in `main.dart`.

---

## ~~P8-06~~ — Wire `recipe_search_performed` [DONE]

**Source**: R08:PA-06
**Fix**: Wired in `RecipeQueryViewModel.updateSearchQuery()` after debounced search completes.

---

## ~~P8-07~~ — Wire remaining recipe events [DONE]

**Source**: R08:PA-01, R08:PA-02 (extended)
**Fix**: Wired `recipe_edited` and `recipe_image_uploaded` in `RecipePersistenceManager`.

---

## ~~P8-08~~ — Remove PII from analytics events [DONE]

**Source**: R08:PA-07
**Fix**: Removed `recipeTitle` from `logRecipeCooked` and `logRecipeDeleted` across interface, implementations, trackers, service, and all callers/tests.

---

## ~~P8-09~~ — Instrument onboarding funnel [DONE]

**Source**: R08:PA-09, R08:PA-24
**Fix**: Added `onboarding_started`, `onboarding_page_viewed`, `onboarding_skipped`, `onboarding_completed` events in `OnboardingViewModel`.

---

## ~~P8-10~~ — Define and track activation metric [DONE]

**Source**: R08:PA-25
**Fix**: Defined as "created first recipe within 7 days of signup". Fires `user_activated` event in `RecipePersistenceManager._trackFirstRecipeMetrics()`.

---

## ~~P8-11~~ — Import funnel session correlation [DONE]

**Source**: R08:PA-10
**Fix**: Added optional `sessionId` parameter to `logImportStarted`, `logImportSuccess`. Added `logImportCancelled` event. Updated interface, repos, tracker, and service.

---

## ~~P8-12~~ — Add group analytics events [DONE]

**Source**: R08:PA-11
**Fix**: Added `logGroupCreated`, `logGroupJoined`, `logContentSharedToGroup` to `SocialEventsTracker`. Wired in `CreateGroupViewModel`, `GroupInvitationsViewModel`, `GroupContentViewModel`.

---

## ~~P8-13~~ — Implement day-N retention tracking [DONE]

**Source**: R08:PA-13
**Fix**: Cloud Function `trackDayNRetention` in `functions/src/analytics/track-retention.ts`. Daily 4 AM UTC, tracks day-1/7/30 retention.

---

## ~~P8-14~~ — Define North Star metric [DONE]

**Source**: R08:PA-14
**Fix**: Defined as "recipes interacted with per week" (recipe_viewed + recipe_cooked + recipe_edited). Documented in `analytics_service.dart`. Dashboard uses existing events.

---

## ~~P8-15~~ — Keep user properties in sync [DONE]

**Source**: R08:PA-08, R08:PA-15
**Fix**: `setUserProperties(recipeCount:)` after recipe create (RecipePersistenceManager) and delete (RecipeDetailViewModel). `hasUsedImport: true` after import.

---

## ~~P8-16~~ — Implement notification deep link routing [DONE]

**Source**: R08:PA-17
**Fix**: Added `onNotificationTapped` static callback in `NotificationService._handleMessageOpened()`. Extracts `route` and `targetId` from message data.

---

## ~~P8-17~~ — Schedule activity digest trigger [DONE]

**Source**: R08:PA-19, R08:PA-32
**Fix**: Cloud Function `sendWeeklyActivityDigest` in `functions/src/analytics/send-activity-digest.ts`. Weekly Monday 8 AM UTC.

---

## ~~P8-18~~ — Build lapsed user detection + win-back [DONE]

**Source**: R08:PA-30
**Fix**: Cloud Function `detectLapsedUsers` in `functions/src/analytics/detect-lapsed-users.ts`. Daily 5 AM UTC, graduated win-back at 7/14/30 days.

---

## ~~P8-19~~ — Log feature flag assignments to analytics [DONE]

**Source**: R08:PA-21
**Fix**: Added analytics event `feature_flag_evaluated` in `FeatureFlagService.isInRollout()`.

---

## ~~P8-20~~ — Time-to-first-value tracking [DONE]

**Source**: R08:PA-12
**Fix**: `time_to_first_recipe` event with `minutes_since_signup` fired on first recipe creation in `RecipePersistenceManager._trackFirstRecipeMetrics()`.

---

## ~~P8-21~~ — Campaign attribution on deep links [DONE]

**Source**: R08:PA-28
**Fix**: UTM parameter extraction (`utm_source`, `utm_medium`, `utm_campaign`) in `DeepLinkHandler._trackCampaignAttribution()`. Fires `campaign_click` event.

---

## ~~P8-22~~ — Notification effectiveness correlation [DONE]

**Source**: R08:PA-18
**Fix**: Cloud Function `correlateNotificationEffectiveness` in `functions/src/analytics/correlate-notifications.ts`. Daily 6 AM UTC, correlates notification sends with app opens.
