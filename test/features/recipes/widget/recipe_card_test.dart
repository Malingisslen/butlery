/// Comprehensive widget tests for RecipeCard following Flutter widget testing best practices.
///
/// This test suite validates UI rendering, user interactions, accessibility compliance,
/// state management integration, and responsive behavior using comprehensive test scenarios
/// and proper widget testing methodology.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../helpers/test_service_locator.dart';
import '../../../helpers/test_helpers.dart';

void main() {
  group('RecipeCard Widget Tests', () {
    late Recipe testRecipe;
    setUp(() {
      TestServiceLocator.initialize();

      testRecipe = TestServiceLocator.createTestRecipe(
        id: 'recipe_card_test',
        title: 'Test Recipe Card',
        description: 'A delicious test recipe for widget testing',
        ingredients: ['Test Ingredient 1', 'Test Ingredient 2'],
        instructions: ['Test Step 1', 'Test Step 2'],
      );
    });

    tearDown(() {
      TestServiceLocator.reset();
    });

    group('basic rendering', () {
      testWidgets('should render recipe card with basic information',
          (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
            ),
          );

          // Then
          expect(find.text('Test Recipe Card'), findsOneWidget);
          expect(find.text('A delicious test recipe for widget testing'),
              findsOneWidget);
        });
      });

      testWidgets('should render recipe image when available', (tester) async {
        // Given
        final recipeWithImage = TestServiceLocator.createTestRecipe(
          title: 'Recipe with Image',
        );
        recipeWithImage.core.imageUrls = [
          'https://example.com/recipe-image.jpg'
        ];

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: recipeWithImage),
            ),
          );

          // Then
          expect(find.byType(Image), findsOneWidget);
        });
      });

      testWidgets('should render placeholder when no image available',
          (tester) async {
        // Given
        final recipeWithoutImage = TestServiceLocator.createTestRecipe(
          title: 'Recipe without Image',
        );
        recipeWithoutImage.core.imageUrls = [];

        // When
        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(recipe: recipeWithoutImage),
          ),
        );

        // Then
        expect(find.byIcon(Icons.restaurant), findsOneWidget);
      });

      testWidgets('should display meal type badge', (tester) async {
        // Given
        testRecipe.core.mealType = 'Middag';

        // When
        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(recipe: testRecipe),
          ),
        );

        // Then
        expect(find.text('Middag'), findsOneWidget);
      });

      testWidgets('should display cooking time when available', (tester) async {
        // Given
        testRecipe.core.timeMinutes = 30;

        // When
        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(recipe: testRecipe),
          ),
        );

        // Then
        expect(find.text('30 min'), findsOneWidget);
        expect(find.byIcon(Icons.access_time), findsOneWidget);
      });

      testWidgets('should display portions when available', (tester) async {
        // Given
        testRecipe.core.portions = 4;

        // When
        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(recipe: testRecipe),
          ),
        );

        // Then
        expect(find.text('4 portioner'), findsOneWidget);
        expect(find.byIcon(Icons.people), findsOneWidget);
      });

      testWidgets('should display rating when available', (tester) async {
        // Given
        testRecipe.core.rating = 4.5;

        // When
        await tester.pumpWidget(
          createTestableWidget(
            child: RecipeCard(recipe: testRecipe),
          ),
        );

        // Then
        expect(find.text('4.5'), findsOneWidget);
        expect(find.byIcon(Icons.star), findsOneWidget);
      });
    });

    group('user interactions', () {
      testWidgets('should handle tap gesture', (tester) async {
        // Given
        Recipe? tappedRecipe;

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(
                recipe: testRecipe,
                onTap: (recipe) {
                  tappedRecipe = recipe;
                },
              ),
            ),
          );

          await tester.tap(find.byType(RecipeCard));
          await tester.pumpAndSettle();

          // Then
          expect(tappedRecipe, equals(testRecipe));
        });
      });

      testWidgets('should handle long press gesture', (tester) async {
        // Given
        Recipe? longPressedRecipe;

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(
                recipe: testRecipe,
                onLongPress: (recipe) {
                  longPressedRecipe = recipe;
                },
              ),
            ),
          );

          await tester.longPress(find.byType(RecipeCard));
          await tester.pumpAndSettle();

          // Then
          expect(longPressedRecipe, equals(testRecipe));
        });
      });

      testWidgets('should show context menu on long press', (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(
                recipe: testRecipe,
                showContextMenu: true,
              ),
            ),
          );

          await tester.longPress(find.byType(RecipeCard));
          await tester.pumpAndSettle();

          // Then
          expect(find.text('Redigera'), findsOneWidget);
          expect(find.text('Dela'), findsOneWidget);
          expect(find.text('Ta bort'), findsOneWidget);
        });
      });

      testWidgets('should handle favorite button tap', (tester) async {
        // Given
        bool favoriteTapped = false;

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(
                recipe: testRecipe,
                showFavoriteButton: true,
                onFavoriteToggle: (recipe) {
                  favoriteTapped = true;
                },
              ),
            ),
          );

          await tester.tap(find.byIcon(Icons.favorite_border));
          await tester.pumpAndSettle();

          // Then
          expect(favoriteTapped, isTrue);
        });
      });
    });

    group('accessibility', () {
      testWidgets('should have proper accessibility labels', (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
            ),
          );

          // Then
          expect(
            find.bySemanticsLabel('Recipe: Test Recipe Card'),
            findsOneWidget,
          );
        });
      });

      testWidgets('should have proper touch target size', (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
            ),
          );

          // Then
          final cardFinder = find.byType(RecipeCard);
          final RenderBox cardBox = tester.renderObject(cardFinder);
          expect(cardBox.size.height,
              greaterThanOrEqualTo(48.0)); // Minimum touch target
        });
      });

      testWidgets('should support screen reader navigation', (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
            ),
          );

          // Then
          expect(find.bySemanticsLabel(RegExp('.*Test Recipe Card.*')),
              findsOneWidget);
        });
      });
    });

    group('responsive design', () {
      testWidgets('should adapt to different screen sizes - phone',
          (tester) async {
        // Given
        tester.view.physicalSize = const Size(375, 667); // iPhone SE
        tester.view.devicePixelRatio = 2.0;

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
            ),
          );

          // Then
          final cardFinder = find.byType(RecipeCard);
          final RenderBox cardBox = tester.renderObject(cardFinder);
          expect(cardBox.size.width, lessThanOrEqualTo(375.0));
        });

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      });

      testWidgets('should adapt to different screen sizes - tablet',
          (tester) async {
        // Given
        tester.view.physicalSize = const Size(768, 1024); // iPad
        tester.view.devicePixelRatio = 2.0;

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
            ),
          );

          // Then
          final cardFinder = find.byType(RecipeCard);
          expect(cardFinder, findsOneWidget);
          // Card should render appropriately for larger screens
        });

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      });
    });

    // State management integration tests removed - RecipeCard is now a simple stateless widget

    group('edge cases', () {
      testWidgets('should handle very long recipe titles gracefully',
          (tester) async {
        // Given
        final longTitleRecipe = TestServiceLocator.createTestRecipe(
          title:
              'This is a very long recipe title that might overflow and cause UI issues if not handled properly',
        );

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: longTitleRecipe),
            ),
          );

          // Then
          expect(find.textContaining('This is a very long recipe title'),
              findsOneWidget);
          // Verify that the widget doesn't overflow
          expect(tester.takeException(), isNull);
        });
      });

      testWidgets('should handle empty description gracefully', (tester) async {
        // Given
        final emptyDescriptionRecipe = TestServiceLocator.createTestRecipe(
          title: 'Recipe with Empty Description',
          description: '',
        );

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: emptyDescriptionRecipe),
            ),
          );

          // Then
          expect(find.text('Recipe with Empty Description'), findsOneWidget);
          // Should not crash with empty description
          expect(tester.takeException(), isNull);
        });
      });

      testWidgets('should handle missing metadata gracefully', (tester) async {
        // Given
        final minimalRecipe = TestServiceLocator.createTestRecipe(
          title: 'Minimal Recipe',
        );
        minimalRecipe.core.timeMinutes = null;
        minimalRecipe.core.portions = null;
        minimalRecipe.core.rating = null;

        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: minimalRecipe),
            ),
          );

          // Then
          expect(find.text('Minimal Recipe'), findsOneWidget);
          // Should not show metadata that doesn't exist
          expect(find.byIcon(Icons.access_time), findsNothing);
          expect(find.byIcon(Icons.people), findsNothing);
          expect(find.byIcon(Icons.star), findsNothing);
        });
      });
    });

    group('theme integration', () {
      testWidgets('should adapt to dark theme', (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
              theme: ThemeData.dark(),
            ),
          );

          // Then
          expect(find.text('Test Recipe Card'), findsOneWidget);
          // Verify that the widget renders correctly in dark theme
          expect(tester.takeException(), isNull);
        });
      });

      testWidgets('should adapt to light theme', (tester) async {
        // Given
        await tester.runAsync(() async {
          // When
          await tester.pumpWidget(
            createTestableWidget(
              child: RecipeCard(recipe: testRecipe),
              theme: ThemeData.light(),
            ),
          );

          // Then
          expect(find.text('Test Recipe Card'), findsOneWidget);
          // Verify that the widget renders correctly in light theme
          expect(tester.takeException(), isNull);
        });
      });
    });

    group('performance', () {
      testWidgets('should rebuild efficiently when recipe changes',
          (tester) async {
        // Given
        Recipe updatedRecipe = testRecipe;

        await tester.runAsync(() async {
          // When - Initial render
          await tester.pumpWidget(
            createTestableWidget(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      RecipeCard(recipe: updatedRecipe),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            updatedRecipe = TestServiceLocator.createTestRecipe(
                              id: testRecipe.id,
                              title: 'Updated Recipe Title',
                            );
                          });
                        },
                        child: const Text('Update'),
                      ),
                    ],
                  );
                },
              ),
            ),
          );

          // Then - Initial state
          expect(find.text('Test Recipe Card'), findsOneWidget);

          // When - Update recipe
          await tester.tap(find.text('Update'));
          await tester.pumpAndSettle();

          // Then - Updated state
          expect(find.text('Updated Recipe Title'), findsOneWidget);
          expect(find.text('Test Recipe Card'), findsNothing);
        });
      });
    });
  });
}
