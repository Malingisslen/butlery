/// Unit tests for RealtimeRecipeUtils - Shared utilities for realtime recipe operations
///
/// Tests comprehensive realtime recipe utilities including:
/// - Recipe to RealtimeRecipe conversion
/// - RealtimeRecipe to Recipe conversion
/// - Change application and merging
/// - Collaboration statistics
/// - Permission validation
/// - Edit history generation
/// - User activity tracking
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

// Test infrastructure
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('RealtimeRecipeUtils', () {
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
    
    group('Recipe Conversion', () {
      test('should convert Recipe to RealtimeRecipe data structure', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Swedish Meatballs',
            description: 'Traditional Swedish recipe',
            ingredients: ['500g ground beef', '1 onion', '2 dl cream'],
            instructions: ['Mix ingredients', 'Form balls', 'Fry until golden'],
            mealType: 'huvudrätt',
            createdBy: 'user-456',
          ),
          type: RecipeType.realtime,
          socialData: RecipeSocialData(
            ownerId: 'owner-789',
            ownerDisplayName: 'Test Owner',
          ),
          realtimeData: RecipeRealtimeData(
            lastEditedByUserId: 'editor-111',
            lastEditedByDisplayName: 'Test Editor',
          ),
        );
        
        // Act
        final result = RealtimeRecipeUtils.convertToRealtimeRecipe(recipe);
        
        // Assert
        expect(result['id'], equals('recipe-123'));
        expect(result['name'], equals('Swedish Meatballs'));
        expect(result['description'], equals('Traditional Swedish recipe'));
        expect(result['ingredients'], equals(['500g ground beef', '1 onion', '2 dl cream']));
        expect(result['instructions'], equals(['Mix ingredients', 'Form balls', 'Fry until golden']));
        expect(result['ownerId'], equals('owner-789'));
        expect(result['ownerDisplayName'], equals('Test Owner'));
        expect(result['lastEditedByUserId'], equals('editor-111'));
        expect(result['lastEditedByDisplayName'], equals('Test Editor'));
        expect(result['editCount'], equals(1));
        expect(result['lastEditedAt'], isNotNull);
      });
      
      test('should handle Recipe without social and realtime data', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Simple Recipe',
            description: 'Basic recipe',
            ingredients: ['ingredient 1'],
            instructions: ['step 1'],
            mealType: 'huvudrätt',
            createdBy: 'user-123',
          ),
          type: RecipeType.personal,
        );
        
        // Act
        final result = RealtimeRecipeUtils.convertToRealtimeRecipe(recipe);
        
        // Assert
        expect(result['ownerId'], equals('user-123'));
        expect(result['ownerDisplayName'], equals('Unknown'));
        expect(result['lastEditedByUserId'], equals('user-123'));
        expect(result['lastEditedByDisplayName'], equals('Unknown'));
      });
      
      test('should convert RealtimeRecipe object to Recipe', () {
        // Arrange
        final baseRecipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test Recipe',
            description: 'Test description',
            ingredients: ['ingredient 1'],
            instructions: ['instruction 1'],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.realtime,
        );
        
        final realtimeRecipe = RealtimeRecipe.fromRecipe(
          recipe: baseRecipe,
          ownerId: 'owner-123',
          ownerDisplayName: 'Test Owner',
        );
        
        // Act
        final result = RealtimeRecipeUtils.convertToRecipe(realtimeRecipe);
        
        // Assert
        expect(result.id, equals('recipe-123'));
        expect(result.title, equals('Test Recipe'));
        expect(result.type, equals(RecipeType.realtime));
      });
      
      test('should convert Map data to Recipe', () {
        // Arrange
        final realtimeData = {
          'id': 'recipe-456',
          'name': 'Kladdkaka',
          'description': 'Swedish chocolate cake',
          'ingredients': ['100g butter', '2 eggs', '3 dl sugar'],
          'instructions': ['Melt butter', 'Mix all', 'Bake 15 min'],
          'imageUrls': ['image1.jpg', 'image2.jpg'],
          'mealType': 'efterrätt',
        };
        
        // Act
        final result = RealtimeRecipeUtils.convertToRecipe(realtimeData);
        
        // Assert
        expect(result.id, equals('recipe-456'));
        expect(result.title, equals('Kladdkaka'));
        expect(result.description, equals('Swedish chocolate cake'));
        expect(result.ingredients.length, equals(3));
        expect(result.instructions.length, equals(3));
        expect(result.imageUrls.length, equals(2));
        expect(result.type, equals(RecipeType.realtime));
      });
      
      test('should handle Map with missing fields', () {
        // Arrange
        final minimalData = {
          'id': 'recipe-789',
        };
        
        // Act
        final result = RealtimeRecipeUtils.convertToRecipe(minimalData);
        
        // Assert
        expect(result.id, equals('recipe-789'));
        expect(result.title, isEmpty);
        expect(result.description, isEmpty);
        expect(result.ingredients, isEmpty);
        expect(result.instructions, isEmpty);
        expect(result.core.mealType, equals('Lunch')); // Default value
      });
      
      test('should throw error for invalid realtimeRecipe type', () {
        // Act & Assert
        expect(
          () => RealtimeRecipeUtils.convertToRecipe('invalid'),
          throwsA(isA<ArgumentError>()),
        );
        
        expect(
          () => RealtimeRecipeUtils.convertToRecipe(123),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
    
    group('Change Application', () {
      test('should apply changes to realtime recipe data', () {
        // Arrange
        final recipe = {
          'id': 'recipe-123',
          'name': 'Old Name',
          'description': 'Old description',
          'ingredients': ['old ingredient'],
          'instructions': ['old instruction'],
          'imageUrls': ['old.jpg'],
          'editCount': 5,
        };
        
        final changes = {
          'title': 'New Name',
          'description': 'New description',
          'ingredients': ['new ingredient 1', 'new ingredient 2'],
        };
        
        // Act
        final result = RealtimeRecipeUtils.applyChangesToRealtimeRecipe(
          recipe,
          changes,
          'Updated recipe content',
          'user-123',
          'Test User',
        );
        
        // Assert
        expect(result['name'], equals('New Name'));
        expect(result['description'], equals('New description'));
        expect(result['ingredients'], equals(['new ingredient 1', 'new ingredient 2']));
        expect(result['instructions'], equals(['old instruction'])); // Unchanged
        expect(result['imageUrls'], equals(['old.jpg'])); // Unchanged
        expect(result['editCount'], equals(6));
        expect(result['lastEditedByUserId'], equals('user-123'));
        expect(result['lastEditedByDisplayName'], equals('Test User'));
        expect(result['editDescription'], equals('Updated recipe content'));
        expect(result['lastEditedAt'], isNotNull);
      });
      
      test('should handle partial changes', () {
        // Arrange
        final recipe = {
          'id': 'recipe-123',
          'name': 'Recipe Name',
          'description': 'Recipe description',
          'ingredients': ['ingredient 1'],
          'instructions': ['instruction 1'],
          'editCount': 2,
        };
        
        final changes = {
          'instructions': ['new instruction 1', 'new instruction 2'],
        };
        
        // Act
        final result = RealtimeRecipeUtils.applyChangesToRealtimeRecipe(
          recipe,
          changes,
          null,
          null,
          null,
        );
        
        // Assert
        expect(result['name'], equals('Recipe Name')); // Unchanged
        expect(result['description'], equals('Recipe description')); // Unchanged
        expect(result['ingredients'], equals(['ingredient 1'])); // Unchanged
        expect(result['instructions'], equals(['new instruction 1', 'new instruction 2']));
        expect(result['editCount'], equals(3));
      });
    });
    
    group('Recipe Merging', () {
      test('should merge two recipe versions', () {
        // Arrange
        final local = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Local Title',
            description: 'Local description',
            ingredients: ['local ingredient'],
            instructions: ['local instruction'],
            imageUrls: ['local1.jpg', 'local2.jpg'],
            mealType: 'huvudrätt',
            rating: 4.5,
            tags: ['local', 'test'],
          ),
          type: RecipeType.realtime,
        );
        
        final remote = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Remote Title',
            description: 'Remote description',
            ingredients: ['remote ingredient 1', 'remote ingredient 2'],
            instructions: ['remote instruction'],
            imageUrls: ['remote1.jpg', 'remote2.jpg'],
            mealType: 'huvudrätt',
            rating: 4.0,
            tags: ['remote', 'production'],
          ),
          type: RecipeType.realtime,
        );
        
        // Act
        final result = RealtimeRecipeUtils.mergeRecipeVersions(
          local,
          remote,
          'user-123',
          'Test User',
        );
        
        // Assert
        expect(result.title, equals('Remote Title')); // Remote wins
        expect(result.description, equals('Remote description')); // Remote wins
        expect(result.ingredients, equals(['remote ingredient 1', 'remote ingredient 2'])); // Remote wins
        expect(result.instructions, equals(['remote instruction'])); // Remote wins
        
        // Images are merged
        expect(result.imageUrls.toSet(), equals({'local1.jpg', 'local2.jpg', 'remote1.jpg', 'remote2.jpg'}));
        
        // Local rating preferred when available
        expect(result.rating, equals(4.5));
        
        // Tags are merged
        expect(result.tags!.toSet(), equals({'local', 'test', 'remote', 'production'}));
      });
      
      test('should handle null values in merge', () {
        // Arrange
        final local = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Local Title',
            description: 'Local description',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
            rating: null,
            tags: null,
          ),
          type: RecipeType.realtime,
        );
        
        final remote = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Remote Title',
            description: 'Remote description',
            ingredients: ['remote ingredient'],
            instructions: ['remote instruction'],
            mealType: 'huvudrätt',
            rating: 4.8,
            tags: ['remote'],
          ),
          type: RecipeType.realtime,
        );
        
        // Act
        final result = RealtimeRecipeUtils.mergeRecipeVersions(
          local,
          remote,
          null,
          null,
        );
        
        // Assert
        expect(result.rating, equals(4.8)); // Remote rating used when local is null
        expect(result.tags, equals(['remote'])); // Remote tags used when local is null
      });
    });
    
    group('Collaboration Statistics', () {
      test('should get collaboration stats for collaborative recipe', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Collaborative Recipe',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
            updatedAt: DateTime.now().subtract(const Duration(days: 3)),
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            memberPermissions: {
              'user1': ResourcePermission.editor,
              'user2': ResourcePermission.viewer,
              'user3': ResourcePermission.editor,
            },
          ),
          realtimeData: RecipeRealtimeData(
            lastEditedAt: DateTime.now().subtract(const Duration(days: 2)),
            lastEditedByUserId: 'user1',
            editCount: 15,
          ),
        );
        
        // Act
        final stats = RealtimeRecipeUtils.getCollaborationStats(recipe);
        
        // Assert
        expect(stats['memberCount'], equals(3));
        expect(stats['daysSinceLastEdit'], equals(2));
        expect(stats['editCount'], equals(15));
        expect(stats['collaborationLevel'], equals('medium'));
        expect(stats.containsKey('activeEditorsCount'), isTrue);
        expect(stats.containsKey('isActivelyCollaborated'), isTrue);
      });
      
      test('should return empty stats for non-collaborative recipe', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Personal Recipe',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.personal,
        );
        
        // Act
        final stats = RealtimeRecipeUtils.getCollaborationStats(recipe);
        
        // Assert
        expect(stats, isEmpty);
      });
      
      test('should calculate collaboration level correctly', () {
        // Arrange
        final recipeLow = Recipe(
          core: RecipeCore(
            id: 'recipe-1',
            title: 'Low Collab',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            memberPermissions: {
              'user1': ResourcePermission.editor,
              'user2': ResourcePermission.viewer,
            },
          ),
        );
        
        final recipeMedium = Recipe(
          core: RecipeCore(
            id: 'recipe-2',
            title: 'Medium Collab',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            memberPermissions: {
              'user1': ResourcePermission.editor,
              'user2': ResourcePermission.editor,
              'user3': ResourcePermission.viewer,
              'user4': ResourcePermission.editor,
            },
          ),
        );
        
        final recipeHigh = Recipe(
          core: RecipeCore(
            id: 'recipe-3',
            title: 'High Collab',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            memberPermissions: {
              'user1': ResourcePermission.editor,
              'user2': ResourcePermission.editor,
              'user3': ResourcePermission.viewer,
              'user4': ResourcePermission.editor,
              'user5': ResourcePermission.editor,
              'user6': ResourcePermission.viewer,
            },
          ),
        );
        
        // Act
        final statsLow = RealtimeRecipeUtils.getCollaborationStats(recipeLow);
        final statsMedium = RealtimeRecipeUtils.getCollaborationStats(recipeMedium);
        final statsHigh = RealtimeRecipeUtils.getCollaborationStats(recipeHigh);
        
        // Assert
        expect(statsLow['collaborationLevel'], equals('low'));
        expect(statsMedium['collaborationLevel'], equals('medium'));
        expect(statsHigh['collaborationLevel'], equals('high'));
      });
    });
    
    group('Change Description', () {
      test('should get change description in Swedish', () {
        // Arrange
        final changes1 = {'title': 'New Title'};
        final changes2 = {'description': 'New desc', 'ingredients': ['new']};
        final changes3 = {
          'title': 'Title',
          'description': 'Desc',
          'ingredients': ['ing'],
          'instructions': ['inst'],
          'imageUrls': ['img'],
        };
        final changes4 = <String, dynamic>{};
        
        // Act
        final desc1 = RealtimeRecipeUtils.getChangeDescription(changes1);
        final desc2 = RealtimeRecipeUtils.getChangeDescription(changes2);
        final desc3 = RealtimeRecipeUtils.getChangeDescription(changes3);
        final desc4 = RealtimeRecipeUtils.getChangeDescription(changes4);
        
        // Assert
        expect(desc1, equals('titel'));
        expect(desc2, equals('beskrivning, ingredienser'));
        expect(desc3, equals('titel, beskrivning, ingredienser, instruktioner, bilder'));
        expect(desc4, equals('receptet')); // Default when no fields changed
      });
    });
    
    group('Validation', () {
      test('should validate recipe for realtime operations', () {
        // Arrange
        final validRecipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.collaborative,
        );
        
        final invalidRecipe = Recipe(
          core: RecipeCore(
            id: 'recipe-456',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.personal,
        );
        
        // Act
        final validResult = RealtimeRecipeUtils.validateRecipeForRealtime(validRecipe);
        final invalidResult = RealtimeRecipeUtils.validateRecipeForRealtime(invalidRecipe);
        final nullResult = RealtimeRecipeUtils.validateRecipeForRealtime(null);
        
        // Assert
        expect(validResult, isNull); // null means valid
        expect(invalidResult, equals('Recipe is not collaborative'));
        expect(nullResult, equals('Recipe not found'));
      });
      
      test('should validate user permissions', () {
        // Arrange & Act
        final result1 = RealtimeRecipeUtils.validateUserPermissions(
          'user-123',
          'recipe-456',
          requireEdit: true,
          requireOwner: false,
        );
        
        final result2 = RealtimeRecipeUtils.validateUserPermissions(
          null,
          'recipe-456',
          requireEdit: false,
          requireOwner: false,
        );
        
        // Assert
        expect(result1, isNull); // Stub implementation returns null (valid)
        expect(result2, equals('User must be logged in'));
      });
    });
    
    group('Edit History', () {
      test('should create edit history entry', () {
        // Arrange
        final timestamp = DateTime(2024, 1, 15, 10, 30);
        
        // Act
        final entry = RealtimeRecipeUtils.createEditHistoryEntry(
          timestamp: timestamp,
          userId: 'user-123',
          userName: 'Test User',
          action: 'Updated recipe',
          details: 'Changed ingredients',
          targetUserId: 'target-456',
        );
        
        // Assert
        expect(entry['timestamp'], equals(timestamp));
        expect(entry['userId'], equals('user-123'));
        expect(entry['userName'], equals('Test User'));
        expect(entry['action'], equals('Updated recipe'));
        expect(entry['details'], equals('Changed ingredients'));
        expect(entry['targetUserId'], equals('target-456'));
      });
      
      test('should generate edit history for recipe', () {
        // Arrange
        final createdAt = DateTime(2024, 1, 10);
        final updatedAt = DateTime(2024, 1, 12);
        
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test Recipe',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
            createdAt: createdAt,
            updatedAt: updatedAt,
            createdBy: 'creator-123',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'owner-123',
            ownerDisplayName: 'Recipe Owner',
            memberPermissions: {
              'member1': ResourcePermission.editor,
              'member2': ResourcePermission.viewer,
            },
          ),
          realtimeData: RecipeRealtimeData(
            lastEditedByUserId: 'editor-456',
            lastEditedByDisplayName: 'Last Editor',
          ),
        );
        
        // Act
        final history = RealtimeRecipeUtils.generateEditHistory(recipe);
        
        // Assert
        expect(history.length, greaterThanOrEqualTo(3)); // Creation + update + collaborators
        
        // Check creation event
        final creationEvent = history.firstWhere((e) => e['action'] == 'Created recipe');
        expect(creationEvent['timestamp'], equals(createdAt));
        expect(creationEvent['userId'], equals('creator-123'));
        
        // Check update event
        final updateEvent = history.firstWhere((e) => e['action'] == 'Updated recipe');
        expect(updateEvent['timestamp'], equals(updatedAt));
        expect(updateEvent['userId'], equals('editor-456'));
        expect(updateEvent['userName'], equals('Last Editor'));
        
        // Check collaborator events
        final collabEvents = history.where((e) => e['action'] == 'Added collaborator');
        expect(collabEvents.length, equals(2)); // Two members added
      });
      
      test('should handle recipe without updates', () {
        // Arrange
        final createdAt = DateTime(2024, 1, 10);
        
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test Recipe',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
            createdAt: createdAt,
            updatedAt: createdAt, // Same as created
            createdBy: 'creator-123',
          ),
          type: RecipeType.personal,
        );
        
        // Act
        final history = RealtimeRecipeUtils.generateEditHistory(recipe);
        
        // Assert
        expect(history.length, equals(1)); // Only creation event
        expect(history.first['action'], equals('Created recipe'));
      });
    });
    
    group('Active Editors', () {
      test('should get active editors from recipe', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            memberPermissions: {
              'user1': ResourcePermission.editor,
              'user2': ResourcePermission.viewer,
              'user3': ResourcePermission.editor,
            },
          ),
          realtimeData: RecipeRealtimeData(
            lastEditedAt: DateTime.now().subtract(const Duration(minutes: 2)),
            lastEditedByUserId: 'user1',
          ),
        );
        
        // Act
        final activeEditors = RealtimeRecipeUtils.getActiveEditorsFromRecipe(recipe);
        
        // Assert
        expect(activeEditors, contains('user1')); // Recently edited
        // May contain others based on random simulation
      });
      
      test('should return empty list for non-collaborative recipe', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.personal,
        );
        
        // Act
        final activeEditors = RealtimeRecipeUtils.getActiveEditorsFromRecipe(recipe);
        
        // Assert
        expect(activeEditors, isEmpty);
      });
      
      test('should exclude editors inactive for more than 5 minutes', () {
        // Arrange
        final recipe = Recipe(
          core: RecipeCore(
            id: 'recipe-123',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'huvudrätt',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            memberPermissions: <String, ResourcePermission>{}, // Empty to avoid random simulation
          ),
          realtimeData: RecipeRealtimeData(
            lastEditedAt: DateTime.now().subtract(const Duration(minutes: 10)),
            lastEditedByUserId: 'user1',
          ),
        );
        
        // Act
        final activeEditors = RealtimeRecipeUtils.getActiveEditorsFromRecipe(recipe);
        
        // Assert
        // user1 should not be included as they edited 10 minutes ago and no members to randomly simulate
        expect(activeEditors, isEmpty);
      });
    });
    
    group('User Activity', () {
      test('should simulate user activity viewing', () async {
        // Act - Run multiple times with small delays to test randomness
        int activeCount = 0;
        for (int i = 0; i < 30; i++) {
          if (RealtimeRecipeUtils.isUserActivelyViewing('user-123', 'recipe-456')) {
            activeCount++;
          }
          // Small delay to ensure different millisecond values
          await Future.delayed(const Duration(milliseconds: 1));
        }
        
        // Assert - Should get some active and some inactive
        expect(activeCount, greaterThan(0)); // At least some activity
        expect(activeCount, lessThan(30)); // But not always active
      });
    });
  });
}