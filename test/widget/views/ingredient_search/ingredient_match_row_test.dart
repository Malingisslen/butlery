import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/ingredient_search/ingredient_match_row.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'a hit shows the title, the count, what is missing and the match',
    (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          IngredientMatchRow(
            recipe: RecipeFactory.build(id: 'r1', title: 'Svamprisotto'),
            matchPercent: 0.67,
            matchedCount: 2,
            totalCount: 3,
            missingNames: const ['arborioris'],
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('Svamprisotto'), findsOneWidget);
      expect(find.textContaining('2 av 3 ingredienser'), findsOneWidget);
      expect(find.text('Saknas: arborioris'), findsOneWidget);
      expect(find.text('67 %'), findsOneWidget);

      await tester.tap(find.text('Svamprisotto'));
      expect(taps, 1);
    },
  );

  testWidgets('a full match has nothing missing to list', (tester) async {
    await tester.pumpWidget(
      _host(
        IngredientMatchRow(
          recipe: RecipeFactory.build(id: 'r1', title: 'Svamppasta'),
          matchPercent: 1,
          matchedCount: 3,
          totalCount: 3,
          missingNames: const [],
          onTap: () {},
        ),
      ),
    );

    expect(find.text('100 %'), findsOneWidget);
    expect(find.textContaining('Saknas'), findsNothing);
  });
}
