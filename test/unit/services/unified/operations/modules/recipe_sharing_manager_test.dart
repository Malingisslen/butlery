// test/unit/services/unified/operations/modules/recipe_sharing_manager_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
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

      // Bridge production ServiceLocator to TestServiceLocator
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockNotificationService = MockNotificationService();

      // Create sharing manager instance
      sharingManager = RecipeSharingManager(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCurrentUserDisplayName: () =>
            mockParentService.currentUserDisplayName,
        getRecipes: () => mockParentService.recipes,
        createCollaborativeRecipe: mockParentService.createCollaborativeRecipe,
        createPersonalRecipe: mockParentService.createPersonalRecipe,
        notificationService: mockNotificationService,
      );

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

        // createCollaborativeRecipe has a concrete spy override on
        // MockUnifiedRecipeService; configure success and inspect the
        // captured call list instead of mocktail verify().
        mockParentService.setCollaborativeState(shouldSucceed: true);

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

        // Assert — mock returns 'collab-<title>' on success.
        expect(newId, equals('collab-My Great Recipe'));

        expect(mockParentService.createCollaborativeRecipeCalls, hasLength(1));
        final call = mockParentService.createCollaborativeRecipeCalls.first;
        expect(call['title'], equals('My Great Recipe'));
        expect(call['memberIds'], equals(memberIds));
        expect(call['description'], equals('A wonderful personal recipe'));
        expect(call['ingredients'], equals(['ingredient 1', 'ingredient 2']));
        expect(call['instructions'], equals(['step 1', 'step 2']));
        expect(call['mealType'], equals('Middag'));
        expect(call['descriptionCollaborative'],
            equals('Sharing my recipe with the team'));
        expect(call['allowGuestViewing'], isTrue);
        expect(call['allowMemberInvites'], isFalse);
        expect(call['categoryIds'], equals(['category_1']));

        verify(() => mockNotificationService.sendImmediateNotification(
              targetUserIds: memberIds,
              strategy: NotificationStrategy.recipeShared,
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              imageUrl: any(named: 'imageUrl'),
              actions: any(named: 'actions'),
            )).called(1);
      });

      test('rejects share when projected size would exceed cap (BUT-955)',
          () async {
        // Stage a collaborative recipe already at cap: 200 distinct members.
        // Adding the owner (user_123) via the set union puts the projected
        // size at 201, then the new member pushes it to 202 — over the
        // Recipe.maxSharesPerRecipe ceiling. Cap-guard must short-circuit
        // before any createCollaborativeRecipe call.
        final atCapMembers = <String, ResourcePermission>{
          for (var i = 0; i < 200; i++) 'member_$i': ResourcePermission.viewer,
        };
        final atCapRecipe = Recipe(
          core: testCollaborativeRecipe.core,
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'user_123',
            ownerDisplayName: 'Recipe Owner',
            memberPermissions: atCapMembers,
            allowGuestViewing: false,
            allowMemberInvites: true,
          ),
        );
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          currentUserDisplayName: 'Current User',
          recipes: [atCapRecipe],
          isInitialized: true,
        );

        final newId = await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['new-member-1'],
          memberDisplayNames: {'new-member-1': 'New Member'},
        );

        expect(newId, isNull, reason: 'cap-guard must reject');
        expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
      });

      test(
          'BUT-1056: cap-rejection routes the localized message to onShareError',
          () async {
        // Same at-cap staging as above, but this manager wires an onShareError
        // sink — proving the UI gets the dedicated cap message instead of a
        // bare null it can't distinguish from "not found" / "save failed".
        String? surfacedError;
        final manager = RecipeSharingManager(
          getCurrentUserId: () => mockParentService.currentUserId,
          getCurrentUserDisplayName: () =>
              mockParentService.currentUserDisplayName,
          getRecipes: () => mockParentService.recipes,
          createCollaborativeRecipe:
              mockParentService.createCollaborativeRecipe,
          createPersonalRecipe: mockParentService.createPersonalRecipe,
          notificationService: mockNotificationService,
          onShareError: (msg) => surfacedError = msg,
        );

        final atCapMembers = <String, ResourcePermission>{
          for (var i = 0; i < 200; i++) 'member_$i': ResourcePermission.viewer,
        };
        final atCapRecipe = Recipe(
          core: testCollaborativeRecipe.core,
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'user_123',
            ownerDisplayName: 'Recipe Owner',
            memberPermissions: atCapMembers,
            allowGuestViewing: false,
            allowMemberInvites: true,
          ),
        );
        mockParentService.setRecipeState(
          currentUserId: 'user_123',
          currentUserDisplayName: 'Current User',
          recipes: [atCapRecipe],
          isInitialized: true,
        );

        final newId = await manager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['new-member-1'],
          memberDisplayNames: {'new-member-1': 'New Member'},
        );

        expect(newId, isNull, reason: 'cap-guard still rejects');
        expect(
          surfacedError,
          equals(AppLocale.current
              .errorShareCapReached(Recipe.maxSharesPerRecipe)),
          reason: 'cap message must reach the UI error sink',
        );
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
        // createCollaborativeRecipe is a concrete spy on the mock — assert
        // no call was recorded instead of using mocktail verifyNever().
        expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
      });

      test('should re-share when recipe already collaborative', () async {
        // Production now supports re-sharing an already-collaborative recipe
        // (syncs to shared_recipes collection for the new group instead of
        // failing). The previous "should fail" expectation predated that
        // feature; the recipe id flows through unchanged.
        final newId = await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['user_999'],
          memberDisplayNames: {'user_999': 'New Member'},
        );

        expect(newId, equals('collab_1'));
      });

      test('should handle creation failure', () async {
        // Arrange — concrete spy returns null when shouldSucceed=false
        // (the default), so no stub is needed for the failure path.
        mockParentService.setCollaborativeState(shouldSucceed: false);

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
              personalTagIds: any(named: 'personalTagIds'),
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
              personalTagIds: any(named: 'personalTagIds'),
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
              personalTagIds: any(named: 'personalTagIds'),
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
              personalTagIds: any(named: 'personalTagIds'),
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
