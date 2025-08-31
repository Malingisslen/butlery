// test/unit/viewmodels/recipe_selection_viewmodel_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Testable extension of MockUnifiedRecipeService that adds social operations support
class TestableUnifiedRecipeService extends MockUnifiedRecipeService {
  MockSocialRecipeOperations? _socialOperations;
  bool _shouldThrowOnRecipes = false;
  Exception? _exceptionToThrow;
  
  void setSocialOperations(MockSocialRecipeOperations operations) {
    _socialOperations = operations;
  }
  
  void configureThrowing({required bool shouldThrow, Exception? exception}) {
    _shouldThrowOnRecipes = shouldThrow;
    _exceptionToThrow = exception ?? Exception('Load failed');
  }
  
  @override
  List<Recipe> get recipes {
    if (_shouldThrowOnRecipes) {
      throw _exceptionToThrow!;
    }
    return super.recipes;
  }
  
  @override
  SocialRecipeOperations get social {
    if (_socialOperations == null) {
      throw StateError('SocialRecipeOperations not configured in mock. '
          'Use setSocialOperations(mockSocialOps)');
    }
    return _socialOperations!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late TestableUnifiedRecipeService mockRecipeService;
  late MockSocialRecipeOperations mockSocialOperations;
  late RecipeSelectionViewModel viewModel;
  late UserProfile targetFriend;

  setUp(() async {
    await TestServiceLocator.initialize();
    
    mockSocialOperations = MockSocialRecipeOperations();
    mockRecipeService = TestableUnifiedRecipeService();
    
    // Setup mock service structure with state configuration
    mockRecipeService.setSocialOperations(mockSocialOperations);
    mockRecipeService.setRecipeState(
      recipes: [],
      isInitialized: true,
    );
    
    targetFriend = UserProfile(
      uid: 'friend_123',
      displayName: 'Anna Andersson',
      email: 'anna@example.com',
      joinedAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
    
    viewModel = RecipeSelectionViewModel(
      recipeService: mockRecipeService,
      targetFriend: targetFriend,
    );
    
    // Default mock setup
    when(() => mockSocialOperations.getSharedByMe()).thenAnswer((_) async => []);
    when(() => mockSocialOperations.getSharedWithMe()).thenAnswer((_) async => []);
  });

  tearDown(() async {
    viewModel.dispose();
    await TestServiceLocator.reset();
  });

  Recipe createRecipeWithSocialData({
    String? id,
    String? title,
    Map<String, ResourcePermission>? memberPermissions,
  }) {
    final recipe = RecipeFactory.build(
      id: id ?? 'recipe_${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Test Recipe',
    );
    
    if (memberPermissions != null) {
      // Create recipe with social data
      return recipe.copyWith(
        socialData: RecipeSocialData(
          ownerId: 'test_user',
          ownerDisplayName: 'Test User',
          memberPermissions: memberPermissions,
        ),
      );
    }
    
    return recipe;
  }

  group('RecipeSelectionViewModel - Initialization', () {
    test('should initialize with default state', () {
      expect(viewModel.targetFriend, equals(targetFriend));
      expect(viewModel.allRecipes, isEmpty);
      expect(viewModel.filteredRecipes, isEmpty);
      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isFalse);
      expect(viewModel.hasRecipes, isFalse);
      expect(viewModel.hasFilteredRecipes, isFalse);
      expect(viewModel.selectedRecipeIds, isEmpty);
      expect(viewModel.alreadySharedRecipeIds, isEmpty);
      expect(viewModel.selectedRecipes, isEmpty);
      expect(viewModel.canShare, isFalse);
    });

    test('should have correct compatibility properties', () {
      expect(viewModel.hasSelectedRecipes, isFalse);
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.hasSearchResults, isFalse);
      expect(viewModel.filteredCount, equals(0));
      expect(viewModel.totalCount, equals(0));
    });
  });

  group('RecipeSelectionViewModel - Loading Recipes', () {
    test('should load recipes successfully', () async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
        RecipeFactory.build(id: 'recipe_3', title: 'Recipe 3'),
      ];
      
      mockRecipeService.setRecipeState(recipes: recipes);
      
      await viewModel.loadRecipes();
      
      expect(viewModel.allRecipes.length, equals(3));
      expect(viewModel.filteredRecipes.length, equals(3));
      expect(viewModel.hasRecipes, isTrue);
      expect(viewModel.hasFilteredRecipes, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
    });

    test('should load already shared recipes', () async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
      ];
      
      final sharedRecipe = createRecipeWithSocialData(
        id: 'recipe_1',
        title: 'Shared Recipe',
        memberPermissions: {
          'friend_123': ResourcePermission.editor,
          'friend_456': ResourcePermission.viewer,
        },
      );
      
      mockRecipeService.setRecipeState(recipes: recipes);
      when(() => mockSocialOperations.getSharedByMe())
          .thenAnswer((_) async => [sharedRecipe]);
      when(() => mockSocialOperations.getSharedWithMe())
          .thenAnswer((_) async => []);
      
      await viewModel.loadRecipes();
      
      expect(viewModel.alreadySharedRecipeIds.contains('recipe_1'), isTrue);
      expect(viewModel.isRecipeAlreadyShared('recipe_1'), isTrue);
      expect(viewModel.isRecipeAlreadyShared('recipe_2'), isFalse);
    });

    test('should detect bidirectional sharing', () async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1'),
        RecipeFactory.build(id: 'recipe_2'),
      ];
      
      final sharedWithMe = createRecipeWithSocialData(
        id: 'recipe_2',
        memberPermissions: {
          'friend_123': ResourcePermission.viewer,
          'current_user': ResourcePermission.editor,
        },
      );
      
      mockRecipeService.setRecipeState(recipes: recipes);
      when(() => mockSocialOperations.getSharedByMe()).thenAnswer((_) async => []);
      when(() => mockSocialOperations.getSharedWithMe())
          .thenAnswer((_) async => [sharedWithMe]);
      
      await viewModel.loadRecipes();
      
      expect(viewModel.isRecipeAlreadyShared('recipe_2'), isTrue);
    });

    test('should handle loading error', () async {
      // Configure mock to throw when accessing recipes
      mockRecipeService.configureThrowing(
        shouldThrow: true,
        exception: Exception('Load failed'),
      );
      
      await viewModel.loadRecipes();
      
      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, equals('Kunde inte ladda recept'));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.allRecipes, isEmpty);
    });

    test('should handle shared recipes loading error gracefully', () async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1'),
      ];
      
      mockRecipeService.setRecipeState(recipes: recipes);
      when(() => mockSocialOperations.getSharedByMe())
          .thenThrow(Exception('Network error'));
      
      await viewModel.loadRecipes();
      
      // Should still load recipes even if shared loading fails
      expect(viewModel.allRecipes.length, equals(1));
      expect(viewModel.alreadySharedRecipeIds, isEmpty);
      expect(viewModel.hasError, isFalse); // Main loading succeeded
    });
  });

  group('RecipeSelectionViewModel - Search and Filtering', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(
          id: 'recipe_1',
          title: 'Pasta Carbonara',
          description: 'Italian classic',
          ingredients: ['Pasta', 'Eggs', 'Bacon'],
        ),
        RecipeFactory.build(
          id: 'recipe_2',
          title: 'Vegetable Soup',
          description: 'Healthy soup',
          ingredients: ['Carrots', 'Potatoes', 'Onions'],
        ),
        RecipeFactory.build(
          id: 'recipe_3',
          title: 'Chicken Salad',
          description: 'Light meal',
          ingredients: ['Chicken', 'Lettuce', 'Tomatoes'],
        ),
      ];
      
      mockRecipeService.setRecipeState(recipes: recipes);
      await viewModel.loadRecipes();
    });

    test('should update search query and filter recipes', () {
      viewModel.updateSearchQuery('pasta');
      
      expect(viewModel.searchQuery, equals('pasta'));
      expect(viewModel.filteredRecipes.length, equals(1));
      expect(viewModel.filteredRecipes.first.title, contains('Pasta'));
    });

    test('should search by title case-insensitive', () {
      viewModel.updateSearchQuery('PASTA');
      
      expect(viewModel.filteredRecipes.length, equals(1));
      expect(viewModel.filteredRecipes.first.title, contains('Pasta'));
    });

    test('should search by description', () {
      viewModel.updateSearchQuery('italian');
      
      expect(viewModel.filteredRecipes.length, equals(1));
      expect(viewModel.filteredRecipes.first.description, contains('Italian'));
    });

    test('should search by ingredients', () {
      viewModel.updateSearchQuery('chicken');
      
      expect(viewModel.filteredRecipes.length, equals(1));
      expect(viewModel.filteredRecipes.first.title, contains('Chicken'));
    });

    test('should clear search', () {
      viewModel.updateSearchQuery('pasta');
      expect(viewModel.searchQuery, equals('pasta'));
      expect(viewModel.filteredRecipes.length, equals(1));
      
      viewModel.clearSearch();
      
      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.filteredRecipes.length, equals(3));
    });

    test('should use compatibility search method', () {
      viewModel.updateSearch('soup');
      
      expect(viewModel.searchQuery, equals('soup'));
      expect(viewModel.filteredRecipes.length, equals(1));
    });

    test('should sort unshared recipes before shared ones', () async {
      // Mark recipe_2 as already shared
      final sharedRecipe = createRecipeWithSocialData(
        id: 'recipe_2',
        memberPermissions: {'friend_123': ResourcePermission.viewer},
      );
      
      when(() => mockSocialOperations.getSharedByMe())
          .thenAnswer((_) async => [sharedRecipe]);
      
      await viewModel.loadRecipes();
      
      // Unshared recipes should come first, sorted alphabetically within group
      // recipe_3 (Chicken Salad) and recipe_1 (Pasta Carbonara) are unshared
      // recipe_2 (Vegetable Soup) is shared
      expect(viewModel.filteredRecipes[0].id, equals('recipe_3')); // Chicken Salad (unshared)
      expect(viewModel.filteredRecipes[1].id, equals('recipe_1')); // Pasta Carbonara (unshared)
      expect(viewModel.filteredRecipes[2].id, equals('recipe_2')); // Vegetable Soup (shared)
    });

    test('should sort alphabetically within shared/unshared groups', () {
      // All unshared, should be alphabetical
      expect(viewModel.filteredRecipes[0].title, startsWith('Chicken'));
      expect(viewModel.filteredRecipes[1].title, startsWith('Pasta'));
      expect(viewModel.filteredRecipes[2].title, startsWith('Vegetable'));
    });
  });

  group('RecipeSelectionViewModel - Selection Management', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
        RecipeFactory.build(id: 'recipe_3', title: 'Recipe 3'),
      ];
      
      mockRecipeService.setRecipeState(recipes: recipes);
      await viewModel.loadRecipes();
    });

    test('should toggle recipe selection', () {
      expect(viewModel.isRecipeSelected('recipe_1'), isFalse);
      
      viewModel.toggleRecipeSelection('recipe_1');
      
      expect(viewModel.isRecipeSelected('recipe_1'), isTrue);
      expect(viewModel.selectedRecipeIds.contains('recipe_1'), isTrue);
      expect(viewModel.selectedCount, equals(1));
      expect(viewModel.hasSelectedRecipes, isTrue);
      expect(viewModel.canShare, isTrue);
    });

    test('should deselect recipe on second toggle', () {
      viewModel.toggleRecipeSelection('recipe_1');
      expect(viewModel.isRecipeSelected('recipe_1'), isTrue);
      
      viewModel.toggleRecipeSelection('recipe_1');
      
      expect(viewModel.isRecipeSelected('recipe_1'), isFalse);
      expect(viewModel.selectedRecipeIds.contains('recipe_1'), isFalse);
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.canShare, isFalse);
    });

    test('should select multiple recipes', () {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');
      viewModel.toggleRecipeSelection('recipe_3');
      
      expect(viewModel.selectedCount, equals(3));
      expect(viewModel.selectedRecipeIds.length, equals(3));
      expect(viewModel.selectedRecipes.length, equals(3));
    });

    test('should clear all selections', () {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');
      expect(viewModel.selectedCount, equals(2));
      
      viewModel.clearSelection();
      
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.selectedRecipeIds, isEmpty);
      expect(viewModel.canShare, isFalse);
    });

    test('should use compatibility clear method', () {
      viewModel.toggleRecipeSelection('recipe_1');
      expect(viewModel.selectedCount, equals(1));
      
      viewModel.clearSelections();
      
      expect(viewModel.selectedCount, equals(0));
    });

    test('should get selected recipe objects', () {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_3');
      
      final selected = viewModel.selectedRecipes;
      
      expect(selected.length, equals(2));
      expect(selected.any((r) => r.id == 'recipe_1'), isTrue);
      expect(selected.any((r) => r.id == 'recipe_3'), isTrue);
    });
  });

  group('RecipeSelectionViewModel - Sharing Operations', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
      ];
      
      mockRecipeService.setRecipeState(recipes: recipes);
      await viewModel.loadRecipes();
    });

    test('should share selected recipes successfully', () async {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');
      
      when(() => mockSocialOperations.shareRecipe(
        recipeId: any(named: 'recipeId'),
        memberIds: any(named: 'memberIds'),
        memberDisplayNames: any(named: 'memberDisplayNames'),
      )).thenAnswer((_) async => 'share_id');
      
      final success = await viewModel.shareSelectedRecipes();
      
      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.selectedRecipeIds, isEmpty); // Cleared after sharing
      expect(viewModel.alreadySharedRecipeIds.contains('recipe_1'), isTrue);
      expect(viewModel.alreadySharedRecipeIds.contains('recipe_2'), isTrue);
      
      verify(() => mockSocialOperations.shareRecipe(
        recipeId: 'recipe_1',
        memberIds: ['friend_123'],
        memberDisplayNames: {'friend_123': 'Anna Andersson'},
      )).called(1);
      
      verify(() => mockSocialOperations.shareRecipe(
        recipeId: 'recipe_2',
        memberIds: ['friend_123'],
        memberDisplayNames: {'friend_123': 'Anna Andersson'},
      )).called(1);
    });

    test('should handle sharing failure', () async {
      viewModel.toggleRecipeSelection('recipe_1');
      
      when(() => mockSocialOperations.shareRecipe(
        recipeId: any(named: 'recipeId'),
        memberIds: any(named: 'memberIds'),
        memberDisplayNames: any(named: 'memberDisplayNames'),
      )).thenAnswer((_) async => null);
      
      final success = await viewModel.shareSelectedRecipes();
      
      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, contains('Kunde inte dela recept'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should not share when no recipes selected', () async {
      final success = await viewModel.shareSelectedRecipes();
      
      expect(success, isFalse);
      verifyNever(() => mockSocialOperations.shareRecipe(
        recipeId: any(named: 'recipeId'),
        memberIds: any(named: 'memberIds'),
        memberDisplayNames: any(named: 'memberDisplayNames'),
      ));
    });

    test('should not share when already sharing', () async {
      viewModel.toggleRecipeSelection('recipe_1');
      
      // Start first share operation
      when(() => mockSocialOperations.shareRecipe(
        recipeId: any(named: 'recipeId'),
        memberIds: any(named: 'memberIds'),
        memberDisplayNames: any(named: 'memberDisplayNames'),
      )).thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'share_id';
      });
      
      final future1 = viewModel.shareSelectedRecipes();
      final future2 = viewModel.shareSelectedRecipes();
      
      final results = await Future.wait([future1, future2]);
      
      // One should succeed, one should fail
      expect(results.where((r) => r == true).length, equals(1));
      expect(results.where((r) => r == false).length, equals(1));
    });
  });

  group('RecipeSelectionViewModel - Status Messages', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Pasta'),
        RecipeFactory.build(id: 'recipe_2', title: 'Soup'),
      ];
      
      mockRecipeService.setRecipeState(recipes: recipes);
      await viewModel.loadRecipes();
    });

    test('should get selection summary', () {
      expect(viewModel.getSelectionSummary(), equals('Inga recept valda'));
      
      viewModel.toggleRecipeSelection('recipe_1');
      expect(viewModel.getSelectionSummary(), equals('1 recept valt'));
      
      viewModel.toggleRecipeSelection('recipe_2');
      expect(viewModel.getSelectionSummary(), equals('2 recept valda'));
    });

    test('should get share message for single recipe', () {
      viewModel.toggleRecipeSelection('recipe_1');
      
      final message = viewModel.getShareMessage();
      
      expect(message, contains('Pasta'));
      expect(message, contains('Anna Andersson'));
      expect(message, contains('delat med'));
    });

    test('should get share message for multiple recipes', () {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');
      
      final message = viewModel.getShareMessage();
      
      expect(message, contains('2 recept'));
      expect(message, contains('Anna Andersson'));
      expect(message, contains('delade med'));
    });

    test('should get empty share message when no selection', () {
      final message = viewModel.getShareMessage();
      
      expect(message, isEmpty);
    });
  });

  group('RecipeSelectionViewModel - Refresh', () {
    test('should refresh recipe list', () async {
      final initialRecipes = [
        RecipeFactory.build(id: 'recipe_1'),
      ];
      
      final updatedRecipes = [
        RecipeFactory.build(id: 'recipe_1'),
        RecipeFactory.build(id: 'recipe_2'),
      ];
      
      mockRecipeService.setRecipeState(recipes: initialRecipes);
      await viewModel.loadRecipes();
      expect(viewModel.allRecipes.length, equals(1));
      
      mockRecipeService.setRecipeState(recipes: updatedRecipes);
      await viewModel.refresh();
      
      expect(viewModel.allRecipes.length, equals(2));
    });
  });
}