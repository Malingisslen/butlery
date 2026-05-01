import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// Handles deletion of social data (friends, messages, shared content, comments/ratings).
class SocialDeletionOperations {
  final FirebaseFirestore _firestore;
  final MessagingRepository _messagingRepo;
  static const String _logTag = 'SocialDeletionOps';
  static const int _batchLimit =
      450; // Safety margin under Firestore's 500-op limit

  SocialDeletionOperations(
    this._firestore, {
    required MessagingRepository messagingRepository,
  }) : _messagingRepo = messagingRepository;

  /// Delete all docs in a collection owned by userId, draining member subcollections first.
  Future<void> _deleteOwnedSharedContent(
      String collection, String userId) async {
    final ownedSnapshot = await _firestore
        .collection(collection)
        .where('sharedByUserId', isEqualTo: userId)
        .get();

    for (final doc in ownedSnapshot.docs) {
      final members =
          await doc.reference.collection(FirestoreCollections.members).get();
      await batchDeleteDocs(_firestore, members.docs);
    }
    await batchDeleteDocs(_firestore, ownedSnapshot.docs);
  }

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

      // Clean up reverse friend links on each friend
      for (final friendId in friendIds) {
        // Remove this user from friend's friends list
        batch.delete(_firestore
            .collection(FirestoreCollections.users)
            .doc(friendId)
            .collection(FirestoreCollections.userFriends)
            .doc(userId));
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
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
            .collection(FirestoreCollections.socialRequests)
            .where('fromUserId', isEqualTo: userId)
            .get(),
        _firestore
            .collection(FirestoreCollections.socialRequests)
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
      await _messagingRepo.deleteAllMessagesForUser(userId);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete messages', e);
      return false;
    }
  }

  /// Remove user from all shared content memberships and delete owned shared recipes.
  Future<bool> removeFromSharedContent(String userId) async {
    try {
      // Two independent collectionGroup reads — fan out concurrently.
      final results = await Future.wait([
        _firestore
            .collectionGroup(FirestoreCollections.members)
            .where('userId', isEqualTo: userId)
            .get(),
        // BUT-732: scrub the user's engagement metadata across other people's
        // shared content. Engagement docs live at
        // `shared_content/{contentId}/engagements/{userId}` and accumulate as
        // the user views/imports/joins shared items — every doc with
        // `userId == this user` must go for GDPR Art. 17 erasure.
        // Permission path: firestore.rules:1552-1554 (collectionGroup
        // `engagements` read scoped by `request.auth.uid == userId`) allows
        // this query independent of membership state. Per-doc delete uses the
        // direct-path rule at firestore.rules:547 (`auth.uid == userId`).
        _firestore
            .collectionGroup(FirestoreCollections.engagements)
            .where('userId', isEqualTo: userId)
            .get(),
      ]);
      final memberDocs = results[0];
      final engagementDocs = results[1];

      // Clean up sharedToUserIds on parent docs (batched)
      var batch = _firestore.batch();
      var opCount = 0;
      for (final doc in memberDocs.docs) {
        final parentRef = doc.reference.parent.parent;
        if (parentRef != null) {
          batch.update(parentRef, {
            'sharedToUserIds': FieldValue.arrayRemove([userId]),
          });
          opCount++;
          final state = await _commitIfNeeded(batch, opCount);
          batch = state.batch;
          opCount = state.count;
        }
      }
      // Commit remaining updates, ignoring not-found errors from already-deleted parents
      if (opCount > 0) {
        try {
          await batch.commit();
        } catch (e) {
          app_logger.AppLogger.warning(
              '[$_logTag] Some sharedToUserIds updates failed (parents may be deleted): $e');
        }
      }
      await batchDeleteDocs(_firestore, memberDocs.docs);
      await batchDeleteDocs(_firestore, engagementDocs.docs);

      // Note: legacy `sharedWith` array cleanup is intentionally NOT done
      // here. firestore.rules:515-518 only permits `update` on a
      // shared_content doc to its `sharedByUserId` owner or a member-
      // subcollection participant — a recipient who only appears in the
      // legacy `sharedWith` flat array has no `update` permission and the
      // call would server-side permission-deny. This must be handled by an
      // admin-context Cloud Function cascade. Filed as a follow-up.

      await _deleteOwnedSharedContent(
          FirestoreCollections.sharedContent, userId);

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

  /// Delete shared menus and shopping lists owned by user.
  /// No-op since removeFromSharedContent already deletes all owned content
  /// from the unified shared_content collection.
  @Deprecated(
      'All shared content is now in shared_content collection — handled by removeFromSharedContent')
  Future<bool> deleteSharedMenusAndShoppingLists(String userId) async {
    // All content types now live in shared_content — already cleaned up by removeFromSharedContent
    return true;
  }

  /// BUT-407 GDPR cascade: delete all pings authored by userId across every
  /// group. Pings live at `pings/{groupId}/pings/{pingId}` — we issue a
  /// collection-group query scoped to the nested `pings` subcollection to
  /// collect every doc with `fromUserId == userId`, then batch-delete.
  /// Missing index falls back silently (no pings is the safe default).
  Future<bool> deletePingsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collectionGroup(FirestoreCollections.pings)
          .where('fromUserId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) return true;

      await batchDeleteDocs(_firestore, snapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${snapshot.docs.length} pings for user $userId');
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete user pings', e);
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
}
