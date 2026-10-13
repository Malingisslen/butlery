/// Widget tests for ConnectionDot — status shows as a coloured dot, never text.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/viewmodels/realtime/connection_monitor.dart';
import 'package:butlery/widgets/common/indicators/connection_dot.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';
import 'package:butlery/widgets/social/collaborative/components/collaborative_connection_widgets.dart';

void main() {
  const expectations = <ConnectionStatus, String>{
    ConnectionStatus.connected: 'success',
    ConnectionStatus.disconnected: 'error',
    ConnectionStatus.connecting: 'warning',
    ConnectionStatus.reconnecting: 'warning',
    ConnectionStatus.unknown: 'neutral',
  };

  for (final entry in expectations.entries) {
    testWidgets('${entry.key.name} is drawn as a round ${entry.value} dot', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: ConnectionDot(status: entry.key)),
        ),
      );

      final context = tester.element(find.byType(ConnectionDot));
      final modeColors = context.modeColors;
      final expected = switch (entry.value) {
        'success' => modeColors.success,
        'error' => Theme.of(context).colorScheme.error,
        'warning' => modeColors.warning,
        _ => modeColors.neutral,
      };

      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(ConnectionDot),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, expected);
      expect(find.byType(Text), findsNothing);
    });
  }

  group('widgets hand their status on to the dot', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('sv'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );
    }

    ConnectionStatus? dotStatus(WidgetTester tester) =>
        tester.widgetList<ConnectionDot>(find.byType(ConnectionDot)).isEmpty
        ? null
        : tester.widget<ConnectionDot>(find.byType(ConnectionDot)).status;

    testWidgets('RealtimeStatusWidget', (tester) async {
      await pump(
        tester,
        const RealtimeStatusWidget(
          isOnline: false,
          statusDescription: 'd',
          status: ConnectionStatus.reconnecting,
        ),
      );
      expect(dotStatus(tester), ConnectionStatus.reconnecting);
    });

    testWidgets('RealtimeStatusBanner', (tester) async {
      await pump(
        tester,
        const RealtimeStatusBanner(
          isOnline: false,
          statusDescription: 'd',
          status: ConnectionStatus.disconnected,
        ),
      );
      expect(dotStatus(tester), ConnectionStatus.disconnected);
    });

    testWidgets(
      'collaborative offline banner shows the dot only with a status',
      (
        tester,
      ) async {
        await pump(
          tester,
          CollaborativeConnectionWidgets.connectionStatus(
            isOnline: false,
            statusText: 'x',
            status: ConnectionStatus.disconnected,
          ),
        );
        expect(dotStatus(tester), ConnectionStatus.disconnected);

        await pump(
          tester,
          CollaborativeConnectionWidgets.connectionStatus(
            isOnline: false,
            statusText: 'x',
          ),
        );
        expect(dotStatus(tester), isNull);
      },
    );

    testWidgets('collaborative online pill shows a connected dot', (
      tester,
    ) async {
      await pump(
        tester,
        CollaborativeConnectionWidgets.connectionStatus(
          isOnline: true,
          statusText: '',
        ),
      );
      expect(dotStatus(tester), ConnectionStatus.connected);
    });
  });
}
