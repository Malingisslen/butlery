/// Centralized registry of Firebase Analytics event names and user-property
/// keys. Source-of-truth for every `logEvent(name: ...)` and
/// `setUserProperty(name: ...)` call site (BUT-737).
///
/// Why centralize: a typo in an event-name literal silently kills its funnel
/// — the event is logged under the misspelled name and dashboard queries
/// keep returning zero. Constants give us compile-time safety and a single
/// place to audit our analytics surface area when adding new metrics.
///
/// When adding a new event/user-property, add the constant here AND use it
/// at the call site. Avoid inline string literals.
library;

/// All `logEvent(name: ...)` values used in the app. Grouped by domain in
/// declaration order: auth/lifecycle, recipes, menu, shopping, social,
/// import/parse, system/perf, attribution, notifications, milestones,
/// review prompts, security.
abstract final class AnalyticsEvents {
  // --- Auth / lifecycle ---
  static const appOpened = 'app_opened';
  static const appBackgrounded = 'app_backgrounded';
  static const logout = 'logout';
  static const logoutInactivity = 'logout_inactivity';
  static const authFailed = 'auth_failed';
  static const mfaEnrolled = 'mfa_enrolled';
  static const mfaUnenrolled = 'mfa_unenrolled';
  static const accountDeleted = 'account_deleted';
  static const sessionTimeoutPaused = 'session_timeout_paused';
  static const sessionTimeoutResumed = 'session_timeout_resumed';
  static const sessionTimeoutWarningShown = 'session_timeout_warning_shown';
  static const sessionTimeoutLogout = 'session_timeout_logout';
  static const onboardingStarted = 'onboarding_started';
  static const onboardingPageViewed = 'onboarding_page_viewed';
  // BUT-675: emitted when a user re-enters onboarding mid-flow (resume) and
  // when the 24h-no-progress nudge bottom-sheet is shown (abandoned).
  static const onboardingResumed = 'onboarding_resumed';
  static const onboardingAbandoned = 'onboarding_abandoned';
  static const onboardingSkipped = 'onboarding_skipped';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingRecipesSeeded = 'onboarding_recipes_seeded';
  // BUT-926: emitted when one or more starter recipes fail to seed during
  // onboarding completion. Parameters: `failed` (int), `attempted` (int).
  // Distinct from `onboardingRecipesSeeded` (success-side counter) so the
  // failure-rate metric is queryable without `attempted - seeded` math.
  static const onboardingRecipesSeedFailed = 'onboarding_recipes_seed_failed';
  // BUT-930: emitted once after starter recipes are seeded, when a sample
  // weekly-menu plan + its shopping list are generated so the new user lands
  // on a populated menu and shopping list instead of empty screens.
  // Parameters: `menuEntries` (int), `shoppingItems` (int). Both 0 means
  // seeding ran but had nothing to place (no recipes seeded / plan non-empty).
  static const onboardingMenuSeeded = 'onboarding_menu_seeded';
  // BUT-545: dedicated outcome events for the onboarding import page so
  // the activation funnel can distinguish "tried-and-imported" from
  // "tried-and-failed" from "skipped". The generic import_started/success
  // events still fire alongside (with `source: 'onboarding'`) for the
  // unified import funnel; these add the onboarding-specific dimension.
  static const onboardingImportAttempted = 'onboarding_import_attempted';
  static const onboardingImportSucceeded = 'onboarding_import_succeeded';
  static const onboardingImportSkipped = 'onboarding_import_skipped';
  static const screenViewed = 'screen_viewed';
  static const userActivated = 'user_activated';
  static const timeToFirstRecipe = 'time_to_first_recipe';

  // --- Recipes ---
  static const recipeCreated = 'recipe_created';
  static const recipeShared = 'recipe_shared';
  static const recipeCooked = 'recipe_cooked';
  static const recipeDeleted = 'recipe_deleted';
  static const recipeViewed = 'recipe_viewed';
  static const recipeEdited = 'recipe_edited';
  static const recipeCopied = 'recipe_copied';
  static const recipeImageUploaded = 'recipe_image_uploaded';
  static const recipeSearchPerformed = 'recipe_search_performed';
  static const recipeFavorited = 'recipe_favorited';
  static const postImportEdit = 'post_import_edit';

  // --- Pooled ratings "Butlery-betyget" (decision 15) ---
  // `poolRatingShown` fires once per recipe-detail open when the community
  // score clears the display floor and is rendered (the detail-open stats
  // read); NOT per card, to keep the funnel + read volume low. `poolRatingContributed`
  // fires when the user rates a poolable recipe (client-side intent signal;
  // the server mirror CF remains the authority for the actual pool event).
  static const poolRatingShown = 'pool_rating_shown';
  static const poolRatingContributed = 'pool_rating_contributed';

  // --- Cooking mode (BUT-802 HIGH-PA4) ---
  static const cookingSessionStarted = 'cooking_session_started';
  static const cookingStepAdvanced = 'cooking_step_advanced';
  static const cookingSessionCompleted = 'cooking_session_completed';
  static const cookingSessionAbandoned = 'cooking_session_abandoned';

  // --- Household size / portion scaling (BUT-1322) ---
  static const householdSizeChanged = 'household_size_changed';
  static const portionScalingApplied = 'portion_scaling_applied';

  // --- Menu / meal plan ---
  static const menuGenerated = 'menu_generated';
  // BUT-1474: fired when a user swaps a single recipe in a generated menu
  // (the "byt ut" action) and a replacement is actually chosen. Powers the
  // swap-rate-per-menu signal — the core "is the menu getting better" metric.
  // Parameter: `category` (the meal category swapped within).
  static const menuRecipeSwapped = 'menu_recipe_swapped';
  // BUT-1464 follow-up: fired once per generation when household allergen
  // filtering shrinks the candidate pool, carrying the hidden-count and the
  // preference source — the "how often does allergen filtering bite" signal.
  static const menuRecipesHiddenByHousehold =
      'menu_recipes_hidden_by_household';
  static const menuGenerationStarted = 'menu_generation_started';
  static const menuGenerationFailed = 'menu_generation_failed';
  static const menuSaved = 'menu_saved';
  static const menuLoaded = 'menu_loaded';
  static const menuShared = 'menu_shared';
  static const menuDeleted = 'menu_deleted';

  // --- Shopping ---
  static const shoppingListCreated = 'shopping_list_created';
  static const shoppingListItemAdded = 'shopping_list_item_added';
  static const shoppingListItemChecked = 'shopping_list_item_checked';
  static const shoppingListShared = 'shopping_list_shared';
  static const shoppingListCompleted = 'shopping_list_completed';

  // --- Social ---
  static const friendRequestSent = 'friend_request_sent';
  static const friendRequestAccepted = 'friend_request_accepted';
  static const friendRequestRejected = 'friend_request_rejected';
  static const friendRequestCancelled = 'friend_request_cancelled';
  static const friendRemoved = 'friend_removed';
  // BUT-939: social-funnel instrumentation.
  static const friendSearchPerformed = 'friend_search_performed';
  static const socialOnboardingStarted = 'social_onboarding_started';
  static const userBlocked = 'user_blocked';
  static const userUnblocked = 'user_unblocked';
  static const messageSent = 'message_sent';
  static const commentCreated = 'comment_created';
  static const recipeRated = 'recipe_rated';
  static const groupCreated = 'group_created';
  static const groupJoined = 'group_joined';
  static const groupLeft = 'group_left';
  static const groupDeleted = 'group_deleted';
  static const contentSharedToGroup = 'content_shared_to_group';
  static const contentUnshared = 'content_unshared';

  // --- Import / parse pipeline ---
  static const importStarted = 'import_started';
  static const importSuccess = 'import_success';
  static const importCancelled = 'import_cancelled';
  // BUT-1037: user backed out of the "doesn't look like a recipe" warn dialog,
  // so we avoided a wasted paid LLM parse. Measures cost saved.
  static const importWarnDialogCancelled = 'import_warn_dialog_cancelled';
  static const extractionError = 'extraction_error';
  static const manualCopyFallback = 'manual_copy_fallback';
  static const importTierSucceeded = 'import_tier_succeeded';
  static const importTierFailed = 'import_tier_failed';

  // --- System / perf ---
  static const errorOccurred = 'error_occurred';
  static const networkError = 'network_error';
  static const slowOperation = 'slow_operation';
  static const featureFlagEvaluated = 'feature_flag_evaluated';
  static const performanceReport = 'performance_report';
  static const performanceWarnings = 'performance_warnings';
  // BUT-670: emitted once per session when the maintenance-mode blocker
  // first appears (Remote Config flag flipped or fetched as true). Used to
  // measure incident impact — count of users hitting the blocker.
  static const maintenanceModeShown = 'maintenance_mode_shown';

  // --- Tagging system ---
  static const recipeTagged = 'recipe_tagged';
  static const unknownIngredients = 'unknown_ingredients';
  static const personalTagCreated = 'personal_tag_created';
  static const personalTagRuleTriggered = 'personal_tag_rule_triggered';
  static const taggingPerformance = 'tagging_performance';
  static const taggingCoverageAnomaly = 'tagging_coverage_anomaly';
  static const taggingCacheDesync = 'tagging_cache_desync';
  static const taggingConfigValidationError = 'tagging_config_validation_error';
  static const dataIntegrityCheck = 'data_integrity_check';
  // BUT-616: emitted when ParseEventLogger.logEvent's callable invocation
  // fails, so we can measure parse-event loss rate. Params: error_code
  // (Firebase Functions code or 'unknown'), cause (truncated message).
  static const parseEventLogFailed = 'parse_event_log_failed';
  // BUT-1486: emitted when ParseCorrectionUploader drops a correction upload
  // before it reaches the callable (unknown tier, no analytics salt, or a
  // payload/prefs error) — mirrors parseEventLogFailed so the correction
  // feedback loop's silent losses are measurable. Params: reason
  // (unknown_tier | no_salt | payload_error | salt_error), tier (offending
  // Dart tier name, unknown_tier only), cause (truncated message, error paths).
  static const parseCorrectionUploadDropped = 'parse_correction_upload_dropped';
  // BUT-655: emitted from notification settings when a category toggle
  // changes. Params: category (e.g. friend_request, comment, chat),
  // enabled (bool).
  static const notificationPreferenceChanged =
      'notification_preference_changed';

  // --- Attribution / acquisition ---
  static const campaignClick = 'campaign_click';

  // --- Notifications ---
  static const notificationOpened = 'notification_opened';
  static const notificationPayloadMissingRoute =
      'notification_payload_missing_route';
  static const notificationPayloadUnknownRoute =
      'notification_payload_unknown_route';

  // --- Win-back attribution (BUT-691) ---
  /// Emitted once per win-back send, on the first meaningful action
  /// (cook complete / recipe import / menu generate) within 7 days of
  /// the server-side send. Parameters: `{ channel, variant, bucket,
  /// hours_since_send, action_type }`. The win-back send itself is
  /// driven by `functions/src/analytics/detect-lapsed-users.ts`, which
  /// stamps `lastWinBack*` bridge fields on the user doc; the client
  /// reads those at session start (see `WinbackAttributionService`),
  /// applies the FA experiment slice, and emits this event on the
  /// next meaningful action — closing the measurement loop.
  static const winbackConverted = 'winback_converted';

  // --- Milestones (once-per-user activation events) ---
  static const firstShare = 'first_share';
  static const firstFriend = 'first_friend';
  static const firstComment = 'first_comment';
  static const firstGroup = 'first_group';
  static const firstMealPlan = 'first_meal_plan';
  static const firstSearch = 'first_search';
  static const firstCook = 'first_cook';

  // --- Review prompts ---
  static const inAppReviewRequested = 'in_app_review_requested';
  static const inAppReviewDismissed = 'in_app_review_dismissed';

  // --- Security telemetry ---
  static const sslPinMismatch = 'ssl_pin_mismatch';

  // --- Experiments (BUT-657) ---
  /// Logged once per session per experiment when a variant is assigned.
  /// Parameters: `{ experiment_name, variant }`.
  static const experimentAssigned = 'experiment_assigned';
}

/// All `setUserProperty(name: ...)` values used in the app.
/// User properties are sticky per-user — set once and re-read on every event.
abstract final class AnalyticsUserProperties {
  // --- Activity buckets ---
  static const userType = 'user_type';
  static const recipeCountRange = 'recipe_count_range';
  static const hasUsedImport = 'has_used_import';
  static const hasSharedRecipe = 'has_shared_recipe';
  static const hasMarkedCooked = 'has_marked_cooked';

  // --- Activation flags (paired with milestone events) ---
  static const sharingActivated = 'sharing_activated';
  static const hasFriend = 'has_friend';
  static const hasCommented = 'has_commented';
  static const hasGroup = 'has_group';
  static const menuActivated = 'menu_activated';
  static const searchActivated = 'search_activated';
  static const cookingActivated = 'cooking_activated';

  // --- Acquisition / first-touch ---
  static const acquisitionSource = 'acquisition_source';
  static const acquisitionMedium = 'acquisition_medium';
  static const acquisitionCampaign = 'acquisition_campaign';
  static const firstRecipeSource = 'first_recipe_source';

  // BUT-1500 follow-up: `has_algolia_search` retired. Its only emitter lived
  // in `RecipeSearchRouter`, deleted on 2026-07-16 when the Algolia text-search
  // routing path was removed as dead code. Recipe search is now 100% local
  // substring matching, and the surviving Algolia delegate is reachable only
  // from account-deletion index cleanup — so the property no longer describes
  // anything about a user's search experience. Not re-wired in SearchModule:
  // the flag is off in production, so it would emit a constant `false` for
  // every user — the same zero-information dimension `subscription_tier` was
  // retired for below.

  // --- Locale / device / lifecycle (BUT-636 / BUT-637 / BUT-639) ---
  /// User's active app locale (`sv`, `en`). Re-emitted on locale change.
  static const language = 'language';

  /// Device/runtime platform bucket: `ios | android | macos | windows | linux | web`.
  static const platform = 'platform';

  /// Lifecycle cohort bucket: `new | activated | habitual | dormant | churned`.
  /// Recomputed on cold start + after each cook completion.
  static const lifecycleStage = 'lifecycle_stage';

  // BUT-1410: `subscription_tier` retired. It was seeded (BUT-623) to slice
  // paid cohorts, but Butlery has no consumer subscription (monetization =
  // grocery-channel aggregation + POD cookbook gifting), so it emitted a
  // constant `'free'` for every user forever — a zero-information dimension
  // and a misleading "we have tiers" signal. Removed rather than repurposed;
  // a real free-app cohort dimension is a separate, deliberate design.

  // --- Experiments (BUT-657) ---
  /// Prefix for per-experiment user properties. Concrete property name is
  /// `<prefix><sanitized_experiment_name>` and the value is the variant
  /// (`control`, `treatment`, etc). Set by
  /// [ExperimentAssignment.setExperimentAssignment].
  ///
  /// Firebase Analytics user-property names cap at 24 chars and only allow
  /// `[A-Za-z0-9_]`, must start with a letter — the prefix consumes 4 of
  /// those, leaving 20 for the experiment name.
  static const experimentPrefix = 'exp_';
}
