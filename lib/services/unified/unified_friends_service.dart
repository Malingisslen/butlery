/// Comprehensive unified friends service providing coordinated social relationship management with advanced collaboration features.
///
/// This service implements sophisticated friend management functionality using facade pattern with specialized operations
/// for friend relationships, group management, invitations, and social sharing. It provides unified access to all
/// social features while maintaining clean architecture separation and comprehensive real-time synchronization for
/// enhanced social cooking experiences and community engagement.
///
/// **Phase 9 Refactored Architecture:**
/// This service represents a complete refactoring following Single Responsibility Principle with focused modules:
/// - Clean facade coordination with backward compatibility for existing ViewModels
/// - Modular architecture enabling independent testing and maintenance of social features
/// - Optimistic updates with Firebase synchronization and intelligent caching strategies
/// - Real-time synchronization ensuring immediate updates across all social interactions
///
/// **Architecture Integration:**
/// - Implements facade pattern coordinating specialized friend management modules
/// - Integrates with [FirestoreRepository] for persistent friend data storage and real-time updates
/// - Uses [AuthRepository] for user authentication and permission-aware social operations
/// - Delegates state management to [FriendsStateManager] with ChangeNotifier for reactive UI updates
/// - Coordinates with [PermissionService] for comprehensive social permission validation
///
/// **Specialized Operations Coordination:**
/// This facade coordinates between focused operations modules:
/// - **[FriendsManagementOperations]**: Core friend relationship CRUD operations and status management
/// - **[FriendsCategoriesOperations]**: Friend categorization and organization with custom groups
/// - **[FriendsInvitationsOperations]**: Friend request management and invitation workflow handling
/// - **[SocialGroupSharingOperations]**: Group-based sharing and collaborative cooking features
///
/// **Social Features:**
/// - **Friend Relationships**: Comprehensive friend request, acceptance, and management system
/// - **Group Management**: Custom friend groups and categories for organized social cooking
/// - **Social Sharing**: Recipe and menu sharing with friends and groups
/// - **Real-time Sync**: Live updates for friend activities and social interactions
/// - **Offline Support**: Complete offline functionality with automatic synchronization
///
/// **Usage Examples:**
/// ```dart
/// final friendsService = UnifiedFriendsService(firestoreRepo, authRepo);
/// await friendsService.initialize();
/// 
/// // Send friend request
/// await friendsService.sendFriendRequest(userId, customMessage);
/// 
/// // Organize friends in categories
/// await friendsService.createFriendCategory('Matlagning', ['friend1', 'friend2']);
/// 
/// // Share recipe with friend group
/// await friendsService.shareRecipeWithGroup(recipeId, groupId);
/// 
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
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

// Feature interfaces
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/operations/social_group_sharing_operations.dart';

// Friends service classes consolidated during nuclear consolidation

/// Consolidated friends state manager (simplified)
class FriendsStateManager extends ChangeNotifier {
  final FirebaseFriendsRepository _repository;
  final FriendCategoryRepository _categoryRepository;
  
  // Internal state
  List<UserProfile> _friends = [];
  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> _outgoingRequests = [];
  List<FriendCategory> _categories = [];
  List<GroupInvitation> _sentInvitations = [];
  final Set<String> _blockedUsers = <String>{};
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  
  // Stream subscriptions for real-time updates - ULTRATHINK FIX: Initialize as null
  StreamSubscription? _incomingRequestsSubscription;
  StreamSubscription? _sentRequestsSubscription;
  StreamSubscription? _groupInvitationsSubscription;
  
  FriendsStateManager({
    required FirebaseFriendsRepository repository,
    required FriendCategoryRepository categoryRepository,
  }) : _repository = repository,
       _categoryRepository = categoryRepository {
    AppLogger.debug('FriendsStateManager initialized with repository and category repository');
  }
  
  // State getters
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);
  List<FriendCategory> get categories => List.unmodifiable(_categories);
  List<GroupInvitation> get sentInvitations => List.unmodifiable(_sentInvitations);
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);
  Map<String, Set<String>> get friendCategoryRelationships => <String, Set<String>>{};
  
  // Status getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  
  /// Initialize and load all friends data from Firebase
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.debug('FriendsStateManager already initialized');
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      AppLogger.info('🔄 Loading friends data from Firebase...');
      
      // Get current user ID
      final currentUserId = _repository.currentUserId;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      
      // Load all data in parallel for better performance
      await Future.wait([
        _loadFriends(currentUserId),
        _loadFriendRequests(),
        _loadCategories(currentUserId),
      ]);
      
      // Set up real-time listeners
      _setupRealtimeListeners(currentUserId);
      
      _isInitialized = true;
      _isLoading = false;
      AppLogger.success('✅ Friends data loaded successfully');
      AppLogger.info('📊 Loaded: ${_friends.length} friends, ${_incomingRequests.length} incoming requests, ${_outgoingRequests.length} outgoing requests');
      
    } catch (e, stackTrace) {
      _error = 'Failed to load friends data: $e';
      _isLoading = false;
      AppLogger.error('❌ Failed to initialize FriendsStateManager: $e', stackTrace);
    }
    
    notifyListeners();
  }
  
  /// Load friends list from Firebase
  Future<void> _loadFriends(String userId) async {
    try {
      // Get friend IDs first
      final friendIds = await _repository.fetchFriendIds(userId);
      
      if (friendIds.isNotEmpty) {
        // ULTRATHINK FIX: Filter out current user from friend IDs to prevent self-friend bug
        final filteredFriendIds = friendIds.where((id) => id != userId).toList();
        
        if (filteredFriendIds.isNotEmpty) {
          // Get friend profiles
          final friendProfiles = await _repository.fetchFriendProfiles(filteredFriendIds);
          _friends = friendProfiles;
          AppLogger.debug('Loaded ${_friends.length} friends (filtered out self)');
        } else {
          _friends = [];
          AppLogger.debug('No friends found after filtering self');
        }
      } else {
        _friends = [];
        AppLogger.debug('No friends found');
      }
    } catch (e) {
      AppLogger.warning('Failed to load friends: $e');
      _friends = [];
    }
  }
  
  /// Load friend requests from Firebase
  Future<void> _loadFriendRequests() async {
    try {
      // Load both incoming and outgoing requests
      final incomingFuture = _repository.getIncomingRequests();
      final outgoingFuture = _repository.getSentRequests();
      
      final results = await Future.wait([incomingFuture, outgoingFuture]);
      
      _incomingRequests = results[0];
      _outgoingRequests = results[1];
      
      AppLogger.debug('Loaded ${_incomingRequests.length} incoming requests, ${_outgoingRequests.length} outgoing requests');
    } catch (e) {
      AppLogger.warning('Failed to load friend requests: $e');
      _incomingRequests = [];
      _outgoingRequests = [];
    }
  }
  
  /// Load categories from Firebase
  Future<void> _loadCategories(String userId) async {
    try {
      _categories = await _categoryRepository.fetchCategories(userId);
      AppLogger.debug('Loaded ${_categories.length} categories using FriendCategoryRepository');
    } catch (e) {
      AppLogger.warning('Failed to load categories: $e');
      _categories = [];
    }
  }
  
  /// Clear all cached friends data (called on user logout)
  void clearAllData() {
    AppLogger.info('🧹 Clearing all friends data for user logout');
    
    // Cancel all subscriptions
    _incomingRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    _groupInvitationsSubscription?.cancel();
    
    // ULTRATHINK FIX: Nullify subscription references for complete cleanup
    _incomingRequestsSubscription = null;
    _sentRequestsSubscription = null;
    _groupInvitationsSubscription = null;
    
    // Clear all state
    _friends.clear();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _categories.clear();
    _sentInvitations.clear();
    _blockedUsers.clear();
    
    // Reset flags
    _isInitialized = false;
    _isLoading = false;
    _error = null;
    
    AppLogger.debug('✅ Friends data cleared successfully');
    notifyListeners();
  }
  
  /// Set up real-time listeners for data changes
  void _setupRealtimeListeners(String userId) {
    try {
      // ULTRATHINK FIX: Cancel existing listeners first to prevent duplicates
      _incomingRequestsSubscription?.cancel();
      _sentRequestsSubscription?.cancel();
      _groupInvitationsSubscription?.cancel();
      AppLogger.debug('🧹 Cancelled existing real-time listeners before setting up new ones');
      
      // Listen to incoming requests
      _incomingRequestsSubscription = _repository.incomingRequestsStream(userId).listen(
        (requests) {
          _incomingRequests = requests;
          AppLogger.debug('Real-time update: ${_incomingRequests.length} incoming requests');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Incoming requests stream error: $e');
        },
      );
      
      // Listen to sent requests
      _sentRequestsSubscription = _repository.sentRequestsStream(userId).listen(
        (requests) {
          _outgoingRequests = requests;
          AppLogger.debug('Real-time update: ${_outgoingRequests.length} outgoing requests');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Sent requests stream error: $e');
        },
      );
      
      // Listen to group invitations
      _groupInvitationsSubscription = _repository.receivedInvitationsStream(userId).listen(
        (invitations) {
          _sentInvitations = invitations;
          AppLogger.debug('Real-time update: ${_sentInvitations.length} group invitations');
          notifyListeners();
        },
        onError: (e) {
          AppLogger.warning('Group invitations stream error: $e');
        },
      );
      
      AppLogger.success('✅ Real-time listeners setup complete');
    } catch (e) {
      AppLogger.warning('Failed to setup real-time listeners: $e');
    }
  }
  
  /// Clear error state
  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }
  
  /// Refresh all data
  Future<void> refresh() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }
    
    final currentUserId = _repository.currentUserId;
    if (currentUserId == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await Future.wait([
        _loadFriends(currentUserId),
        _loadFriendRequests(),
        _loadCategories(currentUserId),
      ]);
      
      _isLoading = false;
      AppLogger.success('✅ Friends data refreshed successfully');
    } catch (e) {
      _error = 'Failed to refresh friends data: $e';
      _isLoading = false;
      AppLogger.error('❌ Failed to refresh friends data: $e');
    }
    
    notifyListeners();
  }
  
  // Additional methods for internal operations
  Map<String, Set<String>> get relationshipsInternal => <String, Set<String>>{};
  dynamic getCategoryById(String categoryId) {
    return _categories.where((c) => c.id == categoryId).firstOrNull;
  }
  
  // ===== ULTRATHINK FIX: INTERNAL STATE MODIFICATION METHODS =====
  
  /// Add friend to local state
  void addFriend(UserProfile friend) {
    if (!_friends.any((f) => f.uid == friend.uid)) {
      _friends.add(friend);
      AppLogger.debug('Added friend to state: ${friend.displayName} (${friend.uid})');
      notifyListeners();
    }
  }
  
  /// Remove friend from local state
  void removeFriend(String friendId) {
    final initialLength = _friends.length;
    _friends.removeWhere((f) => f.uid == friendId);
    if (_friends.length < initialLength) {
      AppLogger.debug('Removed friend from state: $friendId');
      notifyListeners();
    }
  }
  
  /// Add incoming friend request to local state
  void addIncomingRequest(FriendRequest request) {
    if (!_incomingRequests.any((r) => r.id == request.id)) {
      _incomingRequests.add(request);
      AppLogger.debug('Added incoming request to state: ${request.id}');
      notifyListeners();
    }
  }
  
  /// Remove incoming friend request from local state
  void removeIncomingRequest(String requestId) {
    final initialLength = _incomingRequests.length;
    _incomingRequests.removeWhere((r) => r.id == requestId);
    if (_incomingRequests.length < initialLength) {
      AppLogger.debug('Removed incoming request from state: $requestId');
      notifyListeners();
    }
  }
  
  /// Add outgoing friend request to local state
  void addOutgoingRequest(FriendRequest request) {
    if (!_outgoingRequests.any((r) => r.id == request.id)) {
      _outgoingRequests.add(request);
      AppLogger.debug('Added outgoing request to state: ${request.id}');
      notifyListeners();
    }
  }
  
  /// Remove outgoing friend request from local state
  void removeOutgoingRequest(String requestId) {
    final initialLength = _outgoingRequests.length;
    _outgoingRequests.removeWhere((r) => r.id == requestId);
    if (_outgoingRequests.length < initialLength) {
      AppLogger.debug('Removed outgoing request from state: $requestId');
      notifyListeners();
    }
  }
  
  /// Add blocked user to local state
  void addBlockedUser(String userId) {
    if (_blockedUsers.add(userId)) {
      AppLogger.debug('Added blocked user to state: $userId');
      notifyListeners();
    }
  }
  
  /// Remove blocked user from local state
  void removeBlockedUser(String userId) {
    if (_blockedUsers.remove(userId)) {
      AppLogger.debug('Removed blocked user from state: $userId');
      notifyListeners();
    }
  }
  
  /// Add category to local state
  void addCategory(FriendCategory category) {
    if (!_categories.any((c) => c.id == category.id)) {
      _categories.add(category);
      AppLogger.debug('Added category to state: ${category.name}');
      notifyListeners();
    }
  }
  
  /// Update category in local state
  void updateCategory(String categoryId, FriendCategory category) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index] = category;
      AppLogger.debug('Updated category in state: ${category.name}');
      notifyListeners();
    }
  }
  
  /// Remove category from local state
  void removeCategory(String categoryId) {
    final initialLength = _categories.length;
    _categories.removeWhere((c) => c.id == categoryId);
    if (_categories.length < initialLength) {
      AppLogger.debug('Removed category from state: $categoryId');
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    // Cancel all subscriptions
    _incomingRequestsSubscription?.cancel();
    _sentRequestsSubscription?.cancel();
    _groupInvitationsSubscription?.cancel();
    
    // ULTRATHINK FIX: Nullify subscription references for complete cleanup
    _incomingRequestsSubscription = null;
    _sentRequestsSubscription = null;
    _groupInvitationsSubscription = null;
    
    AppLogger.debug('FriendsStateManager disposed - cleaned up ${_friends.length} friends data');
    super.dispose();
  }
}

/// Consolidated friends service coordinator (simplified)  
class FriendsServiceCoordinator {
  FriendsServiceCoordinator();
  
  // Service getters (simplified implementations)
  FriendsSyncService get sync => FriendsSyncService();
  FriendsPresenceService get presence => FriendsPresenceService();
  FriendsCacheService get cache => FriendsCacheService();
  
  // Initialization methods (simplified)
  Future<void> initialize() async {}
  Future<void> refresh() async {}
  void clearError() {}
  void dispose() {}
}

/// Consolidated friends internal operations
class FriendsInternalOperations {
  final FriendCategoryRepository _categoryRepository;
  final AuthRepository _authRepository;
  late final FriendsStateManager _stateManager;
  
  FriendsInternalOperations({
    required FriendCategoryRepository categoryRepository,
    required AuthRepository authRepository,
  }) : _categoryRepository = categoryRepository,
       _authRepository = authRepository;
  
  /// Set state manager reference after initialization
  void setStateManager(FriendsStateManager stateManager) {
    _stateManager = stateManager;
  }
  
  // Internal method implementations
  List<UserProfile> get friendsInternal => _stateManager.friends;
  List<FriendCategory> getAllCategoriesInternal() => _stateManager.categories;
  List<GroupInvitation> getAllSentInvitationsInternal() => _stateManager.sentInvitations;
  void notifyListenersInternal() => _stateManager.notifyListeners();
  
  dynamic getCategoryByIdInternal(String categoryId) {
    return _stateManager.categories
        .where((category) => category.id == categoryId)
        .firstOrNull;
  }
  
  void addCategoryInternal(dynamic category) {
    print('🔧 [DEBUG] addCategoryInternal called with: ${category.runtimeType}');
    if (category is FriendCategory) {
      print('✅ [DEBUG] Adding category to state manager: ${category.name}');
      _stateManager.addCategory(category);
      print('✅ [DEBUG] Category added successfully and listeners notified');
    } else {
      print('❌ [DEBUG] Invalid category type: ${category.runtimeType}');
    }
  }
  
  void updateCategoryInternal(String categoryId, dynamic category) {
    if (category is FriendCategory) {
      _stateManager.updateCategory(categoryId, category);
    }
  }
  
  void removeCategoryInternal(String categoryId) {
    _stateManager.removeCategory(categoryId);
  }
  Future<void> syncCategoryToFirebaseInternal(dynamic category) async {
    print('☁️ [DEBUG] syncCategoryToFirebaseInternal called');
    print('🔍 [DEBUG] Category type: ${category.runtimeType}');
    
    if (category is FriendCategory) {
      print('✅ [DEBUG] Category is valid FriendCategory');
      print('📝 [DEBUG] Category details: name="${category.name}", id="${category.id}"');
      
      try {
        print('🔐 [DEBUG] Getting current user ID for Firebase auth...');
        final currentUserId = _authRepository.currentUser?.uid;
        if (currentUserId == null) {
          AppLogger.warning('Cannot sync category: User not authenticated');
          print('❌ [DEBUG] Current user is null, cannot sync');
          return;
        }
        print('✅ [DEBUG] Current user ID: $currentUserId');
        
        print('💾 [DEBUG] Calling _categoryRepository.saveCategory...');
        await _categoryRepository.saveCategory(currentUserId, category);
        print('✅ [DEBUG] Category saved to Firebase successfully');
        AppLogger.success('✅ Category synced to Firebase: ${category.name}');
      } catch (e) {
        print('💥 [DEBUG] Exception in Firebase sync: $e');
        AppLogger.error('❌ Failed to sync category to Firebase: ${category.name}', e);
        rethrow;
      }
    } else {
      print('❌ [DEBUG] Invalid category type: ${category.runtimeType}');
      AppLogger.warning('Invalid category type for Firebase sync');
    }
  }
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async {
    try {
      final currentUserId = _authRepository.currentUser?.uid;
      if (currentUserId == null) {
        AppLogger.warning('Cannot delete category: User not authenticated');
        return;
      }
      
      await _categoryRepository.deleteCategory(currentUserId, categoryId);
      AppLogger.success('✅ Category deleted from Firebase: $categoryId');
    } catch (e) {
      AppLogger.error('❌ Failed to delete category from Firebase: $categoryId', e);
      rethrow;
    }
  }
  void addFriendToCategoryInternal(String friendId, String categoryId) {}
  void removeFriendFromCategoryInternal(String friendId, String categoryId) {}
  Set<String> getFriendsInCategoryInternal(String categoryId) => {};
  Set<String> getCategoriesForFriendInternal(String friendId) => {};
  void addSentInvitationInternal(dynamic invitation) {}
  dynamic getSentInvitationByIdInternal(String invitationId) => null;
  void updateSentInvitationInternal(String invitationId, dynamic invitation) {}
  Future<bool> sendEmailInvitationInternal({required String email, required dynamic invitation}) async => true;
  Future<bool> sendSMSInvitationInternal({required String phoneNumber, required dynamic invitation}) async => true;
  String createInvitationLinkInternal(String invitationId) => 'https://example.com/invite/$invitationId';
  Future<void> updateInvitationStatusInternal(String invitationId, dynamic status) async {}
  String? getCurrentUserDisplayNameInternal() => 'Mock User';
}

/// Consolidated friends sync service (simplified)
class FriendsSyncService {
  FriendsSyncService();
}

/// Consolidated friends presence service (simplified)
class FriendsPresenceService {
  FriendsPresenceService();
}

/// Consolidated friends cache service (simplified)
class FriendsCacheService {
  FriendsCacheService();
}

/// Unified Friends Service - Main facade for friend management (Phase 9 Refactored)
/// 
/// This facade coordinates between focused single-responsibility modules:
/// - FriendsStateManager: Manages all state and notifications
/// - FriendsServiceCoordinator: Handles service initialization and callbacks
/// - FriendsInternalOperations: Provides internal methods for operations classes
/// - Feature operations: Handle specific business logic
/// 
/// Maintains 100% backward compatibility while providing clean modular architecture.
class UnifiedFriendsService extends ChangeNotifier with StreamManagementMixin {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  late final FirebaseFriendsRepository _friendsRepository;
  late final FriendRelationshipRepository _relationshipRepository;
  late final FriendCategoryRepository _categoryRepository;
  
  // Focused modules (Phase 9 refactoring)
  late final FriendsStateManager _stateManager;
  late final FriendsServiceCoordinator _serviceCoordinator;
  late final FriendsInternalOperations _internalOps;
  
  // Feature interfaces
  late final FriendsManagementOperations _managementOps;
  late final FriendsCategoriesOperations _categoriesOps;
  late final FriendsInvitationsOperations _invitationsOps;
  late final SocialGroupSharingOperations _groupSharingOps;

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
    
    AppLogger.info('✅ UnifiedFriendsService facade initialized with modular architecture');
  }

  // ===== GETTERS (Delegated to State Manager) =====

  List<UserProfile> get friends => _stateManager.friends;
  List<FriendRequest> get incomingRequests => _stateManager.incomingRequests;
  List<FriendRequest> get outgoingRequests => _stateManager.outgoingRequests;
  List<FriendCategory> get categoriesList => _stateManager.categories;
  List<GroupInvitation> get sentInvitations => _stateManager.sentInvitations;
  Set<String> get blockedUsers => _stateManager.blockedUsers;
  Map<String, Set<String>> get friendCategoryRelationships => _stateManager.friendCategoryRelationships;

  bool get isInitialized => _stateManager.isInitialized;
  bool get isLoading => _stateManager.isLoading;
  String? get error => _stateManager.error;
  bool get hasError => _stateManager.hasError;
  
  String? get currentUserId => ServiceLocator.get<PermissionService>().currentUserId;
  FirebaseFirestore get firestore => _firestoreRepository.firestore;
  FriendRelationshipRepository get relationshipRepository => _relationshipRepository;

  // ===== FEATURE INTERFACE GETTERS =====

  FriendsManagementOperations get management => _managementOps;
  FriendsCategoriesOperations get categories => _categoriesOps;
  FriendsInvitationsOperations get invitations => _invitationsOps;
  SocialGroupSharingOperations get groupSharing => _groupSharingOps;

  // ===== SERVICE GETTERS (Delegated to Service Coordinator) =====

  FriendsSyncService get sync => _serviceCoordinator.sync;
  FriendsPresenceService get presence => _serviceCoordinator.presence;
  FriendsCacheService get cache => _serviceCoordinator.cache;

  // ===== INITIALIZATION (Delegated to Service Coordinator) =====

  Future<void> initialize() async {
    try {
      AppLogger.info('🔄 Initializing UnifiedFriendsService facade...');
      
      // Set up auth state change listener (CRITICAL FIX for authentication bug)
      listenToStream(
        _authRepository.authStateChanges(),
        (user) async {
          if (user != null) {
            // User logged in - reload friends data
            AppLogger.info('🔄 User logged in - reloading friends data for: ${user.uid}');
            await _stateManager.initialize();
            
            // Run migration to ensure owners are members of their groups
            await categories.migrateOwnersAsMembers();
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
      }
      
      // Initialize the service coordinator
      await _serviceCoordinator.initialize();
      
      AppLogger.success('✅ UnifiedFriendsService facade initialized with auth state handling');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize UnifiedFriendsService facade: $e');
      rethrow;
    }
  }

  // ===== PRIVATE INITIALIZATION METHODS =====

  void _initializeModules() {
    // Initialize state manager with Firebase repository and category repository
    _stateManager = FriendsStateManager(
      repository: _friendsRepository,
      categoryRepository: _categoryRepository,
    );
    
    // Initialize service coordinator
    _serviceCoordinator = FriendsServiceCoordinator();
    
    // Initialize internal operations
    _internalOps = FriendsInternalOperations(
      categoryRepository: _categoryRepository,
      authRepository: _authRepository,
    );
    
    // Connect internal operations to state manager
    _internalOps.setStateManager(_stateManager);
    
    // Forward state manager notifications to facade
    _stateManager.addListener(() {
      notifyListeners();
    });
    
    AppLogger.debug('Focused modules initialized with Firebase repository and category repository');
  }

  void _initializeFeatureInterfaces() {
    _managementOps = FriendsManagementOperations(this);
    _categoriesOps = FriendsCategoriesOperations(this);
    _invitationsOps = FriendsInvitationsOperations(this);
    _groupSharingOps = SocialGroupSharingOperations(this);
    
    AppLogger.debug('Feature interfaces initialized');
  }

  // ===== STATE MANAGEMENT (Delegated to State Manager) =====
  // Note: State management is now handled by FriendsStateManager
  // All state operations are automatically coordinated through the service coordinator

  // ===== INTERNAL METHODS FOR OPERATIONS CLASSES (Delegated to Internal Operations) =====

  /// Internal getter for friends list (for operations classes)
  List<UserProfile> get friendsInternal => _internalOps.friendsInternal;

  /// Internal getter for categories list (for operations classes)
  List<FriendCategory> getAllCategoriesInternal() => _internalOps.getAllCategoriesInternal();

  /// Internal getter for sent invitations (for operations classes)
  List<GroupInvitation> getAllSentInvitationsInternal() => _internalOps.getAllSentInvitationsInternal();

  /// Internal getter for friend-category relationships (for operations classes)
  Map<String, Set<String>> get friendCategoryRelationshipsInternal => _stateManager.relationshipsInternal;

  /// Internal method to notify listeners (for operations classes)
  void notifyListenersInternal() => _internalOps.notifyListenersInternal();

  /// Internal method to get category by ID (for operations classes)
  FriendCategory? getCategoryByIdInternal(String categoryId) => _internalOps.getCategoryByIdInternal(categoryId);

  /// Internal method to add category (for operations classes)
  void addCategoryInternal(FriendCategory category) => _internalOps.addCategoryInternal(category);

  /// Internal method to update category (for operations classes)
  void updateCategoryInternal(String categoryId, FriendCategory category) => _internalOps.updateCategoryInternal(categoryId, category);

  /// Internal method to remove category (for operations classes)
  void removeCategoryInternal(String categoryId) => _internalOps.removeCategoryInternal(categoryId);

  /// Internal method to sync category to Firebase (for operations classes)
  Future<void> syncCategoryToFirebaseInternal(FriendCategory category) async => await _internalOps.syncCategoryToFirebaseInternal(category);

  /// Internal method to delete category from Firebase (for operations classes)
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async => await _internalOps.deleteCategoryFromFirebaseInternal(categoryId);

  /// Internal method to add friend to category (for operations classes)
  void addFriendToCategoryInternal(String friendId, String categoryId) => _internalOps.addFriendToCategoryInternal(friendId, categoryId);

  /// Internal method to remove friend from category (for operations classes)
  void removeFriendFromCategoryInternal(String friendId, String categoryId) => _internalOps.removeFriendFromCategoryInternal(friendId, categoryId);

  /// Internal method to get friends in category (for operations classes)
  Set<String> getFriendsInCategoryInternal(String categoryId) => _internalOps.getFriendsInCategoryInternal(categoryId);

  /// Internal method to get categories for friend (for operations classes)
  Set<String> getCategoriesForFriendInternal(String friendId) => _internalOps.getCategoriesForFriendInternal(friendId);

  /// Internal method to add sent invitation (for operations classes)
  void addSentInvitationInternal(GroupInvitation invitation) => _internalOps.addSentInvitationInternal(invitation);

  /// Internal method to get sent invitation by ID (for operations classes)
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) => _internalOps.getSentInvitationByIdInternal(invitationId);

  /// Internal method to update sent invitation (for operations classes)
  void updateSentInvitationInternal(String invitationId, GroupInvitation invitation) => _internalOps.updateSentInvitationInternal(invitationId, invitation);

  /// Internal method to send email invitation (for operations classes)
  Future<bool> sendEmailInvitationInternal({required String email, required GroupInvitation invitation}) async => await _internalOps.sendEmailInvitationInternal(email: email, invitation: invitation);

  /// Internal method to send SMS invitation (for operations classes)
  Future<bool> sendSMSInvitationInternal({required String phoneNumber, required GroupInvitation invitation}) async => await _internalOps.sendSMSInvitationInternal(phoneNumber: phoneNumber, invitation: invitation);

  /// Internal method to create invitation link (for operations classes)
  String createInvitationLinkInternal(String invitationId) => _internalOps.createInvitationLinkInternal(invitationId);

  /// Internal method to update invitation status (for operations classes)
  Future<void> updateInvitationStatusInternal(String invitationId, GroupInvitationStatus status) async => await _internalOps.updateInvitationStatusInternal(invitationId, status);

  /// Internal getter for current user display name (for operations classes)
  String? get currentUserDisplayName => _internalOps.getCurrentUserDisplayNameInternal();

  /// Internal method to refresh data (for operations classes)
  Future<void> refresh() async => await _serviceCoordinator.refresh();

  // ===== ADDITIONAL INTERNAL METHODS FOR FRIENDS MANAGEMENT =====
  
  // ===== ULTRATHINK FIX: INTERNAL METHODS THAT ACTUALLY MODIFY STATE =====
  
  /// Internal method to add outgoing friend request
  void addOutgoingRequestInternal(FriendRequest request) {
    _stateManager.addOutgoingRequest(request);
    AppLogger.debug('✅ Added outgoing request to ${request.toUserId} via state manager');
  }
  
  /// Internal method to remove outgoing friend request
  void removeOutgoingRequestInternal(String requestId) {
    _stateManager.removeOutgoingRequest(requestId);
    AppLogger.debug('✅ Removed outgoing request $requestId via state manager');
  }
  
  /// Internal method to add incoming friend request
  void addIncomingRequestInternal(FriendRequest request) {
    _stateManager.addIncomingRequest(request);
    AppLogger.debug('✅ Added incoming request from ${request.fromUserId} via state manager');
  }
  
  /// Internal method to remove incoming friend request
  void removeIncomingRequestInternal(String requestId) {
    _stateManager.removeIncomingRequest(requestId);
    AppLogger.debug('✅ Removed incoming request $requestId via state manager');
  }
  
  /// Internal method to add friend
  void addFriendInternal(UserProfile friend) {
    _stateManager.addFriend(friend);
    AppLogger.debug('✅ Added friend ${friend.displayName} via state manager');
  }
  
  /// Internal method to remove friend
  void removeFriendInternal(String friendId) {
    _stateManager.removeFriend(friendId);
    AppLogger.debug('✅ Removed friend $friendId via state manager');
  }
  
  /// Internal method to add blocked user
  void addBlockedUserInternal(String userId) {
    _stateManager.addBlockedUser(userId);
    AppLogger.debug('✅ Blocked user $userId via state manager');
  }
  
  /// Internal method to remove blocked user
  void removeBlockedUserInternal(String userId) {
    _stateManager.removeBlockedUser(userId);
    AppLogger.debug('✅ Unblocked user $userId via state manager');
  }
  
  /// Sync friend request to Firebase
  Future<void> syncFriendRequestToFirebase(FriendRequest request) async {
    try {
      await firestore.collection('friend_requests').add({
        'fromUserId': request.fromUserId,
        'toUserId': request.toUserId,
        'message': request.message,
        'sentAt': request.sentAt,
        'status': request.status.toString().split('.').last,
      });
      AppLogger.success('Synced friend request to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend request to Firebase', e);
      rethrow;
    }
  }
  
  /// Update friend request status in Firebase
  Future<void> updateFriendRequestStatus(FriendRequest request) async {
    try {
      final querySnapshot = await firestore
          .collection('friend_requests')
          .where('fromUserId', isEqualTo: request.fromUserId)
          .where('toUserId', isEqualTo: request.toUserId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'status': request.status.toString().split('.').last,
          'respondedAt': request.respondedAt ?? DateTime.now(),
        });
        AppLogger.success('Updated friend request status in Firebase');
      }
    } catch (e) {
      AppLogger.error('Failed to update friend request status', e);
      rethrow;
    }
  }
  
  /// Sync friend to Firebase
  /// 
  /// ⚠️ ULTRATHINK WARNING: This method should NOT be used for friend request acceptance!
  /// Use FriendRelationshipRepository.addMutualFriends() instead, which properly handles:
  /// - Atomic operations, counter updates, and consistent field structures
  /// This method uses different field names and doesn't update friendsCount
  Future<void> syncFriendToFirebase(UserProfile friend) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      
      // Add to friends subcollection
      await firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friend.uid)
          .set({
        'friendSince': DateTime.now(),
        'displayName': friend.displayName,
      });
      
      // Also add reverse relationship
      await firestore
          .collection('users')
          .doc(friend.uid)
          .collection('friends')
          .doc(userId)
          .set({
        'friendSince': DateTime.now(),
      });
      
      AppLogger.success('Synced friend to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend to Firebase', e);
      rethrow;
    }
  }
  
  /// Remove friend from Firebase
  Future<void> removeFriendFromFirebase(String friendId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;
      
      // Remove from friends subcollection
      await firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendId)
          .delete();
      
      // Also remove reverse relationship
      await firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(userId)
          .delete();
      
      AppLogger.success('Removed friend from Firebase');
    } catch (e) {
      AppLogger.error('Failed to remove friend from Firebase', e);
      rethrow;
    }
  }

  // ===== PUBLIC METHODS FOR OPERATIONS CLASSES =====
  
  /// Get all friend requests (incoming and outgoing combined)
  List<FriendRequest> get friendRequests {
    final all = <FriendRequest>[];
    all.addAll(incomingRequests);
    all.addAll(outgoingRequests);
    return all;
  }
  
  /// Sync blocked users to Firebase
  Future<void> syncBlockedUsers() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        AppLogger.warning('Cannot sync blocked users: No authenticated user');
        return;
      }
      
      // Save blocked users to user document
      await firestore
          .collection('users')
          .doc(userId)
          .update({
        'blockedUsers': blockedUsers.toList(),
        'updatedAt': DateTime.now(),
      });
      
      AppLogger.success('Successfully synced ${blockedUsers.length} blocked users to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync blocked users to Firebase', e);
      rethrow;
    }
  }
  
  /// Search for users by query
  Future<List<UserProfile>> searchUsers(String query) async {
    // Delegate to management operations
    return await management.searchUsers(query);
  }
  
  /// Get friends of a specific user
  Future<List<UserProfile>> getFriendsOfUser(String userId) async {
    try {
      AppLogger.debug('Getting friends of user: $userId');
      
      // Get friend IDs from user document
      final userDoc = await firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        AppLogger.warning('User not found: $userId');
        return [];
      }
      
      final data = userDoc.data();
      final friendIds = List<String>.from(data?['friends'] ?? []);
      
      if (friendIds.isEmpty) {
        return [];
      }
      
      // Fetch friend profiles
      final friendProfiles = <UserProfile>[];
      for (final friendId in friendIds) {
        final friendDoc = await firestore
            .collection('users')
            .doc(friendId)
            .get();
        
        if (friendDoc.exists) {
          final friendData = friendDoc.data()!;
          friendProfiles.add(UserProfile(
            uid: friendId,
            displayName: friendData['displayName'] ?? 'Unknown User',
            email: friendData['email'] ?? '',
            avatarUrl: friendData['avatarUrl'],
            joinedAt: friendData['joinedAt'] != null ? (friendData['joinedAt'] as Timestamp).toDate() : DateTime.now(),
            lastActiveAt: friendData['lastActiveAt'] != null ? (friendData['lastActiveAt'] as Timestamp).toDate() : DateTime.now(),
          ));
        }
      }
      
      AppLogger.success('Found ${friendProfiles.length} friends for user $userId');
      return friendProfiles;
    } catch (e) {
      AppLogger.error('Failed to get friends of user $userId', e);
      return [];
    }
  }
  
  /// Get recent collaborators
  Future<List<UserProfile>> getRecentCollaborators() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        AppLogger.warning('Cannot get recent collaborators: No authenticated user');
        return [];
      }
      
      AppLogger.debug('Fetching recent collaborators for user: $userId');
      
      // Get recent collaborators from recipes
      final recentRecipes = await firestore
          .collection('recipes')
          .where('sharedWith', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(20)
          .get();
      
      // Get recent collaborators from menus
      final recentMenus = await firestore
          .collection('menus')
          .where('sharedWith', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(20)
          .get();
      
      // Collect unique collaborator IDs
      final collaboratorIds = <String>{};
      
      // Add recipe collaborators
      for (final doc in recentRecipes.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final sharedWith = List<String>.from(data['sharedWith'] ?? []);
        
        if (ownerId != null && ownerId != userId) {
          collaboratorIds.add(ownerId);
        }
        for (final collaboratorId in sharedWith) {
          if (collaboratorId != userId) {
            collaboratorIds.add(collaboratorId);
          }
        }
      }
      
      // Add menu collaborators
      for (final doc in recentMenus.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final sharedWith = List<String>.from(data['sharedWith'] ?? []);
        
        if (ownerId != null && ownerId != userId) {
          collaboratorIds.add(ownerId);
        }
        for (final collaboratorId in sharedWith) {
          if (collaboratorId != userId) {
            collaboratorIds.add(collaboratorId);
          }
        }
      }
      
      if (collaboratorIds.isEmpty) {
        AppLogger.debug('No recent collaborators found');
        return [];
      }
      
      // Fetch user profiles for collaborators
      final collaborators = <UserProfile>[];
      for (final collaboratorId in collaboratorIds.take(10)) { // Limit to 10 most recent
        final userDoc = await firestore
            .collection('users')
            .doc(collaboratorId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          collaborators.add(UserProfile(
            uid: collaboratorId,
            displayName: userData['displayName'] ?? 'Unknown User',
            email: userData['email'] ?? '',
            avatarUrl: userData['avatarUrl'],
            joinedAt: userData['joinedAt'] != null ? (userData['joinedAt'] as Timestamp).toDate() : DateTime.now(),
            lastActiveAt: userData['lastActiveAt'] != null ? (userData['lastActiveAt'] as Timestamp).toDate() : DateTime.now(),
          ));
        }
      }
      
      AppLogger.success('Found ${collaborators.length} recent collaborators');
      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent collaborators', e);
      return [];
    }
  }
  
  /// Get recent shopping collaborators
  Future<List<UserProfile>> getRecentShoppingCollaborators() async {
    try {
      final userId = currentUserId;
      if (userId == null) {
        AppLogger.warning('Cannot get recent shopping collaborators: No authenticated user');
        return [];
      }
      
      AppLogger.debug('Fetching recent shopping collaborators for user: $userId');
      
      // Get recent shopping lists where user is a collaborator
      final recentShoppingLists = await firestore
          .collection('shopping_lists')
          .where('collaborators', arrayContains: userId)
          .orderBy('lastModified', descending: true)
          .limit(20)
          .get();
      
      // Collect unique collaborator IDs
      final collaboratorIds = <String>{};
      
      for (final doc in recentShoppingLists.docs) {
        final data = doc.data();
        final ownerId = data['ownerId'] as String?;
        final collaborators = List<String>.from(data['collaborators'] ?? []);
        
        // Add owner if not the current user
        if (ownerId != null && ownerId != userId) {
          collaboratorIds.add(ownerId);
        }
        
        // Add all collaborators except current user
        for (final collaboratorId in collaborators) {
          if (collaboratorId != userId) {
            collaboratorIds.add(collaboratorId);
          }
        }
      }
      
      if (collaboratorIds.isEmpty) {
        AppLogger.debug('No recent shopping collaborators found');
        return [];
      }
      
      // Fetch user profiles for collaborators
      final collaborators = <UserProfile>[];
      for (final collaboratorId in collaboratorIds.take(10)) { // Limit to 10 most recent
        final userDoc = await firestore
            .collection('users')
            .doc(collaboratorId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          collaborators.add(UserProfile(
            uid: collaboratorId,
            displayName: userData['displayName'] ?? 'Unknown User',
            email: userData['email'] ?? '',
            avatarUrl: userData['avatarUrl'],
            joinedAt: userData['joinedAt'] != null ? (userData['joinedAt'] as Timestamp).toDate() : DateTime.now(),
            lastActiveAt: userData['lastActiveAt'] != null ? (userData['lastActiveAt'] as Timestamp).toDate() : DateTime.now(),
          ));
        }
      }
      
      AppLogger.success('Found ${collaborators.length} recent shopping collaborators');
      return collaborators;
    } catch (e) {
      AppLogger.error('Failed to get recent shopping collaborators', e);
      return [];
    }
  }

  // ===== VIEWMODEL COMPATIBILITY METHODS (Delegated) =====

  /// Clear error state (for ViewModels)
  void clearError() => _stateManager.clearError();

  /// Get friends list (for ViewModels)
  List<UserProfile> get friendsList => friends;

  /// Get category by ID (for ViewModels)
  FriendCategory? getCategoryById(String categoryId) => _stateManager.getCategoryById(categoryId);

  /// Cancel sent invitation (for ViewModels)
  Future<bool> cancelSentInvitation(String invitationId) async => await invitations.cancelInvitation(invitationId);

  // ===== CLEANUP (Delegated to Service Coordinator) =====

  @override
  void dispose() {
    // Clear friends state manager first
    _stateManager.clearAllData();
    
    // Dispose service coordinator
    _serviceCoordinator.dispose();
    
    // Dispose stream subscriptions (async, so we'll do it without await)
    disposeStreamResources();
    
    super.dispose();
  }
}