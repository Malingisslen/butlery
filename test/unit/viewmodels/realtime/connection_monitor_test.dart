import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:mocktail/mocktail.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Local mock: centralized MockRealtimeSyncService lacks connectionStream override.
class _MockSyncService extends Mock implements RealtimeSyncService {
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  bool _connected = false;

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnected => _connected;

  void setConnectionState(bool connected) {
    _connected = connected;
  }

  void triggerConnectionChange(bool connected) {
    _connected = connected;
    _connectionController.add(connected);
  }

  @override
  Future<void> dispose() async {
    _connectionController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSyncService mockSyncService;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() {
    mockSyncService = _MockSyncService();
    mockSyncService.setConnectionState(false);
  });

  tearDown(() {
    mockSyncService.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  group('Initialization and Basic State', () {
    test('should initialize with unknown status', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        // Initial status is unknown before debounce fires
        expect(monitor.status, equals(ConnectionStatus.unknown));
        expect(monitor.lastConnectionChange, isNull);
        expect(monitor.connectionUptime, isNull);

        // Let debounce timer fire (350ms)
        async.elapse(const Duration(milliseconds: 400));

        monitor.dispose();
      });
    });

    test('should initialize as connected when service reports connected', () {
      fakeAsync((async) {
        mockSyncService.setConnectionState(true);
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        // Let debounce settle
        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.isOnline, isTrue);
        expect(monitor.status, equals(ConnectionStatus.connected));

        monitor.dispose();
      });
    });

    test('should provide status descriptions and emojis', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        expect(monitor.statusDescription, isA<String>());
        expect(monitor.statusDescription.isNotEmpty, isTrue);
        expect(monitor.statusEmoji, equals('❓'));

        monitor.dispose();
        async.elapse(const Duration(milliseconds: 400));
      });
    });
  });

  group('Connection State Changes', () {
    test('should handle connection established', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.isOnline, isTrue);
        expect(monitor.lastConnectionChange, isNotNull);

        monitor.dispose();
      });
    });

    test('should handle connection lost', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        // Connect
        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));
        expect(monitor.isOnline, isTrue);

        // Disconnect
        mockSyncService.triggerConnectionChange(false);
        async.elapse(const Duration(milliseconds: 400));
        expect(monitor.isOnline, isFalse);
        expect(monitor.lastConnectionChange, isNotNull);

        monitor.dispose();
      });
    });

    test('should debounce rapid connection changes', () {
      fakeAsync((async) {
        int changeCount = 0;
        final monitor = ConnectionMonitor(
          syncService: mockSyncService,
          onConnectionChanged: (_) => changeCount++,
        );
        async.elapse(const Duration(milliseconds: 400));

        // Rapid flapping
        mockSyncService.triggerConnectionChange(true);
        mockSyncService.triggerConnectionChange(false);
        mockSyncService.triggerConnectionChange(true);

        async.elapse(const Duration(milliseconds: 400));

        // Debounce means fewer callbacks than raw events
        expect(changeCount, lessThanOrEqualTo(2));

        monitor.dispose();
      });
    });

    test('should track status transitions via callback', () {
      fakeAsync((async) {
        final statusChanges = <ConnectionStatus>[];
        final monitor = ConnectionMonitor(
          syncService: mockSyncService,
          onStatusChanged: (s) => statusChanges.add(s),
        );
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(false);
        async.elapse(const Duration(milliseconds: 400));

        expect(statusChanges, isNotEmpty);

        monitor.dispose();
      });
    });
  });

  group('Stability and Uptime Tracking', () {
    test('should track stability correctly', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        mockSyncService.triggerConnectionChange(true);
        // Let the 350ms debounce timer fire (virtual clock).
        async.elapse(const Duration(milliseconds: 500));

        // Not stable for 1 minute (just connected)
        expect(monitor.hasBeenStableFor(const Duration(minutes: 1)), isFalse);

        // hasBeenStableFor(Duration.zero) should be true once connected
        expect(monitor.hasBeenStableFor(Duration.zero), isTrue);

        monitor.dispose();
      });
    });

    test('should calculate connection uptime', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 500));

        // Once connected, uptime should be non-null
        final uptime = monitor.connectionUptime;
        expect(uptime, isNotNull);
        expect(uptime!.inMicroseconds, greaterThanOrEqualTo(0));

        monitor.dispose();
      });
    });

    test('should return null uptime when disconnected', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.connectionUptime, isNull);
        expect(monitor.hasBeenStableFor(const Duration(minutes: 1)), isFalse);

        monitor.dispose();
      });
    });

    test('should reset uptime on disconnection', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));
        expect(monitor.connectionUptime, isNotNull);

        mockSyncService.triggerConnectionChange(false);
        async.elapse(const Duration(milliseconds: 400));
        expect(monitor.connectionUptime, isNull);

        monitor.dispose();
      });
    });
  });

  group('Force Connection Check', () {
    test('should force connection check without error', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        expect(() => monitor.forceConnectionCheck(), returnsNormally);

        monitor.dispose();
      });
    });

    test('should update status on forced check', () {
      fakeAsync((async) {
        mockSyncService.setConnectionState(true);
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        monitor.forceConnectionCheck();
        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.isOnline, isTrue);

        monitor.dispose();
      });
    });
  });

  group('Debug Information', () {
    test('should provide comprehensive debug info', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        final info = monitor.debugInfo;
        expect(info, isA<Map<String, dynamic>>());
        expect(info.containsKey('isOnline'), isTrue);
        expect(info.containsKey('status'), isTrue);
        expect(info.containsKey('lastChange'), isTrue);
        expect(info.containsKey('uptime'), isTrue);
        expect(info.containsKey('stable'), isTrue);

        monitor.dispose();
      });
    });

    test('should include correct values in debug info', () {
      fakeAsync((async) {
        mockSyncService.setConnectionState(true);
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        final info = monitor.debugInfo;
        expect(info['isOnline'], equals(monitor.isOnline));
        expect(info['status'], equals(monitor.status.name));

        monitor.dispose();
      });
    });
  });

  group('Callback Functionality', () {
    test('should trigger onConnectionChanged callback', () {
      fakeAsync((async) {
        bool? callbackValue;
        final monitor = ConnectionMonitor(
          syncService: mockSyncService,
          onConnectionChanged: (online) => callbackValue = online,
        );
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        expect(callbackValue, isTrue);

        monitor.dispose();
      });
    });

    test('should trigger onStatusChanged callback', () {
      fakeAsync((async) {
        ConnectionStatus? callbackStatus;
        final monitor = ConnectionMonitor(
          syncService: mockSyncService,
          onStatusChanged: (s) => callbackStatus = s,
        );
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        expect(callbackStatus, isNotNull);

        monitor.dispose();
      });
    });

    test('should work without callbacks', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.status, isA<ConnectionStatus>());

        monitor.dispose();
      });
    });
  });

  group('Reconnection Logic', () {
    test('should handle reconnection scenario', () {
      fakeAsync((async) {
        final history = <ConnectionStatus>[];
        final monitor = ConnectionMonitor(
          syncService: mockSyncService,
          onStatusChanged: (s) => history.add(s),
        );
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(false);
        async.elapse(const Duration(milliseconds: 400));

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        expect(history, isNotEmpty);

        monitor.dispose();
      });
    });

    test('should differentiate initial connection from reconnection', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        // Starts unknown/disconnected
        expect(monitor.isOnline, isFalse);

        mockSyncService.triggerConnectionChange(true);
        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.isOnline, isTrue);

        monitor.dispose();
      });
    });
  });

  group('Disposal and Cleanup', () {
    test('should dispose cleanly', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        expect(() => monitor.dispose(), returnsNormally);
      });
    });

    test('should cancel timers on dispose', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);

        // Trigger changes to start debounce timers
        mockSyncService.triggerConnectionChange(true);
        mockSyncService.triggerConnectionChange(false);

        // Dispose before debounce fires -- should not crash
        expect(() => monitor.dispose(), returnsNormally);

        // Remaining timer should be harmless
        async.elapse(const Duration(milliseconds: 400));
      });
    });

    test('should cancel subscription on dispose', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        monitor.dispose();

        // Events after dispose should not crash
        expect(
          () => mockSyncService.triggerConnectionChange(true),
          returnsNormally,
        );
        async.elapse(const Duration(milliseconds: 400));
      });
    });
  });

  group('Edge Cases', () {
    test('should handle rapid dispose after creation', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        expect(() => monitor.dispose(), returnsNormally);
        async.elapse(const Duration(milliseconds: 400));
      });
    });

    test('should maintain state consistency during concurrent operations', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        monitor.forceConnectionCheck();
        mockSyncService.triggerConnectionChange(true);
        mockSyncService.triggerConnectionChange(false);
        monitor.forceConnectionCheck();

        async.elapse(const Duration(milliseconds: 400));

        expect(monitor.status, isA<ConnectionStatus>());
        expect(monitor.debugInfo, isA<Map<String, dynamic>>());

        monitor.dispose();
      });
    });

    test('should provide stable API after connection changes', () {
      fakeAsync((async) {
        final monitor = ConnectionMonitor(syncService: mockSyncService);
        async.elapse(const Duration(milliseconds: 400));

        for (int i = 0; i < 5; i++) {
          mockSyncService.triggerConnectionChange(i.isEven);
          async.elapse(const Duration(milliseconds: 100));
        }
        async.elapse(const Duration(milliseconds: 400));

        // All getters work without error
        expect(() => monitor.isOnline, returnsNormally);
        expect(() => monitor.status, returnsNormally);
        expect(() => monitor.statusDescription, returnsNormally);
        expect(() => monitor.statusEmoji, returnsNormally);
        expect(() => monitor.debugInfo, returnsNormally);
        expect(() => monitor.connectionUptime, returnsNormally);
        expect(
          () => monitor.hasBeenStableFor(const Duration(seconds: 1)),
          returnsNormally,
        );

        monitor.dispose();
      });
    });
  });
}
