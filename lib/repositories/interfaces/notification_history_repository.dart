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

  /// BUT-952: bulk mark every unread notification for [userId] as opened.
  /// Returns the number of docs updated. Uses batched writes (chunks of
  /// 500 per Firestore batch limit). Caller must verify the authenticated
  /// uid matches [userId].
  Future<int> markAllAsOpenedForUser(String userId);

  /// Fetches notification history for a user, ordered by sentAt descending.
  /// Uses cursor-based pagination via [before].
  Future<List<NotificationHistoryEntry>> getHistory(
    String userId, {
    int limit = 20,
    DateTime? before,
  });

  /// Delete every `notification_history` doc owned by [userId]. GDPR Art. 17.
  /// Returns the number of docs deleted (0 if none).
  Future<int> deleteAllByUser(String userId);

  /// BUT-1080: bulk-delete the [docIds] owned by [userId] in batched writes
  /// (chunks of 500). Only docs that are BOTH in [docIds] AND owned by
  /// [userId] are deleted — foreign IDs are silently ignored. Caller must
  /// verify the authenticated uid matches [userId]. Returns the number deleted.
  Future<int> deleteByIds(List<String> docIds, String userId);
}
