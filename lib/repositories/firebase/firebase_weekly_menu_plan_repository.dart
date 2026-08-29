import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
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
///
/// The doc-ID prefix ranges below stop at `{userId}_` plus a U+F8FF sentinel,
/// and that sentinel is load-bearing: without it the bounds collapse to
/// `>= x AND < x`, which matches zero documents — silently emptying the GDPR
/// export and turning the recipe-delete cascade into a no-op rather than
/// failing. Always spell it as the six-character escape, never as a literal
/// U+F8FF character: the literal renders as nothing, so the range reads as
/// degenerate and gets re-reported as a bug (BUT-1690 was filed that way).
/// `test/architecture/architecture_test.dart` enforces the escape spelling.
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
    String userId,
    WeeklyMenuPlan entity,
  ) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    WeeklyMenuPlan? entity,
  ) async {
    // Doc ID prefix is the owning userId — match it.
    return resourceId.startsWith('${userId}_');
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    WeeklyMenuPlan entity,
  ) async {
    return entity.userId == userId && resourceId.startsWith('${userId}_');
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    return resourceId.startsWith('${userId}_');
  }

  @override
  Future<WeeklyMenuPlan?> fetchForWeek({
    required String userId,
    required DateTime weekStart,
  }) async {
    final docId = IsoWeekUtils.weekIdFor(userId, weekStart);
    // Cache-first so a previously-viewed week resolves instantly offline. A
    // never-cached week falls back to the server.
    //
    // `acceptCachedAbsence` because an empty week has no document, so without it
    // "this week is empty" and "I could not reach the server" arrive as the same
    // throw, and BUT-1939's refusal blocks planning a fresh week offline
    // (BUT-1961). The flag only applies once the server read has already failed.
    //
    // This is NOT a display-only read: `WeeklyMenuPlanService._loadPlanForWrite`
    // and `copyWeek` reach it from write paths, and a `null` there becomes an
    // empty plan that `save()` writes back with `set()`. So a stale absence lets
    // a write build on "empty". What bounds it is `firestore.rules`' update
    // limb, which refuses a changed `createdAt` — the server keeps whatever
    // another device wrote, and the user loses their own local edit instead.
    // That trade is recorded in `docs/architecture/ACCEPTED_DEVIATIONS.md`.
    final snapshot = await getDocCacheFirst(
      collection.doc(docId),
      acceptCachedAbsence: true,
    );
    if (!snapshot.exists) return null;
    return fromFirestore(snapshot);
  }

  @override
  Future<void> save(WeeklyMenuPlan plan) async {
    // Deterministic upsert on `{uid}_{ISO week}`.
    //
    // Resolved BEFORE the gate, not inside the refusal branch: it is the only
    // client-side authentication assertion on this path, and throwing it from
    // inside the branch would lose the very refusal row this method keeps.
    final actorId = requireCurrentUserId();
    final canWrite = await validateUpdatePermission(plan.userId, plan.id, plan);
    if (!canWrite) {
      // Audit only the REFUSAL. Each granted save wrote a plan document plus
      // an audit document — two writes where one would do. GDPR Art. 30 does
      // not ask for the audit row — it is a
      // register of processing categories and purposes, not an access log
      // (checked 2026-08-29). What remains is the accountability value of
      // being able to show refusals. Malin's call, BUT-1981.
      await logPermissionCheck(
        // The AUTHENTICATED actor — `plan.userId` is the CLAIMED owner. An
        // `audit_logs` create whose uid does not match the caller is refused
        // by the rules, so naming the claim here would lose the row.
        userId: actorId,
        resource: '$collectionName/user:${plan.userId}',
        operation: 'save',
        granted: false,
        details: 'week ${IsoWeekUtils.weekKeyOf(plan.weekStartDate)}',
        auditRepository: auditRepository,
      );
      // Was `return`, which is why a refused save reached the user as silence
      // (BUT-1962).
      throw PermissionDeniedException(
        'Weekly menu plan save denied',
        resource: collectionName,
        operation: 'save',
        userId: plan.userId,
      );
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
      'Deleted ${snapshot.docs.length} weekly menu plans for user ${userId.maskedUserId}',
    );
    return snapshot.docs.length;
  }

  @override
  Future<int> removeRecipeFromAllPlans({
    required String userId,
    required String recipeId,
  }) async {
    final actorId = requireCurrentUserId();
    await validateOwnership(
      currentUserId: actorId,
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    // BUT-893: logged once at the user level, not per plan — the cascade is
    // naturally one-per-user, so a row per document would say the same thing
    // N times.
    await logPermissionCheck(
      userId: actorId,
      resource: '$collectionName/user:$userId',
      operation: 'removeRecipeFromAllPlans',
      granted: true,
      auditRepository: auditRepository,
    );

    // Doc-ID prefix range gives us only this user's plans — same trick as
    // deleteAllByUser. Typical user has 4–12 plans so a single read +
    // in-memory filter is cheap; saves an extra denormalized index.
    final snapshot = await collection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
        .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final affected = <DocumentSnapshot<Map<String, dynamic>>>[];
    final scrubbedEntries = <List<dynamic>>[];

    for (final doc in snapshot.docs) {
      final plan = fromFirestore(doc);
      final filteredEntries = plan.entries
          .where((e) => e.recipeId != recipeId)
          .toList();
      if (filteredEntries.length == plan.entries.length) continue;
      affected.add(doc);
      // Run through toFirestore so the entries match the on-disk shape
      // (timestamps, sentinels, etc.) but only extract the entries field
      // — see batch.update below.
      final scrubbed = plan.copyWith(entries: filteredEntries);
      final asMap = toFirestore(scrubbed);
      scrubbedEntries.add(asMap['entries'] as List<dynamic>);
    }

    if (affected.isEmpty) return 0;

    final batch = firestore.batch();
    for (var i = 0; i < affected.length; i++) {
      // batch.update (not set) so concurrent writers can't lose fields
      // added outside the entries array — partial update by design.
      batch.update(affected[i].reference, {'entries': scrubbedEntries[i]});
    }
    await batch.commit();

    AppLogger.info(
      'Scrubbed recipe $recipeId from ${affected.length} weekly plan(s) for ${userId.maskedUserId}',
    );
    return affected.length;
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 260,
  }) async {
    // GDPR Article 20: caller must be exporting their own data. Doc-ID
    // prefix already binds rows to userId, but ownership assertion here
    // guards against a misuse where a caller passes another userId.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${userId}_')
        .where(FieldPath.documentId, isLessThan: '${userId}_\uf8ff')
        .limit(maxDocuments)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
