// lib/repositories/firebase/firebase_friends_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../models/friend_request.dart';

/// Repository handling friend requests and friends collections in Firestore.
class FirebaseFriendsRepository {
  FirebaseFriendsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _friendRequestsRef =>
      _firestore.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> _userFriendsRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('friends');

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _firestore.collection('public_profiles');

  /// Send a new friend request.
  Future<void> sendRequest(FriendRequest request) async {
    await _friendRequestsRef.doc(request.id).set(request.toFirestore());
  }

  /// Update an existing friend request document.
  Future<void> updateRequest(FriendRequest request) async {
    await _friendRequestsRef.doc(request.id).update(request.toFirestore());
  }

  /// Fetch a friend request by id.
  Future<FriendRequest?> fetchRequest(String requestId) async {
    final doc = await _friendRequestsRef.doc(requestId).get();
    if (!doc.exists) return null;
    return FriendRequest.fromFirestore(doc);
  }

  /// Check if a pending request already exists between two users.
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
  Future<bool> areFriends(String userId1, String userId2) async {
    final doc = await _userFriendsRef(userId1).doc(userId2).get();
    return doc.exists;
  }

  /// Add users to each other's friends collections and update counts.
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

  /// Retrieve friend ids for a user.
  Future<List<String>> fetchFriendIds(String userId) async {
    final snapshot = await _userFriendsRef(userId).get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  /// Retrieve user profiles for a list of ids.
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

