/// Integration tests for Firebase Notifications Repository
///
/// Tests Firebase-specific functionality including FieldValue operations,
/// batch writes, and real-time streams using FakeFirebaseFirestore.
@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_notifications_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import '../../../infrastructure/mocks/firestore_singleton.dart';
import '../../../test_support/test_field_values.dart';
import '../../../test_support/test_data_isolator.dart';

void main() {
  group('Firebase Notifications Repository Integration', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FirebaseNotificationsRepository repository;
    late FirebaseAuthRepository authRepository;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    const testUserId = 'test-user-123';
    const testUserEmail = 'test@example.com';
    const testUserDisplayName = 'Test User';

    setUp(() async {
      // Initialize test isolation
      TestDataIsolator.initializeTest(
          'notifications_repository_integration_test');

      // Set up fake Firebase instances
      fakeFirestore = FirestoreSingleton.instance;
      mockUser = MockUser(
        uid: testUserId,
        email: testUserEmail,
        displayName: testUserDisplayName,
      );
      mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: true);

      // Setup auth repository
      authRepository = FirebaseAuthRepository(firebaseAuth: mockAuth);

      // Create repository with fake Firestore
      repository = FirebaseNotificationsRepository(
        firestore: fakeFirestore,
        authRepository: authRepository,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      await mockAuth.signOut();
      await TestDataIsolator.cleanupTest(
          'notifications_repository_integration_test');
    });

    group('Notifications with FieldValue operations', () {
      test('should create notification with server timestamp', () async {
        // Arrange
        const userId = 'target_user';
        const type = NotificationType.immediate;
        const title = 'New Friend Request';
        const body = 'Someone wants to be your friend!';
        final data = {'requestId': 'req_123'};

        // Act
        await repository.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        final notifications = await fakeFirestore
            .collection('user_notifications')
            .where('userId', isEqualTo: userId)
            .get();

        expect(notifications.docs.length, equals(1));
        final notification = notifications.docs.first.data();

        // Verify server timestamp was set
        expect(notification['createdAt'], isA<Timestamp>());
        final timestamp = notification['createdAt'] as Timestamp;
        expect(timestamp.toDate().difference(DateTime.now()).inMinutes.abs(),
            lessThan(1));

        expect(notification['title'], equals(title));
        expect(notification['body'], equals(body));
        expect(notification['isRead'], isFalse);
      });

      test('should mark notification as read with readAt timestamp', () async {
        // Arrange
        const userId = 'test_user';

        // Create notification with server timestamp
        final docRef =
            await fakeFirestore.collection('user_notifications').add({
          'userId': userId,
          'type': NotificationType.optional.toString(),
          'title': 'Test Notification',
          'body': 'Test Body',
          'isRead': false,
          'createdAt': TestFieldValues.serverTimestamp(),
        });

        // Act
        await repository.markAsRead(docRef.id);

        // Assert
        final doc = await docRef.get();
        final data = doc.data()!;

        expect(data['isRead'], isTrue);
        expect(data['readAt'], isA<Timestamp>());

        // Verify readAt is after createdAt
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final readAt = (data['readAt'] as Timestamp).toDate();
        expect(readAt.isAfter(createdAt), isTrue);
      });

      test('should stream notifications with proper timestamp ordering',
          () async {
        // Arrange
        const userId = 'test_user';

        // Create notifications with server timestamps
        for (int i = 0; i < 3; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': false,
            'createdAt': TestFieldValues.serverTimestamp(),
          });

          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Act
        final stream = repository.getNotificationsStream(userId);
        final notifications = await stream.first;

        // Assert
        expect(notifications.length, equals(3));

        // Verify notifications are ordered by createdAt descending (newest first)
        for (int i = 0; i < notifications.length - 1; i++) {
          expect(
            notifications[i].createdAt.isAfter(notifications[i + 1].createdAt),
            isTrue,
          );
        }
      });
    });

    group('Batch Operations', () {
      test('should send bulk notifications using batch write', () async {
        // Arrange
        final userIds = ['user_1', 'user_2', 'user_3', 'user_4', 'user_5'];
        const type = NotificationType.batchable;
        const title = 'New Recipe Shared';
        const body = 'Check out this amazing recipe!';
        final data = {'recipeId': 'recipe_456'};

        // Act
        await repository.sendBulkNotifications(
          userIds: userIds,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        for (final userId in userIds) {
          final notifications = await fakeFirestore
              .collection('user_notifications')
              .where('userId', isEqualTo: userId)
              .get();

          expect(notifications.docs.length, equals(1));
          final notification = notifications.docs.first.data();

          // Verify all notifications have server timestamp
          expect(notification['createdAt'], isA<Timestamp>());
          expect(notification['title'], equals(title));
          expect(notification['body'], equals(body));
          expect(notification['data']['recipeId'], equals('recipe_456'));
        }
      });

      test('should mark multiple notifications as read in batch', () async {
        // Arrange
        const userId = 'test_user';
        final notificationIds = <String>[];

        // Create multiple unread notifications
        for (int i = 0; i < 5; i++) {
          final docRef =
              await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': false,
            'createdAt': TestFieldValues.serverTimestamp(),
          });
          notificationIds.add(docRef.id);
        }

        // Act
        await repository.markMultipleAsRead(notificationIds);

        // Assert
        for (final id in notificationIds) {
          final doc = await fakeFirestore
              .collection('user_notifications')
              .doc(id)
              .get();

          final data = doc.data()!;
          expect(data['isRead'], isTrue);
          expect(data['readAt'], isA<Timestamp>());
        }
      });
    });

    group('Complex Queries with Timestamps', () {
      test('should retrieve notifications since specific date', () async {
        // Arrange
        const userId = 'test_user';
        final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

        // Create old notifications
        for (int i = 10; i < 13; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Old Notification $i',
            'body': 'Old Body $i',
            'isRead': false,
            'createdAt': Timestamp.fromDate(
              cutoffDate.subtract(Duration(days: i)),
            ),
          });
        }

        // Create recent notifications
        for (int i = 1; i <= 3; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Recent Notification $i',
            'body': 'Recent Body $i',
            'isRead': false,
            'createdAt': Timestamp.fromDate(
              cutoffDate.add(Duration(days: i)),
            ),
          });
        }

        // Act
        final notifications = await repository.getUserNotifications(
          userId,
          since: cutoffDate,
        );

        // Assert
        expect(notifications.length, equals(3));
        expect(
          notifications.every((n) => n.createdAt.isAfter(cutoffDate)),
          isTrue,
        );
        expect(
          notifications.every((n) => n.title.startsWith('Recent')),
          isTrue,
        );
      });

      test('should handle unread count with real-time updates', () async {
        // Arrange
        const userId = 'test_user';

        // Create mix of read and unread notifications
        for (int i = 0; i < 10; i++) {
          await fakeFirestore.collection('user_notifications').add({
            'userId': userId,
            'type': NotificationType.optional.toString(),
            'title': 'Notification $i',
            'body': 'Body $i',
            'isRead': i % 3 == 0, // Every third is read
            'createdAt': TestFieldValues.serverTimestamp(),
          });
        }

        // Act
        final unreadCount = await repository.getUnreadCount(userId);

        // Assert
        expect(unreadCount, equals(7)); // 10 total, 3 read, 7 unread

        // Mark all as read
        await repository.markAllAsRead(userId);

        // Verify all are now read
        final newUnreadCount = await repository.getUnreadCount(userId);
        expect(newUnreadCount, equals(0));
      });
    });

    group('Notification Preferences', () {
      test('should save and retrieve notification preferences', () async {
        // Arrange
        const userId = 'test_user';
        final preferences = NotificationPreferences.defaults();

        // Act
        await repository.updateNotificationPreferences(userId, preferences);

        // Assert
        final savedPreferences =
            await repository.getNotificationPreferences(userId);

        expect(savedPreferences.enabled, isTrue);
        expect(savedPreferences.soundEnabled, isFalse);
        expect(savedPreferences.vibrationEnabled, isTrue);
        expect(savedPreferences.allowBatching, isFalse);
        expect(savedPreferences.enabled, isTrue);
        expect(savedPreferences.soundEnabled, isFalse);
        expect(savedPreferences.vibrationEnabled, isTrue);
        expect(savedPreferences.allowBatching, isFalse);
      });
    });
  });
}
