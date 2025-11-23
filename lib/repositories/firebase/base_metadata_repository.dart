/// Base repository for metadata operations on documents created elsewhere.
/// This abstract base class provides unified patterns for repositories that annotate
/// documents rather than owning them - such as marking content as viewed, dismissed,
/// imported, or tracking social interactions like likes and ratings.
/// Architecture Integration:
/// - Uses PermissionValidationMixin for security enforcement
/// - Integrates with AuthRepository for user authentication
/// - Integrates with FirebaseAuditRepository for GDPR Article 30 compliance
/// - Operates on subcollections for metadata (views, engagements, dismissals, etc.)
/// Key Features:
/// - Subcollection-based metadata storage (replacing deprecated array patterns)
/// - Permission validation for metadata access (can read parent → can annotate)
/// - Comprehensive audit logging for all metadata operations
/// - Batch operations for bulk metadata updates
/// - Self-annotation enforcement (users can only annotate with their own userId)
/// **Usage Example:**
/// ```dart
/// class SharedRecipeViewRepository extends BaseMetadataRepository<ViewMetadata> {
///   SharedRecipeViewRepository({
///     required super.authRepository,
///     super.auditRepository,
///   });
///   @override
///   String get parentCollectionName => 'shared_recipes';
///   @override
///   String get metadataType => 'view';
///   @override
///   ViewMetadata fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
///     ViewMetadata.fromFirestore(doc);
///   @override
///   Map<String, dynamic> toFirestore(ViewMetadata metadata) =>
///     metadata.toFirestore();
///   @override
///   Future<bool> validateMetadataAccess(String userId, String resourceId) async {
///     // User can view metadata if they can read the parent document
///     return await canReadParentDocument(userId, resourceId);
///   }
/// }
/// ```

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';

/// Base class for metadata repositories that annotate documents created elsewhere.
/// This class consolidates duplicate metadata operation patterns across 8+ repositories:
/// - Unified subcollection management (views, engagements, dismissals, etc.)
/// - Unified permission validation (metadata access requires parent document read access)
/// - Unified audit logging (GDPR Article 30 compliance for all metadata operations)
/// - Unified batch operations for bulk metadata updates
/// Pattern Categories:
/// 1. Status Flags: viewed, read, dismissed (BaseSharedContentRepository, Notifications, Messaging)
/// 2. Engagement Tracking: imported, joined (BaseSharedContentRepository, SocialRecipe)
/// 3. Social Interactions: likes, ratings (MenuCollaboration, Comments, Ratings)
/// 4. Membership: members, collaborators (BaseSharedContentRepository)
abstract class BaseMetadataRepository<M> with PermissionValidationMixin {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final FirebaseAuditRepository? _auditRepository;

  BaseMetadataRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository,
        _auditRepository = auditRepository;

  // ===== PROTECTED ACCESSORS =====

  /// Protected access to FirebaseFirestore instance for subclasses
  @protected
  FirebaseFirestore get firestore => _firestore;

  /// Protected access to AuthRepository instance for subclasses
  @protected
  AuthRepository get authRepository => _authRepository;

  /// Protected access to audit repository for explicit logging
  @protected
  FirebaseAuditRepository? get auditRepository => _auditRepository;

  // ===== ABSTRACT METHODS FOR SUBCLASSES =====

  /// The name of the parent Firestore collection (e.g., 'shared_recipes', 'notifications')
  String get parentCollectionName;

  /// The type of metadata this repository manages (e.g., 'view', 'engagement', 'dismissal')
  String get metadataType;

  /// Convert Firestore document to metadata entity
  M fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc);

  /// Convert metadata entity to Firestore data
  Map<String, dynamic> toFirestore(M metadata);

  /// Validate if the user can access metadata for the given resource
  /// Typically: user can annotate if they can read the parent document
  Future<bool> validateMetadataAccess(String userId, String resourceId);

  // ===== DERIVED PROPERTIES =====

  /// Subcollection name for this metadata type (e.g., 'views', 'engagements', 'dismissals')
  String get subcollectionName => '${metadataType}s';

  // ===== AUTHENTICATION =====

  /// Unified authentication check
  String requireCurrentUserId() {
    final uid = _authRepository.currentUserId;
    if (uid == null) {
      throw AuthenticationException(
        'No authenticated user for $metadataType operation',
        details: 'Authentication required for $metadataType operations',
      );
    }
    return uid;
  }

  /// Optional authentication check
  String? get currentUserId => _authRepository.currentUserId;

  // ===== COLLECTION REFERENCES =====

  /// Get parent collection reference
  CollectionReference<Map<String, dynamic>> get parentCollection {
    return _firestore.collection(parentCollectionName);
  }

  /// Get metadata subcollection reference for a specific resource
  CollectionReference<Map<String, dynamic>> getMetadataCollection(
    String resourceId,
  ) {
    return parentCollection.doc(resourceId).collection(subcollectionName);
  }

  // ===== CORE METADATA OPERATIONS =====

  /// Add metadata entry to the resource (subcollection-based pattern).
  /// This is the primary metadata operation replacing deprecated array patterns.
  /// [resourceId] ID of the parent document being annotated
  /// [userId] User performing the annotation (enforces self-annotation)
  /// [additionalData] Optional metadata fields (e.g., 'action', 'targetId', 'reason')
  /// **Security**: Validates metadata access before adding entry
  /// **Audit**: Logs metadata operation to FirebaseAuditRepository (GDPR Article 30)
  /// **Pattern**: Subcollection document with userId as document ID
  /// ```dart
  /// // Example: Mark recipe as viewed
  /// await addMetadata('recipe123', 'user456');
  /// // Creates: shared_recipes/recipe123/views/user456
  /// ```
  Future<void> addMetadata(
    String resourceId,
    String userId, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Step 1: Authenticate
      final currentUserId = requireCurrentUserId();

      // Step 2: Enforce self-annotation (users can only annotate with their own userId)
      if (userId != currentUserId) {
        throw PermissionDeniedException(
          'User $currentUserId cannot add $metadataType for different user $userId',
        );
      }

      // Step 3: Validate metadata access
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      // Step 4: Log permission check (console + persistent audit for GDPR)
      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName/$userId',
        operation: 'add_$metadataType',
        granted: canAccess,
        details: additionalData?.toString(),
        auditRepository: _auditRepository,
      );

      // Step 5: Enforce permission
      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to add $metadataType to $parentCollectionName/$resourceId',
        );
      }

      // Step 6: Add metadata entry
      await getMetadataCollection(resourceId).doc(userId).set({
        'userId': userId,
        'timestamp': DateTime.now(),
        ...?additionalData,
      });

      AppLogger.info(
        '$metadataType added: $parentCollectionName/$resourceId by $userId',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to add $metadataType to $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  /// Remove metadata entry from the resource.
  /// [resourceId] ID of the parent document being un-annotated
  /// [userId] User whose annotation is being removed (enforces self-removal)
  /// **Security**: Validates metadata access and enforces self-removal
  /// **Audit**: Logs metadata removal to FirebaseAuditRepository
  Future<void> removeMetadata(String resourceId, String userId) async {
    try {
      // Step 1: Authenticate
      final currentUserId = requireCurrentUserId();

      // Step 2: Enforce self-removal (users can only remove their own metadata)
      if (userId != currentUserId) {
        throw PermissionDeniedException(
          'User $currentUserId cannot remove $metadataType for different user $userId',
        );
      }

      // Step 3: Validate metadata access
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      // Step 4: Log permission check
      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName/$userId',
        operation: 'remove_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      // Step 5: Enforce permission
      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to remove $metadataType from $parentCollectionName/$resourceId',
        );
      }

      // Step 6: Remove metadata entry
      await getMetadataCollection(resourceId).doc(userId).delete();

      AppLogger.info(
        '$metadataType removed: $parentCollectionName/$resourceId by $userId',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove $metadataType from $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  /// Check if metadata exists for the given user and resource.
  /// [resourceId] ID of the parent document
  /// [userId] User whose metadata to check
  /// Returns true if metadata entry exists, false otherwise
  /// **Security**: No permission validation (existence check is non-sensitive)
  Future<bool> hasMetadata(String resourceId, String userId) async {
    try {
      final doc = await getMetadataCollection(resourceId).doc(userId).get();
      return doc.exists;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check $metadataType existence for $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get specific metadata entry for a user and resource.
  /// [resourceId] ID of the parent document
  /// [userId] User whose metadata to retrieve
  /// Returns metadata entity if exists, null otherwise
  /// **Security**: Validates metadata access before returning data
  Future<M?> getMetadata(String resourceId, String userId) async {
    try {
      // Step 1: Authenticate
      final currentUserId = requireCurrentUserId();

      // Step 2: Validate metadata access
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      // Step 3: Log permission check
      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName/$userId',
        operation: 'get_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      // Step 4: Enforce permission
      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to read $metadataType from $parentCollectionName/$resourceId',
        );
      }

      // Step 5: Fetch metadata
      final doc = await getMetadataCollection(resourceId).doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      return fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to get $metadataType from $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all metadata entries for a resource.
  /// [resourceId] ID of the parent document
  /// Returns list of all metadata entries for the resource
  /// **Security**: Validates metadata access before returning data
  /// **Use Case**: View counts, engagement statistics, member lists
  Future<List<M>> getMetadataForResource(String resourceId) async {
    try {
      // Step 1: Authenticate
      final currentUserId = requireCurrentUserId();

      // Step 2: Validate metadata access
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      // Step 3: Log permission check
      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName',
        operation: 'list_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      // Step 4: Enforce permission
      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to list $metadataType from $parentCollectionName/$resourceId',
        );
      }

      // Step 5: Fetch all metadata entries
      final snapshot = await getMetadataCollection(resourceId).get();

      return snapshot.docs.map((doc) => fromFirestore(doc)).toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to list $metadataType from $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get metadata count for a resource (e.g., view count, like count).
  /// [resourceId] ID of the parent document
  /// Returns count of metadata entries for the resource
  /// **Security**: Validates metadata access before returning count
  Future<int> getMetadataCount(String resourceId) async {
    try {
      // Step 1: Authenticate
      final currentUserId = requireCurrentUserId();

      // Step 2: Validate metadata access
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      // Step 3: Log permission check
      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName',
        operation: 'count_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      // Step 4: Enforce permission
      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to count $metadataType from $parentCollectionName/$resourceId',
        );
      }

      // Step 5: Count metadata entries
      final snapshot = await getMetadataCollection(resourceId).get();

      return snapshot.size;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to count $metadataType from $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  // ===== PARENT DOCUMENT FIELD OPERATIONS =====

  /// Update a field in the parent document (e.g., cached counts, aggregates).
  /// [resourceId] ID of the parent document
  /// [fieldName] Name of the field to update
  /// [value] New value for the field
  /// **Security**: No permission validation (subclasses should validate)
  /// **Use Case**: Update cached averageRating, viewCount, likeCount fields
  @protected
  Future<void> updateParentField(
    String resourceId,
    String fieldName,
    dynamic value,
  ) async {
    try {
      await parentCollection.doc(resourceId).update({fieldName: value});

      AppLogger.info(
        'Parent field updated: $parentCollectionName/$resourceId.$fieldName = $value',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to update parent field $parentCollectionName/$resourceId.$fieldName: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  /// Increment a field in the parent document (e.g., view count, like count).
  /// [resourceId] ID of the parent document
  /// [fieldName] Name of the field to increment
  /// [amount] Amount to increment (default: 1, can be negative for decrement)
  /// **Security**: No permission validation (subclasses should validate)
  /// **Use Case**: Increment/decrement cached counts without fetching document
  @protected
  Future<void> incrementParentField(
    String resourceId,
    String fieldName, {
    int amount = 1,
  }) async {
    try {
      await parentCollection.doc(resourceId).update({
        fieldName: FieldValue.increment(amount),
      });

      AppLogger.info(
        'Parent field incremented: $parentCollectionName/$resourceId.$fieldName by $amount',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to increment parent field $parentCollectionName/$resourceId.$fieldName: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  // ===== BATCH OPERATIONS =====

  /// Add metadata to multiple resources in batch.
  /// [resourceIds] List of parent document IDs
  /// [userId] User performing the annotations
  /// [additionalData] Optional metadata fields for all entries
  /// **Security**: Validates metadata access for each resource
  /// **Use Case**: Mark multiple items as read, bulk dismiss notifications
  Future<void> addMetadataBatch(
    List<String> resourceIds,
    String userId, {
    Map<String, dynamic>? additionalData,
  }) async {
    // Use sequential processing to ensure proper permission validation
    // for each resource (cannot batch permission checks)
    for (final resourceId in resourceIds) {
      await addMetadata(resourceId, userId, additionalData: additionalData);
    }

    AppLogger.info(
      'Batch $metadataType added: ${resourceIds.length} resources by $userId',
    );
  }

  /// Remove metadata from multiple resources in batch.
  /// [resourceIds] List of parent document IDs
  /// [userId] User whose annotations are being removed
  /// **Security**: Validates metadata access and enforces self-removal for each resource
  Future<void> removeMetadataBatch(
    List<String> resourceIds,
    String userId,
  ) async {
    // Use sequential processing to ensure proper permission validation
    for (final resourceId in resourceIds) {
      await removeMetadata(resourceId, userId);
    }

    AppLogger.info(
      'Batch $metadataType removed: ${resourceIds.length} resources by $userId',
    );
  }
}
