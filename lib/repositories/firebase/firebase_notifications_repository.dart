// lib/repositories/firebase/firebase_notifications_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for notification management with FCM integration.
/// Uses `user_notifications`, `user_fcm_tokens`, and `user_notification_preferences` collections.
class FirebaseNotificationsRepository
    extends BaseFirebaseRepository<UserNotification>
    implements NotificationsRepository {
  FirebaseNotificationsRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.userNotifications;

  @override
  UserNotification fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserNotification.fromFirestore(doc.data()!, doc.id);

  @override
  Map<String, dynamic> toFirestore(UserNotification entity) =>
      entity.toFirestore();

  @override
  String getId(UserNotification entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
    String userId,
    UserNotification entity,
  ) async {
    // Only the authenticated sender can create notifications.
    // System/server notifications bypass client SDK via Cloud Functions.
    if (entity.senderId == null) return false;
    return userId == entity.senderId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    UserNotification? entity,
  ) async {
    if (entity == null) return false;

    // Users can only read their own notifications
    return entity.userId == userId;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    UserNotification entity,
  ) async {
    // Users can only update their own notifications (mark as read)
    return entity.userId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Users can only delete their own notifications
    try {
      final notification = await read(resourceId);
      if (notification == null) return false;
      return notification.userId == userId;
    } catch (e) {
      return false;
    }
  }

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
      'senderId':
          currentUserId, // 🔒 SECURITY: Required by firestore.rules for spam prevention
      'type': type.toString(),
      'title': title,
      'body': body,
      'data': data,
      'isRead': false,
      'createdAt': timestampProvider.serverTimestamp(),
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
        'senderId':
            currentUserId, // 🔒 SECURITY: Required by firestore.rules for spam prevention
        'type': type.toString(),
        'title': title,
        'body': body,
        'data': data,
        'isRead': false,
        'createdAt': timestampProvider.serverTimestamp(),
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
      query =
          query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
    }

    final querySnapshot = await query.get();
    return querySnapshot.docs.map((doc) => fromFirestore(doc)).toList();
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
      resourceOwnerId: (notificationData['userId'] as String?).orEmpty(),
      resourceType: 'notification',
      resourceId: notificationId,
    );

    await collection.doc(notificationId).update({
      'isRead': true,
      'readAt': timestampProvider.serverTimestamp(),
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

    // Verify ownership of all notifications in parallel
    await Future.wait(notificationIds.map((id) async {
      final doc = await getDocumentWithPermissionCheck(
        docRef: collection.doc(id),
        currentUserId: currentUser,
        resourceType: 'notification',
      );

      final notificationData = doc.data() as Map<String, dynamic>;
      await validateOwnership(
        currentUserId: currentUser,
        resourceOwnerId: (notificationData['userId'] as String?).orEmpty(),
        resourceType: 'notification',
        resourceId: id,
      );

      batch.update(collection.doc(id), {
        'isRead': true,
        'readAt': timestampProvider.serverTimestamp(),
      });
    }));

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

    final docs = unreadQuery.docs;
    for (var i = 0; i < docs.length; i += 500) {
      final batch = firestore.batch();
      for (final doc in docs.skip(i).take(500)) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': timestampProvider.serverTimestamp(),
        });
      }
      await batch.commit();
    }

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
      resourceOwnerId: (notificationData['userId'] as String?).orEmpty(),
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
    final countResult = await collection
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();

    return countResult.count ?? 0;
  }

  @override
  Stream<List<UserNotification>> getNotificationsStream(String userId) {
    return collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) => fromFirestore(doc)).toList(),
        );
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

    final prefsCollection = firestore.collection(
      'user_notification_preferences',
    );
    await prefsCollection
        .doc(userId)
        .set(preferences.toFirestore(), SetOptions(merge: true));

    logPermissionCheck(
      userId: currentUser,
      resource: 'notification_preferences',
      operation: 'update',
      granted: true,
    );
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences(
    String userId,
  ) async {
    final prefsCollection = firestore.collection(
      'user_notification_preferences',
    );
    final doc = await prefsCollection.doc(userId).get();

    if (!doc.exists) {
      return NotificationPreferences.defaults();
    }

    return NotificationPreferences.fromFirestore(doc);
  }
}
