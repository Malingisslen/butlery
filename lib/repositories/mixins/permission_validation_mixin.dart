/// Comprehensive permission validation mixin providing robust security enforcement for Firebase repository operations.
/// This mixin implements a sophisticated permission validation system that ensures proper authorization
/// and access control throughout the Butlery cooking application. It provides comprehensive validation
/// methods for ownership verification, read/write permissions, user operations, and data integrity
/// checks that protect user data and maintain security compliance in cooking and social collaboration scenarios.
/// **Architecture Integration:**
/// - Integrates seamlessly with Firebase repositories to provide consistent security enforcement
/// - Implements defense-in-depth security patterns with multiple validation layers
/// - Provides centralized permission logic reducing code duplication across repositories
/// - Supports both individual and collaborative cooking scenarios with appropriate access controls
/// - Enables comprehensive audit logging for security monitoring and compliance tracking
/// **Security Features:**
/// - **Ownership Validation**: Ensures users only access their own cooking data (recipes, shopping lists)
/// - **Read Access Control**: Manages shared content access for collaborative cooking scenarios
/// - **Write Permission Management**: Controls data modification rights for collaborative features
/// - **Field Validation**: Validates data integrity and prevents malicious data injection
/// - **Resource Existence Checks**: Ensures operations target valid, accessible resources
/// - **Audit Logging**: Comprehensive security event logging for monitoring and compliance
/// **Permission Models:**
/// The mixin supports multiple permission models essential for cooking applications:
/// - **Personal Data**: User-owned recipes, shopping lists, and preferences
/// - **Shared Content**: Recipes shared with friends or family members
/// - **Collaborative Editing**: Real-time collaboration on recipes and shopping lists
/// - **Public Resources**: Community recipes and shared cooking content
/// - **Group Management**: Family or friend group access controls
/// **Validation Categories:**
/// - **Ownership Verification**: Confirms users own the resources they're accessing
/// - **Shared Access Rights**: Validates permissions for shared cooking content
/// - **Collaborative Permissions**: Manages multi-user editing and modification rights
/// - **Data Integrity**: Ensures all data meets security and validation requirements
/// - **Resource Security**: Validates resource existence and accessibility
/// **Usage Examples:**
/// ```dart
/// class RecipeRepository with PermissionValidationMixin {
///   Future<void> updateRecipe(Recipe recipe) async {
///     await validateOwnership(
///       currentUserId: currentUserId,
///       resourceOwnerId: recipe.ownerId,
///       resourceType: 'recipe',
///       resourceId: recipe.id,
///     );
///     validateRequiredFields(
///       data: recipe.toMap(),
///       requiredFields: ['title', 'ingredients'],
///       resourceType: 'recipe',
///     );
///     // Proceed with update
///     await _updateRecipeInFirestore(recipe);
///   }
/// }
/// ```

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';

/// Comprehensive permission validation mixin implementing robust security enforcement for Firebase repository operations in cooking-focused applications.
/// This mixin serves as the central security enforcement layer for all repository operations throughout
/// the Butlery application, providing comprehensive permission validation, access control, and data
/// integrity checks. It implements defense-in-depth security patterns ensuring user data protection,
/// collaborative feature security, and compliance with privacy requirements for Swedish cooking applications.
/// **Security Architecture:**
/// - **Multi-Layer Validation**: Comprehensive permission checks at multiple application layers
/// - **Centralized Enforcement**: Consistent security rules across all repository implementations
/// - **Audit Integration**: Complete security event logging for monitoring and compliance
/// - **Data Integrity**: Robust validation preventing malicious data injection and corruption
/// - **Privacy Protection**: Strong user data isolation and access control mechanisms
/// **Design Principles:**
/// The mixin reflects the trust and safety of cooking with comprehensive security validation,
/// robust access controls, and transparent audit logging that protects user privacy while enabling
/// secure collaborative cooking experiences for Swedish users and their families.
mixin PermissionValidationMixin {
  /// Validates that the current user owns the specified resource with comprehensive security checks.
  /// Performs thorough ownership verification ensuring that users can only access and modify
  /// resources they own. This is fundamental for protecting personal cooking data including
  /// recipes, shopping lists, meal plans, and other user-specific content in the cooking application.
  /// [currentUserId] The ID of the user attempting the operation (null indicates unauthenticated)
  /// [resourceOwnerId] The ID of the user who owns the resource being accessed
  /// [resourceType] The type of resource being validated (e.g., 'recipe', 'shopping_list')
  /// [resourceId] Optional resource identifier for detailed audit logging
  /// Throws [PermissionDeniedException] if the user is not authenticated or doesn't own the resource
  /// **Security Enforcement:**
  /// - Validates user authentication before resource access
  /// - Confirms ownership match between current user and resource owner
  /// - Logs security violations for audit and monitoring purposes
  /// - Provides clear error messaging for debugging and user feedback
  /// **Audit Logging:**
  /// All ownership validation attempts are logged with appropriate security event details
  /// for monitoring, compliance, and security incident investigation.
  /// Example:
  /// ```dart
  /// await validateOwnership(
  ///   currentUserId: currentUser.id,
  ///   resourceOwnerId: recipe.ownerId,
  ///   resourceType: 'recipe',
  ///   resourceId: recipe.id,
  /// );
  /// // User confirmed as owner, can proceed with operation
  /// ```
  Future<void> validateOwnership({
    required String? currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    String? resourceId,
  }) async {
    if (currentUserId == null) {
      throw PermissionDeniedException(
        'User must be authenticated',
        resource: resourceType,
        operation: 'validateOwnership',
      );
    }

    if (currentUserId != resourceOwnerId) {
      AppLogger.warning(
        'Permission denied: User $currentUserId attempted to access $resourceType owned by $resourceOwnerId',
      );
      throw PermissionDeniedException(
        'User does not own this $resourceType',
        resource: resourceType,
        operation: 'access',
        userId: currentUserId,
      );
    }
  }

  /// Validates comprehensive read access permissions for shared cooking resources.
  /// Evaluates whether the current user has appropriate read permissions for a resource,
  /// supporting multiple access scenarios including ownership, explicit sharing, and public
  /// access. This enables flexible content sharing for collaborative cooking while maintaining
  /// proper security boundaries and user privacy protection.
  /// [currentUserId] The ID of the user requesting read access (null for unauthenticated)
  /// [resourceOwnerId] The ID of the user who owns the resource
  /// [sharedWithUserIds] Optional list of user IDs with whom the resource is explicitly shared
  /// [isPublic] Whether the resource is publicly accessible to all users
  /// Returns true if the user has read access, false otherwise
  /// **Access Hierarchy:**
  /// 1. **Owner Access**: Resource owners always have full read access
  /// 2. **Public Access**: Public resources are readable by all authenticated users
  /// 3. **Explicit Sharing**: Users in the shared list have read access
  /// 4. **Default Denial**: All other access attempts are denied
  /// **Sharing Scenarios:**
  /// - **Family Recipes**: Shared between family members for collaborative cooking
  /// - **Friend Sharing**: Recipes shared with specific friends
  /// - **Community Content**: Public recipes available to all users
  /// - **Group Collaboration**: Shopping lists shared with cooking groups
  /// Example:
  /// ```dart
  /// final canRead = await hasReadAccess(
  ///   currentUserId: currentUser.id,
  ///   resourceOwnerId: recipe.ownerId,
  ///   sharedWithUserIds: recipe.sharedWith,
  ///   isPublic: recipe.isPublic,
  /// );
  /// if (canRead) {
  ///   displayRecipe(recipe);
  /// } else {
  ///   showAccessDenied();
  /// }
  /// ```
  Future<bool> hasReadAccess({
    required String? currentUserId,
    required String resourceOwnerId,
    List<String>? sharedWithUserIds,
    bool isPublic = false,
  }) async {
    if (currentUserId == null) {
      return false;
    }

    // Owner always has access
    if (currentUserId == resourceOwnerId) {
      return true;
    }

    // Check if public resource
    if (isPublic) {
      return true;
    }

    // Check if user is in shared list
    if (sharedWithUserIds != null &&
        sharedWithUserIds.contains(currentUserId)) {
      return true;
    }

    return false;
  }

  /// Validates comprehensive write permissions for collaborative cooking resource modification.
  /// Enforces strict write access controls ensuring only authorized users can modify cooking
  /// resources. This supports collaborative cooking scenarios while maintaining data integrity
  /// and preventing unauthorized modifications to recipes, shopping lists, and other shared content.
  /// [currentUserId] The ID of the user attempting to modify the resource
  /// [resourceOwnerId] The ID of the user who owns the resource
  /// [resourceType] The type of resource being modified (e.g., 'recipe', 'shopping_list')
  /// [resourceId] Optional resource identifier for detailed audit logging
  /// [collaborators] Optional list of user IDs with collaborative write permissions
  /// Throws [PermissionDeniedException] if the user lacks write permissions
  /// **Write Permission Hierarchy:**
  /// 1. **Owner Rights**: Resource owners have full write permissions
  /// 2. **Collaborator Access**: Users in the collaborators list can modify content
  /// 3. **Default Denial**: All other write attempts are blocked
  /// **Collaborative Scenarios:**
  /// - **Recipe Co-creation**: Multiple users editing recipes together
  /// - **Shared Shopping Lists**: Family members adding items to shared lists
  /// - **Menu Planning**: Couples planning meals collaboratively
  /// - **Group Cooking**: Friends preparing meals together with shared resources
  /// **Security Logging:**
  /// All write permission validation attempts are logged with comprehensive details
  /// for security monitoring and unauthorized access detection.
  /// Example:
  /// ```dart
  /// await validateWritePermission(
  ///   currentUserId: currentUser.id,
  ///   resourceOwnerId: recipe.ownerId,
  ///   resourceType: 'recipe',
  ///   resourceId: recipe.id,
  ///   collaborators: recipe.collaborators,
  /// );
  /// // User confirmed to have write access, can proceed with modification
  /// ```
  Future<void> validateWritePermission({
    required String? currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    String? resourceId,
    List<String>? collaborators,
  }) async {
    if (currentUserId == null) {
      throw PermissionDeniedException(
        'User must be authenticated to write',
        resource: resourceType,
        operation: 'write',
      );
    }

    // Owner can always write
    if (currentUserId == resourceOwnerId) {
      return;
    }

    // Check if user is a collaborator (for resources that support collaboration)
    if (collaborators != null && collaborators.contains(currentUserId)) {
      return;
    }

    AppLogger.warning(
      'Write permission denied: User $currentUserId attempted to modify $resourceType owned by $resourceOwnerId',
    );
    throw PermissionDeniedException(
      'User lacks write permission for this $resourceType',
      resource: resourceType,
      operation: 'write',
      userId: currentUserId,
    );
  }

  /// Validates that a user can perform an operation on their own data
  Future<void> validateSelfOperation({
    required String? currentUserId,
    required String targetUserId,
    required String operation,
  }) async {
    if (currentUserId == null) {
      throw PermissionDeniedException(
        'User must be authenticated',
        operation: operation,
      );
    }

    if (currentUserId != targetUserId) {
      throw PermissionDeniedException(
        'Users can only $operation their own data',
        operation: operation,
        userId: currentUserId,
      );
    }
  }

  /// Validates that required fields exist in data
  void validateRequiredFields({
    required Map<String, dynamic> data,
    required List<String> requiredFields,
    required String resourceType,
  }) {
    final missingFields = requiredFields
        .where((field) => !data.containsKey(field))
        .toList();

    if (missingFields.isNotEmpty) {
      throw SecurityViolationException(
        'Missing required fields for $resourceType',
        details: 'Missing: ${missingFields.join(', ')}',
      );
    }
  }

  /// Validates field constraints (e.g., string length)
  void validateFieldConstraints({
    required Map<String, dynamic> data,
    required Map<String, FieldConstraint> constraints,
    required String resourceType,
  }) {
    constraints.forEach((field, constraint) {
      if (data.containsKey(field)) {
        final value = data[field];

        // String length constraints
        if (constraint.maxLength != null && value is String) {
          if (value.length > constraint.maxLength!) {
            throw SecurityViolationException(
              'Field $field exceeds maximum length',
              details: 'Max: ${constraint.maxLength}, Actual: ${value.length}',
            );
          }
        }

        if (constraint.minLength != null && value is String) {
          if (value.length < constraint.minLength!) {
            throw SecurityViolationException(
              'Field $field below minimum length',
              details: 'Min: ${constraint.minLength}, Actual: ${value.length}',
            );
          }
        }

        // List size constraints
        if (constraint.maxItems != null && value is List) {
          if (value.length > constraint.maxItems!) {
            throw SecurityViolationException(
              'Field $field exceeds maximum items',
              details: 'Max: ${constraint.maxItems}, Actual: ${value.length}',
            );
          }
        }

        // Allowed values constraint
        if (constraint.allowedValues != null &&
            !constraint.allowedValues!.contains(value)) {
          throw SecurityViolationException(
            'Field $field contains invalid value',
            details:
                'Allowed: ${constraint.allowedValues!.join(', ')}, Actual: $value',
          );
        }
      }
    });
  }

  /// Checks if a document exists and returns it
  Future<DocumentSnapshot> getDocumentWithPermissionCheck({
    required DocumentReference docRef,
    required String? currentUserId,
    required String resourceType,
  }) async {
    if (currentUserId == null) {
      throw PermissionDeniedException(
        'User must be authenticated',
        resource: resourceType,
        operation: 'read',
      );
    }

    final doc = await docRef.get();

    if (!doc.exists) {
      throw ResourceNotFoundException(
        '$resourceType not found',
        resourceType: resourceType,
        resourceId: docRef.id,
      );
    }

    return doc;
  }

  /// Logs permission check for audit trail with optional persistent storage.
  /// This method provides dual-layer audit logging:
  /// 1. **Console Logging**: Always logs to AppLogger for development visibility
  /// 2. **Persistent Logging**: Optionally logs to Firestore for GDPR compliance (Article 30)
  /// The persistent logging is fire-and-forget - failures do not block operations.
  /// This ensures audit logging issues never break application functionality.
  /// [userId] The ID of the user performing the operation
  /// [resource] The resource being accessed (format: "resourceType/resourceId" or "resourceType")
  /// [operation] The operation being performed (read, write, update, delete, create)
  /// [granted] Whether permission was granted or denied
  /// [details] Optional additional context
  /// [auditRepository] Optional repository for persistent audit logging (GDPR compliance)
  /// [metadata] Optional metadata for persistent audit logs (IP address, device info, etc.)
  Future<void> logPermissionCheck({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
    FirebaseAuditRepository? auditRepository,
    Map<String, dynamic>? metadata,
  }) async {
    // ALWAYS log to console for development visibility
    final message =
        'Permission ${granted ? 'GRANTED' : 'DENIED'}: '
        'User=$userId, Resource=$resource, Operation=$operation';

    if (granted) {
      AppLogger.info(message + (details != null ? ', Details=$details' : ''));
    } else {
      AppLogger.warning(
        message + (details != null ? ', Details=$details' : ''),
      );
    }

    // OPTIONALLY persist to Firestore for GDPR compliance (Article 30)
    if (auditRepository != null) {
      try {
        // Parse resource string (format: "resourceType/resourceId" or "resourceType")
        final resourceParts = resource.split('/');
        final resourceType = resourceParts.first;
        final resourceId = resourceParts.length > 1 ? resourceParts[1] : null;

        // Build metadata with additional context
        final auditMetadata = <String, dynamic>{
          'details': ?details,
          if (metadata != null) ...metadata,
        };

        // Fire-and-forget persistent logging (GDPR Article 30 compliance)
        // Note: We don't await this to avoid blocking application operations.
        // BUT-1741: `unawaited` says so out loud. A bare expression statement
        // discarding a future reads identically to the bug this ticket fixed
        // in the shopping modules — a dropped future whose rejection escapes as
        // an unhandled async error — and the only thing separating the two is
        // the `catchError` below, which is easy to delete by accident.
        unawaited(
          auditRepository
              .logPermissionCheck(
                userId: userId,
                operation: operation,
                resourceType: resourceType,
                resourceId: resourceId,
                granted: granted,
                metadata: auditMetadata.isNotEmpty ? auditMetadata : null,
              )
              .catchError((error) {
                // Audit logging failures are logged but never block operations
                AppLogger.error(
                  '⚠️ Failed to persist audit log (non-blocking): $error',
                );
              }),
        );
      } catch (e) {
        // Catch parsing errors - audit logging must never break operations
        AppLogger.error('⚠️ Failed to parse audit log data (non-blocking): $e');
      }
    }
  }
}

/// Defines constraints for a field
class FieldConstraint {
  final int? minLength;
  final int? maxLength;
  final int? maxItems;
  final List<dynamic>? allowedValues;

  const FieldConstraint({
    this.minLength,
    this.maxLength,
    this.maxItems,
    this.allowedValues,
  });
}
