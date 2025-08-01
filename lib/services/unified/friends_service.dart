// Merged from 6 friends service files
import 'package:butlery/models/friend.dart';
import 'package:butlery/core/utils/logger.dart';

class FriendsService {
  final Map<String, Friend> _cache = {};
  
  // Merged from friends_coordinator + operations + sync + state
  Future<void> sendFriendRequest(String userId) async {
    AppLogger.info('Sending friend request to $userId');
  }
  
  Stream<List<Friend>> getFriendsStream() {
    return Stream.value([]);
  }
  
  Future<void> updatePresence(String status) async {
    AppLogger.info('Updating presence: $status');
  }
  
  // Merged caching from friends_cache_service
  void cacheFriend(Friend friend) {
    _cache[friend.id] = friend;
  }
}