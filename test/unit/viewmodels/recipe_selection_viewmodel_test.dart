import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_selection_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Local pure-Mocks: centralized versions have concrete @overrides blocking when().
class _MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialRecipeOperations extends Mock
    implements SocialRecipeOperations {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockUnifiedRecipeService mockRecipeService;
  late _MockSocialRecipeOperations mockSocialOperations;
  late RecipeSelectionViewModel viewModel;
  late UserProfile targetFriend;

  setUpAll(() async {
    await TestServiceLocator.initialize();

    registerFallbackValue(<String>[]);
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockSocialOperations = _MockSocialRecipeOperations();
    mockRecipeService = _MockUnifiedRecipeService();

    when(() => mockRecipeService.social).thenReturn(mockSocialOperations);
    when(() => mockRecipeService.recipes).thenReturn([]);

    // Default: no previously shared recipes
    when(
      () => mockSocialOperations.getSharedByMe(),
    ).thenAnswer((_) async => []);
    when(
      () => mockSocialOperations.getSharedWithMe(),
    ).thenAnswer((_) async => []);

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
  });

  tearDown(() {
    viewModel.dispose();
  });

  tearDownAll(() async {
    await TestServiceLocator.reset();
  });

  Recipe withSocial(String id, Map<String, ResourcePermission> perms) {
    return RecipeFactory.build(id: id, title: 'Recipe $id').copyWith(
      socialData: RecipeSocialData(
        ownerId: 'test_user',
        ownerDisplayName: 'Test User',
        memberPermissions: perms,
      ),
    );
  }

  group('Initialization', () {
    test('should initialize with default state and compatibility props', () {
      expect(viewModel.targetFriend, equals(targetFriend));
      expect(viewModel.allRecipes, isEmpty);
      expect(viewModel.filteredRecipes, isEmpty);
      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.error, isNull);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.hasError, isFalse);
      expect(viewModel.hasRecipes, isFalse);
      expect(viewModel.selectedRecipeIds, isEmpty);
      expect(viewModel.alreadySharedRecipeIds, isEmpty);
      expect(viewModel.canShare, isFalse);
      // Compatibility properties
      expect(viewModel.hasSelectedRecipes, isFalse);
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.filteredCount, equals(0));
      expect(viewModel.totalCount, equals(0));
    });
  });

  group('Loading Recipes', () {
    test('should load recipes successfully', () async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
        RecipeFactory.build(id: 'recipe_3', title: 'Recipe 3'),
      ];

      when(() => mockRecipeService.recipes).thenReturn(recipes);

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

      final sharedRecipe = withSocial('recipe_1', {
        'friend_123': ResourcePermission.editor,
        'friend_456': ResourcePermission.viewer,
      });

      when(() => mockRecipeService.recipes).thenReturn(recipes);
      when(
        () => mockSocialOperations.getSharedByMe(),
      ).thenAnswer((_) async => [sharedRecipe]);

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

      final sharedWithMe = withSocial('recipe_2', {
        'friend_123': ResourcePermission.viewer,
        'current_user': ResourcePermission.editor,
      });

      when(() => mockRecipeService.recipes).thenReturn(recipes);
      when(
        () => mockSocialOperations.getSharedWithMe(),
      ).thenAnswer((_) async => [sharedWithMe]);

      await viewModel.loadRecipes();

      expect(viewModel.isRecipeAlreadyShared('recipe_2'), isTrue);
    });

    test('should handle loading error', () async {
      when(() => mockRecipeService.recipes).thenThrow(Exception('Load failed'));

      await viewModel.loadRecipes();

      expect(viewModel.hasError, isTrue);
      expect(viewModel.error, equals('Kunde inte ladda recept'));
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.allRecipes, isEmpty);
    });

    test('should handle shared recipes loading error gracefully', () async {
      final recipes = [RecipeFactory.build(id: 'recipe_1')];

      when(() => mockRecipeService.recipes).thenReturn(recipes);
      when(
        () => mockSocialOperations.getSharedByMe(),
      ).thenThrow(Exception('Network error'));

      await viewModel.loadRecipes();

      // Main recipes still loaded even if shared-check failed
      expect(viewModel.allRecipes.length, equals(1));
      expect(viewModel.alreadySharedRecipeIds, isEmpty);
      expect(viewModel.hasError, isFalse);
    });
  });

  group('Search and Filtering', () {
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

      when(() => mockRecipeService.recipes).thenReturn(recipes);
      await viewModel.loadRecipes();
    });

    test(
      'should filter by title, description, ingredients (case-insensitive)',
      () {
        viewModel.updateSearchQuery('PASTA');
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes.first.title, contains('Pasta'));

        viewModel.updateSearchQuery('italian');
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(
          viewModel.filteredRecipes.first.description,
          contains('Italian'),
        );

        viewModel.updateSearchQuery('chicken');
        expect(viewModel.filteredRecipes.length, equals(1));
        expect(viewModel.filteredRecipes.first.title, contains('Chicken'));
      },
    );

    test('should clear search and support compatibility methods', () {
      viewModel.updateSearchQuery('pasta');
      expect(viewModel.filteredRecipes.length, equals(1));
      viewModel.clearSearch();
      expect(viewModel.searchQuery, isEmpty);
      expect(viewModel.filteredRecipes.length, equals(3));

      // Compatibility alias
      viewModel.updateSearch('soup');
      expect(viewModel.searchQuery, equals('soup'));
      expect(viewModel.filteredRecipes.length, equals(1));
    });

    test('should sort unshared recipes before shared ones', () async {
      final sharedRecipe = withSocial('recipe_2', {
        'friend_123': ResourcePermission.viewer,
      });

      when(
        () => mockSocialOperations.getSharedByMe(),
      ).thenAnswer((_) async => [sharedRecipe]);

      await viewModel.loadRecipes();

      // Unshared first (alphabetical), then shared
      expect(viewModel.filteredRecipes[0].id, equals('recipe_3'));
      expect(viewModel.filteredRecipes[1].id, equals('recipe_1'));
      expect(viewModel.filteredRecipes[2].id, equals('recipe_2'));
    });

    test('should sort alphabetically within groups', () {
      // All unshared => pure alphabetical
      expect(viewModel.filteredRecipes[0].title, startsWith('Chicken'));
      expect(viewModel.filteredRecipes[1].title, startsWith('Pasta'));
      expect(viewModel.filteredRecipes[2].title, startsWith('Vegetable'));
    });
  });

  group('Selection Management', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
        RecipeFactory.build(id: 'recipe_3', title: 'Recipe 3'),
      ];

      when(() => mockRecipeService.recipes).thenReturn(recipes);
      await viewModel.loadRecipes();
    });

    test('should toggle, deselect, and multi-select recipes', () {
      expect(viewModel.isRecipeSelected('recipe_1'), isFalse);
      viewModel.toggleRecipeSelection('recipe_1');
      expect(viewModel.isRecipeSelected('recipe_1'), isTrue);
      expect(viewModel.selectedCount, equals(1));
      expect(viewModel.canShare, isTrue);

      // Deselect on second toggle
      viewModel.toggleRecipeSelection('recipe_1');
      expect(viewModel.isRecipeSelected('recipe_1'), isFalse);
      expect(viewModel.selectedCount, equals(0));

      // Multi-select
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');
      viewModel.toggleRecipeSelection('recipe_3');
      expect(viewModel.selectedCount, equals(3));
      expect(viewModel.selectedRecipes.length, equals(3));
    });

    test('should clear selections (both methods)', () {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');
      viewModel.clearSelection();
      expect(viewModel.selectedCount, equals(0));
      expect(viewModel.canShare, isFalse);

      // Compatibility alias
      viewModel.toggleRecipeSelection('recipe_1');
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

  group('Sharing Operations', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Recipe 1'),
        RecipeFactory.build(id: 'recipe_2', title: 'Recipe 2'),
      ];

      when(() => mockRecipeService.recipes).thenReturn(recipes);
      await viewModel.loadRecipes();
    });

    test('should share selected recipes successfully', () async {
      viewModel.toggleRecipeSelection('recipe_1');
      viewModel.toggleRecipeSelection('recipe_2');

      when(
        () => mockSocialOperations.shareRecipe(
          recipeId: any(named: 'recipeId'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
        ),
      ).thenAnswer((_) async => 'share_id');

      final success = await viewModel.shareSelectedRecipes();

      expect(success, isTrue);
      expect(viewModel.isSharing, isFalse);
      expect(viewModel.selectedRecipeIds, isEmpty);
      expect(viewModel.alreadySharedRecipeIds.contains('recipe_1'), isTrue);
      expect(viewModel.alreadySharedRecipeIds.contains('recipe_2'), isTrue);

      verify(
        () => mockSocialOperations.shareRecipe(
          recipeId: 'recipe_1',
          memberIds: ['friend_123'],
          memberDisplayNames: {'friend_123': 'Anna Andersson'},
        ),
      ).called(1);

      verify(
        () => mockSocialOperations.shareRecipe(
          recipeId: 'recipe_2',
          memberIds: ['friend_123'],
          memberDisplayNames: {'friend_123': 'Anna Andersson'},
        ),
      ).called(1);
    });

    test('should handle sharing failure', () async {
      viewModel.toggleRecipeSelection('recipe_1');

      when(
        () => mockSocialOperations.shareRecipe(
          recipeId: any(named: 'recipeId'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
        ),
      ).thenAnswer((_) async => null);

      final success = await viewModel.shareSelectedRecipes();

      expect(success, isFalse);
      expect(viewModel.hasError, isTrue);
      // Production code calls errorCouldNotUpdate('recept') => 'Kunde inte uppdatera recept'
      expect(viewModel.error, contains('Kunde inte'));
      expect(viewModel.isSharing, isFalse);
    });

    test('should not share when no recipes selected', () async {
      final success = await viewModel.shareSelectedRecipes();

      expect(success, isFalse);
      verifyNever(
        () => mockSocialOperations.shareRecipe(
          recipeId: any(named: 'recipeId'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
        ),
      );
    });

    test('should not share when already sharing', () async {
      viewModel.toggleRecipeSelection('recipe_1');

      when(
        () => mockSocialOperations.shareRecipe(
          recipeId: any(named: 'recipeId'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
        ),
      ).thenAnswer((_) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'share_id';
      });

      final future1 = viewModel.shareSelectedRecipes();
      final future2 = viewModel.shareSelectedRecipes();

      final results = await Future.wait([future1, future2]);

      // One succeeds, one is blocked
      expect(results.where((r) => r == true).length, equals(1));
      expect(results.where((r) => r == false).length, equals(1));
    });
  });

  group('Status Messages', () {
    setUp(() async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Pasta'),
        RecipeFactory.build(id: 'recipe_2', title: 'Soup'),
      ];

      when(() => mockRecipeService.recipes).thenReturn(recipes);
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

  group('Refresh', () {
    test('should refresh recipe list', () async {
      final initial = [RecipeFactory.build(id: 'recipe_1')];
      final updated = [
        RecipeFactory.build(id: 'recipe_1'),
        RecipeFactory.build(id: 'recipe_2'),
      ];

      when(() => mockRecipeService.recipes).thenReturn(initial);
      await viewModel.loadRecipes();
      expect(viewModel.allRecipes.length, equals(1));

      when(() => mockRecipeService.recipes).thenReturn(updated);
      await viewModel.refresh();

      expect(viewModel.allRecipes.length, equals(2));
    });
  });
}
