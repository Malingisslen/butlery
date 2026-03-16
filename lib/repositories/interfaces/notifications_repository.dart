import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_preferences.dart';
export 'package:butlery/models/notification_preferences.dart';

/// Repository interface for notification management with FCM integration and user preferences.
abstract class NotificationsRepository extends Repository<UserNotification> {
  /// Send a notification to a user
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  /// Send notifications to multiple users
  Future<void> sendBulkNotifications({
    required List<String> userIds,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });

  /// Get notifications for a user
  Future<List<UserNotification>> getUserNotifications(
    String userId, {
    int limit = 50,
    DateTime? since,
  });

  /// Mark notification as read
  Future<void> markAsRead(String notificationId);

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds);

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId);

  /// Delete a notification
  Future<void> deleteNotification(String notificationId);

  /// Get unread notification count for a user
  Future<int> getUnreadCount(String userId);

  /// Get notifications stream for real-time updates
  Stream<List<UserNotification>> getNotificationsStream(String userId);

  /// Update FCM token for a user
  Future<void> updateFCMToken(String userId, String token);

  /// Remove FCM token for a user
  Future<void> removeFCMToken(String userId, String token);

  /// Update notification preferences
  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  );

  /// Get notification preferences
  Future<NotificationPreferences> getNotificationPreferences(String userId);

  /// Save FCM token to Firestore (per-device model)
  Future<void> saveTokenToFirestore(
      String docId, Map<String, dynamic> tokenData);

  /// Update device information
  Future<void> updateDeviceInfo(String docId, Map<String, dynamic> deviceData);

  /// Update token timestamp without changing token data
  Future<void> updateTokenTimestamp(String docId);

  /// Remove old token by marking as inactive
  Future<void> removeOldToken(String userId, String oldToken);

  /// Get all active tokens for a user
  Future<List<String>> getAllUserTokens(String userId);

  /// Mark device as inactive
  Future<void> markDeviceInactive(String docId);

  /// Cleanup old devices for a user
  Future<void> cleanupOldDevices(String userId, DateTime olderThan);
}

/// User notification model
class UserNotification {
  final String id;
  final String userId;
  final String? senderId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  UserNotification({
    required this.id,
    required this.userId,
    this.senderId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        if (senderId != null) 'senderId': senderId,
        'type': type.toString(),
        'title': title,
        'body': body,
        'data': data,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
        'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      };

  factory UserNotification.fromFirestore(
          Map<String, dynamic> data, String id) =>
      UserNotification(
        id: id,
        userId: data['userId'] ?? '',
        senderId: data['senderId'] as String?,
        type: NotificationType.values.firstWhere(
          (e) => e.toString() == data['type'],
          orElse: () => NotificationType.optional,
        ),
        title: data['title'] ?? '',
        body: data['body'] ?? '',
        data: data['data'],
        isRead: data['isRead'] ?? false,
        createdAt:
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        readAt: (data['readAt'] as Timestamp?)?.toDate(),
      );
}
