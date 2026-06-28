/// Direct unit tests for [RealtimeDiagnosticsHelper] (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Pure map-assembly helpers: they gather status from the realtime modules into
/// the diagnostic shape consumers read. The contract is the exact key structure
/// and the fixed architecture/version markers — so the tests assert the shape,
/// using lightweight duck-typed fakes for the modules.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_diagnostics_helper.dart';

class _FakeWatching {
  bool isWatchingAvailable() => true;
  List<String> getWatchingCapabilities() => ['watch', 'edit'];
  bool get isConnected => true;
}

class _FakePresence {
  Map<String, dynamic> getPresenceStatistics() => {'active': 2};
}

class _FakeNotification {
  bool get isNotificationAvailable => false;
  Map<String, dynamic> getNotificationStatistics() => {'sent': 5};
}

void main() {
  group('getModuleStatus', () {
    test('assembles each module\'s status under the expected keys', () {
      final status = RealtimeDiagnosticsHelper.getModuleStatus(
        watchingModule: _FakeWatching(),
        presenceModule: _FakePresence(),
        notificationModule: _FakeNotification(),
      );

      expect(status['watchingModule'], {
        'isAvailable': true,
        'capabilities': ['watch', 'edit'],
        'isConnected': true,
      });
      expect(status['editingModule'], {'isInitialized': true});
      expect(status['collaborationModule'], {'isInitialized': true});
      expect(status['presenceModule'], {
        'statistics': {'active': 2},
      });
      expect(status['notificationModule'], {
        'isAvailable': false,
        'statistics': {'sent': 5},
      });
    });
  });

  group('getRealtimeOperationsStatus', () {
    test('wraps the inputs and stamps architecture + version', () {
      final status = RealtimeDiagnosticsHelper.getRealtimeOperationsStatus(
        hasRealtimeService: true,
        isConnected: false,
        moduleStatus: {'x': 1},
        currentUserId: 'u1',
      );

      expect(status['hasRealtimeService'], isTrue);
      expect(status['isConnected'], isFalse);
      expect(status['moduleStatus'], {'x': 1});
      expect(status['currentUserId'], 'u1');
      expect(status['architecture'], 'modular');
      expect(status['version'], '2.0');
    });

    test('passes a null user id through unchanged', () {
      final status = RealtimeDiagnosticsHelper.getRealtimeOperationsStatus(
        hasRealtimeService: false,
        isConnected: false,
        moduleStatus: const {},
        currentUserId: null,
      );
      expect(status['currentUserId'], isNull);
    });
  });
}
