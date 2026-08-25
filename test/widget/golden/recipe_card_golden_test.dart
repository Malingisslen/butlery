import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/content_card.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../test_support/base_unit_test.dart';
import 'golden_helper.dart';

void main() {
  group('RecipeCard Golden Tests', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    butleryGolden(
      'recipe card with image matches golden',
      file: 'goldens/recipe_card_detailed.png',
      width: 375,
      height: null,
      target: find.byType(ContentCard),
      build: () {
        final recipe = RecipeFactory.build(
          id: 'golden_1',
          title: 'Köttbullar med potatismos',
          description: 'Klassisk svensk husmanskost',
          imageUrls: [],
          mealType: 'Middag',
          portions: 4,
          timeMinutes: 45,
          rating: 4.5,
        );
        return ContentCard(
          item: recipe,
          type: ContentCardType.recipe,
          style: ContentCardStyle.detailed,
          onTap: () {},
        );
      },
    );

    butleryGolden(
      'recipe card grid style matches golden',
      file: 'goldens/recipe_card_grid.png',
      // No height: a grid card sizes to its own content since BUT-1911, and
      // the row it sits in takes the height of its tallest card. Pinning one
      // here would measure a card the screen never draws.
      //
      // The pixels were re-pinned in that commit.
      width: 180,
      height: null,
      target: find.byType(ContentCard),
      build: () {
        final recipe = RecipeFactory.build(
          id: 'golden_2',
          title: 'Fisksoppa',
          description: 'Värmande soppa',
          imageUrls: [],
          mealType: 'Lunch',
          portions: 6,
          timeMinutes: 30,
        );
        return ContentCard(
          item: recipe,
          type: ContentCardType.recipe,
          style: ContentCardStyle.grid,
          onTap: () {},
        );
      },
    );
  });
}
