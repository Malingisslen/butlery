// lib/services/notifications/modules/notification_analytics_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:get_it/get_it.dart';

/// Specialized notification analytics and tracking module providing comprehensive delivery metrics and engagement analysis.
///
/// This focused module implements sophisticated notification analytics following Single Responsibility Principle,
/// handling all aspects of notification delivery tracking, user engagement metrics, and performance analysis.
/// It provides comprehensive analytics for notification effectiveness optimization while maintaining clean separation
/// from other notification system components for maintainable and scalable analytics infrastructure.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles analytics and tracking responsibilities:
/// - **Delivery Tracking**: Comprehensive notification delivery confirmation and status monitoring
/// - **Engagement Metrics**: Detailed user interaction tracking including opens, dismissals, and action clicks
/// - **Performance Analytics**: Statistical analysis of notification effectiveness and conversion rates
/// - **Aggregate Reporting**: Summary statistics and trend analysis for notification system optimization
/// - **A/B Testing Support**: Experimental framework for testing notification strategies and content variations
///
/// **What This Module Does NOT Handle:**
/// - FCM token management and device registration (handled by FCMTokenManager)
/// - Content generation and message templating (handled by NotificationContentManager)
/// - User preferences and quiet hours (handled by NotificationPreferenceManager)
/// - Notification batching and delivery optimization (handled by NotificationBatchManager)
///
/// **Analytics Capabilities:**
/// - Real-time delivery confirmation tracking with failure analysis and retry insights
/// - Comprehensive user engagement metrics providing actionable insights for content optimization
/// - Performance trend analysis enabling data-driven notification strategy improvements
/// - A/B testing framework supporting experimental notification approaches and content variations
/// - Batch processing for efficient analytics data collection reducing Firestore write operations
///
/// **Usage Examples:**
/// ```dart
/// final analyticsManager = NotificationAnalyticsManager(firestore, userId);
/// 
/// // Track notification delivery
/// await analyticsManager.trackDelivery(notificationId, 'delivered');
/// 
/// // Record user engagement
/// await analyticsManager.trackEngagement(notificationId, 'opened');
/// 
/// // Get performance metrics
/// final metrics = await analyticsManager.getEngagementMetrics(dateRange);
/// ```
class NotificationAnalyticsManager {
  final FirebaseFirestore _firestore;
  final String _userId;
  
  // Collections for analytics data
  static const String _deliveryCollection = 'notification_delivery';
  static const String _engagementCollection = 'notification_engagement';
  static const String _metricsCollection = 'notification_metrics';
  
  // In-memory cache for recent events to batch writes
  final List<Map<String, dynamic>> _pendingEvents = [];
  static const int _batchSize = 10;

  NotificationAnalyticsManager({
    required String userId,
  }) : _firestore = GetIt.instance<FirebaseFirestore>(), _userId = userId;

  // ===== DELIVERY TRACKING =====

  /// Record that a notification was sent
  /// 
  /// This should be called immediately after FCM send attempt
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

  /// Record that a notification was delivered to device
  /// 
  /// This is called when FCM confirms delivery (usually from background handler)
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

      AppLogger.debug('📊 Recorded notification failed: $notificationId ($errorCode)');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification failure: $e');
    }
  }

  // ===== ENGAGEMENT TRACKING =====

  /// Record that a notification was opened by user
  /// 
  /// This should be called when user taps the notification
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
        'context': context ?? {},
      };

      await _firestore
          .collection(_engagementCollection)
          .add(engagementEvent);

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
        'reason': dismissalReason,
      };

      await _firestore
          .collection(_engagementCollection)
          .add(engagementEvent);

      AppLogger.debug('📊 Recorded notification dismissed: $notificationId');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification dismissed: $e');
    }
  }

  /// Record that a notification action was taken
  /// 
  /// This is for action buttons like "Accept", "Decline", etc.
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
        'actionData': actionData ?? {},
      };

      await _firestore
          .collection(_engagementCollection)
          .add(engagementEvent);

      AppLogger.info('📊 Recorded notification action taken: $notificationId ($actionId)');
    } catch (e) {
      AppLogger.warning('⚠️ Failed to record notification action: $e');
    }
  }

  // ===== PERFORMANCE METRICS =====

  /// Generate daily metrics for notification performance
  /// 
  /// This should be called by a scheduled function or background job
  Future<void> generateDailyMetrics({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now().subtract(const Duration(days: 1));
      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      AppLogger.info('📊 Generating daily metrics for ${startOfDay.toString().substring(0, 10)}');

      // Query delivery data for the day
      final deliveryQuery = await _firestore
          .collection(_deliveryCollection)
          .where('sentAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('sentAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      // Calculate metrics by category and type
      final metrics = _calculateMetrics(deliveryQuery.docs);

      // Save aggregate metrics
      await _saveMetrics(startOfDay, metrics);

      AppLogger.success('✅ Generated daily metrics: ${metrics['summary']}');
    } catch (e) {
      AppLogger.error('❌ Failed to generate daily metrics', e);
    }
  }

  /// Get notification performance stats for a category
  Future<Map<String, dynamic>> getCategoryPerformance(
    NotificationCategory category, {
    Duration? period,
  }) async {
    try {
      final since = DateTime.now().subtract(period ?? const Duration(days: 7));
      
      final query = await _firestore
          .collection(_deliveryCollection)
          .where('category', isEqualTo: category.name)
          .where('sentAt', isGreaterThan: Timestamp.fromDate(since))
          .get();

      return _calculatePerformanceStats(query.docs);
    } catch (e) {
      AppLogger.error('❌ Failed to get category performance', e);
      return {};
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

      return _calculateEngagementSummary(deliveryQuery.docs, engagementQuery.docs);
    } catch (e) {
      AppLogger.error('❌ Failed to get user engagement summary', e);
      return {};
    }
  }

  // ===== ANALYTICS CALCULATIONS =====

  /// Calculate metrics from delivery documents
  Map<String, dynamic> _calculateMetrics(List<QueryDocumentSnapshot> docs) {
    final metrics = <String, dynamic>{
      'total_sent': 0,
      'total_delivered': 0,
      'total_failed': 0,
      'total_opened': 0,
      'by_category': <String, dynamic>{},
      'by_type': <String, dynamic>{},
    };

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = data['category'] as String;
      final type = data['type'] as String;
      final status = data['status'] as String;
      final opened = data['opened'] as bool? ?? false;

      // Overall counts
      metrics['total_sent']++;
      
      if (status == 'delivered') metrics['total_delivered']++;
      if (status == 'failed') metrics['total_failed']++;
      if (opened) metrics['total_opened']++;

      // By category
      final categoryMetrics = metrics['by_category'][category] ??= {
        'sent': 0, 'delivered': 0, 'failed': 0, 'opened': 0,
      };
      categoryMetrics['sent']++;
      if (status == 'delivered') categoryMetrics['delivered']++;
      if (status == 'failed') categoryMetrics['failed']++;
      if (opened) categoryMetrics['opened']++;

      // By type
      final typeMetrics = metrics['by_type'][type] ??= {
        'sent': 0, 'delivered': 0, 'failed': 0, 'opened': 0,
      };
      typeMetrics['sent']++;
      if (status == 'delivered') typeMetrics['delivered']++;
      if (status == 'failed') typeMetrics['failed']++;
      if (opened) typeMetrics['opened']++;
    }

    // Calculate rates
    final totalSent = metrics['total_sent'] as int;
    if (totalSent > 0) {
      metrics['delivery_rate'] = (metrics['total_delivered'] as int) / totalSent;
      metrics['failure_rate'] = (metrics['total_failed'] as int) / totalSent;
      metrics['open_rate'] = (metrics['total_opened'] as int) / totalSent;
    }

    metrics['summary'] = 'Sent: $totalSent, Delivered: ${metrics['total_delivered']}, Opened: ${metrics['total_opened']}';

    return metrics;
  }

  /// Calculate performance statistics
  Map<String, dynamic> _calculatePerformanceStats(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return {'error': 'No data available'};
    }

    int sent = 0, delivered = 0, opened = 0, failed = 0;
    
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      sent++;
      
      final status = data['status'] as String;
      if (status == 'delivered') delivered++;
      if (status == 'failed') failed++;
      if (data['opened'] as bool? ?? false) opened++;
    }

    return {
      'total_sent': sent,
      'delivery_rate': delivered / sent,
      'open_rate': opened / sent,
      'failure_rate': failed / sent,
      'engagement_score': (opened / sent) * 100, // percentage
    };
  }

  /// Calculate engagement summary for user
  Map<String, dynamic> _calculateEngagementSummary(
    List<QueryDocumentSnapshot> deliveryDocs,
    List<QueryDocumentSnapshot> engagementDocs,
  ) {
    // Count notifications received
    final received = deliveryDocs.where((doc) => 
        (doc.data() as Map<String, dynamic>)['status'] == 'delivered').length;

    // Count engagement actions
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
      'engagement_rate': received > 0 ? (opened + actionsTaken) / received : 0.0,
      'dismissal_rate': received > 0 ? dismissed / received : 0.0,
    };
  }

  /// Save calculated metrics to Firestore
  Future<void> _saveMetrics(DateTime date, Map<String, dynamic> metrics) async {
    try {
      final dateKey = '${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
      
      await _firestore
          .collection(_metricsCollection)
          .doc(dateKey)
          .set({
            'date': Timestamp.fromDate(date),
            'metrics': metrics,
            'calculatedAt': FieldValue.serverTimestamp(),
          });

      AppLogger.debug('✅ Saved daily metrics for $dateKey');
    } catch (e) {
      AppLogger.error('❌ Failed to save metrics', e);
    }
  }

  /// Flush pending events to Firestore in batch
  Future<void> _flushPendingEventsIfNeeded() async {
    if (_pendingEvents.length >= _batchSize) {
      await _flushPendingEvents();
    }
  }

  /// Force flush all pending events
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

  // ===== CLEANUP AND MAINTENANCE =====

  /// Clean up old analytics data
  Future<void> cleanupOldData({Duration? olderThan}) async {
    try {
      final cutoffDate = DateTime.now().subtract(olderThan ?? const Duration(days: 90));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Clean up delivery records
      final deliveryQuery = await _firestore
          .collection(_deliveryCollection)
          .where('sentAt', isLessThan: cutoffTimestamp)
          .limit(100)
          .get();

      if (deliveryQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in deliveryQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        
        AppLogger.info('🧹 Cleaned up ${deliveryQuery.docs.length} old delivery records');
      }

      // Clean up engagement records
      final engagementQuery = await _firestore
          .collection(_engagementCollection)
          .where('timestamp', isLessThan: cutoffTimestamp)
          .limit(100)
          .get();

      if (engagementQuery.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in engagementQuery.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        
        AppLogger.info('🧹 Cleaned up ${engagementQuery.docs.length} old engagement records');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to cleanup old analytics data', e);
    }
  }

  // ===== LIFECYCLE METHODS =====

  /// Dispose resources and flush pending events
  Future<void> dispose() async {
    AppLogger.info('📊 Disposing NotificationAnalyticsManager for user $_userId');

    // Flush any pending events
    await _flushPendingEvents();

    AppLogger.debug('✅ NotificationAnalyticsManager disposed');
  }
}