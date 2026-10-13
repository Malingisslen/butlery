/// Widget tests for the RealtimeIndicators facade — verifies that each
/// static helper constructs the correct underlying specialized widget with
/// its props forwarded.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';
import 'package:butlery/widgets/common/indicators/realtime_indicators.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: MediaQuery(
      // Disable animations so any infinite repeat can't hang pumpAndSettle.
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    ),
  ),
);

void main() {
  group('RealtimeIndicators.realtimeStatus', () {
    testWidgets('constructs a RealtimeStatusWidget with forwarded props', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatus(
            isOnline: true,
            statusDescription: 'Online',
            status: ConnectionStatus.connected,
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusWidget>(
        find.byType(RealtimeStatusWidget),
      );
      expect(w.isOnline, isTrue);
      expect(w.statusDescription, 'Online');
      expect(w.status, ConnectionStatus.connected);
      expect(w.showText, isFalse);
    });

    testWidgets('showText=true is forwarded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatus(
            isOnline: false,
            statusDescription: 'Offline',
            status: ConnectionStatus.disconnected,
            showText: true,
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusWidget>(
        find.byType(RealtimeStatusWidget),
      );
      expect(w.showText, isTrue);
    });

    testWidgets('custom padding is forwarded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatus(
            isOnline: true,
            statusDescription: 'd',
            status: ConnectionStatus.unknown,
            padding: const EdgeInsets.all(7),
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusWidget>(
        find.byType(RealtimeStatusWidget),
      );
      expect(w.padding, const EdgeInsets.all(7));
    });
  });

  group('RealtimeIndicators.realtimeStatusBanner', () {
    testWidgets('constructs a RealtimeStatusBanner with forwarded props', (
      tester,
    ) async {
      void onRetry() {}
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatusBanner(
            isOnline: false,
            statusDescription: 'Disconnected',
            status: ConnectionStatus.disconnected,
            onRetry: onRetry,
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusBanner>(
        find.byType(RealtimeStatusBanner),
      );
      expect(w.isOnline, isFalse);
      expect(w.statusDescription, 'Disconnected');
      expect(w.status, ConnectionStatus.disconnected);
      expect(w.onRetry, equals(onRetry));
    });

    testWidgets('null onRetry is forwarded as null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          RealtimeIndicators.realtimeStatusBanner(
            isOnline: true,
            statusDescription: 'Connected',
            status: ConnectionStatus.connected,
          ),
        ),
      );
      final w = tester.widget<RealtimeStatusBanner>(
        find.byType(RealtimeStatusBanner),
      );
      expect(w.onRetry, isNull);
    });
  });
}
