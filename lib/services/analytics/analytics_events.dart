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
  static const logout = 'logout';
  static const mfaUnenrolled = 'mfa_unenrolled';
  static const accountDeleted = 'account_deleted';
  static const onboardingStarted = 'onboarding_started';
  static const onboardingPageViewed = 'onboarding_page_viewed';
  // BUT-675: emitted when a user re-enters onboarding mid-flow (resume) and
  // when the 24h-no-progress nudge bottom-sheet is shown (abandoned).
  static const onboardingResumed = 'onboarding_resumed';
  static const onboardingAbandoned = 'onboarding_abandoned';
  static const onboardingSkipped = 'onboarding_skipped';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingRecipesSeeded = 'onboarding_recipes_seeded';
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
  static const postImportEdit = 'post_import_edit';

  // --- Menu / meal plan ---
  static const menuGenerated = 'menu_generated';
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
  static const extractionError = 'extraction_error';
  static const manualCopyFallback = 'manual_copy_fallback';
  static const importTierSucceeded = 'import_tier_succeeded';
  static const importTierFailed = 'import_tier_failed';

  // --- System / perf ---
  static const errorOccurred = 'error_occurred';
  static const networkError = 'network_error';
  static const slowOperation = 'slow_operation';
  static const featureFlagEvaluated = 'feature_flag_evaluated';

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

  // --- Acquisition / first-touch ---
  static const acquisitionSource = 'acquisition_source';
  static const acquisitionMedium = 'acquisition_medium';
  static const acquisitionCampaign = 'acquisition_campaign';
  static const firstRecipeSource = 'first_recipe_source';

  // --- Capability flags ---
  static const hasAlgoliaSearch = 'has_algolia_search';

  // --- Locale / device / lifecycle (BUT-636 / BUT-637 / BUT-639) ---
  /// User's active app locale (`sv`, `en`). Re-emitted on locale change.
  static const language = 'language';

  /// Device/runtime platform bucket: `ios | android | macos | windows | linux | web`.
  static const platform = 'platform';

  /// Lifecycle cohort bucket: `new | activated | habitual | dormant | churned`.
  /// Recomputed on cold start + after each cook completion.
  static const lifecycleStage = 'lifecycle_stage';

  /// Monetization cohort bucket (BUT-623): `free | pro | family | trial`.
  /// Set to `free` for all users during beta — costless schema seeding so
  /// post-beta paid cohorts can be sliced from day 1 without retroactive
  /// backfill. Re-emitted on purchase / downgrade / trial transitions.
  static const subscriptionTier = 'subscription_tier';

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
