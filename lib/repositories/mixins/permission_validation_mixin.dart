// lib/repositories/mixins/permission_validation_mixin.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/exceptions/permission_exceptions.dart';
import '../../core/utils/logger.dart';

/// Mixin to provide permission validation methods for Firebase repositories
mixin PermissionValidationMixin {

  /// Validates that a user owns a resource
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

  /// Validates that a user has read access to a shared resource
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
    if (sharedWithUserIds != null && sharedWithUserIds.contains(currentUserId)) {
      return true;
    }

    return false;
  }

  /// Validates write permission for a resource
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
    final missingFields = requiredFields.where((field) => !data.containsKey(field)).toList();
    
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
        if (constraint.allowedValues != null && !constraint.allowedValues!.contains(value)) {
          throw SecurityViolationException(
            'Field $field contains invalid value',
            details: 'Allowed: ${constraint.allowedValues!.join(', ')}, Actual: $value',
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

  /// Logs permission check for audit trail
  void logPermissionCheck({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  }) {
    final message = 'Permission ${granted ? 'GRANTED' : 'DENIED'}: '
        'User=$userId, Resource=$resource, Operation=$operation';
    
    if (granted) {
      AppLogger.info(message + (details != null ? ', Details=$details' : ''));
    } else {
      AppLogger.warning(message + (details != null ? ', Details=$details' : ''));
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