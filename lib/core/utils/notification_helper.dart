// lib/core/utils/notification_helper.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Notification helper utilities for safe notification sending
/// This helper provides safe notification sending patterns with:
/// - Null-safe notification service handling
/// - Automatic error catching and logging
/// - Non-blocking failures (notifications never throw)
/// - Consistent logging patterns
/// **Usage:**
/// ```dart
/// await NotificationHelper.sendSafely(
///   notificationService: _notificationService,
///   operationName: 'Send sharing notification',
///   send: () => _notificationService!.sendImmediateNotification(...),
/// );
/// ```
class NotificationHelper {
  /// Safely send a notification with automatic null checking and error handling
  /// This method encapsulates the common pattern of:
  /// 1. Check if notification service exists
  /// 2. Try to send notification
  /// 3. Log success/failure
  /// 4. Never rethrow errors (notifications are non-critical)
  /// **Parameters:**
  /// - [notificationService]: The notification service instance (nullable)
  /// - [operationName]: Human-readable operation description for logging
  /// - [send]: Async callback that sends the notification
  /// - [successMessage]: Optional success log message (auto-generated if not provided)
  /// - [logWarningOnNull]: If true, logs warning when service is null (default: false)
  /// **Returns:** true if notification sent successfully, false otherwise
  static Future<bool> sendSafely({
    required NotificationService? notificationService,
    required String operationName,
    required Future<void> Function() send,
    String? successMessage,
    bool logWarningOnNull = false,
  }) async {
    // Check if notification service is available
    if (notificationService == null) {
      if (logWarningOnNull) {
        AppLogger.warning(
            '⚠️ No notification service available for: $operationName');
      } else {
        AppLogger.debug(
            '📋 No notification service available for: $operationName');
      }
      return false;
    }

    try {
      // Execute the notification sending callback
      await send();

      // Log success
      final message =
          successMessage ?? '✅ $operationName completed successfully';
      AppLogger.info(message);

      return true;
    } catch (e) {
      // Log error but don't rethrow - notifications are non-critical
      AppLogger.error('❌ Failed to send notification: $operationName', e);
      return false;
    }
  }

  /// Safely send immediate notification with standard parameters
  /// Convenience wrapper for common immediate notification pattern.
  /// **Example:**
  /// ```dart
  /// await NotificationHelper.sendImmediateSafely(
  ///   notificationService: _notificationService,
  ///   operationName: 'Recipe shared',
  ///   targetUserIds: [userId1, userId2],
  ///   strategy: NotificationStrategy.recipeShared,
  ///   variables: {'senderName': 'John', 'recipeName': 'Pizza'},
  ///   additionalData: {'recipeId': '123'},
  /// );
  /// ```
  static Future<bool> sendImmediateSafely({
    required NotificationService? notificationService,
    required String operationName,
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    return await sendSafely(
      notificationService: notificationService,
      operationName: operationName,
      send: () => notificationService!.sendImmediateNotification(
        targetUserIds: targetUserIds,
        strategy: strategy,
        variables: variables,
        additionalData: additionalData,
        imageUrl: imageUrl,
        actions: actions,
      ),
    );
  }

  /// Safely send batchable notification with standard parameters
  /// Convenience wrapper for common batchable notification pattern.
  /// **Example:**
  /// ```dart
  /// await NotificationHelper.sendBatchableSafely(
  ///   notificationService: _notificationService,
  ///   operationName: 'Comment posted',
  ///   targetUserIds: memberIds,
  ///   strategy: NotificationStrategy.recipeComment,
  ///   variables: {'commenterName': 'Jane', 'recipeName': 'Pasta'},
  /// );
  /// ```
  static Future<bool> sendBatchableSafely({
    required NotificationService? notificationService,
    required String operationName,
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
  }) async {
    return await sendSafely(
      notificationService: notificationService,
      operationName: operationName,
      send: () => notificationService!.sendBatchableNotification(
        targetUserIds: targetUserIds,
        strategy: strategy,
        variables: variables,
        additionalData: additionalData,
        imageUrl: imageUrl,
      ),
    );
  }

  /// Safely send silent notification with standard parameters
  /// Convenience wrapper for silent notification pattern (background sync, data updates).
  /// **Example:**
  /// ```dart
  /// await NotificationHelper.sendSilentSafely(
  ///   notificationService: _notificationService,
  ///   operationName: 'Member removed',
  ///   targetUserIds: [removedUserId],
  ///   data: {'type': 'member_removed', 'recipeId': '123'},
  /// );
  /// ```
  static Future<bool> sendSilentSafely({
    required NotificationService? notificationService,
    required String operationName,
    required List<String> targetUserIds,
    required Map<String, dynamic> data,
  }) async {
    return await sendSafely(
      notificationService: notificationService,
      operationName: operationName,
      send: () => notificationService!.sendSilentNotification(
        targetUserIds: targetUserIds,
        data: data,
      ),
    );
  }
}
