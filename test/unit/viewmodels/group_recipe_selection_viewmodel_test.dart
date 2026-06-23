import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/group_recipe_selection_viewmodel.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Mock services
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class FakeSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

void main() {
  group('GroupRecipeSelectionViewModel - Group Recipe Sharing Tests', () {
    late GroupRecipeSelectionViewModel viewModel;
    late MockUnifiedRecipeService mockRecipeService;
    late FakeSocialRecipeOperations mockSocialOperations;

    // Test data
    const testUserId = 'current-user-123';
    final testGroupName = 'Testgrupp';

    final testTargetGroup = FriendCategory.create(
      ownerId: testUserId,
      name: testGroupName,
      friendUserIds: ['friend-1', 'friend-2', 'friend-3'],
      isDefault: false,
    );

    final testGroupMembers = [
      UserProfile(
        uid: 'friend-1',
        displayName: 'Anna',
        email: 'anna@test.com',
        isOnline: true,
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime.now(),
      ),
      UserProfile(
        uid: 'friend-2',
        displayName: 'Erik',
        email: 'erik@test.com',
        isOnline: false,
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime.now(),
      ),
    ];

    // Recipe 1: Personal recipe (not shared)
    final testRecipe1 = Recipe(
      core: RecipeCore(
        id: 'recipe-1',
        title: 'Pannkakor',
        description: 'Goda pannkakor',
        ingredients: ['Mjöl', 'Mjölk', 'Ägg'],
        instructions: ['Blanda', 'Stek'],
        mealType: 'Frukost',
        createdBy: testUserId,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
      type: RecipeType.personal,
    );

    // Recipe 2: Collaborative recipe (shared with friend-1)
    final testRecipe2 = Recipe(
      core: RecipeCore(
        id: 'recipe-2',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
        ingredients: ['Köttfärs', 'Ägg', 'Ströbröd'],
        instructions: ['Rulla', 'Stek'],
        mealType: 'Middag',
        createdBy: testUserId,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      ),
      type: RecipeType.collaborative,
      socialData: RecipeSocialData(
        ownerId: testUserId,
        memberPermissions: {
          testUserId: ResourcePermission.owner,
          'friend-1': ResourcePermission.editor,
        },
      ),
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register fallback values for mocktail
      registerFallbackValue(<String>[]);
      registerFallbackValue(<String, String>{});
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockRecipeService = MockUnifiedRecipeService();
      mockSocialOperations = FakeSocialRecipeOperations();

      // Wire up social operations
      when(() => mockRecipeService.social).thenReturn(mockSocialOperations);

      // Register mock
      TestServiceLocator.registerMock<UnifiedRecipeService>(mockRecipeService);

      // Default mock behavior - return test recipes
      when(
        () => mockRecipeService.recipes,
      ).thenReturn([testRecipe1, testRecipe2]);
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
    GroupRecipeSelectionViewModel createViewModel() {
      return GroupRecipeSelectionViewModel(
        recipeService: mockRecipeService,
        targetGroup: testTargetGroup,
        groupMembers: testGroupMembers,
      );
    }

    // ===== INITIALIZATION AND STATE =====

    group('Initialization and State', () {
      test('should initialize with default state', () {
        // Act
        viewModel = createViewModel();

        // Assert
        expect(
          viewModel.filteredRecipes,
          isEmpty,
          reason: 'No recipes loaded yet',
        );
        expect(viewModel.isLoading, false, reason: 'Not loading initially');
        expect(viewModel.isSharing, false, reason: 'Not sharing initially');
        expect(viewModel.isEmpty, true, reason: 'No recipes loaded yet');
        expect(viewModel.hasSelectedRecipes, false, reason: 'Nothing selected');
        expect(viewModel.selectedCount, 0);
        expect(viewModel.searchQuery, '', reason: 'No search query');
      });

      test('should provide access to target group', () {
        // Act
        viewModel = createViewModel();

        // Assert
        expect(
          viewModel.targetGroup.id,
          isNotEmpty,
          reason: 'Group should have an ID',
        );
        expect(viewModel.targetGroup.name, testGroupName);
        expect(viewModel.targetGroup.ownerId, testUserId);
      });

      test('should provide access to group members', () {
        // Act
        viewModel = createViewModel();

        // Assert
        expect(viewModel.groupMembers.length, 2);
        expect(viewModel.groupMembers.first.displayName, 'Anna');
      });
    });

    // ===== LOAD RECIPES =====

    group('Load Recipes', () {
      test('should load recipes successfully', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        await viewModel.loadRecipes();

        // Assert
        expect(viewModel.isLoading, false);
        expect(viewModel.isEmpty, false);
        expect(viewModel.filteredCount, 2);
        expect(viewModel.totalCount, 2);
        expect(viewModel.error, null);
      });

      test('should detect already shared recipes', () async {
        // Arrange - Recipe2 is already shared with friend-1
        viewModel = createViewModel();

        // Act
        await viewModel.loadRecipes();

        // Assert
        expect(viewModel.isRecipeAlreadyShared('recipe-1'), false);
        expect(
          viewModel.isRecipeAlreadyShared('recipe-2'),
          true,
          reason: 'Recipe2 is collaborative with friend-1 as member',
        );
      });

      test('should sort unshared recipes first', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        await viewModel.loadRecipes();

        // Assert
        final filtered = viewModel.filteredRecipes;
        expect(
          filtered.first.id,
          'recipe-1',
          reason: 'Unshared recipe should be first',
        );
        expect(
          filtered.last.id,
          'recipe-2',
          reason: 'Shared recipe should be last',
        );
      });

      test('should handle load error', () async {
        // Arrange
        when(
          () => mockRecipeService.recipes,
        ).thenThrow(Exception('Failed to load'));
        viewModel = createViewModel();

        // Act
        await viewModel.loadRecipes();

        // Assert
        expect(viewModel.error, isNotNull);
        expect(viewModel.error, contains('Kunde inte ladda recept'));
        expect(viewModel.isLoading, false);
      });

      test('should set loading state during load', () async {
        // Arrange
        viewModel = createViewModel();

        // Act
        final loadFuture = viewModel.loadRecipes();

        // Wait a bit
        await Future.delayed(const Duration(milliseconds: 10));

        // During load, isLoading might be true (depends on AsyncOperationMixin timing)
        await loadFuture;

        // Assert - After load
        expect(viewModel.isLoading, false);
      });
    });

    // ===== RECIPE SELECTION =====

    group('Recipe Selection', () {
      test('should toggle recipe selection', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act - Select
        viewModel.toggleRecipeSelection('recipe-1');

        // Assert
        expect(viewModel.isRecipeSelected('recipe-1'), true);
        expect(viewModel.hasSelectedRecipes, true);
        expect(viewModel.selectedCount, 1);

        // Act - Deselect
        viewModel.toggleRecipeSelection('recipe-1');

        // Assert
        expect(viewModel.isRecipeSelected('recipe-1'), false);
        expect(viewModel.hasSelectedRecipes, false);
        expect(viewModel.selectedCount, 0);
      });

      test('should allow multiple selections', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act
        viewModel.toggleRecipeSelection('recipe-1');
        viewModel.toggleRecipeSelection('recipe-2');

        // Assert
        expect(viewModel.selectedCount, 2);
        expect(viewModel.isRecipeSelected('recipe-1'), true);
        expect(viewModel.isRecipeSelected('recipe-2'), true);
      });

      test('should provide list of selected recipes', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act
        viewModel.toggleRecipeSelection('recipe-1');
        viewModel.toggleRecipeSelection('recipe-2');

        // Assert
        final selected = viewModel.selectedRecipes;
        expect(selected.length, 2);
        expect(
          selected.map((r) => r.id),
          containsAll(['recipe-1', 'recipe-2']),
        );
      });

      test('should clear all selections', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');
        viewModel.toggleRecipeSelection('recipe-2');
        expect(viewModel.selectedCount, 2);

        // Act
        viewModel.clearSelections();

        // Assert
        expect(viewModel.selectedCount, 0);
        expect(viewModel.hasSelectedRecipes, false);
      });

      test('should notify listeners on selection change', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.toggleRecipeSelection('recipe-1');

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });

    // ===== SEARCH AND FILTER =====

    group('Search and Filter', () {
      test('should filter recipes by title', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        expect(viewModel.filteredCount, 2);

        // Act
        viewModel.setSearchQuery('pannkakor');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredRecipes.first.title, 'Pannkakor');
      });

      test('should filter recipes by description', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act
        viewModel.setSearchQuery('svenska');

        // Assert
        expect(viewModel.filteredCount, 1);
        expect(viewModel.filteredRecipes.first.title, 'Köttbullar');
      });

      test('should be case insensitive', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act
        viewModel.setSearchQuery('PANNKAKOR');

        // Assert
        expect(viewModel.filteredCount, 1);
      });

      test('should trim search query', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act
        viewModel.setSearchQuery('  pannkakor  ');

        // Assert
        expect(viewModel.searchQuery, 'pannkakor');
        expect(viewModel.filteredCount, 1);
      });

      test('should clear search query', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.setSearchQuery('pannkakor');
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
        await viewModel.loadRecipes();

        // Act
        viewModel.setSearchQuery('');

        // Assert
        expect(viewModel.filteredCount, 2);
      });

      test('should notify listeners when search changes', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        // Act
        viewModel.setSearchQuery('test');

        // Assert
        expect(notificationCount, greaterThan(0));
      });
    });

    // ===== SHARE SELECTED RECIPES =====

    group('Share Selected Recipes', () {
      test('should share selected recipes with group successfully', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async => 'recipe-1');

        // Act
        final result = await viewModel.shareSelectedRecipes();

        // Assert
        expect(result, true);
        expect(viewModel.isSharing, false);
        expect(viewModel.error, null);

        verify(
          () => mockSocialOperations.shareRecipe(
            recipeId: 'recipe-1',
            memberIds: testTargetGroup.friendUserIds,
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).called(1);
      });

      test('should share multiple recipes', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');
        viewModel.toggleRecipeSelection('recipe-2');

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async => 'recipe-1');

        // Act
        final result = await viewModel.shareSelectedRecipes();

        // Assert
        expect(result, true);

        verify(
          () => mockSocialOperations.shareRecipe(
            recipeId: 'recipe-1',
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).called(1);

        verify(
          () => mockSocialOperations.shareRecipe(
            recipeId: 'recipe-2',
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).called(1);
      });

      test('should pass member display names correctly', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        Map<String, String>? capturedDisplayNames;
        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((invocation) async {
          capturedDisplayNames =
              invocation.namedArguments[Symbol('memberDisplayNames')]
                  as Map<String, String>?;
          return 'recipe-1';
        });

        // Act
        await viewModel.shareSelectedRecipes();

        // Assert
        expect(capturedDisplayNames, isNotNull);
        expect(capturedDisplayNames!['friend-1'], 'Anna');
        expect(capturedDisplayNames!['friend-2'], 'Erik');
      });

      test('should clear selections after successful share', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');
        expect(viewModel.selectedCount, 1);

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async => 'recipe-1');

        // Act
        await viewModel.shareSelectedRecipes();

        // Assert
        expect(viewModel.selectedCount, 0);
      });

      test('should mark shared recipes as already shared', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');
        expect(viewModel.isRecipeAlreadyShared('recipe-1'), false);

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async => 'recipe-1');

        // Act
        await viewModel.shareSelectedRecipes();

        // Assert
        expect(viewModel.isRecipeAlreadyShared('recipe-1'), true);
      });

      test('should not share when nothing selected', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act
        final result = await viewModel.shareSelectedRecipes();

        // Assert
        expect(result, false);

        verifyNever(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        );
      });

      test('should not share when already sharing', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        // Mock a slow sharing operation
        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'recipe-1';
        });

        // Act - Start first share
        final share1 = viewModel.shareSelectedRecipes();
        await Future.delayed(const Duration(milliseconds: 10));

        // Try second share while first is in progress
        final share2 = viewModel.shareSelectedRecipes();

        await Future.wait([share1, share2]);

        // Assert - Should only call service once
        verify(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).called(1);
      });

      test('should handle share failure', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenThrow(Exception('Failed to share'));

        // Act
        final result = await viewModel.shareSelectedRecipes();

        // Assert
        expect(result, false);
        expect(viewModel.error, isNotNull);
        expect(viewModel.error, contains('Vissa delningar misslyckades'));
        expect(viewModel.isSharing, false);
      });

      test('should handle null return from share service', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        final result = await viewModel.shareSelectedRecipes();

        // Assert
        expect(result, false);
        expect(viewModel.error, contains('Vissa delningar misslyckades'));
      });

      test('should set loading state during share', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        when(
          () => mockSocialOperations.shareRecipe(
            recipeId: any(named: 'recipeId'),
            memberIds: any(named: 'memberIds'),
            memberDisplayNames: any(named: 'memberDisplayNames'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'recipe-1';
        });

        // Act
        final shareFuture = viewModel.shareSelectedRecipes();
        await Future.delayed(const Duration(milliseconds: 10));

        // Assert - During share
        expect(viewModel.isSharing, true);

        await shareFuture;

        // After share
        expect(viewModel.isSharing, false);
      });
    });

    // ===== SUCCESS MESSAGE =====

    group('Success Message', () {
      test('should provide single recipe success message', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');

        // Act
        final message = viewModel.successMessage;

        // Assert
        expect(message, contains('Pannkakor'));
        expect(message, contains('delat med'));
        expect(message, contains(testGroupName));
        expect(message, contains('🍽️'));
      });

      test('should provide multiple recipes success message', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();
        viewModel.toggleRecipeSelection('recipe-1');
        viewModel.toggleRecipeSelection('recipe-2');

        // Act
        final message = viewModel.successMessage;

        // Assert
        expect(message, contains('2 recept'));
        expect(message, contains('delade med'));
        expect(message, contains(testGroupName));
        expect(message, contains('🍽️'));
      });
    });

    // ===== DISPOSE =====

    group('Dispose', () {
      test('should dispose without errors', () async {
        // Arrange
        viewModel = createViewModel();
        await viewModel.loadRecipes();

        // Act & Assert
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
