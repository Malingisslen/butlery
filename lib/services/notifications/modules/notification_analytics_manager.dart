// lib/services/notifications/modules/notification_analytics_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:get_it/get_it.dart';

/// Notification analytics with delivery tracking and engagement metrics.
/// Follows SRP - handles only analytics (not FCM, content, preferences, or batching).
/// ```dart
/// await manager.recordNotificationSent(id, category, type, userId, metadata);
/// await manager.recordNotificationOpened(id); final metrics = await manager.getUserEngagementSummary();
/// ```
class NotificationAnalyticsManager {
  final FirebaseFirestore _firestore;
  final String _userId;

  // Collections for analytics data
  static const String _deliveryCollection = 'notification_delivery';
  static const String _engagementCollection = 'notification_engagement';

  // In-memory cache for recent events to batch writes
  final List<Map<String, dynamic>> _pendingEvents = [];
  static const int _batchSize = 10;

  NotificationAnalyticsManager({
    required String userId,
  })  : _firestore = GetIt.instance<FirebaseFirestore>(),
        _userId = userId;

  /// Record notification sent (call after FCM send attempt)
  Future<void> recordNotificationSent({
    required String notificationId,
    required NotificationCategory category,
    required NotificationType type,
    required String targetUserId,
    required Map<String, dynamic> metadata,
  }) async {
    try {
      final deliveryEvent = {
        'notificationId': notificationId,
        'senderId': _userId,
        'targetUserId': targetUserId,
        'category': category.name,
        'type': type.name,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        'metadata': metadata,
      };

      // Batch this write for performance
      _pendingEvents.add(deliveryEvent);

      AppLogger.debug('📊 Recorded notification sent: $notificationId');
      await _flushPendingEventsIfNeeded();
    } catch (e) {
      AppLogger.error('❌ Failed to record notification sent', e);
    }
  }

  /// Record notification delivered to device (FCM confirmation from background handler)
  Future<void> recordNotificationDelivered({
    required String notificationId,
    Map<String, dynamic>? deliveryMetadata,
  }) async {
    try {
      await _firestore
          .collection(_deliveryCollection)
          .doc(notificationId)
          .update({
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
        'deliveryMetadata': deliveryMetadata ?? {},
      });

      AppLogger.debug('📊 Recorded notification delivered: $notificationId');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification delivered: $e');
    }
  }

  /// Record that a notification failed to deliver
  Future<void> recordNotificationFailed({
    required String notificationId,
    required String errorCode,
    String? errorMessage,
  }) async {
    try {
      await _firestore
          .collection(_deliveryCollection)
          .doc(notificationId)
          .update({
        'status': 'failed',
        'failedAt': FieldValue.serverTimestamp(),
        'errorCode': errorCode,
        'errorMessage': errorMessage,
      });

      AppLogger.debug(
          '📊 Recorded notification failed: $notificationId ($errorCode)');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification failure: $e');
    }
  }

  /// Record notification opened (user tapped notification)
  Future<void> recordNotificationOpened({
    required String notificationId,
    Map<String, dynamic>? context,
  }) async {
    try {
      final engagementEvent = {
        'notificationId': notificationId,
        'userId': _userId,
        'action': 'opened',
        'timestamp': FieldValue.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        'context': context ?? {},
      };

      await _firestore.collection(_engagementCollection).add(engagementEvent);

      // Also update the delivery record
      await _firestore
          .collection(_deliveryCollection)
          .doc(notificationId)
          .update({
        'opened': true,
        'openedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('📊 Recorded notification opened: $notificationId');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification opened: $e');
    }
  }

  /// Record that a notification was dismissed by user
  Future<void> recordNotificationDismissed({
    required String notificationId,
    String? dismissalReason,
  }) async {
    try {
      final engagementEvent = {
        'notificationId': notificationId,
        'userId': _userId,
        'action': 'dismissed',
        'timestamp': FieldValue.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        'reason': dismissalReason,
      };

      await _firestore.collection(_engagementCollection).add(engagementEvent);

      AppLogger.debug('📊 Recorded notification dismissed: $notificationId');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification dismissed: $e');
    }
  }

  /// Record notification action taken (action buttons like "Accept", "Decline")
  Future<void> recordNotificationActionTaken({
    required String notificationId,
    required String actionId,
    Map<String, dynamic>? actionData,
  }) async {
    try {
      final engagementEvent = {
        'notificationId': notificationId,
        'userId': _userId,
        'action': 'action_taken',
        'actionId': actionId,
        'timestamp': FieldValue.serverTimestamp(),
        'expireAt':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 90))),
        'actionData': actionData ?? {},
      };

      await _firestore.collection(_engagementCollection).add(engagementEvent);

      AppLogger.info(
          '📊 Recorded notification action taken: $notificationId ($actionId)');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification action: $e');
    }
  }

  /// Get user engagement summary
  Future<Map<String, dynamic>> getUserEngagementSummary({
    Duration? period,
  }) async {
    try {
      final since = DateTime.now().subtract(period ?? const Duration(days: 30));

      // Get delivery stats
      final deliveryQuery = await _firestore
          .collection(_deliveryCollection)
          .where('targetUserId', isEqualTo: _userId)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(since))
          .get();

      // Get engagement stats
      final engagementQuery = await _firestore
          .collection(_engagementCollection)
          .where('userId', isEqualTo: _userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .get();

      return _calculateEngagementSummary(
          deliveryQuery.docs, engagementQuery.docs);
    } catch (e) {
      AppLogger.error('❌ Failed to get user engagement summary', e);
      return {};
    }
  }

  Map<String, dynamic> _calculateEngagementSummary(
    List<QueryDocumentSnapshot> deliveryDocs,
    List<QueryDocumentSnapshot> engagementDocs,
  ) {
    final received = deliveryDocs
        .where((doc) =>
            (doc.data() as Map<String, dynamic>)['status'] == 'delivered')
        .length;

    final actions = <String, int>{};
    for (final doc in engagementDocs) {
      final action = (doc.data() as Map<String, dynamic>)['action'] as String;
      actions[action] = (actions[action] ?? 0) + 1;
    }

    final opened = actions['opened'] ?? 0;
    final dismissed = actions['dismissed'] ?? 0;
    final actionsTaken = actions['action_taken'] ?? 0;

    return {
      'notifications_received': received,
      'notifications_opened': opened,
      'notifications_dismissed': dismissed,
      'actions_taken': actionsTaken,
      'open_rate': received > 0 ? opened / received : 0.0,
      'engagement_rate':
          received > 0 ? (opened + actionsTaken) / received : 0.0,
      'dismissal_rate': received > 0 ? dismissed / received : 0.0,
    };
  }

  Future<void> _flushPendingEventsIfNeeded() async {
    if (_pendingEvents.length >= _batchSize) {
      await _flushPendingEvents();
    }
  }

  Future<void> _flushPendingEvents() async {
    if (_pendingEvents.isEmpty) return;

    try {
      final batch = _firestore.batch();

      for (final event in _pendingEvents) {
        final docRef = _firestore.collection(_deliveryCollection).doc();
        batch.set(docRef, event);
      }

      await batch.commit();

      AppLogger.debug('📊 Flushed ${_pendingEvents.length} analytics events');
      _pendingEvents.clear();
    } catch (e) {
      AppLogger.error('❌ Failed to flush analytics events', e);
    }
  }

  Future<void> dispose() async {
    AppLogger.info(
        '📊 Disposing NotificationAnalyticsManager for user $_userId');

    await _flushPendingEvents();

    AppLogger.debug('✅ NotificationAnalyticsManager disposed');
  }
}
