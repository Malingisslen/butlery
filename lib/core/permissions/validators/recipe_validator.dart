// lib/core/permissions/validators/recipe_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Recipe permission validator
class RecipePermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
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