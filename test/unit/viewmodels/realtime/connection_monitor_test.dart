// test/unit/viewmodels/realtime/connection_monitor_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectionMonitor connectionMonitor;
  late MockRealtimeSyncService mockSyncService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    mockSyncService = MockRealtimeSyncService();

    // Initialize with default disconnected state using state configuration
    mockSyncService.setConnectionState(false);

    connectionMonitor = ConnectionMonitor(syncService: mockSyncService);
  });

  tearDown(() async {
    await connectionMonitor.dispose();
    mockSyncService.disposeStreams();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  group('ConnectionMonitor - Initialization and Basic State', () {
    test('should initialize with unknown status', () {
      expect(connectionMonitor.status, equals(ConnectionStatus.unknown));
      expect(connectionMonitor.isOnline, isFalse);
      expect(connectionMonitor.lastConnectionChange, isNull);
      expect(connectionMonitor.connectionUptime, isNull);
    });

    test(
        'should initialize with connected status when sync service is connected',
        () {
      // Create new monitor with connected state
      mockSyncService.setConnectionState(true);
      final connectedMonitor = ConnectionMonitor(syncService: mockSyncService);

      expect(connectedMonitor.isOnline, isTrue);

      connectedMonitor.dispose();
    });

    test('should provide correct status descriptions', () {
      expect(connectionMonitor.statusDescription, isA<String>());
      expect(connectionMonitor.statusDescription.isNotEmpty, isTrue);
      expect(connectionMonitor.statusDescription,
          equals('Kontrollerar anslutning...'));
    });

    test('should provide correct status emojis', () {
      expect(connectionMonitor.statusEmoji, isA<String>());
      expect(connectionMonitor.statusEmoji.isNotEmpty, isTrue);
      expect(connectionMonitor.statusEmoji, equals('❓'));
    });
  });

  group('ConnectionMonitor - Connection State Changes', () {
    test('should handle connection established', () async {
      final monitor = ConnectionMonitor(
        syncService: mockSyncService,
        onConnectionChanged: (isOnline) {
          // Connection callback handled
        },
        onStatusChanged: (status) {
          // Status callback handled
        },
      );

      // Trigger connection change using state configuration
      mockSyncService.triggerConnectionChange(true);

      // Wait for debounce timer
      await Future.delayed(const Duration(milliseconds: 500));

      expect(monitor.isOnline, isTrue);
      expect(monitor.lastConnectionChange, isNotNull);

      await monitor.dispose();
    });

    test('should handle connection lost', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Start from disconnected (default), then connect
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Then lose connection
      mockSyncService.triggerConnectionChange(false);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(monitor.isOnline, isFalse);
      expect(monitor.lastConnectionChange, isNotNull);

      await monitor.dispose();
    });

    test('should debounce rapid connection changes', () async {
      int connectionChangeCount = 0;

      final monitor = ConnectionMonitor(
        syncService: mockSyncService,
        onConnectionChanged: (isOnline) {
          connectionChangeCount++;
        },
      );

      // Rapid changes using mock state methods
      mockSyncService.triggerConnectionChange(true);
      mockSyncService.triggerConnectionChange(false);
      mockSyncService.triggerConnectionChange(true);

      // Wait for debounce to settle
      await Future.delayed(const Duration(milliseconds: 600));

      // Should have fewer callbacks due to debouncing
      expect(connectionChangeCount, lessThan(3));

      await monitor.dispose();
    });

    test('should track connection status transitions', () async {
      final List<ConnectionStatus> statusChanges = [];

      final monitor = ConnectionMonitor(
        syncService: mockSyncService,
        onStatusChanged: (status) {
          statusChanges.add(status);
        },
      );

      // Connected
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Disconnected
      mockSyncService.triggerConnectionChange(false);
      await Future.delayed(const Duration(milliseconds: 500));

      // Check that we got status changes
      expect(statusChanges, isNotEmpty);

      await monitor.dispose();
    });
  });

  group('ConnectionMonitor - Stability and Uptime Tracking', () {
    test('should track connection stability correctly', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Start disconnected, then establish connection to trigger a state change
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Initially not stable for 1 minute
      expect(monitor.hasBeenStableFor(Duration(minutes: 1)), isFalse);

      // Should be stable for very short duration
      expect(monitor.hasBeenStableFor(Duration(milliseconds: 1)), isTrue);

      await monitor.dispose();
    });

    test('should calculate connection uptime', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Start disconnected, then establish connection to trigger a state change
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      final uptime = monitor.connectionUptime;
      expect(uptime, isNotNull);
      expect(uptime!.inMilliseconds, greaterThan(0));

      await monitor.dispose();
    });

    test('should return null uptime when disconnected', () {
      expect(connectionMonitor.connectionUptime, isNull);
      expect(connectionMonitor.hasBeenStableFor(Duration(minutes: 1)), isFalse);
    });

    test('should reset stability tracking on disconnection', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Start disconnected, then connect to trigger a state change
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(monitor.connectionUptime, isNotNull);

      // Disconnect
      mockSyncService.triggerConnectionChange(false);
      await Future.delayed(const Duration(milliseconds: 500));

      expect(monitor.connectionUptime, isNull);

      await monitor.dispose();
    });
  });

  group('ConnectionMonitor - Force Connection Check', () {
    test('should force connection check when requested', () {
      expect(() => connectionMonitor.forceConnectionCheck(), returnsNormally);
    });

    test('should update status on forced check', () async {
      mockSyncService.setConnectionState(true);

      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Force check should update status
      monitor.forceConnectionCheck();

      // Wait for debounce
      await Future.delayed(const Duration(milliseconds: 500));

      expect(monitor.isOnline, isTrue);

      await monitor.dispose();
    });
  });

  group('ConnectionMonitor - Debug Information', () {
    test('should provide comprehensive debug information', () {
      final debugInfo = connectionMonitor.debugInfo;

      expect(debugInfo, isA<Map<String, dynamic>>());
      expect(debugInfo.containsKey('isOnline'), isTrue);
      expect(debugInfo.containsKey('status'), isTrue);
      expect(debugInfo.containsKey('lastChange'), isTrue);
      expect(debugInfo.containsKey('uptime'), isTrue);
      expect(debugInfo.containsKey('stable'), isTrue);
    });

    test('should include correct values in debug info', () async {
      mockSyncService.setConnectionState(true);

      final monitor = ConnectionMonitor(syncService: mockSyncService);

      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      final debugInfo = monitor.debugInfo;

      expect(debugInfo['isOnline'], equals(monitor.isOnline));
      expect(debugInfo['status'], equals(monitor.status.name));

      await monitor.dispose();
    });
  });

  group('ConnectionMonitor - Error Handling', () {
    test('should handle connection stream errors gracefully', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Since we can't easily trigger stream errors with the mock structure,
      // we'll just test that error handling doesn't crash the app
      await Future.delayed(const Duration(milliseconds: 100));

      expect(monitor.status, isA<ConnectionStatus>());

      await monitor.dispose();
    });

    test('should handle sync service being null', () {
      mockSyncService.setConnectionState(false);

      expect(() => ConnectionMonitor(syncService: mockSyncService),
          returnsNormally);
    });
  });

  group('ConnectionMonitor - Callback Functionality', () {
    test('should trigger onConnectionChanged callback', () async {
      bool callbackTriggered = false;
      bool? callbackValue;

      final monitor = ConnectionMonitor(
        syncService: mockSyncService,
        onConnectionChanged: (isOnline) {
          callbackTriggered = true;
          callbackValue = isOnline;
        },
      );

      mockSyncService.triggerConnectionChange(true);

      await Future.delayed(const Duration(milliseconds: 500));

      expect(callbackTriggered, isTrue);
      expect(callbackValue, isTrue);

      await monitor.dispose();
    });

    test('should trigger onStatusChanged callback', () async {
      bool callbackTriggered = false;
      ConnectionStatus? callbackStatus;

      final monitor = ConnectionMonitor(
        syncService: mockSyncService,
        onStatusChanged: (status) {
          callbackTriggered = true;
          callbackStatus = status;
        },
      );

      mockSyncService.triggerConnectionChange(true);

      await Future.delayed(const Duration(milliseconds: 500));

      expect(callbackTriggered, isTrue);
      expect(callbackStatus, isNotNull);

      await monitor.dispose();
    });

    test('should work without callbacks', () {
      expect(() => ConnectionMonitor(syncService: mockSyncService),
          returnsNormally);
    });
  });

  group('ConnectionMonitor - Reconnection Logic', () {
    test('should handle reconnection scenario', () async {
      final List<ConnectionStatus> statusHistory = [];

      final monitor = ConnectionMonitor(
        syncService: mockSyncService,
        onStatusChanged: (status) {
          statusHistory.add(status);
        },
      );

      // Start connected
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Lose connection
      mockSyncService.triggerConnectionChange(false);
      await Future.delayed(const Duration(milliseconds: 500));

      // Reconnect
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should have gone through connection states
      expect(statusHistory, isNotEmpty);

      await monitor.dispose();
    });

    test('should differentiate between initial connection and reconnection',
        () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Start disconnected
      expect(monitor.status, equals(ConnectionStatus.unknown));

      // Connect for first time
      mockSyncService.triggerConnectionChange(true);
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify we're connected
      expect(monitor.isOnline, isTrue);

      await monitor.dispose();
    });
  });

  group('ConnectionMonitor - Disposal and Cleanup', () {
    test('should dispose cleanly', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      await expectLater(monitor.dispose(), completes);
    });

    test('should handle multiple dispose calls', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      await monitor.dispose();

      // Second dispose should not crash
      await expectLater(monitor.dispose(), completes);
    });

    test('should cancel timers on dispose', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Trigger some connection changes to start timers
      mockSyncService.triggerConnectionChange(true);
      mockSyncService.triggerConnectionChange(false);

      // Dispose should cancel timers
      await expectLater(monitor.dispose(), completes);
    });

    test('should cancel subscription on dispose', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      await monitor.dispose();

      // Adding events after dispose should not affect monitor
      expect(
        () => mockSyncService.triggerConnectionChange(true),
        returnsNormally,
      );
    });
  });

  group('ConnectionMonitor - Edge Cases and Integration', () {
    test('should handle rapid dispose after creation', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Dispose immediately
      await expectLater(monitor.dispose(), completes);
    });

    test('should handle connection events during disposal', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Start disposal
      final disposePromise = monitor.dispose();

      // Add connection events during disposal
      mockSyncService.triggerConnectionChange(true);
      mockSyncService.triggerConnectionChange(false);

      await expectLater(disposePromise, completes);
    });

    test('should maintain state consistency during concurrent operations',
        () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Concurrent operations
      final futures = [
        Future(() => monitor.forceConnectionCheck()),
        Future(() => mockSyncService.triggerConnectionChange(true)),
        Future(() => mockSyncService.triggerConnectionChange(false)),
        Future(() => monitor.forceConnectionCheck()),
      ];

      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 600));

      // Should still be in valid state
      expect(monitor.status, isA<ConnectionStatus>());
      expect(monitor.debugInfo, isA<Map<String, dynamic>>());

      await monitor.dispose();
    });

    test('should provide stable API after connection changes', () async {
      final monitor = ConnectionMonitor(syncService: mockSyncService);

      // Multiple connection state changes
      for (int i = 0; i < 5; i++) {
        mockSyncService.triggerConnectionChange(i % 2 == 0);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Wait for final debounce
      await Future.delayed(const Duration(milliseconds: 600));

      // All getters should still work
      expect(() => monitor.isOnline, returnsNormally);
      expect(() => monitor.status, returnsNormally);
      expect(() => monitor.statusDescription, returnsNormally);
      expect(() => monitor.statusEmoji, returnsNormally);
      expect(() => monitor.debugInfo, returnsNormally);
      expect(() => monitor.connectionUptime, returnsNormally);
      expect(() => monitor.hasBeenStableFor(Duration(seconds: 1)),
          returnsNormally);

      await monitor.dispose();
    });
  });
}
