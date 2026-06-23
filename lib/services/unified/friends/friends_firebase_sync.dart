// lib/services/unified/friends/friends_firebase_sync.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

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
      await firestore.collection(FirestoreCollections.socialRequests).add({
        'type': 'friend',
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

  /// Update friend request status in Firebase.
  /// For cancellation (by sender), uses delete since Firestore rules only
  /// allow the recipient to update status. The delete rule permits both parties.
  Future<void> updateFriendRequestStatus(FriendRequest request) async {
    try {
      final querySnapshot = await firestore
          .collection(FirestoreCollections.socialRequests)
          .where('fromUserId', isEqualTo: request.fromUserId)
          .where('toUserId', isEqualTo: request.toUserId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        if (request.status == FriendRequestStatus.cancelled) {
          // Sender cancellation: delete the doc (Firestore rules block sender updates)
          await querySnapshot.docs.first.reference.delete();
          AppLogger.success('Deleted cancelled friend request from Firebase');
        } else {
          // Recipient accept/reject: update normally
          await querySnapshot.docs.first.reference.update({
            'status': request.status.toString().split('.').last,
            'respondedAt': request.respondedAt ?? clock.now(),
          });
          AppLogger.success('Updated friend request status in Firebase');
        }
      }
    } catch (e) {
      AppLogger.error('Failed to update friend request status', e);
      rethrow;
    }
  }

  /// Sync friend to Firebase
  /// WARNING: Do not use for friend request acceptance.
  /// Use FriendRelationshipRepository.addMutualFriends() instead, which properly handles
  /// atomic operations, counter updates, and consistent field structures.
  /// This method uses different field names and doesn't update friendsCount.
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
            'friendSince': clock.now(),
            'displayName': friend.displayName,
            'displayNameLower': friend.displayName.toLowerCase(),
          });

      // Also add reverse relationship
      await firestore
          .collection(FirestoreCollections.users)
          .doc(friend.uid)
          .collection(FirestoreCollections.userFriends)
          .doc(userId)
          .set({
            'friendSince': clock.now(),
          });

      AppLogger.success('Synced friend to Firebase');
    } catch (e) {
      AppLogger.error('Failed to sync friend to Firebase', e);
      rethrow;
    }
  }

  /// Backfill displayNameLower for legacy friend docs missing the field.
  /// Gated by a per-user migration flag to run only once.
  Future<void> backfillDisplayNameLower(String userId) async {
    try {
      // Check migration flag
      final migrationDoc = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userRateLimits)
          .doc('friendSearchMigrated')
          .get();

      if (migrationDoc.exists) return;

      final friendsSnapshot = await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends)
          .get();

      final docsToUpdate = friendsSnapshot.docs
          .where((doc) => doc.data()['displayNameLower'] == null)
          .toList();

      if (docsToUpdate.isNotEmpty) {
        var batch = firestore.batch();
        var opCount = 0;

        for (final doc in docsToUpdate) {
          final displayName = doc.data()['displayName'] as String?;
          if (displayName != null) {
            batch.update(doc.reference, {
              'displayNameLower': displayName.toLowerCase(),
            });
            opCount++;
            if (opCount >= kFirestoreBatchSafeChunkSize) {
              await batch.commit();
              batch = firestore.batch();
              opCount = 0;
            }
          }
        }

        if (opCount > 0) await batch.commit();
        AppLogger.success(
          'Backfilled displayNameLower for ${docsToUpdate.length} friend docs',
        );
      }

      // Set migration flag
      await firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userRateLimits)
          .doc('friendSearchMigrated')
          .set({'migratedAt': clock.now()});
    } catch (e) {
      AppLogger.warning('Failed to backfill displayNameLower: $e');
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
