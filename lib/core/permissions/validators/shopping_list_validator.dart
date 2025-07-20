// lib/core/permissions/validators/shopping_list_validator.dart

import '../../../services/permission_service.dart';
import '../../../core/injection.dart';
import 'base_validator.dart';
import 'validation_result.dart';

/// Shopping list permission validator
class ShoppingListPermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
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