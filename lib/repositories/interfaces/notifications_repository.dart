import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/services/notifications/notification_types.dart';

/// Repository interface for push notification and user notification management.
///
/// This interface provides comprehensive notification operations including push
/// notification delivery, notification preferences management, and real-time
/// notification streaming. It integrates with Firebase Cloud Messaging (FCM)
/// to deliver timely notifications about social activities, recipe sharing, and
/// system updates.
///
/// **Core Notification Features:**
/// - **Push Notifications**: Send individual and bulk push notifications via FCM
/// - **Notification History**: Persistent storage and retrieval of user notifications
/// - **Real-time Streams**: Live notification updates for reactive UI
/// - **Preference Management**: User-controlled notification settings and filtering
/// - **FCM Integration**: Token management and push notification delivery
/// - **Notification Categorization**: Type-based notification organization and filtering
///
/// **Notification Types:**
/// Supports various notification categories including recipe sharing, friend requests,
/// group invitations, comments, ratings, collaborative editing, and system updates.
/// Each type can be individually controlled through user preferences.
///
/// **Performance and UX:**
/// - Implements efficient notification querying with pagination
/// - Supports batch operations for better performance
/// - Provides unread count tracking for UI badges
/// - Enables notification marking and cleanup operations
///
/// **Privacy and Control:**
/// Respects user notification preferences, supports granular notification control,
/// and provides opt-out mechanisms for different notification categories.
///
/// **Usage Examples:**
/// ```dart
/// final notificationRepo = sl<NotificationsRepository>();
/// 
/// // Send notification to user
/// await notificationRepo.sendNotification(
///   userId: friendUserId,
///   type: NotificationType.friendRequest,
///   title: 'New Friend Request',
///   body: '${currentUser.name} wants to be your friend!',
///   data: {'requestId': requestId},
/// );
/// 
/// // Listen to notifications
/// notificationRepo.getNotificationsStream(userId).listen((notifications) {
///   updateNotificationBadge(notifications.where((n) => !n.isRead).length);
/// });
/// 
/// // Manage preferences
/// final preferences = NotificationPreferences(
///   enableFriendRequests: true,
///   enableRecipeSharing: false,
/// );
/// await notificationRepo.updateNotificationPreferences(userId, preferences);
/// ```
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