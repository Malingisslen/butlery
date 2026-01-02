// test/unit/services/unified/operations/modules/recipe_sharing_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeSharingManager', () {
    late MockUnifiedRecipeService mockParentService;
    late MockNotificationService mockNotificationService;
    late RecipeSharingManager sharingManager;
    late Recipe testPersonalRecipe;
    late Recipe testCollaborativeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(NotificationStrategy.recipeShared);
      registerFallbackValue(NotificationAction.viewRecipe);
      registerFallbackValue(<NotificationAction>[]);
      registerFallbackValue(Recipe(
        core: RecipeCore(
          id: 'test',
          title: 'Test',
          description: 'Test',
          ingredients: [],
          instructions: [],
          mealType: 'Test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      ));
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockNotificationService = MockNotificationService();

      // Create sharing manager instance
      sharingManager =
          RecipeSharingManager(mockParentService, mockNotificationService);

      // Create test data
      testPersonalRecipe = Recipe(
        core: RecipeCore(
          id: 'personal_1',
          title: 'My Great Recipe',
          description: 'A wonderful personal recipe',
          ingredients: ['ingredient 1', 'ingredient 2'],
          instructions: ['step 1', 'step 2'],
          mealType: 'Middag',
          portions: 4,
          timeMinutes: 30,
          rating: 4.5,
          personalTagIds: ['swedish', 'traditional'],
          sourceUrl: 'https://example.com',
          imageUrls: ['image1.jpg', 'image2.jpg'],
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      );

      testCollaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab_1',
          title: 'Shared Team Recipe',
          description: 'A collaborative recipe',
          ingredients: ['shared ingredient'],
          instructions: ['shared step'],
          mealType: 'Lunch',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
          },
          allowGuestViewing: false,
          allowMemberInvites: true,
          descriptionCollaborative: 'Team collaboration recipe',
        ),
      );

      // Configure mocks using setRecipeState method
      mockParentService.setRecipeState(
        currentUserId: 'user_123',
        currentUserDisplayName: 'Current User',
        recipes: [testPersonalRecipe, testCollaborativeRecipe],
        isInitialized: true,
      );
      // No need to stub recipes - it's a concrete getter that returns the configured value
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Recipe Sharing (Personal to Collaborative)', () {
      test('should share personal recipe successfully', () async {
        // Arrange
        final memberIds = ['user_456', 'user_789'];
        final memberDisplayNames = {
          'user_456': 'Member One',
          'user_789': 'Member Two',
        };

        when(() => mockParentService.createCollaborativeRecipe(
              title: any(named: 'title'),
              memberIds: any(named: 'memberIds'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              imageUrls: any(named: 'imageUrls'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              descriptionCollaborative: any(named: 'descriptionCollaborative'),
              allowGuestViewing: any(named: 'allowGuestViewing'),
              allowMemberInvites: any(named: 'allowMemberInvites'),
              categoryIds: any(named: 'categoryIds'),
            )).thenAnswer((_) async => 'new_collab_id');

        when(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              imageUrl: any(named: 'imageUrl'),
              actions: any(named: 'actions'),
            )).thenAnswer((_) async {});

        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'personal_1',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
          collaborativeDescription: 'Sharing my recipe with the team',
          allowGuestViewing: true,
          allowMemberInvites: false,
          categoryIds: ['category_1'],
        );

        // Assert
        expect(newId, equals('new_collab_id'));

        verify(() => mockParentService.createCollaborativeRecipe(
              title: 'My Great Recipe',
              memberIds: memberIds,
              description: 'A wonderful personal recipe',
              ingredients: ['ingredient 1', 'ingredient 2'],
              instructions: ['step 1', 'step 2'],
              imageUrls: ['image1.jpg', 'image2.jpg'],
              mealType: 'Middag',
              portions: 4,
              timeMinutes: 30,
              rating: 4.5,
              personalTagIds: ['swedish', 'traditional'],
              sourceUrl: 'https://example.com',
              descriptionCollaborative: 'Sharing my recipe with the team',
              allowGuestViewing: true,
              allowMemberInvites: false,
              categoryIds: ['category_1'],
            )).called(1);

        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: memberIds,
              strategy: NotificationStrategy.recipeShared,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              imageUrl: any(named: 'imageUrl'),
              actions: any(named: 'actions'),
            )).called(1);
      });

      test('should fail when recipe not found', () async {
        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'nonexistent',
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Member'},
        );

        // Assert
        expect(newId, isNull);
        verifyNever(() => mockParentService.createCollaborativeRecipe(
              title: any(named: 'title'),
              memberIds: any(named: 'memberIds'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              imageUrls: any(named: 'imageUrls'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              descriptionCollaborative: any(named: 'descriptionCollaborative'),
              allowGuestViewing: any(named: 'allowGuestViewing'),
              allowMemberInvites: any(named: 'allowMemberInvites'),
              categoryIds: any(named: 'categoryIds'),
            ));
      });

      test('should fail when recipe already collaborative', () async {
        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['user_999'],
          memberDisplayNames: {'user_999': 'New Member'},
        );

        // Assert
        expect(newId, isNull);
      });

      test('should handle creation failure', () async {
        // Arrange
        when(() => mockParentService.createCollaborativeRecipe(
              title: any(named: 'title'),
              memberIds: any(named: 'memberIds'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              imageUrls: any(named: 'imageUrls'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              descriptionCollaborative: any(named: 'descriptionCollaborative'),
              allowGuestViewing: any(named: 'allowGuestViewing'),
              allowMemberInvites: any(named: 'allowMemberInvites'),
              categoryIds: any(named: 'categoryIds'),
            )).thenAnswer((_) async => null);

        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'personal_1',
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Member'},
        );

        // Assert
        expect(newId, isNull);
      });
    });

    group('Recipe Personal Copy (Collaborative to Personal)', () {
      test('should make personal copy of collaborative recipe', () async {
        // Arrange
        when(() => mockParentService.createPersonalRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              imageUrls: any(named: 'imageUrls'),
            )).thenAnswer((_) async => 'new_personal_id');

        // Act
        final newId = await sharingManager.makeRecipePersonal(
          collaborativeRecipeId: 'collab_1',
          newTitle: 'My Copy',
        );

        // Assert
        expect(newId, equals('new_personal_id'));

        verify(() => mockParentService.createPersonalRecipe(
              title: 'My Copy',
              description: 'A collaborative recipe',
              ingredients: ['shared ingredient'],
              instructions: ['shared step'],
              mealType: 'Lunch',
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              imageUrls: any(named: 'imageUrls'),
            )).called(1);
      });

      test('should use default title when not specified', () async {
        // Arrange
        when(() => mockParentService.createPersonalRecipe(
              title: any(named: 'title'),
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              imageUrls: any(named: 'imageUrls'),
            )).thenAnswer((_) async => 'new_personal_id');

        // Act
        final newId = await sharingManager.makeRecipePersonal(
          collaborativeRecipeId: 'collab_1',
        );

        // Assert
        expect(newId, equals('new_personal_id'));
        verify(() => mockParentService.createPersonalRecipe(
              title: 'Shared Team Recipe (Min kopia)',
              description: any(named: 'description'),
              ingredients: any(named: 'ingredients'),
              instructions: any(named: 'instructions'),
              mealType: any(named: 'mealType'),
              portions: any(named: 'portions'),
              timeMinutes: any(named: 'timeMinutes'),
              rating: any(named: 'rating'),
              personalTagIds: any(named: 'personalTags'),
              sourceUrl: any(named: 'sourceUrl'),
              imageUrls: any(named: 'imageUrls'),
            )).called(1);
      });

      test('should fail when recipe not collaborative', () async {
        // Act
        final newId = await sharingManager.makeRecipePersonal(
          collaborativeRecipeId: 'personal_1',
        );

        // Assert
        expect(newId, isNull);
      });
    });

    // Share state management and bulk operations are not implemented in the actual RecipeSharingManager class
  });
}
