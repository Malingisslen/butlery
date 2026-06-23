/// BUT-604: gates for the inline timer chip.
///
/// Intent: a duration phrase inside an instruction line renders as a tappable
/// chip that surfaces the parsed duration to the caller — the visible
/// replacement for the long-press-only affordance BUT-406 shipped. Lines
/// without a duration must render as plain text (no phantom affordance).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/utils/duration_parser.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders the duration phrase as a tappable chip', (tester) async {
    DurationMatch? tapped;
    await tester.pumpWidget(
      _wrap(
        InlineTimerText(
          text: 'Grädda i 25 min mitt i ugnen',
          onTimerTap: (m) => tapped = m,
        ),
      ),
    );

    expect(
      find.byIcon(Icons.timer_outlined),
      findsOneWidget,
      reason: 'The chip is the visible timer affordance.',
    );
    expect(
      find.text('25 min'),
      findsOneWidget,
      reason: 'The chip carries the matched phrase verbatim.',
    );

    await tester.tap(find.byIcon(Icons.timer_outlined));
    expect(tapped, isNotNull, reason: 'Tap must surface the parsed match.');
    expect(tapped!.duration, const Duration(minutes: 25));
  });

  testWidgets('word phrase "en halvtimme" gets a chip too', (tester) async {
    DurationMatch? tapped;
    await tester.pumpWidget(
      _wrap(
        InlineTimerText(
          text: 'Låt vila en halvtimme',
          onTimerTap: (m) => tapped = m,
        ),
      ),
    );

    expect(find.text('en halvtimme'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.timer_outlined));
    expect(tapped!.duration, const Duration(minutes: 30));
  });

  testWidgets('line without a duration renders plain text — no chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        InlineTimerText(
          text: 'Rör ner smöret',
          onTimerTap: (_) => fail('No chip should exist to tap'),
        ),
      ),
    );

    expect(
      find.byIcon(Icons.timer_outlined),
      findsNothing,
      reason: 'A chip on a non-duration line is a phantom affordance.',
    );
    expect(find.text('Rör ner smöret'), findsOneWidget);
  });

  testWidgets('chip exposes a button semantics label for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        InlineTimerText(
          text: 'Koka i 10 min',
          onTimerTap: (_) {},
        ),
      ),
    );

    // Not start-anchored: the chip's WidgetSpan node can merge with the
    // surrounding text span in the semantics tree.
    expect(
      find.bySemanticsLabel(RegExp('Starta timer')),
      findsOneWidget,
      reason:
          'Per ui-conventions, InkWell affordances need an explicit '
          'localized Semantics(button:) label.',
    );
    handle.dispose();
  });
}
