import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/repositories/interfaces/activity_event_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// Firebase implementation for social activity events.
///
/// Top-level collection (not user-scoped) — events are queried across users
/// via batched `whereIn` on actorId.
class FirebaseActivityEventRepository
    extends BaseFirebaseRepository<ActivityEvent>
    implements ActivityEventRepository {
  FirebaseActivityEventRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.activityEvents;

  @override
  ActivityEvent fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ActivityEvent.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(ActivityEvent entity) =>
      entity.toFirestore();

  @override
  String getId(ActivityEvent entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(
      String userId, ActivityEvent entity) async {
    return entity.actorId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, ActivityEvent? entity) async {
    return true; // Friend filtering is query-level
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, ActivityEvent entity) async {
    return entity.actorId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    return true; // Deletion allowed for own events via GDPR cascade
  }

  @override
  Future<void> addEvent(ActivityEvent event) async {
    final userId = requireCurrentUserId();
    final canCreate = await validateCreatePermission(userId, event);

    await logPermissionCheck(
      userId: userId,
      resource: '$collectionName/${event.id}',
      operation: 'create',
      granted: canCreate,
      auditRepository: auditRepository,
    );

    if (!canCreate) {
      throw PermissionDeniedException(
        'User $userId does not have permission to create activity event',
      );
    }

    // Batch the event create with a rate-limit marker so the firestore.rules
    // `rateLimitWrite('activity_events', 2)` gate is actually armed. Without
    // this doc the rule always takes the `!exists(limitsPath)` branch and the
    // 2-second burst guard never fires.
    final batch = firestore.batch();
    batch.set(collection.doc(event.id), toFirestore(event));
    batch.set(
      firestore
          .collection(FirestoreCollections.users)
          .doc(userId)
          .collection(FirestoreCollections.userRateLimits)
          .doc(FirestoreCollections.activityEvents),
      {
        'lastWrite': timestampProvider.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(clock.now().add(const Duration(days: 90))),
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    AppLogger.info('ActivityEvent created: ${event.id}');
  }

  @override
  Future<List<ActivityEvent>> fetchFriendActivity({
    required List<String> friendIds,
    int limit = 20,
    DateTime? before,
  }) async {
    if (friendIds.isEmpty) return [];

    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[];

    for (final batch in friendIds.chunked(kFirestoreWhereInLimit)) {
      Query<Map<String, dynamic>> query = collection
          .where('actorId', whereIn: batch)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (before != null) {
        query = query.startAfter([Timestamp.fromDate(before)]);
      }

      futures.add(query.get());
    }

    final snapshots = await Future.wait(futures);
    final allEvents = snapshots
        .expand((s) => s.docs)
        .map((doc) => fromFirestore(doc))
        .toList();

    // Merge and sort across batches
    allEvents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allEvents.take(limit).toList();
  }

  @override
  Future<List<ActivityEvent>> getEventsByUser(String userId) async {
    final snapshot = await collection
        .where('actorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> exportEventsByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    // GDPR Article 20: caller must be exporting their own events.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection
        .where('actorId', isEqualTo: userId)
        .limit(maxDocuments)
        .get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }

  @override
  Future<int> deleteAllByUser(String userId) async {
    // GDPR cascade: caller must be deleting their own data. Admin-driven
    // moderator deletes go through `delete()` per-doc, not this bulk path.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection.where('actorId', isEqualTo: userId).get();

    if (snapshot.docs.isEmpty) return 0;

    await batchDeleteDocs(firestore, snapshot.docs);
    AppLogger.info(
        'Deleted ${snapshot.docs.length} activity events for user ${userId.maskedUserId}');
    return snapshot.docs.length;
  }
}
