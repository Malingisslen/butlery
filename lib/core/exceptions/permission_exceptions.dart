/// Comprehensive permission exception system implementing intelligent error handling for access control and security violations.
/// This exception system serves as the centralized error handling infrastructure for permission and security
/// violations throughout the Butlery application, providing detailed context for access control failures while
/// maintaining security best practices and comprehensive error reporting. It ensures proper error categorization
/// and contextual information for debugging, monitoring, and user feedback in Swedish cooking application's
/// collaborative features, social interactions, and resource access control scenarios.
/// ## Core Architecture Features
/// **Permission Exception Types**
/// - PermissionDeniedException for access control violations with detailed context and user information
/// - ResourceNotFoundException for missing resource access attempts with resource type identification
/// - SecurityViolationException for security constraint violations with detailed security context
/// - AuthenticationException for authentication requirement failures with user guidance
/// - ValidationException for input validation failures with field-specific error information
/// **Detailed Context Preservation**
/// - Resource identification with type and ID information for debugging and monitoring
/// - Operation context with user ID and action details for comprehensive audit trails
/// - Security violation details with specific constraint information for forensic analysis
/// - Field-level validation context with value information for detailed error reporting
/// **Security-Conscious Design**
/// - Detailed internal logging while maintaining appropriate user-facing error messages
/// - Context preservation for debugging without exposing sensitive security information
/// - Comprehensive toString implementations for development and monitoring purposes
/// - Structured exception hierarchy for proper error handling and recovery strategies
/// ## Usage Examples
/// **Permission Denial Handling:**
/// ```dart
/// class RecipeAccessControl {
///   Future<Recipe> getRecipe(String recipeId, String userId) async {
///     if (!await _hasReadPermission(userId, recipeId)) {
///       throw PermissionDeniedException(
///         'Du har inte behörighet att visa detta recept',
///         resource: 'recipe',
///         operation: 'read',
///         userId: userId,
///       );
///     }
///     return await _repository.getRecipe(recipeId);
///   }
/// }
/// ```
/// **Resource Not Found Handling:**
/// ```dart
/// class GroupService {
///   Future<Group> getGroup(String groupId) async {
///     final group = await _repository.findById(groupId);
///     if (group == null) {
///       throw ResourceNotFoundException(
///         'Gruppen kunde inte hittas',
///         resourceType: 'group',
///         resourceId: groupId,
///       );
///     }
///     return group;
///   }
/// }
/// ```
/// **Security Violation Handling:**
/// ```dart
/// class SecurityService {
///   Future<void> validateSecurityConstraints(String operation, Map<String, dynamic> context) async {
///     if (!await _meetsSecurityRequirements(operation, context)) {
///       throw SecurityViolationException(
///         'Säkerhetsreglerna tillåter inte denna operation',
///         details: 'Operation: $operation, Context: ${context.keys.join(", ")}',
///       );
///     }
///   }
/// }
/// ```
/// **Authentication Requirement Handling:**
/// ```dart
/// class AuthGuard {
///   void requireAuthentication(String? userId, String operation) {
///     if (userId == null) {
///       throw AuthenticationException(
///         'Du måste logga in för att utföra denna åtgärd',
///         details: 'Operation: $operation',
///       );
///     }
///   }
/// }
/// ```
/// **Validation Error Handling:**
/// ```dart
/// class FormValidationService {
///   void validateRecipeData(Map<String, dynamic> data) {
///     if (data['title'] == null || data['title'].toString().trim().isEmpty) {
///       throw ValidationException(
///         'Recepttitel är obligatorisk',
///         field: 'title',
///         value: data['title'],
///       );
///     }
///   }
/// }
/// ```
/// ## Performance Characteristics
/// - **Exception Efficiency**: Lightweight exception creation with minimal memory allocation
/// - **Context Preservation**: Efficient context capture without sensitive data exposure
/// - **String Formatting**: Optimized toString implementations for debugging and logging
/// - **Memory Management**: Proper exception hierarchy with no memory leaks or retention
/// ## Integration Patterns
/// - **Access Control**: Primary exception types for all permission and access control systems
/// - **Security Layer**: Comprehensive security violation reporting with detailed context
/// - **Error Handling**: Structured exception hierarchy for proper error handling and recovery
/// - **Monitoring**: Detailed exception information for security monitoring and audit trails
/// This exception system is essential for maintaining secure, well-monitored, and properly debugged
/// access control throughout the Swedish cooking application while providing comprehensive error
/// context for development, monitoring, and security analysis purposes.

/// Comprehensive exception class for permission and access control violations with detailed context information.
/// This exception is thrown when a user lacks the necessary permissions to perform a specific operation
/// on a resource. It provides detailed context including the specific resource, operation, and user
/// information for comprehensive debugging and security monitoring purposes.
class PermissionDeniedException implements Exception {
  final String message;
  final String? resource;
  final String? operation;
  final String? userId;

  PermissionDeniedException(
    this.message, {
    this.resource,
    this.operation,
    this.userId,
  });

  @override
  String toString() {
    final parts = [
      'PermissionDeniedException: $message',
      if (operation != null) 'Operation: $operation',
      if (resource != null) 'Resource: $resource',
      if (userId != null) 'User: $userId',
    ];
    return parts.join(', ');
  }
}

/// Exception thrown when attempting to access a resource that doesn't exist
class ResourceNotFoundException implements Exception {
  final String message;
  final String? resourceType;
  final String? resourceId;

  ResourceNotFoundException(
    this.message, {
    this.resourceType,
    this.resourceId,
  });

  @override
  String toString() {
    final parts = [
      'ResourceNotFoundException: $message',
      if (resourceType != null) 'Type: $resourceType',
      if (resourceId != null) 'ID: $resourceId',
    ];
    return parts.join(', ');
  }
}

/// Exception thrown when operation violates security constraints
class SecurityViolationException implements Exception {
  final String message;
  final String? details;

  SecurityViolationException(this.message, {this.details});

  @override
  String toString() {
    return 'SecurityViolationException: $message${details != null ? ' - $details' : ''}';
  }
}

/// Exception thrown when user authentication is required but not present
class AuthenticationException implements Exception {
  final String message;
  final String? details;

  AuthenticationException(this.message, {this.details});

  @override
  String toString() {
    return 'AuthenticationException: $message${details != null ? ' - $details' : ''}';
  }
}

/// Exception thrown when input validation fails
class ValidationException implements Exception {
  final String message;
  final String? field;
  final dynamic value;

  ValidationException(this.message, {this.field, this.value});

  @override
  String toString() {
    final parts = [
      'ValidationException: $message',
      if (field != null) 'Field: $field',
      if (value != null) 'Value: $value',
    ];
    return parts.join(', ');
  }
}