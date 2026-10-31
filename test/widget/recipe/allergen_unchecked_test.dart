/// Where allergens are shown, an unsettled one says "Ej kontrollerat" so the
/// absence of a badge is never read as "safe". Recipe cards show none.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
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
  generatorVersion: kTagGeneratorVersion,
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
    for (final style in RecipeCardStyle.values) {
      testWidgets('${style.name}: shows nothing allergen-related', (
        tester,
      ) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: Scaffold(
              body: RecipeCard(
                recipe: _recipe(
                  _tagResult({
                    'gluten': TriState.contains,
                    'mjölk': TriState.unknown,
                  }),
                ),
                style: style,
              ),
            ),
          ),
        );

        expect(find.byType(AllergenStatusBadge), findsNothing);
        expect(find.byType(AllergenUncheckedMark), findsNothing);
        expect(find.text('Ej kontrollerat'), findsNothing);
      });
    }
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

    testWidgets('shows the shared verdict, not the raw answer', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: TagResultDisplay(
            tagResult: _tagResult({'gluten': TriState.free}),
            userAllergenPrefs: const {'gluten'},
            // What AllergenVerdict says about a FREE from an older tagger.
            allergenStatusOf: (_) => TriState.unknown,
          ),
        ),
      );

      expect(find.byType(AllergenStatusBadge), findsNothing);
      expect(find.text('Ej kontrollerat'), findsOneWidget);
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
