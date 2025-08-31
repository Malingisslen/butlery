/// Unit tests for SocialRecipeMembershipService - Manages recipe membership
///
/// Tests membership operations including:
/// - Adding members with permissions
/// - Removing members
/// - Updating member permissions
/// - Permission validation
/// - Error handling for invalid operations
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_membership_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

// Test infrastructure
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/factories/recipe_factory.dart';

void main() {
  group('SocialRecipeMembershipService', () {
    late SocialRecipeMembershipService membershipService;
    late Map<String, Recipe> testRecipesMap;
    late String currentUserId;
    late String? errorMessage;
    late int notifyCount;
    
    setUpAll(() {
      // Register fallback values
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(RecipeFactory.build());
    });
    
    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Reset test state
      currentUserId = 'admin-user-123';
      errorMessage = null;
      notifyCount = 0;
      testRecipesMap = {};
      
      // Create test recipes with proper structure
      final adminRecipe = RecipeFactory.buildCollaborative(
        id: 'recipe-1',
        title: 'Admin Recipe',
        permissions: {
          currentUserId: ResourcePermission.admin,
          'user-2': ResourcePermission.editor,
          'user-3': ResourcePermission.viewer,
        },
      );
      
      final editorRecipe = RecipeFactory.buildCollaborative(
        id: 'recipe-2',
        title: 'Editor Recipe',
        permissions: {
          'owner-user': ResourcePermission.admin,
          currentUserId: ResourcePermission.editor,
          'user-3': ResourcePermission.viewer,
        },
      );
      
      final viewerRecipe = RecipeFactory.buildCollaborative(
        id: 'recipe-3',
        title: 'Viewer Recipe',
        permissions: {
          'owner-user': ResourcePermission.admin,
          currentUserId: ResourcePermission.viewer,
        },
      );
      
      testRecipesMap['recipe-1'] = adminRecipe;
      testRecipesMap['recipe-2'] = editorRecipe;
      testRecipesMap['recipe-3'] = viewerRecipe;
      
      // Create service with test dependencies
      membershipService = SocialRecipeMembershipService(
        getCurrentUserId: () => currentUserId,
        setError: (error) => errorMessage = error,
        notifyListeners: () => notifyCount++,
        getRecipe: (id) async {
          return testRecipesMap[id];
        },
        saveRecipe: (recipe) async {
          testRecipesMap[recipe.id] = recipe;
          return true;
        },
      );
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Service Initialization', () {
      test('should initialize with required dependencies', () {
        // Assert
        expect(membershipService, isNotNull);
        expect(membershipService.serviceName, equals('SocialRecipeMembershipService'));
      });
    });
    
    group('Add Member', () {
      test('should add member with specified permission when admin', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newUserId = 'new-member';
        const permission = ResourcePermission.editor;
        
        // Act
        final result = await membershipService.addMemberToRecipe(
          recipeId,
          newUserId,
          permission,
        );
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?.containsKey(newUserId), isTrue);
        expect(memberPermissions?[newUserId], equals(permission));
      });
      
      test('should fail when non-admin tries to add member', () async {
        // Arrange
        const recipeId = 'recipe-2'; // User is editor, not admin
        const newUserId = 'new-member';
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await membershipService.addMemberToRecipe(
          recipeId,
          newUserId,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        // Error is caught internally, message not propagated
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?.containsKey(newUserId), isFalse);
      });
      
      test('should validate user ID', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const invalidUserId = ''; // Empty user ID
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await membershipService.addMemberToRecipe(
          recipeId,
          invalidUserId,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        expect(errorMessage, isNotNull);
      });
      
      test('should handle recipe not found', () async {
        // Arrange
        const nonExistentId = 'non-existent';
        const newUserId = 'new-member';
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await membershipService.addMemberToRecipe(
          nonExistentId,
          newUserId,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
        // Error is caught internally, message not propagated
      });
      
      test('should replace existing member permission', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const existingUserId = 'user-3'; // Currently a viewer
        const newPermission = ResourcePermission.editor;
        
        // Act
        final result = await membershipService.addMemberToRecipe(
          recipeId,
          existingUserId,
          newPermission,
        );
        
        // Assert
        expect(result, isTrue);
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?[existingUserId], equals(newPermission));
      });
    });
    
    group('Remove Member', () {
      test('should remove member when admin', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const memberToRemove = 'user-3';
        
        // Act
        final result = await membershipService.removeMemberFromRecipe(
          recipeId,
          memberToRemove,
        );
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?.containsKey(memberToRemove), isFalse);
      });
      
      test('should fail when non-admin tries to remove member', () async {
        // Arrange
        const recipeId = 'recipe-3'; // User is viewer, not admin
        const memberToRemove = 'some-user';
        
        // Act
        final result = await membershipService.removeMemberFromRecipe(
          recipeId,
          memberToRemove,
        );
        
        // Assert
        expect(result, isFalse);
        // Error is caught internally, message not propagated
      });
      
      test('should handle removing non-existent member', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const nonExistentMember = 'non-existent-user';
        
        // Act
        final result = await membershipService.removeMemberFromRecipe(
          recipeId,
          nonExistentMember,
        );
        
        // Assert
        expect(result, isTrue); // Should succeed even if member doesn't exist
        expect(notifyCount, greaterThan(0));
      });
      
      test('should allow admin to remove themselves', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Act
        final result = await membershipService.removeMemberFromRecipe(
          recipeId,
          currentUserId, // Remove self
        );
        
        // Assert
        expect(result, isTrue);
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?.containsKey(currentUserId), isFalse);
      });
    });
    
    group('Update Member Permission', () {
      test('should update member permission when admin', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const userId = 'user-2'; // Currently editor
        const newPermission = ResourcePermission.viewer;
        
        // Act
        final result = await membershipService.updateMemberPermission(
          recipeId,
          userId,
          newPermission,
        );
        
        // Assert
        expect(result, isTrue);
        expect(notifyCount, greaterThan(0));
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?[userId], equals(newPermission));
      });
      
      test('should fail when non-admin tries to update permission', () async {
        // Arrange
        const recipeId = 'recipe-2'; // User is editor, not admin
        const userId = 'user-3';
        const newPermission = ResourcePermission.editor;
        
        // Act
        final result = await membershipService.updateMemberPermission(
          recipeId,
          userId,
          newPermission,
        );
        
        // Assert
        expect(result, isFalse);
        // Error is caught internally, message not propagated
      });
      
      test('should add new member if not exists', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newUserId = 'brand-new-user';
        const permission = ResourcePermission.viewer;
        
        // Act
        final result = await membershipService.updateMemberPermission(
          recipeId,
          newUserId,
          permission,
        );
        
        // Assert
        expect(result, isTrue);
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?.containsKey(newUserId), isTrue);
        expect(memberPermissions?[newUserId], equals(permission));
      });
      
      test('should update own permission when admin', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newPermission = ResourcePermission.editor;
        
        // Act
        final result = await membershipService.updateMemberPermission(
          recipeId,
          currentUserId,
          newPermission,
        );
        
        // Assert
        expect(result, isTrue);
        
        final recipe = testRecipesMap[recipeId];
        final memberPermissions = recipe?.socialData?.memberPermissions;
        expect(memberPermissions?[currentUserId], equals(newPermission));
      });
    });
    
    group('Get Recipe Members', () {
      test('should return all members with permissions', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Act
        final members = await membershipService.getRecipeMembers(recipeId);
        
        // Assert
        expect(members, isNotEmpty);
        expect(members.length, equals(3)); // Admin + 2 members
        expect(members[currentUserId], equals(ResourcePermission.admin));
        expect(members['user-2'], equals(ResourcePermission.editor));
        expect(members['user-3'], equals(ResourcePermission.viewer));
      });
      
      test('should return empty map for non-existent recipe', () async {
        // Arrange
        const nonExistentId = 'non-existent';
        
        // Act
        final members = await membershipService.getRecipeMembers(nonExistentId);
        
        // Assert
        expect(members, isEmpty);
      });
      
      test('should return empty map for recipe without members', () async {
        // Arrange
        final recipeWithoutMembers = RecipeFactory.buildCollaborative(
          id: 'recipe-no-members',
          title: 'No Members Recipe',
          permissions: {},
        );
        testRecipesMap['recipe-no-members'] = recipeWithoutMembers;
        
        // Act
        final members = await membershipService.getRecipeMembers('recipe-no-members');
        
        // Assert
        expect(members, isEmpty);
      });
      
      test('should handle exceptions gracefully', () async {
        // Arrange
        const recipeId = 'recipe-1';
        
        // Override getRecipe to throw
        membershipService = SocialRecipeMembershipService(
          getCurrentUserId: () => currentUserId,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => throw Exception('Database error'),
          saveRecipe: (recipe) async => true,
        );
        
        // Act
        final members = await membershipService.getRecipeMembers(recipeId);
        
        // Assert
        expect(members, isEmpty);
        expect(errorMessage, contains('Failed to get recipe members'));
      });
    });
    
    group('Save Failures', () {
      test('should handle save failure on add member', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newUserId = 'new-member';
        const permission = ResourcePermission.viewer;
        
        // Override saveRecipe to fail
        membershipService = SocialRecipeMembershipService(
          getCurrentUserId: () => currentUserId,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => testRecipesMap[id],
          saveRecipe: (recipe) async => false, // Fail save
        );
        
        // Act
        final result = await membershipService.addMemberToRecipe(
          recipeId,
          newUserId,
          permission,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should handle save failure on remove member', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const memberToRemove = 'user-3';
        
        // Override saveRecipe to fail
        membershipService = SocialRecipeMembershipService(
          getCurrentUserId: () => currentUserId,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => testRecipesMap[id],
          saveRecipe: (recipe) async => false, // Fail save
        );
        
        // Act
        final result = await membershipService.removeMemberFromRecipe(
          recipeId,
          memberToRemove,
        );
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should handle save failure on update permission', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const userId = 'user-2';
        const newPermission = ResourcePermission.viewer;
        
        // Override saveRecipe to fail
        membershipService = SocialRecipeMembershipService(
          getCurrentUserId: () => currentUserId,
          setError: (error) => errorMessage = error,
          notifyListeners: () => notifyCount++,
          getRecipe: (id) async => testRecipesMap[id],
          saveRecipe: (recipe) async => false, // Fail save
        );
        
        // Act
        final result = await membershipService.updateMemberPermission(
          recipeId,
          userId,
          newPermission,
        );
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('State Updates', () {
      test('should notify listeners on successful add', () async {
        // Arrange
        const recipeId = 'recipe-1';
        const newUserId = 'new-member';
        const permission = ResourcePermission.viewer;
        final initialNotifyCount = notifyCount;
        
        // Act
        await membershipService.addMemberToRecipe(recipeId, newUserId, permission);
        
        // Assert
        expect(notifyCount, greaterThan(initialNotifyCount));
      });
      
      test('should not notify on failed operation', () async {
        // Arrange
        const recipeId = 'recipe-2'; // User is not admin
        const newUserId = 'new-member';
        const permission = ResourcePermission.viewer;
        final initialNotifyCount = notifyCount;
        
        // Act
        await membershipService.addMemberToRecipe(recipeId, newUserId, permission);
        
        // Assert
        expect(notifyCount, equals(initialNotifyCount));
      });
    });
    
    group('Recipe Operation Results', () {
      test('should create success result', () {
        // Act
        final result = membershipService.createSuccessResult('Test success');
        
        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.message, equals('Test success'));
      });
      
      test('should create failure result', () {
        // Act
        final result = membershipService.createFailureResult('Test failure');
        
        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.message, equals('Test failure'));
      });
    });
  });
}