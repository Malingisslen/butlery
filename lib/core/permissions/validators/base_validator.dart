// lib/core/permissions/validators/base_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

/// Abstract base class for all permission validators in the system.
///
/// This class provides common validation functionality that all specific
/// permission validators can build upon. It handles basic authentication
/// checks, session validation, and provides access to the permission service.
///
/// Subclasses should extend this class and implement domain-specific
/// validation logic while leveraging the common functionality provided here.
///
/// Example usage:
/// ```dart
/// class RecipePermissionValidator extends BasePermissionValidator {
///   PermissionValidationResult validateRecipeAccess(String recipeId) {
///     final basicResult = validateBasicPermissions();
///     if (!basicResult.isValid) return basicResult;
///     
///     // Add recipe-specific validation logic
///     return PermissionValidationResult.success();
///   }
/// }
/// ```
abstract class BasePermissionValidator {
  /// Access to the permission service for validation operations.
  ///
  /// Retrieves the permission service instance from the dependency injection
  /// container. This service provides access to user authentication state,
  /// permission checking methods, and session management.
  PermissionService get _permissionService => sl<PermissionService>();
  
  /// Validates that the current user is properly authenticated.
  ///
  /// This is the most basic validation check that should be performed
  /// before any permission-protected operation. It verifies that a user
  /// is currently logged in with valid credentials.
  ///
  /// Returns [PermissionValidationResult.success] if the user is authenticated,
  /// or [PermissionValidationResult.notAuthenticated] if no valid user session exists.
  ///
  /// Example usage:
  /// ```dart
  /// final authResult = validateAuthentication();
  /// if (!authResult.isValid) {
  ///   showLoginDialog();
  ///   return;
  /// }
  /// ```
  PermissionValidationResult validateAuthentication() {
    if (!_permissionService.isAuthenticated) {
      return PermissionValidationResult.notAuthenticated();
    }
    return PermissionValidationResult.success();
  }
  
  /// Validates basic user permissions including authentication and session validity.
  ///
  /// This method performs comprehensive basic validation that should be the
  /// foundation for all permission checks. It verifies:
  /// 1. User is authenticated
  /// 2. User session is still valid and hasn't expired
  ///
  /// This is typically called as the first step in more specific permission
  /// validation methods to ensure the user context is valid before proceeding
  /// with domain-specific checks.
  ///
  /// Returns [PermissionValidationResult.success] if all basic validations pass,
  /// or an appropriate failure result with error details if any validation fails.
  ///
  /// Example usage:
  /// ```dart
  /// PermissionValidationResult validateRecipeEdit(String recipeId) {
  ///   final basicResult = validateBasicPermissions();
  ///   if (!basicResult.isValid) return basicResult;
  ///   
  ///   // Proceed with recipe-specific validation
  ///   return validateRecipeOwnership(recipeId);
  /// }
  /// ```
  PermissionValidationResult validateBasicPermissions() {
    final authResult = validateAuthentication();
    if (!authResult.isValid) return authResult;
    
    if (!_permissionService.hasValidSession) {
      return PermissionValidationResult.failure(
        errorMessage: 'User session has expired, please log in again',
        errorCode: 'SESSION_EXPIRED',
      );
    }
    
    return PermissionValidationResult.success();
  }
}