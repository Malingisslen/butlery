import 'package:butlery/services/notifications/notification_types.dart';

/// Repository interface for notification dedup and delivery tracking.
abstract class NotificationHistoryRepository {
  Future<void> recordNotification({
    required String notificationId,
    required NotificationCategory category,
    required NotificationType type,
    required Map<String, dynamic> data,
  });

  Future<bool> wasNotificationSent(String notificationId);

  Future<void> markNotificationDelivered(String notificationId);

  Future<void> markNotificationOpened(String notificationId);
}
