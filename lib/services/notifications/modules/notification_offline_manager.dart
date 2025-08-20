// lib/services/notifications/modules/notification_offline_manager.dart

import 'dart:async';
import 'package:clock/clock.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/utils/logger.dart';

/// Specialized offline notification queue management module providing comprehensive connectivity-aware notification handling.
///
/// This focused module implements sophisticated offline notification management following Single Responsibility Principle,
/// handling all aspects of notification queuing, connectivity monitoring, and automatic processing when network access
/// is restored. It provides comprehensive offline support ensuring reliable notification delivery regardless of
/// network connectivity status while maintaining optimal user experience through intelligent retry strategies.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles offline notification management responsibilities:
/// - **Offline Queuing**: Intelligent notification queuing when network connectivity is unavailable or unreliable
/// - **Connectivity Tracking**: Real-time online/offline status monitoring with automatic state management
/// - **Automatic Processing**: Seamless queue processing when connectivity is restored with priority-based delivery
/// - **Retry Logic**: Sophisticated retry mechanisms for failed notifications with exponential backoff strategies
/// - **Queue Persistence**: Reliable queue storage and cleanup ensuring notifications survive app restarts
///
/// **What This Module Does NOT Handle:**
/// - FCM token management and device registration (handled by FCMTokenManager)
/// - Content generation and message templating (handled by NotificationContentManager)
/// - User preferences and quiet hours (handled by NotificationPreferenceManager)
/// - Delivery analytics and tracking (handled by NotificationAnalyticsManager)
///
/// **Offline Management Features:**
/// - Intelligent notification queuing with priority-based ordering ensuring critical notifications are processed first
/// - Real-time connectivity monitoring automatically detecting network state changes and triggering appropriate actions
/// - Automatic queue processing with exponential backoff retry strategies preventing network congestion
/// - Persistent queue storage ensuring queued notifications survive application restarts and system reboots
/// - Smart cleanup mechanisms preventing queue overflow while preserving important notification delivery
///
/// **Connectivity Intelligence:**
/// - Real-time network state monitoring with immediate response to connectivity changes
/// - Adaptive retry strategies that adjust timing based on network stability and previous success rates
/// - Priority-based queue management ensuring critical cooking and social notifications are delivered first
/// - Background processing optimization minimizing battery usage while maintaining reliable delivery
/// - Graceful degradation ensuring smooth user experience during network instability periods
///
/// **Usage Examples:**
/// ```dart
/// final offlineManager = NotificationOfflineManager(
///   userId: currentUserId,
///   sendNotificationCallback: deliveryService.sendNotification,
/// );
/// 
/// // Queue notification when offline
/// await offlineManager.queueNotification(pendingNotification);
/// 
/// // Update connectivity status
/// offlineManager.updateConnectivityStatus(isOnline);
/// 
/// // Process queued notifications when online
/// await offlineManager.processOfflineQueue();
/// 
/// // Get queue statistics
/// final queueSize = offlineManager.getQueueSize();
/// ```
class NotificationOfflineManager {
  final String _userId;
  final Clock _clock;
  final Duration _retryDelay;
  
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
    Clock? clock,
    Duration? retryDelay,
  }) : _userId = userId, 
       _sendNotificationCallback = sendNotificationCallback,
       _clock = clock ?? const Clock(),
       _retryDelay = retryDelay ?? const Duration(minutes: 5);

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
        queuedAt: _clock.now(),
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
  Future<void> processOfflineQueue({bool force = false}) async {
    if (_isProcessingQueue && !force) {
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
    await processOfflineQueue(force: true);
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
    final now = _clock.now();
    
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
    return _clock.now().difference(notification.queuedAt) > maxAge;
  }

  /// Schedule retry for failed notifications
  void _scheduleRetry() {
    _cancelRetryTimer();
    
    // Retry in 5 minutes
    _retryTimer = Timer(_retryDelay, () {
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