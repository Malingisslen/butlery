import 'repository.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';

abstract class FriendsRepository extends Repository<UserProfile> {
  /// Send a friend request to another user
  Future<bool> sendFriendRequest(String toUserId, {String? message});

  /// Accept an incoming friend request
  Future<bool> acceptFriendRequest(String requestId);

  /// Reject an incoming friend request
  Future<bool> rejectFriendRequest(String requestId);

  /// Remove an existing friend
  Future<bool> removeFriend(String friendUserId);

  /// Get all incoming friend requests for current user
  Future<List<FriendRequest>> getIncomingRequests();

  /// Get all sent friend requests for current user
  Future<List<FriendRequest>> getSentRequests();

  /// Check if a pending request already exists between two users
  Future<bool> requestExists(String fromUserId, String toUserId);

  /// Check if two users are friends
  Future<bool> areFriends(String userId1, String userId2);

  /// Add both users to each other's friends lists
  Future<void> addMutualFriends(String userId1, String userId2);

  /// Remove users from each other's friends lists
  Future<void> removeMutualFriends(String userId1, String userId2);

  /// Fetch ids of all friends for a user
  Future<List<String>> fetchFriendIds(String userId);

  /// Fetch profiles for a set of user ids
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds);

  /// Cancel a previously sent friend request
  Future<bool> cancelFriendRequest(String requestId);
}
