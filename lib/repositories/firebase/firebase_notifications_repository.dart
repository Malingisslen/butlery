// lib/repositories/firebase/firebase_notifications_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/notifications_repository.dart';
import '../../services/notifications/notification_types.dart';
import 'base_firebase_repository.dart';

/// Firebase implementation of NotificationsRepository
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
    await collection.doc(notificationId).update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    final batch = firestore.batch();
    
    for (final id in notificationIds) {
      batch.update(collection.doc(id), {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }

  @override
  Future<void> markAllAsRead(String userId) async {
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
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await collection.doc(notificationId).delete();
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
    final prefsCollection = firestore.collection('user_notification_preferences');
    await prefsCollection.doc(userId).set(
      preferences.toFirestore(),
      SetOptions(merge: true),
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