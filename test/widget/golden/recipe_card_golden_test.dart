import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/content_card.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('RecipeCard Golden Tests', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('recipe card with image matches golden', (tester) async {
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

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 375,
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              style: ContentCardStyle.detailed,
              onTap: () {},
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(ContentCard),
        matchesGoldenFile('goldens/recipe_card_detailed.png'),
      );
    });

    testWidgets('recipe card grid style matches golden', (tester) async {
      final recipe = RecipeFactory.build(
        id: 'golden_2',
        title: 'Fisksoppa',
        description: 'Värmande soppa',
        imageUrls: [],
        mealType: 'Lunch',
        portions: 6,
        timeMinutes: 30,
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 180,
            height: 240,
            child: ContentCard(
              item: recipe,
              type: ContentCardType.recipe,
              style: ContentCardStyle.grid,
              onTap: () {},
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(ContentCard),
        matchesGoldenFile('goldens/recipe_card_grid.png'),
      );
    });
  });
}
