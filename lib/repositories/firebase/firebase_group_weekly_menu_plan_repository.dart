import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';

/// Firebase implementation of [GroupWeeklyMenuPlanRepository].
///
/// Top-level collection (one doc per group per ISO week). Doc ID is
/// `{groupId}_{YYYY}-W{WW}`, same shape as the per-user plans so upsert
/// semantics transfer directly. Access control is the domain of
/// firestore.rules. What each permission method here checks differs — read
/// their bodies. `validateUpdatePermission` calls `canEdit`, and that is the
/// one `save()`'s denial hangs on.
class FirebaseGroupWeeklyMenuPlanRepository
    extends BaseFirebaseRepository<GroupWeeklyMenuPlan>
    implements GroupWeeklyMenuPlanRepository {
  FirebaseGroupWeeklyMenuPlanRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.groupWeeklyMenuPlans;

  @override
  GroupWeeklyMenuPlan fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => GroupWeeklyMenuPlan.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(GroupWeeklyMenuPlan entity) =>
      entity.toFirestore();

  @override
  String getId(GroupWeeklyMenuPlan entity) => entity.id;

  // Permission methods. Firestore rules are the authoritative gate; these vary
  // in what they check, so read each body rather than the group.
  // `validateUpdatePermission` is the one `save()` refuses on.

  @override
  Future<bool> validateCreatePermission(
    String userId,
    GroupWeeklyMenuPlan entity,
  ) async {
    return entity.id.startsWith('${entity.groupId}_') &&
        entity.participantFor(userId) != null;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    GroupWeeklyMenuPlan? entity,
  ) async {
    // A null entity means the caller has no snapshot to judge — a read of a
    // document that may not exist. `firestore.rules` decides that one; there is
    // nothing here to check it against.
    if (entity == null) return true;
    // The doc-id prefix is checked alongside membership, matching the create
    // and update limbs. Without it a document whose id belongs to another group
    // passes on membership alone (BUT-1974).
    return resourceId.startsWith('${entity.groupId}_') &&
        entity.canRead(userId);
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    GroupWeeklyMenuPlan entity,
  ) async {
    return resourceId.startsWith('${entity.groupId}_') &&
        entity.canEdit(userId);
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // No entity snapshot here — rules enforce admin-only delete. This
    // returns true so the caller can delegate to the security rules.
    return true;
  }

  @override
  Future<GroupWeeklyMenuPlan?> fetchForWeek({
    required String groupId,
    required DateTime weekStart,
  }) async {
    final docId = GroupWeeklyMenuPlan.docIdFor(groupId, weekStart);
    final snapshot = await collection.doc(docId).get();
    if (!snapshot.exists) return null;
    return fromFirestore(snapshot);
  }

  @override
  Future<void> save(GroupWeeklyMenuPlan plan, {String? userId}) async {
    // Deterministic upsert on `{groupId}_{ISO week}`.
    // Self-consistency: doc-ID prefix must match groupId.
    if (!plan.id.startsWith('${plan.groupId}_')) {
      // Was a silent `return`, so a mis-keyed plan looked saved to every
      // caller (BUT-1962). Routed through the sanitizer because a Dart-core
      // throw gets none of the `toString()` masking the permission exceptions
      // build in, and this one reaches Crashlytics through the poll-close
      // path. The chokepoint is the point, not the redaction.
      throw StateError(
        'Group menu plan id does not match its groupId: '
        '${LogSanitizer.maskConversationId(plan.groupId)}',
      );
    }
    // Belt-and-braces permission check mirroring the per-user plan repo.
    // The service layer also checks this, and Firestore rules are the
    // authoritative gate — the duplicate here catches programming errors
    // (missing service-layer check, test harness mocks, etc.).
    if (userId != null) {
      // Resolved before the gate for the same reason as the per-user repo:
      // on this limb it is the only client-side authentication assertion, and
      // throwing it from inside the refusal branch would lose the row. A
      // `save` with no `userId` skips this limb entirely and asserts nothing
      // client-side — unchanged, and bounded by the rules.
      final actorId = requireCurrentUserId();
      final canWrite = await validateUpdatePermission(userId, plan.id, plan);
      if (!canWrite) {
        // BUT-1981 audited the REFUSAL only. That reduction was accepted on the
        // ground that the edit trail would buy back the lost edit history, and
        // ADR-0010 measured that it does not: the trail is written by the
        // client, so a member can put another member's uid in a row, and `save`
        // writes the whole document, so a genuine row is lost when two people
        // edit the same week. Malin chose to restore the granted row here
        // rather than rely on the trail alone.
        //
        // This collection only. The per-user repository keeps BUT-1981's
        // reduction: its gate is a tautology that never recorded a decision
        // which could have gone the other way.
        await logPermissionCheck(
          // The AUTHENTICATED actor, not the caller-supplied one — an
          // `audit_logs` create whose uid does not match the caller is refused
          // by the rules, so a divergent actor would lose the row silently.
          // The permission check above deliberately still uses the passed
          // `userId`: that is the identity whose access is being decided.
          userId: actorId,
          resource: '$collectionName/${plan.id}',
          operation: 'save',
          granted: false,
          auditRepository: auditRepository,
        );
        // Was a silent `return`. On the meal-poll close that meant the poll
        // closed on a one-way door with the winner never written. Throwing
        // leaves it open for a retry.
        throw PermissionDeniedException(
          'Group menu plan save denied',
          resource: collectionName,
          operation: 'save',
          userId: userId,
        );
      }
      // The GRANTED row (ADR-0010). Server-verifiable in a way the edit trail
      // is not: `audit_logs` refuses a create whose uid does not match the
      // caller, so this row cannot name anybody but its writer.
      await logPermissionCheck(
        userId: actorId,
        resource: '$collectionName/${plan.id}',
        operation: 'save',
        granted: true,
        auditRepository: auditRepository,
      );
    }
    await collection.doc(plan.id).set(toFirestore(plan));
  }

  @override
  Stream<GroupWeeklyMenuPlan?> watchForWeek({
    required String groupId,
    required DateTime date,
  }) {
    final docId = GroupWeeklyMenuPlan.docIdFor(groupId, date);
    final docRef = collection.doc(docId);

    return docRef
        .snapshots()
        .map<GroupWeeklyMenuPlan?>((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data();
          if (data == null) return null;
          try {
            return GroupWeeklyMenuPlan.fromMap(snapshot.id, data);
          } catch (e) {
            AppLogger.warning(
              'Failed to parse group menu plan ${snapshot.id}: $e',
            );
            return null;
          }
        })
        .handleError((Object error) {
          AppLogger.error(
            'Realtime group menu plan stream error ($groupId / $docId)',
            error,
          );
          throw error;
        });
  }

  @override
  Future<List<Map<String, dynamic>>> exportPlansForParticipant(
    String userId, {
    int maxDocuments = 260,
  }) async {
    // GDPR Article 20: caller must be exporting their own participation.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    // `isNull: false`, not `isNotEqualTo: null` — the SDK adds a condition only
    // when the argument is non-null (query.dart:659), so a literal null made
    // this an unfiltered read of every group's plans rather than the
    // requester's participation. Same defect, same fix as the shared-shopping
    // -list probes (BUT-1732).
    final snapshot = await collection
        .where('memberPermissions.$userId', isNull: false)
        .limit(maxDocuments)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
