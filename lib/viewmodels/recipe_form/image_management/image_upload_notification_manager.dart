// lib/viewmodels/recipe_form/image_management/image_upload_notification_manager.dart

import 'dart:async';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Manages upload progress notifications and error reporting for recipe images.
///
/// **Responsibilities:**
/// - Broadcast upload notification events via stream
/// - Cooldown management to prevent notification spam
/// - Trigger notifications for upload milestones (completion, failures, queue cleared)
/// - Priority-based notification system
/// - Background notification coordination
///
/// **Used by:** RecipeImageManager for user feedback during uploads
class ImageUploadNotificationManager {
  /// Stream controller for upload notification events
  static final StreamController<UploadNotificationEvent> _notificationController =
      StreamController<UploadNotificationEvent>.broadcast();

  /// Stream of upload notification events for UI subscription
  static Stream<UploadNotificationEvent> get notificationStream =>
      _notificationController.stream;

  /// Cooldown duration to prevent notification spam
  static const Duration _notificationCooldown = Duration(seconds: 3);

  /// Track which notifications have been sent
  final Set<UploadNotificationTrigger> _notificationTriggers = {};

  /// Last notification timestamp for cooldown management
  DateTime? _lastNotificationTime;

  /// Check if notification cooldown allows new notification
  bool _canSendNotification() {
    if (_lastNotificationTime == null) return true;
    return DateTime.now().difference(_lastNotificationTime!) >=
        _notificationCooldown;
  }

  /// Send upload notification event
  void sendNotificationEvent(UploadNotificationEvent event) {
    if (!_canSendNotification()) {
      AppLogger.debug(
          '🔔 NOTIFICATION: Skipping notification due to cooldown: ${event.trigger.name}');
      return;
    }

    _lastNotificationTime = DateTime.now();
    _notificationTriggers.add(event.trigger);
    _notificationController.add(event);

    AppLogger.info(
        '🔔 NOTIFICATION: Sent ${event.trigger.name} notification: ${event.message}');
  }

  /// Trigger completion notification when all uploads are done
  void triggerCompletionNotification(int totalImages) {
    if (_notificationTriggers.contains(UploadNotificationTrigger.allCompleted)) {
      return; // Already sent
    }

    final imageText = totalImages == 1 ? 'bild' : 'bilder';
    sendNotificationEvent(UploadNotificationEvent(
      trigger: UploadNotificationTrigger.allCompleted,
      title: 'Uppladdning slutförd!',
      message: 'Alla $totalImages $imageText har laddats upp framgångsrikt',
      priority: NotificationPriority.medium,
      data: {'totalImages': totalImages},
      timestamp: DateTime.now(),
    ));
  }

  /// Trigger major failure notification when significant uploads fail
  void triggerMajorFailureNotification(int failedCount, int totalCount) {
    if (_notificationTriggers.contains(UploadNotificationTrigger.majorFailure)) {
      return; // Already sent
    }

    if (failedCount >= 2 || (totalCount > 1 && failedCount >= totalCount / 2)) {
      sendNotificationEvent(UploadNotificationEvent(
        trigger: UploadNotificationTrigger.majorFailure,
        title: 'Uppladdningsproblem',
        message:
            '$failedCount av $totalCount bilder misslyckades - kontrollera din internetanslutning',
        priority: NotificationPriority.high,
        data: {'failedCount': failedCount, 'totalCount': totalCount},
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Trigger retry success notification (when previously failed upload succeeds)
  void triggerRetrySuccessNotification(String imagePath) {
    sendNotificationEvent(UploadNotificationEvent(
      trigger: UploadNotificationTrigger.retrySuccess,
      title: 'Uppladdning lyckades!',
      message: 'Bilden laddades upp efter omförsök',
      priority: NotificationPriority.low,
      data: {'imagePath': imagePath},
      timestamp: DateTime.now(),
    ));
  }

  /// Trigger queue cleared notification when all uploads are handled
  void triggerQueueClearedNotification(int totalProcessed) {
    if (_notificationTriggers.isNotEmpty && totalProcessed == 0) {
      sendNotificationEvent(UploadNotificationEvent(
        trigger: UploadNotificationTrigger.queueCleared,
        title: 'Uppladdningskö rensad',
        message: 'Alla uppladdningar har hanterats',
        priority: NotificationPriority.low,
        data: {'totalProcessed': totalProcessed},
        timestamp: DateTime.now(),
      ));
      _notificationTriggers.clear(); // Reset triggers
    }
  }

  /// Trigger progress milestone notification (e.g., 25%, 50%, 75% complete)
  void triggerSignificantProgressNotification(int completed, int total, double percentage) {
    // Only notify at significant milestones (25%, 50%, 75%)
    final milestones = [25, 50, 75];
    final currentPercentage = (percentage * 100).round();

    if (milestones.contains(currentPercentage)) {
      sendNotificationEvent(UploadNotificationEvent(
        trigger: UploadNotificationTrigger.significantProgress,
        title: 'Uppladdning pågår',
        message: '$completed av $total bilder uppladdade ($currentPercentage%)',
        priority: NotificationPriority.low,
        data: {
          'completed': completed,
          'total': total,
          'percentage': percentage,
        },
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Check and trigger appropriate notifications based on upload queue state
  void checkAndTriggerNotifications({
    required int total,
    required int completed,
    required int failed,
    required int active,
  }) {
    // Trigger completion notification if all uploads are done
    if (total > 0 && completed == total && active == 0) {
      triggerCompletionNotification(total);
    }

    // Trigger major failure notification if significant failures
    if (failed > 0) {
      triggerMajorFailureNotification(failed, total);
    }

    // Trigger queue cleared if everything is finished
    if (total == 0 || (active == 0 && completed + failed == total)) {
      triggerQueueClearedNotification(total);
    }
  }

  /// Reset notification state (useful when starting new upload batch)
  void resetNotificationState() {
    _notificationTriggers.clear();
    _lastNotificationTime = null;
  }

  /// Get notification summary for debugging
  Map<String, dynamic> getNotificationSummary() {
    return {
      'triggersSent': _notificationTriggers.map((t) => t.name).toList(),
      'lastNotificationTime': _lastNotificationTime?.toIso8601String(),
      'canSendNotification': _canSendNotification(),
    };
  }

  /// Dispose of resources (close stream controller)
  static void dispose() {
    _notificationController.close();
  }
}
