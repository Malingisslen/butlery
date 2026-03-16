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
  static const String sharedRecipes = 'shared_recipes';
  static const String sharedMenus = 'shared_menus';
  static const String sharedShoppingLists = 'shared_shopping_lists';
  static const String blocks = 'blocks';
  static const String sharedPersonalTags = 'shared_personal_tags';
  static const String friendRequests = 'friend_requests';
  static const String groupInvitations = 'group_invitations';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String ingredients = 'ingredients';
  static const String ingredientSuggestions = 'ingredientSuggestions';
  static const String auditLogs = 'audit_logs';
  static const String deletionAuditLogs = 'deletion_audit_logs';
  static const String feedback = 'feedback';
  static const String presence = 'presence';
  static const String realtimeRecipes = 'realtime_recipes';
  static const String realtimeMenus = 'realtime_menus';
  static const String realtimeResources = 'realtime_resources';
  static const String recipeComments = 'recipe_comments';
  static const String recipeRatings = 'recipe_ratings';
  static const String menuComments = 'menu_comments';
  static const String menuRatings = 'menu_ratings';
  static const String menuTemplates = 'menu_templates';
  static const String menuActivity = 'menu_activity';
  static const String userNotifications = 'user_notifications';
  static const String userNotificationPreferences =
      'user_notification_preferences';
  static const String userFcmTokens = 'user_fcm_tokens';
  static const String userDevices = 'user_devices';
  static const String unifiedShoppingLists = 'unified_shopping_lists';
  static const String unifiedSharedShoppingLists =
      'unified_shared_shopping_lists';
  static const String siteConfigs = 'site_configs';
  static const String tagConfigs = 'tagConfigs';
  static const String parsingCorrections = 'parsing_corrections';
  static const String deepLinks = 'deep_links';
  static const String connectivityTest = 'connectivity_test';
  static const String butleryArchive = 'butlery_archive';
  static const String activityFeed = 'activity_feed';
  static const String reports = 'reports';
  static const String notificationHistory = 'notification_history';
  static const String notificationBatches = 'notification_batches';

  static const String shoppingListTemplates = 'shoppingListTemplates';

  // ── User subcollections (under users/{userId}/) ──

  static const String userRecipes = 'recipes';
  static const String userMenus = 'menus';
  static const String userShoppingLists = 'shopping_lists';
  static const String userFriends = 'friends';
  static const String userFriendsTop = 'userFriends';
  static const String userFriendCategories = 'friendCategories';
  static const String userCategoryMemberships = 'categoryMemberships';
  static const String userPersonalTagIds = 'personalTagIds';
  static const String userPersonalTagGroups = 'personalTagGroups';
  static const String userSettings = 'settings';
  static const String userConsent = 'consent';
  static const String userConversationMemberships = 'conversationMemberships';
  static const String userRateLimits = 'rateLimits';
  static const String userSharedMenus = 'userSharedMenus';
  static const String userSharedShoppingLists = 'userSharedShoppingLists';

  // ── Shared content subcollections ──

  static const String members = 'members';
  static const String collaborators = 'collaborators';
  static const String items = 'items';
  static const String receivedMenus = 'receivedMenus';
  static const String receivedLists = 'receivedLists';
  static const String counters = 'counters';

  // ── Other subcollections ──

  static const String participants = 'participants';
  static const String activeUsers = 'activeUsers';
  static const String recipePresence = 'recipePresence';
  static const String likes = 'likes';
  static const String clicks = 'clicks';
  static const String ratings = 'ratings';
  static const String comments = 'comments';
  static const String activities = 'activities';
  static const String deletions = 'deletions';

  // ── Firebase system collections ──

  static const String firebaseInfo = '.info';
}
