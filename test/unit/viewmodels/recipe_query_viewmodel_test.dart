import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe/recipe_query_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe/recipe_completeness.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('RecipeQueryViewModel', () {
    late RecipeQueryViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;

    // Test data
    final personalRecipe1 = RecipeFactory.build(
      id: 'personal_1',
      title: 'Pannkakor',
      description: 'Klassiska svenska pannkakor',
      mealType: 'Frukost',
      personalTagIds: ['Vegetarisk', 'Snabb', 'Barnvänlig'],
      type: RecipeType.personal,
      rating: 4.5,
      lastCookedAt: DateTime.now().subtract(const Duration(days: 2)),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    );

    final personalRecipe2 = RecipeFactory.build(
      id: 'personal_2',
      title: 'Köttbullar',
      description: 'Mormors köttbullar med brunsås',
      mealType: 'Middag',
      personalTagIds: ['Traditionell', 'Kött'],
      type: RecipeType.personal,
      rating: 5.0,
      lastCookedAt: DateTime.now().subtract(const Duration(days: 5)),
      createdAt:
          DateTime.now().subtract(const Duration(days: 20)), // Older creation
      updatedAt:
          DateTime.now().subtract(const Duration(days: 10)), // Older update
      imageUrls: ['image1.jpg'],
    );

    final sharedRecipe1 = RecipeFactory.build(
      id: 'shared_1',
      title: 'Tacos',
      description: 'Fredagstacos med allt gott',
      mealType: 'Middag',
      personalTagIds: ['Mexikansk', 'Familj'],
      type: RecipeType.collaborative,
      rating: 4.0,
      createdAt:
          DateTime.now().subtract(const Duration(days: 15)), // Older creation
      updatedAt:
          DateTime.now().subtract(const Duration(days: 8)), // Older update
      socialData: RecipeSocialData(
        ownerId: 'friend_123',
        ownerDisplayName: 'Friend User',
        memberPermissions: {
          'test_user': ResourcePermission.editor,
          'friend_123': ResourcePermission.admin,
        },
        allowGuestViewing: false,
        allowMemberInvites: true,
      ),
    );

    final sharedRecipe2 = RecipeFactory.build(
      id: 'shared_2',
      title: 'Sallad',
      description: 'Fräsch grönsallad',
      mealType: 'Lunch',
      personalTagIds: ['Vegetarisk', 'Hälsosam', 'Snabb'],
      type: RecipeType.collaborative,
      rating: 3.5,
      createdAt:
          DateTime.now().subtract(const Duration(days: 10)), // Older creation
      updatedAt:
          DateTime.now().subtract(const Duration(days: 5)), // Older update
      socialData: RecipeSocialData(
        ownerId: 'test_user',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'test_user': ResourcePermission.admin,
          'friend_456': ResourcePermission.viewer,
        },
        allowGuestViewing: false,
        allowMemberInvites: true,
      ),
    );

    final recentRecipe = RecipeFactory.build(
      id: 'recent_1',
      title: 'Pasta Carbonara',
      description: 'Krämig italiensk pasta',
      mealType: 'Middag',
      personalTagIds: ['Italiensk', 'Pasta'],
      type: RecipeType.personal,
      rating: 4.8,
      lastCookedAt: DateTime.now().subtract(const Duration(days: 1)),
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
    );

    final allRecipes = [
      personalRecipe1,
      personalRecipe2,
      sharedRecipe1,
      sharedRecipe2,
      recentRecipe,
    ];

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeType.personal);

      // Bridge production ServiceLocator to test GetIt instance
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Get the existing mock from the service locator
      mockRecipeService = ServiceLocator.get<UnifiedRecipeService>()
          as MockUnifiedRecipeService;

      // Configure mock behavior
      mockRecipeService.setRecipeState(
        recipes: allRecipes,
        currentUserId: 'test_user',
      );

      // Create viewModel (will use the configured mock from ServiceLocator)
      viewModel = RecipeQueryViewModel();
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Basic State', () {
      test('should access all recipes from service', () {
        expect(viewModel.allRecipes, equals(allRecipes));
        expect(viewModel.hasRecipes, isTrue);
      });

      test('should filter personal recipes', () {
        final personal = viewModel.personalRecipes;
        expect(personal.length, equals(3));
        expect(personal.every((r) => r.isPersonal), isTrue);
      });

      test('should filter collaborative recipes', () {
        final collaborative = viewModel.collaborativeRecipes;
        expect(collaborative.length, equals(2));
        expect(collaborative.every((r) => r.isCollaborative), isTrue);
      });

      test('should handle empty recipes list', () {
        mockRecipeService.setRecipeState(recipes: []);
        expect(viewModel.hasRecipes, isFalse);
        expect(viewModel.hasPersonalRecipes, isFalse);
        expect(viewModel.hasCollaborativeRecipes, isFalse);
      });

      test('should get current user ID from service', () {
        expect(viewModel.currentUserId, equals('test_user'));
      });
    });

    group('Basic Queries', () {
      test('should get recipe by ID', () {
        final recipe = viewModel.getRecipeById('personal_1');
        expect(recipe, isNotNull);
        expect(recipe!.title, equals('Pannkakor'));
      });

      test('should return null for non-existent ID', () {
        final recipe = viewModel.getRecipeById('non_existent');
        expect(recipe, isNull);
      });

      test('should return null for empty ID', () {
        final recipe = viewModel.getRecipeById('');
        expect(recipe, isNull);
      });

      test('should get recipes by meal type', () {
        final middag = viewModel.getRecipesByMealType('Middag');
        expect(middag.length, equals(3));
        expect(middag.every((r) => r.mealType == 'Middag'), isTrue);
      });

      test('should get recipes by tag', () {
        final vegetarisk = viewModel.getRecipesByTag('Vegetarisk');
        expect(vegetarisk.length, equals(2));
        expect(
            vegetarisk.every(
                (r) => r.personalTagIds?.contains('Vegetarisk') ?? false),
            isTrue);
      });

      test('should get recipes by type', () {
        final personal = viewModel.getRecipesByType(RecipeType.personal);
        expect(personal.length, equals(3));
        expect(personal.every((r) => r.type == RecipeType.personal), isTrue);
      });
    });

    group('Search Functionality', () {
      test('should search by title', () {
        final results = viewModel.searchRecipes('pannkakor');
        expect(results.length, equals(1));
        expect(results.first.title, equals('Pannkakor'));
      });

      test('should search by description', () {
        final results = viewModel.searchRecipes('krämig');
        expect(results.length, equals(1));
        expect(results.first.title, equals('Pasta Carbonara'));
      });

      test('should search by ingredients', () {
        // Add a recipe with specific ingredients
        final recipeWithIngredients = RecipeFactory.build(
          title: 'Test Recipe',
          ingredients: ['mjölk', 'ägg', 'mjöl'],
        );
        mockRecipeService
            .setRecipeState(recipes: [...allRecipes, recipeWithIngredients]);

        final results = viewModel.searchRecipes('mjölk');
        expect(results.length, equals(1));
        expect(results.first.title, equals('Test Recipe'));
      });

      test('should search by tags', () {
        final results = viewModel.searchRecipes('italiensk');
        expect(results.length, equals(1));
        expect(results.first.title, equals('Pasta Carbonara'));
      });

      test('should handle case-insensitive search', () {
        final results = viewModel.searchRecipes('PANNKAKOR');
        expect(results.length, equals(1));
        expect(results.first.title, equals('Pannkakor'));
      });

      test('should return all recipes for empty search', () {
        final results = viewModel.searchRecipes('');
        expect(results.length, equals(allRecipes.length));
      });

      test('should update search query', () {
        fakeAsync((async) {
          viewModel.updateSearchQuery('test query');
          async.elapse(const Duration(milliseconds: 300));
          expect(viewModel.searchQuery, equals('test query'));
        });
      });

      test('should clear search', () {
        viewModel.updateSearchQuery('test');
        viewModel.clearSearch();
        expect(viewModel.searchQuery, isEmpty);
      });

      test('should notify listeners on search update', () {
        fakeAsync((async) {
          int notificationCount = 0;
          viewModel.addListener(() => notificationCount++);

          viewModel.updateSearchQuery('test');
          async.elapse(const Duration(milliseconds: 300));
          // Debounced search triggers: setLoading(true), operation notifyListeners, setSuccess
          expect(notificationCount, equals(3));

          viewModel.clearSearch(); // Immediate: +1
          expect(notificationCount, equals(4));
        });
      });
    });

    group('Filtering', () {
      test('should filter by meal type', () {
        viewModel.setMealTypeFilter('Middag');
        final filtered = viewModel.filteredRecipes;
        expect(filtered.length, equals(3));
        expect(filtered.every((r) => r.mealType == 'Middag'), isTrue);
      });

      test('should filter by tag', () {
        // ignore: deprecated_member_use_from_same_package
        viewModel.setTagFilter('Vegetarisk');
        final filtered = viewModel.filteredRecipes;
        expect(filtered.length, equals(2));
        expect(
            filtered.every(
                (r) => r.personalTagIds?.contains('Vegetarisk') ?? false),
            isTrue);
      });

      test('should filter by type', () {
        viewModel.setTypeFilter(RecipeType.collaborative);
        final filtered = viewModel.filteredRecipes;
        expect(filtered.length, equals(2));
        expect(
            filtered.every((r) => r.type == RecipeType.collaborative), isTrue);
      });

      test('should combine search and filters', () {
        fakeAsync((async) {
          viewModel.updateSearchQuery('middag');
          async.elapse(const Duration(milliseconds: 300));
          // ignore: deprecated_member_use_from_same_package
          viewModel.setTagFilter('Vegetarisk');

          final filtered = viewModel.filteredRecipes;
          expect(filtered.length,
              equals(0)); // No vegetarian dinner recipes in search results
        });
      });

      test('should clear individual filters', () {
        viewModel.setMealTypeFilter('Middag');
        // ignore: deprecated_member_use_from_same_package
        viewModel.setTagFilter('Vegetarisk');
        viewModel.setTypeFilter(RecipeType.personal);

        viewModel.clearFilters();

        expect(viewModel.selectedMealType, isNull);
        expect(viewModel.selectedTag, isNull);
        expect(viewModel.selectedType, isNull);
      });

      test('should clear all filters and search', () {
        viewModel.updateSearchQuery('test');
        viewModel.setMealTypeFilter('Middag');
        // ignore: deprecated_member_use_from_same_package
        viewModel.setTagFilter('Vegetarisk');

        viewModel.clearAllFiltersAndSearch();

        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.selectedMealType, isNull);
        expect(viewModel.selectedTag, isNull);
        expect(viewModel.hasActiveFilters, isFalse);
      });

      test('should detect active filters', () {
        fakeAsync((async) {
          expect(viewModel.hasActiveFilters, isFalse);

          viewModel.updateSearchQuery('test');
          async.elapse(const Duration(milliseconds: 300));
          expect(viewModel.hasActiveFilters, isTrue);

          viewModel.clearSearch();
          viewModel.setMealTypeFilter('Middag');
          expect(viewModel.hasActiveFilters, isTrue);
        });
      });
    });

    group('Specialized Queries', () {
      test('should get editable recipes', () {
        final editable = viewModel.getEditableRecipes();
        // test_user can edit: 3 personal recipes + 2 shared recipes (admin on one, editor on another)
        expect(editable.length, equals(5));
      });

      test('should get recently cooked recipes', () {
        final recent = viewModel.getRecentlyCookedRecipes(daysBack: 7);
        expect(recent.length, equals(3));
        expect(recent.every((r) => r.lastCookedAt != null), isTrue);
      });

      test('should get recently created recipes', () {
        final recent = viewModel.getRecentlyCreatedRecipes(daysBack: 7);
        expect(recent.length,
            equals(1)); // Only recentRecipe created within 7 days
      });

      test('should get recently edited recipes', () {
        final recent = viewModel.getRecentlyEditedRecipes(daysBack: 2);
        expect(recent.length, equals(2)); // personalRecipe1 and recentRecipe
      });

      test('should get favorite recipes', () {
        final favorites = viewModel.getFavoriteRecipes();
        expect(favorites.length, equals(3)); // Recipes with rating >= 4.5
        expect(
            favorites.first.rating, equals(5.0)); // Should be sorted by rating
      });

      test('should get high rated recipes', () {
        final highRated = viewModel.getHighRatedRecipes(minRating: 4.0);
        expect(highRated.length, equals(4));
        expect(highRated.every((r) => r.rating != null && r.rating! >= 4.0),
            isTrue);
      });

      test('should get recipes with images', () {
        final withImages = viewModel.getRecipesWithImages();
        expect(withImages.length, equals(1));
        expect(withImages.first.title, equals('Köttbullar'));
      });

      test('should get recipes without images', () {
        final withoutImages = viewModel.getRecipesWithoutImages();
        expect(withoutImages.length, equals(4));
        expect(withoutImages.every((r) => r.imageUrls.isEmpty), isTrue);
      });
    });

    group('Social Queries', () {
      test('should get recipes shared with me', () {
        // Note: The method looks for recipes that are both collaborative AND shared (isShared)
        // Since our test recipes are collaborative but not shared type, this returns empty
        final sharedWithMe = viewModel.getSharedWithMe();
        expect(sharedWithMe.length, equals(0));
      });

      test('should get recipes shared by me', () {
        // Note: The method looks for recipes that are both collaborative AND shared (isShared)
        // Since our test recipes are collaborative but not shared type, this returns empty
        final sharedByMe = viewModel.getSharedByMe();
        expect(sharedByMe.length, equals(0));
      });

      test('should get recipes with specific collaborator', () {
        final withCollaborator =
            viewModel.getRecipesWithCollaborator('friend_456');
        expect(withCollaborator.length, equals(1));
        expect(withCollaborator.first.title, equals('Sallad'));
      });

      test('should handle empty collaborator ID', () {
        final recipes = viewModel.getRecipesWithCollaborator('');
        expect(recipes, isEmpty);
      });
    });

    group('Grouping and Organization', () {
      test('should group recipes by meal type', () {
        final grouped = viewModel.recipesByMealType;

        expect(grouped.containsKey('Frukost'), isTrue);
        expect(grouped.containsKey('Lunch'), isTrue);
        expect(grouped.containsKey('Middag'), isTrue);

        expect(grouped['Middag']!.length, equals(3));
        expect(grouped['Frukost']!.length, equals(1));
      });

      test('should group recipes by tags', () {
        final grouped = viewModel.recipesByTag;

        expect(grouped.containsKey('Vegetarisk'), isTrue);
        expect(grouped['Vegetarisk']!.length, equals(2));

        // Each recipe should appear under each of its tags
        expect(grouped.containsKey('Snabb'), isTrue);
        expect(grouped['Snabb']!.length, equals(2));
      });

      test('should group recipes by type', () {
        final grouped = viewModel.recipesByType;

        expect(grouped[RecipeType.personal]!.length, equals(3));
        expect(grouped[RecipeType.collaborative]!.length, equals(2));
      });

      test('should sort grouped recipes alphabetically', () {
        final grouped = viewModel.recipesByMealType;
        final middagRecipes = grouped['Middag']!;

        expect(middagRecipes.first.title, equals('Köttbullar'));
        expect(middagRecipes.last.title, equals('Tacos'));
      });
    });

    group('Metadata and Options', () {
      test('should get used meal types', () {
        final mealTypes = viewModel.usedMealTypes;

        expect(mealTypes.length, equals(3));
        expect(mealTypes, contains('Frukost'));
        expect(mealTypes, contains('Lunch'));
        expect(mealTypes, contains('Middag'));

        // Should be sorted alphabetically
        expect(mealTypes.first, equals('Frukost'));
      });

      test('should get used tags', () {
        final tags = viewModel.usedTags;

        expect(tags, contains('Vegetarisk'));
        expect(tags, contains('Snabb'));
        expect(tags, contains('Italiensk'));

        // Should be sorted alphabetically
        expect(tags.first, equals('Barnvänlig'));
      });

      test('should get used types', () {
        final types = viewModel.usedTypes;

        expect(types.length, equals(2));
        expect(types, contains(RecipeType.personal));
        expect(types, contains(RecipeType.collaborative));
      });
    });

    group('Statistics and Insights', () {
      test('should provide recipe insights', () {
        final insights = viewModel.recipeInsights;

        expect(insights.totalRecipes, equals(5));
        expect(insights.personalRecipes, equals(3));
        expect(insights.collaborativeRecipes, equals(2));
        expect(insights.mealTypes, equals(3));
      });

      test('should get most used meal types', () {
        final mealTypes = viewModel.getMostUsedMealTypes();

        expect(mealTypes.first.key, equals('Middag'));
        expect(mealTypes.first.value, equals(3));
      });

      test('should get most used tags', () {
        final tags = viewModel.getMostUsedTags();

        expect(tags.first.key, equals('Vegetarisk'));
        expect(tags.first.value, equals(2));
        expect(tags[1].key, equals('Snabb'));
        expect(tags[1].value, equals(2));
      });

      test('should calculate average ratings by meal type', () {
        final averages = viewModel.getAverageRatingsByMealType();

        expect(averages['Frukost'], equals(4.5));
        expect(averages['Middag'], closeTo(4.6, 0.1)); // (5.0 + 4.0 + 4.8) / 3
      });

      test('should get cooking frequency by meal type', () {
        final frequency = viewModel.getCookingFrequencyByMealType();

        expect(
            frequency['Middag'], equals(2)); // personalRecipe2 and recentRecipe
        expect(frequency['Frukost'], equals(1)); // personalRecipe1
      });

      test('should include completeness stats in insights', () {
        final insights = viewModel.recipeInsights;

        // All default factory recipes have empty imageUrls except personalRecipe2
        expect(insights.withoutPhotoCount, equals(4));
        // All have timeMinutes: 30
        expect(insights.withoutTimeCount, equals(0));
        // 4 recipes at 0.65 score (< 0.7 threshold), 1 at 0.70 (not incomplete)
        expect(insights.incompleteCount, equals(4));
        expect(insights.completenessDistribution, isA<Map<String, int>>());
      });

      test('should compute completeness distribution buckets', () {
        final insights = viewModel.recipeInsights;
        final dist = insights.completenessDistribution;

        // All 5 recipes score 0.65 or 0.70 -> all in '50-75%' bucket
        expect(dist['0-25%'], equals(0));
        expect(dist['25-50%'], equals(0));
        expect(dist['50-75%'], equals(5));
        expect(dist['75-100%'], equals(0));
      });

      test('should return incomplete recipes sorted by score ascending', () {
        final incomplete = viewModel.getIncompleteRecipes();

        expect(incomplete.length, equals(4));
        // All incomplete recipes have the same score (0.65), so order is stable
        for (final recipe in incomplete) {
          expect(recipe.completenessScore, lessThan(0.7));
        }
      });

      test('should respect limit on getIncompleteRecipes', () {
        final incomplete = viewModel.getIncompleteRecipes(limit: 2);
        expect(incomplete.length, equals(2));
      });

      test('should handle fully complete recipes', () {
        final completeRecipe = RecipeFactory.build(
          id: 'complete_1',
          title: 'Complete Recipe',
          ingredients: ['a', 'b', 'c'],
          instructions: ['step 1', 'step 2'],
          imageUrls: ['img.jpg'],
          portions: 4,
          timeMinutes: 30,
        );
        mockRecipeService.setRecipeState(recipes: [completeRecipe]);

        final insights = viewModel.recipeInsights;
        expect(insights.incompleteCount, equals(0));
        expect(insights.withoutPhotoCount, equals(0));

        final incomplete = viewModel.getIncompleteRecipes();
        expect(incomplete, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('should handle recipes without ratings', () {
        final recipeNoRating = RecipeFactory.build(
          title: 'No Rating',
          rating: null,
        );
        mockRecipeService.setRecipeState(recipes: [recipeNoRating]);

        final favorites = viewModel.getFavoriteRecipes();
        expect(favorites, isEmpty);

        final highRated = viewModel.getHighRatedRecipes();
        expect(highRated, isEmpty);
      });

      test('should handle recipes without tags', () {
        final recipeNoTags = RecipeFactory.build(
          title: 'No Tags',
          personalTagIds: [], // Use empty list instead of null to avoid default tags
        );
        mockRecipeService.setRecipeState(recipes: [recipeNoTags]);

        final byTag = viewModel.getRecipesByTag('any');
        expect(byTag, isEmpty);

        final tags = viewModel.usedTags;
        expect(tags, isEmpty);
      });

      test('should handle empty recipe list', () {
        mockRecipeService.setRecipeState(recipes: []);

        expect(viewModel.filteredRecipes, isEmpty);
        expect(viewModel.recipesByMealType, isEmpty);
        expect(viewModel.recipesByTag, isEmpty);
        expect(viewModel.recipesByType, isEmpty);
        expect(viewModel.usedMealTypes, isEmpty);
        expect(viewModel.usedTags, isEmpty);
      });

      test('should handle null current user ID', () {
        mockRecipeService.setRecipeState(
          recipes: allRecipes,
          currentUserId: null,
        );

        final editable = viewModel.getEditableRecipes();
        expect(editable, isEmpty);

        final sharedWithMe = viewModel.getSharedWithMe();
        expect(sharedWithMe, isEmpty);

        final sharedByMe = viewModel.getSharedByMe();
        expect(sharedByMe, isEmpty);
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        final testViewModel = RecipeQueryViewModel();
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle operations after dispose', () {
        final testViewModel = RecipeQueryViewModel();
        testViewModel.dispose();

        // Operations that call notifyListeners should throw
        expect(
            () => testViewModel.updateSearchQuery('test'), throwsFlutterError);
        expect(() => testViewModel.clearSearch(), throwsFlutterError);
        expect(() => testViewModel.setMealTypeFilter('Middag'),
            throwsFlutterError);

        // Read-only operations should still work (they don't call notifyListeners)
        expect(() => testViewModel.allRecipes, returnsNormally);
        expect(() => testViewModel.searchRecipes('test'), returnsNormally);
      });
    });
  });
}
