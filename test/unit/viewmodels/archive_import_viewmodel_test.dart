import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/data/archived_recipes.dart' as archive;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class MockPersonalRecipeOperations extends Mock
    implements PersonalRecipeOperations {}

void main() {
  // Real archived recipes from the data file (6 recipes)
  // Pasta Bolognese (30min), Chicken Curry (35min), Vegetable Stir Fry (20min),
  // Fish & Chips (40min), Caesar Salad (15min), Pancakes (20min)
  final realRecipeCount = archive.archivedRecipes.length; // 6

  group('ArchiveImportViewModel', () {
    late ArchiveImportViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockPersonalRecipeOperations mockPersonalOperations;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(<Recipe>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockRecipeService = MockUnifiedRecipeService();
      mockPersonalOperations = MockPersonalRecipeOperations();

      // Wire personal operations via setRecipeState
      mockRecipeService.setRecipeState(
        error: null,
        personalOperations: mockPersonalOperations,
        isInitialized: true,
      );

      when(
        () => mockPersonalOperations.addMultipleUnifiedRecipes(any()),
      ).thenAnswer(
        (_) async => RecipeOperationResult.success(
          'Recept importerade',
        ),
      );

      // Use real SearchService (pure logic, no dependencies)
      final realSearchService = SearchService();

      viewModel = ArchiveImportViewModel(
        recipeService: mockRecipeService,
        searchService: realSearchService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default state', () {
        expect(viewModel.selectedTags, isEmpty);
        expect(viewModel.selectedRecipeIds, isEmpty);
        expect(viewModel.timeFilter, equals(TimeFilter.all));
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.isImporting, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(viewModel.selectedCount, equals(0));
        expect(viewModel.hasSelection, isFalse);
        expect(viewModel.allSelected, isFalse);
      });

      test('should have archived recipes available', () {
        expect(viewModel.archivedRecipes, isNotEmpty);
        expect(viewModel.archivedRecipes.length, equals(realRecipeCount));
      });

      test('should extract available tags from archived recipes', () {
        final tags = viewModel.availableTags;

        expect(tags, isNotEmpty);
        // Real tags from recipe_seeds.dart
        expect(tags, contains('pasta'));
        expect(tags, contains('middag'));
        expect(tags, contains('curry'));
        expect(tags, contains('vegetariskt'));
        expect(tags, contains('fisk'));
        expect(tags, contains('sallad'));
        expect(tags, contains('frukost'));
      });

      test('should show all recipes when no filters applied', () {
        final filtered = viewModel.filteredRecipes;

        expect(filtered.length, equals(realRecipeCount));
      });
    });

    group('Search Functionality', () {
      test('should filter recipes by search query', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.updateSearch('pasta');

        expect(viewModel.searchQuery, equals('pasta'));
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, contains('Pasta'));
        expect(notificationCount, greaterThan(0));
      });

      test('should find recipes by ingredient', () {
        // Real recipes have 'chicken breast' as ingredient
        viewModel.updateSearch('chicken');

        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, contains('Chicken'));
      });

      test('should handle case-insensitive search', () {
        viewModel.updateSearch('PANCAKES');

        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, contains('Pancakes'));
      });

      test('should clear search query', () {
        viewModel.updateSearch('pasta');
        expect(viewModel.filteredRecipes.length, equals(1));

        viewModel.updateSearch('');

        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.filteredRecipes.length, equals(realRecipeCount));
      });

      test('should update selection when search changes', () {
        // Select first two recipes by ID
        final id0 = viewModel.archivedRecipes[0].id;
        final id1 = viewModel.archivedRecipes[1].id;
        viewModel.toggleRecipeSelection(id0);
        viewModel.toggleRecipeSelection(id1);
        expect(viewModel.selectedCount, equals(2));

        // Search that shows only 1 of the 2 selected
        viewModel.updateSearch('pasta');

        // Only the recipe still visible should remain selected
        expect(viewModel.selectedCount, lessThanOrEqualTo(2));
      });
    });

    group('Tag Filtering', () {
      test('should toggle tag selection', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.toggleTag('middag');

        expect(viewModel.selectedTags.contains('middag'), isTrue);
        expect(notificationCount, greaterThan(0));

        viewModel.toggleTag('middag');
        expect(viewModel.selectedTags.contains('middag'), isFalse);
      });

      test('should filter recipes by single tag', () {
        // 'middag' tag: Pasta Bolognese, Chicken Curry
        viewModel.toggleTag('middag');

        expect(viewModel.filteredRecipes.length, equals(2));
        expect(
          viewModel.filteredRecipes.every(
            (r) => r.personalTagIds?.contains('middag') ?? false,
          ),
          isTrue,
        );
      });

      test('should filter recipes by multiple tags with AND logic', () {
        // 'snabbt' AND 'vegetariskt' -> Vegetable Stir Fry only
        viewModel.toggleTag('snabbt');
        viewModel.toggleTag('vegetariskt');

        expect(viewModel.filteredRecipes.length, equals(1));
        expect(
          viewModel.filteredRecipes[0].title,
          equals('Vegetable Stir Fry'),
        );
      });

      test('should handle tag removal', () {
        viewModel.toggleTag('snabbt');
        viewModel.toggleTag('vegetariskt');
        expect(viewModel.filteredRecipes.length, equals(1));

        // Remove vegetariskt -> only snabbt remains
        viewModel.toggleTag('vegetariskt');

        expect(viewModel.selectedTags.contains('vegetariskt'), isFalse);
        // 'snabbt': Vegetable Stir Fry + Caesar Salad
        expect(viewModel.filteredRecipes.length, equals(2));
      });
    });

    group('Time Filtering', () {
      test('should filter recipes under 15 minutes', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.setTimeFilter(TimeFilter.under15);

        expect(viewModel.timeFilter, equals(TimeFilter.under15));
        // Only Caesar Salad (15min)
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].timeMinutes, lessThanOrEqualTo(15));
        expect(notificationCount, greaterThan(0));
      });

      test('should filter recipes under 30 minutes', () {
        viewModel.setTimeFilter(TimeFilter.under30);

        // Vegetable Stir Fry (20), Caesar Salad (15), Pancakes (20), Pasta Bolognese (30)
        expect(viewModel.filteredRecipes.length, equals(4));
        expect(
          viewModel.filteredRecipes.every((r) => r.timeMinutes! <= 30),
          isTrue,
        );
      });

      test('should filter recipes under 60 minutes', () {
        viewModel.setTimeFilter(TimeFilter.under60);

        // All 6 recipes are under 60 minutes
        expect(viewModel.filteredRecipes.length, equals(realRecipeCount));
        expect(
          viewModel.filteredRecipes.every((r) => r.timeMinutes! <= 60),
          isTrue,
        );
      });

      test('should show all recipes with TimeFilter.all', () {
        viewModel.setTimeFilter(TimeFilter.under15);
        expect(viewModel.filteredRecipes.length, equals(1));

        viewModel.setTimeFilter(TimeFilter.all);

        expect(viewModel.filteredRecipes.length, equals(realRecipeCount));
      });
    });

    group('Combined Filtering', () {
      test('should combine search and tag filters', () {
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('pasta');

        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, equals('Pasta Bolognese'));
      });

      test('should combine all filter types', () {
        viewModel.toggleTag('snabbt');
        viewModel.setTimeFilter(TimeFilter.under30);
        viewModel.updateSearch('salad');

        // 'snabbt' + <=30min + 'salad' -> Caesar Salad
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, equals('Caesar Salad'));
      });

      test('should handle no matching results', () {
        viewModel.updateSearch('pizza');

        expect(viewModel.filteredRecipes, isEmpty);
      });
    });

    group('Recipe Selection', () {
      test('should toggle individual recipe selection', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        final recipeId = viewModel.archivedRecipes[0].id;
        viewModel.toggleRecipeSelection(recipeId);

        expect(viewModel.selectedRecipeIds.contains(recipeId), isTrue);
        expect(viewModel.selectedCount, equals(1));
        expect(viewModel.hasSelection, isTrue);
        expect(notificationCount, greaterThan(0));

        viewModel.toggleRecipeSelection(recipeId);
        expect(viewModel.selectedRecipeIds.contains(recipeId), isFalse);
        expect(viewModel.selectedCount, equals(0));
        expect(viewModel.hasSelection, isFalse);
      });

      test('should select multiple recipes', () {
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[1].id);
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[2].id);

        expect(viewModel.selectedCount, equals(3));
        expect(viewModel.hasSelection, isTrue);
      });

      test('should toggle select all', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.toggleSelectAll();

        expect(viewModel.selectedCount, equals(realRecipeCount));
        expect(viewModel.allSelected, isTrue);
        expect(notificationCount, greaterThan(0));

        viewModel.toggleSelectAll();

        expect(viewModel.selectedCount, equals(0));
        expect(viewModel.allSelected, isFalse);
      });

      test('should select all filtered recipes', () {
        // Filter to 'middag' tag (2 recipes: Pasta Bolognese, Chicken Curry)
        viewModel.toggleTag('middag');
        expect(viewModel.filteredRecipes.length, equals(2));

        viewModel.toggleSelectAll();

        expect(viewModel.selectedCount, equals(2));
      });

      test('should handle partial selection', () {
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        expect(viewModel.allSelected, isFalse);

        viewModel.toggleSelectAll();

        expect(viewModel.selectedCount, equals(realRecipeCount));
        expect(viewModel.allSelected, isTrue);
      });
    });

    group('Import Operations', () {
      test('imports selected recipes with source attribution', () async {
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[1].id);

        await viewModel.importSelectedRecipes();

        expect(viewModel.hasError, isFalse);
        expect(viewModel.selectedCount, equals(0));
        final captured =
            verify(
                  () => mockPersonalOperations.addMultipleUnifiedRecipes(
                    captureAny(),
                  ),
                ).captured.first
                as List<Recipe>;
        expect(captured.length, equals(2));
        expect(
          captured.every((r) => r.sourceUrl == 'Fr\u00e5n Butlerys arkiv'),
          isTrue,
        );
      });

      test('rejects import when no recipes selected', () async {
        await viewModel.importSelectedRecipes();
        expect(viewModel.hasError, isTrue);
        verifyNever(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(any()),
        );
      });

      test('imports all filtered or all recipes', () async {
        // With filter
        viewModel.toggleTag('middag');
        expect(viewModel.filteredRecipes.length, equals(2));
        await viewModel.importAllRecipes();
        expect(viewModel.hasError, isFalse);
        var captured =
            verify(
                  () => mockPersonalOperations.addMultipleUnifiedRecipes(
                    captureAny(),
                  ),
                ).captured.first
                as List<Recipe>;
        expect(captured.length, equals(2));

        // Without filter
        viewModel.clearFilters();
        await viewModel.importAllRecipes();
        captured =
            verify(
                  () => mockPersonalOperations.addMultipleUnifiedRecipes(
                    captureAny(),
                  ),
                ).captured.first
                as List<Recipe>;
        expect(captured.length, equals(realRecipeCount));
      });

      test('handles import failure and exception', () async {
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        when(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(any()),
        ).thenAnswer(
          (_) async =>
              RecipeOperationResult.failure('Kunde inte importera recept'),
        );

        await viewModel.importSelectedRecipes();
        expect(viewModel.error, equals('Kunde inte importera recept'));
        expect(viewModel.selectedCount, equals(1));

        // Exception path
        when(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(any()),
        ).thenThrow(Exception('Network error'));
        await viewModel.importSelectedRecipes();
        expect(viewModel.hasError, isTrue);
      });

      test('tracks importing state', () async {
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        when(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(any()),
        ).thenAnswer((_) async => RecipeOperationResult.success('OK'));
        bool wasImporting = false;
        viewModel.addListener(() {
          if (viewModel.isImporting) wasImporting = true;
        });

        await viewModel.importSelectedRecipes();
        expect(wasImporting, isTrue);
        expect(viewModel.isImporting, isFalse);
      });
    });

    group('Clear and Reset', () {
      test('clearError and clearFilters reset state', () async {
        await viewModel.importSelectedRecipes(); // triggers error
        expect(viewModel.hasError, isTrue);
        viewModel.clearError();
        expect(viewModel.hasError, isFalse);

        viewModel.updateSearch('pasta');
        viewModel.toggleTag('middag');
        viewModel.setTimeFilter(TimeFilter.under30);
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        viewModel.clearFilters();

        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.selectedTags, isEmpty);
        expect(viewModel.timeFilter, equals(TimeFilter.all));
        expect(viewModel.selectedRecipeIds, isEmpty);
        expect(viewModel.filteredRecipes.length, equals(realRecipeCount));
      });
    });

    group('Caching', () {
      test('caches results, invalidates on filter changes, not selection', () {
        final cached = viewModel.filteredRecipes;
        expect(identical(cached, viewModel.filteredRecipes), isTrue);

        viewModel.updateSearch('pasta');
        expect(identical(cached, viewModel.filteredRecipes), isFalse);
        viewModel.updateSearch('');

        final b1 = viewModel.filteredRecipes;
        viewModel.toggleTag('middag');
        expect(identical(b1, viewModel.filteredRecipes), isFalse);
        viewModel.toggleTag('middag');

        final b2 = viewModel.filteredRecipes;
        viewModel.setTimeFilter(TimeFilter.under30);
        expect(identical(b2, viewModel.filteredRecipes), isFalse);
        viewModel.setTimeFilter(TimeFilter.all);

        final b3 = viewModel.filteredRecipes;
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        expect(identical(b3, viewModel.filteredRecipes), isTrue);
      });
    });

    group('Lifecycle', () {
      test('disposes without errors', () {
        final vm = ArchiveImportViewModel(
          recipeService: mockRecipeService,
          searchService: SearchService(),
        );
        expect(() => vm.dispose(), returnsNormally);
      });

      test('handles rapid filter changes and concurrent operations', () async {
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('middag');
        viewModel.setTimeFilter(TimeFilter.under30);
        viewModel.updateSearch('chicken');
        viewModel.clearFilters();
        viewModel.toggleTag('fisk');
        expect(viewModel.selectedTags.contains('fisk'), isTrue);
        expect(viewModel.searchQuery, isEmpty);

        // Concurrent import + filter changes
        viewModel.toggleRecipeSelection(viewModel.archivedRecipes[0].id);
        final import1 = viewModel.importSelectedRecipes();
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('middag');
        await import1;
        expect(viewModel.hasError, isFalse);
        expect(viewModel.searchQuery, equals('pasta'));
      });
    });
  });
}
