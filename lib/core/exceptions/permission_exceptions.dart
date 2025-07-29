// lib/core/exceptions/permission_exceptions.dart

/// Exception thrown when a user lacks permission to perform an operation
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