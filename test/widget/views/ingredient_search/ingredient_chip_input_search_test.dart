import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/views/ingredient_search/ingredient_chip_input.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the ingredient search is the shared search box, and its clear '
      'empties the query and hides the suggestions', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Material(
          child: IngredientChipInput(
            selectedIngredients: const [],
            autocompleteResults: const [
              IngredientData(
                id: 'tomato',
                swedish: 'Tomater',
                english: 'Tomatoes',
                group: 'vegetables',
                properties: {},
              ),
            ],
            onSearchChanged: queries.add,
            onIngredientSelected: (_) {},
            onIngredientRemoved: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(ButlerySearchBox), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tom');
    await tester.pump();
    expect(find.byType(IngredientSuggestionList), findsOneWidget);

    await tester.tap(find.byIcon(ButleryIcons.x));
    await tester.pump();
    expect(queries.last, '');
    expect(find.byType(IngredientSuggestionList), findsNothing);
  });

  testWidgets('tapping a chip removes that ingredient by its id', (
    tester,
  ) async {
    final removed = <String>[];
    IngredientData ingredient(String id, String swedish) => IngredientData(
      id: id,
      swedish: swedish,
      english: id,
      group: 'vegetables',
      properties: const {},
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Material(
          child: IngredientChipInput(
            selectedIngredients: [
              ingredient('ing-onion', 'Lök'),
              ingredient('ing-garlic', 'Vitlök'),
            ],
            autocompleteResults: const [],
            onSearchChanged: (_) {},
            onIngredientSelected: (_) {},
            onIngredientRemoved: removed.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Vitlök'));
    await tester.pump();
    expect(removed, ['ing-garlic']);
  });
}
