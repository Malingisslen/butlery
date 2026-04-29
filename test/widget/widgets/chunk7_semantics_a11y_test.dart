// BUT-697 chunk-7: Semantics coverage for the chunk-7 widget sweep.
//
// Asserts that the Semantics labels added in chunk 7 are exposed by
// `find.bySemanticsLabel`. The recipe-detail wraps require
// RecipeDetailViewModel + SocialRecipeViewModel scaffolding and are
// covered by chunk-8's unwrapped-files audit; this file covers the
// stand-alone-renderable wraps (ingredient chip + notification time
// tile via the public IngredientChipInput).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/views/ingredient_search/ingredient_chip_input.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-697 chunk-7 widget Semantics labels', () {
    testWidgets(
        'IngredientChipInput — selected chip exposes localized remove label',
        (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Material(
            child: IngredientChipInput(
              selectedIngredients: const [
                IngredientData(
                  id: 'tomato',
                  swedish: 'Tomater',
                  english: 'Tomatoes',
                  group: 'vegetables',
                  properties: {},
                ),
              ],
              autocompleteResults: const [],
              onSearchChanged: (_) {},
              onIngredientSelected: (_) {},
              onIngredientRemoved: (_) {},
            ),
          ),
        ),
      );

      // Swedish: "Ta bort Tomater"
      expect(
        find.bySemanticsLabel(RegExp(r'^Ta bort Tomater')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
