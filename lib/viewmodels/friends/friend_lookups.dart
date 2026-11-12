import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Friendship status between current user and another user
enum FriendshipStatus { none, friends, requestSent, requestReceived, blocked }

/// Read-only questions about friends and groups, answered from the service.
class FriendLookups {
  final UnifiedFriendsService _friendsService;

  FriendLookups(this._friendsService);

  /// Get friends in a specific group.
  List<UserProfile> getFriendsInGroup(String groupId) {
    return _friendsService.categories.getFriendsInCategory(groupId);
  }

  /// Check if group name is available.
  bool isGroupNameAvailable(String name) {
    return _friendsService.categories.getCategoryByName(name) == null;
  }

  /// Get groups for a specific friend.
  List<FriendCategory> getGroupsForFriend(String friendUserId) {
    return _friendsService.categories.getCategoriesForFriend(friendUserId);
  }

  /// Search groups.
  List<FriendCategory> searchGroups(String query) {
    if (query.trim().isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    return _friendsService.categoriesList
        .where((category) => category.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Get relationship status with user.
  ///
  /// The order below is load-bearing and is NOT the safety answer: `friends`
  /// / `requestSent` / `requestReceived` are all tested before `blocked`, so
  /// during (or after a failed) block cleanup this returns `friends` about
  /// someone who is blocked. Surfaces that gate on blocking call [isBlocked]
  /// instead. Deliberately left as it is — it has other callers whose
  /// meaning depends on this precedence (BUT-2022).
  FriendshipStatus getFriendshipStatus(String userId) {
    // Check if user is already a friend
    if (_friendsService.friends.any((friend) => friend.uid == userId)) {
      return FriendshipStatus.friends;
    }

    // Check if there's an outgoing request
    if (_friendsService.outgoingRequests.any(
      (request) => request.toUserId == userId,
    )) {
      return FriendshipStatus.requestSent;
    }

    // Check if there's an incoming request
    if (_friendsService.incomingRequests.any(
      (request) => request.fromUserId == userId,
    )) {
      return FriendshipStatus.requestReceived;
    }

    // Check if user is blocked
    if (_friendsService.blockedUsers.contains(userId)) {
      return FriendshipStatus.blocked;
    }

    return FriendshipStatus.none;
  }
}
