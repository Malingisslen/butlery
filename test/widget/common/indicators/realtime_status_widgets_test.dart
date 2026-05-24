/// Widget tests for RealtimeStatusWidget and RealtimeStatusBanner.
///
/// Verifies tooltip, emoji rendering, conditional text visibility, banner
/// hide-when-online, retry button visibility/callback, and l10n usage.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/realtime_status_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: MediaQuery(
          // Disable animations so AnimatedSwitcher fades don't fight pump.
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      ),
    );

void main() {
  group('RealtimeStatusWidget', () {
    testWidgets('renders emoji and wraps it in a Tooltip with description',
        (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusWidget(
        isOnline: true,
        statusDescription: 'Allt funkar',
        statusEmoji: '🟢',
      )));
      await tester.pump();

      expect(find.text('🟢'), findsOneWidget);
      final tooltip = tester.widget<Tooltip>(find.descendant(
        of: find.byType(RealtimeStatusWidget),
        matching: find.byType(Tooltip),
      ));
      expect(tooltip.message, 'Allt funkar');
    });

    testWidgets('does not render statusDescription text when showText=false',
        (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusWidget(
        isOnline: true,
        statusDescription: 'Allt funkar',
        statusEmoji: '🟢',
      )));
      await tester.pump();

      // Description should NOT be visible as a Text widget (only as tooltip
      // message). The only visible Text inside the widget is the emoji.
      final texts = find
          .descendant(
            of: find.byType(RealtimeStatusWidget),
            matching: find.byType(Text),
          )
          .evaluate();
      expect(texts.length, 1);
      expect((texts.first.widget as Text).data, '🟢');
    });

    testWidgets('renders statusDescription text when showText=true',
        (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusWidget(
        isOnline: false,
        statusDescription: 'Frånkopplad',
        statusEmoji: '🔴',
        showText: true,
      )));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RealtimeStatusWidget),
          matching: find.text('Frånkopplad'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('default padding is EdgeInsets.all(spacingS) when not supplied',
        (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusWidget(
        isOnline: true,
        statusDescription: 'd',
        statusEmoji: 'e',
      )));
      final container = tester.widget<Container>(find
          .descendant(
            of: find.byType(RealtimeStatusWidget),
            matching: find.byType(Container),
          )
          .first);
      expect(
        container.padding,
        const EdgeInsets.all(AppDimensions.spacingS),
      );
    });

    testWidgets('custom padding overrides default', (tester) async {
      const custom = EdgeInsets.symmetric(horizontal: 11, vertical: 13);
      await tester.pumpWidget(_wrap(const RealtimeStatusWidget(
        isOnline: true,
        statusDescription: 'd',
        statusEmoji: 'e',
        padding: custom,
      )));
      final container = tester.widget<Container>(find
          .descendant(
            of: find.byType(RealtimeStatusWidget),
            matching: find.byType(Container),
          )
          .first);
      expect(container.padding, custom);
    });
  });

  group('RealtimeStatusBanner', () {
    testWidgets('renders SizedBox.shrink (no banner content) when isOnline',
        (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusBanner(
        isOnline: true,
        statusDescription: 'Connected',
        statusEmoji: '🟢',
      )));
      await tester.pump();

      // No emoji, no localized "Offline" heading, no retry button when online.
      expect(find.text('🟢'), findsNothing);
      expect(find.text('Offline'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      // Banner itself collapses to SizedBox.shrink.
      expect(
        find.descendant(
          of: find.byType(RealtimeStatusBanner),
          matching: find.byType(Row),
        ),
        findsNothing,
      );
    });

    testWidgets('renders emoji + l10n offline title + description when offline',
        (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusBanner(
        isOnline: false,
        statusDescription: 'Ingen anslutning',
        statusEmoji: '🔴',
      )));
      await tester.pump();

      expect(find.text('🔴'), findsOneWidget);
      // Swedish l10n: realtimeOffline = "Offline"
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Ingen anslutning'), findsOneWidget);
    });

    testWidgets('omits retry TextButton when onRetry is null', (tester) async {
      await tester.pumpWidget(_wrap(const RealtimeStatusBanner(
        isOnline: false,
        statusDescription: 'x',
        statusEmoji: '🔴',
      )));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(RealtimeStatusBanner),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
    });

    testWidgets('renders retry button with l10n label and invokes callback',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(RealtimeStatusBanner(
        isOnline: false,
        statusDescription: 'x',
        statusEmoji: '🔴',
        onRetry: () => taps++,
      )));
      await tester.pump();

      // Swedish l10n: commonRetry = "Försök igen"
      final btnFinder = find.widgetWithText(TextButton, 'Försök igen');
      expect(btnFinder, findsOneWidget);

      await tester.tap(btnFinder);
      await tester.pump();
      expect(taps, 1);
    });
  });
}
