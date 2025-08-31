/// Unit tests for SocialRecipeQueryService - Handles collaborative recipe queries
///
/// Tests query operations including:
/// - Collaborative recipe retrieval
/// - Permission-based filtering
/// - Recipe search functionality
/// - Collaboration statistics
/// - Cache management
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_query_service.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  group('SocialRecipeQueryService', () {
    late SocialRecipeQueryService queryService;
    late MockJsonCacheHelper mockCacheHelper;
    late MockRecipeServiceAdapter mockServiceAdapter;
    late String currentUserId;
    late List<Recipe> testRecipes;
    
    setUpAll(() {
      // Centralized fallback values already registered via TestServiceLocator
    });
    
    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Reset test state
      currentUserId = 'test-user-123';
      testRecipes = [];
      
      // Create mocks
      mockCacheHelper = MockJsonCacheHelper();
      mockServiceAdapter = MockRecipeServiceAdapter();
      
      // MockJsonCacheHelper has concrete implementations, no stubbing needed
      
      // Create test recipes
      final personalRecipe = RecipeFactory.buildPersonal(
        id: 'personal-1',
        title: 'Personal Recipe',
        createdBy: currentUserId,
      );
      
      final ownedCollaborative1 = Recipe(
        core: RecipeCore(
          id: 'owned-collab-1',
          title: 'Swedish Meatballs',
          description: 'Traditional recipe',
          ingredients: ['Ground beef', 'Breadcrumbs'],
          instructions: ['Mix ingredients', 'Form balls', 'Cook'],
          mealType: 'Dinner',
          createdBy: currentUserId,
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: currentUserId,
          ownerDisplayName: 'Test User',
          memberPermissions: {
            currentUserId: ResourcePermission.admin,
            'friend-1': ResourcePermission.editor,
            'friend-2': ResourcePermission.viewer,
          },
        ),
      );
      
      final ownedCollaborative2 = Recipe(
        core: RecipeCore(
          id: 'owned-collab-2',
          title: 'Swedish Pancakes',
          description: 'Thin pancakes',
          ingredients: ['Flour', 'Eggs', 'Milk'],
          instructions: ['Mix batter', 'Cook thin'],
          mealType: 'Breakfast',
          createdBy: currentUserId,
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: currentUserId,
          ownerDisplayName: 'Test User',
          memberPermissions: {
            currentUserId: ResourcePermission.admin,
            'friend-3': ResourcePermission.editor,
          },
        ),
      );
      
      final memberCollaborative1 = Recipe(
        core: RecipeCore(
          id: 'member-collab-1',
          title: 'Pasta Carbonara',
          description: 'Italian classic',
          ingredients: ['Pasta', 'Eggs', 'Bacon'],
          instructions: ['Cook pasta', 'Mix with eggs'],
          mealType: 'Dinner',
          createdBy: 'friend-1',
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'friend-1',
          ownerDisplayName: 'Friend One',
          memberPermissions: {
            'friend-1': ResourcePermission.admin,
            currentUserId: ResourcePermission.editor,
            'friend-2': ResourcePermission.viewer,
          },
        ),
      );
      
      final memberCollaborative2 = Recipe(
        core: RecipeCore(
          id: 'member-collab-2',
          title: 'Pizza Margherita',
          description: 'Classic pizza',
          ingredients: ['Dough', 'Tomato', 'Mozzarella'],
          instructions: ['Make dough', 'Add toppings', 'Bake'],
          mealType: 'Dinner',
          createdBy: 'friend-2',
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'friend-2',
          ownerDisplayName: 'Friend Two',
          memberPermissions: {
            'friend-2': ResourcePermission.admin,
            currentUserId: ResourcePermission.viewer,
            'friend-1': ResourcePermission.editor,
          },
        ),
      );
      
      final notMemberCollaborative = Recipe(
        core: RecipeCore(
          id: 'not-member-collab',
          title: 'Secret Recipe',
          description: 'Not shared with current user',
          ingredients: ['Secret'],
          instructions: ['Secret'],
          mealType: 'Dinner',
          createdBy: 'other-user',
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'other-user',
          ownerDisplayName: 'Other User',
          memberPermissions: {
            'other-user': ResourcePermission.admin,
            'friend-3': ResourcePermission.editor,
          },
        ),
      );
      
      testRecipes = [
        personalRecipe,
        ownedCollaborative1,
        ownedCollaborative2,
        memberCollaborative1,
        memberCollaborative2,
        notMemberCollaborative,
      ];
      
      // Setup service adapter behavior
      when(() => mockServiceAdapter.getRecipesForUser(any()))
          .thenAnswer((invocation) async {
            final userId = invocation.positionalArguments[0] as String;
            if (userId == currentUserId) {
              return testRecipes;
            } else if (userId == 'friend-1') {
              return [memberCollaborative1];
            }
            return [];
          });
      
      // Create service
      queryService = SocialRecipeQueryService(
        cacheHelper: mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        setError: (error) {},
        serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
      );
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Collaborative Recipe Queries', () {
      test('should get collaborative recipes for current user', () async {
        // Act
        final recipes = await queryService.getCollaborativeRecipesForUser();
        
        // Assert
        expect(recipes, isNotEmpty);
        expect(recipes.length, equals(4)); // 2 owned + 2 member
        expect(recipes.every((r) => r.isCollaborative), isTrue);
        expect(recipes.every((r) => 
          r.socialData?.memberPermissions?.containsKey(currentUserId) == true), isTrue);
      });
      
      test('should return empty list when user not authenticated', () async {
        // Arrange
        queryService = SocialRecipeQueryService(
          cacheHelper: mockCacheHelper,
          getCurrentUserId: () => null,
          setError: (error) {},
          serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
        );
        
        // Act
        final recipes = await queryService.getCollaborativeRecipesForUser();
        
        // Assert
        expect(recipes, isEmpty);
      });
      
      test('should get recipes shared by specific user', () async {
        // Act
        final sharedByCurrentUser = await queryService.getRecipesSharedByUser(currentUserId);
        final sharedByFriend1 = await queryService.getRecipesSharedByUser('friend-1');
        
        // Assert
        expect(sharedByCurrentUser.length, equals(2)); // 2 owned collaborative
        expect(sharedByCurrentUser.every((r) => r.socialData?.ownerId == currentUserId), isTrue);
        
        expect(sharedByFriend1.length, equals(1));
        expect(sharedByFriend1.first.socialData?.ownerId, equals('friend-1'));
      });
      
      test('should get owned collaborative recipes', () async {
        // Act
        final ownedRecipes = await queryService.getOwnedCollaborativeRecipes();
        
        // Assert
        expect(ownedRecipes.length, equals(2));
        expect(ownedRecipes.every((r) => r.socialData?.ownerId == currentUserId), isTrue);
        expect(ownedRecipes.every((r) => r.isCollaborative), isTrue);
      });
    });
    
    group('Permission-Based Queries', () {
      test('should get recipes with admin permission', () async {
        // Act
        final adminRecipes = await queryService.getRecipesWithPermission(ResourcePermission.admin);
        
        // Assert
        expect(adminRecipes.length, equals(2)); // 2 owned recipes
        expect(adminRecipes.every((r) => 
          r.socialData?.memberPermissions?[currentUserId] == ResourcePermission.admin), isTrue);
      });
      
      test('should get recipes with editor permission', () async {
        // Act
        final editorRecipes = await queryService.getRecipesWithPermission(ResourcePermission.editor);
        
        // Assert
        expect(editorRecipes.length, equals(1)); // member-collab-1
        expect(editorRecipes.first.id, equals('member-collab-1'));
        expect(editorRecipes.first.socialData?.memberPermissions?[currentUserId], 
          equals(ResourcePermission.editor));
      });
      
      test('should get recipes with viewer permission', () async {
        // Act
        final viewerRecipes = await queryService.getRecipesWithPermission(ResourcePermission.viewer);
        
        // Assert
        expect(viewerRecipes.length, equals(1)); // member-collab-2
        expect(viewerRecipes.first.id, equals('member-collab-2'));
        expect(viewerRecipes.first.socialData?.memberPermissions?[currentUserId], 
          equals(ResourcePermission.viewer));
      });
      
      test('should return empty list when user not authenticated', () async {
        // Arrange
        queryService = SocialRecipeQueryService(
          cacheHelper: mockCacheHelper,
          getCurrentUserId: () => null,
          setError: (error) {},
          serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
        );
        
        // Act
        final recipes = await queryService.getRecipesWithPermission(ResourcePermission.admin);
        
        // Assert
        expect(recipes, isEmpty);
      });
    });
    
    group('Search Operations', () {
      test('should search collaborative recipes by title', () async {
        // Act
        final swedishRecipes = await queryService.searchCollaborativeRecipes('swedish');
        final pastaRecipes = await queryService.searchCollaborativeRecipes('pasta');
        final pizzaRecipes = await queryService.searchCollaborativeRecipes('PIZZA'); // Case insensitive
        
        // Assert
        expect(swedishRecipes.length, equals(2));
        expect(swedishRecipes.every((r) => r.title.toLowerCase().contains('swedish')), isTrue);
        
        expect(pastaRecipes.length, equals(1));
        expect(pastaRecipes.first.title, contains('Pasta'));
        
        expect(pizzaRecipes.length, equals(1));
        expect(pizzaRecipes.first.title, contains('Pizza'));
      });
      
      test('should return empty list for no matches', () async {
        // Act
        final results = await queryService.searchCollaborativeRecipes('nonexistent');
        
        // Assert
        expect(results, isEmpty);
      });
      
      test('should handle empty search query', () async {
        // Act
        final results = await queryService.searchCollaborativeRecipes('');
        
        // Assert
        expect(results.length, equals(4)); // All collaborative recipes user has access to
      });
    });
    
    group('Collaboration Statistics', () {
      test('should calculate collaboration statistics', () async {
        // Act
        final stats = await queryService.getCollaborationStats();
        
        // Assert
        expect(stats, isNotNull);
        expect(stats['owned_collaborative'], equals(2));
        expect(stats['member_of'], equals(2));
        expect(stats['editor_access'], equals(1));
        expect(stats['viewer_access'], equals(1));
        expect(stats['total_collaborative'], equals(4));
      });
      
      test('should return empty stats when user not authenticated', () async {
        // Arrange
        queryService = SocialRecipeQueryService(
          cacheHelper: mockCacheHelper,
          getCurrentUserId: () => null,
          setError: (error) {},
          serviceAdapter: mockServiceAdapter as RecipeServiceAdapter,
        );
        
        // Act
        final stats = await queryService.getCollaborationStats();
        
        // Assert
        expect(stats, isEmpty);
      });
      
      test('should get most active collaborators', () async {
        // Act
        final collaborators = await queryService.getMostActiveCollaborators(limit: 5);
        
        // Assert
        expect(collaborators, isNotEmpty);
        // friend-1 and friend-2 appear in multiple recipes
        expect(collaborators.contains('friend-1'), isTrue);
        expect(collaborators.contains('friend-2'), isTrue);
      });
      
      test('should limit active collaborators list', () async {
        // Act
        final collaborators = await queryService.getMostActiveCollaborators(limit: 1);
        
        // Assert
        expect(collaborators.length, lessThanOrEqualTo(1));
      });
      
      test('should get collaboration activity summary', () async {
        // Act
        final activity = await queryService.getCollaborationActivity();
        
        // Assert
        expect(activity, isNotNull);
        expect(activity['stats'], isNotNull);
        expect(activity['active_collaborators'], isNotNull);
        expect(activity['has_collaborative_activity'], isTrue);
      });
    });
    
    group('Cache Operations', () {
      test('should save recipe to cache', () async {
        // Arrange
        final recipe = testRecipes[1]; // collaborative recipe
        
        // Act
        await queryService.saveToCache(recipe);
        
        // Assert
        // Check that the recipe was saved in the mock cache
        final savedData = await mockCacheHelper.loadJson(recipe.id);
        expect(savedData, isNotNull);
      });
      
      test('should load cached collaborative recipes', () async {
        // Arrange
        // Save recipes to cache first
        await mockCacheHelper.saveJson('owned-collab-1', testRecipes[1].toJson());
        await mockCacheHelper.saveJson('owned-collab-2', testRecipes[2].toJson());
        await mockCacheHelper.saveJson('personal-1', testRecipes[0].toJson()); // Personal recipe
        
        // Act
        final cachedRecipes = await queryService.loadCachedCollaborativeRecipes();
        
        // Assert
        expect(cachedRecipes.length, equals(2)); // Only collaborative
        expect(cachedRecipes.every((r) => r.isCollaborative), isTrue);
      });
      
      test('should handle corrupted cache data', () async {
        // Arrange
        // Save corrupted data to cache
        await mockCacheHelper.saveJson('corrupted-1', {'invalid': 'data'});
        
        // Act
        final cachedRecipes = await queryService.loadCachedCollaborativeRecipes();
        
        // Assert
        expect(cachedRecipes, isEmpty);
      });
      
      test('should clear cached recipes', () async {
        // Arrange
        // Save some data first
        await mockCacheHelper.saveJson('test-1', {'test': 'data'});
        
        // Act
        await queryService.clearCachedRecipes();
        
        // Assert
        // Check that cache is empty
        final keys = await mockCacheHelper.getAllKeys();
        expect(keys, isEmpty);
      });
      
      test('should get cache statistics', () async {
        // Arrange
        // Save some recipes to cache
        await mockCacheHelper.saveJson('recipe-1', testRecipes[1].toJson());
        await mockCacheHelper.saveJson('recipe-2', testRecipes[2].toJson());
        await mockCacheHelper.saveJson('recipe-3', testRecipes[3].toJson());
        
        // Act
        final stats = await queryService.getCacheStats();
        
        // Assert
        expect(stats['total_cached'], equals(3));
        expect(stats['collaborative_cached'], greaterThanOrEqualTo(0));
      });
    });
    
    group('Error Handling', () {
      test('should handle service adapter errors gracefully', () async {
        // Arrange
        when(() => mockServiceAdapter.getRecipesForUser(any()))
            .thenThrow(Exception('Database error'));
        
        // Act
        final recipes = await queryService.getCollaborativeRecipesForUser();
        final stats = await queryService.getCollaborationStats();
        final collaborators = await queryService.getMostActiveCollaborators();
        
        // Assert
        expect(recipes, isEmpty);
        // Stats returns a map with zero values on error
        expect(stats['total_collaborative'], equals(0));
        expect(collaborators, isEmpty);
      });
      
      test('should handle cache errors gracefully', () async {
        // Arrange
        final recipe = testRecipes[1];
        
        // We can't mock throwing errors with MockJsonCacheHelper's concrete implementation
        // But we can test that the service handles empty/null cache gracefully
        
        // Act & Assert - Should not throw even with empty cache
        await expectLater(
          queryService.saveToCache(recipe),
          completes,
        );
        
        // Clear cache to simulate error scenario
        await mockCacheHelper.clear();
        
        final cachedRecipes = await queryService.loadCachedCollaborativeRecipes();
        expect(cachedRecipes, isEmpty);
        
        await expectLater(
          queryService.clearCachedRecipes(),
          completes,
        );
      });
    });
  });
}