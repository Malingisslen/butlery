// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RealtimeMenuData', () {
    late Recipe testRecipe1;
    late Recipe testRecipe2;
    late Recipe testRecipe3;
    late Map<String, List<Recipe>> testMenuSnapshot;

    setUp(() {
      testRecipe1 = RecipeFactory.build(id: 'recipe_1', title: 'Köttbullar');
      testRecipe2 = RecipeFactory.build(id: 'recipe_2', title: 'Fiskgryta');
      testRecipe3 = RecipeFactory.build(id: 'recipe_3', title: 'Äppelpaj');

      testMenuSnapshot = {
        'Måndag': [testRecipe1],
        'Tisdag': [testRecipe2],
        'Efterrätt': [testRecipe3],
      };
    });

    group('Construction', () {
      test('should create with required parameters', () {
        final createdForDate = DateTime(2025, 1, 15);

        final menuData = RealtimeMenuData(
          menuTitle: 'Veckans meny',
          createdForDate: createdForDate,
          menuSnapshot: testMenuSnapshot,
        );

        expect(menuData.menuTitle, equals('Veckans meny'));
        expect(menuData.createdForDate, equals(createdForDate));
        expect(menuData.menuSnapshot, equals(testMenuSnapshot));
        expect(menuData.menuNotes, isNull);
        expect(menuData.favoriteRecipeIds, isNull);
        expect(menuData.originalPrompt, isNull);
      });

      test('should create with all parameters', () {
        final createdForDate = DateTime(2025, 1, 15);

        final menuData = RealtimeMenuData(
          menuTitle: 'Familjens veckomeny',
          createdForDate: createdForDate,
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Extra grönsaker till barnen',
          favoriteRecipeIds: ['recipe_1', 'recipe_3'],
          originalPrompt: 'Skapa en veckomeny för familj med små barn',
        );

        expect(menuData.menuTitle, equals('Familjens veckomeny'));
        expect(menuData.createdForDate, equals(createdForDate));
        expect(menuData.menuSnapshot, equals(testMenuSnapshot));
        expect(menuData.menuNotes, equals('Extra grönsaker till barnen'));
        expect(menuData.favoriteRecipeIds, equals(['recipe_1', 'recipe_3']));
        expect(menuData.originalPrompt,
            equals('Skapa en veckomeny för familj med små barn'));
      });
    });

    group('Factory Methods', () {
      test('should create from menu categories', () {
        final menuData = RealtimeMenuData.fromMenuCategories(
          menuTitle: 'Test Meny',
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Anteckningar',
          favoriteRecipeIds: ['recipe_2'],
          originalPrompt: 'Test prompt',
          createdForDate: DateTime(2025, 1, 20),
        );

        expect(menuData.menuTitle, equals('Test Meny'));
        expect(menuData.menuSnapshot, equals(testMenuSnapshot));
        expect(menuData.menuNotes, equals('Anteckningar'));
        expect(menuData.favoriteRecipeIds, equals(['recipe_2']));
        expect(menuData.originalPrompt, equals('Test prompt'));
        expect(menuData.createdForDate, equals(DateTime(2025, 1, 20)));
      });

      test('should use current date when not provided in fromMenuCategories',
          () {
        final before = DateTime.now();

        final menuData = RealtimeMenuData.fromMenuCategories(
          menuTitle: 'Test Meny',
          menuSnapshot: testMenuSnapshot,
        );

        final after = DateTime.now();

        expect(
            menuData.createdForDate.isAfter(before) ||
                menuData.createdForDate.isAtSameMomentAs(before),
            isTrue);
        expect(
            menuData.createdForDate.isBefore(after) ||
                menuData.createdForDate.isAtSameMomentAs(after),
            isTrue);
      });
    });

    group('Data Access Methods', () {
      late RealtimeMenuData menuData;

      setUp(() {
        // Create menu with duplicate recipe in different categories
        final menuWithDuplicates = {
          'Måndag': [testRecipe1, testRecipe2],
          'Tisdag': [testRecipe2, testRecipe3],
          'Onsdag': [testRecipe1],
        };

        menuData = RealtimeMenuData(
          menuTitle: 'Test Meny',
          createdForDate: DateTime(2025, 1, 15),
          menuSnapshot: menuWithDuplicates,
        );
      });

      test('should get all categories', () {
        final categories = menuData.categories;

        expect(categories.length, equals(3));
        expect(categories, containsAll(['Måndag', 'Tisdag', 'Onsdag']));
      });

      test('should get all unique recipes', () {
        final uniqueRecipes = menuData.allUniqueRecipes;

        expect(uniqueRecipes.length, equals(3)); // Deduplicates recipes
        expect(uniqueRecipes.map((r) => r.id),
            containsAll(['recipe_1', 'recipe_2', 'recipe_3']));
      });

      test('should get recipes for specific category', () {
        final mondayRecipes = menuData.getRecipesForCategory('Måndag');

        expect(mondayRecipes.length, equals(2));
        expect(mondayRecipes[0].id, equals('recipe_1'));
        expect(mondayRecipes[1].id, equals('recipe_2'));
      });

      test('should return empty list for non-existent category', () {
        final recipes = menuData.getRecipesForCategory('Torsdag');

        expect(recipes, isEmpty);
      });

      test('should check if category has recipes', () {
        expect(menuData.categoryHasRecipes('Måndag'), isTrue);
        expect(menuData.categoryHasRecipes('Tisdag'), isTrue);
        expect(menuData.categoryHasRecipes('Torsdag'), isFalse);
      });

      test('should convert to MenuViewModel format', () {
        final viewModelFormat = menuData.toMenuViewModelFormat();

        expect(viewModelFormat, equals(menuData.menuSnapshot));
        // Should be a copy, not the same instance
        expect(identical(viewModelFormat, menuData.menuSnapshot), isFalse);
      });

      test('should check if menu contains recipe', () {
        expect(menuData.containsRecipe('recipe_1'), isTrue);
        expect(menuData.containsRecipe('recipe_2'), isTrue);
        expect(menuData.containsRecipe('recipe_999'), isFalse);
      });

      test('should find recipe category', () {
        expect(menuData.findRecipeCategory('recipe_1'), equals('Måndag'));
        expect(menuData.findRecipeCategory('recipe_3'), equals('Tisdag'));
        expect(menuData.findRecipeCategory('recipe_999'), isNull);
      });
    });

    group('Serialization', () {
      late RealtimeMenuData menuData;

      setUp(() {
        menuData = RealtimeMenuData(
          menuTitle: 'Serialization Test',
          createdForDate: DateTime(2025, 1, 15, 12, 30),
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Test notes',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Test prompt',
        );
      });

      test('should serialize content for Firestore', () {
        final serialized = menuData.serializeContent();

        expect(serialized['menuTitle'], equals('Serialization Test'));
        expect(serialized['menuNotes'], equals('Test notes'));
        expect(serialized['favoriteRecipeIds'], equals(['recipe_1']));
        expect(serialized['originalPrompt'], equals('Test prompt'));

        // Check timestamp serialization (AppTimestamp.toFirestore returns Timestamp)
        expect(serialized['createdForDate'], isA<Timestamp>());

        // Check menu snapshot serialization
        final menuSnapshotData =
            serialized['menuSnapshot'] as Map<String, dynamic>;
        expect(menuSnapshotData.keys,
            containsAll(['Måndag', 'Tisdag', 'Efterrätt']));
        expect(menuSnapshotData['Måndag'], isA<List>());
      });

      test('should round-trip through Firestore', () {
        final serialized = menuData.serializeContent();
        final restored = RealtimeMenuData.fromFirestore(serialized);

        expect(restored.menuTitle, equals(menuData.menuTitle));
        // Firestore round-trip converts to UTC
        expect(restored.createdForDate.toUtc(),
            equals(menuData.createdForDate.toUtc()));
        expect(restored.menuNotes, equals(menuData.menuNotes));
        expect(restored.favoriteRecipeIds, equals(menuData.favoriteRecipeIds));
        expect(restored.originalPrompt, equals(menuData.originalPrompt));

        // Check recipes are restored correctly
        expect(restored.menuSnapshot.keys, equals(menuData.menuSnapshot.keys));
        expect(restored.allUniqueRecipes.length,
            equals(menuData.allUniqueRecipes.length));
      });

      test('should handle missing fields in Firestore data', () {
        final minimalData = {
          'menuTitle': null,
          'createdForDate':
              AppTimestamp.fromDateTime(DateTime(2025, 1, 1)).toFirestore(),
          'menuSnapshot': {},
        };

        final restored = RealtimeMenuData.fromFirestore(minimalData);

        expect(restored.menuTitle, equals(''));
        expect(restored.menuSnapshot, isEmpty);
        expect(restored.menuNotes, isNull);
        expect(restored.favoriteRecipeIds, isNull);
        expect(restored.originalPrompt, isNull);
      });

      test('should serialize to JSON', () {
        final json = menuData.toJson();

        expect(json['menuTitle'], equals('Serialization Test'));
        expect(json['createdForDate'], equals('2025-01-15T12:30:00.000'));
        expect(json['menuNotes'], equals('Test notes'));
        expect(json['favoriteRecipeIds'], equals(['recipe_1']));
        expect(json['originalPrompt'], equals('Test prompt'));

        final menuSnapshotData = json['menuSnapshot'] as Map<String, dynamic>;
        expect(menuSnapshotData.keys,
            containsAll(['Måndag', 'Tisdag', 'Efterrätt']));
      });

      test('should round-trip through JSON', () {
        final json = menuData.toJson();
        final restored = RealtimeMenuData.fromJson(json);

        expect(restored.menuTitle, equals(menuData.menuTitle));
        expect(restored.createdForDate, equals(menuData.createdForDate));
        expect(restored.menuNotes, equals(menuData.menuNotes));
        expect(restored.favoriteRecipeIds, equals(menuData.favoriteRecipeIds));
        expect(restored.originalPrompt, equals(menuData.originalPrompt));

        expect(restored.menuSnapshot.keys, equals(menuData.menuSnapshot.keys));
        expect(restored.allUniqueRecipes.length,
            equals(menuData.allUniqueRecipes.length));
      });

      test('should handle missing fields in JSON', () {
        final minimalJson = {
          'createdForDate': '2025-01-01T00:00:00.000',
        };

        final restored = RealtimeMenuData.fromJson(minimalJson);

        expect(restored.menuTitle, equals(''));
        expect(restored.createdForDate, equals(DateTime(2025, 1, 1)));
        expect(restored.menuSnapshot, isEmpty);
        expect(restored.menuNotes, isNull);
        expect(restored.favoriteRecipeIds, isNull);
        expect(restored.originalPrompt, isNull);
      });
    });

    group('copyWith', () {
      late RealtimeMenuData original;

      setUp(() {
        original = RealtimeMenuData(
          menuTitle: 'Original',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Original notes',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Original prompt',
        );
      });

      test('should copy with new values', () {
        final newDate = DateTime(2025, 2, 1);
        final newMenuSnapshot = {
          'Fredag': [testRecipe1]
        };

        final copied = original.copyWith(
          menuTitle: 'Updated',
          createdForDate: newDate,
          menuSnapshot: newMenuSnapshot,
          menuNotes: 'Updated notes',
          favoriteRecipeIds: ['recipe_2', 'recipe_3'],
          originalPrompt: 'Updated prompt',
        );

        expect(copied.menuTitle, equals('Updated'));
        expect(copied.createdForDate, equals(newDate));
        expect(copied.menuSnapshot, equals(newMenuSnapshot));
        expect(copied.menuNotes, equals('Updated notes'));
        expect(copied.favoriteRecipeIds, equals(['recipe_2', 'recipe_3']));
        expect(copied.originalPrompt, equals('Updated prompt'));
      });

      test('should preserve original values when not specified', () {
        final copied = original.copyWith(menuTitle: 'New Title');

        expect(copied.menuTitle, equals('New Title'));
        expect(copied.createdForDate, equals(original.createdForDate));
        expect(copied.menuSnapshot, equals(original.menuSnapshot));
        expect(copied.menuNotes, equals(original.menuNotes));
        expect(copied.favoriteRecipeIds, equals(original.favoriteRecipeIds));
        expect(copied.originalPrompt, equals(original.originalPrompt));
      });
    });

    group('Equality and HashCode', () {
      test('should be equal when all fields match', () {
        final date = DateTime(2025, 1, 15);
        final menu1 = RealtimeMenuData(
          menuTitle: 'Test',
          createdForDate: date,
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Notes',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Prompt',
        );

        final menu2 = RealtimeMenuData(
          menuTitle: 'Test',
          createdForDate: date,
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Notes',
          favoriteRecipeIds: ['recipe_1'],
          originalPrompt: 'Prompt',
        );

        expect(menu1, equals(menu2));
        expect(menu1.hashCode, equals(menu2.hashCode));
      });

      test('should not be equal when fields differ', () {
        final baseMenu = RealtimeMenuData(
          menuTitle: 'Test',
          createdForDate: DateTime(2025, 1, 15),
          menuSnapshot: testMenuSnapshot,
        );

        final differentTitle = baseMenu.copyWith(menuTitle: 'Different');
        final differentDate =
            baseMenu.copyWith(createdForDate: DateTime(2025, 2, 1));
        final differentSnapshot = baseMenu.copyWith(menuSnapshot: {});

        expect(baseMenu, isNot(equals(differentTitle)));
        expect(baseMenu, isNot(equals(differentDate)));
        expect(baseMenu, isNot(equals(differentSnapshot)));
      });

      test('should handle null fields in equality', () {
        final menu1 = RealtimeMenuData(
          menuTitle: 'Test',
          createdForDate: DateTime(2025, 1, 15),
          menuSnapshot: testMenuSnapshot,
          menuNotes: null,
        );

        final menu2 = RealtimeMenuData(
          menuTitle: 'Test',
          createdForDate: DateTime(2025, 1, 15),
          menuSnapshot: testMenuSnapshot,
          menuNotes: null,
        );

        expect(menu1, equals(menu2));
      });
    });

    group('Edge Cases', () {
      test('should handle empty menu snapshot', () {
        final menuData = RealtimeMenuData(
          menuTitle: 'Empty Menu',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: {},
        );

        expect(menuData.categories, isEmpty);
        expect(menuData.allUniqueRecipes, isEmpty);
        expect(menuData.containsRecipe('any'), isFalse);
        expect(menuData.findRecipeCategory('any'), isNull);
        expect(menuData.getRecipesForCategory('any'), isEmpty);
        expect(menuData.categoryHasRecipes('any'), isFalse);
      });

      test('should handle Swedish characters in menu title and notes', () {
        final menuData = RealtimeMenuData(
          menuTitle: 'Åsas veckomeny med ÄÖÅ',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: testMenuSnapshot,
          menuNotes: 'Köttbullar och räkmacka är gött!',
        );

        expect(menuData.menuTitle, equals('Åsas veckomeny med ÄÖÅ'));
        expect(menuData.menuNotes, equals('Köttbullar och räkmacka är gött!'));

        // Should serialize and deserialize correctly
        final json = menuData.toJson();
        final restored = RealtimeMenuData.fromJson(json);

        expect(restored.menuTitle, equals(menuData.menuTitle));
        expect(restored.menuNotes, equals(menuData.menuNotes));
      });

      test('should handle categories with special characters', () {
        final specialMenuSnapshot = {
          'Måndag-Lunch': [testRecipe1],
          'Tisdag/Middag': [testRecipe2],
          'Onsdag (Efterrätt)': [testRecipe3],
        };

        final menuData = RealtimeMenuData(
          menuTitle: 'Special Categories',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: specialMenuSnapshot,
        );

        expect(
            menuData.categories,
            containsAll(
                ['Måndag-Lunch', 'Tisdag/Middag', 'Onsdag (Efterrätt)']));
        expect(
            menuData.getRecipesForCategory('Måndag-Lunch').length, equals(1));
      });

      test('should handle very large menu snapshots', () {
        final largeMenuSnapshot = <String, List<Recipe>>{};
        for (int i = 0; i < 100; i++) {
          final recipe = RecipeFactory.build(
            id: 'recipe_$i',
            title: 'Recipe $i',
          );
          largeMenuSnapshot['Category_$i'] = [recipe];
        }

        final menuData = RealtimeMenuData(
          menuTitle: 'Large Menu',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: largeMenuSnapshot,
        );

        expect(menuData.categories.length, equals(100));
        expect(menuData.allUniqueRecipes.length, equals(100));

        // Should still serialize correctly
        final json = menuData.toJson();
        expect(json['menuSnapshot'], isA<Map>());

        final restored = RealtimeMenuData.fromJson(json);
        expect(restored.categories.length, equals(100));
      });

      test('should handle duplicate recipes in same category', () {
        final menuWithDuplicates = {
          'Måndag': [testRecipe1, testRecipe1, testRecipe2],
        };

        final menuData = RealtimeMenuData(
          menuTitle: 'Duplicates Test',
          createdForDate: DateTime(2025, 1, 1),
          menuSnapshot: menuWithDuplicates,
        );

        // getRecipesForCategory returns all including duplicates
        expect(menuData.getRecipesForCategory('Måndag').length, equals(3));

        // allUniqueRecipes removes duplicates
        expect(menuData.allUniqueRecipes.length, equals(2));
      });
    });
  });
}
