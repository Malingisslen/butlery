/// Unit tests for SocialRecipeSharingService - Handles recipe sharing operations
///
/// Tests sharing operations including:
/// - Sharing recipes with users
/// - Sharing recipes with groups
/// - Unsharing recipes
/// - Permission validation
/// - Group member resolution
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_sharing_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  group('SocialRecipeSharingService', () {
    late SocialRecipeSharingService sharingService;
    late MockUnifiedFriendsService mockFriendsService;
    late String currentUserId;
    late String currentUserDisplayName;
    late String? errorMessage;
    late int notifyCount;
    late Map<String, Recipe> recipeStorage;
    
    setUpAll(() {
      // Centralized fallback values already registered via TestServiceLocator
    });
    
    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Reset test state
      currentUserId = 'test-user-123';
      currentUserDisplayName = 'Test User';
      errorMessage = null;
      notifyCount = 0;
      recipeStorage = {};
      
      // Create mock friends service
      mockFriendsService = MockUnifiedFriendsService();
      
      // Register mock friends service with TestServiceLocator
      TestServiceLocator.registerMock<UnifiedFriendsService>(mockFriendsService);
      
      // Setup default friends service behavior
      when(() => mockFriendsService.getCategoryByIdInternal(any())).thenReturn(null);
      when(() => mockFriendsService.friends).thenReturn([]);
      
      // Create test recipes
      final personalRecipe = RecipeFactory.buildPersonal(
        id: 'personal-recipe-1',
        title: 'Personal Recipe',
        createdBy: currentUserId,
      );
      
      final collaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab-recipe-1',
          title: 'Collaborative Recipe',
          description: 'A shared recipe',
          ingredients: ['Ingredient 1'],
          instructions: ['Step 1'],
          mealType: 'Dinner',
          createdBy: currentUserId,
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: currentUserId,
          ownerDisplayName: currentUserDisplayName,
          memberPermissions: {
            currentUserId: ResourcePermission.admin,
            'user-2': ResourcePermission.editor,
          },
        ),
      );
      
      final otherUserRecipe = RecipeFactory.buildPersonal(
        id: 'other-recipe-1',
        title: 'Other User Recipe',
        createdBy: 'other-user',
      );
      
      recipeStorage['personal-recipe-1'] = personalRecipe;
      recipeStorage['collab-recipe-1'] = collaborativeRecipe;
      recipeStorage['other-recipe-1'] = otherUserRecipe;
      
      // Create service with test dependencies
      sharingService = SocialRecipeSharingService(
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (error) => errorMessage = error,
        notifyListeners: () => notifyCount++,
        getRecipe: (id) async => recipeStorage[id],
        saveRecipe: (recipe) async {
          recipeStorage[recipe.id] = recipe;
          return true;
        },
      );
    });
    
    tearDown(() async {
      // Test infrastructure will handle cleanup
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Share Recipe With Users', () {
      test('should convert personal recipe to collaborative when sharing', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final userIds = ['user-2', 'user-3'];
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          userIds,
          permission,
        );
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final updatedRecipe = recipeStorage[recipeId];
        expect(updatedRecipe, isNotNull);
        expect(updatedRecipe!.isCollaborative, isTrue);
        expect(updatedRecipe.type, equals(RecipeType.collaborative));
        
        // Check permissions
        final memberPermissions = updatedRecipe.socialData?.memberPermissions;
        expect(memberPermissions, isNotNull);
        expect(memberPermissions!.containsKey(currentUserId), isTrue);
        expect(memberPermissions[currentUserId], equals(ResourcePermission.admin));
        expect(memberPermissions.containsKey('user-2'), isTrue);
        expect(memberPermissions['user-2'], equals(permission));
        expect(memberPermissions.containsKey('user-3'), isTrue);
        expect(memberPermissions['user-3'], equals(permission));
      });
      
      test('should add users to existing collaborative recipe', () async {
        // Arrange
        const recipeId = 'collab-recipe-1';
        final newUserIds = ['user-3', 'user-4'];
        const permission = ResourcePermission.editor;
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          newUserIds,
          permission,
        );
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final updatedRecipe = recipeStorage[recipeId];
        expect(updatedRecipe, isNotNull);
        expect(updatedRecipe!.isCollaborative, isTrue);
        
        // Check that existing members are preserved
        final memberPermissions = updatedRecipe.socialData?.memberPermissions;
        expect(memberPermissions, isNotNull);
        expect(memberPermissions!.containsKey(currentUserId), isTrue);
        expect(memberPermissions.containsKey('user-2'), isTrue);
        expect(memberPermissions['user-2'], equals(ResourcePermission.editor)); // Preserved
        
        // Check new members added
        expect(memberPermissions.containsKey('user-3'), isTrue);
        expect(memberPermissions['user-3'], equals(permission));
        expect(memberPermissions.containsKey('user-4'), isTrue);
        expect(memberPermissions['user-4'], equals(permission));
      });
      
      test('should fail when recipe not found', () async {
        // Arrange
        const recipeId = 'non-existent';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          userIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('kunde inte hittas'));
        expect(notifyCount, equals(0));
      });
      
      test('should fail when user lacks permission to share', () async {
        // Arrange
        const recipeId = 'other-recipe-1';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          userIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('behörighet'));
        expect(notifyCount, equals(0));
      });
      
      test('should handle null user ID', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        
        // Override service to return null user ID
        sharingService = SocialRecipeSharingService(
          getCurrentUserId: () => null,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => recipeStorage[id],
          saveRecipe: (recipe) async => true,
        );
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          userIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('inloggad'));
      });
      
      test('should handle save failure', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        
        // Override service with failing save
        sharingService = SocialRecipeSharingService(
          getCurrentUserId: () => currentUserId,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => recipeStorage[id],
          saveRecipe: (recipe) async => false,
        );
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          userIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('Kunde inte spara'));
      });
    });
    
    group('Share Recipe With Groups', () {
      test('should resolve group members and share recipe', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final groupIds = ['group-1'];
        const permission = ResourcePermission.viewer;
        
        // Setup mock friends service with group data
        final category = FriendCategory(
          id: 'group-1',
          ownerId: currentUserId,
          name: 'Test Group',
          friendUserIds: ['group-user-1', 'group-user-2'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final friends = [
          UserProfile(
            uid: 'group-user-1',
            displayName: 'Group User 1',
            email: 'user1@test.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
          UserProfile(
            uid: 'group-user-2',
            displayName: 'Group User 2',
            email: 'user2@test.com',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          ),
        ];
        
        when(() => mockFriendsService.getCategoryByIdInternal('group-1')).thenReturn(category);
        when(() => mockFriendsService.friends).thenReturn(friends);
        
        // Act
        final result = await sharingService.shareRecipeWithGroups(
          recipeId,
          groupIds,
          permission,
        );
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final updatedRecipe = recipeStorage[recipeId];
        expect(updatedRecipe, isNotNull);
        expect(updatedRecipe!.isCollaborative, isTrue);
        
        // Check group members were added
        final memberPermissions = updatedRecipe.socialData?.memberPermissions;
        expect(memberPermissions, isNotNull);
        expect(memberPermissions!.containsKey('group-user-1'), isTrue);
        expect(memberPermissions['group-user-1'], equals(permission));
        expect(memberPermissions.containsKey('group-user-2'), isTrue);
        expect(memberPermissions['group-user-2'], equals(permission));
      });
      
      test('should handle multiple groups', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final groupIds = ['group-1', 'group-2'];
        const permission = ResourcePermission.editor;
        
        // Setup mock friends service with multiple groups
        final category1 = FriendCategory(
          id: 'group-1',
          ownerId: currentUserId,
          name: 'Group 1',
          friendUserIds: ['user-a', 'user-b'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final category2 = FriendCategory(
          id: 'group-2',
          ownerId: currentUserId,
          name: 'Group 2',
          friendUserIds: ['user-c', 'user-d'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        final friends = [
          UserProfile(uid: 'user-a', displayName: 'User A', email: 'a@test.com', joinedAt: DateTime.now(), lastActiveAt: DateTime.now()),
          UserProfile(uid: 'user-b', displayName: 'User B', email: 'b@test.com', joinedAt: DateTime.now(), lastActiveAt: DateTime.now()),
          UserProfile(uid: 'user-c', displayName: 'User C', email: 'c@test.com', joinedAt: DateTime.now(), lastActiveAt: DateTime.now()),
          UserProfile(uid: 'user-d', displayName: 'User D', email: 'd@test.com', joinedAt: DateTime.now(), lastActiveAt: DateTime.now()),
        ];
        
        when(() => mockFriendsService.getCategoryByIdInternal('group-1')).thenReturn(category1);
        when(() => mockFriendsService.getCategoryByIdInternal('group-2')).thenReturn(category2);
        when(() => mockFriendsService.friends).thenReturn(friends);
        
        // Act
        final result = await sharingService.shareRecipeWithGroups(
          recipeId,
          groupIds,
          permission,
        );
        
        // Assert
        expect(result, isTrue);
        
        final updatedRecipe = recipeStorage[recipeId];
        final memberPermissions = updatedRecipe?.socialData?.memberPermissions;
        expect(memberPermissions, isNotNull);
        expect(memberPermissions!.length, equals(5)); // Owner + 4 group members
      });
      
      test('should handle non-existent group', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final groupIds = ['non-existent-group'];
        const permission = ResourcePermission.viewer;
        
        // Mock returns null for non-existent group
        when(() => mockFriendsService.getCategoryByIdInternal('non-existent-group')).thenReturn(null);
        
        // Act
        final result = await sharingService.shareRecipeWithGroups(
          recipeId,
          groupIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('Inga gruppmedlemmar'));
      });
      
      test('should handle empty group', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final groupIds = ['empty-group'];
        const permission = ResourcePermission.viewer;
        
        // Setup empty group
        final emptyCategory = FriendCategory(
          id: 'empty-group',
          ownerId: currentUserId,
          name: 'Empty Group',
          friendUserIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        when(() => mockFriendsService.getCategoryByIdInternal('empty-group')).thenReturn(emptyCategory);
        when(() => mockFriendsService.friends).thenReturn([]);
        
        // Act
        final result = await sharingService.shareRecipeWithGroups(
          recipeId,
          groupIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('Inga gruppmedlemmar'));
      });
    });
    
    group('Unshare Recipe', () {
      test('should convert collaborative recipe back to personal', () async {
        // Arrange
        const recipeId = 'collab-recipe-1';
        
        // Act
        final result = await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final updatedRecipe = recipeStorage[recipeId];
        expect(updatedRecipe, isNotNull);
        expect(updatedRecipe!.isPersonal, isTrue);
        expect(updatedRecipe.type, equals(RecipeType.personal));
        expect(updatedRecipe.socialData, isNull);
      });
      
      test('should fail when recipe not found', () async {
        // Arrange
        const recipeId = 'non-existent';
        
        // Act
        final result = await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('kunde inte hittas'));
      });
      
      test('should fail when recipe is not collaborative', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        
        // Act
        final result = await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('inte delat'));
      });
      
      test('should fail when user is not owner', () async {
        // Arrange
        const recipeId = 'collab-recipe-1';
        
        // Create recipe owned by another user
        recipeStorage[recipeId] = Recipe(
          core: RecipeCore(
            id: recipeId,
            title: 'Other Owner Recipe',
            description: 'Test',
            ingredients: ['Ingredient'],
            instructions: ['Step'],
            mealType: 'Dinner',
            createdBy: 'other-user',
          ),
          type: RecipeType.collaborative,
          socialData: RecipeSocialData(
            ownerId: 'other-user',
            memberPermissions: {
              'other-user': ResourcePermission.admin,
              currentUserId: ResourcePermission.editor,
            },
          ),
        );
        
        // Act
        final result = await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('ägaren'));
      });
      
      test('should handle save failure during unshare', () async {
        // Arrange
        const recipeId = 'collab-recipe-1';
        
        // Override service with failing save
        sharingService = SocialRecipeSharingService(
          getCurrentUserId: () => currentUserId,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => recipeStorage[id],
          saveRecipe: (recipe) async => false,
        );
        
        // Act
        final result = await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('Kunde inte sluta dela'));
      });
    });
    
    group('Query Operations', () {
      test('should check if recipe is shared', () async {
        // Act & Assert - Collaborative recipe
        final isShared = await sharingService.isRecipeShared('collab-recipe-1');
        expect(isShared, isTrue);
        
        // Act & Assert - Personal recipe
        final isPersonal = await sharingService.isRecipeShared('personal-recipe-1');
        expect(isPersonal, isFalse);
        
        // Act & Assert - Non-existent recipe
        final notFound = await sharingService.isRecipeShared('non-existent');
        expect(notFound, isFalse);
      });
      
      test('should get list of shared users', () async {
        // Act - Collaborative recipe
        final sharedUsers = await sharingService.getSharedUsers('collab-recipe-1');
        
        // Assert
        expect(sharedUsers, isNotEmpty);
        expect(sharedUsers.length, equals(2)); // Owner + user-2
        expect(sharedUsers, contains(currentUserId));
        expect(sharedUsers, contains('user-2'));
      });
      
      test('should return empty list for personal recipe', () async {
        // Act
        final sharedUsers = await sharingService.getSharedUsers('personal-recipe-1');
        
        // Assert
        expect(sharedUsers, isEmpty);
      });
      
      test('should return empty list for non-existent recipe', () async {
        // Act
        final sharedUsers = await sharingService.getSharedUsers('non-existent');
        
        // Assert
        expect(sharedUsers, isEmpty);
      });
    });
    
    group('Error Handling', () {
      test('should handle exceptions in shareRecipeWithUsers', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        
        // Override service to throw exception
        sharingService = SocialRecipeSharingService(
          getCurrentUserId: () => currentUserId,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => throw Exception('Database error'),
          saveRecipe: (recipe) async => true,
        );
        
        // Act
        final result = await sharingService.shareRecipeWithUsers(
          recipeId,
          userIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('Database error'));
      });
      
      test('should handle exceptions in shareRecipeWithGroups', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final groupIds = ['group-1'];
        const permission = ResourcePermission.viewer;
        
        // Setup mock to throw
        when(() => mockFriendsService.getCategoryByIdInternal(any())).thenThrow(Exception('Service error'));
        
        // Act
        final result = await sharingService.shareRecipeWithGroups(
          recipeId,
          groupIds,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        // Error message will be about no group members since exception is caught and handled
        expect(errorMessage, anyOf(contains('Service error'), contains('Inga gruppmedlemmar')));
      });
      
      test('should handle exceptions in unshareRecipe', () async {
        // Arrange
        const recipeId = 'collab-recipe-1';
        
        // Override service to throw exception
        sharingService = SocialRecipeSharingService(
          getCurrentUserId: () => currentUserId,
          getCurrentUserDisplayName: () => currentUserDisplayName,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => recipeStorage[id],
          saveRecipe: (recipe) async => throw Exception('Save failed'),
        );
        
        // Act
        final result = await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, contains('Save failed'));
      });
    });
    
    group('State Updates', () {
      test('should notify listeners on successful share', () async {
        // Arrange
        const recipeId = 'personal-recipe-1';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        final initialNotifyCount = notifyCount;
        
        // Act
        await sharingService.shareRecipeWithUsers(recipeId, userIds, permission);
        
        // Assert
        expect(notifyCount, greaterThan(initialNotifyCount));
      });
      
      test('should not notify on failed share', () async {
        // Arrange
        const recipeId = 'non-existent';
        final userIds = ['user-2'];
        const permission = ResourcePermission.viewer;
        final initialNotifyCount = notifyCount;
        
        // Act
        await sharingService.shareRecipeWithUsers(recipeId, userIds, permission);
        
        // Assert
        expect(notifyCount, equals(initialNotifyCount));
      });
      
      test('should notify listeners on successful unshare', () async {
        // Arrange
        const recipeId = 'collab-recipe-1';
        final initialNotifyCount = notifyCount;
        
        // Act
        await sharingService.unshareRecipe(recipeId);
        
        // Assert
        expect(notifyCount, greaterThan(initialNotifyCount));
      });
    });
  });
}