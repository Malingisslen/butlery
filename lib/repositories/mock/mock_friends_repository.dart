import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/mock/in_memory_repository.dart';

/// In-memory implementation of [FriendsRepository] for tests.
class MockFriendsRepository extends InMemoryRepository<UserProfile>
    implements FriendsRepository {
  MockFriendsRepository({required this.currentUserId}) : super((p) => p.uid);

  final String currentUserId;

  final Map<String, Set<String>> _friends = {};
  final Map<String, List<FriendRequest>> _incoming = {};
  final Map<String, List<FriendRequest>> _sent = {};
  final Map<String, Map<String, FriendCategory>> _categories = {};
  final Map<String, GroupInvitation> _invitations = {};

  Map<String, FriendCategory> _categoryMap(String userId) =>
      _categories.putIfAbsent(userId, () => <String, FriendCategory>{});

  Iterable<GroupInvitation> _receivedInvitations(String userId) =>
      _invitations.values.where((i) => i.toUserId == userId);

  Iterable<GroupInvitation> _sentInvitations(String userId) =>
      _invitations.values.where((i) => i.fromUserId == userId);

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

  // ===== Category methods =====

  @override
  Future<void> saveCategory(String userId, FriendCategory category) async {
    _categoryMap(userId)[category.id] = category;
  }

  @override
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data) async {
    final map = _categoryMap(userId);
    final existing = map[categoryId];
    if (existing != null) {
      map[categoryId] = existing.copyWith(
        name: data['name'] as String?,
        description: data['description'] as String?,
        emoji: data['emoji'] as String?,
        friendUserIds:
            (data['friendUserIds'] as List?)?.cast<String>() ?? existing.friendUserIds,
        sortOrder: data['sortOrder'] as int?,
      );
    }
  }

  @override
  Future<void> deleteCategory(String userId, String categoryId) async {
    _categoryMap(userId).remove(categoryId);
  }

  @override
  Future<List<FriendCategory>> fetchCategories(String userId) async {
    return _categoryMap(userId).values.toList();
  }

  @override
  Future<void> createCategoryForUser(String userId, FriendCategory category) async {
    await saveCategory(userId, category);
  }

  @override
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds) async {
    final map = _categoryMap(userId);
    final existing = map[categoryId];
    if (existing != null) {
      map[categoryId] = existing.copyWith(friendUserIds: memberIds);
    }
  }

  @override
  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    return _categoryMap(userId)[categoryId];
  }

  // ===== Invitation methods =====

  @override
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) async* {
    yield _receivedInvitations(userId).toList();
  }

  @override
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) async* {
    yield _sentInvitations(userId).toList();
  }

  @override
  Future<GroupInvitation?> getInvitation(String invitationId) async {
    return _invitations[invitationId];
  }

  @override
  Future<void> saveInvitation(GroupInvitation invitation) async {
    _invitations[invitation.id] = invitation;
  }

  @override
  Future<void> updateInvitation(
      String invitationId, Map<String, dynamic> data) async {
    final existing = _invitations[invitationId];
    if (existing != null) {
      _invitations[invitationId] = existing.copyWith(
        status: data['status'] != null
            ? GroupInvitationStatus.values.firstWhere(
                (e) => e.name == data['status'],
                orElse: () => existing.status,
              )
            : existing.status,
        respondedAt: data['respondedAt'] as DateTime? ?? existing.respondedAt,
      );
    }
  }

  @override
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now) async {
    // Not used in mock - return empty list
    return [];
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate) async {
    // Not used in mock - return empty list
    return [];
  }

  @override
  Future<void> deleteDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    // no-op in mock
  }

  @override
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data) async {
    // no-op in mock
  }

  @override
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    return _invitations.values.any((i) =>
        i.groupId == groupId &&
        i.toUserId == toUserId &&
        i.status == GroupInvitationStatus.pending);
  }
}
