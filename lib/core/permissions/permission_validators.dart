/// 🛡️ PERMISSION VALIDATORS - Complex permission validation logic
/// File: lib/core/permissions/permission_validators.dart
/// Purpose: Centralized validation for complex permission scenarios
/// Dependencies: PermissionService, permission_mixins.dart
/// Usage: Used by services and ViewModels for complex permission checks

import '../../services/permission_service.dart';
import '../../core/injection.dart';

/// Result of a permission validation
class PermissionValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? errorCode;
  final Map<String, dynamic>? context;
  
  const PermissionValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.context,
  });
  
  /// Create a successful validation result
  factory PermissionValidationResult.success({Map<String, dynamic>? context}) {
    return PermissionValidationResult(
      isValid: true,
      context: context,
    );
  }
  
  /// Create a failed validation result
  factory PermissionValidationResult.failure({
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic>? context,
  }) {
    return PermissionValidationResult(
      isValid: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      context: context,
    );
  }
  
  /// Create a validation result for missing authentication
  factory PermissionValidationResult.notAuthenticated() {
    return PermissionValidationResult.failure(
      errorMessage: 'Du måste vara inloggad för att utföra denna åtgärd',
      errorCode: 'NOT_AUTHENTICATED',
    );
  }
  
  /// Create a validation result for insufficient permissions
  factory PermissionValidationResult.insufficientPermissions({
    required String resource,
    required String action,
  }) {
    return PermissionValidationResult.failure(
      errorMessage: 'Du har inte behörighet att $action för $resource',
      errorCode: 'INSUFFICIENT_PERMISSIONS',
      context: {'resource': resource, 'action': action},
    );
  }
  
  /// Create a validation result for resource not found
  factory PermissionValidationResult.resourceNotFound(String resource) {
    return PermissionValidationResult.failure(
      errorMessage: '$resource hittades inte eller du har inte åtkomst till den',
      errorCode: 'RESOURCE_NOT_FOUND',
      context: {'resource': resource},
    );
  }
}

/// Base permission validator with common functionality
abstract class BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  
  /// Validate that user is authenticated
  PermissionValidationResult validateAuthentication() {
    if (!_permissionService.isAuthenticated) {
      return PermissionValidationResult.notAuthenticated();
    }
    return PermissionValidationResult.success();
  }
  
  /// Validate basic user permissions
  PermissionValidationResult validateBasicPermissions() {
    final authResult = validateAuthentication();
    if (!authResult.isValid) return authResult;
    
    if (!_permissionService.hasValidSession) {
      return PermissionValidationResult.failure(
        errorMessage: 'Användarsession har upphört, logga in igen',
        errorCode: 'SESSION_EXPIRED',
      );
    }
    
    return PermissionValidationResult.success();
  }
}

/// Recipe permission validator
class RecipePermissionValidator extends BasePermissionValidator {
  /// Validate recipe creation permissions
  PermissionValidationResult validateRecipeCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    // Add specific recipe creation validations here
    // For example: check if user has reached recipe limit, etc.
    
    return PermissionValidationResult.success();
  }
  
  /// Validate recipe editing permissions
  PermissionValidationResult validateRecipeEdit(String recipeId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canEditRecipe(recipeId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'recept',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate recipe deletion permissions
  PermissionValidationResult validateRecipeDeletion(String recipeId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canDeleteRecipe(recipeId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'recept',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate recipe sharing permissions
  PermissionValidationResult validateRecipeSharing(String recipeId, List<String> targetUserIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canShareRecipe(recipeId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'recept',
        action: 'dela',
      );
    }
    
    // Validate target users
    for (final userId in targetUserIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan inte dela recept med en eller flera av de valda användarna',
          errorCode: 'INVALID_SHARE_TARGET',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate recipe collaboration permissions
  PermissionValidationResult validateRecipeCollaboration(String recipeId, List<String> collaboratorIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isRecipeOwner(recipeId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'recept',
        action: 'hantera samarbete för',
      );
    }
    
    // Validate collaborator permissions
    for (final userId in collaboratorIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan bara lägga till giltiga användare som medarbetare',
          errorCode: 'INVALID_COLLABORATOR',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
}

/// Shopping list permission validator
class ShoppingListPermissionValidator extends BasePermissionValidator {
  /// Validate shopping list creation permissions
  PermissionValidationResult validateShoppingListCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    return PermissionValidationResult.success();
  }
  
  /// Validate shopping list editing permissions
  PermissionValidationResult validateShoppingListEdit(String listId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canEditShoppingList(listId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'inköpslista',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate shopping list management permissions
  PermissionValidationResult validateShoppingListManagement(String listId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canManageShoppingList(listId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'inköpslista',
        action: 'hantera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate shopping list deletion permissions
  PermissionValidationResult validateShoppingListDeletion(String listId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canDeleteShoppingList(listId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'inköpslista',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate shopping list sharing permissions
  PermissionValidationResult validateShoppingListSharing(String listId, List<String> targetUserIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canShareShoppingList(listId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'inköpslista',
        action: 'dela',
      );
    }
    
    // Validate target users
    for (final userId in targetUserIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan inte dela inköpslista med en eller flera av de valda användarna',
          errorCode: 'INVALID_SHARE_TARGET',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate collaborative shopping list permissions
  PermissionValidationResult validateCollaborativeShoppingList(String listId, List<String> memberIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isShoppingListOwner(listId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'inköpslista',
        action: 'hantera medlemmar för',
      );
    }
    
    // Validate member permissions
    for (final userId in memberIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan bara lägga till giltiga användare som medlemmar',
          errorCode: 'INVALID_MEMBER',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
}

/// Group permission validator
class GroupPermissionValidator extends BasePermissionValidator {
  /// Validate group creation permissions
  PermissionValidationResult validateGroupCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group editing permissions
  PermissionValidationResult validateGroupEdit(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group management permissions
  PermissionValidationResult validateGroupManagement(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'hantera',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group deletion permissions
  PermissionValidationResult validateGroupDeletion(String groupId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canDeleteGroup(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group invitation permissions
  PermissionValidationResult validateGroupInvitation(String groupId, List<String> inviteeIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canInviteToGroup(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'bjuda in till',
      );
    }
    
    // Validate invitees
    for (final userId in inviteeIds) {
      if (!_permissionService.canViewProfile(userId)) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan inte bjuda in en eller flera av de valda användarna',
          errorCode: 'INVALID_INVITEE',
        );
      }
      
      // Note: Check for existing membership could be implemented later
      // For now, we'll allow the invitation to be sent
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate group member removal permissions
  PermissionValidationResult validateGroupMemberRemoval(String groupId, List<String> memberIds) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isGroupAdmin(groupId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'grupp',
        action: 'ta bort medlemmar från',
      );
    }
    
    // Validate member removal permissions
    for (final userId in memberIds) {
      if (_permissionService.isGroupAdmin(groupId) && userId == _permissionService.currentUserId) {
        return PermissionValidationResult.failure(
          errorMessage: 'Gruppägaren kan inte ta bort sig själv',
          errorCode: 'CANNOT_REMOVE_OWNER',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
}

/// Social permission validator
class SocialPermissionValidator extends BasePermissionValidator {
  /// Validate friend request permissions
  PermissionValidationResult validateFriendRequest(String targetUserId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canSendFriendRequest(targetUserId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'användare',
        action: 'skicka vänförfrågan till',
      );
    }
    
    // Note: Friend status check is already handled in canSendFriendRequest
    
    return PermissionValidationResult.success();
  }
  
  /// Validate friend removal permissions
  PermissionValidationResult validateFriendRemoval(String friendId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.isAuthenticated || friendId == _permissionService.currentUserId) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'vän',
        action: 'ta bort',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate user blocking permissions
  PermissionValidationResult validateUserBlocking(String userId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (userId == _permissionService.currentUserId) {
      return PermissionValidationResult.failure(
        errorMessage: 'Du kan inte blockera dig själv',
        errorCode: 'CANNOT_BLOCK_SELF',
      );
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate profile editing permissions
  PermissionValidationResult validateProfileEdit(String userId) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    if (!_permissionService.canEditProfile(userId)) {
      return PermissionValidationResult.insufficientPermissions(
        resource: 'profil',
        action: 'redigera',
      );
    }
    
    return PermissionValidationResult.success();
  }
}

/// Composite permission validator for complex multi-resource operations
class CompositePermissionValidator extends BasePermissionValidator {
  final RecipePermissionValidator recipeValidator = RecipePermissionValidator();
  final ShoppingListPermissionValidator shoppingListValidator = ShoppingListPermissionValidator();
  final GroupPermissionValidator groupValidator = GroupPermissionValidator();
  final SocialPermissionValidator socialValidator = SocialPermissionValidator();
  
  /// Validate complex sharing operation (recipe + friends + groups)
  PermissionValidationResult validateComplexSharing({
    String? recipeId,
    String? shoppingListId,
    required List<String> targetUserIds,
    required List<String> targetGroupIds,
  }) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    // Validate recipe sharing if applicable
    if (recipeId != null) {
      final result = recipeValidator.validateRecipeSharing(recipeId, targetUserIds);
      if (!result.isValid) return result;
    }
    
    // Validate shopping list sharing if applicable
    if (shoppingListId != null) {
      final result = shoppingListValidator.validateShoppingListSharing(shoppingListId, targetUserIds);
      if (!result.isValid) return result;
    }
    
    // Validate group sharing permissions
    for (final _ in targetGroupIds) {
      if (!_permissionService.isAuthenticated) {
        return PermissionValidationResult.failure(
          errorMessage: 'Du kan inte dela med en eller flera av de valda grupperna',
          errorCode: 'INVALID_GROUP_TARGET',
        );
      }
    }
    
    return PermissionValidationResult.success();
  }
  
  /// Validate bulk operation permissions
  PermissionValidationResult validateBulkOperation({
    required String operation,
    required List<String> resourceIds,
    required String resourceType,
  }) {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    for (final resourceId in resourceIds) {
      PermissionValidationResult result;
      
      switch (resourceType) {
        case 'recipe':
          switch (operation) {
            case 'delete':
              result = recipeValidator.validateRecipeDeletion(resourceId);
              break;
            case 'edit':
              result = recipeValidator.validateRecipeEdit(resourceId);
              break;
            default:
              result = PermissionValidationResult.failure(
                errorMessage: 'Okänd operation: $operation',
                errorCode: 'UNKNOWN_OPERATION',
              );
          }
          break;
        case 'shopping_list':
          switch (operation) {
            case 'delete':
              result = shoppingListValidator.validateShoppingListDeletion(resourceId);
              break;
            case 'edit':
              result = shoppingListValidator.validateShoppingListEdit(resourceId);
              break;
            default:
              result = PermissionValidationResult.failure(
                errorMessage: 'Okänd operation: $operation',
                errorCode: 'UNKNOWN_OPERATION',
              );
          }
          break;
        case 'group':
          switch (operation) {
            case 'delete':
              result = groupValidator.validateGroupDeletion(resourceId);
              break;
            case 'edit':
              result = groupValidator.validateGroupEdit(resourceId);
              break;
            default:
              result = PermissionValidationResult.failure(
                errorMessage: 'Okänd operation: $operation',
                errorCode: 'UNKNOWN_OPERATION',
              );
          }
          break;
        default:
          result = PermissionValidationResult.failure(
            errorMessage: 'Okänd resurstyp: $resourceType',
            errorCode: 'UNKNOWN_RESOURCE_TYPE',
          );
      }
      
      if (!result.isValid) return result;
    }
    
    return PermissionValidationResult.success();
  }
}

/// Permission validator factory
class PermissionValidatorFactory {
  static RecipePermissionValidator createRecipeValidator() => RecipePermissionValidator();
  static ShoppingListPermissionValidator createShoppingListValidator() => ShoppingListPermissionValidator();
  static GroupPermissionValidator createGroupValidator() => GroupPermissionValidator();
  static SocialPermissionValidator createSocialValidator() => SocialPermissionValidator();
  static CompositePermissionValidator createCompositeValidator() => CompositePermissionValidator();
}