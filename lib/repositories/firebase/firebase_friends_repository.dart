// lib/repositories/firebase/firebase_friends_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/auth_repository.dart';
import 'firebase_auth_repository.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';
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
}

