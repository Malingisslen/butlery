/// 🔍 AI INFO BLOCK:
/// Component: Unified Friends Service - Main service for friend management with focused services
/// File: lib/services/unified/unified_friends_service.dart
/// Quick Guide: Central service for all friend-related operations using focused services pattern
/// Dependencies IN: FirestoreRepository, AuthRepository, Friend models
/// Dependencies OUT: Used by ViewModels for friend operations
/// Data flow: ViewModels -> Feature Interfaces -> UnifiedFriendsService -> Focused Services -> Firebase/Cache
/// State management: ChangeNotifier with real-time Firebase sync
/// Purpose: Centralized friend management with separated concerns
/// Common issues: Real-time sync, offline support, permission handling
/// Test coverage: Unit tests for all friend operations and feature interfaces
/// Performance: Optimistic updates with Firebase sync and caching
/// Analytics: Friend activity, relationship metrics, social engagement
/// Code smells: None - follows unified service pattern with focused services
/// Connected to: All friend-related ViewModels and social features
/// Used in phases: Phase 7 - Widget Structure Reorganization

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import '../../core/cache/json_cache_helper.dart';
import '../../repositories/interfaces/auth_repository.dart';
import '../../repositories/firestore_repository.dart';
import '../../models/friend_request.dart';
import '../../models/user_profile.dart';
import '../../models/friend_category.dart';
import '../../models/group_invitation.dart';
import '../../core/utils/logger.dart';
import '../../services/permission_service.dart';
import '../../core/injection.dart';

// Feature interfaces
import 'operations/friends_management_operations.dart';
import 'operations/friends_categories_operations.dart';
import 'operations/friends_invitations_operations.dart';

// Focused services
import 'friends/friends_sync_service.dart';
import 'friends/friends_presence_service.dart';
import 'friends/friends_cache_service.dart';

/// Unified Friends Service - Main orchestrator for friend management
/// 
/// This service coordinates between different focused services:
/// - FriendsSyncService: Handles Firebase synchronization
/// - FriendsPresenceService: Handles real-time presence tracking
/// - FriendsCacheService: Handles local caching
/// - Feature operations: Handle specific business logic
class UnifiedFriendsService extends ChangeNotifier {
  // Dependencies
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  
  // Focused services
  late final FriendsSyncService _syncService;
  late final FriendsPresenceService _presenceService;
  late final FriendsCacheService _cacheService;
  
  // Feature interfaces
  late final FriendsManagementOperations _managementOps;
  late final FriendsCategoriesOperations _categoriesOps;
  late final FriendsInvitationsOperations _invitationsOps;

  // State
  final List<UserProfile> _friends = [];
  final List<FriendRequest> _incomingRequests = [];
  final List<FriendRequest> _outgoingRequests = [];
  final List<FriendCategory> _categories = [];
  final List<GroupInvitation> _sentInvitations = [];
  final Set<String> _blockedUsers = {};
  
  // Friend-Category relationship mapping (friendId -> Set<categoryId>)
  final Map<String, Set<String>> _friendCategoryRelationships = {};

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // Constructor
  UnifiedFriendsService({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository {
    
    // Initialize focused services
    _syncService = FriendsSyncService(_firestoreRepository.firestore);
    _presenceService = FriendsPresenceService(_firestoreRepository.firestore);
    _cacheService = FriendsCacheService(JsonCacheFactory.friendsCache());
    
    // Initialize feature interfaces
    _managementOps = FriendsManagementOperations(this);
    _categoriesOps = FriendsCategoriesOperations(this);
    _invitationsOps = FriendsInvitationsOperations(this);
    
    // Setup service callbacks
    _setupServiceCallbacks();
  }

  // ===== GETTERS =====

  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);
  List<FriendCategory> get categoriesList => List.unmodifiable(_categories);
  List<GroupInvitation> get sentInvitations => List.unmodifiable(_sentInvitations);
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);
  Map<String, Set<String>> get friendCategoryRelationships => Map.unmodifiable(_friendCategoryRelationships);

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  
  String? get currentUserId => sl<PermissionService>().currentUserId;
  FirebaseFirestore get firestore => _firestoreRepository.firestore;

  // ===== FEATURE INTERFACE GETTERS =====

  FriendsManagementOperations get management => _managementOps;
  FriendsCategoriesOperations get categories => _categoriesOps;
  FriendsInvitationsOperations get invitations => _invitationsOps;

  // ===== SERVICE GETTERS =====

  FriendsSyncService get sync => _syncService;
  FriendsPresenceService get presence => _presenceService;
  FriendsCacheService get cache => _cacheService;

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.info('🔄 Initializing UnifiedFriendsService...');
      _setLoading(true);
      
      // Initialize cache helper
      _cacheService.setCurrentUser(currentUserId);

      // Load cached data first (offline-first approach)
      await _loadCachedData();

      // Set up authentication listener
      _authRepository.authStateChanges().listen((user) {
        _onAuthStateChanged(user?.uid);
        _cacheService.setCurrentUser(user?.uid);
        if (user == null) {
          _clearAll();
        }
      });

      // Start Firebase sync if authenticated
      if (_authRepository.getCurrentUser() != null) {
        await _startFirebaseSync();
        await _presenceService.setupMyPresence();
      }

      _isInitialized = true;
      _setLoading(false);
      AppLogger.success('✅ UnifiedFriendsService initialized');
      
    } catch (e) {
      AppLogger.error('❌ Failed to initialize UnifiedFriendsService: $e');
      _setError('Failed to initialize friends service: $e');
      _setLoading(false);
    }
  }

  // ===== PRIVATE METHODS =====

  void _setupServiceCallbacks() {
    // Sync service callbacks
    _syncService.onFriendAdded = (friend) {
      _addFriend(friend);
    };
    
    _syncService.onFriendModified = (friend) {
      _updateFriend(friend);
    };
    
    _syncService.onFriendRemoved = (friendId) {
      _removeFriend(friendId);
    };
    
    _syncService.onFriendRequestAdded = (request) {
      _addFriendRequest(request);
    };
    
    _syncService.onFriendRequestModified = (request) {
      _updateFriendRequest(request);
    };
    
    _syncService.onFriendRequestRemoved = (requestId) {
      _removeFriendRequest(requestId);
    };
    
    _syncService.onCategoryAdded = (category) {
      _addCategory(category);
    };
    
    _syncService.onCategoryModified = (category) {
      _updateCategory(category);
    };
    
    _syncService.onCategoryRemoved = (categoryId) {
      _removeCategory(categoryId);
    };
    
    // Presence service callbacks
    _presenceService.onPresenceChanged = (friendId, isOnline) {
      _updateFriendPresence(friendId, isOnline);
    };
  }

  Future<void> _loadCachedData() async {
    try {
      final cachedData = await _cacheService.loadAllCachedData();
      
      _friends.clear();
      _friends.addAll(cachedData['friends'] as List<UserProfile>);
      
      _incomingRequests.clear();
      _incomingRequests.addAll(cachedData['incomingRequests'] as List<FriendRequest>);
      
      _outgoingRequests.clear();
      _outgoingRequests.addAll(cachedData['outgoingRequests'] as List<FriendRequest>);
      
      _categories.clear();
      _categories.addAll(cachedData['categories'] as List<FriendCategory>);
      
      _sentInvitations.clear();
      _sentInvitations.addAll(cachedData['sentInvitations'] as List<GroupInvitation>);
      
      _blockedUsers.clear();
      _blockedUsers.addAll(cachedData['blockedUsers'] as Set<String>);
      
      _friendCategoryRelationships.clear();
      _friendCategoryRelationships.addAll(cachedData['friendCategoryRelationships'] as Map<String, Set<String>>);
      
      // Subscribe to presence for all friends
      _presenceService.subscribeToFriendsPresence(_friends.map((f) => f.uid).toList());
      
      notifyListeners();
      
      AppLogger.debug('Cached friends data loaded: ${_friends.length} friends');
    } catch (e) {
      AppLogger.error('Failed to load cached data: $e');
    }
  }

  Future<void> _startFirebaseSync() async {
    try {
      _syncService.startFirebaseSync();
      AppLogger.debug('Firebase sync started for friends');
    } catch (e) {
      AppLogger.error('Failed to start Firebase sync: $e');
    }
  }

  void _onAuthStateChanged(String? userId) {
    if (userId == null) {
      _clearAll();
    } else {
      // Re-initialize if user changed
      if (_isInitialized && currentUserId != userId) {
        _isInitialized = false;
        initialize();
      }
    }
  }

  void _clearAll() {
    _friends.clear();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _categories.clear();
    _sentInvitations.clear();
    _blockedUsers.clear();
    _friendCategoryRelationships.clear();
    _presenceService.dispose();
    _isInitialized = false;
    _setError(null);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // ===== STATE MANAGEMENT =====

  void _addFriend(UserProfile friend) {
    if (!_friends.any((f) => f.uid == friend.uid)) {
      _friends.add(friend);
      _cacheService.saveFriendToCache(friend);
      _presenceService.subscribeToFriendPresence(friend.uid);
      notifyListeners();
    }
  }

  void _updateFriend(UserProfile friend) {
    final index = _friends.indexWhere((f) => f.uid == friend.uid);
    if (index != -1) {
      _friends[index] = friend;
      _cacheService.saveFriendToCache(friend);
      notifyListeners();
    }
  }

  void _removeFriend(String friendId) {
    _friends.removeWhere((f) => f.uid == friendId);
    _cacheService.removeFriendFromCache(friendId);
    _presenceService.unsubscribeFromFriendPresence(friendId);
    notifyListeners();
  }

  void _addFriendRequest(FriendRequest request) {
    if (request.toUserId == currentUserId) {
      if (!_incomingRequests.any((r) => r.id == request.id)) {
        _incomingRequests.add(request);
        _cacheService.saveIncomingRequestsToCache(_incomingRequests);
        notifyListeners();
      }
    } else if (request.fromUserId == currentUserId) {
      if (!_outgoingRequests.any((r) => r.id == request.id)) {
        _outgoingRequests.add(request);
        _cacheService.saveOutgoingRequestsToCache(_outgoingRequests);
        notifyListeners();
      }
    }
  }

  void _updateFriendRequest(FriendRequest request) {
    if (request.toUserId == currentUserId) {
      final index = _incomingRequests.indexWhere((r) => r.id == request.id);
      if (index != -1) {
        _incomingRequests[index] = request;
        _cacheService.saveIncomingRequestsToCache(_incomingRequests);
        notifyListeners();
      }
    } else if (request.fromUserId == currentUserId) {
      final index = _outgoingRequests.indexWhere((r) => r.id == request.id);
      if (index != -1) {
        _outgoingRequests[index] = request;
        _cacheService.saveOutgoingRequestsToCache(_outgoingRequests);
        notifyListeners();
      }
    }
  }

  void _removeFriendRequest(String requestId) {
    _incomingRequests.removeWhere((r) => r.id == requestId);
    _outgoingRequests.removeWhere((r) => r.id == requestId);
    _cacheService.saveIncomingRequestsToCache(_incomingRequests);
    _cacheService.saveOutgoingRequestsToCache(_outgoingRequests);
    notifyListeners();
  }

  void _addCategory(FriendCategory category) {
    if (!_categories.any((c) => c.id == category.id)) {
      _categories.add(category);
      _cacheService.saveCategoryToCache(category);
      notifyListeners();
    }
  }

  void _updateCategory(FriendCategory category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      _cacheService.saveCategoryToCache(category);
      notifyListeners();
    }
  }

  void _removeCategory(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
    _cacheService.removeCategoryFromCache(categoryId);
    notifyListeners();
  }

  void _updateFriendPresence(String friendId, bool isOnline) {
    final index = _friends.indexWhere((f) => f.uid == friendId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(isOnline: isOnline);
      _cacheService.saveFriendToCache(_friends[index]);
      notifyListeners();
    }
  }

  // ===== INTERNAL METHODS FOR OPERATIONS CLASSES =====

  /// Internal getter for friends list (for operations classes)
  List<UserProfile> get friendsInternal => _friends;

  /// Internal getter for categories list (for operations classes)
  List<FriendCategory> getAllCategoriesInternal() => _categories;

  /// Internal getter for sent invitations (for operations classes)
  List<GroupInvitation> getAllSentInvitationsInternal() => _sentInvitations;

  /// Internal getter for friend-category relationships (for operations classes)
  Map<String, Set<String>> get friendCategoryRelationshipsInternal => _friendCategoryRelationships;

  /// Internal method to notify listeners (for operations classes)
  void notifyListenersInternal() => notifyListeners();

  /// Internal method to get category by ID (for operations classes)
  FriendCategory? getCategoryByIdInternal(String categoryId) {
    return _categories.where((c) => c.id == categoryId).firstOrNull;
  }

  /// Internal method to add category (for operations classes)
  void addCategoryInternal(FriendCategory category) {
    if (!_categories.any((c) => c.id == category.id)) {
      _categories.add(category);
    }
  }

  /// Internal method to update category (for operations classes)
  void updateCategoryInternal(String categoryId, FriendCategory category) {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      _categories[index] = category;
    }
  }

  /// Internal method to remove category (for operations classes)
  void removeCategoryInternal(String categoryId) {
    _categories.removeWhere((c) => c.id == categoryId);
  }

  /// Internal method to sync category to Firebase (for operations classes)
  Future<void> syncCategoryToFirebaseInternal(FriendCategory category) async {
    await _syncService.syncCategoryToFirebase(category);
  }

  /// Internal method to delete category from Firebase (for operations classes)
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async {
    await _syncService.removeCategoryFromFirebase(categoryId);
  }

  /// Internal method to add friend to category (for operations classes)
  void addFriendToCategoryInternal(String friendId, String categoryId) {
    if (!_friendCategoryRelationships.containsKey(friendId)) {
      _friendCategoryRelationships[friendId] = <String>{};
    }
    _friendCategoryRelationships[friendId]!.add(categoryId);
  }

  /// Internal method to remove friend from category (for operations classes)
  void removeFriendFromCategoryInternal(String friendId, String categoryId) {
    _friendCategoryRelationships[friendId]?.remove(categoryId);
    if (_friendCategoryRelationships[friendId]?.isEmpty ?? false) {
      _friendCategoryRelationships.remove(friendId);
    }
  }

  /// Internal method to get friends in category (for operations classes)
  Set<String> getFriendsInCategoryInternal(String categoryId) {
    return _friendCategoryRelationships.entries
        .where((entry) => entry.value.contains(categoryId))
        .map((entry) => entry.key)
        .toSet();
  }

  /// Internal method to get categories for friend (for operations classes)
  Set<String> getCategoriesForFriendInternal(String friendId) {
    return _friendCategoryRelationships[friendId] ?? <String>{};
  }

  /// Internal method to add sent invitation (for operations classes)
  void addSentInvitationInternal(GroupInvitation invitation) {
    if (!_sentInvitations.any((i) => i.id == invitation.id)) {
      _sentInvitations.add(invitation);
    }
  }

  /// Internal method to get sent invitation by ID (for operations classes)
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) {
    return _sentInvitations.where((i) => i.id == invitationId).firstOrNull;
  }

  /// Internal method to update sent invitation (for operations classes)
  void updateSentInvitationInternal(String invitationId, GroupInvitation invitation) {
    final index = _sentInvitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      _sentInvitations[index] = invitation;
    }
  }

  /// Internal method to send email invitation (for operations classes)
  Future<bool> sendEmailInvitationInternal({
    required String email,
    required GroupInvitation invitation,
  }) async {
    // Email service integration would go here
    // For now, return false as service is not implemented
    AppLogger.warning('Email service not implemented yet');
    return false;
  }

  /// Internal method to send SMS invitation (for operations classes)
  Future<bool> sendSMSInvitationInternal({
    required String phoneNumber,
    required GroupInvitation invitation,
  }) async {
    // SMS service integration would go here
    // For now, return false as service is not implemented
    AppLogger.warning('SMS service not implemented yet');
    return false;
  }

  /// Internal method to create invitation link (for operations classes)
  String createInvitationLinkInternal(String invitationId) {
    // Deep link service integration would go here
    // For now, return a placeholder link
    return 'https://butlery.app/invite/$invitationId';
  }

  /// Internal method to update invitation status (for operations classes)
  Future<void> updateInvitationStatusInternal(String invitationId, GroupInvitationStatus status) async {
    // Firebase update would go here
    // For now, just log the action
    AppLogger.debug('Invitation status updated: $invitationId -> $status');
  }

  /// Internal getter for current user display name (for operations classes)
  String? get currentUserDisplayName {
    // This would typically come from user profile service
    // For now, return a placeholder
    return 'Current User';
  }

  /// Internal method to refresh data (for operations classes)
  Future<void> refresh() async {
    if (!_isInitialized) return;
    
    try {
      _setLoading(true);
      await _startFirebaseSync();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to refresh: $e');
      _setLoading(false);
    }
  }

  // ===== VIEWMODEL COMPATIBILITY METHODS =====

  /// Clear error state (for ViewModels)
  void clearError() {
    _setError(null);
  }

  /// Get friends list (for ViewModels)
  List<UserProfile> get friendsList => friends;

  /// Get category by ID (for ViewModels)
  FriendCategory? getCategoryById(String categoryId) {
    return getCategoryByIdInternal(categoryId);
  }

  /// Cancel sent invitation (for ViewModels)
  Future<bool> cancelSentInvitation(String invitationId) async {
    return await invitations.cancelInvitation(invitationId);
  }

  // ===== CLEANUP =====

  @override
  void dispose() {
    _presenceService.dispose();
    _syncService.stopFirebaseSync();
    super.dispose();
  }
}