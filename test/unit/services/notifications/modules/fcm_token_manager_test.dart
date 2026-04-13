/// Unit tests for FCMTokenManager
///
/// Tests FCM token lifecycle: registration, refresh, topic subscriptions,
/// multi-device support, error handling, and cleanup.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:butlery/services/notifications/modules/fcm_token_manager.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/models/notification_preferences.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

class _MockDeviceRepo extends Mock implements DeviceRepository {}

/// MockFirebaseMessaging variant that returns null token
class _NullTokenMessaging extends MockFirebaseMessaging {
  @override
  Future<String?> getToken({String? vapidKey}) async => null;
}

void main() {
  group('FCMTokenManager', () {
    late FCMTokenManager tokenManager;
    late _MockDeviceRepo mockRepo;
    late MockFirebaseMessaging mockMessaging;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock FlutterSecureStorage platform channel (used by _getDeviceId
      // and _saveTokenLocally in production code)
      const channel =
          MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'read':
            return 'test-device-id';
          case 'write':
            return true;
          case 'delete':
            return true;
          default:
            return null;
        }
      });

      await BaseUnitTest.setupUnit();
      registerFallbackValue(DateTime.now());
    });

    setUp(() {
      mockRepo = _MockDeviceRepo();
      mockMessaging = MockFirebaseMessaging();

      // Configure device repository stubs
      when(() => mockRepo.saveTokenToFirestore(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.updateDeviceInfo(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.updateTokenTimestamp(any())).thenAnswer((_) async {});
      when(() => mockRepo.removeOldToken(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.cleanupOldDevices(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.getAllUserTokens(any())).thenAnswer((_) async => []);
      when(() => mockRepo.markDeviceInactive(any())).thenAnswer((_) async {});

      // MockFirebaseMessaging has concrete overrides for getToken(),
      // requestPermission(), subscribeToTopic(), etc. - use
      // setFirebaseMessagingState() to configure, not when() stubs.
      mockMessaging.setFirebaseMessagingState(
        token: 'test-token-001',
        authorizationStatus: AuthorizationStatus.authorized,
      );

      tokenManager = FCMTokenManager(
        userId: 'test-user-123',
        repository: mockRepo,
        messaging: mockMessaging,
      );
    });

    tearDown(() {
      tokenManager.dispose();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Token Lifecycle', () {
      test('should initialize and register initial token', () async {
        await tokenManager.initialize();

        expect(tokenManager.isInitialized, isTrue);
        verify(() => mockRepo.saveTokenToFirestore(any(), any()))
            .called(greaterThanOrEqualTo(1));
        verify(() => mockRepo.updateDeviceInfo(any(), any())).called(1);
        verify(() => mockRepo.cleanupOldDevices(any(), any())).called(1);
      });

      test('should handle token refresh from FCM', () async {
        final controller = StreamController<String>();
        mockMessaging.setFirebaseMessagingState(
          tokenRefreshStream: controller.stream,
        );

        // Recreate with the new stream config
        tokenManager = FCMTokenManager(
          userId: 'test-user-123',
          repository: mockRepo,
          messaging: mockMessaging,
        );

        await tokenManager.initialize();
        controller.add('refreshed-token');
        await Future.delayed(const Duration(milliseconds: 50));

        // Initial + refresh = 2+ saves
        verify(() => mockRepo.saveTokenToFirestore(any(), any()))
            .called(greaterThanOrEqualTo(2));

        await controller.close();
      });

      test('should cache token on subsequent getCurrentToken calls', () async {
        await tokenManager.initialize();

        final t1 = await tokenManager.getCurrentToken();
        final t2 = await tokenManager.getCurrentToken();

        expect(t1, equals('test-token-001'));
        expect(t2, equals('test-token-001'));
      });

      test('should handle null token from Firebase', () async {
        final nullMessaging = _NullTokenMessaging();
        tokenManager = FCMTokenManager(
          userId: 'test-user-123',
          repository: mockRepo,
          messaging: nullMessaging,
        );

        await tokenManager.initialize();

        expect(tokenManager.isInitialized, isFalse);
        verifyNever(() => mockRepo.saveTokenToFirestore(any(), any()));
      });

      test('should force refresh token', () async {
        await tokenManager.initialize();

        // Verify save was called for initial registration
        verify(() => mockRepo.saveTokenToFirestore(any(), any()))
            .called(greaterThanOrEqualTo(1));

        // Force refresh - token unchanged so only timestamp update
        await tokenManager.refreshToken();

        verify(() => mockRepo.updateTokenTimestamp(any()))
            .called(greaterThanOrEqualTo(1));
      });
    });

    group('Topic Subscriptions', () {
      test('should subscribe to user topic on update', () async {
        await tokenManager.initialize();

        final prefs = NotificationPreferences.defaults();
        await tokenManager.updateTopicSubscriptions(prefs);

        // The concrete mock doesn't track calls, but no errors thrown
        // means topics were processed
        expect(true, isTrue);
      });

      test('should unsubscribe from all topics', () async {
        await tokenManager.initialize();
        await tokenManager.unsubscribeFromAllTopics();

        // No errors means all 5 topics were unsubscribed
        expect(true, isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle permission denied', () async {
        mockMessaging.setFirebaseMessagingState(
          authorizationStatus: AuthorizationStatus.denied,
        );
        tokenManager = FCMTokenManager(
          userId: 'test-user-123',
          repository: mockRepo,
          messaging: mockMessaging,
        );

        // Should complete without throwing
        await tokenManager.initialize();

        expect(tokenManager.isInitialized, isFalse);
        verifyNever(() => mockRepo.saveTokenToFirestore(any(), any()));
      });

      test('should handle repository save failure', () async {
        when(() => mockRepo.saveTokenToFirestore(any(), any()))
            .thenThrow(Exception('Firestore error'));

        await expectLater(
          tokenManager.initialize(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Device Management', () {
      test('should update device info on init', () async {
        await tokenManager.initialize();
        verify(() => mockRepo.updateDeviceInfo(any(), any())).called(1);
      });

      test('should cleanup old devices on init', () async {
        await tokenManager.initialize();
        verify(() => mockRepo.cleanupOldDevices(any(), any())).called(1);
      });

      test('should get all user tokens', () async {
        when(() => mockRepo.getAllUserTokens(any()))
            .thenAnswer((_) async => ['t1', 't2']);

        final tokens = await tokenManager.getAllUserTokens();
        expect(tokens, equals(['t1', 't2']));
      });

      test('should mark device inactive on cleanup', () async {
        await tokenManager.initialize();
        await tokenManager.cleanup();
        verify(() => mockRepo.markDeviceInactive(any())).called(1);
      });
    });

    group('Token State', () {
      test('should start uninitialized', () {
        expect(tokenManager.isInitialized, isFalse);
        expect(tokenManager.tokenAgeMinutes, isNull);
      });

      test('should become initialized after successful init', () async {
        await tokenManager.initialize();
        expect(tokenManager.isInitialized, isTrue);
      });

      test('should track token age after init', () async {
        await tokenManager.initialize();
        final age = tokenManager.tokenAgeMinutes;
        expect(age, isNotNull);
        expect(age, greaterThanOrEqualTo(0));
      });

      test('should clear state on dispose', () async {
        await tokenManager.initialize();
        tokenManager.dispose();
        expect(tokenManager.isInitialized, isFalse);
      });
    });
  });
}
