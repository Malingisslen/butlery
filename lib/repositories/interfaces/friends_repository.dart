import '../repository.dart';
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
}
