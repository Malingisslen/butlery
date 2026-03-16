import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

/// Firebase implementation for notification dedup and delivery tracking.
/// Uses `notification_history` collection.
class FirebaseNotificationHistoryRepository
    implements NotificationHistoryRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final TimestampProvider _timestampProvider;

  FirebaseNotificationHistoryRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    TimestampProvider? timestampProvider,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository,
        _timestampProvider =
            timestampProvider ?? const ServerTimestampProvider();

  String get _userId {
    final id = _authRepository.currentUserId;
    if (id == null) {
      throw StateError('NotificationHistoryRepository: No authenticated user');
    }
    return id;
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.notificationHistory);

  @override
  Future<void> recordNotification({
    required String notificationId,
    required NotificationCategory category,
    required NotificationType type,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _collection.doc(notificationId).set({
        'userId': _userId,
        'notificationId': notificationId,
        'category': category.name,
        'type': type.name,
        'data': data,
        'sentAt': _timestampProvider.serverTimestamp(),
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
      final doc = await _collection.doc(notificationId).get();
      return doc.exists && doc.data() != null;
    } catch (e) {
      AppLogger.error('Failed to check notification history', e);
      return false;
    }
  }

  @override
  Future<void> markNotificationDelivered(String notificationId) async {
    try {
      await _collection.doc(notificationId).update({
        'delivered': true,
        'deliveredAt': _timestampProvider.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Failed to mark notification as delivered: $e');
    }
  }

  @override
  Future<void> markNotificationOpened(String notificationId) async {
    try {
      await _collection.doc(notificationId).update({
        'opened': true,
        'openedAt': _timestampProvider.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.warning('Failed to mark notification as opened: $e');
    }
  }

  @override
  Future<void> cleanupOldHistory(DateTime olderThan) async {
    try {
      final cutoffTimestamp = Timestamp.fromDate(olderThan);
      final query = await _collection
          .where('userId', isEqualTo: _userId)
          .where('sentAt', isLessThan: cutoffTimestamp)
          .limit(100)
          .get();

      final batch = _firestore.batch();
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
