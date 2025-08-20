/// Production-aligned mocks that implement actual interfaces
///
/// These mocks properly implement production interfaces for type safety
/// and compile-time verification of interface changes.
library;

// ignore_for_file: unused_field

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart'; // For BuildContext
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'firestore_singleton.dart';

// Production imports
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/activity_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
import 'package:butlery/repositories/interfaces/reactions_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/analytics_service.dart';
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
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/archive_import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/import/import_manager.dart';
import '../di/test_service_locator.dart';

// Firebase imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Third-party library imports
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';

// ============= REPOSITORY MOCKS =============

/// Mock implementation of AuthRepository with configuration support
///
/// Uses super.noSuchMethod for all methods to allow proper Mocktail stubbing.
/// Configuration methods set internal state for getters only.
class MockAuthRepository extends Mock implements AuthRepository {
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

  // All other methods - no implementation to allow stubbing with when()
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

  // Methods left without concrete implementation to allow stubbing
  // Use when() to define behavior in tests
  // Note: clearError() and other methods are NOT overridden here
  // so they will be handled by Mock's noSuchMethod, allowing stubbing
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
  })  : _uid = uid ?? 'fake-uid',
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
    if (ratingOperationResults != null) _ratingOperationResults = ratingOperationResults;
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

/// Mock implementation of SocialRecipeRepository
class MockSocialRecipeRepository extends Mock
    implements SocialRecipeRepository {
  // Configuration state
  FakeFirebaseFirestore get _fakeFirestore => FirestoreSingleton.instance;
  User? _currentUser;
  List<SharedRecipe> _sharedRecipes = [];
  List<SharedMenu> _sharedMenus = [];

  /// Configure mock state
  void setSocialRecipeState({
    User? currentUser,
    List<SharedRecipe>? sharedRecipes,
    List<SharedMenu>? sharedMenus,
  }) {
    _currentUser = currentUser;
    if (sharedRecipes != null) _sharedRecipes = sharedRecipes;
    if (sharedMenus != null) _sharedMenus = sharedMenus;
  }

  // Implement the required getters
  @override
  CollectionReference<Map<String, dynamic>> get sharedRecipesRef =>
      _fakeFirestore.collection('shared_recipes');

  @override
  CollectionReference<Map<String, dynamic>> get sharedMenusRef =>
      _fakeFirestore.collection('shared_menus');

  @override
  CollectionReference<Map<String, dynamic>> get sharedContentRef =>
      _fakeFirestore.collection('shared_content');

  @override
  CollectionReference<Map<String, dynamic>> get recipeCommentsRef =>
      _fakeFirestore.collection('recipe_comments');

  @override
  User? get currentUser => _currentUser;

  // All other methods left without implementation to allow stubbing with when()
}

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

/// Mock implementation of ActivityRepository
class MockActivityRepository extends Mock implements ActivityRepository {
  // All methods left without implementation to allow stubbing with when()
}

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
          .where((c) =>
              !c.isGroup &&
              c.participantIds.contains(user1Id) &&
              c.participantIds.contains(user2Id))
          .map((c) => c.id)
          .firstOrNull;
    } catch (_) {
      return null;
    }
  }

  // All other methods left without implementation to allow stubbing with when()
}

/// Mock implementation of ReactionsRepository
class MockReactionsRepository extends Mock implements ReactionsRepository {
  // All methods left without implementation to allow stubbing with when()
}

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
class MockFirestoreRepository extends Mock implements FirestoreRepository {
  FakeFirebaseFirestore get _fakeFirestore => FirestoreSingleton.instance;

  @override
  FirebaseFirestore get firestore => _fakeFirestore;
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

  // Methods left without implementation to allow stubbing
}

// ============= SERVICE MOCKS =============

/// Mock UnifiedRecipeService with proper ChangeNotifier implementation
class MockUnifiedRecipeService extends Mock
    with ChangeNotifier
    implements UnifiedRecipeService {
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
      throw StateError('PersonalRecipeOperations not configured in mock. '
          'Use setRecipeState(personalOperations: mockPersonalOps)');
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
    notifyListeners();
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
  // Configuration state
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  void setFriendsState({
    List<UserProfile>? friends,
    List<FriendRequest>? incomingRequests,
    List<FriendRequest>? outgoingRequests,
    bool isInitialized = false,
    bool isLoading = false,
    String? error,
  }) {
    if (friends != null) _friends = friends;
    if (incomingRequests != null) _incomingRequests = incomingRequests;
    if (outgoingRequests != null) _outgoingRequests = outgoingRequests;
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
  bool get isInitialized => _isInitialized;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get error => _error;

  @override
  bool get hasError => _error != null;

  // Methods left without implementation to allow stubbing
}

/// Mock implementation of PermissionService
class MockPermissionService extends Mock implements PermissionService {
  // Configuration state
  Map<String, Map<ResourcePermission, bool>> _permissions = {};
  bool _defaultHasPermission = true;
  String? _currentUserId;
  String? _userDisplayName;
  UserProfile? _currentUser;
  bool _isAuthenticated = false;

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
    // If currentUser is set, derive authentication state and userId
    if (_currentUser != null) {
      _isAuthenticated = true;
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
  String? get currentUserDisplayName => _userDisplayName ?? 'Test User';

  @override
  bool canEditMenu(String menuId) {
    if (_currentUserId == null) return false;
    if (menuId.isEmpty) return false;
    // Check if user has permission to edit this menu
    return _permissions[menuId]?[ResourcePermission.editor] ?? _defaultHasPermission;
  }

  @override
  bool canEditRecipe(String recipeId) {
    if (_currentUserId == null) return false;
    if (recipeId.isEmpty) return false;
    // Check if user has permission to edit this recipe
    return _permissions[recipeId]?[ResourcePermission.editor] ?? _defaultHasPermission;
  }

  @override
  bool isRecipeOwner(String recipeId) {
    if (_currentUserId == null) return false;
    // For tests, assume current user owns recipes with IDs containing their userId
    return recipeId.contains(_currentUserId!);
  }

  bool isMenuOwner(String menuId) {
    if (_currentUserId == null) return false;
    // For tests, assume current user owns menus with IDs containing their userId
    return menuId.contains(_currentUserId!);
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

  // Methods left without implementation to allow stubbing
}

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

/// Mock implementation of AnalyticsService
class MockAnalyticsService extends Mock implements AnalyticsService {
  // Configuration state
  bool _isInitialized = false;
  String? _currentUserId;
  Map<String, dynamic> _userProperties = {};

  void setAnalyticsState({
    bool isInitialized = false,
    String? currentUserId,
    Map<String, dynamic>? userProperties,
  }) {
    _isInitialized = isInitialized;
    _currentUserId = currentUserId;
    if (userProperties != null) _userProperties = userProperties;
  }

  bool get isInitialized => _isInitialized;

  // Methods left without implementation to allow stubbing
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

/// Mock implementation of ArchiveImportStrategy
///
/// Provides configuration support for testing archive-based recipe imports
/// with mock recipe data and search capabilities.
class MockArchiveImportStrategy extends Mock implements ArchiveImportStrategy {
  // Configuration state
  List<Recipe> _availableRecipes = [];
  Set<String> _availableTags = {};
  Set<String> _availableMealTypes = {};
  String _strategyName = 'Archive Import';

  void setArchiveState({
    List<Recipe>? availableRecipes,
    Set<String>? availableTags,
    Set<String>? availableMealTypes,
    String? strategyName,
  }) {
    if (availableRecipes != null) _availableRecipes = availableRecipes;
    if (availableTags != null) _availableTags = availableTags;
    if (availableMealTypes != null) _availableMealTypes = availableMealTypes;
    if (strategyName != null) _strategyName = strategyName;
  }

  @override
  String get strategyName => _strategyName;

  @override
  String get description =>
      'Import recipes from the Butlery curated recipe archive';

  @override
  String get inputExample => 'recipe_id_123 or archive:recipe_name';

  @override
  List<Recipe> getAvailableRecipes() => List.unmodifiable(_availableRecipes);

  @override
  int getRecipeCount() => _availableRecipes.length;

  @override
  Set<String> getAvailableTags() => Set.unmodifiable(_availableTags);

  @override
  Set<String> getAvailableMealTypes() => Set.unmodifiable(_availableMealTypes);

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
3 dl vetemjöl
1 tsk salt

Gör så här:
1. Vispa ihop allt till en slät smet
2. Stek pannkakor i smörad panna
3. Servera med sylt och grädde
''';

  // Methods left without implementation to allow stubbing
}

/// Mock implementation of FileImportStrategy
///
/// Provides configuration support for testing file-based recipe imports
/// from CSV and Excel formats with Swedish content support.
class MockFileImportStrategy extends Mock implements FileImportStrategy {
  // Configuration state
  String _strategyName = 'File Import (CSV/Excel)';
  bool _canHandleFiles = true;

  void setFileImportState({
    String? strategyName,
    bool canHandleFiles = true,
  }) {
    if (strategyName != null) _strategyName = strategyName;
    _canHandleFiles = canHandleFiles;
  }

  @override
  String get strategyName => _strategyName;

  @override
  String get name =>
      _strategyName; // FileImportStrategy has both name and strategyName

  @override
  String get description => 'Import recipes from CSV or Excel files';

  @override
  String get inputExample =>
      'CSV or Excel file with columns: title, ingredients, instructions';

  // Methods left without implementation to allow stubbing
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

/// Mock implementation of JsonCacheHelper
///
/// Provides testing support for JSON cache operations including
/// user-specific caching, batch operations, and statistics.
class MockJsonCacheHelper extends Mock implements JsonCacheHelper {
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
      String key, List<Map<String, dynamic>> dataList) async {
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

/// Mock implementation of FirebaseStorage
class MockFirebaseStorage extends Mock implements FirebaseStorage {}

/// Mock implementation of Reference (Storage)
class MockReference extends Mock implements Reference {}

/// Mock implementation of TaskSnapshot (Storage)
class MockTaskSnapshot extends Mock implements TaskSnapshot {}

/// Mock implementation of WriteBatch
class MockWriteBatch extends Mock implements WriteBatch {}

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

/// Mock implementation of Box (Hive) with functional storage
///
/// Provides a working in-memory storage for testing Hive operations.
/// Supports all common Box operations needed for offline service testing.
class MockBox<T> extends Mock implements Box<T> {
  final Map<dynamic, T> _storage = {};
  bool _isOpen = true;

  // Override common Box methods with actual implementations
  @override
  T? get(dynamic key, {T? defaultValue}) {
    return _storage[key] ?? defaultValue;
  }

  @override
  Future<void> put(dynamic key, T value) async {
    if (!_isOpen) throw StateError('Box is closed');
    _storage[key] = value;
  }

  @override
  Future<void> putAll(Map<dynamic, T> entries) async {
    if (!_isOpen) throw StateError('Box is closed');
    _storage.addAll(entries);
  }

  @override
  Future<void> delete(dynamic key) async {
    if (!_isOpen) throw StateError('Box is closed');
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    if (!_isOpen) throw StateError('Box is closed');
    for (final key in keys) {
      _storage.remove(key);
    }
  }

  @override
  Future<int> clear() async {
    if (!_isOpen) throw StateError('Box is closed');
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  bool get isOpen => _isOpen;

  @override
  bool get isEmpty => _storage.isEmpty;

  @override
  bool get isNotEmpty => _storage.isNotEmpty;

  @override
  int get length => _storage.length;

  @override
  Iterable<dynamic> get keys => _storage.keys;

  @override
  Iterable<T> get values => _storage.values;

  @override
  Map<dynamic, T> toMap() => Map.from(_storage);

  @override
  bool containsKey(dynamic key) => _storage.containsKey(key);

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  // Test helper methods
  void setOpen(bool open) {
    _isOpen = open;
  }

  void setInitialData(Map<dynamic, T> data) {
    _storage.clear();
    _storage.addAll(data);
  }
}

/// Mock implementation of Uuid
class MockUuid extends Mock implements Uuid {}

/// Mock implementation of Share
class MockShare extends Mock implements Share {}

/// Mock implementation of RemoteMessage (FCM)
class MockRemoteMessage extends Mock implements RemoteMessage {}

/// Mock implementation of RemoteNotification (FCM)
class MockRemoteNotification extends Mock implements RemoteNotification {}

/// Mock implementation of FirebaseMessaging
class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

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

/// Mock implementation of RealtimeSyncService
///
/// Provides comprehensive real-time synchronization mocking for collaborative features.
/// Supports stream management, caching, and connection state simulation.
class MockRealtimeSyncService extends Mock
    with ChangeNotifier
    implements RealtimeSyncService {
  // Configuration state
  final Map<String, RealtimeResource> _cache = {};
  final Map<String, StreamController<RealtimeResource>> _streamControllers = {};
  bool _isConnected = false;
  bool _isInitialized = false;
  SyncError? _lastError;
  
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
  void setError(SyncError? error) {
    _lastError = error;
    notifyListeners();
  }
  
  /// Create or get stream controller for a resource
  StreamController<T> getOrCreateStreamController<T extends RealtimeResource>(String id) {
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
  SyncError? get lastError => _lastError;
  
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
}

// Note: MockPermissionService already exists earlier in this file at line 991
// This duplicate has been removed to avoid compilation errors

/// Mock implementation of BuildContext for testing
class MockBuildContext extends Mock implements BuildContext {}
