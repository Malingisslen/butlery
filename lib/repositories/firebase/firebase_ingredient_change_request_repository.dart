import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';

/// How long a withdrawn proposal is kept before the TTL policy on `expireAt`
/// deletes it.
const Duration kIngredientChangeRetention = Duration(days: 365);

class FirebaseIngredientChangeRequestRepository
    extends BaseFirebaseRepository<IngredientChangeRequest>
    implements IngredientChangeRequestRepository {
  FirebaseIngredientChangeRequestRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
  });

  @override
  String get collectionName => FirestoreCollections.ingredientChangeRequests;

  @override
  IngredientChangeRequest fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => IngredientChangeRequest.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(IngredientChangeRequest entity) =>
      entity.toFirestore();

  @override
  String getId(IngredientChangeRequest entity) => entity.id;

  // Who may propose is decided by the `isAdmin()` rule on the server. These
  // checks only refuse what the app itself never does, so they cannot deny an
  // admin that the rules would let through.
  @override
  Future<bool> validateCreatePermission(
    String userId,
    IngredientChangeRequest entity,
  ) async => true;

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    IngredientChangeRequest? entity,
  ) async => true;

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    IngredientChangeRequest entity,
  ) async => true;

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async => false;

  @override
  Future<IngredientChangeRequest> create(IngredientChangeRequest entity) async {
    try {
      final userId = requireCurrentUserId();
      final ref = collection.doc();
      final saved = entity.withIdentity(id: ref.id, createdBy: userId);
      await ref.set(saved.toFirestore());
      AppLogger.info('Ingredient change request created: ${ref.id}');
      return saved;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to create ingredient change request: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> createBatch(List<IngredientChangeRequest> entities) async {
    if (entities.length > IngredientChangeRequestRepository.maxBatchSize) {
      throw ArgumentError(
        'At most ${IngredientChangeRequestRepository.maxBatchSize} '
        'proposals per batch, got ${entities.length}',
      );
    }
    try {
      final userId = requireCurrentUserId();
      final batch = firestore.batch();
      for (final entity in entities) {
        final ref = collection.doc();
        batch.set(
          ref,
          entity.withIdentity(id: ref.id, createdBy: userId).toFirestore(),
        );
      }
      await batch.commit();
      AppLogger.info('Ingredient change batch created: ${entities.length}');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to create ingredient change batch: $e',
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Stream<List<IngredientChangeRequest>> watchPending() => collection
      .where('status', isEqualTo: IngredientChangeStatus.pending.wireName)
      .limit(IngredientChangeRequestRepository.maxPending)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(fromFirestore).toList());

  // A plain update of exactly the keys the rules allow on withdrawal; the
  // base class update would write the whole document.
  @override
  Future<void> withdraw(String id) async {
    try {
      final userId = requireCurrentUserId();
      await collection.doc(id).update({
        'status': IngredientChangeStatus.withdrawn.wireName,
        'withdrawnAt': FieldValue.serverTimestamp(),
        'withdrawnBy': userId,
        'expireAt': Timestamp.fromDate(
          clock.now().add(kIngredientChangeRetention),
        ),
      });
      AppLogger.info('Ingredient change request $id withdrawn');
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to withdraw ingredient change request: $e',
        stackTrace,
      );
      rethrow;
    }
  }
}
