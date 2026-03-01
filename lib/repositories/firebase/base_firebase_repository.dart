/// Base Firebase repository providing unified CRUD operations with permission validation.
/// Consolidates common patterns: authentication, error handling, and audit logging.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/mixins/permission_validation_mixin.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/firebase/firebase_audit_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

abstract class BaseFirebaseRepository<T>
    with PermissionValidationMixin
    implements Repository<T> {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;
  final FirebaseAuditRepository? _auditRepository;

  BaseFirebaseRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _authRepository = authRepository,
        _auditRepository = auditRepository;

  @protected
  FirebaseFirestore get firestore => _firestore;

  @protected
  AuthRepository get authRepository => _authRepository;

  String get collectionName;
  T fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc);
  Map<String, dynamic> toFirestore(T entity);
  String getId(T entity);

  Future<bool> validateCreatePermission(String userId, T entity);
  Future<bool> validateReadPermission(
      String userId, String resourceId, T? entity);
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, T entity);
  Future<bool> validateDeletePermission(String userId, String resourceId);

  String requireCurrentUserId() {
    final uid = _authRepository.currentUserId;
    if (uid == null) {
      throw AuthenticationException(
        'No authenticated user for ${T.toString()} operation',
        details: 'Authentication required for ${T.toString()} operations',
      );
    }
    return uid;
  }

  String? get currentUserId => _authRepository.currentUserId;

  CollectionReference<Map<String, dynamic>> get collection {
    return _firestore.collection(collectionName);
  }

  CollectionReference<Map<String, dynamic>> getUserCollection(String? userId) {
    final uid = userId ?? requireCurrentUserId();
    return _firestore.collection(FirestoreCollections.users).doc(uid).collection(collectionName);
  }

  CollectionReference<Map<String, dynamic>> getCollectionRef() => collection;

  @override
  Future<T> create(T entity) async {
    try {
      final userId = requireCurrentUserId();
      final docId = getId(entity);
      final canCreate = await validateCreatePermission(userId, entity);

      await logPermissionCheck(
        userId: userId,
        resource: '${T.toString()}/$docId',
        operation: 'create',
        granted: canCreate,
        auditRepository: _auditRepository,
      );

      if (!canCreate) {
        throw PermissionDeniedException(
          'User $userId does not have permission to create ${T.toString()}',
        );
      }

      final ref = getCollectionRef();
      await ref.doc(docId).set(toFirestore(entity));

      AppLogger.info('${T.toString()} created: $docId');
      return entity;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create ${T.toString()}: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<T?> read(String id) async {
    try {
      final userId = requireCurrentUserId();
      final ref = getCollectionRef();
      final doc = await ref.doc(id).get();

      if (!doc.exists) {
        AppLogger.info('${T.toString()} not found: $id');
        return null;
      }

      final entity = fromFirestore(doc);
      final canRead = await validateReadPermission(userId, id, entity);

      await logPermissionCheck(
        userId: userId,
        resource: '${T.toString()}/$id',
        operation: 'read',
        granted: canRead,
        auditRepository: _auditRepository,
      );

      if (!canRead) {
        throw PermissionDeniedException(
          'User $userId does not have permission to read ${T.toString()} $id',
        );
      }

      return entity;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to read ${T.toString()} $id: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<T>> readAll() async {
    try {
      final userId = requireCurrentUserId();
      final ref = getCollectionRef();
      final snapshot = await ref.get();

      final allowedEntities = <T>[];
      for (final doc in snapshot.docs) {
        final entity = fromFirestore(doc);
        final canRead = await validateReadPermission(userId, doc.id, entity);

        await logPermissionCheck(
          userId: userId,
          resource: '${T.toString()}/${doc.id}',
          operation: 'readAll',
          granted: canRead,
          auditRepository: _auditRepository,
        );

        if (canRead) {
          allowedEntities.add(entity);
        }
      }

      AppLogger.info(
        '${T.toString()} readAll: ${allowedEntities.length}/${snapshot.docs.length} items (filtered by permissions)',
      );
      return allowedEntities;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to read all ${T.toString()}: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> update(T entity) async {
    try {
      final userId = requireCurrentUserId();
      final docId = getId(entity);
      final canUpdate = await validateUpdatePermission(userId, docId, entity);

      await logPermissionCheck(
        userId: userId,
        resource: '${T.toString()}/$docId',
        operation: 'update',
        granted: canUpdate,
        auditRepository: _auditRepository,
      );

      if (!canUpdate) {
        throw PermissionDeniedException(
          'User $userId does not have permission to update ${T.toString()} $docId',
        );
      }

      final ref = getCollectionRef();
      await ref.doc(docId).update(toFirestore(entity));

      AppLogger.info('${T.toString()} updated: $docId');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update ${T.toString()}: $e', stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final userId = requireCurrentUserId();
      final canDelete = await validateDeletePermission(userId, id);

      await logPermissionCheck(
        userId: userId,
        resource: '${T.toString()}/$id',
        operation: 'delete',
        granted: canDelete,
        auditRepository: _auditRepository,
      );

      if (!canDelete) {
        throw PermissionDeniedException(
          'User $userId does not have permission to delete ${T.toString()} $id',
        );
      }

      final ref = getCollectionRef();
      await ref.doc(id).delete();

      AppLogger.info('${T.toString()} deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete ${T.toString()} $id: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> createBatch(List<T> entities) async {
    try {
      requireCurrentUserId();
      final ref = getCollectionRef();
      final batch = _firestore.batch();

      for (final entity in entities) {
        batch.set(ref.doc(getId(entity)), toFirestore(entity));
      }

      await batch.commit();
      AppLogger.info('${T.toString()} batch created: ${entities.length} items');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create ${T.toString()} batch: $e', stackTrace);
      throw Exception('Failed to create ${T.toString()} batch: $e');
    }
  }

  Stream<List<T>> watchAll({String? orderBy, bool descending = false}) {
    try {
      var query = getCollectionRef() as Query<Map<String, dynamic>>;

      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map(fromFirestore).toList();
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to watch ${T.toString()}: $e', stackTrace);
      throw Exception('Failed to watch ${T.toString()}: $e');
    }
  }

  Future<bool> exists(String id) async {
    try {
      final doc = await getCollectionRef().doc(id).get();
      return doc.exists;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to check ${T.toString()} existence $id: $e', stackTrace);
      return false;
    }
  }

  Future<int> count() async {
    try {
      final snapshot = await getCollectionRef().count().get();
      return snapshot.count ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to count ${T.toString()}: $e', stackTrace);
      return 0;
    }
  }

  /// Returns empty list instead of throwing on auth failure.
  Future<List<T>> readAllSafe() async {
    try {
      if (currentUserId == null) return [];
      return await readAll();
    } catch (e) {
      AppLogger.error('Safe readAll ${T.toString()} failed: $e');
      return [];
    }
  }

  /// Returns null instead of throwing on auth failure.
  Future<T?> readSafe(String id) async {
    try {
      if (currentUserId == null) return null;
      return await read(id);
    } catch (e) {
      AppLogger.error('Safe read ${T.toString()} $id failed: $e');
      return null;
    }
  }

  /// Reads a single document using cache-first strategy.
  ///
  /// Tries the local Firestore cache first to avoid a network round-trip.
  /// Falls back to server on cache miss. Suitable for non-critical reads
  /// where slightly stale data is acceptable (e.g., displaying a recipe
  /// detail, showing a user profile). NOT suitable for permission checks
  /// or pre-update validation where fresh data is required -- use [read].
  @protected
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocCacheFirst(
    DocumentReference<Map<String, dynamic>> docRef,
  ) async {
    try {
      final cached = await docRef.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {
      // Cache miss or cache disabled -- fall through to server
    }
    return await docRef.get(const GetOptions(source: Source.serverAndCache));
  }

  /// Cache-first read with full permission validation.
  ///
  /// Same as [read] but tries cache first. Use for display-only reads
  /// where the latest server state is not critical.
  Future<T?> readCacheFirst(String id) async {
    try {
      final userId = requireCurrentUserId();
      final ref = getCollectionRef();
      final doc = await getDocCacheFirst(ref.doc(id));

      if (!doc.exists) {
        return null;
      }

      final entity = fromFirestore(doc);
      final canRead = await validateReadPermission(userId, id, entity);

      await logPermissionCheck(
        userId: userId,
        resource: '${T.toString()}/$id',
        operation: 'read',
        granted: canRead,
        auditRepository: _auditRepository,
      );

      if (!canRead) {
        throw PermissionDeniedException(
          'User $userId does not have permission to read ${T.toString()} $id',
        );
      }

      return entity;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to read (cache-first) ${T.toString()} $id: $e',
        stackTrace,
      );
      rethrow;
    }
  }
}

/// Mixin for repositories that store data in user-scoped collections.
mixin UserScopedFirebaseRepository<T> on BaseFirebaseRepository<T> {
  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return getUserCollection(null);
  }

  CollectionReference<Map<String, dynamic>> getCollectionForUser(
      String userId) {
    return getUserCollection(userId);
  }
}

/// Mixin for repositories that need batch operations.
mixin BatchOperationsFirebaseRepository<T> on BaseFirebaseRepository<T> {
  Future<void> updateBatch(List<T> entities) async {
    try {
      requireCurrentUserId();
      final ref = getCollectionRef();
      final batch = _firestore.batch();

      for (final entity in entities) {
        batch.update(ref.doc(getId(entity)), toFirestore(entity));
      }

      await batch.commit();
      AppLogger.info('${T.toString()} batch updated: ${entities.length} items');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update ${T.toString()} batch: $e', stackTrace);
      throw Exception('Failed to update ${T.toString()} batch: $e');
    }
  }

  Future<void> deleteBatch(List<String> ids) async {
    try {
      requireCurrentUserId();
      final ref = getCollectionRef();
      final batch = _firestore.batch();

      for (final id in ids) {
        batch.delete(ref.doc(id));
      }

      await batch.commit();
      AppLogger.info('${T.toString()} batch deleted: ${ids.length} items');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete ${T.toString()} batch: $e', stackTrace);
      throw Exception('Failed to delete ${T.toString()} batch: $e');
    }
  }
}
