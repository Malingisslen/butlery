import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

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
  Future<void> cleanupOldHistory(DateTime olderThan) async {
    try {
      final cutoffTimestamp = Timestamp.fromDate(olderThan);
      final query = await collection
          .where('userId', isEqualTo: _userId)
          .where('sentAt', isLessThan: cutoffTimestamp)
          .limit(100)
          .get();

      final batch = firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      if (query.docs.isNotEmpty) {
        await batch.commit();
        AppLogger.info(
            'Cleaned up ${query.docs.length} old notification history entries');
      }
    } catch (e) {
      AppLogger.error('Failed to cleanup notification history', e);
    }
  }
}
