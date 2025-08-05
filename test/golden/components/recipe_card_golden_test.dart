import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import '../../helpers/mock_factories.dart';
import '../../golden_test_configuration.dart';
import '../golden_test_config.dart';

void main() {
  configureGoldenTests();
  group('RecipeCard Golden Tests', () {
    // Create test recipes with different states
    final basicRecipe = RecipeFactory.build(
      title: 'Pasta Carbonara',
      description: 'Classic Italian pasta with eggs, cheese, and bacon',
      timeMinutes: 20,
      portions: 4,
      imageUrls: [GoldenTestData.placeholderImageUrl],
      tags: ['Italian', 'Quick', 'Pasta'],
    );

    final longTitleRecipe = RecipeFactory.build(
      title:
          'Super Delicious Homemade Triple Chocolate Fudge Brownies with Extra Toppings',
      description: 'The most decadent brownies you will ever taste',
      timeMinutes: 45,
      portions: 12,
      imageUrls: [GoldenTestData.placeholderImageUrl],
      tags: ['Dessert', 'Chocolate', 'Baking', 'Sweet', 'Party'],
    );

    final noImageRecipe = RecipeFactory.build(
      title: 'Simple Salad',
      description: 'Fresh and healthy green salad',
      timeMinutes: 10,
      portions: 2,
      imageUrls: [],
      tags: ['Healthy', 'Quick'],
    );

    final minimalRecipe = RecipeFactory.build(
      id: 'minimal',
      title: 'Minimal Recipe',
      ingredients: [],
      instructions: [],
      portions: 1,
      userId: 'user123',
      description: '',
      imageUrls: [],
      timeMinutes: null,
      tags: [],
    );

    // Define recipe variants for testing
    final recipeVariants = [
      ('basic', basicRecipe),
      ('long_title', longTitleRecipe),
      ('no_image', noImageRecipe),
      ('minimal', minimalRecipe),
    ];

    testGoldens('RecipeCard renders correctly across themes and devices',
        (tester) async {
      final builder = GoldenBuilder.grid(
        columns: 2,
        widthToHeightRatio: 1.2,
      );

      for (final (name, recipe) in recipeVariants) {
        builder.addScenario(
          'RecipeCard - $name',
          RecipeCard(
            recipe: recipe,
            onTap: (_) {},
          ),
        );
      }

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(800, 1200),
      );
      await screenMatchesGolden(tester, 'recipe_card');
    });

    testGoldens('RecipeCard with interactions', (tester) async {
      final builder = GoldenBuilder.column();

      builder.addScenario(
        'With favorite button',
        RecipeCard(
          recipe: basicRecipe,
          showFavoriteButton: true,
          onTap: (_) {},
          onFavoriteToggle: (_) {},
        ),
      );

      builder.addScenario(
        'With context menu',
        RecipeCard(
          recipe: basicRecipe,
          showContextMenu: true,
          onTap: (_) {},
        ),
      );

      builder.addScenario(
        'Selected state',
        RecipeCard(
          recipe: basicRecipe,
          isSelected: true,
          onTap: (_) {},
        ),
      );

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(400, 1200),
      );
      await screenMatchesGolden(tester, 'recipe_card_interactions');
    });

    testGoldens('RecipeCard responsive layout', (tester) async {
      await tester.pumpWidgetBuilder(
        CustomGoldenScenario(
          name: 'Recipe Grid',
          constraints: const BoxConstraints(maxWidth: 800),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final recipes = [
                basicRecipe,
                longTitleRecipe,
                noImageRecipe,
                minimalRecipe,
              ];
              return RecipeCard(
                recipe: recipes[index],
                onTap: (_) {},
              );
            },
          ),
        ),
        surfaceSize: const Size(800, 600),
      );
      await screenMatchesGolden(tester, 'recipe_card_responsive');
    });

    testGoldens('RecipeCard with text scaling', (tester) async {
      final builder = GoldenBuilder.grid(
        columns: 2,
        widthToHeightRatio: 1.2,
      );

      for (final scale in [0.8, 1.0, 1.5, 2.0]) {
        builder.addScenario(
          'Text scale ${scale}x',
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: RecipeCard(
              recipe: basicRecipe,
              onTap: (_) {},
            ),
          ),
        );
      }

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(800, 800),
      );
      await screenMatchesGolden(tester, 'recipe_card_text_scaling');
    });

    testGoldens('RecipeCard loading states', (tester) async {
      final builder = GoldenBuilder.column();

      builder.addScenario(
        'Loading shimmer',
        Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );

      builder.addScenario(
        'Error state',
        Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 8),
              Text('Failed to load recipe',
                  style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );

      await tester.pumpWidgetBuilder(
        builder.build(),
        surfaceSize: const Size(400, 600),
      );
      await screenMatchesGolden(tester, 'recipe_card_loading');
    });
  });
}
