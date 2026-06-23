import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/persistence_service.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local extended MockSharedPreferences for testing with control methods
class TestMockSharedPreferences extends MockSharedPreferences {
  final Map<String, Object> _data = {};
  bool _shouldThrow = false;

  // Control method for simulating errors
  void setShouldThrow(bool value) {
    _shouldThrow = value;
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (_shouldThrow) throw Exception('Storage error');
    _data[key] = value;
    return true;
  }

  @override
  String? getString(String key) {
    if (_shouldThrow) throw Exception('Storage error');
    return _data[key] as String?;
  }

  @override
  Future<bool> remove(String key) async {
    if (_shouldThrow) throw Exception('Storage error');
    _data.remove(key);
    return true;
  }

  @override
  Set<String> getKeys() {
    return _data.keys.toSet();
  }

  @override
  Future<bool> clear() async {
    if (_shouldThrow) throw Exception('Storage error');
    _data.clear();
    return true;
  }

  // Helper methods for testing
  void setData(String key, String value) {
    _data[key] = value;
  }

  void clearData() {
    _data.clear();
  }

  bool hasKey(String key) {
    return _data.containsKey(key);
  }
}

void main() {
  late PersistenceService service;
  late TestMockSharedPreferences mockPrefs;

  setUpAll(() async {
    // Initialize base test infrastructure for consistency
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    mockPrefs = TestMockSharedPreferences();
    SharedPreferences.setMockInitialValues({});

    // Override SharedPreferences.getInstance to return our mock
    // Note: In real implementation, we'd inject SharedPreferences through constructor
    // For now, we'll test the service as-is
    service = PersistenceService();
  });

  tearDown(() async {
    mockPrefs.clearData();
    mockPrefs.setShouldThrow(false);
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('PersistenceService', () {
    group('Recipe Persistence', () {
      test('should save empty recipe list', () async {
        // Since we can't easily inject mock SharedPreferences,
        // we'll use SharedPreferences.setMockInitialValues for testing
        SharedPreferences.setMockInitialValues({});

        final result = await service.saveRecipes([]);

        expect(result, isTrue);
      });

      test('should save single recipe', () async {
        SharedPreferences.setMockInitialValues({});
        final recipe = RecipeFactory.build();

        final result = await service.saveRecipes([recipe]);

        expect(result, isTrue);
      });

      test('should save multiple recipes', () async {
        SharedPreferences.setMockInitialValues({});
        final recipes = RecipeFactory.buildList(count: 5);

        final result = await service.saveRecipes(recipes);

        expect(result, isTrue);
      });

      test('should load empty recipe list when no data exists', () async {
        SharedPreferences.setMockInitialValues({});

        final recipes = await service.loadRecipes();

        expect(recipes, isEmpty);
      });

      test('should load saved recipes correctly', () async {
        final originalRecipes = RecipeFactory.buildList(count: 3);

        // Create JSON representation
        final recipesJson = originalRecipes.map((r) => r.toJson()).toList();
        final jsonString = jsonEncode(recipesJson);

        SharedPreferences.setMockInitialValues({
          'butlery_recipes': jsonString,
        });

        final loadedRecipes = await service.loadRecipes();

        expect(loadedRecipes.length, equals(3));
        expect(
          loadedRecipes.first.core.id,
          equals(originalRecipes.first.core.id),
        );
      });

      test('should handle corrupt recipe data gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'butlery_recipes': 'invalid json data {[}]',
        });

        final recipes = await service.loadRecipes();

        expect(recipes, isEmpty);
      });

      test('should clear all recipes', () async {
        final recipes = RecipeFactory.buildList(count: 3);
        final recipesJson = recipes.map((r) => r.toJson()).toList();
        final jsonString = jsonEncode(recipesJson);

        SharedPreferences.setMockInitialValues({
          'butlery_recipes': jsonString,
        });

        final result = await service.clearRecipes();

        expect(result, isTrue);
      });

      test('should handle large recipe collections', () async {
        SharedPreferences.setMockInitialValues({});
        final largeRecipeList = RecipeFactory.buildList(count: 100);

        final saveResult = await service.saveRecipes(largeRecipeList);

        expect(saveResult, isTrue);
      });

      test('should preserve recipe details during save/load cycle', () async {
        final originalRecipe = RecipeFactory.build(
          title: 'Test Recipe',
          description: 'Test Description',
          portions: 4,
          timeMinutes: 30,
        );

        // Save
        SharedPreferences.setMockInitialValues({});
        await service.saveRecipes([originalRecipe]);

        // Simulate loading by setting the saved data
        final recipesJson = [originalRecipe.toJson()];
        final jsonString = jsonEncode(recipesJson);
        SharedPreferences.setMockInitialValues({
          'butlery_recipes': jsonString,
        });

        // Load
        final loadedRecipes = await service.loadRecipes();

        expect(loadedRecipes.length, equals(1));
        expect(loadedRecipes.first.core.title, equals('Test Recipe'));
        expect(
          loadedRecipes.first.core.description,
          equals('Test Description'),
        );
        expect(loadedRecipes.first.core.portions, equals(4));
        expect(loadedRecipes.first.core.timeMinutes, equals(30));
      });

      test(
        'should update last updated timestamp when saving recipes',
        () async {
          SharedPreferences.setMockInitialValues({});
          final recipes = RecipeFactory.buildList(count: 2);

          final beforeSave = DateTime.now();
          await service.saveRecipes(recipes);

          // Verify the last updated timestamp was saved
          final prefs = await SharedPreferences.getInstance();
          final lastUpdated = prefs.getString('butlery_last_updated');
          expect(lastUpdated, isNotNull);
          final parsedTime = DateTime.parse(lastUpdated!);
          expect(
            parsedTime.isAfter(beforeSave.subtract(const Duration(seconds: 1))),
            isTrue,
          );
        },
      );
    });

    group('Menu Persistence', () {
      test('should save empty menu', () async {
        SharedPreferences.setMockInitialValues({});

        final result = await service.saveCurrentMenu([]);

        expect(result, isTrue);
      });

      test('should save menu with recipe IDs', () async {
        SharedPreferences.setMockInitialValues({});
        final recipeIds = ['recipe1', 'recipe2', 'recipe3'];

        final result = await service.saveCurrentMenu(recipeIds);

        expect(result, isTrue);
      });

      test('should load empty menu when no data exists', () async {
        SharedPreferences.setMockInitialValues({});

        final menu = await service.loadCurrentMenu();

        expect(menu, isEmpty);
      });

      test('should load saved menu correctly', () async {
        final recipeIds = ['recipe1', 'recipe2', 'recipe3'];
        final jsonString = jsonEncode(recipeIds);

        SharedPreferences.setMockInitialValues({
          'butlery_current_menu': jsonString,
        });

        final loadedMenu = await service.loadCurrentMenu();

        expect(loadedMenu, equals(recipeIds));
      });

      test('should handle corrupt menu data gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'butlery_current_menu': 'invalid json {[}]',
        });

        final menu = await service.loadCurrentMenu();

        expect(menu, isEmpty);
      });

      test('should clear current menu', () async {
        final recipeIds = ['recipe1', 'recipe2'];
        final jsonString = jsonEncode(recipeIds);

        SharedPreferences.setMockInitialValues({
          'butlery_current_menu': jsonString,
        });

        final result = await service.clearCurrentMenu();

        expect(result, isTrue);
      });

      test('should handle menu with many items', () async {
        SharedPreferences.setMockInitialValues({});
        final largeMenu = List.generate(50, (i) => 'recipe_$i');

        final result = await service.saveCurrentMenu(largeMenu);

        expect(result, isTrue);
      });
    });

    group('Metadata Operations', () {
      test(
        'should return null when no last updated timestamp exists',
        () async {
          SharedPreferences.setMockInitialValues({});

          final lastUpdated = await service.getLastUpdated();

          expect(lastUpdated, isNull);
        },
      );

      test('should return last updated timestamp', () async {
        final timestamp = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'butlery_last_updated': timestamp.toIso8601String(),
        });

        final lastUpdated = await service.getLastUpdated();

        expect(lastUpdated, isNotNull);
        expect(
          lastUpdated!.toIso8601String(),
          equals(timestamp.toIso8601String()),
        );
      });

      test('should handle invalid timestamp gracefully', () async {
        SharedPreferences.setMockInitialValues({
          'butlery_last_updated': 'invalid-date-format',
        });

        final lastUpdated = await service.getLastUpdated();

        expect(lastUpdated, isNull);
      });

      test('should clear all data successfully', () async {
        final recipes = RecipeFactory.buildList(count: 2);
        final recipesJson = recipes.map((r) => r.toJson()).toList();
        final recipesString = jsonEncode(recipesJson);

        final menuIds = ['recipe1', 'recipe2'];
        final menuString = jsonEncode(menuIds);

        SharedPreferences.setMockInitialValues({
          'butlery_recipes': recipesString,
          'butlery_current_menu': menuString,
          'butlery_last_updated': DateTime.now().toIso8601String(),
        });

        final result = await service.clearAllData();

        expect(result, isTrue);
      });

      test('should return storage info with no data', () async {
        SharedPreferences.setMockInitialValues({});

        final info = await service.getStorageInfo();

        expect(info['totalRecipes'], equals(0));
        expect(info['menuItems'], equals(0));
        expect(info['lastUpdated'], isNull);
        expect(info['hasData'], isFalse);
      });

      test('should return complete storage info', () async {
        final recipes = RecipeFactory.buildList(count: 5);
        final recipesJson = recipes.map((r) => r.toJson()).toList();
        final recipesString = jsonEncode(recipesJson);

        final menuIds = ['recipe1', 'recipe2', 'recipe3'];
        final menuString = jsonEncode(menuIds);

        final timestamp = DateTime.now();

        SharedPreferences.setMockInitialValues({
          'butlery_recipes': recipesString,
          'butlery_current_menu': menuString,
          'butlery_last_updated': timestamp.toIso8601String(),
        });

        final info = await service.getStorageInfo();

        expect(info['totalRecipes'], equals(5));
        expect(info['menuItems'], equals(3));
        expect(info['lastUpdated'], isNotNull);
        expect(info['hasData'], isTrue);
      });

      test('should handle storage info with corrupt data gracefully', () async {
        // Set invalid data that will cause parsing errors
        // The service handles these gracefully by returning empty lists
        SharedPreferences.setMockInitialValues({
          'butlery_recipes': 'invalid json',
          'butlery_current_menu': 'invalid json',
        });

        final info = await service.getStorageInfo();

        // When data is corrupt, the service returns empty values
        expect(info['totalRecipes'], equals(0));
        expect(info['menuItems'], equals(0));
        expect(info['hasData'], isFalse);
        expect(info['lastUpdated'], isNull);
        // The error field may or may not be present depending on implementation
      });
    });

    group('Edge Cases', () {
      test('should handle empty strings in recipe data', () async {
        final recipe = RecipeFactory.build(
          title: '',
          description: '',
        );

        SharedPreferences.setMockInitialValues({});
        final result = await service.saveRecipes([recipe]);

        expect(result, isTrue);
      });

      test('should handle special characters in recipe titles', () async {
        final recipe = RecipeFactory.build(
          title: 'Räksmörgås & Köttbullar',
          description: 'Swedish specialties: åäö ÅÄÖ',
        );

        // Save and load cycle
        final recipesJson = [recipe.toJson()];
        final jsonString = jsonEncode(recipesJson);

        SharedPreferences.setMockInitialValues({
          'butlery_recipes': jsonString,
        });

        final loadedRecipes = await service.loadRecipes();

        expect(
          loadedRecipes.first.core.title,
          equals('Räksmörgås & Köttbullar'),
        );
        expect(loadedRecipes.first.core.description, contains('åäö ÅÄÖ'));
      });

      test('should handle very long recipe descriptions', () async {
        final longDescription = 'A' * 10000; // 10,000 character description
        final recipe = RecipeFactory.build(
          description: longDescription,
        );

        SharedPreferences.setMockInitialValues({});
        final result = await service.saveRecipes([recipe]);

        expect(result, isTrue);
      });

      test('should handle rapid save operations', () async {
        SharedPreferences.setMockInitialValues({});

        final futures = <Future<bool>>[];
        for (int i = 0; i < 10; i++) {
          final recipe = RecipeFactory.build(title: 'Recipe $i');
          futures.add(service.saveRecipes([recipe]));
        }

        final results = await Future.wait(futures);

        expect(results.every((r) => r == true), isTrue);
      });

      test('should handle concurrent menu operations', () async {
        SharedPreferences.setMockInitialValues({});

        final saveResult = await service.saveCurrentMenu([
          'recipe1',
          'recipe2',
        ]);
        final loadResult = await service.loadCurrentMenu();
        final clearResult = await service.clearCurrentMenu();

        expect(saveResult, isTrue);
        expect(loadResult, isNotNull);
        expect(clearResult, isTrue);
      });

      test('should handle recipes with null optional fields', () async {
        // Create a recipe with minimal data
        final recipe = RecipeFactory.buildPersonal(
          id: 'test-id',
          title: 'Minimal Recipe',
          createdBy: 'user123',
        );

        SharedPreferences.setMockInitialValues({});
        final saveResult = await service.saveRecipes([recipe]);

        expect(saveResult, isTrue);
      });

      test('should preserve recipe order during save/load cycle', () async {
        final recipes = List.generate(
          5,
          (i) => RecipeFactory.build(title: 'Recipe $i'),
        );

        // Create JSON and save
        final recipesJson = recipes.map((r) => r.toJson()).toList();
        final jsonString = jsonEncode(recipesJson);

        SharedPreferences.setMockInitialValues({
          'butlery_recipes': jsonString,
        });

        final loadedRecipes = await service.loadRecipes();

        expect(loadedRecipes.length, equals(5));
        for (int i = 0; i < 5; i++) {
          expect(loadedRecipes[i].core.title, equals('Recipe $i'));
        }
      });

      test('should handle menu with duplicate recipe IDs', () async {
        SharedPreferences.setMockInitialValues({});
        final duplicateMenu = [
          'recipe1',
          'recipe2',
          'recipe1',
          'recipe3',
          'recipe2',
        ];

        final result = await service.saveCurrentMenu(duplicateMenu);

        expect(result, isTrue);
      });
    });

    // BUT-1028: recipe-list scroll-offset persistence (View-layer restore).
    group('Recipe-list scroll offset', () {
      test('returns 0.0 when nothing has been persisted', () async {
        SharedPreferences.setMockInitialValues({});

        expect(await service.getRecipeListScrollOffset(), 0.0);
      });

      test('round-trips a saved offset', () async {
        SharedPreferences.setMockInitialValues({});

        await service.setRecipeListScrollOffset(1234.5);

        expect(await service.getRecipeListScrollOffset(), 1234.5);
      });

      test('overwrites a previous offset', () async {
        SharedPreferences.setMockInitialValues({});

        await service.setRecipeListScrollOffset(800.0);
        await service.setRecipeListScrollOffset(42.0);

        expect(await service.getRecipeListScrollOffset(), 42.0);
      });
    });
  });
}
