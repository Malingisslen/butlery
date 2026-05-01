import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/logger.dart' as app_logger;
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// GDPR Article 17 cascade for user-owned content (recipes, menus, shopping
/// lists, cook snaps, activity events, weekly menus, pantry, personal tags).
///
/// Per-resource collections delete via their repositories. Cross-user scrub
/// paths (collaborative-list references, group weekly menus) patch foreign
/// docs and stay direct on Firestore by design.
class ContentDeletionOperations {
  final FirebaseFirestore _firestore;
  // Test seams: production resolves via ServiceLocator on first use; tests
  // inject fakes that share the same FakeFirebaseFirestore as [_firestore].
  final CookSnapRepository? _cookSnapRepo;
  final ActivityEventRepository? _activityRepo;
  final WeeklyMenuPlanRepository? _weeklyMenuRepo;
  final PantryRepository? _pantryRepo;
  static const String _logTag = 'ContentDeletionOps';
  // Safety margin under Firestore's 500-op batch limit.
  static const int _batchLimit = 450;

  ContentDeletionOperations(
    this._firestore, {
    CookSnapRepository? cookSnapRepository,
    ActivityEventRepository? activityEventRepository,
    WeeklyMenuPlanRepository? weeklyMenuPlanRepository,
    PantryRepository? pantryRepository,
  })  : _cookSnapRepo = cookSnapRepository,
        _activityRepo = activityEventRepository,
        _weeklyMenuRepo = weeklyMenuPlanRepository,
        _pantryRepo = pantryRepository;

  CookSnapRepository get _cookSnapRepository =>
      _cookSnapRepo ?? ServiceLocator.get<CookSnapRepository>();
  ActivityEventRepository get _activityEventRepository =>
      _activityRepo ?? ServiceLocator.get<ActivityEventRepository>();
  WeeklyMenuPlanRepository get _weeklyMenuPlanRepository =>
      _weeklyMenuRepo ?? ServiceLocator.get<WeeklyMenuPlanRepository>();
  PantryRepository get _pantryRepository =>
      _pantryRepo ?? ServiceLocator.get<PantryRepository>();

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

      // BUT-746: top-level `menus` orphans owned by the deleted user.
      // The unified menus collection holds shared menus that
      // FirebaseDataExportRepository.exportSharedMenusByOwner reads via
      // `sharedByUserId == uid`. These docs would otherwise outlive their
      // owner — GDPR Art 17 violation.
      await _deleteSharedMenusOwnedBy(userId);

      // BUT-747: top-level `menus` where deleted user is a recipient.
      // Mirrors the symmetric scrub for collaborative shopping lists
      // (`_scrubCollaborativeListReferences` above). Removes the deleted
      // UID from `sharedToUserIds` arrays on every inbound shared menu.
      await _scrubInboundSharedMenus(userId);

      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete menus', e);
      return false;
    }
  }

  /// Delete top-level `menus` documents owned by [userId].
  /// Rethrows `permission-denied` so the parent cascade surfaces the failure
  /// in `failedCollections`; transient errors stay best-effort.
  Future<void> _deleteSharedMenusOwnedBy(String userId) async {
    try {
      final ownedMenus = await _firestore
          .collection(FirestoreCollections.menus)
          .where('sharedByUserId', isEqualTo: userId)
          .get();

      if (ownedMenus.docs.isEmpty) return;
      await batchDeleteDocs(_firestore, ownedMenus.docs);

      app_logger.AppLogger.info(
          '[$_logTag] Deleted ${ownedMenus.docs.length} top-level shared menus '
          '(sharedByUserId=$userId)');
    } on FirebaseException catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete top-level shared menus (${e.code})', e);
      if (e.code == 'permission-denied') rethrow;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete top-level shared menus', e);
    }
  }

  /// Remove [userId] from `sharedToUserIds` on every top-level menu they're
  /// a recipient of. Read-modify-write rather than `FieldValue.arrayRemove`
  /// because `fake_cloud_firestore` drops the array transform inside a
  /// batched update (the residual test then can't observe the scrub).
  /// Trade-off accepted: tiny lost-update window if a concurrent share
  /// adds a member to the same menu between read and commit; unlikely
  /// during account deletion (singleton operation per user).
  Future<void> _scrubInboundSharedMenus(String userId) async {
    try {
      final inboundMenus = await _firestore
          .collection(FirestoreCollections.menus)
          .where('sharedToUserIds', arrayContains: userId)
          .get();

      if (inboundMenus.docs.isEmpty) return;

      var batch = _firestore.batch();
      var opCount = 0;
      for (final doc in inboundMenus.docs) {
        final raw = doc.data()['sharedToUserIds'];
        final scrubbed = raw is List
            ? raw.where((id) => id != userId).toList()
            : <dynamic>[];
        batch.update(doc.reference, {'sharedToUserIds': scrubbed});
        opCount++;
        final state = await _commitIfNeeded(batch, opCount);
        batch = state.batch;
        opCount = state.count;
      }
      if (opCount > 0) await batch.commit();

      app_logger.AppLogger.info(
          '[$_logTag] Scrubbed user $userId from ${inboundMenus.docs.length} '
          'inbound shared menus');
    } on FirebaseException catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to scrub inbound shared menus (${e.code})', e);
      if (e.code == 'permission-denied') rethrow;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to scrub inbound shared menus', e);
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

  /// Delete cook snaps (GDPR Article 17 - Right to Erasure).
  /// Routes through [CookSnapRepository.deleteAllByUser] which enforces
  /// `validateOwnership` (PermissionValidationMixin).
  Future<bool> deleteCookSnaps(String userId) async {
    try {
      final count = await _cookSnapRepository.deleteAllByUser(userId);
      app_logger.AppLogger.info('[$_logTag] Deleted $count cook snaps');
      return true;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed to delete cook snaps', e);
      return false;
    }
  }

  /// Delete activity events (GDPR Article 17 - Right to Erasure).
  /// Routes through [ActivityEventRepository.deleteAllByUser] which
  /// enforces `validateOwnership` (PermissionValidationMixin).
  Future<bool> deleteActivityEvents(String userId) async {
    try {
      final count = await _activityEventRepository.deleteAllByUser(userId);
      app_logger.AppLogger.info('[$_logTag] Deleted $count activity events');
      return true;
    } catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed to delete activity events', e);
      return false;
    }
  }

  /// Delete weekly menu plans (GDPR Article 17 - Right to Erasure).
  /// Routes the per-user delete through [WeeklyMenuPlanRepository.deleteAllByUser]
  /// (validates ownership). The cross-user GROUP-plan scrub stays here -
  /// it patches OTHER users' plans and so doesn't fit a per-resource repo.
  Future<bool> deleteWeeklyMenuPlans(String userId) async {
    try {
      final count = await _weeklyMenuPlanRepository.deleteAllByUser(userId);
      app_logger.AppLogger.info('[$_logTag] Deleted $count weekly menu plans');

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

  /// Delete pantry items (GDPR Article 17 - Right to Erasure).
  /// Routes through [PantryRepository.deleteAll]. Ownership is enforced
  /// structurally (subcollection under `users/{uid}`) at the rules layer.
  Future<bool> deletePantryItems(String userId) async {
    try {
      await _pantryRepository.deleteAll(userId);
      app_logger.AppLogger.info('[$_logTag] Deleted pantry items');
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
