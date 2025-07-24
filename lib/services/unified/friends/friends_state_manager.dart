// lib/services/unified/friends/friends_state_manager.dart

import 'package:flutter/foundation.dart';
import '../../../models/friend_request.dart';
import '../../../models/user_profile.dart';
import '../../../models/friend_category.dart';
import '../../../models/group_invitation.dart';
import '../../../core/utils/logger.dart';

/// Focused module for friends state management
/// 
/// This module handles ONLY state management responsibilities:
/// - Managing friends list state
/// - Managing friend requests state
/// - Managing categories and relationships state
/// - Notifying listeners of state changes
/// - Loading and managing cached data state
/// 
/// ❌ DOES NOT CONTAIN: Firebase operations, service coordination, feature operations
class FriendsStateManager extends ChangeNotifier {
  // State collections
  final List<UserProfile> _friends = [];
  final List<FriendRequest> _incomingRequests = [];
  final List<FriendRequest> _outgoingRequests = [];
  final List<FriendCategory> _categories = [];
  final List<GroupInvitation> _sentInvitations = [];
  final Set<String> _blockedUsers = {};
  final Map<String, Set<String>> _friendCategoryRelationships = {};

  // State flags
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // ===== GETTERS =====

  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);
  List<FriendCategory> get categories => List.unmodifiable(_categories);
  List<GroupInvitation> get sentInvitations => List.unmodifiable(_sentInvitations);
  Set<String> get blockedUsers => Set.unmodifiable(_blockedUsers);
  Map<String, Set<String>> get friendCategoryRelationships => Map.unmodifiable(_friendCategoryRelationships);

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // ===== STATE FLAGS MANAGEMENT =====

  void setInitialized(bool initialized) {
    _isInitialized = initialized;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ===== FRIENDS STATE MANAGEMENT =====

  void addFriend(UserProfile friend) {
    if (!_friends.any((f) => f.uid == friend.uid)) {
      _friends.add(friend);
      notifyListeners();
      AppLogger.debug('Friend added to state: ${friend.displayName}');
    }
  }

  void updateFriend(UserProfile friend) {
    final index = _friends.indexWhere((f) => f.uid == friend.uid);
    if (index != -1) {
      _friends[index] = friend;
      notifyListeners();
      AppLogger.debug('Friend updated in state: ${friend.displayName}');
    }
  }

  void removeFriend(String friendId) {
    final initialLength = _friends.length;
    _friends.removeWhere((f) => f.uid == friendId);
    if (_friends.length < initialLength) {
      notifyListeners();
      AppLogger.debug('Friend removed from state: $friendId');
    }
  }

  void updateFriendPresence(String friendId, bool isOnline) {
    final index = _friends.indexWhere((f) => f.uid == friendId);
    if (index != -1) {
      _friends[index] = _friends[index].copyWith(isOnline: isOnline);
      notifyListeners();
      AppLogger.debug('Friend presence updated: $friendId -> $isOnline');
    }
  }

  // ===== FRIEND REQUESTS STATE MANAGEMENT =====

  void addFriendRequest(FriendRequest request, String? currentUserId) {
    if (currentUserId == null) return;

    if (request.toUserId == currentUserId) {
      if (!_incomingRequests.any((r) => r.id == request.id)) {
        _incomingRequests.add(request);
        notifyListeners();
        AppLogger.debug('Incoming friend request added: ${request.id}');
      }
    } else if (request.fromUserId == currentUserId) {
      if (!_outgoingRequests.any((r) => r.id == request.id)) {
        _outgoingRequests.add(request);
        notifyListeners();
        AppLogger.debug('Outgoing friend request added: ${request.id}');
      }
    }
  }

  void updateFriendRequest(FriendRequest request, String? currentUserId) {
    if (currentUserId == null) return;

    if (request.toUserId == currentUserId) {
      final index = _incomingRequests.indexWhere((r) => r.id == request.id);
      if (index != -1) {
        _incomingRequests[index] = request;
        notifyListeners();
        AppLogger.debug('Incoming friend request updated: ${request.id}');
      }
    } else if (request.fromUserId == currentUserId) {
      final index = _outgoingRequests.indexWhere((r) => r.id == request.id);
      if (index != -1) {
        _outgoingRequests[index] = request;
        notifyListeners();
        AppLogger.debug('Outgoing friend request updated: ${request.id}');
      }
    }
  }

  void removeFriendRequest(String requestId) {
    final incomingInitialLength = _incomingRequests.length;
    final outgoingInitialLength = _outgoingRequests.length;
    
    _incomingRequests.removeWhere((r) => r.id == requestId);
    _outgoingRequests.removeWhere((r) => r.id == requestId);
    
    if (_incomingRequests.length < incomingInitialLength || 
        _outgoingRequests.length < outgoingInitialLength) {
      notifyListeners();
      AppLogger.debug('Friend request removed: $requestId');
    }
  }

  // ===== CATEGORIES STATE MANAGEMENT =====

  void addCategory(FriendCategory category) {
    if (!_categories.any((c) => c.id == category.id)) {
      _categories.add(category);
      notifyListeners();
      AppLogger.debug('Category added to state: ${category.name}');
    }
  }

  void updateCategory(FriendCategory category) {
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      _categories[index] = category;
      notifyListeners();
      AppLogger.debug('Category updated in state: ${category.name}');
    }
  }

  void removeCategory(String categoryId) {
    final initialLength = _categories.length;
    _categories.removeWhere((c) => c.id == categoryId);
    if (_categories.length < initialLength) {
      notifyListeners();
      AppLogger.debug('Category removed from state: $categoryId');
    }
  }

  FriendCategory? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // ===== CATEGORY RELATIONSHIPS STATE MANAGEMENT =====

  void addFriendToCategory(String friendId, String categoryId) {
    if (!_friendCategoryRelationships.containsKey(friendId)) {
      _friendCategoryRelationships[friendId] = <String>{};
    }
    
    final wasAdded = _friendCategoryRelationships[friendId]!.add(categoryId);
    if (wasAdded) {
      notifyListeners();
      AppLogger.debug('Friend $friendId added to category $categoryId');
    }
  }

  void removeFriendFromCategory(String friendId, String categoryId) {
    final removed = _friendCategoryRelationships[friendId]?.remove(categoryId) ?? false;
    
    if (_friendCategoryRelationships[friendId]?.isEmpty ?? false) {
      _friendCategoryRelationships.remove(friendId);
    }
    
    if (removed) {
      notifyListeners();
      AppLogger.debug('Friend $friendId removed from category $categoryId');
    }
  }

  Set<String> getFriendsInCategory(String categoryId) {
    return _friendCategoryRelationships.entries
        .where((entry) => entry.value.contains(categoryId))
        .map((entry) => entry.key)
        .toSet();
  }

  Set<String> getCategoriesForFriend(String friendId) {
    return _friendCategoryRelationships[friendId] ?? <String>{};
  }

  // ===== INVITATIONS STATE MANAGEMENT =====

  void addSentInvitation(GroupInvitation invitation) {
    if (!_sentInvitations.any((i) => i.id == invitation.id)) {
      _sentInvitations.add(invitation);
      notifyListeners();
      AppLogger.debug('Sent invitation added: ${invitation.id}');
    }
  }

  void updateSentInvitation(String invitationId, GroupInvitation invitation) {
    final index = _sentInvitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      _sentInvitations[index] = invitation;
      notifyListeners();
      AppLogger.debug('Sent invitation updated: $invitationId');
    }
  }

  GroupInvitation? getSentInvitationById(String invitationId) {
    try {
      return _sentInvitations.firstWhere((i) => i.id == invitationId);
    } catch (e) {
      return null;
    }
  }

  // ===== BLOCKED USERS STATE MANAGEMENT =====

  void addBlockedUser(String userId) {
    final wasAdded = _blockedUsers.add(userId);
    if (wasAdded) {
      notifyListeners();
      AppLogger.debug('User blocked: $userId');
    }
  }

  void removeBlockedUser(String userId) {
    final wasRemoved = _blockedUsers.remove(userId);
    if (wasRemoved) {
      notifyListeners();
      AppLogger.debug('User unblocked: $userId');
    }
  }

  bool isUserBlocked(String userId) {
    return _blockedUsers.contains(userId);
  }

  // ===== BULK STATE OPERATIONS =====

  void loadCachedState({
    required List<UserProfile> friends,
    required List<FriendRequest> incomingRequests,
    required List<FriendRequest> outgoingRequests,
    required List<FriendCategory> categories,
    required List<GroupInvitation> sentInvitations,
    required Set<String> blockedUsers,
    required Map<String, Set<String>> friendCategoryRelationships,
  }) {
    _friends.clear();
    _friends.addAll(friends);
    
    _incomingRequests.clear();
    _incomingRequests.addAll(incomingRequests);
    
    _outgoingRequests.clear();
    _outgoingRequests.addAll(outgoingRequests);
    
    _categories.clear();
    _categories.addAll(categories);
    
    _sentInvitations.clear();
    _sentInvitations.addAll(sentInvitations);
    
    _blockedUsers.clear();
    _blockedUsers.addAll(blockedUsers);
    
    _friendCategoryRelationships.clear();
    _friendCategoryRelationships.addAll(friendCategoryRelationships);
    
    notifyListeners();
    
    AppLogger.debug('✅ Cached state loaded: ${_friends.length} friends, ${_categories.length} categories');
  }

  void clearAll() {
    _friends.clear();
    _incomingRequests.clear();
    _outgoingRequests.clear();
    _categories.clear();
    _sentInvitations.clear();
    _blockedUsers.clear();
    _friendCategoryRelationships.clear();
    _isInitialized = false;
    _error = null;
    
    notifyListeners();
    
    AppLogger.debug('All friends state cleared');
  }

  // ===== INTERNAL ACCESS FOR OPERATIONS =====

  /// Internal getter for mutable friends list (for operations classes)
  List<UserProfile> get friendsInternal => _friends;

  /// Internal getter for mutable categories list (for operations classes)
  List<FriendCategory> get categoriesInternal => _categories;

  /// Internal getter for mutable relationships map (for operations classes)
  Map<String, Set<String>> get relationshipsInternal => _friendCategoryRelationships;

  /// Public method to trigger notifications (for internal operations)
  void triggerNotification() {
    notifyListeners();
  }
}