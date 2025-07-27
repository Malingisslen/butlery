// lib/core/permissions/modules/permission_debug_tools.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/permissions/modules/base_permission_manager.dart';
import 'package:butlery/core/permissions/modules/recipe_permission_handler.dart';
import 'package:butlery/core/permissions/modules/shopping_permission_handler.dart';
import 'package:butlery/core/permissions/modules/group_permission_handler.dart';
import 'package:butlery/core/permissions/modules/social_permission_handler.dart';
import 'package:butlery/core/permissions/modules/permission_action_builder.dart';

/// Focused module for permission debugging tools
/// 
/// This module handles ONLY development and testing utilities:
/// - Permission debugging and logging
/// - Permission validation testing
/// - Permission comparison and analysis
/// - Development-only permission utilities
/// 
/// ❌ DOES NOT CONTAIN: Core permission logic, action builders, production features
class PermissionDebugTools {

  // ===== PERMISSION DEBUGGING =====

  /// Print all permissions for a resource
  static void debugPrintPermissions(String resourceType, String resourceId) {
    if (!kDebugMode) return;
    
    debugPrint('=== PERMISSIONS DEBUG: $resourceType:$resourceId ===');
    debugPrint('User ID: ${BasePermissionManager.currentUserId}');
    debugPrint('Is Authenticated: ${BasePermissionManager.isAuthenticated}');
    debugPrint('Has Valid Session: ${BasePermissionManager.isLoggedIn}');
    debugPrint('');
    
    switch (resourceType.toLowerCase()) {
      case 'recipe':
        _debugPrintRecipePermissions(resourceId);
        break;
      case 'shopping_list':
        _debugPrintShoppingListPermissions(resourceId);
        break;
      case 'group':
        _debugPrintGroupPermissions(resourceId);
        break;
      case 'social':
      case 'user':
        _debugPrintSocialPermissions(resourceId);
        break;
      default:
        debugPrint('Unknown resource type: $resourceType');
    }
    
    debugPrint('===============================================');
  }

  /// Debug print recipe permissions
  static void _debugPrintRecipePermissions(String recipeId) {
    debugPrint('Recipe Permissions:');
    debugPrint('  - Can View: ${RecipePermissionHandler.canViewRecipe(recipeId)}');
    debugPrint('  - Can Edit: ${RecipePermissionHandler.canEditRecipe(recipeId)}');
    debugPrint('  - Can Delete: ${RecipePermissionHandler.canDeleteRecipe(recipeId)}');
    debugPrint('  - Can Share: ${RecipePermissionHandler.canShareRecipe(recipeId)}');
    debugPrint('  - Can Duplicate: ${RecipePermissionHandler.canDuplicateRecipe(recipeId)}');
    debugPrint('  - Is Owner: ${RecipePermissionHandler.isRecipeOwner(recipeId)}');
    debugPrint('  - Permission Level: ${PermissionActionBuilder.getRecipePermissionLevel(recipeId)}');
    debugPrint('  - Available Actions: ${PermissionActionBuilder.getAvailableRecipeActions(recipeId)}');
  }

  /// Debug print shopping list permissions
  static void _debugPrintShoppingListPermissions(String listId) {
    debugPrint('Shopping List Permissions:');
    debugPrint('  - Can View: ${ShoppingPermissionHandler.canViewShoppingList(listId)}');
    debugPrint('  - Can Edit: ${ShoppingPermissionHandler.canEditShoppingList(listId)}');
    debugPrint('  - Can Manage: ${ShoppingPermissionHandler.canManageShoppingList(listId)}');
    debugPrint('  - Can Delete: ${ShoppingPermissionHandler.canDeleteShoppingList(listId)}');
    debugPrint('  - Can Share: ${ShoppingPermissionHandler.canShareShoppingList(listId)}');
    debugPrint('  - Is Owner: ${ShoppingPermissionHandler.isShoppingListOwner(listId)}');
    debugPrint('  - Permission Level: ${PermissionActionBuilder.getShoppingListPermissionLevel(listId)}');
    debugPrint('  - Available Actions: ${PermissionActionBuilder.getAvailableShoppingListActions(listId)}');
  }

  /// Debug print group permissions
  static void _debugPrintGroupPermissions(String groupId) {
    debugPrint('Group Permissions:');
    debugPrint('  - Can View: ${GroupPermissionHandler.canViewGroup(groupId)}');
    debugPrint('  - Can Edit: ${GroupPermissionHandler.canEditGroup(groupId)}');
    debugPrint('  - Can Manage: ${GroupPermissionHandler.canManageGroup(groupId)}');
    debugPrint('  - Can Delete: ${GroupPermissionHandler.canDeleteGroup(groupId)}');
    debugPrint('  - Is Admin: ${GroupPermissionHandler.isGroupAdmin(groupId)}');
    debugPrint('  - Is Owner: ${GroupPermissionHandler.isGroupOwner(groupId)}');
    debugPrint('  - Is Member: ${GroupPermissionHandler.isGroupMember(groupId)}');
    debugPrint('  - Permission Level: ${PermissionActionBuilder.getGroupPermissionLevel(groupId)}');
    debugPrint('  - Available Actions: ${PermissionActionBuilder.getAvailableGroupActions(groupId)}');
  }

  /// Debug print social permissions
  static void _debugPrintSocialPermissions(String userId) {
    debugPrint('Social Permissions:');
    debugPrint('  - Can View Profile: ${SocialPermissionHandler.canViewProfile(userId)}');
    debugPrint('  - Can Edit Profile: ${SocialPermissionHandler.canEditProfile(userId)}');
    debugPrint('  - Can Send Friend Request: ${SocialPermissionHandler.canSendFriendRequest(userId)}');
    debugPrint('  - Can Message: ${SocialPermissionHandler.canMessageUser(userId)}');
    debugPrint('  - Can Block: ${SocialPermissionHandler.canBlockUser(userId)}');
    debugPrint('  - Is Own Profile: ${SocialPermissionHandler.isOwnProfile(userId)}');
    debugPrint('  - Are Friends: ${SocialPermissionHandler.areFriends(userId)}');
    debugPrint('  - Permission Level: ${PermissionActionBuilder.getSocialPermissionLevel(userId)}');
    debugPrint('  - Available Actions: ${PermissionActionBuilder.getAvailableSocialActions(userId)}');
  }

  // ===== PERMISSION VALIDATION TESTING =====

  /// Test all permission combinations for a resource
  static Map<String, bool> testAllPermissions(String resourceType, String resourceId) {
    if (!kDebugMode) return {};
    
    switch (resourceType.toLowerCase()) {
      case 'recipe':
        return RecipePermissionHandler.validateAllRecipePermissions(resourceId);
      case 'shopping_list':
        return ShoppingPermissionHandler.validateAllShoppingListPermissions(resourceId);
      case 'group':
        return GroupPermissionHandler.validateAllGroupPermissions(resourceId);
      case 'social':
      case 'user':
        return SocialPermissionHandler.validateAllSocialPermissions(resourceId);
      default:
        return {};
    }
  }

  /// Compare permissions between resources
  static void compareResourcePermissions(
    Map<String, String> resources, // resourceType -> resourceId
  ) {
    if (!kDebugMode) return;
    
    debugPrint('=== PERMISSION COMPARISON ===');
    
    for (final entry in resources.entries) {
      final resourceType = entry.key;
      final resourceId = entry.value;
      final permissions = testAllPermissions(resourceType, resourceId);
      
      debugPrint('$resourceType ($resourceId):');
      for (final permEntry in permissions.entries) {
        debugPrint('  ${permEntry.key}: ${permEntry.value}');
      }
      debugPrint('');
    }
    
    debugPrint('=============================');
  }

  // ===== PERMISSION CONTEXT DEBUGGING =====

  /// Debug permission context for all resource types
  static void debugPermissionContext({
    String? recipeId,
    String? shoppingListId,
    String? groupId,
    String? userId,
  }) {
    if (!kDebugMode) return;
    
    debugPrint('=== PERMISSION CONTEXT DEBUG ===');
    debugPrint('Current User: ${BasePermissionManager.getCurrentUserInfo()}');
    debugPrint('');
    
    if (recipeId != null) {
      final context = RecipePermissionHandler.createRecipePermissionContext(recipeId);
      debugPrint('Recipe Context: $context');
    }
    
    if (shoppingListId != null) {
      final context = ShoppingPermissionHandler.createShoppingListPermissionContext(shoppingListId);
      debugPrint('Shopping List Context: $context');
    }
    
    if (groupId != null) {
      final context = GroupPermissionHandler.createGroupPermissionContext(groupId);
      debugPrint('Group Context: $context');
    }
    
    if (userId != null) {
      final context = SocialPermissionHandler.createSocialPermissionContext(userId);
      debugPrint('Social Context: $context');
    }
    
    debugPrint('===============================');
  }

  // ===== PERMISSION PERFORMANCE TESTING =====

  /// Benchmark permission checking performance
  static void benchmarkPermissions(String resourceType, List<String> resourceIds) {
    if (!kDebugMode) return;
    
    debugPrint('=== PERMISSION BENCHMARK: $resourceType ===');
    
    final stopwatch = Stopwatch()..start();
    
    for (final resourceId in resourceIds) {
      testAllPermissions(resourceType, resourceId);
    }
    
    stopwatch.stop();
    
    final totalTime = stopwatch.elapsedMilliseconds;
    final avgTime = totalTime / resourceIds.length;
    
    debugPrint('Resources tested: ${resourceIds.length}');
    debugPrint('Total time: ${totalTime}ms');
    debugPrint('Average time per resource: ${avgTime.toStringAsFixed(2)}ms');
    debugPrint('Permissions per second: ${(1000 / avgTime).toStringAsFixed(2)}');
    debugPrint('=======================================');
  }

  // ===== PERMISSION ERROR DEBUGGING =====

  /// Debug permission errors
  static void debugPermissionError(String operation, String resourceType, String resourceId) {
    if (!kDebugMode) return;
    
    debugPrint('=== PERMISSION ERROR DEBUG ===');
    debugPrint('Operation: $operation');
    debugPrint('Resource: $resourceType:$resourceId');
    debugPrint('User Context: ${BasePermissionManager.getPermissionErrorContext()}');
    debugPrint('');
    
    final permissions = testAllPermissions(resourceType, resourceId);
    debugPrint('All Permissions:');
    for (final entry in permissions.entries) {
      debugPrint('  ${entry.key}: ${entry.value}');
    }
    
    debugPrint('');
    debugPrint('Suggested Fix: ${_suggestPermissionFix(operation, resourceType, permissions)}');
    debugPrint('==============================');
  }

  /// Suggest fix for permission error
  static String _suggestPermissionFix(
    String operation, 
    String resourceType, 
    Map<String, bool> permissions,
  ) {
    if (!BasePermissionManager.isAuthenticated) {
      return 'User needs to log in';
    }
    
    if (!BasePermissionManager.isLoggedIn) {
      return 'User session has expired - needs to refresh session';
    }
    
    switch (operation.toLowerCase()) {
      case 'view':
        return 'User needs view permission for this $resourceType';
      case 'edit':
        return 'User needs edit permission for this $resourceType';
      case 'delete':
        return 'User needs delete permission for this $resourceType';
      case 'share':
        return 'User needs share permission for this $resourceType';
      default:
        return 'User needs appropriate permission for $operation on $resourceType';
    }
  }

  // ===== PERMISSION DEVELOPMENT HELPERS =====

  /// Create mock permission scenario for testing
  static Map<String, dynamic> createMockPermissionScenario({
    required String scenarioName,
    required bool isAuthenticated,
    required String? userId,
    Map<String, bool> customPermissions = const {},
  }) {
    if (!kDebugMode) return {};
    
    return {
      'scenario': scenarioName,
      'user_context': {
        'isAuthenticated': isAuthenticated,
        'userId': userId,
        'displayName': userId != null ? 'Test User $userId' : null,
      },
      'custom_permissions': customPermissions,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Validate permission consistency across handlers
  static List<String> validatePermissionConsistency(String resourceType, String resourceId) {
    if (!kDebugMode) return [];
    
    final issues = <String>[];
    
    switch (resourceType.toLowerCase()) {
      case 'recipe':
        issues.addAll(_validateRecipeConsistency(resourceId));
        break;
      case 'shopping_list':
        issues.addAll(_validateShoppingListConsistency(resourceId));
        break;
      case 'group':
        issues.addAll(_validateGroupConsistency(resourceId));
        break;
      case 'social':
        issues.addAll(_validateSocialConsistency(resourceId));
        break;
    }
    
    return issues;
  }

  /// Validate recipe permission consistency
  static List<String> _validateRecipeConsistency(String recipeId) {
    final issues = <String>[];
    
    // If user can edit, they should be able to view
    if (RecipePermissionHandler.canEditRecipe(recipeId) && 
        !RecipePermissionHandler.canViewRecipe(recipeId)) {
      issues.add('Can edit but cannot view recipe');
    }
    
    // If user can delete, they should be able to edit
    if (RecipePermissionHandler.canDeleteRecipe(recipeId) && 
        !RecipePermissionHandler.canEditRecipe(recipeId)) {
      issues.add('Can delete but cannot edit recipe');
    }
    
    // Owner should be able to do everything
    if (RecipePermissionHandler.isRecipeOwner(recipeId)) {
      if (!RecipePermissionHandler.canViewRecipe(recipeId)) {
        issues.add('Owner cannot view own recipe');
      }
      if (!RecipePermissionHandler.canEditRecipe(recipeId)) {
        issues.add('Owner cannot edit own recipe');
      }
      if (!RecipePermissionHandler.canDeleteRecipe(recipeId)) {
        issues.add('Owner cannot delete own recipe');
      }
    }
    
    return issues;
  }

  /// Validate shopping list permission consistency
  static List<String> _validateShoppingListConsistency(String listId) {
    final issues = <String>[];
    
    // Similar validation logic for shopping lists
    if (ShoppingPermissionHandler.canEditShoppingList(listId) && 
        !ShoppingPermissionHandler.canViewShoppingList(listId)) {
      issues.add('Can edit but cannot view shopping list');
    }
    
    return issues;
  }

  /// Validate group permission consistency
  static List<String> _validateGroupConsistency(String groupId) {
    final issues = <String>[];
    
    // Similar validation logic for groups
    if (GroupPermissionHandler.canEditGroup(groupId) && 
        !GroupPermissionHandler.canViewGroup(groupId)) {
      issues.add('Can edit but cannot view group');
    }
    
    return issues;
  }

  /// Validate social permission consistency
  static List<String> _validateSocialConsistency(String userId) {
    final issues = <String>[];
    
    // Similar validation logic for social permissions
    if (SocialPermissionHandler.canEditProfile(userId) && 
        !SocialPermissionHandler.canViewProfile(userId)) {
      issues.add('Can edit but cannot view profile');
    }
    
    return issues;
  }
}