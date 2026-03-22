/// Comprehensive unified friends service providing coordinated social relationship management with advanced collaboration features.
/// This service implements sophisticated friend management functionality using facade pattern with specialized operations
/// for friend relationships, group management, invitations, and social sharing. It provides unified access to all
/// social features while maintaining clean architecture separation and comprehensive real-time synchronization for
/// enhanced social cooking experiences and community engagement.
/// **Phase 9 Refactored Architecture:**
/// This service represents a complete refactoring following Single Responsibility Principle with focused modules:
/// - Clean facade coordination with backward compatibility for existing ViewModels
/// - Modular architecture enabling independent testing and maintenance of social features
/// - Optimistic updates with Firebase synchronization and intelligent caching strategies
/// - Real-time synchronization ensuring immediate updates across all social interactions
/// **Architecture Integration:**
/// - Implements facade pattern coordinating specialized friend management modules
/// - Integrates with [FirestoreRepository] for persistent friend data storage and real-time updates
/// - Uses [AuthRepository] for user authentication and permission-aware social operations
/// - Delegates state management to [FriendsStateManager] with ChangeNotifier for reactive UI updates
/// - Coordinates with [PermissionService] for comprehensive social permission validation
/// **Specialized Operations Coordination:**
/// This facade coordinates between focused operations modules:
/// - **[FriendsManagementOperations]**: Core friend relationship CRUD operations and status management
/// - **[FriendsCategoriesOperations]**: Friend categorization and organization with custom groups
/// - **[FriendsInvitationsOperations]**: Friend request management and invitation workflow handling
/// **Social Features:**
/// - **Friend Relationships**: Comprehensive friend request, acceptance, and management system
/// - **Group Management**: Custom friend groups and categories for organized social cooking
/// - **Social Sharing**: Recipe and menu sharing with friends and groups
/// - **Real-time Sync**: Live updates for friend activities and social interactions
/// - **Offline Support**: Complete offline functionality with automatic synchronization
/// **Usage Examples:**
/// ```dart
/// final friendsService = UnifiedFriendsService(firestoreRepo, authRepo);
/// await friendsService.initialize();
/// // Send friend request
/// await friendsService.sendFriendRequest(userId, customMessage);
/// // Organize friends in categories
/// await friendsService.createFriendCategory('Matlagning', ['friend1', 'friend2']);
/// // Share recipe with friend group
/// await friendsService.shareRecipeWithGroup(recipeId, groupId);
/// // Real-time friend activity updates
/// friendsService.watchFriendActivity().listen(updateSocialUI);
/// ```

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';

// Feature interfaces
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/services/unified/friends/friends_internal_operations.dart';
import 'package:butlery/services/unified/friends/friends_firebase_sync.dart';
import 'package:butlery/services/unified/friends/friends_utility_operations.dart';

// Friends service classes consolidated during nuclear consolidation

/// Unified Friends Service - Main facade for friend management (Phase 9 Refactored)
/// This facade coordinates between focused single-responsibility modules:
/// - FriendsStateManager: Manages all state and notifications
/// - FriendsServiceCoordinator: Handles service initialization and callbacks
/// - FriendsInternalOperations: Provides internal methods for operations classes
/// - Feature operations: Handle specific business logic
/// Maintains 100% backward compatibility while providing clean modular architecture.
class UnifiedFriendsService extends ChangeNotifier
    with StreamManagementMixin, ErrorHandlingMixin {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  late final FirebaseFriendsRepository _friendsRepository;
  late final FriendRelationshipRepository _relationshipRepository;
  late final FriendCategoryRepository _categoryRepository;

  // Focused modules (Phase 9 refactoring)
  late final FriendsStateManager _stateManager;
  late final FriendsInternalOperations _internalOps;
  late final FriendsFirebaseSyncOperations _firebaseSyncOps;
  late final FriendsUtilityOperations _utilityOps;

  // Feature interfaces
  late final FriendsManagementOperations _managementOps;
  late final FriendsCategoriesOperations _categoriesOps;
  late final FriendsInvitationsOperations _invitationsOps;

  // Constructor
  UnifiedFriendsService({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository {
    // Create Firebase friends repository
    _friendsRepository = FirebaseFriendsRepository(
      authRepository: _authRepository,
    );

    // Create friend relationship repository (for counter updates)
    _relationshipRepository = FriendRelationshipRepository(
      authRepository: _authRepository,
    );

    // Create friend category repository (for group/category management)
    _categoryRepository = FriendCategoryRepository(
      authRepository: _authRepository,
    );

    // Initialize focused modules
    _initializeModules();

    // Initialize feature interfaces
    _initializeFeatureInterfaces();

    AppLogger.info(
        '✅ UnifiedFriendsService facade initialized with modular architecture');
  }
  List<UserProfile> get friends => _stateManager.friends;
  List<FriendRequest> get incomingRequests => _stateManager.incomingRequests;
  List<FriendRequest> get outgoingRequests => _stateManager.outgoingRequests;
  List<FriendCategory> get categoriesList => _stateManager.categories;
  List<GroupInvitation> get sentInvitations => _stateManager.sentInvitations;
  List<GroupInvitation> get receivedInvitations =>
      _stateManager.receivedInvitations;
  Set<String> get blockedUsers => _stateManager.blockedUsers;
  Map<String, Set<String>> get friendCategoryRelationships =>
      _stateManager.friendCategoryRelationships;

  bool get isInitialized => _stateManager.isInitialized;
  bool get isLoading => _stateManager.isLoading;
  String? get error => _stateManager.error;
  bool get hasError => _stateManager.hasError;

  String? get currentUserId =>
      ServiceLocator.get<PermissionService>().currentUserId;
  FirebaseFirestore get firestore => _firestoreRepository.firestore;
  FriendRelationshipRepository get relationshipRepository =>
      _relationshipRepository;
  FriendsManagementOperations get management => _managementOps;
  FriendsCategoriesOperations get categories => _categoriesOps;
  FriendsInvitationsOperations get invitations => _invitationsOps;
  Future<void> initialize() async {
    AppLogger.info('🔄 Initializing UnifiedFriendsService facade...');

    // Set up auth state change listener (CRITICAL FIX for authentication bug)
    listenToStream(
      _authRepository.authStateChanges(),
      (user) async {
        if (user != null) {
          // User logged in - reload friends data
          AppLogger.info(
              '🔄 User logged in - reloading friends data for: ${user.uid}');
          await _stateManager.initialize();

          // Run migration to ensure owners are members of their groups
          await categories.migrateOwnersAsMembers();

          // Backfill displayNameLower for legacy friend docs (fire-and-forget)
          _firebaseSyncOps.backfillDisplayNameLower(user.uid).catchError((e) {
            AppLogger.warning('displayNameLower backfill failed: $e');
          });
        } else {
          // User logged out - clear all cached data
          AppLogger.info('🚪 User logged out - clearing friends data');
          // ULTRATHINK FIX: Ensure clearAllData completes before any subsequent operations
          await Future.microtask(() => _stateManager.clearAllData());
          AppLogger.debug('✅ Friends data clearing completed');
        }
      },
      name: 'friends_auth_state_changes',
    );

    // Initialize for current user if already authenticated
    if (_authRepository.currentUser != null) {
      await _stateManager.initialize();

      // Run migration to ensure owners are members of their groups
      await categories.migrateOwnersAsMembers();

      // Backfill displayNameLower for legacy friend docs (fire-and-forget)
      final userId = currentUserId;
      if (userId != null) {
        _firebaseSyncOps.backfillDisplayNameLower(userId).catchError((e) {
          AppLogger.warning('displayNameLower backfill failed: $e');
        });
      }
    }

    AppLogger.success(
        '✅ UnifiedFriendsService facade initialized with auth state handling');
  }

  void _initializeModules() {
    // Initialize state manager with Firebase repository and category repository
    _stateManager = FriendsStateManager(
      repository: _friendsRepository,
      categoryRepository: _categoryRepository,
      blockRepository: ServiceLocator.get<FirebaseBlockRepository>(),
    );

    // Initialize internal operations
    _internalOps = FriendsInternalOperations(
      categoryRepository: _categoryRepository,
      authRepository: _authRepository,
    );

    // Initialize Firebase sync operations
    _firebaseSyncOps = FriendsFirebaseSyncOperations(
      firestore: firestore,
      getCurrentUserId: () => currentUserId,
    );

    // Initialize utility operations
    _utilityOps = FriendsUtilityOperations(
      firestore: firestore,
      getCurrentUserId: () => currentUserId,
      getBlockedUsers: () => blockedUsers,
      getIncomingRequests: () => incomingRequests,
      getOutgoingRequests: () => outgoingRequests,
    );

    // Connect internal operations to state manager
    _internalOps.setStateManager(_stateManager);

    // Forward state manager notifications to facade
    _stateManager.addListener(() {
      notifyListeners();
    });

    AppLogger.debug(
        'Focused modules initialized with Firebase repository and category repository');
  }

  void _initializeFeatureInterfaces() {
    _managementOps = FriendsManagementOperations(this);
    _categoriesOps = FriendsCategoriesOperations(this);
    _invitationsOps = FriendsInvitationsOperations(this);
    AppLogger.debug('Feature interfaces initialized');
  }

  // Note: State management is now handled by FriendsStateManager
  // All state operations are automatically coordinated through the service coordinator
  /// Internal getter for friends list (for operations classes)
  List<UserProfile> get friendsInternal => _internalOps.friendsInternal;

  /// Internal getter for categories list (for operations classes)
  List<FriendCategory> getAllCategoriesInternal() =>
      _internalOps.getAllCategoriesInternal();

  /// Internal getter for sent invitations (for operations classes)
  List<GroupInvitation> getAllSentInvitationsInternal() =>
      _internalOps.getAllSentInvitationsInternal();

  /// Internal getter for friend-category relationships (for operations classes)
  Map<String, Set<String>> get friendCategoryRelationshipsInternal =>
      _stateManager.relationshipsInternal;

  /// Internal method to notify listeners (for operations classes)
  void notifyListenersInternal() => _internalOps.notifyListenersInternal();

  /// Internal method to get category by ID (for operations classes)
  FriendCategory? getCategoryByIdInternal(String categoryId) =>
      _internalOps.getCategoryByIdInternal(categoryId);

  /// Internal method to add category (for operations classes)
  void addCategoryInternal(FriendCategory category) =>
      _internalOps.addCategoryInternal(category);

  /// Internal method to update category (for operations classes)
  void updateCategoryInternal(String categoryId, FriendCategory category) =>
      _internalOps.updateCategoryInternal(categoryId, category);

  /// Internal method to remove category (for operations classes)
  void removeCategoryInternal(String categoryId) =>
      _internalOps.removeCategoryInternal(categoryId);

  /// Internal method to sync category to Firebase (for operations classes)
  Future<void> syncCategoryToFirebaseInternal(FriendCategory category) async =>
      await _internalOps.syncCategoryToFirebaseInternal(category);

  /// Internal method to delete category from Firebase (for operations classes)
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async =>
      await _internalOps.deleteCategoryFromFirebaseInternal(categoryId);

  /// Internal method to add friend to category (for operations classes)
  void addFriendToCategoryInternal(String friendId, String categoryId) =>
      _internalOps.addFriendToCategoryInternal(friendId, categoryId);

  /// Internal method to remove friend from category (for operations classes)
  void removeFriendFromCategoryInternal(String friendId, String categoryId) =>
      _internalOps.removeFriendFromCategoryInternal(friendId, categoryId);

  /// Internal method to get friends in category (for operations classes)
  Set<String> getFriendsInCategoryInternal(String categoryId) =>
      _internalOps.getFriendsInCategoryInternal(categoryId);

  /// Internal method to get categories for friend (for operations classes)
  Set<String> getCategoriesForFriendInternal(String friendId) =>
      _internalOps.getCategoriesForFriendInternal(friendId);

  /// Internal method to add sent invitation (for operations classes)
  void addSentInvitationInternal(GroupInvitation invitation) =>
      _internalOps.addSentInvitationInternal(invitation);

  /// Internal method to get sent invitation by ID (for operations classes)
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) =>
      _internalOps.getSentInvitationByIdInternal(invitationId);

  /// Internal method to update sent invitation (for operations classes)
  void updateSentInvitationInternal(
          String invitationId, GroupInvitation invitation) =>
      _internalOps.updateSentInvitationInternal(invitationId, invitation);

  /// Internal method to send email invitation (for operations classes)
  Future<bool> sendEmailInvitationInternal(
          {required String email, required GroupInvitation invitation}) async =>
      await _internalOps.sendEmailInvitationInternal(
          email: email, invitation: invitation);

  /// Internal method to send SMS invitation (for operations classes)
  Future<bool> sendSMSInvitationInternal(
          {required String phoneNumber,
          required GroupInvitation invitation}) async =>
      await _internalOps.sendSMSInvitationInternal(
          phoneNumber: phoneNumber, invitation: invitation);

  /// Internal method to create invitation link (for operations classes)
  Future<String> createInvitationLinkInternal(String invitationId) =>
      _internalOps.createInvitationLinkInternal(invitationId);

  /// Internal method to update invitation status (for operations classes)
  Future<void> updateInvitationStatusInternal(
          String invitationId, GroupInvitationStatus status) async =>
      await _internalOps.updateInvitationStatusInternal(invitationId, status);

  /// Internal method to get received group invitations (for operations classes)
  List<GroupInvitation> getReceivedGroupInvitationsInternal(String userId) =>
      _internalOps.getReceivedGroupInvitationsInternal(userId);

  /// Internal getter for friends repository (for operations classes to save invitations)
  FirebaseFriendsRepository get friendsRepositoryInternal => _friendsRepository;

  /// Internal getter for category repository (for operations classes to fetch groups)
  FriendCategoryRepository get friendsCategoryRepositoryInternal =>
      _categoryRepository;

  /// Internal getter for current user display name (for operations classes)
  String? get currentUserDisplayName =>
      _internalOps.getCurrentUserDisplayNameInternal();

  /// Internal method to refresh data (for operations classes)
  Future<void> refresh() async => await _stateManager.refresh();

  /// Internal method to add outgoing friend request
  void addOutgoingRequestInternal(FriendRequest request) {
    _stateManager.addOutgoingRequest(request);
    AppLogger.debug(
        '✅ Added outgoing request to ${request.toUserId} via state manager');
  }

  /// Internal method to remove outgoing friend request
  void removeOutgoingRequestInternal(String requestId) {
    _stateManager.removeOutgoingRequest(requestId);
    AppLogger.debug('✅ Removed outgoing request $requestId via state manager');
  }

  /// Internal method to add incoming friend request
  void addIncomingRequestInternal(FriendRequest request) {
    _stateManager.addIncomingRequest(request);
    AppLogger.debug(
        '✅ Added incoming request from ${request.fromUserId} via state manager');
  }

  /// Internal method to remove incoming friend request
  void removeIncomingRequestInternal(String requestId) {
    _stateManager.removeIncomingRequest(requestId);
    AppLogger.debug('✅ Removed incoming request $requestId via state manager');
  }

  /// Internal method to add friend
  void addFriendInternal(UserProfile friend) {
    _stateManager.addFriend(friend);
    AppLogger.debug(
        '✅ Added friend ${friend.displayName.maskedName} via state manager');
  }

  /// Internal method to remove friend
  void removeFriendInternal(String friendId) {
    _stateManager.removeFriend(friendId);
    AppLogger.debug(
        '✅ Removed friend ${friendId.maskedUserId} via state manager');
  }

  /// Sync friend request to Firebase
  Future<void> syncFriendRequestToFirebase(FriendRequest request) async =>
      await _firebaseSyncOps.syncFriendRequestToFirebase(request);

  /// Update friend request status in Firebase
  Future<void> updateFriendRequestStatus(FriendRequest request) async =>
      await _firebaseSyncOps.updateFriendRequestStatus(request);

  /// Sync friend to Firebase
  /// ⚠️ ULTRATHINK WARNING: This method should NOT be used for friend request acceptance!
  /// Use FriendRelationshipRepository.addMutualFriends() instead, which properly handles:
  /// - Atomic operations, counter updates, and consistent field structures
  /// This method uses different field names and doesn't update friendsCount
  Future<void> syncFriendToFirebase(UserProfile friend) async =>
      await _firebaseSyncOps.syncFriendToFirebase(friend);

  /// Remove friend from Firebase
  Future<void> removeFriendFromFirebase(String friendId) async =>
      await _firebaseSyncOps.removeFriendFromFirebase(friendId);

  /// Get all friend requests (incoming and outgoing combined)
  List<FriendRequest> get friendRequests => _utilityOps.friendRequests;

  /// Search for users by query
  Future<List<UserProfile>> searchUsers(String query) async =>
      await management.searchUsers(query);

  /// Get friends of a specific user
  Future<List<UserProfile>> getFriendsOfUser(String userId) async =>
      await _utilityOps.getFriendsOfUser(userId);

  /// Get recent collaborators
  Future<List<UserProfile>> getRecentCollaborators() async =>
      await _utilityOps.getRecentCollaborators();

  /// Get recent shopping collaborators
  Future<List<UserProfile>> getRecentShoppingCollaborators() async =>
      await _utilityOps.getRecentShoppingCollaborators();

  /// Clear error state (for ViewModels)
  void clearError() => _stateManager.clearError();

  /// Get friends list (for ViewModels)
  List<UserProfile> get friendsList => friends;

  /// Get category by ID (for ViewModels)
  FriendCategory? getCategoryById(String categoryId) =>
      _stateManager.getCategoryById(categoryId);

  /// Cancel sent invitation (for ViewModels)
  Future<bool> cancelSentInvitation(String invitationId) async =>
      await invitations.cancelInvitation(invitationId);

  /// Clear user-specific state only — does NOT dispose stream resources
  /// (the auth listener must survive to handle the next login).
  void resetForLogout() {
    _stateManager.clearAllData();
  }

  @override
  void dispose() {
    _stateManager.clearAllData();
    disposeStreamResources();
    super.dispose();
  }
}
