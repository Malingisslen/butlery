// The multi-recipe picker says when every recipe came from an AI reading of a
// photo, so the user knows to check them before saving.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/import/batch_import_preview.dart';

import '../../infrastructure/builders/recipe_builder.dart';

void main() {
  final recipes = [
    RecipeBuilder()
        .withId('a')
        .withTitle('Pannkakor')
        .withIngredients(['3 dl vetemjöl', '2 ägg'])
        .build(),
    RecipeBuilder()
        .withId('b')
        .withTitle('Våfflor')
        .withIngredients(['4 dl vetemjöl', '4 dl mjölk'])
        .build(),
  ];

  Future<void> pump(WidgetTester tester, {required bool readByAi}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('sv'),
          home: BatchImportPreview(recipes: recipes, readByAi: readByAi),
        ),
      );

  const note = 'AI läste fotot. Kontrollera recepten innan du sparar.';

  testWidgets('recipes an AI read carry the note to check them', (
    tester,
  ) async {
    await pump(tester, readByAi: true);
    await tester.pumpAndSettle();

    expect(find.text(note), findsOneWidget);
  });

  testWidgets('recipes the phone read carry no AI note', (tester) async {
    await pump(tester, readByAi: false);
    await tester.pumpAndSettle();

    expect(find.text(note), findsNothing);
    expect(find.text('Pannkakor'), findsOneWidget);
  });
}
