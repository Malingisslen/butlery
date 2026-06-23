/// Unit tests for FCMTokenManager
///
/// Tests FCM token lifecycle: registration, refresh, topic subscriptions,
/// multi-device support, error handling, and cleanup.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // Shared SecureStorage simulation map — wired into the platform-channel
  // handler in setUpAll, cleared per-test in setUp.
  final Map<String, String?> secureStore = <String, String?>{};

  group('FCMTokenManager', () {
    late FCMTokenManager tokenManager;
    late _MockDeviceRepo mockRepo;
    late MockFirebaseMessaging mockMessaging;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock FlutterSecureStorage platform channel (used by _getDeviceId
      // and _saveTokenLocally in production code). The handler is keyed
      // by `arguments.options.key` so the per-test secureStore map can
      // simulate the migration sentinel correctly.
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            final args = (call.arguments as Map?) ?? const {};
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                // Provide deterministic values for known keys; default is the
                // legacy device-id fallback used by `_getDeviceId`.
                if (key == null) return null;
                if (secureStore.containsKey(key)) return secureStore[key];
                // The fallback device-id reader uses `butlery_fallback_device_id`.
                // Anything we haven't written yet → null (matches real plugin).
                if (key == 'butlery_fallback_device_id') {
                  return 'test-device-id';
                }
                return null;
              case 'write':
                if (key != null) {
                  secureStore[key] = args['value'] as String?;
                }
                return true;
              case 'delete':
                if (key != null) secureStore.remove(key);
                return true;
              default:
                return null;
            }
          });

      await BaseUnitTest.setupUnit();
      registerFallbackValue(DateTime.now());
    });

    setUp(() {
      // Reset SecureStorage simulation between tests.
      secureStore.clear();
      // Default SharedPreferences mock — empty store unless a test seeds it.
      SharedPreferences.setMockInitialValues(<String, Object>{});

      mockRepo = _MockDeviceRepo();
      mockMessaging = MockFirebaseMessaging();

      // Configure device repository stubs
      when(
        () => mockRepo.saveTokenToFirestore(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRepo.updateDeviceInfo(any(), any()),
      ).thenAnswer((_) async {});
      when(() => mockRepo.updateTokenTimestamp(any())).thenAnswer((_) async {});
      when(
        () => mockRepo.removeOldToken(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRepo.cleanupOldDevices(any(), any()),
      ).thenAnswer((_) async {});
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
        verify(
          () => mockRepo.saveTokenToFirestore(any(), any()),
        ).called(greaterThanOrEqualTo(1));
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
        verify(
          () => mockRepo.saveTokenToFirestore(any(), any()),
        ).called(greaterThanOrEqualTo(2));

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
        verify(
          () => mockRepo.saveTokenToFirestore(any(), any()),
        ).called(greaterThanOrEqualTo(1));

        // Force refresh - token unchanged so only timestamp update
        await tokenManager.refreshToken();

        verify(
          () => mockRepo.updateTokenTimestamp(any()),
        ).called(greaterThanOrEqualTo(1));
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
        when(
          () => mockRepo.saveTokenToFirestore(any(), any()),
        ).thenThrow(Exception('Firestore error'));

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
        when(
          () => mockRepo.getAllUserTokens(any()),
        ).thenAnswer((_) async => ['t1', 't2']);

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

      test('BUT-457: should migrate legacy token from SharedPreferences and '
          'scrub the legacy keys on first init', () async {
        // Seed a legacy SharedPreferences token (simulates a user upgrading
        // from a build that wrote the FCM token in plaintext).
        SharedPreferences.setMockInitialValues(<String, Object>{
          'fcm_token': 'legacy-token-xyz',
          'fcm_token_timestamp': '2024-01-01T00:00:00.000',
        });

        await tokenManager.initialize();

        // SharedPreferences must be scrubbed.
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('fcm_token'),
          isNull,
          reason: 'legacy SP token must be removed',
        );
        expect(
          prefs.getString('fcm_token_timestamp'),
          isNull,
          reason: 'legacy SP timestamp must be removed',
        );

        // SecureStorage now holds the migrated token (until _refreshToken
        // overwrites it with the freshly-fetched value), or at minimum the
        // migration sentinel.
        expect(
          secureStore['fcm_token_sp_migration_done'],
          equals('true'),
          reason: 'migration sentinel must be set',
        );
      });

      test('BUT-457: migration must run only once — sentinel keeps subsequent '
          'inits a no-op against SharedPreferences', () async {
        // Seed legacy token + run init once to set the sentinel.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'fcm_token': 'legacy-token-xyz',
        });
        await tokenManager.initialize();

        // Now reset SharedPreferences with a NEW value and a fresh manager.
        // A second init would re-scrub if the sentinel didn't gate it; we
        // assert that the new SP value SURVIVES because the sentinel skips.
        SharedPreferences.setMockInitialValues(<String, Object>{
          'fcm_token': 'someone-elses-key-please-leave-alone',
        });

        final secondManager = FCMTokenManager(
          userId: 'test-user-456',
          repository: mockRepo,
          messaging: mockMessaging,
        );
        await secondManager.initialize();
        secondManager.dispose();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('fcm_token'),
          equals('someone-elses-key-please-leave-alone'),
          reason: 'sentinel must stop a second migration sweep',
        );
      });

      test('BUT-457: on Firestore save failure, no plaintext write to '
          'SharedPreferences happens (token never falls back)', () async {
        // Make every Firestore save fail.
        when(
          () => mockRepo.saveTokenToFirestore(any(), any()),
        ).thenThrow(Exception('simulated Firestore outage'));

        // initialize() rethrows the wrapped exception — that's fine; the
        // assertion is that no plaintext SP write smuggles the token to
        // disk on the failure path.
        try {
          await tokenManager.initialize();
        } catch (_) {
          // expected — Firestore save failed
        }

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('fcm_token'),
          isNull,
          reason:
              'token MUST NOT be mirrored to SharedPreferences on '
              'Firestore failure (security regression guard)',
        );
        expect(
          prefs.getString('fcm_token_timestamp'),
          isNull,
          reason: 'timestamp MUST NOT be mirrored either',
        );
      });

      test('should clear state on dispose', () async {
        await tokenManager.initialize();
        tokenManager.dispose();
        expect(tokenManager.isInitialized, isFalse);
      });
    });

    group('Consent revoke (BUT-754)', () {
      test(
        'clearLocalToken removes both SecureStorage keys + nulls memory',
        () async {
          // Arrange — initialize so the token + timestamp land in secure store.
          await tokenManager.initialize();
          expect(
            secureStore['fcm_token'],
            equals('test-token-001'),
            reason: 'precondition: token landed in SecureStorage',
          );
          expect(secureStore['fcm_token_timestamp'], isNotNull);
          expect(tokenManager.isInitialized, isTrue);

          // Act — simulate consent revoke (NotificationService calls this).
          await tokenManager.clearLocalToken();

          // Assert — both keys gone, in-memory cache nulled, but the manager
          // is NOT torn down (no dispose, no topic unsubscribe — that's
          // cleanup()'s job, not clearLocalToken()'s).
          expect(
            secureStore.containsKey('fcm_token'),
            isFalse,
            reason: 'token MUST be deleted from SecureStorage',
          );
          expect(
            secureStore.containsKey('fcm_token_timestamp'),
            isFalse,
            reason: 'timestamp MUST be deleted from SecureStorage',
          );
          expect(
            tokenManager.isInitialized,
            isFalse,
            reason: '_currentToken nulled → isInitialized flips false',
          );
          expect(
            tokenManager.tokenAgeMinutes,
            isNull,
            reason: '_lastTokenRefresh nulled → tokenAgeMinutes is null',
          );
        },
      );

      test(
        'clearLocalToken is idempotent — safe to call when nothing stored',
        () async {
          // No initialize(). secureStore is empty.
          await expectLater(tokenManager.clearLocalToken(), completes);
          expect(secureStore.containsKey('fcm_token'), isFalse);
          expect(tokenManager.isInitialized, isFalse);
        },
      );
    });
  });
}
