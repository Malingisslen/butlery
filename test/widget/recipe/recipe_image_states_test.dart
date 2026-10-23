import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
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

  testWidgets('the add-photo button is 48 dp, named, and fires its callback', (
    tester,
  ) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: UnconstrainedBox(
            child: RecipeAddPhotoIconButton(onPressed: () => taps++),
          ),
        ),
      );

      final size = tester.getSize(find.byType(RecipeAddPhotoIconButton));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(find.byType(RecipeAddPhotoIconButton)).label,
        contains(AppLocalizationsSv().recipeAddPhoto),
      );
      await tester.tap(find.byType(RecipeAddPhotoIconButton));
      expect(taps, 1);
    } finally {
      handle.dispose();
    }
  });
}
