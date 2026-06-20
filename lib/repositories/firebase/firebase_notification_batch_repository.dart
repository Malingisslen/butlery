import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_batch.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// Firebase implementation for notification batch aggregation.
/// Uses `notification_batches` collection.
class FirebaseNotificationBatchRepository
    extends BaseFirebaseRepository<NotificationBatch>
    implements NotificationBatchRepository {
  FirebaseNotificationBatchRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.notificationBatches;

  @override
  NotificationBatch fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      NotificationBatch.fromMap(doc.id, doc.data()!);

  @override
  Map<String, dynamic> toFirestore(NotificationBatch entity) => entity.toMap();

  @override
  String getId(NotificationBatch entity) => entity.batchKey;

  @override
  Future<bool> validateCreatePermission(
          String userId, NotificationBatch entity) async =>
      entity.userId == userId;

  @override
  Future<bool> validateReadPermission(
          String userId, String resourceId, NotificationBatch? entity) async =>
      entity?.userId == userId;

  @override
  Future<bool> validateUpdatePermission(
          String userId, String resourceId, NotificationBatch entity) async =>
      entity.userId == userId;

  @override
  Future<bool> validateDeletePermission(
          String userId, String resourceId) async =>
      true; // Batch cleanup is allowed for authenticated users

  String get _userId => requireCurrentUserId();

  @override
  Future<void> addToBatch({
    required String batchKey,
    required NotificationTemplate notification,
    required Duration batchWindow,
  }) async {
    try {
      final batchDoc = collection.doc(batchKey);
      final appendData = {
        'notifications': FieldValue.arrayUnion([notification.toMap()]),
        'count': FieldValue.increment(1),
        'lastUpdated': timestampProvider.serverTimestamp(),
      };

      try {
        // Append to existing batch (preserves createdAt/scheduledFor)
        await batchDoc.update(appendData);
      } on FirebaseException catch (e) {
        if (e.code == 'not-found') {
          // First notification — use literal values (sentinels invalid in bare set)
          await batchDoc.set({
            'userId': _userId,
            'batchKey': batchKey,
            'notifications': [notification.toMap()],
            'count': 1,
            'lastUpdated': timestampProvider.serverTimestamp(),
            'createdAt': timestampProvider.serverTimestamp(),
            'scheduledFor': Timestamp.fromDate(clock.now().add(batchWindow)),
          });
        } else {
          rethrow;
        }
      }
    } catch (e) {
      AppLogger.error('Failed to add notification to batch', e);
      rethrow;
    }
  }

  @override
  Future<List<NotificationBatch>> getPendingBatches() async {
    final now = Timestamp.now();
    final query = await collection
        .where('userId', isEqualTo: _userId)
        .where('scheduledFor', isLessThanOrEqualTo: now)
        .get();

    return query.docs.map((doc) => fromFirestore(doc)).toList();
  }

  @override
  Future<NotificationBatch?> getBatchByKey(String batchKey) async {
    try {
      final doc = await collection.doc(batchKey).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return fromFirestore(doc);
    } catch (e) {
      AppLogger.error('Failed to get batch by key: $batchKey', e);
      return null;
    }
  }

  @override
  Future<void> removeBatch(String batchKey) async {
    try {
      await collection.doc(batchKey).delete();
    } catch (e) {
      AppLogger.error('Failed to remove batch', e);
      rethrow;
    }
  }

  @override
  Future<int> deleteAllByUser(String userId) async {
    // GDPR cascade: caller must be deleting their own data.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection.where('userId', isEqualTo: userId).get();
    if (snapshot.docs.isEmpty) return 0;
    await batchDeleteDocs(firestore, snapshot.docs);
    AppLogger.info(
        'Deleted ${snapshot.docs.length} notification_batches for user ${userId.maskedUserId}');
    return snapshot.docs.length;
  }
}
