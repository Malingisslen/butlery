import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';

/// Handles deletion of social data (friends, messages, shared content, comments/ratings).
class SocialDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'SocialDeletionOps';

  SocialDeletionOperations(this._firestore);

  Future<bool> removeFriendConnections(String userId) async {
    try {
      final batch = _firestore.batch();

      final userFriends = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends)
          .get();

      for (final doc in userFriends.docs) {
        batch.delete(doc.reference);
      }

      final categories = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriendCategories)
          .get();

      for (final doc in categories.docs) {
        batch.delete(doc.reference);
      }

      final sentRequests = await _firestore
          .collection(FirestoreCollections.friendRequests)
          .where('fromUserId', isEqualTo: userId)
          .get();

      for (final doc in sentRequests.docs) {
        batch.delete(doc.reference);
      }

      final receivedRequests = await _firestore
          .collection(FirestoreCollections.friendRequests)
          .where('toUserId', isEqualTo: userId)
          .get();

      for (final doc in receivedRequests.docs) {
        batch.delete(doc.reference);
      }

      final sentInvitations = await _firestore
          .collection(FirestoreCollections.groupInvitations)
          .where('fromUserId', isEqualTo: userId)
          .get();

      for (final doc in sentInvitations.docs) {
        batch.delete(doc.reference);
      }

      final receivedInvitations = await _firestore
          .collection(FirestoreCollections.groupInvitations)
          .where('toUserId', isEqualTo: userId)
          .get();

      for (final doc in receivedInvitations.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to remove friend connections', e);
      return false;
    }
  }

  Future<bool> deleteMessages(String userId) async {
    try {
      final conversationsSnapshot = await _firestore
          .collection(FirestoreCollections.conversations)
          .where('participants', arrayContains: userId)
          .get();

      final batch = _firestore.batch();

      for (final doc in conversationsSnapshot.docs) {
        final messagesSnapshot =
            await doc.reference.collection(FirestoreCollections.messages).get();

        for (final msgDoc in messagesSnapshot.docs) {
          batch.delete(msgDoc.reference);
        }

        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.length <= 2) {
          batch.delete(doc.reference);
        } else {
          participants.remove(userId);
          batch.update(doc.reference, {'participants': participants});
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete messages', e);
      return false;
    }
  }

  Future<bool> removeFromSharedContent(String userId) async {
    try {
      final sharedRecipesSnapshot = await _firestore
          .collection(FirestoreCollections.sharedRecipes)
          .where('sharedWith', arrayContains: userId)
          .get();

      final batch = _firestore.batch();

      for (final doc in sharedRecipesSnapshot.docs) {
        final sharedWith = List<String>.from(doc.data()['sharedWith'] ?? []);
        sharedWith.remove(userId);

        if (sharedWith.isEmpty) {
          batch.delete(doc.reference);
        } else {
          batch.update(doc.reference, {'sharedWith': sharedWith});
        }
      }

      final ownedSharedSnapshot = await _firestore
          .collection(FirestoreCollections.sharedRecipes)
          .where('ownerId', isEqualTo: userId)
          .get();

      for (final doc in ownedSharedSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to remove from shared content', e);
      return false;
    }
  }

  Future<bool> deleteCommentsAndRatings(String userId) async {
    try {
      final batch = _firestore.batch();

      final commentsSnapshot = await _firestore
          .collection(FirestoreCollections.recipeComments)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final ratingsSnapshot = await _firestore
          .collection(FirestoreCollections.recipeRatings)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in ratingsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final menuCommentsSnapshot = await _firestore
          .collection(FirestoreCollections.menuComments)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in menuCommentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final menuRatingsSnapshot = await _firestore
          .collection(FirestoreCollections.menuRatings)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in menuRatingsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete comments and ratings', e);
      return false;
    }
  }
}
