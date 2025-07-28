// lib/core/permissions/validators/base_validator.dart

import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/core/permissions/validators/validation_result.dart';

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