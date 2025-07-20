// lib/core/permissions/validators/validation_result.dart

/// Result of a permission validation
class PermissionValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? errorCode;
  final Map<String, dynamic>? context;
  
  const PermissionValidationResult({
    required this.isValid,
    this.errorMessage,
    this.errorCode,
    this.context,
  });
  
  /// Create a successful validation result
  factory PermissionValidationResult.success({Map<String, dynamic>? context}) {
    return PermissionValidationResult(
      isValid: true,
      context: context,
    );
  }
  
  /// Create a failed validation result
  factory PermissionValidationResult.failure({
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic>? context,
  }) {
    return PermissionValidationResult(
      isValid: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      context: context,
    );
  }
  
  /// Create a validation result for missing authentication
  factory PermissionValidationResult.notAuthenticated() {
    return PermissionValidationResult.failure(
      errorMessage: 'Du måste vara inloggad för att utföra denna åtgärd',
      errorCode: 'NOT_AUTHENTICATED',
    );
  }
  
  /// Create a validation result for insufficient permissions
  factory PermissionValidationResult.insufficientPermissions({
    required String resource,
    required String action,
  }) {
    return PermissionValidationResult.failure(
      errorMessage: 'Du har inte behörighet att $action för $resource',
      errorCode: 'INSUFFICIENT_PERMISSIONS',
      context: {'resource': resource, 'action': action},
    );
  }
  
  /// Create a validation result for resource not found
  factory PermissionValidationResult.resourceNotFound(String resource) {
    return PermissionValidationResult.failure(
      errorMessage: '$resource hittades inte eller du har inte åtkomst till den',
      errorCode: 'RESOURCE_NOT_FOUND',
      context: {'resource': resource},
    );
  }
}