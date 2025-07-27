// lib/services/unified/friends/friends_service_coordinator.dart

import 'dart:async';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/services/unified/friends/friends_sync_service.dart';
import 'package:butlery/services/unified/friends/friends_presence_service.dart';
import 'package:butlery/services/unified/friends/friends_cache_service.dart';

/// Focused module for service coordination and initialization
/// 
/// This module handles ONLY service coordination responsibilities:
/// - Initializing focused services
/// - Setting up service callbacks
/// - Managing authentication state changes
/// - Coordinating Firebase sync operations
/// - Loading and managing cached data
/// 
/// ❌ DOES NOT CONTAIN: State management, feature operations, UI concerns
class FriendsServiceCoordinator {
  final FirestoreRepository _firestoreRepository;
  final AuthRepository _authRepository;
  final FriendsStateManager _stateManager;

  // Focused services
  late final FriendsSyncService _syncService;
  late final FriendsPresenceService _presenceService;
  late final FriendsCacheService _cacheService;

  // Auth subscription
  StreamSubscription<dynamic>? _authSubscription;

  FriendsServiceCoordinator({
    required FirestoreRepository firestoreRepository,
    required AuthRepository authRepository,
    required FriendsStateManager stateManager,
  })  : _firestoreRepository = firestoreRepository,
        _authRepository = authRepository,
        _stateManager = stateManager {
    
    // Initialize focused services
    _initializeFocusedServices();
    
    // Setup service callbacks
    _setupServiceCallbacks();
  }

  // ===== GETTERS =====

  FriendsSyncService get sync => _syncService;
  FriendsPresenceService get presence => _presenceService;
  FriendsCacheService get cache => _cacheService;

  String? get currentUserId => sl<PermissionService>().currentUserId;

  // ===== INITIALIZATION =====

  Future<void> initialize() async {
    if (_stateManager.isInitialized) return;

    try {
      AppLogger.info('🔄 Initializing FriendsServiceCoordinator...');
      _stateManager.setLoading(true);
      
      // Initialize cache helper
      _cacheService.setCurrentUser(currentUserId);

      // Load cached data first (offline-first approach)
      await _loadCachedData();

      // Set up authentication listener
      _setupAuthListener();

      // Start Firebase sync if authenticated
      if (_authRepository.getCurrentUser() != null) {
        await _startFirebaseSync();
        await _presenceService.setupMyPresence();
      }

      _stateManager.setInitialized(true);
      _stateManager.setLoading(false);
      AppLogger.success('✅ FriendsServiceCoordinator initialized');
      
    } catch (e) {
      AppLogger.error('❌ Failed to initialize FriendsServiceCoordinator: $e');
      _stateManager.setError('Failed to initialize friends service: $e');
      _stateManager.setLoading(false);
    }
  }

  // ===== PRIVATE INITIALIZATION METHODS =====

  void _initializeFocusedServices() {
    _syncService = FriendsSyncService(_firestoreRepository.firestore);
    _presenceService = FriendsPresenceService(_firestoreRepository.firestore);
    _cacheService = FriendsCacheService(JsonCacheFactory.friendsCache());
    
    AppLogger.debug('Focused services initialized');
  }

  void _setupServiceCallbacks() {
    // Sync service callbacks
    _syncService.onFriendAdded = (friend) {
      _stateManager.addFriend(friend);
      _cacheService.saveFriendToCache(friend);
    };
    
    _syncService.onFriendModified = (friend) {
      _stateManager.updateFriend(friend);
      _cacheService.saveFriendToCache(friend);
    };
    
    _syncService.onFriendRemoved = (friendId) {
      _stateManager.removeFriend(friendId);
      _cacheService.removeFriendFromCache(friendId);
      _presenceService.unsubscribeFromFriendPresence(friendId);
    };
    
    _syncService.onFriendRequestAdded = (request) {
      _stateManager.addFriendRequest(request, currentUserId);
      _cacheService.saveIncomingRequestsToCache(_stateManager.incomingRequests);
      _cacheService.saveOutgoingRequestsToCache(_stateManager.outgoingRequests);
    };
    
    _syncService.onFriendRequestModified = (request) {
      _stateManager.updateFriendRequest(request, currentUserId);
      _cacheService.saveIncomingRequestsToCache(_stateManager.incomingRequests);
      _cacheService.saveOutgoingRequestsToCache(_stateManager.outgoingRequests);
    };
    
    _syncService.onFriendRequestRemoved = (requestId) {
      _stateManager.removeFriendRequest(requestId);
      _cacheService.saveIncomingRequestsToCache(_stateManager.incomingRequests);
      _cacheService.saveOutgoingRequestsToCache(_stateManager.outgoingRequests);
    };
    
    _syncService.onCategoryAdded = (category) {
      _stateManager.addCategory(category);
      _cacheService.saveCategoryToCache(category);
    };
    
    _syncService.onCategoryModified = (category) {
      _stateManager.updateCategory(category);
      _cacheService.saveCategoryToCache(category);
    };
    
    _syncService.onCategoryRemoved = (categoryId) {
      _stateManager.removeCategory(categoryId);
      _cacheService.removeCategoryFromCache(categoryId);
    };
    
    // Presence service callbacks
    _presenceService.onPresenceChanged = (friendId, isOnline) {
      _stateManager.updateFriendPresence(friendId, isOnline);
      
      // Update cache with new presence status
      final friend = _stateManager.friendsInternal
          .where((f) => f.uid == friendId)
          .firstOrNull;
      if (friend != null) {
        _cacheService.saveFriendToCache(friend);
      }
    };
    
    AppLogger.debug('Service callbacks configured');
  }

  void _setupAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = _authRepository.authStateChanges().listen((user) {
      _onAuthStateChanged(user?.uid);
      _cacheService.setCurrentUser(user?.uid);
      
      if (user == null) {
        _clearAll();
      }
    });
    
    AppLogger.debug('Auth listener configured');
  }

  // ===== DATA LOADING =====

  Future<void> _loadCachedData() async {
    try {
      final cachedData = await _cacheService.loadAllCachedData();
      
      _stateManager.loadCachedState(
        friends: (cachedData['friends'] as List<dynamic>).cast<UserProfile>(),
        incomingRequests: (cachedData['incomingRequests'] as List<dynamic>).cast<FriendRequest>(),
        outgoingRequests: (cachedData['outgoingRequests'] as List<dynamic>).cast<FriendRequest>(),
        categories: (cachedData['categories'] as List<dynamic>).cast<FriendCategory>(),
        sentInvitations: (cachedData['sentInvitations'] as List<dynamic>).cast<GroupInvitation>(),
        blockedUsers: cachedData['blockedUsers'] as Set<String>,
        friendCategoryRelationships: cachedData['friendCategoryRelationships'] as Map<String, Set<String>>,
      );
      
      // Subscribe to presence for all friends
      final friendIds = _stateManager.friends.map((f) => f.uid).toList();
      if (friendIds.isNotEmpty) {
        _presenceService.subscribeToFriendsPresence(friendIds);
      }
      
      AppLogger.debug('✅ Cached friends data loaded: ${_stateManager.friends.length} friends');
    } catch (e) {
      AppLogger.error('❌ Failed to load cached data: $e');
    }
  }

  Future<void> _startFirebaseSync() async {
    try {
      _syncService.startFirebaseSync();
      AppLogger.debug('✅ Firebase sync started for friends');
    } catch (e) {
      AppLogger.error('❌ Failed to start Firebase sync: $e');
    }
  }

  // ===== AUTH STATE MANAGEMENT =====

  void _onAuthStateChanged(String? userId) {
    if (userId == null) {
      _clearAll();
    } else {
      // Re-initialize if user changed
      if (_stateManager.isInitialized && currentUserId != userId) {
        _stateManager.setInitialized(false);
        initialize();
      }
    }
  }

  void _clearAll() {
    _stateManager.clearAll();
    _presenceService.dispose();
    AppLogger.debug('All friends data cleared due to auth change');
  }

  // ===== PUBLIC OPERATIONS =====

  /// Refresh data from Firebase
  Future<void> refresh() async {
    if (!_stateManager.isInitialized) return;
    
    try {
      _stateManager.setLoading(true);
      await _startFirebaseSync();
      _stateManager.setLoading(false);
    } catch (e) {
      _stateManager.setError('Failed to refresh: $e');
      _stateManager.setLoading(false);
    }
  }

  /// Clear error state
  void clearError() {
    _stateManager.clearError();
  }

  // ===== PRESENCE MANAGEMENT =====

  /// Subscribe to friend presence
  void subscribeToFriendPresence(String friendId) {
    _presenceService.subscribeToFriendPresence(friendId);
  }

  /// Unsubscribe from friend presence
  void unsubscribeFromFriendPresence(String friendId) {
    _presenceService.unsubscribeFromFriendPresence(friendId);
  }

  /// Subscribe to multiple friends presence
  void subscribeToFriendsPresence(List<String> friendIds) {
    _presenceService.subscribeToFriendsPresence(friendIds);
  }

  // ===== CLEANUP =====

  void dispose() {
    _authSubscription?.cancel();
    _presenceService.dispose();
    _syncService.stopFirebaseSync();
    AppLogger.debug('FriendsServiceCoordinator disposed');
  }
}