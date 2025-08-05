import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import '../../helpers/mock_factories.dart';
import '../../golden_test_configuration.dart';

void main() {
  configureGoldenTests();

  group('RecipeCard Golden Tests (No Network)', () {
    testGoldens('recipe card without images', (tester) async {
      // Create recipes without image URLs to avoid network requests
      final recipes = [
        RecipeFactory.build(
          title: 'Pasta Carbonara',
          description: 'Classic Italian pasta',
          timeMinutes: 20,
          portions: 4,
          imageUrls: [], // No images
          tags: ['Italian', 'Quick'],
        ),
        RecipeFactory.build(
          title: 'Long Title Recipe That Should Wrap to Multiple Lines',
          description: 'A very detailed description that explains the recipe',
          timeMinutes: 45,
          portions: 8,
          imageUrls: [], // No images
          tags: ['Dessert', 'Baking'],
        ),
      ];

      final builder = GoldenBuilder.grid(
        columns: 1,
        widthToHeightRatio: 2,
      );

      for (int i = 0; i < recipes.length; i++) {
        builder.addScenario(
          'Recipe ${i + 1}',
          SizedBox(
            width: 300,
            child: RecipeCard(
              recipe: recipes[i],
              onTap: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(
          theme: ThemeData.light(),
        ),
        surfaceSize: const Size(400, 800),
      );
      
      await screenMatchesGolden(tester, 'recipe_card_no_images');
    });

    testGoldens('recipe card states', (tester) async {
      final recipe = RecipeFactory.build(
        title: 'Test Recipe',
        description: 'For testing different states',
        timeMinutes: 30,
        portions: 4,
        imageUrls: [], // No images
      );

      final builder = GoldenBuilder.column();

      builder.addScenario(
        'Default',
        SizedBox(
          width: 300,
          child: RecipeCard(
            recipe: recipe,
            onTap: (_) {},
          ),
        ),
      );

      builder.addScenario(
        'Selected',
        SizedBox(
          width: 300,
          child: RecipeCard(
            recipe: recipe,
            isSelected: true,
            onTap: (_) {},
          ),
        ),
      );

      builder.addScenario(
        'With Favorite',
        SizedBox(
          width: 300,
          child: RecipeCard(
            recipe: recipe,
            showFavoriteButton: true,
            onTap: (_) {},
            onFavoriteToggle: (_) {},
          ),
        ),
      );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(
          theme: ThemeData.light(),
        ),
        surfaceSize: const Size(400, 900),
      );
      
      await screenMatchesGolden(tester, 'recipe_card_states');
    });
  });
}