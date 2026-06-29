/// Comprehensive test suite for Recipe unified model
///
/// Tests all aspects of the Recipe model including:
/// - RecipeCore construction and properties
/// - Recipe facade with different types
/// - Serialization/deserialization (JSON and Firestore)
/// - copyWith functionality
/// - Helper methods and computed properties
/// - Swedish text formatting
/// - Edge cases and validation
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tag_overrides.dart';
import 'package:butlery/models/tagging/tri_state.dart';

import 'helpers/model_test_base.dart';
import 'helpers/serialization_helper.dart';
import 'helpers/validation_helper.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  ModelTestBase.testModelGroup('Recipe Unified Model', () {
    late Recipe testRecipe;
    late Map<String, dynamic> validJson;

    setUp(() {
      // Create test recipe using factory
      testRecipe = RecipeFactory.build(
        id: 'recipe_123',
        title: 'Köttbullar med potatismos',
        description: 'Klassiska svenska köttbullar',
        ingredients: [
          '500g köttfärs',
          '1 dl ströbröd',
          '1 dl mjölk',
          '1 ägg',
          '1 lök, finhackad',
        ],
        instructions: [
          'Blanda ströbröd och mjölk',
          'Fräs löken',
          'Blanda alla ingredienser',
          'Forma köttbullar',
          'Stek i smör',
        ],
        mealType: 'Middag',
        portions: 4,
        timeMinutes: 45,
        rating: 4.5,
        personalTagIds: ['svensk', 'köttbullar', 'middag'],
      );

      validJson = SerializationHelper.createValidRecipeJson();
    });

    group('RecipeCore Construction', () {
      test('should create RecipeCore with all required fields', () {
        // Arrange
        final core = RecipeCore(
          title: 'Test Recipe',
          description: 'Test description',
          ingredients: ['Ingredient 1'],
          instructions: ['Step 1'],
          mealType: 'Lunch',
        );

        // Assert
        expect(core.id, isNotEmpty);
        expect(core.title, equals('Test Recipe'));
        expect(core.description, equals('Test description'));
        expect(core.ingredients, hasLength(1));
        expect(core.instructions, hasLength(1));
        expect(core.mealType, equals('Lunch'));
        expect(core.createdAt, isA<DateTime>());
        expect(core.updatedAt, isA<DateTime>());
      });

      test('should generate unique ID if not provided', () {
        // Arrange
        final core1 = RecipeCore(
          title: 'Recipe 1',
          description: 'Description 1',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
        );

        final core2 = RecipeCore(
          title: 'Recipe 2',
          description: 'Description 2',
          ingredients: [],
          instructions: [],
          mealType: 'Dinner',
        );

        // Assert
        expect(core1.id, isNotEmpty);
        expect(core2.id, isNotEmpty);
        expect(core1.id, isNot(equals(core2.id)));
      });

      test('should use provided optional fields', () {
        // Arrange
        final lastCooked = DateTime(2024, 1, 1);
        final core = RecipeCore(
          id: 'custom_id',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          portions: 6,
          timeMinutes: 30,
          rating: 4.0,
          personalTagIds: ['test', 'recipe'],
          sourceUrl: 'https://example.com',
          imageUrls: ['image1.jpg', 'image2.jpg'],
          createdBy: 'user_123',
          isPublic: true,
          lastCookedAt: lastCooked,
        );

        // Assert
        expect(core.id, equals('custom_id'));
        expect(core.portions, equals(6));
        expect(core.timeMinutes, equals(30));
        expect(core.rating, equals(4.0));
        expect(core.personalTagIds, equals(['test', 'recipe']));
        expect(core.sourceUrl, equals('https://example.com'));
        expect(core.imageUrls, hasLength(2));
        expect(core.createdBy, equals('user_123'));
        expect(core.isPublic, isTrue);
        expect(core.lastCookedAt, equals(lastCooked));
      });
    });

    group('RecipeCore copyWith', () {
      test('should create copy with updated fields', () async {
        // Arrange
        final original = testRecipe.core;

        // Add small delay to ensure timestamp difference
        await Future.delayed(const Duration(milliseconds: 10));

        // Act
        final updated = original.copyWith(
          title: 'Updated Title',
          portions: 8,
          rating: 5.0,
        );

        // Assert
        expect(updated.id, equals(original.id)); // ID unchanged
        expect(updated.title, equals('Updated Title'));
        expect(updated.portions, equals(8));
        expect(updated.rating, equals(5.0));
        expect(updated.description, equals(original.description)); // Unchanged
        expect(updated.createdAt, equals(original.createdAt)); // Unchanged
        expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);
      });

      test('should preserve all fields when not specified', () {
        // Arrange
        final original = testRecipe.core;

        // Act
        final copy = original.copyWith();

        // Assert
        expect(copy.id, equals(original.id));
        expect(copy.title, equals(original.title));
        expect(copy.description, equals(original.description));
        expect(copy.ingredients, equals(original.ingredients));
        expect(copy.instructions, equals(original.instructions));
        expect(copy.mealType, equals(original.mealType));
      });
    });

    group('RecipeCore Helper Methods', () {
      test('should correctly determine hasImages', () {
        // Arrange
        final withImages = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          imageUrls: ['image1.jpg'],
        );

        final withoutImages = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
        );

        // Assert
        expect(withImages.hasImages, isTrue);
        expect(withoutImages.hasImages, isFalse);
      });

      test('should get primaryImageUrl correctly', () {
        // Arrange
        final withImages = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          imageUrls: ['first.jpg', 'second.jpg'],
        );

        final withoutImages = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
        );

        // Assert
        expect(withImages.primaryImageUrl, equals('first.jpg'));
        expect(withoutImages.primaryImageUrl, isNull);
      });

      test('should format cookTimeText in Swedish', () {
        // Arrange
        final withTime = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          timeMinutes: 45,
        );

        final withoutTime = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
        );

        // Assert
        expect(withTime.cookTimeText, equals('45 minuter'));
        expect(withoutTime.cookTimeText, equals('–'));
      });

      test('should format lastCookedText in Swedish', () {
        // Arrange
        final now = DateTime.now();

        final cookedToday = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          lastCookedAt: now,
        );

        final cookedYesterday = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          lastCookedAt: now.subtract(const Duration(days: 1)),
        );

        final cookedLastWeek = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
          lastCookedAt: now.subtract(const Duration(days: 7)),
        );

        final neverCooked = RecipeCore(
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
        );

        // Assert
        expect(cookedToday.lastCookedText, equals('Tillagad idag'));
        expect(cookedYesterday.lastCookedText, equals('Tillagad igår'));
        expect(
          cookedLastWeek.lastCookedText,
          equals('Tillagad för 7 dagar sedan'),
        );
        expect(neverCooked.lastCookedText, isNull);
      });
    });

    group('RecipeCore JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        // Arrange
        final core = testRecipe.core;

        // Act
        final json = core.toJson();

        // Assert
        expect(json, isA<Map<String, dynamic>>());
        expect(json['id'], equals(core.id));
        expect(json['title'], equals(core.title));
        expect(json['description'], equals(core.description));
        expect(json['ingredients'], equals(core.ingredients));
        expect(json['instructions'], equals(core.instructions));
        expect(json['mealType'], equals(core.mealType));
        expect(json['portions'], equals(core.portions));
        expect(json['timeMinutes'], equals(core.timeMinutes));
        expect(json['rating'], equals(core.rating));
        expect(json['personalTagIds'], equals(core.personalTagIds));
        expect(json['createdAt'], isA<String>());
        expect(json['updatedAt'], isA<String>());
      });

      test('should deserialize from JSON correctly', () {
        // Act
        final core = RecipeCore.fromJson(validJson);

        // Assert
        expect(core.id, equals(validJson['id']));
        expect(core.title, equals(validJson['title']));
        expect(core.description, equals(validJson['description']));
        expect(core.ingredients, equals(validJson['ingredients']));
        expect(core.instructions, equals(validJson['instructions']));
        expect(core.mealType, equals(validJson['mealType']));
        expect(core.portions, equals(validJson['portions']));
        expect(core.timeMinutes, equals(validJson['timeMinutes']));
        expect(core.rating, equals(validJson['rating']));
        expect(core.personalTagIds, equals(validJson['personalTagIds']));
      });

      test('should round-trip JSON serialization', () {
        // Arrange
        final original = testRecipe.core;

        // Act
        final json = original.toJson();
        final deserialized = RecipeCore.fromJson(json);
        final json2 = deserialized.toJson();

        // Assert - core fields preserved
        expect(deserialized.id, equals(original.id));
        expect(deserialized.title, equals(original.title));
        expect(deserialized.ingredients, equals(original.ingredients));

        // After first round-trip, personalTags is lazy-migrated from
        // personalTagIds. A second round-trip should be stable.
        final deserialized2 = RecipeCore.fromJson(json2);
        final json3 = deserialized2.toJson();
        expect(json3, equals(json2));
      });
    });

    group('RecipeCore Firestore Serialization', () {
      test('should serialize to Firestore format', () {
        // Arrange
        final core = testRecipe.core;

        // Act
        final firestore = core.toFirestore();

        // Assert
        expect(firestore['id'], equals(core.id));
        expect(firestore['title'], equals(core.title));
        expect(firestore['createdAt'], isA<Timestamp>());
        expect(firestore['updatedAt'], isA<Timestamp>());
        if (core.lastCookedAt != null) {
          expect(firestore['lastCookedAt'], isA<Timestamp>());
        }
      });

      test('should deserialize from Firestore map', () {
        // Arrange
        final firestoreData = {
          'title': 'Firestore Recipe',
          'description': 'From Firestore',
          'ingredients': ['Item 1'],
          'instructions': ['Step 1'],
          'mealType': 'Lunch',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 2)),
        };

        // Act
        final core = RecipeCore.fromMap('firestore_123', firestoreData);

        // Assert
        expect(core.id, equals('firestore_123'));
        expect(core.title, equals('Firestore Recipe'));
        expect(core.description, equals('From Firestore'));
        expect(core.createdAt, equals(DateTime(2024, 1, 1)));
        expect(core.updatedAt, equals(DateTime(2024, 1, 2)));
      });
    });

    group('RecipeCore family-rating denormalization (BUT family Phase 3)', () {
      RecipeCore familyCore() => RecipeCore(
        title: 'Fläskpannkaka',
        description: 'Test',
        ingredients: const ['ägg'],
        instructions: const ['vispa'],
        mealType: 'middag',
        familyAverage: 4.2,
        familyRatingCount: 4,
      );

      test(
        'familyAverage/familyRatingCount survive a Firestore round-trip',
        () {
          final restored = RecipeCore.fromMap(
            'r1',
            familyCore().toFirestore(),
          );
          expect(restored.familyAverage, 4.2);
          expect(restored.familyRatingCount, 4);
        },
      );

      test('familyAverage/familyRatingCount survive a JSON round-trip', () {
        final restored = RecipeCore.fromJson(familyCore().toJson());
        expect(restored.familyAverage, 4.2);
        expect(restored.familyRatingCount, 4);
      });

      test('absent on a legacy doc → null (lazy-compat, no backfill)', () {
        final legacy = RecipeCore.fromMap('r1', {
          'title': 'Gammalt recept',
          'ingredients': ['x'],
          'instructions': ['y'],
          'mealType': 'middag',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        });
        expect(legacy.familyAverage, isNull);
        expect(legacy.familyRatingCount, isNull);
      });

      test(
        'copyWith sets the family fields without bumping updatedAt when '
        'preserved',
        () {
          final original = familyCore();
          final updated = Recipe(
            core: original,
            type: RecipeType.personal,
          ).copyWith(familyAverage: 5.0, updatedAt: original.updatedAt);
          expect(updated.core.familyAverage, 5.0);
          expect(updated.core.updatedAt, original.updatedAt);
        },
      );
    });

    group('Recipe Facade Construction', () {
      test('should create personal recipe', () {
        // Arrange & Act
        final recipe = RecipeFactory.buildPersonal(
          id: 'personal_123',
          title: 'My Personal Recipe',
        );

        // Assert
        expect(recipe.type, equals(RecipeType.personal));
        expect(recipe.core.title, equals('My Personal Recipe'));
        expect(recipe.socialData, isNull);
        expect(recipe.realtimeData, isNull);
        expect(recipe.offlineData, isNull);
      });

      test('should create shared recipe', () {
        // Arrange & Act
        final recipe = RecipeFactory.buildShared(
          id: 'shared_123',
          title: 'Shared Recipe',
          isPublic: true,
        );

        // Assert
        expect(recipe.type, equals(RecipeType.shared));
        expect(recipe.core.isPublic, isTrue);
        expect(recipe.socialData, isNotNull);
        expect(recipe.socialData!.allowGuestViewing, isTrue);
      });

      test('should create collaborative recipe', () {
        // Arrange & Act
        final recipe = RecipeFactory.buildCollaborative(
          id: 'collab_123',
          title: 'Team Recipe',
          permissions: {
            'user1': ResourcePermission.editor,
            'user2': ResourcePermission.viewer,
          },
        );

        // Assert
        expect(recipe.type, equals(RecipeType.collaborative));
        expect(recipe.socialData, isNotNull);
        expect(recipe.socialData!.memberPermissions, isNotNull);
        expect(
          recipe.socialData!.memberPermissions!['user1'],
          equals(ResourcePermission.editor),
        );
      });

      test('should create realtime recipe', () {
        // Arrange & Act
        final recipe = RecipeFactory.buildRealtime(
          id: 'realtime_123',
          title: 'Live Recipe',
          activeUsers: ['user1', 'user2'],
        );

        // Assert
        expect(recipe.type, equals(RecipeType.realtime));
        expect(recipe.realtimeData, isNotNull);
        expect(recipe.realtimeData!.activeEditorIds, hasLength(2));
        expect(recipe.realtimeData!.isActive, isTrue);
      });
    });

    group('Recipe Type-Specific Behavior', () {
      test('should identify recipe type correctly', () {
        // Arrange
        final personal = RecipeFactory.buildPersonal();
        final shared = RecipeFactory.buildShared();
        final collaborative = RecipeFactory.buildCollaborative();
        final realtime = RecipeFactory.buildRealtime();

        // Assert
        expect(personal.type, equals(RecipeType.personal));
        expect(shared.type, equals(RecipeType.shared));
        expect(collaborative.type, equals(RecipeType.collaborative));
        expect(realtime.type, equals(RecipeType.realtime));
      });

      test('should have appropriate metadata for each type', () {
        // Personal - no social data
        final personal = RecipeFactory.buildPersonal();
        expect(personal.socialData, isNull);
        expect(personal.realtimeData, isNull);

        // Shared - has social data
        final shared = RecipeFactory.buildShared();
        expect(shared.socialData, isNotNull);
        expect(shared.realtimeData, isNull);

        // Collaborative - has social data with permissions
        final collaborative = RecipeFactory.buildCollaborative();
        expect(collaborative.socialData, isNotNull);
        expect(collaborative.socialData!.memberPermissions, isNotNull);

        // Realtime - has realtime data
        final realtime = RecipeFactory.buildRealtime();
        expect(realtime.realtimeData, isNotNull);
        expect(realtime.realtimeData!.isActive, isTrue);
      });
    });

    group('BUG-3: Recipe.copyWith tagResult parameter', () {
      test('should update tagResult via Recipe.copyWith', () {
        // Arrange: Recipe without tagResult
        final original = Recipe(
          core: RecipeCore(
            title: 'Test Recipe',
            description: 'Test',
            ingredients: ['Pasta', 'Tomat'],
            instructions: ['Koka'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );
        expect(original.core.tagResult, isNull);

        // Act: Set tagResult via copyWith
        final tagResult = TagResult(
          tags: {'vegetarisk', 'pasta-dish', 'mild'},
          allergenStatus: {'gluten': TriState.contains, 'mjölk': TriState.free},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 0.95,
          unknownIngredients: [],
          generatedAt: DateTime(2025, 6, 1),
          generatorVersion: '1.0.0',
        );

        final updated = original.copyWith(tagResult: tagResult);

        // Assert
        expect(
          updated.core.tagResult,
          isNotNull,
          reason: 'tagResult should be set via Recipe.copyWith',
        );
        expect(updated.core.tagResult!.tags, contains('vegetarisk'));
        expect(updated.core.tagResult!.tags, contains('pasta-dish'));
        expect(updated.core.tagResult!.coverage, 0.95);
        expect(
          updated.core.tagResult!.allergenStatus['gluten'],
          TriState.contains,
        );
      });

      test('should replace existing tagResult via Recipe.copyWith', () {
        // Arrange: Recipe with existing tagResult
        final oldTagResult = TagResult(
          tags: {'gammal-tag'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          unknownIngredients: ['unknown1'],
          generatedAt: DateTime(2025, 1, 1),
          generatorVersion: '0.9.0',
        );

        final original = Recipe(
          core: RecipeCore(
            title: 'Test',
            description: 'Test',
            ingredients: ['A'],
            instructions: ['B'],
            mealType: 'Middag',
            tagResult: oldTagResult,
          ),
          type: RecipeType.personal,
        );

        // Act: Replace with new tagResult
        final newTagResult = TagResult(
          tags: {'ny-tag', 'vegetarisk'},
          allergenStatus: {'gluten': TriState.free},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime(2025, 6, 15),
          generatorVersion: '1.0.0',
        );

        final updated = original.copyWith(tagResult: newTagResult);

        // Assert
        expect(updated.core.tagResult, isNotNull);
        expect(updated.core.tagResult!.tags, contains('ny-tag'));
        expect(updated.core.tagResult!.tags, contains('vegetarisk'));
        expect(
          updated.core.tagResult!.tags,
          isNot(contains('gammal-tag')),
          reason: 'Old tagResult should be fully replaced',
        );
        expect(updated.core.tagResult!.coverage, 1.0);
      });

      test('should preserve tagResult when not specified in copyWith', () {
        // Arrange
        final tagResult = TagResult(
          tags: {'bevarad-tag'},
          allergenStatus: {'mjölk': TriState.contains},
          dietaryStatus: {},
          coverage: 0.8,
          unknownIngredients: [],
          generatedAt: DateTime(2025, 6, 1),
          generatorVersion: '1.0.0',
        );

        final original = Recipe(
          core: RecipeCore(
            title: 'Original',
            description: 'Test',
            ingredients: ['A'],
            instructions: ['B'],
            mealType: 'Middag',
            tagResult: tagResult,
          ),
          type: RecipeType.personal,
        );

        // Act: copyWith without tagResult
        final updated = original.copyWith(title: 'Updated Title');

        // Assert: tagResult should be preserved
        expect(updated.core.tagResult, isNotNull);
        expect(updated.core.tagResult!.tags, contains('bevarad-tag'));
        expect(updated.core.tagResult!.coverage, 0.8);
      });

      test('should update both tagResult and tagOverrides via copyWith', () {
        // Arrange
        final original = Recipe(
          core: RecipeCore(
            title: 'Test',
            description: 'Test',
            ingredients: ['A'],
            instructions: ['B'],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        );

        final tagResult = TagResult(
          tags: {'ny-tag'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
          generatorVersion: '1.0.0',
        );

        final tagOverrides = TagOverrides(
          allergenOverrides: {'gluten': TriState.free},
          addedTags: {'manuell-tag'},
        );

        // Act
        final updated = original.copyWith(
          tagResult: tagResult,
          tagOverrides: tagOverrides,
        );

        // Assert
        expect(updated.core.tagResult, isNotNull);
        expect(updated.core.tagResult!.tags, contains('ny-tag'));
        expect(updated.core.tagOverrides, isNotNull);
        expect(updated.core.tagOverrides!.addedTags, contains('manuell-tag'));
      });
    });

    group('RecipeSocialData', () {
      test('should serialize social data to JSON', () {
        // Arrange
        final socialData = RecipeSocialData(
          ownerId: 'owner_123',
          ownerDisplayName: 'Test Owner',
          memberPermissions: {
            'user1': ResourcePermission.editor,
            'user2': ResourcePermission.viewer,
          },
          allowGuestViewing: true,
          allowMemberInvites: false,
          categoryIds: ['cat1', 'cat2'],
          descriptionCollaborative: 'Team recipe',
        );

        // Act
        final json = socialData.toJson();

        // Assert
        expect(json['ownerId'], equals('owner_123'));
        expect(json['ownerDisplayName'], equals('Test Owner'));
        expect(json['memberPermissions'], isA<Map>());
        expect(json['allowGuestViewing'], isTrue);
        expect(json['allowMemberInvites'], isFalse);
        expect(json['categoryIds'], equals(['cat1', 'cat2']));
        expect(json['descriptionCollaborative'], equals('Team recipe'));
      });

      test('should deserialize social data from JSON', () {
        // Arrange
        final json = {
          'ownerId': 'owner_123',
          'ownerDisplayName': 'Test Owner',
          'memberPermissions': {
            'user1': ResourcePermission.editor.index,
            'user2': ResourcePermission.viewer.index,
          },
          'allowGuestViewing': true,
          'allowMemberInvites': false,
          'categoryIds': ['cat1', 'cat2'],
          'descriptionCollaborative': 'Team recipe',
        };

        // Act
        final socialData = RecipeSocialData.fromJson(json);

        // Assert
        expect(socialData.ownerId, equals('owner_123'));
        expect(socialData.ownerDisplayName, equals('Test Owner'));
        expect(
          socialData.memberPermissions!['user1'],
          equals(ResourcePermission.editor),
        );
        expect(
          socialData.memberPermissions!['user2'],
          equals(ResourcePermission.viewer),
        );
        expect(socialData.allowGuestViewing, isTrue);
        expect(socialData.allowMemberInvites, isFalse);
      });

      test('should copyWith social data correctly', () {
        // Arrange
        final original = RecipeSocialData(
          ownerId: 'owner_123',
          ownerDisplayName: 'Original Owner',
          allowGuestViewing: false,
        );

        // Act
        final updated = original.copyWith(
          ownerDisplayName: 'Updated Owner',
          allowGuestViewing: true,
        );

        // Assert
        expect(updated.ownerId, equals(original.ownerId));
        expect(updated.ownerDisplayName, equals('Updated Owner'));
        expect(updated.allowGuestViewing, isTrue);
      });
    });

    group('RecipeRealtimeData', () {
      test('should serialize realtime data to JSON', () {
        // Arrange
        final now = DateTime.now();
        final realtimeData = RecipeRealtimeData(
          activeEditorIds: ['user1', 'user2'],
          lastSeenAt: {
            'user1': now,
            'user2': now.subtract(const Duration(minutes: 5)),
          },
          lastEditedByUserId: 'user1',
          lastEditedByDisplayName: 'User One',
          lastEditedAt: now,
          editCount: 42,
          isActive: true,
        );

        // Act
        final json = realtimeData.toJson();

        // Assert
        expect(json['activeEditorIds'], equals(['user1', 'user2']));
        expect(json['lastSeenAt'], isA<Map>());
        expect(json['lastEditedByUserId'], equals('user1'));
        expect(json['lastEditedByDisplayName'], equals('User One'));
        expect(json['editCount'], equals(42));
        expect(json['isActive'], isTrue);
      });

      test('should deserialize realtime data from JSON', () {
        // Arrange
        final now = DateTime.now();
        final json = {
          'activeEditorIds': ['user1', 'user2'],
          'lastSeenAt': {
            'user1': now.toIso8601String(),
            'user2': now.subtract(const Duration(minutes: 5)).toIso8601String(),
          },
          'lastEditedByUserId': 'user1',
          'lastEditedByDisplayName': 'User One',
          'lastEditedAt': now.toIso8601String(),
          'editCount': 42,
          'isActive': true,
        };

        // Act
        final realtimeData = RecipeRealtimeData.fromJson(json);

        // Assert
        expect(realtimeData.activeEditorIds, equals(['user1', 'user2']));
        expect(realtimeData.lastSeenAt, isA<Map>());
        expect(realtimeData.lastEditedByUserId, equals('user1'));
        expect(realtimeData.editCount, equals(42));
        expect(realtimeData.isActive, isTrue);
      });
    });

    group('RecipeOfflineData', () {
      test('should serialize offline data to JSON', () {
        // Arrange
        final offlineData = RecipeOfflineData(
          lastSyncedAt: DateTime(2024, 1, 1),
          isModifiedOffline: true,
          pendingChanges: ['change1', 'change2'],
        );

        // Act
        final json = offlineData.toJson();

        // Assert
        expect(json['lastSyncedAt'], isA<String>());
        expect(json['isModifiedOffline'], isTrue);
        expect(json['pendingChanges'], equals(['change1', 'change2']));
      });

      test('should deserialize offline data from JSON', () {
        // Arrange
        final json = {
          'lastSyncedAt': '2024-01-01T00:00:00.000',
          'isModifiedOffline': true,
          'pendingChanges': ['change1', 'change2'],
        };

        // Act
        final offlineData = RecipeOfflineData.fromJson(json);

        // Assert
        expect(offlineData.lastSyncedAt, equals(DateTime(2024, 1, 1)));
        expect(offlineData.isModifiedOffline, isTrue);
        expect(offlineData.pendingChanges, equals(['change1', 'change2']));
      });

      test('should calculate needsSync correctly', () {
        // Never synced
        final neverSynced = RecipeOfflineData();
        expect(neverSynced.needsSync, isTrue);

        // Modified offline
        final modified = RecipeOfflineData(
          lastSyncedAt: DateTime.now(),
          isModifiedOffline: true,
        );
        expect(modified.needsSync, isTrue);

        // Synced and not modified
        final synced = RecipeOfflineData(
          lastSyncedAt: DateTime.now(),
          isModifiedOffline: false,
        );
        expect(synced.needsSync, isFalse);
      });
    });

    group('Edge Cases and Validation', () {
      test('should handle empty collections', () {
        // Arrange
        final recipe = RecipeCore(
          title: 'Empty Recipe',
          description: 'No ingredients or instructions',
          ingredients: [],
          instructions: [],
          mealType: 'Lunch',
        );

        // Assert
        expect(recipe.ingredients, isEmpty);
        expect(recipe.instructions, isEmpty);

        // Should still serialize/deserialize
        final json = recipe.toJson();
        final deserialized = RecipeCore.fromJson(json);
        expect(deserialized.ingredients, isEmpty);
        expect(deserialized.instructions, isEmpty);
      });

      test('should handle Swedish characters', () {
        // Arrange
        final recipe = RecipeCore(
          title: 'Räksmörgås',
          description: 'Öppna smörgåsar med räkor',
          ingredients: ['200g räkor', '1 dl majonnäs'],
          instructions: ['Lägg räkor på bröd', 'Garnera med dill'],
          mealType: 'Lunch',
        );

        // Act
        final json = recipe.toJson();
        final deserialized = RecipeCore.fromJson(json);

        // Assert
        expect(deserialized.title, equals('Räksmörgås'));
        expect(deserialized.description, contains('Öppna'));
        expect(deserialized.ingredients[0], contains('räkor'));
        expect(deserialized.instructions[0], contains('Lägg'));
      });

      test('should handle very long strings', () {
        // Arrange
        final longTitle = 'A' * 500;
        final longDescription = 'B' * 2000;

        final recipe = RecipeCore(
          title: longTitle,
          description: longDescription,
          ingredients: List.generate(100, (i) => 'Ingredient $i'),
          instructions: List.generate(50, (i) => 'Step $i' * 100),
          mealType: 'Lunch',
        );

        // Act
        final json = recipe.toJson();
        final deserialized = RecipeCore.fromJson(json);

        // Assert
        expect(deserialized.title, equals(longTitle));
        expect(deserialized.description, equals(longDescription));
        expect(deserialized.ingredients, hasLength(100));
        expect(deserialized.instructions, hasLength(50));
      });

      test('should handle null optional fields', () {
        // Arrange
        final recipe = RecipeCore(
          title: 'Minimal',
          description: 'Minimal recipe',
          ingredients: ['One'],
          instructions: ['Do'],
          mealType: 'Lunch',
          portions: null,
          timeMinutes: null,
          rating: null,
          personalTagIds: null,
          sourceUrl: null,
          createdBy: null,
          lastCookedAt: null,
        );

        // Act
        final json = recipe.toJson();
        final deserialized = RecipeCore.fromJson(json);

        // Assert
        expect(deserialized.portions, isNull);
        expect(deserialized.timeMinutes, isNull);
        expect(deserialized.rating, isNull);
        expect(deserialized.personalTagIds, isNull);
        expect(deserialized.sourceUrl, isNull);
        expect(deserialized.createdBy, isNull);
        expect(deserialized.lastCookedAt, isNull);
      });

      test('should validate meal types', () {
        // Arrange
        final validMealTypes = [
          'Frukost',
          'Lunch',
          'Middag',
          'Mellanmål',
          'Fika',
          'Dessert',
        ];

        // Assert each valid meal type
        for (final mealType in validMealTypes) {
          final recipe = RecipeCore(
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: mealType,
          );

          expect(recipe.mealType, equals(mealType));
          expect(ValidationHelper.isValidMealType(mealType), isTrue);
        }
      });

      test('should handle invalid JSON gracefully', () {
        // Missing required field — fromJson uses safeString defaults
        final invalidJson = {
          'id': 'test',
          // Missing title
          'description': 'Test',
          'ingredients': [],
          'instructions': [],
          'mealType': 'Lunch',
        };

        // safeString returns '' for missing fields — resilient deserialization
        final recipe = RecipeCore.fromJson(invalidJson);
        expect(recipe.title, equals(''));
        expect(recipe.description, equals('Test'));
      });
    });
  });
}
