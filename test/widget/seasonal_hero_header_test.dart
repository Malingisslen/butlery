import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/home/seasonal_hero_header.dart';

/// Behaviour verified:
/// - Header renders localized month title, ingredient subline, and match count.
/// - Tap propagates through `onTap` callback.
/// - Semantics wrap the whole widget as a button (for screen readers).
void main() {
  const aprilMonth = SeasonalMonth(
    monthIndex: 4,
    monthKey: 'april',
    ingredients: ['sparris', 'rabarber', 'purjolök'],
    vegetableType: VegetableType.asparagus,
    gradient: ['#E8F0EA', '#F8F4E8'],
  );

  Widget harness({required VoidCallback onTap, int matchCount = 5}) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: const [Locale('sv'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SeasonalHeroHeader(
          month: aprilMonth,
          matchCount: matchCount,
          onTap: onTap,
        ),
      ),
    );
  }

  testWidgets('renders localized title, ingredients, and recipe count',
      (tester) async {
    await tester.pumpWidget(harness(onTap: () {}));
    await tester.pumpAndSettle();

    // Swedish locale — "just nu i säsong · april"
    expect(find.textContaining('april'), findsOneWidget);
    // Ingredient line joins with ' · '
    expect(
        find.textContaining('sparris · rabarber · purjolök'), findsOneWidget);
    // Plural-aware Swedish count
    expect(find.text('5 recept'), findsOneWidget);
  });

  testWidgets('tap fires onTap exactly once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(onTap: () => taps++));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('singular count renders without plural s', (tester) async {
    await tester.pumpWidget(harness(onTap: () {}, matchCount: 1));
    await tester.pumpAndSettle();

    expect(find.text('1 recept'), findsOneWidget);
  });

  testWidgets('exposes button semantics for screen readers', (tester) async {
    await tester.pumpWidget(harness(onTap: () {}));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(SeasonalHeroHeader)),
      containsSemantics(isButton: true),
    );
  });
}
