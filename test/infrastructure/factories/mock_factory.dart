/// Mock Factory for generating configured test mocks
/// 
/// Provides factory methods for creating all mocks used in tests,
/// with configuration methods instead of stubbing for concrete implementations.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as firebase_mocks;
import 'package:mocktail/mocktail.dart';

// Import our properly typed mocks
import '../mocks/production_mocks.dart';
import '../mocks/repositories/mock_analytics_repository.dart';
import '../mocks/service_mocks.dart';

// Import models for stubbing
import 'package:butlery/models/recipe_comment.dart';

// Import interfaces that factory methods return
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';

// Import models
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';

/// Mock Factory providing configured mocks for all services
class MockFactory {
  /// Private constructor to prevent instantiation
  MockFactory._();
  
  // ============= REPOSITORIES =============
  
  /// Create mock auth repository with proper typing
  static MockAuthRepository createAuthRepository({
    bool isAuthenticated = false,
    String? userId,
    User? user,
  }) {
    final mock = MockAuthRepository();
    mock.setAuthState(
      isAuthenticated: isAuthenticated,
      userId: userId,
      user: user ?? (userId != null ? createMockUser(uid: userId) : null),
    );
    return mock;
  }
  
  /// Create mock recipe repository with proper typing
  static MockRecipeRepository createRecipeRepository({
    String? currentUserId,
    Map<String, List<Recipe>>? recipesByUser,
    List<Recipe>? archiveRecipes,
    List<Recipe>? searchResults,
    Map<String, Recipe>? recipesById,
    List<Recipe>? recipes, // For backward compatibility
  }) {
    final mock = MockRecipeRepository();
    
    // If simple recipes list provided, use convenience method
    if (recipes != null && recipesByUser == null) {
      mock.setRecipes(recipes);
    } else {
      // Otherwise use full configuration
      mock.setRecipeRepositoryState(
        currentUserId: currentUserId,
        recipesByUser: recipesByUser,
        archiveRecipes: archiveRecipes,
        searchResults: searchResults,
        recipesById: recipesById,
      );
    }
    
    return mock;
  }
  
  /// Create mock user repository
  static MockUserRepository createUserRepository({
    String? currentUserId,
    Map<String, UserProfile>? profiles,
    Map<String, bool>? onlineStatus,
    Map<String, String>? fcmTokens,
    Map<String, bool>? notificationSettings,
    Set<String>? availableDisplayNames,
  }) {
    final mock = MockUserRepository();
    mock.setUserRepositoryState(
      currentUserId: currentUserId,
      profiles: profiles,
      onlineStatus: onlineStatus,
      fcmTokens: fcmTokens,
      notificationSettings: notificationSettings,
      availableDisplayNames: availableDisplayNames,
    );
    return mock;
  }
  
  /// Create mock shopping repository
  static MockShoppingRepository createShoppingRepository() {
    return MockShoppingRepository();
  }
  
  /// Create mock collaborative recipe repository
  static MockCollaborativeRecipeRepository createCollaborativeRecipeRepository({
    Map<String, RealtimeRecipe>? realtimeRecipes,
    Map<String, Map<String, Map<String, dynamic>>>? presenceData,
    Map<String, List<LiveEditor>>? participants,
    Map<String, Map<String, dynamic>>? userDocuments,
  }) {
    final mock = MockCollaborativeRecipeRepository();
    mock.setCollaborativeState(
      realtimeRecipes: realtimeRecipes,
      presenceData: presenceData,
      participants: participants,
      userDocuments: userDocuments,
    );
    return mock;
  }
  
  /// Create mock messaging repository
  static MockMessagingRepository createMessagingRepository({
    String? currentUserId,
    Map<String, Conversation>? conversations,
    Map<String, List<Message>>? messagesByConversation,
    Map<String, Set<String>>? readMessagesByUser,
    Map<String, Map<String, MessageStatus>>? messageStatuses,
  }) {
    final mock = MockMessagingRepository();
    mock.setMessagingState(
      currentUserId: currentUserId,
      conversations: conversations,
      messagesByConversation: messagesByConversation,
      readMessagesByUser: readMessagesByUser,
      messageStatuses: messageStatuses,
    );
    return mock;
  }
  
  /// Create mock firestore repository
  static MockFirestoreRepository createFirestoreRepository() {
    final mock = MockFirestoreRepository();
    // Mock will provide FakeFirebaseFirestore via its implementation
    return mock;
  }
  
  /// Create mock comments repository
  static MockCommentsRepository createCommentsRepository({
    String? currentUserId,
    Map<String, List<RecipeComment>>? commentsByRecipe,
    Map<String, Set<String>>? likesByComment,
    Map<String, int>? replyCounts,
  }) {
    final mock = MockCommentsRepository();
    mock.setCommentsState(
      currentUserId: currentUserId,
      commentsByRecipe: commentsByRecipe,
      likesByComment: likesByComment,
      replyCounts: replyCounts,
    );
    // Setup default behavior for getCommentsStream
    when(() => mock.getCommentsStream(any()))
        .thenAnswer((_) => Stream.value(<RecipeComment>[]));
    return mock;
  }
  
  /// Create mock ratings repository
  static MockRatingsRepository createRatingsRepository() {
    return MockRatingsRepository();
  }
  
  /// Create mock notifications repository
  static MockNotificationsRepository createNotificationsRepository({
    String? currentUserId,
    List<UserNotification>? notifications,
    Map<String, NotificationPreferences>? userPreferences,
    Map<String, String>? fcmTokens,
    int? unreadCount,
  }) {
    final mock = MockNotificationsRepository();
    mock.setNotificationsState(
      currentUserId: currentUserId,
      notifications: notifications,
      userPreferences: userPreferences,
      fcmTokens: fcmTokens,
      unreadCount: unreadCount,
    );
    return mock;
  }
  
  /// Create mock messaging repository
  static MockMessagingRepository createMessagesRepository({
    String? currentUserId,
    Map<String, Conversation>? conversations,
    Map<String, List<Message>>? messagesByConversation,
    Map<String, Set<String>>? readMessagesByUser,
    Map<String, Map<String, MessageStatus>>? messageStatuses,
  }) {
    final mock = MockMessagingRepository();
    mock.setMessagingState(
      currentUserId: currentUserId,
      conversations: conversations,
      messagesByConversation: messagesByConversation,
      readMessagesByUser: readMessagesByUser,
      messageStatuses: messageStatuses,
    );
    return mock;
  }
  
  /// Create mock friends repository
  static MockFriendsRepository createFriendsRepository({
    String? currentUserId,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? sentRequests,
    List<String>? friendIds,
    List<UserProfile>? friendProfiles,
    Map<String, FriendCategory>? categories,
    List<GroupInvitation>? groupInvitations,
  }) {
    final mock = MockFriendsRepository();
    mock.setFriendsState(
      currentUserId: currentUserId,
      incomingRequests: incomingRequests,
      sentRequests: sentRequests,
      friendIds: friendIds,
      friendProfiles: friendProfiles,
      categories: categories,
      groupInvitations: groupInvitations,
    );
    return mock;
  }
  
  /// Create mock groups repository
  static MockGroupsRepository createGroupsRepository() {
    return MockGroupsRepository();
  }
  
  /// Create mock social recipe repository
  static MockSocialRecipeRepository createSocialRecipeRepository({
    User? currentUser,
    List<SharedRecipe>? sharedRecipes,
    List<SharedMenu>? sharedMenus,
  }) {
    final mock = MockSocialRecipeRepository();
    mock.setSocialRecipeState(
      currentUser: currentUser,
      sharedRecipes: sharedRecipes,
      sharedMenus: sharedMenus,
    );
    return mock;
  }
  
  /// Create mock analytics repository  
  static AnalyticsRepository createAnalyticsRepository() {
    // Using the separate mock file
    return MockAnalyticsRepository();
  }
  
  // ============= SERVICES =============
  
  /// Create mock auth service with proper typing
  static MockAuthService createAuthService({
    bool isAuthenticated = false,
    String? userId,
    User? currentUser,
    String? error,
    bool isLoading = false,
  }) {
    final mock = MockAuthService();
    mock.setAuthState(
      isAuthenticated: isAuthenticated,
      currentUser: currentUser ?? (userId != null ? createMockUser(uid: userId) : null),
      error: error,
      isLoading: isLoading,
    );
    return mock;
  }
  
  /// Create mock user service
  static UserService createUserService() {
    return MockUserService();
  }
  
  /// Create mock permission service
  static PermissionService createPermissionService() {
    return MockPermissionService();
  }
  
  /// Create mock unified recipe service with configuration
  static MockUnifiedRecipeService createUnifiedRecipeService({
    List<Recipe>? recipes,
    bool isInitialized = false,
    bool isLoading = false,
    String? error,
    String? currentUserId,
    String? currentUserDisplayName,
    bool isSyncing = false,
  }) {
    final mock = MockUnifiedRecipeService();
    mock.setRecipeState(
      recipes: recipes ?? [],
      isInitialized: isInitialized,
      isLoading: isLoading,
      error: error,
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      isSyncing: isSyncing,
    );
    return mock;
  }
  
  /// Create mock unified shopping service
  static MockUnifiedShoppingService createUnifiedShoppingService() {
    return MockUnifiedShoppingService();
  }
  
  /// Create mock unified friends service
  static MockUnifiedFriendsService createUnifiedFriendsService() {
    return MockUnifiedFriendsService();
  }
  
  /// Create mock messaging service
  static MockMessagingService createMessagingService() {
    return MockMessagingService();
  }
  
  /// Create mock notification service
  static MockNotificationService createNotificationService() {
    return MockNotificationService();
  }
  
  /// Create mock menu service
  static MockMenuService createMenuService() {
    return MockMenuService();
  }
  
  /// Create mock import manager
  static MockImportManager createImportManager() {
    return MockImportManager();
  }
  
  /// Create mock search service
  static MockSearchService createSearchService() {
    return MockSearchService();
  }
  
  /// Create mock recipe discovery service
  static MockRecipeDiscoveryService createRecipeDiscoveryService() {
    return MockRecipeDiscoveryService();
  }
  
  /// Create mock analytics service
  static MockAnalyticsService createAnalyticsService() {
    return MockAnalyticsService();
  }
  
  /// Create mock storage service
  static MockStorageService createStorageService() {
    return MockStorageService();
  }
  
  /// Create mock dialog service
  static MockDialogService createDialogService() {
    return MockDialogService();
  }
  
  /// Create mock connectivity service
  static MockConnectivityService createConnectivityService() {
    return MockConnectivityService();
  }
  
  // ============= VIEWMODELS =============
  
  /// Create mock auth viewmodel with proper typing
  static MockAuthViewModel createAuthViewModel({
    bool isLoginMode = true,
    bool isPasswordVisible = false,
    bool isLoading = false,
    String? errorMessage,
    bool isAuthenticated = false,
  }) {
    final mock = MockAuthViewModel();
    mock.setAuthViewModelState(
      isLoginMode: isLoginMode,
      isPasswordVisible: isPasswordVisible,
      isLoading: isLoading,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated,
    );
    return mock;
  }
  
  /// Create mock recipe form viewmodel
  static MockRecipeFormViewModel createRecipeFormViewModel() {
    return MockRecipeFormViewModel();
  }
  
  /// Create mock recipe list viewmodel
  static MockRecipeListViewModel createRecipeListViewModel() {
    return MockRecipeListViewModel();
  }
  
  /// Create mock shopping viewmodel
  static MockShoppingViewModel createShoppingViewModel() {
    return MockShoppingViewModel();
  }
  
  /// Create mock menu viewmodel
  static MockMenuViewModel createMenuViewModel() {
    return MockMenuViewModel();
  }
  
  /// Create mock friends viewmodel
  static MockFriendsViewModel createFriendsViewModel() {
    return MockFriendsViewModel();
  }
  
  /// Create mock profile viewmodel
  static MockProfileViewModel createProfileViewModel() {
    return MockProfileViewModel();
  }
  
  /// Create mock settings viewmodel
  static MockSettingsViewModel createSettingsViewModel() {
    return MockSettingsViewModel();
  }
  
  // ============= UTILITIES =============
  
  /// Create mock logger
  static MockLogger createLogger() {
    return MockLogger();
  }
  
  /// Create mock error handler
  static MockErrorHandler createErrorHandler() {
    return MockErrorHandler();
  }
  
  /// Create mock cache manager
  static MockCacheManager createCacheManager() {
    return MockCacheManager();
  }
  
  /// Create mock network manager
  static MockNetworkManager createNetworkManager() {
    return MockNetworkManager();
  }
  
  // ============= TEST DATA =============
  
  /// Create mock Firebase user
  static User createMockUser({
    required String uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? emailVerified,
  }) {
    // Create the mock user directly without MockFirebaseAuth
    // since we just need the User object, not the full auth mock
    return firebase_mocks.MockUser(
      uid: uid,
      email: email ?? 'test@example.com',
      displayName: displayName,
      photoURL: photoURL,
      isEmailVerified: emailVerified ?? true,
    );
  }
  
  /// Create mock user profile
  static UserProfile createUserProfile({
    required String userId,
    String? displayName,
    String? email,
    String? avatarUrl,
    int publicRecipeCount = 0,
    int friendsCount = 0,
    bool isOnline = false,
  }) {
    return UserProfile(
      uid: userId,
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      publicRecipeCount: publicRecipeCount,
      friendsCount: friendsCount,
      isOnline: isOnline,
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }
  
  /// Create fake Firestore instance
  static FakeFirebaseFirestore createFakeFirestore() {
    return FakeFirebaseFirestore();
  }
}

// ============= MOCK IMPLEMENTATIONS =============
// All mock implementations have been moved to production_mocks.dart or service_mocks.dart
// to ensure proper interface implementation and avoid name shadowing issues.