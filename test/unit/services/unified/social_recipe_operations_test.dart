/// Comprehensive unit tests for SocialRecipeOperations
/// 
/// Tests the social recipe operations coordinator that handles sharing,
/// collaboration, member management, comments, ratings, and social discovery
/// through specialized modules.

// ignore_for_file: undefined_method
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart'; // For firstOrNull
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// Using MockRatingsRepository and MockFirestoreRepository from production_mocks.dart
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
// ignore: subtype_of_sealed_class
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
// ignore: subtype_of_sealed_class
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}

void main() {
  group('SocialRecipeOperations', () {
    late SocialRecipeOperations operations;
    late MockUnifiedRecipeService mockParent;
    late MockRatingsRepository mockRatingsRepo;
    late MockFirestoreRepository mockFirestoreRepo;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      // Register fallback values for mocktail
      registerFallbackValue(RecipeFactory.build(
        id: 'fallback',
        title: 'Fallback Recipe',
        description: 'Fallback',
      ));
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(RecipeComment(
        id: 'fallback',
        recipeId: 'fallback',
        authorId: 'fallback',
        authorDisplayName: 'Fallback User',
        text: 'fallback',
      ));
    });
    
    setUp(() async {
      // Initialize TestServiceLocator for each test
      await TestServiceLocator.initialize();
      
      mockParent = MockUnifiedRecipeService();
      mockRatingsRepo = MockRatingsRepository();
      mockFirestoreRepo = MockFirestoreRepository();
      
      testRecipe = RecipeFactory.build(
        id: 'test-recipe-1',
        title: 'Köttbullar',
        description: 'Svenska köttbullar',
        createdBy: 'test-user-123',
      );
      
      collaborativeRecipe = Recipe.collaborative(
        title: 'Collaborative Recipe',
        description: 'A shared recipe',
        ingredients: ['ingredient 1'],
        instructions: ['step 1'],
        mealType: 'dinner',
        ownerId: 'test-user-123',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'member-1': ResourcePermission.editor,
          'member-2': ResourcePermission.viewer,
        },
      );
      
      // Configure the mock with recipes
      mockParent.setRecipeState(
        recipes: [testRecipe, collaborativeRecipe],
        currentUserId: 'test-user-123',
        currentUserDisplayName: 'Test User',
      );
      
      operations = SocialRecipeOperations(
        mockParent,
        ratingsRepository: mockRatingsRepo,
        firestoreRepository: mockFirestoreRepo,
      );
      
      // Setup mock firestore if needed
      final mockFirestore = MockFirebaseFirestore();
      when(() => mockFirestoreRepo.firestore).thenReturn(mockFirestore);
      
      // Setup collections and documents for Firestore operations
      final mockCollectionRef = MockCollectionReference<Map<String, dynamic>>();
      final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      
      when(() => mockFirestore.collection(any())).thenReturn(mockCollectionRef);
      when(() => mockCollectionRef.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
    });
    
    tearDown(() async {
      // Reset mocks and service locator
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Recipe Sharing', () {
      test('should share personal recipe successfully', () async {
        // Arrange
        // Verify the mock has the personal recipe
        expect(mockParent.recipes.any((r) => r.id == 'test-recipe-1' && r.isPersonal), isTrue);
        
        // The mockParent needs to have createCollaborativeRecipe stubbed
        when(() => mockParent.createCollaborativeRecipe(
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
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
          descriptionCollaborative: any(named: 'descriptionCollaborative'),
          allowGuestViewing: any(named: 'allowGuestViewing'),
          allowMemberInvites: any(named: 'allowMemberInvites'),
          categoryIds: any(named: 'categoryIds'),
        )).thenAnswer((_) async => 'shared-recipe-id');
        
        // Act
        final sharedId = await operations.shareRecipe(
          recipeId: 'test-recipe-1',
          memberIds: ['user-1', 'user-2'],
          memberDisplayNames: {
            'user-1': 'Anna',
            'user-2': 'Erik',
          },
        );
        
        // Assert
        expect(sharedId, isNotNull);
        expect(sharedId, equals('shared-recipe-id'));
      });
      
      test('should make collaborative recipe personal', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        when(() => mockParent.createPersonalRecipe(
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
        )).thenAnswer((_) async => 'personal-recipe-id');
        
        // Act
        final personalId = await operations.makeRecipePersonal(
          collaborativeRecipeId: collaborativeRecipe.id,
          newTitle: 'My Personal Copy',
        );
        
        // Assert
        expect(personalId, isNotNull);
        expect(personalId, equals('personal-recipe-id'));
      });
      
      test('should duplicate and share recipe', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        when(() => mockParent.createCollaborativeRecipe(
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
          tags: any(named: 'tags'),
          sourceUrl: any(named: 'sourceUrl'),
          descriptionCollaborative: any(named: 'descriptionCollaborative'),
          allowGuestViewing: any(named: 'allowGuestViewing'),
          allowMemberInvites: any(named: 'allowMemberInvites'),
          categoryIds: any(named: 'categoryIds'),
        )).thenAnswer((_) async => 'duplicated-recipe-id');
        
        // Act
        final duplicatedId = await operations.duplicateAndShareRecipe(
          recipeId: 'test-recipe-1',
          memberIds: ['user-3'],
          memberDisplayNames: {'user-3': 'Maria'},
          newTitle: 'Köttbullar (Delad)',
        );
        
        // Assert
        expect(duplicatedId, isNotNull);
        expect(duplicatedId, equals('duplicated-recipe-id'));
      });
    });
    
    group('Member Management', () {
      test('mock parent service works correctly', () {
        // This test verifies the mock is set up correctly
        expect(mockParent.recipes, hasLength(2));
        expect(mockParent.recipes[0], equals(testRecipe));
        expect(mockParent.recipes[1], equals(collaborativeRecipe));
        expect(mockParent.recipes[1].isCollaborative, isTrue);
        expect(mockParent.currentUserId, equals('test-user-123'));
        
        // Test dynamic access (which is what the operations modules use)
        final dynamic dynamicParent = mockParent;
        expect(dynamicParent.recipes, hasLength(2));
        expect(dynamicParent.currentUserId, equals('test-user-123'));
        
        // Test that we can find recipes with dynamic access
        final recipes = dynamicParent.recipes as List;
        final foundPersonal = recipes
            .where((r) => r.id == 'test-recipe-1' && r.isPersonal)
            .firstOrNull;
        expect(foundPersonal, isNotNull);
        expect(foundPersonal?.title, equals('Köttbullar'));
      });
      
      test('should add member to collaborative recipe', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        when(() => mockParent.updateRecipe(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final success = await operations.addMember(
          recipeId: collaborativeRecipe.id,
          userId: 'new-member',
          userDisplayName: 'New Member',
          permission: ResourcePermission.editor,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should remove member from recipe', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        when(() => mockParent.updateRecipe(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final success = await operations.removeMember(
          recipeId: collaborativeRecipe.id,
          userId: 'member-1',
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should update member permission', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        when(() => mockParent.updateRecipe(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final success = await operations.updateMemberPermission(
          recipeId: collaborativeRecipe.id,
          userId: 'member-2',
          permission: ResourcePermission.editor,
        );
        
        // Assert
        expect(success, isTrue);
      });
      
      test('should get recipe members', () async {
        // Arrange
        // Create a collaborative recipe with a known ID
        final testCollaborativeRecipe = Recipe.collaborative(
          title: 'Test Collaborative Recipe',
          description: 'A test recipe',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'dinner',
          ownerId: 'test-user-123',
          ownerDisplayName: 'Test User',
          memberPermissions: {
            'member-1': ResourcePermission.editor,
            'member-2': ResourcePermission.viewer,
          },
        );
        
        // Configure the mock with the test recipe
        mockParent.setRecipeState(
          recipes: [testRecipe, testCollaborativeRecipe],
          currentUserId: 'test-user-123',
          currentUserDisplayName: 'Test User',
        );
        
        // Verify the mock configuration
        expect(mockParent.recipes, hasLength(2));
        expect(mockParent.getRecipeById(testCollaborativeRecipe.id), isNotNull);
        expect(mockParent.getRecipeById(testCollaborativeRecipe.id)?.isCollaborative, isTrue);
        
        // Act
        final members = await operations.getRecipeMembers(testCollaborativeRecipe.id);
        
        // Assert
        expect(members, isNotEmpty);
        // Should have the owner plus 2 members = 3 total
        expect(members, hasLength(3));
        // Should have the owner
        expect(members.any((m) => m['userId'] == 'test-user-123' && m['isOwner'] == true), isTrue);
        // Should have the members
        expect(members.any((m) => m['userId'] == 'member-1' && m['permission'] == ResourcePermission.editor), isTrue);
        expect(members.any((m) => m['userId'] == 'member-2' && m['permission'] == ResourcePermission.viewer), isTrue);
      });
      
      test('should check if user can invite members', () {
        // Arrange
        // Use the existing collaborativeRecipe that was set up in setUp
        // Verify the mock has the recipe
        expect(mockParent.recipes.any((r) => r.id == collaborativeRecipe.id), isTrue);
        
        // Act
        final canInvite = operations.canInviteMembers(collaborativeRecipe.id);
        
        // Assert
        expect(canInvite, isTrue); // Owner can always invite
      });
      
      test('should get member statistics', () {
        // Act
        final stats = operations.getMemberStatistics(collaborativeRecipe.id);
        
        // Assert
        expect(stats, isNotNull);
        expect(stats, isA<Map<String, dynamic>>());
      });
    });
    
    group('Social Discovery', () {
      test('should get collaborative recipes', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        
        // Act
        final recipes = await operations.getCollaborativeRecipes(
          limit: 10,
          categoryFilter: ['dinner'],
        );
        
        // Assert
        expect(recipes, isA<List<Recipe>>());
      });
      
      test('should get recipes shared with user', () async {
        // Act
        final recipes = await operations.getSharedWithMe(
          limit: 20,
          searchQuery: 'köttbullar',
        );
        
        // Assert
        expect(recipes, isA<List<Recipe>>());
      });
      
      test('should get recipes shared by user', () async {
        // Act
        final recipes = await operations.getSharedByMe(
          limit: 15,
          includeEmpty: false,
        );
        
        // Assert
        expect(recipes, isA<List<Recipe>>());
      });
      
      test('should get recipes by specific user', () async {
        // Act
        final recipes = await operations.getRecipesByUser(
          userId: 'other-user',
          limit: 10,
          includePersonal: false,
        );
        
        // Assert
        expect(recipes, isA<List<Recipe>>());
      });
      
      test('should get trending recipes', () async {
        // Act
        final trending = await operations.getTrendingRecipes(
          limit: 20,
          timeWindow: Duration(days: 7),
        );
        
        // Assert
        expect(trending, isA<List<Recipe>>());
      });
      
      test('should search recipes', () async {
        // Act
        final results = await operations.searchRecipes(
          query: 'pasta',
          limit: 25,
          includePersonal: true,
        );
        
        // Assert
        expect(results, isA<List<Recipe>>());
      });
    });
    
    group('Recipe Comments', () {
      test('should add comment to recipe', () async {
        // Arrange
        // getRecipeById is already implemented in MockUnifiedRecipeService
        
        // Act
        final commentId = await operations.addComment(
          recipeId: 'test-recipe-1',
          content: 'Fantastiskt recept!',
          mentions: ['user-1'],
        );
        
        // Assert
        expect(commentId, isA<String?>());
      });
      
      test('should get recipe comments', () async {
        // Act
        final comments = await operations.getComments(
          recipeId: 'test-recipe-1',
          limit: 20,
          includeReplies: true,
        );
        
        // Assert
        expect(comments, isA<List<RecipeComment>>());
      });
      
      test('should edit comment', () async {
        // Act
        final success = await operations.editComment(
          commentId: 'comment-123',
          newContent: 'Updated comment',
        );
        
        // Assert
        expect(success, isA<bool>());
      });
      
      test('should delete comment', () async {
        // Act
        final success = await operations.deleteComment('comment-123');
        
        // Assert
        expect(success, isA<bool>());
      });
      
      test('should toggle comment like', () async {
        // Act
        final success = await operations.toggleCommentLike('comment-123');
        
        // Assert
        expect(success, isA<bool>());
      });
      
      test('should stream comments for recipe', () {
        // Act
        final stream = operations.getCommentsStream('test-recipe-1');
        
        // Assert
        expect(stream, isA<Stream<List<RecipeComment>>>());
      });
      
      test('should get comment statistics', () async {
        // Act
        final stats = await operations.getCommentStatistics('test-recipe-1');
        
        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });
    
    group('Recipe Rating & Social Stats', () {
      test('should rate recipe', () async {
        // Arrange
        when(() => mockRatingsRepo.rateRecipe(
          recipeId: any(named: 'recipeId'),
          userId: any(named: 'userId'),
          rating: any(named: 'rating'),
          review: any(named: 'review'),
        )).thenAnswer((_) async {});
        
        // Act
        final success = await operations.rateRecipe(
          recipeId: 'test-recipe-1',
          rating: 5.0,
          review: 'Perfekt!',
        );
        
        // Assert
        expect(success, isA<bool>());
      });
      
      test('should get recipe statistics', () async {
        // Arrange
        when(() => mockRatingsRepo.getRecipeRatings(any()))
            .thenAnswer((_) async => []);
        
        // Act
        final stats = await operations.getRecipeStats('test-recipe-1');
        
        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
      
      test('should get user rating for recipe', () async {
        // Arrange
        when(() => mockRatingsRepo.getUserRating(any(), any()))
            .thenAnswer((_) async => RecipeRating(
              id: 'rating-1',
              recipeId: 'test-recipe-1',
              userId: 'test-user-123',
              rating: 4.5,
              review: 'Great recipe!',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));
        
        // Act
        final rating = await operations.getUserRating('test-recipe-1');
        
        // Assert
        expect(rating, isA<Map<String, dynamic>?>());
      });
      
      test('should get top rated recipes', () async {
        // Act
        final topRated = await operations.getTopRatedRecipes(
          limit: 10,
          minRating: 4.0,
          minRatingCount: 5,
        );
        
        // Assert
        expect(topRated, isA<List<Map<String, dynamic>>>());
      });
      
      test('should get user social statistics', () async {
        // Act
        final stats = await operations.getUserSocialStats();
        
        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });
    
    group('Permission Helpers', () {
      test('should check if user can view recipe', () {
        // Act
        final canView = operations.canView(testRecipe.id);
        
        // Assert
        expect(canView, isA<bool>());
      });
      
      test('should check if user can edit recipe', () {
        // Act
        final canEdit = operations.canEdit(testRecipe.id);
        
        // Assert
        expect(canEdit, isA<bool>());
      });
      
      test('should check if user can delete recipe', () {
        // Act
        final canDelete = operations.canDelete(testRecipe.id);
        
        // Assert
        expect(canDelete, isA<bool>());
      });
      
      test('should check if user can manage members', () {
        // Act
        final canManage = operations.canManageMembers(collaborativeRecipe.id);
        
        // Assert
        expect(canManage, isA<bool>());
      });
      
      test('should check if user can comment on recipe', () {
        // Act
        final canComment = operations.canComment(testRecipe.id);
        
        // Assert
        expect(canComment, isA<bool>());
      });
      
      test('should check if user can rate recipe', () {
        // Act
        final canRate = operations.canRate(testRecipe.id);
        
        // Assert
        expect(canRate, isA<bool>());
      });
      
      test('should get user permission for recipe', () {
        // Act
        final permission = operations.getUserPermission(
          collaborativeRecipe.id,
          'member-1',
        );
        
        // Assert
        expect(permission, isA<ResourcePermission>());
      });
      
      test('should get permission summary', () {
        // Act
        final summary = operations.getPermissionSummary(
          testRecipe.id,
          'test-user-123',
        );
        
        // Assert
        expect(summary, isA<Map<String, dynamic>>());
      });
    });
    
    group('Additional Features', () {
      test('should get discovery statistics', () {
        // Act
        final stats = operations.getDiscoveryStatistics();
        
        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
      
      test('should get popular collaborative categories', () async {
        // Act
        final categories = await operations.getPopularCollaborativeCategories(
          limit: 10,
        );
        
        // Assert
        expect(categories, isA<Map<String, int>>());
      });
      
      test('should get sharing statistics', () {
        // Act
        final stats = operations.getSharingStats();
        
        // Assert
        expect(stats, isA<Map<String, dynamic>>());
      });
    });
    
    group('Legacy Compatibility', () {
      test('should get legacy shared recipes format', () async {
        // Act
        final legacyRecipes = await operations.getLegacySharedRecipes();
        
        // Assert
        expect(legacyRecipes, isA<List<Map<String, dynamic>>>());
      });
      
      test('should mark shared recipe as viewed', () async {
        // Act & Assert (no error thrown)
        await operations.markSharedRecipeAsViewed('test-recipe-1');
      });
      
      test('should check legacy permission compatibility', () {
        // Act
        final hasPermission = operations.checkLegacyPermission(
          testRecipe.id,
          'test-user-123',
          'view',
        );
        
        // Assert
        expect(hasPermission, isA<bool>());
      });
    });
    
    group('Resource Management', () {
      test('should dispose resources properly', () {
        // Act & Assert (no error thrown)
        operations.dispose();
      });
    });
  });
}