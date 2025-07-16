/// 🔍 AI INFO BLOCK:
/// Component: Friends Management Operations - Feature interface for friend management
/// File: lib/services/unified/operations/friends_management_operations.dart
/// Quick Guide: Handles all friend-related operations including invitations and relationships
/// Dependencies IN: UnifiedFriendsService, FriendRequest model, User model
/// Dependencies OUT: Used by ViewModels for friend operations
/// Data flow: ViewModels -> FriendsManagementOperations -> UnifiedFriendsService -> Firebase
/// State management: Real-time updates for friend requests and relationships
/// Purpose: Separate friend management concerns from unified service
/// Common issues: Friend request validation, duplicate prevention, permission checks
/// Test coverage: Unit tests for friend operations and request handling
/// Performance: Real-time updates with optimistic UI updates
/// Analytics: Friend activity, invitation success rates
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, Social ViewModels, User management
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/friend_request.dart';
import '../../../models/user_profile.dart';
import '../../../core/utils/logger.dart';

/// Friends management operations feature interface
/// 
/// Handles all operations related to friend management:
/// - Sending and managing friend requests
/// - Accepting/rejecting friend requests
/// - Managing friend relationships
/// - Blocking and unblocking users
/// - Friend search and discovery
class FriendsManagementOperations {
  final dynamic _parent; // UnifiedFriendsService

  FriendsManagementOperations(this._parent);

  // ===== FRIEND REQUEST MANAGEMENT =====

  /// Send a friend request to another user
  Future<bool> sendFriendRequest(String recipientId, {String? message}) async {
    // For now, use recipientId as display name until we can fetch user profile
    final recipientDisplayName = 'User ${recipientId.substring(0, 6)}...';
    try {
      if (_parent.currentUserId == null) {
        AppLogger.error('Cannot send friend request: User not authenticated');
        return false;
      }

      if (recipientId == _parent.currentUserId) {
        AppLogger.error('Cannot send friend request to yourself');
        return false;
      }

      // Check if already friends
      if (isFriend(recipientId)) {
        AppLogger.warning('Already friends with this user');
        return false;
      }

      // Check if request already exists
      if (hasOutgoingRequest(recipientId)) {
        AppLogger.warning('Friend request already sent to this user');
        return false;
      }

      // Check if there's an incoming request from this user
      if (hasIncomingRequest(recipientId)) {
        AppLogger.warning('This user has already sent you a friend request');
        return false;
      }

      final currentUserId = _parent.currentUserId;
      final currentUserDisplayName = _parent.currentUserDisplayName;
      
      if (currentUserId == null || currentUserDisplayName == null) {
        AppLogger.error('Cannot send friend request: User information not available');
        return false;
      }
      
      final request = FriendRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fromUserId: currentUserId,
        toUserId: recipientId,
        message: message,
        sentAt: DateTime.now(),
        status: FriendRequestStatus.pending,
      );

      // Add to local state (optimistic update)
      _parent._outgoingRequests.add(request);
      _parent._notifyListeners();

      // Send to Firebase
      await _parent._syncFriendRequestToFirebase(request);

      AppLogger.success('Friend request sent to $recipientDisplayName');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send friend request', e);
      return false;
    }
  }

  /// Accept an incoming friend request
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final request = _parent._incomingRequests
          .where((r) => r.id == requestId)
          .firstOrNull;

      if (request == null) {
        AppLogger.error('Friend request not found');
        return false;
      }

      // Update request status
      final acceptedRequest = request.copyWith(
        status: FriendRequestStatus.accepted,
        respondedAt: DateTime.now(),
      );

      // Add as friend
      final friend = UserProfile(
        uid: request.fromUserId,
        displayName: 'User ${request.fromUserId.substring(0, 6)}...', // Would be fetched from user profile
        email: '', // Would be fetched from user profile
        avatarUrl: null, // Would be fetched from user profile
        bio: null,
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

      // Update local state
      _parent._friends.add(friend);
      _parent._incomingRequests.removeWhere((r) => r.id == requestId);
      _parent._notifyListeners();

      // Sync to Firebase
      await _parent._syncFriendToFirebase(friend);
      await _parent._updateFriendRequestStatus(acceptedRequest);

      AppLogger.success('Friend request accepted from ${request.fromUserId}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to accept friend request', e);
      return false;
    }
  }

  /// Reject an incoming friend request
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      final request = _parent._incomingRequests
          .where((r) => r.id == requestId)
          .firstOrNull;

      if (request == null) {
        AppLogger.error('Friend request not found');
        return false;
      }

      // Update request status
      final rejectedRequest = request.copyWith(
        status: FriendRequestStatus.rejected,
        respondedAt: DateTime.now(),
      );

      // Remove from local state
      _parent._incomingRequests.removeWhere((r) => r.id == requestId);
      _parent._notifyListeners();

      // Update in Firebase
      await _parent._updateFriendRequestStatus(rejectedRequest);

      AppLogger.success('Friend request rejected from ${request.fromUserId}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to reject friend request', e);
      return false;
    }
  }

  /// Cancel an outgoing friend request
  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      final request = _parent._outgoingRequests
          .where((r) => r.id == requestId)
          .firstOrNull;

      if (request == null) {
        AppLogger.error('Friend request not found');
        return false;
      }

      // Update request status
      final cancelledRequest = request.copyWith(
        status: FriendRequestStatus.cancelled,
        respondedAt: DateTime.now(),
      );

      // Remove from local state
      _parent._outgoingRequests.removeWhere((r) => r.id == requestId);
      _parent._notifyListeners();

      // Update in Firebase
      await _parent._updateFriendRequestStatus(cancelledRequest);

      AppLogger.success('Friend request cancelled to ${request.toUserId}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to cancel friend request', e);
      return false;
    }
  }

  // ===== FRIEND RELATIONSHIP MANAGEMENT =====

  /// Remove a friend
  Future<bool> removeFriend(String friendId) async {
    try {
      final friend = _parent._friends
          .where((f) => f.uid == friendId)
          .firstOrNull;

      if (friend == null) {
        AppLogger.error('Friend not found');
        return false;
      }

      // Remove from local state
      _parent._friends.removeWhere((f) => f.uid == friendId);
      _parent._notifyListeners();

      // Remove from Firebase
      await _parent._removeFriendFromFirebase(friendId);

      AppLogger.success('Removed friend: ${friend.displayName}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove friend', e);
      return false;
    }
  }

  /// Block a user
  Future<bool> blockUser(String userId) async {
    try {
      // Remove from friends if they are friends
      if (isFriend(userId)) {
        await removeFriend(userId);
      }

      // Remove any pending friend requests
      _parent._incomingRequests.removeWhere((r) => r.fromUserId == userId);
      _parent._outgoingRequests.removeWhere((r) => r.toUserId == userId);

      // Add to blocked users
      _parent._blockedUsers.add(userId);
      _parent._notifyListeners();

      // Sync to Firebase
      await _parent._syncBlockedUsersToFirebase();

      AppLogger.success('User blocked');
      return true;
    } catch (e) {
      AppLogger.error('Failed to block user', e);
      return false;
    }
  }

  /// Unblock a user
  Future<bool> unblockUser(String userId) async {
    try {
      // Remove from blocked users
      _parent._blockedUsers.remove(userId);
      _parent._notifyListeners();

      // Sync to Firebase
      await _parent._syncBlockedUsersToFirebase();

      AppLogger.success('User unblocked');
      return true;
    } catch (e) {
      AppLogger.error('Failed to unblock user', e);
      return false;
    }
  }

  // ===== FRIEND QUERIES =====

  /// Get all friends
  List<UserProfile> getAllFriends() {
    return List.unmodifiable(_parent._friends);
  }

  /// Get friend by ID
  UserProfile? getFriendById(String friendId) {
    return _parent._friends.where((f) => f.uid == friendId).firstOrNull;
  }

  /// Check if user is a friend
  bool isFriend(String userId) {
    return _parent._friends.any((f) => f.uid == userId);
  }

  /// Get online friends
  List<UserProfile> getOnlineFriends() {
    // UserProfile doesn't have isOnline property, so return all friends for now
    return _parent._friends.toList();
  }

  /// Get friends by category
  List<UserProfile> getFriendsByCategory(String category) {
    // This would need to be implemented with category relationships
    return _parent._friends.toList();
  }

  /// Search friends by name
  List<UserProfile> searchFriends(String query) {
    final searchTerm = query.toLowerCase();
    return _parent._friends
        .where((f) => f.displayName.toLowerCase().contains(searchTerm))
        .toList();
  }
  
  /// Search users (for adding as friends)
  Future<List<UserProfile>> searchUsers(String query) async {
    try {
      // This would search the users collection in Firebase
      // For now, return empty list
      AppLogger.info('Searching users with query: $query');
      return [];
    } catch (e) {
      AppLogger.error('Failed to search users', e);
      return [];
    }
  }

  /// Get incoming friend requests
  List<FriendRequest> getIncomingRequests() {
    return List.unmodifiable(_parent._incomingRequests);
  }

  /// Get outgoing friend requests
  List<FriendRequest> getOutgoingRequests() {
    return List.unmodifiable(_parent._outgoingRequests);
  }

  /// Check if there's an outgoing request to user
  bool hasOutgoingRequest(String userId) {
    return _parent._outgoingRequests.any((r) => 
        r.toUserId == userId && r.status == FriendRequestStatus.pending);
  }

  /// Check if there's an incoming request from user
  bool hasIncomingRequest(String userId) {
    return _parent._incomingRequests.any((r) => 
        r.fromUserId == userId && r.status == FriendRequestStatus.pending);
  }

  /// Get friend request count
  int getIncomingRequestCount() {
    return _parent._incomingRequests.length;
  }

  /// Check if user is blocked
  bool isBlocked(String userId) {
    return _parent._blockedUsers.contains(userId);
  }

  /// Get blocked users
  List<String> getBlockedUsers() {
    return List.unmodifiable(_parent._blockedUsers);
  }

  // ===== FRIEND STATISTICS =====

  /// Get friend statistics
  Map<String, dynamic> getFriendStats() {
    final totalFriends = _parent._friends.length;
    final onlineFriends = 0; // UserProfile doesn't have isOnline property
    final categoryCounts = <String, int>{};

    return {
      'totalFriends': totalFriends,
      'onlineFriends': onlineFriends,
      'offlineFriends': totalFriends - onlineFriends,
      'incomingRequests': _parent._incomingRequests.length,
      'outgoingRequests': _parent._outgoingRequests.length,
      'blockedUsers': _parent._blockedUsers.length,
      'categoryCounts': categoryCounts,
    };
  }

  /// Get mutual friends with another user
  Future<List<UserProfile>> getMutualFriends(String userId) async {
    try {
      // This would query Firebase for mutual friends
      // For now, return empty list
      return [];
    } catch (e) {
      AppLogger.error('Failed to get mutual friends', e);
      return [];
    }
  }
}