/// BUT-1519: the shared Butlery-betyget pill, extracted from the recipe card
/// and the recipe-detail metadata so both render one component. Behaviour of
/// the two consumers is pinned by their own suites; this pins the pill itself —
/// the Swedish decimal-comma average, the vote count, and the a11y label.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/recipe/butlery_betyg_pill.dart';

Widget _host(PooledStats stats) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: Center(child: ButleryBetygPill(stats: stats)),
  ),
);

void main() {
  testWidgets('renders the average with a decimal comma and the vote count', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PooledStats(count: 12, average: 4.5)));

    // Pins the whole visible contract at once: decimal comma (4,5, not 4.5),
    // the middot separator, and the "{count} betyg" label.
    expect(find.text('4,5 · 12 betyg'), findsOneWidget);
  });

  testWidgets('a whole-number average keeps its one decimal (4 -> 4,0)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PooledStats(count: 8, average: 4.0)));
    expect(find.text('4,0 · 8 betyg'), findsOneWidget);
  });

  testWidgets('carries an accessible label with average and count', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const PooledStats(count: 7, average: 3.8)));
    // Pins the full a11yButleryBetygPill(avg, count) contract — both the
    // average and the count — not just the average.
    expect(
      find.bySemanticsLabel(RegExp(r'Butlery-betyget 3,8.*7 röster')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
