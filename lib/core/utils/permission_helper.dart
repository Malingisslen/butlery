// lib/core/utils/permission_helper.dart

import 'package:butlery/core/utils/logger.dart';

/// Permission helper utilities for authentication and authorization checks
///
/// This helper provides safe permission checking patterns with:
/// - Consistent null-safe auth validation
/// - Automatic error logging
/// - Resource ID validation
/// - Clean, readable permission checks
///
/// **Usage:**
/// ```dart
/// // Check if user is authenticated
/// final userId = PermissionHelper.requireAuth(
///   getCurrentUserId: () => _permissionService.currentUserId,
///   operationName: 'Create recipe',
/// );
/// if (userId == null) return null;
///
/// // Validate resource ID
/// if (!PermissionHelper.validateResourceId(recipeId, 'recipe')) {
///   return null;
/// }
/// ```
class PermissionHelper {
  /// Require user authentication for an operation
  ///
  /// Returns the current user ID if authenticated, null otherwise.
  /// Logs error if user is not authenticated.
  ///
  /// **Parameters:**
  /// - [getCurrentUserId]: Function to get current user ID
  /// - [operationName]: Human-readable operation description for logging
  /// - [errorMessage]: Optional custom error message (default: 'Du måste vara inloggad')
  ///
  /// **Returns:** User ID if authenticated, null otherwise
  static String? requireAuth({
    required String? Function() getCurrentUserId,
    required String operationName,
    String? errorMessage,
  }) {
    final userId = getCurrentUserId();

    if (userId == null) {
      final message = errorMessage ?? 'Du måste vara inloggad';
      AppLogger.error('❌ $operationName failed: $message');
      return null;
    }

    return userId;
  }

  /// Require authentication and set error state in calling service
  ///
  /// Similar to requireAuth but also calls setError callback.
  ///
  /// **Parameters:**
  /// - [getCurrentUserId]: Function to get current user ID
  /// - [setError]: Callback to set error state in service
  /// - [operationName]: Human-readable operation description for logging
  /// - [errorMessage]: Optional custom error message
  ///
  /// **Returns:** User ID if authenticated, null otherwise
  static String? requireAuthWithError({
    required String? Function() getCurrentUserId,
    required void Function(String) setError,
    required String operationName,
    String? errorMessage,
  }) {
    final userId = getCurrentUserId();

    if (userId == null) {
      final message = errorMessage ?? 'Du måste vara inloggad';
      setError(message);
      AppLogger.error('❌ $operationName failed: $message');
      return null;
    }

    return userId;
  }

  /// Validate resource ID (recipeId, menuId, etc.)
  ///
  /// Checks if resource ID is not null and not empty.
  /// Logs error if validation fails.
  ///
  /// **Parameters:**
  /// - [resourceId]: The resource ID to validate
  /// - [resourceType]: Human-readable resource type (e.g., 'recipe', 'menu')
  /// - [operationName]: Optional operation name for context
  ///
  /// **Returns:** true if valid, false otherwise
  static bool validateResourceId(
    String? resourceId,
    String resourceType, {
    String? operationName,
  }) {
    if (resourceId == null || resourceId.isEmpty) {
      final operation = operationName != null ? ' for $operationName' : '';
      AppLogger.error('❌ Invalid $resourceType ID$operation');
      return false;
    }
    return true;
  }

  /// Check if user owns a resource
  ///
  /// **Parameters:**
  /// - [currentUserId]: Current user ID
  /// - [ownerId]: Resource owner ID
  /// - [resourceType]: Human-readable resource type
  /// - [resourceId]: Resource ID for logging
  ///
  /// **Returns:** true if user owns resource, false otherwise
  static bool isOwner({
    required String? currentUserId,
    required String? ownerId,
    String? resourceType,
    String? resourceId,
  }) {
    if (currentUserId == null || ownerId == null) return false;

    final isOwner = currentUserId == ownerId;

    if (!isOwner && resourceType != null) {
      final resourceInfo = resourceId != null ? ' ($resourceId)' : '';
      AppLogger.warning(
          '⚠️ User $currentUserId does not own $resourceType$resourceInfo');
    }

    return isOwner;
  }

  /// Check if user has specific permission on a resource
  ///
  /// **Parameters:**
  /// - [hasPermission]: Function that checks if user has permission
  /// - [operationName]: Human-readable operation description
  /// - [resourceType]: Human-readable resource type
  /// - [resourceId]: Optional resource ID for logging
  ///
  /// **Returns:** true if user has permission, false otherwise
  static bool checkPermission({
    required bool Function() hasPermission,
    required String operationName,
    String? resourceType,
    String? resourceId,
  }) {
    final allowed = hasPermission();

    if (!allowed) {
      final resource = resourceType != null ? ' on $resourceType' : '';
      final id = resourceId != null ? ' ($resourceId)' : '';
      AppLogger.error('❌ $operationName failed: No permission$resource$id');
    }

    return allowed;
  }

  /// Combined auth + resource validation check
  ///
  /// Convenience method that checks both authentication and resource ID.
  ///
  /// **Parameters:**
  /// - [getCurrentUserId]: Function to get current user ID
  /// - [resourceId]: Resource ID to validate
  /// - [resourceType]: Human-readable resource type
  /// - [operationName]: Human-readable operation description
  ///
  /// **Returns:** User ID if both checks pass, null otherwise
  static String? requireAuthAndResource({
    required String? Function() getCurrentUserId,
    required String? resourceId,
    required String resourceType,
    required String operationName,
  }) {
    // Check authentication
    final userId = requireAuth(
      getCurrentUserId: getCurrentUserId,
      operationName: operationName,
    );
    if (userId == null) return null;

    // Validate resource ID
    if (!validateResourceId(resourceId, resourceType,
        operationName: operationName)) {
      return null;
    }

    return userId;
  }

  /// Check if user is authenticated (boolean version)
  ///
  /// Simple boolean check without logging.
  ///
  /// **Parameters:**
  /// - [getCurrentUserId]: Function to get current user ID
  ///
  /// **Returns:** true if authenticated, false otherwise
  static bool isAuthenticated({
    required String? Function() getCurrentUserId,
  }) {
    return getCurrentUserId() != null;
  }

  /// Get authenticated user ID or default value
  ///
  /// **Parameters:**
  /// - [getCurrentUserId]: Function to get current user ID
  /// - [defaultValue]: Default value if not authenticated
  ///
  /// **Returns:** User ID or default value
  static String getAuthenticatedUserOrDefault({
    required String? Function() getCurrentUserId,
    String defaultValue = '',
  }) {
    return getCurrentUserId() ?? defaultValue;
  }
}
