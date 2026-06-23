// test/unit/viewmodels/realtime/optimistic_update_manager_test.dart

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/realtime/optimistic_update_manager.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OptimisticUpdateManager updateManager;

  setUpAll(() async {
    await TestServiceLocator.initialize();
  });

  setUp(() async {
    updateManager = OptimisticUpdateManager();
  });

  tearDown(() async {
    updateManager.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  List<Recipe> createTestRecipes({
    int count = 3,
    String namePrefix = 'Recipe',
  }) {
    return List.generate(
      count,
      (index) => RecipeFactory.build(
        id: '${namePrefix.toLowerCase()}_${index + 1}',
        title: '$namePrefix ${index + 1}',
        description: 'Description for $namePrefix ${index + 1}',
      ),
    );
  }

  Map<String, List<Recipe>> createTestMenu() {
    return {
      'Måndag': createTestRecipes(count: 2, namePrefix: 'Monday'),
      'Tisdag': createTestRecipes(count: 2, namePrefix: 'Tuesday'),
      'Onsdag': createTestRecipes(count: 2, namePrefix: 'Wednesday'),
    };
  }

  group('OptimisticUpdateManager - Initialization and Basic State', () {
    test('should initialize with empty state', () {
      expect(updateManager.hasChanges, isFalse);
      expect(updateManager.allChanges, isEmpty);
    });

    test('should initialize with callback', () {
      bool callbackTriggered = false;
      final managerWithCallback = OptimisticUpdateManager(
        onUpdated: () => callbackTriggered = true,
      );

      // Apply change to trigger callback
      managerWithCallback.applyChange(
        'Test Category',
        (recipes) => [...recipes, RecipeFactory.build()],
      );

      expect(callbackTriggered, isTrue);

      managerWithCallback.dispose();
    });

    test('should work without callback', () {
      final manager = OptimisticUpdateManager();

      expect(
        () => manager.applyChange(
          'Test Category',
          (recipes) => [...recipes, RecipeFactory.build()],
        ),
        returnsNormally,
      );

      manager.dispose();
    });
  });

  group('OptimisticUpdateManager - Applying Changes', () {
    test('should apply optimistic change to category', () {
      final testRecipes = createTestRecipes(count: 2);

      updateManager.applyChange(
        'Måndag',
        (recipes) => [...recipes, ...testRecipes],
      );

      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges.containsKey('Måndag'), isTrue);
      expect(updateManager.allChanges['Måndag']!.length, equals(2));
    });

    test('should apply multiple changes to different categories', () {
      final mondayRecipes = createTestRecipes(count: 2, namePrefix: 'Monday');
      final tuesdayRecipes = createTestRecipes(count: 3, namePrefix: 'Tuesday');

      updateManager.applyChange('Måndag', (recipes) => mondayRecipes);
      updateManager.applyChange('Tisdag', (recipes) => tuesdayRecipes);

      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges.length, equals(2));
      expect(updateManager.allChanges['Måndag']!.length, equals(2));
      expect(updateManager.allChanges['Tisdag']!.length, equals(3));
    });

    test('should update existing category changes', () {
      final initialRecipes = createTestRecipes(count: 1, namePrefix: 'Initial');
      final updatedRecipes = createTestRecipes(count: 3, namePrefix: 'Updated');

      // First change
      updateManager.applyChange('Måndag', (recipes) => initialRecipes);
      expect(updateManager.allChanges['Måndag']!.length, equals(1));

      // Update same category
      updateManager.applyChange('Måndag', (recipes) => updatedRecipes);
      expect(updateManager.allChanges['Måndag']!.length, equals(3));
      expect(
        updateManager.allChanges['Måndag']!.first.title,
        contains('Updated'),
      );
    });

    test('should apply change with current recipes as base', () {
      final currentRecipes = createTestRecipes(count: 2, namePrefix: 'Current');
      final additionalRecipe = RecipeFactory.build(title: 'Additional Recipe');

      updateManager.applyChange(
        'Måndag',
        (recipes) => [...recipes, additionalRecipe],
        currentRecipes,
      );

      expect(updateManager.allChanges['Måndag']!.length, equals(3));
      expect(
        updateManager.allChanges['Måndag']!.last.title,
        equals('Additional Recipe'),
      );
    });

    test('should handle empty recipe lists', () {
      updateManager.applyChange('Måndag', (recipes) => []);

      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges['Måndag'], isEmpty);
    });

    test('should handle complex update functions', () {
      final baseRecipes = createTestRecipes(count: 5);

      updateManager.applyChange(
        'Måndag',
        (recipes) => recipes
          ..removeAt(0) // Remove first
          ..add(RecipeFactory.build(title: 'New Recipe')) // Add new
          ..sort((a, b) => a.title.compareTo(b.title)), // Sort
        baseRecipes,
      );

      final result = updateManager.allChanges['Måndag']!;
      expect(result.length, equals(5)); // 5 - 1 + 1 = 5
      expect(result.any((r) => r.title == 'New Recipe'), isTrue);
    });
  });

  group('OptimisticUpdateManager - Retrieving Recipes', () {
    test('should return fallback when no optimistic changes', () {
      final fallback = createTestRecipes(count: 3);

      final result = updateManager.getRecipesForDay('Måndag', fallback);

      expect(result, equals(fallback));
      expect(result.length, equals(3));
    });

    test('should return optimistic changes when available', () {
      final fallback = createTestRecipes(count: 2, namePrefix: 'Fallback');
      final optimistic = createTestRecipes(count: 4, namePrefix: 'Optimistic');

      updateManager.applyChange('Måndag', (recipes) => optimistic);

      final result = updateManager.getRecipesForDay('Måndag', fallback);

      expect(result, equals(optimistic));
      expect(result.length, equals(4));
      expect(result.first.title, contains('Optimistic'));
    });

    test('should return fallback for non-optimistic categories', () {
      final optimistic = createTestRecipes(count: 2, namePrefix: 'Optimistic');
      final fallback = createTestRecipes(count: 3, namePrefix: 'Fallback');

      updateManager.applyChange('Måndag', (recipes) => optimistic);

      // Request different category
      final result = updateManager.getRecipesForDay('Tisdag', fallback);

      expect(result, equals(fallback));
      expect(result.length, equals(3));
    });

    test('should handle empty fallback lists', () {
      final result = updateManager.getRecipesForDay('Måndag', []);

      expect(result, isEmpty);
    });
  });

  group('OptimisticUpdateManager - Menu Application', () {
    test('should return base menu when no optimistic changes', () {
      final baseMenu = createTestMenu();

      final result = updateManager.applyToMenu(baseMenu);

      expect(result, equals(baseMenu));
      expect(result.length, equals(3));
    });

    test('should apply optimistic changes to base menu', () {
      final baseMenu = createTestMenu();
      final optimisticRecipes = createTestRecipes(
        count: 1,
        namePrefix: 'Optimistic',
      );

      updateManager.applyChange('Måndag', (recipes) => optimisticRecipes);

      final result = updateManager.applyToMenu(baseMenu);

      expect(result.length, equals(3));
      expect(result['Måndag'], equals(optimisticRecipes));
      expect(result['Tisdag'], equals(baseMenu['Tisdag'])); // Unchanged
      expect(result['Onsdag'], equals(baseMenu['Onsdag'])); // Unchanged
    });

    test('should add new categories in optimistic changes', () {
      final baseMenu = createTestMenu();
      final newCategoryRecipes = createTestRecipes(count: 2, namePrefix: 'New');

      updateManager.applyChange('Torsdag', (recipes) => newCategoryRecipes);

      final result = updateManager.applyToMenu(baseMenu);

      expect(result.length, equals(4)); // Original 3 + 1 new
      expect(result.containsKey('Torsdag'), isTrue);
      expect(result['Torsdag'], equals(newCategoryRecipes));
    });

    test('should handle multiple optimistic categories', () {
      final baseMenu = createTestMenu();
      final mondayOptimistic = createTestRecipes(
        count: 1,
        namePrefix: 'MondayOpt',
      );
      final thursdayRecipes = createTestRecipes(
        count: 2,
        namePrefix: 'Thursday',
      );

      updateManager.applyChange('Måndag', (recipes) => mondayOptimistic);
      updateManager.applyChange('Torsdag', (recipes) => thursdayRecipes);

      final result = updateManager.applyToMenu(baseMenu);

      expect(result.length, equals(4));
      expect(result['Måndag'], equals(mondayOptimistic));
      expect(result['Torsdag'], equals(thursdayRecipes));
      expect(result['Tisdag'], equals(baseMenu['Tisdag'])); // Unchanged
    });

    test('should handle empty base menu', () {
      final optimisticRecipes = createTestRecipes(count: 2);

      updateManager.applyChange('Måndag', (recipes) => optimisticRecipes);

      final result = updateManager.applyToMenu({});

      expect(result.length, equals(1));
      expect(result['Måndag'], equals(optimisticRecipes));
    });

    test('should return immutable view of all changes', () {
      updateManager.applyChange('Måndag', (recipes) => recipes);

      final changes = updateManager.allChanges;
      expect(() => changes['Tisdag'] = [], throwsUnsupportedError);
    });
  });

  group('OptimisticUpdateManager - Automatic Rollback', () {
    test('should automatically rollback after 10 seconds', () {
      fakeAsync((async) {
        updateManager.applyChange('Måndag', (recipes) => recipes);
        expect(updateManager.hasChanges, isTrue);

        // Wait for auto rollback (plus buffer)
        async.elapse(const Duration(seconds: 11));

        expect(updateManager.hasChanges, isFalse);
        expect(updateManager.allChanges, isEmpty);
      });
    });

    test('should reset rollback timer on new changes', () {
      fakeAsync((async) {
        final firstRecipes = createTestRecipes(count: 1, namePrefix: 'First');
        final secondRecipes = createTestRecipes(count: 2, namePrefix: 'Second');

        updateManager.applyChange('Måndag', (recipes) => firstRecipes);

        // Wait 5 seconds, then apply another change
        async.elapse(const Duration(seconds: 5));
        updateManager.applyChange('Tisdag', (recipes) => secondRecipes);

        // Wait another 6 seconds (total 11, but timer was reset)
        async.elapse(const Duration(seconds: 6));

        // Should still have changes since timer was reset
        expect(updateManager.hasChanges, isTrue);
        expect(updateManager.allChanges.length, equals(2));
      });
    });

    test('should cancel rollback timer on manual clear', () {
      fakeAsync((async) {
        updateManager.applyChange('Måndag', (recipes) => recipes);

        // Clear manually before auto rollback
        async.elapse(const Duration(seconds: 2));
        updateManager.clear();

        expect(updateManager.hasChanges, isFalse);

        // Wait past original rollback time
        async.elapse(const Duration(seconds: 10));

        // Should still be clear (no double clear)
        expect(updateManager.hasChanges, isFalse);
      });
    });

    test('should trigger callback on automatic rollback', () {
      fakeAsync((async) {
        int callbackCount = 0;

        final manager = OptimisticUpdateManager(
          onUpdated: () {
            callbackCount++;
          },
        );

        manager.applyChange('Test', (recipes) => createTestRecipes(count: 1));
        expect(callbackCount, equals(1)); // From apply

        // Wait for auto rollback
        async.elapse(const Duration(seconds: 11));

        expect(callbackCount, equals(2)); // From apply + rollback

        manager.dispose();
      });
    });
  });

  group('OptimisticUpdateManager - Manual Clear Operations', () {
    test('should clear all changes manually', () {
      final mondayRecipes = createTestRecipes(count: 2, namePrefix: 'Monday');
      final tuesdayRecipes = createTestRecipes(count: 3, namePrefix: 'Tuesday');

      updateManager.applyChange('Måndag', (recipes) => mondayRecipes);
      updateManager.applyChange('Tisdag', (recipes) => tuesdayRecipes);

      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges.length, equals(2));

      updateManager.clear();

      expect(updateManager.hasChanges, isFalse);
      expect(updateManager.allChanges, isEmpty);
    });

    test('should trigger callback on manual clear', () {
      bool callbackTriggered = false;

      final manager = OptimisticUpdateManager(
        onUpdated: () => callbackTriggered = true,
      );

      manager.applyChange('Test', (recipes) => createTestRecipes(count: 1));
      callbackTriggered = false; // Reset

      manager.clear();

      expect(callbackTriggered, isTrue);

      manager.dispose();
    });

    test('should handle clear when no changes exist', () {
      expect(updateManager.hasChanges, isFalse);

      // Should not crash
      updateManager.clear();

      expect(updateManager.hasChanges, isFalse);
    });

    test('should clear specific category', () {
      final mondayRecipes = createTestRecipes(count: 2, namePrefix: 'Monday');
      final tuesdayRecipes = createTestRecipes(count: 3, namePrefix: 'Tuesday');

      updateManager.applyChange('Måndag', (recipes) => mondayRecipes);
      updateManager.applyChange('Tisdag', (recipes) => tuesdayRecipes);

      updateManager.clearCategory('Måndag');

      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges.containsKey('Måndag'), isFalse);
      expect(updateManager.allChanges.containsKey('Tisdag'), isTrue);
      expect(updateManager.allChanges.length, equals(1));
    });

    test('should clear last category and reset hasChanges', () {
      updateManager.applyChange('Måndag', (recipes) => recipes);
      expect(updateManager.hasChanges, isTrue);

      updateManager.clearCategory('Måndag');

      expect(updateManager.hasChanges, isFalse);
      expect(updateManager.allChanges, isEmpty);
    });

    test('should trigger callback on category clear', () {
      bool callbackTriggered = false;

      final manager = OptimisticUpdateManager(
        onUpdated: () => callbackTriggered = true,
      );

      manager.applyChange('Test', (recipes) => createTestRecipes(count: 1));
      callbackTriggered = false; // Reset

      manager.clearCategory('Test');

      expect(callbackTriggered, isTrue);

      manager.dispose();
    });

    test('should handle clear non-existent category', () {
      updateManager.applyChange('Måndag', (recipes) => recipes);

      // Clear non-existent category
      updateManager.clearCategory('Nonexistent');

      // Should not affect existing changes
      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges.containsKey('Måndag'), isTrue);
    });

    test('should rollback with warning', () {
      updateManager.applyChange('Måndag', (recipes) => recipes);
      expect(updateManager.hasChanges, isTrue);

      updateManager.rollback();

      expect(updateManager.hasChanges, isFalse);
      expect(updateManager.allChanges, isEmpty);
    });
  });

  group('OptimisticUpdateManager - Callback Functionality', () {
    test('should trigger callback on apply change', () {
      bool callbackTriggered = false;

      final manager = OptimisticUpdateManager(
        onUpdated: () => callbackTriggered = true,
      );

      manager.applyChange('Test', (recipes) => createTestRecipes(count: 1));

      expect(callbackTriggered, isTrue);

      manager.dispose();
    });

    test('should not trigger callback when no callback provided', () {
      // Should not crash
      expect(
        () => updateManager.applyChange(
          'Test',
          (recipes) => createTestRecipes(count: 1),
        ),
        returnsNormally,
      );
    });

    test('should propagate callback exceptions', () {
      final manager = OptimisticUpdateManager(
        onUpdated: () => throw Exception('Callback error'),
      );

      // Should throw the callback exception
      expect(
        () => manager.applyChange(
          'Test',
          (recipes) => createTestRecipes(count: 1),
        ),
        throwsA(isA<Exception>()),
      );

      // Dispose will also throw since it calls clear() which triggers callback
      expect(() => manager.dispose(), throwsA(isA<Exception>()));
    });

    test('should trigger multiple callbacks for multiple operations', () {
      int callbackCount = 0;

      final manager = OptimisticUpdateManager(
        onUpdated: () => callbackCount++,
      );

      manager.applyChange('Cat1', (recipes) => createTestRecipes(count: 1));
      manager.applyChange('Cat2', (recipes) => createTestRecipes(count: 2));
      manager.clearCategory('Cat1');
      manager.clear();

      expect(callbackCount, equals(4));

      manager.dispose();
    });
  });

  group('OptimisticUpdateManager - Disposal and Cleanup', () {
    test('should dispose cleanly', () {
      updateManager.applyChange('Måndag', (recipes) => recipes);

      expect(() => updateManager.dispose(), returnsNormally);
      expect(updateManager.hasChanges, isFalse);
    });

    test('should handle multiple dispose calls', () {
      updateManager.dispose();

      // Second dispose should not crash
      expect(() => updateManager.dispose(), returnsNormally);
    });

    test('should cancel rollback timer on dispose', () {
      fakeAsync((async) {
        updateManager.applyChange('Måndag', (recipes) => recipes);

        updateManager.dispose();

        // Wait past rollback time
        async.elapse(const Duration(seconds: 11));

        // Changes should be cleared by dispose, not by timer
        expect(updateManager.hasChanges, isFalse);
      });
    });

    test('should clear all changes on dispose', () {
      final mondayRecipes = createTestRecipes(count: 2, namePrefix: 'Monday');
      final tuesdayRecipes = createTestRecipes(count: 3, namePrefix: 'Tuesday');

      updateManager.applyChange('Måndag', (recipes) => mondayRecipes);
      updateManager.applyChange('Tisdag', (recipes) => tuesdayRecipes);

      updateManager.dispose();

      expect(updateManager.hasChanges, isFalse);
      expect(updateManager.allChanges, isEmpty);
    });
  });

  group('OptimisticUpdateManager - Edge Cases and Integration', () {
    test('should handle rapid successive changes', () {
      final baseRecipes = createTestRecipes(count: 1);

      // Apply multiple rapid changes
      for (int i = 0; i < 10; i++) {
        updateManager.applyChange(
          'Måndag',
          (recipes) => [
            ...baseRecipes,
            RecipeFactory.build(title: 'Recipe $i'),
          ],
        );
      }

      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges['Måndag']!.length, greaterThan(1));
    });

    test('should handle concurrent category operations', () {
      final categories = ['Cat1', 'Cat2', 'Cat3', 'Cat4', 'Cat5'];

      // Apply changes to multiple categories
      for (String category in categories) {
        updateManager.applyChange(
          category,
          (recipes) => createTestRecipes(count: 2, namePrefix: category),
        );
      }

      expect(updateManager.allChanges.length, equals(5));

      // Clear some categories
      updateManager.clearCategory('Cat2');
      updateManager.clearCategory('Cat4');

      expect(updateManager.allChanges.length, equals(3));
      expect(updateManager.hasChanges, isTrue);
    });

    test('should handle large recipe collections', () {
      final largeRecipeList = createTestRecipes(count: 100);

      updateManager.applyChange(
        'Måndag',
        (recipes) => largeRecipeList,
      );

      expect(updateManager.allChanges['Måndag']!.length, equals(100));

      final fallback = createTestRecipes(count: 5);
      final result = updateManager.getRecipesForDay('Måndag', fallback);

      expect(result.length, equals(100));
    });

    test('should handle empty and null-safe operations', () {
      // Apply with empty list
      updateManager.applyChange('Empty', (recipes) => []);
      expect(updateManager.allChanges['Empty'], isEmpty);

      // Get recipes with empty fallback
      final result = updateManager.getRecipesForDay('Empty', []);
      expect(result, isEmpty);

      // Apply to empty menu
      final emptyMenu = updateManager.applyToMenu({});
      expect(emptyMenu['Empty'], isEmpty);
    });

    test('should maintain state consistency during complex operations', () {
      final baseMenu = createTestMenu();

      // Apply optimistic changes
      updateManager.applyChange(
        'Måndag',
        (recipes) => createTestRecipes(count: 1),
      );
      updateManager.applyChange(
        'Fredag',
        (recipes) => createTestRecipes(count: 2),
      );

      // Test state consistency
      expect(updateManager.hasChanges, isTrue);
      expect(updateManager.allChanges.length, equals(2));

      final menuResult = updateManager.applyToMenu(baseMenu);
      expect(menuResult.length, equals(4)); // 3 original + 1 new (Fredag)

      final mondayResult = updateManager.getRecipesForDay(
        'Måndag',
        baseMenu['Måndag']!,
      );
      expect(mondayResult.length, equals(1)); // Optimistic override

      // Clear one category
      updateManager.clearCategory('Måndag');
      expect(updateManager.hasChanges, isTrue); // Still has Fredag
      expect(updateManager.allChanges.length, equals(1));

      // Clear all
      updateManager.clear();
      expect(updateManager.hasChanges, isFalse);
      expect(updateManager.allChanges, isEmpty);
    });

    test('should handle update functions with side effects', () {
      final baseRecipes = createTestRecipes(count: 3);
      final List<String> sideEffectLog = [];

      updateManager.applyChange(
        'Måndag',
        (recipes) {
          sideEffectLog.add('Processing recipes');
          return recipes.map((r) {
            sideEffectLog.add('Processing recipe: ${r.title}');
            return r;
          }).toList();
        },
        baseRecipes,
      );

      expect(sideEffectLog.length, equals(4)); // 1 processing + 3 recipes
      expect(updateManager.allChanges['Måndag']!.length, equals(3));
    });
  });

  group('OptimisticUpdateManager - Integration Scenarios', () {
    test('should handle complete optimistic update workflow', () async {
      bool callbackTriggered = false;
      final manager = OptimisticUpdateManager(
        onUpdated: () => callbackTriggered = true,
      );

      final baseMenu = createTestMenu();

      // Apply optimistic changes
      manager.applyChange(
        'Måndag',
        (recipes) => createTestRecipes(count: 1, namePrefix: 'Opt1'),
      );
      expect(callbackTriggered, isTrue);

      manager.applyChange(
        'Torsdag',
        (recipes) => createTestRecipes(count: 2, namePrefix: 'Opt2'),
      );

      // Test retrieval methods
      final mondayRecipes = manager.getRecipesForDay(
        'Måndag',
        baseMenu['Måndag']!,
      );
      expect(mondayRecipes.first.title, contains('Opt1'));

      final updatedMenu = manager.applyToMenu(baseMenu);
      expect(updatedMenu.length, equals(4));
      expect(updatedMenu['Torsdag']!.length, equals(2));

      // Clear specific category
      manager.clearCategory('Måndag');
      expect(manager.allChanges.length, equals(1));

      // Rollback remaining changes
      manager.rollback();
      expect(manager.hasChanges, isFalse);

      manager.dispose();
    });
  });
}
