// lib/services/unified/friends/friends_firebase_sync.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase synchronization operations for friends data.
/// Handles direct Firebase operations for friend requests, friend relationships,
/// and blocked users synchronization.
class FriendsFirebaseSyncOperations {
  final FirebaseFirestore firestore;
  final String? Function() getCurrentUserId;

  FriendsFirebaseSyncOperations({
    required this.firestore,
    required this.getCurrentUserId,
  });

  /// Sync friend request to Firebase
  Future<void> syncFriendRequestToFirebase(FriendRequest request) async {
    try {
      await firestore.collection(FirestoreCollections.friendRequests).add({
        'fromUserId': request.fromUserId,
        'toUserId': request.toUserId,
        'message': request.message,
        'sentAt': request.sentAt,
        'status': request.status.toString().split('.').last,
      });
      AppLogger.success('Synced friend request to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend request to Firebase', e);
      rethrow;
    }
  }

  /// Update friend request status in Firebase
  Future<void> updateFriendRequestStatus(FriendRequest request) async {
    try {
      final querySnapshot = await firestore
          .collection(FirestoreCollections.friendRequests)
          .where('fromUserId', isEqualTo: request.fromUserId)
          .where('toUserId', isEqualTo: request.toUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'status': request.status.toString().split('.').last,
          'respondedAt': request.respondedAt ?? DateTime.now(),
        });
        AppLogger.success('Updated friend request status in Firebase');
      }
    } catch (e) {
      AppLogger.error('Failed to update friend request status', e);
      rethrow;
    }
  }

  /// Sync friend to Firebase
  /// ⚠️ ULTRATHINK WARNING: This method should NOT be used for friend request acceptance!
  /// Use FriendRelationshipRepository.addMutualFriends() instead, which properly handles:
  /// - Atomic operations, counter updates, and consistent field structures
  /// This method uses different field names and doesn't update friendsCount
  Future<void> syncFriendToFirebase(UserProfile friend) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return;

      // Add to friends subcollection
      await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends)
          .doc(friend.uid)
          .set({
        'friendSince': DateTime.now(),
        'displayName': friend.displayName,
      });

      // Also add reverse relationship
      await firestore
          .collection(FirestoreCollections.users)
          .doc(friend.uid)
          .collection(FirestoreCollections.userFriends)
          .doc(userId)
          .set({
        'friendSince': DateTime.now(),
      });

      AppLogger.success('Synced friend to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend to Firebase', e);
      rethrow;
    }
  }

  /// Remove friend from Firebase
  Future<void> removeFriendFromFirebase(String friendId) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return;

      // Remove from friends subcollection
      await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends)
          .doc(friendId)
          .delete();

      // Also remove reverse relationship
      await firestore
          .collection(FirestoreCollections.users)
          .doc(friendId)
          .collection(FirestoreCollections.userFriends)
          .doc(userId)
          .delete();

      AppLogger.success('Removed friend from Firebase');
    } catch (e) {
      AppLogger.error('Failed to remove friend from Firebase', e);
      rethrow;
    }
  }
}
