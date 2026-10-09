import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/widgets/recipe/recipe_image_states.dart';
import 'package:butlery/widgets/recipe/recipe_initial_plate.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('recipe card without a photo (B-04)', () {
    // The grid tile keeps its image box: a plate beside the title and the
    // buttons does not fit in a half-width tile.
    for (final style in [RecipeCardStyle.detailed, RecipeCardStyle.compact]) {
      testWidgets('$style collapses the image box to a 36 dp plate', (
        tester,
      ) async {
        final recipe = RecipeFactory.build(
          id: 'r1',
          title: 'Fisksoppa',
          imageUrls: [],
        );
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: SizedBox(
              width: 360,
              child: RecipeCard(recipe: recipe, style: style, onTap: (_) {}),
            ),
          ),
        );

        final plate = find.byType(RecipeInitialPlate);
        expect(plate, findsOneWidget);
        expect(tester.getSize(plate), const Size(36, 36));
        expect(find.text('F'), findsOneWidget);
      });
    }
  });

  testWidgets('a photo that failed to load keeps its area and says so', (
    tester,
  ) async {
    late ColorScheme cs;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            cs = Theme.of(context).colorScheme;
            return const SizedBox(
              width: 360,
              height: 200,
              child: RecipeImageFailedPlate(),
            );
          },
        ),
      ),
    );

    expect(find.text('Bilden kunde inte visas'), findsOneWidget);
    expect(
      tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byType(RecipeImageFailedPlate),
              matching: find.byType(ColoredBox),
            ),
          )
          .color,
      cs.surfaceContainerHighest,
    );
    expect(tester.getSize(find.byType(RecipeImageFailedPlate)).height, 200);
  });

  testWidgets('the add-photo chip is 48 dp tall and fires its callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Center(child: RecipeAddPhotoChip(onPressed: () => taps++)),
      ),
    );

    expect(find.text('Lägg till foto'), findsOneWidget);
    expect(
      tester.getSize(find.byType(RecipeAddPhotoChip)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(RecipeAddPhotoChip));
    expect(taps, 1);
  });
}
