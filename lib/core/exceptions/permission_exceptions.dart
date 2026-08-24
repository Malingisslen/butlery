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

import 'package:butlery/core/utils/log_sanitizer.dart';

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

  /// Masked at the STRING boundary, not in the fields.
  ///
  /// `toString()` is what leaves the device: `AppLogger` hands the exception
  /// OBJECT to `FirebaseCrashlytics.recordError` unchanged, an uncaught
  /// exception reaches `recordError` from `main.dart` without passing any
  /// logger at all, and on web Crashlytics is skipped so the scrubbed web
  /// reporter reads `error.toString()` directly. All three go through here.
  ///
  /// The fields keep their raw values, so a debugger and any local handler are
  /// unaffected (BUT-1897).
  ///
  /// Crashlytics still groups these reports by type — but NOT because the
  /// object is passed through: `recordError` sends `exception.toString()`, so
  /// the object never crosses the channel and `runtimeType` is not what the
  /// grouping sees. It survives because the type LABEL is built outside the
  /// masked span, immediately below. That distinction matters: it means the
  /// label's position is load-bearing, not incidental.
  ///
  /// The exception's own NAME stays OUTSIDE the mask, and that is not cosmetic:
  /// `PermissionDeniedException` is 25 alphanumeric characters, which falls
  /// inside the masker's 20-28 window, so masking the label along with the body
  /// turned every one of these into `Perm***`. (A Firebase uid is 28; it is the
  /// WINDOW they share, not the length. Narrowing the rule to exactly 28 would
  /// quietly re-open the label case.) Caught by the existing tests on the first
  /// run.
  ///
  /// The whole joined string is masked rather than the id fields alone, because
  /// a uid reaches this text by routes a named-field rule cannot see: some sites
  /// interpolate it into `message` ("User $userId does not have permission…")
  /// and some put it inside `resource` (`storage/users/<uid>/…`). Masking only
  /// the named field would leave both open.
  ///
  /// No counts here on purpose. Every number this paragraph has carried was
  /// wrong at least once and corrected at least twice; the rule is what a reader
  /// needs, and the rule does not rot.
  ///
  @override
  String toString() {
    final parts = [
      message,
      if (operation != null) 'Operation: $operation',
      if (resource != null) 'Resource: $resource',
      if (userId != null) 'User: $userId',
    ];
    return 'PermissionDeniedException: '
        '${LogSanitizer.maskIdentifiers(parts.join(', '))}';
  }
}

/// BUT-1726: a membership change was computed against a copy of the resource
/// the server has already moved past, so applying it would replay a decision
/// made about state that no longer exists — reinstating a member removed on
/// another device, or dropping one added there.
///
/// A [PermissionDeniedException] subtype so every existing `on
/// PermissionDeniedException` handler keeps catching it, but distinguishable
/// where the wording matters: "you may not do this" and "this moved under you,
/// look again" are different things to tell someone, and the second one is
/// fixed by reloading.
class StaleAccessControlBaseException extends PermissionDeniedException {
  StaleAccessControlBaseException(
    super.message, {
    super.resource,
    super.operation,
    super.userId,
    this.driftedFields = const [],
  });

  /// The access-control fields that disagree between the caller's base and the
  /// server's copy — for the audit trail, never for the user-facing message.
  final List<String> driftedFields;

  /// Overrides its parent's `toString()`, so it needs the mask in its own
  /// right — inheriting the reasoning does not inherit the call.
  @override
  String toString() {
    final body =
        '$message'
        '${driftedFields.isEmpty ? '' : ', Drifted: ${driftedFields.join(", ")}'}'
        '${resource == null ? '' : ', Resource: $resource'}'
        '${userId == null ? '' : ', User: $userId'}';
    return 'StaleAccessControlBaseException: '
        '${LogSanitizer.maskIdentifiers(body)}';
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

  /// See [PermissionDeniedException.toString] for why the mask sits here.
  /// `resourceId` is the field that started BUT-1897: it can hold a DM's
  /// `direct_<uidA>_<uidB>`, which is a social-graph edge rather than an id.
  @override
  String toString() {
    final parts = [
      message,
      if (resourceType != null) 'Type: $resourceType',
      if (resourceId != null) 'ID: $resourceId',
    ];
    return 'ResourceNotFoundException: '
        '${LogSanitizer.maskIdentifiers(parts.join(', '))}';
  }
}

/// Exception thrown when operation violates security constraints
class SecurityViolationException implements Exception {
  final String message;
  final String? details;

  SecurityViolationException(this.message, {this.details});

  /// Masked like its siblings: `details:` is free text a caller fills in, and an
  /// id is a natural thing to put there. Left out of the first pass and it
  /// should not have been (BUT-1897).
  @override
  String toString() {
    final body = '$message${details != null ? ' - $details' : ''}';
    return 'SecurityViolationException: '
        '${LogSanitizer.maskIdentifiers(body)}';
  }
}

/// Exception thrown when user authentication is required but not present
class AuthenticationException implements Exception {
  final String message;
  final String? details;

  AuthenticationException(this.message, {this.details});

  /// Masked for the same reason as its siblings — `details:` is free text a
  /// caller fills in, and "which user was not signed in" is a natural thing to
  /// put there.
  @override
  String toString() {
    final body = '$message${details != null ? ' - $details' : ''}';
    return 'AuthenticationException: '
        '${LogSanitizer.maskIdentifiers(body)}';
  }
}

/// Exception thrown when input validation fails
class ValidationException implements Exception {
  final String message;
  final String? field;
  final dynamic value;

  ValidationException(this.message, {this.field, this.value});

  /// The rejected VALUE is described, never quoted.
  ///
  /// It is whatever the user typed — a comment body, a recipe title, an email
  /// into a form — so on the Crashlytics path it is free-text personal data
  /// that no identifier rule can recognise. Which field failed, and what kind
  /// of thing was in it, is what a crash report needs; the content is not
  /// (BUT-1897).
  @override
  String toString() {
    final parts = [
      message,
      if (field != null) 'Field: $field',
      if (value != null) 'Value: <${value.runtimeType}>',
    ];
    return 'ValidationException: '
        '${LogSanitizer.maskIdentifiers(parts.join(', '))}';
  }
}
