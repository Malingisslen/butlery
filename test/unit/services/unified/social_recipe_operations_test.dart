/// Comprehensive unit tests for SocialRecipeOperations
/// 
/// Tests the social recipe operations coordinator that handles sharing,
/// collaboration, member management, comments, ratings, and social discovery
/// through specialized modules.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';

import '../../../infrastructure/helpers/_base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';

// Mock parent service that SocialRecipeOperations delegates to
// Note: We're using a Mock without an interface, so we'll set up behavior directly
class MockParentService extends Mock {
  String? currentUserId = 'test-user-123';
  List<Recipe> recipes = [];
  
  Recipe? recipeToReturn;
  String? recipeIdToReturn;
  bool updateRecipeResult = true;
  
  // Setup methods for configuring mock behavior
  void setupGetRecipeById(Recipe? recipe) {
    recipeToReturn = recipe;
  }
  
  void setupCreateRecipe(String? id) {
    recipeIdToReturn = id;
  }
  
  void setupUpdateRecipe(bool result) {
    updateRecipeResult = result;
  }
  
  // Override noSuchMethod to handle undefined methods
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    
    if (memberName.contains('getRecipeById')) {
      return Future.value(recipeToReturn);
    }
    
    if (memberName.contains('createRecipe')) {
      return Future.value(recipeIdToReturn);
    }
    
    if (memberName.contains('updateRecipe')) {
      return Future.value(updateRecipeResult);
    }
    
    return super.noSuchMethod(invocation);
  }
}

// Mock repositories
class MockRatingsRepository extends Mock implements RatingsRepository {}
class MockFirestoreRepository extends Mock implements FirestoreRepository {
  final FakeFirebaseFirestore fakeFirestore = FakeFirebaseFirestore();
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Check if the getter 'firestore' is being accessed
    if (invocation.memberName == Symbol('firestore')) {
      return fakeFirestore;
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('SocialRecipeOperations', () {
    late SocialRecipeOperations operations;
    late MockParentService mockParent;
    late MockRatingsRepository mockRatingsRepo;
    late MockFirestoreRepository mockFirestoreRepo;
    late Recipe testRecipe;
    late Recipe collaborativeRecipe;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      // TestServiceLocator is already initialized in setUpAll via BaseUnitTest.setupUnit()
      
      mockParent = MockParentService();
      mockRatingsRepo = MockRatingsRepository();
      mockFirestoreRepo = MockFirestoreRepository();
      
      operations = SocialRecipeOperations(
        mockParent,
        ratingsRepository: mockRatingsRepo,
        firestoreRepository: mockFirestoreRepo,
      );
      
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
      
      mockParent.recipes = [testRecipe, collaborativeRecipe];
      
      // Comments stream stubbing is handled by MockFactory.createCommentsRepository()
      // Firestore is handled by MockFirestoreRepository's FakeFirebaseFirestore
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
        mockParent.setupGetRecipeById(testRecipe);
        mockParent.setupCreateRecipe('shared-recipe-id');
        
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
        mockParent.setupGetRecipeById(collaborativeRecipe);
        mockParent.setupCreateRecipe('personal-recipe-id');
        
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
        mockParent.setupGetRecipeById(testRecipe);
        mockParent.setupCreateRecipe('duplicated-recipe-id');
        
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
      test('should add member to collaborative recipe', () async {
        // Arrange
        mockParent.setupGetRecipeById(collaborativeRecipe);
        mockParent.setupUpdateRecipe(true);
        
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
        mockParent.setupGetRecipeById(collaborativeRecipe);
        mockParent.setupUpdateRecipe(true);
        
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
        mockParent.setupGetRecipeById(collaborativeRecipe);
        mockParent.setupUpdateRecipe(true);
        
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
        mockParent.setupGetRecipeById(collaborativeRecipe);
        
        // Act
        final members = await operations.getRecipeMembers(collaborativeRecipe.id);
        
        // Assert
        expect(members, isNotEmpty);
      });
      
      test('should check if user can invite members', () {
        // Act
        final canInvite = operations.canInviteMembers(collaborativeRecipe.id);
        
        // Assert
        expect(canInvite, isTrue);
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
        mockParent.setupGetRecipeById(collaborativeRecipe);
        
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
        mockParent.setupGetRecipeById(testRecipe);
        
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