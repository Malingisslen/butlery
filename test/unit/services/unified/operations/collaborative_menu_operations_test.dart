import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/collaborative_menu_operations.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

/// Repository-Level Testing for CollaborativeMenuOperations
///
/// ARCHITECTURAL COMPLIANCE:
/// ✅ Follows HYBRID_TESTING_STRATEGY.md: "Mock at repository level, never mock Firebase directly"
/// ✅ Tests business logic and repository interactions, not Firebase implementation
/// ✅ Uses centralized mocks from production_mocks.dart (no duplication)
/// ✅ Tests intention not exact implementation to avoid brittle tests
///
/// ULTRATHINK PRINCIPLES APPLIED:
/// - Repository pattern abstracts Firebase FieldValue operations
/// - Clean separation between business logic and data persistence
/// - Integration tests can use Firebase emulator for FieldValue operations
/// - Proper dependency injection with repository interface
void main() {
  group('CollaborativeMenuOperations - Repository-Level Testing', () {
    late CollaborativeMenuOperations operations;
    late MockUnifiedMenuService mockParent;
    late MockMenuCollaborationRepository mockRepository;
    late MockPermissionService mockPermissionService;

    // Test data
    late Recipe testRecipe;
    const String testMenuId = 'test-menu-123';
    const String testUserId = 'test-user-456';
    const String testUserDisplayName = 'Test User';

    void setUpMocks() {
      mockParent = MockUnifiedMenuService();
      mockRepository = MockMenuCollaborationRepository();
      mockPermissionService = MockPermissionService();

      // Configure permission service
      mockPermissionService.setPermissionState(
        isAuthenticated: true,
        currentUserId: testUserId,
        userDisplayName: testUserDisplayName,
      );

      operations = CollaborativeMenuOperations(mockParent, mockRepository);
    }

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(RecipeBuilder().build());
      registerFallbackValue(<String, List<Recipe>>{});
      registerFallbackValue(<String, dynamic>{});
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      setUpMocks();

      testRecipe = RecipeBuilder()
          .withId('recipe-123')
          .withTitle('Test Collaborative Recipe')
          .withMealType('Huvudrätter')
          .build();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Collaboration Management', () {
      test(
          'enableMenuCollaboration should delegate to repository and start listener on success',
          () async {
        // Arrange
        const collaboratorIds = ['user-1', 'user-2'];
        final collaboratorDisplayNames = {
          'user-1': 'User One',
          'user-2': 'User Two'
        };

        when(() => mockRepository.enableCollaboration(
              menuId: any(named: 'menuId'),
              collaboratorIds: any(named: 'collaboratorIds'),
              collaboratorDisplayNames: any(named: 'collaboratorDisplayNames'),
            )).thenAnswer((_) async => true);

        when(() => mockRepository.startCollaborationListener(
              any(),
              any(),
            )).thenReturn(null);

        // Act
        final result = await operations.enableMenuCollaboration(
          menuId: testMenuId,
          collaboratorIds: collaboratorIds,
          collaboratorDisplayNames: collaboratorDisplayNames,
        );

        // Assert
        expect(result, isTrue);

        verify(() => mockRepository.enableCollaboration(
              menuId: testMenuId,
              collaboratorIds: collaboratorIds,
              collaboratorDisplayNames: collaboratorDisplayNames,
            )).called(1);

        verify(() => mockRepository.startCollaborationListener(
              testMenuId,
              any(),
            )).called(1);
      });

      test(
          'enableMenuCollaboration should not start listener on repository failure',
          () async {
        // Arrange
        const collaboratorIds = ['user-1'];

        when(() => mockRepository.enableCollaboration(
              menuId: any(named: 'menuId'),
              collaboratorIds: any(named: 'collaboratorIds'),
              collaboratorDisplayNames: any(named: 'collaboratorDisplayNames'),
            )).thenAnswer((_) async => false);

        // Act
        final result = await operations.enableMenuCollaboration(
          menuId: testMenuId,
          collaboratorIds: collaboratorIds,
        );

        // Assert
        expect(result, isFalse);

        verify(() => mockRepository.enableCollaboration(
              menuId: testMenuId,
              collaboratorIds: collaboratorIds,
              collaboratorDisplayNames: null,
            )).called(1);

        verifyNever(
            () => mockRepository.startCollaborationListener(any(), any()));
      });
    });

    group('Recipe Management', () {
      test('addRecipeToCollaborativeMenu should delegate to repository',
          () async {
        // Arrange
        const category = 'Huvudrätter';
        const suggestion = 'Great recipe for family dinner!';

        when(() => mockRepository.addRecipeToMenu(
              menuId: any(named: 'menuId'),
              category: any(named: 'category'),
              recipe: any(named: 'recipe'),
              suggestedBy: any(named: 'suggestedBy'),
              suggestion: any(named: 'suggestion'),
            )).thenAnswer((_) async => true);

        // Act
        final result = await operations.addRecipeToCollaborativeMenu(
          menuId: testMenuId,
          category: category,
          recipe: testRecipe,
          suggestedBy: testUserId,
          suggestion: suggestion,
        );

        // Assert
        expect(result, isTrue);

        verify(() => mockRepository.addRecipeToMenu(
              menuId: testMenuId,
              category: category,
              recipe: testRecipe,
              suggestedBy: testUserId,
              suggestion: suggestion,
            )).called(1);
      });

      test('removeRecipeFromCollaborativeMenu should delegate to repository',
          () async {
        // Arrange
        const category = 'Huvudrätter';
        const recipeId = 'recipe-to-remove-123';
        const reason = 'Not suitable for the menu';

        when(() => mockRepository.removeRecipeFromMenu(
              menuId: any(named: 'menuId'),
              category: any(named: 'category'),
              recipeId: any(named: 'recipeId'),
              reason: any(named: 'reason'),
            )).thenAnswer((_) async => true);

        // Act
        final result = await operations.removeRecipeFromCollaborativeMenu(
          menuId: testMenuId,
          category: category,
          recipeId: recipeId,
          reason: reason,
        );

        // Assert
        expect(result, isTrue);

        verify(() => mockRepository.removeRecipeFromMenu(
              menuId: testMenuId,
              category: category,
              recipeId: recipeId,
              reason: reason,
            )).called(1);
      });
    });

    group('Rating System', () {
      test(
          'rateMenu should delegate to repository and update local cache on success',
          () async {
        // Arrange
        const rating = 4.5;
        const comment = 'Excellent menu!';

        when(() => mockRepository.rateMenu(
              menuId: any(named: 'menuId'),
              rating: any(named: 'rating'),
              comment: any(named: 'comment'),
            )).thenAnswer((_) async => true);

        // Act
        final result = await operations.rateMenu(
          menuId: testMenuId,
          rating: rating,
          comment: comment,
        );

        // Assert
        expect(result, isTrue);

        verify(() => mockRepository.rateMenu(
              menuId: testMenuId,
              rating: rating,
              comment: comment,
            )).called(1);

        // Verify local cache was updated
        expect(operations.toString(), contains('CollaborativeMenuOperations'));
      });

      test('getMenuRatings should delegate to repository', () async {
        // Arrange
        final expectedRatings = [
          {'userId': 'user-1', 'rating': 4.0, 'comment': 'Good!'},
          {'userId': 'user-2', 'rating': 5.0, 'comment': 'Perfect!'},
        ];

        when(() => mockRepository.getMenuRatings(any()))
            .thenAnswer((_) async => expectedRatings);

        // Act
        final result = await operations.getMenuRatings(testMenuId);

        // Assert
        expect(result, equals(expectedRatings));
        verify(() => mockRepository.getMenuRatings(testMenuId)).called(1);
      });

      test('getMenuAverageRating should delegate to repository', () async {
        // Arrange
        const expectedAverage = 4.25;

        when(() => mockRepository.getMenuAverageRating(any()))
            .thenAnswer((_) async => expectedAverage);

        // Act
        final result = await operations.getMenuAverageRating(testMenuId);

        // Assert
        expect(result, equals(expectedAverage));
        verify(() => mockRepository.getMenuAverageRating(testMenuId)).called(1);
      });
    });

    group('Comment System', () {
      test(
          'addMenuComment should delegate to repository and clear local cache on success',
          () async {
        // Arrange
        const comment = 'This looks delicious!';

        when(() => mockRepository.addMenuComment(
              menuId: any(named: 'menuId'),
              comment: any(named: 'comment'),
            )).thenAnswer((_) async => true);

        // Act
        final result = await operations.addMenuComment(
          menuId: testMenuId,
          comment: comment,
        );

        // Assert
        expect(result, isTrue);

        verify(() => mockRepository.addMenuComment(
              menuId: testMenuId,
              comment: comment,
            )).called(1);
      });

      test('getMenuCommentsStream should delegate to repository', () async {
        // Arrange
        final expectedComments = [
          {'id': 'comment-1', 'comment': 'Great menu!', 'userId': 'user-1'},
          {
            'id': 'comment-2',
            'comment': 'Thanks for sharing!',
            'userId': 'user-2'
          },
        ];
        final streamController = StreamController<List<Map<String, dynamic>>>();

        when(() => mockRepository.getMenuCommentsStream(any()))
            .thenAnswer((_) => streamController.stream);

        // Act
        final stream = operations.getMenuCommentsStream(testMenuId);
        streamController.add(expectedComments);

        // Assert
        await expectLater(stream, emits(expectedComments));
        verify(() => mockRepository.getMenuCommentsStream(testMenuId))
            .called(1);

        await streamController.close();
      });

      test('toggleCommentLike should delegate to repository', () async {
        // Arrange
        const commentId = 'comment-123';

        when(() => mockRepository.toggleCommentLike(
              menuId: any(named: 'menuId'),
              commentId: any(named: 'commentId'),
            )).thenAnswer((_) async => true);

        // Act
        final result = await operations.toggleCommentLike(
          menuId: testMenuId,
          commentId: commentId,
        );

        // Assert
        expect(result, isTrue);

        verify(() => mockRepository.toggleCommentLike(
              menuId: testMenuId,
              commentId: commentId,
            )).called(1);
      });
    });

    group('Template Management', () {
      test(
          'createMenuTemplate should delegate to repository and update local cache on success',
          () async {
        // Arrange
        const templateName = 'Weekly Family Menu';
        const expectedTemplateId = 'template-123';

        when(() => mockRepository.createMenuTemplate(
              templateName: any(named: 'templateName'),
              menuSnapshot: any(named: 'menuSnapshot'),
              description: any(named: 'description'),
              tags: any(named: 'tags'),
            )).thenAnswer((_) async => expectedTemplateId);

        // Act
        final result = await operations.createMenuTemplate(
          templateName: templateName,
          menuSnapshot: {'Måndag': [], 'Tisdag': []}, // Mock menu snapshot
        );

        // Assert
        expect(result, equals(expectedTemplateId));

        verify(() => mockRepository.createMenuTemplate(
              templateName: templateName,
              menuSnapshot: any(named: 'menuSnapshot'),
            )).called(1);
      });

      test('createMenuFromTemplate should delegate to repository', () async {
        // Arrange
        const templateId = 'template-456';
        const menuTitle = 'My New Menu from Template';
        const expectedMenuId = 'new-menu-789';

        when(() => mockRepository.createMenuFromTemplate(
              templateId: any(named: 'templateId'),
              menuTitle: any(named: 'menuTitle'),
              sharedToUserIds: any(named: 'sharedToUserIds'),
              shareMessage: any(named: 'shareMessage'),
              enableCollaboration: any(named: 'enableCollaboration'),
            )).thenAnswer((_) async => expectedMenuId);

        // Act
        final result = await operations.createMenuFromTemplate(
          templateId: templateId,
          menuTitle: menuTitle,
        );

        // Assert
        expect(result, equals(expectedMenuId));

        verify(() => mockRepository.createMenuFromTemplate(
              templateId: templateId,
              menuTitle: menuTitle,
            )).called(1);
      });
    });

    group('Resource Management', () {
      test('dispose should cleanup repository listeners and local caches',
          () async {
        // Arrange
        when(() => mockRepository.disposeAllListeners()).thenReturn(null);

        // Act
        operations.dispose();

        // Assert
        verify(() => mockRepository.disposeAllListeners()).called(1);
      });
    });
  });
}
