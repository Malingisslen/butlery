// lib/core/permissions/validators/validation_result.dart

/// Standardized result container for permission validation operations.
///
/// This class provides a consistent way to communicate the outcomes of permission
/// validation operations throughout the Butlery application. It encapsulates both
/// successful and failed validation results with detailed context information for
/// proper error handling and user feedback.
///
/// **Key Features:**
/// - **Type Safety**: Strongly typed success/failure states prevent ambiguity
/// - **Rich Context**: Additional metadata for debugging and detailed error handling
/// - **User-Friendly Messages**: Localized error messages ready for UI display
/// - **Error Categorization**: Structured error codes for programmatic handling
/// - **Extensible Design**: Context map allows for domain-specific additional data
///
/// **Common Usage Patterns:**
/// ```dart
/// // Basic validation result checking
/// final result = await validator.canEditRecipe(recipeId);
/// if (result.isValid) {
///   // Proceed with operation
/// } else {
///   showError(result.errorMessage);
/// }
/// 
/// // Detailed error handling with codes
/// switch (result.errorCode) {
///   case 'NOT_AUTHENTICATED':
///     navigateToLogin();
///     break;
///   case 'INSUFFICIENT_PERMISSIONS':
///     showPermissionDeniedDialog();
///     break;
///   case 'RESOURCE_NOT_FOUND':
///     showResourceNotFoundMessage();
///     break;
/// }
/// 
/// // Using context for additional information
/// if (result.context?['resource'] == 'recipe') {
///   // Handle recipe-specific error
/// }
/// ```
///
/// **Factory Methods:**
/// Provides convenient factory constructors for common validation scenarios,
/// ensuring consistent error messages and codes across the application while
/// supporting localization and proper error categorization.
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