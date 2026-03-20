import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

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

      // Read friends list first — needed for reverse cleanup
      final friendsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userFriends)
          .get();

      final friendIds = friendsSnapshot.docs.map((d) => d.id).toList();

      // Clean up reverse friend links and categoryMemberships on each friend
      for (final friendId in friendIds) {
        // Remove this user from friend's friends list
        batch.delete(_firestore
            .collection(FirestoreCollections.users)
            .doc(friendId)
            .collection(FirestoreCollections.userFriends)
            .doc(userId));
        opCount++;
        var state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;

        // Remove categoryMemberships where this user is the owner
        final memberships = await _firestore
            .collection(FirestoreCollections.users)
            .doc(friendId)
            .collection(FirestoreCollections.userCategoryMemberships)
            .where('ownerId', isEqualTo: userId)
            .get();

        for (final doc in memberships.docs) {
          batch.delete(doc.reference);
          opCount++;
          state = await _commitIfNeeded(batch, opCount);
          batch = state.batch;
          opCount = state.count;
        }
      }

      // Delete user's own friends list, categories, and requests
      final queries = [
        Future.value(friendsSnapshot), // Already fetched above
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
          .where('participantIds', arrayContains: userId)
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
            List<String>.from(doc.data()['participantIds'] ?? []);
        if (participants.length <= 2) {
          batch.delete(doc.reference);
        } else {
          participants.remove(userId);
          batch.update(doc.reference, {'participantIds': participants});
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
          .where('sharedByUserId', isEqualTo: userId)
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

      // Recipe comments: anonymize (not delete) to preserve thread structure
      final recipeComments = await _firestore
          .collection(FirestoreCollections.recipeComments)
          .where('authorId', isEqualTo: userId)
          .get();

      for (final doc in recipeComments.docs) {
        batch.update(doc.reference, {
          'authorId': 'deleted',
          'authorDisplayName': AppLocale.current.deletedUser,
          'authorAvatarUrl': null,
          'isDeleted': true,
          'text': AppLocale.current.commentDeleted,
        });
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      // Hard-delete ratings and menu data (run queries in parallel)
      final deleteResults = await Future.wait([
        _firestore
            .collection(FirestoreCollections.recipeRatings)
            .where('userId', isEqualTo: userId)
            .get(),
        _firestore
            .collectionGroup(FirestoreCollections.comments)
            .where('commentedBy', isEqualTo: userId)
            .get(),
        _firestore
            .collectionGroup(FirestoreCollections.ratings)
            .where('ratedBy', isEqualTo: userId)
            .get(),
      ]);

      for (final snapshot in deleteResults) {
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
          .collection(FirestoreCollections.sharedMenus)
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
          .collection(FirestoreCollections.sharedMenus)
          .where('sharedByUserId', isEqualTo: userId)
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
          .collection(FirestoreCollections.sharedShoppingLists)
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
          .collection(FirestoreCollections.sharedShoppingLists)
          .where('sharedByUserId', isEqualTo: userId)
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
      final reportsSnapshot = await _firestore
          .collection(FirestoreCollections.reports)
          .where('reporterId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, reportsSnapshot.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user reports', e);
      return false;
    }
  }

  /// Delete user's shared personal tags.
  Future<bool> deleteSharedPersonalTags(String userId) async {
    try {
      final tags = await _firestore
          .collection(FirestoreCollections.sharedPersonalTags)
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, tags.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete shared personal tags', e);
      return false;
    }
  }

  /// Delete user's menu activity records.
  Future<bool> deleteMenuActivity(String userId) async {
    try {
      final activities = await _firestore
          .collection(FirestoreCollections.menuActivity)
          .where('userId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, activities.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete menu activity', e);
      return false;
    }
  }
}
