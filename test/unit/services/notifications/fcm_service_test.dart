/// Unit tests for FCMService - Firebase Cloud Messaging integration.
///
/// BUT-782: FCMService is now instance-based with constructor-injected
/// [FirebaseMessaging]. Tests construct `FCMService(messaging: mock)`
/// directly — the legacy `setMessagingForTest` seam is gone.
///
/// Tests cover:
/// - Token management (getToken, refresh)
/// - Topic subscriptions
/// - Permission management
/// - Foreground notification handling (no Firebase calls)
/// - Navigation handling (no Firebase calls)
/// - Edge cases (null data, empty topics, special characters)
///
/// `initialize()` is not directly tested here because it touches the
/// static streams `FirebaseMessaging.onMessage` / `.onMessageOpenedApp` /
/// `.onBackgroundMessage`, which the FCM SDK doesn't expose for mocking.
/// Initialization is exercised indirectly via integration tests of
/// NotificationService.
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/notifications/fcm_service.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

/// MockFirebaseMessaging variant that records subscribe/unsubscribe/getToken
/// calls — used to verify the injected mock receives the production calls.
///
/// Note: [MockFirebaseMessaging] in production_mocks.dart uses concrete
/// `@override` methods, so `when()/thenAnswer()` on it does NOT intercept.
/// Tests that need custom behavior subclass it directly (the pattern in
/// this file).
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

/// Messaging mock whose [getToken] returns null — drives the "SDK returns
/// null" branch of [FCMService.getToken].
class _NullTokenMessaging extends MockFirebaseMessaging {
  @override
  Future<String?> getToken({String? vapidKey}) async => null;
}

/// Messaging mock whose topic-subscribe AND unsubscribe calls throw — drives
/// the safeExecute error-handling branches symmetrically.
class _ThrowingTopicMessaging extends MockFirebaseMessaging {
  @override
  Future<void> subscribeToTopic(String topic) async {
    throw Exception('FCM unavailable');
  }

  @override
  Future<void> unsubscribeFromTopic(String topic) async {
    throw Exception('FCM unavailable');
  }
}

/// Messaging mock whose [getNotificationSettings] throws — drives the
/// catch-and-return-false branch of [FCMService.areNotificationsEnabled].
class _ThrowingSettingsMessaging extends MockFirebaseMessaging {
  @override
  Future<NotificationSettings> getNotificationSettings() async {
    throw Exception('Settings unavailable');
  }
}

void main() {
  group('FCMService', () {
    late MockRemoteMessage mockMessage;
    late MockRemoteNotification mockNotification;
    late MockFirebaseMessaging mockMessaging;
    late FCMService service;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      registerFallbackValue(MockRemoteMessage());
    });

    setUp(() async {
      mockMessage = MockRemoteMessage();
      mockNotification = MockRemoteNotification();
      mockMessaging = MockFirebaseMessaging();

      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();

      service = FCMService(messaging: mockMessaging);
    });

    tearDown(() async {
      await service.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Token Management', () {
      test('should return the injected mock token', () async {
        mockMessaging.setFirebaseMessagingState(token: 'mock-token-001');

        final token = await service.getToken();

        expect(token, equals('mock-token-001'));
      });

      test('should cache the token across repeated calls', () async {
        final recording = _RecordingMessaging()
          ..setFirebaseMessagingState(token: 'cached-token');
        service = FCMService(messaging: recording);

        final first = await service.getToken();
        final second = await service.getToken();

        expect(first, equals('cached-token'));
        expect(second, equals('cached-token'));
        // Cached after first call: only one underlying SDK call.
        expect(recording.getTokenCalls, equals(1));
      });

      test('should return null when SDK returns null', () async {
        service = FCMService(messaging: _NullTokenMessaging());

        final token = await service.getToken();

        expect(token, isNull);
      });
    });

    group('Topic Management', () {
      test('subscribeToTopic forwards to the injected messaging', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        await service.subscribeToTopic('recipes_updates');

        expect(recording.subscribedTopics, equals(['recipes_updates']));
      });

      test('unsubscribeFromTopic forwards to the injected messaging', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        await service.unsubscribeFromTopic('social_updates');

        expect(recording.unsubscribedTopics, equals(['social_updates']));
      });

      test('subscribeToTopic catches errors (proves safeExecute swallowed)',
          () async {
        service = FCMService(messaging: _ThrowingTopicMessaging());

        // safeExecute swallowed the throw. Stronger than 'completes': after
        // the error, a follow-up call must still resolve normally — proving
        // the service didn't enter a broken state.
        await service.subscribeToTopic('invalid_topic');
        await service.subscribeToTopic('another_topic');
      });

      test('unsubscribeFromTopic catches errors (parity with subscribe)',
          () async {
        service = FCMService(messaging: _ThrowingTopicMessaging());

        await service.unsubscribeFromTopic('topic_a');
        await service.unsubscribeFromTopic('topic_b');
      });

      test('should accept various topic names without throwing', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        const topics = ['', 'topic with spaces', 'topic/with/slashes'];
        for (final topic in topics) {
          await expectLater(service.subscribeToTopic(topic), completes);
        }
      });
    });

    group('Message Handling', () {
      test('showForegroundNotification logs without throwing', () {
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Test Title');
        when(() => mockNotification.body).thenReturn('Test Body');
        when(() => mockMessage.data).thenReturn({'key': 'value'});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('handles Swedish notification content', () {
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Nytt recept delat');
        when(() => mockNotification.body)
            .thenReturn('Anna har delat Köttbullar med dig');
        when(() => mockMessage.data).thenReturn({'type': 'recipe_share'});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('handles notification without title or body', () {
        when(() => mockMessage.notification).thenReturn(null);
        when(() => mockMessage.data).thenReturn({'silent': 'true'});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });
    });

    group('Navigation Handling', () {
      test('completes for each notification type without a navigator',
          () async {
        final testCases = [
          {'type': 'friend_request'},
          {'type': 'recipe_share'},
          {'type': 'collaboration'},
          {'type': 'recipe_comment'},
        ];

        for (final testCase in testCases) {
          when(() => mockMessage.data).thenReturn(testCase);

          // No navigator key registered in unit tests → routine bails early.
          await expectLater(
              service.handleNotificationNavigation(mockMessage), completes);
        }
      });

      test('completes for unknown notification types', () async {
        when(() => mockMessage.data).thenReturn({'type': 'unknown_type'});

        await expectLater(
            service.handleNotificationNavigation(mockMessage), completes);
      });
    });

    group('Permission Management', () {
      test('getNotificationSettings reflects the configured authorization',
          () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.denied);

        final result = await service.getNotificationSettings();

        expect(result.authorizationStatus, AuthorizationStatus.denied);
      });

      test('areNotificationsEnabled returns true for authorized status',
          () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.authorized);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isTrue);
      });

      test('areNotificationsEnabled returns true for provisional status',
          () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.provisional);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isTrue);
      });

      test('areNotificationsEnabled returns false for denied status', () async {
        mockMessaging.setFirebaseMessagingState(
            authorizationStatus: AuthorizationStatus.denied);

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isFalse);
      });

      test('areNotificationsEnabled returns false on error', () async {
        service = FCMService(messaging: _ThrowingSettingsMessaging());

        final enabled = await service.areNotificationsEnabled();

        expect(enabled, isFalse);
      });
    });

    group('Lifecycle', () {
      test('dispose is idempotent — second call no-ops cleanly', () async {
        await service.dispose();
        // Second call must not throw, must not double-log catastrophically.
        await service.dispose();
      });
    });

    group('Edge Cases', () {
      test('null notification + empty data still logs cleanly', () {
        when(() => mockMessage.notification).thenReturn(null);
        when(() => mockMessage.data).thenReturn({});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('empty topic name does not throw', () async {
        final recording = _RecordingMessaging();
        service = FCMService(messaging: recording);

        await expectLater(service.subscribeToTopic(''), completes);
        expect(recording.subscribedTopics, equals(['']));
      });

      test('handles very long notification content', () {
        final longTitle = 'A' * 500;
        final longBody = 'B' * 1000;
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn(longTitle);
        when(() => mockNotification.body).thenReturn(longBody);
        when(() => mockMessage.data).thenReturn({});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });

      test('handles special characters in notification', () {
        when(() => mockMessage.notification).thenReturn(mockNotification);
        when(() => mockNotification.title).thenReturn('Test Recipe!');
        when(() => mockNotification.body)
            .thenReturn('Koettbullar & graeddsaas');
        when(() => mockMessage.data).thenReturn({});

        expect(() => service.showForegroundNotification(mockMessage),
            returnsNormally);
      });
    });
  });
}
