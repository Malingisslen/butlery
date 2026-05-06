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
