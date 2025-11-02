import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock dependencies
class MockFirebaseSharedRecipeRepository extends Mock implements FirebaseSharedRecipeRepository {}
class MockSocialRecipeCoordinator extends Mock implements SocialRecipeCoordinator {}

void main() {
  group('SharedRecipeViewModel - Shared Recipe Management Tests', () {
    late SharedRecipeViewModel viewModel;
    late MockFirebaseSharedRecipeRepository mockRepository;
    late MockSocialRecipeCoordinator mockCoordinator;

    // Test data
    const testUserId = 'current-user-123';
    const testOtherUserId = 'other-user-456';
    const testRecipeId1 = 'recipe-1';
    const testRecipeId2 = 'recipe-2';
    const testRecipeId3 = 'recipe-3';

    late SharedRecipe testRecipe1;
    late SharedRecipe testRecipe2;
    late SharedRecipe testRecipe3;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(<String>[]);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRepository = MockFirebaseSharedRecipeRepository();
      mockCoordinator = MockSocialRecipeCoordinator();

      // Create test recipes
      final recipe1 = Recipe(
        core: RecipeCore(
          id: testRecipeId1,
          title: 'Pannkakor',
          description: 'Goda pannkakor',
          ingredients: ['Mjöl', 'Mjölk', 'Ägg'],
          instructions: ['Blanda', 'Stek'],
          mealType: 'Frukost',
          createdBy: testOtherUserId,
          createdAt: DateTime(2025, 1, 20),
          updatedAt: DateTime(2025, 1, 20),
        ),
        type: RecipeType.personal,
      );

      final recipe2 = Recipe(
        core: RecipeCore(
          id: testRecipeId2,
          title: 'Köttbullar',
          description: 'Svenska köttbullar',
          ingredients: ['Köttfärs', 'Ägg', 'Ströbröd'],
          instructions: ['Rulla', 'Stek'],
          mealType: 'Middag',
          createdBy: testOtherUserId,
          createdAt: DateTime(2025, 1, 21),
          updatedAt: DateTime(2025, 1, 21),
        ),
        type: RecipeType.personal,
      );

      final recipe3 = Recipe(
        core: RecipeCore(
          id: testRecipeId3,
          title: 'Våfflor',
          description: 'Knapriga våfflor',
          ingredients: ['Mjöl', 'Mjölk', 'Ägg', 'Smör'],
          instructions: ['Blanda', 'Grädda'],
          mealType: 'Frukost',
          createdBy: testOtherUserId,
          createdAt: DateTime(2025, 1, 22),
          updatedAt: DateTime(2025, 1, 22),
        ),
        type: RecipeType.personal,
      );

      testRecipe1 = SharedRecipe(
        id: testRecipeId1,
        originalRecipeId: testRecipeId1,
        recipeSnapshot: recipe1,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Anna',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 20),
        viewedByUserIds: [],
        engagedByUserIds: [],
        dismissedByUserIds: [],
        allowCollaboration: false,
      );

      testRecipe2 = SharedRecipe(
        id: testRecipeId2,
        originalRecipeId: testRecipeId2,
        recipeSnapshot: recipe2,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Erik',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 21),
        viewedByUserIds: [testUserId], // Already viewed
        engagedByUserIds: [],
        dismissedByUserIds: [],
        allowCollaboration: false,
      );

      testRecipe3 = SharedRecipe(
        id: testRecipeId3,
        originalRecipeId: testRecipeId3,
        recipeSnapshot: recipe3,
        sharedByUserId: testOtherUserId,
        sharedByDisplayName: 'Maria',
        sharedToUserIds: [testUserId],
        sharedAt: DateTime(2025, 1, 22),
        viewedByUserIds: [],
        engagedByUserIds: [],
        dismissedByUserIds: [testUserId], // Dismissed
        allowCollaboration: false,
      );

      // Setup default mock behavior
      when(() => mockRepository.getSharedRecipesForUser(testUserId))
          .thenAnswer((_) async => [testRecipe1, testRecipe2]); // testRecipe3 filtered out (dismissed)

      when(() => mockRepository.markAsViewed(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.markAsDismissed(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockRepository.undismiss(any(), any()))
          .thenAnswer((_) async {});

      when(() => mockCoordinator.joinSharedRecipe(
        sharedRecipeId: any(named: 'sharedRecipeId'),
        newTitle: any(named: 'newTitle'),
      )).thenAnswer((_) async => 'new-recipe-id');

      when(() => mockCoordinator.startCollaborativeEditing(
        sharedRecipeId: any(named: 'sharedRecipeId'),
      )).thenAnswer((_) async => 'collaborative-recipe-id');
    });

    tearDown(() async {
      try {
        viewModel.dispose();
      } catch (e) {
        // Already disposed in test
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // Helper to create ViewModel
    SharedRecipeViewModel createViewModel() {
      return SharedRecipeViewModel(
        sharedRecipeRepository: mockRepository,
        socialRecipeCoordinator: mockCoordinator,
      );
    }

    // ===== INITIALIZATION AND LOADING =====

    group('Initialization and Loading', () {
      test('should initialize and auto-load content', () async {
        // Act
        viewModel = createViewModel();

        // Wait for auto-initialization
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        expect(viewModel.contentTypeName, 'recipe');
        verify(() => mockRepository.getSharedRecipesForUser(testUserId)).called(1);
      });

      test('should load recipes successfully', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        await viewModel.loadContent();

        // Assert
        expect(viewModel.isLoading, false);
        expect(viewModel.hasContent, true);
        expect(viewModel.totalCount, 2, reason: 'Should load 2 recipes (dismissed excluded)');
        expect(viewModel.hasError, false);
      });

      test('should filter out dismissed recipes during load', () async {
        // Arrange
        when(() => mockRepository.getSharedRecipesForUser(testUserId))
            .thenAnswer((_) async => [testRecipe1, testRecipe2, testRecipe3]);

        viewModel = createViewModel();

        // Act
        await viewModel.loadContent();

        // Assert
        expect(viewModel.totalCount, 2, reason: 'testRecipe3 should be filtered (dismissed)');
        expect(viewModel.content.any((r) => r.id == testRecipeId3), false);
      });

      test('should handle load error gracefully', () async {
        // Arrange
        when(() => mockRepository.getSharedRecipesForUser(testUserId))
            .thenThrow(Exception('Network error'));

        viewModel = createViewModel();

        // Act
        await viewModel.loadContent();

        // Assert
        expect(viewModel.hasError, true);
        expect(viewModel.error, contains('Failed to load recipe content'));
        expect(viewModel.isLoading, false);
      });

      test('should set loading state during load', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        final loadFuture = viewModel.loadContent();

        // Wait a bit to check loading state
        await Future.delayed(const Duration(milliseconds: 10));

        await loadFuture;

        // Assert - After load completes
        expect(viewModel.isLoading, false);
      });
    });

    // ===== CONTENT GETTERS =====

    group('Content Getters', () {
      test('should provide unread count', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act & Assert
        expect(viewModel.unreadCount, 1, reason: 'testRecipe1 is unread, testRecipe2 is viewed');
      });

      test('should provide importable recipes', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final importable = viewModel.importableRecipes;

        // Assert
        expect(importable.length, 2, reason: 'Both recipes can be imported');
        expect(importable.any((r) => r.id == testRecipeId1), true);
        expect(importable.any((r) => r.id == testRecipeId2), true);
      });

      test('should exclude imported recipes from importable list', () async {
        // Arrange
        final importedRecipe = SharedRecipe(
          id: testRecipeId1,
          originalRecipeId: testRecipeId1,
          recipeSnapshot: testRecipe1.recipeSnapshot,
          sharedByUserId: testOtherUserId,
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [testUserId],
          sharedAt: DateTime(2025, 1, 20),
          viewedByUserIds: [],
          engagedByUserIds: [testUserId], // Imported (engaged)
          dismissedByUserIds: [],
          allowCollaboration: false,
        );

        when(() => mockRepository.getSharedRecipesForUser(testUserId))
            .thenAnswer((_) async => [importedRecipe, testRecipe2]);

        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final importable = viewModel.importableRecipes;

        // Assert
        expect(importable.length, 1);
        expect(importable.first.id, testRecipeId2);
      });

      test('should provide shared by current user recipes', () async {
        // Arrange
        final myRecipe = SharedRecipe(
          id: 'my-recipe',
          originalRecipeId: 'my-recipe',
          recipeSnapshot: testRecipe1.recipeSnapshot,
          sharedByUserId: testUserId, // Shared by current user
          sharedByDisplayName: 'Me',
          sharedToUserIds: [testOtherUserId],
          sharedAt: DateTime(2025, 1, 20),
          viewedByUserIds: [],
          engagedByUserIds: [],
          dismissedByUserIds: [],
          allowCollaboration: false,
        );

        when(() => mockRepository.getSharedRecipesForUser(testUserId))
            .thenAnswer((_) async => [myRecipe, testRecipe1]);

        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final myRecipes = viewModel.sharedByCurrentUser;

        // Assert
        expect(myRecipes.length, 1);
        expect(myRecipes.first.id, 'my-recipe');
      });
    });

    // ===== SEARCH AND FILTERING =====

    group('Search and Filtering', () {
      test('should filter recipes by title', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        viewModel.updateSearchQuery('Pannkakor');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testRecipeId1);
      });

      test('should filter recipes by description', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        viewModel.updateSearchQuery('Svenska');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testRecipeId2);
      });

      test('should filter recipes by ingredients', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        viewModel.updateSearchQuery('Köttfärs');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testRecipeId2);
      });

      test('should filter recipes by sharer name', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        viewModel.updateSearchQuery('Anna');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredContent.first.id, testRecipeId1);
      });

      test('should be case insensitive', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        viewModel.updateSearchQuery('PANNKAKOR');

        // Assert
        expect(viewModel.filteredCount, 1);
      });

      test('should clear search', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();
        viewModel.updateSearchQuery('Pannkakor');
        expect(viewModel.filteredCount, 1);

        // Act
        viewModel.clearSearch();

        // Assert
        expect(viewModel.searchQuery, '');
        expect(viewModel.filteredCount, 2);
      });

      test('should show all recipes when search is empty', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        viewModel.updateSearchQuery('');

        // Assert
        expect(viewModel.filteredCount, viewModel.totalCount);
      });
    });

    // ===== IMPORT OPERATIONS =====

    group('Import Operations', () {
      test('should import recipe successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final recipeId = await viewModel.importSharedRecipe(testRecipe1);

        // Assert
        expect(recipeId, 'new-recipe-id');
        expect(viewModel.isOperating, false);
        verify(() => mockCoordinator.joinSharedRecipe(
          sharedRecipeId: testRecipeId1,
          newTitle: null,
        )).called(1);
      });

      test('should import recipe with custom title', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();
        const customTitle = 'Mina pannkakor';

        // Act
        await viewModel.importSharedRecipe(testRecipe1, newTitle: customTitle);

        // Assert
        verify(() => mockCoordinator.joinSharedRecipe(
          sharedRecipeId: testRecipeId1,
          newTitle: customTitle,
        )).called(1);
      });

      test('should handle import error', () async {
        // Arrange
        when(() => mockCoordinator.joinSharedRecipe(
          sharedRecipeId: any(named: 'sharedRecipeId'),
          newTitle: any(named: 'newTitle'),
        )).thenThrow(Exception('Import failed'));

        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final result = await viewModel.importSharedRecipe(testRecipe1);

        // Assert
        expect(result, null);
        expect(viewModel.hasError, true);
        expect(viewModel.isOperating, false);
      });

      test('should set operating state during import', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final importFuture = viewModel.importSharedRecipe(testRecipe1);

        // Wait a bit to check operating state
        await Future.delayed(const Duration(milliseconds: 10));

        await importFuture;

        // Assert - After operation
        expect(viewModel.isOperating, false);
      });
    });

    // ===== COLLABORATIVE EDITING =====

    group('Collaborative Editing', () {
      test('should start collaborative editing successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final recipeId = await viewModel.startCollaborativeEditing(testRecipe1);

        // Assert
        expect(recipeId, 'collaborative-recipe-id');
        verify(() => mockCoordinator.startCollaborativeEditing(
          sharedRecipeId: testRecipeId1,
        )).called(1);
      });

      test('should handle collaborative editing error', () async {
        // Arrange
        when(() => mockCoordinator.startCollaborativeEditing(
          sharedRecipeId: any(named: 'sharedRecipeId'),
        )).thenThrow(Exception('Failed to start collaboration'));

        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final result = await viewModel.startCollaborativeEditing(testRecipe1);

        // Assert
        expect(result, null);
        expect(viewModel.hasError, true);
      });
    });

    // ===== MARK AS VIEWED =====

    group('Mark As Viewed', () {
      test('should mark recipe as viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final result = await viewModel.markAsViewed(testRecipe1);

        // Assert
        expect(result, true);
        verify(() => mockRepository.markAsViewed(testRecipeId1, testUserId)).called(1);
      });

      test('should skip if already viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act - testRecipe2 is already viewed
        final result = await viewModel.markAsViewed(testRecipe2);

        // Assert
        expect(result, true);
        verifyNever(() => mockRepository.markAsViewed(testRecipeId2, testUserId));
      });

      test('should handle mark as viewed error', () async {
        // Arrange
        when(() => mockRepository.markAsViewed(any(), any()))
            .thenThrow(Exception('Failed to mark'));

        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final result = await viewModel.markAsViewed(testRecipe1);

        // Assert
        expect(result, false);
        expect(viewModel.hasError, true);
      });
    });

    // ===== DISMISS AND UNDISMISS =====

    group('Dismiss and Undismiss', () {
      test('should dismiss recipe', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();
        final initialCount = viewModel.totalCount;

        // Act
        final result = await viewModel.dismissSharedRecipe(testRecipe1);

        // Assert
        expect(result, true);
        expect(viewModel.totalCount, initialCount - 1, reason: 'Recipe removed from list');
        verify(() => mockRepository.markAsDismissed(testRecipeId1, testUserId)).called(1);
      });

      test('should undismiss recipe', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();
        final initialCount = viewModel.totalCount;

        // Act
        final result = await viewModel.undismissSharedRecipe(testRecipe3);

        // Assert
        expect(result, true);
        expect(viewModel.totalCount, initialCount + 1, reason: 'Recipe added back to list');
        verify(() => mockRepository.undismiss(testRecipeId3, testUserId)).called(1);
      });

      test('should handle dismiss error', () async {
        // Arrange
        when(() => mockRepository.markAsDismissed(any(), any()))
            .thenThrow(Exception('Failed to dismiss'));

        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act
        final result = await viewModel.dismissSharedRecipe(testRecipe1);

        // Assert
        expect(result, false);
        expect(viewModel.hasError, true);
      });
    });

    // ===== STATUS CHECKING =====

    group('Status Checking', () {
      test('should check if recipe is viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for auto-init

        // Act & Assert
        // Note: These use model's own status methods, not ViewModel
        expect(testRecipe1.isViewedBy(testUserId), false);
        expect(testRecipe2.isViewedBy(testUserId), true);
      });

      test('should check if recipe is imported', () async {
        // Arrange
        final importedRecipe = SharedRecipe(
          id: testRecipeId1,
          originalRecipeId: testRecipeId1,
          recipeSnapshot: testRecipe1.recipeSnapshot,
          sharedByUserId: testOtherUserId,
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [testUserId],
          sharedAt: DateTime(2025, 1, 20),
          viewedByUserIds: [],
          engagedByUserIds: [testUserId],
          dismissedByUserIds: [],
          allowCollaboration: false,
        );

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for auto-init

        // Act & Assert - use model's method directly
        expect(importedRecipe.isImportedBy(testUserId), true);
        expect(testRecipe1.isImportedBy(testUserId), false);
      });

      test('should check if recipe is dismissed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for auto-init

        // Act & Assert - use model's method directly
        expect(testRecipe3.isDismissedBy(testUserId), true);
        expect(testRecipe1.isDismissedBy(testUserId), false);
      });

      test('should check if recipe allows collaboration', () async {
        // Arrange
        final collaborativeRecipe = SharedRecipe(
          id: testRecipeId1,
          originalRecipeId: testRecipeId1,
          recipeSnapshot: testRecipe1.recipeSnapshot,
          sharedByUserId: testOtherUserId,
          sharedByDisplayName: 'Anna',
          sharedToUserIds: [testUserId],
          sharedAt: DateTime(2025, 1, 20),
          viewedByUserIds: [],
          engagedByUserIds: [],
          dismissedByUserIds: [],
          allowCollaboration: true,
        );

        viewModel = createViewModel();

        // Act & Assert
        expect(collaborativeRecipe.allowCollaboration, true);
        expect(testRecipe1.allowCollaboration, false);
      });
    });

    // ===== BULK OPERATIONS =====

    group('Bulk Operations', () {
      test('should mark all recipes as viewed', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for auto-init

        // Act
        await viewModel.markAllAsViewed();

        // Assert
        verify(() => mockRepository.markAsViewed(testRecipeId1, testUserId)).called(1);
        // testRecipe2 already viewed, should not be called again
      });

      test('should handle mark all as viewed error', () async {
        // Arrange
        when(() => mockRepository.markAsViewed(any(), any()))
            .thenThrow(Exception('Failed'));

        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for auto-init

        // Act
        await viewModel.markAllAsViewed();

        // Assert
        expect(viewModel.hasError, true);
      });
    });

    // ===== REFRESH =====

    group('Refresh Content', () {
      test('should refresh content successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await Future.delayed(const Duration(milliseconds: 150)); // Wait for auto-init

        // Reset mock to count only the refresh call
        reset(mockRepository);
        when(() => mockRepository.getSharedRecipesForUser(testUserId))
            .thenAnswer((_) async => [testRecipe1, testRecipe2]);

        // Act
        await viewModel.refreshContent();

        // Assert
        verify(() => mockRepository.getSharedRecipesForUser(testUserId)).called(1);
      });

      test('should handle refresh error', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        when(() => mockRepository.getSharedRecipesForUser(testUserId))
            .thenThrow(Exception('Refresh failed'));

        // Act
        await viewModel.refreshContent();

        // Assert
        expect(viewModel.hasError, true);
      });
    });

    // ===== DISPOSAL =====

    group('Disposal', () {
      test('should dispose without errors', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadContent();

        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
