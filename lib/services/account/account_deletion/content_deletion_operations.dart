import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Handles deletion of user content (recipes, menus, shopping lists).
class ContentDeletionOperations {
  final FirebaseFirestore _firestore;
  static const String _logTag = 'ContentDeletionOps';
  // Safety margin under Firestore's 500-op batch limit.
  static const int _batchLimit = 450;

  ContentDeletionOperations(this._firestore);

  /// Commits batch when op count reaches [_batchLimit], returns a fresh
  /// batch and resets counter.
  Future<({WriteBatch batch, int count})> _commitIfNeeded(
      WriteBatch batch, int count) async {
    if (count >= _batchLimit) {
      await batch.commit();
      return (batch: _firestore.batch(), count: 0);
    }
    return (batch: batch, count: count);
  }

  Future<bool> deleteRecipes(String userId) async {
    try {
      final recipesSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.recipes)
          .get();

      final unifiedSnapshot = await _firestore
          .collection(FirestoreCollections.recipes)
          .where('userId', isEqualTo: userId)
          .get();

      final allDocs = [
        ...recipesSnapshot.docs,
        ...unifiedSnapshot.docs,
      ];

      await batchDeleteDocs(_firestore, allDocs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete recipes', e);
      return false;
    }
  }

  Future<bool> deleteMenus(String userId) async {
    try {
      final menusSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.menus)
          .get();

      await batchDeleteDocs(_firestore, menusSnapshot.docs);
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete menus', e);
      return false;
    }
  }

  Future<bool> deleteShoppingLists(String userId) async {
    try {
      final listsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userShoppingLists)
          .get();

      await batchDeleteDocs(_firestore, listsSnapshot.docs);

      // Cross-user scrub. When this user is removed, null out any
      // references on OTHER users' collaborative lists:
      //   - assignedToUserId
      //   - purchasedByUserId
      await _scrubCollaborativeListReferences(userId);

      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete shopping lists', e);
      return false;
    }
  }

  /// Remove references to a deleted user from collaborative shopping list
  /// items on OTHER users' lists (GDPR Article 17 — right to erasure).
  ///
  /// Scope: only `unified_shared_shopping_lists` where the deleted user
  /// is a member. The deleted user's own lists are handled by the regular
  /// delete path above.
  ///
  /// Fields scrubbed on matching items (kept for audit integrity, but
  /// the actor reference is removed):
  ///   - `assignedToUserId` / `assignedToDisplayName` / `assignedAt`
  ///   - `purchasedByUserId` / `purchasedByDisplayName` / `purchasedAt`
  Future<void> _scrubCollaborativeListReferences(String userId) async {
    try {
      // memberPermissions is a map keyed by userId. Firestore cannot query
      // map keys directly, so we use a dot-path filter with isNotEqualTo: null.
      // This matches any list document where `memberPermissions.{userId}`
      // exists (and isn't null), i.e. the user is a member.
      final sharedLists = await _firestore
          .collection(FirestoreCollections.unifiedSharedShoppingLists)
          .where('memberPermissions.$userId', isNotEqualTo: null)
          .get();

      if (sharedLists.docs.isEmpty) return;

      for (final listDoc in sharedLists.docs) {
        final data = listDoc.data();
        final items = data['items'];
        if (items is! List) continue;

        var changed = false;
        final scrubbed = items.map((raw) {
          if (raw is! Map) return raw;
          final map = Map<String, dynamic>.from(raw);
          if (map['assignedToUserId'] == userId) {
            map['assignedToUserId'] = null;
            map['assignedToDisplayName'] = null;
            map['assignedAt'] = null;
            changed = true;
          }
          if (map['purchasedByUserId'] == userId) {
            map['purchasedByUserId'] = null;
            map['purchasedByDisplayName'] = null;
            map['purchasedAt'] = null;
            changed = true;
          }
          return map;
        }).toList();

        if (changed) {
          await listDoc.reference.update({'items': scrubbed});
          app_logger.AppLogger.info(
              '[$_logTag] Scrubbed user $userId from list ${listDoc.id}');
        }
      }
    } catch (e) {
      // Non-fatal — deletion still proceeds. Scrub is best-effort.
      app_logger.AppLogger.error(
          '[$_logTag] Failed to scrub collaborative list refs', e);
    }
  }

  /// Delete personal tags (GDPR Article 17 - Right to Erasure)
  Future<bool> deletePersonalTags(String userId) async {
    try {
      final tagsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userPersonalTags)
          .get();

      await batchDeleteDocs(_firestore, tagsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${tagsSnapshot.docs.length} personal tags');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete personal tags', e);
      return false;
    }
  }

  /// Delete cook snaps (GDPR Article 17 - Right to Erasure)
  Future<bool> deleteCookSnaps(String userId) async {
    try {
      final snapsSnapshot = await _firestore
          .collection(FirestoreCollections.cookSnaps)
          .where('userId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, snapsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${snapsSnapshot.docs.length} cook snaps');
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete cook snaps', e);
      return false;
    }
  }

  /// Delete activity events (GDPR Article 17 - Right to Erasure)
  Future<bool> deleteActivityEvents(String userId) async {
    try {
      final eventsSnapshot = await _firestore
          .collection(FirestoreCollections.activityEvents)
          .where('actorId', isEqualTo: userId)
          .get();

      await batchDeleteDocs(_firestore, eventsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${eventsSnapshot.docs.length} activity events');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete activity events', e);
      return false;
    }
  }

  /// Delete weekly menu plans (GDPR Article 17 - Right to Erasure).
  /// Doc IDs are prefixed with `{userId}_` so a range query gives us only
  /// this user's plans without an additional Firestore index.
  Future<bool> deleteWeeklyMenuPlans(String userId) async {
    try {
      final plansSnapshot = await _firestore
          .collection(FirestoreCollections.weeklyMenuPlans)
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
          .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
          .get();

      await batchDeleteDocs(_firestore, plansSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${plansSnapshot.docs.length} weekly menu plans');

      // Scrub this user from any GROUP plans they were part of. Those
      // plans belong to the group (other participants), so we never
      // cascade-delete — just remove the departing user. If the scrub
      // leaves the plan with zero participants, it's orphaned and gets
      // deleted. Mirrors the collaborative-shopping scrub pattern above.
      await _scrubGroupWeeklyMenuPlans(userId);

      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete weekly menu plans', e);
      return false;
    }
  }

  /// Remove [userId] from the `participants` list + `participantUserIds` +
  /// `memberPermissions` map on every [GroupWeeklyMenuPlan] they're on.
  /// If a plan ends up with zero participants, delete it (orphaned).
  ///
  /// Uses the `participantUserIds` array (which `array-contains` can
  /// filter on natively) rather than the `memberPermissions.{userId}`
  /// dot-path query. The dotted-field idiom used by the shopping scrub
  /// works on real Firestore but can misbehave in certain test fakes;
  /// array-contains is unambiguous and the denormalised list is kept in
  /// sync with the permissions map on every save.
  Future<void> _scrubGroupWeeklyMenuPlans(String userId) async {
    try {
      final groupPlans = await _firestore
          .collection(FirestoreCollections.groupWeeklyMenuPlans)
          .where('participantUserIds', arrayContains: userId)
          .get();

      if (groupPlans.docs.isEmpty) return;

      var orphanedCount = 0;
      var scrubbedCount = 0;

      // Batch updates/deletes into a single commit (one RTT per batch)
      // instead of one RTT per doc — the same pattern used by
      // social_deletion_operations.
      var batch = _firestore.batch();
      var opCount = 0;

      for (final planDoc in groupPlans.docs) {
        final data = planDoc.data();

        final participantsRaw = data['participants'];
        final participants = participantsRaw is List
            ? participantsRaw
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .where((m) => m['userId'] != userId)
                .toList()
            : <Map<String, dynamic>>[];

        final userIdsRaw = data['participantUserIds'];
        final userIds = userIdsRaw is List
            ? userIdsRaw.where((id) => id != userId).cast<String>().toList()
            : <String>[];

        if (userIds.isEmpty) {
          // Orphan — no one left to see the plan.
          batch.delete(planDoc.reference);
          orphanedCount += 1;
        } else {
          // Dotted-path `FieldValue.delete()` cleanly removes the per-user
          // entry from `memberPermissions` without whole-map replacement.
          batch.update(planDoc.reference, {
            'participants': participants,
            'participantUserIds': userIds,
            'memberPermissions.$userId': FieldValue.delete(),
          });
          scrubbedCount += 1;
        }
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }

      if (opCount > 0) await batch.commit();

      app_logger.AppLogger.info(
          '[$_logTag] Group menu scrub: $scrubbedCount updated, '
          '$orphanedCount deleted as orphans (user=$userId)');
    } catch (e) {
      // Non-fatal — account deletion proceeds. Scrub is best-effort.
      app_logger.AppLogger.error(
          '[$_logTag] Failed to scrub group weekly menu plans', e);
    }
  }

  /// Delete pantry items (GDPR Article 17 - Right to Erasure)
  Future<bool> deletePantryItems(String userId) async {
    try {
      final pantrySnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.pantry)
          .get();

      await batchDeleteDocs(_firestore, pantrySnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${pantrySnapshot.docs.length} pantry items');
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete pantry items', e);
      return false;
    }
  }

  /// Delete personal tag groups (GDPR Article 17 - Right to Erasure)
  Future<bool> deletePersonalTagGroups(String userId) async {
    try {
      final groupsSnapshot = await _firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userPersonalTagGroups)
          .get();

      await batchDeleteDocs(_firestore, groupsSnapshot.docs);
      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${groupsSnapshot.docs.length} personal tag groups');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete personal tag groups', e);
      return false;
    }
  }
}
