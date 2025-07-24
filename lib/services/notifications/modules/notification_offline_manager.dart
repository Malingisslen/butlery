// lib/services/notifications/modules/notification_offline_manager.dart

import 'dart:async';
import '../notification_types.dart';
import '../../../core/utils/logger.dart';

/// Focused module for offline notification queue management
/// 
/// This module handles ONLY offline notification responsibilities:
/// - Offline notification queuing when network is unavailable
/// - Online/offline status tracking and management
/// - Automatic queue processing when connectivity is restored
/// - Retry logic for failed notifications
/// - Queue persistence and cleanup
/// 
/// ❌ DOES NOT CONTAIN: FCM token management, content generation, preferences, analytics
class NotificationOfflineManager {
  final String _userId;
  
  // In-memory queue for offline notifications
  final List<PendingNotification> _offlineQueue = [];
  
  // Online status tracking
  bool _isOnline = true;
  
  // Optional callback for when notifications need to be actually sent
  Future<void> Function(PendingNotification)? _sendNotificationCallback;
  
  // Queue processing state
  bool _isProcessingQueue = false;
  Timer? _retryTimer;

  NotificationOfflineManager({
    required String userId,
    Future<void> Function(PendingNotification)? sendNotificationCallback,
  }) : _userId = userId, _sendNotificationCallback = sendNotificationCallback;

  // ===== QUEUE MANAGEMENT =====

  /// Queue notification for offline processing
  /// 
  /// Called when a notification fails to send due to network issues
  void queueNotificationForOffline({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) {
    try {
      final pendingNotification = PendingNotification(
        targetUserIds: targetUserIds,
        strategy: strategy,
        variables: variables,
        additionalData: additionalData,
        imageUrl: imageUrl,
        actions: actions,
        queuedAt: DateTime.now(),
        retryCount: 0,
      );

      _offlineQueue.add(pendingNotification);
      
      AppLogger.info('📋 Queued notification for offline processing (queue size: ${_offlineQueue.length})');
      AppLogger.debug('🔔 Queued notification: ${strategy.category.name} for ${targetUserIds.length} users');
      
      // Limit queue size to prevent memory issues
      _limitQueueSize();
    } catch (e) {
      AppLogger.error('❌ Failed to queue notification for offline processing', e);
    }
  }

  /// Add notification directly to queue (for testing or manual queuing)
  void addToQueue(PendingNotification notification) {
    _offlineQueue.add(notification);
    _limitQueueSize();
    AppLogger.debug('📋 Added notification to offline queue');
  }

  /// Get current queue size
  int get queueSize => _offlineQueue.length;

  /// Check if queue is empty
  bool get isQueueEmpty => _offlineQueue.isEmpty;

  /// Get list of queued notifications (copy for safety)
  List<PendingNotification> get queuedNotifications => 
      List<PendingNotification>.from(_offlineQueue);

  // ===== STATUS MANAGEMENT =====

  /// Update online status and trigger queue processing if coming online
  void setOnlineStatus(bool isOnline) {
    if (_isOnline != isOnline) {
      final wasOffline = !_isOnline;
      _isOnline = isOnline;
      
      AppLogger.info('🔔 Notification service online status changed: $_isOnline');
      
      if (isOnline && wasOffline && _offlineQueue.isNotEmpty) {
        AppLogger.info('🌐 Coming back online with ${_offlineQueue.length} queued notifications');
        // Use a small delay to ensure network is stable
        Timer(const Duration(seconds: 2), () {
          processOfflineQueue();
        });
      } else if (!isOnline) {
        AppLogger.info('📡 Going offline, notifications will be queued');
        _cancelRetryTimer();
      }
    }
  }

  /// Get current online status
  bool get isOnline => _isOnline;

  // ===== QUEUE PROCESSING =====

  /// Process offline notification queue
  /// 
  /// Attempts to send all queued notifications when back online
  Future<void> processOfflineQueue() async {
    if (_isProcessingQueue) {
      AppLogger.debug('📋 Queue processing already in progress, skipping');
      return;
    }

    if (_offlineQueue.isEmpty) {
      AppLogger.debug('📋 Offline queue is empty, nothing to process');
      return;
    }

    if (!_isOnline) {
      AppLogger.debug('📋 Still offline, cannot process queue');
      return;
    }

    _isProcessingQueue = true;
    
    try {
      AppLogger.info('🔔 Processing ${_offlineQueue.length} offline notifications');

      final queueCopy = List<PendingNotification>.from(_offlineQueue);
      _offlineQueue.clear();

      int successCount = 0;
      int failureCount = 0;

      for (final notification in queueCopy) {
        try {
          // Check if notification is too old (older than 24 hours)
          if (_isNotificationExpired(notification)) {
            AppLogger.warning('⏰ Discarding expired notification from ${notification.queuedAt}');
            continue;
          }

          // Use callback if provided, otherwise log
          if (_sendNotificationCallback != null) {
            await _sendNotificationCallback!(notification);
          } else {
            AppLogger.info('📋 Would send queued ${notification.strategy.category.name} notification');
          }
          
          successCount++;
          AppLogger.debug('✅ Successfully sent queued notification');
          
        } catch (e) {
          AppLogger.error('❌ Failed to send queued notification', e);
          failureCount++;
          
          // Re-queue with increased retry count if not exceeded
          final updatedNotification = notification.withIncrementedRetry();
          if (updatedNotification.retryCount <= 3) {
            _offlineQueue.add(updatedNotification);
            AppLogger.info('🔄 Re-queued notification (retry ${updatedNotification.retryCount}/3)');
          } else {
            AppLogger.warning('⚠️ Discarding notification after 3 failed retries');
          }
        }
      }

      AppLogger.success('✅ Processed offline queue: $successCount successful, $failureCount failed');
      
      // Schedule retry for failed notifications
      if (_offlineQueue.isNotEmpty) {
        _scheduleRetry();
      }
      
    } catch (e) {
      AppLogger.error('❌ Failed to process offline queue', e);
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Process queue manually (for testing or manual trigger)
  Future<void> forceProcessQueue() async {
    AppLogger.info('🔄 Manually forcing queue processing');
    await processOfflineQueue();
  }

  // ===== QUEUE MAINTENANCE =====

  /// Clear all queued notifications
  void clearQueue() {
    final queueSize = _offlineQueue.length;
    _offlineQueue.clear();
    _cancelRetryTimer();
    
    AppLogger.info('🗑️ Cleared offline notification queue ($queueSize notifications removed)');
  }

  /// Remove expired notifications from queue
  int cleanupExpiredNotifications() {
    try {
      final initialSize = _offlineQueue.length;
      _offlineQueue.removeWhere(_isNotificationExpired);
      final removedCount = initialSize - _offlineQueue.length;
      
      if (removedCount > 0) {
        AppLogger.info('🧹 Cleaned up $removedCount expired notifications from queue');
      }
      
      return removedCount;
    } catch (e) {
      AppLogger.error('❌ Failed to cleanup expired notifications', e);
      return 0;
    }
  }

  /// Get queue statistics
  Map<String, dynamic> getQueueStatistics() {
    final stats = <String, int>{};
    final now = DateTime.now();
    
    for (final notification in _offlineQueue) {
      final category = notification.strategy.category.name;
      stats[category] = (stats[category] ?? 0) + 1;
    }
    
    final oldestNotification = _offlineQueue.isEmpty 
        ? null 
        : _offlineQueue.reduce((a, b) => 
            a.queuedAt.isBefore(b.queuedAt) ? a : b);
    
    return {
      'total_count': _offlineQueue.length,
      'categories': stats,
      'is_online': _isOnline,
      'is_processing': _isProcessingQueue,
      'oldest_notification_age_minutes': oldestNotification != null
          ? now.difference(oldestNotification.queuedAt).inMinutes
          : null,
    };
  }

  // ===== PRIVATE HELPER METHODS =====

  /// Limit queue size to prevent memory issues
  void _limitQueueSize() {
    const maxQueueSize = 100;
    
    if (_offlineQueue.length > maxQueueSize) {
      // Remove oldest notifications first
      _offlineQueue.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
      final removedCount = _offlineQueue.length - maxQueueSize;
      _offlineQueue.removeRange(0, removedCount);
      
      AppLogger.warning('⚠️ Offline queue exceeded max size, removed $removedCount oldest notifications');
    }
  }

  /// Check if notification is expired (older than 24 hours)
  bool _isNotificationExpired(PendingNotification notification) {
    const maxAge = Duration(hours: 24);
    return DateTime.now().difference(notification.queuedAt) > maxAge;
  }

  /// Schedule retry for failed notifications
  void _scheduleRetry() {
    _cancelRetryTimer();
    
    // Retry in 5 minutes
    _retryTimer = Timer(const Duration(minutes: 5), () {
      if (_isOnline && _offlineQueue.isNotEmpty) {
        AppLogger.info('🔄 Retrying failed notifications');
        processOfflineQueue();
      }
    });
  }

  /// Cancel scheduled retry timer
  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // ===== LIFECYCLE METHODS =====

  /// Set callback for actually sending notifications
  void setSendNotificationCallback(Future<void> Function(PendingNotification) callback) {
    _sendNotificationCallback = callback;
  }

  /// Dispose resources and cleanup
  void dispose() {
    AppLogger.info('🔔 Disposing NotificationOfflineManager for user $_userId');
    
    _cancelRetryTimer();
    clearQueue();
    _sendNotificationCallback = null;
    
    AppLogger.debug('✅ NotificationOfflineManager disposed');
  }
}

/// Pending notification data structure for offline queue
class PendingNotification {
  final List<String> targetUserIds;
  final NotificationStrategy strategy;
  final Map<String, String> variables;
  final Map<String, dynamic>? additionalData;
  final String? imageUrl;
  final List<NotificationAction>? actions;
  final DateTime queuedAt;
  final int retryCount;

  const PendingNotification({
    required this.targetUserIds,
    required this.strategy,
    required this.variables,
    this.additionalData,
    this.imageUrl,
    this.actions,
    required this.queuedAt,
    this.retryCount = 0,
  });

  /// Create a copy with incremented retry count
  PendingNotification withIncrementedRetry() {
    return PendingNotification(
      targetUserIds: targetUserIds,
      strategy: strategy,
      variables: variables,
      additionalData: additionalData,
      imageUrl: imageUrl,
      actions: actions,
      queuedAt: queuedAt,
      retryCount: retryCount + 1,
    );
  }

  /// Convert to map for debugging/logging
  Map<String, dynamic> toMap() {
    return {
      'target_user_count': targetUserIds.length,
      'strategy_category': strategy.category.name,
      'strategy_type': strategy.type.name,
      'queued_at': queuedAt.toIso8601String(),
      'retry_count': retryCount,
      'variables': variables,
    };
  }

  @override
  String toString() {
    return 'PendingNotification(${strategy.category.name}/${strategy.type.name}, '
           '${targetUserIds.length} users, retry: $retryCount)';
  }
}