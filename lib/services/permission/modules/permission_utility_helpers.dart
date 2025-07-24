// lib/services/permission/modules/permission_utility_helpers.dart

import '../../../models/permissions/resource_permission.dart';
import '../../../models/permissions/edit_mode.dart';
import '../../../models/user_profile.dart';
import '../../../core/utils/logger.dart';
import 'auth_permission_engine.dart';

/// Focused module for permission utility helpers
/// 
/// This module handles ONLY utility functions and helpers:
/// - Permission level comparison and conversion
/// - Permission validation utilities
/// - Resource permission helpers
/// - Common permission patterns
/// 
/// ❌ DOES NOT CONTAIN: Core permission logic, caching, resource-specific operations
class PermissionUtilityHelpers {
  final AuthPermissionEngine _authEngine;

  PermissionUtilityHelpers(this._authEngine);

  // ===== PERMISSION LEVEL UTILITIES =====

  /// Get resource permission level for current user
  ResourcePermission getResourcePermission(String resourceId, String resourceType) {
    switch (resourceType) {
      case 'recipe':
        // This would be delegated to recipe permission engine in the facade
        return ResourcePermission.viewer; // Placeholder
      case 'shopping_list':
        // This would be delegated to shopping permission engine in the facade
        return ResourcePermission.viewer; // Placeholder
      case 'group':
        // This would be delegated to group permission engine in the facade
        return ResourcePermission.viewer; // Placeholder
      default:
        return ResourcePermission.viewer; // Default fallback
    }
  }

  /// Check if user has minimum required permission
  bool hasMinimumPermission(String resourceId, String resourceType, ResourcePermission required) {
    final current = getResourcePermission(resourceId, resourceType);
    return ResourcePermissionHelper.isHigherPermission(current, required) || current == required;
  }

  /// Compare two permission levels
  int comparePermissionLevels(ResourcePermission a, ResourcePermission b) {
    final levels = {
      ResourcePermission.viewer: 1,
      ResourcePermission.editor: 2,
      ResourcePermission.owner: 3,
    };
    
    return (levels[a] ?? 0).compareTo(levels[b] ?? 0);
  }

  /// Get highest permission from a list
  ResourcePermission getHighestPermission(List<ResourcePermission> permissions) {
    if (permissions.isEmpty) return ResourcePermission.viewer;
    
    return permissions.reduce((current, next) => 
      comparePermissionLevels(current, next) > 0 ? current : next
    );
  }

  /// Get lowest permission from a list
  ResourcePermission getLowestPermission(List<ResourcePermission> permissions) {
    if (permissions.isEmpty) return ResourcePermission.viewer;
    
    return permissions.reduce((current, next) => 
      comparePermissionLevels(current, next) < 0 ? current : next
    );
  }

  // ===== PERMISSION VALIDATION UTILITIES =====

  /// Validate permission context for operation
  bool validatePermissionContext({
    required bool requiresAuth,
    required bool requiresValidSession,
    String? requiredUserId,
  }) {
    return _authEngine.validatePermissionContext(
      requiresAuth: requiresAuth,
      requiresValidSession: requiresValidSession,
      requiredUserId: requiredUserId,
    );
  }

  /// Get permission denial reason
  String getPermissionDenialReason() {
    return _authEngine.getPermissionDenialReason();
  }

  /// Validate user for operation
  bool validateUserForOperation() {
    return _authEngine.validateUserForOperation();
  }

  /// Check if authentication is required for operation
  bool requiresAuthentication(String operation) {
    return _authEngine.requiresAuthentication(operation);
  }

  // ===== RESOURCE COLLECTION UTILITIES =====

  /// Check if user is owner of any resource
  bool isOwnerOfAny(List<String> resourceIds, String resourceType) {
    return resourceIds.any((id) => 
      getResourcePermission(id, resourceType) == ResourcePermission.owner
    );
  }

  /// Check if user can edit any resource
  bool canEditAny(List<String> resourceIds, String resourceType) {
    return resourceIds.any((id) => 
      hasMinimumPermission(id, resourceType, ResourcePermission.editor)
    );
  }

  /// Get all resources user can edit
  List<String> getEditableResources(List<String> resourceIds, String resourceType) {
    return resourceIds.where((id) => 
      hasMinimumPermission(id, resourceType, ResourcePermission.editor)
    ).toList();
  }

  /// Get all resources user owns
  List<String> getOwnedResources(List<String> resourceIds, String resourceType) {
    return resourceIds.where((id) => 
      getResourcePermission(id, resourceType) == ResourcePermission.owner
    ).toList();
  }

  /// Get all resources user can view
  List<String> getViewableResources(List<String> resourceIds, String resourceType) {
    return resourceIds.where((id) => 
      hasMinimumPermission(id, resourceType, ResourcePermission.viewer)
    ).toList();
  }

  // ===== PERMISSION CONTEXT UTILITIES =====

  /// Get authentication context for logging
  Map<String, dynamic> getAuthContext() {
    return _authEngine.getAuthContext();
  }

  /// Get user permission context
  Map<String, dynamic> getUserPermissionContext() {
    return _authEngine.getUserPermissionContext();
  }

  /// Create general permission context
  Map<String, dynamic> createPermissionContext({
    required String resourceType,
    required String resourceId,
    required String operation,
  }) {
    return {
      'resourceType': resourceType,
      'resourceId': resourceId,
      'operation': operation,
      'userId': _authEngine.currentUserId,
      'isAuthenticated': _authEngine.isAuthenticated,
      'hasValidSession': _authEngine.hasValidSession,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // ===== PERMISSION CHECKING PATTERNS =====

  /// Check if user can perform operation on resource
  bool canPerformOperation(String resourceId, String resourceType, String operation) {
    if (!_authEngine.isAuthenticated) return false;
    
    switch (operation.toLowerCase()) {
      case 'create':
        return _authEngine.isAuthenticated;
      case 'view':
        return hasMinimumPermission(resourceId, resourceType, ResourcePermission.viewer);
      case 'edit':
        return hasMinimumPermission(resourceId, resourceType, ResourcePermission.editor);
      case 'delete':
        return hasMinimumPermission(resourceId, resourceType, ResourcePermission.owner);
      case 'share':
        return hasMinimumPermission(resourceId, resourceType, ResourcePermission.viewer);
      default:
        return false;
    }
  }

  /// Check multiple permissions at once
  Map<String, bool> checkMultiplePermissions(
    String resourceId, 
    String resourceType, 
    List<String> operations,
  ) {
    final results = <String, bool>{};
    
    for (final operation in operations) {
      results[operation] = canPerformOperation(resourceId, resourceType, operation);
    }
    
    return results;
  }

  /// Validate permission batch operation
  Map<String, Map<String, bool>> validatePermissionBatch(
    Map<String, String> resources, // resourceId -> resourceType
    List<String> operations,
  ) {
    final results = <String, Map<String, bool>>{};
    
    for (final entry in resources.entries) {
      final resourceId = entry.key;
      final resourceType = entry.value;
      results[resourceId] = checkMultiplePermissions(resourceId, resourceType, operations);
    }
    
    return results;
  }

  // ===== ADMIN AND SPECIAL PERMISSIONS =====

  /// Check if user has admin privileges
  bool hasAdminPrivileges() {
    return _authEngine.isAuthenticated; // Could be extended with specific admin checks
  }

  /// Check if user has system-level permissions
  bool hasSystemPermissions() {
    // This could be extended with system admin logic
    return _authEngine.isAuthenticated;
  }

  /// Check if user can access development features
  bool canAccessDevelopmentFeatures() {
    // This could be extended with developer role checks
    return _authEngine.isAuthenticated;
  }

  /// Check if user can perform maintenance operations
  bool canPerformMaintenance() {
    // This could be extended with maintenance role checks
    return _authEngine.isAuthenticated;
  }

  // ===== PERMISSION CONSTANTS AND TYPES =====

  /// Get all available permission types
  List<String> getAvailablePermissionTypes() {
    return [
      PermissionTypes.recipe,
      PermissionTypes.shoppingList,
      PermissionTypes.group,
      PermissionTypes.profile,
      PermissionTypes.content,
    ];
  }

  /// Get all available permission actions
  List<String> getAvailablePermissionActions() {
    return [
      PermissionActions.view,
      PermissionActions.edit,
      PermissionActions.delete,
      PermissionActions.share,
      PermissionActions.invite,
      PermissionActions.manage,
      PermissionActions.create,
    ];
  }

  /// Check if permission type is valid
  bool isValidPermissionType(String type) {
    return getAvailablePermissionTypes().contains(type);
  }

  /// Check if permission action is valid
  bool isValidPermissionAction(String action) {
    return getAvailablePermissionActions().contains(action);
  }

  // ===== PERMISSION CONVERSION UTILITIES =====

  /// Convert resource permission to edit mode
  EditMode resourcePermissionToEditMode(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return EditMode.owner;
      case ResourcePermission.editor:
        return EditMode.collaborative;
      case ResourcePermission.viewer:
        return EditMode.readOnlyWithFork;
      default:
        return EditMode.noAccess;
    }
  }

  /// Convert edit mode to resource permission
  ResourcePermission editModeToResourcePermission(EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
        return ResourcePermission.owner;
      case EditMode.collaborative:
        return ResourcePermission.editor;
      case EditMode.readOnlyWithFork:
        return ResourcePermission.viewer;
      default:
        return ResourcePermission.viewer;
    }
  }

  /// Get permission description
  String getPermissionDescription(ResourcePermission permission) {
    switch (permission) {
      case ResourcePermission.owner:
        return 'Full access including delete and member management';
      case ResourcePermission.editor:
        return 'Can view and edit content';
      case ResourcePermission.viewer:
        return 'Can view content only';
      default:
        return 'No access';
    }
  }

  /// Get edit mode description
  String getEditModeDescription(EditMode editMode) {
    switch (editMode) {
      case EditMode.owner:
        return 'Owner with full control';
      case EditMode.collaborative:
        return 'Collaborative editing enabled';
      case EditMode.readOnlyWithFork:
        return 'Read-only, can fork/duplicate';
      case EditMode.noAccess:
        return 'No access to content';
      default:
        return 'Unknown access mode';
    }
  }

  // ===== ASYNC UTILITY OPERATIONS =====

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    return await _authEngine.getUserProfile(userId);
  }

  /// Validate user exists and is accessible
  Future<bool> validateUserExists(String userId) async {
    return await _authEngine.validateUserExists(userId);
  }

  /// Batch validate users exist
  Future<Map<String, bool>> batchValidateUsersExist(List<String> userIds) async {
    final results = <String, bool>{};
    
    for (final userId in userIds) {
      results[userId] = await validateUserExists(userId);
    }
    
    return results;
  }

  // ===== PERMISSION DEBUGGING UTILITIES =====

  /// Create debug permission summary
  Map<String, dynamic> createDebugPermissionSummary(String resourceId, String resourceType) {
    return {
      'resourceId': resourceId,
      'resourceType': resourceType,
      'currentUser': _authEngine.currentUserId,
      'isAuthenticated': _authEngine.isAuthenticated,
      'hasValidSession': _authEngine.hasValidSession,
      'permissionLevel': getResourcePermission(resourceId, resourceType).toString(),
      'availableOperations': getAvailablePermissionActions(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Log permission check for debugging
  void logPermissionCheck(String resourceId, String resourceType, String operation, bool result) {
    if (result) {
      AppLogger.debug('✅ Permission granted: $operation on $resourceType:$resourceId');
    } else {
      AppLogger.debug('❌ Permission denied: $operation on $resourceType:$resourceId');
    }
  }
}

/// Constants for permission types
class PermissionTypes {
  static const String recipe = 'recipe';
  static const String shoppingList = 'shopping_list';
  static const String group = 'group';
  static const String profile = 'profile';
  static const String content = 'content';
}

/// Constants for permission actions
class PermissionActions {
  static const String view = 'view';
  static const String edit = 'edit';
  static const String delete = 'delete';
  static const String share = 'share';
  static const String invite = 'invite';
  static const String manage = 'manage';
  static const String create = 'create';
}