import '../interfaces/friends_repository.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';
import 'in_memory_repository.dart';

/// In-memory implementation of [FriendsRepository] for tests.
class MockFriendsRepository extends InMemoryRepository<UserProfile>
    implements FriendsRepository {
  MockFriendsRepository({required this.currentUserId}) : super((p) => p.uid);

  final String currentUserId;

  final Map<String, Set<String>> _friends = {};
  final Map<String, List<FriendRequest>> _incoming = {};
  final Map<String, List<FriendRequest>> _sent = {};

  Set<String> _friendSet(String userId) =>
      _friends.putIfAbsent(userId, () => <String>{});
  List<FriendRequest> _incomingList(String userId) =>
      _incoming.putIfAbsent(userId, () => <FriendRequest>[]);
  List<FriendRequest> _sentList(String userId) =>
      _sent.putIfAbsent(userId, () => <FriendRequest>[]);

  FriendRequest? _findRequest(String id) {
    for (final list in _incoming.values) {
      for (final r in list) {
        if (r.id == id) return r;
      }
    }
    return null;
  }

  void _replaceRequest(FriendRequest request) {
    final incoming = _incomingList(request.toUserId);
    final sent = _sentList(request.fromUserId);
    for (var i = 0; i < incoming.length; i++) {
      if (incoming[i].id == request.id) incoming[i] = request;
    }
    for (var i = 0; i < sent.length; i++) {
      if (sent[i].id == request.id) sent[i] = request;
    }
  }

  @override
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    final request = FriendRequest.create(
      fromUserId: currentUserId,
      toUserId: toUserId,
      message: message,
    );
    _incomingList(toUserId).add(request);
    _sentList(currentUserId).add(request);
    return true;
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    final req = _findRequest(requestId);
    if (req == null) return false;
    final updated = req.accept();
    _replaceRequest(updated);
    _friendSet(req.fromUserId).add(req.toUserId);
    _friendSet(req.toUserId).add(req.fromUserId);
    return true;
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    final req = _findRequest(requestId);
    if (req == null) return false;
    _replaceRequest(req.reject());
    return true;
  }

  @override
  Future<bool> removeFriend(String friendUserId) async {
    _friendSet(currentUserId).remove(friendUserId);
    _friendSet(friendUserId).remove(currentUserId);
    return true;
  }

  @override
  Future<List<FriendRequest>> getIncomingRequests() async =>
      List.unmodifiable(_incomingList(currentUserId));

  @override
  Future<List<FriendRequest>> getSentRequests() async =>
      List.unmodifiable(_sentList(currentUserId));

  @override
  Future<bool> requestExists(String fromUserId, String toUserId) async {
    return _sentList(fromUserId)
        .any((r) => r.toUserId == toUserId && r.isPending);
  }

  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    return _friendSet(userId1).contains(userId2);
  }

  @override
  Future<void> addMutualFriends(String userId1, String userId2) async {
    _friendSet(userId1).add(userId2);
    _friendSet(userId2).add(userId1);
  }

  @override
  Future<void> removeMutualFriends(String userId1, String userId2) async {
    _friendSet(userId1).remove(userId2);
    _friendSet(userId2).remove(userId1);
  }

  @override
  Future<List<String>> fetchFriendIds(String userId) async {
    return List.unmodifiable(_friendSet(userId));
  }

  @override
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds) async {
    return [
      for (final id in userIds)
        if (items.containsKey(id)) items[id]!
    ];
  }

  @override
  Future<bool> cancelFriendRequest(String requestId) async {
    final req = _findRequest(requestId);
    if (req == null) return false;
    _replaceRequest(req.cancel());
    return true;
  }
}
