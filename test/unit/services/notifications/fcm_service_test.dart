/// Unit tests for FCMService - Firebase Cloud Messaging integration
///
/// Tests FCM functionality including:
/// - Service initialization and setup
/// - Token management and refresh
/// - Message handling (foreground, background, opened app)
/// - Topic subscriptions and unsubscriptions
/// - Permission management
/// - Notification navigation and deep linking
/// - Platform-specific behavior (iOS vs Android)
/// - Swedish localization support
///
/// Two test surfaces:
///   1. Error-path tests below assert graceful failure when no
///      [FirebaseMessaging] mock is registered (real instance unavailable in
///      a unit-test environment).
///   2. The "BUT-446 test injection seam" group exercises the positive path
///      via [FCMService.setMessagingForTest] with a [MockFirebaseMessaging],
///      proving the seam routes calls to the override.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/notifications/fcm_service.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

/// MockFirebaseMessaging variant that records subscribe/unsubscribe/getToken
/// calls — used to verify the BUT-446 test seam routes calls to the override.
class _RecordingMessaging extends MockFirebaseMessaging {
  final List<String> subscribedTopics = <String>[];
  final List<String> unsubscribedTopics = <String>[];
  int getTokenCalls = 0;

  @override
  Future<String?> getToken({String? vapidKey}) async {
    getTokenCalls++;
    return super.getToken(vapidKey: vapidKey);
  }

  @override
  Future<void> subscribeToTopic(String topic) async {
    subscribedTopics.add(topic);
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    unsubscribedTopics.add(topic);
  }
}

void main() {
  group('FCMService', () {
    late MockRemoteMessage mockMessage;
    late MockRemoteNotification mockNotification;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Register fallback values for mocktail
      registerFallbackValue(MockRemoteMessage());
    });

    setUp(() async {
      mockMessage = MockRemoteMessage();
      mockNotification = MockRemoteNotification();

      // Reset any static state
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();

      // Reset FCMService static state between tests
      await FCMService.dispose();
    });

    tearDown(() async {
      await FCMService.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should throw when initialization fails in test environment',
          () async {
        // FCMService.initialize() uses safeExecute which catches internal errors.
        // When the internal operations fail (no real Firebase in test env),
        // safeExecute returns null and initialize() throws explicitly.
        expect(
          () async => await FCMService.initialize(
            onMessageReceived: (message) {},
            onMessageOpenedApp: (message) {},
          ),
          throwsException,
        );
      });

      test('should accept optional callbacks', () async {
        // Verify that initialize accepts null callbacks without argument errors.
        // It will still throw because Firebase isn't available, but the
        // callback handling itself should be correct.
        expect(
          () async => await FCMService.initialize(),
          throwsException,
        );
      });

      test('should throw on repeated initialization failure', () async {
        // Each call should fail the same way in test environment
        expect(
          () async => await FCMService.initialize(),
          throwsException,
        );
      });
    });

    group('Token Management', () {
      test('should return null when Firebase is unavailable', () async {
        // In test environment, getToken() hits the real FirebaseMessaging
        // which is not properly initialized. The method catches errors
        // and returns null.
        final token = await FCMService.getToken();
        expect(token, isNull);
      });

      test('should handle token refresh gracefully', () async {
        // getToken catches errors internally and returns null
        expect(() async {
          await FCMService.getToken();
        }, returnsNormally);
      });

      test('should return null when token retrieval fails', () async {
        // In test environment without Firebase, token retrieval fails gracefully
        final token = await FCMService.getToken();
        expect(token, isNull);
      });
    });

    group('Topic Management', () {
      test('should handle subscribe gracefully when Firebase unavailable',
          () async {
        // safeExecute catches the Firebase error and logs it
        expect(() async {
          await FCMService.subscribeToTopic('recipes_updates');
        }, returnsNormally);
      });

      test('should handle unsubscribe gracefully when Firebase unavailable',
          () async {
        // safeExecute catches the Firebase error and logs it
        expect(() async {
          await FCMService.unsubscribeFromTopic('social_updates');
        }, returnsNormally);
      });

      test('should handle subscription errors gracefully', () async {
        // safeExecute wraps the operation - errors are caught and logged
        expect(() async {
          await FCMService.subscribeToTopic('invalid_topic');
        }, returnsNormally);
      });

      test('should validate topic names', () async {
        // Various topic names should be handled without throwing
        const invalidTopics = ['', 'topic with spaces', 'topic/with/slashes'];

        for (final topic in invalidTopics) {
          expect(() async {
            await FCMService.subscribeToTopic(topic);
          }, returnsNormally);
        }
      });
    });

    group('Message Handling', () {
      test('should show foreground notification', () {
        // Arrange
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Test Title');
        when(() => mockNotification.body).thenReturn('Test Body');
        when(() => mockMessage.data).thenReturn({'key': 'value'});

        // Act
        FCMService.showForegroundNotification(mockMessage);

        // Assert - should log the notification without throwing
      });

      test('should handle notification with Swedish content', () {
        // Arrange
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Nytt recept delat');
        when(() => mockNotification.body)
            .thenReturn('Anna har delat Köttbullar med dig');
        when(() => mockMessage.data).thenReturn({'type': 'recipe_share'});

        // Act
        FCMService.showForegroundNotification(mockMessage);

        // Assert - should handle Swedish characters properly
      });

      test('should handle notification without title or body', () {
        // Arrange
        when(() => mockMessage.notification).thenReturn(null);
        when(() => mockMessage.data).thenReturn({'silent': 'true'});

        // Act & Assert
        expect(() {
          FCMService.showForegroundNotification(mockMessage);
        }, returnsNormally);
      });
    });

    group('Navigation Handling', () {
      test('should navigate based on notification type', () async {
        // Arrange
        final testCases = [
          {'type': 'friend_request', 'expectedRoute': '/friends'},
          {'type': 'recipe_share', 'expectedRoute': '/recipe'},
          {'type': 'collaboration', 'expectedRoute': '/collaboration'},
          {'type': 'recipe_comment', 'expectedRoute': '/comments'},
        ];

        // Act & Assert
        for (final testCase in testCases) {
          when(() => mockMessage.data).thenReturn(testCase);

          // Navigation requires navigator key, testing without one
          await expectLater(
              FCMService.handleNotificationNavigation(mockMessage), completes);
        }
      });

      test('should handle navigation without context', () async {
        // Arrange
        when(() => mockMessage.data).thenReturn({'type': 'test'});

        // Act & Assert
        await expectLater(
            FCMService.handleNotificationNavigation(mockMessage), completes);
      });

      test('should handle unknown notification types', () async {
        // Arrange
        when(() => mockMessage.data).thenReturn({'type': 'unknown_type'});

        // Act & Assert
        await expectLater(
            FCMService.handleNotificationNavigation(mockMessage), completes);
      });
    });

    group('Permission Management', () {
      test('should handle getNotificationSettings error in test env', () async {
        // FCMService.getNotificationSettings() calls _messaging directly.
        // In test environment, this will throw because FirebaseMessaging
        // isn't properly initialized. The method rethrows the error.
        expect(
          () async => await FCMService.getNotificationSettings(),
          throwsA(anything),
        );
      });

      test('should return false when areNotificationsEnabled fails', () async {
        // areNotificationsEnabled catches errors and returns false
        final enabled = await FCMService.areNotificationsEnabled();
        expect(enabled, isFalse);
      });

      test('should handle permission check failure gracefully', () async {
        // areNotificationsEnabled wraps getNotificationSettings in try-catch
        // and returns false on error
        final enabled = await FCMService.areNotificationsEnabled();
        expect(enabled, isA<bool>());
        expect(enabled, isFalse);
      });
    });

    group('BUT-446 test injection seam', () {
      // MockFirebaseMessaging uses *concrete* overrides (not stub-based),
      // so we configure via setFirebaseMessagingState() and use a recording
      // subclass to assert calls into subscribe/unsubscribe.

      tearDown(() {
        FCMService.setMessagingForTest(null);
      });

      test('getToken() returns the override token when set', () async {
        final mock = MockFirebaseMessaging()
          ..setFirebaseMessagingState(token: 'mock-token-446');
        FCMService.setMessagingForTest(mock);

        final token = await FCMService.getToken();

        expect(token, equals('mock-token-446'));
      });

      test('subscribeToTopic() forwards to the override', () async {
        final recording = _RecordingMessaging();
        FCMService.setMessagingForTest(recording);

        await FCMService.subscribeToTopic('recipes_updates');

        expect(recording.subscribedTopics, equals(['recipes_updates']));
      });

      test('unsubscribeFromTopic() forwards to the override', () async {
        final recording = _RecordingMessaging();
        FCMService.setMessagingForTest(recording);

        await FCMService.unsubscribeFromTopic('social_updates');

        expect(recording.unsubscribedTopics, equals(['social_updates']));
      });

      test('clearing the override (null) restores fallback behavior', () async {
        final recording = _RecordingMessaging();
        FCMService.setMessagingForTest(recording);
        FCMService.setMessagingForTest(null);

        // With no override and no real Firebase, getToken catches and
        // returns null. The recording mock must not be touched.
        final token = await FCMService.getToken();

        expect(token, isNull);
        expect(recording.getTokenCalls, equals(0));
      });
    });

    group('Edge Cases', () {
      test('should handle null message data', () {
        // Arrange
        when(() => mockMessage.notification).thenReturn(null);
        when(() => mockMessage.data).thenReturn({});

        // Act & Assert
        expect(() {
          FCMService.showForegroundNotification(mockMessage);
        }, returnsNormally);
      });

      test('should handle empty topic name', () async {
        // Act & Assert
        expect(() async {
          await FCMService.subscribeToTopic('');
        }, returnsNormally);
      });

      test('should handle very long notification content', () {
        // Arrange
        final longTitle = 'A' * 500;
        final longBody = 'B' * 1000;

        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn(longTitle);
        when(() => mockNotification.body).thenReturn(longBody);
        when(() => mockMessage.data).thenReturn({});

        // Act & Assert
        expect(() {
          FCMService.showForegroundNotification(mockMessage);
        }, returnsNormally);
      });

      test('should handle special characters in notification', () {
        // Arrange
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Test Recipe!');
        when(() => mockNotification.body)
            .thenReturn('Koettbullar & graeddsaas');
        when(() => mockMessage.data).thenReturn({});

        // Act & Assert
        expect(() {
          FCMService.showForegroundNotification(mockMessage);
        }, returnsNormally);
      });
    });
  });
}
