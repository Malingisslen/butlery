import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/weekly_menu_plan_repository.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// Firebase implementation of [WeeklyMenuPlanRepository].
///
/// Top-level collection (one doc per user per ISO week). Doc ID is
/// `{userId}_{YYYY}-W{WW}` so generation re-runs upsert into the same
/// document instead of creating duplicates. Owner-scoped via the userId
/// prefix in the doc ID — see firestore.rules.
class FirebaseWeeklyMenuPlanRepository
    extends BaseFirebaseRepository<WeeklyMenuPlan>
    implements WeeklyMenuPlanRepository {
  FirebaseWeeklyMenuPlanRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.weeklyMenuPlans;

  @override
  WeeklyMenuPlan fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      WeeklyMenuPlan.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(WeeklyMenuPlan entity) =>
      entity.toFirestore();

  @override
  String getId(WeeklyMenuPlan entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(
      String userId, WeeklyMenuPlan entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, WeeklyMenuPlan? entity) async {
    // Doc ID prefix is the owning userId — match it.
    return resourceId.startsWith('${userId}_');
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, WeeklyMenuPlan entity) async {
    return entity.userId == userId && resourceId.startsWith('${userId}_');
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    return resourceId.startsWith('${userId}_');
  }

  @override
  Future<WeeklyMenuPlan?> fetchForWeek({
    required String userId,
    required DateTime weekStart,
  }) async {
    final docId = IsoWeekUtils.weekIdFor(userId, weekStart);
    final snapshot = await collection.doc(docId).get();
    if (!snapshot.exists) return null;
    return fromFirestore(snapshot);
  }

  @override
  Future<void> save(WeeklyMenuPlan plan) async {
    // Deterministic upsert — bypass `create` so re-saves of the same
    // user+week update in place rather than throwing on doc collisions.
    final canWrite = await validateUpdatePermission(plan.userId, plan.id, plan);
    if (!canWrite) {
      AppLogger.warning('Blocked weekly menu plan save: ${plan.id}');
      return;
    }
    await collection.doc(plan.id).set(toFirestore(plan));
  }

  @override
  Future<int> deleteAllByUser(String userId) async {
    // GDPR cascade: caller must be deleting their own data. The doc-ID
    // prefix already binds rows to userId, but client-side ownership
    // assertion guards against a misuse where a caller passes a
    // different userId after authenticating.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    // Doc IDs are prefixed with userId, so a range query bounded by the
    // prefix gives us only this user's docs without an extra index.
    final snapshot = await collection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
        .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
        .get();

    if (snapshot.docs.isEmpty) return 0;

    await batchDeleteDocs(firestore, snapshot.docs);
    AppLogger.info(
      'Deleted ${snapshot.docs.length} weekly menu plans for user $userId',
    );
    return snapshot.docs.length;
  }
}
