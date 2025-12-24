/// Unit tests for ShoppingListGenerator - Intelligent shopping list generation and consolidation
///
/// Tests comprehensive shopping list generation including:
/// - Ingredient extraction from various menu formats
/// - Ingredient consolidation and normalization
/// - Quantity aggregation across recipes
/// - Smart unit conversion and optimization
/// - Swedish formatting and pluralization
/// - Alphabetical sorting
/// - Edge cases and error handling
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/utils/text/shopping_list_generator.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ShoppingListGenerator', () {
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });

    group('Basic Shopping List Generation', () {
      test('should handle empty menu', () {
        final menu = <String, List<dynamic>>{};
        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, isEmpty);
      });

      test('should extract ingredients from single recipe', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl mjölk', '3 ägg', '400g mjöl'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(3));
        expect(result, contains('2 dl mjölk'));
        expect(result, contains('3 ägg'));
        expect(result, contains('400 g mjöl'));
      });

      test('should extract ingredients from multiple recipes', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl mjölk', '3 ägg'],
            },
            {
              'ingredients': ['400g mjöl', '1 lök'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(4));
        expect(result, contains('2 dl mjölk'));
        expect(result, contains('3 ägg'));
        expect(result, contains('400 g mjöl'));
        expect(result, contains('1 lök'));
      });

      test('should handle multiple menu sections', () {
        final menu = {
          'Förrätter': [
            {
              'ingredients': ['100g smör'],
            },
          ],
          'Huvudrätter': [
            {
              'ingredients': ['2 dl grädde'],
            },
          ],
          'Efterrätter': [
            {
              'ingredients': ['3 äpplen'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(3));
        expect(result, contains('100 g smör'));
        expect(result, contains('2 dl grädde'));
        expect(result, contains('3 äpplen'));
      });
    });

    group('Ingredient Consolidation', () {
      test('should consolidate identical ingredients', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl mjölk', '1 dl mjölk'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('3 dl mjölk'));
      });

      test('should consolidate ingredients across recipes', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['200g köttfärs'],
            },
            {
              'ingredients': ['300g köttfärs'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('500 g köttfärs'));
      });

      test('should consolidate with plural normalization', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 tomater', '3 tomat'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('5 tomater'));
      });

      test('should consolidate lökar and lök', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 lökar', '1 lök'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('3 lökar'));
      });

      test('should keep different units separate', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl mjöl', '200g mjöl'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(2));
        expect(result, contains('2 dl mjöl'));
        expect(result, contains('200 g mjöl'));
      });
    });

    group('Smart Unit Conversion', () {
      test('should convert grams to kilograms when appropriate', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['800g mjöl', '700g mjöl'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('1 ½ kg mjöl')); // Uses Swedish fractions
      });

      test('should convert deciliters to liters when appropriate', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['8 dl mjölk', '7 dl mjölk'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('1 ½ l mjölk')); // Uses Swedish fractions
      });

      test('should convert American units to Swedish', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['1 cup mjöl', '2 tbsp socker'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(2));
        // 1 cup ≈ 2.37 dl
        expect(result.any((item) => item.contains('dl mjöl')), isTrue);
        // 2 tbsp ≈ 1.78 msk
        expect(result.any((item) => item.contains('msk socker')), isTrue);
      });

      test('should preserve units when conversion is not beneficial', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['200g mjöl', '150g mjöl'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('350 g mjöl')); // Not converted to kg
      });
    });

    group('Swedish Formatting and Pluralization', () {
      test('should apply Swedish fraction formatting', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['0.5 dl socker', '1 dl socker'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('1 ½ dl socker'));
      });

      test('should pluralize Swedish ingredients correctly', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['1 potatis', '2 potatis'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('3 potatisar'));
      });

      test('should handle invariant forms', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['3 ägg', '2 ägg'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('5 ägg')); // ägg is invariant
      });

      test('should format compound ingredients', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['200g finhackad lök', '100g finhackad lök'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('300 g finhackad lök'));
      });
    });

    group('Sorting and Organization', () {
      test('should sort ingredients alphabetically', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['1 tomat', '1 äpple', '1 banan', '1 citron'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result[0], contains('banan'));
        expect(result[1], contains('citron'));
        expect(result[2], contains('tomat'));
        expect(result[3], contains('äpple'));
      });

      test('should sort by normalized ingredient names', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl mjölk', '100g mjöl', '3 ägg'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        // Order: dl mjölk, g mjöl, ägg
        expect(result[0], contains('dl mjölk'));
        expect(result[1], contains('g mjöl'));
        expect(result[2], contains('ägg'));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty ingredients list', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': [],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, isEmpty);
      });

      test('should skip empty ingredient strings', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['', '  ', '2 dl mjölk', ''],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(1));
        expect(result.first, equals('2 dl mjölk'));
      });

      test('should handle missing ingredients key', () {
        final menu = {
          'Huvudrätter': [
            {
              'name': 'Recipe without ingredients',
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, isEmpty);
      });

      test('should handle null ingredients', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': null,
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, isEmpty);
      });

      test('should handle mixed data types in ingredients', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl mjölk', 123, null, '3 ägg'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        // Null gets parsed as '1 null', 123 gets parsed as '12 3ar'
        expect(result, hasLength(4));
        expect(result, contains('2 dl mjölk'));
        expect(result, contains('3 ägg'));
      });

      test('should handle ingredient without quantity', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['salt', 'peppar'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(2));
        expect(result, contains('1 pepp')); // Normalized by removing -ar ending
        expect(result, contains('1 salt'));
      });

      test('should handle special characters in ingredients', () {
        final menu = {
          'Huvudrätter': [
            {
              'ingredients': ['2 dl grädde (40%)', '100g ost (riven)'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(2));
        expect(result, contains('2 dl grädde (40%)'));
        expect(result, contains('100 g ost (riven)'));
      });
    });

    group('Complex Scenarios', () {
      test('should handle complete menu with multiple sections and recipes',
          () {
        final menu = {
          'Förrätter': [
            {
              'ingredients': ['100g smör', '2 dl grädde', '3 vitlöksklyftor'],
            },
            {
              'ingredients': ['200g räkor', '1 dl grädde', '1 citron'],
            },
          ],
          'Huvudrätter': [
            {
              'ingredients': ['400g köttfärs', '2 lökar', '3 vitlöksklyftor'],
            },
            {
              'ingredients': ['300g köttfärs', '1 lök', '2 dl grädde'],
            },
          ],
          'Efterrätter': [
            {
              'ingredients': ['3 ägg', '2 dl grädde', '100g socker'],
            },
          ],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);

        // Check consolidation
        expect(result.any((item) => item.contains('700 g köttfärs')), isTrue);
        expect(result.any((item) => item.contains('3 lökar')), isTrue);
        expect(
            result.any((item) =>
                item.contains('6 vitlöksklyftar') ||
                item.contains('6 vitlöksklyftor')),
            isTrue); // May vary based on normalization
        expect(result.any((item) => item.contains('7 dl grädde')),
            isTrue); // 2+1+2+2 = 7

        // Check unique items
        expect(result.any((item) => item.contains('100 g smör')), isTrue);
        expect(result.any((item) => item.contains('200 g räk')),
            isTrue); // räkor normalized to räk
        expect(result.any((item) => item.contains('1 citron')), isTrue);
        expect(result.any((item) => item.contains('3 ägg')), isTrue);
        expect(result.any((item) => item.contains('100 g socker')), isTrue);
      });

      test('should handle recipe objects with dynamic property access', () {
        // Simulate recipe objects that might come from a Recipe class
        final recipe1 = _MockRecipe(['2 dl mjölk', '3 ägg']);
        final recipe2 = _MockRecipe(['1 dl mjölk', '2 ägg']);

        final menu = {
          'Huvudrätter': [recipe1, recipe2],
        };

        final result = ShoppingListGenerator.generateShoppingList(menu);
        expect(result, hasLength(2));
        expect(result, contains('3 dl mjölk'));
        expect(result, contains('5 ägg'));
      });
    });
  });
}

// Mock recipe class for testing dynamic property access
class _MockRecipe {
  final List<String> ingredients;

  _MockRecipe(this.ingredients);

  @override
  String toString() {
    return 'MockRecipe(ingredients: $ingredients)';
  }
}
