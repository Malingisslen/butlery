/// Comprehensive unit tests for FirebaseNotificationsRepository.
///
/// Tests push notification and user notification management including notification
/// delivery, FCM token management, read status tracking, and notification preferences.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseNotificationsRepository - Notification System', () {
    late FirebaseNotificationsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: 'user-123', displayName: 'Test User');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseNotificationsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should allow system to create notification for any user', () async {
        // Arrange
        final notification = _createNotification('user-123');

        // Act
        final canCreate = await repository.validateCreatePermission('system', notification);

        // Assert
        expect(canCreate, isTrue); // System can create for any user
      });

      test('should allow users to create notification for themselves', () async {
        // Arrange
        final notification = _createNotification('user-123');

        // Act
        final canCreate = await repository.validateCreatePermission('user-123', notification);

        // Assert
        expect(canCreate, isTrue);
      });

      test('should allow user to read their own notification', () async {
        // Arrange
        final notification = _createNotification('user-123');

        // Act
        final canRead = await repository.validateReadPermission('user-123', 'notif-1', notification);

        // Assert
        expect(canRead, isTrue);
      });

      test('should reject user from reading another user\'s notification', () async {
        // Arrange
        final notification = _createNotification('other-user');

        // Act
        final canRead = await repository.validateReadPermission('user-123', 'notif-1', notification);

        // Assert
        expect(canRead, isFalse); // Can't read other user's notifications
      });

      test('should reject read when notification is null', () async {
        // Act
        final canRead = await repository.validateReadPermission('user-123', 'notif-1', null);

        // Assert
        expect(canRead, isFalse);
      });

      test('should allow user to update their own notification', () async {
        // Arrange
        final notification = _createNotification('user-123');

        // Act
        final canUpdate = await repository.validateUpdatePermission('user-123', 'notif-1', notification);

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject user from updating another user\'s notification', () async {
        // Arrange
        final notification = _createNotification('other-user');

        // Act
        final canUpdate = await repository.validateUpdatePermission('user-123', 'notif-1', notification);

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow user to delete their own notification', () async {
        // Arrange
        const notificationId = 'notif-1';
        final notification = _createNotification('user-123', id: notificationId);
        await _seedNotification(fakeFirestore, notificationId, notification);

        // Act
        final canDelete = await repository.validateDeletePermission('user-123', notificationId);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject user from deleting another user\'s notification', () async {
        // Arrange
        const notificationId = 'notif-1';
        final notification = _createNotification('other-user', id: notificationId);
        await _seedNotification(fakeFirestore, notificationId, notification);

        // Act
        final canDelete = await repository.validateDeletePermission('user-123', notificationId);

        // Assert
        expect(canDelete, isFalse);
      });

      test('should reject delete when notification does not exist', () async {
        // Act
        final canDelete = await repository.validateDeletePermission('user-123', 'nonexistent');

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Send Notification', () {
      test('should send notification to user successfully', () async {
        // Arrange
        const userId = 'user-123';
        const type = NotificationType.immediate;
        const title = 'New Friend Request';
        const body = 'John wants to be your friend';
        final data = {'requestId': 'req-1'};

        // Act
        await repository.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        final docs = await fakeFirestore.collection('user_notifications').get();
        expect(docs.docs.length, equals(1));
        final notificationData = docs.docs.first.data();
        expect(notificationData['userId'], equals(userId));
        expect(notificationData['title'], equals(title));
        expect(notificationData['body'], equals(body));
        expect(notificationData['data'], equals(data));
        expect(notificationData['isRead'], isFalse);
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');
    });

    group('Send Bulk Notifications', () {
      test('should send bulk notifications to multiple users', () async {
        // Arrange
        final userIds = ['user-1', 'user-2', 'user-3'];
        const type = NotificationType.batchable;
        const title = 'New Recipe Shared';
        const body = 'Someone shared a recipe with you';

        // Act
        await repository.sendBulkNotifications(
          userIds: userIds,
          type: type,
          title: title,
          body: body,
        );

        // Assert
        final docs = await fakeFirestore.collection('user_notifications').get();
        expect(docs.docs.length, equals(3));
        expect(docs.docs.every((doc) => doc.data()['title'] == title), isTrue);
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');
    });

    group('Get User Notifications', () {
      test('should retrieve user notifications', () async {
        // Arrange
        const userId = 'user-123';
        await _seedNotification(fakeFirestore, 'notif-1', _createNotification(userId, id: 'notif-1'));
        await _seedNotification(fakeFirestore, 'notif-2', _createNotification(userId, id: 'notif-2'));
        await _seedNotification(fakeFirestore, 'notif-3', _createNotification('other-user', id: 'notif-3'));

        // Act
        final notifications = await repository.getUserNotifications(userId);

        // Assert
        expect(notifications.length, equals(2)); // Only user-123's notifications
        expect(notifications.every((n) => n.userId == userId), isTrue);
      });

      test('should respect limit parameter', () async {
        // Arrange
        const userId = 'user-123';
        for (int i = 0; i < 60; i++) {
          await _seedNotification(fakeFirestore, 'notif-$i', _createNotification(userId, id: 'notif-$i'));
        }

        // Act
        final notifications = await repository.getUserNotifications(userId, limit: 50);

        // Assert
        expect(notifications.length, equals(50)); // Enforces limit
      });

      test('should filter by since parameter', () async {
        // Arrange
        const userId = 'user-123';
        final now = DateTime.now();
        final oldDate = now.subtract(const Duration(days: 5));
        final recentDate = now.subtract(const Duration(hours: 1));

        await _seedNotification(fakeFirestore, 'old-notif', _createNotification(userId, id: 'old-notif', createdAt: oldDate));
        await _seedNotification(fakeFirestore, 'recent-notif', _createNotification(userId, id: 'recent-notif', createdAt: recentDate));

        // Act
        final notifications = await repository.getUserNotifications(
          userId,
          since: now.subtract(const Duration(days: 2)),
        );

        // Assert
        expect(notifications.length, equals(1)); // Only recent notification
        expect(notifications.first.id, equals('recent-notif'));
      });

      test('should return empty list when user has no notifications', () async {
        // Act
        final notifications = await repository.getUserNotifications('user-with-no-notifications');

        // Assert
        expect(notifications, isEmpty);
      });
    });

    group('Mark As Read', () {
      test('should mark notification as read successfully', () async {
        // Arrange
        const notificationId = 'notif-1';
        final notification = _createNotification('user-123', id: notificationId, isRead: false);
        await _seedNotification(fakeFirestore, notificationId, notification);

        // Act
        await repository.markAsRead(notificationId);

        // Assert
        final doc = await fakeFirestore.collection('user_notifications').doc(notificationId).get();
        expect(doc.data()!['isRead'], isTrue);
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should reject marking another user\'s notification as read', () async {
        // Arrange
        const notificationId = 'notif-1';
        final notification = _createNotification('other-user', id: notificationId);
        await _seedNotification(fakeFirestore, notificationId, notification);

        // Act & Assert
        expect(
          () => repository.markAsRead(notificationId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject when notification does not exist', () async {
        // Act & Assert
        expect(
          () => repository.markAsRead('nonexistent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Mark Multiple As Read', () {
      test('should mark multiple notifications as read', () async {
        // Arrange
        const notificationIds = ['notif-1', 'notif-2', 'notif-3'];
        for (final id in notificationIds) {
          await _seedNotification(fakeFirestore, id, _createNotification('user-123', id: id, isRead: false));
        }

        // Act
        await repository.markMultipleAsRead(notificationIds);

        // Assert
        for (final id in notificationIds) {
          final doc = await fakeFirestore.collection('user_notifications').doc(id).get();
          expect(doc.data()!['isRead'], isTrue);
        }
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should reject marking another user\'s notifications as read', () async {
        // Arrange
        const notificationIds = ['notif-1', 'notif-2'];
        await _seedNotification(fakeFirestore, 'notif-1', _createNotification('user-123', id: 'notif-1'));
        await _seedNotification(fakeFirestore, 'notif-2', _createNotification('other-user', id: 'notif-2'));

        // Act & Assert
        expect(
          () => repository.markMultipleAsRead(notificationIds),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Mark All As Read', () {
      test('should mark all user notifications as read', () async {
        // Arrange
        const userId = 'user-123';
        await _seedNotification(fakeFirestore, 'notif-1', _createNotification(userId, id: 'notif-1', isRead: false));
        await _seedNotification(fakeFirestore, 'notif-2', _createNotification(userId, id: 'notif-2', isRead: false));
        await _seedNotification(fakeFirestore, 'notif-3', _createNotification('other-user', id: 'notif-3', isRead: false));

        // Act
        await repository.markAllAsRead(userId);

        // Assert
        final doc1 = await fakeFirestore.collection('user_notifications').doc('notif-1').get();
        final doc2 = await fakeFirestore.collection('user_notifications').doc('notif-2').get();
        final doc3 = await fakeFirestore.collection('user_notifications').doc('notif-3').get();

        expect(doc1.data()!['isRead'], isTrue); // user-123's notification
        expect(doc2.data()!['isRead'], isTrue); // user-123's notification
        expect(doc3.data()!['isRead'], isFalse); // other-user's notification unchanged
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should reject marking all notifications for another user', () async {
        // Act & Assert
        expect(
          () => repository.markAllAsRead('other-user'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Delete Notification', () {
      test('should delete notification successfully', () async {
        // Arrange
        const notificationId = 'notif-1';
        final notification = _createNotification('user-123', id: notificationId);
        await _seedNotification(fakeFirestore, notificationId, notification);

        // Verify notification exists
        var doc = await fakeFirestore.collection('user_notifications').doc(notificationId).get();
        expect(doc.exists, isTrue);

        // Act
        await repository.deleteNotification(notificationId);

        // Assert
        doc = await fakeFirestore.collection('user_notifications').doc(notificationId).get();
        expect(doc.exists, isFalse);
      });

      test('should reject deleting another user\'s notification', () async {
        // Arrange
        const notificationId = 'notif-1';
        final notification = _createNotification('other-user', id: notificationId);
        await _seedNotification(fakeFirestore, notificationId, notification);

        // Act & Assert
        expect(
          () => repository.deleteNotification(notificationId),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject delete when notification does not exist', () async {
        // Act & Assert
        expect(
          () => repository.deleteNotification('nonexistent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Get Unread Count', () {
      test('should count unread notifications correctly', () async {
        // Arrange
        const userId = 'user-123';
        await _seedNotification(fakeFirestore, 'notif-1', _createNotification(userId, id: 'notif-1', isRead: false));
        await _seedNotification(fakeFirestore, 'notif-2', _createNotification(userId, id: 'notif-2', isRead: false));
        await _seedNotification(fakeFirestore, 'notif-3', _createNotification(userId, id: 'notif-3', isRead: true));

        // Act
        final count = await repository.getUnreadCount(userId);

        // Assert
        expect(count, equals(2)); // Only unread notifications
      });

      test('should return 0 when all notifications are read', () async {
        // Arrange
        const userId = 'user-123';
        await _seedNotification(fakeFirestore, 'notif-1', _createNotification(userId, id: 'notif-1', isRead: true));

        // Act
        final count = await repository.getUnreadCount(userId);

        // Assert
        expect(count, equals(0));
      });

      test('should return 0 when user has no notifications', () async {
        // Act
        final count = await repository.getUnreadCount('user-with-no-notifications');

        // Assert
        expect(count, equals(0));
      });
    });

    group('Notifications Stream', () {
      test('should stream user notifications', () async {
        // Arrange
        const userId = 'user-123';
        await _seedNotification(fakeFirestore, 'notif-1', _createNotification(userId, id: 'notif-1'));
        await _seedNotification(fakeFirestore, 'notif-2', _createNotification(userId, id: 'notif-2'));

        // Act
        final stream = repository.getNotificationsStream(userId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<UserNotification>>((notifications) {
            return notifications.length == 2 && notifications.every((n) => n.userId == userId);
          })),
        );
      });

      test('should enforce 50 notification limit in stream', () async {
        // Arrange
        const userId = 'user-123';
        for (int i = 0; i < 60; i++) {
          await _seedNotification(fakeFirestore, 'notif-$i', _createNotification(userId, id: 'notif-$i'));
        }

        // Act
        final stream = repository.getNotificationsStream(userId);

        // Assert
        await expectLater(
          stream.first,
          completion(predicate<List<UserNotification>>((notifications) {
            return notifications.length == 50; // Enforces limit
          })),
        );
      });

      test('should return empty stream when user has no notifications', () async {
        // Act
        final stream = repository.getNotificationsStream('user-with-no-notifications');

        // Assert
        await expectLater(
          stream.first,
          completion(isEmpty),
        );
      });
    });

    group('FCM Token Management', () {
      test('should update FCM token successfully', () async {
        // Arrange
        const userId = 'user-123';
        const token = 'fcm-token-abc123';

        // Act
        await repository.updateFCMToken(userId, token);

        // Assert
        final doc = await fakeFirestore.collection('user_fcm_tokens').doc(userId).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['token'], equals(token));
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should update existing FCM token', () async {
        // Arrange
        const userId = 'user-123';
        const oldToken = 'old-token';
        const newToken = 'new-token';

        await fakeFirestore.collection('user_fcm_tokens').doc(userId).set({
          'token': oldToken,
          'updatedAt': Timestamp.now(),
        });

        // Act
        await repository.updateFCMToken(userId, newToken);

        // Assert
        final doc = await fakeFirestore.collection('user_fcm_tokens').doc(userId).get();
        expect(doc.data()!['token'], equals(newToken));
      }, skip: 'FakeFirebaseFirestore server timestamp limitation - tested in integration tests');

      test('should remove FCM token successfully', () async {
        // Arrange
        const userId = 'user-123';
        await fakeFirestore.collection('user_fcm_tokens').doc(userId).set({
          'token': 'fcm-token',
          'updatedAt': Timestamp.now(),
        });

        // Verify token exists
        var doc = await fakeFirestore.collection('user_fcm_tokens').doc(userId).get();
        expect(doc.exists, isTrue);

        // Act
        await repository.removeFCMToken(userId, 'fcm-token');

        // Assert
        doc = await fakeFirestore.collection('user_fcm_tokens').doc(userId).get();
        expect(doc.exists, isFalse);
      });
    });

    group('Notification Preferences', () {
      test('should update notification preferences successfully', () async {
        // Arrange
        const userId = 'user-123';
        final preferences = NotificationPreferences(
          enableRecipeSharing: false,
          enableFriendRequests: true,
          enableGroupInvitations: false,
        );

        // Act
        await repository.updateNotificationPreferences(userId, preferences);

        // Assert
        final doc = await fakeFirestore.collection('user_notification_preferences').doc(userId).get();
        expect(doc.exists, isTrue);
        expect(doc.data()!['enableRecipeSharing'], isFalse);
        expect(doc.data()!['enableFriendRequests'], isTrue);
        expect(doc.data()!['enableGroupInvitations'], isFalse);
      });

      test('should reject updating preferences for another user', () async {
        // Arrange
        final preferences = NotificationPreferences();

        // Act & Assert
        expect(
          () => repository.updateNotificationPreferences('other-user', preferences),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should get notification preferences', () async {
        // Arrange
        const userId = 'user-123';
        await fakeFirestore.collection('user_notification_preferences').doc(userId).set({
          'enableRecipeSharing': false,
          'enableFriendRequests': true,
          'enableGroupInvitations': false,
          'enableComments': true,
          'enableRatings': true,
          'enableCollaborativeEditing': true,
          'enableMenuSharing': true,
          'enableGeneralUpdates': true,
        });

        // Act
        final preferences = await repository.getNotificationPreferences(userId);

        // Assert
        expect(preferences.enableRecipeSharing, isFalse);
        expect(preferences.enableFriendRequests, isTrue);
        expect(preferences.enableGroupInvitations, isFalse);
      });

      test('should return default preferences when none exist', () async {
        // Act
        final preferences = await repository.getNotificationPreferences('user-with-no-prefs');

        // Assert - All defaults should be true
        expect(preferences.enableRecipeSharing, isTrue);
        expect(preferences.enableFriendRequests, isTrue);
        expect(preferences.enableGroupInvitations, isTrue);
        expect(preferences.enableComments, isTrue);
      });
    });

    group('Notification Model Integration', () {
      test('should correctly serialize and deserialize notifications', () async {
        // Arrange
        const notificationId = 'notif-1';
        final originalNotification = _createNotification('user-123', id: notificationId);
        await _seedNotification(fakeFirestore, notificationId, originalNotification);

        // Act
        final doc = await fakeFirestore.collection('user_notifications').doc(notificationId).get();
        final retrievedNotification = UserNotification.fromFirestore(doc.data()!, doc.id);

        // Assert
        expect(retrievedNotification.id, equals(originalNotification.id));
        expect(retrievedNotification.userId, equals(originalNotification.userId));
        expect(retrievedNotification.type, equals(originalNotification.type));
        expect(retrievedNotification.title, equals(originalNotification.title));
        expect(retrievedNotification.body, equals(originalNotification.body));
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test notification
UserNotification _createNotification(
  String userId, {
  String? id,
  bool isRead = false,
  DateTime? createdAt,
}) {
  return UserNotification(
    id: id ?? 'notif-${DateTime.now().millisecondsSinceEpoch}',
    userId: userId,
    type: NotificationType.immediate,
    title: 'Test Notification',
    body: 'This is a test notification',
    data: {'testKey': 'testValue'},
    isRead: isRead,
    createdAt: createdAt ?? DateTime.now(),
  );
}

/// Seed notification into fake Firestore
Future<void> _seedNotification(
  FakeFirebaseFirestore firestore,
  String notificationId,
  UserNotification notification,
) async {
  final data = {
    'userId': notification.userId,
    'type': notification.type.toString(),
    'title': notification.title,
    'body': notification.body,
    'data': notification.data,
    'isRead': notification.isRead,
    'createdAt': Timestamp.fromDate(notification.createdAt),
    'readAt': notification.readAt != null ? Timestamp.fromDate(notification.readAt!) : null,
  };

  await firestore.collection('user_notifications').doc(notificationId).set(data);
}
