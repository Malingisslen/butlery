import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Using centralized MockUnifiedRecipeService from production_mocks.dart

// Using local mock patterns that follow centralized architecture 
// TODO: Resolve import issue with centralized mocks in future cleanup
class MockPersonalRecipeOperations extends Mock implements PersonalRecipeOperations {}
class MockSearchService extends Mock implements SearchService {}

// Test data builder for archived recipes
class ArchivedRecipeBuilder {
  static List<Recipe> buildArchivedRecipes() {
    return [
      RecipeFactory.build(
        id: 'archive_1',
        title: 'Vegetarisk Pasta',
        description: 'Krämig pastarätt med grönsaker',
        ingredients: ['400g pasta', '2 dl grädde', '1 zucchini', '1 paprika'],
        instructions: ['Koka pasta', 'Stek grönsaker', 'Blanda med grädde'],
        tags: ['vegetarisk', 'pasta', 'enkel'],
        timeMinutes: 25,
        mealType: 'Middag',
      ),
      RecipeFactory.build(
        id: 'archive_2',
        title: 'Köttbullar med potatismos',
        description: 'Klassiska svenska köttbullar',
        ingredients: ['500g köttfärs', '1 ägg', '1 kg potatis', '3 dl mjölk'],
        instructions: ['Forma köttbullar', 'Stek i panna', 'Koka potatis', 'Mosa med mjölk'],
        tags: ['kött', 'svensk', 'klassisk'],
        timeMinutes: 45,
        mealType: 'Middag',
      ),
      RecipeFactory.build(
        id: 'archive_3',
        title: 'Snabb sallad',
        description: 'Fräsch och snabb sallad',
        ingredients: ['Salladsblad', 'Tomat', 'Gurka', 'Dressing'],
        instructions: ['Skär grönsaker', 'Blanda i skål', 'Tillsätt dressing'],
        tags: ['vegetarisk', 'sallad', 'snabb'],
        timeMinutes: 10,
        mealType: 'Lunch',
      ),
      RecipeFactory.build(
        id: 'archive_4',
        title: 'Laxfilé med dillsås',
        description: 'Ugnsbakad lax med hemgjord dillsås',
        ingredients: ['4 laxfiléer', '2 dl gräddfil', 'Färsk dill', 'Citron'],
        instructions: ['Baka lax i ugn', 'Blanda dillsås', 'Servera med potatis'],
        tags: ['fisk', 'hälsosam', 'nordisk'],
        timeMinutes: 35,
        mealType: 'Middag',
      ),
      RecipeFactory.build(
        id: 'archive_5',
        title: 'Pannkakor',
        description: 'Tunna svenska pannkakor',
        ingredients: ['3 ägg', '3 dl mjölk', '2 dl vetemjöl', '1 tsk salt'],
        instructions: ['Vispa smet', 'Stek tunna pannkakor', 'Servera med sylt'],
        tags: ['frukost', 'enkel', 'svensk'],
        timeMinutes: 20,
        mealType: 'Frukost',
      ),
    ];
  }
}

void main() {
  group('ArchiveImportViewModel', () {
    late ArchiveImportViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late MockPersonalRecipeOperations mockPersonalOperations;
    late MockSearchService mockSearchService;
    late List<Recipe> testArchivedRecipes;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeFactory.build());
      registerFallbackValue(<Recipe>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mocks - using centralized MockUnifiedRecipeService
      mockRecipeService = MockUnifiedRecipeService();
      mockPersonalOperations = MockPersonalRecipeOperations();
      mockSearchService = MockSearchService();
      
      // Setup test data
      testArchivedRecipes = ArchivedRecipeBuilder.buildArchivedRecipes();
      
      // Configure mock service operations using enhanced setRecipeState()
      mockRecipeService.setRecipeState(
        error: null,
        personalOperations: mockPersonalOperations,
      );
      
      // Configure PersonalRecipeOperations mock
      when(() => mockPersonalOperations.addMultipleUnifiedRecipes(any()))
          .thenAnswer((_) async => RecipeOperationResult.success(
            'Recept importerade',
          ));
      
      // Configure SearchService mocks
      when(() => mockSearchService.searchRecipes(any(), any()))
          .thenAnswer((invocation) {
            final recipes = invocation.positionalArguments[0] as List<Recipe>;
            final query = invocation.positionalArguments[1] as String;
            final lowerQuery = query.toLowerCase();
            
            return recipes.where((recipe) {
              return recipe.title.toLowerCase().contains(lowerQuery) ||
                     recipe.description.toLowerCase().contains(lowerQuery) ||
                     recipe.ingredients.any((i) => i.toLowerCase().contains(lowerQuery));
            }).toList();
          });
      
      when(() => mockSearchService.filterByTags(any(), any()))
          .thenAnswer((invocation) {
            final recipes = invocation.positionalArguments[0] as List<Recipe>;
            final tags = invocation.positionalArguments[1] as List<String>;
            
            if (tags.isEmpty) return recipes;
            
            // AND logic - recipe must have ALL tags
            return recipes.where((recipe) {
              if (recipe.tags == null || recipe.tags!.isEmpty) return false;
              return tags.every((tag) => recipe.tags!.contains(tag));
            }).toList();
          });
      
      when(() => mockSearchService.filterByMaxTime(any(), any()))
          .thenAnswer((invocation) {
            final recipes = invocation.positionalArguments[0] as List<Recipe>;
            final maxMinutes = invocation.positionalArguments[1] as int?;
            
            if (maxMinutes == null) return recipes;
            
            return recipes.where((recipe) {
              return recipe.timeMinutes != null && recipe.timeMinutes! <= maxMinutes;
            }).toList();
          });
      
      // Create viewModel with mocked archived recipes
      viewModel = _TestableArchiveImportViewModel(
        recipeService: mockRecipeService,
        searchService: mockSearchService,
        testArchivedRecipes: testArchivedRecipes,
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
        // Arrange - viewModel created in setUp
        
        // Act - no action needed, checking initial state
        
        // Assert
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
        // Assert
        expect(viewModel.archivedRecipes, isNotEmpty);
        expect(viewModel.archivedRecipes.length, equals(5));
      });

      test('should extract available tags from archived recipes', () {
        // Act
        final tags = viewModel.availableTags;
        
        // Assert
        expect(tags, isNotEmpty);
        expect(tags, contains('vegetarisk'));
        expect(tags, contains('pasta'));
        expect(tags, contains('kött'));
        expect(tags, contains('svensk'));
        expect(tags, contains('fisk'));
        expect(tags, contains('sallad'));
      });

      test('should show all recipes when no filters applied', () {
        // Act
        final filtered = viewModel.filteredRecipes;
        
        // Assert
        expect(filtered.length, equals(5));
        expect(filtered, equals(testArchivedRecipes));
      });
    });

    group('Search Functionality', () {
      test('should filter recipes by search query', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.updateSearch('pasta');
        
        // Assert
        expect(viewModel.searchQuery, equals('pasta'));
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, contains('Pasta'));
        expect(notificationCount, equals(1));
      });

      test('should find recipes by ingredient', () {
        // Act
        viewModel.updateSearch('lax');
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, contains('Laxfilé'));
      });

      test('should handle case-insensitive search', () {
        // Act
        viewModel.updateSearch('KÖTTBULLAR');
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, contains('Köttbullar'));
      });

      test('should clear search query', () {
        // Arrange
        viewModel.updateSearch('pasta');
        expect(viewModel.filteredRecipes.length, equals(1));
        
        // Act
        viewModel.updateSearch('');
        
        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.filteredRecipes.length, equals(5));
      });

      test('should update selection when search changes', () {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        viewModel.toggleRecipeSelection('archive_2');
        expect(viewModel.selectedCount, equals(2));
        
        // Act - search that excludes archive_2
        viewModel.updateSearch('pasta');
        
        // Assert - archive_2 should be deselected
        expect(viewModel.selectedCount, equals(1));
        expect(viewModel.selectedRecipeIds.contains('archive_1'), isTrue);
        expect(viewModel.selectedRecipeIds.contains('archive_2'), isFalse);
      });
    });

    group('Tag Filtering', () {
      test('should toggle tag selection', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.toggleTag('vegetarisk');
        
        // Assert
        expect(viewModel.selectedTags.contains('vegetarisk'), isTrue);
        expect(notificationCount, equals(1));
        
        // Toggle off
        viewModel.toggleTag('vegetarisk');
        expect(viewModel.selectedTags.contains('vegetarisk'), isFalse);
      });

      test('should filter recipes by single tag', () {
        // Act
        viewModel.toggleTag('vegetarisk');
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(2)); // pasta and sallad
        expect(viewModel.filteredRecipes.every((r) => r.tags?.contains('vegetarisk') ?? false), isTrue);
      });

      test('should filter recipes by multiple tags with AND logic', () {
        // Act
        viewModel.toggleTag('vegetarisk');
        viewModel.toggleTag('snabb');
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(1)); // only sallad
        expect(viewModel.filteredRecipes[0].title, equals('Snabb sallad'));
      });

      test('should handle tag removal', () {
        // Arrange
        viewModel.toggleTag('vegetarisk');
        viewModel.toggleTag('pasta');
        expect(viewModel.filteredRecipes.length, equals(1));
        
        // Act - remove pasta tag
        viewModel.toggleTag('pasta');
        
        // Assert
        expect(viewModel.selectedTags.contains('pasta'), isFalse);
        expect(viewModel.filteredRecipes.length, equals(2)); // vegetarisk only
      });
    });

    group('Time Filtering', () {
      test('should filter recipes under 15 minutes', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.setTimeFilter(TimeFilter.under15);
        
        // Assert
        expect(viewModel.timeFilter, equals(TimeFilter.under15));
        expect(viewModel.filteredRecipes.length, equals(1)); // only sallad
        expect(viewModel.filteredRecipes[0].timeMinutes, lessThanOrEqualTo(15));
        expect(notificationCount, equals(1));
      });

      test('should filter recipes under 30 minutes', () {
        // Act
        viewModel.setTimeFilter(TimeFilter.under30);
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(3)); // pasta, sallad, pannkakor
        expect(viewModel.filteredRecipes.every((r) => r.timeMinutes! <= 30), isTrue);
      });

      test('should filter recipes under 60 minutes', () {
        // Act
        viewModel.setTimeFilter(TimeFilter.under60);
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(5)); // all recipes
        expect(viewModel.filteredRecipes.every((r) => r.timeMinutes! <= 60), isTrue);
      });

      test('should show all recipes with TimeFilter.all', () {
        // Arrange
        viewModel.setTimeFilter(TimeFilter.under15);
        expect(viewModel.filteredRecipes.length, equals(1));
        
        // Act
        viewModel.setTimeFilter(TimeFilter.all);
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(5));
      });
    });

    group('Combined Filtering', () {
      test('should combine search and tag filters', () {
        // Act
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('vegetarisk');
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, equals('Vegetarisk Pasta'));
      });

      test('should combine all filter types', () {
        // Act
        viewModel.toggleTag('vegetarisk');
        viewModel.setTimeFilter(TimeFilter.under30);
        viewModel.updateSearch('snabb');
        
        // Assert
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes[0].title, equals('Snabb sallad'));
      });

      test('should handle no matching results', () {
        // Act
        viewModel.updateSearch('pizza');
        
        // Assert
        expect(viewModel.filteredRecipes, isEmpty);
      });
    });

    group('Recipe Selection', () {
      test('should toggle individual recipe selection', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.toggleRecipeSelection('archive_1');
        
        // Assert
        expect(viewModel.selectedRecipeIds.contains('archive_1'), isTrue);
        expect(viewModel.selectedCount, equals(1));
        expect(viewModel.hasSelection, isTrue);
        expect(notificationCount, equals(1));
        
        // Toggle off
        viewModel.toggleRecipeSelection('archive_1');
        expect(viewModel.selectedRecipeIds.contains('archive_1'), isFalse);
        expect(viewModel.selectedCount, equals(0));
        expect(viewModel.hasSelection, isFalse);
      });

      test('should select multiple recipes', () {
        // Act
        viewModel.toggleRecipeSelection('archive_1');
        viewModel.toggleRecipeSelection('archive_2');
        viewModel.toggleRecipeSelection('archive_3');
        
        // Assert
        expect(viewModel.selectedCount, equals(3));
        expect(viewModel.hasSelection, isTrue);
      });

      test('should toggle select all', () {
        // Arrange
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act - select all
        viewModel.toggleSelectAll();
        
        // Assert
        expect(viewModel.selectedCount, equals(5));
        expect(viewModel.allSelected, isTrue);
        expect(notificationCount, equals(1));
        
        // Act - deselect all
        viewModel.toggleSelectAll();
        
        // Assert
        expect(viewModel.selectedCount, equals(0));
        expect(viewModel.allSelected, isFalse);
      });

      test('should select all filtered recipes', () {
        // Arrange
        viewModel.toggleTag('vegetarisk');
        expect(viewModel.filteredRecipes.length, equals(2));
        
        // Act
        viewModel.toggleSelectAll();
        
        // Assert
        expect(viewModel.selectedCount, equals(2));
        expect(viewModel.selectedRecipeIds.contains('archive_1'), isTrue);
        expect(viewModel.selectedRecipeIds.contains('archive_3'), isTrue);
      });

      test('should handle partial selection', () {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        expect(viewModel.allSelected, isFalse);
        
        // Act - select all from partial
        viewModel.toggleSelectAll();
        
        // Assert
        expect(viewModel.selectedCount, equals(5));
        expect(viewModel.allSelected, isTrue);
      });
    });

    group('Import Operations', () {
      test('should import selected recipes', () async {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        viewModel.toggleRecipeSelection('archive_2');
        
        // Act
        await viewModel.importSelectedRecipes();
        
        // Assert
        expect(viewModel.hasError, isFalse);
        expect(viewModel.selectedCount, equals(0)); // cleared after success
        
        // Verify source attribution
        final capturedRecipes = verify(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(captureAny())
        ).captured.first as List<Recipe>;
        expect(capturedRecipes.length, equals(2));
        expect(capturedRecipes.every((r) => r.sourceUrl == 'Från Butlerys arkiv'), isTrue);
      });

      test('should not import when no recipes selected', () async {
        // Act
        await viewModel.importSelectedRecipes();
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, equals('Inga recept valda'));
        verifyNever(() => mockPersonalOperations.addMultipleUnifiedRecipes(any()));
      });

      test('should import all filtered recipes', () async {
        // Arrange
        viewModel.toggleTag('vegetarisk');
        expect(viewModel.filteredRecipes.length, equals(2));
        
        // Act
        await viewModel.importAllRecipes();
        
        // Assert
        expect(viewModel.hasError, isFalse);
        
        // Verify only filtered recipes were imported
        final capturedRecipes = verify(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(captureAny())
        ).captured.first as List<Recipe>;
        expect(capturedRecipes.length, equals(2));
      });

      test('should import all recipes when no filters', () async {
        // Act
        await viewModel.importAllRecipes();
        
        // Assert
        expect(viewModel.hasError, isFalse);
        
        // Verify all recipes were imported
        final capturedRecipes = verify(
          () => mockPersonalOperations.addMultipleUnifiedRecipes(captureAny())
        ).captured.first as List<Recipe>;
        expect(capturedRecipes.length, equals(5));
      });

      test('should handle import failure', () async {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        when(() => mockPersonalOperations.addMultipleUnifiedRecipes(any()))
            .thenAnswer((_) async => RecipeOperationResult.failure(
              'Kunde inte importera recept',
            ));
        
        // Act
        await viewModel.importSelectedRecipes();
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, equals('Kunde inte importera recept'));
        expect(viewModel.selectedCount, equals(1)); // not cleared on failure
      });

      test('should handle import exception', () async {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        when(() => mockPersonalOperations.addMultipleUnifiedRecipes(any()))
            .thenThrow(Exception('Network error'));
        
        // Act
        await viewModel.importSelectedRecipes();
        
        // Assert
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, contains('Import misslyckades'));
      });

      test('should track importing state', () async {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        bool wasImporting = false;
        
        viewModel.addListener(() {
          if (viewModel.isImporting) wasImporting = true;
        });
        
        // Act
        await viewModel.importSelectedRecipes();
        
        // Assert
        expect(wasImporting, isTrue);
        expect(viewModel.isImporting, isFalse); // Should be false after completion
      });
    });

    group('Clear and Reset Operations', () {
      test('should clear error', () {
        // Arrange - set error through failed import
        viewModel.importSelectedRecipes(); // No selection causes error
        expect(viewModel.hasError, isTrue);
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.clearError();
        
        // Assert
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
        expect(notificationCount, equals(1));
      });

      test('should clear all filters', () {
        // Arrange
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('vegetarisk');
        viewModel.setTimeFilter(TimeFilter.under30);
        viewModel.toggleRecipeSelection('archive_1');
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);
        
        // Act
        viewModel.clearFilters();
        
        // Assert
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.selectedTags, isEmpty);
        expect(viewModel.timeFilter, equals(TimeFilter.all));
        expect(viewModel.selectedRecipeIds, isEmpty);
        expect(viewModel.filteredRecipes.length, equals(5));
        expect(notificationCount, equals(1));
      });
    });

    group('Caching Optimization', () {
      test('should cache filtered results', () {
        // Act - first call
        final result1 = viewModel.filteredRecipes;
        
        // Act - second call with same filters
        final result2 = viewModel.filteredRecipes;
        
        // Assert - should return same cached instance
        expect(identical(result1, result2), isTrue);
      });

      test('should invalidate cache on search change', () {
        // Arrange
        final result1 = viewModel.filteredRecipes;
        
        // Act
        viewModel.updateSearch('pasta');
        final result2 = viewModel.filteredRecipes;
        
        // Assert - should be different instances
        expect(identical(result1, result2), isFalse);
        expect(result1.length, equals(5));
        expect(result2.length, equals(1));
      });

      test('should invalidate cache on tag change', () {
        // Arrange
        final result1 = viewModel.filteredRecipes;
        
        // Act
        viewModel.toggleTag('vegetarisk');
        final result2 = viewModel.filteredRecipes;
        
        // Assert - should be different instances
        expect(identical(result1, result2), isFalse);
      });

      test('should invalidate cache on time filter change', () {
        // Arrange
        final result1 = viewModel.filteredRecipes;
        
        // Act
        viewModel.setTimeFilter(TimeFilter.under30);
        final result2 = viewModel.filteredRecipes;
        
        // Assert - should be different instances
        expect(identical(result1, result2), isFalse);
      });

      test('should maintain cache with selection changes', () {
        // Arrange
        final result1 = viewModel.filteredRecipes;
        
        // Act - selection doesn't affect filtering
        viewModel.toggleRecipeSelection('archive_1');
        final result2 = viewModel.filteredRecipes;
        
        // Assert - should return same cached instance
        expect(identical(result1, result2), isTrue);
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        // Arrange
        final testViewModel = _TestableArchiveImportViewModel(
          recipeService: mockRecipeService,
          searchService: mockSearchService,
          testArchivedRecipes: testArchivedRecipes,
        );
        
        // Act & Assert
        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle rapid filter changes', () async {
        // Act - rapid filter changes
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('vegetarisk');
        viewModel.setTimeFilter(TimeFilter.under30);
        viewModel.updateSearch('köttbullar');
        viewModel.clearFilters();
        viewModel.toggleTag('svensk');
        
        // Assert - should handle all changes gracefully
        expect(viewModel.selectedTags.contains('svensk'), isTrue);
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.timeFilter, equals(TimeFilter.all));
      });

      test('should handle concurrent operations', () async {
        // Arrange
        viewModel.toggleRecipeSelection('archive_1');
        
        // Act - concurrent operations
        final import1 = viewModel.importSelectedRecipes();
        viewModel.updateSearch('pasta');
        viewModel.toggleTag('vegetarisk');
        
        await import1;
        
        // Assert
        expect(viewModel.hasError, isFalse);
        expect(viewModel.searchQuery, equals('pasta'));
        expect(viewModel.selectedTags.contains('vegetarisk'), isTrue);
      });
    });
  });
}

// Testable version that allows injecting archived recipes
class _TestableArchiveImportViewModel extends ArchiveImportViewModel {
  final List<Recipe> testArchivedRecipes;
  
  _TestableArchiveImportViewModel({
    required UnifiedRecipeService recipeService,
    required SearchService searchService,
    required this.testArchivedRecipes,
  }) : super(
    recipeService: recipeService,
    searchService: searchService,
  );
  
  @override
  List<Recipe> get archivedRecipes => testArchivedRecipes;
}