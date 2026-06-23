/// BUT-670: regression gate for the maintenance-mode kill switch.
///
/// What this proves:
///   1. When the FeatureFlagService reports `app_maintenance_mode == true`,
///      the gate replaces its child with the blocker UI (Underhållsläge).
///   2. When false, the gate passes the child through transparently.
///   3. The retry button calls `FeatureFlagService.refresh()` and re-renders.
///   4. The "Försök igen" button is hit-testable and labelled correctly.
///
/// Mocking strategy: a minimal `Fake` FeatureFlagService injected via the
/// gate's test override slot — avoids needing the full Firebase Remote
/// Config plumbing.
library;

import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/widgets/maintenance_mode_blocker.dart';
import 'package:butlery/widgets/maintenance_mode_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubFlagService implements FeatureFlagService {
  bool maintenanceMode = false;
  String message = '';
  int refreshCount = 0;
  void Function()? _listener;

  @override
  bool isEnabled(String flag) {
    if (flag == FeatureFlags.appMaintenanceMode) return maintenanceMode;
    return false;
  }

  @override
  String getString(String flag) {
    if (flag == FeatureFlags.appMaintenanceMessageSv) return message;
    return '';
  }

  @override
  void addOnConfigUpdatedListener(void Function() onUpdated) {
    _listener = onUpdated;
  }

  @override
  Future<bool> refresh() async {
    refreshCount++;
    return true;
  }

  // ---- not used by the gate, no-op stubs ----
  @override
  int getInt(String flag) => 0;
  @override
  double getDouble(String flag) => 0.0;
  @override
  bool isInRollout(String flag, String userId) => false;
  @override
  Future<void> initialize() async {}
  @override
  Map<String, dynamic> getAllFlags() => {};
  @override
  void resetSessionDedup() {}
  @override
  void dispose() {}
  @override
  int get evaluatedTupleCount => 0;

  /// Test helper: simulate a Remote Config update by invoking the stored
  /// listener. Mirrors what the real service does on `onConfigUpdated`.
  void simulateConfigUpdate() => _listener?.call();
}

void main() {
  group('BUT-670: MaintenanceModeGate', () {
    testWidgets('passes child through when maintenance mode is OFF', (
      tester,
    ) async {
      final flags = _StubFlagService();
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceModeGate(
            featureFlagServiceOverride: flags,
            child: const Text('home content'),
          ),
        ),
      );

      expect(find.text('home content'), findsOneWidget);
      expect(find.byType(MaintenanceModeBlocker), findsNothing);
    });

    testWidgets('shows blocker when maintenance mode is ON', (tester) async {
      final flags = _StubFlagService()
        ..maintenanceMode = true
        ..message = 'Stör inte. Vi jobbar.';
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceModeGate(
            featureFlagServiceOverride: flags,
            child: const Text('home content'),
          ),
        ),
      );

      expect(find.text('home content'), findsNothing);
      expect(find.byType(MaintenanceModeBlocker), findsOneWidget);
      expect(find.text('Underhållsläge'), findsOneWidget);
      expect(find.text('Stör inte. Vi jobbar.'), findsOneWidget);
      expect(find.text('Försök igen'), findsOneWidget);
    });

    testWidgets(
      'falls back to default Swedish message when override is empty',
      (tester) async {
        final flags = _StubFlagService()..maintenanceMode = true;
        await tester.pumpWidget(
          MaterialApp(
            home: MaintenanceModeGate(
              featureFlagServiceOverride: flags,
              child: const Text('home'),
            ),
          ),
        );

        expect(
          find.text('Vi gör en kort uppdatering. Försök igen om en stund.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('retry button refreshes flags and re-evaluates the gate', (
      tester,
    ) async {
      final flags = _StubFlagService()..maintenanceMode = true;
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceModeGate(
            featureFlagServiceOverride: flags,
            child: const Text('home content'),
          ),
        ),
      );
      expect(find.byType(MaintenanceModeBlocker), findsOneWidget);

      // Simulate ops flipping the flag back off, then the user taps retry.
      flags.maintenanceMode = false;
      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();

      expect(flags.refreshCount, 1);
      expect(find.byType(MaintenanceModeBlocker), findsNothing);
      expect(find.text('home content'), findsOneWidget);
    });

    testWidgets('reacts to live config updates (mid-session flip)', (
      tester,
    ) async {
      final flags = _StubFlagService();
      await tester.pumpWidget(
        MaterialApp(
          home: MaintenanceModeGate(
            featureFlagServiceOverride: flags,
            child: const Text('home content'),
          ),
        ),
      );
      expect(find.byType(MaintenanceModeBlocker), findsNothing);

      // Ops flips maintenance mode on; Remote Config update fires.
      flags.maintenanceMode = true;
      flags.message = 'Underhåll pågår.';
      flags.simulateConfigUpdate();
      await tester.pump();

      expect(find.byType(MaintenanceModeBlocker), findsOneWidget);
      expect(find.text('Underhåll pågår.'), findsOneWidget);
    });
  });
}
