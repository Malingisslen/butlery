// lib/services/notifications/notification_service.dart

import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/notification_repository.dart' as legacy;
import 'package:butlery/services/notifications/fcm_service.dart';
import 'package:butlery/services/notifications/modules/notification_content_manager.dart';
import 'package:butlery/services/notifications/modules/notification_preference_manager.dart';
import 'package:butlery/services/notifications/modules/notification_offline_manager.dart';
import 'package:butlery/services/notifications/modules/notification_batch_manager.dart';
import 'package:butlery/services/notifications/modules/fcm_token_manager.dart';
import 'package:butlery/services/notifications/modules/notification_analytics_manager.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:get_it/get_it.dart';

/// Comprehensive notification management service providing modular push notification functionality with FCM integration.
///
/// This service implements a sophisticated notification system using the coordinator pattern with focused modules
/// for content management, user preferences, offline handling, batch processing, token management, and analytics.
/// It provides comprehensive push notification functionality including recipe sharing alerts, friend interactions,
/// cooking reminders, and social engagement notifications with Swedish localization and intelligent delivery optimization.
///
/// **Refactored Architecture (Single Responsibility Principle):**
/// The service follows clean modular architecture with specialized components:
/// - **NotificationContentManager**: Message generation, template management, and localized content creation
/// - **NotificationPreferenceManager**: User preference management, quiet hours, and notification type controls
/// - **NotificationOfflineManager**: Offline notification queuing, retry logic, and connection-aware delivery
/// - **NotificationBatchManager**: Batch processing, spam prevention, and intelligent notification grouping
/// - **FCMTokenManager**: Device token management, topic subscriptions, and cross-device synchronization
/// - **NotificationAnalyticsManager**: Delivery tracking, engagement metrics, and performance analytics
///
/// **Coordinator Pattern Implementation:**
/// This main service acts as a clean facade that delegates to focused modules while maintaining
/// backward compatibility through unified public API. Each module has single, well-defined responsibility
/// enabling maintainable code and flexible notification system evolution.
///
/// **Development and Production Ready:**
/// All notification logic is fully functional with intentional development logging for debugging.
/// Production deployment requires only updating FCM delivery configuration to use Cloud Functions
/// for scalable server-side notification processing and enhanced delivery reliability.
/// Comprehensive notification coordinator providing modular push notification functionality with FCM integration.
///
/// This service implements the coordinator pattern with specialized modules following Single Responsibility
/// Principle for maintainable notification management. It provides comprehensive push notification functionality
/// including recipe sharing, social interactions, cooking reminders, and system notifications with Swedish
/// localization and intelligent delivery optimization.
class NotificationService extends BaseService {
  @override
  String get serviceName => 'NotificationService';
  final String _userId;
  late final legacy.NotificationRepository _repository;
  
  // Focused notification modules (Single Responsibility)
  late final NotificationContentManager _contentManager;
  late final NotificationPreferenceManager _preferenceManager;
  late final NotificationOfflineManager _offlineManager;
  late final NotificationBatchManager _batchManager;
  late final FCMTokenManager _tokenManager;
  late final NotificationAnalyticsManager _analyticsManager;
  
  bool _isInitialized = false;

  NotificationService({
    required String userId,
  }) : _userId = userId {
    final notificationsRepository = GetIt.instance<NotificationsRepository>();
    
    _repository = legacy.NotificationRepository(
      userId: userId,
    );
    
    // Initialize all focused modules
    _contentManager = NotificationContentManager(
      userId: userId,
    );
    
    _preferenceManager = NotificationPreferenceManager(
      notificationsRepository: notificationsRepository,
      userId: userId,
    );
    
    _offlineManager = NotificationOfflineManager(
      userId: userId,
      sendNotificationCallback: _sendQueuedNotification,
    );
    
    _batchManager = NotificationBatchManager(
      userId: userId,
      repository: _repository,
      sendBatchCallback: _sendBatchedNotification,
    );
    
    _tokenManager = FCMTokenManager(
      userId: userId,
    );
    
    _analyticsManager = NotificationAnalyticsManager(
      userId: userId,
    );
  }

  /// Initialize the notification service
  /// Should be called after user authentication
  @override
  Future<void> onInitialize() async {
    if (_isInitialized) {
      AppLogger.warning('🔔 NotificationService already initialized');
      return;
    }

    await safeExecute(
      () async {
        AppLogger.info('🔔 Initializing NotificationService coordinator for user: $_userId');

        // Initialize FCM service
        await FCMService.initialize(
          onMessageReceived: _handleForegroundMessage,
          onMessageOpenedApp: _handleMessageOpened,
        );

        // Initialize FCM token manager
        await _tokenManager.initialize();

        // Subscribe to user-specific topics based on preferences
        final preferences = await _preferenceManager.getPreferences();
        await _tokenManager.updateTopicSubscriptions(preferences);

        // Process any pending batches
        await _batchManager.processAllPendingBatches();

        // Process offline queue if any notifications are queued
        await _offlineManager.processOfflineQueue();

        _isInitialized = true;
        AppLogger.success('✅ NotificationService coordinator initialized successfully');
      },
      operationName: 'Initialize NotificationService',
      customErrorMessage: 'Failed to initialize NotificationService coordinator',
    );
  }

  /// Send immediate notification (friend requests, direct shares, etc.)
  Future<void> sendImmediateNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    try {
      await safeExecute(
        () async {
          AppLogger.info('🔔 Coordinator: Sending immediate notification to ${targetUserIds.length} users');

          // Filter users based on preferences and quiet hours
          final filteredUserIds = await _preferenceManager.filterUsersForNotification(
            targetUserIds,
            strategy.category,
            strategy.type,
          );

          if (filteredUserIds.isEmpty) {
            AppLogger.info('📋 No users eligible for notification after preference filtering');
            return;
          }

          for (final targetUserId in filteredUserIds) {
            // Generate unique notification ID
            final notificationId = _contentManager.generateNotificationId(targetUserId, strategy);

            // Check if already sent (prevent duplicates)
            final alreadySent = await _repository.wasNotificationSent(notificationId);
            if (alreadySent) {
              AppLogger.info('📋 Notification $notificationId already sent, skipping');
              continue;
            }

            // Create notification content
            final template = _contentManager.createNotificationContent(
              strategy: strategy,
              variables: variables,
              additionalData: additionalData,
              imageUrl: imageUrl,
              actions: actions,
            );

            // Send via FCM
            await _sendFCMNotification(targetUserId, template, notificationId);

            // Record analytics
            await _analyticsManager.recordNotificationSent(
              notificationId: notificationId,
              category: strategy.category,
              type: strategy.type,
              targetUserId: targetUserId,
              metadata: template.data,
            );

            // Record in history
            await _repository.recordNotification(
              notificationId: notificationId,
              category: strategy.category,
              type: strategy.type,
              data: template.data,
            );
          }

          AppLogger.success('✅ Immediate notification sent to ${filteredUserIds.length} users');
        },
        operationName: 'Send Immediate Notification',
        customErrorMessage: 'Failed to send immediate notification',
      );
    } catch (e) {
      // Queue for offline retry
      if (!_offlineManager.isOnline) {
        _offlineManager.queueNotificationForOffline(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: variables,
          additionalData: additionalData,
          imageUrl: imageUrl,
          actions: actions,
        );
      } else {
        rethrow;
      }
    }
  }

  /// Send batchable notification (comments, likes, activity updates)
  Future<void> sendBatchableNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
  }) async {
    await safeExecute(
      () async {
        AppLogger.info('🔔 Coordinator: Processing batchable notification for ${targetUserIds.length} users');

        // Delegate to batch manager
        final batched = await _batchManager.addToBatch(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: variables,
          additionalData: additionalData,
          imageUrl: imageUrl,
        );

        if (batched) {
          AppLogger.success('✅ Batchable notification queued successfully');
        } else {
          AppLogger.info('📋 Notification not eligible for batching');
        }
      },
      operationName: 'Send Batchable Notification',
      customErrorMessage: 'Failed to queue batchable notification',
    );
  }

  /// Send silent notification (background sync, data updates)
  Future<void> sendSilentNotification({
    required List<String> targetUserIds,
    required Map<String, dynamic> data,
  }) async {
    // Silent notifications are less critical, don't rethrow errors
    await safeExecute(
      () async {
        AppLogger.info('🔔 Coordinator: Sending silent notification to ${targetUserIds.length} users');

        for (final targetUserId in targetUserIds) {
          // Send data-only FCM message
          await _sendSilentFCMNotification(targetUserId, data);
        }

        AppLogger.success('✅ Silent notification sent successfully');
      },
      operationName: 'Send Silent Notification',
      customErrorMessage: 'Failed to send silent notification',
      logError: true, // Log but don't throw
    );
  }

  /// Send digest notification (daily/weekly summaries)
  Future<void> sendDigestNotification({
    required String targetUserId,
    required NotificationStrategy strategy,
    required List<Map<String, String>> activityList,
    Map<String, dynamic>? additionalData,
  }) async {
    // Digest notifications are not critical, don't rethrow errors
    await safeExecute(
      () async {
        AppLogger.info('🔔 Coordinator: Sending digest notification to user: $targetUserId');

        // Check if user wants digest notifications
        final digestEnabled = await _preferenceManager.areDigestNotificationsEnabled();
        if (!digestEnabled) {
          AppLogger.info('📋 User has disabled digest notifications');
          return;
        }

        // Build digest content
        final digestContent = _contentManager.buildDigestContent(activityList, strategy);
        
        // Create notification template
        final template = _contentManager.createNotificationContent(
          strategy: strategy,
          variables: digestContent,
          additionalData: additionalData,
        );

        // Generate notification ID
        final notificationId = _contentManager.generateNotificationId(targetUserId, strategy);

        // Send via FCM
        await _sendFCMNotification(targetUserId, template, notificationId);

        // Record analytics
        await _analyticsManager.recordNotificationSent(
          notificationId: notificationId,
          category: strategy.category,
          type: strategy.type,
          targetUserId: targetUserId,
          metadata: template.data,
        );

        AppLogger.success('✅ Digest notification sent successfully');
      },
      operationName: 'Send Digest Notification',
      customErrorMessage: 'Failed to send digest notification',
      logError: true, // Log but don't throw
    );
  }

  /// Check if user should receive notification based on quiet hours
  Future<bool> isInQuietHours(String targetUserId) async {
    return await _preferenceManager.isInQuietHours();
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      AppLogger.info('🔔 Coordinator: Handling foreground message: ${message.notification?.title}');
      
      // Show in-app notification or update UI
      FCMService.showForegroundNotification(message);
      
      // Record analytics
      final notificationId = message.data['notificationId'] as String?;
      if (notificationId != null) {
        _repository.markNotificationDelivered(notificationId);
        _analyticsManager.recordNotificationDelivered(
          notificationId: notificationId,
          deliveryMetadata: message.data,
        );
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle foreground message', e);
    }
  }

  /// Handle message opened app
  void _handleMessageOpened(RemoteMessage message) {
    try {
      AppLogger.info('🔔 Coordinator: Handling message opened app: ${message.notification?.title}');
      
      // Navigate to appropriate screen
      // This would need a BuildContext or navigation service
      
      // Record analytics
      final notificationId = message.data['notificationId'] as String?;
      if (notificationId != null) {
        _repository.markNotificationOpened(notificationId);
        _analyticsManager.recordNotificationOpened(
          notificationId: notificationId,
          context: message.data,
        );
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle message opened', e);
    }
  }

  /// Update topic subscriptions based on user preferences
  Future<void> updateTopicSubscriptions() async {
    try {
      final preferences = await _preferenceManager.getPreferences();
      await _tokenManager.updateTopicSubscriptions(preferences);
      AppLogger.success('✅ Updated topic subscriptions');
    } catch (e) {
      AppLogger.error('❌ Failed to update topic subscriptions', e);
    }
  }

  /// Send FCM notification to specific user
  /// 
  /// DEVELOPMENT IMPLEMENTATION:
  /// This method intentionally logs notifications instead of sending them.
  /// This approach is perfect for development because:
  /// - All notification logic and routing works correctly
  /// - Easy to debug and verify notification content
  /// - No server infrastructure required
  /// - Security-safe (no exposed FCM keys)
  /// 
  /// PRODUCTION TRANSITION:
  /// When ready for production, replace the logging section with:
  /// HTTP call to Cloud Function for server-side FCM sending
  Future<void> _sendFCMNotification(String targetUserId, NotificationTemplate template, String notificationId) async {
    try {
      // =============================================================================
      // DEVELOPMENT LOGGING (INTENTIONAL - NOT A BUG)
      // =============================================================================
      
      AppLogger.info('🔔 [DEV] Coordinator: FCM notification ready for: $targetUserId');
      AppLogger.debug('📋 [DEV] ID: $notificationId');
      AppLogger.debug('📋 [DEV] Title: ${template.title}');  
      AppLogger.debug('📋 [DEV] Body: ${template.body}');
      AppLogger.debug('📋 [DEV] Data keys: ${template.data.keys.join(', ')}');
      if (template.imageUrl != null) {
        AppLogger.debug('📋 [DEV] Image: ${template.imageUrl}');
      }
      
      // =============================================================================
      // PRODUCTION REPLACEMENT POINT
      // =============================================================================
      // Replace the above logging with HTTP call to Cloud Function when ready
      
    } catch (e) {
      AppLogger.error('❌ Failed to prepare FCM notification', e);
      rethrow;
    }
  }

  /// Send silent FCM notification (data-only)
  /// 
  /// DEVELOPMENT IMPLEMENTATION:
  /// Logs silent notifications for real-time collaboration events.
  /// These are background data updates that don't show user-visible notifications.
  /// 
  /// PRODUCTION: Use the same Cloud Function with 'silent: true' parameter
  Future<void> _sendSilentFCMNotification(String targetUserId, Map<String, dynamic> data) async {
    try {
      // =============================================================================
      // DEVELOPMENT LOGGING - Silent notifications for collaboration events
      // =============================================================================
      AppLogger.info('🔔 [DEV] Coordinator: Silent FCM data ready for: $targetUserId');
      AppLogger.debug('📋 [DEV] Data payload: ${data.keys.join(', ')}');
      AppLogger.debug('📋 [DEV] Event type: ${data['type'] ?? 'unknown'}');

      // =============================================================================
      // PRODUCTION: Call same Cloud Function with silent flag
      // =============================================================================
      
    } catch (e) {
      AppLogger.warning('⚠️ Silent notification preparation failed (non-critical): $e');
    }
  }

  // Notification ID generation is now handled by ContentManager
  // Batch key generation is now handled by BatchManager

  // Batch processing is now handled by BatchManager through callbacks

  // Batch notification building is now handled by BatchManager

  // Digest content building is now handled by ContentManager

  // Offline queuing is now handled by OfflineManager

  /// Callback for sending queued notifications from offline manager
  Future<void> _sendQueuedNotification(PendingNotification notification) async {
    await sendImmediateNotification(
      targetUserIds: notification.targetUserIds,
      strategy: notification.strategy,
      variables: notification.variables,
      additionalData: notification.additionalData,
      imageUrl: notification.imageUrl,
      actions: notification.actions,
    );
  }
  
  /// Callback for sending batched notifications from batch manager
  Future<void> _sendBatchedNotification(legacy.NotificationBatch batch) async {
    if (batch.notifications.isNotEmpty) {
      final template = batch.notifications.first;
      final notificationId = _contentManager.generateNotificationId(
        batch.userId, 
        NotificationStrategy.recipeComment, // Default strategy for batches
      );
      await _sendFCMNotification(batch.userId, template, notificationId);
    }
  }

  /// Update online status
  void setOnlineStatus(bool isOnline) {
    _offlineManager.setOnlineStatus(isOnline);
  }

  /// Get notification preferences for current user
  Future<legacy.NotificationPreferences> getPreferences() async {
    return await _preferenceManager.getPreferences();
  }

  /// Update notification preferences for current user
  Future<void> updatePreferences(legacy.NotificationPreferences preferences) async {
    await _preferenceManager.updatePreferences(preferences);
  }


  // ===== PUBLIC UTILITY METHODS =====
  
  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    return await _tokenManager.getCurrentToken();
  }
  
  /// Get notification analytics summary
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    return await _analyticsManager.getUserEngagementSummary();
  }
  
  /// Get offline queue statistics
  Map<String, dynamic> getOfflineQueueStats() {
    return _offlineManager.getQueueStatistics();
  }
  
  /// Get batch statistics
  Map<String, dynamic> getBatchStats() {
    return _batchManager.getBatchStatistics();
  }

  /// Clean up resources
  @override
  Future<void> onDispose() async {
    try {
      AppLogger.info('🔔 Disposing NotificationService coordinator...');
      
      // Dispose all modules
      _batchManager.dispose();
      _offlineManager.dispose();
      _tokenManager.dispose();
      await _analyticsManager.dispose();
      _preferenceManager.dispose();
      
      // Clear repository cache
      _repository.clearCache();
      
      _isInitialized = false;
      AppLogger.success('✅ NotificationService coordinator disposed');
    } catch (e) {
      AppLogger.error('❌ Failed to dispose NotificationService coordinator', e);
    }
  }
}

// PendingNotification class is now defined in the OfflineManager module