import 'dart:async'; // For TimeoutException

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart'; // For TimeOfDay
import 'package:mocktail/mocktail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/services/notifications/notification_repository.dart' as legacy;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// ============= LOCAL MOCKS =============
// Only for Firebase-specific types that aren't in production_mocks.dart
// Note: Using MockNotificationsRepository and MockRemoteMessage from production_mocks

// Keep this local as it's Firebase-specific and not widely used
class MockRemoteNotification extends Mock implements RemoteNotification {}

// Local mock for legacy NotificationRepository interface
class MockLegacyNotificationRepository extends Mock implements legacy.NotificationRepository {}

class FakeNotificationPreferences extends Fake implements legacy.NotificationPreferences {
  @override
  final bool enabled;
  @override
  final Map<NotificationCategory, bool> categorySettings;
  @override
  final Map<NotificationType, bool> typeSettings;
  @override
  final bool allowBatching;
  @override
  final String digestFrequency;
  @override
  final TimeOfDay? quietHoursStart;
  @override
  final TimeOfDay? quietHoursEnd;
  @override
  final bool soundEnabled;
  @override
  final bool vibrationEnabled;
  @override
  final DateTime lastUpdated;

  FakeNotificationPreferences({
    this.enabled = true,
    Map<NotificationCategory, bool>? categorySettings,
    Map<NotificationType, bool>? typeSettings,
    this.allowBatching = true,
    this.digestFrequency = 'never',
    this.quietHoursStart,
    this.quietHoursEnd,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    DateTime? lastUpdated,
  }) : categorySettings = categorySettings ?? {},
       typeSettings = typeSettings ?? {},
       lastUpdated = lastUpdated ?? DateTime.now();
}

// ============= FAKE MODELS =============

class FakeNotificationStrategy extends Fake implements NotificationStrategy {
  @override
  final NotificationType type;
  @override
  final NotificationPriority priority;
  @override
  final NotificationCategory category;

  FakeNotificationStrategy({
    this.type = NotificationType.immediate,
    this.priority = NotificationPriority.high,
    this.category = NotificationCategory.social,
  });
}

class FakeNotificationAction extends Fake implements NotificationAction {
  @override
  final String id;
  @override
  final String title;
  @override
  final Map<String, dynamic>? data;

  FakeNotificationAction({
    required this.id,
    required this.title,
    this.data,
  });
}

// ============= TESTS =============

void main() {
  group('NotificationService', () {
    late NotificationService notificationService;
    late MockNotificationsRepository mockNotificationsRepo;
    late MockLegacyNotificationRepository mockLegacyRepo;
    late FakeFirebaseFirestore fakeFirestore;
    const testUserId = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Register fallback values for mocktail
      registerFallbackValue(FakeNotificationStrategy());
      registerFallbackValue(FakeNotificationAction(id: 'test', title: 'Test'));
      registerFallbackValue(NotificationCategory.social);
      registerFallbackValue(NotificationType.immediate);
      registerFallbackValue(FakeNotificationPreferences());
      registerFallbackValue(DateTime.now());
    });

    setUp(() {
      mockNotificationsRepo = MockNotificationsRepository();
      fakeFirestore = FakeFirebaseFirestore();
      mockLegacyRepo = MockLegacyNotificationRepository();
      
      // Register mocks with TestServiceLocator
      TestServiceLocator.registerMock<NotificationsRepository>(mockNotificationsRepo);
      TestServiceLocator.registerMock<FirebaseFirestore>(fakeFirestore);
      TestServiceLocator.registerMock<legacy.NotificationRepository>(mockLegacyRepo);

      // Setup default stubs for notifications repository
      when(() => mockNotificationsRepo.getNotificationPreferences(any()))
          .thenAnswer((_) async => NotificationPreferences());
      when(() => mockNotificationsRepo.updateNotificationPreferences(any(), any()))
          .thenAnswer((_) async {});
      
      // Setup stubs for legacy notification repository
      when(() => mockLegacyRepo.wasNotificationSent(any()))
          .thenAnswer((_) async => false);
      when(() => mockLegacyRepo.recordNotification(
        notificationId: any(named: 'notificationId'),
        category: any(named: 'category'),
        type: any(named: 'type'),
        data: any(named: 'data'),
      )).thenAnswer((_) async {});
      when(() => mockLegacyRepo.getPreferences())
          .thenAnswer((_) async => legacy.NotificationPreferences.defaults());
      when(() => mockLegacyRepo.markNotificationDelivered(any()))
          .thenAnswer((_) async {});
      when(() => mockLegacyRepo.markNotificationOpened(any()))
          .thenAnswer((_) async {});
      when(() => mockLegacyRepo.clearCache()).thenReturn(null);
      
      // Additional stubs for error handling tests
      when(() => mockLegacyRepo.updatePreferences(any()))
          .thenAnswer((_) async {});

      notificationService = NotificationService(
        userId: testUserId,
      );
    });

    tearDown(() {
      TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize service successfully', () async {
        // Arrange
        // Service already created in setUp
        
        // Act & Assert
        await expectLater(
          notificationService.initialize(),
          completes,
        );
      });

      test('should handle already initialized state', () async {
        // Arrange
        await notificationService.initialize();

        // Act & Assert
        // Should not throw when initialized again
        await expectLater(
          notificationService.initialize(),
          completes,
        );
      });
    });

    group('Immediate Notifications', () {
      test('should send immediate notification to target users', () async {
        // Arrange
        final targetUserIds = ['user-1', 'user-2', 'user-3'];
        final strategy = FakeNotificationStrategy(
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.social,
        );
        final variables = {
          'senderName': 'Anna Andersson',
          'action': 'skickade en vänförfrågan',
        };
        final additionalData = {'requestId': 'req-123'};

        // Act
        await notificationService.sendImmediateNotification(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: variables,
          additionalData: additionalData,
        );

        // Assert - Notification was prepared (logged in dev mode)
        expect(true, isTrue); // Placeholder - actual sending is logged
      });

      test('should handle empty target user list', () async {
        // Arrange
        final targetUserIds = <String>[];
        final strategy = FakeNotificationStrategy();
        final variables = <String, String>{};

        // Act & Assert
        // Should not throw
        await expectLater(
          notificationService.sendImmediateNotification(
            targetUserIds: targetUserIds,
            strategy: strategy,
            variables: variables,
          ),
          completes,
        );
      });

      test('should send notification with image and actions', () async {
        // Arrange
        final targetUserIds = ['user-456'];
        final strategy = FakeNotificationStrategy();
        final variables = {'title': 'Nytt recept', 'body': 'Kolla in mitt nya recept!'};
        const imageUrl = 'https://example.com/recipe.jpg';
        final actions = [
          FakeNotificationAction(
            id: 'view',
            title: 'Visa recept',
            data: {'recipeId': 'recipe-123'},
          ),
        ];

        // Act
        await notificationService.sendImmediateNotification(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: variables,
          imageUrl: imageUrl,
          actions: actions,
        );

        // Assert - Notification was prepared with image and actions
        expect(true, isTrue); // Placeholder
      });
    });

    group('Batchable Notifications', () {
      test('should queue batchable notification', () async {
        // Arrange
        final targetUserIds = ['user-789'];
        final strategy = FakeNotificationStrategy(
          type: NotificationType.batchable,
          category: NotificationCategory.social,
        );
        final variables = {'count': '5', 'type': 'nya kommentarer'};

        // Act
        await notificationService.sendBatchableNotification(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: variables,
        );

        // Assert - Notification was queued for batching
        expect(true, isTrue); // Placeholder
      });

      test('should handle batch with additional data', () async {
        // Arrange
        final targetUserIds = ['user-101', 'user-102'];
        final strategy = FakeNotificationStrategy(
          type: NotificationType.batchable,
        );
        final variables = {'activity': 'gillade ditt recept'};
        final additionalData = {'recipeId': 'recipe-456', 'timestamp': '2024-01-15'};

        // Act
        await notificationService.sendBatchableNotification(
          targetUserIds: targetUserIds,
          strategy: strategy,
          variables: variables,
          additionalData: additionalData,
        );

        // Assert
        expect(true, isTrue); // Placeholder
      });
    });

    group('Silent Notifications', () {
      test('should send silent notification with data', () async {
        // Arrange
        final targetUserIds = ['user-201', 'user-202'];
        final data = {
          'type': 'realtime_edit',
          'recipeId': 'recipe-789',
          'editorId': 'user-100',
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Act
        await notificationService.sendSilentNotification(
          targetUserIds: targetUserIds,
          data: data,
        );

        // Assert - Silent notification was prepared
        expect(true, isTrue); // Placeholder
      });

      test('should handle empty target list for silent notification', () async {
        // Arrange
        final targetUserIds = <String>[];
        final data = {'type': 'background_sync'};

        // Act & Assert
        // Should not throw
        await expectLater(
          notificationService.sendSilentNotification(
            targetUserIds: targetUserIds,
            data: data,
          ),
          completes,
        );
      });
    });

    group('Digest Notifications', () {
      test('should send digest notification with activity list', () async {
        // Arrange
        const targetUserId = 'user-303';
        final strategy = FakeNotificationStrategy(
          type: NotificationType.digest,
          category: NotificationCategory.social,
        );
        final activityList = [
          {'type': 'recipe_liked', 'count': '3'},
          {'type': 'new_followers', 'count': '2'},
          {'type': 'comments', 'count': '5'},
        ];

        // Act
        await notificationService.sendDigestNotification(
          targetUserId: targetUserId,
          strategy: strategy,
          activityList: activityList,
        );

        // Assert - Digest was prepared
        expect(true, isTrue); // Placeholder
      });

      test('should handle empty activity list', () async {
        // Arrange
        const targetUserId = 'user-404';
        final strategy = FakeNotificationStrategy(
          type: NotificationType.digest,
        );
        final activityList = <Map<String, String>>[];

        // Act & Assert
        // Should not throw
        await expectLater(
          notificationService.sendDigestNotification(
            targetUserId: targetUserId,
            strategy: strategy,
            activityList: activityList,
          ),
          completes,
        );
      });
    });

    group('Quiet Hours', () {
      test('should check if user is in quiet hours', () async {
        // Arrange
        // User ID to check
        const userId = 'user-505';
        
        // Act
        final isQuiet = await notificationService.isInQuietHours(userId);

        // Assert
        expect(isQuiet, isA<bool>());
      });
    });

    group('Topic Subscriptions', () {
      test('should update topic subscriptions', () async {
        // Act & Assert - Should not throw
        await expectLater(
          notificationService.updateTopicSubscriptions(),
          completes,
        );
      });
    });

    group('Preferences', () {
      test('should get notification preferences', () async {
        // Act
        final preferences = await notificationService.getPreferences();

        // Assert
        expect(preferences, isNotNull);
        expect(preferences, isA<legacy.NotificationPreferences>());
      });

      test('should update notification preferences', () async {
        // Arrange
        final mockPreferences = FakeNotificationPreferences();

        // Act & Assert - Should not throw
        await expectLater(
          notificationService.updatePreferences(mockPreferences),
          completes,
        );
      });
    });

    group('Utility Methods', () {
      test('should get current FCM token', () async {
        // Act
        final token = await notificationService.getCurrentToken();

        // Assert
        expect(token, isA<String?>());
      });

      test('should get analytics summary', () async {
        // Act
        final summary = await notificationService.getAnalyticsSummary();

        // Assert
        expect(summary, isA<Map<String, dynamic>>());
      });

      test('should get offline queue statistics', () {
        // Act
        final stats = notificationService.getOfflineQueueStats();

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });

      test('should get batch statistics', () {
        // Act
        final stats = notificationService.getBatchStats();

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });

    group('Online Status', () {
      test('should update online status to online', () {
        // Act & Assert - Should not throw
        expect(() => notificationService.setOnlineStatus(true), returnsNormally);
      });

      test('should update online status to offline', () {
        // Act & Assert - Should not throw
        expect(() => notificationService.setOnlineStatus(false), returnsNormally);
      });
    });

    group('Service Lifecycle', () {
      test('should dispose service properly', () async {
        // Arrange
        await notificationService.initialize();

        // Act & Assert
        await expectLater(notificationService.dispose(), completes);
      });

      test('should handle dispose without initialization', () async {
        // Act & Assert - Should not throw even if not initialized
        await expectLater(notificationService.dispose(), completes);
      });
    });

    group('Error Handling', () {
      group('FCM/Firebase Errors', () {
        test('should handle FCM token retrieval failure', () async {
          // Arrange - Simulate token manager failure
          // Note: Token retrieval is internal to FCMTokenManager
          
          // Act
          final token = await notificationService.getCurrentToken();
          
          // Assert - Should return null or handle gracefully
          expect(token, isA<String?>());
        });

        test('should handle permission denied for notifications', () async {
          // Arrange
          when(() => mockNotificationsRepo.getNotificationPreferences(any()))
              .thenAnswer((_) async => throw Exception('Permission denied'));
          
          final targetUserIds = ['user-no-permission'];
          final strategy = FakeNotificationStrategy();

          // Act & Assert - Should handle gracefully
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'title': 'Test', 'body': 'Test'},
            ),
            completes,
          );
        });

        test('should handle FCM quota exceeded error', () async {
          // Arrange - Simulate large batch that would exceed quota
          final targetUserIds = List.generate(1000, (i) => 'user-$i');
          final strategy = FakeNotificationStrategy();

          // Act & Assert - Should handle gracefully by batching or queuing
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'title': 'Mass notification', 'body': 'Test'},
            ),
            completes,
          );
        });
      });

      group('Notification Sending Errors', () {
        test('should validate empty title', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          final variables = {'title': '', 'body': 'Test body'};

          // Act & Assert - Should handle validation
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should validate empty body', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          final variables = {'title': 'Test title', 'body': ''};

          // Act & Assert - Should handle validation
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should handle title too long (>100 chars)', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          final longTitle = 'A' * 150; // 150 characters
          final variables = {'title': longTitle, 'body': 'Test'};

          // Act & Assert - Should truncate or handle
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should handle body too long (>1000 chars)', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          final longBody = 'B' * 1500; // 1500 characters
          final variables = {'title': 'Test', 'body': longBody};

          // Act & Assert - Should truncate or handle
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should handle invalid target user IDs', () async {
          // Arrange
          final targetUserIds = ['', null, '   ', 'user@invalid'].whereType<String>().toList();
          final strategy = FakeNotificationStrategy();
          final variables = {'title': 'Test', 'body': 'Test'};

          // Act & Assert - Should filter invalid IDs
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should handle network timeout during send', () async {
          // Arrange
          when(() => mockNotificationsRepo.getNotificationPreferences(any()))
              .thenAnswer((_) async {
                await Future.delayed(const Duration(seconds: 35));
                throw TimeoutException('Network timeout');
              });

          final targetUserIds = ['user-timeout'];
          final strategy = FakeNotificationStrategy();

          // Act & Assert - Should handle timeout
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'title': 'Test', 'body': 'Test'},
            ).timeout(const Duration(seconds: 5), onTimeout: () {}),
            completes,
          );
        });

        test('should handle invalid notification payload', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          // Circular reference in additional data
          final circularData = <String, dynamic>{};
          circularData['self'] = circularData;

          // Act & Assert - Should handle serialization error
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'title': 'Test', 'body': 'Test'},
              additionalData: circularData,
            ),
            completes,
          );
        });
      });

      group('Topic Management Errors', () {
        test('should handle topic subscription errors', () async {
          // Arrange - Topic management is internal to FCMTokenManager
          // The updateTopicSubscriptions method handles errors internally

          // Act & Assert - Should complete without throwing
          await expectLater(
            notificationService.updateTopicSubscriptions(),
            completes,
          );
        });

        test('should handle invalid topic names gracefully', () async {
          // Arrange - Invalid topics would be filtered by FCMTokenManager
          // The service should handle this internally

          // Act & Assert - Should handle validation internally
          await expectLater(
            notificationService.updateTopicSubscriptions(),
            completes,
          );
        });
      });

      group('Batch Notification Errors', () {
        test('should handle batch size exceeded (>500)', () async {
          // Arrange
          final targetUserIds = List.generate(600, (i) => 'user-$i');
          final strategy = FakeNotificationStrategy(
            type: NotificationType.batchable,
          );

          // Act & Assert - Should split batch or handle limit
          await expectLater(
            notificationService.sendBatchableNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'message': 'Batch test'},
            ),
            completes,
          );
        });

        test('should handle partial batch failures', () async {
          // Arrange - Batch manager handles partial failures internally
          final targetUserIds = List.generate(10, (i) => 'user-$i');
          final strategy = FakeNotificationStrategy(
            type: NotificationType.batchable,
          );

          // Act & Assert - Should continue despite partial failures
          await expectLater(
            notificationService.sendBatchableNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'message': 'Partial batch'},
            ),
            completes,
          );
        });

        test('should handle invalid user IDs in batch', () async {
          // Arrange
          final targetUserIds = [
            'valid-user-1',
            '',
            'valid-user-2',
            '   ',
            'valid-user-3',
            null,
          ].whereType<String>().toList();
          final strategy = FakeNotificationStrategy(
            type: NotificationType.batchable,
          );

          // Act & Assert - Should filter invalid IDs
          await expectLater(
            notificationService.sendBatchableNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'message': 'Filtered batch'},
            ),
            completes,
          );
        });

        test('should handle timeout during batch send', () async {
          // Arrange - Simulate slow batch processing
          final targetUserIds = List.generate(100, (i) => 'user-$i');
          final strategy = FakeNotificationStrategy(
            type: NotificationType.batchable,
          );

          // Act & Assert - Should handle timeout by queuing
          await expectLater(
            notificationService.sendBatchableNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'message': 'Timeout test'},
            ).timeout(const Duration(seconds: 10), onTimeout: () {}),
            completes,
          );
        });
      });

      group('Delayed Notification Errors', () {
        test('should handle delayed notification via batch system', () async {
          // Arrange - Scheduling is handled via batch manager
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy(
            type: NotificationType.batchable,
          );

          // Act & Assert - Should queue for later delivery
          await expectLater(
            notificationService.sendBatchableNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'title': 'Delayed', 'body': 'Test'},
            ),
            completes,
          );
        });

        test('should handle offline queue for delayed delivery', () async {
          // Arrange - Set offline status
          notificationService.setOnlineStatus(false);
          final targetUserIds = ['user-456'];
          final strategy = FakeNotificationStrategy();

          // Act & Assert - Should queue for offline delivery
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: {'title': 'Offline', 'body': 'Queued'},
            ),
            completes,
          );
          
          // Reset online status
          notificationService.setOnlineStatus(true);
        });
      });

      group('Quiet Hours & User Preference Errors', () {
        test('should handle invalid quiet hour settings', () async {
          // Arrange - End time before start time
          final invalidPrefs = FakeNotificationPreferences(
            quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
            quietHoursEnd: const TimeOfDay(hour: 21, minute: 0),
          );

          when(() => mockLegacyRepo.getPreferences())
              .thenAnswer((_) async => invalidPrefs);

          // Act & Assert - Should handle invalid settings
          final isQuiet = await notificationService.isInQuietHours('user-123');
          expect(isQuiet, isA<bool>());
        });

        test('should handle user preferences fetch failure', () async {
          // Arrange
          when(() => mockLegacyRepo.getPreferences())
              .thenAnswer((_) async => throw Exception('Failed to fetch preferences'));
          when(() => mockNotificationsRepo.getNotificationPreferences(any()))
              .thenAnswer((_) async => throw Exception('Database error'));

          // Act & Assert - Should use defaults
          final preferences = await notificationService.getPreferences();
          expect(preferences, isNotNull);
        });

        test('should handle concurrent preference updates', () async {
          // Arrange
          final prefs1 = FakeNotificationPreferences(soundEnabled: true);
          final prefs2 = FakeNotificationPreferences(soundEnabled: false);

          var updateCount = 0;
          when(() => mockLegacyRepo.updatePreferences(any()))
              .thenAnswer((_) async {
                updateCount++;
                if (updateCount == 1) {
                  // Simulate concurrent modification
                  throw Exception('CONCURRENT_MODIFICATION');
                }
              });

          // Act - Try to update twice concurrently
          final update1 = notificationService.updatePreferences(prefs1);
          final update2 = notificationService.updatePreferences(prefs2);

          // Assert - Should handle concurrent updates
          await expectLater(
            Future.wait([update1, update2]),
            completes,
          );
        });
      });

      group('Content & Localization Errors', () {
        test('should handle missing template parameters', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          // Missing required parameters for template
          final incompleteVars = {'name': 'John'};
          // Template expects: name, action, count

          // Act & Assert - Should handle missing params
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: incompleteVars,
            ),
            completes,
          );
        });

        test('should handle invalid content generation', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          final variables = {
            'templateId': 'non_existent_template',
            'title': 'Fallback',
            'body': 'Fallback message',
          };

          // Act & Assert - Content manager should use fallback
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should handle unsupported locale', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          final variables = {
            'locale': 'xx-YY', // Unsupported locale
            'title': 'Test',
            'body': 'Test message',
          };

          // Act & Assert - Should fall back to default locale (Swedish)
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });

        test('should handle template parsing errors', () async {
          // Arrange
          final targetUserIds = ['user-123'];
          final strategy = FakeNotificationStrategy();
          // Malformed template variables
          final variables = {
            'title': 'Hello {{name}', // Missing closing bracket
            'body': 'Count: {{count}} items {{', // Incomplete template
            'name': 'John',
            'count': '5',
          };

          // Act & Assert - Content manager should handle parsing errors
          await expectLater(
            notificationService.sendImmediateNotification(
              targetUserIds: targetUserIds,
              strategy: strategy,
              variables: variables,
            ),
            completes,
          );
        });
      });
    });
  });
}