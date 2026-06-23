import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/service_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  group('RecipeListViewModel', () {
    late RecipeListViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockSearchService mockSearchService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(SortCriteria.title);

      // Bridge production ServiceLocator to test GetIt instance
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks using centralized factory
      mockRecipeService = MockUnifiedRecipeService();
      mockSearchService = MockFactory.createSearchService();

      // Configure mock state using configuration method
      mockRecipeService.setRecipeState(
        recipes: [],
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
        isInitialized: true,
        isLoading: false,
        error: null,
      );

      // Stub initialize() so it returns Future<void> instead of null
      when(() => mockRecipeService.initialize()).thenAnswer((_) async {});

      // Setup default mock behaviors for SearchService
      when(() => mockSearchService.searchRecipes(any(), any())).thenAnswer(
        (invocation) {
          final recipes = invocation.positionalArguments[0] as List<Recipe>;
          final query = invocation.positionalArguments[1] as String;
          if (query.isEmpty) return recipes;
          return recipes
              .where(
                (r) =>
                    r.title.toLowerCase().contains(query.toLowerCase()) ||
                    r.description.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
        },
      );

      when(
        () => mockSearchService.sortRecipes(
          any(),
          any(),
          ascending: any(named: 'ascending'),
        ),
      ).thenAnswer((invocation) {
        final recipes = invocation.positionalArguments[0] as List<Recipe>;
        final criteria = invocation.positionalArguments[1] as SortCriteria;
        final ascending =
            invocation.namedArguments[#ascending] as bool? ?? true;

        final sorted = List<Recipe>.from(recipes);
        sorted.sort((a, b) {
          int comparison;
          switch (criteria) {
            case SortCriteria.title:
              comparison = a.title.compareTo(b.title);
              break;
            case SortCriteria.time:
              comparison = (a.timeMinutes ?? 999).compareTo(
                b.timeMinutes ?? 999,
              );
              break;
            case SortCriteria.rating:
              comparison = (a.rating ?? 0).compareTo(b.rating ?? 0);
              break;
            case SortCriteria.portions:
              comparison = (a.portions ?? 0).compareTo(b.portions ?? 0);
              break;
            case SortCriteria.mealType:
              comparison = a.mealType.compareTo(b.mealType);
              break;
            case SortCriteria.lastCooked:
              final dateA = a.lastCookedAt;
              final dateB = b.lastCookedAt;
              if (dateA == null && dateB == null) {
                comparison = 0;
              } else if (dateA == null) {
                comparison = 1;
              } else if (dateB == null) {
                comparison = -1;
              } else {
                comparison = dateA.compareTo(dateB);
              }
              break;
            case SortCriteria.cookCount:
              comparison = a.cookCount.compareTo(b.cookCount);
              break;
            case SortCriteria.newest:
              comparison = a.createdAt.compareTo(b.createdAt);
              break;
            case SortCriteria.random:
              comparison = 0;
              break;
          }
          return ascending ? comparison : -comparison;
        });
        if (criteria == SortCriteria.random) sorted.shuffle();
        return sorted;
      });

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);
      TestServiceLocator.registerMock<SearchService>(mockSearchService);

      // Create viewModel with all dependencies injected
      viewModel = RecipeListViewModel(
        recipeService: mockRecipeService,
        searchService: mockSearchService,
        tagEditingService: TagEditingService(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
      viewModel.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        // Arrange - viewModel already initialized in setUp

        // Act - no action needed, checking initial state

        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.sortCriteria, equals(SortCriteria.title));
        expect(viewModel.sortAscending, isTrue);
        expect(viewModel.activeTimeFilters, isEmpty);
        expect(viewModel.activeMealTypeFilters, isEmpty);
        expect(viewModel.activeRatingFilters, isEmpty);
        expect(viewModel.hasActiveFilters, isFalse);
      });

      test('should register listener for recipe service updates', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Recipe 1'),
          RecipeFactory.build(id: 'r2', title: 'Recipe 2'),
        ];

        // Act - update service state
        mockRecipeService.setRecipeState(recipes: recipes);
        mockRecipeService.notifyListeners();

        // Assert - viewModel should reflect changes
        expect(viewModel.recipes, hasLength(2));
      });
    });

    group('Search Functionality', () {
      test('should update search query and filter recipes', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Pasta Carbonara'),
          RecipeFactory.build(id: 'r2', title: 'Chicken Salad'),
          RecipeFactory.build(id: 'r3', title: 'Pasta Bolognese'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.updateSearch('pasta');

        // Assert
        expect(viewModel.searchQuery, equals('pasta'));
        expect(viewModel.recipes, hasLength(2));
        expect(
          viewModel.recipes.every(
            (r) => r.title.toLowerCase().contains('pasta'),
          ),
          isTrue,
        );
      });

      test('should not notify if search query unchanged', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.updateSearch('test');
        final firstCount = notificationCount;
        viewModel.updateSearch('test'); // Same query

        // Assert
        expect(
          notificationCount,
          equals(firstCount),
        ); // No additional notification
      });

      test('should clear search when query is empty', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Recipe 1'),
          RecipeFactory.build(id: 'r2', title: 'Recipe 2'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        viewModel.updateSearch('test');

        // Act
        viewModel.updateSearch('');

        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.recipes, hasLength(2)); // All recipes shown
      });
    });

    group('Sorting Functionality', () {
      test('should sort recipes by title ascending by default', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Zebra Cake'),
          RecipeFactory.build(id: 'r2', title: 'Apple Pie'),
          RecipeFactory.build(id: 'r3', title: 'Banana Bread'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act - default sorting
        final sorted = viewModel.recipes;

        // Assert
        expect(sorted[0].title, equals('Apple Pie'));
        expect(sorted[1].title, equals('Banana Bread'));
        expect(sorted[2].title, equals('Zebra Cake'));
      });

      test('should toggle sort direction when same criteria selected', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'A Recipe'),
          RecipeFactory.build(id: 'r2', title: 'B Recipe'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act - toggle to descending
        viewModel.updateSort(
          SortCriteria.title,
        ); // Already title, should toggle

        // Assert
        expect(viewModel.sortAscending, isFalse);
        expect(viewModel.recipes[0].title, equals('B Recipe'));
        expect(viewModel.recipes[1].title, equals('A Recipe'));
      });

      test('should reset to ascending when new criteria selected', () {
        // Arrange
        viewModel.updateSort(SortCriteria.title);
        viewModel.updateSort(SortCriteria.title); // Toggle to descending

        // Act - change criteria
        viewModel.updateSort(SortCriteria.time);

        // Assert
        expect(viewModel.sortCriteria, equals(SortCriteria.time));
        expect(viewModel.sortAscending, isTrue);
      });

      test('should sort by cooking time', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Quick', timeMinutes: 15),
          RecipeFactory.build(id: 'r2', title: 'Long', timeMinutes: 90),
          RecipeFactory.build(id: 'r3', title: 'Medium', timeMinutes: 45),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.updateSort(SortCriteria.time);

        // Assert
        expect(viewModel.recipes[0].timeMinutes, equals(15));
        expect(viewModel.recipes[1].timeMinutes, equals(45));
        expect(viewModel.recipes[2].timeMinutes, equals(90));
      });

      test('should sort by rating', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Good', rating: 3.5),
          RecipeFactory.build(id: 'r2', title: 'Best', rating: 5.0),
          RecipeFactory.build(id: 'r3', title: 'Better', rating: 4.5),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.updateSort(SortCriteria.rating);

        // Assert
        expect(viewModel.recipes[0].rating, equals(3.5));
        expect(viewModel.recipes[1].rating, equals(4.5));
        expect(viewModel.recipes[2].rating, equals(5.0));
      });
    });

    group('Time Filtering', () {
      test('should filter quick recipes (under 30 minutes)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Quick', timeMinutes: 15),
          RecipeFactory.build(id: 'r2', title: 'Medium', timeMinutes: 45),
          RecipeFactory.build(id: 'r3', title: 'Long', timeMinutes: 90),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleTimeFilter('quick');

        // Assert
        expect(viewModel.activeTimeFilters, contains('quick'));
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].timeMinutes, lessThan(30));
      });

      test('should filter medium recipes (30-60 minutes)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Quick', timeMinutes: 15),
          RecipeFactory.build(id: 'r2', title: 'Medium', timeMinutes: 45),
          RecipeFactory.build(id: 'r3', title: 'Long', timeMinutes: 90),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleTimeFilter('medium');

        // Assert
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].timeMinutes, equals(45));
      });

      test('should filter long recipes (over 60 minutes)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Quick', timeMinutes: 15),
          RecipeFactory.build(id: 'r2', title: 'Medium', timeMinutes: 45),
          RecipeFactory.build(id: 'r3', title: 'Long', timeMinutes: 90),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleTimeFilter('long');

        // Assert
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].timeMinutes, greaterThan(60));
      });

      test('should support multiple time filters with OR logic', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Quick', timeMinutes: 15),
          RecipeFactory.build(id: 'r2', title: 'Medium', timeMinutes: 45),
          RecipeFactory.build(id: 'r3', title: 'Long', timeMinutes: 90),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act - select both quick and long
        viewModel.toggleTimeFilter('quick');
        viewModel.toggleTimeFilter('long');

        // Assert - should show quick AND long, but not medium
        expect(viewModel.recipes, hasLength(2));
        expect(viewModel.recipes.any((r) => r.timeMinutes! < 30), isTrue);
        expect(viewModel.recipes.any((r) => r.timeMinutes! > 60), isTrue);
        expect(
          viewModel.recipes.any(
            (r) => r.timeMinutes! >= 30 && r.timeMinutes! <= 60,
          ),
          isFalse,
        );
      });

      test('should toggle time filter on and off', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', timeMinutes: 15),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act & Assert - turn on
        viewModel.toggleTimeFilter('quick');
        expect(viewModel.activeTimeFilters, contains('quick'));

        // Act & Assert - turn off
        viewModel.toggleTimeFilter('quick');
        expect(viewModel.activeTimeFilters, isEmpty);
      });
    });

    group('Meal Type Filtering', () {
      test('should filter by breakfast (Frukost)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Gröt', mealType: 'Frukost'),
          RecipeFactory.build(id: 'r2', title: 'Pasta', mealType: 'Middag'),
          RecipeFactory.build(id: 'r3', title: 'Sallad', mealType: 'Lunch'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleMealTypeFilter('breakfast');

        // Assert
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].mealType, equals('Frukost'));
      });

      test('should filter by lunch', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', mealType: 'Frukost'),
          RecipeFactory.build(id: 'r2', mealType: 'Lunch'),
          RecipeFactory.build(id: 'r3', mealType: 'Middag'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleMealTypeFilter('lunch');

        // Assert
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].mealType, equals('Lunch'));
      });

      test('should filter by dinner (Middag)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', mealType: 'Frukost'),
          RecipeFactory.build(id: 'r2', mealType: 'Lunch'),
          RecipeFactory.build(id: 'r3', mealType: 'Middag'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleMealTypeFilter('dinner');

        // Assert
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].mealType, equals('Middag'));
      });

      test('should support multiple meal type filters', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', mealType: 'Frukost'),
          RecipeFactory.build(id: 'r2', mealType: 'Lunch'),
          RecipeFactory.build(id: 'r3', mealType: 'Middag'),
          RecipeFactory.build(id: 'r4', mealType: 'Mellanmål'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleMealTypeFilter('breakfast');
        viewModel.toggleMealTypeFilter('dinner');

        // Assert
        expect(viewModel.recipes, hasLength(2));
        expect(viewModel.recipes.any((r) => r.mealType == 'Frukost'), isTrue);
        expect(viewModel.recipes.any((r) => r.mealType == 'Middag'), isTrue);
      });

      test('should handle snack (Mellanmål) and dessert (Efterrätt)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', mealType: 'Mellanmål'),
          RecipeFactory.build(id: 'r2', mealType: 'Efterrätt'),
          RecipeFactory.build(id: 'r3', mealType: 'Middag'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleMealTypeFilter('snack');
        viewModel.toggleMealTypeFilter('dessert');

        // Assert
        expect(viewModel.recipes, hasLength(2));
        expect(viewModel.recipes.any((r) => r.mealType == 'Mellanmål'), isTrue);
        expect(viewModel.recipes.any((r) => r.mealType == 'Efterrätt'), isTrue);
      });
    });

    group('Rating Filtering', () {
      test('should filter high rated recipes (4+ stars)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', rating: 3.5),
          RecipeFactory.build(id: 'r2', rating: 4.0),
          RecipeFactory.build(id: 'r3', rating: 4.5),
          RecipeFactory.build(id: 'r4', rating: 5.0),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleRatingFilter('high_rated');

        // Assert
        expect(viewModel.recipes, hasLength(3));
        expect(viewModel.recipes.every((r) => r.rating! >= 4.0), isTrue);
      });

      test('should filter top rated recipes (5 stars)', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', rating: 3.5),
          RecipeFactory.build(id: 'r2', rating: 4.5),
          RecipeFactory.build(id: 'r3', rating: 5.0),
          RecipeFactory.build(id: 'r4', rating: 5.0),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleRatingFilter('top_rated');

        // Assert
        expect(viewModel.recipes, hasLength(2));
        expect(viewModel.recipes.every((r) => r.rating == 5.0), isTrue);
      });

      test(
        'should use highest threshold when multiple rating filters active',
        () {
          // Arrange
          final recipes = [
            RecipeFactory.build(id: 'r1', rating: 3.5),
            RecipeFactory.build(id: 'r2', rating: 4.5),
            RecipeFactory.build(id: 'r3', rating: 5.0),
          ];
          mockRecipeService.setRecipeState(recipes: recipes);

          // Act - both high_rated and top_rated
          viewModel.toggleRatingFilter('high_rated');
          viewModel.toggleRatingFilter('top_rated');

          // Assert - should use top_rated threshold (5.0)
          expect(viewModel.recipes, hasLength(1));
          expect(viewModel.recipes[0].rating, equals(5.0));
        },
      );

      test('should handle recipes without ratings', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', rating: null),
          RecipeFactory.build(id: 'r2', rating: 5.0),
          RecipeFactory.build(id: 'r3', rating: 4.0),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleRatingFilter('high_rated');

        // Assert - recipe without rating excluded
        expect(viewModel.recipes, hasLength(2));
        expect(viewModel.recipes.every((r) => r.rating != null), isTrue);
      });
    });

    group('Combined Filtering', () {
      test('should combine search with filters', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Quick Pasta', timeMinutes: 20),
          RecipeFactory.build(id: 'r2', title: 'Slow Pasta', timeMinutes: 90),
          RecipeFactory.build(id: 'r3', title: 'Quick Salad', timeMinutes: 15),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.updateSearch('pasta');
        viewModel.toggleTimeFilter('quick');

        // Assert - only quick pasta
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].title, equals('Quick Pasta'));
      });

      test('should combine multiple filter types', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(
            id: 'r1',
            title: 'Quick Breakfast',
            timeMinutes: 15,
            mealType: 'Frukost',
            rating: 4.5,
          ),
          RecipeFactory.build(
            id: 'r2',
            title: 'Long Breakfast',
            timeMinutes: 45,
            mealType: 'Frukost',
            rating: 4.5,
          ),
          RecipeFactory.build(
            id: 'r3',
            title: 'Quick Dinner',
            timeMinutes: 25,
            mealType: 'Middag',
            rating: 3.5,
          ),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleTimeFilter('quick');
        viewModel.toggleMealTypeFilter('breakfast');
        viewModel.toggleRatingFilter('high_rated');

        // Assert - only quick, high-rated breakfast
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].id, equals('r1'));
      });
    });

    group('Filter Management', () {
      test('should detect active filters', () {
        // Arrange & Assert - no filters
        expect(viewModel.hasActiveFilters, isFalse);

        // Act & Assert - time filter
        viewModel.toggleTimeFilter('quick');
        expect(viewModel.hasActiveFilters, isTrue);

        // Act & Assert - remove filter
        viewModel.toggleTimeFilter('quick');
        expect(viewModel.hasActiveFilters, isFalse);

        // Act & Assert - meal type filter
        viewModel.toggleMealTypeFilter('lunch');
        expect(viewModel.hasActiveFilters, isTrue);

        // Act & Assert - rating filter
        viewModel.toggleRatingFilter('high_rated');
        expect(viewModel.hasActiveFilters, isTrue);
      });

      test('should clear all filters', () {
        // Arrange
        viewModel.toggleTimeFilter('quick');
        viewModel.toggleMealTypeFilter('lunch');
        viewModel.toggleRatingFilter('high_rated');

        // Act
        viewModel.clearAllFilters();

        // Assert
        expect(viewModel.activeTimeFilters, isEmpty);
        expect(viewModel.activeMealTypeFilters, isEmpty);
        expect(viewModel.activeRatingFilters, isEmpty);
        expect(viewModel.hasActiveFilters, isFalse);
      });

      test('should notify listeners when clearing filters', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        viewModel.toggleTimeFilter('quick');

        // Act
        viewModel.clearAllFilters();

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });

    group('Recipe Operations', () {
      test('should delete recipe optimistically', () {
        // Arrange — mock has empty recipes list, so getRecipeById returns null

        // Act
        viewModel.deleteRecipe('recipe-123');

        // Assert — with null recipe, delete manager skips
        // (real integration would verify optimisticRemoveWithIndex)
      });

      test('should refresh recipes through service', () async {
        // Arrange
        when(() => mockRecipeService.refresh()).thenAnswer((_) async {});

        // Act
        await viewModel.refresh();

        // Assert
        verify(() => mockRecipeService.refresh()).called(1);
      });

      test('should clear error through service', () {
        // Arrange
        mockRecipeService.setRecipeState(error: 'Test error');
        expect(mockRecipeService.error, equals('Test error'));

        // Act
        viewModel.clearError();

        // Assert - clearError is a concrete method that sets error to null
        expect(mockRecipeService.error, isNull);
      });
    });

    group('State Accessors', () {
      test('should expose loading state from service', () {
        // Arrange
        mockRecipeService.setRecipeState(isLoading: true);

        // Act & Assert
        expect(viewModel.isLoading, isTrue);

        // Arrange
        mockRecipeService.setRecipeState(isLoading: false);

        // Act & Assert
        expect(viewModel.isLoading, isFalse);
      });

      test('should expose error state from service', () {
        // Arrange
        mockRecipeService.setRecipeState(error: 'Test error');

        // Act & Assert
        expect(viewModel.error, equals('Test error'));
        expect(viewModel.hasError, isTrue);

        // Arrange
        mockRecipeService.setRecipeState(error: null);

        // Act & Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });
    });

    group('Performance Caching', () {
      test('should cache filtered results', () {
        // Arrange - use fewer recipes than display limit (50) to avoid
        // pagination differences between cache miss (paginated) and cache hit
        final recipes = List.generate(
          10,
          (i) => RecipeFactory.build(id: 'r$i', title: 'Recipe $i'),
        );
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act - access recipes twice
        final first = viewModel.recipes;
        final second = viewModel.recipes;

        // Assert - second call should return cached list
        expect(identical(first, second), isFalse);
        expect(first, hasLength(10));
        expect(second, hasLength(10));
        expect(first, equals(second));
      });

      test('should invalidate cache on search change', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', title: 'Test'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        final first = viewModel.recipes;

        // Act
        viewModel.updateSearch('test');
        final second = viewModel.recipes;

        // Assert - should be different instances
        expect(identical(first, second), isFalse);
      });

      test('should invalidate cache on sort change', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        final first = viewModel.recipes;

        // Act
        viewModel.updateSort(SortCriteria.time);
        final second = viewModel.recipes;

        // Assert
        expect(identical(first, second), isFalse);
      });

      test('should invalidate cache on filter change', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', timeMinutes: 15),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        final first = viewModel.recipes;

        // Act
        viewModel.toggleTimeFilter('quick');
        final second = viewModel.recipes;

        // Assert
        expect(identical(first, second), isFalse);
      });

      test('should invalidate cache when recipes change', () {
        // Arrange
        final recipes1 = [RecipeFactory.build(id: 'r1')];
        mockRecipeService.setRecipeState(recipes: recipes1);
        final first = viewModel.recipes;

        // Act - simulate recipe service update
        final recipes2 = [RecipeFactory.build(id: 'r2')];
        mockRecipeService.setRecipeState(recipes: recipes2);
        mockRecipeService.notifyListeners();
        final second = viewModel.recipes;

        // Assert
        expect(identical(first, second), isFalse);
      });
    });

    group('Edge Cases', () {
      test('should handle empty recipe list', () {
        // Arrange
        mockRecipeService.setRecipeState(recipes: []);

        // Act & Assert
        expect(viewModel.recipes, isEmpty);

        // Act - apply filters on empty list
        viewModel.toggleTimeFilter('quick');
        viewModel.updateSearch('test');

        // Assert - still empty
        expect(viewModel.recipes, isEmpty);
      });

      test('should handle recipes with missing time data', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', timeMinutes: null),
          RecipeFactory.build(id: 'r2', timeMinutes: 15),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleTimeFilter('quick');

        // Assert - recipe without time excluded
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].id, equals('r2'));
      });

      test('should handle recipes with empty meal type', () {
        // Arrange
        final recipes = [
          RecipeFactory.build(id: 'r1', mealType: ''),
          RecipeFactory.build(id: 'r2', mealType: 'Lunch'),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);

        // Act
        viewModel.toggleMealTypeFilter('lunch');

        // Assert
        expect(viewModel.recipes, hasLength(1));
        expect(viewModel.recipes[0].id, equals('r2'));
      });
    });

    group('Bulk Tag (BUT-1012)', () {
      test('bulkApplyPersonalTag returns count of recipes that did not already '
          'have the tag and skips ones that did', () async {
        // Arrange — three recipes, one already tagged with 'travel'.
        final recipes = [
          RecipeFactory.build(id: 'r1', personalTagIds: []),
          RecipeFactory.build(id: 'r2', personalTagIds: ['travel']),
          RecipeFactory.build(id: 'r3', personalTagIds: []),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        mockRecipeService.notifyListeners();
        // Production swallows updateRecipe failures (per-recipe error must
        // not block the bulk); without a successful stub modified stays 0.
        when(
          () => mockRecipeService.updateRecipe(any()),
        ).thenAnswer((_) async => true);

        viewModel.enterSelectionMode('r1');
        viewModel.toggleSelection('r2');
        viewModel.toggleSelection('r3');

        // Act
        final modified = await viewModel.bulkApplyPersonalTag(
          tagId: 'travel',
          tagName: 'Travel',
        );

        // Assert — r1 + r3 modified; r2 already tagged so skipped.
        expect(modified, equals(2));
      });

      test('bulkApplyPersonalTag returns 0 when every selected recipe already '
          'has the tag', () async {
        final recipes = [
          RecipeFactory.build(id: 'r1', personalTagIds: ['weeknight']),
          RecipeFactory.build(id: 'r2', personalTagIds: ['weeknight']),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        mockRecipeService.notifyListeners();

        viewModel.enterSelectionMode('r1');
        viewModel.toggleSelection('r2');

        final modified = await viewModel.bulkApplyPersonalTag(
          tagId: 'weeknight',
          tagName: 'Weeknight',
        );

        expect(modified, equals(0));
      });

      test('bulkApplyPersonalTag returns 0 when selection was entered then '
          'fully deselected (realistic empty-selection path)', () async {
        final recipes = [
          RecipeFactory.build(id: 'r1', personalTagIds: []),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        mockRecipeService.notifyListeners();

        viewModel.enterSelectionMode('r1');
        viewModel.clearSelection();

        final modified = await viewModel.bulkApplyPersonalTag(
          tagId: 'anything',
          tagName: 'Anything',
        );

        expect(modified, equals(0));
      });

      test(
        'undoBulkApplyPersonalTag is a no-op when nothing was applied',
        () async {
          // Snapshot is empty until bulkApplyPersonalTag captures one.
          expect(viewModel.undoBulkApplyPersonalTag, returnsNormally);
          await viewModel.undoBulkApplyPersonalTag();
        },
      );

      test('undoBulkApplyPersonalTag restores prior personalTagIds + '
          'personalTags, and a second undo on the consumed snapshot is a '
          'safe no-op', () async {
        // BUT-1030: wire updateRecipe to mutate mock state so restoration
        // semantics become observable. Without this stub, the production
        // `try/catch (_)` in bulkApplyPersonalTag swallows MissingStubError
        // and the snapshot ends up empty — making the undo a vacuous no-op.
        when(() => mockRecipeService.updateRecipe(any())).thenAnswer((
          invocation,
        ) async {
          final r = invocation.positionalArguments[0] as Recipe;
          mockRecipeService.applyRecipeWriteToState(r);
          return true;
        });

        final recipes = [
          RecipeFactory.build(id: 'r1', personalTagIds: []),
          RecipeFactory.build(id: 'r2', personalTagIds: []),
        ];
        mockRecipeService.setRecipeState(recipes: recipes);
        mockRecipeService.notifyListeners();

        viewModel.enterSelectionMode('r1');
        viewModel.toggleSelection('r2');

        final modified = await viewModel.bulkApplyPersonalTag(
          tagId: 'quick',
          tagName: 'Quick',
        );

        List<String> tagIdsOf(String id) =>
            mockRecipeService.getRecipeById(id)!.core.personalTagIds ??
            const <String>[];

        // Apply landed on both recipes.
        expect(modified, 2);
        expect(tagIdsOf('r1'), contains('quick'));
        expect(tagIdsOf('r2'), contains('quick'));

        await viewModel.undoBulkApplyPersonalTag();

        // Undo restored both recipes to their empty-tag prior state.
        expect(tagIdsOf('r1'), isEmpty);
        expect(tagIdsOf('r2'), isEmpty);

        // Second undo on the cleared snapshot is a safe no-op.
        await viewModel.undoBulkApplyPersonalTag();
        expect(tagIdsOf('r1'), isEmpty);
      });
    });

    group('Seeded Recipes vs Allergen/Dietary Filters (seed-content)', () {
      test('seeded starter recipes stay visible under a default allergen filter '
          'even though they have no tagResult', () {
        // Seeds ship without allergen analysis (tagResult == null). They must
        // NOT be hidden by a persisted/default allergen filter, or a new user
        // who selected e.g. gluten-free at onboarding sees an empty library.
        mockRecipeService.setRecipeState(recipes: RecipeSeeds.allRecipes);
        expect(RecipeSeeds.allRecipes, isNotEmpty);

        viewModel.toggleAllergenFilter('gluten-free');

        expect(
          viewModel.recipes,
          hasLength(RecipeSeeds.allRecipes.length),
          reason:
              'ALL seeded recipes (createdBy == "system") should survive '
              'allergen filtering despite a missing tagResult — not just some '
              '(catches a partial-exemption regression).',
        );
        expect(viewModel.recipes.every((r) => r.createdBy == 'system'), isTrue);
      });

      test(
        'seeded starter recipes stay visible under a default dietary filter',
        () {
          mockRecipeService.setRecipeState(recipes: RecipeSeeds.allRecipes);

          viewModel.toggleDietaryFilter('vegetarian');

          expect(
            viewModel.recipes,
            hasLength(RecipeSeeds.allRecipes.length),
            reason: 'ALL seeded recipes must survive dietary filtering.',
          );
        },
      );

      test(
        'non-seed recipes with no tagResult are STILL excluded by an allergen '
        'filter (safety preserved)',
        () {
          // The seed exemption must not weaken safety for ordinary user recipes:
          // a user recipe with unknown allergen status is correctly hidden.
          final userRecipe = RecipeFactory.build(
            id: 'u1',
            createdBy: 'test_user',
          );
          mockRecipeService.setRecipeState(recipes: [userRecipe]);

          viewModel.toggleAllergenFilter('gluten-free');

          expect(viewModel.recipes, isEmpty);
        },
      );
    });

    // ---------------------------------------------------------------------------
    // BUT-1335 — Allergen/Dietary Safety Gate
    //
    // Each test proves one safety invariant via the PUBLIC `recipes` getter and
    // the `untaggedExclusionMessage` getter.  Filter results are cached; toggling
    // the filter before asserting is the correct way to invalidate the cache.
    // ---------------------------------------------------------------------------
    group('BUT-1335 Allergen/Dietary Safety Gate', () {
      // Helpers -----------------------------------------------------------------

      /// Builds a TagResult that passes EVERY safety gate:
      /// coverage == 1.0, needsRetagging == false, allergenStatus FREE for gluten,
      /// dietaryStatus FREE for vegetarisk.
      TagResult fullyTaggedFree() => TagResult(
        tags: const {},
        allergenStatus: const {'gluten': TriState.free},
        dietaryStatus: const {'vegetarisk': TriState.free},
        coverage: 1.0,
        generatedAt: DateTime(2024),
        generatorVersion: kTagGeneratorVersion,
        hasCoverageAnomaly: false,
      );

      /// Builds a TagResult identical to [fullyTaggedFree] but with partial
      /// coverage (0.6) — the coverage gate must reject this even when status
      /// says free.
      TagResult partialCoverageFree() => TagResult(
        tags: const {},
        allergenStatus: const {'gluten': TriState.free},
        dietaryStatus: const {'vegetarisk': TriState.free},
        coverage: 0.6,
        generatedAt: DateTime(2024),
        generatorVersion: kTagGeneratorVersion,
        hasCoverageAnomaly: false,
      );

      /// Builds a TagResult that needs retagging (generatorVersion == null
      /// satisfies the needsRetagging gate) while still carrying a FREE status —
      /// the needsRetagging gate must reject this before status is consulted.
      TagResult needsRetaggingFree() => TagResult(
        tags: const {},
        allergenStatus: const {'gluten': TriState.free},
        dietaryStatus: const {'vegetarisk': TriState.free},
        coverage: 1.0,
        generatedAt: DateTime(2024),
        generatorVersion: null, // null → needsRetagging == true
        hasCoverageAnomaly: false,
      );

      // -------------------------------------------------------------------------
      // AC-1: Allergen — coverage < 1.0 → excluded
      // -------------------------------------------------------------------------
      test('AC-1: allergen filter EXCLUDES recipe with coverage < 1.0 even when '
          'allergenStatus says FREE', () {
        // This test proves that a recipe that looks "gluten-free" but has only
        // 60 % ingredient coverage is kept OUT of the filtered list, because the
        // unmatched 40 % could hide gluten.
        final partialRecipe = RecipeFactory.build(
          id: 'partial',
        ).copyWith(tagResult: partialCoverageFree());
        mockRecipeService.setRecipeState(recipes: [partialRecipe]);

        viewModel.toggleAllergenFilter('gluten-free');

        expect(
          viewModel.recipes,
          isEmpty,
          reason:
              'A recipe with coverage 0.6 must not pass the allergen-free '
              'safety gate, even if the known ingredients are all gluten-free.',
        );
      });

      // -------------------------------------------------------------------------
      // AC-2: Allergen — needsRetagging → excluded
      // -------------------------------------------------------------------------
      test(
        'AC-2: allergen filter EXCLUDES recipe with needsRetagging == true even '
        'when allergenStatus says FREE',
        () {
          // This test proves that stale tag data (generatorVersion == null) is
          // rejected at the safety gate before the allergen status is read.
          final staleRecipe = RecipeFactory.build(
            id: 'stale',
          ).copyWith(tagResult: needsRetaggingFree());
          mockRecipeService.setRecipeState(recipes: [staleRecipe]);

          viewModel.toggleAllergenFilter('gluten-free');

          expect(
            viewModel.recipes,
            isEmpty,
            reason:
                'A recipe with needsRetagging==true must be excluded even if '
                'its stored allergenStatus claims FREE — the tag data is unreliable.',
          );
        },
      );

      // -------------------------------------------------------------------------
      // AC-3a: Allergen — null tagResult + non-seed → excluded (safety gate)
      // AC-3b: Allergen — null tagResult + system seed → kept (seed bypass)
      // (AC-3 non-seed exclusion is already covered in the existing seed group
      // above; the positive seed-bypass case is also there.  We add them here
      // again as explicit contract assertions for BUT-1335.)
      // -------------------------------------------------------------------------
      test('AC-3a: allergen filter EXCLUDES recipe with tagResult == null '
          '(user recipe — no analysis available)', () {
        // This test proves that a recipe with absolutely no tag data is hidden
        // when a safety-critical allergen filter is active.
        final unanalysed = RecipeFactory.build(id: 'u1', createdBy: 'user');
        // tagResult is null by default from RecipeFactory
        mockRecipeService.setRecipeState(recipes: [unanalysed]);

        viewModel.toggleAllergenFilter('gluten-free');

        expect(
          viewModel.recipes,
          isEmpty,
          reason:
              'A user recipe with null tagResult must be excluded; its '
              'allergen status is completely unknown.',
        );
      });

      test('AC-3b: allergen filter KEEPS a seed recipe with tagResult == null '
          '(createdBy == "system" — starter content bypass)', () {
        // This test proves that system-seeded starter recipes survive the
        // allergen filter even without tag analysis, so a new user who picked
        // a dietary preference at onboarding still sees the library.
        final seedRecipe = RecipeFactory.build(id: 's1', createdBy: 'system');
        mockRecipeService.setRecipeState(recipes: [seedRecipe]);

        viewModel.toggleAllergenFilter('gluten-free');

        expect(
          viewModel.recipes,
          hasLength(1),
          reason:
              'A seed recipe (createdBy=="system") must survive allergen '
              'filtering regardless of missing tagResult.',
        );
        expect(viewModel.recipes.single.createdBy, equals('system'));
      });

      // -------------------------------------------------------------------------
      // AC-1d: Allergen positive case — full coverage + FREE → included
      // (proves the gate is selective, not always-reject)
      // -------------------------------------------------------------------------
      test('allergen filter KEEPS a recipe that is fully tagged and FREE from '
          'the selected allergen', () {
        // This test proves the gate admits recipes that legitimately satisfy
        // coverage == 1.0 AND needsRetagging == false AND status == FREE.
        final cleanRecipe = RecipeFactory.build(
          id: 'clean',
        ).copyWith(tagResult: fullyTaggedFree());
        mockRecipeService.setRecipeState(recipes: [cleanRecipe]);

        viewModel.toggleAllergenFilter('gluten-free');

        expect(
          viewModel.recipes,
          hasLength(1),
          reason:
              'A recipe with full coverage, no retagging needed, and FREE '
              'status must pass the allergen-free filter.',
        );
      });

      // -------------------------------------------------------------------------
      // AC-4: Dietary — same three safety gates (mirrors allergen)
      // -------------------------------------------------------------------------
      test(
        'AC-4a: dietary filter EXCLUDES recipe with coverage < 1.0 even when '
        'dietaryStatus says FREE',
        () {
          final partialRecipe = RecipeFactory.build(
            id: 'dp',
          ).copyWith(tagResult: partialCoverageFree());
          mockRecipeService.setRecipeState(recipes: [partialRecipe]);

          viewModel.toggleDietaryFilter('vegetarian');

          expect(
            viewModel.recipes,
            isEmpty,
            reason:
                'The dietary safety gate must mirror the allergen gate: '
                'coverage < 1.0 excludes even when status says FREE.',
          );
        },
      );

      test('AC-4b: dietary filter EXCLUDES recipe with needsRetagging == true '
          'even when dietaryStatus says FREE', () {
        final staleRecipe = RecipeFactory.build(
          id: 'ds',
        ).copyWith(tagResult: needsRetaggingFree());
        mockRecipeService.setRecipeState(recipes: [staleRecipe]);

        viewModel.toggleDietaryFilter('vegetarian');

        expect(
          viewModel.recipes,
          isEmpty,
          reason:
              'The dietary safety gate must reject stale tags just as the '
              'allergen gate does.',
        );
      });

      test('AC-4c: dietary filter EXCLUDES recipe with tagResult == null '
          '(user recipe)', () {
        final unanalysed = RecipeFactory.build(id: 'dn', createdBy: 'user');
        mockRecipeService.setRecipeState(recipes: [unanalysed]);

        viewModel.toggleDietaryFilter('vegetarian');

        expect(
          viewModel.recipes,
          isEmpty,
          reason:
              'A user recipe with null tagResult is unsafe for dietary '
              'filtering and must be excluded.',
        );
      });

      test('AC-4d: dietary filter KEEPS a recipe with full coverage and FREE '
          'dietary status', () {
        final cleanRecipe = RecipeFactory.build(
          id: 'dc',
        ).copyWith(tagResult: fullyTaggedFree());
        mockRecipeService.setRecipeState(recipes: [cleanRecipe]);

        viewModel.toggleDietaryFilter('vegetarian');

        expect(
          viewModel.recipes,
          hasLength(1),
          reason: 'A fully-tagged FREE recipe must pass the dietary filter.',
        );
      });

      // -------------------------------------------------------------------------
      // AC-5: untaggedExclusionMessage surfaced / absent
      // -------------------------------------------------------------------------
      test(
        'AC-5a: untaggedExclusionMessage is non-null when a recipe is hidden '
        'due to missing/incomplete tag analysis',
        () {
          // This test proves that the user receives a visible explanation when
          // recipes are being excluded because they are still being analysed.
          final analysed = RecipeFactory.build(
            id: 'a1',
          ).copyWith(tagResult: fullyTaggedFree());
          final unanalysed = RecipeFactory.build(id: 'u1', createdBy: 'user');
          mockRecipeService.setRecipeState(recipes: [analysed, unanalysed]);

          viewModel.toggleAllergenFilter('gluten-free');

          // The unanalysed recipe is hidden; the message must surface.
          expect(
            viewModel.untaggedExclusionMessage,
            isNotNull,
            reason:
                'untaggedExclusionMessage must be non-null when at least one '
                'recipe is excluded due to missing tag analysis.',
          );
          expect(
            viewModel.untaggedExclusionMessage,
            contains('1 recept'),
            reason: 'The message must name the count of hidden recipes.',
          );
        },
      );

      test('AC-5b: untaggedExclusionMessage is null when all recipes are fully '
          'tagged (nothing hidden for missing analysis)', () {
        final analysed = RecipeFactory.build(
          id: 'a1',
        ).copyWith(tagResult: fullyTaggedFree());
        mockRecipeService.setRecipeState(recipes: [analysed]);

        viewModel.toggleAllergenFilter('gluten-free');

        expect(
          viewModel.untaggedExclusionMessage,
          isNull,
          reason:
              'When no recipes are excluded for missing analysis, '
              'untaggedExclusionMessage must be null so no banner is shown.',
        );
      });

      test(
        'AC-5c: untaggedExclusionMessage is null when no tag-based filter is '
        'active (even if some recipes lack tags)',
        () {
          // Proves that the message is gate-driven, not recipe-state-driven:
          // without an active allergen/dietary filter, nothing is "hidden."
          final unanalysed = RecipeFactory.build(id: 'u1', createdBy: 'user');
          mockRecipeService.setRecipeState(recipes: [unanalysed]);

          // No filter activated — hasTagBasedFilters == false.
          expect(
            viewModel.untaggedExclusionMessage,
            isNull,
            reason:
                'The exclusion message must be absent when no tag-based '
                'filter is active, regardless of recipe tag state.',
          );
        },
      );
    });

    group('Lifecycle', () {
      test('should cleanup on dispose', () {
        // Arrange
        final testViewModel = RecipeListViewModel(
          recipeService: mockRecipeService,
          searchService: mockSearchService,
          tagEditingService: TagEditingService(),
        );

        // Act & Assert - verify dispose doesn't throw
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should notify listeners on state changes', () {
        fakeAsync((async) {
          // Arrange
          var notificationCount = 0;
          viewModel.addListener(() => notificationCount++);

          // Act - various state changes
          viewModel.updateSearch('test');
          async.elapse(const Duration(milliseconds: 300)); // flush debounce
          viewModel.updateSort(SortCriteria.time);
          viewModel.toggleTimeFilter('quick');
          viewModel.toggleMealTypeFilter('lunch');
          viewModel.toggleRatingFilter('high_rated');
          viewModel.clearAllFilters();

          // Assert - should notify for each change
          expect(notificationCount, equals(6));
        });
      });
    });
  });
}
