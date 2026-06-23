import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cook_event.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/cook_event_repository.dart';

/// Firebase implementation of the per-user cook-event log (BUT-838).
///
/// ## Schema
///
/// ```text
/// recipe_cook_events/{userId}/events/{eventId}
///   recipeId: string     — the cooked recipe's id (non-empty)
///   cookedAt: timestamp  — client cook time (clock.now() at the tap)
/// ```
///
/// The BUT-838 ticket writes the path as `recipe_cook_events/{userId}/{eventId}`,
/// which is not expressible in Firestore (paths alternate collection/document);
/// events therefore live in an `events` subcollection under the per-user
/// document. The `recipe_cook_events/{userId}` document itself is never
/// written — it exists only as a path segment, which is fine for direct
/// subcollection queries (and the rules key owner access off that segment).
///
/// Events are append-only: created atomically with the recipe's
/// `core.cookCount` bump (one WriteBatch), never updated. The `countSince`
/// aggregate needs only the automatic single-field index on `cookedAt`
/// (single range constraint, no orderBy/composite) — nothing was added to
/// firestore.indexes.json.
///
/// Deliberately NOT using `UserScopedFirebaseRepository` (the layer rule's
/// default for user-scoped data): the ticket pins the top-level
/// `recipe_cook_events/{userId}/events` tree so the GDPR cascade and rules
/// block address it directly; the mixin would route to `/users/{uid}/...`.
class FirebaseCookEventRepository extends BaseFirebaseRepository<CookEvent>
    implements CookEventRepository {
  /// Concrete recipe repository — owns the `core.cookCount` field shape, so
  /// the atomic increment is delegated to its batch-additive helper instead
  /// of duplicating the update map here.
  final FirebaseRecipeRepository _recipeRepository;

  FirebaseCookEventRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
    required FirebaseRecipeRepository recipeRepository,
  }) : _recipeRepository = recipeRepository;

  @override
  String get collectionName => FirestoreCollections.recipeCookEvents;

  /// `recipe_cook_events/{userId}/events` for an explicit user.
  CollectionReference<Map<String, dynamic>> eventsCollectionForUser(
    String userId,
  ) => firestore
      .collection(FirestoreCollections.recipeCookEvents)
      .doc(userId)
      .collection(FirestoreCollections.recipeCookEventEntries);

  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() =>
      eventsCollectionForUser(requireCurrentUserId());

  @override
  CookEvent fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CookEvent.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(CookEvent entity) => entity.toFirestore();

  @override
  String getId(CookEvent entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(String userId, CookEvent entity) async {
    return entity.userId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    CookEvent? entity,
  ) async {
    // Collection routing already scopes reads to the caller's own events;
    // the entity check defends against a doc fetched via a foreign ref.
    return entity == null || entity.userId == userId;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    CookEvent entity,
  ) async {
    // Append-only log — events are immutable (rules also deny update).
    return false;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Owner-only: routing scopes deletes to the caller's own subcollection.
    return currentUserId == userId;
  }

  @override
  Future<bool> logCookEvent(String recipeId, DateTime cookedAt) async {
    if (recipeId.isEmpty) return false;

    final userId = currentUserId;
    if (userId == null) {
      AppLogger.warning('logCookEvent: no authenticated user, skipping');
      return false;
    }

    try {
      final eventRef = eventsCollectionForUser(userId).doc();
      final event = CookEvent(
        id: eventRef.id,
        userId: userId,
        recipeId: recipeId,
        cookedAt: cookedAt,
      );

      final canCreate = await validateCreatePermission(userId, event);
      await logPermissionCheck(
        userId: userId,
        resource: '$collectionName/${eventRef.id}',
        operation: 'logCookEvent',
        granted: canCreate,
        auditRepository: auditRepository,
      );
      if (!canCreate) return false;

      // One batch: event doc + recipe counter bump. Either both land or
      // neither — the event log and core.cookCount can never drift.
      final batch = firestore.batch();
      batch.set(eventRef, toFirestore(event));
      _recipeRepository.addIncrementCookCountToBatch(
        batch,
        userId,
        recipeId,
        cookedAt,
      );
      await batch.commit();

      AppLogger.info('Cook event logged: $recipeId at $cookedAt');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log cook event for $recipeId: $e', stackTrace);
      return false;
    }
  }

  /// Self-only gate shared by every per-user read: audit-logs the check,
  /// then throws unless the signed-in user IS [userId]. Centralized so the
  /// audit row and the exception can never drift apart between methods.
  Future<void> _requireSelf(String userId, String operation) async {
    final requesterId = requireCurrentUserId();
    final granted = requesterId == userId;
    await logPermissionCheck(
      userId: requesterId,
      resource: '$collectionName/$userId',
      operation: operation,
      granted: granted,
      auditRepository: auditRepository,
    );
    if (!granted) {
      throw PermissionDeniedException(
        'User $requesterId cannot $operation on cook events of $userId',
        resource: collectionName,
        operation: operation,
        userId: requesterId,
      );
    }
  }

  @override
  Future<int> countSince(String userId, DateTime since) async {
    await _requireSelf(userId, 'countSince');

    // Server-side aggregate — counts without downloading documents. The
    // single range constraint rides Firestore's automatic single-field
    // index on cookedAt; no composite index required.
    final snapshot = await eventsCollectionForUser(userId)
        .where('cookedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> exportCookEventsByUser(
    String userId, {
    int? limit,
  }) async {
    // GDPR Article 15/20: caller must be exporting their own events.
    await _requireSelf(userId, 'exportCookEventsByUser');

    // Newest-first so a truncated export keeps the most recent events
    // (deterministic; rides the automatic single-field index).
    Query<Map<String, dynamic>> query = eventsCollectionForUser(
      userId,
    ).orderBy('cookedAt', descending: true);
    if (limit != null) query = query.limit(limit);
    final snapshot = await query.get();

    return snapshot.docs
        .map((doc) => <String, dynamic>{'id': doc.id, 'data': doc.data()})
        .toList();
  }
}
