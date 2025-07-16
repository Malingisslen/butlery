/// 🔍 AI INFO BLOCK:
/// Component: Friends Operations - Feature interface for basic friend management
/// File: lib/services/unified/operations/friends_operations.dart
/// Quick Guide: Handles core friend operations like requests, search, and CRUD
/// Dependencies IN: UnifiedFriendsService, UserProfile model
/// Dependencies OUT: Used by friends ViewModels for basic friend operations
/// Data flow: ViewModels -> FriendsOperations -> UnifiedFriendsService -> Firebase
/// State management: Delegates to parent UnifiedFriendsService
/// Purpose: Separate core friend concerns from categories and invitations
/// Common issues: Friend request state, search performance, permission validation
/// Test coverage: Unit tests for CRUD operations and search
/// Performance: Optimistic updates with Firebase sync
/// Analytics: Friend request events, search usage, friend interactions
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, Friends ViewModels
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/user_profile.dart';
import '../../../models/friend_request.dart';
import '../../../core/utils/logger.dart';

/// Friends operations feature interface
/// 
/// Handles all core friend management operations:
/// - Friend requests (send, accept, decline)
/// - Friend removal
/// - User search and discovery
/// - Friend list management
/// - Basic friend status checks
class FriendsOperations {
  final dynamic _parent; // UnifiedFriendsService

  FriendsOperations(this._parent);

  // ===== FRIEND REQUEST OPERATIONS =====

  /// Send friend request to user
  Future<bool> sendRequest(String userId) async {
    if (_parent.currentUserId == null) {
      AppLogger.warning('Cannot send friend request: User not logged in');
      return false;
    }

    if (userId == _parent.currentUserId) {
      AppLogger.warning('Cannot send friend request to yourself');
      return false;
    }

    if (isFriend(userId)) {
      AppLogger.warning('User is already a friend');
      return false;
    }

    return await _parent.sendFriendRequest(userId);
  }

  /// Accept incoming friend request
  Future<bool> acceptRequest(String requestId) async {
    final request = _parent.friendRequests
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      AppLogger.warning('Friend request not found: $requestId');
      return false;
    }

    if (request.toUserId != _parent.currentUserId) {
      AppLogger.warning('Cannot accept request not addressed to current user');
      return false;
    }

    return await _parent.acceptFriendRequest(requestId);
  }

  /// Decline incoming friend request
  Future<bool> declineRequest(String requestId) async {
    final request = _parent.friendRequests
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      AppLogger.warning('Friend request not found: $requestId');
      return false;
    }

    if (request.toUserId != _parent.currentUserId) {
      AppLogger.warning('Cannot decline request not addressed to current user');
      return false;
    }

    return await _parent.declineFriendRequest(requestId);
  }

  /// Cancel outgoing friend request
  Future<bool> cancelRequest(String requestId) async {
    final request = _parent.friendRequests
        .where((r) => r.id == requestId)
        .firstOrNull;

    if (request == null) {
      AppLogger.warning('Friend request not found: $requestId');
      return false;
    }

    if (request.fromUserId != _parent.currentUserId) {
      AppLogger.warning('Cannot cancel request not sent by current user');
      return false;
    }

    return await _parent.declineFriendRequest(requestId); // Same operation
  }

  // ===== FRIEND MANAGEMENT =====

  /// Remove friend from friend list
  Future<bool> removeFriend(String friendId) async {
    if (!isFriend(friendId)) {
      AppLogger.warning('User is not a friend: $friendId');
      return false;
    }

    return await _parent.removeFriend(friendId);
  }

  /// Block user (removes friendship and prevents new requests)
  Future<bool> blockUser(String userId) async {
    try {
      // First remove as friend if they are one
      if (isFriend(userId)) {
        await removeFriend(userId);
      }

      // Add to blocked users set
      _parent._blockedUsers.add(userId);
      
      // Remove any pending friend requests
      await _parent._removeAllRequestsWithUser(userId);
      
      // Save to Firebase
      await _parent._syncBlockedUsersToFirebase();
      
      // Notify listeners
      _parent.notifyListeners();
      
      AppLogger.success('Successfully blocked user: $userId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to block user: $e');
      return false;
    }
  }

  /// Unblock user
  Future<bool> unblockUser(String userId) async {
    try {
      // Remove from blocked users set
      final removed = _parent._blockedUsers.remove(userId);
      
      if (!removed) {
        AppLogger.warning('User was not blocked: $userId');
        return false;
      }
      
      // Save to Firebase
      await _parent._syncBlockedUsersToFirebase();
      
      // Notify listeners
      _parent.notifyListeners();
      
      AppLogger.success('Successfully unblocked user: $userId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to unblock user: $e');
      return false;
    }
  }

  // ===== USER SEARCH AND DISCOVERY =====

  /// Search for users by display name, email, or username
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    
    if (query.trim().length < 2) {
      AppLogger.warning('Search query too short, minimum 2 characters');
      return [];
    }

    try {
      final results = await _parent.searchUsers(query.trim());
      
      // Filter out current user and existing friends
      return results.where((user) => 
          user.uid != _parent.currentUserId && 
          !isFriend(user.uid)
      ).toList();
    } catch (e) {
      AppLogger.error('Error searching users', e);
      return [];
    }
  }

  /// Search for users by email (exact match)
  Future<UserProfile?> searchUserByEmail(String email) async {
    if (!_isValidEmail(email)) {
      AppLogger.warning('Invalid email format: $email');
      return null;
    }

    final results = await searchUsers(email);
    return results.where((user) => user.email == email).firstOrNull;
  }

  /// Get suggested friends (mutual friends, contacts, etc.)
  Future<List<UserProfile>> getSuggestedFriends() async {
    try {
      final suggestions = <UserProfile>[];
      final currentUserId = _parent.currentUserId;
      
      if (currentUserId == null) {
        return suggestions;
      }

      // Get mutual friends suggestions
      final mutualFriends = await _getMutualFriendsSuggestions(currentUserId);
      suggestions.addAll(mutualFriends);

      // Get suggestions from recent interactions
      final recentInteractions = await _getRecentInteractionsSuggestions(currentUserId);
      suggestions.addAll(recentInteractions);

      // Remove duplicates and filter out existing friends, blocked users, and pending requests
      final uniqueSuggestions = <String, UserProfile>{};
      for (final suggestion in suggestions) {
        if (!uniqueSuggestions.containsKey(suggestion.uid) &&
            !isFriend(suggestion.uid) &&
            !_parent._blockedUsers.contains(suggestion.uid) &&
            !hasPendingRequestTo(suggestion.uid) &&
            !hasPendingRequestFrom(suggestion.uid)) {
          uniqueSuggestions[suggestion.uid] = suggestion;
        }
      }

      final result = uniqueSuggestions.values.toList();
      AppLogger.info('Found ${result.length} friend suggestions');
      return result;
    } catch (e) {
      AppLogger.error('Error getting friend suggestions', e);
      return [];
    }
  }

  /// Get mutual friends suggestions
  Future<List<UserProfile>> _getMutualFriendsSuggestions(String currentUserId) async {
    try {
      final suggestions = <UserProfile>[];
      final myFriends = _parent.friendsList;
      
      // For each of my friends, get their friends
      for (final friend in myFriends) {
        try {
          // Get friend's friends (this would need to be implemented in the service)
          final friendsFriends = await _parent._getFriendsOfUser(friend.uid);
          
          // Add their friends as potential suggestions
          for (final friendOfFriend in friendsFriends) {
            if (friendOfFriend.uid != currentUserId && 
                !isFriend(friendOfFriend.uid)) {
              suggestions.add(friendOfFriend);
            }
          }
        } catch (e) {
          AppLogger.debug('Could not get friends for user ${friend.uid}: $e');
        }
      }
      
      return suggestions;
    } catch (e) {
      AppLogger.error('Error getting mutual friends suggestions', e);
      return [];
    }
  }

  /// Get suggestions from recent interactions
  Future<List<UserProfile>> _getRecentInteractionsSuggestions(String currentUserId) async {
    try {
      final suggestions = <UserProfile>[];
      
      // Get users from recent collaborative recipes
      final recentCollaborators = await _parent._getRecentCollaborators(currentUserId);
      suggestions.addAll(recentCollaborators);
      
      // Get users from recent shopping list collaborations
      final recentShoppingCollaborators = await _parent._getRecentShoppingCollaborators(currentUserId);
      suggestions.addAll(recentShoppingCollaborators);
      
      return suggestions;
    } catch (e) {
      AppLogger.error('Error getting recent interactions suggestions', e);
      return [];
    }
  }

  // ===== FRIEND STATUS CHECKS =====

  /// Check if user is a friend
  bool isFriend(String userId) {
    return _parent.friendsList.any((friend) => friend.uid == userId);
  }

  /// Check if there's a pending request to user
  bool hasPendingRequestTo(String userId) {
    return _parent.friendRequests.any((request) => 
        request.fromUserId == _parent.currentUserId && 
        request.toUserId == userId &&
        request.status == FriendRequestStatus.pending
    );
  }

  /// Check if there's a pending request from user
  bool hasPendingRequestFrom(String userId) {
    return _parent.friendRequests.any((request) => 
        request.fromUserId == userId && 
        request.toUserId == _parent.currentUserId &&
        request.status == FriendRequestStatus.pending
    );
  }

  /// Get relationship status with user
  FriendshipStatus getRelationshipStatus(String userId) {
    if (userId == _parent.currentUserId) {
      return FriendshipStatus.self;
    }
    
    if (isFriend(userId)) {
      return FriendshipStatus.friends;
    }
    
    if (hasPendingRequestTo(userId)) {
      return FriendshipStatus.requestSent;
    }
    
    if (hasPendingRequestFrom(userId)) {
      return FriendshipStatus.requestReceived;
    }
    
    return FriendshipStatus.none;
  }

  // ===== FRIEND DATA ACCESS =====

  /// Get friend by ID
  UserProfile? getFriendById(String friendId) {
    return _parent.friendsList
        .where((friend) => friend.uid == friendId)
        .firstOrNull;
  }

  /// Get all friends
  List<UserProfile> getAllFriends() {
    return _parent.friendsList;
  }

  /// Get incoming friend requests
  List<FriendRequest> getIncomingRequests() {
    return _parent.friendRequests
        .where((request) => 
            request.toUserId == _parent.currentUserId &&
            request.status == FriendRequestStatus.pending)
        .toList();
  }

  /// Get outgoing friend requests
  List<FriendRequest> getOutgoingRequests() {
    return _parent.friendRequests
        .where((request) => 
            request.fromUserId == _parent.currentUserId &&
            request.status == FriendRequestStatus.pending)
        .toList();
  }

  /// Get friends count
  int getFriendsCount() {
    return _parent.friendsList.length;
  }

  /// Get pending requests count
  int getPendingRequestsCount() {
    return getIncomingRequests().length;
  }

  // ===== PRIVATE HELPER METHODS =====

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

/// Friendship status between current user and another user
enum FriendshipStatus {
  none,           // No relationship
  friends,        // Are friends
  requestSent,    // Current user sent request to other user
  requestReceived,// Other user sent request to current user
  blocked,        // User is blocked
  self,           // Same user
}