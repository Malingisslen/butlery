/// Base repository for metadata operations (views, dismissals, engagements) on documents
/// created elsewhere. Uses subcollections for metadata storage with permission validation.

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';

abstract class BaseMetadataRepository<M> with PermissionValidationMixin {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final FirebaseAuditRepository? _auditRepository;

  BaseMetadataRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authRepository = authRepository,
       _auditRepository = auditRepository;

  @protected
  FirebaseFirestore get firestore => _firestore;

  @protected
  AuthRepository get authRepository => _authRepository;

  @protected
  FirebaseAuditRepository? get auditRepository => _auditRepository;

  String get parentCollectionName;
  String get metadataType;
  M fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toFirestore(M metadata);
  Future<bool> validateMetadataAccess(String userId, String resourceId);

  String get subcollectionName => '${metadataType}s';

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

  String? get currentUserId => _authRepository.currentUserId;

  CollectionReference<Map<String, dynamic>> get parentCollection {
    return _firestore.collection(parentCollectionName);
  }

  CollectionReference<Map<String, dynamic>> getMetadataCollection(
    String resourceId,
  ) {
    return parentCollection.doc(resourceId).collection(subcollectionName);
  }

  Future<void> addMetadata(
    String resourceId,
    String userId, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUserId = requireCurrentUserId();

      if (userId != currentUserId) {
        throw PermissionDeniedException(
          'User $currentUserId cannot add $metadataType for different user $userId',
        );
      }

      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      await logPermissionCheck(
        userId: currentUserId,
        resource:
            '$parentCollectionName/$resourceId/$subcollectionName/$userId',
        operation: 'add_$metadataType',
        granted: canAccess,
        details: additionalData?.toString(),
        auditRepository: _auditRepository,
      );

      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to add $metadataType to $parentCollectionName/$resourceId',
        );
      }

      await getMetadataCollection(resourceId).doc(userId).set({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(
          clock.now().add(const Duration(days: 90)),
        ),
        ...?additionalData,
      });

      AppLogger.info(
        '$metadataType added: $parentCollectionName/$resourceId by ${userId.maskedUserId}',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to add $metadataType to $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  Future<void> removeMetadata(String resourceId, String userId) async {
    try {
      final currentUserId = requireCurrentUserId();

      if (userId != currentUserId) {
        throw PermissionDeniedException(
          'User $currentUserId cannot remove $metadataType for different user $userId',
        );
      }

      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      await logPermissionCheck(
        userId: currentUserId,
        resource:
            '$parentCollectionName/$resourceId/$subcollectionName/$userId',
        operation: 'remove_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to remove $metadataType from $parentCollectionName/$resourceId',
        );
      }

      await getMetadataCollection(resourceId).doc(userId).delete();

      AppLogger.info(
        '$metadataType removed: $parentCollectionName/$resourceId by ${userId.maskedUserId}',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove $metadataType from $parentCollectionName/$resourceId: $e',
        stackTrace,
      );
      rethrow;
    }
  }

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

  Future<M?> getMetadata(String resourceId, String userId) async {
    try {
      final currentUserId = requireCurrentUserId();
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      await logPermissionCheck(
        userId: currentUserId,
        resource:
            '$parentCollectionName/$resourceId/$subcollectionName/$userId',
        operation: 'get_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to read $metadataType from $parentCollectionName/$resourceId',
        );
      }

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

  Future<List<M>> getMetadataForResource(String resourceId) async {
    try {
      final currentUserId = requireCurrentUserId();
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName',
        operation: 'list_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to list $metadataType from $parentCollectionName/$resourceId',
        );
      }

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

  Future<int> getMetadataCount(String resourceId) async {
    try {
      final currentUserId = requireCurrentUserId();
      final canAccess = await validateMetadataAccess(currentUserId, resourceId);

      await logPermissionCheck(
        userId: currentUserId,
        resource: '$parentCollectionName/$resourceId/$subcollectionName',
        operation: 'count_$metadataType',
        granted: canAccess,
        auditRepository: _auditRepository,
      );

      if (!canAccess) {
        throw PermissionDeniedException(
          'User $currentUserId does not have permission to count $metadataType from $parentCollectionName/$resourceId',
        );
      }

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

  Future<void> addMetadataBatch(
    List<String> resourceIds,
    String userId, {
    Map<String, dynamic>? additionalData,
  }) async {
    for (final resourceId in resourceIds) {
      await addMetadata(resourceId, userId, additionalData: additionalData);
    }

    AppLogger.info(
      'Batch $metadataType added: ${resourceIds.length} resources by ${userId.maskedUserId}',
    );
  }

  Future<void> removeMetadataBatch(
    List<String> resourceIds,
    String userId,
  ) async {
    for (final resourceId in resourceIds) {
      await removeMetadata(resourceId, userId);
    }

    AppLogger.info(
      'Batch $metadataType removed: ${resourceIds.length} resources by ${userId.maskedUserId}',
    );
  }
}
