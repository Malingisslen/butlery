import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/repositories/interfaces/social_recipe_repository.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/permission_service.dart';
import '../../../helpers/mock_factories.dart';

// Mocks
class MockSocialRecipeRepository extends Mock implements SocialRecipeRepository {}
class MockUserService extends Mock implements UserService {}
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}
class MockPermissionService extends Mock implements PermissionService {}

void main() {
  late SocialRecipeService sut;
  late MockSocialRecipeRepository mockRepository;
  late MockUserService mockUserService;
  late MockUnifiedRecipeService mockRecipeService;
  late MockPermissionService mockPermissionService;

  setUp(() {
    mockRepository = MockSocialRecipeRepository();
    mockUserService = MockUserService();
    mockRecipeService = MockUnifiedRecipeService();
    mockPermissionService = MockPermissionService();

    // Setup default mocks
    when(() => mockPermissionService.isAuthenticated).thenReturn(true);
    when(() => mockPermissionService.currentUserId).thenReturn('test_user');
    when(() => mockUserService.currentUserId).thenReturn('test_user');

    sut = SocialRecipeService(
      repository: mockRepository,
      userService: mockUserService,
      recipeService: mockRecipeService,
      permissionService: mockPermissionService,
    );
  });

  group('SocialRecipeService - Initialization', () {
    test('should initialize successfully', () async {
      // Given
      when(() => mockRepository.getSharedRecipes(any()))
          .thenAnswer((_) async => []);
      when(() => mockRepository.getSharedMenus(any()))
          .thenAnswer((_) async => []);

      // When
      await sut.initialize();

      // Then
      expect(sut.isLoading, isFalse);
      expect(sut.error, isNull);
    });
  });

  group('SocialRecipeService - Share Operations', () {
    test('should share recipe with friends', () async {
      // Given
      const recipeId = 'recipe123';
      final friendIds = ['friend1', 'friend2'];

      when(() => mockRepository.shareContent(
            fromUserId: any(named: 'fromUserId'),
            toUserId: any(named: 'toUserId'),
            contentType: any(named: 'contentType'),
            contentData: any(named: 'contentData'),
          )).thenAnswer((_) async {});

      // When
      await sut.shareRecipeToFriends(recipeId, friendIds);

      // Then
      verify(() => mockRepository.shareContent(
            fromUserId: any(named: 'fromUserId'),
            toUserId: any(named: 'toUserId'),
            contentType: 'recipe',
            contentData: any(named: 'contentData'),
          )).called(friendIds.length);
    });

    test('should share recipe with groups', () async {
      // Given
      const recipeId = 'recipe123';
      final groupIds = ['group1', 'group2'];

      when(() => mockRepository.shareContent(
            fromUserId: any(named: 'fromUserId'),
            toUserId: any(named: 'toUserId'),
            contentType: any(named: 'contentType'),
            contentData: any(named: 'contentData'),
          )).thenAnswer((_) async {});

      // When
      await sut.shareRecipeToGroups(recipeId, groupIds);

      // Then
      verify(() => mockRepository.shareContent(
            fromUserId: any(named: 'fromUserId'),
            toUserId: any(named: 'toUserId'),
            contentType: 'recipe',
            contentData: any(named: 'contentData'),
          )).called(groupIds.length);
    });

    test('should share menu with friends', () async {
      // Given
      const menuId = 'menu123';
      final friendIds = ['friend1', 'friend2'];

      when(() => mockRepository.shareContent(
            fromUserId: any(named: 'fromUserId'),
            toUserId: any(named: 'toUserId'),
            contentType: any(named: 'contentType'),
            contentData: any(named: 'contentData'),
          )).thenAnswer((_) async {});

      // When
      await sut.shareMenuToFriends(menuId, friendIds);

      // Then
      verify(() => mockRepository.shareContent(
            fromUserId: any(named: 'fromUserId'),
            toUserId: any(named: 'toUserId'),
            contentType: 'menu',
            contentData: any(named: 'contentData'),
          )).called(friendIds.length);
    });
  });

  group('SocialRecipeService - Import Operations', () {
    test('should import shared recipe', () async {
      // Given
      const recipeId = 'shared_recipe123';
      final sharedRecipe = SharedRecipeFactory.build(id: recipeId);

      when(() => mockRepository.getSharedRecipes(any()))
          .thenAnswer((_) async => [sharedRecipe]);
      when(() => mockRecipeService.createRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            imageUrls: any(named: 'imageUrls'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            tags: any(named: 'tags'),
            sourceUrl: any(named: 'sourceUrl'),
          )).thenAnswer((_) async => 'new_recipe_id');
      when(() => mockRepository.markSharedRecipeAsImported(any(), any()))
          .thenAnswer((_) async {});

      // When
      // Note: This test assumes the service can find the recipe by ID from getSharedRecipes
      final result = await sut.importSharedRecipe(recipeId);

      // Then
      expect(result, isTrue);
      verify(() => mockRepository.markSharedRecipeAsImported(recipeId, 'test_user'))
          .called(1);
    });

    test('should import shared menu', () async {
      // Given
      const menuId = 'shared_menu123';
      final sharedMenu = SharedMenuFactory.build(id: menuId);

      when(() => mockRepository.getSharedMenus(any()))
          .thenAnswer((_) async => [sharedMenu]);
      // Remove importSharedMenu call as it's not in interface
      when(() => mockRepository.markSharedMenuAsImported(any(), any()))
          .thenAnswer((_) async {});

      // When
      // Note: This test assumes the service can find the menu by ID from getSharedMenus
      final result = await sut.importSharedMenu(menuId);

      // Then
      expect(result, isTrue);
      verify(() => mockRepository.markSharedMenuAsImported(menuId, 'test_user'))
          .called(1);
    });
  });

  group('SocialRecipeService - View Tracking', () {
    test('should mark shared recipe as viewed', () async {
      // Given
      const recipeId = 'recipe123';
      const userId = 'test_user';

      when(() => mockRepository.markSharedRecipeAsViewed(any(), any()))
          .thenAnswer((_) async {});

      // When
      final result = await sut.markSharedRecipeAsViewed(recipeId, userId);

      // Then
      expect(result, isTrue);
      verify(() => mockRepository.markSharedRecipeAsViewed(recipeId, userId)).called(1);
    });

    test('should mark shared menu as viewed', () async {
      // Given
      const menuId = 'menu123';
      const userId = 'test_user';

      when(() => mockRepository.markSharedMenuAsViewed(any(), any()))
          .thenAnswer((_) async {});

      // When
      final result = await sut.markSharedMenuAsViewed(menuId, userId);

      // Then
      expect(result, isTrue);
      verify(() => mockRepository.markSharedMenuAsViewed(menuId, userId)).called(1);
    });
  });

  group('SocialRecipeService - Dismiss Operations', () {
    test('should dismiss shared recipe', () async {
      // Given
      const recipeId = 'recipe123';

      when(() => mockRepository.dismissSharedRecipe(any(), any()))
          .thenAnswer((_) async {});

      // When
      final result = await sut.dismissSharedRecipe(recipeId);

      // Then
      expect(result, isTrue);
      verify(() => mockRepository.dismissSharedRecipe(recipeId, 'test_user'))
          .called(1);
    });

    test('should undismiss shared recipe', () async {
      // Given
      const recipeId = 'recipe123';

      when(() => mockRepository.undismissSharedRecipe(any(), any()))
          .thenAnswer((_) async {});

      // When
      final result = await sut.undismissSharedRecipe(recipeId);

      // Then
      expect(result, isTrue);
      verify(() => mockRepository.undismissSharedRecipe(recipeId, 'test_user'))
          .called(1);
    });
  });

}