// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'helpers/model_test_base.dart';

// Helper to create test recipe
int _recipeCounter = 0;
Recipe _createTestRecipe({
  String? id,
  String? title,
  String? mealType,
}) {
  _recipeCounter++;
  return Recipe(
    core: RecipeCore(
      id: id ?? 'recipe_$_recipeCounter',
      title: title ?? 'Test Recipe',
      description: 'Test Description',
      ingredients: ['Ingredient 1', 'Ingredient 2'],
      instructions: ['Step 1', 'Step 2'],
      mealType: mealType ?? 'middag',
      portions: 4,
      timeMinutes: 30,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'user_123',
      isPublic: false,
    ),
    type: RecipeType.personal,
  );
}

// Helper to create test menu data
RealtimeMenuData _createTestMenuData({
  String? menuTitle,
  Map<String, List<Recipe>>? menuSnapshot,
  DateTime? createdForDate,
}) {
  return RealtimeMenuData(
    menuTitle: menuTitle ?? 'Veckans meny',
    createdForDate: createdForDate ?? DateTime.now(),
    menuSnapshot: menuSnapshot ??
        {
          'Måndag': [_createTestRecipe(title: 'Köttbullar')],
          'Tisdag': [_createTestRecipe(title: 'Fisk')],
          'Onsdag': [_createTestRecipe(title: 'Pasta')],
          'Torsdag': [],
          'Fredag': [_createTestRecipe(title: 'Pizza')],
        },
    menuNotes: 'Test notes',
    favoriteRecipeIds: ['recipe_1', 'recipe_2'],
    originalPrompt: 'Generate a healthy menu',
  );
}

void main() {
  ModelTestBase.testModelGroup('RealtimeMenu', () {
    group('Construction', () {
      test('should create with required parameters', () {
        final data = _createTestMenuData();
        final participants = {
          'user_456': ResourcePermission.editor,
        };

        final realtimeMenu = RealtimeMenu(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: participants,
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          data: data,
        );

        expect(realtimeMenu.id, equals('menu_123'));
        expect(realtimeMenu.ownerId, equals('user_123'));
        expect(realtimeMenu.ownerDisplayName, equals('Anna Andersson'));
        expect(realtimeMenu.participants, equals(participants));
        expect(realtimeMenu.lastEditedBy, equals('user_123'));
        expect(realtimeMenu.lastEditedByDisplayName, equals('Anna Andersson'));
        expect(realtimeMenu.menuTitle, equals('Veckans meny'));
        expect(realtimeMenu.type, equals(RealtimeResourceType.menu));
        expect(realtimeMenu.editCount, equals(0));
        expect(realtimeMenu.isActive, isTrue);
      });

      test('should create with all parameters', () {
        final data = _createTestMenuData();
        final participants = {
          'user_456': ResourcePermission.editor,
          'user_789': ResourcePermission.viewer,
        };
        final createdAt = DateTime.now().subtract(const Duration(days: 5));
        final lastEditedAt = DateTime.now();
        final metadata = {'extra': 'data'};

        final realtimeMenu = RealtimeMenu(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: participants,
          createdAt: createdAt,
          lastEditedAt: lastEditedAt,
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik Eriksson',
          editCount: 10,
          isActive: false,
          metadata: metadata,
          data: data,
        );

        expect(realtimeMenu.createdAt, equals(createdAt));
        expect(realtimeMenu.lastEditedAt, equals(lastEditedAt));
        expect(realtimeMenu.editCount, equals(10));
        expect(realtimeMenu.isActive, isFalse);
        expect(realtimeMenu.metadata, equals(metadata));
      });
    });

    group('Factory Methods', () {
      test('should create from menu categories', () {
        final menuSnapshot = {
          'Måndag': [_createTestRecipe(title: 'Köttbullar')],
          'Tisdag': [_createTestRecipe(title: 'Fisk')],
        };

        final realtimeMenu = RealtimeMenu.fromMenuCategories(
          menuTitle: 'Test Menu',
          menuSnapshot: menuSnapshot,
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          editorUserIds: ['user_456'],
          viewerUserIds: ['user_789'],
          menuNotes: 'Test notes',
        );

        expect(realtimeMenu.menuTitle, equals('Test Menu'));
        expect(realtimeMenu.ownerId, equals('user_123'));
        expect(realtimeMenu.ownerDisplayName, equals('Anna Andersson'));
        expect(realtimeMenu.menuSnapshot, equals(menuSnapshot));
        expect(realtimeMenu.menuNotes, equals('Test notes'));
        // Owner IS in participants map for RealtimeMenu (different from RealtimeRecipe)
        expect(realtimeMenu.participants.containsKey('user_123'), isTrue);
        expect(realtimeMenu.participants['user_123'],
            equals(ResourcePermission.owner));
        expect(realtimeMenu.participants['user_456'],
            equals(ResourcePermission.editor));
        expect(realtimeMenu.participants['user_789'],
            equals(ResourcePermission.viewer));
      });

      test('should create from data', () {
        final data = _createTestMenuData();
        final participants = {
          'user_456': ResourcePermission.editor,
        };
        final createdAt = DateTime.now().subtract(const Duration(days: 5));
        final lastEditedAt = DateTime.now();

        final realtimeMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: participants,
          createdAt: createdAt,
          lastEditedAt: lastEditedAt,
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik Eriksson',
          data: data,
          editCount: 5,
          isActive: true,
        );

        expect(realtimeMenu.id, equals('menu_123'));
        expect(realtimeMenu.menuTitle, equals('Veckans meny'));
        expect(realtimeMenu.participants, equals(participants));
        expect(realtimeMenu.editCount, equals(5));
      });

      test('should create from JSON', () {
        final json = {
          'id': 'menu_123',
          'ownerId': 'user_123',
          'ownerDisplayName': 'Anna Andersson',
          'participants': {
            'user_456': 'editor',
          },
          'createdAt': DateTime.now().toIso8601String(),
          'lastEditedAt': DateTime.now().toIso8601String(),
          'lastEditedBy': 'user_456',
          'lastEditedByDisplayName': 'Erik Eriksson',
          'editCount': 3,
          'isActive': true,
          'menuTitle': 'Test Menu',
          'createdForDate': DateTime.now().toIso8601String(),
          'menuSnapshot': {
            'Måndag': [],
          },
        };

        final realtimeMenu = RealtimeMenu.fromJson(json);

        expect(realtimeMenu.id, equals('menu_123'));
        expect(realtimeMenu.menuTitle, equals('Test Menu'));
        expect(realtimeMenu.ownerId, equals('user_123'));
      });
    });

    group('Data Access Properties', () {
      late RealtimeMenu realtimeMenu;

      setUp(() {
        final data = _createTestMenuData();
        realtimeMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          data: data,
        );
      });

      test('should return menu title', () {
        expect(realtimeMenu.menuTitle, equals('Veckans meny'));
      });

      test('should return created for date', () {
        expect(realtimeMenu.createdForDate, isA<DateTime>());
      });

      test('should return menu snapshot', () {
        expect(realtimeMenu.menuSnapshot, isA<Map<String, List<Recipe>>>());
        expect(realtimeMenu.menuSnapshot.keys.length, equals(5));
      });

      test('should return menu notes', () {
        expect(realtimeMenu.menuNotes, equals('Test notes'));
      });

      test('should return favorite recipe IDs', () {
        expect(
            realtimeMenu.favoriteRecipeIds, equals(['recipe_1', 'recipe_2']));
      });

      test('should return original prompt', () {
        expect(realtimeMenu.originalPrompt, equals('Generate a healthy menu'));
      });

      test('should return categories', () {
        expect(realtimeMenu.categories, contains('Måndag'));
        expect(realtimeMenu.categories, contains('Tisdag'));
        expect(realtimeMenu.categories.length, equals(5));
      });

      test('should return all unique recipes', () {
        final recipes = realtimeMenu.allUniqueRecipes;
        expect(recipes.length, equals(4)); // 4 unique recipes across categories
      });
    });

    group('Menu Operations', () {
      late RealtimeMenu baseMenu;

      setUp(() {
        final data = _createTestMenuData();
        baseMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          data: data,
        );
      });

      test('should update basic info', () {
        final updated = baseMenu.updateBasicInfo(
          menuTitle: 'Ny veckomeny',
          menuNotes: 'Updated notes',
          editedBy: 'user_456',
          editedByDisplayName: 'Erik Eriksson',
        );

        expect(updated.menuTitle, equals('Ny veckomeny'));
        expect(updated.menuNotes, equals('Updated notes'));
        expect(updated.lastEditedBy, equals('user_456'));
        expect(updated.lastEditedByDisplayName, equals('Erik Eriksson'));
      });

      test('should add recipe to category', () {
        final newRecipe = _createTestRecipe(title: 'Tacos');

        final updated = baseMenu.addRecipeToCategory(
          categoryName: 'Torsdag',
          recipe: newRecipe,
          editedBy: 'user_456',
          editedByDisplayName: 'Erik Eriksson',
        );

        expect(updated.menuSnapshot['Torsdag']!.length, equals(1));
        expect(updated.menuSnapshot['Torsdag']!.first.title, equals('Tacos'));
        expect(updated.lastEditedBy, equals('user_456'));
      });

      test('should remove recipe from category', () {
        // Måndag starts with 1 recipe
        expect(baseMenu.menuSnapshot['Måndag']!.length, equals(1));

        final updated = baseMenu.removeRecipeFromCategory(
          categoryName: 'Måndag',
          recipeIndex: 0,
          editedBy: 'user_456',
          editedByDisplayName: 'Erik Eriksson',
        );

        // After removal it should be empty (0 recipes)
        expect(updated.menuSnapshot['Måndag']!.length, equals(0));
        expect(updated.lastEditedBy, equals('user_456'));
      });

      test('should move recipe between categories', () {
        // Måndag starts with 1 recipe, Torsdag starts empty
        expect(baseMenu.menuSnapshot['Måndag']!.length, equals(1));
        expect(baseMenu.menuSnapshot['Torsdag']!.length, equals(0));
        final recipeTitle = baseMenu.menuSnapshot['Måndag']!.first.title;

        final updated = baseMenu.moveRecipeBetweenCategories(
          fromCategory: 'Måndag',
          fromIndex: 0,
          toCategory: 'Torsdag',
          editedBy: 'user_456',
          editedByDisplayName: 'Erik Eriksson',
        );

        // After move: Måndag should be empty, Torsdag should have 1
        expect(updated.menuSnapshot['Måndag']!.length, equals(0));
        expect(updated.menuSnapshot['Torsdag']!.length, equals(1));
        expect(
            updated.menuSnapshot['Torsdag']!.first.title, equals(recipeTitle));
      });

      test('should clear category', () {
        final updated = baseMenu.clearCategory(
          categoryName: 'Måndag',
          editedBy: 'user_456',
          editedByDisplayName: 'Erik Eriksson',
        );

        expect(updated.menuSnapshot['Måndag']!.length, equals(0));
        expect(updated.lastEditedBy, equals('user_456'));
      });

      test('should update whole category', () {
        final newRecipes = [
          _createTestRecipe(title: 'Soppa'),
          _createTestRecipe(title: 'Sallad'),
        ];

        final updated = baseMenu.updateWholeCategory(
          categoryName: 'Måndag',
          recipes: newRecipes,
          editedBy: 'user_456',
          editedByDisplayName: 'Erik Eriksson',
        );

        expect(updated.menuSnapshot['Måndag']!.length, equals(2));
        expect(updated.menuSnapshot['Måndag']![0].title, equals('Soppa'));
        expect(updated.menuSnapshot['Måndag']![1].title, equals('Sallad'));
      });
    });

    group('Statistics', () {
      late RealtimeMenu realtimeMenu;

      setUp(() {
        final data = _createTestMenuData();
        realtimeMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          data: data,
        );
      });

      test('should return total recipe count', () {
        expect(realtimeMenu.totalRecipeCount, equals(4));
      });

      test('should return categories with recipes', () {
        expect(realtimeMenu.categoriesWithRecipes, equals(4));
      });

      test('should return empty categories count', () {
        expect(
            realtimeMenu.emptyCategoriesCount, equals(1)); // Torsdag is empty
      });

      test('should check if menu is complete', () {
        expect(realtimeMenu.isComplete,
            isTrue); // Has recipes in at least 2 categories
      });

      test('should check if menu is well balanced', () {
        expect(realtimeMenu.isWellBalanced,
            isTrue); // Has recipes in at least 3 categories
      });

      test('should return average recipes per category', () {
        expect(realtimeMenu.averageRecipesPerCategory,
            closeTo(0.8, 0.01)); // 4 recipes / 5 categories
      });

      test('should check if menu has favorites', () {
        expect(realtimeMenu.hasFavorites, isTrue);
        expect(realtimeMenu.favoritesCount, equals(2));
      });
    });

    group('Participant Operations', () {
      late RealtimeMenu baseMenu;

      setUp(() {
        final data = _createTestMenuData();
        baseMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          data: data,
        );
      });

      test('should add participant', () {
        final updated = baseMenu.addParticipant(
          'user_456',
          'Erik Eriksson',
          ResourcePermission.editor,
        );

        expect(updated.participants['user_456'],
            equals(ResourcePermission.editor));
      });

      test('should remove participant', () {
        final withParticipant = baseMenu.addParticipant(
          'user_456',
          'Erik Eriksson',
          ResourcePermission.editor,
        );

        final removed = withParticipant.removeParticipant('user_456');

        expect(removed.participants.containsKey('user_456'), isFalse);
      });

      test('should handle removing non-existent participant', () {
        // Should not throw, returns menu with incremented edit count
        final result = baseMenu.removeParticipant('user_999');
        expect(result.editCount, equals(baseMenu.editCount + 1));
        // Participants should be unchanged (user_999 wasn't there to begin with)
        expect(result.participants, equals(baseMenu.participants));
      });

      test('should update participant permission', () {
        final withParticipant = baseMenu.addParticipant(
          'user_456',
          'Erik Eriksson',
          ResourcePermission.editor,
        );

        final updated = withParticipant.updateParticipantPermission(
          'user_456',
          ResourcePermission.viewer,
        );

        expect(updated.participants['user_456'],
            equals(ResourcePermission.viewer));
      });

      test(
          'should add participant when updating permission for non-existent user',
          () {
        // Should add the participant if they don't exist
        final updated = baseMenu.updateParticipantPermission(
          'user_999',
          ResourcePermission.viewer,
        );
        expect(updated.participants['user_999'],
            equals(ResourcePermission.viewer));
        expect(updated.editCount, equals(baseMenu.editCount + 1));
      });

      test('should throw when removing owner', () {
        expect(
          () => baseMenu.removeParticipant('user_123'),
          throwsArgumentError,
        );
      });
    });

    group('Copy Methods', () {
      late RealtimeMenu baseMenu;

      setUp(() {
        final data = _createTestMenuData();
        baseMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna Andersson',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna Andersson',
          data: data,
        );
      });

      test('should copy with new menu data', () {
        final copied = baseMenu.copyWith(
          menuTitle: 'Updated Menu',
          menuNotes: 'New notes',
        );

        expect(copied.menuTitle, equals('Updated Menu'));
        expect(copied.menuNotes, equals('New notes'));
        expect(copied.id, equals(baseMenu.id));
        expect(copied.ownerId, equals(baseMenu.ownerId));
      });

      test('should copy with metadata', () {
        final copied = baseMenu.copyWithMetadata(
          lastEditedBy: 'user_456',
          lastEditedByDisplayName: 'Erik Eriksson',
          editCount: 5,
        );

        expect(copied.lastEditedBy, equals('user_456'));
        expect(copied.lastEditedByDisplayName, equals('Erik Eriksson'));
        expect(copied.editCount, equals(5));
        expect(copied.menuTitle, equals(baseMenu.menuTitle));
      });

      test('should increment edit count if not specified', () {
        final copied = baseMenu.copyWithMetadata();

        expect(copied.editCount, equals(baseMenu.editCount + 1));
      });
    });

    group('Edge Cases', () {
      test('should handle empty menu snapshot', () {
        final data = RealtimeMenuData(
          menuTitle: 'Empty Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        );

        final realtimeMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
          data: data,
        );

        expect(realtimeMenu.categories, isEmpty);
        expect(realtimeMenu.totalRecipeCount, equals(0));
        expect(realtimeMenu.isComplete, isFalse);
        expect(realtimeMenu.isWellBalanced, isFalse);
      });

      test('should handle Swedish characters', () {
        final data = RealtimeMenuData(
          menuTitle: 'Räksmörgås veckan',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Måndag': [_createTestRecipe(title: 'Räksmörgås')],
            'Tisdag': [_createTestRecipe(title: 'Köttbullar med lingonsylt')],
          },
          menuNotes: 'Åsa önskar räkor',
        );

        final realtimeMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Åsa Öberg',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Åsa Öberg',
          data: data,
        );

        expect(realtimeMenu.menuTitle, equals('Räksmörgås veckan'));
        expect(realtimeMenu.ownerDisplayName, equals('Åsa Öberg'));
        expect(realtimeMenu.menuNotes, equals('Åsa önskar räkor'));
      });

      test('should handle menu without optional fields', () {
        final data = RealtimeMenuData(
          menuTitle: 'Simple Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: {
            'Måndag': [_createTestRecipe()],
          },
          menuNotes: null,
          favoriteRecipeIds: null,
          originalPrompt: null,
        );

        final realtimeMenu = RealtimeMenu.fromData(
          id: 'menu_123',
          ownerId: 'user_123',
          ownerDisplayName: 'Anna',
          participants: {},
          createdAt: DateTime.now(),
          lastEditedAt: DateTime.now(),
          lastEditedBy: 'user_123',
          lastEditedByDisplayName: 'Anna',
          data: data,
        );

        expect(realtimeMenu.menuNotes, isNull);
        expect(realtimeMenu.favoriteRecipeIds, isNull);
        expect(realtimeMenu.originalPrompt, isNull);
        expect(realtimeMenu.hasFavorites, isFalse);
        expect(realtimeMenu.favoritesCount, equals(0));
      });
    });
  });
}
