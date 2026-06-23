import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';

/// Firebase implementation of [PantryRepository].
///
/// Stores items at `users/{userId}/pantry/{itemId}`. Ownership is
/// structural (subcollection under the user document) and enforced by
/// firestore.rules.
///
/// Note: this repository intentionally does NOT extend
/// [BaseFirebaseRepository]. The [PantryRepository] interface takes an
/// explicit `userId` on every method (needed for GDPR jobs, server
/// exports, and tests) which conflicts with `Repository<T>.update(T)`'s
/// single-arg signature. The pattern follows
/// `FirebaseUserIngredientRepository`, which has the same shape.
class FirebasePantryRepository
    with ErrorHandlingMixin
    implements PantryRepository {
  final FirebaseFirestore _firestore;

  FirebasePantryRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) {
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.pantry);
  }

  @override
  Future<String> add(String userId, PantryItem item) async {
    try {
      final ref = _col(userId);
      // Let Firestore allocate the ID so repeated adds don't collide;
      // the service layer handles duplicate detection by ingredientId.
      final docRef = item.id.isEmpty ? ref.doc() : ref.doc(item.id);
      final toWrite = item.id.isEmpty ? item.copyWith(id: docRef.id) : item;
      await docRef.set(toWrite.toFirestore());
      AppLogger.info('PantryItem added: ${docRef.id}');
      return docRef.id;
    } catch (e, stack) {
      AppLogger.error('Failed to add pantry item: $e', stack);
      rethrow;
    }
  }

  @override
  Future<void> update(String userId, PantryItem item) async {
    try {
      await _col(userId).doc(item.id).update(item.toFirestore());
      AppLogger.info('PantryItem updated: ${item.id}');
    } catch (e, stack) {
      AppLogger.error('Failed to update pantry item: $e', stack);
      rethrow;
    }
  }

  @override
  Future<void> remove(String userId, String itemId) async {
    try {
      await _col(userId).doc(itemId).delete();
      AppLogger.info('PantryItem removed: $itemId');
    } catch (e, stack) {
      AppLogger.error('Failed to remove pantry item: $e', stack);
      rethrow;
    }
  }

  @override
  Future<List<PantryItem>> getAll(String userId) async {
    try {
      final snapshot = await _col(userId).get();
      return snapshot.docs.map(PantryItem.fromFirestore).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get pantry items: $e', stack);
      rethrow;
    }
  }

  @override
  Stream<List<PantryItem>> watchAll(String userId) {
    return _col(userId).snapshots().map(
      (snapshot) => snapshot.docs.map(PantryItem.fromFirestore).toList(),
    );
  }

  @override
  Future<PantryItem?> getByIngredientId(
    String userId,
    String ingredientId,
  ) async {
    try {
      final snapshot = await _col(
        userId,
      ).where('ingredientId', isEqualTo: ingredientId).limit(1).get();
      if (snapshot.docs.isEmpty) return null;
      return PantryItem.fromFirestore(snapshot.docs.first);
    } catch (e, stack) {
      AppLogger.error(
        'Failed to lookup pantry item by ingredientId: $e',
        stack,
      );
      rethrow;
    }
  }

  @override
  Future<List<PantryItem>> getExpiringSoon(String userId, int days) async {
    try {
      final cutoff = clock.now().add(Duration(days: days));
      final snapshot = await _col(
        userId,
      ).where('expiryDate', isLessThan: Timestamp.fromDate(cutoff)).get();
      return snapshot.docs.map(PantryItem.fromFirestore).toList();
    } catch (e, stack) {
      AppLogger.error('Failed to get expiring items: $e', stack);
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllByUser(
    String userId, {
    int maxDocuments = 1000,
  }) async {
    // Ownership is structural — the path is `users/{userId}/pantry/{id}`.
    // Firestore rules enforce that only the authenticated owner can read
    // this subcollection. Caller (data_export_service) confirms the
    // userId matches the auth uid before invoking this method.
    try {
      final snapshot = await _col(userId).limit(maxDocuments).get();
      return snapshot.docs
          .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
          .toList();
    } catch (e, stack) {
      AppLogger.error('Failed to export pantry items: $e', stack);
      rethrow;
    }
  }

  @override
  Future<void> deleteAll(String userId) async {
    try {
      final ref = _col(userId);
      // Firestore batches max out at 500 ops; chunk accordingly.
      const chunkSize = 400;
      while (true) {
        final snapshot = await ref.limit(chunkSize).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snapshot.docs.length < chunkSize) break;
      }
      AppLogger.info(
        'All pantry items deleted for user: ${userId.maskedUserId}',
      );
    } catch (e, stack) {
      AppLogger.error('Failed to delete all pantry items: $e', stack);
      rethrow;
    }
  }
}
