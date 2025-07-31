// lib/core/permissions/validators/shopping_list_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/base_validator.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Specialized permission validator for shopping list operations and collaborative features.
///
/// This validator handles all shopping list-specific permission validation including
/// creation, editing, deletion, sharing, and member management. It provides comprehensive
/// validation for both individual shopping lists and collaborative shopping scenarios.
///
/// **Key Validation Areas:**
/// - **List Creation**: Validates user can create new shopping lists
/// - **List Modification**: Ensures proper edit and management permissions
/// - **Item Management**: Validates permissions for adding/removing/modifying items
/// - **Sharing & Collaboration**: Manages sharing permissions and member invitations
/// - **List Administration**: Handles deletion and advanced management permissions
///
/// **Permission Levels Supported:**
/// - **Owner**: Full control over shopping list (all operations, member management)
/// - **Member**: Can add/remove items and modify list content
/// - **Viewer**: Can view list contents but cannot modify
/// - **Shared**: Has specific permissions granted by the owner
///
/// **Collaborative Features:**
/// Shopping lists support real-time collaboration where multiple users can
/// simultaneously add items, check off purchases, and manage list content.
/// This validator ensures all collaborative operations maintain proper
/// permission boundaries while enabling seamless teamwork.
///
/// **Usage Examples:**
/// ```dart
/// final validator = ShoppingListPermissionValidator();
/// 
/// // Validate before allowing list editing
/// final editResult = validator.validateShoppingListEdit(listId);
/// if (editResult.isValid) {
///   enableEditingInterface();
/// }
/// 
/// // Validate collaborative access management
/// final memberResult = validator.validateCollaborativeShoppingList(
///   listId, 
///   ['user1', 'user2']
/// );
/// ```
class ShoppingListPermissionValidator extends BasePermissionValidator {
  PermissionService get _permissionService => sl<PermissionService>();
  /// Validates that the current user can create a new shopping list.
  ///
  /// Performs basic authentication checks and validates that the user
  /// has the necessary permissions to create shopping lists. This is
  /// typically unrestricted for authenticated users but may include
  /// future constraints like subscription limits.
  ///
  /// Returns [PermissionValidationResult.success] if list creation is allowed,
  /// or an appropriate failure result if creation constraints prevent it.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateShoppingListCreation();
  /// if (result.isValid) {
  ///   showCreateListDialog();
  /// }
  /// ```
  PermissionValidationResult validateShoppingListCreation() {
    final basicResult = validateBasicPermissions();
    if (!basicResult.isValid) return basicResult;
    
    return PermissionValidationResult.success();
  }
  
  /// Validates that the current user can edit the specified shopping list.
  ///
  /// Verifies that the user has sufficient permissions to modify the shopping
  /// list, including adding/removing items, changing list properties, and
  /// updating list metadata. This includes both owners and authorized members.
  ///
  /// [listId] The unique identifier of the shopping list to validate edit access for
  ///
  /// Returns [PermissionValidationResult.success] if editing is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// lacks the necessary edit permissions.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateShoppingListEdit('list123');
  /// if (result.isValid) {
  ///   enableItemAddingInterface();
  /// }
  /// ```
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
  
  /// Validates that the current user can perform management operations on the shopping list.
  ///
  /// Management permissions include advanced operations like changing list settings,
  /// managing member permissions, modifying sharing settings, and other administrative
  /// functions. This is typically restricted to list owners and designated managers.
  ///
  /// [listId] The unique identifier of the shopping list to validate management access for
  ///
  /// Returns [PermissionValidationResult.success] if management is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// lacks management privileges.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateShoppingListManagement('list123');
  /// if (result.isValid) {
  ///   showManagementInterface();
  /// }
  /// ```
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
  
  /// Validates that the current user can delete the specified shopping list.
  ///
  /// Deletion is typically the most restrictive permission, usually requiring
  /// ownership rights. This validation ensures that only authorized users can
  /// permanently remove shopping lists, protecting against accidental or
  /// unauthorized deletions.
  ///
  /// [listId] The unique identifier of the shopping list to validate deletion access for
  ///
  /// Returns [PermissionValidationResult.success] if deletion is allowed,
  /// or [PermissionValidationResult.insufficientPermissions] if the user
  /// cannot delete the shopping list.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateShoppingListDeletion('list123');
  /// if (result.isValid) {
  ///   showDeleteConfirmationDialog();
  /// }
  /// ```
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
  
  /// Validates that the current user can share the shopping list with specified users.
  ///
  /// Performs comprehensive validation for shopping list sharing operations:
  /// - User has sharing permissions for the list (owner or authorized member)
  /// - All target users are valid and accessible for sharing
  /// - No privacy constraints prevent sharing with target users
  ///
  /// Sharing allows other users to view and potentially edit the shopping list
  /// depending on the sharing permissions granted.
  ///
  /// [listId] The unique identifier of the shopping list to be shared
  /// [targetUserIds] List of user IDs to validate as sharing targets
  ///
  /// Returns [PermissionValidationResult.success] if sharing is allowed with all targets,
  /// or an appropriate failure result if sharing permissions are insufficient.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateShoppingListSharing(
  ///   'list123',
  ///   ['user1', 'user2']
  /// );
  /// if (result.isValid) {
  ///   processListSharing();
  /// }
  /// ```
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
  
  /// Validates that the current user can manage collaborative members for the shopping list.
  ///
  /// Verifies that the user has sufficient permissions to add or manage
  /// collaborative members for the shopping list, which requires ownership rights.
  /// Also validates that all proposed members are valid users who can be
  /// granted collaborative access to the list.
  ///
  /// Collaborative members typically have broader permissions than shared viewers,
  /// including the ability to add/remove items and modify list content.
  ///
  /// [listId] The unique identifier of the shopping list to manage members for
  /// [memberIds] List of user IDs to validate as potential collaborative members
  ///
  /// Returns [PermissionValidationResult.success] if member management is allowed
  /// and all members are valid, or an appropriate failure result if permissions
  /// are insufficient or members are invalid.
  ///
  /// Example usage:
  /// ```dart
  /// final result = validator.validateCollaborativeShoppingList(
  ///   'list123',
  ///   ['user1', 'user2']
  /// );
  /// if (result.isValid) {
  ///   addMembersToList();
  /// }
  /// ```
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