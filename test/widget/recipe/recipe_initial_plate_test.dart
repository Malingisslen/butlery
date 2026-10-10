import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('RecipeInitialPlate.initialOf', () {
    test('upper-cases the first letter of the title', () {
      expect(RecipeInitialPlate.initialOf('pannkakor'), 'P');
    });

    test('skips leading whitespace and upper-cases Swedish letters', () {
      expect(RecipeInitialPlate.initialOf('  äggröra'), 'Ä');
    });

    test('is empty for an empty or blank title', () {
      expect(RecipeInitialPlate.initialOf(''), '');
      expect(RecipeInitialPlate.initialOf('   '), '');
    });
  });

  testWidgets('the plate shows the initial on the theme surface in '
      'onSurfaceVariant', (tester) async {
    late ColorScheme cs;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            cs = Theme.of(context).colorScheme;
            return const SizedBox(
              width: 120,
              height: 90,
              child: RecipeInitialPlate(title: 'ärtsoppa'),
            );
          },
        ),
      ),
    );

    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byType(RecipeInitialPlate),
              matching: find.byType(ColoredBox),
            ),
          )
          .color,
      cs.surfaceContainerHighest,
    );
    expect(
      tester.widget<Text>(find.text('Ä')).style!.color,
      cs.onSurfaceVariant,
    );
  });
}
