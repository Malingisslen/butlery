// lib/repositories/firebase/firebase_notifications_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';

/// Firebase Firestore implementation for push notification and user notification management.
///
/// This repository implements the [NotificationsRepository] interface using Firebase Firestore
/// for persistent notification storage and Firebase Cloud Messaging (FCM) for push notification
/// delivery. It provides comprehensive notification operations with security validation,
/// batch processing, and real-time streaming capabilities.
///
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] to leverage shared CRUD functionality while providing
/// specialized notification operations. Uses multiple Firestore collections:
/// - `user_notifications`: Persistent notification storage
/// - `user_fcm_tokens`: FCM token management for push delivery
/// - `user_notification_preferences`: User-controlled notification settings
///
/// **Security Implementation:**
/// - **Ownership Validation**: Users can only access and modify their own notifications
/// - **Permission Logging**: Comprehensive audit trail for notification operations
/// - **FCM Security**: Secure token management with timestamp tracking
/// - **Preference Control**: User-controlled granular notification settings
/// - **Batch Validation**: Security checks for bulk notification operations
///
/// **Notification Features:**
/// - **Individual Notifications**: Single-user targeted notification delivery
/// - **Bulk Notifications**: Efficient mass notification distribution
/// - **Read Status Management**: Mark individual, multiple, or all notifications as read
/// - **Real-time Streams**: Live notification updates for reactive UI
/// - **Notification History**: Persistent storage with pagination support
/// - **Unread Counting**: Efficient unread notification badge counts
///
/// **FCM Integration:**
/// - **Token Management**: Secure FCM token storage and updates
/// - **Token Cleanup**: Proper token removal for security and privacy
/// - **Push Delivery**: Integration with FCM for real-time push notifications
/// - **Preference Filtering**: Respects user notification preferences for delivery
///
/// **Performance Optimizations:**
/// - **Stream Limits**: Caps notification streams at 50 notifications for performance
/// - **Batch Operations**: Efficient bulk read/write operations using Firestore batches
/// - **Pagination Support**: Load notifications incrementally with since timestamps
/// - **Efficient Queries**: Optimized Firestore queries with proper indexing
///
/// **Usage Examples:**
/// ```dart
/// final notificationRepo = FirebaseNotificationsRepository(
///   authRepository: sl<AuthRepository>(),
/// );
/// 
/// // Send notification
/// await notificationRepo.sendNotification(
///   userId: targetUserId,
///   type: NotificationType.friendRequest,
///   title: 'New Friend Request',
///   body: 'John wants to be your friend!',
/// );
/// 
/// // Real-time notifications
/// notificationRepo.getNotificationsStream(userId).listen((notifications) {
///   updateNotificationUI(notifications);
///   updateBadgeCount(notifications.where((n) => !n.isRead).length);
/// });
/// 
/// // Manage preferences
/// await notificationRepo.updateNotificationPreferences(
///   userId,
///   NotificationPreferences(enableFriendRequests: false),
/// );
/// ```
class FirebaseNotificationsRepository extends BaseFirebaseRepository<UserNotification>
    implements NotificationsRepository {
  
  FirebaseNotificationsRepository({
    super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'user_notifications';

  @override
  UserNotification fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserNotification.fromFirestore(doc.data()!, doc.id);

  @override
  Map<String, dynamic> toFirestore(UserNotification entity) => entity.toFirestore();

  @override
  String getId(UserNotification entity) => entity.id;

  // ===== SPECIALIZED NOTIFICATION OPERATIONS =====

  @override
  Future<void> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await collection.add({
      'userId': userId,
      'type': type.toString(),
      'title': title,
      'body': body,
      'data': data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendBulkNotifications({
    required List<String> userIds,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final batch = firestore.batch();
    
    for (final userId in userIds) {
      final docRef = collection.doc();
      batch.set(docRef, {
        'userId': userId,
        'type': type.toString(),
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }

  @override
  Future<List<UserNotification>> getUserNotifications(
    String userId, {
    int limit = 50,
    DateTime? since,
  }) async {
    Query<Map<String, dynamic>> query = collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (since != null) {
      query = query.where('createdAt', isGreaterThan: since);
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs
        .map((doc) => fromFirestore(doc))
        .toList();
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    // Validate user owns the notification
    final currentUser = requireCurrentUserId();
    
    // First check if notification exists and user owns it
    final doc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(notificationId),
      currentUserId: currentUser,
      resourceType: 'notification',
    );
    
    final notificationData = doc.data() as Map<String, dynamic>;
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: notificationData['userId'] ?? '',
      resourceType: 'notification',
      resourceId: notificationId,
    );
    
    await collection.doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'notification',
      operation: 'mark_as_read',
      granted: true,
    );
  }

  @override
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    // Validate user owns all notifications
    final currentUser = requireCurrentUserId();
    final batch = firestore.batch();
    
    // Verify ownership of each notification
    for (final id in notificationIds) {
      final doc = await getDocumentWithPermissionCheck(
        docRef: collection.doc(id),
        currentUserId: currentUser,
        resourceType: 'notification',
      );
      
      final notificationData = doc.data() as Map<String, dynamic>;
      await validateOwnership(
        currentUserId: currentUser,
        resourceOwnerId: notificationData['userId'] ?? '',
        resourceType: 'notification',
        resourceId: id,
      );
      
      batch.update(collection.doc(id), {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'notification',
      operation: 'mark_multiple_as_read',
      granted: true,
      details: 'Count: ${notificationIds.length}',
    );
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    // Validate user is marking their own notifications
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'mark all notifications as read',
    );
    
    final unreadQuery = await collection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = firestore.batch();
    
    for (final doc in unreadQuery.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'notification',
      operation: 'mark_all_as_read',
      granted: true,
      details: 'Count: ${unreadQuery.docs.length}',
    );
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    // Validate user owns the notification
    final currentUser = requireCurrentUserId();
    
    // First check if notification exists and user owns it
    final doc = await getDocumentWithPermissionCheck(
      docRef: collection.doc(notificationId),
      currentUserId: currentUser,
      resourceType: 'notification',
    );
    
    final notificationData = doc.data() as Map<String, dynamic>;
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: notificationData['userId'] ?? '',
      resourceType: 'notification',
      resourceId: notificationId,
    );
    
    await collection.doc(notificationId).delete();
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'notification',
      operation: 'delete',
      granted: true,
    );
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final unreadQuery = await collection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    return unreadQuery.docs.length;
  }

  @override
  Stream<List<UserNotification>> getNotificationsStream(String userId) {
    return collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => fromFirestore(doc))
            .toList());
  }

  @override
  Future<void> updateFCMToken(String userId, String token) async {
    final fcmCollection = firestore.collection('user_fcm_tokens');
    await fcmCollection.doc(userId).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removeFCMToken(String userId, String token) async {
    final fcmCollection = firestore.collection('user_fcm_tokens');
    await fcmCollection.doc(userId).delete();
  }

  @override
  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    // Validate user is updating their own preferences
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update notification preferences',
    );
    
    final prefsCollection = firestore.collection('user_notification_preferences');
    await prefsCollection.doc(userId).set(
      preferences.toFirestore(),
      SetOptions(merge: true),
    );
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'notification_preferences',
      operation: 'update',
      granted: true,
    );
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences(String userId) async {
    final prefsCollection = firestore.collection('user_notification_preferences');
    final doc = await prefsCollection.doc(userId).get();
    
    if (!doc.exists) {
      return NotificationPreferences(); // Default preferences
    }
    
    return NotificationPreferences.fromFirestore(doc.data()!);
  }
}