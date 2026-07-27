/// Centralized Firestore collection path constants.
///
/// All collection and subcollection names used across the app.
/// Prevents typos and enables global collection renaming.
abstract final class FirestoreCollections {
  // ── Top-level collections ──

  static const String users = 'users';
  static const String recipes = 'recipes';
  static const String menus = 'menus';
  static const String publicProfiles = 'public_profiles';
  static const String sharedContent = 'shared_content';
  static const String blocks = 'blocks';
  static const String socialRequests = 'social_requests';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String ingredients = 'ingredients';
  static const String ingredientSuggestions = 'ingredient_suggestions';
  static const String auditLogs = 'audit_logs';
  static const String deletionAuditLogs = 'deletion_audit_logs';
  static const String feedback = 'feedback';
  static const String presence = 'presence';
  static const String realtimeRecipes = 'realtime_recipes';
  static const String recipeComments = 'recipe_comments';
  static const String recipeRatings = 'recipe_ratings';
  static const String recipeSocialStats = 'recipe_social_stats';
  // Pooled ratings "Butlery-betyget": server-authoritative aggregate keyed by
  // poolKey (count + average across every user who rated the same dish).
  // Read-only for signed-in users; written only by the Stage-B aggregator CF.
  static const String canonicalRecipeStats = 'canonical_recipe_stats';
  // Family-rating feature (household-scoped, shared across household members).
  static const String households = 'households';
  static const String dinerProfiles = 'diner_profiles';
  static const String familyRatings = 'family_ratings';
  static const String menuTemplates = 'menu_templates';
  static const String userNotifications = 'user_notifications';
  static const String userNotificationPreferences =
      'user_notification_preferences';
  static const String userFcmTokens = 'user_fcm_tokens';
  static const String unifiedShoppingLists = 'unified_shopping_lists';
  static const String unifiedSharedShoppingLists =
      'unified_shared_shopping_lists';
  static const String siteConfigs = 'site_configs';
  static const String tagConfigs = 'tag_configs';
  static const String parsingCorrections = 'parsing_corrections';
  // Admin-dashboard read surfaces. Written server-side by scheduled functions;
  // read by the admin app (rules-gated to isAdmin). See firestore.rules.
  static const String analytics = 'analytics';
  static const String metrics = 'metrics';
  static const String systemEvents = 'system_events';
  static const String deepLinks = 'deep_links';
  static const String connectivityTest = 'connectivity_test';
  static const String butleryArchive = 'butlery_archive';
  static const String reports = 'reports';
  static const String notificationHistory = 'notification_history';
  static const String notificationBatches = 'notification_batches';
  static const String notificationDelivery = 'notification_delivery';
  static const String notificationEngagement = 'notification_engagement';
  static const String ingredientSubstitutions = 'ingredient_substitutions';
  static const String cookSnaps = 'cook_snaps';
  // BUT-838: per-user cook-event log. Events live in an `events`
  // subcollection under recipe_cook_events/{userId} (a virtual doc that is
  // never written — Firestore paths must alternate collection/document).
  static const String recipeCookEvents = 'recipe_cook_events';
  static const String recipeCookEventEntries = 'events';
  static const String activityEvents = 'activity_events';
  static const String pings = 'pings';
  static const String weeklyMenuPlans = 'weekly_menu_plans';
  static const String groupWeeklyMenuPlans = 'group_weekly_menu_plans';
  static const String menuLexicon = 'menu_lexicon';

  static const String shoppingListTemplates = 'shopping_list_templates';
  static const String categoryOverrides = 'category_overrides';
  static const String globalRecipeCache = 'globalRecipeCache';

  // ── User subcollections (under users/{userId}/) ──

  static const String userRecipes = 'recipes';

  /// DEAD PATH — kept only so a future reader recognises the name.
  ///
  /// Nothing writes `users/{uid}/shopping_lists`: the client routes every
  /// personal list through `FirebaseShoppingRepository`, whose `collectionName`
  /// is [unifiedShoppingLists], and `firestore.rules` grants no match for this
  /// name at all. Two constants for one concept is what broke the GDPR export
  /// and the erasure cascade (BUT-1697) — do not reintroduce it as a live path.
  ///
  /// The remaining readers are all broken rather than merely empty, and are
  /// tracked in BUT-1724: `friends_utility_operations.dart:146` queries a ROOT
  /// `shopping_lists` (not this subcollection), which the catch-all deny turns
  /// into `permission-denied` on every call, so "senaste inköpssamarbeten" is
  /// permanently empty; `functions/src/analytics/compute-feature-retention.ts`
  /// probes this subcollection for its `shopped` flag, which is therefore false
  /// for every user every day.
  ///
  /// Two Admin-SDK readers sweep it DELIBERATELY and correctly no-op:
  /// `functions/src/account/account-deletion-cascade.ts` (a legacy safety net
  /// for accounts predating the rename) and `functions/src/admin/
  /// reset-user-data.ts`. Both hard-code the string, so a grep for this
  /// constant does not find them.
  static const String userShoppingLists = 'shopping_lists';
  static const String userFriends = 'friends';
  static const String userFriendCategories = 'friend_categories';
  static const String userPersonalTags = 'personal_tags';
  static const String userPersonalTagGroups = 'personal_tag_groups';
  static const String userSettings = 'settings';
  static const String userConsent = 'consent';
  static const String userConversationMemberships = 'conversation_memberships';
  static const String userRateLimits = 'rate_limits';
  static const String userSharedMenus = 'user_shared_menus';
  static const String userSharedShoppingLists = 'user_shared_shopping_lists';
  static const String categoryPreferences = 'category_preferences';
  static const String listCategoryOrders = 'list_category_orders';
  static const String pantry = 'pantry';
  // BUT-781: per-(reporter, contentOwner) brigade-rate-limit sentinel
  // doc id is the contentOwnerId; field is `lastReportAt: serverTimestamp()`.
  static const String userReportThrottle = 'report_throttle';
  // Pooled ratings ("Butlery-betyget"): one frozen pool event per pool the user
  // has voted in (doc-id = poolKey). Server-only writes (CF mirror, Admin SDK);
  // owner-read for GDPR export. Pseudonymous, not anonymous.
  static const String canonicalRatingEvents = 'canonical_rating_events';

  // ── Shared content subcollections ──

  static const String members = 'members';
  static const String collaborators = 'collaborators';
  static const String items = 'items';
  static const String receivedMenus = 'received_menus';
  static const String receivedLists = 'received_lists';
  static const String counters = 'counters';
  static const String engagements = 'engagements';

  // ── Other subcollections ──

  static const String participants = 'participants';
  static const String activeUsers = 'activeUsers';
  static const String recipePresence = 'recipePresence';
  // BUT-238: collaborative shopping presence (per-list, 30s TTL).
  static const String shoppingPresence = 'shoppingPresence';
  static const String likes = 'likes';
  static const String clicks = 'clicks';
  static const String ratings = 'ratings';
  static const String comments = 'comments';
  static const String activities = 'activities';
  static const String deletions = 'deletions';

  // ── Firebase system collections ──

  static const String firebaseInfo = '.info';
}
