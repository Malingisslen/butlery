// test/unit/viewmodels/realtime_menu/realtime_stream_manager_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_stream_manager.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';

// Local pure-Mock — the centralized MockRealtimeMenuService has concrete
// @override on watchRealtimeMenu which prevents mocktail when() stubbing.
class _MockMenuService extends Mock implements RealtimeMenuService {}

RealtimeMenu _buildMenu({String id = 'menu_123', String title = 'Test Menu'}) {
  return RealtimeMenu(
    id: id,
    ownerId: 'owner',
    ownerDisplayName: 'Owner',
    participants: {},
    lastEditedBy: 'owner',
    lastEditedByDisplayName: 'Owner',
    data: RealtimeMenuData(
      menuTitle: title,
      createdForDate: DateTime.now(),
      menuSnapshot: {},
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeStreamManager', () {
    late RealtimeStreamManager manager;
    late _MockMenuService mockService;
    late StreamController<RealtimeMenu> streamCtrl;

    late List<RealtimeMenu> updates;
    late List<dynamic> errors;
    late List<String> events;

    const menuId1 = 'menu_123';
    const menuId2 = 'menu_456';

    setUpAll(() {
      registerFallbackValue(_buildMenu());
    });

    setUp(() {
      mockService = _MockMenuService();
      streamCtrl = StreamController<RealtimeMenu>.broadcast();
      updates = [];
      errors = [];
      events = [];

      when(() => mockService.watchRealtimeMenu(any()))
          .thenAnswer((_) => streamCtrl.stream);

      manager = RealtimeStreamManager(
        menuService: mockService,
        onMenuUpdated: (m) => updates.add(m),
        onMenuError: (e) => errors.add(e),
        onStreamStarted: () => events.add('started'),
        onStreamStopped: () => events.add('stopped'),
      );
    });

    tearDown(() async {
      await manager.dispose();
      if (!streamCtrl.isClosed) await streamCtrl.close();
    });

    // -- Initial State -------------------------------------------------------

    group('Initial State', () {
      test('should have correct defaults', () {
        expect(manager.isStreaming, isFalse);
        expect(manager.currentMenuId, isNull);
        expect(manager.hasActiveSubscription, isFalse);
        expect(manager.isStreamHealthy(), isFalse);
      });

      test('should not call service on construction', () {
        verifyNever(() => mockService.watchRealtimeMenu(any()));
      });

      test('should return initial connection stats', () {
        final stats = manager.getConnectionStats();
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isFalse);
        expect(stats['currentMenuId'], isNull);
        expect(stats['isHealthy'], isFalse);
      });
    });

    // -- Start Watching ------------------------------------------------------

    group('Start Watching', () {
      test('should start stream and fire callback', () async {
        await manager.startWatching(menuId1);

        expect(manager.isStreaming, isTrue);
        expect(manager.currentMenuId, equals(menuId1));
        expect(manager.hasActiveSubscription, isTrue);
        expect(events, contains('started'));
        verify(() => mockService.watchRealtimeMenu(menuId1)).called(1);
      });

      test('should deliver menu updates via callback', () async {
        await manager.startWatching(menuId1);
        final menu = _buildMenu();
        streamCtrl.add(menu);
        await Future.microtask(() {});

        expect(updates, hasLength(1));
        expect(updates.first.id, equals(menuId1));
      });

      test('should skip if already watching the same menu', () async {
        await manager.startWatching(menuId1);
        events.clear();

        await manager.startWatching(menuId1);

        expect(events, isEmpty);
        verify(() => mockService.watchRealtimeMenu(menuId1)).called(1);
      });

      test('should switch menus when watching different menu', () async {
        await manager.startWatching(menuId1);
        events.clear();

        await manager.startWatching(menuId2);

        expect(manager.currentMenuId, equals(menuId2));
        expect(events, contains('stopped'));
        expect(events, contains('started'));
        verify(() => mockService.watchRealtimeMenu(menuId2)).called(1);
      });

      test('should clean up on service exception', () async {
        when(() => mockService.watchRealtimeMenu(menuId1))
            .thenThrow(Exception('Network error'));

        await expectLater(
          manager.startWatching(menuId1),
          throwsA(isA<Exception>()),
        );

        expect(manager.isStreaming, isFalse);
        expect(manager.currentMenuId, isNull);
        expect(manager.hasActiveSubscription, isFalse);
      });
    });

    // -- Stop Watching -------------------------------------------------------

    group('Stop Watching', () {
      test('should stop and reset state', () async {
        await manager.startWatching(menuId1);
        events.clear();

        await manager.stopWatching();

        expect(manager.isStreaming, isFalse);
        expect(manager.currentMenuId, isNull);
        expect(manager.hasActiveSubscription, isFalse);
        expect(events, contains('stopped'));
      });

      test('should be no-op if not streaming', () async {
        await manager.stopWatching();
        expect(events, isEmpty);
      });

      test('should show clean stats after stop', () async {
        await manager.startWatching(menuId1);
        await manager.stopWatching();

        final stats = manager.getConnectionStats();
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isFalse);
        expect(stats['currentMenuId'], isNull);
      });
    });

    // -- Pause / Resume ------------------------------------------------------

    group('Pause and Resume', () {
      test('should pause streaming (subscription kept)', () async {
        await manager.startWatching(menuId1);
        manager.pauseStreaming();

        expect(manager.isStreaming, isFalse);
        expect(manager.hasActiveSubscription, isTrue);
        expect(manager.currentMenuId, equals(menuId1));
      });

      test('should resume streaming', () async {
        await manager.startWatching(menuId1);
        manager.pauseStreaming();
        manager.resumeStreaming();

        expect(manager.isStreaming, isTrue);
        expect(manager.hasActiveSubscription, isTrue);
      });

      test('should ignore updates while paused', () async {
        await manager.startWatching(menuId1);
        manager.pauseStreaming();
        updates.clear();

        streamCtrl.add(_buildMenu());
        await Future.microtask(() {});

        expect(updates, isEmpty);
      });

      test('should process updates after resume', () async {
        await manager.startWatching(menuId1);
        manager.pauseStreaming();
        manager.resumeStreaming();
        updates.clear();

        streamCtrl.add(_buildMenu());
        await Future.microtask(() {});

        expect(updates, hasLength(1));
      });

      test('should be no-op if not streaming', () {
        manager.pauseStreaming();
        expect(manager.isStreaming, isFalse);
      });

      test('should be no-op if no subscription', () {
        manager.resumeStreaming();
        expect(manager.isStreaming, isFalse);
      });
    });

    // -- Connection Management -----------------------------------------------

    group('Connection Management', () {
      test('should report healthy when active', () async {
        await manager.startWatching(menuId1);
        expect(manager.isStreamHealthy(), isTrue);
      });

      test('should report unhealthy when paused', () async {
        await manager.startWatching(menuId1);
        manager.pauseStreaming();
        expect(manager.isStreamHealthy(), isFalse);
      });

      test('should restart stream for current menu', () async {
        await manager.startWatching(menuId1);
        events.clear();

        await manager.restartStream();

        expect(manager.currentMenuId, equals(menuId1));
        expect(events, contains('stopped'));
        expect(events, contains('started'));
        verify(() => mockService.watchRealtimeMenu(menuId1)).called(2);
      });

      test('should skip restart when no menu ID', () async {
        await manager.restartStream();
        expect(events, isEmpty);
        verifyNever(() => mockService.watchRealtimeMenu(any()));
      });

      test('should force reconnect when menu active', () async {
        await manager.startWatching(menuId1);
        events.clear();

        await manager.forceReconnect();

        expect(manager.isStreaming, isTrue);
        expect(events, contains('stopped'));
        expect(events, contains('started'));
      });

      test('should skip force reconnect without active menu', () async {
        await manager.forceReconnect();
        expect(events, isEmpty);
      });
    });

    // -- Stream Events -------------------------------------------------------

    group('Stream Events', () {
      test('should forward stream errors to callback', () async {
        await manager.startWatching(menuId1);
        streamCtrl.addError(Exception('stream err'));
        await Future.microtask(() {});

        expect(errors, hasLength(1));
      });

      test('should handle stream completion', () async {
        await manager.startWatching(menuId1);
        events.clear();

        await streamCtrl.close();
        await Future.microtask(() {});

        expect(manager.isStreaming, isFalse);
        expect(events, contains('stopped'));
      });

      test('should receive rapid updates (may debounce)', () async {
        await manager.startWatching(menuId1);

        streamCtrl.add(_buildMenu(title: 'A'));
        streamCtrl.add(_buildMenu(title: 'B'));
        streamCtrl.add(_buildMenu(title: 'C'));
        // Each StreamController.add() schedules a separate microtask, so
        // waiting one microtask only delivers the first event. Drain the
        // event queue so all three arrive before the assertion.
        await pumpEventQueue();

        // Stream may debounce rapid updates — at least the last one arrives
        expect(updates, isNotEmpty);
        expect(updates.last.menuTitle, 'C');
      });
    });

    // -- Validation ----------------------------------------------------------

    group('Validation', () {
      test('should validate non-empty menu ID as valid', () {
        expect(manager.validateMenuId(menuId1), isTrue);
      });

      test('should validate null and empty as invalid', () {
        expect(manager.validateMenuId(null), isFalse);
        expect(manager.validateMenuId(''), isFalse);
      });

      test('should allow starting stream with valid menu ID', () {
        expect(manager.canStartStreaming(menuId1), isTrue);
      });

      test('should deny starting stream with empty menu ID', () {
        expect(manager.canStartStreaming(''), isFalse);
      });

      test('should allow restart of same menu', () async {
        await manager.startWatching(menuId1);
        expect(manager.canStartStreaming(menuId1), isTrue);
      });
    });

    // -- Statistics ----------------------------------------------------------

    group('Statistics', () {
      test('should return streaming stats', () async {
        await manager.startWatching(menuId1);
        final stats = manager.getConnectionStats();
        expect(stats['isStreaming'], isTrue);
        expect(stats['hasSubscription'], isTrue);
        expect(stats['currentMenuId'], equals(menuId1));
        expect(stats['isHealthy'], isTrue);
      });

      test('should return paused stats', () async {
        await manager.startWatching(menuId1);
        manager.pauseStreaming();
        final stats = manager.getConnectionStats();
        expect(stats['isStreaming'], isFalse);
        expect(stats['hasSubscription'], isTrue);
        expect(stats['isHealthy'], isFalse);
      });

      test('should return null stream duration (not implemented)', () {
        expect(manager.getStreamDuration(), isNull);
      });
    });

    // -- Lifecycle ------------------------------------------------------------

    group('Lifecycle', () {
      test('should dispose without throwing', () async {
        await expectLater(manager.dispose(), completes);
      });

      test('should clean up on disposal with active stream', () async {
        await manager.startWatching(menuId1);
        await manager.dispose();

        expect(manager.isStreaming, isFalse);
        expect(manager.currentMenuId, isNull);
        expect(manager.hasActiveSubscription, isFalse);
      });

      test('should handle multiple dispose calls', () async {
        await manager.dispose();
        await expectLater(manager.dispose(), completes);
      });

      test('should handle rapid start/stop cycles', () async {
        await manager.startWatching(menuId1);
        await manager.stopWatching();
        await manager.startWatching(menuId2);
        await manager.stopWatching();

        expect(manager.isStreaming, isFalse);
        expect(manager.currentMenuId, isNull);
      });
    });
  });
}
