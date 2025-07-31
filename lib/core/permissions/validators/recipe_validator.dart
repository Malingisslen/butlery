// lib/core/permissions/validators/recipe_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Specialized permission validator for recipe-related operations and access control.
///
/// This validator handles all recipe-specific permission validation including creation,
/// editing, deletion, sharing, and collaboration. It builds upon the base validation
/// functionality while providing domain-specific validation logic for recipe operations.
///
/// **Key Validation Areas:**
/// - **Recipe Creation**: Validates user can create new recipes and hasn't exceeded limits
/// - **Recipe Modification**: Ensures user has edit/delete permissions for specific recipes
/// - **Recipe Sharing**: Validates sharing permissions and target user accessibility
/// - **Recipe Collaboration**: Manages collaborative editing permissions and invitations
/// - **Access Control**: Verifies view permissions and ownership validation
///
/// **Permission Levels Supported:**
/// - **Owner**: Full control over recipe (edit, delete, share, manage collaborators)
/// - **Collaborator**: Can edit recipe content but cannot delete or manage sharing
/// - **Viewer**: Can view recipe details and content but cannot modify
/// - **Public**: Can view public recipes without explicit sharing
///
/// **Integration with Permission Service:**
/// Delegates actual permission checks to the PermissionService while providing
/// validation result standardization and error handling. This separation allows
/// for consistent validation patterns while maintaining flexibility in permission logic.
///
/// **Usage Examples:**
/// ```dart
/// final validator = RecipePermissionValidator();
/// 
/// // Validate recipe editing before allowing user to edit
/// final editResult = validator.validateRecipeEdit(recipeId);
/// if (editResult.isValid) {
///   navigateToEditScreen();
/// } else {
///   showError(editResult.errorMessage);
/// }
/// 
/// // Validate complex sharing operation
/// final shareResult = validator.validateRecipeSharing(
///   recipeId, 
///   ['user1', 'user2', 'user3']
/// );
/// ```
class RecipePermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  /// Validates that the current user can create a new recipe.
  ///
  /// Performs basic authentication checks and any recipe-specific creation
  /// constraints such as recipe limits, subscription tiers, or account status.
  /// This is typically called before showing the recipe creation interface
  /// or processing a recipe creation request.
  ///
  /// Returns [PermissionValidationResult.success] if the user can create recipes,
  /// or an appropriate failure result with error details if creation is not allowed.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateRecipeCreation();
  /// if (result.isValid) {
  ///   showRecipeCreationDialog();
  /// } else {
  ///   showError(result.errorMessage);
  /// }
  /// ```
  PermissionValidationResult validateRecipeCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    // Add specific recipe creation validations here
    // For example: check if user has reached recipe limit, etc.
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can edit the specified recipe.
  ///
  /// Checks if the user has sufficient permissions to modify the recipe,
  /// including ownership or collaborator status. This validation should be
  /// performed before allowing access to recipe editing interfaces or
  /// processing recipe modification requests.
  ///
  /// [recipeId] The unique identifier of the recipe to validate edit access for
  ///
  /// Returns [PermissionValidationResult.success] if editing is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// lacks the necessary permissions.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateRecipeEdit('recipe123');
  /// if (result.isValid) {
  ///   navigateToRecipeEditor(recipeId);
  /// }
  /// ```
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
  
  /// Validates that the current user can delete the specified recipe.
  ///
  /// Verifies that the user has deletion permissions for the recipe, which
  /// typically requires ownership rights. Deletion is usually more restrictive
  /// than editing and may not be available to collaborators.
  ///
  /// [recipeId] The unique identifier of the recipe to validate deletion access for
  ///
  /// Returns [PermissionValidationResult.success] if deletion is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// cannot delete the recipe.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateRecipeDeletion('recipe123');
  /// if (result.isValid) {
  ///   showDeleteConfirmationDialog();
  /// }
  /// ```
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
  
  /// Validates that the current user can share the recipe with specified users.
  ///
  /// Performs comprehensive validation for recipe sharing operations, including:
  /// - User has sharing permissions for the recipe (typically owner or collaborator)
  /// - All target users are valid and accessible for sharing
  /// - No privacy or security constraints prevent sharing with target users
  ///
  /// This validation helps prevent unauthorized sharing and ensures all recipients
  /// are legitimate targets for the sharing operation.
  ///
  /// [recipeId] The unique identifier of the recipe to be shared
  /// [targetUserIds] List of user IDs to validate as sharing targets
  ///
  /// Returns [PermissionValidationResult.success] if sharing is allowed with all targets,
  /// or an appropriate failure result if sharing permissions are insufficient or
  /// any target user is invalid.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateRecipeSharing(
  ///   'recipe123', 
  ///   ['user1', 'user2', 'user3']
  /// );
  /// if (result.isValid) {
  ///   processRecipeSharing();
  /// }
  /// ```
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
  
  /// Validates that the current user can manage collaborators for the recipe.
  ///
  /// Verifies that the user has sufficient permissions to add or manage
  /// collaborators for the recipe, which typically requires ownership rights.
  /// Also validates that all proposed collaborators are valid users who can
  /// be granted collaborative access.
  ///
  /// Collaboration management is typically more restrictive than sharing,
  /// as it grants editing permissions rather than just viewing access.
  ///
  /// [recipeId] The unique identifier of the recipe to manage collaborators for
  /// [collaboratorIds] List of user IDs to validate as potential collaborators
  ///
  /// Returns [PermissionValidationResult.success] if collaboration management
  /// is allowed and all collaborators are valid, or an appropriate failure
  /// result if permissions are insufficient or collaborators are invalid.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateRecipeCollaboration(
  ///   'recipe123',
  ///   ['user1', 'user2']
  /// );
  /// if (result.isValid) {
  ///   addCollaboratorsToRecipe();
  /// }
  /// ```
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