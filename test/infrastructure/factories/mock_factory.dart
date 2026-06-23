/// Mock Factory for generating configured test mocks
///
/// Provides factory methods for creating all mocks used in tests,
/// with configuration methods instead of stubbing for concrete implementations.
library;

import 'dart:typed_data';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart' as firebase_mocks;
import 'package:mocktail/mocktail.dart';
// Import our properly typed mocks with aliases to avoid conflicts
import '../mocks/production_mocks.dart' as production;
import '../mocks/service_mocks.dart' as service;
import '../mocks/widget_mocks.dart' as widget;

// Import models for stubbing
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/user_profile.dart';

// Import interfaces that factory methods return
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

// Import models
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
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

  /// Create fake auth repository with proper typing.
  ///
  /// Returns a [production.FakeAuthRepository] — tests that need mocktail
  /// stubbing on other methods (e.g. `signIn`, `signOut`,
  /// `authStateChanges`) should declare a local
  /// `class _MockAuthRepository extends Mock implements AuthRepository {}`
  /// instead (see BUT-1074).
  static production.FakeAuthRepository createAuthRepository({
    bool isAuthenticated = false,
    String? userId,
    User? user,
  }) {
    final mock = production.FakeAuthRepository();
    mock.setAuthState(
      isAuthenticated: isAuthenticated,
      userId: userId,
      user: user ?? (userId != null ? createMockUser(uid: userId) : null),
    );
    return mock;
  }

  /// Create mock recipe repository with proper typing
  static production.MockRecipeRepository createRecipeRepository({
    String? currentUserId,
    Map<String, List<Recipe>>? recipesByUser,
    List<Recipe>? archiveRecipes,
    List<Recipe>? searchResults,
    Map<String, Recipe>? recipesById,
    List<Recipe>? recipes, // For backward compatibility
  }) {
    final mock = production.MockRecipeRepository();

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
  static production.MockUserRepository createUserRepository({
    String? currentUserId,
    Map<String, UserProfile>? profiles,
    Map<String, bool>? onlineStatus,
    Map<String, String>? fcmTokens,
    Map<String, bool>? notificationSettings,
    Set<String>? availableDisplayNames,
  }) {
    final mock = production.MockUserRepository();
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
  static production.MockShoppingRepository createShoppingRepository() {
    return production.MockShoppingRepository();
  }

  /// Create mock collaborative recipe repository
  static production.MockCollaborativeRecipeRepository
  createCollaborativeRecipeRepository({
    Map<String, RealtimeRecipe>? realtimeRecipes,
    Map<String, Map<String, Map<String, dynamic>>>? presenceData,
    Map<String, List<LiveEditor>>? participants,
    Map<String, Map<String, dynamic>>? userDocuments,
  }) {
    final mock = production.MockCollaborativeRecipeRepository();
    mock.setCollaborativeState(
      realtimeRecipes: realtimeRecipes,
      presenceData: presenceData,
      participants: participants,
      userDocuments: userDocuments,
    );
    return mock;
  }

  /// Create mock messaging repository
  static production.MockMessagingRepository createMessagingRepository({
    String? currentUserId,
    Map<String, Conversation>? conversations,
    Map<String, List<Message>>? messagesByConversation,
    Map<String, Set<String>>? readMessagesByUser,
    Map<String, Map<String, MessageStatus>>? messageStatuses,
  }) {
    final mock = production.MockMessagingRepository();
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
  static production.FakeFirestoreRepository createFirestoreRepository() {
    final mock = production.FakeFirestoreRepository();
    // Mock will provide FakeFirebaseFirestore via its implementation
    return mock;
  }

  /// Create mock comments repository
  static production.MockCommentsRepository createCommentsRepository({
    String? currentUserId,
    Map<String, List<RecipeComment>>? commentsByRecipe,
    Map<String, Set<String>>? likesByComment,
    Map<String, int>? replyCounts,
  }) {
    final mock = production.MockCommentsRepository();
    mock.setCommentsState(
      currentUserId: currentUserId,
      commentsByRecipe: commentsByRecipe,
      likesByComment: likesByComment,
      replyCounts: replyCounts,
    );
    // Setup default behavior for getCommentsStream
    when(
      () => mock.getCommentsStream(any()),
    ).thenAnswer((_) => Stream.value(<RecipeComment>[]));
    return mock;
  }

  /// Create mock ratings repository
  static production.MockRatingsRepository createRatingsRepository() {
    return production.MockRatingsRepository();
  }

  /// Create mock notifications repository
  static production.MockNotificationsRepository createNotificationsRepository({
    String? currentUserId,
    List<UserNotification>? notifications,
    Map<String, NotificationPreferences>? userPreferences,
    Map<String, String>? fcmTokens,
    int? unreadCount,
  }) {
    final mock = production.MockNotificationsRepository();
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
  static production.MockMessagingRepository createMessagesRepository({
    String? currentUserId,
    Map<String, Conversation>? conversations,
    Map<String, List<Message>>? messagesByConversation,
    Map<String, Set<String>>? readMessagesByUser,
    Map<String, Map<String, MessageStatus>>? messageStatuses,
  }) {
    final mock = production.MockMessagingRepository();
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
  static production.MockFriendsRepository createFriendsRepository({
    String? currentUserId,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? sentRequests,
    List<String>? friendIds,
    List<UserProfile>? friendProfiles,
    Map<String, FriendCategory>? categories,
    List<GroupInvitation>? groupInvitations,
  }) {
    final mock = production.MockFriendsRepository();
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
  static production.MockGroupsRepository createGroupsRepository() {
    return production.MockGroupsRepository();
  }

  /// Create mock analytics repository
  static production.MockAnalyticsRepository createAnalyticsRepository() {
    // Using the mock from production_mocks.dart
    return production.MockAnalyticsRepository();
  }

  // ============= SERVICES =============

  /// Create mock auth service with proper typing
  static production.MockAuthService createAuthService({
    bool isAuthenticated = false,
    String? userId,
    User? currentUser,
    String? error,
    bool isLoading = false,
  }) {
    final mock = production.MockAuthService();
    mock.setAuthState(
      isAuthenticated: isAuthenticated,
      currentUser:
          currentUser ?? (userId != null ? createMockUser(uid: userId) : null),
      error: error,
      isLoading: isLoading,
    );
    return mock;
  }

  /// Create mock user service
  static UserService createUserService() {
    return production.MockUserService();
  }

  /// Create mock permission service. Returns the concrete
  /// [production.FakePermissionService] so callers can use
  /// `setProfile()` / other config setters without casts.
  static production.FakePermissionService createPermissionService({
    String? currentUserId = 'test-user-123',
    String? userDisplayName = 'Test User',
    bool defaultHasPermission = true,
  }) {
    final mock = production.FakePermissionService();
    mock.setPermissionState(
      currentUserId: currentUserId,
      userDisplayName: userDisplayName,
      defaultHasPermission: defaultHasPermission,
    );
    return mock;
  }

  /// Create mock unified recipe service with configuration
  static production.MockUnifiedRecipeService createUnifiedRecipeService({
    List<Recipe>? recipes,
    bool isInitialized = false,
    bool isLoading = false,
    String? error,
    String? currentUserId,
    String? currentUserDisplayName,
    bool isSyncing = false,
  }) {
    final mock = production.MockUnifiedRecipeService();
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

  /// Create mock recipe cooking service. Pre-configured to return true
  /// from `markAsCooked` — override via `mock.setMarkAsCookedResult(false)`
  /// when a test wants to exercise the failure branch.
  static production.MockRecipeCookingService createRecipeCookingService() {
    final mock = production.MockRecipeCookingService();
    when(() => mock.markAsCooked(any())).thenAnswer((_) async => true);
    return mock;
  }

  /// Create mock unified shopping service
  static production.MockUnifiedShoppingService createUnifiedShoppingService() {
    return production.MockUnifiedShoppingService();
  }

  /// Create mock unified friends service
  static production.MockUnifiedFriendsService createUnifiedFriendsService() {
    return production.MockUnifiedFriendsService();
  }

  /// Create mock messaging service
  static service.MockMessagingService createMessagingService() {
    return service.MockMessagingService();
  }

  /// Create mock notification service
  static production.MockNotificationService createNotificationService() {
    return production.MockNotificationService();
  }

  /// Create mock menu service
  static service.MockMenuService createMenuService() {
    return service.MockMenuService();
  }

  /// Create mock import manager
  static production.MockImportManager createImportManager() {
    return production.MockImportManager();
  }

  /// Create mock search service
  static service.MockSearchService createSearchService() {
    return service.MockSearchService();
  }

  /// Create mock recipe discovery service
  static service.MockRecipeDiscoveryService createRecipeDiscoveryService() {
    return service.MockRecipeDiscoveryService();
  }

  /// Create mock analytics service
  static production.MockAnalyticsService createAnalyticsService() {
    return production.MockAnalyticsService();
  }

  /// Create mock storage service
  static service.MockStorageService createStorageService() {
    return service.MockStorageService();
  }

  /// Create mock dialog service
  static service.MockDialogService createDialogService() {
    return service.MockDialogService();
  }

  /// Create mock connectivity service
  static service.MockConnectivityService createConnectivityService() {
    return service.MockConnectivityService();
  }

  /// Create mock connectivity monitoring service.
  ///
  /// BUT-610: defaults to ONLINE so the import offline pre-check doesn't trip
  /// tests that don't care about connectivity. Offline-path tests override with
  /// `when(() => mock.isConnectedToInternet).thenReturn(false)`.
  static production.MockConnectivityMonitoringService
  createConnectivityMonitoringService() {
    final mock = production.MockConnectivityMonitoringService();
    when(() => mock.isConnectedToInternet).thenReturn(true);
    return mock;
  }

  /// Create mock image picker service
  static production.MockImagePickerService createImagePickerService() {
    return production.MockImagePickerService();
  }

  /// Create fake XFile for image picker testing
  static production.FakeXFile createXFile(
    String path, {
    String? name,
    int? length,
  }) {
    return production.FakeXFile(name: name ?? 'test.jpg', path: path);
  }

  /// Create mock realtime menu service
  static production.MockRealtimeMenuService createRealtimeMenuService({
    bool isProcessing = false,
    List<String>? categoryNames,
  }) {
    final mock = production.MockRealtimeMenuService();
    mock.setMenuServiceState(
      isProcessing: isProcessing,
      categoryNames: categoryNames,
    );
    return mock;
  }

  /// Create mock realtime sync service
  static production.MockRealtimeSyncService createRealtimeSyncService({
    bool isConnected = true,
  }) {
    final mock = production.MockRealtimeSyncService();
    mock.setConnectionState(isConnected);
    return mock;
  }

  /// Create mock social recipe service
  static production.MockSocialRecipeService createSocialRecipeService({
    List<SharedRecipe>? sharedRecipes,
    List<SharedMenu>? sharedMenus,
    bool isLoading = false,
    String? error,
  }) {
    final mock = production.MockSocialRecipeService();
    mock.setSocialState(
      sharedRecipes: sharedRecipes,
      sharedMenus: sharedMenus,
      isLoading: isLoading,
      error: error,
    );
    return mock;
  }

  /// Create mock optimistic update manager
  static production.MockOptimisticUpdateManager createOptimisticUpdateManager({
    Map<String, List<Recipe>>? optimisticChanges,
    bool hasOptimisticChanges = false,
  }) {
    final mock = production.MockOptimisticUpdateManager();
    mock.setOptimisticState(
      optimisticChanges: optimisticChanges,
      hasOptimisticChanges: hasOptimisticChanges,
    );
    return mock;
  }

  // ============= VIEWMODELS =============

  /// Create mock auth viewmodel with proper typing
  static widget.MockAuthViewModel createAuthViewModel({
    bool isLoginMode = true,
    bool isPasswordVisible = false,
    bool isLoading = false,
    String? errorMessage,
    bool isAuthenticated = false,
  }) {
    final mock = widget.MockAuthViewModel();
    mock.setAuthState(
      isAuthenticated: isAuthenticated,
      userId: isAuthenticated ? 'test_user_123' : null,
      email: isAuthenticated ? 'test@example.com' : null,
    );
    return mock;
  }

  /// Create mock URL import viewmodel
  static production.MockUrlImportViewModel createUrlImportViewModel({
    bool isLoading = false,
    String? error,
    String url = '',
    String extractedText = '',
    bool hasExtractedText = false,
    bool canFetch = false,
    String sourceUrl = '',
  }) {
    final mock = production.MockUrlImportViewModel();
    mock.setUrlImportState(
      isLoading: isLoading,
      error: error,
      url: url,
      extractedText: extractedText,
      hasExtractedText: hasExtractedText,
      canFetch: canFetch,
      sourceUrl: sourceUrl,
    );
    return mock;
  }

  /// Create mock photo import viewmodel
  static PhotoImportViewModel createPhotoImportViewModel({
    bool isLoading = false,
    String? error,
    Uint8List? imageBytes,
    String ocrText = '',
    bool hasImage = false,
    bool hasOcrResult = false,
    bool canImport = false,
    bool isProcessing = false,
  }) {
    final mock = production.MockPhotoImportViewModel();
    mock.setPhotoImportState(
      isLoading: isLoading,
      error: error,
      imageBytes: imageBytes,
      ocrText: ocrText,
      hasImage: hasImage,
      hasOcrResult: hasOcrResult,
      canImport: canImport,
      isProcessing: isProcessing,
    );
    return mock;
  }

  /// Create mock shared content coordinator viewmodel
  static production.MockSharedContentCoordinatorViewModel
  createSharedContentCoordinatorViewModel({
    bool isLoading = false,
    String? error,
    List? sharedContent,
    int activeTab = 0,
    String searchQuery = '',
    bool hasSharedContent = true,
    bool hasFilteredContent = true,
  }) {
    final mock = production.MockSharedContentCoordinatorViewModel();

    // Use non-empty content if hasSharedContent is true
    final contentList = hasSharedContent
        ? (sharedContent ?? ['test-content'])
        : <dynamic>[];

    mock.setSharedContentState(
      isLoading: isLoading,
      error: error,
      sharedContent: contentList,
      activeTab: activeTab,
      searchQuery: searchQuery,
    );
    return mock;
  }

  // createGroupContentViewModel removed - legacy shared_content system deleted

  /// Create mock recipe form viewmodel
  static widget.MockRecipeFormViewModel createRecipeFormViewModel() {
    return widget.MockRecipeFormViewModel();
  }

  /// Create mock recipe list viewmodel
  static widget.MockRecipeListViewModel createRecipeListViewModel() {
    return widget.MockRecipeListViewModel();
  }

  /// Create mock shopping viewmodel
  static service.MockShoppingViewModel createShoppingViewModel() {
    return service.MockShoppingViewModel();
  }

  /// Create mock menu viewmodel
  static widget.MockMenuViewModel createMenuViewModel() {
    return widget.MockMenuViewModel();
  }

  /// Create mock friends viewmodel
  static widget.MockFriendsViewModel createFriendsViewModel() {
    return widget.MockFriendsViewModel();
  }

  /// Create mock profile viewmodel
  static service.MockProfileViewModel createProfileViewModel() {
    return service.MockProfileViewModel();
  }

  /// Create mock user profile viewmodel
  static widget.MockUserProfileViewModel createUserProfileViewModel({
    bool isLoading = false,
    String? error,
    String displayName = 'Test Användare',
    String? avatarUrl,
    bool isSearchable = true,
    bool allowEmailSearch = false,
    bool hasUnsavedChanges = false,
    String? displayNameError,
    bool hasProfile = true,
    bool isFormValid = true,
    CookingSkillLevel? cookingSkillLevel,
    List<String>? cuisineAffinities,
    String? bio,
  }) {
    final mock = widget.MockUserProfileViewModel();
    mock.setUserProfileState(
      isLoading: isLoading,
      error: error,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isSearchable: isSearchable,
      allowEmailSearch: allowEmailSearch,
      hasUnsavedChanges: hasUnsavedChanges,
      displayNameError: displayNameError,
      hasProfile: hasProfile,
      isFormValid: isFormValid,
      cookingSkillLevel: cookingSkillLevel,
      cuisineAffinities: cuisineAffinities,
      bio: bio,
    );
    return mock;
  }

  /// Create mock settings viewmodel
  static service.MockSettingsViewModel createSettingsViewModel() {
    return service.MockSettingsViewModel();
  }

  // ============= UTILITIES =============

  /// Create mock logger
  static service.MockLogger createLogger() {
    return service.MockLogger();
  }

  /// Create mock error handler
  static service.MockErrorHandler createErrorHandler() {
    return service.MockErrorHandler();
  }

  /// Create mock cache manager
  static service.MockCacheManager createCacheManager() {
    return service.MockCacheManager();
  }

  /// Create mock network manager
  static service.MockNetworkManager createNetworkManager() {
    return service.MockNetworkManager();
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

  /// Create mock participant tracker
  static production.MockParticipantTracker createParticipantTracker({
    int activeCount = 0,
    List<ParticipantActivity>? allActivities,
    List<String>? onlineParticipants,
  }) {
    final mock = production.MockParticipantTracker();
    // Configure with standard mocktail stubbing
    when(() => mock.activeCount).thenReturn(activeCount);
    when(
      () => mock.allActivities,
    ).thenReturn(allActivities ?? <ParticipantActivity>[]);
    when(
      () => mock.onlineParticipants,
    ).thenReturn(onlineParticipants ?? <String>[]);
    return mock;
  }

  /// Create fake Firestore instance
  static FakeFirebaseFirestore createFakeFirestore() {
    return FakeFirebaseFirestore();
  }
}

// ============= MOCK IMPLEMENTATIONS =============
// All mock implementations have been moved to production_mocks.dart or service_mocks.dart
// to ensure proper interface implementation and avoid name shadowing issues.
