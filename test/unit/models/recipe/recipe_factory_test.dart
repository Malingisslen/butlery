// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/recipe_factory.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import '../helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('RecipeFactory', () {
    group('Personal Recipe Creation', () {
      test('should create personal recipe with all parameters', () {
        final recipe = RecipeFactory.createPersonal(
          title: 'Köttbullar',
          description: 'Klassiska svenska köttbullar',
          ingredients: ['500g köttfärs', '1 ägg', '1 dl ströbröd'],
          instructions: ['Blanda allt', 'Forma bollar', 'Stek i panna'],
          mealType: 'Middag',
          createdBy: 'user_123',
          portions: 4,
          timeMinutes: 45,
          rating: 4.5,
          personalTagIds: ['Svenskt', 'Traditionellt'],
          sourceUrl: 'https://example.com',
          imageUrls: ['image1.jpg', 'image2.jpg'],
          isPublic: true,
        );

        expect(recipe.core.title, equals('Köttbullar'));
        expect(recipe.core.description, equals('Klassiska svenska köttbullar'));
        expect(recipe.core.ingredients.length, equals(3));
        expect(recipe.core.instructions.length, equals(3));
        expect(recipe.core.mealType, equals('Middag'));
        expect(recipe.core.createdBy, equals('user_123'));
        expect(recipe.core.portions, equals(4));
        expect(recipe.core.timeMinutes, equals(45));
        expect(recipe.core.rating, equals(4.5));
        expect(
          recipe.core.personalTagIds,
          equals(['Svenskt', 'Traditionellt']),
        );
        expect(recipe.core.sourceUrl, equals('https://example.com'));
        expect(recipe.core.imageUrls.length, equals(2));
        expect(recipe.core.isPublic, isTrue);
        expect(recipe.type, equals(RecipeType.personal));
        expect(recipe.socialData, isNull);
        expect(recipe.realtimeData, isNull);
      });

      test('should create personal recipe with minimal parameters', () {
        final recipe = RecipeFactory.createPersonal(
          title: 'Simple Recipe',
          description: 'A simple recipe',
          ingredients: ['Ingredient 1'],
          instructions: ['Step 1'],
          mealType: 'Lunch',
        );

        expect(recipe.core.title, equals('Simple Recipe'));
        expect(recipe.core.description, equals('A simple recipe'));
        expect(recipe.core.ingredients, equals(['Ingredient 1']));
        expect(recipe.core.instructions, equals(['Step 1']));
        expect(recipe.core.mealType, equals('Lunch'));
        expect(recipe.core.isPublic, isFalse); // Default value
        expect(recipe.type, equals(RecipeType.personal));
      });

      test('should create quick personal recipe', () {
        final recipe = RecipeFactory.createQuickPersonal(
          title: 'Snabb macka',
          ingredients: ['Bröd', 'Smör', 'Ost'],
          instructions: ['Bred smör', 'Lägg på ost'],
        );

        expect(recipe.core.title, equals('Snabb macka'));
        expect(recipe.core.description, equals('')); // Default empty
        expect(recipe.core.ingredients.length, equals(3));
        expect(recipe.core.instructions.length, equals(2));
        expect(recipe.core.mealType, equals('Middag')); // Default
        expect(recipe.type, equals(RecipeType.personal));
      });

      test('should create quick personal recipe with custom meal type', () {
        final recipe = RecipeFactory.createQuickPersonal(
          title: 'Frukost',
          ingredients: ['Yoghurt', 'Müsli'],
          instructions: ['Blanda'],
          mealType: 'Frukost',
          createdBy: 'user_456',
        );

        expect(recipe.core.mealType, equals('Frukost'));
        expect(recipe.core.createdBy, equals('user_456'));
      });
    });

    group('Shared Recipe Creation', () {
      test('should create shared recipe with all parameters', () {
        final recipe = RecipeFactory.createShared(
          title: 'Shared Pasta',
          description: 'A shared pasta recipe',
          ingredients: ['Pasta', 'Tomater', 'Basilika'],
          instructions: ['Koka pasta', 'Gör sås', 'Servera'],
          mealType: 'Middag',
          ownerId: 'owner_123',
          ownerDisplayName: 'Anna Andersson',
          portions: 6,
          timeMinutes: 30,
          rating: 4.8,
          personalTagIds: ['Italienskt', 'Pasta'],
          sourceUrl: 'https://recipe.com',
          imageUrls: ['pasta.jpg'],
          allowGuestViewing: false,
        );

        expect(recipe.core.title, equals('Shared Pasta'));
        expect(recipe.core.createdBy, equals('owner_123'));
        expect(recipe.core.isPublic, isTrue); // Shared recipes are public
        expect(recipe.type, equals(RecipeType.shared));
        expect(recipe.socialData, isNotNull);
        expect(recipe.socialData!.ownerId, equals('owner_123'));
        expect(recipe.socialData!.ownerDisplayName, equals('Anna Andersson'));
        expect(recipe.socialData!.allowGuestViewing, isFalse);
        expect(
          recipe.socialData!.allowMemberInvites,
          isFalse,
        ); // Shared don't allow invites
      });

      test('should create shared recipe with default guest viewing', () {
        final recipe = RecipeFactory.createShared(
          title: 'Public Recipe',
          description: 'Publicly viewable',
          ingredients: ['Item 1'],
          instructions: ['Step 1'],
          mealType: 'Lunch',
          ownerId: 'user_789',
          ownerDisplayName: 'Erik Eriksson',
        );

        expect(recipe.socialData!.allowGuestViewing, isTrue); // Default
      });
    });

    group('Collaborative Recipe Creation', () {
      test('should create collaborative recipe with member permissions', () {
        final memberPermissions = {
          'user_1': ResourcePermission.editor,
          'user_2': ResourcePermission.viewer,
          'user_3': ResourcePermission.admin,
        };

        final recipe = RecipeFactory.createCollaborative(
          title: 'Team Recipe',
          description: 'Collaborative cooking',
          ingredients: ['Ingredient 1', 'Ingredient 2'],
          instructions: ['Step 1', 'Step 2'],
          mealType: 'Middag',
          ownerId: 'owner_456',
          ownerDisplayName: 'Lars Larsson',
          memberPermissions: memberPermissions,
          allowGuestViewing: true,
          allowMemberInvites: false,
          descriptionCollaborative: 'Let\'s cook together!',
          portions: 8,
        );

        expect(recipe.type, equals(RecipeType.collaborative));
        expect(recipe.core.isPublic, isTrue);
        expect(recipe.socialData!.memberPermissions, equals(memberPermissions));
        expect(recipe.socialData!.allowGuestViewing, isTrue);
        expect(recipe.socialData!.allowMemberInvites, isFalse);
        expect(
          recipe.socialData!.descriptionCollaborative,
          equals('Let\'s cook together!'),
        );
      });

      test('should create collaborative recipe with default settings', () {
        final recipe = RecipeFactory.createCollaborative(
          title: 'Default Collab',
          description: 'Default settings',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
          ownerId: 'owner_789',
          ownerDisplayName: 'User Name',
        );

        expect(recipe.socialData!.memberPermissions, isEmpty);
        expect(recipe.socialData!.allowGuestViewing, isFalse); // Default
        expect(recipe.socialData!.allowMemberInvites, isTrue); // Default
      });
    });

    group('Realtime Recipe Creation', () {
      test('should create realtime recipe with active editors', () {
        final activeEditors = ['editor_1', 'editor_2', 'editor_3'];
        final memberPermissions = {
          'editor_1': ResourcePermission.editor,
          'editor_2': ResourcePermission.editor,
          'editor_3': ResourcePermission.viewer,
        };

        final recipe = RecipeFactory.createRealtime(
          title: 'Live Recipe',
          description: 'Real-time collaboration',
          ingredients: ['Live ingredient'],
          instructions: ['Live step'],
          mealType: 'Middag',
          ownerId: 'realtime_owner',
          ownerDisplayName: 'Realtime Owner',
          memberPermissions: memberPermissions,
          activeEditorIds: activeEditors,
          portions: 10,
          timeMinutes: 60,
        );

        expect(recipe.type, equals(RecipeType.realtime));
        expect(recipe.core.isPublic, isTrue);
        expect(
          recipe.socialData!.allowGuestViewing,
          isTrue,
        ); // Default for realtime
        expect(
          recipe.socialData!.allowMemberInvites,
          isTrue,
        ); // Default for realtime
        expect(recipe.realtimeData, isNotNull);
        expect(recipe.realtimeData!.activeEditorIds, equals(activeEditors));
        expect(
          recipe.realtimeData!.lastEditedByUserId,
          equals('realtime_owner'),
        );
        expect(
          recipe.realtimeData!.lastEditedByDisplayName,
          equals('Realtime Owner'),
        );
        expect(recipe.realtimeData!.editCount, equals(0));
        expect(recipe.realtimeData!.isActive, isTrue);
      });

      test('should create realtime recipe without active editors', () {
        final recipe = RecipeFactory.createRealtime(
          title: 'No Editors',
          description: 'No active editors',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
        );

        expect(recipe.realtimeData!.activeEditorIds, isNull);
        expect(recipe.realtimeData!.lastEditedAt, isNotNull);
      });
    });

    group('Recipe Conversion Methods', () {
      late Recipe personalRecipe;

      setUp(() {
        personalRecipe = RecipeFactory.createPersonal(
          title: 'My Recipe',
          description: 'Personal recipe',
          ingredients: ['A', 'B', 'C'],
          instructions: ['1', '2', '3'],
          mealType: 'Middag',
          createdBy: 'original_owner',
          portions: 4,
          personalTagIds: ['tag1', 'tag2'],
        );
      });

      test('should convert personal to shared', () {
        final sharedRecipe = RecipeFactory.convertToShared(
          personalRecipe,
          ownerId: 'new_owner',
          ownerDisplayName: 'New Owner',
          allowGuestViewing: false,
        );

        expect(sharedRecipe.type, equals(RecipeType.shared));
        expect(sharedRecipe.core.isPublic, isTrue);
        expect(sharedRecipe.core.title, equals('My Recipe'));
        expect(sharedRecipe.core.ingredients, equals(['A', 'B', 'C']));
        expect(sharedRecipe.socialData!.ownerId, equals('new_owner'));
        expect(sharedRecipe.socialData!.ownerDisplayName, equals('New Owner'));
        expect(sharedRecipe.socialData!.allowGuestViewing, isFalse);
        expect(sharedRecipe.socialData!.allowMemberInvites, isFalse);
      });

      test('should throw when converting non-personal to shared', () {
        final sharedRecipe = RecipeFactory.createShared(
          title: 'Already Shared',
          description: 'Desc',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
        );

        expect(
          () => RecipeFactory.convertToShared(
            sharedRecipe,
            ownerId: 'new',
            ownerDisplayName: 'New',
          ),
          throwsArgumentError,
        );
      });

      test('should convert personal to collaborative', () {
        final members = {
          'member_1': ResourcePermission.editor,
          'member_2': ResourcePermission.viewer,
        };

        final collabRecipe = RecipeFactory.convertToCollaborative(
          personalRecipe,
          ownerId: 'collab_owner',
          ownerDisplayName: 'Collab Owner',
          initialMembers: members,
          allowGuestViewing: true,
          allowMemberInvites: false,
          descriptionCollaborative: 'Let\'s collaborate!',
        );

        expect(collabRecipe.type, equals(RecipeType.collaborative));
        expect(collabRecipe.core.isPublic, isTrue);
        expect(collabRecipe.socialData!.memberPermissions, equals(members));
        expect(collabRecipe.socialData!.allowGuestViewing, isTrue);
        expect(collabRecipe.socialData!.allowMemberInvites, isFalse);
        expect(
          collabRecipe.socialData!.descriptionCollaborative,
          equals('Let\'s collaborate!'),
        );
      });

      test('should throw when converting non-personal to collaborative', () {
        final sharedRecipe = RecipeFactory.createShared(
          title: 'Shared',
          description: 'Desc',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
        );

        expect(
          () => RecipeFactory.convertToCollaborative(
            sharedRecipe,
            ownerId: 'new',
            ownerDisplayName: 'New',
          ),
          throwsArgumentError,
        );
      });

      test('should convert collaborative to realtime', () {
        final collabRecipe = RecipeFactory.createCollaborative(
          title: 'Collab Recipe',
          description: 'Collaborative',
          ingredients: ['X'],
          instructions: ['Y'],
          mealType: 'Lunch',
          ownerId: 'collab_owner',
          ownerDisplayName: 'Collab Owner',
        );

        final realtimeRecipe = RecipeFactory.convertToRealtime(
          collabRecipe,
          activeEditorIds: ['editor_1', 'editor_2'],
        );

        expect(realtimeRecipe.type, equals(RecipeType.realtime));
        expect(realtimeRecipe.core, equals(collabRecipe.core));
        expect(realtimeRecipe.socialData, equals(collabRecipe.socialData));
        expect(realtimeRecipe.realtimeData, isNotNull);
        expect(
          realtimeRecipe.realtimeData!.activeEditorIds,
          equals(['editor_1', 'editor_2']),
        );
        expect(
          realtimeRecipe.realtimeData!.lastEditedByUserId,
          equals('collab_owner'),
        );
        expect(realtimeRecipe.realtimeData!.editCount, equals(0));
        expect(realtimeRecipe.realtimeData!.isActive, isTrue);
      });

      test('should throw when converting non-collaborative to realtime', () {
        expect(
          () => RecipeFactory.convertToRealtime(personalRecipe),
          throwsArgumentError,
        );
      });

      test('should create personal copy from shared recipe', () {
        final sharedRecipe = RecipeFactory.createShared(
          title: 'Shared Recipe',
          description: 'From Anna',
          ingredients: ['Pasta', 'Tomater'],
          instructions: ['Koka', 'Servera'],
          mealType: 'Middag',
          ownerId: 'anna_123',
          ownerDisplayName: 'Anna Andersson',
          portions: 4,
          rating: 4.5,
          personalTagIds: ['Italian'],
          imageUrls: ['image.jpg'],
        );

        final personalCopy = RecipeFactory.createPersonalCopy(
          sharedRecipe,
          newOwnerId: 'user_456',
        );

        expect(personalCopy.type, equals(RecipeType.personal));
        expect(
          personalCopy.core.title,
          equals('Shared Recipe (från Anna Andersson)'),
        );
        expect(personalCopy.core.createdBy, equals('user_456'));
        expect(personalCopy.core.isPublic, isFalse);
        expect(personalCopy.core.ingredients, equals(['Pasta', 'Tomater']));
        expect(
          personalCopy.core.sourceUrl,
          equals('Kopierat från: Shared Recipe'),
        );
        expect(personalCopy.socialData, isNull);
      });

      test('should create personal copy with custom title', () {
        final personalCopy = RecipeFactory.createPersonalCopy(
          personalRecipe,
          newOwnerId: 'new_user',
          customTitle: 'My Version',
        );

        expect(personalCopy.core.title, equals('My Version'));
        expect(personalCopy.core.sourceUrl, equals('Kopierat från: My Recipe'));
      });

      test(
        'should create personal copy from recipe without owner display name',
        () {
          final simpleRecipe = RecipeFactory.createPersonal(
            title: 'Simple',
            description: 'Desc',
            ingredients: ['A'],
            instructions: ['B'],
            mealType: 'Lunch',
          );

          final copy = RecipeFactory.createPersonalCopy(
            simpleRecipe,
            newOwnerId: 'copier',
          );

          expect(copy.core.title, equals('Simple (kopia)'));
        },
      );
    });

    group('Template and Import Methods', () {
      test('should create empty template with defaults', () {
        final template = RecipeFactory.createEmptyTemplate();

        expect(template.core.title, equals('Nytt recept'));
        expect(template.core.description, equals(''));
        expect(template.core.ingredients, equals(['']));
        expect(template.core.instructions, equals(['']));
        expect(template.core.mealType, equals('Middag'));
        expect(template.type, equals(RecipeType.personal));
      });

      test('should create empty template with custom values', () {
        final template = RecipeFactory.createEmptyTemplate(
          title: 'Min mall',
          mealType: 'Frukost',
          createdBy: 'user_123',
        );

        expect(template.core.title, equals('Min mall'));
        expect(template.core.mealType, equals('Frukost'));
        expect(template.core.createdBy, equals('user_123'));
      });

      test('should create recipe from import', () {
        final imported = RecipeFactory.createFromImport(
          title: 'Imported Recipe',
          description: 'From the web',
          ingredients: ['Web ingredient 1', 'Web ingredient 2'],
          instructions: ['Web step 1', 'Web step 2', 'Web step 3'],
          sourceUrl: 'https://source.com/recipe',
          mealType: 'Lunch',
          createdBy: 'importer_123',
          portions: 6,
          timeMinutes: 35,
          imageUrls: ['image1.jpg', 'image2.jpg'],
        );

        expect(imported.core.title, equals('Imported Recipe'));
        expect(imported.core.description, equals('From the web'));
        expect(imported.core.ingredients.length, equals(2));
        expect(imported.core.instructions.length, equals(3));
        expect(imported.core.sourceUrl, equals('https://source.com/recipe'));
        expect(imported.core.mealType, equals('Lunch'));
        expect(imported.core.createdBy, equals('importer_123'));
        expect(imported.core.portions, equals(6));
        expect(imported.core.timeMinutes, equals(35));
        expect(imported.core.imageUrls.length, equals(2));
        expect(imported.type, equals(RecipeType.personal));
      });

      test('should create import with minimal data', () {
        final imported = RecipeFactory.createFromImport(
          title: 'Minimal Import',
          description: 'Basic',
          ingredients: ['A'],
          instructions: ['B'],
          sourceUrl: 'https://example.com',
        );

        expect(imported.core.mealType, equals('Middag')); // Default
        expect(imported.core.imageUrls, isEmpty); // Default empty list
      });
    });

    group('Validation and Helper Methods', () {
      test('should validate basic recipe data', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: 'Valid Title',
            ingredients: ['Ingredient 1', 'Ingredient 2'],
            instructions: ['Step 1', 'Step 2'],
            mealType: 'Middag',
          ),
          isTrue,
        );
      });

      test('should reject empty title', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: '   ',
            ingredients: ['A'],
            instructions: ['B'],
            mealType: 'Lunch',
          ),
          isFalse,
        );
      });

      test('should reject empty ingredients list', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: 'Title',
            ingredients: [],
            instructions: ['Step'],
            mealType: 'Lunch',
          ),
          isFalse,
        );
      });

      test('should reject all empty ingredients', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: 'Title',
            ingredients: ['', '   ', ''],
            instructions: ['Step'],
            mealType: 'Lunch',
          ),
          isFalse,
        );
      });

      test('should reject empty instructions list', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: 'Title',
            ingredients: ['Ingredient'],
            instructions: [],
            mealType: 'Lunch',
          ),
          isFalse,
        );
      });

      test('should reject all empty instructions', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: 'Title',
            ingredients: ['Ingredient'],
            instructions: ['', '   '],
            mealType: 'Lunch',
          ),
          isFalse,
        );
      });

      test('should reject empty meal type', () {
        expect(
          RecipeFactory.validateBasicRecipeData(
            title: 'Title',
            ingredients: ['Ingredient'],
            instructions: ['Step'],
            mealType: '   ',
          ),
          isFalse,
        );
      });

      test('should get default meal types', () {
        final mealTypes = RecipeFactory.getDefaultMealTypes();

        expect(mealTypes, contains('Frukost'));
        expect(mealTypes, contains('Lunch'));
        expect(mealTypes, contains('Middag'));
        expect(mealTypes, contains('Mellanmål'));
        expect(mealTypes, contains('Efterrätt'));
        expect(mealTypes, contains('Dryck'));
        expect(mealTypes, contains('Bakning'));
        expect(mealTypes.length, equals(7));
      });

      test('should get common tags', () {
        final tags = RecipeFactory.getCommonTags();

        expect(tags, contains('Snabbt'));
        expect(tags, contains('Vegetariskt'));
        expect(tags, contains('Veganskt'));
        expect(tags, contains('Glutenfritt'));
        expect(tags, contains('Laktosfritt'));
        expect(tags, contains('Barnvänligt'));
        expect(tags, contains('Festmat'));
        expect(tags, contains('Vardagsmat'));
        expect(tags, contains('Hälsosamt'));
        expect(tags, contains('Billigt'));
        expect(tags.length, equals(10));
      });
    });

    group('Edge Cases', () {
      test('should handle Swedish characters in recipe data', () {
        final recipe = RecipeFactory.createPersonal(
          title: 'Räksmörgås',
          description: 'Äkta svensk räkmacka med löjrom',
          ingredients: ['Räkor', 'Ägg', 'Löjrom', 'Smörgås'],
          instructions: ['Koka ägg', 'Lägg på räkor', 'Toppa med löjrom'],
          mealType: 'Förrätt',
          personalTagIds: ['Sjömat', 'Högtid'],
        );

        expect(recipe.core.title, equals('Räksmörgås'));
        expect(recipe.core.description, contains('Äkta svensk'));
        expect(recipe.core.ingredients, contains('Löjrom'));
        expect(recipe.core.mealType, equals('Förrätt'));
      });

      test('should handle very long lists', () {
        final longIngredients = List.generate(100, (i) => 'Ingredient $i');
        final longInstructions = List.generate(50, (i) => 'Step $i');

        final recipe = RecipeFactory.createPersonal(
          title: 'Complex Recipe',
          description: 'Very complex',
          ingredients: longIngredients,
          instructions: longInstructions,
          mealType: 'Middag',
        );

        expect(recipe.core.ingredients.length, equals(100));
        expect(recipe.core.instructions.length, equals(50));
      });

      test('should preserve offline data during conversion', () {
        final personalRecipe = RecipeFactory.createPersonal(
          title: 'Personal',
          description: 'Desc',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
        );

        // Manually add offline data (normally done by other systems)
        final recipeWithOffline = Recipe(
          core: personalRecipe.core,
          type: personalRecipe.type,
          offlineData: RecipeOfflineData(
            lastSyncedAt: DateTime(2025, 1, 1),
            isModifiedOffline: false,
          ),
        );

        final sharedRecipe = RecipeFactory.convertToShared(
          recipeWithOffline,
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
        );

        expect(sharedRecipe.offlineData, isNotNull);
        expect(
          sharedRecipe.offlineData!.lastSyncedAt,
          equals(DateTime(2025, 1, 1)),
        );
        expect(sharedRecipe.offlineData!.isModifiedOffline, isFalse);
      });

      test(
        'should handle recipes with null tags when creating personal copy',
        () {
          final recipe = RecipeFactory.createPersonal(
            title: 'No Tags',
            description: 'Recipe without tags',
            ingredients: ['A'],
            instructions: ['B'],
            mealType: 'Lunch',
            personalTagIds: null,
          );

          final copy = RecipeFactory.createPersonalCopy(
            recipe,
            newOwnerId: 'copier',
          );

          expect(copy.core.personalTagIds, isNull);
        },
      );

      test(
        'BUG-2: createPersonalCopy should preserve tagResult from source recipe',
        () {
          // Arrange: Create a recipe with tag result data
          final tagResult = TagResult(
            tags: {'vegetarisk', 'pasta-dish', 'mild'},
            allergenStatus: {
              'gluten': TriState.contains,
              'mjölk': TriState.free,
            },
            dietaryStatus: {'vegetarisk': TriState.free},
            coverage: 0.95,
            unknownIngredients: ['unknown-spice'],
            generatedAt: DateTime(2025, 6, 1),
            generatorVersion: '1.0.0',
          );

          final sourceRecipe = Recipe(
            core: RecipeCore(
              title: 'Pasta med grönsakssås',
              description: 'Vegetarisk pasta',
              ingredients: ['Pasta', 'Tomater', 'Basilika'],
              instructions: ['Koka pasta', 'Gör sås'],
              mealType: 'Middag',
              tagResult: tagResult,
            ),
            type: RecipeType.shared,
            socialData: const RecipeSocialData(
              ownerId: 'owner_123',
              ownerDisplayName: 'Anna',
            ),
          );

          // Act
          final copy = RecipeFactory.createPersonalCopy(
            sourceRecipe,
            newOwnerId: 'new_user',
          );

          // Assert
          expect(
            copy.core.tagResult,
            isNotNull,
            reason: 'tagResult should be preserved in personal copy',
          );
          expect(copy.core.tagResult!.tags, contains('vegetarisk'));
          expect(copy.core.tagResult!.tags, contains('pasta-dish'));
          expect(copy.core.tagResult!.coverage, 0.95);
        },
      );

      test(
        'BUG-2: createPersonalCopy should preserve tagOverrides from source recipe',
        () {
          // Arrange
          final tagOverrides = TagOverrides(
            allergenOverrides: {'gluten': TriState.free},
            addedTags: {'hälsosam'},
            removedTags: {'stark'},
            lastEditedAt: DateTime(2025, 5, 15),
            lastEditedBy: 'owner_123',
          );

          final sourceRecipe = Recipe(
            core: RecipeCore(
              title: 'Test recipe',
              description: 'Test',
              ingredients: ['A', 'B'],
              instructions: ['Step 1'],
              mealType: 'Lunch',
              tagOverrides: tagOverrides,
            ),
            type: RecipeType.personal,
          );

          // Act
          final copy = RecipeFactory.createPersonalCopy(
            sourceRecipe,
            newOwnerId: 'copier_456',
          );

          // Assert
          expect(
            copy.core.tagOverrides,
            isNotNull,
            reason: 'tagOverrides should be preserved in personal copy',
          );
          expect(
            copy.core.tagOverrides!.allergenOverrides['gluten'],
            TriState.free,
          );
          expect(copy.core.tagOverrides!.addedTags, contains('hälsosam'));
          expect(copy.core.tagOverrides!.removedTags, contains('stark'));
        },
      );

      test(
        'BUG-2: createPersonalCopy should preserve ingredientsNormalized from source recipe',
        () {
          // Arrange
          final normalized = ['pasta', 'tomat', 'basilika', 'olivolja'];

          final sourceRecipe = Recipe(
            core: RecipeCore(
              title: 'Pasta',
              description: 'Test',
              ingredients: [
                '400g pasta',
                '3 tomater',
                'Basilika',
                '2 msk olivolja',
              ],
              instructions: ['Koka'],
              mealType: 'Middag',
              ingredientsNormalized: normalized,
            ),
            type: RecipeType.shared,
            socialData: const RecipeSocialData(
              ownerId: 'owner_123',
              ownerDisplayName: 'Anna',
            ),
          );

          // Act
          final copy = RecipeFactory.createPersonalCopy(
            sourceRecipe,
            newOwnerId: 'new_user',
          );

          // Assert
          expect(
            copy.core.ingredientsNormalized,
            isNotNull,
            reason: 'ingredientsNormalized should be preserved',
          );
          expect(copy.core.ingredientsNormalized, equals(normalized));
        },
      );

      test(
        'BUG-2: createPersonalCopy should handle null tagResult, tagOverrides, and ingredientsNormalized',
        () {
          // Arrange: Recipe with all tag fields null
          final sourceRecipe = Recipe(
            core: RecipeCore(
              title: 'Legacy recipe',
              description: 'No tagging data',
              ingredients: ['A'],
              instructions: ['B'],
              mealType: 'Lunch',
              // tagResult, tagOverrides, ingredientsNormalized are all null
            ),
            type: RecipeType.personal,
          );

          // Act
          final copy = RecipeFactory.createPersonalCopy(
            sourceRecipe,
            newOwnerId: 'copier',
          );

          // Assert: null fields stay null
          expect(copy.core.tagResult, isNull);
          expect(copy.core.tagOverrides, isNull);
          expect(copy.core.ingredientsNormalized, isNull);
        },
      );

      test('should create valid timestamps for realtime recipes', () {
        final before = DateTime.now();

        final recipe = RecipeFactory.createRealtime(
          title: 'Realtime',
          description: 'Test',
          ingredients: ['A'],
          instructions: ['B'],
          mealType: 'Lunch',
          ownerId: 'owner',
          ownerDisplayName: 'Owner',
        );

        final after = DateTime.now();

        expect(recipe.realtimeData!.lastEditedAt, isNotNull);
        expect(
          recipe.realtimeData!.lastEditedAt!.isAfter(before) ||
              recipe.realtimeData!.lastEditedAt!.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          recipe.realtimeData!.lastEditedAt!.isBefore(after) ||
              recipe.realtimeData!.lastEditedAt!.isAtSameMomentAs(after),
          isTrue,
        );
      });
    });
  });
}
