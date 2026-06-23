/// Unit tests for services using NotificationsRepository
///
/// Tests business logic using mocked repository, avoiding Firebase implementation details.
/// For Firebase-specific tests, see integration tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('NotificationsRepository Mock Tests', () {
    late MockNotificationsRepository mockRepository;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mock repository with configuration
      mockRepository = MockFactory.createNotificationsRepository(
        currentUserId: 'test_user_123',
        notifications: [],
        unreadCount: 0,
      );

      // Register the mock in service locator
      TestServiceLocator.registerMock(mockRepository);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Send Notifications', () {
      test('should send single notification to user', () async {
        // Arrange
        const userId = 'target_user';
        const type = NotificationType.immediate;
        const title = 'New Friend Request';
        const body = 'John wants to be your friend!';
        final data = {'senderId': 'john_123'};

        // Stub the repository method
        when(
          () => mockRepository.sendNotification(
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: data,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.sendNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        verify(
          () => mockRepository.sendNotification(
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: data,
          ),
        ).called(1);
      });

      test('should send bulk notifications to multiple users', () async {
        // Arrange
        final userIds = ['user_1', 'user_2', 'user_3'];
        const type = NotificationType.batchable;
        const title = 'New Recipe Shared';
        const body = 'Check out this amazing recipe!';
        final data = {'recipeId': 'recipe_456'};

        // Stub the repository method
        when(
          () => mockRepository.sendBulkNotifications(
            userIds: userIds,
            type: type,
            title: title,
            body: body,
            data: data,
          ),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.sendBulkNotifications(
          userIds: userIds,
          type: type,
          title: title,
          body: body,
          data: data,
        );

        // Assert
        verify(
          () => mockRepository.sendBulkNotifications(
            userIds: userIds,
            type: type,
            title: title,
            body: body,
            data: data,
          ),
        ).called(1);
      });
    });

    group('Get Notifications', () {
      test('should retrieve user notifications with default limit', () async {
        // Arrange
        const userId = 'test_user';
        final notifications = [
          UserNotification(
            id: 'notif_1',
            userId: userId,
            type: NotificationType.optional,
            title: 'Notification 1',
            body: 'Body 1',
            isRead: false,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          ),
          UserNotification(
            id: 'notif_2',
            userId: userId,
            type: NotificationType.immediate,
            title: 'Notification 2',
            body: 'Body 2',
            isRead: true,
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getUserNotifications(userId),
        ).thenAnswer((_) async => notifications);

        // Act
        final result = await mockRepository.getUserNotifications(userId);

        // Assert
        expect(result.length, equals(2));
        expect(result.first.title, equals('Notification 1'));
        expect(result[1].isRead, isTrue);

        // Verify the method was called
        verify(() => mockRepository.getUserNotifications(userId)).called(1);
      });

      test('should retrieve notifications since specific date', () async {
        // Arrange
        const userId = 'test_user';
        final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

        final recentNotifications = [
          UserNotification(
            id: 'recent_1',
            userId: userId,
            type: NotificationType.optional,
            title: 'Recent Notification',
            body: 'Recent Body',
            isRead: false,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getUserNotifications(userId, since: cutoffDate),
        ).thenAnswer((_) async => recentNotifications);

        // Act
        final result = await mockRepository.getUserNotifications(
          userId,
          since: cutoffDate,
        );

        // Assert
        expect(result.length, equals(1));
        expect(result.first.title, equals('Recent Notification'));
        expect(result.first.createdAt.isAfter(cutoffDate), isTrue);

        // Verify the method was called with correct parameters
        verify(
          () => mockRepository.getUserNotifications(userId, since: cutoffDate),
        ).called(1);
      });

      test('should stream user notifications', () async {
        // Arrange
        const userId = 'test_user';
        final notifications = [
          UserNotification(
            id: 'stream_1',
            userId: userId,
            type: NotificationType.optional,
            title: 'Streamed Notification',
            body: 'Streamed Body',
            isRead: false,
            createdAt: DateTime.now(),
          ),
        ];

        // Stub the repository method
        when(
          () => mockRepository.getNotificationsStream(userId),
        ).thenAnswer((_) => Stream.value(notifications));

        // Act
        final stream = mockRepository.getNotificationsStream(userId);
        final result = await stream.first;

        // Assert
        expect(result.length, equals(1));
        expect(result.first.title, equals('Streamed Notification'));

        // Verify the method was called
        verify(() => mockRepository.getNotificationsStream(userId)).called(1);
      });
    });

    group('Mark As Read', () {
      test('should mark single notification as read', () async {
        // Arrange
        const notificationId = 'notif_123';

        // Stub the repository method
        when(
          () => mockRepository.markAsRead(notificationId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.markAsRead(notificationId);

        // Assert
        verify(() => mockRepository.markAsRead(notificationId)).called(1);
      });

      test('should mark multiple notifications as read', () async {
        // Arrange
        final notificationIds = ['notif_1', 'notif_2', 'notif_3'];

        // Stub the repository method
        when(
          () => mockRepository.markMultipleAsRead(notificationIds),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.markMultipleAsRead(notificationIds);

        // Assert
        verify(
          () => mockRepository.markMultipleAsRead(notificationIds),
        ).called(1);
      });

      test('should mark all user notifications as read', () async {
        // Arrange
        const userId = 'test_user_123';

        // Stub the repository method
        when(
          () => mockRepository.markAllAsRead(userId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.markAllAsRead(userId);

        // Assert
        verify(() => mockRepository.markAllAsRead(userId)).called(1);
      });
    });

    group('Notification Management', () {
      test('should delete notification', () async {
        // Arrange
        const notificationId = 'notif_to_delete';

        // Stub the repository method
        when(
          () => mockRepository.deleteNotification(notificationId),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.deleteNotification(notificationId);

        // Assert
        verify(
          () => mockRepository.deleteNotification(notificationId),
        ).called(1);
      });

      test('should get unread notification count', () async {
        // Arrange
        const userId = 'test_user';
        const unreadCount = 5;

        // Stub the repository method
        when(
          () => mockRepository.getUnreadCount(userId),
        ).thenAnswer((_) async => unreadCount);

        // Act
        final count = await mockRepository.getUnreadCount(userId);

        // Assert
        expect(count, equals(5));
        verify(() => mockRepository.getUnreadCount(userId)).called(1);
      });
    });

    group('Notification Preferences', () {
      test('should update notification preferences', () async {
        // Arrange
        const userId = 'test_user';
        final preferences = NotificationPreferences.defaults();

        // Stub the repository method
        when(
          () =>
              mockRepository.updateNotificationPreferences(userId, preferences),
        ).thenAnswer((_) async {});

        // Act
        await mockRepository.updateNotificationPreferences(userId, preferences);

        // Assert
        verify(
          () =>
              mockRepository.updateNotificationPreferences(userId, preferences),
        ).called(1);
      });

      test('should get notification preferences', () async {
        // Arrange
        const userId = 'test_user';
        final preferences = NotificationPreferences.defaults();

        // Stub the repository method
        when(
          () => mockRepository.getNotificationPreferences(userId),
        ).thenAnswer((_) async => preferences);

        // Act
        final result = await mockRepository.getNotificationPreferences(userId);

        // Assert - verify model uses categorySettings map
        expect(result.categorySettings[NotificationCategory.recipes], isTrue);
        expect(result.categorySettings[NotificationCategory.friends], isTrue);
        verify(
          () => mockRepository.getNotificationPreferences(userId),
        ).called(1);
      });
    });
  });
}
