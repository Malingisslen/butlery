import 'repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notifications/notification_types.dart';

/// Repository interface for notification operations
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
}

/// User notification model
class UserNotification {
  final String id;
  final String userId;
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
    'type': type.toString(),
    'title': title,
    'body': body,
    'data': data,
    'isRead': isRead,
    'createdAt': createdAt,
    'readAt': readAt,
  };

  factory UserNotification.fromFirestore(Map<String, dynamic> data, String id) => UserNotification(
    id: id,
    userId: data['userId'] ?? '',
    type: NotificationType.values.firstWhere(
      (e) => e.toString() == data['type'],
      orElse: () => NotificationType.optional,
    ),
    title: data['title'] ?? '',
    body: data['body'] ?? '',
    data: data['data'],
    isRead: data['isRead'] ?? false,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    readAt: (data['readAt'] as Timestamp?)?.toDate(),
  );
}

/// Notification preferences for a user
class NotificationPreferences {
  final bool enableRecipeSharing;
  final bool enableFriendRequests;
  final bool enableGroupInvitations;
  final bool enableComments;
  final bool enableRatings;
  final bool enableCollaborativeEditing;
  final bool enableMenuSharing;
  final bool enableGeneralUpdates;

  NotificationPreferences({
    this.enableRecipeSharing = true,
    this.enableFriendRequests = true,
    this.enableGroupInvitations = true,
    this.enableComments = true,
    this.enableRatings = true,
    this.enableCollaborativeEditing = true,
    this.enableMenuSharing = true,
    this.enableGeneralUpdates = true,
  });

  Map<String, dynamic> toFirestore() => {
    'enableRecipeSharing': enableRecipeSharing,
    'enableFriendRequests': enableFriendRequests,
    'enableGroupInvitations': enableGroupInvitations,
    'enableComments': enableComments,
    'enableRatings': enableRatings,
    'enableCollaborativeEditing': enableCollaborativeEditing,
    'enableMenuSharing': enableMenuSharing,
    'enableGeneralUpdates': enableGeneralUpdates,
  };

  factory NotificationPreferences.fromFirestore(Map<String, dynamic> data) => NotificationPreferences(
    enableRecipeSharing: data['enableRecipeSharing'] ?? true,
    enableFriendRequests: data['enableFriendRequests'] ?? true,
    enableGroupInvitations: data['enableGroupInvitations'] ?? true,
    enableComments: data['enableComments'] ?? true,
    enableRatings: data['enableRatings'] ?? true,
    enableCollaborativeEditing: data['enableCollaborativeEditing'] ?? true,
    enableMenuSharing: data['enableMenuSharing'] ?? true,
    enableGeneralUpdates: data['enableGeneralUpdates'] ?? true,
  );
}