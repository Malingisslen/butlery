// lib/services/notifications/notification_service.dart

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/models/notification_history_entry.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/models/notification_batch.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/services/notifications/fcm_service.dart';
import 'package:butlery/services/notifications/modules/notification_content_manager.dart';
import 'package:butlery/services/notifications/modules/notification_preference_manager.dart';
import 'package:butlery/services/notifications/modules/notification_offline_manager.dart';
import 'package:butlery/services/notifications/modules/notification_batch_manager.dart';
import 'package:butlery/services/notifications/modules/fcm_token_manager.dart';
import 'package:butlery/services/notifications/modules/notification_analytics_manager.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart'
    as interface_repo;
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/interfaces/device_repository.dart';

/// Notification coordinator using modular architecture with 6 specialized managers.
///
/// ## Usage
/// ```dart
/// final service = ServiceLocator.get<NotificationService>();
///
/// // Send notification
/// await service.sendNotification(userId, type: NotificationType.friendRequest);
///
/// // Update preferences
/// await service.updatePreferences(NotificationPreferences(...));
/// ```
///
/// Implements facade pattern for FCM integration, Swedish localization,
/// and intelligent delivery with development logging.
class NotificationService extends BaseService {
  @override
  String get serviceName => 'NotificationService';
  final interface_repo.NotificationsRepository _notificationsRepository;
  final auth_repo.AuthRepository _authRepository;
  final NotificationHistoryRepository _historyRepository;
  final NotificationBatchRepository _batchRepository;
  final DeviceRepository _deviceRepository;

  /// Dynamic userId read from AuthRepository (survives logout/login cycles)
  String get _userId {
    final id = _authRepository.currentUserId;
    if (id == null) {
      throw StateError('NotificationService: No authenticated user');
    }
    return id;
  }

  // Focused notification modules (Single Responsibility)
  late NotificationContentManager _contentManager;
  late NotificationPreferenceManager _preferenceManager;
  late NotificationOfflineManager _offlineManager;
  late NotificationBatchManager _batchManager;
  FCMTokenManager? _tokenManager;
  late NotificationAnalyticsManager _analyticsManager;

  bool _isInitialized = false;
  bool _modulesCreated = false;

  NotificationService({
    required interface_repo.NotificationsRepository notificationsRepository,
    required auth_repo.AuthRepository authRepository,
    required NotificationHistoryRepository historyRepository,
    required NotificationBatchRepository batchRepository,
    required DeviceRepository deviceRepository,
  })  : _notificationsRepository = notificationsRepository,
        _authRepository = authRepository,
        _historyRepository = historyRepository,
        _batchRepository = batchRepository,
        _deviceRepository = deviceRepository;

  /// Initialize modules for the current authenticated user.
  /// Called on first [onInitialize] or after [resetForLogout].
  void _initializeModules() {
    if (_modulesCreated) return;
    final userId = _userId;

    _contentManager = NotificationContentManager(
      userId: userId,
    );

    _preferenceManager = NotificationPreferenceManager(
      notificationsRepository: _notificationsRepository,
      userId: userId,
    );

    _offlineManager = NotificationOfflineManager(
      userId: userId,
      sendNotificationCallback: _sendQueuedNotification,
    );

    _batchManager = NotificationBatchManager(
      userId: userId,
      repository: _batchRepository,
      sendBatchCallback: _sendBatchedNotification,
    );

    // FCMTokenManager accesses FirebaseMessaging.instance in its constructor,
    // which may not be available (e.g. web, tests). Other modules still work.
    try {
      _tokenManager = FCMTokenManager(
        userId: userId,
        repository: _deviceRepository,
      );
    } catch (e) {
      _tokenManager = null;
      AppLogger.warning('FCMTokenManager unavailable: $e');
    }

    _analyticsManager = NotificationAnalyticsManager(
      userId: userId,
    );

    _modulesCreated = true;
  }

  /// Ensure modules are created even if full [onInitialize] hasn't run.
  /// Allows methods like [getPreferences] to work before full FCM setup.
  void _ensureModulesCreated() {
    if (!_modulesCreated) {
      _initializeModules();
    }
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
        // Initialize modules for current user on first init
        _initializeModules();

        AppLogger.info(
            '🔔 Initializing NotificationService coordinator for user: $_userId');

        // Initialize FCM service
        await FCMService.initialize(
          onMessageReceived: _handleForegroundMessage,
          onMessageOpenedApp: _handleMessageOpened,
        );

        // Initialize FCM token manager (may be null if Firebase unavailable)
        await _tokenManager?.initialize();

        // Subscribe to user-specific topics based on preferences
        final preferences = await _preferenceManager.getPreferences();
        await _tokenManager?.updateTopicSubscriptions(preferences);

        // Process any pending batches
        await _batchManager.processAllPendingBatches();

        // Process offline queue if any notifications are queued
        await _offlineManager.processOfflineQueue();

        _isInitialized = true;
        AppLogger.success(
            '✅ NotificationService coordinator initialized successfully');
      },
      operationName: 'Initialize NotificationService',
      customErrorMessage:
          'Failed to initialize NotificationService coordinator',
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
    _ensureModulesCreated();
    try {
      await safeExecute(
        () async {
          AppLogger.info(
              '🔔 Coordinator: Sending immediate notification to ${targetUserIds.length} users');

          // Filter users based on preferences and quiet hours
          final filteredUserIds =
              await _preferenceManager.filterUsersForNotification(
            targetUserIds,
            strategy.category,
            strategy.type,
          );

          if (filteredUserIds.isEmpty) {
            AppLogger.info(
                '📋 No users eligible for notification after preference filtering');
            return;
          }

          for (final targetUserId in filteredUserIds) {
            // Generate unique notification ID
            final notificationId =
                _contentManager.generateNotificationId(targetUserId, strategy);

            // Check if already sent (prevent duplicates)
            final alreadySent =
                await _historyRepository.wasNotificationSent(notificationId);
            if (alreadySent) {
              AppLogger.info(
                  '📋 Notification $notificationId already sent, skipping');
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
            await _historyRepository.recordNotification(
              notificationId: notificationId,
              category: strategy.category,
              type: strategy.type,
              data: template.data,
            );
          }

          AppLogger.success(
              '✅ Immediate notification sent to ${filteredUserIds.length} users');
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
    _ensureModulesCreated();
    await safeExecute(
      () async {
        AppLogger.info(
            '🔔 Coordinator: Processing batchable notification for ${targetUserIds.length} users');

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
        AppLogger.info(
            '🔔 Coordinator: Sending silent notification to ${targetUserIds.length} users');

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
    _ensureModulesCreated();
    // Digest notifications are not critical, don't rethrow errors
    await safeExecute(
      () async {
        AppLogger.info(
            '🔔 Coordinator: Sending digest notification to user: $targetUserId');

        // Check if user wants digest notifications
        final digestEnabled =
            await _preferenceManager.areDigestNotificationsEnabled();
        if (!digestEnabled) {
          AppLogger.info('📋 User has disabled digest notifications');
          return;
        }

        // Build digest content
        final digestContent =
            _contentManager.buildDigestContent(activityList, strategy);

        // Create notification template
        final template = _contentManager.createNotificationContent(
          strategy: strategy,
          variables: digestContent,
          additionalData: additionalData,
        );

        // Generate notification ID
        final notificationId =
            _contentManager.generateNotificationId(targetUserId, strategy);

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
    _ensureModulesCreated();
    return await _preferenceManager.isInQuietHours();
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      AppLogger.info(
          '🔔 Coordinator: Handling foreground message: ${message.notification?.title}');

      // Show in-app notification or update UI
      FCMService.showForegroundNotification(message);

      // Record analytics
      final notificationId = message.data['notificationId'] as String?;
      if (notificationId != null) {
        _historyRepository.markNotificationDelivered(notificationId);
        _analyticsManager.recordNotificationDelivered(
          notificationId: notificationId,
          deliveryMetadata: message.data,
        );
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle foreground message', e);
    }
  }

  /// Callback for notification tap routing. Set from main.dart to wire navigation.
  static void Function(String route, Map<String, String?> data)?
      onNotificationTapped;

  /// Handle message opened app
  void _handleMessageOpened(RemoteMessage message) {
    try {
      AppLogger.info(
          '🔔 Coordinator: Handling message opened app: ${message.notification?.title}');

      // Record analytics
      final notificationId = message.data['notificationId'] as String?;
      if (notificationId != null) {
        _historyRepository.markNotificationOpened(notificationId);
        _analyticsManager.recordNotificationOpened(
          notificationId: notificationId,
          context: message.data,
        );
      }

      // P8-16: Route to appropriate screen based on notification data
      final route = message.data['route'] as String?;
      if (route != null && onNotificationTapped != null) {
        final targetId = message.data['targetId'] as String?;
        onNotificationTapped!(route, {'id': targetId});
      }
    } catch (e) {
      AppLogger.error('❌ Failed to handle message opened', e);
    }
  }

  /// Update topic subscriptions based on user preferences
  Future<void> updateTopicSubscriptions() async {
    _ensureModulesCreated();
    try {
      final preferences = await _preferenceManager.getPreferences();
      await _tokenManager?.updateTopicSubscriptions(preferences);
      AppLogger.success('✅ Updated topic subscriptions');
    } catch (e) {
      AppLogger.error('❌ Failed to update topic subscriptions', e);
    }
  }

  /// Send FCM notification via Cloud Function
  Future<void> _sendFCMNotification(String targetUserId,
      NotificationTemplate template, String notificationId) async {
    try {
      AppLogger.info('🔔 Sending FCM notification to: $targetUserId');

      final callable =
          FirebaseFunctions.instance.httpsCallable('sendNotification');

      final result = await callable.call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
        'title': template.title,
        'body': template.body,
        'data': {
          ...template.data.map((key, value) => MapEntry(key, value.toString())),
          'notificationId': notificationId,
        },
        if (template.imageUrl != null) 'imageUrl': template.imageUrl,
        'silent': false,
      });

      final response = result.data;
      final successCount = response['successCount'] as int? ?? 0;
      final failureCount = response['failureCount'] as int? ?? 0;

      if (successCount > 0) {
        AppLogger.success('✅ FCM notification sent: $successCount device(s)');
      }
      if (failureCount > 0) {
        AppLogger.warning(
            '⚠️ FCM notification failed for $failureCount device(s)');
      }
      if (successCount == 0 && failureCount == 0) {
        AppLogger.info('ℹ️ No FCM tokens registered for user $targetUserId');
      }
    } catch (e) {
      AppLogger.error('❌ Failed to send FCM notification', e);
      rethrow;
    }
  }

  /// Send silent FCM notification via Cloud Function (for background sync events)
  Future<void> _sendSilentFCMNotification(
      String targetUserId, Map<String, dynamic> data) async {
    try {
      AppLogger.info('🔔 Sending silent FCM notification to: $targetUserId');

      final callable =
          FirebaseFunctions.instance.httpsCallable('sendNotification');

      await callable.call<Map<String, dynamic>>({
        'targetUserId': targetUserId,
        'data': data.map((key, value) => MapEntry(key, value.toString())),
        'silent': true,
      });

      AppLogger.debug('✅ Silent FCM notification sent to: $targetUserId');
    } catch (e) {
      AppLogger.warning('⚠️ Silent notification failed (non-critical): $e');
    }
  }

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
  Future<void> _sendBatchedNotification(NotificationBatch batch) async {
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
    _ensureModulesCreated();
    _offlineManager.setOnlineStatus(isOnline);
  }

  /// Get notification preferences for current user
  Future<NotificationPreferences> getPreferences() async {
    _ensureModulesCreated();
    return await _preferenceManager.getPreferences();
  }

  /// Update notification preferences for current user
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    _ensureModulesCreated();
    await _preferenceManager.updatePreferences(preferences);
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    _ensureModulesCreated();
    return await _tokenManager?.getCurrentToken();
  }

  /// Get notification analytics summary
  Future<Map<String, dynamic>> getAnalyticsSummary() async {
    _ensureModulesCreated();
    return await _analyticsManager.getUserEngagementSummary();
  }

  /// Get offline queue statistics
  Map<String, dynamic> getOfflineQueueStats() {
    _ensureModulesCreated();
    return _offlineManager.getQueueStatistics();
  }

  Map<String, dynamic> getBatchStats() {
    _ensureModulesCreated();
    return _batchManager.getBatchStatistics();
  }

  /// Fetches notification history for the current user.
  Future<List<NotificationHistoryEntry>> getNotificationHistory({
    int limit = 20,
    DateTime? before,
  }) async {
    try {
      return await _historyRepository.getHistory(_userId,
          limit: limit, before: before);
    } catch (e) {
      AppLogger.error('Failed to fetch notification history', e);
      return [];
    }
  }

  /// Marks a notification as opened in history.
  Future<void> markHistoryNotificationOpened(String notificationId) async {
    try {
      await _historyRepository.markNotificationOpened(notificationId);
    } catch (e) {
      AppLogger.warning('Failed to mark notification opened: $e');
    }
  }

  /// Reset state for logout. Allows re-initialization for a new user session.
  Future<void> resetForLogout() async {
    // Guard on _modulesCreated (not _isInitialized) because modules may have
    // been lazily created via _ensureModulesCreated() without full FCM init.
    if (!_modulesCreated) return;

    try {
      await _preferenceManager.clearLocalStorage();
      await _tokenManager?.cleanup();
      await _disposeModules();
      AppLogger.info('🔔 NotificationService reset for logout');
    } catch (e) {
      AppLogger.error('❌ Failed to reset NotificationService for logout', e);
    }
  }

  @override
  Future<void> onDispose() async {
    if (!_modulesCreated) return;
    try {
      AppLogger.info('🔔 Disposing NotificationService coordinator...');
      await _disposeModules();
      AppLogger.success('✅ NotificationService coordinator disposed');
    } catch (e) {
      AppLogger.error('❌ Failed to dispose NotificationService coordinator', e);
    }
  }

  Future<void> _disposeModules() async {
    _batchManager.dispose();
    _offlineManager.dispose();
    _tokenManager?.dispose();
    await _analyticsManager.dispose();
    _preferenceManager.dispose();
    _isInitialized = false;
    _modulesCreated = false;
  }
}
