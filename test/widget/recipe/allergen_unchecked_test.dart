/// Megagenomgång A1: a recipe whose allergens are unsettled says
/// "Ej kontrollerat" in words wherever allergens are shown, so the absence of
/// a badge is never read as "safe".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/tagging/allergen_status_badge.dart';
import 'package:butlery/widgets/tagging/tag_result_display.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

TagResult _tagResult(Map<String, TriState> allergens) => TagResult(
  tags: const {},
  allergenStatus: allergens,
  dietaryStatus: const {},
  coverage: 1.0,
  generatedAt: DateTime(2026, 1, 1),
  generatorVersion: '1.0',
  hasCoverageAnomaly: false,
);

Recipe _recipe(TagResult tagResult) =>
    (RecipeBuilder()
          ..id = 'r1'
          ..title = 'Test'
          ..imageUrls = []
          ..withTagResult(tagResult))
        .build();

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('recipe card', () {
    Future<void> pumpCard(WidgetTester tester, Recipe recipe) =>
        tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: recipe,
                style: RecipeCardStyle.detailed,
                showAllergenBadges: true,
                userAllergenPrefs: const {'gluten', 'mjölk'},
              ),
            ),
          ),
        );

    testWidgets(
      'says so beside the known badges when one allergen is unsettled',
      (
        tester,
      ) async {
        await pumpCard(
          tester,
          _recipe(
            _tagResult({'gluten': TriState.free, 'mjölk': TriState.unknown}),
          ),
        );

        expect(find.byType(AllergenStatusBadge), findsOneWidget);
        expect(find.text('Ej kontrollerat'), findsOneWidget);
      },
    );

    testWidgets('stays silent when every tracked allergen is settled', (
      tester,
    ) async {
      await pumpCard(
        tester,
        _recipe(
          _tagResult({'gluten': TriState.free, 'mjölk': TriState.contains}),
        ),
      );

      expect(find.text('Ej kontrollerat'), findsNothing);
    });
  });

  group('TagResultDisplay', () {
    testWidgets('names the unsettled allergens and explains it', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: TagResultDisplay(
            tagResult: _tagResult({
              'gluten': TriState.free,
              'mjölk': TriState.unknown,
            }),
            userAllergenPrefs: const {'gluten', 'mjölk'},
          ),
        ),
      );

      expect(find.byType(AllergenUncheckedMark), findsOneWidget);
      expect(find.text('Ej kontrollerat'), findsOneWidget);
      expect(
        find.textContaining('Läs ingredienserna själv'),
        findsOneWidget,
      );
    });

    testWidgets('a result that settled nothing is not "no allergens found"', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: TagResultDisplay(tagResult: _tagResult(const {})),
        ),
      );

      expect(find.text('Ej kontrollerat'), findsOneWidget);
      expect(find.text('Inga av dina allergener hittades'), findsNothing);
    });
  });
}
