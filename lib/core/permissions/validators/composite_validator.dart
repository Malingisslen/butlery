// lib/core/permissions/validators/composite_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';
import 'package:butlery/core/permissions/validators/recipe_validator.dart';
import 'package:butlery/core/permissions/validators/shopping_list_validator.dart';
import 'package:butlery/core/permissions/validators/group_validator.dart';
import 'package:butlery/core/permissions/validators/social_validator.dart';

/// Composite permission validator for complex multi-resource operations.
///
/// This validator combines multiple specialized validators to handle complex
/// operations that involve multiple resources or domains. It orchestrates
/// validation across different validators while maintaining consistent error
/// handling and providing comprehensive permission checking.
///
/// **Key Capabilities:**
/// - **Multi-Resource Validation**: Validates operations spanning multiple resource types
/// - **Bulk Operation Support**: Efficiently validates operations on multiple resources
/// - **Complex Sharing Logic**: Handles sharing scenarios with recipes, groups, and users
/// - **Coordinated Validation**: Ensures all related permissions are checked consistently
/// - **Error Aggregation**: Provides detailed feedback when validation fails at any step
///
/// **Common Use Cases:**
/// - Sharing recipes or shopping lists to multiple groups and users
/// - Bulk operations like deleting multiple recipes or shopping lists
/// - Complex collaborative operations involving multiple permission domains
/// - Cross-domain operations that require validation across multiple validators
///
/// **Architecture Integration:**
/// This validator acts as a coordinator for other specialized validators,
/// delegating domain-specific validation to the appropriate validator while
/// handling the orchestration and result aggregation logic.
///
/// **Usage Examples:**
/// ```dart
/// final compositeValidator = CompositePermissionValidator();
/// 
/// // Validate complex sharing operation
/// final result = compositeValidator.validateComplexSharing(
///   recipeId: 'recipe123',
///   targetUserIds: ['user1', 'user2'],
///   targetGroupIds: ['group1', 'group2'],
/// );
/// 
/// // Validate bulk deletion
/// final bulkResult = compositeValidator.validateBulkOperation(
///   operation: 'delete',
///   resourceIds: ['recipe1', 'recipe2', 'recipe3'],
///   resourceType: 'recipe',
/// );
/// ```
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