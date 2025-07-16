// lib/repositories/firebase/firebase_friends_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import 'firebase_auth_repository.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';
import '../../models/friend_category.dart';
import '../../models/group_invitation.dart';
import '../interfaces/friends_repository.dart';

/// Repository handling friend requests and friends collections in Firestore.
class FirebaseFriendsRepository implements FriendsRepository {
  FirebaseFriendsRepository({
    FirebaseFirestore? firestore,
    AuthRepository? authRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository ?? FirebaseAuthRepository();

  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  CollectionReference<Map<String, dynamic>> get _friendRequestsRef =>
      _firestore.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> _userFriendsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('friends');

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _firestore.collection('public_profiles');

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('friendCategories');

  CollectionReference<Map<String, dynamic>> get _invitationsRef =>
      _firestore.collection('group_invitations');

  @override
  Future<UserProfile> create(UserProfile profile) async {
    await _profilesRef.doc(profile.uid).set(profile.toFirestore());
    return profile;
  }

  @override
  Future<UserProfile?> read(String id) async {
    final doc = await _profilesRef.doc(id).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  @override
  Future<List<UserProfile>> readAll() async {
    final snap = await _profilesRef.get();
    return snap.docs.map(UserProfile.fromFirestore).toList();
  }

  @override
  Future<void> update(UserProfile profile) async {
    await _profilesRef.doc(profile.uid).update(profile.toFirestore());
  }

  @override
  Future<void> delete(String id) async {
    await _profilesRef.doc(id).delete();
  }

  /// Send a new friend request.
  Future<void> sendRequest(FriendRequest request) async {
    await _friendRequestsRef.doc(request.id).set(request.toFirestore());
  }

  @override
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    final fromId = _authRepository.currentUserId;
    if (fromId == null) return false;
    final exists = await requestExists(fromId, toUserId);
    if (exists) return false;
    final request = FriendRequest.create(
      fromUserId: fromId,
      toUserId: toUserId,
      message: message,
    );
    await sendRequest(request);
    return true;
  }

  /// Update an existing friend request document.
  Future<void> updateRequest(FriendRequest request) async {
    await _friendRequestsRef.doc(request.id).update(request.toFirestore());
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;
    await updateRequest(req.accept());
    await addMutualFriends(req.fromUserId, req.toUserId);
    return true;
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;
    await updateRequest(req.reject());
    return true;
  }

  @override
  Future<bool> cancelFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;
    await updateRequest(req.cancel());
    return true;
  }

  /// Fetch a friend request by id.
  Future<FriendRequest?> fetchRequest(String requestId) async {
    final doc = await _friendRequestsRef.doc(requestId).get();
    if (!doc.exists) return null;
    return FriendRequest.fromFirestore(doc);
  }

  /// Check if a pending request already exists between two users.
  @override
  Future<bool> requestExists(String fromUserId, String toUserId) async {
    final query = await _friendRequestsRef
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Check if users are already friends.
  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    final doc = await _userFriendsRef(userId1).doc(userId2).get();
    return doc.exists;
  }

  /// Add users to each other's friends collections and update counts.
  @override
  Future<void> addMutualFriends(String userId1, String userId2) async {
    final batch = _firestore.batch();

    final user1Ref = _userFriendsRef(userId1).doc(userId2);
    final user2Ref = _userFriendsRef(userId2).doc(userId1);

    batch.set(user1Ref, {'addedAt': FieldValue.serverTimestamp()});
    batch.set(user2Ref, {'addedAt': FieldValue.serverTimestamp()});

    final user1Profile = _profilesRef.doc(userId1);
    final user2Profile = _profilesRef.doc(userId2);
    batch.update(user1Profile, {'friendsCount': FieldValue.increment(1)});
    batch.update(user2Profile, {'friendsCount': FieldValue.increment(1)});

    await batch.commit();
  }

  /// Remove users from each other's friends collections and update counts.
  @override
  Future<void> removeMutualFriends(String userId1, String userId2) async {
    final batch = _firestore.batch();

    final user1Ref = _userFriendsRef(userId1).doc(userId2);
    final user2Ref = _userFriendsRef(userId2).doc(userId1);

    batch.delete(user1Ref);
    batch.delete(user2Ref);

    final user1Profile = _profilesRef.doc(userId1);
    final user2Profile = _profilesRef.doc(userId2);
    batch.update(user1Profile, {'friendsCount': FieldValue.increment(-1)});
    batch.update(user2Profile, {'friendsCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  @override
  Future<bool> removeFriend(String friendUserId) async {
    final current = _authRepository.currentUserId;
    if (current == null) return false;
    await removeMutualFriends(current, friendUserId);
    return true;
  }

  /// Retrieve friend ids for a user.
  @override
  Future<List<String>> fetchFriendIds(String userId) async {
    final snapshot = await _userFriendsRef(userId).get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  @override
  Future<List<FriendRequest>> getIncomingRequests() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return [];
    final snap = await _friendRequestsRef
        .where('toUserId', isEqualTo: uid)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .get();
    return snap.docs.map(FriendRequest.fromFirestore).toList();
  }

  @override
  Future<List<FriendRequest>> getSentRequests() async {
    final uid = _authRepository.currentUserId;
    if (uid == null) return [];
    final snap = await _friendRequestsRef
        .where('fromUserId', isEqualTo: uid)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .get();
    return snap.docs.map(FriendRequest.fromFirestore).toList();
  }

  /// Retrieve user profiles for a list of ids.
  @override
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    const batchSize = 10;
    final profiles = <UserProfile>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      final query = await _profilesRef
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in query.docs) {
        profiles.add(UserProfile.fromFirestore(doc));
      }
    }
    return profiles;
  }

  /// Stream incoming friend requests for the current user.
  Stream<List<FriendRequest>> incomingRequestsStream(String userId) {
    return _friendRequestsRef
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(FriendRequest.fromFirestore).toList());
  }

  /// Stream sent friend requests for the current user.
  Stream<List<FriendRequest>> sentRequestsStream(String userId) {
    return _friendRequestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(FriendRequest.fromFirestore).toList());
  }

  // ===== Category methods =====

  @override
  Future<void> saveCategory(String userId, FriendCategory category) {
    return _categoriesRef(userId).doc(category.id).set(category.toFirestore());
  }

  @override
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data) {
    return _categoriesRef(userId).doc(categoryId).update(data);
  }

  @override
  Future<void> deleteCategory(String userId, String categoryId) {
    return _categoriesRef(userId).doc(categoryId).delete();
  }

  @override
  Future<List<FriendCategory>> fetchCategories(String userId) async {
    final snap = await _categoriesRef(userId).get();
    return snap.docs.map(FriendCategory.fromFirestore).toList();
  }

  @override
  Future<void> createCategoryForUser(String userId, FriendCategory category) {
    return _categoriesRef(userId).doc(category.id).set(category.toFirestore());
  }

  @override
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds) {
    return _categoriesRef(userId).doc(categoryId).update({
      'friendUserIds': memberIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    final doc = await _categoriesRef(userId).doc(categoryId).get();
    if (!doc.exists) return null;
    return FriendCategory.fromFirestore(doc);
  }

  // ===== Invitation methods =====

  @override
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GroupInvitation.fromFirestore).toList());
  }

  @override
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _invitationsRef
        .where('fromUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(GroupInvitation.fromFirestore).toList());
  }

  @override
  Future<GroupInvitation?> getInvitation(String invitationId) async {
    final doc = await _invitationsRef.doc(invitationId).get();
    if (!doc.exists) return null;
    return GroupInvitation.fromFirestore(doc);
  }

  @override
  Future<void> saveInvitation(GroupInvitation invitation) {
    return _invitationsRef.doc(invitation.id).set(invitation.toFirestore());
  }

  @override
  Future<void> updateInvitation(
      String invitationId, Map<String, dynamic> data) {
    return _invitationsRef.doc(invitationId).update(data);
  }

  @override
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now) async {
    final query = await _invitationsRef
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .where('expiresAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();
    return query.docs.map((d) => d.reference).toList();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate) async {
    final query = await _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .where('sentAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    return query.docs;
  }

  @override
  Future<void> deleteDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    final batch = _firestore.batch();
    for (final ref in refs) {
      batch.delete(ref);
    }
    await batch.commit();
  }

  @override
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data) async {
    final batch = _firestore.batch();
    for (final ref in refs) {
      batch.update(ref, data);
    }
    await batch.commit();
  }

  @override
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    final query = await _invitationsRef
        .where('groupId', isEqualTo: groupId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }
}

