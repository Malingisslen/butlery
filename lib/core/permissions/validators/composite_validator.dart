// lib/core/permissions/validators/composite_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';
import 'package:butlery/core/permissions/validators/recipe_validator.dart';
import 'package:butlery/core/permissions/validators/shopping_list_validator.dart';
import 'package:butlery/core/permissions/validators/group_validator.dart';
import 'package:butlery/core/permissions/validators/social_validator.dart';

/// Composite permission validator for complex multi-resource operations
class CompositePermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
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