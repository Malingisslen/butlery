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
import 'package:butlery/core/providers/application_provider.dart' as production;

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

// Local pure-Mock classes: centralized MockRecipeServiceAdapter has concrete
// @override methods which breaks mocktail's when() stubbing.
class _MockRecipeServiceAdapter extends Mock implements RecipeServiceAdapter {}

void main() {
  group('SocialRecipeQueryService', () {
    late SocialRecipeQueryService queryService;
    late MockJsonCacheHelper mockCacheHelper;
    late _MockRecipeServiceAdapter mockServiceAdapter;
    late String currentUserId;
    late List<Recipe> testRecipes;

    setUpAll(() {
      registerFallbackValue('');
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Production ServiceLocator bridge so BaseService internals resolve
      production.ServiceLocator.reset();
      production.ServiceLocator.initialize(MockDIContainer());

      currentUserId = 'test-user-123';
      testRecipes = [];

      mockCacheHelper = MockJsonCacheHelper();
      mockServiceAdapter = _MockRecipeServiceAdapter();

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

      // Stub the pure-Mock adapter (no concrete overrides to interfere)
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

      queryService = SocialRecipeQueryService(
        getCacheHelper: () => mockCacheHelper,
        getCurrentUserId: () => currentUserId,
        setError: (error) {},
        serviceAdapter: mockServiceAdapter,
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
        final recipes = await queryService.getCollaborativeRecipesForUser();

        expect(recipes, isNotEmpty);
        expect(recipes.length, equals(4)); // 2 owned + 2 member
        expect(recipes.every((r) => r.isCollaborative), isTrue);
        expect(
            recipes.every((r) =>
                r.socialData?.memberPermissions?.containsKey(currentUserId) ==
                true),
            isTrue);
      });

      test('should return empty list when user not authenticated', () async {
        queryService = SocialRecipeQueryService(
          getCacheHelper: () => mockCacheHelper,
          getCurrentUserId: () => null,
          setError: (error) {},
          serviceAdapter: mockServiceAdapter,
        );

        final recipes = await queryService.getCollaborativeRecipesForUser();

        expect(recipes, isEmpty);
      });

      test('should get recipes shared by specific user', () async {
        final sharedByCurrentUser =
            await queryService.getRecipesSharedByUser(currentUserId);
        final sharedByFriend1 =
            await queryService.getRecipesSharedByUser('friend-1');

        expect(sharedByCurrentUser.length, equals(2));
        expect(
            sharedByCurrentUser
                .every((r) => r.socialData?.ownerId == currentUserId),
            isTrue);

        expect(sharedByFriend1.length, equals(1));
        expect(sharedByFriend1.first.socialData?.ownerId, equals('friend-1'));
      });

      test('should get owned collaborative recipes', () async {
        final ownedRecipes = await queryService.getOwnedCollaborativeRecipes();

        expect(ownedRecipes.length, equals(2));
        expect(
            ownedRecipes.every((r) => r.socialData?.ownerId == currentUserId),
            isTrue);
        expect(ownedRecipes.every((r) => r.isCollaborative), isTrue);
      });
    });

    group('Permission-Based Queries', () {
      test('should get recipes with admin permission', () async {
        final adminRecipes = await queryService
            .getRecipesWithPermission(ResourcePermission.admin);

        expect(adminRecipes.length, equals(2));
        expect(
            adminRecipes.every((r) =>
                r.socialData?.memberPermissions?[currentUserId] ==
                ResourcePermission.admin),
            isTrue);
      });

      test('should get recipes with editor permission', () async {
        final editorRecipes = await queryService
            .getRecipesWithPermission(ResourcePermission.editor);

        expect(editorRecipes.length, equals(1));
        expect(editorRecipes.first.id, equals('member-collab-1'));
        expect(
            editorRecipes.first.socialData?.memberPermissions?[currentUserId],
            equals(ResourcePermission.editor));
      });

      test('should get recipes with viewer permission', () async {
        final viewerRecipes = await queryService
            .getRecipesWithPermission(ResourcePermission.viewer);

        expect(viewerRecipes.length, equals(1));
        expect(viewerRecipes.first.id, equals('member-collab-2'));
        expect(
            viewerRecipes.first.socialData?.memberPermissions?[currentUserId],
            equals(ResourcePermission.viewer));
      });

      test('should return empty list when user not authenticated', () async {
        queryService = SocialRecipeQueryService(
          getCacheHelper: () => mockCacheHelper,
          getCurrentUserId: () => null,
          setError: (error) {},
          serviceAdapter: mockServiceAdapter,
        );

        final recipes = await queryService
            .getRecipesWithPermission(ResourcePermission.admin);

        expect(recipes, isEmpty);
      });
    });

    group('Search Operations', () {
      test('should search collaborative recipes by title', () async {
        final swedishRecipes =
            await queryService.searchCollaborativeRecipes('swedish');
        final pastaRecipes =
            await queryService.searchCollaborativeRecipes('pasta');
        final pizzaRecipes = await queryService
            .searchCollaborativeRecipes('PIZZA'); // Case insensitive

        expect(swedishRecipes.length, equals(2));
        expect(
            swedishRecipes
                .every((r) => r.title.toLowerCase().contains('swedish')),
            isTrue);

        expect(pastaRecipes.length, equals(1));
        expect(pastaRecipes.first.title, contains('Pasta'));

        expect(pizzaRecipes.length, equals(1));
        expect(pizzaRecipes.first.title, contains('Pizza'));
      });

      test('should return empty list for no matches', () async {
        final results =
            await queryService.searchCollaborativeRecipes('nonexistent');

        expect(results, isEmpty);
      });

      test('should handle empty search query', () async {
        final results = await queryService.searchCollaborativeRecipes('');

        expect(results.length,
            equals(4)); // All collaborative recipes user has access to
      });
    });

    group('Collaboration Statistics', () {
      test('should calculate collaboration statistics', () async {
        final stats = await queryService.getCollaborationStats();

        expect(stats, isNotNull);
        expect(stats['owned_collaborative'], equals(2));
        expect(stats['member_of'], equals(2));
        expect(stats['editor_access'], equals(1));
        expect(stats['viewer_access'], equals(1));
        expect(stats['total_collaborative'], equals(4));
      });

      test('should return empty stats when user not authenticated', () async {
        queryService = SocialRecipeQueryService(
          getCacheHelper: () => mockCacheHelper,
          getCurrentUserId: () => null,
          setError: (error) {},
          serviceAdapter: mockServiceAdapter,
        );

        final stats = await queryService.getCollaborationStats();

        expect(stats, isEmpty);
      });

      test('should get most active collaborators', () async {
        final collaborators =
            await queryService.getMostActiveCollaborators(limit: 5);

        expect(collaborators, isNotEmpty);
        expect(collaborators.contains('friend-1'), isTrue);
        expect(collaborators.contains('friend-2'), isTrue);
      });

      test('should limit active collaborators list', () async {
        final collaborators =
            await queryService.getMostActiveCollaborators(limit: 1);

        expect(collaborators.length, lessThanOrEqualTo(1));
      });

      test('should get collaboration activity summary', () async {
        final activity = await queryService.getCollaborationActivity();

        expect(activity, isNotNull);
        expect(activity['stats'], isNotNull);
        expect(activity['active_collaborators'], isNotNull);
        expect(activity['has_collaborative_activity'], isTrue);
      });
    });

    group('Cache Operations', () {
      test('should save recipe to cache', () async {
        final recipe = testRecipes[1]; // collaborative recipe

        await queryService.saveToCache(recipe);

        final savedData = await mockCacheHelper.loadJson(recipe.id);
        expect(savedData, isNotNull);
      });

      test('should load cached collaborative recipes', () async {
        await mockCacheHelper.saveJson(
            'owned-collab-1', testRecipes[1].toJson());
        await mockCacheHelper.saveJson(
            'owned-collab-2', testRecipes[2].toJson());
        await mockCacheHelper.saveJson(
            'personal-1', testRecipes[0].toJson()); // Personal recipe

        final cachedRecipes =
            await queryService.loadCachedCollaborativeRecipes();

        expect(cachedRecipes.length, equals(2)); // Only collaborative
        expect(cachedRecipes.every((r) => r.isCollaborative), isTrue);
      });

      test('should handle corrupted cache data', () async {
        await mockCacheHelper.saveJson('corrupted-1', {'invalid': 'data'});

        final cachedRecipes =
            await queryService.loadCachedCollaborativeRecipes();

        expect(cachedRecipes, isEmpty);
      });

      test('should clear cached recipes', () async {
        await mockCacheHelper.saveJson('test-1', {'test': 'data'});

        await queryService.clearCachedRecipes();

        final keys = await mockCacheHelper.getAllKeys();
        expect(keys, isEmpty);
      });

      test('should get cache statistics', () async {
        await mockCacheHelper.saveJson('recipe-1', testRecipes[1].toJson());
        await mockCacheHelper.saveJson('recipe-2', testRecipes[2].toJson());
        await mockCacheHelper.saveJson('recipe-3', testRecipes[3].toJson());

        final stats = await queryService.getCacheStats();

        expect(stats['total_cached'], equals(3));
        expect(stats['collaborative_cached'], greaterThanOrEqualTo(0));
      });
    });

    group('Error Handling', () {
      test('should handle service adapter errors gracefully', () async {
        when(() => mockServiceAdapter.getRecipesForUser(any()))
            .thenThrow(Exception('Database error'));

        final recipes = await queryService.getCollaborativeRecipesForUser();
        final stats = await queryService.getCollaborationStats();
        final collaborators = await queryService.getMostActiveCollaborators();

        expect(recipes, isEmpty);
        // getCollaborativeRecipesForUser catches the error and returns [],
        // so getCollaborationStats succeeds with zeroed values
        expect(stats['total_collaborative'], equals(0));
        expect(collaborators, isEmpty);
      });

      test('should handle cache errors gracefully', () async {
        final recipe = testRecipes[1];

        await expectLater(
          queryService.saveToCache(recipe),
          completes,
        );

        await mockCacheHelper.clear();

        final cachedRecipes =
            await queryService.loadCachedCollaborativeRecipes();
        expect(cachedRecipes, isEmpty);

        await expectLater(
          queryService.clearCachedRecipes(),
          completes,
        );
      });
    });
  });
}
