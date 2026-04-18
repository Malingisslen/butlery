import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/group_weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/group_weekly_menu_plan_repository.dart';
import 'package:butlery/services/account/account_deletion/deletion_utils.dart';

/// Firebase implementation of [GroupWeeklyMenuPlanRepository] (BUT-405).
///
/// Top-level collection (one doc per group per ISO week). Doc ID is
/// `{groupId}_{YYYY}-W{WW}`, same shape as the per-user plans so upsert
/// semantics transfer directly. Access control is the domain of
/// firestore.rules — the permission methods here only enforce internal
/// self-consistency between the entity's groupId and the doc-ID prefix.
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
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      GroupWeeklyMenuPlan.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(GroupWeeklyMenuPlan entity) =>
      entity.toFirestore();

  @override
  String getId(GroupWeeklyMenuPlan entity) => entity.id;

  // Permission methods — only enforce the internal invariant that the
  // doc-ID prefix matches the entity's groupId. Participant-level auth is
  // enforced by Firestore rules + the service layer above.

  @override
  Future<bool> validateCreatePermission(
      String userId, GroupWeeklyMenuPlan entity) async {
    return entity.id.startsWith('${entity.groupId}_') &&
        entity.participantFor(userId) != null;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, GroupWeeklyMenuPlan? entity) async {
    if (entity == null) return true; // delegated to firestore.rules
    return entity.canRead(userId);
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, GroupWeeklyMenuPlan entity) async {
    return resourceId.startsWith('${entity.groupId}_') &&
        entity.canEdit(userId);
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
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
  Future<void> save(GroupWeeklyMenuPlan plan) async {
    // Deterministic upsert — bypass `create` so re-saves of the same
    // group+week update in place rather than throwing on doc collisions.
    // Self-consistency: doc-ID prefix must match groupId. Caller-level
    // permission (is the writer an editor?) is enforced by the service.
    if (!plan.id.startsWith('${plan.groupId}_')) {
      AppLogger.warning(
          'Blocked group menu plan save (id/groupId mismatch): ${plan.id}');
      return;
    }
    await collection.doc(plan.id).set(toFirestore(plan));
  }

  @override
  Future<int> deleteAllByGroup(String groupId) async {
    // Doc IDs are prefixed with groupId, so a range query bounded by the
    // prefix gives us only this group's docs without an extra index.
    final snapshot = await collection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${groupId}_')
        .where(FieldPath.documentId, isLessThan: '${groupId}_\uf8ff')
        .get();

    if (snapshot.docs.isEmpty) return 0;

    await batchDeleteDocs(firestore, snapshot.docs);
    AppLogger.info(
      'Deleted ${snapshot.docs.length} group weekly menu plans for group $groupId',
    );
    return snapshot.docs.length;
  }
}
