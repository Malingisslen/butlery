import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/firestore_batch_utils.dart';

/// Firebase implementation for notification dedup and delivery tracking.
/// Uses `notification_history` collection.
class FirebaseNotificationHistoryRepository
    extends BaseFirebaseRepository<Map<String, dynamic>>
    implements NotificationHistoryRepository {
  FirebaseNotificationHistoryRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.notificationHistory;

  @override
  Map<String, dynamic> fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      {'id': doc.id, ...doc.data() ?? {}};

  @override
  Map<String, dynamic> toFirestore(Map<String, dynamic> entity) => entity;

  @override
  String getId(Map<String, dynamic> entity) =>
      entity['notificationId'] as String? ?? '';

  @override
  Future<bool> validateCreatePermission(
          String userId, Map<String, dynamic> entity) async =>
      entity['userId'] == userId;

  @override
  Future<bool> validateReadPermission(String userId, String resourceId,
          Map<String, dynamic>? entity) async =>
      entity?['userId'] == userId;

  @override
  Future<bool> validateUpdatePermission(String userId, String resourceId,
          Map<String, dynamic> entity) async =>
      entity['userId'] == userId;

  @override
  Future<bool> validateDeletePermission(
          String userId, String resourceId) async =>
      true; // History cleanup is allowed for authenticated users

  String get _userId => requireCurrentUserId();

  @override
  Future<void> recordNotification({
    required String notificationId,
    required NotificationCategory category,
    required NotificationType type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await collection.doc(notificationId).set({
        'userId': _userId,
        'notificationId': notificationId,
        'category': category.name,
        'type': type.name,
        'data': data,
        'sentAt': timestampProvider.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(clock.now().add(const Duration(days: 90))),
        'delivered': false,
        'opened': false,
      });
    } catch (e) {
      AppLogger.error('Failed to record notification history', e);
    }
  }

  @override
  Future<bool> wasNotificationSent(String notificationId) async {
    try {
      final doc = await collection.doc(notificationId).get();
      return doc.exists && doc.data() != null;
    } catch (e) {
      AppLogger.error('Failed to check notification history', e);
      return false;
    }
  }

  @override
  Future<void> markNotificationDelivered(String notificationId) async {
    try {
      await collection.doc(notificationId).update({
        'delivered': true,
        'deliveredAt': timestampProvider.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Failed to mark notification as delivered: $e');
    }
  }

  @override
  Future<void> markNotificationOpened(String notificationId) async {
    try {
      await collection.doc(notificationId).update({
        'opened': true,
        'openedAt': timestampProvider.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Failed to mark notification as opened: $e');
    }
  }

  @override
  Future<List<NotificationHistoryEntry>> getHistory(
    String userId, {
    int limit = 20,
    DateTime? before,
  }) async {
    try {
      Query<Map<String, dynamic>> query = collection
          .where('userId', isEqualTo: userId)
          .orderBy('sentAt', descending: true)
          .limit(limit);

      if (before != null) {
        query = query.where('sentAt', isLessThan: Timestamp.fromDate(before));
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => NotificationHistoryEntry.fromFirestore(
              {'id': doc.id, ...doc.data()}))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to fetch notification history', e);
      return [];
    }
  }

  @override
  Future<int> markAllAsOpenedForUser(String userId) async {
    // Owner-only — caller must be marking their own notifications.
    await validateOwnership(
      currentUserId: requireCurrentUserId(),
      resourceOwnerId: userId,
      resourceType: collectionName,
    );

    final snapshot = await collection
        .where('userId', isEqualTo: userId)
        .where('opened', isEqualTo: false)
        .get();
    if (snapshot.docs.isEmpty) return 0;

    // Chunk into 500-op batches (Firestore limit).
    final timestamp = timestampProvider.serverTimestamp();
    for (var i = 0; i < snapshot.docs.length; i += 500) {
      final end =
          (i + 500 < snapshot.docs.length) ? i + 500 : snapshot.docs.length;
      final batch = firestore.batch();
      for (final doc in snapshot.docs.sublist(i, end)) {
        batch.update(doc.reference, {
          'opened': true,
          'openedAt': timestamp,
        });
      }
      await batch.commit();
    }
    AppLogger.info(
        'Marked ${snapshot.docs.length} notifications as opened for user $userId');
    return snapshot.docs.length;
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
        'Deleted ${snapshot.docs.length} notification_history for user $userId');
    return snapshot.docs.length;
  }
}
