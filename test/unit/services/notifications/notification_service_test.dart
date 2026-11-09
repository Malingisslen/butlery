/// Unit tests for NotificationService coordinator
///
/// Tests the facade that delegates to 6 specialized managers:
/// content, preferences, offline, batch, FCM token, analytics.
library;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/notifications/modules/fcm_token_manager.dart';

import 'package:butlery/services/notifications/fcm_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/interfaces/notification_analytics_repository.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockAuthRepo extends Mock implements AuthRepository {
  @override
  String? get currentUserId => 'test-user-123';
}

class _MockFcm extends Mock implements FCMService {}

class _MockHistoryRepo extends Mock implements NotificationHistoryRepository {}

class _MockBatchRepo extends Mock implements NotificationBatchRepository {}

class _MockDeviceRepo extends Mock implements DeviceRepository {}

class _MockAnalyticsRepo extends Mock
    implements NotificationAnalyticsRepository {}

class _MockTokenManager extends Mock implements FCMTokenManager {}

/// Captures the listener NotificationService registers so a test can
/// replay a consent change.
class _FakeConsent extends Mock implements ConsentService {
  _FakeConsent(this.pushGranted);

  bool pushGranted;
  final List<VoidCallback> listeners = <VoidCallback>[];

  @override
  Future<bool> hasConsent(ConsentPurpose purpose) async =>
      purpose == ConsentPurpose.pushNotifications && pushGranted;

  @override
  void addListener(VoidCallback listener) => listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);

  Future<void> fire() async {
    for (final listener in List.of(listeners)) {
      listener();
    }
    await pumpEventQueue();
  }
}

void main() {
  group('NotificationService', () {
    late NotificationService service;
    late MockNotificationsRepository mockNotificationsRepo;
    late _MockAuthRepo mockAuthRepo;
    late _MockHistoryRepo mockHistoryRepo;
    late _MockBatchRepo mockBatchRepo;
    late _MockDeviceRepo mockDeviceRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to test GetIt instance
      production.ServiceLocator.initialize(DIContainer());

      registerFallbackValue(NotificationCategory.social);
      registerFallbackValue(NotificationType.immediate);
      registerFallbackValue(DateTime.now());
    });

    setUp(() {
      mockNotificationsRepo = MockNotificationsRepository();
      mockAuthRepo = _MockAuthRepo();
      mockHistoryRepo = _MockHistoryRepo();
      mockBatchRepo = _MockBatchRepo();
      mockDeviceRepo = _MockDeviceRepo();

      // Stub notifications repository
      when(
        () => mockNotificationsRepo.getNotificationPreferences(any()),
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      when(
        () => mockNotificationsRepo.updateNotificationPreferences(any(), any()),
      ).thenAnswer((_) async {});

      // Stub history repository
      when(
        () => mockHistoryRepo.wasNotificationSent(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockHistoryRepo.recordNotification(
          notificationId: any(named: 'notificationId'),
          category: any(named: 'category'),
          type: any(named: 'type'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockHistoryRepo.markNotificationDelivered(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockHistoryRepo.markNotificationOpened(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockHistoryRepo.getHistory(
          any(),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => []);

      // Register notifications repo override so internal modules can find it
      TestServiceLocator.registerMock<NotificationsRepository>(
        mockNotificationsRepo,
      );

      service = NotificationService(
        notificationsRepository: mockNotificationsRepo,
        authRepository: mockAuthRepo,
        historyRepository: mockHistoryRepo,
        batchRepository: mockBatchRepo,
        deviceRepository: mockDeviceRepo,
        analyticsRepository: _MockAnalyticsRepo(),
        fcmService: _MockFcm(),
        getConsentService: () => null,
      );
    });

    tearDown(() {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    group('Preferences', () {
      test('should get notification preferences', () async {
        final prefs = await service.getPreferences();
        expect(prefs, isA<NotificationPreferences>());
        expect(prefs.enabled, isTrue);
      });

      test('should update notification preferences', () async {
        final prefs = NotificationPreferences.defaults();
        await expectLater(service.updatePreferences(prefs), completes);
      });

      test('should handle preferences fetch failure gracefully', () async {
        when(
          () => mockNotificationsRepo.getNotificationPreferences(any()),
        ).thenThrow(Exception('DB error'));

        // getPreferences uses the preference manager which caches;
        // on error it should return defaults via the manager's fallback
        final prefs = await service.getPreferences();
        expect(prefs, isA<NotificationPreferences>());
      });
    });

    group('Quiet Hours', () {
      test('should check quiet hours status', () async {
        final result = await service.isInQuietHours('any-user');
        expect(result, isA<bool>());
      });
    });

    group('Immediate Notifications', () {
      test('should complete for valid target users', () async {
        final strategy = NotificationStrategy(
          notificationType: 'test',
          destination: NotificationDestination(NotificationRoutes.home),
          type: NotificationType.immediate,
          priority: NotificationPriority.medium,
          category: NotificationCategory.social,
        );

        await expectLater(
          service.sendImmediateNotification(
            targetUserIds: ['user-1', 'user-2'],
            strategy: strategy,
            variables: {'title': 'Test', 'body': 'Hello'},
          ),
          completes,
        );
      });

      test('should complete for empty target list', () async {
        final strategy = NotificationStrategy(
          notificationType: 'test',
          destination: NotificationDestination(NotificationRoutes.home),
          type: NotificationType.immediate,
          priority: NotificationPriority.medium,
          category: NotificationCategory.social,
        );

        await expectLater(
          service.sendImmediateNotification(
            targetUserIds: [],
            strategy: strategy,
            variables: {},
          ),
          completes,
        );
      });
    });

    group('Batchable Notifications', () {
      test('should queue batchable notification', () async {
        final strategy = NotificationStrategy(
          notificationType: 'test',
          destination: NotificationDestination(NotificationRoutes.home),
          type: NotificationType.batchable,
          priority: NotificationPriority.low,
          category: NotificationCategory.social,
        );

        await expectLater(
          service.sendBatchableNotification(
            targetUserIds: ['user-1'],
            strategy: strategy,
            variables: {'count': '5'},
          ),
          completes,
        );
      });
    });

    group('Silent Notifications', () {
      test('should send silent notification', () async {
        await expectLater(
          service.sendSilentNotification(
            targetUserIds: ['user-1'],
            data: {'type': 'sync', 'recipeId': 'r1'},
          ),
          completes,
        );
      });
    });

    group('Digest Notifications', () {
      test('should send digest notification', () async {
        final strategy = NotificationStrategy(
          notificationType: 'test',
          destination: NotificationDestination(NotificationRoutes.home),
          type: NotificationType.digest,
          priority: NotificationPriority.low,
          category: NotificationCategory.social,
        );

        await expectLater(
          service.sendDigestNotification(
            targetUserId: 'user-1',
            strategy: strategy,
            activityList: [
              {'type': 'like', 'count': '3'},
            ],
          ),
          completes,
        );
      });
    });

    group('Utility Methods', () {
      test('should get FCM token (null without real FCM)', () async {
        final token = await service.getCurrentToken();
        // FCMTokenManager creation fails in test (no real Firebase),
        // so _tokenManager is null, returning null
        expect(token, isNull);
      });

      test('should get analytics summary', () async {
        final summary = await service.getAnalyticsSummary();
        expect(summary, isA<Map<String, dynamic>>());
      });

      test('should get offline queue stats', () {
        final stats = service.getOfflineQueueStats();
        expect(stats, isA<Map<String, dynamic>>());
      });

      test('should get batch stats', () {
        final stats = service.getBatchStats();
        expect(stats, isA<Map<String, dynamic>>());
      });

      test('should get notification history', () async {
        final history = await service.getNotificationHistory();
        expect(history, isEmpty);
      });
    });

    group('Online Status', () {
      test('should set online status without error', () {
        expect(() => service.setOnlineStatus(true), returnsNormally);
        expect(() => service.setOnlineStatus(false), returnsNormally);
      });
    });

    group('Topic Subscriptions', () {
      test('should update topic subscriptions without error', () async {
        await expectLater(service.updateTopicSubscriptions(), completes);
      });
    });

    // The token manager asks the OS for notification permission and
    // registers the device, so it must wait for push consent.
    group('Push consent gate', () {
      late _MockTokenManager tokenManager;
      late _MockFcm fcm;

      NotificationService buildWith(ConsentService consent) =>
          NotificationService(
            notificationsRepository: mockNotificationsRepo,
            authRepository: mockAuthRepo,
            historyRepository: mockHistoryRepo,
            batchRepository: mockBatchRepo,
            deviceRepository: mockDeviceRepo,
            analyticsRepository: _MockAnalyticsRepo(),
            fcmService: fcm,
            getConsentService: () => consent,
            createTokenManager: (_) => tokenManager,
          );

      setUp(() {
        tokenManager = _MockTokenManager();
        when(() => tokenManager.initialize()).thenAnswer((_) async {});
        when(
          () => tokenManager.updateTopicSubscriptions(any()),
        ).thenAnswer((_) async {});
        when(() => tokenManager.clearLocalToken()).thenAnswer((_) async {});

        fcm = _MockFcm();
        when(
          () => fcm.initialize(
            onMessageReceived: any(named: 'onMessageReceived'),
            onMessageOpenedApp: any(named: 'onMessageOpenedApp'),
            consentService: any(named: 'consentService'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => fcm.bindUserContext(
            onMessageReceived: any(named: 'onMessageReceived'),
            onMessageOpenedApp: any(named: 'onMessageOpenedApp'),
            consentService: any(named: 'consentService'),
          ),
        ).thenAnswer((_) async {});
      });

      test('without push consent the token manager never starts', () async {
        final service = buildWith(_FakeConsent(false));

        await service.initialize();
        await service.updateTopicSubscriptions();

        verifyNever(() => tokenManager.initialize());
        verifyNever(() => tokenManager.updateTopicSubscriptions(any()));
      });

      test('with push consent the token manager starts once', () async {
        final service = buildWith(_FakeConsent(true));

        await service.initialize();

        verify(() => tokenManager.initialize()).called(1);
        verify(() => tokenManager.updateTopicSubscriptions(any())).called(1);
      });

      test('a mid-session grant starts the token manager', () async {
        final consent = _FakeConsent(false);
        final service = buildWith(consent);
        await service.initialize();
        verifyNever(() => tokenManager.initialize());

        consent.pushGranted = true;
        await consent.fire();

        verify(() => tokenManager.initialize()).called(1);
      });

      test('a revoke stops the started token manager', () async {
        final consent = _FakeConsent(true);
        final service = buildWith(consent);
        await service.initialize();
        verify(() => tokenManager.updateTopicSubscriptions(any())).called(1);

        consent.pushGranted = false;
        await consent.fire();
        await service.updateTopicSubscriptions();

        verify(() => tokenManager.clearLocalToken()).called(1);
        verify(() => tokenManager.dispose()).called(1);
        verifyNever(() => tokenManager.updateTopicSubscriptions(any()));
      });

      test('a grant after a revoke starts a fresh token manager', () async {
        final built = <_MockTokenManager>[];
        final consent = _FakeConsent(true);
        final service = NotificationService(
          notificationsRepository: mockNotificationsRepo,
          authRepository: mockAuthRepo,
          historyRepository: mockHistoryRepo,
          batchRepository: mockBatchRepo,
          deviceRepository: mockDeviceRepo,
          analyticsRepository: _MockAnalyticsRepo(),
          fcmService: fcm,
          getConsentService: () => consent,
          createTokenManager: (_) {
            final manager = _MockTokenManager();
            when(() => manager.initialize()).thenAnswer((_) async {});
            when(
              () => manager.updateTopicSubscriptions(any()),
            ).thenAnswer((_) async {});
            when(() => manager.clearLocalToken()).thenAnswer((_) async {});
            built.add(manager);
            return manager;
          },
        );
        await service.initialize();

        consent.pushGranted = false;
        await consent.fire();
        consent.pushGranted = true;
        await consent.fire();

        expect(built, hasLength(2));
        verify(() => built.first.dispose()).called(1);
        verify(() => built.first.initialize()).called(1);
        verify(() => built.last.initialize()).called(1);
      });

      test('a failed start is retried on the next grant', () async {
        var attempts = 0;
        when(() => tokenManager.initialize()).thenAnswer((_) async {
          attempts++;
          if (attempts == 1) throw StateError('keystore unavailable');
        });
        final consent = _FakeConsent(true);
        final service = buildWith(consent);
        await service.initialize();
        // The failure must not stop the rest of start-up: a finished start
        // makes a second initialize a no-op that never reaches FCM again.
        await service.initialize();
        verify(
          () => fcm.initialize(
            onMessageReceived: any(named: 'onMessageReceived'),
            onMessageOpenedApp: any(named: 'onMessageOpenedApp'),
            consentService: any(named: 'consentService'),
          ),
        ).called(1);

        await consent.fire();

        expect(attempts, 2);
      });
    });

    group('Lifecycle', () {
      test('should dispose without initialization', () async {
        await expectLater(service.dispose(), completes);
      });

      test('should reset for logout', () async {
        // Trigger module creation via a method call
        await service.getPreferences();
        await expectLater(service.resetForLogout(), completes);
      });
    });
  });
}
