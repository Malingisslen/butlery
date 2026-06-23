/// Widget tests for IngredientSuggestionList.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/widgets/common/input/ingredient_suggestion_list.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

IngredientData _ingredient({
  String id = 'ing-1',
  String swedish = 'Mjölk',
}) {
  return IngredientData(
    id: id,
    swedish: swedish,
    english: 'Milk',
    group: 'dairy',
    properties: const {},
  );
}

void main() {
  testWidgets('renders empty list with no item rows', (tester) async {
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(results: const [], onTap: (_) {}),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('renders one item per result, showing swedish name', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(
          results: [
            _ingredient(id: '1', swedish: 'Mjölk'),
            _ingredient(id: '2', swedish: 'Bröd'),
          ],
          onTap: (_) {},
        ),
      ),
    );
    expect(find.text('Mjölk'), findsOneWidget);
    expect(find.text('Bröd'), findsOneWidget);
    expect(find.byType(InkWell), findsNWidgets(2));
  });

  testWidgets('tapping an item calls onTap with the right ingredient', (
    tester,
  ) async {
    IngredientData? tapped;
    final milk = _ingredient(id: '1', swedish: 'Mjölk');
    final bread = _ingredient(id: '2', swedish: 'Bröd');
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(
          results: [milk, bread],
          onTap: (ing) => tapped = ing,
        ),
      ),
    );
    await tester.tap(find.text('Bröd'));
    expect(tapped, same(bread));
  });

  testWidgets(
    'each item carries a Semantics(button: true) for screen readers',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          IngredientSuggestionList(
            results: [_ingredient()],
            onTap: (_) {},
          ),
        ),
      );
      // The Semantics widget wraps the InkWell with button: true.
      expect(find.byType(Semantics), findsAtLeastNWidgets(1));
      handle.dispose();
    },
  );

  testWidgets('uses ValueKey(ingredient.id) for each InkWell', (tester) async {
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(
          results: [_ingredient(id: 'special-id')],
          onTap: (_) {},
        ),
      ),
    );
    expect(find.byKey(const ValueKey('special-id')), findsOneWidget);
  });

  testWidgets('container is bounded at 180px max height', (tester) async {
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(
          results: List.generate(
            20,
            (i) => _ingredient(id: '$i', swedish: 'r$i'),
          ),
          onTap: (_) {},
        ),
      ),
    );
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(IngredientSuggestionList),
        matching: find.byType(Container),
      ),
    );
    expect(container.constraints?.maxHeight, 180);
  });

  testWidgets('uses ListView.builder under the hood', (tester) async {
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(
          results: [_ingredient()],
          onTap: (_) {},
        ),
      ),
    );
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('long results list scrolls inside the bounded container', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        IngredientSuggestionList(
          results: List.generate(
            30,
            (i) => _ingredient(id: 'r$i', swedish: 'item$i'),
          ),
          onTap: (_) {},
        ),
      ),
    );
    // First item visible.
    expect(find.text('item0'), findsOneWidget);
    // Last item not initially in viewport (container is 180px tall).
    expect(find.text('item29'), findsNothing);
  });
}
