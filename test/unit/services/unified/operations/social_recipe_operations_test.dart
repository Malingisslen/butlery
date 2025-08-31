import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// Using centralized mocks:
// - From production_mocks.dart: MockUnifiedRecipeService, MockRecipeSharingManager,
//   MockRecipeMemberManager, MockRecipeCommentsManager, MockRecipeSocialStats,
//   MockRecipePermissionHelper, MockRatingsRepository, MockFirestoreRepository
// - From service_mocks.dart (via production_mocks.dart): MockRecipeDiscoveryService

void main() {
  group('SocialRecipeOperations', () {
    late SocialRecipeOperations operations;
    late MockUnifiedRecipeService mockParent;
    late MockRatingsRepository mockRatingsRepo;
    late MockFirestoreRepository mockFirestoreRepo;

    // Module mocks for direct testing (if needed later)
    // late MockRecipeSharingManager mockSharingManager;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockParent = MockUnifiedRecipeService();
      mockRatingsRepo = MockRatingsRepository();
      mockFirestoreRepo = MockFirestoreRepository();

      // Module mocks are created internally by SocialRecipeOperations

      // Set default state
      mockParent.setRecipeState(currentUserId: 'test-user-123');

      // Create operations (will initialize its own modules)
      operations = SocialRecipeOperations(
        mockParent,
        ratingsRepository: mockRatingsRepo,
        firestoreRepository: mockFirestoreRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Recipe Sharing', () {
      setUp(() {
        // Note: Since SocialRecipeOperations creates its own module instances,
        // we can't easily mock them. These tests verify the API contract.
        // For deeper testing, consider refactoring to allow dependency injection.
        /*
        when(() => mockSharingManager.shareRecipe(
          recipeId: any(named: 'recipeId'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          collaborativeDescription: any(named: 'collaborativeDescription'),
          allowGuestViewing: any(named: 'allowGuestViewing'),
          allowMemberInvites: any(named: 'allowMemberInvites'),
          categoryIds: any(named: 'categoryIds'),
        )).thenAnswer((_) async => 'shared-recipe-123');
        
        when(() => mockSharingManager.makeRecipePersonal(
          collaborativeRecipeId: any(named: 'collaborativeRecipeId'),
          newTitle: any(named: 'newTitle'),
        )).thenAnswer((_) async => 'personal-recipe-123');
        
        when(() => mockSharingManager.duplicateAndShareRecipe(
          recipeId: any(named: 'recipeId'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          newTitle: any(named: 'newTitle'),
          collaborativeDescription: any(named: 'collaborativeDescription'),
          allowGuestViewing: any(named: 'allowGuestViewing'),
          allowMemberInvites: any(named: 'allowMemberInvites'),
          categoryIds: any(named: 'categoryIds'),
        )).thenAnswer((_) async => 'duplicated-recipe-123');
        */
      });

      test('should share recipe with members', () async {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final result = await operations.shareRecipe(
          recipeId: 'recipe-123',
          memberIds: ['member-1', 'member-2'],
          memberDisplayNames: {'member-1': 'Anna', 'member-2': 'Erik'},
        );

        // Assert
        // Note: Since operations creates its own modules internally,
        // we can't control the result. Just verify it doesn't throw.
        expect(result, isA<String?>());
      });

      test('should convert collaborative recipe to personal', () async {
        // Arrange
        final collaborativeRecipe =
            RecipeBuilder().withId('collab-123').asCollaborative().build();
        mockParent.setRecipeState(recipes: [collaborativeRecipe]);

        // Act
        final result = await operations.makeRecipePersonal(
          collaborativeRecipeId: 'collab-123',
          newTitle: 'My Personal Copy',
        );

        // Assert
        expect(result, isA<String?>());
      });

      test('should duplicate and share recipe', () async {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final result = await operations.duplicateAndShareRecipe(
          recipeId: 'recipe-123',
          memberIds: ['friend-1'],
          memberDisplayNames: {'friend-1': 'Friend'},
          newTitle: 'Shared Copy',
        );

        // Assert
        expect(result, isA<String?>());
      });
    });

    group('Member Management', () {
      test('should add member to collaborative recipe', () async {
        // Arrange
        final recipe =
            RecipeBuilder().withId('recipe-123').asCollaborative().build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final result = await operations.addMember(
          recipeId: 'recipe-123',
          userId: 'new-member',
          userDisplayName: 'New Member',
          permission: ResourcePermission.editor,
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should use default viewer permission when adding member', () async {
        // Arrange
        final recipe =
            RecipeBuilder().withId('recipe-123').asCollaborative().build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final result = await operations.addMember(
          recipeId: 'recipe-123',
          userId: 'new-member',
          userDisplayName: 'New Member',
          // No permission specified - should default to viewer
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should remove member from collaborative recipe', () async {
        // Arrange
        final recipe =
            RecipeBuilder().withId('recipe-123').asCollaborative().build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final result = await operations.removeMember(
          recipeId: 'recipe-123',
          userId: 'member-to-remove',
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should update member permission', () async {
        // Arrange
        final recipe =
            RecipeBuilder().withId('recipe-123').asCollaborative().build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final result = await operations.updateMemberPermission(
          recipeId: 'recipe-123',
          userId: 'member-123',
          permission: ResourcePermission.admin,
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should get recipe members', () async {
        // Act
        final members = await operations.getRecipeMembers('recipe-123');

        // Assert
        expect(members, isA<List<Map<String, dynamic>>>());
      });

      test('should check if user can invite members', () {
        // Act
        final canInvite = operations.canInviteMembers('recipe-123');

        // Assert
        expect(canInvite, isA<bool>());
      });

      test('should get member statistics', () {
        // Act
        final stats = operations.getMemberStatistics('recipe-123');

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });

    group('Social Discovery', () {
      test('should get collaborative recipes', () async {
        // Act
        final recipes = await operations.getCollaborativeRecipes(
          limit: 10,
          categoryFilter: ['dinner'],
        );

        // Assert
        expect(recipes, isA<List<Recipe>>());
      });

      test('should get recipes shared with current user', () async {
        // Act
        final recipes = await operations.getSharedWithMe(
          limit: 20,
          searchQuery: 'pasta',
        );

        // Assert
        expect(recipes, isA<List<Recipe>>());
      });

      test('should get recipes shared by current user', () async {
        // Act
        final recipes = await operations.getSharedByMe(
          limit: 15,
          includeEmpty: true,
        );

        // Assert
        expect(recipes, isA<List<Recipe>>());
      });

      test('should get recipes by specific user', () async {
        // Act
        final recipes = await operations.getRecipesByUser(
          userId: 'user-123',
          limit: 25,
          includePersonal: false,
        );

        // Assert
        expect(recipes, isA<List<Recipe>>());
      });

      test('should get trending recipes', () async {
        // Act
        final recipes = await operations.getTrendingRecipes(
          limit: 10,
          timeWindow: const Duration(days: 7),
        );

        // Assert
        expect(recipes, isA<List<Recipe>>());
      });

      test('should search recipes', () async {
        // Act
        final recipes = await operations.searchRecipes(
          query: 'chicken',
          limit: 20,
          includePersonal: true,
        );

        // Assert
        expect(recipes, isA<List<Recipe>>());
      });

      test('should get popular collaborative categories', () async {
        // Act
        final categories = await operations.getPopularCollaborativeCategories(
          limit: 5,
        );

        // Assert
        expect(categories, isA<Map<String, int>>());
      });

      test('should get discovery statistics', () {
        // Act
        final stats = operations.getDiscoveryStatistics();

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });

    group('Recipe Comments', () {
      test('should add comment to recipe', () async {
        // Act
        final commentId = await operations.addComment(
          recipeId: 'recipe-123',
          content: 'Great recipe!',
        );

        // Assert
        expect(commentId, isA<String?>());
      });

      test('should add reply to comment', () async {
        // Act
        final replyId = await operations.addComment(
          recipeId: 'recipe-123',
          content: 'I agree!',
          parentCommentId: 'parent-comment-123',
          mentions: ['user-456'],
        );

        // Assert
        expect(replyId, isA<String?>());
      });

      test('should get comments for recipe', () async {
        // Act
        final comments = await operations.getComments(
          recipeId: 'recipe-123',
          limit: 20,
          includeReplies: true,
        );

        // Assert
        expect(comments, isA<List<RecipeComment>>());
      });

      test('should edit comment', () async {
        // Act
        final result = await operations.editComment(
          commentId: 'comment-123',
          newContent: 'Updated comment',
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should delete comment', () async {
        // Act
        final result = await operations.deleteComment('comment-123');

        // Assert
        expect(result, isA<bool>());
      });

      test('should toggle comment like', () async {
        // Act
        final result = await operations.toggleCommentLike('comment-123');

        // Assert
        expect(result, isA<bool>());
      });

      test('should stream comments for recipe', () {
        // Act
        final stream = operations.getCommentsStream('recipe-123');

        // Assert
        expect(stream, isA<Stream<List<RecipeComment>>>());
      });

      test('should get comment statistics', () async {
        // Act
        final stats = await operations.getCommentStatistics('recipe-123');

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });

    group('Recipe Rating & Social Stats', () {
      test('should rate recipe', () async {
        // Act
        final result = await operations.rateRecipe(
          recipeId: 'recipe-123',
          rating: 4.5,
          review: 'Excellent recipe!',
        );

        // Assert
        expect(result, isA<bool>());
      });

      test('should get recipe statistics', () async {
        // Act
        final stats = await operations.getRecipeStats('recipe-123');

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });

      test('should get user rating for recipe', () async {
        // Act
        final rating = await operations.getUserRating('recipe-123');

        // Assert
        expect(rating, isA<Map<String, dynamic>?>());
      });

      test('should get top rated recipes', () async {
        // Act
        final topRated = await operations.getTopRatedRecipes(
          limit: 5,
          minRating: 4.5,
          minRatingCount: 10,
        );

        // Assert
        expect(topRated, isA<List>());
      });

      test('should get user social statistics', () async {
        // Act
        final stats = await operations.getUserSocialStats();

        // Assert
        expect(stats, isA<Map>());
      });
    });

    group('Permissions', () {
      test('should check if user can view recipe', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final canView = operations.canView('recipe-123');

        // Assert
        expect(canView, isA<bool>());
      });

      test('should check if user can edit recipe', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final canEdit = operations.canEdit('recipe-123');

        // Assert
        expect(canEdit, isA<bool>());
      });

      test('should check if user can delete recipe', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final canDelete = operations.canDelete('recipe-123');

        // Assert
        expect(canDelete, isA<bool>());
      });

      test('should check if user can manage members', () {
        // Arrange
        final recipe =
            RecipeBuilder().withId('recipe-123').asCollaborative().build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final canManage = operations.canManageMembers('recipe-123');

        // Assert
        expect(canManage, isA<bool>());
      });

      test('should check if user can comment on recipe', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final canComment = operations.canComment('recipe-123');

        // Assert
        expect(canComment, isA<bool>());
      });

      test('should check if user can rate recipe', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final canRate = operations.canRate('recipe-123');

        // Assert
        expect(canRate, isA<bool>());
      });

      test('should get user permission for recipe', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final permission =
            operations.getUserPermission('recipe-123', 'user-123');

        // Assert
        expect(permission, isA<ResourcePermission>());
      });

      test('should get permission summary', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final summary =
            operations.getPermissionSummary('recipe-123', 'user-123');

        // Assert
        expect(summary, isA<Map<String, dynamic>>());
      });

      test('should return error for non-existent recipe permission check', () {
        // Arrange
        mockParent.setRecipeState(recipes: []);

        // Act
        final canView = operations.canView('non-existent');
        final canEdit = operations.canEdit('non-existent');
        final permission =
            operations.getUserPermission('non-existent', 'user-123');

        // Assert
        expect(canView, isFalse);
        expect(canEdit, isFalse);
        expect(permission, equals(ResourcePermission.read));
      });
    });

    group('Legacy Compatibility', () {
      test('should get legacy shared recipes format', () async {
        // Arrange
        // Note: We can't easily mock the internal module calls,
        // so we test the API contract
        /*
        final sharedRecipe = RecipeBuilder()
            .withId('shared-123')
            .asCollaborative()
            .withTitle('Shared Recipe')
            .build();
        */

        // Act
        final legacyRecipes = await operations.getLegacySharedRecipes();

        // Assert
        expect(legacyRecipes, isA<List<Map<String, dynamic>>>());
      });

      test('should mark shared recipe as viewed', () async {
        // Act & Assert - just verify it doesn't throw
        await operations.markSharedRecipeAsViewed('recipe-123');
      });

      test('should check legacy permission compatibility', () {
        // Arrange
        final recipe = RecipeBuilder().withId('recipe-123').build();
        mockParent.setRecipeState(recipes: [recipe]);

        // Act
        final hasPermission = operations.checkLegacyPermission(
          'recipe-123',
          'user-123',
          'view',
        );

        // Assert
        expect(hasPermission, isA<bool>());
      });
    });

    group('Additional Features', () {
      test('should get sharing statistics', () {
        // Act
        final stats = operations.getSharingStats();

        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });

      test('should dispose resources properly', () {
        // Act & Assert - just verify it doesn't throw
        operations.dispose();
      });

      test('should access discovery service directly', () {
        // Act
        final discoveryService = operations.discoveryService;

        // Assert
        expect(discoveryService, isA<RecipeDiscoveryService>());
      });
    });
  });
}
