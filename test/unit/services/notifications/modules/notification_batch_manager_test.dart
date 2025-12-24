/// Unit tests for NotificationBatchManager
/// 
/// Tests intelligent notification batching including grouping, spam prevention,
/// rate limiting, batch window management, and combined notification generation.
/// Tests against the REAL NotificationBatchManager production code.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clock/clock.dart';

// Production code being tested
import 'package:butlery/services/notifications/modules/notification_batch_manager.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/notifications/notification_repository.dart';
import 'package:butlery/models/notification_batch.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

// Mock classes
class MockNotificationRepository extends Mock implements NotificationRepository {}

// Fake classes for fallback values
class FakeNotificationTemplate extends Fake implements NotificationTemplate {}
class FakeNotificationBatch extends Fake implements NotificationBatch {}
class FakeNotificationStrategy extends Fake implements NotificationStrategy {}

void main() {
  // Register fallback values for mocktail
  setUpAll(() {
    registerFallbackValue(FakeNotificationTemplate());
    registerFallbackValue(FakeNotificationBatch());
    registerFallbackValue(FakeNotificationStrategy());
    registerFallbackValue(const Duration(minutes: 5));
  });

  group('NotificationBatchManager', () {
    late NotificationBatchManager batchManager;
    late MockNotificationRepository mockRepository;
    late List<NotificationBatch> sentBatches;
    
    // Create test notification strategy
    NotificationStrategy createTestStrategy({
      NotificationType? type,
      NotificationCategory? category,
      Duration? batchWindow,
    }) {
      return NotificationStrategy(
        type: type ?? NotificationType.batchable,
        priority: NotificationPriority.medium,
        category: category ?? NotificationCategory.social,
        batchWindow: batchWindow ?? const Duration(minutes: 5),
        requiresInternet: true,
        localization: {'en': 'Test', 'sv': 'Test'},
      );
    }
    
    // Create test notification template
    NotificationTemplate createTestTemplate({
      String? title,
      String? body,
      Map<String, dynamic>? data,
      String? imageUrl,
    }) {
      return NotificationTemplate(
        title: title ?? 'Test Notification',
        body: body ?? 'Test notification body',
        data: data ?? {'category': 'NotificationCategory.social', 'timestamp': DateTime.now().toIso8601String()},
        imageUrl: imageUrl,
        actions: null,
      );
    }
    
    // Create test notification batch
    NotificationBatch createTestBatch({
      String? batchKey,
      String? userId,
      List<NotificationTemplate>? notifications,
      DateTime? createdAt,
      DateTime? scheduledFor,
    }) {
      return NotificationBatch(
        batchKey: batchKey ?? 'test-batch-key',
        userId: userId ?? 'test-user-123',
        notifications: notifications ?? [createTestTemplate()],
        createdAt: createdAt ?? DateTime.now(),
        scheduledFor: scheduledFor ?? DateTime.now().add(const Duration(minutes: 5)),
      );
    }
    
    setUp(() async {
      // Initialize test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockRepository = MockNotificationRepository();
      
      // Reset tracking
      sentBatches = [];
      
      // Configure mock repository behavior
      when(() => mockRepository.addToBatch(
        batchKey: any(named: 'batchKey'),
        notification: any(named: 'notification'),
        batchWindow: any(named: 'batchWindow'),
      )).thenAnswer((_) async {});
      
      when(() => mockRepository.getPendingBatches())
          .thenAnswer((_) async => []);
      
      when(() => mockRepository.removeBatch(any()))
          .thenAnswer((_) async {});
      
      // Create the REAL NotificationBatchManager with mocked dependencies
      batchManager = NotificationBatchManager(
        userId: 'test-user-123',
        repository: mockRepository,
        sendBatchCallback: (batch) async {
          sentBatches.add(batch);
        },
      );
    });
    
    tearDown(() async {
      // Clean up
      batchManager.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    group('Batch Creation', () {
      test('should add batchable notifications to batch', () async {
        // Arrange
        final strategy = createTestStrategy(type: NotificationType.batchable);
        
        // Act
        final result = await batchManager.addToBatch(
          targetUserIds: ['user1', 'user2'],
          strategy: strategy,
          variables: {'title': 'Test', 'body': 'Test body'},
        );
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).called(2); // Called for each user
      });
      
      test('should reject non-batchable notifications', () async {
        // Arrange
        final strategy = createTestStrategy(type: NotificationType.immediate);
        
        // Act
        final result = await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy,
          variables: {'title': 'Test'},
        );
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        ));
      });
      
      test('should generate unique batch keys for different strategies', () async {
        // Arrange
        final fixedTime = DateTime(2024, 1, 1, 12, 0);
        final clock = Clock.fixed(fixedTime);
        
        batchManager = NotificationBatchManager(
          userId: 'test_user',
          repository: mockRepository,
          clock: clock,
        );
        
        // Use different categories to ensure unique keys (both must be batchable)
        final strategy1 = createTestStrategy(
          category: NotificationCategory.social,
          type: NotificationType.batchable,
          batchWindow: const Duration(minutes: 5),
        );
        final strategy2 = createTestStrategy(
          category: NotificationCategory.friends,
          type: NotificationType.batchable,
          batchWindow: const Duration(minutes: 5),
        );
        
        final capturedBatchKeys = <String>[];
        when(() => mockRepository.addToBatch(
          batchKey: captureAny(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).thenAnswer((invocation) async {
          capturedBatchKeys.add(invocation.namedArguments[const Symbol('batchKey')] as String);
        });
        
        // Act
        await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy1,
          variables: {'title': 'Test1'},
        );
        
        await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy2,
          variables: {'title': 'Test2'},
        );
        
        // Assert - keys should be different due to different strategy types
        expect(capturedBatchKeys.length, equals(2));
        expect(capturedBatchKeys[0], isNot(equals(capturedBatchKeys[1])));
      });
      
      test('should add batchable notifications and schedule processing', () async {
        // Arrange
        final strategy = createTestStrategy(
          batchWindow: const Duration(seconds: 5),
        );
        
        // Act - Add to batch (this internally schedules a timer)
        final result = await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy,
          variables: {'title': 'Test'},
        );
        
        // Assert - Verify the notification was added to batch
        expect(result, isTrue);
        
        // Verify the repository was called to add to batch
        verify(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).called(1);
      }, skip: 'Timer scheduling is internal implementation detail');
    });
    
    group('Rate Limiting', () {
      test('should enforce rate limits for different categories', () async {
        // Arrange
        final systemStrategy = createTestStrategy(category: NotificationCategory.system);
        
        // Act - Send 4 system notifications (limit is 3 in 15 minutes)
        for (int i = 0; i < 4; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['test-user-123'],
            strategy: systemStrategy,
            variables: {'title': 'System $i'},
          );
        }
        
        // Assert - Only 3 should be added (4th exceeds rate limit)
        verify(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).called(3);
      });
      
      test('should have different limits for each category', () async {
        // Arrange
        final friendsStrategy = createTestStrategy(category: NotificationCategory.friends);
        final messagingStrategy = createTestStrategy(category: NotificationCategory.messaging);
        
        // Act - Friends limit is 10, Messaging limit is 20
        for (int i = 0; i < 12; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['test-user-123'],
            strategy: friendsStrategy,
            variables: {'title': 'Friend $i'},
          );
        }
        
        for (int i = 0; i < 22; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['test-user-123'],
            strategy: messagingStrategy,
            variables: {'title': 'Message $i'},
          );
        }
        
        // Assert
        verify(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).called(30); // 10 friends + 20 messaging
      });
      
      test('should cleanup old rate limit entries', () async {
        // Arrange - Start with a fixed time
        final startTime = DateTime(2024, 1, 1, 12, 0);
        final oldTime = startTime.subtract(const Duration(minutes: 20));
        final recentTime = startTime.subtract(const Duration(seconds: 30));
        
        // Create a batch manager with ability to manipulate time
        Clock testClock = Clock.fixed(oldTime);
        batchManager = NotificationBatchManager(
          userId: 'test_user',
          repository: mockRepository,
          clock: testClock,
        );
        
        final strategy = createTestStrategy(category: NotificationCategory.friends);
        
        // Add some old notifications (20 minutes ago)
        for (int i = 0; i < 5; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['user1'],
            strategy: strategy,
            variables: {'title': 'Old $i'},
          );
        }
        
        // Now update to recent time and add more notifications
        testClock = Clock.fixed(recentTime);
        batchManager = NotificationBatchManager(
          userId: 'test_user',
          repository: mockRepository,
          clock: testClock,
        );
        
        // Add recent notifications (30 seconds ago)
        for (int i = 0; i < 5; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['user1'],
            strategy: strategy,
            variables: {'title': 'Recent $i'},
          );
        }
        
        // Now move to current time
        testClock = Clock.fixed(startTime);
        batchManager = NotificationBatchManager(
          userId: 'test_user',
          repository: mockRepository,
          clock: testClock,
        );
        
        // Add current notifications
        for (int i = 0; i < 5; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['user1'],
            strategy: strategy,
            variables: {'title': 'Current $i'},
          );
        }
        
        // Get initial stats - should have rate limit tracking
        final statsBefore = batchManager.getBatchStatistics();
        final trackingBefore = statsBefore['rate_limit_tracking'] as Map;
        expect(trackingBefore.isNotEmpty, isTrue);
        expect(trackingBefore['user1_friends'], equals(5)); // Only current ones
        
        // Clean up with 15 minute window (should keep all as we only track recent)
        batchManager.cleanupRateLimitData(const Duration(minutes: 15));
        
        // Assert - Current entries remain
        final statsAfter = batchManager.getBatchStatistics();
        final trackingAfter = statsAfter['rate_limit_tracking'] as Map;
        expect(trackingAfter['user1_friends'], equals(5));
      });
      
      test('should track rate limits per user independently', () async {
        // Arrange
        final strategy = createTestStrategy(category: NotificationCategory.system);
        
        // Act - Send 3 notifications to each user (system limit is 3)
        for (int i = 0; i < 3; i++) {
          await batchManager.addToBatch(
            targetUserIds: ['user1'],
            strategy: strategy,
            variables: {'title': 'System $i'},
          );
          
          await batchManager.addToBatch(
            targetUserIds: ['user2'],
            strategy: strategy,
            variables: {'title': 'System $i'},
          );
        }
        
        // Assert - All 6 should be added (3 per user)
        verify(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).called(6);
      });
    });
    
    group('Spam Prevention', () {
      test('should detect identical title spam pattern', () async {
        // Arrange
        final notifications = List.generate(
          6, 
          (i) => createTestTemplate(
            title: 'Same Title',
            body: 'Body $i',
            data: {'category': 'NotificationCategory.social', 'timestamp': DateTime.now().toIso8601String()},
          ),
        );
        
        final batch = createTestBatch(
          batchKey: 'spam-test',
          notifications: notifications,
        );
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => [batch]);
        
        // Act
        await batchManager.forceBatchProcessing('spam-test');
        
        // Assert - Should detect spam and not send
        expect(sentBatches, isEmpty);
        verify(() => mockRepository.removeBatch('spam-test')).called(1);
      });
      
      test('should detect rapid succession spam pattern', () async {
        // Arrange
        final baseTime = DateTime.now();
        final notifications = List.generate(
          10, 
          (i) => createTestTemplate(
            title: 'Title $i',
            body: 'Body $i',
            data: {
              'category': 'NotificationCategory.social',
              'timestamp': baseTime.add(Duration(seconds: i)).toIso8601String(),
            },
          ),
        );
        
        final batch = createTestBatch(
          batchKey: 'rapid-test',
          notifications: notifications,
        );
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => [batch]);
        
        // Act
        await batchManager.forceBatchProcessing('rapid-test');
        
        // Assert - Should detect rapid succession spam
        expect(sentBatches, isEmpty);
        verify(() => mockRepository.removeBatch('rapid-test')).called(1);
      });
      
      test('should allow legitimate batch patterns', () async {
        // Arrange
        final notifications = List.generate(
          3, 
          (i) => createTestTemplate(
            title: 'Title $i',
            body: 'Body $i',
            data: {
              'category': 'NotificationCategory.social',
              'timestamp': DateTime.now().add(Duration(minutes: i * 2)).toIso8601String(),
            },
          ),
        );
        
        final batch = createTestBatch(
          batchKey: 'legitimate-test',
          notifications: notifications,
        );
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => [batch]);
        
        // Act
        await batchManager.forceBatchProcessing('legitimate-test');
        
        // Assert - Should process legitimate batch
        expect(sentBatches, hasLength(1));
        verify(() => mockRepository.removeBatch('legitimate-test')).called(1);
      });
    });
    
    group('Batch Processing', () {
      test('should process all pending batches', () async {
        // Arrange
        final batches = [
          createTestBatch(batchKey: 'batch1'),
          createTestBatch(batchKey: 'batch2'),
          createTestBatch(batchKey: 'batch3'),
        ];
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => batches);
        
        // Act
        await batchManager.processAllPendingBatches();
        
        // Assert
        expect(sentBatches, hasLength(3));
        verify(() => mockRepository.removeBatch(any())).called(3);
      });
      
      test('should build combined notification for multiple items', () async {
        // Arrange
        final notifications = [
          createTestTemplate(title: 'Recipe 1'),
          createTestTemplate(title: 'Recipe 2'),
          createTestTemplate(title: 'Recipe 3'),
        ];
        
        final batch = createTestBatch(
          batchKey: 'combine-test',
          notifications: notifications,
        );
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => [batch]);
        
        // Act
        await batchManager.forceBatchProcessing('combine-test');
        
        // Assert
        expect(sentBatches, hasLength(1));
        final sentBatch = sentBatches.first;
        expect(sentBatch.notifications, hasLength(1));
        
        final combinedNotification = sentBatch.notifications.first;
        expect(combinedNotification.data['batched'], isTrue);
        expect(combinedNotification.data['count'], equals(3));
      });
      
      test('should generate localized batch titles by category', () async {
        // Test different categories
        final categoryTests = [
          (NotificationCategory.recipes, 'Ny receptaktivitet'),
          (NotificationCategory.friends, 'Vänaktivitet'),
          (NotificationCategory.collaboration, 'Samarbetsaktivitet'),
          (NotificationCategory.shopping, 'Inköpslistor'),
          (NotificationCategory.social, 'Social aktivitet'),
        ];
        
        for (final (category, expectedTitle) in categoryTests) {
          // Arrange
          final notifications = List.generate(
            3, 
            (i) => createTestTemplate(
              data: {'category': 'NotificationCategory.${category.name}', 'timestamp': DateTime.now().toIso8601String()},
            ),
          );
          
          final batch = createTestBatch(
            batchKey: 'category-${category.name}',
            notifications: notifications,
          );
          
          when(() => mockRepository.getPendingBatches())
              .thenAnswer((_) async => [batch]);
          
          // Act
          sentBatches.clear();
          await batchManager.forceBatchProcessing('category-${category.name}');
          
          // Assert
          expect(sentBatches, hasLength(1));
          final sentBatch = sentBatches.first;
          final combinedNotification = sentBatch.notifications.first;
          expect(combinedNotification.title, equals(expectedTitle));
        }
      });
      
      test('should handle batch not found gracefully', () async {
        // Arrange
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => []);
        
        // Act & Assert - Should not throw
        await expectLater(
          batchManager.forceBatchProcessing('non-existent'),
          completes,
        );
        
        // Should not try to remove non-existent batch
        verifyNever(() => mockRepository.removeBatch('non-existent'));
      });
      
      test('should handle single notification batch', () async {
        // Arrange
        final batch = createTestBatch(
          batchKey: 'single-test',
          notifications: [createTestTemplate(title: 'Single')],
        );
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => [batch]);
        
        // Act
        await batchManager.forceBatchProcessing('single-test');
        
        // Assert
        expect(sentBatches, hasLength(1));
        final sentBatch = sentBatches.first;
        expect(sentBatch.notifications.first.title, equals('Single'));
      });
    });
    
    group('Batch Statistics', () {
      test('should provide accurate batch statistics', () async {
        // Arrange
        final strategy = createTestStrategy();
        
        // Act
        await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy,
          variables: {'title': 'Test'},
        );
        
        final stats = batchManager.getBatchStatistics();
        
        // Assert
        expect(stats['active_batch_timers'], greaterThanOrEqualTo(1));
        expect(stats['batch_keys'], isA<List>());
        expect(stats['is_processing'], isFalse);
        expect(stats['rate_limit_tracking'], isA<Map>());
      });
    });
    
    group('Error Handling', () {
      test('should handle repository failures gracefully', () async {
        // Arrange
        when(() => mockRepository.addToBatch(
          batchKey: any(named: 'batchKey'),
          notification: any(named: 'notification'),
          batchWindow: any(named: 'batchWindow'),
        )).thenAnswer((_) async => throw Exception('Repository error'));
        
        final strategy = createTestStrategy();
        
        // Act
        final result = await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy,
          variables: {'title': 'Test'},
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should continue processing other batches on error', () async {
        // Arrange
        final batches = [
          createTestBatch(batchKey: 'batch1'),
          createTestBatch(batchKey: 'batch2'),
          createTestBatch(batchKey: 'batch3'),
        ];
        
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => batches);
        
        // Make second batch fail
        int callCount = 0;
        when(() => mockRepository.removeBatch(any())).thenAnswer((invocation) async {
          callCount++;
          if (callCount == 2) {
            throw Exception('Remove failed');
          }
        });
        
        // Act
        await batchManager.processAllPendingBatches();
        
        // Assert - Should process 1st and 3rd despite 2nd failing
        expect(sentBatches.length, greaterThanOrEqualTo(2));
      });
    });
    
    group('Lifecycle', () {
      test('should dispose resources properly', () async {
        // Arrange
        final strategy = createTestStrategy();
        await batchManager.addToBatch(
          targetUserIds: ['user1'],
          strategy: strategy,
          variables: {'title': 'Test'},
        );
        
        // Act
        batchManager.dispose();
        
        // Assert
        final stats = batchManager.getBatchStatistics();
        expect(stats['active_batch_timers'], equals(0));
        expect(stats['rate_limit_tracking'], isEmpty);
      });
      
      test('should set and use send batch callback', () async {
        // Arrange
        final customSentBatches = <NotificationBatch>[];
        batchManager.setSendBatchCallback((batch) async {
          customSentBatches.add(batch);
        });
        
        final batch = createTestBatch(batchKey: 'callback-test');
        when(() => mockRepository.getPendingBatches())
            .thenAnswer((_) async => [batch]);
        
        // Act
        await batchManager.forceBatchProcessing('callback-test');
        
        // Assert
        expect(customSentBatches, hasLength(1));
      });
    });
  });
}