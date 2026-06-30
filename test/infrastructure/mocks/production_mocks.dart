/// Production-aligned mocks that implement actual interfaces
///
/// These mocks properly implement production interfaces for type safety
/// and compile-time verification of interface changes.
library;

// ignore_for_file: unused_field

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // For BuildContext
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'firestore_singleton.dart';

// Production imports
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
// ActivityRepository removed - dead code
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
// ReactionsRepository removed - dead code
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/menu_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/analytics/trackers/import_events_tracker.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart'; // For MenuOperationError
import 'package:butlery/services/realtime/modules/menu_operations.dart'; // For MenuOperationError class
import 'package:butlery/services/realtime_sync_service.dart' as realtime;
import 'package:butlery/services/realtime/realtime_types.dart' as realtime;
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/viewmodels/realtime/optimistic_update_manager.dart';
// ActivityService removed - dead code
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/unified/operations/social_menu_operations.dart';
import 'package:butlery/services/unified/operations/realtime_recipe_operations.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/realtime_notification_module.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/operations/shopping_share_operations.dart';
import 'package:butlery/services/unified/operations/modules/shopping_social_share_module.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/file_content_provider.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/social_media_extractor.dart'; // For SourcePlatform and ExtractionResult
import 'package:butlery/services/extraction/web_scraper.dart'; // For WebScraper interface
import 'package:butlery/services/social_recipe_service.dart'; // For SocialRecipeService interface
import 'package:butlery/services/image_picker_provider.dart'; // For provider interfaces
// Note: Some interface classes may not exist - using mock implementations instead
import '../di/test_service_locator.dart';
import 'service_mocks.dart'; // For MockRecipeDiscoveryService

// Firebase imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Third-party library imports
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // For Permission and PermissionStatus
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

// ============= REPOSITORY MOCKS =============

/// Fake implementation of AuthRepository with configuration support.
///
/// Extends [Fake] (not [Mock]) on purpose: the previous `extends Mock`
/// version exposed concrete `@override` getters for `currentUser` /
/// `currentUserId`, which silently swallowed `when(() => mock.currentUserId)
/// .thenReturn(...)` stubs — production code read the field-backed concrete
/// getter, not the stubbed value (BUT-1074, BUT-368/369 antipattern).
///
/// Tests configure state via [setAuthState]. Tests that need mocktail
/// `when(...).thenAnswer(...)` for other methods (e.g. `signIn`,
/// `authStateChanges`) should declare a local
/// `class _MockAuthRepository extends Mock implements AuthRepository {}`
/// rather than trying to stub on this fake.
class FakeAuthRepository extends Fake implements AuthRepository {
  // Configuration state
  User? _currentUser;
  String? _currentUserId;

  /// Configure mock state for getters
  void setAuthState({
    User? user,
    String? userId,
    bool isAuthenticated = false,
  }) {
    _currentUser = user;
    _currentUserId = userId ?? user?.uid;
  }

  // Getters return configured state
  @override
  User? get currentUser => _currentUser;

  @override
  String? get currentUserId => _currentUserId;

  @override
  User? getCurrentUser() => _currentUser;

  // Other AuthRepository methods are intentionally unimplemented; calls
  // throw via Fake.noSuchMethod, surfacing tests that depend on behavior
  // this fake doesn't model.
}

/// Always-matured [AccountMaturityHelper] for viewmodel tests.
///
/// BUT-1417 added a client-side maturity gate to the friend/DM/group-invite
/// CTAs; injecting this keeps existing viewmodel tests exercising the
/// post-maturity behavior (the gate is covered directly in
/// account_maturity_cta_test.dart). Returns true regardless of profile/user.
class FakeMaturedAccountHelper extends Fake implements AccountMaturityHelper {
  @override
  bool isMatured({required dynamic profile, required dynamic firebaseUser}) =>
      true;
}

/// Mock implementation of RecipeRepository
class MockRecipeRepository extends Mock implements RecipeRepository {
  // Configuration state
  String? _currentUserId = 'test-user-123';
  Map<String, List<Recipe>> _recipesByUser = {};
  List<Recipe> _archiveRecipes = [];
  List<Recipe> _searchResults = [];
  Map<String, Recipe> _recipesById = {};

  /// Configure mock state for recipe repository
  void setRecipeRepositoryState({
    String? currentUserId,
    Map<String, List<Recipe>>? recipesByUser,
    List<Recipe>? archiveRecipes,
    List<Recipe>? searchResults,
    Map<String, Recipe>? recipesById,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (recipesByUser != null) _recipesByUser = recipesByUser;
    if (archiveRecipes != null) _archiveRecipes = archiveRecipes;
    if (searchResults != null) _searchResults = searchResults;
    if (recipesById != null) _recipesById = recipesById;
  }

  // Convenience method for backward compatibility
  void setRecipes(List<Recipe> recipes) {
    _recipesByUser[_currentUserId ?? 'test-user-123'] = recipes;
    for (final recipe in recipes) {
      _recipesById[recipe.id] = recipe;
    }
  }

  // Getters for accessing configured state
  String? get currentUserId => _currentUserId;
  List<Recipe> get recipes => _recipesByUser[_currentUserId] ?? [];
  Map<String, List<Recipe>> get recipesByUser => _recipesByUser;
  List<Recipe> get archiveRecipes => _archiveRecipes;
  Map<String, Recipe> get recipesById => _recipesById;

  // All methods left without implementation to allow stubbing with when()
  // This includes watchRecipes, subscribeToUserRecipes, searchRecipes,
  // create, read, update, delete, etc.
}

/// Mock implementation of UserRepository
class MockUserRepository extends Mock implements UserRepository {
  // Configuration state
  String? _currentUserId = 'test-user-123';
  Map<String, UserProfile> _profiles = {};
  Map<String, bool> _onlineStatus = {};
  Map<String, String> _fcmTokens = {};
  Map<String, bool> _notificationSettings = {};
  Set<String> _availableDisplayNames = {};

  /// Configure mock state for user repository
  void setUserRepositoryState({
    String? currentUserId,
    Map<String, UserProfile>? profiles,
    Map<String, bool>? onlineStatus,
    Map<String, String>? fcmTokens,
    Map<String, bool>? notificationSettings,
    Set<String>? availableDisplayNames,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (profiles != null) _profiles = profiles;
    if (onlineStatus != null) _onlineStatus = onlineStatus;
    if (fcmTokens != null) _fcmTokens = fcmTokens;
    if (notificationSettings != null) {
      _notificationSettings = notificationSettings;
    }
    if (availableDisplayNames != null) {
      _availableDisplayNames = availableDisplayNames;
    }
  }

  // Getters for configured state (for tests that need them)
  String? get currentUserId => _currentUserId;
  Map<String, UserProfile> get profiles => _profiles;
  Map<String, bool> get onlineStatus => _onlineStatus;
  Map<String, String> get fcmTokens => _fcmTokens;
  Map<String, bool> get notificationSettings => _notificationSettings;

  // All other methods left without implementation to allow stubbing with when()
}

// ============= SERVICE MOCKS =============

/// Mock AuthService with proper ChangeNotifier and mixin implementation
class MockAuthService extends Mock with ChangeNotifier implements AuthService {
  // Configuration state
  User? _currentUser;
  bool _isAuthenticated = false;
  String? _error;
  bool _isLoading = false;

  void setAuthState({
    User? currentUser,
    bool isAuthenticated = false,
    String? error,
    bool isLoading = false,
  }) {
    _currentUser = currentUser;
    _isAuthenticated = isAuthenticated;
    _error = error;
    _isLoading = isLoading;
  }

  @override
  User? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get errorMessage => _error;

  @override
  String? get currentUserId => _currentUser?.uid;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  // Provide default implementations for auth methods. These are
  // state-backed (driven by setAuthState/setError), not pure no-ops —
  // tests that need a specific return override via setAuthState instead
  // of Mocktail's when().
  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return !hasError;
  }

  @override
  Future<bool> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return !hasError;
  }

  @override
  Future<bool> sendPasswordResetEmail(String email) async {
    return !hasError;
  }

  @override
  Future<void> signOut() async {
    if (hasError) {
      throw Exception(_error);
    }
  }

  @override
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// Mock AuthViewModel with proper ChangeNotifier implementation
class MockAuthViewModel extends Mock
    with ChangeNotifier
    implements AuthViewModel {
  // Configuration state
  bool _isLoginMode = true;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthenticated = false;

  void setAuthViewModelState({
    bool isLoginMode = true,
    bool isPasswordVisible = false,
    bool isLoading = false,
    String? errorMessage,
    bool isAuthenticated = false,
  }) {
    _isLoginMode = isLoginMode;
    _isPasswordVisible = isPasswordVisible;
    _isLoading = isLoading;
    _errorMessage = errorMessage;
    _isAuthenticated = isAuthenticated;
  }

  @override
  bool get isLoginMode => _isLoginMode;

  @override
  bool get isPasswordVisible => _isPasswordVisible;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  void toggleAuthMode() {
    _isLoginMode = !_isLoginMode;
    notifyListeners();
  }

  @override
  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  @override
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

/// Mock RecipeFormViewModel
class MockRecipeFormViewModel extends Mock
    with ChangeNotifier, ErrorHandlingMixin
    implements RecipeFormViewModel {
  // Basic state
  bool _isLoading = false;
  String? _error;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  void setFormState({
    bool isLoading = false,
    String? error,
    bool isSaving = false,
    bool hasUnsavedChanges = false,
  }) {
    _isLoading = isLoading;
    _error = error;
    _isSaving = isSaving;
    _hasUnsavedChanges = hasUnsavedChanges;
  }

  bool get isLoading => _isLoading;

  @override
  bool get isSaving => _isSaving;

  @override
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;
}

// ============= FAKE IMPLEMENTATIONS =============
// These are shared fakes that can be used across tests

/// Fake UserCredential for Firebase Auth testing
class FakeUserCredential extends Fake implements UserCredential {
  final User? _user;

  FakeUserCredential([this._user]);

  @override
  User? get user => _user;
}

/// Fake Recipe for testing
class FakeRecipe extends Fake implements Recipe {
  @override
  String get id => 'fake-recipe-id';

  @override
  String get title => 'Fake Recipe';

  @override
  String? get createdBy => 'fake-user-id';
}

/// Fake User for Firebase Auth testing
class FakeUser extends Fake implements User {
  final String _uid;
  final String? _email;
  final String? _displayName;
  final bool _emailVerified;

  FakeUser({
    String? uid,
    String? email,
    String? displayName,
    bool? emailVerified,
  }) : _uid = uid ?? 'fake-uid',
       _email = email ?? 'fake@example.com',
       _displayName = displayName ?? 'Fake User',
       _emailVerified = emailVerified ?? true;

  @override
  String get uid => _uid;

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  @override
  bool get emailVerified => _emailVerified;
}

// ============= OTHER REPOSITORY MOCKS =============

/// Mock implementation of ShoppingRepository
class MockShoppingRepository extends Mock implements ShoppingRepository {
  // Configuration state
  String? _currentUserId = 'test_user_123';
  String? _activeListId;
  Map<String, UnifiedShoppingList> _listsById = {};
  Map<String, UnifiedShoppingList> _personalLists = {};
  Map<String, UnifiedShoppingList> _sharedLists = {};
  Map<String, Map<String, dynamic>> _templates = {};
  Map<String, Map<String, dynamic>> _publicTemplates = {};

  /// Configure mock state for shopping repository
  void setShoppingState({
    String? currentUserId,
    String? activeListId,
    Map<String, UnifiedShoppingList>? listsById,
    Map<String, UnifiedShoppingList>? personalLists,
    Map<String, UnifiedShoppingList>? sharedLists,
    Map<String, Map<String, dynamic>>? templates,
    Map<String, Map<String, dynamic>>? publicTemplates,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (activeListId != null) _activeListId = activeListId;
    if (listsById != null) _listsById = listsById;
    if (personalLists != null) _personalLists = personalLists;
    if (sharedLists != null) _sharedLists = sharedLists;
    if (templates != null) _templates = templates;
    if (publicTemplates != null) _publicTemplates = publicTemplates;
  }

  /// Add or update a shopping list in the mock state
  void addList(UnifiedShoppingList list) {
    _listsById[list.id] = list;
    if (list.isPersonal) {
      _personalLists[list.id] = list;
    } else if (list.isCollaborative) {
      _sharedLists[list.id] = list;
    }
  }

  /// Add a template to the mock state
  void addTemplate(String templateId, Map<String, dynamic> template) {
    _templates[templateId] = template;
    if (template['isPublic'] == true) {
      _publicTemplates[templateId] = template;
    }
  }

  /// Remove a list from the mock state
  void removeList(String listId) {
    final list = _listsById[listId];
    if (list != null) {
      _listsById.remove(listId);
      _personalLists.remove(listId);
      _sharedLists.remove(listId);
    }
  }

  /// Update shopping items in a list
  void updateListItems(String listId, List<UnifiedShoppingItem> items) {
    final list = _listsById[listId];
    if (list != null) {
      final updatedList = list.copyWith(items: items);
      addList(updatedList);
    }
  }

  // Getters for configured state
  String? get currentUserId => _currentUserId;
  String? get activeListId => _activeListId;
  Map<String, UnifiedShoppingList> get listsById => _listsById;
  Map<String, UnifiedShoppingList> get personalLists => _personalLists;
  Map<String, UnifiedShoppingList> get sharedLists => _sharedLists;
  Map<String, Map<String, dynamic>> get templates => _templates;
  Map<String, Map<String, dynamic>> get publicTemplates => _publicTemplates;

  // Concrete helper methods for test configuration (not interface methods)
  UnifiedShoppingList? getListById(String id) => _listsById[id];
  List<UnifiedShoppingList> getAllLists() => _listsById.values.toList();
  List<UnifiedShoppingList> getPersonalLists() =>
      _personalLists.values.toList();
  List<UnifiedShoppingList> getSharedLists() => _sharedLists.values.toList();
  UnifiedShoppingList? getActiveListSync() =>
      _activeListId != null ? _listsById[_activeListId!] : null;
}

/// Mock implementation of CommentsRepository
class MockCommentsRepository extends Mock implements CommentsRepository {
  // Configuration state
  String? _currentUserId = 'test_user_123';
  Map<String, List<RecipeComment>> _commentsByRecipe = {};
  Map<String, Set<String>> _likesByComment = {};
  Map<String, int> _replyCounts = {};

  /// Configure mock state for comments repository
  void setCommentsState({
    String? currentUserId,
    Map<String, List<RecipeComment>>? commentsByRecipe,
    Map<String, Set<String>>? likesByComment,
    Map<String, int>? replyCounts,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (commentsByRecipe != null) _commentsByRecipe = commentsByRecipe;
    if (likesByComment != null) _likesByComment = likesByComment;
    if (replyCounts != null) _replyCounts = replyCounts;
  }

  // Getters for configured state (for tests that need them)
  String? get currentUserId => _currentUserId;
  Map<String, List<RecipeComment>> get commentsByRecipe => _commentsByRecipe;
  Map<String, Set<String>> get likesByComment => _likesByComment;

  // All other methods left without implementation to allow stubbing with when()
}

class MockRatingsRepository extends Mock implements RatingsRepository {
  // Configuration state
  Map<String, RecipeRating> _userRatings = {};
  Map<String, List<RecipeRating>> _recipeRatings = {};
  Map<String, RatingStatistics> _ratingStatistics = {};
  Map<String, bool> _ratingOperationResults = {};

  /// Configure mock state for ratings repository
  void setRatingsState({
    Map<String, RecipeRating>? userRatings,
    Map<String, List<RecipeRating>>? recipeRatings,
    Map<String, RatingStatistics>? ratingStatistics,
    Map<String, bool>? ratingOperationResults,
  }) {
    if (userRatings != null) _userRatings = userRatings;
    if (recipeRatings != null) _recipeRatings = recipeRatings;
    if (ratingStatistics != null) _ratingStatistics = ratingStatistics;
    if (ratingOperationResults != null) {
      _ratingOperationResults = ratingOperationResults;
    }
  }

  // Getters for configured state
  Map<String, RecipeRating> get userRatings => _userRatings;
  Map<String, List<RecipeRating>> get recipeRatings => _recipeRatings;
  Map<String, RatingStatistics> get ratingStatistics => _ratingStatistics;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of NotificationsRepository
class MockNotificationsRepository extends Mock
    implements NotificationsRepository {
  // Configuration state
  String? _currentUserId = 'test_user_123';
  List<UserNotification> _notifications = [];
  Map<String, NotificationPreferences> _userPreferences = {};
  Map<String, String> _fcmTokens = {};
  int _unreadCount = 0;

  /// Configure mock state for notifications repository
  void setNotificationsState({
    String? currentUserId,
    List<UserNotification>? notifications,
    Map<String, NotificationPreferences>? userPreferences,
    Map<String, String>? fcmTokens,
    int? unreadCount,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (notifications != null) _notifications = notifications;
    if (userPreferences != null) _userPreferences = userPreferences;
    if (fcmTokens != null) _fcmTokens = fcmTokens;
    if (unreadCount != null) _unreadCount = unreadCount;
  }

  // Getters for configured state (for tests that need them)
  String? get currentUserId => _currentUserId;
  List<UserNotification> get notifications => _notifications;
  Map<String, NotificationPreferences> get userPreferences => _userPreferences;
  int get unreadCount => _unreadCount;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of NotificationPermissionService.
///
/// The Android 13+ runtime-permission gate. Stub `requestIfNeeded` with
/// `when(() => mock.requestIfNeeded(any())).thenAnswer((_) async => true/false)`
/// to drive the master-toggle grant/deny branch in [NotificationPreferencesView].
class MockNotificationPermissionService extends Mock
    implements NotificationPermissionService {}

/// Mock implementation of NotificationService
class MockNotificationService extends Mock implements NotificationService {
  // Configuration state
  List<Map<String, dynamic>> _sentNotifications = [];
  Map<String, bool> _notificationResults = {};
  int _unreadCount = 0;
  bool _isInitialized = false;

  /// Configure mock state for notification service
  void setNotificationServiceState({
    List<Map<String, dynamic>>? sentNotifications,
    Map<String, bool>? notificationResults,
    int? unreadCount,
    bool? isInitialized,
  }) {
    if (sentNotifications != null) _sentNotifications = sentNotifications;
    if (notificationResults != null) _notificationResults = notificationResults;
    if (unreadCount != null) _unreadCount = unreadCount;
    if (isInitialized != null) _isInitialized = isInitialized;
  }

  // Getters for configured state
  List<Map<String, dynamic>> get sentNotifications => _sentNotifications;
  int get unreadCount => _unreadCount;
  bool get isInitialized => _isInitialized;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of ConnectivityRepository
class MockConnectivityRepository extends Mock
    implements ConnectivityRepository {
  // All methods left without implementation to allow stubbing with when()
}

/// Mock implementation of DeepLinkRepository
class MockDeepLinkRepository extends Mock implements DeepLinkRepository {
  // All methods left without implementation to allow stubbing with when()
}

// MockActivityRepository removed - dead code

/// Mock implementation of MessagingRepository
class MockMessagingRepository extends Mock implements MessagingRepository {
  // Configuration state
  String? _currentUserId = 'test_user_123';
  Map<String, Conversation> _conversations = {};
  Map<String, List<Message>> _messagesByConversation = {};
  Map<String, Set<String>> _readMessagesByUser = {};
  Map<String, Map<String, MessageStatus>> _messageStatuses = {};

  /// Configure mock state for messaging repository
  void setMessagingState({
    String? currentUserId,
    Map<String, Conversation>? conversations,
    Map<String, List<Message>>? messagesByConversation,
    Map<String, Set<String>>? readMessagesByUser,
    Map<String, Map<String, MessageStatus>>? messageStatuses,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (conversations != null) _conversations = conversations;
    if (messagesByConversation != null) {
      _messagesByConversation = messagesByConversation;
    }
    if (readMessagesByUser != null) _readMessagesByUser = readMessagesByUser;
    if (messageStatuses != null) _messageStatuses = messageStatuses;
  }

  /// Add or update a conversation
  void addConversation(Conversation conversation) {
    _conversations[conversation.id] = conversation;
  }

  /// Add a message to a conversation
  void addMessage(String conversationId, Message message) {
    _messagesByConversation.putIfAbsent(conversationId, () => []);
    _messagesByConversation[conversationId]!.add(message);
  }

  /// Mark message as read by user
  void markAsRead(String messageId, String userId) {
    _readMessagesByUser.putIfAbsent(messageId, () => {});
    _readMessagesByUser[messageId]!.add(userId);
  }

  /// Update message status
  void updateStatus(String messageId, String userId, MessageStatus status) {
    _messageStatuses.putIfAbsent(messageId, () => {});
    _messageStatuses[messageId]![userId] = status;
  }

  // Getters for configured state (for tests that need them)
  String? get currentUserId => _currentUserId;
  Map<String, Conversation> get conversations => _conversations;
  Map<String, List<Message>> get messagesByConversation =>
      _messagesByConversation;

  /// Get conversations for a user
  List<Conversation> getUserConversationsList(String userId) {
    return _conversations.values
        .where((c) => c.participantIds.contains(userId))
        .toList();
  }

  /// Get messages for a conversation
  List<Message> getConversationMessagesList(String conversationId) {
    return _messagesByConversation[conversationId] ?? [];
  }

  /// Get unread message count for user
  int getUnreadCount(String userId) {
    int count = 0;
    _messagesByConversation.forEach((convId, messages) {
      for (final message in messages) {
        if (message.senderId != userId) {
          final readBy = _readMessagesByUser[message.id] ?? {};
          if (!readBy.contains(userId)) count++;
        }
      }
    });
    return count;
  }

  /// Find direct conversation between two users
  String? findDirectConversationId(String user1Id, String user2Id) {
    try {
      return _conversations.values
          .where(
            (c) =>
                !c.isGroup &&
                c.participantIds.contains(user1Id) &&
                c.participantIds.contains(user2Id),
          )
          .map((c) => c.id)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  // All other methods left without implementation to allow stubbing with when()
}

// MockReactionsRepository removed - dead code

/// Mock implementation of FriendsRepository
class MockFriendsRepository extends Mock implements FriendsRepository {
  // Configuration state
  String? _currentUserId = 'test_user_123';
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _sentRequests = [];
  List<String> _friendIds = [];
  List<UserProfile> _friendProfiles = [];
  Map<String, FriendCategory> _categories = {};
  List<GroupInvitation> _groupInvitations = [];

  /// Configure mock state for friends repository
  void setFriendsState({
    String? currentUserId,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? sentRequests,
    List<String>? friendIds,
    List<UserProfile>? friendProfiles,
    Map<String, FriendCategory>? categories,
    List<GroupInvitation>? groupInvitations,
  }) {
    if (currentUserId != null) _currentUserId = currentUserId;
    if (incomingRequests != null) _incomingRequests = incomingRequests;
    if (sentRequests != null) _sentRequests = sentRequests;
    if (friendIds != null) _friendIds = friendIds;
    if (friendProfiles != null) _friendProfiles = friendProfiles;
    if (categories != null) _categories = categories;
    if (groupInvitations != null) _groupInvitations = groupInvitations;
  }

  // Getters for configured state (for tests that need them)
  String? get currentUserId => _currentUserId;
  List<FriendRequest> get incomingRequests => _incomingRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  List<String> get friendIds => _friendIds;
  List<UserProfile> get friendProfiles => _friendProfiles;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of GroupsRepository (no interface exists)
class MockGroupsRepository extends Mock {
  // All methods left without implementation to allow stubbing with when()
}

/// Mock implementation of FirestoreRepository
/// Fake implementation of FirestoreRepository — delegates to the singleton
/// `FakeFirebaseFirestore`. Every method has a concrete body, so this is a
/// Fake, not a Mock (`when().thenReturn(...)` on `firestore` / `collection`
/// / `doc` is silently ignored — the body runs instead). Tests that need
/// stubbable behaviour should use a local `class FooMock extends Mock
/// implements FirestoreRepository`.
class FakeFirestoreRepository extends Fake implements FirestoreRepository {
  // Tests that need to inspect documents on their own FakeFirebaseFirestore
  // instance (rather than the shared singleton) pass it via the constructor.
  // Defaults to the singleton so existing callers keep working unchanged.
  FakeFirestoreRepository({FakeFirebaseFirestore? firestore})
    : _fakeFirestore = firestore ?? FirestoreSingleton.instance;

  final FakeFirebaseFirestore _fakeFirestore;

  @override
  FirebaseFirestore get firestore => _fakeFirestore;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _fakeFirestore.collection(path);

  @override
  DocumentReference<Map<String, dynamic>> doc(String path) =>
      _fakeFirestore.doc(path);

  // Production builds users/{uid}/recipes. Mirror the path here so the
  // fake firestore returns a real collection ref (otherwise Fake's
  // noSuchMethod throws UnimplementedError and tests can't proceed).
  @override
  CollectionReference<Map<String, dynamic>> userRecipesCollection(String uid) {
    return _fakeFirestore.collection('users').doc(uid).collection('recipes');
  }

  @override
  Future<void> setDocument(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data,
  ) async {
    await ref.set(data, SetOptions(merge: true));
  }
}

/// Mock implementation of CollaborativeRecipeRepository
class MockCollaborativeRecipeRepository extends Mock
    implements CollaborativeRecipeRepository {
  // Configuration state
  Map<String, RealtimeRecipe> _realtimeRecipes = {};
  Map<String, Map<String, Map<String, dynamic>>> _presenceData = {};
  Map<String, List<LiveEditor>> _participants = {};
  Map<String, Map<String, dynamic>> _userDocuments = {};

  /// Configure mock state for collaborative repository
  void setCollaborativeState({
    Map<String, RealtimeRecipe>? realtimeRecipes,
    Map<String, Map<String, Map<String, dynamic>>>? presenceData,
    Map<String, List<LiveEditor>>? participants,
    Map<String, Map<String, dynamic>>? userDocuments,
  }) {
    if (realtimeRecipes != null) _realtimeRecipes = realtimeRecipes;
    if (presenceData != null) _presenceData = presenceData;
    if (participants != null) _participants = participants;
    if (userDocuments != null) _userDocuments = userDocuments;
  }

  // Getters for configured state (for tests that need them)
  Map<String, RealtimeRecipe> get realtimeRecipes => _realtimeRecipes;
  Map<String, Map<String, Map<String, dynamic>>> get presenceData =>
      _presenceData;
  Map<String, List<LiveEditor>> get participants => _participants;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of FirebaseAuthRepository (concrete class)
class MockFirebaseAuthRepository extends Mock
    implements FirebaseAuthRepository {
  // Configuration state
  User? _currentUser;
  String? _currentUserId;

  /// Configure mock state for getters
  void setAuthState({
    User? user,
    String? userId,
    bool isAuthenticated = false,
  }) {
    _currentUser = user;
    _currentUserId = userId ?? user?.uid;
  }

  @override
  User? get currentUser => _currentUser;

  @override
  String? get currentUserId => _currentUserId;

  // authStateChanges() is intentionally left unimplemented so tests can
  // stub it via when() — unified_recipe_service_test does this. Tests
  // whose code-under-test subscribes to authStateChanges (e.g.
  // UnifiedFriendsService.initialize) must stub it themselves.
}

// ============= SERVICE MOCKS =============

/// Mock UnifiedRecipeService with proper ChangeNotifier implementation
class MockUnifiedRecipeService extends Mock
    with ChangeNotifier
    implements UnifiedRecipeService {
  final _stateController = StreamController<RecipeServiceState>.broadcast();

  @override
  Stream<RecipeServiceState> get stateStream => _stateController.stream;

  // Configuration state
  List<Recipe> _recipes = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;
  String? _currentUserDisplayName;
  bool _isSyncing = false;
  PersonalRecipeOperations? _personalOperations;

  void setRecipeState({
    List<Recipe>? recipes,
    bool isInitialized = false,
    bool isLoading = false,
    String? error,
    String? currentUserId,
    String? currentUserDisplayName,
    bool isSyncing = false,
    PersonalRecipeOperations? personalOperations,
  }) {
    if (recipes != null) _recipes = recipes;
    _isInitialized = isInitialized;
    _isLoading = isLoading;
    _error = error;
    _currentUserId = currentUserId;
    _currentUserDisplayName = currentUserDisplayName;
    _isSyncing = isSyncing;
    if (personalOperations != null) _personalOperations = personalOperations;
  }

  /// Test-time mock-equivalent of a Firestore listener firing a write.
  /// Use from a `when()` stub when a test needs state-after-write
  /// assertions; otherwise `updateRecipe` is a mocktail no-op.
  void applyRecipeWriteToState(Recipe recipe) {
    final i = _recipes.indexWhere((r) => r.id == recipe.id);
    _recipes = i >= 0
        ? (List<Recipe>.of(_recipes)..[i] = recipe)
        : <Recipe>[..._recipes, recipe];
    notifyListeners();
  }

  /// Paired with [applyRecipeWriteToState] for delete flows. No-op when
  /// the id isn't present, so callers don't get spurious notifications.
  void removeRecipeFromState(String recipeId) {
    final next = _recipes.where((r) => r.id != recipeId).toList();
    if (next.length == _recipes.length) return;
    _recipes = next;
    notifyListeners();
  }

  final _mockSocial = FakeSocialRecipeOperations();
  final _mockRealtime = MockRealtimeRecipeOperations();

  @override
  SocialRecipeOperations get social => _mockSocial;

  @override
  RealtimeRecipeOperations get realtime => _mockRealtime;

  FakeSocialRecipeOperations get mockSocial => _mockSocial;
  MockRealtimeRecipeOperations get mockRealtime => _mockRealtime;

  @override
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  @override
  List<Recipe> get personalRecipes =>
      _recipes.where((r) => r.isPersonal).toList();

  @override
  List<Recipe> get collaborativeRecipes =>
      _recipes.where((r) => r.isCollaborative).toList();

  @override
  bool get hasRecipes => _recipes.isNotEmpty;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  @override
  String? get lastError => _error;

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserDisplayName => _currentUserDisplayName;

  @override
  PersonalRecipeOperations get personal {
    if (_personalOperations == null) {
      throw StateError(
        'PersonalRecipeOperations not configured in mock. '
        'Use setRecipeState(personalOperations: mockPersonalOps)',
      );
    }
    return _personalOperations!;
  }

  @override
  bool get isSyncing => _isSyncing;

  @override
  Recipe? getRecipeById(String id) {
    return _recipes.where((r) => r.id == id).firstOrNull;
  }

  @override
  void clearError() {
    _error = null;
  }

  /// Emit a state event on the mock's stateStream for test verification
  void emitState(RecipeServiceState state) {
    _stateController.add(state);
  }

  // Spy-style hook for the few tests that want to verify the args passed
  // to createCollaborativeRecipe (mocktail's verify() can't be used here
  // because the method has a concrete override — needed so VM tests get a
  // real Future<String?> rather than a noSuchMethod-null cast crash).
  final List<Map<String, dynamic>> _createCollaborativeRecipeCalls = [];
  List<Map<String, dynamic>> get createCollaborativeRecipeCalls =>
      List.unmodifiable(_createCollaborativeRecipeCalls);

  bool _collaborativeShouldSucceed = false;
  void setCollaborativeState({bool? shouldSucceed}) {
    if (shouldSucceed != null) _collaborativeShouldSucceed = shouldSucceed;
  }

  @override
  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> memberIds,
    String description = '',
    List<String> ingredients = const [],
    List<String> instructions = const [],
    List<String> imageUrls = const [],
    String mealType = 'Lunch',
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
    String? descriptionCollaborative,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    _createCollaborativeRecipeCalls.add({
      'title': title,
      'memberIds': List<String>.from(memberIds),
      'description': description,
      'ingredients': List<String>.from(ingredients),
      'instructions': List<String>.from(instructions),
      'imageUrls': List<String>.from(imageUrls),
      'mealType': mealType,
      'portions': portions,
      'timeMinutes': timeMinutes,
      'rating': rating,
      'personalTagIds': personalTagIds == null
          ? null
          : List<String>.from(personalTagIds),
      'sourceUrl': sourceUrl,
      'descriptionCollaborative': descriptionCollaborative,
      'allowGuestViewing': allowGuestViewing,
      'allowMemberInvites': allowMemberInvites,
      'categoryIds': categoryIds == null
          ? null
          : List<String>.from(categoryIds),
    });
    return _collaborativeShouldSucceed ? 'collab-$title' : null;
  }

  @override
  Map<String, dynamic> getServiceStatus() {
    return {
      'initialized': _isInitialized,
      'loading': _isLoading,
      'error': _error,
      'recipeCount': _recipes.length,
      'personalCount': personalRecipes.length,
      'collaborativeCount': collaborativeRecipes.length,
    };
  }

  // Methods left without implementation to allow stubbing
  // These will be stubbed in tests as needed
}

/// Mock implementation of UnifiedFriendsService
class MockUnifiedFriendsService extends Mock
    with ChangeNotifier
    implements UnifiedFriendsService {
  // Stream for stateStream — seeded with loading state like production
  final _stateController = StreamController<FriendsServiceState>.broadcast();

  @override
  Stream<FriendsServiceState> get stateStream => _stateController.stream;

  // Configuration state
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  final Set<String> _blockedUsers = {};
  List<FriendCategory> _categories = []; // ⭐ ADDED: Missing categories state
  MockFriendsManagementOperations?
  _management; // ⭐ ADDED: Missing management operations
  MockFriendsCategoriesOperations?
  _categoriesOps; // ⭐ ADDED: Missing categories operations
  MockFriendsInvitationsOperations?
  _invitationsOps; // ⭐ ADDED: Missing invitations operations
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  String? _currentUserId = 'test-user-123';
  String? _currentUserDisplayName = 'Test User';

  void setFriendsState({
    List<UserProfile>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    List<FriendCategory>?
    categoriesList, // ⭐ ADDED: Missing categoriesList parameter
    Set<String>? blockedUsers,
    MockFriendsManagementOperations?
    management, // ⭐ ADDED: Missing management parameter
    MockFriendsCategoriesOperations?
    categories, // ⭐ ADDED: Missing categories operations parameter
    MockFriendsInvitationsOperations?
    invitations, // ⭐ ADDED: Missing invitations operations parameter
    String? currentUserId,
    String? currentUserDisplayName,
    bool isInitialized = false,
    bool isLoading = false,
    String? error,
  }) {
    if (friends != null) _friends = friends;
    if (incomingRequests != null) _incomingRequests = incomingRequests;
    if (outgoingRequests != null) _outgoingRequests = outgoingRequests;
    if (blockedUsers != null) {
      _blockedUsers
        ..clear()
        ..addAll(blockedUsers);
    }
    if (categoriesList != null) {
      _categories = categoriesList;
    }
    if (management != null) {
      _management = management;
    }
    if (categories != null) {
      _categoriesOps = categories;
    }
    if (invitations != null) {
      _invitationsOps = invitations;
    }
    if (currentUserId != null) _currentUserId = currentUserId;
    if (currentUserDisplayName != null) {
      _currentUserDisplayName = currentUserDisplayName;
    }
    _isInitialized = isInitialized;
    _isLoading = isLoading;
    _error = error;
  }

  @override
  List<UserProfile> get friends => List.unmodifiable(_friends);

  @override
  List<FriendRequest> get incomingRequests =>
      List.unmodifiable(_incomingRequests);

  @override
  List<FriendRequest> get outgoingRequests =>
      List.unmodifiable(_outgoingRequests);

  @override
  List<FriendCategory> get categoriesList => List.unmodifiable(_categories); // ⭐ ADDED: Missing categoriesList getter

  @override
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);

  /// Get management operations ⭐ FIXED: Return proper interface type
  @override
  FriendsManagementOperations get management =>
      _management ?? MockFriendsManagementOperations();

  /// Get categories operations ⭐ FIXED: Return stored instance instead of creating new one
  @override
  FriendsCategoriesOperations get categories =>
      _categoriesOps ?? MockFriendsCategoriesOperations();

  /// Get invitations operations ⭐ ADDED: Return stored instance instead of creating new one
  @override
  FriendsInvitationsOperations get invitations =>
      _invitationsOps ?? MockFriendsInvitationsOperations();

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserDisplayName => _currentUserDisplayName;

  @override
  List<UserProfile> get friendsList => List.from(_friends);

  // Internal methods needed by operations classes
  @override
  Map<String, Set<String>> get friendCategoryRelationshipsInternal =>
      _friendCategoryRelationships;
  final Map<String, Set<String>> _friendCategoryRelationships = {};

  @override
  void notifyListenersInternal() => notifyListeners();

  // Invitation internal methods with in-memory tracking
  @override
  List<GroupInvitation> getAllSentInvitationsInternal() =>
      List.unmodifiable(_sentInvitationsTracker);

  @override
  List<GroupInvitation> getReceivedGroupInvitationsInternal(String userId) =>
      [];

  @override
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) =>
      _sentInvitationsTracker
          .where((inv) => inv.id == invitationId)
          .firstOrNull;

  @override
  void addSentInvitationInternal(GroupInvitation invitation) =>
      _sentInvitationsTracker.add(invitation);

  @override
  void updateSentInvitationInternal(
    String invitationId,
    GroupInvitation invitation,
  ) {
    final index = _sentInvitationsTracker.indexWhere(
      (inv) => inv.id == invitationId,
    );
    if (index >= 0) {
      _sentInvitationsTracker[index] = invitation;
    }
  }

  @override
  Future<bool> sendEmailInvitationInternal({
    required String email,
    required GroupInvitation invitation,
  }) async => true;

  @override
  Future<bool> sendSMSInvitationInternal({
    required String phoneNumber,
    required GroupInvitation invitation,
  }) async => true;

  @override
  Future<String> createInvitationLinkInternal(String invitationId) async =>
      'https://butlery.app/invite/$invitationId';

  @override
  Future<void> updateInvitationStatusInternal(
    String invitationId,
    GroupInvitationStatus status,
  ) async {}

  /// Test utility method to update categories list
  void updateCategoriesList(List<FriendCategory> categories) {
    _categories = List.from(categories);
    notifyListeners();
  }

  /// Test utility method to update friends list
  void updateFriendsList(List<UserProfile> friends) {
    _friends = List.from(friends);
    notifyListeners();
  }

  // ===== TEST HELPER PROPERTIES =====

  /// Test helper: Track sent invitations for verification - ✅ FIXED: Missing getter
  final List<GroupInvitation> _sentInvitationsTracker = <GroupInvitation>[];
  List<GroupInvitation> get sentInvitationsList =>
      List.unmodifiable(_sentInvitationsTracker);

  /// Test helper: Clear sent invitations tracker
  void clearSentInvitations() => _sentInvitationsTracker.clear();

  /// Test helper: Add invitation to tracker
  void addSentInvitation(GroupInvitation invitation) =>
      _sentInvitationsTracker.add(invitation);

  // Methods left without implementation to allow stubbing
}

/// Mock implementation of PermissionService
class FakePermissionService extends Fake implements PermissionService {
  // Configuration state
  Map<String, Map<ResourcePermission, bool>> _permissions = {};
  bool _defaultHasPermission = true;
  String? _currentUserId;
  String? _userDisplayName;
  UserProfile? _currentUser;
  bool _isAuthenticated = false;
  // Lookup table for getUserProfile(userId). Tests register expected
  // profiles via setProfile(); production calls fall back to _currentUser
  // when the uid matches it (covers the common "look me up" case).
  final Map<String, UserProfile> _profiles = {};
  // Optional error to throw from getUserProfile (for testing error paths
  // without `when(...).thenThrow(...)`, which Fake doesn't support).
  Object? _profileError;

  /// Configure the profile that `getUserProfile(profile.uid)` returns.
  /// Used in place of `when(...).thenAnswer(...)` since this class extends
  /// Fake (no noSuchMethod plumbing for mocktail stubs).
  void setProfile(UserProfile profile) {
    _profiles[profile.uid] = profile;
  }

  /// Configure `getUserProfile` to throw [error] for ALL calls. Pass null
  /// to clear. Tests use this in place of `when(...).thenThrow(...)`.
  void setProfileError(Object? error) {
    _profileError = error;
  }

  // Per-group admin flags. Defaults to true when no entry is set so the
  // common "owner is admin" path works without explicit setup.
  final Map<String, bool> _groupAdminFlags = {};
  bool _defaultGroupAdmin = true;
  // Per-group delete-permission flags. Same default-true convention.
  final Map<String, bool> _groupDeleteFlags = {};
  bool _defaultCanDeleteGroup = true;

  /// Configure whether the current user is admin of [groupId]. Pass
  /// [groupId] = null to set the default for unconfigured groups.
  void setGroupAdmin({String? groupId, required bool isAdmin}) {
    if (groupId == null) {
      _defaultGroupAdmin = isAdmin;
    } else {
      _groupAdminFlags[groupId] = isAdmin;
    }
  }

  /// Configure whether the current user can delete [groupId]. Pass
  /// [groupId] = null to set the default for unconfigured groups.
  void setCanDeleteGroup({String? groupId, required bool canDelete}) {
    if (groupId == null) {
      _defaultCanDeleteGroup = canDelete;
    } else {
      _groupDeleteFlags[groupId] = canDelete;
    }
  }

  void setPermissionState({
    Map<String, Map<ResourcePermission, bool>>? permissions,
    bool defaultHasPermission = true,
    String? currentUserId,
    String? userDisplayName,
    bool? isAuthenticated,
    UserProfile? currentUser,
  }) {
    if (permissions != null) _permissions = permissions;
    _defaultHasPermission = defaultHasPermission;
    _currentUserId = currentUserId;
    _userDisplayName = userDisplayName;
    if (isAuthenticated != null) _isAuthenticated = isAuthenticated;
    if (currentUser != null) _currentUser = currentUser;
    // If currentUser is set, derive userId/displayName. Authentication is
    // derived as true ONLY when the caller didn't pass an explicit
    // isAuthenticated — an explicit `isAuthenticated: false` is honored as a
    // force-override (BUT-1111) so a previously-authenticated fake can be
    // toggled back to unauthenticated in place to exercise the unauth branch.
    if (_currentUser != null) {
      if (isAuthenticated == null) _isAuthenticated = true;
      _currentUserId = _currentUser!.uid;
      _userDisplayName = _currentUser!.displayName;
    }
    // If currentUserId is set but no explicit auth state, assume authenticated
    if (_currentUserId != null && isAuthenticated == null) {
      _isAuthenticated = true;
    }
  }

  @override
  bool hasPermission(String resourceId, ResourcePermission permission) {
    if (_currentUserId == null) return false;
    if (resourceId.isEmpty) return false;
    return _permissions[resourceId]?[permission] ?? _defaultHasPermission;
  }

  @override
  String? get currentUserId => _currentUserId;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  UserProfile? get currentUser {
    if (_currentUser != null) return _currentUser;
    if (_currentUserId == null) return null;
    return UserProfile(
      uid: _currentUserId!,
      displayName: _userDisplayName ?? 'Test User',
      email: 'test@example.com',
      avatarUrl: 'https://example.com/avatar.jpg',
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }

  @override
  Future<UserProfile?> getUserProfile(String userId) async {
    if (_profileError != null) throw _profileError!;
    if (_profiles.containsKey(userId)) return _profiles[userId];
    if (_currentUser != null && _currentUser!.uid == userId) {
      return _currentUser;
    }
    return null;
  }

  @override
  bool isGroupAdmin(String groupId) {
    return _groupAdminFlags[groupId] ?? _defaultGroupAdmin;
  }

  @override
  bool canDeleteGroup(String groupId) {
    return _groupDeleteFlags[groupId] ?? _defaultCanDeleteGroup;
  }

  @override
  String? get currentUserDisplayName => _userDisplayName ?? 'Test User';

  @override
  bool canEditMenu(String menuId) {
    if (_currentUserId == null) return false;
    if (menuId.isEmpty) return false;
    // Check if user has permission to edit this menu
    return _permissions[menuId]?[ResourcePermission.editor] ??
        _defaultHasPermission;
  }

  @override
  bool canEditRecipe(String recipeId) {
    if (_currentUserId == null) return false;
    if (recipeId.isEmpty) return false;
    // Check if user has permission to edit this recipe
    return _permissions[recipeId]?[ResourcePermission.editor] ??
        _defaultHasPermission;
  }

  @override
  bool isRecipeOwner(String recipeId) {
    if (_currentUserId == null) return false;
    if (recipeId.isEmpty) return false;
    return _permissions[recipeId]?[ResourcePermission.owner] ??
        _defaultHasPermission;
  }

  @override
  bool canViewRecipe(String recipeId) {
    if (_currentUserId == null) return false;
    if (recipeId.isEmpty) return false;
    return _permissions[recipeId]?[ResourcePermission.viewer] ??
        _defaultHasPermission;
  }

  @override
  bool canInviteToRecipe(String recipeId) {
    if (_currentUserId == null) return false;
    if (recipeId.isEmpty) return false;
    return _permissions[recipeId]?[ResourcePermission.editor] ??
        _defaultHasPermission;
  }

  bool isMenuOwner(String menuId) {
    if (_currentUserId == null) return false;
    if (menuId.isEmpty) return false;
    return _permissions[menuId]?[ResourcePermission.owner] ??
        _defaultHasPermission;
  }

  // Shopping list permission methods using the same config-based pattern
  @override
  bool canEditShoppingList(String listId) {
    if (_currentUserId == null) return false;
    if (listId.isEmpty) return false;
    return _permissions[listId]?[ResourcePermission.editor] ??
        _defaultHasPermission;
  }

  @override
  bool canViewShoppingList(String listId) {
    if (_currentUserId == null) return false;
    if (listId.isEmpty) return false;
    return _permissions[listId]?[ResourcePermission.viewer] ??
        _defaultHasPermission;
  }

  @override
  bool canManageShoppingList(String listId) {
    if (_currentUserId == null) return false;
    if (listId.isEmpty) return false;
    return _permissions[listId]?[ResourcePermission.admin] ??
        _defaultHasPermission;
  }

  @override
  bool canDeleteShoppingList(String listId) {
    if (_currentUserId == null) return false;
    if (listId.isEmpty) return false;
    return _permissions[listId]?[ResourcePermission.owner] ??
        _defaultHasPermission;
  }

  @override
  bool isShoppingListOwner(String listId) {
    if (_currentUserId == null) return false;
    if (listId.isEmpty) return false;
    return _permissions[listId]?[ResourcePermission.owner] ??
        _defaultHasPermission;
  }

  /// Reset method for test cleanup - ✅ FIXED: Added missing reset method
  void reset() {
    _permissions.clear();
    _defaultHasPermission = true;
    _currentUserId = null;
    _userDisplayName = null;
    _currentUser = null;
    _isAuthenticated = false;
  }

  // Methods left without implementation to allow stubbing
}

/// Mock implementation of UserService
class MockUserService extends Mock implements UserService {
  // Configuration state
  UserProfile? _currentUser;
  Map<String, UserProfile> _users = {};
  bool _isLoading = false;
  String? _error;

  void setUserState({
    UserProfile? currentUser,
    Map<String, UserProfile>? users,
    bool isLoading = false,
    String? error,
  }) {
    _currentUser = currentUser;
    if (users != null) _users = users;
    _isLoading = isLoading;
    _error = error;
  }

  // Getters for test access
  UserProfile? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  // Helper method for tests
  Future<UserProfile?> getUserById(String userId) async {
    return _users[userId];
  }

  @override
  Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    return userIds
        .where((id) => _users.containsKey(id))
        .map((id) => _users[id]!)
        .toList();
  }
}

/// Mock implementation of PersonalTagService
class MockPersonalTagService extends Mock implements PersonalTagService {}

/// Mock implementation of OfflineService
class MockOfflineService extends Mock implements OfflineService {
  // Configuration state
  bool _isInitialized = false;
  bool _isOfflineMode = false;
  bool _hasPendingChanges = false;
  String? _currentUserId;
  Map<String, List<Recipe>> _offlineRecipes = {};

  void setOfflineState({
    bool isInitialized = false,
    bool isOfflineMode = false,
    bool hasPendingChanges = false,
    String? currentUserId,
    Map<String, List<Recipe>>? offlineRecipes,
  }) {
    _isInitialized = isInitialized;
    _isOfflineMode = isOfflineMode;
    _hasPendingChanges = hasPendingChanges;
    _currentUserId = currentUserId;
    if (offlineRecipes != null) _offlineRecipes = offlineRecipes;
  }

  @override
  bool get isInitialized => _isInitialized;

  bool get isOfflineMode => _isOfflineMode;

  bool get hasPendingChanges => _hasPendingChanges;

  @override
  String? get currentUserId => _currentUserId;

  // Methods left without implementation to allow stubbing
}

// All tracker methods return Future<void>. If a tracker adds a non-void
// return type, this mock will cause a TypeError — add an explicit override.
class _NoOpFutureMock extends Fake {
  /// Fire-once tracker helpers return `Future<bool>` (whether they fired) by
  /// convention — two families: `logFirstXyzIfMilestone`
  /// (`BaseTracker.fireOnceMilestone`) and `...IfFirstEntry`
  /// (e.g. `logSocialOnboardingStartedIfFirstEntry`). Match the suffixes once
  /// instead of a hand-curated list (the list bit-rotted on BUT-803 when
  /// `logFirstCookIfMilestone` was added; BUT-1183 hit the same on the
  /// `IfFirstEntry` family, which crashed view-init for any view touching
  /// social-onboarding analytics). Default no-op returns false (= "did not
  /// fire") so analytics-flow tests don't accidentally claim a milestone fired.
  static final RegExp _milestoneMethodPattern = RegExp(
    r'(IfMilestone|IfFirstEntry)',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      final name = invocation.memberName.toString();
      // Symbols stringify as `Symbol("name")` — substring match is enough.
      if (_milestoneMethodPattern.hasMatch(name)) {
        return Future<bool>.value(false);
      }
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class MockRecipeEventsTracker extends _NoOpFutureMock
    implements RecipeEventsTracker {}

class MockMenuEventsTracker extends _NoOpFutureMock
    implements MenuEventsTracker {}

class MockShoppingEventsTracker extends _NoOpFutureMock
    implements ShoppingEventsTracker {}

class MockSocialEventsTracker extends _NoOpFutureMock
    implements SocialEventsTracker {}

class MockImportEventsTracker extends _NoOpFutureMock
    implements ImportEventsTracker {}

/// Mock implementation of AnalyticsService
class MockAnalyticsService extends Mock implements AnalyticsService {
  // Configuration state
  bool _isInitialized = false;
  // Two distinct slots so a test that arranges a baseline via
  // `setAnalyticsState(currentUserId:)` can't be confused with one that
  // captures what production code actually called `setUserId(...)` with.
  // The old shared `_currentUserId` made `capturedUserId == 'foo'` pass
  // even when production never ran — a footgun the new split eliminates.
  String? _configuredUserId;
  String? _capturedUserId;
  Map<String, dynamic> _userProperties = {};
  // BUT-1021: capture logEvent calls so tests can assert that production
  // code emitted the expected analytics event (e.g. sessionTimeoutLogout
  // from the auth-stream error path). Stays parallel to _capturedUserId —
  // semantically a Fake, not a Mock with when()/verify().
  final List<({String name, Map<String, Object>? parameters})> _capturedEvents =
      [];

  final _recipe = MockRecipeEventsTracker();
  final _menu = MockMenuEventsTracker();
  final _shopping = MockShoppingEventsTracker();
  final _social = MockSocialEventsTracker();
  final _import = MockImportEventsTracker();

  @override
  RecipeEventsTracker get recipe => _recipe;
  @override
  MenuEventsTracker get menu => _menu;
  @override
  ShoppingEventsTracker get shopping => _shopping;
  @override
  SocialEventsTracker get social => _social;
  @override
  ImportEventsTracker get import => _import;

  void setAnalyticsState({
    bool isInitialized = false,
    String? currentUserId,
    Map<String, dynamic>? userProperties,
  }) {
    _isInitialized = isInitialized;
    _configuredUserId = currentUserId;
    if (userProperties != null) _userProperties = userProperties;
  }

  bool get isInitialized => _isInitialized;

  // State-backed no-op method bodies. These methods return Future<void>
  // and are fire-and-forget analytics — tests should not stub them with
  // when() (MockAnalyticsService is semantically a Fake). The concrete
  // bodies below also provide a non-null Future<void> that Mocktail's
  // default-null return cannot supply.
  @override
  Future<void> setUserProperties({
    int? recipeCount,
    bool? hasUsedImport,
    bool? hasSharedRecipe,
    bool? hasCooked,
  }) async {}
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    _capturedEvents.add((name: name, parameters: parameters));
  }

  /// All `logEvent` invocations observed since construction or
  /// [clearCapturedEvents]. Useful for asserting analytics chokepoints
  /// from BUT-1021 (auth stream-error path) and similar flows.
  List<({String name, Map<String, Object>? parameters})> get capturedEvents =>
      List.unmodifiable(_capturedEvents);

  void clearCapturedEvents() => _capturedEvents.clear();
  @override
  Future<void> logFriendRequestSent({
    required String recipientId,
    String? source,
  }) async {}
  @override
  Future<void> logFriendRequestAccepted({required String senderId}) async {}
  @override
  Future<void> setUserId(String? userId) async {
    _capturedUserId = userId;
  }

  /// What production code actually called `setUserId(...)` with —
  /// distinct from `setAnalyticsState(currentUserId:)`'s baseline slot.
  String? get capturedUserId => _capturedUserId;

  /// Baseline configured by `setAnalyticsState(currentUserId:)`. Falls
  /// back to the captured value so legacy callers reading "what's the
  /// user id?" get the latest signal regardless of which path wrote it.
  String? get currentUserId => _configuredUserId ?? _capturedUserId;

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    _userProperties[name] = value;
  }

  Map<String, dynamic> get capturedUserProperties =>
      Map.unmodifiable(_userProperties);
}

/// Mock implementation of RecipeCookingService.
///
/// `RecipeCookingService` extends `BaseService` (not an interface), so this
/// mock implements the class directly. Built as a pure mocktail Mock — no
/// concrete overrides — so callers can both `verify(() => mock.markAsCooked(...))`
/// AND override the return via `setMarkAsCookedResult`. The factory
/// pre-stubs the default success case.
class MockRecipeCookingService extends Mock implements RecipeCookingService {
  /// Re-stub the value returned by `markAsCooked` (default: true via factory).
  void setMarkAsCookedResult(bool result) {
    when(() => markAsCooked(any())).thenAnswer((_) async => result);
  }
}

// ============= IMPORT STRATEGY MOCKS =============

/// Mock implementation of ImportStrategy base interface
///
/// Provides configuration support for testing import strategy behavior
/// without stubbing concrete getters.
class MockImportStrategy extends Mock implements ImportStrategy {
  // Configuration state
  String _strategyName = 'Mock Strategy';
  String _description = 'Mock import strategy for testing';
  String _inputExample = 'Example input';
  bool _canHandle = true;
  bool _validateInput = true;

  void setStrategyState({
    String? strategyName,
    String? description,
    String? inputExample,
    bool canHandle = true,
    bool validateInput = true,
  }) {
    if (strategyName != null) _strategyName = strategyName;
    if (description != null) _description = description;
    if (inputExample != null) _inputExample = inputExample;
    _canHandle = canHandle;
    _validateInput = validateInput;
  }

  @override
  String get strategyName => _strategyName;

  @override
  String get description => _description;

  @override
  String get inputExample => _inputExample;

  // Methods left without implementation to allow stubbing
}

/// Mock implementation of TextImportStrategy
///
/// Provides configuration support for testing text-based recipe imports
/// with parsing patterns and Swedish language support.
class MockTextImportStrategy extends Mock implements TextImportStrategy {
  // Configuration state
  String _strategyName = 'Text Import';
  List<String> _canHandlePatterns = ['ingrediens', 'gör så här'];
  List<String> _supportedMealTypes = ['Frukost', 'Lunch', 'Middag', 'Fika'];

  void setTextParsingState({
    String? strategyName,
    List<String>? canHandlePatterns,
    List<String>? supportedMealTypes,
  }) {
    if (strategyName != null) _strategyName = strategyName;
    if (canHandlePatterns != null) _canHandlePatterns = canHandlePatterns;
    if (supportedMealTypes != null) _supportedMealTypes = supportedMealTypes;
  }

  @override
  String get strategyName => _strategyName;

  @override
  String get description =>
      'Import recipes from text content (social media posts, manual input)';

  @override
  String get inputExample => '''
Pannkakor
Ingredienser:
3 ägg
5 dl mjölk

Gör så här:
1. Vispa ihop allt
2. Stek i smörad panna
''';
}

/// Mock implementation of ImportManager
///
/// Provides configuration support for testing import orchestration
/// with multiple strategies and batch processing capabilities.
class MockImportManager extends Mock implements ImportManager {
  // Configuration state
  List<ImportStrategy> _availableStrategies = [];
  TextImportStrategy? _textImportStrategy;

  void setImportManagerState({
    List<ImportStrategy>? availableStrategies,
    TextImportStrategy? textImportStrategy,
  }) {
    if (availableStrategies != null) _availableStrategies = availableStrategies;
    if (textImportStrategy != null) _textImportStrategy = textImportStrategy;
  }

  @override
  List<ImportStrategy> get availableStrategies =>
      List.unmodifiable(_availableStrategies);

  @override
  TextImportStrategy getTextImportStrategy() {
    if (_textImportStrategy == null) {
      throw StateError('TextImportStrategy not configured in mock');
    }
    return _textImportStrategy!;
  }

  // Methods left without implementation to allow stubbing
}

// ============= INFRASTRUCTURE MOCKS =============

/// Mock implementation of DIContainer for testing
///
/// This mock delegates to the test ServiceLocator to provide consistent
/// service resolution during tests. It mirrors the production DIContainer
/// interface while using the test infrastructure for dependency injection.
class MockDIContainer extends Mock implements DIContainer {
  @override
  T get<T extends Object>() {
    // Use TestServiceLocator for test dependencies
    return TestServiceLocator.get<T>();
  }

  @override
  bool isRegistered<T extends Object>() {
    // Check in TestServiceLocator
    return TestServiceLocator.isRegistered<T>();
  }

  @override
  bool get isInitialized => true; // Always return true for tests
}

/// Mock implementation of PersonalRecipeOperations
///
/// Provides testing support for personal recipe operations including
/// CRUD operations, batch processing, and content management.
/// All methods are left unimplemented to allow stubbing with when().
class MockPersonalRecipeOperations extends Mock
    implements PersonalRecipeOperations {}

// ============= PERFORMANCE SERVICE MOCKS =============

/// Fake implementation of JsonCacheHelper — in-memory maps.
///
/// This is a Fake, not a Mock: every method is a real behavioural
/// implementation, so `when(...).thenReturn(...)` wouldn't work anyway.
/// Tests that need to stub individual calls should use a separate
/// `class XyzMock extends Mock implements JsonCacheHelper` locally.
class FakeJsonCacheHelper extends Fake implements JsonCacheHelper {
  // Configuration state
  String? _currentUserId;
  final Map<String, Map<String, dynamic>> _cache = {};
  final Map<String, List<Map<String, dynamic>>> _listCache = {};

  @override
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
  }

  void setCacheState({Map<String, Map<String, dynamic>>? cache}) {
    if (cache != null) {
      _cache.clear();
      _cache.addAll(cache);
    }
  }

  // Default implementations for concrete methods
  @override
  Future<Map<String, dynamic>?> loadJson(String key) async {
    return _cache[key];
  }

  @override
  Future<bool> saveJson(String key, Map<String, dynamic> data) async {
    _cache[key] = data;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>?> loadJsonList(String key) async {
    return _listCache[key];
  }

  @override
  Future<bool> saveJsonList(
    String key,
    List<Map<String, dynamic>> dataList,
  ) async {
    _listCache[key] = dataList;
    return true;
  }

  @override
  Future<bool> delete(String key) async {
    _cache.remove(key);
    _listCache.remove(key);
    return true;
  }

  @override
  Future<bool> exists(String key) async {
    return _cache.containsKey(key) || _listCache.containsKey(key);
  }

  @override
  Future<List<String>> getAllKeys() async {
    final keys = <String>{};
    keys.addAll(_cache.keys);
    keys.addAll(_listCache.keys);
    return keys.toList();
  }

  @override
  Future<bool> clear() async {
    _cache.clear();
    _listCache.clear();
    return true;
  }

  @override
  Future<JsonCacheStats> getStats() async {
    return JsonCacheStats(
      boxName: 'test_box',
      keyCount: _cache.length + _listCache.length,
      userId: _currentUserId,
    );
  }

  @override
  Future<void> dispose() async {
    // No-op for tests
  }
}

// ============= FIREBASE MOCKS =============
// Note: Many Firebase Firestore classes are sealed and cannot be mocked directly.
// Use FakeFirebaseFirestore from fake_cloud_firestore package for Firestore testing.
// For other Firebase services, we can still mock some interfaces.

/// Mock implementation of FirebaseAuth for mocktail stubbing
/// Note: This is separate from firebase_auth_mocks package's MockFirebaseAuth
/// and is used when you need to stub methods with mocktail's when() syntax
class MockFirebaseAuth extends Mock implements FirebaseAuth {
  // Configuration state
  User? _currentUser;

  /// Configure mock state for FirebaseAuth
  void setAuthState({User? currentUser}) {
    _currentUser = currentUser;
  }

  /// Override currentUser getter to return configured value
  @override
  User? get currentUser => _currentUser;

  // All other methods left without implementation to allow stubbing
}

/// Mock implementation of User for mocktail stubbing with configuration support
/// Note: This is separate from firebase_auth_mocks package's MockUser
/// and provides a setUserState method for test configuration
class MockUser extends Mock implements User {
  // Configuration state
  String? _uid;
  String? _email;
  String? _displayName;

  /// Configure mock state for User
  void setUserState({String? uid, String? email, String? displayName}) {
    _uid = uid;
    _email = email;
    _displayName = displayName;
  }

  /// Override getters to return configured values
  @override
  String get uid => _uid ?? 'test_uid';

  @override
  String? get email => _email;

  @override
  String? get displayName => _displayName;

  // All other methods left without implementation to allow stubbing
}

// NOTE: 13 hand-rolled Firebase SDK-shape mocks were removed here as part of
// BUT-389 step B4 (MockFirebaseFirestore / MockCollectionReference /
// MockDocumentReference / MockDocumentSnapshot / MockQuery / MockQuerySnapshot
// / MockQueryDocumentSnapshot / MockWriteBatch / MockFirebaseStorage /
// MockReference / MockTaskSnapshot / MockFirebaseAnalytics).
//
// Use the real fakes instead:
//   - package:fake_cloud_firestore/fake_cloud_firestore.dart (Firestore)
//   - package:firebase_storage_mocks/firebase_storage_mocks.dart (Storage)
//
// For FirebaseAnalytics, define a local `class MockFirebaseAnalytics extends
// Mock implements FirebaseAnalytics {}` inside the individual test file —
// there's no in-memory fake for analytics in the ecosystem.

/// Mock implementation of StreamSubscription for stream subscription tests
class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}

/// Mock implementation of Timer for timer tests
class MockTimer extends Mock implements Timer {}

/// ULTRATHINK Phase 21 - Essential mock classes (simple Mock, no interface conflicts)

/// Mock for FriendsManagementOperations (Tier 1 - 6 errors)
// REMOVED: Duplicate class definition moved above

/// Fake implementation of SocialRecipeOperations — full in-memory behaviour.
/// Every method has a concrete body driven by `_shouldSucceed` / seed lists,
/// so this is a Fake, not a Mock. Tests that need method-level stubbing
/// should define a local `Mock`.
class FakeSocialRecipeOperations extends Fake
    implements SocialRecipeOperations {
  bool _shouldSucceed = true;

  void setSocialState({bool? shouldSucceed}) {
    if (shouldSucceed != null) _shouldSucceed = shouldSucceed;
  }

  // ===== RECIPE SHARING =====

  @override
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async => _shouldSucceed ? 'shared-$recipeId' : null;

  @override
  Future<String?> makeRecipePersonal({
    required String collaborativeRecipeId,
    String? newTitle,
  }) async => _shouldSucceed ? 'personal-$collaborativeRecipeId' : null;

  @override
  Future<String?> duplicateAndShareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? newTitle,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async => 'duplicate-shared-$recipeId';

  // ===== MEMBER MANAGEMENT =====

  @override
  Future<bool> addMember({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    ResourcePermission? permission,
  }) async => true;

  @override
  Future<bool> removeMember({
    required String recipeId,
    required String userId,
  }) async => true;

  @override
  Future<bool> updateMemberPermission({
    required String recipeId,
    required String userId,
    required ResourcePermission permission,
  }) async => true;

  @override
  Future<List<Map<String, dynamic>>> getRecipeMembers(String recipeId) async =>
      [];

  @override
  bool canInviteMembers(String recipeId) => true;

  @override
  Map<String, dynamic> getMemberStatistics(String recipeId) => {};

  // ===== SOCIAL DISCOVERY =====

  @override
  Future<List<Recipe>> getCollaborativeRecipes({
    int limit = 50,
    String? startAfter,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<List<Recipe>> getSharedWithMe({
    int limit = 50,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<List<Recipe>> getSharedByMe({
    int limit = 50,
    bool includeEmpty = false,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<List<Recipe>> getRecipesByUser({
    required String userId,
    int limit = 50,
    bool includePersonal = false,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async => [];

  @override
  Future<List<Recipe>> getTrendingRecipes({
    int limit = 20,
    Duration? timeWindow,
    List<String>? categoryFilter,
  }) async => [];

  @override
  Future<List<Recipe>> searchRecipes({
    required String query,
    int limit = 20,
    List<String>? categoryFilter,
    bool includePersonal = false,
  }) async => [];

  // ===== RECIPE COMMENTS =====

  @override
  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
    List<String> imageUrls = const [],
  }) async => 'comment-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<List<RecipeComment>> getComments({
    required String recipeId,
    int limit = 20,
    DateTime? before,
    bool includeReplies = true,
  }) async => [];

  @override
  Future<bool> editComment({
    required String commentId,
    required String newContent,
  }) async => true;

  @override
  Future<bool> deleteComment(String commentId) async => true;

  @override
  Future<bool> toggleCommentLike(String commentId) async => true;

  @override
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) =>
      Stream.value([]);

  @override
  Future<Map<String, dynamic>> getCommentStatistics(String recipeId) async =>
      {};

  // ===== RECIPE RATING & SOCIAL STATS =====

  @override
  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
    String? review,
  }) async => true;

  @override
  Future<Map<String, dynamic>> getRecipeStats(String recipeId) async => {};

  @override
  Future<Map<String, dynamic>?> getUserRating(String recipeId) async => null;

  @override
  Future<List<Map<String, dynamic>>> getTopRatedRecipes({
    int limit = 10,
    double minRating = 4.0,
    int minRatingCount = 3,
  }) async => [];

  @override
  Future<Map<String, dynamic>> getUserSocialStats() async => {};

  // ===== LEGACY COMPATIBILITY =====

  @override
  Future<List<Map<String, dynamic>>> getLegacySharedRecipes() async => [];

  @override
  bool checkLegacyPermission(String recipeId, String userId, String action) =>
      true;

  // ===== PERMISSION HELPERS =====

  @override
  bool canView(String recipeId) => true;

  @override
  bool canEdit(String recipeId) => true;

  @override
  bool canDelete(String recipeId) => true;

  @override
  bool canManageMembers(String recipeId) => true;

  @override
  bool canComment(String recipeId) => true;

  @override
  bool canRate(String recipeId) => true;

  @override
  ResourcePermission getUserPermission(String recipeId, String userId) =>
      ResourcePermission.write;

  @override
  Map<String, dynamic> getPermissionSummary(String recipeId, String userId) =>
      {};

  // ===== ADDITIONAL FEATURES =====

  @override
  RecipeDiscoveryService get discoveryService => MockRecipeDiscoveryService();

  @override
  Map<String, dynamic> getDiscoveryStatistics() => {};

  @override
  Future<Map<String, int>> getPopularCollaborativeCategories({
    int limit = 10,
  }) async => {};

  @override
  Map<String, dynamic> getSharingStats() => {};

  @override
  void dispose() {}
}

/// Mock for RecipeServiceAdapter (Tier 1 - 3 errors)
class MockRecipeServiceAdapter extends Mock implements RecipeServiceAdapter {
  /// Create recipe
  @override
  Future<String?> createRecipe(Recipe recipe) async {
    // Mock recipe creation - return recipe ID
    return 'mock-recipe-${recipe.id}'; // Mock creation returns ID
  }

  /// Update recipe
  @override
  Future<bool> updateRecipe(Recipe recipe) async {
    // Mock recipe update - return success status
    return true;
  }

  /// Delete recipe
  @override
  Future<bool> deleteRecipe(String recipeId) async {
    // Mock recipe deletion - return success status
    return true;
  }

  /// Get recipes for user
  @override
  Future<List<Recipe>> getRecipesForUser(String userId) async {
    // Mock user recipes
    return [
      Recipe(
        core: RecipeCore(
          id: 'mock-recipe-1',
          title: 'Mock Recipe 1',
          description: 'Test recipe',
          ingredients: ['ingredient1'],
          instructions: ['step1'],
          mealType: 'Lunch', // FIXED: Added required mealType parameter
          createdBy: userId,
        ),
        type: RecipeType.personal, // FIXED: Added required type parameter
      ),
    ];
  }
}

/// Mock for FriendsManagementOperations - FIXED: Added missing interface methods
class MockFriendsManagementOperations extends Mock
    implements FriendsManagementOperations {
  // Configuration state for testing
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  final Set<String> _blockedUsers = {};
  bool _shouldSucceed = true;
  List<UserProfile> _mutualFriends = [];

  void setManagementState({
    List<UserProfile>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    Set<String>? blockedUsers,
    bool? shouldSucceed,
    List<UserProfile>? mutualFriends,
  }) {
    if (friends != null) _friends = friends;
    if (incomingRequests != null) _incomingRequests = incomingRequests;
    if (outgoingRequests != null) _outgoingRequests = outgoingRequests;
    if (blockedUsers != null) {
      _blockedUsers
        ..clear()
        ..addAll(blockedUsers);
    }
    if (shouldSucceed != null) _shouldSucceed = shouldSucceed;
    if (mutualFriends != null) _mutualFriends = mutualFriends;
  }

  @override
  Future<bool> sendFriendRequest(String recipientId, {String? message}) async =>
      _shouldSucceed;
  @override
  Future<bool> acceptFriendRequest(String requestId) async => _shouldSucceed;
  @override
  Future<bool> rejectFriendRequest(String requestId) async => _shouldSucceed;
  @override
  Future<bool> cancelFriendRequest(String requestId) async => _shouldSucceed;
  @override
  Future<bool> removeFriend(String friendId) async => _shouldSucceed;
  @override
  Future<bool> blockUser(String userId) async => _shouldSucceed;
  @override
  Future<bool> unblockUser(String userId) async => _shouldSucceed;
  @override
  Future<int> blockUsers(List<String> userIds) async =>
      _shouldSucceed ? userIds.length : 0;
  @override
  Future<int> unblockUsers(List<String> userIds) async =>
      _shouldSucceed ? userIds.length : 0;
  @override
  bool isFriend(String userId) =>
      _friends.any((friend) => friend.uid == userId);
  @override
  bool hasOutgoingRequest(String userId) =>
      _outgoingRequests.any((request) => request.toUserId == userId);
  @override
  bool hasIncomingRequest(String userId) =>
      _incomingRequests.any((request) => request.fromUserId == userId);
  @override
  bool isBlocked(String userId) => _blockedUsers.contains(userId);
  @override
  Future<List<UserProfile>> searchUsers(String query) async => [];
  @override
  Future<List<UserProfile>> getMutualFriends(String userId) async =>
      _mutualFriends;
  @override
  List<String> getBlockedUsers() => _blockedUsers.toList();
  @override
  int getIncomingRequestCount() => _incomingRequests.length;
  @override
  Map<String, dynamic> getFriendStats() => {
    'totalFriends': _friends.length,
    'onlineFriends': 0,
    'incomingRequests': _incomingRequests.length,
    'outgoingRequests': _outgoingRequests.length,
    'blockedUsers': _blockedUsers.length,
  };
}

class MockFriendsInvitationsOperations extends Mock
    implements FriendsInvitationsOperations {
  // Configuration state for testing
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  Set<String> _blockedUsers = {};

  /// Configure mock state for tests
  void setFriendsManagementState({
    List<UserProfile>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    Set<String>? blockedUsers,
  }) {
    if (friends != null) _friends = friends;
    if (incomingRequests != null) _incomingRequests = incomingRequests;
    if (outgoingRequests != null) _outgoingRequests = outgoingRequests;
    if (blockedUsers != null) _blockedUsers = blockedUsers;
  }

  /// Alias for setFriendsManagementState - ⭐ FIXED: Missing alias method
  void setManagementState({
    List<UserProfile>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    Set<String>? blockedUsers,
  }) {
    setFriendsManagementState(
      friends: friends,
      incomingRequests: incomingRequests,
      outgoingRequests: outgoingRequests,
      blockedUsers: blockedUsers,
    );
  }

  // ===== KEY METHODS EXPECTED BY TESTS =====

  /// Get all friends ⭐ CRITICAL METHOD
  List<UserProfile> getAllFriends() => List.unmodifiable(_friends);

  /// Get friend by ID
  UserProfile? getFriendById(String friendId) {
    try {
      return _friends.firstWhere((friend) => friend.uid == friendId);
    } catch (e) {
      return null;
    }
  }

  // ===== FRIEND REQUEST MANAGEMENT =====

  /// Send friend request
  Future<bool> sendFriendRequest(String recipientId, {String? message}) async =>
      true;

  /// Accept friend request
  Future<bool> acceptFriendRequest(String requestId) async => true;

  /// Reject friend request
  Future<bool> rejectFriendRequest(String requestId) async => true;

  /// Cancel friend request
  Future<bool> cancelFriendRequest(String requestId) async => true;

  // ===== RELATIONSHIP MANAGEMENT =====

  /// Remove friend
  Future<bool> removeFriend(String friendId) async => true;

  /// Block user
  Future<bool> blockUser(String userId) async => true;

  /// Unblock user
  Future<bool> unblockUser(String userId) async => true;

  // ===== QUERY METHODS =====

  /// Check if user is a friend
  bool isFriend(String userId) =>
      _friends.any((friend) => friend.uid == userId);

  /// Check if has outgoing request
  bool hasOutgoingRequest(String userId) =>
      _outgoingRequests.any((request) => request.toUserId == userId);

  /// Check if has incoming request
  bool hasIncomingRequest(String userId) =>
      _incomingRequests.any((request) => request.fromUserId == userId);

  /// Check if user is blocked
  bool isBlocked(String userId) => _blockedUsers.contains(userId);

  // ===== SEARCH AND DISCOVERY =====

  /// Search users
  Future<List<UserProfile>> searchUsers(String query) async => [];

  /// Get mutual friends
  Future<List<UserProfile>> getMutualFriends(String userId) async => [];

  // ===== MISSING METHODS FROM INTERFACE =====

  /// Get online friends
  List<UserProfile> getOnlineFriends() =>
      _friends.where((friend) => true).toList(); // Mock: all friends are online

  /// Get friends by category
  List<UserProfile> getFriendsByCategory(String category) => [];

  /// Search friends
  List<UserProfile> searchFriends(String query) => _friends
      .where(
        (friend) =>
            friend.displayName.toLowerCase().contains(query.toLowerCase()),
      )
      .toList();

  /// Get incoming requests
  List<FriendRequest> getIncomingRequests() =>
      List.unmodifiable(_incomingRequests);

  /// Get outgoing requests
  List<FriendRequest> getOutgoingRequests() =>
      List.unmodifiable(_outgoingRequests);

  /// Get incoming request count
  int getIncomingRequestCount() => _incomingRequests.length;

  /// Get blocked users
  List<String> getBlockedUsers() => _blockedUsers.toList();

  /// Get friend statistics
  Map<String, dynamic> getFriendStats() => {
    'totalFriends': _friends.length,
    'onlineFriends': _friends.length, // Mock: all friends are online
    'incomingRequests': _incomingRequests.length,
    'outgoingRequests': _outgoingRequests.length,
    'blockedUsers': _blockedUsers.length,
  };
}

/// Mock for FriendsCategoriesOperations - ⭐ FIXED: Added missing methods
class MockFriendsCategoriesOperations extends Mock
    implements FriendsCategoriesOperations {
  // Configuration state
  bool _shouldSucceed = true;
  String? _createdCategoryId;
  List<UserProfile>? _categoryFriends;
  FriendCategory? _categoryByName;
  List<FriendCategory> _friendCategories = [];
  Map<String, List<UserProfile>> _friendsByCategory = {};

  /// Configure mock state for tests
  void setCategoriesState({
    bool shouldSucceed = true,
    String? createdCategoryId,
    List<UserProfile>? categoryFriends,
    FriendCategory? categoryByName,
    List<FriendCategory>? friendCategories,
    // Aliases used by some tests
    List<FriendCategory>? categories,
    Map<String, List<UserProfile>>? friendsByCategory,
  }) {
    _shouldSucceed = shouldSucceed;
    _createdCategoryId = createdCategoryId;
    _categoryFriends = categoryFriends;
    _categoryByName = categoryByName;
    _friendCategories = friendCategories ?? categories ?? [];
    if (friendsByCategory != null) _friendsByCategory = friendsByCategory;
  }

  @override
  Future<String?> createCategory({
    required String name,
    String? description,
    String? icon,
    bool? isPrivate,
    List<String>? initialMemberIds,
  }) async =>
      _shouldSucceed ? (_createdCategoryId ?? 'mock-category-id') : null;

  @override
  Future<void> refresh() async {}

  @override
  FriendCategory? getCategoryById(String categoryId) {
    try {
      return _friendCategories
          .where((category) => category.id == categoryId)
          .firstOrNull;
    } catch (e) {
      return null;
    }
  }

  @override
  List<UserProfile> getFriendsInCategory(String categoryId) =>
      _friendsByCategory[categoryId] ?? [];

  @override
  List<FriendCategory> getCategoriesForFriend(String friendId) =>
      _friendCategories
          .where((c) => c.friendUserIds.contains(friendId))
          .toList();

  @override
  FriendCategory? getCategoryByName(String name) =>
      _friendCategories.where((c) => c.name == name).firstOrNull;

  @override
  List<FriendCategory> getMemberCategories() => _friendCategories;

  // Getters for configured state (tests can access)
  bool get shouldSucceed => _shouldSucceed;
  String? get createdCategoryId => _createdCategoryId;
  List<UserProfile>? get categoryFriends => _categoryFriends;
  List<FriendCategory> get friendCategories =>
      List.unmodifiable(_friendCategories);
}

/// Alias for backwards compatibility (old name without 's')
typedef MockFriendCategoriesOperations = MockFriendsCategoriesOperations;

/// Mock for UnifiedMenuService (Tier 2 - 2 errors)
class MockUnifiedMenuService extends Mock implements UnifiedMenuService {}

/// Fake implementation of ShoppingShareOperations — full in-memory behaviour.
/// Tests that need method-level stubbing should define a local `Mock`.
class FakeShoppingShareOperations extends Fake
    implements ShoppingShareOperations {
  // ===== EXPORT OPERATIONS =====

  /// Export shopping list as formatted text
  @override
  String exportListAsText(String listId) =>
      'Shopping List $listId:\n- Item 1\n- Item 2';

  /// Export shopping list as minimal text (for SMS/messaging)
  @override
  String exportListAsMinimalText(String listId) =>
      'List $listId: Item 1, Item 2';

  /// Export shopping list as structured JSON
  @override
  Map<String, dynamic> exportListAsJson(String listId) => {
    'listId': listId,
    'items': ['Item 1', 'Item 2'],
    'exported': DateTime.now().toIso8601String(),
  };

  /// Export shopping list as CSV
  @override
  String exportListAsCSV(String listId) =>
      'Item,Quantity,Category\nItem 1,1,Food\nItem 2,2,Household';

  // ===== EXTERNAL SHARING OPERATIONS =====

  /// Share shopping list via external apps
  @override
  Future<bool> shareList({
    required String listId,
    String format = 'text',
    String? customMessage,
  }) async => true;

  /// Create public link for shopping list
  @override
  Future<String?> createPublicLink(String listId) async =>
      'https://example.com/shared/$listId';

  // ===== TEMPLATE OPERATIONS =====

  /// Save shopping list as template
  @override
  Future<bool> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
  }) async => true;

  /// Create shopping list from template
  @override
  Future<String?> createFromTemplate({
    required String templateId,
    String? customName,
  }) async => 'new-list-from-template';

  // ===== IMPORT OPERATIONS =====

  /// Import shopping list from text
  @override
  Future<String?> importFromText({
    required String text,
    String? listName,
  }) async => 'imported-list-from-text';

  /// Import shopping list from JSON
  @override
  Future<String?> importFromJson(Map<String, dynamic> jsonData) async =>
      'imported-list-from-json';

  // ===== SOCIAL SHARING OPERATIONS =====

  /// Share shopping list with specific friends
  @override
  Future<bool> shareWithFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async => true;

  /// Share shopping list with single friend ⭐ KEY METHOD
  @override
  Future<bool> shareListWithFriend(String listId, String friendId) async =>
      true;

  /// Share shopping list with multiple friends
  @override
  Future<bool> shareListWithMultipleFriends({
    required String listId,
    required List<String> friendIds,
    String? message,
  }) async => true;

  /// Share shopping list with specific groups
  @override
  Future<bool> shareWithGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) async => true;

  /// Share shopping list with single group
  @override
  Future<bool> shareListWithGroup(String listId, String groupId) async => true;

  /// Share shopping list with multiple groups
  @override
  Future<bool> shareListWithMultipleGroups({
    required String listId,
    required List<String> groupIds,
    String? message,
  }) async => true;

  /// Send shopping list collaboration invitation
  @override
  Future<bool> sendCollaborationInvite({
    required String listId,
    required String recipientId,
    String? message,
  }) async => true;

  /// Get shopping lists shared with current user
  @override
  Future<List<Map<String, dynamic>>> getShoppingListsSharedWithMe() async => [];

  /// Get shopping lists shared by current user
  @override
  Future<List<Map<String, dynamic>>> getShoppingListsSharedByMe() async => [];

  /// Import shared shopping list
  @override
  Future<String?> importSharedShoppingList(String sharedListId) async =>
      'imported-shared-list';

  /// Mark shared shopping list as viewed
  @override
  Future<void> markSharedShoppingListAsViewed(String sharedListId) async {}

  /// Get shopping list sharing statistics
  @override
  Future<Map<String, dynamic>> getShoppingListSharingStats(
    String listId,
  ) async => {
    'sharedWith': 0,
    'views': 0,
    'lastShared': DateTime.now().toIso8601String(),
  };

  // ===== MODULE ACCESS PROPERTIES =====

  @override
  ShoppingExportModule get export => MockShoppingExportModule();

  @override
  ShoppingExternalShareModule get externalShare =>
      MockShoppingExternalShareModule();

  @override
  ShoppingTemplateModule get template => MockShoppingTemplateModule();

  @override
  ShoppingImportModule get import => MockShoppingImportModule();

  @override
  ShoppingSocialShareModule get socialShare => MockShoppingSocialShareModule();
}

/// Mock shopping module classes for ShoppingShareOperations - FIXED: Extend concrete classes with correct constructors
class MockShoppingExportModule extends ShoppingExportModule {
  MockShoppingExportModule();
}

class MockShoppingExternalShareModule extends ShoppingExternalShareModule {
  MockShoppingExternalShareModule()
    : super(permissionService: FakePermissionService());
}

class MockShoppingTemplateModule extends ShoppingTemplateModule {
  MockShoppingTemplateModule();
}

class MockShoppingImportModule extends ShoppingImportModule {
  MockShoppingImportModule();
}

class MockShoppingSocialShareModule extends ShoppingSocialShareModule {
  MockShoppingSocialShareModule()
    : super(
        firestore: FakeFirebaseFirestore(),
        permissionService: FakePermissionService(),
      );
}

/// Mock for AccountDeletionRepository (Tier 2 - 2 errors)
class MockAccountDeletionRepository extends Mock {
  // Configuration state for test scenarios
  final Map<String, bool> _deletionResults = {};

  /// Delete all user recipes
  Future<bool> deleteUserRecipes(String userId) async =>
      _deletionResults['recipes'] ?? true;

  /// Delete all user menus
  Future<bool> deleteUserMenus(String userId) async =>
      _deletionResults['menus'] ?? true;

  /// Delete all user shopping lists
  Future<bool> deleteShoppingLists(String userId) async =>
      _deletionResults['shopping_lists'] ?? true;

  /// Remove all friend connections for user
  Future<bool> removeFriendConnections(String userId) async =>
      _deletionResults['friend_connections'] ?? true;

  /// Delete all user messages
  Future<bool> deleteUserMessages(String userId) async =>
      _deletionResults['messages'] ?? true;

  /// Remove from shared content
  Future<bool> removeFromSharedContent(String userId) async =>
      _deletionResults['shared_content'] ?? true;

  /// Delete comments and ratings
  Future<bool> deleteCommentsAndRatings(String userId) async =>
      _deletionResults['comments_ratings'] ?? true;

  /// Delete user preferences
  Future<bool> deleteUserPreferences(String userId) async =>
      _deletionResults['preferences'] ?? true;

  /// Delete user profile
  Future<bool> deleteUserProfile(String userId) async =>
      _deletionResults['profile'] ?? true;

  /// Create audit log - FIXED: Match production signature with named parameters
  Future<String> createAuditLog({
    required String userId,
    required String email,
    required String reason,
    required List<dynamic> deletedCollections,
    required List<dynamic> failedCollections,
  }) async => 'audit-123';

  /// Test configuration methods
  void resetDeletionState() {
    _deletionResults.clear();
  }

  void setDeletionResult(String operation, bool result) {
    _deletionResults[operation] = result;
  }

  /// Mock audit logs for testing
  List<Map<String, dynamic>> get auditLogs => [
    {
      'id': 'audit-123',
      'userId': 'test-user',
      'reason': 'test-deletion',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    },
  ];
}

/// Tier 3 - Single occurrence mock classes
class MockWebScraper extends Mock implements WebScraper {}

/// Mock implementation of RealtimeRecipeOperations - COMPREHENSIVE INTERFACE
class MockRealtimeRecipeOperations extends Mock
    implements RealtimeRecipeOperations {
  // ===== REAL-TIME WATCHING OPERATIONS =====

  /// ✅ FIXED: Replace Recipe.empty() with null streams - Phase 5A ultrathink approach
  @override
  Stream<Recipe> watchRecipe(String recipeId) => const Stream.empty();

  @override
  Stream<Recipe> watchRecipeWithRetry(
    String recipeId, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) => const Stream.empty();

  @override
  Stream<List<Recipe>> watchMultipleRecipes(List<String> recipeIds) =>
      Stream.value([]);

  @override
  Stream<Map<String, Recipe?>> watchMultipleRecipesIndividually(
    List<String> recipeIds,
  ) => Stream.value({});

  bool _connected = false;

  void setRealtimeState({bool? connected}) {
    if (connected != null) _connected = connected;
  }

  @override
  bool get isConnected => _connected;

  @override
  Stream<bool> get connectionStream => Stream.value(_connected);

  @override
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 10),
  }) async => true;

  @override
  Stream<ConnectionStatus> monitorConnectionStatus() => Stream.value(
    ConnectionStatus(
      isConnected: true,
      timestamp: DateTime.now(),
      hasRealtimeService: true,
    ),
  );

  @override
  StreamSubscription<Recipe> startWatchingRecipe(
    String recipeId,
    void Function(Recipe) onRecipeUpdated, {
    void Function(dynamic)? onError,
  }) => Stream<Recipe>.empty().listen(onRecipeUpdated, onError: onError);

  @override
  StreamSubscription<List<Recipe>> startWatchingMultipleRecipes(
    List<String> recipeIds,
    void Function(List<Recipe>) onRecipesUpdated, {
    void Function(dynamic)? onError,
  }) => Stream<List<Recipe>>.empty().listen(onRecipesUpdated, onError: onError);

  @override
  bool isWatchingAvailable() => true;

  @override
  Map<String, bool> getWatchingCapabilities() => {
    'realtime': true,
    'offline': true,
  };

  // ===== REAL-TIME EDITING OPERATIONS =====

  @override
  Future<bool> startRealtimeEditing(String recipeId) async => true;

  @override
  Future<bool> stopRealtimeEditing(String recipeId) async => true;

  @override
  bool isInRealtimeEditingMode(String recipeId) => true;

  @override
  Future<bool> makeRealtimeEdit({
    required String recipeId,
    required Map<String, dynamic> changes,
    String? editDescription,
  }) async => true;

  @override
  Future<bool> makeBatchRealtimeEdits({
    required String recipeId,
    required List<Map<String, dynamic>> changeList,
    String? batchDescription,
  }) async => true;

  @override
  Future<bool> undoLastRealtimeEdit(String recipeId) async => true;

  @override
  Future<bool> resolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    required String resolution,
    String? localActiveField,
  }) async => true;

  @override
  Future<bool> autoResolveConflict({
    required String recipeId,
    required Recipe localVersion,
    required Recipe remoteVersion,
    String strategy = 'merge',
    String? localActiveField,
  }) async => true;

  @override
  Future<List<ConflictInfo>> getPendingConflicts(String recipeId) async =>
      <ConflictInfo>[];

  @override
  bool validateEditChanges(String recipeId, Map<String, dynamic> changes) =>
      true;

  @override
  Map<String, dynamic> getEditValidationRules() => {};

  @override
  Map<String, dynamic> getEditingStatus(String recipeId) => {};

  // ===== COLLABORATION FEATURES =====

  @override
  Future<bool> enableCollaborativeEditing(
    String recipeId,
    List<String> memberIds,
  ) async => true;

  @override
  Future<bool> disableCollaborativeEditing(String recipeId) async => true;

  @override
  bool canEnableCollaboration(String recipeId) => true;

  @override
  bool canDisableCollaboration(String recipeId) => true;

  @override
  Future<bool> addCollaborators(
    String recipeId,
    List<String> memberIds,
  ) async => true;

  @override
  Future<bool> removeCollaborators(
    String recipeId,
    List<String> memberIds,
  ) async => true;

  @override
  Future<bool> updateMemberPermissions(
    String recipeId,
    Map<String, String> memberPermissions,
  ) async => true;

  @override
  Future<bool> transferOwnership(String recipeId, String newOwnerId) async =>
      true;

  @override
  Future<bool> leaveCollaboration(String recipeId) async => true;

  @override
  Map<String, dynamic> getCollaborationDetails(String recipeId) => {};

  @override
  Map<String, dynamic> getCollaborationStats(String recipeId) => {};

  @override
  Future<List<Map<String, dynamic>>> getCollaborationHistory(
    String recipeId,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> getEditHistory(String recipeId) async =>
      [];

  @override
  Map<String, String> validateCollaborationSettings({
    required List<String> memberIds,
    Map<String, String>? memberPermissions,
  }) => {};

  @override
  bool isWithinCollaborationLimits(String recipeId, int additionalMembers) =>
      true;

  @override
  Map<String, dynamic> getCollaborationStatus(String recipeId) => {};

  // ===== PRESENCE FEATURES =====

  @override
  Future<bool> showPresence(String recipeId) async => true;

  @override
  Future<bool> hidePresence(String recipeId) async => true;

  @override
  Future<bool> updatePresenceHeartbeat(String recipeId) async => true;

  @override
  Future<List<Map<String, dynamic>>> getRecipePresence(String recipeId) async =>
      [];

  @override
  Future<Map<String, List<Map<String, dynamic>>>> getMultipleRecipePresence(
    List<String> recipeIds,
  ) async => {};

  @override
  bool isUserPresent(String recipeId, String userId) => true;

  @override
  int getPresenceCount(String recipeId) => 1;

  @override
  Stream<List<Map<String, dynamic>>> watchRecipePresence(String recipeId) =>
      Stream.value([]);

  @override
  Stream<Map<String, List<Map<String, dynamic>>>> watchMultipleRecipePresence(
    List<String> recipeIds,
  ) => Stream.value({});

  @override
  Stream<int> watchPresenceCount(String recipeId) => Stream.value(1);

  @override
  StreamSubscription<void>? startAutomaticPresenceTracking(
    String recipeId, {
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) => Stream<void>.empty().listen(null);

  @override
  Future<void> updateMultipleRecipePresence(
    Map<String, bool> recipePresenceMap,
  ) async {}

  @override
  Future<void> clearAllPresence() async {}

  @override
  Map<String, dynamic> getPresenceStatistics() => {};

  @override
  List<Map<String, dynamic>> getUserPresenceHistory(String userId) => [];

  // ===== LEGACY METHODS =====

  @override
  List<String> getActiveEditors(String recipeId) => [];

  // ===== MODULE STATUS AND DIAGNOSTICS =====

  @override
  Map<String, dynamic> getModuleStatus() => {};

  @override
  Map<String, dynamic> getRealtimeOperationsStatus() => {};
}

/// Mock implementation of PermissionProvider - ⭐ FIXED: Implements correct interface
class MockPermissionProvider extends Mock implements PermissionProvider {
  /// Check permission status - FIXED: Correct types (Permission -> PermissionStatus)
  @override
  Future<PermissionStatus> checkPermission(Permission permission) async {
    // Mock permission granted by default
    return PermissionStatus.granted;
  }

  /// Request permission - FIXED: Correct types (Permission -> PermissionStatus)
  @override
  Future<PermissionStatus> requestPermission(Permission permission) async {
    // Mock permission request granted by default
    return PermissionStatus.granted;
  }
}

class MockNotificationRepository extends Mock {
  /// Get notification preferences
  Future<Map<String, dynamic>> getPreferences(String userId) async {
    return {
      'enabled': true,
      'sound': true,
      'vibration': true,
      'categories': ['social', 'recipes', 'system'],
    };
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String userId, String token) async {
    // Mock token storage
  }

  /// Update device information
  Future<void> updateDeviceInfo(
    String userId,
    Map<String, dynamic> deviceInfo,
  ) async {
    // Mock device info update
  }

  /// Update token timestamp
  Future<void> updateTokenTimestamp(String userId, String token) async {
    // Mock timestamp update
  }

  /// Remove old token
  Future<void> removeOldToken(String userId, String oldToken) async {
    // Mock token removal
  }

  /// Cleanup old devices
  Future<void> cleanupOldDevices(String userId) async {
    // Mock old device cleanup
  }

  /// Get all user tokens
  Future<List<String>> getAllUserTokens(String userId) async {
    return ['mock-token-1', 'mock-token-2'];
  }

  /// Mark device as inactive
  Future<void> markDeviceInactive(String userId, String deviceId) async {
    // Mock device deactivation
  }
}

/// ✅ FIXED: Complete NotificationParent mock implementation - PHASE 4B SUCCESS!
class MockNotificationParent extends Mock implements NotificationParent {
  // Configuration state for notification parent
  Map<String, dynamic> _parentState = {};

  /// Configure mock state for notification parent testing - ✅ FIXED: Added missing parameters
  void setNotificationParentState({
    Map<String, dynamic>? parentState,
    String? currentUserId,
    String? currentUserDisplayName,
  }) {
    if (parentState != null) _parentState = parentState;
    if (currentUserId != null) _parentState['currentUserId'] = currentUserId;
    if (currentUserDisplayName != null) {
      _parentState['currentUserDisplayName'] = currentUserDisplayName;
    }
  }

  // Getters for configured state
  Map<String, dynamic> get parentState => _parentState;

  // All other methods left without implementation to allow stubbing with when()
}

class MockMenuCollaborationRepository extends Mock
    implements MenuCollaborationRepository {
  // State-backed no-ops. See MockAnalyticsService note — returning a real
  // value is necessary for Future<bool>-typed methods that Mocktail cannot
  // default-supply. Tests that need failure paths should configure state
  // or define a local Mock for the specific test case.
  @override
  Future<bool> enableCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  }) async => true;

  @override
  void startCollaborationListener(
    String menuId,
    Function(SharedMenu) onUpdate,
  ) {}

  @override
  Future<bool> addRecipeToMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  }) async => true;

  @override
  Future<bool> removeRecipeFromMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  }) async => true;

  @override
  void disposeAllListeners() {}
}

// ✅ REMOVED: Duplicate MockLegacyNotificationRepository - keeping the complete version
/// Mock implementation of ImageValidator - ⭐ FIXED: Implements correct interface
class MockImageValidator extends Mock implements ImageValidator {
  /// Validate if file is a valid image - FIXED: File parameter instead of String
  @override
  bool isValidImageFile(File file) {
    // Mock validation - accept common image extensions
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
    return validExtensions.any((ext) => file.path.toLowerCase().endsWith(ext));
  }
}

/// Mock implementation of ImagePickerProvider - ⭐ FIXED: Implements correct interface
class MockImagePickerProvider extends Mock implements ImagePickerProvider {
  /// Pick image from source - FIXED: Correct types (ImageSource, returns XFile)
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    // Mock image picker - return mock XFile
    return XFile('/mock/path/to/test-image.jpg');
  }

  /// Pick multiple images - FIXED: No source param, returns List of XFile
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    // Mock multi image picker - return mock XFiles
    return [
      XFile('/mock/path/to/image1.jpg'),
      XFile('/mock/path/to/image2.jpg'),
    ];
  }
}

/// ✅ FIXED: Complete FileContentProvider interface alignment - PHASE 4C SUCCESS!
class MockFileContentProvider extends Mock implements FileContentProvider {
  // Configuration state
  FilePickerResult? _mockResult;

  /// Configure mock result for testing
  void setFilePickerResult(FilePickerResult? result) {
    _mockResult = result;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = true,
    bool withReadStream = false,
  }) async {
    return _mockResult;
  }

  @override
  Future<FilePickerResult?> provideContent(
    Uint8List content,
    String fileName,
    String? extension,
  ) async {
    return _mockResult;
  }
}

// ============= THIRD-PARTY LIBRARY MOCKS =============

/// Mock implementation of File from dart:io
class MockFile extends Mock implements File {}

/// Mock implementation of ImagePicker
class MockImagePicker extends Mock implements ImagePicker {}

/// Mock implementation of XFile
class MockXFile extends Mock implements XFile {}

/// Mock implementation of FilePickerResult
class MockFilePickerResult extends Mock implements FilePickerResult {}

/// Mock implementation of PlatformFile
class MockPlatformFile extends Mock implements PlatformFile {}

/// Mock implementation of SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

/// Mock implementation of Connectivity
class MockConnectivity extends Mock implements Connectivity {}

/// Mock implementation of Uuid
class MockUuid extends Mock implements Uuid {}

/// Mock implementation of SharePlus
class MockSharePlus extends Mock implements SharePlus {}

/// Mock implementation of RemoteMessage (FCM)
class MockRemoteMessage extends Mock implements RemoteMessage {}

/// Mock implementation of RemoteNotification (FCM)
class MockRemoteNotification extends Mock implements RemoteNotification {}

/// Mock implementation of FirebaseMessaging with composable state.
///
/// BUT-1008: previously every interesting failure path needed a bespoke
/// subclass (_NullTokenMessaging, _ThrowingTopicMessaging, etc.). Now
/// `setFirebaseMessagingState` exposes the failure flags directly so a
/// single instance can compose them (e.g. null token AND throwing topic
/// AND throwing settings — no subclass required).
class MockFirebaseMessaging extends Mock implements FirebaseMessaging {
  // Configuration state
  String? _token = 'test-fcm-token-123';
  AuthorizationStatus _authorizationStatus = AuthorizationStatus.authorized;
  Stream<String> _tokenRefreshStream = const Stream.empty();
  bool _throwOnSubscribe = false;
  bool _throwOnUnsubscribe = false;
  bool _throwOnSettings = false;

  /// Configure FCM messaging state for testing.
  ///
  /// Pass `token: null` (with `clearToken: true`) to simulate the
  /// permission-denied / non-iOS-non-Android path where `getToken` returns
  /// null. The `clearToken` flag is required because `token: null` alone is
  /// indistinguishable from "not provided" in nullable named params.
  ///
  /// The `throwOn*` flags simulate transient FCM SDK failures — e.g.
  /// network blip during topic subscribe, or settings query throwing.
  void setFirebaseMessagingState({
    String? token,
    bool clearToken = false,
    AuthorizationStatus? authorizationStatus,
    Stream<String>? tokenRefreshStream,
    bool? throwOnSubscribe,
    bool? throwOnUnsubscribe,
    bool? throwOnSettings,
  }) {
    if (clearToken) {
      _token = null;
    } else if (token != null) {
      _token = token;
    }
    if (authorizationStatus != null) _authorizationStatus = authorizationStatus;
    if (tokenRefreshStream != null) _tokenRefreshStream = tokenRefreshStream;
    if (throwOnSubscribe != null) _throwOnSubscribe = throwOnSubscribe;
    if (throwOnUnsubscribe != null) _throwOnUnsubscribe = throwOnUnsubscribe;
    if (throwOnSettings != null) _throwOnSettings = throwOnSettings;
  }

  // Core token methods
  @override
  Future<String?> getToken({
    String? serviceWorkerScriptPath,
    String? vapidKey,
  }) async => _token;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshStream;

  // Permission methods
  @override
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = true,
    bool criticalAlert = false,
    bool providesAppNotificationSettings = true,
    bool provisional = false,
    bool sound = true,
  }) async {
    return MockNotificationSettings(authorizationStatus: _authorizationStatus);
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    if (_throwOnSettings) {
      throw Exception('Simulated getNotificationSettings failure (BUT-1008)');
    }
    return MockNotificationSettings(authorizationStatus: _authorizationStatus);
  }

  // Topic subscription methods
  @override
  Future<void> subscribeToTopic(String topic) async {
    if (_throwOnSubscribe) {
      throw Exception('Simulated subscribeToTopic failure (BUT-1008)');
    }
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_throwOnUnsubscribe) {
      throw Exception('Simulated unsubscribeFromTopic failure (BUT-1008)');
    }
  }

  // Message handling
  Stream<RemoteMessage> get onMessage => const Stream.empty();

  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  Stream<RemoteMessage> get onBackgroundMessage => const Stream.empty();
}

/// ✅ FIXED: Complete NotificationSettings mock implementation - PHASE 4B SUCCESS!
/// Mock implementation of NotificationSettings
class MockNotificationSettings extends Mock implements NotificationSettings {
  AuthorizationStatus _authorizationStatus = AuthorizationStatus.authorized;
  final AppleNotificationSetting _alert;
  final AppleNotificationSetting _announcement;
  final AppleNotificationSetting _badge;
  final AppleNotificationSetting _carPlay;
  final AppleNotificationSetting _lockScreen;
  final AppleNotificationSetting _notificationCenter;
  final AppleShowPreviewSetting _showPreviews;
  final AppleNotificationSetting _timeSensitive;
  final AppleNotificationSetting _criticalAlert;
  final AppleNotificationSetting _sound;

  MockNotificationSettings({
    AuthorizationStatus authorizationStatus = AuthorizationStatus.authorized,
    AppleNotificationSetting alert = AppleNotificationSetting.enabled,
    AppleNotificationSetting announcement =
        AppleNotificationSetting.notSupported,
    AppleNotificationSetting badge = AppleNotificationSetting.enabled,
    AppleNotificationSetting carPlay = AppleNotificationSetting.enabled,
    AppleNotificationSetting lockScreen = AppleNotificationSetting.enabled,
    AppleNotificationSetting notificationCenter =
        AppleNotificationSetting.enabled,
    AppleShowPreviewSetting showPreviews = AppleShowPreviewSetting.always,
    AppleNotificationSetting timeSensitive =
        AppleNotificationSetting.notSupported,
    AppleNotificationSetting criticalAlert =
        AppleNotificationSetting.notSupported,
    AppleNotificationSetting sound = AppleNotificationSetting.enabled,
  }) : _alert = alert,
       _announcement = announcement,
       _badge = badge,
       _carPlay = carPlay,
       _lockScreen = lockScreen,
       _notificationCenter = notificationCenter,
       _showPreviews = showPreviews,
       _timeSensitive = timeSensitive,
       _criticalAlert = criticalAlert,
       _sound = sound {
    _authorizationStatus = authorizationStatus;
  }

  /// Configure notification settings for testing
  void setAuthorizationStatus(AuthorizationStatus status) {
    _authorizationStatus = status;
  }

  @override
  AuthorizationStatus get authorizationStatus => _authorizationStatus;

  @override
  AppleNotificationSetting get alert => _alert;

  @override
  AppleNotificationSetting get announcement => _announcement;

  @override
  AppleNotificationSetting get badge => _badge;

  @override
  AppleNotificationSetting get carPlay => _carPlay;

  @override
  AppleNotificationSetting get lockScreen => _lockScreen;

  @override
  AppleNotificationSetting get notificationCenter => _notificationCenter;

  @override
  AppleShowPreviewSetting get showPreviews => _showPreviews;

  @override
  AppleNotificationSetting get timeSensitive => _timeSensitive;

  @override
  AppleNotificationSetting get criticalAlert => _criticalAlert;

  @override
  AppleNotificationSetting get sound => _sound;
}

/// Mock implementation of FCMService
///
/// Provides configuration support for testing FCM functionality.
/// Note: FCMService uses static methods, so this mock helps with testing
/// components that depend on FCM functionality.
class MockFCMService extends Mock {
  // Configuration state
  String? _fcmToken = 'test_fcm_token_123';
  bool _isInitialized = false;
  Set<String> _subscribedTopics = {};

  void setFCMState({
    String? fcmToken,
    bool isInitialized = false,
    Set<String>? subscribedTopics,
  }) {
    if (fcmToken != null) _fcmToken = fcmToken;
    _isInitialized = isInitialized;
    if (subscribedTopics != null) _subscribedTopics = subscribedTopics;
  }

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  Set<String> get subscribedTopics => Set.unmodifiable(_subscribedTopics);

  // Methods left without implementation to allow stubbing
}

/// ✅ FIXED: Complete Fake Notification classes - PHASE 4B SUCCESS!
/// Simple fake notification strategy for testing
class FakeNotificationStrategy {
  final String id;
  final String name;
  final Map<String, dynamic> configuration;

  const FakeNotificationStrategy({
    required this.id,
    required this.name,
    this.configuration = const {},
  });

  factory FakeNotificationStrategy.defaults() {
    return const FakeNotificationStrategy(
      id: 'test-strategy',
      name: 'Test Strategy',
      configuration: {'enabled': true},
    );
  }

  /// Adapter method to convert to production NotificationStrategy
  NotificationStrategy toNotificationStrategy() {
    return NotificationStrategy(
      type: NotificationType.immediate,
      priority: NotificationPriority.medium,
      category: NotificationCategory.social,
    );
  }
}

/// Simple fake notification preferences for testing
class FakeNotificationPreferences {
  final bool enabled;
  final Map<String, bool> categories;
  final Map<String, bool> types;

  const FakeNotificationPreferences({
    this.enabled = true,
    this.categories = const {},
    this.types = const {},
  });

  factory FakeNotificationPreferences.defaults() {
    return const FakeNotificationPreferences(
      enabled: true,
      categories: {'friends': true, 'recipes': true},
      types: {'immediate': true, 'digest': false},
    );
  }

  /// Adapter method to convert to production NotificationPreferences
  NotificationPreferences toNotificationPreferences() {
    return NotificationPreferences(
      enabled: enabled,
      categorySettings: const {
        NotificationCategory.friends: true,
        NotificationCategory.recipes: true,
        NotificationCategory.social: true,
        NotificationCategory.system: true,
        NotificationCategory.collaboration: true,
        NotificationCategory.shopping: false,
        NotificationCategory.messaging: true,
      },
      typeSettings: const {
        NotificationType.immediate: true,
        NotificationType.batchable: true,
        NotificationType.silent: true,
        NotificationType.digest: false,
        NotificationType.optional: false,
      },
      allowBatching: true,
      digestFrequency: 'never',
      soundEnabled: enabled,
      vibrationEnabled: enabled,
      lastUpdated: DateTime.now(),
    );
  }
}

/// Mock implementation of RealtimeSyncService
///
/// Provides comprehensive real-time synchronization mocking for collaborative features.
/// Supports stream management, caching, and connection state simulation.
class MockRealtimeSyncService extends Mock
    with ChangeNotifier
    implements realtime.RealtimeSyncService {
  // Configuration state
  final Map<String, RealtimeResource> _cache = {};
  final Map<String, StreamController<RealtimeResource>> _streamControllers = {};
  // ignore: close_sinks - Closed in disposeStreams()
  final StreamController<realtime.SyncError> _errorStreamController =
      StreamController<realtime.SyncError>.broadcast();
  bool _isConnected = false;
  bool _isInitialized = false;
  realtime.SyncError? _lastError;

  /// Configure connection state
  void setConnectionState(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  /// Set cached resource for testing
  void setCachedResource(String id, RealtimeResource resource) {
    _cache[id] = resource;
  }

  /// Trigger stream update for testing real-time changes
  void triggerStreamUpdate(String id, RealtimeResource resource) {
    if (_streamControllers.containsKey(id)) {
      _streamControllers[id]!.add(resource);
    }
  }

  /// Set error state for testing error scenarios
  void setError(realtime.SyncError? error) {
    _lastError = error;
    if (error != null && !_errorStreamController.isClosed) {
      _errorStreamController.add(error);
    }
    notifyListeners();
  }

  /// Create or get stream controller for a resource
  StreamController<T> getOrCreateStreamController<T extends RealtimeResource>(
    String id,
  ) {
    if (!_streamControllers.containsKey(id)) {
      _streamControllers[id] = StreamController<RealtimeResource>.broadcast();
    }
    return _streamControllers[id]! as StreamController<T>;
  }

  // Getters for configured state
  @override
  bool get isConnected => _isConnected;

  bool get isInitialized => _isInitialized;

  @override
  realtime.SyncError? get lastError {
    return _lastError;
  }

  @override
  Stream<realtime.SyncError> get errorStream => _errorStreamController.stream;

  @override
  T? getCachedResource<T extends RealtimeResource>(String resourceId) {
    return _cache[resourceId] as T?;
  }

  // Initialize state for testing
  void setInitialized(bool initialized) {
    _isInitialized = initialized;
  }

  // Clean up stream controllers
  void disposeStreams() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    if (!_errorStreamController.isClosed) {
      _errorStreamController.close();
    }
  }

  // Override dispose to match BaseService signature
  @override
  Future<void> dispose() async {
    disposeStreams();
    super.dispose();
  }

  // Reset all state
  void reset() {
    _cache.clear();
    disposeStreams();
    _isConnected = false;
    _isInitialized = false;
    _lastError = null;
  }

  // ===== MISSING TEST-SPECIFIC METHODS =====

  /// Trigger connection change for testing
  void triggerConnectionChange(bool connected) {
    setConnectionState(connected);
  }

  /// Emit error for testing error scenarios
  void emitError(realtime.SyncError error) {
    setError(error);
  }

  /// Emit menu update for testing - ✅ FIXED: Flexible parameter handling for Phase 4E
  void emitMenu(RealtimeMenu menu, [String? menuId]) {
    final id = menuId ?? menu.id;
    if (_streamControllers.containsKey(id)) {
      _streamControllers[id]!.add(menu);
    }
  }
}

// Note: FakePermissionService already exists earlier in this file at line 991
// This duplicate has been removed to avoid compilation errors

/// Mock implementation of AnalyticsRepository
class MockAnalyticsRepository extends Mock implements AnalyticsRepository {
  // Configuration state for test scenarios
  Map<String, dynamic> _analyticsState = {};

  /// Configure mock state for analytics repository (renamed to match interface)
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    _analyticsState['isEnabled'] = enabled;
  }

  /// Configure mock state for analytics repository (helper for tests)
  void setAnalyticsState({
    bool isInitialized = true,
    bool isEnabled = true,
    Map<String, dynamic>? customProperties,
    List<String>? eventHistory,
    String? userId,
  }) {
    _analyticsState = {
      'isInitialized': isInitialized,
      'isEnabled': isEnabled,
      'customProperties': customProperties ?? {},
      'eventHistory': eventHistory ?? [],
      'userId': userId,
    };
  }

  /// Reset analytics state for testing
  void resetForTesting() {
    _analyticsState.clear();
  }

  // Getters for configured state
  Map<String, dynamic> get analyticsState => _analyticsState;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of UnifiedShoppingService
class MockUnifiedShoppingService extends Mock
    implements UnifiedShoppingService {
  // Stream controller for stateStream
  final _stateController = StreamController<ShoppingServiceState>.broadcast();

  @override
  Stream<ShoppingServiceState> get stateStream => _stateController.stream;

  // Configuration state - FIXED: All required properties
  bool _isLoading = false;
  String? _error;
  List<UnifiedShoppingList> _shoppingLists = [];
  List<UnifiedShoppingList> _personalLists = [];
  List<UnifiedShoppingList> _collaborativeLists = [];
  String? _activeListId;
  bool _isInitialized = true;
  String? _currentUserId;
  String? _currentUserDisplayName;
  bool _isSyncing = false;
  ShoppingShareOperations? _shareOps;
  Map<String, dynamic>? _shoppingState;

  /// Configure mock state for tests - ⭐ FIXED: Complete parameter interface alignment
  void setShoppingState({
    bool isLoading = false,
    String? error,
    List<UnifiedShoppingList>? lists,
    List<UnifiedShoppingList>? personalLists,
    List<UnifiedShoppingList>? collaborativeLists, // ⭐ ADDED: Missing parameter
    String? activeListId,
    bool isInitialized = true, // ⭐ ADDED: Missing parameter
    String? currentUserId, // ⭐ ADDED: Missing parameter
    String? currentUserDisplayName, // ⭐ ADDED: Missing parameter
    bool isSyncing = false, // ⭐ ADDED: Missing parameter
    ShoppingShareOperations?
    shareOps, // Accepts any ShoppingShareOperations subtype
    Map<String, dynamic>? state,
  }) {
    _isLoading = isLoading;
    _error = error;
    _shoppingLists = lists ?? [];
    _personalLists = personalLists ?? [];
    _collaborativeLists =
        collaborativeLists ?? []; // ⭐ ADDED: Store collaborative lists
    _activeListId = activeListId;
    _isInitialized = isInitialized; // ⭐ ADDED: Store initialization state
    _currentUserId = currentUserId; // ⭐ ADDED: Store current user ID
    _currentUserDisplayName =
        currentUserDisplayName; // ⭐ ADDED: Store current user display name
    _isSyncing = isSyncing; // ⭐ ADDED: Store syncing state
    _shareOps = shareOps; // ⭐ ADDED: Store share operations
    _shoppingState =
        state ??
        {
          'lists': _shoppingLists,
          'personalLists': _personalLists,
          'collaborativeLists': _collaborativeLists,
          'activeListId': _activeListId,
        };
  }

  // ⭐ FIXED: Complete getter interface alignment
  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  @override
  List<UnifiedShoppingList> get lists => _shoppingLists;

  @override
  List<UnifiedShoppingList> get personalLists => _personalLists;

  @override
  List<UnifiedShoppingList> get collaborativeLists => _collaborativeLists; // ⭐ ADDED: Missing getter

  @override
  String? get activeListId => _activeListId;

  @override
  bool get isInitialized => _isInitialized; // ⭐ ADDED: Missing getter

  @override
  String? get currentUserId => _currentUserId; // ⭐ ADDED: Missing getter

  @override
  String? get currentUserDisplayName => _currentUserDisplayName; // ⭐ ADDED: Missing getter

  @override
  bool get isSyncing => _isSyncing; // ⭐ ADDED: Missing getter

  /// Get share operations ⭐ FIXED: Return proper interface type
  @override
  ShoppingShareOperations get share =>
      _shareOps ?? FakeShoppingShareOperations();

  /// Alias for share (production service exposes both)
  @override
  ShoppingShareOperations get sharing => share;

  @override
  UnifiedShoppingList? get activeList {
    if (_activeListId == null) return null;
    try {
      return _shoppingLists.firstWhere((list) => list.id == _activeListId);
    } catch (_) {
      return null;
    }
  }

  // Legacy getters for backward compatibility
  List<UnifiedShoppingList> get shoppingLists => _shoppingLists;
  Map<String, dynamic>? get shoppingState => _shoppingState;

  /// Emit a state event on the mock's stateStream for test verification
  void emitState(ShoppingServiceState state) {
    _stateController.add(state);
  }

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of ConnectivityMonitoringService
class MockConnectivityMonitoringService extends Mock
    implements ConnectivityMonitoringService {
  // All methods left without implementation to allow stubbing with when()
}

/// Mock implementation of ImagePickerService
class MockImagePickerService extends Mock implements ImagePickerService {
  // All methods left without implementation to allow stubbing with when()
}

/// Mock implementation of RealtimeMenuService - ⭐ FIXED: Complete interface implementation
class MockRealtimeMenuService extends Mock implements RealtimeMenuService {
  // Configuration state
  bool _isProcessing = false;
  List<String> _categoryNames = [];
  RealtimeMenu? _currentMenu;
  MenuOperationError? _lastError;

  /// Configure mock state for tests
  void setMenuServiceState({
    bool isProcessing = false,
    List<String>? categoryNames,
  }) {
    _isProcessing = isProcessing;
    _categoryNames = categoryNames ?? [];
  }

  // Getters for configured state (tests can access)
  @override
  bool get isProcessing => _isProcessing;
  @override
  List<String> get categoryNames => _categoryNames;
  @override
  MenuOperationError? get lastError => _lastError;

  // ===== MOCK METHOD IMPLEMENTATIONS =====

  /// Create realtime menu from existing category menu
  @override
  Future<RealtimeMenu> createRealtimeMenu({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    List<String>? editorUserIds,
    List<String>? viewerUserIds,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    DateTime? createdForDate,
  }) async {
    final menu = RealtimeMenu.fromMenuCategories(
      menuTitle: menuTitle,
      menuSnapshot: menuSnapshot,
      ownerId: 'mock-user',
      ownerDisplayName: 'Mock User',
      editorUserIds: editorUserIds,
      viewerUserIds: viewerUserIds,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
      createdForDate: createdForDate,
    );
    _currentMenu = menu;
    return menu;
  }

  /// Watch realtime menu updates
  @override
  Stream<RealtimeMenu> watchRealtimeMenu(String resourceId) {
    final menu =
        _currentMenu ??
        RealtimeMenu.fromMenuCategories(
          menuTitle: 'Mock Menu',
          menuSnapshot: Map.fromIterables(
            _categoryNames,
            _categoryNames.map((name) => <Recipe>[]).toList(),
          ),
          ownerId: 'mock-user',
          ownerDisplayName: 'Mock User',
        );
    return Stream.value(menu);
  }

  /// Add recipe to specific category
  @override
  Future<void> addRecipeToCategory({
    required String resourceId,
    required String categoryName,
    required Recipe recipe,
  }) async {
    // Mock implementation
  }

  /// Remove recipe from category
  @override
  Future<void> removeRecipeFromCategory({
    required String resourceId,
    required String categoryName,
    required int recipeIndex,
  }) async {
    // Mock implementation
  }

  /// Move recipe between categories
  @override
  Future<void> moveRecipeBetweenCategories({
    required String resourceId,
    required String fromCategory,
    required String toCategory,
    required int fromIndex,
    int? toIndex,
  }) async {
    // Mock implementation
  }

  /// Update basic menu information
  @override
  Future<void> updateBasicInfo({
    required String resourceId,
    String? menuTitle,
    DateTime? createdForDate,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
  }) async {
    // Mock implementation
  }

  /// Clear category (remove all recipes)
  @override
  Future<void> clearCategory({
    required String resourceId,
    required String categoryName,
  }) async {
    // Mock implementation
  }

  /// Regenerate category with AI
  @override
  Future<void> regenerateCategory({
    required String resourceId,
    required String categoryName,
    required List<Recipe> newRecipes,
  }) async {
    // Mock implementation
  }

  /// Add participant to menu
  @override
  Future<void> addParticipant({
    required String resourceId,
    required String userId,
    required String userDisplayName,
    ResourcePermission permission = ResourcePermission.viewer,
  }) async {
    // Mock implementation
  }

  /// Remove participant from menu
  @override
  Future<void> removeParticipant({
    required String resourceId,
    required String userId,
  }) async {
    // Mock implementation
  }

  /// Create personal copy of menu
  @override
  Map<String, List<Recipe>> createPersonalCopy(RealtimeMenu realtimeMenu) {
    return Map.fromIterables(
      _categoryNames,
      _categoryNames.map((name) => <Recipe>[]).toList(),
    );
  }

  /// Delete realtime menu
  @override
  Future<void> deleteRealtimeMenu(String resourceId) async {
    // Mock implementation
    _currentMenu = null;
  }

  /// Set error state
  void setError(MenuOperationError error) {
    _lastError = error;
  }

  /// Dispose resources
  @override
  Future<void> dispose() async {
    // Mock implementation
  }

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of SocialRecipeService - FIXED: Now implements proper interface
class MockSocialRecipeService extends Mock implements SocialRecipeService {
  // Configuration state
  bool _isLoading = false;
  String? _error;
  List<SharedRecipe> _sharedRecipes = [];
  List<SharedMenu> _sharedMenus = [];

  /// Configure mock state for tests
  void setSocialState({
    bool isLoading = false,
    String? error,
    List<SharedRecipe>? sharedRecipes,
    List<SharedMenu>? sharedMenus,
  }) {
    _isLoading = isLoading;
    _error = error;
    _sharedRecipes = sharedRecipes ?? [];
    _sharedMenus = sharedMenus ?? [];
  }

  // ⭐ FIXED: Getters matching production interface exactly
  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  @override
  List<SharedRecipe> get sharedRecipes => List.unmodifiable(_sharedRecipes);

  @override
  List<SharedMenu> get sharedMenus => List.unmodifiable(_sharedMenus);

  @override
  List<SharedRecipe> get sharedWithMe => sharedRecipes;

  // ===== QUERY METHODS =====

  /// Common methods expected by tests (can be stubbed with when())
  @override
  List<SharedRecipe> getVisibleSharedRecipes(String currentUserId) =>
      sharedRecipes;

  @override
  List<SharedMenu> getVisibleSharedMenus(String currentUserId) => sharedMenus;

  @override
  Future<bool> isRecipeSharedByUser(String recipeId, String userId) async =>
      false;

  @override
  Future<List<UserProfile>> getRecipeParticipants(String recipeId) async => [];

  @override
  Future<bool> isMenuSharedByUser(String menuId, String userId) async => false;

  @override
  Future<List<UserProfile>> getMenuParticipants(String menuId) async => [];

  // ===== INTERACTION METHODS =====

  /// ⭐ ADDED: Additional methods based on production interface
  @override
  Future<bool> markSharedRecipeAsViewed(String recipeId, String userId) async =>
      true;

  @override
  Future<bool> markSharedMenuAsViewed(String menuId, String userId) async =>
      true;

  @override
  Future<bool> importSharedRecipe(String recipeId) async => true;

  @override
  Future<bool> importSharedMenu(String menuId) async => true;

  @override
  Future<bool> dismissSharedRecipe(String recipeId) async => true;

  @override
  Future<bool> dismissSharedMenu(String menuId) async => true;

  @override
  Future<bool> undismissSharedRecipe(String recipeId) async => true;

  @override
  Future<bool> undismissSharedMenu(String menuId) async => true;

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of OptimisticUpdateManager
class MockOptimisticUpdateManager extends Mock
    implements OptimisticUpdateManager {
  // Configuration state
  bool _hasOptimisticChanges = false;
  Map<String, List<Recipe>>? _optimisticChanges;

  /// Configure mock state for tests
  void setOptimisticState({
    bool hasOptimisticChanges = false,
    Map<String, List<Recipe>>? optimisticChanges,
  }) {
    _hasOptimisticChanges = hasOptimisticChanges;
    _optimisticChanges = optimisticChanges;
  }

  // Getters for configured state (tests can access)
  bool get hasOptimisticChanges => _hasOptimisticChanges;
  Map<String, List<Recipe>>? get optimisticChanges => _optimisticChanges;

  // Additional getters for test compatibility
  @override
  bool get hasChanges => _hasOptimisticChanges;
  @override
  Map<String, List<Recipe>> get allChanges =>
      Map.unmodifiable(_optimisticChanges ?? {});

  /// Apply change - FIXED: Correct signature with optional third parameter
  @override
  void applyChange(
    String categoryName,
    List<Recipe> Function(List<Recipe>) updateFunction, [
    List<Recipe>? currentRecipes, // CRITICAL: Optional third parameter
  ]) {
    // Mock implementation - apply update function to current recipes
    final recipes = currentRecipes ?? [];
    final updatedRecipes = updateFunction(recipes);
    _optimisticChanges ??= {};
    _optimisticChanges![categoryName] = updatedRecipes;
    _hasOptimisticChanges = true;
  }

  /// Rollback optimistic changes - ⭐ FIXED: Added missing method
  @override
  void rollback({String? categoryName}) {
    if (categoryName != null) {
      _optimisticChanges?.remove(categoryName);
      if (_optimisticChanges?.isEmpty == true) {
        _hasOptimisticChanges = false;
      }
    } else {
      // Rollback all changes
      _optimisticChanges?.clear();
      _hasOptimisticChanges = false;
    }
  }

  /// Clear all optimistic changes - ⭐ FIXED: Added missing method
  @override
  void clear() {
    _optimisticChanges?.clear();
    _hasOptimisticChanges = false;
  }

  /// Apply optimistic changes to menu - ⭐ FIXED: Added missing method
  @override
  Map<String, List<Recipe>> applyToMenu(Map<String, List<Recipe>> menu) {
    if (!_hasOptimisticChanges || _optimisticChanges == null) {
      return menu;
    }

    final updatedMenu = Map<String, List<Recipe>>.from(menu);
    for (final entry in _optimisticChanges!.entries) {
      updatedMenu[entry.key] = entry.value;
    }
    return updatedMenu;
  }

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of UrlImportViewModel
class MockUrlImportViewModel extends Mock implements UrlImportViewModel {
  // Configuration state
  bool _isLoading = false;
  String? _error;
  String _url = '';
  String _extractedText = '';
  bool _hasExtractedText = false;
  bool _canFetch = false;
  String _sourceUrl = '';

  /// Configure mock state for tests
  void setUrlImportState({
    bool isLoading = false,
    String? error,
    String url = '',
    String extractedText = '',
    bool hasExtractedText = false,
    bool canFetch = false,
    String sourceUrl = '',
  }) {
    _isLoading = isLoading;
    _error = error;
    _url = url;
    _extractedText = extractedText;
    _hasExtractedText = hasExtractedText;
    _canFetch = canFetch;
    _sourceUrl = sourceUrl;
  }

  // Getters for configured state (tests can access)
  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  @override
  String get url => _url;
  @override
  String get extractedText => _extractedText;
  @override
  bool get hasExtractedText => _hasExtractedText;
  @override
  bool get canFetch => _canFetch;
  @override
  String get sourceUrl => _sourceUrl;
  @override
  bool get isMultiUrl => false;
  @override
  List<UrlImportResult> get urlResults => const [];
  @override
  bool get hasAnyUrlSuccess => false;
  @override
  int get successfulUrlCount => 0;
  @override
  bool get isIndexPageCandidate => false;
  @override
  List<String> get indexPageLinks => const [];
  @override
  String get successfulBatchText => '';
  @override
  bool get hasError => _error != null;

  // All methods left without implementation to allow stubbing with when()
}

/// Mock implementation of PhotoImportViewModel
class MockPhotoImportViewModel extends Mock implements PhotoImportViewModel {
  // Configuration state
  bool _isLoading = false;
  String? _error;
  Uint8List? _imageBytes;
  String _ocrText = '';
  bool _hasImage = false;
  bool _hasOcrResult = false;
  bool _canImport = false;
  bool _isProcessing = false;
  bool _hasMultipleRecipes = false;
  List<Recipe> _parsedRecipes = const [];

  /// Configure mock state for tests
  void setPhotoImportState({
    bool isLoading = false,
    String? error,
    Uint8List? imageBytes,
    String ocrText = '',
    bool hasImage = false,
    bool hasOcrResult = false,
    bool canImport = false,
    bool isProcessing = false,
    bool hasMultipleRecipes = false,
    List<Recipe> parsedRecipes = const [],
  }) {
    _isLoading = isLoading;
    _error = error;
    _imageBytes = imageBytes;
    _ocrText = ocrText;
    _hasImage = hasImage;
    _hasOcrResult = hasOcrResult;
    _canImport = canImport;
    _isProcessing = isProcessing;
    _hasMultipleRecipes = hasMultipleRecipes;
    _parsedRecipes = parsedRecipes;
  }

  // Getters for configured state (tests can access)
  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  @override
  bool get hasError => _error != null;
  @override
  Uint8List? get imageBytes => _imageBytes;
  @override
  String get ocrText => _ocrText;
  @override
  bool get hasImage => _hasImage;
  @override
  bool get hasOcrResult => _hasOcrResult;
  @override
  bool get canImport => _canImport;
  @override
  bool get isProcessing => _isProcessing;
  @override
  bool get hasMultipleRecipes => _hasMultipleRecipes;
  @override
  List<Recipe> get parsedRecipes => _parsedRecipes;

  @override
  int get lastSaveFailureCount => 0;

  // All methods left without implementation to allow stubbing with when()
}

/// Mock implementation of SharedContentCoordinatorViewModel
class MockSharedContentCoordinatorViewModel extends Mock
    implements SharedContentCoordinatorViewModel {
  // Configuration state
  bool _isLoading = false;
  String? _error;
  List<dynamic>? _sharedContent;
  int _activeTab = 0;
  String _searchQuery = '';

  /// Configure mock state for tests
  void setSharedContentState({
    bool isLoading = false,
    String? error,
    List<dynamic>? sharedContent,
    int activeTab = 0,
    String searchQuery = '',
  }) {
    _isLoading = isLoading;
    _error = error;
    _sharedContent = sharedContent;
    _activeTab = activeTab;
    _searchQuery = searchQuery;
  }

  // Getters for configured state (tests can access)
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<dynamic>? get sharedContent => _sharedContent;
  int get activeTab => _activeTab;
  String get searchQuery => _searchQuery;

  // All methods left without implementation to allow stubbing with when()
}

// MockActivityService removed - dead code

/// Mock implementation of ParticipantTracker
class MockParticipantTracker extends Mock implements ParticipantTracker {
  // Configuration state
  int _activeCount = 0;
  List<ParticipantActivity> _allActivities = [];
  List<String> _onlineParticipants = [];

  /// Configure mock state for tests
  void setParticipantState({
    int activeCount = 0,
    List<ParticipantActivity>? allActivities,
    List<String>? onlineParticipants,
  }) {
    _activeCount = activeCount;
    if (allActivities != null) _allActivities = allActivities;
    if (onlineParticipants != null) _onlineParticipants = onlineParticipants;
  }

  // Getters for configured state (tests can access)
  @override
  int get activeCount => _activeCount;
  @override
  List<ParticipantActivity> get allActivities => _allActivities;
  @override
  List<String> get onlineParticipants => _onlineParticipants;
  @override
  List<String> get activeParticipantIds => _onlineParticipants;
  @override
  List<String> get recentlyActiveParticipants => _onlineParticipants;

  // State-backed no-ops. Same rationale as MockMenuCollaborationRepository —
  // the concrete returns supply non-null values for getters/return types
  // that Mocktail cannot default-fill; they don't block `when()` stubs in
  // practice because no test attempts that pattern.
  @override
  void updateDisplayName(String userId, String displayName) {}
  @override
  void removeParticipant(String userId) {}
  @override
  void updateFromMenu(RealtimeMenu menu) {}
  @override
  void dispose() {}
  @override
  void markActiveNow(String userId, String displayName) {}
  @override
  bool wasRecentlyActive(String userId, Duration within) => false;
  @override
  String getDisplayName(String userId) => 'Mock User';
  @override
  DateTime? getLastActivity(String userId) => null;
  @override
  void clear() {}
  @override
  void forceCleanup() {}
}

/// Mock implementation of SocialMenuOperations
class MockSocialMenuOperations extends Mock implements SocialMenuOperations {
  // All methods left without implementation to allow stubbing with when()
}

/// Fake implementation of XFile for testing
class FakeXFile extends Fake implements XFile {
  final String _name;
  final String _path;

  FakeXFile({
    required String name,
    required String path,
  }) : _name = name,
       _path = path;

  @override
  String get name => _name;

  @override
  String get path => _path;
}

/// Mock implementation of BuildContext for testing
class MockBuildContext extends Mock implements BuildContext {}

/// Simple error class for sync operations in tests
class SyncError {
  final String message;
  final dynamic originalError;

  const SyncError(this.message, [this.originalError]);

  @override
  String toString() => 'SyncError: $message';
}

// ===== CONSENT =====

class MockConsentService extends Mock implements ConsentService {}
