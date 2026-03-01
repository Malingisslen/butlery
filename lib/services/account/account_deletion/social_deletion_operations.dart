import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';

/// Handles deletion of social data (friends, messages, shared content, comments/ratings).
class SocialDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'SocialDeletionOps';
  static const int _batchLimit =
      450; // Safety margin under Firestore's 500-op limit

  SocialDeletionOperations(this._firestore);

  /// Commits batch when op count reaches limit, returns a fresh batch and resets counter.
  Future<({WriteBatch batch, int count})> _commitIfNeeded(
      WriteBatch batch, int count) async {
    if (count >= _batchLimit) {
      await batch.commit();
      return (batch: _firestore.batch(), count: 0);
    }
    return (batch: batch, count: count);
  }

  Future<bool> removeFriendConnections(String userId) async {
    try {
      var batch = _firestore.batch();
      var opCount = 0;

      final queries = [
        _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userFriends)
            .get(),
        _firestore
            .collection(FirestoreCollections.users)
            .doc(userId)
            .collection(FirestoreCollections.userFriendCategories)
            .get(),
        _firestore
            .collection(FirestoreCollections.friendRequests)
            .where('fromUserId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.friendRequests)
            .where('toUserId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.groupInvitations)
            .where('fromUserId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.groupInvitations)
            .where('toUserId', isEqualTo: userId)
            .get(),
      ];

      final results = await Future.wait(queries);

      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
          opCount++;
          final state = await _commitIfNeeded(batch, opCount);
          batch = state.batch;
          opCount = state.count;
        }
      }

      if (opCount > 0) await batch.commit();
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

      var batch = _firestore.batch();
      var opCount = 0;

      for (final doc in conversationsSnapshot.docs) {
        final messagesSnapshot =
            await doc.reference.collection(FirestoreCollections.messages).get();

        for (final msgDoc in messagesSnapshot.docs) {
          batch.delete(msgDoc.reference);
          opCount++;
          final state = await _commitIfNeeded(batch, opCount);
          batch = state.batch;
          opCount = state.count;
        }

        final participants =
            List<String>.from(doc.data()['participants'] ?? []);
        if (participants.length <= 2) {
          batch.delete(doc.reference);
        } else {
          participants.remove(userId);
          batch.update(doc.reference, {'participants': participants});
        }
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      if (opCount > 0) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete messages', e);
      return false;
    }
  }

  Future<bool> removeFromSharedContent(String userId) async {
    try {
      var batch = _firestore.batch();
      var opCount = 0;

      final sharedRecipesSnapshot = await _firestore
          .collection(FirestoreCollections.sharedRecipes)
          .where('sharedWith', arrayContains: userId)
          .get();

      for (final doc in sharedRecipesSnapshot.docs) {
        final sharedWith = List<String>.from(doc.data()['sharedWith'] ?? []);
        sharedWith.remove(userId);

        if (sharedWith.isEmpty) {
          batch.delete(doc.reference);
        } else {
          batch.update(doc.reference, {'sharedWith': sharedWith});
        }
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      final ownedSharedSnapshot = await _firestore
          .collection(FirestoreCollections.sharedRecipes)
          .where('ownerId', isEqualTo: userId)
          .get();

      for (final doc in ownedSharedSnapshot.docs) {
        batch.delete(doc.reference);
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      if (opCount > 0) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to remove from shared content', e);
      return false;
    }
  }

  Future<bool> deleteCommentsAndRatings(String userId) async {
    try {
      var batch = _firestore.batch();
      var opCount = 0;

      final queries = [
        _firestore
            .collection(FirestoreCollections.recipeComments)
            .where('userId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.recipeRatings)
            .where('userId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.menuComments)
            .where('userId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.menuRatings)
            .where('userId', isEqualTo: userId)
            .get(),
      ];

      final results = await Future.wait(queries);

      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
          opCount++;
          final state = await _commitIfNeeded(batch, opCount);
          batch = state.batch;
          opCount = state.count;
        }
      }

      if (opCount > 0) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete comments and ratings', e);
      return false;
    }
  }

  /// Delete shared menus owned by or shared with user.
  Future<bool> deleteSharedMenus(String userId) async {
    try {
      var batch = _firestore.batch();
      var opCount = 0;

      // Menus shared with user
      final sharedWithSnapshot = await _firestore
          .collection('shared_menus')
          .where('sharedWith', arrayContains: userId)
          .get();

      for (final doc in sharedWithSnapshot.docs) {
        batch.update(doc.reference, {
          'sharedWith': FieldValue.arrayRemove([userId]),
        });
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      // Menus owned by user
      final ownedSnapshot = await _firestore
          .collection('shared_menus')
          .where('ownerId', isEqualTo: userId)
          .get();

      for (final doc in ownedSnapshot.docs) {
        batch.delete(doc.reference);
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      if (opCount > 0) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete shared menus', e);
      return false;
    }
  }

  /// Delete shared shopping lists owned by or shared with user.
  Future<bool> deleteSharedShoppingLists(String userId) async {
    try {
      var batch = _firestore.batch();
      var opCount = 0;

      // Lists shared with user
      final sharedWithSnapshot = await _firestore
          .collection('shared_shopping_lists')
          .where('sharedWith', arrayContains: userId)
          .get();

      for (final doc in sharedWithSnapshot.docs) {
        batch.update(doc.reference, {
          'sharedWith': FieldValue.arrayRemove([userId]),
        });
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      // Lists owned by user
      final ownedSnapshot = await _firestore
          .collection('shared_shopping_lists')
          .where('ownerId', isEqualTo: userId)
          .get();

      for (final doc in ownedSnapshot.docs) {
        batch.delete(doc.reference);
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      if (opCount > 0) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete shared shopping lists', e);
      return false;
    }
  }

  /// Delete content reports submitted by user (GDPR — user's own data).
  Future<bool> deleteUserReports(String userId) async {
    try {
      var batch = _firestore.batch();
      var opCount = 0;

      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .get();

      for (final doc in reportsSnapshot.docs) {
        batch.delete(doc.reference);
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      if (opCount > 0) await batch.commit();
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user reports', e);
      return false;
    }
  }
}
