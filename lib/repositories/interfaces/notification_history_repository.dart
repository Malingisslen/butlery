import 'package:butlery/models/notification_history_entry.dart';
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

  /// Fetches notification history for a user, ordered by sentAt descending.
  /// Uses cursor-based pagination via [before].
  Future<List<NotificationHistoryEntry>> getHistory(
    String userId, {
    int limit = 20,
    DateTime? before,
  });
}
