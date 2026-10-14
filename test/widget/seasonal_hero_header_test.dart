import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/seasonal/seasonal_month.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/home/seasonal_hero_header.dart';

/// Behaviour verified:
/// - Header renders localized month title, ingredient subline, and match count.
/// - The banner is information only: nothing on it is pressable.
void main() {
  const aprilMonth = SeasonalMonth(
    monthIndex: 4,
    monthKey: 'april',
    ingredients: ['sparris', 'rabarber', 'purjolök'],
    vegetableType: VegetableType.asparagus,
  );

  Widget harness({int matchCount = 5}) {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: const [Locale('sv'), Locale('en')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: SeasonalHeroHeader(
          month: aprilMonth,
          matchCount: matchCount,
        ),
      ),
    );
  }

  testWidgets('renders localized title, ingredients, and recipe count', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Swedish locale — "just nu i säsong · april"
    expect(find.textContaining('april'), findsOneWidget);
    // Ingredient line joins with ' · '
    expect(
      find.textContaining('sparris · rabarber · purjolök'),
      findsOneWidget,
    );
    // Plural-aware Swedish count
    expect(find.text('5 recept'), findsOneWidget);
  });

  testWidgets('is not pressable', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('singular count renders without plural s', (tester) async {
    await tester.pumpWidget(harness(matchCount: 1));
    await tester.pumpAndSettle();

    expect(find.text('1 recept'), findsOneWidget);
  });

  testWidgets('is not announced as a button', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byType(SeasonalHeroHeader)),
      isNot(containsSemantics(isButton: true)),
    );
  });
}
