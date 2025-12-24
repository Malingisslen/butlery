/// Unit tests for FCMTokenManager
///
/// Tests FCM token lifecycle management including registration, refresh,
/// multi-device support, topic subscriptions, and error handling.
/// Tests against the REAL FCMTokenManager production code with mocked dependencies.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

// Production code being tested
import 'package:butlery/services/notifications/modules/fcm_token_manager.dart';
import 'package:butlery/services/notifications/notification_repository.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/notification_preferences.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

// Mock for the concrete NotificationRepository class (FCM token operations)
class MockNotificationRepositoryForFCM extends Mock
    implements NotificationRepository {}

void main() {
  setUpAll(() {
    // Centralized fallback values already registered via TestServiceLocator
  });

  group('FCMTokenManager', () {
    late FCMTokenManager tokenManager;
    late NotificationRepository mockRepository;
    late MockFirebaseMessaging mockMessaging;
    late MockSharedPreferences mockPreferences;
    late MockFirebaseFirestore mockFirestore;

    setUp(() async {
      // Initialize test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Initialize mocks using centralized infrastructure
      mockRepository = MockNotificationRepositoryForFCM();
      mockMessaging = MockFirebaseMessaging();
      mockPreferences = MockSharedPreferences();
      mockFirestore = MockFirebaseFirestore();

      // Register mocks in GetIt for dependency injection
      GetIt.instance.registerSingleton<NotificationRepository>(mockRepository);
      GetIt.instance.registerSingleton<FirebaseFirestore>(mockFirestore);

      // Configure default mock behavior for NotificationRepository
      when(() => mockRepository.getPreferences())
          .thenAnswer((_) async => NotificationPreferences.defaults());

      when(() => mockRepository.saveTokenToFirestore(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.updateDeviceInfo(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.updateTokenTimestamp(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.removeOldToken(any(), any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.cleanupOldDevices(any(), any(),
          olderThan: any(named: 'olderThan'))).thenAnswer((_) async {});

      when(() => mockRepository.getAllUserTokens(any(), any()))
          .thenAnswer((_) async => []);

      when(() => mockRepository.markDeviceInactive(any(), any()))
          .thenAnswer((_) async {});

      // Configure Firebase Messaging mock
      final mockSettings = MockNotificationSettings();
      mockSettings.setAuthorizationStatus(AuthorizationStatus.authorized);

      when(() => mockMessaging.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            carPlay: any(named: 'carPlay'),
            criticalAlert: any(named: 'criticalAlert'),
            provisional: any(named: 'provisional'),
          )).thenAnswer((_) async => mockSettings);

      when(() => mockMessaging.getToken())
          .thenAnswer((_) async => 'test-fcm-token-001');

      // Use empty stream initially to avoid immediate token refresh
      when(() => mockMessaging.onTokenRefresh)
          .thenAnswer((_) => Stream.empty());

      when(() => mockMessaging.subscribeToTopic(any()))
          .thenAnswer((_) async {});
      when(() => mockMessaging.unsubscribeFromTopic(any()))
          .thenAnswer((_) async {});

      // Configure SharedPreferences mock
      when(() => mockPreferences.getString(any())).thenReturn(null);
      when(() => mockPreferences.setString(any(), any()))
          .thenAnswer((_) async => true);
      when(() => mockPreferences.remove(any())).thenAnswer((_) async => true);

      // Create the REAL FCMTokenManager with mocked dependencies
      tokenManager = FCMTokenManager(
        userId: 'test-user-123',
        repository: mockRepository,
        messaging: mockMessaging, // Now injecting the mock
      );
    });

    tearDown(() async {
      // Clean up
      tokenManager.dispose();
      GetIt.instance.reset();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    group('Token Lifecycle', () {
      test('should initialize and register initial token', () async {
        // Act
        await tokenManager.initialize();

        // Assert
        expect(tokenManager.isInitialized, isTrue);
        verify(() => mockMessaging.requestPermission(
              alert: true,
              badge: true,
              sound: true,
              carPlay: false,
              criticalAlert: false,
              provisional: false,
            )).called(1);
        verify(() => mockMessaging.getToken()).called(1);
        verify(() => mockRepository.saveTokenToFirestore(any(), any(), any()))
            .called(greaterThanOrEqualTo(1));
      });

      test('should handle token refresh from FCM', () async {
        // Arrange
        final refreshController = StreamController<String>();
        when(() => mockMessaging.onTokenRefresh)
            .thenAnswer((_) => refreshController.stream);

        // Act
        await tokenManager.initialize();
        refreshController.add('new-refreshed-token');
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        verify(() => mockRepository.saveTokenToFirestore(any(), any(), any()))
            .called(greaterThanOrEqualTo(2));

        // Cleanup
        await refreshController.close();
      });

      test('should get current token with caching', () async {
        // Arrange
        await tokenManager.initialize();

        // Act
        final token1 = await tokenManager.getCurrentToken();
        final token2 = await tokenManager.getCurrentToken();

        // Assert
        expect(token1, equals(token2));
        expect(token1, equals('test-fcm-token-001'));
        // Should use cached token on second call
        verify(() => mockMessaging.getToken()).called(1);
      });

      test('should force refresh token when requested', () async {
        // Arrange
        await tokenManager.initialize();
        when(() => mockMessaging.getToken())
            .thenAnswer((_) async => 'new-token-456');

        // Act
        await tokenManager.refreshToken();

        // Assert
        verify(() => mockMessaging.getToken())
            .called(2); // Once in init, once in refresh
        verify(() => mockRepository.saveTokenToFirestore(any(), any(), any()))
            .called(greaterThanOrEqualTo(2));
      });

      test('should cleanup on logout', () async {
        // Arrange
        await tokenManager.initialize();

        // Act
        await tokenManager.cleanup();

        // Assert
        verify(() => mockMessaging.unsubscribeFromTopic('user_test-user-123'))
            .called(1);
        verify(() => mockRepository.markDeviceInactive(any(), any())).called(1);
      });

      test('should handle null token from Firebase', () async {
        // Arrange
        when(() => mockMessaging.getToken()).thenAnswer((_) async => null);

        // Act
        await tokenManager.initialize();

        // Assert
        expect(tokenManager.isInitialized, isFalse);
        verifyNever(
            () => mockRepository.saveTokenToFirestore(any(), any(), any()));
      });
    });

    group('Topic Subscriptions', () {
      test('should subscribe to user topic when updating preferences',
          () async {
        // Arrange - initialize first
        await tokenManager.initialize();

        final preferences = NotificationPreferences.defaults();

        // Act - updateTopicSubscriptions is where topic subscription happens
        await tokenManager.updateTopicSubscriptions(preferences);

        // Assert
        verify(() => mockMessaging.subscribeToTopic('user_test-user-123'))
            .called(1);
      });

      test('should update topic subscriptions based on preferences', () async {
        // Arrange
        await tokenManager.initialize();

        final preferences = NotificationPreferences(
          enabled: true,
          categorySettings: {
            NotificationCategory.system: true,
            NotificationCategory.social: true,
            NotificationCategory.recipes: true,
            NotificationCategory.friends: true,
          },
          typeSettings: {
            NotificationType.digest: true,
          },
          allowBatching: true,
          digestFrequency: 'daily',
          soundEnabled: true,
          vibrationEnabled: true,
          lastUpdated: DateTime.now(),
        );

        // Act
        await tokenManager.updateTopicSubscriptions(preferences);

        // Assert
        verify(() => mockMessaging.subscribeToTopic('system_updates'))
            .called(1);
        verify(() => mockMessaging.subscribeToTopic('social_digest')).called(1);
        verify(() => mockMessaging.subscribeToTopic('recipe_recommendations'))
            .called(1);
        verify(() => mockMessaging.subscribeToTopic('friend_activity'))
            .called(1);
      });

      test('should unsubscribe from topics when preferences disabled',
          () async {
        // Arrange
        await tokenManager.initialize();

        final preferences = NotificationPreferences(
          enabled: true,
          categorySettings: {
            NotificationCategory.system: false,
            NotificationCategory.social: false,
            NotificationCategory.recipes: false,
            NotificationCategory.friends: false,
          },
          typeSettings: {
            NotificationType.digest: false,
          },
          allowBatching: true,
          digestFrequency: 'never',
          soundEnabled: true,
          vibrationEnabled: true,
          lastUpdated: DateTime.now(),
        );

        // Act
        await tokenManager.updateTopicSubscriptions(preferences);

        // Assert
        verify(() => mockMessaging.unsubscribeFromTopic('system_updates'))
            .called(1);
        verify(() => mockMessaging.unsubscribeFromTopic('social_digest'))
            .called(1);
        verify(() =>
                mockMessaging.unsubscribeFromTopic('recipe_recommendations'))
            .called(1);
        verify(() => mockMessaging.unsubscribeFromTopic('friend_activity'))
            .called(1);
      });

      test('should unsubscribe from all topics on cleanup', () async {
        // Arrange
        await tokenManager.initialize();

        // Act
        await tokenManager.unsubscribeFromAllTopics();

        // Assert
        verify(() => mockMessaging.unsubscribeFromTopic('user_test-user-123'))
            .called(1);
        verify(() => mockMessaging.unsubscribeFromTopic('system_updates'))
            .called(1);
        verify(() => mockMessaging.unsubscribeFromTopic('social_digest'))
            .called(1);
        verify(() =>
                mockMessaging.unsubscribeFromTopic('recipe_recommendations'))
            .called(1);
        verify(() => mockMessaging.unsubscribeFromTopic('friend_activity'))
            .called(1);
      });
    });

    group('Error Handling', () {
      test('should handle permission denied gracefully', () async {
        // Arrange
        final mockSettings = MockNotificationSettings();
        mockSettings.setAuthorizationStatus(AuthorizationStatus.denied);
        when(() => mockMessaging.requestPermission(
              alert: any(named: 'alert'),
              badge: any(named: 'badge'),
              sound: any(named: 'sound'),
              carPlay: any(named: 'carPlay'),
              criticalAlert: any(named: 'criticalAlert'),
              provisional: any(named: 'provisional'),
            )).thenAnswer((_) async => mockSettings);

        // Act & Assert - Should not throw
        await expectLater(
          tokenManager.initialize(),
          completes,
        );

        // Should not try to get token if permission denied
        verifyNever(() => mockMessaging.getToken());
      });

      test('should handle token fetch failure', () async {
        // Arrange
        when(() => mockMessaging.getToken())
            .thenAnswer((_) async => throw Exception('Network error'));

        // Act & Assert - Should not throw
        await expectLater(
          tokenManager.initialize(),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle topic subscription failure gracefully', () async {
        // Arrange
        await tokenManager.initialize();
        when(() => mockMessaging.subscribeToTopic(any())).thenAnswer(
            (_) async => throw Exception('Topic subscription failed'));

        final preferences = NotificationPreferences.defaults();

        // Act & Assert - Should not throw
        await expectLater(
          tokenManager.updateTopicSubscriptions(preferences),
          completes,
        );
      });

      test('should handle repository save failures gracefully', () async {
        // Arrange
        when(() => mockRepository.saveTokenToFirestore(any(), any(), any()))
            .thenAnswer((_) async => throw Exception('Firestore error'));

        // Act & Assert
        await expectLater(
          tokenManager.initialize(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Device Management', () {
      test('should update device info on token registration', () async {
        // Act
        await tokenManager.initialize();

        // Assert
        verify(() => mockRepository.updateDeviceInfo(any(), any(), any()))
            .called(1);
      });

      test('should cleanup old devices on initialization', () async {
        // Act
        await tokenManager.initialize();

        // Assert
        verify(() => mockRepository.cleanupOldDevices(
              any(),
              'test-user-123',
              olderThan: const Duration(days: 30),
            )).called(1);
      });

      test('should mark device as inactive on cleanup', () async {
        // Arrange
        await tokenManager.initialize();

        // Act
        await tokenManager.cleanup();

        // Assert
        verify(() => mockRepository.markDeviceInactive(any(), any())).called(1);
      });

      test('should get all user tokens', () async {
        // Arrange
        when(() => mockRepository.getAllUserTokens(any(), any()))
            .thenAnswer((_) async => ['token1', 'token2', 'token3']);

        // Act
        final tokens = await tokenManager.getAllUserTokens();

        // Assert
        expect(tokens, hasLength(3));
        expect(tokens, contains('token1'));
        expect(tokens, contains('token2'));
        expect(tokens, contains('token3'));
      });
    });

    group('Token State', () {
      test('should track initialization state', () {
        // Assert
        expect(tokenManager.isInitialized, isFalse);
      });

      test('should become initialized after successful init', () async {
        // Act
        await tokenManager.initialize();

        // Assert
        expect(tokenManager.isInitialized, isTrue);
      });

      test('should track token age', () async {
        // Act
        await tokenManager.initialize();
        await Future.delayed(const Duration(seconds: 1));

        // Assert
        final age = tokenManager.tokenAgeMinutes;
        expect(age, isNotNull);
        expect(age, greaterThanOrEqualTo(0));
      });

      test('should dispose properly', () async {
        // Arrange
        await tokenManager.initialize();

        // Act
        tokenManager.dispose();

        // Assert
        expect(tokenManager.isInitialized, isFalse);
      });
    });
  });
}
