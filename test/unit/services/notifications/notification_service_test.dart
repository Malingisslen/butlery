/// Unit tests for NotificationService coordinator
///
/// Tests the facade that delegates to 6 specialized managers:
/// content, preferences, offline, batch, FCM token, analytics.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockHistoryRepo extends Mock implements NotificationHistoryRepository {}

class _MockBatchRepo extends Mock implements NotificationBatchRepository {}

class _MockDeviceRepo extends Mock implements DeviceRepository {}

// BUT-1181: NotificationAnalyticsManager resolves this via
// ServiceLocator.get<NotificationAnalyticsRepository>() at construction, so it
// must be registered before NotificationService is built or every test throws
// "not registered inside GetIt".
class _MockAnalyticsRepo extends Mock
    implements NotificationAnalyticsRepository {}

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
      // TestServiceLocator registers FirestoreRepository (needed by
      // NotificationAnalyticsManager constructor via ServiceLocator.get)
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

      // BUT-1181: NotificationAnalyticsManager resolves its repo via
      // ServiceLocator.get at construction — register a mock so the service
      // builds. The 15 preferences/quiet-hours/utility tests don't drive the
      // analytics write/read paths, so a bare mock is sufficient.
      TestServiceLocator.registerMock<NotificationAnalyticsRepository>(
        _MockAnalyticsRepo(),
      );

      service = NotificationService(
        notificationsRepository: mockNotificationsRepo,
        authRepository: mockAuthRepo,
        historyRepository: mockHistoryRepo,
        batchRepository: mockBatchRepo,
        deviceRepository: mockDeviceRepo,
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
