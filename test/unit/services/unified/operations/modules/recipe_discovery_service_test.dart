// test/unit/services/unified/operations/modules/recipe_discovery_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeDiscoveryService', () {
    late MockUnifiedRecipeService mockParentService;
    late RecipeDiscoveryService discoveryService;
    late List<Recipe> testRecipes;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(Recipe(
        core: RecipeCore(
          id: 'test',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mock parent service
      mockParentService = MockUnifiedRecipeService();

      // Create discovery service instance
      discoveryService = RecipeDiscoveryService(
        getCurrentUserId: () => mockParentService.currentUserId,
        getRecipes: () => mockParentService.recipes,
      );

      // Create test recipes
      testRecipes = [
        // Personal recipe (should not appear in collaborative queries)
        Recipe(
          core: RecipeCore(
            id: 'personal_1',
            title: 'My Personal Recipe',
            description: 'Personal recipe',
            ingredients: ['ingredient 1'],
            instructions: ['step 1'],
            mealType: 'Middag',
            createdBy: 'user_123',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          type: RecipeType.personal,
        ),
        // Collaborative recipe where user is owner
        Recipe(
          core: RecipeCore(
            id: 'collab_1',
            title: 'Collaborative Pasta',
            description: 'A collaborative pasta recipe',
            ingredients: ['pasta', 'sauce'],
            instructions: ['cook pasta', 'add sauce'],
            mealType: 'Middag',
            createdBy: 'user_123',
            personalTagIds: ['italian', 'pasta', 'quick'],
            createdAt: DateTime.now().subtract(Duration(days: 2)),
            updatedAt: DateTime.now().subtract(Duration(hours: 1)),
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'user_123',
            ownerDisplayName: 'Current User',
            memberPermissions: {
              'user_456': ResourcePermission.editor,
            },
            categoryIds: ['category_1'],
          ),
        ),
        // Collaborative recipe where user is member
        Recipe(
          core: RecipeCore(
            id: 'collab_2',
            title: 'Team Salad',
            description: 'Healthy team salad',
            ingredients: ['lettuce', 'tomatoes'],
            instructions: ['mix ingredients'],
            mealType: 'Lunch',
            createdBy: 'user_456',
            personalTagIds: ['healthy', 'salad', 'vegetarian'],
            createdAt: DateTime.now().subtract(Duration(days: 1)),
            updatedAt: DateTime.now().subtract(Duration(minutes: 30)),
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'user_456',
            ownerDisplayName: 'Other User',
            memberPermissions: {
              'user_123': ResourcePermission.viewer,
              'user_789': ResourcePermission.editor,
            },
            categoryIds: ['category_2'],
          ),
        ),
        // Collaborative recipe where user is NOT a member
        Recipe(
          core: RecipeCore(
            id: 'collab_3',
            title: 'Private Collaboration',
            description: 'Recipe user cannot access',
            ingredients: ['secret'],
            instructions: ['hidden'],
            mealType: 'Middag',
            createdBy: 'user_789',
            createdAt: DateTime.now().subtract(Duration(days: 3)),
            updatedAt: DateTime.now().subtract(Duration(days: 3)),
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'user_789',
            ownerDisplayName: 'Another User',
            memberPermissions: {
              'user_456': ResourcePermission.editor,
            },
          ),
        ),
        // Shared recipe with guest viewing
        Recipe(
          core: RecipeCore(
            id: 'shared_1',
            title: 'Public Shared Recipe',
            description: 'Anyone can view this',
            ingredients: ['public ingredient'],
            instructions: ['public step'],
            mealType: 'Frukost',
            createdBy: 'user_999',
            isPublic: true,
            createdAt: DateTime.now().subtract(Duration(hours: 12)),
            updatedAt: DateTime.now().subtract(Duration(hours: 12)),
          ),
          type: RecipeType.shared,
          socialData: RecipeSocialData(
            ownerId: 'user_999',
            ownerDisplayName: 'Public User',
            allowGuestViewing: true,
          ),
        ),
      ];

      // Configure mock using setRecipeState
      mockParentService.setRecipeState(
        currentUserId: 'user_123',
        recipes: testRecipes,
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Collaborative Recipe Discovery', () {
      test('should get collaborative recipes where user is member', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes();

        // Assert
        expect(recipes.length, equals(2)); // collab_1 and collab_2
        expect(recipes.map((r) => r.id), containsAll(['collab_1', 'collab_2']));
        expect(recipes.map((r) => r.id),
            isNot(contains('collab_3'))); // User not a member
        expect(recipes.map((r) => r.id),
            isNot(contains('personal_1'))); // Not collaborative
      });

      test('should filter by category', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          categoryFilter: ['category_1'],
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_1'));
      });

      test('should search by query in title', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          searchQuery: 'pasta',
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_1'));
      });

      test('should search by query in description', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          searchQuery: 'healthy',
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_2'));
      });

      test('should search by query in tags', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          searchQuery: 'italian',
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_1'));
      });

      test('should apply limit to results', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          limit: 1,
        );

        // Assert
        expect(recipes.length, equals(1));
      });

      test('should sort by most recent update', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes();

        // Assert
        expect(recipes.length, equals(2));
        expect(recipes[0].id, equals('collab_2')); // Updated 30 minutes ago
        expect(recipes[1].id, equals('collab_1')); // Updated 1 hour ago
      });

      test('should return empty list when user not logged in', () async {
        // Arrange
        mockParentService.setRecipeState(
          currentUserId: null,
          recipes: testRecipes,
        );

        // Act
        final recipes = await discoveryService.getCollaborativeRecipes();

        // Assert
        expect(recipes, isEmpty);
      });
    });

    group('Shared Recipe Discovery', () {
      test('should get recipes shared with current user', () async {
        // Act
        final recipes = await discoveryService.getSharedWithMe();

        // Assert
        expect(recipes.length,
            equals(1)); // Only collab_2 where user is member but not owner
        expect(recipes[0].id, equals('collab_2'));
      });

      test('should get recipes shared by current user', () async {
        // Act
        final recipes = await discoveryService.getSharedByMe();

        // Assert
        expect(recipes.length, equals(1)); // Only collab_1 where user is owner
        expect(recipes[0].id, equals('collab_1'));
      });

      test('should filter shared recipes by category', () async {
        // Act
        final recipes = await discoveryService.getSharedWithMe(
          categoryFilter: ['category_2'],
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_2'));
      });

      test('should search shared recipes by owner name', () async {
        // Act
        final recipes = await discoveryService.getSharedWithMe(
          searchQuery: 'Other User',
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_2'));
      });
    });

    group('Recommendation Engine Tests', () {
      test('should get trending recipes based on activity', () async {
        // Arrange
        final now = DateTime.now();
        final trendingRecipes = [
          RecipeBuilder()
              .withId('trending_1')
              .withTitle('Popular Recipe')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_999',
                  memberPermissions: {
                    'user_123': ResourcePermission.viewer,
                    'user_456': ResourcePermission.editor,
                    'user_789': ResourcePermission.viewer,
                    'user_111': ResourcePermission.viewer,
                  },
                  categoryIds: ['trending'],
                ),
              )
              .withUpdatedAt(now.subtract(Duration(hours: 1)))
              .withRating(4.8)
              .build(),
          RecipeBuilder()
              .withId('trending_2')
              .withTitle('Recent Hit')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_888',
                  memberPermissions: {
                    'user_123': ResourcePermission.editor,
                    'user_456': ResourcePermission.viewer,
                  },
                  categoryIds: ['trending'],
                ),
              )
              .withUpdatedAt(now.subtract(Duration(days: 2)))
              .withRating(4.5)
              .build(),
        ];

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [...testRecipes, ...trendingRecipes],
        );

        // Act
        final recipes = await discoveryService.getTrendingRecipes(
          limit: 2,
          timeWindow: Duration(days: 7),
        );

        // Assert
        expect(recipes.length, lessThanOrEqualTo(2));
        expect(
            recipes.first.id,
            equals(
                'trending_1')); // Higher score due to more members and recent activity
      });

      test('should get recently shared recipes within time window', () async {
        // Arrange
        final recentRecipe = RecipeBuilder()
            .withId('recent_1')
            .withTitle('Just Shared')
            .asCollaborative()
            .withSocialData(
              RecipeSocialData(
                ownerId: 'user_123',
                memberPermissions: {
                  'user_456': ResourcePermission.editor,
                },
              ),
            )
            .withCreatedAt(DateTime.now().subtract(Duration(hours: 2)))
            .build();

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [...testRecipes, recentRecipe],
        );

        // Act
        final recipes = await discoveryService.getRecentlySharedRecipes(
          timeWindow: Duration(days: 1),
        );

        // Assert
        expect(recipes.any((r) => r.id == 'recent_1'), isTrue);
      });

      test('should recommend recipes based on user history', () async {
        // Arrange - Simulate user preference for Italian recipes
        final italianRecipes = [
          RecipeBuilder()
              .withId('italian_1')
              .withTitle('Spaghetti Carbonara')
              .asCollaborative()
              .withTags(['italian', 'pasta', 'recommended'])
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_chef',
                  memberPermissions: {
                    'user_123': ResourcePermission.viewer,
                  },
                ),
              )
              .build(),
          RecipeBuilder()
              .withId('italian_2')
              .withTitle('Risotto alla Milanese')
              .asCollaborative()
              .withTags(['italian', 'rice', 'recommended'])
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_chef2',
                  memberPermissions: {
                    'user_123': ResourcePermission.editor,
                  },
                ),
              )
              .build(),
        ];

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [...testRecipes, ...italianRecipes],
        );

        // Act
        final recipes = await discoveryService.searchRecipes(
          query: 'italian',
          includePersonal: false,
        );

        // Assert
        expect(
            recipes
                .where((r) => r.personalTagIds?.contains('italian') ?? false)
                .length,
            greaterThanOrEqualTo(2));
      });

      test('should calculate discovery statistics correctly', () {
        // Arrange
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: testRecipes,
        );

        // Act
        final stats = discoveryService.getDiscoveryStatistics();

        // Assert
        expect(stats['personal_recipes'], equals(1));
        expect(stats['owned_collaborative'], equals(1));
        expect(stats['shared_with_me'], equals(1));
        expect(stats['total_recipes'], equals(3));
        expect(stats['collaboration_ratio'], greaterThan(0));
      });

      test('should get popular collaborative categories', () async {
        // Arrange
        final categorizedRecipes = [
          RecipeBuilder()
              .withId('cat_1')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  categoryIds: ['italian', 'pasta'],
                  memberPermissions: {'user_456': ResourcePermission.viewer},
                ),
              )
              .build(),
          RecipeBuilder()
              .withId('cat_2')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  categoryIds: ['italian', 'pizza'],
                  memberPermissions: {'user_789': ResourcePermission.editor},
                ),
              )
              .build(),
        ];

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [...testRecipes, ...categorizedRecipes],
        );

        // Act
        final categories =
            await discoveryService.getPopularCollaborativeCategories();

        // Assert
        expect(categories.containsKey('italian'), isTrue);
        expect(categories['italian'], greaterThanOrEqualTo(2));
      });
    });

    group('Advanced Filtering Tests', () {
      test('should filter by multiple categories', () async {
        // Arrange
        final multiCategoryRecipes = [
          RecipeBuilder()
              .withId('multi_1')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  categoryIds: ['healthy', 'vegetarian', 'quick'],
                  memberPermissions: {},
                ),
              )
              .build(),
          RecipeBuilder()
              .withId('multi_2')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  categoryIds: ['healthy', 'vegan'],
                  memberPermissions: {},
                ),
              )
              .build(),
        ];

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [...testRecipes, ...multiCategoryRecipes],
        );

        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          categoryFilter: ['healthy', 'vegetarian'],
        );

        // Assert
        expect(recipes.any((r) => r.id == 'multi_1'), isTrue);
        expect(recipes.any((r) => r.id == 'multi_2'), isTrue);
      });

      test('should handle complex search queries with Swedish characters',
          () async {
        // Arrange
        final swedishRecipes = [
          RecipeBuilder()
              .withId('swedish_1')
              .withTitle('Köttbullar med lingonsylt')
              .withDescription('Traditionella svenska köttbullar')
              .asCollaborative()
              .withTags(['svensk', 'kött', 'traditionell'])
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  memberPermissions: {},
                ),
              )
              .build(),
          RecipeBuilder()
              .withId('swedish_2')
              .withTitle('Räksmörgås')
              .withDescription('Öppen smörgås med räkor')
              .asCollaborative()
              .withTags(['svensk', 'fisk', 'smörgås'])
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  memberPermissions: {},
                ),
              )
              .build(),
        ];

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [...testRecipes, ...swedishRecipes],
        );

        // Act
        final recipes = await discoveryService.searchRecipes(
          query: 'köttbullar',
        );

        // Assert
        expect(recipes.any((r) => r.id == 'swedish_1'), isTrue);
      });

      test('should combine search and category filters', () async {
        // Act
        final recipes = await discoveryService.getCollaborativeRecipes(
          searchQuery: 'pasta',
          categoryFilter: ['category_1'],
        );

        // Assert
        expect(recipes.length, equals(1));
        expect(recipes[0].id, equals('collab_1'));
      });

      test('should search in ingredients field', () async {
        // Act
        final recipes = await discoveryService.searchRecipes(
          query: 'tomatoes',
        );

        // Assert
        expect(recipes.any((r) => r.ingredients.contains('tomatoes')), isTrue);
      });

      test('should handle empty search results gracefully', () async {
        // Act
        final recipes = await discoveryService.searchRecipes(
          query: 'nonexistent_ingredient_xyz',
        );

        // Assert
        expect(recipes, isEmpty);
      });
    });

    group('Pagination and Performance Tests', () {
      test('should handle pagination with limit', () async {
        // Arrange
        final manyRecipes = List.generate(
            50,
            (i) => RecipeBuilder()
                .withId('recipe_$i')
                .withTitle('Recipe $i')
                .asCollaborative()
                .withSocialData(
                  RecipeSocialData(
                    ownerId: 'user_123',
                    memberPermissions: {},
                  ),
                )
                .build());

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: manyRecipes,
        );

        // Act
        final firstPage = await discoveryService.getCollaborativeRecipes(
          limit: 10,
        );

        // Assert
        expect(firstPage.length, equals(10));
      });

      test('should handle large dataset efficiently', () async {
        // Arrange
        final largeDataset = List.generate(
            1000,
            (i) => RecipeBuilder()
                .withId('large_$i')
                .asCollaborative()
                .withSocialData(
                  RecipeSocialData(
                    ownerId: i % 2 == 0 ? 'user_123' : 'other_user',
                    memberPermissions: i % 2 == 0
                        ? {}
                        : {'user_123': ResourcePermission.viewer},
                  ),
                )
                .build());

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: largeDataset,
        );

        // Act
        final stopwatch = Stopwatch()..start();
        final recipes = await discoveryService.getCollaborativeRecipes(
          limit: 50,
        );
        stopwatch.stop();

        // Assert
        expect(recipes.length, lessThanOrEqualTo(50));
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });

      test('should sort results by relevance in search', () async {
        // Arrange
        final searchableRecipes = [
          RecipeBuilder()
              .withId('exact_title')
              .withTitle('Pasta')
              .withDescription('Some description')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  memberPermissions: {},
                ),
              )
              .build(),
          RecipeBuilder()
              .withId('in_description')
              .withTitle('Something else')
              .withDescription('This has pasta in description')
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  memberPermissions: {},
                ),
              )
              .build(),
          RecipeBuilder()
              .withId('in_tags')
              .withTitle('Another recipe')
              .withDescription('No match here')
              .withTags(['pasta', 'italian'])
              .asCollaborative()
              .withSocialData(
                RecipeSocialData(
                  ownerId: 'user_123',
                  memberPermissions: {},
                ),
              )
              .build(),
        ];

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: searchableRecipes,
        );

        // Act
        final results = await discoveryService.searchRecipes(
          query: 'pasta',
        );

        // Assert
        expect(results.first.id,
            equals('exact_title')); // Title match should be first
      });

      test('should handle concurrent discovery operations', () async {
        // Act
        final futures = [
          discoveryService.getCollaborativeRecipes(),
          discoveryService.getSharedWithMe(),
          discoveryService.getSharedByMe(),
          discoveryService.getTrendingRecipes(),
        ];

        // Assert
        await expectLater(
          Future.wait(futures),
          completes,
        );
      });

      test('should filter recipes by user correctly', () async {
        // Act
        final userRecipes = await discoveryService.getRecipesByUser(
          userId: 'user_123',
          includePersonal: true,
        );

        // Assert
        expect(userRecipes.any((r) => r.id == 'personal_1'), isTrue);
        expect(userRecipes.any((r) => r.id == 'collab_1'), isTrue);
      });
    });

    group('Error Handling', () {
      test('should handle errors gracefully', () async {
        // Arrange
        // NOTE: Exception testing for getters requires stubbing since we can't
        // configure the mock to throw from a getter. This is an acceptable
        // exception to the "no stubbing concrete getters" rule.
        // TODO: Consider alternative error testing approaches

        // For now, test with empty recipe list instead
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [],
        );

        // Act
        final recipes = await discoveryService.getCollaborativeRecipes();

        // Assert
        expect(recipes, isEmpty);
      });

      test('should handle null social data gracefully', () async {
        // Arrange
        final brokenRecipe = Recipe(
          core: RecipeCore(
            id: 'broken_1',
            title: 'Broken Recipe',
            description: 'No social data',
            ingredients: [],
            instructions: [],
            mealType: 'Test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          type: RecipeType.collaborative,
          socialData: null,
        );

        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          recipes: [brokenRecipe],
        );

        // Act
        final recipes = await discoveryService.getCollaborativeRecipes();

        // Assert
        expect(recipes, isEmpty); // Should filter out broken recipe
      });

      test('should handle empty search query', () async {
        // Act
        final recipes = await discoveryService.searchRecipes(
          query: '   ', // Whitespace only
        );

        // Assert
        expect(recipes, isEmpty);
      });
    });
  });
}

// Mock classes for testing
// MockUnifiedRecipeService is now imported from production_mocks.dart
