import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('MenuService', () {
    late MenuService menuService;
    late List<Recipe> testRecipes;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() {
      // Reset singleton for test isolation
      SingletonServiceMixin.resetForTesting();
      
      // Create service
      menuService = MenuService();
      
      // Create test recipes with different meal types
      testRecipes = [
        // Breakfasts
        RecipeFactory.build(
          id: 'breakfast1',
          title: 'Havregrynsgröt',
          mealType: 'Frukost',
        ),
        RecipeFactory.build(
          id: 'breakfast2',
          title: 'Äggmacka',
          mealType: 'Frukost',
        ),
        RecipeFactory.build(
          id: 'breakfast3',
          title: 'Smoothie bowl',
          mealType: 'Frukost',
        ),
        RecipeFactory.build(
          id: 'breakfast4',
          title: 'Yoghurt med müsli',
          mealType: 'Frukost',
        ),
        RecipeFactory.build(
          id: 'breakfast5',
          title: 'Pannkakor',
          mealType: 'Frukost',
        ),
        
        // Lunches
        RecipeFactory.build(
          id: 'lunch1',
          title: 'Caesarsallad',
          mealType: 'Lunch',
        ),
        RecipeFactory.build(
          id: 'lunch2',
          title: 'Pasta Carbonara',
          mealType: 'Lunch',
        ),
        RecipeFactory.build(
          id: 'lunch3',
          title: 'Soppor',
          mealType: 'Lunch',
        ),
        RecipeFactory.build(
          id: 'lunch4',
          title: 'Wraps',
          mealType: 'Lunch',
        ),
        
        // Dinners
        RecipeFactory.build(
          id: 'dinner1',
          title: 'Köttbullar',
          mealType: 'Middag',
        ),
        RecipeFactory.build(
          id: 'dinner2',
          title: 'Lax med potatis',
          mealType: 'Middag',
        ),
        RecipeFactory.build(
          id: 'dinner3',
          title: 'Tacos',
          mealType: 'Middag',
        ),
        RecipeFactory.build(
          id: 'dinner4',
          title: 'Pizza',
          mealType: 'Middag',
        ),
        RecipeFactory.build(
          id: 'dinner5',
          title: 'Lasagne',
          mealType: 'Middag',
        ),
        RecipeFactory.build(
          id: 'dinner6',
          title: 'Kyckling curry',
          mealType: 'Middag',
        ),
        
        // Snacks
        RecipeFactory.build(
          id: 'snack1',
          title: 'Fruktsallad',
          mealType: 'Mellanmål',
        ),
        RecipeFactory.build(
          id: 'snack2',
          title: 'Nötter',
          mealType: 'Mellanmål',
        ),
        
        // Desserts
        RecipeFactory.build(
          id: 'dessert1',
          title: 'Kladdkaka',
          mealType: 'Efterrätt',
        ),
        RecipeFactory.build(
          id: 'dessert2',
          title: 'Glass',
          mealType: 'Efterrätt',
        ),
      ];
    });
    
    tearDown(() async {
      SingletonServiceMixin.resetForTesting();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Service Identification', () {
      test('should have correct service name', () {
        // Assert
        expect(menuService.serviceName, equals('MenuService'));
      });
      
      test('should be singleton instance', () {
        // Arrange & Act
        final instance1 = MenuService();
        final instance2 = MenuService();
        
        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });
    
    group('Natural Language Processing - Swedish Numbers', () {
      test('should parse Swedish word numbers correctly', () async {
        // Arrange
        const input = 'tre frukoster';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu.containsKey('Frukost'), isTrue);
        expect(menu['Frukost']?.length, equals(3));
      });
      
      test('should handle all Swedish numbers from en to tio', () async {
        // Test each Swedish number
        final testCases = {
          'en frukost': 1,
          'två frukoster': 2,
          'tre frukoster': 3,
          'fyra frukoster': 4,
          'fem frukoster': 5,
          'sex middagar': 6,  // Note: using middag to avoid running out of breakfast recipes
          'sju middagar': 6,  // Limited by available recipes (6 dinners)
          'åtta middagar': 6,
          'nio middagar': 6,
          'tio middagar': 6,
        };
        
        for (final entry in testCases.entries) {
          final menu = await menuService.generateMenuFromPrompt(entry.key, testRecipes);
          final mealType = entry.key.contains('frukost') ? 'Frukost' : 'Middag';
          expect(
            menu[mealType]?.length,
            equals(entry.value),
            reason: 'Failed for input: ${entry.key}',
          );
        }
      });
      
      test('should handle ett variant for en', () async {
        // Arrange
        const input = 'ett mellanmål';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Mellanmål']?.length, equals(1));
      });
    });
    
    group('Natural Language Processing - Numeric Digits', () {
      test('should parse numeric digits correctly', () async {
        // Arrange
        const input = '3 frukoster';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
      });
      
      test('should handle mixed numeric and word numbers', () async {
        // Arrange
        const input = '3 frukoster och två middagar';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Middag']?.length, equals(2));
      });
    });
    
    group('Meal Type Detection', () {
      test('should detect Frukost correctly', () async {
        // Test variations
        final variations = [
          'frukost',
          'frukoster',
          'frukostar',
        ];
        
        for (final variation in variations) {
          final menu = await menuService.generateMenuFromPrompt(
            '2 $variation',
            testRecipes,
          );
          expect(menu.containsKey('Frukost'), isTrue,
              reason: 'Failed for variation: $variation');
        }
      });
      
      test('should detect Lunch correctly', () async {
        // Arrange
        const input = 'två luncher';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu.containsKey('Lunch'), isTrue);
        expect(menu['Lunch']?.length, equals(2));
      });
      
      test('should detect Middag correctly', () async {
        // Arrange
        const input = 'fem middagar';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu.containsKey('Middag'), isTrue);
        expect(menu['Middag']?.length, equals(5));
      });
      
      test('should detect Mellanmål correctly', () async {
        // Arrange
        const input = 'två mellanmål';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu.containsKey('Mellanmål'), isTrue);
        expect(menu['Mellanmål']?.length, equals(2));
      });
      
      test('should detect Efterrätt correctly', () async {
        // Arrange
        const input = 'en efterrätt';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu.containsKey('Efterrätt'), isTrue);
        expect(menu['Efterrätt']?.length, equals(1));
      });
      
      test('should handle plural normalization', () async {
        // Test that plural forms are normalized correctly
        final testCases = {
          'middagar': 'Middag',
          'luncher': 'Lunch',
          'frukoster': 'Frukost',
          'frukostar': 'Frukost',
        };
        
        for (final entry in testCases.entries) {
          final menu = await menuService.generateMenuFromPrompt(
            '1 ${entry.key}',
            testRecipes,
          );
          expect(menu.containsKey(entry.value), isTrue,
              reason: 'Failed to detect ${entry.value} from ${entry.key}');
        }
      });
    });
    
    group('Complex Input Parsing', () {
      test('should handle comma-separated input', () async {
        // Arrange
        const input = 'tre frukoster, två luncher, fyra middagar';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Lunch']?.length, equals(2));
        expect(menu['Middag']?.length, equals(4));
      });
      
      test('should handle "och" conjunction', () async {
        // Arrange
        const input = 'tre frukoster och två middagar och en efterrätt';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Middag']?.length, equals(2));
        expect(menu['Efterrätt']?.length, equals(1));
      });
      
      test('should handle "&" separator', () async {
        // Arrange
        const input = 'tre frukoster & två middagar';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Middag']?.length, equals(2));
      });
      
      test('should handle semicolon separator', () async {
        // Arrange
        const input = 'tre frukoster; två middagar';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Middag']?.length, equals(2));
      });
      
      test('should handle mixed separators', () async {
        // Arrange
        const input = 'tre frukoster, två luncher och fyra middagar; en efterrätt';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Lunch']?.length, equals(2));
        expect(menu['Middag']?.length, equals(4));
        expect(menu['Efterrätt']?.length, equals(1));
      });
      
      test('should accumulate counts for same meal type', () async {
        // Arrange - Request more breakfasts in multiple parts
        const input = 'två frukoster och tre frukoster';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert - Should sum to 5 breakfasts
        expect(menu['Frukost']?.length, equals(5));
      });
    });
    
    group('Edge Cases', () {
      test('should return empty map for empty input', () async {
        // Act
        final menu = await menuService.generateMenuFromPrompt('', testRecipes);
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should return empty map for whitespace input', () async {
        // Act
        final menu = await menuService.generateMenuFromPrompt('   \n\t  ', testRecipes);
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should return empty map for invalid input', () async {
        // Act
        final menu = await menuService.generateMenuFromPrompt(
          'detta är inte en giltig meny instruktion',
          testRecipes,
        );
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should handle case insensitive input', () async {
        // Arrange
        const input = 'TRE FRUKOSTER OCH TVÅ MIDDAGAR';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(3));
        expect(menu['Middag']?.length, equals(2));
      });
      
      test('should handle empty recipe list', () async {
        // Arrange
        const input = 'tre frukoster';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, []);
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should limit to available recipes', () async {
        // Arrange - Request more than available
        const input = 'tio frukoster'; // Only 5 breakfast recipes available
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu['Frukost']?.length, equals(5)); // Limited to available
      });
      
      test('should not include duplicate recipes', () async {
        // Arrange
        const input = 'fem frukoster';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        final breakfasts = menu['Frukost'] ?? [];
        final uniqueIds = breakfasts.map((r) => r.id).toSet();
        expect(uniqueIds.length, equals(breakfasts.length)); // All unique
      });
      
      test('should handle invalid numbers gracefully', () async {
        // Arrange
        const input = 'elva frukoster'; // 'elva' not in word2num map
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should handle zero or negative numbers', () async {
        // Arrange
        const input = '0 frukoster';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should handle unknown meal types', () async {
        // Arrange
        const input = 'tre kvällsmat'; // Unknown meal type
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        expect(menu, isEmpty);
      });
      
      test('should handle recipes with null or empty meal types', () async {
        // Arrange
        final recipesWithNullType = [
          RecipeFactory.build(id: 'null1', mealType: ''),
          RecipeFactory.build(id: 'valid1', mealType: 'Frukost'),
        ];
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(
          'en frukost',
          recipesWithNullType,
        );
        
        // Assert
        expect(menu['Frukost']?.length, equals(1));
        expect(menu['Frukost']?.first.id, equals('valid1'));
      });
    });
    
    group('Recipe Selection', () {
      test('should randomize recipe selection', () async {
        // Arrange
        const input = 'tre frukoster';
        
        // Act - Generate multiple menus
        final menus = <List<String>>[];
        for (int i = 0; i < 10; i++) {
          final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
          final ids = menu['Frukost']?.map((r) => r.id).toList() ?? [];
          if (ids.isNotEmpty) {
            menus.add(ids);
          }
        }
        
        // Assert - At least some variations should exist
        // Note: This might occasionally fail due to randomness
        final uniqueMenus = menus.map((m) => m.join(',')).toSet();
        expect(uniqueMenus.length, greaterThan(1),
            reason: 'Should have different random selections');
      });
      
      test('should return correct recipe objects', () async {
        // Arrange
        const input = 'en frukost';
        
        // Act
        final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
        
        // Assert
        final breakfast = menu['Frukost']?.first;
        expect(breakfast, isNotNull);
        expect(breakfast?.mealType, equals('Frukost'));
        expect(testRecipes.contains(breakfast), isTrue);
      });
    });
    
    group('Performance', () {
      test('should handle large recipe collections efficiently', () async {
        // Arrange
        final largeRecipeList = List.generate(
          1000,
          (i) => RecipeFactory.build(
            id: 'recipe_$i',
            title: 'Recipe $i',
            mealType: i % 5 == 0 ? 'Frukost' :
                      i % 5 == 1 ? 'Lunch' :
                      i % 5 == 2 ? 'Middag' :
                      i % 5 == 3 ? 'Mellanmål' : 'Efterrätt',
          ),
        );
        
        const input = 'fem frukoster, tre luncher och fyra middagar';
        
        // Act
        final stopwatch = Stopwatch()..start();
        final menu = await menuService.generateMenuFromPrompt(input, largeRecipeList);
        stopwatch.stop();
        
        // Assert
        expect(menu['Frukost']?.length, equals(5));
        expect(menu['Lunch']?.length, equals(3));
        expect(menu['Middag']?.length, equals(4));
        expect(stopwatch.elapsedMilliseconds, lessThan(100),
            reason: 'Should process large lists quickly');
      });
    });
    
    group('Singleton Pattern', () {
      test('should maintain same instance across multiple factory calls', () {
        // Act
        final instance1 = MenuService();
        final instance2 = MenuService();
        final instance3 = MenuService();
        
        // Assert
        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance2, instance3), isTrue);
      });
      
      test('should reset singleton for testing', () {
        // Arrange
        final instance1 = MenuService();
        
        // Act
        SingletonServiceMixin.resetForTesting();
        final instance2 = MenuService();
        
        // Assert
        expect(identical(instance1, instance2), isFalse);
      });
    });
    
    group('Error Handling', () {
      // Tests for existing generateMenuFromPrompt functionality
      group('Current Implementation Errors', () {
        test('should handle extremely large number requests gracefully', () async {
          // Arrange
          const input = '9999999 frukoster'; // Extreme number
          
          // Act
          final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
          
          // Assert - Should be limited to available recipes
          expect(menu['Frukost']?.length, lessThanOrEqualTo(5)); // Only 5 breakfast recipes available
        });
        
        test('should handle negative numbers gracefully', () async {
          // Arrange
          const input = '-5 frukoster';
          
          // Act
          final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
          
          // Assert
          expect(menu, isEmpty);
        });
        
        test('should handle no recipes available for meal type', () async {
          // Arrange
          final recipesWithoutBreakfast = testRecipes
              .where((r) => r.mealType != 'Frukost')
              .toList();
          const input = 'fem frukoster';
          
          // Act
          final menu = await menuService.generateMenuFromPrompt(
            input, 
            recipesWithoutBreakfast,
          );
          
          // Assert
          expect(menu['Frukost'], isNull);
        });
        
        test('should handle invalid meal type strings gracefully', () async {
          // Arrange
          const invalidMealTypes = [
            'invalid_meal',
            'xyz_random_type',
            'not_a_meal',
          ];
          
          // Act & Assert
          for (final mealType in invalidMealTypes) {
            final menu = await menuService.generateMenuFromPrompt(
              'tre $mealType',
              testRecipes,
            );
            expect(menu, isEmpty,
                reason: 'Should return empty for invalid meal type: $mealType');
          }
          
          // Note: The service may be lenient and match partial inputs
          // This is actually a feature, not a bug - it helps with user experience
        });
        
        test('should handle malformed input with special characters', () async {
          // Arrange
          const malformedInputs = [
            '@#\$%^&*()',
            '!!!###',
            '<<<>>>',
            '{}[]',
            'null undefined',
          ];
          
          // Act & Assert
          for (final input in malformedInputs) {
            final menu = await menuService.generateMenuFromPrompt(
              input,
              testRecipes,
            );
            expect(menu, isEmpty,
                reason: 'Should return empty for malformed input: $input');
          }
        });
        
        test('should handle mixed valid and invalid requests', () async {
          // Arrange
          const input = 'tre frukoster och invalid_meal och två middagar';
          
          // Act
          final menu = await menuService.generateMenuFromPrompt(input, testRecipes);
          
          // Assert - Should only process valid meal types
          expect(menu['Frukost']?.length, equals(3));
          expect(menu['Middag']?.length, equals(2));
          expect(menu.containsKey('invalid_meal'), isFalse);
        });
        
        test('should handle recipe list with duplicate IDs', () async {
          // Arrange
          final duplicateRecipes = [
            RecipeFactory.build(id: 'dup1', mealType: 'Frukost'),
            RecipeFactory.build(id: 'dup1', mealType: 'Frukost'), // Duplicate
            RecipeFactory.build(id: 'dup2', mealType: 'Frukost'),
          ];
          
          // Act
          final menu = await menuService.generateMenuFromPrompt(
            'två frukoster',
            duplicateRecipes,
          );
          
          // Assert - Should handle duplicates gracefully
          expect(menu['Frukost']?.length, lessThanOrEqualTo(2));
        });
        
        test('should handle concurrent calls gracefully', () async {
          // Arrange
          final futures = List.generate(10, (i) => 
            menuService.generateMenuFromPrompt('en frukost', testRecipes)
          );
          
          // Act & Assert - All should complete without issues
          final results = await Future.wait(futures);
          for (final result in results) {
            expect(result['Frukost']?.length, equals(1));
          }
        });
      });
    });
  });
}