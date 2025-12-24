// test/unit/viewmodels/realtime_menu/realtime_stream_manager_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_stream_manager.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';

import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeStreamManager - Ultrathink Enhanced Tests', () {
    late RealtimeStreamManager streamManager;
    late MockRealtimeMenuService mockMenuService;

    // Callback tracking variables
    late List<RealtimeMenu> menuUpdates;
    late List<dynamic> menuErrors;
    late List<String> streamEvents; // 'started', 'stopped'

    // Test data
    const testMenuId = 'menu_123';
    const testMenuId2 = 'menu_456';
    late RealtimeMenu testMenu;
    late StreamController<RealtimeMenu> mockStreamController;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(RealtimeMenu(
        id: 'fallback_menu',
        ownerId: 'fallback_owner',
        ownerDisplayName: 'Fallback Owner',
        participants: {},
        lastEditedBy: 'fallback_owner',
        lastEditedByDisplayName: 'Fallback Owner',
        data: RealtimeMenuData(
          menuTitle: 'Fallback Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        ),
      ));
    });

    setUp(() {
      mockMenuService = MockFactory.createRealtimeMenuService();
      menuUpdates = [];
      menuErrors = [];
      streamEvents = [];
      mockStreamController = StreamController<RealtimeMenu>.broadcast();

      // Create test data
      testMenu = RealtimeMenu(
        id: testMenuId,
        ownerId: 'test_owner',
        ownerDisplayName: 'Test Owner',
        participants: {},
        lastEditedBy: 'test_owner',
        lastEditedByDisplayName: 'Test Owner',
        data: RealtimeMenuData(
          menuTitle: 'Test Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        ),
      );

      // Configure default service behavior using ultrathink state configuration
      when(() => mockMenuService.watchRealtimeMenu(any()))
          .thenAnswer((_) => mockStreamController.stream);

      // Create stream manager with callback injection (ultrathink approach)
      streamManager = RealtimeStreamManager(
        menuService: mockMenuService,
        onMenuUpdated: (menu) => menuUpdates.add(menu),
        onMenuError: (error) => menuErrors.add(error),
        onStreamStarted: () => streamEvents.add('started'),
        onStreamStopped: () => streamEvents.add('stopped'),
      );
    });

    tearDown(() async {
      await streamManager.dispose();
      await mockStreamController.close();
    });

    group('Initialization and Basic Properties', () {
      test('should initialize with correct default state', () {
        // Assert
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.currentMenuId, isNull);
        expect(streamManager.hasActiveSubscription, isFalse);
      });

      test('should initialize with injected dependencies', () {
        // Assert - No service calls should happen during construction
        verifyNever(() => mockMenuService.watchRealtimeMenu(any()));
      });

      test('should provide correct stream state getters', () {
        // Assert - Default state
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.currentMenuId, isNull);
        expect(streamManager.hasActiveSubscription, isFalse);
        expect(streamManager.isStreamHealthy(), isFalse);
      });

      test('should return correct connection statistics for initial state', () {
        // Act
        final stats = streamManager.getConnectionStats();

        // Assert
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isFalse);
        expect(stats['currentMenuId'], isNull);
        expect(stats['isHealthy'], isFalse);
      });
    });

    group('Stream Operations - Start Watching', () {
      test('should start watching successfully', () async {
        // Act
        await streamManager.startWatching(testMenuId);

        // Assert
        expect(streamManager.isStreaming, isTrue);
        expect(streamManager.currentMenuId, equals(testMenuId));
        expect(streamManager.hasActiveSubscription, isTrue);
        expect(streamEvents, contains('started'));
        verify(() => mockMenuService.watchRealtimeMenu(testMenuId)).called(1);
      });

      test('should handle menu updates correctly', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        mockStreamController.add(testMenu);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(menuUpdates, hasLength(1));
        expect(menuUpdates.first.id, equals(testMenuId));
        expect(menuUpdates.first.menuTitle, equals('Test Menu'));
      });

      test('should not start watching with same menu ID if already streaming',
          () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamEvents.clear();

        // Act
        await streamManager.startWatching(testMenuId);

        // Assert
        expect(streamEvents, isEmpty); // No additional started events
        verify(() => mockMenuService.watchRealtimeMenu(testMenuId))
            .called(1); // Only called once
      });

      test('should switch to new menu ID when already streaming different menu',
          () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamEvents.clear();

        // Act
        await streamManager.startWatching(testMenuId2);

        // Assert
        expect(streamManager.currentMenuId, equals(testMenuId2));
        expect(streamEvents, contains('stopped')); // Old stream stopped
        expect(streamEvents, contains('started')); // New stream started
        verify(() => mockMenuService.watchRealtimeMenu(testMenuId2)).called(1);
      });

      test('should handle stream service exceptions gracefully', () async {
        // Arrange
        when(() => mockMenuService.watchRealtimeMenu(testMenuId))
            .thenThrow(Exception('Network error'));

        // Act & Assert
        await expectLater(
          streamManager.startWatching(testMenuId),
          throwsA(isA<Exception>()),
        );

        // Verify cleanup happened
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.currentMenuId, isNull);
        expect(streamManager.hasActiveSubscription, isFalse);
      });
    });

    group('Stream Operations - Stop Watching', () {
      test('should stop watching successfully', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamEvents.clear();

        // Act
        await streamManager.stopWatching();

        // Assert
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.currentMenuId, isNull);
        expect(streamManager.hasActiveSubscription, isFalse);
        expect(streamEvents, contains('stopped'));
      });

      test('should not stop watching if not currently streaming', () async {
        // Act
        await streamManager.stopWatching();

        // Assert
        expect(streamEvents, isEmpty); // No stopped events
      });

      test('should cleanup resources on stop', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        await streamManager.stopWatching();

        // Assert
        final stats = streamManager.getConnectionStats();
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isFalse);
        expect(stats['currentMenuId'], isNull);
        expect(stats['isHealthy'], isFalse);
      });
    });

    group('Stream Operations - Pause and Resume', () {
      test('should pause streaming correctly', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        streamManager.pauseStreaming();

        // Assert
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.hasActiveSubscription,
            isTrue); // Subscription still active
        expect(streamManager.currentMenuId, equals(testMenuId));
      });

      test('should resume streaming correctly', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamManager.pauseStreaming();

        // Act
        streamManager.resumeStreaming();

        // Assert
        expect(streamManager.isStreaming, isTrue);
        expect(streamManager.hasActiveSubscription, isTrue);
        expect(streamManager.currentMenuId, equals(testMenuId));
      });

      test('should ignore menu updates when paused', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamManager.pauseStreaming();
        menuUpdates.clear();

        // Act
        mockStreamController.add(testMenu);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(menuUpdates, isEmpty); // Updates ignored while paused
      });

      test('should process menu updates after resume', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamManager.pauseStreaming();
        streamManager.resumeStreaming();
        menuUpdates.clear();

        // Act
        mockStreamController.add(testMenu);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(menuUpdates, hasLength(1));
      });

      test('should not pause if not streaming', () async {
        // Act
        streamManager.pauseStreaming();

        // Assert
        expect(streamManager.isStreaming, isFalse); // Should remain false
      });

      test('should not resume if no active subscription', () async {
        // Act
        streamManager.resumeStreaming();

        // Assert
        expect(streamManager.isStreaming, isFalse);
      });
    });

    group('Connection Management', () {
      test('should report healthy stream when active', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Assert
        expect(streamManager.isStreamHealthy(), isTrue);
      });

      test('should report unhealthy stream when paused', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamManager.pauseStreaming();

        // Assert
        expect(streamManager.isStreamHealthy(), isFalse);
      });

      test('should restart stream successfully', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamEvents.clear();

        // Act
        await streamManager.restartStream();

        // Assert
        expect(streamManager.currentMenuId, equals(testMenuId));
        expect(streamEvents, contains('stopped'));
        expect(streamEvents, contains('started'));
        verify(() => mockMenuService.watchRealtimeMenu(testMenuId))
            .called(2); // Original + restart
      });

      test('should not restart stream if no menu ID', () async {
        // Act
        await streamManager.restartStream();

        // Assert
        expect(streamEvents, isEmpty);
        verifyNever(() => mockMenuService.watchRealtimeMenu(any()));
      });

      test('should force reconnect successfully', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamEvents.clear();

        // Act
        await streamManager.forceReconnect();

        // Assert
        expect(streamManager.isStreaming, isTrue);
        expect(streamEvents, contains('stopped'));
        expect(streamEvents, contains('started'));
      });

      test('should handle force reconnect with no active menu', () async {
        // Act
        await streamManager.forceReconnect();

        // Assert
        expect(streamEvents, isEmpty);
        verifyNever(() => mockMenuService.watchRealtimeMenu(any()));
      });
    });

    group('Stream Event Handling', () {
      test('should handle stream errors correctly', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        final testError = Exception('Stream error');
        mockStreamController.addError(testError);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(menuErrors, hasLength(1));
        expect(menuErrors.first, equals(testError));
      });

      test('should handle stream completion', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamEvents.clear();

        // Act
        await mockStreamController.close();
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(streamManager.isStreaming, isFalse);
        expect(streamEvents, contains('stopped'));
      });

      test('should handle multiple rapid menu updates', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        final menu1 = RealtimeMenu(
          id: testMenuId,
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
          participants: {},
          lastEditedBy: 'owner',
          lastEditedByDisplayName: 'Owner',
          data: RealtimeMenuData(
              menuTitle: 'Menu 1',
              createdForDate: DateTime.now(),
              menuSnapshot: {}),
        );
        final menu2 = RealtimeMenu(
          id: testMenuId,
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
          participants: {},
          lastEditedBy: 'owner',
          lastEditedByDisplayName: 'Owner',
          data: RealtimeMenuData(
              menuTitle: 'Menu 2',
              createdForDate: DateTime.now(),
              menuSnapshot: {}),
        );
        final menu3 = RealtimeMenu(
          id: testMenuId,
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
          participants: {},
          lastEditedBy: 'owner',
          lastEditedByDisplayName: 'Owner',
          data: RealtimeMenuData(
              menuTitle: 'Menu 3',
              createdForDate: DateTime.now(),
              menuSnapshot: {}),
        );

        // Act
        mockStreamController.add(menu1);
        mockStreamController.add(menu2);
        mockStreamController.add(menu3);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(menuUpdates, hasLength(3));
        expect(menuUpdates[0].menuTitle, equals('Menu 1'));
        expect(menuUpdates[1].menuTitle, equals('Menu 2'));
        expect(menuUpdates[2].menuTitle, equals('Menu 3'));
      });
    });

    group('Stream Validation', () {
      test('should validate menu ID correctly - valid ID', () {
        // Act & Assert
        expect(streamManager.validateMenuId(testMenuId), isTrue);
        expect(streamManager.validateMenuId('valid_id'), isTrue);
      });

      test('should validate menu ID correctly - invalid IDs', () {
        // Act & Assert
        expect(streamManager.validateMenuId(null), isFalse);
        expect(streamManager.validateMenuId(''), isFalse);
        expect(streamManager.validateMenuId('   '), isFalse);
      });

      test('should check if can start streaming - valid scenarios', () {
        // Act & Assert
        expect(streamManager.canStartStreaming(testMenuId), isTrue);
      });

      test('should check if can start streaming - invalid menu ID', () {
        // Act & Assert
        expect(streamManager.canStartStreaming(''), isFalse);
        expect(streamManager.canStartStreaming('   '), isFalse);
      });

      test('should allow restart of same menu', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act & Assert
        expect(streamManager.canStartStreaming(testMenuId), isTrue);
      });
    });

    group('Stream Statistics and Diagnostics', () {
      test('should provide accurate connection statistics - not streaming', () {
        // Act
        final stats = streamManager.getConnectionStats();

        // Assert
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isFalse);
        expect(stats['currentMenuId'], isNull);
        expect(stats['isHealthy'], isFalse);
      });

      test('should provide accurate connection statistics - streaming',
          () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        final stats = streamManager.getConnectionStats();

        // Assert
        expect(stats['isStreaming'], isTrue);
        expect(stats['hasSubscription'], isTrue);
        expect(stats['currentMenuId'], equals(testMenuId));
        expect(stats['isHealthy'], isTrue);
      });

      test('should provide accurate connection statistics - paused', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);
        streamManager.pauseStreaming();

        // Act
        final stats = streamManager.getConnectionStats();

        // Assert
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isTrue);
        expect(stats['currentMenuId'], equals(testMenuId));
        expect(stats['isHealthy'], isFalse);
      });

      test('should handle stream duration (not implemented)', () {
        // Act
        final duration = streamManager.getStreamDuration();

        // Assert
        expect(duration, isNull); // Not implemented yet
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle null menu updates gracefully', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act - Stream controller doesn't allow null, so test error scenario instead
        mockStreamController.addError('Null data received');
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert
        expect(menuErrors, hasLength(1));
        expect(menuErrors.first, equals('Null data received'));
      });

      test('should handle subscription cancellation errors gracefully',
          () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act - Force close controller to trigger cancellation
        await mockStreamController.close();
        await streamManager.stopWatching();

        // Assert - should not throw
        expect(streamManager.isStreaming, isFalse);
      });

      test('should handle rapid start/stop operations', () async {
        // Act - Multiple rapid operations
        await streamManager.startWatching(testMenuId);
        await streamManager.stopWatching();
        await streamManager.startWatching(testMenuId2);
        await streamManager.stopWatching();

        // Assert - Should end in clean state
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.currentMenuId, isNull);
        expect(streamManager.hasActiveSubscription, isFalse);
      });

      test('should handle concurrent stream operations', () async {
        // Act - Concurrent operations
        final future1 = streamManager.startWatching(testMenuId);
        final future2 = streamManager.startWatching(testMenuId2);

        await Future.wait([future1, future2]);

        // Assert - Should end with last operation
        expect(streamManager.currentMenuId, equals(testMenuId2));
        expect(streamManager.isStreaming, isTrue);
      });
    });

    group('Lifecycle and Disposal', () {
      test('should dispose without throwing', () async {
        // Act & Assert
        await expectLater(streamManager.dispose(), completes);
      });

      test('should cleanup resources on disposal', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        await streamManager.dispose();

        // Assert
        expect(streamManager.isStreaming, isFalse);
        expect(streamManager.currentMenuId, isNull);
        expect(streamManager.hasActiveSubscription, isFalse);
      });

      test('should handle disposal during active streaming', () async {
        // Arrange
        await streamManager.startWatching(testMenuId);

        // Act
        await streamManager.dispose();

        // Assert - should not throw and should clean up
        expect(streamManager.isStreaming, isFalse);
      });

      test('should handle multiple disposal calls gracefully', () async {
        // Act & Assert
        await streamManager.dispose();
        await expectLater(streamManager.dispose(), completes);
      });
    });
  });
}
